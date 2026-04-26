//
//  TutorConversationModel.swift
//  lahacks
//
//  Coordinates the voice-first tutor experience:
//
//      mic on → SpeechAnalyzer → mic off → Gemma (LocalLLMClient) → ElevenLabs TTS
//
//  The Gemma + ElevenLabs portion mirrors the original LocalChatViewModel from the
//  `gemma-elevenlabs-audioOutput` branch (chat history, prompt template, streaming
//  partial text, final speak). The new pieces are:
//
//      • mic toggle entry point that drains the SpeechAnalyzer transcript on stop
//      • a `state` machine that drives the AR avatar (wave on spawn, Yes loop while
//        speaking, Idle otherwise) via `isSpeaking`
//      • explicit ordering between the recording AVAudioSession and the playback
//        AVAudioSession so the mic is fully torn down before TTS opens its session
//      • progress signals (elapsed time + raw-token callback count) so the UI can
//        prove the model is still working even while the response filter is
//        suppressing thinking tokens
//      • an `<end_of_turn>` early-stop fallback in case Zetic doesn't recognize
//        Gemma's EOS and the inner generation loop would otherwise run forever
//      • a user-initiated cancel that aborts the pipeline mid-flight
//
//  This model is `@MainActor` so all UI-facing state mutations land on main; the
//  Gemma actor handles its own off-main token loop and posts streamed text back to
//  the main actor.
//

import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class TutorConversationModel {
    enum State: Equatable {
        case idle
        case loadingModel(progress: Float?)
        case listening
        case retrieving
        case thinking
        case speaking
        case unavailable
    }

    private(set) var state: State = .idle
    private(set) var messages: [ChatMessage] = []
    private(set) var partialAssistantText = ""
    private(set) var thinkingStartedAt: Date?
    private(set) var rawTokenCount = 0
    private(set) var errorMessage: String?
    private(set) var isGemmaReady = false

    let speechModel = SpeechAnalyzerModel()

    private let logger = Logger(subsystem: "lahacks", category: "TutorConversationModel")
    private let llmClient = LocalLLMClient()
    private let retrievalService = RAGRetrievalService()
    private var ttsClient: ElevenLabsTTSClient?
    private var modelLoadTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?
    private var earlyStoppedText: String?
    private var textbookISBN: ISBN?
    private var atlasCollection: String?
    private var currentPipelineStartedAt: Date?
    private var didLogFirstRawToken = false
    private var didLogFirstVisibleToken = false
    private var didLogFirstSpeechSafeToken = false

    private static let ragContextCharacterBudget = 5_000
    var isSpeaking: Bool { state == .speaking }

    var isModelReady: Bool {
        switch state {
        case .idle, .listening, .retrieving, .thinking, .speaking:
            return isGemmaReady
        case .loadingModel, .unavailable:
            return false
        }
    }

    var canToggleMic: Bool {
        guard isGemmaReady else { return false }

        switch state {
        case .idle, .listening:
            return true
        default:
            return false
        }
    }

    var canCancelPipeline: Bool {
        switch state {
        case .retrieving, .thinking, .speaking:
            return true
        default:
            return false
        }
    }

    var gemmaReadinessLabel: String {
        isGemmaReady ? "Gemma Ready" : "Gemma Not Ready"
    }

    var gemmaReadinessDetail: String {
        switch state {
        case .loadingModel(let progress):
            if let progress {
                "Loading \(progress.formatted(.percent.precision(.fractionLength(0))))"
            } else {
                "Loading model"
            }
        case .unavailable:
            "Check configuration"
        default:
            isGemmaReady ? "Loaded on device" : "Preloading"
        }
    }

    var statusMessage: String {
        switch state {
        case .idle:
            "Tap the mic and ask a question."
        case .loadingModel(let progress):
            if let progress {
                "Downloading tutor model \(progress.formatted(.percent.precision(.fractionLength(0))))"
            } else {
                "Loading on-device tutor…"
            }
        case .listening:
            "Listening — tap the mic to send."
        case .retrieving:
            "Searching textbook…"
        case .thinking:
            "Generating answer on device…"
        case .speaking:
            "Speaking…"
        case .unavailable:
            "Tutor unavailable. Check Melange configuration."
        }
    }

    var liveTranscript: String {
        speechModel.transcript
    }

    func prepareModel() {
        guard MelangeSecrets.isConfigured else {
            isGemmaReady = false
            state = .unavailable
            errorMessage = "Add your Melange personal key and model name in MelangeSecrets.swift before talking to the tutor."
            return
        }

        if case .loadingModel = state { return }
        if isGemmaReady { return }

        state = .loadingModel(progress: nil)
        logger.info("Preparing on-device tutor model")

        modelLoadTask = Task { [weak self, llmClient] in
            defer { self?.modelLoadTask = nil }
            do {
                try await llmClient.prepare { [weak self] progress in
                    guard let self else { return }
                    self.state = .loadingModel(progress: progress)
                }
                guard let self, !Task.isCancelled else { return }
                self.isGemmaReady = true
                self.state = .idle
                self.logger.info("Tutor model ready")
            } catch {
                guard let self else { return }
                self.isGemmaReady = false
                if !Task.isCancelled {
                    self.errorMessage = "Could not load the tutor model: \(error.localizedDescription)"
                    self.logger.error("Model prepare failed: \(error.localizedDescription, privacy: .public)")
                }
                self.state = .unavailable
            }
        }
    }

    func configureTextbook(isbn: ISBN, atlasCollection: String?) {
        textbookISBN = isbn
        self.atlasCollection = atlasCollection
    }

    func toggleMic() {
        switch state {
        case .listening:
            stopAndProcess()
        case .idle:
            startListening()
        default:
            return
        }
    }

    func cancelPipeline() {
        guard pipelineTask != nil else { return }
        logger.info("User cancelled pipeline (state=\(String(describing: self.state), privacy: .public))")
        pipelineTask?.cancel()
        let client = ttsClient
        ttsClient = nil
        Task { await client?.cancel() }
    }

    func tearDown() {
        modelLoadTask?.cancel()
        modelLoadTask = nil
        stopInteraction()
    }

    func stopInteraction() {
        pipelineTask?.cancel()
        pipelineTask = nil
        speechModel.stopListening()
        let client = ttsClient
        ttsClient = nil
        Task { await client?.cancel() }
        if isGemmaReady {
            state = .idle
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func startListening() {
        guard isGemmaReady else {
            errorMessage = "Gemma is still loading. Wait for the Ready indicator before talking."
            return
        }
        guard textbookISBN != nil, atlasCollection != nil else {
            errorMessage = "Textbook context is still loading. Wait for the avatar to finish loading before asking a question."
            return
        }
        guard MelangeSecrets.isRetrievalConfigured else {
            errorMessage = "Textbook retrieval is not configured."
            return
        }
        errorMessage = nil
        speechModel.startListening()
        state = .listening
        logger.info("Mic on — listening")
    }

    private func stopAndProcess() {
        currentPipelineStartedAt = .now
        let userText = speechModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        speechModel.stopListening()
        logger.info("Mic off — captured \(userText.count) chars")
        logLatency("mic stop", details: "captured \(userText.count) chars")

        guard !userText.isEmpty else {
            state = .idle
            errorMessage = "I didn't catch that — try again."
            return
        }

        messages.append(ChatMessage(role: .user, text: userText))
        runPipeline()
    }

    private func runPipeline() {
        partialAssistantText = ""
        rawTokenCount = 0
        thinkingStartedAt = .now
        earlyStoppedText = nil
        didLogFirstRawToken = false
        didLogFirstVisibleToken = false
        didLogFirstSpeechSafeToken = false

        guard let textbookISBN else {
            errorMessage = "Textbook context is still loading. Try again in a moment."
            state = .idle
            return
        }

        guard let lastUserText = messages.last(where: { $0.role == .user })?.text else {
            state = .idle
            return
        }

        state = .retrieving
        logger.info("Retrieval started (message=\(lastUserText.count, privacy: .public) chars)")
        logLatency("retrieval start", details: "message \(lastUserText.count) chars")

        pipelineTask = Task { [weak self, retrievalService, llmClient] in
            guard let self else { return }

            let retrieval: RetrievalResponse
            do {
                retrieval = try await retrievalService.retrieveContext(
                    isbn: textbookISBN,
                    message: lastUserText
                )
                self.logLatency("retrieval end", details: "\(retrieval.chunks.count) chunks")
                if Task.isCancelled {
                    self.state = .idle
                    self.thinkingStartedAt = nil
                    self.pipelineTask = nil
                    return
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Could not search the textbook: \(error.localizedDescription)"
                    self.logger.error("Retrieval error: \(error.localizedDescription, privacy: .public)")
                }
                self.state = .idle
                self.thinkingStartedAt = nil
                self.pipelineTask = nil
                return
            }

            let prompt = Self.chatPrompt(from: self.messages, retrieval: retrieval)
            self.logLatency("prompt ready", details: "\(prompt.count) chars")
            let assistantMessage = ChatMessage(role: .assistant, text: "")
            self.messages.append(assistantMessage)
            let assistantID = assistantMessage.id

            self.state = .thinking
            self.logger.info("Pipeline started (prompt=\(prompt.count, privacy: .public) chars, chunks=\(retrieval.chunks.count, privacy: .public))")

            let finalResponse: String
            do {
                self.logLatency("Gemma run start")
                finalResponse = try await llmClient.generateResponse(for: prompt) { [weak self] streamed in
                    guard let self else { return }
                    self.handleStreamed(streamed, assistantID: assistantID)
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Tutor failed to respond: \(error.localizedDescription)"
                    self.logger.error("LLM error: \(error.localizedDescription, privacy: .public)")
                }
                self.removeEmptyAssistantMessage(id: assistantID)
                self.state = .idle
                self.thinkingStartedAt = nil
                self.pipelineTask = nil
                return
            }
            self.logLatency("final token", details: "\(finalResponse.count) visible chars")

            let cancelled = Task.isCancelled
            let textToSpeak: String
            if let early = self.earlyStoppedText {
                textToSpeak = early
                self.logger.info("Pipeline early-stopped on <end_of_turn> (chars=\(early.count))")
            } else if cancelled {
                self.logger.info("Pipeline cancelled by user")
                self.removeEmptyAssistantMessage(id: assistantID)
                self.state = .idle
                self.thinkingStartedAt = nil
                self.pipelineTask = nil
                return
            } else {
                textToSpeak = AssistantResponseFilter.spokenText(
                    from: finalResponse.replacing("<end_of_turn>", with: "")
                )
                self.logger.info("Pipeline finished normally (raw chars=\(finalResponse.count), spoken chars=\(textToSpeak.count))")
            }

            self.thinkingStartedAt = nil

            if textToSpeak.isEmpty {
                self.removeEmptyAssistantMessage(id: assistantID)
                self.state = .idle
                self.pipelineTask = nil
                return
            }

            self.replaceText(textToSpeak, in: assistantID)
            self.partialAssistantText = textToSpeak
            await self.speak(textToSpeak)
            self.pipelineTask = nil
        }
    }

    private func handleStreamed(
        _ streamed: LocalLLMStreamUpdate,
        assistantID: ChatMessage.ID
    ) {
        rawTokenCount += 1
        if !didLogFirstRawToken {
            didLogFirstRawToken = true
            logLatency("first raw token", details: "generated \(streamed.generatedTokens) tokens")
        }

        if earlyStoppedText != nil {
            return
        }

        if let endRange = streamed.visibleText.range(of: "<end_of_turn>") {
            let truncated = String(streamed.visibleText[..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            earlyStoppedText = truncated
            partialAssistantText = truncated
            replaceText(truncated, in: assistantID)
            pipelineTask?.cancel()
            return
        }

        if !streamed.visibleText.isEmpty, !didLogFirstVisibleToken {
            didLogFirstVisibleToken = true
            logLatency("first visible token", details: "\(streamed.visibleText.count) chars")
        }

        partialAssistantText = streamed.visibleText
        replaceText(streamed.visibleText, in: assistantID)

        if streamed.isSafeForSpeech, !streamed.visibleText.isEmpty, !didLogFirstSpeechSafeToken {
            didLogFirstSpeechSafeToken = true
            logLatency("first speech-safe token", details: "\(streamed.visibleText.count) chars")
        }
    }

    private func makeTimedTTSClient() -> ElevenLabsTTSClient {
        ElevenLabsTTSClient(
            onSocketOpen: { [weak self] in
                self?.logLatency("TTS socket open")
            },
            onFirstAudioChunk: { [weak self] in
                self?.logLatency("first audio chunk")
            },
            onPlaybackDone: { [weak self] in
                self?.logLatency("playback done")
            }
        )
    }

    private func speak(_ text: String) async {
        guard MelangeSecrets.isElevenLabsConfigured else {
            state = .idle
            return
        }

        let client = makeTimedTTSClient()
        ttsClient = client
        state = .speaking
        logger.info("Speaking via ElevenLabs (\(text.count) chars)")

        do {
            try await client.start()
            try await client.speak(text)
        } catch {
            if !Task.isCancelled {
                errorMessage = "Voice playback failed: \(error.localizedDescription)"
                logger.error("ElevenLabs failed: \(error.localizedDescription, privacy: .public)")
            }
            await client.cancel()
        }

        ttsClient = nil
        state = .idle
    }

    private func logLatency(_ event: String, details: String = "") {
        let elapsed = currentPipelineStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
        if details.isEmpty {
            logger.info("Tutor latency — \(event, privacy: .public): +\(elapsed, privacy: .public)s")
        } else {
            logger.info("Tutor latency — \(event, privacy: .public): +\(elapsed, privacy: .public)s (\(details, privacy: .public))")
        }
    }

    private func replaceText(_ text: String, in messageID: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].text = text
    }

    private func removeEmptyAssistantMessage(id: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }), messages[index].text.isEmpty else { return }
        messages.remove(at: index)
    }

    private static func chatPrompt(from messages: [ChatMessage], retrieval: RetrievalResponse) -> String {
        let contextBlock = ragContextBlock(from: retrieval)
        var prompt = """
        <start_of_turn>user
        You are a friendly, concise learning assistant running fully on the student's iPad next to their textbook. Answer clearly and keep responses natural and enthusiastic for spoken, engaging conversation, ideally one to two sentences. Keep the responses strictly in paragraph form. Do not use any bulletpoints. Do not use any numbered lists. Do not include <think> tags or reasoning text in the spoken answer.

        Important output rule: when you are ready to give the answer the student should hear, write exactly SPOKEN_ANSWER: and then the answer. Do not put any reasoning, analysis, scratchpad, or hidden thought after SPOKEN_ANSWER:. <end_of_turn>

        <start_of_turn>user
        Use the retrieved textbook context below to ground your next answer. If the context is empty or does not contain the answer, say "I couldn't find that in the textbook context" and ask the student to try a more specific question.

        Retrieved textbook context:
        \(contextBlock)<end_of_turn>

        """

        for message in messages {
            if message.role == .assistant && message.text.isEmpty {
                continue
            }

            let roleString = message.role == .user ? "user" : "model"
            prompt += """
            <start_of_turn>\(roleString)
            \(message.text)<end_of_turn>

            """
        }

        prompt += "<start_of_turn>model\n"

        return prompt
    }

    private static func ragContextBlock(from retrieval: RetrievalResponse) -> String {
        guard !retrieval.chunks.isEmpty else {
            return "No relevant textbook chunks were returned."
        }

        var context = ""
        for (index, chunk) in retrieval.chunks.enumerated() {
            let snippet = ragSnippet(for: chunk, index: index)
            if context.count + snippet.count > ragContextCharacterBudget {
                break
            }
            context += snippet
        }

        return context.isEmpty ? "No retrieved chunk fit within the local model context budget." : context
    }

    private static func ragSnippet(for chunk: RetrievedChunk, index: Int) -> String {
        var metadata: [String] = []
        if let sourceFile = chunk.sourceFile {
            metadata.append("source: \(sourceFile)")
        }
        if let page = chunk.page {
            metadata.append("page: \(page)")
        }
        if let chunkIndex = chunk.chunkIndex {
            metadata.append("chunk: \(chunkIndex)")
        }

        let title: String
        if metadata.isEmpty {
            title = "[Chunk \(index + 1)]"
        } else {
            title = "[Chunk \(index + 1) - \(metadata.joined(separator: ", "))]"
        }

        return """
        \(title)
        \(chunk.text)

        """
    }
}

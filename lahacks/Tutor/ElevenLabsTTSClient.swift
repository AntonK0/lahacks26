import Foundation

@MainActor
final class ElevenLabsTTSClient: NSObject {
    private let audioPlayer = ElevenLabsAudioPlayer()
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let onSocketOpen: @MainActor @Sendable () -> Void
    private let onFirstAudioChunk: @MainActor @Sendable () -> Void
    private let onPlaybackDone: @MainActor @Sendable () -> Void
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var receiveTask: Task<Void, Never>?
    private var keepAliveTask: Task<Void, Never>?
    private var lastVisibleText = ""
    private var openContinuation: CheckedContinuation<Void, any Error>?
    private var finalResponseContinuation: CheckedContinuation<Void, any Error>?
    private var hasReceivedFinalResponse = false
    private var hasReceivedAudio = false

    init(
        onSocketOpen: @escaping @MainActor @Sendable () -> Void = {},
        onFirstAudioChunk: @escaping @MainActor @Sendable () -> Void = {},
        onPlaybackDone: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.onSocketOpen = onSocketOpen
        self.onFirstAudioChunk = onFirstAudioChunk
        self.onPlaybackDone = onPlaybackDone
        super.init()
    }

    func start() async throws {
        guard webSocketTask == nil else {
            return
        }

        try ElevenLabsAudioPlayer.configureSession()

        let urlString = "wss://api.elevenlabs.io/v1/text-to-speech/\(MelangeSecrets.elevenLabsVoiceID)/stream-input?model_id=\(MelangeSecrets.elevenLabsModelID)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        hasReceivedFinalResponse = false
        hasReceivedAudio = false
        task.resume()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            self.openContinuation = continuation
        }

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
        keepAliveTask = Task { [weak self] in
            await self?.sendKeepAlives()
        }

        do {
            try await send(
                InitialMessage(
                    text: " ",
                    xiApiKey: MelangeSecrets.elevenLabsAPIKey,
                    voiceSettings: VoiceSettings(
                        stability: 0.5,
                        similarityBoost: 0.8,
                        useSpeakerBoost: false
                    ),
                    generationConfig: GenerationConfig(chunkLengthSchedule: [120, 160, 250, 290])
                ),
                logDescription: "initial configuration"
            )
        } catch {
            tearDown()
            throw error
        }
    }

    func streamVisibleText(_ visibleText: String) async {
        guard webSocketTask != nil else {
            return
        }

        let delta = visibleText.delta(comparedTo: lastVisibleText)
        lastVisibleText = visibleText

        guard !delta.isEmpty else {
            return
        }

        do {
            try await send(TextMessage(text: delta, flush: nil), logDescription: "text delta (\(delta.count) chars)")
        } catch {
            tearDown()
        }
    }

    func speakAcknowledgement(_ text: String) async throws {
        let spokenText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spokenText.isEmpty else {
            return
        }

        lastVisibleText = spokenText
        try await send(TextMessage(text: spokenText, flush: true), logDescription: "acknowledgement (\(spokenText.count) chars)")
    }

    func speak(_ text: String) async throws {
        let spokenText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spokenText.isEmpty else {
            return
        }

        try await send(TextMessage(text: spokenText, flush: true), logDescription: "final response (\(spokenText.count) chars)")
        stopKeepAlives()
        try await closeTextStream()
        do {
            try await waitForFinalResponse(timeout: .seconds(8))
        } catch {
            print("[ElevenLabs] final response timeout: \(error)")
        }
        await audioPlayer.waitUntilIdle(timeout: .seconds(45))
        onPlaybackDone()
        tearDown()
    }

    func finish() async throws {
        guard webSocketTask != nil else {
            await audioPlayer.waitUntilIdle(timeout: .seconds(45))
            onPlaybackDone()
            return
        }

        stopKeepAlives()
        try await closeTextStream(flush: true)
        do {
            try await waitForFinalResponse(timeout: .seconds(8))
        } catch {
            print("[ElevenLabs] final response timeout: \(error)")
        }
        await audioPlayer.waitUntilIdle(timeout: .seconds(45))
        onPlaybackDone()
        tearDown()
    }

    func cancel() async {
        tearDown()
        audioPlayer.stop()
    }

    private func receiveLoop() async {
        guard let webSocketTask else {
            return
        }

        while !Task.isCancelled {
            do {
                let message = try await webSocketTask.receive()
                handle(message)
            } catch {
                if !Task.isCancelled {
                    print("[ElevenLabs] receive error: \(error)")
                    tearDown()
                }
                break
            }
        }
    }

    private func sendKeepAlives() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(10))
                try await send(TextMessage(text: " ", flush: nil), logDescription: "keepalive")
            } catch {
                if !Task.isCancelled {
                    tearDown()
                }
                return
            }
        }
    }

    private func stopKeepAlives() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data

        switch message {
        case .data(let messageData):
            data = messageData
        case .string(let messageText):
            guard let messageData = messageText.data(using: .utf8) else {
                return
            }
            data = messageData
        @unknown default:
            return
        }

        guard let response = try? jsonDecoder.decode(AudioResponse.self, from: data) else {
            if let text = String(data: data, encoding: .utf8) {
                print("[ElevenLabs] unexpected message: \(text.prefix(500))")
            }
            return
        }

        if let audio = response.audio, let audioData = Data(base64Encoded: audio) {
            if !hasReceivedAudio {
                hasReceivedAudio = true
                onFirstAudioChunk()
            }
            audioPlayer.enqueue(audioData)
        }

        if response.isFinal == true {
            hasReceivedFinalResponse = true
            finalResponseContinuation?.resume()
            finalResponseContinuation = nil
            tearDown()
        }
    }

    private func send<T: Encodable>(_ message: T, logDescription: String) async throws {
        guard let webSocketTask else {
            return
        }

        let data = try jsonEncoder.encode(message)
        guard let string = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        try await webSocketTask.send(.string(string))
        print("[ElevenLabs] sent \(logDescription)")
    }

    private func closeTextStream(flush: Bool? = nil) async throws {
        try await send(TextMessage(text: "", flush: flush), logDescription: "end of stream")
    }

    private func waitForFinalResponse(timeout: Duration? = nil) async throws {
        guard !hasReceivedFinalResponse else {
            return
        }

        let timeoutTask = timeout.map { timeout in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self, !Task.isCancelled else { return }
                finalResponseContinuation?.resume(throwing: URLError(.timedOut))
                finalResponseContinuation = nil
            }
        }

        defer {
            timeoutTask?.cancel()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            finalResponseContinuation = continuation
        }
    }

    private func tearDown() {
        openContinuation?.resume(throwing: URLError(.cancelled))
        openContinuation = nil
        finalResponseContinuation?.resume(throwing: URLError(.cancelled))
        finalResponseContinuation = nil
        receiveTask?.cancel()
        receiveTask = nil
        stopKeepAlives()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        lastVisibleText = ""
    }
}

extension ElevenLabsTTSClient: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("[ElevenLabs] WebSocket connection opened")
        Task { @MainActor in
            onSocketOpen()
            openContinuation?.resume()
            openContinuation = nil
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        print("[ElevenLabs] WebSocket closed: code=\(closeCode.rawValue), reason=\(reasonString)")
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else {
            return
        }
        print("[ElevenLabs] connection failed: \(error)")
        Task { @MainActor in
            if let continuation = openContinuation {
                continuation.resume(throwing: error)
                openContinuation = nil
            } else {
                tearDown()
            }
        }
    }
}

private struct InitialMessage: Encodable {
    let text: String
    let xiApiKey: String
    let voiceSettings: VoiceSettings
    let generationConfig: GenerationConfig

    enum CodingKeys: String, CodingKey {
        case text
        case xiApiKey = "xi_api_key"
        case voiceSettings = "voice_settings"
        case generationConfig = "generation_config"
    }
}

private struct VoiceSettings: Encodable {
    let stability: Double
    let similarityBoost: Double
    let useSpeakerBoost: Bool

    enum CodingKeys: String, CodingKey {
        case stability
        case similarityBoost = "similarity_boost"
        case useSpeakerBoost = "use_speaker_boost"
    }
}

private struct GenerationConfig: Encodable {
    let chunkLengthSchedule: [Int]

    enum CodingKeys: String, CodingKey {
        case chunkLengthSchedule = "chunk_length_schedule"
    }
}

private struct TextMessage: Encodable {
    let text: String
    let flush: Bool?
}

private struct AudioResponse: Decodable {
    let audio: String?
    let isFinal: Bool?
}

private extension String {
    func delta(comparedTo previousText: String) -> String {
        guard !isEmpty else {
            return ""
        }

        if hasPrefix(previousText) {
            return String(dropFirst(previousText.count))
        }

        let sharedPrefixCount = zip(self, previousText).prefix { current, previous in
            current == previous
        }.count

        return String(dropFirst(sharedPrefixCount))
    }
}

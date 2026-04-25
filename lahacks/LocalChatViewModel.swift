import Foundation
import Observation

@MainActor
@Observable
final class LocalChatViewModel {
    var messages: [ChatMessage] = []
    var draft = ""
    var isLoadingModel = false
    var isGenerating = false
    var downloadProgress: Float?
    var errorMessage: String?

    private let client = LocalLLMClient()
    private var generationTask: Task<Void, Never>?

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating && !isLoadingModel
    }

    var statusText: String {
        if isLoadingModel {
            if let downloadProgress {
                "Downloading model \(downloadProgress.formatted(.percent.precision(.fractionLength(0))))"
            } else {
                "Preparing local model"
            }
        } else if isGenerating {
            "Generating on device"
        } else if !MelangeSecrets.isConfigured {
            "Add your Melange key and model name in MelangeSecrets.swift"
        } else {
            "Ready"
        }
    }

    func prepareModel() {
        guard MelangeSecrets.isConfigured else {
            errorMessage = "Add your Melange personal key and model name in MelangeSecrets.swift before loading Gemma."
            return
        }

        guard !isLoadingModel else {
            return
        }

        isLoadingModel = true
        errorMessage = nil

        generationTask = Task {
            do {
                try await client.prepare { [weak self] progress in
                    self?.downloadProgress = progress
                }
                downloadProgress = nil
            } catch {
                errorMessage = "Could not load the local model: \(error.localizedDescription)"
            }

            isLoadingModel = false
            generationTask = nil
        }
    }

    func sendDraft() {
        let promptText = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !promptText.isEmpty, !isGenerating, !isLoadingModel else {
            return
        }

        guard MelangeSecrets.isConfigured else {
            errorMessage = "Add your Melange personal key and model name in MelangeSecrets.swift before chatting."
            return
        }

        errorMessage = nil
        draft = ""

        messages.append(ChatMessage(role: .user, text: promptText))
        let prompt = Self.chatPrompt(from: messages)
        let assistantMessage = ChatMessage(role: .assistant, text: "")
        messages.append(assistantMessage)
        isGenerating = true

        generationTask = Task {
            do {
                try await client.generateResponse(for: prompt) { [weak self] text in
                    self?.replaceText(text, in: assistantMessage.id)
                }
            } catch {
                errorMessage = "Gemma could not generate a response: \(error.localizedDescription)"
                removeEmptyAssistantMessage(id: assistantMessage.id)
            }

            isGenerating = false
            generationTask = nil
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    func dismissError() {
        errorMessage = nil
    }

    private func replaceText(_ text: String, in messageID: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
            return
        }

        messages[index].text = text
    }

    private func removeEmptyAssistantMessage(id: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }), messages[index].text.isEmpty else {
            return
        }

        messages.remove(at: index)
    }

    private static func chatPrompt(from messages: [ChatMessage]) -> String {
        var prompt = """
        <start_of_turn>user
        You are a helpful, concise local tutor running on the user's iOS device. Answer clearly and keep the conversation natural. Return only the final answer. Do not include hidden reasoning, analysis, internal monologue, channel tags, or thinking process.<end_of_turn>

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
}

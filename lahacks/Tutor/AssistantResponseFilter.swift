import Foundation

nonisolated struct AssistantResponseFilter {
    private var rawText = ""

    mutating func append(_ token: String) -> AssistantResponseFilterOutput {
        rawText.append(token)

        return displayText(from: rawText)
    }

    private func displayText(from text: String) -> AssistantResponseFilterOutput {
        if let spokenAnswerRange = text.range(of: "SPOKEN_ANSWER:", options: [.caseInsensitive, .backwards]) {
            return AssistantResponseFilterOutput(
                visibleText: String(text[spokenAnswerRange.upperBound...]).trimmedGeneratedAnswer(),
                isSafeForSpeech: true
            )
        }

        if let finalRange = text.range(of: "<channel>final") ?? text.range(of: "<|channel|>final") {
            return AssistantResponseFilterOutput(
                visibleText: String(text[finalRange.upperBound...]).trimmedGeneratedAnswer(),
                isSafeForSpeech: true
            )
        }

        if let thoughtStartRange = text.range(of: "<channel>thought") ?? text.range(of: "<|channel|>thought") {
            let remainingText = String(text[thoughtStartRange.upperBound...])

            if let endThoughtRange = remainingText.range(of: "</channel>") ??
                remainingText.range(of: "<|channel|>") ??
                remainingText.range(of: "<channel|>") {
                return AssistantResponseFilterOutput(
                    visibleText: String(remainingText[endThoughtRange.upperBound...]).trimmedGeneratedAnswer(),
                    isSafeForSpeech: false
                )
            }

            return AssistantResponseFilterOutput(visibleText: "", isSafeForSpeech: false)
        }

        if let closingRange = text.range(of: "</channel>", options: .backwards) ??
            text.range(of: "<|channel|>", options: .backwards) ??
            text.range(of: "<channel|>", options: .backwards) {
            return AssistantResponseFilterOutput(
                visibleText: String(text[closingRange.upperBound...]).trimmedGeneratedAnswer(),
                isSafeForSpeech: false
            )
        }

        if text.isPotentialChannelMarkerPrefix {
            return AssistantResponseFilterOutput(visibleText: "", isSafeForSpeech: false)
        }

        return AssistantResponseFilterOutput(
            visibleText: text.trimmedGeneratedAnswer(),
            isSafeForSpeech: false
        )
    }
}

private extension String {
    func trimmedGeneratedAnswer() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isPotentialChannelMarkerPrefix: Bool {
        "<channel>thought".hasPrefix(self) ||
            "<|channel|>thought".hasPrefix(self) ||
            "<channel>final".hasPrefix(self) ||
            "<|channel|>final".hasPrefix(self) ||
            "SPOKEN_ANSWER:".hasPrefix(self.uppercased()) ||
            "</channel>".hasPrefix(self) ||
            "<|channel|>".hasPrefix(self) ||
            "<channel|>".hasPrefix(self)
    }
}

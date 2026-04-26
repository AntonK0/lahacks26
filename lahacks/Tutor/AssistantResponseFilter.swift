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
                visibleText: Self.spokenText(from: String(text[spokenAnswerRange.upperBound...])),
                isSafeForSpeech: true
            )
        }

        if let finalRange = text.range(of: "<channel>final") ?? text.range(of: "<|channel|>final") {
            return AssistantResponseFilterOutput(
                visibleText: Self.spokenText(from: String(text[finalRange.upperBound...])),
                isSafeForSpeech: true
            )
        }

        if let qwenThinkEndRange = text.range(of: "</think>", options: [.caseInsensitive, .backwards]) {
            return AssistantResponseFilterOutput(
                visibleText: Self.spokenText(from: String(text[qwenThinkEndRange.upperBound...])),
                isSafeForSpeech: true
            )
        }

        if text.range(of: "<think>", options: [.caseInsensitive]) != nil {
            return AssistantResponseFilterOutput(visibleText: "", isSafeForSpeech: false)
        }

        if let thoughtStartRange = text.range(of: "<channel>thought") ?? text.range(of: "<|channel|>thought") {
            let remainingText = String(text[thoughtStartRange.upperBound...])

            if let endThoughtRange = remainingText.range(of: "</channel>") ??
                remainingText.range(of: "<|channel|>") ??
                remainingText.range(of: "<channel|>") {
                return AssistantResponseFilterOutput(
                    visibleText: Self.spokenText(from: String(remainingText[endThoughtRange.upperBound...])),
                    isSafeForSpeech: false
                )
            }

            return AssistantResponseFilterOutput(visibleText: "", isSafeForSpeech: false)
        }

        if let closingRange = text.range(of: "</channel>", options: .backwards) ??
            text.range(of: "<|channel|>", options: .backwards) ??
            text.range(of: "<channel|>", options: .backwards) {
            return AssistantResponseFilterOutput(
                visibleText: Self.spokenText(from: String(text[closingRange.upperBound...])),
                isSafeForSpeech: false
            )
        }

        if text.isPotentialChannelMarkerPrefix {
            return AssistantResponseFilterOutput(visibleText: "", isSafeForSpeech: false)
        }

        return AssistantResponseFilterOutput(
            visibleText: Self.spokenText(from: text),
            isSafeForSpeech: false
        )
    }

    static func spokenText(from text: String) -> String {
        text
            .removingTaggedContent(openingTag: "<think>", closingTag: "</think>")
            .removingTrailingOpenTagContent("<think>")
            .trimmedGeneratedAnswer()
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
            "<THINK>".hasPrefix(self.uppercased()) ||
            "</THINK>".hasPrefix(self.uppercased()) ||
            "</channel>".hasPrefix(self) ||
            "<|channel|>".hasPrefix(self) ||
            "<channel|>".hasPrefix(self)
    }

    func removingTaggedContent(openingTag: String, closingTag: String) -> String {
        var result = self

        while let openingRange = result.range(of: openingTag, options: .caseInsensitive),
              let closingRange = result.range(of: closingTag, options: .caseInsensitive, range: openingRange.upperBound..<result.endIndex) {
            result.removeSubrange(openingRange.lowerBound..<closingRange.upperBound)
        }

        return result
    }

    func removingTrailingOpenTagContent(_ openingTag: String) -> String {
        guard let openingRange = range(of: openingTag, options: .caseInsensitive) else {
            return self
        }

        return String(self[..<openingRange.lowerBound])
    }
}

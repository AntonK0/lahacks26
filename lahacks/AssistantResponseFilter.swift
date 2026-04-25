import Foundation

nonisolated struct AssistantResponseFilter {
    private var rawText = ""

    mutating func append(_ token: String) -> String {
        rawText.append(token)

        return displayText(from: rawText)
    }

    private func displayText(from text: String) -> String {
        if let finalRange = text.range(of: "<channel>final") ?? text.range(of: "<|channel|>final") {
            return String(text[finalRange.upperBound...]).trimmedGeneratedAnswer()
        }

        if let thoughtStartRange = text.range(of: "<channel>thought") ?? text.range(of: "<|channel|>thought") {
            let remainingText = String(text[thoughtStartRange.upperBound...])

            if let endThoughtRange = remainingText.range(of: "</channel>") ??
                remainingText.range(of: "<|channel|>") ??
                remainingText.range(of: "<channel|>") {
                return String(remainingText[endThoughtRange.upperBound...]).trimmedGeneratedAnswer()
            }

            return ""
        }

        if let closingRange = text.range(of: "</channel>", options: .backwards) ??
            text.range(of: "<|channel|>", options: .backwards) ??
            text.range(of: "<channel|>", options: .backwards) {
            return String(text[closingRange.upperBound...]).trimmedGeneratedAnswer()
        }

        if text.isPotentialChannelMarkerPrefix {
            return ""
        }

        return text.trimmedGeneratedAnswer()
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
            "</channel>".hasPrefix(self) ||
            "<|channel|>".hasPrefix(self) ||
            "<channel|>".hasPrefix(self)
    }
}

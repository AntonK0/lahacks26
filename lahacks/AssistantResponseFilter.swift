import Foundation

struct AssistantResponseFilter {
    private var rawText = ""

    mutating func append(_ token: String) -> String {
        rawText.append(token)

        return displayText(from: rawText)
    }

    private func displayText(from text: String) -> String {
        if let finalRange = text.range(of: "<channel>final") {
            return String(text[finalRange.upperBound...]).trimmedGeneratedAnswer()
        }

        if let closingRange = text.range(of: "</channel>", options: .backwards) {
            return String(text[closingRange.upperBound...]).trimmedGeneratedAnswer()
        }

        if text.contains("<channel>thought") {
            return ""
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
        "<channel>thought".hasPrefix(self) || "<channel>final".hasPrefix(self) || "</channel>".hasPrefix(self)
    }
}

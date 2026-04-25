//
//  ISBN.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import Foundation

struct ISBN: Equatable {
    let value: String

    init?(barcodePayload: String) {
        let trimmedPayload = barcodePayload.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedPayload.count == 13,
              trimmedPayload.utf8.allSatisfy({ byte in byte >= 48 && byte <= 57 }),
              trimmedPayload.hasPrefix("978") || trimmedPayload.hasPrefix("979"),
              Self.hasValidISBN13CheckDigit(trimmedPayload) else {
            return nil
        }

        value = trimmedPayload
    }

    private static func hasValidISBN13CheckDigit(_ candidate: String) -> Bool {
        let digits = candidate.compactMap(\.wholeNumberValue)
        guard digits.count == 13 else {
            return false
        }

        let weightedSum = digits.dropLast().enumerated().reduce(0) { partialResult, item in
            let multiplier = item.offset.isMultiple(of: 2) ? 1 : 3
            return partialResult + item.element * multiplier
        }
        let expectedCheckDigit = (10 - weightedSum % 10) % 10

        return digits.last == expectedCheckDigit
    }
}

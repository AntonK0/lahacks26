//
//  TextbookServiceError.swift
//  lahacks
//

import Foundation

enum TextbookServiceError: LocalizedError {
    case redisNotConfigured
    case isbnNotFound(isbn: String)
    case redisRequestFailed(statusCode: Int)
    case redisHashMissingFields
    case redisResponseUnreadable
    case assetDownloadFailed(statusCode: Int)
    case noUSDCFiles

    var errorDescription: String? {
        switch self {
        case .redisNotConfigured:
            "Upstash Redis credentials are missing in MelangeSecrets."
        case .isbnNotFound(let isbn):
            "No textbook avatar is registered for ISBN \(isbn)."
        case .redisRequestFailed(let statusCode):
            "Upstash Redis request failed with status \(statusCode)."
        case .redisHashMissingFields:
            "The Redis hash is missing cloudinary_url/textbook_id fields."
        case .redisResponseUnreadable:
            "Upstash Redis returned a payload we could not decode."
        case .assetDownloadFailed(let statusCode):
            "Cloudinary asset download failed with status \(statusCode)."
        case .noUSDCFiles:
            "The downloaded USDZ archive did not contain any .usdc files."
        }
    }
}

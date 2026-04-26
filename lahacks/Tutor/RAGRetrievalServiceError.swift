import Foundation

enum RAGRetrievalServiceError: LocalizedError {
    case endpointNotConfigured
    case requestFailed(statusCode: Int)
    case responseUnreadable

    var errorDescription: String? {
        switch self {
        case .endpointNotConfigured:
            "The textbook retrieval endpoint is not configured."
        case .requestFailed(let statusCode):
            "Textbook retrieval failed with status \(statusCode)."
        case .responseUnreadable:
            "The textbook retrieval response could not be decoded."
        }
    }
}

import Foundation

struct RetrievalRequest: Codable, Equatable, Sendable {
    let isbn: String
    let message: String
    let limit: Int
    let numCandidates: Int?

    init(isbn: String, message: String, limit: Int = 5, numCandidates: Int? = nil) {
        self.isbn = isbn
        self.message = message
        self.limit = limit
        self.numCandidates = numCandidates
    }
}

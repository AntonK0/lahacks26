import Foundation

struct RetrievalResponse: Codable, Equatable, Sendable {
    let collection: String
    let index: String
    let isbn: String
    let count: Int
    let chunks: [RetrievedChunk]
}

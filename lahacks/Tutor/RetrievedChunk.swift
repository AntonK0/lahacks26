import Foundation

struct RetrievedChunk: Codable, Equatable, Sendable {
    let text: String
    let isbn: String?
    let sourceFile: String?
    let page: Int?
    let chunkIndex: Int?
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case text
        case isbn
        case sourceFile = "source_file"
        case page
        case chunkIndex = "chunk_index"
        case score
    }
}

//
//  RetrievalClient.swift
//  lahacks
//
//  Calls the FastAPI retrieval backend with an on-device query vector.
//

import Foundation

struct RetrievalRequest: Encodable {
    let queryVector: [Float]
    let textbookID: String?
    let isbn: String
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case queryVector
        case textbookID = "textbook_id"
        case isbn
        case limit
    }
}

struct RetrievedChunk: Decodable, Identifiable {
    var id: String {
        "\(sourceFile ?? "unknown")-\(page ?? 0)-\(chunkIndex ?? 0)"
    }

    let text: String
    let textbookID: String?
    let isbn: String?
    let sourceFile: String?
    let page: Int?
    let chunkIndex: Int?
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case text
        case textbookID = "textbook_id"
        case isbn
        case sourceFile = "source_file"
        case page
        case chunkIndex = "chunk_index"
        case score
    }
}

struct RetrievalResponse: Decodable {
    let collection: String
    let index: String
    let isbn: String
    let count: Int
    let chunks: [RetrievedChunk]
}

enum RetrievalClientError: Error {
    case invalidVectorDimension(Int)
    case invalidResponse
    case serverError(statusCode: Int, body: String)
}

final class RetrievalClient {
    private let endpointURL: URL
    private let session: URLSession
    private let expectedDimensions: Int

    init(
        endpointURL: URL,
        session: URLSession = .shared,
        expectedDimensions: Int = 768
    ) {
        self.endpointURL = endpointURL
        self.session = session
        self.expectedDimensions = expectedDimensions
    }

    func retrieveContext(
        queryVector: [Float],
        isbn: String,
        textbookID: String? = nil,
        limit: Int = 5
    ) async throws -> [RetrievedChunk] {
        guard queryVector.count == expectedDimensions else {
            throw RetrievalClientError.invalidVectorDimension(queryVector.count)
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RetrievalRequest(
                queryVector: queryVector,
                textbookID: textbookID,
                isbn: isbn,
                limit: limit
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RetrievalClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RetrievalClientError.serverError(statusCode: httpResponse.statusCode, body: body)
        }

        return try JSONDecoder().decode(RetrievalResponse.self, from: data).chunks
    }
}

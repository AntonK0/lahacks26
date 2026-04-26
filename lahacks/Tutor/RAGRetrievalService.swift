import Foundation

final class RAGRetrievalService {
    private let urlSession: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func retrieveContext(
        isbn: ISBN,
        message: String,
        limit: Int = 5,
        numCandidates: Int? = nil
    ) async throws -> RetrievalResponse {
        guard MelangeSecrets.isRetrievalConfigured,
              let endpointURL = URL(string: MelangeSecrets.retrievalEndpointURL) else {
            throw RAGRetrievalServiceError.endpointNotConfigured
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            RetrievalRequest(
                isbn: isbn.value,
                message: message,
                limit: limit,
                numCandidates: numCandidates
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RAGRetrievalServiceError.responseUnreadable
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RAGRetrievalServiceError.requestFailed(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(RetrievalResponse.self, from: data)
        } catch {
            throw RAGRetrievalServiceError.responseUnreadable
        }
    }
}

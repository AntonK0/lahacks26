//
//  TextbookService.swift
//  lahacks
//
//  Resolves a scanned ISBN into a downloaded, ready-to-render avatar bundle
//  by talking to Upstash Redis (REST API) and Cloudinary.
//

import Foundation

@Observable
@MainActor
final class TextbookService {
    private let urlSession: URLSession
    private let fileManager: FileManager

    init(urlSession: URLSession = .shared, fileManager: FileManager = .default) {
        self.urlSession = urlSession
        self.fileManager = fileManager
    }

    /// Looks up the textbook config in Upstash Redis, downloads the USDZ from
    /// Cloudinary, extracts its `.usdc` clips to a per-ISBN cache directory,
    /// and returns the resolved asset bundle alongside the original config.
    func loadTextbook(for isbn: ISBN) async throws -> (config: TextbookConfig, assets: RobotAvatarAssets) {
        let config = try await fetchConfig(for: isbn)
        let assets = try await downloadAndExtractAssets(from: config.assetURL, isbn: isbn)
        return (config, assets)
    }

    func fetchConfig(for isbn: ISBN) async throws -> TextbookConfig {
        guard MelangeSecrets.isUpstashConfigured,
              let baseURL = URL(string: MelangeSecrets.upstashRedisURL) else {
            throw TextbookServiceError.redisNotConfigured
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("HGETALL").appendingPathComponent(isbn.value))
        request.httpMethod = "GET"
        request.setValue("Bearer \(MelangeSecrets.upstashRedisToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextbookServiceError.redisResponseUnreadable
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TextbookServiceError.redisRequestFailed(statusCode: httpResponse.statusCode)
        }

        // The current Redis schema stores each ISBN as a hash:
        //   cloudinary_url -> .usdz URL
        //   textbook_id    -> Atlas collection/textbook identifier
        // Upstash returns HGETALL as a flat array:
        //   {"result":["cloudinary_url","https://...","textbook_id","college_prep"]}
        struct UpstashEnvelope: Decodable {
            let result: [String]?
        }

        let envelope: UpstashEnvelope
        do {
            envelope = try JSONDecoder().decode(UpstashEnvelope.self, from: data)
        } catch {
            throw TextbookServiceError.redisResponseUnreadable
        }

        guard let entries = envelope.result, !entries.isEmpty else {
            throw TextbookServiceError.isbnNotFound(isbn: isbn.value)
        }

        var hash: [String: String] = [:]
        var index = entries.startIndex
        while index + 1 < entries.endIndex {
            hash[entries[index]] = entries[index + 1]
            index += 2
        }

        guard let assetURLString = hash["cloudinary_url"] ?? hash["asset_url"],
              let assetURL = URL(string: assetURLString),
              let atlasCollection = hash["textbook_id"] ?? hash["atlas_collection"] else {
            throw TextbookServiceError.redisHashMissingFields
        }

        return TextbookConfig(assetURL: assetURL, atlasCollection: atlasCollection)
    }

    func downloadAndExtractAssets(from assetURL: URL, isbn: ISBN) async throws -> RobotAvatarAssets {
        let (downloadedURL, response) = try await urlSession.download(from: assetURL)
        defer {
            try? fileManager.removeItem(at: downloadedURL)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw TextbookServiceError.assetDownloadFailed(statusCode: httpResponse.statusCode)
        }

        let destination = try assetCacheDirectory(for: isbn)
        try? fileManager.removeItem(at: destination)

        let extracted = try await Task.detached(priority: .userInitiated) {
            try USDZArchive.extract(archiveURL: downloadedURL, into: destination)
        }.value

        let assets = RobotAvatarAssets(extractedFiles: extracted)
        guard assets.hasIdle else {
            throw TextbookServiceError.noUSDCFiles
        }
        return assets
    }

    private func assetCacheDirectory(for isbn: ISBN) throws -> URL {
        let caches = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return caches
            .appendingPathComponent("textbook-avatars", isDirectory: true)
            .appendingPathComponent(isbn.value, isDirectory: true)
    }
}

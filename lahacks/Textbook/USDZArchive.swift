//
//  USDZArchive.swift
//  lahacks
//
//  USDZ extractor.
//

import Foundation
import ZIPFoundation

enum USDZArchiveError: LocalizedError {
    case noExtractedFiles

    var errorDescription: String? {
        switch self {
        case .noExtractedFiles:
            "The downloaded USDZ archive did not extract any files."
        }
    }
}

enum USDZArchive {
    /// Extracts every entry of `archiveURL` into `destinationDirectory`.
    static func extract(archiveURL: URL, into destinationDirectory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: archiveURL, to: destinationDirectory)

        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: destinationDirectory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            throw USDZArchiveError.noExtractedFiles
        }

        let extractedURLs = enumerator.compactMap { item -> URL? in
            guard let url = item as? URL,
                  let values = try? url.resourceValues(forKeys: resourceKeys),
                  values.isRegularFile == true else {
                return nil
            }
            return url
        }

        guard !extractedURLs.isEmpty else {
            throw USDZArchiveError.noExtractedFiles
        }

        return extractedURLs
    }
}

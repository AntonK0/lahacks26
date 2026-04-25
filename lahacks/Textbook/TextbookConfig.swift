//
//  TextbookConfig.swift
//  lahacks
//
//  The lookup record returned by the Upstash Redis index for a given ISBN.
//

import Foundation

struct TextbookConfig: Codable, Equatable, Sendable {
    let assetURL: URL
    let atlasCollection: String

    init(assetURL: URL, atlasCollection: String) {
        self.assetURL = assetURL
        self.atlasCollection = atlasCollection
    }

    enum CodingKeys: String, CodingKey {
        case assetURL = "asset_url"
        case atlasCollection = "atlas_collection"
    }
}

//
//  RobotAvatarAssets.swift
//  lahacks
//
//  Resolved file URLs for the textbook avatar's animation clips. The values
//  may live in the app bundle (developer fallback) or in the on-disk cache
//  populated by `TextbookService` after extracting a Cloudinary-hosted USDZ.
//

import Foundation

struct RobotAvatarAssets: Equatable, Sendable {
    enum Animation: String, CaseIterable, Sendable {
        case idle = "Idle"
        case yes = "Yes"
        case no = "No"
        case wave = "Wave"
    }

    private let urls: [Animation: URL]

    init(extractedFiles: [URL]) {
        var map: [Animation: URL] = [:]
        for url in extractedFiles where url.pathExtension.lowercased() == "usdc" {
            let stem = url.deletingPathExtension().lastPathComponent
            if let animation = Animation(rawValue: stem) {
                map[animation] = url
            }
        }
        urls = map
    }

    private init(urls: [Animation: URL]) {
        self.urls = urls
    }

    static func bundledFallback(in bundle: Bundle = .main) -> RobotAvatarAssets? {
        var map: [Animation: URL] = [:]
        for animation in Animation.allCases {
            if let url = bundle.url(forResource: animation.rawValue, withExtension: "usdc") {
                map[animation] = url
            }
        }
        guard !map.isEmpty else {
            return nil
        }
        return RobotAvatarAssets(urls: map)
    }

    func url(for animation: Animation) -> URL? {
        urls[animation]
    }

    var hasIdle: Bool {
        urls[.idle] != nil
    }
}

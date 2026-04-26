import Foundation

struct LocalLLMStreamUpdate: Sendable {
    let rawToken: String
    let visibleText: String
    let isSafeForSpeech: Bool
    let generatedTokens: Int
}

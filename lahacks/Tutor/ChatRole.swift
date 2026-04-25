import Foundation

enum ChatRole: String {
    case user = "You"
    case assistant = "Gemma"

    var promptLabel: String {
        switch self {
        case .user:
            "User"
        case .assistant:
            "Gemma"
        }
    }
}

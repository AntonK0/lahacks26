import SwiftUI

enum SidebarItem: String, CaseIterable, Hashable, Identifiable {
    case home
    case scan
    case discover

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            "Home"
        case .scan:
            "Scan"
        case .discover:
            "Discover"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .scan:
            "barcode.viewfinder"
        case .discover:
            "books.vertical"
        }
    }
}

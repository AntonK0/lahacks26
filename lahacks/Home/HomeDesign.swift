import SwiftUI

enum HomeDesign {
    static let pageBackground = Color(red: 0.94, green: 0.94, blue: 0.94)
    static let heroGreen = Color(red: 0.25, green: 0.49, blue: 0.35)
    static let scanOrange = Color(red: 0.94, green: 0.59, blue: 0.32)
    static let selectedOrange = Color(red: 0.95, green: 0.46, blue: 0.25)
    static let systemReadyGreen = Color(red: 0.45, green: 0.68, blue: 0.25)
    static let cardGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    static let primaryLabel = Color.black
    static let vibrantPrimaryLabel = Color(red: 0.10, green: 0.10, blue: 0.10)

    static let sidebarWidth: CGFloat = 224
    static let sidebarCornerRadius: CGFloat = 20
    static let cardCornerRadius: CGFloat = 20
    static let pagePadding: CGFloat = 40
    static let sectionSpacing: CGFloat = 28
    static let heroHeight: CGFloat = 288
    static let heroMaxWidth: CGFloat = .infinity
    static let recommendationCoverSize: CGFloat = 190
    static let recommendationSpacing: CGFloat = 10
    static let recommendationRailHeight: CGFloat = 250

    static func spaceGrotesk(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("SpaceGrotesk-Light", size: size, relativeTo: textStyle)
        .weight(weight)
    }
}

import SwiftUI

struct RecommendationPageControl: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(HomeDesign.primaryLabel)
                .frame(width: 7, height: 7)

            Circle()
                .fill(.secondary)
                .frame(width: 7, height: 7)
        }
        .frame(height: 20)
        .accessibilityLabel("Page 1 of 2")
    }
}

#Preview {
    RecommendationPageControl()
        .padding()
        .background(HomeDesign.pageBackground)
}

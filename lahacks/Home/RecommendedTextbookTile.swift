import SwiftUI

struct RecommendedTextbookTile: View {
    let textbook: HomeTextbook

    var body: some View {
        Link(destination: textbook.purchaseURL) {
            VStack(alignment: .leading, spacing: 10) {
                TextbookCover(textbook: textbook, size: HomeDesign.recommendationCoverSize)

                Text(textbook.title)
                    .font(HomeDesign.spaceGrotesk(size: 23, relativeTo: .title3))
                    .foregroundStyle(HomeDesign.primaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: HomeDesign.recommendationCoverSize, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens purchase page")
    }
}

#Preview {
    RecommendedTextbookTile(
        textbook: HomeTextbook(
            id: "college-prep",
            title: "College Prep",
            imageName: "CollegePrepCover",
            purchaseURL: URL(string: "https://he.kendallhunt.com/product/openstax-college-success")!
        )
    )
    .padding()
    .background(HomeDesign.pageBackground)
}

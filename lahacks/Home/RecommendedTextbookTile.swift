import SwiftUI

struct RecommendedTextbookTile: View {
    let textbook: HomeTextbook

    var body: some View {
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
}

#Preview {
    RecommendedTextbookTile(
        textbook: HomeTextbook(
            id: "college-prep",
            title: "College Prep",
            imageName: "CollegePrepCover"
        )
    )
    .padding()
    .background(HomeDesign.pageBackground)
}

import SwiftUI

struct RecommendedForYouSection: View {
    private let textbooks = [
        HomeTextbook(id: "college-algebra", title: "College Algebra", imageName: "CollegeAlgebraCover"),
        HomeTextbook(id: "statistics", title: "Statistics", imageName: "StatisticsCover"),
        HomeTextbook(id: "college-prep", title: "College Prep", imageName: "CollegePrepCover"),
        HomeTextbook(id: "us-history", title: "US History", imageName: "USHistoryCover"),
        HomeTextbook(
            id: "introduction-to-python-programming",
            title: "Introduction To Python Programming",
            imageName: "IntroductionToPythonProgrammingWebCardCover"
        ),
        HomeTextbook(id: "psychology-2e", title: "Psychology 2e", imageName: "Psychology2eCover")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Recommended For You")
                .font(HomeDesign.spaceGrotesk(size: 32, weight: .bold, relativeTo: .title))
                .foregroundStyle(HomeDesign.primaryLabel)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: HomeDesign.recommendationSpacing) {
                    ForEach(textbooks) { textbook in
                        RecommendedTextbookTile(textbook: textbook)
                    }
                }
                .padding(.trailing, 8)
            }
            .scrollIndicators(.hidden)
            .frame(height: HomeDesign.recommendationRailHeight)
            .clipShape(.rect)

            RecommendationPageControl()
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    RecommendedForYouSection()
        .padding()
        .background(HomeDesign.pageBackground)
}

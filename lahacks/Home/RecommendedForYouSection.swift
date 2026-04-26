import SwiftUI

struct RecommendedForYouSection: View {
    private let textbooks = [
        HomeTextbook(
            id: "college-algebra",
            title: "College Algebra",
            imageName: "CollegeAlgebraCover",
            purchaseURL: URL(string: "https://he.kendallhunt.com/product/openstax-college-algebra-0")!
        ),
        HomeTextbook(
            id: "statistics",
            title: "Statistics",
            imageName: "StatisticsCover",
            purchaseURL: URL(string: "https://he.kendallhunt.com/product/openstax-statistics-high-school")!
        ),
        HomeTextbook(
            id: "college-prep",
            title: "College Prep",
            imageName: "CollegePrepCover",
            purchaseURL: URL(string: "https://he.kendallhunt.com/product/openstax-college-success")!
        ),
        HomeTextbook(
            id: "us-history",
            title: "US History",
            imageName: "USHistoryCover",
            purchaseURL: URL(string: "https://he.kendallhunt.com/product/openstax-us-history-0")!
        ),
        HomeTextbook(
            id: "introduction-to-python-programming",
            title: "Introduction To Python Programming",
            imageName: "IntroductionToPythonProgrammingWebCardCover",
            purchaseURL: URL(string: "https://www.barnesandnoble.com/w/introduction-to-python-programming-open-stax/1145566267")!
        ),
        HomeTextbook(
            id: "psychology-2e",
            title: "Psychology 2e",
            imageName: "Psychology2eCover",
            purchaseURL: URL(string: "https://he.kendallhunt.com/product/openstax-psychology-1")!
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Recommended For You")
                .font(HomeDesign.spaceGrotesk(size: 32, weight: .bold, relativeTo: .title))
                .foregroundStyle(HomeDesign.primaryLabel)
                .padding(.top, 30)

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

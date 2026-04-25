import SwiftUI

struct DiscoverTextbooksCard: View {
    var coverSize: CGFloat = 80

    private let textbooks = [
        HomeTextbook(id: "college-algebra", title: "College Algebra 2e", imageName: "CollegeAlgebraCover"),
        HomeTextbook(id: "statistics", title: "High School Statistics", imageName: "StatisticsCover"),
        HomeTextbook(id: "us-history", title: "U.S. History", imageName: "USHistoryCover"),
        HomeTextbook(id: "psychology", title: "Psychology 2e", imageName: "PsychologyCover")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Discover Textbooks")
                .font(.system(size: 32))
                .bold()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.8)

            Grid(horizontalSpacing: 14, verticalSpacing: 16) {
                GridRow {
                    ForEach(textbooks.prefix(3)) { textbook in
                        TextbookCover(textbook: textbook, size: coverSize)
                    }
                }

                GridRow {
                    TextbookCover(textbook: textbooks[3], size: coverSize)
                    Color.clear
                        .frame(width: coverSize, height: 1)
                    Color.clear
                        .frame(width: coverSize, height: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            HStack(spacing: 8) {
                Circle()
                    .fill(HomeDesign.primaryLabel)
                    .frame(width: 8, height: 8)

                Circle()
                    .fill(HomeDesign.primaryLabel.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Page 1 of 2")
        }
        .frame(maxWidth: .infinity, minHeight: 288, alignment: .topLeading)
        .padding(24)
        .background(HomeDesign.cardGray, in: .rect(cornerRadius: HomeDesign.cardCornerRadius))
    }
}

#Preview {
    DiscoverTextbooksCard()
        .padding()
}

import SwiftUI

struct HomeMainContent: View {
    let scanAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HomeDesign.sectionSpacing) {
            HeroScanCard(scanAction: scanAction)
                .frame(maxWidth: HomeDesign.heroMaxWidth, minHeight: HomeDesign.heroHeight)

            RecommendedForYouSection()
        }
        .padding(.horizontal, HomeDesign.pagePadding)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .background(HomeDesign.pageBackground)
    }
}

#Preview {
    HomeMainContent(scanAction: {})
}

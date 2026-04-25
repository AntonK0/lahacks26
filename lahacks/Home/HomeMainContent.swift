import SwiftUI

struct HomeMainContent: View {
    let scanAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let compactDetail = proxy.size.width < 640
            let lowerCardSpacing: CGFloat = compactDetail ? 20 : 62
            let heroToCardSpacing: CGFloat = compactDetail ? 24 : 36
            let heroHeight: CGFloat = compactDetail ? 260 : 288
            let availableWidth = proxy.size.width - (HomeDesign.pagePadding * 2)
            let lowerCardWidth = (availableWidth - lowerCardSpacing) / 2
            let availableLowerHeight = proxy.size.height - heroHeight - heroToCardSpacing - HomeDesign.pagePadding
            let lowerCardHeight = min(335, max(288, availableLowerHeight))

            VStack(spacing: heroToCardSpacing) {
                HeroScanCard(scanAction: scanAction)
                    .frame(height: heroHeight)
                    .layoutPriority(1)

                if compactDetail {
                    VStack(spacing: 20) {
                        DiscoverTextbooksCard()
                            .frame(height: lowerCardHeight)
                        JitsFoundCard(count: 22)
                            .frame(height: lowerCardHeight)
                    }
                } else {
                    HStack(alignment: .top, spacing: lowerCardSpacing) {
                        DiscoverTextbooksCard(coverSize: 80)
                            .frame(width: lowerCardWidth, height: lowerCardHeight)

                        JitsFoundCard(count: 22)
                            .frame(width: lowerCardWidth, height: lowerCardHeight)
                    }
                }
            }
            .padding(.horizontal, HomeDesign.pagePadding)
            .padding(.bottom, HomeDesign.pagePadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .background(Color.white)
    }
}

#Preview {
    HomeMainContent(scanAction: {})
}

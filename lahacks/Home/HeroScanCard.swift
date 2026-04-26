import SwiftUI

struct HeroScanCard: View {
    let scanAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 36) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Find a Jit")
                        .font(HomeDesign.spaceGrotesk(size: 56, weight: .bold, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("Start scanning the back of supported textbooks to discover new Jits!")
                        .font(HomeDesign.spaceGrotesk(size: 30, relativeTo: .title2))
                        .lineSpacing(3)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 430, alignment: .leading)
                }

                Button("Scan a Book", systemImage: "barcode.viewfinder", action: scanAction)
                    .font(HomeDesign.spaceGrotesk(size: 24, weight: .medium, relativeTo: .title3))
                    .foregroundStyle(HomeDesign.pageBackground)
                    .padding(.horizontal, 18)
                    .frame(minWidth: 210, minHeight: 54)
                    .background(HomeDesign.scanOrange, in: .rect(cornerRadius: HomeDesign.cardCornerRadius))
            }

            Spacer(minLength: 0)

            Image("RobotLineIcon")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 186, height: 186)
                .padding(.trailing, 18)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.vertical, 28)
        .background(HomeDesign.heroGreen, in: .rect(cornerRadius: HomeDesign.cardCornerRadius))
    }
}

#Preview {
    HeroScanCard(scanAction: {})
        .padding()
}

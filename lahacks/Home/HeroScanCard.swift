import SwiftUI

struct HeroScanCard: View {
    let scanAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Find a Jit")
                    .font(.system(size: 60, weight: .heavy))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)

                Text("Start scanning supported textbooks to discover new Jits.")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
            }

            Button("Scan a Book", systemImage: "barcode.viewfinder", action: scanAction)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .frame(minWidth: 245, minHeight: 54)
                .background(.white, in: .rect(cornerRadius: HomeDesign.cardCornerRadius))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .background(HomeDesign.accentBlue, in: .rect(cornerRadius: HomeDesign.cardCornerRadius))
    }
}

#Preview {
    HeroScanCard(scanAction: {})
        .padding()
}

import SwiftUI

struct JitsFoundCard: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 0) {
                Text(count, format: .number)
                    .font(.system(size: 64, weight: .heavy))

                Text("Jits Found")
                    .font(.system(size: 64, weight: .light))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.white)

            Spacer(minLength: 32)

            Text("Keep going, theres many to explore!")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 316, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 288, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .background(HomeDesign.cardGray, in: .rect(cornerRadius: HomeDesign.cardCornerRadius))
    }
}

#Preview {
    JitsFoundCard(count: 22)
        .padding()
}

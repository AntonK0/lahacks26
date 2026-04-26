import SwiftUI

struct GemmaReadinessIndicator: View {
    let isReady: Bool
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(isReady ? HomeDesign.systemReadyGreen : HomeDesign.scanOrange)
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)

            Text(title)
                .font(HomeDesign.spaceGrotesk(size: 15, relativeTo: .caption))
                .foregroundStyle(HomeDesign.primaryLabel)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(detail)
                .font(HomeDesign.spaceGrotesk(size: 15, weight: .light, relativeTo: .caption))
                .foregroundStyle(HomeDesign.primaryLabel)
                .lineLimit(1)
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
    }
}

#Preview {
    VStack {
        GemmaReadinessIndicator(isReady: false, title: "Gemma Not Ready", detail: "Preloading")
        GemmaReadinessIndicator(isReady: true, title: "Gemma Ready", detail: "Loaded on device")
    }
    .padding()
}

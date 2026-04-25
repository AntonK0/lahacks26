import SwiftUI

struct GemmaReadinessIndicator: View {
    let isReady: Bool
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isReady ? .green : .orange)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HomeDesign.primaryLabel)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.28), in: .rect(cornerRadius: 14))
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

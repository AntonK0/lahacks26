import SwiftUI

struct ChatErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
        }
        .padding()
        .background(.orange.opacity(0.14), in: .rect(cornerRadius: 16))
        .padding([.horizontal, .top])
    }
}

#Preview {
    ChatErrorBannerView(message: "Could not load the local model.", onDismiss: {})
}

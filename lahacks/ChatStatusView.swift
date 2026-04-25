import SwiftUI

struct ChatStatusView: View {
    let text: String
    let progress: Float?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .accessibilityHidden(true)

                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let progress {
                ProgressView(value: progress)
                    .accessibilityLabel("Model download progress")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }
}

#Preview {
    ChatStatusView(text: "Downloading model 42%", progress: 0.42)
}

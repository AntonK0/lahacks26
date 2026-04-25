import SwiftUI

struct ChatMessageRowView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user {
                Spacer(minLength: 48)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.role.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Group {
                    if message.text.isEmpty {
                        ProgressView("Generating answer")
                    } else {
                        Text(message.text)
                            .textSelection(.enabled)
                    }
                }
                .font(.body)
                .padding(14)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .background(message.role == .user ? .blue : .gray.opacity(0.16), in: .rect(cornerRadius: 18))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(message.role.rawValue): \(message.text.isEmpty ? "Generating answer" : message.text)")

            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatMessageRowView(message: ChatMessage(role: .assistant, text: "Local inference is ready."))
        ChatMessageRowView(message: ChatMessage(role: .user, text: "Explain vectors."))
    }
    .padding()
}

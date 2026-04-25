import SwiftUI

struct ChatComposerView: View {
    @Binding var draft: String
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message Gemma", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .submitLabel(.send)
                .onSubmit(sendIfPossible)

            Button("Send", systemImage: "paperplane.fill", action: onSend)
                .buttonStyle(.borderedProminent)
                .disabled(!canSend)
        }
        .padding()
        .background(.bar)
    }

    private func sendIfPossible() {
        guard canSend else {
            return
        }

        onSend()
    }
}

#Preview {
    @Previewable @State var draft = "What is local AI?"

    ChatComposerView(draft: $draft, canSend: true, onSend: {})
}

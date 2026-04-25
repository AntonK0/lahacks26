import SwiftUI

struct LocalChatView: View {
    @State private var viewModel = LocalChatViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            VStack(spacing: 0) {
                ChatStatusView(text: viewModel.statusText, progress: viewModel.downloadProgress)

                if let errorMessage = viewModel.errorMessage {
                    ChatErrorBannerView(message: errorMessage, onDismiss: viewModel.dismissError)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageRowView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages) {
                        scrollToLatestMessage(with: proxy)
                    }
                }

                ChatComposerView(
                    draft: $viewModel.draft,
                    canSend: viewModel.canSend,
                    onSend: viewModel.sendDraft
                )
            }
            .navigationTitle("Local Gemma")
            .toolbar {
                if viewModel.isGenerating {
                    Button("Stop", systemImage: "stop.fill", action: viewModel.cancelGeneration)
                }
            }
        }
        .task {
            viewModel.prepareModel()
        }
    }

    private func scrollToLatestMessage(with proxy: ScrollViewProxy) {
        guard let lastMessageID = viewModel.messages.last?.id else {
            return
        }

        withAnimation(.smooth) {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }
}

#Preview {
    LocalChatView()
}

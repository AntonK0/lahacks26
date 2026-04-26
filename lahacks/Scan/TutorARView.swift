//
//  TutorARView.swift
//  lahacks
//
//  Owns the post-scan pipeline: takes a freshly scanned ISBN, queries Upstash
//  Redis for the textbook's avatar config, downloads + extracts the USDZ from
//  Cloudinary, and renders the AR scene once the assets are ready.
//
//  Once the avatar is on screen, also hosts the voice tutor conversation
//  (mic toggle → SpeechAnalyzer → Gemma → ElevenLabs) and forwards the
//  resulting `isSpeaking` flag to the AR view so the avatar loops the Yes
//  animation while it talks back.
//

import SwiftUI

struct TutorARView: View {
    let isbn: ISBN
    let conversation: TutorConversationModel
    let scanAnotherBook: () -> Void

    @State private var service = TextbookService()
    @State private var loadState: LoadState = .loading
    @State private var loadAttempt = 0

    enum LoadState {
        case loading
        case loaded(RobotAvatarAssets, atlasCollection: String?)
        case failed(String)
    }

    var body: some View {
        ZStack(alignment: .top) {
            content

            scanAgainBanner
        }
        .task(id: loadAttempt) {
            await load()
        }
        .onDisappear {
            conversation.stopInteraction()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            loadingView

        case .loaded(let assets, _):
            ZStack(alignment: .bottom) {
                ARViewContainer(assets: assets, isSpeaking: conversation.isSpeaking)
                    .ignoresSafeArea()

                TutorConversationOverlay(conversation: conversation)
            }
            .task {
                conversation.prepareModel()
            }

        case .failed(let message):
            failureView(message: message)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading textbook avatar…")
                .font(.headline)
            Text("ISBN \(isbn.value)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func failureView(message: String) -> some View {
        ContentUnavailableView {
            Label("Avatar unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 8) {
                Text(message)
                Text("ISBN \(isbn.value)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } actions: {
            VStack(spacing: 12) {
                Button("Retry", systemImage: "arrow.clockwise", action: retry)
                    .buttonStyle(.borderedProminent)

                if let bundled = RobotAvatarAssets.bundledFallback() {
                    Button("Use Demo Avatar", systemImage: "cube.transparent") {
                        loadState = .loaded(bundled, atlasCollection: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var scanAgainBanner: some View {
        VStack(spacing: 8) {
            Text("ISBN \(isbn.value)")
                .font(.headline.monospacedDigit())

            Button("Scan Another Book", systemImage: "barcode.viewfinder", action: scanAnotherBook)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func retry() {
        loadState = .loading
        loadAttempt += 1
    }

    private func load() async {
        do {
            let result = try await service.loadTextbook(for: isbn)
            conversation.configureTextbook(isbn: isbn, atlasCollection: result.config.atlasCollection)
            loadState = .loaded(result.assets, atlasCollection: result.config.atlasCollection)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}

#Preview {
    TutorARView(
        isbn: ISBN(barcodePayload: "9780306406157")!,
        conversation: TutorConversationModel(),
        scanAnotherBook: {}
    )
}

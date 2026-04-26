//
//  MicToggleButton.swift
//  lahacks
//
//  Primary action control for the voice tutor HUD. The button has three roles:
//
//      • idle / listening    → mic toggle (start/stop recording)
//      • thinking / speaking → cancel the in-flight pipeline so the user can
//        recover from a slow Gemma response or a runaway TTS stream
//      • loadingModel / unavailable → disabled placeholder
//
//  Doing this with a single Capsule keeps the HUD calm — there's never two
//  buttons fighting for the user's attention while the AR scene is busy.
//

import SwiftUI

struct MicToggleButton: View {
    let state: TutorConversationModel.State
    let canToggle: Bool
    let canCancel: Bool
    let toggleMic: () -> Void
    let cancel: () -> Void

    var body: some View {
        Button(action: handleTap) {
            Label {
                Text(label)
                    .font(.headline)
            } icon: {
                Image(systemName: iconName)
                    .font(.title3)
                    .symbolEffect(
                        .pulse,
                        isActive: state == .listening || state == .retrieving || state == .thinking || state == .speaking
                    )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(minWidth: 240)
            .background(background, in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var isEnabled: Bool {
        canToggle || canCancel
    }

    private func handleTap() {
        if canToggle {
            toggleMic()
        } else if canCancel {
            cancel()
        }
    }

    private var iconName: String {
        switch state {
        case .listening: "stop.circle.fill"
        case .retrieving, .thinking, .speaking: "xmark.circle.fill"
        case .loadingModel, .unavailable: "mic.slash.circle.fill"
        case .idle: "mic.circle.fill"
        }
    }

    private var label: String {
        switch state {
        case .listening: "Stop & send"
        case .retrieving, .thinking: "Cancel"
        case .speaking: "Stop speaking"
        case .loadingModel: "Loading…"
        case .unavailable: "Unavailable"
        case .idle: "Talk to the tutor"
        }
    }

    private var background: Color {
        switch state {
        case .listening: .red
        case .retrieving, .thinking, .speaking: .orange
        case .loadingModel, .unavailable: .gray
        case .idle: .accentColor
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .listening: "Stop listening and send"
        case .retrieving: "Cancel textbook search"
        case .thinking: "Cancel tutor response"
        case .speaking: "Stop tutor speaking"
        case .loadingModel: "Loading tutor model"
        case .unavailable: "Tutor unavailable"
        case .idle: "Talk to the tutor"
        }
    }

    private var accessibilityHint: String {
        switch state {
        case .idle: "Starts listening to your question."
        case .listening: "Stops listening and sends your question to the tutor."
        case .retrieving: "Cancels the textbook search and returns to idle."
        case .thinking: "Cancels the on-device language model and returns to idle."
        case .speaking: "Stops the tutor mid-sentence and returns to idle."
        case .loadingModel: "Wait for the on-device model to finish loading."
        case .unavailable: "Check Melange and ElevenLabs configuration."
        }
    }
}

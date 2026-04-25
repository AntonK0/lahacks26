//
//  TutorConversationOverlay.swift
//  lahacks
//
//  Bottom HUD over the AR scene that exposes the voice tutor: a status panel,
//  optional live transcript / partial response, an error banner, and the mic
//  toggle button (which doubles as a Cancel button while the pipeline is busy).
//

import SwiftUI

struct TutorConversationOverlay: View {
    let conversation: TutorConversationModel

    var body: some View {
        VStack(spacing: 12) {
            if let errorMessage = conversation.errorMessage {
                TutorErrorBanner(message: errorMessage, dismiss: conversation.dismissError)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            TutorStatusPanel(
                state: conversation.state,
                statusMessage: conversation.statusMessage,
                liveTranscript: conversation.liveTranscript,
                partialAssistantText: conversation.partialAssistantText,
                thinkingStartedAt: conversation.thinkingStartedAt,
                rawTokenCount: conversation.rawTokenCount
            )

            MicToggleButton(
                state: conversation.state,
                canToggle: conversation.canToggleMic,
                canCancel: conversation.canCancelPipeline,
                toggleMic: conversation.toggleMic,
                cancel: conversation.cancelPipeline
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.easeInOut(duration: 0.2), value: conversation.errorMessage)
    }
}

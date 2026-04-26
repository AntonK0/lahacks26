//
//  TutorStatusPanel.swift
//  lahacks
//
//  Top half of the voice tutor HUD: a status badge with the current state's
//  message, plus a live transcript / partial response when relevant.
//
//  During `.thinking` the model can be silent for a long time — either because
//  Gemma is still doing prompt prefill on the CPU, or because the response
//  filter is suppressing thinking-channel tokens. To prove that progress is
//  being made we surface elapsed seconds + raw token-callback count in the
//  detail row, refreshed once a second via `TimelineView` so the UI animates
//  even when no token has arrived recently.
//

import SwiftUI

struct TutorStatusPanel: View {
    let state: TutorConversationModel.State
    let statusMessage: String
    let liveTranscript: String
    let partialAssistantText: String
    let thinkingStartedAt: Date?
    let rawTokenCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StatusIndicator(state: state)

                Text(statusMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            if state == .thinking, let startedAt = thinkingStartedAt {
                ThinkingProgressLabel(startedAt: startedAt, rawTokenCount: rawTokenCount)
            }

            if let detail = detailText {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var detailText: String? {
        switch state {
        case .listening:
            liveTranscript.isEmpty ? nil : liveTranscript
        case .thinking, .speaking:
            partialAssistantText.isEmpty ? nil : partialAssistantText
        default:
            nil
        }
    }
}

private struct StatusIndicator: View {
    let state: TutorConversationModel.State

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }

    private var tint: Color {
        switch state {
        case .idle: .secondary
        case .loadingModel: .orange
        case .listening: .red
        case .retrieving, .thinking: .yellow
        case .speaking: .green
        case .unavailable: .red
        }
    }
}

private struct ThinkingProgressLabel: View {
    let startedAt: Date
    let rawTokenCount: Int

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            Text(progressText(elapsed: elapsed))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(accessibilityLabel(elapsed: elapsed))
        }
    }

    private func progressText(elapsed: TimeInterval) -> String {
        let secondsLabel = "\(Int(elapsed))s elapsed"
        if rawTokenCount == 0 {
            return "\(secondsLabel) · prefilling prompt…"
        }
        return "\(secondsLabel) · \(rawTokenCount) tokens streamed"
    }

    private func accessibilityLabel(elapsed: TimeInterval) -> String {
        let seconds = Int(elapsed)
        if rawTokenCount == 0 {
            return "Thinking for \(seconds) seconds. Still preparing the prompt."
        }
        return "Thinking for \(seconds) seconds. \(rawTokenCount) tokens streamed."
    }
}

//
//  SpeechAnalyzerDemoView.swift
//  lahacks
//
//  Created by Cursor on 4/24/26.
//

import SwiftUI

struct SpeechAnalyzerDemoView: View {
    @State private var model = SpeechAnalyzerDemoModel()

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: model.isListening ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 72))
                .foregroundStyle(model.isListening ? .green : .blue)
                .symbolEffect(.pulse, isActive: model.isListening)
                .accessibilityHidden(true)

            Text("SpeechAnalyzer Demo")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(model.statusMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.12), in: .rect(cornerRadius: 16))
            }

            ScrollView {
                Text(model.transcript.isEmpty ? "Tap Start Listening and speak into the microphone." : model.transcript)
                    .font(.title3)
                    .foregroundStyle(model.transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxHeight: .infinity)
            .background(.thinMaterial, in: .rect(cornerRadius: 20))

            Button(model.isListening ? "Stop Listening" : "Start Listening", systemImage: model.isListening ? "stop.fill" : "mic.fill", action: model.toggleListening)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
        .navigationTitle("Speech")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: model.stopListening)
    }
}

#Preview {
    SpeechAnalyzerDemoView()
}

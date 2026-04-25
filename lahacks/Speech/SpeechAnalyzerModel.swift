//
//  SpeechAnalyzerModel.swift
//  lahacks
//
//  Created by Cursor on 4/24/26.
//

@preconcurrency import AVFoundation
import Observation
import Speech

@MainActor
@Observable
final class SpeechAnalyzerModel {
    private let audioEngine = AVAudioEngine()

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var audioConverter: AVAudioConverter?
    private var finalizedTranscript = ""

    var transcript = ""
    var statusMessage = "Ready to listen."
    var isListening = false
    var errorMessage: String?

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard !isListening else { return }

        errorMessage = nil
        transcript = ""
        finalizedTranscript = ""
        statusMessage = "Preparing SpeechAnalyzer..."

        Task {
            do {
                try await startSpeechAnalysis()
            } catch {
                stopAudioEngine()
                statusMessage = "Unable to start."
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopListening() {
        guard isListening || audioEngine.isRunning else { return }

        stopAudioEngine()
        statusMessage = "Finalizing transcript..."

        let analyzer = analyzer
        Task {
            await analyzer?.cancelAndFinishNow()
            statusMessage = "Stopped."
        }
    }

    private func startSpeechAnalysis() async throws {
        guard await requestMicrophonePermission() else {
            throw SpeechAnalyzerError.microphonePermissionDenied
        }

        guard SpeechTranscriber.isAvailable else {
            throw SpeechAnalyzerError.unsupportedDevice
        }

        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else {
            throw SpeechAnalyzerError.unsupportedLocale
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .progressiveTranscription
        )
        let modules: [any SpeechModule] = [transcriber]

        try await installAssetsIfNeeded(for: modules)
        try configureAudioSession()

        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        guard let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: modules,
            considering: inputFormat
        ) else {
            throw SpeechAnalyzerError.unavailableAudioInput
        }

        let analyzer = SpeechAnalyzer(
            modules: modules,
            options: .init(priority: .userInitiated, modelRetention: .whileInUse)
        )

        try await analyzer.prepareToAnalyze(in: analysisFormat)
        let inputSequence = try makeAudioInputSequence(
            inputFormat: inputFormat,
            analysisFormat: analysisFormat
        )

        self.analyzer = analyzer
        self.transcriber = transcriber
        observeResults(from: transcriber)

        try audioEngine.start()
        try await analyzer.start(inputSequence: inputSequence)

        isListening = true
        statusMessage = "Listening..."
    }

    private func installAssetsIfNeeded(for modules: [any SpeechModule]) async throws {
        let status = await AssetInventory.status(forModules: modules)

        switch status {
        case .installed:
            return
        case .supported, .downloading:
            statusMessage = "Installing speech assets..."

            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                try await request.downloadAndInstall()
            }
        case .unsupported:
            throw SpeechAnalyzerError.unsupportedDevice
        @unknown default:
            throw SpeechAnalyzerError.unsupportedDevice
        }
    }

    private func makeAudioInputSequence(
        inputFormat: AVAudioFormat,
        analysisFormat: AVAudioFormat
    ) throws -> AsyncStream<AnalyzerInput> {
        audioEngine.inputNode.removeTap(onBus: 0)

        let converter: AVAudioConverter? = if Self.audioFormatsMatch(inputFormat, analysisFormat) {
            nil
        } else {
            AVAudioConverter(from: inputFormat, to: analysisFormat)
        }

        if !Self.audioFormatsMatch(inputFormat, analysisFormat), converter == nil {
            throw SpeechAnalyzerError.unavailableAudioInput
        }

        audioConverter = converter

        let sequence = AsyncStream<AnalyzerInput> { continuation in
            inputContinuation = continuation
        }

        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 4_096,
            format: inputFormat
        ) { [inputContinuation, converter] buffer, _ in
            guard let analyzerBuffer = Self.convert(
                buffer,
                from: inputFormat,
                to: analysisFormat,
                using: converter
            ) else {
                return
            }

            inputContinuation?.yield(AnalyzerInput(buffer: analyzerBuffer))
        }

        return sequence
    }

    nonisolated private static func audioFormatsMatch(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
        lhs.sampleRate == rhs.sampleRate
            && lhs.channelCount == rhs.channelCount
            && lhs.commonFormat == rhs.commonFormat
            && lhs.isInterleaved == rhs.isInterleaved
    }

    nonisolated private static func convert(
        _ inputBuffer: AVAudioPCMBuffer,
        from inputFormat: AVAudioFormat,
        to outputFormat: AVAudioFormat,
        using converter: AVAudioConverter?
    ) -> AVAudioPCMBuffer? {
        guard let converter else {
            return inputBuffer
        }

        let sampleRateRatio = outputFormat.sampleRate / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * sampleRateRatio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputCapacity
        ) else {
            return nil
        }

        var didProvideInput = false
        var conversionError: NSError?

        converter.convert(to: outputBuffer, error: &conversionError) { _, outputStatus in
            if didProvideInput {
                outputStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outputStatus.pointee = .haveData
            return inputBuffer
        }

        return conversionError == nil ? outputBuffer : nil
    }

    private func observeResults(from transcriber: SpeechTranscriber) {
        resultsTask?.cancel()

        resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    updateTranscript(with: result)
                }
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Transcription failed."
                stopAudioEngine()
            }
        }
    }

    private func updateTranscript(with result: SpeechTranscriber.Result) {
        let text = String(result.text.characters)

        if result.isFinal {
            finalizedTranscript = [finalizedTranscript, text]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            transcript = finalizedTranscript
        } else {
            transcript = [finalizedTranscript, text]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func stopAudioEngine() {
        inputContinuation?.finish()
        inputContinuation = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        resultsTask?.cancel()
        resultsTask = nil

        audioConverter = nil
        analyzer = nil
        transcriber = nil
        isListening = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }
}

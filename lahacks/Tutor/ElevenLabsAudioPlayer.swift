import AVFoundation
import Foundation

@MainActor
final class ElevenLabsAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var queuedAudio: [Data] = []
    private var currentPlayer: AVAudioPlayer?
    private var idleContinuation: CheckedContinuation<Void, Never>?
    private var idleTimeoutTask: Task<Void, Never>?

    static func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }

    func enqueue(_ audioData: Data) {
        queuedAudio.append(audioData)
        playNextIfNeeded()
    }

    func stop() {
        currentPlayer?.stop()
        currentPlayer = nil
        queuedAudio.removeAll()
        idleTimeoutTask?.cancel()
        idleTimeoutTask = nil
        notifyIdleIfNeeded()
    }

    func waitUntilIdle(timeout: Duration? = nil) async {
        guard currentPlayer != nil || !queuedAudio.isEmpty else {
            return
        }

        await withCheckedContinuation { continuation in
            idleTimeoutTask?.cancel()
            idleContinuation = continuation
            guard let timeout else { return }

            idleTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard let self else { return }
                idleContinuation?.resume()
                idleContinuation = nil
                idleTimeoutTask = nil
            }
        }
    }

    private func playNextIfNeeded() {
        guard currentPlayer == nil, !queuedAudio.isEmpty else {
            return
        }

        let audioData = queuedAudio.removeFirst()

        do {
            let player = try AVAudioPlayer(data: audioData)
            player.delegate = self
            player.prepareToPlay()
            currentPlayer = player
            player.play()
        } catch {
            playNextIfNeeded()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            currentPlayer = nil
            playNextIfNeeded()
            notifyIdleIfNeeded()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            currentPlayer = nil
            playNextIfNeeded()
            notifyIdleIfNeeded()
        }
    }

    private func notifyIdleIfNeeded() {
        guard currentPlayer == nil, queuedAudio.isEmpty else {
            return
        }

        idleTimeoutTask?.cancel()
        idleTimeoutTask = nil
        idleContinuation?.resume()
        idleContinuation = nil
    }
}

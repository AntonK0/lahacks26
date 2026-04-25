//
//  SpeechAnalyzerError.swift
//  lahacks
//

import Foundation

enum SpeechAnalyzerError: LocalizedError {
    case microphonePermissionDenied
    case unsupportedDevice
    case unsupportedLocale
    case unavailableAudioInput

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            "Microphone access is required for live transcription."
        case .unsupportedDevice:
            "SpeechTranscriber is not available on this device."
        case .unsupportedLocale:
            "SpeechTranscriber does not support the current locale."
        case .unavailableAudioInput:
            "No compatible microphone format is available."
        }
    }
}

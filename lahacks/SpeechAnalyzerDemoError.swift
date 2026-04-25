//
//  SpeechAnalyzerDemoError.swift
//  lahacks
//
//  Created by Cursor on 4/24/26.
//

import Foundation

enum SpeechAnalyzerDemoError: LocalizedError {
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

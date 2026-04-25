//
//  ISBNBarcodeScannerError.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import Foundation

enum ISBNBarcodeScannerError: LocalizedError {
    case cameraUnavailable
    case cameraAccessDenied
    case cannotAddCameraInput
    case cannotAddMetadataOutput
    case ean13Unsupported

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "The back camera is not available on this device."
        case .cameraAccessDenied:
            "Camera access is required to scan a book barcode."
        case .cannotAddCameraInput:
            "The app could not connect to the camera."
        case .cannotAddMetadataOutput:
            "The app could not prepare barcode scanning."
        case .ean13Unsupported:
            "This device does not report EAN-13 barcodes through the camera metadata output."
        }
    }
}

//
//  ISBNBarcodeScannerModel.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import AVFoundation
import Observation

@Observable
@MainActor
final class ISBNBarcodeScannerModel {
    var scannedISBN: ISBN?
    var statusMessage = "Point the camera at the book's ISBN barcode."
    var errorMessage: String?
    var isScanning = false

    @ObservationIgnored
    private let sessionController = ISBNBarcodeSessionController()

    var captureSession: AVCaptureSession {
        sessionController.captureSession
    }

    init() {
        sessionController.onDetectedISBN = { [weak self] isbn in
            self?.scannedISBN = isbn
            self?.isScanning = false
            self?.errorMessage = nil
            self?.statusMessage = "ISBN \(isbn.value) scanned."
        }

        sessionController.onError = { [weak self] message in
            self?.isScanning = false
            self?.errorMessage = message
            self?.statusMessage = "Scanner unavailable."
        }
    }

    func startScanning() async {
        guard !isScanning else {
            return
        }

        scannedISBN = nil
        errorMessage = nil
        statusMessage = "Looking for an EAN-13 ISBN barcode..."
        isScanning = true
        await sessionController.startScanning()
    }

    func stopScanning() {
        sessionController.stopScanning()
        isScanning = false
    }
}

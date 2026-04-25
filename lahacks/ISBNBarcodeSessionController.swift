//
//  ISBNBarcodeSessionController.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

@preconcurrency import AVFoundation

final class ISBNBarcodeSessionController: NSObject {
    let captureSession = AVCaptureSession()

    var onDetectedISBN: @MainActor (ISBN) -> Void = { _ in }
    var onError: @MainActor (String) -> Void = { _ in }

    private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "lahacks.isbn-barcode.session")
    private let metadataQueue = DispatchQueue(label: "lahacks.isbn-barcode.metadata")
    private var isConfigured = false
    private var didEmitScanResult = false

    func startScanning() async {
        do {
            try await authorizeCameraIfNeeded()
            try configureSessionIfNeeded()
            didEmitScanResult = false

            await withCheckedContinuation { continuation in
                sessionQueue.async { [captureSession] in
                    if !captureSession.isRunning {
                        captureSession.startRunning()
                    }
                    continuation.resume()
                }
            }
        } catch {
            onError(error.localizedDescription)
        }
    }

    func stopScanning() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    private func authorizeCameraIfNeeded() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw ISBNBarcodeScannerError.cameraAccessDenied
            }
        case .denied, .restricted:
            throw ISBNBarcodeScannerError.cameraAccessDenied
        @unknown default:
            throw ISBNBarcodeScannerError.cameraAccessDenied
        }
    }

    private func configureSessionIfNeeded() throws {
        guard !isConfigured else {
            return
        }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw ISBNBarcodeScannerError.cameraUnavailable
        }

        let cameraInput = try AVCaptureDeviceInput(device: camera)

        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }

        captureSession.sessionPreset = .high

        guard captureSession.canAddInput(cameraInput) else {
            throw ISBNBarcodeScannerError.cannotAddCameraInput
        }
        captureSession.addInput(cameraInput)

        guard captureSession.canAddOutput(metadataOutput) else {
            throw ISBNBarcodeScannerError.cannotAddMetadataOutput
        }
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)

        guard metadataOutput.availableMetadataObjectTypes.contains(.ean13) else {
            throw ISBNBarcodeScannerError.ean13Unsupported
        }

        metadataOutput.metadataObjectTypes = [.ean13]
        isConfigured = true
    }

    private func handleMachineReadableCode(_ code: AVMetadataMachineReadableCodeObject) {
        guard !didEmitScanResult,
              code.type == .ean13,
              let payload = code.stringValue,
              let isbn = ISBN(barcodePayload: payload) else {
            return
        }

        didEmitScanResult = true
        stopScanning()

        Task { @MainActor [onDetectedISBN] in
            onDetectedISBN(isbn)
        }
    }
}

extension ISBNBarcodeSessionController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for metadataObject in metadataObjects {
            guard let machineReadableCode = metadataObject as? AVMetadataMachineReadableCodeObject else {
                continue
            }

            handleMachineReadableCode(machineReadableCode)
        }
    }
}

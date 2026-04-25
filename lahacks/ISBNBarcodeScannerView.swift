//
//  ISBNBarcodeScannerView.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import SwiftUI

struct ISBNBarcodeScannerView: View {
    let onISBNScanned: (ISBN) -> Void

    @State private var scannerModel = ISBNBarcodeScannerModel()

    init(onISBNScanned: @escaping (ISBN) -> Void = { _ in }) {
        self.onISBNScanned = onISBNScanned
    }

    var body: some View {
        ZStack {
            ISBNBarcodeCameraPreview(captureSession: scannerModel.captureSession)
                .ignoresSafeArea()

            ISBNBarcodeScannerOverlay(
                statusMessage: scannerModel.statusMessage,
                errorMessage: scannerModel.errorMessage,
                scannedISBN: scannerModel.scannedISBN,
                isScanning: scannerModel.isScanning,
                scanAgain: scanAgain
            )
        }
        .task {
            await scannerModel.startScanning()
        }
        .onChange(of: scannerModel.scannedISBN) {
            if let scannedISBN = scannerModel.scannedISBN {
                onISBNScanned(scannedISBN)
            }
        }
        .onDisappear(perform: scannerModel.stopScanning)
    }

    private func scanAgain() {
        Task {
            await scannerModel.startScanning()
        }
    }
}

#Preview {
    ISBNBarcodeScannerView()
}

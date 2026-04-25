//
//  ISBNBarcodeScannerStatus.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import SwiftUI

struct ISBNBarcodeScannerStatus: View {
    let statusMessage: String
    let errorMessage: String?
    let scannedISBN: ISBN?
    let isScanning: Bool
    let scanAgain: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let scannedISBN {
                Text("ISBN: \(scannedISBN.value)")
                    .font(.title2.monospacedDigit().bold())
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
            } else {
                Text(statusMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
            }

            if scannedISBN != nil || errorMessage != nil {
                Button("Scan Again", systemImage: "barcode.viewfinder", action: scanAgain)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if let scannedISBN {
            return "ISBN \(scannedISBN.value) scanned."
        }

        if let errorMessage {
            return errorMessage
        }

        return isScanning ? statusMessage : "ISBN barcode scanner is idle."
    }
}

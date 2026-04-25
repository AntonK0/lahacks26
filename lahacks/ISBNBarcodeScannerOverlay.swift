//
//  ISBNBarcodeScannerOverlay.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import SwiftUI

struct ISBNBarcodeScannerOverlay: View {
    let statusMessage: String
    let errorMessage: String?
    let scannedISBN: ISBN?
    let isScanning: Bool
    let scanAgain: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Scan Book ISBN")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white, lineWidth: 3)
                .frame(width: 300, height: 140)
                .overlay {
                    Text("Align barcode here")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.55), in: Capsule())
                }
                .accessibilityHidden(true)

            ISBNBarcodeScannerStatus(
                statusMessage: statusMessage,
                errorMessage: errorMessage,
                scannedISBN: scannedISBN,
                isScanning: isScanning,
                scanAgain: scanAgain
            )
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background {
            LinearGradient(
                colors: [.black.opacity(0.6), .clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

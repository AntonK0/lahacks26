//
//  ISBNBarcodeCameraPreview.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import AVFoundation
import SwiftUI

struct ISBNBarcodeCameraPreview: UIViewRepresentable {
    let captureSession: AVCaptureSession

    func makeUIView(context: Context) -> ISBNBarcodePreviewView {
        let view = ISBNBarcodePreviewView()
        view.previewLayer.session = captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: ISBNBarcodePreviewView, context: Context) {
        uiView.previewLayer.session = captureSession
    }
}

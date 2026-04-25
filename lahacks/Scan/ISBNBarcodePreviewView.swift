//
//  ISBNBarcodePreviewView.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import AVFoundation
import UIKit

final class ISBNBarcodePreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

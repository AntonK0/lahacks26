//
//  ISBNBarcodePreviewView.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import AVFoundation
import UIKit

final class ISBNBarcodePreviewView: UIView {
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationDeviceUniqueID: String?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyPreviewRotation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyPreviewRotation()
    }

    func configureRotation(for camera: AVCaptureDevice) {
        if rotationDeviceUniqueID != camera.uniqueID {
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: camera,
                previewLayer: previewLayer
            )
            rotationDeviceUniqueID = camera.uniqueID
        }

        applyPreviewRotation()
    }

    func applyPreviewRotation() {
        guard let connection = previewLayer.connection,
              let rotationCoordinator else {
            return
        }

        let angle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}

//
//  TutorARView.swift
//  lahacks
//
//  Created by Cursor on 4/25/26.
//

import RealityKit
import SwiftUI

struct TutorARView: View {
    let isbn: ISBN
    let scanAnotherBook: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            RealityView { content in
                let model = Entity()
                let mesh = MeshResource.generateBox(size: 0.1, cornerRadius: 0.005)
                let material = SimpleMaterial(color: .gray, roughness: 0.15, isMetallic: true)
                model.components.set(ModelComponent(mesh: mesh, materials: [material]))
                model.position = [0, 0.05, 0]

                let anchor = AnchorEntity(
                    .plane(.horizontal, classification: .any, minimumBounds: SIMD2<Float>(0.2, 0.2))
                )
                anchor.addChild(model)
                content.add(anchor)
                content.camera = .spatialTracking
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                Text("ISBN \(isbn.value)")
                    .font(.headline.monospacedDigit())

                Button("Scan Another Book", systemImage: "barcode.viewfinder", action: scanAnotherBook)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding()
        }
    }
}

#Preview {
    TutorARView(isbn: ISBN(barcodePayload: "9780306406157")!, scanAnotherBook: {})
}

//
//  ARViewContainer.swift
//  lahacks
//
//  SwiftUI wrapper around an ARKit `ARView` that places a textbook avatar on
//  a detected horizontal plane. The avatar's animation clips come from a
//  `RobotAvatarAssets` bundle, which can either be the freshly downloaded
//  Cloudinary archive or the in-bundle fallback.
//

import ARKit
import RealityKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    let assets: RobotAvatarAssets

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        arView.session.run(configuration)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        arView.addGestureRecognizer(pinch)

        context.coordinator.installAutoPlacedRobot(in: arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.assets = assets
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(assets: assets)
    }

    @MainActor
    final class Coordinator {
        var assets: RobotAvatarAssets

        private var robotAnchor: AnchorEntity?
        private var robotContainer: Entity?
        private var displayedRobot: Entity?
        private var animationController: AnimationPlaybackController?
        private var pendingNodTask: Task<Void, Never>?

        private var initialScale: SIMD3<Float> = [0.01, 0.01, 0.01]
        private let minScale: Float = 0.01
        private let maxScale: Float = 0.02

        init(assets: RobotAvatarAssets) {
            self.assets = assets
        }

        deinit {
            pendingNodTask?.cancel()
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = recognizer.view as? ARView else {
                return
            }

            let tapLocation = recognizer.location(in: arView)

            if isTapOnPlacedRobot(arView.entity(at: tapLocation)) {
                playNod()
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let entity = robotContainer else {
                return
            }

            switch recognizer.state {
            case .began:
                initialScale = entity.scale

            case .changed:
                let scaleFactor = Float(recognizer.scale)
                let proposedScale = initialScale * scaleFactor
                entity.scale = SIMD3<Float>(
                    x: max(minScale, min(maxScale, proposedScale.x)),
                    y: max(minScale, min(maxScale, proposedScale.y)),
                    z: max(minScale, min(maxScale, proposedScale.z))
                )

            case .cancelled:
                entity.scale = initialScale

            default:
                break
            }
        }

        func installAutoPlacedRobot(in arView: ARView) {
            guard robotAnchor == nil else {
                return
            }

            guard let idleRobot = makeRobotEntity(for: .idle) else {
                return
            }

            pendingNodTask?.cancel()
            pendingNodTask = nil

            let anchorEntity = AnchorEntity(
                .plane(
                    .horizontal,
                    classification: .any,
                    minimumBounds: SIMD2<Float>(0.2, 0.2)
                )
            )
            let container = Entity()
            container.name = "PlacedRobotContainer"
            container.scale = [0.01, 0.01, 0.01]
            container.addChild(idleRobot)

            anchorEntity.addChild(container)
            arView.scene.addAnchor(anchorEntity)

            robotAnchor = anchorEntity
            robotContainer = container
            displayedRobot = idleRobot
            playFirstAnimation(on: idleRobot, looping: true)
        }

        private func playNod() {
            guard robotContainer != nil, pendingNodTask == nil else {
                return
            }

            guard let nodRobot = makeRobotEntity(for: .yes) else {
                return
            }

            swapDisplayedRobot(to: nodRobot)
            playFirstAnimation(on: nodRobot, looping: false)

            let nodDuration = max(animationController?.duration ?? 1.5, 0.1)

            pendingNodTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(nodDuration))
                guard let self else {
                    return
                }
                self.pendingNodTask = nil

                guard !Task.isCancelled else {
                    return
                }

                guard let idleRobot = self.makeRobotEntity(for: .idle) else {
                    return
                }
                self.swapDisplayedRobot(to: idleRobot)
                self.playFirstAnimation(on: idleRobot, looping: true)
            }
        }

        private func makeRobotEntity(for animation: RobotAvatarAssets.Animation) -> Entity? {
            guard let url = assets.url(for: animation) else {
                return nil
            }

            do {
                let entity = try Entity.load(contentsOf: url)
                entity.generateCollisionShapes(recursive: true)
                return entity
            } catch {
                return nil
            }
        }

        private func swapDisplayedRobot(to robot: Entity) {
            displayedRobot?.removeFromParent()
            robotContainer?.addChild(robot)
            displayedRobot = robot
        }

        private func playFirstAnimation(on entity: Entity, looping: Bool) {
            animationController?.stop()

            guard let animation = entity.availableAnimations.first else {
                return
            }

            let resolved = looping ? animation.repeat(duration: .infinity) : animation
            animationController = entity.playAnimation(
                resolved,
                transitionDuration: 0.2,
                startsPaused: false
            )
        }

        private func isTapOnPlacedRobot(_ entity: Entity?) -> Bool {
            guard let robotContainer, var current = entity else {
                return false
            }
            while true {
                if current == robotContainer {
                    return true
                }
                guard let parent = current.parent else {
                    return false
                }
                current = parent
            }
        }
    }
}

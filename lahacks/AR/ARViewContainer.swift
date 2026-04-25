//
//  ARViewContainer.swift
//  lahacks
//
//  SwiftUI wrapper around an ARKit `ARView` that places a textbook avatar on
//  a detected horizontal plane. The avatar's animation clips come from a
//  `RobotAvatarAssets` bundle, which can either be the freshly downloaded
//  Cloudinary archive or the in-bundle fallback.
//
//  Animation behaviour:
//      • On spawn, plays the `Wave` clip once before transitioning to a looping
//        `Idle`. (If `Wave` isn't bundled, falls back to `Idle` immediately.)
//      • While `isSpeaking` is true, swaps to a looping `Yes` clip so the
//        avatar appears to be talking; restores the looping `Idle` when it
//        becomes false again.
//      • Pinch gesture continues to scale the avatar.
//

import ARKit
import RealityKit
import SwiftUI

struct ARViewContainer: UIViewRepresentable {
    let assets: RobotAvatarAssets
    let isSpeaking: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        arView.session.run(configuration)

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
        context.coordinator.applySpeakingState(isSpeaking)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.tearDown()
        uiView.gestureRecognizers?.forEach(uiView.removeGestureRecognizer)
        uiView.scene.anchors.removeAll()
        uiView.session.pause()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(assets: assets)
    }

    @MainActor
    final class Coordinator {
        var assets: RobotAvatarAssets

        private enum LoopMode { case idle, speaking }

        private var robotAnchor: AnchorEntity?
        private var robotContainer: Entity?
        private var displayedRobot: Entity?
        private var animationController: AnimationPlaybackController?
        private var spawnTransitionTask: Task<Void, Never>?

        private var lastAppliedSpeaking = false
        private var currentLoopMode: LoopMode = .idle
        private var hasFinishedSpawnSequence = false

        private var initialScale: SIMD3<Float> = [0.01, 0.01, 0.01]
        private let minScale: Float = 0.01
        private let maxScale: Float = 0.02

        init(assets: RobotAvatarAssets) {
            self.assets = assets
        }

        deinit {
            spawnTransitionTask?.cancel()
        }

        func tearDown() {
            spawnTransitionTask?.cancel()
            spawnTransitionTask = nil
            animationController?.stop()
            animationController = nil
            displayedRobot?.removeFromParent()
            displayedRobot = nil
            robotContainer?.removeFromParent()
            robotContainer = nil
            robotAnchor?.removeFromParent()
            robotAnchor = nil
            hasFinishedSpawnSequence = false
            lastAppliedSpeaking = false
            currentLoopMode = .idle
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

            let initialAnimation: RobotAvatarAssets.Animation = assets.url(for: .wave) != nil ? .wave : .idle
            guard let initialRobot = makeRobotEntity(for: initialAnimation) else {
                return
            }

            spawnTransitionTask?.cancel()
            spawnTransitionTask = nil

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
            container.addChild(initialRobot)

            anchorEntity.addChild(container)
            arView.scene.addAnchor(anchorEntity)

            robotAnchor = anchorEntity
            robotContainer = container
            displayedRobot = initialRobot

            if initialAnimation == .wave {
                playFirstAnimation(on: initialRobot, looping: false)
                scheduleSpawnTransitionToIdle(after: animationController?.duration ?? 2.0)
            } else {
                playFirstAnimation(on: initialRobot, looping: true)
                hasFinishedSpawnSequence = true
                currentLoopMode = .idle
            }
        }

        func applySpeakingState(_ speaking: Bool) {
            guard lastAppliedSpeaking != speaking else { return }
            lastAppliedSpeaking = speaking

            if speaking {
                spawnTransitionTask?.cancel()
                spawnTransitionTask = nil
                hasFinishedSpawnSequence = true
                switchLoop(to: .speaking)
            } else {
                if !hasFinishedSpawnSequence {
                    return
                }
                switchLoop(to: .idle)
            }
        }

        private func scheduleSpawnTransitionToIdle(after seconds: TimeInterval) {
            let duration = max(seconds, 0.1)
            spawnTransitionTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard let self, !Task.isCancelled else { return }
                self.spawnTransitionTask = nil
                self.hasFinishedSpawnSequence = true
                if self.lastAppliedSpeaking {
                    self.switchLoop(to: .speaking)
                } else {
                    self.switchLoop(to: .idle)
                }
            }
        }

        private func switchLoop(to mode: LoopMode) {
            guard robotContainer != nil else { return }

            let animation: RobotAvatarAssets.Animation = mode == .speaking ? .yes : .idle
            guard let entity = makeRobotEntity(for: animation) else {
                return
            }

            swapDisplayedRobot(to: entity)
            playFirstAnimation(on: entity, looping: true)
            currentLoopMode = mode
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
    }
}

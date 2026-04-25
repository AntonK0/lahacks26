

import SwiftUI
import RealityKit
import ARKit

// ARViewContainer bridges a RealityKit ARView into SwiftUI and handles tap/pinch gestures to place and scale a 3D model.

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        // Create the RealityKit ARView that renders the AR scene
        let arView = ARView(frame: .zero)
        
        // Configure world tracking (6DOF) with plane detection and optional scene reconstruction
        let config = ARWorldTrackingConfiguration()
        
        // Detect horizontal planes (tables, floors). Add .vertical if you need walls
        config.planeDetection = [.horizontal]
        
        // Enable scene reconstruction (meshing) when available for improved understanding/occlusion
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        // Start the AR session with our configuration
        arView.session.run(config)
        
        // Add a tap gesture recognizer to place the model on a detected surface
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // Add a pinch gesture recognizer to scale the last-placed model
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinchGesture)
        
        // Return the configured ARView to SwiftUI
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // No dynamic updates needed for now; ARView is driven by gestures and ARSession
    }
    
    // Create a coordinator to act as the target for UIKit gestures and hold transient AR state
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        // Holds references to the placed robot and implements gesture handlers for placing/scaling.
        
        // Container for the current robot. Scaling stays here while animation assets swap underneath.
        var selectedEntity: Entity?
        var robotAnchor: AnchorEntity?
        var robotContainer: Entity?
        var displayedRobot: Entity?
        var animationController: AnimationPlaybackController?
        var isPlayingNod = false
        
        // Scale captured at the beginning of a pinch gesture
        var initialScale: SIMD3<Float> = [0.01, 0.01, 0.01]
        
        // Clamp scaling so the model stays within a reasonable size range
        let minScale: Float = 0.01
        let maxScale: Float = 0.02
        
        // tap gesture
        
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            // Ensure the gesture is attached to an ARView
            guard let arView = recognizer.view as? ARView else { return }
            
            // Screen-space location of the tap
            let tapLocation = recognizer.location(in: arView)
            
            // Tapping the placed robot triggers the nod instead of placing a new robot.
            if isTapOnPlacedRobot(arView.entity(at: tapLocation)) {
                playNod()
                return
            }
            
            // Raycast from the tap into the real world to find a horizontal surface
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
            
            // If no surface was found, guide the user
            guard let firstResult = results.first else {
                print("No surface was found - point camera at flat surface")
                return
            }
            
            placeIdleRobot(at: firstResult.worldTransform, in: arView)
        }
        
        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer){
            
            // Require a selected entity to scale (tap to place one first)
            guard let entity = selectedEntity else {
                print("No entity is selected tap to place an object first")
                return
            }
            
            // Track the gesture lifecycle to compute relative scaling
            switch recognizer.state {
            case .began:
                // Capture the starting scale at gesture begin
                initialScale = entity.scale
                print("Started scaling from \(initialScale)")
                
            case .changed:
                // Apply the gesture's scale factor relative to the initial scale
                let scale = Float(recognizer.scale)
                let newScale = initialScale * scale
                
                // Clamp the new scale to the allowed range
                let clampedScale = SIMD3<Float>(
                    x: max(minScale, min(maxScale, newScale.x)),
                    y: max(minScale, min(maxScale, newScale.y)),
                    z: max(minScale, min(maxScale, newScale.z))
                )
                entity.scale = clampedScale
                
            case .ended:
                // Gesture ended; keep the resulting scale
                print("final scale \(entity.scale)")
                
            case .cancelled:
                // Revert to the original scale if the gesture was cancelled
                entity.scale = initialScale
                print("Scale cancelled")
                
            default: break
                
            }
        }
        
        private func placeIdleRobot(at worldTransform: simd_float4x4, in arView: ARView) {
            guard let idleRobot = makeRobotEntity(named: "Idle") else { return }
            
            robotAnchor?.removeFromParent()
            
            let anchorEntity = AnchorEntity(world: worldTransform)
            let container = Entity()
            container.name = "PlacedRobotContainer"
            container.scale = [0.01, 0.01, 0.01]
            container.addChild(idleRobot)
            
            anchorEntity.addChild(container)
            arView.scene.addAnchor(anchorEntity)
            
            robotAnchor = anchorEntity
            robotContainer = container
            displayedRobot = idleRobot
            selectedEntity = container
            playFirstAnimation(on: idleRobot, looping: true)
            
            print("Placed Idle robot - pinch to scale, tap robot to nod")
        }
        
        private func playNod() {
            guard robotContainer != nil, !isPlayingNod else { return }
            guard let nodRobot = makeRobotEntity(named: "Yes") else { return }
            
            isPlayingNod = true
            swapDisplayedRobot(to: nodRobot)
            playFirstAnimation(on: nodRobot, looping: false)
            
            let nodDuration = max(animationController?.duration ?? 1.5, 0.1)
            DispatchQueue.main.asyncAfter(deadline: .now() + nodDuration) { [weak self] in
                guard let self else { return }
                self.isPlayingNod = false
                
                guard let idleRobot = self.makeRobotEntity(named: "Idle") else { return }
                self.swapDisplayedRobot(to: idleRobot)
                self.playFirstAnimation(on: idleRobot, looping: true)
            }
            
            print("Playing Yes nod animation")
        }
        
        private func makeRobotEntity(named assetName: String) -> Entity? {
            let resourceNames = ["robot_assets/\(assetName)", assetName]
            
            for resourceName in resourceNames {
                if let entity = try? Entity.load(named: resourceName) {
                    entity.generateCollisionShapes(recursive: true)
                    return entity
                }
            }
            
            print("Failed to load \(assetName).usdc from robot_assets")
            return nil
        }
        
        private func swapDisplayedRobot(to robot: Entity) {
            displayedRobot?.removeFromParent()
            robotContainer?.addChild(robot)
            displayedRobot = robot
        }
        
        private func playFirstAnimation(on entity: Entity, looping: Bool) {
            animationController?.stop()
            
            guard let animation = entity.availableAnimations.first else {
                print("\(entity.name) does not contain an animation")
                return
            }
            
            let animationToPlay = looping ? animation.repeat(duration: .infinity) : animation
            animationController = entity.playAnimation(animationToPlay, transitionDuration: 0.2, startsPaused: false)
        }
        
        private func isTapOnPlacedRobot(_ entity: Entity?) -> Bool {
            guard var currentEntity = entity, let robotContainer else { return false }
            
            while true {
                if currentEntity == robotContainer {
                    return true
                }
                
                guard let parent = currentEntity.parent else {
                    return false
                }
                
                currentEntity = parent
            }
        }
        
    }
    
}


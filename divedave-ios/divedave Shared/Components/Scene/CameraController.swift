//
//  CameraController.swift
//  divedave iOS
//
//  Owns the SKCameraNode for DiveScene and runs the follow + clamp
//  logic that used to live inside DiveScene.setupCamera/updateCamera.
//

import SpriteKit

@MainActor
final class CameraController {
    let node: SKCameraNode

    init(scene: SKScene) {
        self.node = SKCameraNode()
        scene.camera = node
        scene.addChild(node)
    }

    /// Move the camera to follow `targetY`, clamped vertically to the scene
    /// bounds so we never reveal off-world area above or below.
    /// Reads the current scene height from `GameState.shared`.
    func follow(targetY: CGFloat) {
        let viewHeight = GameState.shared.metrics.height
        let centerX = GameState.shared.metrics.width / 2
        let sceneHeight = GameState.shared.sceneHeight

        let minY = viewHeight / 2
        let maxY = sceneHeight - viewHeight / 2
        let clamped = max(minY, min(targetY, maxY))
        node.position = CGPoint(x: centerX, y: clamped)
    }
}

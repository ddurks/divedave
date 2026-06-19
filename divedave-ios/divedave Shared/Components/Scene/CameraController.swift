//
//  CameraController.swift
//  divedave iOS
//
//  Owns the SKCameraNode for DiveScene and runs the follow + clamp
//  logic. Also applies a per-frame shake offset on top of the clamped
//  position so impacts (board flex, splash) feel weighty.
//

import SpriteKit

@MainActor
final class CameraController {
    let node: SKCameraNode

    /// Remaining shake magnitude in points. Decays toward 0 each frame in `follow(...)`.
    private var shakeIntensity: CGFloat = 0
    /// How fast `shakeIntensity` decays back to zero (points per second).
    private var shakeDecay: CGFloat = 0
    private var lastShakeTime: TimeInterval = 0

    init(scene: SKScene) {
        self.node = SKCameraNode()
        scene.camera = node
        scene.addChild(node)
    }

    /// Move the camera to follow `targetY`, clamped vertically to the scene
    /// bounds so we never reveal off-world area above or below. Also applies
    /// the current shake offset so impacts feel weighty.
    func follow(targetY: CGFloat) {
        let viewHeight = GameState.shared.metrics.height
        let centerX = GameState.shared.metrics.width / 2
        let sceneHeight = GameState.shared.sceneHeight

        let minY = viewHeight / 2
        let maxY = sceneHeight - viewHeight / 2
        let clamped = max(minY, min(targetY, maxY))

        let (offsetX, offsetY) = consumeShakeOffset()
        node.position = CGPoint(x: centerX + offsetX, y: clamped + offsetY)
    }

    /// Kick off a screen shake. Intensity is the peak displacement in points;
    /// duration is approximate seconds-to-zero. Call repeatedly to layer impacts.
    func shake(intensity: CGFloat, duration: TimeInterval = 0.25) {
        // Take the stronger of any in-flight shake — letting a tiny ongoing shake
        // suppress a fresh big one would feel wrong.
        shakeIntensity = max(shakeIntensity, intensity)
        shakeDecay = shakeIntensity / CGFloat(max(duration, 0.001))
        lastShakeTime = CACurrentMediaTime()
    }

    /// Sample a random offset within the current shake magnitude, then decay
    /// the magnitude by `shakeDecay * dt`. Returns (0, 0) when no shake is active.
    private func consumeShakeOffset() -> (CGFloat, CGFloat) {
        guard shakeIntensity > 0 else { return (0, 0) }

        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastShakeTime)
        lastShakeTime = now

        let dx = CGFloat.random(in: -shakeIntensity...shakeIntensity)
        let dy = CGFloat.random(in: -shakeIntensity...shakeIntensity)

        shakeIntensity = max(0, shakeIntensity - shakeDecay * dt)
        if shakeIntensity == 0 { shakeDecay = 0 }

        return (dx, dy)
    }
}

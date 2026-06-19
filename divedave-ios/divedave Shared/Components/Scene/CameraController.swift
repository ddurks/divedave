import SpriteKit

@MainActor
final class CameraController {
    let node: SKCameraNode

    private var shakeIntensity: CGFloat = 0
    private var shakeDecay: CGFloat = 0
    private var lastShakeTime: TimeInterval = 0

    init(scene: SKScene) {
        self.node = SKCameraNode()
        scene.camera = node
        scene.addChild(node)
    }

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

    func shake(intensity: CGFloat, duration: TimeInterval = 0.25) {
        shakeIntensity = max(shakeIntensity, intensity)
        shakeDecay = shakeIntensity / CGFloat(max(duration, 0.001))
        lastShakeTime = CACurrentMediaTime()
    }

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

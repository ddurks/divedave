import SpriteKit

@MainActor
final class RotationTracker {
    private(set) var currentVelocity: CGFloat = Game.minSpinVelocity
    private(set) var tucked: Bool = false
    private(set) var tuckCount: Int = 0
    private(set) var totalRotations: Double = 0.0

    private var sumRotation: CGFloat = 0
    private var previousAngle: CGFloat = 0
    private var currentAngle: CGFloat = 0
    private var lastFlipNumber: Double = 0
    private var lastUpdateTime: TimeInterval

    init() {
        lastUpdateTime = CACurrentMediaTime()
    }

    func reset() {
        sumRotation = 0
        totalRotations = 0
        previousAngle = 0
        currentAngle = 0
        lastFlipNumber = 0
        tuckCount = 0
        tucked = false
    }

    func resetTuck() {
        tucked = false
        currentVelocity = Game.minSpinVelocity
    }

    func beginTuck() {
        tucked = true
        tuckCount += 1
    }

    func incrementSpin() {
        if currentVelocity < Game.maxSpinVelocity - (200.0 * .pi / 180.0) {
            currentVelocity += 5.0 * .pi / 180.0
        } else if currentVelocity < Game.maxSpinVelocity {
            currentVelocity += 1.0 * .pi / 180.0
        }
    }

    func applyAngularDrag(to body: SKPhysicsBody, currentTime: TimeInterval) {
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        let deltaTime = CGFloat(dt)

        let sign: CGFloat = body.angularVelocity >= 0 ? 1 : -1
        let dragThisFrame = Game.linearAngularDrag * deltaTime
        let newAngularVelocity = abs(body.angularVelocity) - dragThisFrame
        body.angularVelocity = max(newAngularVelocity, 0) * sign
    }

    func countRotations(daveRotation: CGFloat) -> Double? {
        guard tuckCount >= 1 else { return nil }

        let normalized = (daveRotation.truncatingRemainder(dividingBy: 2 * .pi) + 2 * .pi)
            .truncatingRemainder(dividingBy: 2 * .pi)

        guard normalized != currentAngle else { return nil }

        var angleDiff = abs(previousAngle - currentAngle)

        if angleDiff > 5 {
            if normalized < 1 {
                previousAngle = 0
            } else if normalized > 5 {
                previousAngle = 2 * .pi
            }
            angleDiff = abs(previousAngle - currentAngle)
        }

        sumRotation += angleDiff
        totalRotations = Double(sumRotation) / (2 * .pi)

        previousAngle = currentAngle
        currentAngle = normalized

        if totalRotations > lastFlipNumber {
            let rotationDifference = totalRotations - lastFlipNumber
            if rotationDifference >= 1 {
                let roundedRotations = round(totalRotations)
                lastFlipNumber = roundedRotations
                return roundedRotations
            }
        }
        return nil
    }
}

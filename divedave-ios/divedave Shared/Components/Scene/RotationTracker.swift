//
//  RotationTracker.swift
//  divedave iOS
//
//  Owns the dive's rotation/tuck/spin state, the per-frame angular drag,
//  and the rotation-counting state machine driven by Dave's zRotation.
//

import SpriteKit

@MainActor
final class RotationTracker {
    // MARK: - State

    /// Current angular velocity Dave's body is being driven at while tucking.
    private(set) var currentVelocity: CGFloat = Game.minSpinVelocity
    /// True while a tuck is in progress.
    private(set) var tucked: Bool = false
    /// Number of times the player has engaged tuck this dive (resets on board).
    private(set) var tuckCount: Int = 0
    /// Number of full rotations completed since the last reset. Updated by `countRotations`.
    private(set) var totalRotations: Double = 0.0

    // Internal accumulators driven by countRotations.
    private var sumRotation: CGFloat = 0
    private var previousAngle: CGFloat = 0
    private var currentAngle: CGFloat = 0
    private var lastFlipNumber: Double = 0
    /// Last frame's currentTime, used to compute dt for angular drag.
    private var lastUpdateTime: TimeInterval

    init() {
        lastUpdateTime = CACurrentMediaTime()
    }

    // MARK: - Reset

    /// Zero rotation accumulators. Called whenever Dave returns to / is above the board.
    func reset() {
        sumRotation = 0
        totalRotations = 0
    }

    /// Drop out of tuck and reset spin velocity to idle. Called when no spin button is held.
    func resetTuck() {
        tucked = false
        currentVelocity = Game.minSpinVelocity
    }

    /// Engage tuck. Bumps tuckCount.
    func beginTuck() {
        tucked = true
        tuckCount += 1
    }

    /// Two-stage spin ramp: fast until near max, slow approach beyond.
    func incrementSpin() {
        if currentVelocity < Game.maxSpinVelocity - (200.0 * .pi / 180.0) {
            currentVelocity += 5.0 * .pi / 180.0
        } else if currentVelocity < Game.maxSpinVelocity {
            currentVelocity += 1.0 * .pi / 180.0
        }
    }

    // MARK: - Per-frame

    /// Linear angular drag: decay the body's angular velocity at a constant rate per second.
    func applyAngularDrag(to body: SKPhysicsBody, currentTime: TimeInterval) {
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        let deltaTime = CGFloat(dt)

        let sign: CGFloat = body.angularVelocity >= 0 ? 1 : -1
        let dragThisFrame = Game.linearAngularDrag * deltaTime
        let newAngularVelocity = abs(body.angularVelocity) - dragThisFrame
        body.angularVelocity = max(newAngularVelocity, 0) * sign
    }

    /// Update rotation accumulators from Dave's current `zRotation`. Only counts after
    /// the first tuck. Returns the rounded rotation count if a NEW full rotation just
    /// completed this frame (caller renders a flashing label etc.); nil otherwise.
    func countRotations(daveRotation: CGFloat) -> Double? {
        guard tuckCount >= 1 else { return nil }

        // Normalize Dave's rotation within [0, 2π]
        let normalized = (daveRotation.truncatingRemainder(dividingBy: 2 * .pi) + 2 * .pi)
            .truncatingRemainder(dividingBy: 2 * .pi)

        guard normalized != currentAngle else { return nil }

        // Calculate the angle difference
        var angleDiff = abs(previousAngle - currentAngle)

        // Handle large angle jumps due to wrapping from 0 to 2π or vice versa
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

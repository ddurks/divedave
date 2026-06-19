//
//  DavePlayer.swift
//  divedave iOS
//
//  Owns Dave's sprite, his physics body, the per-frame animation orchestration
//  for the player character, the jump → boost flow, and the horizontal velocity
//  damping. Climbdave / gettingoutdave / splash stay in DiveScene since they're
//  post-dive environmental presentation, not player physics.
//

import SpriteKit

/// How quickly the player released the jump button relative to landing.
/// Drives the post-jump feedback label (PERFECT / GOOD / OK).
enum BoostTiming {
    case perfect   // < 125 ms
    case good      // < 250 ms
    case ok        // < 350 ms
    case miss      // anything else
}

@MainActor
final class DavePlayer {
    let dave: AnimatedSprite

    var jumping: Bool = false
    var boost: CGFloat = 0
    /// Monotonic timestamp (CACurrentMediaTime) at which Dave most recently
    /// landed on the springboard. `0` = never. Compared against
    /// `GameState.shared.jumpReleasedAt` to score the jump's quickness.
    var landedAt: CFTimeInterval = 0

    init(scene: SKScene, springboard: AnimatedSprite) {
        let d = AnimatedSprite(spritesheetName: "divedave-spritesheet-extruded",
                               frameWidth: Game.defaultDaveHeight,
                               frameHeight: Game.defaultDaveHeight,
                               margin: 1,
                               spacing: 2,
                               scale: GameState.shared.metrics.scaleFactorHeight)
        d.position = CGPoint(x: GameState.shared.metrics.width / 4,
                             y: springboard.position.y + 100)
        d.zPosition = 5

        d.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: d.size.width / 4, height: d.size.height))
        d.physicsBody?.isDynamic = true
        d.physicsBody?.mass = Game.daveMass
        d.physicsBody?.affectedByGravity = true
        d.physicsBody?.restitution = 0.0
        d.physicsBody?.friction = 0.0

        d.physicsBody?.categoryBitMask = PhysicsCategory.dave.rawValue
        d.physicsBody?.contactTestBitMask = PhysicsCategory.springboard.rawValue
        d.physicsBody?.collisionBitMask = PhysicsCategory.springboard.rawValue

        scene.addChild(d)

        d.defineAnimation(name: "idle",      frameIndices: [18, 18, 18, 18, 18, 19, 20, 21], timePerFrame: 0.125)
        d.defineAnimation(name: "walkRight", frameIndices: [2, 3, 2, 4], timePerFrame: 0.166)
        d.defineAnimation(name: "walkLeft",  frameIndices: [11, 12, 11, 13], timePerFrame: 0.166)
        d.defineAnimation(name: "jump",      frameIndices: [5, 5, 6], timePerFrame: 0.1, repeatForever: false)

        self.dave = d
    }

    /// Begin a jump: flex the board, animate Dave's jump pose, then apply the
    /// jump impulse with boost factored in for quick release timing.
    /// `onJumpStarted` fires exactly when the jump animation actually begins
    /// (after the guard), so callers can react to a real jump without
    /// firing on rejected button-mashes. `onJumpCompleted` fires after the
    /// jump animation finishes and boost is applied, receiving the timing
    /// tier so the caller can surface a PERFECT/GOOD/OK feedback label.
    func jump(
        springboard: AnimatedSprite,
        onJumpStarted: (() -> Void)? = nil,
        onJumpCompleted: ((BoostTiming) -> Void)? = nil
    ) {
        guard !jumping, dave.currentAnimation != "jump" else { return }

        onJumpStarted?()

        springboard.playAnimation(name: "flex") {
            springboard.clearCurrentAnimation()
        }
        jumping = true
        dave.playAnimation(name: "jump") { [weak self] in
            guard let self = self else { return }
            self.jumping = false
            let timing = self.calculateBoost(springboard: springboard)
            self.landedAt = 0
            self.dave.physicsBody?.velocity.dy = Game.jumpVelocity + self.boost
            onJumpCompleted?(timing)
        }
    }

    @discardableResult
    private func calculateBoost(springboard: AnimatedSprite) -> BoostTiming {
        // Symmetric window: tapping slightly EARLY (release before landing)
        // counts the same as a tap of the same magnitude after landing.
        // msBetween returns .greatestFiniteMagnitude if either stamp is 0,
        // so abs() still falls through to .miss in that case.
        let quickness = abs(Self.msBetween(landedAt, GameState.shared.jumpReleasedAt))

        let timing: BoostTiming
        if quickness < 50 {
            timing = .perfect
            boost = Game.maxBoost
        } else if quickness < 100 {
            timing = .good
            boost = Game.maxBoost - 50
        } else if quickness < 175 {
            timing = .ok
            boost = Game.maxBoost - 100
        } else {
            timing = .miss
            boost = 0
        }

        // Boost decays the further Dave is from the board's pivot end.
        let daveBoardDist = dave.position.x - (springboard.position.x - springboard.size.width / 2)
        if daveBoardDist > 0 {
            var newRatio = daveBoardDist / springboard.size.width
            newRatio = min(newRatio, 1)
            boost *= newRatio
        }

        return timing
    }

    /// Milliseconds between two `CACurrentMediaTime` stamps, or `.greatestFiniteMagnitude`
    /// if either is `0` (never recorded).
    private static func msBetween(_ start: CFTimeInterval, _ end: CFTimeInterval) -> Double {
        guard start > 0, end > 0 else { return .greatestFiniteMagnitude }
        return (end - start) * 1000
    }

    /// Horizontal-only velocity damping applied each frame so Dave decelerates on the board.
    func applyDamping() {
        guard let body = dave.physicsBody else { return }
        let newVelocityX = body.velocity.dx * Game.drag
        body.velocity = CGVector(dx: newVelocityX, dy: body.velocity.dy)
    }

    /// True if Dave is in his tuck pose. Side effect: while `rotationTrackerTucked` is
    /// true, forces the tuck texture (so the visual matches the physics state).
    func daveIsTucked(rotationTrackerTucked: Bool) -> Bool {
        if rotationTrackerTucked {
            dave.texture = dave.frames[7]
        }
        return dave.texture == dave.frames[7] || rotationTrackerTucked
    }

    /// Per-frame animation orchestration. Picks the right walk/idle/airborne texture
    /// based on whether Dave is on the board, mid-jump, falling, or rising.
    func updateFrame(aboveBoard: Bool, isTouching: Bool, tucked: Bool) {
        guard !jumping else { return }

        if aboveBoard {
            if dave.zRotation != 0 {
                dave.zRotation = 0
            }
            if isTouching {
                if let velocity = dave.physicsBody?.velocity.dx, velocity > (Game.daveSpeed / 10) {
                    dave.playAnimation(name: "walkRight")
                } else if let velocity = dave.physicsBody?.velocity.dx, velocity < -(Game.daveSpeed / 10) {
                    dave.playAnimation(name: "walkLeft")
                } else {
                    dave.playAnimation(name: "idle")
                }
            } else {
                dave.stopAnimation()
                if (dave.physicsBody?.velocity.dy ?? 0) > 0 {
                    if (dave.physicsBody?.velocity.dx ?? 0) < 0 {
                        dave.texture = dave.frames[15]
                    } else {
                        dave.texture = dave.frames[6]
                    }
                } else {
                    if (dave.physicsBody?.velocity.dx ?? 0) < 0 {
                        dave.texture = dave.frames[11]
                    } else {
                        dave.texture = dave.frames[2]
                    }
                }
            }
        } else if !tucked {
            dave.texture = dave.zRotation >= -CGFloat.pi / 2 && dave.zRotation <= CGFloat.pi / 2 ? dave.frames[6] : dave.frames[8]
            dave.clearCurrentAnimation()
        }
    }
}

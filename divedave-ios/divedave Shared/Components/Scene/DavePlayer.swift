import SpriteKit
import os

private let logger = Logger(subsystem: "com.drawvid.divedave", category: "dave-state")

enum DaveState {
    case grounded
    case launching
    case airborne
    case diving
    case splashed
}

enum BoostTiming {
    case perfect
    case good
    case ok
    case miss
}

@MainActor
final class DavePlayer {
    let dave: AnimatedSprite

    private(set) var state: DaveState = .airborne

    var boost: CGFloat = 0
    var landedAt: CFTimeInterval = 0

    private static let allowedTransitions: [DaveState: Set<DaveState>] = [
        .grounded:  [.launching, .airborne],
        .launching: [.airborne],
        .airborne:  [.diving, .grounded, .splashed],
        .diving:    [.splashed],
        .splashed:  []
    ]

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

    @discardableResult
    func transition(to next: DaveState) -> Bool {
        if next == state { return true }
        guard Self.allowedTransitions[state]?.contains(next) == true else {
            logger.debug("rejected dave transition: \(String(describing: self.state)) -> \(String(describing: next))")
            return false
        }
        logger.debug("dave transition: \(String(describing: self.state)) -> \(String(describing: next))")
        state = next
        didEnter(next)
        return true
    }

    private func didEnter(_ state: DaveState) {
        switch state {
        case .diving:
            // Drop board collision once committed to a dive — Dave passes through.
            dave.physicsBody?.collisionBitMask = 0
            dave.physicsBody?.contactTestBitMask = 0
        case .grounded, .launching, .airborne, .splashed:
            break
        }
    }

    func isCleanLanding() -> Bool {
        guard let body = dave.physicsBody else { return false }
        // dy tolerance instead of <= 0: SpriteKit's collision resolution leaves
        // tiny floating-point noise (~4e-12) at the instant didBegin fires.
        // A strict check would reject real landings as "ascending".
        let notLaunching = body.velocity.dy < 50
        let lowSpin = abs(body.angularVelocity) < 0.5
        return notLaunching && lowSpin
    }

    func jump(
        springboard: AnimatedSprite,
        onJumpStarted: (() -> Void)? = nil,
        onJumpCompleted: ((BoostTiming) -> Void)? = nil
    ) {
        guard state == .grounded else { return }
        guard transition(to: .launching) else { return }

        onJumpStarted?()

        springboard.playAnimation(name: "flex") {
            springboard.clearCurrentAnimation()
        }
        dave.playAnimation(name: "jump") { [weak self] in
            guard let self = self else { return }
            let timing = self.calculateBoost(springboard: springboard)
            self.landedAt = 0
            self.dave.physicsBody?.velocity.dy = Game.jumpVelocity + self.boost
            self.transition(to: .airborne)
            onJumpCompleted?(timing)
        }
    }

    @discardableResult
    private func calculateBoost(springboard: AnimatedSprite) -> BoostTiming {
        let quickness = abs(Self.msBetween(landedAt, GameState.shared.jumpReleasedAt))

        let timing: BoostTiming
        if quickness < 90 {
            timing = .perfect
            boost = Game.maxBoost
        } else if quickness < 175 {
            timing = .good
            boost = Game.maxBoost - 50
        } else if quickness < 265 {
            timing = .ok
            boost = Game.maxBoost - 100
        } else {
            timing = .miss
            boost = 0
        }

        let daveBoardDist = dave.position.x - (springboard.position.x - springboard.size.width / 2)
        if daveBoardDist > 0 {
            var newRatio = daveBoardDist / springboard.size.width
            newRatio = min(newRatio, 1)
            boost *= newRatio
        }

        return timing
    }

    private static func msBetween(_ start: CFTimeInterval, _ end: CFTimeInterval) -> Double {
        guard start > 0, end > 0 else { return .greatestFiniteMagnitude }
        return (end - start) * 1000
    }

    func applyDamping() {
        guard let body = dave.physicsBody else { return }
        let newVelocityX = body.velocity.dx * Game.drag
        body.velocity = CGVector(dx: newVelocityX, dy: body.velocity.dy)
    }

    func updateFrame(tucked: Bool) {
        switch state {
        case .launching, .splashed:
            return

        case .grounded:
            if dave.zRotation != 0 { dave.zRotation = 0 }
            let dx = dave.physicsBody?.velocity.dx ?? 0
            if dx > Game.daveSpeed / 10 {
                dave.playAnimation(name: "walkRight")
            } else if dx < -Game.daveSpeed / 10 {
                dave.playAnimation(name: "walkLeft")
            } else {
                dave.playAnimation(name: "idle")
            }

        case .airborne:
            dave.stopAnimation()
            let dx = dave.physicsBody?.velocity.dx ?? 0
            let dy = dave.physicsBody?.velocity.dy ?? 0
            if dy > 0 {
                dave.texture = dx < 0 ? dave.frames[15] : dave.frames[6]
            } else {
                dave.texture = dx < 0 ? dave.frames[11] : dave.frames[2]
            }

        case .diving:
            dave.stopAnimation()
            if tucked {
                dave.texture = dave.frames[7]
            } else {
                let r = dave.zRotation
                dave.texture = (r >= -CGFloat.pi / 2 && r <= CGFloat.pi / 2)
                    ? dave.frames[6]
                    : dave.frames[8]
            }
        }
    }
}

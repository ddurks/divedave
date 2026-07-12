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

@MainActor
final class DavePlayer {
    let dave: AnimatedSprite

    private(set) var state: DaveState = .airborne

    var boost: CGFloat = 0
    var landedAt: CFTimeInterval = 0

    // Facing + turn-on-reversal (grounded only). facing: 1 = right, -1 = left.
    private var facing: CGFloat = 1
    private var prevDesired: CGFloat = 0
    private var turning = false
    private var turnFrom: CGFloat = 1
    private var turnTo: CGFloat = 1
    private var turnViaBack = false
    private var turnStart: TimeInterval = 0
    private let turnFrameDuration: TimeInterval = 0.05

    // Tuck transition: slip the falling frame in when tucking from the dive pose.
    private var wasTucked = false
    private var tuckTransitioning = false
    private var tuckTransitionStart: TimeInterval = 0
    private var lastFrame = 11
    private let tuckFallDuration: TimeInterval = 0.08

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
                               spacing: 2)
        d.position = CGPoint(x: springboard.frame.minX + springboard.frame.width / 4,
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

        d.defineAnimation(name: "idle", frameIndices: [15, 15, 15, 15, 15, 16, 17, 18], timePerFrame: 0.125)
        d.defineAnimation(name: "walk", frameIndices: [5, 6, 7, 8], timePerFrame: 0.125)
        d.defineAnimation(name: "jump", frameIndices: [10, 10, 11], timePerFrame: 0.1, repeatForever: false)

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
        case .grounded:
            turning = false
            prevDesired = 0
        case .launching, .airborne, .splashed:
            break
        }
    }

    func isCleanLanding() -> Bool {
        guard let body = dave.physicsBody else { return false }
        // dy tolerance instead of <= 0: SpriteKit's collision resolution leaves
        // tiny floating-point noise (~4e-12) at the instant didBegin fires.
        // A strict check would reject real landings as "ascending".
        let notLaunching = body.velocity.dy < 50
        // 30°/s in radians — matches web's Phaser angularVelocity gate (deg/s).
        let lowSpin = abs(body.angularVelocity) < 30.0 * .pi / 180.0
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

        setFacing(left: false)
        dave.playAnimation(name: "jump") { [weak self] in
            guard let self = self else { return }
            let timing = self.calculateBoost(springboard: springboard)
            self.playBoardBounce(springboard: springboard, timing: timing)
            self.landedAt = 0
            self.dave.physicsBody?.velocity.dy = Game.jumpVelocity + self.boost
            self.transition(to: .airborne)
            onJumpCompleted?(timing)
        }
    }

    // Flex the board to this jump's timing frame (1 = OK, 2 = GOOD, 3 = PERFECT);
    // a non-notable (miss) bounce leaves it at rest. Mirrors divedave-web.
    private func playBoardBounce(springboard: AnimatedSprite, timing: BoostTiming) {
        let bounce: String
        switch timing {
        case .perfect: bounce = "bouncePerfect"
        case .good:    bounce = "bounceGood"
        case .ok:      bounce = "bounceOk"
        case .miss:    return
        }
        springboard.playAnimation(name: bounce) {
            springboard.clearCurrentAnimation()
        }
    }

    @discardableResult
    private func calculateBoost(springboard: AnimatedSprite) -> BoostTiming {
        let quickness = abs(Self.msBetween(landedAt, GameState.shared.jumpReleasedAt))
        let timing = DiveScorer.classifyBoostTiming(quicknessMs: quickness)
        switch timing {
        case .perfect:   boost = Game.maxBoost
        case .good:      boost = Game.maxBoost / 2
        case .ok, .miss: boost = 0
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

    // Frames face right; a negative xScale mirrors Dave for leftward motion.
    // The physics body is a centered rectangle, so mirroring leaves it unchanged.
    private func setFacing(left: Bool) {
        dave.xScale = left ? -abs(dave.xScale) : abs(dave.xScale)
    }

    func updateFrame(tucked: Bool, currentTime: TimeInterval) {
        switch state {
        case .launching, .splashed:
            return

        case .grounded:
            if dave.zRotation != 0 { dave.zRotation = 0 }
            if turning {
                advanceTurn(currentTime: currentTime)
                return
            }
            let thr = Game.daveSpeed / 10
            let dx = dave.physicsBody?.velocity.dx ?? 0
            let desired: CGFloat = dx > thr ? 1 : (dx < -thr ? -1 : 0)
            if desired == 0 {
                setFacing(left: facing < 0)
                dave.playAnimation(name: "idle")
                prevDesired = 0
            } else if desired == facing {
                setFacing(left: facing < 0)
                dave.playAnimation(name: "walk")
                prevDesired = desired
            } else if prevDesired == 0 {
                // From idle/landing: snap to the new direction, no turn.
                facing = desired
                setFacing(left: facing < 0)
                dave.playAnimation(name: "walk")
                prevDesired = desired
            } else {
                // Reversed mid-walk: pivot through the turn frames, then walk.
                startTurn(from: facing, to: desired, currentTime: currentTime)
                prevDesired = desired
            }

        case .airborne:
            dave.stopAnimation()
            let dx = dave.physicsBody?.velocity.dx ?? 0
            let dy = dave.physicsBody?.velocity.dy ?? 0
            setFacing(left: dx < 0)
            // dy > 0 ascending = jump-up (11), else falling-down (12)
            lastFrame = dy > 0 ? 11 : 12
            dave.texture = dave.frames[lastFrame]

        case .diving:
            dave.stopAnimation()
            // Dive pose never mirrors — always the original (right-facing) frame.
            setFacing(left: false)
            if tucked {
                // Tucking straight from the dive (inverted) frame slips the
                // falling frame in first; from the falling/upright frame it's skipped.
                if !wasTucked && lastFrame == 14 {
                    tuckTransitioning = true
                    tuckTransitionStart = currentTime
                }
                if tuckTransitioning && currentTime - tuckTransitionStart < tuckFallDuration {
                    lastFrame = 12
                } else {
                    tuckTransitioning = false
                    lastFrame = 13
                }
            } else {
                tuckTransitioning = false
                // Falling pose while upright; dive pose once rotated upside down.
                // Normalize accumulated spin to [-pi, pi] before the test.
                let twoPi = 2 * CGFloat.pi
                var r = dave.zRotation.truncatingRemainder(dividingBy: twoPi)
                if r > .pi { r -= twoPi } else if r < -.pi { r += twoPi }
                let upright = r >= -CGFloat.pi / 2 && r <= CGFloat.pi / 2
                lastFrame = upright ? 12 : 14
            }
            dave.texture = dave.frames[lastFrame]
            wasTucked = tucked
        }
    }

    private func startTurn(from: CGFloat, to: CGFloat, currentTime: TimeInterval) {
        turning = true
        turnFrom = from
        turnTo = to
        turnViaBack = Bool.random()
        turnStart = currentTime
        dave.stopAnimation()
        advanceTurn(currentTime: currentTime)
    }

    private func advanceTurn(currentTime: TimeInterval) {
        let mid = turnViaBack ? 3 : 1
        let pivot = turnViaBack ? 4 : 0
        let frames = [2, mid, pivot, mid, 2]
        let dirs = [turnFrom, turnFrom, turnFrom, turnTo, turnTo]
        let step = Int((currentTime - turnStart) / turnFrameDuration)
        if step >= frames.count {
            turning = false
            facing = turnTo
            setFacing(left: facing < 0)
            dave.texture = dave.frames[2]
            return
        }
        setFacing(left: dirs[step] < 0)
        dave.texture = dave.frames[frames[step]]
    }
}

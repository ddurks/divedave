import CoreGraphics
import SpriteKit

struct PhysicsCategory: OptionSet {
    let rawValue: UInt32

    static let dave        = PhysicsCategory(rawValue: 1 << 0)
    static let springboard = PhysicsCategory(rawValue: 1 << 1)
}

enum Game {
    // === Shared with divedave-web Constants.js — keep in sync. ===
    // `tools/run-parity.sh` catches drift in DiveScorer + boost-window
    // classification. The remaining values are stable; check the matching
    // JS declaration when changing any of them.
    static let defaultWidth: CGFloat = 1250
    // Reference world height; the device-aspect FOV is clamped to at least this
    // (mirrors divedave-web REF_HEIGHT). 1 m = 200 units throughout.
    static let refHeight: CGFloat = 1500

    // Kinematics in the fixed 1250-wide world. Both engines set these as
    // velocities directly, so they are byte-identical to web. Gravity is the lone
    // exception (SpriteKit integrator ≠ Phaser) and stays platform-specific below.
    static let daveSpeed: CGFloat = 352
    static let jumpVelocity: CGFloat = 704
    static let maxBoost: CGFloat = 352
    static let drag: CGFloat = 0.94

    static let minSpinVelocity: CGFloat = 100.0 * .pi / 180.0
    static let maxSpinVelocity: CGFloat = 550.0 * .pi / 180.0

    static let boostPerfectMs: Double = 90
    static let boostGoodMs: Double = 175
    static let boostOkMs: Double = 265

    static let minClouds = 5
    static let maxClouds = 12
    static let minBirds = 0
    static let maxBirds = 3

    // Atmosphere parallax depth: 0 = pinned to camera (deepest), 1 = full world-space.
    static let starParallax: CGFloat = 0.3
    static let cloudParallax: CGFloat = 0.6
    static let birdParallax: CGFloat = 0.8
    static let planeParallax: CGFloat = 0.8
    static let ufoParallax: CGFloat = 1.0

    static let highScoreKey = "highScore"
    // === End shared block. ===

    // SpriteKit-specific: applied by SKPhysicsWorld (≈150 pt/m, variable-substep
    // integrator), so NOT web's Phaser value (1083 px/s² at a fixed 60 Hz step).
    // 7.04 = the old 2 × 3.52 (3000/852): the world is now the fixed 1250-wide
    // space instead of per-device points, so velocities and gravity both scaled
    // by 3.52, preserving the prior trajectory feel.
    static let gravity: CGFloat = 7.04
    static let daveMass: CGFloat = 1.0

    static let defaultDaveHeight: CGFloat = 256
    static let defaultButtonHeight: CGFloat = 256

    // Reference ratio for the goal half-flip heuristic only (DiveScorer.goalHalfFlips,
    // parity-tested). No longer scales physics or layout.
    static let defaultHeight: CGFloat = 3000
    static let referenceScreenHeight: CGFloat = 852

    static let angularDrag: CGFloat = 0.9
    static let linearAngularDrag: CGFloat = 2.618

    static let cloudMinSpeed: CGFloat = 8
    static let cloudMaxSpeed: CGFloat = 20
    static let birdMinSpeed: CGFloat = 25
    static let birdMaxSpeed: CGFloat = 100

    static let customGreen = SKColor(red: 0/255, green: 128/255, blue: 0/255, alpha: 1.0)
    static let customRed = SKColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 1.0)
    static let customYellow = SKColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 1.0)
}

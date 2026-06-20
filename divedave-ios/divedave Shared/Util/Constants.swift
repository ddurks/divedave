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

    static let minSpinVelocity: CGFloat = 100.0 * .pi / 180.0
    static let maxSpinVelocity: CGFloat = 550.0 * .pi / 180.0

    static let boostPerfectMs: Double = 90
    static let boostGoodMs: Double = 175
    static let boostOkMs: Double = 265

    static let minClouds = 5
    static let maxClouds = 12
    static let minBirds = 0
    static let maxBirds = 3

    static let highScoreKey = "highScore"
    // === End shared block. ===

    static let gravity: CGFloat = 2
    static let daveMass: CGFloat = 1.0

    static let defaultHeight: CGFloat = 3000
    static let defaultDaveHeight: CGFloat = 256
    static let defaultButtonHeight: CGFloat = 256

    static let daveSpeed: CGFloat = 100
    static let jumpVelocity: CGFloat = 200
    static let drag: CGFloat = 0.94
    static let angularDrag: CGFloat = 0.9
    static let linearAngularDrag: CGFloat = 2.618
    static let maxBoost: CGFloat = 100

    static let cloudMinSpeed: CGFloat = 8
    static let cloudMaxSpeed: CGFloat = 20
    static let birdMinSpeed: CGFloat = 25
    static let birdMaxSpeed: CGFloat = 100

    static let customGreen = SKColor(red: 0/255, green: 128/255, blue: 0/255, alpha: 1.0)
    static let customRed = SKColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 1.0)
    static let customYellow = SKColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 1.0)
}

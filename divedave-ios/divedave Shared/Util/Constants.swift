import CoreGraphics
import SpriteKit

struct PhysicsCategory: OptionSet {
    let rawValue: UInt32

    static let dave        = PhysicsCategory(rawValue: 1 << 0)
    static let springboard = PhysicsCategory(rawValue: 1 << 1)
}

enum Game {
    static let gravity: CGFloat = 2
    static let daveMass: CGFloat = 1.0

    static let defaultWidth: CGFloat = 1250
    static let defaultHeight: CGFloat = 3000
    static let defaultDaveHeight: CGFloat = 256
    static let defaultButtonHeight: CGFloat = 256

    static let daveSpeed: CGFloat = 100
    static let jumpVelocity: CGFloat = 200
    static let minSpinVelocity: CGFloat = 100.0 * .pi / 180.0
    static let maxSpinVelocity: CGFloat = 550.0 * .pi / 180.0
    static let drag: CGFloat = 0.94
    static let angularDrag: CGFloat = 0.9
    static let linearAngularDrag: CGFloat = 2.618
    static let maxBoost: CGFloat = 100

    static let minClouds = 5
    static let maxClouds = 12
    static let cloudMinSpeed: CGFloat = 8
    static let cloudMaxSpeed: CGFloat = 20
    static let minBirds = 0
    static let maxBirds = 3
    static let birdMinSpeed: CGFloat = 25
    static let birdMaxSpeed: CGFloat = 100

    static let highScoreKey = "highScore"

    static let customGreen = SKColor(red: 0/255, green: 128/255, blue: 0/255, alpha: 1.0)
    static let customRed = SKColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 1.0)
    static let customYellow = SKColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 1.0)
}


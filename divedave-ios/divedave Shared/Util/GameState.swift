import Foundation
import CoreGraphics

@MainActor
final class GameState {
    static let shared = GameState()
    private init() {}

    var metrics: SceneMetrics = .default

    var challengeMode: Bool = true

    var streak: Int = 0
    var totalScore: Int = 0
    var platformHeight: CGFloat = 703

    var sceneHeight: CGFloat = 0
    var jumpReleasedAt: CFTimeInterval = 0

    var stats: DiveStats = DiveStats()

    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: Game.highScoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: Game.highScoreKey) }
    }
}

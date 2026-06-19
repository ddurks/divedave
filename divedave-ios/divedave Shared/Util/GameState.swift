//
//  GameState.swift
//  divedave iOS
//
//  Created by Lane E (Globals refactor) on 6/18/26.
//

import Foundation
import CoreGraphics

/// Main-actor-isolated session state, replacing the file-scope `var`s that
/// used to live in `Globals.swift`. All scene/UI code runs on the main thread
/// already, so `@MainActor` is essentially free here while giving us a single
/// audited owner for mutable global state.
@MainActor
final class GameState {
    static let shared = GameState()
    private init() {}

    // MARK: - Screen / scaling

    /// On-screen drawing size + per-axis scale factors. Set once by
    /// `GameViewController.viewDidLoad` before any scene runs.
    var metrics: SceneMetrics = .default

    // MARK: - Mode

    /// Game mode selected on the main menu. `true` = challenge (escalating
    /// platform heights, high-score tracking); `false` = arcade.
    var challengeMode: Bool = true

    // MARK: - Session (current run)

    /// Consecutive successful dives in the current run.
    var streak: Int = 0
    /// Cumulative score in the current run.
    var totalScore: Int = 0
    /// Current dive's platform height in design-space units. Defaults to the
    /// challenge-mode starting height (703).
    var platformHeight: CGFloat = 703

    // MARK: - Per-dive state (populated by the active DiveScene)

    /// Height of the active scene's world (`HEIGHT` or `platformHeight + buffer`,
    /// whichever is larger).
    var sceneHeight: CGFloat = 0
    /// Monotonic timestamp (CACurrentMediaTime) at which the jump button was
    /// released. `0` = never (initial state). Compared against the landing
    /// time inside DiveScene to decide the boost magnitude.
    var jumpReleasedAt: CFTimeInterval = 0

    /// Stats for the most recently scored dive (height, angle, rotations, etc).
    var stats: DiveStats = DiveStats()

    // MARK: - Persistence

    /// Legacy single high score, persisted in UserDefaults under
    /// `Game.highScoreKey`. Reads and writes are synchronous.
    var highScore: Int {
        get { UserDefaults.standard.integer(forKey: Game.highScoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: Game.highScoreKey) }
    }
}

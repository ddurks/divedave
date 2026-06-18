//
//  StatsStore.swift
//  divedave iOS
//
//  Persistent meta-progression store backed by UserDefaults.
//

import Foundation

enum StatsStore {
    // MARK: - Keys
    private enum Key {
        static let arcadeHigh      = "stats.arcadeHigh"
        static let challengeHigh   = "stats.challengeHigh"
        static let longestStreak   = "stats.longestStreak"
        static let maxHeight       = "stats.maxHeight"
        static let totalDives      = "stats.totalDives"
        static let totalFlips      = "stats.totalFlips"
        static let hasSeenTutorial = "stats.hasSeenTutorial"
        static let audioEnabled    = "settings.audio"
        static let hapticsEnabled  = "settings.haptics"

        // Legacy
        static let legacyHighScore = "highScore"
    }

    // MARK: - Migration
    private static var migrated = false

    /// Seed `stats.arcadeHigh` from the legacy `highScore` key once, the first
    /// time any caller touches the store. The legacy key is intentionally
    /// preserved (Lane E owns its removal).
    private static func migrateLegacyIfNeeded() {
        guard !migrated else { return }
        migrated = true

        let defaults = UserDefaults.standard
        let arcadeHasValue = defaults.object(forKey: Key.arcadeHigh) != nil
        let legacy = defaults.object(forKey: Key.legacyHighScore) as? Int ?? 0

        if !arcadeHasValue && legacy > 0 {
            defaults.set(legacy, forKey: Key.arcadeHigh)
        }
    }

    // MARK: - Helpers
    private static func int(forKey key: String, default defaultValue: Int = 0) -> Int {
        migrateLegacyIfNeeded()
        return UserDefaults.standard.object(forKey: key) as? Int ?? defaultValue
    }

    private static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        migrateLegacyIfNeeded()
        return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    private static func set(_ value: Int, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private static func set(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - Stats
    static var arcadeHigh: Int {
        get { int(forKey: Key.arcadeHigh) }
        set { set(newValue, forKey: Key.arcadeHigh) }
    }

    static var challengeHigh: Int {
        get { int(forKey: Key.challengeHigh) }
        set { set(newValue, forKey: Key.challengeHigh) }
    }

    static var longestStreak: Int {
        get { int(forKey: Key.longestStreak) }
        set { set(newValue, forKey: Key.longestStreak) }
    }

    static var maxHeightReached: Int {
        get { int(forKey: Key.maxHeight) }
        set { set(newValue, forKey: Key.maxHeight) }
    }

    static var totalDives: Int {
        get { int(forKey: Key.totalDives) }
        set { set(newValue, forKey: Key.totalDives) }
    }

    static var totalFlips: Int {
        get { int(forKey: Key.totalFlips) }
        set { set(newValue, forKey: Key.totalFlips) }
    }

    // MARK: - Flags / Settings
    static var hasSeenTutorial: Bool {
        get { bool(forKey: Key.hasSeenTutorial, default: false) }
        set { set(newValue, forKey: Key.hasSeenTutorial) }
    }

    static var audioEnabled: Bool {
        get { bool(forKey: Key.audioEnabled, default: true) }
        set { set(newValue, forKey: Key.audioEnabled) }
    }

    static var hapticsEnabled: Bool {
        get { bool(forKey: Key.hapticsEnabled, default: true) }
        set { set(newValue, forKey: Key.hapticsEnabled) }
    }
}

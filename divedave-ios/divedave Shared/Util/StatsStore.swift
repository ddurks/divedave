import Foundation

@MainActor
enum StatsStore {
    private enum Key {
        static let arcadeHigh      = "stats.arcadeHigh"
        static let challengeHigh   = "stats.challengeHigh"
        static let longestStreak   = "stats.longestStreak"
        static let maxHeight       = "stats.maxHeight"
        static let totalDives      = "stats.totalDives"
        static let totalFlips      = "stats.totalFlips"
        static let hasSeenTutorial = "stats.hasSeenTutorial"

        static let legacyHighScore = "highScore"
    }

    private static var migrated = false

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

    static var hasSeenTutorial: Bool {
        get { bool(forKey: Key.hasSeenTutorial, default: false) }
        set { set(newValue, forKey: Key.hasSeenTutorial) }
    }
}

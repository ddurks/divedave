import UIKit

@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    static var isEnabled = true

    static func prepare() {
        light.prepare(); medium.prepare(); heavy.prepare(); notification.prepare()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        switch style {
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .heavy: heavy.impactOccurred()
        default: break
        }
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notification.notificationOccurred(type)
    }
}

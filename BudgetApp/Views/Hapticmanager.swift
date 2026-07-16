import UIKit

struct HapticManager {

    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsOn") as? Bool ?? true
    }

    // Light tap — for minor UI interactions
    static func light() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // Medium tap — for saves, confirmations
    static func medium() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // Heavy tap — for destructive actions like delete
    static func heavy() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // Success — double tap, for distribute income, mark as paid
    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // Error — for validation failures
    static func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // Warning — for over budget, low balance alerts
    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

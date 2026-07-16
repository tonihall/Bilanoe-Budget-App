import UserNotifications
import Foundation

class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    // MARK: - Request Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func checkPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - Schedule Reminder for One Subscription

    func scheduleReminder(for subscription: Subscription) {
        let center = UNUserNotificationCenter.current()

        // Cancel existing notification for this subscription first
        center.removePendingNotificationRequests(withIdentifiers: [subscription.uuid])

        // Calculate the day before due date at 9:00 AM
        guard let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: subscription.dueDate) else { return }

        // Don't schedule if the reminder date is in the past
        guard dayBefore > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Bill Due Tomorrow 💸"
        content.body = "\(subscription.name) — \(formatCurrency(subscription.amount)) is due tomorrow."
        content.sound = .default
        content.badge = 1

        var components = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: subscription.uuid, content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Schedule All Subscriptions

    func scheduleAll(subscriptions: [Subscription]) {
        for sub in subscriptions {
            scheduleReminder(for: sub)
        }
    }

    // MARK: - Cancel Reminder

    func cancelReminder(for subscription: Subscription) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [subscription.uuid]
        )
    }

    // MARK: - Cancel All

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Format Currency

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

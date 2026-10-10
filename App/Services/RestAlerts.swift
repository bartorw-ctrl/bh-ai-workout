import Foundation
import UserNotifications
import AudioToolbox
import UIKit

/// Rest-over alerts (SPEC 5.9).
/// A local notification covers the locked/background case; in the foreground the app plays the sound itself.
enum RestAlerts {
    static let notificationID = "rest-timer"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Replaces any pending rest notification with one at `date` (or none).
    static func schedule(at date: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        guard let date else { return }
        let interval = date.timeIntervalSinceNow
        guard interval > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
    }

    /// Sound + vibration while the app is open.
    static func playInApp() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Suppresses the rest banner while the app is open, because the app already plays its own alert.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.identifier == RestAlerts.notificationID {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound])
        }
    }
}

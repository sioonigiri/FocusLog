import UserNotifications

enum NotificationManager {
    private static let timerID = "focuslog.timer"
    private static var center: UNUserNotificationCenter { .current() }

    static func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func scheduleTimerEnd(at date: Date, taskName: String, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "お疲れさまでした！"
        content.body = "\(taskName)（\(minutes)分）が完了しました"
        if AppSettings.soundEnabled {
            content.sound = AppSettings.alarmSound.notificationSound
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: timerID, content: content, trigger: trigger))
    }

    /// 通知が許可されているか。設定でオフにされている（拒否）ときだけfalse。
    static func isAllowed() async -> Bool {
        await center.notificationSettings().authorizationStatus != .denied
    }

    static func cancelTimer() {
        center.removePendingNotificationRequests(withIdentifiers: [timerID])
    }
}

/// アプリを開いているときは通知バナーを出さず、アプリ内のサウンドとバイブで知らせる。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}

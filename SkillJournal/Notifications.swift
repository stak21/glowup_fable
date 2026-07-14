//  Notifications.swift
//  Skill Journal

import Foundation
import UserNotifications

extension Notification.Name {
    static let openTodayTab = Notification.Name("openTodayTab")
    static let openExploreTab = Notification.Name("openExploreTab")
    /// Posted after "Build my routine" creates routines from a template —
    /// sheets listening for it dismiss themselves and RootView switches to Today.
    static let templateRoutinesBuilt = Notification.Name("templateRoutinesBuilt")
}

final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotifDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.identifier.hasPrefix("timer-") {
            completionHandler([]) // in-app: the heartbeat plays its own completion chime
        } else {
            completionHandler([.banner, .sound]) // show banners even while app is open
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationCenter.default.post(name: .openTodayTab, object: nil)
        completionHandler()
    }
}

// MARK: - Notifications

enum NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func sync(_ reminders: [Reminder]) {
        if !reminders.isEmpty { requestPermission() }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { existing in
            // Replace only reminder schedules — leave running step-timer notifications alone.
            let stale = existing.map(\.identifier).filter { !$0.hasPrefix("timer-") }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for r in reminders {
                let content = UNMutableNotificationContent()
                content.title = "Skill Journal"
                content.body = r.label
                content.sound = .default
                if r.days.count == 7 {
                    var dc = DateComponents()
                    dc.hour = r.hour; dc.minute = r.minute
                    let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                    center.add(UNNotificationRequest(identifier: r.id.uuidString, content: content, trigger: trigger))
                } else {
                    for d in r.days {
                        var dc = DateComponents()
                        dc.hour = r.hour; dc.minute = r.minute; dc.weekday = d
                        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                        center.add(UNNotificationRequest(identifier: "\(r.id.uuidString)-\(d)", content: content, trigger: trigger))
                    }
                }
            }
        }
    }

    // MARK: Step timers

    static func scheduleTimerDone(key: String, label: String, end: Date) {
        requestPermission()
        let content = UNMutableNotificationContent()
        content.title = "⏳ \(label) — time's up!"
        content.body = "Ready for your next step"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "timer-\(key)", content: content, trigger: trigger))
    }

    static func cancelTimerDone(key: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer-\(key)"])
    }

    static func cancelAllTimerDone() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { existing in
            let ids = existing.map(\.identifier).filter { $0.hasPrefix("timer-") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}

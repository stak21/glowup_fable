//  ClearingApp.swift
//  Skincare Ritual — native   port of the web tracker
//
//  iOS 16+. Local notifications work with a FREE Apple ID (no paid account).
//

import SwiftUI
import UserNotifications

// MARK: - App entry

@main
struct ClearingApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light) // palette is hard-coded light; keeps system controls (drag handles etc.) visible
                .onAppear {
                    UNUserNotificationCenter.current().delegate = NotifDelegate.shared
                    NotificationManager.requestPermission()
                }
        }
    }
}

//  SkillJournalApp.swift
//  Skill Journal — modular routine builder.
//
//  iOS 17+. Local notifications work with a FREE Apple ID (no paid account).

import SwiftUI
import UserNotifications

// MARK: - App entry

@main
struct SkillJournalApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            // Placeholder root — replaced by RootView in the views transplant.
            TabView {
                PhotosView()
                    .tabItem { Label("Photos", systemImage: "camera.fill") }
                RemindersView()
                    .tabItem { Label("Reminders", systemImage: "bell.fill") }
            }
            .tint(.roseDeep)
            .environmentObject(store)
            .environmentObject(store.packs)
            .preferredColorScheme(.light) // palette is hard-coded light; keeps system controls visible
            .onAppear {
                UNUserNotificationCenter.current().delegate = NotifDelegate.shared
                // Permission is requested contextually — first timer or
                // first reminder — not at launch.
            }
        }
    }
}

//  SkillJournalApp.swift
//  Skill Journal — modular routine builder.
//
//  Step-1 scaffold: placeholder root view. The engine (AppStore, PackStore,
//  RootView) arrives in the next steps; this file then mirrors ClearingApp's
//  store injection + notification-delegate wiring.

import SwiftUI

@main
struct SkillJournalApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("📓")
                    .font(.system(size: 56))
                Text("Skill Journal")
                    .font(.system(.title, design: .serif).weight(.semibold))
                Text("Scaffold build — engine transplant in progress.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .preferredColorScheme(.light)
        }
    }
}

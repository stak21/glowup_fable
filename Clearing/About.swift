//  About.swift
//  Clearing (GlowUp)

import SwiftUI

// MARK: - About / legal

enum AppLinks {
    /// Set once the site/ pages are hosted (separate public repo + GitHub Pages).
    static let privacyURL: URL? = nil
    static let supportEmail = "angiedelgadoux@gmail.com"

    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(v)"
    }
}

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🌸 GlowUp")
                                .font(.system(.title2, design: .serif).weight(.semibold))
                                .foregroundColor(.ink)
                            Text(AppLinks.version)
                                .font(.caption)
                                .foregroundColor(.faint)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.roseDeep)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.roseTint))
                        }
                    }
                    .padding(.top, 20)

                    card("Your privacy",
                         "GlowUp has no accounts, no analytics, and no tracking. Your routines, check-offs, quiz answers, shopping list and progress photos stay on your phone — nothing is uploaded, ever.")

                    if let url = AppLinks.privacyURL {
                        Link(destination: url) {
                            Text("Read the full privacy policy ↗")
                                .font(.footnote.weight(.heavy))
                                .foregroundColor(.roseDeep)
                        }
                        .padding(.leading, 4)
                    }

                    card("Not medical advice",
                         "GlowUp offers cosmetic guidance and habit tracking only — it isn't medical advice, diagnosis or treatment. For skin concerns, please see a dermatologist.")

                    card("Affiliate disclosure",
                         "As an Amazon Associate, GlowUp earns from qualifying purchases made through store links in the app. Prices shown are indicative and may differ at the store.")

                    card("Support",
                         "Questions or ideas? We'd love to hear from you.")

                    Link(destination: URL(string: "mailto:\(AppLinks.supportEmail)")!) {
                        Text("✉️ \(AppLinks.supportEmail)")
                            .font(.footnote.weight(.heavy))
                            .foregroundColor(.roseDeep)
                    }
                    .padding(.leading, 4)

                    Text("Made with ♡")
                        .font(.caption2)
                        .foregroundColor(.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func card(_ heading: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundColor(.rose)
            Text(text)
                .font(.footnote)
                .foregroundColor(.ink)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.85)))
    }
}

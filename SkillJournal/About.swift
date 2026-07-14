//  About.swift
//  Skill Journal

import SwiftUI

// MARK: - About / legal

enum AppLinks {
    /// Set once a privacy page is hosted.
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
                            Text("📓 Skill Journal")
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
                         "Skill Journal has no accounts, no analytics, and no tracking. Your routines, check-offs, supplies list and progress photos stay on your phone — nothing is uploaded, ever.")

                    if let url = AppLinks.privacyURL {
                        Link(destination: url) {
                            Text("Read the full privacy policy ↗")
                                .font(.footnote.weight(.heavy))
                                .foregroundColor(.roseDeep)
                        }
                        .padding(.leading, 4)
                    }

                    card("Guidance, not professional advice",
                         "Skill Journal offers general guidance and habit tracking only — it isn't medical, veterinary, financial or other professional advice. For anything high-stakes, please consult a professional.")

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

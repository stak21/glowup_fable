//  SkincareBasics.swift
//  Clearing

import SwiftUI

// MARK: - Skincare 101 (post-quiz education)

/// Newcomer walkthrough of what each product type does, shown between the
/// quiz and the kit recommendation. The media box on each page is a
/// placeholder for a future custom video.
struct BasicsPage: Identifiable {
    let emoji: String
    let title: String
    let when: String
    let what: String
    let tip: String
    var id: String { title }

    static let all: [BasicsPage] = [
        BasicsPage(emoji: "🫧", title: "Cleanser",
                   when: "Morning + night · always step 1",
                   what: "Washes away oil, sunscreen and the day so everything you apply after can actually reach your skin.",
                   tip: "Gentle is the goal — if your face feels squeaky or tight afterwards, it's too harsh."),
        BasicsPage(emoji: "✨", title: "Exfoliant",
                   when: "A few nights a week · after cleansing",
                   what: "Acids like glycolic or salicylic dissolve the layer of dead skin that makes you look dull and clogs pores.",
                   tip: "Start slow — two nights a week — and never stack two acids on the same night."),
        BasicsPage(emoji: "💧", title: "Treatment",
                   when: "Daily · the middle of your routine",
                   what: "Serums are concentrated actives with one job each: vitamin C brightens, niacinamide calms, retinoids renew.",
                   tip: "Add one new active at a time, so you know what's working — or what's irritating."),
        BasicsPage(emoji: "🧴", title: "Moisturizer",
                   when: "Morning + night · near the end",
                   what: "Seals everything in and keeps your skin barrier happy. Hydrated skin heals faster and irritates slower.",
                   tip: "Oily skin needs it too — skipping moisturizer often makes oil worse."),
        BasicsPage(emoji: "☀️", title: "SPF",
                   when: "Every morning · always last",
                   what: "Sunscreen is the single biggest anti-aging and anti-dark-spot step there is. Nothing else works if you skip it.",
                   tip: "A nickel-sized amount for the face, every single day — clouds don't count as protection."),
        BasicsPage(emoji: "🌸", title: "Extras",
                   when: "As needed",
                   what: "Masks, eye creams, steam and tools — the treat-yourself layer that supports the core steps.",
                   tip: "Nice to have, never required. A solid core routine beats a drawer full of extras."),
    ]
}

struct SkincareBasicsView: View {
    let onContinue: () -> Void
    @State private var page = 0

    private let pages = BasicsPage.all
    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skincare 101")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("A 60-second tour of what each product actually does.")
                        .font(.subheadline)
                        .foregroundColor(.soft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, p in
                        pageCard(p)
                            .padding(.horizontal, 24)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.rose : Color.faint.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }

                Button {
                    if isLast {
                        onContinue()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                    }
                } label: {
                    Text(isLast ? "See my match ♡" : "Next")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.rose))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Skip") { onContinue() }
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.roseDeep)
            }
        }
    }

    private func pageCard(_ p: BasicsPage) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(Color.roseTint)
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.rose)
                        Text("Video coming soon")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.roseDeep)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)

                HStack(spacing: 10) {
                    Text(p.emoji).font(.title2)
                    Text(p.title)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                }
                Text(p.when.uppercased())
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.rose)
                Text(p.what)
                    .font(.subheadline)
                    .foregroundColor(.ink)
                    .lineSpacing(3)
                Text("💡 \(p.tip)")
                    .font(.footnote)
                    .foregroundColor(.soft)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.8)))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.white)
                .shadow(color: Color.rose.opacity(0.09), radius: 8, y: 3))
        }
    }
}

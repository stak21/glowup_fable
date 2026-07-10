//  RoutineQuiz.swift
//  Clearing

import SwiftUI

// MARK: - Skin quiz

struct QuizSheet: View {
    let kits: [RoutineKit]
    let catalog: [ShopProduct]
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var skinType: SkinType?
    @State private var concern: Effect?
    @State private var tier: RoutineTier?

    private var recommendedKit: RoutineKit? {
        guard let concern, let tier else { return nil }
        return kits.first { $0.id == "\(concern.rawValue)-\(tier.rawValue)" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            if step > 0 {
                                Button {
                                    withAnimation { step -= 1 }
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.subheadline.weight(.heavy))
                                        .foregroundColor(.soft)
                                }
                            }
                            Spacer()
                            Text("\(step + 1) of 3")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.faint)
                        }
                        .padding(.top, 20)

                        switch step {
                        case 0: skinTypeStep
                        case 1: concernStep
                        default: tierStep
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: .init(
                get: { store.quizResult != nil && step == 3 },
                set: { if !$0 { step = 2 } }
            )) {
                if let kit = recommendedKit {
                    resultView(kit)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Steps

    private var skinTypeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("How does your skin feel most days?",
                   sub: "This helps us pick gentler options if you need them.")
            ForEach(SkinType.allCases) { type in
                optionCard(emoji: type.emoji, title: type.displayName, selected: skinType == type) {
                    skinType = type
                    advance()
                }
            }
        }
    }

    private var concernStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("What's your main goal right now?",
                   sub: "Pick the one that matters most — you can always explore the rest.")
            optionCard(emoji: "🫧", title: "Clear breakouts", selected: concern == .acne) { concern = .acne; advance() }
            optionCard(emoji: "🎯", title: "Fade dark spots", selected: concern == .darkSpots) { concern = .darkSpots; advance() }
            optionCard(emoji: "🌸", title: "Smooth texture & glow", selected: concern == .texture) { concern = .texture; advance() }
            optionCard(emoji: "💧", title: "Deep hydration", selected: concern == .hydration) { concern = .hydration; advance() }
            optionCard(emoji: "⏳", title: "Slow the clock", selected: concern == .antiAging) { concern = .antiAging; advance() }
        }
    }

    private var tierStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("How much do you want to spend?",
                   sub: "Every tier works — this is about texture and treat-yourself factor.")
            ForEach(RoutineTier.allCases) { t in
                optionCard(emoji: t.emoji, title: t.displayName, subtitle: t.hint, selected: tier == t) {
                    tier = t
                    finish()
                }
            }
        }
    }

    private func resultView(_ kit: RoutineKit) -> some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("✨ Your match")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.rose)
                        .padding(.top, 12)
                    if let skinType, let concern {
                        Text("Because you're \(skinType.displayName.lowercased()) and want to \(goalPhrase(concern)), we built you this:")
                            .font(.subheadline)
                            .foregroundColor(.soft)
                    }
                    KitSheetContent(kit: kit, catalog: catalog)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.roseDeep)
            }
        }
    }

    // MARK: Helpers

    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
    }

    private func finish() {
        guard let skinType, let concern, let tier else { return }
        store.quizResult = QuizResult(skinType: skinType, concern: concern, tier: tier)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { step = 3 }
    }

    private func goalPhrase(_ concern: Effect) -> String {
        switch concern {
        case .acne: return "clear breakouts"
        case .darkSpots: return "fade dark spots"
        case .texture: return "smooth and glow"
        case .hydration: return "hydrate deeply"
        case .antiAging: return "stay ahead of aging"
        default: return "glow"
        }
    }

    private func header(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundColor(.ink)
            Text(sub)
                .font(.subheadline)
                .foregroundColor(.soft)
        }
    }

    private func optionCard(emoji: String, title: String, subtitle: String? = nil,
                            selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.soft)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? .rose : .faint)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Color.roseTint : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Color.rose : Color.lineC, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}

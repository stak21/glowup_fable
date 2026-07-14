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

    // "Not sure" mini skin check
    @State private var findingType = false
    @State private var finderAnswers: [Int?] = [nil, nil, nil]
    @State private var finderStep = 0

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
                            if step > 0 || findingType {
                                Button {
                                    withAnimation {
                                        if findingType {
                                            if finderStep > 0 { finderStep -= 1 } else { findingType = false }
                                        } else {
                                            step -= 1
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.subheadline.weight(.heavy))
                                        .foregroundColor(.soft)
                                }
                            }
                            Spacer()
                            Text(findingType
                                 ? (finderStep < Self.finderQuestions.count ? "Skin check \(finderStep + 1) of 3" : "Skin check")
                                 : "\(step + 1) of 3")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.faint)
                        }
                        .padding(.top, 20)

                        switch step {
                        case 0:
                            if findingType { typeFinderStep } else { skinTypeStep }
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
                // Skincare 101 first, then the kit reveal.
                if let kit = recommendedKit {
                    BasicsGate { resultView(kit) }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onReceive(NotificationCenter.default.publisher(for: .kitRoutinesBuilt)) { _ in
            dismiss() // routines built — get out of the way so Today shows them
        }
    }

    // MARK: Steps

    private var skinTypeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("How does your skin feel most days?",
                   sub: "This helps us pick gentler options if you need them.")
            ForEach([SkinType.oily, .dry, .combination, .sensitive]) { type in
                optionCard(emoji: type.emoji, title: type.displayName, subtitle: type.cue,
                           selected: skinType == type) {
                    skinType = type
                    advance()
                }
            }
            Button {
                finderAnswers = [nil, nil, nil]
                finderStep = 0
                withAnimation(.easeInOut(duration: 0.2)) { findingType = true }
            } label: {
                HStack(spacing: 12) {
                    Text("🤔").font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not sure? Let's find out")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.ink)
                        Text("Three quick questions, about 30 seconds")
                            .font(.caption)
                            .foregroundColor(.soft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.faint)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.rose.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: "Not sure" mini skin check

    private struct FinderOption {
        let emoji: String
        let title: String
        var vote: SkinType? = nil   // nil = neutral, no signal
    }
    private struct FinderQuestion {
        let title: String
        let sub: String
        let options: [FinderOption]
    }

    private static let finderQuestions: [FinderQuestion] = [
        FinderQuestion(
            title: "An hour after washing your face — no products — it usually feels…",
            sub: "This bare-faced hour is the classic at-home skin test.",
            options: [
                FinderOption(emoji: "😬", title: "Tight, uncomfortable, maybe flaky", vote: .dry),
                FinderOption(emoji: "😊", title: "Comfortable — I barely notice it", vote: .combination),
                FinderOption(emoji: "🌗", title: "Oily in spots — forehead, nose, chin", vote: .combination),
                FinderOption(emoji: "✨", title: "Shiny or greasy all over", vote: .oily),
            ]),
        FinderQuestion(
            title: "By late afternoon on a normal day, your face looks…",
            sub: "End-of-day shine (or flaking) is where your type shows itself.",
            options: [
                FinderOption(emoji: "🏜️", title: "Dull, rough, or flaky in places", vote: .dry),
                FinderOption(emoji: "🌗", title: "Shiny in the T-zone, fine elsewhere", vote: .combination),
                FinderOption(emoji: "✨", title: "Shiny pretty much everywhere", vote: .oily),
                FinderOption(emoji: "😌", title: "About the same as the morning"),
            ]),
        FinderQuestion(
            title: "When you try new products, how does your skin react?",
            sub: "Stinging, burning, or redness points to a delicate skin barrier.",
            options: [
                FinderOption(emoji: "🌷", title: "It often stings, burns, or turns red", vote: .sensitive),
                FinderOption(emoji: "🤏", title: "The occasional tingle, nothing dramatic"),
                FinderOption(emoji: "💪", title: "Rarely or never reacts"),
            ]),
    ]

    /// Sensitive wins outright; otherwise unanimous votes decide, and any
    /// split verdict lands on combination.
    private var finderVerdict: SkinType {
        let votes = zip(Self.finderQuestions, finderAnswers).compactMap { q, a in
            a.flatMap { q.options[$0].vote }
        }
        if votes.contains(.sensitive) { return .sensitive }
        guard let first = votes.first else { return .combination }
        return votes.allSatisfy { $0 == first } ? first : .combination
    }

    private var typeFinderStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if finderStep < Self.finderQuestions.count {
                let q = Self.finderQuestions[finderStep]
                header(q.title, sub: q.sub)
                ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                    optionCard(emoji: option.emoji, title: option.title,
                               selected: finderAnswers[finderStep] == i) {
                        finderAnswers[finderStep] = i
                        withAnimation(.easeInOut(duration: 0.2)) { finderStep += 1 }
                    }
                }
            } else {
                let verdict = finderVerdict
                header("Sounds like \(verdict.displayName.lowercased()) skin \(verdict.emoji)",
                       sub: verdict.cue)
                Button {
                    skinType = verdict
                    withAnimation(.easeInOut(duration: 0.2)) {
                        findingType = false
                        step += 1
                    }
                } label: {
                    Text("That's me — use \(verdict.displayName.lowercased())")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.rose))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { findingType = false }
                } label: {
                    Text("I'd rather pick myself")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.roseDeep)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                Text("Skin shifts with seasons, stress, and hormones — you can retake the quiz anytime.")
                    .font(.caption)
                    .foregroundColor(.faint)
                    .padding(.top, 10)
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

    /// Shows Skincare 101, then pushes the quiz result when the user
    /// continues (or skips).
    private struct BasicsGate<Result: View>: View {
        @ViewBuilder let result: () -> Result
        @State private var showResult = false

        var body: some View {
            SkincareBasicsView(onContinue: { showResult = true })
                .navigationDestination(isPresented: $showResult) { result() }
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

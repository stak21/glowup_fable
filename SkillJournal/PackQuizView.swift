//  PackQuizView.swift
//  Skill Journal
//
//  Pack-driven onboarding quiz — the shell of GlowUp's skin quiz (progress
//  header, option cards, back chevron) rendering PackQuiz data. Each option
//  carries weighted votes for templates; the highest total wins and the
//  result screen embeds the recommended template.

import SwiftUI

struct PackQuizSheet: View {
    let pack: DomainPack
    let quiz: PackQuiz
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var answers: [Int?]

    init(pack: DomainPack, quiz: PackQuiz) {
        self.pack = pack
        self.quiz = quiz
        _answers = State(initialValue: Array(repeating: nil, count: quiz.questions.count))
    }

    private var isResult: Bool { step >= quiz.questions.count }

    /// Sums templateVotes across the chosen options; highest total wins,
    /// falling back to the pack's first template.
    private var recommendedTemplate: RoutineTemplate? {
        var scores: [String: Int] = [:]
        for (question, answer) in zip(quiz.questions, answers) {
            guard let answer, question.options.indices.contains(answer) else { continue }
            for (templateID, weight) in question.options[answer].templateVotes {
                scores[templateID, default: 0] += weight
            }
        }
        let ranked = scores.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        if let best = ranked.first?.key, let template = pack.templates.first(where: { $0.id == best }) {
            return template
        }
        return pack.templates.first
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
                            Text(isResult ? "Your match" : "\(step + 1) of \(quiz.questions.count)")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.faint)
                        }
                        .padding(.top, 20)

                        if isResult {
                            resultView
                        } else {
                            questionView(quiz.questions[step])
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onReceive(NotificationCenter.default.publisher(for: .templateRoutinesBuilt)) { _ in
            dismiss() // routines built — get out of the way so Today shows them
        }
    }

    // MARK: Steps

    private func questionView(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.prompt)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundColor(.ink)
            ForEach(Array(question.options.enumerated()), id: \.offset) { i, option in
                optionCard(option, selected: answers[step] == i) {
                    answers[step] = i
                    withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                }
            }
        }
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("✨ Your match")
                .font(.caption.weight(.heavy))
                .foregroundColor(.rose)
                .padding(.top, 12)
            if let template = recommendedTemplate {
                Text("Based on your answers, we'd start you here:")
                    .font(.subheadline)
                    .foregroundColor(.soft)
                TemplateSheetContent(template: template, pack: pack)
            } else {
                Text("This pack has no templates yet — build a routine by hand from Today.")
                    .font(.subheadline)
                    .foregroundColor(.soft)
            }
        }
    }

    private func optionCard(_ option: QuizOption, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(option.emoji).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                    if let subtitle = option.subtitle {
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

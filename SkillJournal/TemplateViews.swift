//  TemplateViews.swift
//  Skill Journal
//
//  Starter-template browsing and the build-my-routine flow, carried over
//  from GlowUp's kit views: template card → sheet → review-before-create.
//  Nothing is saved until "Create my routines"; a double-fired create is a
//  no-op; sheets dismiss via .templateRoutinesBuilt and RootView switches
//  to Today.

import SwiftUI

// MARK: - Template card (Explore)

struct TemplateCard: View {
    let template: RoutineTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(template.routines.enumerated()), id: \.offset) { _, r in
                    Text(r.emoji).font(.title3)
                }
                Spacer()
            }
            Text(template.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.ink)
                .lineLimit(1)
            Text("\(template.routines.count) routine\(template.routines.count == 1 ? "" : "s") · \(template.routines.reduce(0) { $0 + $1.steps.count }) steps")
                .font(.caption)
                .foregroundColor(.soft)
        }
        .padding(14)
        .frame(width: 190, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
    }
}

// MARK: - Template detail

/// Standalone sheet wrapper around TemplateSheetContent.
struct TemplateSheet: View {
    let template: RoutineTemplate
    let pack: DomainPack
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                TemplateSheetContent(template: template, pack: pack)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onReceive(NotificationCenter.default.publisher(for: .templateRoutinesBuilt)) { _ in
            dismiss() // routines built — get out of the way so Today shows them
        }
    }
}

/// Template detail body — used inside TemplateSheet and the quiz result screen.
struct TemplateSheetContent: View {
    let template: RoutineTemplate
    let pack: DomainPack
    @EnvironmentObject var store: AppStore
    /// Drafts under review ride along with the sheet so a stale set can't linger.
    private struct ReviewRequest: Identifiable {
        let drafts: [Routine]
        var id: String { drafts.map(\.id).joined() }
    }
    @State private var reviewRequest: ReviewRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(pack.emoji) \(template.title)")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundColor(.ink)
                Text(template.blurb)
                    .font(.subheadline)
                    .foregroundColor(.soft)
            }

            ForEach(Array(template.routines.enumerated()), id: \.offset) { _, routine in
                routineCard(routine)
            }

            let built = store.hasTemplateRoutines(template.id)
            Button {
                if built {
                    // Already built — this is a link to Today now, not a rebuild.
                    NotificationCenter.default.post(name: .templateRoutinesBuilt, object: nil)
                } else {
                    reviewRequest = ReviewRequest(drafts: store.draftRoutines(from: template, pack: pack))
                }
            } label: {
                Text(built ? "Routines created — see Today →" : "Build my routine ♡")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(built ? Color.greenC : Color.rose))
            }
        }
        .sheet(item: $reviewRequest) { TemplateReviewSheet(pack: pack, drafts: $0.drafts) }
    }

    private func routineCard(_ routine: TemplateRoutine) -> some View {
        let theme = RoutineTheme(rawValue: routine.theme) ?? pack.theme
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(routine.emoji)
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 12).fill(theme.tint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                    Text(dayLine(routine.days))
                        .font(.caption2)
                        .foregroundColor(.soft)
                }
                Spacer()
            }
            ForEach(Array(routine.steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.faint)
                        .frame(width: 16, alignment: .trailing)
                    Text(step.label)
                        .font(.footnote)
                        .foregroundColor(.ink)
                    Spacer()
                    if let chip = step.cadence?.chipLabel {
                        Text(chip)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.bodyCoral)
                    }
                    if let wait = step.waitMinutes {
                        Text("wait \(wait)m")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.amGold)
                    }
                }
            }
            if let footer = routine.footer {
                Text(footer)
                    .font(.caption)
                    .foregroundColor(.roseDeep)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.roseTint.opacity(0.7)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
    }

    private func dayLine(_ days: [Int]) -> String {
        if Set(days) == Set(0...6) { return "Every day" }
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().compactMap { names.indices.contains($0) ? names[$0] : nil }
            .joined(separator: " · ")
    }
}

// MARK: - Template review ("build my routine" confirmation)

/// Full-edit review of the routines a template drafts: rename them, reorder,
/// remove or add steps — nothing is created until the button says so.
struct TemplateReviewSheet: View {
    let pack: DomainPack
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [Routine]

    init(pack: DomainPack, drafts: [Routine]) {
        self.pack = pack
        _drafts = State(initialValue: drafts)
    }

    private var canCreate: Bool {
        drafts.allSatisfy { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Review your routines")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundColor(.ink)
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

                    Text("Rename anything, drag to reorder, tap a step to tweak. Nothing is saved until you create them.")
                        .font(.subheadline)
                        .foregroundColor(.soft)

                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text(draft.emoji)
                                    .font(.title3)
                                    .frame(width: 38, height: 38)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(draft.theme.tint))
                                TextField("Routine name", text: $draft.title)
                                    .font(.system(.headline, design: .serif).weight(.semibold))
                                    .foregroundColor(.ink)
                                    .submitLabel(.done)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lineC, lineWidth: 1))
                            }
                            StepListEditor(steps: $draft.steps,
                                           omitCoreCategories: draft.omitCoreCategories,
                                           pack: pack)
                        }
                        .padding(.top, 6)
                    }

                    Button {
                        create()
                    } label: {
                        Text("Create my routines ♡")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(canCreate ? Color.rose : Color.faint))
                    }
                    .disabled(!canCreate)
                    .padding(.top, 8)

                    Text("Days, colors and photo check-ins can be changed anytime — tap the pencil on Today.")
                        .font(.caption)
                        .foregroundColor(.faint)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func create() {
        store.createRoutines(drafts)
        NotificationCenter.default.post(name: .templateRoutinesBuilt, object: nil)
        dismiss()
    }
}

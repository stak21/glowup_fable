//  RoutineEditor.swift
//  Skill Journal

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Routine manager (list / reorder / add / delete)

struct RoutineManagerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingRoutine: Routine?
    @State private var creatingRoutine: Routine?
    @State private var deletingID: String?
    @State private var draggedID: String?

    private let displayDayOrder = [1, 2, 3, 4, 5, 6, 0]
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Your routines")
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

                    Text("Drag to reorder · tap to edit")
                        .font(.caption)
                        .foregroundColor(.soft)

                    VStack(spacing: 10) {
                        ForEach(store.routines) { routine in
                            routineRow(routine)
                                .opacity(draggedID == routine.id ? 0.4 : 1)
                                .onDrag {
                                    draggedID = routine.id
                                    return NSItemProvider(object: routine.id as NSString)
                                }
                                .onDrop(of: [.text], delegate: SectionDropDelegate(
                                    item: routine.id,
                                    draggedKey: $draggedID,
                                    reorder: { store.moveRoutine($0, over: $1) }))
                        }
                    }
                    .onDrop(of: [.text], isTargeted: nil) { _ in
                        draggedID = nil
                        return true
                    }

                    Button {
                        creatingRoutine = Routine(
                            id: "rt-" + UUID().uuidString.prefix(8).lowercased(),
                            title: "", emoji: "✨", days: Set(0...6), steps: [])
                    } label: {
                        Label("New routine", systemImage: "plus")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(Color.rose))
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $editingRoutine) { RoutineEditorSheet(routine: $0, isNew: false) }
        .sheet(item: $creatingRoutine) { RoutineEditorSheet(routine: $0, isNew: true) }
        .confirmationDialog("Delete this routine?", isPresented: .init(
            get: { deletingID != nil }, set: { if !$0 { deletingID = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deletingID { store.deleteRoutine(id: id) }
                deletingID = nil
            }
        } message: {
            Text("Only the routine goes — your check history stays.")
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        Button { editingRoutine = routine } label: {
            HStack(spacing: 12) {
                Text(routine.emoji)
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 12).fill(routine.theme.tint))
                VStack(alignment: .leading, spacing: 3) {
                    Text(routine.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                    if let focus = routine.focus ?? routine.subtitle {
                        Text(focus)
                            .font(.caption2)
                            .foregroundColor(.soft)
                            .lineLimit(1)
                    }
                    HStack(spacing: 3) {
                        ForEach(displayDayOrder, id: \.self) { d in
                            let active = routine.days.contains(d)
                            Text(dayLetters[d])
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(active ? .white : .faint)
                                .frame(width: 15, height: 15)
                                .background(Circle().fill(active ? routine.theme.accent : Color.clear))
                        }
                        Text("· \(routine.steps.count) steps")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.soft)
                            .padding(.leading, 2)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.faint)
                Button { deletingID = routine.id } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.faint)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Routine editor

struct RoutineEditorSheet: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var packStore: PackStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Routine
    let isNew: Bool

    @State private var confirmDelete = false
    @FocusState private var titleFocused: Bool

    private let displayDayOrder = [1, 2, 3, 4, 5, 6, 0]
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let emojiChoices = ["☀️", "🌙", "🌱", "🐾", "🏋️", "🧹", "🧠", "📚", "🎨", "🧘", "💧", "✨"]

    init(routine: Routine, isNew: Bool) {
        _draft = State(initialValue: routine)
        self.isNew = isNew
    }

    private var pack: DomainPack? { packStore.pack(for: draft) }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty && !draft.days.isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(isNew ? "New routine" : "Edit routine")
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

                    TextField("Routine name", text: $draft.title)
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { titleFocused = false }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lineC, lineWidth: 1))

                    caption("LOOK")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(emojiChoices, id: \.self) { e in
                                Button { draft.emoji = e } label: {
                                    Text(e)
                                        .font(.system(size: 18))
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(draft.emoji == e ? Color.roseTint : Color.white))
                                        .overlay(Circle().stroke(draft.emoji == e ? Color.rose : Color.lineC, lineWidth: 1))
                                }
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        ForEach(RoutineTheme.allCases) { theme in
                            Button { draft.theme = theme } label: {
                                Circle()
                                    .fill(theme.accent)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.ink.opacity(draft.theme == theme ? 0.6 : 0), lineWidth: 2))
                            }
                        }
                    }

                    caption("DAYS")
                    HStack(spacing: 5) {
                        ForEach(displayDayOrder, id: \.self) { d in
                            let on = draft.days.contains(d)
                            Button {
                                if on { draft.days.remove(d) } else { draft.days.insert(d) }
                            } label: {
                                Text(dayLetters[d])
                                    .font(.caption.weight(.heavy))
                                    .foregroundColor(on ? .white : .soft)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(on ? Color.rose : Color.roseTint))
                            }
                        }
                    }

                    caption("PHOTO CHECK-INS")
                    Menu {
                        Button("None") { draft.photoArea = nil }
                        ForEach(packStore.allPhotoAreas) { area in
                            Button("\(area.emoji) \(area.title)") { draft.photoArea = area.id }
                        }
                    } label: {
                        HStack {
                            if let key = draft.photoArea,
                               let area = packStore.allPhotoAreas.first(where: { $0.id == key }) {
                                Text("\(area.emoji) \(area.title)")
                                    .foregroundColor(.ink)
                            } else {
                                Text("No photo prompts")
                                    .foregroundColor(.faint)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.faint)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lineC, lineWidth: 1))
                    }

                    caption("STEPS · IN ORDER")
                    StepListEditor(steps: $draft.steps,
                                   omitCoreCategories: draft.omitCoreCategories,
                                   pack: pack)

                    Button {
                        save()
                    } label: {
                        Text(isNew ? "Create routine ♡" : "Save changes ♡")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(canSave ? Color.rose : Color.faint))
                    }
                    .disabled(!canSave)

                    if !isNew {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Delete routine")
                                .font(.subheadline.weight(.heavy))
                                .foregroundColor(.roseDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(Color.roseTint))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Delete this routine?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deleteRoutine(id: draft.id)
                dismiss()
            }
        }
    }

    // MARK: Pieces

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundColor(.soft)
    }

    private func save() {
        if isNew {
            store.addRoutine(draft)
        } else {
            store.updateRoutine(draft)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Step list editor

/// Reusable steps editor: numbered rows (tap to tweak wait/note/cadence),
/// drag to reorder, x to delete, dashed placeholder slots for the pack's
/// missing core categories, and an add-step picker. Edits land in the bound
/// array — the owner decides when (or whether) they're saved.
struct StepListEditor: View {
    @EnvironmentObject var store: AppStore
    @Binding var steps: [RStep]
    /// Core categories this routine deliberately skips — suppresses their
    /// "add a ___" placeholder (e.g. covered by a sibling template routine).
    var omitCoreCategories: Set<String> = []
    /// The routine's pack — drives placement ranks, placeholders and defaults.
    var pack: DomainPack? = nil

    @State private var editingStepKey: String?
    @State private var draggedStepKey: String?
    /// Item-driven picker presentation: the tapped slot's category rides along with
    /// the sheet, so the filter can't lag a tap.
    private struct PickerRequest: Identifiable {
        let categoryID: String?
        var id: String { categoryID ?? "any" }
    }
    @State private var pickerRequest: PickerRequest?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.element.key) { index, step in
                stepRow(step, num: index + 1)
                    .opacity(draggedStepKey == step.key ? 0.4 : 1)
                    .onDrag {
                        draggedStepKey = step.key
                        return NSItemProvider(object: step.key as NSString)
                    }
                    .onDrop(of: [.text], delegate: SectionDropDelegate(
                        item: step.key,
                        draggedKey: $draggedStepKey,
                        reorder: moveStep))
            }
            ForEach(RoutinePlacement.missingCoreCategories(in: steps, omit: omitCoreCategories, pack: pack)) { category in
                placeholderSlot(category)
            }
            Button {
                pickerRequest = PickerRequest(categoryID: nil)
            } label: {
                Label("Add a step", systemImage: "plus")
                    .font(.footnote.weight(.heavy))
                    .foregroundColor(.roseDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.roseTint))
            }
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            draggedStepKey = nil
            return true
        }
        .sheet(item: $pickerRequest) { request in
            StepPickerSheet(initialCategoryID: request.categoryID,
                            pack: pack,
                            onPickProduct: { productID, categoryID in
                                addStep(productID: productID, categoryID: categoryID)
                            },
                            onPickCustom: { label, categoryID in
                                addCustomStep(label: label, categoryID: categoryID)
                            })
        }
        .sheet(item: .init(
            get: { editingStepKey.flatMap { key in steps.first { $0.key == key } } },
            set: { if $0 == nil { editingStepKey = nil } }
        )) { step in
            StepEditSheet(step: step) { updated in
                if let idx = steps.firstIndex(where: { $0.key == updated.key }) {
                    steps[idx] = updated
                }
            }
        }
    }

    private func stepRow(_ step: RStep, num: Int) -> some View {
        let name = step.label ?? step.productID.flatMap { store.productInfo($0)?.name } ?? "Step"
        return Button { editingStepKey = step.key } label: {
            HStack(spacing: 10) {
                Text("\(num)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.faint)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                    HStack(spacing: 6) {
                        if let category = pack?.category(step.categoryID) {
                            Text(category.name.uppercased())
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.soft)
                        }
                        if let wait = step.wait {
                            Text("wait \(wait) min")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.amGold)
                        }
                        if let chip = step.cadence?.chipLabel {
                            Text(chip)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.bodyCoral)
                        }
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "line.3.horizontal")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.faint)
                Button {
                    steps.removeAll { $0.key == step.key }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.faint)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lineC, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func placeholderSlot(_ category: PackCategory) -> some View {
        Button {
            pickerRequest = PickerRequest(categoryID: category.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.dashed")
                    .foregroundColor(.soft)
                Text("Add a \(category.name.lowercased())")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.soft)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.faint, style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
        .buttonStyle(.plain)
    }

    private func moveStep(_ draggedKey: String, over targetKey: String) {
        guard let from = steps.firstIndex(where: { $0.key == draggedKey }),
              let to = steps.firstIndex(where: { $0.key == targetKey }), from != to else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            steps.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    private func addStep(productID: String, categoryID: String?) {
        let info = store.productInfo(productID)
        let text = "\(info?.name ?? "") \(info?.tag ?? "")"
        let step = RStep(key: "st-" + UUID().uuidString.prefix(8).lowercased(),
                         productID: productID,
                         wait: pack?.defaultWaitMinutes(stepText: text, categoryID: categoryID),
                         cadence: pack?.defaultCadence(stepText: text, categoryID: categoryID),
                         categoryID: categoryID)
        steps.insert(step, at: RoutinePlacement.insertionIndex(for: categoryID, in: steps, pack: pack))
    }

    private func addCustomStep(label: String, categoryID: String?) {
        let step = RStep(key: "st-" + UUID().uuidString.prefix(8).lowercased(),
                         label: label,
                         wait: pack?.defaultWaitMinutes(stepText: label, categoryID: categoryID),
                         cadence: pack?.defaultCadence(stepText: label, categoryID: categoryID),
                         categoryID: categoryID)
        steps.insert(step, at: RoutinePlacement.insertionIndex(for: categoryID, in: steps, pack: pack))
    }
}

// MARK: - Step editor

struct StepEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: RStep
    let onSave: (RStep) -> Void

    init(step: RStep, onSave: @escaping (RStep) -> Void) {
        _step = State(initialValue: step)
        self.onSave = onSave
    }

    private var waitBinding: Binding<Int> {
        Binding(get: { step.wait ?? 0 }, set: { step.wait = $0 == 0 ? nil : $0 })
    }

    private var everyOtherDayBinding: Binding<Bool> {
        Binding(get: { step.cadence?.kind == "everyOtherDay" },
                set: { step.cadence = $0 ? .everyOtherDay : nil })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step details")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundColor(.ink)
                .padding(.top, 20)

            Stepper(value: waitBinding, in: 0...30) {
                Text(step.wait.map { "Wait \($0) min after" } ?? "No wait timer")
                    .font(.subheadline)
                    .foregroundColor(.ink)
            }

            TextField("Note (optional)", text: .init(
                get: { step.note ?? "" },
                set: { step.note = $0.isEmpty ? nil : $0 }
            ))
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lineC, lineWidth: 1))

            if step.cadence?.kind == "days" {
                HStack {
                    Text("Active on")
                        .font(.subheadline)
                        .foregroundColor(.ink)
                    Spacer()
                    Text(step.cadence?.chipLabel ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.bodyCoral)
                }
            } else {
                Toggle(isOn: everyOtherDayBinding) {
                    Text("Every other day")
                        .font(.subheadline)
                        .foregroundColor(.ink)
                }
                .tint(.rose)
            }

            Button {
                onSave(step)
                dismiss()
            } label: {
                Text("Done ♡")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Color.rose))
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Step picker (pack products + custom steps)

struct StepPickerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let initialCategoryID: String?
    let pack: DomainPack?
    let onPickProduct: (String, String?) -> Void
    let onPickCustom: (String, String?) -> Void

    @State private var query = ""
    @State private var categoryID: String?

    init(initialCategoryID: String?,
         pack: DomainPack?,
         onPickProduct: @escaping (String, String?) -> Void,
         onPickCustom: @escaping (String, String?) -> Void) {
        self.initialCategoryID = initialCategoryID
        self.pack = pack
        self.onPickProduct = onPickProduct
        self.onPickCustom = onPickCustom
        _categoryID = State(initialValue: initialCategoryID)
    }

    private var products: [PackProduct] {
        var result = pack?.products ?? []
        if let categoryID {
            result = result.filter { $0.categoryID == categoryID }
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(q) || $0.tag.localizedCaseInsensitiveContains(q)
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add a step")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                        .padding(.top, 20)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.faint)
                        TextField("Search, or type your own step", text: $query)
                            .font(.subheadline)
                            .foregroundColor(.ink)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().stroke(Color.lineC, lineWidth: 1))

                    if let pack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(pack.categories) { c in
                                    let active = categoryID == c.id
                                    Button { categoryID = active ? nil : c.id } label: {
                                        Text("\(c.emoji) \(c.name)")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundColor(active ? .white : .ink)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(active ? Color.rose : Color.white))
                                            .overlay(Capsule().stroke(active ? Color.rose : Color.lineC, lineWidth: 1))
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    // Free-text step: whatever was typed becomes a custom step.
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            onPickCustom(query.trimmingCharacters(in: .whitespaces), categoryID)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.rose)
                                Text("Add step \"\(query.trimmingCharacters(in: .whitespaces))\"")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.ink)
                                Spacer()
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.rose.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                        }
                        .buttonStyle(.plain)
                    }

                    if products.isEmpty && query.isEmpty {
                        Text("No suggestions for this filter — type a step name above to add your own.")
                            .font(.footnote)
                            .foregroundColor(.soft)
                            .padding(.vertical, 20)
                    }

                    VStack(spacing: 8) {
                        ForEach(products) { product in
                            HStack(spacing: 10) {
                                Button {
                                    onPickProduct(product.id, product.categoryID ?? initialCategoryID)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(product.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.ink)
                                            Text(product.tag)
                                                .font(.caption)
                                                .foregroundColor(.soft)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 8)
                                        if let c = pack?.category(product.categoryID) {
                                            Text(c.name.uppercased())
                                                .font(.system(size: 8, weight: .heavy))
                                                .foregroundColor(.soft)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    store.toggleWishlist(product.id)
                                } label: {
                                    Image(systemName: store.isWishlisted(product.id) ? "heart.fill" : "heart")
                                        .font(.subheadline)
                                        .foregroundColor(.rose)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    onPickProduct(product.id, product.categoryID ?? initialCategoryID)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    dismiss()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.rose)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lineC, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

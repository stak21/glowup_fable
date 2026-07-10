//  Reminders.swift
//  Clearing

import SwiftUI

// MARK: - Reminders

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @State private var newLabel = ""
    @State private var newTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 30)) ?? Date()
    @State private var newDays: Set<Int> = Set(1...7)
    @State private var editingReminder: Reminder?
    @State private var deletingReminder: Reminder?
    @FocusState private var newLabelFocused: Bool
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your reminders")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("These fire as real notifications — lock screen, banners, sounds — even when the app is closed. Tap a reminder to edit it. 💌")
                        .font(.footnote).foregroundColor(.soft)

                    ForEach(store.reminders) { r in
                        HStack(spacing: 12) {
                            Text(String(format: "%d:%02d", r.hour, r.minute))
                                .font(.system(.title3, design: .serif).weight(.semibold))
                                .foregroundColor(.roseDeep)
                                .frame(minWidth: 56, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.label).font(.subheadline.weight(.bold)).foregroundColor(.ink)
                                Text(r.days.count == 7 ? "Every day"
                                     : r.days.sorted().map { dayNames[$0 - 1] }.joined(separator: " · "))
                                    .font(.caption).foregroundColor(.soft)
                            }
                            Spacer()
                            Button {
                                deletingReminder = r
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.heavy))
                                    .foregroundColor(.roseDeep)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(Color.roseTint))
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white)
                            .shadow(color: Color.rose.opacity(0.09), radius: 7, y: 3))
                        .contentShape(Rectangle())
                        .onTapGesture { editingReminder = r }
                    }

                    // Add form
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NEW REMINDER")
                            .font(.caption2.weight(.heavy)).foregroundColor(.soft)
                        HStack(spacing: 8) {
                            DatePicker("", selection: $newTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            TextField("What for? e.g. Spearmint tea 🍵", text: $newLabel)
                                .textFieldStyle(.roundedBorder)
                                .focused($newLabelFocused)
                                .submitLabel(.done)
                                .onSubmit { newLabelFocused = false }
                        }
                        HStack(spacing: 5) {
                            ForEach(1...7, id: \.self) { d in
                                let on = newDays.contains(d)
                                Button {
                                    if on { newDays.remove(d) } else { newDays.insert(d) }
                                } label: {
                                    Text(dayLetters[d - 1])
                                        .font(.caption.weight(.heavy))
                                        .foregroundColor(on ? .white : .soft)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(RoundedRectangle(cornerRadius: 10)
                                            .fill(on ? Color.rose : Color.roseTint))
                                }
                            }
                        }
                        Button {
                            guard !newDays.isEmpty else { return }
                            newLabelFocused = false
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                            let label = newLabel.trimmingCharacters(in: .whitespaces)
                            store.reminders.append(Reminder(
                                label: label.isEmpty ? "Skincare time ♡" : label,
                                hour: comps.hour ?? 8, minute: comps.minute ?? 0, days: newDays))
                            newLabel = ""
                            newDays = Set(1...7)
                        } label: {
                            Text("Add reminder ♡")
                                .font(.subheadline.weight(.heavy))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.rose))
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: Color.rose.opacity(0.10), radius: 8, y: 3))

                    Text("If notifications aren't arriving, check Settings → Notifications → Clearing and make sure Allow Notifications is on.")
                        .font(.caption).foregroundColor(.soft)
                        .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .onTapGesture { newLabelFocused = false }
        .sheet(item: $editingReminder) { r in
            ReminderEditSheet(reminder: r)
        }
        .confirmationDialog("Delete this reminder?",
                            isPresented: Binding(get: { deletingReminder != nil }, set: { if !$0 { deletingReminder = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let r = deletingReminder {
                    store.reminders.removeAll { $0.id == r.id }
                }
                deletingReminder = nil
            }
            Button("Cancel", role: .cancel) { deletingReminder = nil }
        }
    }
}

struct ReminderEditSheet: View {
    @EnvironmentObject var store: AppStore
    let reminder: Reminder
    @Environment(\.dismiss) private var dismiss

    @State private var label: String
    @State private var time: Date
    @State private var days: Set<Int>
    @State private var confirmDelete = false
    @FocusState private var labelFocused: Bool
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    init(reminder: Reminder) {
        self.reminder = reminder
        _label = State(initialValue: reminder.label)
        _time = State(initialValue: Calendar.current.date(from: DateComponents(hour: reminder.hour, minute: reminder.minute)) ?? Date())
        _days = State(initialValue: reminder.days)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Edit reminder")
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

                HStack(spacing: 8) {
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    TextField("What for?", text: $label)
                        .textFieldStyle(.roundedBorder)
                        .focused($labelFocused)
                        .submitLabel(.done)
                        .onSubmit { labelFocused = false }
                }

                HStack(spacing: 5) {
                    ForEach(1...7, id: \.self) { d in
                        let on = days.contains(d)
                        Button {
                            if on { days.remove(d) } else { days.insert(d) }
                        } label: {
                            Text(dayLetters[d - 1])
                                .font(.caption.weight(.heavy))
                                .foregroundColor(on ? .white : .soft)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(on ? Color.rose : Color.roseTint))
                        }
                    }
                }

                Button {
                    save()
                } label: {
                    Text("Save changes ♡")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(days.isEmpty ? Color.faint : Color.rose))
                }
                .disabled(days.isEmpty)

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Text("Delete reminder")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.roseDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.roseTint))
                }
            }
            .padding(24)
        }
        .onTapGesture { labelFocused = false }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Delete this reminder?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.reminders.removeAll { $0.id == reminder.id }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func save() {
        guard !days.isEmpty else { return }
        labelFocused = false
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        var updated = reminder
        updated.label = trimmed.isEmpty ? "Skincare time ♡" : trimmed
        updated.hour = comps.hour ?? 8
        updated.minute = comps.minute ?? 0
        updated.days = days
        if let idx = store.reminders.firstIndex(where: { $0.id == reminder.id }) {
            store.reminders[idx] = updated
        }
        dismiss()
    }
}

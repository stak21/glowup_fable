//  Today.swift
//  Clearing

import SwiftUI
import Combine
import UIKit
import UniformTypeIdentifiers

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab = Tab.today

    /// Today shows the fresh (new-user sandbox) profile; Legacy shows the
    /// user's real routines. Week and Shop follow whichever was entered last.
    enum Tab: Int {
        case today = 0, legacy, week, photos, shop, reminders
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
                .tag(Tab.today)
            TodayView()
                .tabItem { Label("Legacy", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.legacy)
            WeekPlanView()
                .tabItem { Label("Week", systemImage: "calendar") }
                .tag(Tab.week)
            PhotosView()
                .tabItem { Label("Photos", systemImage: "camera.fill") }
                .tag(Tab.photos)
            ShopView()
                .tabItem { Label("Shop", systemImage: "bag.fill") }
                .tag(Tab.shop)
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
                .tag(Tab.reminders)
        }
        .tint(.roseDeep)
        .onAppear {
            selectedTab = store.profile == .legacy ? .legacy : .today
        }
        .onChange(of: selectedTab) { tab in
            if tab == .today { store.switchProfile(.fresh) }
            if tab == .legacy { store.switchProfile(.legacy) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTodayTab)) { _ in
            selectedTab = store.profile == .legacy ? .legacy : .today
        }
        .onReceive(NotificationCenter.default.publisher(for: .openShopTab)) { _ in
            selectedTab = .shop
        }
    }
}

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var infoProduct: Product?
    @State private var isReordering = false
    @State private var draggedKey: String?
    @State private var showManager = false
    @State private var editingRoutine: Routine?
    private let heartbeat = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        ProgressHeader()
                        WeekStrip()
                        sectionIconRow(proxy: proxy)

                        if store.routines.isEmpty {
                            emptyState
                        }

                        ForEach(store.visibleRoutines) { routine in
                            Group {
                                if isReordering {
                                    sectionCard(for: routine)
                                        .opacity(draggedKey == routine.id ? 0.4 : 1)
                                        .onDrag {
                                            draggedKey = routine.id
                                            return NSItemProvider(object: routine.id as NSString)
                                        }
                                        .onDrop(of: [.text], delegate: SectionDropDelegate(
                                            item: routine.id,
                                            draggedKey: $draggedKey,
                                            reorder: { store.moveVisibleRoutine($0, over: $1) }))
                                } else {
                                    sectionCard(for: routine)
                                }
                            }
                            .id(routine.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .onDrop(of: [.text], isTargeted: nil) { _ in
                    draggedKey = nil
                    return true
                }
            }
        }
        .onReceive(heartbeat) { _ in store.tick() }
        .sheet(item: $infoProduct) { ProductSheet(product: $0) }
        .sheet(isPresented: $showManager) { RoutineManagerSheet() }
        .sheet(item: $editingRoutine) { RoutineEditorSheet(routine: $0, isNew: false) }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🌸")
                .font(.system(size: 44))
            Text("No routines yet")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundColor(.ink)
            Text("Build your first ritual with the pencil above,\nor find a starter kit in the Shop.")
                .font(.footnote)
                .foregroundColor(.soft)
                .multilineTextAlignment(.center)
            Button {
                showManager = true
            } label: {
                Text("Create a routine")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.rose))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.85)))
        .padding(.top, 12)
    }

    private func sectionIconRow(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.visibleRoutines) { routine in
                        Button {
                            withAnimation { proxy.scrollTo(routine.id, anchor: .top) }
                        } label: {
                            Text(routine.emoji)
                                .font(.system(size: 18))
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Color.white.opacity(0.85)))
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            Button {
                withAnimation {
                    isReordering.toggle()
                    draggedKey = nil
                }
            } label: {
                Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(isReordering ? Color.greenC : Color.rose))
            }
            Button {
                showManager = true
            } label: {
                Image(systemName: "pencil")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.roseDeep)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.85)))
            }
        }
        .padding(.top, 4)
    }

    private func sectionCard(for routine: Routine) -> some View {
        SectionCard(title: routine.title, emoji: routine.emoji,
                    accent: routine.theme.accent, tint: routine.theme.tint,
                    subtitle: routine.subtitle,
                    steps: store.visibleSteps(for: routine),
                    infoProduct: $infoProduct,
                    footer: dynamicFooter(for: routine),
                    photoArea: routine.photoArea,
                    isReordering: isReordering,
                    onEdit: { editingRoutine = routine })
    }

    /// A routine's own footer wins; otherwise routines with a resting
    /// every-other-day step get the "rests today" note on off days.
    private func dynamicFooter(for routine: Routine) -> String? {
        if let footer = routine.footer { return footer }
        if routine.steps.contains(where: \.everyOtherDay) && !store.azelaicBodyDay {
            return "Azelaic acid rests today — it's back tomorrow ✨"
        }
        return nil
    }
}

struct SectionDropDelegate: DropDelegate {
    let item: String
    @Binding var draggedKey: String?
    let reorder: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedKey, dragged != item else { return }
        reorder(dragged, item)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedKey = nil
        return true
    }
}

// MARK: - Header + week strip

struct ProgressHeader: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.roseTint, lineWidth: 7)
                Circle().trim(from: 0, to: store.progress)
                    .stroke(Color.rose, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: store.progress)
                Text("\(Int(store.progress * 100))%")
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundColor(.roseDeep)
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 2) {
                Text(Calendar.current.isDateInToday(store.selectedDate) ? "Hi lovely ♡" : dayName)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundColor(.ink)
                Text("\(dayName), \(dateLine)\(store.todayFocus.map { " · \($0)" } ?? "")")
                    .font(.footnote).foregroundColor(.soft)
                Text("\(store.doneCount) of \(store.allKeys.count) done · Week 3 — you're doing amazingly 🌷")
                    .font(.caption2).foregroundColor(.faint)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
    private var dayName: String {
        store.selectedDate.formatted(.dateTime.weekday(.wide))
    }
    private var dateLine: String {
        store.selectedDate.formatted(.dateTime.month(.wide).day())
    }
}

struct WeekStrip: View {
    @EnvironmentObject var store: AppStore
    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) // 1=Sun
        let monOffset = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -monOffset, to: cal.startOfDay(for: today))!
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
    }
    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { d in
                let selected = Calendar.current.isDate(d, inSameDayAs: store.selectedDate)
                Button {
                    store.selectedDate = d
                } label: {
                    VStack(spacing: 2) {
                        Text(d.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(selected ? .roseTint : .faint)
                        Text(d.formatted(.dateTime.day()))
                            .font(.system(.subheadline, design: .serif).weight(.semibold))
                            .foregroundColor(selected ? .white : (Calendar.current.isDateInToday(d) ? .roseDeep : .ink))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 13)
                        .fill(selected ? Color.rose : Color.white.opacity(0.75)))
                }
            }
        }
    }
}

// MARK: - Section card + step rows

struct SectionCard: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let emoji: String
    let accent: Color
    let tint: Color
    let subtitle: String?
    let steps: [RStep]
    @Binding var infoProduct: Product?
    var footer: String? = nil
    var photoArea: String? = nil
    var isReordering: Bool = false
    var onEdit: (() -> Void)? = nil
    @State private var open = true
    @State private var showCamera = false
    @State private var cameraUnavailable = false

    private var doneCount: Int { steps.filter { store.isDone($0.key) }.count }
    private var isComplete: Bool { !steps.isEmpty && doneCount == steps.count }
    private var hasPhotoToday: Bool {
        guard let photoArea else { return false }
        return store.photos(for: photoArea).contains { $0.dateKey == store.dateKey(store.selectedDate) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                guard !isReordering else { return }
                withAnimation(.easeInOut(duration: 0.2)) { open.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text(emoji).font(.title3)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(.headline, design: .serif).weight(.semibold))
                            .foregroundColor(.ink)
                        if let subtitle {
                            Text(subtitle).font(.caption).foregroundColor(.soft)
                        }
                    }
                    Spacer()
                    if isReordering {
                        Image(systemName: "line.3.horizontal")
                            .font(.body.weight(.semibold))
                            .foregroundColor(accent)
                            .frame(width: 38, height: 38)
                            .background(RoundedRectangle(cornerRadius: 12).fill(tint))
                    } else {
                        Text("\(doneCount)/\(steps.count)")
                            .font(.caption.weight(.bold)).foregroundColor(accent)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold)).foregroundColor(.faint)
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                }
            }
            .buttonStyle(.plain)

            if open && !isReordering {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.key) { index, step in
                        StepRowView(step: step, num: index + 1, accent: accent, infoProduct: $infoProduct)
                    }
                }
                .padding(.top, 4)
                if steps.isEmpty, let onEdit {
                    Button(action: onEdit) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.dashed")
                            Text("Add your products")
                                .font(.footnote.weight(.semibold))
                            Spacer()
                        }
                        .foregroundColor(.soft)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.faint, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                if let footer {
                    Text(footer)
                        .font(.caption).foregroundColor(.roseDeep)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.roseTint.opacity(0.7)))
                        .padding(.top, 8)
                }
                if let photoArea, isComplete {
                    completionBanner(photoArea: photoArea)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color.white)
            .shadow(color: Color.rose.opacity(0.10), radius: 9, y: 4))
        .onChange(of: store.selectedDate) { _, _ in
            open = true // fresh day, fresh card
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(overlayImage: photoArea.flatMap { area in
                store.previousPhoto(for: area, excluding: store.dateKey(store.selectedDate)).flatMap(store.image(for:))
            }) { image in
                store.savePhoto(image, area: photoArea ?? "routine", date: store.selectedDate)
                withAnimation(.easeInOut(duration: 0.2)) { open = false }
            }
            .ignoresSafeArea()
        }
        .alert("Camera not available", isPresented: $cameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device (or simulator) doesn't have a camera available.")
        }
    }

    private func completionBanner(photoArea: String) -> some View {
        VStack(spacing: 8) {
            Text("✨ You're glowing!")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.roseDeep)
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    cameraUnavailable = true
                }
            } label: {
                Label(hasPhotoToday ? "Retake today's photo" : "Take a photo to add to your journey",
                      systemImage: "camera.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(accent))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint))
        .padding(.top, 8)
    }
}

struct StepRowView: View {
    @EnvironmentObject var store: AppStore
    let step: RStep
    let num: Int
    let accent: Color
    @Binding var infoProduct: Product?

    private var product: Product? { step.productID.flatMap { store.productInfo($0) } }
    private var label: String { step.label ?? product?.name ?? "Step" }
    private var done: Bool { store.isDone(step.key) }
    private var timer: RunningTimer? { store.timers[step.key] }
    private var remaining: Int {
        guard let t = timer else { return 0 }
        return max(0, Int(ceil(t.end.timeIntervalSinceNow)))
    }
    private var frac: Double {
        guard let t = timer, t.total > 0 else { return 0 }
        return 1 - Double(remaining) / t.total
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // whole-row tap target: number + pearl + text
            HStack(alignment: .top, spacing: 12) {
                Text("\(num)")
                    .font(.system(.caption2, design: .serif))
                    .foregroundColor(.faint)
                    .frame(width: 16, alignment: .trailing)
                    .padding(.top, 5)
                PearlView(done: done, accent: accent, frac: timer != nil ? frac : nil)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(done ? .faint : .ink)
                            .strikethrough(done)
                        if let t = timer, !done {
                            Text("⏳ \(remaining / 60):\(String(format: "%02d", remaining % 60))")
                                .font(.system(size: 11, weight: .heavy)).monospacedDigit()
                                .foregroundColor(.white)
                                .padding(.horizontal, 9).padding(.vertical, 2)
                                .background(Capsule().fill(accent))
                                .id(t.end)
                        } else if let wait = step.wait {
                            Text("wait \(wait) min")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(accent)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(accent.opacity(0.12)))
                        }
                        if step.everyOtherDay {
                            Text("every other day")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.pmLav)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Capsule().fill(Color.pmLav.opacity(0.12)))
                        }
                    }
                    if let note = step.note {
                        Text(note).font(.caption).foregroundColor(.soft)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .gesture(
                ExclusiveGesture(TapGesture(count: 2), TapGesture(count: 1))
                    .onEnded { value in
                        switch value {
                        case .first: store.skip(step.key)      // double tap = skip/complete
                        case .second: store.tap(step)          // single tap = start/cancel/undo
                        }
                    }
            )

            if let product {
                Button { infoProduct = product } label: {
                    Text("why ♡")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(accent.opacity(0.12)))
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 10)
        .overlay(Rectangle().fill(Color.lineC).frame(height: 1), alignment: .bottom)
    }
}

struct PearlView: View {
    let done: Bool
    let accent: Color
    let frac: Double?   // nil when idle

    var body: some View {
        ZStack {
            if done {
                Circle().fill(accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
            } else if let frac {
                Circle().stroke(Color.lineC, lineWidth: 4)
                Circle().trim(from: 0, to: frac)
                    .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(Color.white).frame(width: 12, height: 12)
            } else {
                Circle().stroke(Color.faint, lineWidth: 2)
            }
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Product info sheet

struct ProductSheet: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(product.name)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundColor(.ink)
                Text(product.tag.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.rose)
                infoBlock("What it is", product.what)
                infoBlock("Why it helps", product.why)
                infoBlock("Why this order", product.order)
                if let caution = product.caution {
                    Text("⚠︎ \(caution)")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.roseDeep)
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.roseTint))
                }
                Button { dismiss() } label: {
                    Text("Got it ♡")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.rose))
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func infoBlock(_ heading: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundColor(.soft)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.ink)
        }
    }
}

// MARK: - Week plan

struct WeekPlanView: View {
    @EnvironmentObject var store: AppStore
    private let displayDayOrder = [1, 2, 3, 4, 5, 6, 0]

    private var everydayRoutines: [Routine] {
        store.routines.filter { $0.days.count == 7 }
    }

    private func rotatingRoutines(on day: Int) -> [Routine] {
        store.routines.filter { $0.days.count < 7 && $0.days.contains(day) }
    }

    private func dayName(_ day: Int) -> String {
        Calendar.current.weekdaySymbols[day]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    Text("Your week at a glance")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("Everyday routines run daily — day-specific ones rotate below.")
                        .font(.footnote).foregroundColor(.soft)

                    if !everydayRoutines.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("EVERY DAY")
                                .font(.caption2.weight(.heavy)).foregroundColor(.soft)
                            Text(everydayRoutines.map { "\($0.emoji) \($0.title)" }.joined(separator: "  ·  "))
                                .font(.footnote).foregroundColor(.ink)
                                .lineSpacing(4)
                        }
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.75)))
                    }

                    ForEach(displayDayOrder, id: \.self) { day in
                        let rotating = rotatingRoutines(on: day)
                        let isToday = day == (Calendar.current.component(.weekday, from: Date()) - 1)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(rotating.first?.emoji ?? "💗").font(.title3)
                                Text(dayName(day))
                                    .font(.system(.headline, design: .serif).weight(.semibold))
                                    .foregroundColor(.ink)
                                if isToday {
                                    Text("TODAY")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.rose))
                                }
                                Spacer()
                                if let focus = rotating.compactMap(\.focus).first {
                                    Text(focus)
                                        .font(.caption.weight(.heavy)).foregroundColor(.pmLav)
                                }
                            }
                            if rotating.isEmpty {
                                Text("Same as every day 💗").font(.footnote).foregroundColor(.soft)
                            } else {
                                Text(rotating.map(\.title).joined(separator: " + "))
                                    .font(.footnote).foregroundColor(.ink)
                                ForEach(rotating.compactMap(\.planNote), id: \.self) { note in
                                    Text(note).font(.caption).foregroundColor(.soft)
                                }
                            }
                        }
                        .padding(15)
                        .background(RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(color: Color.rose.opacity(0.09), radius: 8, y: 3))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(isToday ? Color.rose : Color.clear, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("GOLDEN RULES")
                            .font(.caption2.weight(.heavy)).foregroundColor(.pmLav)
                        Text("Never skip SPF · Never retinal + acids the same night · Never steam on retinal nights · Completely dry skin always · No glycolic on armpits or chest · Minoxidil is always the last step · Spearmint tea daily 🍵")
                            .font(.footnote).foregroundColor(.ink)
                            .lineSpacing(4)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.pmTint))
                }
                .padding(16)
            }
        }
    }
}


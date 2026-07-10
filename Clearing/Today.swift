//  Today.swift
//  Clearing

import SwiftUI
import Combine
import UIKit
import UniformTypeIdentifiers

// MARK: - Root

struct RootView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
                .tag(0)
            WeekPlanView()
                .tabItem { Label("Week", systemImage: "calendar") }
                .tag(1)
            PhotosView()
                .tabItem { Label("Photos", systemImage: "camera.fill") }
                .tag(2)
            ShopView()
                .tabItem { Label("Shop", systemImage: "bag.fill") }
                .tag(3)
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
                .tag(4)
        }
        .tint(.roseDeep)
        .onReceive(NotificationCenter.default.publisher(for: .openTodayTab)) { _ in
            selectedTab = 0
        }
    }
}

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var infoProduct: Product?
    @State private var isReordering = false
    @State private var draggedKey: String?
    private let heartbeat = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var visibleSectionOrder: [String] {
        store.sectionOrder.filter { $0 != "removal" || store.isWednesday }
    }

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

                        ForEach(visibleSectionOrder, id: \.self) { key in
                            Group {
                                if isReordering {
                                    sectionView(for: key)
                                        .opacity(draggedKey == key ? 0.4 : 1)
                                        .onDrag {
                                            draggedKey = key
                                            return NSItemProvider(object: key as NSString)
                                        }
                                        .onDrop(of: [.text], delegate: SectionDropDelegate(
                                            item: key,
                                            draggedKey: $draggedKey,
                                            reorder: { moveSection($0, over: $1) }))
                                } else {
                                    sectionView(for: key)
                                }
                            }
                            .id(key)
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
    }

    private func sectionIconRow(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleSectionOrder, id: \.self) { key in
                        Button {
                            withAnimation { proxy.scrollTo(key, anchor: .top) }
                        } label: {
                            Text(sectionEmoji(key))
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
        }
        .padding(.top, 4)
    }

    private func moveSection(_ dragged: String, over target: String) {
        var visible = visibleSectionOrder
        guard let fromIdx = visible.firstIndex(of: dragged),
              let toIdx = visible.firstIndex(of: target),
              fromIdx != toIdx else { return }
        visible.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
        withAnimation(.easeInOut(duration: 0.2)) { applyVisibleOrder(visible) }
    }

    private func applyVisibleOrder(_ visible: [String]) {
        if store.isWednesday {
            store.sectionOrder = visible
        } else {
            let removalIndex = store.sectionOrder.firstIndex(of: "removal") ?? 1
            var newOrder = visible
            newOrder.insert("removal", at: min(removalIndex, newOrder.count))
            store.sectionOrder = newOrder
        }
    }

    private func sectionTitle(_ key: String) -> String {
        switch key {
        case "morning": return "Morning ritual"
        case "removal": return "Hair removal"
        case "evening": return "Evening ritual"
        case "bikini": return "Bikini"
        case "armpits": return "Armpits"
        case "chest": return "Chest"
        case "habits": return "Daily glow habits"
        default: return key
        }
    }

    private func sectionEmoji(_ key: String) -> String {
        switch key {
        case "morning": return "☀️"
        case "removal": return "🪞"
        case "evening": return "🌙"
        case "bikini": return "🌸"
        case "armpits": return "🫶"
        case "chest": return "💗"
        case "habits": return "🍵"
        default: return "•"
        }
    }

    @ViewBuilder
    private func sectionView(for key: String) -> some View {
        switch key {
        case "morning":
            SectionCard(title: "Morning ritual", emoji: "☀️", accent: .amGold, tint: .amTint,
                        subtitle: "Same glow, every day",
                        steps: Catalog.amSteps, infoProduct: $infoProduct, photoArea: "face",
                        isReordering: isReordering)
        case "removal":
            if store.isWednesday {
                SectionCard(title: "Hair removal", emoji: "🪞", accent: .rose, tint: .roseTint,
                            subtitle: "Do this first, before the evening routine",
                            steps: Catalog.removalSteps, infoProduct: $infoProduct,
                            footer: "Tonight's mustache rules: no steam, no mask, no azelaic on the mustache area. Hyaluronic Concentrate is the only yes. 💋",
                            photoArea: "removal",
                            isReordering: isReordering)
            }
        case "evening":
            SectionCard(title: "Evening ritual", emoji: "🌙", accent: .pmLav, tint: .pmTint,
                        subtitle: "\(store.plan.emoji) \(store.plan.focus)",
                        steps: store.plan.steps, infoProduct: $infoProduct, photoArea: "face",
                        isReordering: isReordering)
        case "bikini":
            bodyCard(area: "bikini", title: "Bikini", emoji: "🌸")
        case "armpits":
            bodyCard(area: "armpits", title: "Armpits", emoji: "🫶",
                     footer: "Rule: niacinamide, pads + azelaic only. Never glycolic, retinal or salicylic here.")
        case "chest":
            bodyCard(area: "chest", title: "Chest", emoji: "💗",
                     subtitle: "Bumps are the purge — clears weeks 4–6 💪")
        case "habits":
            SectionCard(title: "Daily glow habits", emoji: "🍵", accent: .greenC,
                        tint: Color(hex: 0xEAF3EC), subtitle: nil,
                        steps: Catalog.habits, infoProduct: $infoProduct, photoArea: "habits",
                        isReordering: isReordering)
        default:
            EmptyView()
        }
    }

    private func bodyCard(area: String, title: String, emoji: String,
                          subtitle: String? = "Daily care after shower", footer: String? = nil) -> some View {
        SectionCard(title: title, emoji: emoji, accent: .bodyCoral, tint: .bodyTint,
                    subtitle: subtitle,
                    steps: Catalog.bodySteps(area: area, includeAzelaic: store.azelaicBodyDay),
                    infoProduct: $infoProduct,
                    footer: store.azelaicBodyDay ? footer : (footer ?? "Azelaic acid rests today — it's back tomorrow ✨"),
                    photoArea: area,
                    isReordering: isReordering)
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
                Text("\(dayName), \(dateLine) · \(store.plan.emoji) \(store.plan.focus)")
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

    private var product: Product? { step.productID.flatMap { Catalog.products[$0] } }
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
    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 11) {
                    Text("Your week at a glance")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("Mornings + body care are the same every day — evenings rotate below.")
                        .font(.footnote).foregroundColor(.soft)

                    ForEach(Catalog.weekInfo, id: \.day) { info in
                        let isToday = info.day == (Calendar.current.component(.weekday, from: Date()) - 1)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(info.emoji).font(.title3)
                                Text(info.name)
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
                                Text(info.focus)
                                    .font(.caption.weight(.heavy)).foregroundColor(.pmLav)
                            }
                            Text(info.key).font(.footnote).foregroundColor(.ink)
                            Text(info.note).font(.caption).foregroundColor(.soft)
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


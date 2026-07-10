//  Store.swift
//  Clearing

import SwiftUI
import Combine
import UIKit
import AudioToolbox

// MARK: - Store

final class AppStore: ObservableObject {
    @Published var selectedDate: Date = Date() {
        didSet { timers = [:]; NotificationManager.cancelAllTimerDone(); loadChecks() }
    }
    @Published var checks: [String: Bool] = [:]
    @Published var timers: [String: RunningTimer] = [:]
    @Published var reminders: [Reminder] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(reminders) {
                UserDefaults.standard.set(data, forKey: "reminders")
            }
            NotificationManager.sync(reminders)
        }
    }
    @Published var progressPhotos: [ProgressPhoto] = []
    @Published var wishlist: [WishlistItem] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(wishlist) {
                UserDefaults.standard.set(data, forKey: "wishlist")
            }
        }
    }
    @Published var quizResult: QuizResult? {
        didSet {
            if let result = quizResult, let data = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(data, forKey: "quizResult")
            }
        }
    }
    @Published var routines: [Routine] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(routines) {
                UserDefaults.standard.set(data, forKey: "routines")
            }
        }
    }

    /// Shop catalog cached for cross-catalog product resolution.
    let shopProducts: [ShopProduct] = BundledShopCatalog().allProducts()
    private lazy var shopProductsByID: [String: ShopProduct] =
        Dictionary(uniqueKeysWithValues: shopProducts.map { ($0.id, $0) })

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let photosDirectory: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        loadChecks()
        if let data = UserDefaults.standard.data(forKey: "reminders"),
           let saved = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = saved
        } else {
            reminders = [
                Reminder(label: "☀️ Morning ritual time", hour: 7, minute: 30, days: Set(1...7)),
                Reminder(label: "🌙 Evening ritual time", hour: 21, minute: 30, days: Set(1...7)),
            ]
        }
        if let data = UserDefaults.standard.data(forKey: "progressPhotos"),
           let saved = try? JSONDecoder().decode([ProgressPhoto].self, from: data) {
            progressPhotos = saved
        }
        if let data = UserDefaults.standard.data(forKey: "wishlist"),
           let saved = try? JSONDecoder().decode([WishlistItem].self, from: data) {
            wishlist = saved
        }
        if let data = UserDefaults.standard.data(forKey: "quizResult"),
           let saved = try? JSONDecoder().decode(QuizResult.self, from: data) {
            quizResult = saved
        }
        if let data = UserDefaults.standard.data(forKey: "routines"),
           let saved = try? JSONDecoder().decode([Routine].self, from: data) {
            routines = saved
        } else {
            routines = Self.migratedSeedRoutines()
        }
    }

    /// First-run (or upgrade-from-hardcoded) seed, ordered by any legacy "sectionOrder"
    /// the user had saved, with the old single "evening" slot expanded to the 7 seeds.
    private static func migratedSeedRoutines() -> [Routine] {
        let seeds = Catalog.seedRoutines()
        guard let data = UserDefaults.standard.data(forKey: "sectionOrder"),
              let legacy = try? JSONDecoder().decode([String].self, from: data) else { return seeds }
        let orderedIDs = legacy.flatMap(Catalog.routineIDs(forLegacySection:))
        var remaining = seeds
        var ordered: [Routine] = []
        for id in orderedIDs {
            if let idx = remaining.firstIndex(where: { $0.id == id }) {
                ordered.append(remaining.remove(at: idx))
            }
        }
        return ordered + remaining
    }

    func isWishlisted(_ productID: String) -> Bool {
        wishlist.contains { $0.productID == productID }
    }

    func toggleWishlist(_ productID: String) {
        if isWishlisted(productID) {
            wishlist.removeAll { $0.productID == productID }
        } else {
            wishlist.append(WishlistItem(productID: productID))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func togglePurchased(_ productID: String) {
        guard let idx = wishlist.firstIndex(where: { $0.productID == productID }) else { return }
        wishlist[idx].purchased.toggle()
    }

    /// Resolved product IDs for a kit, honoring sensitive-skin swaps.
    func resolvedProductIDs(for kit: RoutineKit) -> [String] {
        let sensitive = quizResult?.skinType == .sensitive
        return kit.items.map { item in
            sensitive ? (item.sensitiveAlt ?? item.productID) : item.productID
        }
    }

    /// Adds every kit product not already on the wishlist; returns how many were added.
    @discardableResult
    func addKit(_ kit: RoutineKit) -> Int {
        let newIDs = resolvedProductIDs(for: kit).filter { !isWishlisted($0) }
        for id in newIDs { wishlist.append(WishlistItem(productID: id)) }
        if !newIDs.isEmpty { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        return newIDs.count
    }

    var dateKey: String { Self.keyFormatter.string(from: selectedDate) }
    var jsWeekday: Int { Calendar.current.component(.weekday, from: selectedDate) - 1 } // 0=Sun
    var azelaicBodyDay: Bool {
        (Calendar.current.ordinality(of: .day, in: .year, for: selectedDate) ?? 0) % 2 == 0
    }

    // MARK: Routines

    /// Routines active on the selected date's weekday, in user order.
    var visibleRoutines: [Routine] {
        routines.filter { $0.days.contains(jsWeekday) }
    }

    /// A routine's steps as shown/counted today (every-other-day steps rest off-days).
    func visibleSteps(for routine: Routine) -> [RStep] {
        routine.steps.filter { !$0.everyOtherDay || azelaicBodyDay }
    }

    /// Header line focus, e.g. "✨ Glycolic Glow" — first focus among today's routines.
    var todayFocus: String? {
        visibleRoutines.compactMap(\.focus).first
    }

    /// Unified product lookup across the built-in catalog and the shop catalog.
    func productInfo(_ id: String) -> Product? {
        if let builtIn = Catalog.products[id] { return builtIn }
        guard let shop = shopProductsByID[id] else { return nil }
        return Product(name: shop.name, tag: "\(shop.brand) · \(shop.tag)",
                       what: shop.what, why: shop.why, order: shop.order,
                       caution: shop.caution)
    }

    // MARK: Routine editing

    func addRoutine(_ routine: Routine) {
        routines.append(routine)
    }

    func deleteRoutine(id: String) {
        routines.removeAll { $0.id == id }
    }

    func updateRoutine(_ routine: Routine) {
        guard let idx = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[idx] = rekeyingCollisions(routine)
    }

    /// Reorders today's visible routines, preserving the positions of hidden ones.
    func moveVisibleRoutine(_ draggedID: String, over targetID: String) {
        var visibleIDs = visibleRoutines.map(\.id)
        guard let from = visibleIDs.firstIndex(of: draggedID),
              let to = visibleIDs.firstIndex(of: targetID), from != to else { return }
        visibleIDs.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        let byID = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        var sequence = visibleIDs.makeIterator()
        routines = routines.map { r in
            r.days.contains(jsWeekday) ? byID[sequence.next()!]! : r
        }
    }

    /// Adds a product as a new step, auto-placed by its category in canonical
    /// layering order (cleanser → exfoliant → treatment → moisturizer → SPF → extras).
    func addProduct(_ productID: String, to routineID: String) {
        guard let idx = routines.firstIndex(where: { $0.id == routineID }) else { return }
        let category = Catalog.products[productID]?.category // shop catalog categories arrive with the Shop hookup
        let step = RStep(key: "st-" + UUID().uuidString.prefix(8).lowercased(),
                         productID: productID, category: category)
        var steps = routines[idx].steps
        steps.insert(step, at: insertionIndex(for: category, in: steps))
        routines[idx].steps = steps
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func removeStep(key: String, from routineID: String) {
        guard let idx = routines.firstIndex(where: { $0.id == routineID }) else { return }
        routines[idx].steps.removeAll { $0.key == key }
    }

    func moveStep(in routineID: String, from source: IndexSet, to destination: Int) {
        guard let idx = routines.firstIndex(where: { $0.id == routineID }) else { return }
        routines[idx].steps.move(fromOffsets: source, toOffset: destination)
    }

    /// Insert after the last step whose category rank ≤ the new one; steps without
    /// a category stay anchored where the user put them.
    private func insertionIndex(for category: StepCategory?, in steps: [RStep]) -> Int {
        guard let rank = category?.sortRank else { return steps.count }
        var index: Int? = nil
        for (i, existing) in steps.enumerated() {
            if let existingRank = existing.category?.sortRank, existingRank <= rank {
                index = i + 1
            }
        }
        if let index { return index }
        // No earlier-or-equal anchor: go before the categorized steps if any exist, else append.
        return steps.contains { $0.category != nil } ? 0 : steps.count
    }

    /// If an edit makes two same-day routines share a step key, re-key the edited one's clashes.
    private func rekeyingCollisions(_ routine: Routine) -> Routine {
        let otherKeys: Set<String> = Set(routines
            .filter { $0.id != routine.id && !$0.days.isDisjoint(with: routine.days) }
            .flatMap { $0.steps.map(\.key) })
        guard routine.steps.contains(where: { otherKeys.contains($0.key) }) else { return routine }
        var fixed = routine
        fixed.steps = fixed.steps.map { step in
            guard otherKeys.contains(step.key) else { return step }
            var s = step
            s.key = "st-" + UUID().uuidString.prefix(8).lowercased()
            return s
        }
        return fixed
    }

    func loadChecks() {
        if let data = UserDefaults.standard.data(forKey: "checks-\(dateKey)"),
           let saved = try? JSONDecoder().decode([String: Bool].self, from: data) {
            checks = saved
        } else {
            checks = [:]
        }
    }

    private func saveChecks() {
        if let data = try? JSONEncoder().encode(checks) {
            UserDefaults.standard.set(data, forKey: "checks-\(dateKey)")
        }
    }

    func isDone(_ key: String) -> Bool { checks[key] ?? false }

    func setCheck(_ key: String, _ value: Bool) {
        checks[key] = value
        saveChecks()
    }

    /// Single tap: undo if done; cancel if timing; start timer if step has a wait; else complete.
    func tap(_ step: RStep) {
        let key = step.key
        if isDone(key) { timers.removeValue(forKey: key); setCheck(key, false); return }
        if timers[key] != nil {
            timers.removeValue(forKey: key)
            NotificationManager.cancelTimerDone(key: key)
            return
        }
        if let wait = step.wait, wait > 0 {
            let name = step.label ?? step.productID.flatMap { productInfo($0)?.name } ?? "Step"
            let end = Date().addingTimeInterval(TimeInterval(wait * 60))
            timers[key] = RunningTimer(end: end, total: TimeInterval(wait * 60), label: name)
            NotificationManager.scheduleTimerDone(key: key, label: name, end: end)
        } else {
            setCheck(key, true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// Double tap: skip any timer and complete immediately.
    func skip(_ key: String) {
        if timers.removeValue(forKey: key) != nil {
            NotificationManager.cancelTimerDone(key: key)
        }
        if !isDone(key) {
            setCheck(key, true)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    /// Called on a heartbeat; completes any expired timers.
    func tick() {
        let now = Date()
        for (key, t) in timers where now >= t.end {
            timers.removeValue(forKey: key)
            setCheck(key, true)
            // Expired just now, with the app in use: chime here and the pending
            // notification is suppressed. Expired while backgrounded: the local
            // notification already alerted, so complete quietly.
            if now.timeIntervalSince(t.end) < 1.5 {
                AudioServicesPlaySystemSound(1007) // gentle tri-tone chime
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        if !timers.isEmpty {
            objectWillChange.send() // refresh countdown labels
        }
    }

    // Progress across everything shown today
    var allKeys: [String] {
        visibleRoutines.flatMap { visibleSteps(for: $0).map(\.key) }
    }
    var doneCount: Int { allKeys.filter { isDone($0) }.count }
    var progress: Double { allKeys.isEmpty ? 0 : Double(doneCount) / Double(allKeys.count) }

    // MARK: Progress photos

    func photos(for area: String) -> [ProgressPhoto] {
        progressPhotos.filter { $0.area == area }.sorted { $0.dateKey > $1.dateKey }
    }

    /// Most recent existing shot for the area, ignoring the day about to be captured — used as an angle-matching overlay.
    func previousPhoto(for area: String, excluding dateKey: String) -> ProgressPhoto? {
        photos(for: area).first { $0.dateKey != dateKey }
    }

    func dateKey(_ date: Date) -> String { Self.keyFormatter.string(from: date) }

    /// One photo per area per day — retaking today's shot replaces the old one.
    func savePhoto(_ image: UIImage, area: String, date: Date = Date()) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let key = dateKey(date)
        if let existing = progressPhotos.first(where: { $0.area == area && $0.dateKey == key }) {
            deletePhoto(existing)
        }
        let filename = "\(area)-\(key)-\(UUID().uuidString).jpg"
        let url = Self.photosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
        } catch {
            return
        }
        progressPhotos.append(ProgressPhoto(area: area, dateKey: key, filename: filename))
        savePhotosIndex()
    }

    func deletePhoto(_ photo: ProgressPhoto) {
        try? FileManager.default.removeItem(at: Self.photosDirectory.appendingPathComponent(photo.filename))
        progressPhotos.removeAll { $0.id == photo.id }
        savePhotosIndex()
    }

    func image(for photo: ProgressPhoto) -> UIImage? {
        UIImage(contentsOfFile: Self.photosDirectory.appendingPathComponent(photo.filename).path)
    }

    private func savePhotosIndex() {
        if let data = try? JSONEncoder().encode(progressPhotos) {
            UserDefaults.standard.set(data, forKey: "progressPhotos")
        }
    }
}


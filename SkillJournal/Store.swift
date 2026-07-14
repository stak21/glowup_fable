//  Store.swift
//  Skill Journal
//
//  The routine engine, carried over from GlowUp: date-keyed check-offs,
//  running timers, reminders, progress photos, drag reorder, wishlist.
//  Domain knowledge (categories, wait/cadence defaults, templates) comes
//  from the owned PackStore instead of compiled tables.

import SwiftUI
import Combine
import UIKit
import AudioToolbox
import Photos

// MARK: - Store

final class AppStore: ObservableObject {
    /// Domain packs — owned here so engine methods can resolve categories,
    /// defaults and products; also injected into the environment directly.
    let packs = PackStore()

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
    @Published var routines: [Routine] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(routines) {
                UserDefaults.standard.set(data, forKey: "routines")
            }
        }
    }

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
        }
        if let data = UserDefaults.standard.data(forKey: "progressPhotos"),
           let saved = try? JSONDecoder().decode([ProgressPhoto].self, from: data) {
            progressPhotos = saved
        }
        if let data = UserDefaults.standard.data(forKey: "wishlist"),
           let saved = try? JSONDecoder().decode([WishlistItem].self, from: data) {
            wishlist = saved
        }
        if let data = UserDefaults.standard.data(forKey: "routines"),
           let saved = try? JSONDecoder().decode([Routine].self, from: data) {
            routines = saved
        }

        // Ensure photo files use full lock-state encryption even if written
        // by an earlier build with a weaker default.
        DispatchQueue.global(qos: .utility).async {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: Self.photosDirectory, includingPropertiesForKeys: nil)) ?? []
            for url in files {
                try? FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            }
        }
    }

    private var checksKey: String { "checks-\(dateKey)" }

    // MARK: Wishlist

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

    // MARK: Templates → routines

    /// Builds Routine drafts from a pack template — pure data assembly; the
    /// template's authored order, waits and cadences are taken as-is. Nothing
    /// is saved until createRoutines. A routine omits the "add a ___" nudge
    /// for core categories a sibling routine in the same template covers.
    func draftRoutines(from template: RoutineTemplate, pack: DomainPack) -> [Routine] {
        let covered: [Set<String>] = template.routines.map { Set($0.steps.compactMap(\.categoryID)) }
        let core = Set(pack.coreCategoryIDs)
        return template.routines.enumerated().map { index, tr in
            let steps = tr.steps.map { ts in
                RStep(key: "st-" + UUID().uuidString.prefix(8).lowercased(),
                      productID: ts.productID,
                      label: ts.label,
                      wait: ts.waitMinutes,
                      note: ts.note,
                      cadence: ts.cadence,
                      categoryID: ts.categoryID)
            }
            var omit = Set<String>()
            for (j, siblingCovered) in covered.enumerated() where j != index {
                omit.formUnion(siblingCovered)
            }
            omit.subtract(covered[index])
            omit.formIntersection(core)
            return Routine(id: "rt-" + UUID().uuidString.prefix(8).lowercased(),
                           title: tr.title,
                           emoji: tr.emoji,
                           subtitle: template.title,
                           footer: tr.footer,
                           days: Set(tr.days),
                           photoArea: tr.photoAreaID,
                           theme: RoutineTheme(rawValue: tr.theme) ?? pack.theme,
                           steps: steps,
                           packID: pack.id,
                           sourceTemplateID: template.id,
                           omitCoreCategories: omit)
        }
    }

    /// Appends reviewed routines, skipping any whose ID already exists — a
    /// double-fired create is a no-op instead of a duplicate set.
    func createRoutines(_ new: [Routine]) {
        let fresh = new.filter { candidate in !routines.contains { $0.id == candidate.id } }
        guard !fresh.isEmpty else { return }
        routines.append(contentsOf: fresh)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// True once routines built from this template exist — its sheet shows
    /// "created" instead of offering to build again.
    func hasTemplateRoutines(_ templateID: String) -> Bool {
        routines.contains { $0.sourceTemplateID == templateID }
    }

    // MARK: Dates

    var dateKey: String { Self.keyFormatter.string(from: selectedDate) }
    var jsWeekday: Int { Calendar.current.component(.weekday, from: selectedDate) - 1 } // 0=Sun

    // MARK: Routines

    /// Routines active on the selected date's weekday, in user order.
    var visibleRoutines: [Routine] {
        routines.filter { $0.days.contains(jsWeekday) }
    }

    /// A routine's steps as shown/counted today (non-daily cadences rest off-days).
    func visibleSteps(for routine: Routine) -> [RStep] {
        routine.steps.filter { ($0.cadence ?? .daily).isActive(on: selectedDate) }
    }

    /// Header line focus — first focus among today's routines.
    var todayFocus: String? {
        visibleRoutines.compactMap(\.focus).first
    }

    /// Info for a step's "why" sheet, from the active packs' products.
    func productInfo(_ id: String) -> ProductInfo? {
        guard let p = packs.product(id) else { return nil }
        return ProductInfo(name: p.name, tag: p.tag, what: p.what, why: p.why,
                           order: p.order, caution: p.caution)
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

    /// Adds a pack product as a new step, auto-placed by its category's rank
    /// with the pack's default wait and cadence for its type.
    func addProduct(_ productID: String, to routineID: String) {
        guard let idx = routines.firstIndex(where: { $0.id == routineID }) else { return }
        let pack = packs.pack(for: routines[idx])
        let product = packs.product(productID)
        let categoryID = product?.categoryID
        let text = "\(product?.name ?? "") \(product?.tag ?? "")"
        let step = RStep(key: "st-" + UUID().uuidString.prefix(8).lowercased(),
                         productID: productID,
                         wait: pack?.defaultWaitMinutes(stepText: text, categoryID: categoryID),
                         cadence: pack?.defaultCadence(stepText: text, categoryID: categoryID),
                         categoryID: categoryID)
        var steps = routines[idx].steps
        steps.insert(step, at: RoutinePlacement.insertionIndex(for: categoryID, in: steps, pack: pack))
        routines[idx].steps = steps
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Reorders the full routine list (manager sheet — includes off-day routines).
    func moveRoutine(_ draggedID: String, over targetID: String) {
        guard let from = routines.firstIndex(where: { $0.id == draggedID }),
              let to = routines.firstIndex(where: { $0.id == targetID }), from != to else { return }
        routines.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func removeStep(key: String, from routineID: String) {
        guard let idx = routines.firstIndex(where: { $0.id == routineID }) else { return }
        routines[idx].steps.removeAll { $0.key == key }
    }

    func moveStep(in routineID: String, from source: IndexSet, to destination: Int) {
        guard let idx = routines.firstIndex(where: { $0.id == routineID }) else { return }
        routines[idx].steps.move(fromOffsets: source, toOffset: destination)
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

    // MARK: Checks

    func loadChecks() {
        if let data = UserDefaults.standard.data(forKey: checksKey),
           let saved = try? JSONDecoder().decode([String: Bool].self, from: data) {
            checks = saved
        } else {
            checks = [:]
        }
    }

    private func saveChecks() {
        if let data = try? JSONEncoder().encode(checks) {
            UserDefaults.standard.set(data, forKey: checksKey)
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
    /// Returns false if the photo could not be written, so callers can tell the user.
    @discardableResult
    func savePhoto(_ image: UIImage, area: String, date: Date = Date()) -> Bool {
        let prepared = Self.downscaled(image, maxDimension: 2048)
        guard let data = prepared.jpegData(compressionQuality: 0.85) else { return false }
        let key = dateKey(date)
        if let existing = progressPhotos.first(where: { $0.area == area && $0.dateKey == key }) {
            deletePhoto(existing)
        }
        let filename = "\(area)-\(key)-\(UUID().uuidString).jpg"
        let url = Self.photosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            return false
        }
        progressPhotos.append(ProgressPhoto(area: area, dateKey: key, filename: filename))
        savePhotosIndex()
        return true
    }

    /// Camera output is 12MP+ (~3 MB each); 2048px is plenty for grids and timelapses
    /// and keeps months of dailies from eating gigabytes.
    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let largest = max(pixelWidth, pixelHeight)
        guard largest > maxDimension else { return image }
        let factor = maxDimension / largest
        let newSize = CGSize(width: (pixelWidth * factor).rounded(), height: (pixelHeight * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
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

    // MARK: Photo backup (opt-in copy to the user's Photos library)

    var photosPendingBackup: Int {
        progressPhotos.filter { $0.assetID == nil }.count
    }

    enum PhotoBackupError: LocalizedError {
        case noAccess
        var errorDescription: String? {
            "Photos access is needed to back up. Allow it in Settings → Privacy → Photos → Skill Journal."
        }
    }

    /// Copies every not-yet-backed-up photo into the Photos library, preserving each
    /// shot's original date. User-initiated only — the app never uploads anything itself.
    func backUpPhotosToLibrary(completion: @escaping (Result<Int, Error>) -> Void) {
        let pending = progressPhotos.filter { $0.assetID == nil }
        guard !pending.isEmpty else { completion(.success(0)); return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(.failure(PhotoBackupError.noAccess)) }
                return
            }
            var created: [(photoID: UUID, assetID: String)] = []
            PHPhotoLibrary.shared().performChanges({
                for photo in pending {
                    let url = Self.photosDirectory.appendingPathComponent(photo.filename)
                    guard let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                    else { continue }
                    request.creationDate = Self.keyFormatter.date(from: photo.dateKey)
                    if let assetID = request.placeholderForCreatedAsset?.localIdentifier {
                        created.append((photo.id, assetID))
                    }
                }
            }) { success, error in
                DispatchQueue.main.async {
                    guard success else {
                        completion(.failure(error ?? PhotoBackupError.noAccess))
                        return
                    }
                    for (photoID, assetID) in created {
                        if let idx = self.progressPhotos.firstIndex(where: { $0.id == photoID }) {
                            self.progressPhotos[idx].assetID = assetID
                        }
                    }
                    self.savePhotosIndex()
                    completion(.success(created.count))
                }
            }
        }
    }
}

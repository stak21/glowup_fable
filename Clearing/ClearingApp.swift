//  ClearingApp.swift
//  Skincare Ritual — native iOS port of the web tracker
//
//  Setup: create a new Xcode project (iOS App, SwiftUI, name: Clearing),
//  replace the contents of ClearingApp.swift with this ENTIRE file,
//  and delete ContentView.swift. Build & run. That's it — one file.
//
//  iOS 16+. Local notifications work with a FREE Apple ID (no paid account).
//

import SwiftUI
import Combine
import UserNotifications
import UIKit
import AVFoundation
import CoreVideo
import Photos

// MARK: - App entry

@main
struct ClearingApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = NotifDelegate.shared
                    NotificationManager.requestPermission()
                }
        }
    }
}

final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotifDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound]) // show banners even while app is open
    }
}

// MARK: - Palette

extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
    static let ink = Color(hex: 0x53333F)
    static let soft = Color(hex: 0xA17E8B)
    static let faint = Color(hex: 0xC9AEB8)
    static let rose = Color(hex: 0xD46A8C)
    static let roseDeep = Color(hex: 0xB84A6F)
    static let roseTint = Color(hex: 0xFBE3EA)
    static let amGold = Color(hex: 0xDE9A52)
    static let amTint = Color(hex: 0xFFF3E2)
    static let pmLav = Color(hex: 0x8E7BB8)
    static let pmTint = Color(hex: 0xF1EDFA)
    static let bodyCoral = Color(hex: 0xD9806E)
    static let bodyTint = Color(hex: 0xFDEAE4)
    static let lineC = Color(hex: 0xF4DDE4)
    static let greenC = Color(hex: 0x7FAE8B)
    static let bgTop = Color(hex: 0xFFF9F7)
    static let bgBottom = Color(hex: 0xFAECF0)
}

// MARK: - Models

struct Product: Identifiable {
    var id: String { name }
    let name: String
    let tag: String
    let what: String
    let why: String
    let order: String
    var caution: String? = nil
}

struct RStep: Identifiable {
    let key: String                 // unique check id, e.g. "am0"
    var productID: String? = nil    // key into Catalog.products
    var label: String? = nil        // custom label (removal steps)
    var wait: Int? = nil            // minutes to count down
    var note: String? = nil
    var everyOtherDay = false
    var id: String { key }
}

struct DayPlan {
    let focus: String
    let emoji: String
    let steps: [RStep]
}

struct Reminder: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String
    var hour: Int
    var minute: Int
    var days: Set<Int>              // Calendar weekdays 1=Sun ... 7=Sat
}

struct RunningTimer {
    let end: Date
    let total: TimeInterval
    let label: String
}

struct ProgressPhoto: Identifiable, Codable, Equatable {
    var id = UUID()
    let area: String        // "face" | "chest" | "armpits" | "bikini"
    let dateKey: String     // yyyy-MM-dd
    let filename: String    // file on disk in the ProgressPhotos folder
}

enum DateKeyFormat {
    static let key: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    static func displayString(from dateKey: String) -> String {
        guard let d = key.date(from: dateKey) else { return dateKey }
        return display.string(from: d)
    }
}

// MARK: - Catalog (products + full Week 3 schedule from the PDF)

enum Catalog {

    static let products: [String: Product] = [
        "cleanse": Product(name: "Cleanse", tag: "Fresh start",
            what: "A gentle cleanser to remove buildup, SPF, sweat and pollution.",
            why: "Actives only work on clean skin — cleansing first lets everything after it absorb properly.",
            order: "Always step one. Every serum and acid needs clean, completely dry skin."),
        "glowpads": Product(name: "Glow Up Pads", tag: "Sugar Baby · kojic + citric acid",
            what: "Pre-soaked pads with kojic and citric acid — a gentle AHA brightening swipe.",
            why: "Fades dark spots with light daily exfoliation. Gentle enough for face, bikini, armpits and chest.",
            order: "Right after cleansing — the thinnest, most watery step goes first so richer serums can layer over it."),
        "flavoc": Product(name: "Flavo-C Ultraglican", tag: "ISDIN · vitamin C",
            what: "A vitamin C antioxidant ampoule.",
            why: "Brightens, boosts collagen, firms, and adds UV defense that makes SPF work harder.",
            order: "First serum after pads — thin, water-light, and antioxidants perform best applied early."),
        "melaclear": Product(name: "Melaclear", tag: "ISDIN · tranexamic acid",
            what: "A tranexamic acid serum targeting pigmentation.",
            why: "Fades hyperpigmentation and stubborn dark spots — teams up with the vitamin C before it.",
            order: "After vitamin C, following the thin-to-thick serum rule."),
        "niacinamide": Product(name: "TJ Niacinamide + HA", tag: "Niacinamide + hyaluronic acid",
            what: "A niacinamide and hyaluronic acid serum.",
            why: "Minimises pores, controls oil, calms redness, hydrates. Daily hero for bikini, armpits and chest too.",
            order: "Last serum — thickest and most hydrating, it seals the brightening serums underneath."),
        "hyaleyes": Product(name: "Hyaluronic Eyes", tag: "ISDIN · eye contour",
            what: "A hydrating eye treatment. Pat gently with your ring finger.",
            why: "Hydrates the delicate eye area and reduces puffiness.",
            order: "Always AFTER all serums and actives, BEFORE moisturiser — the eye area gets its own layer here."),
        "spf": Product(name: "SPF", tag: "Every single morning",
            what: "Broad-spectrum sunscreen. Reapply every 2 hours outdoors.",
            why: "Your routine is full of actives that make skin sun-sensitive — SPF protects every result you're building.",
            order: "Final AM step, always. Sunscreen must sit on top of everything to form its protective film.",
            caution: "Never skip. Skipping SPF undoes the work of every other product."),
        "glycolic": Product(name: "Glycolic Acid", tag: "The Ordinary · AHA · face only",
            what: "A glycolic acid exfoliating toner, applied with a cotton pad.",
            why: "Smooths texture, brightens, fades dark spots, supports collagen.",
            order: "Straight after cleansing on glycolic nights — acids need direct skin contact. Wait the full 10 minutes.",
            caution: "FACE ONLY — never on armpits or chest. Avoid the eye area."),
        "azelaic": Product(name: "Azelaic Acid", tag: "The Ordinary",
            what: "An azelaic acid suspension.",
            why: "Fades dark spots, calms redness, fights acne. Safe on face, bikini, armpits and chest (alternate days on body).",
            order: "In the actives block, after any AHA and before hydration."),
        "salicylic": Product(name: "Salicylic Renewal", tag: "ISDIN · BHA · face only",
            what: "A salicylic acid treatment — twice weekly at week 3.",
            why: "Oil-soluble, so it unclogs pores from inside and fights acne, including the chest purge.",
            order: "The strongest step of the night goes last among actives, right before soothing hydration.",
            caution: "Wed + Sat only. Skip if skin feels sensitive. Face only — avoid mustache area on Wednesdays."),
        "retinal": Product(name: "Retinal Intense", tag: "ISDIN · face only",
            what: "A retinaldehyde treatment — a step stronger than retinol.",
            why: "Gold standard for anti-wrinkle, cell renewal and collagen. Softens elevens over time.",
            order: "After the niacinamide buffer, on completely dry skin, applied sparingly.",
            caution: "Tue + Fri only. Never with acids. Never steam on retinal nights. If irritated: Hyaluronic Concentrate only."),
        "hyalconc": Product(name: "Hyaluronic Concentrate", tag: "ISDIN · overnight hydration",
            what: "A deep hydration concentrate.",
            why: "Seals in moisture overnight and soothes after actives — your skin's recovery blanket.",
            order: "Final face step every evening — moisturiser locks everything underneath in place."),
        "niabuffer": Product(name: "Niacinamide (buffer)", tag: "Retinal nights only",
            what: "A niacinamide layer applied before retinal.",
            why: "A cushion that significantly reduces retinal irritation without weakening results.",
            order: "Immediately before Retinal Intense — it only works underneath."),
        "mask": Product(name: "Tata Harper Radiance Mask", tag: "Lactic acid + kaolin · 20 min",
            what: "A resurfacing clay mask — thick layer, massage until white, 20 min, rinse warm.",
            why: "Lactic acid gently exfoliates while kaolin deep-cleans pores opened by steam.",
            order: "Right after steaming while pores are open. Wednesdays: skip the mustache area."),
        "steam": Product(name: "Facial Steam", tag: "5 min · 20–30 cm away",
            what: "Warm steam on clean skin.",
            why: "Opens pores so the mask and actives after it work deeper.",
            order: "ALWAYS after cleansing, never on dirty skin. Never on retinal nights.",
            caution: "Wednesdays: shield the mustache area with a cool damp cloth after Nair."),
        "scrub": Product(name: "TJ Microdermabrasion Scrub", tag: "Pre-removal · body only",
            what: "A physical exfoliating scrub.",
            why: "Clears dead skin before hair removal so ingrowns can't form.",
            order: "Before Nair, in the warm shower."),
        "nair": Product(name: "Nair", tag: "Wednesday · right formula per area",
            what: "Depilatory cream — sensitive formula for armpits, bikini formula for bikini, FACIAL formula only for mustache.",
            why: "Far less trauma than shaving. Watch timing per packaging.",
            order: "After warm shower + scrub. Then cool rinse, pat dry, soothe with niacinamide.",
            caution: "NEVER body Nair on the face."),
        "minoxidil": Product(name: "Minoxidil", tag: "Scalp only · leave on",
            what: "A scalp treatment that stimulates hair follicles.",
            why: "Supports hair growth over 3–6 months of nightly use.",
            order: "The absolute last step of the night. Dry scalp, leave on, no rinse."),
        "dryskin": Product(name: "Clean, dry skin", tag: "After shower",
            what: "Pat completely dry before applying anything.",
            why: "Products absorb better and irritate less on fully dry skin.",
            order: "The foundation of every body-care step."),
        "tea": Product(name: "Spearmint tea", tag: "Minimum once daily · non-negotiable",
            what: "One cup — 85–90°C, steeped 5–7 min covered.",
            why: "Clinically shown to reduce androgens, which drive hormonal chin AND chest acne.",
            order: "Anytime today — pairing it with breakfast makes it automatic."),
        "water": Product(name: "Water 2.5–3 L", tag: "All day",
            what: "Your daily hydration minimum.",
            why: "Non-negotiable for skin repair, de-puffing, and making every serum's hydration count.",
            order: "Sip throughout the day."),
    ]

    static let amSteps: [RStep] = [
        RStep(key: "am0", productID: "cleanse", wait: 2),
        RStep(key: "am1", productID: "glowpads", wait: 2),
        RStep(key: "am2", productID: "flavoc", wait: 3),
        RStep(key: "am3", productID: "melaclear", wait: 3),
        RStep(key: "am4", productID: "niacinamide", wait: 2),
        RStep(key: "am5", productID: "hyaleyes", wait: 1),
        RStep(key: "am6", productID: "spf"),
    ]

    // JS-style weekday: 0=Sun ... 6=Sat
    static let pmByDay: [Int: DayPlan] = [
        1: DayPlan(focus: "Glycolic Glow", emoji: "✨", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2),
            RStep(key: "pm1", productID: "glycolic", wait: 10),
            RStep(key: "pm2", productID: "hyaleyes", wait: 1),
            RStep(key: "pm3", productID: "hyalconc"),
            RStep(key: "pm4", productID: "minoxidil"),
        ]),
        2: DayPlan(focus: "Retinal Renewal", emoji: "🌙", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2, note: "Skin must be FULLY dry before retinal"),
            RStep(key: "pm1", productID: "glowpads", wait: 2),
            RStep(key: "pm2", productID: "niabuffer", wait: 3),
            RStep(key: "pm3", productID: "retinal", wait: 5),
            RStep(key: "pm4", productID: "hyaleyes", wait: 1),
            RStep(key: "pm5", productID: "hyalconc"),
            RStep(key: "pm6", productID: "minoxidil"),
        ]),
        3: DayPlan(focus: "Removal · Steam · Mask", emoji: "🧖‍♀️", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2, note: "Always cleanse before steaming"),
            RStep(key: "pm1", productID: "steam", wait: 5, note: "Shield mustache area"),
            RStep(key: "pm2", productID: "mask", wait: 20, note: "Avoid mustache area"),
            RStep(key: "pm3", productID: "azelaic", wait: 5, note: "Avoid mustache area"),
            RStep(key: "pm4", productID: "salicylic", wait: 3, note: "Skip if skin feels sensitive"),
            RStep(key: "pm5", productID: "hyaleyes", wait: 1),
            RStep(key: "pm6", productID: "hyalconc", note: "Yes on mustache — soothing"),
            RStep(key: "pm7", productID: "minoxidil"),
        ]),
        4: DayPlan(focus: "Glycolic + Azelaic", emoji: "💫", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2),
            RStep(key: "pm1", productID: "glowpads", wait: 2, note: "Skip if sensitive — both are AHAs"),
            RStep(key: "pm2", productID: "glycolic", wait: 10),
            RStep(key: "pm3", productID: "azelaic", wait: 5),
            RStep(key: "pm4", productID: "hyaleyes", wait: 1),
            RStep(key: "pm5", productID: "hyalconc"),
            RStep(key: "pm6", productID: "minoxidil"),
        ]),
        5: DayPlan(focus: "Retinal Renewal", emoji: "🌙", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2, note: "Skin must be FULLY dry before retinal"),
            RStep(key: "pm1", productID: "glowpads", wait: 2),
            RStep(key: "pm2", productID: "niabuffer", wait: 3),
            RStep(key: "pm3", productID: "retinal", wait: 5),
            RStep(key: "pm4", productID: "hyaleyes", wait: 1),
            RStep(key: "pm5", productID: "hyalconc"),
            RStep(key: "pm6", productID: "minoxidil"),
        ]),
        6: DayPlan(focus: "Azelaic + Salicylic", emoji: "🫧", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2),
            RStep(key: "pm1", productID: "azelaic", wait: 5),
            RStep(key: "pm2", productID: "salicylic", wait: 3, note: "If reactive, azelaic only tonight"),
            RStep(key: "pm3", productID: "hyaleyes", wait: 1),
            RStep(key: "pm4", productID: "hyalconc"),
            RStep(key: "pm5", productID: "minoxidil"),
        ]),
        0: DayPlan(focus: "Steam · Mask · Rest", emoji: "🛁", steps: [
            RStep(key: "pm0", productID: "cleanse", wait: 2, note: "Always cleanse before steaming"),
            RStep(key: "pm1", productID: "steam", wait: 5, note: "Weekly deep reset — 5–8 min"),
            RStep(key: "pm2", productID: "mask", wait: 20),
            RStep(key: "pm3", productID: "glowpads", wait: 2),
            RStep(key: "pm4", productID: "hyaleyes", wait: 1),
            RStep(key: "pm5", productID: "hyalconc", note: "Rest night — no strong acids after mask"),
            RStep(key: "pm6", productID: "minoxidil"),
        ]),
    ]

    static let removalSteps: [RStep] = [
        RStep(key: "rem1", label: "Warm shower", note: "Softens hair follicles"),
        RStep(key: "rem2", productID: "scrub", label: "Scrub armpits · 30 sec"),
        RStep(key: "rem3", productID: "scrub", label: "Scrub bikini · 60 sec"),
        RStep(key: "rem4", productID: "nair", label: "Nair armpits", note: "Sensitive formula"),
        RStep(key: "rem5", productID: "nair", label: "Nair bikini", note: "Bikini formula"),
        RStep(key: "rem6", productID: "nair", label: "Nair mustache", note: "FACIAL formula only"),
        RStep(key: "rem7", label: "Cool rinse + pat dry", note: "Never rub"),
        RStep(key: "rem8", productID: "niacinamide", label: "Niacinamide to soothe"),
    ]

    static func bodySteps(area: String, includeAzelaic: Bool) -> [RStep] {
        var steps = [
            RStep(key: "\(area)-dry", productID: "dryskin"),
            RStep(key: "\(area)-nia", productID: "niacinamide"),
            RStep(key: "\(area)-pads", productID: "glowpads"),
        ]
        if includeAzelaic {
            steps.append(RStep(key: "\(area)-aze", productID: "azelaic", everyOtherDay: true))
        }
        return steps
    }

    static let habits: [RStep] = [
        RStep(key: "hb-tea", productID: "tea"),
        RStep(key: "hb-water", productID: "water"),
    ]

    static let weekInfo: [(day: Int, name: String, emoji: String, focus: String, key: String, note: String)] = [
        (1, "Monday", "✨", "Glycolic Glow", "Glycolic acid night — texture + brightness", "10-min wait after glycolic. Face only."),
        (2, "Tuesday", "🌙", "Retinal Renewal", "Niacinamide buffer + Retinal Intense", "Fully dry skin. No acids, no steam tonight."),
        (3, "Wednesday", "🧖‍♀️", "Removal · Steam · Mask", "Nair + steam + Tata Harper + azelaic + salicylic", "Big night! Protect the mustache area throughout."),
        (4, "Thursday", "💫", "Glycolic + Azelaic", "Double acid night", "Skip Glow Up Pads if skin feels sensitive."),
        (5, "Friday", "🌙", "Retinal Renewal", "Niacinamide buffer + Retinal Intense", "Same rules as Tuesday — dry skin, no heat."),
        (6, "Saturday", "🫧", "Azelaic + Salicylic", "Deep-clean acid duo", "Salicylic is twice weekly now (Wed + Sat)."),
        (0, "Sunday", "🛁", "Steam · Mask · Rest", "Steam + Tata Harper mask, then rest", "Recovery night — hydration only after the mask."),
    ]
}

// MARK: - Notifications

enum NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func sync(_ reminders: [Reminder]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for r in reminders {
            let content = UNMutableNotificationContent()
            content.title = "Skincare Ritual ♡"
            content.body = r.label
            content.sound = .default
            if r.days.count == 7 {
                var dc = DateComponents()
                dc.hour = r.hour; dc.minute = r.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                center.add(UNNotificationRequest(identifier: r.id.uuidString, content: content, trigger: trigger))
            } else {
                for d in r.days {
                    var dc = DateComponents()
                    dc.hour = r.hour; dc.minute = r.minute; dc.weekday = d
                    let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
                    center.add(UNNotificationRequest(identifier: "\(r.id.uuidString)-\(d)", content: content, trigger: trigger))
                }
            }
        }
    }
}

// MARK: - Store

final class AppStore: ObservableObject {
    @Published var selectedDate: Date = Date() {
        didSet { timers = [:]; loadChecks() }
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
    }

    var dateKey: String { Self.keyFormatter.string(from: selectedDate) }
    var jsWeekday: Int { Calendar.current.component(.weekday, from: selectedDate) - 1 } // 0=Sun
    var isWednesday: Bool { jsWeekday == 3 }
    var azelaicBodyDay: Bool {
        (Calendar.current.ordinality(of: .day, in: .year, for: selectedDate) ?? 0) % 2 == 0
    }
    var plan: DayPlan { Catalog.pmByDay[jsWeekday] ?? Catalog.pmByDay[1]! }

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
        if timers[key] != nil { timers.removeValue(forKey: key); return }
        if let wait = step.wait, wait > 0 {
            let name = step.label ?? Catalog.products[step.productID ?? ""]?.name ?? "Step"
            timers[key] = RunningTimer(end: Date().addingTimeInterval(TimeInterval(wait * 60)),
                                       total: TimeInterval(wait * 60), label: name)
        } else {
            setCheck(key, true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// Double tap: skip any timer and complete immediately.
    func skip(_ key: String) {
        timers.removeValue(forKey: key)
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if !timers.isEmpty {
            objectWillChange.send() // refresh countdown labels
        }
    }

    // Progress across everything shown today
    var allKeys: [String] {
        var keys = Catalog.amSteps.map(\.key) + plan.steps.map(\.key) + Catalog.habits.map(\.key)
        if isWednesday { keys += Catalog.removalSteps.map(\.key) }
        for area in ["bikini", "armpits", "chest"] {
            keys += Catalog.bodySteps(area: area, includeAzelaic: azelaicBodyDay).map(\.key)
        }
        return keys
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

// MARK: - Root

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "checklist") }
            WeekPlanView()
                .tabItem { Label("Week", systemImage: "calendar") }
            PhotosView()
                .tabItem { Label("Photos", systemImage: "camera.fill") }
            RemindersView()
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
        }
        .tint(.roseDeep)
    }
}

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var infoProduct: Product?
    private let heartbeat = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    ProgressHeader()
                    WeekStrip()

                    SectionCard(title: "Morning ritual", emoji: "☀️", accent: .amGold, tint: .amTint,
                                subtitle: "Same glow, every day",
                                steps: Catalog.amSteps, infoProduct: $infoProduct, photoArea: "face")

                    if store.isWednesday {
                        SectionCard(title: "Hair removal", emoji: "🪞", accent: .rose, tint: .roseTint,
                                    subtitle: "Do this first, before the evening routine",
                                    steps: Catalog.removalSteps, infoProduct: $infoProduct,
                                    footer: "Tonight's mustache rules: no steam, no mask, no azelaic on the mustache area. Hyaluronic Concentrate is the only yes. 💋",
                                    photoArea: "removal")
                    }

                    SectionCard(title: "Evening ritual", emoji: "🌙", accent: .pmLav, tint: .pmTint,
                                subtitle: "\(store.plan.emoji) \(store.plan.focus)",
                                steps: store.plan.steps, infoProduct: $infoProduct, photoArea: "face")

                    bodyCard(area: "bikini", title: "Bikini", emoji: "🌸")
                    bodyCard(area: "armpits", title: "Armpits", emoji: "🫶",
                             footer: "Rule: niacinamide, pads + azelaic only. Never glycolic, retinal or salicylic here.")
                    bodyCard(area: "chest", title: "Chest", emoji: "💗",
                             subtitle: "Bumps are the purge — clears weeks 4–6 💪")

                    SectionCard(title: "Daily glow habits", emoji: "🍵", accent: .greenC,
                                tint: Color(hex: 0xEAF3EC), subtitle: nil,
                                steps: Catalog.habits, infoProduct: $infoProduct, photoArea: "habits")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .onReceive(heartbeat) { _ in store.tick() }
        .sheet(item: $infoProduct) { ProductSheet(product: $0) }
    }

    private func bodyCard(area: String, title: String, emoji: String,
                          subtitle: String? = "Daily care after shower", footer: String? = nil) -> some View {
        SectionCard(title: title, emoji: emoji, accent: .bodyCoral, tint: .bodyTint,
                    subtitle: subtitle,
                    steps: Catalog.bodySteps(area: area, includeAzelaic: store.azelaicBodyDay),
                    infoProduct: $infoProduct,
                    footer: store.azelaicBodyDay ? footer : (footer ?? "Azelaic acid rests today — it's back tomorrow ✨"),
                    photoArea: area)
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
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
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
                    Text("\(doneCount)/\(steps.count)")
                        .font(.caption.weight(.bold)).foregroundColor(accent)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold)).foregroundColor(.faint)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if open {
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

// MARK: - Progress photos

struct PhotoArea {
    let key: String
    let title: String
    let emoji: String
}

enum PhotoAreas {
    static let all: [PhotoArea] = [
        PhotoArea(key: "face", title: "Face", emoji: "🌷"),
        PhotoArea(key: "chest", title: "Chest", emoji: "💗"),
        PhotoArea(key: "armpits", title: "Armpits", emoji: "🫶"),
        PhotoArea(key: "bikini", title: "Bikini", emoji: "🌸"),
        PhotoArea(key: "removal", title: "Removal", emoji: "🪞"),
        PhotoArea(key: "habits", title: "Habits", emoji: "🍵"),
    ]
}

struct PhotosView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedArea = "face"
    @State private var showCamera = false
    @State private var cameraUnavailable = false
    @State private var viewerPhoto: ProgressPhoto?
    @State private var showTimelapse = false
    @State private var showDemo = false

    private var photosForArea: [ProgressPhoto] { store.photos(for: selectedArea) }
    private var areaTitle: String { PhotoAreas.all.first { $0.key == selectedArea }?.title ?? "" }
    private var todayHasPhoto: Bool {
        photosForArea.contains { $0.dateKey == store.dateKey(Date()) }
    }
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Progress photos")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("A private, on-device timeline for each area. Nothing leaves your phone.")
                        .font(.footnote).foregroundColor(.soft)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PhotoAreas.all, id: \.key) { area in
                                let selected = selectedArea == area.key
                                Button { selectedArea = area.key } label: {
                                    VStack(spacing: 2) {
                                        Text(area.emoji)
                                        Text(area.title).font(.caption.weight(.bold))
                                    }
                                    .foregroundColor(selected ? .white : .soft)
                                    .frame(width: 72)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 13)
                                        .fill(selected ? Color.bodyCoral : Color.white.opacity(0.75)))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showCamera = true
                            } else {
                                cameraUnavailable = true
                            }
                        } label: {
                            Label(todayHasPhoto ? "Retake today's photo" : "Take today's photo", systemImage: "camera.fill")
                                .font(.subheadline.weight(.heavy))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(Color.bodyCoral))
                        }

                        Button {
                            showTimelapse = true
                        } label: {
                            Image(systemName: "play.rectangle.fill")
                                .font(.subheadline.weight(.heavy))
                                .foregroundColor(photosForArea.count < 2 ? .faint : .roseDeep)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.white))
                        }
                        .disabled(photosForArea.count < 2)
                    }

                    if photosForArea.isEmpty {
                        VStack(spacing: 10) {
                            Text("📸").font(.system(size: 32))
                            Text("No photos yet for \(areaTitle)")
                                .font(.subheadline.weight(.semibold)).foregroundColor(.ink)
                            Text("Take your first daily photo to start tracking progress.")
                                .font(.caption).foregroundColor(.soft)
                                .multilineTextAlignment(.center)
                            Button { showDemo = true } label: {
                                Label("See how the timelapse works", systemImage: "play.circle.fill")
                                    .font(.caption.weight(.heavy))
                                    .foregroundColor(.roseDeep)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Color.roseTint))
                            }
                            .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(photosForArea) { photo in
                                Button { viewerPhoto = photo } label: {
                                    PhotoThumb(photo: photo)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(overlayImage: store.previousPhoto(for: selectedArea, excluding: store.dateKey(Date())).flatMap(store.image(for:))) { image in
                store.savePhoto(image, area: selectedArea)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $viewerPhoto) { photo in
            PhotoViewerSheet(photo: photo)
        }
        .sheet(isPresented: $showTimelapse) {
            if let area = PhotoAreas.all.first(where: { $0.key == selectedArea }) {
                TimelapseView(area: area)
            }
        }
        .sheet(isPresented: $showDemo) {
            if let area = PhotoAreas.all.first(where: { $0.key == selectedArea }) {
                DemoTimelapseView(area: area)
            }
        }
        .alert("Camera not available", isPresented: $cameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device (or simulator) doesn't have a camera available.")
        }
    }
}

struct PhotoThumb: View {
    @EnvironmentObject var store: AppStore
    let photo: ProgressPhoto

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = store.image(for: photo) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.roseTint
            }
            Text(DateKeyFormat.displayString(from: photo.dateKey))
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .padding(5)
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct PhotoViewerSheet: View {
    @EnvironmentObject var store: AppStore
    let photo: ProgressPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 16) {
            if let img = store.image(for: photo) {
                Image(uiImage: img).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            Text(DateKeyFormat.displayString(from: photo.dateKey))
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundColor(.ink)
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete photo", systemImage: "trash")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.roseDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.roseTint))
            }
            Spacer()
        }
        .padding(24)
        .presentationDetents([.large])
        .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deletePhoto(photo)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Timelapse

struct RangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let bounds: ClosedRange<Double>
    var accent: Color = .bodyCoral
    private let thumbSize: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let trackWidth = max(0, geo.size.width - thumbSize)
            let span = bounds.upperBound - bounds.lowerBound
            let lowerX = span > 0 ? CGFloat((lowerValue - bounds.lowerBound) / span) * trackWidth : 0
            let upperX = span > 0 ? CGFloat((upperValue - bounds.lowerBound) / span) * trackWidth : trackWidth

            ZStack(alignment: .leading) {
                Capsule().fill(Color.lineC).frame(height: 4)
                    .offset(x: thumbSize / 2)
                Capsule().fill(accent).frame(width: max(0, upperX - lowerX), height: 4)
                    .offset(x: lowerX + thumbSize / 2)

                thumb.offset(x: lowerX)
                    .gesture(DragGesture().onChanged { value in
                        guard span > 0 else { return }
                        let raw = bounds.lowerBound + Double((value.location.x - thumbSize / 2) / trackWidth) * span
                        lowerValue = min(max(raw.rounded(), bounds.lowerBound), upperValue)
                    })

                thumb.offset(x: upperX)
                    .gesture(DragGesture().onChanged { value in
                        guard span > 0 else { return }
                        let raw = bounds.lowerBound + Double((value.location.x - thumbSize / 2) / trackWidth) * span
                        upperValue = max(min(raw.rounded(), bounds.upperBound), lowerValue)
                    })
            }
        }
    }

    private var thumb: some View {
        Circle().fill(Color.white)
            .overlay(Circle().stroke(accent, lineWidth: 3))
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: Color.ink.opacity(0.15), radius: 2, y: 1)
    }
}

enum TimelapseSpeed {
    /// Scales flip speed to photo count so playback stays roughly this many seconds long,
    /// without ever flickering too fast or crawling too slow.
    static func interval(forFrameCount count: Int, targetDuration: Double = 6.0,
                         minInterval: Double = 0.12, maxInterval: Double = 0.6) -> Double {
        guard count > 1 else { return maxInterval }
        return min(max(targetDuration / Double(count), minInterval), maxInterval)
    }
}

struct DemoTimelapseView: View {
    let area: PhotoArea
    @Environment(\.dismiss) private var dismiss

    private let frameCount = 30
    @State private var index: Double = 0
    @State private var isPlaying = true

    private let playTimer = Timer.publish(every: TimelapseSpeed.interval(forFrameCount: 30), on: .main, in: .common).autoconnect()

    private var frameIndex: Int { min(frameCount - 1, max(0, Int(index.rounded()))) }
    private var progress: Double { Double(frameIndex) / Double(frameCount - 1) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.roseDeep)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.roseTint))
                    }
                    Spacer()
                    Text("Example timelapse")
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Spacer()
                    Color.clear.frame(width: 30, height: 30)
                }

                Text("Illustrated example — once you've taken a few \(area.title.lowercased()) photos, your real timeline will scrub and play just like this.")
                    .font(.caption).foregroundColor(.soft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                DemoFrameView(progress: progress)
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text("Day \(frameIndex + 1) of \(frameCount) · example")
                    .font(.caption.weight(.bold)).foregroundColor(.soft)

                Slider(value: $index, in: 0...Double(frameCount - 1), step: 1) { editing in
                    if editing { isPlaying = false }
                }
                .tint(.bodyCoral)

                Button {
                    if frameIndex == frameCount - 1 { index = 0 }
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.bodyCoral))
                }

                Spacer()
            }
            .padding(20)
        }
        .onReceive(playTimer) { _ in
            guard isPlaying else { return }
            let next = frameIndex + 1
            index = Double(next > frameCount - 1 ? 0 : next)
        }
    }
}

struct DemoFrameView: View {
    let progress: Double   // 0...1

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(hex: 0xE7D3DC),
                Color.rose.opacity(0.55 + progress * 0.35),
                Color.amGold.opacity(0.25 + progress * 0.35),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 7)
                .frame(width: 140, height: 140)
            Circle()
                .trim(from: 0, to: 0.3 + progress * 0.7)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 140, height: 140)
                .animation(.easeInOut(duration: 0.4), value: progress)

            VStack(spacing: 4) {
                Text("✨").font(.system(size: 30)).opacity(0.35 + progress * 0.65)
                Text("\(Int(progress * 100))% glow")
                    .font(.system(.subheadline, design: .serif).weight(.bold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct TimelapseView: View {
    @EnvironmentObject var store: AppStore
    let area: PhotoArea
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [ProgressPhoto] = []   // oldest -> newest, full history
    @State private var images: [UIImage] = []          // parallel to photos
    @State private var rangeStart: Double = 0           // trim handles, indices into photos
    @State private var rangeEnd: Double = 0
    @State private var index: Double = 0                // scrub/playback position within the trimmed range
    @State private var isPlaying = false
    @State private var isExporting = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var showSavedAlert = false
    @State private var elapsedSincePlay: TimeInterval = 0

    // Fast fixed tick; actual advance rate adapts to trimmedPhotos.count via elapsedSincePlay,
    // so speed stays correct even as the trim range changes live.
    private let heartbeat = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private var playInterval: Double { TimelapseSpeed.interval(forFrameCount: trimmedPhotos.count) }

    private var trimStart: Int { photos.isEmpty ? 0 : min(Int(rangeStart.rounded()), photos.count - 1) }
    private var trimEnd: Int { photos.isEmpty ? 0 : min(Int(rangeEnd.rounded()), photos.count - 1) }
    private var trimmedPhotos: [ProgressPhoto] { photos.isEmpty ? [] : Array(photos[trimStart...trimEnd]) }
    private var trimmedImages: [UIImage] { images.isEmpty ? [] : Array(images[trimStart...trimEnd]) }

    private var frameIndex: Int {
        guard !trimmedPhotos.isEmpty else { return 0 }
        return min(trimmedPhotos.count - 1, max(0, Int(index.rounded())))
    }
    private var currentImage: UIImage? { trimmedImages.indices.contains(frameIndex) ? trimmedImages[frameIndex] : nil }
    private var currentPhoto: ProgressPhoto? { trimmedPhotos.indices.contains(frameIndex) ? trimmedPhotos[frameIndex] : nil }
    private var rangeLabel: String {
        guard let first = trimmedPhotos.first, let last = trimmedPhotos.last else { return "" }
        return "\(trimmedPhotos.count) photos · \(DateKeyFormat.displayString(from: first.dateKey)) – \(DateKeyFormat.displayString(from: last.dateKey))"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.roseDeep)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.roseTint))
                    }
                    Spacer()
                    Text("\(area.emoji) \(area.title) timelapse")
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Spacer()
                    Color.clear.frame(width: 30, height: 30)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(Color.black)
                    if let img = currentImage {
                        Image(uiImage: img).resizable().scaledToFit()
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxHeight: 380)

                if let photo = currentPhoto {
                    Text("\(DateKeyFormat.displayString(from: photo.dateKey)) · \(frameIndex + 1) of \(trimmedPhotos.count)")
                        .font(.caption.weight(.bold)).foregroundColor(.soft)
                }

                if photos.count > 1 {
                    Slider(value: $index, in: 0...Double(max(0, trimmedPhotos.count - 1)), step: 1) { editing in
                        if editing { isPlaying = false }
                    }
                    .tint(.bodyCoral)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("TRIM RANGE")
                                .font(.caption2.weight(.heavy)).foregroundColor(.soft)
                            Spacer()
                            Text(rangeLabel)
                                .font(.caption2).foregroundColor(.faint)
                        }
                        RangeSlider(lowerValue: $rangeStart, upperValue: $rangeEnd,
                                    bounds: 0...Double(photos.count - 1), accent: .bodyCoral)
                            .frame(height: 26)
                        HStack(spacing: 8) {
                            presetChip("All") { applyPreset(days: nil) }
                            presetChip("Last 7 days") { applyPreset(days: 7) }
                            presetChip("Last 30 days") { applyPreset(days: 30) }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                } else {
                    Text("Take at least 2 photos of \(area.title.lowercased()) to build a timelapse.")
                        .font(.caption).foregroundColor(.soft)
                }

                HStack(spacing: 12) {
                    Button {
                        if frameIndex == trimmedPhotos.count - 1 { index = 0 }
                        isPlaying.toggle()
                    } label: {
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.bodyCoral))
                    }
                    .disabled(trimmedPhotos.count < 2)

                    Button {
                        exportVideo()
                    } label: {
                        Label(isExporting ? "Exporting…" : "Export", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(isExporting ? Color.faint : Color.rose))
                    }
                    .disabled(trimmedPhotos.count < 2 || isExporting)
                }

                if isExporting {
                    ProgressView().tint(.rose)
                }

                Spacer()
            }
            .padding(20)
        }
        .onAppear(perform: load)
        .onChange(of: rangeStart) { _, _ in isPlaying = false; index = 0; elapsedSincePlay = 0 }
        .onChange(of: rangeEnd) { _, _ in isPlaying = false; index = 0; elapsedSincePlay = 0 }
        .onReceive(heartbeat) { _ in
            guard isPlaying, trimmedPhotos.count > 1 else { return }
            elapsedSincePlay += 0.05
            guard elapsedSincePlay >= playInterval else { return }
            elapsedSincePlay = 0
            let next = frameIndex + 1
            index = Double(next > trimmedPhotos.count - 1 ? 0 : next)
        }
        .alert("Saved to Photos ♡", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
    }

    private func presetChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.roseDeep)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.roseTint))
        }
    }

    private func load() {
        photos = store.photos(for: area.key).sorted { $0.dateKey < $1.dateKey }
        images = photos.compactMap { store.image(for: $0) }
        rangeStart = 0
        rangeEnd = Double(max(0, photos.count - 1))
        index = 0
    }

    private func applyPreset(days: Int?) {
        guard !photos.isEmpty else { return }
        guard let days else {
            rangeStart = 0
            rangeEnd = Double(photos.count - 1)
            return
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date())) ?? .distantPast
        let cutoffKey = store.dateKey(cutoff)
        let firstIdx = photos.firstIndex { $0.dateKey >= cutoffKey } ?? 0
        rangeStart = Double(firstIdx)
        rangeEnd = Double(photos.count - 1)
    }

    private func exportVideo() {
        isPlaying = false
        isExporting = true
        TimelapseRenderer.export(images: trimmedImages) { result in
            isExporting = false
            switch result {
            case .success(let url):
                saveToPhotos(url)
            case .failure(let error):
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
        }
    }

    private func saveToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    exportErrorMessage = "Photos access is needed to save the timelapse. Enable it in Settings → Privacy → Photos."
                    showExportError = true
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            showSavedAlert = true
                        } else {
                            exportErrorMessage = error?.localizedDescription ?? "Could not save the video."
                            showExportError = true
                        }
                        try? FileManager.default.removeItem(at: url)
                    }
                }
            }
        }
    }
}

enum TimelapseRenderer {
    enum RenderError: LocalizedError {
        case noImages
        case writerSetupFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .noImages: return "No photos to render."
            case .writerSetupFailed: return "Couldn't set up the video writer."
            case .writeFailed: return "Something went wrong while writing the video."
            }
        }
    }

    nonisolated static func export(images: [UIImage], fps: Int32 = 2, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try renderSync(images: images, fps: fps)
                DispatchQueue.main.async { completion(.success(url)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    nonisolated private static func renderSync(images: [UIImage], fps: Int32) throws -> URL {
        guard let first = images.first else { throw RenderError.noImages }

        let maxDim: CGFloat = 1280
        let scale = min(1, maxDim / max(first.size.width, first.size.height))
        let rawWidth = Int((first.size.width * scale).rounded())
        let rawHeight = Int((first.size.height * scale).rounded())
        let width = max(2, rawWidth - rawWidth % 2)
        let height = max(2, rawHeight - rawHeight % 2)

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("timelapse-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelBufferAttrs)

        guard writer.canAdd(input) else { throw RenderError.writerSetupFailed }
        writer.add(input)

        guard writer.startWriting() else { throw RenderError.writerSetupFailed }
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: fps)
        var frameCount: Int64 = 0

        for image in images {
            guard let buffer = pixelBuffer(from: image, width: width, height: height) else { continue }
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            let time = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
            adaptor.append(buffer, withPresentationTime: time)
            frameCount += 1
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        guard writer.status == .completed else { throw RenderError.writeFailed }
        return outputURL
    }

    nonisolated private static func pixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let upright = normalized(image)
        guard let cgImage = upright.cgImage else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width, height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let imgSize = CGSize(width: cgImage.width, height: cgImage.height)
        let fitScale = min(CGFloat(width) / imgSize.width, CGFloat(height) / imgSize.height)
        let drawSize = CGSize(width: imgSize.width * fitScale, height: imgSize.height * fitScale)
        let origin = CGPoint(x: (CGFloat(width) - drawSize.width) / 2, y: (CGFloat(height) - drawSize.height) / 2)
        context.draw(cgImage, in: CGRect(origin: origin, size: drawSize))

        return buffer
    }

    nonisolated private static func normalized(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var overlayImage: UIImage? = nil
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        if let overlayImage {
            let overlay = UIImageView(image: overlayImage)
            overlay.frame = UIScreen.main.bounds
            overlay.contentMode = .scaleAspectFit
            overlay.clipsToBounds = true
            overlay.alpha = 0.3
            overlay.isUserInteractionEnabled = false
            picker.cameraOverlayView = overlay
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Reminders

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @State private var newLabel = ""
    @State private var newTime = Calendar.current.date(from: DateComponents(hour: 7, minute: 30)) ?? Date()
    @State private var newDays: Set<Int> = Set(1...7)
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
                    Text("These fire as real notifications — lock screen, banners, sounds — even when the app is closed. 💌")
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
                                store.reminders.removeAll { $0.id == r.id }
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
    }
}

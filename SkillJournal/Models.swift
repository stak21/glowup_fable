//  Models.swift
//  Skill Journal
//
//  The engine structures are carried over from GlowUp unchanged where
//  possible; everything skincare-specific (step categories, wait/cadence
//  tables, kits, quiz) is replaced by data from a DomainPack — one JSON
//  format shared by bundled packs and, later, runtime-generated ones.

import Foundation

// MARK: - Domain packs

struct DomainPack: Codable, Identifiable {
    let schemaVersion: Int            // 1; PackStore rejects others
    let id: String                    // "gardening" | later "custom-<uuid>"
    let name: String
    let emoji: String
    let tagline: String
    let accentTheme: String           // RoutineTheme rawValue
    let categories: [PackCategory]
    let coreCategoryIDs: [String]     // drives "add a ___" placeholder slots
    let waitRules: [WaitRule]
    let cadenceRules: [CadenceRule]
    let templates: [RoutineTemplate]
    let quiz: PackQuiz?
    let educationPages: [EducationPage]?
    let photoAreas: [PackPhotoArea]?
    let products: [PackProduct]?
}

struct PackCategory: Codable, Identifiable, Equatable {
    let id: String        // "watering" — stored in RStep.categoryID
    let name: String
    let emoji: String
    let sortRank: Int     // auto-placement rank (lower = earlier)
}

/// Struct, not enum-with-associated-values: the flat
/// {"kind": "daily"|"everyOtherDay"|"days", "days": [Int]?} shape keeps the
/// structured-outputs JSON schema trivial.
struct Cadence: Codable, Equatable {
    let kind: String      // "daily" | "everyOtherDay" | "days"
    var days: [Int]? = nil // jsWeekday 0=Sun…6=Sat, only when kind == "days"

    static let daily = Cadence(kind: "daily")
    static let everyOtherDay = Cadence(kind: "everyOtherDay")

    /// Whether a step with this cadence is active on the given date.
    /// everyOtherDay keeps GlowUp's global day-of-year parity so all
    /// resting steps rest on the same days.
    func isActive(on date: Date) -> Bool {
        switch kind {
        case "everyOtherDay":
            return (Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0) % 2 == 0
        case "days":
            guard let days else { return true }
            let jsWeekday = Calendar.current.component(.weekday, from: date) - 1
            return days.contains(jsWeekday)
        default:
            return true
        }
    }

    /// Short label for step chips; nil when daily (no chip).
    var chipLabel: String? {
        switch kind {
        case "everyOtherDay": return "every other day"
        case "days":
            guard let days, !days.isEmpty else { return nil }
            let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return days.sorted().compactMap { names.indices.contains($0) ? names[$0] : nil }
                .joined(separator: " · ")
        default: return nil
        }
    }
}

struct WaitRule: Codable {
    let categoryID: String?
    let keyword: String?
    let minutes: Int
}

struct CadenceRule: Codable {
    let categoryID: String?
    let keyword: String?
    let cadence: Cadence
}

struct RoutineTemplate: Codable, Identifiable {
    let id: String
    let title: String
    let blurb: String
    let routines: [TemplateRoutine]
}

struct TemplateRoutine: Codable {
    let title: String
    let emoji: String
    let theme: String                 // RoutineTheme rawValue
    let days: [Int]                   // jsWeekday 0=Sun…6=Sat
    let photoAreaID: String?
    let footer: String?               // → Routine.footer (caution chip)
    let steps: [TemplateStep]
}

struct TemplateStep: Codable {
    let label: String
    let categoryID: String?
    let waitMinutes: Int?
    let cadence: Cadence?
    let note: String?
    let productID: String?
}

struct PackQuiz: Codable {
    let questions: [QuizQuestion]
}

struct QuizQuestion: Codable {
    let prompt: String
    let options: [QuizOption]
}

struct QuizOption: Codable {
    let emoji: String
    let title: String
    let subtitle: String?
    let templateVotes: [String: Int]  // templateID → weight
}

struct EducationPage: Codable {
    let title: String
    let emoji: String
    let body: String
}

struct PackPhotoArea: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let emoji: String
}

/// Mirrors GlowUp's Product fields so the what/why/order/caution info sheet
/// carries over unchanged.
struct PackProduct: Codable, Identifiable {
    let id: String
    let name: String
    let tag: String
    let what: String
    let why: String
    let order: String
    let caution: String?
    let categoryID: String?
    let url: URL?
}

// MARK: - Pack rule lookups (replace GlowUp's compiled tables)

extension DomainPack {
    func category(_ id: String?) -> PackCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func rank(of categoryID: String?) -> Int? {
        category(categoryID)?.sortRank
    }

    func product(_ id: String?) -> PackProduct? {
        guard let id else { return nil }
        return products?.first { $0.id == id }
    }

    var theme: RoutineTheme { RoutineTheme(rawValue: accentTheme) ?? .green }

    /// Default wait for a newly added step. First match wins; keyword rules
    /// (case-insensitive contains) are checked before pure category rules,
    /// mirroring GlowUp's DefaultWait table.
    func defaultWaitMinutes(stepText: String, categoryID: String?) -> Int? {
        let text = stepText.lowercased()
        for rule in waitRules {
            guard let keyword = rule.keyword?.lowercased(), text.contains(keyword) else { continue }
            if let ruleCategory = rule.categoryID, ruleCategory != categoryID { continue }
            return rule.minutes
        }
        for rule in waitRules where rule.keyword == nil {
            if let ruleCategory = rule.categoryID, ruleCategory == categoryID { return rule.minutes }
        }
        return nil
    }

    /// Default cadence for a newly added step; same matching order as waits.
    func defaultCadence(stepText: String, categoryID: String?) -> Cadence? {
        let text = stepText.lowercased()
        for rule in cadenceRules {
            guard let keyword = rule.keyword?.lowercased(), text.contains(keyword) else { continue }
            if let ruleCategory = rule.categoryID, ruleCategory != categoryID { continue }
            return rule.cadence
        }
        for rule in cadenceRules where rule.keyword == nil {
            if let ruleCategory = rule.categoryID, ruleCategory == categoryID { return rule.cadence }
        }
        return nil
    }
}

// MARK: - Routine engine structures (from GlowUp)

struct RStep: Identifiable, Codable, Equatable {
    var key: String                 // unique check id; opaque everywhere
    var productID: String? = nil    // key into the active pack's products
    var label: String? = nil        // custom label (free-text steps)
    var wait: Int? = nil            // minutes to count down
    var note: String? = nil
    var cadence: Cadence? = nil     // nil = daily (was everyOtherDay: Bool)
    var categoryID: String? = nil   // pack category (was category: StepCategory)
    var id: String { key }
}

enum RoutineTheme: String, Codable, CaseIterable, Identifiable {
    case gold, lavender, rose, coral, green
    var id: String { rawValue }
}

enum RoutinePlacement {
    /// Index for a new step of `categoryID`: after the last step whose category
    /// rank ≤ the new one; uncategorized steps stay anchored where the user put
    /// them. Same walk as GlowUp, ranks from the pack instead of an enum.
    static func insertionIndex(for categoryID: String?, in steps: [RStep], pack: DomainPack?) -> Int {
        guard let pack, let rank = pack.rank(of: categoryID) else { return steps.count }
        var index: Int? = nil
        for (i, existing) in steps.enumerated() {
            if let existingRank = pack.rank(of: existing.categoryID), existingRank <= rank {
                index = i + 1
            }
        }
        if let index { return index }
        // No earlier-or-equal anchor: go before the categorized steps if any exist, else append.
        return steps.contains { pack.rank(of: $0.categoryID) != nil } ? 0 : steps.count
    }

    /// Core categories the pack expects a routine to cover — drives the dashed
    /// "add a ___" placeholder slots. `omit` marks categories a routine
    /// deliberately skips (e.g. covered by a sibling routine in its template).
    static func missingCoreCategories(in steps: [RStep], omit: Set<String> = [], pack: DomainPack?) -> [PackCategory] {
        guard let pack else { return [] }
        let present = Set(steps.compactMap(\.categoryID))
        return pack.coreCategoryIDs
            .filter { !present.contains($0) && !omit.contains($0) }
            .compactMap { pack.category($0) }
    }
}

struct Routine: Identifiable, Codable, Equatable {
    var id: String                  // "rt-" + UUID prefix
    var title: String
    var emoji: String
    var subtitle: String? = nil
    var focus: String? = nil        // header line
    var footer: String? = nil       // caution chip under the card
    var days: Set<Int>              // 0=Sun … 6=Sat (jsWeekday convention)
    var photoArea: String? = nil    // pack photo-area id, or nil for no photo prompt
    var theme: RoutineTheme = .green
    var steps: [RStep]
    var packID: String? = nil               // pack this routine belongs to
    var sourceTemplateID: String? = nil     // template it was built from
    /// Core categories this routine deliberately skips (see RoutinePlacement).
    var omitCoreCategories: Set<String> = []
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
    let area: String        // pack photo-area id
    let dateKey: String     // yyyy-MM-dd
    let filename: String    // file on disk in the ProgressPhotos folder
    var assetID: String? = nil  // Photos-library localIdentifier once backed up
}

struct WishlistItem: Identifiable, Codable, Equatable {
    var id: String { productID }
    let productID: String
    var addedAt = Date()
    var purchased = false     // checkable while shopping
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

/// Display-only info for a step's "why" sheet, derived from a PackProduct.
struct ProductInfo {
    let name: String
    let tag: String
    let what: String
    let why: String
    let order: String
    let caution: String?
}

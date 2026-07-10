//  Models.swift
//  Clearing

import Foundation

// MARK: - Models

struct Product: Identifiable {
    var id: String { name }
    let name: String
    let tag: String
    let what: String
    let why: String
    let order: String
    var caution: String? = nil
    var category: StepCategory? = nil
}

/// Canonical skincare layering order — declaration order is the sort order
/// used when auto-placing a product into a routine. nil category = manual position.
enum StepCategory: String, Codable, CaseIterable, Identifiable {
    case cleanser, exfoliant, treatment, moisturizer, spf, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cleanser: return "Cleanser"
        case .exfoliant: return "Exfoliant"
        case .treatment: return "Treatment"
        case .moisturizer: return "Moisturizer"
        case .spf: return "SPF"
        case .other: return "Extras"
        }
    }
    var sortRank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

struct RStep: Identifiable, Codable, Equatable {
    var key: String                 // unique check id, e.g. "am0"; opaque everywhere
    var productID: String? = nil    // key into Catalog.products or the shop catalog
    var label: String? = nil        // custom label (removal steps)
    var wait: Int? = nil            // minutes to count down
    var note: String? = nil
    var everyOtherDay = false       // step is active only on azelaicBodyDay
    var category: StepCategory? = nil
    var id: String { key }
}

enum RoutineTheme: String, Codable, CaseIterable, Identifiable {
    case gold, lavender, rose, coral, green
    var id: String { rawValue }
}

enum RoutinePlacement {
    /// Index for a new step of `category`: after the last step whose category
    /// rank ≤ the new one; uncategorized steps stay anchored where the user put them.
    static func insertionIndex(for category: StepCategory?, in steps: [RStep]) -> Int {
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

    /// Core categories a routine is expected to cover — drives placeholder slots.
    static let coreCategories: [StepCategory] = [.cleanser, .treatment, .moisturizer, .spf]

    static func missingCoreCategories(in steps: [RStep]) -> [StepCategory] {
        let present = Set(steps.compactMap(\.category))
        return coreCategories.filter { !present.contains($0) }
    }
}

struct Routine: Identifiable, Codable, Equatable {
    var id: String                  // migrated: "morning", "evening-mon"…; new: UUID string
    var title: String
    var emoji: String
    var subtitle: String? = nil
    var focus: String? = nil        // header line, e.g. "✨ Glycolic Glow"
    var footer: String? = nil       // caution chip under the card
    var planNote: String? = nil     // Week-tab note (not shown on Today)
    var days: Set<Int>              // 0=Sun … 6=Sat (jsWeekday convention)
    var photoArea: String? = nil    // existing PhotoAreas key, or nil for no photo prompt
    var theme: RoutineTheme = .rose
    var steps: [RStep]
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

// MARK: - Shop

enum Effect: String, Codable, CaseIterable, Identifiable {
    case brightening, darkSpots, acne, texture, hydration, soothing, pores, antiAging, body
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .brightening: return "Brightening"
        case .darkSpots: return "Dark spots"
        case .acne: return "Acne"
        case .texture: return "Texture"
        case .hydration: return "Hydration"
        case .soothing: return "Soothing"
        case .pores: return "Pores & oil"
        case .antiAging: return "Anti-aging"
        case .body: return "Body"
        }
    }
    var emoji: String {
        switch self {
        case .brightening: return "✨"
        case .darkSpots: return "🎯"
        case .acne: return "🫧"
        case .texture: return "🌸"
        case .hydration: return "💧"
        case .soothing: return "🌿"
        case .pores: return "🧖‍♀️"
        case .antiAging: return "⏳"
        case .body: return "🧴"
        }
    }
}

struct ShopProduct: Identifiable, Codable, Equatable {
    let id: String            // stable slug, e.g. "cosrx-snail-mucin"
    let name: String
    let brand: String
    let tag: String           // short descriptor, same voice as Product.tag
    let what: String
    let why: String
    let order: String
    var caution: String? = nil
    let effects: [Effect]
    let category: StepCategory
    let price: String         // freeform, e.g. "~$15"
    var storeURL: URL? = nil
}

/// Active "tap a product to add it" hand-off from the routine editor to the Shop tab.
struct ShopAddTarget: Equatable {
    let routineID: String
    let routineTitle: String
    var category: StepCategory? = nil
}

struct WishlistItem: Identifiable, Codable, Equatable {
    var id: String { productID }
    let productID: String
    var addedAt = Date()
    var purchased = false     // checkable while shopping in-store
}

// MARK: - Routine kits + quiz

enum RoutineTier: String, Codable, CaseIterable, Identifiable {
    case budget, mid, luxury
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .budget: return "Budget"
        case .mid: return "Mid-range"
        case .luxury: return "Luxury"
        }
    }
    var emoji: String {
        switch self {
        case .budget: return "💛"
        case .mid: return "💗"
        case .luxury: return "👑"
        }
    }
    var hint: String {
        switch self {
        case .budget: return "Around $60–70 all in"
        case .mid: return "Around $100–120 all in"
        case .luxury: return "The no-compromise picks"
        }
    }
}

enum SkinType: String, Codable, CaseIterable, Identifiable {
    case oily, dry, combination, sensitive, unsure
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .oily: return "Oily"
        case .dry: return "Dry"
        case .combination: return "Combination"
        case .sensitive: return "Sensitive"
        case .unsure: return "Not sure"
        }
    }
    var emoji: String {
        switch self {
        case .oily: return "✨"
        case .dry: return "🏜️"
        case .combination: return "🌗"
        case .sensitive: return "🌷"
        case .unsure: return "🤔"
        }
    }
}

struct KitItem: Codable, Equatable {
    let productID: String           // key into the shop catalog
    let role: String                // "Cleanse" / "Treat" / "Moisturize" / "Protect"
    var sensitiveAlt: String? = nil // gentler swap when the quiz says sensitive
}

struct RoutineKit: Identifiable, Codable, Equatable {
    let id: String                  // "<concern>-<tier>", e.g. "acne-budget"
    let concern: Effect
    let tier: RoutineTier
    let title: String
    let blurb: String
    let items: [KitItem]
}

struct QuizResult: Codable, Equatable {
    var skinType: SkinType
    var concern: Effect
    var tier: RoutineTier
    var takenAt = Date()
    var kitID: String { "\(concern.rawValue)-\(tier.rawValue)" }
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


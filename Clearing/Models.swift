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
    let price: String         // freeform, e.g. "~$15"
    var storeURL: URL? = nil
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


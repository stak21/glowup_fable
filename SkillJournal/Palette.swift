//  Palette.swift
//  Skill Journal

import SwiftUI

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

extension RoutineTheme {
    var accent: Color {
        switch self {
        case .gold: return .amGold
        case .lavender: return .pmLav
        case .rose: return .rose
        case .coral: return .bodyCoral
        case .green: return .greenC
        }
    }
    var tint: Color {
        switch self {
        case .gold: return .amTint
        case .lavender: return .pmTint
        case .rose: return .roseTint
        case .coral: return .bodyTint
        case .green: return Color(hex: 0xEAF3EC)
        }
    }
}


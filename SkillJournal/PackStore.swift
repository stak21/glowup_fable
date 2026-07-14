//  PackStore.swift
//  Skill Journal
//
//  Loads domain packs and answers the lookups the engine used to compile in:
//  categories, wait/cadence defaults, photo areas, products. Bundled packs
//  ship in the app; any JSON dropped in Documents/Packs (future runtime
//  generation) loads through the same path with zero loader changes.

import SwiftUI
import Combine

final class PackStore: ObservableObject {
    /// Bundled pack IDs, in Explore display order. Each maps to Pack-<id>.json.
    static let bundledIDs = ["gardening", "petcare", "fitness", "cleaning", "nootropics"]

    @Published private(set) var packs: [DomainPack] = []

    /// Packs the user has activated (drives Today/Photos/editor lookups).
    @Published var activePackIDs: [String] {
        didSet { UserDefaults.standard.set(activePackIDs, forKey: "activePackIDs") }
    }

    private static var documentsPacksDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Packs", isDirectory: true)
    }

    init() {
        activePackIDs = UserDefaults.standard.stringArray(forKey: "activePackIDs") ?? []
        reload()
    }

    func reload() {
        var loaded: [DomainPack] = []
        for id in Self.bundledIDs {
            guard let url = Bundle.main.url(forResource: "Pack-\(id)", withExtension: "json"),
                  let pack = Self.decode(url) else { continue }
            loaded.append(pack)
        }
        if let files = try? FileManager.default.contentsOfDirectory(
            at: Self.documentsPacksDirectory, includingPropertiesForKeys: nil) {
            for url in files where url.pathExtension == "json" {
                guard let pack = Self.decode(url),
                      !loaded.contains(where: { $0.id == pack.id }) else { continue }
                loaded.append(pack)
            }
        }
        packs = loaded
    }

    private static func decode(_ url: URL) -> DomainPack? {
        guard let data = try? Data(contentsOf: url),
              let pack = try? JSONDecoder().decode(DomainPack.self, from: data),
              pack.schemaVersion == 1 else { return nil }
        return pack
    }

    // MARK: Lookups

    func pack(_ id: String?) -> DomainPack? {
        guard let id else { return nil }
        return packs.first { $0.id == id }
    }

    var activePacks: [DomainPack] {
        activePackIDs.compactMap { pack($0) }
    }

    func isActive(_ id: String) -> Bool {
        activePackIDs.contains(id)
    }

    func activate(_ id: String) {
        guard pack(id) != nil, !isActive(id) else { return }
        activePackIDs.append(id)
    }

    /// The pack a routine belongs to, falling back to the first active pack
    /// for hand-built routines that predate pack tagging.
    func pack(for routine: Routine) -> DomainPack? {
        pack(routine.packID) ?? activePacks.first
    }

    /// Photo areas across active packs, deduped by id; generic fallback so
    /// the Photos tab always has at least one area.
    var allPhotoAreas: [PackPhotoArea] {
        var seen = Set<String>()
        var areas: [PackPhotoArea] = []
        for pack in activePacks {
            for area in pack.photoAreas ?? [] where !seen.contains(area.id) {
                seen.insert(area.id)
                areas.append(area)
            }
        }
        return areas.isEmpty ? [PackPhotoArea(id: "progress", title: "Progress", emoji: "📈")] : areas
    }

    /// Product lookup across active packs (first match wins).
    func product(_ id: String?) -> PackProduct? {
        guard let id else { return nil }
        for pack in activePacks {
            if let product = pack.product(id) { return product }
        }
        // Also search inactive packs so wishlist rows survive deactivation.
        for pack in packs {
            if let product = pack.product(id) { return product }
        }
        return nil
    }
}

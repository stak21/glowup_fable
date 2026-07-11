//  RoutineKitViews.swift
//  Clearing

import SwiftUI

// MARK: - Kit helpers

enum KitPricing {
    static func dollars(_ price: String) -> Int {
        Int(price.filter(\.isNumber)) ?? 0
    }
    static func estimatedTotal(kit: RoutineKit, products: [String: ShopProduct], resolvedIDs: [String]) -> Int {
        resolvedIDs.compactMap { products[$0] }.map { dollars($0.price) }.reduce(0, +)
    }
}

// MARK: - Kit card (Shop tab)

struct KitCard: View {
    let kit: RoutineKit
    let products: [String: ShopProduct]
    @EnvironmentObject var store: AppStore

    var body: some View {
        let total = KitPricing.estimatedTotal(kit: kit, products: products,
                                              resolvedIDs: store.resolvedProductIDs(for: kit))
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(kit.concern.emoji)
                    .font(.title3)
                Spacer()
                Text("\(kit.tier.emoji) \(kit.tier.displayName)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.roseDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.roseTint))
            }
            Text(kit.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.ink)
                .lineLimit(1)
            Text("\(kit.items.count) products · ~$\(total)")
                .font(.caption)
                .foregroundColor(.soft)
        }
        .padding(14)
        .frame(width: 190, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
    }
}

// MARK: - Kit detail

/// Standalone sheet wrapper around KitSheetContent.
struct KitSheet: View {
    let kit: RoutineKit
    let catalog: [ShopProduct]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                KitSheetContent(kit: kit, catalog: catalog)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// Kit detail body — used inside KitSheet and inside the quiz result screen.
struct KitSheetContent: View {
    let kit: RoutineKit
    let catalog: [ShopProduct]
    @EnvironmentObject var store: AppStore
    @State private var infoProduct: ShopProduct?

    private var products: [String: ShopProduct] {
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }
    private var sensitive: Bool { store.quizResult?.skinType == .sensitive }
    private var resolvedIDs: [String] { store.resolvedProductIDs(for: kit) }
    private var allAdded: Bool { resolvedIDs.allSatisfy { store.isWishlisted($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(kit.concern.emoji) \(kit.title)")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Spacer()
                    Text("\(kit.tier.emoji) \(kit.tier.displayName)")
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(.roseDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.roseTint))
                }
                Text(kit.blurb)
                    .font(.subheadline)
                    .foregroundColor(.soft)
            }

            if sensitive && kit.items.contains(where: { $0.sensitiveAlt != nil }) {
                Text("🌷 Swapped in gentler picks for your sensitive skin.")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.roseDeep)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.roseTint))
            }

            VStack(spacing: 10) {
                ForEach(Array(zip(kit.items, resolvedIDs)), id: \.1) { item, resolvedID in
                    if let product = products[resolvedID] {
                        kitRow(role: item.role, product: product,
                               swapped: resolvedID != item.productID)
                    }
                }
            }

            Text("🌱 Starter kits keep it simple: the core steps plus one active matched to your goal. More actives, exfoliants and extras layer in later, once your skin has settled.")
                .font(.footnote)
                .foregroundColor(.soft)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.8)))

            HStack {
                Text("Estimated total")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.ink)
                Spacer()
                Text("~$\(KitPricing.estimatedTotal(kit: kit, products: products, resolvedIDs: resolvedIDs))")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.roseDeep)
            }
            .padding(.top, 2)

            Button {
                store.addKit(kit)
            } label: {
                Text(allAdded ? "All on your list ♥" : "Add all to list ♡")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(allAdded ? Color.roseDeep : Color.rose))
            }
            .disabled(allAdded)
        }
        .sheet(item: $infoProduct) { ShopProductSheet(product: $0) }
    }

    private func kitRow(role: String, product: ShopProduct, swapped: Bool) -> some View {
        Button { infoProduct = product } label: {
            HStack(spacing: 12) {
                Text(role.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.soft)
                    .frame(width: 72, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                        .multilineTextAlignment(.leading)
                    Text("\(product.brand) · \(product.price)\(swapped ? " · gentler pick 🌷" : "")")
                        .font(.caption)
                        .foregroundColor(.soft)
                }
                Spacer(minLength: 8)
                Button { store.toggleWishlist(product.id) } label: {
                    Image(systemName: store.isWishlisted(product.id) ? "heart.fill" : "heart")
                        .foregroundColor(.roseDeep)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

//  Shop.swift
//  Clearing

import SwiftUI

// MARK: - Shop

struct ShopView: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    @State private var activeEffects: Set<Effect> = []
    @State private var infoProduct: ShopProduct?
    @State private var showWishlist = false

    private let catalog: [ShopProduct] = BundledShopCatalog().allProducts()

    private var results: [ShopProduct] {
        var items = catalog
        if !activeEffects.isEmpty {
            items = items.filter { !activeEffects.isDisjoint(with: $0.effects) }
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(q)
                || $0.brand.localizedCaseInsensitiveContains(q)
                || $0.tag.localizedCaseInsensitiveContains(q)
                || $0.what.localizedCaseInsensitiveContains(q)
            }
        }
        return items
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Shop")
                            .font(.system(.largeTitle, design: .serif).weight(.semibold))
                            .foregroundColor(.ink)
                        Spacer()
                        wishlistButton
                    }
                    .padding(.top, 8)

                    Text("Find something for…")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.soft)
                        .padding(.top, 2)

                    effectChips
                    searchField

                    if results.isEmpty {
                        Text(catalog.isEmpty
                             ? "The shop catalog couldn't be loaded."
                             : "Nothing matches — try fewer filters.")
                            .font(.subheadline)
                            .foregroundColor(.soft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(results) { product in
                                productRow(product)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $infoProduct) { ShopProductSheet(product: $0) }
        .sheet(isPresented: $showWishlist) { WishlistSheet(catalog: catalog) }
    }

    private var wishlistButton: some View {
        Button { showWishlist = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                if !store.wishlist.isEmpty {
                    Text("\(store.wishlist.count)")
                        .font(.footnote.weight(.heavy))
                }
            }
            .foregroundColor(.roseDeep)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.roseTint))
        }
    }

    private var effectChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Effect.allCases) { effect in
                    let active = activeEffects.contains(effect)
                    Button {
                        if active { activeEffects.remove(effect) } else { activeEffects.insert(effect) }
                    } label: {
                        Text("\(effect.emoji) \(effect.displayName)")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(active ? .white : .ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(active ? Color.rose : Color.white))
                            .overlay(Capsule().stroke(active ? Color.rose : Color.lineC, lineWidth: 1))
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.faint)
            TextField("Search products or brands", text: $query)
                .font(.subheadline)
                .foregroundColor(.ink)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.faint)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().stroke(Color.lineC, lineWidth: 1))
    }

    private func productRow(_ product: ShopProduct) -> some View {
        Button { infoProduct = product } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                        .multilineTextAlignment(.leading)
                    Text("\(product.brand) · \(product.price)")
                        .font(.caption)
                        .foregroundColor(.soft)
                    Text(product.effects.map(\.emoji).joined(separator: " "))
                        .font(.caption2)
                }
                Spacer(minLength: 8)
                if product.caution != nil {
                    Text("⚠︎")
                        .font(.footnote)
                        .foregroundColor(.roseDeep)
                }
                Button { store.toggleWishlist(product.id) } label: {
                    Image(systemName: store.isWishlisted(product.id) ? "heart.fill" : "heart")
                        .foregroundColor(.roseDeep)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shop product sheet

struct ShopProductSheet: View {
    let product: ShopProduct
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(product.name)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundColor(.ink)
                Text("\(product.brand.uppercased()) · \(product.tag.uppercased())")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.rose)
                HStack(spacing: 6) {
                    ForEach(product.effects) { effect in
                        Text("\(effect.emoji) \(effect.displayName)")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.roseTint))
                    }
                }
                infoBlock("What it is", product.what)
                infoBlock("Why it helps", product.why)
                infoBlock("Where it fits", product.order)
                if let caution = product.caution {
                    Text("⚠︎ \(caution)")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.roseDeep)
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.roseTint))
                }
                Button { store.toggleWishlist(product.id) } label: {
                    Text(store.isWishlisted(product.id) ? "On your list ♥" : "Add to list ♡")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(store.isWishlisted(product.id) ? Color.roseDeep : Color.rose))
                }
                .padding(.top, 4)
                if let url = Affiliate.url(for: product) {
                    Link(destination: url) {
                        Text("View at store \(product.price) ↗")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.roseDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().stroke(Color.roseDeep, lineWidth: 1.5))
                    }
                }
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

// MARK: - Wishlist

struct WishlistSheet: View {
    let catalog: [ShopProduct]
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var deletingID: String?

    private func product(for id: String) -> ShopProduct? {
        catalog.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Shopping list")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                        .padding(.top, 20)
                    if store.wishlist.isEmpty {
                        Text("Nothing saved yet — tap the ♡ on any product to keep it here for your next haul.")
                            .font(.subheadline)
                            .foregroundColor(.soft)
                            .padding(.vertical, 30)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.wishlist) { item in
                                if let p = product(for: item.productID) {
                                    wishlistRow(item: item, product: p)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Remove from your list?", isPresented: .init(
            get: { deletingID != nil }, set: { if !$0 { deletingID = nil } }
        ), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let id = deletingID { store.wishlist.removeAll { $0.productID == id } }
                deletingID = nil
            }
        }
    }

    private func wishlistRow(item: WishlistItem, product: ShopProduct) -> some View {
        HStack(spacing: 12) {
            Button { store.togglePurchased(product.id) } label: {
                Image(systemName: item.purchased ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.purchased ? .greenC : .faint)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(item.purchased ? .faint : .ink)
                    .strikethrough(item.purchased, color: .faint)
                Text("\(product.brand) · \(product.price)")
                    .font(.caption)
                    .foregroundColor(.soft)
            }
            Spacer(minLength: 8)
            if let url = Affiliate.url(for: product) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(.rose)
                }
            }
            Button { deletingID = product.id } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.faint)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
    }
}

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
    @State private var showQuiz = false
    @State private var selectedTier: RoutineTier = .budget
    @State private var presentedKit: RoutineKit?

    private let kits: [RoutineKit] = BundledKitCatalog().allKits()

    private var catalog: [ShopProduct] { store.shopProducts }

    private var productsByID: [String: ShopProduct] {
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }

    private var results: [ShopProduct] {
        var items = catalog
        if let targetCategory = store.shopAddTarget?.category {
            items = items.filter { $0.category == targetCategory }
        }
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

                    if let target = store.shopAddTarget {
                        addTargetBanner(target)
                    }

                    routinesSection

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
        .sheet(isPresented: $showQuiz) { QuizSheet(kits: kits, catalog: catalog) }
        .sheet(item: $presentedKit) { KitSheet(kit: $0, catalog: catalog) }
    }

    // MARK: Routines section

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let result = store.quizResult, let match = kits.first(where: { $0.id == result.kitID }) {
                Button { presentedKit = match } label: {
                    HStack(spacing: 12) {
                        Text("✨")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your match: \(match.title)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.ink)
                            Text("\(match.tier.emoji) \(match.tier.displayName) · tap to see your routine")
                                .font(.caption)
                                .foregroundColor(.soft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.faint)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.roseTint))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rose, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button { showQuiz = true } label: {
                    Text("Retake quiz")
                        .font(.caption.weight(.heavy))
                        .foregroundColor(.roseDeep)
                }
            } else {
                Button { showQuiz = true } label: {
                    HStack(spacing: 12) {
                        Text("✨")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Find your routine")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.ink)
                            Text("30-second quiz · skin type, goal, budget")
                                .font(.caption)
                                .foregroundColor(.soft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.faint)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.roseTint))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rose, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Text("Routine kits")
                .font(.caption.weight(.heavy))
                .foregroundColor(.soft)
                .padding(.top, 6)

            HStack(spacing: 8) {
                ForEach(RoutineTier.allCases) { tier in
                    let active = selectedTier == tier
                    Button { selectedTier = tier } label: {
                        Text("\(tier.emoji) \(tier.displayName)")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(active ? .white : .ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(active ? Color.rose : Color.white))
                            .overlay(Capsule().stroke(active ? Color.rose : Color.lineC, lineWidth: 1))
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(kits.filter { $0.tier == selectedTier }) { kit in
                        Button { presentedKit = kit } label: {
                            KitCard(kit: kit, products: productsByID)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 4)
    }

    private func addTargetBanner(_ target: ShopAddTarget) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Adding to \(target.routineTitle)")
                    .font(.footnote.weight(.heavy))
                    .foregroundColor(.roseDeep)
                Text(target.category.map { "Showing \($0.displayName.lowercased())s — tap one to add it" }
                     ?? "Tap a product to add it")
                    .font(.caption2)
                    .foregroundColor(.soft)
            }
            Spacer()
            Button {
                store.shopAddTarget = nil
            } label: {
                Text("Cancel")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.roseDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.roseTint))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.rose, lineWidth: 1))
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
        Button {
            if let target = store.shopAddTarget {
                store.addProduct(product.id, to: target.routineID)
                store.shopAddTarget = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                NotificationCenter.default.post(name: .openTodayTab, object: nil)
            } else {
                infoProduct = product
            }
        } label: {
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
    @State private var showRoutinePicker = false

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
            }
            .padding(24)
        }
        // Actions pinned below the scroll so every button is visible even at
        // the half-height detent (they used to scroll out of sight).
        .safeAreaInset(edge: .bottom) { actionFooter }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showRoutinePicker) {
            RoutinePickerSheet(productID: product.id)
        }
    }

    private var actionFooter: some View {
        VStack(spacing: 8) {
            Button { store.toggleWishlist(product.id) } label: {
                Text(store.isWishlisted(product.id) ? "On your list ♥" : "Add to list ♡")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(store.isWishlisted(product.id) ? Color.roseDeep : Color.rose))
            }
            HStack(spacing: 8) {
                Button { showRoutinePicker = true } label: {
                    Text("Add to routine ＋")
                        .font(.footnote.weight(.heavy))
                        .foregroundColor(.roseDeep)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().stroke(Color.roseDeep, lineWidth: 1.5))
                }
                if let url = Affiliate.url(for: product) {
                    Link(destination: url) {
                        Text("View at store \(product.price) ↗")
                            .font(.footnote.weight(.heavy))
                            .foregroundColor(.roseDeep)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().stroke(Color.roseDeep, lineWidth: 1.5))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            Rectangle().fill(Color.white)
                .overlay(Rectangle().fill(Color.lineC).frame(height: 1), alignment: .top)
                .ignoresSafeArea()
        )
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

// MARK: - Routine picker (add a shop product to a routine)

struct RoutinePickerSheet: View {
    let productID: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var addedTo: String?

    private let displayDayOrder = [1, 2, 3, 4, 5, 6, 0]
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add to which routine?")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                        .padding(.top, 20)
                    Text("It'll slot into the right spot automatically.")
                        .font(.caption)
                        .foregroundColor(.soft)
                    VStack(spacing: 8) {
                        ForEach(store.routines) { routine in
                            Button {
                                store.addProduct(productID, to: routine.id)
                                addedTo = routine.id
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(routine.emoji)
                                        .font(.title3)
                                        .frame(width: 38, height: 38)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(routine.theme.tint))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(routine.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.ink)
                                        HStack(spacing: 3) {
                                            ForEach(displayDayOrder, id: \.self) { d in
                                                Text(dayLetters[d])
                                                    .font(.system(size: 9, weight: .heavy))
                                                    .foregroundColor(routine.days.contains(d) ? routine.theme.accent : .faint)
                                            }
                                        }
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: addedTo == routine.id ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundColor(addedTo == routine.id ? .greenC : .rose)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(addedTo != nil)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

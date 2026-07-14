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
    @Environment(\.dismiss) private var dismiss

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
        .onReceive(NotificationCenter.default.publisher(for: .kitRoutinesBuilt)) { _ in
            dismiss() // routines built — get out of the way so Today shows them
        }
    }
}

/// Kit detail body — used inside KitSheet and inside the quiz result screen.
struct KitSheetContent: View {
    let kit: RoutineKit
    let catalog: [ShopProduct]
    @EnvironmentObject var store: AppStore
    @State private var infoProduct: ShopProduct?
    /// Drafts under review ride along with the sheet so a stale pair can't linger.
    private struct ReviewRequest: Identifiable {
        let drafts: [Routine]
        var id: String { drafts.map(\.id).joined() }
    }
    @State private var reviewRequest: ReviewRequest?

    private var products: [String: ShopProduct] {
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }
    private var resolvedIDs: [String] { store.resolvedProductIDs(for: kit) }
    private var allAdded: Bool { resolvedIDs.allSatisfy { store.isWishlisted($0) } }
    private var anySwapped: Bool { zip(kit.items, resolvedIDs).contains { $0.productID != $1 } }

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

            if anySwapped, let mine = store.quizResult?.skinType {
                Text("🌷 Swapped in picks matched to your \(mine.displayName.localizedLowercase) skin.")
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

            let built = store.hasKitRoutines(kit.id)
            Button {
                reviewRequest = ReviewRequest(drafts: store.draftKitRoutines(from: kit))
            } label: {
                Text(built ? "Routines created — see Today ✓" : "Build my routine ♡")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(built ? Color.greenC : Color.rose))
            }
            .disabled(built)

            Button {
                store.addKit(kit)
            } label: {
                Text(allAdded ? "All on your list ♥" : "Add all to shopping list ♡")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.roseDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().stroke(Color.roseDeep, lineWidth: 1.5))
            }
            .disabled(allAdded)
        }
        .sheet(item: $infoProduct) { ShopProductSheet(product: $0) }
        .sheet(item: $reviewRequest) { KitReviewSheet(drafts: $0.drafts) }
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
                    Text("\(product.brand) · \(product.price)\(swapped ? " · matched to you 🌷" : "")")
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

// MARK: - Kit review ("build my routine" confirmation)

/// Full-edit review of the two starter routines a kit drafts: rename them,
/// reorder, remove or add steps — nothing is created until the button says so.
struct KitReviewSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [Routine]

    init(drafts: [Routine]) {
        _drafts = State(initialValue: drafts)
    }

    private var canCreate: Bool {
        drafts.allSatisfy { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Review your rituals")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundColor(.ink)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(.roseDeep)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.roseTint))
                        }
                    }
                    .padding(.top, 20)

                    Text("Rename anything, drag to reorder, tap a step to tweak. Nothing is saved until you create them.")
                        .font(.subheadline)
                        .foregroundColor(.soft)

                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text(draft.emoji)
                                    .font(.title3)
                                    .frame(width: 38, height: 38)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(draft.theme.tint))
                                TextField("Routine name", text: $draft.title)
                                    .font(.system(.headline, design: .serif).weight(.semibold))
                                    .foregroundColor(.ink)
                                    .submitLabel(.done)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.lineC, lineWidth: 1))
                            }
                            StepListEditor(steps: $draft.steps, omitCoreCategories: draft.omitCoreCategories)
                        }
                        .padding(.top, 6)
                    }

                    Button {
                        create()
                    } label: {
                        Text("Create my rituals ♡")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(canCreate ? Color.rose : Color.faint))
                    }
                    .disabled(!canCreate)
                    .padding(.top, 8)

                    Text("Days, colors and photo check-ins can be changed anytime — tap the pencil on Today.")
                        .font(.caption)
                        .foregroundColor(.faint)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func create() {
        store.createRoutines(drafts)
        NotificationCenter.default.post(name: .kitRoutinesBuilt, object: nil)
        dismiss()
    }
}

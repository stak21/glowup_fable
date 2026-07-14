//  Explore.swift
//  Skill Journal
//
//  Plays the role GlowUp's Shop tab did: browse domain packs, take a pack's
//  quiz, read its education pages, build routines from its templates, and
//  keep a supplies list. Layout patterns carried over from the Shop views.

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var packStore: PackStore
    @State private var showSupplies = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Explore")
                                    .font(.system(.title2, design: .serif).weight(.semibold))
                                    .foregroundColor(.ink)
                                Text("Pick something to get better at — each pack brings routines, tips and supplies.")
                                    .font(.footnote)
                                    .foregroundColor(.soft)
                            }
                            Spacer()
                            Button { showSupplies = true } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "heart.text.square")
                                        .font(.title3)
                                        .foregroundColor(.roseDeep)
                                        .frame(width: 40, height: 40)
                                        .background(Circle().fill(Color.white.opacity(0.85)))
                                    if !store.wishlist.isEmpty {
                                        Text("\(store.wishlist.count)")
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Circle().fill(Color.rose))
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)

                        ForEach(packStore.packs) { pack in
                            NavigationLink {
                                PackDetailView(pack: pack)
                            } label: {
                                packRow(pack)
                            }
                            .buttonStyle(.plain)
                        }

                        if packStore.packs.isEmpty {
                            VStack(spacing: 10) {
                                Text("📦").font(.system(size: 32))
                                Text("No packs loaded")
                                    .font(.subheadline.weight(.semibold)).foregroundColor(.ink)
                                Text("Bundled packs are missing from this build.")
                                    .font(.caption).foregroundColor(.soft)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSupplies) { SuppliesSheet() }
    }

    private func packRow(_ pack: DomainPack) -> some View {
        HStack(spacing: 12) {
            Text(pack.emoji)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(pack.theme.tint))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(pack.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                    if packStore.isActive(pack.id) {
                        Text("Active")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.greenC))
                    }
                }
                Text(pack.tagline)
                    .font(.caption)
                    .foregroundColor(.soft)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(.faint)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white)
            .shadow(color: Color.rose.opacity(0.08), radius: 7, y: 3))
    }
}

// MARK: - Pack detail

struct PackDetailView: View {
    let pack: DomainPack
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var packStore: PackStore
    @State private var quizPresented = false
    @State private var educationPresented = false
    @State private var selectedTemplate: RoutineTemplate?
    @State private var infoProduct: ProductSelection?

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Text(pack.emoji)
                            .font(.system(size: 40))
                            .frame(width: 64, height: 64)
                            .background(RoundedRectangle(cornerRadius: 18).fill(pack.theme.tint))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pack.name)
                                .font(.system(.title2, design: .serif).weight(.semibold))
                                .foregroundColor(.ink)
                            Text(pack.tagline)
                                .font(.footnote)
                                .foregroundColor(.soft)
                        }
                    }
                    .padding(.top, 8)

                    if !packStore.isActive(pack.id) {
                        Button {
                            packStore.activate(pack.id)
                        } label: {
                            Text("Add to my journal ♡")
                                .font(.subheadline.weight(.heavy))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(Color.rose))
                        }
                    }

                    if let quiz = pack.quiz, !pack.templates.isEmpty {
                        Button {
                            quizPresented = true
                        } label: {
                            HStack(spacing: 12) {
                                Text("✨").font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Find my starting point")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.ink)
                                    Text("\(quiz.questions.count) quick questions → a recommended routine")
                                        .font(.caption)
                                        .foregroundColor(.soft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.faint)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    if let pages = pack.educationPages, !pages.isEmpty {
                        Button {
                            educationPresented = true
                        } label: {
                            HStack(spacing: 12) {
                                Text("📖").font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(pack.name) 101")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.ink)
                                    Text("The basics, in \(pages.count) short pages")
                                        .font(.caption)
                                        .foregroundColor(.soft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.faint)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    if !pack.templates.isEmpty {
                        Text("STARTER ROUTINES")
                            .font(.caption2.weight(.heavy))
                            .foregroundColor(.soft)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(pack.templates) { template in
                                    Button { selectedTemplate = template } label: {
                                        TemplateCard(template: template)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if let products = pack.products, !products.isEmpty {
                        Text("SUPPLIES")
                            .font(.caption2.weight(.heavy))
                            .foregroundColor(.soft)
                        VStack(spacing: 8) {
                            ForEach(products) { product in
                                productRow(product)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $quizPresented) {
            if let quiz = pack.quiz {
                PackQuizSheet(pack: pack, quiz: quiz)
            }
        }
        .sheet(isPresented: $educationPresented) {
            if let pages = pack.educationPages {
                EducationView(pack: pack, pages: pages)
            }
        }
        .sheet(item: $selectedTemplate) { template in
            TemplateSheet(template: template, pack: pack)
        }
        .sheet(item: $infoProduct) { ProductSheet(selection: $0) }
    }

    private func productRow(_ product: PackProduct) -> some View {
        Button {
            infoProduct = ProductSelection(
                productID: product.id,
                product: ProductInfo(name: product.name, tag: product.tag, what: product.what,
                                     why: product.why, order: product.order, caution: product.caution))
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                        .multilineTextAlignment(.leading)
                    Text(product.tag)
                        .font(.caption)
                        .foregroundColor(.soft)
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
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supplies list (GlowUp's wishlist, over pack products)

struct SuppliesSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var deletingID: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Supplies list")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                        .padding(.top, 20)
                    if store.wishlist.isEmpty {
                        Text("Nothing saved yet — tap the ♡ on any supply to keep it here for your next shop.")
                            .font(.subheadline)
                            .foregroundColor(.soft)
                            .padding(.vertical, 30)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.wishlist) { item in
                                if let p = store.packs.product(item.productID) {
                                    suppliesRow(item: item, product: p)
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

    private func suppliesRow(item: WishlistItem, product: PackProduct) -> some View {
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
                Text(product.tag)
                    .font(.caption)
                    .foregroundColor(.soft)
            }
            Spacer(minLength: 8)
            if let url = product.url {
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

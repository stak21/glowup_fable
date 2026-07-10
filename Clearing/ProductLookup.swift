//  ProductLookup.swift
//  Clearing

import SwiftUI

// MARK: - Product lookup

struct ProductLookupView: View {
    @State private var query = ""
    @State private var infoProduct: Product?

    private var results: [Product] {
        let all = Catalog.products.values.sorted { $0.name < $1.name }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(q)
            || $0.tag.localizedCaseInsensitiveContains(q)
            || $0.what.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Products")
                        .font(.system(.largeTitle, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                        .padding(.top, 8)

                    searchField

                    if results.isEmpty {
                        Text("No products match “\(query)”")
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
        .sheet(item: $infoProduct) { ProductSheet(product: $0) }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.faint)
            TextField("Search name or ingredient", text: $query)
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

    private func productRow(_ product: Product) -> some View {
        Button { infoProduct = product } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.ink)
                    Text(product.tag)
                        .font(.caption)
                        .foregroundColor(.soft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if product.caution != nil {
                    Text("⚠︎")
                        .font(.footnote)
                        .foregroundColor(.roseDeep)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.faint)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lineC, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

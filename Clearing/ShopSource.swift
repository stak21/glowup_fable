//  ShopSource.swift
//  Clearing

import Foundation

// MARK: - Shop catalog source

// Future remote/API catalogs conform to this and swap in behind ShopView.
protocol ShopProductSource {
    func allProducts() -> [ShopProduct]
}

struct BundledShopCatalog: ShopProductSource {
    func allProducts() -> [ShopProduct] {
        guard let url = Bundle.main.url(forResource: "ShopCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let products = try? JSONDecoder().decode([ShopProduct].self, from: data)
        else { return [] }
        return products.sorted { $0.name < $1.name }
    }
}

// MARK: - Affiliate links

enum Affiliate {
    /// Set to your Associates tag (e.g. "clearing-20") once the account exists.
    static let amazonTag: String? = "glowup02f6-20"

    static func url(for product: ShopProduct) -> URL? {
        guard let url = product.storeURL else { return nil }
        guard let tag = amazonTag, url.host?.contains("amazon") == true else { return url }
        var withTag = url
        withTag.append(queryItems: [URLQueryItem(name: "tag", value: tag)])
        return withTag
    }
}

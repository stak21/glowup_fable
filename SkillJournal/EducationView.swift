//  EducationView.swift
//  Skill Journal
//
//  Pack education pages — the paged-card shell of GlowUp's Skincare 101,
//  rendering whatever pages the pack ships.

import SwiftUI

struct EducationView: View {
    let pack: DomainPack
    let pages: [EducationPage]
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(pack.name) 101")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("A quick tour of the basics before you start.")
                        .font(.subheadline)
                        .foregroundColor(.soft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, p in
                        pageCard(p)
                            .padding(.horizontal, 24)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.rose : Color.faint.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }

                Button {
                    if isLast {
                        dismiss()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                    }
                } label: {
                    Text(isLast ? "Got it ♡" : "Next")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(Color.rose))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func pageCard(_ p: EducationPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(p.emoji)
                    .font(.system(size: 44))
                Text(p.title)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundColor(.ink)
                Text(p.body)
                    .font(.subheadline)
                    .foregroundColor(.ink)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))
        }
    }
}

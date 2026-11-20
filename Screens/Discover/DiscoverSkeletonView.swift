//
//  DiscoverSkeletonView.swift
//  Re-Hearse_v1
//
//  Skeleton overlay for DiscoverViewController.
//  Mirrors: search bar, filter buttons, 8 song rows.
//

import UIKit

final class DiscoverSkeletonView: SkeletonContainerView {

    /// Where the real search bar starts; the Library header above it stays visible.
    private static let contentTop: CGFloat = 194

    override init() {
        super.init()
        // Only the area below the header is covered, and touches pass through to the header.
        backgroundColor = .clear
        isUserInteractionEnabled = false
        let cover = UIView()
        cover.backgroundColor = ComponentColors.DiscoverScreen.background
        cover.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cover)
        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: topAnchor, constant: Self.contentTop - 8),
            cover.leadingAnchor.constraint(equalTo: leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: trailingAnchor),
            cover.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Self.contentTop),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])

        // Search bar placeholder
        stack.addArrangedSubview(SkeletonBox(height: 44, cornerRadius: 22))

        // Filter row
        stack.addArrangedSubview(makeFilterRow())

        // "Songs" title placeholder
        stack.addArrangedSubview(makeLabel())

        // 8 song rows
        for _ in 0..<8 {
            stack.addArrangedSubview(makeSongRow())
        }
    }

    private func makeFilterRow() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let btn1 = SkeletonBox(height: 44, cornerRadius: 14)
        btn1.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let btn2 = SkeletonBox(height: 44, cornerRadius: 14)
        btn2.widthAnchor.constraint(equalToConstant: 112).isActive = true
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(btn1)
        row.addArrangedSubview(btn2)
        row.addArrangedSubview(spacer)
        return row
    }

    private func makeLabel() -> UIView {
        let box = SkeletonBox(height: 18, cornerRadius: 9)
        box.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(box)
        wrapper.heightAnchor.constraint(equalToConstant: 24).isActive = true
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            box.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
        ])
        return wrapper
    }

    private func makeSongRow() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 72).isActive = true

        // Cover art
        let thumb = SkeletonBox(height: nil, cornerRadius: 10)
        thumb.widthAnchor.constraint(equalToConstant: 58).isActive = true
        thumb.heightAnchor.constraint(equalToConstant: 58).isActive = true

        // Title, composer and the level/tempo/hands tags
        let text = SkeletonLineGroup(lines: 3, lineHeight: 12, spacing: 8, lastLineWidthRatio: 0.7)

        row.addArrangedSubview(thumb)
        row.addArrangedSubview(text)
        return row
    }
}

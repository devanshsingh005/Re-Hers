//
//  DiscoverSkeletonView.swift
//  Re-Hearse_v1
//
//  Skeleton overlay for DiscoverViewController.
//  Mirrors: search bar, filter buttons, 8 song rows.
//

import UIKit

final class DiscoverSkeletonView: SkeletonContainerView {

    override init() {
        super.init()
        backgroundColor = ComponentColors.DiscoverScreen.background
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
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 180), // below nav + header
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])

        // Search bar placeholder
        stack.addArrangedSubview(SkeletonBox(height: 46, cornerRadius: 14))

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
        row.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let btn1 = SkeletonBox(height: 40, cornerRadius: 14)
        btn1.widthAnchor.constraint(equalToConstant: 100).isActive = true
        let btn2 = SkeletonBox(height: 40, cornerRadius: 14)
        btn2.widthAnchor.constraint(equalToConstant: 100).isActive = true
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

        // Album art thumbnail
        let thumb = SkeletonBox(height: nil, cornerRadius: 10)
        thumb.widthAnchor.constraint(equalToConstant: 54).isActive = true
        thumb.heightAnchor.constraint(equalToConstant: 54).isActive = true

        // Title + composer lines
        let text = SkeletonLineGroup(lines: 2, lineHeight: 13, spacing: 6)

        // Duration pill
        let dur = SkeletonBox(height: 24, cornerRadius: 12)
        dur.widthAnchor.constraint(equalToConstant: 42).isActive = true

        row.addArrangedSubview(thumb)
        row.addArrangedSubview(text)
        row.addArrangedSubview(dur)
        return row
    }
}

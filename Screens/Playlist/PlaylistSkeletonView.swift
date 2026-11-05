//
//  PlaylistSkeletonView.swift
//  Re-Hearse_v1
//
//  Skeleton for MainPlayListScreen — 2×3 card grid.
//

import UIKit

final class PlaylistSkeletonView: SkeletonContainerView {

    override init() {
        super.init()
        backgroundColor = ComponentColors.HomeScreen.background
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])

        // Title placeholder
        let title = SkeletonBox(height: 18, cornerRadius: 9)
        title.widthAnchor.constraint(equalToConstant: 140).isActive = true
        let titleWrapper = UIStackView(arrangedSubviews: [title])
        stack.addArrangedSubview(titleWrapper)

        // 2 rows of 3 cards each
        for _ in 0..<2 {
            stack.addArrangedSubview(makeCardRow())
        }

        // Below playlists: "Your Uploads" section label + 3 rows
        let uploadsLabel = SkeletonBox(height: 16, cornerRadius: 8)
        uploadsLabel.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let labWrapper = UIStackView(arrangedSubviews: [uploadsLabel])
        stack.addArrangedSubview(labWrapper)
        for _ in 0..<3 {
            stack.addArrangedSubview(makeUploadRow())
        }
    }

    private func makeCardRow() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 12
        row.heightAnchor.constraint(equalToConstant: 140).isActive = true

        for _ in 0..<3 {
            let card = UIStackView()
            card.axis = .vertical
            card.spacing = 8

            let image = SkeletonBox(height: nil, cornerRadius: 12)
            image.heightAnchor.constraint(equalToConstant: 100).isActive = true
            let label = SkeletonBox(height: 12, cornerRadius: 6)

            card.addArrangedSubview(image)
            card.addArrangedSubview(label)
            row.addArrangedSubview(card)
        }
        return row
    }

    private func makeUploadRow() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.heightAnchor.constraint(equalToConstant: 68).isActive = true

        let thumb = SkeletonBox(height: nil, cornerRadius: 10)
        thumb.widthAnchor.constraint(equalToConstant: 48).isActive = true
        thumb.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let text = SkeletonLineGroup(lines: 2, lineHeight: 12, spacing: 6)
        let chevron = SkeletonBox(height: 16, cornerRadius: 8)
        chevron.widthAnchor.constraint(equalToConstant: 10).isActive = true

        row.addArrangedSubview(thumb)
        row.addArrangedSubview(text)
        row.addArrangedSubview(chevron)
        return row
    }
}

//
//  HomeSkeletonView.swift
//  Re-Hearse_v1
//
//  Skeleton overlay for HomeViewController.
//  Mirrors: hero card, playlist row (3 cards), recents (4 rows), header avatar.
//

import UIKit

final class HomeSkeletonView: SkeletonContainerView {

    // MARK: Init
    override init() {
        super.init()
        backgroundColor = ComponentColors.HomeScreen.background
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Build
    private func build() {
        let scrollView = UIScrollView()
        scrollView.isScrollEnabled = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.topAnchor.constraint(equalTo: scrollView.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 110),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
        ])

        // Header row: avatar circle + subtitle line
        stack.addArrangedSubview(makeHeaderSkeleton())

        // Hero card
        stack.addArrangedSubview(makeHeroCardSkeleton())

        // Playlist section
        stack.addArrangedSubview(makeSectionLabel())
        stack.addArrangedSubview(makePlaylistRowSkeleton())

        // Recents section
        stack.addArrangedSubview(makeSectionLabel())
        for _ in 0..<4 {
            stack.addArrangedSubview(makeRecentRowSkeleton())
        }
    }

    // MARK: Pieces

    private func makeHeaderSkeleton() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let lines = SkeletonLineGroup(lines: 2, lineHeight: 13, spacing: 6)
        let avatar = SkeletonCircle(diameter: 40)

        // Lines fill available space, avatar fixed on right
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        row.addArrangedSubview(lines)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(avatar)

        row.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return row
    }

    private func makeHeroCardSkeleton() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = SkeletonTokens.base
        card.layer.cornerRadius = 20

        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        inner.addArrangedSubview(SkeletonBox(height: 18, cornerRadius: 9))
        inner.addArrangedSubview(SkeletonBox(height: 14, cornerRadius: 7))
        let tagsRow = makeHorizontalRow(widths: [70, 70])
        inner.addArrangedSubview(tagsRow)
        inner.addArrangedSubview(SkeletonBox(height: 44, cornerRadius: 14))

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 200),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
        return card
    }

    private func makePlaylistRowSkeleton() -> UIView {
        let sv = UIScrollView()
        sv.isScrollEnabled = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        sv.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: sv.topAnchor),
            stack.leadingAnchor.constraint(equalTo: sv.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: sv.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: sv.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: sv.heightAnchor),
        ])

        for _ in 0..<3 {
            let card = SkeletonBox(height: nil, cornerRadius: 16)
            card.widthAnchor.constraint(equalToConstant: 130).isActive = true
            stack.addArrangedSubview(card)
        }
        return sv
    }

    private func makeRecentRowSkeleton() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 68).isActive = true

        // Thumbnail
        let thumb = SkeletonBox(height: nil, cornerRadius: 12)
        thumb.widthAnchor.constraint(equalToConstant: 52).isActive = true
        thumb.heightAnchor.constraint(equalToConstant: 52).isActive = true

        // Text
        let textStack = SkeletonLineGroup(lines: 2, lineHeight: 13, spacing: 6)

        // Play button
        let play = SkeletonCircle(diameter: 30)

        row.addArrangedSubview(thumb)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(play)

        // Wrap in a card
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = SkeletonTokens.base.withAlphaComponent(0.6)
        card.layer.cornerRadius = 16
        card.addSubview(row)
        card.heightAnchor.constraint(equalToConstant: 80).isActive = true
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    private func makeSectionLabel() -> UIView {
        let box = SkeletonBox(height: 16, cornerRadius: 8)
        box.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(box)
        wrapper.heightAnchor.constraint(equalToConstant: 22).isActive = true
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            box.centerYAnchor.constraint(equalTo: wrapper.centerYAnchor),
        ])
        return wrapper
    }

    private func makeHorizontalRow(widths: [CGFloat]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        for w in widths {
            let box = SkeletonBox(height: 28, cornerRadius: 14)
            box.widthAnchor.constraint(equalToConstant: w).isActive = true
            row.addArrangedSubview(box)
        }
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
        return row
    }
}

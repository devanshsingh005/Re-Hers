//
//  PDFSkeletonView.swift
//  Re-Hearse_v1
//
//  Reusable skeleton for PDF-based screens:
//    • DiscoverSongDetailViewController  (replaces pdfLoadingIndicator)
//    • SongDetailsPage (Playlist)        (replaces loadingIndicator)
//    • PlayAlongViewController           (replaces loadingView blur overlay)
//
//  Displays a score-sheet pattern: alternating title block + staff lines.
//

import UIKit

final class PDFSkeletonView: SkeletonContainerView {

    override init() {
        super.init()
        // Transparent container — the page card below provides the visible background
        backgroundColor = .clear
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let page = UIView()
        page.translatesAutoresizingMaskIntoConstraints = false
        page.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicCardFill
        page.layer.cornerRadius = 12
        page.layer.masksToBounds = true
        addSubview(page)

        NSLayoutConstraint.activate([
            page.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            page.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            page.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            page.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: page.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -24),
        ])

        // Repeat 4 musical stave groups
        for _ in 0..<4 {
            stack.addArrangedSubview(makeStaveGroup())
        }
    }

    /// One stave group = title line + 5 staff lines
    private func makeStaveGroup() -> UIView {
        let group = UIStackView()
        group.axis = .vertical
        group.spacing = 10
        group.translatesAutoresizingMaskIntoConstraints = false

        // Title / clef placeholder
        let title = SkeletonBox(height: 12, cornerRadius: 6)
        title.widthAnchor.constraint(equalToConstant: 120).isActive = true
        group.addArrangedSubview(title)

        // 5 staff lines — alternating thin/thick
        for i in 0..<5 {
            let line = SkeletonBox(height: i.isMultiple(of: 2) ? 3 : 2, cornerRadius: 1)
            group.addArrangedSubview(line)
        }

        // Notes row: short boxes representing note heads
        let notesRow = UIStackView()
        notesRow.axis = .horizontal
        notesRow.spacing = 14
        for _ in 0..<6 {
            let note = SkeletonBox(height: 8, cornerRadius: 4)
            note.widthAnchor.constraint(equalToConstant: CGFloat.random(in: 16...32)).isActive = true
            notesRow.addArrangedSubview(note)
        }
        let filler = UIView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        notesRow.addArrangedSubview(filler)
        group.addArrangedSubview(notesRow)

        return group
    }
}

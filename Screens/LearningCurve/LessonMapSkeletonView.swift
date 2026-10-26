//
//  LessonMapSkeletonView.swift
//  Re-Hearse_v1
//
//  Skeleton for L1ViewController (lesson map screen).
//  Shows a branching path of shimmering lesson node circles.
//

import UIKit

final class LessonMapSkeletonView: SkeletonContainerView {

    override init() {
        super.init()
        backgroundColor = ComponentColors.HomeScreen.background
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        // Title placeholder
        let title = SkeletonBox(height: 22, cornerRadius: 11)
        title.widthAnchor.constraint(equalToConstant: 160).isActive = true
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 24),
            title.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])

        // Node path — zigzag layout
        let nodeSize: CGFloat = 52
        let nodeRadius: CGFloat = nodeSize / 2
        let verticalGap: CGFloat = 80
        let horizontalOffset: CGFloat = 80

        let nodeCount = 7
        var previousNode: UIView?

        for i in 0..<nodeCount {
            // Alternate left / centre / right pattern
            let xOffset: CGFloat
            switch i % 3 {
            case 0: xOffset = 0
            case 1: xOffset = horizontalOffset
            default: xOffset = -horizontalOffset
            }

            let node = makeNode(diameter: nodeSize, cornerRadius: nodeRadius)
            addSubview(node)

            NSLayoutConstraint.activate([
                node.widthAnchor.constraint(equalToConstant: nodeSize),
                node.heightAnchor.constraint(equalToConstant: nodeSize),
                node.centerXAnchor.constraint(equalTo: centerXAnchor, constant: xOffset),
                node.topAnchor.constraint(
                    equalTo: previousNode?.bottomAnchor ?? title.bottomAnchor,
                    constant: i == 0 ? 40 : verticalGap - nodeSize
                ),
            ])

            // Connecting line between nodes
            if let prev = previousNode {
                let connector = SkeletonBox(height: verticalGap - nodeSize, cornerRadius: 3)
                connector.widthAnchor.constraint(equalToConstant: 4).isActive = true
                addSubview(connector)
                NSLayoutConstraint.activate([
                    connector.centerXAnchor.constraint(equalTo: centerXAnchor),
                    connector.topAnchor.constraint(equalTo: prev.bottomAnchor),
                    connector.bottomAnchor.constraint(equalTo: node.topAnchor),
                ])
            }

            // Star row below node
            let stars = makeStarRow()
            addSubview(stars)
            NSLayoutConstraint.activate([
                stars.centerXAnchor.constraint(equalTo: node.centerXAnchor),
                stars.topAnchor.constraint(equalTo: node.bottomAnchor, constant: 4),
            ])

            previousNode = node
        }
    }

    private func makeNode(diameter: CGFloat, cornerRadius: CGFloat) -> UIView {
        let outer = UIView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        outer.backgroundColor = SkeletonTokens.shine
        outer.layer.cornerRadius = cornerRadius

        let inner = SkeletonBox(height: diameter - 8, cornerRadius: cornerRadius - 4)
        inner.layer.cornerRadius = (diameter - 8) / 2
        outer.addSubview(inner)

        NSLayoutConstraint.activate([
            inner.centerXAnchor.constraint(equalTo: outer.centerXAnchor),
            inner.centerYAnchor.constraint(equalTo: outer.centerYAnchor),
            inner.widthAnchor.constraint(equalToConstant: diameter - 8),
        ])
        return outer
    }

    private func makeStarRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<3 {
            let star = SkeletonBox(height: 10, cornerRadius: 5)
            star.widthAnchor.constraint(equalToConstant: 10).isActive = true
            row.addArrangedSubview(star)
        }
        return row
    }
}

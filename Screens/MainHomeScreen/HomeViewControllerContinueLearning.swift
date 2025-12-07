//
//  HomeViewControllerContinueLearning.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
//
//  HomeViewController+ContinueLearning.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {
    
    // MARK: - Continue Learning Section
    func addContinueLearningSection() {
        let sectionHeader = UILabel()
        sectionHeader.text = "Continue Learning"
        sectionHeader.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionHeader.textColor = .darkGray1

        contentView.addArrangedSubview(sectionHeader)

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        contentView.addArrangedSubview(scrollView)
        scrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 14
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        let imageNames = ["cl_5", "cl_4", "ride_home", "cl_1", "cl_2"]
        imageNames.forEach {
            stackView.addArrangedSubview(createImageCard(imageName: $0, title: getTitleForImage($0)))
        }
    }

    // MARK: - Image Card
     func createImageCard(imageName: String, title: String) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 12
        card.clipsToBounds = true
        
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .appBackground
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor(white: 0, alpha: 0.7)
        
        card.addSubview(imageView)
        card.addSubview(titleLabel)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 140),
            card.heightAnchor.constraint(equalToConstant: 160),
            
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return card
    }

    // MARK: - Image Title Resolver
    func getTitleForImage(_ name: String) -> String {
        let titles: [String: String] = [
            "arrival": "The Arrival",
            "meridian": "Meridian",
            "classic": "Classic Suite",
            "fur_elise": "Fur Elise",
            "nocturne": "Nocturne",
            "sonata": "Moonlight Sonata",
            "prelude": "Prelude",
            "rhapsody": "Rhapsody"
        ]
        return titles[name] ?? name.capitalized
    }
}


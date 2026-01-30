//
//  HomeViewControllerContinueCard.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
//
//  HomeViewController+ContinueCard.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {
    
    
    // MARK: - Padded Label Class
    final class PaddingLabel: UILabel {
        
        private var topInset: CGFloat
        private var leftInset: CGFloat
        private var bottomInset: CGFloat
        private var rightInset: CGFloat
        
        init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
            self.topInset = top
            self.leftInset = left
            self.bottomInset = bottom
            self.rightInset = right
            super.init(frame: .zero)
        }
        
        required init?(coder: NSCoder) {
            self.topInset = 4
            self.leftInset = 8
            self.bottomInset = 4
            self.rightInset = 8
            super.init(coder: coder)
        }
        
        override func drawText(in rect: CGRect) {
            let insetRect = rect.inset(by: UIEdgeInsets(
                top: topInset,
                left: leftInset,
                bottom: bottomInset,
                right: rightInset
            ))
            super.drawText(in: insetRect)
        }
        
        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(
                width: size.width + leftInset + rightInset,
                height: size.height + topInset + bottomInset
            )
        }
    }
    
    // MARK: - Tag Label Factory
    func createTagLabel(_ text: String) -> UILabel {
        let label = PaddingLabel(top: 4, left: 10, bottom: 4, right: 10)
        label.text = text
        label.textColor = .black
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    // MARK: - Main Card Builder
    func addContinueCard() {
        let card = UIView()
        card.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        card.layer.cornerRadius = 22
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // Image
        let image = UIImageView()
        image.image = UIImage(named: "ride_home") ?? UIImage(systemName: "music.note")
        image.layer.cornerRadius = 10
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.translatesAutoresizingMaskIntoConstraints = false
        
        // Title + Subtitle
        let title = UILabel()
        title.text = "Continue: Ride Home"
        title.textColor = .white
        title.font = .systemFont(ofSize: 19, weight: .bold)
        
        let subtitle = UILabel()
        subtitle.text = "Bars 5–6 | Right-Hand focus"
        subtitle.textColor = .lightGray
        subtitle.font = .systemFont(ofSize: 13)
        
        let titleStack = UIStackView(arrangedSubviews: [title, subtitle])
        titleStack.axis = .vertical
        titleStack.spacing = 4
        titleStack.alignment = .leading
        
        let topRow = UIStackView(arrangedSubviews: [image, titleStack])
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.alignment = .top
        
        // Progress
        let progressView = UIProgressView()
        progressView.progress = 0.4
        progressView.progressTintColor = .appBackground
        progressView.trackTintColor = .darkGray1
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.heightAnchor.constraint(equalToConstant: 4).isActive = true
        
        // Buttons
        let continueBtn = createFilledButton("Continue")
        continueBtn.addTarget(self, action: #selector(openPianoPage), for: .touchUpInside)
        
        let playBtn = createBorderedButton("Play Along")
        playBtn.addTarget(self, action: #selector(playAlongTapped), for: .touchUpInside)
        
        continueBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        
        let buttonStack = UIStackView(arrangedSubviews: [continueBtn, playBtn])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
        // Main Stack
        let mainStack = UIStackView(arrangedSubviews: [
            topRow,
            progressView,
            buttonStack
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 0
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        mainStack.setCustomSpacing(18, after: topRow)
        mainStack.setCustomSpacing(22, after: progressView)
        
        card.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            mainStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            
            image.widthAnchor.constraint(equalToConstant: 80),
            image.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        contentView.addArrangedSubview(card)
    }
}

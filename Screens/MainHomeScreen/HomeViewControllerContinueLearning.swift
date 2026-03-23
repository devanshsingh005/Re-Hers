//
//  HomeViewControllerContinueLearning.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    func addPlaylistSection() {
        contentView.addArrangedSubview(makeSectionHeader("Your Playlist", action: {}))
    }

    // MARK: - Build Your Basics
    func addBuildYourBasicsSection() {
        contentView.addArrangedSubview(makeSectionHeader("Build your basics"))
        contentView.setCustomSpacing(12, after: contentView.arrangedSubviews.last!)

        // ── Cream card ──
        let card = UIView()
        card.backgroundColor   = ComponentColors.SongCard.background
        card.layer.cornerRadius = 20
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let headingLabel = UILabel()
        headingLabel.text          = "Start from\nthe basics"
        headingLabel.font          = .systemFont(ofSize: 20, weight: .bold)
        headingLabel.textColor     = ComponentColors.SongCard.titleText
        headingLabel.numberOfLines = 2

        let subtitleLabel = UILabel()
        subtitleLabel.text      = "Scales · Chords · Rhythm"
        subtitleLabel.font      = .systemFont(ofSize: 12)
        subtitleLabel.textColor = ComponentColors.SongCard.metadataText

        // Orange pill button
        let discoverBg = UIView()
        discoverBg.backgroundColor   = ComponentColors.HomeScreen.actionButtonFill
        discoverBg.layer.cornerRadius = 14
        discoverBg.layer.masksToBounds = true

        let discoverLabel = UILabel()
        discoverLabel.text      = "Discover →"
        discoverLabel.font      = .systemFont(ofSize: 12, weight: .semibold)
        discoverLabel.textColor = .white
        discoverLabel.translatesAutoresizingMaskIntoConstraints = false
        discoverBg.addSubview(discoverLabel)
        NSLayoutConstraint.activate([
            discoverLabel.topAnchor.constraint(equalTo: discoverBg.topAnchor, constant: 6),
            discoverLabel.bottomAnchor.constraint(equalTo: discoverBg.bottomAnchor, constant: -6),
            discoverLabel.leadingAnchor.constraint(equalTo: discoverBg.leadingAnchor, constant: 14),
            discoverLabel.trailingAnchor.constraint(equalTo: discoverBg.trailingAnchor, constant: -14),
        ])

        let leftStack = UIStackView(arrangedSubviews: [headingLabel, subtitleLabel, discoverBg])
        leftStack.axis      = .vertical
        leftStack.spacing   = 4
        leftStack.alignment = .leading
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.setCustomSpacing(14, after: subtitleLabel)

        // Orange icon tile
        let iconTile = UIView()
        iconTile.backgroundColor   = ComponentColors.HomeScreen.actionButtonFill
        iconTile.layer.cornerRadius = 14
        iconTile.layer.masksToBounds = true
        iconTile.translatesAutoresizingMaskIntoConstraints = false

        let iconImage = UIImageView(image: UIImage(systemName: "pianokeys"))
        iconImage.tintColor     = .white
        iconImage.contentMode   = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconTile.addSubview(iconImage)

        NSLayoutConstraint.activate([
            iconTile.widthAnchor.constraint(equalToConstant: 62),
            iconTile.heightAnchor.constraint(equalToConstant: 62),
            iconImage.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 28),
            iconImage.heightAnchor.constraint(equalToConstant: 28),
        ])

        card.addSubview(leftStack)
        card.addSubview(iconTile)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 110),

            leftStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            leftStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            leftStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: iconTile.leadingAnchor, constant: -10),

            iconTile.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            iconTile.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(buildBasicsTapped))
        card.addGestureRecognizer(tap); card.isUserInteractionEnabled = true
        contentView.addArrangedSubview(card)
    }

    @objc private func buildBasicsTapped() {
        tabBarController?.selectedIndex = 2
    }

    // MARK: - Continue Playing
    func addContinueLearningSection() {
        contentView.addArrangedSubview(makeSectionHeader("Continue playing"))
        contentView.setCustomSpacing(12, after: contentView.arrangedSubviews.last!)

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.clipsToBounds = false
        contentView.addArrangedSubview(scrollView)
        scrollView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        let stackView = UIStackView()
        stackView.axis = .horizontal; stackView.spacing = 16
        self.playlistStackView = stackView // save for async population
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    func createPlaylistCard(playlist: Playlist, imageName: String) -> UIView {
        let size: CGFloat = 136
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.translatesAutoresizingMaskIntoConstraints = false

        if let url = playlist.coverImageURL {
            ImageLoader.shared.loadImage(from: url) { [weak imageView] img in
                if let img = img {
                    imageView?.image = img
                }
            }
        }

        let titleLabel = UILabel()
        titleLabel.text = playlist.name
        titleLabel.textColor = ComponentColors.SongCard.titleText
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let tracksLabel = UILabel()
        tracksLabel.text = playlist.description ?? "0 TRACKS"
        tracksLabel.textColor = ComponentColors.SongCard.metadataText
        tracksLabel.font = .systemFont(ofSize: 10, weight: .medium)
        tracksLabel.translatesAutoresizingMaskIntoConstraints = false

        wrapper.addSubview(imageView)
        wrapper.addSubview(titleLabel)
        wrapper.addSubview(tracksLabel)

        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: size),

            imageView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: size),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),

            tracksLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            tracksLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            tracksLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            tracksLabel.bottomAnchor.constraint(lessThanOrEqualTo: wrapper.bottomAnchor)
        ])
        return wrapper
    }

    func addRecentsSection() {
        contentView.addArrangedSubview(makeSectionHeader("Recents", action: { [weak self] in
            let vc = AllRecentsViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        contentView.setCustomSpacing(12, after: contentView.arrangedSubviews.last!)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.recentsStackView = stack
        contentView.addArrangedSubview(stack)

        // Placeholder shown until data arrives
        let placeholder = UILabel()
        placeholder.text = "Play a song to see your recents here!"
        placeholder.font = .systemFont(ofSize: 14, weight: .medium)
        placeholder.textColor = .gray
        placeholder.textAlignment = .center
        placeholder.tag = 999
        stack.addArrangedSubview(placeholder)

        // Bottom spacer to ensure scrolling above tab bar doesn't cut off recents block
        let bottomSpacer = UIView()
        bottomSpacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        contentView.addArrangedSubview(bottomSpacer)
    }

    func createRecentRow(song: Song, timeAgo: String, imageName: String) -> UIView {
        let cardBgColor = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : .white }
        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(named: imageName) ?? UIImage(named: "trackimage_1"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = song.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = ComponentColors.SongCard.titleText
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "\(song.composer) • \(timeAgo)"
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = ComponentColors.SongCard.metadataText
        
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical; textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let playBtn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        playBtn.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: config), for: .normal)
        playBtn.tintColor = ComponentColors.HomeScreen.actionButtonFill
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(imageView)
        card.addSubview(textStack)
        card.addSubview(playBtn)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 80),
            
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            imageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 52),
            imageView.heightAnchor.constraint(equalToConstant: 52),
            
            textStack.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: playBtn.leadingAnchor, constant: -10),
            
            playBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            playBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            playBtn.widthAnchor.constraint(equalToConstant: 32),
            playBtn.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return card
    }
}

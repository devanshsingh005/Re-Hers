//
//  HomeViewControllerContinueLearning.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    func addPlaylistSection() {
        contentView.addArrangedSubview(makeSectionHeader("Your Playlist", action: {}))
        contentView.setCustomSpacing(8, after: contentView.arrangedSubviews.last!)

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
        let wrapper = UIButton(type: .custom)
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.layer.borderWidth = 1.0
        imageView.layer.borderColor = ComponentColors.SongCard.border.cgColor
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
        
        wrapper.addAction(UIAction { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            NavigationBarHelper.animateButtonPress(wrapper) {
                // Future: Navigate to playlist
            }
        }, for: .touchUpInside)
        
        return wrapper
    }

    func addRecentsSection() {
        contentView.addArrangedSubview(makeSectionHeader("Recents", action: { [weak self] in
            guard let self = self else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let vc = AllRecentsViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        contentView.setCustomSpacing(8, after: contentView.arrangedSubviews.last!)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.recentsStackView = stack
        contentView.addArrangedSubview(stack)

        // Placeholder shown until data arrives
        let placeholder = UILabel()
        placeholder.text = "Play a song to see your recents here!"
        placeholder.font = .systemFont(ofSize: 14, weight: .medium)
        placeholder.textColor = ComponentColors.SongCard.metadataText
        placeholder.textAlignment = .center
        placeholder.tag = 999
        stack.addArrangedSubview(placeholder)

        // Bottom spacer
        let bottomSpacer = UIView()
        bottomSpacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        contentView.addArrangedSubview(bottomSpacer)
    }

    func createRecentRow(song: Song, timeAgo: String, imageName: String) -> UIView {
        let cardBgColor = ComponentColors.SongCard.background
        let card = UIButton(type: .custom)
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1.0
        card.layer.borderColor = ComponentColors.SongCard.border.cgColor
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
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let playBtn = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        playBtn.image = UIImage(systemName: "play.circle.fill", withConfiguration: config)
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
        
        card.addAction(UIAction { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            NavigationBarHelper.animateButtonPress(card) {
                // Future: Play song
            }
        }, for: .touchUpInside)
        
        return card
    }
}

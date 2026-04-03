//
//  HomeViewControllerContinueLearning.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    // MARK: - Playlist Section

    func addPlaylistSectionView() -> UIView {
        let sectionStack = UIStackView()
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        sectionStack.translatesAutoresizingMaskIntoConstraints = false

        sectionStack.addArrangedSubview(makeSectionHeader("Your Playlist", action: { [weak self] in
            guard let self = self else { return }
            let vc = PlaylistViewController()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        }))

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.clipsToBounds = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        sectionStack.addArrangedSubview(scrollView)

        let stackView = UIStackView()
        stackView.axis = .horizontal; stackView.spacing = 16
        self.playlistStackView = stackView
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
        
        return sectionStack
    }

    func createPlaylistCard(playlist: Playlist, imageName: String) -> UIView {
        let size: CGFloat = 136
        let wrapper = UIButton(type: .custom)
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        // No border — clean card look per user request
        imageView.translatesAutoresizingMaskIntoConstraints = false

        if let url = playlist.coverImageURL, !url.isEmpty {
            if url.hasPrefix("http") {
                ImageLoader.shared.loadImage(from: url) { [weak imageView] img in
                    if let img = img { imageView?.image = img }
                }
            } else {
                imageView.image = UIImage(named: url) ?? imageView.image
            }
        }

        let titleLabel = UILabel()
        titleLabel.text = playlist.name
        titleLabel.textColor = ComponentColors.SongCard.titleText
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let tracksLabel = UILabel()
        tracksLabel.text = playlist.description ?? "Custom Playlist"
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
        
        wrapper.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            NavigationBarHelper.animateButtonPress(wrapper) { [weak self] in
                guard let self = self else { return }
                let vc = PlaylistDetailViewController()
                vc.hidesBottomBarWhenPushed = true
                vc.passedTitle   = playlist.name
                vc.passedArtist  = playlist.description ?? "Custom Playlist"
                vc.playlistId    = playlist.id
                vc.passedCoverUrl = playlist.coverImageURL
                if let url = playlist.coverImageURL, url.hasPrefix("http") {
                    ImageLoader.shared.loadImage(from: url) { [weak vc] img in vc?.passedImage = img }
                }
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }, for: .touchUpInside)
        
        return wrapper
    }

    func createEmptyPlaylistCard() -> UIView {
        let size: CGFloat = 136
        let wrapper = UIButton(type: .custom)
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.widthAnchor.constraint(equalToConstant: size).isActive = true

        let container = UIView()
        container.isUserInteractionEnabled = false
        container.backgroundColor = .clear
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(container)

        // Dashed Border
        let dashedLayer = CAShapeLayer()
        dashedLayer.strokeColor = ComponentColors.SongCard.border.withAlphaComponent(0.4).cgColor
        dashedLayer.fillColor = nil
        dashedLayer.lineWidth = 1.5
        dashedLayer.lineDashPattern = [4, 4]
        dashedLayer.path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerRadius: 16).cgPath
        container.layer.addSublayer(dashedLayer)

        let plusCircle = UIView()
        plusCircle.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        plusCircle.layer.cornerRadius = 22
        plusCircle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(plusCircle)

        let plusIcon = UIImageView(image: UIImage(systemName: "plus"))
        plusIcon.tintColor = .white
        plusIcon.contentMode = .scaleAspectFit
        plusIcon.preferredSymbolConfiguration = .init(pointSize: 18, weight: .bold)
        plusIcon.translatesAutoresizingMaskIntoConstraints = false
        plusCircle.addSubview(plusIcon)

        let titleLabel = UILabel()
        titleLabel.text = "Create\nPlaylist"
        titleLabel.textColor = ComponentColors.SongCard.titleText
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: wrapper.topAnchor),
            container.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: size),

            plusCircle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            plusCircle.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -15),
            plusCircle.widthAnchor.constraint(equalToConstant: 44),
            plusCircle.heightAnchor.constraint(equalToConstant: 44),

            plusIcon.centerXAnchor.constraint(equalTo: plusCircle.centerXAnchor),
            plusIcon.centerYAnchor.constraint(equalTo: plusCircle.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: plusCircle.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4)
        ])

        wrapper.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            NavigationBarHelper.animateButtonPress(wrapper) { [weak self] in
                guard let self = self else { return }
                let vc = PlaylistViewController()
                vc.hidesBottomBarWhenPushed = true
                vc.shouldOpenAddPlaylistOnAppear = true
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }, for: .touchUpInside)

        return wrapper
    }

    // MARK: - Recents Section

    func addRecentsSectionView() -> UIView {
        let sectionStack = UIStackView()
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        sectionStack.translatesAutoresizingMaskIntoConstraints = false

        sectionStack.addArrangedSubview(makeSectionHeader("Recents", action: { [weak self] in
            guard let self = self else { return }
            let vc = AllRecentsViewController()
            vc.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.recentsStackView = stack
        sectionStack.addArrangedSubview(stack)

        // Initial empty state
        stack.addArrangedSubview(createEmptyRecentsView())

        // Bottom spacer
        let bottomSpacer = UIView()
        bottomSpacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        sectionStack.addArrangedSubview(bottomSpacer)
        
        return sectionStack
    }

    func createEmptyRecentsView() -> UIView {
        let container = UIView()
        container.backgroundColor = ComponentColors.SongCard.background
        container.layer.cornerRadius = 24
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "music.note"))
        icon.tintColor = ComponentColors.SongCard.titleText.withAlphaComponent(0.8)
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = .init(pointSize: 32, weight: .semibold)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Nothing here yet"
        titleLabel.textColor = ComponentColors.SongCard.titleText
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Practice from Discover and\nit'll show up here."
        subtitleLabel.textColor = ComponentColors.SongCard.metadataText
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 28),

            titleLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])

        return container
    }

    func createRecentRow(song: Song, timeAgo: String, imageName: String) -> UIView {
        let card = UIButton(type: .custom)
        card.backgroundColor = ComponentColors.SongCard.background
        card.layer.cornerRadius = 16
        // No border — clean look
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let placeholder = UIImage(named: imageName) ?? UIImage(named: "trackimage_1")
        let imageView = UIImageView(image: placeholder)
        
        if let coverUrl = song.coverImageUrl, !coverUrl.isEmpty {
            if coverUrl.hasPrefix("http") {
                ImageLoader.shared.loadImage(from: coverUrl) { [weak imageView] img in
                    if let img = img { imageView?.image = img }
                }
            } else {
                imageView.image = UIImage(named: coverUrl) ?? placeholder
            }
        }

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
        
        // Tap: open the final song detail directly from Home recents.
        card.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            NavigationBarHelper.animateButtonPress(card) { [weak self] in
                guard let self = self else { return }
                let vc = DiscoverSongDetailViewController()
                vc.hidesBottomBarWhenPushed = true
                vc.song = song
                vc.passedImage = imageView.image
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }, for: .touchUpInside)
        
        return card
    }
}

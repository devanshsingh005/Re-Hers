//
//  HomeViewControllerContinueLearning.swift
//  Re-Hearse_v1
//

import UIKit

// kAppCream is kept as a local alias so call-sites in this file need no change.
// The canonical value is ComponentColors.SongCard.background — do NOT hardcode here.
private let kAppCream: UIColor = ComponentColors.SongCard.background

extension HomeViewController {

    // MARK: - Build Your Basics
    func addBuildYourBasicsSection() {
        contentView.addArrangedSubview(makeSectionHeader("Build your basics"))
        contentView.setCustomSpacing(12, after: contentView.arrangedSubviews.last!)

        // ── Cream card ──
        let card = UIView()
        card.backgroundColor   = kAppCream
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
        navigationController?.pushViewController(LessonMapViewController(), animated: true)
    }

    // MARK: - Continue Playing
    func addContinueLearningSection() {
        contentView.addArrangedSubview(makeSectionHeader("Continue playing"))
        contentView.setCustomSpacing(12, after: contentView.arrangedSubviews.last!)

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.clipsToBounds = false
        contentView.addArrangedSubview(scrollView)
        scrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        let stackView = UIStackView()
        stackView.axis = .horizontal; stackView.spacing = 12
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        let songs: [(image: String, song: String, artist: String)] = [
            ("cl_5",      "Ride",      "Pritam"),
            ("cl_4",      "Ride",      "Tanishk"),
            ("trackimage_1", "Ride",      "Tanishk"),
            ("cl_1",      "Moonlight", "Beethoven"),
            ("cl_2",      "Fur Elise", "Beethoven"),
        ]
        // Alternate orange / cream placeholder backgrounds
        for (i, s) in songs.enumerated() {
            stackView.addArrangedSubview(
                createContinuePlayingCard(
                    imageName: s.image, song: s.song, artist: s.artist,
                    placeholderColor: i.isMultiple(of: 2) ? ComponentColors.HomeScreen.actionButtonFill : kAppCream
                )
            )
        }
    }

    // MARK: - Square album card
    func createContinuePlayingCard(imageName: String, song: String, artist: String,
                                   placeholderColor: UIColor = .systemGray5) -> UIView {
        let size: CGFloat = 120
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor     = placeholderColor
        card.layer.cornerRadius  = 16
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.07
        card.layer.shadowRadius  = 8
        card.layer.shadowOffset  = CGSize(width: 0, height: 2)
        card.clipsToBounds       = false
        card.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode         = .scaleAspectFill
        imageView.clipsToBounds       = true
        imageView.layer.cornerRadius  = 16
        imageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(imageView)

        let songLabel = UILabel()
        songLabel.text = song
        songLabel.textColor = ComponentColors.SongCard.titleText
        songLabel.font          = .systemFont(ofSize: 13, weight: .semibold)
        songLabel.textAlignment = .center
        songLabel.translatesAutoresizingMaskIntoConstraints = false

        let artistLabel = UILabel()
        artistLabel.text          = artist
        artistLabel.textColor     = ComponentColors.SongCard.metadataText
        artistLabel.font          = .systemFont(ofSize: 11)
        artistLabel.textAlignment = .center
        artistLabel.translatesAutoresizingMaskIntoConstraints = false

        wrapper.addSubview(card)
        wrapper.addSubview(songLabel)
        wrapper.addSubview(artistLabel)

        NSLayoutConstraint.activate([
            wrapper.widthAnchor.constraint(equalToConstant: size),

            card.topAnchor.constraint(equalTo: wrapper.topAnchor),
            card.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            card.widthAnchor.constraint(equalToConstant: size),
            card.heightAnchor.constraint(equalToConstant: size),

            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            songLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 8),
            songLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            songLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),

            artistLabel.topAnchor.constraint(equalTo: songLabel.bottomAnchor, constant: 2),
            artistLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            artistLabel.bottomAnchor.constraint(lessThanOrEqualTo: wrapper.bottomAnchor),
        ])
        return wrapper
    }

    func createImageCard(imageName: String, title: String) -> UIView {
        createContinuePlayingCard(imageName: imageName, song: title, artist: "")
    }

    func getTitleForImage(_ name: String) -> String {
        let t = ["arrival":"The Arrival","meridian":"Meridian","classic":"Classic Suite",
                 "fur_elise":"Fur Elise","nocturne":"Nocturne","sonata":"Moonlight Sonata",
                 "prelude":"Prelude","rhapsody":"Rhapsody"]
        return t[name] ?? name.capitalized
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

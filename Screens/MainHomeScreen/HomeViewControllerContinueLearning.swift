//
//  HomeViewControllerContinueLearning.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    // MARK: - Build Your Basics
    func addBuildYourBasicsSection() {
        contentView.addArrangedSubview(makeSectionHeader("Build Your Basics"))

        let card = UIView()
        card.backgroundColor = kAppOrange
        card.layer.cornerRadius = 20
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(equalToConstant: 120).isActive = true

        // Left text stack
        let headingLabel = UILabel()
        headingLabel.text = "Start from\nthe basics"
        headingLabel.font = .systemFont(ofSize: 18, weight: .bold)
        headingLabel.textColor = .white
        headingLabel.numberOfLines = 2

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Scales · Chords · Rhythm"
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.80)

        // "Explore →" iOS-style cream label/button
        let exploreBg = UIView()
        exploreBg.backgroundColor = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1.0) // cream
        exploreBg.layer.cornerRadius = 10
        exploreBg.layer.masksToBounds = true

        let exploreLabel = UILabel()
        exploreLabel.text = "Explore →"
        exploreLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        exploreLabel.textColor = kAppOrange
        exploreLabel.translatesAutoresizingMaskIntoConstraints = false
        exploreBg.addSubview(exploreLabel)
        NSLayoutConstraint.activate([
            exploreLabel.topAnchor.constraint(equalTo: exploreBg.topAnchor, constant: 5),
            exploreLabel.bottomAnchor.constraint(equalTo: exploreBg.bottomAnchor, constant: -5),
            exploreLabel.leadingAnchor.constraint(equalTo: exploreBg.leadingAnchor, constant: 10),
            exploreLabel.trailingAnchor.constraint(equalTo: exploreBg.trailingAnchor, constant: -10),
        ])

        let leftStack = UIStackView(arrangedSubviews: [headingLabel, subtitleLabel, exploreBg])
        leftStack.axis = .vertical
        leftStack.spacing = 4
        leftStack.alignment = .leading
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.setCustomSpacing(10, after: subtitleLabel)

        // Right: 2×2 icon grid — cream tiles, orange icons
        let icons = ["music.note", "guitars", "pianokeys", "waveform.path.ecg"]
        let iconGrid = UIStackView()
        iconGrid.axis = .vertical; iconGrid.spacing = 8; iconGrid.distribution = .fillEqually
        iconGrid.translatesAutoresizingMaskIntoConstraints = false

        for row in 0..<2 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal; rowStack.spacing = 8; rowStack.distribution = .fillEqually
            for col in 0..<2 {
                let idx = row * 2 + col
                let tile = UIView()
                tile.backgroundColor = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 0.90)
                tile.layer.cornerRadius = 11
                tile.widthAnchor.constraint(equalToConstant: 40).isActive = true
                tile.heightAnchor.constraint(equalToConstant: 40).isActive = true

                let img = UIImageView(image: UIImage(systemName: icons[safe: idx] ?? "music.note"))
                img.tintColor = kAppOrange
                img.contentMode = .scaleAspectFit
                img.translatesAutoresizingMaskIntoConstraints = false
                tile.addSubview(img)
                NSLayoutConstraint.activate([
                    img.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                    img.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
                    img.widthAnchor.constraint(equalToConstant: 20),
                    img.heightAnchor.constraint(equalToConstant: 20)
                ])
                rowStack.addArrangedSubview(tile)
            }
            iconGrid.addArrangedSubview(rowStack)
        }

        card.addSubview(leftStack)
        card.addSubview(iconGrid)
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            leftStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: iconGrid.leadingAnchor, constant: -10),
            iconGrid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            iconGrid.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(buildBasicsTapped))
        card.addGestureRecognizer(tap); card.isUserInteractionEnabled = true
        contentView.addArrangedSubview(card)
    }

    @objc private func buildBasicsTapped() {
        let vc = LessonMapViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Continue Playing
    func addContinueLearningSection() {
        contentView.addArrangedSubview(makeSectionHeader("Continue Playing"))

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        contentView.addArrangedSubview(scrollView)
        scrollView.heightAnchor.constraint(equalToConstant: 182).isActive = true

        let stackView = UIStackView()
        stackView.axis = .horizontal; stackView.spacing = 12
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        let songs: [(image: String, song: String, artist: String)] = [
            ("cl_5",      "Ride",      "Pritam"),
            ("cl_4",      "Ride",      "Tanishk"),
            ("ride_home", "Ride",      "Tanishk"),
            ("cl_1",      "Moonlight", "Beethoven"),
            ("cl_2",      "Fur Elise", "Beethoven")
        ]
        songs.forEach {
            stackView.addArrangedSubview(
                createContinuePlayingCard(imageName: $0.image, song: $0.song, artist: $0.artist)
            )
        }
    }

    // MARK: - Square album card
    func createContinuePlayingCard(imageName: String, song: String, artist: String) -> UIView {
        let size: CGFloat = 130
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        // White card with shadow
        let card = UIView()
        card.layer.cornerRadius = 16
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowRadius  = 8
        card.layer.shadowOffset  = CGSize(width: 0, height: 3)
        card.clipsToBounds = false
        card.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(imageView)

        let songLabel = UILabel()
        songLabel.text = song
        songLabel.textColor = UIColor(red: 0.10, green: 0.09, blue: 0.07, alpha: 1.0)
        songLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        songLabel.textAlignment = .center
        songLabel.translatesAutoresizingMaskIntoConstraints = false

        let artistLabel = UILabel()
        artistLabel.text = artist
        artistLabel.textColor = UIColor(red: 0.55, green: 0.53, blue: 0.49, alpha: 1.0)
        artistLabel.font = .systemFont(ofSize: 11)
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
            artistLabel.bottomAnchor.constraint(lessThanOrEqualTo: wrapper.bottomAnchor)
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

    func makeSectionHeader(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 19, weight: .bold)
        l.textColor = UIColor(red: 0.10, green: 0.09, blue: 0.07, alpha: 1.0)
        return l
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

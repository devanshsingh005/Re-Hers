//
//  PlayListInside.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 24/11/25.
//


//
//  PlaylistDetailViewController.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 24/11/25.
//

import UIKit
import Foundation

struct Track {
    let title: String
    let artist: String
    let artworkName: String
}

class PlaylistDetailViewController: UIViewController {
    
    // MARK: - Data
    private let tracks: [Track] = [
        Track(title: "Last Rite",      artist: "Devjeet Saha", artworkName: "ride_home"),
        Track(title: "Phool",          artist: "Devjeet Saha", artworkName: "ride_home"),
        Track(title: "Chalo dur kahi", artist: "Devjeet Saha", artworkName: "ride_home"),
        // add more if needed...
    ]
    
    // MARK: - Scroll Container
    private let mainScrollView = UIScrollView()
    private let contentView = UIView()
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(title: "")
    
    private let albumArtBackgroundContainer = UIView()
    private let albumArtBackgroundView = UIImageView()
    private let albumArtCardView = UIImageView()
    
    private let playlistTitleLabel = UILabel()
    private let playlistArtistLabel = UILabel()
    
    private let tracksHeaderLabel = UILabel()
    private let tracksStackView = UIStackView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupScroll()
        setupContent()
        setupConstraints()
        setupTracks()
    }
    
    // MARK: - Navbar (Fixed)
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible = true
        navBar.isProfileVisible = true
        navBar.setTitle("")
        
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            navBar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Scroll Setup
    private func setupScroll() {
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.alwaysBounceVertical = true
        view.addSubview(mainScrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: mainScrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor)
        ])
    }
    
    // MARK: - Content Setup
    private func setupContent() {
        // Banner background container
        albumArtBackgroundContainer.layer.cornerRadius = 24
        albumArtBackgroundContainer.clipsToBounds = true
        albumArtBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtBackgroundContainer)
        
        let backgroundImage = UIImage(named: "ride_home") ?? UIImage(systemName: "photo")
        albumArtBackgroundView.image = backgroundImage
        albumArtBackgroundView.contentMode = .scaleAspectFill
        albumArtBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        albumArtBackgroundContainer.addSubview(albumArtBackgroundView)
        
        // Center card
        albumArtCardView.image = backgroundImage
        albumArtCardView.layer.cornerRadius = 24
        albumArtCardView.clipsToBounds = true
        albumArtCardView.contentMode = .scaleAspectFill
        albumArtCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtCardView)
        
        // Playlist title & artist
        playlistTitleLabel.text = "Silent Waves"
        playlistTitleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        playlistTitleLabel.textAlignment = .center
        playlistTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playlistTitleLabel)
        
        playlistArtistLabel.text = "Devjeet Saha"
        playlistArtistLabel.font = .systemFont(ofSize: 14, weight: .regular)
        playlistArtistLabel.textColor = .darkGray
        playlistArtistLabel.textAlignment = .center
        playlistArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playlistArtistLabel)
        
        // Tracks header
        tracksHeaderLabel.text = "Tracks - \(tracks.count)"
        tracksHeaderLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        tracksHeaderLabel.textColor = .label
        tracksHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tracksHeaderLabel)
        
        // Tracks list stack
        tracksStackView.axis = .vertical
        tracksStackView.spacing = 12
        tracksStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tracksStackView)
    }
    
    // MARK: - Constraints
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Banner
            albumArtBackgroundContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            albumArtBackgroundContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            albumArtBackgroundContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            albumArtBackgroundContainer.heightAnchor.constraint(equalToConstant: 180),
            
            albumArtBackgroundView.topAnchor.constraint(equalTo: albumArtBackgroundContainer.topAnchor),
            albumArtBackgroundView.bottomAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor),
            albumArtBackgroundView.leadingAnchor.constraint(equalTo: albumArtBackgroundContainer.leadingAnchor),
            albumArtBackgroundView.trailingAnchor.constraint(equalTo: albumArtBackgroundContainer.trailingAnchor),
            
            albumArtCardView.centerXAnchor.constraint(equalTo: albumArtBackgroundContainer.centerXAnchor),
            albumArtCardView.centerYAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor, constant: -28),
            albumArtCardView.widthAnchor.constraint(equalToConstant: 140),
            albumArtCardView.heightAnchor.constraint(equalToConstant: 140),
            
            // Title & artist
            playlistTitleLabel.topAnchor.constraint(equalTo: albumArtCardView.bottomAnchor, constant: 16),
            playlistTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            playlistArtistLabel.topAnchor.constraint(equalTo: playlistTitleLabel.bottomAnchor, constant: 2),
            playlistArtistLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Tracks header
            tracksHeaderLabel.topAnchor.constraint(equalTo: playlistArtistLabel.bottomAnchor, constant: 24),
            tracksHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            
            // Track list
            tracksStackView.topAnchor.constraint(equalTo: tracksHeaderLabel.bottomAnchor, constant: 16),
            tracksStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tracksStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tracksStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Build Track Cards
    private func setupTracks() {
        for (index, track) in tracks.enumerated() {
            let card = makeTrackCard(for: track, index: index)
            tracksStackView.addArrangedSubview(card)
        }
    }
    
    private func makeTrackCard(for track: Track, index: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.systemGray5
        container.layer.cornerRadius = 22
        
        let artworkView = UIImageView()
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.image = UIImage(named: track.artworkName) ?? UIImage(systemName: "music.note")
        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 18
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = track.title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        
        let artistLabel = UILabel()
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.text = track.artist
        artistLabel.font = .systemFont(ofSize: 12, weight: .regular)
        artistLabel.textColor = .secondaryLabel
        
        let labelsStack = UIStackView(arrangedSubviews: [titleLabel, artistLabel])
        labelsStack.axis = .vertical
        labelsStack.spacing = 2
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let playButton = UIButton(type: .system)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        let playImage = UIImage(systemName: "play.fill")
        playButton.setImage(playImage, for: .normal)
        playButton.tintColor = .darkGray
        playButton.tag = index
        playButton.addTarget(self, action: #selector(trackPlayTapped(_:)), for: .touchUpInside)
        
        container.addSubview(artworkView)
        container.addSubview(labelsStack)
        container.addSubview(playButton)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 80),
            
            artworkView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            artworkView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 56),
            artworkView.heightAnchor.constraint(equalToConstant: 56),
            
            labelsStack.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 12),
            labelsStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelsStack.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -8),
            
            playButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            playButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 30),
            playButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return container
    }
    
    // MARK: - Actions
    @objc private func trackPlayTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < tracks.count else { return }
        
        // Navigate to your existing SongDetailViewController
        let vc = SongDetailViewController()
        // if you want, you can pass data to vc here later
        navigationController?.pushViewController(vc, animated: true)
    }
}


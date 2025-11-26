//
//  PlayListInside.swift
//  Re-Hearse_v1
//

import UIKit
import Foundation

struct Track {
    let title: String
    let artist: String
    let artworkName: String
}

class PlaylistDetailViewController: UIViewController {
    
    // MARK: - Passed Data
    var passedImage: UIImage?
    var passedTitle: String?
    var passedArtist: String?
    
    // MARK: - Tracks
    private let tracks: [Track] = [
        Track(title: "Last Rite",      artist: "Devjeet Saha", artworkName: "cl_3"),
        Track(title: "Phool",          artist: "Devjeet Saha", artworkName: "cl_4"),
        Track(title: "Chalo dur kahi", artist: "Devjeet Saha", artworkName: "cl_5"),
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
        
        setupUI()
        setupScroll()
        setupContent()
        setupConstraints()
        setupTracks()
        
        applyPassedData()
    }
    
    // MARK: - Apply Passed Playlist Data
    private func applyPassedData() {
        let img = passedImage ?? UIImage(named: "cl_2")
        
        albumArtBackgroundView.image = img
        albumArtCardView.image = img
        
        playlistTitleLabel.text = passedTitle ?? "Silent Waves"
        playlistArtistLabel.text = passedArtist ?? "Devjeet Saha"
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
       
    }
    // MARK: - Navbar Setup
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible = true
        navBar.isProfileVisible = true
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.setTitle("")
        
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        navBar.chordAction = { [weak self] in
            let vc = ChordRecognitionViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }
    
    // MARK: - Scroll
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
    
    // MARK: - Content
    private func setupContent() {
        albumArtBackgroundContainer.layer.cornerRadius = 24
        albumArtBackgroundContainer.clipsToBounds = true
        albumArtBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtBackgroundContainer)
        
        albumArtBackgroundView.image = UIImage(named: "cl_2")
        albumArtBackgroundView.contentMode = .scaleAspectFill
        albumArtBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        albumArtBackgroundContainer.addSubview(albumArtBackgroundView)
        
        albumArtCardView.image = UIImage(named: "cl_2")
        albumArtCardView.layer.cornerRadius = 24
        albumArtCardView.contentMode = .scaleAspectFill
        albumArtCardView.clipsToBounds = true
        albumArtCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtCardView)
        
        playlistTitleLabel.text = "Silent Waves"
        playlistTitleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        playlistTitleLabel.textAlignment = .center
        playlistTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playlistTitleLabel)
        
        playlistArtistLabel.text = "Devjeet Saha"
        playlistArtistLabel.font = .systemFont(ofSize: 14)
        playlistArtistLabel.textAlignment = .center
        playlistArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        playlistArtistLabel.textColor = .darkGray
        contentView.addSubview(playlistArtistLabel)
        
        tracksHeaderLabel.text = "Tracks - \(tracks.count)"
        tracksHeaderLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        tracksHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tracksHeaderLabel)
        
        tracksStackView.axis = .vertical
        tracksStackView.spacing = 12
        tracksStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tracksStackView)
    }
    
    // MARK: - Constraints
    private func setupConstraints() {
        NSLayoutConstraint.activate([
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
            
            playlistTitleLabel.topAnchor.constraint(equalTo: albumArtCardView.bottomAnchor, constant: 16),
            playlistTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            playlistArtistLabel.topAnchor.constraint(equalTo: playlistTitleLabel.bottomAnchor, constant: 2),
            playlistArtistLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            tracksHeaderLabel.topAnchor.constraint(equalTo: playlistArtistLabel.bottomAnchor, constant: 24),
            tracksHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            
            tracksStackView.topAnchor.constraint(equalTo: tracksHeaderLabel.bottomAnchor, constant: 16),
            tracksStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tracksStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tracksStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])
    }
    
    // MARK: - Track Cards
    private func setupTracks() {
        for (index, track) in tracks.enumerated() {
            let card = makeTrackCard(for: track, index: index)
            tracksStackView.addArrangedSubview(card)
        }
    }
    
    private func makeTrackCard(for track: Track, index: Int) -> UIView {
        let container =
            UIView()
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
        
        let artistLabel = UILabel()
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.text = track.artist
        artistLabel.font = .systemFont(ofSize: 12)
        artistLabel.textColor = .secondaryLabel
        
        let labelsStack = UIStackView(arrangedSubviews: [titleLabel, artistLabel])
        labelsStack.axis = .vertical
        labelsStack.spacing = 2
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let playButton = UIButton(type: .system)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
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
    
    // MARK: - Play Action (UPDATED TO PASS IMAGE)
    @objc private func trackPlayTapped(_ sender: UIButton) {
        let index = sender.tag
        let track = tracks[index]
        
        let vc = SongDetailViewController()
        
        vc.passedImage = UIImage(named: track.artworkName)
        vc.passedSongTitle = track.title
        vc.passedArtist = track.artist
        
        navigationController?.pushViewController(vc, animated: true)
    }
}

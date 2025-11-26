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
    
    // MARK: - Tracks (dynamic list)
    private var trackList: [Track] = [
        Track(title: "Last Rite",      artist: "Devjeet Saha", artworkName: "cl_3"),
        Track(title: "Phool",          artist: "Devjeet Saha", artworkName: "cl_4"),
        Track(title: "Chalo dur kahi", artist: "Devjeet Saha", artworkName: "cl_5"),
    ]
    
    // MARK: - All available songs to choose from
    private let availableSongs: [Track] = [
        Track(title: "Moonlight Echo", artist: "Devjeet Saha", artworkName: "cl_6"),
        Track(title: "Broken Strings", artist: "Devjeet Saha", artworkName: "cl_7"),
        Track(title: "Infinite Road",  artist: "Devjeet Saha", artworkName: "cl_8"),
        Track(title: "Daydream Pulse", artist: "Devjeet Saha", artworkName: "cl_9"),
    ]
    
    // MARK: - Scroll + Container
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
    
    // MARK: - Floating Button
    private let floatingAddButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.orange
        btn.setImage(UIImage(systemName: "plus"), for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = 30
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.25
        btn.layer.shadowRadius = 6
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.isHidden = true
        
        setupUI()
        setupScroll()
        setupContent()
        setupConstraints()
        reloadTracksUI()
        applyPassedData()
        setupFloatingButton()
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
        setupNavBar()
    }

    // MARK: - Navbar
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible = true
        navBar.isProfileVisible = true
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
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
            contentView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor),
        ])
    }
    
    // MARK: - Content
    private func setupContent() {
        albumArtBackgroundContainer.layer.cornerRadius = 24
        albumArtBackgroundContainer.clipsToBounds = true
        albumArtBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtBackgroundContainer)
        
        albumArtBackgroundView.contentMode = .scaleAspectFill
        albumArtBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        albumArtBackgroundContainer.addSubview(albumArtBackgroundView)
        
        albumArtCardView.contentMode = .scaleAspectFill
        albumArtCardView.clipsToBounds = true
        albumArtCardView.layer.cornerRadius = 24
        albumArtCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtCardView)
        
        playlistTitleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        playlistTitleLabel.textAlignment = .center
        playlistTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playlistTitleLabel)
        
        playlistArtistLabel.font = .systemFont(ofSize: 14)
        playlistArtistLabel.textColor = .darkGray
        playlistArtistLabel.textAlignment = .center
        playlistArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(playlistArtistLabel)
        
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
            albumArtBackgroundView.leadingAnchor.constraint(equalTo: albumArtBackgroundContainer.leadingAnchor),
            albumArtBackgroundView.trailingAnchor.constraint(equalTo: albumArtBackgroundContainer.trailingAnchor),
            albumArtBackgroundView.bottomAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor),
            
            albumArtCardView.centerXAnchor.constraint(equalTo: albumArtBackgroundContainer.centerXAnchor),
            albumArtCardView.centerYAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor, constant: -28),
            albumArtCardView.heightAnchor.constraint(equalToConstant: 140),
            albumArtCardView.widthAnchor.constraint(equalToConstant: 140),
            
            playlistTitleLabel.topAnchor.constraint(equalTo: albumArtCardView.bottomAnchor, constant: 16),
            playlistTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            playlistArtistLabel.topAnchor.constraint(equalTo: playlistTitleLabel.bottomAnchor, constant: 5),
            playlistArtistLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            tracksHeaderLabel.topAnchor.constraint(equalTo: playlistArtistLabel.bottomAnchor, constant: 28),
            tracksHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            tracksStackView.topAnchor.constraint(equalTo: tracksHeaderLabel.bottomAnchor, constant: 16),
            tracksStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tracksStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tracksStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
        ])
    }
    
    // MARK: - Floating Button Setup
    private func setupFloatingButton() {
        view.addSubview(floatingAddButton)
        
        floatingAddButton.addTarget(self, action: #selector(showAddSongPopup), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            floatingAddButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            floatingAddButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            floatingAddButton.widthAnchor.constraint(equalToConstant: 60),
            floatingAddButton.heightAnchor.constraint(equalToConstant: 60),
        ])
    }
    
    // MARK: - Popup to Choose Songs
    @objc private func showAddSongPopup() {
        let alert = UIAlertController(title: "Add Song", message: "Select a track to add", preferredStyle: .actionSheet)
        
        for song in availableSongs {
            alert.addAction(UIAlertAction(title: song.title, style: .default, handler: { _ in
                self.addSongToPlaylist(song)
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        self.present(alert, animated: true)
    }
    
    // MARK: - Add Song Logic
    private func addSongToPlaylist(_ song: Track) {
        trackList.append(song)
        reloadTracksUI()
    }
    
    // MARK: - Refresh UI
    private func reloadTracksUI() {
        tracksStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        tracksHeaderLabel.text = "Tracks - \(trackList.count)"
        
        for (i, track) in trackList.enumerated() {
            let card = makeTrackCard(for: track, index: i)
            tracksStackView.addArrangedSubview(card)
        }
    }
    
    // MARK: - Track Card
    private func makeTrackCard(for track: Track, index: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemGray5
        container.layer.cornerRadius = 22
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let artwork = UIImageView(image: UIImage(named: track.artworkName))
        artwork.contentMode = .scaleAspectFill
        artwork.layer.cornerRadius = 18
        artwork.clipsToBounds = true
        artwork.translatesAutoresizingMaskIntoConstraints = false
        
        let title = UILabel()
        title.text = track.title
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        
        let artist = UILabel()
        artist.text = track.artist
        artist.font = .systemFont(ofSize: 12)
        artist.textColor = .secondaryLabel
        
        let labels = UIStackView(arrangedSubviews: [title, artist])
        labels.axis = .vertical
        labels.spacing = 0
        labels.translatesAutoresizingMaskIntoConstraints = false
        
        let play = UIButton(type: .system)
        play.setImage(UIImage(systemName: "play.fill"), for: .normal)
        play.tintColor = .darkGray
        play.tag = index
        play.addTarget(self, action: #selector(trackPlayTapped(_:)), for: .touchUpInside)
        play.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(artwork)
        container.addSubview(labels)
        container.addSubview(play)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 80),
            
            artwork.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            artwork.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            artwork.widthAnchor.constraint(equalToConstant: 56),
            artwork.heightAnchor.constraint(equalToConstant: 56),
            
            labels.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 12),
            labels.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labels.trailingAnchor.constraint(equalTo: play.leadingAnchor, constant: -10),
            
            play.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            play.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            play.widthAnchor.constraint(equalToConstant: 32),
            play.heightAnchor.constraint(equalToConstant: 32),
        ])
        
        return container
    }
    
    // MARK: - Play Action
    @objc private func trackPlayTapped(_ sender: UIButton) {
        let index = sender.tag
        let track = trackList[index]
        
        let vc = SongDetailViewController()
        vc.passedImage = UIImage(named: track.artworkName)
        vc.passedSongTitle = track.title
        vc.passedArtist = track.artist
        
        navigationController?.pushViewController(vc, animated: true)
    }
}

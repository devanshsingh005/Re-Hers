//
//  PlayListInside.swift
//  Re-Hearse_v1
//

import UIKit
import Foundation


class PlaylistDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Passed Data
    var passedImage: UIImage? {
        didSet {
            guard isViewLoaded else { return }
            let placeholder = playlistId.map { albumPlaceholder(for: $0) } ?? UIImage(systemName: "music.note.list")
            let img = passedImage ?? placeholder
            albumArtBackgroundView.image = img
            albumArtCardView.image = img
        }
    }
    var passedTitle: String?
    var passedArtist: String?
    var playlistId: UUID?
    
    // MARK: - Tracks (fetched from Supabase)
    private var trackList: [PlaylistTrack] = []
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(title: "")
    
    // Header View Components (will be placed in tableView.tableHeaderView)
    private let headerContainerView = UIView()
    private let albumArtBackgroundContainer = UIView()
    private let albumArtBackgroundView = UIImageView()
    private let albumArtCardView = UIImageView()
    private let playlistTitleLabel = UILabel()
    private let playlistArtistLabel = UILabel()
    private let tracksHeaderLabel = UILabel()
    
    // Table View
    private let tracksTableView = UITableView(frame: .zero, style: .plain)
    
    // MARK: - Activity Indicator
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .orange
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Empty State
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No tracks yet.\nTap + to add a track."
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
        
        // Background color #F8F8F4
        view.backgroundColor = UIColor(red: 248/255, green: 248/255, blue: 244/255, alpha: 1.0)
        navigationController?.navigationBar.isHidden = true
        
        setupTableView()
        setupNavBar()
        setupHeader()
        setupActivityIndicator()
        applyPassedData()
        setupFloatingButton()
        fetchTracks()
    }
    
    // MARK: - Apply Passed Playlist Data
    private func applyPassedData() {
        let placeholder = playlistId.map { albumPlaceholder(for: $0) } ?? UIImage(systemName: "music.note.list")
        let img = passedImage ?? placeholder
        
        albumArtBackgroundView.image = img
        albumArtCardView.image = img
        
        playlistTitleLabel.text = passedTitle ?? "Playlist"
        playlistArtistLabel.text = passedArtist ?? "Custom Playlist" // Matching design text
    }
    
    private func setupTableView() {
        tracksTableView.backgroundColor = .clear
        tracksTableView.separatorStyle = .none
        tracksTableView.dataSource = self
        tracksTableView.delegate = self
        tracksTableView.register(TrackTableViewCell.self, forCellReuseIdentifier: "TrackCell")
        tracksTableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tracksTableView)
        
        NSLayoutConstraint.activate([
            tracksTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60), // Space for navbar
            tracksTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tracksTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tracksTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupActivityIndicator() {
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
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
        
        navBar.chordAction = { [weak self] in
            let vc = ChordRecognitionViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }
        navBar.profileAction = { [weak self] in
            guard let self = self else { return }
            let vc = UserProfileViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }
    
    // MARK: - Header Setup
    private func setupHeader() {
        headerContainerView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 350)
        
        albumArtBackgroundContainer.layer.cornerRadius = 24
        albumArtBackgroundContainer.clipsToBounds = true
        albumArtBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainerView.addSubview(albumArtBackgroundContainer)
        
        albumArtBackgroundView.contentMode = .scaleAspectFill
        albumArtBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        albumArtBackgroundContainer.addSubview(albumArtBackgroundView)
        
        albumArtCardView.contentMode = .scaleAspectFill
        albumArtCardView.clipsToBounds = true
        albumArtCardView.layer.cornerRadius = 24
        albumArtCardView.translatesAutoresizingMaskIntoConstraints = false
        headerContainerView.addSubview(albumArtCardView)
        
        playlistTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        playlistTitleLabel.textAlignment = .center
        playlistTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainerView.addSubview(playlistTitleLabel)
        
        playlistArtistLabel.font = .systemFont(ofSize: 16)
        playlistArtistLabel.textColor = .secondaryLabel
        playlistArtistLabel.textAlignment = .center
        playlistArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainerView.addSubview(playlistArtistLabel)
        
        tracksHeaderLabel.font = .systemFont(ofSize: 20, weight: .bold)
        tracksHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        headerContainerView.addSubview(tracksHeaderLabel)
        
        headerContainerView.addSubview(emptyStateLabel)
        
        tracksTableView.tableHeaderView = headerContainerView
        
        NSLayoutConstraint.activate([
            albumArtBackgroundContainer.topAnchor.constraint(equalTo: headerContainerView.topAnchor, constant: 8),
            albumArtBackgroundContainer.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor, constant: 16),
            albumArtBackgroundContainer.trailingAnchor.constraint(equalTo: headerContainerView.trailingAnchor, constant: -16),
            albumArtBackgroundContainer.heightAnchor.constraint(equalToConstant: 160),
            
            albumArtBackgroundView.topAnchor.constraint(equalTo: albumArtBackgroundContainer.topAnchor),
            albumArtBackgroundView.leadingAnchor.constraint(equalTo: albumArtBackgroundContainer.leadingAnchor),
            albumArtBackgroundView.trailingAnchor.constraint(equalTo: albumArtBackgroundContainer.trailingAnchor),
            albumArtBackgroundView.bottomAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor),
            
            albumArtCardView.centerXAnchor.constraint(equalTo: albumArtBackgroundContainer.centerXAnchor),
            albumArtCardView.centerYAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor, constant: -10),
            albumArtCardView.heightAnchor.constraint(equalToConstant: 140),
            albumArtCardView.widthAnchor.constraint(equalToConstant: 140),
            
            playlistTitleLabel.topAnchor.constraint(equalTo: albumArtCardView.bottomAnchor, constant: 10),
            playlistTitleLabel.centerXAnchor.constraint(equalTo: headerContainerView.centerXAnchor),
            
            playlistArtistLabel.topAnchor.constraint(equalTo: playlistTitleLabel.bottomAnchor, constant: 4),
            playlistArtistLabel.centerXAnchor.constraint(equalTo: headerContainerView.centerXAnchor),
            
            tracksHeaderLabel.topAnchor.constraint(equalTo: playlistArtistLabel.bottomAnchor, constant: 16),
            tracksHeaderLabel.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor, constant: 20),
            
            emptyStateLabel.topAnchor.constraint(equalTo: tracksHeaderLabel.bottomAnchor, constant: 30),
            emptyStateLabel.centerXAnchor.constraint(equalTo: headerContainerView.centerXAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: headerContainerView.trailingAnchor, constant: -40),
        ])
        
        // Add tap gesture to playlist title
        playlistTitleLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handlePlaylistRename))
        playlistTitleLabel.addGestureRecognizer(tap)
    }
    
    @objc private func handlePlaylistRename() {
        let alert = UIAlertController(title: "Rename Playlist", message: "Enter new name", preferredStyle: .alert)
        alert.addTextField { $0.text = self.playlistTitleLabel.text }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            self.updatePlaylistName(newName)
        })
        present(alert, animated: true)
    }
    
    private func updatePlaylistName(_ newName: String) {
        guard let id = playlistId else { return }
        Task {
            do {
                try await PlaylistsManager.shared.updatePlaylistName(id: id, newName: newName)
                await MainActor.run {
                    self.playlistTitleLabel.text = newName
                    self.passedTitle = newName
                    NotificationCenter.default.post(name: NSNotification.Name("PlaylistUpdated"), object: nil)
                }
            } catch {
                print("❌ Rename error: \(error)")
            }
        }
    }
    
    // MARK: - Floating Button Setup
    private func setupFloatingButton() {
        view.addSubview(floatingAddButton)
        
        floatingAddButton.addTarget(self, action: #selector(showAddTrackDialog), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            floatingAddButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            floatingAddButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            floatingAddButton.widthAnchor.constraint(equalToConstant: 60),
            floatingAddButton.heightAnchor.constraint(equalToConstant: 60),
        ])
    }
    
    // MARK: - Fetch Tracks
    private func fetchTracks() {
        guard let playlistId = playlistId else {
            reloadTracksUI()
            return
        }
        
        activityIndicator.startAnimating()
        
        Task {
            do {
                let tracks = try await PlaylistsManager.shared.fetchPlaylistTracks(playlistId: playlistId)
                DispatchQueue.main.async { [weak self] in
                    self?.trackList = tracks
                    self?.activityIndicator.stopAnimating()
                    self?.reloadTracksUI()
                }
            } catch {
                print("❌ Error fetching tracks: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.stopAnimating()
                    self?.reloadTracksUI()
                }
            }
        }
    }
    
    // MARK: - Add Track
    @objc private func showAddTrackDialog() {
        guard let playlistId = playlistId else { return }
        let picker = UploadPickerViewController()
        picker.modalPresentationStyle = .pageSheet
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        picker.onSelect = { [weak self] uploadItem in
            guard let self else { return }
            self.addScanToPlaylist(playlistId: playlistId, scan: uploadItem)
        }
        present(picker, animated: true)
    }
    
    private func addScanToPlaylist(playlistId: UUID, scan: UploadScanItem) {
        activityIndicator.startAnimating()
        Task {
            do {
                let newTrack = try await PlaylistsManager.shared.addScanToPlaylist(
                    playlistId: playlistId,
                    scan: scan
                )
                DispatchQueue.main.async { [weak self] in
                    self?.trackList.append(newTrack)
                    self?.activityIndicator.stopAnimating()
                    self?.reloadTracksUI()
                }
            } catch {
                print("❌ Error adding scan to playlist: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.stopAnimating()
                    let alert = UIAlertController(title: "Error",
                                                  message: "Failed to add track: \(error.localizedDescription)",
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - Remove Track
    private func removeTrack(at index: Int) {
        let track = trackList[index]
        guard let itemId = track.playlistItemId else { return }
        
        activityIndicator.startAnimating()
        
        Task {
            do {
                try await PlaylistsManager.shared.removeTrackFromPlaylist(playlistItemId: itemId)
                DispatchQueue.main.async { [weak self] in
                    self?.trackList.remove(at: index)
                    self?.activityIndicator.stopAnimating()
                    self?.reloadTracksUI()
                }
            } catch {
                print("❌ Error removing track: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }
    
    // MARK: - Refresh UI
    private func reloadTracksUI() {
        tracksHeaderLabel.text = "Tracks - \(trackList.count)"
        emptyStateLabel.isHidden = !trackList.isEmpty
        tracksTableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return trackList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath) as! TrackTableViewCell
        let track = trackList[indexPath.row]
        cell.configure(with: track, index: indexPath.row)
        cell.selectionStyle = .none
        
        cell.renameHandler = { [weak self] in
            self?.handleTrackRename(at: indexPath.row)
        }
        
        return cell
    }
    
    private func handleTrackRename(at index: Int) {
        let track = trackList[index]
        let alert = UIAlertController(title: "Rename Track", message: "Enter new title", preferredStyle: .alert)
        alert.addTextField { $0.text = track.title }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
            guard let newTitle = alert.textFields?.first?.text, !newTitle.isEmpty else { return }
            self.updateTrackTitle(at: index, newTitle: newTitle)
        })
        present(alert, animated: true)
    }
    
    private func updateTrackTitle(at index: Int, newTitle: String) {
        guard let playlistItemId = trackList[index].playlistItemId else { return }
        Task {
            do {
                try await PlaylistsManager.shared.updateTrackName(playlistItemId: playlistItemId, newTitle: newTitle)
                await MainActor.run {
                    self.fetchTracks() // Refresh data
                }
            } catch {
                print("❌ Track rename error: \(error)")
            }
        }
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 92 // 80 card height + 12 spacing
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let track = trackList[indexPath.row]
        let vc = SongDetailViewController()
        vc.passedImage = UIImage(named: "cl_\((indexPath.row % 5) + 1)")
        vc.passedSongTitle = track.title
        vc.passedArtist = track.artist
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completion) in
            self?.removeTrack(at: indexPath.row)
            completion(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}


// MARK: - Custom TableViewCell
class TrackTableViewCell: UITableViewCell {
    
    private let container = UIView()
    private let artwork = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    var renameHandler: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Playlist/Card color #F4F3EE
        container.backgroundColor = UIColor(red: 244/255, green: 243/255, blue: 238/255, alpha: 1.0)
        container.layer.cornerRadius = 22
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        
        artwork.contentMode = .scaleAspectFill
        artwork.layer.cornerRadius = 18
        artwork.clipsToBounds = true
        artwork.backgroundColor = UIColor.systemGray4
        artwork.tintColor = .darkGray
        artwork.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(artwork)
        
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleRenameTap))
        titleLabel.addGestureRecognizer(tap)
        container.addSubview(titleLabel)
        
        artistLabel.font = .systemFont(ofSize: 12)
        artistLabel.textColor = .secondaryLabel
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(artistLabel)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            artwork.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            artwork.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            artwork.widthAnchor.constraint(equalToConstant: 56),
            artwork.heightAnchor.constraint(equalToConstant: 56),
            
            titleLabel.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -10),
            
            artistLabel.leadingAnchor.constraint(equalTo: artwork.trailingAnchor, constant: 12),
            artistLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            artistLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 10),
        ])
    }
    
    func configure(with track: PlaylistTrack, index: Int) {
        titleLabel.text = track.title
        artistLabel.text = track.artist
        artwork.image = UIImage(named: "cl_\((index % 5) + 1)") ?? UIImage(systemName: "music.note")
    }
    
    @objc private func handleRenameTap() {
        renameHandler?()
    }
}

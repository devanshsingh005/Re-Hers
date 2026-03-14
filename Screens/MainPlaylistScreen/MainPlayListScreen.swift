//
//  MainPlayListScreen.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/11/25.
//

import UIKit
import Supabase

// MARK: - Playlist Data Model
struct Playlist {
    let id: UUID
    let title: String
    /// imageIdentifier can be an asset name (e.g. "cl_1") or a filename saved in Documents (e.g. "doc_123.png") or a signed URL
    let imageIdentifier: String
    let tags: String
    let trackCount: Int
    let createdAt: Date?
    let isPublic: Bool?
    var isSelectedForDeletion: Bool = false
    
    // Convenience initializer for local playlists
    init(id: UUID = UUID(), title: String, imageIdentifier: String, tags: String, trackCount: Int, createdAt: Date? = nil, isPublic: Bool? = false) {
        self.id = id
        self.title = title
        self.imageIdentifier = imageIdentifier
        self.tags = tags
        self.trackCount = trackCount
        self.createdAt = createdAt
        self.isPublic = isPublic
    }
}

// MARK: - Database Playlist Model
struct DBPlaylist: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let coverImageUrl: String?
    let isPublic: Bool?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case coverImageUrl = "cover_image_url"
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Image Loader with Cache
class ImageLoader {
    static let shared = ImageLoader()
    private var cache = NSCache<NSString, UIImage>()
    private var loadingTasks: [String: URLSessionDataTask] = [:]
    
    private init() {}
    
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            completion(cachedImage)
            return
        }
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        // Cancel existing task for this URL if any
        loadingTasks[urlString]?.cancel()
        
        // Create new download task
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Remove task from dictionary
            self.loadingTasks.removeValue(forKey: urlString)
            
            guard let data = data,
                  let image = UIImage(data: data),
                  error == nil else {
                completion(nil)
                return
            }
            
            // Cache the image
            self.cache.setObject(image, forKey: urlString as NSString)
            
            DispatchQueue.main.async {
                completion(image)
            }
        }
        
        // Store and start task
        loadingTasks[urlString] = task
        task.resume()
    }
    
    func cancelLoad(for urlString: String) {
        loadingTasks[urlString]?.cancel()
        loadingTasks.removeValue(forKey: urlString)
    }
}

// MARK: - Playlist Screen
class PlaylistViewController: UIViewController {
    
    // MARK: - UI Components
    private let navBar = TopNavBar.make(title: "PlayList")
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()
    
    // MARK: - Floating Action Buttons
    private let addButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.orange
        btn.setImage(UIImage(systemName: "plus"), for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = UIDevice.current.userInterfaceIdiom == .pad ? 35 : 30
        btn.clipsToBounds = false
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.25
        btn.layer.shadowRadius = 6
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.tag = 1 // Tag for add button
        return btn
    }()
    
    private let deleteButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.systemRed
        btn.setImage(UIImage(systemName: "trash"), for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = UIDevice.current.userInterfaceIdiom == .pad ? 35 : 30
        btn.clipsToBounds = false
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.25
        btn.layer.shadowRadius = 6
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.tag = 2 // Tag for delete button
        btn.alpha = 0
        btn.isHidden = true
        return btn
    }()
    
    private let selectionModeLabel: UILabel = {
        let label = UILabel()
        label.text = "Select Playlists to Delete"
        label.textColor = .systemRed
        label.font = UIDevice.current.userInterfaceIdiom == .pad ? .boldSystemFont(ofSize: 18) : .boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.backgroundColor = .white
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.layer.borderColor = UIColor.systemRed.cgColor
        label.layer.borderWidth = 1
        label.alpha = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Activity Indicator
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .orange
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Data
    private var playlists: [Playlist] = [] {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    // MARK: - State Management
    private var isSelectionMode = false {
        didSet {
            updateUIForSelectionMode()
        }
    }
    
    // MARK: - iPad-specific properties
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    private var selectedIndexPaths: Set<IndexPath> = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFloatingButtons()
        setupActivityIndicator()
        setupRefreshControl()
        loadPlaylists()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPlaylists()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            guard let collectionView = self.collectionView else {
                print("❌ collectionView is nil")
                return
            }
            collectionView.collectionViewLayout.invalidateLayout()

        }
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupCollectionView()
        setupSelectionModeLabel()
    }
    
    private func setupActivityIndicator() {
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupRefreshControl() {
        refreshControl.tintColor = .orange
        refreshControl.addTarget(self, action: #selector(refreshPlaylists), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func setupSelectionModeLabel() {
        view.addSubview(selectionModeLabel)
        NSLayoutConstraint.activate([
            selectionModeLabel.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 8),
            selectionModeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: isPad ? 40 : 20),
            selectionModeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: isPad ? -40 : -20),
            selectionModeLabel.heightAnchor.constraint(equalToConstant: isPad ? 50 : 40)
        ])
    }
    
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.isChordIconVisible = true
        
        navBar.chordAction = { [weak self] in
            let vc = ChordRecognitionViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }
        navBar.profileAction = { [weak self] in
            guard let self = self else { return }
            let vc = UserProfileViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        let sidePadding: CGFloat = isPad ? 40 : 10
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sidePadding),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sidePadding)
        ])
    }
    
    // MARK: - Floating Buttons
    private func setupFloatingButtons() {
        view.addSubview(addButton)
        view.addSubview(deleteButton)
        
        // Size for iPad vs iPhone
        let buttonSize: CGFloat = isPad ? 70 : 60
        let buttonBottomPadding: CGFloat = isPad ? 40 : 26
        let buttonSidePadding: CGFloat = isPad ? 40 : 22
        let buttonSpacing: CGFloat = isPad ? 24 : 16
        
        NSLayoutConstraint.activate([
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -buttonSidePadding),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -buttonBottomPadding),
            addButton.widthAnchor.constraint(equalToConstant: buttonSize),
            addButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -buttonSidePadding),
            deleteButton.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -buttonSpacing),
            deleteButton.widthAnchor.constraint(equalToConstant: buttonSize),
            deleteButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
        
        addButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
    }
    
    private func updateUIForSelectionMode() {
        UIView.animate(withDuration: 0.3) {
            if self.isSelectionMode {
                // Show delete button and selection label
                self.deleteButton.isHidden = false
                self.deleteButton.alpha = 1
                self.selectionModeLabel.isHidden = false
                self.selectionModeLabel.alpha = 1
                
                // Change add button to "Done" for confirming deletion
                self.addButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
                self.addButton.backgroundColor = UIColor.systemGreen
            } else {
                // Hide delete button and selection label
                self.deleteButton.alpha = 0
                self.selectionModeLabel.alpha = 0
                
                // Reset add button to original state
                self.addButton.setImage(UIImage(systemName: "plus"), for: .normal)
                self.addButton.backgroundColor = UIColor.orange
                
                // Hide delete button after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.deleteButton.isHidden = true
                    self.selectionModeLabel.isHidden = true
                }
                
                // Deselect all playlists
                for i in 0..<self.playlists.count {
                    self.playlists[i].isSelectedForDeletion = false
                }
                self.selectedIndexPaths.removeAll()
            }
            self.collectionView.reloadData()
        }
    }
    
    // MARK: - Button Actions
    @objc private func didTapAdd() {
        if isSelectionMode {
            // Confirm deletion
            confirmDeletion()
        } else {
            // Create new playlist
            let addVC = AddPlaylistViewController()
            addVC.modalPresentationStyle = .overFullScreen
            
            addVC.onSave = { [weak self] (name, pickedImage) in
                guard let self = self else { return }
                
                // Show loading indicator
                self.showLoading(true)
                
                Task {
                    do {
                        // Create playlist in database
                        let playlistId = try await self.createPlaylistInDatabase(name: name, image: pickedImage)
                        
                        // Create local playlist object with signed URL or local file
                        let id: String
                        if let image = pickedImage {
                            do {
                                let session = try await SupabaseManager.shared.client.auth.session
                                let userId = session.user.id
                                id = try await self.uploadImageToStorage(image: image, userId: userId)
                            } catch {
                                print("Image upload failed, saving locally: \(error)")
                                id = self.saveImageToDocuments(image: image) ?? "cl_1"
                            }
                        } else {
                            id = "cl_1"
                        }
                        
                        let newPlaylist = Playlist(
                            id: playlistId,
                            title: name,
                            imageIdentifier: id,
                            tags: "Custom Playlist",
                            trackCount: 0
                        )
                        
                        DispatchQueue.main.async {
                            self.playlists.insert(newPlaylist, at: 0)
                            self.collectionView.reloadData()
                            self.showLoading(false)
                        }
                        
                    } catch {
                        print("Error creating playlist: \(error)")
                        DispatchQueue.main.async {
                            self.showLoading(false)
                            let alert = UIAlertController(
                                title: "Error",
                                message: "Failed to create playlist. Please try again.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(alert, animated: true)
                        }
                    }
                }
            }
            
            present(addVC, animated: true)
        }
    }
    
    @objc private func didTapDelete() {
        // Toggle selection mode
        isSelectionMode.toggle()
    }
    
    private func confirmDeletion() {
        let selectedPlaylists = playlists.filter { $0.isSelectedForDeletion }
        
        guard !selectedPlaylists.isEmpty else {
            // No playlists selected, exit selection mode
            isSelectionMode = false
            return
        }
        
        let alert = UIAlertController(
            title: "Delete Playlists",
            message: "Are you sure you want to delete \(selectedPlaylists.count) playlist(s)?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            // Just exit selection mode without deleting
            self.isSelectionMode = false
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteSelectedPlaylists()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteSelectedPlaylists() {
        let selectedPlaylists = playlists.filter { $0.isSelectedForDeletion }
        var indexesToDelete: [IndexPath] = []
        
        // Collect indexes of selected playlists
        for (index, playlist) in playlists.enumerated() {
            if playlist.isSelectedForDeletion {
                indexesToDelete.append(IndexPath(item: index, section: 0))
            }
        }
        
        // Show loading indicator
        showLoading(true)
        
        Task {
            do {
                for playlist in selectedPlaylists {
                    // Delete from database
                    try await SupabaseManager.shared.client
                        .from("playlists")
                        .delete()
                        .eq("id", value: playlist.id)
                        .execute()
                    
                    // If playlist has a storage image, try to delete it
                    if playlist.imageIdentifier.contains("token=") || playlist.imageIdentifier.hasPrefix("https://") {
                        // Extract filename from URL
                        if let url = URL(string: playlist.imageIdentifier),
                           let fileName = url.pathComponents.last?.components(separatedBy: "?").first {
                            try? await SupabaseManager.shared.client.storage
                                .from("playlistcover")
                                .remove(paths: [fileName])
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    // Remove selected playlists from data source
                    self.playlists.removeAll { $0.isSelectedForDeletion }
                    
                    // Exit selection mode
                    self.isSelectionMode = false
                    
                    // Update collection view with animation
                    self.collectionView.deleteItems(at: indexesToDelete)
                    self.showLoading(false)
                    
                    // Show success message
                    let alert = UIAlertController(
                        title: "Success",
                        message: "\(selectedPlaylists.count) playlist(s) deleted successfully.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
                
            } catch {
                print("Error deleting playlists: \(error)")
                DispatchQueue.main.async {
                    self.showLoading(false)
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to delete playlists. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - Database Operations
    @objc private func refreshPlaylists() {
        loadPlaylists()
    }
    
    private func loadPlaylists() {
        activityIndicator.startAnimating()
        
        Task {
            do {
                // Get current user ID from auth
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id
                
                print("Loading playlists for user: \(userId)")
                
                // Fetch playlists for the current user
                let dbPlaylists: [DBPlaylist] = try await SupabaseManager.shared.client
                    .from("playlists")
                    .select()
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                
                print("Fetched \(dbPlaylists.count) playlists from database")
                
                // Convert DB models to local models
                var loadedPlaylists: [Playlist] = []
                
                for dbPlaylist in dbPlaylists {
                    let imageIdentifier = dbPlaylist.coverImageUrl ?? "cl_1"
                    
                    let playlist = Playlist(
                        id: dbPlaylist.id,
                        title: dbPlaylist.name,
                        imageIdentifier: imageIdentifier,
                        tags: dbPlaylist.description ?? "Custom Playlist",
                        trackCount: 0,
                        createdAt: dbPlaylist.createdAt,
                        isPublic: dbPlaylist.isPublic
                    )
                    loadedPlaylists.append(playlist)
                }
                
                // Add default playlists only if no user playlists exist
                if loadedPlaylists.isEmpty {
                    let defaultPlaylists = [
                        Playlist(title: "Silent Waves", imageIdentifier: "cl_2", tags: "Lo-fi Ambient Acoustic Chill", trackCount: 12),
                        Playlist(title: "Beast Mode Beats", imageIdentifier: "cl_3", tags: "Blaze Surge Rush Fuel", trackCount: 9),
                        Playlist(title: "Midnight Flow", imageIdentifier: "cl_4", tags: "Ambient Chillwave Jazzy Groovy", trackCount: 14),
                        Playlist(title: "Focus Mode", imageIdentifier: "cl_5", tags: "Study Chill Relax", trackCount: 10),
                        Playlist(title: "Deep Travel", imageIdentifier: "cl_1", tags: "Soul Indie Acoustic", trackCount: 8),
                    ]
                    loadedPlaylists = defaultPlaylists
                }
                
                DispatchQueue.main.async {
                    self.playlists = loadedPlaylists
                    self.activityIndicator.stopAnimating()
                    self.refreshControl.endRefreshing()
                }
                
            } catch {
                print("Error loading playlists: \(error)")
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.refreshControl.endRefreshing()
                    
                    // Show default playlists on error
                    self.playlists = [
                        Playlist(title: "Silent Waves", imageIdentifier: "cl_2", tags: "Lo-fi Ambient Acoustic Chill", trackCount: 12),
                        Playlist(title: "Beast Mode Beats", imageIdentifier: "cl_3", tags: "Blaze Surge Rush Fuel", trackCount: 9),
                        Playlist(title: "Midnight Flow", imageIdentifier: "cl_4", tags: "Ambient Chillwave Jazzy Groovy", trackCount: 14),
                        Playlist(title: "Focus Mode", imageIdentifier: "cl_5", tags: "Study Chill Relax", trackCount: 10),
                        Playlist(title: "Deep Travel", imageIdentifier: "cl_1", tags: "Soul Indie Acoustic", trackCount: 8),
                    ]
                    
                    // Show error alert
                    let alert = UIAlertController(
                        title: "Connection Error",
                        message: "Could not load playlists. Using local data.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func createPlaylistInDatabase(name: String, image: UIImage?) async throws -> UUID {
        // Get current user
        let session = try await SupabaseManager.shared.client.auth.session
        let userId = session.user.id
        
        var coverImageUrl: String? = nil
        
        // Upload image to storage if provided
        if let image = image {
            do {
                coverImageUrl = try await uploadImageToStorage(image: image, userId: userId)
            } catch {
                print("Image upload failed, continuing without image: \(error)")
                // Save locally as fallback
                if let localFile = saveImageToDocuments(image: image) {
                    coverImageUrl = localFile
                }
            }
        }
        
        // Create playlist in database
        let newPlaylist = DBPlaylist(
            id: UUID(),
            userId: userId,
            name: name,
            description: "Custom Playlist",
            coverImageUrl: coverImageUrl,
            isPublic: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        print("Inserting playlist to database: \(newPlaylist)")
        
        do {
            let inserted: DBPlaylist = try await SupabaseManager.shared.client
                .from("playlists")
                .insert(newPlaylist)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Created playlist with ID: \(inserted.id)")
            return inserted.id
        } catch {
            print("❌ Database insert error: \(error)")
            throw error
        }
    }
    
    private func uploadImageToStorage(image: UIImage, userId: UUID) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ImageConversionError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        print("📤 Uploading: \(fileName), Size: \(imageData.count) bytes")
        
        do {
            // First, check authentication
            let session = try await SupabaseManager.shared.client.auth.session
            print("✅ User authenticated: \(session.user.id)")
            
            // Upload to Supabase Storage
            print("🔄 Starting upload...")
            try await SupabaseManager.shared.client.storage
                .from("playlistcover")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )
            
            print("✅ Upload successful")
            
            // Get signed URL for private bucket
            print("🔄 Getting signed URL...")
            let signedUrl = try await SupabaseManager.shared.client.storage
                .from("playlistcover")
                .createSignedURL(
                    path: fileName,
                    expiresIn: 31536000 // 1 year expiry
                )
            
            print("✅ Signed URL created: \(signedUrl.absoluteString)")
            return signedUrl.absoluteString
            
        } catch {
            print("❌ Upload error details:")
            print("Error: \(error)")
            
            if let urlError = error as? URLError {
                print("URL Error code: \(urlError.errorCode)")
            }
            
            throw error
        }
    }
    
    private func showLoading(_ show: Bool) {
        DispatchQueue.main.async {
            if show {
                self.activityIndicator.startAnimating()
                self.view.isUserInteractionEnabled = false
            } else {
                self.activityIndicator.stopAnimating()
                self.view.isUserInteractionEnabled = true
            }
        }
    }
    
    // MARK: - Collection View Setup
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        
        if isPad {
            // iPad: Grid layout with 2-3 columns depending on orientation
            let spacing: CGFloat = 20
            let itemWidth = (view.bounds.width - (3 * spacing)) / 2
            layout.itemSize = CGSize(width: itemWidth, height: 150)
            layout.minimumInteritemSpacing = spacing
            layout.minimumLineSpacing = spacing
            layout.sectionInset = UIEdgeInsets(top: 20, left: spacing, bottom: 100, right: spacing)
        } else {
            // iPhone: Single column list layout
            layout.itemSize = CGSize(width: view.bounds.width - 32, height: 130)
            layout.minimumInteritemSpacing = 0
            layout.minimumLineSpacing = 10
            layout.sectionInset = UIEdgeInsets(top: 10, left: 16, bottom: 100, right: 16)
        }
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PlaylistCollectionViewCell.self, forCellWithReuseIdentifier: "PlaylistCell")
        
        collectionView.backgroundColor = .white
        collectionView.alwaysBounceVertical = true
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: isPad ? 20 : 18),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - File saving helper (for local fallback)
    private func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.pngData() else { return nil }
        let filename = "doc_\(UUID().uuidString).png"
        let url = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask).first!.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            print("Failed to save image to documents:", error)
            return nil
        }
    }
    
    fileprivate func loadImage(identifier: String) -> UIImage? {
        // Check if it's a signed URL (contains "token=" or is a https URL)
        if identifier.contains("token=") || identifier.hasPrefix("https://") {
            // Return placeholder, will be loaded asynchronously
            return UIImage(named: "cl_1")
        }
        
        // Check if it's a local asset
        if let img = UIImage(named: identifier) { return img }
        
        // Check if it's a document file
        let url = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask).first!.appendingPathComponent(identifier)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        
        // Fallback to default
        return UIImage(named: "cl_1")
    }
}

// MARK: - Collection View Delegate & DataSource
extension PlaylistViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return playlists.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaylistCell", for: indexPath) as! PlaylistCollectionViewCell
        var playlist = playlists[indexPath.item]
        
        // Configure selection indicator
        cell.selectionOverlay.isHidden = !isSelectionMode || !playlist.isSelectedForDeletion
        
        // Load initial placeholder
        cell.configure(withTitle: playlist.title, tags: playlist.tags, trackCount: playlist.trackCount, image: UIImage(named: "cl_1"))
        
        // If it's a signed URL, load it asynchronously
        if playlist.imageIdentifier.contains("token=") || playlist.imageIdentifier.hasPrefix("https://") {
            ImageLoader.shared.loadImage(from: playlist.imageIdentifier) { image in
                DispatchQueue.main.async {
                    // Make sure we're still looking at the same cell
                    if let currentCell = collectionView.cellForItem(at: indexPath) as? PlaylistCollectionViewCell {
                        currentCell.playlistImageView.image = image ?? UIImage(named: "cl_1")
                    }
                }
            }
        } else {
            // Load local image
            let img = loadImage(identifier: playlist.imageIdentifier)
            cell.configure(withTitle: playlist.title, tags: playlist.tags, trackCount: playlist.trackCount, image: img)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            // Toggle selection for deletion
            var playlist = playlists[indexPath.item]
            playlist.isSelectedForDeletion.toggle()
            playlists[indexPath.item] = playlist
            
            // Update cell
            if let cell = collectionView.cellForItem(at: indexPath) as? PlaylistCollectionViewCell {
                cell.selectionOverlay.isHidden = !playlist.isSelectedForDeletion
            }
            
            collectionView.deselectItem(at: indexPath, animated: true)
        } else {
            // Normal tap - go to playlist detail
            collectionView.deselectItem(at: indexPath, animated: true)
            
            let playlist = playlists[indexPath.item]
            let vc = PlaylistDetailViewController()
            
            // Set title and tags immediately
            vc.passedTitle = playlist.title
            vc.passedArtist = playlist.tags
            
            // Load image asynchronously if needed
            if playlist.imageIdentifier.contains("token=") || playlist.imageIdentifier.hasPrefix("https://") {
                ImageLoader.shared.loadImage(from: playlist.imageIdentifier) { image in
                    DispatchQueue.main.async {
                        vc.passedImage = image ?? UIImage(named: "cl_1")
                    }
                }
            } else {
                vc.passedImage = loadImage(identifier: playlist.imageIdentifier)
            }
            
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // MARK: - Collection View Layout (for iPad responsive design)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard isPad else {
            // iPhone: single column
            return CGSize(width: collectionView.bounds.width - 32, height: 130)
        }
        
        // iPad: adaptive columns
        let spacing: CGFloat = 20
        let availableWidth = collectionView.bounds.width - (3 * spacing)
        
        // Calculate number of columns based on width
        let minColumnWidth: CGFloat = 300
        let maxColumns = Int(availableWidth / minColumnWidth)
        let columns = max(2, maxColumns)
        
        let itemWidth = (availableWidth - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
        return CGSize(width: itemWidth, height: 150)
    }
}

// MARK: - Playlist Collection View Cell
class PlaylistCollectionViewCell: UICollectionViewCell {
    
    let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        v.layer.cornerRadius = 20
        v.clipsToBounds = true
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.1
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 4
        return v
    }()
    
    let playlistImageView = UIImageView()
    private let titleLabel = UILabel()
    private let tagsLabel = UILabel()
    private let trackCountLabel = UILabel()
    let selectionOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
        v.layer.cornerRadius = 20
        v.layer.borderColor = UIColor.systemRed.cgColor
        v.layer.borderWidth = 2
        v.isHidden = true
        return v
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = .clear
        
        playlistImageView.contentMode = .scaleAspectFill
        playlistImageView.layer.cornerRadius = UIDevice.current.userInterfaceIdiom == .pad ? 14 : 16
        playlistImageView.clipsToBounds = true
        
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        titleLabel.font = isPad ? .boldSystemFont(ofSize: 20) : .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        
        tagsLabel.font = isPad ? .systemFont(ofSize: 15) : .systemFont(ofSize: 13)
        tagsLabel.textColor = .lightGray
        tagsLabel.numberOfLines = 2
        
        trackCountLabel.font = isPad ? .systemFont(ofSize: 14) : .systemFont(ofSize: 13)
        trackCountLabel.textColor = .white
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, tagsLabel, trackCountLabel])
        stack.axis = .vertical
        stack.spacing = isPad ? 6 : 4
        stack.alignment = .leading
        
        contentView.addSubview(containerView)
        containerView.addSubview(playlistImageView)
        containerView.addSubview(stack)
        containerView.addSubview(selectionOverlay)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        playlistImageView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        
        let imageSize: CGFloat = isPad ? 80 : 70
        let padding: CGFloat = isPad ? 20 : 15
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            playlistImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            playlistImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playlistImageView.widthAnchor.constraint(equalToConstant: imageSize),
            playlistImageView.heightAnchor.constraint(equalToConstant: imageSize),
            
            stack.leadingAnchor.constraint(equalTo: playlistImageView.trailingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            stack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            selectionOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    func configure(withTitle title: String, tags: String, trackCount: Int, image: UIImage?) {
        titleLabel.text = title
        tagsLabel.text = tags
        trackCountLabel.text = "Tracks - \(trackCount)"
        playlistImageView.image = image ?? UIImage(named: "cl_1")
    }
}

// MARK: - AddPlaylistViewController (Updated for iPad)
class AddPlaylistViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // callback
    var onSave: ((_ name: String, _ image: UIImage?) -> Void)?
    
    private let dimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        return v
    }()
    
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 20
        v.clipsToBounds = true
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.2
        v.layer.shadowRadius = 10
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        return v
    }()
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Create Playlist"
        l.font = UIDevice.current.userInterfaceIdiom == .pad ? .boldSystemFont(ofSize: 22) : .boldSystemFont(ofSize: 18)
        l.textAlignment = .center
        return l
    }()
    
    private let nameField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Playlist name"
        tf.borderStyle = .roundedRect
        tf.font = UIDevice.current.userInterfaceIdiom == .pad ? .systemFont(ofSize: 18) : .systemFont(ofSize: 16)
        return tf
    }()
    
    private let imageViewPreview: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.systemGray5
        return iv
    }()
    
    private let pickImageButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Choose Image", for: .normal)
        b.titleLabel?.font = UIDevice.current.userInterfaceIdiom == .pad ? .systemFont(ofSize: 18) : .systemFont(ofSize: 16)
        return b
    }()
    
    private let saveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Save", for: .normal)
        b.titleLabel?.font = UIDevice.current.userInterfaceIdiom == .pad ? .boldSystemFont(ofSize: 20) : .boldSystemFont(ofSize: 16)
        return b
    }()
    
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.titleLabel?.font = UIDevice.current.userInterfaceIdiom == .pad ? .systemFont(ofSize: 18) : .systemFont(ofSize: 16)
        return b
    }()
    
    private var pickedImage: UIImage?
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        dimView.addGestureRecognizer(tap)
    }
    
    private func setupUI() {
        view.addSubview(dimView)
        view.addSubview(cardView)
        
        dimView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        cardView.addSubview(titleLabel)
        cardView.addSubview(nameField)
        cardView.addSubview(imageViewPreview)
        cardView.addSubview(pickImageButton)
        cardView.addSubview(saveButton)
        cardView.addSubview(cancelButton)
        
        [titleLabel, nameField, imageViewPreview, pickImageButton, saveButton, cancelButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        let cardWidth: CGFloat = isPad ? 500 : 300
        let cardPadding: CGFloat = isPad ? 40 : 28
        
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.widthAnchor.constraint(equalToConstant: cardWidth),
        ])
        
        let verticalPadding: CGFloat = isPad ? 30 : 18
        let horizontalPadding: CGFloat = isPad ? 32 : 16
        let elementSpacing: CGFloat = isPad ? 20 : 12
        let buttonHeight: CGFloat = isPad ? 50 : 44
        let fieldHeight: CGFloat = isPad ? 50 : 40
        let imageHeight: CGFloat = isPad ? 180 : 140
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: verticalPadding),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: horizontalPadding),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -horizontalPadding),
            
            nameField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: elementSpacing),
            nameField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: horizontalPadding),
            nameField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -horizontalPadding),
            nameField.heightAnchor.constraint(equalToConstant: fieldHeight),
            
            imageViewPreview.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: elementSpacing),
            imageViewPreview.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: horizontalPadding),
            imageViewPreview.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -horizontalPadding),
            imageViewPreview.heightAnchor.constraint(equalToConstant: imageHeight),
            
            pickImageButton.topAnchor.constraint(equalTo: imageViewPreview.bottomAnchor, constant: elementSpacing),
            pickImageButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            
            saveButton.topAnchor.constraint(equalTo: pickImageButton.bottomAnchor, constant: elementSpacing),
            saveButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: horizontalPadding),
            saveButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -verticalPadding),
            saveButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            
            cancelButton.topAnchor.constraint(equalTo: pickImageButton.bottomAnchor, constant: elementSpacing),
            cancelButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -horizontalPadding),
            cancelButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -verticalPadding),
            cancelButton.heightAnchor.constraint(equalToConstant: buttonHeight),
        ])
        
        pickImageButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func pickImage() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = self
        if isPad {
            picker.modalPresentationStyle = .popover
            if let popover = picker.popoverPresentationController {
                popover.sourceView = pickImageButton
                popover.sourceRect = pickImageButton.bounds
            }
        }
        present(picker, animated: true)
    }
    
    @objc private func saveTapped() {
        guard let name = nameField.text, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            let alert = UIAlertController(title: "Name Required", message: "Please enter playlist name.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        onSave?(name, pickedImage)
        dismiss(animated: true)
    }
    
    @objc private func dismissSelf() { dismiss(animated: true) }
    
    // MARK: - Image Picker Delegate
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let edited = info[.editedImage] as? UIImage {
            pickedImage = edited
            imageViewPreview.image = edited
        } else if let original = info[.originalImage] as? UIImage {
            pickedImage = original
            imageViewPreview.image = original
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

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
    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()
    
    // MARK: - Floating Button
    private let floatingButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.orange
        btn.setImage(UIImage(systemName: "plus"), for: .normal)
        btn.tintColor = .white
        
        btn.layer.cornerRadius = 30
        btn.clipsToBounds = false
        
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.25
        btn.layer.shadowRadius = 6
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
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
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFloatingButton()
        setupActivityIndicator()
        setupRefreshControl()
        loadPlaylists()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPlaylists()
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupTableView()
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
        tableView.refreshControl = refreshControl
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
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }
    
    // MARK: - Floating Button
    private func setupFloatingButton() {
        view.addSubview(floatingButton)
        floatingButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            floatingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            floatingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -26),
            floatingButton.widthAnchor.constraint(equalToConstant: 60),
            floatingButton.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        floatingButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)
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
    
    // MARK: - Add Playlist
    @objc private func didTapAdd() {
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
                        self.tableView.reloadData()
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
    
    // MARK: - Table View Setup
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlaylistTableViewCell.self, forCellReuseIdentifier: "PlaylistCell")
        
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.rowHeight = 130
        
        // Add padding so FAB doesn't overlap first card
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 30, right: 0)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 18),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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

// MARK: - Table Delegate
extension PlaylistViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { playlists.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath) as! PlaylistTableViewCell
        let p = playlists[indexPath.row]
        
        // Load initial placeholder
        cell.configure(withTitle: p.title, tags: p.tags, trackCount: p.trackCount, image: UIImage(named: "cl_1"))
        
        // If it's a signed URL, load it asynchronously
        if p.imageIdentifier.contains("token=") || p.imageIdentifier.hasPrefix("https://") {
            ImageLoader.shared.loadImage(from: p.imageIdentifier) { image in
                DispatchQueue.main.async {
                    // Make sure we're still looking at the same cell
                    if let currentCell = tableView.cellForRow(at: indexPath) as? PlaylistTableViewCell {
                        currentCell.playlistImageView.image = image ?? UIImage(named: "cl_1")
                    }
                }
            }
        } else {
            // Load local image
            let img = loadImage(identifier: p.imageIdentifier)
            cell.configure(withTitle: p.title, tags: p.tags, trackCount: p.trackCount, image: img)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let playlist = playlists[indexPath.row]
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
    
    // MARK: - Swipe to delete
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Only allow deletion for user-created playlists (not default ones)
        let playlist = playlists[indexPath.row]
        return !playlist.imageIdentifier.hasPrefix("cl_") // Default playlists start with "cl_"
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let playlist = playlists[indexPath.row]
            deletePlaylist(playlist, at: indexPath)
        }
    }
    
    private func deletePlaylist(_ playlist: Playlist, at indexPath: IndexPath) {
        Task {
            do {
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
                
                DispatchQueue.main.async {
                    self.playlists.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
                
            } catch {
                print("Error deleting playlist: \(error)")
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to delete playlist.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - Playlist Cell
class PlaylistTableViewCell: UITableViewCell {
    
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        v.layer.cornerRadius = 20
        v.clipsToBounds = true
        return v
    }()
    
    let playlistImageView = UIImageView()
    private let titleLabel = UILabel()
    private let tagsLabel = UILabel()
    private let trackCountLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        playlistImageView.contentMode = .scaleAspectFill
        playlistImageView.layer.cornerRadius = 16
        playlistImageView.clipsToBounds = true
        
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white
        
        tagsLabel.font = .systemFont(ofSize: 13)
        tagsLabel.textColor = .lightGray
        
        trackCountLabel.font = .systemFont(ofSize: 13)
        trackCountLabel.textColor = .white
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, tagsLabel, trackCountLabel])
        stack.axis = .vertical
        stack.spacing = 3
        
        contentView.addSubview(containerView)
        containerView.addSubview(playlistImageView)
        containerView.addSubview(stack)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        playlistImageView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            playlistImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            playlistImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playlistImageView.widthAnchor.constraint(equalToConstant: 70),
            playlistImageView.heightAnchor.constraint(equalToConstant: 70),
            
            stack.leadingAnchor.constraint(equalTo: playlistImageView.trailingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    func configure(withTitle title: String, tags: String, trackCount: Int, image: UIImage?) {
        titleLabel.text = title
        tagsLabel.text = tags
        trackCountLabel.text = "Tracks - \(trackCount)"
        playlistImageView.image = image ?? UIImage(named: "cl_1")
    }
}

// MARK: - AddPlaylistViewController
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
        v.layer.cornerRadius = 16
        v.clipsToBounds = true
        return v
    }()
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Create Playlist"
        l.font = .boldSystemFont(ofSize: 18)
        l.textAlignment = .center
        return l
    }()
    
    private let nameField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Playlist name"
        tf.borderStyle = .roundedRect
        return tf
    }()
    
    private let imageViewPreview: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 10
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.systemGray5
        return iv
    }()
    
    private let pickImageButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Choose Image", for: .normal)
        return b
    }()
    
    private let saveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Save", for: .normal)
        b.titleLabel?.font = .boldSystemFont(ofSize: 16)
        return b
    }()
    
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        return b
    }()
    
    private var pickedImage: UIImage?
    
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
        
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
        ])
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            nameField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            nameField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            nameField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            nameField.heightAnchor.constraint(equalToConstant: 40),
            
            imageViewPreview.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 12),
            imageViewPreview.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            imageViewPreview.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            imageViewPreview.heightAnchor.constraint(equalToConstant: 140),
            
            pickImageButton.topAnchor.constraint(equalTo: imageViewPreview.bottomAnchor, constant: 12),
            pickImageButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            
            saveButton.topAnchor.constraint(equalTo: pickImageButton.bottomAnchor, constant: 12),
            saveButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            saveButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 44),
            
            cancelButton.topAnchor.constraint(equalTo: pickImageButton.bottomAnchor, constant: 12),
            cancelButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            cancelButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
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

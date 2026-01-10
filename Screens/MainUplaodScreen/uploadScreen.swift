//
//  UploadScreen.swift
//  Re-Hearse_v1
//

import UIKit
import AVFoundation
import Photos
import Supabase

class UploadScreen: UIViewController {
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 20
        static let elementSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 14
        static let buttonHeight: CGFloat = 52
        static let uploadContainerHeight: CGFloat = 300
        static let cardSize = CGSize(width: 140, height: 160)
        static let carouselHeight: CGFloat = 180
        static let metaCoverSize: CGFloat = 56
        static let metaCornerRadius: CGFloat = metaCoverSize / 2 // circular
    }
    
    // MARK: - State / Data
    private var uploadTitle: String = "Untitled"
    private var uploadCoverImage: UIImage? = UIImage(systemName: "music.note")
    private var currentUploadData: Data? // Store uploaded file data
    private var currentFileName: String = ""
    private var currentFileType: String = ""
    
    private var metaTitleLbl: UILabel?
    private var metaCoverImgView: UIImageView?
    private var recentHStack: UIStackView?
    
    // Use shared Supabase client
    private var supabase: SupabaseClient {
        return SupabaseManager.shared.client
    }
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(title: "Upload")
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    private let uploadContainer = UIView()
    private let uploadIcon = UIImageView()
    private let uploadLabel = UILabel()
    private let uploadButton = UIButton()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupScrollView()
        addUploadMetaSection()
        setupUploadSection()
        addRecentUploadsSection()
        
        // Load real recent uploads from database
        loadRecentUploadsFromDB()
    }
    
    // MARK: - Database Methods
    
    private func loadRecentUploadsFromDB() {
        Task {
            do {
                let recentUploads = try await fetchRecentUploadsFromDatabase()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.displayRecentUploads(recentUploads)
                }
            } catch {
                print("Error loading recent uploads: \(error)")
                // Fallback to sample data if needed
                DispatchQueue.main.async {
                    self.addRecentUploadCard(title: "Sample Upload", image: UIImage(named: "cl_1"))
                }
            }
        }
    }
    
    private func fetchRecentUploadsFromDatabase() async throws -> [Scan] {
        // First, let's test if we can get the current user ID
        guard let userIdString = await getCurrentUserId() else {
            print("No user ID found")
            return []
        }
        
        guard let userId = UUID(uuidString: userIdString) else {
            print("Invalid user ID format: \(userIdString)")
            return []
        }
        
        print("Fetching scans for user ID: \(userId)")
        
        do {
            let response: [Scan] = try await supabase
                .from("scans")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false)
                .limit(5)
                .execute()
                .value
            
            print("Successfully fetched \(response.count) scans")
            return response
        } catch {
            print("Error fetching scans: \(error)")
            throw error
        }
    }
    
    private func getCurrentUserId() async -> String? {
        do {
            // Get current session from Supabase
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch {
            print("Error getting user session: \(error)")
            return nil
        }
    }
    private func displayRecentUploads(_ scans: [Scan]) {
        guard let hStack = recentHStack else { return }
        
        // Clear existing cards
        for view in hStack.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        // Add cards from database
        for scan in scans {
            let title = extractTitle(from: scan.jsonData) ?? scan.originalFilename ?? "Untitled"
            // You might want to store thumbnail URLs in JSON or use a placeholder
            addRecentUploadCard(title: title, image: UIImage(named: "cl_1"))
        }
        
        // If no uploads, show empty state
        if scans.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No recent uploads"
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.textAlignment = .center
            hStack.addArrangedSubview(emptyLabel)
        }
    }
    
    private func extractTitle(from jsonData: AnyCodable?) -> String? {
        guard let jsonData = jsonData else { return nil }
        
        // Access the underlying value
        if let dict = jsonData.value as? [String: Any] {
            return dict["title"] as? String
        }
        return nil
    }
    
    private func saveUploadToDatabase(imageData: Data, fileName: String, fileType: String) async throws {
        print("Starting upload process...")
        
        // 1. Create a unique processing ID
        let processingId = "proc_\(UUID().uuidString)"
        
        // 2. Get user ID
        guard let userIdString = await getCurrentUserId(),
              let userId = UUID(uuidString: userIdString) else {
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"])
        }
        
        print("User ID: \(userId)")
        
        // 3. Create JSON data
        let jsonDict: [String: Any] = [
            "status": "processing",
            "filename": fileName,
            "uploaded_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let initialScan = ScanInsert(
            userId: userId,
            jsonData: AnyCodable(jsonDict),
            processingId: processingId,
            status: "processing",
            originalFilename: fileName,
            fileType: fileType
        )
        
        print("Inserting scan record...")
        
        do {
            let response: Scan = try await supabase
                .from("scans")
                .insert(initialScan)
                .select()
                .single()
                .execute()
                .value
            
            print("Scan record inserted successfully with ID: \(response.id)")
            
            let createdScan = response
            
            // 4. Simulate API call to external cloud processing
            print("Simulating API call to cloud processing service...")
            
            // Simulate processing delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // 5. Simulate getting JSON response from cloud
            let mockJsonResponse: [String: Any] = [
                "title": uploadTitle,
                "documentType": "image_scan",
                "filename": fileName,
                "fileType": fileType,
                "size": imageData.count,
                "processedAt": ISO8601DateFormatter().string(from: Date()),
                "confidence": 0.95,
                "status": "completed",
                "analysis": [
                    "chords": ["C", "G", "Am", "F"],
                    "key": "C Major",
                    "tempo": "120 BPM"
                ]
            ]
            
            print("Updating scan with processing results...")
            
            // 6. Update the database with the JSON result
            try await updateScanInDatabase(
                scanId: createdScan.id,
                jsonData: mockJsonResponse,
                processingId: processingId
            )
            
            print("Scan updated successfully!")
            
        } catch {
            print("Error in saveUploadToDatabase: \(error)")
            throw error
        }
        
        // 7. Refresh recent uploads
        await loadRecentUploadsFromDB()
    }
    
    private func updateScanInDatabase(scanId: Int64, jsonData: [String: Any], processingId: String) async throws {
        let updateData = UpdateScanData(
            jsonData: AnyCodable(jsonData),
            status: "completed",
            processedAt: ISO8601DateFormatter().string(from: Date()),
            processingId: processingId,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            try await supabase
                .from("scans")
                .update(updateData)
                .eq("id", value: String(scanId))
                .execute()
            
            print("Database update successful for scan ID: \(scanId)")
        } catch {
            print("Error updating scan in database: \(error)")
            throw error
        }
    }
    
    // MARK: - Data Models
    struct Scan: Codable, Identifiable {
        let id: Int64
        let userId: UUID
        let jsonData: AnyCodable?
        let processingId: String?
        let status: String?
        let originalFilename: String?
        let fileType: String?
        let processedAt: String?
        let updatedAt: String?
        let errorMessage: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case jsonData = "json_data"
            case processingId = "processing_id"
            case status
            case originalFilename = "original_filename"
            case fileType = "file_type"
            case processedAt = "processed_at"
            case updatedAt = "updated_at"
            case errorMessage = "error_message"
        }
    }
    
    struct ScanInsert: Encodable {
        let userId: UUID
        let jsonData: AnyCodable
        let processingId: String
        let status: String
        let originalFilename: String?
        let fileType: String?
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case jsonData = "json_data"
            case processingId = "processing_id"
            case status
            case originalFilename = "original_filename"
            case fileType = "file_type"
        }
    }
    
    struct UpdateScanData: Encodable {
        let jsonData: AnyCodable
        let status: String
        let processedAt: String
        let processingId: String
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case jsonData = "json_data"
            case status
            case processedAt = "processed_at"
            case processingId = "processing_id"
            case updatedAt = "updated_at"
        }
    }
    
    // MARK: - AnyCodable helper for handling dynamic JSON
    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let boolValue = try? container.decode(Bool.self) {
                value = boolValue
            } else if let intValue = try? container.decode(Int.self) {
                value = intValue
            } else if let doubleValue = try? container.decode(Double.self) {
                value = doubleValue
            } else if let stringValue = try? container.decode(String.self) {
                value = stringValue
            } else if let arrayValue = try? container.decode([AnyCodable].self) {
                value = arrayValue.map { $0.value }
            } else if let dictValue = try? container.decode([String: AnyCodable].self) {
                value = dictValue.mapValues { $0.value }
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch value {
            case let boolValue as Bool:
                try container.encode(boolValue)
            case let intValue as Int:
                try container.encode(intValue)
            case let doubleValue as Double:
                try container.encode(doubleValue)
            case let stringValue as String:
                try container.encode(stringValue)
            case let arrayValue as [Any]:
                let anyCodableArray = arrayValue.map { AnyCodable($0) }
                try container.encode(anyCodableArray)
            case let dictValue as [String: Any]:
                let anyCodableDict = dictValue.mapValues { AnyCodable($0) }
                try container.encode(anyCodableDict)
            default:
                let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value of type \(type(of: value))")
                throw EncodingError.invalidValue(value, context)
            }
        }
    }
    
    // MARK: - NavBar
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.isChordIconVisible = true
        
        navBar.chordAction = { [weak self] in
            guard let self = self else { return }
            let vc = ChordRecognitionViewController()
            if let nav = self.navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                vc.modalPresentationStyle = .fullScreen
                self.present(vc, animated: true)
            }
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
    
    // MARK: - Scroll + Content stack
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        
        // contentView is the vertical UIStackView that holds sections
        scrollView.addSubview(contentView)
        contentView.axis = .vertical
        contentView.spacing = Constants.sectionSpacing
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Constrain contentView to scrollView using contentLayoutGuide and frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // contentView to contentLayoutGuide (vertical)
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 0),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: 0),
            
            // contentView to frameLayoutGuide (horizontal sizing)
            contentView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Constants.horizontalPadding),
            contentView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Constants.horizontalPadding),
            
            // ensure contentView width equals frame width minus padding so stack's arranged subviews layout properly
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Constants.horizontalPadding)
        ])
    }
    
    // MARK: - Upload Meta Section (circular thumbnail + title + Edit)
    private func addUploadMetaSection() {
        let metaStack = UIStackView()
        metaStack.axis = .horizontal
        metaStack.spacing = 14
        metaStack.alignment = .center
        metaStack.translatesAutoresizingMaskIntoConstraints = false
        
        // circular cover image
        let cover = UIImageView()
        cover.image = uploadCoverImage ?? UIImage(systemName: "music.note")
        cover.tintColor = .black
        cover.backgroundColor = UIColor(white: 0.95, alpha: 1)
        cover.clipsToBounds = true
        cover.layer.cornerRadius = 20
        cover.translatesAutoresizingMaskIntoConstraints = true
        metaCoverImgView = cover
        
        // title label
        let title = UILabel()
        title.text = uploadTitle
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false
        metaTitleLbl = title
        
        // edit button (shows action sheet)
        let editButton = UIButton(type: .system)
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        editButton.addTarget(self, action: #selector(showMetaEditor), for: .touchUpInside)
        
        metaStack.addArrangedSubview(cover)
        metaStack.addArrangedSubview(title)
        metaStack.addArrangedSubview(editButton)
        
        NSLayoutConstraint.activate([
            cover.widthAnchor.constraint(equalToConstant: 36),
            cover.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        contentView.addArrangedSubview(metaStack)
    }
    
    @objc private func showMetaEditor() {
        let ac = UIAlertController(title: "Edit Upload Info", message: nil, preferredStyle: .actionSheet)
        
        ac.addAction(UIAlertAction(title: "Edit Name", style: .default) { _ in
            self.askForTitle()
        })
        ac.addAction(UIAlertAction(title: "Change Cover Image", style: .default) { _ in
            self.presentImagePicker(sourceType: .photoLibrary, forCover: true)
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad popover anchor
        if let pop = ac.popoverPresentationController {
            pop.sourceView = metaCoverImgView ?? self.view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: 100, width: 0, height: 0)
        }
        present(ac, animated: true)
    }
    
    private func askForTitle() {
        let ac = UIAlertController(title: "Enter Title", message: nil, preferredStyle: .alert)
        ac.addTextField { tf in
            tf.placeholder = "Song Title"
            tf.text = self.uploadTitle
        }
        ac.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let newTitle = ac.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.uploadTitle = (newTitle?.isEmpty == false) ? newTitle! : "Untitled"
            self.metaTitleLbl?.text = self.uploadTitle
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    // MARK: - Upload Box (big drag/drop area + button)
    private func setupUploadSection() {
        // container
        uploadContainer.backgroundColor = .secondarySystemBackground
        uploadContainer.layer.cornerRadius = Constants.cornerRadius
        uploadContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // icon centered
        uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
        uploadIcon.tintColor = .black
        uploadIcon.contentMode = .scaleAspectFit
        uploadIcon.translatesAutoresizingMaskIntoConstraints = false
        
        // label
        uploadLabel.text = "Drag & drop or tap to upload"
        uploadLabel.font = .systemFont(ofSize: 14, weight: .regular)
        uploadLabel.textColor = .secondaryLabel
        uploadLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // upload button
        var cfg = UIButton.Configuration.filled()
        cfg.title = "Upload Files"
        cfg.image = UIImage(systemName: "camera.fill")
        cfg.baseBackgroundColor = .systemYellow
        cfg.baseForegroundColor = .black
        cfg.cornerStyle = .medium
        uploadButton.configuration = cfg
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)
        
        // add to stack
        contentView.addArrangedSubview(uploadContainer)
        contentView.addArrangedSubview(uploadButton)
        
        uploadContainer.addSubview(uploadIcon)
        uploadContainer.addSubview(uploadLabel)
        
        // constraints
        uploadContainer.heightAnchor.constraint(equalToConstant: Constants.uploadContainerHeight).isActive = true
        
        NSLayoutConstraint.activate([
            uploadIcon.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            uploadIcon.centerYAnchor.constraint(equalTo: uploadContainer.centerYAnchor, constant: -10),
            uploadIcon.widthAnchor.constraint(equalToConstant: 44),
            uploadIcon.heightAnchor.constraint(equalToConstant: 44),
            
            uploadLabel.topAnchor.constraint(equalTo: uploadIcon.bottomAnchor, constant: 8),
            uploadLabel.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            
            uploadButton.heightAnchor.constraint(equalToConstant: Constants.buttonHeight)
        ])
        
        // tap gesture for the entire container
        let tap = UITapGestureRecognizer(target: self, action: #selector(uploadTapped))
        uploadContainer.addGestureRecognizer(tap)
    }
    
    @objc private func uploadTapped() {
        showUploadOptions()
    }
    
    private func showUploadOptions() {
        let ac = UIAlertController(title: "Upload Content", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Take Photo", style: .default) { _ in self.presentImagePicker(sourceType: .camera) })
        ac.addAction(UIAlertAction(title: "Choose From Library", style: .default) { _ in self.presentImagePicker(sourceType: .photoLibrary) })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = ac.popoverPresentationController { pop.sourceView = uploadButton; pop.sourceRect = uploadButton.bounds }
        present(ac, animated: true)
    }
    
    // MARK: - Recent Uploads (horizontal scroll)
    private func addRecentUploadsSection() {
        let header = UILabel()
        header.text = "Recent Uploads"
        header.font = .systemFont(ofSize: 18, weight: .semibold)
        header.textColor = .label
        contentView.addArrangedSubview(header)
        
        // horizontal scroll view — must give it a constrained height so UIStackView sizes it
        let horizScroll = UIScrollView()
        horizScroll.translatesAutoresizingMaskIntoConstraints = false
        horizScroll.showsHorizontalScrollIndicator = false
        contentView.addArrangedSubview(horizScroll)
        
        NSLayoutConstraint.activate([
            horizScroll.heightAnchor.constraint(equalToConstant: Constants.carouselHeight)
        ])
        
        // hStack inside scroll's contentLayoutGuide
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = Constants.elementSpacing
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false
        recentHStack = hStack
        
        horizScroll.addSubview(hStack)
        
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: horizScroll.contentLayoutGuide.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: horizScroll.contentLayoutGuide.bottomAnchor),
            hStack.leadingAnchor.constraint(equalTo: horizScroll.contentLayoutGuide.leadingAnchor, constant: 10),
            hStack.trailingAnchor.constraint(equalTo: horizScroll.contentLayoutGuide.trailingAnchor, constant: -10),
            
            // ensure the stack's height matches the scroll's visible height
            hStack.heightAnchor.constraint(equalTo: horizScroll.frameLayoutGuide.heightAnchor)
        ])
    }
    
    // MARK: - Add card to recents (insert at 0)
    private func addRecentUploadCard(title: String, image: UIImage?) {
        guard let hStack = recentHStack else { return }
        let card = makeRecentCard(title: title, image: image)
        // insert at start
        hStack.insertArrangedSubview(card, at: 0)
    }
    
    private func makeRecentCard(title: String, image: UIImage?) -> UIView {
        // card container (with shadow)
        let card = UIButton(type: .system)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = Constants.cornerRadius
        card.clipsToBounds = false // allow shadow
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowRadius = 6
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        // circular inner image (center)
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = (image == nil) ? .scaleAspectFill : .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 20 // circular image radius
        iv.tintColor = .black
        iv.image = image ?? UIImage(systemName: "music.note")
        iv.backgroundColor = image == nil ? UIColor(white: 0.97, alpha: 1) : .clear
        
        // title label bottom
        let titleLbl = UILabel()
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 14, weight: .medium)
        titleLbl.textAlignment = .center
        titleLbl.numberOfLines = 2
        
        card.addSubview(iv)
        card.addSubview(titleLbl)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Constants.cardSize.width),
            card.heightAnchor.constraint(equalToConstant: Constants.cardSize.height),
            
            // center iv horizontally, slightly above center
            iv.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -10),
            iv.widthAnchor.constraint(equalToConstant: 80),
            iv.heightAnchor.constraint(equalToConstant: 80),
            
            // title at bottom with small padding
            titleLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            titleLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
            titleLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
        
        // action: navigate to detail when tapped
        card.addAction(UIAction(handler: { _ in
            let vc = UploadPageNextViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }), for: .touchUpInside)
        
        return card
    }
    
    // MARK: - Image picker helper
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType, forCover: Bool = false) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = sourceType
        picker.view.tag = forCover ? 999 : 0
        present(picker, animated: true)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension UploadScreen: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let picked = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        picker.dismiss(animated: true)
        
        if picker.view.tag == 999 {
            // user changed the meta cover image
            uploadCoverImage = picked
            metaCoverImgView?.image = uploadCoverImage
            return
        }
        
        // Normal upload flow - prepare data for database
        guard let image = picked else { return }
        
        // Convert image to Data
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            currentUploadData = imageData
            currentFileName = "upload_\(Date().timeIntervalSince1970).jpg"
            currentFileType = "image/jpeg"
            
            // Show loading state
            uploadIcon.image = UIImage(systemName: "arrow.clockwise")
            uploadLabel.text = "Processing upload..."
            
            // Simulate API flow and save to database
            Task {
                do {
                    print("Starting upload task...")
                    try await saveUploadToDatabase(
                        imageData: imageData,
                        fileName: currentFileName,
                        fileType: currentFileType
                    )
                    
                    print("Upload completed successfully!")
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        // Show success
                        self.uploadIcon.image = UIImage(systemName: "checkmark.circle.fill")
                        self.uploadLabel.text = "Upload completed!"
                        
                        // Reset after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                            self.uploadLabel.text = "Drag & drop or tap to upload"
                        }
                        
                        // Navigate to next page
                        let vc = UploadPageNextViewController()
                        if let nav = self.navigationController {
                            nav.pushViewController(vc, animated: true)
                        } else {
                            vc.modalPresentationStyle = .fullScreen
                            self.present(vc, animated: true)
                        }
                    }
                } catch {
                    print("Upload failed with error: \(error)")
                    print("Error details: \(error.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        // Show error with more details
                        self.uploadIcon.image = UIImage(systemName: "exclamationmark.triangle")
                        self.uploadLabel.text = "Upload failed"
                        
                        // Reset after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                            self.uploadLabel.text = "Drag & drop or tap to upload"
                        }
                        
                        // Show error alert with more details
                        let alert = UIAlertController(
                            title: "Upload Failed",
                            message: "Error: \(error.localizedDescription)\n\nPlease check your connection and try again.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

//
//  ProfileScreen.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase

struct Profile: Decodable {
    let id: UUID
    let full_name: String?
    let username: String?
    let avatar_url: String?
    let bio: String?
}

final class UserProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - UI
    private let navBar = UIView()
    private let backButton = UIButton(type: .system)

    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    // Header elements we update
    private let profileImageView = UIImageView()
    private let cameraBadgeView = UIView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let bioLabel = UILabel()
    private let editButton = UIButton(type: .system)
    
    // Data
    private var currentProfile: Profile?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.systemGroupedBackground
        navigationController?.navigationBar.isHidden = true

        setupNavBar()
        setupScroll()
        buildUI()
        view.bringSubviewToFront(navBar)
        
        loadProfile()
    }

    // MARK: - NAVBAR
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.backgroundColor = .clear

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .label
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(backButton)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 68),

            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - ScrollView
    private func setupScroll() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.alignment = .fill
        scrollView.contentInsetAdjustmentBehavior = .never

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Build Screen UI
    private func buildUI() {
        contentView.addArrangedSubview(buildHeader())
        contentView.setCustomSpacing(12, after: contentView.arrangedSubviews.last!)

        contentView.addArrangedSubview(buildStatsSection())
        // contentView.addArrangedSubview(buildPracticeGraphCard())
        contentView.addArrangedSubview(buildSavedSection())

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 36).isActive = true
        contentView.addArrangedSubview(spacer)
    }

    // MARK: - HEADER (DYNAMIC, NICER DESIGN)
    private func buildHeader() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let header = GradientHeaderView()
        header.layer.cornerRadius = 24
        header.layer.masksToBounds = true
        header.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(header)
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            header.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            header.heightAnchor.constraint(greaterThanOrEqualToConstant: 260)
        ])

        // Avatar container in center
        let avatarWrapper = UIView()
        avatarWrapper.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(avatarWrapper)
        
        // Profile image
        profileImageView.image = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .white
        profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
        profileImageView.layer.cornerRadius = 52
        profileImageView.clipsToBounds = true
        profileImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        profileImageView.layer.borderWidth = 3
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(changeAvatarTapped))
        )
        
        // Camera badge overlay
        cameraBadgeView.backgroundColor = .white
        cameraBadgeView.layer.cornerRadius = 16
        cameraBadgeView.layer.shadowColor = UIColor.black.cgColor
        cameraBadgeView.layer.shadowOpacity = 0.15
        cameraBadgeView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cameraBadgeView.layer.shadowRadius = 4
        cameraBadgeView.translatesAutoresizingMaskIntoConstraints = false
        
        let cameraIcon = UIImageView(image: UIImage(systemName: "camera.fill"))
        cameraIcon.tintColor = UIColor.systemOrange
        cameraIcon.contentMode = .scaleAspectFit
        cameraIcon.translatesAutoresizingMaskIntoConstraints = false
        cameraBadgeView.addSubview(cameraIcon)
        
        NSLayoutConstraint.activate([
            cameraIcon.centerXAnchor.constraint(equalTo: cameraBadgeView.centerXAnchor),
            cameraIcon.centerYAnchor.constraint(equalTo: cameraBadgeView.centerYAnchor),
            cameraIcon.widthAnchor.constraint(equalToConstant: 16),
            cameraIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        avatarWrapper.addSubview(profileImageView)
        avatarWrapper.addSubview(cameraBadgeView)
        
        NSLayoutConstraint.activate([
            avatarWrapper.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            avatarWrapper.topAnchor.constraint(equalTo: header.topAnchor, constant: 84),
            
            profileImageView.topAnchor.constraint(equalTo: avatarWrapper.topAnchor),
            profileImageView.leadingAnchor.constraint(equalTo: avatarWrapper.leadingAnchor),
            profileImageView.trailingAnchor.constraint(equalTo: avatarWrapper.trailingAnchor),
            profileImageView.heightAnchor.constraint(equalToConstant: 104),
            profileImageView.widthAnchor.constraint(equalToConstant: 104),
            
            cameraBadgeView.widthAnchor.constraint(equalToConstant: 32),
            cameraBadgeView.heightAnchor.constraint(equalToConstant: 32),
            cameraBadgeView.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 4),
            cameraBadgeView.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 4),
            
            avatarWrapper.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor)
        ])

        // Name
        nameLabel.text = "Loading..."
        nameLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        
        // Username
        usernameLabel.text = "@username"
        usernameLabel.font = .systemFont(ofSize: 14, weight: .regular)
        usernameLabel.textColor = .secondaryLabel
        usernameLabel.textAlignment = .center
        
        // Bio
        bioLabel.text = "Add a short bio about your music journey."
        bioLabel.font = .systemFont(ofSize: 13)
        bioLabel.textColor = .secondaryLabel
        bioLabel.textAlignment = .center
        bioLabel.numberOfLines = 2
        
        // Edit button
        editButton.setTitle("Edit Profile", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        editButton.setTitleColor(.white, for: .normal)
        editButton.backgroundColor = UIColor.systemOrange
        editButton.layer.cornerRadius = 16
        editButton.contentEdgeInsets = .init(top: 8, left: 20, bottom: 8, right: 20)
        editButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        
        let textStack = UIStackView(arrangedSubviews: [nameLabel, usernameLabel, bioLabel])
        textStack.axis = .vertical
        textStack.alignment = .center
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        header.addSubview(textStack)
        header.addSubview(editButton)
        
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: avatarWrapper.bottomAnchor, constant: 16),
            textStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),
            textStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -24),
            
            editButton.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 12),
            editButton.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            editButton.bottomAnchor.constraint(lessThanOrEqualTo: header.bottomAnchor, constant: -24)
        ])
        
        return container
    }

    // MARK: - STATS
    private func buildStatsSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .white
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        container.addSubview(card)
        
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let playlist = statView(number: "23", label: "PLAYLISTS")
        let followers = statView(number: "58", label: "FOLLOWERS")
        let following = statView(number: "43", label: "FOLLOWING")

        let stack = UIStackView(arrangedSubviews: [playlist, followers, following])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return container
    }

    private func statView(number: String, label: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4

        let num = UILabel()
        num.text = number
        num.font = .systemFont(ofSize: 18, weight: .semibold)
        num.textColor = .label

        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = .secondaryLabel

        stack.addArrangedSubview(num)
        stack.addArrangedSubview(lbl)
        return stack
    }

    // MARK: - PRACTICE GRAPH (placeholder)
    private func buildPracticeGraphCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.12, alpha: 1)
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false

        let streak = UILabel()
        streak.text = "__ day streak"
        streak.font = .systemFont(ofSize: 15, weight: .semibold)
        streak.textColor = UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1)

        let hours = UILabel()
        hours.text = "⏱️ __ hrs spent"
        hours.font = .systemFont(ofSize: 15, weight: .semibold)
        hours.textColor = .white

        let topRow = UIStackView(arrangedSubviews: [streak, hours])
        topRow.axis = .horizontal
        topRow.distribution = .equalSpacing

        let title = UILabel()
        title.text = "Practice Graph"
        title.font = .boldSystemFont(ofSize: 20)
        title.textColor = .white

        let graphBox = UIView()
        graphBox.backgroundColor = UIColor(white: 0.12, alpha: 1)
        graphBox.layer.cornerRadius = 16
        graphBox.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let stack = UIStackView(arrangedSubviews: [topRow, title, graphBox])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])

        return card
    }

    // MARK: - SAVED SECTION
    private func buildSavedSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .white
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        container.addSubview(card)
        
        let label = UILabel()
        label.text = "Saved"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        
        let stack = UIStackView(arrangedSubviews: [
            label,
            savedRow(title: "Shazam", likes: "7 likes"),
            savedRow(title: "Roadtrip", likes: "4 likes")
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return container
    }

    private func savedRow(title: String, likes: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "music.note.list"))
        icon.tintColor = .systemOrange
        icon.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
        icon.layer.cornerRadius = 12
        icon.clipsToBounds = true
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false

        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 16, weight: .medium)

        let l = UILabel()
        l.text = likes
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [t, l])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .tertiaryLabel
        arrow.translatesAutoresizingMaskIntoConstraints = false

        row.addSubviews(icon, textStack, arrow)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.heightAnchor.constraint(equalToConstant: 44),
            icon.widthAnchor.constraint(equalToConstant: 44),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            arrow.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            arrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.heightAnchor.constraint(equalToConstant: 60)
        ])

        return row
    }
}

// MARK: - Supabase: Load & Update Profile
private extension UserProfileViewController {
    
    func loadProfile() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run { self.nameLabel.text = "Not logged in" }
                return
            }
            
            do {
                let profile: Profile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .single()
                    .execute()
                    .value
                
                self.currentProfile = profile
                
                await MainActor.run {
                    self.nameLabel.text = profile.full_name?.isEmpty == false ? profile.full_name : "No Name"
                    
                    if let username = profile.username, !username.isEmpty {
                        self.usernameLabel.text = "@\(username)"
                    } else {
                        self.usernameLabel.text = "@username"
                    }
                    
                    if let bio = profile.bio, !bio.isEmpty {
                        self.bioLabel.text = bio
                    }
                    
                    self.updateAvatar(with: profile.avatar_url)
                }
            } catch {
                print("Error loading profile:", error)
                await MainActor.run {
                    self.nameLabel.text = "Profile Error"
                    self.usernameLabel.text = ""
                    self.updateAvatar(with: nil)
                }
            }
        }
    }
    
    /// Load avatar image from a URL string stored in `avatar_url`
    func updateAvatar(with urlString: String?) {
        // Reset to default first
        self.profileImageView.image = UIImage(systemName: "person.fill")
        self.profileImageView.tintColor = .white
        self.profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
        
        guard
            let urlString = urlString,
            !urlString.isEmpty,
            let url = URL(string: urlString)
        else {
            return  // keep default
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.profileImageView.image = image
                        self.profileImageView.contentMode = .scaleAspectFill
                        self.profileImageView.backgroundColor = .clear
                        self.profileImageView.tintColor = .clear
                    }
                }
            } catch {
                print("Failed to load avatar image:", error)
            }
        }
    }

    // MARK: - Edit Profile (name/username only)
    @objc func editProfileTapped() {
        let alert = UIAlertController(title: "Edit Profile",
                                      message: "Update your name and username",
                                      preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "Full Name"
            tf.text = self.currentProfile?.full_name ?? self.nameLabel.text
        }
        alert.addTextField { tf in
            tf.placeholder = "Username"
            if let username = self.currentProfile?.username {
                tf.text = username
            } else if let text = self.usernameLabel.text, text.hasPrefix("@") {
                tf.text = String(text.dropFirst())
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            let fullName = alert.textFields?[0].text ?? ""
            let username = alert.textFields?[1].text ?? ""
            self.updateProfile(fullName: fullName, username: username)
        }))
        
        present(alert, animated: true)
    }
    
    func updateProfile(fullName: String, username: String) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            
            let updates: [String: String] = [
                "full_name": fullName,
                "username": username
            ]
            
            do {
                _ = try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                await MainActor.run {
                    self.nameLabel.text = fullName.isEmpty ? "No Name" : fullName
                    self.usernameLabel.text = username.isEmpty ? "@username" : "@\(username)"
                }
            } catch {
                print("Error updating profile:", error)
                await MainActor.run {
                    self.showAlert(title: "Update failed", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Avatar: Pick & Upload to Supabase (bucket: useprofile)
extension UserProfileViewController {
    
    @objc func changeAvatarTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        guard let selectedImage = image else { return }
        
        // Update UI immediately
        self.profileImageView.image = selectedImage
        
        // Upload to Supabase Storage
        uploadAvatarImage(selectedImage)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func uploadAvatarImage(_ image: UIImage) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
                await MainActor.run {
                    self.showAlert(title: "Error", message: "Could not prepare image data.")
                }
                return
            }
            
            let client = SupabaseManager.shared.client
            
            // Unique file name
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "avatar_\(user.id.uuidString)_\(timestamp).jpg"
            let path = "\(user.id.uuidString)/\(fileName)"   // folder per user
            
            do {
                // Upload to bucket "useprofile"
                try await client.storage
                    .from("useprofile")
                    .upload(
                        path: path,
                        file: jpegData,
                        options: FileOptions(
                            cacheControl: "3600",
                            contentType: "image/jpeg",
                            upsert: true
                        )
                    )
                
                // Get public URL (throwing in your SDK)
                let publicURL = try client.storage
                    .from("useprofile")
                    .getPublicURL(path: path)
                
                let publicURLString = publicURL.absoluteString
                print("✅ Avatar uploaded: \(publicURLString)")
                
                // Save URL in profiles.avatar_url
                let updates: [String: String] = [
                    "avatar_url": publicURLString
                ]
                
                _ = try await client
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Reload from DB to confirm
                await MainActor.run {
                    self.loadProfile()
                }
                
            } catch {
                print("❌ Error uploading avatar:", error)
                await MainActor.run {
                    self.showAlert(title: "Upload failed", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Helpers
private extension UserProfileViewController {
    func showAlert(title: String, message: String) {
        if presentedViewController is UIAlertController { return }
        
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Gradient Header
final class GradientHeaderView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        gradient.colors = [
            UIColor(red: 1.0, green: 0.75, blue: 0.36, alpha: 1).cgColor,
            UIColor(red: 1.0, green: 0.93, blue: 0.83, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}

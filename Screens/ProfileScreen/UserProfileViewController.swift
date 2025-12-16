//  ProfileScreen.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase

struct Profile: Decodable {
    let id: UUID
    var full_name: String?
    var username: String?
    var avatar_url: String?
    var bio: String?
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
        // Send notification before popping to refresh navbar
        NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
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
        // Add profile header FIRST
        contentView.addArrangedSubview(buildHeader())
        contentView.setCustomSpacing(20, after: contentView.arrangedSubviews.last!)

        // Then add stats section
        contentView.addArrangedSubview(buildStatsSection())
        contentView.setCustomSpacing(20, after: contentView.arrangedSubviews.last!)

        // Then add saved section
        contentView.addArrangedSubview(buildSavedSection())

        // Add bottom spacer
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 100).isActive = true
        contentView.addArrangedSubview(spacer)
    }

    // MARK: - HEADER (DYNAMIC, NICER DESIGN)
    private func buildHeader() -> UIView {
        let container = UIView()
        
        let header = GradientHeaderView()
        header.layer.cornerRadius = 24
        header.layer.masksToBounds = true
        
        container.addSubview(header)
        
        // Avatar container in center
        let avatarWrapper = UIView()
        
        // Profile image
        profileImageView.image = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .white
        profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
        profileImageView.layer.cornerRadius = 52
        profileImageView.clipsToBounds = true
        profileImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        profileImageView.layer.borderWidth = 3
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(changeAvatarTapped))
        )
        
        // Camera badge overlay (FOR IMAGE UPLOAD ONLY)
        cameraBadgeView.backgroundColor = .white
        cameraBadgeView.layer.cornerRadius = 16
        cameraBadgeView.layer.shadowColor = UIColor.black.cgColor
        cameraBadgeView.layer.shadowOpacity = 0.15
        cameraBadgeView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cameraBadgeView.layer.shadowRadius = 4
        cameraBadgeView.isUserInteractionEnabled = true
        cameraBadgeView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(changeAvatarTapped))
        )
        
        let cameraIcon = UIImageView(image: UIImage(systemName: "camera.fill"))
        cameraIcon.tintColor = UIColor.systemOrange
        cameraIcon.contentMode = .scaleAspectFit
        cameraBadgeView.addSubview(cameraIcon)
        
        avatarWrapper.addSubview(profileImageView)
        avatarWrapper.addSubview(cameraBadgeView)
        
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
        
        // Edit pencil button (FOR EDITING NAME/USERNAME/PASSWORD)
        editButton.setImage(UIImage(systemName: "pencil"), for: .normal)
        editButton.tintColor = .white
        editButton.backgroundColor = UIColor.systemOrange
        editButton.layer.cornerRadius = 16
        editButton.contentEdgeInsets = .init(top: 8, left: 8, bottom: 8, right: 8)
        editButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        
        let textStack = UIStackView(arrangedSubviews: [nameLabel, usernameLabel, bioLabel])
        textStack.axis = .vertical
        textStack.alignment = .center
        textStack.spacing = 4
        
        header.addSubview(avatarWrapper)
        header.addSubview(textStack)
        header.addSubview(editButton)
        
        // Enable Auto Layout
        header.translatesAutoresizingMaskIntoConstraints = false
        avatarWrapper.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        cameraBadgeView.translatesAutoresizingMaskIntoConstraints = false
        cameraIcon.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        editButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Header constraints
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            header.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            header.heightAnchor.constraint(equalToConstant: 300),
            
            // Avatar wrapper
            avatarWrapper.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            avatarWrapper.topAnchor.constraint(equalTo: header.topAnchor, constant: 40),
            
            // Profile image
            profileImageView.topAnchor.constraint(equalTo: avatarWrapper.topAnchor),
            profileImageView.leadingAnchor.constraint(equalTo: avatarWrapper.leadingAnchor),
            profileImageView.trailingAnchor.constraint(equalTo: avatarWrapper.trailingAnchor),
            profileImageView.heightAnchor.constraint(equalToConstant: 104),
            profileImageView.widthAnchor.constraint(equalToConstant: 104),
            
            // Camera badge
            cameraBadgeView.widthAnchor.constraint(equalToConstant: 32),
            cameraBadgeView.heightAnchor.constraint(equalToConstant: 32),
            cameraBadgeView.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 4),
            cameraBadgeView.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 4),
            
            // Camera icon inside badge
            cameraIcon.centerXAnchor.constraint(equalTo: cameraBadgeView.centerXAnchor),
            cameraIcon.centerYAnchor.constraint(equalTo: cameraBadgeView.centerYAnchor),
            cameraIcon.widthAnchor.constraint(equalToConstant: 16),
            cameraIcon.heightAnchor.constraint(equalToConstant: 16),
            
            // Avatar wrapper bottom
            avatarWrapper.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor),
            
            // Text stack
            textStack.topAnchor.constraint(equalTo: avatarWrapper.bottomAnchor, constant: 20),
            textStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),
            textStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -24),
            
            // Edit button
            editButton.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 16),
            editButton.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 80),
            editButton.heightAnchor.constraint(equalToConstant: 32),
            editButton.bottomAnchor.constraint(lessThanOrEqualTo: header.bottomAnchor, constant: -24)
        ])
        
        return container
    }

    // MARK: - STATS
    private func buildStatsSection() -> UIView {
        let container = UIView()
        
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        container.addSubview(card)
        
        let playlist = statView(number: "23", label: "PLAYLISTS")
        let followers = statView(number: "58", label: "FOLLOWERS")
        let following = statView(number: "43", label: "FOLLOWING")

        let stack = UIStackView(arrangedSubviews: [playlist, followers, following])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.spacing = 0

        card.addSubview(stack)
        
        // Enable Auto Layout
        card.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        
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

    // MARK: - SAVED SECTION
    private func buildSavedSection() -> UIView {
        let container = UIView()

        let card = UIView()
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

        card.addSubview(stack)
        
        // Enable Auto Layout
        card.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        
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

        let icon = UIImageView(image: UIImage(systemName: "music.note.list"))
        icon.tintColor = .systemOrange
        icon.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
        icon.layer.cornerRadius = 12
        icon.clipsToBounds = true
        icon.contentMode = .center

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

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .tertiaryLabel

        row.addSubviews(icon, textStack, arrow)
        
        // Enable Auto Layout
        icon.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        arrow.translatesAutoresizingMaskIntoConstraints = false
        
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
                await MainActor.run {
                    self.nameLabel.text = "Not logged in"
                    self.usernameLabel.text = "@username"
                }
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
                    self.usernameLabel.text = "@username"
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
        self.profileImageView.contentMode = .center
        
        guard
            let urlString = urlString,
            !urlString.isEmpty
        else {
            return  // keep default
        }
        
        Task {
            do {
                // Check if URL is valid
                var finalURLString = urlString
                
                // Fix the URL if it's missing /public/
                if urlString.contains("supabase.co/storage/v1/object/useprofile/") && !urlString.contains("/public/") {
                    // Replace /object/useprofile/ with /object/public/useprofile/
                    finalURLString = urlString.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
                }
                
                guard let url = URL(string: finalURLString) else {
                    print("Invalid URL string: \(finalURLString)")
                    return
                }
                
                print("Loading avatar from: \(url)")
                
                // Load image with timeout
                let request = URLRequest(url: url, timeoutInterval: 30)
                let (data, _) = try await URLSession.shared.data(for: request)
                
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
                print("URL attempted: \(urlString)")
            }
        }
    }

    // MARK: - Edit Profile (name/username and password) - PENCIL BUTTON
    @objc func editProfileTapped() {
        let alert = UIAlertController(title: "Edit Profile",
                                      message: "What would you like to update?",
                                      preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Update Name & Username", style: .default, handler: { _ in
            self.showNameUsernameEditor()
        }))
        
        alert.addAction(UIAlertAction(title: "Change Password", style: .default, handler: { _ in
            self.showPasswordChangeDialog()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = editButton
            popoverController.sourceRect = editButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showNameUsernameEditor() {
        let alert = UIAlertController(title: "Update Profile",
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
    
    private func showPasswordChangeDialog() {
        let alert = UIAlertController(title: "Change Password",
                                      message: "Enter your new password",
                                      preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "New Password"
            tf.isSecureTextEntry = true
        }
        
        alert.addTextField { tf in
            tf.placeholder = "Confirm New Password"
            tf.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Change", style: .default, handler: { _ in
            let newPassword = alert.textFields?[0].text ?? ""
            let confirmPassword = alert.textFields?[1].text ?? ""
            
            if newPassword.isEmpty {
                self.showAlert(title: "Error", message: "Password cannot be empty")
            } else if newPassword != confirmPassword {
                self.showAlert(title: "Error", message: "Passwords do not match")
            } else if newPassword.count < 6 {
                self.showAlert(title: "Error", message: "Password must be at least 6 characters")
            } else {
                self.updatePassword(newPassword: newPassword)
            }
        }))
        
        present(alert, animated: true)
    }
    
    func updateProfile(fullName: String, username: String) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            
            // Create updates dictionary with only String values
            var updates: [String: String?] = [
                "full_name": fullName.isEmpty ? nil : fullName
            ]
            
            // Only add username if it's not empty
            if !username.isEmpty {
                updates["username"] = username
            } else {
                updates["username"] = nil
            }
            
            do {
                // Filter out nil values for the update
                let filteredUpdates = updates.compactMapValues { $0 }
                
                _ = try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(filteredUpdates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Create a new Profile object with updated values
                self.currentProfile = Profile(
                    id: self.currentProfile?.id ?? user.id,
                    full_name: fullName.isEmpty ? nil : fullName,
                    username: username.isEmpty ? nil : username,
                    avatar_url: self.currentProfile?.avatar_url,
                    bio: self.currentProfile?.bio
                )
                
                await MainActor.run {
                    self.nameLabel.text = fullName.isEmpty ? "No Name" : fullName
                    self.usernameLabel.text = username.isEmpty ? "@username" : "@\(username)"
                    self.showAlert(title: "Success", message: "Profile updated successfully")
                    
                    // Send notification to refresh navbar
                    NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
                }
            } catch {
                print("Error updating profile:", error)
                await MainActor.run {
                    self.showAlert(title: "Update failed", message: error.localizedDescription)
                }
            }
        }
        
    }
    
    func updatePassword(newPassword: String) {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(user: .init(password: newPassword))
                
                await MainActor.run {
                    self.showAlert(title: "Success", message: "Password updated successfully")
                }
            } catch {
                print("Error updating password:", error)
                await MainActor.run {
                    self.showAlert(title: "Update failed", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Avatar: Pick & Upload to Supabase (bucket: useprofile) - CAMERA BADGE
extension UserProfileViewController {
    
    @objc func changeAvatarTapped() {
        let alert = UIAlertController(title: "Change Profile Picture",
                                      message: "Choose an option",
                                      preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default, handler: { _ in
            self.openPhotoLibrary()
        }))
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { _ in
                self.openCamera()
            }))
        }
        
        // Check if user has existing avatar to allow removal
        if let currentProfile = currentProfile, currentProfile.avatar_url != nil {
            alert.addAction(UIAlertAction(title: "Remove Current Photo", style: .destructive, handler: { _ in
                self.removeAvatar()
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = cameraBadgeView
            popoverController.sourceRect = cameraBadgeView.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func openPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }
    
    private func openCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }
    
    private func removeAvatar() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            
            do {
                // Update database to remove avatar_url
                let updates: [String: String?] = [
                    "avatar_url": nil
                ]
                
                // Filter out nil values
                let filteredUpdates = updates.compactMapValues { $0 }
                
                _ = try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(filteredUpdates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Create a new Profile object without avatar_url
                self.currentProfile = Profile(
                    id: self.currentProfile?.id ?? user.id,
                    full_name: self.currentProfile?.full_name,
                    username: self.currentProfile?.username,
                    avatar_url: nil,
                    bio: self.currentProfile?.bio
                )
                
                await MainActor.run {
                    self.profileImageView.image = UIImage(systemName: "person.fill")
                    self.profileImageView.tintColor = .white
                    self.profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
                    self.profileImageView.contentMode = .center
                    self.showAlert(title: "Success", message: "Profile picture removed")
                }
            } catch {
                print("Error removing avatar:", error)
                await MainActor.run {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    // UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage else {
            self.showAlert(title: "Error", message: "Could not select image")
            return
        }
        
        // Update UI immediately
        self.profileImageView.image = image
        self.profileImageView.contentMode = .scaleAspectFill
        self.profileImageView.backgroundColor = .clear
        self.profileImageView.tintColor = .clear
        
        // Upload to Supabase Storage
        uploadAvatarImage(image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func uploadAvatarImage(_ image: UIImage) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    self.showAlert(title: "Error", message: "Not logged in")
                }
                return
            }
            
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
            
            do {
                // METHOD 1: Try simplest upload without options
                try await client.storage
                    .from("useprofile")
                    .upload(
                        path: fileName,
                        file: jpegData
                    )
                
                print("✅ Upload successful")
                
            } catch {
                print("❌ Method 1 failed, trying Method 2:", error)
                
                // METHOD 2: Try with FileOptions (FIXED ORDER - cacheControl before contentType)
                do {
                    try await client.storage
                        .from("useprofile")
                        .upload(
                            path: fileName,
                            file: jpegData,
                            options: FileOptions(
                                cacheControl: "3600",
                                contentType: "image/jpeg"
                            )
                        )
                    
                    print("✅ Method 2 upload successful")
                    
                } catch {
                    print("❌ All upload methods failed:", error)
                    await MainActor.run {
                        // Revert to default image
                        self.profileImageView.image = UIImage(systemName: "person.fill")
                        self.profileImageView.tintColor = .white
                        self.profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
                        self.profileImageView.contentMode = .center
                        
                        let errorMessage: String
                        if (error as NSError).code == -1005 {
                            errorMessage = "Network connection lost. Please check your internet and try again."
                        } else {
                            errorMessage = "Upload failed: \(error.localizedDescription)"
                        }
                        self.showAlert(title: "Upload Error", message: errorMessage)
                    }
                    return
                }
            }
            
            // If we get here, upload was successful
            // Get the correct public URL
            let projectRef = "djqgmowfjxsnjdffdohw" // REPLACE WITH YOUR PROJECT REF
            let publicURL = "https://\(projectRef).supabase.co/storage/v1/object/public/useprofile/\(fileName)"
            
            // Save URL in profiles.avatar_url
            let updates: [String: String] = [
                "avatar_url": publicURL
            ]
            
            do {
                _ = try await client
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Create a new Profile object with updated avatar_url
                self.currentProfile = Profile(
                    id: self.currentProfile?.id ?? user.id,
                    full_name: self.currentProfile?.full_name,
                    username: self.currentProfile?.username,
                    avatar_url: publicURL,
                    bio: self.currentProfile?.bio
                )
                
                await MainActor.run {
                    self.showAlert(title: "Success", message: "Profile picture updated!")
                    
                    // Send notification to refresh navbar
                    NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
                }
                
            } catch {
                print("❌ Error saving to database:", error)
                await MainActor.run {
                    self.showAlert(title: "Database Error", message: "Image uploaded but couldn't update profile.")
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

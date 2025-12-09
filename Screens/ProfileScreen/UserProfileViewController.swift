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
    
    // Header elements we need to update
    private let profileImageView = UIImageView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()   // will show @username
    private let editButton = UIButton(type: .system)
    
    // Data
    private var currentProfile: Profile?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
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
        backButton.tintColor = .black
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
        contentView.addArrangedSubview(buildStatsSection())
        // contentView.addArrangedSubview(buildPracticeGraphCard())
        contentView.addArrangedSubview(buildSavedSection())

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 36).isActive = true
        contentView.addArrangedSubview(spacer)
    }

    // MARK: - HEADER (DYNAMIC)
    private func buildHeader() -> UIView {
        let header = GradientHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false

        // Profile image
        profileImageView.image = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .black
        profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        profileImageView.layer.cornerRadius = 50
        profileImageView.clipsToBounds = true
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(changeAvatarTapped))
        )

        // Name
        nameLabel.text = "Loading..."
        nameLabel.font = .boldSystemFont(ofSize: 22)

        // Username label
        usernameLabel.text = "@username"
        usernameLabel.font = .systemFont(ofSize: 14)
        usernameLabel.textColor = .darkGray

        // Edit button
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 16)
        editButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)

        let infoStack = UIStackView(arrangedSubviews: [nameLabel, usernameLabel, editButton])
        infoStack.axis = .vertical
        infoStack.spacing = 6
        infoStack.alignment = .leading
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        header.addSubviews(profileImageView, infoStack)

        NSLayoutConstraint.activate([
            profileImageView.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            profileImageView.topAnchor.constraint(equalTo: header.topAnchor, constant: 120),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),

            infoStack.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 30),
            infoStack.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
            infoStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),

            header.heightAnchor.constraint(equalToConstant: 260)
        ])

        return header
    }

    // MARK: - STATS
    private func buildStatsSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // TODO: later make these dynamic from playlists/followers etc.
        let playlist = statView(number: "23", label: "PLAYLISTS")
        let followers = statView(number: "58", label: "FOLLOWERS")
        let following = statView(number: "43", label: "FOLLOWING")

        let stack = UIStackView(arrangedSubviews: [playlist, followers, following])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
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
        num.font = .boldSystemFont(ofSize: 18)

        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = .gray

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

        // STREAK
        let streak = UILabel()
        streak.text = "__ day streak"
        streak.font = .systemFont(ofSize: 15, weight: .semibold)
        streak.textColor = UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1)

        // HOURS
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

        let label = UILabel()
        label.text = "Saved"
        label.font = .boldSystemFont(ofSize: 18)

        let stack = UIStackView(arrangedSubviews: [
            label,
            savedRow(title: "Shazam", likes: "7 likes"),
            savedRow(title: "Roadtrip", likes: "4 likes")
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func savedRow(title: String, likes: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "music.note"))
        icon.tintColor = .black
        icon.translatesAutoresizingMaskIntoConstraints = false

        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 16, weight: .medium)

        let l = UILabel()
        l.text = likes
        l.font = .systemFont(ofSize: 12)
        l.textColor = .gray

        let textStack = UIStackView(arrangedSubviews: [t, l])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .gray
        arrow.translatesAutoresizingMaskIntoConstraints = false

        row.addSubviews(icon, textStack, arrow)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.heightAnchor.constraint(equalToConstant: 50),
            icon.widthAnchor.constraint(equalToConstant: 50),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            arrow.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            arrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.heightAnchor.constraint(equalToConstant: 60)
        ])

        return row
    }
}

// MARK: - Supabase: Load & Update Profile (name, username, avatar_url)
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
                    .value   // decodes into Profile
                
                self.currentProfile = profile
                
                await MainActor.run {
                    self.nameLabel.text = profile.full_name?.isEmpty == false ? profile.full_name : "No Name"
                    
                    if let username = profile.username, !username.isEmpty {
                        self.usernameLabel.text = "@\(username)"
                    } else {
                        self.usernameLabel.text = "@username"
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
        self.profileImageView.tintColor = .black
        self.profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        
        guard
            let urlString = urlString,
            !urlString.isEmpty,
            let url = URL(string: urlString)
        else {
            return  // no valid avatar URL, keep default
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

    // MARK: - Edit Profile (name/username)
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
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                print("Failed to create JPEG data")
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
                
                // Get public URL (URL -> String)
                let publicURL = try client.storage
                    .from("useprofile")
                    .getPublicURL(path: path)
                
                let publicURLString = publicURL.absoluteString
                
                // Save URL in profiles.avatar_url
                let updates: [String: String] = [
                    "avatar_url": publicURLString
                ]
                
                _ = try await client
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Update local state + UI
                await MainActor.run {
                    self.currentProfile = Profile(
                        id: self.currentProfile?.id ?? user.id,
                        full_name: self.currentProfile?.full_name,
                        username: self.currentProfile?.username,
                        avatar_url: publicURLString,
                        bio: self.currentProfile?.bio
                    )
                    self.updateAvatar(with: publicURLString)
                }
                
            } catch {
                print("❌ Error uploading avatar:", error)
            }
        }
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
            UIColor.white.cgColor
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

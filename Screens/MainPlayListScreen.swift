//
//  MainPlayListScreen.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/11/25.
//

import UIKit

// MARK: - Playlist Data Model
struct Playlist {
    let title: String
    /// imageIdentifier can be an asset name (e.g. "cl_1") or a filename saved in Documents (e.g. "doc_123.png")
    let imageIdentifier: String
    let tags: String
    let trackCount: Int
}

// MARK: - Playlist Screen
// MARK: - Playlist Screen
class PlaylistViewController: UIViewController {
    
    // MARK: - UI Components
    private let navBar = TopNavBar.make(title: "PlayList")
    private let tableView = UITableView()
    
    // MARK: - Floating Button (Matches PlaylistDetailViewController)
    private let floatingButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.orange      // identical color
        btn.setImage(UIImage(systemName: "plus"), for: .normal)
        btn.tintColor = .white
        
        btn.layer.cornerRadius = 30
        btn.clipsToBounds = false
        
        // Same modern shadow
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.25
        btn.layer.shadowRadius = 6
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    
    // MARK: - Data (mutable)
    private var playlists: [Playlist] = [
        Playlist(title: "Silent Waves", imageIdentifier: "cl_2", tags: "Lo-fi Ambient Acoustic Chill", trackCount: 12),
        Playlist(title: "Beast Mode Beats", imageIdentifier: "cl_3", tags: "Blaze Surge Rush Fuel", trackCount: 9),
        Playlist(title: "Midnight Flow", imageIdentifier: "cl_4", tags: "Ambient Chillwave Jazzy Groovy", trackCount: 14),
        Playlist(title: "Focus Mode", imageIdentifier: "cl_5", tags: "Study Chill Relax", trackCount: 10),
        Playlist(title: "Deep Travel", imageIdentifier: "cl_1", tags: "Soul Indie Acoustic", trackCount: 8),
    ]
    
    
    // MARK: - Life
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFloatingButton()
    }
    
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupTableView()
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
               let vc = ProfileScreen()
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


    
    
    // MARK: - Add
    @objc private func didTapAdd() {
        let addVC = AddPlaylistViewController()
        addVC.modalPresentationStyle = .overFullScreen

        addVC.onSave = { [weak self] (name, pickedImage) in
            guard let self = self else { return }
            let id: String

            if let image = pickedImage {
                if let fileName = self.saveImageToDocuments(image: image) {
                    id = fileName
                } else {
                    id = "cl_1"
                }
            } else {
                id = "cl_1"
            }
            
            let new = Playlist(title: name, imageIdentifier: id, tags: "Custom Playlist", trackCount: 0)
            self.playlists.append(new)
            self.tableView.reloadData()
        }
        
        present(addVC, animated: true)
    }
    
    
    // MARK: - Table
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
    
    
    // MARK: - File saving helper
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
        if let img = UIImage(named: identifier) { return img }
        
        let url = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask).first!.appendingPathComponent(identifier)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}

    
    // MARK: - File saving helper
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
        if let img = UIImage(named: identifier) { return img }
        
        let url = FileManager.default.urls(for: .documentDirectory,
                                           in: .userDomainMask).first!.appendingPathComponent(identifier)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }


// MARK: - Table Delegate
extension PlaylistViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { playlists.count }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath) as! PlaylistTableViewCell
        let p = playlists[indexPath.row]
        
        let img = loadImage(identifier: p.imageIdentifier)
        cell.configure(withTitle: p.title, tags: p.tags, trackCount: p.trackCount, image: img)
        
        return cell
    }
    
    // ⬇️ UPDATED — passes image + title + tags to next screen
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let playlist = playlists[indexPath.row]
        
        let vc = PlaylistDetailViewController()
        let img = loadImage(identifier: playlist.imageIdentifier)

        vc.passedImage = img                      // PASS IMAGE
        vc.passedTitle = playlist.title           // PASS TITLE
        vc.passedArtist = playlist.tags           // PASS ARTIST/TAGS
        
        navigationController?.pushViewController(vc, animated: true)
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
    
    private let playlistImageView = UIImageView()
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

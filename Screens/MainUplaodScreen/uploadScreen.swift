//
//  UploadScreen.swift
//  Re-Hearse_v1
//

import UIKit
import AVFoundation
import Photos

class UploadScreen: UIViewController {
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 20
        static let elementSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 16
        static let buttonHeight: CGFloat = 52
        static let uploadContainerHeight: CGFloat = 300
        static let cardSize = CGSize(width: 140, height: 160)
        static let carouselHeight: CGFloat = 180
    }
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(title: "Upload")
    
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    private let uploadContainer = UIView()
    private let uploadIcon = UIImageView()
    private let uploadLabel = UILabel()
    private let uploadButton = UIButton()

    // MARK: - Metadata Storage
    private var uploadTitle: String = "Untitled"
    private var uploadCoverImage: UIImage? = UIImage(systemName: "music.note")
    
    // UI references
    private var metaTitleLbl: UILabel?
    private var metaCoverImgView: UIImageView?
    
    // Recent Uploads Data
    private var recentUploads: [(title: String, cover: UIImage?)] = []
    
    // UI reference for recents stack
    private var recentHStack: UIStackView?
    
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
    }
    
    // MARK: - Navbar Setup
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

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }

    // MARK: - ScrollView Setup
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        contentView.axis = .vertical
        contentView.spacing = Constants.sectionSpacing
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: Constants.horizontalPadding),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -Constants.horizontalPadding),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -2 * Constants.horizontalPadding)
        ])
    }

    // MARK: - Upload Meta Section
    private func addUploadMetaSection() {

        let metaStack = UIStackView()
        metaStack.axis = .horizontal
        metaStack.spacing = 14
        metaStack.alignment = .center
        
        // Image
        let cover = UIImageView()
        cover.image = uploadCoverImage
        cover.clipsToBounds = true
        cover.layer.cornerRadius = 26
        cover.contentMode = .scaleAspectFill
        cover.translatesAutoresizingMaskIntoConstraints = false
        metaCoverImgView = cover
        
        // Title
        let title = UILabel()
        title.text = uploadTitle
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .black
        metaTitleLbl = title
        
        // Edit button
        let editButton = UIButton(type: .system)
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        editButton.addTarget(self, action: #selector(showMetaEditor), for: .touchUpInside)
        
        metaStack.addArrangedSubview(cover)
        metaStack.addArrangedSubview(title)
        metaStack.addArrangedSubview(editButton)
        
        NSLayoutConstraint.activate([
            cover.widthAnchor.constraint(equalToConstant: 52),
            cover.heightAnchor.constraint(equalToConstant: 52)
        ])
        
        contentView.addArrangedSubview(metaStack)
    }
    
    // MARK: Edit Meta Popup
    @objc private func showMetaEditor() {
        let ac = UIAlertController(title: "Edit Upload Info", message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "Edit Name", style: .default, handler: { _ in
            self.askForTitle()
        }))

        ac.addAction(UIAlertAction(title: "Change Cover Image", style: .default, handler: { _ in
            self.pickCoverImage()
        }))

        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(ac, animated: true)
    }

    private func askForTitle() {
        let ac = UIAlertController(title: "Enter Title", message: nil, preferredStyle: .alert)
        ac.addTextField { tf in
            tf.text = self.uploadTitle
            tf.placeholder = "Song Title"
        }
        ac.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            self.uploadTitle = ac.textFields?.first?.text ?? "Untitled"
            self.metaTitleLbl?.text = self.uploadTitle
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }

    private func pickCoverImage() {
        presentImagePicker(sourceType: .photoLibrary, forCover: true)
    }
    
    // MARK: - Recent Uploads Section
    private func addRecentUploadsSection() {

        let header = UILabel()
        header.text = "Recent Uploads"
        header.font = .systemFont(ofSize: 18, weight: .semibold)
        header.textColor = .black
        
        contentView.addArrangedSubview(header)

        // Horizontal scroll
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = Constants.elementSpacing
        hStack.translatesAutoresizingMaskIntoConstraints = false
        recentHStack = hStack
        
        scroll.addSubview(hStack)
        contentView.addArrangedSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(equalToConstant: Constants.carouselHeight),
            hStack.topAnchor.constraint(equalTo: scroll.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 10),
            hStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            hStack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])
    }
    
    // MARK: Add Card to Recent Uploads
    private func addRecentUploadCard(title: String, image: UIImage?) {
        guard let hStack = recentHStack else { return }
        
        let card = createImageCard(image: image, title: title)
        
        // Insert at index 0
        hStack.insertArrangedSubview(card, at: 0)
    }

    // MARK: Create Image Card
    private func createImageCard(image: UIImage?, title: String) -> UIView {

        let card = UIButton()
        card.layer.cornerRadius = Constants.cornerRadius
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = image ?? UIImage(systemName: "music.note")
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        
        let lbl = UILabel()
        lbl.text = title
        lbl.textAlignment = .center
        lbl.textColor = .white
        lbl.font = .systemFont(ofSize: 14, weight: .semibold)
        lbl.backgroundColor = UIColor(white: 0, alpha: 0.7)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(iv)
        card.addSubview(lbl)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Constants.cardSize.width),
            card.heightAnchor.constraint(equalToConstant: Constants.cardSize.height),
            
            iv.topAnchor.constraint(equalTo: card.topAnchor),
            iv.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            iv.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            lbl.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            lbl.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            lbl.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // Action → open detail page
        card.addAction(UIAction(handler: { _ in
            let vc = SongDetailViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }), for: .touchUpInside)
        
        return card
    }

    // MARK: - Upload Box
    private func setupUploadSection() {
        uploadContainer.backgroundColor = .secondarySystemBackground
        uploadContainer.layer.cornerRadius = Constants.cornerRadius
        uploadContainer.translatesAutoresizingMaskIntoConstraints = false
        
        uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
        uploadIcon.tintColor = .secondaryLabel
        uploadIcon.translatesAutoresizingMaskIntoConstraints = false
        
        uploadLabel.text = "Drag & drop or tap to upload"
        uploadLabel.font = .systemFont(ofSize: 14, weight: .medium)
        uploadLabel.textColor = .secondaryLabel
        uploadLabel.translatesAutoresizingMaskIntoConstraints = false
        
        var cfg = UIButton.Configuration.filled()
        cfg.title = "Upload Files"
        cfg.image = UIImage(systemName: "camera.fill")
        cfg.imagePadding = 8
        cfg.baseBackgroundColor = .systemYellow
        cfg.baseForegroundColor = .black
        
        uploadButton.configuration = cfg
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)

        contentView.addArrangedSubview(uploadContainer)
        contentView.addArrangedSubview(uploadButton)
        
        uploadContainer.addSubview(uploadIcon)
        uploadContainer.addSubview(uploadLabel)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(uploadTapped))
        uploadContainer.addGestureRecognizer(tap)
        
        NSLayoutConstraint.activate([
            uploadContainer.heightAnchor.constraint(equalToConstant: Constants.uploadContainerHeight),
            
            uploadIcon.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            uploadIcon.centerYAnchor.constraint(equalTo: uploadContainer.centerYAnchor, constant: -10),
            uploadIcon.widthAnchor.constraint(equalToConstant: 45),
            uploadIcon.heightAnchor.constraint(equalToConstant: 45),
            
            uploadLabel.topAnchor.constraint(equalTo: uploadIcon.bottomAnchor, constant: 8),
            uploadLabel.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            
            uploadButton.heightAnchor.constraint(equalToConstant: Constants.buttonHeight)
        ])
    }

    // MARK: - Upload Logic
    @objc private func uploadTapped() {
        showUploadOptions()
    }

    private func showUploadOptions() {
        let ac = UIAlertController(title: "Upload Content", message: nil, preferredStyle: .actionSheet)
        
        ac.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { _ in
            self.presentImagePicker(sourceType: .camera)
        }))
        
        ac.addAction(UIAlertAction(title: "Choose From Library", style: .default, handler: { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        }))
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType, forCover: Bool = false) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = sourceType
        picker.view.tag = forCover ? 999 : 0
        present(picker, animated: true)
    }
}

// MARK: - Image Picker Delegate
extension UploadScreen: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage

        if picker.view.tag == 999 {
            // Cover image changed
            uploadCoverImage = img
            metaCoverImgView?.image = img
            picker.dismiss(animated: true)
            return
        }

        picker.dismiss(animated: true) {
            guard let selected = img else { return }
            let nextVC = UploadPageNextViewController()
            nextVC.uploadedImage = selected
            if let nav = self.navigationController {
                nav.pushViewController(nextVC, animated: true)
            } else {
                nextVC.modalPresentationStyle = .fullScreen
                self.present(nextVC, animated: true)
            }
        }
    }
}

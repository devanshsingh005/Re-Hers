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
    
    private var metaTitleLbl: UILabel?
    private var metaCoverImgView: UIImageView?
    private var recentHStack: UIStackView?
    
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
        
        // sample placeholder cards so area is visible on load
        addRecentUploadCard(title: "Lo-fi Focus", image: UIImage(named: "cl_1"))
        addRecentUploadCard(title: "Deep Work Mix", image: UIImage(named: "cl_2"))
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
        cover.contentMode = .scaleAspectFit
        cover.tintColor = .black
        cover.backgroundColor = UIColor(white: 0.95, alpha: 1)
        cover.clipsToBounds = true
        cover.layer.cornerRadius = Constants.metaCornerRadius
        cover.translatesAutoresizingMaskIntoConstraints = false
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
            cover.widthAnchor.constraint(equalToConstant: Constants.metaCoverSize),
            cover.heightAnchor.constraint(equalToConstant: Constants.metaCoverSize)
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
        uploadIcon.image = UIImage(systemName: "music.note") // small centered music icon
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
        
        // Normal upload flow — simulate conversion finished by adding to recents
        addRecentUploadCard(title: uploadTitle, image: picked)
        
        // then navigate to next page (your flow)
        let vc = SongDetailViewController()
//        vc.uploadedImage = picked // if your detail VC accepts an image (removed per instructions)
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}


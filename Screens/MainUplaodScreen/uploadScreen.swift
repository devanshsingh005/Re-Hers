//
//  UploadScreen.swift
//  Re-Hearse_v1
//
//  Created by DEVANSH on 04/11/25.
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
        static let uploadContainerHeight: CGFloat = 180
        static let cardSize = CGSize(width: 140, height: 160)
        static let carouselHeight: CGFloat = 180
    }
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(
       title: "Upload"
    )
    
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
        setupUploadSection()
        addContinueLearningSection()
    }
    
    // MARK: - Navbar Setup
    private func setupNavBar() {
          view.addSubview(navBar)
          navBar.translatesAutoresizingMaskIntoConstraints = false

          navBar.isStreakVisible = false
          navBar.isWelcomeTextHidden = true
          
          // 🔥 SHOW CHORD ICON
          navBar.isChordIconVisible = true
          
          // ---- IMPORTANT: use push so the chord VC becomes part of the nav stack.
          // This keeps the bottom tab bar visible and lets back button behavior be natural.
          navBar.chordAction = { [weak self] in
              guard let self = self else { return }
              let vc = ChordRecognitionViewController()
              // prefer push (so TabBar + Nav stack remain correct)
              if let nav = self.navigationController {
                  nav.pushViewController(vc, animated: true)
              } else {
                  // fallback: if caller isn't embedded in a UINavigationController,
                  // present modally so feature still works.
                  vc.modalPresentationStyle = .fullScreen
                  self.present(vc, animated: true)
              }
          }


        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
        
        navBar.layer.shadowColor = UIColor.black.cgColor
        navBar.layer.shadowOpacity = 0.1
        navBar.layer.shadowOffset = CGSize(width: 0, height: 2)
        navBar.layer.shadowRadius = 4
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

    // MARK: - Upload Box
    private func setupUploadSection() {
        uploadContainer.backgroundColor = .secondarySystemBackground
        uploadContainer.layer.cornerRadius = Constants.cornerRadius
        uploadContainer.translatesAutoresizingMaskIntoConstraints = false
        
        uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
        uploadIcon.tintColor = .tertiaryLabel
        uploadIcon.translatesAutoresizingMaskIntoConstraints = false
        
        uploadLabel.text = "Drag & drop or tap to upload"
        uploadLabel.textColor = .secondaryLabel
        uploadLabel.font = .systemFont(ofSize: 14, weight: .medium)
        uploadLabel.translatesAutoresizingMaskIntoConstraints = false
        
        var cfg = UIButton.Configuration.filled()
        cfg.title = "Upload Files"
        cfg.image = UIImage(systemName: "camera.fill")
        cfg.imagePadding = 8
        cfg.baseBackgroundColor = UIColor(red: 0.96, green: 0.71, blue: 0.34, alpha: 1)
        cfg.baseForegroundColor = .black
        cfg.cornerStyle = .medium
        
        uploadButton.configuration = cfg
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)

        contentView.addArrangedSubview(uploadContainer)
        contentView.addArrangedSubview(uploadButton)
        
        uploadContainer.addSubview(uploadIcon)
        uploadContainer.addSubview(uploadLabel)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(uploadTapped))
        uploadContainer.addGestureRecognizer(tapGesture)
        
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

    // MARK: - Continue Learning
    private func addContinueLearningSection() {
        let sectionHeader = UILabel()
        sectionHeader.text = "Continue Learning"
        sectionHeader.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionHeader.textColor = .black
        contentView.addArrangedSubview(sectionHeader)
        
        let headerSpacer = UIView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.heightAnchor.constraint(equalToConstant: 12).isActive = true
        contentView.addArrangedSubview(headerSpacer)
        
        let slider = createHorizontalCarousel()
        contentView.addArrangedSubview(slider)
    }

    private func createHorizontalCarousel() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let hScroll = UIScrollView()
        hScroll.showsHorizontalScrollIndicator = false
        hScroll.translatesAutoresizingMaskIntoConstraints = false
        
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = Constants.elementSpacing
        hStack.translatesAutoresizingMaskIntoConstraints = false
        
        hScroll.addSubview(hStack)
        container.addSubview(hScroll)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: Constants.carouselHeight),
            hScroll.topAnchor.constraint(equalTo: container.topAnchor),
            hScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hStack.topAnchor.constraint(equalTo: hScroll.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: hScroll.leadingAnchor, constant: Constants.horizontalPadding),
            hStack.trailingAnchor.constraint(equalTo: hScroll.trailingAnchor, constant: -Constants.horizontalPadding),
            hStack.bottomAnchor.constraint(equalTo: hScroll.bottomAnchor),
            hStack.heightAnchor.constraint(equalTo: hScroll.heightAnchor)
        ])

        let imgs = ["cl_1", "cl_2", "ride_home", "cl_1", "cl_2"]
        imgs.forEach {
            hStack.addArrangedSubview(createImageCard(imageName: $0, title: getTitleForImage($0)))
        }
        
        return container
    }

    private func createImageCard(imageName: String, title: String) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = Constants.cornerRadius
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.image = UIImage(named: imageName) ?? UIImage(systemName: "music.note")
        
        let lbl = UILabel()
        lbl.text = title
        lbl.textColor = .white
        lbl.font = .systemFont(ofSize: 14, weight: .semibold)
        lbl.textAlignment = .center
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
        return card
    }
    
    // MARK: - Helpers
    private func getTitleForImage(_ name: String) -> String {
        switch name {
        case "cl_1": return "Lo-fi Focus"
        case "cl_2": return "Deep Work Mix"
        case "ride_home": return "Ride Home"
        default: return "Playlist"
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Upload Handling
    @objc private func uploadTapped() {
        showUploadOptions()
    }

    private func showUploadOptions() {
        let ac = UIAlertController(title: "Upload Content", message: "Choose an option", preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { _ in self.openCamera() }))
        ac.addAction(UIAlertAction(title: "Choose from Library", style: .default, handler: { _ in self.openPhotoLibrary() }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = ac.popoverPresentationController {
            popover.sourceView = uploadButton
            popover.sourceRect = uploadButton.bounds
        }
        present(ac, animated: true)
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(title: "Camera Not Available", message: "This device doesn't have a camera")
            return
        }
        presentImagePicker(sourceType: .camera)
    }

    private func openPhotoLibrary() {
        presentImagePicker(sourceType: .photoLibrary)
    }

    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
}

// MARK: - Image Picker Delegate
extension UploadScreen: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        print("Image selected successfully")
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

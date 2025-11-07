import Foundation
import UIKit
import AVFoundation
import Photos

class UploadScreen: UIViewController {
    
    // MARK: - Constants
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 20 // Reduced
        static let elementSpacing: CGFloat = 12 // Reduced
        static let cornerRadius: CGFloat = 16
        static let buttonHeight: CGFloat = 52
        static let uploadContainerHeight: CGFloat = 180 // Reduced
        static let cardSize = CGSize(width: 140, height: 160)
        static let carouselHeight: CGFloat = 180
        static let topNavBarTopPadding: CGFloat = 0 // Reduced to 0
        static let scrollViewTopPadding: CGFloat = 4 // Reduced further
        static let contentViewTopPadding: CGFloat = 0 // Reduced to 0
    }
    
    // MARK: - UI Components
    private var topNavBar: TopNavBar!
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let uploadContainer = UIView()
    private let uploadIcon = UIImageView()
    private let uploadButton = UIButton()
    private let uploadLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        addContinueLearningSection()
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        setupTopNavBar()
        setupScrollView()
        setupUploadSection()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: Constants.contentViewTopPadding, left: 0, bottom: 12, right: 0) // Reduced bottom
        view.addSubview(scrollView)
        
        contentView.axis = .vertical
        contentView.spacing = Constants.sectionSpacing
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layoutMargins = UIEdgeInsets(
            top: 8, // Minimal top padding
            left: Constants.horizontalPadding,
            bottom: Constants.elementSpacing,
            right: Constants.horizontalPadding
        )
        contentView.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentView)
    }
    
    private func setupUploadSection() {
        // Upload container
        uploadContainer.backgroundColor = .secondarySystemBackground
        uploadContainer.layer.cornerRadius = Constants.cornerRadius
        uploadContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Upload icon
        uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
        uploadIcon.tintColor = .tertiaryLabel
        uploadIcon.contentMode = .scaleAspectFit
        uploadIcon.translatesAutoresizingMaskIntoConstraints = false
        uploadContainer.addSubview(uploadIcon)
        
        // Upload label
        uploadLabel.text = "Drag & drop or tap to upload"
        uploadLabel.font = .systemFont(ofSize: 14, weight: .medium)
        uploadLabel.textColor = .secondaryLabel
        uploadLabel.textAlignment = .center
        uploadLabel.translatesAutoresizingMaskIntoConstraints = false
        uploadContainer.addSubview(uploadLabel)
        
        // Upload button
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.title = "Upload Files"
        buttonConfig.image = UIImage(systemName: "camera.fill")
        buttonConfig.imagePadding = 8
        buttonConfig.baseBackgroundColor = UIColor(red: 0.96, green: 0.71, blue: 0.34, alpha: 1.0)
        buttonConfig.baseForegroundColor = .black
        buttonConfig.cornerStyle = .medium
        uploadButton.configuration = buttonConfig
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)
        
        contentView.addArrangedSubview(uploadContainer)
        contentView.addArrangedSubview(uploadButton)
        
        // Add tap gesture to upload container
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(uploadTapped))
        uploadContainer.addGestureRecognizer(tapGesture)
        uploadContainer.isUserInteractionEnabled = true
    }
    
    // MARK: - Continue Learning Carousel
    private func addContinueLearningSection() {
        let sectionHeader = createSectionHeader(title: "Continue Learning")
        contentView.addArrangedSubview(sectionHeader)
        
        let carouselView = createHorizontalCarousel()
        contentView.addArrangedSubview(carouselView)
    }
    
    private func createSectionHeader(title: String) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold) // Slightly smaller
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4), // Reduced
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4), // Reduced
            container.heightAnchor.constraint(equalToConstant: 24) // Reduced from 28
        ])
        
        return container
    }
    
    private func createHorizontalCarousel() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: Constants.horizontalPadding, bottom: 0, right: Constants.horizontalPadding)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = Constants.elementSpacing
        hStack.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(hStack)
        container.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: Constants.carouselHeight),
            
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            hStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        // Sample images
        let imageNames = ["cl_1", "cl_2", "ride_home", "cl_1", "cl_2"]
        imageNames.forEach { name in
            hStack.addArrangedSubview(createImageCard(imageName: name, title: getTitleForImage(name)))
        }
        
        return container
    }
    
    private func createImageCard(imageName: String, title: String) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = Constants.cornerRadius
        card.clipsToBounds = true
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 4
        card.layer.shadowOpacity = 0.1
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray5
        
        if let img = UIImage(named: imageName) {
            imageView.image = img
        } else {
            imageView.image = UIImage(systemName: "music.note")?
                .withTintColor(.systemGray2, renderingMode: .alwaysOriginal)
        }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
        gradientLayer.locations = [0.5, 1.0]
        
        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(imageView)
        card.addSubview(gradientView)
        card.addSubview(label)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Constants.cardSize.width),
            card.heightAnchor.constraint(equalToConstant: Constants.cardSize.height),
            
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            gradientView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: 60),
            
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        
        // Layout gradient after constraints are set
        DispatchQueue.main.async {
            gradientLayer.frame = gradientView.bounds
        }
        
        return card
    }
    
    // MARK: - Camera Functionality
    @objc private func uploadTapped() {
        showUploadOptions()
    }
    
    private func showUploadOptions() {
        let alertController = UIAlertController(title: "Upload Content", message: "Choose an option", preferredStyle: .actionSheet)
        
        // Camera option
        let cameraAction = UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
            self?.openCamera()
        }
        cameraAction.setValue(UIImage(systemName: "camera"), forKey: "image")
        
        // Photo Library option
        let libraryAction = UIAlertAction(title: "Choose from Library", style: .default) { [weak self] _ in
            self?.openPhotoLibrary()
        }
        libraryAction.setValue(UIImage(systemName: "photo.on.rectangle"), forKey: "image")
        
        // Cancel option
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(cameraAction)
        alertController.addAction(libraryAction)
        alertController.addAction(cancelAction)
        
        // For iPad support
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = uploadButton
            popoverController.sourceRect = uploadButton.bounds
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func openCamera() {
        // Check if camera is available
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(title: "Camera Not Available", message: "This device doesn't have a camera")
            return
        }
        
        // Check camera permissions
        checkCameraPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.presentImagePicker(sourceType: .camera)
                } else {
                    self?.showCameraPermissionsAlert()
                }
            }
        }
    }
    
    private func openPhotoLibrary() {
        checkPhotoLibraryPermissions { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.presentImagePicker(sourceType: .photoLibrary)
                } else {
                    self?.showPhotoLibraryPermissionsAlert()
                }
            }
        }
    }
    
    private func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func checkPhotoLibraryPermissions(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                completion(status == .authorized || status == .limited)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = sourceType
        imagePicker.allowsEditing = true
        
        if sourceType == .camera {
            imagePicker.cameraCaptureMode = .photo
            imagePicker.cameraDevice = .rear
        }
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    private func showCameraPermissionsAlert() {
        showAlert(
            title: "Camera Access Required",
            message: "Please enable camera access in Settings to take photos",
            showSettings: true
        )
    }
    
    private func showPhotoLibraryPermissionsAlert() {
        showAlert(
            title: "Photo Library Access Required",
            message: "Please enable photo library access in Settings to choose photos",
            showSettings: true
        )
    }
    
    private func showAlert(title: String, message: String, showSettings: Bool = false) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        if showSettings {
            let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            alert.addAction(settingsAction)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Titles
    private func getTitleForImage(_ imageName: String) -> String {
        let titles: [String: String] = [
            "arrival": "The Arrival",
            "meridian": "Meridian",
            "classic": "Classic Suite",
            "fur_elise": "Fur Elise",
            "nocturne": "Nocturne",
            "sonata": "Moonlight Sonata",
            "prelude": "Prelude",
            "rhapsody": "Rhapsody"
        ]
        return titles[imageName] ?? imageName.capitalized
    }
    
    // MARK: - Top NavBar
    private func setupTopNavBar() {
        let props = useTopNavBar.getProps(
            username: "Mukul",
            dayNumber: 5,
            onProfileTap: { [weak self] in self?.navigateToProfile() },
            onDayBadgeTap: { [weak self] in self?.showStreakDetails() }
        )
        
        topNavBar = TopNavBar.create(props: props)
        topNavBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topNavBar)
    }
    
    // MARK: - Constraints
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // NavBar - Minimal top padding
            topNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.topNavBarTopPadding),
            topNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.horizontalPadding),
            topNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.horizontalPadding),
            topNavBar.heightAnchor.constraint(equalToConstant: 56), // Reduced height
            
            // ScrollView - Minimal top padding
            scrollView.topAnchor.constraint(equalTo: topNavBar.bottomAnchor, constant: Constants.scrollViewTopPadding),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Upload container constraints
        NSLayoutConstraint.activate([
            uploadContainer.heightAnchor.constraint(equalToConstant: Constants.uploadContainerHeight),
            
            uploadIcon.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            uploadIcon.centerYAnchor.constraint(equalTo: uploadContainer.centerYAnchor, constant: -10), // Reduced
            uploadIcon.widthAnchor.constraint(equalToConstant: 45), // Reduced
            uploadIcon.heightAnchor.constraint(equalToConstant: 45), // Reduced
            
            uploadLabel.topAnchor.constraint(equalTo: uploadIcon.bottomAnchor, constant: 8), // Reduced
            uploadLabel.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            uploadLabel.leadingAnchor.constraint(greaterThanOrEqualTo: uploadContainer.leadingAnchor, constant: 16),
            uploadLabel.trailingAnchor.constraint(lessThanOrEqualTo: uploadContainer.trailingAnchor, constant: -16),
            
            uploadButton.heightAnchor.constraint(equalToConstant: Constants.buttonHeight)
        ])
    }
    
    // MARK: - Actions
    private func navigateToProfile() {
        navigationController?.pushViewController(ProfileViewController(), animated: true)
    }
    
    private func showStreakDetails() {
        print("Streak details tapped")
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension UploadScreen: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
            // Handle the selected image here
            print("Image selected: \(image.size)")
            // You can upload the image, display it, or process it further
            showImageUploadSuccess(image: image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    private func showImageUploadSuccess(image: UIImage) {
        let alert = UIAlertController(
            title: "Upload Successful",
            message: "Your image has been selected successfully",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

import Foundation
import UIKit

class UploadScreen: UIViewController {
    
    // MARK: - UI Components
    private var topNavBar: TopNavBar!
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let uploadContainer = UIView()
    private let uploadIcon = UIImageView()
    private let uploadButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        addContinueLearningSection()
    }
    
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .white
        
        setupTopNavBar()
        
        // ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        // Main vertical layout
        contentView.axis = .vertical
        contentView.spacing = 22
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Upload container with padding
        uploadContainer.backgroundColor = .systemGray6
        uploadContainer.layer.cornerRadius = 20
        uploadContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let innerPadding = UIView()
        innerPadding.translatesAutoresizingMaskIntoConstraints = false
        uploadContainer.addSubview(innerPadding)
        
        // Icon in center
        uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
        uploadIcon.tintColor = .systemGray3
        uploadIcon.contentMode = .scaleAspectFit
        uploadIcon.translatesAutoresizingMaskIntoConstraints = false
        innerPadding.addSubview(uploadIcon)
        
        // Add upload container into main layout
        contentView.addArrangedSubview(uploadContainer)
        
        // Upload button
        uploadButton.setTitle("Upload", for: .normal)
        uploadButton.backgroundColor = UIColor(red: 0.96, green: 0.71, blue: 0.34, alpha: 1.0)
        uploadButton.setTitleColor(.black, for: .normal)
        uploadButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        uploadButton.layer.cornerRadius = 12
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addArrangedSubview(uploadButton)
    }
    
    
    // MARK: ✅ Continue Learning Carousel
    private func addContinueLearningSection() {
        let sectionHeader = UILabel()
        sectionHeader.text = "Continue Learning"
        sectionHeader.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionHeader.textColor = .black
        contentView.addArrangedSubview(sectionHeader)
        
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 10).isActive = true
        contentView.addArrangedSubview(spacer)
        
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = 16
        hStack.translatesAutoresizingMaskIntoConstraints = false
        
        scroll.addSubview(hStack)
        contentView.addArrangedSubview(scroll)
        
        scroll.heightAnchor.constraint(equalToConstant: 180).isActive = true
        
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: scroll.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            hStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            hStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            hStack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])
        
        // Sample images
        let imageNames = ["cl_1", "cl_2", "ride_home", "cl_1", "cl_2"]
        
        imageNames.forEach { name in
            hStack.addArrangedSubview(createImageCard(imageName: name, title: getTitleForImage(name)))
        }
    }
    
    
    // MARK: Helper: Create Image Card
    private func createImageCard(imageName: String, title: String) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 12
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        if let img = UIImage(named: imageName) {
            imageView.image = img
        } else {
            imageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
            imageView.image = UIImage(systemName: "music.note")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        }
        
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.backgroundColor = UIColor(white: 0, alpha: 0.7)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(imageView)
        card.addSubview(label)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 140),
            card.heightAnchor.constraint(equalToConstant: 160),
            
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            label.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return card
    }
    
    
    // MARK: Titles
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
    
    
    // MARK: Top NavBar
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
    
    
    // MARK: Constraints
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // NavBar
            topNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            topNavBar.heightAnchor.constraint(equalToConstant: 80),
            
            // Scroll
            scrollView.topAnchor.constraint(equalTo: topNavBar.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content Stack
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        
        // ✅ Upload container padded equally
        let padding: CGFloat = 20
        
        NSLayoutConstraint.activate([
            uploadContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            uploadContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            uploadContainer.heightAnchor.constraint(equalToConstant: 180),
            
            uploadIcon.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            uploadIcon.centerYAnchor.constraint(equalTo: uploadContainer.centerYAnchor),
            uploadIcon.widthAnchor.constraint(equalToConstant: 45),
            uploadIcon.heightAnchor.constraint(equalToConstant: 45),
            
            uploadButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            uploadButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            uploadButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    
    // MARK: Actions
    @objc private func uploadTapped() {
        print("Upload button tapped")
    }
    
    private func navigateToProfile() {
        navigationController?.pushViewController(ProfileViewController(), animated: true)
    }
    
    private func showStreakDetails() {
        print("Streak details tapped")
    }
}

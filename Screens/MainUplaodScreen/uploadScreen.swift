import Foundation
import UIKit

class UploadScreen: UIViewController {
    
    // MARK: - UI Components
    private var topNavBar: TopNavBar!
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let uploadBox = UIView()
    private let uploadIcon = UIImageView()
    private let uploadButton = UIButton()
    private let recentUploadsLabel = UILabel()
    private let albumStackView = UIStackView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // Setup TopNavBar using hook
        setupTopNavBar()
        
        // Setup Scroll View
        setupScrollView()
        
        // Upload Box
        uploadBox.backgroundColor = .systemGray6
        uploadBox.layer.cornerRadius = 20
        uploadBox.translatesAutoresizingMaskIntoConstraints = false
        
        // Upload Icon
        uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
        uploadIcon.tintColor = .systemGray3
        uploadIcon.contentMode = .scaleAspectFit
        uploadIcon.translatesAutoresizingMaskIntoConstraints = false
        
        // Upload Button
        uploadButton.setTitle("Upload", for: .normal)
        uploadButton.backgroundColor = UIColor(red: 0.96, green: 0.71, blue: 0.34, alpha: 1.0)
        uploadButton.setTitleColor(.black, for: .normal)
        uploadButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        uploadButton.layer.cornerRadius = 12
        uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Recent Uploads Label
        recentUploadsLabel.text = "Recent Uploads ›"
        recentUploadsLabel.textColor = .systemGray
        recentUploadsLabel.font = .boldSystemFont(ofSize: 14)
        recentUploadsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Album Stack
        albumStackView.axis = .vertical
        albumStackView.spacing = 15
        albumStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add sample albums
        addAlbumCovers()
        
        // Add to view hierarchy
        uploadBox.addSubview(uploadIcon)
        contentView.addSubview(uploadBox)
        contentView.addSubview(uploadButton)
        contentView.addSubview(recentUploadsLabel)
        contentView.addSubview(albumStackView)
    }
    
    private func setupTopNavBar() {
        // Use the hook to get navbar props
        let navBarProps = useTopNavBar.getProps(
            username: "Mukul",
            dayNumber: 5,
            onProfileTap: { [weak self] in
                self?.navigateToProfile()
            },
            onDayBadgeTap: { [weak self] in
                self?.showStreakDetails()
            }
        )
        
        // Create navbar with props
        topNavBar = TopNavBar.create(props: navBarProps)
        topNavBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topNavBar)
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
    }
    
    private func addAlbumCovers() {
        // Sample album covers
        let album1 = createAlbumView(title: "RIDE – New Album", color: .systemBlue)
        let album2 = createAlbumView(title: "Summer Vibes", color: .systemOrange)
        let album3 = createAlbumView(title: "Chill Lo-fi", color: .systemPurple)
        
        albumStackView.addArrangedSubview(album1)
        albumStackView.addArrangedSubview(album2)
        albumStackView.addArrangedSubview(album3)
    }
    
    private func createAlbumView(title: String, color: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
        
        return view
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Top Nav Bar
            topNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            topNavBar.heightAnchor.constraint(equalToConstant: 80),
            
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: topNavBar.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Upload Box
            uploadBox.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            uploadBox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            uploadBox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            uploadBox.heightAnchor.constraint(equalToConstant: 180),
            
            // Upload Icon
            uploadIcon.centerXAnchor.constraint(equalTo: uploadBox.centerXAnchor),
            uploadIcon.centerYAnchor.constraint(equalTo: uploadBox.centerYAnchor),
            uploadIcon.widthAnchor.constraint(equalToConstant: 40),
            uploadIcon.heightAnchor.constraint(equalToConstant: 40),
            
            // Upload Button
            uploadButton.topAnchor.constraint(equalTo: uploadBox.bottomAnchor, constant: 20),
            uploadButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            uploadButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            uploadButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Recent Uploads Label
            recentUploadsLabel.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 30),
            recentUploadsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            recentUploadsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Album Stack
            albumStackView.topAnchor.constraint(equalTo: recentUploadsLabel.bottomAnchor, constant: 15),
            albumStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            albumStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            albumStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    @objc private func uploadTapped() {
        print("Upload button tapped")
        // Implement upload logic
    }
    
    private func navigateToProfile() {
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    private func showStreakDetails() {
        print("Show streak details")
        // Implement streak logic
    }
}

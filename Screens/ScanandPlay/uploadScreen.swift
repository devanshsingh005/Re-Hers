//
//  uploadScreen.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

class ReHearseViewController: UIViewController {
    
    // MARK: - UI Components
    private let topNavView = UIView()
    private let appTitleLabel = UILabel()
    private let recordButton = UIButton()
    private let profileImageView = UIImageView()
    private let editNameLabel = UILabel()
    private let uploadBox = UIView()
    private let uploadIcon = UIImageView()
    private let uploadButton = UIButton()
    private let recentUploadsLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let albumStackView = UIStackView()
    private let bottomNavView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // Top Navigation
        setupTopNavigation()
        
        // Edit Name Label
        editNameLabel.text = "Edit Name ✎"
        editNameLabel.textColor = .systemGray
        editNameLabel.font = .boldSystemFont(ofSize: 14)
        editNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Recent Uploads Label
        recentUploadsLabel.text = "Recent Uploads ›"
        recentUploadsLabel.textColor = .systemGray
        recentUploadsLabel.font = .boldSystemFont(ofSize: 14)
        recentUploadsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Scroll View Setup
        setupScrollView()
        
        // Bottom Navigation
        setupBottomNavigation()
        
        // Add subviews
        view.addSubview(topNavView)
        view.addSubview(editNameLabel)
        view.addSubview(uploadBox)
        uploadBox.addSubview(uploadIcon)
        view.addSubview(uploadButton)
        view.addSubview(recentUploadsLabel)
        view.addSubview(scrollView)
        view.addSubview(bottomNavView)
        
        scrollView.addSubview(contentView)
        contentView.addSubview(albumStackView)
    }
    
    private func setupTopNavigation() {
        topNavView.translatesAutoresizingMaskIntoConstraints = false
        
        // Keyboard Icon
        let keyboardIcon = UIImageView()
        keyboardIcon.image = UIImage(systemName: "keyboard")
        keyboardIcon.tintColor = .black
        keyboardIcon.translatesAutoresizingMaskIntoConstraints = false
        
        // App Title
        appTitleLabel.text = "Re-Hearse"
        appTitleLabel.font = .boldSystemFont(ofSize: 18)
        appTitleLabel.textColor = .black
        appTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Record Button
        recordButton.setImage(UIImage(systemName: "record.circle"), for: .normal)
        recordButton.tintColor = .black
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Profile Image
        profileImageView.image = UIImage(systemName: "person.circle.fill")
        profileImageView.tintColor = .systemPink
        profileImageView.layer.cornerRadius = 16
        profileImageView.clipsToBounds = true
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        
        topNavView.addSubview(keyboardIcon)
        topNavView.addSubview(appTitleLabel)
        topNavView.addSubview(recordButton)
        topNavView.addSubview(profileImageView)
        
        NSLayoutConstraint.activate([
            keyboardIcon.leadingAnchor.constraint(equalTo: topNavView.leadingAnchor),
            keyboardIcon.centerYAnchor.constraint(equalTo: topNavView.centerYAnchor),
            keyboardIcon.widthAnchor.constraint(equalToConstant: 20),
            keyboardIcon.heightAnchor.constraint(equalToConstant: 20),
            
            appTitleLabel.leadingAnchor.constraint(equalTo: keyboardIcon.trailingAnchor, constant: 8),
            appTitleLabel.centerYAnchor.constraint(equalTo: topNavView.centerYAnchor),
            
            profileImageView.trailingAnchor.constraint(equalTo: topNavView.trailingAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: topNavView.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 32),
            profileImageView.heightAnchor.constraint(equalToConstant: 32),
            
            recordButton.trailingAnchor.constraint(equalTo: profileImageView.leadingAnchor, constant: -15),
            recordButton.centerYAnchor.constraint(equalTo: topNavView.centerYAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 32),
            recordButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        albumStackView.axis = .vertical
        albumStackView.spacing = 15
        albumStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add sample album covers
        addAlbumCovers()
    }
    
    private func addAlbumCovers() {
        // Album 1 - Futuristic Neon Grid
        let album1 = createAlbumView(
            title: "RIDE – New Album",
            backgroundColor: .systemBlue,
            isGrid: true
        )
        
        // Album 2 - Purple Vinyl
        let album2 = createAlbumView(
            title: "",
            backgroundColor: .systemPurple,
            isGrid: false
        )
        
        // Add vinyl overlay to album 2
        addVinylOverlay(to: album2)
        
        // Add parental advisory label to album 2
        addParentalAdvisoryLabel(to: album2)
        
        albumStackView.addArrangedSubview(album1)
        albumStackView.addArrangedSubview(album2)
        
        // Add more sample albums to demonstrate scrolling
        for i in 3...6 {
            let album = createAlbumView(
                title: "Album \(i)",
                backgroundColor: [.systemGreen, .systemOrange, .systemRed, .systemTeal][i-3],
                isGrid: i % 2 == 0
            )
            albumStackView.addArrangedSubview(album)
        }
    }
    
    private func createAlbumView(title: String, backgroundColor: UIColor, isGrid: Bool) -> UIView {
        let albumView = UIView()
        albumView.backgroundColor = backgroundColor
        albumView.layer.cornerRadius = 12
        albumView.translatesAutoresizingMaskIntoConstraints = false
        albumView.heightAnchor.constraint(equalTo: albumView.widthAnchor).isActive = true
        
        if isGrid {
            addGridPattern(to: albumView)
        }
        
        if !title.isEmpty {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .white
            titleLabel.font = .boldSystemFont(ofSize: 13)
            titleLabel.numberOfLines = 2
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            
            albumView.addSubview(titleLabel)
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: albumView.leadingAnchor, constant: 12),
                titleLabel.trailingAnchor.constraint(equalTo: albumView.trailingAnchor, constant: -12),
                titleLabel.bottomAnchor.constraint(equalTo: albumView.bottomAnchor, constant: -12)
            ])
        }
        
        return albumView
    }
    
    private func addGridPattern(to view: UIView) {
        let gridLayer = CAShapeLayer()
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        gridLayer.lineWidth = 1
        
        let path = UIBezierPath()
        let gridSize: CGFloat = 20
        
        // Vertical lines
        for i in 1...Int(view.bounds.width/gridSize) {
            let x = CGFloat(i) * gridSize
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: view.bounds.height))
        }
        
        // Horizontal lines
        for i in 1...Int(view.bounds.height/gridSize) {
            let y = CGFloat(i) * gridSize
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: view.bounds.width, y: y))
        }
        
        gridLayer.path = path.cgPath
        view.layer.addSublayer(gridLayer)
    }
    
    private func addVinylOverlay(to albumView: UIView) {
        let vinylView = UIView()
        vinylView.backgroundColor = .black
        vinylView.layer.cornerRadius = 30
        vinylView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add vinyl grooves
        let grooveLayer = CAShapeLayer()
        grooveLayer.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        
        let groovePath = UIBezierPath()
        for i in 0..<18 {
            let angle = CGFloat(i) * (CGFloat.pi / 9)
            groovePath.move(to: CGPoint(x: 30, y: 30))
            groovePath.addArc(withCenter: CGPoint(x: 30, y: 30),
                            radius: 25 + CGFloat(i % 3),
                            startAngle: angle,
                            endAngle: angle + 0.1,
                            clockwise: true)
        }
        
        grooveLayer.path = groovePath.cgPath
        grooveLayer.strokeColor = UIColor.darkGray.cgColor
        grooveLayer.lineWidth = 1
        vinylView.layer.addSublayer(grooveLayer)
        
        // Center hole
        let centerView = UIView()
        centerView.backgroundColor = .systemGray4
        centerView.layer.cornerRadius = 5
        centerView.translatesAutoresizingMaskIntoConstraints = false
        
        albumView.addSubview(vinylView)
        vinylView.addSubview(centerView)
        
        NSLayoutConstraint.activate([
            vinylView.centerXAnchor.constraint(equalTo: albumView.centerXAnchor),
            vinylView.centerYAnchor.constraint(equalTo: albumView.centerYAnchor),
            vinylView.widthAnchor.constraint(equalToConstant: 60),
            vinylView.heightAnchor.constraint(equalToConstant: 60),
            
            centerView.centerXAnchor.constraint(equalTo: vinylView.centerXAnchor),
            centerView.centerYAnchor.constraint(equalTo: vinylView.centerYAnchor),
            centerView.widthAnchor.constraint(equalToConstant: 10),
            centerView.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
    
    private func addParentalAdvisoryLabel(to albumView: UIView) {
        let label = UILabel()
        label.text = "PARENTAL ADVISORY"
        label.font = .boldSystemFont(ofSize: 8)
        label.textColor = .black
        label.backgroundColor = .white
        label.textAlignment = .center
        label.layer.cornerRadius = 2
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        albumView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: albumView.topAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: albumView.trailingAnchor, constant: -8),
            label.widthAnchor.constraint(equalToConstant: 60),
            label.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func setupBottomNavigation() {
        bottomNavView.backgroundColor = .systemGray6
        bottomNavView.layer.cornerRadius = 20
        bottomNavView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomNavView.translatesAutoresizingMaskIntoConstraints = false
        
        let homeButton = createNavButton(systemName: "house.fill")
        let musicButton = createNavButton(systemName: "music.note")
        let plusButton = createNavButton(systemName: "plus", isCenter: true)
        let statsButton = createNavButton(systemName: "chart.bar")
        let searchButton = createNavButton(systemName: "magnifyingglass")
        
        let navStack = UIStackView(arrangedSubviews: [homeButton, musicButton, plusButton, statsButton, searchButton])
        navStack.axis = .horizontal
        navStack.distribution = .equalSpacing
        navStack.translatesAutoresizingMaskIntoConstraints = false
        
        bottomNavView.addSubview(navStack)
        
        NSLayoutConstraint.activate([
            navStack.leadingAnchor.constraint(equalTo: bottomNavView.leadingAnchor, constant: 30),
            navStack.trailingAnchor.constraint(equalTo: bottomNavView.trailingAnchor, constant: -30),
            navStack.topAnchor.constraint(equalTo: bottomNavView.topAnchor, constant: 15),
            navStack.bottomAnchor.constraint(equalTo: bottomNavView.bottomAnchor, constant: -15)
        ])
    }
    
    private func createNavButton(systemName: String, isCenter: Bool = false) -> UIButton {
        let button = UIButton()
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = isCenter ? .black : .systemGray
        button.backgroundColor = isCenter ? UIColor(red: 0.96, green: 0.71, blue: 0.34, alpha: 1.0) : .clear
        
        if isCenter {
            button.layer.cornerRadius = 25
            button.widthAnchor.constraint(equalToConstant: 50).isActive = true
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        }
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Top Navigation
            topNavView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topNavView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topNavView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            topNavView.heightAnchor.constraint(equalToConstant: 44),
            
            // Edit Name
            editNameLabel.topAnchor.constraint(equalTo: topNavView.bottomAnchor, constant: 15),
            editNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Upload Box
            uploadBox.topAnchor.constraint(equalTo: editNameLabel.bottomAnchor, constant: 30),
            uploadBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            uploadBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            uploadBox.heightAnchor.constraint(equalToConstant: 180),
            
            // Upload Icon
            uploadIcon.centerXAnchor.constraint(equalTo: uploadBox.centerXAnchor),
            uploadIcon.centerYAnchor.constraint(equalTo: uploadBox.centerYAnchor),
            uploadIcon.widthAnchor.constraint(equalToConstant: 40),
            uploadIcon.heightAnchor.constraint(equalToConstant: 40),
            
            // Upload Button
            uploadButton.topAnchor.constraint(equalTo: uploadBox.bottomAnchor, constant: 20),
            uploadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            uploadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            uploadButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Recent Uploads Label
            recentUploadsLabel.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 30),
            recentUploadsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            recentUploadsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: recentUploadsLabel.bottomAnchor, constant: 15),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: bottomNavView.topAnchor, constant: -20),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Album Stack View
            albumStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            albumStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            albumStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            albumStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Bottom Navigation
            bottomNavView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomNavView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomNavView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomNavView.heightAnchor.constraint(equalToConstant: 85)
        ])
    }
}

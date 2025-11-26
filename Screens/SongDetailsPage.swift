//
//  SongDetailsPage.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 24/11/25.
//

import UIKit
import Foundation

class SongDetailViewController: UIViewController {
    
    // MARK: - Passed Data From Previous Page
    var passedImage: UIImage?
    var passedSongTitle: String?
    var passedArtist: String?
    
    // MARK: - Scroll Container
    private let mainScrollView = UIScrollView()
    private let contentView = UIView()
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(title: "")
    
    private let albumArtBackgroundContainer = UIView()
    private let albumArtBackgroundView = UIImageView()
    private let albumArtCardView = UIImageView()
    
    private let bookmarkButton = UIButton(type: .system)
    private let songTitleLabel = UILabel()
    private let artistLabel = UILabel()
    
    private let playAlongButton = UIButton(type: .system)
    private let animationButton = UIButton(type: .system)
    private let buttonStack = UIStackView()
    
    private let sheetContainer = UIView()
    private let pageLabel = UILabel()
    private let sheetImageView = UIImageView()
    private let pageNextButton = UIButton(type: .system)
    
    private let bottomSpacer = UIView()
    
    // MARK: - Page Data
    private var currentPage = 1
    private let totalPages = 6
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.isHidden = true
        
        setupUI()
        setupScroll()
        setupContent()
        setupConstraints()
        setupActions()
        
        applyPassedData()
        updatePage()
    }
    
    // MARK: - Apply Passed Data
    private func applyPassedData() {
        let img = passedImage ?? UIImage(named: "ride_home")

        albumArtBackgroundView.image = img
        albumArtCardView.image = img
        
        songTitleLabel.text = passedSongTitle ?? "Unknown Song"
        artistLabel.text = passedArtist ?? "Unknown Artist"
    }
    
    // MARK: - Navbar UI
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        setupNavBar()
    }
    
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible = true
        navBar.isProfileVisible = true
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.setTitle("")
        
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
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
    
    // MARK: - Scroll View Setup
    private func setupScroll() {
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.alwaysBounceVertical = true
        view.addSubview(mainScrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: mainScrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor)
        ])
    }
    
    
    // MARK: - UI Content Setup
    private func setupContent() {
        
        albumArtBackgroundContainer.layer.cornerRadius = 24
        albumArtBackgroundContainer.clipsToBounds = true
        albumArtBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtBackgroundContainer)
        
        albumArtBackgroundView.contentMode = .scaleAspectFill
        albumArtBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        albumArtBackgroundContainer.addSubview(albumArtBackgroundView)
        
        albumArtCardView.layer.cornerRadius = 24
        albumArtCardView.contentMode = .scaleAspectFill
        albumArtCardView.clipsToBounds = true
        albumArtCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtCardView)
        
        bookmarkButton.setImage(UIImage(systemName: "bookmark"), for: .normal)
        bookmarkButton.tintColor = .systemGray
        bookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bookmarkButton)
        
        songTitleLabel.textAlignment = .center
        songTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        songTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(songTitleLabel)
        
        artistLabel.textAlignment = .center
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = .darkGray
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)
        
        
        // MARK: - Updated Buttons
        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.layer.cornerRadius = 12
        playAlongButton.setTitleColor(.white, for: .normal)
        playAlongButton.backgroundColor = UIColor(red: 0.96, green: 0.71, blue: 0.13, alpha: 1)
        
        animationButton.setTitle("Animation", for: .normal)
        animationButton.layer.cornerRadius = 12
        animationButton.setTitleColor(.darkGray, for: .normal)
        animationButton.backgroundColor = .systemGray5
        
        playAlongButton.layer.shadowOpacity = 0.15
        playAlongButton.layer.shadowRadius = 6
        playAlongButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        animationButton.layer.shadowOpacity = 0.10
        animationButton.layer.shadowRadius = 6
        animationButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        
        // MARK: - Increased spacing between buttons
        buttonStack.axis = .horizontal
        buttonStack.spacing = 26        // ⬅️ Increased spacing here
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(playAlongButton)
        buttonStack.addArrangedSubview(animationButton)
        contentView.addSubview(buttonStack)
        
        
        sheetContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sheetContainer)
        
        pageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        pageLabel.textAlignment = .center
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.addSubview(pageLabel)
        
        sheetImageView.layer.cornerRadius = 12
        sheetImageView.clipsToBounds = true
        sheetImageView.contentMode = .scaleAspectFill
        sheetImageView.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.addSubview(sheetImageView)
        
        pageNextButton.setImage(UIImage(systemName: "chevron.right.circle.fill"), for: .normal)
        pageNextButton.tintColor = .darkGray
        pageNextButton.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.addSubview(pageNextButton)
        
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.backgroundColor = .clear
        contentView.addSubview(bottomSpacer)
    }
    
    
    // MARK: - Constraints
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            
            albumArtBackgroundContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            albumArtBackgroundContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            albumArtBackgroundContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            albumArtBackgroundContainer.heightAnchor.constraint(equalToConstant: 180),
            
            albumArtBackgroundView.topAnchor.constraint(equalTo: albumArtBackgroundContainer.topAnchor),
            albumArtBackgroundView.bottomAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor),
            albumArtBackgroundView.leadingAnchor.constraint(equalTo: albumArtBackgroundContainer.leadingAnchor),
            albumArtBackgroundView.trailingAnchor.constraint(equalTo: albumArtBackgroundContainer.trailingAnchor),
            
            albumArtCardView.centerXAnchor.constraint(equalTo: albumArtBackgroundContainer.centerXAnchor),
            albumArtCardView.centerYAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor, constant: -28),
            albumArtCardView.widthAnchor.constraint(equalToConstant: 140),
            albumArtCardView.heightAnchor.constraint(equalToConstant: 140),
            
            bookmarkButton.leadingAnchor.constraint(equalTo: albumArtCardView.trailingAnchor, constant: 10),
            bookmarkButton.centerYAnchor.constraint(equalTo: albumArtCardView.centerYAnchor, constant: 20),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 36),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 36),
            
            songTitleLabel.topAnchor.constraint(equalTo: albumArtCardView.bottomAnchor, constant: 18),
            songTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            artistLabel.topAnchor.constraint(equalTo: songTitleLabel.bottomAnchor, constant: 2),
            artistLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            buttonStack.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 28),
            buttonStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonStack.widthAnchor.constraint(equalToConstant: 320),
            buttonStack.heightAnchor.constraint(equalToConstant: 46),
            
            sheetContainer.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 32),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            pageLabel.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 10),
            pageLabel.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            
            sheetImageView.topAnchor.constraint(equalTo: pageLabel.bottomAnchor, constant: 10),
            sheetImageView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor),
            sheetImageView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor),
            sheetImageView.heightAnchor.constraint(equalToConstant: 380),
            
            pageNextButton.centerYAnchor.constraint(equalTo: sheetImageView.centerYAnchor),
            pageNextButton.trailingAnchor.constraint(equalTo: sheetImageView.trailingAnchor, constant: -10),
            pageNextButton.widthAnchor.constraint(equalToConstant: 34),
            pageNextButton.heightAnchor.constraint(equalToConstant: 34),
            
            bottomSpacer.topAnchor.constraint(equalTo: sheetContainer.bottomAnchor),
            bottomSpacer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomSpacer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomSpacer.heightAnchor.constraint(equalToConstant: 300),
            bottomSpacer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    
    // MARK: - Actions
    private func setupActions() {
        playAlongButton.addTarget(self, action: #selector(tabPlayAlong), for: .touchUpInside)
        animationButton.addTarget(self, action: #selector(openPianoAnimationVC), for: .touchUpInside)
        bookmarkButton.addTarget(self, action: #selector(bookmarkTapped), for: .touchUpInside)
        pageNextButton.addTarget(self, action: #selector(nextPageTapped), for: .touchUpInside)
    }

    @objc func openPianoAnimationVC() {
        let vc = PianoAnimationViewController()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
    
    
    // MARK: - Page Flip
    private func updatePage() {
        pageLabel.text = "\(currentPage)/\(totalPages)"
        sheetImageView.image = UIImage(named: "sheet\(currentPage).png")
    }
    
    @objc private func nextPageTapped() {
        currentPage += 1
        if currentPage > totalPages { currentPage = 1 }
        
        let transition = CATransition()
        transition.type = .push
        transition.subtype = .fromRight
        transition.duration = 0.3
        sheetImageView.layer.add(transition, forKey: "flip")
        
        updatePage()
    }
    
    
    // MARK: - Button States
    @objc private func tabPlayAlong() {
        playAlongButton.backgroundColor = UIColor(red: 0.96, green: 0.71, blue: 0.13, alpha: 1)
        playAlongButton.setTitleColor(.white, for: .normal)
        animationButton.backgroundColor = .systemGray5
        animationButton.setTitleColor(.darkGray, for: .normal)
    }
    
    @objc private func tabAnimation() {
        animationButton.backgroundColor = UIColor(red: 0.96, green: 0.71, blue: 0.13, alpha: 1)
        animationButton.setTitleColor(.white, for: .normal)
        playAlongButton.backgroundColor = .systemGray5
        playAlongButton.setTitleColor(.darkGray, for: .normal)
    }
    
    @objc private func bookmarkTapped() {
        let bookmarked = bookmarkButton.tintColor == .systemYellow
        bookmarkButton.tintColor = bookmarked ? .systemGray : .systemYellow
        bookmarkButton.setImage(UIImage(systemName: bookmarked ? "bookmark" : "bookmark.fill"), for: .normal)
    }
}

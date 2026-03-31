//
//  SongDetailsPage.swift
//  Re-Hearse_v1
//

import UIKit
import Foundation

class PlayAlongSongDetailViewController: UIViewController {
    
    // MARK: - Passed Data From Previous Page
    var passedImage: UIImage?
    var passedSongTitle: String?
    var passedArtist: String?
    
    // MARK: - Scroll Container
    private let mainScrollView = UIScrollView()
    private let contentView = UIView()
    
    // MARK: - UI Elements
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
        
        view.backgroundColor = ComponentColors.SongDetailScreen.background
        navigationController?.setNavigationBarHidden(false, animated: false)
        
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
        let img = passedImage ?? UIImage(named: "trackimage_1")
        albumArtBackgroundView.image = img
        albumArtCardView.image = img
        songTitleLabel.text = passedSongTitle ?? "Unknown Song"
        artistLabel.text = passedArtist ?? "Unknown Artist"
    }
    
    // MARK: - Navbar UI
    private func setupUI() {
        view.backgroundColor = ComponentColors.SongDetailScreen.background
        setupNavBar()
    }
    
    private func setupNavBar() {
        _ = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: passedSongTitle ?? "Song",
            subtitle: passedArtist ?? "Play Along",
            backAction: #selector(handleBack)
        )
        navigationItem.rightBarButtonItems = NavigationBarHelper.createNativeRightBarButtonItems(
            target: self,
            profileAction: #selector(handleProfile),
            chordAction: #selector(handleChord)
        )
    }
    
    // MARK: - Scroll View Setup
    private func setupScroll() {
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.alwaysBounceVertical = true
        view.addSubview(mainScrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
        bookmarkButton.tintColor = ComponentColors.SongCard.chevronIcon
        bookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bookmarkButton)
        
        songTitleLabel.textAlignment = .center
        songTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        songTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(songTitleLabel)
        
        artistLabel.textAlignment = .center
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = ComponentColors.SongDetailScreen.artistName
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)
        
        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.layer.cornerRadius = 12
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        
        animationButton.setTitle("Animation", for: .normal)
        animationButton.layer.cornerRadius = 12
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        
        playAlongButton.layer.shadowOpacity = 0.15
        playAlongButton.layer.shadowRadius = 6
        playAlongButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        animationButton.layer.shadowOpacity = 0.10
        animationButton.layer.shadowRadius = 6
        animationButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        buttonStack.axis = .horizontal
        buttonStack.spacing = 26
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
        playAlongButton.addTarget(self, action: #selector(openPlayAlongVC), for: .touchUpInside)
        animationButton.addTarget(self, action: #selector(openPianoAnimationVC), for: .touchUpInside)
        bookmarkButton.addTarget(self, action: #selector(bookmarkTapped), for: .touchUpInside)
        pageNextButton.addTarget(self, action: #selector(nextPageTapped), for: .touchUpInside)
    }

    // MARK: - Navigation Actions

    @objc private func openPlayAlongVC() {
        // Update button visual state
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)

        let vc = PlayAlongViewController()
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func openPianoAnimationVC() {
        // Update button visual state
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)

        let vc = AnimationViewController()
        vc.songTitle = passedSongTitle ?? "Animation"

        // Fix 1: Wrap in a landscape-forcing navigation controller so rotation works
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
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

    @objc private func bookmarkTapped() {
        let bookmarked = bookmarkButton.tintColor == UIColor.systemYellow
        bookmarkButton.tintColor = bookmarked ? ComponentColors.SongCard.chevronIcon : .systemYellow
        bookmarkButton.setImage(UIImage(systemName: bookmarked ? "bookmark" : "bookmark.fill"), for: .normal)
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleChord() {
        navigationController?.pushViewController(ChordRecognitionViewController(), animated: true)
    }

    @objc private func handleProfile() {
        navigationController?.pushViewController(UserProfileViewController(), animated: true)
    }
}


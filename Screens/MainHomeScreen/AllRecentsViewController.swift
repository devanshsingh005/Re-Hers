//
//  AllRecentsViewController.swift
//  Re-Hearse_v1
//

import UIKit

final class AllRecentsViewController: UIViewController {

    private let scrollView  = UIScrollView()
    private let contentStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.HomeScreen.background
        
        title = "Recent History"
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .white
        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        
        setupScroll()
        fetchAll()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func fetchAll() {
        spinner.startAnimating()
        Task {
            do {
                let recents = try await RecentPlayService.shared.fetchRecents(limit: 50)
                await MainActor.run { self.populate(recents) }
            } catch {
                print("[AllRecents] ❌ \(error)")
                await MainActor.run { self.showEmpty() }
            }
        }
    }

    private func populate(_ recents: [RecentPlay]) {
        spinner.stopAnimating()
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !recents.isEmpty else { showEmpty(); return }

        for recent in recents {
            let card = createRow(song: recent.songs, date: recent.lastPlayedAt)
            contentStack.addArrangedSubview(card)
        }

        let bottomSpacer = UIView()
        bottomSpacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        contentStack.addArrangedSubview(bottomSpacer)
    }

    private func showEmpty() {
        spinner.stopAnimating()
        let label = UILabel()
        label.text = "No recent plays yet.\nStart playing songs to build your history!"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gray
        contentStack.addArrangedSubview(label)
    }

    private func createRow(song: Song, date: Date) -> UIView {
        let cardBgColor = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : .white }
        let card = UIView()
        card.backgroundColor = cardBgColor
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.translatesAutoresizingMaskIntoConstraints = false

        let randomImg = "trackimage_\(Int.random(in: 1...16))"
        let placeholder = UIImage(named: randomImg) ?? UIImage(named: "trackimage_1")
        let imageView = UIImageView(image: placeholder)
        
        if let coverUrl = song.coverImageUrl, !coverUrl.isEmpty {
            if coverUrl.hasPrefix("http") {
                ImageLoader.shared.loadImage(from: coverUrl) { [weak imageView] img in
                    if let img = img { imageView?.image = img }
                }
            } else {
                imageView.image = UIImage(named: coverUrl) ?? placeholder
            }
        }
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = song.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = ComponentColors.SongCard.titleText

        let timeAgo = Self.timeAgoString(from: date)
        let subtitleLabel = UILabel()
        subtitleLabel.text = "\(song.composer) • \(timeAgo)"
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = ComponentColors.SongCard.metadataText

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical; textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let playBtn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        playBtn.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: config), for: .normal)
        playBtn.tintColor = ComponentColors.HomeScreen.actionButtonFill
        playBtn.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(imageView)
        card.addSubview(textStack)
        card.addSubview(playBtn)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 80),

            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            imageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 52),
            imageView.heightAnchor.constraint(equalToConstant: 52),

            textStack.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: playBtn.leadingAnchor, constant: -10),

            playBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            playBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            playBtn.widthAnchor.constraint(equalToConstant: 32),
            playBtn.heightAnchor.constraint(equalToConstant: 32),
        ])

        return card
    }

    private static func timeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}

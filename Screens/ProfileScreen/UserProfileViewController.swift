//
//  ProfileScreen.swift
//  Re-Hearse_v1
//

import UIKit

final class UserProfileViewController: UIViewController {

    // MARK: - UI
    private let navBar = UIView()
    private let backButton = UIButton(type: .system)

    private let scrollView = UIScrollView()
    private let contentView = UIStackView()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.isHidden = true

        setupNavBar()
        setupScroll()
        buildUI()
        view.bringSubviewToFront(navBar)
    }

    // MARK: - NAVBAR
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.backgroundColor = .clear

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .black
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(backButton)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 68),

            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - ScrollView
    private func setupScroll() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.alignment = .fill

        scrollView.contentInsetAdjustmentBehavior = .never

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Build Screen UI
    private func buildUI() {
        contentView.addArrangedSubview(buildHeader())
        contentView.addArrangedSubview(buildStatsSection())
       // contentView.addArrangedSubview(buildPracticeGraphCard())
        contentView.addArrangedSubview(buildSavedSection())

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 36).isActive = true
        contentView.addArrangedSubview(spacer)
    }

    // MARK: - HEADER
    private func buildHeader() -> UIView {
        let header = GradientHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false

        let profileImg = UIImageView()
        profileImg.image = UIImage(systemName: "person.fill")
        profileImg.tintColor = .black
        profileImg.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        profileImg.layer.cornerRadius = 50
        profileImg.clipsToBounds = true
        profileImg.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = "Mukul Parashar"
        nameLabel.font = .boldSystemFont(ofSize: 22)

        let locationLabel = UILabel()
        locationLabel.text = "Chennai, Tamil Nadu, India"
        locationLabel.font = .systemFont(ofSize: 14)
        locationLabel.textColor = .darkGray

        let editBtn = UIButton(type: .system)
        editBtn.setTitle("Edit", for: .normal)
        editBtn.titleLabel?.font = .systemFont(ofSize: 16)

        let infoStack = UIStackView(arrangedSubviews: [nameLabel, locationLabel, editBtn])
        infoStack.axis = .vertical
        infoStack.spacing = 6
        infoStack.alignment = .leading
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        header.addSubviews(profileImg, infoStack)

        NSLayoutConstraint.activate([
            profileImg.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            profileImg.topAnchor.constraint(equalTo: header.topAnchor, constant: 120),
            profileImg.heightAnchor.constraint(equalToConstant: 100),
            profileImg.widthAnchor.constraint(equalToConstant: 100),

            infoStack.leadingAnchor.constraint(equalTo: profileImg.trailingAnchor, constant: 30),
            infoStack.centerYAnchor.constraint(equalTo: profileImg.centerYAnchor),
            infoStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),

            header.heightAnchor.constraint(equalToConstant: 260)
        ])

        return header
    }

    // MARK: - STATS
    private func buildStatsSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let playlist = statView(number: "23", label: "PLAYLISTS")
        let followers = statView(number: "58", label: "FOLLOWERS")
        let following = statView(number: "43", label: "FOLLOWING")

        let stack = UIStackView(arrangedSubviews: [playlist, followers, following])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
       

        return container
    }

    private func statView(number: String, label: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4

        let num = UILabel()
        num.text = number
        num.font = .boldSystemFont(ofSize: 18)

        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = .gray

        stack.addArrangedSubview(num)
        stack.addArrangedSubview(lbl)
        return stack
    }

    // MARK: - PRACTICE GRAPH (UPDATED + ACCURATE)
    private func buildPracticeGraphCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.12, alpha: 1)
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false

        // STREAK
        let streak = UILabel()
        streak.text = " __day streak"
        streak.font = .systemFont(ofSize: 15, weight: .semibold)
        streak.textColor = UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1)

        // HOURS
        let hours = UILabel()
        hours.text = "⏱️ __ hrs spent"
        hours.font = .systemFont(ofSize: 15, weight: .semibold)
        hours.textColor = .white

        let topRow = UIStackView(arrangedSubviews: [streak, hours])
        topRow.axis = .horizontal
        topRow.distribution = .equalSpacing

        let title = UILabel()
        title.text = "Practice Graph"
        title.font = .boldSystemFont(ofSize: 20)
        title.textColor = .white

        let graphBox = UIView()
        graphBox.backgroundColor = UIColor(white: 0.12, alpha: 1)
        graphBox.layer.cornerRadius = 16
        graphBox.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let stack = UIStackView(arrangedSubviews: [topRow, title, graphBox])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])

        return card
    }

    // MARK: - SAVED SECTION
    private func buildSavedSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Saved"
        label.font = .boldSystemFont(ofSize: 18)

        let stack = UIStackView(arrangedSubviews: [
            label,
            savedRow(title: "Shazam", likes: "7 likes"),
            savedRow(title: "Roadtrip", likes: "4 likes")
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func savedRow(title: String, likes: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "music.note"))
        icon.tintColor = .black
        icon.translatesAutoresizingMaskIntoConstraints = false

        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 16, weight: .medium)

        let l = UILabel()
        l.text = likes
        l.font = .systemFont(ofSize: 12)
        l.textColor = .gray

        let textStack = UIStackView(arrangedSubviews: [t, l])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .gray
        arrow.translatesAutoresizingMaskIntoConstraints = false

        row.addSubviews(icon, textStack, arrow)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.heightAnchor.constraint(equalToConstant: 50),
            icon.widthAnchor.constraint(equalToConstant: 50),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            arrow.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            arrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.heightAnchor.constraint(equalToConstant: 60)
        ])

        return row
    }
}

// MARK: - Gradient Header
final class GradientHeaderView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        gradient.colors = [
            UIColor(red: 1.0, green: 0.75, blue: 0.36, alpha: 1).cgColor,
            UIColor.white.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}

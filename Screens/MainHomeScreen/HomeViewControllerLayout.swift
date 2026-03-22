//
//  HomeViewControllerLayout.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    func setupNavBar() {
        navigationItem.title = "" // Empty because custom header handles large text, and titleView handles inline
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        
        let (headerStack, subTitle) = NavigationBarHelper.createInlineTitleView(title: "Home", subtitle: "Welcome")
        self.inlineSubtitleLabel = subTitle
        navigationItem.titleView = headerStack
        
        navigationItem.rightBarButtonItems = nil
        setupNavigationBarAppearance()
    }
    
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
    }
    
    @objc private func handleDayBadgeTap() {
        // Keeping method signature alive in case it gets wired back later
    }
    
    func setupWelcomeLabel() {
        // Handled via Custom Header
    }

    func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = false
        
        // Pin strictly ignoring safe area top so it flows beautifully behind the nav bar
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 32
        contentView.alignment = .fill
        
        // By using custom layout, we can control EXACTLY how high the text sits.
        // UIScrollView natively adds the Navigation Bar + Safe Area inset (~91pt) automatically.
        // We set a negative constant (-28) to pull the "Home" text drastically UP, 
        // effectively overlapping the transparent navigation bar, to sit tight under the Dynamic Island seamlessly.
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 90), 
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -24),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -100),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }

    // MARK: - Section header with optional "See all"
    func makeSectionHeader(_ text: String, action: (() -> Void)? = nil) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = text
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = ComponentColors.HomeScreen.sectionHeaderText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        guard let action else { return titleLabel }

        let seeAll = UIButton(type: .system)
        seeAll.setTitle("See all", for: .normal)
        seeAll.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        seeAll.setTitleColor(ComponentColors.HomeScreen.actionButtonFill, for: .normal)
        seeAll.translatesAutoresizingMaskIntoConstraints = false
        seeAll.addAction(UIAction { _ in action() }, for: .touchUpInside)

        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel); row.addSubview(seeAll)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            seeAll.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            seeAll.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: seeAll.leadingAnchor, constant: -8),
            row.heightAnchor.constraint(equalToConstant: 30),
        ])
        return row
    }

    @objc func openPianoPage() {
        navigationController?.pushViewController(PianoAnimationkeyboardViewController(), animated: true)
    }

    @objc func playAlongTapped() {
        navigationController?.pushViewController(PlayAlongViewController(), animated: true)
    }
}

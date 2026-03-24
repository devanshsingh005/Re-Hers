//
//  HomeViewControllerLayout.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase

extension HomeViewController {

    func setupNavBar() {
        navigationItem.title = "" 
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        
        let (headerStack, subTitle) = NavigationBarHelper.createInlineTitleView(title: "Home", subtitle: "Welcome back, User")
        self.inlineSubtitleLabel = subTitle
        navigationItem.titleView = headerStack
        
        navigationItem.rightBarButtonItems = nil
    }

    func setupNavBackground() {
        navBackgroundView.alpha = 0
        navBackgroundView.isUserInteractionEnabled = false
        navBackgroundView.contentView.isUserInteractionEnabled = false
        view.addSubview(navBackgroundView)
        
        navShadowLayer.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        navShadowLayer.translatesAutoresizingMaskIntoConstraints = false
        navBackgroundView.contentView.addSubview(navShadowLayer)
        
        let window = view.window?.windowScene?.keyWindow ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        let topPadding = window?.safeAreaInsets.top ?? 0
        let navHeight: CGFloat = 44 + topPadding
        
        navBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            navBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBackgroundView.heightAnchor.constraint(equalToConstant: navHeight),
            
            navShadowLayer.leadingAnchor.constraint(equalTo: navBackgroundView.leadingAnchor),
            navShadowLayer.trailingAnchor.constraint(equalTo: navBackgroundView.trailingAnchor),
            navShadowLayer.bottomAnchor.constraint(equalTo: navBackgroundView.bottomAnchor),
            navShadowLayer.heightAnchor.constraint(equalToConstant: 0.33)
        ])
        
        navBackgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        navBackgroundView.layer.borderWidth = 0.5
    }

    func setupCustomLargeHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertArrangedSubview(headerContainer, at: 0)
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Home"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Welcome back, User"
        largeSubtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        largeSubtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(largeSubtitleLabel)
        headerContainer.addSubview(labelStack)
        
        largeProfileButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        largeProfileButton.layer.cornerRadius = 20
        largeProfileButton.layer.masksToBounds = true
        largeProfileButton.clipsToBounds = true
        largeProfileButton.layer.borderWidth    = 1.0
        largeProfileButton.layer.borderColor    = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        
        // Default placeholder
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .secondaryLabel
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        headerContainer.addSubview(largeProfileButton)
        
        NSLayoutConstraint.activate([
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -20),
            largeProfileButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    func syncNavBarAlpha() {
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let alpha = NavigationBarHelper.calculateNavBarAlpha(offset: offset)
        
        navigationItem.titleView?.alpha = alpha
        navigationItem.titleView?.isHidden = (alpha == 0)
        navBackgroundView.alpha = alpha
    }

    func fetchProfileData() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    largeSubtitleLabel.text = "Welcome back, User"
                    inlineSubtitleLabel?.text = "Welcome back, User"
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
                return
            }
            struct Profile: Decodable {
                let full_name: String?
                let avatar_url: String?
            }
            do {
                let profile: Profile = try await SupabaseManager.shared.client
                    .from("profiles").select().eq("id", value: user.id).single().execute().value
                    
                await MainActor.run {
                    let name = profile.full_name?.isEmpty == false ? profile.full_name! : "User"
                    largeSubtitleLabel.text = "Welcome back, \(name)"
                    inlineSubtitleLabel?.text = "Welcome back, \(name)"
                }
                
                if let avatarUrl = profile.avatar_url, !avatarUrl.isEmpty {
                    await loadAndSetProfileImage(from: avatarUrl)
                } else {
                    await MainActor.run {
                        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                        largeProfileButton.tintColor = .secondaryLabel
                    }
                }
            } catch {
                await MainActor.run {
                    largeSubtitleLabel.text = "Welcome back, User"
                    inlineSubtitleLabel?.text = "Welcome back, User"
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
            }
        }
    }

    private func loadAndSetProfileImage(from urlString: String) async {
        if urlString.starts(with: "icon_") {
            await MainActor.run {
                if let img = UIImage(named: urlString) {
                    largeProfileButton.setImage(img, for: .normal)
                    largeProfileButton.tintColor = .clear
                }
            }
            return
        }
        var finalURL = urlString
        if urlString.contains("supabase.co/storage/v1/object/useprofile/") && !urlString.contains("/public/") {
            finalURL = urlString.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
        }
        guard let url = URL(string: finalURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
            if let img = UIImage(data: data) {
                await MainActor.run {
                    largeProfileButton.setImage(img, for: .normal)
                    largeProfileButton.tintColor = .clear
                }
            }
        } catch {}
    }

    @objc private func handleProfileTap() {
        NavigationBarHelper.animateButtonPress(largeProfileButton) { [weak self] in
            self?.navigationController?.pushViewController(UserProfileViewController(), animated: true)
        }
    }

    func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = false

        scrollView.addSubview(contentView)
        contentView.axis      = .vertical
        contentView.spacing   = 12
        contentView.alignment = .fill
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 96),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
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
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            seeAll.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -20),
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

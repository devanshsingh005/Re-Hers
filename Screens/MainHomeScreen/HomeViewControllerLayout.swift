//
//  HomeViewControllerLayout.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase
import Auth
internal import PostgREST

extension HomeViewController {

    func updateNavBackgroundAppearance() {
        NavigationBarHelper.updateNavigationBackgroundAppearance(
            navBackgroundView,
            shadowView: navShadowLayer,
            traitCollection: traitCollection
        )
    }

    func setupNavBar() {
        inlineSubtitleLabel = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: "Home",
            subtitle: "Welcome , User"
        )
        
        navigationItem.rightBarButtonItems = nil
    }

    func setupNavBackground() {
        updateNavBackgroundAppearance()
        NavigationBarHelper.installNavigationBackground(
            navBackgroundView,
            shadowView: navShadowLayer,
            in: view
        )
    }

    func setupCustomLargeHeader() -> UIView {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Home"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Welcome , admin"
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
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .secondaryLabel
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        headerContainer.addSubview(largeProfileButton)
        
        NavigationBarHelper.loadProfileImage(into: largeProfileButton)
        
        NSLayoutConstraint.activate([
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -20),
            largeProfileButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        return headerContainer
    }

    func syncNavBarAlpha() {
        NavigationBarHelper.syncNavigationBarAlpha(
            scrollView: scrollView,
            navigationItem: navigationItem,
            navBackgroundView: navBackgroundView
        )
    }

    func fetchProfileData() {
        Task {
            if GuestSessionManager.shared.isGuest() {
                let guestName = GuestSessionManager.shared.guestDisplayName() ?? "Guest"
                let guestAvatar = GuestSessionManager.shared.guestAvatarIdentifier()

                await MainActor.run {
                    largeSubtitleLabel.text = "Welcome , \(guestName)"
                    inlineSubtitleLabel?.text = "Welcome , \(guestName)"
                }

                if let guestAvatar, !guestAvatar.isEmpty {
                    await loadAndSetProfileImage(from: guestAvatar)
                } else {
                    await MainActor.run {
                        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                        largeProfileButton.tintColor = .secondaryLabel
                    }
                }
                return
            }

            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    largeSubtitleLabel.text = "Welcome , User"
                    inlineSubtitleLabel?.text = "Welcome , User"
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
                return
            }
            do {
                let profile: UserProfile = try await SupabaseManager.shared.client
                    .from("profiles").select().eq("id", value: user.id).single().execute().value
                    
                await MainActor.run {
                    let name = profile.full_name?.isEmpty == false ? profile.full_name! : "User"
                    largeSubtitleLabel.text = "Welcome , \(name)"
                    inlineSubtitleLabel?.text = "Welcome , \(name)"
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
                    largeSubtitleLabel.text = "Welcome , User"
                    inlineSubtitleLabel?.text = "Welcome , User"
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
        guard let finalURL = await NavigationBarHelper.signedProfileURLString(from: urlString),
              let url = URL(string: finalURL) else { return }
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
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        let headerContainer = setupCustomLargeHeader()
        contentView.addSubview(headerContainer)

        mainStackView.axis      = .vertical
        mainStackView.spacing   = 12
        mainStackView.alignment = .fill
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 96),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            mainStackView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 8),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
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
        seeAll.setTitle("See more", for: .normal)
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
        guard let song = self.topSong else { return }
        let detailVC = DiscoverSongDetailViewController()
        detailVC.song = song
        detailVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(detailVC, animated: true)
    }

    @objc func playAlongTapped() {
        guard !presentGuestPlayAlongGateIfNeeded() else { return }

        let alert = UIAlertController(
            title: "Choose a Song First",
            message: "Play Along needs processed sheet music for a specific song. Open a song detail page and start Play Along from there.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @discardableResult
    private func presentGuestPlayAlongGateIfNeeded() -> Bool {
        guard !GuestFeatureAccessPolicy.allowsPlayAlong else { return false }
        guard GuestSessionManager.shared.isGuest(), presentedViewController == nil else { return false }

        let modal = GuestFeatureGateModal(
            featureName: "play along",
            onSignUp: { [weak self] in
                self?.presentGuestAuth(mode: .signUp)
            },
            onLogIn: { [weak self] in
                self?.presentGuestAuth(mode: .logIn)
            }
        )

        present(modal, animated: true)
        return true
    }

    private func presentGuestAuth(mode: AuthViewController.AuthMode) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }

            let authVC = AuthViewController(initialMode: mode)
            let nav = UINavigationController(rootViewController: authVC)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        }
    }
}

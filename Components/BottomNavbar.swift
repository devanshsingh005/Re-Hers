//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

final class AppNavigationController: UINavigationController, UINavigationControllerDelegate {
    /// Called as a screen is about to show, with whether it is this tab's root.
    var onWillShow: ((_ isRoot: Bool) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController, animated: Bool) {
        onWillShow?(viewController === viewControllers.first)
        // An interactive back swipe that is cancelled leaves the pushed screen showing.
        transitionCoordinator?.notifyWhenInteractionChanges { [weak self] context in
            guard context.isCancelled, let self else { return }
            self.onWillShow?(self.topViewController === self.viewControllers.first)
        }
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if !viewControllers.isEmpty {
            viewController.hidesBottomBarWhenPushed = true
            // Only tab roots use large titles; pushed screens keep their own headers.
            if viewController.navigationItem.largeTitleDisplayMode == .automatic {
                viewController.navigationItem.largeTitleDisplayMode = .never
            }
        }
        super.pushViewController(viewController, animated: animated)
    }
}

/// Home, Library and Settings, plus Search as its own tab (iOS 26 shows it apart, Apple Music style).
/// The last-played sheet rides above the tab bar as a mini player.
class MainTabBarController: UITabBarController, UITabBarControllerDelegate {

    enum TabID: String {
        case home, library, settings, search
    }

    private lazy var homeNav     = makeNav(HomeViewController())
    private lazy var libraryNav  = makeNav(DiscoverViewController())
    private lazy var settingsNav = makeNav(UserProfileViewController())
    private lazy var searchNav   = makeNav(AppSearchViewController())

    private let miniPlayer = MiniPlayerView()
    /// Pre-iOS 26 the mini player floats above the tab bar in this container.
    private var legacyMiniPlayerContainer: UIVisualEffectView?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        if #available(iOS 18.0, *) {
            mode = .tabBar
        }
        setupTabs()
        setupAppearance()
        setupMiniPlayer()

        InAppNotificationStore.shared.start()
        Task {
            guard let songs = try? await SongService.shared.fetchSongs() else { return }
            InAppNotificationStore.shared.noteLibrarySongs(songs)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(refreshMiniPlayer),
                                               name: LastPlayedStore.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshMiniPlayer),
                                               name: LocalSheetLibrary.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshMiniPlayer),
                                               name: SupabaseManager.authStatusChangedNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func makeNav(_ root: UIViewController) -> AppNavigationController {
        let nav = AppNavigationController(rootViewController: root)
        nav.onWillShow = { [weak self, weak nav] _ in
            guard let self, let nav, nav === self.selectedViewController else { return }
            self.refreshMiniPlayer()
        }
        return nav
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        refreshMiniPlayer()
    }

    @available(iOS 18.0, *)
    func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
        refreshMiniPlayer()
    }

    /// Pushed screens hide the tab bar; the mini player goes with it so it never covers their buttons.
    private var isShowingTabRoot: Bool {
        guard let nav = selectedViewController as? UINavigationController else { return true }
        // During a push the new screen is already on the stack; during a pop it's already off.
        return nav.viewControllers.count <= 1
    }

    // MARK: - Tabs

    private func setupTabs() {
        if #available(iOS 18.0, *) {
            let home = UITab(title: "Home", image: UIImage(systemName: "house.fill"),
                             identifier: TabID.home.rawValue) { [unowned self] _ in self.homeNav }
            let library = UITab(title: "Library", image: UIImage(systemName: "music.note.list"),
                                identifier: TabID.library.rawValue) { [unowned self] _ in self.libraryNav }
            let settings = UITab(title: "Settings", image: UIImage(systemName: "gearshape.fill"),
                                 identifier: TabID.settings.rawValue) { [unowned self] _ in self.settingsNav }
            let search = UISearchTab { [unowned self] _ in self.searchNav }
            if #available(iOS 26.0, *) {
                search.automaticallyActivatesSearch = true
            }
            tabs = [home, library, settings, search]
        } else {
            homeNav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"),
                                              selectedImage: UIImage(systemName: "house.fill"))
            libraryNav.tabBarItem = UITabBarItem(title: "Library", image: UIImage(systemName: "music.note.list"), tag: 1)
            settingsNav.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"),
                                                  selectedImage: UIImage(systemName: "gearshape.fill"))
            searchNav.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 3)
            viewControllers = [homeNav, libraryNav, settingsNav, searchNav]
        }
    }

    /// Switches to a tab and returns its navigation controller, popped to the root.
    @discardableResult
    func select(_ tab: TabID, popToRoot: Bool = true) -> UINavigationController {
        let nav: UINavigationController
        switch tab {
        case .home:     nav = homeNav
        case .library:  nav = libraryNav
        case .settings: nav = settingsNav
        case .search:   nav = searchNav
        }
        if #available(iOS 18.0, *), let uiTab = self.tab(forIdentifier: tab.rawValue) {
            selectedTab = uiTab
        } else {
            selectedViewController = nav
        }
        if popToRoot { nav.popToRootViewController(animated: false) }
        return nav
    }

    private func setupAppearance() {
        tabBar.tintColor = ComponentColors.TabBar.activeIcon
        if #available(iOS 26.0, *) {
            // Liquid Glass tab bar: let the system draw it and fold it away while scrolling down.
            tabBarMinimizeBehavior = .onScrollDown
            return
        }
        tabBar.unselectedItemTintColor = ComponentColors.TabBar.inactiveIcon
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    // MARK: - Mini player

    private func setupMiniPlayer() {
        miniPlayer.onOpen = { [weak self] in self?.openLastPlayed(resume: false) }
        miniPlayer.onResume = { [weak self] in self?.openLastPlayed(resume: true) }

        if #unavailable(iOS 26.0) {
            let container = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
            container.layer.cornerRadius = 16
            container.layer.cornerCurve = .continuous
            container.clipsToBounds = true
            container.translatesAutoresizingMaskIntoConstraints = false
            miniPlayer.translatesAutoresizingMaskIntoConstraints = false
            container.contentView.addSubview(miniPlayer)
            view.insertSubview(container, belowSubview: tabBar)
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                container.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -8),
                container.heightAnchor.constraint(equalToConstant: 56),
                miniPlayer.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor),
                miniPlayer.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor),
                miniPlayer.topAnchor.constraint(equalTo: container.contentView.topAnchor),
                miniPlayer.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
            ])
            legacyMiniPlayerContainer = container
        }
        refreshMiniPlayer()
    }

    @objc private func refreshMiniPlayer() {
        let item = LastPlayedStore.shared.current
        if let item { miniPlayer.configure(with: item) }

        if #available(iOS 26.0, *) {
            let wantsAccessory = item != nil && isShowingTabRoot
            if wantsAccessory, bottomAccessory == nil {
                setBottomAccessory(UITabAccessory(contentView: miniPlayer), animated: viewIfLoaded?.window != nil)
            } else if !wantsAccessory, bottomAccessory != nil {
                setBottomAccessory(nil, animated: viewIfLoaded?.window != nil)
            }
        } else {
            legacyMiniPlayerContainer?.isHidden = item == nil || !isShowingTabRoot
            for nav in [homeNav, libraryNav, settingsNav, searchNav] {
                nav.additionalSafeAreaInsets.bottom = item == nil ? 0 : 64
            }
        }
    }

    /// Opens the last-played sheet on the current tab. With `resume`, it goes straight back into
    /// Play Along or Animation once the sheet has loaded.
    func openLastPlayed(resume: Bool) {
        guard let item = LastPlayedStore.shared.current else {
            refreshMiniPlayer()
            return
        }
        let nav = (selectedViewController as? UINavigationController) ?? homeNav
        nav.presentedViewController?.dismiss(animated: false)

        let detail: UIViewController
        if let uploadId = item.uploadId {
            let vc = UploadPageNextViewController()
            vc.jobId = uploadId
            vc.autoStartMode = resume ? item.mode : nil
            detail = vc
        } else if let song = item.song {
            let vc = DiscoverSongDetailViewController()
            vc.song = song
            vc.autoStartMode = resume ? item.mode : nil
            detail = vc
        } else {
            return
        }
        nav.pushViewController(detail, animated: true)
    }

    // MARK: - Orientation Delegation

    /// On iPhone the tabs are portrait-only; Play Along and Animation are presented full screen
    /// with their own landscape mask, and closing them rotates the app back to portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if traitCollection.userInterfaceIdiom == .phone { return .portrait }
        return selectedViewController?.supportedInterfaceOrientations ?? .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if traitCollection.userInterfaceIdiom == .phone { return .portrait }
        return selectedViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
    }
}

extension UIViewController {
    /// The app's tab bar controller, from any screen inside it.
    var mainTabBarController: MainTabBarController? {
        (tabBarController as? MainTabBarController)
            ?? (view.window?.rootViewController as? MainTabBarController)
    }
}

// MARK: - Navigation Controller Orientation Delegation
extension UINavigationController {

    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return topViewController?.supportedInterfaceOrientations ?? .allButUpsideDown
    }

    override open var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return topViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
    }
}

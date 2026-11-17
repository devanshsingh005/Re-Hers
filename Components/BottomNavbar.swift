//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

/// iPad: how wide a screen's content may grow. Its tab's column follows the screen on top;
/// screens that don't say get a reading width.
protocol IPadContentWidth {
    var iPadContentWidth: CGFloat { get }
}

final class AppNavigationController: UINavigationController, UINavigationControllerDelegate {
    /// Called as a screen is about to show, with whether it is this tab's root.
    var onWillShow: ((_ isRoot: Bool) -> Void)?
    /// Called as a screen is about to show (and again if a back swipe is cancelled).
    var onWillShowController: ((UIViewController) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController, animated: Bool) {
        onWillShow?(viewController === viewControllers.first)
        onWillShowController?(viewController)
        // An interactive back swipe that is cancelled leaves the pushed screen showing.
        transitionCoordinator?.notifyWhenInteractionChanges { [weak self] context in
            guard context.isCancelled, let self else { return }
            self.onWillShow?(self.topViewController === self.viewControllers.first)
            if let top = self.topViewController { self.onWillShowController?(top) }
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

extension NSLayoutConstraint {
    /// The constraint at `priority`, for use inside `NSLayoutConstraint.activate([...])`.
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

/// Sizes that grow on iPad, where the screen is far taller than the phone layouts assume.
enum DeviceLayout {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    static func value(phone: CGFloat, pad: CGFloat) -> CGFloat { isPad ? pad : phone }
}

/// On iPad, keeps a tab's screens in a centred column over the app's background, so
/// phone-designed layouts don't stretch across a 13-inch screen. The column's width follows
/// the screen on top (`IPadContentWidth`): Home and the two-pane sheet pages are wide, lists
/// and settings keep a reading width. It fills the window when that is narrower.
final class ReadableColumnController: UIViewController {
    /// Lists, settings, forms: wide enough for rows, narrow enough to read.
    static let readingWidth: CGFloat = 700

    let content: UIViewController
    private var widthLimit: NSLayoutConstraint?

    init(content: UIViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var tabBarItem: UITabBarItem! {
        get { content.tabBarItem }
        set { content.tabBarItem = newValue }
    }

    static func width(for screen: UIViewController?) -> CGFloat {
        (screen as? IPadContentWidth)?.iPadContentWidth ?? readingWidth
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.App.screenBackground
        addChild(content)
        let column = content.view!
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)
        let fill = column.widthAnchor.constraint(equalTo: view.widthAnchor)
        fill.priority = .defaultHigh
        let top = (content as? UINavigationController)?.topViewController ?? content
        let limit = column.widthAnchor.constraint(lessThanOrEqualToConstant: Self.width(for: top))
        widthLimit = limit
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: view.topAnchor),
            column.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            column.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            limit,
            column.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor),
            fill,
        ])
        content.didMove(toParent: self)
    }

    /// Resizes the column for the screen about to show, along with its push or pop.
    func follow(_ screen: UIViewController, coordinator: UIViewControllerTransitionCoordinator?) {
        let width = Self.width(for: screen)
        guard let widthLimit, widthLimit.constant != width else { return }
        widthLimit.constant = width
        guard isViewLoaded, view.window != nil else { return }
        if let coordinator {
            coordinator.animate(alongsideTransition: { _ in self.view.layoutIfNeeded() })
        } else {
            view.layoutIfNeeded()
        }
    }

    override var childForStatusBarStyle: UIViewController? { content }
    override var childForStatusBarHidden: UIViewController? { content }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        content.preferredInterfaceOrientationForPresentation
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

    /// iPad: each tab's navigation sits in a readable-width column (see ReadableColumnController).
    private let usesColumns = UIDevice.current.userInterfaceIdiom == .pad
    private var columns: [ObjectIdentifier: ReadableColumnController] = [:]

    /// What the tab shows for `nav`: the navigation controller itself, or its iPad column.
    private func tabRoot(_ nav: AppNavigationController) -> UIViewController {
        guard usesColumns else { return nav }
        if let column = columns[ObjectIdentifier(nav)] { return column }
        let column = ReadableColumnController(content: nav)
        nav.onWillShowController = { [weak column, weak nav] screen in
            column?.follow(screen, coordinator: nav?.transitionCoordinator)
        }
        // the tab bar is told it is compact (so it sits at the bottom, as on iPhone); the screens
        // inside keep the iPad's regular width
        column.traitOverrides.horizontalSizeClass = .regular
        columns[ObjectIdentifier(nav)] = column
        return column
    }

    /// The selected tab's navigation controller.
    var selectedNav: UINavigationController? {
        (selectedViewController as? UINavigationController)
            ?? ((selectedViewController as? ReadableColumnController)?.content as? UINavigationController)
    }

    private let miniPlayer = MiniPlayerView()
    /// Pre-iOS 26 the mini player floats above the tab bar in this container.
    private var legacyMiniPlayerContainer: UIVisualEffectView?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        if #available(iOS 18.0, *) {
            mode = .tabBar
        }
        // iPad: the tab bar floats at the bottom like the phone's instead of across the top
        if usesColumns { traitOverrides.horizontalSizeClass = .compact }
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
        nav.onWillShow = { [weak self, weak nav] isRoot in
            guard let self, let nav, nav === self.selectedNav else { return }
            // In a column the tab bar can't see the push, so hide it here like hidesBottomBarWhenPushed.
            if self.usesColumns { self.setTabBarHiddenForPush(!isRoot) }
            self.refreshMiniPlayer()
        }
        return nav
    }

    private func setTabBarHiddenForPush(_ hidden: Bool) {
        let animated = viewIfLoaded?.window != nil
        if #available(iOS 18.0, *) {
            guard isTabBarHidden != hidden else { return }
            setTabBarHidden(hidden, animated: animated)
        } else {
            tabBar.isHidden = hidden
        }
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if usesColumns { setTabBarHiddenForPush(!isShowingTabRoot) }
        refreshMiniPlayer()
    }

    @available(iOS 18.0, *)
    func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
        if usesColumns { setTabBarHiddenForPush(!isShowingTabRoot) }
        refreshMiniPlayer()
    }

    /// Pushed screens hide the tab bar; the mini player goes with it so it never covers their buttons.
    private var isShowingTabRoot: Bool {
        guard let nav = selectedNav else { return true }
        // During a push the new screen is already on the stack; during a pop it's already off.
        return nav.viewControllers.count <= 1
    }

    // MARK: - Tabs

    private func setupTabs() {
        if #available(iOS 18.0, *) {
            let home = UITab(title: "Home", image: UIImage(systemName: "house.fill"),
                             identifier: TabID.home.rawValue) { [unowned self] _ in self.tabRoot(self.homeNav) }
            let library = UITab(title: "Library", image: UIImage(systemName: "music.note.list"),
                                identifier: TabID.library.rawValue) { [unowned self] _ in self.tabRoot(self.libraryNav) }
            let settings = UITab(title: "Settings", image: UIImage(systemName: "gearshape.fill"),
                                 identifier: TabID.settings.rawValue) { [unowned self] _ in self.tabRoot(self.settingsNav) }
            let search = UISearchTab { [unowned self] _ in self.tabRoot(self.searchNav) }
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
            viewControllers = [homeNav, libraryNav, settingsNav, searchNav].map(tabRoot)
        }
    }

    /// Switches to a tab and returns its navigation controller, popped to the root.
    @discardableResult
    func select(_ tab: TabID, popToRoot: Bool = true) -> UINavigationController {
        let nav: AppNavigationController
        switch tab {
        case .home:     nav = homeNav
        case .library:  nav = libraryNav
        case .settings: nav = settingsNav
        case .search:   nav = searchNav
        }
        if #available(iOS 18.0, *), let uiTab = self.tab(forIdentifier: tab.rawValue) {
            selectedTab = uiTab
        } else {
            selectedViewController = tabRoot(nav)
        }
        if popToRoot { nav.popToRootViewController(animated: false) }
        return nav
    }

    private func setupAppearance() {
        tabBar.tintColor = ComponentColors.TabBar.activeIcon
        if #available(iOS 26.0, *) {
            // Liquid Glass tab bar drawn by the system. It folds away on scroll only while the
            // mini player is showing (see refreshMiniPlayer), so it stays full-size otherwise.
            tabBarMinimizeBehavior = .never
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
            // iPad Home shows the last-played sheet in its own column instead
            let homeHasItsOwn = usesColumns && selectedNav === homeNav
            let wantsAccessory = item != nil && isShowingTabRoot && !homeHasItsOwn
            if wantsAccessory, bottomAccessory == nil {
                setBottomAccessory(UITabAccessory(contentView: miniPlayer), animated: viewIfLoaded?.window != nil)
            } else if !wantsAccessory, bottomAccessory != nil {
                setBottomAccessory(nil, animated: viewIfLoaded?.window != nil)
            }
            // The minimized form (two round buttons) tucks the mini player in between them.
            // Without a recent song there is nothing to tuck in, so keep the full tab bar.
            tabBarMinimizeBehavior = wantsAccessory ? .onScrollDown : .never
        } else {
            legacyMiniPlayerContainer?.isHidden = item == nil || !isShowingTabRoot
                || (usesColumns && selectedNav === homeNav)
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
        let nav = selectedNav ?? homeNav
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
        return .landscape   // the iPad app is landscape throughout
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if traitCollection.userInterfaceIdiom == .phone { return .portrait }
        return .landscapeRight
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

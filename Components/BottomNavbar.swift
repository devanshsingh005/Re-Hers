//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

/// iPad: how wide a screen's content may grow (see `IPadScreenContainer`); screens that don't
/// say get a reading width.
protocol IPadContentWidth {
    var iPadContentWidth: CGFloat { get }
}

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

    override func pushViewController(_ pushed: UIViewController, animated: Bool) {
        // iPad: the screen comes in its own width-limited container, so the navigation never
        // resizes and pushes and pops animate as usual
        let viewController = IPadScreenContainer.wrapIfNeeded(pushed)
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
    /// iPad pages laid out for the phone grow by this much (text, spacing and components
    /// alike), so they keep their proportions on the larger screen.
    static let padScale: CGFloat = 1.25
    /// `value` at the iPad's scale (unchanged on iPhone).
    static func s(_ value: CGFloat) -> CGFloat { isPad ? (value * padScale).rounded() : value }
}

/// iPad: holds one screen in a centred column of the width it asks for (`IPadContentWidth`,
/// else a reading width), over the screen's own background. Each screen in a navigation stack
/// has its own container, so the stack never changes size and transitions stay smooth.
/// Navigation items, status bar, orientation and the scroll view the bars follow come from
/// the screen inside.
final class IPadScreenContainer: UIViewController {
    /// Lists, settings, forms: wide enough for rows, narrow enough to read.
    static let readingWidth: CGFloat = 900
    /// Screens at least this wide (Home) fill the window and need no container.
    static let fullWidth: CGFloat = 1400

    let content: UIViewController
    private let maxWidth: CGFloat
    private var widthConstraint: NSLayoutConstraint?

    /// `viewController` on a phone or when it fills the screen; otherwise in a container.
    static func wrapIfNeeded(_ viewController: UIViewController) -> UIViewController {
        guard DeviceLayout.isPad, !(viewController is IPadScreenContainer) else { return viewController }
        let width = (viewController as? IPadContentWidth)?.iPadContentWidth ?? readingWidth
        guard width < fullWidth else { return viewController }
        return IPadScreenContainer(content: viewController, maxWidth: width)
    }

    private init(content: UIViewController, maxWidth: CGFloat) {
        self.content = content
        self.maxWidth = maxWidth
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var navigationItem: UINavigationItem { content.navigationItem }
    override var title: String? {
        get { content.title }
        set { content.title = newValue }
    }
    override var tabBarItem: UITabBarItem! {
        get { content.tabBarItem }
        set { content.tabBarItem = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(content)
        let column = content.view!
        view.backgroundColor = column.backgroundColor ?? ComponentColors.App.screenBackground
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)
        // an exact width, min(window, limit), set on each layout: a "fill but at most" pair of
        // constraints conflicts on a wide screen and lets screens settle at their compact width
        let width = column.widthAnchor.constraint(equalToConstant: maxWidth)
        widthConstraint = width
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: view.topAnchor),
            column.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // within the safe area: on iPad the tab rail on the right adds to it
            column.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            width,
        ])
        content.didMove(toParent: self)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = min(view.bounds.inset(by: view.safeAreaInsets).width, maxWidth)
        if widthConstraint?.constant != width { widthConstraint?.constant = width }
    }

    override func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
        content.contentScrollView(for: edge)
    }
    override var childForStatusBarStyle: UIViewController? { content }
    override var childForStatusBarHidden: UIViewController? { content }
    override var childForHomeIndicatorAutoHidden: UIViewController? { content }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { content.supportedInterfaceOrientations }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        content.preferredInterfaceOrientationForPresentation
    }
}

extension UIViewController {
    /// The screen itself, out of its iPad container if it has one.
    var screen: UIViewController { (self as? IPadScreenContainer)?.content ?? self }

    /// Being popped (or removed) from its navigation stack, directly or in its iPad container.
    var isLeavingNavigationStack: Bool {
        isMovingFromParent || ((parent as? IPadScreenContainer)?.isMovingFromParent ?? false)
    }

    /// Being pushed onto its navigation stack, directly or in its iPad container.
    var isArrivingInNavigationStack: Bool {
        isMovingToParent || ((parent as? IPadScreenContainer)?.isMovingToParent ?? false)
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

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    /// What the tab shows for `nav`.
    private func tabRoot(_ nav: AppNavigationController) -> UIViewController { nav }

    /// The selected tab's navigation controller.
    var selectedNav: UINavigationController? { selectedViewController as? UINavigationController }

    private let miniPlayer = MiniPlayerView()
    /// Pre-iOS 26 (and on iPad) the mini player floats in this container: above the tab bar,
    /// or along the bottom beside the iPad's tab rail.
    private var legacyMiniPlayerContainer: UIVisualEffectView?

    /// iPad: the tabs in a column on the right instead of a tab bar along the bottom.
    private lazy var padRail = PadTabRail()
    private static let padMiniPlayerHeight: CGFloat = 72

    /// What lets people move between tabs: the iPad's tab rail, else the tab bar.
    var tabNavigationView: UIView { isPad ? padRail : tabBar }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        if #available(iOS 18.0, *) {
            mode = .tabBar
        }
        // iPad: the tab bar floats at the bottom like the phone's instead of across the top
        if isPad { traitOverrides.horizontalSizeClass = .compact }
        setupTabs()
        setupAppearance()
        if isPad { setupPadRail() }
        setupMiniPlayer()
        setupOfflineNote()

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
        let nav = AppNavigationController(rootViewController: IPadScreenContainer.wrapIfNeeded(root))
        // the tab bar is told it is compact (so it sits at the bottom); its screens keep the
        // iPad's regular width
        if isPad { nav.traitOverrides.horizontalSizeClass = .regular }
        nav.onWillShow = { [weak self, weak nav] _ in
            guard let self, let nav, nav === self.selectedNav else { return }
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

    /// The tab showing now.
    private var currentTab: TabID {
        switch selectedNav {
        case libraryNav: return .library
        case settingsNav: return .settings
        case searchNav: return .search
        default: return .home
        }
    }

    // MARK: - iPad tab rail

    private func setupPadRail() {
        if #available(iOS 18.0, *) { setTabBarHidden(true, animated: false) } else { tabBar.isHidden = true }
        padRail.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(padRail)
        NSLayoutConstraint.activate([
            padRail.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            padRail.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
        padRail.onSelect = { [weak self] tab in
            guard let self else { return }
            // the tab showing: back to its first screen, as tapping a tab bar item does
            self.select(tab, popToRoot: tab == self.currentTab)
            self.refreshMiniPlayer()
        }
        padRail.setSelected(currentTab)
    }

    /// Room for the rail (and the mini player under it) in each tab's first screen.
    private func updatePadInsets(miniPlayerShown: Bool) {
        guard isPad else { return }
        let right = PadTabRail.width + 16 + 12
        let bottom = miniPlayerShown ? Self.padMiniPlayerHeight + 14 + 8 : 0
        for nav in [homeNav, libraryNav, settingsNav, searchNav] {
            guard let root = nav.viewControllers.first else { continue }
            let insets = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: right)
            if root.additionalSafeAreaInsets != insets { root.additionalSafeAreaInsets = insets }
        }
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

    // MARK: - Offline note

    private let offlineNote = UIView()

    /// A small pill at the top while there's no connection: pages keep showing their saved data.
    private func setupOfflineNote() {
        let icon = UIImageView(image: UIImage(systemName: "wifi.slash"))
        icon.tintColor = .white
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let label = UILabel()
        label.text = "Offline · showing saved data"
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 6
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        offlineNote.backgroundColor = UIColor(white: 0.18, alpha: 0.94)
        offlineNote.layer.cornerRadius = 15
        offlineNote.layer.cornerCurve = .continuous
        offlineNote.isUserInteractionEnabled = false
        offlineNote.isAccessibilityElement = true
        offlineNote.accessibilityLabel = "Offline. Showing saved data."
        offlineNote.translatesAutoresizingMaskIntoConstraints = false
        offlineNote.addSubview(row)
        view.addSubview(offlineNote)
        NSLayoutConstraint.activate([
            offlineNote.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            offlineNote.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            offlineNote.heightAnchor.constraint(equalToConstant: 30),
            row.leadingAnchor.constraint(equalTo: offlineNote.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: offlineNote.trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: offlineNote.centerYAnchor),
        ])

        Connectivity.shared.start()
        updateOfflineNote(animated: false)
        NotificationCenter.default.addObserver(forName: Connectivity.didChangeNotification, object: nil,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateOfflineNote(animated: true) }
        }
    }

    private func updateOfflineNote(animated: Bool) {
        let offline = !Connectivity.shared.isOnline
        view.bringSubviewToFront(offlineNote)
        UIView.animate(withDuration: animated ? 0.25 : 0) {
            self.offlineNote.alpha = offline ? 1 : 0
            self.offlineNote.transform = offline ? .identity : CGAffineTransform(translationX: 0, y: -12)
        }
    }

    // MARK: - Mini player

    private func setupMiniPlayer() {
        miniPlayer.onOpen = { [weak self] in self?.openLastPlayed(resume: false) }
        miniPlayer.onResume = { [weak self] in self?.openLastPlayed(resume: true) }

        if isPad {
            setupPadMiniPlayer()
        } else if #unavailable(iOS 26.0) {
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

    /// iPad: a larger mini player along the bottom, from the left edge to the tab rail.
    private func setupPadMiniPlayer() {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) { effect = UIGlassEffect() } else { effect = UIBlurEffect(style: .systemChromeMaterial) }
        let container = UIVisualEffectView(effect: effect)
        container.layer.cornerRadius = Self.padMiniPlayerHeight / 2
        container.layer.cornerCurve = .continuous
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        miniPlayer.isLarge = true
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false
        container.contentView.addSubview(miniPlayer)
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: padRail.leadingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            container.heightAnchor.constraint(equalToConstant: Self.padMiniPlayerHeight),
            miniPlayer.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: 6),
            miniPlayer.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -10),
            miniPlayer.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            miniPlayer.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
        ])
        legacyMiniPlayerContainer = container
    }

    @objc private func refreshMiniPlayer() {
        let item = LastPlayedStore.shared.current
        if let item { miniPlayer.configure(with: item) }

        if isPad {
            // the rail and mini player belong to the tabs' first screens; pushed screens get the
            // whole window, as they did without the tab bar
            let showRail = isShowingTabRoot
            let showMini = item != nil && showRail
            padRail.setSelected(currentTab)
            UIView.animate(withDuration: viewIfLoaded?.window != nil ? 0.25 : 0) {
                self.padRail.alpha = showRail ? 1 : 0
                self.legacyMiniPlayerContainer?.alpha = showMini ? 1 : 0
            }
            padRail.isUserInteractionEnabled = showRail
            legacyMiniPlayerContainer?.isUserInteractionEnabled = showMini
            view.bringSubviewToFront(padRail)
            if let container = legacyMiniPlayerContainer { view.bringSubviewToFront(container) }
            updatePadInsets(miniPlayerShown: showMini)
            return
        }

        if #available(iOS 26.0, *) {
            let wantsAccessory = item != nil && isShowingTabRoot
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

// MARK: - iPad tab rail

/// iPad: Home, Library and Settings in a glass column on the right, with Search in its own
/// round button below, in place of the tab bar along the bottom.
final class PadTabRail: UIView {
    static let width: CGFloat = 88
    var onSelect: ((MainTabBarController.TabID) -> Void)?

    private var buttons: [MainTabBarController.TabID: UIButton] = [:]
    private var selected: MainTabBarController.TabID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func glass(cornerRadius: CGFloat) -> UIVisualEffectView {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) { effect = UIGlassEffect() } else { effect = UIBlurEffect(style: .systemChromeMaterial) }
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    private func build() {
        let items: [(MainTabBarController.TabID, String, String)] = [
            (.home, "Home", "house.fill"),
            (.library, "Library", "music.note.list"),
            (.settings, "Settings", "gearshape.fill"),
        ]
        let pill = Self.glass(cornerRadius: Self.width / 2)
        let column = UIStackView()
        column.axis = .vertical
        column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false
        pill.contentView.addSubview(column)
        for (tab, title, symbol) in items {
            let button = makeButton(tab: tab, title: title, symbol: symbol)
            column.addArrangedSubview(button)
        }

        let searchCircle = Self.glass(cornerRadius: Self.width / 2)
        let search = makeButton(tab: .search, title: nil, symbol: "magnifyingglass")
        search.accessibilityLabel = "Search"
        searchCircle.contentView.addSubview(search)

        let stack = UIStackView(arrangedSubviews: [pill, searchCircle])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            pill.widthAnchor.constraint(equalToConstant: Self.width),
            column.topAnchor.constraint(equalTo: pill.contentView.topAnchor, constant: 8),
            column.bottomAnchor.constraint(equalTo: pill.contentView.bottomAnchor, constant: -8),
            column.leadingAnchor.constraint(equalTo: pill.contentView.leadingAnchor, constant: 6),
            column.trailingAnchor.constraint(equalTo: pill.contentView.trailingAnchor, constant: -6),

            searchCircle.widthAnchor.constraint(equalToConstant: Self.width),
            searchCircle.heightAnchor.constraint(equalToConstant: Self.width),
            search.centerXAnchor.constraint(equalTo: searchCircle.contentView.centerXAnchor),
            search.centerYAnchor.constraint(equalTo: searchCircle.contentView.centerYAnchor),
            search.widthAnchor.constraint(equalToConstant: Self.width - 12),
            search.heightAnchor.constraint(equalToConstant: Self.width - 12),
        ])
    }

    private func makeButton(tab: MainTabBarController.TabID, title: String?, symbol: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: title == nil ? 24 : 21,
                                                                                  weight: .semibold)
        config.imagePlacement = .top
        config.imagePadding = 5
        config.cornerStyle = .capsule
        // narrow sides, so "Settings" fits on one line
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2)
        config.titleLineBreakMode = .byClipping
        if let title {
            config.attributedTitle = AttributedString(title, attributes: AttributeContainer(
                [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)]))
        }
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        if title != nil {
            button.heightAnchor.constraint(equalToConstant: 72).isActive = true
        }
        button.accessibilityLabel = title
        button.addAction(UIAction { [weak self] _ in self?.onSelect?(tab) }, for: .touchUpInside)
        buttons[tab] = button
        style(button, selected: false)
        return button
    }

    func setSelected(_ tab: MainTabBarController.TabID) {
        guard tab != selected else { return }
        selected = tab
        for (id, button) in buttons { style(button, selected: id == tab) }
    }

    private func style(_ button: UIButton, selected: Bool) {
        button.configuration?.baseForegroundColor = selected ? ComponentColors.TabBar.activeIcon : .label
        button.configuration?.background.backgroundColor = selected
            ? ComponentColors.TabBar.activeIcon.withAlphaComponent(0.16) : .clear
        button.accessibilityTraits = selected ? [.button, .selected] : .button
    }
}

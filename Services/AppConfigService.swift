//
//  AppConfigService.swift
//  Re-Hearse_v1
//
//  Remote config published from the admin dashboard (Supabase table `app_config`):
//    • maintenance mode on                → a full-screen maintenance screen that can't be closed
//    • below `min_supported_version`      → a full-screen "Update required" screen that can't be closed
//    • below `latest_version`             → a one-time "Update available" alert the person can skip
//    • `theme`                            → the seasonal decorations from Theme Studio (AppThemeManager)
//  Read when the app becomes active, every 2 minutes while it's open, and every 30 seconds while the
//  maintenance screen is up (so people get back in soon after it's turned off). The last good config is
//  cached, so a block still applies offline. Any missing or malformed value means "no block": this never
//  blocks anyone by accident.
//

import UIKit
import Supabase

struct RemoteAppConfig: Codable, Equatable {
    let minSupportedVersion: String
    let latestVersion: String
    let updateRequiredMessage: String
    let updateAvailableMessage: String
    let maintenanceEnabled: Bool
    let maintenanceTitle: String
    let maintenanceMessage: String
    /// ISO 8601 time the admin expects maintenance to end, if they gave one.
    let maintenanceEndsAt: String?
    /// The seasonal theme from Theme Studio ("default" or "christmas"); see `SeasonalTheme`.
    let theme: String
    let version: Int

    enum CodingKeys: String, CodingKey {
        case minSupportedVersion = "min_supported_version"
        case latestVersion = "latest_version"
        case updateRequiredMessage = "update_required_message"
        case updateAvailableMessage = "update_available_message"
        case maintenanceEnabled = "maintenance_enabled"
        case maintenanceTitle = "maintenance_title"
        case maintenanceMessage = "maintenance_message"
        case maintenanceEndsAt = "maintenance_ends_at"
        case theme
        case version
    }

    static let selectColumns = "min_supported_version, latest_version, update_required_message, update_available_message, maintenance_enabled, maintenance_title, maintenance_message, maintenance_ends_at, theme, version"
    static let defaultMaintenanceTitle = "Down for maintenance"
    static let defaultMaintenanceMessage = "Rehearse is getting an update. Please check back soon."

    init(
        minSupportedVersion: String,
        latestVersion: String,
        updateRequiredMessage: String,
        updateAvailableMessage: String,
        maintenanceEnabled: Bool = false,
        maintenanceTitle: String = RemoteAppConfig.defaultMaintenanceTitle,
        maintenanceMessage: String = RemoteAppConfig.defaultMaintenanceMessage,
        maintenanceEndsAt: String? = nil,
        theme: String = SeasonalTheme.default.rawValue,
        version: Int
    ) {
        self.minSupportedVersion = minSupportedVersion
        self.latestVersion = latestVersion
        self.updateRequiredMessage = updateRequiredMessage
        self.updateAvailableMessage = updateAvailableMessage
        self.maintenanceEnabled = maintenanceEnabled
        self.maintenanceTitle = maintenanceTitle
        self.maintenanceMessage = maintenanceMessage
        self.maintenanceEndsAt = maintenanceEndsAt
        self.theme = theme
        self.version = version
    }

    /// Maintenance and theme fields are optional so a config cached before they existed still decodes
    /// (as maintenance off and the default theme).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minSupportedVersion = try c.decode(String.self, forKey: .minSupportedVersion)
        latestVersion = try c.decode(String.self, forKey: .latestVersion)
        updateRequiredMessage = try c.decode(String.self, forKey: .updateRequiredMessage)
        updateAvailableMessage = try c.decode(String.self, forKey: .updateAvailableMessage)
        maintenanceEnabled = try c.decodeIfPresent(Bool.self, forKey: .maintenanceEnabled) ?? false
        maintenanceTitle = try c.decodeIfPresent(String.self, forKey: .maintenanceTitle) ?? Self.defaultMaintenanceTitle
        maintenanceMessage = try c.decodeIfPresent(String.self, forKey: .maintenanceMessage) ?? Self.defaultMaintenanceMessage
        maintenanceEndsAt = try c.decodeIfPresent(String.self, forKey: .maintenanceEndsAt)
        // a wrong type here must not throw away the rest of the config
        theme = (try? c.decodeIfPresent(String.self, forKey: .theme)) ?? SeasonalTheme.default.rawValue
        version = try c.decode(Int.self, forKey: .version)
    }

    /// The expected end time, if it's set and still in the future.
    func expectedMaintenanceEnd(now: Date = Date()) -> Date? {
        guard let raw = maintenanceEndsAt else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = withFraction.date(from: raw) ?? plain.date(from: raw), date > now else { return nil }
        return date
    }
}

/// What the app should do with the published config.
enum AppGate: Equatable {
    case none
    case available(latestVersion: String, message: String)
    case updateRequired(message: String)
    case maintenance(title: String, message: String, endsAt: Date?)
}

enum AppVersion {
    /// The installed marketing version, e.g. "1.1".
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Numeric parts of "1.2.3" padded to three; nil for anything that isn't a plain version.
    static func components(_ version: String) -> [Int]? {
        let parts = version.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.count <= 4, part.allSatisfy(\.isASCII), let n = Int(part), n >= 0 else { return nil }
            numbers.append(n)
        }
        return numbers + Array(repeating: 0, count: 3 - numbers.count)
    }

    /// Orders two versions numerically ("1.10" is after "1.9"); nil if either can't be read.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult? {
        guard let a = components(lhs), let b = components(rhs) else { return nil }
        for (x, y) in zip(a, b) where x != y {
            return x < y ? .orderedAscending : .orderedDescending
        }
        return .orderedSame
    }

    /// Maintenance wins over updates: updating wouldn't help while the service itself is down.
    static func gate(for config: RemoteAppConfig, installed: String, now: Date = Date()) -> AppGate {
        if config.maintenanceEnabled {
            let title = config.maintenanceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = config.maintenanceMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            return .maintenance(
                title: title.isEmpty ? RemoteAppConfig.defaultMaintenanceTitle : title,
                message: message.isEmpty ? RemoteAppConfig.defaultMaintenanceMessage : message,
                endsAt: config.expectedMaintenanceEnd(now: now)
            )
        }
        if AppVersion.compare(installed, config.minSupportedVersion) == .orderedAscending {
            return .updateRequired(message: config.updateRequiredMessage)
        }
        if AppVersion.compare(installed, config.latestVersion) == .orderedAscending {
            return .available(latestVersion: config.latestVersion, message: config.updateAvailableMessage)
        }
        return .none
    }
}

@MainActor
final class AppConfigService {
    static let shared = AppConfigService()

    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6761712673")!

    private let defaults: UserDefaults
    private let cacheKey = "remoteAppConfig.ios"
    private let promptedKey = "remoteAppConfig.promptedLatestVersion"
    private let minimumInterval: TimeInterval = 30
    private let openInterval: TimeInterval = 120
    private let maintenanceInterval: TimeInterval = 30

    private var lastFetch: Date?
    private var isFetching = false
    private var blockingWindow: UIWindow?
    private var pendingPrompt: (latestVersion: String, message: String)?
    private var isShowingPrompt = false
    private var pollTimer: Timer?
    private weak var activeScene: UIWindowScene?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Call when a scene becomes active. Applies the cached config at once, then refreshes it.
    /// `force` skips the 30-second throttle (used by the timer and the "Try again" button).
    /// `background` marks checks the person didn't cause (the timer): those may block the app for
    /// maintenance or a required update, but never pop the skippable "Update available" alert mid-practice.
    func refresh(for scene: UIWindowScene, force: Bool = false, background: Bool = false) {
        activeScene = scene
        if let cached = cachedConfig() {
            apply(cached, in: scene, allowPrompt: !background)
        }
        schedulePolling()
        if !force, let lastFetch, Date().timeIntervalSince(lastFetch) < minimumInterval { return }
        guard !isFetching else { return }
        isFetching = true
        lastFetch = Date()

        Task { [weak self, weak scene] in
            defer { self?.isFetching = false }
            do {
                let config: RemoteAppConfig = try await SupabaseManager.shared.client
                    .from("app_config")
                    .select(RemoteAppConfig.selectColumns)
                    .eq("platform", value: "ios")
                    .single()
                    .execute()
                    .value
                self?.store(config)
                if let scene {
                    self?.apply(config, in: scene, allowPrompt: !background)
                    self?.schedulePolling()
                }
            } catch {
                debugLog("[AppConfig] fetch failed, keeping cached config: \(error)")
            }
        }
    }

    /// Call when the app goes to the background: no checks run while it isn't on screen.
    func pause() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Call once the main tab bar is on screen, so a skippable prompt isn't shown over the splash or onboarding.
    func mainInterfaceDidAppear(in window: UIWindow?) {
        guard let pendingPrompt, let window else { return }
        presentPrompt(latestVersion: pendingPrompt.latestVersion, message: pendingPrompt.message, in: window)
    }

    // MARK: - Polling

    private var isShowingMaintenance: Bool {
        (blockingWindow?.rootViewController as? AppBlockingViewController)?.kind.isMaintenance == true
    }

    private func schedulePolling() {
        let interval = isShowingMaintenance ? maintenanceInterval : openInterval
        if let pollTimer, pollTimer.isValid, pollTimer.timeInterval == interval { return }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let scene = self.activeScene, scene.activationState == .foregroundActive else { return }
                self.refresh(for: scene, force: true, background: true)
            }
        }
    }

    // MARK: - Applying

    private func apply(_ config: RemoteAppConfig, in scene: UIWindowScene, allowPrompt: Bool) {
        AppThemeManager.shared.setSeasonalTheme(SeasonalTheme(remoteValue: config.theme))
        switch AppVersion.gate(for: config, installed: AppVersion.current) {
        case .maintenance(let title, let message, let endsAt):
            pendingPrompt = nil
            showBlockingScreen(.maintenance(title: title, message: message, endsAt: endsAt), in: scene)
        case .updateRequired(let message):
            pendingPrompt = nil
            showBlockingScreen(.updateRequired(message: message), in: scene)
        case .available(let latestVersion, let message):
            hideBlockingScreen()
            guard defaults.string(forKey: promptedKey) != latestVersion else { return }
            pendingPrompt = (latestVersion, message)
            let mainWindow = (scene.delegate as? SceneDelegate)?.window
            if allowPrompt, let mainWindow, mainWindow.rootViewController is MainTabBarController {
                presentPrompt(latestVersion: latestVersion, message: message, in: mainWindow)
            }
        case .none:
            pendingPrompt = nil
            hideBlockingScreen()
        }
    }

    private func showBlockingScreen(_ kind: AppBlockingViewController.Kind, in scene: UIWindowScene) {
        if let existing = blockingWindow?.rootViewController as? AppBlockingViewController {
            if existing.kind != kind { existing.kind = kind }
            return
        }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.overrideUserInterfaceStyle = AppThemeManager.shared.currentTheme.interfaceStyle
        AppThemeManager.shared.applySeasonalTrait(to: [window])
        let controller = AppBlockingViewController(kind: kind)
        controller.onTryAgain = { [weak self, weak scene] in
            guard let self, let scene else { return }
            self.refresh(for: scene, force: true)
        }
        window.rootViewController = controller
        window.makeKeyAndVisible()
        blockingWindow = window
    }

    private func hideBlockingScreen() {
        guard let window = blockingWindow else { return }
        window.isHidden = true
        blockingWindow = nil
        (window.windowScene?.delegate as? SceneDelegate)?.window?.makeKey()
    }

    private func presentPrompt(latestVersion: String, message: String, in window: UIWindow) {
        guard !isShowingPrompt, blockingWindow == nil, var top = window.rootViewController else { return }
        while let presented = top.presentedViewController {
            if presented is UIAlertController { return }
            top = presented
        }
        let alert = UIAlertController(title: "Update available", message: message, preferredStyle: .alert)
        let markSeen = { [weak self] in
            guard let self else { return }
            self.defaults.set(latestVersion, forKey: self.promptedKey)
            self.pendingPrompt = nil
            self.isShowingPrompt = false
        }
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel) { _ in markSeen() })
        alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            markSeen()
            UIApplication.shared.open(Self.appStoreURL)
        })
        alert.preferredAction = alert.actions.last
        isShowingPrompt = true
        top.present(alert, animated: true)
    }

    // MARK: - Cache

    private func cachedConfig() -> RemoteAppConfig? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(RemoteAppConfig.self, from: data)
    }

    private func store(_ config: RemoteAppConfig) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: cacheKey)
        }
    }
}

/// Full-screen screen that can't be closed: either maintenance or "Update required".
final class AppBlockingViewController: UIViewController {
    enum Kind: Equatable {
        case updateRequired(message: String)
        case maintenance(title: String, message: String, endsAt: Date?)

        var isMaintenance: Bool {
            if case .maintenance = self { return true }
            return false
        }
    }

    var kind: Kind {
        didSet { if isViewLoaded { render() } }
    }

    /// Maintenance "Try again" button.
    var onTryAgain: (() -> Void)?

    private let symbol = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let detailLabel = UILabel()
    private lazy var button = UIButton(configuration: .filled(), primaryAction: UIAction { [weak self] _ in
        self?.primaryTapped()
    })

    init(kind: Kind) {
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = BrandColors.backgroundPrimary

        symbol.tintColor = BrandColors.brand
        symbol.contentMode = .scaleAspectFit
        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        symbol.isAccessibilityElement = false

        titleLabel.font = UIFont.preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = BrandColors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = BrandColors.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        detailLabel.font = .preferredFont(forTextStyle: .subheadline).withTraits(.traitBold)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = BrandColors.textPrimary
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [symbol, titleLabel, messageLabel, detailLabel, button])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.setCustomSpacing(28, after: detailLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Scrolls only when the content is taller than the screen (very large text, landscape),
        // so the button can always be reached.
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        view.addSubview(scroll)
        scroll.addSubview(stack)

        let content = scroll.contentLayoutGuide
        let frame = scroll.frameLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),

            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.readableContentGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.readableContentGuide.trailingAnchor, constant: -8),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            stack.widthAnchor.constraint(equalTo: view.readableContentGuide.widthAnchor, constant: -16).withPriority(.defaultHigh),
            symbol.heightAnchor.constraint(equalToConstant: 72),
        ])
        // Content is exactly screen height when everything fits (stack centred); it grows past it,
        // and scrolls, only when the stack needs more room.
        let fitScreen = content.heightAnchor.constraint(equalTo: frame.heightAnchor)
        fitScreen.priority = .defaultLow
        fitScreen.isActive = true
        render()
    }

    private func render() {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = BrandColors.brand
        config.baseForegroundColor = .black
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.preferredFont(forTextStyle: .headline)
            return attrs
        }

        switch kind {
        case .updateRequired(let message):
            symbol.image = UIImage(systemName: "arrow.down.app.fill")
            titleLabel.text = "Update required"
            messageLabel.text = message
            detailLabel.text = nil
            detailLabel.isHidden = true
            config.title = "Update on the App Store"
        case .maintenance(let title, let message, let endsAt):
            symbol.image = UIImage(systemName: "wrench.and.screwdriver.fill")
            titleLabel.text = title
            messageLabel.text = message
            if let endsAt {
                detailLabel.text = "Expected back around \(Self.formatted(endsAt))"
                detailLabel.isHidden = false
            } else {
                detailLabel.text = nil
                detailLabel.isHidden = true
            }
            config.title = "Try again"
        }
        button.configuration = config
        button.isEnabled = true
    }

    private func primaryTapped() {
        switch kind {
        case .updateRequired:
            UIApplication.shared.open(AppConfigService.appStoreURL)
        case .maintenance:
            // Brief disable so repeated taps don't hammer the server; the result swaps or hides this screen.
            button.isEnabled = false
            onTryAgain?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.button.isEnabled = true }
        }
    }

    /// "3:30 PM" today, otherwise "Nov 19, 3:30 PM", in the person's own time zone.
    static func formatted(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate(calendar.isDate(date, inSameDayAs: now) ? "jmm" : "MMMdjmm")
        return formatter.string(from: date)
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

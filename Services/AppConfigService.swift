//
//  AppConfigService.swift
//  Re-Hearse_v1
//
//  Remote config published from the admin dashboard (Supabase table `app_config`).
//  Today it carries force-update settings:
//    • below `min_supported_version`  → a full-screen "Update required" screen that can't be closed
//    • below `latest_version`         → a one-time "Update available" alert the person can skip
//  Read when the app becomes active (at most every 30 seconds). The last good config is cached,
//  so a required update still applies offline. Any missing or malformed value means "no prompt":
//  this never blocks anyone by accident.
//

import UIKit
import Supabase

struct RemoteAppConfig: Codable, Equatable {
    let minSupportedVersion: String
    let latestVersion: String
    let updateRequiredMessage: String
    let updateAvailableMessage: String
    let version: Int

    enum CodingKeys: String, CodingKey {
        case minSupportedVersion = "min_supported_version"
        case latestVersion = "latest_version"
        case updateRequiredMessage = "update_required_message"
        case updateAvailableMessage = "update_available_message"
        case version
    }

    static let selectColumns = "min_supported_version, latest_version, update_required_message, update_available_message, version"
}

enum UpdateRequirement: Equatable {
    case none
    case available(latestVersion: String, message: String)
    case required(message: String)
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

    static func requirement(for config: RemoteAppConfig, installed: String) -> UpdateRequirement {
        if AppVersion.compare(installed, config.minSupportedVersion) == .orderedAscending {
            return .required(message: config.updateRequiredMessage)
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

    private var lastFetch: Date?
    private var isFetching = false
    private var blockingWindow: UIWindow?
    private var pendingPrompt: (latestVersion: String, message: String)?
    private var isShowingPrompt = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Call when a scene becomes active. Applies the cached config at once, then refreshes it.
    func refresh(for scene: UIWindowScene) {
        if let cached = cachedConfig() {
            apply(cached, in: scene)
        }
        if let lastFetch, Date().timeIntervalSince(lastFetch) < minimumInterval { return }
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
                if let scene { self?.apply(config, in: scene) }
            } catch {
                debugLog("[AppConfig] fetch failed, keeping cached config: \(error)")
            }
        }
    }

    /// Call once the main tab bar is on screen, so a skippable prompt isn't shown over the splash or onboarding.
    func mainInterfaceDidAppear(in window: UIWindow?) {
        guard let pendingPrompt, let window else { return }
        presentPrompt(latestVersion: pendingPrompt.latestVersion, message: pendingPrompt.message, in: window)
    }

    // MARK: - Applying

    private func apply(_ config: RemoteAppConfig, in scene: UIWindowScene) {
        switch AppVersion.requirement(for: config, installed: AppVersion.current) {
        case .required(let message):
            pendingPrompt = nil
            showBlockingScreen(message: message, in: scene)
        case .available(let latestVersion, let message):
            hideBlockingScreen()
            guard defaults.string(forKey: promptedKey) != latestVersion else { return }
            pendingPrompt = (latestVersion, message)
            let mainWindow = (scene.delegate as? SceneDelegate)?.window
            if mainWindow?.rootViewController is MainTabBarController {
                presentPrompt(latestVersion: latestVersion, message: message, in: mainWindow!)
            }
        case .none:
            pendingPrompt = nil
            hideBlockingScreen()
        }
    }

    private func showBlockingScreen(message: String, in scene: UIWindowScene) {
        if let existing = blockingWindow?.rootViewController as? UpdateRequiredViewController {
            existing.message = message
            return
        }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.overrideUserInterfaceStyle = AppThemeManager.shared.currentTheme.interfaceStyle
        window.rootViewController = UpdateRequiredViewController(message: message)
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

/// Full-screen, non-dismissable screen shown while the installed version is below the minimum.
final class UpdateRequiredViewController: UIViewController {
    var message: String {
        didSet { messageLabel.text = message }
    }

    private let messageLabel = UILabel()

    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = BrandColors.backgroundPrimary
        let accent = BrandColors.brand

        let symbol = UIImageView(image: UIImage(systemName: "arrow.down.app.fill"))
        symbol.tintColor = accent
        symbol.contentMode = .scaleAspectFit
        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)
        symbol.isAccessibilityElement = false

        let title = UILabel()
        title.text = "Update required"
        title.font = UIFont.preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = BrandColors.textPrimary
        title.textAlignment = .center
        title.numberOfLines = 0
        title.accessibilityTraits = .header

        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = BrandColors.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        config.title = "Update on the App Store"
        config.baseBackgroundColor = accent
        config.baseForegroundColor = .black
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.preferredFont(forTextStyle: .headline)
            return attrs
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in
            UIApplication.shared.open(AppConfigService.appStoreURL)
        })

        let stack = UIStackView(arrangedSubviews: [symbol, title, messageLabel, button])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.setCustomSpacing(28, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.readableContentGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.readableContentGuide.trailingAnchor, constant: -8),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            stack.widthAnchor.constraint(equalTo: view.readableContentGuide.widthAnchor, constant: -16).withPriority(.defaultHigh),
            symbol.heightAnchor.constraint(equalToConstant: 72),
        ])
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

import UIKit

enum AppTheme: Int {
    case dark = 0
    case light = 1
    case system = 2

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        case .system:
            return .unspecified
        }
    }

    var isDarkModeEnabled: Bool {
        self == .dark
    }

    var displayName: String {
        switch self {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        case .system:
            return "System Default"
        }
    }
}

/// The seasonal look published from the admin dashboard's Theme Studio (`app_config.theme`).
/// A seasonal theme only adds decorations: the app's colours and layout never change.
enum SeasonalTheme: String, Codable {
    case `default`
    case christmas

    /// Anything missing or unknown (a theme added after this build) means `.default`.
    init(remoteValue: String?) {
        let value = remoteValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        self = SeasonalTheme(rawValue: value) ?? .default
    }
}

/// The seasonal theme as a trait, set on every window: colours that change with the theme (the
/// Christmas background) read it, and UIKit redraws them by itself when it changes.
struct SeasonalThemeTrait: UITraitDefinition {
    static let defaultValue = SeasonalTheme.default
    static let affectsColorAppearance = true
}

extension UITraitCollection {
    var seasonalTheme: SeasonalTheme { self[SeasonalThemeTrait.self] }
}

final class AppThemeManager {
    static let shared = AppThemeManager()

    static let themeDidChangeNotification = Notification.Name("AppThemeDidChange")
    /// Posted on the main queue when the seasonal theme changes.
    static let seasonalThemeDidChangeNotification = Notification.Name("AppSeasonalThemeDidChange")

    private let storageKey = "appThemePreference"
    private let seasonalStorageKey = "seasonalTheme"
    private(set) var currentTheme: AppTheme
    private var storedSeasonalTheme: SeasonalTheme
    #if DEBUG
    /// For checking a theme on a simulator without publishing it: launch with
    /// `-seasonalThemeOverride christmas` (or `default`).
    private let seasonalOverride = UserDefaults.standard.string(forKey: "seasonalThemeOverride").map(SeasonalTheme.init(remoteValue:))
    #endif

    /// The seasonal theme to show now (the last one published, kept across launches).
    var seasonalTheme: SeasonalTheme {
        #if DEBUG
        if let seasonalOverride { return seasonalOverride }
        #endif
        return storedSeasonalTheme
    }

    private init() {
        let defaults = UserDefaults.standard
        if let storedRawValue = defaults.object(forKey: storageKey) as? Int,
           let storedTheme = AppTheme(rawValue: storedRawValue) {
            currentTheme = storedTheme
        } else {
            currentTheme = .dark
            defaults.set(AppTheme.dark.rawValue, forKey: storageKey)
        }
        storedSeasonalTheme = SeasonalTheme(remoteValue: defaults.string(forKey: seasonalStorageKey))
    }

    /// Called with each config the app reads (and its cached copy at launch).
    func setSeasonalTheme(_ theme: SeasonalTheme) {
        guard theme != storedSeasonalTheme else { return }
        let before = seasonalTheme
        storedSeasonalTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: seasonalStorageKey)
        guard seasonalTheme != before else { return }
        let post = {
            self.applySeasonalTrait(to: self.connectedWindows())
            NotificationCenter.default.post(name: Self.seasonalThemeDidChangeNotification, object: nil)
        }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
    }

    /// Puts the seasonal theme on `windows` as a trait (see `SeasonalThemeTrait`).
    func applySeasonalTrait(to windows: [UIWindow]) {
        let theme = seasonalTheme
        // (reading an override that was never set raises, so it's always written)
        for window in windows { window.traitOverrides[SeasonalThemeTrait.self] = theme }
    }

    var isDarkModeEnabled: Bool {
        currentTheme.isDarkModeEnabled
    }

    func applyCurrentTheme(to window: UIWindow? = nil) {
        apply(theme: currentTheme, to: window)
    }

    func setTheme(_ theme: AppTheme, window: UIWindow? = nil) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: storageKey)
        apply(theme: theme, to: window)
        NotificationCenter.default.post(name: Self.themeDidChangeNotification, object: nil)
    }

    private func apply(theme: AppTheme, to window: UIWindow?) {
        let windows = window.map { [$0] } ?? connectedWindows()
        windows.forEach { $0.overrideUserInterfaceStyle = theme.interfaceStyle }
        applySeasonalTrait(to: windows)
    }

    private func connectedWindows() -> [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
    }
}

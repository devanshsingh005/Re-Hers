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

final class AppThemeManager {
    static let shared = AppThemeManager()

    static let themeDidChangeNotification = Notification.Name("AppThemeDidChange")

    private let storageKey = "appThemePreference"
    private(set) var currentTheme: AppTheme

    private init() {
        let defaults = UserDefaults.standard
        if let storedRawValue = defaults.object(forKey: storageKey) as? Int,
           let storedTheme = AppTheme(rawValue: storedRawValue) {
            currentTheme = storedTheme
        } else {
            currentTheme = .dark
            defaults.set(AppTheme.dark.rawValue, forKey: storageKey)
        }
    }

    var isDarkModeEnabled: Bool {
        currentTheme.isDarkModeEnabled
    }

    func applyCurrentTheme(to window: UIWindow? = nil) {
        apply(theme: currentTheme, to: window)
    }

    func setDarkModeEnabled(_ isEnabled: Bool, window: UIWindow? = nil) {
        setTheme(isEnabled ? .dark : .light, window: window)
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
    }

    private func connectedWindows() -> [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
    }
}

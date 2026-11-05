import UIKit
import Network
import Supabase
import Auth

@inline(__always)
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    Swift.print(message, terminator: terminator)
    #endif
}

public final class NavigationBarHelper {
    public static let profileDidUpdateNotification = Notification.Name("NavigationBarProfileDidUpdate")
    
    // Minimal profile model
    private struct NavbarProfile: Decodable {
        let full_name: String?
        let avatar_url: String?
    }
    
    /// Creates the right-side bar button items (Profile, Chord, Day Badge) wrapped in a pill/capsule matching the design
    public static func createRightBarButtonItems(
        target: Any?,
        profileAction: Selector? = nil,
        chordAction: Selector? = nil,
        dayBadgeAction: Selector? = nil
    ) -> [UIBarButtonItem] {
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Day Badge
        if let target = target, let action = dayBadgeAction {
            let dayBadge = UIButton(type: .system)
            dayBadge.setTitle("🔥 Day 1", for: .normal)
            dayBadge.setTitleColor(.black, for: .normal)
            dayBadge.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
            dayBadge.layer.cornerRadius = 14
            dayBadge.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            dayBadge.titleLabel?.font = .boldSystemFont(ofSize: 14)
            dayBadge.addTarget(target, action: action, for: .touchUpInside)
            stackView.addArrangedSubview(dayBadge)
        }
        
        // Chord Button
        if let target = target, let action = chordAction {
            let chordButton = UIButton(type: .system)
            chordButton.setImage(UIImage(systemName: "opticaldisc"), for: .normal)
            chordButton.tintColor = .label
            chordButton.imageView?.contentMode = .scaleAspectFit
            chordButton.addTarget(target, action: action, for: .touchUpInside)
            chordButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
            chordButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
            stackView.addArrangedSubview(chordButton)
        }
        
        // Profile Image
        let profileImg = UIImageView(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
        profileImg.layer.cornerRadius = 18
        profileImg.clipsToBounds = true
        profileImg.contentMode = .scaleAspectFill
        profileImg.image = UIImage(systemName: "person.crop.circle")
        profileImg.tintColor = .gray
        
        let profileContainer = UIView()
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.widthAnchor.constraint(equalToConstant: 36).isActive = true
        profileContainer.heightAnchor.constraint(equalToConstant: 36).isActive = true
        profileContainer.addSubview(profileImg)
        profileImg.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            profileImg.centerXAnchor.constraint(equalTo: profileContainer.centerXAnchor),
            profileImg.centerYAnchor.constraint(equalTo: profileContainer.centerYAnchor),
            profileImg.widthAnchor.constraint(equalToConstant: 36),
            profileImg.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        if let target = target, let action = profileAction {
            let tap = UITapGestureRecognizer(target: target, action: action)
            profileContainer.addGestureRecognizer(tap)
            profileContainer.isUserInteractionEnabled = true
        }
        stackView.addArrangedSubview(profileContainer)
        
        // Load the profile asynchronously
        loadProfileImage(into: profileImg)
        
        if chordAction == nil && dayBadgeAction == nil {
            return [UIBarButtonItem(customView: profileContainer)]
        }
        
        // Main Pill Container
        let pillContainer = UIView()
        pillContainer.backgroundColor = .systemBackground
        pillContainer.layer.cornerRadius = 24 // Approx height 48 / 2
        pillContainer.layer.shadowColor = UIColor.black.cgColor
        pillContainer.layer.shadowOpacity = 0.05
        pillContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        pillContainer.layer.shadowRadius = 4
        
        // Add a subtle border for contrast in light/dark mode if needed
        pillContainer.layer.borderWidth = 0.5
        pillContainer.layer.borderColor = UIColor.systemGray5.cgColor
        
        pillContainer.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: pillContainer.leadingAnchor, constant: 6),
            stackView.trailingAnchor.constraint(equalTo: pillContainer.trailingAnchor, constant: -6),
            stackView.topAnchor.constraint(equalTo: pillContainer.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: pillContainer.bottomAnchor, constant: -6),
            // Set a minimum height to make the capsule round
            pillContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
        
        // Returns the single capsule item
        return [UIBarButtonItem(customView: pillContainer)]
    }
    
    public static func createCustomBackButton(target: Any?, action: Selector) -> UIBarButtonItem {
        let btn = makeCircularBackButton()
        if let target = target {
            btn.addTarget(target, action: action, for: .touchUpInside)
        }
        
        // Wrapping in a stack view prevents the system from adding "halo" layers
        // or resizing the button unpredictably in iOS 16+.
        let stack = UIStackView(arrangedSubviews: [btn])
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        
        return UIBarButtonItem(customView: stack)
    }

    public static func createNativeBackButton(target: Any?, action: Selector) -> UIBarButtonItem {
        let image = UIImage(systemName: "chevron.backward")
        return UIBarButtonItem(image: image, style: .plain, target: target, action: action)
    }

    public static func createNativeRightBarButtonItems(
        target: Any?,
        profileAction: Selector? = nil,
        chordAction: Selector? = nil
    ) -> [UIBarButtonItem] {
        var items: [UIBarButtonItem] = []

        if let chordAction {
            let chordItem = UIBarButtonItem(
                image: UIImage(systemName: "opticaldisc"),
                style: .plain,
                target: target,
                action: chordAction
            )
            items.append(chordItem)
        }

        if let profileAction {
            let profileItem = UIBarButtonItem(
                image: UIImage(systemName: "person.crop.circle"),
                style: .plain,
                target: target,
                action: profileAction
            )
            items.append(profileItem)
        }

        return items
    }

    /// A specialized button that maintains its circular shape and premium styling.
    private class PremiumBackButton: UIButton {
        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }
        
        private func setup() {
            let chevronCfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
            setImage(UIImage(systemName: "chevron.backward", withConfiguration: chevronCfg), for: .normal)
            tintColor = .label
            contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 10)
            
            // Remove Shadow (Reset to default)
            layer.shadowColor = UIColor.clear.cgColor
            layer.shadowOpacity = 0
            layer.shadowRadius = 0
            layer.shadowOffset = .zero
        }
        
        override var intrinsicContentSize: CGSize {
            return CGSize(width: 44, height: 44)
        }
    }

    public static func makeCircularBackButton() -> UIButton {
        let btn = PremiumBackButton(type: .custom)
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 44),
            btn.heightAnchor.constraint(equalToConstant: 44)
        ])
        return btn
    }

    /// Performs a gentle, calming "shrink and grow" animation on a button with haptic feedback.
    public static func animateButtonPress(_ button: UIView, completion: (() -> Void)? = nil) {
        // Match UploadScreen's snappy feel (0.96 scale)
        UIView.animate(withDuration: 0.10, delay: 0, options: .curveEaseOut, animations: {
            button.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
                button.transform = .identity
            }) { _ in
                completion?()
            }
        }
    }

    public static func applyNativeNavigationBarAppearance(to navigationController: UINavigationController?) {
        guard let navigationBar = navigationController?.navigationBar else { return }

        let collapsedAppearance = UINavigationBarAppearance()
        collapsedAppearance.configureWithTransparentBackground()
        collapsedAppearance.backgroundEffect = nil
        collapsedAppearance.backgroundColor = .clear
        collapsedAppearance.shadowColor = .clear
        collapsedAppearance.titleTextAttributes = [
            .foregroundColor: ComponentColors.NavBar.title,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]

        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithTransparentBackground()
        scrollEdgeAppearance.backgroundEffect = nil
        scrollEdgeAppearance.backgroundColor = .clear
        scrollEdgeAppearance.shadowColor = .clear
        scrollEdgeAppearance.titleTextAttributes = collapsedAppearance.titleTextAttributes

        navigationBar.standardAppearance = collapsedAppearance
        navigationBar.compactAppearance = collapsedAppearance
        navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        navigationBar.tintColor = ComponentColors.NavBar.title
        navigationBar.isTranslucent = true
    }

    public static func configureInlineNavigationBar(
        for viewController: UIViewController,
        title: String,
        subtitle: String,
        backAction: Selector? = nil
    ) -> UILabel {
        viewController.navigationItem.title = ""
        viewController.navigationController?.navigationBar.prefersLargeTitles = false
        viewController.navigationItem.largeTitleDisplayMode = .never

        let (headerStack, subtitleLabel) = createInlineTitleView(title: title, subtitle: subtitle)
        headerStack.alpha = 0
        viewController.navigationItem.titleView = headerStack

        if let backAction {
            viewController.navigationItem.leftBarButtonItem = createNativeBackButton(
                target: viewController,
                action: backAction
            )
        } else {
            viewController.navigationItem.leftBarButtonItem = nil
        }

        applyNativeNavigationBarAppearance(to: viewController.navigationController)
        return subtitleLabel
    }

    public static func updateNavigationBackgroundAppearance(
        _ navBackgroundView: UIVisualEffectView,
        shadowView: UIView,
        traitCollection: UITraitCollection
    ) {
        navBackgroundView.effect = nil
        navBackgroundView.backgroundColor = ComponentColors.NavBar.background.withAlphaComponent(
            traitCollection.userInterfaceStyle == .dark ? 0.18 : 0.22
        )
        navBackgroundView.layer.borderColor = UIColor.clear.cgColor
        navBackgroundView.layer.borderWidth = 0
        shadowView.backgroundColor = ComponentColors.NavBar.separator.withAlphaComponent(0.08)
    }

    public static func installNavigationBackground(
        _ navBackgroundView: UIVisualEffectView,
        shadowView: UIView,
        in containerView: UIView
    ) {
        navBackgroundView.alpha = 0
        navBackgroundView.isUserInteractionEnabled = false
        navBackgroundView.contentView.isUserInteractionEnabled = false
        navBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.translatesAutoresizingMaskIntoConstraints = false

        if navBackgroundView.superview == nil {
            containerView.addSubview(navBackgroundView)
        }
        if shadowView.superview == nil {
            navBackgroundView.contentView.addSubview(shadowView)
        }

        let window = containerView.window
            ?? (containerView.window?.windowScene?.windows.first { $0.isKeyWindow })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        let topPadding = window?.safeAreaInsets.top ?? 0
        let navHeight: CGFloat = 44 + topPadding

        NSLayoutConstraint.activate([
            navBackgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
            navBackgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            navBackgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            navBackgroundView.heightAnchor.constraint(equalToConstant: navHeight),

            shadowView.leadingAnchor.constraint(equalTo: navBackgroundView.leadingAnchor),
            shadowView.trailingAnchor.constraint(equalTo: navBackgroundView.trailingAnchor),
            shadowView.bottomAnchor.constraint(equalTo: navBackgroundView.bottomAnchor),
            shadowView.heightAnchor.constraint(equalToConstant: 0.33)
        ])
    }

    public static func syncNavigationBarAlpha(
        scrollView: UIScrollView,
        navigationItem: UINavigationItem,
        navBackgroundView: UIVisualEffectView
    ) {
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let alpha = calculateNavBarAlpha(offset: offset)
        navigationItem.titleView?.alpha = alpha
        navigationItem.titleView?.isHidden = (alpha == 0)
        navBackgroundView.alpha = alpha * 0.45
    }
    
    public static func loadProfileImage(into target: UIView) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            
            do {
                let profile: NavbarProfile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .single()
                    .execute()
                    .value
                
                if let urlString = profile.avatar_url, !urlString.isEmpty {
                    if let imageView = target as? UIImageView {
                        await fetchImage(from: urlString, into: imageView)
                    } else if let button = target as? UIButton {
                        await fetchImage(from: urlString, intoButton: button)
                    }
                }
            } catch {
                // Ignore error, keep default image
            }
        }
    }
    
    private static func loadProfileImage(into imageView: UIImageView) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            
            do {
                let profile: NavbarProfile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .single()
                    .execute()
                    .value
                
                if let urlString = profile.avatar_url, !urlString.isEmpty {
                    await fetchImage(from: urlString, into: imageView)
                }
            } catch {
                // Ignore error, keep default image
            }
        }
    }
    
    private static func fetchImage(from urlString: String, intoButton button: UIButton) async {
        if urlString.starts(with: "icon_") {
            await MainActor.run {
                if let img = UIImage(named: urlString) {
                    button.setImage(img, for: .normal)
                    button.tintColor = .clear
                }
            }
            return
        }
        
        guard let signedURLString = await signedProfileURLString(from: urlString),
              let url = URL(string: signedURLString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            if let img = UIImage(data: data) {
                await MainActor.run {
                    button.setImage(img, for: .normal)
                    button.tintColor = .clear
                }
            }
        } catch {}
    }
    
    private static func fetchImage(from urlString: String, into imageView: UIImageView) async {
        if urlString.starts(with: "icon_") {
            await MainActor.run {
                if let img = UIImage(named: urlString) {
                    imageView.image = img
                    imageView.tintColor = .clear
                }
            }
            return
        }
        
        guard let signedURLString = await signedProfileURLString(from: urlString),
              let url = URL(string: signedURLString) else { return }
        
        do {
            let request = URLRequest(url: url, timeoutInterval: 30)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let img = UIImage(data: data) {
                await MainActor.run {
                    imageView.image = img
                    imageView.tintColor = .clear
                }
            }
        } catch {}
    }
    
    static func signedProfileURLString(from storedValue: String) async -> String? {
        let marker = "/object/useprofile/"
        let profilePath: String

        if let range = storedValue.range(of: marker) {
            profilePath = String(storedValue[range.upperBound...])
        } else if URL(string: storedValue)?.scheme != nil {
            return storedValue
        } else {
            profilePath = storedValue
        }

        guard !profilePath.isEmpty else { return nil }
        return try? await SupabaseManager.shared.client.storage
            .from("useprofile")
            .createSignedURL(path: profilePath, expiresIn: 3600)
            .absoluteString
    }

    // MARK: - Global TopNavBar Helpers
    
    /// Creates the standard inline title stack with a main title and subtitle for root tabs.
    public static func createInlineTitleView(title: String, subtitle: String) -> (UIStackView, UILabel) {
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.alignment = .center
        headerStack.spacing = -2
        
        let mainTitle = UILabel()
        mainTitle.text = title
        mainTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        mainTitle.textColor = ComponentColors.NavBar.title
        
        let subTitleLbl = UILabel()
        subTitleLbl.text = subtitle
        subTitleLbl.font = .systemFont(ofSize: 11, weight: .regular)
        subTitleLbl.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.7)
        
        headerStack.addArrangedSubview(mainTitle)
        headerStack.addArrangedSubview(subTitleLbl)
        
        return (headerStack, subTitleLbl)
    }
    
    /// Returns the alpha percentage (0.0 to 1.0) for the navigation bar background and inline title based on scroll offset.
    public static func calculateNavBarAlpha(offset: CGFloat) -> CGFloat {
        let fadeStart: CGFloat = 0
        let fadeEnd:   CGFloat = 30
        
        if offset <= fadeStart { return 0.0 }
        if offset >= fadeEnd { return 1.0 }
        return (offset - fadeStart) / (fadeEnd - fadeStart)
    }
}

final class AppConnectivityMonitor {
    static let shared = AppConnectivityMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.rehearse.connectivity.monitor")
    private let lock = NSLock()
    private var latestStatus: NWPath.Status?

    var isOnline: Bool {
        lock.lock()
        defer { lock.unlock() }

        // Default to online until the first path update arrives so we don't
        // block valid requests during app startup.
        guard let latestStatus else { return true }
        return latestStatus == .satisfied
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.lock.lock()
            self?.latestStatus = path.status
            self?.lock.unlock()
        }
        monitor.start(queue: queue)
    }
}

enum AppUserFacingError {
    static func isOffline(_ error: Error?) -> Bool {
        if !AppConnectivityMonitor.shared.isOnline {
            return true
        }

        guard let error else { return false }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            switch code {
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                return true
            default:
                break
            }
        }

        let lowercasedDescription = error.localizedDescription.lowercased()
        return lowercasedDescription.contains("offline")
            || lowercasedDescription.contains("internet connection appears to be offline")
            || lowercasedDescription.contains("not connected to the internet")
    }

    static func isNetworkIssue(_ error: Error?) -> Bool {
        if isOffline(error) {
            return true
        }

        guard let error else { return false }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        let lowercasedDescription = error.localizedDescription.lowercased()
        return lowercasedDescription.contains("network")
            || lowercasedDescription.contains("connection")
            || lowercasedDescription.contains("timed out")
            || lowercasedDescription.contains("timeout")
            || lowercasedDescription.contains("host")
            || lowercasedDescription.contains("dns")
    }

    static func title(for error: Error?) -> String {
        if isOffline(error) {
            return "No Internet Connection"
        }

        if isNetworkIssue(error) {
            return "Connection Issue"
        }

        return "Something Went Wrong"
    }

    static func message(
        for action: String,
        error: Error?,
        fallback: String
    ) -> String {
        if isOffline(error) {
            return "Your internet connection appears to be offline. Please reconnect and try again."
        }

        if isNetworkIssue(error) {
            return "We couldn't \(action) because the connection was interrupted. Please try again."
        }

        return fallback
    }
}

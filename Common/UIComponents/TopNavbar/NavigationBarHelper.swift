import UIKit
import Supabase

public final class NavigationBarHelper {
    
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
            var config = UIButton.Configuration.filled()
            config.title = "🔥 Day 1"
            config.baseForegroundColor = .black
            config.baseBackgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            let dayBadge = UIButton(configuration: config)
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
    
    /// Creates a circular white back button with a chevron, matching the global back button style for use in UINavigationBar.
    public static func createCustomBackButton(target: Any?, action: Selector) -> UIBarButtonItem {
        // Wrapper view to prevent UINavigationBar from clipping the button's bounds/shadow
        // and to fix Auto Layout conflicts inside the native navigation bar item.
        let wrapper = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.widthAnchor.constraint(equalToConstant: 44).isActive = true
        wrapper.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        let btn = UIButton(type: .system)
        btn.frame = wrapper.bounds
        btn.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        btn.tintColor          = .label
        btn.backgroundColor    = .systemBackground
        btn.layer.cornerRadius = 22
        btn.layer.shadowColor  = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.10
        btn.layer.shadowRadius  = 6
        btn.layer.shadowOffset  = CGSize(width: 0, height: 2)
        
        if let target = target {
            btn.addTarget(target, action: action, for: .touchUpInside)
        }
        
        wrapper.addSubview(btn)
        return UIBarButtonItem(customView: wrapper)
    }

    /// Returns a standalone circular frosted glass back UIButton imitating iOS 18 appearance.
    public static func makeCircularBackButton() -> UIButton {
        var config = UIButton.Configuration.plain()
        
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        config.image = UIImage(systemName: "chevron.backward", withConfiguration: cfg)
        config.baseForegroundColor = .label
        
        // Use a UIVisualEffectView as the button's background natively
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.layer.cornerRadius = 22
        blur.clipsToBounds = true
        blur.layer.borderWidth = 0.5
        blur.layer.borderColor = UIColor.separator.cgColor
        
        config.background.customView = blur
        config.background.cornerRadius = 22
        
        let btn = UIButton(configuration: config)
        
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.05
        btn.layer.shadowRadius = 4
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 44),
            btn.heightAnchor.constraint(equalToConstant: 44)
        ])
        return btn
    }
    
    public static func fetchWelcomeName(completion: @escaping (String) -> Void) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run { completion("User") }
                return
            }
            do {
                let profile: NavbarProfile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    if let fullName = profile.full_name, !fullName.isEmpty {
                        completion(fullName)
                    } else {
                        completion("User")
                    }
                }
            } catch {
                await MainActor.run { completion("User") }
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
        
        var finalURLString = urlString
        if urlString.contains("supabase.co/storage/v1/object/useprofile/") && !urlString.contains("/public/") {
            finalURLString = urlString.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
        }
        
        guard let url = URL(string: finalURLString) else { return }
        
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

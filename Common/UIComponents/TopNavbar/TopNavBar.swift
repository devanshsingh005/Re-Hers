import UIKit
import Supabase

// Minimal profile model for the navbar
private struct NavbarProfile: Decodable {
    let full_name: String?
    let avatar_url: String?
}

public final class TopNavBar: UIView {

    // MARK: - Public Toggles
    public var isBackButtonVisible: Bool = false { didSet { backButton.isHidden = !isBackButtonVisible } }
    public var isStreakVisible: Bool = true { didSet { dayBadge.isHidden = !isStreakVisible } }
    public var isChordIconVisible: Bool = false { didSet { chordButton.isHidden = !isChordIconVisible } }
    public var isProfileVisible: Bool = true { didSet { profileImg.isHidden = !isProfileVisible } }
    public var isWelcomeTextHidden: Bool = false { didSet { welcomeLabel.isHidden = isWelcomeTextHidden } }

    // MARK: - Actions
    public var backAction: (() -> Void)?
    public var dayBadgeAction: (() -> Void)?
    public var chordAction: (() -> Void)?
    public var profileAction: (() -> Void)?

    // MARK: - UI Components

    private let backButton: UIButton = {
        let btn = UIButton(type: .system)
        let icon = UIImage(systemName: "chevron.left")?.withRenderingMode(.alwaysTemplate)
        btn.setImage(icon, for: .normal)
        btn.tintColor = .label
        btn.isHidden = true
        btn.contentHorizontalAlignment = .leading
        return btn
    }()

    private let appLabel: UILabel = {
        let label = UILabel()
        label.text = "Re-Hearse"

        let baseFont = UIFont.preferredFont(forTextStyle: .title1)
        label.font = UIFont.systemFont(
            ofSize: baseFont.pointSize,
            weight: .medium
        )

        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        return label
    }()



    private let dayBadge: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("🔥 Day 1", for: .normal)
        btn.setTitleColor(.black, for: .normal)
        btn.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
        btn.layer.cornerRadius = 16
        btn.titleLabel?.font = .boldSystemFont(ofSize: 14)
        btn.contentEdgeInsets = .init(top: 6, left: 10, bottom: 6, right: 10)
        return btn
    }()

    private let chordButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "opticaldisc"), for: .normal)
        btn.tintColor = .label

        btn.contentHorizontalAlignment = .fill
        btn.contentVerticalAlignment = .fill
        btn.contentEdgeInsets = .zero
        btn.imageView?.contentMode = .scaleAspectFit

        return btn
    }()

    private let profileImg: UIImageView = {
        let iv = UIImageView()
        iv.layer.cornerRadius = 18
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(systemName: "person.crop.circle")
        iv.tintColor = .gray
        return iv
    }()

    private let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome back..."
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let topRowStack = UIStackView()
    private let rightStack = UIStackView()
    private let mainStack = UIStackView()

    // MARK: - Public Refresh Mechanism
    public static let profileDidUpdateNotification = Notification.Name("TopNavBarProfileDidUpdate")
    private var observer: NSObjectProtocol?

    // MARK: - Init
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        loadUserProfile()
        setupNotificationObserver()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
        loadUserProfile()
        setupNotificationObserver()
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Setup
    private func configureUI() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        setupStacks()
        buildHierarchy()
        applyConstraints()

        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        dayBadge.addTarget(self, action: #selector(handleDayBadge), for: .touchUpInside)
        chordButton.addTarget(self, action: #selector(handleChord), for: .touchUpInside)

        profileImg.isUserInteractionEnabled = true
        profileImg.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleProfile))
        )
    }

    private func setupStacks() {
        topRowStack.axis = .horizontal
        topRowStack.alignment = .center
        topRowStack.spacing = 8

        rightStack.axis = .horizontal
        rightStack.alignment = .center
        rightStack.spacing = 10

        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.spacing = 6
    }

    private func buildHierarchy() {
        // Right row: badge + chord icon + profile
        rightStack.addArrangedSubview(dayBadge)
        rightStack.addArrangedSubview(chordButton)
        rightStack.addArrangedSubview(profileImg)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Back button + title + spacer + right section
        topRowStack.addArrangedSubview(backButton)
        topRowStack.addArrangedSubview(appLabel)
        topRowStack.addArrangedSubview(spacer)
        topRowStack.addArrangedSubview(rightStack)

        mainStack.addArrangedSubview(topRowStack)
        mainStack.addArrangedSubview(welcomeLabel)

        addSubview(mainStack)
    }

    private func applyConstraints() {
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        profileImg.translatesAutoresizingMaskIntoConstraints = false
        chordButton.translatesAutoresizingMaskIntoConstraints = false

        chordButton.imageView?.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            profileImg.widthAnchor.constraint(equalToConstant: 36),
            profileImg.heightAnchor.constraint(equalToConstant: 36),

            chordButton.widthAnchor.constraint(equalToConstant: 32),
            chordButton.heightAnchor.constraint(equalToConstant: 32),
        ])

        chordButton.setContentHuggingPriority(.required, for: .horizontal)
        chordButton.setContentHuggingPriority(.required, for: .vertical)
        chordButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        chordButton.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    // MARK: - Notification Observer
    private func setupNotificationObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: TopNavBar.profileDidUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 NavBar received profile update notification - refreshing...")
            self?.loadUserProfile()
        }
    }

    // MARK: - Actions
    @objc private func handleBack()     { backAction?() }
    @objc private func handleDayBadge() { dayBadgeAction?() }
    @objc private func handleChord()    { chordAction?() }
    @objc private func handleProfile()  { profileAction?() }

    // MARK: - Public API
    public func setTitle(_ text: String) {
        appLabel.text = text
    }

    public static func make(title: String) -> TopNavBar {
        let bar = TopNavBar()
        bar.setTitle(title)
        return bar
    }

    // MARK: - Refresh Profile (Public Method)
    public func refreshProfile() {
        print("🔄 Manually refreshing navbar profile...")
        loadUserProfile()
    }

    // MARK: - Load Name + Avatar from Supabase
    public func loadUserProfile() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    self.welcomeLabel.text = "Welcome back..."
                    self.profileImg.image = UIImage(systemName: "person.crop.circle")
                    self.profileImg.tintColor = .gray
                    self.profileImg.contentMode = .scaleAspectFit
                }
                return
            }

            do {
                // This infers NavbarProfile as the generic return type
                let profile: NavbarProfile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .single()
                    .execute()
                    .value

                await MainActor.run {
                    if let fullName = profile.full_name, !fullName.isEmpty {
                        self.welcomeLabel.text = "Welcome back, \(fullName)"
                    } else {
                        self.welcomeLabel.text = "Welcome back, User"
                    }
                    
                    print("✅ NavBar loaded profile name: \(profile.full_name ?? "nil")")
                }

                if let urlString = profile.avatar_url, !urlString.isEmpty {
                    await loadProfileImage(from: urlString)
                } else {
                    await MainActor.run {
                        self.profileImg.image = UIImage(systemName: "person.crop.circle")
                        self.profileImg.tintColor = .gray
                        self.profileImg.contentMode = .scaleAspectFit
                        print("✅ NavBar: No avatar URL, using default")
                    }
                }
            } catch {
                print("❌ Failed to load navbar profile:", error)
                await MainActor.run {
                    self.welcomeLabel.text = "Welcome back..."
                    self.profileImg.image = UIImage(systemName: "person.crop.circle")
                    self.profileImg.tintColor = .gray
                    self.profileImg.contentMode = .scaleAspectFit
                }
            }
        }
    }

    // MARK: - Load Profile Image
    private func loadProfileImage(from urlString: String) async {
        var finalURLString = urlString
        
        // Fix the URL if it's missing /public/
        if urlString.contains("supabase.co/storage/v1/object/useprofile/") && !urlString.contains("/public/") {
            // Replace /object/useprofile/ with /object/public/useprofile/
            finalURLString = urlString.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
        }
        
        guard let url = URL(string: finalURLString) else {
            print("❌ Invalid URL for navbar profile: \(finalURLString)")
            await MainActor.run {
                self.profileImg.image = UIImage(systemName: "person.crop.circle")
                self.profileImg.tintColor = .gray
                self.profileImg.contentMode = .scaleAspectFit
            }
            return
        }

        do {
            print("🔄 NavBar loading image from: \(url)")
            let request = URLRequest(url: url, timeoutInterval: 30)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let img = UIImage(data: data) {
                await MainActor.run {
                    self.profileImg.image = img
                    self.profileImg.contentMode = .scaleAspectFill
                    self.profileImg.tintColor = .clear
                    print("✅ NavBar image loaded successfully")
                }
            } else {
                await MainActor.run {
                    self.profileImg.image = UIImage(systemName: "person.crop.circle")
                    self.profileImg.tintColor = .gray
                    self.profileImg.contentMode = .scaleAspectFit
                    print("❌ NavBar: Could not create image from data")
                }
            }
        } catch {
            print("❌ Failed to load profile image:", error)
            await MainActor.run {
                self.profileImg.image = UIImage(systemName: "person.crop.circle")
                self.profileImg.tintColor = .gray
                self.profileImg.contentMode = .scaleAspectFit
            }
        }
    }
}

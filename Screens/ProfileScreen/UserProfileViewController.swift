import UIKit

class ProfileScreen: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.isHidden = true

        setupScroll()
        buildUI()
    }

    // MARK: - SCROLLVIEW
    private func setupScroll() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        contentView.axis = .vertical
        contentView.spacing = 20

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - BUILD UI
    private func buildUI() {
        contentView.addArrangedSubview(buildTopNav())
        contentView.addArrangedSubview(buildHeaderSection())
        contentView.addArrangedSubview(buildStatsSection())
        contentView.addArrangedSubview(buildStreakHoursSection())
        contentView.addArrangedSubview(buildPracticeGraphCard())
        contentView.addArrangedSubview(buildSavedSection())
    }

    // MARK: - TOP NAV (BACK BUTTON)
    private func buildTopNav() -> UIView {

        let container = UIView()
        container.backgroundColor = .clear
        container.translatesAutoresizingMaskIntoConstraints = false

        let backBtn = UIButton(type: .system)
        backBtn.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backBtn.tintColor = .black
        backBtn.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        container.addSubview(backBtn)
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            backBtn.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            backBtn.widthAnchor.constraint(equalToConstant: 32),
            backBtn.heightAnchor.constraint(equalToConstant: 32),

            container.heightAnchor.constraint(equalToConstant: 40)
        ])

        return container
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - HEADER (Gradient + Profile + Name)
    private func buildHeaderSection() -> UIView {

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Gradient
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.systemOrange.cgColor,
            UIColor.white.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.3)
        gradient.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 230)

        container.layer.addSublayer(gradient)

        // Profile Image
        let profileImg = UIImageView()
        profileImg.image = UIImage(systemName: "person.fill")!
        profileImg.tintColor = .systemBlue
        profileImg.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        profileImg.contentMode = .scaleAspectFit
        profileImg.layer.cornerRadius = 50
        profileImg.clipsToBounds = true

        // Name
        let nameLbl = UILabel()
        nameLbl.text = "Mukul Parashar"
        nameLbl.font = .boldSystemFont(ofSize: 22)

        // Location
        let locationLbl = UILabel()
        locationLbl.text = "Chennai, Tamil Nadu, India"
        locationLbl.font = .systemFont(ofSize: 14)
        locationLbl.textColor = .darkGray

        let editBtn = UIButton(type: .system)
        editBtn.setTitle("Edit ✏️", for: .normal)
        editBtn.titleLabel?.font = .systemFont(ofSize: 16)

        let vstack = UIStackView(arrangedSubviews: [
            nameLbl, locationLbl, editBtn
        ])
        vstack.axis = .vertical
        vstack.spacing = 6
        vstack.alignment = .leading

        container.addSubview(profileImg)
        container.addSubview(vstack)

        profileImg.translatesAutoresizingMaskIntoConstraints = false
        vstack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            profileImg.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            profileImg.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),
            profileImg.widthAnchor.constraint(equalToConstant: 100),
            profileImg.heightAnchor.constraint(equalToConstant: 100),

            vstack.leadingAnchor.constraint(equalTo: profileImg.trailingAnchor, constant: 20),
            vstack.centerYAnchor.constraint(equalTo: profileImg.centerYAnchor),
            vstack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            container.heightAnchor.constraint(equalToConstant: 240)
        ])

        return container
    }

    // MARK: - PLAYLIST / FOLLOWERS / FOLLOWING
    private func buildStatsSection() -> UIView {

        let container = UIView()

        let playlists = statView(number: "23", label: "PLAYLISTS")
        let followers = statView(number: "58", label: "FOLLOWERS")
        let following = statView(number: "43", label: "FOLLOWING")

        let hStack = UIStackView(arrangedSubviews: [
            playlists, followers, following
        ])
        hStack.axis = .horizontal
        hStack.distribution = .fillEqually

        container.addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: container.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            hStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func statView(number: String, label: String) -> UIView {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .center

        let num = UILabel()
        num.text = number
        num.font = .boldSystemFont(ofSize: 22)

        let lbl = UILabel()
        lbl.text = label
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = .gray

        s.addArrangedSubview(num)
        s.addArrangedSubview(lbl)
        return s
    }

    // MARK: - STREAK + HOURS SPENT
    private func buildStreakHoursSection() -> UIView {

        let streak = metricView(icon: "🔥", number: "5", label: "Days Streak")
        let hours = metricView(icon: "⏳", number: "24", label: "Hours Spent")

        let stack = UIStackView(arrangedSubviews: [streak, hours])
        stack.axis = .horizontal
        stack.distribution = .fillEqually

        return stack
    }

    private func metricView(icon: String, number: String, label: String) -> UIView {

        let emoji = UILabel()
        emoji.text = icon
        emoji.font = .systemFont(ofSize: 28)

        let num = UILabel()
        num.text = number
        num.font = .boldSystemFont(ofSize: 32)

        let lbl = UILabel()
        lbl.text = label
        lbl.textColor = .gray
        lbl.font = .systemFont(ofSize: 14)

        let stack = UIStackView(arrangedSubviews: [emoji, num, lbl])
        stack.axis = .vertical
        stack.alignment = .center
        return stack
    }

    // MARK: - PRACTICE GRAPH
    private func buildPracticeGraphCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.2, alpha: 1)
        card.layer.cornerRadius = 18
        card.heightAnchor.constraint(equalToConstant: 240).isActive = true

        let title = UILabel()
        title.text = "Practice Graph"
        title.textColor = .white
        title.font = .boldSystemFont(ofSize: 16)

        card.addSubview(title)
        title.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20)
        ])

        return card
    }

    // MARK: - SAVED SECTION
    private func buildSavedSection() -> UIView {

        let label = UILabel()
        label.text = "Saved"
        label.font = .boldSystemFont(ofSize: 20)

        let v = UIStackView(arrangedSubviews: [
            label,
            savedRow(title: "Shazam", likes: "7 likes"),
            savedRow(title: "Roadtrip", likes: "4 likes")
        ])
        v.axis = .vertical
        v.spacing = 16

        return v
    }

    private func savedRow(title: String, likes: String) -> UIView {

        let row = UIView()

        let icon = UIImageView(image: UIImage(systemName: "music.note"))
        icon.tintColor = .black
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 16, weight: .medium)

        let likeLbl = UILabel()
        likeLbl.text = likes
        likeLbl.font = .systemFont(ofSize: 12)
        likeLbl.textColor = .gray

        let labels = UIStackView(arrangedSubviews: [titleLbl, likeLbl])
        labels.axis = .vertical
        labels.spacing = 4

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .gray

        row.addSubview(icon)
        row.addSubview(labels)
        row.addSubview(arrow)

        labels.translatesAutoresizingMaskIntoConstraints = false
        arrow.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 45),
            icon.heightAnchor.constraint(equalToConstant: 45),

            labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            labels.centerYAnchor.constraint(equalTo: icon.centerYAnchor),

            arrow.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            arrow.centerYAnchor.constraint(equalTo: icon.centerYAnchor),

            row.heightAnchor.constraint(equalToConstant: 60)
        ])

        return row
    }
}

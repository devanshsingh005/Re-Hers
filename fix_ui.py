import re

with open("Screens/LearningCurve/LessonMapViewController.swift", "r") as f:
    content = f.read()

# 1. Update the inline title
content = content.replace(
    'NavigationBarHelper.createInlineTitleView(title: "Practice", subtitle: "Select a module")',
    'NavigationBarHelper.createInlineTitleView(title: "Basics", subtitle: "Interactive lessons")'
)

# 2. Update the large header text
content = content.replace(
    'titleLabel.text = "Practice"',
    'titleLabel.text = "Basics"'
)

# 3. Replace setupCustomLargeHeader completely to include the progress bar
old_setup_header = """    private func setupCustomLargeHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerContainer)
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Practice"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Interactive lessons"
        largeSubtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        largeSubtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(largeSubtitleLabel)
        headerContainer.addSubview(labelStack)
        
        largeProfileButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        largeProfileButton.layer.cornerRadius = 20
        largeProfileButton.clipsToBounds = true
        largeProfileButton.layer.borderWidth    = 1.0
        largeProfileButton.layer.borderColor    = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .white
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        headerContainer.addSubview(largeProfileButton)
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 90),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            largeProfileButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }"""

new_setup_header = """    private func setupCustomLargeHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerContainer)
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Basics"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Interactive lessons"
        largeSubtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        largeSubtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(largeSubtitleLabel)
        headerContainer.addSubview(labelStack)
        
        largeProfileButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        largeProfileButton.layer.cornerRadius = 20
        largeProfileButton.clipsToBounds = true
        largeProfileButton.layer.borderWidth    = 1.0
        largeProfileButton.layer.borderColor    = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .white
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        headerContainer.addSubview(largeProfileButton)
        
        // Setup Progress Container inside the large header
        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(progressContainer)
        
        let progressTitle = UILabel()
        progressTitle.translatesAutoresizingMaskIntoConstraints = false
        progressTitle.text = "PROGRESS"
        progressTitle.font = .systemFont(ofSize: 10, weight: .bold)
        progressTitle.textColor = .systemGray
        
        headerProgressLabel = UILabel()
        headerProgressLabel?.translatesAutoresizingMaskIntoConstraints = false
        headerProgressLabel?.text = "0%"
        headerProgressLabel?.font = .systemFont(ofSize: 10, weight: .bold)
        headerProgressLabel?.textColor = .systemGray
        
        let track = UIView()
        track.translatesAutoresizingMaskIntoConstraints = false
        track.backgroundColor = UIColor.systemGray5
        track.layer.cornerRadius = 3
        
        headerProgressFill = UIView()
        headerProgressFill?.translatesAutoresizingMaskIntoConstraints = false
        headerProgressFill?.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        headerProgressFill?.layer.cornerRadius = 3
        track.addSubview(headerProgressFill!)
        
        headerProgressFillWidth = headerProgressFill?.widthAnchor.constraint(equalToConstant: 0)
        
        progressContainer.addSubview(progressTitle)
        progressContainer.addSubview(headerProgressLabel!)
        progressContainer.addSubview(track)
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 90),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            labelStack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            largeProfileButton.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40),
            
            progressContainer.topAnchor.constraint(equalTo: largeProfileButton.bottomAnchor, constant: 16),
            progressContainer.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            progressContainer.widthAnchor.constraint(equalToConstant: 105),
            progressContainer.heightAnchor.constraint(equalToConstant: 24),
            
            progressTitle.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressTitle.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            
            headerProgressLabel!.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            headerProgressLabel!.centerYAnchor.constraint(equalTo: progressTitle.centerYAnchor),
            
            track.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            track.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            track.topAnchor.constraint(equalTo: progressTitle.bottomAnchor, constant: 6),
            track.heightAnchor.constraint(equalToConstant: 6),
            
            headerProgressFill!.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            headerProgressFill!.topAnchor.constraint(equalTo: track.topAnchor),
            headerProgressFill!.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            headerProgressFillWidth!
        ])
    }"""

content = content.replace(old_setup_header, new_setup_header)

# 4. Remove the old `setupHeader` function calls and implementation
content = content.replace("        setupHeader()\n", "")

old_setup_header_logic = r"    private func setupHeader\(\) \{.*?(?=    private func setupScrollView\(\))"
content = re.sub(old_setup_header_logic, "", content, flags=re.DOTALL)

# 5. Fix the overlapping path issues
# Also change progress calculation for the small block (width 105)
content = content.replace(
    'let availableWidth = view.bounds.width - 48',
    'let availableWidth: CGFloat = 105'
)

# 6. Apply the DB struct fixes
db_fix_old = """                let profileData: [[String: Any]] = try await db
                    .from("profiles")
                    .select("current_chapter")
                    .eq("id", value: userID.uuidString)
                    .limit(1)
                    .execute()
                    .value as? [[String: Any]] ?? []

                guard let firstProfile = profileData.first, let currentChapter = firstProfile["current_chapter"] as? Int else { return }

                let eventsData: [[String: Any]] = try await db
                    .from("lesson_events")
                    .select("chapter_index, stars")
                    .eq("user_id", value: userID.uuidString)
                    .eq("event_type", value: "lesson_completed")
                    .execute()
                    .value as? [[String: Any]] ?? []

                var starsMap: [Int: Int] = [:]
                for row in eventsData {
                    if let cIdx = row["chapter_index"] as? Int, let stars = row["stars"] as? Int {
                        let prev = starsMap[cIdx] ?? 0
                        starsMap[cIdx] = max(prev, stars)
                    }
                }"""

db_fix_new = """                struct ProfileChapterResponse: Codable {
                    let current_chapter: Int
                }
                struct LessonEventResponse: Codable {
                    let chapter_index: Int
                    let stars: Int
                }
                
                let profiles: [ProfileChapterResponse] = (try? await db
                    .from("profiles")
                    .select("current_chapter")
                    .eq("id", value: userID.uuidString)
                    .limit(1)
                    .execute()
                    .value) ?? []
                let currentChapter = profiles.first?.current_chapter ?? 1

                let events: [LessonEventResponse] = (try? await db
                    .from("lesson_events")
                    .select("chapter_index, stars")
                    .eq("user_id", value: userID.uuidString)
                    .eq("event_type", value: "lesson_completed")
                    .execute()
                    .value) ?? []

                var starsMap: [Int: Int] = [:]
                for row in events {
                    let prev = starsMap[row.chapter_index] ?? 0
                    starsMap[row.chapter_index] = max(prev, row.stars)
                }"""

content = content.replace(db_fix_old, db_fix_new)

with open("Screens/LearningCurve/LessonMapViewController.swift", "w") as f:
    f.write(content)

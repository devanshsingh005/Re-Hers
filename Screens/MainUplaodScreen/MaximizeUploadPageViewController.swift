//
//  MaximizeUploadPageViewController.swift
//  Re-Hearse_v1
//

import UIKit

final class MaximizeUploadPageViewController: UIViewController {

    // MARK: - Public API
    var sheetImage: UIImage? {
        didSet { sheetImageView.image = sheetImage }
    }
    var sheetMusicText: String = "" {
        didSet { updateMusicTextView() }
    }

    // MARK: - UI Components
    private let navBar = TopNavBar()
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let sheetContainer = UIView()
    private let sheetImageView = UIImageView()
    private let musicTextView = UITextView()
    
    private let infoStackView = UIStackView()
    private let keyLabel = UILabel()
    private let timeLabel = UILabel()
    private let chordLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavBar()
        setupUI()
        buildHierarchy()
        applyConstraints()
        enableSwipeDismiss()
    }

    // MARK: - Navbar
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible = false
        navBar.isProfileVisible = false
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.setTitle("Sheet Music")

        navBar.backAction = { [weak self] in
            self?.dismiss(animated: true)
        }

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - UI Setup
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Bigger dark card
        sheetContainer.backgroundColor = UIColor(white: 0.22, alpha: 1)
        sheetContainer.layer.cornerRadius = 34
        sheetContainer.translatesAutoresizingMaskIntoConstraints = false

        // Bigger image
        sheetImageView.contentMode = .scaleAspectFit
        sheetImageView.clipsToBounds = true
        sheetImageView.layer.cornerRadius = 22
        sheetImageView.backgroundColor = .white
        sheetImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Music Text View
        musicTextView.isEditable = false
        musicTextView.isScrollEnabled = true
        musicTextView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        musicTextView.layer.cornerRadius = 16
        musicTextView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        musicTextView.showsVerticalScrollIndicator = false
        musicTextView.showsHorizontalScrollIndicator = false
        musicTextView.translatesAutoresizingMaskIntoConstraints = false
        
        // Info Stack View
        infoStackView.axis = .horizontal
        infoStackView.spacing = 12
        infoStackView.distribution = .fillEqually
        infoStackView.translatesAutoresizingMaskIntoConstraints = false
        
        keyLabel.font = .systemFont(ofSize: 14, weight: .medium)
        keyLabel.textColor = .white
        keyLabel.textAlignment = .center
        keyLabel.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        keyLabel.layer.cornerRadius = 10
        keyLabel.clipsToBounds = true
        keyLabel.text = "Key: C Major"
        
        timeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center
        timeLabel.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        timeLabel.layer.cornerRadius = 10
        timeLabel.clipsToBounds = true
        timeLabel.text = "Time: 4/4"
        
        chordLabel.font = .systemFont(ofSize: 14, weight: .medium)
        chordLabel.textColor = .white
        chordLabel.textAlignment = .center
        chordLabel.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        chordLabel.layer.cornerRadius = 10
        chordLabel.clipsToBounds = true
        chordLabel.numberOfLines = 2
        chordLabel.text = "Chords: C, G, Am, F"
    }
    
    private func updateMusicTextView() {
        guard !sheetMusicText.isEmpty else {
            musicTextView.text = "No sheet music text available"
            musicTextView.textColor = .white
            musicTextView.font = .systemFont(ofSize: 16)
            musicTextView.textAlignment = .center
            return
        }
        
        let attributedText = NSMutableAttributedString(string: sheetMusicText)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        paragraphStyle.alignment = .left
        
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        attributedText.addAttributes(baseAttributes, range: NSRange(location: 0, length: sheetMusicText.count))
        
        // Highlight measure numbers
        let measureRegex = try! NSRegularExpression(pattern: "Measure \\d+:", options: [])
        let measureMatches = measureRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in measureMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor(red: 0.4, green: 0.8, blue: 1, alpha: 1)
            ], range: match.range)
        }
        
        // Highlight section headers
        let sectionRegex = try! NSRegularExpression(pattern: "(TIME:|INSTRUMENT:|CHORD PROGRESSION:|KEY:|DIFFICULTY:)", options: [])
        let sectionMatches = sectionRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in sectionMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 1)
            ], range: match.range)
        }
        
        // Highlight notes
        let noteRegex = try! NSRegularExpression(pattern: "\\b[A-G][#b]?\\d\\b", options: [])
        let noteMatches = noteRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in noteMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .medium),
                .foregroundColor: UIColor(red: 0.8, green: 1, blue: 0.6, alpha: 1)
            ], range: match.range)
        }
        
        // Highlight chords
        let chordRegex = try! NSRegularExpression(pattern: "\\b(C|G|Am|F|Dm|Em|A|D|E|Bm)\\b", options: [])
        let chordMatches = chordRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in chordMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .bold),
                .foregroundColor: UIColor(red: 1, green: 0.6, blue: 0.8, alpha: 1)
            ], range: match.range)
        }
        
        musicTextView.attributedText = attributedText
        
        // Extract info for labels
        extractInfoFromText()
    }
    
    private func extractInfoFromText() {
        // Extract key
        if let keyRange = sheetMusicText.range(of: "KEY: ") {
            let startIndex = sheetMusicText.index(keyRange.upperBound, offsetBy: 0)
            if let endIndex = sheetMusicText[startIndex...].firstIndex(of: "\n") {
                let key = String(sheetMusicText[startIndex..<endIndex])
                keyLabel.text = "Key: \(key)"
            }
        }
        
        // Extract time signature
        if let timeRange = sheetMusicText.range(of: "TIME: ") {
            let startIndex = sheetMusicText.index(timeRange.upperBound, offsetBy: 0)
            let substring = sheetMusicText[startIndex...]
            if let endIndex = substring.firstIndex(of: "\n") {
                let time = String(sheetMusicText[startIndex..<endIndex])
                timeLabel.text = "Time: \(time)"
            }
        }
        
        // Extract chords
        if let chordsRange = sheetMusicText.range(of: "CHORD PROGRESSION:") {
            let startIndex = sheetMusicText.index(chordsRange.upperBound, offsetBy: 0)
            let substring = sheetMusicText[startIndex...]
            if let endIndex = substring.range(of: "\n\n")?.lowerBound {
                let chordsLine = String(sheetMusicText[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                chordLabel.text = "Chords: \(chordsLine)"
            } else {
                // If no double newline, take until end
                let chordsLine = String(sheetMusicText[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                chordLabel.text = "Chords: \(chordsLine)"
            }
        }
    }

    // MARK: - Hierarchy
    private func buildHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(sheetContainer)
        sheetContainer.addSubview(sheetImageView)
        sheetContainer.addSubview(musicTextView)
        sheetContainer.addSubview(infoStackView)
        
        infoStackView.addArrangedSubview(keyLabel)
        infoStackView.addArrangedSubview(timeLabel)
        infoStackView.addArrangedSubview(chordLabel)
    }

    // MARK: - Constraints
    private func applyConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        NSLayoutConstraint.activate([
            sheetContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            sheetContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),

            sheetImageView.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 30),
            sheetImageView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 30),
            sheetImageView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -30),
            sheetImageView.heightAnchor.constraint(equalToConstant: 300),

            musicTextView.topAnchor.constraint(equalTo: sheetImageView.bottomAnchor, constant: 20),
            musicTextView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 30),
            musicTextView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -30),
            musicTextView.heightAnchor.constraint(equalToConstant: 200),
            
            infoStackView.topAnchor.constraint(equalTo: musicTextView.bottomAnchor, constant: 16),
            infoStackView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 30),
            infoStackView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -30),
            infoStackView.heightAnchor.constraint(equalToConstant: 40),
            infoStackView.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -30)
        ])
    }

    // MARK: - Swipe to dismiss
    private func enableSwipeDismiss() {
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipe.direction = .down
        view.addGestureRecognizer(swipe)
    }

    @objc private func handleSwipeDown() {
        dismiss(animated: true)
    }
}

//
//  UploadPageNextViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase

final class UploadPageNextViewController: UIViewController {

    var uploadedImage: UIImage? {
        didSet { sheetImageView.image = uploadedImage }
    }
    
    var scanData: UploadScreen.Scan? // Add this to store scan data
    private var sheetMusicText: String = ""
    private var extractedChords: [String] = []
    private var timeSignature: String = "4/4"
    private var tempo: String = "120 BPM"

    private let navBar = TopNavBar()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let sheetContainer = UIView()
    private let sheetHeaderLabel = UILabel()
    private let maximizeButton = UIButton(type: .system)
    private let sheetImageView = UIImageView()
    private let musicTextView = UITextView() // Text view for sheet music
    private let metronomeLabel = UILabel()
    
    private let infoStackView = UIStackView()
    private let keyLabel = UILabel()
    private let timeLabel = UILabel()
    private let chordLabel = UILabel()

    private let tipsContainer = UIView()
    private let tipsTitleLabel = UILabel()
    private let tipsBodyLabel = UILabel()

    private let playAlongButton = UIButton(type: .system)
    private let animationButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavBar()
        setupUI()
        buildHierarchy()
        applyConstraints()
        setupActions()
        
        loadScanData()
    }
    
    // MARK: - Data Loading
    private func loadScanData() {
        loadLatestScanFromDatabase()
    }
    
    private func loadLatestScanFromDatabase() {
        Task {
            do {
                let scans: [UploadScreen.Scan] = try await SupabaseManager.shared.client
                    .from("scans")
                    .select()
                    .order("updated_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                if let latestScan = scans.first {
                    self.scanData = latestScan
                    DispatchQueue.main.async {
                        self.extractAndDisplaySheetMusic()
                    }
                }
            } catch {
                print("Error loading scan: \(error)")
                DispatchQueue.main.async {
                    self.showSampleSheetMusic()
                }
            }
        }
    }
    
    private func extractAndDisplaySheetMusic() {
        guard let scan = scanData,
              let jsonData = scan.jsonData,
              let analysisDict = jsonData.value as? [String: Any] else {
            showSampleSheetMusic()
            return
        }
        
        // Try to extract MusicXML data
        if let scorePartwise = analysisDict["score-partwise"] as? [String: Any] {
            processMusicXMLData(scorePartwise)
        } else if let sheetMusic = analysisDict["sheet_music"] as? String {
            sheetMusicText = sheetMusic
            displaySheetMusic()
        } else {
            showSampleSheetMusic()
        }
        
        metronomeLabel.text = "Metronome: \(tempo)"
        updatePracticeTips()
    }
    
    private func processMusicXMLData(_ data: [String: Any]) {
        var result = ""
        extractedChords.removeAll()
        
        // Extract time signature
        if let part = data["part"] as? [String: Any],
           let measures = part["measure"] as? [[String: Any]],
           let firstMeasure = measures.first,
           let attributes = firstMeasure["attributes"] as? [String: Any],
           let time = attributes["time"] as? [String: Any],
           let beats = time["beats"] as? String,
           let beatType = time["beat-type"] as? String {
            timeSignature = "\(beats)/\(beatType)"
        }
        
        // Process measures
        if let part = data["part"] as? [String: Any],
           let measures = part["measure"] as? [[String: Any]] {
            
            result += "TIME: \(timeSignature)\n"
            result += "INSTRUMENT: Piano\n\n"
            
            for (index, measureDict) in measures.enumerated() {
                let measureNum = index + 1
                result += "Measure \(measureNum):\n"
                
                if let notes = measureDict["note"] {
                    var measureNotes: [String] = []
                    
                    if let noteArray = notes as? [[String: Any]] {
                        for noteDict in noteArray {
                            if let pitch = noteDict["pitch"] as? [String: Any],
                               let step = pitch["step"] as? String,
                               let octave = pitch["octave"] as? String {
                                let noteName = "\(step)\(octave)"
                                measureNotes.append(noteName)
                                extractChordFromNote(step: step, octave: octave)
                            }
                        }
                    } else if let noteDict = notes as? [String: Any],
                              let pitch = noteDict["pitch"] as? [String: Any],
                              let step = pitch["step"] as? String,
                              let octave = pitch["octave"] as? String {
                        let noteName = "\(step)\(octave)"
                        measureNotes.append(noteName)
                        extractChordFromNote(step: step, octave: octave)
                    }
                    
                    if !measureNotes.isEmpty {
                        result += "  Notes: \(measureNotes.joined(separator: ", "))\n"
                    }
                }
                result += "\n"
            }
            
            if !extractedChords.isEmpty {
                result += "CHORD PROGRESSION:\n"
                let uniqueChords = Array(Set(extractedChords))
                result += uniqueChords.joined(separator: " - ") + "\n"
                chordLabel.text = "Chords: \(uniqueChords.joined(separator: ", "))"
            }
        }
        
        sheetMusicText = result
        displaySheetMusic()
        keyLabel.text = "Key: C Major"
        timeLabel.text = "Time: \(timeSignature)"
    }
    
    private func extractChordFromNote(step: String, octave: String) {
        let note = "\(step)\(octave)"
        let chordNotes: [String: [String]] = [
            "C": ["C4", "E4", "G4"],
            "G": ["G4", "B4", "D5"],
            "Am": ["A4", "C5", "E5"],
            "F": ["F4", "A4", "C5"],
            "Dm": ["D4", "F4", "A4"],
            "Em": ["E4", "G4", "B4"]
        ]
        
        for (chord, notes) in chordNotes {
            if notes.contains(note) && !extractedChords.contains(chord) {
                extractedChords.append(chord)
            }
        }
    }
    
    private func showSampleSheetMusic() {
        sheetMusicText = """
        TIME: 2/4
        INSTRUMENT: Piano
        
        Measure 1:
          Right Hand: C4 (quarter) | C4 (quarter)
          Left Hand: C3 (half)
        
        Measure 2:
          Right Hand: G4 (quarter) | G4 (quarter)
          Left Hand: E3 (half)
        
        Measure 3:
          Right Hand: A4 (quarter) | A4 (quarter)
          Left Hand: F3 (half)
        
        CHORD PROGRESSION:
        C - G - Am - F
        
        KEY: C Major
        DIFFICULTY: Beginner
        """
        
        extractedChords = ["C", "G", "Am", "F"]
        timeSignature = "2/4"
        
        displaySheetMusic()
        keyLabel.text = "Key: C Major"
        timeLabel.text = "Time: \(timeSignature)"
        chordLabel.text = "Chords: \(extractedChords.joined(separator: ", "))"
    }
    
    private func displaySheetMusic() {
        let attributedText = NSMutableAttributedString(string: sheetMusicText)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .left
        
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        attributedText.addAttributes(baseAttributes, range: NSRange(location: 0, length: sheetMusicText.count))
        
        // Highlight measure numbers
        let measureRegex = try! NSRegularExpression(pattern: "Measure \\d+:", options: [])
        let measureMatches = measureRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in measureMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor(red: 0.4, green: 0.8, blue: 1, alpha: 1)
            ], range: match.range)
        }
        
        // Highlight section headers
        let sectionRegex = try! NSRegularExpression(pattern: "(TIME:|INSTRUMENT:|CHORD PROGRESSION:|KEY:|DIFFICULTY:)", options: [])
        let sectionMatches = sectionRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in sectionMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 1)
            ], range: match.range)
        }
        
        // Highlight notes
        let noteRegex = try! NSRegularExpression(pattern: "\\b[A-G][#b]?\\d\\b", options: [])
        let noteMatches = noteRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in noteMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .medium),
                .foregroundColor: UIColor(red: 0.8, green: 1, blue: 0.6, alpha: 1)
            ], range: match.range)
        }
        
        // Highlight chords
        let chordRegex = try! NSRegularExpression(pattern: "\\b(C|G|Am|F|Dm|Em|A|D|E|Bm)\\b", options: [])
        let chordMatches = chordRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in chordMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .bold),
                .foregroundColor: UIColor(red: 1, green: 0.6, blue: 0.8, alpha: 1)
            ], range: match.range)
        }
        
        musicTextView.attributedText = attributedText
    }
    
    private func updatePracticeTips() {
        var tips = ""
        
        if extractedChords.contains("F") || extractedChords.contains("Bm") {
            tips += "• Practice barre chords for better sound\n"
        }
        
        if timeSignature == "2/4" || timeSignature == "3/4" {
            tips += "• Count aloud: 1-2 for 2/4, 1-2-3 for 3/4\n"
        }
        
        if extractedChords.contains("Am") || extractedChords.contains("Dm") || extractedChords.contains("Em") {
            tips += "• Minor chords add emotional depth\n"
        }
        
        tips += "• Keep wrists relaxed and fingers curved\n"
        tips += "• Listen for even timing between notes\n"
        
        tipsBodyLabel.text = tips
    }

    // MARK: - Button Actions
    private func setupActions() {
        maximizeButton.addTarget(self, action: #selector(didTapMaximize), for: .touchUpInside)
        playAlongButton.addTarget(self, action: #selector(didTapPlayAlong), for: .touchUpInside)
        animationButton.addTarget(self, action: #selector(didTapAnimation), for: .touchUpInside)
    }

    @objc private func didTapMaximize() {
        let vc = MaximizeUploadPageViewController() // Use correct class name
        vc.sheetImage = uploadedImage
        vc.sheetMusicText = sheetMusicText
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
    
    @objc private func didTapPlayAlong() {
        let alert = UIAlertController(
            title: "Play Along",
            message: "Play chord progression at \(tempo)?\n\nChords: \(extractedChords.joined(separator: " - "))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Start", style: .default) { _ in
            self.startPlayAlong()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func startPlayAlong() {
        print("Playing chords: \(extractedChords)")
        let playingAlert = UIAlertController(
            title: "Playing...",
            message: "Chord progression: \(extractedChords.joined(separator: " → "))",
            preferredStyle: .alert
        )
        playingAlert.addAction(UIAlertAction(title: "Stop", style: .destructive))
        present(playingAlert, animated: true)
    }
    
    @objc private func didTapAnimation() {
        let chordList = extractedChords.isEmpty ? "C, G, Am, F" : extractedChords.joined(separator: ", ")
        let alert = UIAlertController(
            title: "Chord Animation",
            message: "Show finger placement for: \(chordList)",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Show All Chords", style: .default))
        
        for chord in extractedChords {
            alert.addAction(UIAlertAction(title: "Show \(chord) Chord", style: .default))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - UI Setup
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible = true
        navBar.isProfileVisible = true
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.setTitle("Sheet Music")

        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        navBar.chordAction = { [weak self] in
            let vc = ChordRecognitionViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }
        
        navBar.profileAction = { [weak self] in
            let vc = UserProfileViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        sheetContainer.backgroundColor = UIColor(white: 0.22, alpha: 1)
        sheetContainer.layer.cornerRadius = 30
        sheetContainer.translatesAutoresizingMaskIntoConstraints = false

        sheetHeaderLabel.text = "Music Analysis"
        sheetHeaderLabel.font = .systemFont(ofSize: 16, weight: .medium)
        sheetHeaderLabel.textColor = .white
        sheetHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        maximizeButton.setTitle("Maximize", for: .normal)
        maximizeButton.setTitleColor(.white, for: .normal)
        maximizeButton.titleLabel?.font = .systemFont(ofSize: 13)
        maximizeButton.backgroundColor = UIColor.white.withAlphaComponent(0.17)
        maximizeButton.layer.cornerRadius = 14
        maximizeButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        maximizeButton.translatesAutoresizingMaskIntoConstraints = false

        sheetImageView.contentMode = .scaleAspectFit
        sheetImageView.clipsToBounds = true
        sheetImageView.layer.cornerRadius = 20
        sheetImageView.backgroundColor = .white
        sheetImageView.image = uploadedImage
        sheetImageView.translatesAutoresizingMaskIntoConstraints = false
        
        musicTextView.isEditable = false
        musicTextView.isScrollEnabled = true
        musicTextView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        musicTextView.layer.cornerRadius = 12
        musicTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        musicTextView.showsVerticalScrollIndicator = false
        musicTextView.translatesAutoresizingMaskIntoConstraints = false
        
        infoStackView.axis = .horizontal
        infoStackView.spacing = 12
        infoStackView.distribution = .fillEqually
        infoStackView.translatesAutoresizingMaskIntoConstraints = false
        
        keyLabel.font = .systemFont(ofSize: 12, weight: .medium)
        keyLabel.textColor = .white
        keyLabel.textAlignment = .center
        keyLabel.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        keyLabel.layer.cornerRadius = 8
        keyLabel.clipsToBounds = true
        
        timeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        timeLabel.textColor = .white
        timeLabel.textAlignment = .center
        timeLabel.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        timeLabel.layer.cornerRadius = 8
        timeLabel.clipsToBounds = true
        
        chordLabel.font = .systemFont(ofSize: 12, weight: .medium)
        chordLabel.textColor = .white
        chordLabel.textAlignment = .center
        chordLabel.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        chordLabel.layer.cornerRadius = 8
        chordLabel.clipsToBounds = true
        chordLabel.numberOfLines = 2

        metronomeLabel.text = "Metronome: \(tempo)"
        metronomeLabel.font = .systemFont(ofSize: 12)
        metronomeLabel.textColor = .white
        metronomeLabel.translatesAutoresizingMaskIntoConstraints = false

        tipsContainer.backgroundColor = UIColor(white: 0.95, alpha: 1)
        tipsContainer.layer.cornerRadius = 18
        tipsContainer.translatesAutoresizingMaskIntoConstraints = false

        tipsTitleLabel.text = "Practice Tips"
        tipsTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        tipsTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        tipsBodyLabel.text = ""
        tipsBodyLabel.numberOfLines = 0
        tipsBodyLabel.font = .systemFont(ofSize: 14)
        tipsBodyLabel.textColor = .darkGray
        tipsBodyLabel.translatesAutoresizingMaskIntoConstraints = false

        DispatchQueue.main.async {
            let border = CAShapeLayer()
            border.strokeColor = UIColor.darkGray.cgColor
            border.lineWidth = 2.8
            border.lineDashPattern = [6, 4]
            border.fillColor = UIColor.clear.cgColor
            border.path = UIBezierPath(roundedRect: self.tipsContainer.bounds, cornerRadius: 18).cgPath
            border.frame = self.tipsContainer.bounds
            self.tipsContainer.layer.addSublayer(border)
        }

        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.25, alpha: 1)
        playAlongButton.layer.cornerRadius = 12
        playAlongButton.setTitleColor(.black, for: .normal)
        playAlongButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        playAlongButton.translatesAutoresizingMaskIntoConstraints = false

        animationButton.setTitle("Animation", for: .normal)
        animationButton.backgroundColor = UIColor(white: 0.92, alpha: 1)
        animationButton.layer.cornerRadius = 12
        animationButton.setTitleColor(.darkGray, for: .normal)
        animationButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        animationButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(sheetContainer)
        sheetContainer.addSubview(sheetHeaderLabel)
        sheetContainer.addSubview(maximizeButton)
        sheetContainer.addSubview(sheetImageView)
        sheetContainer.addSubview(musicTextView)
        sheetContainer.addSubview(infoStackView)
        sheetContainer.addSubview(metronomeLabel)
        
        infoStackView.addArrangedSubview(keyLabel)
        infoStackView.addArrangedSubview(timeLabel)
        infoStackView.addArrangedSubview(chordLabel)

        contentView.addSubview(tipsContainer)
        tipsContainer.addSubview(tipsTitleLabel)
        tipsContainer.addSubview(tipsBodyLabel)

        contentView.addSubview(playAlongButton)
        contentView.addSubview(animationButton)
    }

    private func applyConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        NSLayoutConstraint.activate([
            sheetContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            sheetHeaderLabel.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 20),
            sheetHeaderLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 20),

            maximizeButton.centerYAnchor.constraint(equalTo: sheetHeaderLabel.centerYAnchor),
            maximizeButton.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -20),

            sheetImageView.topAnchor.constraint(equalTo: sheetHeaderLabel.bottomAnchor, constant: 20),
            sheetImageView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            sheetImageView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            sheetImageView.heightAnchor.constraint(equalToConstant: 180),

            musicTextView.topAnchor.constraint(equalTo: sheetImageView.bottomAnchor, constant: 16),
            musicTextView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            musicTextView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            musicTextView.heightAnchor.constraint(equalToConstant: 160),
            
            infoStackView.topAnchor.constraint(equalTo: musicTextView.bottomAnchor, constant: 12),
            infoStackView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            infoStackView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            infoStackView.heightAnchor.constraint(equalToConstant: 36),

            metronomeLabel.topAnchor.constraint(equalTo: infoStackView.bottomAnchor, constant: 12),
            metronomeLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -20),
            metronomeLabel.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -20)
        ])

        NSLayoutConstraint.activate([
            tipsContainer.topAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: 20),
            tipsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tipsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            tipsTitleLabel.topAnchor.constraint(equalTo: tipsContainer.topAnchor, constant: 16),
            tipsTitleLabel.leadingAnchor.constraint(equalTo: tipsContainer.leadingAnchor, constant: 16),

            tipsBodyLabel.topAnchor.constraint(equalTo: tipsTitleLabel.bottomAnchor, constant: 8),
            tipsBodyLabel.leadingAnchor.constraint(equalTo: tipsContainer.leadingAnchor, constant: 16),
            tipsBodyLabel.trailingAnchor.constraint(equalTo: tipsContainer.trailingAnchor, constant: -16),
            tipsBodyLabel.bottomAnchor.constraint(equalTo: tipsContainer.bottomAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            playAlongButton.topAnchor.constraint(equalTo: tipsContainer.bottomAnchor, constant: 30),
            playAlongButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            playAlongButton.heightAnchor.constraint(equalToConstant: 54),

            animationButton.centerYAnchor.constraint(equalTo: playAlongButton.centerYAnchor),
            animationButton.leadingAnchor.constraint(equalTo: playAlongButton.trailingAnchor, constant: 16),
            animationButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            animationButton.heightAnchor.constraint(equalToConstant: 54),

            playAlongButton.widthAnchor.constraint(equalTo: animationButton.widthAnchor),
            animationButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50)
        ])
    }
}

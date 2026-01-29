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
    
    var jobData: Job?
    private var sheetMusicText: String = ""
    private var extractedChords: [String] = []
    private var timeSignature: String = "4/4"
    private var tempo: String = "120 BPM"
    private var keySignature: String = "C Major"

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
    
    // MARK: - Data Models
    struct Job: Codable, Identifiable {
        let id: UUID
        let userId: UUID
        let pdfPath: String
        let resultUrl: String?
        let status: String
        let errorMessage: String?
        let createdAt: Date
        let updatedAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case pdfPath = "pdf_path"
            case resultUrl = "result_url"
            case status
            case errorMessage = "error_message"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
    
    struct SheetMusicData {
        let text: String
        let chords: [String]
        let timeSignature: String
        let tempo: String
        let keySignature: String
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavBar()
        setupUI()
        buildHierarchy()
        applyConstraints()
        setupActions()
        
        loadJobData()
    }
    
    // MARK: - Data Loading
    private func loadJobData() {
        loadLatestJobFromDatabase()
    }
    
    private func loadLatestJobFromDatabase() {
        Task {
            do {
                // Get current user ID
                guard let currentUserId = await getCurrentUserId() else {
                    throw NSError(domain: "DataError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user found"])
                }
                
                print("Fetching jobs for user: \(currentUserId)")
                
                // Fetch latest job for current user
                let jobs: [Job] = try await SupabaseManager.shared.client
                    .from("jobs")
                    .select()
                    .eq("user_id", value: currentUserId)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                if let latestJob = jobs.first {
                    self.jobData = latestJob
                    print("Found job: \(latestJob.id), status: \(latestJob.status), resultUrl: \(latestJob.resultUrl ?? "nil")")
                    
                    // Load and display the sheet music data
                    DispatchQueue.main.async {
                        self.loadAndDisplaySheetMusic(from: latestJob)
                    }
                } else {
                    print("No jobs found for user")
                    DispatchQueue.main.async {
                        self.showSampleSheetMusic()
                    }
                }
            } catch {
                print("Error loading job: \(error)")
                DispatchQueue.main.async {
                    self.showSampleSheetMusic()
                }
            }
        }
    }
    
    private func getCurrentUserId() async -> UUID? {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            return session.user.id
        } catch {
            print("Error getting user session: \(error)")
            return nil
        }
    }
    
    private func loadAndDisplaySheetMusic(from job: Job) {
        // Check if job is completed and has result URL
        guard job.status == "completed", let resultUrl = job.resultUrl else {
            if job.status == "failed" {
                showErrorState(error: job.errorMessage ?? "Processing failed")
            } else if job.status == "processing" {
                showProcessingState()
            } else {
                showSampleSheetMusic()
            }
            return
        }
        
        // Download and parse the result JSON from bucket
        Task {
            do {
                print("Downloading result from: \(resultUrl)")
                let resultData = try await downloadResultFromBucket(url: resultUrl)
                
                // First, try to parse as JSON
                if let json = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] {
                    print("Successfully parsed as JSON")
                    let sheetData = try await parseSheetMusicData(json: json)
                    
                    DispatchQueue.main.async {
                        self.displaySheetData(sheetData)
                    }
                } else {
                    // If not JSON, try to parse as text
                    if let text = String(data: resultData, encoding: .utf8) {
                        print("Parsing as text")
                        let sheetData = SheetMusicData(
                            text: text,
                            chords: [],
                            timeSignature: "4/4",
                            tempo: "120 BPM",
                            keySignature: "C Major"
                        )
                        
                        DispatchQueue.main.async {
                            self.displaySheetData(sheetData)
                        }
                    } else {
                        throw NSError(domain: "ParseError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unsupported file format"])
                    }
                }
            } catch {
                print("Error loading sheet music: \(error)")
                DispatchQueue.main.async {
                    self.showSampleSheetMusic()
                }
            }
        }
    }
    
    private func downloadResultFromBucket(url: String) async throws -> Data {
        guard let fileUrl = URL(string: url) else {
            throw NSError(domain: "DownloadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: fileUrl)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "DownloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to download file"])
        }
        
        return data
    }
    
    // MARK: - MusicXML Parsing
    private func parseSheetMusicData(json: [String: Any]) async throws -> SheetMusicData {
        print("Parsing sheet music JSON...")
        
        // Extract from score-partwise structure (MusicXML)
        var sheetMusicText = ""
        var chords: [String] = []
        var timeSig = "4/4"
        var tempoStr = "120 BPM"
        var keySig = "C Major"
        
        // Check if we have score-partwise structure
        if let scorePartwise = json["score-partwise"] as? [String: Any] {
            print("Found score-partwise structure")
            sheetMusicText = formatMusicXMLData(scorePartwise)
            
            // Extract time signature from first measure
            if let part = scorePartwise["part"] as? [String: Any],
               let measures = parseMeasures(from: part),
               let firstMeasure = measures.first,
               let attributes = firstMeasure["attributes"] as? [String: Any],
               let time = attributes["time"] as? [String: Any] {
                
                if let beats = time["beats"] as? String,
                   let beatType = time["beat-type"] as? String {
                    timeSig = "\(beats)/\(beatType)"
                } else if let beats = time["beats"] as? Int,
                          let beatType = time["beat-type"] as? Int {
                    timeSig = "\(beats)/\(beatType)"
                }
            }
            
            // Extract notes and chords from all measures
            if let part = scorePartwise["part"] as? [String: Any],
               let measures = parseMeasures(from: part) {
                
                var allNotes: [String] = []
                
                for measure in measures {
                    if let notes = measure["note"] {
                        let measureNotes = extractNotes(from: notes)
                        allNotes.append(contentsOf: measureNotes)
                    }
                }
                
                // Analyze chords from collected notes
                chords = analyzeChords(from: allNotes)
            }
        } else {
            // Try other possible structures
            sheetMusicText = "MusicXML Score\n\n"
            
            if let partList = json["part-list"] as? [String: Any],
               let scorePart = partList["score-part"] as? [String: Any],
               let partName = scorePart["part-name"] as? String {
                sheetMusicText += "Instrument: \(partName)\n\n"
            }
            
            // Add raw JSON for debugging
            sheetMusicText += "JSON Structure:\n"
            for key in json.keys {
                sheetMusicText += "- \(key)\n"
            }
        }
        
        print("Parsing complete. Time: \(timeSig), Chords: \(chords)")
        
        return SheetMusicData(
            text: sheetMusicText,
            chords: Array(Set(chords)), // Remove duplicates
            timeSignature: timeSig,
            tempo: tempoStr,
            keySignature: keySig
        )
    }
    
    private func parseMeasures(from part: [String: Any]) -> [[String: Any]]? {
        if let measures = part["measure"] as? [[String: Any]] {
            return measures
        } else if let measure = part["measure"] as? [String: Any] {
            return [measure]
        }
        return nil
    }
    
    private func extractNotes(from notes: Any) -> [String] {
        var noteNames: [String] = []
        
        if let noteArray = notes as? [[String: Any]] {
            for noteDict in noteArray {
                if let pitch = noteDict["pitch"] as? [String: Any],
                   let step = pitch["step"] as? String,
                   let octave = pitch["octave"] as? String {
                    let alter = pitch["alter"] as? String
                    let accidental = alter.flatMap { Int($0) } ?? 0
                    
                    var noteName = step
                    if accidental == 1 {
                        noteName += "♯"
                    } else if accidental == -1 {
                        noteName += "♭"
                    }
                    noteName += "\(octave)"
                    noteNames.append(noteName)
                } else if noteDict["rest"] != nil {
                    noteNames.append("REST")
                }
            }
        } else if let noteDict = notes as? [String: Any] {
            if let pitch = noteDict["pitch"] as? [String: Any],
               let step = pitch["step"] as? String,
               let octave = pitch["octave"] as? String {
                let alter = pitch["alter"] as? String
                let accidental = alter.flatMap { Int($0) } ?? 0
                
                var noteName = step
                if accidental == 1 {
                    noteName += "♯"
                } else if accidental == -1 {
                    noteName += "♭"
                }
                noteName += "\(octave)"
                noteNames.append(noteName)
            } else if noteDict["rest"] != nil {
                noteNames.append("REST")
            }
        }
        
        return noteNames
    }
    
    private func analyzeChords(from notes: [String]) -> [String] {
        var chords: [String] = []
        
        // Group notes by measure (simplified analysis)
        let chordMap: [String: [String]] = [
            "C": ["C4", "E4", "G4"],
            "G": ["G4", "B4", "D5"],
            "Am": ["A4", "C5", "E5"],
            "F": ["F4", "A4", "C5"],
            "Dm": ["D4", "F4", "A4"],
            "Em": ["E4", "G4", "B4"],
            "A": ["A4", "C♯5", "E5"],
            "D": ["D4", "F♯4", "A4"],
            "E": ["E4", "G♯4", "B4"],
            "Bm": ["B4", "D5", "F♯5"]
        ]
        
        // Look for common chord patterns
        for (chord, chordNotes) in chordMap {
            var matchCount = 0
            for chordNote in chordNotes {
                if notes.contains(chordNote) {
                    matchCount += 1
                }
            }
            if matchCount >= 2 { // At least 2 matching notes for a chord
                chords.append(chord)
            }
        }
        
        // If no chords found, return common progression
        if chords.isEmpty {
            chords = ["C", "G", "Am", "F"]
        }
        
        return chords
    }
    
    private func formatMusicXMLData(_ data: [String: Any]) -> String {
        var result = ""
        
        // Extract part information
        if let partList = data["part-list"] as? [String: Any],
           let scorePart = partList["score-part"] as? [String: Any] {
            
            if let partName = scorePart["part-name"] as? String {
                result += "INSTRUMENT: \(partName)\n"
            }
        }
        
        // Extract measures
        if let part = data["part"] as? [String: Any],
           let measures = parseMeasures(from: part) {
            
            result += "TIME SIGNATURE: \(timeSignature)\n\n"
            
            for (index, measureDict) in measures.enumerated() {
                let measureNum = index + 1
                result += "=== MEASURE \(measureNum) ===\n"
                
                // Extract attributes for this measure
                if let attributes = measureDict["attributes"] as? [String: Any] {
                    if let divisions = attributes["divisions"] {
                        result += "Divisions: \(divisions)\n"
                    }
                }
                
                // Extract notes
                if let notes = measureDict["note"] {
                    let noteList = extractNotes(from: notes)
                    if !noteList.isEmpty {
                        result += "Notes: \(noteList.joined(separator: ", "))\n"
                    }
                    
                    // Extract note types and durations
                    if let noteArray = notes as? [[String: Any]] {
                        for noteDict in noteArray {
                            if let type = noteDict["type"] as? String,
                               let duration = noteDict["duration"] {
                                if let pitch = noteDict["pitch"] as? [String: Any],
                                   let step = pitch["step"] as? String,
                                   let octave = pitch["octave"] as? String {
                                    result += "  \(step)\(octave): \(type) (duration: \(duration))\n"
                                } else if noteDict["rest"] != nil {
                                    result += "  REST: \(type) (duration: \(duration))\n"
                                }
                            }
                        }
                    }
                }
                
                // Check for barline
                if measureDict["barline"] != nil {
                    result += "--- Barline ---\n"
                }
                
                result += "\n"
            }
        } else {
            result += "No measures found in the score.\n"
        }
        
        return result
    }
    
    private func displaySheetData(_ data: SheetMusicData) {
        sheetMusicText = data.text
        extractedChords = data.chords
        timeSignature = data.timeSignature
        tempo = data.tempo
        keySignature = data.keySignature
        
        displaySheetMusic()
        metronomeLabel.text = "Metronome: \(tempo)"
        keyLabel.text = "Key: \(keySignature)"
        timeLabel.text = "Time: \(timeSignature)"
        chordLabel.text = "Chords: \(extractedChords.joined(separator: ", "))"
        updatePracticeTips()
    }
    
    private func showErrorState(error: String) {
        sheetMusicText = """
        PROCESSING ERROR
        
        Status: Failed
        Error: \(error)
        
        Please try uploading the sheet again.
        Make sure the image is clear and well-lit.
        """
        
        displaySheetMusic()
        metronomeLabel.text = "Metronome: N/A"
        keyLabel.text = "Key: N/A"
        timeLabel.text = "Time: N/A"
        chordLabel.text = "Chords: N/A"
        
        tipsBodyLabel.text = "• Check your internet connection\n• Ensure the sheet is clear\n• Try uploading again"
    }
    
    private func showProcessingState() {
        sheetMusicText = """
        PROCESSING...
        
        Your sheet music is being analyzed.
        This may take a few moments.
        
        Please wait...
        """
        
        displaySheetMusic()
        metronomeLabel.text = "Metronome: Processing"
        keyLabel.text = "Key: Processing"
        timeLabel.text = "Time: Processing"
        chordLabel.text = "Chords: Processing"
        
        tipsBodyLabel.text = "• Processing usually takes 30-60 seconds\n• Results will appear automatically\n• Check back in a moment"
    }
    
    private func showSampleSheetMusic() {
        sheetMusicText = """
        MUSIC SHEET ANALYSIS
        
        No recent sheet music found.
        
        Upload a sheet music image to get started!
        
        Features:
        • Automatic chord detection
        • Time signature analysis
        • Practice tips
        • Play-along mode
        
        How to use:
        1. Take a photo of sheet music
        2. Upload it from the Upload screen
        3. Get instant analysis here
        """
        
        extractedChords = ["C", "G", "Am", "F"]
        timeSignature = "4/4"
        tempo = "120 BPM"
        keySignature = "C Major"
        
        displaySheetMusic()
        metronomeLabel.text = "Metronome: \(tempo)"
        keyLabel.text = "Key: \(keySignature)"
        timeLabel.text = "Time: \(timeSignature)"
        chordLabel.text = "Chords: \(extractedChords.joined(separator: ", "))"
        
        tipsBodyLabel.text = "• Sample chords shown for demonstration\n• Upload your own sheet music for analysis\n• Practice regularly for best results"
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
        
        // Highlight section headers
        let sectionRegex = try! NSRegularExpression(pattern: "(INSTRUMENT:|TIME SIGNATURE:|MEASURE \\d+|Divisions:|Notes:|--- Barline ---)", options: [])
        let sectionMatches = sectionRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in sectionMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 1)
            ], range: match.range)
        }
        
        // Highlight notes
        let noteRegex = try! NSRegularExpression(pattern: "\\b[A-G][#♯b♭]?\\d\\b", options: [])
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
        
        // Chord-based tips
        if extractedChords.contains("F") || extractedChords.contains("Bm") {
            tips += "• Practice barre chords for better sound\n"
        }
        
        if extractedChords.contains("Am") || extractedChords.contains("Dm") || extractedChords.contains("Em") {
            tips += "• Minor chords add emotional depth\n"
        }
        
        // Time signature tips
        if timeSignature == "2/4" || timeSignature == "3/4" {
            tips += "• Count aloud: 1-2 for 2/4, 1-2-3 for 3/4\n"
        } else if timeSignature == "6/8" {
            tips += "• Feel in 2: 1-2-3, 4-5-6\n"
        }
        
        // General tips
        tips += "• Keep wrists relaxed and fingers curved\n"
        tips += "• Listen for even timing between notes\n"
        tips += "• Practice slowly, then increase tempo\n"
        tips += "• Use a metronome for consistent rhythm\n"
        
        tipsBodyLabel.text = tips
    }

    // MARK: - Button Actions
    private func setupActions() {
        maximizeButton.addTarget(self, action: #selector(didTapMaximize), for: .touchUpInside)
        playAlongButton.addTarget(self, action: #selector(didTapPlayAlong), for: .touchUpInside)
        animationButton.addTarget(self, action: #selector(didTapAnimation), for: .touchUpInside)
    }

    @objc private func didTapMaximize() {
        let vc = MaximizeUploadPageViewController()
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
            message: "Chord progression: \(extractedChords.joined(separator: " → "))\nTempo: \(tempo)",
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

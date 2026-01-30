//
//  UploadPageNextViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase
import PDFKit

final class UploadPageNextViewController: UIViewController {

    var uploadedImage: UIImage? {
        didSet { sheetImageView.image = uploadedImage }
    }
    
    // Properties to receive data from UploadScreen
    var scanId: Int64?
    var resultURL: String?
    var jobId: UUID?
    
    private var sheetMusicText: String = ""
    private var extractedChords: [String] = []
    private var timeSignature: String = "4/4"
    private var tempo: String = "120 BPM"
    private var keySignature: String = "C Major"
    private var sheetMusicJSON: [String: Any]?
    private var isProcessing = true
    private var pollingTimer: Timer?

    private let navBar = TopNavBar()

    private let pdfView = PDFView()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let sheetContainer = UIView()
    private let sheetHeaderLabel = UILabel()
    private let maximizeButton = UIButton(type: .system)
    private let sheetImageView = UIImageView()
    private let musicTextView = UITextView() // Text view for sheet music
    private let metronomeLabel = UILabel()
    private let progressView = UIProgressView()
    private let statusLabel = UILabel()
    
    private let infoStackView = UIStackView()
    private let keyLabel = UILabel()
    private let timeLabel = UILabel()
    private let chordLabel = UILabel()

    private let tipsContainer = UIView()
    private let tipsTitleLabel = UILabel()
    private let tipsBodyLabel = UILabel()

    private let playAlongButton = UIButton(type: .system)
    private let animationButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)
    
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
        let jsonData: [String: Any]?
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavBar()
        setupUI()
        buildHierarchy()
        applyConstraints()
        setupActions()
        
        print("UploadPageNextViewController loaded with scanId: \(String(describing: scanId)), resultURL: \(String(describing: resultURL))")
        
        // Show processing state initially
        showProcessingState()
        
        // Load data based on passed parameters
        if let resultURL = resultURL {
            loadDataFromResultURL(resultURL)
        } else if let scanId = scanId {
            loadDataFromScanId(scanId)
        } else {
            loadLatestJobFromDatabase()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop polling when leaving the screen
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
    
    // MARK: - Data Loading Methods
    
    private func loadDataFromResultURL(_ resultURL: String) {
        print("Loading data directly from result URL: \(resultURL)")
        self.resultURL = resultURL
        
        // Start polling for the result
        startPollingResultURL(resultURL)
    }
    
    private func startPollingResultURL(_ resultURL: String) {
        print("Starting to poll result URL...")
        
        // Show processing state
        DispatchQueue.main.async {
            self.showProcessingState()
        }
        
        // Start polling timer (every 5 seconds)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkResultURL(resultURL)
        }
        
        // First check immediately
        checkResultURL(resultURL)
    }
    
    private func checkResultURL(_ resultURL: String) {
        print("Checking result URL: \(resultURL)")
        
        Task {
            do {
                guard let url = URL(string: resultURL) else {
                    throw NSError(domain: "URLError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 10 // 10 second timeout
                
                // Make HEAD request first to check if file exists without downloading it
                request.httpMethod = "HEAD"
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "DownloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No response from server"])
                }
                
                print("HEAD request status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // File exists, now download it
                    await self.downloadAndParseResult(url: url)
                } else if httpResponse.statusCode == 404 {
                    // File not ready yet, continue polling
                    print("File not ready yet (404), continuing to poll...")
                    await self.updateProcessingStatus(message: "Processing your sheet music...\nThis may take up to 60 seconds.")
                } else {
                    print("Unexpected status code: \(httpResponse.statusCode)")
                    await self.updateProcessingStatus(message: "Processing... (Status: \(httpResponse.statusCode))")
                }
                
            } catch {
                print("Error checking result URL: \(error)")
                
                // Check if it's a timeout or connection error
                if (error as NSError).code == NSURLErrorTimedOut ||
                   (error as NSError).code == NSURLErrorCannotConnectToHost ||
                   (error as NSError).code == NSURLErrorNetworkConnectionLost {
                    
                    await MainActor.run {
                        self.updateProcessingStatus(message: "Connecting to server...")
                    }
                } else {
                    await MainActor.run {
                        self.updateProcessingStatus(message: "Processing...")
                    }
                }
            }
        }
    }
    
    private func downloadAndParseResult(url: URL) async {
        print("Downloading result from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "DownloadError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to download file"])
            }
            
            print("Successfully downloaded data, size: \(data.count) bytes")
            
            // Stop polling since we got the data
            await MainActor.run {
                self.pollingTimer?.invalidate()
                self.pollingTimer = nil
                self.isProcessing = false
                self.progressView.isHidden = true
                self.statusLabel.isHidden = true
                self.refreshButton.isHidden = true
            }
            
            // Parse JSON
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            // Extract chords and display
            if let json = json {
                await parseAndDisplayJSON(json)
            } else {
                // Try to parse as plain text
                if let text = String(data: data, encoding: .utf8) {
                    await MainActor.run {
                        self.extractedChords = self.extractChordsFromText(text)
                        self.displaySheetData(SheetMusicData(
                            text: text,
                            chords: self.extractedChords,
                            timeSignature: "4/4",
                            tempo: "120 BPM",
                            keySignature: "C Major",
                            jsonData: nil
                        ))
                    }
                }
            }
            
        } catch {
            print("Error downloading result: \(error)")
            await MainActor.run {
                self.showErrorState(error: "Failed to download processed data")
            }
        }
    }
    
    private func updateProcessingStatus(message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
        }
    }
    
    private func loadDataFromScanId(_ scanId: Int64) {
        print("Loading data from scan ID: \(scanId)")
        Task {
            do {
                // Fetch scan from database
                let scan: Scan = try await SupabaseManager.shared.client
                    .from("scans")
                    .select()
                    .eq("id", value: scanId as! PostgrestFilterValue)
                    .single()
                    .execute()
                    .value
                
                print("Found scan: \(scan.id)")
                
                // Extract result URL from JSON data
                if let jsonData = scan.jsonData?.value as? [String: Any],
                   let resultUrl = jsonData["result_url"] as? String {
                    print("Found result_url in scan: \(resultUrl)")
                    
                    // Load data from this URL
                    await MainActor.run {
                        self.loadDataFromResultURL(resultUrl)
                    }
                } else {
                    print("No result_url found in scan JSON")
                    await MainActor.run {
                        self.showSampleSheetMusic()
                    }
                }
                
            } catch {
                print("Error loading scan: \(error)")
                await MainActor.run {
                    self.showSampleSheetMusic()
                }
            }
        }
    }
    
    private func parseAndDisplayJSON(_ json: [String: Any]) async {
        print("Parsing JSON data...")
        
        // Store the JSON for later use
        self.sheetMusicJSON = json
        
        // Check if this is a queued response
        if let status = json["status"] as? String, status == "queued" {
            print("Job is still queued")
            await MainActor.run {
                self.updateProcessingStatus(message: "Job queued for processing...")
            }
            return
        }
        
        // Extract chords from JSON - this depends on your API response structure
        let chords = extractChordsFromJSON(json)
        print("Extracted chords: \(chords)")
        
        // Extract other metadata
        let timeSig = extractTimeSignature(json)
        let keySig = extractKeySignature(json)
        let tempoStr = extractTempo(json)
        
        // Create formatted text
        let formattedText = formatJSONForDisplay(json)
        
        await MainActor.run {
            self.displaySheetData(SheetMusicData(
                text: formattedText,
                chords: chords,
                timeSignature: timeSig,
                tempo: tempoStr,
                keySignature: keySig,
                jsonData: json
            ))
        }
    }
    
    private func extractChordsFromJSON(_ json: [String: Any]) -> [String] {
        var chords: [String] = []
        
        // Try different possible JSON structures
        if let chordsArray = json["chords"] as? [String] {
            chords = chordsArray
        } else if let chordsString = json["chords"] as? String {
            chords = chordsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else if let analysis = json["analysis"] as? [String: Any],
                  let detectedChords = analysis["chords"] as? [String] {
            chords = detectedChords
        } else if let scorePartwise = json["score-partwise"] as? [String: Any] {
            // MusicXML format - extract chords from measures
            chords = extractChordsFromMusicXML(scorePartwise)
        }
        
        // If no chords found, return sample chords
        if chords.isEmpty {
            chords = ["C", "G", "Am", "F"]
        }
        
        return chords
    }
    
    private func extractChordsFromMusicXML(_ scorePartwise: [String: Any]) -> [String] {
        var chords: [String] = []
        
        // Extract harmony elements from MusicXML
        if let part = scorePartwise["part"] as? [String: Any] {
            if let measures = parseMeasures(from: part) {
                for measure in measures {
                    if let harmonies = measure["harmony"] {
                        let measureChords = extractHarmonies(from: harmonies)
                        chords.append(contentsOf: measureChords)
                    }
                }
            }
        }
        
        return chords
    }
    
    private func extractHarmonies(from harmonies: Any) -> [String] {
        var chordNames: [String] = []
        
        if let harmonyArray = harmonies as? [[String: Any]] {
            for harmony in harmonyArray {
                if let root = harmony["root"] as? [String: Any],
                   let rootStep = root["root-step"] as? String {
                    var chordName = rootStep
                    
                    // Add root alter if present
                    if let rootAlter = root["root-alter"] as? String,
                       let alterValue = Int(rootAlter) {
                        if alterValue == 1 {
                            chordName += "♯"
                        } else if alterValue == -1 {
                            chordName += "♭"
                        }
                    }
                    
                    // Add kind (chord quality)
                    if let kind = harmony["kind"] as? String {
                        let kindMapping: [String: String] = [
                            "major": "",
                            "minor": "m",
                            "dominant": "7",
                            "major-seventh": "maj7",
                            "minor-seventh": "m7",
                            "diminished": "dim",
                            "augmented": "aug",
                            "sus4": "sus4"
                        ]
                        
                        if let quality = kindMapping[kind] {
                            chordName += quality
                        } else {
                            chordName += kind
                        }
                    }
                    
                    chordNames.append(chordName)
                }
            }
        } else if let harmony = harmonies as? [String: Any],
                  let root = harmony["root"] as? [String: Any],
                  let rootStep = root["root-step"] as? String {
            var chordName = rootStep
            
            if let rootAlter = root["root-alter"] as? String,
               let alterValue = Int(rootAlter) {
                if alterValue == 1 {
                    chordName += "♯"
                } else if alterValue == -1 {
                    chordName += "♭"
                }
            }
            
            if let kind = harmony["kind"] as? String {
                if kind == "minor" {
                    chordName += "m"
                }
            }
            
            chordNames.append(chordName)
        }
        
        return chordNames
    }
    
    private func extractChordsFromText(_ text: String) -> [String] {
        var chords: [String] = []
        
        // Common chord patterns in text
        let chordPatterns = [
            "C", "Cm", "C♯", "C♯m", "D", "Dm", "D♯", "D♯m",
            "E", "Em", "F", "Fm", "F♯", "F♯m", "G", "Gm",
            "G♯", "G♯m", "A", "Am", "A♯", "A♯m", "B", "Bm"
        ]
        
        for chord in chordPatterns {
            if text.contains(chord) {
                chords.append(chord)
            }
        }
        
        return chords.isEmpty ? ["C", "G", "Am", "F"] : chords
    }
    
    private func extractTimeSignature(_ json: [String: Any]) -> String {
        if let time = json["time_signature"] as? String {
            return time
        } else if let analysis = json["analysis"] as? [String: Any],
                  let time = analysis["time_signature"] as? String {
            return time
        } else if let scorePartwise = json["score-partwise"] as? [String: Any],
                  let part = scorePartwise["part"] as? [String: Any],
                  let measures = parseMeasures(from: part),
                  let firstMeasure = measures.first,
                  let attributes = firstMeasure["attributes"] as? [String: Any],
                  let time = attributes["time"] as? [String: Any] {
            
            if let beats = time["beats"] as? String,
               let beatType = time["beat-type"] as? String {
                return "\(beats)/\(beatType)"
            } else if let beats = time["beats"] as? Int,
                      let beatType = time["beat-type"] as? Int {
                return "\(beats)/\(beatType)"
            }
        }
        
        return "4/4"
    }
    
    private func extractKeySignature(_ json: [String: Any]) -> String {
        if let key = json["key_signature"] as? String {
            return key
        } else if let analysis = json["analysis"] as? [String: Any],
                  let key = analysis["key_signature"] as? String {
            return key
        } else if let scorePartwise = json["score-partwise"] as? [String: Any],
                  let part = scorePartwise["part"] as? [String: Any],
                  let measures = parseMeasures(from: part),
                  let firstMeasure = measures.first,
                  let attributes = firstMeasure["attributes"] as? [String: Any],
                  let key = attributes["key"] as? [String: Any],
                  let fifths = key["fifths"] as? String {
            
            let fifthsInt = Int(fifths) ?? 0
            let majorKeys = ["C", "G", "D", "A", "E", "B", "F♯", "C♯"]
            let minorKeys = ["Am", "Em", "Bm", "F♯m", "C♯m", "G♯m", "D♯m", "A♯m"]
            
            if fifthsInt >= 0 && fifthsInt < majorKeys.count {
                return majorKeys[fifthsInt]
            } else if fifthsInt < 0 && abs(fifthsInt) <= minorKeys.count {
                return minorKeys[abs(fifthsInt) - 1]
            }
        }
        
        return "C Major"
    }
    
    private func extractTempo(_ json: [String: Any]) -> String {
        if let tempo = json["tempo"] as? String {
            return tempo
        } else if let analysis = json["analysis"] as? [String: Any],
                  let tempo = analysis["tempo"] as? String {
            return tempo
        }
        
        return "120 BPM"
    }
    
    private func formatJSONForDisplay(_ json: [String: Any]) -> String {
        var result = "SHEET MUSIC ANALYSIS\n\n"
        
        // Add metadata
        result += "METADATA:\n"
        result += "• Time Signature: \(timeSignature)\n"
        result += "• Key: \(keySignature)\n"
        result += "• Tempo: \(tempo)\n"
        result += "• Chords: \(extractedChords.joined(separator: ", "))\n\n"
        
        // Add chords progression
        result += "CHORD PROGRESSION:\n"
        for (index, chord) in extractedChords.enumerated() {
            result += "  \(index + 1). \(chord)\n"
        }
        result += "\n"
        
        // Add structured data if available
        if let scorePartwise = json["score-partwise"] as? [String: Any] {
            result += "MUSICXML STRUCTURE:\n"
            if let partList = scorePartwise["part-list"] as? [String: Any],
               let scorePart = partList["score-part"] as? [String: Any],
               let partName = scorePart["part-name"] as? String {
                result += "• Instrument: \(partName)\n"
            }
            
            if let part = scorePartwise["part"] as? [String: Any],
               let measures = parseMeasures(from: part) {
                result += "• Measures: \(measures.count)\n"
                
                // Show first few measures
                let measuresToShow = min(3, measures.count)
                for i in 0..<measuresToShow {
                    if let notes = measures[i]["note"] {
                        let noteCount = countNotes(notes)
                        result += "  Measure \(i+1): \(noteCount) notes\n"
                    }
                }
            }
        } else {
            // Show JSON keys for debugging
            result += "DATA STRUCTURE:\n"
            for key in json.keys.prefix(10) {
                result += "• \(key)\n"
            }
            if json.keys.count > 10 {
                result += "• ... and \(json.keys.count - 10) more\n"
            }
        }
        
        return result
    }
    
    private func countNotes(_ notes: Any) -> Int {
        if let noteArray = notes as? [[String: Any]] {
            return noteArray.count
        } else if let _ = notes as? [String: Any] {
            return 1
        }
        return 0
    }
    
    // MARK: - Existing Methods (with minor updates)
    
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
                    
                    print("Found job: \(latestJob.id), status: \(latestJob.status), resultUrl: \(latestJob.resultUrl ?? "nil")")
                    
                    if let resultUrl = latestJob.resultUrl {
                        await MainActor.run {
                            self.loadDataFromResultURL(resultUrl)
                        }
                    } else {
                        await MainActor.run {
                            self.showSampleSheetMusic()
                        }
                    }
                } else {
                    print("No jobs found for user")
                    await MainActor.run {
                        self.showSampleSheetMusic()
                    }
                }
            } catch {
                print("Error loading job: \(error)")
                await MainActor.run {
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
    
    // MARK: - Scan Data Model
    struct Scan: Codable, Identifiable {
        let id: Int64
        let userId: UUID
        let jsonData: AnyCodable?
        let processingId: String?
        let status: String?
        let originalFilename: String?
        let fileType: String?
        let processedAt: String?
        let updatedAt: String?
        let errorMessage: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case jsonData = "json_data"
            case processingId = "processing_id"
            case status
            case originalFilename = "original_filename"
            case fileType = "file_type"
            case processedAt = "processed_at"
            case updatedAt = "updated_at"
            case errorMessage = "error_message"
        }
    }
    
    // MARK: - AnyCodable helper
    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let boolValue = try? container.decode(Bool.self) {
                value = boolValue
            } else if let intValue = try? container.decode(Int.self) {
                value = intValue
            } else if let doubleValue = try? container.decode(Double.self) {
                value = doubleValue
            } else if let stringValue = try? container.decode(String.self) {
                value = stringValue
            } else if let arrayValue = try? container.decode([AnyCodable].self) {
                value = arrayValue.map { $0.value }
            } else if let dictValue = try? container.decode([String: AnyCodable].self) {
                value = dictValue.mapValues { $0.value }
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch value {
            case let boolValue as Bool:
                try container.encode(boolValue)
            case let intValue as Int:
                try container.encode(intValue)
            case let doubleValue as Double:
                try container.encode(doubleValue)
            case let stringValue as String:
                try container.encode(stringValue)
            case let arrayValue as [Any]:
                let anyCodableArray = arrayValue.map { AnyCodable($0) }
                try container.encode(anyCodableArray)
            case let dictValue as [String: Any]:
                let anyCodableDict = dictValue.mapValues { AnyCodable($0) }
                try container.encode(anyCodableDict)
            default:
                let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value of type \(type(of: value))")
                throw EncodingError.invalidValue(value, context)
            }
        }
    }
    
    private func parseMeasures(from part: [String: Any]) -> [[String: Any]]? {
        if let measures = part["measure"] as? [[String: Any]] {
            return measures
        } else if let measure = part["measure"] as? [String: Any] {
            return [measure]
        }
        return nil
    }
    
    // MARK: - UI State Methods
    
    private func showProcessingState() {
        isProcessing = true
        
        sheetMusicText = """
        PROCESSING SHEET MUSIC
        
        Status: Analyzing your PDF
        Job ID: \(jobId?.uuidString ?? "Unknown")
        
        Please wait while we process your sheet music...
        This usually takes 30-60 seconds.
        
        Features being analyzed:
        • Chord detection
        • Time signature
        • Key signature
        • Note extraction
        
        Check back in a moment!
        """
        
        displaySheetMusic()
        metronomeLabel.text = "Metronome: Analyzing..."
        keyLabel.text = "Key: Analyzing..."
        timeLabel.text = "Time: Analyzing..."
        chordLabel.text = "Chords: Detecting..."
        
        progressView.isHidden = false
        statusLabel.isHidden = false
        refreshButton.isHidden = false
        
        // Start progress animation
        animateProgress()
        
        tipsBodyLabel.text = "• Processing usually takes 30-60 seconds\n• Results will appear automatically\n• Check back in a moment\n• Large files may take longer"
    }
    
    private func animateProgress() {
        UIView.animate(withDuration: 1.5, delay: 0, options: [.autoreverse, .repeat, .curveEaseInOut]) {
            self.progressView.setProgress(0.7, animated: true)
        }
    }
    
    private func displaySheetData(_ data: SheetMusicData) {
        sheetMusicText = data.text
        extractedChords = data.chords
        timeSignature = data.timeSignature
        tempo = data.tempo
        keySignature = data.keySignature
        sheetMusicJSON = data.jsonData
        
        displaySheetMusic()
        metronomeLabel.text = "Metronome: \(tempo)"
        keyLabel.text = "Key: \(keySignature)"
        timeLabel.text = "Time: \(timeSignature)"
        chordLabel.text = "Chords: \(extractedChords.joined(separator: ", "))"
        updatePracticeTips()
        
        // Hide progress when data is loaded
        progressView.isHidden = true
        statusLabel.isHidden = true
        refreshButton.isHidden = true
    }
    
    private func showErrorState(error: String) {
        sheetMusicText = """
        PROCESSING ERROR
        
        Status: Failed
        Error: \(error)
        
        Please try uploading the sheet again.
        Make sure the PDF is clear and well-lit.
        """
        
        displaySheetMusic()
        metronomeLabel.text = "Metronome: N/A"
        keyLabel.text = "Key: N/A"
        timeLabel.text = "Time: N/A"
        chordLabel.text = "Chords: N/A"
        
        progressView.isHidden = true
        statusLabel.text = "Failed to load data"
        refreshButton.isHidden = false
        
        tipsBodyLabel.text = "• Check your internet connection\n• Ensure the PDF is valid\n• Try uploading again\n• Contact support if problem persists"
    }
    
    private func showSampleSheetMusic() {
        sheetMusicText = """
        SHEET MUSIC ANALYSIS
        
        No sheet music data found.
        
        Upload sheet music to get chord analysis!
        
        Features:
        • Automatic chord detection
        • Time signature analysis
        • Practice tips
        • Play-along mode
        
        Sample Chord Progression:
        C → G → Am → F
        
        Try uploading your own sheet music!
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
        
        progressView.isHidden = true
        statusLabel.isHidden = true
        refreshButton.isHidden = true
        
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
        let sectionRegex = try! NSRegularExpression(pattern: "(SHEET MUSIC ANALYSIS|METADATA:|CHORD PROGRESSION:|MUSICXML STRUCTURE:|DATA STRUCTURE:|PROCESSING SHEET MUSIC|PROCESSING ERROR)", options: [])
        let sectionMatches = sectionRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in sectionMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor(red: 1, green: 0.8, blue: 0.4, alpha: 1)
            ], range: match.range)
        }
        
        // Highlight chords in the text
        let chordPattern = "\\b(C|G|Am|F|Dm|Em|A|D|E|Bm|C♯|D♯|F♯|G♯|A♯|Cm|C♯m|Dm|D♯m|Em|Fm|F♯m|Gm|G♯m|Am|A♯m|Bm)\\b"
        let chordRegex = try! NSRegularExpression(pattern: chordPattern, options: [])
        let chordMatches = chordRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in chordMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .bold),
                .foregroundColor: UIColor(red: 1, green: 0.6, blue: 0.8, alpha: 1),
                .backgroundColor: UIColor(red: 1, green: 0.6, blue: 0.8, alpha: 0.2)
            ], range: match.range)
        }
        
        // Highlight metadata labels
        let metaRegex = try! NSRegularExpression(pattern: "(Time Signature:|Key:|Tempo:|Chords:|Measures:|Instrument:|Status:|Job ID:|Error:)", options: [])
        let metaMatches = metaRegex.matches(in: sheetMusicText, options: [], range: NSRange(location: 0, length: sheetMusicText.count))
        
        for match in metaMatches {
            attributedText.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor(red: 0.8, green: 1, blue: 0.6, alpha: 1)
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
        refreshButton.addTarget(self, action: #selector(didTapRefresh), for: .touchUpInside)
    }
    
    @objc private func didTapRefresh() {
        print("Refresh button tapped")
        if let resultURL = resultURL {
            startPollingResultURL(resultURL)
        } else {
            loadLatestJobFromDatabase()
        }
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
        
        pdfView.autoScales = true
        pdfView.backgroundColor = .white
        pdfView.layer.cornerRadius = 20
        pdfView.clipsToBounds = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.isHidden = true

        
        musicTextView.isEditable = false
        musicTextView.isScrollEnabled = true
        musicTextView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        musicTextView.layer.cornerRadius = 12
        musicTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        musicTextView.showsVerticalScrollIndicator = false
        musicTextView.translatesAutoresizingMaskIntoConstraints = false
        
        // Progress View
        progressView.progressTintColor = UIColor(red: 1, green: 0.75, blue: 0.25, alpha: 1)
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        // Status Label
        statusLabel.text = "Processing your sheet music..."
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
        
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.setTitleColor(.white, for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        refreshButton.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 1, alpha: 1)
        refreshButton.layer.cornerRadius = 8
        refreshButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(sheetContainer)
        sheetContainer.addSubview(sheetHeaderLabel)
        sheetContainer.addSubview(maximizeButton)
        sheetContainer.addSubview(sheetImageView)
        sheetContainer.addSubview(pdfView)
        sheetContainer.addSubview(musicTextView)
        sheetContainer.addSubview(progressView)
        sheetContainer.addSubview(statusLabel)
        sheetContainer.addSubview(infoStackView)
        sheetContainer.addSubview(metronomeLabel)
        sheetContainer.addSubview(refreshButton)
        
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
            
            pdfView.topAnchor.constraint(equalTo: sheetHeaderLabel.bottomAnchor, constant: 20),
            pdfView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            pdfView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            pdfView.heightAnchor.constraint(equalToConstant: 180),

            musicTextView.topAnchor.constraint(equalTo: sheetImageView.bottomAnchor, constant: 16),
            musicTextView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            musicTextView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            musicTextView.heightAnchor.constraint(equalToConstant: 160),
            
            progressView.topAnchor.constraint(equalTo: musicTextView.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            
            refreshButton.centerYAnchor.constraint(equalTo: sheetHeaderLabel.centerYAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: maximizeButton.leadingAnchor, constant: -8),
            
            infoStackView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
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

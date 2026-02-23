//
//  UploadPageNextViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase
import PDFKit

final class UploadPageNextViewController: UIViewController {

    // Pass only jobId from the previous screen.
    // Everything else (pdf_path, output_url) is fetched from the DB.
    var jobId: UUID?
    var onDataReady: (() -> Void)?

    private var sheetMusicText: String = ""
    private var extractedChords: [String] = []
    private var timeSignature: String = "4/4"
    private var tempo: String = "120 BPM"
    private var keySignature: String = "C Major"
    private var sheetMusicJSON: [String: Any]?
    private var isProcessing = true
    private var pollingTimer: Timer?

    // MARK: - Nav
    private let navBar = TopNavBar()

    // MARK: - Scroll
    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    // MARK: - Sheet container
    private let sheetContainer   = UIView()
    private let sheetHeaderLabel = UILabel()
    private let previewButton    = UIButton(type: .system)

    // Sheet display
    private let pdfView               = PDFView()
    private let sheetImageView        = UIImageView()
    private let sheetLoadingIndicator = UIActivityIndicatorView(style: .medium)

    // Status
    private let metronomeLabel = UILabel()
    private let progressView   = UIProgressView()
    private let statusLabel    = UILabel()
    private let refreshButton  = UIButton(type: .system)

    private let infoStackView = UIStackView()
    private let keyLabel      = UILabel()
    private let timeLabel     = UILabel()
    private let chordLabel    = UILabel()

    // Tips
    private let tipsContainer  = UIView()
    private let tipsTitleLabel = UILabel()
    private let tipsBodyLabel  = UILabel()

    // Action buttons
    private let playAlongButton = UIButton(type: .system)
    private let animationButton = UIButton(type: .system)

    // MARK: - Data Models
    struct Job: Codable, Identifiable {
        let id: UUID; let userId: UUID; let pdfPath: String
        let resultUrl: String?; let status: String
        let errorMessage: String?; let createdAt: Date; let updatedAt: Date
        enum CodingKeys: String, CodingKey {
            case id; case userId = "user_id"; case pdfPath = "pdf_path"
            case resultUrl = "result_url"; case status
            case errorMessage = "error_message"
            case createdAt = "created_at"; case updatedAt = "updated_at"
        }
    }

    struct SheetMusicData {
        let text: String; let chords: [String]
        let timeSignature: String; let tempo: String
        let keySignature: String; let jsonData: [String: Any]?
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1.0)

        setupNavBar(); setupUI(); buildHierarchy(); applyConstraints(); setupActions()
        showProcessingState()

        print("[VDL] jobId=\(jobId?.uuidString ?? "nil")")

        loadFromJobId()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let doc = pdfView.document, !pdfView.isHidden {
            if let p = doc.page(at: 0) { pdfView.go(to: p) }
            pdfView.layoutIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pollingTimer?.invalidate(); pollingTimer = nil
    }

    deinit { pollingTimer?.invalidate() }

    // MARK: - Data Loading

    private func loadFromJobId() {
        guard let jobId else {
            print("[Load] ❌ No jobId — cannot load anything")
            showSampleSheetMusic()
            return
        }
        Task { await fetchJobAndLoad(jobId: jobId) }
    }

    private func fetchJobAndLoad(jobId: UUID) async {
        struct JobRow: Decodable {
            let pdfPath: String
            let resultUrl: String?
            enum CodingKeys: String, CodingKey {
                case pdfPath = "pdf_path"; case resultUrl = "result_url"
            }
        }

        do {
            let rows: [JobRow] = try await SupabaseManager.shared.client
                .from("jobs")
                .select("pdf_path, result_url")
                .eq("id", value: jobId)
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else {
                print("[Load] ❌ No job found for jobId=\(jobId)")
                await MainActor.run { self.showSampleSheetMusic() }
                return
            }

            print("[Load] pdf_path=\(row.pdfPath)  result_url=\(row.resultUrl ?? "nil")")

            // Build PDF public URL via Supabase SDK — no manual string construction.
            guard let pdfURL = try? SupabaseManager.shared.client.storage
                    .from("pdf_uploads")
                    .getPublicURL(path: row.pdfPath) else {
                print("[Load] ❌ Failed to build public URL for path=\(row.pdfPath)")
                await MainActor.run { self.showSampleSheetMusic() }
                return
            }

            print("[Load] pdfURL=\(pdfURL.absoluteString)")

            await MainActor.run { self.loadSheetPDF(from: pdfURL.absoluteString) }

            // Poll the output JSON using result_url from DB.
            if let resultUrl = row.resultUrl, !resultUrl.isEmpty {
                await MainActor.run { self.startPollingResultURL(resultUrl) }
            } else {
                // Fallback: derive from known sheet_data path structure.
                let derived = deriveOutputURL(jobId: jobId, pdfPath: row.pdfPath)
                print("[Load] No result_url in DB — using derived: \(derived)")
                await MainActor.run { self.startPollingResultURL(derived) }
            }

        } catch {
            print("[Load] ❌ DB error: \(error)")
            await MainActor.run { self.showSampleSheetMusic() }
        }
    }

    /// Derives the output JSON URL from the known sheet_data/{userId}/{jobId}/output.json structure.
    private func deriveOutputURL(jobId: UUID, pdfPath: String) -> String {
        let parts = pdfPath.components(separatedBy: "/")
        let userId = parts.first ?? jobId.uuidString
        let projectID = "djqgmowfjxsnjdffdohw"
        return "https://\(projectID).supabase.co/storage/v1/object/public/sheet_data/\(userId)/\(jobId.uuidString.lowercased())/output.json"
    }

    // MARK: - PDF Display

    private func loadSheetPDF(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("[PDF] ❌ Invalid URL: \(urlString)"); return
        }
        print("[PDF] 🔄 Loading: \(urlString)")

        sheetLoadingIndicator.startAnimating()
        pdfView.isHidden = true

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[PDF] HTTP \(code)  bytes=\(data.count)")

                guard (200...299).contains(code) else {
                    let body = String(data: data, encoding: .utf8) ?? "<binary>"
                    print("[PDF] ❌ HTTP \(code): \(body)")
                    await MainActor.run {
                        self.sheetLoadingIndicator.stopAnimating()
                        self.statusLabel.text = "PDF unavailable (HTTP \(code)). Check Supabase Storage."
                        self.statusLabel.isHidden  = false
                        self.refreshButton.isHidden = false
                    }
                    return
                }

                await MainActor.run {
                    self.sheetLoadingIndicator.stopAnimating()
                    self.handlePDFData(data)
                }
            } catch {
                print("[PDF] ❌ Network error: \(error.localizedDescription)")
                await MainActor.run {
                    self.sheetLoadingIndicator.stopAnimating()
                    self.statusLabel.text = "Network error. Tap Refresh to retry."
                    self.statusLabel.isHidden  = false
                    self.refreshButton.isHidden = false
                }
            }
        }
    }

    private func handlePDFData(_ data: Data) {
        if let pdfDoc = PDFDocument(data: data), pdfDoc.pageCount > 0 {
            print("[PDF] ✅ Valid PDF — pages=\(pdfDoc.pageCount)")
            pdfView.document = pdfDoc
            pdfView.isHidden = false
            pdfView.layoutIfNeeded()
            if let p = pdfDoc.page(at: 0) { pdfView.go(to: p) }
        } else {
            print("[PDF] ❌ Not a valid PDF")
            statusLabel.text       = "Could not display sheet. Tap Refresh to retry."
            statusLabel.isHidden   = false
            refreshButton.isHidden = false
        }
    }

    // MARK: - Output JSON Polling

    private func startPollingResultURL(_ url: String) {
        showProcessingState()
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkResultURL(url)
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
        checkResultURL(url)
    }

    private func checkResultURL(_ urlString: String) {
        Task {
            guard let url = URL(string: urlString) else { return }
            do {
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                req.setValue("bytes=0-0", forHTTPHeaderField: "Range")
                req.timeoutInterval = 10
                let (_, response) = try await URLSession.shared.data(for: req)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 || code == 206 {
                    await downloadAndParseResult(url: url)
                } else {
                    await MainActor.run { self.updateProcessingStatus(message: "Processing…") }
                }
            } catch {
                await MainActor.run { self.updateProcessingStatus(message: "Processing…") }
            }
        }
    }

    private func downloadAndParseResult(url: URL) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return }

            if let preview = String(data: data.prefix(500), encoding: .utf8) {
                print("[Result] JSON preview:\n\(preview)")
            }

            await MainActor.run {
                self.pollingTimer?.invalidate(); self.pollingTimer = nil
                self.isProcessing       = false
                self.progressView.isHidden  = true
                self.statusLabel.isHidden   = true
                self.refreshButton.isHidden = true
                self.onDataReady?()
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("[Result] Keys: \(json.keys.sorted())")
                await parseAndDisplayJSON(json)
            }
        } catch {
            await MainActor.run { self.showErrorState(error: "Failed to download result") }
        }
    }

    private func parseAndDisplayJSON(_ json: [String: Any]) async {
        if let status = json["status"] as? String, status == "queued" {
            await MainActor.run { self.updateProcessingStatus(message: "Job queued…") }; return
        }

        let chords   = extractChordsFromJSON(json)
        let timeSig  = extractTimeSignature(json)
        let keySig   = extractKeySignature(json)
        let tempoStr = extractTempo(json)

        print("[ParseJSON] chords=\(chords.count) \(Array(chords.prefix(4)))")

        await MainActor.run {
            self.displaySheetData(SheetMusicData(
                text: "", chords: chords, timeSignature: timeSig,
                tempo: tempoStr, keySignature: keySig, jsonData: json))
        }
    }

    // MARK: - Extraction Helpers

    private func extractChordsFromJSON(_ json: [String: Any]) -> [String] {
        if let a = json["chords"] as? [String], !a.isEmpty { return a }
        if let s = json["chords"] as? String {
            let p = s.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !p.isEmpty { return p }
        }
        if let a = (json["analysis"] as? [String: Any])?["chords"] as? [String], !a.isEmpty { return a }
        if let sp = json["score-partwise"] as? [String: Any] {
            let xml = extractChordsFromMusicXML(sp)
            return xml.isEmpty ? deriveChordsFallback(from: sp) : xml
        }
        return ["C", "G", "Am", "F"]
    }

    private func extractChordsFromMusicXML(_ sp: [String: Any]) -> [String] {
        var chords: [String] = []
        let parts: [[String: Any]]
        if let arr = sp["part"] as? [[String: Any]]  { parts = arr }
        else if let d = sp["part"] as? [String: Any] { parts = [d] }
        else                                         { parts = [] }
        for part in parts {
            let measures: [[String: Any]]
            if let arr = part["measure"] as? [[String: Any]]   { measures = arr }
            else if let d = part["measure"] as? [String: Any]  { measures = [d] }
            else                                               { continue }
            for m in measures { if let h = m["harmony"] { chords += extractHarmonies(from: h) } }
        }
        return chords
    }

    private func deriveChordsFallback(from sp: [String: Any]) -> [String] {
        let parts: [[String: Any]]
        if let arr = sp["part"] as? [[String: Any]]  { parts = arr }
        else if let d = sp["part"] as? [String: Any] { parts = [d] }
        else                                         { return ["C","G","Am","F"] }
        var count = 0
        for part in parts {
            if let arr = part["measure"] as? [[String: Any]]  { count = max(count, arr.count) }
            else if part["measure"] as? [String: Any] != nil  { count = max(count, 1) }
        }
        guard count > 0 else { return ["C","G","Am","F"] }
        let cycle = ["C","G","Am","F","Dm","G","Em","Am"]
        return (0..<count).map { cycle[$0 % cycle.count] }
    }

    private func extractHarmonies(from harmonies: Any) -> [String] {
        var names: [String] = []
        let process: ([String: Any]) -> Void = { h in
            guard let root = h["root"] as? [String: Any], let step = root["root-step"] as? String else { return }
            var name = step
            if let alter = root["root-alter"] as? String, let v = Int(alter) {
                name += v == 1 ? "♯" : (v == -1 ? "♭" : "")
            }
            let map = ["major":"","minor":"m","dominant":"7","major-seventh":"maj7",
                       "minor-seventh":"m7","diminished":"dim","augmented":"aug","sus4":"sus4"]
            if let kind = h["kind"] as? String { name += map[kind] ?? kind }
            names.append(name)
        }
        if let arr = harmonies as? [[String: Any]] { arr.forEach(process) }
        else if let d = harmonies as? [String: Any] { process(d) }
        return names
    }

    private func extractTimeSignature(_ json: [String: Any]) -> String {
        if let t = json["time_signature"] as? String { return t }
        if let t = (json["analysis"] as? [String: Any])?["time_signature"] as? String { return t }
        if let sp = json["score-partwise"] as? [String: Any] {
            let parts: [[String: Any]]
            if let arr = sp["part"] as? [[String: Any]]  { parts = arr }
            else if let d = sp["part"] as? [String: Any] { parts = [d] }
            else                                         { parts = [] }
            for part in parts {
                let measures: [[String: Any]]
                if let arr = part["measure"] as? [[String: Any]]  { measures = arr }
                else if let d = part["measure"] as? [String: Any] { measures = [d] }
                else                                              { continue }
                if let attrs = measures.first?["attributes"] as? [String: Any],
                   let time = attrs["time"] as? [String: Any] {
                    let b  = (time["beats"] as? String)     ?? "\(time["beats"] ?? "4")"
                    let bt = (time["beat-type"] as? String) ?? "\(time["beat-type"] ?? "4")"
                    return "\(b)/\(bt)"
                }
            }
        }
        return "4/4"
    }

    private func extractKeySignature(_ json: [String: Any]) -> String {
        if let k = json["key_signature"] as? String { return k }
        if let k = (json["analysis"] as? [String: Any])?["key_signature"] as? String { return k }
        return "C Major"
    }

    private func extractTempo(_ json: [String: Any]) -> String {
        if let t = json["tempo"] as? String { return t }
        if let t = (json["analysis"] as? [String: Any])?["tempo"] as? String { return t }
        return "120 BPM"
    }

    // MARK: - UI State

    private func updateProcessingStatus(message: String) {
        DispatchQueue.main.async { self.statusLabel.text = message }
    }

    private func showProcessingState() {
        isProcessing = true
        metronomeLabel.text = "Metronome: Analyzing..."
        keyLabel.text = "Key: –"; timeLabel.text = "Time: –"; chordLabel.text = "Chords: –"
        progressView.isHidden = false; statusLabel.isHidden = false; refreshButton.isHidden = false
        animateProgress()
        tipsBodyLabel.text = "• Processing usually takes 30–60 seconds\n• Results will appear automatically"
    }

    private func animateProgress() {
        UIView.animate(withDuration: 1.5, delay: 0,
                       options: [.autoreverse, .repeat, .curveEaseInOut]) {
            self.progressView.setProgress(0.7, animated: true)
        }
    }

    private func displaySheetData(_ data: SheetMusicData) {
        sheetMusicText  = data.text; extractedChords = data.chords
        timeSignature   = data.timeSignature; tempo = data.tempo
        keySignature    = data.keySignature; sheetMusicJSON = data.jsonData

        let bpm = tempo.components(separatedBy: " ").first ?? "120"
        metronomeLabel.text = "Metronome on \(bpm) BPM"
        keyLabel.text   = "Key: \(keySignature)"
        timeLabel.text  = "Time: \(timeSignature)"
        chordLabel.text = "Chords: \(extractedChords.prefix(4).joined(separator: ", "))"
        updatePracticeTips()
        progressView.isHidden = true; statusLabel.isHidden = true; refreshButton.isHidden = true
    }

    private func showErrorState(error: String) {
        metronomeLabel.text = "Metronome: N/A"
        keyLabel.text = "Key: N/A"; timeLabel.text = "Time: N/A"; chordLabel.text = "Chords: N/A"
        progressView.isHidden = true
        statusLabel.text = "Failed to load data"; statusLabel.isHidden = false; refreshButton.isHidden = false
    }

    private func showSampleSheetMusic() {
        extractedChords = ["C", "G", "Am", "F"]; timeSignature = "4/4"; tempo = "120 BPM"; keySignature = "C Major"
        displaySheetData(SheetMusicData(text: "", chords: extractedChords,
                                        timeSignature: timeSignature, tempo: tempo,
                                        keySignature: keySignature, jsonData: nil))
        sheetHeaderLabel.text = "Right hand focus"
        progressView.isHidden = true; statusLabel.isHidden = true; refreshButton.isHidden = true
        onDataReady?()
    }

    private func updatePracticeTips() {
        var tips = ""
        if timeSignature == "3/4" { tips += "• Count aloud: 1-2-3 for waltz feel\n" }
        if timeSignature == "6/8" { tips += "• Feel in 2: 1-2-3, 4-5-6\n" }
        tips += "• Keep wrists relaxed and fingers curved.\n• Listen for even timing between notes."
        tipsBodyLabel.text = tips
    }

    // MARK: - Actions

    private func setupActions() {
        previewButton.addTarget(self,   action: #selector(didTapPreview),   for: .touchUpInside)
        playAlongButton.addTarget(self, action: #selector(didTapPlayAlong), for: .touchUpInside)
        animationButton.addTarget(self, action: #selector(didTapAnimation), for: .touchUpInside)
        refreshButton.addTarget(self,   action: #selector(didTapRefresh),   for: .touchUpInside)
    }

    @objc private func didTapRefresh() { loadFromJobId() }

    @objc private func didTapPreview() {
        let vc = MaximizeUploadPageViewController()
        vc.sheetMusicText = sheetMusicText
        vc.modalPresentationStyle = .fullScreen; present(vc, animated: true)
    }

    @objc private func didTapPlayAlong() {
        let a = UIAlertController(title: "Play Along",
                                  message: "Chords: \(extractedChords.joined(separator: " - "))\nTempo: \(tempo)",
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Start", style: .default) { _ in self.startPlayAlong() })
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(a, animated: true)
    }

    private func startPlayAlong() {
        let a = UIAlertController(title: "Playing…",
                                  message: "\(extractedChords.joined(separator: " → "))\n\(tempo)",
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Stop", style: .destructive))
        present(a, animated: true)
    }

    @objc private func didTapAnimation() {
        if isProcessing { showAnimationError("Still processing. Please wait."); return }
        guard let json = sheetMusicJSON else {
            showAnimationError("No sheet music data available."); return
        }
        navigateToAnimation(withJSON: json)
    }

    private func navigateToAnimation(withJSON json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            showAnimationError("Failed to prepare data."); return
        }
        let vc = PianoAnimationViewController(); vc.sheetMusicData = data
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showAnimationError(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default)); present(a, animated: true)
    }

    // MARK: - UI Setup

    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isBackButtonVisible = true; navBar.isChordIconVisible = true
        navBar.isProfileVisible = true; navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true; navBar.setTitle("Practice")
        navBar.backAction    = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        navBar.chordAction   = { [weak self] in self?.navigationController?.pushViewController(ChordRecognitionViewController(), animated: true) }
        navBar.profileAction = { [weak self] in self?.navigationController?.pushViewController(UserProfileViewController(), animated: true) }
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false; scrollView.alwaysBounceVertical = true
        contentView.translatesAutoresizingMaskIntoConstraints = false

        sheetContainer.backgroundColor = UIColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1.0)
        sheetContainer.layer.cornerRadius = 24; sheetContainer.translatesAutoresizingMaskIntoConstraints = false

        sheetHeaderLabel.text = "Right hand focus"
        sheetHeaderLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        sheetHeaderLabel.textColor = .label; sheetHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        var previewConfig = UIButton.Configuration.filled()
        previewConfig.title = "Preview"; previewConfig.baseForegroundColor = .white
        previewConfig.baseBackgroundColor = UIColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 1.0)
        previewConfig.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18)
        previewConfig.cornerStyle = .fixed
        previewConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var o = incoming; o.font = UIFont.systemFont(ofSize: 14, weight: .semibold); return o
        }
        previewButton.configuration = previewConfig
        previewButton.layer.cornerRadius = 16; previewButton.clipsToBounds = true
        previewButton.translatesAutoresizingMaskIntoConstraints = false

        pdfView.autoScales = true; pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1.0)
        pdfView.layer.cornerRadius = 14; pdfView.clipsToBounds = false
        pdfView.minScaleFactor = 0.1; pdfView.maxScaleFactor = 5.0
        pdfView.isHidden = true; pdfView.translatesAutoresizingMaskIntoConstraints = false

        sheetImageView.contentMode = .scaleAspectFit; sheetImageView.clipsToBounds = true
        sheetImageView.layer.cornerRadius = 14
        sheetImageView.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1.0)
        sheetImageView.isHidden = true  // PDF is always loaded from DB — no passed image
        sheetImageView.translatesAutoresizingMaskIntoConstraints = false

        sheetLoadingIndicator.color = UIColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 1.0)
        sheetLoadingIndicator.hidesWhenStopped = true; sheetLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        progressView.progressTintColor = UIColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 1.0)
        progressView.trackTintColor = UIColor.secondaryLabel.withAlphaComponent(0.2)
        progressView.layer.cornerRadius = 3; progressView.clipsToBounds = true
        progressView.isHidden = true; progressView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = "Processing your sheet music..."
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .secondaryLabel; statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0; statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.setTitleColor(UIColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 1.0), for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        refreshButton.isHidden = true; refreshButton.translatesAutoresizingMaskIntoConstraints = false

        infoStackView.axis = .horizontal; infoStackView.spacing = 10
        infoStackView.distribution = .fillEqually; infoStackView.translatesAutoresizingMaskIntoConstraints = false
        for lbl in [keyLabel, timeLabel, chordLabel] {
            lbl.font = .systemFont(ofSize: 12, weight: .medium)
            lbl.textColor = .secondaryLabel; lbl.textAlignment = .center
            lbl.backgroundColor = .white; lbl.layer.cornerRadius = 8; lbl.clipsToBounds = true
            lbl.numberOfLines = 2; infoStackView.addArrangedSubview(lbl)
        }
        keyLabel.text = "Key: C Major"; timeLabel.text = "Time: 4/4"; chordLabel.text = "Chords: –"

        metronomeLabel.text = "Metronome on 120 BPM"
        metronomeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        metronomeLabel.textColor = .secondaryLabel; metronomeLabel.textAlignment = .right
        metronomeLabel.translatesAutoresizingMaskIntoConstraints = false

        tipsContainer.backgroundColor = UIColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1.0)
        tipsContainer.layer.cornerRadius = 20; tipsContainer.translatesAutoresizingMaskIntoConstraints = false

        tipsTitleLabel.text = "Tips"; tipsTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        tipsTitleLabel.textColor = .label; tipsTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        tipsBodyLabel.text = "Keep wrists relaxed and fingers curved.\nListen for even timing."
        tipsBodyLabel.numberOfLines = 0; tipsBodyLabel.font = .systemFont(ofSize: 15)
        tipsBodyLabel.textColor = .label; tipsBodyLabel.translatesAutoresizingMaskIntoConstraints = false

        var playConfig = UIButton.Configuration.filled()
        playConfig.title = "Play Along"; playConfig.baseForegroundColor = .white
        playConfig.baseBackgroundColor = UIColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 1.0)
        playConfig.cornerStyle = .capsule; playAlongButton.configuration = playConfig
        playAlongButton.translatesAutoresizingMaskIntoConstraints = false

        var animConfig = UIButton.Configuration.filled()
        animConfig.title = "Animation"; animConfig.baseForegroundColor = .label
        animConfig.baseBackgroundColor = UIColor(red: 0.90, green: 0.89, blue: 0.87, alpha: 1.0)
        animConfig.cornerStyle = .capsule; animationButton.configuration = animConfig
        animationButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildHierarchy() {
        view.addSubview(scrollView); scrollView.addSubview(contentView)
        contentView.addSubview(sheetContainer)
        sheetContainer.addSubview(sheetHeaderLabel); sheetContainer.addSubview(previewButton)
        sheetContainer.addSubview(pdfView); sheetContainer.addSubview(sheetImageView)
        sheetContainer.addSubview(sheetLoadingIndicator)
        sheetContainer.addSubview(progressView); sheetContainer.addSubview(statusLabel)
        sheetContainer.addSubview(refreshButton); sheetContainer.addSubview(infoStackView)
        sheetContainer.addSubview(metronomeLabel)
        contentView.addSubview(tipsContainer)
        tipsContainer.addSubview(tipsTitleLabel); tipsContainer.addSubview(tipsBodyLabel)
        contentView.addSubview(playAlongButton); contentView.addSubview(animationButton)
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
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            sheetContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            sheetHeaderLabel.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 18),
            sheetHeaderLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 18),
            previewButton.centerYAnchor.constraint(equalTo: sheetHeaderLabel.centerYAnchor),
            previewButton.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),

            pdfView.topAnchor.constraint(equalTo: sheetHeaderLabel.bottomAnchor, constant: 14),
            pdfView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 12),
            pdfView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -12),
            pdfView.heightAnchor.constraint(equalToConstant: 400),

            sheetImageView.topAnchor.constraint(equalTo: sheetHeaderLabel.bottomAnchor, constant: 14),
            sheetImageView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 12),
            sheetImageView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -12),
            sheetImageView.heightAnchor.constraint(equalToConstant: 400),

            sheetLoadingIndicator.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            sheetLoadingIndicator.topAnchor.constraint(equalTo: sheetHeaderLabel.bottomAnchor, constant: 200),

            progressView.topAnchor.constraint(equalTo: pdfView.bottomAnchor, constant: 10),
            progressView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 4),

            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),

            refreshButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 6),
            refreshButton.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),

            infoStackView.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 10),
            infoStackView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 16),
            infoStackView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),
            infoStackView.heightAnchor.constraint(equalToConstant: 36),

            metronomeLabel.topAnchor.constraint(equalTo: infoStackView.bottomAnchor, constant: 12),
            metronomeLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -18),
            metronomeLabel.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -16),

            tipsContainer.topAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: 16),
            tipsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tipsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tipsTitleLabel.topAnchor.constraint(equalTo: tipsContainer.topAnchor, constant: 18),
            tipsTitleLabel.leadingAnchor.constraint(equalTo: tipsContainer.leadingAnchor, constant: 18),
            tipsBodyLabel.topAnchor.constraint(equalTo: tipsTitleLabel.bottomAnchor, constant: 8),
            tipsBodyLabel.leadingAnchor.constraint(equalTo: tipsContainer.leadingAnchor, constant: 18),
            tipsBodyLabel.trailingAnchor.constraint(equalTo: tipsContainer.trailingAnchor, constant: -18),
            tipsBodyLabel.bottomAnchor.constraint(equalTo: tipsContainer.bottomAnchor, constant: -18),

            playAlongButton.topAnchor.constraint(equalTo: tipsContainer.bottomAnchor, constant: 24),
            playAlongButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            playAlongButton.heightAnchor.constraint(equalToConstant: 54),
            animationButton.centerYAnchor.constraint(equalTo: playAlongButton.centerYAnchor),
            animationButton.leadingAnchor.constraint(equalTo: playAlongButton.trailingAnchor, constant: 12),
            animationButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            animationButton.heightAnchor.constraint(equalToConstant: 54),
            animationButton.widthAnchor.constraint(equalTo: playAlongButton.widthAnchor),
            animationButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
        ])
    }
}

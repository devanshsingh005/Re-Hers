//
//  UploadPageNextViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase
import PDFKit

final class UploadPageNextViewController: UIViewController {

    // Set jobId from the previous screen.
    // Optionally set resultURL to skip the DB round-trip for the output JSON URL
    // (when the caller already has it, e.g. from scan.jsonData["output_url"]).
    var jobId:     UUID?
    var resultURL: String?          // ← NEW: drives JSON fetch + animation
    var onDataReady: (() -> Void)?

    private var sheetMusicText:   String       = ""
    private var extractedChords:  [String]     = []
    private var timeSignature:    String       = "4/4"
    private var tempo:            String       = "120 BPM"
    private var keySignature:     String       = "C Major"
    private var sheetMusicJSON:   [String: Any]?
    private var isProcessing      = true
    private var pollingTimer:     Timer?
    private var processingHeightConstraint: NSLayoutConstraint?
    private var statusHeightConstraint:     NSLayoutConstraint?
    private var refreshHeightConstraint:    NSLayoutConstraint?
    private var loadedPDFDocument: PDFDocument? // stored for full-screen preview
    private var pendingPDFPath:   String?       // raw pdf_path from DB, used after processing

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
    struct SheetMusicData {
        let text: String; let chords: [String]
        let timeSignature: String; let tempo: String
        let keySignature: String; let jsonData: [String: Any]?
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.App.screenBackground
        setupNavBar(); setupUI(); buildHierarchy(); applyConstraints(); setupActions()
        showProcessingState()
        print("[VDL] jobId=\(jobId?.uuidString ?? "nil")  resultURL=\(resultURL ?? "nil")")
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
            print("[Load] ❌ No jobId — showing sample")
            showSampleSheetMusic()
            return
        }
        Task { await fetchJobAndLoad(jobId: jobId) }
    }

    private func fetchJobAndLoad(jobId: UUID) async {
        struct JobRow: Decodable {
            let pdfPath:   String
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

            print("[Load] pdf_path=\(row.pdfPath)  db_result_url=\(row.resultUrl ?? "nil")")

            // Store path — PDF loads only after processing completes (labeled if ready, else input)
            self.pendingPDFPath = row.pdfPath

            // Determine effective result URL
            let _: String
            if let preSupplied = self.resultURL, !preSupplied.isEmpty {
                print("[Load] ✅ Using pre-supplied resultURL: \(preSupplied)")
                _ = preSupplied
            } else if let dbURL = row.resultUrl, !dbURL.isEmpty {
                print("[Load] Using DB result_url: \(dbURL)")
                _ = dbURL
            } else {
                let derived = deriveOutputURL(jobId: jobId, pdfPath: row.pdfPath)
                print("[Load] No result_url — using derived: \(derived)")
                _ = derived
            }

            // Start polling job status — backend owns all transitions
            await MainActor.run { self.startPollingJobStatus() }

        } catch {
            print("[Load] ❌ DB error: \(error)")
            await MainActor.run { self.showSampleSheetMusic() }
        }
    }

    /// Derives the output JSON URL from the known sheet_data/{userId}/{jobId}/output.json structure.
    private func deriveOutputURL(jobId: UUID, pdfPath: String) -> String {
        let userId    = pdfPath.components(separatedBy: "/").first ?? jobId.uuidString
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
                var pdfReq = URLRequest(url: url)
                pdfReq.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: pdfReq)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[PDF] HTTP \(code)  bytes=\(data.count)")

                guard (200...299).contains(code) else {
                    let body = String(data: data, encoding: .utf8) ?? "<binary>"
                    print("[PDF] ❌ HTTP \(code): \(body)")
                    await MainActor.run {
                        self.sheetLoadingIndicator.stopAnimating()
                        self.statusLabel.text      = "PDF unavailable (HTTP \(code))."
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
                    self.statusLabel.text      = "Network error. Tap Refresh to retry."
                    self.statusLabel.isHidden  = false
                    self.refreshButton.isHidden = false
                }
            }
        }
    }

    private func handlePDFData(_ data: Data) {
        if let pdfDoc = PDFDocument(data: data), pdfDoc.pageCount > 0 {
            print("[PDF] ✅ Valid PDF — pages=\(pdfDoc.pageCount)")
            loadedPDFDocument   = pdfDoc
            pdfView.document    = pdfDoc
            pdfView.isHidden    = false
            pdfView.layoutIfNeeded()
            if let p = pdfDoc.page(at: 0) { pdfView.go(to: p) }
        } else {
            print("[PDF] ❌ Not a valid PDF")
            statusLabel.text       = "Could not display sheet. Tap Refresh to retry."
            statusLabel.isHidden   = false
            refreshButton.isHidden = false
        }
    }

    // MARK: - Job Status Polling

    private static let maxPollAttempts = 24   // 24 × 5 s = 2 min max
    private var pollAttempts = 0

    /// Polls the jobs table every 5 s. Proceeds only when the backend sets
    /// status = 'completed' or 'completed_with_warning', guaranteeing that
    /// labeled.pdf is already saved before we try to load it.
    private func startPollingJobStatus() {
        guard let jobId else { return }
        showProcessingState()
        pollAttempts = 0
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.pollAttempts += 1
            if self.pollAttempts >= Self.maxPollAttempts {
                self.pollingTimer?.invalidate(); self.pollingTimer = nil
                DispatchQueue.main.async {
                    self.statusLabel.text       = "Processing timed out. Tap Refresh to retry."
                    self.statusLabel.isHidden   = false
                    self.refreshButton.isHidden = false
                    self.progressView.isHidden  = true
                }
                return
            }
            Task { await self.pollJobStatus(jobId: jobId) }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
        Task { await pollJobStatus(jobId: jobId) }  // immediate first check
    }

    private func pollJobStatus(jobId: UUID) async {
        struct StatusRow: Decodable {
            let status: String
            let resultUrl: String?
            enum CodingKeys: String, CodingKey {
                case status
                case resultUrl = "result_url"
            }
        }
        do {
            let rows: [StatusRow] = try await SupabaseManager.shared.client
                .from("jobs").select("status, result_url")
                .eq("id", value: jobId).limit(1).execute().value
            guard let row = rows.first else { return }
            switch row.status {
            case "completed", "completed_with_warning":
                pollingTimer?.invalidate(); pollingTimer = nil
                await handleJobCompleted(resultUrl: row.resultUrl)
            case "failed":
                pollingTimer?.invalidate(); pollingTimer = nil
                await MainActor.run {
                    self.statusLabel.text       = "Processing failed. Tap Refresh to retry."
                    self.statusLabel.isHidden   = false
                    self.refreshButton.isHidden = false
                    self.progressView.isHidden  = true
                }
            case "processing":
                await MainActor.run { self.updateProcessingStatus(message: "Processing…") }
            default:
                await MainActor.run { self.updateProcessingStatus(message: "Job queued…") }
            }
        } catch {
            print("[Poll] ⚠️ DB error: \(error.localizedDescription)")
        }
    }

    /// Called once the backend marks the job complete. By this point labeled.pdf
    /// is guaranteed to be in sheet_data storage (same public bucket as output.json).
    /// result_url from the DB is "sheet_data/{user_id}/{job_id}/labeled.pdf" —
    /// we just prepend the Supabase public-storage base URL.
    private func handleJobCompleted(resultUrl: String?) async {
        await MainActor.run {
            self.isProcessing           = false
            self.progressView.isHidden  = true
            self.statusLabel.isHidden   = true
            self.refreshButton.isHidden = true
        }

        let projectID = "djqgmowfjxsnjdffdohw"
        let publicBase = "https://\(projectID).supabase.co/storage/v1/object/public"

        // Load labeled PDF from sheet_data (public bucket — no auth needed)
        if let relPath = resultUrl, !relPath.isEmpty {
            // relPath is e.g. "sheet_data/{user_id}/{job_id}/labeled.pdf"
            let pdfPublicURL = relPath.hasPrefix("http") ? relPath : "\(publicBase)/\(relPath)"
            print("[PDF] ✅ Loading labeled PDF: \(pdfPublicURL)")
            await MainActor.run { self.loadSheetPDF(from: pdfPublicURL) }
        } else if let rawPath = pendingPDFPath {
            // No result_url yet — rare fallback: show input PDF via signed URL
            if let url = try? await SupabaseManager.shared.client.storage
                    .from("pdf_uploads").createSignedURL(path: rawPath, expiresIn: 3600) {
                print("[PDF] ⚠️ No result_url — falling back to input.pdf")
                await MainActor.run { self.loadSheetPDF(from: url.absoluteString) }
            }
        }

        // Download output.json and populate chord/key/time/tempo fields
        if let jobId, let rawPath = pendingPDFPath {
            let jsonURL = deriveOutputURL(jobId: jobId, pdfPath: rawPath)
            print("[JSON] 🔄 Fetching output.json: \(jsonURL)")
            
            Task {
                do {
                    let (data, response) = try await URLSession.shared.data(from: URL(string: jsonURL)!)
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("[JSON] HTTP \(code)  bytes=\(data.count)")
                    
                    guard (200...299).contains(code) else {
                        print("❌ [JSON] Failed to fetch output.json: HTTP \(code)")
                        return
                    }
                    
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("✅ [JSON] Successfully parsed output.json. Keys: \(json.keys.sorted())")
                        await parseAndDisplayJSON(json)
                    } else {
                        print("❌ [JSON] output.json is not a dictionary")
                    }
                } catch {
                    print("❌ [JSON] Error fetching/parsing output.json: \(error)")
                }
            }
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
        let header   = extractStaffHeader(json)
        print("[ParseJSON] chords=\(chords.count) \(Array(chords.prefix(4)))  staff=\(header)")
        await MainActor.run {
            self.sheetHeaderLabel.text = header
            self.displaySheetData(SheetMusicData(
                text: "", chords: chords, timeSignature: timeSig,
                tempo: tempoStr, keySignature: keySig, jsonData: json))
        }
    }

    /// Reads "staff" (or parts/clefs) from the JSON and returns a human-readable focus label.
    private func extractStaffHeader(_ json: [String: Any]) -> String {
        // Collect all unique staff/clef values from the JSON
        var clefs = Set<String>()

        // Top-level "staff" key
        if let s = json["staff"] as? String { clefs.insert(s.lowercased()) }

        // MusicXML: score-partwise → part → measure → attributes → clef → sign
        if let sp = json["score-partwise"] as? [String: Any] {
            for part in flatList(sp["part"]) {
                for measure in flatList(part["measure"]) {
                    if let attrs = measure["attributes"] as? [String: Any] {
                        let clefNodes = flatList(attrs["clef"])
                        for c in clefNodes {
                            if let sign = c["sign"] as? String { clefs.insert(sign.lowercased()) }
                        }
                    }
                }
            }
        }

        let hasTreble = clefs.contains("g") || clefs.contains("treble")
        let hasBass   = clefs.contains("f") || clefs.contains("bass")

        switch (hasTreble, hasBass) {
        case (true, true):  return "Both hands focus"
        case (true, false): return "Right hand focus"
        case (false, true): return "Left hand focus"
        default:            return "Right hand focus"   // sensible default
        }
    }

    // MARK: - Extraction Helpers

    private func extractChordsFromJSON(_ json: [String: Any]) -> [String] {
        if let a = json["chords"] as? [String], !a.isEmpty { return a }
        if let s = json["chords"] as? String {
            let p = s.components(separatedBy: ",")
                     .map { $0.trimmingCharacters(in: .whitespaces) }
                     .filter { !$0.isEmpty }
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
        let parts = flatList(sp["part"])
        for part in parts {
            let measures = flatList(part["measure"])
            for m in measures { if let h = m["harmony"] { chords += extractHarmonies(from: h) } }
        }
        return chords
    }

    private func deriveChordsFallback(from sp: [String: Any]) -> [String] {
        // Build a unique set of pitch-step names per measure, deduplicated globally
        var seen  = Set<String>()
        var chords: [String] = []
        for part in flatList(sp["part"]) {
            for measure in flatList(part["measure"]) {
                var steps = Set<String>()
                for note in flatList(measure["note"]) {
                    if let pitch = note["pitch"] as? [String: Any],
                       let step  = pitch["step"] as? String {
                        steps.insert(step)
                    }
                }
                guard !steps.isEmpty else { continue }
                let _ = steps.sorted().joined()   // e.g. "ADE" → use root only
                let root  = steps.sorted().first ?? "C"
                if !seen.contains(root) { seen.insert(root); chords.append(root) }
            }
        }
        return chords.isEmpty ? ["C","G","Am","F"] : chords
    }

    // Accepts either a [[String:Any]] or [String:Any] and returns [[String:Any]].
    private func flatList(_ value: Any?) -> [[String: Any]] {
        if let arr = value as? [[String: Any]]  { return arr }
        if let d   = value as? [String: Any]    { return [d] }
        return []
    }

    private func extractHarmonies(from harmonies: Any) -> [String] {
        var names: [String] = []
        let process: ([String: Any]) -> Void = { h in
            guard let root = h["root"] as? [String: Any],
                  let step = root["root-step"] as? String else { return }
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
            for part in flatList(sp["part"]) {
                if let first = flatList(part["measure"]).first,
                   let attrs = first["attributes"] as? [String: Any],
                   let time  = attrs["time"] as? [String: Any] {
                    let b  = (time["beats"]     as? String) ?? "\(time["beats"]     ?? "4")"
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
        // MusicXML: score-partwise → part → measure → attributes → key → fifths
        if let sp = json["score-partwise"] as? [String: Any] {
            for part in flatList(sp["part"]) {
                for measure in flatList(part["measure"]) {
                    if let attrs = measure["attributes"] as? [String: Any],
                       let key   = attrs["key"] as? [String: Any],
                       let fifthsStr = key["fifths"] as? String,
                       let fifths = Int(fifthsStr) {
                        return keyFromFifths(fifths)
                    }
                }
            }
            return inferKeyFromNotes(sp)
        }
        return "C Major"
    }

    private func keyFromFifths(_ fifths: Int) -> String {
        let major = ["C Major","G Major","D Major","A Major","E Major","B Major",
                     "F♯ Major","C♯ Major","F Major","B♭ Major",
                     "E♭ Major","A♭ Major","D♭ Major"]
        let idx = fifths >= 0 ? fifths : (8 + (-fifths))
        return (0..<major.count).contains(idx) ? major[idx] : "C Major"
    }

    private func inferKeyFromNotes(_ sp: [String: Any]) -> String {
        var sharps = 0; var flats = 0
        for part in flatList(sp["part"]) {
            for measure in flatList(part["measure"]) {
                for note in flatList(measure["note"]) {
                    if let pitch = note["pitch"] as? [String: Any],
                       let alter = pitch["alter"] as? String {
                        if alter == "1" { sharps += 1 } else if alter == "-1" { flats += 1 }
                    }
                }
            }
        }
        if sharps > flats { return sharps > 3 ? "E Major" : "G Major" }
        if flats > sharps { return flats  > 3 ? "E♭ Major" : "F Major" }
        return "A Minor"
    }

    private func extractTempo(_ json: [String: Any]) -> String {
        if let t = json["tempo"] as? String { return t }
        if let t = (json["analysis"] as? [String: Any])?["tempo"] as? String { return t }
        // MusicXML: direction → sound @tempo
        if let sp = json["score-partwise"] as? [String: Any] {
            for part in flatList(sp["part"]) {
                for measure in flatList(part["measure"]) {
                    if let dirs = measure["direction"] {
                        for d in (dirs as? [[String: Any]] ?? (dirs as? [String: Any]).map { [$0] } ?? []) {
                            if let sound = d["sound"] as? [String: Any],
                               let bpm   = sound["@tempo"] as? String, !bpm.isEmpty {
                                return "\(bpm) BPM"
                            }
                        }
                    }
                }
            }
        }
        return "120 BPM"
    }

    // MARK: - UI State

    private func updateProcessingStatus(message: String) {
        DispatchQueue.main.async { self.statusLabel.text = message }
    }

    private func showProcessingState() {
        isProcessing        = true
        metronomeLabel.text = "Metronome: Analyzing..."
        keyLabel.text       = "Key: –"; timeLabel.text = "Time: –"; chordLabel.text = "Chords: –"
        processingHeightConstraint?.constant = 4
        statusHeightConstraint?.constant     = 32
        refreshHeightConstraint?.constant    = 24
        progressView.isHidden  = false
        statusLabel.isHidden   = false
        refreshButton.isHidden = false
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
        sheetMusicText  = data.text;  extractedChords = data.chords
        timeSignature   = data.timeSignature; tempo = data.tempo
        keySignature    = data.keySignature;  sheetMusicJSON = data.jsonData

        let bpm = tempo.components(separatedBy: " ").first ?? "nil"
    metronomeLabel.text = "Metronome on \(bpm) BPM"
        keyLabel.text       = "Key: \(keySignature)"
        timeLabel.text      = "Time: \(timeSignature)"
        chordLabel.text     = "Chords: \(extractedChords.prefix(3).joined(separator: ", "))"
        updatePracticeTips()
        processingHeightConstraint?.constant = 0
        statusHeightConstraint?.constant     = 0
        refreshHeightConstraint?.constant    = 0
        progressView.isHidden  = true
        statusLabel.isHidden   = true
        refreshButton.isHidden = true
        onDataReady?()
    }

    private func showErrorState(error: String) {
        metronomeLabel.text    = "Metronome: N/A"
        keyLabel.text = "Key: N/A"; timeLabel.text = "Time: N/A"; chordLabel.text = "Chords: N/A"
        progressView.isHidden  = true
        statusLabel.text       = "Failed to load data"
        statusLabel.isHidden   = false
        refreshButton.isHidden = false
    }

    private func showSampleSheetMusic() {
        extractedChords = ["C", "G", "Am", "F"]
        timeSignature = "4/4"; tempo = "120 BPM"; keySignature = "C Major"
        displaySheetData(SheetMusicData(text: "", chords: extractedChords,
                                        timeSignature: timeSignature, tempo: tempo,
                                        keySignature: keySignature, jsonData: nil))
        sheetHeaderLabel.text  = "Right hand focus"
        progressView.isHidden  = true
        statusLabel.isHidden   = true
        refreshButton.isHidden = true
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
        guard let doc = pdfView.document else {
            let a = UIAlertController(title: "Not Ready", message: "PDF is still loading.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }
        let vc = MaximizeUploadPageViewController()
        vc.pdfDocument = doc
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func didTapPlayAlong() {
        if isProcessing { 
            let a = UIAlertController(title: "Processing", message: "Please wait for the analysis to complete.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }
        
        guard let json = sheetMusicJSON else {
            let a = UIAlertController(title: "No Data", message: "No sheet music data available for this upload.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }
        
        let a = UIAlertController(
            title: "Play Along",
            message: "Start practice session for this piece?\nTempo: \(tempo)",
            preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Start",  style: .default)  { _ in self.startPlayAlong(with: json) })
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(a, animated: true)
    }

    private func startPlayAlong(with json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            let a = UIAlertController(title: "Error", message: "Failed to prepare data for Play Along.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }
        
        let vc = PlayAlongViewController()
        vc.sheetMusicData = data
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        present(nav, animated: true)
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
        let vc = AnimationViewController()
        vc.sheetMusicData = data
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        present(nav, animated: true)
    }

    private func showAnimationError(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: - UI Setup

    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isBackButtonVisible = true; navBar.isChordIconVisible = true
        navBar.isProfileVisible    = true; navBar.isStreakVisible    = false
        navBar.isWelcomeTextHidden = true; navBar.setTitle("Practice")
        navBar.backAction    = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        navBar.chordAction   = { [weak self] in
            self?.navigationController?.pushViewController(ChordRecognitionViewController(), animated: true)
        }
        navBar.profileAction = { [weak self] in
            self?.navigationController?.pushViewController(UserProfileViewController(), animated: true)
        }
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        contentView.translatesAutoresizingMaskIntoConstraints = false

        sheetContainer.backgroundColor    = ComponentColors.SongDetailScreen.sheetMusicCardFill
        sheetContainer.layer.cornerRadius = 24
        sheetContainer.translatesAutoresizingMaskIntoConstraints = false

        sheetHeaderLabel.text      = "Right hand focus"
        sheetHeaderLabel.font      = .systemFont(ofSize: 16, weight: .semibold)
        sheetHeaderLabel.textColor = .label
        sheetHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        var previewConfig = UIButton.Configuration.filled()
        previewConfig.title              = "Preview"
        previewConfig.baseForegroundColor  = .white
        previewConfig.baseBackgroundColor  = ComponentColors.HomeScreen.actionButtonFill
        previewConfig.contentInsets      = NSDirectionalEdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18)
        previewConfig.cornerStyle        = .fixed
        previewConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var o = incoming; o.font = UIFont.systemFont(ofSize: 14, weight: .semibold); return o
        }
        previewButton.configuration      = previewConfig
        previewButton.layer.cornerRadius = 16
        previewButton.clipsToBounds      = true
        previewButton.translatesAutoresizingMaskIntoConstraints = false

        pdfView.autoScales          = true
        pdfView.displayMode         = .singlePageContinuous
        pdfView.displayDirection    = .vertical
        pdfView.backgroundColor     = ComponentColors.SongDetailScreen.sheetMusicBackground
        pdfView.layer.cornerRadius  = 14
        pdfView.clipsToBounds       = false
        pdfView.minScaleFactor      = 0.1
        pdfView.maxScaleFactor      = 5.0
        pdfView.isHidden            = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false

        sheetImageView.contentMode       = .scaleAspectFit
        sheetImageView.clipsToBounds     = true
        sheetImageView.layer.cornerRadius = 14
        sheetImageView.backgroundColor   = ComponentColors.SongDetailScreen.sheetMusicBackground
        sheetImageView.isHidden          = true
        sheetImageView.translatesAutoresizingMaskIntoConstraints = false

        sheetLoadingIndicator.color             = ComponentColors.HomeScreen.actionButtonFill
        sheetLoadingIndicator.hidesWhenStopped  = true
        sheetLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        progressView.progressTintColor  = ComponentColors.HomeScreen.actionButtonFill
        progressView.trackTintColor     = UIColor.secondaryLabel.withAlphaComponent(0.2)
        progressView.layer.cornerRadius = 3
        progressView.clipsToBounds      = true
        progressView.isHidden           = true
        progressView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text          = "Processing your sheet music..."
        statusLabel.font          = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor     = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden      = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.setTitleColor(ComponentColors.HomeScreen.actionButtonFill, for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        refreshButton.isHidden         = true
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        infoStackView.axis         = .horizontal
        infoStackView.spacing      = 10
        infoStackView.distribution = .fillEqually
        infoStackView.alignment    = .center   // ← ADD THIS LINE
        infoStackView.translatesAutoresizingMaskIntoConstraints = false
        for lbl in [keyLabel, timeLabel, chordLabel] {
            lbl.font              = .systemFont(ofSize: 12, weight: .medium)
            lbl.textColor         = .secondaryLabel
            lbl.textAlignment     = .center
            lbl.backgroundColor   = ComponentColors.SongDetailScreen.sheetMusicBackground
            lbl.layer.cornerRadius = 8
            lbl.clipsToBounds     = true
            lbl.numberOfLines     = 2
            infoStackView.addArrangedSubview(lbl)
        }
        keyLabel.text   = "Key: C Major"
        timeLabel.text  = "Time: 4/4"
        chordLabel.text = "Chords: –"

        //metronomeLabel.text      = "Metronome on 120 BPM"
        metronomeLabel.font      = .systemFont(ofSize: 13, weight: .medium)
        metronomeLabel.textColor = .secondaryLabel
        metronomeLabel.textAlignment = .right
        metronomeLabel.translatesAutoresizingMaskIntoConstraints = false

        tipsContainer.backgroundColor    = ComponentColors.SongDetailScreen.sheetMusicCardFill
        tipsContainer.layer.cornerRadius = 20
        tipsContainer.translatesAutoresizingMaskIntoConstraints = false

        tipsTitleLabel.text      = "Tips"
        tipsTitleLabel.font      = .systemFont(ofSize: 22, weight: .bold)
        tipsTitleLabel.textColor = .label
        tipsTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        tipsBodyLabel.text        = "Keep wrists relaxed and fingers curved.\nListen for even timing."
        tipsBodyLabel.numberOfLines = 0
        tipsBodyLabel.font        = .systemFont(ofSize: 15)
        tipsBodyLabel.textColor   = .label
        tipsBodyLabel.translatesAutoresizingMaskIntoConstraints = false

        var playConfig = UIButton.Configuration.filled()
        playConfig.title              = "Play Along"
        playConfig.baseForegroundColor  = .white
        playConfig.baseBackgroundColor  = ComponentColors.HomeScreen.actionButtonFill
        playConfig.cornerStyle        = .capsule
        playAlongButton.configuration = playConfig
        playAlongButton.translatesAutoresizingMaskIntoConstraints = false

        var animConfig = UIButton.Configuration.filled()
        animConfig.title              = "Animation"
        animConfig.baseForegroundColor  = .label
        animConfig.baseBackgroundColor  = ComponentColors.SongDetailScreen.sheetMusicBackground
        animConfig.cornerStyle        = .capsule
        animationButton.configuration = animConfig
        animationButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildHierarchy() {
        view.addSubview(scrollView); scrollView.addSubview(contentView)
        contentView.addSubview(sheetContainer)
        sheetContainer.addSubview(sheetHeaderLabel); sheetContainer.addSubview(previewButton)
        sheetContainer.addSubview(pdfView);          sheetContainer.addSubview(sheetImageView)
        sheetContainer.addSubview(sheetLoadingIndicator)
        sheetContainer.addSubview(progressView);     sheetContainer.addSubview(statusLabel)
        sheetContainer.addSubview(refreshButton);    sheetContainer.addSubview(infoStackView)
        sheetContainer.addSubview(metronomeLabel)
        contentView.addSubview(tipsContainer)
        tipsContainer.addSubview(tipsTitleLabel); tipsContainer.addSubview(tipsBodyLabel)
        contentView.addSubview(playAlongButton);  contentView.addSubview(animationButton)
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

            sheetHeaderLabel.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 30),
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

            // Processing views sit between PDF and info labels (spacing collapses with content)
            progressView.topAnchor.constraint(equalTo: pdfView.bottomAnchor, constant: 0),
            progressView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),
            {
                let c = progressView.heightAnchor.constraint(equalToConstant: 4)
                processingHeightConstraint = c
                return c
            }(),

            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 0),
            statusLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),
            {
                let c = statusLabel.heightAnchor.constraint(equalToConstant: 32)
                statusHeightConstraint = c; return c
            }(),

            refreshButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 0),
            refreshButton.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            {
                let c = refreshButton.heightAnchor.constraint(equalToConstant: 24)
                refreshHeightConstraint = c; return c
            }(),

            // Info stack anchors to refreshButton — collapses to 10pt gap when processing hidden
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
            playAlongButton.heightAnchor.constraint(equalToConstant: 46),

            animationButton.centerYAnchor.constraint(equalTo: playAlongButton.centerYAnchor),
            animationButton.leadingAnchor.constraint(equalTo: playAlongButton.trailingAnchor, constant: 12),
            animationButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            animationButton.heightAnchor.constraint(equalToConstant: 46),
            animationButton.widthAnchor.constraint(equalTo: playAlongButton.widthAnchor),
            animationButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
        ])
    }
}

//
//  UploadPageNextViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase
import Auth
internal import PostgREST
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
    private var unavailableReasonMessage: String?
    private var hasPresentedUnavailableReason = false
    private var pollingTimer:     Timer?
    private var processingHeightConstraint: NSLayoutConstraint?
    private var statusHeightConstraint:     NSLayoutConstraint?
    private var refreshHeightConstraint:    NSLayoutConstraint?
    private var loadedPDFData:     Data?
    private var pendingPDFPath:   String?       // raw pdf_path from DB, used after processing
    private var pdfLoadTask:      Task<Void, Never>?
    private var jsonFetchTask:    Task<Void, Never>?
    private var jobLoadTask:      Task<Void, Never>?
    private var pollStatusTask:   Task<Void, Never>?
    private var trackedPracticeSessionStartedAt: Date?

    // MARK: - Scroll
    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    // MARK: - Sheet container
    private let sheetContainer   = UIView()
    private let sheetHeaderLabel = UILabel()
    private let previewButton    = UIButton(type: .system)

    // Sheet display
    private let sheetPDFView          = PDFView()
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

    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.App.screenBackground
        setupNativeNavBar(); setupUI(); buildHierarchy(); applyConstraints(); setupActions()
        showProcessingState()
        debugLog("[VDL] jobId=\(jobId?.uuidString.lowercased() ?? "nil")  hasResultURL=\(resultURL?.isEmpty == false)")
        loadFromJobId()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SupabaseProgressManager.beginTrackedPracticeSessionIfNeeded(&trackedPracticeSessionStartedAt)
        presentUnavailableReasonIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.isHidden = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pollingTimer?.invalidate(); pollingTimer = nil
        pdfLoadTask?.cancel()
        jsonFetchTask?.cancel()
        jobLoadTask?.cancel()
        pollStatusTask?.cancel()

        let movedOffNavigationStack = navigationController?.topViewController.map { $0 !== self } ?? false
        if isMovingFromParent || isBeingDismissed || movedOffNavigationStack {
            releasePreviewResources()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        SupabaseProgressManager.endTrackedPracticeSession(
            &trackedPracticeSessionStartedAt,
            kind: .practicePage
        )
    }

    deinit {
        pollingTimer?.invalidate()
        pdfLoadTask?.cancel()
        jsonFetchTask?.cancel()
        jobLoadTask?.cancel()
        pollStatusTask?.cancel()
        releasePreviewResources()
    }

    // MARK: - Data Loading

    private func loadFromJobId() {
        guard let jobId else {
            debugLog("[Load] ❌ No jobId available for upload result screen")
            showUnavailableState(message: "We couldn't load this upload. Please return to Uploads and try again.")
            return
        }
        jobLoadTask?.cancel()
        jobLoadTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchJobAndLoad(jobId: jobId)
        }
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
                debugLog("[Load] ❌ No job found for jobId=\(jobId)")
                await MainActor.run {
                    self.showUnavailableState(message: "This upload is no longer available. Please refresh your uploads list.")
                }
                return
            }

            // Store path — PDF loads only after processing completes (labeled if ready, else input)
            self.pendingPDFPath = row.pdfPath

            // Determine effective result URL
            let _: String
            if let preSupplied = self.resultURL, !preSupplied.isEmpty {
                if isLegacyPublicStorageURL(preSupplied) {
                    let authenticatedURL = deriveOutputURL(jobId: jobId, pdfPath: row.pdfPath)
                    debugLog("[Load] Ignoring legacy public resultURL; using authenticated route: \(authenticatedURL)")
                    _ = authenticatedURL
                } else {
                    debugLog("[Load] Using pre-supplied authenticated resultURL")
                    _ = preSupplied
                }
            } else if let dbURL = row.resultUrl, !dbURL.isEmpty {
                if isLegacyPublicStorageURL(dbURL) {
                    let authenticatedURL = deriveOutputURL(jobId: jobId, pdfPath: row.pdfPath)
                    debugLog("[Load] Ignoring legacy DB result_url; using authenticated route: \(authenticatedURL)")
                    _ = authenticatedURL
                } else {
                    debugLog("[Load] Using DB result_url")
                    _ = dbURL
                }
            } else {
                let derived = deriveOutputURL(jobId: jobId, pdfPath: row.pdfPath)
                debugLog("[Load] No result_url — using derived: \(derived)")
                _ = derived
            }

            // Start polling job status — backend owns all transitions
            await MainActor.run { self.startPollingJobStatus() }

        } catch {
            debugLog("[Load] ❌ DB error: \(error)")
            let message = AppUserFacingError.message(
                for: "load this upload",
                error: error,
                fallback: "We hit a problem loading this upload. Please try again."
            )
            await MainActor.run {
                self.showUnavailableState(message: message)
            }
        }
    }

    /// Derives the authenticated output JSON endpoint for the current job.
    private func deriveOutputURL(jobId: UUID, pdfPath: String) -> String {
        _ = pdfPath
        return "\(ReHersAPI.baseURLString)/sheets/\(normalizedJobIDString(jobId))"
    }

    private func deriveLabeledPDFURL(jobId: UUID) -> String {
        "\(ReHersAPI.baseURLString)/sheets/\(normalizedJobIDString(jobId))/pdf"
    }

    private func normalizedJobIDString(_ jobId: UUID) -> String {
        jobId.uuidString.lowercased()
    }

    // MARK: - PDF Display

    private func loadSheetPDF(from urlString: String) {
        guard let url = URL(string: urlString) else {
            debugLog("[PDF] ❌ Invalid URL: \(urlString)"); return
        }
        debugLog("[PDF] 🔄 Loading: \(urlString)")
        releasePreviewResources()
        sheetLoadingIndicator.startAnimating()
        sheetPDFView.isHidden = true

        pdfLoadTask?.cancel()
        pdfLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let (data, code) = try await self.fetchAuthenticatedData(
                    from: url,
                    logPrefix: "PDF",
                    usePinnedSession: urlString.hasPrefix(ReHersAPI.baseURLString)
                )

                guard (200...299).contains(code) else {
                    let body = String(data: data, encoding: .utf8) ?? "<binary>"
                    debugLog("[PDF] ❌ HTTP \(code): \(body)")
                    let message = AppUserFacingError.message(
                        for: "load this sheet preview",
                        error: nil,
                        fallback: "We couldn't load this sheet preview right now. Please try again."
                    )
                    await MainActor.run {
                        self.sheetLoadingIndicator.stopAnimating()
                        self.statusLabel.text      = message
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
                debugLog("[PDF] ❌ Network error: \(error.localizedDescription)")
                let message = AppUserFacingError.message(
                    for: "load this sheet preview",
                    error: error,
                    fallback: "We couldn't load this sheet preview right now. Please try again."
                )
                await MainActor.run {
                    self.sheetLoadingIndicator.stopAnimating()
                    self.statusLabel.text      = message
                    self.statusLabel.isHidden  = false
                    self.refreshButton.isHidden = false
                }
            }
        }
    }

    private func handlePDFData(_ data: Data) {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else {
            debugLog("[PDF] ❌ Not a valid PDF")
            statusLabel.text       = "We couldn't render this sheet preview right now. Please try again."
            statusLabel.isHidden   = false
            refreshButton.isHidden = false
            return
        }

        debugLog("[PDF] ✅ Rendering PDF inline")
        loadedPDFData          = data
        sheetPDFView.document  = doc
        if let p = doc.page(at: 0) { sheetPDFView.go(to: p) }
        sheetPDFView.isHidden  = false
    }

    // MARK: - Job Status Polling

    private static let maxPollAttempts = 60   // 60 × 5 s = 5 min max
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
                let message = AppUserFacingError.message(
                    for: "finish processing this upload",
                    error: nil,
                    fallback: "Processing is taking longer than expected. Please try again in a moment."
                )
                DispatchQueue.main.async {
                    self.statusLabel.text       = message
                    self.statusLabel.isHidden   = false
                    self.refreshButton.isHidden = false
                    self.progressView.isHidden  = true
                }
                return
            }
            self.pollStatusTask?.cancel()
            self.pollStatusTask = Task { [weak self] in
                guard let self else { return }
                await self.pollJobStatus(jobId: jobId)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
        pollStatusTask?.cancel()
        pollStatusTask = Task { [weak self] in
            guard let self else { return }
            await self.pollJobStatus(jobId: jobId)
        }  // immediate first check
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
                let message = AppUserFacingError.message(
                    for: "finish processing this upload",
                    error: nil,
                    fallback: "We couldn't finish processing this upload. Please try again."
                )
                await MainActor.run {
                    self.isProcessing = false
                    self.showUnavailableState(message: message)
                }
            case "processing":
                await MainActor.run { self.updateProcessingStatus(message: "Processing…") }
            default:
                await MainActor.run { self.updateProcessingStatus(message: "Job queued…") }
            }
        } catch {
            debugLog("[Poll] DB polling error")
            stopPolling()
            let message = AppUserFacingError.message(
                for: "check this upload",
                error: error,
                fallback: "We couldn't refresh this upload right now. Please try again."
            )
            DispatchQueue.main.async { self.showErrorState(error: message) }
        }
    }

    /// Called once the backend marks the job complete. The authenticated backend
    /// owns access to both output.json and labeled.pdf for this job.
    private func handleJobCompleted(resultUrl: String?) async {
        guard let currentJobId = jobId else { return }
        await MainActor.run {
            self.isProcessing           = false
            self.progressView.isHidden  = true
            self.statusLabel.isHidden   = true
            self.refreshButton.isHidden = true
        }

        let pdfURL = deriveLabeledPDFURL(jobId: currentJobId)
        if let relPath = resultUrl, isLegacyPublicStorageURL(relPath) {
            debugLog("[PDF] Ignoring legacy public PDF path; using authenticated route")
        } else {
            debugLog("[PDF] Using authenticated backend PDF route")
        }
        debugLog("[PDF] ✅ Loading labeled PDF")
        await MainActor.run { self.loadSheetPDF(from: pdfURL) }

        // Download output.json and populate chord/key/time/tempo fields
        if let rawPath = pendingPDFPath {
            await fetchOutputJSON(jobId: currentJobId, pdfPath: rawPath)
        }
    }

    private func fetchOutputJSON(jobId: UUID, pdfPath: String) async {
        let jsonURL = deriveOutputURL(jobId: jobId, pdfPath: pdfPath)
        debugLog("[JSON] Fetching output.json from authenticated route")

        jsonFetchTask?.cancel()
        jsonFetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard let url = URL(string: jsonURL) else { return }
                let (data, code) = try await self.fetchAuthenticatedData(
                    from: url,
                    logPrefix: "JSON",
                    usePinnedSession: true
                )

                guard (200...299).contains(code) else {
                    debugLog("❌ [JSON] Failed to fetch output.json: HTTP \(code)")
                    return
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    debugLog("✅ [JSON] Successfully parsed output.json. Keys: \(json.keys.sorted())")
                    await parseAndDisplayJSON(json)
                } else {
                    debugLog("❌ [JSON] output.json is not a dictionary")
                }
            } catch {
                debugLog("❌ [JSON] Error fetching/parsing output.json: \(error)")
            }
        }

        await jsonFetchTask?.value
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
        debugLog("[ParseJSON] chords=\(chords.count) \(Array(chords.prefix(4)))  staff=\(header)")
        await MainActor.run {
            self.sheetHeaderLabel.text = header
            self.displaySheetData(SheetMusicData(
                text: "", chords: chords, timeSignature: timeSig,
                tempo: tempoStr, keySignature: keySig, jsonData: json))
        }
    }

    private func authToken() async -> String? {
        try? await SupabaseManager.shared.accessToken()
    }

    private func refreshAuthToken() async -> String? {
        try? await SupabaseManager.shared.accessToken(forceRefresh: true)
    }

    private func fetchAuthenticatedData(
        from url: URL,
        logPrefix: String,
        usePinnedSession: Bool
    ) async throws -> (Data, Int) {
        let session = usePinnedSession ? ReHersPinnedSession.shared : URLSession.shared
        var didRetryAfterRefresh = false

        while true {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15

            if usePinnedSession {
                guard let token = await (didRetryAfterRefresh ? refreshAuthToken() : authToken()) else {
                    debugLog("❌ [\(logPrefix)] Missing auth credentials")
                    return (Data(), 401)
                }
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                debugLog("[\(logPrefix)] Authorization header set: true")
            }

            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            debugLog("[\(logPrefix)] HTTP \(code)  bytes=\(data.count)")

            if code == 401 && usePinnedSession && !didRetryAfterRefresh {
                debugLog("[\(logPrefix)] 401 received, refreshing session and retrying once")
                didRetryAfterRefresh = true
                continue
            }

            return (data, code)
        }
    }

    private func isLegacyPublicStorageURL(_ value: String) -> Bool {
        let storageMarker = ["/storage", "v1", "object", "public"].joined(separator: "/")
        return value.contains(storageMarker)
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        pollStatusTask?.cancel()
        pollStatusTask = nil
    }

    private func showErrorState() {
        showErrorState(error: AppUserFacingError.message(
            for: "load this upload",
            error: nil,
            fallback: "We couldn't load this upload right now. Please try again."
        ))
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
        unavailableReasonMessage = nil
        hasPresentedUnavailableReason = false

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
        unavailableReasonMessage = error
        metronomeLabel.text    = "Metronome: N/A"
        keyLabel.text = "Key: N/A"; timeLabel.text = "Time: N/A"; chordLabel.text = "Chords: N/A"
        progressView.isHidden  = true
        statusLabel.text       = error
        statusLabel.isHidden   = false
        refreshButton.isHidden = false
        presentUnavailableReasonIfNeeded()
    }

    private func showUnavailableState(message: String) {
        unavailableReasonMessage = message
        extractedChords = []
        timeSignature = "Unavailable"
        tempo = "Unavailable"
        keySignature = "Unavailable"
        sheetMusicJSON = nil
        sheetMusicText = ""
        loadedPDFData = nil
        sheetHeaderLabel.text = "Upload unavailable"
        metronomeLabel.text = "Metronome: Unavailable"
        keyLabel.text = "Key: Unavailable"
        timeLabel.text = "Time: Unavailable"
        chordLabel.text = "Chords: Unavailable"
        tipsBodyLabel.text = message
        progressView.isHidden = true
        statusLabel.text = message
        statusLabel.isHidden = false
        refreshButton.isHidden = false
        presentUnavailableReasonIfNeeded()
    }

    private func presentUnavailableReasonIfNeeded() {
        guard isViewLoaded,
              view.window != nil,
              !hasPresentedUnavailableReason,
              presentedViewController == nil,
              let message = unavailableReasonMessage,
              !message.isEmpty else { return }

        hasPresentedUnavailableReason = true
        let alert = UIAlertController(
            title: "Conversion Issue",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    #if DEBUG
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
    #endif

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
        NavigationBarHelper.animateButtonPress(previewButton) { [weak self] in
            guard let self = self else { return }
            guard let pdfData = self.loadedPDFData,
                  let doc = autoreleasepool(invoking: { PDFDocument(data: pdfData) }),
                  doc.pageCount > 0 else {
                let a = UIAlertController(title: "Not Ready", message: "PDF is still loading.", preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(a, animated: true)
                return
            }
            let vc = MaximizeUploadPageViewController()
            vc.pdfData = pdfData
            vc.pdfDocument = doc
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true)
        }
    }

    @objc private func didTapPlayAlong() {
        NavigationBarHelper.animateButtonPress(playAlongButton) { [weak self] in
            guard let self = self else { return }
            guard !self.presentGuestPlayAlongGateIfNeeded() else { return }
            guard let json = self.validSheetMusicJSON(orPresentingFor: "Play Along") else { return }
            
            let a = UIAlertController(
                title: "Play Along",
                message: "Start practice session for this piece?\nTempo: \(self.tempo)",
                preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Start",  style: .default)  { _ in self.startPlayAlong(with: json) })
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(a, animated: true)
        }
    }

    private func startPlayAlong(with json: [String: Any]) {
        guard !presentGuestPlayAlongGateIfNeeded() else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            let a = UIAlertController(title: "Error", message: "Failed to prepare data for Play Along.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }
        
        let vc = PlayAlongViewController()
        vc.sheetMusicData = data
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @discardableResult
    private func presentGuestPlayAlongGateIfNeeded() -> Bool {
        guard GuestSessionManager.shared.isGuest(), presentedViewController == nil else { return false }

        let modal = GuestFeatureGateModal(
            featureName: "play along",
            onSignUp: { [weak self] in
                self?.presentGuestAuth(mode: .signUp)
            },
            onLogIn: { [weak self] in
                self?.presentGuestAuth(mode: .logIn)
            }
        )

        present(modal, animated: true)
        return true
    }

    private func presentGuestAuth(mode: AuthViewController.AuthMode) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }

            let authVC = AuthViewController(initialMode: mode)
            let nav = UINavigationController(rootViewController: authVC)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        }
    }

    @objc private func didTapAnimation() {
        NavigationBarHelper.animateButtonPress(animationButton) { [weak self] in
            guard let self = self else { return }
            guard let json = self.validSheetMusicJSON(orPresentingFor: "Animation") else { return }
            self.navigateToAnimation(withJSON: json)
        }
    }

    private func validSheetMusicJSON(orPresentingFor feature: String) -> [String: Any]? {
        if isProcessing {
            showFeatureUnavailableAlert(
                title: "Processing",
                message: "Please wait for the analysis to complete before opening \(feature)."
            )
            return nil
        }

        guard let json = sheetMusicJSON else {
            showFeatureUnavailableAlert(
                title: "No Data",
                message: "This upload could not be converted properly, so \(feature) is unavailable for it."
            )
            return nil
        }

        if loadedPDFData == nil || sheetHeaderLabel.text == "Upload unavailable" || tempo == "Unavailable" {
            showFeatureUnavailableAlert(
                title: "Unavailable",
                message: "This upload is missing converted sheet music data, so \(feature) can't be opened."
            )
            return nil
        }

        return json
    }

    private func showFeatureUnavailableAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func navigateToAnimation(withJSON json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            showAnimationError("Failed to prepare data."); return
        }
        let vc = AnimationViewController()
        vc.sheetMusicData = data
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func showAnimationError(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: - UI Setup

    private func setupNativeNavBar() {
        title = "Practice"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        
        navigationItem.leftBarButtonItem = NavigationBarHelper.createCustomBackButton(target: self, action: #selector(backAction))
    }

    @objc private func backAction() {
        if let btn = navigationItem.leftBarButtonItem?.customView {
            NavigationBarHelper.animateButtonPress(btn) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        } else {
            navigationController?.popViewController(animated: true)
        }
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

        previewButton.setTitle("Preview", for: .normal)
        previewButton.setTitleColor(.white, for: .normal)
        previewButton.backgroundColor    = ComponentColors.HomeScreen.actionButtonFill
        previewButton.titleLabel?.font   = .systemFont(ofSize: 14, weight: .semibold)
        previewButton.contentEdgeInsets  = UIEdgeInsets(top: 7, left: 18, bottom: 7, right: 18)
        previewButton.layer.cornerRadius = 16
        previewButton.clipsToBounds      = true
        previewButton.translatesAutoresizingMaskIntoConstraints = false

        sheetPDFView.autoScales          = true
        sheetPDFView.displayMode         = .singlePageContinuous
        sheetPDFView.displayDirection    = .vertical
        sheetPDFView.backgroundColor     = ComponentColors.SongDetailScreen.sheetMusicBackground
        sheetPDFView.layer.cornerRadius  = 14
        sheetPDFView.clipsToBounds       = true
        sheetPDFView.isHidden            = true
        sheetPDFView.isUserInteractionEnabled = true
        sheetPDFView.translatesAutoresizingMaskIntoConstraints = false

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

        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.setTitleColor(.white, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        playAlongButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        playAlongButton.layer.cornerRadius = 20
        playAlongButton.clipsToBounds = true
        playAlongButton.translatesAutoresizingMaskIntoConstraints = false

        animationButton.setTitle("Animation", for: .normal)
        animationButton.setTitleColor(.label, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicBackground
        animationButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        animationButton.layer.cornerRadius = 20
        animationButton.clipsToBounds = true
        animationButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildHierarchy() {
        view.addSubview(scrollView); scrollView.addSubview(contentView)
        contentView.addSubview(sheetContainer)
        sheetContainer.addSubview(sheetHeaderLabel); sheetContainer.addSubview(previewButton)
        sheetContainer.addSubview(sheetPDFView)
        sheetContainer.addSubview(sheetLoadingIndicator)
        sheetContainer.addSubview(progressView);     sheetContainer.addSubview(statusLabel)
        sheetContainer.addSubview(refreshButton);    sheetContainer.addSubview(infoStackView)
        sheetContainer.addSubview(metronomeLabel)
        contentView.addSubview(tipsContainer)
        tipsContainer.addSubview(tipsTitleLabel); tipsContainer.addSubview(tipsBodyLabel)
        contentView.addSubview(playAlongButton);  contentView.addSubview(animationButton)
    }

    private func releasePreviewResources() {
        loadedPDFData = nil
        sheetPDFView.document = nil
        sheetPDFView.isHidden = true
        statusLabel.isHidden = true
        sheetLoadingIndicator.stopAnimating()
    }


    private func applyConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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

            sheetPDFView.topAnchor.constraint(equalTo: sheetHeaderLabel.bottomAnchor, constant: 14),
            sheetPDFView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 12),
            sheetPDFView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -12),
            sheetPDFView.heightAnchor.constraint(equalToConstant: 400),

            sheetLoadingIndicator.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            sheetLoadingIndicator.topAnchor.constraint(equalTo: sheetHeaderLabel.bottomAnchor, constant: 200),

            // Processing views sit between PDF and info labels (spacing collapses with content)
            progressView.topAnchor.constraint(equalTo: sheetPDFView.bottomAnchor, constant: 0),
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
            animationButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }
}

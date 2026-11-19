//
//  OnDeviceSheetConverter.swift
//  Re-Hearse_v1
//
//  Sheet music PDF → score JSON + MusicXML + labeled PDF, entirely on the device: OemerKit
//  runs oemer's two networks with Core ML (Neural Engine) and its recognition engine in Swift.
//  It replaced the former conversion server (Audiveris behind a /convert API), now removed.
//

import OemerKit
import PDFKit
import UIKit
import Vision

/// Everything one conversion produces.
nonisolated struct SheetConversionResult {
    /// The score in the JSON shape Play Along and Animation read (`MusicXMLDocument.jsonObject`).
    let scoreJSON: Data
    let musicXML: String
    /// The input PDF with English note names under the notes.
    let labeledPDF: Data
    /// What `labeledPDF` was drawn from, so it can be redrawn from the input PDF on another
    /// device instead of storing a second PDF (see `LabelSheet`).
    let labels: LabelSheet
    let noteCount: Int
    let pageCount: Int
    /// 1-based pages where no music was found; they stay unlabeled and add no measures.
    let skippedPages: [Int]
    let seconds: Double
}

/// The note names drawn on each page, in page-image pixels, with each page's render scale.
nonisolated struct LabelSheet: Codable {
    struct Page: Codable {
        let labels: [NoteLabelRenderer.Label]
        let scale: CGFloat
    }
    let pages: [Page]
}

nonisolated enum SheetConversionError: LocalizedError {
    case unreadablePDF
    case noMusicFound
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .unreadablePDF:
            return "We couldn't open this file. Please try another PDF or photo."
        case .noMusicFound:
            return "We couldn't find any sheet music in this file. Try a sharper, evenly lit photo of printed music."
        case .recognizerUnavailable:
            return "The music recognizer couldn't start on this device. Please restart the app and try again."
        }
    }
}

nonisolated final class OnDeviceSheetConverter: @unchecked Sendable {
    static let shared = OnDeviceSheetConverter()

    private let lock = NSLock()
    private var recognizer: SheetMusicRecognizer?

    /// Pages are rendered at about this many pixels; OemerKit works at 3.0–4.35 MP.
    private static let renderPixels: CGFloat = 4_000_000
    /// Fewer notes than this in the whole file and it isn't a piece of music.
    static let minimumNotes = 4

    /// Loads the models ahead of the first upload (the first load after install is slow).
    func prepare() async {
        try? await loadedRecognizer().prepare()
    }

    /// Converts every page of `pdfData`. Pages without music are skipped; if no page has any,
    /// this throws `SheetConversionError.noMusicFound`. Call it off the main actor.
    func convert(pdfData: Data, title: String,
                 progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> SheetConversionResult
    {
        let start = Date()
        guard let document = PDFDocument(data: pdfData), document.pageCount > 0 else {
            throw SheetConversionError.unreadablePDF
        }
        let recognizer = try loadedRecognizer()
        let pageCount = document.pageCount

        var scores: [XMLElementNode] = []
        var labels: [[NoteLabelRenderer.Label]] = Array(repeating: [], count: pageCount)
        // each page's recognized notes with their MusicXML elements, for labels made after the
        // score is corrected (ScoreCleanup changes pitches in place)
        var pageNotes: [(index: Int, notes: [LocatedNote], elements: [XMLElementNode]?)] = []
        var scales: [CGFloat] = Array(repeating: 1, count: pageCount)
        var skipped: [Int] = []
        var noteCount = 0
        // the printed tempo: from the text layer, else read off the first page's image (once)
        let textTempo = PrintedTempo.findInText(of: document)
        let readTempo = textTempo == nil ? document.page(at: 0).flatMap(PrintedTempo.recognizedMark(on:)) : nil

        for index in 0..<pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let size = Self.displaySize(of: page)
            let scale = (Self.renderPixels / max(size.width * size.height, 1)).squareRoot()
            scales[index] = scale
            guard let image = Self.render(page, size: size, scale: scale) else {
                skipped.append(index + 1)
                continue
            }
            do {
                let result = try await recognizer.recognize(cgImage: image) { p in
                    progress((Double(index) + p) / Double(pageCount))
                }
                let pageScore = try MusicXMLDocument.parse(result.musicXML)
                var notes = result.notes
                if let mark = PrintedTempo.markBounds(on: page) ?? (index == 0 ? readTempo?.bounds : nil) {
                    let rects = notes.map { CGRect(x: $0.rect.minX / scale, y: $0.rect.minY / scale,
                                                   width: $0.rect.width / scale, height: $0.rect.height / scale) }
                    let hidden = PrintedTempo.hideNotes(under: mark, at: rects, in: pageScore)
                    notes = notes.enumerated().filter { !hidden.contains($0.offset) }.map(\.element)
                }
                let elements = PrintedTempo.pitchedNotes(in: pageScore)
                if elements.count == notes.count {
                    let moved = StaffAssignment.fix(&notes, elements: elements, score: pageScore)
                    if moved > 0 { debugLog("[OnDevice] page \(index + 1): \(moved) note(s) moved to the staff they sit on") }
                }
                scores.append(pageScore)
                pageNotes.append((index, notes, elements.count == notes.count ? elements : nil))
                noteCount += notes.count
            } catch let error as OMRError {
                switch error {
                case .noStaffFound, .imageTooNoisy, .inconsistentStaffs, .imageDecodingFailed:
                    #if DEBUG
                    print("[OnDevice] page \(index + 1) skipped: \(error)")
                    #endif
                    skipped.append(index + 1)
                case .modelUnavailable, .badClassifierData:
                    throw SheetConversionError.recognizerUnavailable
                }
            }
        }

        // Lines in a photo (grass, a table's edge) can pass for staves; with hardly a note on
        // them it isn't music, and the upload fails instead of "completing" empty.
        guard noteCount >= Self.minimumNotes, let score = MusicXMLDocument.merge(pages: scores) else {
            throw SheetConversionError.noMusicFound
        }
        score.firstChild(named: "work")?.firstChild(named: "work-title")?.text = title
        MusicXMLDocument.normalizeTempo(score)
        let cleanup = ScoreCleanup.clean(score)
        if cleanup != ScoreCleanup.Report() {
            debugLog("[OnDevice] undid \(cleanup.clefs) false clef change(s), \(cleanup.keys) false key change(s)")
        }
        let rhythm = RhythmRepair.repair(score)
        if rhythm != RhythmRepair.Report() {
            debugLog("[OnDevice] rhythm: \(rhythm.leadingGaps) empty opening beat(s) removed, \(rhythm.refitted) measure(s) re-timed")
        }
        for page in pageNotes {
            var names: [Int: String] = [:]
            for (i, element) in (page.elements ?? []).enumerated() {
                if let name = Self.noteName(element) { names[i] = name }
            }
            labels[page.index] = NoteLabelRenderer.layout(page.notes, names: names)
        }
        if let tempo = textTempo ?? readTempo?.mark { PrintedTempo.apply(tempo, to: score) }
        let json = MusicXMLDocument.jsonObject(score)
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let labeledPDF = Self.labeledPDF(document, labels: labels, scales: scales)
        progress(1)
        return SheetConversionResult(scoreJSON: jsonData, musicXML: MusicXMLDocument.serialize(score),
                                     labeledPDF: labeledPDF,
                                     labels: LabelSheet(pages: zip(labels, scales).map { LabelSheet.Page(labels: $0, scale: $1) }),
                                     noteCount: noteCount, pageCount: pageCount,
                                     skippedPages: skipped, seconds: Date().timeIntervalSince(start))
    }

    // MARK: - Private

    /// "Eb4" from a MusicXML <note>.
    private static func noteName(_ note: XMLElementNode) -> String? {
        guard let pitch = note.firstChild(named: "pitch"), let step = pitch.firstChild(named: "step")?.text,
              let octave = pitch.firstChild(named: "octave")?.text else { return nil }
        let alter = ["1": "#", "-1": "b", "2": "##", "-2": "bb"][pitch.firstChild(named: "alter")?.text ?? "0"] ?? ""
        return step + alter + octave
    }

    private func loadedRecognizer() throws -> SheetMusicRecognizer {
        lock.lock()
        defer { lock.unlock() }
        if let recognizer { return recognizer }
        do {
            let r = try SheetMusicRecognizer()
            recognizer = r
            return r
        } catch {
            throw SheetConversionError.recognizerUnavailable
        }
    }

    /// Page size as shown, in points (width and height swap for pages rotated by 90° or 270°).
    private static func displaySize(of page: PDFPage) -> CGSize {
        let box = page.bounds(for: .cropBox).size
        return page.rotation % 180 == 0 ? box : CGSize(width: box.height, height: box.width)
    }

    /// Draws the page upright into a UIKit (top-left origin) context of `displaySize` points.
    /// PDFKit applies the page's rotation itself; it only needs the y axis flipped.
    private static func drawPage(_ page: PDFPage, size: CGSize, in cg: CGContext) {
        cg.saveGState()
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: 1, y: -1)
        page.draw(with: .cropBox, to: cg)
        cg.restoreGState()
    }

    /// The page on white at `scale` pixels per point, for recognition.
    private static func render(_ page: PDFPage, size: CGSize, scale: CGFloat) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let pixels = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let image = UIGraphicsImageRenderer(size: pixels, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pixels))
            ctx.cgContext.interpolationQuality = .high
            ctx.cgContext.scaleBy(x: pixels.width / size.width, y: pixels.height / size.height)
            drawPage(page, size: size, in: ctx.cgContext)
        }
        return image.cgImage
    }

    /// Redraws the labeled PDF from the original PDF and its saved labels.
    static func labeledPDF(pdfData: Data, sheet: LabelSheet) -> Data? {
        guard let document = PDFDocument(data: pdfData), document.pageCount == sheet.pages.count else { return nil }
        return labeledPDF(document, labels: sheet.pages.map(\.labels), scales: sheet.pages.map(\.scale))
    }

    /// The original pages, unchanged (vector stays vector), with the note names on top.
    private static func labeledPDF(_ document: PDFDocument, labels: [[NoteLabelRenderer.Label]],
                                   scales: [CGFloat]) -> Data
    {
        let firstSize = document.page(at: 0).map(displaySize) ?? CGSize(width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: firstSize))
        return renderer.pdfData { ctx in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let size = displaySize(of: page)
                ctx.beginPage(withBounds: CGRect(origin: .zero, size: size), pageInfo: [:])
                drawPage(page, size: size, in: ctx.cgContext)
                NoteLabelRenderer.draw(labels[index], scale: 1 / scales[index])
            }
        }
    }
}

// MARK: - Staff of notes between the staves

/// Notes written between the two staves of a piano system — high bass notes on ledger lines,
/// low treble notes — that the recognizer gave to the wrong staff. It then read their pitch
/// against the other staff's lines, so a bass E♭4 came out as a treble F3 four ledger lines
/// down (and the bass lost the note). A note at least two ledger lines out is moved when it lies
/// nearer the other staff, or about halfway with its stem pointing at the other staff; its pitch
/// is read again from where it is printed.
nonisolated enum StaffAssignment {
    private static let steps = ["C", "D", "E", "F", "G", "A", "B"]

    /// `notes[i]` is the recognizer's position of `elements[i]`. Returns how many moved.
    static func fix(_ notes: inout [LocatedNote], elements: [XMLElementNode], score: XMLElementNode) -> Int {
        guard notes.count == elements.count,
              let measure = score.firstChild(named: "part")?.firstChild(named: "measure"),
              let attributes = measure.firstChild(named: "attributes") else { return 0 }
        // only a grand staff: treble clef above, bass clef below
        let clefs = attributes.children(named: "clef")
        func clef(_ number: String) -> String? {
            let c = clefs.first { ($0.attribute("number") ?? "1") == number }
            return c.map { ($0.firstChild(named: "sign")?.text ?? "") + ($0.firstChild(named: "line")?.text ?? "") }
        }
        guard clef("1") == "G2", clef("2") == "F4" else { return 0 }
        let fifths = Int(attributes.firstChild(named: "key")?.firstChild(named: "fifths")?.text ?? "") ?? 0

        func median(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            return values.sorted()[values.count / 2]
        }
        var moved = 0
        for system in Set(notes.map(\.system)) {
            let upper = notes.filter { $0.system == system && $0.staff == 1 }
            let lower = notes.filter { $0.system == system && $0.staff == 2 }
            guard let upperBottom = median(upper.map(\.staffBottom)), let upperTop = median(upper.map(\.staffTop)),
                  let upperSpace = median(upper.map(\.staffSpace)),
                  let lowerTop = median(lower.map(\.staffTop)), let lowerBottom = median(lower.map(\.staffBottom)),
                  let lowerSpace = median(lower.map(\.staffSpace)),
                  lowerTop > upperBottom, upperSpace > 0, lowerSpace > 0 else { continue }
            for i in notes.indices where notes[i].system == system {
                let y = Double(notes[i].rect.midY)
                var target: (staff: Int, diatonic: Int, top: Double, bottom: Double, space: Double)?
                let stem = elements[i].firstChild(named: "stem")?.text
                // nearer the other staff, or about halfway with its stem pointing at the other staff
                // (high bass notes are printed with stems down toward the bass staff)
                let towardLower = lowerTop - y < y - upperBottom
                    || (stem == "down" && lowerTop - y <= y - upperBottom + upperSpace)
                let towardUpper = y - upperBottom < lowerTop - y
                    || (stem == "up" && y - upperBottom <= lowerTop - y + lowerSpace)
                if notes[i].staff == 1, y > upperBottom + 1.75 * upperSpace, towardLower {
                    // half spaces above the bass staff's top line (A3)
                    let up = Int(((lowerTop - y) / (lowerSpace / 2)).rounded())
                    target = (2, 3 * 7 + 5 + up, lowerTop, lowerBottom, lowerSpace)
                } else if notes[i].staff == 2, y < lowerTop - 1.75 * lowerSpace, towardUpper {
                    // half spaces below the treble staff's bottom line (E4)
                    let down = Int(((y - upperBottom) / (upperSpace / 2)).rounded())
                    target = (1, 4 * 7 + 2 - down, upperTop, upperBottom, upperSpace)
                }
                guard let target, target.diatonic > 0 else { continue }
                let step = target.diatonic % 7, octave = target.diatonic / 7
                let element = elements[i]
                guard let pitch = element.firstChild(named: "pitch") else { continue }
                // a printed accidental stays with its note; else the key signature decides
                let alter = element.firstChild(named: "accidental") != nil
                    ? (Int(pitch.firstChild(named: "alter")?.text ?? "") ?? 0)
                    : ScoreCleanup.keyAlter(step: step, fifths: fifths)
                pitch.firstChild(named: "step")?.text = steps[step]
                pitch.firstChild(named: "octave")?.text = String(octave)
                if let a = pitch.firstChild(named: "alter") {
                    a.text = String(alter)
                } else if alter != 0, let at = pitch.children.firstIndex(where: { $0.name == "step" }) {
                    let a = XMLElementNode(name: "alter")
                    a.text = String(alter)
                    pitch.children.insert(a, at: at + 1)
                }
                element.firstChild(named: "staff")?.text = String(target.staff)
                notes[i] = notes[i].moved(toStaff: target.staff, step: steps[step], alter: alter, octave: octave,
                                          staffTop: target.top, staffBottom: target.bottom, staffSpace: target.space)
                moved += 1
            }
        }
        return moved
    }
}

// MARK: - Printed tempo

/// The tempo printed on the sheet, read from the PDF's text layer. PDFs exported by notation
/// programs keep "♩ = 108" (the note as a music-font glyph) or "Allegro" as text; the
/// recognizer only sees the image, so without this every upload plays at its default 90.
/// Scans and photos have no text layer and keep the default.
nonisolated enum PrintedTempo {
    struct Mark: Equatable {
        let perMinute: Double
        let beatUnit: String       // MusicXML <beat-unit>: "quarter", "half", "eighth", …
        let dots: Int
        let words: String?         // "Alla marcia", "Allegro", …

        /// Quarter notes per minute.
        var quarterBPM: Double {
            let quarters: Double = ["whole": 4, "half": 2, "quarter": 1, "eighth": 0.5, "16th": 0.25][beatUnit] ?? 1
            return perMinute * quarters * (dots > 0 ? 1.5 : 1)
        }
    }

    static func find(in document: PDFDocument) -> Mark? {
        if let mark = findInText(of: document) { return mark }
        // scans, photos and image-only PDFs: read the words printed above the first system
        return document.page(at: 0).flatMap(recognizedMark(on:))?.mark
    }

    /// A tempo in the PDF's text layer (first two pages).
    static func findInText(of document: PDFDocument) -> Mark? {
        for index in 0..<min(document.pageCount, 2) {
            if let text = document.page(at: index)?.string, let mark = find(in: text) { return mark }
        }
        return nil
    }

    /// A tempo read off the page image, with where its metronome mark is printed (page points
    /// from the top-left, as `markBounds` gives) when it is one.
    static func recognizedMark(on page: PDFPage) -> (mark: Mark, bounds: CGRect?)? {
        guard let lines = readTopOfPage(page), let mark = find(inRecognized: lines.map(\.text)) else { return nil }
        let metronome = lines.first { line in
            line.text.count <= 24 && line.text.range(of: #"=\s*\d{2,3}\b"#, options: .regularExpression) != nil
        }
        return (mark, metronome?.bounds)
    }

    /// A tempo in text recognized from the page image: the same marks as in a text layer, plus
    /// "= 120" with the note itself not read as text (taken as a quarter note).
    static func find(inRecognized all: [String]) -> Mark? {
        // the first line read is usually the title ("Slow Dancing" isn't a tempo)
        let lines = all.count >= 3 ? Array(all.dropFirst()) : all
        if let mark = find(in: lines.joined(separator: "\n")) { return mark }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count <= 24,
                  let range = trimmed.range(of: #"=\s*(\d{2,3})\b"#, options: .regularExpression),
                  let perMinute = Double(trimmed[range].filter(\.isNumber)), (30...240).contains(perMinute)
            else { continue }
            let before = trimmed[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            // the note glyph usually comes out as one or two odd characters ("J", "d", "♩"); a dot
            // after it ("J.") is a dotted note, as in 6/8
            guard before.count <= 3, !before.contains(where: \.isNumber) else { continue }
            return Mark(perMinute: perMinute, beatUnit: "quarter", dots: before.hasSuffix(".") ? 1 : 0, words: nil)
        }
        return nil
    }

    /// Text recognized on the top third of `page` (where tempo marks are printed), top to bottom,
    /// each line with its place on the page (points from the top-left). Runs on the device; nil
    /// when nothing could be read.
    static func readTopOfPage(_ page: PDFPage) -> [(text: String, bounds: CGRect)]? {
        let box = page.bounds(for: .cropBox).size
        let size = page.rotation % 180 == 0 ? box : CGSize(width: box.height, height: box.width)
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(3, 1800 / size.width)
        let crop = CGSize(width: size.width, height: size.height * 0.34)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let pixels = CGSize(width: (crop.width * scale).rounded(), height: (crop.height * scale).rounded())
        let image = UIGraphicsImageRenderer(size: pixels, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pixels))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .cropBox, to: ctx.cgContext)
        }
        guard let cg = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "it-IT"]
        do {
            try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        } catch {
            return nil
        }
        let observations = (request.results ?? []).sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
        let lines = observations.compactMap { o -> (text: String, bounds: CGRect)? in
            guard let text = o.topCandidates(1).first?.string else { return nil }
            // Vision's box is a fraction of the image, from the bottom-left
            let b = o.boundingBox
            let bounds = CGRect(x: b.minX * crop.width, y: (1 - b.maxY) * crop.height,
                                width: b.width * crop.width, height: b.height * crop.height)
            return (text, bounds)
        }
        return lines.isEmpty ? nil : lines
    }

    /// A metronome mark (a note glyph, then "= 108") anywhere in `text`, else a tempo word on
    /// a short line of its own.
    static func find(in text: String) -> Mark? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if let mark = metronome(in: line) { return mark }
        }
        // the note and "=" drawn as shapes: a tempo word ("Sentimentally") over a lone number
        let head = lines.prefix(10).map { $0.trimmingCharacters(in: .whitespaces) }
        for k in head.indices.dropFirst() {
            guard let perMinute = Double(head[k]), (30...240).contains(perMinute), head[k].allSatisfy(\.isNumber) else { continue }
            let words = head[k - 1]
            let wordCount = words.split(separator: " ").count
            guard (1...3).contains(wordCount), words.contains(where: \.isLetter), !words.contains(where: \.isNumber) else { continue }
            return Mark(perMinute: perMinute, beatUnit: "quarter", dots: 0, words: words)
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard (3...40).contains(trimmed.count), let bpm = ScoreTimeline.tempo(forWords: trimmed) else { continue }
            return Mark(perMinute: bpm, beatUnit: "quarter", dots: 0, words: trimmed)
        }
        return nil
    }

    /// A metronome mark on one line of text: a note glyph, optional dots, "=", a number.
    private static func metronome(in line: String) -> Mark? {
        guard let equals = line.range(of: #"=\s*\d{2,3}"#, options: .regularExpression) else { return nil }
        let number = line[equals].filter(\.isNumber)
        guard let perMinute = Double(number), (20...320).contains(perMinute) else { return nil }
        var scalars = Array(line[..<equals.lowerBound].unicodeScalars)
        while let last = scalars.last, CharacterSet.whitespaces.contains(last) { scalars.removeLast() }
        var dots = 0
        while let last = scalars.last, last == "." || last.value == 0xECB7 || last.value == 0x1D16D {
            dots += 1
            scalars.removeLast()
            while let l = scalars.last, CharacterSet.whitespaces.contains(l) { scalars.removeLast() }
        }
        guard let glyph = scalars.last, let unit = beatUnit(glyph) else { return nil }
        scalars.removeLast()
        let words = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "(")))
            .filter { !$0.unicodeScalars.contains { (0xE000...0xF8FF).contains($0.value) } }
        return Mark(perMinute: perMinute, beatUnit: unit, dots: min(dots, 1),
                    words: words.contains(where: \.isLetter) ? words : nil)
    }

    /// Where the metronome mark is printed on `page`, in the page's points from its top-left
    /// corner (the coordinates the page is rendered in for recognition).
    static func markBounds(on page: PDFPage) -> CGRect? {
        guard page.rotation % 360 == 0, let text = page.string else { return nil }
        let string = text as NSString
        var range: NSRange?
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: .byLines) { line, lineRange, _, stop in
            if let line, metronome(in: line) != nil {
                range = lineRange
                stop.pointee = true
            }
        }
        guard let range, let bounds = page.selection(for: range)?.bounds(for: page), !bounds.isEmpty else { return nil }
        let box = page.bounds(for: .cropBox)
        return CGRect(x: bounds.minX - box.minX, y: box.maxY - bounds.maxY, width: bounds.width, height: bounds.height)
    }

    /// The recognizer can read the note of a metronome mark ("♩ = 48") as a note of the music,
    /// which then sounds at the start of the piece. Notes read inside `mark` become hidden rests
    /// (a chord tone is removed), so the measure keeps the timing the recognizer gave it.
    /// `rects`: the noteheads of the score's pitched notes in order, in page points. Returns
    /// the indices of the notes hidden.
    /// The score's pitched notes in order — the order the recognizer reports their positions in.
    static func pitchedNotes(in score: XMLElementNode) -> [XMLElementNode] {
        pitchedNoteRefs(in: score).map(\.note)
    }

    private static func pitchedNoteRefs(in score: XMLElementNode) -> [(measure: XMLElementNode, note: XMLElementNode)] {
        var pitched: [(measure: XMLElementNode, note: XMLElementNode)] = []
        for part in score.children(named: "part") {
            for measure in part.children(named: "measure") {
                for note in measure.children(named: "note") where note.firstChild(named: "pitch") != nil {
                    pitched.append((measure, note))
                }
            }
        }
        return pitched
    }

    static func hideNotes(under mark: CGRect, at rects: [CGRect], in score: XMLElementNode) -> Set<Int> {
        let pitched = pitchedNoteRefs(in: score)
        guard pitched.count == rects.count else { return [] }
        let area = mark.insetBy(dx: -3, dy: -3)
        var hiddenIndices = Set<Int>()
        for (index, element) in pitched.enumerated() where area.intersects(rects[index]) {
            hiddenIndices.insert(index)
            if element.note.firstChild(named: "chord") != nil {
                element.measure.children.removeAll { $0 === element.note }
            } else {
                let hidden: Set<String> = ["pitch", "stem", "accidental", "tie", "notations", "beam"]
                if let i = element.note.children.firstIndex(where: { $0.name == "pitch" }) {
                    element.note.children[i] = XMLElementNode(name: "rest")
                }
                element.note.children.removeAll { hidden.contains($0.name) }
                element.note.setAttribute("print-object", "no")
            }
        }
        return hiddenIndices
    }

    private static func beatUnit(_ glyph: Unicode.Scalar) -> String? {
        switch glyph.value {
        case 0xECA2, 0x1D15D:                   return "whole"
        case 0xECA3, 0xECA4, 0x1D15E:           return "half"
        case 0xECA5, 0xECA6, 0x2669, 0x1D15F:   return "quarter"
        case 0xECA7, 0xECA8, 0x266A, 0x1D160:   return "eighth"
        case 0xECA9, 0xECAA, 0x1D161:           return "16th"
        default:
            // text fonts for music ("q = 108" in Maestro-style fonts)
            switch glyph { case "q": return "quarter"; case "h": return "half"; case "e": return "eighth"; default: return nil }
        }
    }

    /// Sets the part's tempo and prints the mark over the first measure (once).
    static func apply(_ mark: Mark, to score: XMLElementNode) {
        guard let part = score.firstChild(named: "part") else { return }
        let bpm = String(format: "%g", mark.quarterBPM)
        MusicXMLDocument.normalizeTempo(score)
        guard let first = part.firstChild(named: "measure") else { return }
        MusicXMLDocument.setTempo(bpm, in: first, replacing: true)
        guard let measure = part.firstChild(named: "measure"),
              !measure.children(named: "direction").contains(where: { direction in
                  direction.children(named: "direction-type").contains { $0.firstChild(named: "metronome") != nil }
              }) else { return }

        let direction = XMLElementNode(name: "direction", attributes: [("placement", "above")])
        if let words = mark.words {
            let type = XMLElementNode(name: "direction-type")
            let text = XMLElementNode(name: "words")
            text.text = words
            type.children.append(text)
            direction.children.append(type)
        }
        let type = XMLElementNode(name: "direction-type")
        let metronome = XMLElementNode(name: "metronome")
        let unit = XMLElementNode(name: "beat-unit")
        unit.text = mark.beatUnit
        metronome.children.append(unit)
        if mark.dots > 0 { metronome.children.append(XMLElementNode(name: "beat-unit-dot")) }
        let perMinute = XMLElementNode(name: "per-minute")
        perMinute.text = String(format: "%g", mark.perMinute)
        metronome.children.append(perMinute)
        type.children.append(metronome)
        direction.children.append(type)
        direction.children.append(XMLElementNode(name: "sound", attributes: [("tempo", bpm)]))

        let after = (measure.children.lastIndex { $0.name == "attributes" || $0.name == "print" } ?? -1) + 1
        measure.children.insert(direction, at: after)
    }
}

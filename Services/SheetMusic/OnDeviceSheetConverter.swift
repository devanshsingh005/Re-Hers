//
//  OnDeviceSheetConverter.swift
//  Re-Hearse_v1
//
//  Sheet music PDF → score JSON + MusicXML + labeled PDF, entirely on the device: OemerKit
//  runs oemer's two networks with Core ML (Neural Engine) and its recognition engine in Swift.
//  This replaces the old /convert API (Audiveris on a server) and label_notes.py.
//

import OemerKit
import PDFKit
import UIKit

/// Everything one conversion produces.
nonisolated struct SheetConversionResult {
    /// The score in the JSON shape Play Along and Animation read (`MusicXMLDocument.jsonObject`).
    let scoreJSON: Data
    let musicXML: String
    /// The input PDF with English note names under the notes.
    let labeledPDF: Data
    let noteCount: Int
    let pageCount: Int
    /// 1-based pages where no music was found; they stay unlabeled and add no measures.
    let skippedPages: [Int]
    let seconds: Double
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
        var scales: [CGFloat] = Array(repeating: 1, count: pageCount)
        var skipped: [Int] = []
        var noteCount = 0

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
                scores.append(try MusicXMLDocument.parse(result.musicXML))
                labels[index] = NoteLabelRenderer.layout(result.notes)
                noteCount += result.notes.count
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

        guard let score = MusicXMLDocument.merge(pages: scores) else { throw SheetConversionError.noMusicFound }
        score.firstChild(named: "work")?.firstChild(named: "work-title")?.text = title
        let json = MusicXMLDocument.jsonObject(score)
        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let labeledPDF = Self.labeledPDF(document, labels: labels, scales: scales)
        progress(1)
        return SheetConversionResult(scoreJSON: jsonData, musicXML: MusicXMLDocument.serialize(score),
                                     labeledPDF: labeledPDF, noteCount: noteCount, pageCount: pageCount,
                                     skippedPages: skipped, seconds: Date().timeIntervalSince(start))
    }

    // MARK: - Private

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

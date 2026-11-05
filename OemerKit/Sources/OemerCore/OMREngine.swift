import Foundation

/// The five segmentation maps produced by the two neural networks (1 = class present).
public struct SegmentationMaps {
    public var staff: Mask
    public var symbols: Mask
    public var stemsRests: Mask
    public var notehead: Mask
    public var clefsKeys: Mask

    public init(staff: Mask, symbols: Mask, stemsRests: Mask, notehead: Mask, clefsKeys: Mask) {
        precondition([symbols, stemsRests, notehead, clefsKeys].allSatisfy { $0.width == staff.width && $0.height == staff.height })
        self.staff = staff
        self.symbols = symbols
        self.stemsRests = stemsRests
        self.notehead = notehead
        self.clefsKeys = clefsKeys
    }

    public var width: Int { staff.width }
    public var height: Int { staff.height }
}

public struct OMROptions {
    /// Straighten curved/skewed pages before reading (oemer's default). Turn off for flat scans.
    public var deskew: Bool
    /// Work title written into the MusicXML.
    public var title: String

    public init(deskew: Bool = true, title: String = "Score") {
        self.deskew = deskew
        self.title = title
    }
}

public struct OMRResult {
    /// MusicXML 4.0 document (partwise), same format oemer writes.
    public let musicXML: String
    /// Every note written to the MusicXML, in document order, with its notehead box in
    /// the coordinates of the segmentation maps (see `mapToMapCoordinates`).
    public let notes: [RecognizedNote]
    /// Vertical dewarp mapping (output row -> source row) when deskewing was applied.
    public let dewarpRows: Grid<Float>?
    /// Seconds spent per stage.
    public let timings: [(stage: String, seconds: Double)]
    /// Detailed intermediate results as JSON (for testing against the Python reference).
    public let debugJSON: String?
}

public enum OMREngine {
    /// Runs oemer's full post-processing on segmentation maps and returns MusicXML.
    public static func transcribe(_ maps: SegmentationMaps, classifiers: SymbolClassifiers,
                                  options: OMROptions = OMROptions(), debug: Bool = false) throws -> OMRResult
    {
        var timings: [(String, Double)] = []
        var t0 = Date()
        func lap(_ name: String) {
            let now = Date()
            timings.append((name, now.timeIntervalSince(t0)))
            t0 = now
        }

        var f: [Grid<Float>]
        var rows: Grid<Float>? = nil
        let all = [maps.staff, maps.symbols, maps.stemsRests, maps.notehead, maps.clefsKeys]
        if options.deskew {
            let mapping = estimateDewarpMapping(maps.staff)
            f = remapVertical(all, mapping)
            rows = mapping
            lap("dewarp")
        } else {
            f = all.map(floatGrid)
        }

        let ctx = OMRContext(staff: f[0], symbols: f[1], stemsRests: f[2], notehead: f[3], clefsKeys: f[4],
                             floatMaps: options.deskew, classifiers: classifiers)
        f.removeAll()
        try ctx.extractStaffs()
        lap("staffs")
        ctx.notes = try ctx.extractNoteheads()
        ctx.registerNoteIds()
        lap("noteheads")
        ctx.extractNoteGroups()
        lap("groups")
        try ctx.extractSymbols()
        lap("symbols")
        ctx.extractRhythm()
        lap("rhythm")
        let builder = MusicXMLBuilder(ctx: ctx)
        builder.build()
        let xml = builder.toMusicXML(title: options.title)
        lap("musicxml")
        return OMRResult(musicXML: xml, notes: builder.writtenNotes, dewarpRows: rows,
                         timings: timings, debugJSON: debug ? ctx.debugJSON() : nil)
    }
}

// MARK: - Debug JSON (same structure as tools/golden_export.py)

private func j(_ v: Double) -> String {
    if v.isNaN { return "NaN" }
    if v == v.rounded() && abs(v) < 1e15 { return String(format: "%.1f", v) }
    return "\(v)"
}
private func j(_ v: Int?) -> String { v.map(String.init) ?? "null" }
private func j(_ v: Bool?) -> String { v.map { $0 ? "true" : "false" } ?? "null" }
private func j(_ v: String?) -> String { v.map { "\"\($0)\"" } ?? "null" }
private func j(_ b: BBox) -> String { "[\(b.x1), \(b.y1), \(b.x2), \(b.y2)]" }
private func j(_ a: [Int]) -> String { "[" + a.map(String.init).joined(separator: ", ") + "]" }

extension OMRContext {
    func debugJSON() -> String {
        var s = "{\n"
        s += "\"zones\": [" + staffLayout.zones.map { "[\($0.lowerBound), \($0.upperBound)]" }.joined(separator: ", ") + "],\n"
        var cols: [String] = []
        for col in staffLayout.grid {
            var items: [String] = []
            for st in col {
                var e = "{\"y_center\": \(j(st.yCenter)), \"y_upper\": \(j(st.yUpper)), \"y_lower\": \(j(st.yLower)), "
                e += "\"x_left\": \(j(st.xLeft)), \"x_right\": \(j(st.xRight)), \"unit_size\": \(j(st.unitSize)), "
                e += "\"track\": \(st.track), \"group\": \(st.group), \"is_interp\": \(j(st.isInterp)), "
                let centers: [String] = st.lines.map { j($0.yCenter) }
                e += "\"line_centers\": [" + centers.joined(separator: ", ") + "], "
                e += "\"line_points\": " + j(st.lines.map { $0.count }) + "}"
                items.append(e)
            }
            cols.append("[" + items.joined(separator: ", ") + "]")
        }
        s += "\"staffs\": [" + cols.joined(separator: ",\n") + "],\n"
        var noteItems: [String] = []
        for n in notes {
            var e = "{\"id\": \(n.id), \"bbox\": \(j(n.bbox)), \"staff_line_pos\": \(n.staffLinePos), "
            e += "\"label\": \(j(n.rawLabel?.pyName)), "
            e += "\"stem_up\": \(j(n.stemUp)), \"stem_right\": \(j(n.stemRight)), \"has_dot\": \(j(n.hasDot)), "
            e += "\"invalid\": \(j(n.invalid)), \"track\": \(n.track), \"group\": \(n.group), "
            e += "\"note_group_id\": \(j(n.noteGroupId)), \"sfn\": \(j(n.sfn?.pyName))}"
            noteItems.append(e)
        }
        s += "\"notes\": [\n" + noteItems.joined(separator: ",\n") + "],\n"
        var groupItems: [String] = []
        for g in groups {
            var e = "{\"id\": \(g.id), \"bbox\": \(j(g.bbox)), \"note_ids\": \(j(g.noteIds)), "
            e += "\"top_note_ids\": \(j(g.topNoteIds)), "
            e += "\"bottom_note_ids\": \(j(g.bottomNoteIds)), \"stem_up\": \(j(g.stemUp)), \"has_stem\": \(j(g.hasStem)), "
            e += "\"all_same_type\": \(j(g.allSameType)), \"track\": \(g.track), \"group\": \(g.group)}"
            groupItems.append(e)
        }
        s += "\"groups\": [\n" + groupItems.joined(separator: ",\n") + "],\n"
        s += "\"barlines\": [" + barlines.map { "{\"bbox\": \(j($0.bbox)), \"group\": \($0.group)}" }.joined(separator: ", ") + "],\n"
        s += "\"clefs\": [" + clefs.map { "{\"bbox\": \(j($0.bbox)), \"label\": \"\($0.label.pyName)\", \"track\": \($0.track), \"group\": \($0.group)}" }.joined(separator: ", ") + "],\n"
        s += "\"sfns\": [" + sfns.map { "{\"bbox\": \(j($0.bbox)), \"label\": \"\($0.label.pyName)\", \"note_id\": \(j($0.noteId)), \"is_key\": \(j($0.isKey)), \"track\": \($0.track), \"group\": \($0.group)}" }.joined(separator: ", ") + "],\n"
        s += "\"rests\": [" + rests.map { "{\"bbox\": \(j($0.bbox)), \"label\": \"\($0.label.pyName)\", \"has_dot\": \(j($0.hasDot)), \"track\": \($0.track), \"group\": \($0.group)}" }.joined(separator: ", ") + "]\n"
        s += "}\n"
        return s
    }
}

import Foundation

// Port of oemer/symbol_extraction.py

public enum ClefType: Int {
    case gClef = 1, fClef = 2
    var pyName: String { self == .gClef ? "G_CLEF" : "F_CLEF" }
}

public enum RestType: Int {
    case wholeHalf = 1, quarter, eighth, sixteenth, thirtySecond, sixtyFourth, whole, half
    var pyName: String {
        switch self {
        case .wholeHalf: return "WHOLE_HALF"
        case .quarter: return "QUARTER"
        case .eighth: return "EIGHTH"
        case .sixteenth: return "SIXTEENTH"
        case .thirtySecond: return "THIRTY_SECOND"
        case .sixtyFourth: return "SIXTY_FOURTH"
        case .whole: return "WHOLE"
        case .half: return "HALF"
        }
    }
}

/// Anything placed in a measure: voices, rests, clefs, accidentals/keys.
class MeasureSymbol {
    var bbox: BBox
    var track = 0
    var group = 0
    init(bbox: BBox) { self.bbox = bbox }
    var xCenter: Double { Double(bbox.x1 + bbox.x2) / 2 }
}

final class Barline: MeasureSymbol {}

final class Clef: MeasureSymbol {
    var label: ClefType = .gClef
}

final class Sfn: MeasureSymbol {
    var label: SfnType = .sharp
    var noteId: Int? = nil
    var isKey: Bool? = nil
    /// Line/space position of the pitch it alters on its staff (see `staffLinePosition`);
    /// set outside parity mode.
    var linePos: Int? = nil
}

final class Rest: MeasureSymbol {
    var label: RestType = .quarter
    var hasDot: Bool? = nil
    /// Rests inserted by the measure builder carry a float center.
    var xCenterOverride: Double? = nil
    override var xCenter: Double { xCenterOverride ?? super.xCenter }
}

extension OMRContext {
    /// `filter_out_of_range_bbox(bboxes)`
    func filterOutOfRange(_ bboxes: [BBox]) -> [BBox] {
        let maxX = zoneMaxX, minX = zoneMinX
        return bboxes.filter { b in
            let cx = pyRound(Double(b.x1 + b.x2) / 2)
            return !(cx > maxX || cx < minX)
        }
    }

    /// `filter_out_small_area(bboxes, area_size_func=...)`
    func filterOutSmallArea(_ bboxes: [BBox], _ sizeFunc: (Double) -> Double) -> [BBox] {
        bboxes.filter { b in
            let w = Double(b.x2 - b.x1), h = Double(b.y2 - b.y1)
            return w * h > sizeFunc(unitSize(b.center))
        }
    }

    /// `parse_barlines(...)`
    func parseBarlines(minHeightUnitRatio: Double = 3.75) -> [BBox] {
        let n = width * height
        var barCand = Mask.zeros(width: width, height: height)
        var noNote = Mask.zeros(width: width, height: height)
        for i in 0..<n {
            let g = groupMap.data[i]
            // float32 map - int group map -> float64 in numpy
            if Double(stemsF.data[i]) - Double(g) > 1 { barCand.data[i] = 1 }
            if Double(symbolsF.data[i]) - Double(g) > 1 { noNote.data[i] = 1 }
        }
        let (symLabel, symN) = labelRegions(noNote)
        var hit = [Bool](repeating: false, count: symN + 1)
        for i in 0..<n where barCand.data[i] != 0 { hit[Int(symLabel.data[i])] = true }
        var symBarline = Mask.zeros(width: width, height: height)
        for i in 0..<n {
            let l = Int(symLabel.data[i])
            if l != 0 && hit[l] { symBarline.data[i] = 1 }
        }
        let lines = findLines(symBarline)
        return filterBarlines(lines, minHeightUnitRatio: minHeightUnitRatio)
    }

    /// `filter_barlines(lines, min_height_unit_ratio)`
    func filterBarlines(_ linesIn: [BBox], minHeightUnitRatio: Double) -> [BBox] {
        var lines = filterOutOfRange(linesIn)
        lines = rmMergeOverlapBBoxes(lines, merge: true, overlapRatio: 0)
        var validLines: [BBox] = []
        var unitSizeLast = Double.nan
        for line in lines {
            unitSizeLast = unitSize(line.center)
            let deg = atan2(Double(line.y2 - line.y1), Double(line.x2 - line.x1)) * 180 / Double.pi
            if abs(deg) < 75 { continue }
            validLines.append(line)
        }
        if validLines.isEmpty { return [] }
        let maxX = validLines.map { $0.x2 }.max()!
        let maxY = validLines.map { $0.y2 }.max()!
        var canvas = Mask.zeros(width: maxX + 10, height: maxY + 10)
        for l in validLines {
            linePixels(width: canvas.width, height: canvas.height, (l.x1, l.y1), (l.x2, l.y2)) { x, y in
                canvas[y, x] = 1
            }
        }
        let boxes = getBBoxes(canvas)
        var validBox: [BBox] = []
        for b in boxes where !(Double(b.y2 - b.y1) < unitSizeLast * minHeightUnitRatio) {
            validBox.append(b)
        }
        validBox = validBox.enumerated()
            .sorted { ($0.element.y2 - $0.element.y1, $0.offset) < ($1.element.y2 - $1.element.y1, $1.offset) }
            .map { $0.element }
        let heights = validBox.map { Double($0.y2 - $0.y1) }
        let top5 = npMean(Array(heights.suffix(5)))
        return validBox.indices.filter { heights[$0] / top5 > 0.5 }.map { validBox[$0] }
    }

    /// `parse_clefs_keys(clefs_keys, unit_size)`
    func parseClefsKeys(unitSize globalU: Double, clefSizeRatio: Double = 3.5, maxClefTpRatio: Double = 0.45)
        throws -> (clefBox: [BBox], keyBox: [BBox], clefLabel: [String], keyLabel: [String])
    {
        let kh = Int((globalU / 2).rounded(.down))
        var ck = clefsTrunc
        if kh > 0 {
            let ker = StructuringElement.rect(width: 1, height: kh)
            ck = erode(dilate(clefsTrunc, ker), ker)
        }
        var bboxes = getBBoxes(ck)
        bboxes = filterOutOfRange(bboxes)
        try checkCandidateCount(bboxes.count)
        bboxes = rmMergeOverlapBBoxes(bboxes, merge: true, overlapRatio: 0.3)
        bboxes = filterOutSmallArea(bboxes) { $0 * $0 }
        bboxes = mergeNearbyBBoxes(bboxes, distance: globalU * 1.2)

        var keyBox: [BBox] = []
        var clefBox: [BBox] = []
        for b in bboxes {
            let w = Double(b.x2 - b.x1), h = Double(b.y2 - b.y1)
            let us = unitSize(b.center)
            let areaSizeRatio = w * h / (us * us)
            let tp = Double(ck.countNonZero(x1: b.x1, y1: b.y1, x2: b.x2, y2: b.y2)) / (w * h)
            if areaSizeRatio > clefSizeRatio && tp < maxClefTpRatio {
                clefBox.append(b)
            } else if w > us / 2 && h > us / 2 {
                keyBox.append(b)
            }
        }
        // filter_clef_box
        clefBox = clefBox.filter { b in
            let w = Double(b.x2 - b.x1), h = Double(b.y2 - b.y1)
            let c = b.center
            let u = unitSize(c)
            if w < u * 1.5 || h < u * 1.5 { return false }
            let (st, _) = findClosestStaffs(Double(c.x), Double(c.y))
            return !(Double(c.y) < st.yUpper || Double(c.y) > st.yLower)
        }
        func region(_ b: BBox) -> Grid<Int32> {
            let (rows, cols) = sliceRanges(b, width: width, height: height)
            var g = Grid<Int32>(width: cols.count, height: rows.count, repeating: 0)
            for (ry, y) in rows.enumerated() {
                for (rx, x) in cols.enumerated() { g[ry, rx] = Int32(ck[y, x]) }
            }
            return g
        }
        let clefLabel = clefBox.map { classifiers.clef.predict(region: region($0)) }
        let keyLabel = keyBox.map { classifiers.sfn.predict(region: region($0)) }
        return (clefBox, keyBox, clefLabel, keyLabel)
    }

    /// `parse_rests(line_box, unit_size)`
    func parseRests(lineBox: [BBox], unitSize globalU: Double) throws -> ([BBox], [String]) {
        // rests = stems_rests - g_map - data (float64 in numpy); rests[rests < 0] = 0
        var rests = Grid<Double>(width: width, height: height, repeating: 0)
        var barMask = Mask.zeros(width: width, height: height)
        for b in lineBox {
            let (rows, cols) = sliceRanges(b, width: width, height: height)
            for y in rows { for x in cols { barMask[y, x] = 1 } }
        }
        var restMask = Mask.zeros(width: width, height: height)  // rests.astype(np.uint8) != 0
        for i in 0..<(width * height) {
            let v = Double(stemsF.data[i]) - (groupMap.data[i] > -1 ? 1 : 0) - Double(barMask.data[i])
            if v > 0 {
                rests.data[i] = v
                if v >= 1 { restMask.data[i] = 1 }
            }
        }
        var bboxes = filterOutOfRange(getBBoxes(restMask))
        if bboxes.isEmpty { return ([], []) }
        try checkCandidateCount(bboxes.count)
        bboxes = mergeNearbyBBoxes(bboxes, distance: globalU * 1.2)
        bboxes = rmMergeOverlapBBoxes(bboxes)
        bboxes = filterOutSmallArea(bboxes) { $0 * $0 * 0.7 }

        var labels: [String] = []
        var valid: [BBox] = []
        for b in bboxes {
            if Double(b.y2 - b.y1) > globalU * 3.5 || Double(b.x2 - b.x1) < globalU * 0.5 { continue }
            let (rows, cols) = sliceRanges(b, width: width, height: height)
            // predict() scales the view in place when its max is 1 — keep that side effect
            var maxV = -Double.infinity
            for y in rows { for x in cols { maxV = max(maxV, rests[y, x]) } }
            if maxV == 1 {
                for y in rows { for x in cols { rests[y, x] *= 255 } }
            }
            // Image.fromarray(region.astype(np.uint8)): truncation toward zero
            var g = Grid<UInt8>(width: cols.count, height: rows.count, repeating: 0)
            for (ry, y) in rows.enumerated() {
                for (rx, x) in cols.enumerated() { g[ry, rx] = UInt8(truncatingIfNeeded: Int(rests[y, x])) }
            }
            var pred = classifiers.rests.predict(pixels: g)
            if pred.contains("8th") { pred = classifiers.restsAbove8.predict(pixels: g) }
            valid.append(b)
            labels.append(pred)
        }
        return (valid, labels)
    }

    /// Height of the pitch an accidental marks: a flat's is its bowl, half a staff space above
    /// its bottom (the stem rises above it); sharps and naturals are centered on it.
    func accidentalPitchY(_ b: BBox, _ label: SfnType) -> Double {
        let mid = Double(b.y1 + b.y2) / 2
        guard label == .flat else { return mid }
        let u = unitSize(b.center)
        return u > 0 && u.isFinite ? max(Double(b.y2) - u / 2, mid) : mid
    }

    /// The note an accidental belongs to. oemer scans a single row (the accidental's middle)
    /// for one staff space to the right, which misses noteheads a little above or below it and
    /// picks an arbitrary chord tone. Outside parity mode the window reaches 2.5 staff spaces to
    /// the right and 0.75 above and below, and among the noteheads in it the one whose middle is
    /// nearest the accidental's pitch height wins (then the nearest to the left).
    func nearbyNoteId(_ b: BBox, label: SfnType) -> Int? {
        if pythonParity { return nearbyNoteIdPython(b) }
        let u = unitSize(b.center)
        guard u > 0, u.isFinite else { return nil }
        let x1 = max(b.x2, 0), x2 = min(b.x2 + Int(2.5 * u), width)
        let y1 = max(b.y1 - Int(0.75 * u), 0), y2 = min(b.y2 + Int(0.75 * u), height - 1)
        guard x1 < x2, y1 <= y2 else { return nil }
        var found = Set<Int>()
        for y in y1...y2 {
            for x in x1..<x2 {
                let v = Int(noteIdMap[y, x])
                if v >= 0 && v < notes.count && !notes[v].invalid { found.insert(v) }
            }
        }
        let pitchY = accidentalPitchY(b, label)
        return found.min { a, c in
            let na = notes[a].bbox, nc = notes[c].bbox
            let da = abs(Double(na.y1 + na.y2) / 2 - pitchY), dc = abs(Double(nc.y1 + nc.y2) / 2 - pitchY)
            if da != dc { return da < dc }
            if na.x1 != nc.x1 { return na.x1 < nc.x1 }
            return a < c
        }
    }

    /// `get_nearby_note_id(box, note_id_map)`
    private func nearbyNoteIdPython(_ b: BBox) -> Int? {
        let c = b.center
        let u = pyRound(unitSize(c))
        if u <= 0 { return nil }
        for x in b.x2..<(b.x2 + u) {
            guard c.y >= 0 && c.y < height && x >= 0 && x < width else { continue }
            let v = noteIdMap[c.y, x]
            if v != -1 { return Int(v) }
        }
        return nil
    }

    /// `symbol_extraction.extract()` — sets barlines, clefs, sfns and rests.
    func extractSymbols(minBarlineHUnitRatio: Double = 3.75) throws {
        let lineBox = parseBarlines(minHeightUnitRatio: minBarlineHUnitRatio)
        barlines = lineBox.map { b in
            let bl = Barline(bbox: b)
            let c = b.center
            bl.group = findClosestStaffs(Double(c.x), Double(c.y)).0.group
            return bl
        }

        let u = globalUnitSize
        let (clefBox, keyBox, clefLabel, keyLabel) = try parseClefsKeys(unitSize: u)
        clefs = zip(clefBox, clefLabel).map { b, l in
            let c = Clef(bbox: b)
            c.label = l == "gclef" ? .gClef : .fClef
            let st = findClosestStaffs(Double(b.center.x), Double(b.center.y)).0
            c.track = st.track
            c.group = st.group
            if !pythonParity { c.label = checkedClefLabel(c.label, box: b, staff: st) }
            return c
        }
        sfns = zip(keyBox, keyLabel).map { b, l in
            let s = Sfn(bbox: b)
            s.label = l == "sharp" ? .sharp : (l == "flat" ? .flat : .natural)
            let st = findClosestStaffs(Double(b.center.x), Double(b.center.y)).0
            s.noteId = nearbyNoteId(b, label: s.label)
            s.track = st.track
            s.group = st.group
            if !pythonParity {
                bindAccidental(s, staff: st)
                return s
            }
            if let nid = s.noteId {
                let note = notes[nid]
                if s.track != note.track {
                    note.invalid = true
                } else if s.group != note.group {
                    note.invalid = true
                } else {
                    note.sfn = s.label
                    s.isKey = false
                }
            }
            return s
        }

        let (restBox, restLabel) = try parseRests(lineBox: lineBox, unitSize: u)
        rests = makeRests(restBox, restLabel)
    }

    /// Outside parity mode: an accidental next to a note of its system alters that note; when
    /// its own nearest staff is the other staff of the system (it sits between them), it takes
    /// the note's staff. oemer instead invalidated (dropped) the note in that case. Its pitch
    /// position is recorded either way, for key signatures and for binding it later.
    private func bindAccidental(_ s: Sfn, staff st: Staff) {
        if let nid = s.noteId {
            let note = notes[nid]
            if note.group == s.group {
                s.track = note.track
                note.sfn = s.label
                s.isKey = false
            } else {
                s.noteId = nil
            }
        }
        let cx = Double(s.bbox.center.x)
        let staff = staffSegment(group: s.group, track: s.track, x: cx) ?? st
        s.linePos = staffLinePosition(accidentalPitchY(s.bbox, s.label), on: staff)
    }

    /// The classifier only returns a label; the glyph's height is a second opinion. A G clef
    /// reaches well above and below the staff (about 7 staff spaces), an F clef sits in its upper
    /// part (about 3.5). The height may only move a clef toward its staff's usual one (G on even
    /// tracks, F on odd: treble and bass on piano), so a G clef that is short because part of it
    /// was lost is not turned into an F clef, while a short "G" on the bass staff is.
    private func checkedClefLabel(_ label: ClefType, box b: BBox, staff st: Staff) -> ClefType {
        let u = st.unitSize
        guard u > 0, u.isFinite else { return label }
        let spaces = Double(b.y2 - b.y1) / u
        let usual: ClefType = st.track % 2 == 0 ? .gClef : .fClef
        if usual == .fClef && label == .gClef && spaces <= 4.5 { return .fClef }
        if usual == .gClef && label == .fClef && spaces >= 5.5 { return .gClef }
        return label
    }

    private func makeRests(_ restBox: [BBox], _ restLabel: [String]) -> [Rest] {
        return zip(restBox, restLabel).map { b, l in
            let r = Rest(bbox: b)
            switch l {
            case "rest_whole": r.label = .wholeHalf
            case "rest_quarter": r.label = .quarter
            case "rest_8th": r.label = .eighth
            case "rest_16th": r.label = .sixteenth
            case "rest_32nd": r.label = .thirtySecond
            default: r.label = .sixtyFourth
            }
            let c = b.center
            let st = findClosestStaffs(Double(c.x), Double(c.y)).0
            r.track = st.track
            r.group = st.group
            let us = pyRound(unitSize(c))
            let lo = b.x2 + 1
            let hi = min(b.x2 + us, width - 1)
            // np.sum(symbols[y1:y2, range]) — a contiguous copy, summed pairwise in float32
            var vals: [Float] = []
            if lo < hi {
                let rows = sliceRanges(b, width: width, height: height).rows
                for y in rows { for x in lo..<hi { vals.append(symbolsF[y, x]) } }
            }
            let limit = Double(us * us) / 7
            let hasDot: Bool
            if floatMaps {
                let s = npSumF(vals)
                hasDot = 0 < s && s < Float(limit)
            } else {
                let s = vals.reduce(0.0) { $0 + Double($1) }
                hasDot = 0 < s && s < limit
            }
            if hasDot { r.hasDot = true }
            return r
        }
    }
}

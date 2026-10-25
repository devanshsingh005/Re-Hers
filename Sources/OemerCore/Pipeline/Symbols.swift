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

    /// `get_nearby_note_id(box, note_id_map)`
    private func nearbyNoteId(_ b: BBox) -> Int? {
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
            return c
        }
        sfns = zip(keyBox, keyLabel).map { b, l in
            let s = Sfn(bbox: b)
            s.label = l == "sharp" ? .sharp : (l == "flat" ? .flat : .natural)
            let st = findClosestStaffs(Double(b.center.x), Double(b.center.y)).0
            s.noteId = nearbyNoteId(b)
            s.track = st.track
            s.group = st.group
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
        rests = zip(restBox, restLabel).map { b, l in
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

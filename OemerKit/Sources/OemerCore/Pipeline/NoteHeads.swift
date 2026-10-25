// Port of oemer/notehead_extraction.py

public enum NoteType: Int, CaseIterable {
    case whole = 0, half, quarter, eighth, sixteenth, thirtySecond, sixtyFourth, triplet, others
    case halfOrWhole = 9

    /// Python enum member name (used in debug/golden output).
    var pyName: String {
        switch self {
        case .whole: return "WHOLE"
        case .half: return "HALF"
        case .quarter: return "QUARTER"
        case .eighth: return "EIGHTH"
        case .sixteenth: return "SIXTEENTH"
        case .thirtySecond: return "THIRTY_SECOND"
        case .sixtyFourth: return "SIXTY_FOURTH"
        case .triplet: return "TRIPLET"
        case .others: return "OTHERS"
        case .halfOrWhole: return "HALF_OR_WHOLE"
        }
    }
}

public enum SfnType: Int {
    case flat = 1, sharp = 2, natural = 3

    var pyName: String {
        switch self {
        case .flat: return "FLAT"
        case .sharp: return "SHARP"
        case .natural: return "NATURAL"
        }
    }
}

final class NoteHead {
    var bbox: BBox
    var hasDot = false
    var stemUp: Bool? = nil
    var stemRight: Bool? = nil
    var track: Int = 0
    var group: Int = 0
    var staffLinePos: Int = 0
    var invalid = false
    var id: Int = -1
    var noteGroupId: Int? = nil
    var sfn: SfnType? = nil
    var rawLabel: NoteType? = nil

    init(bbox: BBox) { self.bbox = bbox }

    /// `label` property: None when invalid; setting only works while unset.
    var label: NoteType? {
        get { invalid ? nil : rawLabel }
        set { if rawLabel == nil { rawLabel = newValue } }
    }

    func forceSetLabel(_ l: NoteType) { rawLabel = l }
}

private let noteheadMorphWidthFactor = 0.5
private let noteheadMorphHeightFactor = 0.4
let noteheadSizeRatio = 1.285714
private let clefZoneWidthUnitRatio = 4.5406916

/// `morph_notehead(pred, unit_size)`
func morphNotehead(_ pred: Mask, unitSize: Double) -> Mask {
    let small = pyRound(unitSize / 3)
    let smallKer = StructuringElement.ellipse(width: max(small, 1), height: max(small, 1))
    let closed = erode(dilate(pred, smallKer), smallKer)
    let w = pyRound(unitSize * noteheadMorphWidthFactor)
    let h = pyRound(unitSize * noteheadMorphHeightFactor)
    let img = erode(closed, StructuringElement.ellipse(width: max(w, 1), height: max(h, 1)))
    return dilate(img, StructuringElement.ellipse(width: w + 1, height: h + 1))
}

/// `adjust_bbox(bbox, noteheads)`
private func adjustBBox(_ b: BBox, _ noteheads: Mask) -> BBox? {
    let (rows, cols) = sliceRanges(b, width: noteheads.width, height: noteheads.height)
    var minR = Int.max, maxR = Int.min
    for y in rows {
        let row = y * noteheads.width
        for x in cols where noteheads.data[row + x] != 0 {
            minR = min(minR, y - rows.lowerBound)
            maxR = max(maxR, y - rows.lowerBound)
            break
        }
    }
    if minR == Int.max { return nil }
    return BBox(b.x1, minR + b.y1 - 1, b.x2, maxR + b.y1 + 1)
}

/// `check_bbox_size(bbox, noteheads, unit_size)`
func checkBBoxSize(_ b: BBox, _ noteheads: Mask, _ unitSize: Double) -> [BBox] {
    let w = Double(b.x2 - b.x1)
    let h = b.y2 - b.y1
    let cenX = b.center.x
    let noteW = noteheadSizeRatio * unitSize
    let noteH = unitSize
    var newBoxes: [BBox] = []
    if abs(w - noteW) > abs(w - noteW * 2) {
        let left = adjustBBox(BBox(b.x1, b.y1, cenX, b.y2), noteheads)
        let right = adjustBBox(BBox(cenX, b.y1, b.x2, b.y2), noteheads)
        if let l = left { newBoxes += checkBBoxSize(l, noteheads, unitSize) }
        if let r = right { newBoxes += checkBBoxSize(r, noteheads, unitSize) }
    }
    if !newBoxes.isEmpty {
        var tmp: [BBox] = []
        for box in newBoxes { tmp += checkBBoxSize(box, noteheads, unitSize) }
        newBoxes = tmp
    } else {
        let numNotes = pyRound(Double(h) / noteH)
        if numNotes > 0 {
            let subH = pyFloorDiv(h, numNotes)
            for i in 0..<numNotes {
                newBoxes.append(BBox(b.x1, b.y1 + i * subH, b.x2, b.y1 + (i + 1) * subH))
            }
        }
    }
    return newBoxes
}

/// `fill_hole(region)` — including the original's column scan nested inside the row loop.
/// Works on the raw (possibly float) values with the original comparisons: the first and third
/// scans stop at `> 0`, the second at `== 0` (so small negative values behave like ink there).
func fillHole(_ region: Grid<Float>) -> Grid<Float> {
    var tar = region
    let h = tar.height, w = tar.width
    for yi in 0..<h {
        var cur = 0
        while cur < w && !(tar[yi, cur] > 0) { cur += 1 }
        while cur < w && tar[yi, cur] != 0 { cur += 1 }
        var cand: [Int] = []
        while cur < w && !(tar[yi, cur] > 0) {
            cand.append(cur)
            cur += 1
        }
        if cur < w { for x in cand { tar[yi, x] = 1 } }

        for xi in 0..<w {
            var c = 0
            while c < h && !(tar[c, xi] > 0) { c += 1 }
            while c < h && tar[c, xi] != 0 { c += 1 }
            var candY: [Int] = []
            while c < h && !(tar[c, xi] > 0) {
                candY.append(c)
                c += 1
            }
            if c < h { for y in candY { tar[y, xi] = 1 } }
        }
    }
    return tar
}

extension OMRContext {
    /// `filter_notehead_bbox(...)`
    func filterNoteheadBBoxes(_ bboxes: [BBox], _ notehead: Mask, minHRatio: Double, maxHRatio: Double,
                              minWRatio: Double, maxWRatio: Double, minAreaRatio: Double) -> [BBox]
    {
        let minX = zoneMinX, maxX = zoneMaxX
        var valid: [BBox] = []
        for b in bboxes {
            let c = b.center
            let u = unitSize(c)
            if Double(c.x) < Double(minX) + clefZoneWidthUnitRatio * u || c.x > maxX { continue }
            let h = Double(b.y2 - b.y1), w = Double(b.x2 - b.x1)
            if h < u * minHRatio || h > u * maxHRatio { continue }
            if w < u * minWRatio * noteheadSizeRatio || w > u * maxWRatio * noteheadSizeRatio { continue }
            let minCount = h * w * minAreaRatio
            if Double(notehead.countNonZero(x1: b.x1, y1: b.y1, x2: b.x2, y2: b.y2)) < minCount { continue }
            valid.append(b)
        }
        return valid
    }

    /// `get_notehead_bbox(pred, global_unit_size, ...)` — morphing uses `pred.astype(np.uint8)`,
    /// the box size check uses `pred > 0`.
    func noteheadBBoxes(globalUnitSize: Double, minHRatio: Double, maxHRatio: Double,
                        minWRatio: Double, maxWRatio: Double, minAreaRatio: Double) -> [BBox]
    {
        let note = morphNotehead(noteheadTrunc, unitSize: globalUnitSize)
        let bboxes = rmMergeOverlapBBoxes(getBBoxes(note))
        var result: [BBox] = []
        for b in bboxes { result += checkBBoxSize(b, noteheadPos, unitSize(b.center)) }
        return filterNoteheadBBoxes(result, note, minHRatio: minHRatio, maxHRatio: maxHRatio,
                                    minWRatio: minWRatio, maxWRatio: maxWRatio, minAreaRatio: minAreaRatio)
    }

    /// `gen_notes(bboxes, symbols)`
    func genNotes(_ bboxes: [BBox]) -> [NoteHead] {
        var notes: [NoteHead] = []
        for b in bboxes {
            let nn = NoteHead(bbox: b)
            let c = b.center
            let cx = Double(c.x), cy = Double(c.y)
            let (st1, st2) = findClosestStaffs(cx, cy)
            let master: Staff
            if st1.yCenter == st2.yCenter || (st1.yUpper <= cy && cy <= st1.yLower) {
                master = st1
            } else {
                let (up, lo) = st1.yCenter < st2.yCenter ? (st1, st2) : (st2, st1)
                master = cy < (up.yCenter + lo.yCenter) / 2 ? up : lo
            }
            nn.group = master.group
            nn.track = master.track

            let step = master.unitSize / 2
            let base = master.lines.reversed().map { $0.yCenter }
            var posCen: [Double] = []
            for (i, v) in base.enumerated() {
                posCen.append(v)
                if i + 1 < base.count { posCen.append((v + base[i + 1]) / 2) }
            }
            posCen = [posCen[0] + step] + posCen + [posCen[posCen.count - 1] - step]
            var posIdx = 0
            var best = Double.infinity
            for (i, v) in posCen.enumerated() where abs(v - cy) < best {
                best = abs(v - cy)
                posIdx = i
            }
            if posIdx > 0 && posIdx < posCen.count - 1 {
                nn.staffLinePos = posIdx
            } else if posIdx == 0 {
                nn.staffLinePos = -pyRound(abs(posCen[0] - cy) / step)
            } else {
                nn.staffLinePos = pyRound(abs(posCen[posCen.count - 1] - cy) / step) + posCen.count - 1
            }
            notes.append(nn)
        }
        return notes
    }

    /// `parse_stem_info(notes)`
    func parseStemInfo(_ notes: [NoteHead]) {
        let enhanced = dilate(stemsTrunc, StructuringElement.rect(width: 2, height: 3))
        let (stMap, n) = labelRegions(enhanced)
        var sumX = [Int](repeating: 0, count: n + 1)
        var cnt = [Int](repeating: 0, count: n + 1)
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                let l = Int(stMap.data[row + x])
                if l != 0 { sumX[l] += x; cnt[l] += 1 }
            }
        }
        for note in notes {
            let (rows, cols) = sliceRanges(note.bbox, width: width, height: height)
            var lls = PySet(uniqueValues(stMap, rows: rows, cols: cols))
            lls.discard(0)
            guard let label = lls.pop() else { continue }
            let stCenX = Double(sumX[label]) / Double(cnt[label])
            let cenX = Double(note.bbox.x1 + note.bbox.x2) / 2
            note.stemRight = stCenX > cenX
        }
    }

    /// `notehead_extraction.extract()`
    func extractNoteheads(minHRatio: Double = 0.4, maxHRatio: Double = 5, minWRatio: Double = 0.3,
                          maxWRatio: Double = 3, minAreaRatio: Double = 0.5,
                          maxWholeNoteWidthFactor: Double = 1.5, yDistFactor: Double = 5,
                          hollowFilledRatioTh: Double = 1.3) throws -> [NoteHead]
    {
        let u = globalUnitSize
        let bboxes = noteheadBBoxes(globalUnitSize: u, minHRatio: minHRatio, maxHRatio: maxHRatio,
                                    minWRatio: minWRatio, maxWRatio: maxWRatio, minAreaRatio: minAreaRatio)
        try checkCandidateCount(bboxes.count)
        let merged = mergeNearbyBBoxes(bboxes, distance: u * maxWholeNoteWidthFactor, yFactor: yDistFactor)
        var solid: [BBox] = []
        var hollow: [BBox] = []
        for mb in merged {
            let b = BBox(mb.x1 - 1, mb.y1 - 1, mb.x2 - 1, mb.y2 - 1)
            let (rows, cols) = sliceRanges(b, width: width, height: height)
            var region = Grid<Float>(width: cols.count, height: rows.count, repeating: 0)
            var count = 0
            for (ry, y) in rows.enumerated() {
                for (rx, x) in cols.enumerated() {
                    let v = symbolsF[y, x]
                    region[ry, rx] = v
                    if v > 0 { count += 1 }
                }
            }
            if count == 0 { continue }
            let filled = fillHole(region)
            let fCount = filled.data.reduce(0) { $0 + ($1 > 0 ? 1 : 0) }
            if Double(fCount) / Double(count) > hollowFilledRatioTh {
                hollow.append(b)
            } else {
                solid.append(b)
            }
        }
        let solidNotes = genNotes(solid)
        let hollowNotes = genNotes(hollow)
        for n in hollowNotes { n.label = .halfOrWhole }
        let notes = solidNotes + hollowNotes
        parseStemInfo(notes)
        return notes
    }

    /// `register_note_id()` — note id of every symbol pixel inside each note's box
    /// (later notes overwrite earlier ones, as in the original).
    func registerNoteIds() {
        for (idx, note) in notes.enumerated() {
            note.id = idx
            let b = note.bbox
            let (rows, cols) = sliceRanges(b, width: width, height: height)
            for (ry, y) in rows.enumerated() {
                for (rx, x) in cols.enumerated() where symbolsF[y, x] > 0 {
                    // numpy: layer[ry + y1, rx + x1] with negative indices wrapping
                    var ty = ry + b.y1, tx = rx + b.x1
                    if ty < 0 { ty += height }
                    if tx < 0 { tx += width }
                    if ty >= 0 && ty < height && tx >= 0 && tx < width { noteIdMap[ty, tx] = Int32(idx) }
                }
            }
        }
    }
}

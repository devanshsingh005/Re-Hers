import Foundation

// Port of oemer/staffline_extraction.py and the staff helpers in oemer/utils.py.

/// One detected staff line (a set of pixels close to one horizontal peak).
final class StaffLine {
    var ys: [Double] = []
    var xs: [Double] = []
    var label: Int? = nil

    func addPoint(y: Double, x: Double) {
        ys.append(y)
        xs.append(x)
    }

    var count: Int { ys.count }
    lazy var yCenter: Double = npMean(ys)
    lazy var yUpper: Double = ys.min() ?? .nan
    lazy var yLower: Double = ys.max() ?? .nan
    lazy var xCenter: Double = npMean(xs)
    lazy var xLeft: Double = xs.min() ?? .nan
    lazy var xRight: Double = xs.max() ?? .nan
}

/// Five staff lines within one horizontal zone of the page.
public final class Staff {
    var lines: [StaffLine] = []
    public internal(set) var track: Int = 0
    public internal(set) var group: Int = 0
    var isInterp = false

    private var _yCenter: Double?
    private var _yUpper: Double?
    private var _yLower: Double?
    private var _xCenter: Double?
    private var _xLeft: Double?
    private var _xRight: Double?
    private var _unitSize: Double?

    func addLine(_ l: StaffLine) {
        lines.append(l)
        _yCenter = nil; _yUpper = nil; _yLower = nil
        _xCenter = nil; _xLeft = nil; _xRight = nil; _unitSize = nil
    }

    public var yCenter: Double {
        if let v = _yCenter { return v }
        let v = npMean(lines.map { $0.yCenter })
        _yCenter = v
        return v
    }
    public var yUpper: Double {
        if let v = _yUpper { return v }
        let v = lines.map { $0.yUpper }.min()!
        _yUpper = v
        return v
    }
    public var yLower: Double {
        if let v = _yLower { return v }
        let v = lines.map { $0.yLower }.max()!
        _yLower = v
        return v
    }
    public var xCenter: Double {
        if let v = _xCenter { return v }
        let v = npMean(lines.map { $0.xCenter })
        _xCenter = v
        return v
    }
    public var xLeft: Double {
        if let v = _xLeft { return v }
        let v = lines.map { $0.xLeft }.min()!
        _xLeft = v
        return v
    }
    public var xRight: Double {
        if let v = _xRight { return v }
        let v = lines.map { $0.xRight }.max()!
        _xRight = v
        return v
    }
    /// Mean distance between consecutive staff lines — oemer's basic measuring unit.
    public var unitSize: Double {
        if let v = _unitSize { return v }
        let centers = lines.map { $0.yCenter }
        var gaps: [Double] = []
        for i in 1..<max(lines.count, 1) { gaps.append(centers[i] - centers[i - 1]) }
        let v = npMean(gaps)
        _unitSize = v
        return v
    }
    /// Line centers from top to bottom.
    public var lineCenters: [Double] { lines.map { $0.yCenter } }

    func duplicate(xOffset: Double = 0, yOffset: Double = 0) -> Staff {
        let st = Staff()
        for line in lines {
            let nl = StaffLine()
            for i in 0..<line.count { nl.addPoint(y: line.ys[i] + yOffset, x: line.xs[i] + xOffset) }
            st.addLine(nl)
        }
        return st
    }

    /// `Staff.__sub__`: euclidean distance from the staff center to (x, y).
    func distance(x: Double, y: Double) -> Double {
        let xd = (x - xCenter) * (x - xCenter)
        let yd = (y - yCenter) * (y - yCenter)
        return (xd + yd).squareRoot()
    }
}

/// Staffs arranged as [zone][row] plus the horizontal zones they were detected in.
struct StaffLayout {
    var grid: [[Staff]]      // `staffs` layer: shape (n_zones, n_rows)
    var zones: [Range<Int>]  // all zones from init_zones (some may hold no staffs)

    /// `staffs.reshape(-1, 1).squeeze()` order (zone-major).
    var flat: [Staff] { grid.flatMap { $0 } }
}

extension OMRContext {
    // MARK: - utils.py

    /// `find_closest_staffs(x, y)`
    func findClosestStaffs(_ x: Double, _ y: Double) -> (Staff, Staff) {
        let flat = staffsFlat
        var keyed: [(idx: Int, dist: Double)] = []
        keyed.reserveCapacity(flat.count)
        for (i, st) in flat.enumerated() { keyed.append((i, st.distance(x: x, y: y))) }
        keyed.sort { (a: (idx: Int, dist: Double), b: (idx: Int, dist: Double)) -> Bool in
            a.dist != b.dist ? a.dist < b.dist : a.idx < b.idx
        }
        let order: [Staff] = keyed.map { flat[$0.idx] }
        if order.count == 1 { return (order[0], order[0]) }
        if order.count == 2 { return (order[0], order[1]) }
        let first = order[0], second = order[1], third = order[2]
        if abs(first.yLower - y) <= abs(first.yUpper - y) {
            if second.yCenter > first.yCenter { return (first, second) }
            if third.yCenter > first.yCenter { return (first, third) }
            return (first, first)
        } else {
            if second.yCenter < first.yCenter { return (first, second) }
            if third.yCenter < first.yCenter { return (first, third) }
            return (first, first)
        }
    }

    /// `get_unit_size(x, y)` (keeps the original's interpolation weights).
    func unitSize(_ x: Double, _ y: Double) -> Double {
        let (st1, st2) = findClosestStaffs(x, y)
        if st1.yCenter == st2.yCenter { return st1.unitSize }
        if st1.yUpper <= y && y <= st1.yLower { return st1.unitSize }
        let dist1 = abs(y - st1.yCenter)
        let dist2 = abs(y - st2.yCenter)
        let w1 = dist1 / (dist1 + dist2)
        let w2 = dist2 / (dist1 + dist2)
        return w1 * st1.unitSize + w2 * st2.unitSize
    }

    func unitSize(_ c: (x: Int, y: Int)) -> Double { unitSize(Double(c.x), Double(c.y)) }

    /// `get_global_unit_size()` (plain Python sum / len).
    var globalUnitSize: Double {
        let flat = staffsFlat
        var s = 0.0
        for st in flat { s += st.unitSize }
        return s / Double(flat.count)
    }

    /// `get_total_track_nums()`
    var totalTrackNums: Int { Set(staffsFlat.map { $0.track }).count }
}

// MARK: - staffline_extraction.py

/// `init_zones(staff_pred, splits)`. With float32 maps (after dewarping) the column sums and
/// means are float32 like numpy computes them; with oemer's integer maps they are exact/float64.
func initZones(_ staffPred: Grid<Float>, floatMaps: Bool, splits: Int) throws -> [Range<Int>] {
    let w = staffPred.width, h = staffPred.height
    var minX = Int.max, maxX = Int.min
    var colSumF = [Float](repeating: 0, count: w)
    var colSumD = [Double](repeating: 0, count: w)
    staffPred.data.withUnsafeBufferPointer { p in
        for y in 0..<h {
            let row = y * w
            for x in 0..<w {
                let v = p[row + x]
                if v > 0 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                }
                if floatMaps { colSumF[x] += v } else { colSumD[x] += Double(v) }
            }
        }
    }
    if maxX < minX { throw OMRError.noStaffFound }
    // accum_x = accum_x / np.mean(accum_x); then np.mean(window) < 0.1
    let windowBelow: (Int, Int) -> Bool
    if floatMaps {
        let mean = npSumF(colSumF) / Float(w)
        let accum = colSumF.map { $0 / mean }
        windowBelow = { lo, hi in npSumF(Array(accum[lo..<hi])) / Float(hi - lo) < Float(0.1) }
    } else {
        let mean = npMean(colSumD)
        let accum = colSumD.map { $0 / mean }
        windowBelow = { lo, hi in npMean(Array(accum[lo..<hi])) < 0.1 }
    }
    let half = pyRound(Double(w) / 2)
    var rightBound = min(maxX + 50, w)
    var leftBound = max(minX - 50, 0)
    if half + 10 < w {
        for i in (half + 10)..<w where windowBelow(i - 10, i) {
            rightBound = i
            break
        }
    }
    var i = half - 10
    while i > 0 {
        let lo = max(i, 0)
        let hi = min(i + 10, w)
        if lo < hi && windowBelow(lo, hi) {
            leftBound = i
            break
        }
        i -= 1
    }
    let stepSize = pyRound(Double(rightBound - leftBound) / Double(splits))
    if stepSize <= 0 { throw OMRError.noStaffFound }
    var zones: [Range<Int>] = []
    var start = leftBound
    while start < rightBound {
        var end = start + stepSize
        if rightBound - end < stepSize {
            end = rightBound
            zones.append(start..<end)
            break
        }
        zones.append(start..<end)
        start += stepSize
    }
    return zones
}

/// `filter_line_peaks(peaks, norm)`
func filterLinePeaks(_ peaks: [Int], _ norm: [Double], maxGapRatio: Double = 1.5) -> (valid: [Bool], groups: [Int]) {
    var valid = [Bool](repeating: true, count: peaks.count)
    for (idx, p) in peaks.enumerated() where norm[p] > 15 { valid[idx] = false }
    if peaks.isEmpty { return (valid, []) }

    var gaps: [Int] = []
    for i in 1..<max(peaks.count, 1) { gaps.append(peaks[i] - peaks[i - 1]) }
    let count = max(5, pyRound(Double(peaks.count) * 0.2))
    let sortedGaps = gaps.sorted()
    let approxUnit = sortedGaps.isEmpty ? Double.nan : npMean(sortedGaps.prefix(count).map { Double($0) })
    let maxGap = approxUnit * maxGapRatio

    var ext: [Double] = [Double(peaks[0]) - maxGap - 1] + peaks.map { Double($0) }
    var groups: [Int] = []
    var group = -1
    for i in 1..<ext.count {
        if ext[i] - ext[i - 1] > maxGap { group += 1 }
        groups.append(group)
    }
    ext.removeAll()
    groups.append(groups[groups.count - 1] + 1)
    var curG = groups[0]
    var cnt = 1
    for idx in 1..<groups.count {
        let g = groups[idx]
        if g == curG {
            cnt += 1
            continue
        }
        if cnt < 5 {
            for k in (idx - cnt)..<idx { valid[k] = false }
        } else if cnt > 5 {
            let cand = Array(peaks[(idx - cnt)..<idx])
            var headSum = 0.0, tailSum = 0.0
            for p in cand.prefix(5) { headSum += norm[p] }
            for p in cand.suffix(5) { tailSum += norm[p] }
            if headSum > tailSum {
                for k in (idx - cnt + 5)..<idx { valid[k] = false }
            } else {
                for k in (idx - cnt)..<(idx - 5) { valid[k] = false }
            }
        }
        curG = g
        cnt = 1
    }
    groups.removeLast()
    return (valid, groups)
}

/// `extract_line(pred, x_offset, line_threshold)` on the zone `xr` of the staff map.
/// Returns the valid lines (labelled 0...4 within each staff) in their original order.
func extractLines(_ pred: Mask, xr: Range<Int>, lineThreshold: Double = 0.8) -> [StaffLine]? {
    let h = pred.height, w = pred.width
    var count = [Double](repeating: 0, count: h + 2)
    pred.data.withUnsafeBufferPointer { p in
        for y in 0..<h {
            let row = y * w
            var c = 0
            for x in xr where p[row + x] != 0 { c += 1 }
            count[y + 1] = Double(UInt16(truncatingIfNeeded: c))
        }
    }
    let mean = npMean(count)
    let std = npStd(count)
    let normFull = count.map { ($0 - mean) / std }
    var centers = findPeaks(normFull, height: lineThreshold, distance: 8, prominence: 1).map { $0 - 1 }
    let norm = Array(normFull[1..<(normFull.count - 1)])
    if centers.isEmpty { return nil }
    let (valid, groups) = filterLinePeaks(centers, norm)

    let cc = centers.indices.filter { valid[$0] }.map { centers[$0] }
    var ccGaps: [Double] = []
    for i in 1..<max(cc.count, 1) { ccGaps.append(Double(cc[i] - cc[i - 1])) }
    ccGaps.sort()
    let maxGap = ccGaps.isEmpty ? Double.nan : npMean(Array(ccGaps.prefix(3)))

    let lines = centers.map { _ in StaffLine() }
    let threshold = min(lineThreshold, 1.2)
    pred.data.withUnsafeBufferPointer { p in
        // walk pixels in raster order (np.where order)
        var ci = 0
        for y in 0..<h {
            // closest center to y: np.argmin(|centers - y|), first on ties
            while ci + 1 < centers.count && abs(centers[ci + 1] - y) < abs(centers[ci] - y) { ci += 1 }
            let closest = ci
            let cen = centers[closest]
            guard valid[closest], norm[y] > threshold, Double(abs(y - cen)) < maxGap else { continue }
            let row = y * w
            for x in xr where p[row + x] != 0 {
                lines[closest].addPoint(y: Double(y), x: Double(x))
            }
        }
    }
    centers.removeAll(keepingCapacity: false)

    // Assign labels: iterate valid lines sorted by y_center (stable)
    let validIdx = lines.indices.filter { valid[$0] }
    if validIdx.contains(where: { lines[$0].count == 0 }) { return nil }
    let ordered = validIdx.sorted { a, b in
        let ya = lines[a].yCenter, yb = lines[b].yCenter
        return ya != yb ? ya < yb : a < b
    }
    var lastGroup = groups[0]
    var curLineId = 0
    for idx in ordered {
        if groups[idx] != lastGroup {
            curLineId = 0
            lastGroup = groups[idx]
        }
        if curLineId > 4 { return nil }  // Python raises ValueError here
        lines[idx].label = curLineId
        curLineId += 1
    }
    return validIdx.map { lines[$0] }
}

/// `extract_part(pred, x_offset, line_threshold)`
func extractPart(_ pred: Mask, xr: Range<Int>, lineThreshold: Double = 0.8) -> [Staff]? {
    guard let lines = extractLines(pred, xr: xr, lineThreshold: lineThreshold), lines.count >= 5 else { return nil }
    var staffs: [Staff] = []
    var buffer: [StaffLine] = []
    for (idx, line) in lines.enumerated() {
        let lid = idx % 5
        if line.label != lid { return nil }  // Python asserts here
        if lid == 0 && !buffer.isEmpty {
            if buffer.count != 5 { return nil }
            let st = Staff()
            buffer.forEach { st.addLine($0) }
            staffs.append(st)
            buffer = []
        }
        buffer.append(line)
    }
    let st = Staff()
    buffer.forEach { st.addLine($0) }
    staffs.append(st)
    return staffs
}

/// `align_staffs(staffs)` — fills missing sub-staffs so every zone has the same rows.
func alignStaffs(_ staffs: [[Staff]], maxDistRatio: Double = 3) -> [[Staff]] {
    let lenTypes = Set(staffs.map { $0.count })
    if lenTypes.count == 1 { return staffs }
    let maxLen = lenTypes.max()!
    var grid: [[Staff?]] = staffs.map { $0.count == maxLen ? $0.map { Optional($0) } : Array(repeating: nil, count: maxLen) }

    func nearby(_ j: Int, _ i: Int) -> [(Int, Staff)] {
        let idxs = (0..<grid.count).sorted { a, b in
            let da = abs(a - j), db = abs(b - j)
            return da != db ? da < db : a < b
        }
        var out: [(Int, Staff)] = []
        for k in idxs {
            if let st = grid[k][i] { out.append((k, st)) }
            if out.count >= 2 { break }
        }
        return out
    }

    for i in 0..<maxLen {
        for j in 0..<grid.count {
            if grid[j][i] != nil { continue }
            let ori = staffs[j]
            let sts = nearby(j, i)
            guard let ref = sts.first?.1 else { continue }
            let maxDist = ref.unitSize * maxDistRatio
            if let found = ori.first(where: { abs($0.yCenter - ref.yCenter) < maxDist }) {
                grid[j][i] = found
                continue
            }
            var newSt: Staff
            if sts.count == 1 {
                let (refIdx, refSt) = sts[0]
                let width = refSt.xRight - refSt.xLeft
                newSt = refSt.duplicate(xOffset: width * Double(j - refIdx))
            } else {
                var (idx1, ref1) = sts[0]
                var (idx2, ref2) = sts[1]
                if idx1 > idx2 {
                    swap(&idx1, &idx2)
                    swap(&ref1, &ref2)
                }
                if j < idx1 {
                    let r1 = Double(idx1 - j), r2 = Double(idx2 - idx1)
                    newSt = ref1.duplicate(xOffset: -(ref2.xCenter - ref1.xCenter) * (r1 / r2),
                                           yOffset: -(ref2.yCenter - ref1.yCenter) * (r1 / r2))
                } else if idx1 <= j && j < idx2 {
                    let r1 = Double(j - idx1), r2 = Double(idx2 - idx1)
                    newSt = ref1.duplicate(xOffset: (ref2.xCenter - ref1.xCenter) * (r1 / r2),
                                           yOffset: (ref2.yCenter - ref1.yCenter) * (r1 / r2))
                } else {
                    let r1 = Double(idx2 - idx1), r2 = Double(j - idx2)
                    newSt = ref2.duplicate(xOffset: (ref2.xCenter - ref1.xCenter) * (r2 / r1),
                                           yOffset: (ref2.yCenter - ref1.yCenter) * (r2 / r1))
                }
            }
            newSt.isInterp = true
            grid[j][i] = newSt
        }
    }
    return grid.map { $0.compactMap { $0 } }
}

extension OMRContext {
    /// `staffline_extraction.extract()` — sets `staffLayout`.
    func extractStaffs(splits: Int = 8, lineThreshold: Double = 0.8, horizontalDiffTh: Double = 0.1,
                       unitSizeDiffTh: Double = 0.1, barlineMinDegree: Double = 75) throws
    {
        let zones = try initZones(staffF, floatMaps: floatMaps, splits: splits)
        var all: [[Staff]] = []
        for rr in zones {
            if let sts = extractPart(staffPos, xr: rr, lineThreshold: lineThreshold) { all.append(sts) }
        }
        if all.isEmpty { throw OMRError.noStaffFound }
        let aligned = alignStaffs(all)
        guard aligned.allSatisfy({ $0.count == aligned[0].count }), aligned[0].count > 0 else {
            throw OMRError.inconsistentStaffs
        }

        let numTrack = inferTrackNums(aligned, minDegree: barlineMinDegree)
        for col in aligned {
            for (idx, st) in col.enumerated() {
                st.track = idx % numTrack
                st.group = idx / numTrack
            }
        }

        func norm(_ v: [Double]) -> [Double] {
            let m = npMean(v)
            return v.map { abs($0 / m - 1) }
        }
        var validRows: [[Staff]] = []
        let rows = aligned[0].count
        for r in 0..<rows {
            let row = aligned.map { $0[r] }
            if Set(row.map { $0.lines.count }).count != 1 { continue }
            if !norm(row.map { $0.yCenter }).allSatisfy({ $0 < horizontalDiffTh }) { continue }
            if !norm(row.map { $0.unitSize }).allSatisfy({ $0 < unitSizeDiffTh }) { continue }
            validRows.append(row)
        }
        if validRows.isEmpty { throw OMRError.noStaffFound }
        // transpose back to [zone][row]
        let grid = (0..<aligned.count).map { z in validRows.map { $0[z] } }
        staffLayout = StaffLayout(grid: grid, zones: zones)
        staffsFlat = staffLayout.flat
    }

    /// `further_infer_track_nums(staffs, min_degree)`
    func inferTrackNums(_ staffs: [[Staff]], minDegree: Double) -> Int {
        let w = width, h = height
        // mix = symbols - stems - notehead - clefs; mix[mix < 0] = 0; find_lines(mix) uses mix.astype(np.uint8)
        var mix = Mask.zeros(width: w, height: h)
        for i in 0..<(w * h) {
            let v = ((symbolsF.data[i] - stemsF.data[i]) - noteheadF.data[i]) - clefsF.data[i]
            mix.data[i] = v >= 1 ? 1 : 0
        }
        let lines = findLines(mix)
        let flat = staffs.flatMap { $0 }
        var minY = 9_999_999.0, minX = 9_999_999.0, maxY = 0.0, maxX = 0.0
        for st in flat {
            minY = min(minY, st.yUpper)
            minX = min(minX, st.xLeft)
            maxY = max(maxY, st.yLower)
            maxX = max(maxX, st.xRight)
        }
        var cands: [BBox] = []
        for line in lines {
            let degree = atan2(Double(line.y2 - line.y1), Double(line.x2 - line.x1)) * 180 / Double.pi
            if degree < minDegree { continue }
            if Double(line.y1) < minY || Double(line.y2) > maxY || Double(line.x1) < minX || Double(line.x2) > maxX { continue }
            cands.append(line)
        }
        // get_barline_map(symbols, lines) + stems, clamped at 1, then .astype(np.uint8)
        var img = Grid<Float>(width: w, height: h, repeating: 0)
        for box in cands {
            var b = box
            if b.x2 - b.x1 == 0 { b.x2 += 1 }
            let r = clampSlice(x1: b.x1, y1: b.y1, x2: b.x2, y2: b.y2, width: w, height: h)
            if r.x1 >= r.x2 || r.y1 >= r.y2 { continue }
            for y in r.y1..<r.y2 {
                for x in r.x1..<r.x2 { img[y, x] += symbolsF[y, x] }
            }
        }
        var bmap = Mask.zeros(width: w, height: h)
        for i in 0..<(w * h) {
            let v = (img.data[i] > 1 ? 1 : img.data[i]) + stemsF.data[i]
            bmap.data[i] = v >= 1 ? 1 : 0
        }
        let ker = StructuringElement.rect(width: 2, height: 5)
        let ext = erode(dilate(bmap, ker), ker)
        let bboxes = getBBoxes(ext)

        var hRatios: [Double] = []
        for box in bboxes {
            let hh = Double(box.y2 - box.y1)
            let c = box.center
            // naive_get_unit_size: closest staff by squared center distance (stable)
            var best: Staff? = nil
            var bestD = Double.infinity
            for st in flat {
                let dx = st.xCenter - Double(c.x), dy = st.yCenter - Double(c.y)
                let d = dx * dx + dy * dy
                if d < bestD { bestD = d; best = st }
            }
            let u = best!.unitSize
            if hh > u { hRatios.append(hh / u) }
        }
        var numTrack = 1
        let factor = 10.0
        for i in 1..<10 {
            let validH = hRatios.filter { $0 > factor * Double(i) }.count
            if validH * (i + 1) > staffs[0].count {
                numTrack += 1
            } else {
                break
            }
        }
        return numTrack
    }
}

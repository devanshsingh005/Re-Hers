import Foundation

// Port of oemer/rhythm_extraction.py

/// Shared beam-region info (`map_info` entries); `gids` is shared between entries like in Python.
private final class RegionInfo {
    var bbox: BBox
    let gids: PySetRef
    init(bbox: BBox, gids: PySetRef) {
        self.bbox = bbox
        self.gids = gids
    }
}

/// Minimal insertion-ordered dictionary.
private struct OrderedDict<V> {
    private(set) var keys: [Int] = []
    private var store: [Int: V] = [:]

    subscript(_ k: Int) -> V? {
        get { store[k] }
        set {
            if let v = newValue {
                if store[k] == nil { keys.append(k) }
                store[k] = v
            } else if store[k] != nil {
                store[k] = nil
                keys.removeAll { $0 == k }
            }
        }
    }

    var items: [(Int, V)] { keys.map { ($0, store[$0]!) } }
}

extension OMRContext {
    /// `scan_dot(...)`
    private func scanDot(_ sym: Mask, _ b: BBox, unitSize u: Double, minCount: Int, maxCount: Int) -> Bool {
        var rightBound = b.x2 + 1
        let startY = b.y1 - pyRound(u / 2)
        let rowStart = pySliceStart(startY, height), rowStop = pySliceStop(b.y2, height)
        while true {
            if rightBound >= width || rightBound < -width { break }  // IndexError
            let col = rightBound < 0 ? rightBound + width : rightBound
            var found = false
            if rowStart < rowStop {
                for y in rowStart..<rowStop where noteIdMap[y, col] != -1 {
                    found = true
                    break
                }
            }
            if found { break }
            rightBound += 1
            if Double(rightBound) >= Double(b.x2) + u { break }
        }
        let leftBound = b.x2 + pyRound(u * 0.4)
        let pixels = sym.countNonZero(x1: leftBound, y1: startY, x2: rightBound, y2: b.y2)
        return minCount <= pixels && pixels <= maxCount
    }

    /// `parse_dot(...)`
    func parseDots(minAreaRatio: Double = 0.08, maxAreaRatio: Double = 0.2) {
        // np.where(symbols - stems - clefs_sfns > 0, 1, 0)   (float32)
        var noStem = Mask.zeros(width: width, height: height)
        for i in 0..<(width * height) {
            let v = (symbolsF.data[i] - stemsF.data[i]) - clefsF.data[i]
            if v > 0 { noStem.data[i] = 1 }
        }
        let ker = StructuringElement.ellipse(width: 4, height: 4)
        noStem = dilate(erode(noStem, ker), ker)

        for group in groups {
            let gbox = group.bbox
            let u = unitSize(gbox.center)
            let minCount = pyRound(u * u * minAreaRatio)
            let maxCount = pyRound(u * u * maxAreaRatio)
            var dots: [Bool] = []
            for nid in group.noteIds {
                let nb = notes[nid].bbox
                let b = BBox(nb.x1, nb.y1, max(nb.x2, gbox.x2), nb.y2)
                let d = scanDot(noStem, b, unitSize: u, minCount: minCount, maxCount: maxCount)
                dots.append(d)
                notes[nid].hasDot = d
            }
            let allSame = !(dots.allSatisfy { $0 } != dots.contains(true))
            if group.stemUp != nil && !allSame {
                let t = dots.filter { $0 }.count
                let toDot = t >= dots.count - t
                for nid in group.noteIds { notes[nid].hasDot = toDot }
            }
        }
    }

    /// `polish_symbols(...)` followed by the subtraction at the top of `parse_beams`:
    /// `beams = beams - gp_map - stems` (float64). Returns `beams > 0` and `beams.astype(np.uint8)`.
    private func beamCandidates() -> (positive: Mask, truncated: Mask) {
        let beamsInStaff = morphOpen(staffTrunc, StructuringElement.rect(width: 1, height: 5))
        var mix = Mask.zeros(width: width, height: height)
        for i in 0..<(width * height) {
            let gp = groupMap.data[i] > -1 ? 1.0 : 0.0
            // symbols (f32) + beams_in_staff (u8) -> f32; then - gp_map (int) -> f64; - stems; - clefs
            let s = symbolsF.data[i] + Float(beamsInStaff.data[i])
            let v = ((Double(s) - gp) - Double(stemsF.data[i])) - Double(clefsF.data[i])
            if v > 0 { mix.data[i] = 1 }
        }
        mix = morphOpen(mix, StructuringElement.rect(width: 3, height: 2))
        let extStems = morphClose(stemsTrunc, StructuringElement.rect(width: 1, height: 5))
        var pos = Mask.zeros(width: width, height: height)
        var trunc = Mask.zeros(width: width, height: height)
        for i in 0..<(width * height) {
            let gp = groupMap.data[i] > -1 ? 1 : 0
            var b = Int(mix.data[i]) + Int(extStems.data[i]) + gp
            if b > 1 { b = 1 }
            let v = (Double(b) - Double(gp)) - Double(stemsF.data[i])
            if v > 0 { pos.data[i] = 1 }
            if v >= 1 { trunc.data[i] = 1 }
        }
        return (pos, trunc)
    }

    /// `parse_beams(...)` — returns the binary `poly_map`.
    func parseBeams(minAreaRatio: Double = 0.07, minTpRatio: Double = 0.4, minWidthRatio: Double = 0.2) -> Mask {
        let (beams, beamsTrunc) = beamCandidates()
        // poly_map: 0 = black (beam), 255 = white
        var poly = [UInt8](repeating: 255, count: width * height)
        for i in 0..<(width * height) where beams.data[i] != 0 { poly[i] = 0 }
        var validPixels: [[Int]] = []
        var visited = [Int32](repeating: -1, count: width * height)
        var stamp: Int32 = 0

        // rotated boxes come from findContours(beams.astype(np.uint8)); pixel tests use beams > 0
        for contour in findContours(beamsTrunc) {
            let rbox = minAreaRect(contour.points)
            let pts = rbox.points()
            if pts.contains(where: { $0.x < 0 || $0.y < 0 }) { continue }
            let cnt = pts.map { (x: Int($0.x), y: Int($0.y)) }   // astype(np.uint64)
            let cx = Double(cnt.reduce(0) { $0 + $1.x }) / 4
            let cy = Double(cnt.reduce(0) { $0 + $1.y }) / 4
            let u = unitSize(Double(pyRound(cx)), Double(pyRound(cy)))
            // cv2.contourArea
            var a00 = 0.0
            var prev = cnt[3]
            for p in cnt {
                a00 += Double(prev.x) * Double(p.y) - Double(prev.y) * Double(p.x)
                prev = p
            }
            let area = abs(a00 * 0.5)
            if area < u * u * minAreaRatio {
                fillPoly(width: width, height: height, cnt) { x, y in poly[y * width + x] = 255 }
                continue
            }
            // pixels covered by the filled polygon
            stamp += 1
            var all: [Int] = []
            fillPoly(width: width, height: height, cnt) { x, y in
                let i = y * width + x
                if visited[i] != stamp {
                    visited[i] = stamp
                    all.append(i)
                }
            }
            let onBeam = all.filter { beams.data[$0] != 0 }
            let rWidth = Double(min(rbox.width, rbox.height))
            if rWidth < u * minWidthRatio {
                for i in onBeam { poly[i] = 255 }
                continue
            }
            let ratio = Double(onBeam.count) / (Double(all.count) + 1e-8)
            if ratio < minTpRatio {
                for i in onBeam { poly[i] = 255 }
                continue
            }
            validPixels.append(onBeam)
        }
        for v in validPixels { for i in v { poly[i] = 0 } }
        return Mask(width: width, height: height, data: poly.map { $0 == 0 ? 1 : 0 })
    }

    /// `parse_beam_overlap_regions(poly_map, invalid_map)`
    private func parseBeamOverlapRegions(_ polyIn: Mask) -> (Mask, OrderedDict<RegionInfo>) {
        let ker = StructuringElement.rect(width: 3, height: 3)
        var mixBin = Mask.zeros(width: width, height: height)
        // mix = poly_map + symbols (float64), clamped at 0, then .astype(np.uint8)
        for i in 0..<(width * height) where Double(polyIn.data[i]) + Double(symbolsF.data[i]) >= 1 { mixBin.data[i] = 1 }
        var mix = dilate(erode(mixBin, ker), ker)
        var poly = dilate(erode(polyIn, ker), ker)
        for bl in barlines {
            let (rows, cols) = sliceRanges(bl.bbox, width: width, height: height)
            for y in rows {
                for x in cols {
                    mix[y, x] = 0
                    poly[y, x] = 0
                }
            }
        }
        let (regMap, featNum) = labelRegions(poly)
        let (symMap, symN) = labelRegions(mix)

        // per symbol component: inclusive bbox and the sorted group ids it overlaps (incl. -1)
        var symBox = [BBox?](repeating: nil, count: symN + 1)
        var symGids = [Set<Int32>](repeating: [], count: symN + 1)
        var regSyms = [Set<Int>](repeating: [], count: featNum + 1)
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                let s = Int(symMap.data[row + x])
                let r = Int(regMap.data[row + x])
                if r != 0 { regSyms[r].insert(s) }
                if s == 0 { continue }
                if var b = symBox[s] {
                    if x < b.x1 { b.x1 = x }
                    if x > b.x2 { b.x2 = x }
                    if y < b.y1 { b.y1 = y }
                    if y > b.y2 { b.y2 = y }
                    symBox[s] = b
                } else {
                    symBox[s] = BBox(x, y, x, y)
                }
                symGids[s].insert(groupMap.data[row + x])
            }
        }

        var outMap = Mask.zeros(width: width, height: height)
        var mapInfo = OrderedDict<RegionInfo>()
        var keepRegion = [Bool](repeating: false, count: featNum + 1)
        for idx in 1...max(featNum, 1) where idx <= featNum {
            var symLabels = PySet(regSyms[idx].sorted())
            symLabels.discard(0)
            var allG = Set<Int32>()
            var box: BBox? = nil
            for l in symLabels.elements {
                allG.formUnion(symGids[l])
                if let b = symBox[l] {
                    box = box.map { BBox(min($0.x1, b.x1), min($0.y1, b.y1), max($0.x2, b.x2), max($0.y2, b.y2)) } ?? b
                }
            }
            var gids = PySet(allG.map { Int($0) }.sorted())
            gids.discard(-1)
            if gids.isEmpty { continue }
            keepRegion[idx] = true
            var cur = box!
            let shared = PySetRef(gids)
            for l in symLabels.elements {
                if let existing = mapInfo[l] {
                    let bb = existing.bbox
                    shared.set.update(existing.gids.set)
                    cur = BBox(min(bb.x1, cur.x1), min(bb.y1, cur.y1), max(bb.x2, cur.x2), max(bb.y2, cur.y2))
                }
                mapInfo[l] = RegionInfo(bbox: cur, gids: shared)
            }
        }
        for i in 0..<(width * height) where keepRegion[Int(regMap.data[i])] && regMap.data[i] != 0 { outMap.data[i] = 1 }
        outMap = erode(dilate(outMap, ker), ker)
        return (outMap, mapInfo)
    }

    /// `refine_map_info(map_info)`
    private func refineMapInfo(_ mapInfo: OrderedDict<RegionInfo>) -> OrderedDict<RegionInfo> {
        var newInfo = OrderedDict<RegionInfo>()
        var revMap: [Int: Int] = [:]
        for (reg, info) in mapInfo.items {
            let entry = RegionInfo(bbox: BBox(0, 0, 0, 0), gids: PySetRef())
            newInfo[reg] = entry
            var bx = info.gids.set.elements.map { groups[$0].bbox }
            bx.append(info.bbox)
            let bbox = BBox(bx.map { $0.x1 }.min()!, bx.map { $0.y1 }.min()!, bx.map { $0.x2 }.max()!, bx.map { $0.y2 }.max()!)
            entry.bbox = bbox
            let (rows, cols) = sliceRanges(bbox, width: width, height: height)
            var gids = PySet(uniqueValues(groupMap, rows: rows, cols: cols))
            gids.discard(-1)
            for gid in gids.elements {
                guard let oriReg = revMap[gid] else {
                    entry.gids.set.add(gid)
                    revMap[gid] = reg
                    continue
                }
                if oriReg == reg { continue }
                guard let ori = newInfo[oriReg] else { continue }  // Python would raise KeyError
                let newBox = BBox(min(ori.bbox.x1, bbox.x1), min(ori.bbox.y1, bbox.y1),
                                  max(ori.bbox.x2, bbox.x2), max(ori.bbox.y2, bbox.y2))
                ori.gids.set.add(gid)
                entry.gids.set.update(ori.gids.set)
                entry.bbox = newBox
                revMap[gid] = reg
                newInfo[oriReg] = nil
                for og in ori.gids.set.elements { revMap[og] = reg }
            }
        }
        return newInfo
    }

    /// `get_stem_x(gbox, nboxes, unit_size, is_right)`
    private func stemX(_ gbox: BBox, _ nboxes: [BBox], _ u: Double, isRight: Bool = true) -> Int {
        let allSameSide = nboxes.allSatisfy { Double(abs($0.x2 - gbox.x2)) < u / 3 }
        if !allSameSide { return pyRound(Double(gbox.x1 + gbox.x2) / 2) }
        return isRight ? gbox.x2 : gbox.x1
    }

    /// `scan_beam_flag(...)`
    private func scanBeamFlag(_ poly: Mask, startX sx: Int, startY syIn: Int, endX ex: Int, endY eyIn: Int,
                              threshold: Double = 0.1, minWidthRatio: Double = 0.25, maxWidthRatio: Double = 0.9) -> Int
    {
        var sy = syIn, ey = eyIn
        let n = max(ex - sx, 0)
        var counter = [Int](repeating: 0, count: n)
        if ey < sy { swap(&sy, &ey) }
        let u = unitSize(Double(sx), Double(sy))
        let minWidth = u * minWidthRatio
        let maxWidth = u * maxWidthRatio
        func px(_ y: Int, _ x: Int) -> Int {
            let yy = y < 0 ? y + height : y
            let xx = x < 0 ? x + width : x
            guard yy >= 0 && yy < height && xx >= 0 && xx < width else { return 0 }
            return Int(poly[yy, xx])
        }
        var hit: Bool? = nil
        var widthVal: Int? = nil
        for (idx, x) in (sx..<max(ex, sx)).enumerated() {
            var curY = sy
            var lastVal = px(curY, x)
            while curY < ey {
                var h = false
                var w = 0
                while curY < ey {
                    let curVal = px(curY, x)
                    if (lastVal ^ curVal) != 0 {
                        h = lastVal > curVal
                        lastVal = curVal
                        curY += 1
                        break
                    }
                    curY += 1
                    w += 1
                }
                hit = h
                widthVal = w
                if h && Double(w) >= minWidth { counter[idx] += Int(ceil(Double(w) / maxWidth)) }
            }
            if lastVal == 1 {
                if let h = hit, h, let w = widthVal {
                    counter[idx] += Int(ceil(Double(w) / maxWidth))
                } else {
                    counter[idx] += 1
                }
            }
        }
        var stat: [Int: Int] = [:]
        for c in counter { stat[c, default: 0] += 1 }
        let minNum = Double(counter.count) * threshold
        var accum = 0
        for c in stat.keys.sorted(by: >) {
            accum += stat[c]!
            if Double(accum) > minNum { return c }
        }
        return 0
    }

    private static let noteTypeMap: [NoteType] = [.quarter, .eighth, .sixteenth, .thirtySecond, .sixteenth]

    /// `parse_inner_groups(...)`
    private func parseInnerGroups(_ poly: Mask, _ group: NoteGroup, setBox: BBox, halfScanWidth: Int, threshold: Double) {
        let ntsAsc = group.noteIds.map { notes[$0] }
        // sorted(reverse=True) by staff_line_pos, stable
        let nts = ntsAsc.enumerated().sorted { a, b in
            a.element.staffLinePos != b.element.staffLinePos ? a.element.staffLinePos > b.element.staffLinePos : a.offset < b.offset
        }.map { $0.element }
        let map = OMRContext.noteTypeMap
        func getLabel(_ nb: BBox, stemUp: Bool) -> NoteType {
            let cenX = stemUp ? nb.x2 : nb.x1
            let startY = stemUp ? nb.y1 : nb.y2
            let endY = stemUp ? setBox.y1 : setBox.y2
            let count = scanBeamFlag(poly, startX: max(setBox.x1, cenX - halfScanWidth), startY: startY,
                                     endX: min(setBox.x2, cenX + halfScanWidth), endY: endY, threshold: threshold)
            return count >= map.count ? map[map.count - 1] : map[count]
        }
        if nts.count == 2 {
            notes[nts[0].id].forceSetLabel(getLabel(nts[0].bbox, stemUp: true))
            notes[nts[1].id].forceSetLabel(getLabel(nts[1].bbox, stemUp: false))
            notes[nts[0].id].stemUp = true
            notes[nts[1].id].stemUp = false
            group.topNoteIds.append(nts[0].id)
            group.bottomNoteIds.append(nts[1].id)
        } else if group.allSameType == true {
            notes[nts[0].id].label = getLabel(nts[0].bbox, stemUp: true)
            notes[nts[0].id].stemUp = true
            group.topNoteIds.append(nts[0].id)
            let bt = getLabel(nts[nts.count - 1].bbox, stemUp: false)
            for nn in nts.dropFirst() {
                notes[nn.id].label = bt
                notes[nn.id].stemUp = false
                group.bottomNoteIds.append(nn.id)
            }
        } else {
            var idx = 0
            while idx < nts.count {
                if nts[0].label != nts[idx].label { break }
                idx += 1
            }
            if nts[0].label == .halfOrWhole {
                for nn in nts[..<idx] {
                    notes[nn.id].forceSetLabel(.half)
                    notes[nn.id].stemUp = true
                    group.topNoteIds.append(nn.id)
                }
                let bt = getLabel(nts[nts.count - 1].bbox, stemUp: false)
                for nn in nts[idx...] {
                    notes[nn.id].label = bt
                    notes[nn.id].stemUp = false
                    group.bottomNoteIds.append(nn.id)
                }
            } else {
                for nn in nts[idx...] {
                    notes[nn.id].forceSetLabel(.half)
                    notes[nn.id].stemUp = false
                    group.bottomNoteIds.append(nn.id)
                }
                let top = getLabel(nts[nts.count - 1].bbox, stemUp: true)
                for nn in nts[..<idx] {
                    notes[nn.id].label = top
                    notes[nn.id].stemUp = true
                    group.topNoteIds.append(nn.id)
                }
            }
        }
    }

    /// `parse_rhythm(beam_map, map_info)`
    private func parseRhythm(_ beamMap: Mask, _ mapInfo: OrderedDict<RegionInfo>, agreeTh: Double = 0.15) {
        var revBox: [Int: BBox] = [:]
        for (_, info) in mapInfo.items {
            for gid in info.gids.set.elements { revBox[gid] = info.bbox }
        }
        let map = OMRContext.noteTypeMap
        for (gid, group) in groups.enumerated() {
            let gbox0 = group.bbox
            let regBox = revBox[gid] ?? gbox0
            let u0 = unitSize(gbox0.center)
            let halfScan = pyRound(u0 / 2)

            if group.stemUp == nil {
                if group.hasStem != true {
                    for nid in group.noteIds {
                        if notes[nid].label != .halfOrWhole {
                            notes[nid].invalid = true
                            continue
                        }
                        notes[nid].forceSetLabel(.whole)
                    }
                } else {
                    parseInnerGroups(beamMap, group, setBox: regBox, halfScanWidth: halfScan, threshold: agreeTh)
                }
                continue
            }

            // most common label (Python breaks ties by set order, which is random for enums;
            // here ties go to the label seen first)
            let labels = group.noteIds.map { notes[$0].label }
            var order: [NoteType?] = []
            var counts: [Int] = []
            for l in labels {
                if let i = order.firstIndex(where: { $0 == l }) { counts[i] += 1 } else { order.append(l); counts.append(1) }
            }
            var best = 0
            for i in 1..<max(order.count, 1) where counts[i] > counts[best] { best = i }
            let label = order[best]
            if label == .halfOrWhole {
                for nid in group.noteIds { notes[nid].forceSetLabel(.half) }
                continue
            }
            guard revBox[gid] != nil else {
                for nid in group.noteIds { notes[nid].label = .quarter }
                continue
            }
            let gbox = BBox(gbox0.x1, min(gbox0.y1, regBox.y1), gbox0.x2, max(gbox0.y2, regBox.y2))
            let nboxes = group.noteIds.map { notes[$0].bbox }
            let u = unitSize(gbox.center)
            let cenX: Int, startY: Int, endY: Int
            if group.stemUp == true {
                cenX = stemX(gbox, nboxes, u)
                startY = nboxes.map { $0.y1 }.min()!
                endY = gbox.y1
            } else {
                cenX = stemX(gbox, nboxes, u, isRight: false)
                startY = nboxes.map { $0.y2 }.max()!
                endY = gbox.y2
            }
            let count = scanBeamFlag(beamMap, startX: max(regBox.x1, cenX - halfScan), startY: startY,
                                     endX: min(regBox.x2, cenX + halfScan), endY: endY, threshold: agreeTh)
            for nid in group.noteIds where notes[nid].label == nil {
                if count >= 0 && count < map.count {
                    notes[nid].label = map[count]
                } else {
                    notes[nid].invalid = true
                }
            }
        }
    }

    /// `rhythm_extraction.extract()`
    func extractRhythm() {
        parseDots()
        let poly = parseBeams()
        let (outMap, info) = parseBeamOverlapRegions(poly)
        let refined = refineMapInfo(info)
        var bin = outMap
        for i in 0..<bin.data.count { bin.data[i] = bin.data[i] > 0 ? 1 : 0 }
        parseRhythm(bin, refined)
    }
}

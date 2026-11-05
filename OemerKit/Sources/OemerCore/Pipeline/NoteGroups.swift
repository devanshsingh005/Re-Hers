// Port of oemer/note_group_extraction.py

final class NoteGroup {
    var id = 0
    var bbox = BBox(0, 0, 0, 0)
    var noteIds: [Int] = []
    var topNoteIds: [Int] = []
    var bottomNoteIds: [Int] = []
    var stemUp: Bool? = nil
    var hasStem: Bool? = nil
    var allSameType: Bool? = nil
    var group = 0
    var track = 0

    var xCenter: Double { Double(bbox.x1 + bbox.x2) / 2 }
}

/// A label map whose labels can be merged cheaply (`nh_label[nh_label == ll] = label`).
private struct MergeableLabels {
    var orig: Grid<Int32>
    var current: [Int]          // original label -> current label (0 = removed)
    var members: [[Int]]        // current label -> original labels carrying it

    init(_ labels: Grid<Int32>, count: Int) {
        orig = labels
        current = Array(0...count)
        members = (0...count).map { [$0] }
    }

    mutating func relabel(_ from: Int, to: Int) {
        if from == to { return }
        let moved = members[from]
        for o in moved { current[o] = to }
        if to != 0 { members[to] += moved }
        members[from] = []
    }

    func uniqueCurrent(rows: Range<Int>, cols: Range<Int>) -> [Int] {
        var s = Set<Int>()
        for y in rows {
            let row = y * orig.width
            for x in cols { s.insert(current[Int(orig.data[row + x])]) }
        }
        return s.sorted()
    }

    func materialize() -> Grid<Int32> {
        var g = orig
        for i in 0..<g.data.count { g.data[i] = Int32(current[Int(g.data[i])]) }
        return g
    }
}

/// Insertion-ordered dictionary of group label -> note ids.
private struct OrderedGroups {
    var keys: [Int] = []
    var values: [Int: [Int]] = [:]

    func contains(_ k: Int) -> Bool { values[k] != nil }

    mutating func set(_ k: Int, _ v: [Int]) {
        if values[k] == nil { keys.append(k) }
        values[k] = v
    }

    mutating func remove(_ k: Int) {
        values[k] = nil
        keys.removeAll { $0 == k }
    }
}

extension OMRContext {
    /// `group_noteheads()` — returns groups (in dict order) and the group label map.
    private func groupNoteheads() -> (OrderedGroups, Grid<Int32>) {
        // mix = notehead + dilate(stems.astype(np.uint8)); mix[mix > 1] = 1; scipy labels mix != 0
        let extStems = dilate(stemsTrunc, StructuringElement.rect(width: 2, height: 3))
        var mix = Mask.zeros(width: width, height: height)
        for i in 0..<mix.data.count where (noteheadF.data[i] + Float(extStems.data[i])) != 0 {
            mix.data[i] = 1
        }
        let (nhLabel, n) = labelRegions(mix)
        var labels = MergeableLabels(nhLabel, count: n)

        // pixel extents of each note id in note_id_map
        var ext: [Int: (minX: Int, minY: Int, maxX: Int, maxY: Int)] = [:]
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                let nid = Int(noteIdMap.data[row + x])
                if nid < 0 { continue }
                if let e = ext[nid] {
                    ext[nid] = (min(e.minX, x), min(e.minY, y), max(e.maxX, x), max(e.maxY, y))
                } else {
                    ext[nid] = (x, y, x, y)
                }
            }
        }
        var nidsSet = PySet(([-1] + ext.keys.sorted()).filter { $0 == -1 ? noteIdMap.data.contains(-1) : true })
        nidsSet.discard(-1)

        var groups = OrderedGroups()
        for nid in nidsSet.elements {
            let e = ext[nid]!
            let top = e.minY - 3, bt = e.maxY + 3
            let (rows, cols) = sliceRanges(BBox(e.minX, top, e.maxX, bt), width: width, height: height)
            var lbls = PySet(labels.uniqueCurrent(rows: rows, cols: cols))
            lbls.discard(0)
            if lbls.isEmpty { continue }
            var label: Int
            if lbls.count > 1 {
                let keys = PySet(groups.keys)
                var inter = lbls.intersection(keys)
                if inter.isEmpty {
                    label = lbls.pop()!
                } else if inter.count == 1 {
                    label = inter.pop()!
                } else {
                    label = inter.pop()!
                    var tmp = groups.values[label]!
                    for k in inter.elements {
                        tmp += groups.values[k]!
                        groups.remove(k)
                    }
                    groups.set(label, tmp)
                }
                for ll in lbls.elements { labels.relabel(ll, to: label) }
            } else {
                label = lbls.pop()!
            }
            var list = groups.values[label] ?? []
            list.append(nid)
            groups.set(label, list)
        }
        // remove labels that have no notehead attached
        for l in 1...max(n, 1) where l <= n {
            if !labels.members[l].isEmpty && !groups.contains(l) { labels.relabel(l, to: 0) }
        }
        return (groups, labels.materialize())
    }

    /// Bounding boxes (inclusive) of every label in a label map.
    private func labelBoxes(_ map: Grid<Int32>) -> [Int: BBox] {
        var boxes: [Int: BBox] = [:]
        for y in 0..<map.height {
            let row = y * map.width
            for x in 0..<map.width {
                let l = Int(map.data[row + x])
                if l <= 0 { continue }
                if var b = boxes[l] {
                    if x < b.x1 { b.x1 = x }
                    if x > b.x2 { b.x2 = x }
                    if y < b.y1 { b.y1 = y }
                    if y > b.y2 { b.y2 = y }
                    boxes[l] = b
                } else {
                    boxes[l] = BBox(x, y, x, y)
                }
            }
        }
        return boxes
    }

    /// `get_possible_nearby_gid(cur_note, group_map)`
    private func possibleNearbyGid(_ note: NoteHead, _ gmap: Grid<Int32>, current: (Int32) -> Int,
                                   scanRangeRatio: Double = 5) -> Int?
    {
        let b = note.bbox
        let c = b.center
        let curGid = current(gmap[c.y, c.x])
        let u = unitSize(c)
        let w = b.x2 - b.x1 + 4
        let startX = b.x1 - pyRound(Double(w) / 2)
        let endX = min(startX + w, gmap.width)

        func search(_ startY: Double, _ yBound: Double, _ step: Int) -> (Int, Double)? {
            var curY = startY
            while true {
                if step > 0 && curY >= yBound { break }
                if step < 0 && curY < yBound { break }
                var yi = Int(curY)
                if yi < 0 { yi += gmap.height }
                let lo = pySliceStart(startX, gmap.width), hi = pySliceStop(endX, gmap.width)
                var counts: [Int: Int] = [:]
                if lo < hi {
                    for x in lo..<hi { counts[current(gmap[yi, x]), default: 0] += 1 }
                }
                var gids = PySet(counts.keys.sorted())
                gids.discard(0)
                gids.discard(curGid)
                if !gids.isEmpty {
                    if gids.count > 1 {
                        let reg = gids.elements.map { ($0, counts[$0]!) }
                        let sortedReg = reg.enumerated().sorted { a, b in
                            a.element.1 != b.element.1 ? a.element.1 < b.element.1 : a.offset < b.offset
                        }
                        return (sortedReg.last!.element.0, curY)
                    }
                    return (gids.pop()!, curY)
                }
                curY += Double(step)
            }
            return nil
        }

        let (st1, st2) = findClosestStaffs(Double(c.x), Double(c.y))
        let yUpper = min(st1.yUpper, st2.yUpper)
        let yLower = max(st1.yLower, st2.yLower)
        var curY = Double(b.y1 - 1)
        let top = search(curY, max(curY - scanRangeRatio * u, yUpper), -1)
        curY = Double(b.y2 + 1)
        let bottom = search(curY, min(curY + scanRangeRatio * u, yLower), 1)
        if let t = top, let bt = bottom {
            let dTop = abs(Double(c.y) - t.1)
            let dBt = abs(Double(c.y) - bt.1)
            return dTop < dBt ? t.0 : bt.0
        }
        return top?.0 ?? bottom?.0
    }

    /// `note_group_extraction.extract()` — sets `groups` and `groupMap`.
    func extractNoteGroups(toleranceRatio: Double = 0.2, maxXDiffRatio: Double = 0.5) {
        var (groups, gmap) = groupNoteheads()

        // parse_stem_direction
        var boxes = labelBoxes(gmap)
        var redirect: [Int: Int] = [:]  // gp merged into new_group (group_map relabel)
        func current(_ v: Int32) -> Int {
            var l = Int(v)
            while let r = redirect[l] { l = r }
            return l
        }
        var tempResult: [Int: Bool] = [:]
        for gp in groups.keys {
            let nids = groups.values[gp]!
            guard let gbox = boxes[gp], !nids.isEmpty else { continue }
            let nb = nids.map { notes[$0].bbox }
            let nbox = BBox(nb.map { $0.x1 }.min()!, nb.map { $0.y1 }.min()!, nb.map { $0.x2 }.max()!, nb.map { $0.y2 }.max()!)
            let nh = npMean(nb.map { Double($0.y2 - $0.y1) })
            let tolerance = nh * toleranceRatio
            let higher = Double(gbox.y1) < Double(nbox.y1) - tolerance
            let lower = Double(gbox.y2) > Double(nbox.y2) + tolerance
            if higher && !lower {
                tempResult[gp] = true
                for nid in nids { notes[nid].stemUp = true }
                continue
            } else if !higher && lower {
                tempResult[gp] = false
                for nid in nids { notes[nid].stemUp = false }
                continue
            }
            if nids.count == 1 {
                let nid = nids[0]
                // newGroup == gp (the note's center pixel lies outside its own group) is a no-op in
                // Python; recording it would make `redirect` cycle and drop the group's box.
                if let newGroup = possibleNearbyGid(notes[nid], gmap, current: current), newGroup != gp,
                   let oriBox = boxes[gp], let tarBox = boxes[newGroup]
                {
                    // check_valid_new_group
                    let oc = oriBox.center, tc = tarBox.center
                    let valid = abs(Double(tc.x - oc.x)) < unitSize(oc) * maxXDiffRatio
                    if valid {
                        if let r = tempResult[newGroup] { notes[nid].stemUp = r }
                        redirect[gp] = newGroup
                        boxes[newGroup] = BBox(min(oriBox.x1, tarBox.x1), min(oriBox.y1, tarBox.y1),
                                               max(oriBox.x2, tarBox.x2), max(oriBox.y2, tarBox.y2))
                        boxes[gp] = nil
                        var lst = groups.values[newGroup]!
                        lst.append(nid)
                        groups.values[newGroup] = lst
                        var old = groups.values[gp]!
                        old.remove(at: old.firstIndex(of: nid)!)
                        groups.values[gp] = old
                    }
                }
            }
        }
        if !redirect.isEmpty {
            for i in 0..<gmap.data.count where gmap.data[i] > 0 { gmap.data[i] = Int32(current(gmap.data[i])) }
        }
        let keys = groups.keys.filter { !(groups.values[$0]!.isEmpty) }

        // gen_groups
        var newMap = Grid<Int32>(width: width, height: height, repeating: -1)
        var idOf: [Int: Int32] = [:]
        var ngs: [NoteGroup] = []
        for (idx, gid) in keys.enumerated() {
            let nids = groups.values[gid]!
            let ng = NoteGroup()
            ng.id = idx
            ng.noteIds = nids
            let gbox = boxes[gid]!
            let nb = nids.map { notes[$0].bbox }
            let nbox = BBox(nb.map { $0.x1 }.min()!, nb.map { $0.y1 }.min()!, nb.map { $0.x2 }.max()!, nb.map { $0.y2 }.max()!)
            ng.bbox = gbox
            for nid in nids { notes[nid].noteGroupId = idx }
            if let su = notes[nids[0]].stemUp {
                ng.stemUp = su
                ng.hasStem = true
            } else {
                let nh = npMean(nb.map { Double($0.y2 - $0.y1) })
                let gH = gbox.y2 - gbox.y1
                let nH = nbox.y2 - nbox.y1
                ng.hasStem = Double(abs(gH - nH)) > (nh / 5).rounded(.down)
            }
            let types = nids.map { notes[$0].label }
            ng.allSameType = types.allSatisfy { $0 == types[0] }

            var tarTrack = notes[nids[0]].track
            var tarGroup = notes[nids[0]].group
            let sameTrack = nids.allSatisfy { notes[$0].track == tarTrack }
            let sameGroup = nids.allSatisfy { notes[$0].group == tarGroup }
            if !(sameTrack && sameGroup) {
                let (st, _) = findClosestStaffs(Double(gbox.x1 + gbox.x2) / 2, Double(gbox.y1 + gbox.y2) / 2)
                tarTrack = st.track
                tarGroup = st.group
                for nid in nids {
                    notes[nid].track = st.track
                    notes[nid].group = st.group
                }
            }
            ng.track = tarTrack
            ng.group = tarGroup
            idOf[gid] = Int32(idx)
            ngs.append(ng)
        }
        for i in 0..<gmap.data.count {
            let g = Int(gmap.data[i])
            if g > 0, let v = idOf[g] { newMap.data[i] = v }
        }
        self.groups = ngs
        self.groupMap = newMap
    }
}

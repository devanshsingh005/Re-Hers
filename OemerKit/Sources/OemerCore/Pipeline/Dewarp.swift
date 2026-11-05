import Foundation

// Port of oemer/dewarp.py. The final interpolation step differs from the original: scipy's
// griddata (Delaunay triangulation) is replaced by column-wise linear interpolation between the
// detected staff lines (see tools/reference_v2.py, the Python spec for this file).

private struct GridCell {
    var bbox: (x1: Int, y1: Double, x2: Int, y2: Double)
    var yCenter: Double { (bbox.y1 + bbox.y2) / 2 }
}

private final class GridGroup {
    var id = 0
    var regId = 0
    var bbox: (x1: Int, y1: Int, x2: Int, y2: Int) = (0, 0, 0, 0)
    var gids: [Int] = []
    var splitUnit = 0
    var width: Int { bbox.x2 - bbox.x1 }
}

/// `build_grid(st_pred, split_unit=11)`
private func buildGrid(_ pred: Mask, splitUnit: Int = 11) -> (Grid<Int32>, [GridCell]) {
    let h = pred.height, w = pred.width
    var gridMap = Grid<Int32>(width: w, height: h, repeating: -1)
    var grids: [GridCell] = []
    func isOn(_ y: Int, _ i: Int) -> Bool {
        var s = 0
        let row = y * w
        for x in i..<min(i + splitUnit, w) { s += Int(pred.data[row + x]) }
        return s > splitUnit / 2
    }
    var i = 0
    while i < w {
        var curY = 0
        var lastY = 0
        var curStat = isOn(curY, i)
        while curY < h {
            while curY < h && curStat == isOn(curY, i) { curY += 1 }
            if curStat && (curY - lastY < splitUnit) {
                let gid = Int32(grids.count)
                for y in lastY..<curY {
                    for x in i..<min(i + splitUnit, w) { gridMap[y, x] = gid }
                }
                grids.append(GridCell(bbox: (i, Double(lastY), i + splitUnit, Double(curY))))
            }
            curStat.toggle()
            lastY = curY
        }
        i += splitUnit
    }
    return (gridMap, grids)
}

/// `build_grid_group(grid_map, grids)`
private func buildGridGroups(_ gridMap: Grid<Int32>, _ grids: [GridCell]) -> (Grid<Int32>, [GridGroup]) {
    let (regions, n) = labelRegions(width: gridMap.width, height: gridMap.height) { gridMap.data[$0] != -1 }
    var gidSets = [Set<Int32>](repeating: [], count: n + 1)
    for i in 0..<regions.data.count where regions.data[i] != 0 {
        gidSets[Int(regions.data[i])].insert(gridMap.data[i])
    }
    var groups: [GridGroup] = []
    for r in 1...max(n, 1) where r <= n {
        let gids = gidSets[r].map { Int($0) }.sorted()
        let l = grids[gids[0]].bbox, rb = grids[gids[gids.count - 1]].bbox
        let gg = GridGroup()
        gg.regId = r
        gg.gids = gids
        gg.bbox = (min(l.x1, rb.x1), Int(min(l.y1, rb.y1)), max(l.x2, rb.x2), Int(max(l.y2, rb.y2)))
        gg.splitUnit = l.x2 - l.x1
        groups.append(gg)
    }
    // sorted(grid_groups, reverse=True) by width, stable
    groups = groups.enumerated().sorted { a, b in
        a.element.width != b.element.width ? a.element.width > b.element.width : a.offset < b.offset
    }.map { $0.element }
    var regToIdx = [Int32](repeating: -1, count: n + 1)
    for (idx, gg) in groups.enumerated() {
        regToIdx[gg.regId] = Int32(idx)
        gg.id = idx
        gg.regId = idx
    }
    var ggMap = Grid<Int32>(width: gridMap.width, height: gridMap.height, repeating: -1)
    for i in 0..<regions.data.count where regions.data[i] != 0 { ggMap.data[i] = regToIdx[Int(regions.data[i])] }
    return (ggMap, groups)
}

/// `connect_nearby_grid_group(...)` — extends staff-line bands to the left across gaps.
private func connectNearbyGridGroups(_ ggMap: Grid<Int32>, _ groups: [GridGroup], _ gridMap: Grid<Int32>,
                                     _ gridsIn: [GridCell], refCount: Int = 8, maxStep: Int = 20) -> Grid<Int32>
{
    var newMap = ggMap
    var grids = gridsIn
    let H = ggMap.height, W = ggMap.width
    if groups.isEmpty { return newMap }
    var refGids = Array(groups[0].gids.prefix(refCount))
    var gg = groups[0]
    var remaining = PySet(0..<groups.count)
    while !remaining.isEmpty {
        if !remaining.contains(gg.id) {
            guard let gid = remaining.pop() else { break }
            gg = groups[gid]
            refGids = Array(gg.gids.prefix(refCount))
        } else {
            remaining.discard(gg.id)
        }
        if refGids.count < 2 { continue }

        let step = gg.splitUnit
        let centers = refGids.map { grids[$0].yCenter }
        let xs = (0..<centers.count).map { Double($0 * step) }
        let fit = olsFit(xs, centers)
        let refBox = grids[refGids[0]].bbox
        var endX = refBox.x1
        let h = Int(refBox.y2 - refBox.y1)
        var cands: [(x1: Int, y1: Int, x2: Int, y2: Int)] = []
        for i in 0..<maxStep {
            let tarX = Double((-i - 1) * step)
            let cenY = fit.intercept + fit.slope * tarX
            let y = pyRound(cenY - Double(h) / 2)
            let rows = pySliceStart(y, H)..<max(pySliceStart(y, H), pySliceStop(y + h, H))
            let c0 = pySliceStart(endX - step, W), c1 = pySliceStop(endX, W)
            let cols = c0..<max(c0, c1)
            var counts: [Int32: Int] = [:]
            for yy in rows { for xx in cols { counts[newMap[yy, xx], default: 0] += 1 } }
            counts[-1] = nil
            cands.append((endX - step, y, endX, y + h))
            if counts.isEmpty {
                endX -= step
                continue
            }
            cands.removeLast()
            let label: Int
            let uniq = counts.keys.sorted()
            if uniq.count > 1 {
                // sorted(zip(unique, counts), key=count, reverse=True)[0][0]
                var best = uniq[0]
                for u in uniq where counts[u]! > counts[best]! { best = u }
                label = Int(best)
            } else {
                label = Int(uniq[0])
            }
            let tar = groups[label].bbox
            if tar.x2 > endX { break }
            // grid id most overlapped in this window
            var gcount: [Int32: Int] = [:]
            for yy in rows { for xx in cols where newMap[yy, xx] == Int32(label) { gcount[gridMap[yy, xx], default: 0] += 1 } }
            let gk = gcount.keys.sorted()
            var gbest = gk[0]
            for g in gk where gcount[g]! > gcount[gbest]! { gbest = g }
            let grid = grids[Int(gbest)]
            // interp1d([-i-1, 0], [grid.y_center, centers[0]])
            let x0 = Double(-i - 1), y0 = grid.yCenter, y1v = centers[0]
            let slope = (y1v - y0) / (0 - x0)
            var candIds: [Int] = []
            for (bi, box) in cands.enumerated() {
                let interpY = Double(pyRound(slope * (Double(-bi - 1) - x0) + y0 - Double(h) / 2))
                let nb = (x1: box.x1, y1: interpY, x2: box.x2, y2: interpY + Double(h))
                candIds.append(grids.count)
                gg.gids.append(grids.count)
                gg.bbox = (min(gg.bbox.x1, nb.x1), Int(min(Double(gg.bbox.y1), nb.y1)),
                           max(gg.bbox.x2, nb.x2), Int(max(Double(gg.bbox.y2), nb.y2)))
                grids.append(GridCell(bbox: nb))
                let ry0 = pySliceStart(Int(nb.y1), H), ry1 = pySliceStop(Int(nb.y2), H)
                let rx0 = pySliceStart(nb.x1, W), rx1 = pySliceStop(nb.x2, W)
                if ry0 < ry1 && rx0 < rx1 {
                    for yy in ry0..<ry1 { for xx in rx0..<rx1 { newMap[yy, xx] = Int32(gg.id) } }
                }
            }
            gg = groups[label]
            refGids = Array((gg.gids + candIds.reversed()).prefix(refCount))
            break
        }
    }
    return newMap
}

/// Vertical source coordinate for every output pixel (`coords_y` in the original).
func estimateDewarpMapping(_ staffPred: Mask) -> Grid<Float> {
    let H = staffPred.height, W = staffPred.width
    var pred = dilate(staffPred, StructuringElement.rect(width: 1, height: 6))
    pred = morphOpen(pred, StructuringElement.rect(width: 6, height: 1))
    let (gridMap, grids) = buildGrid(pred)
    let (ggMap, groups) = buildGridGroups(gridMap, grids)
    let newMap = connectNearbyGridGroups(ggMap, groups, gridMap, grids)

    // build_mapping: per long region, target row and sampled (x, source y) knots
    let (regions, n) = labelRegions(width: W, height: H) { newMap.data[$0] != -1 }
    var ySum = [Int](repeating: 0, count: n + 1)
    var cnt = [Int](repeating: 0, count: n + 1)
    var minX = [Int](repeating: Int.max, count: n + 1)
    var maxX = [Int](repeating: Int.min, count: n + 1)
    regions.data.withUnsafeBufferPointer { R in
        for y in 0..<H {
            let row = y * W
            for x in 0..<W {
                let r = Int(R[row + x])
                if r == 0 { continue }
                ySum[r] += y
                cnt[r] += 1
                if x < minX[r] { minX[r] = x }
                if x > maxX[r] { maxX[r] = x }
            }
        }
    }
    let minWidth = Double(W) * 0.4
    // per-column row sums/counts only for the long regions
    var slot = [Int](repeating: -1, count: n + 1)
    var longRegions: [Int] = []
    for r in 1...max(n, 1) where r <= n && !(Double(maxX[r] - minX[r]) < minWidth) {
        slot[r] = longRegions.count
        longRegions.append(r)
    }
    var colRowSum = [Int](repeating: 0, count: longRegions.count * W)
    var colCount = [Int](repeating: 0, count: longRegions.count * W)
    regions.data.withUnsafeBufferPointer { R in
        for y in 0..<H {
            let row = y * W
            for x in 0..<W {
                let r = Int(R[row + x])
                if r == 0 { continue }
                let s = slot[r]
                if s < 0 { continue }
                colRowSum[s * W + x] += y
                colCount[s * W + x] += 1
            }
        }
    }
    var coordsAt: [Int: [Int: Int]] = [:]  // target row -> (x -> source y), later regions overwrite
    var lines: [(target: Int, xs: [Int])] = []
    for (s, r) in longRegions.enumerated() {
        let target = pyRound(Double(ySum[r]) / Double(cnt[r]))
        var xs: [Int] = []
        var ii = 0
        for x in 0..<W where colCount[s * W + x] > 0 {
            if ii % 10 == 0 {
                coordsAt[target, default: [:]][x] = pyRound(Double(colRowSum[s * W + x]) / Double(colCount[s * W + x]))
                xs.append(x)
            }
            ii += 1
        }
        lines.append((target, xs))
    }
    if H > 0 { coordsAt[0] = [:]; coordsAt[H - 1] = [:] }

    // column-wise interpolation between knots
    var out = Grid<Float>(width: W, height: H, repeating: 0)
    let perLine: [(Int, [Int], [Double])] = lines.compactMap { l in
        if l.target == 0 || l.target == H - 1 { return nil }
        return (l.target, l.xs, l.xs.map { Double(coordsAt[l.target]?[$0] ?? 0) })
    }
    for c in 0..<W {
        // not a literal: 0 and H - 1 coincide on a one-row image (Python's dict just overwrites)
        var knots: [Int: Double] = [0: 0]
        knots[H - 1] = Double(H - 1)
        for (target, xs, vals) in perLine where xs.first! <= c && c <= xs.last! {
            knots[target] = interp(Double(c), xs.map { Double($0) }, vals)
        }
        let ky = knots.keys.sorted().map { Double($0) }
        let kv = ky.map { knots[Int($0)]! }
        for r in 0..<H { out[r, c] = Float(interp(Double(r), ky, kv)) }
    }
    return out
}

/// numpy.interp for increasing xp (same arithmetic as numpy's compiled loop).
private func interp(_ x: Double, _ xp: [Double], _ fp: [Double]) -> Double {
    let n = xp.count
    if n == 1 { return fp[0] }
    if x < xp[0] { return fp[0] }
    if x > xp[n - 1] { return fp[n - 1] }
    if x == xp[n - 1] { return fp[n - 1] }
    // binary search: largest j with xp[j] <= x
    var lo = 0, hi = n - 1
    while hi - lo > 1 {
        let mid = (lo + hi) / 2
        if xp[mid] <= x { lo = mid } else { hi = mid }
    }
    let j = lo
    if xp[j] == x { return fp[j] }
    let slope = (fp[j + 1] - fp[j]) / (xp[j + 1] - xp[j])
    return slope * (x - xp[j]) + fp[j]
}

/// OpenCV's bicubic coefficients (A = -0.75) for the 32 sub-pixel positions.
private let cubicTable: [(Float, Float, Float, Float)] = (0..<32).map { i in
    let A: Float = -0.75
    let t = Float(i) / 32
    let x = t + 1
    let w0 = ((A * x - 5 * A) * x + 8 * A) * x - 4 * A
    let w1 = ((A + 2) * t - (A + 3)) * t * t + 1
    let t1 = 1 - t
    let w2 = ((A + 2) * t1 - (A + 3)) * t1 * t1 + 1
    let w3 = 1 - w0 - w1 - w2
    return (w0, w1, w2, w3)
}

/// `cv2.remap(img.astype(np.float32), coords_x, coords_y, cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)`
/// for binary maps whose x mapping is the identity: bicubic (A = -0.75) vertical resampling,
/// `out(r, c) = in(coordsY(r, c), c)`, with the same float32 arithmetic as OpenCV.
func remapVertical(_ srcs: [Mask], _ coordsY: Grid<Float>) -> [Grid<Float>] {
    let H = coordsY.height, W = coordsY.width
    var outs = srcs.map { Grid<Float>(width: $0.width, height: $0.height, repeating: 0) }
    let table = cubicTable
    for k in 0..<srcs.count {
        srcs[k].data.withUnsafeBufferPointer { s in
            outs[k].data.withUnsafeMutableBufferPointer { o in
                coordsY.data.withUnsafeBufferPointer { cy in
                    for r in 0..<H {
                        let row = r * W
                        for c in 0..<W {
                            // OpenCV converts float maps to fixed point with 1/32 pixel steps
                            let iy = cvRound(cy[row + c] * 32)
                            let y0 = iy >> 5
                            let w = table[iy & 31]
                            let ya = min(max(y0 - 1, 0), H - 1), yb = min(max(y0, 0), H - 1)
                            let yc = min(max(y0 + 1, 0), H - 1), yd = min(max(y0 + 2, 0), H - 1)
                            var v: Float = 0
                            v += w.0 * Float(s[ya * W + c])
                            v += w.1 * Float(s[yb * W + c])
                            v += w.2 * Float(s[yc * W + c])
                            v += w.3 * Float(s[yd * W + c])
                            o[row + c] = v
                        }
                    }
                }
            }
        }
    }
    return outs
}

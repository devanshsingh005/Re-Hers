import Foundation

/// OpenCV `RotatedRect` (center, size, angle in degrees).
public struct RotatedRect {
    public var centerX: Float = 0
    public var centerY: Float = 0
    public var width: Float = 0
    public var height: Float = 0
    public var angle: Float = 0

    /// `cv2.boxPoints(rect)` / RotatedRect::points.
    public func points() -> [(x: Float, y: Float)] {
        let angleRad = Double(angle) * Double.pi / 180.0
        let b = Float(cos(angleRad)) * 0.5
        let a = Float(sin(angleRad)) * 0.5
        let ah = a * height
        let aw = a * width
        let bh = b * height
        let bw = b * width
        return [
            (centerX - ah - bw, centerY + bh - aw),
            (centerX + ah - bw, centerY - bh - aw),
            (centerX + ah + bw, centerY - bh + aw),
            (centerX - ah + bw, centerY + bh + aw),
        ]
    }
}

@inline(__always) private func cvSign(_ v: Int64) -> Int { v > 0 ? 1 : (v < 0 ? -1 : 0) }
@inline(__always) private func cvSign(_ v: Int) -> Int { v > 0 ? 1 : (v < 0 ? -1 : 0) }

/// Sklansky_<int, int64> from convhull.cpp. `array` holds indices into `pts`; results are
/// written to `stack[base...]`.
private func sklansky(_ pts: [(x: Int, y: Int)], _ array: [Int], _ start: Int, _ endIn: Int,
                      _ stack: inout [Int], _ base: Int, _ nsign: Int, _ sign2: Int) -> Int
{
    var end = endIn
    let incr = end > start ? 1 : -1
    var pprev = start, pcur = pprev + incr, pnext = pcur + incr
    var stacksize = 3

    if start == end || (pts[array[start]].x == pts[array[end]].x && pts[array[start]].y == pts[array[end]].y) {
        stack[base + 0] = start
        return 1
    }
    stack[base + 0] = pprev
    stack[base + 1] = pcur
    stack[base + 2] = pnext
    end += incr

    while pnext != end {
        let cury = pts[array[pcur]].y
        let nexty = pts[array[pnext]].y
        let by = nexty - cury
        if cvSign(by) != nsign {
            let ax = pts[array[pcur]].x - pts[array[pprev]].x
            let ay = cury - pts[array[pprev]].y
            let bx = pts[array[pnext]].x - pts[array[pcur]].x
            let convexity = Int64(ay) * Int64(bx) - Int64(ax) * Int64(by)
            if cvSign(convexity) == sign2 && (ax != 0 || ay != 0) {
                pprev = pcur
                pcur = pnext
                pnext += incr
                stack[base + stacksize] = pnext
                stacksize += 1
            } else {
                if pprev == start {
                    pcur = pnext
                    stack[base + 1] = pcur
                    pnext += incr
                    stack[base + 2] = pnext
                } else {
                    stack[base + stacksize - 2] = pnext
                    pcur = pprev
                    pprev = stack[base + stacksize - 4]
                    stacksize -= 1
                }
            }
        } else {
            pnext += incr
            stack[base + stacksize - 1] = pnext
        }
    }
    stacksize -= 1
    return stacksize
}

/// `cv::convexHull(points, hull, clockwise=false, returnPoints=true)` for integer points.
func convexHull(_ pts: [(x: Int, y: Int)]) -> [(x: Int, y: Int)] {
    let total = pts.count
    if total == 0 { return [] }
    // sort by x, then y, then original position (pointer comparison in OpenCV)
    let pointer = (0..<total).sorted { a, b in
        if pts[a].x != pts[b].x { return pts[a].x < pts[b].x }
        if pts[a].y != pts[b].y { return pts[a].y < pts[b].y }
        return a < b
    }
    var minyInd = 0, maxyInd = 0
    for i in 1..<max(total, 1) {
        let y = pts[pointer[i]].y
        if pts[pointer[minyInd]].y > y { minyInd = i }
        if pts[pointer[maxyInd]].y < y { maxyInd = i }
    }
    var hullbuf: [Int] = []
    var stack = [Int](repeating: 0, count: total + 2)

    if pts[pointer[0]].x == pts[pointer[total - 1]].x && pts[pointer[0]].y == pts[pointer[total - 1]].y {
        hullbuf.append(0)
    } else {
        // upper half
        var tlBase = 0
        var tlCount = sklansky(pts, pointer, 0, maxyInd, &stack, tlBase, -1, 1)
        var trBase = tlCount
        var trCount = sklansky(pts, pointer, total - 1, maxyInd, &stack, trBase, -1, -1)
        // !clockwise: swap
        swap(&tlBase, &trBase)
        swap(&tlCount, &trCount)
        if tlCount - 1 > 0 { for i in 0..<(tlCount - 1) { hullbuf.append(stack[tlBase + i]) } }
        var i = trCount - 1
        while i > 0 { hullbuf.append(stack[trBase + i]); i -= 1 }
        let stopIdx = trCount > 2 ? stack[trBase + 1] : (tlCount > 2 ? stack[tlBase + tlCount - 2] : -1)

        // lower half
        let blBase = 0
        var blCount = sklansky(pts, pointer, 0, minyInd, &stack, blBase, 1, -1)
        let brBase = blCount
        var brCount = sklansky(pts, pointer, total - 1, minyInd, &stack, brBase, 1, 1)

        if stopIdx >= 0 {
            let checkIdx = blCount > 2 ? stack[blBase + 1] : (blCount + brCount > 2 ? stack[brBase + 2 - blCount] : -1)
            if checkIdx == stopIdx || (checkIdx >= 0
                && pts[pointer[checkIdx]].x == pts[pointer[stopIdx]].x
                && pts[pointer[checkIdx]].y == pts[pointer[stopIdx]].y)
            {
                blCount = min(blCount, 2)
                brCount = min(brCount, 2)
            }
        }
        if blCount - 1 > 0 { for i in 0..<(blCount - 1) { hullbuf.append(stack[blBase + i]) } }
        i = brCount - 1
        while i > 0 { hullbuf.append(stack[brBase + i]); i -= 1 }

        // indices into the original array
        for k in 0..<hullbuf.count { hullbuf[k] = pointer[hullbuf[k]] }

        // cyclic shift so indices are monotonic where possible
        let nout = hullbuf.count
        if nout >= 3 {
            var minIdx = 0, maxIdx = 0, lt = 0
            var i = 1
            while i < nout {
                let idx = hullbuf[i]
                lt += hullbuf[i - 1] < idx ? 1 : 0
                if lt > 1 && lt <= i - 2 { break }
                if idx < hullbuf[minIdx] { minIdx = i }
                if idx > hullbuf[maxIdx] { maxIdx = i }
                i += 1
            }
            let mmdist = abs(maxIdx - minIdx)
            if (mmdist == 1 || mmdist == nout - 1) && (lt <= 1 || lt >= nout - 2) {
                let ascending = (maxIdx + 1) % nout == minIdx
                let i0 = ascending ? minIdx : maxIdx
                var j = i0
                if i0 > 0 {
                    var tmp = [Int](repeating: 0, count: nout)
                    var k = 0
                    while k < nout {
                        let currIdx = hullbuf[j]
                        tmp[k] = currIdx
                        let nextJ = j + 1 < nout ? j + 1 : 0
                        let nextIdx = hullbuf[nextJ]
                        if k < nout - 1 && (ascending != (currIdx < nextIdx)) { break }
                        j = nextJ
                        k += 1
                    }
                    if k == nout { hullbuf = tmp }
                }
            }
        }
        return hullbuf.map { pts[$0] }
    }
    return hullbuf.map { pts[pointer[$0]] }
}

/// rotatingCalipers(..., CALIPERS_MINAREARECT) from rotcalipers.cpp. Returns corner, vector1, vector2.
private func rotatingCalipersMinArea(_ points: [(x: Float, y: Float)], orientation: Float) -> [Float] {
    let n = points.count
    var minarea = Float.greatestFiniteMagnitude
    var bufSeq3 = 0, bufSeq0 = 0
    var bufA: Float = 0, bufW: Float = 0, bufB: Float = 0, bufH: Float = 0
    var invLen = [Float](repeating: 0, count: n)
    var vx = [Float](repeating: 0, count: n)
    var vy = [Float](repeating: 0, count: n)
    var left = 0, bottom = 0, right = 0, top = 0
    var seq = [-1, -1, -1, -1]

    var baseA: Float
    var baseB: Float = 0
    var pt0 = points[0]
    var leftX = pt0.x, rightX = pt0.x
    var topY = pt0.y, bottomY = pt0.y

    for i in 0..<n {
        if pt0.x < leftX { leftX = pt0.x; left = i }
        if pt0.x > rightX { rightX = pt0.x; right = i }
        if pt0.y > topY { topY = pt0.y; top = i }
        if pt0.y < bottomY { bottomY = pt0.y; bottom = i }
        let pt = points[i + 1 < n ? i + 1 : 0]
        let dx = Double(pt.x) - Double(pt0.x)
        let dy = Double(pt.y) - Double(pt0.y)
        vx[i] = Float(dx)
        vy[i] = Float(dy)
        invLen[i] = Float(1.0 / (dx * dx + dy * dy).squareRoot())
        pt0 = pt
    }
    baseA = orientation
    seq[0] = bottom
    seq[1] = right
    seq[2] = top
    seq[3] = left

    for _ in 0..<n {
        var mainElement = 0
        let rot: [(x: Float, y: Float)] = [
            (vx[seq[0]], vy[seq[0]]),
            (vy[seq[1]], -vx[seq[1]]),     // rotate90CW
            (-vx[seq[2]], -vy[seq[2]]),    // rotate180
            (-vy[seq[3]], vx[seq[3]]),     // rotate90CCW
        ]
        for i in 1..<4 {
            // firstVecIsRight(rot[i], rot[main])
            let tmpX = rot[i].y
            let tmpY = -rot[i].x
            if tmpX * rot[mainElement].x + tmpY * rot[mainElement].y < 0 { mainElement = i }
        }
        let pindex = seq[mainElement]
        let leadX = vx[pindex] * invLen[pindex]
        let leadY = vy[pindex] * invLen[pindex]
        switch mainElement {
        case 0: baseA = leadX; baseB = leadY
        case 1: baseA = leadY; baseB = -leadX
        case 2: baseA = -leadX; baseB = -leadY
        default: baseA = -leadY; baseB = leadX
        }
        seq[mainElement] += 1
        if seq[mainElement] == n { seq[mainElement] = 0 }

        var dx = points[seq[1]].x - points[seq[3]].x
        var dy = points[seq[1]].y - points[seq[3]].y
        let width = dx * baseA + dy * baseB
        dx = points[seq[2]].x - points[seq[0]].x
        dy = points[seq[2]].y - points[seq[0]].y
        let height = -dx * baseB + dy * baseA
        let area = width * height
        if area <= minarea {
            minarea = area
            bufSeq3 = seq[3]
            bufA = baseA
            bufW = width
            bufB = baseB
            bufH = height
            bufSeq0 = seq[0]
        }
    }

    let A1 = bufA
    let B1 = bufB
    let A2 = -bufB
    let B2 = bufA
    let C1 = A1 * points[bufSeq3].x + points[bufSeq3].y * B1
    let C2 = A2 * points[bufSeq0].x + points[bufSeq0].y * B2
    let idet = 1 / (A1 * B2 - A2 * B1)
    let px = (C1 * B2 - C2 * B1) * idet
    let py = (A1 * C2 - A2 * C1) * idet
    return [px, py, A1 * bufW, B1 * bufW, A2 * bufH, B2 * bufH]
}

/// `cv2.minAreaRect(points)` for integer points.
public func minAreaRect(_ pts: [(x: Int, y: Int)]) -> RotatedRect {
    let hullI = convexHull(pts)
    let hull = hullI.map { (x: Float($0.x), y: Float($0.y)) }
    var box = RotatedRect()
    var angle = -Double.pi / 2
    let n = hull.count
    if n > 2 {
        let out = rotatingCalipersMinArea(hull, orientation: 1)
        box.centerX = out[0] + (out[2] + out[4]) * 0.5
        box.centerY = out[1] + (out[3] + out[5]) * 0.5
        box.width = Float((Double(out[4]) * Double(out[4]) + Double(out[5]) * Double(out[5])).squareRoot())
        box.height = Float((Double(out[2]) * Double(out[2]) + Double(out[3]) * Double(out[3])).squareRoot())
        if out[2] == 0 && out[3] > 0 {
            swap(&box.width, &box.height)
        } else {
            angle = -atan2(Double(out[2]), Double(out[3]))
        }
    } else if n == 2 {
        box.centerX = (hull[0].x + hull[1].x) * 0.5
        box.centerY = (hull[0].y + hull[1].y) * 0.5
        let dx = Double(hull[0].x - hull[1].x)
        let dy = Double(hull[0].y - hull[1].y)
        box.width = 0
        box.height = Float((dx * dx + dy * dy).squareRoot())
        if dx == 0 {
            swap(&box.width, &box.height)
        } else if dy < 0 {
            angle = atan2(dy, dx)
            swap(&box.width, &box.height)
        } else if dy > 0 {
            angle = -atan2(dx, dy)
        }
    } else if n == 1 {
        box.centerX = hull[0].x
        box.centerY = hull[0].y
    }
    box.angle = Float(angle * 180 / Double.pi)
    return box
}

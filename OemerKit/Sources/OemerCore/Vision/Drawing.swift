// Port of the parts of OpenCV 4.14 imgproc/src/drawing.cpp that oemer relies on:
// 8-connected lines (cv2.line on float images falls back to LINE_8) and cv2.fillPoly.

private let XY_SHIFT = 16
private let XY_ONE: Int64 = 1 << 16

/// clipLine(Size2l, Point2l&, Point2l&)
@discardableResult
func clipLine(width: Int, height: Int, _ p1: inout (x: Int, y: Int), _ p2: inout (x: Int, y: Int)) -> Bool {
    if width <= 0 || height <= 0 { return false }
    let right = width - 1, bottom = height - 1
    var x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y
    func code(_ x: Int, _ y: Int) -> Int {
        (x < 0 ? 1 : 0) + (x > right ? 2 : 0) + (y < 0 ? 4 : 0) + (y > bottom ? 8 : 0)
    }
    var c1 = code(x1, y1)
    var c2 = code(x2, y2)
    if (c1 & c2) == 0 && (c1 | c2) != 0 {
        if (c1 & 12) != 0 {
            let a = c1 < 8 ? 0 : bottom
            x1 += Int(Double(a - y1) * Double(x2 - x1) / Double(y2 - y1))
            y1 = a
            c1 = (x1 < 0 ? 1 : 0) + (x1 > right ? 2 : 0)
        }
        if (c2 & 12) != 0 {
            let a = c2 < 8 ? 0 : bottom
            x2 += Int(Double(a - y2) * Double(x2 - x1) / Double(y2 - y1))
            y2 = a
            c2 = (x2 < 0 ? 1 : 0) + (x2 > right ? 2 : 0)
        }
        if (c1 & c2) == 0 && (c1 | c2) != 0 {
            if c1 != 0 {
                let a = c1 == 1 ? 0 : right
                y1 += Int(Double(a - x1) * Double(y2 - y1) / Double(x2 - x1))
                x1 = a
                c1 = 0
            }
            if c2 != 0 {
                let a = c2 == 1 ? 0 : right
                y2 += Int(Double(a - x2) * Double(y2 - y1) / Double(x2 - x1))
                x2 = a
                c2 = 0
            }
        }
    }
    p1 = (x1, y1)
    p2 = (x2, y2)
    return (c1 | c2) == 0
}

/// Pixels visited by `LineIterator(img, pt1, pt2, connectivity=8, leftToRight=true)`.
func linePixels(width: Int, height: Int, _ a: (x: Int, y: Int), _ b: (x: Int, y: Int),
                _ visit: (Int, Int) -> Void)
{
    var pt1 = a, pt2 = b
    if pt1.x < 0 || pt1.x >= width || pt2.x < 0 || pt2.x >= width
        || pt1.y < 0 || pt1.y >= height || pt2.y < 0 || pt2.y >= height
    {
        if !clipLine(width: width, height: height, &pt1, &pt2) { return }
    }
    var deltaX = 1, deltaY = 1
    var dx = pt2.x - pt1.x
    var dy = pt2.y - pt1.y
    if dx < 0 {
        dx = -dx
        dy = -dy
        pt1 = pt2
    }
    if dy < 0 {
        dy = -dy
        deltaY = -1
    }
    let vert = dy > dx
    if vert {
        swap(&dx, &dy)
        swap(&deltaX, &deltaY)
    }
    var err = dx - (dy + dy)
    let plusDelta = dx + dx
    let minusDelta = -(dy + dy)
    var minusShift = deltaX
    var plusShift = 0
    var minusStep = 0
    var plusStep = deltaY
    let count = dx + 1
    if vert {
        swap(&plusStep, &plusShift)
        swap(&minusStep, &minusShift)
    }
    var px = pt1.x, py = pt1.y
    for _ in 0..<count {
        visit(px, py)
        let mask = err < 0 ? -1 : 0
        err += minusDelta + (plusDelta & mask)
        px += minusShift + (plusShift & mask)
        py += minusStep + (plusStep & mask)
    }
}

private struct PolyEdge {
    var y0: Int
    var y1: Int
    var x: Int64
    var dx: Int64
    var next: Int = -1
}

/// `cv2.fillPoly(img, [pts], color)` with integer points, LINE_8 and shift 0. Calls `set(x, y)`
/// for every pixel OpenCV would paint (polygon outline plus interior, possibly repeated).
func fillPoly(width: Int, height: Int, _ v: [(x: Int, y: Int)], _ set: (Int, Int) -> Void) {
    let count = v.count
    if count == 0 { return }
    var edges: [PolyEdge] = []
    var pt0 = (x: Int64(v[count - 1].x) << Int64(XY_SHIFT), y: Int64(v[count - 1].y))
    for i in 0..<count {
        let pt1 = (x: Int64(v[i].x) << Int64(XY_SHIFT), y: Int64(v[i].y))
        defer { pt0 = pt1 }
        var pt0c = pt0, pt1c = pt1
        var t0 = (x: Int((pt0.x + (XY_ONE >> 1)) >> Int64(XY_SHIFT)), y: Int(pt0.y))
        var t1 = (x: Int((pt1.x + (XY_ONE >> 1)) >> Int64(XY_SHIFT)), y: Int(pt1.y))
        linePixels(width: width, height: height, t0, t1, set)
        if t0.x < 0 || t0.x >= width || t1.x < 0 || t1.x >= width
            || t0.y < 0 || t0.y >= height || t1.y < 0 || t1.y >= height
        {
            clipLine(width: width, height: height, &t0, &t1)
            if t0.y != t1.y {
                pt0c.y = Int64(t0.y)
                pt1c.y = Int64(t1.y)
            }
        }
        pt0c.x = Int64(t0.x) << Int64(XY_SHIFT)
        pt1c.x = Int64(t1.x) << Int64(XY_SHIFT)
        if pt0.y == pt1.y { continue }
        let dx = (pt1c.x - pt0c.x) / (pt1c.y - pt0c.y)
        if pt0.y < pt1.y {
            edges.append(PolyEdge(y0: Int(pt0.y), y1: Int(pt1.y), x: pt0c.x + (pt0.y - pt0c.y) * dx, dx: dx))
        } else {
            edges.append(PolyEdge(y0: Int(pt1.y), y1: Int(pt0.y), x: pt1c.x + (pt1.y - pt1c.y) * dx, dx: dx))
        }
    }
    fillEdgeCollection(width: width, height: height, &edges, set)
}

private func fillEdgeCollection(width: Int, height: Int, _ edgesIn: inout [PolyEdge], _ set: (Int, Int) -> Void) {
    let total = edgesIn.count
    if total < 2 { return }
    var yMax = Int.min, yMin = Int.max
    var xMax: Int64 = -1, xMin: Int64 = Int64.max
    for e1 in edgesIn {
        let x1 = e1.x + Int64(e1.y1 - e1.y0) * e1.dx
        yMin = min(yMin, e1.y0)
        yMax = max(yMax, e1.y1)
        xMin = min(xMin, e1.x)
        xMax = max(xMax, e1.x)
        xMin = min(xMin, x1)
        xMax = max(xMax, x1)
    }
    if yMax < 0 || yMin >= height || xMax < 0 || xMin >= (Int64(width) << Int64(XY_SHIFT)) { return }

    // std::sort with CmpEdges (y0, then x, then dx); stable here, ties are interchangeable
    var edges = edgesIn.enumerated().sorted { a, b in
        if a.element.y0 != b.element.y0 { return a.element.y0 < b.element.y0 }
        if a.element.x != b.element.x { return a.element.x < b.element.x }
        if a.element.dx != b.element.dx { return a.element.dx < b.element.dx }
        return a.offset < b.offset
    }.map { $0.element }
    edges.append(PolyEdge(y0: Int.max, y1: 0, x: 0, dx: 0))  // sentinel

    let HEAD = -2  // the `tmp` list head
    var headNext = -1
    func setNext(_ idx: Int, _ v: Int) { if idx == HEAD { headNext = v } else { edges[idx].next = v } }

    let delta = XY_ONE - 1
    var i = 0
    var e = 0
    yMax = min(yMax, height)
    var y = edges[e].y0
    while y < yMax {
        var draw = 0
        let clipline = y < 0
        var prelast = HEAD
        var last = headNext
        while last != -1 || edges[e].y0 == y {
            if last != -1 && edges[last].y1 == y {
                setNext(prelast, edges[last].next)
                last = edges[last].next
                continue
            }
            let keepPrelast = prelast
            if last != -1 && (edges[e].y0 > y || edges[last].x < edges[e].x) {
                prelast = last
                last = edges[last].next
            } else if i < total {
                setNext(prelast, e)
                edges[e].next = last
                prelast = e
                i += 1
                e = i
            } else {
                break
            }
            if draw != 0 {
                if !clipline {
                    var x1: Int, x2: Int
                    if edges[keepPrelast].x > edges[prelast].x {
                        x1 = Int((edges[prelast].x + delta) >> Int64(XY_SHIFT))
                        x2 = Int(edges[keepPrelast].x >> Int64(XY_SHIFT))
                    } else {
                        x1 = Int((edges[keepPrelast].x + delta) >> Int64(XY_SHIFT))
                        x2 = Int(edges[prelast].x >> Int64(XY_SHIFT))
                    }
                    if x1 < width && x2 >= 0 {
                        if x1 < 0 { x1 = 0 }
                        if x2 >= width { x2 = width - 1 }
                        if x1 <= x2 { for xx in x1...x2 { set(xx, y) } }
                    }
                }
                edges[keepPrelast].x += edges[keepPrelast].dx
                edges[prelast].x += edges[prelast].dx
            }
            draw ^= 1
        }

        // bubble sort of the active edge list by x
        var keepPrelast = -1
        repeat {
            var prelast2 = HEAD
            var last2 = headNext
            var lastExchange = -1
            while last2 != keepPrelast && last2 != -1 && edges[last2].next != -1 {
                let te = edges[last2].next
                if edges[last2].x > edges[te].x {
                    setNext(prelast2, te)
                    edges[last2].next = edges[te].next
                    edges[te].next = last2
                    prelast2 = te
                    lastExchange = prelast2
                } else {
                    prelast2 = last2
                    last2 = te
                }
            }
            if lastExchange == -1 { break }
            keepPrelast = lastExchange
        } while keepPrelast != headNext && keepPrelast != HEAD
        y += 1
    }
}

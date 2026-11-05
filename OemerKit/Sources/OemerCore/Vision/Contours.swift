/// A traced border, as returned by `cv2.findContours(img, RETR_TREE, CHAIN_APPROX_SIMPLE)`.
public struct Contour {
    /// Border points after CHAIN_APPROX_SIMPLE compression, in image coordinates.
    public var points: [(x: Int, y: Int)]
    public var isHole: Bool

    /// `cv2.boundingRect(points)` as (x1, y1, x2, y2) with exclusive x2/y2, i.e. oemer's `get_bbox` box.
    public var bbox: BBox {
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return BBox(minX, minY, maxX + 1, maxY + 1)
    }
}

// Port of OpenCV 4.14 modules/imgproc/src/contours_new.cpp (8-bit image path, RETR_TREE,
// CHAIN_APPROX_SIMPLE). The output order (depth-first over the contour tree, newest sibling
// first) matters for oemer, so this follows the original control flow closely.

private let chainDX: [Int] = [1, 1, 0, -1, -1, -1, 0, 1]
private let chainDY: [Int] = [0, -1, -1, -1, 0, 1, 1, 1]
private let MASK8_RIGHT: Int8 = Int8(bitPattern: 0x80)
private let MASK8_NEW: Int8 = 0x02
private let MASK8_FLAGS: Int8 = Int8(bitPattern: 0xFE)
private let MASK8_BLACK: Int8 = 0x01
private let MASK8_LVAL: Int8 = 0x7F

private struct CNode {
    var parent = -1
    var firstChild = -1
    var prev = -1
    var next = -1
    var ctableNext = -1
    var isHole = false
    var origin = (x: 0, y: 0)          // padded-image coordinates
    var brect = (x: 0, y: 0, w: 0, h: 0) // padded-image coordinates
    var points: [(x: Int, y: Int)] = []
}

private struct ContourScanner {
    var img: [Int8]
    let step: Int        // padded width
    let rows: Int        // padded height
    var pt = (x: 1, y: 1)
    var lnbd = (x: 0, y: 1)
    var nbd: Int8 = 2
    var tree: [CNode] = []
    var ctable = [Int](repeating: -1, count: 128)

    init(mask: Mask) {
        step = mask.width + 2
        rows = mask.height + 2
        img = [Int8](repeating: 0, count: step * rows)
        for y in 0..<mask.height {
            for x in 0..<mask.width where mask.data[y * mask.width + x] != 0 {
                img[(y + 1) * step + x + 1] = 1
            }
        }
        var root = CNode()
        root.isHole = true
        root.brect = (0, 0, step, rows)
        tree.append(root)
    }

    @inline(__always) func delta(_ s: Int) -> Int {
        let d = s % 8
        return chainDX[d] + chainDY[d] * step
    }

    mutating func addChild(_ parentIdx: Int, _ childIdx: Int) {
        if tree[parentIdx].firstChild != -1 {
            let fc = tree[parentIdx].firstChild
            tree[fc].prev = childIdx
            tree[childIdx].next = fc
        }
        tree[parentIdx].firstChild = childIdx
        tree[childIdx].parent = parentIdx
        tree[childIdx].prev = -1
    }

    /// icvFetchContourEx<schar>
    mutating func fetchContour(start: (x: Int, y: Int), nbd: Int8, node: inout CNode) {
        let i0 = start.y * step + start.x
        // origin includes the (-1, -1) offset so points come out in unpadded coordinates
        var pt = (x: node.origin.x, y: node.origin.y)
        var rect = (x: pt.x, y: pt.y, w: pt.x, h: pt.y)
        var sEnd = node.isHole ? 0 : 4
        var s = sEnd
        var i1 = 0
        repeat {
            s = (s - 1) & 7
            i1 = i0 + delta(s)
        } while img[i1] == 0 && s != sEnd

        if s == sEnd {
            img[i0] = nbd | MASK8_RIGHT
            node.points.append(pt)
        } else {
            var i3 = i0
            var i4 = 0
            var prevS = s ^ 4
            while true {
                sEnd = s
                s = min(s, 15)
                while s < 15 {
                    s += 1
                    i4 = i3 + delta(s)
                    if img[i4] != 0 { break }
                }
                s &= 7
                if UInt(bitPattern: s - 1) < UInt(sEnd) {
                    img[i3] = nbd | MASK8_RIGHT
                } else if img[i3] == MASK8_BLACK {
                    img[i3] = nbd
                }
                if s != prevS {
                    node.points.append(pt)
                    if pt.x < rect.x { rect.x = pt.x } else if pt.x > rect.w { rect.w = pt.x }
                    if pt.y < rect.y { rect.y = pt.y } else if pt.y > rect.h { rect.h = pt.y }
                }
                prevS = s
                pt.x += chainDX[s]
                pt.y += chainDY[s]
                if i4 == i0 && i3 == i1 { break }
                i3 = i4
                s = (s + 4) & 7
            }
        }
        rect.w -= rect.x - 1
        rect.h -= rect.y - 1
        node.brect = rect
    }

    /// icvTraceContour<schar>
    func traceContour(start: (x: Int, y: Int), end: (x: Int, y: Int), isHole: Bool) -> Bool {
        let stop = end.y * step + end.x
        let i0 = start.y * step + start.x
        let sEnd = isHole ? 0 : 4
        var s = sEnd
        var i1 = 0
        repeat {
            s = (s - 1) & 7
            i1 = i0 + delta(s)
        } while img[i1] == 0 && s != sEnd
        var i3 = i0
        var i4 = 0
        if s != sEnd {
            while true {
                s = min(s, 15)
                while s < 15 {
                    s += 1
                    i4 = i3 + delta(s)
                    if img[i4] != 0 { break }
                }
                if i3 == stop {
                    if (img[i3] & MASK8_RIGHT) == 0 { return true }
                    var t = s
                    while true {
                        t = (t - 1) & 7
                        let i5 = i3 + delta(t)
                        if img[i5] != 0 { break }
                        if t == 0 { return true }
                    }
                }
                if i4 == i0 && i3 == i1 { break }
                i3 = i4
                s = (s + 4) & 7
            }
        } else {
            return i3 == stop
        }
        return false
    }

    mutating func makeContour(nbd nbdIn: inout Int8, isHole: Bool, x: Int, y: Int) -> Int {
        let start = (x: x - (isHole ? 1 : 0), y: y)
        var node = CNode()
        node.isHole = isHole
        node.origin = (start.x - 1, start.y - 1)
        let lval = nbdIn
        nbdIn = (nbdIn &+ 1) & MASK8_LVAL
        if nbdIn == 0 { nbdIn = MASK8_BLACK | MASK8_NEW }
        fetchContour(start: start, nbd: lval, node: &node)
        node.brect.x += 1  // brect.x -= offset.x with offset = (-1, -1)
        node.brect.y += 1
        let idx = tree.count
        node.ctableNext = ctable[Int(lval)]
        ctable[Int(lval)] = idx
        node.origin = start
        tree.append(node)
        return idx
    }

    func findFirstBoundingContour(lastPos: (x: Int, y: Int), y: Int, lval: Int, par: Int) -> Int {
        let end = (x: lastPos.x, y: y)
        var res = par
        var cur = ctable[lval]
        while cur != -1 {
            let e = tree[cur]
            if (lastPos.x - e.brect.x) < e.brect.w && (lastPos.y - e.brect.y) < e.brect.h {
                if res != -1 {
                    let r = tree[res]
                    if traceContour(start: r.origin, end: end, isHole: r.isHole) { break }
                }
                res = cur
            }
            cur = e.ctableNext
        }
        return res
    }

    mutating func contourScan(prev: Int, p: Int, lastPos: inout (x: Int, y: Int), x: Int, y: Int) -> Bool {
        var isHole = false
        if !(prev == 0 && p == 1) {
            if p != 0 || prev < 1 { return false }
            if (prev & Int(MASK8_FLAGS)) != 0 { lastPos.x = x - 1 }
            isHole = true
        }
        var mainParent = -1
        if lastPos.x <= 0 {
            mainParent = 0
        } else {
            let lval = Int(img[lastPos.y * step + lastPos.x] & MASK8_LVAL)
            mainParent = findFirstBoundingContour(lastPos: lastPos, y: y, lval: lval, par: mainParent)
            if mainParent == -1 { mainParent = 0 }  // never expected; OpenCV would read out of bounds
            if tree[mainParent].isHole == isHole {
                mainParent = tree[mainParent].parent != -1 ? tree[mainParent].parent : 0
            }
        }
        lastPos.x = x - (isHole ? 1 : 0)
        var nbdLocal = nbd
        let idx = makeContour(nbd: &nbdLocal, isHole: isHole, x: x, y: y)
        if tree[idx].parent == -1 { addChild(mainParent, idx) }
        pt = (x + 1, y)
        nbd = nbdLocal
        return true
    }

    mutating func findNext() -> Bool {
        var x = pt.x
        var y = pt.y
        let width = step - 1
        let height = rows - 1
        var lastPos = lnbd
        var prev = Int(img[y * step + x - 1])
        while y < height {
            var p = 0
            while x < width {
                // findNextX: first x with a value different from prev
                while x < width {
                    p = Int(img[y * step + x])
                    if p != prev { break }
                    x += 1
                }
                if x >= width { break }
                if contourScan(prev: prev, p: p, lastPos: &lastPos, x: x, y: y) {
                    lnbd = lastPos
                    return true
                } else {
                    prev = p
                    if (prev & Int(MASK8_FLAGS)) != 0 { lastPos.x = x }
                }
                x += 1
            }
            lastPos = (0, y + 1)
            x = 1
            prev = 0
            y += 1
        }
        return false
    }
}

/// `cv2.findContours(mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)[0]`, in OpenCV's output order.
public func findContours(_ mask: Mask) -> [Contour] {
    if mask.width == 0 || mask.height == 0 { return [] }
    var scanner = ContourScanner(mask: mask)
    while scanner.findNext() {}
    let tree = scanner.tree
    if tree.count <= 1 { return [] }
    // Depth-first traversal (TreeIterator): children visited from first_child along `next`.
    var out: [Contour] = []
    out.reserveCapacity(tree.count - 1)
    var stack: [Int] = [0]
    while let idx = stack.popLast() {
        let node = tree[idx]
        var cur = node.firstChild
        if cur != -1 {
            while tree[cur].next != -1 { cur = tree[cur].next }  // lastSibling
            while cur != -1 {
                stack.append(cur)
                cur = tree[cur].prev
            }
        }
        if idx == 0 { continue }
        out.append(Contour(points: node.points, isHole: node.isHole))
    }
    return out
}

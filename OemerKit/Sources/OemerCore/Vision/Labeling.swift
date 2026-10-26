/// `scipy.ndimage.label(mask)` with the default (4-connected) structure.
/// Labels are 1...count, assigned in raster order of each region's first pixel; 0 is background.
public func labelRegions(_ mask: Mask) -> (labels: Grid<Int32>, count: Int) {
    labelRegions(width: mask.width, height: mask.height) { mask.data[$0] != 0 }
}

/// Same as `labelRegions(_:)` but for any predicate over the flat pixel index.
public func labelRegions(width w: Int, height h: Int, isSet: (Int) -> Bool) -> (labels: Grid<Int32>, count: Int) {
    var labels = Grid<Int32>(width: w, height: h, repeating: 0)
    if w == 0 || h == 0 { return (labels, 0) }
    var parent: [Int32] = [0]  // provisional label -> parent (index 0 unused)

    func find(_ x: Int32) -> Int32 {
        var r = x
        while parent[Int(r)] != r { r = parent[Int(r)] }
        var c = x
        while parent[Int(c)] != r {
            let n = parent[Int(c)]
            parent[Int(c)] = r
            c = n
        }
        return r
    }
    func union(_ a: Int32, _ b: Int32) {
        let ra = find(a), rb = find(b)
        if ra == rb { return }
        if ra < rb { parent[Int(rb)] = ra } else { parent[Int(ra)] = rb }
    }

    var regionCount = 0
    labels.data.withUnsafeMutableBufferPointer { L in
        for y in 0..<h {
            let row = y * w
            for x in 0..<w {
                let i = row + x
                if !isSet(i) { continue }
                let left: Int32 = x > 0 ? L[i - 1] : 0
                let up: Int32 = y > 0 ? L[i - w] : 0
                if left == 0 && up == 0 {
                    let n = Int32(parent.count)
                    parent.append(n)
                    L[i] = n
                } else if left != 0 && up != 0 {
                    L[i] = min(left, up)
                    if left != up { union(left, up) }
                } else {
                    L[i] = left != 0 ? left : up
                }
            }
        }
        // Final numbering: order of first appearance in the raster scan.
        var finalOf = [Int32](repeating: 0, count: parent.count)
        var next: Int32 = 0
        for i in 0..<(w * h) where L[i] != 0 {
            let root = find(L[i])
            if finalOf[Int(root)] == 0 {
                next += 1
                finalOf[Int(root)] = next
            }
            L[i] = finalOf[Int(root)]
        }
        regionCount = Int(next)
    }
    return (labels, regionCount)
}

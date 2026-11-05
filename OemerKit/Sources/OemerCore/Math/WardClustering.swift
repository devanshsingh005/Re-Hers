import Foundation

/// sklearn `AgglomerativeClustering(n_clusters=None, distance_threshold=t, compute_full_tree=True)`
/// with Ward linkage (scipy nn_chain), returning `labels_` exactly as sklearn assigns them.
func wardClusterLabels(_ points: [(Double, Double)], distanceThreshold: Double) -> [Int] {
    let n = points.count
    if n == 0 { return [] }
    if n == 1 { return [0] }  // sklearn raises here; one point is trivially one cluster

    // pdist (euclidean), condensed
    func cidx(_ i: Int, _ j: Int) -> Int {
        i < j ? n * i - (i * (i + 1)) / 2 + (j - i - 1) : n * j - (j * (j + 1)) / 2 + (i - j - 1)
    }
    var D = [Double](repeating: 0, count: n * (n - 1) / 2)
    for i in 0..<n {
        for j in (i + 1)..<max(i + 1, n) {
            let dx = points[i].0 - points[j].0
            let dy = points[i].1 - points[j].1
            D[cidx(i, j)] = (dx * dx + dy * dy).squareRoot()
        }
    }

    // nn_chain (scipy/cluster/_hierarchy.pyx) with the Ward update
    var Z = [(x: Int, y: Int, d: Double, c: Int)]()
    Z.reserveCapacity(n - 1)
    var size = [Int](repeating: 1, count: n)
    var chain = [Int](repeating: 0, count: n)
    var chainLength = 0
    for _ in 0..<(n - 1) {
        if chainLength == 0 {
            chainLength = 1
            for i in 0..<n where size[i] > 0 {
                chain[0] = i
                break
            }
        }
        var x = 0, y = 0
        var currentMin = Double.infinity
        while true {
            x = chain[chainLength - 1]
            if chainLength > 1 {
                y = chain[chainLength - 2]
                currentMin = D[cidx(x, y)]
            } else {
                currentMin = Double.infinity
            }
            for i in 0..<n {
                if size[i] == 0 || x == i { continue }
                let dist = D[cidx(x, i)]
                if dist < currentMin {
                    currentMin = dist
                    y = i
                }
            }
            if chainLength > 1 && y == chain[chainLength - 2] { break }
            chain[chainLength] = y
            chainLength += 1
        }
        chainLength -= 2
        if x > y { swap(&x, &y) }
        let nx = size[x], ny = size[y]
        Z.append((x, y, currentMin, nx + ny))
        size[x] = 0
        size[y] = nx + ny
        for i in 0..<n {
            let ni = size[i]
            if ni == 0 || i == y { continue }
            let dxi = D[cidx(i, x)], dyi = D[cidx(i, y)]
            let t = 1.0 / Double(nx + ny + ni)
            D[cidx(i, y)] = (Double(ni + nx) * t * dxi * dxi + Double(ni + ny) * t * dyi * dyi
                - Double(ni) * t * currentMin * currentMin).squareRoot()
        }
    }

    // stable sort by distance (mergesort), then relabel with union-find (`label` in scipy)
    let order = Z.indices.sorted { a, b in Z[a].d != Z[b].d ? Z[a].d < Z[b].d : a < b }
    var sortedZ = order.map { Z[$0] }
    var parent = Array(0..<(2 * n - 1))
    var nextLabel = n
    func find(_ v: Int) -> Int {
        var r = v
        while parent[r] != r { r = parent[r] }
        var c = v
        while parent[c] != r {
            let nx = parent[c]
            parent[c] = r
            c = nx
        }
        return r
    }
    for i in 0..<(n - 1) {
        let xr = find(sortedZ[i].x), yr = find(sortedZ[i].y)
        if xr < yr { sortedZ[i].x = xr; sortedZ[i].y = yr } else { sortedZ[i].x = yr; sortedZ[i].y = xr }
        parent[xr] = nextLabel
        parent[yr] = nextLabel
        nextLabel += 1
    }
    let children = sortedZ.map { [$0.x, $0.y] }
    let distances = sortedZ.map { $0.d }

    // n_clusters_ = count(distances >= threshold) + 1, then _hc_cut
    let nClusters = distances.filter { $0 >= distanceThreshold }.count + 1
    return hcCut(nClusters: nClusters, children: children, nLeaves: n)
}

/// sklearn.cluster._agglomerative._hc_cut (uses heapq on negated node ids).
private func hcCut(nClusters: Int, children: [[Int]], nLeaves: Int) -> [Int] {
    var nodes = [-(children[children.count - 1].max()! + 1)]
    for _ in 0..<(nClusters - 1) {
        let these = children[-nodes[0] - nLeaves]
        heapPush(&nodes, -these[0])
        _ = heapPushPop(&nodes, -these[1])
    }
    var label = [Int](repeating: 0, count: nLeaves)
    for (i, node) in nodes.enumerated() {
        // _hc_get_descendent
        var stack = [-node]
        while let v = stack.popLast() {
            if v < nLeaves {
                label[v] = i
            } else {
                stack.append(children[v - nLeaves][0])
                stack.append(children[v - nLeaves][1])
            }
        }
    }
    return label
}

// CPython heapq
private func heapSiftDown(_ heap: inout [Int], _ startpos: Int, _ posIn: Int) {
    var pos = posIn
    let newitem = heap[pos]
    while pos > startpos {
        let parentpos = (pos - 1) >> 1
        let parent = heap[parentpos]
        if newitem < parent {
            heap[pos] = parent
            pos = parentpos
            continue
        }
        break
    }
    heap[pos] = newitem
}

private func heapSiftUp(_ heap: inout [Int], _ posIn: Int) {
    var pos = posIn
    let endpos = heap.count
    let startpos = pos
    let newitem = heap[pos]
    var childpos = 2 * pos + 1
    while childpos < endpos {
        let rightpos = childpos + 1
        if rightpos < endpos && !(heap[childpos] < heap[rightpos]) { childpos = rightpos }
        heap[pos] = heap[childpos]
        pos = childpos
        childpos = 2 * pos + 1
    }
    heap[pos] = newitem
    heapSiftDown(&heap, startpos, pos)
}

private func heapPush(_ heap: inout [Int], _ item: Int) {
    heap.append(item)
    heapSiftDown(&heap, 0, heap.count - 1)
}

private func heapPushPop(_ heap: inout [Int], _ itemIn: Int) -> Int {
    var item = itemIn
    if !heap.isEmpty && heap[0] < item {
        swap(&item, &heap[0])
        heapSiftUp(&heap, 0)
    }
    return item
}

/// Largest number of symbol candidates the clustering steps accept. Ward clustering needs
/// O(n^2) time and memory (as in sklearn); real pages stay below ~400 candidates, while
/// noise or non-music images can produce tens of thousands (gigabytes of distances).
let maxSymbolCandidates = 4000

/// Throws `OMRError.imageTooNoisy` when a stage has more candidates than any real page.
func checkCandidateCount(_ n: Int) throws {
    if n > maxSymbolCandidates { throw OMRError.imageTooNoisy }
}

/// oemer `merge_nearby_bbox`.
func mergeNearbyBBoxes(_ bboxes: [BBox], distance: Double, xFactor: Double = 1, yFactor: Double = 1) -> [BBox] {
    if bboxes.isEmpty { return [] }
    let centers = bboxes.map { bb -> (Double, Double) in
        (Double(bb.x1 + bb.x2) / 2 * xFactor, Double(bb.y1 + bb.y2) / 2 * yFactor)
    }
    let labels = wardClusterLabels(centers, distanceThreshold: distance)
    let uniq = Array(Set(labels)).sorted()
    return uniq.map { label in
        var x1 = Int.max, y1 = Int.max, x2 = Int.min, y2 = Int.min
        for (i, l) in labels.enumerated() where l == label {
            let b = bboxes[i]
            x1 = min(x1, b.x1, b.x2); x2 = max(x2, b.x1, b.x2)
            y1 = min(y1, b.y1, b.y2); y2 = max(y2, b.y1, b.y2)
        }
        return BBox(x1, y1, x2, y2)
    }
}

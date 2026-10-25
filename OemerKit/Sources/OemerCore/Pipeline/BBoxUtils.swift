// Port of oemer/bbox.py helpers.

/// `get_bbox(data)`: bounding boxes of all contours (outer borders and holes), OpenCV order.
func getBBoxes(_ mask: Mask) -> [BBox] {
    findContours(mask).map { $0.bbox }
}

/// `find_lines(data)`: probabilistic Hough segments as (min x, min y, max x, max y).
func findLines(_ mask: Mask, minLength: Double = 10, maxGap: Double = 20) -> [BBox] {
    houghLinesP(mask, rho: 1, theta: Double.pi / 180, threshold: 50, minLineLength: minLength, maxLineGap: maxGap)
        .map { l in BBox(min(l.x1, l.x2), min(l.y1, l.y2), max(l.x1, l.x2), max(l.y1, l.y2)) }
}

/// `rm_merge_overlap_bbox(bboxes, mode, overlap_ratio)`
func rmMergeOverlapBBoxes(_ bboxes: [BBox], merge: Bool = false, overlapRatio: Double = 0.5) -> [BBox] {
    if bboxes.isEmpty { return [] }
    let maxX = bboxes.map { $0.x2 }.max()!
    let maxY = bboxes.map { $0.y2 }.max()!
    if maxX <= 0 || maxY <= 0 { return [] }
    var mask = Grid<UInt16>(width: maxX, height: maxY, repeating: 0)

    struct Info { var bbox: BBox; let area: Int }
    let infos = bboxes.enumerated()
        .map { (i: $0.offset, info: Info(bbox: $0.element, area: ($0.element.y2 - $0.element.y1) * ($0.element.x2 - $0.element.x1))) }
        .sorted { $0.info.area != $1.info.area ? $0.info.area > $1.info.area : $0.i < $1.i }
        .map { $0.info }

    var records: [Int: Info] = [:]
    var recordOrder: [Int] = []
    for (idx, info) in infos.enumerated() {
        let box = info.bbox
        let (rows, cols) = sliceRanges(box, width: maxX, height: maxY)
        var counts: [Int: Int] = [:]
        for y in rows {
            for x in cols { counts[Int(mask[y, x]), default: 0] += 1 }
        }
        var vals = PySet(counts.keys.sorted())
        vals.discard(0)
        let label = UInt16(truncatingIfNeeded: idx + 1)
        if vals.isEmpty {
            records[idx + 1] = info
            recordOrder.append(idx + 1)
            for y in rows { for x in cols { mask[y, x] = label } }
            continue
        }
        let area = Double(info.area)
        var valid = true
        for val in vals.elements {
            let overlap = Double(counts[val] ?? 0)
            if overlap / area > overlapRatio {
                if merge, var tar = records[val] {
                    tar.bbox = BBox(min(box.x1, tar.bbox.x1), min(box.y1, tar.bbox.y1),
                                    max(box.x2, tar.bbox.x2), max(box.y2, tar.bbox.y2))
                    records[val] = tar
                }
                valid = false
                break
            }
        }
        if valid {
            records[idx + 1] = info
            recordOrder.append(idx + 1)
            for y in rows { for x in cols { mask[y, x] = label } }
        }
    }
    return recordOrder.map { records[$0]!.bbox }
}

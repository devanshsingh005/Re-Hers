/// A binary structuring element with OpenCV semantics: rows of the kernel are described
/// by half-open column ranges, and the anchor defaults to (width/2, height/2).
public struct StructuringElement {
    public let width: Int
    public let height: Int
    /// For each kernel row, the half-open range of active columns (empty if `lo >= hi`).
    let rows: [(lo: Int, hi: Int)]
    let anchorX: Int
    let anchorY: Int

    /// `np.ones((rows, cols))` / `cv2.MORPH_RECT`.
    public static func rect(width: Int, height: Int) -> StructuringElement {
        precondition(width > 0 && height > 0)
        return StructuringElement(width: width, height: height,
                                  rows: Array(repeating: (0, width), count: height),
                                  anchorX: width / 2, anchorY: height / 2)
    }

    /// `cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (width, height))`.
    public static func ellipse(width: Int, height: Int) -> StructuringElement {
        precondition(width > 0 && height > 0)
        if width == 1 && height == 1 { return rect(width: 1, height: 1) }
        let r = height / 2
        let c = width / 2
        let invR2 = r != 0 ? 1.0 / (Double(r) * Double(r)) : 0
        var rows: [(Int, Int)] = []
        for i in 0..<height {
            let dy = i - r
            var j1 = 0, j2 = 0
            if abs(dy) <= r {
                // saturate_cast<int>(double) rounds half to even
                let dx = cvRound(Double(c) * (Double(r * r - dy * dy) * invR2).squareRoot())
                j1 = max(c - dx, 0)
                j2 = min(c + dx + 1, width)
            }
            rows.append((j1, j2))
        }
        return StructuringElement(width: width, height: height, rows: rows,
                                  anchorX: width / 2, anchorY: height / 2)
    }
}

private enum MorphOp { case dilate, erode }

/// `cv2.dilate(src, kernel)` for binary images; pixels outside the image are ignored.
public func dilate(_ src: Mask, _ k: StructuringElement) -> Mask {
    morph(src, k, .dilate)
}

/// `cv2.erode(src, kernel)` for binary images; pixels outside the image are ignored.
public func erode(_ src: Mask, _ k: StructuringElement) -> Mask {
    morph(src, k, .erode)
}

/// `cv2.morphologyEx(src, MORPH_OPEN, kernel)`.
public func morphOpen(_ src: Mask, _ k: StructuringElement) -> Mask {
    dilate(erode(src, k), k)
}

/// `cv2.morphologyEx(src, MORPH_CLOSE, kernel)`.
public func morphClose(_ src: Mask, _ k: StructuringElement) -> Mask {
    erode(dilate(src, k), k)
}

/// dst(y, x) = OR/AND over active kernel cells (i, j) of src(y + i - ay, x + j - ax),
/// considering only cells that fall inside the image (OpenCV's default morphology border).
private func morph(_ src: Mask, _ k: StructuringElement, _ op: MorphOp) -> Mask {
    let w = src.width, h = src.height
    var out = Mask(width: w, height: h, repeating: op == .dilate ? 0 : 1)
    if w == 0 || h == 0 { return out }

    // Group consecutive kernel rows that share a column range into vertical blocks.
    var blocks: [(lo: Int, hi: Int, i0: Int, i1: Int)] = []  // i0...i1 inclusive kernel rows
    for (i, r) in k.rows.enumerated() where r.lo < r.hi {
        if let last = blocks.last, last.lo == r.lo, last.hi == r.hi, last.i1 == i - 1 {
            blocks[blocks.count - 1].i1 = i
        } else {
            blocks.append((r.lo, r.hi, i, i))
        }
    }

    var horiz = [UInt8](repeating: 0, count: w * h)
    // Column-wise prefix counts laid out row by row so both passes stream through memory.
    var prefix = [Int32](repeating: 0, count: (h + 1) * w)
    var lastRange: (Int, Int)? = nil

    src.data.withUnsafeBufferPointer { s in
        out.data.withUnsafeMutableBufferPointer { o in
            for b in blocks {
                // Horizontal pass: window offsets [lo, hi] relative to x.
                let lo = b.lo - k.anchorX
                let hi = b.hi - 1 - k.anchorX
                if lastRange == nil || lastRange! != (lo, hi) {
                    horiz.withUnsafeMutableBufferPointer { hb in
                        horizontalPass(s, hb, w, h, lo, hi, op)
                    }
                    prefix.withUnsafeMutableBufferPointer { pc in
                        horiz.withUnsafeBufferPointer { hb in
                            for x in 0..<w { pc[x] = 0 }
                            for y in 0..<h {
                                let prev = y * w, cur = (y + 1) * w
                                for x in 0..<w {
                                    let v = hb[prev + x]
                                    let hit: Int32 = op == .dilate ? (v != 0 ? 1 : 0) : (v == 0 ? 1 : 0)
                                    pc[cur + x] = pc[prev + x] + hit
                                }
                            }
                        }
                    }
                    lastRange = (lo, hi)
                }
                // Vertical pass over kernel rows i0...i1 => src rows y + (i0 - ay) ... y + (i1 - ay).
                let vlo = b.i0 - k.anchorY
                let vhi = b.i1 - k.anchorY
                prefix.withUnsafeBufferPointer { pc in
                    for y in 0..<h {
                        let a = max(0, y + vlo)
                        let z = min(h - 1, y + vhi)
                        if a > z { continue }
                        let top = a * w, bottom = (z + 1) * w, row = y * w
                        if op == .dilate {
                            for x in 0..<w where pc[bottom + x] - pc[top + x] > 0 { o[row + x] = 1 }
                        } else {
                            for x in 0..<w where pc[bottom + x] - pc[top + x] > 0 { o[row + x] = 0 }
                        }
                    }
                }
            }
        }
    }
    return out
}

/// For each pixel: dilate -> 1 if any src pixel in [x+lo, x+hi] (in bounds) is set;
/// erode -> 1 if no src pixel in that window (in bounds) is zero.
private func horizontalPass(_ s: UnsafeBufferPointer<UInt8>, _ hb: UnsafeMutableBufferPointer<UInt8>,
                            _ w: Int, _ h: Int, _ lo: Int, _ hi: Int, _ op: MorphOp)
{
    var prefix = [Int32](repeating: 0, count: w + 1)
    prefix.withUnsafeMutableBufferPointer { p in
        for y in 0..<h {
            let row = y * w
            p[0] = 0
            for x in 0..<w {
                let v = s[row + x]
                let hit: Int32 = op == .dilate ? (v != 0 ? 1 : 0) : (v == 0 ? 1 : 0)
                p[x + 1] = p[x] + hit
            }
            for x in 0..<w {
                let a = max(0, x + lo)
                let z = min(w - 1, x + hi)
                let hits: Int32 = a > z ? 0 : p[z + 1] - p[a]
                if op == .dilate {
                    hb[row + x] = hits > 0 ? 1 : 0
                } else {
                    hb[row + x] = hits > 0 ? 0 : 1
                }
            }
        }
    }
}

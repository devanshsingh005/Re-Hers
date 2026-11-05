import Foundation

// Port of Pillow's libImaging/Resample.c for 8-bit single-channel images with the BICUBIC
// filter, which oemer uses (via Image.resize) to feed symbol crops to the SVM classifiers.

private let precisionBits = 32 - 8 - 2

private func bicubicFilter(_ xIn: Double) -> Double {
    let a = -0.5
    var x = xIn
    if x < 0 { x = -x }
    if x < 1.0 { return ((a + 2.0) * x - (a + 3.0)) * x * x + 1 }
    if x < 2.0 { return (((x - 5) * x + 8) * x - 4) * a }
    return 0
}

/// precompute_coeffs + normalize_coeffs_8bpc
private func precomputeCoeffs(inSize: Int, in0: Float, in1: Float, outSize: Int)
    -> (ksize: Int, bounds: [Int], kk: [Int32])
{
    var scale = Double(in1 - in0) / Double(outSize)
    var filterscale = scale
    if filterscale < 1.0 { filterscale = 1.0 }
    let support = 2.0 * filterscale
    let ksize = Int(ceil(support)) * 2 + 1
    var kkD = [Double](repeating: 0, count: outSize * ksize)
    var bounds = [Int](repeating: 0, count: outSize * 2)
    scale = Double(in1 - in0) / Double(outSize)
    for xx in 0..<outSize {
        let center = Double(in0) + (Double(xx) + 0.5) * scale
        var ww = 0.0
        let ss = 1.0 / filterscale
        var xmin = Int(center - support + 0.5)  // C (int) truncation
        if xmin < 0 { xmin = 0 }
        var xmax = Int(center + support + 0.5)
        if xmax > inSize { xmax = inSize }
        xmax -= xmin
        let base = xx * ksize
        if xmax > 0 {
            for x in 0..<xmax {
                let w = bicubicFilter((Double(x + xmin) - center + 0.5) * ss)
                kkD[base + x] = w
                ww += w
            }
            for x in 0..<xmax where ww != 0.0 { kkD[base + x] /= ww }
        }
        bounds[xx * 2] = xmin
        bounds[xx * 2 + 1] = xmax
    }
    let scaleInt = Double(1 << precisionBits)
    let kk = kkD.map { v -> Int32 in
        v < 0 ? Int32(-0.5 + v * scaleInt) : Int32(0.5 + v * scaleInt)
    }
    return (ksize, bounds, kk)
}

@inline(__always) private func clip8(_ v: Int64) -> UInt8 {
    let s = v >> Int64(precisionBits)
    if s < 0 { return 0 }
    if s > 255 { return 255 }
    return UInt8(s)
}

/// `np.array(Image.fromarray(img).resize((width, height)))` for mode "L" (default BICUBIC).
func pilResizeBicubic(_ img: Grid<UInt8>, width outW: Int, height outH: Int) -> Grid<UInt8> {
    let inW = img.width, inH = img.height
    if inW == outW && inH == outH { return img }
    let needH = outW != inW
    let needV = outH != inH
    let horiz = precomputeCoeffs(inSize: inW, in0: 0, in1: Float(inW), outSize: outW)
    var vert = precomputeCoeffs(inSize: inH, in0: 0, in1: Float(inH), outSize: outH)
    let yboxFirst = vert.bounds[0]
    let yboxLast = vert.bounds[outH * 2 - 2] + vert.bounds[outH * 2 - 1]

    // Pillow >= 10.4: if the height shrinks more than twice as much as the width, the
    // vertical pass runs first (the 8-bit intermediate makes the order matter).
    let horizontalFirst = !((inH - outH) > 0 && (inH - outH) > (inW - outW) * 2)
    if !horizontalFirst {
        var cur = img
        if needV { cur = verticalPass(cur, outH, vert.bounds, vert.kk, vert.ksize) }
        if needH { cur = horizontalPass(cur, outW, horiz.bounds, horiz.kk, horiz.ksize, rowOffset: 0, rows: cur.height) }
        return cur
    }

    var cur = img
    if needH {
        for i in 0..<outH { vert.bounds[i * 2] -= yboxFirst }
        let tmpH = yboxLast - yboxFirst
        var tmp = Grid<UInt8>(width: outW, height: tmpH, repeating: 0)
        for yy in 0..<tmpH {
            for xx in 0..<outW {
                let xmin = horiz.bounds[xx * 2], xmax = horiz.bounds[xx * 2 + 1]
                let k = xx * horiz.ksize
                var ss0: Int64 = 1 << Int64(precisionBits - 1)
                for x in 0..<max(xmax, 0) {
                    ss0 += Int64(img[yy + yboxFirst, x + xmin]) * Int64(horiz.kk[k + x])
                }
                tmp[yy, xx] = clip8(ss0)
            }
        }
        cur = tmp
    }
    if needV {
        var out = Grid<UInt8>(width: cur.width, height: outH, repeating: 0)
        for yy in 0..<outH {
            let ymin = vert.bounds[yy * 2], ymax = vert.bounds[yy * 2 + 1]
            let k = yy * vert.ksize
            for xx in 0..<cur.width {
                var ss0: Int64 = 1 << Int64(precisionBits - 1)
                for y in 0..<max(ymax, 0) {
                    ss0 += Int64(cur[y + ymin, xx]) * Int64(vert.kk[k + y])
                }
                out[yy, xx] = clip8(ss0)
            }
        }
        cur = out
    }
    return cur
}

private func horizontalPass(_ src: Grid<UInt8>, _ outW: Int, _ bounds: [Int], _ kk: [Int32], _ ksize: Int,
                            rowOffset: Int, rows: Int) -> Grid<UInt8>
{
    var out = Grid<UInt8>(width: outW, height: rows, repeating: 0)
    for yy in 0..<rows {
        for xx in 0..<outW {
            let xmin = bounds[xx * 2], xmax = bounds[xx * 2 + 1]
            let k = xx * ksize
            var ss0: Int64 = 1 << Int64(precisionBits - 1)
            for x in 0..<max(xmax, 0) { ss0 += Int64(src[yy + rowOffset, x + xmin]) * Int64(kk[k + x]) }
            out[yy, xx] = clip8(ss0)
        }
    }
    return out
}

private func verticalPass(_ src: Grid<UInt8>, _ outH: Int, _ bounds: [Int], _ kk: [Int32], _ ksize: Int) -> Grid<UInt8> {
    var out = Grid<UInt8>(width: src.width, height: outH, repeating: 0)
    for yy in 0..<outH {
        let ymin = bounds[yy * 2], ymax = bounds[yy * 2 + 1]
        let k = yy * ksize
        for xx in 0..<src.width {
            var ss0: Int64 = 1 << Int64(precisionBits - 1)
            for y in 0..<max(ymax, 0) { ss0 += Int64(src[y + ymin, xx]) * Int64(kk[k + y]) }
            out[yy, xx] = clip8(ss0)
        }
    }
    return out
}

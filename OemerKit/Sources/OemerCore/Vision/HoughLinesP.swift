import Foundation

/// cv::RNG (multiply-with-carry), as used by HoughLinesProbabilistic.
struct CvRNG {
    var state: UInt64

    init(_ seed: UInt64) { state = seed != 0 ? seed : 0xffff_ffff }

    mutating func next() -> UInt32 {
        state = UInt64(UInt32(truncatingIfNeeded: state)) &* 4_164_903_690 &+ (state >> 32)
        return UInt32(truncatingIfNeeded: state)
    }

    /// RNG::uniform(int a, int b)
    mutating func uniform(_ a: Int, _ b: Int) -> Int {
        if a == b { return a }
        return Int(next() % UInt32(truncatingIfNeeded: b - a)) + a
    }
}

/// `cv2.HoughLinesP(img, rho, theta, threshold, None, minLineLength, maxLineGap)` — port of
/// HoughLinesProbabilistic from OpenCV 4.14 (the IPP path is disabled for this function).
/// Returns segments as (x1, y1, x2, y2) in OpenCV's output order.
public func houghLinesP(_ image: Mask, rho rhoD: Double = 1, theta thetaD: Double = Double.pi / 180,
                        threshold: Int = 50, minLineLength: Double = 10, maxLineGap: Double = 20)
    -> [(x1: Int, y1: Int, x2: Int, y2: Int)]
{
    let rho = Float(rhoD)
    let theta = Float(thetaD)
    let lineLength = cvRound(minLineLength)
    let lineGap = cvRound(maxLineGap)
    let irho: Float = 1 / rho
    var rng = CvRNG(UInt64.max)
    let width = image.width
    let height = image.height
    if width == 0 || height == 0 { return [] }

    // computeNumangle(0.0, CV_PI, theta)
    let thetaStep = Double(theta)
    var numangle = Int(floor(Double.pi / thetaStep)) + 1
    if numangle > 1 && abs(Double.pi - Double(numangle - 1) * thetaStep) < thetaStep / 2 {
        numangle -= 1
    }
    let numrho = cvRound(Float((width + height) * 2 + 1) / rho)

    var accum = [Int32](repeating: 0, count: numangle * numrho)
    var mask = [UInt8](repeating: 0, count: width * height)
    var trig = [Float](repeating: 0, count: numangle * 2)
    for n in 0..<numangle {
        trig[n * 2] = Float(cos(Double(n) * Double(theta)) * Double(irho))
        trig[n * 2 + 1] = Float(sin(Double(n) * Double(theta)) * Double(irho))
    }

    var nzloc: [(x: Int, y: Int)] = []
    for y in 0..<height {
        for x in 0..<width {
            if image.data[y * width + x] != 0 {
                mask[y * width + x] = 1
                nzloc.append((x, y))
            }
        }
    }

    var lines: [(x1: Int, y1: Int, x2: Int, y2: Int)] = []
    let shift: Int64 = 16
    let rhoOffset = (numrho - 1) / 2

    var count = nzloc.count
    while count > 0 {
        defer { count -= 1 }
        let idx = rng.uniform(0, count)
        var maxVal = threshold - 1
        var maxN = 0
        let point = nzloc[idx]
        let i = point.y, j = point.x
        nzloc[idx] = nzloc[count - 1]

        if mask[i * width + j] == 0 { continue }

        let fj = Float(j), fi = Float(i)
        for n in 0..<numangle {
            let r = cvRound(fj * trig[n * 2] + fi * trig[n * 2 + 1]) + rhoOffset
            let k = n * numrho + r
            accum[k] += 1
            let val = Int(accum[k])
            if maxVal < val {
                maxVal = val
                maxN = n
            }
        }
        if maxVal < threshold { continue }

        let a = -trig[maxN * 2 + 1]
        let b = trig[maxN * 2]
        var x0 = Int64(j), y0 = Int64(i)
        var dx0: Int64, dy0: Int64
        let xflag: Bool
        if abs(a) > abs(b) {
            xflag = true
            dx0 = a > 0 ? 1 : -1
            dy0 = Int64(cvRound(b * Float(1 << 16) / abs(a)))
            y0 = (y0 << shift) + (1 << (shift - 1))
        } else {
            xflag = false
            dy0 = b > 0 ? 1 : -1
            dx0 = Int64(cvRound(a * Float(1 << 16) / abs(b)))
            x0 = (x0 << shift) + (1 << (shift - 1))
        }

        var lineEnd = [(x: 0, y: 0), (x: 0, y: 0)]
        for k in 0..<2 {
            var gap = 0
            var x = x0, y = y0, dx = dx0, dy = dy0
            if k > 0 { dx = -dx; dy = -dy }
            while true {
                let j1: Int64, i1: Int64
                if xflag { j1 = x; i1 = y >> shift } else { j1 = x >> shift; i1 = y }
                if j1 < 0 || j1 >= Int64(width) || i1 < 0 || i1 >= Int64(height) { break }
                if mask[Int(i1) * width + Int(j1)] != 0 {
                    gap = 0
                    lineEnd[k] = (Int(j1), Int(i1))
                } else {
                    gap += 1
                    if gap > lineGap { break }
                }
                x += dx
                y += dy
            }
        }

        let goodLine = abs(lineEnd[1].x - lineEnd[0].x) >= lineLength
            || abs(lineEnd[1].y - lineEnd[0].y) >= lineLength

        for k in 0..<2 {
            var x = x0, y = y0, dx = dx0, dy = dy0
            if k > 0 { dx = -dx; dy = -dy }
            while true {
                let j1: Int64, i1: Int64
                if xflag { j1 = x; i1 = y >> shift } else { j1 = x >> shift; i1 = y }
                let mi = Int(i1) * width + Int(j1)
                if mask[mi] != 0 {
                    if goodLine {
                        let fj1 = Float(j1), fi1 = Float(i1)
                        for n in 0..<numangle {
                            let r = cvRound(fj1 * trig[n * 2] + fi1 * trig[n * 2 + 1]) + rhoOffset
                            accum[n * numrho + r] -= 1
                        }
                    }
                    mask[mi] = 0
                }
                if Int(i1) == lineEnd[k].y && Int(j1) == lineEnd[k].x { break }
                x += dx
                y += dy
            }
        }

        if goodLine {
            lines.append((lineEnd[0].x, lineEnd[0].y, lineEnd[1].x, lineEnd[1].y))
        }
    }
    return lines
}

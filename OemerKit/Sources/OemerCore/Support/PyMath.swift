import Foundation

// Helpers that reproduce Python / numpy numeric behaviour exactly. The original
// pipeline's thresholds were tuned against these semantics, so the port keeps them.

/// Python `round(x)` / `np.round(x)`: round half to even.
@inline(__always)
public func pyRound(_ x: Double) -> Int {
    Int(x.rounded(.toNearestOrEven))
}

/// OpenCV `cvRound` (lrint in the default rounding mode): also round half to even.
@inline(__always)
func cvRound(_ x: Double) -> Int {
    Int(x.rounded(.toNearestOrEven))
}

@inline(__always)
func cvRound(_ x: Float) -> Int {
    Int(x.rounded(.toNearestOrEven))
}

/// Python floor division for integers.
@inline(__always)
func pyFloorDiv(_ a: Int, _ b: Int) -> Int {
    let q = a / b
    return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q
}

/// Python modulo for integers (result has the sign of the divisor).
@inline(__always)
func pyMod(_ a: Int, _ b: Int) -> Int {
    let r = a % b
    return (r != 0 && ((r < 0) != (b < 0))) ? r + b : r
}

/// numpy's pairwise summation for float64 (`np.add.reduce` on a contiguous array).
func npSum(_ a: [Double]) -> Double {
    if a.isEmpty { return 0 }
    return a.withUnsafeBufferPointer { npPairwiseSum($0.baseAddress!, a.count, 1) }
}

private let pwBlockSize = 128

private func npPairwiseSum(_ a: UnsafePointer<Double>, _ n: Int, _ stride: Int) -> Double {
    if n < 8 {
        var res = 0.0
        // numpy starts from -0.0 for n < 8 and adds in order; sign of zero is irrelevant here.
        for i in 0..<n { res += a[i * stride] }
        return res
    } else if n <= pwBlockSize {
        var r = [Double](repeating: 0, count: 8)
        for k in 0..<8 { r[k] = a[k * stride] }
        var i = 8
        while i < n - (n % 8) {
            r[0] += a[(i + 0) * stride]
            r[1] += a[(i + 1) * stride]
            r[2] += a[(i + 2) * stride]
            r[3] += a[(i + 3) * stride]
            r[4] += a[(i + 4) * stride]
            r[5] += a[(i + 5) * stride]
            r[6] += a[(i + 6) * stride]
            r[7] += a[(i + 7) * stride]
            i += 8
        }
        var res = ((r[0] + r[1]) + (r[2] + r[3])) + ((r[4] + r[5]) + (r[6] + r[7]))
        while i < n {
            res += a[i * stride]
            i += 1
        }
        return res
    } else {
        var n2 = n / 2
        n2 -= n2 % 8
        return npPairwiseSum(a, n2, stride) + npPairwiseSum(a + n2 * stride, n - n2, stride)
    }
}

/// numpy's pairwise summation for float32 arrays (float32 accumulators).
func npSumF(_ a: [Float]) -> Float {
    if a.isEmpty { return 0 }
    return a.withUnsafeBufferPointer { npPairwiseSumF($0.baseAddress!, a.count) }
}

private func npPairwiseSumF(_ a: UnsafePointer<Float>, _ n: Int) -> Float {
    if n < 8 {
        var res: Float = 0
        for i in 0..<n { res += a[i] }
        return res
    } else if n <= 128 {
        var r0 = a[0], r1 = a[1], r2 = a[2], r3 = a[3], r4 = a[4], r5 = a[5], r6 = a[6], r7 = a[7]
        var i = 8
        while i < n - (n % 8) {
            r0 += a[i]; r1 += a[i + 1]; r2 += a[i + 2]; r3 += a[i + 3]
            r4 += a[i + 4]; r5 += a[i + 5]; r6 += a[i + 6]; r7 += a[i + 7]
            i += 8
        }
        var res = ((r0 + r1) + (r2 + r3)) + ((r4 + r5) + (r6 + r7))
        while i < n {
            res += a[i]
            i += 1
        }
        return res
    } else {
        var n2 = n / 2
        n2 -= n2 % 8
        return npPairwiseSumF(a, n2) + npPairwiseSumF(a + n2, n - n2)
    }
}

/// `np.mean` of a float64 array.
func npMean(_ a: [Double]) -> Double {
    npSum(a) / Double(a.count)
}

/// `np.std` (population, ddof=0) of a float64 array.
func npStd(_ a: [Double]) -> Double {
    let m = npMean(a)
    let sq = a.map { ($0 - m) * ($0 - m) }
    return (npSum(sq) / Double(a.count)).squareRoot()
}

/// Mean of a Python list of floats via `np.mean` (pairwise summation).
func npMean<S: Sequence>(_ s: S) -> Double where S.Element == Double {
    npMean(Array(s))
}

/// Simple least-squares slope of y on x (sklearn LinearRegression with one feature).
func olsFit(_ xs: [Double], _ ys: [Double]) -> (slope: Double, intercept: Double) {
    let mx = npMean(xs)
    let my = npMean(ys)
    var sxy = 0.0
    var sxx = 0.0
    for i in 0..<xs.count {
        let dx = xs[i] - mx
        sxy += dx * (ys[i] - my)
        sxx += dx * dx
    }
    let slope = sxx == 0 ? 0 : sxy / sxx
    return (slope, my - slope * mx)
}

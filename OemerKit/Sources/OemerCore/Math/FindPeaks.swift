import Foundation

/// `scipy.signal.find_peaks(x, height=height, distance=distance, prominence=prominence)`,
/// returning peak indices in ascending order.
func findPeaks(_ x: [Double], height: Double, distance: Double, prominence: Double) -> [Int] {
    // _local_maxima_1d
    var peaks: [Int] = []
    var i = 1
    let iMax = x.count - 1
    while i < iMax {
        if x[i - 1] < x[i] {
            var iAhead = i + 1
            while iAhead < iMax && x[iAhead] == x[i] { iAhead += 1 }
            if x[iAhead] < x[i] {
                let left = i
                let right = iAhead - 1
                peaks.append((left + right) / 2)
                i = iAhead
            }
        }
        i += 1
    }

    // height: keep peaks with x[peak] >= height
    peaks = peaks.filter { x[$0] >= height }

    // distance: _select_by_peak_distance (priority = peak heights)
    if !peaks.isEmpty {
        let dist = Int(ceil(distance))
        var keep = [Bool](repeating: true, count: peaks.count)
        // np.argsort(priority). numpy's order for *equal* heights depends on the CPU's SIMD sort
        // (it differs between machines), so ties are broken deterministically here: among equal
        // heights the earlier peak is processed first and kept. On staff-line profiles this keeps
        // the peak nearer the line center (a later twin pulls rows of the next line into this one).
        let order = peaks.indices.sorted { a, b in
            let pa = x[peaks[a]], pb = x[peaks[b]]
            return pa != pb ? pa < pb : a > b
        }
        for oi in stride(from: order.count - 1, through: 0, by: -1) {
            let j = order[oi]
            if !keep[j] { continue }
            var k = j - 1
            while k >= 0 && peaks[j] - peaks[k] < dist {
                keep[k] = false
                k -= 1
            }
            k = j + 1
            while k < peaks.count && peaks[k] - peaks[j] < dist {
                keep[k] = false
                k += 1
            }
        }
        peaks = peaks.indices.filter { keep[$0] }.map { peaks[$0] }
    }

    // prominence: _peak_prominences with wlen = -1
    peaks = peaks.filter { peak in
        var i = peak
        var leftMin = x[peak]
        while i >= 0 && x[i] <= x[peak] {
            if x[i] < leftMin { leftMin = x[i] }
            i -= 1
        }
        i = peak
        var rightMin = x[peak]
        while i <= x.count - 1 && x[i] <= x[peak] {
            if x[i] < rightMin { rightMin = x[i] }
            i += 1
        }
        let prom = x[peak] - max(leftMin, rightMin)
        return prom >= prominence
    }
    return peaks
}

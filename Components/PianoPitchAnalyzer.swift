import Accelerate
import Foundation

// MARK: - PianoPitchAnalyzer
//
// Finds which piano keys are sounding in microphone audio, and when each one is struck.
//
// Every hop (about 21 ms) the newest ~170 ms of audio is windowed and transformed (8192-point
// FFT, ~5.9 Hz per bin, enough to tell low notes apart). The spectrum is whitened (its overall
// tilt flattened, so quiet high partials count) and every one of the 88 keys gets a salience: the
// weighted sum of the spectrum at its harmonics, allowing for the slight sharpening of a real
// piano's upper partials. Several notes sounding at once are found one by one (Klapuri's
// iterative estimation): take the strongest key, remove its harmonics from the spectrum
// (keeping what other notes share of them), and look again. Because a key's salience needs
// energy at its own fundamental series, the overtones of a note are not reported as notes.
//
// A note is struck (an onset) when its salience jumps against what it was ~170 ms earlier, or —
// for a key struck again while it still rings, which the long window cannot see — when a short
// (~43 ms) window shows a sudden attack across the spectrum and at that key's own partials.

nonisolated final class PianoPitchAnalyzer {
    static let lowestMidi = 21
    static let highestMidi = 108
    static let keyCount = highestMidi - lowestMidi + 1

    struct Frame: Sendable {
        let time: Double
        /// RMS level of the newest hop, dBFS.
        let level: Float
        /// Salience of every key (index 0 = A0), from the whole spectrum.
        let salience: [Float]
        let maxSalience: Float
        /// Keys judged to be sounding, strongest first.
        let notes: [Int]
        /// Keys struck in this frame.
        let onsets: Set<Int>
        /// Whether each key's fundamental stands above the noise.
        let fundamental: [Bool]
        /// A sudden rise of energy across the spectrum (something was struck) in this frame.
        let attack: Bool
        /// How much each key's own partials jumped in the short window, beyond the jump the
        /// whole spectrum made.
        let keyFlux: [Float]

        func flux(of midi: Int) -> Float {
            guard (PianoPitchAnalyzer.lowestMidi...PianoPitchAnalyzer.highestMidi).contains(midi) else { return 0 }
            return keyFlux[midi - PianoPitchAnalyzer.lowestMidi]
        }

        func hasFundamental(_ midi: Int) -> Bool {
            guard (PianoPitchAnalyzer.lowestMidi...PianoPitchAnalyzer.highestMidi).contains(midi) else { return false }
            return fundamental[midi - PianoPitchAnalyzer.lowestMidi]
        }

        func salience(of midi: Int) -> Float {
            guard (PianoPitchAnalyzer.lowestMidi...PianoPitchAnalyzer.highestMidi).contains(midi) else { return 0 }
            return salience[midi - PianoPitchAnalyzer.lowestMidi]
        }
    }

    let sampleRate: Double
    let fftSize: Int
    let hopSize: Int

    /// Quietest level (dBFS) treated as playing; below it nothing is reported.
    var gateLevel: Float = -58
    var maxPolyphony = 6

    private let fft: vDSP.FFT<DSPSplitComplex>
    private let window: [Float]
    private var ring: [Float]
    private var ringIndex = 0
    private var pending = 0
    private var samplesSeen = 0
    private var history: [[Float]] = []            // salience of the last frames, newest last
    private var lastOnset = [Double](repeating: -1, count: PianoPitchAnalyzer.keyCount)
    /// Since each key's last onset: its highest salience, and whether it has fallen back since.
    private var peakSinceOnset = [Float](repeating: 0, count: PianoPitchAnalyzer.keyCount)
    private var dippedSinceOnset = [Bool](repeating: true, count: PianoPitchAnalyzer.keyCount)
    private let harmonicBins: [[(low: Int, high: Int, weight: Float)]]

    // short window for attacks
    private let shortSize: Int
    private let shortFFT: vDSP.FFT<DSPSplitComplex>
    private let shortWindow: [Float]
    private var previousShort: [Float] = []
    private var fluxHistory: [Float] = []
    private let shortBins: [[Int]]                 // each key's first partials in the short spectrum

    init(sampleRate: Double, hopSize: Int = 1024) {
        self.sampleRate = sampleRate
        self.hopSize = hopSize
        fftSize = sampleRate > 60_000 ? 16_384 : 8_192
        let log2n = vDSP_Length(log2(Double(fftSize)).rounded())
        fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)!
        window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: fftSize, isHalfWindow: false)
        ring = [Float](repeating: 0, count: fftSize)

        // where each key's harmonics fall, with the weight each one carries
        let binHz = sampleRate / Double(fftSize)
        let maxHz = min(5_200, sampleRate / 2 - binHz * 4)
        var table: [[(Int, Int, Float)]] = []
        for midi in Self.lowestMidi...Self.highestMidi {
            let f0 = 440 * pow(2, Double(midi - 69) / 12)
            // piano strings are stiff: partial h sits at h·f0·√(1 + B·h²); B grows up the keyboard
            let b = 0.00008 * pow(2, Double(midi - 21) / 18)
            var bins: [(Int, Int, Float)] = []
            var h = 1
            let count = min(20, max(6, Int(1_600 / f0)))
            while h <= count {
                let fh = Double(h) * f0 * (1 + b * Double(h * h)).squareRoot()
                if fh > maxHz { break }
                // about ±10 cents (the stiffness model takes care of the rest), never under a bin
                let tolerance = fh * 0.006 + binHz * 0.75
                let low = max(1, Int(((fh - tolerance) / binHz).rounded(.down)))
                let high = min(fftSize / 2 - 2, Int(((fh + tolerance) / binHz).rounded(.up)))
                // gently falling weights: a key's own series must outweigh a single overtone of it
                let weight = Float(pow(Double(h), -0.35))
                bins.append((low, max(low, high), weight))
                h += 1
            }
            table.append(bins)
        }
        harmonicBins = table

        shortSize = fftSize / 4
        shortFFT = vDSP.FFT(log2n: vDSP_Length(log2(Double(shortSize)).rounded()), radix: .radix2, ofType: DSPSplitComplex.self)!
        shortWindow = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: shortSize, isHalfWindow: false)
        let shortHz = sampleRate / Double(shortSize)
        shortBins = (Self.lowestMidi...Self.highestMidi).map { midi in
            let f0 = 440 * pow(2, Double(midi - 69) / 12)
            return (1...6).compactMap { h in
                let k = Int((Double(h) * f0 / shortHz).rounded())
                return k >= 2 && k < Int(5_200 / shortHz) ? k : nil
            }
        }
    }

    /// Feeds samples (mono). Returns a frame for every completed hop.
    func process(_ samples: UnsafeBufferPointer<Float>, at startTime: Double) -> [Frame] {
        var frames: [Frame] = []
        for (i, sample) in samples.enumerated() {
            ring[ringIndex] = sample
            ringIndex = (ringIndex + 1) % fftSize
            pending += 1
            samplesSeen += 1
            if pending >= hopSize {
                pending = 0
                let time = startTime + Double(i + 1) / sampleRate
                frames.append(analyze(at: time))
            }
        }
        return frames
    }

    func process(_ samples: [Float], at startTime: Double) -> [Frame] {
        samples.withUnsafeBufferPointer { process($0, at: startTime) }
    }

    func reset() {
        ring = [Float](repeating: 0, count: fftSize)
        ringIndex = 0
        pending = 0
        samplesSeen = 0
        history.removeAll()
        lastOnset = [Double](repeating: -1, count: Self.keyCount)
        peakSinceOnset = [Float](repeating: 0, count: Self.keyCount)
        dippedSinceOnset = [Bool](repeating: true, count: Self.keyCount)
        previousShort = []
        fluxHistory = []
    }

    // MARK: Analysis

    private func analyze(at time: Double) -> Frame {
        // the newest hop's level
        var sumSquares: Float = 0
        for k in 0..<hopSize {
            let v = ring[(ringIndex - 1 - k + fftSize) % fftSize]
            sumSquares += v * v
        }
        let level = 10 * log10(max(sumSquares / Float(hopSize), 1e-12))

        let (attack, keyFlux) = shortWindowAttack()
        let spectrum = whitenedSpectrum()
        let floor = noise(of: spectrum)
        let salience = (0..<Self.keyCount).map { saliency(of: $0, in: spectrum, noise: floor) }
        let maxSalience = salience.max() ?? 0
        let audible = level > gateLevel && samplesSeen >= fftSize / 2
        let notes = audible ? estimateNotes(spectrum: spectrum, noise: floor) : []

        // a key counts as struck again only once its sound has fallen back from its last peak
        for index in 0..<Self.keyCount {
            peakSinceOnset[index] = max(peakSinceOnset[index], salience[index])
            if salience[index] < peakSinceOnset[index] * 0.82 { dippedSinceOnset[index] = true }
        }
        // onsets: a sounding key whose salience jumped against ~170 ms ago
        var onsets = Set<Int>()
        if audible, history.count >= 3 {
            let lookBack = history.count >= 8 ? history[history.count - 8] : history[0]
            let previous = history[history.count - 1]
            let strongestFlux = keyFlux.max() ?? 0
            for index in notes {
                let now = salience[index]
                let before = lookBack[index]
                let rising = now >= previous[index] * 0.98
                let rearmed = dippedSinceOnset[index] || time - lastOnset[index] > 0.6
                let jumped = now > before * 1.45 + maxSalience * 0.04 && rising && rearmed
                // struck again while still ringing: a fresh attack at this key's own partials
                let restruck = attack && strongestFlux > 0 && keyFlux[index] >= strongestFlux * 0.35
                // one strike, one onset: the long window keeps rising for ~0.2 s after an attack,
                // so its own test waits longer than a fresh attack does
                let since = time - lastOnset[index]
                if (jumped && since > 0.3) || (restruck && since > 0.15) {
                    onsets.insert(index + Self.lowestMidi)
                    lastOnset[index] = time
                    peakSinceOnset[index] = now
                    dippedSinceOnset[index] = false
                }
            }
        }
        history.append(salience)
        if history.count > 10 { history.removeFirst(history.count - 10) }

        let fundamental = (0..<Self.keyCount).map { partial($0, 1, in: spectrum, noise: floor) > floor * 2 }
        return Frame(time: time, level: level, salience: salience, maxSalience: maxSalience,
                     notes: notes.map { $0 + Self.lowestMidi }, onsets: onsets, fundamental: fundamental,
                     attack: attack, keyFlux: keyFlux)
    }

    /// The newest ~43 ms: whether energy rose suddenly across the spectrum, and how much at each
    /// key's partials (log magnitudes, against the previous hop).
    private func shortWindowAttack() -> (Bool, [Float]) {
        let n = shortSize, half = n / 2
        var frame = [Float](repeating: 0, count: n)
        for k in 0..<n { frame[k] = ring[(ringIndex - n + k + fftSize) % fftSize] }
        vDSP.multiply(frame, shortWindow, result: &frame)
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                frame.withUnsafeBufferPointer { samples in
                    samples.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                shortFFT.forward(input: split, output: &split)
                vDSP.absolute(split, result: &magnitudes)
            }
        }
        let compressed = magnitudes.map { log(1 + 200 * $0) }
        defer { previousShort = compressed }
        guard previousShort.count == compressed.count else { return (false, [Float](repeating: 0, count: Self.keyCount)) }
        let binHz = Float(sampleRate) / Float(n)
        let lo = max(1, Int(50 / binHz)), hi = min(half - 1, Int(5_200 / binHz))
        var flux: Float = 0
        var rise = [Float](repeating: 0, count: half)
        for k in lo...hi {
            rise[k] = max(0, compressed[k] - previousShort[k])
            flux += rise[k]
        }
        flux /= Float(hi - lo + 1)
        let sorted = fluxHistory.sorted()
        let typical = sorted.isEmpty ? flux : sorted[sorted.count / 2]
        fluxHistory.append(flux)
        if fluxHistory.count > 24 { fluxHistory.removeFirst(fluxHistory.count - 24) }
        let attack = flux > typical * 2.5 + 0.015
        // a key struck again lifts all of its lower partials; another key that merely shares one
        // of them lifts only that one, so take the median of the first four
        let keyFlux = shortBins.map { bins -> Float in
            let rises = bins.prefix(4).map { k in max(rise[k - 1], rise[k], rise[min(half - 1, k + 1)]) }.sorted()
            guard !rises.isEmpty else { return 0 }
            return rises.count >= 3 ? rises[rises.count / 2] : rises[0]
        }
        // a hammer strike lifts the whole spectrum a little: count only what rose beyond that
        let baseline = keyFlux.sorted()[keyFlux.count / 2]
        return (attack, keyFlux.map { max(0, $0 - baseline) })
    }

    /// Magnitude spectrum of the windowed frame, its tilt flattened (spectral whitening).
    private func whitenedSpectrum() -> [Float] {
        let n = fftSize
        var frame = [Float](repeating: 0, count: n)
        for k in 0..<n { frame[k] = ring[(ringIndex + k) % n] }
        vDSP.multiply(frame, window, result: &frame)

        let half = n / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var magnitudes = [Float](repeating: 0, count: half)
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                frame.withUnsafeBufferPointer { samples in
                    samples.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                fft.forward(input: split, output: &split)
                vDSP.absolute(split, result: &magnitudes)
            }
        }
        magnitudes[0] = 0

        // spectral envelope: average over a band about a third of an octave wide
        var cumulative = [Float](repeating: 0, count: half + 1)
        for k in 0..<half { cumulative[k + 1] = cumulative[k] + magnitudes[k] }
        let binHz = Float(sampleRate) / Float(n)
        var white = [Float](repeating: 0, count: half)
        let floor = (magnitudes.max() ?? 1) * 1e-4 + 1e-9
        for k in 1..<half {
            let width = max(3, Int((Float(k) * 0.12 + 40 / binHz).rounded()))
            let lo = max(1, k - width), hi = min(half, k + width + 1)
            let envelope = (cumulative[hi] - cumulative[lo]) / Float(hi - lo) + floor
            white[k] = magnitudes[k] * pow(envelope, -0.67)
        }
        return white
    }

    /// Weighted sum of a key's partials, each counted above the noise only, scaled by how
    /// many of its first eight partials are really there: a phantom note under a chord (an
    /// octave or a twelfth below a real one) only lines up with some of them.
    private func saliency(of index: Int, in spectrum: [Float], noise: Float) -> Float {
        var total: Float = 0
        let cut = noise * 2.5
        let bins = harmonicBins[index]
        let checked = min(8, bins.count)
        var present = 0
        for (h, bin) in bins.enumerated() {
            var peak: Float = 0
            for k in bin.low...bin.high where spectrum[k] > peak { peak = spectrum[k] }
            if peak > cut { total += bin.weight * (peak - cut) }
            if h < checked && peak > noise * 5 { present += 1 }
        }
        let coverage = Float(present) / Float(checked)
        return total * coverage * coverage
    }

    /// Several notes at once: take the strongest key, remove its harmonics, repeat.
    private func estimateNotes(spectrum: [Float], noise: Float) -> [Int] {
        var residual = spectrum
        var found: [Int] = []
        var first: Float = 0
        // a key must stand clear of what noise alone would give it
        let minimum = noise * 6
        while found.count < maxPolyphony {
            var best = -1
            var bestValue: Float = 0
            for index in 0..<Self.keyCount where !found.contains(index) {
                let value = saliency(of: index, in: residual, noise: noise)
                if value > bestValue { bestValue = value; best = index }
            }
            guard best >= 0, bestValue > minimum else { break }
            let corrected = correctOctave(best, in: residual, noise: noise)
            if corrected != best, !found.contains(corrected) {
                best = corrected
                bestValue = saliency(of: best, in: residual, noise: noise)
            }
            if found.isEmpty {
                first = bestValue
            } else if bestValue < first * 0.22 {
                break
            }
            // a high key needs its own fundamental; leftovers of other notes' partials have none
            if PianoPitchAnalyzer.frequency(of: best + Self.lowestMidi) > 1_000,
               partial(best, 1, in: residual, noise: noise) < noise * 10 {
                removeHarmonics(of: best, from: &residual)
                continue
            }
            // an octave (or two) below a note already found needs its own fundamental
            if found.contains(where: { $0 - best == 12 || $0 - best == 24 }),
               PianoPitchAnalyzer.frequency(of: best + Self.lowestMidi) > 80,
               partial(best, 1, in: residual, noise: noise) < noise * 8 {
                removeHarmonics(of: best, from: &residual)
                continue
            }
            // a key that is only an overtone of one already found is not a new note
            if found.contains(where: { isOvertone(best, of: $0) }) && bestValue < first * 0.7 {
                removeHarmonics(of: best, from: &residual)
                continue
            }
            found.append(best)
            removeHarmonics(of: best, from: &residual)
        }
        return found
    }

    /// The spectrum's typical level between 60 Hz and 2 kHz.
    private func noise(of spectrum: [Float]) -> Float {
        let binHz = sampleRate / Double(fftSize)
        let lo = Int(60 / binHz), hi = min(spectrum.count - 1, Int(2_000 / binHz))
        var band = Array(spectrum[lo...hi])
        band.sort()
        return band[band.count / 2]
    }

    /// The partial of a key nearest harmonic `h`, above the noise.
    private func partial(_ index: Int, _ h: Int, in spectrum: [Float], noise: Float) -> Float {
        let bins = harmonicBins[index]
        guard h >= 1, h <= bins.count else { return 0 }
        let bin = bins[h - 1]
        var peak: Float = 0
        for k in bin.low...bin.high where spectrum[k] > peak { peak = spectrum[k] }
        return max(0, peak - noise * 2)
    }

    /// Octave errors: a note an octave lower shares every even partial with this one, so it is
    /// the real note when its own odd partials are there too; and a key whose odd partials are
    /// missing is really the one an octave higher.
    private func correctOctave(_ index: Int, in spectrum: [Float], noise: Float) -> Int {
        var index = index
        func ratio(_ i: Int) -> Float {
            var odd: Float = 0, even: Float = 0
            for h in [1, 3, 5, 7] { odd += partial(i, h, in: spectrum, noise: noise) }
            for h in [2, 4, 6, 8] { even += partial(i, h, in: spectrum, noise: noise) }
            return even > 0 ? odd / even : (odd > 0 ? 10 : 0)
        }
        // down: is this key the overtone of one an octave below?
        while index - 12 >= 0 {
            let lower = index - 12
            let odd = [1, 3, 5].map { partial(lower, $0, in: spectrum, noise: noise) }
            let even = [2, 4, 6].map { partial(lower, $0, in: spectrum, noise: noise) }
            let oddSum = odd.reduce(0, +), evenSum = even.reduce(0, +)
            // the lower note needs real odd partials (two of them, or a clear third)
            let present = odd.filter { $0 > evenSum / 3 * 0.35 }.count
            guard evenSum > 0, oddSum >= evenSum * 0.4, present >= 2 else { break }
            // above E2 a piano note's fundamental is there; without it the lower key is a phantom
            if PianoPitchAnalyzer.frequency(of: lower + Self.lowestMidi) > 80, odd[0] < evenSum / 3 * 0.25 { break }
            index = lower
        }
        // up: a key with no odd partials of its own is the octave above
        while index + 12 < Self.keyCount, ratio(index) < 0.18, partial(index + 12, 1, in: spectrum, noise: noise) > 0 {
            index += 12
        }
        return index
    }

    private func isOvertone(_ index: Int, of base: Int) -> Bool {
        let interval = index - base
        return [12, 19, 24, 28, 31, 34, 36].contains(interval)
    }

    /// Removes a key's partials from the spectrum, keeping what other notes may share of them
    /// (each partial is cut to the smooth level of its neighbours).
    private func removeHarmonics(of index: Int, from residual: inout [Float]) {
        let bins = harmonicBins[index]
        var peaks: [(k: Int, value: Float)] = []
        for bin in bins {
            var best = bin.low
            for k in bin.low...bin.high where residual[k] > residual[best] { best = k }
            peaks.append((best, residual[best]))
        }
        for (h, peak) in peaks.enumerated() {
            let neighbours = [h - 1, h, h + 1].filter { $0 >= 0 && $0 < peaks.count }.map { peaks[$0].value }
            let smooth = min(peak.value, neighbours.reduce(0, +) / Float(neighbours.count))
            let cut = h == 0 ? peak.value : max(smooth, peak.value * 0.85)
            for k in max(1, peak.k - 3)...min(residual.count - 1, peak.k + 3) {
                let shape: Float = 1 - Float(abs(k - peak.k)) / 4
                residual[k] = max(0, residual[k] - cut * shape)
            }
        }
    }

    // MARK: Names

    static func name(of midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return "\(names[((midi % 12) + 12) % 12])\(midi / 12 - 1)"
    }

    static func frequency(of midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }
}

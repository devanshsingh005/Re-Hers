import Foundation

// MARK: - PlayAlongSession
//
// The rules of Play Along, apart from the screen. The score becomes a list of steps (the notes
// struck together at one moment); the session waits on each step until every note of it has
// been played — on a keyboard connected by USB (MIDI), on the piano (heard through the
// microphone) or on the screen keyboard — then moves on.
//
// Listening knows what it is waiting for: a note counts as played when the analyzer heard it
// struck, or when its salience is strong and has just risen (so a note doubled an octave above
// another, which is hard to pick out blind, is still recognised). A note that was not asked for
// counts as a mistake only when it is clearly struck, is not an overtone or undertone of a note
// that is sounding, and is not the previous step still ringing.
//
// Tempo is measured the way it is written: the beats the player covered over the last few steps
// (from the score) over the seconds they took, against the score's own tempo there. Spanning
// several steps evens out the small delay before each note is recognised; a long pause or a
// skip starts a new stretch.

nonisolated final class PlayAlongSession {
    enum Hands: Equatable, Sendable {
        case both, right, left
        var next: Hands { self == .both ? .right : (self == .right ? .left : .both) }
        var label: String { self == .both ? "L+R" : (self == .right ? "R" : "L") }
    }

    struct Step: Sendable {
        let tick: Int
        let measure: Int
        let left: [Int]
        let right: [Int]
        /// Each key as the score spells it ("Ab3", not "G#3").
        let names: [Int: String]
    }

    enum Event: Equatable, Sendable {
        case hit(midi: Int)
        case wrong(midi: Int)
        case advanced(to: Int)
        case finished
    }

    struct Result: Sendable {
        let correct: Int
        let mistakes: Int
        let steps: Int
        let cleanSteps: Int
        let skipped: Int
        /// The player's typical tempo and the score's, in quarter notes per minute.
        let playedBPM: Double?
        let targetBPM: Double
        let seconds: Double

        var accuracy: Int {
            correct + mistakes == 0 ? 100 : Int((Double(correct) / Double(correct + mistakes) * 100).rounded())
        }
    }

    let steps: [Step]
    private let timeline: ScoreTimeline

    private(set) var index = 0
    private(set) var hands: Hands = .both
    private(set) var hit = Set<Int>()
    private(set) var isFinished = false

    private var correct = 0
    private var mistakes = 0
    private var cleanSteps = 0
    private var skipped = 0
    private var stepHadMistake = false
    private var firstHitTime: Double?
    /// Whether the step's strike was timed precisely — by the attack that started it, or a
    /// screen-keyboard press. Only those time the tempo: a note is recognised a varying moment
    /// after it is struck.
    private var firstHitIsPrecise = false
    /// Recent attacks (strikes heard), and when the last completed step was struck.
    private var attacks: [Double] = []
    private var previousStrike: Double = -1
    private var startedAt: Double?
    private var lastCompletion: (index: Int, time: Double)?
    /// The current unbroken stretch of steps played: (tick, when its first note was heard).
    private var stretch: [(tick: Int, time: Double)] = []
    /// Beats and seconds over every stretch, for the session's average.
    private var totalBeats = 0.0
    private var totalSeconds = 0.0
    private(set) var tempoSamples: [Double] = []
    private var lastWrong: [Int: Double] = [:]
    private var lastTouch: [Int: Double] = [:]
    private var ringing: [(midi: Int, until: Double)] = []
    /// The notes of the step just finished: the same key in this step must be struck again.
    private var justPlayed: (notes: Set<Int>, struck: Double, completed: Double) = ([], -1, -1)
    private var lastAttack: Double = -1
    /// Each key's lowest salience since the last attack (the dip an attack leaves).
    private var lowSinceAttack: [Float] = []
    private var history: [[Float]] = []           // salience of every key over the last frames

    init(timeline: ScoreTimeline) {
        self.timeline = timeline
        var byTick: [Int: (measure: Int, left: Set<Int>, right: Set<Int>, names: [Int: String])] = [:]
        for note in timeline.notes where note.isStruck {
            guard let midi = note.midi else { continue }
            var step = byTick[note.startTick] ?? (note.measureIndex, [], [], [:])
            if note.isLeftHand { step.left.insert(midi) } else { step.right.insert(midi) }
            step.names[midi] = note.writtenName
            byTick[note.startTick] = step
        }
        steps = byTick.keys.sorted().map { tick in
            let step = byTick[tick]!
            // a key both hands play at once is played once
            return Step(tick: tick, measure: step.measure, left: step.left.sorted(),
                        right: step.right.subtracting(step.left).sorted(), names: step.names)
        }
    }

    // MARK: State

    var current: Step? { index < steps.count ? steps[index] : nil }

    /// The notes of the current step the player has to play, with the chosen hands.
    var expected: Set<Int> {
        guard let step = current else { return [] }
        switch hands {
        case .both:  return Set(step.left + step.right)
        case .right: return Set(step.right)
        case .left:  return Set(step.left)
        }
    }

    var remaining: Set<Int> { expected.subtracting(hit) }
    var progress: Double { steps.isEmpty ? 1 : Double(index) / Double(steps.count) }

    /// The score's tempo where the player is (quarter notes per minute).
    var targetBPM: Double {
        timeline.writtenTime.bpm(atTick: Double(current?.tick ?? steps.last?.tick ?? 0))
    }

    /// The player's tempo over the last few steps.
    var playedBPM: Double? { tempoSamples.last }

    var result: Result {
        let target = steps.isEmpty ? 0 : steps.reduce(0.0) { $0 + timeline.writtenTime.bpm(atTick: Double($1.tick)) } / Double(steps.count)
        return Result(correct: correct, mistakes: mistakes, steps: steps.count, cleanSteps: cleanSteps,
                      skipped: skipped, playedBPM: totalSeconds > 0 ? totalBeats / totalSeconds * 60 : nil,
                      targetBPM: target, seconds: max(0, (lastCompletion?.time ?? 0) - (startedAt ?? 0)))
    }

    // MARK: Control

    /// Starts over from `step` (0 = the beginning).
    func restart(at step: Int = 0) {
        index = min(max(0, step), steps.count)
        hit = []
        isFinished = steps.isEmpty
        correct = 0; mistakes = 0; cleanSteps = 0; skipped = 0
        stepHadMistake = false
        firstHitTime = nil
        startedAt = nil
        lastCompletion = nil
        stretch = []
        totalBeats = 0
        totalSeconds = 0
        tempoSamples = []
        lastWrong = [:]
        ringing = []
        history = []
        justPlayed = ([], -1, -1)
        lastAttack = -1
        lowSinceAttack = []
        attacks = []
        previousStrike = -1
        skipEmptySteps()
    }

    /// Practise with both hands, or one (the other hand's notes are not waited for).
    @discardableResult
    func setHands(_ hands: Hands) -> [Event] {
        self.hands = hands
        hit = hit.intersection(expected)
        var events: [Event] = []
        let before = index
        skipEmptySteps()
        if index != before { events.append(index >= steps.count ? .finished : .advanced(to: index)) }
        return events
    }

    /// Moves on without the missing notes.
    func skip(at time: Double) -> [Event] {
        guard current != nil else { return [] }
        skipped += 1
        lastCompletion = nil
        stretch = []           // no tempo across a skip
        return advance(at: time, countClean: false)
    }

    // MARK: Input

    /// A key pressed on the screen keyboard.
    func touch(_ midi: Int, at time: Double) -> [Event] {
        lastTouch[midi] = time
        return play(midi, at: time, struck: time, precise: true)
    }

    /// A key pressed on a connected MIDI keyboard: exact, so it is timed and judged as played.
    func key(_ midi: Int, at time: Double) -> [Event] {
        play(midi, at: time, struck: time, precise: true)
    }

    /// One frame from the microphone.
    func listen(_ frame: PianoPitchAnalyzer.Frame) -> [Event] {
        ringing.removeAll { $0.until < frame.time }
        let wanted = remaining
        // kept across steps: a key still ringing from the last step has not "just risen"
        let before = history.count >= 8 ? history[history.count - 8] : history.first
        history.append(frame.salience)
        if history.count > 10 { history.removeFirst(history.count - 10) }
        guard current != nil, frame.level > -58 else { return [] }
        if frame.attack {
            lastAttack = frame.time
            attacks.append(frame.time)
            attacks.removeAll { frame.time - $0 > 3 }
            lowSinceAttack = frame.salience
        } else if lowSinceAttack.count == frame.salience.count {
            for i in lowSinceAttack.indices { lowSinceAttack[i] = min(lowSinceAttack[i], frame.salience[i]) }
        }

        var events: [Event] = []
        // the notes asked for: struck, or strong and just risen
        for midi in wanted.sorted() {
            // the screen keyboard's own sound coming back through the microphone
            if let touched = lastTouch[midi], frame.time - touched < 0.5 { continue }
            let now = frame.salience(of: midi)
            let earlier = before.map { $0[midi - PianoPitchAnalyzer.lowestMidi] } ?? 0
            let rose = now > earlier * 1.4 + frame.maxSalience * 0.05
            // struck; or strong and just risen; or (a note partly hidden under others, such as
            // one an octave or more above another) just risen with its own fundamental present
            let repeated = justPlayed.notes.contains(midi)
            // struck again: an onset, or a fresh attack at its own partials (inside a chord)
            let restruck = frame.onsets.contains(midi)
                || (frame.attack && frame.flux(of: midi) >= (frame.keyFlux.max() ?? 0) * 0.35
                    && now >= frame.maxSalience * 0.15)
            // or, after a fresh attack, rising clearly out of the dip the attack left (a note
            // doubled an octave above another, struck again with it)
            // the same key again needs a new attack after the previous step's own strike (a late
            // confirmation of that strike is not a new one)
            let newAttack = lastAttack > justPlayed.struck + 0.1 && frame.time - lastAttack < 0.4
            let low = lowSinceAttack.isEmpty ? now : lowSinceAttack[midi - PianoPitchAnalyzer.lowestMidi]
            let climbed = now > low * 1.6 + frame.maxSalience * 0.05
            let heard = repeated
                ? frame.time - justPlayed.completed > 0.05 && newAttack
                    && (restruck || (climbed && now >= frame.maxSalience * 0.3))
                : frame.onsets.contains(midi)
                    || (rose && now >= frame.maxSalience * 0.4)
                    || (rose && now >= frame.maxSalience * 0.2 && frame.hasFundamental(midi))
            if heard {
                // the strike: the latest attack before this, after the previous step's strike
                let strike = attacks.last { $0 <= frame.time && $0 > previousStrike + 0.08 && frame.time - $0 < 0.45 }
                let produced = play(midi, at: frame.time, struck: strike ?? frame.time, precise: strike != nil)
                events += produced
                // the step is done: the rest of this frame belongs to it, not to the next one
                if produced.contains(where: { $0 == .finished || { if case .advanced = $0 { return true }; return false }($0) }) {
                    return events
                }
            }
        }
        // anything else clearly struck is a wrong note
        let explained = expected.union(hit).union(ringing.map(\.midi))
        for midi in frame.onsets.sorted() where !expected.contains(midi) {
            if let touched = lastTouch[midi], frame.time - touched < 0.5 { continue }
            if explained.contains(where: { Self.related(midi, $0) }) { continue }
            guard frame.salience(of: midi) >= frame.maxSalience * 0.5 else { continue }
            if let last = lastWrong[midi], frame.time - last < 0.35 { continue }
            lastWrong[midi] = frame.time
            mistakes += 1
            stepHadMistake = true
            events.append(.wrong(midi: midi))
        }
        return events
    }

    /// The same key again, an octave or two apart, or an overtone/undertone of it.
    private static func related(_ a: Int, _ b: Int) -> Bool {
        let d = abs(a - b)
        return d == 0 || [12, 19, 24, 28, 31, 36].contains(d)
    }

    private func play(_ midi: Int, at time: Double, struck: Double, precise: Bool) -> [Event] {
        guard current != nil, !isFinished else { return [] }
        if startedAt == nil { startedAt = time }
        guard expected.contains(midi) else {
            if let last = lastWrong[midi], time - last < 0.35 { return [] }
            lastWrong[midi] = time
            mistakes += 1
            stepHadMistake = true
            return [.wrong(midi: midi)]
        }
        guard !hit.contains(midi) else { return [] }
        hit.insert(midi)
        correct += 1
        if firstHitTime == nil {
            firstHitTime = struck
            firstHitIsPrecise = precise
        }
        var events: [Event] = [.hit(midi: midi)]
        if remaining.isEmpty {
            events += advance(at: time, countClean: true)
        }
        return events
    }

    private func advance(at time: Double, countClean: Bool) -> [Event] {
        guard let step = current else { return [] }
        if countClean && !stepHadMistake { cleanSteps += 1 }
        // tempo: beats written over the last few steps against the seconds they took
        let struck = firstHitTime ?? time
        if countClean && firstHitIsPrecise {
            if let last = stretch.last {
                let beats = Double(step.tick - last.tick) / Double(timeline.ticksPerQuarter)
                let seconds = struck - last.time
                if beats <= 0 || seconds > 4 * max(1, beats) || seconds < 0.03 {
                    stretch = []                  // a pause: start a new stretch
                } else {
                    totalBeats += beats
                    totalSeconds += seconds
                }
            }
            stretch.append((step.tick, struck))
            if stretch.count > 6 { stretch.removeFirst(stretch.count - 6) }
            if stretch.count >= 3, let first = stretch.first, let last = stretch.last, last.time > first.time {
                let beats = Double(last.tick - first.tick) / Double(timeline.ticksPerQuarter)
                tempoSamples.append(min(400, beats / (last.time - first.time) * 60))
            }
        }
        if countClean { lastCompletion = (index, struck) }
        previousStrike = struck
        for midi in expected { ringing.append((midi, time + 0.6)) }
        // struck and completed: a fast player's next strike can come before the slower notes of
        // a chord have all been confirmed
        justPlayed = (expected, struck, time)

        index += 1
        hit = []
        stepHadMistake = false
        firstHitTime = nil
        firstHitIsPrecise = false
        skipEmptySteps()
        if index >= steps.count {
            isFinished = true
            return [.finished]
        }
        return [.advanced(to: index)]
    }

    /// Steps with nothing for the chosen hands are passed over.
    private func skipEmptySteps() {
        while index < steps.count && expected.isEmpty { index += 1 }
        if index >= steps.count { isFinished = true }
    }
}

import UIKit

// MARK: - Hand fingering
//
// The ghost hands play a song the way a pianist would. Before playback each hand's notes are
// fingered for the whole piece: the hand keeps a five-finger position (a finger over each of
// five neighbouring white keys) while the notes stay in reach, so a run is played by one finger
// after another instead of one finger hopping from key to key. It moves to a new position only
// when the music needs one — chosen over the whole piece at once (least stretching and moving
// overall) — and it moves early, in the gap before the notes that need it. Chords are spread
// over several fingers in order, a finger still holding a note is left on it, and the thumb
// stays off black keys where it can.

/// A note one hand plays, in seconds of the performance at 1× tempo.
nonisolated struct HandNote: Sendable {
    let midi: Int
    let isLeft: Bool
    let start: Double
    let release: Double
}

nonisolated struct HandPlan: Sendable {
    struct Press: Sendable {
        let finger: Int          // 0…4 left to right on the keyboard
        let key: Double          // key centre, in white-key widths from A0's left edge
        let isBlack: Bool
        let start: Double
        let release: Double
        let approach: Double     // seconds the finger takes to get over its key
    }
    struct Move: Sendable {
        let start: Double
        let end: Double
        let from: Double
        let to: Double
    }
    struct Span: Sendable { let start: Double; let end: Double }

    let isLeft: Bool
    /// Position: the white key under the leftmost finger (finger f rests over key p + f).
    let initial: Double
    let moves: [Move]            // by start
    let presses: [[Press]]       // per finger, by start
    let active: [Span]           // when the hand is playing, by start

    var isEmpty: Bool { active.isEmpty }
    /// The thumb is the finger nearest the middle of the keyboard.
    var thumb: Int { isLeft ? 4 : 0 }

    func position(at t: Double) -> Double {
        var lo = 0, hi = moves.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if moves[mid].start <= t { lo = mid + 1 } else { hi = mid }
        }
        guard lo > 0 else { return initial }
        let move = moves[lo - 1]
        guard t < move.end, move.end > move.start else { return move.to }
        return move.from + (move.to - move.from) * HandFingering.ease((t - move.start) / (move.end - move.start))
    }

    /// Seconds from `t` to the nearest moment the hand plays (0 while it plays).
    func idle(at t: Double) -> Double {
        var best = Double.infinity
        var lo = 0, hi = active.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if active[mid].start <= t { lo = mid + 1 } else { hi = mid }
        }
        for i in [lo - 1, lo] where i >= 0 && i < active.count {
            let span = active[i]
            if t >= span.start && t <= span.end { return 0 }
            best = min(best, t < span.start ? span.start - t : t - span.end)
        }
        return best
    }
}

nonisolated enum HandFingering {
    /// Hand positions: the leftmost finger over white key 0 (A0) … 47 (the pinky on C8).
    static let positions = 0...47

    private static let keyTable: [Int: (x: Double, isBlack: Bool)] = {
        let white: Set<Int> = [0, 2, 4, 5, 7, 9, 11]
        var table: [Int: (Double, Bool)] = [:]
        var below = 0
        for midi in 21...108 {
            if white.contains(midi % 12) {
                table[midi] = (Double(below) + 0.5, false)
                below += 1
            } else {
                table[midi] = (Double(below), true)   // on the boundary between two white keys
            }
        }
        return table
    }()

    /// A key's centre in white-key widths from A0's left edge, and whether it is black.
    static func key(_ midi: Int) -> (x: Double, isBlack: Bool)? { keyTable[midi] }

    static func ease(_ s: Double) -> Double {
        let s = max(0, min(1, s))
        return s * s * s * (s * (s * 6 - 15) + 10)
    }

    private struct Chord {
        let start: Double
        let notes: [(note: HandNote, x: Double, isBlack: Bool)]
        let keys: [(x: Double, isBlack: Bool)]   // distinct, low to high, at most five
    }

    /// `other`: the other hand's plan; positions overlapping it cost extra, so the hands only
    /// cross when the music needs it.
    static func plan(_ notes: [HandNote], isLeft: Bool, avoiding other: HandPlan? = nil) -> HandPlan {
        let mine = notes.filter { $0.isLeft == isLeft }
            .compactMap { n -> (note: HandNote, x: Double, isBlack: Bool)? in key(n.midi).map { (n, $0.x, $0.isBlack) } }
            .sorted { $0.note.start < $1.note.start }
        let thumb = isLeft ? 4 : 0
        guard !mine.isEmpty else {
            return HandPlan(isLeft: isLeft, initial: isLeft ? 16 : 23, moves: [], presses: Array(repeating: [], count: 5), active: [])
        }

        // notes starting together (or within a rolled chord) are played together
        var chords: [Chord] = []
        var group: [(note: HandNote, x: Double, isBlack: Bool)] = []
        func close() {
            guard let first = group.first else { return }
            var seen = Set<Double>()
            var keys = group.filter { seen.insert($0.x).inserted }.map { (x: $0.x, isBlack: $0.isBlack) }.sorted { $0.x < $1.x }
            if keys.count > 5 { keys = (0..<5).map { keys[$0 * (keys.count - 1) / 4] } }
            chords.append(Chord(start: first.note.start, notes: group, keys: keys))
            group = []
        }
        for item in mine {
            if let first = group.first, item.note.start - first.note.start > 0.03 { close() }
            group.append(item)
        }
        close()

        // the positions each chord can be played from, with what each costs
        func candidates(_ chord: Chord) -> [Int] {
            let low = chord.keys.first!.x, high = chord.keys.last!.x
            var from = Int(floor(high - 4.5 - 2.0)), to = Int(ceil(low - 0.5 + 2.0))
            if from > to {
                let centre = (low + high) / 2 - 2.5
                from = Int(floor(centre)) - 1
                to = Int(ceil(centre)) + 1
            }
            let lo = min(max(from, positions.lowerBound), positions.upperBound)
            let hi = min(max(to, lo), positions.upperBound)
            return Array(lo...hi)
        }
        let candidateLists = chords.map(candidates)
        let local = zip(chords, candidateLists).map { chord, list in
            list.map { p -> Double in
                var cost = assign(chord.keys, at: Double(p), thumb: thumb, busy: []).cost
                if let other, other.idle(at: chord.start) < 0.6 {
                    // keep a hand's width (five keys) between the two positions
                    let gap = isLeft ? other.position(at: chord.start) - Double(p) : Double(p) - other.position(at: chord.start)
                    cost += max(0, 5 - gap) * 1.5
                }
                return cost
            }
        }

        // the cheapest way through the whole piece: stretching, plus moving (more when hurried)
        var total = local[0]
        var back: [[Int]] = [Array(repeating: -1, count: total.count)]
        for i in 1..<chords.count {
            let gap = max(chords[i].start - chords[i - 1].start, 0.02)
            var row: [Double] = []
            var from: [Int] = []
            for (k, p) in candidateLists[i].enumerated() {
                var best = Double.infinity, arg = 0
                for (j, q) in candidateLists[i - 1].enumerated() {
                    let move = p == q ? 0 : 1.0 + 0.3 * Double(abs(p - q)) + 0.15 / gap
                    let cost = total[j] + move
                    if cost < best { best = cost; arg = j }
                }
                row.append(best + local[i][k])
                from.append(arg)
            }
            total = row
            back.append(from)
        }
        var choice = Array(repeating: 0, count: chords.count)
        choice[chords.count - 1] = total.indices.min { total[$0] < total[$1] } ?? 0
        for i in stride(from: chords.count - 1, to: 0, by: -1) { choice[i - 1] = back[i][choice[i]] }
        let chosen = choice.enumerated().map { Double(candidateLists[$0.offset][$0.element]) }

        // fingers, in order, leaving a finger that is still holding a note where it is
        var presses: [[HandPlan.Press]] = Array(repeating: [], count: 5)
        var lastRelease = Array(repeating: -Double.infinity, count: 5)
        var holding: [Int: (x: Double, release: Double)] = [:]
        for (i, chord) in chords.enumerated() {
            let busy = Set(holding.filter { $0.value.release > chord.start + 0.02 }.keys)
            let fingers = assign(chord.keys, at: chosen[i], thumb: thumb, busy: busy).fingers
            for item in chord.notes {
                let k = chord.keys.indices.min { abs(chord.keys[$0].x - item.x) < abs(chord.keys[$1].x - item.x) } ?? 0
                let finger = fingers[k]
                let free = item.note.start - lastRelease[finger]
                presses[finger].append(HandPlan.Press(finger: finger, key: item.x, isBlack: item.isBlack,
                                                      start: item.note.start, release: item.note.release,
                                                      approach: min(0.12, max(0.025, free))))
                lastRelease[finger] = max(lastRelease[finger], item.note.release)
                holding[finger] = (item.x, max(holding[finger]?.release ?? 0, item.note.release))
            }
        }

        // the hand moves in the gap before the chord that needs the new position
        var moves: [HandPlan.Move] = []
        for i in 1..<chords.count where chosen[i] != chosen[i - 1] {
            let gap = chords[i].start - chords[i - 1].start
            let end = chords[i].start - min(0.015, gap * 0.1)
            let duration = min(0.1 + 0.035 * abs(chosen[i] - chosen[i - 1]), 0.32, max(gap * 0.8, 0.02))
            moves.append(HandPlan.Move(start: max(end - duration, chords[i - 1].start + 0.001), end: end,
                                       from: chosen[i - 1], to: chosen[i]))
        }

        var active: [HandPlan.Span] = []
        for item in mine {
            let start = item.note.start - 0.5, end = item.note.release + 0.5
            if let last = active.last, start <= last.end {
                active[active.count - 1] = HandPlan.Span(start: last.start, end: max(last.end, end))
            } else {
                active.append(HandPlan.Span(start: start, end: end))
            }
        }
        // a finger is on one key at a time: given a new note while still holding one, it lets go
        // (the note rings on) as it heads for the new key
        for f in 0..<5 {
            presses[f].sort { $0.start < $1.start }
            for i in presses[f].indices.dropLast() {
                let press = presses[f][i], next = presses[f][i + 1]
                let leave = max(press.start + 0.02, next.start - next.approach)
                guard press.release > leave else { continue }
                presses[f][i] = HandPlan.Press(finger: f, key: press.key, isBlack: press.isBlack, start: press.start,
                                               release: leave, approach: press.approach)
            }
        }
        return HandPlan(isLeft: isLeft, initial: chosen[0], moves: moves, presses: presses, active: active)
    }

    /// One finger at one moment.
    struct Finger: Sendable {
        var x: Double            // key widths
        var y: Double            // fraction of the keyboard's height
        var depth: Double        // 0 up … 1 pressing
        var engage: Double       // 0 resting … 1 over its key
    }

    /// Where the hand is (`position`) and each finger, at second `t`. Continuous in `t`: a
    /// finger handing over from one key to the next blends between them.
    static func pose(_ plan: HandPlan, at t: Double) -> (position: Double, fingers: [Finger]) {
        let p = plan.position(at: t)
        // resting tips: the middle finger reaches furthest, the thumb sits low
        let restRight: [Double] = [0.8, 0.5, 0.45, 0.48, 0.57]
        let rest = plan.isLeft ? Array(restRight.reversed()) : restRight
        var result: [Finger] = []
        for f in 0..<5 {
            let natural = p + 0.5 + Double(f)
            let isThumb = f == plan.thumb
            let presses = plan.presses[f]
            var lo = 0, hi = presses.count
            while lo < hi {
                let mid = (lo + hi) / 2
                if presses[mid].start - presses[mid].approach <= t { lo = mid + 1 } else { hi = mid }
            }
            var weight = 0.0, engage = 0.0, depth = 0.0, x = 0.0, y = 0.0
            // every press still fading out (fast passages overlap several) or about to begin
            for i in max(0, lo - 10)..<min(presses.count, lo + 2) {
                let press = presses[i]
                if t > press.release + 0.1 { continue }
                let e: Double
                if t < press.start { e = ease((t - (press.start - press.approach)) / press.approach) }
                else if t <= press.release { e = 1 }
                else { e = 1 - ease((t - press.release) / 0.1) }
                guard e > 0 else { continue }
                let strike = min(0.035, press.approach * 0.5)
                let d: Double
                if t < press.start - strike { d = 0 }
                else if t < press.start { d = ease((t - (press.start - strike)) / strike) }
                else if t <= press.release { d = 1 }
                else { d = 1 - ease((t - press.release) / 0.06) }
                // over the key the finger is lifted, pressing it the tip curls in toward the front
                let lifted = press.isBlack ? (isThumb ? 0.46 : 0.36) : (isThumb ? 0.66 : 0.56)
                let pressed = press.isBlack ? (isThumb ? 0.5 : 0.42) : (isThumb ? 0.76 : 0.68)
                weight += e
                x += press.key * e
                y += (lifted + (pressed - lifted) * d) * e
                engage = max(engage, e)
                depth = max(depth, d)
            }
            var finger = Finger(x: natural, y: rest[f], depth: depth, engage: engage)
            if weight > 0 {
                finger.x = natural + (x / weight - natural) * engage
                finger.y = rest[f] + (y / weight - rest[f]) * engage
            }
            result.append(finger)
        }
        // fingers that are not playing make room for the ones that are (fading out as they engage)
        for f in 1..<5 {
            let room = max(0, 1 - 2 * result[f].engage)
            let limit = result[f - 1].x + 0.62
            if result[f].x < limit { result[f].x += (limit - result[f].x) * room }
        }
        for f in stride(from: 3, through: 0, by: -1) {
            let room = max(0, 1 - 2 * result[f].engage)
            let limit = result[f + 1].x - 0.62
            if result[f].x > limit { result[f].x += (limit - result[f].x) * room }
        }
        return (p, result)
    }

    /// The fingers (in order) for `keys` with the hand at `position`, and how awkward that is.
    static func assign(_ keys: [(x: Double, isBlack: Bool)], at position: Double, thumb: Int,
                       busy: Set<Int>) -> (cost: Double, fingers: [Int]) {
        let pinky = 4 - thumb
        var best: (cost: Double, fingers: [Int]) = (.infinity, Array(0..<keys.count).map { min($0, 4) })
        func search(_ next: Int, _ from: Int, _ chosen: [Int], _ cost: Double) {
            if cost >= best.cost { return }
            if next == keys.count { best = (cost, chosen); return }
            for f in from..<5 where 5 - f >= keys.count - next {
                let d = abs(keys[next].x - (position + 0.5 + Double(f)))
                var c = d * d + max(0, d - 1) * 3
                if keys[next].isBlack && f == thumb { c += 0.8 }
                if keys[next].isBlack && f == pinky { c += 0.3 }
                if busy.contains(f) { c += 3 }
                c += 0.02 * Double(abs(f - 2))
                search(next + 1, f + 1, chosen + [f], cost + c)
            }
        }
        search(0, 0, [], 0)
        return best
    }
}

// MARK: - Ghost hands
//
// Two hands drawn in white line on a dark panel, fixed in a corner over the keyboard (the end
// the song uses least). They do not move: when a note plays, the finger the fingering plan gives
// it lights up in its hand's colour (left blue, right red) and shows its piano finger number
// (1 thumb … 5 little finger). A finger starts to glow faintly just before its note and fades
// as it lets go. The artwork is images (Assets.xcassets/GhostHands, made by
// scripts/ghost-hands/make_hand_images.swift): the hand, and a white glow per finger that is
// tinted here.

final class GhostHandsView: UIView {
    var keyWidth: CGFloat = 13

    private final class HandArt {
        let isLeft: Bool
        let view = UIView()
        let art = UIView()                  // mirrored for the left hand
        let base = UIImageView(image: UIImage(named: "GhostHand"))
        let glows: [UIImageView]            // piano finger 1…5
        let badges: [UILabel]
        let caption = UILabel()

        init(isLeft: Bool) {
            self.isLeft = isLeft
            let tint = isLeft ? AnimatedPianoKeyView.leftColor : AnimatedPianoKeyView.rightColor
            glows = (1...5).map { n in
                let glow = UIImageView(image: UIImage(named: "GhostFinger\(n)")?.withRenderingMode(.alwaysTemplate))
                glow.tintColor = tint
                glow.alpha = 0
                return glow
            }
            badges = (1...5).map { n in
                let badge = UILabel()
                badge.text = "\(n)"
                badge.font = .systemFont(ofSize: 11, weight: .heavy)
                badge.textColor = .white
                badge.textAlignment = .center
                badge.backgroundColor = tint
                badge.layer.cornerRadius = 8
                badge.layer.borderColor = UIColor.white.cgColor
                badge.layer.borderWidth = 1.2
                badge.clipsToBounds = true
                badge.alpha = 0
                return badge
            }
            caption.text = isLeft ? "L" : "R"
            caption.font = .systemFont(ofSize: 10, weight: .bold)
            caption.textColor = tint
            caption.textAlignment = .center
            [base].forEach { $0.contentMode = .scaleAspectFit }
            glows.forEach { $0.contentMode = .scaleAspectFit }
            art.addSubview(base)
            glows.forEach { art.addSubview($0) }
            view.addSubview(art)
            badges.forEach { view.addSubview($0) }
            view.addSubview(caption)
            if isLeft { art.transform = CGAffineTransform(scaleX: -1, y: 1) }
        }
    }

    /// Fingertips in the right-hand image (piano finger 1…5), as fractions of its size.
    private static let tips: [CGPoint] = [CGPoint(x: 0.229, y: 0.408), CGPoint(x: 0.39, y: 0.2),
                                          CGPoint(x: 0.548, y: 0.15), CGPoint(x: 0.7, y: 0.196),
                                          CGPoint(x: 0.833, y: 0.288)]
    private static let imageAspect: CGFloat = 420.0 / 480.0

    private var plans: [HandPlan] = []
    private let panel = UIView()
    private let hands = [HandArt(isLeft: true), HandArt(isLeft: false)]
    private var onRight = true
    private var lastTime: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        panel.layer.cornerRadius = 12
        panel.layer.cornerCurve = .continuous
        panel.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        panel.layer.borderWidth = 0.5
        panel.alpha = 0
        addSubview(panel)
        hands.forEach { panel.addSubview($0.view) }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.height > 0 else { return }
        // small, in the corner over the front of the white keys: about 40% of the keyboard's height
        let inset: CGFloat = 4
        let caption: CGFloat = 9
        let handHeight = min(56, (bounds.height * 0.4).rounded())
        let handWidth = handHeight * Self.imageAspect
        let panelSize = CGSize(width: 2 * handWidth + 3 * 3, height: handHeight + caption + 6)
        let x = onRight ? bounds.width - panelSize.width - inset : inset
        panel.frame = CGRect(origin: CGPoint(x: x, y: bounds.height - panelSize.height - inset), size: panelSize)
        panel.layer.cornerRadius = 9
        let badgeSize = max(11, (handHeight * 0.24).rounded())
        for (i, hand) in hands.enumerated() {
            hand.view.frame = CGRect(x: 3 + CGFloat(i) * (handWidth + 3), y: 4, width: handWidth, height: handHeight + caption)
            hand.art.transform = .identity
            hand.art.frame = CGRect(x: 0, y: 0, width: handWidth, height: handHeight)
            if hand.isLeft { hand.art.transform = CGAffineTransform(scaleX: -1, y: 1) }
            hand.base.frame = hand.art.bounds
            hand.glows.forEach { $0.frame = hand.art.bounds }
            for (n, badge) in hand.badges.enumerated() {
                let tip = Self.tips[n]
                let tx = hand.isLeft ? 1 - tip.x : tip.x
                badge.bounds = CGRect(x: 0, y: 0, width: badgeSize, height: badgeSize)
                badge.layer.cornerRadius = badgeSize / 2
                badge.font = .systemFont(ofSize: badgeSize * 0.68, weight: .heavy)
                badge.center = CGPoint(x: tx * handWidth, y: max(badgeSize / 2, tip.y * handHeight - badgeSize * 0.6))
            }
            hand.caption.font = .systemFont(ofSize: 8, weight: .bold)
            hand.caption.frame = CGRect(x: 0, y: handHeight - 1, width: handWidth, height: caption)
        }
    }

    /// Fingers the whole performance (both hands) and picks the corner the song uses least.
    func setPerformance(_ notes: [HandNote]) {
        let left = HandFingering.plan(notes, isLeft: true)
        plans = [left, HandFingering.plan(notes, isLeft: false, avoiding: left)]
        let mean = notes.isEmpty ? 60 : Double(notes.reduce(0) { $0 + $1.midi }) / Double(notes.count)
        onRight = mean < 66
        panel.alpha = notes.isEmpty ? 0 : 1
        setNeedsLayout()
        show(time: lastTime)
    }

    /// Lights the fingers playing at second `time` of the performance (at 1× tempo).
    func show(time: Double) {
        lastTime = time
        guard plans.count == 2 else { return }
        for (plan, hand) in zip(plans, hands) {
            hand.base.alpha = plan.isEmpty ? 0.25 : (plan.idle(at: time) <= 0 ? 0.6 : 0.4)
            guard !plan.isEmpty else { continue }
            let pose = HandFingering.pose(plan, at: time).fingers
            for f in 0..<5 {
                // planner fingers run left to right on the keyboard: the right hand starts at
                // its thumb, the left hand at its little finger
                let number = plan.isLeft ? 5 - f : f + 1
                let lit = CGFloat(pose[f].depth), coming = CGFloat(pose[f].engage)
                hand.glows[number - 1].alpha = max(lit, coming * 0.3)
                let badge = hand.badges[number - 1]
                badge.alpha = lit
                badge.transform = CGAffineTransform(scaleX: 0.6 + 0.4 * lit, y: 0.6 + 0.4 * lit)
            }
        }
    }
}


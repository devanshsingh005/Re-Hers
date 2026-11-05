import UIKit

// MARK: - SheetMusicView
//
// The score in Animation and Play Along, laid out like a printed page: systems (lines of
// measures) stacked top to bottom. A cursor moves across the current line in time with the
// music; when the line ends the page scrolls up so the next line takes its place.
//
// Line breaks follow the original (`<print new-system>`) where the lines fit, else measures
// are packed greedily; every line is justified to the width. Inside a measure notes are
// spaced the way engravers do it — longer notes get more room, but not proportionally more
// (the original `default-x` positions are used when the score has them) — with room kept for
// accidentals, dots, flags and note names so nothing collides. Each line starts with its
// clefs and key (and the time signature where it begins or changes).
//
// Every note is engraved from the score: head by value, stem as written (else away from the
// middle line), flags or sloped beams, dots, accidentals, ledger lines, ties, slurs, tuplets,
// articulations and fermatas, 8va lines, rests of the right shape; plus dynamics, hairpins,
// tempo and text marks, repeat barlines and 1st / 2nd endings. Under each staff a row of note
// names in the hand's colour (left blue, right red, like the keys). While a note sounds its
// head, a bar showing how long it lasts, and its name light up.

final class SheetMusicView: UIView {

    // Delegate to communicate seeks
    var onSeekProgress: ((CGFloat) -> Void)?

    // MARK: Style
    private let paper = UIColor(white: 0.97, alpha: 1)
    private let ink = UIColor(white: 0.12, alpha: 1)
    private let brandOrange = UIColor(red: 239.0/255.0, green: 148.0/255.0, blue: 8.0/255.0, alpha: 1.0)

    // MARK: State
    private var timeline: ScoreTimeline?
    private var page: SheetPage?
    private var currentTick: Double = 0
    private var loadGeneration = 0
    private var renderPending = false
    private var lastBounds = CGRect.zero

    private var visuals: [SheetNoteVisual] = []
    private var nextVisual = 0
    private var activeVisuals: [Int] = []
    private var stateTick = -Double.infinity
    private var shownSystem = -1

    // MARK: Permanent layers / views (added once, never removed)
    private let pageLayer = CALayer()      // every system, stacked; scrolled vertically
    private let cursorBand = CALayer()
    private let cursor = CALayer()
    private let feedbackOverlay = UIView()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = paper
        clipsToBounds = true
        pageLayer.anchorPoint = .zero
        pageLayer.position = .zero
        layer.addSublayer(pageLayer)

        cursorBand.backgroundColor = brandOrange.withAlphaComponent(0.12).cgColor
        cursor.backgroundColor = brandOrange.cgColor
        cursor.cornerRadius = 1.25
        cursor.shadowColor = brandOrange.cgColor
        cursor.shadowOpacity = 0.55
        cursor.shadowRadius = 4
        cursor.shadowOffset = .zero

        feedbackOverlay.isUserInteractionEnabled = false
        feedbackOverlay.alpha = 0
        addSubview(feedbackOverlay)
    }

    // MARK: - Loading

    /// Parses the score JSON off the main thread, then draws it.
    func loadData(_ data: Data) {
        loadGeneration += 1
        let generation = loadGeneration
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let timeline = try? ScoreTimeline.parse(data: data) else { return }
            DispatchQueue.main.async {
                guard let self, self.loadGeneration == generation else { return }
                self.load(timeline: timeline)
            }
        }
    }

    /// Draws a score that is already parsed (Animation shares its timeline with playback).
    func load(timeline: ScoreTimeline) {
        loadGeneration += 1
        self.timeline = timeline
        scheduleRender()
        setNeedsLayout()
    }

    func setChordCount(_ n: Int) {}

    /// Play Along hands over its chords after `loadData`; the sheet already has everything.
    func configure(with chords: [SongChord]) {
        setNeedsLayout()
    }

    func setProgressBarHidden(_ hidden: Bool) {}

    // MARK: - Playback

    func updateProgress(to tick: Int) {
        updateToTick(Double(tick))
    }

    func updatePlaybackProgress(_ p: CGFloat) {
        let total = Double(timeline?.totalTicks ?? 0)
        updateToTick(total * Double(max(0, min(1, p))))
    }

    /// Moves the cursor to `tick` (scrolling to its line) and lights the notes sounding there.
    func updateToTick(_ tick: Double) {
        currentTick = max(0, tick)
        guard let page, let timeline else { return }
        let spot = page.locate(min(currentTick, Double(timeline.totalTicks)), in: timeline)
        let system = page.systems[spot.system]
        let s = page.space
        let top = system.staffTops[0] - 1.6 * s
        let height = (system.staffTops.last ?? top) + 4 * s + 1.6 * s - top
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cursor.frame = CGRect(x: spot.x - 1.25, y: top, width: 2.5, height: height)
        cursorBand.frame = CGRect(x: spot.x - 0.9 * s, y: top, width: 1.8 * s, height: height)
        cursorBand.cornerRadius = 0.4 * s
        CATransaction.commit()
        if spot.system != shownSystem { scroll(to: spot.system, animated: shownSystem >= 0) }
        updateNoteStates()
    }

    func resetProgress() {
        updateToTick(0)
        pageLayer.sublayers?.filter { $0.name == "WrongNoteMarker" }.forEach { $0.removeFromSuperlayer() }
    }

    /// Brings `system` to the top of the view (the line after it shows below).
    private func scroll(to system: Int, animated: Bool) {
        guard let page else { return }
        shownSystem = system
        let line = page.systems[system]
        var y = max(0, min(line.top, page.height - bounds.height))
        if line.bottom > y + bounds.height { y = line.top }
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(0.45)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        pageLayer.transform = CATransform3DMakeTranslation(0, -y, 0)
        CATransaction.commit()
    }

    // MARK: - Interactive Feedback

    func showFeedback(isCorrect: Bool) {
        let color = isCorrect ? UIColor.systemGreen : UIColor.systemRed
        feedbackOverlay.backgroundColor = color.withAlphaComponent(0.15)

        UIView.animate(withDuration: 0.1, animations: {
            self.feedbackOverlay.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut, animations: {
                self.feedbackOverlay.alpha = 0
            }, completion: nil)
        }
    }

    func addWrongNoteMarker(at tick: Double) {
        guard let page, let timeline else { return }
        let spot = page.locate(tick, in: timeline)
        let system = page.systems[spot.system]
        let marker = CALayer()
        marker.name = "WrongNoteMarker"
        marker.backgroundColor = UIColor.systemRed.withAlphaComponent(0.55).cgColor
        marker.cornerRadius = 2
        let top = system.staffTops[0] - 4
        marker.frame = CGRect(x: spot.x - 1.25, y: top, width: 2.5,
                              height: (system.staffTops.last ?? top) + 4 * page.space + 8 - top)
        pageLayer.addSublayer(marker)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 1.1
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        marker.add(fade, forKey: "fadeOut")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            marker.removeFromSuperlayer()
        }
    }

    /// The measures on each line, top to bottom.
    var systemRanges: [Range<Int>] { page?.systems.map(\.measures) ?? [] }

    /// The whole page as an image (for checking the engraving).
    func pageImage() -> UIImage? {
        guard let page else { return nil }
        let size = CGSize(width: bounds.width, height: page.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            paper.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let saved = pageLayer.transform
            pageLayer.transform = CATransform3DIdentity
            pageLayer.render(in: context.cgContext)
            pageLayer.transform = saved
            CATransaction.commit()
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        feedbackOverlay.frame = bounds
        if bounds != lastBounds {
            lastBounds = bounds
            scheduleRender()
        }
    }

    private func scheduleRender() {
        guard !renderPending else { return }
        renderPending = true
        DispatchQueue.main.async { [weak self] in
            self?.renderPending = false
            self?.doRender()
        }
    }

    private func doRender() {
        guard bounds.width > 0, bounds.height > 0, let timeline else { return }
        var builder = PageBuilder(timeline: timeline, width: bounds.width, viewHeight: bounds.height,
                                  ink: ink, scale: displayScale, space: nil)
        var built = builder.build()
        // every line must fit in the view: a wide-ranging score is set a little smaller
        for _ in 0..<2 {
            let tallest = built.page.systems.map { $0.bottom - $0.top }.max() ?? 0
            guard tallest > bounds.height - 4 else { break }
            let space = max(5.5, built.page.space * (bounds.height - 4) / tallest * 0.98)
            guard space < built.page.space else { break }
            builder = PageBuilder(timeline: timeline, width: bounds.width, viewHeight: bounds.height,
                                  ink: ink, scale: displayScale, space: space)
            built = builder.build()
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pageLayer.sublayers = built.layers + [cursorBand, cursor]
        pageLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: built.page.height)
        CATransaction.commit()

        page = built.page
        visuals = built.visuals
        nextVisual = 0
        activeVisuals = []
        stateTick = -Double.infinity
        shownSystem = -1
        updateToTick(currentTick)
    }

    private var displayScale: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? scale : 3
    }

    // MARK: - Note states

    private func updateNoteStates() {
        guard !visuals.isEmpty else { return }
        let t = currentTick
        if t < stateTick {
            // moved back: work every note out again
            activeVisuals = []
            nextVisual = visuals.count
            for i in visuals.indices {
                let v = visuals[i]
                let state: SheetNoteState = v.start > t ? .upcoming : (t < v.end ? .active : .played)
                if v.start > t && nextVisual == visuals.count { nextVisual = i }
                if state == .active { activeVisuals.append(i) }
                setState(state, at: i, animated: false)
            }
        } else {
            while nextVisual < visuals.count && visuals[nextVisual].start <= t {
                activeVisuals.append(nextVisual)
                setState(.active, at: nextVisual, animated: true)
                nextVisual += 1
            }
            activeVisuals.removeAll { i in
                guard visuals[i].end <= t else { return false }
                setState(.played, at: i, animated: true)
                return true
            }
        }
        stateTick = t
    }

    private func setState(_ state: SheetNoteState, at i: Int, animated: Bool) {
        guard visuals[i].state != state else { return }
        visuals[i].state = state
        let v = visuals[i]
        let hand = v.isLeft ? AnimatedPianoKeyView.leftColor : AnimatedPianoKeyView.rightColor

        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(state == .active ? 0.08 : 0.25)
        } else {
            CATransaction.setDisableActions(true)
        }
        switch state {
        case .upcoming:
            v.head.fillColor = ink.cgColor
            v.bar?.backgroundColor = hand.withAlphaComponent(0.14).cgColor
            v.label?.foregroundColor = hand.withAlphaComponent(0.85).cgColor
        case .active:
            v.head.fillColor = hand.cgColor
            v.bar?.backgroundColor = hand.withAlphaComponent(0.45).cgColor
            v.label?.foregroundColor = hand.cgColor
        case .played:
            v.head.fillColor = ink.withAlphaComponent(0.5).cgColor
            v.bar?.backgroundColor = hand.withAlphaComponent(0.06).cgColor
            v.label?.foregroundColor = hand.withAlphaComponent(0.45).cgColor
        }
        CATransaction.commit()
    }
}

// MARK: - Page model

private struct SheetSystem {
    let measures: Range<Int>
    let top: CGFloat
    let bottom: CGFloat
    let staffTops: [CGFloat]
    let left: CGFloat                   // the system's opening barline
    let right: CGFloat                  // its closing barline
}

/// Where the cursor goes in one measure: x at ticks, linear in between.
private struct MeasureSpot {
    let system: Int
    var points: [(tick: Double, x: CGFloat)]
}

private struct SheetPage {
    let space: CGFloat
    let height: CGFloat
    let systems: [SheetSystem]
    let spots: [MeasureSpot]

    func locate(_ tick: Double, in timeline: ScoreTimeline) -> (system: Int, x: CGFloat) {
        guard !spots.isEmpty else { return (0, 0) }
        let measure = min(timeline.measureIndex(atTick: tick), spots.count - 1)
        return (spots[measure].system, x(tick, measure: measure))
    }

    func x(_ tick: Double, measure: Int) -> CGFloat {
        let points = spots[measure].points
        guard let first = points.first else { return 0 }
        if tick <= first.tick { return first.x }
        for k in 1..<points.count where tick <= points[k].tick {
            let a = points[k - 1], b = points[k]
            let f = b.tick > a.tick ? CGFloat((tick - a.tick) / (b.tick - a.tick)) : 1
            return a.x + (b.x - a.x) * f
        }
        return points.last?.x ?? first.x
    }
}

private enum SheetNoteState { case upcoming, active, played }

private struct SheetNoteVisual {
    let start: Double
    let end: Double
    let isLeft: Bool
    let head: CAShapeLayer          // head, dots and accidental
    let bar: CALayer?               // how long it sounds
    let label: CATextLayer?
    var state = SheetNoteState.upcoming
}

// MARK: - PageBuilder

/// Lays the score out in lines and builds every layer.
private struct PageBuilder {
    struct Result {
        let layers: [CALayer]
        let page: SheetPage
        let visuals: [SheetNoteVisual]
    }

    /// Notes printed on one stem: one staff and voice at one time. Ys are measured from the
    /// staff's top line until the systems are placed, then from the page's top.
    struct Chord {
        var notes: [Int]                // indices into timeline.notes, low to high on the staff
        let staff: Int
        let measure: Int
        let tick: Int
        let value: NoteValue
        let isGrace: Bool
        let beamGroup: Int?
        let writtenStem: ScoreNote.Stem?
        var up = true
        var hasStem = true
        var x: CGFloat = 0
        var headDX: [Int: CGFloat] = [:]
        var accidentalDX: [Int: CGFloat] = [:]
        var y: [Int: CGFloat] = [:]
        var left: CGFloat = 0           // room the chord needs left of x
        var right: CGFloat = 0          // and right of x
        var stemDX: CGFloat = 0
        var baseY: CGFloat = 0
        var tipY: CGFloat = 0
        var highY: CGFloat = 0
        var lowY: CGFloat = 0
        var scale: CGFloat { isGrace ? 0.65 : 1 }
        var stemX: CGFloat { x + stemDX }
    }

    /// What one onset (a moment where something starts) needs around it.
    struct Onset {
        var left: CGFloat = 0
        var right: CGFloat = 0
        var labelHalf: CGFloat = 0
        var defaultX: Double?
    }

    struct MeasurePlan {
        var ticks: [Int] = []
        var lead: CGFloat = 0
        var gaps: [CGFloat] = []        // after each onset (the last one: to the barline)
        var minimumGaps: [CGFloat] = [] // squeezed as far as the symbols and names allow
        var width: CGFloat { lead + gaps.reduce(0, +) }
        var minimumWidth: CGFloat { lead + minimumGaps.reduce(0, +) }
    }

    let timeline: ScoreTimeline
    let width: CGFloat
    let viewHeight: CGFloat
    let ink: UIColor
    let scale: CGFloat
    let s: CGFloat

    private var chords: [Chord] = []
    private var chordsByMeasure: [Int: [Int]] = [:]
    private var onsets: [Int: [Int: Onset]] = [:]       // measure → tick → needs
    private var plans: [MeasurePlan] = []
    private var lines: [Range<Int>] = []
    private var onsetX: [Int: [Int: CGFloat]] = [:]      // measure → tick → x
    private var measureX: [CGFloat] = []                 // barline at the measure's start
    private var measureEndX: [CGFloat] = []
    private var lineOf: [Int] = []
    private var systems: [SheetSystem] = []
    private var labelRows: [Int: CGFloat] = [:]          // chord → top of its first name, staff-relative
    private var beams: [Int: [Int]] = [:]                // beam group → its chords, left to right
    private var drawnBeams = Set<Int>()

    private var inkPaths: [Int: CGMutablePath] = [:]
    private var lineLayers: [CALayer] = []
    private var barLayers: [CALayer] = []
    private var headLayers: [CALayer] = []
    private var textLayers: [CALayer] = []
    private var visuals: [SheetNoteVisual] = []

    private let labelFont: UIFont
    private var stemWidth: CGFloat { max(1, 0.11 * s) }
    private var margin: CGFloat { 0.6 * s }

    /// `space`: the staff space; nil starts from the view's height (one line of a grand staff
    /// with its names, plus part of the next).
    init(timeline: ScoreTimeline, width: CGFloat, viewHeight: CGFloat, ink: UIColor, scale: CGFloat, space: CGFloat?) {
        self.timeline = timeline
        self.width = width
        self.viewHeight = viewHeight
        self.ink = ink
        self.scale = scale
        self.s = space ?? (min(10, max(6.5, viewHeight / 22)) * 2).rounded() / 2
        self.labelFont = UIFont.systemFont(ofSize: max(6, 0.8 * self.s), weight: .semibold)
    }

    private mutating func inkPath(_ measure: Int) -> CGMutablePath {
        if let path = inkPaths[measure] { return path }
        let path = CGMutablePath()
        inkPaths[measure] = path
        return path
    }

    mutating func build() -> Result {
        makeChords()
        measureOnsets()
        planMeasures()
        breakLines()
        placeHorizontally()
        beam()
        placeSystems()

        drawSystems()
        drawClefChanges()
        for c in chords.indices { drawChord(c) }
        drawRests()
        drawTies()
        drawSlurs()
        drawTuplets()
        drawDirections()

        let ink = inkPaths.sorted { $0.key < $1.key }.map { _, path -> CALayer in
            let layer = CAShapeLayer()
            layer.path = path
            layer.fillColor = self.ink.cgColor
            return layer
        }
        visuals.sort { $0.start < $1.start }

        var spots: [MeasureSpot] = []
        for (i, measure) in timeline.measures.enumerated() {
            var points: [(tick: Double, x: CGFloat)] = []
            let ticks = (onsetX[i] ?? [:]).sorted { $0.key < $1.key }
            let firstX = ticks.first.map { $0.key == measure.startTick ? $0.value : measureX[i] + plans[i].lead } ?? measureX[i] + plans[i].lead
            points.append((Double(measure.startTick), firstX))
            for (tick, x) in ticks where tick > measure.startTick { points.append((Double(tick), x)) }
            // glide into the next measure's first note when it is on the same line
            var endX = measureEndX[i]
            if i + 1 < timeline.measures.count, lineOf[i + 1] == lineOf[i] {
                let next = timeline.measures[i + 1]
                endX = onsetX[i + 1]?[next.startTick] ?? measureX[i + 1] + plans[i + 1].lead
            }
            points.append((Double(measure.endTick), endX))
            spots.append(MeasureSpot(system: lineOf[i], points: points))
        }
        let height = (systems.last?.bottom ?? 0) + 2 * s
        let page = SheetPage(space: s, height: max(height, viewHeight), systems: systems, spots: spots)
        return Result(layers: barLayers + lineLayers + ink + headLayers + textLayers, page: page, visuals: visuals)
    }

    // MARK: Chords (stems, seconds, accidentals) — staff-relative

    private func relY(_ note: ScoreNote) -> CGFloat {
        4 * s - CGFloat((note.displayDiatonic ?? 0) - note.clef.bottomLineDiatonic) * s / 2
    }

    private mutating func makeChords() {
        let notes = timeline.notes
        var byKey: [String: Int] = [:]
        var lastGrace: [Int: Int] = [:]
        for (i, note) in notes.enumerated() where !note.isRest && note.displayDiatonic != nil && note.isPrinted {
            if note.isGrace {
                if note.isChordTone, let c = lastGrace[note.staff], chords[c].tick == note.startTick {
                    chords[c].notes.append(i)
                    continue
                }
                lastGrace[note.staff] = chords.count
            } else {
                let key = "\(note.staff)|\(note.voice)|\(note.startTick)"
                if let c = byKey[key] {
                    chords[c].notes.append(i)
                    continue
                }
                byKey[key] = chords.count
            }
            chords.append(Chord(notes: [i], staff: note.staff, measure: note.measureIndex, tick: note.startTick,
                                value: note.value, isGrace: note.isGrace, beamGroup: note.beamGroup,
                                writtenStem: note.stem))
        }
        for c in chords.indices {
            chords[c].notes.sort { (notes[$0].displayDiatonic ?? 0) < (notes[$1].displayDiatonic ?? 0) }
            chords[c].hasStem = chords[c].value.hasStem && chords[c].writtenStem != ScoreNote.Stem.none
            chords[c].up = defaultStemUp(chords[c])
            chordsByMeasure[chords[c].measure, default: []].append(c)
        }

        // a beam group shares one stem direction: as most of it is written, else by position
        var groups: [Int: [Int]] = [:]
        for (c, chord) in chords.enumerated() where chord.hasStem && !chord.isGrace {
            if let group = chord.beamGroup { groups[group, default: []].append(c) }
        }
        for (_, members) in groups where members.count >= 2 {
            let written = members.compactMap { chords[$0].writtenStem }
            let ups = written.filter { $0 == .up }.count, downs = written.filter { $0 == .down }.count
            var up = ups > downs
            if ups == downs {
                var total = 0
                for c in members {
                    let mid = middleLine(chords[c])
                    for i in chords[c].notes { total += (notes[i].displayDiatonic ?? mid) - mid }
                }
                up = total < 0
            }
            for c in members { chords[c].up = up }
        }
        for c in chords.indices { shape(&chords[c]) }
    }

    private func middleLine(_ chord: Chord) -> Int {
        timeline.notes[chord.notes[0]].clef.bottomLineDiatonic + 4
    }

    /// As written; else away from the middle line, judged by the chord's farthest note.
    private func defaultStemUp(_ chord: Chord) -> Bool {
        if chord.isGrace { return true }
        switch chord.writtenStem {
        case .up?:   return true
        case .down?: return false
        default:     break
        }
        let mid = middleLine(chord)
        let positions = chord.notes.compactMap { timeline.notes[$0].displayDiatonic }
        let high = positions.max() ?? mid, low = positions.min() ?? mid
        return high - mid < mid - low
    }

    /// Heads (a second apart: one moves across the stem), stem, accidentals and the room the
    /// chord takes, all relative to the chord's x and the staff's top line.
    private func shape(_ chord: inout Chord) {
        let notes = timeline.notes
        let hs = s * chord.scale
        let headWidth = SheetGlyphs.headWidth(chord.value, s: hs)
        for i in chord.notes { chord.y[i] = relY(notes[i]) }

        let order = chord.up ? chord.notes : chord.notes.reversed()
        var previous: Int?
        var previousMoved = false
        for i in order {
            let d = notes[i].displayDiatonic ?? 0
            var dx: CGFloat = 0
            var moved = false
            if let p = previous, abs(d - p) == 1, !previousMoved {
                dx = (chord.up ? 1 : -1) * (headWidth - stemWidth)
                moved = true
            }
            chord.headDX[i] = dx
            previous = d
            previousMoved = moved
        }

        chord.highY = chord.notes.compactMap { chord.y[$0] }.min() ?? 0
        chord.lowY = chord.notes.compactMap { chord.y[$0] }.max() ?? 0
        let length = (chord.isGrace ? 2.5 : 3.5) * hs + CGFloat(max(0, chord.value.flagCount - 2)) * 0.75 * hs
        if chord.up {
            chord.stemDX = headWidth / 2 - stemWidth / 2
            chord.baseY = chord.lowY - 0.15 * s
            chord.tipY = chord.highY - length
            if !chord.isGrace { chord.tipY = min(chord.tipY, 2 * s) }
        } else {
            chord.stemDX = -headWidth / 2 + stemWidth / 2
            chord.baseY = chord.highY + 0.15 * s
            chord.tipY = chord.lowY + length
            if !chord.isGrace { chord.tipY = max(chord.tipY, 2 * s) }
        }

        // accidentals: as close to the heads as they fit without overlapping each other
        let dxs = chord.notes.compactMap { chord.headDX[$0] }
        let leftmost = (dxs.min() ?? 0) - headWidth / 2
        var placed: [(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat)] = []
        chord.accidentalDX = [:]
        for i in chord.notes.reversed() {
            guard let accidental = notes[i].accidental, let y = chord.y[i] else { continue }
            let w = SheetGlyphs.accidentalWidth(accidental, s: hs)
            let (above, below) = SheetGlyphs.accidentalExtent(accidental, s: hs)
            var right = leftmost - 0.25 * hs
            for _ in 0..<6 {
                guard let hit = placed.first(where: { $0.left < right && right - w < $0.right
                    && $0.top < y + below && y - above < $0.bottom }) else { break }
                right = hit.left - 0.12 * hs
            }
            placed.append((right - w, right, y - above, y + below))
            chord.accidentalDX[i] = right - w / 2
        }
        chord.left = max(headWidth / 2 - (dxs.min() ?? 0), -(placed.map(\.left).min() ?? 0)) + (chord.isGrace ? 0 : 0.1 * s)
        let dots = chord.notes.map { notes[$0].dots }.max() ?? 0
        var right = (dxs.max() ?? 0) + headWidth / 2
        if dots > 0 { right += 0.3 * hs + CGFloat(dots) * 0.5 * hs }
        if chord.up && chord.hasStem && chord.beamGroup == nil && chord.value.flagCount > 0 {
            right = max(right, chord.stemDX + 1.1 * hs)
        }
        chord.right = right
    }

    // MARK: Horizontal: onsets, measure widths, lines

    private func labelWidth(_ text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: labelFont]).width)
    }

    private mutating func measureOnsets() {
        let notes = timeline.notes
        for chord in chords where !chord.isGrace {
            var onset = onsets[chord.measure]?[chord.tick] ?? Onset()
            onset.left = max(onset.left, chord.left)
            onset.right = max(onset.right, chord.right)
            let names = chord.notes.filter { notes[$0].isStruck }.compactMap { notes[$0].writtenName }
            if let widest = names.map(labelWidth).max() { onset.labelHalf = max(onset.labelHalf, widest / 2) }
            let xs = chord.notes.compactMap { notes[$0].defaultX }
            if let x = xs.min() { onset.defaultX = min(onset.defaultX ?? x, x) }
            onsets[chord.measure, default: [:]][chord.tick] = onset
        }
        // grace notes take room before their main note
        var graceCount: [String: Int] = [:]
        for chord in chords where chord.isGrace { graceCount["\(chord.measure)|\(chord.tick)", default: 0] += 1 }
        for (key, count) in graceCount {
            let parts = key.split(separator: "|").compactMap { Int($0) }
            var onset = onsets[parts[0]]?[parts[1]] ?? Onset()
            onset.left += CGFloat(count) * 1.2 * s
            onsets[parts[0], default: [:]][parts[1]] = onset
        }
        for note in notes where note.isRest && !note.isGrace && note.isPrinted && !note.isMeasureRest {
            var onset = onsets[note.measureIndex]?[note.startTick] ?? Onset()
            onset.left = max(onset.left, 0.7 * s)
            onset.right = max(onset.right, 0.7 * s + CGFloat(note.dots) * 0.5 * s)
            if let x = note.defaultX { onset.defaultX = min(onset.defaultX ?? x, x) }
            onsets[note.measureIndex, default: [:]][note.startTick] = onset
        }
        // a clef change inside a measure is printed before the note it applies to
        for change in timeline.clefChanges {
            let m = timeline.measureIndex(atTick: Double(change.tick))
            guard timeline.measures[m].startTick != change.tick else { continue }
            var onset = onsets[m]?[change.tick] ?? Onset()
            onset.left += 2.4 * s
            onsets[m, default: [:]][change.tick] = onset
        }
    }

    /// Room an onset gets before the next one: about 3.4 spaces for a quarter, growing with
    /// the square-ish root of longer values (or the original spacing), never less than the
    /// symbols and names on both sides need.
    private func idealGap(_ ticks: Int) -> CGFloat {
        let q = Double(ticks) / Double(timeline.ticksPerQuarter)
        return s * CGFloat(0.9 + 2.5 * pow(max(q, 0.03), 0.6))
    }

    private mutating func planMeasures() {
        for measure in timeline.measures {
            let table = onsets[measure.index] ?? [:]
            var plan = MeasurePlan()
            plan.ticks = table.keys.sorted()
            guard !plan.ticks.isEmpty else {
                plan.lead = 1.0 * s
                plan.gaps = [max(4 * s, idealGap(measure.lengthTicks))]
                plan.minimumGaps = [3 * s]
                plans.append(plan)
                continue
            }
            let first = table[plan.ticks[0]]!
            plan.lead = 1.0 * s + first.left + (plan.ticks[0] > measure.startTick ? idealGap(plan.ticks[0] - measure.startTick) : 0)
            let xs = plan.ticks.map { table[$0]?.defaultX }
            var useOriginal = measure.widthTenths != nil && xs.allSatisfy { $0 != nil }
            if useOriginal {
                for k in 1..<max(1, xs.count) where xs[k]! <= xs[k - 1]! { useOriginal = false }
                if let last = xs.last!, let width = measure.widthTenths, last >= width { useOriginal = false }
            }
            for (k, tick) in plan.ticks.enumerated() {
                let here = table[tick]!
                let isLast = k + 1 == plan.ticks.count
                let nextTick = isLast ? measure.endTick : plan.ticks[k + 1]
                let next = isLast ? nil : table[nextTick]
                var minimum = here.right + (next?.left ?? 0) + 0.45 * s
                if let next { minimum = max(minimum, here.labelHalf + next.labelHalf + 0.25 * s) }
                if isLast { minimum = max(here.right + 1.0 * s, here.labelHalf + 0.6 * s) }
                var gap = idealGap(nextTick - tick)
                if useOriginal, let x = xs[k] {
                    let nextX = isLast ? measure.widthTenths! : xs[k + 1]!
                    gap = CGFloat(nextX - x) / 10 * s
                }
                plan.gaps.append(max(gap, minimum))
                plan.minimumGaps.append(minimum)
            }
            plans.append(plan)
        }
    }

    private func headerWidth(lineStart m: Int) -> CGFloat {
        let measure = timeline.measures[m]
        let staves = max(1, timeline.staffCount)
        var units: CGFloat = (staves > 1 ? 1.6 : 0.6) + 0.6 + 3.2 + CGFloat(abs(measure.keyFifths)) * 0.95 + 0.4
        if measure.time != nil && (m == 0 || measure.timeChanged) { units += 2.6 }
        return units * s
    }

    /// The clefs in force at the end of measure `m` (changes inside it included).
    private func clefsAtEnd(_ m: Int) -> [ScoreClef] {
        let measure = timeline.measures[m]
        var clefs = measure.clefs
        for change in timeline.clefChanges where change.tick > measure.startTick && change.tick < measure.endTick {
            if change.staff - 1 < clefs.count { clefs[change.staff - 1] = change.clef }
        }
        return clefs
    }

    /// Room for a clef / key / time change at the start of a measure inside a line.
    private func changeWidth(_ m: Int) -> CGFloat {
        guard m > 0 else { return 0 }
        let measure = timeline.measures[m], previous = timeline.measures[m - 1]
        var units: CGFloat = 0
        if measure.clefs != clefsAtEnd(m - 1) { units += 3.0 }
        if measure.keyChanged {
            let shown = measure.keyFifths == 0 ? abs(previous.keyFifths) : abs(measure.keyFifths)
            units += CGFloat(shown) * 0.95 + 0.4
        }
        if measure.timeChanged { units += 2.6 }
        if measure.repeatStart { units += 1.2 }
        return units == 0 ? 0 : (units + 0.6) * s
    }

    /// Width of measures `range` as one line: (ideal, squeezed as far as possible).
    private func lineWidths(_ range: Range<Int>) -> (ideal: CGFloat, minimum: CGFloat) {
        var ideal = headerWidth(lineStart: range.lowerBound), minimum = ideal
        for m in range {
            let extra = lineExtra(m, lineStart: range.lowerBound)
            ideal += plans[m].width + extra
            minimum += plans[m].minimumWidth + extra
        }
        return (ideal, minimum)
    }

    /// Room before measure `m` for changes printed inside a line (or a repeat sign at its start).
    private func lineExtra(_ m: Int, lineStart: Int) -> CGFloat {
        m == lineStart ? (timeline.measures[m].repeatStart ? 1.2 * s : 0) : changeWidth(m)
    }

    /// The original's line breaks when every one of its lines fits; else the breaks that keep
    /// lines evenly full (least squeezing and stretching over the piece).
    private mutating func breakLines() {
        let count = timeline.measures.count
        let available = width - 2 * margin
        var original: [Range<Int>] = []
        var start = 0
        for m in 1..<max(1, count) where timeline.measures[m].startsNewSystem {
            original.append(start..<m)
            start = m
        }
        if count > 0 { original.append(start..<count) }
        if original.count > 1 && original.allSatisfy({ lineWidths($0).minimum <= available }) {
            lines = original
        } else {
            // cost[j]: best way to set measures 0..<j; a line of measures i..<j costs its squeeze
            // or stretch squared (the last line may stay short)
            var cost = [CGFloat](repeating: .infinity, count: count + 1)
            var from = [Int](repeating: 0, count: count + 1)
            cost[0] = 0
            for j in 1...max(1, count) where count > 0 {
                for i in stride(from: j - 1, through: max(0, j - 12), by: -1) {
                    let w = lineWidths(i..<j)
                    if w.minimum > available && j - i > 1 { break }
                    let badness: CGFloat
                    if w.ideal >= available {
                        let squeeze = (w.ideal - available) / max(w.ideal - w.minimum, 1)
                        badness = squeeze * squeeze
                    } else {
                        let stretch = (available - w.ideal) / available
                        badness = j == count ? 0 : stretch * stretch * 3
                    }
                    if cost[i] + badness + 0.01 < cost[j] {
                        cost[j] = cost[i] + badness + 0.01
                        from[j] = i
                    }
                }
            }
            var breaks: [Range<Int>] = []
            var j = count
            while j > 0 {
                breaks.insert(from[j]..<j, at: 0)
                j = from[j]
            }
            lines = breaks
        }
        lineOf = Array(repeating: 0, count: count)
        for (l, line) in lines.enumerated() { for m in line { lineOf[m] = l } }
    }

    /// Justifies every line: the room between notes shrinks toward its minimum, or grows
    /// evenly, until the line is full.
    private mutating func placeHorizontally() {
        measureX = Array(repeating: 0, count: timeline.measures.count)
        measureEndX = measureX
        let available = width - 2 * margin
        for (l, line) in lines.enumerated() {
            let widths = lineWidths(line)
            var squeeze: CGFloat = 0           // 0: ideal gaps, 1: minimum gaps
            var stretch: CGFloat = 1
            if widths.ideal > available {
                squeeze = min(1, (widths.ideal - available) / max(widths.ideal - widths.minimum, 1))
            } else {
                let gaps = line.reduce(CGFloat(0)) { $0 + plans[$1].gaps.reduce(0, +) }
                stretch = gaps > 0 ? 1 + (available - widths.ideal) / gaps : 1
                let isLast = l == lines.count - 1
                if isLast && stretch > 1.6 { stretch = 1 } else if stretch > 2.2 { stretch = 2.2 }
            }

            var x = margin + headerWidth(lineStart: line.lowerBound)
            for m in line {
                measureX[m] = x
                var cursor = x + plans[m].lead + lineExtra(m, lineStart: line.lowerBound)
                var table: [Int: CGFloat] = [:]
                for (k, tick) in plans[m].ticks.enumerated() {
                    table[tick] = cursor
                    let ideal = plans[m].gaps[k], minimum = plans[m].minimumGaps[k]
                    cursor += (ideal - (ideal - minimum) * squeeze) * stretch
                }
                if plans[m].ticks.isEmpty {
                    let ideal = plans[m].gaps.first ?? 4 * s, minimum = plans[m].minimumGaps.first ?? 3 * s
                    cursor += (ideal - (ideal - minimum) * squeeze) * stretch
                }
                onsetX[m] = table
                measureEndX[m] = cursor
                x = cursor
            }
        }
        for c in chords.indices {
            chords[c].x = onsetX[chords[c].measure]?[chords[c].tick] ?? measureX[chords[c].measure] + plans[chords[c].measure].lead
        }
        // grace notes sit before the note they lead into
        var graces: [String: [Int]] = [:]
        for (c, chord) in chords.enumerated() where chord.isGrace {
            graces["\(chord.staff)|\(chord.tick)", default: []].append(c)
        }
        for (_, group) in graces {
            let main = chords.first { !$0.isGrace && $0.staff == chords[group[0]].staff && $0.tick == chords[group[0]].tick }
            let edge = (main?.left ?? 0.8 * s)
            for (k, c) in group.enumerated() {
                chords[c].x -= edge + CGFloat(group.count - k) * 1.2 * s - 0.4 * s
            }
        }
    }

    // MARK: Beams (staff-relative)

    private mutating func beam() {
        var groups: [Int: [Int]] = [:]
        for (c, chord) in chords.enumerated() where chord.hasStem && !chord.isGrace {
            if let group = chord.beamGroup { groups[group, default: []].append(c) }
        }
        for (group, members) in groups {
            let members = members.sorted { chords[$0].x < chords[$1].x }
            guard members.count >= 2, Set(members.map { lineOf[chords[$0].measure] }).count == 1 else { continue }
            beams[group] = members
            let up = chords[members[0]].up
            let first = chords[members[0]], last = chords[members[members.count - 1]]
            let span = max(last.stemX - first.stemX, 1)
            var dy = last.tipY - first.tipY
            dy = max(-min(1.0 * s, 0.25 * span), min(dy, min(1.0 * s, 0.25 * span)))
            let maxFlags = members.map { chords[$0].value.flagCount }.max() ?? 1
            let minimumStem = (2.6 + CGFloat(max(0, maxFlags - 1)) * 0.75) * s
            func lineY(_ x: CGFloat) -> CGFloat { first.tipY + dy * (x - first.stemX) / span }
            var offset: CGFloat = 0
            for c in members {
                let y = lineY(chords[c].stemX)
                offset = up ? min(offset, (chords[c].highY - minimumStem) - y)
                            : max(offset, (chords[c].lowY + minimumStem) - y)
            }
            for c in members { chords[c].tipY = lineY(chords[c].stemX) + offset }
        }
    }

    // MARK: Vertical: systems

    private func labelHeight() -> CGFloat { labelFont.lineHeight * 0.92 }

    /// Staff-relative extent of everything printed with a staff in one line.
    private mutating func extents(line: Range<Int>, staff: Int) -> (top: CGFloat, bottom: CGFloat) {
        var top: CGFloat = -1.2 * s
        var bottom: CGFloat = 5.2 * s
        let notes = timeline.notes
        for m in line {
            for c in chordsByMeasure[m] ?? [] where chords[c].staff == staff {
                let chord = chords[c]
                let tipTop = chord.hasStem && chord.up ? chord.tipY - 0.3 * s : chord.highY - 0.6 * s
                let tipBottom = chord.hasStem && !chord.up ? chord.tipY + 0.3 * s : chord.lowY + 0.6 * s
                var t = min(chord.highY - 0.6 * s, tipTop)
                var b = max(chord.lowY + 0.6 * s, tipBottom)
                let marks = chord.notes.contains { !notes[$0].articulations.isEmpty || notes[$0].hasFermata }
                if marks { t -= 1.4 * s; b += 1.2 * s }
                if chord.isGrace { top = min(top, t); bottom = max(bottom, b); continue }
                // the names go in a row under the staff (lower when the chord reaches below it)
                let named = chord.notes.filter { notes[$0].isStruck }.count
                if named > 0 {
                    let row = max(4 * s + 1.9 * s, b + 0.4 * s)
                    labelRows[c] = row
                    b = row + CGFloat(named) * labelHeight()
                }
                top = min(top, t)
                bottom = max(bottom, b)
            }
        }
        return (top, bottom)
    }

    private mutating func placeSystems() {
        let staves = max(1, timeline.staffCount)
        var y: CGFloat = 0.6 * s
        for line in lines {
            var tops: [CGFloat] = []
            var aboveFirst: CGFloat = 0
            // marks above the top staff: tempo / text, endings, octave lines
            let first = timeline.measures[line.lowerBound].startTick, end = timeline.measures[line.upperBound - 1].endTick
            let marks = timeline.directions.filter { $0.tick >= first && $0.tick < end }
            if marks.contains(where: { d in
                switch d.kind { case .words, .metronome, .segno, .coda: return d.staff == 1 || d.above; default: return false }
            }) { aboveFirst += 1.8 * s }
            if line.contains(where: { !timeline.measures[$0].endingNumbers.isEmpty }) { aboveFirst += 2.2 * s }
            if marks.contains(where: { if case .octaveShift(_, true, _) = $0.kind { return $0.staff == 1 } else { return false } }) {
                aboveFirst += 1.8 * s
            }
            let dynamicsBelow = marks.filter {
                switch $0.kind { case .dynamic, .wedge: return true; default: return false }
            }
            var previousBottom: CGFloat = 0
            for staff in 1...staves {
                var e = extents(line: line, staff: staff)
                if dynamicsBelow.contains(where: { $0.staff == staff }) { e.bottom += 2.2 * s }
                if staff == 1 {
                    tops.append(y - e.top + aboveFirst)
                } else {
                    let previousTop = tops[staff - 2]
                    let gap = max(previousTop + 4 * s + 3.0 * s, previousTop + previousBottom - e.top + 0.5 * s)
                    tops.append(gap)
                }
                previousBottom = e.bottom
            }
            let bottom = (tops.last ?? y) + previousBottom + 0.4 * s
            let lastMeasure = line.upperBound - 1
            systems.append(SheetSystem(measures: line, top: y, bottom: bottom, staffTops: tops,
                                       left: margin + (staves > 1 ? 1.6 * s : 0.6 * s), right: measureEndX[lastMeasure]))
            // chords: staff-relative → page
            for m in line {
                for c in chordsByMeasure[m] ?? [] {
                    let dy = tops[min(chords[c].staff, tops.count) - 1]
                    chords[c].baseY += dy
                    chords[c].tipY += dy
                    chords[c].highY += dy
                    chords[c].lowY += dy
                    for (i, v) in chords[c].y { chords[c].y[i] = v + dy }
                    if let row = labelRows[c] { labelRows[c] = row + dy }
                }
            }
            y = bottom + 1.0 * s
        }
    }

    private func staffTop(line: Int, staff: Int) -> CGFloat {
        let tops = systems[line].staffTops
        return tops[min(max(staff, 1), tops.count) - 1]
    }

    /// x of a tick, kept inside the line of `line`.
    private func x(_ tick: Double, line: Int) -> CGFloat {
        let range = lines[line]
        let m = min(max(timeline.measureIndex(atTick: tick), range.lowerBound), range.upperBound - 1)
        if tick >= Double(timeline.measures[range.upperBound - 1].endTick) { return measureEndX[range.upperBound - 1] }
        if tick < Double(timeline.measures[range.lowerBound].startTick) { return measureX[range.lowerBound] }
        let measure = timeline.measures[m]
        var points: [(Double, CGFloat)] = [(Double(measure.startTick), measureX[m] + plans[m].lead)]
        for (t, x) in (onsetX[m] ?? [:]).sorted(by: { $0.key < $1.key }) {
            if t == measure.startTick { points[0] = (Double(t), x) } else { points.append((Double(t), x)) }
        }
        points.append((Double(measure.endTick), measureEndX[m]))
        for k in 1..<points.count where tick <= points[k].0 {
            let a = points[k - 1], b = points[k]
            let f = b.0 > a.0 ? CGFloat((tick - a.0) / (b.0 - a.0)) : 1
            return a.1 + (b.1 - a.1) * f
        }
        return measureEndX[m]
    }

    // MARK: Drawing: systems, barlines, headers

    private mutating func drawSystems() {
        let staves = max(1, timeline.staffCount)
        let numberFont = UIFont.systemFont(ofSize: max(6, 0.75 * s), weight: .medium)
        for (l, line) in lines.enumerated() {
            let system = systems[l]
            let first = line.lowerBound
            let path = inkPath(first)
            let top = system.staffTops[0], bottom = system.staffTops[staves - 1] + 4 * s
            for t in system.staffTops {
                for i in 0..<5 {
                    lineLayers.append(SheetGlyphs.line(x: system.left, y: t + CGFloat(i) * s, width: system.right - system.left, s: s))
                }
            }
            if staves > 1 {
                SheetGlyphs.addBrace(path, x: system.left - 1.3 * s, top: top, bottom: bottom, s: s)
            }
            path.addRect(CGRect(x: system.left, y: top, width: stemWidth, height: bottom - top))

            // clefs, key and (where it starts or changes) the time signature
            let measure = timeline.measures[first]
            let x = system.left + 0.5 * s
            for (k, t) in system.staffTops.enumerated() {
                let clef = k < measure.clefs.count ? measure.clefs[k] : (k == 0 ? .treble : .bass)
                textLayers.append(SheetGlyphs.clefLayer(clef, x: x, staffTop: t, s: s, color: ink, scale: scale))
                SheetGlyphs.addKeySignature(path, fifths: measure.keyFifths, previous: 0, clef: clef,
                                            x: x + 3.2 * s, staffTop: t, s: s)
                if let time = measure.time, first == 0 || measure.timeChanged {
                    let tx = x + 3.2 * s + CGFloat(abs(measure.keyFifths)) * 0.95 * s + 1.5 * s
                    textLayers += SheetGlyphs.timeLayers(time, centerX: tx, staffTop: t, s: s, color: ink, scale: scale)
                }
            }
            textLayers.append(SheetGlyphs.textLayer(measure.number, font: numberFont, color: .tertiaryLabel,
                                                    centerX: system.left + 0.6 * s, centerY: top - 1.4 * s, scale: scale))

            for m in line {
                drawBarlines(m, line: l, top: top, bottom: bottom)
                if m != first { drawChanges(m, line: l) }
                drawEnding(m, line: l)
            }
        }
    }

    private mutating func drawBarlines(_ m: Int, line: Int, top: CGFloat, bottom: CGFloat) {
        let measure = timeline.measures[m]
        let path = inkPath(m)
        let h = bottom - top
        let thin = stemWidth, thick = 0.5 * s
        let tops = systems[line].staffTops
        func dots(at x: CGFloat) {
            for t in tops {
                for dy in [1.5 * s, 2.5 * s] {
                    path.addEllipse(in: CGRect(x: x - 0.22 * s, y: t + dy - 0.22 * s, width: 0.44 * s, height: 0.44 * s))
                }
            }
        }
        if measure.repeatStart {
            let x = measureX[m] + (m == lines[line].lowerBound ? 0.1 * s : changeWidth(m) - 1.4 * s)
            path.addRect(CGRect(x: x, y: top, width: thick, height: h))
            path.addRect(CGRect(x: x + thick + 0.3 * s, y: top, width: thin, height: h))
            dots(at: x + thick + 0.9 * s)
        }
        let end = measureEndX[m]
        let isLast = m == timeline.measures.count - 1
        if measure.repeatEnd {
            dots(at: end - thick - 0.9 * s)
            path.addRect(CGRect(x: end - thick - 0.3 * s - thin, y: top, width: thin, height: h))
            path.addRect(CGRect(x: end - thick, y: top, width: thick, height: h))
        } else if measure.rightBarStyle == "light-heavy" || isLast {
            path.addRect(CGRect(x: end - thick - 0.3 * s - thin, y: top, width: thin, height: h))
            path.addRect(CGRect(x: end - thick, y: top, width: thick, height: h))
        } else if measure.rightBarStyle == "light-light" {
            path.addRect(CGRect(x: end - 0.4 * s - thin, y: top, width: thin, height: h))
            path.addRect(CGRect(x: end - thin, y: top, width: thin, height: h))
        } else {
            path.addRect(CGRect(x: end - thin, y: top, width: thin, height: h))
        }
    }

    /// Clef / key / time printed where they change inside a line.
    private mutating func drawChanges(_ m: Int, line: Int) {
        guard changeWidth(m) > 0 else { return }
        let measure = timeline.measures[m], previous = timeline.measures[m - 1]
        let path = inkPath(m)
        var x = measureX[m] + 0.5 * s
        let tops = systems[line].staffTops
        let before = clefsAtEnd(m - 1)
        if measure.clefs != before {
            for (k, clef) in measure.clefs.enumerated() where k < tops.count && (k >= before.count || before[k] != clef) {
                textLayers.append(SheetGlyphs.clefLayer(clef, x: x, staffTop: tops[k], s: s * 0.8, color: ink, scale: scale))
            }
            x += 3.0 * s
        }
        if measure.keyChanged {
            for (k, t) in tops.enumerated() {
                let clef = k < measure.clefs.count ? measure.clefs[k] : .treble
                SheetGlyphs.addKeySignature(path, fifths: measure.keyFifths, previous: previous.keyFifths,
                                            clef: clef, x: x, staffTop: t, s: s)
            }
            let shown = measure.keyFifths == 0 ? abs(previous.keyFifths) : abs(measure.keyFifths)
            x += CGFloat(shown) * 0.95 * s + 0.4 * s
        }
        if measure.timeChanged, let time = measure.time {
            for t in tops {
                textLayers += SheetGlyphs.timeLayers(time, centerX: x + 1.2 * s, staffTop: t, s: s, color: ink, scale: scale)
            }
        }
    }

    /// 1st / 2nd ending brackets over the top staff.
    private mutating func drawEnding(_ m: Int, line: Int) {
        let measure = timeline.measures[m]
        guard !measure.endingNumbers.isEmpty else { return }
        let path = inkPath(m)
        let y = systems[line].top + 0.8 * s
        let left = measureX[m] + 0.3 * s
        let right = measureEndX[m] - 0.4 * s
        path.addRect(CGRect(x: left, y: y, width: right - left, height: stemWidth))
        let starts = measure.endingStarts || m == lines[line].lowerBound
        if measure.endingStarts { path.addRect(CGRect(x: left, y: y, width: stemWidth, height: 1.6 * s)) }
        if measure.endingClosed { path.addRect(CGRect(x: right - stemWidth, y: y, width: stemWidth, height: 1.6 * s)) }
        if starts, let text = measure.endingText {
            let font = UIFont.systemFont(ofSize: 1.1 * s, weight: .semibold)
            let label = SheetGlyphs.textLayer(text, font: font, color: ink, centerX: left + 0.5 * s + labelWidth(text) / 2,
                                              centerY: y + 0.9 * s, scale: scale)
            textLayers.append(label)
        }
    }

    /// A clef change inside a measure, printed small just before the notes it applies to.
    private mutating func drawClefChanges() {
        for change in timeline.clefChanges {
            let m = timeline.measureIndex(atTick: Double(change.tick))
            guard timeline.measures[m].startTick != change.tick, m < lineOf.count else { continue }
            let line = lineOf[m]
            guard change.staff <= systems[line].staffTops.count else { continue }
            let x = onsetX[m]?[change.tick] ?? self.x(Double(change.tick), line: line)
            let left = chords.filter { $0.measure == m && $0.tick == change.tick && !$0.isGrace }.map(\.left).max() ?? 0.8 * s
            textLayers.append(SheetGlyphs.clefLayer(change.clef, x: x - left - 2.5 * s,
                                                    staffTop: staffTop(line: line, staff: change.staff),
                                                    s: s * 0.75, color: ink, scale: scale))
        }
    }

    // MARK: Drawing: chords

    private mutating func drawChord(_ c: Int) {
        let chord = chords[c]
        let notes = timeline.notes
        let path = inkPath(chord.measure)
        let hs = s * chord.scale
        let headWidth = SheetGlyphs.headWidth(chord.value, s: hs)
        let line = lineOf[chord.measure]
        let top = staffTop(line: line, staff: chord.staff)
        let bottomLine = timeline.notes[chord.notes[0]].clef.bottomLineDiatonic

        // ledger lines
        let positions = chord.notes.compactMap { notes[$0].displayDiatonic }
        let dxs = chord.notes.compactMap { chord.headDX[$0] }
        let ledgerLeft = chord.x + (dxs.min() ?? 0) - headWidth * 0.8
        let ledgerRight = chord.x + (dxs.max() ?? 0) + headWidth * 0.8
        var ledgers: [Int] = []
        if let low = positions.min(), low <= bottomLine - 2 { ledgers += stride(from: bottomLine - 2, through: low, by: -2) }
        if let high = positions.max(), high >= bottomLine + 10 { ledgers += stride(from: bottomLine + 10, through: high, by: 2) }
        for d in ledgers {
            let y = top + 4 * s - CGFloat(d - bottomLine) * s / 2
            path.addRect(CGRect(x: ledgerLeft, y: y - 0.07 * s, width: ledgerRight - ledgerLeft, height: max(0.8, 0.14 * s)))
        }

        // stem, flags, grace slash
        if chord.hasStem {
            let y0 = min(chord.baseY, chord.tipY), y1 = max(chord.baseY, chord.tipY)
            path.addRect(CGRect(x: chord.stemX - stemWidth / 2, y: y0, width: stemWidth, height: y1 - y0))
            if (chord.beamGroup == nil || chord.isGrace || !isBeamed(c)) && chord.value.flagCount > 0 {
                SheetGlyphs.addFlags(path, stemX: chord.stemX, tipY: chord.tipY, count: chord.value.flagCount, up: chord.up, s: hs)
            }
            if chord.isGrace && chord.value.flagCount == 1 {
                let slash = CGMutablePath()
                slash.move(to: CGPoint(x: chord.stemX - 0.6 * hs, y: chord.tipY + 1.9 * hs))
                slash.addLine(to: CGPoint(x: chord.stemX + 0.9 * hs, y: chord.tipY + 0.7 * hs))
                path.addPath(slash.copy(strokingWithWidth: 0.12 * hs, lineCap: .round, lineJoin: .round, miterLimit: 4))
            }
        }
        if !chord.isGrace { drawBeamIfFirst(c) }
        drawArticulations(chord, path: path, staffTop: top)

        let rightmost = chord.x + (dxs.max() ?? 0) + headWidth / 2
        let named = chord.isGrace ? [] : chord.notes.reversed().filter { notes[$0].isStruck }
        let step = labelHeight()
        for i in chord.notes {
            let note = notes[i]
            let x = chord.x + (chord.headDX[i] ?? 0)
            let y = chord.y[i] ?? top
            let glyph = CGMutablePath()
            SheetGlyphs.addHead(glyph, center: CGPoint(x: x, y: y), value: chord.value, s: hs)
            if let accidental = note.accidental, let ax = chord.accidentalDX[i] {
                SheetGlyphs.addAccidental(glyph, accidental, centerX: chord.x + ax, centerY: y, s: hs)
            }
            if note.dots > 0 {
                let onLine = ((note.displayDiatonic ?? 0) - bottomLine) % 2 == 0
                let dotY = onLine ? y - 0.5 * s : y
                for k in 0..<note.dots {
                    let dx = rightmost + 0.45 * hs + CGFloat(k) * 0.5 * hs
                    glyph.addEllipse(in: CGRect(x: dx - 0.2 * hs, y: dotY - 0.2 * hs, width: 0.4 * hs, height: 0.4 * hs))
                }
            }
            if chord.isGrace {
                path.addPath(glyph)
                continue
            }

            let head = CAShapeLayer()
            head.path = glyph
            head.fillColor = ink.cgColor
            headLayers.append(head)

            let hand = note.isLeftHand ? AnimatedPianoKeyView.leftColor : AnimatedPianoKeyView.rightColor
            let heldEnd = note.startTick + Int(Double(note.soundingTicks) * min(1, note.heldFraction ?? 1))
            var bar: CALayer?
            if note.isStruck {
                let end = min(self.x(Double(heldEnd), line: line), systems[line].right) - 0.4 * s
                if end > x + headWidth * 0.9 {
                    let b = CALayer()
                    b.frame = CGRect(x: x, y: y - 0.3 * s, width: end - x, height: 0.6 * s)
                    b.cornerRadius = 0.3 * s
                    b.backgroundColor = hand.withAlphaComponent(0.14).cgColor
                    barLayers.append(b)
                    bar = b
                }
            }

            var label: CATextLayer?
            if let k = named.firstIndex(of: i), let name = note.writtenName, let row = labelRows[c] {
                let l = SheetGlyphs.textLayer(name, font: labelFont, color: hand.withAlphaComponent(0.85),
                                              centerX: chord.x, centerY: row + step / 2 + CGFloat(k) * step, scale: scale)
                textLayers.append(l)
                label = l
            }

            let end = note.isStruck ? max(heldEnd, note.startTick + 1) : max(note.endTick, note.startTick + 1)
            visuals.append(SheetNoteVisual(start: Double(note.startTick), end: Double(end),
                                           isLeft: note.isLeftHand, head: head, bar: bar, label: label))
        }
    }

    private func isBeamed(_ c: Int) -> Bool {
        chords[c].beamGroup.map { beams[$0] != nil } ?? false
    }

    /// Primary beam through the outer stems, then shorter values' beams between neighbours.
    private mutating func drawBeamIfFirst(_ c: Int) {
        guard let group = chords[c].beamGroup, !drawnBeams.contains(group), let members = beams[group] else { return }
        drawnBeams.insert(group)
        let first = chords[members[0]], last = chords[members[members.count - 1]]
        let up = first.up
        let span = max(last.stemX - first.stemX, 1)
        func lineY(_ x: CGFloat) -> CGFloat { first.tipY + (last.tipY - first.tipY) * (x - first.stemX) / span }
        let thickness = 0.48 * s
        let toward: CGFloat = up ? 1 : -1
        let path = inkPath(first.measure)
        func addBeam(from a: CGFloat, to b: CGFloat, level: Int) {
            let shift = CGFloat(level - 1) * (thickness + 0.25 * s) * toward
            let ya = lineY(a) + shift, yb = lineY(b) + shift
            let t = thickness * toward
            path.move(to: CGPoint(x: a, y: ya))
            path.addLine(to: CGPoint(x: b, y: yb))
            path.addLine(to: CGPoint(x: b, y: yb + t))
            path.addLine(to: CGPoint(x: a, y: ya + t))
            path.closeSubpath()
        }
        let edge = stemWidth / 2
        addBeam(from: first.stemX - edge, to: last.stemX + edge, level: 1)
        let maxFlags = members.map { chords[$0].value.flagCount }.max() ?? 1
        guard maxFlags >= 2 else { return }
        for level in 2...maxFlags {
            for (k, m) in members.enumerated() where chords[m].value.flagCount >= level {
                let x = chords[m].stemX
                if k + 1 < members.count && chords[members[k + 1]].value.flagCount >= level {
                    addBeam(from: x - edge, to: chords[members[k + 1]].stemX + edge, level: level)
                } else if k == 0 || chords[members[k - 1]].value.flagCount < level {
                    let stub = 1.1 * s
                    if k + 1 < members.count {
                        addBeam(from: x - edge, to: x + stub, level: level)
                    } else {
                        addBeam(from: x - stub, to: x + edge, level: level)
                    }
                }
            }
        }
    }

    /// Staccato, tenuto and accents on the head side away from the stem; fermatas above.
    private func drawArticulations(_ chord: Chord, path: CGMutablePath, staffTop: CGFloat) {
        let notes = timeline.notes
        var marks = Set<ScoreNote.Articulation>()
        var fermata = false
        for i in chord.notes { marks.formUnion(notes[i].articulations); fermata = fermata || notes[i].hasFermata }
        if fermata {
            let y = min(chord.highY, chord.hasStem && chord.up ? chord.tipY : chord.highY, staffTop) - 1.2 * s
            SheetGlyphs.addFermata(path, centerX: chord.x, baseY: y, s: s)
        }
        guard !marks.isEmpty else { return }
        let below = chord.up && chord.hasStem
        var y = below ? chord.lowY + 1.0 * s : chord.highY - 1.0 * s
        func clearOfLines(_ y: CGFloat) -> CGFloat {
            let rel = (y - staffTop) / s
            guard rel > -0.1, rel < 4.1, abs(rel - rel.rounded()) < 0.25 else { return y }
            return y + (below ? 0.5 : -0.5) * s
        }
        let step: CGFloat = (below ? 1 : -1) * 0.9 * s
        if marks.contains(.staccato) || marks.contains(.staccatissimo) || marks.contains(.spiccato) || marks.contains(.detachedLegato) {
            y = clearOfLines(y)
            let r = (marks.contains(.staccatissimo) ? 0.16 : 0.2) * s
            path.addEllipse(in: CGRect(x: chord.x - r, y: y - r, width: 2 * r, height: 2 * r))
            y += step
        }
        if marks.contains(.tenuto) || marks.contains(.detachedLegato) {
            y = clearOfLines(y)
            path.addRect(CGRect(x: chord.x - 0.6 * s, y: y - 0.07 * s, width: 1.2 * s, height: 0.14 * s))
            y += step
        }
        if marks.contains(.accent) {
            SheetGlyphs.addAccent(path, centerX: chord.x, centerY: y + (below ? 0.2 : -0.2) * s, s: s)
        } else if marks.contains(.strongAccent) {
            SheetGlyphs.addMarcato(path, centerX: chord.x, centerY: y + (below ? 0.3 : -0.3) * s, up: !below, s: s)
        }
    }

    // MARK: Drawing: rests, ties, slurs, tuplets

    private mutating func drawRests() {
        let notes = timeline.notes
        var byMeasureStaff: [String: [Int]] = [:]
        for (i, n) in notes.enumerated() where !n.isRest && !n.isGrace {
            byMeasureStaff["\(n.measureIndex)|\(n.staff)", default: []].append(i)
        }
        for note in notes where note.isRest && !note.isGrace && note.isPrinted {
            let line = lineOf[note.measureIndex]
            let top = staffTop(line: line, staff: note.staff)
            var centerY = top + 2 * s
            // notes sounding in the same staff while the rest lasts
            let overlapping = (byMeasureStaff["\(note.measureIndex)|\(note.staff)"] ?? []).filter {
                notes[$0].startTick < note.endTick && notes[$0].endTick > note.startTick
            }
            if overlapping.contains(where: { notes[$0].voice == note.voice }) { continue }   // contradicts its voice (OMR)
            if let d = note.restDiatonic {
                centerY = top + 4 * s - CGFloat(d - note.clef.bottomLineDiatonic) * s / 2
            } else if !overlapping.isEmpty {
                // the other voice is above the middle line: the rest goes below, and the other way round
                let middle = note.clef.bottomLineDiatonic + 4
                let average = overlapping.compactMap { notes[$0].displayDiatonic }.reduce(0, +) / max(1, overlapping.count)
                centerY += (average >= middle ? 2.5 : -2.5) * s
            }
            let x: CGFloat
            let value: NoteValue
            if note.isMeasureRest {
                x = (measureX[note.measureIndex] + plans[note.measureIndex].lead + measureEndX[note.measureIndex]) / 2 - 0.5 * s
                value = .whole
            } else {
                x = onsetX[note.measureIndex]?[note.startTick] ?? self.x(Double(note.startTick), line: line)
                value = note.value
            }
            let path = inkPath(note.measureIndex)
            SheetGlyphs.addRest(path, value: value, x: x, centerY: centerY, s: s)
            if !note.isMeasureRest {
                for k in 0..<note.dots {
                    let dx = x + 0.9 * s + CGFloat(k) * 0.5 * s
                    path.addEllipse(in: CGRect(x: dx - 0.2 * s, y: centerY - 0.7 * s, width: 0.4 * s, height: 0.4 * s))
                }
            }
            if note.hasFermata {
                SheetGlyphs.addFermata(path, centerX: x, baseY: top - 1.2 * s, s: s)
            }
        }
    }

    /// Head position and stem side of every printed note.
    private func headSpots() -> [Int: (x: CGFloat, y: CGFloat, up: Bool, width: CGFloat, chord: Int)] {
        var spots: [Int: (x: CGFloat, y: CGFloat, up: Bool, width: CGFloat, chord: Int)] = [:]
        for (c, chord) in chords.enumerated() where !chord.isGrace {
            for i in chord.notes {
                spots[i] = (chord.x + (chord.headDX[i] ?? 0), chord.y[i] ?? 0, chord.up || !chord.hasStem,
                            SheetGlyphs.headWidth(chord.value, s: s), c)
            }
        }
        return spots
    }

    /// A curve from one note to another; across lines, a half curve on each line.
    private mutating func addCurve(from a: (x: CGFloat, y: CGFloat), measureA: Int, to b: (x: CGFloat, y: CGFloat),
                                   measureB: Int, below: Bool, slur: Bool) {
        let la = lineOf[measureA], lb = lineOf[measureB]
        let lift: CGFloat = slur ? 1.0 : 0.55
        let d: CGFloat = below ? 1 : -1
        if la == lb {
            SheetGlyphs.addTie(inkPath(measureA), from: CGPoint(x: a.x, y: a.y + d * lift * s),
                               to: CGPoint(x: b.x, y: b.y + d * lift * s), below: below, s: s, tall: slur)
        } else {
            let end = systems[la].right - 0.3 * s
            SheetGlyphs.addTie(inkPath(measureA), from: CGPoint(x: a.x, y: a.y + d * lift * s),
                               to: CGPoint(x: end, y: a.y + d * lift * s), below: below, s: s, tall: slur)
            let start = measureX[lines[lb].lowerBound] + headerWidth(lineStart: lines[lb].lowerBound) - 0.5 * s
            SheetGlyphs.addTie(inkPath(measureB), from: CGPoint(x: start, y: b.y + d * lift * s),
                               to: CGPoint(x: b.x, y: b.y + d * lift * s), below: below, s: s, tall: slur)
        }
    }

    private mutating func drawTies() {
        let notes = timeline.notes
        let spots = headSpots()
        var stops: [String: [Int]] = [:]
        for (i, n) in notes.enumerated() where n.tieStop && !n.isRest {
            if let midi = n.midi { stops["\(midi)|\(n.staff)", default: []].append(i) }
        }
        let tolerance = timeline.ticksPerQuarter / 8
        for (i, n) in notes.enumerated() where n.tieStart && !n.isRest && !n.isGrace {
            guard let midi = n.midi, let a = spots[i] else { continue }
            let partner = stops["\(midi)|\(n.staff)"]?.first { abs(notes[$0].startTick - n.endTick) <= tolerance }
            let from = (x: a.x + a.width * 0.45, y: a.y)
            if let j = partner, let b = spots[j] {
                addCurve(from: from, measureA: n.measureIndex, to: (x: b.x - b.width * 0.45, y: b.y),
                         measureB: notes[j].measureIndex, below: a.up, slur: false)
            } else {
                addCurve(from: from, measureA: n.measureIndex, to: (x: from.x + 2 * s, y: a.y),
                         measureB: n.measureIndex, below: a.up, slur: false)
            }
        }
    }

    private mutating func drawSlurs() {
        let notes = timeline.notes
        let spots = headSpots()
        for slur in timeline.slurs {
            guard let a = spots[slur.from], let b = spots[slur.to] else { continue }
            let below = slur.above.map { !$0 } ?? a.up
            let chordA = chords[a.chord], chordB = chords[b.chord]
            // start and end clear of the heads on the curve's side
            let ya = below ? chordA.lowY : chordA.highY
            let yb = below ? chordB.lowY : chordB.highY
            addCurve(from: (x: a.x, y: ya), measureA: notes[slur.from].measureIndex, to: (x: b.x, y: yb),
                     measureB: notes[slur.to].measureIndex, below: below, slur: true)
        }
    }

    private mutating func drawTuplets() {
        let notes = timeline.notes
        let spots = headSpots()
        for tuplet in timeline.tuplets {
            let members = tuplet.notes
            guard let firstIndex = members.first, let lastIndex = members.last else { continue }
            let line = lineOf[notes[firstIndex].measureIndex]
            guard lineOf[notes[lastIndex].measureIndex] == line else { continue }
            let xs = members.map { spots[$0]?.x ?? x(Double(notes[$0].startTick), line: line) }
            let staffTopY = staffTop(line: line, staff: notes[firstIndex].staff)
            let memberChords = members.compactMap { spots[$0]?.chord }.map { chords[$0] }
            let up = tuplet.above ?? (memberChords.first?.up ?? true)
            let y: CGFloat
            if up {
                y = min(memberChords.map { $0.hasStem && $0.up ? $0.tipY : $0.highY }.min() ?? staffTopY, staffTopY) - 1.0 * s
            } else {
                y = max(memberChords.map { $0.hasStem && !$0.up ? $0.tipY : $0.lowY }.max() ?? staffTopY + 4 * s, staffTopY + 4 * s) + 1.0 * s
            }
            let left = (xs.min() ?? 0) - 0.4 * s, right = (xs.max() ?? 0) + 0.4 * s
            let center = (left + right) / 2
            let font = UIFont(name: "TimesNewRomanPS-BoldItalicMT", size: 1.4 * s) ?? .italicSystemFont(ofSize: 1.4 * s)
            textLayers.append(SheetGlyphs.textLayer("\(tuplet.actual)", font: font, color: ink, centerX: center, centerY: y, scale: scale))
            let beamed = memberChords.count == members.count && Set(memberChords.compactMap(\.beamGroup)).count == 1
                && memberChords.allSatisfy { $0.beamGroup != nil }
            if tuplet.bracket ?? !beamed {
                let path = inkPath(notes[firstIndex].measureIndex)
                let gap = 0.9 * s
                let hook: CGFloat = (up ? 1 : -1) * 0.6 * s
                path.addRect(CGRect(x: left, y: y - 0.05 * s, width: center - gap - left, height: 0.1 * s))
                path.addRect(CGRect(x: center + gap, y: y - 0.05 * s, width: right - center - gap, height: 0.1 * s))
                path.addRect(CGRect(x: left, y: min(y, y + hook), width: 0.1 * s, height: abs(hook)))
                path.addRect(CGRect(x: right - 0.1 * s, y: min(y, y + hook), width: 0.1 * s, height: abs(hook)))
            }
        }
    }

    // MARK: Drawing: dynamics, hairpins, text, tempo, octave lines

    private mutating func drawDirections() {
        let notes = timeline.notes
        let staves = max(1, timeline.staffCount)
        let dynamicFont = UIFont(name: "TimesNewRomanPS-BoldItalicMT", size: 1.7 * s) ?? .boldSystemFont(ofSize: 1.7 * s)
        let wordsFont = UIFont(name: "TimesNewRomanPS-ItalicMT", size: 1.3 * s) ?? .italicSystemFont(ofSize: 1.3 * s)
        let tempoFont = UIFont.systemFont(ofSize: 1.2 * s, weight: .bold)
        // the lane under a staff's note names, and the space over the top staff
        func belowLane(line: Int, staff: Int) -> CGFloat {
            let top = staffTop(line: line, staff: staff)
            var lowest = top + 5.4 * s
            for m in lines[line] {
                for c in chordsByMeasure[m] ?? [] where chords[c].staff == staff {
                    let named = chords[c].notes.filter { notes[$0].isStruck }.count
                    if let row = labelRows[c] { lowest = max(lowest, row + CGFloat(named) * labelHeight()) }
                    lowest = max(lowest, chords[c].lowY + 0.8 * s, chords[c].hasStem && !chords[c].up ? chords[c].tipY + 0.4 * s : 0)
                }
            }
            return lowest + 1.0 * s
        }
        func aboveLane(line: Int) -> CGFloat {
            systems[line].top + (lines[line].contains { !timeline.measures[$0].endingNumbers.isEmpty } ? 3.2 : 1.0) * s
        }
        for direction in timeline.directions {
            let m = timeline.measureIndex(atTick: Double(direction.tick))
            guard m < lineOf.count else { continue }
            let line = lineOf[m]
            let staff = min(max(direction.staff, 1), staves)
            let x = self.x(Double(direction.tick), line: line)
            let path = inkPath(m)
            switch direction.kind {
            case .dynamic(let mark):
                let y = belowLane(line: line, staff: staff)
                textLayers.append(SheetGlyphs.textLayer(mark, font: dynamicFont, color: ink, centerX: x + 0.6 * s, centerY: y, scale: scale))
            case .wedge(let crescendo, let endTick):
                let y = belowLane(line: line, staff: staff)
                let endLine = lineOf[min(timeline.measureIndex(atTick: Double(endTick)), lineOf.count - 1)]
                let end = endLine == line ? self.x(Double(endTick), line: line) : systems[line].right - 0.5 * s
                if end - x > 1.5 * s {
                    SheetGlyphs.addHairpin(path, from: x, to: end, centerY: y, crescendo: crescendo, s: s)
                }
            case .words(let text):
                let y = direction.above || staff == 1 ? aboveLane(line: line) : belowLane(line: line, staff: staff)
                let width = (text as NSString).size(withAttributes: [.font: wordsFont]).width
                textLayers.append(SheetGlyphs.textLayer(text, font: wordsFont, color: ink, centerX: x + width / 2, centerY: y, scale: scale))
            case .metronome(let beat, let dots, let perMinute):
                let symbol: String
                switch beat {
                case .half:   symbol = "𝅗𝅥"
                case .eighth: symbol = "♪"
                default:      symbol = "♩"
                }
                let text = "\(symbol)\(dots > 0 ? "." : "") = \(String(format: "%g", perMinute))"
                let width = (text as NSString).size(withAttributes: [.font: tempoFont]).width
                // after the tempo words printed at the same place ("Alla marcia  ♩ = 108")
                var after: CGFloat = 0
                for other in timeline.directions where other.tick == direction.tick {
                    if case .words(let words) = other.kind {
                        after = max(after, (words as NSString).size(withAttributes: [.font: wordsFont]).width + 0.8 * s)
                    }
                }
                textLayers.append(SheetGlyphs.textLayer(text, font: tempoFont, color: ink, centerX: x + after + width / 2,
                                                        centerY: aboveLane(line: line), scale: scale))
            case .octaveShift(let size, let down, let endTick):
                let label = size >= 15 ? (down ? "15ma" : "15mb") : (down ? "8va" : "8vb")
                let top = staffTop(line: line, staff: staff)
                let y = down ? min(top - 2.0 * s, aboveLane(line: line) + 1.6 * s) : belowLane(line: line, staff: staff)
                let font = UIFont(name: "TimesNewRomanPS-BoldItalicMT", size: 1.3 * s) ?? .italicSystemFont(ofSize: 1.3 * s)
                let width = (label as NSString).size(withAttributes: [.font: font]).width
                textLayers.append(SheetGlyphs.textLayer(label, font: font, color: ink, centerX: x + width / 2, centerY: y, scale: scale))
                let endLine = lineOf[min(timeline.measureIndex(atTick: Double(endTick)), lineOf.count - 1)]
                let end = endLine == line ? self.x(Double(endTick), line: line) + 0.8 * s : systems[line].right - 0.3 * s
                var dash = x + width + 0.4 * s
                while dash < end - 0.4 * s {
                    path.addRect(CGRect(x: dash, y: y - 0.05 * s, width: min(0.6 * s, end - dash), height: 0.1 * s))
                    dash += 1.1 * s
                }
                path.addRect(CGRect(x: end - 0.1 * s, y: down ? y : y - 0.8 * s, width: 0.1 * s, height: 0.8 * s))
            case .segno:
                textLayers.append(SheetGlyphs.textLayer("𝄋", font: .systemFont(ofSize: 2 * s), color: ink, centerX: x,
                                                        centerY: aboveLane(line: line), scale: scale))
            case .coda:
                textLayers.append(SheetGlyphs.textLayer("𝄌", font: .systemFont(ofSize: 2 * s), color: ink, centerX: x,
                                                        centerY: aboveLane(line: line), scale: scale))
            }
        }
    }
}

// MARK: - Glyphs
//
// Notation symbols as paths, sized in staff spaces (`s`). All are filled shapes so a measure's
// ink can share one path.

private enum SheetGlyphs {
    static func line(x: CGFloat, y: CGFloat, width: CGFloat, s: CGFloat) -> CALayer {
        let line = CALayer()
        line.backgroundColor = UIColor(white: 0.12, alpha: 0.55).cgColor
        let h = max(0.6, 0.08 * s)
        line.frame = CGRect(x: x, y: y - h / 2, width: width, height: h)
        return line
    }

    static func headWidth(_ value: NoteValue, s: CGFloat) -> CGFloat {
        value <= .whole ? 1.56 * s : 1.3 * s
    }

    /// Whole notes: wide and open; half notes: open and tilted; shorter: filled and tilted.
    /// Holes wind the other way so a non-zero fill leaves them open.
    static func addHead(_ path: CGMutablePath, center c: CGPoint, value: NoteValue, s: CGFloat) {
        let move = CGAffineTransform(translationX: c.x, y: c.y)
        func oval(_ w: CGFloat, _ h: CGFloat, angle: CGFloat, reversed: Bool = false) {
            let p = UIBezierPath(ovalIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
            p.apply(CGAffineTransform(rotationAngle: angle))
            path.addPath((reversed ? p.reversing() : p).cgPath, transform: move)
        }
        if value <= .whole {
            oval(1.56 * s, 1.0 * s, angle: 0)
            oval(0.72 * s, 0.52 * s, angle: 0.6, reversed: true)
        } else if value == .half {
            oval(1.3 * s, 0.92 * s, angle: -0.35)
            oval(1.0 * s, 0.42 * s, angle: -0.6, reversed: true)
        } else {
            oval(1.3 * s, 0.92 * s, angle: -0.35)
        }
    }

    static func addFlags(_ path: CGMutablePath, stemX x: CGFloat, tipY: CGFloat, count: Int, up: Bool, s: CGFloat) {
        let d: CGFloat = up ? 1 : -1
        for k in 0..<count {
            let y = tipY + d * CGFloat(k) * 0.8 * s
            path.move(to: CGPoint(x: x, y: y))
            path.addCurve(to: CGPoint(x: x + 0.95 * s, y: y + d * 2.3 * s),
                          control1: CGPoint(x: x + 0.1 * s, y: y + d * 1.0 * s),
                          control2: CGPoint(x: x + 1.25 * s, y: y + d * 1.25 * s))
            path.addCurve(to: CGPoint(x: x, y: y + d * 0.9 * s),
                          control1: CGPoint(x: x + 0.85 * s, y: y + d * 1.55 * s),
                          control2: CGPoint(x: x + 0.3 * s, y: y + d * 1.2 * s))
            path.closeSubpath()
        }
    }

    // MARK: Accidentals

    static func accidentalWidth(_ a: ScoreNote.Accidental, s: CGFloat) -> CGFloat {
        switch a {
        case .sharp:       return 1.0 * s
        case .flat:        return 0.8 * s
        case .natural:     return 0.75 * s
        case .doubleSharp: return 0.9 * s
        case .doubleFlat:  return 1.5 * s
        }
    }

    /// How far the glyph reaches above and below its centre.
    static func accidentalExtent(_ a: ScoreNote.Accidental, s: CGFloat) -> (above: CGFloat, below: CGFloat) {
        switch a {
        case .sharp, .natural:    return (1.35 * s, 1.35 * s)
        case .flat, .doubleFlat:  return (1.75 * s, 0.55 * s)
        case .doubleSharp:        return (0.5 * s, 0.5 * s)
        }
    }

    static func addAccidental(_ path: CGMutablePath, _ a: ScoreNote.Accidental, centerX cx: CGFloat,
                              centerY cy: CGFloat, s: CGFloat) {
        func bar(_ left: CGFloat, _ right: CGFloat, _ yc: CGFloat, thickness t: CGFloat) {
            let rise = 0.12 * s
            path.move(to: CGPoint(x: left, y: yc + rise - t / 2))
            path.addLine(to: CGPoint(x: right, y: yc - rise - t / 2))
            path.addLine(to: CGPoint(x: right, y: yc - rise + t / 2))
            path.addLine(to: CGPoint(x: left, y: yc + rise + t / 2))
            path.closeSubpath()
        }
        func flat(at x0: CGFloat) {
            path.addRect(CGRect(x: x0 - 0.06 * s, y: cy - 1.75 * s, width: 0.12 * s, height: 2.25 * s))
            path.move(to: CGPoint(x: x0, y: cy + 0.5 * s))
            path.addCurve(to: CGPoint(x: x0 + 0.62 * s, y: cy - 0.18 * s),
                          control1: CGPoint(x: x0 + 0.35 * s, y: cy + 0.3 * s),
                          control2: CGPoint(x: x0 + 0.62 * s, y: cy + 0.05 * s))
            path.addCurve(to: CGPoint(x: x0, y: cy - 0.2 * s),
                          control1: CGPoint(x: x0 + 0.62 * s, y: cy - 0.5 * s),
                          control2: CGPoint(x: x0 + 0.2 * s, y: cy - 0.48 * s))
            path.addLine(to: CGPoint(x: x0, y: cy - 0.02 * s))
            path.addCurve(to: CGPoint(x: x0 + 0.38 * s, y: cy - 0.12 * s),
                          control1: CGPoint(x: x0 + 0.15 * s, y: cy - 0.25 * s),
                          control2: CGPoint(x: x0 + 0.38 * s, y: cy - 0.28 * s))
            path.addCurve(to: CGPoint(x: x0, y: cy + 0.32 * s),
                          control1: CGPoint(x: x0 + 0.38 * s, y: cy + 0.05 * s),
                          control2: CGPoint(x: x0 + 0.2 * s, y: cy + 0.2 * s))
            path.closeSubpath()
        }
        switch a {
        case .sharp:
            path.addRect(CGRect(x: cx - 0.3 * s, y: cy - 1.2 * s, width: 0.12 * s, height: 2.5 * s))
            path.addRect(CGRect(x: cx + 0.18 * s, y: cy - 1.35 * s, width: 0.12 * s, height: 2.5 * s))
            bar(cx - 0.5 * s, cx + 0.5 * s, cy - 0.45 * s, thickness: 0.26 * s)
            bar(cx - 0.5 * s, cx + 0.5 * s, cy + 0.45 * s, thickness: 0.26 * s)
        case .flat:
            flat(at: cx - 0.3 * s)
        case .doubleFlat:
            flat(at: cx - 0.65 * s)
            flat(at: cx + 0.1 * s)
        case .natural:
            path.addRect(CGRect(x: cx - 0.31 * s, y: cy - 1.25 * s, width: 0.12 * s, height: 1.8 * s))
            path.addRect(CGRect(x: cx + 0.19 * s, y: cy - 0.55 * s, width: 0.12 * s, height: 1.8 * s))
            bar(cx - 0.31 * s, cx + 0.31 * s, cy - 0.3 * s, thickness: 0.24 * s)
            bar(cx - 0.31 * s, cx + 0.31 * s, cy + 0.3 * s, thickness: 0.24 * s)
        case .doubleSharp:
            let x = CGMutablePath()
            x.move(to: CGPoint(x: cx - 0.38 * s, y: cy - 0.38 * s))
            x.addLine(to: CGPoint(x: cx + 0.38 * s, y: cy + 0.38 * s))
            x.move(to: CGPoint(x: cx - 0.38 * s, y: cy + 0.38 * s))
            x.addLine(to: CGPoint(x: cx + 0.38 * s, y: cy - 0.38 * s))
            path.addPath(x.copy(strokingWithWidth: 0.24 * s, lineCap: .square, lineJoin: .miter, miterLimit: 4))
        }
    }

    // MARK: Articulations

    static func addAccent(_ path: CGMutablePath, centerX x: CGFloat, centerY y: CGFloat, s: CGFloat) {
        let a = CGMutablePath()
        a.move(to: CGPoint(x: x - 0.7 * s, y: y - 0.4 * s))
        a.addLine(to: CGPoint(x: x + 0.7 * s, y: y))
        a.addLine(to: CGPoint(x: x - 0.7 * s, y: y + 0.4 * s))
        path.addPath(a.copy(strokingWithWidth: 0.14 * s, lineCap: .round, lineJoin: .miter, miterLimit: 6))
    }

    static func addMarcato(_ path: CGMutablePath, centerX x: CGFloat, centerY y: CGFloat, up: Bool, s: CGFloat) {
        let d: CGFloat = up ? -1 : 1
        path.move(to: CGPoint(x: x - 0.5 * s, y: y - d * 0.45 * s))
        path.addLine(to: CGPoint(x: x, y: y + d * 0.55 * s))
        path.addLine(to: CGPoint(x: x + 0.5 * s, y: y - d * 0.45 * s))
        path.addLine(to: CGPoint(x: x + 0.25 * s, y: y - d * 0.45 * s))
        path.addLine(to: CGPoint(x: x, y: y + d * 0.05 * s))
        path.closeSubpath()
    }

    /// An arc with a dot under it; `baseY` is the bottom of the arc.
    static func addFermata(_ path: CGMutablePath, centerX x: CGFloat, baseY y: CGFloat, s: CGFloat) {
        path.move(to: CGPoint(x: x - 1.1 * s, y: y))
        path.addCurve(to: CGPoint(x: x + 1.1 * s, y: y), control1: CGPoint(x: x - 1.0 * s, y: y - 1.5 * s),
                      control2: CGPoint(x: x + 1.0 * s, y: y - 1.5 * s))
        path.addCurve(to: CGPoint(x: x - 1.1 * s, y: y), control1: CGPoint(x: x + 0.9 * s, y: y - 1.2 * s),
                      control2: CGPoint(x: x - 0.9 * s, y: y - 1.2 * s))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: x - 0.2 * s, y: y - 0.45 * s, width: 0.4 * s, height: 0.4 * s))
    }

    static func addHairpin(_ path: CGMutablePath, from a: CGFloat, to b: CGFloat, centerY y: CGFloat,
                           crescendo: Bool, s: CGFloat) {
        let open = 0.6 * s
        let p = CGMutablePath()
        let narrow = crescendo ? a : b, wide = crescendo ? b : a
        p.move(to: CGPoint(x: wide, y: y - open))
        p.addLine(to: CGPoint(x: narrow, y: y))
        p.addLine(to: CGPoint(x: wide, y: y + open))
        path.addPath(p.copy(strokingWithWidth: 0.1 * s, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
    }

    // MARK: Rests

    /// `centerY` is the staff's middle line (or the rest's display position).
    static func addRest(_ path: CGMutablePath, value: NoteValue, x: CGFloat, centerY c: CGFloat, s: CGFloat) {
        switch value {
        case .breve, .whole:
            path.addRect(CGRect(x: x - 0.6 * s, y: c - 1.0 * s, width: 1.2 * s, height: 0.5 * s))
        case .half:
            path.addRect(CGRect(x: x - 0.6 * s, y: c - 0.5 * s, width: 1.2 * s, height: 0.5 * s))
        case .quarter:
            let z = CGMutablePath()
            z.move(to: CGPoint(x: x - 0.15 * s, y: c - 1.5 * s))
            z.addLine(to: CGPoint(x: x + 0.4 * s, y: c - 0.75 * s))
            z.addLine(to: CGPoint(x: x - 0.15 * s, y: c - 0.05 * s))
            z.addLine(to: CGPoint(x: x + 0.4 * s, y: c + 0.6 * s))
            z.addQuadCurve(to: CGPoint(x: x + 0.05 * s, y: c + 1.45 * s),
                           control: CGPoint(x: x - 0.65 * s, y: c + 0.55 * s))
            path.addPath(z.copy(strokingWithWidth: 0.3 * s, lineCap: .round, lineJoin: .round, miterLimit: 4))
        default:
            let flags = value.flagCount
            let topY = c - 0.75 * s
            let bottomY = c + 0.75 * s + CGFloat(flags - 1) * 1.0 * s
            let topX = x + 0.45 * s + CGFloat(flags - 1) * 0.2 * s
            let bottomX = x - 0.1 * s
            func stemX(_ y: CGFloat) -> CGFloat { topX + (bottomX - topX) * (y - topY) / (bottomY - topY) }
            let stroke = CGMutablePath()
            stroke.move(to: CGPoint(x: topX, y: topY))
            stroke.addLine(to: CGPoint(x: bottomX, y: bottomY))
            for k in 0..<flags {
                let dotY = topY + 0.2 * s + CGFloat(k) * 1.0 * s
                let dotX = stemX(dotY) - 0.75 * s
                path.addEllipse(in: CGRect(x: dotX - 0.27 * s, y: dotY - 0.27 * s, width: 0.54 * s, height: 0.54 * s))
                stroke.move(to: CGPoint(x: dotX, y: dotY + 0.2 * s))
                stroke.addQuadCurve(to: CGPoint(x: stemX(dotY - 0.05 * s), y: dotY - 0.05 * s),
                                    control: CGPoint(x: dotX + 0.45 * s, y: dotY + 0.4 * s))
            }
            path.addPath(stroke.copy(strokingWithWidth: 0.13 * s, lineCap: .round, lineJoin: .round, miterLimit: 4))
        }
    }

    // MARK: Ties, slurs, brace

    /// A tie (flat) or slur (`tall`) from `a` to `b`, bowing down when `below`.
    static func addTie(_ path: CGMutablePath, from a: CGPoint, to b: CGPoint, below: Bool, s: CGFloat, tall: Bool = false) {
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length > 0.3 * s else { return }
        let d: CGFloat = below ? 1 : -1
        let height = tall ? min(2.2 * s, max(0.7 * s, length * 0.1)) : min(1.0 * s, max(0.45 * s, length * 0.12))
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        path.move(to: a)
        path.addQuadCurve(to: b, control: CGPoint(x: mid.x, y: mid.y + d * height * 2))
        path.addQuadCurve(to: a, control: CGPoint(x: mid.x, y: mid.y + d * (height - 0.16 * s) * 2))
        path.closeSubpath()
    }

    static func addBrace(_ path: CGMutablePath, x: CGFloat, top: CGFloat, bottom: CGFloat, s: CGFloat) {
        let w = 0.9 * s, h = bottom - top, mid = (top + bottom) / 2
        let b = CGMutablePath()
        b.move(to: CGPoint(x: x + w, y: top))
        b.addCurve(to: CGPoint(x: x, y: mid), control1: CGPoint(x: x + 0.1 * w, y: top + 0.15 * h),
                   control2: CGPoint(x: x + 0.9 * w, y: mid - 0.2 * h))
        b.addCurve(to: CGPoint(x: x + w, y: bottom), control1: CGPoint(x: x + 0.9 * w, y: mid + 0.2 * h),
                   control2: CGPoint(x: x + 0.1 * w, y: bottom - 0.15 * h))
        path.addPath(b.copy(strokingWithWidth: 0.24 * s, lineCap: .round, lineJoin: .round, miterLimit: 4))
    }

    // MARK: Clefs, keys, time signatures

    static func clefLayer(_ clef: ScoreClef, x: CGFloat, staffTop top: CGFloat, s: CGFloat,
                          color: UIColor, scale: CGFloat) -> CATextLayer {
        let layer = CATextLayer()
        layer.contentsScale = scale
        layer.alignmentMode = .center
        layer.foregroundColor = color.cgColor
        let staffHeight = 4 * s
        switch clef.sign {
        case "F":
            layer.string = "𝄢"
            layer.fontSize = staffHeight * 0.68
            layer.frame = CGRect(x: x + 0.15 * s, y: top + 0.08 * s - CGFloat(clef.line - 4) * s,
                                 width: 3 * s, height: staffHeight - 0.17 * s)
        case "C":
            layer.string = "𝄡"
            layer.fontSize = staffHeight * 0.95
            layer.frame = CGRect(x: x, y: top - 0.55 * s - CGFloat(clef.line - 3) * s,
                                 width: 3 * s, height: staffHeight + 1.2 * s)
        default:
            layer.string = "𝄞"
            layer.fontSize = staffHeight + 0.5 * s
            layer.frame = CGRect(x: x, y: top - 0.67 * s - CGFloat(clef.line - 2) * s,
                                 width: 3.2 * s, height: staffHeight + 1.5 * s)
        }
        return layer
    }

    /// The key's sharps or flats from `x`; a change to C major prints naturals for the old key.
    static func addKeySignature(_ path: CGMutablePath, fifths: Int, previous: Int, clef: ScoreClef,
                                x: CGFloat, staffTop top: CGFloat, s: CGFloat) {
        let sharps = [38, 35, 39, 36, 33, 37, 34]       // F5 C5 G5 D5 A4 E5 B4 on a treble staff
        let flats = [34, 37, 33, 36, 32, 35, 31]        // B4 E5 A4 D5 G4 C5 F4
        let shift = Int((Double(clef.bottomLineDiatonic - 30) / 7).rounded()) * 7
        let glyph: ScoreNote.Accidental
        let positions: [Int]
        if fifths == 0 {
            guard previous != 0 else { return }
            glyph = .natural
            positions = Array((previous > 0 ? sharps : flats).prefix(abs(previous)))
        } else {
            glyph = fifths > 0 ? .sharp : .flat
            positions = Array((fifths > 0 ? sharps : flats).prefix(min(7, abs(fifths))))
        }
        for (k, d) in positions.enumerated() {
            let y = top + 4 * s - CGFloat(d + shift - clef.bottomLineDiatonic) * s / 2
            addAccidental(path, glyph, centerX: x + 0.5 * s + CGFloat(k) * 0.95 * s, centerY: y, s: s)
        }
    }

    static func timeLayers(_ time: ScoreTimeSignature, centerX: CGFloat, staffTop top: CGFloat, s: CGFloat,
                           color: UIColor, scale: CGFloat) -> [CATextLayer] {
        let font = UIFont.systemFont(ofSize: 2.8 * s, weight: .heavy)
        return [
            textLayer("\(time.beats)", font: font, color: color, centerX: centerX, centerY: top + s, scale: scale),
            textLayer("\(time.beatType)", font: font, color: color, centerX: centerX, centerY: top + 3 * s, scale: scale)
        ]
    }

    /// Text whose capital letters are centred on `centerY`.
    static func textLayer(_ string: String, font: UIFont, color: UIColor, centerX: CGFloat, centerY: CGFloat,
                          scale: CGFloat) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = string
        layer.font = font
        layer.fontSize = font.pointSize
        layer.foregroundColor = color.cgColor
        layer.alignmentMode = .center
        layer.contentsScale = scale
        let width = ceil((string as NSString).size(withAttributes: [.font: font]).width) + 4
        let height = ceil(font.lineHeight) + 2
        layer.frame = CGRect(x: centerX - width / 2, y: centerY - font.ascender + font.capHeight / 2,
                             width: width, height: height)
        return layer
    }
}

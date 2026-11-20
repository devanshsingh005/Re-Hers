//
//  PracticeTipsView.swift
//  Re-Hearse_v1
//
//  Tips for practising one piece, worked out from its score: the hardest bars (to loop), the
//  key's sharps or flats, the metre, the tempo, both hands, fast runs, dotted rhythms, triplets,
//  ties, stray accidentals, chords, dynamics, staccato, repeats, range. The card shows the most
//  useful few, each as an icon, a title and one line.
//

import UIKit

struct PracticeTip: Equatable, Sendable {
    /// SF Symbol name.
    let icon: String
    let title: String
    let detail: String
}

nonisolated enum PracticeTips {
    /// The most useful tips for `timeline`, best first (at most `limit`).
    static func tips(for timeline: ScoreTimeline, limit: Int = 4) -> [PracticeTip] {
        var found: [(priority: Int, tip: PracticeTip)] = []
        func add(_ priority: Int, _ icon: String, _ title: String, _ detail: String) {
            found.append((priority, PracticeTip(icon: icon, title: title, detail: detail)))
        }
        let measures = timeline.measures
        let struck = timeline.notes.filter(\.isStruck)
        guard !measures.isEmpty, !struck.isEmpty else { return [general] }

        func bar(_ m: Int) -> String {
            let number = measures[m].number.trimmingCharacters(in: .whitespaces)
            return number.isEmpty ? String(m + 1) : number
        }
        func bars(_ list: [Int]) -> String {
            let sorted = Array(Set(list)).sorted()
            guard let first = sorted.first, let last = sorted.last else { return "" }
            // most of the piece: naming bars says nothing
            if sorted.count >= 4, Double(sorted.count) >= Double(measures.count) * 0.6 { return "throughout the piece" }
            if sorted.count > 3 { return "bars \(bar(first))–\(bar(last))" }
            if sorted.count == 1 { return "bar \(bar(first))" }
            return "bars " + sorted.map(bar).joined(separator: ", ")
        }
        let quarter = Double(max(1, timeline.ticksPerQuarter))

        // key signature
        let fifths = measures[0].keyFifths
        if fifths != 0 {
            let names = fifths > 0 ? ["F♯", "C♯", "G♯", "D♯", "A♯", "E♯", "B♯"] : ["B♭", "E♭", "A♭", "D♭", "G♭", "C♭", "F♭"]
            let marks = Array(names.prefix(min(7, abs(fifths))))
            let kind = fifths > 0 ? (marks.count == 1 ? "sharp" : "sharps") : (marks.count == 1 ? "flat" : "flats")
            let detail = marks.count == 1
                ? "Play every \(marks[0].prefix(1)) as \(marks[0]), in every octave."
                : "Play these all the way through, in every octave."
            add(70, fifths > 0 ? "number" : "music.note", "\(marks.count) \(kind): \(marks.joined(separator: " "))", detail)
        }
        if let change = measures.dropFirst().first(where: \.keyChanged) {
            add(62, "arrow.triangle.swap", "Key change in bar \(bar(change.index))",
                "The sharps and flats change from there: look before you play.")
        }

        // metre
        let signatures = timeline.effectiveTimeSignatures()
        let time = signatures[0]
        switch (time.beats, time.beatType) {
        case (3, 4): add(50, "metronome", "3/4 time", "Count 1-2-3 and lean on the 1.")
        case (6, 8): add(50, "metronome", "6/8 time", "Feel two beats, each split in three: 1-2-3, 4-5-6.")
        case (2, 4): add(40, "metronome", "2/4 time", "Count 1-2: a steady, march-like pulse.")
        case (2, 2): add(40, "metronome", "Cut time", "Feel two half-note beats in each bar.")
        default: break
        }
        if let i = signatures.indices.dropFirst().first(where: { signatures[$0] != signatures[$0 - 1] }) {
            let from = signatures[i - 1], to = signatures[i]
            add(64, "metronome", "Time changes in bar \(bar(i))",
                "From \(from.beats)/\(from.beatType) to \(to.beats)/\(to.beatType): count the new beats.")
        }

        // tempo
        if let bpm = timeline.tempos.first?.bpm {
            let shown = Int(bpm.rounded())
            if bpm >= 120 {
                let start = max(60, Int((bpm * 0.65 / 5).rounded()) * 5)
                add(60, "gauge.with.dots.needle.67percent", "Fast tempo: ♩ = \(shown)",
                    "Start around ♩ = \(start) with the metronome, then speed up.")
            } else if bpm <= 66 {
                add(38, "gauge.with.dots.needle.33percent", "Slow tempo: ♩ = \(shown)",
                    "Hold each long note for its full value.")
            }
        }

        // hands
        let left = struck.filter(\.isLeftHand), right = struck.filter { !$0.isLeftHand }
        if !left.isEmpty, !right.isEmpty {
            add(55, "hands.sparkles", "Both hands", "Practise each hand alone first (L / R in Play Along).")
        }

        // rhythm
        let fast = struck.filter { $0.value >= .sixteenth }
        let eighths = struck.filter { $0.value == .eighth }
        if Double(fast.count) >= Double(struck.count) * 0.15, fast.count >= 4 {
            add(75, "hare", "Fast sixteenth notes", "\(bars(fast.map(\.measureIndex)).capitalizedFirst): keep them even, slowly at first.")
        } else if Double(eighths.count) >= Double(struck.count) * 0.4 {
            add(34, "music.note.list", "Lots of eighth notes", "Count “1-and-2-and” to keep them even.")
        }
        let dotted = struck.filter { $0.dots > 0 }
        if Double(dotted.count) >= Double(struck.count) * 0.1, dotted.count >= 2 {
            add(45, "smallcircle.filled.circle", "Dotted rhythms", "Hold the dotted note longer, then a quick short one.")
        }
        let triplets = struck.filter { $0.tuplet?.actual == 3 }
        if triplets.count >= 3 {
            add(55, "3.circle", "Triplets", "\(bars(triplets.map(\.measureIndex)).capitalizedFirst): three even notes per beat.")
        }
        if timeline.notes.filter(\.tieStart).count >= 2 {
            add(40, "link", "Tied notes", "Hold through the tie; don't strike the second note again.")
        }

        // accidentals outside the key
        let keyAlter = keyAlterations(fifths: fifths)
        let stray = struck.filter { note in
            guard let step = note.step else { return false }
            return note.alter != (keyAlter[step] ?? 0)
        }
        if stray.count >= 3 {
            add(58, "exclamationmark.triangle", "Extra sharps and flats",
                "Watch the accidentals in \(bars(stray.map(\.measureIndex))).")
        }

        // chords in one hand
        func chordCount(_ notes: [ScoreNote]) -> Int {
            Dictionary(grouping: notes, by: \.startTick).values.filter { $0.count >= 2 }.count
        }
        if chordCount(left) >= 3 {
            add(46, "pianokeys", "Left-hand chords", "Press the chord notes together, evenly.")
        } else if chordCount(right) >= 3 {
            add(44, "pianokeys", "Right-hand chords", "Press the chord notes together, evenly.")
        }

        // markings
        var dynamics: [String] = []
        for direction in timeline.directions {
            if case .dynamic(let mark) = direction.kind, dynamics.last != mark { dynamics.append(mark) }
        }
        if Set(dynamics).count >= 2 {
            add(30, "speaker.wave.2", "Dynamics: \(dynamics.prefix(3).joined(separator: " → "))",
                "Play softly at p and strongly at f: shape the sound.")
        }
        if struck.filter({ $0.articulations.contains(.staccato) }).count >= 3 {
            add(35, "circle.grid.2x1", "Staccato", "Short, detached notes where there's a dot.")
        }
        if measures.contains(where: \.repeatEnd) {
            add(25, "repeat", "Repeats", "Some bars are played twice: follow the ending numbers.")
        }
        if struck.contains(where: \.hasFermata) {
            add(20, "pause.circle", "Fermata", "Hold the notes under ⌒ longer than written.")
        }
        let midis = struck.compactMap(\.midi)
        if let low = midis.min(), let high = midis.max(), high - low >= 36 {
            add(28, "arrow.left.and.right", "Wide range",
                "From \(PianoPitchAnalyzer.name(of: low)) to \(PianoPitchAnalyzer.name(of: high)): move your hand early.")
        }

        // the hardest bars: most notes per beat (plus stray accidentals), to loop
        if measures.count >= 4 {
            var score = [Double](repeating: 0, count: measures.count)
            for (m, notes) in Dictionary(grouping: struck, by: \.measureIndex) {
                let beats = max(1, Double(measures[m].lengthTicks) / quarter)
                score[m] = Double(Set(notes.map(\.startTick)).count) / beats
            }
            for note in stray { score[note.measureIndex] += 0.3 }
            let sorted = score.sorted()
            let median = sorted[sorted.count / 2]
            if let top = score.indices.max(by: { score[$0] < score[$1] }), score[top] >= max(1.5 * median, median + 0.75) {
                var range = [top]
                if top + 1 < score.count, score[top + 1] >= 0.8 * score[top] { range.append(top + 1) }
                else if top > 0, score[top - 1] >= 0.8 * score[top] { range.insert(top - 1, at: 0) }
                let label = range.count == 1 ? "bar \(bar(range[0]))" : "bars \(bar(range[0]))–\(bar(range[1]))"
                add(90, "flame", "Hardest spot: \(label)", "Loop it with A–B and play it slowly first.")
            }
        }

        if found.count < 2 { found.append((0, general)) }
        return found.sorted { $0.priority > $1.priority }.prefix(limit).map(\.tip)
    }

    static let general = PracticeTip(icon: "hand.raised", title: "Relaxed hands",
                                     detail: "Keep your wrists loose and fingers curved.")

    /// Each step's alteration in the key with `fifths` sharps (or flats when negative).
    static func keyAlterations(fifths: Int) -> [String: Int] {
        var alter: [String: Int] = [:]
        if fifths > 0 { for step in ["F", "C", "G", "D", "A", "E", "B"].prefix(min(7, fifths)) { alter[step] = 1 } }
        if fifths < 0 { for step in ["B", "E", "A", "D", "G", "C", "F"].prefix(min(7, -fifths)) { alter[step] = -1 } }
        return alter
    }
}

private extension String {
    nonisolated var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - The card

/// "Tips for this piece": a card of rows, each an icon in a tinted tile, a title and a line.
final class PracticeTipsView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let rows = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ComponentColors.SongDetailScreen.sheetMusicCardFill
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous

        titleLabel.text = "Tips for this piece"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        subtitleLabel.text = "From your sheet"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel

        rows.axis = .vertical
        rows.spacing = 0
        let header = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        header.axis = .vertical
        header.spacing = 2
        let stack = UIStackView(arrangedSubviews: [header, rows])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTips(_ tips: [PracticeTip]) {
        subtitleLabel.text = "From your sheet"
        subtitleLabel.isHidden = false
        show(tips)
    }

    /// One row instead of tips: while the sheet is read, or when it can't be.
    func setMessage(icon: String, title: String, detail: String) {
        subtitleLabel.isHidden = true
        show([PracticeTip(icon: icon, title: title, detail: detail)])
    }

    private func show(_ tips: [PracticeTip]) {
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, tip) in tips.enumerated() {
            if i > 0 {
                let line = UIView()
                line.backgroundColor = UIColor.separator
                line.heightAnchor.constraint(equalToConstant: 1 / max(1, traitCollection.displayScale)).isActive = true
                let inset = UIStackView(arrangedSubviews: [line])
                inset.isLayoutMarginsRelativeArrangement = true
                inset.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 48, bottom: 0, trailing: 0)
                rows.addArrangedSubview(inset)
            }
            rows.addArrangedSubview(row(tip))
        }
    }

    private func row(_ tip: PracticeTip) -> UIView {
        let tile = UIView()
        tile.backgroundColor = BrandColors.brand.withAlphaComponent(0.16)
        tile.layer.cornerRadius = 10
        tile.layer.cornerCurve = .continuous
        let icon = UIImageView(image: UIImage(systemName: tip.icon) ?? UIImage(systemName: "lightbulb"))
        icon.tintColor = BrandColors.brand
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(icon)
        tile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 36),
            tile.heightAnchor.constraint(equalToConstant: 36),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
        ])

        let title = UILabel()
        title.text = tip.title
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .label
        title.numberOfLines = 0
        let detail = UILabel()
        detail.text = tip.detail
        detail.font = .systemFont(ofSize: 14)
        detail.textColor = .secondaryLabel
        detail.numberOfLines = 0
        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 2

        let row = UIStackView(arrangedSubviews: [tile, text])
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(tip.title). \(tip.detail)"
        return row
    }
}

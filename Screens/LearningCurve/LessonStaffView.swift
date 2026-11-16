//
//  LessonStaffView.swift
//  Re-Hearse_v1
//
//  The staff on a Practice lesson: a treble clef and the part's notes, drawn with the same
//  glyphs as the Animation sheet (filled heads, stems, accidentals, ledger lines) at their
//  real pitch. Play sounds them on the piano, chord by chord, lighting each one as it plays.
//

import UIKit

final class LessonStaffView: UIView {

    private let steps: [PracticeStep]
    /// Staff space (distance between two lines).
    private let s: CGFloat = 10
    private var stepLayers: [[CAShapeLayer]] = []
    private var drawnSize: CGSize = .zero
    private var playbackItems: [DispatchWorkItem] = []
    private let playButton = UIButton(type: .system)

    private var ink: UIColor { ComponentColors.LessonScreen.labelPrimary.resolvedColor(with: traitCollection) }
    private var lineColor: UIColor { ink.withAlphaComponent(0.45) }
    private var highlight: UIColor { BrandColors.brand.resolvedColor(with: traitCollection) }

    init(steps: [PracticeStep]) {
        self.steps = steps
        super.init(frame: .zero)
        backgroundColor = .clear
        isAccessibilityElement = false

        var config = UIButton.Configuration.filled()
        config.title = "Play"
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.baseBackgroundColor = BrandColors.brand
        config.baseForegroundColor = .white
        config.buttonSize = .small
        playButton.configuration = config
        playButton.accessibilityLabel = "Play " + steps.map(\.label).joined(separator: ", ")
        playButton.addAction(UIAction { [weak self] _ in self?.play() }, for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playButton)
        NSLayoutConstraint.activate([
            playButton.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            playButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(play)))

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.drawnSize = .zero
            self.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        playbackItems.forEach { $0.cancel() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != drawnSize, bounds.width > 0 else { return }
        drawnSize = bounds.size
        redraw()
    }

    // MARK: - Drawing

    private func redraw() {
        layer.sublayers?.filter { !($0.delegate is UIView) }.forEach { $0.removeFromSuperlayer() }
        stepLayers = []
        let scale = window?.screen.scale ?? traitCollection.displayScale

        let left: CGFloat = 20, right = bounds.width - 20
        let labelSpace: CGFloat = steps.count > 1 ? 20 : 0
        // centre the staff; leave room for ledger notes and stems
        let staffTop = (bounds.height - 4 * s) / 2 + 6 - labelSpace / 2
        let bottomLine = staffTop + 4 * s
        let bottomDiatonic = ScoreClef.treble.bottomLineDiatonic   // E4

        for i in 0..<5 {
            let y = staffTop + CGFloat(i) * s
            let line = CALayer()
            line.frame = CGRect(x: left, y: y - 0.5, width: right - left, height: 1)
            line.backgroundColor = lineColor.cgColor
            layer.addSublayer(line)
        }
        layer.addSublayer(trebleClef(x: left + 2, staffTop: staffTop, scale: scale))

        let headWidth = SheetGlyphs.headWidth(.quarter, s: s)
        let firstX = left + 6.5 * s
        let lastX = right - 2.5 * s
        let xs: [CGFloat] = steps.count == 1
            ? [(firstX + lastX) / 2]
            : (0..<steps.count).map { firstX + (lastX - firstX) * CGFloat($0) / CGFloat(steps.count - 1) }

        for (index, step) in steps.enumerated() {
            let x = xs[index]
            let positions = step.pitches.map { $0.diatonic - bottomDiatonic }   // 0 = bottom line
            func y(_ p: Int) -> CGFloat { bottomLine - CGFloat(p) * s / 2 }

            let ledger = CGMutablePath()
            if let low = positions.min(), low <= -2 {
                for p in stride(from: -2, through: low, by: -2) {
                    ledger.addRect(CGRect(x: x - headWidth * 0.85, y: y(p) - 0.6, width: headWidth * 1.7, height: 1.2))
                }
            }
            if let high = positions.max(), high >= 10 {
                for p in stride(from: 10, through: high, by: 2) {
                    ledger.addRect(CGRect(x: x - headWidth * 0.85, y: y(p) - 0.6, width: headWidth * 1.7, height: 1.2))
                }
            }

            // stem: up when the notes sit mostly below the middle line
            let up = Double(positions.reduce(0, +)) / Double(max(1, positions.count)) < 4
            let lowY = y(positions.min() ?? 0), highY = y(positions.max() ?? 0)
            let stemX = up ? x + headWidth / 2 - 0.55 : x - headWidth / 2 + 0.55
            let stem = up
                ? CGRect(x: stemX - 0.55, y: highY - 3.5 * s, width: 1.1, height: lowY - highY + 3.5 * s)
                : CGRect(x: stemX - 0.55, y: highY, width: 1.1, height: lowY - highY + 3.5 * s)
            ledger.addRect(stem)

            let fixed = CAShapeLayer()
            fixed.path = ledger
            fixed.fillColor = ink.cgColor
            layer.addSublayer(fixed)

            // heads and accidentals, which light up while playing
            var headLayers: [CAShapeLayer] = []
            var accidentalColumns: [[Int]] = []
            for (pitch, p) in zip(step.pitches, positions).sorted(by: { $0.1 > $1.1 }) {
                let glyph = CGMutablePath()
                SheetGlyphs.addHead(glyph, center: CGPoint(x: x, y: y(p)), value: .quarter, s: s)
                if let accidental = Self.accidental(pitch.alter) {
                    // stagger accidentals that would collide (within a sixth)
                    var column = 0
                    while column < accidentalColumns.count,
                          accidentalColumns[column].contains(where: { abs($0 - p) < 6 }) { column += 1 }
                    if column == accidentalColumns.count { accidentalColumns.append([]) }
                    accidentalColumns[column].append(p)
                    let ax = x - headWidth / 2 - 0.95 * s - CGFloat(column) * 1.15 * s
                    SheetGlyphs.addAccidental(glyph, accidental, centerX: ax, centerY: y(p), s: s)
                }
                let head = CAShapeLayer()
                head.path = glyph
                head.fillColor = ink.cgColor
                layer.addSublayer(head)
                headLayers.append(head)
            }
            stepLayers.append(headLayers)

            if steps.count > 1 {
                let label = SheetGlyphs.textLayer(step.label, font: .systemFont(ofSize: 13, weight: .semibold),
                                                  color: ink.withAlphaComponent(0.75), centerX: x,
                                                  centerY: bounds.height - 18, scale: scale)
                layer.addSublayer(label)
            }
        }
        bringSubviewToFront(playButton)
    }

    /// A treble clef spanning the staff, its curl round the G line.
    private func trebleClef(x: CGFloat, staffTop: CGFloat, scale: CGFloat) -> CATextLayer {
        let size = 8.6 * s
        let font = UIFont(name: "AppleSymbols", size: size) ?? .systemFont(ofSize: size)
        let clef = CATextLayer()
        clef.contentsScale = scale
        clef.string = NSAttributedString(string: "𝄞", attributes: [.font: font, .foregroundColor: ink])
        // baseline a little under the bottom line, so the tail hangs below and the top rises above
        clef.frame = CGRect(x: x - 0.3 * s, y: staffTop + 4 * s + 0.9 * s - font.ascender, width: 5 * s, height: font.lineHeight)
        return clef
    }

    private static func accidental(_ alter: Int) -> ScoreNote.Accidental? {
        switch alter {
        case 1: return .sharp
        case -1: return .flat
        case 2: return .doubleSharp
        case -2: return .doubleFlat
        default: return nil
        }
    }

    // MARK: - Playback

    /// Plays each step on the piano (chords together, a progression one chord at a time).
    @objc func play() {
        stop()
        AudioEngineManager.shared.startEngine()
        let gap: Double = steps.count > 1 ? 0.85 : 0
        for (index, step) in steps.enumerated() {
            let start = DispatchWorkItem { [weak self] in
                guard let self else { return }
                AudioEngineManager.shared.stopAllNotes()
                let velocity = UInt8(step.pitches.count > 1 ? 96 : 108)
                for midi in step.midiNotes { AudioEngineManager.shared.startNote(midi: UInt8(midi), velocity: velocity) }
                self.setHighlighted(true, step: index)
            }
            let isLast = index == steps.count - 1
            let end = DispatchWorkItem { [weak self] in
                self?.setHighlighted(false, step: index)
                if isLast { AudioEngineManager.shared.stopAllNotes() }
            }
            playbackItems += [start, end]
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * gap, execute: start)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * gap + (steps.count > 1 ? 0.8 : 1.2),
                                          execute: end)
        }
    }

    func stop() {
        playbackItems.forEach { $0.cancel() }
        playbackItems = []
        for index in stepLayers.indices { setHighlighted(false, step: index) }
    }

    private func setHighlighted(_ on: Bool, step: Int) {
        guard stepLayers.indices.contains(step) else { return }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        for head in stepLayers[step] { head.fillColor = (on ? highlight : ink).cgColor }
        CATransaction.commit()
    }
}

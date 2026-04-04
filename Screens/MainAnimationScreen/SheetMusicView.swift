import UIKit

// MARK: - SheetMusicView
//
// Pure CALayer drawing — no UIView subviews added/removed during render.
// Grand staff (treble + bass) drawn when JSON has 2 clefs.
// Single staff (treble only) when JSON has 1 clef.
// contentLayer.sublayers replaced atomically inside CATransaction.

final class SheetMusicView: UIView {
    private struct ParsedSheetState {
        let isSingleStaff: Bool
        let score: Score
        let totalTicks: Int
        let maxPixelsPerTick: CGFloat
        let songPixelLength: CGFloat
        let canvasW: CGFloat
    }

    // MARK: Constants
    private let lineSpacing: CGFloat = 12   // slightly reduced from 13 to avoid clipping in landscape
    private let noteRadius:  CGFloat = 4.0   // slightly reduced to match line spacing
    private let clefW:       CGFloat = 100
    private let msrW:        CGFloat = 260

    // Brand Color
    private let brandOrange = UIColor(red: 239.0/255.0, green: 148.0/255.0, blue: 8.0/255.0, alpha: 1.0)

    private var staffH:   CGFloat { 4 * lineSpacing }
    private var staffGap: CGFloat { 22 } // reduced from 30 to grant more vertical space

    // MARK: State
    private var canvasW:        CGFloat = 4000
    private var scrollFraction: CGFloat = 0
    private var currentTickPosition: Double = 0
    private var isSingleStaff:  Bool    = false   // grand staff by default
    private var score:          Score?
    private var lastBounds      = CGRect.zero
    private var renderPending   = false

    // For perfect tick-based synchronization
    private var totalTicks:       Int = 1000
    private var maxPixelsPerTick: CGFloat = 1.0
    private var loadGeneration: Int = 0

    // MARK: Permanent layers / views (added once, never removed)
    private let contentLayer = CALayer()   // all note/staff drawing lives here
    private let playhead     = UIView()
    private let fadeOverlay  = UIView()
    private let feedbackOverlay = UIView()

    // Delegate to communicate seeks
    var onSeekProgress: ((CGFloat) -> Void)?
    
    // Derived total pixel length of song for perfect sync
    private var songPixelLength: CGFloat = 1000

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    func loadData(_ data: Data) {
        loadGeneration += 1
        let generation = loadGeneration

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let state = Self.parsedSheetState(from: data) else { return }

            DispatchQueue.main.async {
                guard let self else { return }
                guard self.loadGeneration == generation else { return }

                self.applyParsedSheetState(state)
                self.setNeedsLayout()
            }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func setChordCount(_ n: Int) {}

    func configure(with chords: [SongChord]) {
        // Since SheetMusicView already has loadJSON/loadData logic that parses everything,
        // and PlayAlongViewController calls configure(with: st) where st is [SongChord],
        // we can just ensure the view is ready. 
        // In this implementation, the data is already loaded in loadDemoSheet() calling loadData.
        // However, PlayAlongViewController expects configure(with:) to exist.
        setNeedsLayout()
    }

    func updateProgress(to tick: Int) {
        updateToTick(Double(tick))
    }

    // MARK: One-time setup
    private func setup() {
        backgroundColor = UIColor(white: 0.97, alpha: 1)
        clipsToBounds = true
        layer.masksToBounds = true
        layer.addSublayer(contentLayer)

        // Fix: thin solid playhead line
        playhead.backgroundColor    = brandOrange
        playhead.layer.cornerRadius = 0
        playhead.isUserInteractionEnabled = false
        addSubview(playhead)

        // Fade overlay: white from left edge to playhead
        fadeOverlay.backgroundColor = UIColor(white: 0.97, alpha: 0.72)
        fadeOverlay.isUserInteractionEnabled = false
        addSubview(fadeOverlay)

        // Feedback overlay
        feedbackOverlay.isUserInteractionEnabled = false
        feedbackOverlay.alpha = 0
        addSubview(feedbackOverlay)
    }

    func setProgressBarHidden(_ hidden: Bool) {}

    // MARK: layoutSubviews — FRAME MATH ONLY
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let gt   = trebleTop
        let visH = totalStaffHeight
        let phX  = bounds.width * 0.16
        let phW: CGFloat = 3
        playhead.frame    = CGRect(x: phX, y: gt - 12, width: phW, height: visH + 24)
        fadeOverlay.frame = CGRect(x: 0,   y: 0, width: phX, height: bounds.height)
        feedbackOverlay.frame = bounds

        if bounds != lastBounds {
            lastBounds = bounds
            scheduleRender()
        }
    }

    // MARK: Playback
    func updatePlaybackProgress(_ p: CGFloat) {
        let p = max(0, min(1, p))
        scrollFraction = p
        currentTickPosition = Double(totalTicks) * Double(p)
        applyCurrentTransform()
    }

    func updateToTick(_ tick: Double) {
        let maxTick = max(1.0, Double(totalTicks))
        let p = max(0, min(1, CGFloat(tick / maxTick)))
        scrollFraction = p
        currentTickPosition = max(0, tick)
        applyCurrentTransform()
    }

    func resetProgress() {
        scrollFraction = 0
        currentTickPosition = 0
        applyCurrentTransform()
        contentLayer.sublayers?.filter { $0.name == "WrongNoteMarker" }.forEach { $0.removeFromSuperlayer() }
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
        let nx = clefW + CGFloat(tick) * maxPixelsPerTick + 16
        
        let marker = CALayer()
        marker.name = "WrongNoteMarker"
        marker.backgroundColor = UIColor.systemRed.withAlphaComponent(0.55).cgColor
        marker.cornerRadius = 2
        
        let markerH = totalStaffHeight + 8
        let markerY = trebleTop - 4
        marker.frame = CGRect(x: nx - 1.25, y: markerY, width: 2.5, height: markerH)
        
        contentLayer.addSublayer(marker)

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

    // MARK: Geometry
    private var trebleTop:        CGFloat {
        let pad: CGFloat = 12
        let total = isSingleStaff ? staffH : totalStaffHeight
        return pad + max(0, (bounds.height - total - pad * 2)) / 2
    }
    private var bassTop:          CGFloat { trebleTop + staffH + staffGap }
    private var totalStaffHeight: CGFloat { isSingleStaff ? staffH : (staffH * 2 + staffGap) }

    // MARK: JSON
    #if DEBUG
    private func loadJSON() {
        guard let url  = Bundle.main.url(forResource:"sheet_test", withExtension:"json"),
              let data = try? Data(contentsOf: url)
        else { debugLog("❌ bundled debug sheet data not found"); return }
        parseJSON(data); setNeedsLayout()
    }
    #else
    private func loadJSON() {}
    #endif

    private func parseJSON(_ data: Data) {
        guard let state = Self.parsedSheetState(from: data) else { return }
        applyParsedSheetState(state)
    }

    private func applyParsedSheetState(_ state: ParsedSheetState) {
        isSingleStaff = state.isSingleStaff
        score = state.score
        totalTicks = state.totalTicks
        maxPixelsPerTick = state.maxPixelsPerTick
        songPixelLength = state.songPixelLength
        canvasW = state.canvasW
    }

    private static func parsedSheetState(from data: Data) -> ParsedSheetState? {
        debugLog("📄 [SheetMusicView] parseJSON starting, data size: \(data.count) bytes")
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String:Any]
        else { 
            debugLog("❌ [SheetMusicView] parseJSON failed: Invalid JSON format")
            return nil
        }
        debugLog("🔍 [SheetMusicView] Root keys: \(root.keys.joined(separator: ", "))")

        // "part" is [[String:Any]] (array), not [String:Any] — must handle both
        var raw: [[String:Any]]?
        if let pw = root["score-partwise"] as? [String:Any] {
            if let parts = pw["part"] as? [[String:Any]] {
                // Multiple parts: flatten all measures
                raw = parts.compactMap { $0["measure"] as? [[String:Any]] }.flatMap { $0 }
            } else if let pt = pw["part"] as? [String:Any],
                      let ar = pt["measure"] as? [[String:Any]] {
                raw = ar
            }
        }
        if raw == nil || raw!.isEmpty { raw = deepFind(root) }
        guard let arr = raw, !arr.isEmpty else {
            debugLog("❌ SheetMusicView: no measures found in JSON")
            return nil
        }

        // Always show grand staff (treble + bass) regardless of clef count.
        // If the song only has right-hand notes, bass staff will simply be empty.
        let isSingleStaff = false

        var measures: [Measure] = []
        var globalTick = 0
        var divisions = 6
        var defaultBeats = 4   // will be inferred below

        // --- Pre-pass: read divisions and time signature from attributes ---
        for m in arr {
            if let att = m["attributes"] as? [String:Any] {
                if let d = att["divisions"] { divisions = MusicJSONLoader.intVal(d) ?? divisions }
                if let t = att["time"] as? [String:Any], let b = MusicJSONLoader.intVal(t["beats"]) {
                    defaultBeats = b
                    break
                }
            }
        }
        // --- Infer beats from first measure note durations if no time sig found ---
        if defaultBeats == 4 {
        if let first = arr.first {
                var rn: [[String:Any]] = []
                if let a = first["note"] as? [[String:Any]] { rn = a }
                else if let o = first["note"] as? [String:Any] { rn = [o] }
                let total = rn.filter { $0["chord"] == nil }.compactMap { MusicJSONLoader.intVal($0["duration"]) }.reduce(0, +)
            if total > 0 && divisions > 0 { defaultBeats = total / divisions }
        }
        }
        // pixelsPerTick is now computed from actual beats × divisions per measure
        let ticksPerMeasure = defaultBeats * divisions
        let pixelsPerTick: CGFloat = ticksPerMeasure > 0 ? 260 / CGFloat(ticksPerMeasure) : 260 / 24.0

        for m in arr {
            if let att = m["attributes"] as? [String:Any] {
                if let d = att["divisions"] { divisions = MusicJSONLoader.intVal(d) ?? divisions }
                if let t = att["time"] as? [String:Any], let b = MusicJSONLoader.intVal(t["beats"]) { defaultBeats = b }
            }

            var localTick: [String: Int] = [:]
            var lastLocalDur: [String: Int] = [:]
            var currentNotes: [SheetNote] = []

            var rn: [[String:Any]] = []
            if let a = m["note"] as? [[String:Any]]    { rn = a }
            else if let o = m["note"] as? [String:Any] { rn = [o] }

            for d in rn {
                let voice = MusicJSONLoader.strVal(d["voice"]) ?? "1"
                let staffStr = MusicJSONLoader.strVal(d["staff"]) ?? "1"
                let dur = MusicJSONLoader.intVal(d["duration"]) ?? 0
                let isChord = d["chord"] != nil
                _ = d["rest"] != nil

                let tickKey = "\(staffStr)-\(voice)"
                let localCur = localTick[tickKey, default: 0]
                let prevDur = lastLocalDur[tickKey, default: 0]
                let localStart = isChord ? max(0, localCur - prevDur) : localCur
                
                let noteTick = globalTick + localStart

                if let sn = noteFrom(d, tick: noteTick) {
                    currentNotes.append(sn)
                }

                if !isChord {
                    localTick[tickKey] = localCur + dur
                    lastLocalDur[tickKey] = dur
                }
            }

            var backupTotal = 0
            if let b = m["backup"] as? [[String:Any]] { backupTotal = b.compactMap { MusicJSONLoader.intVal($0["duration"]) }.reduce(0, +) }
            else if let b = m["backup"] as? [String:Any] { backupTotal = MusicJSONLoader.intVal(b["duration"]) ?? 0 }
            
            if backupTotal > 0 {
                for k in localTick.keys { localTick[k] = max(0, (localTick[k] ?? 0) - backupTotal) }
            }

            guard let num = msrNum(m) else { continue }
            measures.append(Measure(number:num, startTick: globalTick, notes: currentNotes))
            
            globalTick += defaultBeats * divisions
        }

        let score = Score(measures: measures, pixelsPerTick: pixelsPerTick)
        let songPixelLength = CGFloat(globalTick) * pixelsPerTick
        let canvasW = max(3000, 110 + songPixelLength + 400)
        debugLog("✅ SheetMusicView: \(measures.count) msr  singleStaff=\(isSingleStaff)  canvasW=\(canvasW)  totalTicks=\(globalTick)")
        return ParsedSheetState(
            isSingleStaff: isSingleStaff,
            score: score,
            totalTicks: globalTick,
            maxPixelsPerTick: pixelsPerTick,
            songPixelLength: songPixelLength,
            canvasW: canvasW
        )
    }

    private static func noteFrom(_ d: [String:Any], tick: Int) -> SheetNote? {

        let pitch = d["pitch"] as? [String:Any]
        let step  = pitch?["step"] as? String
        let oct:Int?
        if let s = pitch?["octave"] as? String { oct = Int(s) }
        else { oct = pitch?["octave"] as? Int }

        let staff:Int
        if let s = d["staff"] as? String { staff = Int(s) ?? 1 }
        else { staff = d["staff"] as? Int ?? 1 }

        var alter = 0
        if let a = pitch?["alter"] {
            if let i = a as? Int { alter=i }
            else if let f = a as? Double { alter=Int(f) }
            else if let s = a as? String { alter=Int(s) ?? 0 }
        }
        return SheetNote(step:step,octave:oct,alter:alter,tick:tick,staff:staff,isRest:d["rest"] != nil)
    }

    private static func msrNum(_ d:[String:Any]) -> Int? {
        if let s = d["@number"] as? String { return Int(s) }
        return d["@number"] as? Int
    }
    private static func deepFind(_ d:[String:Any]) -> [[String:Any]]? {
        if let a = d["measure"] as? [[String:Any]], !a.isEmpty { return a }
        for (_,v) in d {
            if let s = v as? [String:Any], let f = deepFind(s) { return f }
            // Also recurse into arrays of dicts (e.g. "part" is [[String:Any]])
            if let arr = v as? [[String:Any]] {
                let all = arr.compactMap { deepFind($0) }.flatMap { $0 }
                if !all.isEmpty { return all }
            }
        }
        return nil
    }

    // MARK: Render scheduling
    private func scheduleRender() {
        guard !renderPending else { return }
        renderPending = true
        DispatchQueue.main.async { [weak self] in
            self?.renderPending = false
            self?.doRender()
        }
    }

    // MARK: doRender — all CALayer, no UIView subviews
    private func doRender() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let build = CALayer()
        build.frame = CGRect(x:0, y:0, width:canvasW, height:bounds.height)

        let gt = trebleTop
        let bt = bassTop

        drawStaffLines(build, gt:gt, bt:bt)
        drawBraceAndBarline(build, gt:gt, bt:bt)
        drawClefs(build, gt:gt, bt:bt)
        drawBarlines(build, gt:gt, bt:bt)
        drawNotes(build, gt:gt, bt:bt)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.sublayers = build.sublayers   // atomic swap
        contentLayer.frame     = build.frame
        CATransaction.commit()

        applyCurrentTransform()
    }

    private func applyCurrentTransform() {
        let clampedTick = max(0, min(CGFloat(currentTickPosition), CGFloat(totalTicks)))
        let targetX = clefW + clampedTick * maxPixelsPerTick + 16
        let tx = playhead.frame.midX - targetX

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.transform = CATransform3DMakeTranslation(tx, 0, 0)
        CATransaction.commit()
    }

    // MARK: Draw staff lines
    private func drawStaffLines(_ p:CALayer, gt:CGFloat, bt:CGFloat) {
        let startX: CGFloat = 46
        let tops:[CGFloat] = isSingleStaff ? [gt] : [gt, bt]
        for top in tops {
            for i in 0..<5 {
                p.addSublayer(box(x:startX, y:top+CGFloat(i)*lineSpacing,
                                  w:canvasW-startX+2, h:0.7))
            }
        }
    }

    // MARK: Draw brace + connecting barline
    private func drawBraceAndBarline(_ p:CALayer, gt:CGFloat, bt:CGFloat) {
        let startX: CGFloat = 46
        if isSingleStaff {
            // Just a thin left barline
            p.addSublayer(box(x:startX, y:gt, w:1.5, h:staffH))
            return
        }
        let totalH = bt + staffH - gt
        // Thick connecting barline on far left
        p.addSublayer(box(x:startX, y:gt, w:2, h:totalH))
        // Curly brace { as text
        let tl = txt("{", sz:totalH*0.85)
        tl.frame = CGRect(x:4, y:gt - totalH*0.05, width:startX-8, height:totalH*1.1)
        tl.alignmentMode = .right
        p.addSublayer(tl)
    }

    // MARK: Draw clefs
    private func drawClefs(_ p:CALayer, gt:CGFloat, bt:CGFloat) {
        let clefX: CGFloat = 58
        // Treble clef
        let tc = txt("𝄞", sz:staffH+6)
        tc.frame = CGRect(x:clefX, y:gt-8, width:38, height:staffH+18)
        p.addSublayer(tc)

        if !isSingleStaff {
            let bc = txt("𝄢", sz:staffH*0.68)
            bc.frame = CGRect(x:clefX+2, y:bt+1, width:36, height:staffH-2)
            p.addSublayer(bc)
        }
    }

    // MARK: Draw barlines + measure numbers
    private func drawBarlines(_ p:CALayer, gt:CGFloat, bt:CGFloat) {
        guard let score else { return }
        let pixelsPerTick = score.pixelsPerTick
        let visH = isSingleStaff ? staffH : (bt + staffH - gt)
        for m in score.measures {
            let x = clefW + CGFloat(m.startTick) * pixelsPerTick + 16
            p.addSublayer(box(x:x, y:gt, w:0.8, h:visH))
            let n = txt("\(m.number)", sz:8)
            n.foregroundColor = UIColor.tertiaryLabel.cgColor
            n.frame = CGRect(x:x+3, y:gt-14, width:28, height:12)
            p.addSublayer(n)
        }
        // Final double barline
        let ex = clefW + songPixelLength + 16
        p.addSublayer(box(x:ex,   y:gt, w:1.5, h:isSingleStaff ? staffH : (bt+staffH-gt)))
        p.addSublayer(box(x:ex+4, y:gt, w:4,   h:isSingleStaff ? staffH : (bt+staffH-gt)))
    }

    // MARK: Draw notes
    private func drawNotes(_ p:CALayer, gt:CGFloat, bt:CGFloat) {
        guard let score else { return }
        let pixelsPerTick = score.pixelsPerTick
        for msr in score.measures {
            let valid = msr.notes.filter { !$0.isRest && $0.step != nil && $0.octave != nil }
            guard !valid.isEmpty else { continue }

            for note in valid {
                let nx  = clefW + CGFloat(note.tick) * pixelsPerTick + 16
                let ny  = noteY(note, gt:gt, bt:bt)
                let isTreble = (note.staff == 1 || isSingleStaff)
                let midY = isTreble ? (gt + staffH/2) : (bt + staffH/2)
                let stemUp = ny >= midY // if visually lower than middle line (larger Y), stem goes UP

                drawHead(p, cx:nx, cy:ny, alter:note.alter, staff:note.staff, step:note.step, oct:note.octave, stemUp:stemUp)
                // Ledger lines if needed
                drawLedger(p, note:note, cx:nx, gt:gt, bt:bt)
            }
        }
    }

    // Note Y: treble E4=bottom line, bass G2=bottom line
    private func noteY(_ n:SheetNote, gt:CGFloat, bt:CGFloat) -> CGFloat {
        guard let step=n.step, let oct=n.octave else { return gt+staffH/2 }
        let sc=["C","D","E","F","G","A","B"]
        guard let idx=sc.firstIndex(of:step) else { return gt+staffH/2 }
        let half=lineSpacing/2
        if n.staff==1 || isSingleStaff {
            return (gt+staffH) - CGFloat((oct-4)*7+(idx-2))*half
        } else {
            return (bt+staffH) - CGFloat((oct-2)*7+(idx-4))*half
        }
    }

    // Draw note head + stem (black for a cleaner, unified look)
    private func drawHead(_ p:CALayer, cx:CGFloat, cy:CGFloat, alter:Int, staff:Int, step:String?, oct:Int?, stemUp:Bool) {
        let noteColor: UIColor = UIColor(white: 0.1, alpha: 1.0) // Deep dark gray/black
        
        let w = noteRadius * 2.5
        let h = noteRadius * 1.6

        // True oval shape for the notehead
        let hd = CAShapeLayer()
        let ovalPath = UIBezierPath(ovalIn: CGRect(x: -w/2, y: -h/2, width: w, height: h))
        hd.path = ovalPath.cgPath
        hd.fillColor = noteColor.cgColor
        hd.position = CGPoint(x: cx, y: cy)
        hd.transform = CATransform3DMakeRotation(-0.35, 0, 0, 1) // ~20 degrees rotation
        p.addSublayer(hd)

        let st = CALayer()
        st.backgroundColor = noteColor.cgColor
        let stemH = noteRadius * 5.0
        let stemW: CGFloat = 1.0
        if stemUp {
            // Stem points UP from the RIGHT side of the notehead
            st.frame = CGRect(x: cx + w/2 - 1.5, y: cy - stemH, width: stemW, height: stemH)
        } else {
            // Stem points DOWN from the LEFT side of the notehead
            st.frame = CGRect(x: cx - w/2 + 0.5, y: cy, width: stemW, height: stemH)
        }
        p.addSublayer(st)

        if alter != 0 {
            let acc=txt(alter==1 ? "♯":"♭", sz:8)
            acc.foregroundColor=noteColor.cgColor
            acc.frame=CGRect(x:cx-noteRadius-9, y:cy-6, width:9, height:12)
            p.addSublayer(acc)
        }

        // Add note name label beneath or above depending on position for higher visibility
        if let s = step, let o = oct {
            let altStr = alter == 1 ? "#" : alter == -1 ? "b" : ""
            let lbl = txt("\(s)\(altStr)\(o)", sz: 6.5)
            lbl.foregroundColor = UIColor.black.cgColor // Darker highlighted text
            let lblY = stemUp ? cy + h/2 + 2 : cy - h/2 - 10
            lbl.frame = CGRect(x: cx-12, y: lblY, width: 24, height: 10)
            p.addSublayer(lbl)
        }
    }

    // Draw ledger lines for notes outside the staff
    private func drawLedger(_ p:CALayer, note:SheetNote, cx:CGFloat, gt:CGFloat, bt:CGFloat) {
        guard let step=note.step, let oct=note.octave else { return }
        let sc=["C","D","E","F","G","A","B"]
        guard let idx=sc.firstIndex(of:step) else { return }
        let half=lineSpacing/2
        let lw:CGFloat=noteRadius*2.5

        if note.staff==1 || isSingleStaff {
            // Positions above and below treble staff
            // Middle C (C4) = one ledger below treble bottom line
            let stepsFromE4 = (oct-4)*7+(idx-2)
            // Ledger below: C4 (-2), B3 (-3), A3 (-4) etc (every even step from bottom)
            if stepsFromE4 <= -2 {
                var s = -2
                while s >= stepsFromE4 {
                    let ly = (gt+staffH) - CGFloat(s)*half
                    p.addSublayer(box(x:cx-lw/2, y:ly-0.5, w:lw, h:0.75))
                    s -= 2
                }
            }
            // Ledger above top line
            if stepsFromE4 >= 10 {
                var s = 10
                while s <= stepsFromE4 {
                    let ly = (gt+staffH) - CGFloat(s)*half
                    p.addSublayer(box(x:cx-lw/2, y:ly-0.5, w:lw, h:0.75))
                    s += 2
                }
            }
        } else {
            let stepsFromG2 = (oct-2)*7+(idx-4)
            if stepsFromG2 <= -2 {
                var s = -2
                while s >= stepsFromG2 {
                    let ly = (bt+staffH) - CGFloat(s)*half
                    p.addSublayer(box(x:cx-lw/2, y:ly-0.5, w:lw, h:0.75))
                    s -= 2
                }
            }
            if stepsFromG2 >= 10 {
                var s = 10
                while s <= stepsFromG2 {
                    let ly = (bt+staffH) - CGFloat(s)*half
                    p.addSublayer(box(x:cx-lw/2, y:ly-0.5, w:lw, h:0.75))
                    s += 2
                }
            }
        }
    }

    // MARK: CALayer helpers
    private func box(x:CGFloat,y:CGFloat,w:CGFloat,h:CGFloat)->CALayer {
        let l=CALayer()
        l.backgroundColor=UIColor.black.cgColor
        l.frame=CGRect(x:x,y:y,width:max(w,0.5),height:max(h,0.5))
        return l
    }
    private func txt(_ s:String, sz:CGFloat)->CATextLayer {
        let l=CATextLayer()
        l.string=s
        l.fontSize=sz
        l.foregroundColor=UIColor.black.cgColor
        l.contentsScale=UITraitCollection.current.displayScale
        l.alignmentMode = .center
        l.isWrapped=false
        return l
    }
}

// MARK: Models
private struct Score   { var measures:[Measure]; var pixelsPerTick: CGFloat }
private struct Measure { let number:Int; let startTick:Int; var notes:[SheetNote] }
private struct SheetNote {
    let step:String?; let octave:Int?; let alter:Int
    let tick:Int; let staff:Int; let isRest:Bool
}

import UIKit

// MARK: - SheetMusicView
//
// Pure CALayer drawing — no UIView subviews added/removed during render.
// Grand staff (treble + bass) drawn when JSON has 2 clefs.
// Single staff (treble only) when JSON has 1 clef.
// contentLayer.sublayers replaced atomically inside CATransaction.

final class SheetMusicView: UIView {

    // MARK: Constants
    private let lineSpacing: CGFloat = 13   // between staff lines (wider for landscape)
    private let noteRadius:  CGFloat = 4.5
    private let clefW:       CGFloat = 110   // column for brace + clef symbols (increased)
    private let msrW:        CGFloat = 260  // pixels per measure on canvas

    private var staffH: CGFloat { 4 * lineSpacing }   // 5 lines = 4 gaps

    // MARK: State
    private var canvasW:        CGFloat = 4000
    private var scrollFraction: CGFloat = 0
    private var isSingleStaff:  Bool    = false   // grand staff by default
    private var score:          Score?
    private var lastBounds      = CGRect.zero
    private var renderPending   = false
    
    // For perfect tick-based synchronization
    private var totalTicks:       Int = 1000
    private var maxPixelsPerTick: CGFloat = 1.0

    // MARK: Permanent layers / views (added once, never removed)
    private let contentLayer = CALayer()   // all note/staff drawing lives here
    private let playhead     = UIView()
    private let fadeOverlay  = UIView()
    private let progressBarTrack = UIView()
    private let progressBar  = UIView()
    private let progressThumb = UIView()
    
    // Delegate to communicate seeks
    var onSeekProgress: ((CGFloat) -> Void)?
    
    // Derived total pixel length of song for perfect sync
    private var songPixelLength: CGFloat = 1000

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        loadJSON()
    }

    func loadData(_ data: Data) {
        parseJSON(data)
        setNeedsLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    func setChordCount(_ n: Int) {}

    // MARK: One-time setup
    private func setup() {
        backgroundColor = UIColor(white: 0.97, alpha: 1)
        layer.addSublayer(contentLayer)

        // Fix: thin solid blue playhead line (not wide band)
        playhead.backgroundColor    = UIColor.systemBlue
        playhead.layer.cornerRadius = 0
        playhead.isUserInteractionEnabled = false
        addSubview(playhead)

        // Fade overlay: white from left edge to playhead
        fadeOverlay.backgroundColor = UIColor(white: 0.97, alpha: 0.72)
        fadeOverlay.isUserInteractionEnabled = false
        addSubview(fadeOverlay)

        // Progress bar container & track
        progressBarTrack.backgroundColor = UIColor.systemGray4
        progressBarTrack.layer.cornerRadius = 4
        progressBarTrack.isUserInteractionEnabled = true
        addSubview(progressBarTrack)
        
        // Progress bar fill
        let orangeColor = UIColor(red: 0.91, green: 0.44, blue: 0.05, alpha: 1.0)
        progressBar.backgroundColor = orangeColor
        progressBar.layer.cornerRadius = 4
        progressBar.isUserInteractionEnabled = false
        progressBarTrack.addSubview(progressBar)
        
        // Progress thumb (circle)
        progressThumb.backgroundColor = orangeColor
        progressThumb.layer.cornerRadius = 8
        progressThumb.isUserInteractionEnabled = false
        progressBarTrack.addSubview(progressThumb)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleProgressPan(_:)))
        progressBarTrack.addGestureRecognizer(pan)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleProgressTap(_:)))
        progressBarTrack.addGestureRecognizer(tap)
    }

    @objc private func handleProgressPan(_ gesture: UIPanGestureRecognizer) {
        let loc = gesture.location(in: progressBarTrack)
        let p = max(0, min(1, loc.x / progressBarTrack.bounds.width))
        onSeekProgress?(p)
    }
    
    @objc private func handleProgressTap(_ gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: progressBarTrack)
        let p = max(0, min(1, loc.x / progressBarTrack.bounds.width))
        onSeekProgress?(p)
    }

    // MARK: layoutSubviews — FRAME MATH ONLY
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let gt  = trebleTop
        let visH = totalStaffHeight
        // Fix 3: playhead is a 3pt wide solid blue vertical line at 28% of width
        let phX = bounds.width * 0.28
        let phW: CGFloat = 3
        playhead.frame = CGRect(x: phX, y: gt - 12, width: phW, height: visH + 24)

        fadeOverlay.frame = CGRect(x: 0, y: 0, width: phX, height: bounds.height)
        
        let trackPaddingX: CGFloat = 50
        let trackY: CGFloat = 16
        let trackW = bounds.width - (trackPaddingX * 2)
        let trackH: CGFloat = 8
        
        progressBarTrack.frame = CGRect(x: trackPaddingX, y: trackY, width: trackW, height: trackH)
        
        let fillW = trackW * scrollFraction
        progressBar.frame = CGRect(x: 0, y: 0, width: fillW, height: trackH)
        progressThumb.frame = CGRect(x: fillW - 8, y: -4, width: 16, height: 16)

        if bounds != lastBounds {
            lastBounds = bounds
            scheduleRender()
        }
    }

    // MARK: Playback
    func updatePlaybackProgress(_ p: CGFloat) {
        let p = max(0, min(1, p))
        scrollFraction = p

        // Scroll the content layer so the note at fraction p aligns with the playhead
        let targetX = clefW + p * songPixelLength + 16
        let tx = playhead.frame.midX - targetX

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.transform = CATransform3DMakeTranslation(tx, 0, 0)
        CATransaction.commit()
        
        let trackW = bounds.width - 100
        let fillW = trackW * scrollFraction
        progressBar.frame = CGRect(x: 0, y: 0, width: fillW, height: 8)
        progressThumb.frame = CGRect(x: fillW - 8, y: -4, width: 16, height: 16)
    }

    /// Update progress based precisely on the loaded sheet's tick timeline
    func updateToTick(_ tick: Double) {
        let maxTick = max(1.0, Double(totalTicks))
        let p = max(0, min(1, CGFloat(tick / maxTick)))
        scrollFraction = p
        
        // Use exact tick mapping for perfect synchronization
        let targetX = clefW + CGFloat(tick) * maxPixelsPerTick + 16
        let tx = playhead.frame.midX - targetX
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.transform = CATransform3DMakeTranslation(tx, 0, 0)
        CATransaction.commit()
        
        let trackW = bounds.width - 100
        let fillW = trackW * scrollFraction
        progressBar.frame = CGRect(x: 0, y: 0, width: fillW, height: 8)
        progressThumb.frame = CGRect(x: fillW - 8, y: -4, width: 16, height: 16)
    }

    func resetProgress() {
        scrollFraction = 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.transform = CATransform3DIdentity
        CATransaction.commit()
        progressBar.frame = CGRect(x: 0, y: 0, width: 0, height: 8)
        progressThumb.frame = CGRect(x: -8, y: -4, width: 16, height: 16)
    }

    // MARK: Geometry
    private var staffGap:         CGFloat { 30 }   // gap between treble and bass
    private var trebleTop:        CGFloat {
        let pad: CGFloat = 8
        let total = isSingleStaff ? staffH : totalStaffHeight
        return pad + max(0, (bounds.height - total - pad * 2)) / 2
    }
    private var bassTop:          CGFloat { trebleTop + staffH + staffGap }
    private var totalStaffHeight: CGFloat { isSingleStaff ? staffH : (staffH * 2 + staffGap) }

    // MARK: JSON
    private func loadJSON() {
        guard let url  = Bundle.main.url(forResource:"sheet_test", withExtension:"json"),
              let data = try? Data(contentsOf: url)
        else { print("❌ sheet_test.json not found"); return }
        parseJSON(data); setNeedsLayout()
    }

    private func parseJSON(_ data: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String:Any]
        else { return }

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
            print("❌ SheetMusicView: no measures found in JSON")
            return
        }

        // Always show grand staff (treble + bass) regardless of clef count.
        // If the song only has right-hand notes, bass staff will simply be empty.
        isSingleStaff = false

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
        let pixelsPerTick: CGFloat = ticksPerMeasure > 0 ? msrW / CGFloat(ticksPerMeasure) : msrW / 24.0

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
                let isRest = d["rest"] != nil

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

        score   = Score(measures: measures, pixelsPerTick: pixelsPerTick)
        self.totalTicks = globalTick
        self.maxPixelsPerTick = pixelsPerTick
        songPixelLength = CGFloat(globalTick) * pixelsPerTick
        canvasW = max(3000, clefW + songPixelLength + 400)
        print("✅ SheetMusicView: \(measures.count) msr  singleStaff=\(isSingleStaff)  canvasW=\(canvasW)  totalTicks=\(totalTicks)")
    }

    private func noteFrom(_ d: [String:Any], tick: Int) -> SheetNote? {

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

    private func msrNum(_ d:[String:Any]) -> Int? {
        if let s = d["@number"] as? String { return Int(s) }
        return d["@number"] as? Int
    }
    private func deepFind(_ d:[String:Any]) -> [[String:Any]]? {
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

        // Re-apply scroll offset
        let targetX = clefW + scrollFraction * songPixelLength + 16
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
        l.contentsScale=UIScreen.main.scale
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

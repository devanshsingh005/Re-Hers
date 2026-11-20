// Usage: swift scripts/ghost-hands/make_hand_images.swift <output folder>
// then copy hand.png / finger1…5.png into Re-Hearse_v1/Assets.xcassets/GhostHands (GhostHand@3x, GhostFinger1…5@3x).

// Renders the ghost-hand artwork (a right hand, back view, fingers up) and one glow layer per
// finger, as PNGs. The app mirrors the right hand for the left.
import AppKit
import CoreGraphics

let W = 420, H = 480
let out = CommandLine.arguments[1]

struct Finger { let base: CGPoint; let tip: CGPoint; let baseW: CGFloat; let tipW: CGFloat }
// thumb, index, middle, ring, pinky (left to right for a right hand seen from above)
let fingers = [
    Finger(base: CGPoint(x: 168, y: 318), tip: CGPoint(x: 96, y: 196), baseW: 60, tipW: 40),
    Finger(base: CGPoint(x: 186, y: 214), tip: CGPoint(x: 164, y: 96), baseW: 52, tipW: 38),
    Finger(base: CGPoint(x: 236, y: 204), tip: CGPoint(x: 230, y: 72), baseW: 54, tipW: 40),
    Finger(base: CGPoint(x: 284, y: 212), tip: CGPoint(x: 294, y: 94), baseW: 50, tipW: 38),
    Finger(base: CGPoint(x: 326, y: 234), tip: CGPoint(x: 350, y: 138), baseW: 44, tipW: 32),
]

func fingerPath(_ f: Finger) -> CGPath {
    var dx = f.tip.x - f.base.x, dy = f.tip.y - f.base.y
    let len = hypot(dx, dy); dx /= len; dy /= len
    let px = -dy, py = dx
    let r = f.tipW / 2
    let c = CGPoint(x: f.tip.x - dx * r, y: f.tip.y - dy * r)
    let root = CGPoint(x: f.base.x - dx * 30, y: f.base.y - dy * 30)
    let p = CGMutablePath()
    p.move(to: CGPoint(x: root.x + px * f.baseW / 2, y: root.y + py * f.baseW / 2))
    // a slight knuckle swell two thirds of the way up
    let mid = CGPoint(x: f.base.x + (c.x - f.base.x) * 0.45, y: f.base.y + (c.y - f.base.y) * 0.45)
    let midW = (f.baseW + f.tipW) / 2 + 3
    p.addQuadCurve(to: CGPoint(x: c.x + px * r, y: c.y + py * r),
                   control: CGPoint(x: mid.x + px * midW / 2, y: mid.y + py * midW / 2))
    let a0 = atan2(py, px)
    for k in 1...24 {
        let a = a0 - .pi * CGFloat(k) / 24
        p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
    }
    p.addQuadCurve(to: CGPoint(x: root.x - px * f.baseW / 2, y: root.y - py * f.baseW / 2),
                   control: CGPoint(x: mid.x - px * midW / 2, y: mid.y - py * midW / 2))
    p.closeSubpath()
    return p
}

func palmPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 152, y: 236))
    p.addCurve(to: CGPoint(x: 350, y: 246), control1: CGPoint(x: 200, y: 186), control2: CGPoint(x: 310, y: 190))
    p.addCurve(to: CGPoint(x: 336, y: 470), control1: CGPoint(x: 372, y: 320), control2: CGPoint(x: 340, y: 400))
    p.addLine(to: CGPoint(x: 196, y: 470))
    p.addCurve(to: CGPoint(x: 152, y: 236), control1: CGPoint(x: 190, y: 400), control2: CGPoint(x: 128, y: 320))
    p.closeSubpath()
    return p
}

var hand = palmPath()
for f in fingers { hand = hand.union(fingerPath(f)) }

func render(_ name: String, _ draw: (CGContext) -> Void) {
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(H)); ctx.scaleBy(x: 1, y: -1)   // y down, like UIKit
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}

let glowBlue = CGColor(srgbRed: 0.45, green: 0.78, blue: 1, alpha: 1)

render("hand") { ctx in
    let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
    // a soft white glow around the drawing
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 14, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35))
    ctx.addPath(hand); ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.92)); ctx.fillPath()
    ctx.restoreGState()
    // the lines inside: where the fingers meet the hand, knuckle creases, nails
    ctx.saveGState()
    ctx.addPath(hand); ctx.clip()
    ctx.setStrokeColor(white.copy(alpha: 0.85)!); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    for (i, f) in fingers.enumerated() {
        var dx = f.tip.x - f.base.x, dy = f.tip.y - f.base.y
        let len = hypot(dx, dy); dx /= len; dy /= len
        let px = -dy, py = dx
        // the finger's sides down into the hand
        ctx.setLineWidth(3)
        ctx.addPath(fingerPath(f).subtracting(palmPath())); ctx.strokePath()
        ctx.setLineWidth(2.4)
        for at in (i == 0 ? [0.5] : [0.42, 0.7]) {
            let c = CGPoint(x: f.base.x + (f.tip.x - f.base.x) * at, y: f.base.y + (f.tip.y - f.base.y) * at)
            let w = (f.baseW + (f.tipW - f.baseW) * at) * 0.26
            for k in [-1.0, 1.0] {
                ctx.move(to: CGPoint(x: c.x + px * w * (k < 0 ? 1.1 : 0.15), y: c.y + py * w * (k < 0 ? 1.1 : 0.15)))
                ctx.addLine(to: CGPoint(x: c.x + px * w * (k < 0 ? 0.25 : -0.9) + dx * 3, y: c.y + py * w * (k < 0 ? 0.25 : -0.9) + dy * 3))
            }
            ctx.strokePath()
        }
        // the nail at the tip
        let r = f.tipW * 0.3
        let c = CGPoint(x: f.tip.x - dx * f.tipW * 0.42, y: f.tip.y - dy * f.tipW * 0.42)
        let a = atan2(dy, dx)
        ctx.addArc(center: c, radius: r, startAngle: a - 1.4, endAngle: a + 1.4, clockwise: false)
        ctx.strokePath()
    }
    // the tendons on the back of the hand
    ctx.setLineWidth(1.8); ctx.setStrokeColor(white.copy(alpha: 0.35)!)
    for f in fingers.dropFirst() {
        ctx.move(to: CGPoint(x: f.base.x, y: f.base.y + 30)); ctx.addLine(to: CGPoint(x: 262 + (f.base.x - 262) * 0.4, y: 380)); ctx.strokePath()
    }
    ctx.restoreGState()
    // the outline
    ctx.addPath(hand); ctx.setStrokeColor(white); ctx.setLineWidth(4); ctx.setLineJoin(.round); ctx.strokePath()
    // the white cuff at the wrist
    ctx.setFillColor(white)
    ctx.addEllipse(in: CGRect(x: 192, y: 446, width: 148, height: 40)); ctx.fillPath()
}

// one glow per finger, in white (the app tints it with the hand's colour)
let palm = palmPath()
for (i, f) in fingers.enumerated() {
    render("finger\(i + 1)") { ctx in
        // the finger itself, not the palm it grows from
        let path = fingerPath(f).subtracting(palm)
        var dx = f.tip.x - f.base.x, dy = f.tip.y - f.base.y
        let len = hypot(dx, dy); dx /= len; dy /= len
        // a soft halo around the finger
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 24, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.95))
        ctx.addPath(path); ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35)); ctx.fillPath()
        ctx.restoreGState()
        // light running up the finger, strongest at the tip
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.85),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: f.tip, end: f.base, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
        ctx.addPath(path); ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)); ctx.setLineWidth(3); ctx.strokePath()
        // the fingertip shines where it meets the key
        let r = f.tipW * 0.42
        let c = CGPoint(x: f.tip.x - dx * r * 0.9, y: f.tip.y - dy * r * 0.9)
        ctx.setShadow(offset: .zero, blur: 16, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.75)); ctx.fillPath()
    }
}
// where each fingertip is, for the finger-number badges (fractions of the image)
for (i, f) in fingers.enumerated() {
    print("finger \(i + 1) tip: \(f.tip.x / CGFloat(W)), \(f.tip.y / CGFloat(H))")
}

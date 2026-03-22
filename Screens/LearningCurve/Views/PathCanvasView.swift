import UIKit

class PathCanvasView: UIView {
    let chapters:    [MusicChapter]
    let nodeSize:    CGFloat
    let vSpacing:    CGFloat
    let canvasWidth: CGFloat

    private let watermarkDefs: [(CGFloat, CGFloat, Int, CGFloat)] = [
        (0.08, 0.06, 0, -15), (0.78, 0.12, 1,  10), (0.05, 0.28, 2,  -8),
        (0.72, 0.34, 0,  20), (0.10, 0.50, 1, -12), (0.75, 0.56, 2,  15),
        (0.06, 0.70, 0,  -5), (0.78, 0.76, 1,  18), (0.12, 0.88, 2, -20),
    ]

    init(chapters: [MusicChapter], nodeSize: CGFloat, vSpacing: CGFloat, width: CGFloat) {
        self.chapters = chapters; self.nodeSize = nodeSize
        self.vSpacing = vSpacing; self.canvasWidth = width
        super.init(frame: .zero); backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        drawWatermarks(ctx: ctx, rect: rect)
        ctx.setStrokeColor(ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(5); ctx.setLineDash(phase: 0, lengths: [12, 9])
        ctx.setLineCap(.round)
        for i in 0..<chapters.count - 1 {
            let from = nodeCenter(index: i); let to = nodeCenter(index: i + 1)
            let cp1  = CGPoint(x: from.x, y: from.y + vSpacing * 0.5)
            let cp2  = CGPoint(x: to.x,   y: to.y   - vSpacing * 0.5)
            ctx.move(to: from); ctx.addCurve(to: to, control1: cp1, control2: cp2)
        }
        ctx.strokePath()
    }

    private func drawWatermarks(ctx: CGContext, rect: CGRect) {
        let iconChars = ["♩", "♫", "♬"]
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32),
            .foregroundColor: ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.18)
        ]
        func drawStaffLines(at center: CGPoint, rotation: CGFloat) {
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: rotation * .pi / 180)
            ctx.setStrokeColor(ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.18).cgColor)
            ctx.setLineWidth(2); ctx.setLineDash(phase: 0, lengths: [])
            let lineW: CGFloat = 28; let lineSpacing: CGFloat = 5
            let totalH = lineSpacing * 3
            for j in 0..<4 {
                let ly = -totalH / 2 + CGFloat(j) * lineSpacing
                ctx.move(to: CGPoint(x: -lineW/2, y: ly))
                ctx.addLine(to: CGPoint(x: lineW/2, y: ly))
            }
            ctx.strokePath(); ctx.restoreGState()
        }
        for def in watermarkDefs {
            let (xRatio, yRatio, iconIdx, rotation) = def
            let cx = xRatio * canvasWidth; let cy = yRatio * rect.height
            if iconIdx == 1 {
                drawStaffLines(at: CGPoint(x: cx, y: cy), rotation: rotation)
            } else {
                let char = iconChars[iconIdx % iconChars.count]
                ctx.saveGState()
                ctx.translateBy(x: cx, y: cy)
                ctx.rotate(by: rotation * .pi / 180)
                let size = (char as NSString).size(withAttributes: attrs)
                (char as NSString).draw(at: CGPoint(x: -size.width/2, y: -size.height/2),
                                        withAttributes: attrs)
                ctx.restoreGState()
            }
        }
    }

    func nodeCenter(index: Int) -> CGPoint {
        let y     = CGFloat(index) * vSpacing + 10 + nodeSize / 2
        let inset: CGFloat = canvasWidth * 0.12
        let leftX  = inset + nodeSize / 2
        let rightX = canvasWidth - nodeSize / 2 - inset - 40
        let x: CGFloat
        switch index % 4 {
        case 0: x = rightX
        case 1: x = leftX
        case 2: x = rightX * 0.75 + leftX * 0.25
        case 3: x = leftX + (rightX - leftX) * 0.2
        default: x = index % 2 == 0 ? rightX : leftX
        }
        return CGPoint(x: x, y: y)
    }
}

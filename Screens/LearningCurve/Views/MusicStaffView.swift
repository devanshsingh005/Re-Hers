import UIKit

class MusicStaffView: UIView {

    private let noteName: String
    private var noteLayer: CALayer?

    init(noteName: String) {
        self.noteName = noteName
        super.init(frame: .zero)
        backgroundColor = .white
        layer.cornerRadius = 24
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 6)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        drawStaff()
        addTapToPlay()
    }

    private func drawStaff() {
        let staffTop: CGFloat = 50
        let staffLeft: CGFloat = 24
        let staffRight: CGFloat = bounds.width - 24
        let lineSpacing: CGFloat = 14
        let numLines = 5

        for i in 0..<numLines {
            let y = staffTop + CGFloat(i) * lineSpacing
            let line = CALayer()
            line.frame = CGRect(x: staffLeft, y: y, width: staffRight - staffLeft, height: 1)
            line.backgroundColor = UIColor.systemGray4.cgColor
            layer.addSublayer(line)
        }

        let clefLayer = CATextLayer()
        clefLayer.string = "𝄞"
        clefLayer.font = CTFontCreateWithName("TimesNewRomanPS-BoldMT" as CFString, 72, nil)
        clefLayer.fontSize = 72
        clefLayer.foregroundColor = UIColor.systemGray3.cgColor
        clefLayer.frame = CGRect(x: staffLeft + 2, y: staffTop - 32, width: 60, height: 85)
        clefLayer.contentsScale = UITraitCollection.current.displayScale
        layer.addSublayer(clefLayer)

        let centerY = staffTop + CGFloat(numLines - 1) / 2 * lineSpacing
        let noteOffset = noteYOffset(for: noteName)
        let noteY = centerY + noteOffset
        let noteX = bounds.width / 2 + 20

        if noteName == "C" {
            let ledger = CALayer()
            ledger.frame = CGRect(x: noteX - 18, y: noteY + 6, width: 38, height: 1.5)
            ledger.backgroundColor = UIColor.systemGray3.cgColor
            layer.addSublayer(ledger)
        }

        let stem = CALayer()
        stem.frame = CGRect(x: noteX + 8, y: noteY - 28, width: 2, height: 32)
        stem.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        layer.addSublayer(stem)

        let noteHead = CALayer()
        noteHead.bounds = CGRect(x: 0, y: 0, width: 22, height: 15)
        noteHead.position = CGPoint(x: noteX, y: noteY + 6)
        noteHead.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        noteHead.cornerRadius = 7
        noteHead.transform = CATransform3DMakeRotation(-0.25, 0, 0, 1)
        layer.addSublayer(noteHead)
        self.noteLayer = noteHead
        startPulse()
    }

    private func noteYOffset(for note: String) -> CGFloat {
        switch note {
        case "C": return 22
        case "D": return 14
        case "E": return 7
        case "F": return 0
        case "G": return -7
        case "A": return -14
        case "B": return -21
        default:  return 22
        }
    }

    private func startPulse() {
        guard let noteLayer = noteLayer else { return }
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0; pulse.toValue = 1.12
        pulse.duration = 0.65; pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        noteLayer.add(pulse, forKey: "pulse")
    }

    private func addTapToPlay() {
        let tapLabel = UILabel()
        tapLabel.text = "TAP TO PLAY"
        tapLabel.font = .systemFont(ofSize: 11, weight: .bold)
        tapLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
        tapLabel.translatesAutoresizingMaskIntoConstraints = false

        let border = UIView()
        border.translatesAutoresizingMaskIntoConstraints = false
        border.layer.borderColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        border.layer.borderWidth = 1.2
        border.layer.cornerRadius = 11
        border.addSubview(tapLabel)
        addSubview(border)

        NSLayoutConstraint.activate([
            tapLabel.topAnchor.constraint(equalTo: border.topAnchor, constant: 5),
            tapLabel.bottomAnchor.constraint(equalTo: border.bottomAnchor, constant: -5),
            tapLabel.leadingAnchor.constraint(equalTo: border.leadingAnchor, constant: 12),
            tapLabel.trailingAnchor.constraint(equalTo: border.trailingAnchor, constant: -12),
            border.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            border.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    @objc private func handleTap() {
        guard let noteLayer = noteLayer else { return }
        noteLayer.removeAllAnimations()
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.3, 0.9, 1.1, 1.0]
        bounce.duration = 0.5; bounce.calculationMode = .cubic
        noteLayer.add(bounce, forKey: "bounce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.startPulse() }
    }
}

//
//  WaveView.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 18/11/25.
//


//
//  WaveView.swift
//  Re-Hearse_v1
//

import UIKit

class WaveView: UIView {

    private var amplitude: CGFloat = 0.01
    private var phase: CGFloat = 0
    private var displayLink: CADisplayLink?

    private var waveColor: UIColor = .systemBlue   // Default

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = UIColor(white: 0.97, alpha: 1)
        layer.cornerRadius = 12

        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to: .main, forMode: .default)
    }

    deinit {
        displayLink?.invalidate()
        displayLink = nil
    }

    func setWaveColor(_ color: UIColor) {
        waveColor = color
    }

    func updateAmplitude(_ value: CGFloat) {
        amplitude = min(max(value, 0.02), 1.0)
    }

    @objc private func step() {
        phase += 0.15
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.clear(rect)

        let midY = rect.height / 2
        let width = rect.width

        let path = UIBezierPath()
        path.lineWidth = 3

        let amplitudeHeight: CGFloat = amplitude * 40
        let wavelength = width * 1.6

        for x in stride(from: CGFloat(0), through: width, by: 1) {
            let relative = x / wavelength
            let y = sin(relative * .pi * 2 + phase) * amplitudeHeight + midY

            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        waveColor.setStroke()
        path.stroke()
    }
}

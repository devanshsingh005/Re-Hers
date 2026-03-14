//
//  AnimationOverlayView.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 19/02/26.
//

import Foundation
import UIKit
final class AnimationOverlayView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    // Example placeholder animation
    func animateNote(at x: CGFloat) {
        let note = UIView()
        note.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        note.layer.cornerRadius = 6

        addSubview(note)
        note.frame = CGRect(x: x, y: -40, width: 24, height: 40)

        UIView.animate(withDuration: 1.2, delay: 0, options: .curveLinear) {
            note.frame.origin.y = self.bounds.height - 40
        } completion: { _ in
            note.removeFromSuperview()
        }
    }
}

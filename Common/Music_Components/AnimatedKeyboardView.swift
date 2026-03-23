//
//  AnimatedKeyboardView.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import Foundation
import UIKit

class AnimatedKeyboardView: UIView {
    private var keys: [PianoKeyView] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboard()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeyboard()
    }
    
    private func setupKeyboard() {
        backgroundColor = .darkGray
        layer.cornerRadius = 12
        
        // Create 3 white keys for demo
        for _ in 0..<3 {
            let key = PianoKeyView(isBlackKey: false)
            keys.append(key)
            addSubview(key)
        }
        setupTapGestures()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let keyWidth = bounds.width / 3
        for (index, key) in keys.enumerated() {
            key.frame = CGRect(
                x: CGFloat(index) * keyWidth + 2,
                y: 2,
                width: keyWidth - 4,
                height: bounds.height - 4
            )
        }
    }
    
    private func setupTapGestures() {
        for key in keys {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(keyTapped(_:)))
            key.addGestureRecognizer(tapGesture)
            key.isUserInteractionEnabled = true
        }
    }

    @objc private func keyTapped(_ gesture: UITapGestureRecognizer) {
        guard let key = gesture.view as? PianoKeyView else { return }
        
        UIView.animate(withDuration: 0.1, animations: {
            key.backgroundColor = .systemBlue
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                key.backgroundColor = .white
            }
        }
    }
    
}

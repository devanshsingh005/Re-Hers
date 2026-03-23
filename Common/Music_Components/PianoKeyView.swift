//
//  PianoKeyView.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import Foundation
import UIKit

class PianoKeyView: UIView {
    private let keyColor: UIColor
    
    init(isBlackKey: Bool = false) {
        self.keyColor = isBlackKey ? .black : .white
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.keyColor = .white
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = keyColor
        layer.borderWidth = 1
        layer.borderColor = UIColor.gray.cgColor
        layer.cornerRadius = 4
    }
}

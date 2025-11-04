//
//  ViewController.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardView()
    }

    private func setupKeyboardView() {
        let keyboardView = AnimatedKeyboardView()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        
        NSLayoutConstraint.activate([
            keyboardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            keyboardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            keyboardView.widthAnchor.constraint(equalToConstant: 300),
            keyboardView.heightAnchor.constraint(equalToConstant: 150)
        ])
    }


}


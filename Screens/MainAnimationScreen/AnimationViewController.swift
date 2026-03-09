import Foundation
import UIKit

final class AnimationViewController: UIViewController {

    private let topView = LessonNavBarView()
    private let sheetView = SheetMusicView()
    private let keyboardView = PianoKeyboardView()
    private let animationOverlay = AnimationOverlayView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLayout()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(topView)
        view.addSubview(sheetView)
        view.addSubview(keyboardView)
        view.addSubview(animationOverlay)
    }

    private func setupLayout() {
        [topView, sheetView, keyboardView, animationOverlay].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([

            // Top Controls
            topView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            topView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topView.leadingAnchor.constraint(equalTo: view.leadingAnchor,constant: 30),
            topView.trailingAnchor.constraint(equalTo: view.trailingAnchor,constant: -30),
           
            topView.heightAnchor.constraint(equalToConstant: 120),
           
            // Sheet Music
            sheetView.topAnchor.constraint(equalTo: topView.bottomAnchor, constant: 12),
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor,constant: 30),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor,constant: -30),
            sheetView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.35),

            // Keyboard
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor,constant: 30),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor,constant: -30),
            keyboardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            keyboardView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.32),

            // Animation overlay sits above sheet + keyboard
            animationOverlay.topAnchor.constraint(equalTo: sheetView.topAnchor),
            animationOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            animationOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            animationOverlay.bottomAnchor.constraint(equalTo: keyboardView.topAnchor)
        ])
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }

}


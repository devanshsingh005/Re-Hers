import UIKit

class SplashViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var topGradientView: UIView!
    @IBOutlet weak var getStartedButton: UIButton!
    @IBOutlet weak var appNameLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyGradient()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimation()
    }

    // MARK: - Setup
    private func setupUI() {
        topGradientView.alpha = 0
        getStartedButton.alpha = 0
        logoImageView.alpha = 0
        appNameLabel.alpha = 0
        logoImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        appNameLabel.transform = CGAffineTransform(translationX: 0, y: 20)

        // Button Styling
        getStartedButton.layer.cornerRadius = 24
        getStartedButton.backgroundColor = .secondaryColor
        getStartedButton.setTitleColor(.black, for: .normal)
        getStartedButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)

        // Add touch feedback
        getStartedButton.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        getStartedButton.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchDragExit, .touchCancel])
    }
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
        }
    }

    private func applyGradient() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.secondaryColor.cgColor,  // ✔ Updated
            UIColor.appBackground.cgColor    // ✔ Updated (.white replaced)
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.frame = topGradientView.bounds
        topGradientView.layer.insertSublayer(gradient, at: 0)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradient = topGradientView.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = topGradientView.bounds
        }
    }

    // MARK: - Animations
    private func startAnimation() {
        UIView.animate(withDuration: 0.8, delay: 0, options: [.curveEaseOut]) {
            self.logoImageView.alpha = 1
            self.logoImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.8, delay: 0.1, options: [.curveEaseInOut]) {
                let moveUp = CGAffineTransform(translationX: 0, y: -100)
                let scaleUp = CGAffineTransform(scaleX: 1.35, y: 1.35)
                self.logoImageView.transform = moveUp.concatenating(scaleUp)
            } completion: { _ in
                UIView.animate(withDuration: 0.7, delay: 0.1, options: [.curveEaseInOut]) {
                    self.appNameLabel.alpha = 1
                    self.appNameLabel.transform = .identity
                } completion: { _ in
                    UIView.animate(withDuration: 0.6, delay: 0.1, options: [.curveEaseInOut]) {
                        self.topGradientView.alpha = 1
                    } completion: { _ in
                        UIView.animate(withDuration: 0.5, delay: 0.2, options: [.curveEaseIn]) {
                            self.getStartedButton.alpha = 1
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions
    @IBAction func getStartedTapped(_ sender: UIButton) {
        goToMain()
    }

    private func goToMain() {
        guard let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }

        let homeVC = AuthViewController()

        UIView.transition(with: window,
                          duration: 0.6,
                          options: .transitionCrossDissolve,
                          animations: {
            window.rootViewController = homeVC
        })
    }
}

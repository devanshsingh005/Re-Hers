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
        appNameLabel.alpha = 0   // hide text initially
        logoImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        appNameLabel.transform = CGAffineTransform(translationX: 0, y: 20) // start slightly below

        // Button Styling
        getStartedButton.layer.cornerRadius = 24
        getStartedButton.layer.masksToBounds = true
        getStartedButton.backgroundColor = UIColor(red: 1.0, green: 0.73, blue: 0.35, alpha: 1.0)
        getStartedButton.setTitleColor(.black, for: .normal)
        getStartedButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    }


    private func applyGradient() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 1.0, green: 0.75, blue: 0.36, alpha: 1).cgColor,
            UIColor.white.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.frame = topGradientView.bounds
        topGradientView.layer.insertSublayer(gradient, at: 0)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure gradient layer resizes correctly on different screens
        if let gradient = topGradientView.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = topGradientView.bounds
        }
    }

    // MARK: - Animations
    private func startAnimation() {
        // Step 1: Fade in and enlarge the logo
        UIView.animate(withDuration: 0.8, delay: 0, options: [.curveEaseOut]) {
            self.logoImageView.alpha = 1
            self.logoImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        } completion: { _ in
            // Step 2: Move the logo upward while enlarging more
            UIView.animate(withDuration: 0.8, delay: 0.1, options: [.curveEaseInOut]) {
                let moveUp = CGAffineTransform(translationX: 0, y: -100)
                let scaleUp = CGAffineTransform(scaleX: 1.35, y: 1.35)
                self.logoImageView.transform = moveUp.concatenating(scaleUp)
            } completion: { _ in
                // Step 3: During this phase, fade in and slide up "Re-Hearse"
                UIView.animate(withDuration: 0.7, delay: 0.1, options: [.curveEaseInOut]) {
                    self.appNameLabel.alpha = 1
                    self.appNameLabel.transform = .identity
                } completion: { _ in
                    // Step 4: Reveal the gradient background behind
                    UIView.animate(withDuration: 0.6, delay: 0.1, options: [.curveEaseInOut]) {
                        self.topGradientView.alpha = 1
                    } completion: { _ in
                        // Step 5: Fade in the "Get Started" button
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

        let homeVC = MainTabBarController()

        UIView.transition(with: window,
                          duration: 0.6,
                          options: .transitionCrossDissolve,
                          animations: {
            window.rootViewController = homeVC
        })
    }

}

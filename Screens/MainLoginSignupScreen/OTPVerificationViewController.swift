//
//  OTPVerificationViewController.swift
//  Re-Hearse_v1
//

import Foundation
import UIKit
import Supabase
import Auth

private final class OTPDigitTextField: UITextField {
    var onBackspaceWhenEmpty: (() -> Void)?

    override func deleteBackward() {
        let wasEmpty = (text ?? "").isEmpty
        super.deleteBackward()
        if wasEmpty {
            onBackspaceWhenEmpty?()
        }
    }
}

final class OTPVerificationViewController: UIViewController, UITextFieldDelegate {
    private let email: String
    private let password: String

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let errorLabel = UILabel()
    private let verifyButton = UIButton(type: .system)
    private let resendButton = UIButton(type: .system)
    private let boxesStackView = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var digitFields: [OTPDigitTextField] = []
    private var resendTimer: Timer?
    private var resendSecondsRemaining = 30

    init(email: String, password: String) {
        self.email = email
        self.password = password
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        resendTimer?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.AuthScreen.background
        title = "Verify email"
        setupNavigation()
        setupUI()
        startResendCountdown()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        digitFields.first?.becomeFirstResponder()
    }

    private func setupNavigation() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = ComponentColors.AuthScreen.bodyText
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true

        contentView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Verify your email"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = ComponentColors.AuthScreen.headlineText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isHidden = false

        subtitleLabel.text = "We sent a 6-digit code to \(email)"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = ComponentColors.AuthScreen.bodyText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.isHidden = false

        boxesStackView.axis = .horizontal
        boxesStackView.alignment = .fill
        boxesStackView.distribution = .fillEqually
        boxesStackView.spacing = 10
        boxesStackView.translatesAutoresizingMaskIntoConstraints = false

        for index in 0..<6 {
            let field = OTPDigitTextField()
            field.translatesAutoresizingMaskIntoConstraints = false
            field.delegate = self
            field.tag = index
            field.keyboardType = .numberPad
            field.textAlignment = .center
            field.font = .monospacedDigitSystemFont(ofSize: 24, weight: .semibold)
            field.textColor = ComponentColors.AuthScreen.inputText
            field.tintColor = ComponentColors.AuthScreen.linkText
            field.backgroundColor = ComponentColors.AuthScreen.inputFill
            field.layer.cornerRadius = 14
            field.layer.borderWidth = 1
            field.layer.borderColor = ComponentColors.AuthScreen.inputBorder.cgColor
            field.onBackspaceWhenEmpty = { [weak self, weak field] in
                guard let self, let field else { return }
                guard field.tag > 0 else { return }
                let previousField = self.digitFields[field.tag - 1]
                previousField.text = ""
                previousField.becomeFirstResponder()
            }

            NSLayoutConstraint.activate([
                field.heightAnchor.constraint(equalToConstant: 56),
                field.widthAnchor.constraint(equalToConstant: 48)
            ])

            digitFields.append(field)
            boxesStackView.addArrangedSubview(field)
        }

        errorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        errorLabel.textColor = ComponentColors.AuthScreen.inputErrorText
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        verifyButton.setTitle("Verify", for: .normal)
        verifyButton.backgroundColor = ComponentColors.AuthScreen.ctaFill
        verifyButton.setTitleColor(ComponentColors.AuthScreen.ctaText, for: .normal)
        verifyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        verifyButton.layer.cornerRadius = 28
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        verifyButton.isHidden = false
        verifyButton.isEnabled = false
        verifyButton.alpha = 0.55

        resendButton.setTitleColor(ComponentColors.AuthScreen.linkText, for: .normal)
        resendButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        resendButton.addTarget(self, action: #selector(resendTapped), for: .touchUpInside)
        resendButton.translatesAutoresizingMaskIntoConstraints = false
        resendButton.isHidden = false

        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            boxesStackView,
            errorLabel,
            verifyButton,
            resendButton
        ])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(contentStack)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),

            verifyButton.heightAnchor.constraint(equalToConstant: 56),
            resendButton.heightAnchor.constraint(equalToConstant: 24),

            activityIndicator.centerXAnchor.constraint(equalTo: verifyButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: verifyButton.centerYAnchor)
        ])
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func verifyTapped() {
        let code = digitFields.compactMap(\.text).joined()
        guard code.count == 6 else {
            showError("Please enter the 6-digit code.")
            shakeBoxes()
            return
        }

        setLoading(true)
        errorLabel.isHidden = true

        Task {
            do {
                try await SupabaseManager.shared.client.auth.verifyOTP(
                    email: email,
                    token: code,
                    type: .signup
                )

                await MainActor.run {
                    setLoading(false)
                    AnalyticsManager.logOTPVerified()
                    routeAfterLogin()
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    handleVerificationError(error)
                }
            }
        }
    }
    
    @objc private func resendTapped() {
        guard resendSecondsRemaining == 0 else { return }

        setResendEnabled(false)
        errorLabel.isHidden = true

        Task {
            do {
                try await SupabaseManager.shared.client.auth.resend(
                    email: email,
                    type: .signup
                )

                await MainActor.run {
                    AnalyticsManager.logOTPResent()
                    startResendCountdown()
                    showToast(message: "Code resent")
                }
            } catch {
                await MainActor.run {
                    setResendEnabled(true)
                    showError("Could not resend. Please try again.")
                }
            }
        }
    }

    @MainActor
    private func routeAfterLogin() {
        if let authViewController = navigationController?.viewControllers.first(where: { $0 is AuthViewController }) as? AuthViewController {
            authViewController.routeAfterLogin()
        }
    }

    @MainActor
    private func handleVerificationError(_ error: Error) {
        let message = error.localizedDescription.lowercased()

        if message.contains("expired") {
            showError("Code expired. Tap Resend to get a new one.")
        } else if message.contains("invalid") || message.contains("token") || message.contains("otp") {
            showError("Invalid code. Please try again.")
            shakeBoxes()
        } else {
            showError("Account creation failed. Please try again.")
        }
    }

    @MainActor
    private func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    @MainActor
    private func setLoading(_ isLoading: Bool) {
        verifyButton.isEnabled = !isLoading && currentCode.count == 6
        verifyButton.alpha = verifyButton.isEnabled ? 1.0 : 0.55
        verifyButton.setTitle(isLoading ? nil : "Verify", for: .normal)
        isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    private var currentCode: String {
        digitFields.compactMap(\.text).joined()
    }

    @MainActor
    private func updateVerifyButtonState() {
        guard !activityIndicator.isAnimating else { return }
        verifyButton.isEnabled = currentCode.count == 6
        verifyButton.alpha = verifyButton.isEnabled ? 1.0 : 0.55
    }

    @MainActor
    private func shakeBoxes() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-12, 12, -8, 8, -4, 4, 0]
        animation.duration = 0.35
        boxesStackView.layer.add(animation, forKey: "shake")
    }

    @MainActor
    private func startResendCountdown() {
        resendTimer?.invalidate()
        resendSecondsRemaining = 30
        updateResendTitle()

        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.resendSecondsRemaining -= 1
                self.updateResendTitle()

                if self.resendSecondsRemaining <= 0 {
                    self.resendTimer?.invalidate()
                    self.resendTimer = nil
                    self.setResendEnabled(true)
                }
            }
        }

        setResendEnabled(false)
    }

    @MainActor
    private func updateResendTitle() {
        let title = resendSecondsRemaining > 0 ? "Resend in \(resendSecondsRemaining)s" : "Resend code"
        resendButton.setTitle(title, for: .normal)
    }

    @MainActor
    private func setResendEnabled(_ isEnabled: Bool) {
        resendButton.isEnabled = isEnabled
        resendButton.alpha = isEnabled ? 1 : 0.6
        updateResendTitle()
    }

    @MainActor
    private func showToast(message: String) {
        let toastLabel = PaddingLabel()
        toastLabel.text = message
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.textColor = ComponentColors.AuthScreen.ctaText
        toastLabel.backgroundColor = ComponentColors.AuthScreen.ctaFill
        toastLabel.layer.cornerRadius = 16
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0
        toastLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toastLabel)
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])

        UIView.animate(withDuration: 0.25, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.2, options: [], animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let digitField = textField as? OTPDigitTextField else { return true }

        if string.isEmpty {
            digitField.text = ""
            Task { @MainActor in
                self.updateVerifyButtonState()
            }
            return false
        }

        let digits = string.filter(\.isNumber)
        guard let digit = digits.last else { return false }

        digitField.text = String(digit)

        if digitField.tag < digitFields.count - 1 {
            digitFields[digitField.tag + 1].becomeFirstResponder()
        } else {
            digitField.resignFirstResponder()
        }

        Task { @MainActor in
            self.updateVerifyButtonState()
        }

        return false
    }
}

private final class PaddingLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 28, height: size.height + 20)
    }
}

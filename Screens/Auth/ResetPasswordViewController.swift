//
//  ResetPasswordViewController.swift
//  Re-Hearse_v1
//

import Foundation
import UIKit

final class ResetPasswordViewController: UIViewController {
    private let email: String
    private let passwordRecoveryService: PasswordRecoveryService

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let passwordTitleLabel = UILabel()
    private let confirmPasswordTitleLabel = UILabel()
    private let passwordContainerView = UIView()
    private let confirmPasswordContainerView = UIView()
    private let passwordTextField = UITextField()
    private let confirmPasswordTextField = UITextField()
    private let errorLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    init(
        email: String,
        passwordRecoveryService: PasswordRecoveryService = PasswordRecoveryService()
    ) {
        self.email = email
        self.passwordRecoveryService = passwordRecoveryService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.AuthScreen.background
        title = "Reset password"
        setupViews()
    }
}

private extension ResetPasswordViewController {
    func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        titleLabel.text = "Create a new password"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = ComponentColors.AuthScreen.headlineText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.text = "Choose a new password for \(email)"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = ComponentColors.AuthScreen.bodyText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        passwordTitleLabel.text = "New password"
        passwordTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        passwordTitleLabel.textColor = .label

        confirmPasswordTitleLabel.text = "Confirm new password"
        confirmPasswordTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        confirmPasswordTitleLabel.textColor = .label

        [passwordContainerView, confirmPasswordContainerView].forEach {
            $0.backgroundColor = ComponentColors.AuthScreen.inputFill
            $0.layer.cornerRadius = 14
            $0.layer.borderWidth = 1
            $0.layer.borderColor = ComponentColors.AuthScreen.inputBorder.cgColor
        }

        configureTextField(passwordTextField, placeholder: "*********", secure: true)
        configureTextField(confirmPasswordTextField, placeholder: "*********", secure: true)
        passwordTextField.textContentType = .newPassword
        confirmPasswordTextField.textContentType = .newPassword

        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.textColor = ComponentColors.AuthScreen.inputErrorText
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        primaryButton.setTitle("Update Password", for: .normal)
        primaryButton.backgroundColor = ComponentColors.AuthScreen.ctaFill
        primaryButton.setTitleColor(ComponentColors.AuthScreen.ctaText, for: .normal)
        primaryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        primaryButton.layer.cornerRadius = 28
        primaryButton.addTarget(self, action: #selector(updatePasswordTapped), for: .touchUpInside)

        activityIndicator.hidesWhenStopped = true

        [titleLabel,
         subtitleLabel,
         passwordTitleLabel,
         passwordContainerView,
         confirmPasswordTitleLabel,
         confirmPasswordContainerView,
         errorLabel,
         primaryButton,
         activityIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        passwordContainerView.addSubview(passwordTextField)
        confirmPasswordContainerView.addSubview(confirmPasswordTextField)

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

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            passwordTitleLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            passwordTitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            passwordTitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            passwordContainerView.topAnchor.constraint(equalTo: passwordTitleLabel.bottomAnchor, constant: 8),
            passwordContainerView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            passwordContainerView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            passwordContainerView.heightAnchor.constraint(equalToConstant: 44),

            passwordTextField.leadingAnchor.constraint(equalTo: passwordContainerView.leadingAnchor, constant: 12),
            passwordTextField.trailingAnchor.constraint(equalTo: passwordContainerView.trailingAnchor, constant: -12),
            passwordTextField.topAnchor.constraint(equalTo: passwordContainerView.topAnchor),
            passwordTextField.bottomAnchor.constraint(equalTo: passwordContainerView.bottomAnchor),

            confirmPasswordTitleLabel.topAnchor.constraint(equalTo: passwordContainerView.bottomAnchor, constant: 16),
            confirmPasswordTitleLabel.leadingAnchor.constraint(equalTo: passwordTitleLabel.leadingAnchor),
            confirmPasswordTitleLabel.trailingAnchor.constraint(equalTo: passwordTitleLabel.trailingAnchor),

            confirmPasswordContainerView.topAnchor.constraint(equalTo: confirmPasswordTitleLabel.bottomAnchor, constant: 8),
            confirmPasswordContainerView.leadingAnchor.constraint(equalTo: passwordContainerView.leadingAnchor),
            confirmPasswordContainerView.trailingAnchor.constraint(equalTo: passwordContainerView.trailingAnchor),
            confirmPasswordContainerView.heightAnchor.constraint(equalToConstant: 44),

            confirmPasswordTextField.leadingAnchor.constraint(equalTo: confirmPasswordContainerView.leadingAnchor, constant: 12),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: confirmPasswordContainerView.trailingAnchor, constant: -12),
            confirmPasswordTextField.topAnchor.constraint(equalTo: confirmPasswordContainerView.topAnchor),
            confirmPasswordTextField.bottomAnchor.constraint(equalTo: confirmPasswordContainerView.bottomAnchor),

            errorLabel.topAnchor.constraint(equalTo: confirmPasswordContainerView.bottomAnchor, constant: 16),
            errorLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            primaryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
            primaryButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            primaryButton.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 56),
            primaryButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

            activityIndicator.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: primaryButton.centerYAnchor)
        ])
    }

    func configureTextField(_ textField: UITextField, placeholder: String, secure: Bool) {
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = placeholder
        textField.isSecureTextEntry = secure
        textField.textColor = ComponentColors.AuthScreen.inputText
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.clearButtonMode = .whileEditing
    }

    @objc
    func updatePasswordTapped() {
        errorLabel.isHidden = true
        let password = InputValidator.limit(passwordTextField.text ?? "", maxLength: InputValidator.singleLineMaxLength)
        let confirmPassword = InputValidator.limit(confirmPasswordTextField.text ?? "", maxLength: InputValidator.singleLineMaxLength)
        passwordTextField.text = password
        confirmPasswordTextField.text = confirmPassword

        if let passwordError = InputValidator.validatePassword(password) {
            showError(passwordError)
            return
        }

        setLoading(true)
        Task {
            do {
                try await passwordRecoveryService.resetPassword(
                    newPassword: password,
                    confirmPassword: confirmPassword
                )

                await MainActor.run {
                    self.setLoading(false)
                    self.showSuccessAlert()
                }
            } catch let error as PasswordRecoveryService.ValidationError {
                await MainActor.run {
                    self.setLoading(false)
                    self.showError(error.localizedDescription)
                }
            } catch {
                await MainActor.run {
                    self.setLoading(false)
                    self.showError("We couldn't update your password right now. Please try again.")
                }
            }
        }
    }

    @MainActor
    func setLoading(_ isLoading: Bool) {
        primaryButton.isEnabled = !isLoading
        primaryButton.alpha = isLoading ? 0.55 : 1.0
        primaryButton.setTitle(isLoading ? nil : "Update Password", for: .normal)
        isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    @MainActor
    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    @MainActor
    func showSuccessAlert() {
        let alert = UIAlertController(
            title: "Password updated",
            message: "Your password has been updated. Please log in with your new password.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self else { return }
            if let authViewController = navigationController?.viewControllers.first(where: { $0 is AuthViewController }) {
                navigationController?.popToViewController(authViewController, animated: true)
            } else {
                navigationController?.popToRootViewController(animated: true)
            }
        })
        present(alert, animated: true)
    }
}

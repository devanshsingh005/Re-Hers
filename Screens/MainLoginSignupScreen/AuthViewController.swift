//
//  AuthViewController.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
import UIKit
import Supabase
import SwiftUI


final class AuthViewController: UIViewController {
    
    // MARK: - Constants
    private let primaryOrangeColor = UIColor(red: 1.0, green: 0.702, blue: 0.0, alpha: 1.0)
    
    // MARK: - Constraint Storage
    private var signupConstraints: [NSLayoutConstraint] = []
    private var primaryButtonLoginConstraint: NSLayoutConstraint?
    private var primaryButtonSignupConstraint: NSLayoutConstraint?
    
    // MARK: - UI elements
    
    // Scroll view
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Top title
    private let appTitleLabel = UILabel()
    private let screenTitleLabel = UILabel()       // "Sign In" / "Sign Up"
    
    // Segmented control (kept hidden if you want later)
    private let modeSegment = UISegmentedControl(items: ["Login", "Sign Up"])
    
    private let emailTitleLabel = UILabel()
    private let passwordTitleLabel = UILabel()
    
    private let emailContainerView = UIView()
    private let passwordContainerView = UIView()
    
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let passwordToggleButton = UIButton(type: .system)
    
    // SIGN UP EXTRA FIELDS
    private let fullNameTitleLabel = UILabel()
    private let usernameTitleLabel = UILabel()
    private let confirmPasswordTitleLabel = UILabel()
    
    private let fullNameContainerView = UIView()
    private let usernameContainerView = UIView()
    private let confirmPasswordContainerView = UIView()
    
    private let fullNameTextField = UITextField()
    private let usernameTextField = UITextField()
    private let confirmPasswordTextField = UITextField()
    
    private let forgotPasswordButton = UIButton(type: .system)
    
    private let primaryButton = UIButton(type: .system)   // "NEXT" / "Sign Up"
    
    // Separator "Or"
    private let leftSeparatorLine = UIView()
    private let rightSeparatorLine = UIView()
    private let orLabel = UILabel()
    
    // Social buttons (UI only for now)
    private let appleButton = UIButton(type: .system)
    private let googleButton = UIButton(type: .system)
    private let facebookButton = UIButton(type: .system)
    
    // Bottom toggle ("Create a Account" / "Already have an account?")
    private let switchModeButton = UIButton(type: .system)
    
    private let errorLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    private var isLoginMode: Bool {
        modeSegment.selectedSegmentIndex == 0
    }
    
    // iPad-responsive margins
    private var horizontalMargin: CGFloat {
        let width = view.bounds.width
        if width > 1000 { // iPad Pro
            return 80
        } else if width > 768 { // iPad
            return 60
        } else { // iPhone
            return 32
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // default to LOGIN (design in screenshot)
        modeSegment.selectedSegmentIndex = 0
        
        setupViews()
        updateTextsForMode()
    }
}

// MARK: - UI Setup

private extension AuthViewController {
    
    func setupViews() {
        // MARK: - Top titles
        
        appTitleLabel.text = "RE-HEARSE"
        appTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        appTitleLabel.textAlignment = .center
        appTitleLabel.textColor = UIColor(named: "TextPrimary") ?? .label
        
        screenTitleLabel.text = "Sign In"
        screenTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        screenTitleLabel.textAlignment = .center
        screenTitleLabel.textColor = .secondaryLabel
        
        // MARK: - Email / password labels
        
        emailTitleLabel.text = "Email"
        emailTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        emailTitleLabel.textColor = .label
        
        passwordTitleLabel.text = "Password"
        passwordTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        passwordTitleLabel.textColor = .label
        
        // SIGN UP LABELS
        fullNameTitleLabel.text = "Full Name"
        fullNameTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        fullNameTitleLabel.textColor = .label
        
        usernameTitleLabel.text = "Username"
        usernameTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        usernameTitleLabel.textColor = .label
        
        confirmPasswordTitleLabel.text = "Confirm Password"
        confirmPasswordTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        confirmPasswordTitleLabel.textColor = .label
        
        // Container style (rounded rectangle like screenshot)
        [emailContainerView,
         passwordContainerView,
         fullNameContainerView,
         usernameContainerView,
         confirmPasswordContainerView].forEach {
            configureContainerView($0)
        }
        
        // MARK: - Text fields
        
        configureTextField(emailTextField,
                           placeholder: "Enter your email",
                           keyboard: .emailAddress,
                           secure: false)
        
        configureTextField(passwordTextField,
                           placeholder: "*********",
                           keyboard: .default,
                           secure: true)
        
        configureTextField(fullNameTextField,
                           placeholder: "Enter your full name",
                           keyboard: .default,
                           secure: false)
        
        configureTextField(usernameTextField,
                           placeholder: "Choose a username",
                           keyboard: .default,
                           secure: false)
        
        configureTextField(confirmPasswordTextField,
                           placeholder: "*********",
                           keyboard: .default,
                           secure: true)
        
        // Padding inside textfield
        [emailTextField,
         passwordTextField,
         fullNameTextField,
         usernameTextField,
         confirmPasswordTextField].forEach { addLeftPadding(to: $0) }
        
        // Eye button for password
        passwordToggleButton.setImage(UIImage(systemName: "eye"), for: .normal)
        passwordToggleButton.tintColor = .systemGray2
        passwordToggleButton.addTarget(self,
                                       action: #selector(togglePasswordVisibility),
                                       for: .touchUpInside)
        passwordToggleButton.translatesAutoresizingMaskIntoConstraints = false
        
        passwordContainerView.addSubview(passwordTextField)
        passwordContainerView.addSubview(passwordToggleButton)
        
        emailTextField.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        
        fullNameTextField.translatesAutoresizingMaskIntoConstraints = false
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        confirmPasswordTextField.translatesAutoresizingMaskIntoConstraints = false
        
        fullNameContainerView.addSubview(fullNameTextField)
        usernameContainerView.addSubview(usernameTextField)
        confirmPasswordContainerView.addSubview(confirmPasswordTextField)
        
        // MARK: - Forgot password
        
        forgotPasswordButton.setTitle("Forgot Password ?", for: .normal)
        forgotPasswordButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        forgotPasswordButton.setTitleColor(primaryOrangeColor, for: .normal)
        forgotPasswordButton.contentHorizontalAlignment = .right
        forgotPasswordButton.addTarget(self,
                                       action: #selector(forgotPasswordTapped),
                                       for: .touchUpInside)
        
        // MARK: - Primary button
        
        primaryButton.setTitle("NEXT", for: .normal)
        primaryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        primaryButton.backgroundColor = primaryOrangeColor
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.layer.cornerRadius = 8
        primaryButton.addTarget(self,
                                action: #selector(primaryButtonTapped),
                                for: .touchUpInside)
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        
        // MARK: - Separator "Or"
        
        leftSeparatorLine.backgroundColor = UIColor.systemGray4
        rightSeparatorLine.backgroundColor = UIColor.systemGray4
        
        orLabel.text = "Or"
        orLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        orLabel.textColor = .systemGray
        
        [leftSeparatorLine, rightSeparatorLine, orLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // MARK: - Social buttons
        
        configureSocialButton(appleButton,
                              title: "Continue with Apple",
                              systemImageName: "apple.logo")
        configureSocialButton(googleButton,
                              title: "Continue with Google",
                              systemImageName: "g.circle")
        configureSocialButton(facebookButton,
                              title: "Continue with Facebook",
                              systemImageName: "f.circle")
        
        // MARK: - Bottom switch mode
        
        switchModeButton.setTitle("Create a Account", for: .normal)
        switchModeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        switchModeButton.setTitleColor(.darkGray, for: .normal)
        switchModeButton.addTarget(self,
                                   action: #selector(switchModeTapped),
                                   for: .touchUpInside)
        
        // MARK: - Error + Activity
        
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true
        
        activityIndicator.hidesWhenStopped = true
        
        // MARK: - Add subviews
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        [appTitleLabel,
         screenTitleLabel,
         emailTitleLabel,
         emailContainerView,
         passwordTitleLabel,
         passwordContainerView,
         fullNameTitleLabel,
         fullNameContainerView,
         usernameTitleLabel,
         usernameContainerView,
         confirmPasswordTitleLabel,
         confirmPasswordContainerView,
         forgotPasswordButton,
         primaryButton,
         leftSeparatorLine,
         orLabel,
         rightSeparatorLine,
         appleButton,
         googleButton,
         facebookButton,
         errorLabel,
         activityIndicator,
         switchModeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        // email textfield inside container
        emailContainerView.addSubview(emailTextField)
        
        // Store signup field constraints for toggling
        signupConstraints = [
            fullNameTitleLabel.topAnchor.constraint(equalTo: passwordContainerView.bottomAnchor, constant: 16),
            fullNameTitleLabel.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            fullNameTitleLabel.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            
            fullNameContainerView.topAnchor.constraint(equalTo: fullNameTitleLabel.bottomAnchor, constant: 8),
            fullNameContainerView.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            fullNameContainerView.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            fullNameContainerView.heightAnchor.constraint(equalToConstant: 44),
            
            fullNameTextField.leadingAnchor.constraint(equalTo: fullNameContainerView.leadingAnchor, constant: 12),
            fullNameTextField.trailingAnchor.constraint(equalTo: fullNameContainerView.trailingAnchor, constant: -12),
            fullNameTextField.topAnchor.constraint(equalTo: fullNameContainerView.topAnchor),
            fullNameTextField.bottomAnchor.constraint(equalTo: fullNameContainerView.bottomAnchor),
            
            usernameTitleLabel.topAnchor.constraint(equalTo: fullNameContainerView.bottomAnchor, constant: 16),
            usernameTitleLabel.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            usernameTitleLabel.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            
            usernameContainerView.topAnchor.constraint(equalTo: usernameTitleLabel.bottomAnchor, constant: 8),
            usernameContainerView.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            usernameContainerView.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            usernameContainerView.heightAnchor.constraint(equalToConstant: 44),
            
            usernameTextField.leadingAnchor.constraint(equalTo: usernameContainerView.leadingAnchor, constant: 12),
            usernameTextField.trailingAnchor.constraint(equalTo: usernameContainerView.trailingAnchor, constant: -12),
            usernameTextField.topAnchor.constraint(equalTo: usernameContainerView.topAnchor),
            usernameTextField.bottomAnchor.constraint(equalTo: usernameContainerView.bottomAnchor),
            
            confirmPasswordTitleLabel.topAnchor.constraint(equalTo: usernameContainerView.bottomAnchor, constant: 16),
            confirmPasswordTitleLabel.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            confirmPasswordTitleLabel.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            
            confirmPasswordContainerView.topAnchor.constraint(equalTo: confirmPasswordTitleLabel.bottomAnchor, constant: 8),
            confirmPasswordContainerView.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            confirmPasswordContainerView.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            confirmPasswordContainerView.heightAnchor.constraint(equalToConstant: 44),
            
            confirmPasswordTextField.leadingAnchor.constraint(equalTo: confirmPasswordContainerView.leadingAnchor, constant: 12),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: confirmPasswordContainerView.trailingAnchor, constant: -12),
            confirmPasswordTextField.topAnchor.constraint(equalTo: confirmPasswordContainerView.topAnchor),
            confirmPasswordTextField.bottomAnchor.constraint(equalTo: confirmPasswordContainerView.bottomAnchor),
        ]
        
        // Container constraints
        NSLayoutConstraint.activate([
            appTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            appTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            appTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            
            screenTitleLabel.topAnchor.constraint(equalTo: appTitleLabel.bottomAnchor, constant: 16),
            screenTitleLabel.centerXAnchor.constraint(equalTo: appTitleLabel.centerXAnchor),
            
            emailTitleLabel.topAnchor.constraint(equalTo: screenTitleLabel.bottomAnchor, constant: 32),
            emailTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            emailTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            
            emailContainerView.topAnchor.constraint(equalTo: emailTitleLabel.bottomAnchor, constant: 8),
            emailContainerView.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            emailContainerView.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            emailContainerView.heightAnchor.constraint(equalToConstant: 44),
            
            emailTextField.leadingAnchor.constraint(equalTo: emailContainerView.leadingAnchor, constant: 12),
            emailTextField.trailingAnchor.constraint(equalTo: emailContainerView.trailingAnchor, constant: -12),
            emailTextField.topAnchor.constraint(equalTo: emailContainerView.topAnchor),
            emailTextField.bottomAnchor.constraint(equalTo: emailContainerView.bottomAnchor),
            
            passwordTitleLabel.topAnchor.constraint(equalTo: emailContainerView.bottomAnchor, constant: 16),
            passwordTitleLabel.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            passwordTitleLabel.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            
            passwordContainerView.topAnchor.constraint(equalTo: passwordTitleLabel.bottomAnchor, constant: 8),
            passwordContainerView.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            passwordContainerView.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            passwordContainerView.heightAnchor.constraint(equalToConstant: 44),
            
            passwordTextField.leadingAnchor.constraint(equalTo: passwordContainerView.leadingAnchor, constant: 12),
            passwordTextField.trailingAnchor.constraint(equalTo: passwordToggleButton.leadingAnchor, constant: -8),
            passwordTextField.topAnchor.constraint(equalTo: passwordContainerView.topAnchor),
            passwordTextField.bottomAnchor.constraint(equalTo: passwordContainerView.bottomAnchor),
            
            passwordToggleButton.centerYAnchor.constraint(equalTo: passwordContainerView.centerYAnchor),
            passwordToggleButton.trailingAnchor.constraint(equalTo: passwordContainerView.trailingAnchor, constant: -12),
            passwordToggleButton.widthAnchor.constraint(equalToConstant: 24),
            passwordToggleButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Forgot Password (only visible in login)
            forgotPasswordButton.topAnchor.constraint(equalTo: passwordContainerView.bottomAnchor, constant: 12),
            forgotPasswordButton.trailingAnchor.constraint(equalTo: passwordContainerView.trailingAnchor),
            forgotPasswordButton.leadingAnchor.constraint(greaterThanOrEqualTo: passwordContainerView.leadingAnchor),
        ])
        
        // Primary button constraints (will be toggled between login/signup mode)
        primaryButtonLoginConstraint = primaryButton.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 16)
        primaryButtonSignupConstraint = primaryButton.topAnchor.constraint(equalTo: confirmPasswordContainerView.bottomAnchor, constant: 24)
        
        // ScrollView and ContentView constraints
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
        ])
        
        NSLayoutConstraint.activate([
            primaryButtonLoginConstraint!,
            primaryButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            primaryButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            primaryButton.heightAnchor.constraint(equalToConstant: 55),
            
            
            activityIndicator.topAnchor.constraint(equalTo: primaryButton.bottomAnchor, constant: 8),
            activityIndicator.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),
            
            errorLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 4),
            errorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            errorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            
            leftSeparatorLine.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 24),
            leftSeparatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            leftSeparatorLine.heightAnchor.constraint(equalToConstant: 1),
            
            orLabel.centerYAnchor.constraint(equalTo: leftSeparatorLine.centerYAnchor),
            orLabel.leadingAnchor.constraint(equalTo: leftSeparatorLine.trailingAnchor, constant: 8),
            
            rightSeparatorLine.leadingAnchor.constraint(equalTo: orLabel.trailingAnchor, constant: 8),
            rightSeparatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            rightSeparatorLine.centerYAnchor.constraint(equalTo: orLabel.centerYAnchor),
            rightSeparatorLine.heightAnchor.constraint(equalToConstant: 1),
            
            appleButton.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: 24),
            appleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            appleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            appleButton.heightAnchor.constraint(equalToConstant: 48),
            
            googleButton.topAnchor.constraint(equalTo: appleButton.bottomAnchor, constant: 12),
            googleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            googleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            googleButton.heightAnchor.constraint(equalToConstant: 48),
            
            facebookButton.topAnchor.constraint(equalTo: googleButton.bottomAnchor, constant: 12),
            facebookButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            facebookButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            facebookButton.heightAnchor.constraint(equalToConstant: 48),
            
            switchModeButton.topAnchor.constraint(equalTo: facebookButton.bottomAnchor, constant: 24),
            switchModeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            switchModeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    func configureContainerView(_ v: UIView) {
        v.backgroundColor = .white
        v.layer.cornerRadius = 6
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.systemGray4.cgColor
    }
    
    func configureTextField(_ tf: UITextField,
                            placeholder: String,
                            keyboard: UIKeyboardType,
                            secure: Bool) {
        tf.placeholder = placeholder
        tf.keyboardType = keyboard
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.isSecureTextEntry = secure
        tf.clearButtonMode = .whileEditing
        tf.borderStyle = .none
        tf.font = UIFont.systemFont(ofSize: 14)
    }
    
    func addLeftPadding(to textField: UITextField) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 10))
        textField.leftView = paddingView
        textField.leftViewMode = .always
    }
    
    func configureSocialButton(_ button: UIButton,
                               title: String,
                               systemImageName: String) {
        button.setTitle("  " + title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.contentHorizontalAlignment = .center
        
        let image = UIImage(systemName: systemImageName)
        button.setImage(image, for: .normal)
        
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func updateTextsForMode() {
        let showSignupFields = !isLoginMode
        
        fullNameTitleLabel.isHidden = !showSignupFields
        fullNameContainerView.isHidden = !showSignupFields
        usernameTitleLabel.isHidden = !showSignupFields
        usernameContainerView.isHidden = !showSignupFields
        confirmPasswordTitleLabel.isHidden = !showSignupFields
        confirmPasswordContainerView.isHidden = !showSignupFields
        
        // Toggle forgot password visibility
        forgotPasswordButton.isHidden = !isLoginMode
        
        // Toggle primary button constraint
        if showSignupFields {
            primaryButtonLoginConstraint?.isActive = false
            primaryButtonSignupConstraint?.isActive = true
            NSLayoutConstraint.activate(signupConstraints)
        } else {
            primaryButtonLoginConstraint?.isActive = true
            primaryButtonSignupConstraint?.isActive = false
            NSLayoutConstraint.deactivate(signupConstraints)
        }
        
        screenTitleLabel.text = isLoginMode ? "Sign In" : "Sign Up"
        primaryButton.setTitle(isLoginMode ? "NEXT" : "Sign Up", for: .normal)
        switchModeButton.setTitle(isLoginMode ? "Create a Account" : "Already have an account? Sign In", for: .normal)
        
        errorLabel.isHidden = true
        
        // Animate layout change
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - Actions

private extension AuthViewController {
    
    @objc func togglePasswordVisibility() {
        passwordTextField.isSecureTextEntry.toggle()
        let imgName = passwordTextField.isSecureTextEntry ? "eye" : "eye.slash"
        passwordToggleButton.setImage(UIImage(systemName: imgName), for: .normal)
    }
    
    @objc func switchModeTapped() {
        // Flip between Login / Sign Up without changing functionality
        modeSegment.selectedSegmentIndex = isLoginMode ? 1 : 0
        updateTextsForMode()
    }
    
    @objc func forgotPasswordTapped() {
        guard let email = emailTextField.text, !email.isEmpty else {
            showError("Please enter your email first.")
            return
        }
        
        Task {
            do {
                try await SupabaseManager.shared.client.auth.resetPasswordForEmail(email)
                await MainActor.run {
                    self.showError("Password reset email sent. Check your inbox.")
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to send reset email: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc func primaryButtonTapped() {
        view.endEditing(true)
        errorLabel.isHidden = true
        
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showError("Please enter both email and password.")
            return
        }
        
        if !isLoginMode {
            // extra validations for sign up
            guard let fullName = fullNameTextField.text, !fullName.isEmpty,
                  let username = usernameTextField.text, !username.isEmpty else {
                showError("Please enter full name and username.")
                return
            }
            
            guard let confirm = confirmPasswordTextField.text, confirm == password else {
                showError("Passwords do not match.")
                return
            }
        }
        
        primaryButton.isEnabled = false
        activityIndicator.startAnimating()
        
        Task {
            do {
                if isLoginMode {
                    try await login(email: email, password: password)
                } else {
                    try await signUp(email: email, password: password)
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
            
            await MainActor.run {
                self.activityIndicator.stopAnimating()
                self.primaryButton.isEnabled = true
            }
        }
    }
}

// MARK: - Supabase Auth

private extension AuthViewController {
    
    func login(email: String, password: String) async throws {
        let client = SupabaseManager.shared.client
        
        _ = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        await MainActor.run {
            self.routeAfterLogin()

        }
    }
    
    func signUp(email: String, password: String) async throws {
        let client = SupabaseManager.shared.client
        
        let fullName = fullNameTextField.text ?? ""
        let username = usernameTextField.text ?? ""
        
        guard !fullName.isEmpty, !username.isEmpty else {
            await MainActor.run {
                self.showError("Please enter full name and username.")
            }
            return
        }
        
        // Send metadata so trigger can use it
        let result = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "full_name": .string(fullName),
                "username": .string(username)
            ]
        )
        
        // ⛔️ IMPORTANT: remove manual insert into profiles here.
        // The trigger now handles profile creation.

        print("SIGNUP RESULT:", result)
        
        if result.session != nil {
            // Email confirm OFF -> user already logged in
            await MainActor.run {
                self.routeAfterLogin()

            }
        } else {
            // Email confirm ON -> user must verify, but profile row is already created by trigger
            await MainActor.run {
                self.showError("Account created. Please check your email to verify.")
            }
        }
    }

    
    
    @MainActor
    func showHomeScreen() {
        let home = MainTabBarController()
        home.modalPresentationStyle = .fullScreen
        present(home, animated: true)
    }

    
    @MainActor
    func showError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }
    @MainActor
    func routeAfterLogin() {
        Task {
            do {
                let client = SupabaseManager.shared.client
                let session = try await client.auth.session
                let userId = session.user.id.uuidString

                // Query user_onboarding
                let response = try await client
                    .from("user_onboarding")
                    .select()
                    .eq("id", value: userId)
                    .single()
                    .execute()

                // If record exists → go home
                showHomeScreen()
            } catch {
                // If .single() fails → no onboarding data → start onboarding
                showOnboardingFlow()
            }
        }
    }
    @MainActor
   
    func showOnboardingFlow() {
        let onboardingVC = UIHostingController(rootView: OnboardingFlowRoot())
        onboardingVC.modalPresentationStyle = .fullScreen
        present(onboardingVC, animated: true)
    }



}

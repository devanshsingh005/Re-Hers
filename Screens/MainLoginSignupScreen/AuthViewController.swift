//
//  AuthViewController.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
import UIKit
import Supabase

final class AuthViewController: UIViewController {
    
    // MARK: - UI elements
    
    // Top title
    private let appTitleLabel = UILabel()
    private let screenTitleLabel = UILabel()       // "Sign In" / "Sign Up"
    
    // We keep the segmented control only to preserve the
    // login / signup logic, but we don't show it.
    private let modeSegment = UISegmentedControl(items: ["Login", "Sign Up"])
    
    private let emailTitleLabel = UILabel()
    private let passwordTitleLabel = UILabel()
    
    private let emailContainerView = UIView()
    private let passwordContainerView = UIView()
    
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let passwordToggleButton = UIButton(type: .system)
    
    private let forgotPasswordButton = UIButton(type: .system)
    
    private let primaryButton = UIButton(type: .system)   // "NEXT" / "Sign Up"
    
    // Separator "Or"
    private let leftSeparatorLine = UIView()
    private let rightSeparatorLine = UIView()
    private let orLabel = UILabel()
    
    // Social buttons
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
        
        // Container style (rounded rectangle like screenshot)
        configureContainerView(emailContainerView)
        configureContainerView(passwordContainerView)
        
        // MARK: - Text fields
        
        configureTextField(emailTextField,
                           placeholder: "Enter your email",
                           keyboard: .emailAddress,
                           secure: false)
        
        configureTextField(passwordTextField,
                           placeholder: "*********",
                           keyboard: .default,
                           secure: true)
        
        // Padding inside textfield
        addLeftPadding(to: emailTextField)
        addLeftPadding(to: passwordTextField)
        
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
        
        // MARK: - Forgot password
        
        forgotPasswordButton.setTitle("Forgot Password ?", for: .normal)
        forgotPasswordButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        forgotPasswordButton.setTitleColor(UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1.0),
                                           for: .normal) // orange-ish
        forgotPasswordButton.contentHorizontalAlignment = .right
        // (No extra functionality required yet)
        
        // MARK: - Primary button
        
        primaryButton.setTitle("NEXT", for: .normal)
        primaryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        primaryButton.backgroundColor = UIColor(red: 1.0, green: 0.70, blue: 0.20, alpha: 1.0)
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
        
        // MARK: - Layout
        
        [appTitleLabel,
         screenTitleLabel,
         emailTitleLabel,
         emailContainerView,
         passwordTitleLabel,
         passwordContainerView,
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
            view.addSubview($0)
        }
        
        // email textfield inside container
        emailContainerView.addSubview(emailTextField)
        
        // Container constraints
        NSLayoutConstraint.activate([
            appTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            appTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            appTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            screenTitleLabel.topAnchor.constraint(equalTo: appTitleLabel.bottomAnchor, constant: 16),
            screenTitleLabel.centerXAnchor.constraint(equalTo: appTitleLabel.centerXAnchor),
            
            emailTitleLabel.topAnchor.constraint(equalTo: screenTitleLabel.bottomAnchor, constant: 40),
            emailTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emailTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            emailContainerView.topAnchor.constraint(equalTo: emailTitleLabel.bottomAnchor, constant: 8),
            emailContainerView.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            emailContainerView.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            emailContainerView.heightAnchor.constraint(equalToConstant: 44),
            
            emailTextField.leadingAnchor.constraint(equalTo: emailContainerView.leadingAnchor, constant: 12),
            emailTextField.trailingAnchor.constraint(equalTo: emailContainerView.trailingAnchor, constant: -12),
            emailTextField.topAnchor.constraint(equalTo: emailContainerView.topAnchor),
            emailTextField.bottomAnchor.constraint(equalTo: emailContainerView.bottomAnchor),
            
            passwordTitleLabel.topAnchor.constraint(equalTo: emailContainerView.bottomAnchor, constant: 20),
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
            
            forgotPasswordButton.topAnchor.constraint(equalTo: passwordContainerView.bottomAnchor, constant: 6),
            forgotPasswordButton.trailingAnchor.constraint(equalTo: passwordContainerView.trailingAnchor),
            
            primaryButton.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 20),
            primaryButton.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            primaryButton.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 48),
            
            activityIndicator.topAnchor.constraint(equalTo: primaryButton.bottomAnchor, constant: 8),
            activityIndicator.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),
            
            errorLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 4),
            errorLabel.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            
            leftSeparatorLine.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 24),
            leftSeparatorLine.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            leftSeparatorLine.heightAnchor.constraint(equalToConstant: 1),
            
            orLabel.centerYAnchor.constraint(equalTo: leftSeparatorLine.centerYAnchor),
            orLabel.leadingAnchor.constraint(equalTo: leftSeparatorLine.trailingAnchor, constant: 8),
            
            rightSeparatorLine.leadingAnchor.constraint(equalTo: orLabel.trailingAnchor, constant: 8),
            rightSeparatorLine.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            rightSeparatorLine.centerYAnchor.constraint(equalTo: orLabel.centerYAnchor),
            rightSeparatorLine.heightAnchor.constraint(equalToConstant: 1),
            
            leftSeparatorLine.trailingAnchor.constraint(equalTo: orLabel.leadingAnchor, constant: -8),
            
            appleButton.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: 24),
            appleButton.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            appleButton.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
            appleButton.heightAnchor.constraint(equalToConstant: 48),
            
            googleButton.topAnchor.constraint(equalTo: appleButton.bottomAnchor, constant: 12),
            googleButton.leadingAnchor.constraint(equalTo: appleButton.leadingAnchor),
            googleButton.trailingAnchor.constraint(equalTo: appleButton.trailingAnchor),
            googleButton.heightAnchor.constraint(equalToConstant: 48),
            
            facebookButton.topAnchor.constraint(equalTo: googleButton.bottomAnchor, constant: 12),
            facebookButton.leadingAnchor.constraint(equalTo: appleButton.leadingAnchor),
            facebookButton.trailingAnchor.constraint(equalTo: appleButton.trailingAnchor),
            facebookButton.heightAnchor.constraint(equalToConstant: 48),
            
            switchModeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            switchModeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
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
        if isLoginMode {
            screenTitleLabel.text = "Sign In"
            primaryButton.setTitle("NEXT", for: .normal)
            switchModeButton.setTitle("Create a Account", for: .normal)
        } else {
            screenTitleLabel.text = "Sign Up"
            primaryButton.setTitle("Sign Up", for: .normal)
            switchModeButton.setTitle("Already have an account? Sign In", for: .normal)
        }
        errorLabel.isHidden = true
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
    
    @objc func primaryButtonTapped() {
        view.endEditing(true)
        errorLabel.isHidden = true
        
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showError("Please enter both email and password.")
            return
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
        
        showHomeScreen()
    }
    
    func signUp(email: String, password: String) async throws {
        let client = SupabaseManager.shared.client
        
        let result = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        print("SIGNUP RESULT:", result)
        
        if let _ = result.session {
            showHomeScreen()
        } else {
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
}

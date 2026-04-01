//
//  AuthViewController.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
import UIKit
import Supabase
import Auth
import SwiftUI


final class AuthViewController: UIViewController {
    enum AuthMode {
        case logIn
        case signUp
    }
    
    // MARK: - Constraint Storage
    private var loginFieldConstraints: [NSLayoutConstraint] = []
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
    private let legalAgreementButton = UIButton(type: .system)
    private let legalAgreementTextView = UITextView()
    private var hasAcceptedSignupLegal = false
    
    private let forgotPasswordButton = UIButton(type: .system)
    
    private let primaryButton = UIButton(type: .system)   // "NEXT" / "Sign Up"
    
    // Bottom toggle ("Create a Account" / "Already have an account?")
    private let switchModeButton = UIButton(type: .system)
    
    private let errorLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let initialMode: AuthMode
    
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

    init(initialMode: AuthMode = .logIn) {
        self.initialMode = initialMode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = ComponentColors.AuthScreen.background
        
        modeSegment.selectedSegmentIndex = initialMode == .logIn ? 0 : 1
        
        setupViews()
        updateTextsForMode()
    }
}

// MARK: - UI Setup

private extension AuthViewController {
    
    func setupViews() {
        // MARK: - Top titles
        
        appTitleLabel.text = "Rehearse"
        appTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        appTitleLabel.textAlignment = .center
        appTitleLabel.textColor = ComponentColors.AuthScreen.headlineText
        
        screenTitleLabel.text = "Sign In"
        screenTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        screenTitleLabel.textAlignment = .center
        screenTitleLabel.textColor = ComponentColors.AuthScreen.bodyText
        
        // MARK: - Email / password labels
        
        emailTitleLabel.text = "Email address"
        emailTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        emailTitleLabel.textColor = .label
        
        passwordTitleLabel.text = "Password"
        passwordTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        passwordTitleLabel.textColor = .label
        
        // SIGN UP LABELS
        fullNameTitleLabel.text = "Full name"
        fullNameTitleLabel.textColor = ComponentColors.AuthScreen.inputText
        fullNameTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        
        usernameTitleLabel.text = "Username"
        usernameTitleLabel.textColor = ComponentColors.AuthScreen.inputText
        usernameTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        
        confirmPasswordTitleLabel.text = "Confirm password"
        confirmPasswordTitleLabel.textColor = ComponentColors.AuthScreen.inputText
        confirmPasswordTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)

        legalAgreementButton.setImage(UIImage(systemName: "square"), for: .normal)
        legalAgreementButton.tintColor = ComponentColors.AuthScreen.bodyText
        legalAgreementButton.contentVerticalAlignment = .top
        legalAgreementButton.addTarget(self, action: #selector(toggleLegalAgreement), for: .touchUpInside)
        legalAgreementButton.translatesAutoresizingMaskIntoConstraints = false

        legalAgreementTextView.backgroundColor = .clear
        legalAgreementTextView.isEditable = false
        legalAgreementTextView.isScrollEnabled = false
        legalAgreementTextView.textContainerInset = .zero
        legalAgreementTextView.textContainer.lineFragmentPadding = 0
        legalAgreementTextView.delegate = self
        legalAgreementTextView.linkTextAttributes = [
            .foregroundColor: ComponentColors.AuthScreen.linkText,
            .font: UIFont.systemFont(ofSize: 13, weight: .regular)
        ]
        legalAgreementTextView.attributedText = legalAgreementAttributedText()
        legalAgreementTextView.translatesAutoresizingMaskIntoConstraints = false
        
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
        passwordToggleButton.tintColor = SemanticColors.Icon.inactive
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
        forgotPasswordButton.setTitleColor(ComponentColors.AuthScreen.linkText, for: .normal)
        forgotPasswordButton.contentHorizontalAlignment = .right
        forgotPasswordButton.addTarget(self,
                                       action: #selector(forgotPasswordTapped),
                                       for: .touchUpInside)
        
        // MARK: - Primary button
        
        primaryButton.setTitle("Sign Up", for: .normal)
        primaryButton.backgroundColor = ComponentColors.AuthScreen.ctaFill
        primaryButton.setTitleColor(ComponentColors.AuthScreen.ctaText, for: .normal)
        primaryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        primaryButton.layer.cornerRadius = 28 // Unified pill shape
        primaryButton.addTarget(self,
                                action: #selector(primaryButtonTapped),
                                for: .touchUpInside)
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        
        // MARK: - Bottom switch mode
        
        switchModeButton.setTitle("Create a Account", for: .normal)
        switchModeButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        switchModeButton.setTitleColor(ComponentColors.AuthScreen.bodyText, for: .normal)
        switchModeButton.addTarget(self,
                                   action: #selector(switchModeTapped),
                                   for: .touchUpInside)
        
        // MARK: - Error + Activity
        
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.textColor = ComponentColors.AuthScreen.inputErrorText
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
         legalAgreementButton,
         legalAgreementTextView,
         forgotPasswordButton,
         primaryButton,
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
            fullNameTitleLabel.topAnchor.constraint(equalTo: screenTitleLabel.bottomAnchor, constant: 32),
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
            
            emailTitleLabel.topAnchor.constraint(equalTo: fullNameContainerView.bottomAnchor, constant: 16),
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

            usernameTitleLabel.topAnchor.constraint(equalTo: emailContainerView.bottomAnchor, constant: 16),
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
            
            passwordTitleLabel.topAnchor.constraint(equalTo: usernameContainerView.bottomAnchor, constant: 16),
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

            confirmPasswordTitleLabel.topAnchor.constraint(equalTo: passwordContainerView.bottomAnchor, constant: 16),
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

            legalAgreementButton.topAnchor.constraint(equalTo: confirmPasswordContainerView.bottomAnchor, constant: 16),
            legalAgreementButton.leadingAnchor.constraint(equalTo: emailTitleLabel.leadingAnchor),
            legalAgreementButton.widthAnchor.constraint(equalToConstant: 24),
            legalAgreementButton.heightAnchor.constraint(equalToConstant: 24),

            legalAgreementTextView.topAnchor.constraint(equalTo: legalAgreementButton.topAnchor, constant: -1),
            legalAgreementTextView.leadingAnchor.constraint(equalTo: legalAgreementButton.trailingAnchor, constant: 8),
            legalAgreementTextView.trailingAnchor.constraint(equalTo: emailTitleLabel.trailingAnchor),
        ]
        
        // Container constraints
        NSLayoutConstraint.activate([
            appTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            appTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            appTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            
            screenTitleLabel.topAnchor.constraint(equalTo: appTitleLabel.bottomAnchor, constant: 16),
            screenTitleLabel.centerXAnchor.constraint(equalTo: appTitleLabel.centerXAnchor),
        ])

        loginFieldConstraints = [
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
        ]
        NSLayoutConstraint.activate(loginFieldConstraints)
        
        // Primary button constraints (will be toggled between login/signup mode)
        primaryButtonLoginConstraint = primaryButton.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 16)
        primaryButtonSignupConstraint = primaryButton.topAnchor.constraint(equalTo: legalAgreementTextView.bottomAnchor, constant: 24)
        
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
            primaryButton.heightAnchor.constraint(equalToConstant: 56),
            
            
            activityIndicator.topAnchor.constraint(equalTo: primaryButton.bottomAnchor, constant: 8),
            activityIndicator.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),
            
            errorLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 4),
            errorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            errorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            
            switchModeButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 24),
            switchModeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            switchModeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }
    
    func configureContainerView(_ v: UIView) {
        v.backgroundColor = ComponentColors.AuthScreen.inputFill
        v.layer.cornerRadius = 12
        if traitCollection.userInterfaceStyle == .light {
            v.layer.borderWidth = 0
            v.layer.borderColor = UIColor.clear.cgColor
        } else {
            v.layer.borderWidth = 1
            v.layer.borderColor = ComponentColors.AuthScreen.inputBorder.cgColor
        }
    }

    func legalAgreementAttributedText() -> NSAttributedString {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: ComponentColors.AuthScreen.bodyText
        ]

        let attributed = NSMutableAttributedString(
            string: "* I agree to the Terms of Service and Privacy Policy",
            attributes: baseAttributes
        )

        if let starRange = attributed.string.range(of: "*") {
            attributed.addAttribute(.foregroundColor, value: ComponentColors.AuthScreen.inputErrorText, range: NSRange(starRange, in: attributed.string))
        }

        if let termsRange = attributed.string.range(of: "Terms of Service") {
            attributed.addAttribute(.link, value: "rehearse://legal/terms", range: NSRange(termsRange, in: attributed.string))
        }

        if let privacyRange = attributed.string.range(of: "Privacy Policy") {
            attributed.addAttribute(.link, value: "rehearse://legal/privacy", range: NSRange(privacyRange, in: attributed.string))
        }

        return attributed
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
    
    func updateTextsForMode() {
        let showSignupFields = !isLoginMode
        
        fullNameTitleLabel.isHidden = !showSignupFields
        fullNameContainerView.isHidden = !showSignupFields
        emailTitleLabel.isHidden = false
        emailContainerView.isHidden = false
        usernameTitleLabel.isHidden = !showSignupFields
        usernameContainerView.isHidden = !showSignupFields
        passwordTitleLabel.isHidden = false
        passwordContainerView.isHidden = false
        confirmPasswordTitleLabel.isHidden = !showSignupFields
        confirmPasswordContainerView.isHidden = !showSignupFields
        legalAgreementButton.isHidden = !showSignupFields
        legalAgreementTextView.isHidden = !showSignupFields
        
        // Toggle forgot password visibility
        forgotPasswordButton.isHidden = !isLoginMode
        
        // Toggle primary button constraint
        if showSignupFields {
            NSLayoutConstraint.deactivate(loginFieldConstraints)
            primaryButtonLoginConstraint?.isActive = false
            primaryButtonSignupConstraint?.isActive = true
            NSLayoutConstraint.activate(signupConstraints)
        } else {
            NSLayoutConstraint.activate(loginFieldConstraints)
            primaryButtonLoginConstraint?.isActive = true
            primaryButtonSignupConstraint?.isActive = false
            NSLayoutConstraint.deactivate(signupConstraints)
        }
        
        screenTitleLabel.text = isLoginMode ? "Sign In" : "Sign Up"
        primaryButton.setTitle(isLoginMode ? "NEXT" : "Sign Up", for: .normal)
        switchModeButton.setTitle(isLoginMode ? "Create a Account" : "Already have an account? Sign In", for: .normal)
        
        errorLabel.isHidden = true
        
        // Animate layout change
    }
}

// MARK: - Actions
extension AuthViewController {
    
    @objc func toggleLegalAgreement() {
        hasAcceptedSignupLegal.toggle()
        let imageName = hasAcceptedSignupLegal ? "checkmark.square.fill" : "square"
        legalAgreementButton.setImage(UIImage(systemName: imageName), for: .normal)
        legalAgreementButton.tintColor = hasAcceptedSignupLegal ? ComponentColors.AuthScreen.linkText : ComponentColors.AuthScreen.bodyText
    }
    
    @objc func openTermsOfService() {
        presentLegalScreen(initialTab: .terms)
    }
    
    @objc func openPrivacyPolicy() {
        presentLegalScreen(initialTab: .privacy)
    }
    
    private func presentLegalScreen(initialTab: LegalTab) {
        let legalVC = UIHostingController(rootView: LegalScreenView(initialTab: initialTab))
        legalVC.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sheet = legalVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(legalVC, animated: true)
    }
    
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
            
            guard hasAcceptedSignupLegal else {
                showError("Please accept the Terms of Service and Privacy Policy to sign up.")
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
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.primaryButton.isEnabled = true
                    self.routeAfterLogin()
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                    self.activityIndicator.stopAnimating()
                    self.primaryButton.isEnabled = true
                }
            }
        }
    }

}

extension AuthViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if url.absoluteString == "rehearse://legal/terms" {
            presentLegalScreen(initialTab: .terms)
            return false
        }

        if url.absoluteString == "rehearse://legal/privacy" {
            presentLegalScreen(initialTab: .privacy)
            return false
        }

        return true
    }
}

// MARK: - Supabase Auth
extension AuthViewController {
    
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
        
        let result = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "full_name": .string(fullName),
                "username": .string(username)
            ]
        )
        
        if result.session != nil {
            await MainActor.run {
                self.routeAfterLogin()
            }
        } else {
            await MainActor.run {
                self.showError("Account created. Please check your email to verify.")
            }
        }
    }

    @MainActor
    func showHomeScreen() {
        let home = MainTabBarController()
        replaceRootViewController(with: home)
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
                await GuestSessionManager.shared.migrateGuestIfNeeded()

                let client = SupabaseManager.shared.client
                let session = try await client.auth.session
                let userId = session.user.id.uuidString

                // Query user_onboarding — check if the user has set their genre (completed onboarding)
                struct OnboardingRow: Decodable {
                    let genres: [String]?
                }

                do {
                    let row: OnboardingRow = try await client
                        .from("user_onboarding")
                        .select("genres")
                        .eq("id", value: userId)
                        .single()
                        .execute()
                        .value
                        
                    if let genres = row.genres, !genres.isEmpty {
                        // Returning user with completed onboarding → go to main app
                        showHomeScreen()
                    } else {
                        // User record exists but onboarding not finished
                        showOnboardingFlow()
                    }
                } catch {
                    debugLog("Email Auth Onboarding Check - no record found")
                    // No onboarding record found at all → show onboarding
                    showOnboardingFlow()
                }
            } catch {
                // Could not get session — stay on auth screen
                showError("Login error. Please try again.")
            }
        }
    }

    @MainActor
    func showOnboardingFlow() {
        let onboardingVC = UIHostingController(rootView: OnboardingFlowRoot())
        replaceRootViewController(with: onboardingVC)
    }

    /// Replaces the window's root view controller with a smooth cross-dissolve.
    /// Always use this instead of present() for top-level navigation transitions.
    private func replaceRootViewController(with vc: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }

        UIView.transition(with: window,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: { window.rootViewController = vc },
                          completion: nil)
    }
}

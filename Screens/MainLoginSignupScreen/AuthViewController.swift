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


final class AuthViewController: UIViewController, UITextFieldDelegate {
    enum AuthMode {
        case logIn
        case signUp
    }

    enum AuthError: LocalizedError {
        case emailAlreadyRegistered
        case usernameAlreadyTaken
        case signUpRateLimited
        case signUpUnavailable
        case networkUnavailable

        var errorDescription: String? {
            switch self {
            case .emailAlreadyRegistered:
                return "This email is already registered. Please log in instead."
            case .usernameAlreadyTaken:
                return "That username is already taken. Please choose another one."
            case .signUpRateLimited:
                return "Too many sign up attempts right now. Please wait a moment and try again."
            case .signUpUnavailable:
                return "Sign up is temporarily unavailable. Please try again shortly."
            case .networkUnavailable:
                return "We couldn't reach the server. Check your internet connection and try again."
            }
        }
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
    
    private let primaryButton = UIButton(type: .system)   // "LOGIN" / "Sign Up"
    
    // Bottom toggle ("Create a Account" / "Already have an account?")
    private let switchModeButton = UIButton(type: .system)
    
    private let errorLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let initialMode: AuthMode
    var postLoginRouteHandler: (@MainActor () -> Void)?
    
    // Async form state
    private var isUsernameChecking = false
    private var checkedUsername = ""
    private var isCheckedUsernameTaken = false
    private var usernameCheckTask: Task<Void, Never>?
    
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
        
        setupKeyboardDismiss()
    }
    
    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
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
         confirmPasswordTextField].forEach {
            addLeftPadding(to: $0)
            $0.delegate = self
            $0.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingChanged)
            $0.addTarget(self, action: #selector(textFieldEditingDidEnd(_:)), for: .editingDidEnd)
        }

        emailTextField.textContentType = .emailAddress
        emailTextField.returnKeyType = .next
        fullNameTextField.textContentType = .name
        fullNameTextField.autocapitalizationType = .words
        fullNameTextField.returnKeyType = .next
        usernameTextField.textContentType = .username
        usernameTextField.returnKeyType = .next
        passwordTextField.textContentType = .password
        confirmPasswordTextField.textContentType = .newPassword
        
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
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
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
            attributed.addAttribute(.link, value: "https://letsrehearse.studio/terms-of-service/", range: NSRange(termsRange, in: attributed.string))
        }

        if let privacyRange = attributed.string.range(of: "Privacy Policy") {
            attributed.addAttribute(.link, value: "https://letsrehearse.studio/privacy-policy/", range: NSRange(privacyRange, in: attributed.string))
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
        
        screenTitleLabel.text = isLoginMode ? "Login" : "Sign Up"
        primaryButton.setTitle(isLoginMode ? "Login" : "Sign Up", for: .normal)
        switchModeButton.setTitle(isLoginMode ? "Create a Account" : "Already have an account? Login", for: .normal)
        
        errorLabel.isHidden = true
        updatePrimaryButtonState()
        
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
        updatePrimaryButtonState()
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
        let email = InputValidator.trimOnSubmit(emailTextField.text ?? "")
        emailTextField.text = InputValidator.limit(email, maxLength: InputValidator.singleLineMaxLength)

        if let emailError = InputValidator.validateEmail(email) {
            showError(emailError)
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
                    self.showError("We couldn't send the reset email right now. Please try again.")
                }
            }
        }
    }
    
    @objc func primaryButtonTapped() {
        view.endEditing(true)
        errorLabel.isHidden = true
        guard let payload = validatedAuthPayload(showErrors: true) else { return }
        
        primaryButton.isEnabled = false
        activityIndicator.startAnimating()
        
        Task {
            do {
                if isLoginMode {
                    try await login(email: payload.email, password: payload.password)
                    await MainActor.run {
                        self.handleSuccessfulLogin()
                    }
                } else {
                    try await ensureUsernameAvailable(payload.username)
                    try await requestSignupOTP(
                        email: payload.email,
                        password: payload.password,
                        fullName: payload.fullName,
                        username: payload.username
                    )
                    await MainActor.run {
                        self.activityIndicator.stopAnimating()
                        self.updatePrimaryButtonState()
                        self.showOTPVerificationScreen(email: payload.email, password: payload.password)
                    }
                }
            } catch {
                await MainActor.run {
                    let message = self.userFacingAuthErrorMessage(error, mode: self.isLoginMode ? .logIn : .signUp)
                    self.showError(message)
                    if case .usernameAlreadyTaken = (error as? AuthError) {
                        self.showUsernameTakenAlert(message: message)
                    }
                    self.activityIndicator.stopAnimating()
                    self.updatePrimaryButtonState()
                }
            }
        }
    }

}

extension AuthViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return true
    }
}

private extension AuthViewController {
    struct AuthPayload {
        let email: String
        let password: String
        let fullName: String
        let username: String
    }

    func maxLength(for textField: UITextField) -> Int {
        switch textField {
        case fullNameTextField:
            return InputValidator.nameMaxLength
        case emailTextField, usernameTextField, passwordTextField, confirmPasswordTextField:
            return InputValidator.singleLineMaxLength
        default:
            return InputValidator.singleLineMaxLength
        }
    }

    @objc func textFieldEditingChanged(_ textField: UITextField) {
        let limited = InputValidator.limit(textField.text ?? "", maxLength: maxLength(for: textField))
        if textField === usernameTextField {
            textField.text = limited.replacingOccurrences(of: " ", with: "")
        } else {
            textField.text = limited
        }

        if textField === usernameTextField && !isLoginMode {
            let uname = textField.text ?? ""
            checkedUsername = ""
            isCheckedUsernameTaken = false
            usernameCheckTask?.cancel()
            
            if !uname.isEmpty {
                isUsernameChecking = true
                updatePrimaryButtonState() // Disable button while checking
                
                usernameCheckTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled, let self = self else { return }
                    
                    let taken = await self.isUsernameTaken(uname)
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run {
                        self.isUsernameChecking = false
                        self.checkedUsername = uname
                        self.isCheckedUsernameTaken = taken
                        if taken {
                            self.showError(AuthError.usernameAlreadyTaken.errorDescription!)
                        } else if !self.errorLabel.isHidden && self.errorLabel.text == AuthError.usernameAlreadyTaken.errorDescription {
                            self.errorLabel.isHidden = true
                        }
                        self.updatePrimaryButtonState()
                    }
                }
            } else {
                isUsernameChecking = false
            }
        }

        if !errorLabel.isHidden, validatedAuthPayload(showErrors: false) != nil {
            errorLabel.isHidden = true
        }
        updatePrimaryButtonState()
    }

    @objc func textFieldEditingDidEnd(_ textField: UITextField) {
        let trimmed = InputValidator.trimOnSubmit(textField.text ?? "")
        let limited = InputValidator.limit(trimmed, maxLength: maxLength(for: textField))
        textField.text = textField === usernameTextField ? limited.replacingOccurrences(of: " ", with: "") : limited
        updatePrimaryButtonState()
        
        // Inline error reporting on field exit
        if !isLoginMode {
            if textField == emailTextField, let err = InputValidator.validateEmail(textField.text ?? "") {
                showError(err)
            } else if textField == passwordTextField, let err = InputValidator.validatePassword(textField.text ?? "") {
                showError(err)
            } else if textField == confirmPasswordTextField, textField.text != passwordTextField.text {
                showError("Passwords do not match.")
            }
        } else {
             if textField == emailTextField, let err = InputValidator.validateEmail(textField.text ?? "") {
                 showError(err)
             }
        }
    }

    func validatedAuthPayload(showErrors: Bool) -> AuthPayload? {
        let email = InputValidator.limit(InputValidator.trimOnSubmit(emailTextField.text ?? ""), maxLength: InputValidator.singleLineMaxLength)
        let password = InputValidator.limit(passwordTextField.text ?? "", maxLength: InputValidator.singleLineMaxLength)
        emailTextField.text = email
        passwordTextField.text = password

        if let emailError = InputValidator.validateEmail(email) {
            if showErrors { showError(emailError) }
            return nil
        }

        guard !InputValidator.trimOnSubmit(password).isEmpty else {
            if showErrors { showError("Password is required.") }
            return nil
        }

        if !isLoginMode {
            if let passwordError = InputValidator.validatePassword(password) {
                if showErrors { showError(passwordError) }
                return nil
            }
        }

        guard !isLoginMode else {
            return AuthPayload(email: email, password: password, fullName: "", username: "")
        }

        let fullName = InputValidator.limit(InputValidator.trimOnSubmit(fullNameTextField.text ?? ""), maxLength: InputValidator.nameMaxLength)
        let username = InputValidator.limit(InputValidator.trimOnSubmit(usernameTextField.text ?? "").replacingOccurrences(of: " ", with: ""), maxLength: InputValidator.singleLineMaxLength)
        let confirmPassword = InputValidator.limit(confirmPasswordTextField.text ?? "", maxLength: InputValidator.singleLineMaxLength)

        fullNameTextField.text = fullName
        usernameTextField.text = username
        confirmPasswordTextField.text = confirmPassword

        if let nameError = InputValidator.validateRequired(fullName, message: "Full name is required.") {
            if showErrors { showError(nameError) }
            return nil
        }

        if let usernameError = InputValidator.validateRequired(username, message: "Username is required.") {
            if showErrors { showError(usernameError) }
            return nil
        }

        if isUsernameChecking {
            return nil // Disable while verifying username
        }

        if isCheckedUsernameTaken && username == checkedUsername {
            if showErrors { showError(AuthError.usernameAlreadyTaken.errorDescription!) }
            return nil
        }

        guard username == checkedUsername, !isCheckedUsernameTaken else {
            return nil // Wait for check task to flip state
        }

        guard !confirmPassword.isEmpty else {
            if showErrors { showError("Please confirm your password.") }
            return nil
        }

        guard confirmPassword == password else {
            if showErrors { showError("Passwords do not match.") }
            return nil
        }

        guard hasAcceptedSignupLegal else {
            if showErrors { showError("Please accept the Terms of Service and Privacy Policy to sign up.") }
            return nil
        }

        return AuthPayload(email: email, password: password, fullName: fullName, username: username)
    }

    func updatePrimaryButtonState() {
        guard !activityIndicator.isAnimating else { return }
        primaryButton.isEnabled = validatedAuthPayload(showErrors: false) != nil
        primaryButton.alpha = primaryButton.isEnabled ? 1.0 : 0.55
    }

    func userFacingAuthErrorMessage(_ error: Error, mode: AuthMode) -> String {
        if let authError = error as? AuthError, let message = authError.errorDescription {
            return message
        }
        
        let errorString = "\(error.localizedDescription) \(String(describing: error))".lowercased()
        if errorString.contains("username") || errorString.contains("duplicate") || errorString.contains("unique") || errorString.contains("already exists") || errorString.contains("database error saving new user") {
            return AuthError.usernameAlreadyTaken.errorDescription!
        }

        switch mode {
        case .logIn:
            return "We couldn't sign you in. Check your details and try again."
        case .signUp:
            return "We couldn't start sign up right now. Please try again."
        }
    }
}

struct ReviewAccessConfiguration {
    let email: String
    let password: String

    init(dictionary: [String: Any]) {
        self.email = (dictionary["REVIEW_ACCESS_EMAIL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.password = (dictionary["REVIEW_ACCESS_PASSWORD"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    init(bundle: Bundle) {
        self.init(dictionary: bundle.infoDictionary ?? [:])
    }

    var isConfigured: Bool {
        !email.isEmpty && !password.isEmpty
    }
}

extension AuthViewController {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case fullNameTextField:
            usernameTextField.becomeFirstResponder()
        case emailTextField:
            (isLoginMode ? passwordTextField : fullNameTextField).becomeFirstResponder()
        case usernameTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField:
            if isLoginMode {
                primaryButtonTapped()
            } else {
                confirmPasswordTextField.becomeFirstResponder()
            }
        case confirmPasswordTextField:
            primaryButtonTapped()
        default:
            textField.resignFirstResponder()
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
    }
    
    /// Creates the Supabase account and triggers the confirmation email.
    /// The OTP code the user receives comes from Supabase's "Confirm signup"
    /// email template — set that template to use {{ .Token }} (not {{ .ConfirmationURL }})
    /// in the Supabase dashboard so a 6-digit code is sent instead of a magic link.
    func ensureUsernameAvailable(_ username: String) async throws {
        struct UsernameRow: Decodable {
            let id: String
        }

        let normalizedUsername = InputValidator.trimOnSubmit(username)

        let matches: [UsernameRow] = try await SupabaseManager.shared.client
            .from("profiles")
            .select("id")
            .eq("username", value: normalizedUsername)
            .limit(1)
            .execute()
            .value

        if !matches.isEmpty {
            throw AuthError.usernameAlreadyTaken
        }
    }

    func isUsernameTaken(_ username: String) async -> Bool {
        do {
            try await ensureUsernameAvailable(username)
            return false
        } catch {
            if case .usernameAlreadyTaken = (error as? AuthError) {
                return true
            }
            return false
        }
    }

    func requestSignupOTP(
        email: String,
        password: String,
        fullName: String,
        username: String
    ) async throws {
        let client = SupabaseManager.shared.makeEphemeralClient()
        let metadata: [String: AnyJSON] = [
            "full_name": .string(fullName),
            "username": .string(username)
        ]

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )

            if isExistingUserSignupResponse(response) {
                throw AuthError.emailAlreadyRegistered
            }
        } catch {
            if isEmailAlreadyRegisteredError(error) {
                throw AuthError.emailAlreadyRegistered
            }
            if isSignupRateLimitedError(error) {
                throw AuthError.signUpRateLimited
            }
            if isNetworkError(error) {
                throw AuthError.networkUnavailable
            }
            if isSignupUnavailableError(error) {
                throw AuthError.signUpUnavailable
            }
            throw error
        }
    }

    private func isEmailAlreadyRegisteredError(_ error: Error) -> Bool {
        let message = "\(error.localizedDescription) \(String(describing: error))".lowercased()
        let existingAccountMarkers = [
            "already registered",
            "user already registered",
            "already been registered",
            "user already exists",
            "email address is already",
            "already exists",
            "email_exists",
            "user_exists",
            "email already in use",
            "duplicate key value"
        ]

        return existingAccountMarkers.contains { message.contains($0) }
    }

    private func isSignupRateLimitedError(_ error: Error) -> Bool {
        let message = "\(error.localizedDescription) \(String(describing: error))".lowercased()
        let rateLimitMarkers = [
            "rate limit",
            "too many requests",
            "over_email_send_rate_limit",
            "security purposes",
            "try again later"
        ]

        return rateLimitMarkers.contains { message.contains($0) }
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut, .dnsLookupFailed:
                return true
            default:
                break
            }
        }

        let message = "\(error.localizedDescription) \(String(describing: error))".lowercased()
        let networkMarkers = [
            "not connected to internet",
            "internet connection appears to be offline",
            "network connection was lost",
            "could not connect to the server",
            "timed out",
            "dns"
        ]

        return networkMarkers.contains { message.contains($0) }
    }

    private func isSignupUnavailableError(_ error: Error) -> Bool {
        let message = "\(error.localizedDescription) \(String(describing: error))".lowercased()
        let unavailableMarkers = [
            "signups not allowed",
            "signup is disabled",
            "email provider is disabled",
            "unsupported provider"
        ]

        return unavailableMarkers.contains { message.contains($0) }
    }

    private func isExistingUserSignupResponse(_ response: Any) -> Bool {
        guard let user = unwrapMirrorValue(valueForLabel("user", in: response)) else {
            return false
        }

        let session = unwrapMirrorValue(valueForLabel("session", in: response))
        let identities = unwrapMirrorValue(valueForLabel("identities", in: user))

        return session == nil && isEmptyCollectionLikeValue(identities)
    }

    private func valueForLabel(_ label: String, in value: Any) -> Any? {
        Mirror(reflecting: value).children.first(where: { $0.label == label })?.value
    }

    private func unwrapMirrorValue(_ value: Any?) -> Any? {
        guard let value else { return nil }

        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else {
            return value
        }

        return mirror.children.first?.value
    }

    private func isEmptyCollectionLikeValue(_ value: Any?) -> Bool {
        guard let value else { return false }

        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .collection, .set:
            return mirror.children.isEmpty
        default:
            return false
        }
    }

    @MainActor
    private func showOTPVerificationScreen(email: String, password: String) {
        let otpViewController = OTPVerificationViewController(email: email, password: password)

        if let navigationController = navigationController {
            navigationController.setNavigationBarHidden(false, animated: false)
            navigationController.pushViewController(otpViewController, animated: true)
            return
        }

        let navigationController = UINavigationController(rootViewController: otpViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
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
    func handleSuccessfulLogin() {
        activityIndicator.stopAnimating()
        updatePrimaryButtonState()

        if let postLoginRouteHandler {
            postLoginRouteHandler()
        } else {
            routeAfterLogin()
        }
    }

    @MainActor
    private func showUsernameTakenAlert(message: String) {
        let alert = UIAlertController(
            title: "Username Unavailable",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.usernameTextField.becomeFirstResponder()
        })
        present(alert, animated: true)
    }

    @MainActor
    func routeAfterLogin() {
        Task {
            do {
                let migrated = await GuestSessionManager.shared.migrateGuestIfNeeded()

                if migrated {
                    await MainActor.run {
                        self.showProgressSavedToast()
                    }
                }

                let client = SupabaseManager.shared.client
                let session = try await client.auth.session
                let userId = session.user.id.uuidString
                let metadata = session.user.userMetadata

                // RACE CONDITION FIX: Ensure at least a profile stub exists for all users
                // if they didn't come from guest migration.
                if !migrated {
                    let fullName = (metadata["full_name"]?.value as? String) ?? ""
                    let username = (metadata["username"]?.value as? String) ?? ""
                    let avatar = (metadata["avatar_url"]?.value as? String) ?? "icon_1"

                    // Silent idempotent upsert
                    let _ = try? await client
                        .from("profiles")
                        .upsert(["id": userId, "full_name": fullName, "username": username, "avatar_url": avatar])
                        .execute()
                }

                // Query user_onboarding
                struct OnboardingRow: Decodable {
                    let level: Int?
                    let genres: [String]?
                }

                do {
                    let row: OnboardingRow = try await client
                        .from("user_onboarding")
                        .select("level, genres")
                        .eq("id", value: userId)
                        .single()
                        .execute()
                        .value
                        
                    // If login mode (returning user), always skip onboarding
                    // If signup mode, only show if they haven't finished it
                    if isLoginMode {
                        showHomeScreen()
                    } else if let genres = row.genres, !genres.isEmpty {
                        showHomeScreen()
                    } else {
                        showOnboardingFlow()
                    }
                } catch {
                    debugLog("Email Auth Onboarding Check - no record found")
                    // If login mode, bypass even if no record found
                    if isLoginMode {
                        showHomeScreen()
                    } else {
                        showOnboardingFlow()
                    }
                }
            } catch {
                showError("Login error. Please try again.")
            }
        }
    }

    @MainActor
    func showOnboardingFlow() {
        let onboardingVC = UIHostingController(rootView: OnboardingFlowRoot())
        replaceRootViewController(with: onboardingVC)
    }

    @MainActor
    private func showProgressSavedToast() {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return }

        let toast = UILabel()
        toast.text = "Your progress has been saved"
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.textColor = ComponentColors.AuthScreen.ctaText
        toast.backgroundColor = ComponentColors.AuthScreen.ctaFill
        toast.textAlignment = .center
        toast.layer.cornerRadius = 20
        toast.clipsToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false

        window.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])

        UIView.animate(withDuration: 0.25, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: [], animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
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

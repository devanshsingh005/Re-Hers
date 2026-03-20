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
import AuthenticationServices


final class AuthViewController: UIViewController {
    
    // MARK: - Constants
    private let primaryOrangeColor = ComponentColors.HomeScreen.actionButtonFill
    
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
    
    // Social buttons
    private let googleButton = UIButton(type: .system)
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        // default to LOGIN (design in screenshot)
        modeSegment.selectedSegmentIndex = 0
        
        setupViews()
        updateTextsForMode()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Only show the intro card once per fresh install
        if !UserDefaults.standard.bool(forKey: "hasSeenAppIntroCard") {
            showRehearsalInfoCard()
        }
    }
    
    private func showRehearsalInfoCard() {
        let binding = Binding<Bool>(
            get: { true },
            set: { isVisible in
                if !isVisible {
                    self.presentedViewController?.dismiss(animated: false, completion: {
                        UserDefaults.standard.set(true, forKey: "hasSeenAppIntroCard")
                    })
                }
            }
        )
        
        let introView = RehearsalInfoCard(isPresented: binding)
        let hostingController = UIHostingController(rootView: introView)
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.view.backgroundColor = .clear // Let the ZStack handle dimming
        
        present(hostingController, animated: false, completion: nil)
    }
}

// MARK: - UI Setup

private extension AuthViewController {
    
    func setupViews() {
        // MARK: - Top titles
        
        appTitleLabel.text = "Rehearse"
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
        primaryButton.backgroundColor = .primaryColor
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.layer.cornerRadius = 28 // Unified pill shape
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
        
        // MARK: - Google Button Custom Subviews
        let googleIconView = UIImageView(image: UIImage(named: "google_icon"))
        googleIconView.contentMode = .scaleAspectFit
        googleIconView.translatesAutoresizingMaskIntoConstraints = false
        
        let googleLabel = UILabel()
        googleLabel.text = "Continue with Google"
        googleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        googleLabel.textColor = .label
        googleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let googleArrowView = UIImageView(image: UIImage(systemName: "arrow.right"))
        googleArrowView.tintColor = .label
        googleArrowView.contentMode = .scaleAspectFit
        googleArrowView.translatesAutoresizingMaskIntoConstraints = false
        
        googleButton.addSubview(googleIconView)
        googleButton.addSubview(googleLabel)
        googleButton.addSubview(googleArrowView)
        
        configureSocialButton(googleButton, title: "", image: nil)
        
        NSLayoutConstraint.activate([
            googleIconView.leadingAnchor.constraint(equalTo: googleButton.leadingAnchor, constant: 20),
            googleIconView.centerYAnchor.constraint(equalTo: googleButton.centerYAnchor),
            googleIconView.widthAnchor.constraint(equalToConstant: 24),
            googleIconView.heightAnchor.constraint(equalToConstant: 24),
            
            googleLabel.leadingAnchor.constraint(equalTo: googleIconView.trailingAnchor, constant: 12),
            googleLabel.centerYAnchor.constraint(equalTo: googleButton.centerYAnchor),
            
            googleArrowView.trailingAnchor.constraint(equalTo: googleButton.trailingAnchor, constant: -20),
            googleArrowView.centerYAnchor.constraint(equalTo: googleButton.centerYAnchor),
            googleArrowView.widthAnchor.constraint(equalToConstant: 18),
            googleArrowView.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        googleButton.addTarget(self,
                               action: #selector(googleButtonTapped),
                               for: .touchUpInside)
        
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
         googleButton,
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
            primaryButton.heightAnchor.constraint(equalToConstant: 56),
            
            
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
            
            googleButton.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: 24),
            googleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalMargin),
            googleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalMargin),
            googleButton.heightAnchor.constraint(equalToConstant: 56),
            
            switchModeButton.topAnchor.constraint(equalTo: googleButton.bottomAnchor, constant: 24),
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
                               image: UIImage?) {
        if !title.isEmpty {
            button.setTitle("  " + title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
            button.setTitleColor(.label, for: .normal)
        }
        
        button.layer.cornerRadius = 28 // Pill shaped (height 56 / 2)
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor.systemGray5.cgColor
        button.contentHorizontalAlignment = .center
        
        if let image = image {
            button.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
            button.imageView?.contentMode = .scaleAspectFit
        }
        
        button.backgroundColor = .white
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08 // Slightly more prominent shadow for consistency
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        
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
    }
}

// MARK: - Actions
extension AuthViewController {
    
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
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.primaryButton.isEnabled = true
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    self.routeAfterLogin()
                }
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                    self.activityIndicator.stopAnimating()
                    self.primaryButton.isEnabled = true
                    UserDefaults.standard.set(false, forKey: "isLoggedIn") // Set to false on error
                }
            }
        }
    }

    @objc func googleButtonTapped() {
        Task {
            do {
                let url = try SupabaseManager.shared.client.auth.getOAuthSignInURL(
                    provider: .google,
                    redirectTo: URL(string: "io.supabase.rehearse://login-callback")
                )

                await MainActor.run {
                    let webSession = ASWebAuthenticationSession(
                        url: url,
                        callbackURLScheme: "io.supabase.rehearse"
                    ) { callbackURL, error in

                        // User cancelled — fail silently
                        if let error = error as? ASWebAuthenticationSessionError,
                           error.code == .canceledLogin { return }

                        if let error = error {
                            DispatchQueue.main.async {
                                self.showError("Google sign-in failed: \(error.localizedDescription)")
                            }
                            return
                        }

                        guard let callbackURL = callbackURL else {
                            DispatchQueue.main.async {
                                self.showError("Google sign-in failed: no callback URL.")
                            }
                            return
                        }

                        // Exchange the callback URL for a Supabase session.
                        // IMPORTANT: After handle() succeeds we query onboarding
                        // INLINE in the same Task — this avoids the race condition
                        // where routeAfterLogin() spawns a *new* Task and tries to
                        // read client.auth.session before it is fully committed.
                        Task {
                            do {
                                let client = SupabaseManager.shared.client
                                client.auth.handle(callbackURL)

                                // The SDK securely stores the session in the iOS Keychain.
                                // Sometimes fetching .session immediately throws "Auth session missing"
                                // because the Keychain write hasn't propagated across threads yet.
                                // We retry up to 5 times (max 1.5s delay) to ensure it syncs.
                                var session: Session?
                                for _ in 0..<5 {
                                    if let s = try? await client.auth.session {
                                        session = s
                                        break
                                    }
                                    try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                                }
                                
                                guard let validSession = session else {
                                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session took too long to save. Please restart the app."])
                                }

                                let userId = validSession.user.id.uuidString

                                // Check onboarding completion inline
                                struct OnboardingRow: Decodable { let genre: String? }
                                let shouldOnboard: Bool

                                do {
                                    let row: OnboardingRow = try await client
                                        .from("user_onboarding")
                                        .select("genre")
                                        .eq("id", value: userId)
                                        .single()
                                        .execute()
                                        .value
                                        
                                    print("Google Auth Onboarding Check - Retrieved Genre: \(String(describing: row.genre))")
                                    shouldOnboard = row.genre == nil || row.genre!.isEmpty
                                } catch {
                                    print("Google Auth Onboarding Check - No record found: \(error.localizedDescription)")
                                    shouldOnboard = true // no record → show onboarding
                                }
                                
                                await MainActor.run {
                                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                                    if shouldOnboard {
                                        self.showOnboardingFlow()
                                    } else {
                                        self.showHomeScreen()
                                    }
                                }

                            } catch {
                                await MainActor.run {
                                    self.showError("Sign-in failed: \(error.localizedDescription)")
                                }
                            }
                        }
                    }

                    webSession.presentationContextProvider = self
                    webSession.prefersEphemeralWebBrowserSession = true
                    webSession.start()
                }
            } catch {
                await MainActor.run {
                    self.showError("Failed to start Google login: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window = self.view.window { return window }
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return UIWindow(windowScene: scene!)
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
        
        print("SIGNUP RESULT:", result)
        
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
                let client = SupabaseManager.shared.client
                let session = try await client.auth.session
                let userId = session.user.id.uuidString

                // Query user_onboarding — check if the user has set their genre (completed onboarding)
                struct OnboardingRow: Decodable {
                    let genre: String?
                }

                do {
                    let row: OnboardingRow = try await client
                        .from("user_onboarding")
                        .select("genre")
                        .eq("id", value: userId)
                        .single()
                        .execute()
                        .value
                        
                    print("Email Auth Onboarding Check - Retrieved Genre: \(String(describing: row.genre))")

                    if row.genre != nil && !row.genre!.isEmpty {
                        // Returning user with completed onboarding → go to main app
                        showHomeScreen()
                    } else {
                        // User record exists but onboarding not finished
                        showOnboardingFlow()
                    }
                } catch {
                    print("Email Auth Onboarding Check - No record found: \(error.localizedDescription)")
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
              let window = scene.keyWindow else { return }

        UIView.transition(with: window,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: { window.rootViewController = vc },
                          completion: nil)
    }
}




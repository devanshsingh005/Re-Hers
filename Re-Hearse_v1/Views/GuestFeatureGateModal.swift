//
//  GuestFeatureGateModal.swift
//  Re-Hearse_v1
//

import UIKit

final class GuestFeatureGateModal: UIViewController {

    // MARK: - Callbacks

    private let onSignUp: () -> Void
    private let onLogIn: () -> Void
    private let featureName: String

    // MARK: - UI

    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let signUpButton = UIButton(type: .system)
    private let logInButton = UIButton(type: .system)
    private let contentStack = UIStackView()

    // MARK: - Init

    init(featureName: String, onSignUp: @escaping () -> Void, onLogIn: @escaping () -> Void) {
        self.featureName = featureName
        self.onSignUp = onSignUp
        self.onLogIn = onLogIn
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        isModalInPresentation = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.App.screenBackground
        configureSheetPresentation()
        setupUI()
    }

    // MARK: - Presentation

    private func configureSheetPresentation() {
        guard let sheet = sheetPresentationController else { return }
        sheet.detents = [.medium(), .large()]
        sheet.prefersGrabberVisible = true
    }

    // MARK: - UI

    private func setupUI() {
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(contentStack)

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        titleLabel.text = "Create a free account"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = ComponentColors.NavBar.title
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        bodyLabel.text = "Sign up to unlock \(featureName). Your progress will be saved to your account."
        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = ComponentColors.DiscoverScreen.emptyStateText
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        signUpButton.setTitle("Sign up", for: .normal)
        stylePrimaryButton(signUpButton)
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)

        logInButton.setTitle("Log in", for: .normal)
        styleSecondaryButton(logInButton)
        logInButton.addTarget(self, action: #selector(logInTapped), for: .touchUpInside)

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(bodyLabel)
        contentStack.addArrangedSubview(signUpButton)
        contentStack.addArrangedSubview(logInButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            contentStack.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            signUpButton.heightAnchor.constraint(equalToConstant: 48),
            logInButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func stylePrimaryButton(_ button: UIButton) {
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(ComponentColors.HomeScreen.actionButtonText, for: .normal)
        button.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        button.layer.cornerRadius = 14
        button.clipsToBounds = true
    }

    private func styleSecondaryButton(_ button: UIButton) {
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)
        button.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = ComponentColors.SongDetailScreen.secondaryActionBorder.cgColor
        button.clipsToBounds = true
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func signUpTapped() {
        onSignUp()
        dismiss(animated: true)
    }

    @objc private func logInTapped() {
        onLogIn()
        dismiss(animated: true)
    }
}

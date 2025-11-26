//
//  UploadPageNextViewController.swift
//  Re-Hearse_v1
//

import UIKit

final class UploadPageNextViewController: UIViewController {

    var uploadedImage: UIImage? {
        didSet { sheetImageView.image = uploadedImage }
    }

    private let navBar = TopNavBar()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let sheetContainer = UIView()
    private let sheetHeaderLabel = UILabel()
    private let maximizeButton = UIButton(type: .system)
    private let sheetImageView = UIImageView()
    private let metronomeLabel = UILabel()

    private let tipsContainer = UIView()
    private let tipsTitleLabel = UILabel()
    private let tipsBodyLabel = UILabel()

    private let playAlongButton = UIButton(type: .system)
    private let animationButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavBar()
        setupUI()
        buildHierarchy()
        applyConstraints()
        setupActions()
    }

    // MARK: - Maximize Button Action
    private func setupActions() {
        maximizeButton.addTarget(self, action: #selector(didTapMaximize), for: .touchUpInside)
    }

    @objc private func didTapMaximize() {
        let vc = MaximizeViewController()
        vc.sheetImage = uploadedImage
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible = true
        navBar.isProfileVisible = true
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.setTitle("Practice")

        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        navBar.chordAction = { [weak self] in
            let vc = ChordRecognitionViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }
        navBar.profileAction = { [weak self] in
               guard let self = self else { return }
               let vc = UserProfileViewController()
               self.navigationController?.pushViewController(vc, animated: true)
           }

           navBar.backAction = { [weak self] in
               self?.navigationController?.popViewController(animated: true)
           }


        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        sheetContainer.backgroundColor = UIColor(white: 0.22, alpha: 1)
        sheetContainer.layer.cornerRadius = 30
        sheetContainer.translatesAutoresizingMaskIntoConstraints = false

        sheetHeaderLabel.text = "Right hand focus"
        sheetHeaderLabel.font = .systemFont(ofSize: 16, weight: .medium)
        sheetHeaderLabel.textColor = .white
        sheetHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        maximizeButton.setTitle("Maximize", for: .normal)
        maximizeButton.setTitleColor(.white, for: .normal)
        maximizeButton.titleLabel?.font = .systemFont(ofSize: 13)
        maximizeButton.backgroundColor = UIColor.white.withAlphaComponent(0.17)
        maximizeButton.layer.cornerRadius = 14
        maximizeButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        maximizeButton.translatesAutoresizingMaskIntoConstraints = false

        sheetImageView.contentMode = .scaleAspectFit
        sheetImageView.clipsToBounds = true
        sheetImageView.layer.cornerRadius = 20
        sheetImageView.backgroundColor = .white
        sheetImageView.image = uploadedImage
        sheetImageView.translatesAutoresizingMaskIntoConstraints = false

        metronomeLabel.text = "Metronome on 60 BPM"
        metronomeLabel.font = .systemFont(ofSize: 12)
        metronomeLabel.textColor = .white
        metronomeLabel.translatesAutoresizingMaskIntoConstraints = false

        tipsContainer.backgroundColor = UIColor(white: 0.95, alpha: 1)
        tipsContainer.layer.cornerRadius = 18
        tipsContainer.translatesAutoresizingMaskIntoConstraints = false

        tipsTitleLabel.text = "Tips"
        tipsTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        tipsTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        tipsBodyLabel.text = "Keep wrists relaxed and fingers curved.\nListen for even timing between notes."
        tipsBodyLabel.numberOfLines = 0
        tipsBodyLabel.font = .systemFont(ofSize: 14)
        tipsBodyLabel.textColor = .darkGray
        tipsBodyLabel.translatesAutoresizingMaskIntoConstraints = false

        DispatchQueue.main.async {
            let border = CAShapeLayer()
            border.strokeColor = UIColor.darkGray.cgColor
            border.lineWidth = 2.8
            border.lineDashPattern = [6, 4]
            border.fillColor = UIColor.clear.cgColor
            border.path = UIBezierPath(roundedRect: self.tipsContainer.bounds, cornerRadius: 18).cgPath
            border.frame = self.tipsContainer.bounds
            self.tipsContainer.layer.addSublayer(border)
        }

        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.25, alpha: 1)
        playAlongButton.layer.cornerRadius = 12
        playAlongButton.setTitleColor(.black, for: .normal)
        playAlongButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        playAlongButton.translatesAutoresizingMaskIntoConstraints = false

        animationButton.setTitle("Animation", for: .normal)
        animationButton.backgroundColor = UIColor(white: 0.92, alpha: 1)
        animationButton.layer.cornerRadius = 12
        animationButton.setTitleColor(.darkGray, for: .normal)
        animationButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        animationButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(sheetContainer)
        sheetContainer.addSubview(sheetHeaderLabel)
        sheetContainer.addSubview(maximizeButton)
        sheetContainer.addSubview(sheetImageView)
        sheetContainer.addSubview(metronomeLabel)

        contentView.addSubview(tipsContainer)
        tipsContainer.addSubview(tipsTitleLabel)
        tipsContainer.addSubview(tipsBodyLabel)

        contentView.addSubview(playAlongButton)
        contentView.addSubview(animationButton)
    }

    private func applyConstraints() {

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        NSLayoutConstraint.activate([
            sheetContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            sheetHeaderLabel.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 20),
            sheetHeaderLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 20),

            maximizeButton.centerYAnchor.constraint(equalTo: sheetHeaderLabel.centerYAnchor),
            maximizeButton.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -20),

            sheetImageView.topAnchor.constraint(equalTo: sheetHeaderLabel.bottomAnchor, constant: 20),
            sheetImageView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            sheetImageView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            sheetImageView.heightAnchor.constraint(equalToConstant: 340),

            metronomeLabel.topAnchor.constraint(equalTo: sheetImageView.bottomAnchor, constant: 16),
            metronomeLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -20),
            metronomeLabel.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -20)
        ])

        NSLayoutConstraint.activate([
            tipsContainer.topAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: 30),
            tipsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tipsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            tipsTitleLabel.topAnchor.constraint(equalTo: tipsContainer.topAnchor, constant: 16),
            tipsTitleLabel.leadingAnchor.constraint(equalTo: tipsContainer.leadingAnchor, constant: 16),

            tipsBodyLabel.topAnchor.constraint(equalTo: tipsTitleLabel.bottomAnchor, constant: 8),
            tipsBodyLabel.leadingAnchor.constraint(equalTo: tipsContainer.leadingAnchor, constant: 16),
            tipsBodyLabel.trailingAnchor.constraint(equalTo: tipsContainer.trailingAnchor, constant: -16),
            tipsBodyLabel.bottomAnchor.constraint(equalTo: tipsContainer.bottomAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            playAlongButton.topAnchor.constraint(equalTo: tipsContainer.bottomAnchor, constant: 30),
            playAlongButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            playAlongButton.heightAnchor.constraint(equalToConstant: 54),

            animationButton.centerYAnchor.constraint(equalTo: playAlongButton.centerYAnchor),
            animationButton.leadingAnchor.constraint(equalTo: playAlongButton.trailingAnchor, constant: 16),
            animationButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            animationButton.heightAnchor.constraint(equalToConstant: 54),

            playAlongButton.widthAnchor.constraint(equalTo: animationButton.widthAnchor),

            animationButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50)
        ])
    }
}

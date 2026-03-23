import UIKit

class LessonCompletionPopupView: UIView {

    var onContinue: (() -> Void)?

    init(stars: Int, lessonTitle: String) {
        super.init(frame: .zero)
        build(stars: stars, lessonTitle: lessonTitle)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(stars: Int, lessonTitle: String) {
        backgroundColor = .white
        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.20; layer.shadowRadius = 28
        layer.shadowOffset = CGSize(width: 0, height: 10)

        // Top accent bar
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = ComponentColors.HomeScreen.actionButtonFill; bar.layer.cornerRadius = 4
        addSubview(bar)

        // Icon circle
        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.10)
        iconCircle.layer.cornerRadius = 40
        addSubview(iconCircle)

        let iconLabel = UILabel()
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.text = stars == 3 ? "🏆" : stars == 2 ? "🎯" : "🎵"
        iconLabel.font = .systemFont(ofSize: 44); iconLabel.textAlignment = .center
        iconCircle.addSubview(iconLabel)

        // Stars row — filled ⭐ for earned, hollow ☆ for remaining
        let starsRow = UIStackView()
        starsRow.translatesAutoresizingMaskIntoConstraints = false
        starsRow.axis = .horizontal; starsRow.spacing = 8; starsRow.alignment = .center
        for i in 0..<3 {
            let lbl = UILabel()
            lbl.font = .systemFont(ofSize: 32)
            if i < stars {
                lbl.text = "⭐"
            } else {
                lbl.text = "☆"
                lbl.textColor = .systemGray4
            }
            // Animate each star popping in with stagger
            lbl.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            lbl.alpha = 0
            starsRow.addArrangedSubview(lbl)
            UIView.animate(withDuration: 0.45, delay: 0.35 + Double(i) * 0.13,
                           usingSpringWithDamping: 0.45, initialSpringVelocity: 0.8) {
                lbl.transform = .identity; lbl.alpha = 1
            }
        }
        addSubview(starsRow)

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let titles = ["Keep Practising!", "Well Done! 👏", "Lesson Complete! 🎉"]
        titleLabel.text = titles[min(stars - 1, 2)]
        titleLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        titleLabel.textColor = .label; titleLabel.textAlignment = .center
        addSubview(titleLabel)

        // Description
        let descLabel = UILabel()
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        let descs = [
            "You earned \(stars) star — practice makes perfect!",
            "You earned \(stars) stars — great effort!",
            "You earned \(stars) stars — perfect run!"
        ]
        descLabel.text = descs[min(stars - 1, 2)]
        descLabel.font = .systemFont(ofSize: 13); descLabel.textColor = .systemGray
        descLabel.textAlignment = .center; descLabel.numberOfLines = 2
        addSubview(descLabel)

        // "Next lesson unlocked" pill
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.10)
        pill.layer.cornerRadius = 16
        addSubview(pill)

        let pillLabel = UILabel()
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pillLabel.text = "🔓  Next lesson is now unlocked!"
        pillLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        pillLabel.textColor = ComponentColors.HomeScreen.actionButtonFill; pillLabel.textAlignment = .center
        pill.addSubview(pillLabel)

        // Continue button
        let contBtn = UIButton(type: .system)
        contBtn.translatesAutoresizingMaskIntoConstraints = false
        contBtn.setTitle("Continue  →", for: .normal)
        contBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        contBtn.setTitleColor(.white, for: .normal)
        contBtn.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        contBtn.layer.cornerRadius = 26
        contBtn.layer.shadowColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        contBtn.layer.shadowOpacity = 0.35; contBtn.layer.shadowRadius = 12
        contBtn.layer.shadowOffset = CGSize(width: 0, height: 5)
        contBtn.addTarget(self, action: #selector(tappedContinue), for: .touchUpInside)
        addSubview(contBtn)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.widthAnchor.constraint(equalToConstant: 48),
            bar.heightAnchor.constraint(equalToConstant: 5),

            iconCircle.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 18),
            iconCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 80),
            iconCircle.heightAnchor.constraint(equalToConstant: 80),
            iconLabel.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            starsRow.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 14),
            starsRow.centerXAnchor.constraint(equalTo: centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: starsRow.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            descLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            descLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            pill.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 16),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 10),
            pillLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -10),
            pillLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 18),
            pillLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -18),

            contBtn.topAnchor.constraint(equalTo: pill.bottomAnchor, constant: 20),
            contBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            contBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            contBtn.heightAnchor.constraint(equalToConstant: 52),
            contBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -26),
        ])
    }

    @objc private func tappedContinue() { onContinue?() }
}

import UIKit

class VariantChipButton: UIButton {

    private(set) var isDone: Bool = false

    init(label: String, sublabel: String, isSelected: Bool) {
        super.init(frame: .zero)
        setupChip(label: label, sublabel: sublabel, isSelected: isSelected)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupChip(label: String, sublabel: String, isSelected: Bool) {
        backgroundColor = isSelected ? ComponentColors.HomeScreen.actionButtonFill : UIColor.systemGray6
        layer.cornerRadius = 20
        layer.shadowColor = isSelected ? ComponentColors.HomeScreen.actionButtonFill.cgColor : UIColor.clear.cgColor
        layer.shadowOpacity = 0.3; layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical; stack.alignment = .center
        stack.spacing = 2; stack.isUserInteractionEnabled = false

        let noteLabel = UILabel()
        noteLabel.text = label
        noteLabel.font = .systemFont(ofSize: 18, weight: .bold)
        noteLabel.textColor = isSelected ? .white : .systemGray

        let subLabel = UILabel()
        subLabel.text = sublabel
        subLabel.font = .systemFont(ofSize: 9, weight: .medium)
        subLabel.textColor = isSelected ? UIColor.white.withAlphaComponent(0.9) : .systemGray3

        stack.addArrangedSubview(noteLabel)
        stack.addArrangedSubview(subLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(equalToConstant: 70),
            heightAnchor.constraint(equalToConstant: 70),
        ])
    }

    /// Marks this chip done with an animated green tick badge
    func markDone() {
        guard !isDone else { return }
        isDone = true

        let tick = UILabel()
        tick.text = "✓"; tick.font = .systemFont(ofSize: 11, weight: .heavy)
        tick.textColor = .white; tick.translatesAutoresizingMaskIntoConstraints = false

        let badge = UIView()
        badge.backgroundColor = ComponentColors.LessonScreen.correctAnswer
        badge.layer.cornerRadius = 9; badge.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(tick); addSubview(badge)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            badge.widthAnchor.constraint(equalToConstant: 18),
            badge.heightAnchor.constraint(equalToConstant: 18),
            tick.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            tick.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])

        badge.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.55, initialSpringVelocity: 0.8) {
            badge.transform = .identity
        }
    }
}

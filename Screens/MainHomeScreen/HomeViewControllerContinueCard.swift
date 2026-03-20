//
//  HomeViewControllerContinueCard.swift
//  Re-Hearse_v1
//

import UIKit

// MARK: - Shared Orange
let kAppOrange = UIColor(red: 1.0, green: 0.60, blue: 0.10, alpha: 1.0)

// MARK: - Data Model
struct ContinueCardItem {
    let imageName:  String
    let title:      String
    let subtitle:   String
    let filledDots: Int
    let totalDots:  Int
}

// MARK: - Self-rounding Pill Button
final class PillButton: UIButton {
    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = kAppOrange
        clipsToBounds   = true
        let attrs:   [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor.white]
        let hlAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor.white.withAlphaComponent(0.6)]
        setAttributedTitle(NSAttributedString(string: "Start Practice", attributes: attrs),   for: .normal)
        setAttributedTitle(NSAttributedString(string: "Start Practice", attributes: hlAttrs), for: .highlighted)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

// MARK: - Carousel Cell
final class ContinueCardCell: UICollectionViewCell {
    static let reuseID = "ContinueCardCell"

    private let albumImage    = UIImageView()
    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let dotsStack     = UIStackView()
    private let startButton   = PillButton()

    var onStartTapped: (() -> Void)?

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Cream background
        contentView.backgroundColor = UIColor(red: 0xFB/255.0, green: 0xF0/255.0, blue: 0xDA/255.0, alpha: 1.0)
        contentView.layer.cornerRadius   = 20
        contentView.layer.masksToBounds  = false
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowRadius  = 10
        layer.shadowOffset  = CGSize(width: 0, height: 3)
        layer.cornerRadius  = 20

        albumImage.layer.cornerRadius = 12
        albumImage.clipsToBounds      = true
        albumImage.contentMode        = .scaleAspectFill

        titleLabel.font      = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.10, green: 0.09, blue: 0.07, alpha: 1.0)

        subtitleLabel.font      = .systemFont(ofSize: 12)
        subtitleLabel.textColor = UIColor(red: 0.50, green: 0.48, blue: 0.44, alpha: 1.0)

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labelStack.axis = .vertical; labelStack.spacing = 4; labelStack.alignment = .leading

        let topRow = UIStackView(arrangedSubviews: [albumImage, labelStack])
        topRow.axis = .horizontal; topRow.spacing = 14; topRow.alignment = .center

        dotsStack.axis = .horizontal; dotsStack.spacing = 4
        dotsStack.alignment = .fill; dotsStack.distribution = .fillEqually

        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        [topRow, dotsStack, startButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        albumImage.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            albumImage.widthAnchor.constraint(equalToConstant: 72),
            albumImage.heightAnchor.constraint(equalToConstant: 72),

            dotsStack.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 14),
            dotsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dotsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dotsStack.heightAnchor.constraint(equalToConstant: 6),

            startButton.topAnchor.constraint(equalTo: dotsStack.bottomAnchor, constant: 14),
            startButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            startButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            startButton.heightAnchor.constraint(equalToConstant: 46),
            startButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    func configure(with item: ContinueCardItem) {
        albumImage.image   = UIImage(named: item.imageName)
        titleLabel.text    = item.title
        subtitleLabel.text = item.subtitle
        dotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for i in 0..<item.totalDots {
            let seg = UIView()
            seg.layer.cornerRadius = 3; seg.layer.masksToBounds = true
            seg.backgroundColor = i < item.filledDots
                ? kAppOrange
                : UIColor(red: 0.85, green: 0.80, blue: 0.73, alpha: 1.0)
            dotsStack.addArrangedSubview(seg)
        }
    }

    @objc private func startTapped() { onStartTapped?() }
}

// MARK: - Carousel
extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    final class PaddingLabel: UILabel {
        private var t,l,b,r: CGFloat
        init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
            t=top; l=left; b=bottom; r=right; super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { t=4; l=8; b=4; r=8; super.init(coder: coder) }
        override func drawText(in rect: CGRect) {
            super.drawText(in: rect.inset(by: UIEdgeInsets(top:t, left:l, bottom:b, right:r)))
        }
        override var intrinsicContentSize: CGSize {
            let s = super.intrinsicContentSize
            return CGSize(width: s.width+l+r, height: s.height+t+b)
        }
    }

    func createTagLabel(_ text: String) -> UILabel {
        let label = PaddingLabel(top:4, left:10, bottom:4, right:10)
        label.text = text; label.textColor = .black
        label.font = .systemFont(ofSize:12, weight:.medium)
        label.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        label.layer.cornerRadius = 6; label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    var carouselItems: [ContinueCardItem] {[
        ContinueCardItem(imageName:"Image",     title:"Believer",       subtitle:"Bars 5/15 · Right hand", filledDots:4,  totalDots:12),
        ContinueCardItem(imageName:"ride_home", title:"Ride",           subtitle:"Bars 8/20 · Full song",  filledDots:6,  totalDots:12),
        ContinueCardItem(imageName:"cl_4",      title:"Neon Lights",    subtitle:"Bars 2/10 · Left hand",  filledDots:2,  totalDots:12),
        ContinueCardItem(imageName:"cl_5",      title:"Midnight Train", subtitle:"Bars 12/16 · Chords",    filledDots:9,  totalDots:12),
    ]}

    func addCarouselSection() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection    = .horizontal
        layout.minimumLineSpacing = 14

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor         = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate        = .fast
        cv.clipsToBounds           = false
        cv.dataSource = self; cv.delegate = self
        cv.register(ContinueCardCell.self, forCellWithReuseIdentifier: ContinueCardCell.reuseID)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.tag = 100

        // Native UIPageControl — no scale transform
        let pageControl = UIPageControl()
        pageControl.numberOfPages                    = carouselItems.count
        pageControl.currentPage                      = 0
        pageControl.currentPageIndicatorTintColor    = kAppOrange
        pageControl.pageIndicatorTintColor           = UIColor(red: 0.80, green: 0.76, blue: 0.70, alpha: 1.0)
        pageControl.translatesAutoresizingMaskIntoConstraints = false

        let wrapper = UIView()
        wrapper.clipsToBounds = false
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(cv); wrapper.addSubview(pageControl)

        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: wrapper.topAnchor),
            cv.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            cv.heightAnchor.constraint(equalToConstant: 218),

            pageControl.topAnchor.constraint(equalTo: cv.bottomAnchor, constant: 4),
            pageControl.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])

        objc_setAssociatedObject(cv, &AssocKeys.pc, pageControl, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        contentView.addArrangedSubview(wrapper)
    }

    public func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cv.tag == 100 ? carouselItems.count : 0
    }
    public func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: ContinueCardCell.reuseID, for: ip) as! ContinueCardCell
        cell.configure(with: carouselItems[ip.item])
        cell.onStartTapped = { [weak self] in self?.openPianoPage() }
        return cell
    }
    public func collectionView(_ cv: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        CGSize(width: cv.bounds.width, height: 218)
    }
    public func collectionView(_ cv: UICollectionView, layout _: UICollectionViewLayout, insetForSectionAt _: Int) -> UIEdgeInsets { .zero }

    public func scrollViewWillEndDragging(_ sv: UIScrollView, withVelocity v: CGPoint, targetContentOffset t: UnsafeMutablePointer<CGPoint>) {
        guard let cv = sv as? UICollectionView, cv.tag == 100 else { return }
        let pageW = cv.bounds.width + 14
        let raw   = t.pointee.x / pageW
        let page  = v.x > 0 ? Int(ceil(raw)) : v.x < 0 ? Int(floor(raw)) : Int(round(raw))
        let clamped = max(0, min(page, carouselItems.count - 1))
        t.pointee = CGPoint(x: CGFloat(clamped) * pageW, y: 0)
        if let pc = objc_getAssociatedObject(cv, &AssocKeys.pc) as? UIPageControl { pc.currentPage = clamped }
    }
    public func scrollViewDidScroll(_ sv: UIScrollView) {
        guard let cv = sv as? UICollectionView, cv.tag == 100 else { return }
        let pageW = cv.bounds.width + 14
        let page  = Int((sv.contentOffset.x + pageW / 2) / pageW)
        if let pc = objc_getAssociatedObject(cv, &AssocKeys.pc) as? UIPageControl {
            pc.currentPage = max(0, min(page, carouselItems.count - 1))
        }
    }
}

private enum AssocKeys { nonisolated(unsafe) static var pc: UInt8 = 0 }

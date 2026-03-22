//
//  HomeViewControllerContinueCard.swift
//  Re-Hearse_v1
//

import UIKit

private final class GradientOverlayView: UIView {
    private let gradientLayer = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
        gradientLayer.locations = [0.4, 1.0]
        layer.insertSublayer(gradientLayer, at: 0)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

extension HomeViewController {
    func addTopPracticeCard() {
        let headerRow = UIView()
        
    

        contentView.addArrangedSubview(headerRow)
        contentView.setCustomSpacing(12, after: headerRow)

        let cardBgColor = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : .white }
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.backgroundColor = cardBgColor
        wrapper.layer.cornerRadius = 24
        wrapper.layer.masksToBounds = true
        
        let outerContainer = UIView()
        outerContainer.translatesAutoresizingMaskIntoConstraints = false
        outerContainer.layer.shadowColor = UIColor.black.cgColor
        outerContainer.layer.shadowOpacity = 0.08
        outerContainer.layer.shadowRadius = 16
        outerContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        outerContainer.addSubview(wrapper)
        NSLayoutConstraint.activate([
            wrapper.topAnchor.constraint(equalTo: outerContainer.topAnchor),
            wrapper.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor),
            wrapper.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor),
            wrapper.bottomAnchor.constraint(equalTo: outerContainer.bottomAnchor),
        ])

        // Image header
        let randomStartImage = "trackimage_\(Int.random(in: 1...16))"
        let imageView = UIImageView(image: UIImage(named: randomStartImage))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.topCardImageView = imageView
        wrapper.addSubview(imageView)
        
        // Gradient overlay for text readability
        let gradientView = GradientOverlayView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(gradientView)

        // Dynamic Title
        let titleLabel = UILabel()
        titleLabel.text = "Loading..."
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.topCardTitleLabel = titleLabel
        wrapper.addSubview(titleLabel)

    var carouselItems: [ContinueCardItem] {[
        ContinueCardItem(imageName:"trackimage_1",     title:"Believer",       subtitle:"Bars 5/15 · Right hand", filledDots:4,  totalDots:12),
        ContinueCardItem(imageName:"trackimage_2", title:"Ride",           subtitle:"Bars 8/20 · Full song",  filledDots:6,  totalDots:12),
        ContinueCardItem(imageName:"trackimage_3",      title:"Neon Lights",    subtitle:"Bars 2/10 · Left hand",  filledDots:2,  totalDots:12),
        ContinueCardItem(imageName:"trackimage_4", title:"Midnight Train", subtitle:"Bars 12/16 · Chords",    filledDots:9,  totalDots:12),
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

        // Native UIPageControl
        let pageControl = UIPageControl()
        pageControl.numberOfPages                    = carouselItems.count
        pageControl.currentPage                      = 0
        pageControl.currentPageIndicatorTintColor    = ComponentColors.HomeScreen.actionButtonFill
        pageControl.pageIndicatorTintColor           = ComponentColors.SongCard.border
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

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cv.tag == 100 ? carouselItems.count : 0
    }
    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: ContinueCardCell.reuseID, for: ip) as! ContinueCardCell
        cell.configure(with: carouselItems[ip.item])
        cell.onStartTapped = { [weak self] in self?.openPianoPage() }
        return cell
    }
    func collectionView(_ cv: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        CGSize(width: cv.bounds.width, height: 218)
    }
    func collectionView(_ cv: UICollectionView, layout _: UICollectionViewLayout, insetForSectionAt _: Int) -> UIEdgeInsets { .zero }

    func scrollViewWillEndDragging(_ sv: UIScrollView, withVelocity v: CGPoint, targetContentOffset t: UnsafeMutablePointer<CGPoint>) {
        guard let cv = sv as? UICollectionView, cv.tag == 100 else { return }
        let pageW = cv.bounds.width + 14
        let raw   = t.pointee.x / pageW
        let page  = v.x > 0 ? Int(ceil(raw)) : v.x < 0 ? Int(floor(raw)) : Int(round(raw))
        let clamped = max(0, min(page, carouselItems.count - 1))
        t.pointee = CGPoint(x: CGFloat(clamped) * pageW, y: 0)
        if let pc = objc_getAssociatedObject(cv, &AssocKeys.pc) as? UIPageControl { pc.currentPage = clamped }
    }
    func scrollViewDidScroll(_ sv: UIScrollView) {
        if let cv = sv as? UICollectionView, cv.tag == 100 {
            let pageW = cv.bounds.width + 14
            let page  = Int((sv.contentOffset.x + pageW / 2) / pageW)
            if let pc = objc_getAssociatedObject(cv, &AssocKeys.pc) as? UIPageControl {
                pc.currentPage = max(0, min(page, carouselItems.count - 1))
            }
        } else if sv === self.scrollView {
            syncNavBarAlpha()
        }
    }
}

private enum AssocKeys { nonisolated(unsafe) static var pc: UInt8 = 0 }

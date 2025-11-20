//  ExploreViewController.swift
//  Re-Hearse_v1
//  Created by DEVANSH on 04/11/25.

import UIKit

class ExploreViewController: UIViewController {

    // MARK: - UI Components
    private let navBar = TopNavBar.make(
        title: "Explore"
    )
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let searchBar = UISearchBar()
    private let categoryLabel = SectionHeader(title: "Category")
    private let albumLabel = SectionHeader(title: "Albums")

    private let categoryCollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: CustomMasonryLayout()
    )
    private let albumCollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewFlowLayout()
    )

    private let categories = ["cl_1", "cl_2", "cl_1", "cl_2"]
    private let albums = ["cl_1", "cl_2", "cl_1","cl_1", "cl_2", "cl_1", "cl_2"]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupScrollView()
        setupSearchBar()
        setupCollections()
    }
    
    // MARK: - Navbar Setup
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        
        // 🔥 SHOW CHORD ICON
        navBar.isChordIconVisible = true
        
        // ---- IMPORTANT: use push so the chord VC becomes part of the nav stack.
        // This keeps the bottom tab bar visible and lets back button behavior be natural.
        navBar.chordAction = { [weak self] in
            guard let self = self else { return }
            let vc = ChordRecognitionViewController()
            // prefer push (so TabBar + Nav stack remain correct)
            if let nav = self.navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                // fallback: if caller isn't embedded in a UINavigationController,
                // present modally so feature still works.
                vc.modalPresentationStyle = .fullScreen
                self.present(vc, animated: true)
            }
        }
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
        
        navBar.layer.shadowColor = UIColor.black.cgColor
        navBar.layer.shadowOpacity = 0.1
        navBar.layer.shadowOffset = CGSize(width: 0, height: 2)
        navBar.layer.shadowRadius = 4
    }

    // MARK: - ScrollView Setup
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Ensure scroll view is scrollable
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
    }

    // MARK: - Search Bar
    private func setupSearchBar() {
        searchBar.placeholder = "Search"
        searchBar.searchBarStyle = .minimal
        contentView.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Collections Setup
    private func setupCollections() {
        // Category Label
        contentView.addSubview(categoryLabel)
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            categoryLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20), // Increased gap
            categoryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        // Category Collection with Custom Layout
        if let layout = categoryCollectionView.collectionViewLayout as? CustomMasonryLayout {
            layout.delegate = self
            layout.numberOfColumns = 2
            layout.cellPadding = 8
        }
        
        categoryCollectionView.isScrollEnabled = false
        categoryCollectionView.delegate = self
        categoryCollectionView.dataSource = self
        categoryCollectionView.register(CategoryCell.self, forCellWithReuseIdentifier: "CategoryCell")
        categoryCollectionView.backgroundColor = .clear

        contentView.addSubview(categoryCollectionView)
        categoryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            categoryCollectionView.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 15),
            categoryCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            categoryCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            categoryCollectionView.heightAnchor.constraint(equalToConstant: 400) // Increased height
        ])

        // Album Label - INCREASED GAP
        contentView.addSubview(albumLabel)
        albumLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            albumLabel.topAnchor.constraint(equalTo: categoryCollectionView.bottomAnchor, constant: 25), // Increased to 25px
            albumLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            albumLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        // Album Collection - Horizontal Scrollable
        let albumLayout = UICollectionViewFlowLayout()
        albumLayout.scrollDirection = .horizontal
        albumLayout.minimumLineSpacing = 14
        albumLayout.minimumInteritemSpacing = 0
        albumLayout.itemSize = CGSize(width: 130, height: 130)
        
        albumCollectionView.collectionViewLayout = albumLayout
        albumCollectionView.delegate = self
        albumCollectionView.dataSource = self
        albumCollectionView.register(AlbumCell.self, forCellWithReuseIdentifier: "AlbumCell")
        albumCollectionView.showsHorizontalScrollIndicator = false
        albumCollectionView.backgroundColor = .clear
        albumCollectionView.isScrollEnabled = true
        albumCollectionView.alwaysBounceHorizontal = true

        contentView.addSubview(albumCollectionView)
        albumCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            albumCollectionView.topAnchor.constraint(equalTo: albumLabel.bottomAnchor, constant: 15),
            albumCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            albumCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            albumCollectionView.heightAnchor.constraint(equalToConstant: 140),
            albumCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40) // Increased bottom space for better scrolling
        ])
    }
}

// MARK: - Custom Masonry Layout
protocol CustomMasonryLayoutDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView, heightForItemAtIndexPath indexPath: IndexPath) -> CGFloat
}

class CustomMasonryLayout: UICollectionViewLayout {
    weak var delegate: CustomMasonryLayoutDelegate?
    
    var numberOfColumns = 2
    var cellPadding: CGFloat = 6
    var contentHeight: CGFloat = 0
    var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        let insets = collectionView.contentInset
        return collectionView.bounds.width - (insets.left + insets.right)
    }
    
    private var cache: [UICollectionViewLayoutAttributes] = []
    private var columnHeights: [CGFloat] = []
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }
    
    override func prepare() {
        guard let collectionView = collectionView, cache.isEmpty else { return }
        
        let columnWidth = contentWidth / CGFloat(numberOfColumns)
        var xOffset: [CGFloat] = []
        for column in 0..<numberOfColumns {
            xOffset.append(CGFloat(column) * columnWidth)
        }
        
        columnHeights = [CGFloat](repeating: 0, count: numberOfColumns)
        var column = 0
        
        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let indexPath = IndexPath(item: item, section: 0)
            
            let cellHeight = delegate?.collectionView(collectionView, heightForItemAtIndexPath: indexPath) ?? 180
            let height = cellPadding * 2 + cellHeight
            
            let frame = CGRect(x: xOffset[column], y: columnHeights[column], width: columnWidth, height: height)
            let insetFrame = frame.insetBy(dx: cellPadding, dy: cellPadding)
            
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = insetFrame
            cache.append(attributes)
            
            contentHeight = max(contentHeight, frame.maxY)
            columnHeights[column] = columnHeights[column] + height
            
            // Find the column with minimum height for next item
            column = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath.item]
    }
    
    override func invalidateLayout() {
        super.invalidateLayout()
        cache.removeAll()
        columnHeights.removeAll()
        contentHeight = 0
    }
}

// MARK: - Collection Delegate & DataSource
extension ExploreViewController: UICollectionViewDelegate, UICollectionViewDataSource, CustomMasonryLayoutDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView == categoryCollectionView ? categories.count : albums.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoryCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCell
            cell.configure(imageName: categories[indexPath.row])
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCell", for: indexPath) as! AlbumCell
            cell.configure(imageName: albums[indexPath.row])
            return cell
        }
    }

    // Custom Masonry Layout Delegate
    func collectionView(_ collectionView: UICollectionView, heightForItemAtIndexPath indexPath: IndexPath) -> CGFloat {
        // Return the actual content height (without padding)
        switch indexPath.item {
        case 0: return 140  // Small
        case 1: return 220  // Tall
        case 2: return 220  // Tall
        case 3: return 140  // Small
        default: return 180
        }
    }
}

// MARK: - Custom UI Components
class CategoryCell: UICollectionViewCell {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupCell() {
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 18
        imageView.clipsToBounds = true

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        contentView.layoutMargins = .zero
        contentView.insetsLayoutMarginsFromSafeArea = false
    }

    func configure(imageName: String) {
        imageView.image = UIImage(named: imageName)
    }
}

class AlbumCell: UICollectionViewCell {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 18
        imageView.clipsToBounds = true

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(imageName: String) {
        imageView.image = UIImage(named: imageName)
    }
}

class SectionHeader: UILabel {
    init(title: String) {
        super.init(frame: .zero)
        text = title
        font = .boldSystemFont(ofSize: 22)
        textColor = .gray
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

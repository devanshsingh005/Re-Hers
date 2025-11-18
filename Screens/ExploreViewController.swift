
//  ExploreViewController.swift
//  Re-Hearse_v1
//
//  Created by DEVANSH on 04/11/25.


import UIKit

class ExploreViewController: UIViewController {

    // MARK: - UI Components
    private let navBar = TopNavBar.make(
        appTitle: "Explore"
    )
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let searchBar = UISearchBar()
    private let categoryLabel = SectionHeader(title: "Category")
    private let albumLabel = SectionHeader(title: "Albums")

    private let categoryCollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewFlowLayout()
    )
    private let albumCollectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewFlowLayout()
    )

    private let categories = ["ride", "purple", "goaway", "diver"]
    private let albums = ["case", "arrival", "mariposa"]

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
    }

    // MARK: - Search Bar
    private func setupSearchBar() {
        searchBar.placeholder = "Search"
        searchBar.searchBarStyle = .minimal
        contentView.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: contentView.topAnchor),
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
            categoryLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20),
            categoryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        // Category Collection
        let catLayout = UICollectionViewFlowLayout()
        catLayout.scrollDirection = .vertical
        catLayout.minimumInteritemSpacing = 16
        catLayout.minimumLineSpacing = 16
        categoryCollectionView.collectionViewLayout = catLayout
        categoryCollectionView.isScrollEnabled = false
        categoryCollectionView.delegate = self
        categoryCollectionView.dataSource = self
        categoryCollectionView.register(CategoryCell.self, forCellWithReuseIdentifier: "CategoryCell")
        categoryCollectionView.backgroundColor = .clear

        contentView.addSubview(categoryCollectionView)
        categoryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            categoryCollectionView.topAnchor.constraint(equalTo: categoryLabel.bottomAnchor, constant: 10),
            categoryCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            categoryCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            categoryCollectionView.heightAnchor.constraint(equalToConstant: 360)
        ])

        // Album Label
        contentView.addSubview(albumLabel)
        albumLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            albumLabel.topAnchor.constraint(equalTo: categoryCollectionView.bottomAnchor, constant: 25),
            albumLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            albumLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        // Album Collection
        let albumLayout = UICollectionViewFlowLayout()
        albumLayout.scrollDirection = .horizontal
        albumLayout.minimumLineSpacing = 14
        albumCollectionView.collectionViewLayout = albumLayout
        albumCollectionView.delegate = self
        albumCollectionView.dataSource = self
        albumCollectionView.register(AlbumCell.self, forCellWithReuseIdentifier: "AlbumCell")
        albumCollectionView.showsHorizontalScrollIndicator = false
        albumCollectionView.backgroundColor = .clear

        contentView.addSubview(albumCollectionView)
        albumCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            albumCollectionView.topAnchor.constraint(equalTo: albumLabel.bottomAnchor, constant: 10),
            albumCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            albumCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            albumCollectionView.heightAnchor.constraint(equalToConstant: 120),
            albumCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -80)
        ])
    }
}

// MARK: - Collection Delegate & DataSource
extension ExploreViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
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

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == categoryCollectionView {
            let width = (collectionView.frame.width - 16) / 2
            return CGSize(width: width, height: 160)
        } else {
            return CGSize(width: 100, height: 100)
        }
    }
}

// MARK: - Custom UI Components
class CategoryCell: UICollectionViewCell {
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

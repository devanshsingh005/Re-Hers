//
//  SearchExplorePage.swift
//  Re-Hearse_v1
//

import UIKit

final class SearchExplorePage: UIViewController {

    // MARK: - UI
    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search"
        sb.searchBarStyle = .minimal
        return sb
    }()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let recentLabel: UILabel = {
        let l = UILabel()
        l.text = "Recent Searches"
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        return l
    }()

    private let noRecentLabel: UILabel = {
        let l = UILabel()
        l.text = "No recent searches"
        l.font = .systemFont(ofSize: 14)
        l.textColor = .darkGray
        l.isHidden = true
        return l
    }()

    private let resultsStack = UIStackView()
    private let recentStack = UIStackView()

    private let trendingLabel: UILabel = {
        let l = UILabel()
        l.text = "Trending"
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        return l
    }()

    private let trendingScroll = UIScrollView()
    private let trendingStack = UIStackView()

    // MARK: - Data
    private let demoNames: [String] = [
        "Aqua Dream","Black River","Calm Nights","Deep Sea",
        "Echoes","Fallen Star","Golden Hour","Highway",
        "Island Sun","Jazzy Mood","Kite Runner","Lone Rider",
        "Midnight Walk","Neon Lights","Open Road","Pink Sky",
        "Quiet Place","Rising Sun","Silver Lining","Twilight",
        "Uptown Vibes","Velvet Night","Wild Ride","Xylophone",
        "Yellow Sub","Zephyr"
    ]

    private let trendingImages = ["cl_5","cl_2","cl_3","cl_4","cl_1","cl_3","cl_2"]

    // NEW: search result images (cycle)
    private let searchImages = ["cl_1","cl_2","cl_3","cl_4","cl_5"]

    private var filteredNames: [String] = []

    private var recentSearches: [String] {
        get { UserDefaults.standard.stringArray(forKey: "recentSearches_v1") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "recentSearches_v1") }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupViews()
        configureStacks()
        updateRecentUI()

        searchBar.delegate = self
        navigationController?.navigationBar.isHidden = true
    }

    // MARK: - Setup
    private func setupViews() {
        view.addSubview(searchBar)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        contentView.addSubview(recentLabel)
        contentView.addSubview(noRecentLabel)
        contentView.addSubview(recentStack)
        contentView.addSubview(resultsStack)
        contentView.addSubview(trendingLabel)
        contentView.addSubview(trendingScroll)
        trendingScroll.addSubview(trendingStack)

        recentLabel.translatesAutoresizingMaskIntoConstraints = false
        noRecentLabel.translatesAutoresizingMaskIntoConstraints = false
        recentStack.translatesAutoresizingMaskIntoConstraints = false
        resultsStack.translatesAutoresizingMaskIntoConstraints = false
        trendingLabel.translatesAutoresizingMaskIntoConstraints = false
        trendingScroll.translatesAutoresizingMaskIntoConstraints = false
        trendingStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            recentLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            recentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            noRecentLabel.topAnchor.constraint(equalTo: recentLabel.bottomAnchor, constant: 8),
            noRecentLabel.leadingAnchor.constraint(equalTo: recentLabel.leadingAnchor),

            recentStack.topAnchor.constraint(equalTo: recentLabel.bottomAnchor, constant: 12),
            recentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            recentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            resultsStack.topAnchor.constraint(equalTo: recentStack.bottomAnchor, constant: 12),
            resultsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            trendingLabel.topAnchor.constraint(equalTo: resultsStack.bottomAnchor, constant: 24),
            trendingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            trendingScroll.topAnchor.constraint(equalTo: trendingLabel.bottomAnchor, constant: 10),
            trendingScroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            trendingScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            trendingScroll.heightAnchor.constraint(equalToConstant: 140),
            trendingScroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),

            trendingStack.topAnchor.constraint(equalTo: trendingScroll.topAnchor),
            trendingStack.leadingAnchor.constraint(equalTo: trendingScroll.leadingAnchor, constant: 20),
            trendingStack.trailingAnchor.constraint(equalTo: trendingScroll.trailingAnchor, constant: -20),
            trendingStack.bottomAnchor.constraint(equalTo: trendingScroll.bottomAnchor),
            trendingStack.heightAnchor.constraint(equalTo: trendingScroll.heightAnchor)
        ])

        recentStack.axis = .vertical
        recentStack.spacing = 8

        resultsStack.axis = .vertical
        resultsStack.spacing = 12

        trendingStack.axis = .horizontal
        trendingStack.spacing = 12
        trendingScroll.showsHorizontalScrollIndicator = false
    }

    private func configureStacks() {
        updateRecentUI()

        trendingImages.forEach { name in
            let iv = UIImageView(image: UIImage(named: name))
            iv.layer.cornerRadius = 12
            iv.clipsToBounds = true
            iv.contentMode = .scaleAspectFill
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 120).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 120).isActive = true

            iv.isUserInteractionEnabled = true
            iv.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapTrending(_:))))

            trendingStack.addArrangedSubview(iv)
        }
    }

    // MARK: - Actions
    @objc private func didTapTrending(_ g: UITapGestureRecognizer) {
        let alert = UIAlertController(title: "Trending", message: "Tapped trending item", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func updateRecentUI() {
        recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if recentSearches.isEmpty {
            noRecentLabel.isHidden = false
        } else {
            noRecentLabel.isHidden = true
            recentSearches.forEach { term in
                recentStack.addArrangedSubview(makeRecentRow(term: term))
            }
        }
    }

    private func makeRecentRow(term: String) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.lightGray.withAlphaComponent(0.12)
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let lbl = UILabel()
        lbl.text = term
        lbl.font = .systemFont(ofSize: 15)

        let clearBtn = UIButton(type: .system)
        clearBtn.setTitle("Remove", for: .normal)
        clearBtn.titleLabel?.font = .systemFont(ofSize: 13)
        clearBtn.tintColor = .systemBlue
        clearBtn.accessibilityLabel = term
        clearBtn.addTarget(self, action: #selector(removeRecent(_:)), for: .touchUpInside)

        view.addSubview(lbl)
        view.addSubview(clearBtn)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        clearBtn.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            lbl.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            clearBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            clearBtn.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        return view
    }

    @objc private func removeRecent(_ sender: UIButton) {
        guard let term = sender.accessibilityLabel else { return }
        recentSearches.removeAll { $0 == term }
        updateRecentUI()
    }

    // MARK: - Search Results
    private func showResults(for query: String) {
        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        filteredNames = demoNames.filter { $0.lowercased().contains(query.lowercased()) }

        if filteredNames.isEmpty {
            let lbl = UILabel()
            lbl.text = "No results"
            lbl.textColor = .darkGray
            lbl.font = .systemFont(ofSize: 14)
            resultsStack.addArrangedSubview(lbl)
            return
        }

        for (idx, name) in filteredNames.enumerated() {
            resultsStack.addArrangedSubview(makeResultCard(title: name, index: idx))
        }
    }

    private func makeResultCard(title: String, index: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.lightGray.withAlphaComponent(0.12)
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(equalToConstant: 72).isActive = true

        // IMAGE SELECTION
        let imgName = searchImages[index % searchImages.count]
        let img = UIImageView(image: UIImage(named: imgName))
        img.contentMode = .scaleAspectFill
        img.layer.cornerRadius = 10
        img.clipsToBounds = true
        img.translatesAutoresizingMaskIntoConstraints = false
        img.widthAnchor.constraint(equalToConstant: 52).isActive = true
        img.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 16, weight: .semibold)

        // DYNAMIC ARTIST NAME
        let artistLetter = title.first?.uppercased() ?? "A"
        let dynamicArtist = "Artist \(artistLetter)"

        let subLbl = UILabel()
        subLbl.text = dynamicArtist
        subLbl.font = .systemFont(ofSize: 12)
        subLbl.textColor = .darkGray

        let playBtn = UIButton(type: .system)
        playBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playBtn.tintColor = .black
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.widthAnchor.constraint(equalToConstant: 34).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 34).isActive = true

        // PASS DATA USING accessibility
        card.accessibilityLabel = title              // song title
        card.accessibilityHint = "\(imgName)|\(dynamicArtist)"   // pack image + artist

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapResult(_:)))
        card.addGestureRecognizer(tap)

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subLbl])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(img)
        card.addSubview(textStack)
        card.addSubview(playBtn)

        NSLayoutConstraint.activate([
            img.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            img.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: img.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            playBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            playBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }

    // MARK: - Tap On Search Result → Navigate
    @objc private func didTapResult(_ g: UITapGestureRecognizer) {
        guard let card = g.view else { return }
        guard let title = card.accessibilityLabel else { return }
        guard let packed = card.accessibilityHint else { return }

        let parts = packed.split(separator: "|")
        let imgName = String(parts[0])
        let artist = String(parts[1])

        // save to recent
        var existing = recentSearches
        existing.removeAll { $0 == title }
        existing.insert(title, at: 0)
        if existing.count > 10 { existing = Array(existing.prefix(10)) }
        recentSearches = existing

        updateRecentUI()

        // OPEN SONGDETAIL WITH DATA
        let vc = SongDetailViewController()
        vc.passedImage = UIImage(named: imgName)
        vc.passedSongTitle = title
        vc.passedArtist = artist

        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Search Delegate
extension SearchExplorePage: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {

        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            updateRecentUI()
            return
        }

        noRecentLabel.isHidden = true
        showResults(for: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

//
//  SearchPageViewController.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 19/11/25.
//

import Foundation
import UIKit

class SearchViewController: UIViewController {

    // MARK: - UI Components
    
    private let backButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        btn.tintColor = .black
        return btn
    }()
    
    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search"
        sb.searchBarStyle = .minimal
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()
    
    private let searchResultsLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Search results"
        lbl.font = .systemFont(ofSize: 20, weight: .semibold)
        return lbl
    }()
    
    private let resultsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 12
        return sv
    }()
    
    private let trendingLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Trending"
        lbl.font = .systemFont(ofSize: 20, weight: .semibold)
        return lbl
    }()
    
    private let trendingScrollView = UIScrollView()
    private let trendingStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 14
        return sv
    }()
    
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupSearchResults()
        setupTrending()
    }
    
    
    // MARK: - UI Layout
    
    private func setupUI() {
        view.addSubview(backButton)
        view.addSubview(searchBar)
        view.addSubview(searchResultsLabel)
        view.addSubview(resultsStackView)
        view.addSubview(trendingLabel)
        view.addSubview(trendingScrollView)
        
        trendingScrollView.addSubview(trendingStackView)
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        trendingScrollView.translatesAutoresizingMaskIntoConstraints = false
        trendingStackView.translatesAutoresizingMaskIntoConstraints = false
        resultsStackView.translatesAutoresizingMaskIntoConstraints = false
        searchResultsLabel.translatesAutoresizingMaskIntoConstraints = false
        trendingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        
        NSLayoutConstraint.activate([
            
            // Back button
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Search bar
            searchBar.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Search results label
            searchResultsLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20),
            searchResultsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            // Results stack
            resultsStackView.topAnchor.constraint(equalTo: searchResultsLabel.bottomAnchor, constant: 14),
            resultsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Trending text
            trendingLabel.topAnchor.constraint(equalTo: resultsStackView.bottomAnchor, constant: 30),
            trendingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            // Trending scroll
            trendingScrollView.topAnchor.constraint(equalTo: trendingLabel.bottomAnchor, constant: 14),
            trendingScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            trendingScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            trendingScrollView.heightAnchor.constraint(equalToConstant: 120),
            
            // Trending stack
            trendingStackView.topAnchor.constraint(equalTo: trendingScrollView.topAnchor),
            trendingStackView.bottomAnchor.constraint(equalTo: trendingScrollView.bottomAnchor),
            trendingStackView.leadingAnchor.constraint(equalTo: trendingScrollView.leadingAnchor),
            trendingStackView.trailingAnchor.constraint(equalTo: trendingScrollView.trailingAnchor),
            trendingStackView.heightAnchor.constraint(equalTo: trendingScrollView.heightAnchor)
        ])
    }
    
    
    // MARK: - Create Search Result Cards
    
    private func setupSearchResults() {
        
        let items = [
            ("Last Ride", "Devjeet Saha", UIImage(named: "ride1")),
            ("Ride My Horse", "Devjeet Saha", UIImage(named: "ride2")),
            ("Chalo Dur Kahi", "Devjeet Saha", UIImage(named: "ride1"))
        ]
        
        for item in items {
            let card = createSearchResultCard(title: item.0, subtitle: item.1, image: item.2)
            resultsStackView.addArrangedSubview(card)
        }
    }
    
    
    private func createSearchResultCard(title: String, subtitle: String, image: UIImage?) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.layer.cornerRadius = 18
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        let imgView = UIImageView(image: image)
        imgView.layer.cornerRadius = 12
        imgView.clipsToBounds = true
        imgView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .gray
        
        let playBtn = UIButton(type: .system)
        playBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playBtn.tintColor = .darkGray
        
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        
        container.addSubview(imgView)
        container.addSubview(textStack)
        container.addSubview(playBtn)
        
        NSLayoutConstraint.activate([
            imgView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            imgView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imgView.widthAnchor.constraint(equalToConstant: 60),
            imgView.heightAnchor.constraint(equalToConstant: 60),
            
            textStack.leadingAnchor.constraint(equalTo: imgView.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            playBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            playBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playBtn.widthAnchor.constraint(equalToConstant: 32),
            playBtn.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return container
    }
    
    
    // MARK: - Trending Section
    
    private func setupTrending() {
        
        let trendingImages = [
            UIImage(named: "t1"),
            UIImage(named: "t2"),
            UIImage(named: "t3")
        ]
        
        for img in trendingImages {
            let imgView = UIImageView(image: img)
            imgView.layer.cornerRadius = 14
            imgView.clipsToBounds = true
            imgView.widthAnchor.constraint(equalToConstant: 100).isActive = true
            imgView.heightAnchor.constraint(equalToConstant: 100).isActive = true
            trendingStackView.addArrangedSubview(imgView)
        }
    }
}

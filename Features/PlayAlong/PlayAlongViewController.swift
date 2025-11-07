//
//  PlayAlongViewController.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import Foundation
import UIKit

struct Playlist {
    let title: String
    let tags: String
    let trackCount: Int
}

class PlayAlongViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "PlayList"
    }
}

import UIKit

class PlaylistTableViewController: UITableViewController {
    
    private let playlists = [
        Playlist(title: "Silent Waves", tags: "Lo-fi Ambient Acoustic Chill", trackCount: 12),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9),
        Playlist(title: "Midnight Flow", tags: "Ambient Chillwave Jazzy Groovy", trackCount: 14),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    private func setupTableView() {
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0)
        tableView.separatorColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        tableView.register(PlaylistTableViewCell.self, forCellReuseIdentifier: "PlaylistCell")
        tableView.rowHeight = 80
        tableView.tableHeaderView = createHeaderView()
    }
    
    private func createHeaderView() -> UIView {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 60))
        let titleLabel = UILabel()
        titleLabel.text = "Playlist"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = CGRect(x: 16, y: 20, width: headerView.frame.width - 32, height: 24)
        headerView.addSubview(titleLabel)
        return headerView
    }
    
    // MARK: - UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath) as! PlaylistTableViewCell
        let playlist = playlists[indexPath.row]
        cell.configure(with: playlist)
        return cell
    }
}

class PlaylistTableViewCell: UITableViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let tagsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
        return label
    }()
    
    private let trackCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(tagsLabel)
        contentView.addSubview(trackCountLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        tagsLabel.translatesAutoresizingMaskIntoConstraints = false
        trackCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            tagsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            tagsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tagsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            trackCountLabel.topAnchor.constraint(equalTo: tagsLabel.bottomAnchor, constant: 8),
            trackCountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            trackCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(with playlist: Playlist) {
        titleLabel.text = playlist.title
        tagsLabel.text = playlist.tags
        trackCountLabel.text = "Tracks \(playlist.trackCount)"
    }
}

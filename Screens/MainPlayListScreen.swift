//
//  MainPlayListScreen.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/11/25.
//

import Foundation
import UIKit

// MARK: - Playlist Data Model
struct Playlist {
    let title: String
    let tags: String
    let trackCount: Int
    let imageName: String
}

class PlaylistTableViewController: UITableViewController {
    
    // MARK: - Playlist Data
    private let playlists = [
        Playlist(title: "Silent Waves", tags: "Lo-fi Ambient Acoustic Chill", trackCount: 12, imageName: "playlist1"),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9, imageName: "playlist2"),
        Playlist(title: "Midnight Flow", tags: "Ambient Chillwave Jazzy Groovy", trackCount: 14, imageName: "playlist3"),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9, imageName: "playlist4"),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9, imageName: "playlist5")
    ]
    
    // MARK: - Grey Shades Configuration
    // Starting from deep grey #3C3C3C to lighter greys
    private let greyShades = [
        UIColor(red: 0.235, green: 0.235, blue: 0.235, alpha: 1.0), // #3C3C3C - Deepest
        UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0),    // #737373
        UIColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0),    // #A6A6A6
        UIColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1.0),    // #CCCCCC
        UIColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1.0)     // #E6E6E6 - Lightest
    ]
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    // MARK: - Table View Setup
    private func setupTableView() {
        // Configure table view appearance
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.register(PlaylistTableViewCell.self, forCellReuseIdentifier: "PlaylistCell")
        tableView.rowHeight = 130 // Slightly increased height for rounder cards
        
        // Create and set table header view
        let headerView = createHeaderView()
        tableView.tableHeaderView = headerView
        
        // Add padding at bottom of table
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
    }
    
    // MARK: - Header View Creation
    private func createHeaderView() -> UIView {
        // Create header view with proper frame
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 80))
        headerView.backgroundColor = .white
        
        // Create and configure title label
        let titleLabel = UILabel()
        titleLabel.text = "Playlist"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .black
        
        // Add title label to header view with constraints
        headerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20)
        ])
        
        return headerView
    }
    
    // MARK: - UITableViewDataSource Methods
    
    // Returns number of rows in the table
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }
    
    // Configures and returns each cell for the table
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath) as! PlaylistTableViewCell
        let playlist = playlists[indexPath.row]
        let bgColor = greyShades[indexPath.row % greyShades.count]
        cell.configure(with: playlist, backgroundColor: bgColor)
        return cell
    }
    
    // MARK: - UITableViewDelegate Methods
    
    // Handles row selection
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Add your selection handling code here
    }
}

// MARK: - Playlist Table View Cell
class PlaylistTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    
    // Container view for the card with rounded corners
    private let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20 // Increased for rounder corners
        view.layer.masksToBounds = true
        return view
    }()
    
    // Image view for playlist artwork with rounded corners
    private let playlistImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 16 // Increased for rounder corners
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = .darkGray
        return imageView
    }()
    
    // Stack view to organize text labels vertically
    private let textStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 6 // Slightly increased spacing for better visual hierarchy
        stackView.alignment = .leading
        return stackView
    }()
    
    // Label for playlist title
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    // Label for "Tracks" text
    private let tracksLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        label.text = "Tracks" // Static text
        return label
    }()
    
    // Label for playlist tags/genres
    private let tagsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
        label.numberOfLines = 1
        return label
    }()
    
    // Label for track count number
    private let trackCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        return label
    }()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Configure cell appearance
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        // Add main container view
        contentView.addSubview(containerView)
        containerView.addSubview(playlistImageView)
        containerView.addSubview(textStackView)
        
        // Add labels to text stack view in order
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(tracksLabel)
        textStackView.addArrangedSubview(tagsLabel)
        textStackView.addArrangedSubview(trackCountLabel)
        
        setupConstraints()
    }
    
    // MARK: - Constraints Setup
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        playlistImageView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container view constraints with more vertical padding for rounder appearance
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            // Playlist image constraints with more padding
            playlistImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            playlistImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playlistImageView.widthAnchor.constraint(equalToConstant: 85), // Slightly larger for better proportions
            playlistImageView.heightAnchor.constraint(equalToConstant: 85),
            
            // Text stack view constraints with more padding
            textStackView.leadingAnchor.constraint(equalTo: playlistImageView.trailingAnchor, constant: 20),
            textStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            textStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    // MARK: - Cell Configuration
    func configure(with playlist: Playlist, backgroundColor: UIColor) {
        // Set text content
        titleLabel.text = playlist.title
        tagsLabel.text = playlist.tags
        trackCountLabel.text = "\(playlist.trackCount)"
        
        // Set playlist image (using system image as placeholder)
        playlistImageView.image = UIImage(systemName: "music.note.list") ?? UIImage(systemName: "photo")
        playlistImageView.tintColor = .white
        playlistImageView.backgroundColor = .systemGray
        
        // Set background color for the card
        containerView.backgroundColor = backgroundColor
        
       
    }
}

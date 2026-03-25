//
//  MainPlayListScreen.swift
//  Re-Hearse_v1
//

import UIKit
import PhotosUI

// MARK: - Album Placeholder Helper
func albumPlaceholder(for id: UUID) -> UIImage {
    let index = abs(id.hashValue) % 16 + 1
    return UIImage(named: "album_\(index)") ?? UIImage()
}

class PlaylistViewController: UIViewController {

    // MARK: - UI Components
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()

    // MARK: - Delete Button (selection mode only)
    private let deleteButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        btn.setImage(UIImage(systemName: "trash"), for: .normal)
        btn.tintColor = SemanticColors.Text.onBrand
        btn.layer.cornerRadius = 28
        btn.clipsToBounds = false
        btn.layer.shadowColor = SemanticColors.Shadow.level2.cgColor
        btn.layer.shadowOpacity = 0.3
        btn.layer.shadowRadius = 8
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.alpha = 0
        btn.isHidden = true
        return btn
    }()

    private let selectionModeLabel: UILabel = {
        let label = UILabel()
        label.text = "Select Playlists to Delete"
        label.textColor = SemanticColors.Text.primary
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        label.backgroundColor = SemanticColors.Background.card
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.layer.borderColor = ComponentColors.DestructiveButton.border.cgColor
        label.layer.borderWidth = 1
        label.alpha = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Activity Indicator
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = SemanticColors.Text.brand
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Data
    private let playlistsManager = PlaylistsManager.shared
    private var loadedPlaylists: [PlaylistData] = []

    // MARK: - State
    private var isSelectionMode = false {
        didSet { updateUIForSelectionMode() }
    }

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    private var selectedIndexPaths: Set<IndexPath> = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDeleteButton()
        setupActivityIndicator()
        setupRefreshControl()
        fetchPlaylists()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        fetchPlaylists()
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    private func setupUI() {
        view.backgroundColor = ComponentColors.App.screenBackground
        
        title = "Playlists"
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .white
        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        
        setupCollectionView()
        setupSelectionModeLabel()
    }

    private func setupActivityIndicator() {
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupRefreshControl() {
        refreshControl.tintColor = SemanticColors.Text.brand
        refreshControl.addTarget(self, action: #selector(refreshPlaylists), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func setupSelectionModeLabel() {
        view.addSubview(selectionModeLabel)
        NSLayoutConstraint.activate([
            selectionModeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            selectionModeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor,
                                                        constant: isPad ? 40 : 20),
            selectionModeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                                         constant: isPad ? -40 : -20),
            selectionModeLabel.heightAnchor.constraint(equalToConstant: isPad ? 50 : 40)
        ])
    }


    // MARK: - Collection View
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()

        if isPad {
            let spacing: CGFloat = 16
            let availableWidth = view.bounds.width - (3 * spacing)
            let itemWidth = availableWidth / 2
            layout.itemSize = CGSize(width: itemWidth, height: 110)
            layout.minimumInteritemSpacing = spacing
            layout.minimumLineSpacing = spacing
            layout.sectionInset = UIEdgeInsets(top: 16, left: spacing, bottom: 0, right: spacing)
        } else {
            layout.itemSize = CGSize(width: view.bounds.width - 32, height: 98)
            layout.minimumLineSpacing = 12
            layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 0, right: 16)
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        collectionView.delegate   = self
        collectionView.dataSource = self
        collectionView.register(PlaylistCollectionViewCell.self,
                                 forCellWithReuseIdentifier: "PlaylistCell")
        collectionView.register(CreatePlaylistFooterView.self,
                                 forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                 withReuseIdentifier: "CreateFooter")

        collectionView.backgroundColor     = ComponentColors.App.screenBackground
        collectionView.alwaysBounceVertical = true

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor,
                                                constant: isPad ? 20 : 14),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Delete Button (selection mode FAB)
    private func setupDeleteButton() {
        view.addSubview(deleteButton)

        let buttonSize: CGFloat    = isPad ? 70 : 60
        let bottomPadding: CGFloat = isPad ? 40 : 26
        let sidePadding: CGFloat   = isPad ? 40 : 22

        NSLayoutConstraint.activate([
            deleteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor,
                                                   constant: -sidePadding),
            deleteButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                 constant: -bottomPadding),
            deleteButton.widthAnchor.constraint(equalToConstant: buttonSize),
            deleteButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])

        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
    }

    // MARK: - Selection Mode UI
    private func updateUIForSelectionMode() {
        UIView.animate(withDuration: 0.3) {
            if self.isSelectionMode {
                self.deleteButton.isHidden       = false
                self.deleteButton.alpha          = 1
                self.selectionModeLabel.isHidden = false
                self.selectionModeLabel.alpha    = 1
            } else {
                self.deleteButton.alpha          = 0
                self.selectionModeLabel.alpha    = 0

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.deleteButton.isHidden       = true
                    self.selectionModeLabel.isHidden = true
                }

                for i in 0..<self.loadedPlaylists.count {
                    self.loadedPlaylists[i].isSelectedForDeletion = false
                }
                self.selectedIndexPaths.removeAll()
            }
            self.collectionView.reloadData()
        }
    }

    // MARK: - Button Actions
    @objc private func didTapAdd() {
        guard !isSelectionMode else {
            confirmDeletion()
            return
        }
        let addVC = AddPlaylistViewController()
        addVC.onSave = { [weak self] name, pickedImage in
            self?.addPlaylist(name: name, image: pickedImage)
        }
        addVC.modalPresentationStyle = .overFullScreen
        addVC.modalTransitionStyle   = .crossDissolve
        present(addVC, animated: true)
    }

    @objc private func didTapDelete() {
        isSelectionMode.toggle()
    }

    private func confirmDeletion() {
        let selected = loadedPlaylists.filter { $0.isSelectedForDeletion }
        guard !selected.isEmpty else {
            isSelectionMode = false
            return
        }

        let alert = UIAlertController(
            title: "Delete Playlists",
            message: "Are you sure you want to delete \(selected.count) playlist(s)?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.isSelectionMode = false
        })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteSelectedPlaylists()
        })
        present(alert, animated: true)
    }

    private func deleteSelectedPlaylists() {
        let selectedIDs = loadedPlaylists.filter { $0.isSelectedForDeletion }.map { $0.id }
        guard !selectedIDs.isEmpty else { isSelectionMode = false; return }

        showLoading(true)
        Task {
            let group = DispatchGroup()
            for id in selectedIDs {
                group.enter()
                await playlistsManager.deletePlaylist(id: id)
                group.leave()
            }
            group.notify(queue: .main) { [weak self] in
                self?.showLoading(false)
                self?.isSelectionMode = false
                self?.fetchPlaylists()

                let alert = UIAlertController(
                    title: "Success",
                    message: "\(selectedIDs.count) playlist(s) deleted.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }

    // MARK: - Data Operations
    @objc private func refreshPlaylists() { fetchPlaylists() }

    private func fetchPlaylists() {
        activityIndicator.startAnimating()
        Task {
            do {
                self.loadedPlaylists = try await playlistsManager.fetchRemotePlaylists()
            } catch {
                print("❌ Fetch error: \(error)")
                self.loadedPlaylists = []
            }
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.collectionView.reloadData()
                self.updateEmptyState()
                self.refreshControl.endRefreshing()
            }
        }
    }

    private func showLoading(_ show: Bool) {
        DispatchQueue.main.async {
            show ? self.activityIndicator.startAnimating()
                 : self.activityIndicator.stopAnimating()
            self.view.isUserInteractionEnabled = !show
        }
    }

    private func updateEmptyState() {
        print(loadedPlaylists.isEmpty ? "No playlists." : "Playlists loaded.")
    }

    private func addPlaylist(name: String, image: UIImage?) {
        showLoading(true)
        Task {
            do {
                let _ = try await PlaylistsManager.shared.createPlaylist(name: name, image: image)
                DispatchQueue.main.async { [weak self] in
                    self?.showLoading(false)
                    self?.fetchPlaylists()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.showLoading(false)
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to add playlist: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    fileprivate func loadImage(identifier: String) -> UIImage? {
        if identifier.contains("token=") || URL(string: identifier)?.scheme != nil { return nil }
        if let img = UIImage(named: identifier) { return img }
        guard !identifier.contains("/"),
              !identifier.contains(".."),
              !identifier.contains("\\"),
              identifier.count <= 128,
              identifier.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(.init(charactersIn: "-_.")).contains($0) }) else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                             .first!.appendingPathComponent(identifier)
        if let data = try? Data(contentsOf: url) { return UIImage(data: data) }
        return nil
    }
}

// MARK: - UICollectionViewDelegate, DataSource, FlowLayout
extension PlaylistViewController: UICollectionViewDelegate,
                                   UICollectionViewDataSource,
                                   UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return loadedPlaylists.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "PlaylistCell", for: indexPath
        ) as! PlaylistCollectionViewCell

        let playlist = loadedPlaylists[indexPath.item]
        cell.selectionOverlay.isHidden = !isSelectionMode || !playlist.isSelectedForDeletion
        cell.configure(with: playlist)
        cell.onDelete = { [weak self] in
            self?.confirmSingleDeletion(for: playlist, at: indexPath)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        if isSelectionMode {
            loadedPlaylists[indexPath.item].isSelectedForDeletion.toggle()
            if let cell = collectionView.cellForItem(at: indexPath) as? PlaylistCollectionViewCell {
                cell.selectionOverlay.isHidden = !loadedPlaylists[indexPath.item].isSelectedForDeletion
            }
        } else {
            let playlist = loadedPlaylists[indexPath.item]
            let vc = PlaylistDetailViewController()
            vc.playlistId    = playlist.id
            vc.passedTitle   = playlist.title
            vc.passedArtist  = playlist.tags
            vc.passedCoverUrl = playlist.imageUrl   // pass URL — banner loads it directly
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: Item size
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard isPad else {
            return CGSize(width: collectionView.bounds.width - 32, height: 98)
        }
        let spacing: CGFloat = 16
        let available = collectionView.bounds.width - (3 * spacing)
        let columns   = max(2, Int(available / 300))
        let width     = (available - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        return CGSize(width: width, height: 110)
    }

    // MARK: Footer size
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 84)
    }

    // MARK: Footer view
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionFooter else {
            return UICollectionReusableView()
        }
        let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "CreateFooter",
            for: indexPath
        ) as! CreatePlaylistFooterView
        footer.onTap = { [weak self] in self?.didTapAdd() }
        return footer
    }

    // MARK: Single delete
    private func confirmSingleDeletion(for playlist: PlaylistData, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Delete Playlist",
            message: "Are you sure you want to delete '\(playlist.title)'?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.showLoading(true)
            Task {
                await self.playlistsManager.deletePlaylist(id: playlist.id)
                DispatchQueue.main.async {
                    self.showLoading(false)
                    self.fetchPlaylists()
                }
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - PlaylistCollectionViewCell
class PlaylistCollectionViewCell: UICollectionViewCell, UIGestureRecognizerDelegate {

    var onDelete: (() -> Void)?
    private var panStartingX: CGFloat = 0
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    // MARK: Subviews
    let deleteBackgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = SemanticColors.State.incorrect
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        v.isHidden = true
        return v
    }()

    let trashImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "trash.fill"))
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = ComponentColors.SongCard.background
        v.layer.cornerRadius = 18
        v.clipsToBounds = true
        return v
    }()

    let playlistImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .boldSystemFont(ofSize: 16)
        l.textColor = ComponentColors.SongCard.titleText
        l.numberOfLines = 1
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = ComponentColors.SongCard.metadataText
        l.numberOfLines = 1
        return l
    }()

    private let chevron: UIImageView = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: "chevron.right",
                                            withConfiguration: cfg))
        iv.tintColor = ComponentColors.SongCard.metadataText.withAlphaComponent(0.45)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    let selectionOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = SemanticColors.State.incorrectSubtle
        v.layer.cornerRadius = 18
        v.layer.borderColor  = SemanticColors.State.incorrect.cgColor
        v.layer.borderWidth  = 1.5
        v.isHidden = true
        return v
    }()

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayout()
        setupGesture()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Layout
    private func setupLayout() {
        let imageSize: CGFloat = isPad ? 82 : 68
        let padding:   CGFloat = isPad ? 16 : 14

        [deleteBackgroundView, containerView].forEach {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        deleteBackgroundView.addSubview(trashImageView)
        trashImageView.translatesAutoresizingMaskIntoConstraints = false

        [playlistImageView, titleLabel, subtitleLabel,
         chevron, selectionOverlay].forEach {
            containerView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Delete bg
            deleteBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            deleteBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            deleteBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            deleteBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            trashImageView.trailingAnchor.constraint(equalTo: deleteBackgroundView.trailingAnchor,
                                                     constant: -24),
            trashImageView.centerYAnchor.constraint(equalTo: deleteBackgroundView.centerYAnchor),
            trashImageView.widthAnchor.constraint(equalToConstant: 22),
            trashImageView.heightAnchor.constraint(equalToConstant: 22),

            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            // Thumbnail
            playlistImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor,
                                                       constant: padding),
            playlistImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playlistImageView.widthAnchor.constraint(equalToConstant: imageSize),
            playlistImageView.heightAnchor.constraint(equalToConstant: imageSize),

            // Chevron
            chevron.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),

            // Title — above center
            titleLabel.leadingAnchor.constraint(equalTo: playlistImageView.trailingAnchor,
                                                constant: padding),
            titleLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -2),

            // Subtitle — below center
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: containerView.centerYAnchor, constant: 3),

            // Selection overlay
            selectionOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }

    // MARK: Configure
    func configure(with playlist: PlaylistData) {
        titleLabel.text    = playlist.title
        subtitleLabel.text = "\(playlist.trackCount) Tracks · \(playlist.tags)"

        let placeholder = albumPlaceholder(for: playlist.id)
        playlistImageView.image = placeholder

        if let imageData = playlist.imageData {
            playlistImageView.image = UIImage(data: imageData) ?? placeholder
        } else if let imageUrl = playlist.imageUrl, !imageUrl.isEmpty {
            if imageUrl.hasPrefix("http") {
                ImageLoader.shared.loadImage(from: imageUrl) { [weak self] image in
                    DispatchQueue.main.async {
                        self?.playlistImageView.image = image ?? placeholder
                    }
                }
            } else {
                // Local asset name stored in DB (e.g. "trackimage_3")
                playlistImageView.image = UIImage(named: imageUrl) ?? placeholder
            }
        }
    }

    // MARK: Swipe to delete
    private func setupGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        containerView.addGestureRecognizer(pan)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let t = pan.translation(in: containerView)
            return abs(t.x) > abs(t.y)
        }
        return true
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: contentView)
        switch recognizer.state {
        case .began:
            panStartingX = containerView.transform.tx
            deleteBackgroundView.isHidden = false

        case .changed:
            var newX = panStartingX + translation.x
            if newX > 0 { newX *= 0.2 }
            containerView.transform = CGAffineTransform(translationX: newX, y: 0)
            let scale = min(1.3, max(0.5, abs(newX) / 80.0))
            trashImageView.transform = CGAffineTransform(scaleX: scale, y: scale)

        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: contentView).x
            let currentX = containerView.transform.tx
            if currentX < -80 || (velocity < -500 && currentX < -30) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                UIView.animate(withDuration: 0.25, animations: {
                    self.containerView.transform = CGAffineTransform(
                        translationX: -self.bounds.width, y: 0)
                }) { _ in
                    self.onDelete?()
                    self.resetPan(animated: false)
                }
            } else {
                resetPan(animated: true)
            }
        default:
            resetPan(animated: true)
        }
    }

    private func resetPan(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0,
                           usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.containerView.transform = .identity
            } completion: { _ in
                self.deleteBackgroundView.isHidden = true
            }
        } else {
            containerView.transform = .identity
            deleteBackgroundView.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        resetPan(animated: false)
    }
}

// MARK: - CreatePlaylistFooterView
class CreatePlaylistFooterView: UICollectionReusableView {

    var onTap: (() -> Void)?
    private var dashedLayer: CAShapeLayer?

    private let button: UIButton = {
        var config = UIButton.Configuration.plain()
        let img = UIImage(
            systemName: "plus.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        )
        config.image               = img
        config.imagePlacement      = .leading
        config.imagePadding        = 8
        config.title               = "Create New Playlist"
        config.baseForegroundColor = BrandColors.brand
        config.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.boldSystemFont(ofSize: 16)
                return a
            }
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
        button.addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashedLayer?.removeFromSuperlayer()
        let dashed = CAShapeLayer()
        dashed.strokeColor     = ComponentColors.SongCard.border.withAlphaComponent(0.55).cgColor
        dashed.fillColor       = UIColor.clear.cgColor
        dashed.lineWidth       = 1.5
        dashed.lineDashPattern = [6, 4]
        let rect = CGRect(x: 16, y: 8,
                          width: bounds.width - 32,
                          height: bounds.height - 20)
        dashed.path = UIBezierPath(roundedRect: rect, cornerRadius: 16).cgPath
        layer.insertSublayer(dashed, at: 0)
        dashedLayer = dashed
    }

    required init?(coder: NSCoder) { fatalError() }
    @objc private func tapped() { onTap?() }
}

// MARK: - AddPlaylistViewController
class AddPlaylistViewController: UIViewController,
                                  UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate {

    var onSave: ((_ name: String, _ image: UIImage?) -> Void)?
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    private let dimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        return v
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = SemanticColors.Background.card
        v.layer.cornerRadius = 20
        v.clipsToBounds = true
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Create Playlist"
        l.font = UIDevice.current.userInterfaceIdiom == .pad
            ? .boldSystemFont(ofSize: 22)
            : .boldSystemFont(ofSize: 18)
        l.textAlignment = .center
        return l
    }()

    private let nameField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Playlist name"
        tf.borderStyle = .roundedRect
        tf.font = UIDevice.current.userInterfaceIdiom == .pad
            ? .systemFont(ofSize: 18)
            : .systemFont(ofSize: 16)
        return tf
    }()

    private let imageViewPreview: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.backgroundColor = SemanticColors.Background.skeletonBase
        return iv
    }()

    private let pickImageButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Choose Image", for: .normal)
        b.titleLabel?.font = UIDevice.current.userInterfaceIdiom == .pad
            ? .systemFont(ofSize: 18)
            : .systemFont(ofSize: 16)
        return b
    }()

    private let saveButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Save", for: .normal)
        b.titleLabel?.font = UIDevice.current.userInterfaceIdiom == .pad
            ? .boldSystemFont(ofSize: 20)
            : .boldSystemFont(ofSize: 16)
        return b
    }()

    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.titleLabel?.font = UIDevice.current.userInterfaceIdiom == .pad
            ? .systemFont(ofSize: 18)
            : .systemFont(ofSize: 16)
        return b
    }()

    private var pickedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        dimView.addGestureRecognizer(tap)
        setRandomAlbumPlaceholder()
    }

    private func setRandomAlbumPlaceholder() {
        let idx = Int.random(in: 1...16)
        if let img = UIImage(named: "album_\(idx)") {
            pickedImage = img
            imageViewPreview.image = img
        }
    }

    private func setupUI() {
        view.addSubview(dimView)
        view.addSubview(cardView)

        dimView.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false

        [titleLabel, nameField, imageViewPreview,
         pickImageButton, saveButton, cancelButton].forEach {
            cardView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let cardWidth: CGFloat = isPad ? 500 : 300
        let vPad:      CGFloat = isPad ? 30  : 18
        let hPad:      CGFloat = isPad ? 32  : 16
        let spacing:   CGFloat = isPad ? 20  : 12
        let btnH:      CGFloat = isPad ? 50  : 44
        let fieldH:    CGFloat = isPad ? 50  : 40
        let imgH:      CGFloat = isPad ? 180 : 140

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.widthAnchor.constraint(equalToConstant: cardWidth),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: vPad),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: hPad),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -hPad),

            nameField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: spacing),
            nameField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: hPad),
            nameField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -hPad),
            nameField.heightAnchor.constraint(equalToConstant: fieldH),

            imageViewPreview.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: spacing),
            imageViewPreview.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: hPad),
            imageViewPreview.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -hPad),
            imageViewPreview.heightAnchor.constraint(equalToConstant: imgH),

            pickImageButton.topAnchor.constraint(equalTo: imageViewPreview.bottomAnchor,
                                                  constant: spacing),
            pickImageButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            saveButton.topAnchor.constraint(equalTo: pickImageButton.bottomAnchor, constant: spacing),
            saveButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: hPad),
            saveButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -vPad),
            saveButton.heightAnchor.constraint(equalToConstant: btnH),

            cancelButton.topAnchor.constraint(equalTo: pickImageButton.bottomAnchor, constant: spacing),
            cancelButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -hPad),
            cancelButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -vPad),
            cancelButton.heightAnchor.constraint(equalToConstant: btnH),
        ])

        pickImageButton.addTarget(self, action: #selector(pickImage), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
    }

    @objc private func pickImage() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = self
        if isPad {
            picker.modalPresentationStyle = .popover
            picker.popoverPresentationController?.sourceView = pickImageButton
            picker.popoverPresentationController?.sourceRect = pickImageButton.bounds
        }
        present(picker, animated: true)
    }

    @objc private func saveTapped() {
        guard let name = nameField.text,
              !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            let alert = UIAlertController(title: "Name Required",
                                          message: "Please enter a playlist name.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        onSave?(name, pickedImage)
        dismiss(animated: true)
    }

    @objc private func dismissSelf() { dismiss(animated: true) }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        pickedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        imageViewPreview.image = pickedImage
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

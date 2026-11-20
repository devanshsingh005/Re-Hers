//
//  NotificationsViewController.swift
//  Re-Hearse_v1
//
//  The activity feed behind the bell on Home. Tapping an item marks it read and opens what it
//  is about; swipe to delete or toggle read.
//

import UIKit

final class NotificationsViewController: UITableViewController {
    private var items: [InAppNotification] = []
    private let store = InAppNotificationStore.shared
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = ComponentColors.HomeScreen.background
        tableView.backgroundColor = ComponentColors.HomeScreen.background
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        // iPad: rows and their text a size up, in proportion with the other pages
        if DeviceLayout.isPad {
            tableView.traitOverrides.preferredContentSizeCategory = .extraExtraLarge
            tableView.register(PadCardPairCell.self, forCellReuseIdentifier: PadCardPairCell.reuseID)
            tableView.separatorStyle = .none
            tableView.allowsSelection = false   // the cards take the taps
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: makeMenu())
        navigationItem.rightBarButtonItem?.accessibilityLabel = "More"
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: InAppNotificationStore.didChangeNotification, object: nil)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Same bar as the app's other pushed pages: back button and title over the theme background.
        navigationController?.setNavigationBarHidden(false, animated: animated)
        NavigationBarHelper.applyNativeNavigationBarAppearance(to: navigationController)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func makeMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Mark All as Read", image: UIImage(systemName: "envelope.open")) { [weak self] _ in
                self?.store.markAllRead()
            },
            UIAction(title: "Clear All", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmClearAll()
            },
        ])
    }

    @objc private func reload() {
        items = store.all()
        tableView.reloadData()
        var empty: UIContentUnavailableConfiguration?
        if items.isEmpty {
            var config = UIContentUnavailableConfiguration.empty()
            config.image = UIImage(systemName: "bell.slash")
            config.text = "No Notifications"
            config.secondaryText = "Updates about your uploads, practice goals and new songs appear here."
            empty = config
        }
        contentUnavailableConfiguration = empty
        navigationItem.rightBarButtonItem?.isEnabled = !items.isEmpty
    }

    private func confirmClearAll() {
        let alert = UIAlertController(title: "Clear All Notifications?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            self?.store.deleteAll()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(alert, animated: true)
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        DeviceLayout.isPad ? (items.count + 1) / 2 : items.count
    }

    private func content(for item: InAppNotification) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.subtitleCell()
        content.image = UIImage(systemName: item.kind.symbolName)
        content.imageProperties.tintColor = tint(for: item.kind)
        content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        content.text = item.title
        content.textProperties.font = UIFont.preferredFont(forTextStyle: .subheadline)
            .withWeight(item.isRead ? .regular : .semibold)
        content.secondaryText = "\(item.body)\n\(Self.relativeFormatter.localizedString(for: item.date, relativeTo: Date()))"
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .footnote)
        content.secondaryTextProperties.color = .secondaryLabel
        content.textToSecondaryTextVerticalPadding = 3
        return content
    }

    /// iPad: long-press menu in place of the phone's swipe actions.
    private func menu(for item: InAppNotification) -> UIMenu {
        var actions: [UIMenuElement] = []
        if !item.isRead {
            actions.append(UIAction(title: "Mark as Read", image: UIImage(systemName: "envelope.open")) { [weak self] _ in
                self?.store.markRead(id: item.id)
            })
        }
        actions.append(UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.store.delete(id: item.id)
        })
        return UIMenu(children: actions)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if DeviceLayout.isPad {
            // two to a row, as cards (like the Library)
            let cell = tableView.dequeueReusableCell(withIdentifier: PadCardPairCell.reuseID,
                                                     for: indexPath) as! PadCardPairCell
            let first = indexPath.row * 2
            let pair = [items[first]] + (first + 1 < items.count ? [items[first + 1]] : [])
            cell.configure(left: content(for: pair[0]), right: pair.count > 1 ? content(for: pair[1]) : nil,
                           menus: pair.map(menu(for:)) + [nil],
                           dots: pair.map { $0.isRead ? nil : BrandColors.brand } + [nil])
            cell.onTap = { [weak self] side in
                guard let self, side < pair.count else { return }
                self.store.markRead(id: pair[side].id)
                self.open(pair[side])
            }
            return cell
        }
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.contentConfiguration = content(for: item)
        cell.backgroundColor = ComponentColors.HomeScreen.cardBackground

        if item.isRead {
            cell.accessoryView = nil
        } else {
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            dot.backgroundColor = BrandColors.brand
            dot.layer.cornerRadius = DeviceLayout.s(5)
            cell.accessoryView = dot
        }
        cell.accessibilityValue = item.isRead ? nil : "Unread"
        return cell
    }

    private func tint(for kind: InAppNotification.Kind) -> UIColor {
        switch kind {
        case .uploadReady:  return .systemGreen
        case .uploadFailed: return .systemRed
        case .goalReached:  return BrandColors.brand
        case .newSongs:     return .systemPink
        case .welcome:      return .systemYellow
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        store.markRead(id: item.id)
        open(item)
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = items[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.store.delete(id: item.id)
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    override func tableView(_ tableView: UITableView,
                            leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = items[indexPath.row]
        guard !item.isRead else { return nil }
        let read = UIContextualAction(style: .normal, title: "Read") { [weak self] _, _, done in
            self?.store.markRead(id: item.id)
            done(true)
        }
        read.image = UIImage(systemName: "envelope.open")
        read.backgroundColor = .systemBlue
        return UISwipeActionsConfiguration(actions: [read])
    }

    // MARK: - Opening

    private func open(_ item: InAppNotification) {
        switch item.kind {
        case .uploadReady, .uploadFailed:
            guard let id = item.uploadId, let upload = LocalSheetLibrary.shared.upload(id: id) else {
                showGone("This upload is no longer on this device.")
                return
            }
            if upload.status == .failed { LocalSheetLibrary.shared.retry(id: id) }
            let vc = UploadPageNextViewController()
            vc.jobId = id
            navigationController?.pushViewController(vc, animated: true)
        case .newSongs:
            guard let songId = item.songId else {
                mainTabBarController?.select(.library)
                return
            }
            Task { [weak self] in
                let song = (try? await SongService.shared.fetchSongs())?.first { $0.id == songId }
                guard let self else { return }
                guard let song else {
                    self.mainTabBarController?.select(.library)
                    return
                }
                let vc = DiscoverSongDetailViewController()
                vc.song = song
                self.navigationController?.pushViewController(vc, animated: true)
            }
        case .goalReached:
            mainTabBarController?.select(.settings)
        case .welcome:
            navigationController?.popToRootViewController(animated: true)
        }
    }

    private func showGone(_ message: String) {
        let alert = UIAlertController(title: "Not Available", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

/// iPad: wide, two notifications to a row, like the Library.
extension NotificationsViewController: IPadContentWidth {
    var iPadContentWidth: CGFloat { 1180 }
}

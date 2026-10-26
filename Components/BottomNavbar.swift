//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

final class AppNavigationController: UINavigationController {
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if !viewControllers.isEmpty {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}

class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    private weak var activeGuestGateModal: GuestFeatureGateModal?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 18.0, *) {
            self.mode = .tabBar
        }
        delegate = self
        setupTabs()
        setupAppearance()
    }
    
    private func setupTabs() {
        // Home Tab
        let homeVC = HomeViewController()
        let homeNav = AppNavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        
        // Upload Tab
        let uploadVC = UploadScreen()
        let uploadNav = AppNavigationController(rootViewController: uploadVC)
        uploadNav.tabBarItem = UITabBarItem(
            title: "Upload",
            image: UIImage(systemName: "plus.square"),
            selectedImage: UIImage(systemName: "plus.square.fill")
        )
        
        // Practice Tab
        let practiceVC = LessonMapViewController()
        let practiceNav = AppNavigationController(rootViewController: practiceVC)
        practiceNav.tabBarItem = UITabBarItem(
            title: "Practice",
            image: UIImage(systemName: "map"),
            selectedImage: UIImage(systemName: "map.fill")
        )

        // Search Tab
        let searchVC = DiscoverViewController()
        let searchNav = AppNavigationController(rootViewController: searchVC)
        searchNav.tabBarItem = UITabBarItem(
            title: "Discover",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )
        
        // Set all view controllers in the new order: Home, Upload, Practice, Search
        viewControllers = [homeNav, uploadNav, practiceNav, searchNav]
    }
    
    private func setupAppearance() {
        tabBar.tintColor              = ComponentColors.TabBar.activeIcon
        tabBar.unselectedItemTintColor = ComponentColors.TabBar.inactiveIcon

        // Apply to the global UITabBar appearance proxy so ANY system redraw
        // (trait change, orientation etc.) picks up the correct attributes.
        let globalAppearance = UITabBarAppearance()
        globalAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance   = globalAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = globalAppearance
        }

        reapplyTabBarAppearance()
    }

    /// Reapplies the full tab bar appearance. Called on init and after every selection
    /// to prevent the OS from resetting labels when a tab is tapped.
    private func reapplyTabBarAppearance() {
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: ComponentColors.TabBar.inactiveIcon,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: ComponentColors.TabBar.activeIcon,
            .font: UIFont.systemFont(ofSize: 10, weight: .bold)
        ]

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = ComponentColors.TabBar.separator

        // Stacked (default iPhone portrait)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes   = normalAttrs
        appearance.stackedLayoutAppearance.normal.iconColor             = ComponentColors.TabBar.inactiveIcon
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        appearance.stackedLayoutAppearance.selected.iconColor           = ComponentColors.TabBar.activeIcon

        // Inline (iPad / landscape)
        appearance.inlineLayoutAppearance.normal.titleTextAttributes    = normalAttrs
        appearance.inlineLayoutAppearance.selected.titleTextAttributes  = selectedAttrs

        // Compact inline (iPhone landscape)
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes    = normalAttrs
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes  = selectedAttrs

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.isTranslucent = true
    }
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        // Reapply appearance to prevent iOS from clearing labels after selection
        reapplyTabBarAppearance()
    }

    func attemptSelectUploadTab() -> Bool {
        guard let viewControllers, viewControllers.indices.contains(1) else { return false }

        let uploadController = viewControllers[1]
        guard shouldAllowSelection(of: uploadController) else { return false }

        selectedIndex = 1
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        shouldAllowSelection(of: viewController)
    }

    private func shouldAllowSelection(of viewController: UIViewController) -> Bool {
        guard isUploadTab(viewController) else { return true }
        guard GuestSessionManager.shared.isGuest() else { return true }
        guard !GuestFeatureAccessPolicy.allowsUploadTab else { return true }

        presentUploadGuestGateIfNeeded()
        return false
    }

    private func isUploadTab(_ viewController: UIViewController) -> Bool {
        guard let viewControllers, viewControllers.indices.contains(1) else { return false }
        return viewControllers[1] === viewController
    }

    private func presentUploadGuestGateIfNeeded() {
        guard activeGuestGateModal == nil else { return }
        guard presentedViewController == nil else { return }

        let gateModal = GuestFeatureGateModal(
            featureName: "sheet music upload",
            onSignUp: { [weak self] in
                self?.presentAuth(mode: .signUp)
            },
            onLogIn: { [weak self] in
                self?.presentAuth(mode: .logIn)
            }
        )

        activeGuestGateModal = gateModal
        gateModal.presentationController?.delegate = self
        present(gateModal, animated: true)
    }

    private func presentAuth(mode: AuthViewController.AuthMode) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activeGuestGateModal = nil
            guard self.presentedViewController == nil else { return }

            let authViewController = AuthViewController(initialMode: mode)
            let authNavigationController = UINavigationController(rootViewController: authViewController)
            authNavigationController.modalPresentationStyle = .fullScreen
            self.present(authNavigationController, animated: true)
        }
    }
    
    // MARK: - Orientation Delegation

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return selectedViewController?.supportedInterfaceOrientations ?? .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return selectedViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
    }
}

extension MainTabBarController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        activeGuestGateModal = nil
    }
}

// MARK: - Navigation Controller Orientation Delegation
extension UINavigationController {

    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return topViewController?.supportedInterfaceOrientations ?? .allButUpsideDown
    }

    override open var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return topViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
    }
}

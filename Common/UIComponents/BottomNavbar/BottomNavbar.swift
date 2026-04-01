//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 18.0, *) {
            self.mode = .tabBar
        }
        setupTabs()
        setupAppearance()
    }
    
    private func setupTabs() {
        // Home Tab
        let homeVC = HomeViewController()
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        
        // Upload Tab
        let uploadVC = UploadScreen()
        let uploadNav = UINavigationController(rootViewController: uploadVC)
        uploadNav.tabBarItem = UITabBarItem(
            title: "Upload",
            image: UIImage(systemName: "plus.square"),
            selectedImage: UIImage(systemName: "plus.square.fill")
        )
        
        // Practice Tab
        let practiceVC = LessonMapViewController()
        let practiceNav = UINavigationController(rootViewController: practiceVC)
        practiceNav.tabBarItem = UITabBarItem(
            title: "Practice",
            image: UIImage(systemName: "map"),
            selectedImage: UIImage(systemName: "map.fill")
        )

        // Search Tab
        let searchVC = DiscoverViewController()
        let searchNav = UINavigationController(rootViewController: searchVC)
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

    // MARK: - Orientation Delegation

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return selectedViewController?.supportedInterfaceOrientations ?? .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return selectedViewController?.preferredInterfaceOrientationForPresentation ?? .portrait
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

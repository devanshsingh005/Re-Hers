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
        
        // Discover Tab
        let discoverVC = DiscoverViewController()
        let discoverNav = UINavigationController(rootViewController: discoverVC)
        discoverNav.tabBarItem = UITabBarItem(
            title: "Discover",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )
        
        // Play Along Tab
        let playListVC = PlaylistViewController()
        let playListNav = UINavigationController(rootViewController: playListVC)
        playListNav.tabBarItem = UITabBarItem(
            title: "Playlist",
            image: UIImage(systemName: "music.note.list"),
            selectedImage: UIImage(systemName: "music.note.list")
        )
        
        // Set all view controllers
        viewControllers = [homeNav, uploadNav, discoverNav, playListNav]
    }
    
    private func setupAppearance() {
        // Active / inactive icon and label tints — all resolved from the design token layer.
        tabBar.tintColor             = ComponentColors.TabBar.activeIcon
        tabBar.unselectedItemTintColor = ComponentColors.TabBar.inactiveIcon

        // iOS 15+ opaque appearance — collapses redundancy between standardAppearance
        // and scrollEdgeAppearance so the bar never turns transparent on scroll.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ComponentColors.TabBar.background

        // Use the separator token rather than hiding the line entirely.
        // Passing .clear would fully remove it; the token is a very subtle stroke colour.
        appearance.shadowColor = ComponentColors.TabBar.separator

        tabBar.standardAppearance  = appearance
        tabBar.scrollEdgeAppearance = appearance

        tabBar.isTranslucent  = false
        tabBar.clipsToBounds  = false
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


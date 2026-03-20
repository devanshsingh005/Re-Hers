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
        
        // Chord Recognition Tab
        let chordVC = ChordRecognitionViewController()
        let chordNav = UINavigationController(rootViewController: chordVC)
        chordNav.tabBarItem = UITabBarItem(
            title: "Chords",
            image: UIImage(systemName: "pianokeys"),
            selectedImage: UIImage(systemName: "pianokeys")
        )
        
        // Set all view controllers
        viewControllers = [homeNav, uploadNav, discoverNav, playListNav]
    }
    
    private func setupAppearance() {
        tabBar.tintColor = UIColor(red: 0.96, green: 0.71, blue: 0.34, alpha: 1.0)
        tabBar.unselectedItemTintColor = .systemGray
        
        // Force light mode appearance and remove dark mode
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            
            // Remove separator line
            appearance.shadowColor = .clear
            appearance.shadowImage = nil
            
            // Set the same appearance for both normal and scroll edge
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        } else {
            // Fallback for earlier iOS versions
            tabBar.backgroundColor = .white
            tabBar.barTintColor = .white
            tabBar.isTranslucent = false
        }
        
        // Ensure the tab bar background extends to the bottom edge
        tabBar.isTranslucent = false
        tabBar.clipsToBounds = false
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


//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

//
//  BottomNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//


//
//  MainTabBarController.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25
//

import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTabBar()
        setupViewControllers()
    }
    
    // MARK: - Tab Bar UI Setup
    private func configureTabBar() {
        tabBar.tintColor = UIColor.systemYellow          // Active icon
        tabBar.unselectedItemTintColor = .systemGray3    // Inactive icon
        
        tabBar.backgroundColor = .systemBackground       // Modern iOS look
        tabBar.isTranslucent = true
        
        // Extra safe padding for devices with Home indicator
        if let tabBarLayer = tabBar.layer.sublayers?.first {
            tabBarLayer.masksToBounds = true
            tabBar.layer.cornerRadius = 18
            tabBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }
        
        // Slight shadow for elevation effect
        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = 0.08
        tabBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        tabBar.layer.shadowRadius = 6
    }

    // MARK: - Add Screens
    private func setupViewControllers() {
        let homeVC = HomeViewController()
        let scanVC = ScanViewController()
        let animationVC = AnimationViewController()
        let playVC = PlayAlongViewController()
        let chordVC = ChordRecognitionViewController()

        viewControllers = [
            createNavController(for: homeVC,      title: "Home",       icon: "house.fill"),
            createNavController(for: scanVC,      title: "Scan",       icon: "camera.viewfinder"),
            createNavController(for: animationVC, title: "Tutorials",  icon: "play.rectangle.fill"),
            createNavController(for: playVC,      title: "Play Along", icon: "music.note.list"),
            createNavController(for: chordVC,     title: "Chords",     icon: "pianokeys")
        ]
    }

    // MARK: - Helper
    private func createNavController(for vc: UIViewController, title: String, icon: String) -> UINavigationController {
        let nav = UINavigationController(rootViewController: vc)
        nav.tabBarItem.title = title
        nav.tabBarItem.image = UIImage(systemName: icon)
        
        // Optional: hide nav bar title for modern UI
        vc.navigationItem.largeTitleDisplayMode = .always
        nav.navigationBar.prefersLargeTitles = true
        
        return nav
    }
}

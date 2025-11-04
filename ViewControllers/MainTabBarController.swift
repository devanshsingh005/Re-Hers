//
//  MainTabBarController.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import Foundation
import UIKit

class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
    }
    
    private func setupViewControllers() {
        let scanVC = ScanViewController()
        let animationVC = AnimationViewController()
        let playAlongVC = PlayAlongViewController()
        let chordsVC = ChordRecognitionViewController()
        
        viewControllers = [
            createNavController(for: scanVC, title: "Scan", icon: "doc.viewfinder"),
            createNavController(for: animationVC, title: "Animation", icon: "play.rectangle"),
            createNavController(for: playAlongVC, title: "Play Along", icon: "music.mic"),
            createNavController(for: chordsVC, title: "Chords", icon: "square.grid.3x3")
        ]
    }
    
    private func createNavController(for rootViewController: UIViewController, title: String, icon: String) -> UIViewController {
        let navController = UINavigationController(rootViewController: rootViewController)
        navController.tabBarItem.title = title
        navController.tabBarItem.image = UIImage(systemName: icon)
        return navController
    }
}

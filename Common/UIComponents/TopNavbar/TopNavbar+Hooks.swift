//
//  TopNavbar+Hooks.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

// Global state context
class NavBarContext {
    static let shared = NavBarContext()
    
    var currentUsername: String = "Mukul"
    var currentDay: Int = 5
    var profileImage: UIImage?
    
    private init() {}
}

// React-like hooks for TopNavbar
struct useTopNavBar {
    
    // Main hook to get navbar props
    static func getProps(
        username: String? = nil,
        dayNumber: Int? = nil,
        profileImage: UIImage? = nil,
        onProfileTap: (() -> Void)? = nil,
        onDayBadgeTap: (() -> Void)? = nil
    ) -> TopNavBarProps {
        
        return TopNavBarProps(
            username: username ?? NavBarContext.shared.currentUsername,
            dayNumber: dayNumber ?? NavBarContext.shared.currentDay,
            profileImage: profileImage ?? NavBarContext.shared.profileImage,
            onProfileTap: onProfileTap,
            onDayBadgeTap: onDayBadgeTap
        )
    }
    
    // Hook to update global state
    static func updateUser(username: String) {
        NavBarContext.shared.currentUsername = username
    }
    
    static func updateDay(_ day: Int) {
        NavBarContext.shared.currentDay = day
    }
    
    static func updateProfileImage(_ image: UIImage) {
        NavBarContext.shared.profileImage = image
    }
    
    // Hook to reset state
    static func reset() {
        NavBarContext.shared.currentUsername = "User"
        NavBarContext.shared.currentDay = 1
        NavBarContext.shared.profileImage = nil
    }
}

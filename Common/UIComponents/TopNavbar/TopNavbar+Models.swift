//
//  TopNavbar+Model.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

// Props structure
struct TopNavBarProps {
    let username: String
    let dayNumber: Int
    let profileImage: UIImage?
    let onProfileTap: (() -> Void)?
    let onDayBadgeTap: (() -> Void)?
    
    init(
        username: String,
        dayNumber: Int,
        profileImage: UIImage? = nil,
        onProfileTap: (() -> Void)? = nil,
        onDayBadgeTap: (() -> Void)? = nil
    ) {
        self.username = username
        self.dayNumber = dayNumber
        self.profileImage = profileImage
        self.onProfileTap = onProfileTap
        self.onDayBadgeTap = onDayBadgeTap
    }
}

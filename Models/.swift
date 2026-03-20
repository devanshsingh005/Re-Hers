//
//  BrandColors.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 26/11/25.
//

import UIKit

public extension UIColor {

    // MARK: - Brand Colors (Global App Palette)

    /// Brand Primary Color - #EF9408
    static let primaryColor: UIColor = UIColor(hex: "#EF9408")

    /// Brand Accent Color (Orange) - #EF9408
    static let secondaryColor: UIColor = UIColor(hex: "#EF9408")

    /// Dark Gray 1 - #3C3C3C
    static let darkGray1: UIColor = UIColor(hex: "#3C3C3C")

    /// Light Gray - #D9D9D9
    static let lightGray: UIColor = UIColor(hex: "#D9D9D9")

    /// Dark Gray 2 - #212121
    static let darkGray2: UIColor = UIColor(hex: "#212121")

    /// Pure White - #FFFFFF
    static let appBackground: UIColor = UIColor(hex: "#FFFFFF")



    // MARK: - Hex Initializer
    /// Create a UIColor from a hex string "#RRGGBB" or "RRGGBB"
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }

        var rgbValue: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&rgbValue) else {
            self.init(white: 0, alpha: 0)
            return
        }

        switch cleaned.count {
        case 6:
            let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: alpha)

        case 8: // AARRGGBB
            let a = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            let r = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            let b = CGFloat(rgbValue & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)

        default:
            self.init(white: 0, alpha: 0)
        }
    }
}

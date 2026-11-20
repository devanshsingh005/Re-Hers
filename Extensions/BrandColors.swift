//
//  BrandColors.swift
//  Re-Hearse_v1
//
//  The single source of truth for every raw color value in the app.
//  All colors are defined here as static UIColor properties with full
//  Light Mode and Dark Mode (adaptive) support.
//
//  Do NOT use these directly in UI code — import SemanticColors or
//  ComponentColors instead so intent is clear and theming stays consistent.
//
//  Created by Devvvv on 26/11/25.
//  Updated: Full palette with Dark Mode — Re-Hearse Design System v2.0
//

import UIKit

// MARK: - UIColor Hex Initializer

public extension UIColor {

    /// Creates a UIColor from a hex string.
    /// Supports formats: "#RRGGBB", "RRGGBB", "#AARRGGBB", "AARRGGBB"
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
            let g = CGFloat((rgbValue & 0x00FF00) >> 8)  / 255.0
            let b = CGFloat( rgbValue & 0x0000FF)         / 255.0
            self.init(red: r, green: g, blue: b, alpha: alpha)

        case 8: // AARRGGBB
            let a = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            let r = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            let g = CGFloat((rgbValue & 0x0000FF00) >> 8)  / 255.0
            let b = CGFloat( rgbValue & 0x000000FF)         / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)

        default:
            self.init(white: 0, alpha: 0)
        }
    }

    /// Like `adaptive`, with its own dark value while the Christmas theme is on (pine greens
    /// instead of the warm browns). Light Mode never changes with the theme.
    static func seasonal(light: UIColor, dark: UIColor, christmasDark: UIColor) -> UIColor {
        UIColor { traits in
            guard traits.userInterfaceStyle == .dark else { return light }
            return traits.seasonalTheme == .christmas ? christmasDark : dark
        }
    }

    /// Creates an adaptive UIColor that resolves to different values in Light vs Dark Mode.
    static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }
}


// MARK: - BrandColors Namespace

/// Raw, named color literals for the Re-Hearse design system.
/// These are the canonical definitions. Reference SemanticColors for usage intent.
public enum BrandColors {

    // ─────────────────────────────────────────────
    // MARK: Brand / Accent
    // ─────────────────────────────────────────────

    /// Primary brand orange — #EF9408
    /// Use for: CTAs, active states, progress indicators.
    /// Dark Mode: Same — orange pops equally on dark surfaces.
    public static let brand: UIColor = UIColor(hex: "#EF9408")

    /// Brand orange at 10% opacity — for graph fills, soft highlights.
    public static let brandSubtle: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#EF9408").withAlphaComponent(0.50),
        dark:  UIColor(hex: "#EF9408").withAlphaComponent(0.15)
    )


    // ─────────────────────────────────────────────
    // MARK: Backgrounds
    // ─────────────────────────────────────────────

    /// Christmas theme background (Figma "Christmas theme": #031711), dark appearance only.
    public static let christmasBackground: UIColor = UIColor(hex: "#031711")

    /// App-wide base background — Light: Modern Greige #F4F1ED / Dark: Deep charcoal #1A1714
    /// (#031711 deep pine green while the Christmas theme is on).
    public static let backgroundPrimary: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#F4F1ED"),
        dark:  UIColor(hex: "#1A1714"),
        christmasDark: christmasBackground
    )

    /// Card / surface layer — Light: #FFFFFF / Dark: #2A2520
    /// Always sits one level above backgroundPrimary.
    public static let backgroundSurface: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#FFFFFF"),
        dark:  UIColor(hex: "#2A2520"),
        christmasDark: UIColor(hex: "#0D2721")
    )

    /// Elevated card (modal, bottom sheet) — Light: #FFFFFF / Dark: #332D27
    /// Sits above backgroundSurface.
    public static let backgroundElevated: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#FFFFFF"),
        dark:  UIColor(hex: "#332D27"),
        christmasDark: UIColor(hex: "#14322A")
    )

    /// Nav bar / tab bar background — Light: #FFFFFF / Dark: #1F1C18
    /// (the Christmas background while that theme is on, so a scrolled header matches the page)
    public static let backgroundNavBar: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#FFFFFF"),
        dark:  UIColor(hex: "#1F1C18"),
        christmasDark: christmasBackground
    )


    // ─────────────────────────────────────────────
    // MARK: Text
    // ─────────────────────────────────────────────

    /// Primary text — Light: Warm near-black #2D2823 / Dark: Warm off-white #F0EDE8
    public static let textPrimary: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#2D2823"),
        dark:  UIColor(hex: "#F0EDE8")
    )

    /// Secondary text — Light: Warm mid-gray #6B6259 / Dark: #A89E95
    public static let textSecondary: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#6B6259"),
        dark:  UIColor(hex: "#A89E95")
    )

    /// Tertiary / placeholder text — Light: #9A9188 / Dark: #6E665F
    public static let textTertiary: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#9A9188"),
        dark:  UIColor(hex: "#6E665F")
    )

    /// Inverted text — always white; used on orange/dark filled buttons.
    public static let textInverted: UIColor = UIColor(hex: "#FFFFFF")

    /// Brand-colored text — for links, active labels, stat numbers.
    public static let textBrand: UIColor = BrandColors.brand


    // ─────────────────────────────────────────────
    // MARK: Strokes & Borders
    // ─────────────────────────────────────────────

    /// Default 1px separator / card border — Light: #E9E3DB / Dark: #3D3630
    public static let stroke: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#f5a73e"),
        dark:  UIColor(hex: "#3D3630"),
        christmasDark: UIColor(hex: "#405048")
    )

    /// Strong border — used for focused inputs — Light: #C9C0B5 / Dark: #5A504A
    public static let strokeStrong: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#C9C0B5"),
        dark:  UIColor(hex: "#5A504A"),
        christmasDark: UIColor(hex: "#557064")
    )

    /// Brand border — for selected / active card outlines.
    public static let strokeBrand: UIColor = BrandColors.brand


    // ─────────────────────────────────────────────
    // MARK: Semantic States
    // ─────────────────────────────────────────────

    /// Success green — Light: #2E7D52 / Dark: #4CAF7D
    public static let success: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#2E7D52"),
        dark:  UIColor(hex: "#4CAF7D")
    )

    /// Success background tint — Light: #EAF5EE / Dark: #1A2E22
    public static let successSubtle: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#EAF5EE"),
        dark:  UIColor(hex: "#1A2E22")
    )

    /// Error red — Light: #C0392B / Dark: #E57373
    public static let error: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#C0392B"),
        dark:  UIColor(hex: "#E57373")
    )

    /// Error background tint — Light: #FDECEA / Dark: #2E1A1A
    public static let errorSubtle: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#FDECEA"),
        dark:  UIColor(hex: "#2E1A1A")
    )


    // ─────────────────────────────────────────────
    // MARK: Disabled / Inactive
    // ─────────────────────────────────────────────

    /// Disabled fill — for inactive buttons and controls.
    public static let disabledFill: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#E9E3DB"),
        dark:  UIColor(hex: "#2E2925"),
        christmasDark: UIColor(hex: "#13302A")
    )

    /// Disabled text — for labels on inactive elements.
    public static let disabledText: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#B5ADA5"),
        dark:  UIColor(hex: "#504840"),
        christmasDark: UIColor(hex: "#4C6359")
    )

    /// Inactive tab icon / unselected nav icon.
    public static let iconInactive: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#9A9188"),
        dark:  UIColor(hex: "#6E665F")
    )


    // ─────────────────────────────────────────────
    // MARK: Skeleton / Shimmer
    // ─────────────────────────────────────────────

    /// Base layer of the skeleton loading placeholder.
    public static let skeletonBase: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#EAE6E1"),
        dark:  UIColor(hex: "#2A2520"),
        christmasDark: UIColor(hex: "#0D2721")
    )

    /// Highlight layer that animates across the skeleton.
    public static let skeletonHighlight: UIColor = UIColor.seasonal(
        light: UIColor(hex: "#F5F2EE"),
        dark:  UIColor(hex: "#3A342E"),
        christmasDark: UIColor(hex: "#1A3B32")
    )


    // ─────────────────────────────────────────────
    // MARK: Shadows / Elevation
    // ─────────────────────────────────────────────

    /// Level 1 — card shadow (subtle lift).
    /// Apply: opacity 0.06, radius 4, offset (0, 2)
    public static let shadowLevel1: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#2D2823").withAlphaComponent(0.06),
        dark:  UIColor(hex: "#000000").withAlphaComponent(0.25)
    )

    /// Level 2 — modal / bottom sheet shadow.
    /// Apply: opacity 0.10, radius 12, offset (0, 6)
    public static let shadowLevel2: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#2D2823").withAlphaComponent(0.10),
        dark:  UIColor(hex: "#000000").withAlphaComponent(0.40)
    )

    /// Level 3 — floating action / album art shadow.
    /// Apply: opacity 0.14, radius 24, offset (0, 10)
    public static let shadowLevel3: UIColor = UIColor.adaptive(
        light: UIColor(hex: "#2D2823").withAlphaComponent(0.14),
        dark:  UIColor(hex: "#000000").withAlphaComponent(0.55)
    )
}

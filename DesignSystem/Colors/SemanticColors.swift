//
//  SemanticColors.swift
//  Re-Hearse_v1
//
//  Semantic color tokens — the "why" layer of the design system.
//  Each token describes the INTENT of a color, not its raw value.
//  All values delegate to BrandColors, so a single palette change
//  propagates everywhere automatically.
//
//  Usage:
//      label.textColor = SemanticColors.Text.primary
//      view.backgroundColor = SemanticColors.Background.screen
//
//  Created by Devvvv on 26/11/25.
//  Updated: Re-Hearse Design System v2.0
//

import UIKit

// MARK: - SemanticColors

public enum SemanticColors {

    // =========================================================
    // MARK: Background
    // =========================================================

    public enum Background {

        /// The base canvas color for every screen.
        /// Always use this as the root UIViewController view background.
        /// Light: Greige #F4F1ED  |  Dark: Deep charcoal #1A1714
        public static let screen: UIColor = BrandColors.backgroundPrimary

        /// White card / content surface that "lifts" off the screen background.
        /// Light: #FFFFFF  |  Dark: #2A2520
        public static let card: UIColor = BrandColors.backgroundSurface

        /// Elevated surface for modals, bottom sheets, and popovers.
        /// Light: #FFFFFF  |  Dark: #332D27
        public static let modal: UIColor = BrandColors.backgroundElevated

        /// Navigation bar and tab bar background.
        /// Light: #FFFFFF  |  Dark: #1F1C18
        public static let navigation: UIColor = BrandColors.backgroundNavBar

        /// Tinted background for the brand-colored primary CTA button.
        public static let primaryButton: UIColor = BrandColors.brand

        /// Tinted background for secondary / ghost buttons.
        /// Light: #FFFFFF  |  Dark: #2A2520
        public static let secondaryButton: UIColor = BrandColors.backgroundSurface

        /// Background for disabled buttons and controls.
        public static let disabledButton: UIColor = BrandColors.disabledFill

        /// Background for success alert banners / toast views.
        public static let successBanner: UIColor = BrandColors.successSubtle

        /// Background for error alert banners / toast views.
        public static let errorBanner: UIColor = BrandColors.errorSubtle

        /// Background for warning alert banners / toast views.
        public static let warningBanner: UIColor = BrandColors.warningSubtle

        /// Base layer for skeleton loading placeholders.
        public static let skeletonBase: UIColor = BrandColors.skeletonBase

        /// Highlight layer that sweeps across skeleton placeholders (animate this).
        public static let skeletonHighlight: UIColor = BrandColors.skeletonHighlight

        /// Very subtle brand-tinted background — graph area fills, soft chips.
        public static let brandTint: UIColor = BrandColors.brandSubtle
    }


    // =========================================================
    // MARK: Text
    // =========================================================

    public enum Text {

        /// Main titles, song names, body copy, button labels.
        /// Light: Warm near-black #2D2823  |  Dark: Warm off-white #F0EDE8
        public static let primary: UIColor = BrandColors.textPrimary

        /// Artist names, dates, metadata, subtitles.
        /// Light: #6B6259  |  Dark: #A89E95
        public static let secondary: UIColor = BrandColors.textSecondary

        /// Placeholder text, axis labels, timestamps, captions.
        /// Light: #9A9188  |  Dark: #6E665F
        public static let tertiary: UIColor = BrandColors.textTertiary

        /// Text on orange / filled brand buttons. Always white.
        public static let onBrand: UIColor = BrandColors.textInverted

        /// Text on dark filled surfaces (dark cards in Dark Mode). Always near-white.
        public static let inverted: UIColor = BrandColors.textInverted

        /// Stat numbers (e.g., "42.5h"), active filter labels, links.
        public static let brand: UIColor = BrandColors.textBrand

        /// Text on disabled buttons or controls.
        public static let disabled: UIColor = BrandColors.disabledText

        /// Success message text.
        public static let success: UIColor = BrandColors.success

        /// Error message text.
        public static let error: UIColor = BrandColors.error

        /// Warning message text.
        public static let warning: UIColor = BrandColors.warning

        /// Sheet music notation, staff lines, note heads.
        /// Uses primary text to give an "ink on paper" look — never pure black.
        public static let musicNotation: UIColor = BrandColors.textPrimary
    }


    // =========================================================
    // MARK: Icon
    // =========================================================

    public enum Icon {

        /// Active / selected icon in tab bar or toolbar.
        public static let active: UIColor = BrandColors.brand

        /// Unselected / idle icon in tab bar or toolbar.
        public static let inactive: UIColor = BrandColors.iconInactive

        /// Icon on a filled orange button (e.g., scan button).
        public static let onBrand: UIColor = BrandColors.textInverted

        /// Standard icon next to list items or labels.
        public static let `default`: UIColor = BrandColors.textSecondary

        /// Disabled icon.
        public static let disabled: UIColor = BrandColors.disabledText
    }


    // =========================================================
    // MARK: Border & Stroke
    // =========================================================

    public enum Border {

        /// Default 1px separator line — between cards, cells, sections.
        /// Light: #E9E3DB  |  Dark: #3D3630
        public static let `default`: UIColor = BrandColors.stroke

        /// Stronger border for text input fields and focused containers.
        public static let input: UIColor = BrandColors.strokeStrong

        /// Brand orange border — selected card, active quiz bubble.
        public static let active: UIColor = BrandColors.strokeBrand

        /// Success-colored border.
        public static let success: UIColor = BrandColors.success

        /// Error-colored border — wrong answer flash.
        public static let error: UIColor = BrandColors.error
    }


    // =========================================================
    // MARK: States
    // =========================================================

    public enum State {

        /// Correct answer indicator (quiz feedback).
        public static let correct: UIColor = BrandColors.success

        /// Correct answer background tint.
        public static let correctSubtle: UIColor = BrandColors.successSubtle

        /// Wrong answer indicator (quiz feedback).
        public static let incorrect: UIColor = BrandColors.error

        /// Wrong answer background tint.
        public static let incorrectSubtle: UIColor = BrandColors.errorSubtle

        /// Warning / caution state.
        public static let warning: UIColor = BrandColors.warning

        /// Warning background tint.
        public static let warningSubtle: UIColor = BrandColors.warningSubtle

        /// Pressed / ripple tint for brand buttons.
        public static let brandPressed: UIColor = BrandColors.brandPressed

        /// Disabled control fill.
        public static let disabled: UIColor = BrandColors.disabledFill
    }


    // =========================================================
    // MARK: Progress & Data Viz
    // =========================================================

    public enum DataViz {

        /// Progress bar / ring fill — always brand orange.
        public static let progressFill: UIColor = BrandColors.brand

        /// Progress bar track (unfilled portion).
        public static let progressTrack: UIColor = BrandColors.disabledFill

        /// Graph line color.
        public static let graphLine: UIColor = BrandColors.brand

        /// Graph area fill (10% opacity orange).
        public static let graphAreaFill: UIColor = BrandColors.brandSubtle

        /// Axis tick labels on charts.
        public static let axisLabel: UIColor = BrandColors.textTertiary

        /// Grid lines on charts.
        public static let gridLine: UIColor = BrandColors.stroke
    }


    // =========================================================
    // MARK: Shadow
    // =========================================================

    public enum Shadow {

        /// Subtle lift — use for standard list/content cards.
        /// Config: opacity 0.06, radius 4pt, offset (0, 2)
        public static let level1: UIColor = BrandColors.shadowLevel1

        /// Medium lift — modals, action sheets, bottom drawers.
        /// Config: opacity 0.10, radius 12pt, offset (0, 6)
        public static let level2: UIColor = BrandColors.shadowLevel2

        /// Strong lift — floating album art, FABs, tooltips.
        /// Config: opacity 0.14, radius 24pt, offset (0, 10)
        public static let level3: UIColor = BrandColors.shadowLevel3
    }
}


// MARK: - UIView Shadow Helper

public extension UIView {

    /// Applies a standardized Re-Hearse shadow to any view.
    /// - Parameters:
    ///   - level: Shadow intensity (1 = subtle, 2 = modal, 3 = floating)
    ///   - cornerRadius: Optionally sync the shadow path with a rounded corner.
    func applyReHearseShader(level: Int = 1, cornerRadius: CGFloat = 0) {
        layer.masksToBounds = false

        switch level {
        case 1:
            layer.shadowColor   = SemanticColors.Shadow.level1.cgColor
            layer.shadowOpacity = 0.06
            layer.shadowRadius  = 4
            layer.shadowOffset  = CGSize(width: 0, height: 2)

        case 2:
            layer.shadowColor   = SemanticColors.Shadow.level2.cgColor
            layer.shadowOpacity = 0.10
            layer.shadowRadius  = 12
            layer.shadowOffset  = CGSize(width: 0, height: 6)

        case 3:
            layer.shadowColor   = SemanticColors.Shadow.level3.cgColor
            layer.shadowOpacity = 0.14
            layer.shadowRadius  = 24
            layer.shadowOffset  = CGSize(width: 0, height: 10)

        default:
            break
        }

        if cornerRadius > 0 {
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: cornerRadius
            ).cgPath
        }
    }
}

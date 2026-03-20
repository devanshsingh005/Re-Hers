//
//  UIColorLegacyBridge.swift
//  Re-Hearse_v1
//
//  Maps legacy UIColor property names used across the onboarding screens to
//  their canonical design-system equivalents. This file is intentionally thin —
//  all real colour values live in BrandColors / SemanticColors / ComponentColors.
//  Do NOT add new colour names here; use ComponentColors or SemanticColors directly.
//

import UIKit

extension UIColor {

    // MARK: - Legacy Aliases (onboarding screens)

    /// Primary brand accent — Amber Orange.
    /// Previously used as the "selected" and "CTA button" colour.
    static var primaryColor: UIColor { BrandColors.brand }

    /// Secondary brand accent — same amber, used for selected-state tints.
    static var secondaryColor: UIColor { BrandColors.brand }

    /// App-wide background — warm Greige in light mode, charcoal in dark mode.
    static var appBackground: UIColor { SemanticColors.Background.screen }

    /// Dark grey used for inactive step-indicator dots.
    static var darkGray1: UIColor { SemanticColors.Text.secondary }
}

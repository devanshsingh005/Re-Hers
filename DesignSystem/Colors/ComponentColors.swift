//
//  ComponentColors.swift
//  Re-Hearse_v1
//
//  Component-level color tokens — the "where" layer of the design system.
//  Each nested enum maps directly to a screen or reusable component.
//  All values delegate to SemanticColors (which delegates to BrandColors),
//  keeping the chain clean: Component → Semantic → Brand.
//
//  Usage:
//      view.backgroundColor = ComponentColors.HomeScreen.background
//      label.textColor      = ComponentColors.SongCard.titleText
//
//  ┌─────────────────────────────────────────────────────────┐
//  │  Rule of thumb: Import ONLY ComponentColors in UI files. │
//  │  Only touch SemanticColors for new generic components.   │
//  │  Never reference BrandColors directly in view code.      │
//  └─────────────────────────────────────────────────────────┘
//
//  Created by Devvvv on 26/11/25.
//  Updated: Re-Hearse Design System v2.0
//

import UIKit

// MARK: - ComponentColors

public enum ComponentColors {

    // =========================================================
    // MARK: 1. Global / App Shell
    // =========================================================

    public enum App {
        /// Root background color — applied to every UIViewController.view
        public static let screenBackground: UIColor = SemanticColors.Background.screen
    }


    // =========================================================
    // MARK: 2. Navigation Bar
    // =========================================================

    public enum NavBar {
        public static let background:    UIColor = SemanticColors.Background.navigation
        public static let title:         UIColor = SemanticColors.Text.primary
        public static let backButton:    UIColor = SemanticColors.Text.brand
        public static let rightButton:   UIColor = SemanticColors.Text.brand
        public static let separator:     UIColor = SemanticColors.Border.default
    }


    // =========================================================
    // MARK: 3. Tab Bar
    // =========================================================

    public enum TabBar {
        public static let background:    UIColor = SemanticColors.Background.navigation
        public static let activeIcon:    UIColor = SemanticColors.Icon.active
        public static let inactiveIcon:  UIColor = SemanticColors.Icon.inactive
        public static let activeLabel:   UIColor = SemanticColors.Text.brand
        public static let inactiveLabel: UIColor = SemanticColors.Text.tertiary
        public static let separator:     UIColor = SemanticColors.Border.default
    }


    // =========================================================
    // MARK: 4. Home / Upload Screen
    // =========================================================

    public enum HomeScreen {
        public static let background:        UIColor = SemanticColors.Background.screen

        // Top action buttons (Scan / Upload)
        public static let actionButtonFill:          UIColor = SemanticColors.Background.primaryButton
        public static let actionButtonGradientStart: UIColor = BrandColors.brand
        public static let actionButtonGradientEnd:   UIColor = BrandColors.brandDark
        public static let actionButtonText:  UIColor = SemanticColors.Text.onBrand
        public static let actionButtonCornerRadius: CGFloat = 14

        // Section headers
        public static let sectionHeaderText: UIColor = SemanticColors.Text.primary

        // "Recent Uploads" empty state
        public static let emptyStateIcon:    UIColor = SemanticColors.Icon.inactive
        public static let emptyStateText:    UIColor = SemanticColors.Text.secondary
    }


    // =========================================================
    // MARK: 5. File / Song Card (List Item)
    // =========================================================

    public enum SongCard {
        public static let background:     UIColor = SemanticColors.Background.card
        public static let border:         UIColor = SemanticColors.Border.default
        public static let cornerRadius:   CGFloat = 12

        public static let fileIcon:       UIColor = SemanticColors.Text.brand
        public static let titleText:      UIColor = SemanticColors.Text.primary
        public static let metadataText:   UIColor = SemanticColors.Text.secondary   // date, size, BPM

        public static let chevronIcon:    UIColor = SemanticColors.Icon.inactive

        // Skeleton state
        public static let skeletonBase:   UIColor = SemanticColors.Background.skeletonBase
        public static let skeletonShimmer:UIColor = SemanticColors.Background.skeletonHighlight
    }


    // =========================================================
    // MARK: 6. Practice Mode / Quiz Screen
    // =========================================================

    public enum QuizScreen {
        public static let background:       UIColor = SemanticColors.Background.screen

        // Question card (large white card at top)
        public static let questionCardFill: UIColor = SemanticColors.Background.card
        public static let questionCardBorder:UIColor = SemanticColors.Border.default

        // Sheet music rendered on the question card
        public static let staffLines:       UIColor = SemanticColors.Text.musicNotation
        public static let noteHeads:        UIColor = SemanticColors.Text.musicNotation
        public static let clefSymbol:       UIColor = SemanticColors.Text.musicNotation
        public static let noteLabel:        UIColor = SemanticColors.Text.secondary

        // Multiple choice bubbles
        public static let bubbleDefaultFill:   UIColor = SemanticColors.Background.card
        public static let bubbleDefaultBorder: UIColor = SemanticColors.Border.default
        public static let bubbleDefaultText:   UIColor = SemanticColors.Text.primary

        public static let bubbleSelectedFill:   UIColor = SemanticColors.Background.primaryButton
        public static let bubbleSelectedBorder: UIColor = SemanticColors.Border.active
        public static let bubbleSelectedText:   UIColor = SemanticColors.Text.onBrand

        public static let bubbleCorrectBorder:  UIColor = SemanticColors.State.correct
        public static let bubbleCorrectFill:    UIColor = SemanticColors.State.correctSubtle

        public static let bubbleIncorrectBorder:UIColor = SemanticColors.State.incorrect
        public static let bubbleIncorrectFill:  UIColor = SemanticColors.State.incorrectSubtle

        // Feedback toast / banner
        public static let correctBannerFill:    UIColor = SemanticColors.State.correctSubtle
        public static let correctBannerText:    UIColor = SemanticColors.State.correct
        public static let incorrectBannerFill:  UIColor = SemanticColors.State.incorrectSubtle
        public static let incorrectBannerText:  UIColor = SemanticColors.State.incorrect

        // Progress bar at top
        public static let progressTrack:        UIColor = SemanticColors.DataViz.progressTrack
        public static let progressFill:         UIColor = SemanticColors.DataViz.progressFill

        // Question counter label (e.g., "Q 3 of 10")
        public static let counterText:          UIColor = SemanticColors.Text.tertiary
        public static let counterHighlight:     UIColor = SemanticColors.Text.brand
    }


    // =========================================================
    // MARK: 7. Song Detail & Sheet Music Viewer
    // =========================================================

    public enum SongDetailScreen {
        public static let background:            UIColor = SemanticColors.Background.screen

        // Album art card (floats above background)
        public static let albumArtBackground:    UIColor = SemanticColors.Background.card
        // Apply shadow level 3 to the album art container view.

        // Song metadata
        public static let songTitle:             UIColor = SemanticColors.Text.primary
        public static let artistName:            UIColor = SemanticColors.Text.secondary
        public static let durationLabel:         UIColor = SemanticColors.Text.tertiary

        // Primary action — "Play Along" button
        public static let primaryActionFill:     UIColor = SemanticColors.Background.primaryButton
        public static let primaryActionText:     UIColor = SemanticColors.Text.onBrand
        public static let primaryActionRadius:   CGFloat = 14

        // Secondary action — "View Animation" button
        public static let secondaryActionFill:   UIColor = SemanticColors.Background.secondaryButton
        public static let secondaryActionBorder: UIColor = SemanticColors.Border.default
        public static let secondaryActionText:   UIColor = SemanticColors.Text.primary
        public static let secondaryActionRadius: CGFloat = 14

        // Sheet music viewer card
        public static let sheetMusicCardFill:    UIColor = SemanticColors.Background.card
        public static let sheetMusicCardBorder:  UIColor = SemanticColors.Border.default
        public static let sheetMusicBackground:  UIColor = SemanticColors.Background.card  // "paper"
        public static let sheetMusicNotation:    UIColor = SemanticColors.Text.musicNotation

        // Playhead / scrubber
        public static let scrubberTrack:         UIColor = SemanticColors.DataViz.progressTrack
        public static let scrubberFill:          UIColor = SemanticColors.DataViz.progressFill
        public static let scrubberThumb:         UIColor = SemanticColors.Background.primaryButton
        public static let timeLabel:             UIColor = SemanticColors.Text.tertiary

        // Tempo / key signature chip
        public static let chipFill:              UIColor = SemanticColors.Background.brandTint
        public static let chipText:              UIColor = SemanticColors.Text.brand
        public static let chipBorder:            UIColor = SemanticColors.Border.active
    }


    // =========================================================
    // MARK: 8. Discover Screen
    // =========================================================

    public enum DiscoverScreen {
        public static let background:        UIColor = SemanticColors.Background.screen
        
        public static let sectionHeader:     UIColor = SemanticColors.Text.primary
        public static let emptyStateText:    UIColor = SemanticColors.Text.secondary
        
        // Chips (Top categories - "All", "Piano", etc)
        public static let chipBackgroundDefault:  UIColor = SemanticColors.Background.secondaryButton
        public static let chipBackgroundSelected: UIColor = SemanticColors.Background.primaryButton
        public static let chipTextDefault:        UIColor = SemanticColors.Text.secondary
        public static let chipTextSelected:       UIColor = SemanticColors.Text.onBrand
        
        // Skill Tiles (Large square buttons)
        public static let skillTileBackground:    UIColor = SemanticColors.Background.card
        public static let skillTileIcon:          UIColor = SemanticColors.Icon.primary
        public static let skillTileTitle:         UIColor = SemanticColors.Text.secondary
    }


    // =========================================================
    // MARK: 9. Discovery Song Card (List Item)
    // =========================================================

    public enum DiscoverySongCard {
        public static let artPlaceholder:    UIColor = SemanticColors.Background.secondaryButton
        public static let artPlaceholderText:UIColor = SemanticColors.Text.tertiary
        
        public static let titleText:         UIColor = SemanticColors.Text.primary
        public static let subtitleText:      UIColor = SemanticColors.Text.secondary
        
        public static let accessoryIcon:     UIColor = SemanticColors.Icon.inactive
        public static let separator:         UIColor = SemanticColors.Border.default
    }


    // =========================================================
    // MARK: 8. User Profile & Analytics Screen
    // =========================================================

    public enum ProfileScreen {
        public static let background:          UIColor = SemanticColors.Background.screen

        // Profile header card
        public static let headerCardFill:      UIColor = SemanticColors.Background.card
        public static let headerCardBorder:    UIColor = SemanticColors.Border.default
        public static let avatarBorder:        UIColor = SemanticColors.Border.active       // orange ring
        public static let userName:            UIColor = SemanticColors.Text.primary
        public static let userHandle:          UIColor = SemanticColors.Text.secondary
        public static let editProfileText:     UIColor = SemanticColors.Text.brand

        // Stat cards (Sessions / Practice Time / Streak)
        public static let statCardFill:        UIColor = SemanticColors.Background.card
        public static let statCardBorder:      UIColor = SemanticColors.Border.default
        public static let statNumber:          UIColor = SemanticColors.Text.brand           // big orange number
        public static let statLabel:           UIColor = SemanticColors.Text.secondary       // "PRACTICE", "SESSIONS"

        // Progress / Activity graph
        public static let graphLine:           UIColor = SemanticColors.DataViz.graphLine
        public static let graphAreaFill:       UIColor = SemanticColors.DataViz.graphAreaFill
        public static let graphAxisLabel:      UIColor = SemanticColors.DataViz.axisLabel
        public static let graphGridLine:       UIColor = SemanticColors.DataViz.gridLine

        // Achievement / badge row
        public static let badgeUnlocked:       UIColor = SemanticColors.Text.brand
        public static let badgeLocked:         UIColor = SemanticColors.Icon.inactive

        // Settings list (inside profile)
        public static let settingsCellFill:    UIColor = SemanticColors.Background.card
        public static let settingsCellText:    UIColor = SemanticColors.Text.primary
        public static let settingsCellDetail:  UIColor = SemanticColors.Text.secondary
        public static let settingsSeparator:   UIColor = SemanticColors.Border.default
        public static let settingsChevron:     UIColor = SemanticColors.Icon.inactive

        // Destructive action (Log Out)
        public static let destructiveText:     UIColor = SemanticColors.State.incorrect
    }


    // =========================================================
    // MARK: 9. Lesson / Learning Screens (L1, L2, etc.)
    // =========================================================

    public enum LessonScreen {
        public static let background:     UIColor = SemanticColors.Background.screen
        public static let correctAnswer:  UIColor = SemanticColors.State.correct      // green badge / dot
        public static let incorrectAnswer:UIColor = SemanticColors.State.incorrect    // red indication
        public static let progressFill:   UIColor = SemanticColors.DataViz.progressFill
        public static let progressTrack:  UIColor = SemanticColors.DataViz.progressTrack
        public static let cardFill:       UIColor = SemanticColors.Background.card
        public static let cardBorder:     UIColor = SemanticColors.Border.default
        public static let labelPrimary:   UIColor = SemanticColors.Text.primary
        public static let labelSecondary: UIColor = SemanticColors.Text.secondary
        public static let brandAccent:    UIColor = SemanticColors.Text.brand
    }

    // =========================================================
    // MARK: 10. Learning Curve / Map Screen
    // =========================================================

    public enum LearningCurve {
        public static let background:        UIColor = SemanticColors.Background.screen
        
        // Node / Lesson Bubble
        public static let nodeCompletedFill: UIColor = SemanticColors.Background.card
        public static let nodeActiveFill:    UIColor = SemanticColors.Background.card
        public static let nodeLockedFill:    UIColor = SemanticColors.Background.secondaryButton
        public static let nodeLockedBorder:  UIColor = SemanticColors.Border.default
        
        public static let nodeIconCompleted: UIColor = SemanticColors.State.correct
        public static let nodeIconActive:    UIColor = SemanticColors.Text.brand
        public static let nodeIconLocked:    UIColor = SemanticColors.Icon.inactive
        
        // Connection Lines
        public static let pathCompleted:     UIColor = SemanticColors.Text.brand
        public static let pathLocked:        UIColor = SemanticColors.Border.default
        
        // Chapter Header
        public static let headerTitle:       UIColor = SemanticColors.Text.primary
        public static let headerSubtitle:    UIColor = SemanticColors.Text.secondary
        public static let chapterBadgeFill:  UIColor = SemanticColors.Text.brand
        public static let chapterBadgeText:  UIColor = SemanticColors.Text.onBrand
        
        // Unlocked Popup
        public static let popupBackground:   UIColor = SemanticColors.Background.card
        public static let popupTitle:        UIColor = SemanticColors.Text.primary
        public static let popupSubtitle:     UIColor = SemanticColors.Text.secondary
        public static let popupShadow:       UIColor = UIColor.black
    }


    // =========================================================
    // MARK: 10. Onboarding / Auth Screens
    // =========================================================

    public enum AuthScreen {
        public static let background:         UIColor = SemanticColors.Background.screen
        public static let headlineText:       UIColor = SemanticColors.Text.primary
        public static let bodyText:           UIColor = SemanticColors.Text.secondary

        // Input fields
        public static let inputFill:          UIColor = SemanticColors.Background.card
        public static let inputBorder:        UIColor = SemanticColors.Border.input
        public static let inputBorderFocused: UIColor = SemanticColors.Border.active
        public static let inputText:          UIColor = SemanticColors.Text.primary
        public static let inputPlaceholder:   UIColor = SemanticColors.Text.tertiary
        public static let inputErrorBorder:   UIColor = SemanticColors.Border.error
        public static let inputErrorText:     UIColor = SemanticColors.State.incorrect

        // CTA button
        public static let ctaFill:            UIColor = SemanticColors.Background.primaryButton
        public static let ctaText:            UIColor = SemanticColors.Text.onBrand
        public static let ctaRadius:          CGFloat = 14

        // Social / secondary auth button
        public static let secondaryFill:      UIColor = SemanticColors.Background.card
        public static let secondaryBorder:    UIColor = SemanticColors.Border.default
        public static let secondaryText:      UIColor = SemanticColors.Text.primary

        // Link text ("Sign In", "Forgot password?")
        public static let linkText:           UIColor = SemanticColors.Text.brand
    }


    // =========================================================
    // MARK: 10. Reusable UI Atoms
    // =========================================================

    // ── Buttons ─────────────────────────────────────────────

    public enum PrimaryButton {
        public static let fill:         UIColor = SemanticColors.Background.primaryButton
        public static let text:         UIColor = SemanticColors.Text.onBrand
        public static let pressedFill:  UIColor = SemanticColors.State.brandPressed
        public static let disabledFill: UIColor = SemanticColors.State.disabled
        public static let disabledText: UIColor = SemanticColors.Text.disabled
        public static let cornerRadius: CGFloat = 14
    }

    public enum SecondaryButton {
        public static let fill:         UIColor = SemanticColors.Background.secondaryButton
        public static let border:       UIColor = SemanticColors.Border.default
        public static let text:         UIColor = SemanticColors.Text.primary
        public static let disabledFill: UIColor = SemanticColors.State.disabled
        public static let disabledText: UIColor = SemanticColors.Text.disabled
        public static let cornerRadius: CGFloat = 14
    }

    public enum TextButton {
        public static let text:         UIColor = SemanticColors.Text.brand
        public static let disabledText: UIColor = SemanticColors.Text.disabled
    }

    public enum DestructiveButton {
        public static let fill:         UIColor = SemanticColors.State.incorrectSubtle
        public static let border:       UIColor = SemanticColors.State.incorrect
        public static let text:         UIColor = SemanticColors.State.incorrect
        public static let cornerRadius: CGFloat = 14
    }

    // ── Chips / Tags ─────────────────────────────────────────

    public enum Chip {
        public static let defaultFill:   UIColor = SemanticColors.Background.card
        public static let defaultBorder: UIColor = SemanticColors.Border.default
        public static let defaultText:   UIColor = SemanticColors.Text.secondary

        public static let activeFill:    UIColor = SemanticColors.Background.brandTint
        public static let activeBorder:  UIColor = SemanticColors.Border.active
        public static let activeText:    UIColor = SemanticColors.Text.brand

        public static let cornerRadius:  CGFloat = 20
    }

    // ── Toast / Alert Banner ─────────────────────────────────

    public enum Toast {
        public static let successFill:   UIColor = SemanticColors.Background.successBanner
        public static let successText:   UIColor = SemanticColors.State.correct
        public static let successIcon:   UIColor = SemanticColors.State.correct

        public static let errorFill:     UIColor = SemanticColors.Background.errorBanner
        public static let errorText:     UIColor = SemanticColors.State.incorrect
        public static let errorIcon:     UIColor = SemanticColors.State.incorrect

        public static let warningFill:   UIColor = SemanticColors.Background.warningBanner
        public static let warningText:   UIColor = SemanticColors.State.warning
        public static let warningIcon:   UIColor = SemanticColors.State.warning

        public static let cornerRadius:  CGFloat = 12
    }

    // ── Dividers / Separators ────────────────────────────────

    public enum Divider {
        public static let color: UIColor = SemanticColors.Border.default
    }

    // ── Skeleton / Loading ───────────────────────────────────

    public enum Skeleton {
        public static let base:      UIColor = SemanticColors.Background.skeletonBase
        public static let shimmer:   UIColor = SemanticColors.Background.skeletonHighlight
        public static let cornerRadius: CGFloat = 8
    }
}

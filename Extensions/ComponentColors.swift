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
        public static let rightButton:   UIColor = SemanticColors.Text.brand
        public static let separator:     UIColor = SemanticColors.Border.default
    }

    // =========================================================
    // MARK: 3. Tab Bar
    // =========================================================

    public enum TabBar {
        public static let activeIcon:    UIColor = SemanticColors.Icon.active
        public static let inactiveIcon:  UIColor = SemanticColors.Icon.inactive
    }

    // =========================================================
    // MARK: 4. Home / Upload Screen
    // =========================================================

    public enum HomeScreen {
        public static let background:        UIColor = SemanticColors.Background.screen
        public static let cardBackground:     UIColor = SemanticColors.Background.card

        // Top action buttons (Scan / Upload)
        public static let actionButtonFill:          UIColor = SemanticColors.Background.primaryButton
        public static let actionButtonText:  UIColor = SemanticColors.Text.onBrand

        // Section headers

        // "Recent Uploads" empty state
    }

    // =========================================================
    // MARK: 5. File / Song Card (List Item)
    // =========================================================

    public enum SongCard {
        public static let background:     UIColor = SemanticColors.Background.card
        public static let border:         UIColor = SemanticColors.Border.default

        public static let fileIcon:       UIColor = SemanticColors.Text.brand
        public static let titleText:      UIColor = SemanticColors.Text.primary
        public static let metadataText:   UIColor = SemanticColors.Text.secondary   // date, size, BPM

        // Skeleton state
    }

    // =========================================================
    // MARK: 6. Practice Mode / Quiz Screen
    // =========================================================

    public enum QuizScreen {

        // Question card (large white card at top)

        // Sheet music rendered on the question card
        public static let staffLines:       UIColor = SemanticColors.Text.musicNotation
        public static let clefSymbol:       UIColor = SemanticColors.Text.musicNotation

        // Multiple choice bubbles

        // Feedback toast / banner

        // Progress bar at top
        public static let progressFill:         UIColor = SemanticColors.DataViz.progressFill

        // Question counter label (e.g., "Q 3 of 10")
    }

    // =========================================================
    // MARK: 7. Song Detail & Sheet Music Viewer
    // =========================================================

    public enum SongDetailScreen {
        public static let background:            UIColor = SemanticColors.Background.screen

        // Album art card (floats above background)
        // Apply shadow level 3 to the album art container view.

        // Song metadata
        public static let songTitle:             UIColor = SemanticColors.Text.primary
        public static let artistName:            UIColor = SemanticColors.Text.secondary

        // Primary action — "Play Along" button
        public static let primaryActionFill:     UIColor = SemanticColors.Background.primaryButton
        public static let primaryActionText:     UIColor = SemanticColors.Text.onBrand

        // Secondary action — "View Animation" button
        public static let secondaryActionFill:   UIColor = SemanticColors.Background.secondaryButton
        public static let secondaryActionBorder: UIColor = SemanticColors.Border.default
        public static let secondaryActionText:   UIColor = SemanticColors.Text.primary

        // Sheet music viewer card
        public static let sheetMusicCardFill:    UIColor = SemanticColors.Background.card
        public static let sheetMusicBackground:  UIColor = SemanticColors.Background.card  // "paper"

        // Playhead / scrubber

        // Tempo / key signature chip
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
        public static let chipTextDefault:        UIColor = SemanticColors.Text.secondary
        
        // Skill Tiles (Large square buttons)
    }

    // =========================================================
    // MARK: 9. Discovery Song Card (List Item)
    // =========================================================

    public enum DiscoverySongCard {
        public static let artPlaceholder:    UIColor = SemanticColors.Background.secondaryButton
        
        public static let titleText:         UIColor = SemanticColors.Text.primary
        
        public static let separator:         UIColor = SemanticColors.Border.default
    }

    // =========================================================
    // MARK: 8. User Profile & Analytics Screen
    // =========================================================

    public enum ProfileScreen {
        public static let background:          UIColor = SemanticColors.Background.screen

        // Profile header card
        public static let headerCardFill:      UIColor = SemanticColors.Background.card
        public static let avatarBorder:        UIColor = SemanticColors.Border.active       // orange ring
        public static let userName:            UIColor = SemanticColors.Text.primary
        public static let userHandle:          UIColor = SemanticColors.Text.secondary
        public static let editProfileText:     UIColor = SemanticColors.Text.brand

        // Stat cards (Sessions / Practice Time / Streak)
        public static let statCardFill:        UIColor = SemanticColors.Background.card
        public static let statCardBorder:      UIColor = SemanticColors.Border.default
        public static let statLabel:           UIColor = SemanticColors.Text.secondary       // "PRACTICE", "SESSIONS"

        // Progress / Activity graph
        public static let graphAxisLabel:      UIColor = SemanticColors.DataViz.axisLabel

        // Achievement / badge row

        // Settings list (inside profile)
        public static let settingsCellFill:    UIColor = SemanticColors.Background.card

        // Destructive action (Log Out)
    }

    // =========================================================
    // MARK: 9. Lesson / Learning Screens (L1, L2, etc.)
    // =========================================================

    public enum LessonScreen {
        public static let background:     UIColor = SemanticColors.Background.screen
        public static let correctAnswer:  UIColor = SemanticColors.State.correct      // green badge / dot
        public static let incorrectAnswer:UIColor = SemanticColors.State.incorrect    // red indication
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
        
        // Node / Lesson Bubble
        public static let nodeCompletedFill: UIColor = SemanticColors.Background.primaryButton
        public static let nodeActiveFill:    UIColor = SemanticColors.Background.card
        public static let nodeLockedFill:    UIColor = SemanticColors.Background.secondaryButton
        public static let nodeLockedBorder:  UIColor = SemanticColors.Border.default
        
        public static let nodeIconCompleted: UIColor = SemanticColors.Text.onBrand
        public static let nodeIconActive:    UIColor = SemanticColors.Text.brand
        public static let nodeIconLocked:    UIColor = SemanticColors.Icon.inactive
        
        // Connection Lines
        public static let pathCompleted:     UIColor = SemanticColors.Text.brand
        
        // Chapter Header
        public static let headerTitle:       UIColor = SemanticColors.Text.primary
        public static let headerSubtitle:    UIColor = SemanticColors.Text.secondary
        public static let chapterBadgeFill:  UIColor = SemanticColors.Text.brand
        public static let chapterBadgeText:  UIColor = SemanticColors.Text.onBrand
        
        // Unlocked Popup
        public static let popupBackground:   UIColor = SemanticColors.Background.card
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
        public static let inputText:          UIColor = SemanticColors.Text.primary
        public static let inputErrorText:     UIColor = SemanticColors.State.incorrect

        // CTA button
        public static let ctaFill:            UIColor = SemanticColors.Background.primaryButton
        public static let ctaText:            UIColor = SemanticColors.Text.onBrand

        // Social / secondary auth button

        // Link text ("Sign In", "Forgot password?")
        public static let linkText:           UIColor = SemanticColors.Text.brand
    }

    // =========================================================
    // MARK: 10. Reusable UI Atoms
    // =========================================================

    // ── Buttons ─────────────────────────────────────────────

    public enum PrimaryButton {
        public static let text:         UIColor = SemanticColors.Text.onBrand
    }

    public enum DestructiveButton {
        public static let border:       UIColor = SemanticColors.State.incorrect
    }

    // ── Chips / Tags ─────────────────────────────────────────

    // ── Toast / Alert Banner ─────────────────────────────────

    // ── Dividers / Separators ────────────────────────────────

    // ── Skeleton / Loading ───────────────────────────────────

}

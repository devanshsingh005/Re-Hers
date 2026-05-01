<!-- converted from ReHearse_Implementation_Plan.docx -->

Re-Hearse
Design System — Implementation Plan
Step-by-step guide for applying BrandColors → SemanticColors → ComponentColors across all screens
Golden import rule


The three design rules — check these on every screen

Quick color reference

Phase 0    Foundation — Design System Files
Do this before touching any screen



Phase 1    App Shell — Nav Bar, Tab Bar, Root Background
Global chrome — affects every screen




Phase 2    Home / Upload Screen
Entry point of the app





Phase 3    Practice Mode / Quiz Screen
The core learning experience





Phase 4    Song Detail & Sheet Music Viewer
The music reading experience






Phase 5    User Profile & Analytics
Stats, graphs, settings





Re-Hearse Design System v2.0  ·  BrandColors → SemanticColors → ComponentColors
| In view files: import ONLY ComponentColors. Never reference BrandColors or raw hex values directly in UI code. |
| --- |
| ✓ view.backgroundColor = ComponentColors.HomeScreen.background
✗ view.backgroundColor = UIColor(hex: "#F4F1ED") |
| --- |
| Rule | What it means | How to check |
| --- | --- | --- |
| The Lifting Rule | White cards always sit on Greige background. Never white on white without a border. | Look at any card screen — the card must visibly pop off the background. |
| The Orange Limit | Only one solid orange element per screen at a time. | Scan every screen. If two orange-filled elements are visible simultaneously, fix one. |
| Softness over Starkness | Use #2D2823 instead of pure black (#000000) for text and notation. | Search the codebase for UIColor.black or #000000 — replace all with textPrimary. |
| Element | Light Mode | Dark Mode | File |
| --- | --- | --- | --- |
| App background | #F4F1ED | #1A1714 | BrandColors.backgroundPrimary |
| Card / surface | #FFFFFF | #2A2520 | BrandColors.backgroundSurface |
| Brand / CTA | #EF9408 | #EF9408 | BrandColors.brand |
| Primary text | #2D2823 | #F0EDE8 | BrandColors.textPrimary |
| Secondary text | #6B6259 | #A89E95 | BrandColors.textSecondary |
| Stroke / border | #E9E3DB | #3D3630 | BrandColors.stroke |
| Success | #2E7D52 | #4CAF7D | BrandColors.success |
| Error | #C0392B | #E57373 | BrandColors.error |
| Disabled fill | #E9E3DB | #2E2925 | BrandColors.disabledFill |
| Skeleton base | #EAE6E1 | #2A2520 | BrandColors.skeletonBase |
| Add files to Xcode project    GLOBAL | Add files to Xcode project    GLOBAL | Add files to Xcode project    GLOBAL |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Create DesignSystem/Colors/ group in Xcode navigator | APPLY |
| ▢ | Drag BrandColors.swift, SemanticColors.swift, ComponentColors.swift into the group | APPLY |
| ▢ | Delete the old BrandColors.swift from its previous location to avoid duplicate symbols | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Confirm all three files are in the main app target (check Target Membership in File Inspector) | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Build (Cmd+B) — zero errors, zero warnings | BUILD & RUN |
| Verify adaptive colors work    GLOBAL | Verify adaptive colors work    GLOBAL | Verify adaptive colors work    GLOBAL |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Remove the temporary test view before moving to Phase 1 | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | In iOS Simulator, switch to Dark Mode (Settings → Developer → Dark Appearance) | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Add a temporary view with backgroundColor = BrandColors.backgroundPrimary and confirm it changes between Greige and charcoal | BUILD & RUN |
| Root background    GLOBAL | Root background    GLOBAL | Root background    GLOBAL |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Set view.backgroundColor = ComponentColors.App.screenBackground on every existing UIViewController | APPLY |
| ▢ | If using a UINavigationController, set its view background too | APPLY |
| Build & run | Build & run | Build & run |
| ▢ | Build and run — all screens show Greige (#F4F1ED) in Light Mode, charcoal in Dark Mode | BUILD & RUN |
| Navigation Bar    COMPONENT | Navigation Bar    COMPONENT | Navigation Bar    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | In AppDelegate / SceneDelegate, set UINavigationBar.appearance().backgroundColor = ComponentColors.NavBar.background | APPLY |
| ▢ | Set largeTitleTextAttributes and titleTextAttributes to use color: ComponentColors.NavBar.title | APPLY |
| ▢ | Set tintColor = ComponentColors.NavBar.rightButton for back and bar button items | APPLY |
| ▢ | Set the bottom separator: standardAppearance.shadowColor = ComponentColors.NavBar.separator | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Nav bar is white (light) / near-black (dark) with warm-black or off-white title | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Back chevron and right buttons are brand orange in both modes | BUILD & RUN |
| Tab Bar    COMPONENT | Tab Bar    COMPONENT | Tab Bar    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Set UITabBar.appearance().backgroundColor = ComponentColors.TabBar.background | APPLY |
| ▢ | Set unselectedItemTintColor = ComponentColors.TabBar.inactiveIcon | APPLY |
| ▢ | Set tintColor = ComponentColors.TabBar.activeIcon | APPLY |
| ▢ | Add 1px top separator: UITabBarAppearance().shadowColor = ComponentColors.TabBar.separator | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Active tab icon is orange, inactive icons are #9A9188 (light) / #6E665F (dark) | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Tab bar background is white (light) / near-black (dark), not system gray | BUILD & RUN |
| Screen background & section headers    SCREEN | Screen background & section headers    SCREEN | Screen background & section headers    SCREEN |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | view.backgroundColor = ComponentColors.HomeScreen.background | APPLY |
| ▢ | Set all section header labels to textColor = ComponentColors.HomeScreen.sectionHeaderText | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Background is Greige, not white or system gray | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Build and run in both Light and Dark Mode | BUILD & RUN |
| Scan / Upload action buttons    COMPONENT | Scan / Upload action buttons    COMPONENT | Scan / Upload action buttons    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | backgroundColor = ComponentColors.HomeScreen.actionButtonFill (orange) | APPLY |
| ▢ | setTitleColor(ComponentColors.HomeScreen.actionButtonText) — white text | APPLY |
| ▢ | layer.cornerRadius = ComponentColors.HomeScreen.actionButtonCornerRadius (14pt) | APPLY |
| ▢ | Apply shadow: view.applyReHearseShader(level: 1) | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Only ONE element is solid orange at a time — Orange Limit rule | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Button text is white, legible on orange in both modes | BUILD & RUN |
| Recent Uploads file list cards    COMPONENT | Recent Uploads file list cards    COMPONENT | Recent Uploads file list cards    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Each cell's contentView.backgroundColor = ComponentColors.SongCard.background (white) | APPLY |
| ▢ | Add border: layer.borderColor = ComponentColors.SongCard.border.cgColor, borderWidth = 1 | APPLY |
| ▢ | layer.cornerRadius = ComponentColors.SongCard.cornerRadius (12pt) | APPLY |
| ▢ | File name label: textColor = ComponentColors.SongCard.titleText | APPLY |
| ▢ | Date/size label: textColor = ComponentColors.SongCard.metadataText | APPLY |
| ▢ | File icon tint: tintColor = ComponentColors.SongCard.fileIcon | APPLY |
| ▢ | cell.applyReHearseShader(level: 1, cornerRadius: 12) | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | White card visibly lifts off Greige background — the Lifting Rule | CHECK |
| ▢ | No white card placed directly on another white card without a border | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Card border visible in Light Mode, slightly more prominent in Dark Mode | BUILD & RUN |
| Empty state    COMPONENT | Empty state    COMPONENT | Empty state    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Empty state icon tintColor = ComponentColors.HomeScreen.emptyStateIcon | APPLY |
| ▢ | Empty state label textColor = ComponentColors.HomeScreen.emptyStateText | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Empty state reads as secondary — not competing with primary content | CHECK |
| Screen & question card    SCREEN | Screen & question card    SCREEN | Screen & question card    SCREEN |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | view.backgroundColor = ComponentColors.QuizScreen.background | APPLY |
| ▢ | Question card: backgroundColor = ComponentColors.QuizScreen.questionCardFill | APPLY |
| ▢ | Question card: layer.borderColor = ComponentColors.QuizScreen.questionCardBorder.cgColor | APPLY |
| ▢ | Apply shadow level 2 to question card: card.applyReHearseShader(level: 2) | APPLY |
| Sheet music rendering    COMPONENT | Sheet music rendering    COMPONENT | Sheet music rendering    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Staff lines stroke color = ComponentColors.QuizScreen.staffLines | APPLY |
| ▢ | Note heads fill = ComponentColors.QuizScreen.noteHeads | APPLY |
| ▢ | Clef symbol color = ComponentColors.QuizScreen.clefSymbol | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | All notation uses #2D2823 (warm near-black), not pure #000000 | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Notation reads as 'ink on paper' — legible against the white card background | BUILD & RUN |
| Multiple choice bubbles — all 4 states    COMPONENT | Multiple choice bubbles — all 4 states    COMPONENT | Multiple choice bubbles — all 4 states    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Default: backgroundColor = bubbleDefaultFill, border = bubbleDefaultBorder, text = bubbleDefaultText | APPLY |
| ▢ | Selected: backgroundColor = bubbleSelectedFill (orange), text = bubbleSelectedText (white) | APPLY |
| ▢ | Correct feedback: border flashes to bubbleCorrectBorder (green), fill = bubbleCorrectFill | APPLY |
| ▢ | Incorrect feedback: border flashes to bubbleIncorrectBorder (red), fill = bubbleIncorrectFill | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Selected bubble stays orange during feedback — only the border changes for correct/incorrect | CHECK |
| ▢ | Only one bubble can be solid orange at a time | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Test all 4 states: default → selected → correct flash → reset | BUILD & RUN |
| ▢ | Test all 4 states: default → selected → incorrect flash → reset | BUILD & RUN |
| Progress bar & counter    COMPONENT | Progress bar & counter    COMPONENT | Progress bar & counter    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Progress track: backgroundColor = ComponentColors.QuizScreen.progressTrack | APPLY |
| ▢ | Progress fill: backgroundColor = ComponentColors.QuizScreen.progressFill (orange) | APPLY |
| ▢ | Counter label: textColor = ComponentColors.QuizScreen.counterText | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Progress bar is the only orange element at the top of the screen | CHECK |
| Screen background & metadata    SCREEN | Screen background & metadata    SCREEN | Screen background & metadata    SCREEN |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | view.backgroundColor = ComponentColors.SongDetailScreen.background | APPLY |
| ▢ | Song title: textColor = ComponentColors.SongDetailScreen.songTitle | APPLY |
| ▢ | Artist name: textColor = ComponentColors.SongDetailScreen.artistName | APPLY |
| ▢ | Duration label: textColor = ComponentColors.SongDetailScreen.durationLabel | APPLY |
| Album art    COMPONENT | Album art    COMPONENT | Album art    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Album art container: backgroundColor = ComponentColors.SongDetailScreen.albumArtBackground | APPLY |
| ▢ | albumArtView.applyReHearseShader(level: 3, cornerRadius: 16) | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Album art appears to 'float' with a soft warm shadow — not a hard drop shadow | CHECK |
| Primary & secondary action buttons    COMPONENT | Primary & secondary action buttons    COMPONENT | Primary & secondary action buttons    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Primary (Play Along): fill = primaryActionFill, text = primaryActionText, radius = 14 | APPLY |
| ▢ | Secondary (View Animation): fill = secondaryActionFill, border = secondaryActionBorder, text = secondaryActionText, radius = 14 | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Only the primary button is solid orange — Orange Limit rule | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Secondary button reads clearly as secondary — white with subtle border | BUILD & RUN |
| Sheet music viewer card    COMPONENT | Sheet music viewer card    COMPONENT | Sheet music viewer card    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Card: backgroundColor = sheetMusicCardFill, border = sheetMusicCardBorder | APPLY |
| ▢ | All notation rendered in: ComponentColors.SongDetailScreen.sheetMusicNotation | APPLY |
| ▢ | Scrubber track, fill, and thumb wired to scrubberTrack / scrubberFill / scrubberThumb | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Sheet music looks like 'ink on paper' — warm dark notation on a pure white card | CHECK |
| ▢ | Notation color is #2D2823, not pure black | CHECK |
| Tempo / key signature chips    COMPONENT | Tempo / key signature chips    COMPONENT | Tempo / key signature chips    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Chip fill = chipFill (brand tint, 10% orange), text = chipText (orange), border = chipBorder | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Chips read as informational — softly branded, not a primary CTA | CHECK |
| Profile header card    SCREEN | Profile header card    SCREEN | Profile header card    SCREEN |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | view.backgroundColor = ComponentColors.ProfileScreen.background | APPLY |
| ▢ | Header card: backgroundColor = ComponentColors.ProfileScreen.headerCardFill | APPLY |
| ▢ | Avatar ring: layer.borderColor = avatarBorder.cgColor, borderWidth = 3 | APPLY |
| ▢ | User name: textColor = userName; handle: textColor = userHandle | APPLY |
| ▢ | Edit profile link: textColor = editProfileText (orange) | APPLY |
| Stat cards    COMPONENT | Stat cards    COMPONENT | Stat cards    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Card: backgroundColor = statCardFill, border = statCardBorder | APPLY |
| ▢ | Number (e.g. '42.5h'): textColor = statNumber (orange) | APPLY |
| ▢ | Label (e.g. 'PRACTICE'): textColor = statLabel | APPLY |
| ▢ | Apply shadow level 1 to each stat card | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | The large orange stat number is the clear visual anchor of each card | CHECK |
| ▢ | Only stat numbers are orange — labels are secondary gray | CHECK |
| Progress / activity graph    COMPONENT | Progress / activity graph    COMPONENT | Progress / activity graph    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Graph line: stroke = graphLine (orange) | APPLY |
| ▢ | Area fill: graphAreaFill (10% orange tint) | APPLY |
| ▢ | Axis labels: textColor = axisLabel; grid lines: stroke = graphGridLine | APPLY |
| Design checks | Design checks | Design checks |
| ▢ | Area fill is a very soft orange tint — not distractingly saturated | CHECK |
| Build & run | Build & run | Build & run |
| ▢ | Graph reads clearly in Dark Mode — axis labels visible against dark background | BUILD & RUN |
| Settings list & destructive action    COMPONENT | Settings list & destructive action    COMPONENT | Settings list & destructive action    COMPONENT |
| --- | --- | --- |
| Apply | Apply | Apply |
| ▢ | Settings cells: backgroundColor = settingsCellFill | APPLY |
| ▢ | Cell title: textColor = settingsCellText; detail: textColor = settingsCellDetail | APPLY |
| ▢ | Separator, chevron icon wired to settingsSeparator and settingsChevron | APPLY |
| ▢ | Log Out / destructive action: textColor = destructiveText (red) | APPLY |
| Build & run | Build & run | Build & run |
| ▢ | Settings list looks like a lifted white card on Greige background | BUILD & RUN |
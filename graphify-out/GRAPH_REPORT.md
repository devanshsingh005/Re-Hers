# Graph Report - .  (2026-04-24)

## Corpus Check
- Large corpus: 268 files · ~2,614,375 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 2636 nodes · 4537 edges · 75 communities detected
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 116 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)
1. `UploadScreen` - 102 edges
2. `UserProfileViewController` - 67 edges
3. `DatabaseClient` - 59 edges
4. `AuthViewController` - 53 edges
5. `LessonDetailViewController` - 49 edges
6. `DiscoverSongDetailViewController` - 43 edges
7. `DiscoverViewController` - 41 edges
8. `StorageManager` - 40 edges
9. `PlayAlongViewController` - 36 edges
10. `OrphanDetector` - 35 edges

## Surprising Connections (you probably didn't know these)
- `Security-focused backend tests.` --uses--> `OrphanDetector`  [INFERRED]
  backend/tests/test_security.py → backend/app/orphan_detector.py
- `Pytest configuration and shared fixtures for backend security tests.` --uses--> `OrphanDetector`  [INFERRED]
  backend/tests/conftest.py → backend/app/orphan_detector.py
- `Create an instance of the default event loop for the test session.` --uses--> `OrphanDetector`  [INFERRED]
  backend/tests/conftest.py → backend/app/orphan_detector.py
- `Supabase storage integration for storing job outputs with user isolation.` --uses--> `DatabaseClient`  [INFERRED]
  backend/app/storage.py → backend/app/database.py
- `Manages file uploads/downloads with user isolation and DB linkage.` --uses--> `DatabaseClient`  [INFERRED]
  backend/app/storage.py → backend/app/database.py

## Communities

### Community 0 - "Init Uploadquizpopupdelegate"
Cohesion: 0.03
Nodes (36): AnyObject, AVCapturePhotoCaptureDelegate, Encodable, PHPickerViewControllerDelegate, String, UIDocumentPickerDelegate, UploadQuizPopupDelegate, UploadQuizPopupDelegate (+28 more)

### Community 1 - "Init Layoutsubviews"
Cohesion: 0.03
Nodes (21): AnimatedKeyboardView, AnimationOverlayView, HomeViewController, PillButton, HomeViewController, PracticeCardBackgroundView, PracticeCardTheme, EarTrainingOptionState (+13 more)

### Community 2 - "User Args"
Cohesion: 0.03
Nodes (93): DatabaseClient, Database operations for sheet_files and jobs tables., Handles all database operations with user isolation., Create or update sheet_file record linking file to user.                  Uses u, Initialize Supabase client., Get sheet_file only if owned by user., Get sheet_file by job_id (with user validation)., Get all sheet_files for a user. (+85 more)

### Community 3 - "Init Codingkeys"
Cohesion: 0.04
Nodes (54): applyProgress(), ChapterStatus, completed, current, locked, ChordDetail, MusicChapter, MusicLesson (+46 more)

### Community 4 - "Init__ Table"
Cohesion: 0.03
Nodes (22): app_client(), ASGITestClient, backend_state(), BackendState, event_loop(), expired_jwt(), FakeQuery, FakeStorageAPI (+14 more)

### Community 5 - "Init Discoverviewcontroller"
Cohesion: 0.04
Nodes (14): BlockedUserKeyValueStore, BlockedUserStore, DiscoverLayoutMetrics, DiscoverSongFilter, DiscoverViewController, SongCell, UserDefaults, PlaylistDetailViewController (+6 more)

### Community 6 - "Codingkeys Init"
Cohesion: 0.03
Nodes (65): CodingKey, CodingKeys, contentID, contentType, reason, reporterID, Equatable, NSObject (+57 more)

### Community 7 - "Viewdidload Allrecentsviewcontroller"
Cohesion: 0.04
Nodes (12): AllRecentsViewController, ChordRecognition, GuestFeatureGateModal, MaximizeUploadPageViewController, PianoAnimationkeyboardViewController, Particle, ParticleView, SplashScreenView (+4 more)

### Community 8 - "Init Userprofileviewcontroller"
Cohesion: 0.06
Nodes (6): GradientHeaderView, OnboardingData, PracticeChartView, ProfileStats, UIView, UserProfileViewController

### Community 9 - "Filevalidator Filetoolarge"
Cohesion: 0.04
Nodes (29): Error, FileValidationError, fileTooLarge, unreadable, unsupportedType, FileValidator, ValidatedFile, ImageValidationError (+21 more)

### Community 10 - "Setupui Viewdidload"
Cohesion: 0.05
Nodes (16): AddPlaylistViewController, albumPlaceholder(), CreatePlaylistFooterView, loadPlaylistCoverImage(), PlaylistCollectionViewCell, PlaylistViewController, resolvePlaylistCoverImage(), UIImageView (+8 more)

### Community 11 - "Auth Authentication"
Cohesion: 0.04
Nodes (24): AuthManager, get_auth_manager(), get_current_user(), Authentication helpers for Supabase Auth., Initialize auth manager., Verify JWT token and return user data.                  Args:             token:, Extract and verify current user from Authorization header.                  Args, Get or create auth manager. (+16 more)

### Community 12 - "Init Createsignedurl"
Cohesion: 0.04
Nodes (18): AuthLocalStorage, DiscoverJSONSourceSelectionTests, DiscoverLayoutMetricsTests, DiscoverModerationPayloadTests, DiscoverSongDetailAccessPolicyTests, GuestFeatureAccessPolicyTests, ReviewAccessConfigurationTests, SheetMusicViewRenderTests (+10 more)

### Community 13 - "Uploadpagenextviewcontroller Animate"
Cohesion: 0.07
Nodes (60): animateProgress(), applyConstraints(), authToken(), buildHierarchy(), canPresentAnimation(), deinit(), deriveChordsFallback(), deriveLabeledPDFURL() (+52 more)

### Community 14 - "Init Setupui"
Cohesion: 0.06
Nodes (6): PlayAlongEngineDelegate, PlayAlongEngine, PlayAlongEngineDelegate, PlayAlongNavBar, PlayAlongReportView, PlayAlongViewController

### Community 15 - "Appdelegate Legalscreenview"
Cohesion: 0.04
Nodes (32): AppDelegate, LegalAgreementView, LegalContent, bullets, callout, paragraph, LegalData, LegalScreenView (+24 more)

### Community 16 - "Memory Store"
Cohesion: 0.03
Nodes (12): Enum, Job, JobStatus, JobStore, In-memory job store for tracking job status., Job model for tracking conversion tasks., Thread-safe in-memory job store., Create a new job record. (+4 more)

### Community 17 - "Discoversongdetailviewcontroller Ini"
Cohesion: 0.06
Nodes (15): AuthError, emailAlreadyRegistered, networkUnavailable, signUpRateLimited, signUpUnavailable, usernameAlreadyTaken, AssetError, invalidURL (+7 more)

### Community 18 - "Authviewcontroller Login"
Cohesion: 0.07
Nodes (7): AuthMode, logIn, signUp, AuthPayload, AuthViewController, ReviewAccessConfiguration, UITextViewDelegate

### Community 19 - "Init Animationviewcontroller"
Cohesion: 0.07
Nodes (8): AnimationViewController, MenuState, main, sound, tempo, PlaybackOverlay, SeekRipple, SettingsMenuView

### Community 20 - "Init Guestsessionmanager"
Cohesion: 0.06
Nodes (10): Decodable, ExistingOnboardingRow, GuestOnboardingPayload, GuestSessionManager, PartCompletedEvent, NavbarProfile, NavigationBarHelper, PremiumBackButton (+2 more)

### Community 21 - "Presentationcontrollerdiddismiss Vie"
Cohesion: 0.07
Nodes (9): AppNavigationController, MainTabBarController, UINavigationController, LandscapeNavigationController, ChordRecognitionViewController, UIAdaptivePresentationControllerDelegate, UINavigationController, UITabBarController (+1 more)

### Community 22 - "Uploadquizpopup Cleftype"
Cohesion: 0.06
Nodes (19): ClefType, bass, treble, MusicQuizQuestion, NoteDuration, eighth, half, quarter (+11 more)

### Community 23 - "Alluploadsviewcontroller Init"
Cohesion: 0.07
Nodes (16): AllUploadsViewController, AnyCodable, CodingKeys, errorMessage, fileType, id, jsonData, originalFilename (+8 more)

### Community 24 - "Alluploadsviewcontroller Init"
Cohesion: 0.07
Nodes (16): AllUploadsViewController, AnyCodable, CodingKeys, errorMessage, fileType, id, jsonData, originalFilename (+8 more)

### Community 25 - "Init Pianoview"
Cohesion: 0.08
Nodes (13): AnimatedPianoKeyboardView, AnimatedPianoKeyView, HandType, left, right, KeyboardMode, animation, playAlong (+5 more)

### Community 26 - "Songdetailspage Alert"
Cohesion: 0.1
Nodes (35): alert(), buildUI(), canPresentAnimation(), configure(), fetchAndCache(), fetchDiscoverSong(), fetchDiscoverSongFromMetadata(), fetchLabeledPDFFromSong() (+27 more)

### Community 27 - "Init L1viewcontroller"
Cohesion: 0.1
Nodes (4): ChapterNodeView, ChapterPopupCard, LessonMapViewController, PathCanvasView

### Community 28 - "Audiveris Port"
Cohesion: 0.12
Nodes (35): Worker, acquire_vm_lock(), claim_audiveris_port(), decrement_active_jobs(), ensure_audiveris_ready(), get_active_jobs(), _get_compute_client(), _get_credential() (+27 more)

### Community 29 - "Sheetmusicview Addwrongnotemarker"
Cohesion: 0.11
Nodes (31): applyCurrentTransform(), applyParsedSheetState(), box(), deepFind(), doRender(), drawBarlines(), drawBraceAndBarline(), drawClefs() (+23 more)

### Community 30 - "Test_security Build_rate_limited_app"
Cohesion: 0.09
Nodes (20): _build_rate_limited_app(), _grep(), Security-focused backend tests., _seed_worker_env(), _subprocess_import(), _subprocess_worker(), test_a07_verify_signature_never_false(), test_a08_rate_limiter_uses_ip_for_invalid_tokens() (+12 more)

### Community 31 - "Audiveris Local"
Cohesion: 0.08
Nodes (30): acquire_vm_lock(), claim_audiveris_port(), decrement_active_jobs(), ensure_audiveris_ready(), get_active_jobs(), get_queue_length(), _get_vm_power_state(), increment_active_jobs() (+22 more)

### Community 32 - "Staff Note"
Cohesion: 0.1
Nodes (30): compute_tenths_to_pt(), debug_measure_rect(), debug_note_anchor(), debug_staff_top_line(), extract_system_layout(), get_note_staff_number(), note_head_y_for_clef(), parse_clefs() (+22 more)

### Community 33 - "Test_endpoints Flatten_strings"
Cohesion: 0.09
Nodes (13): _flatten_strings(), _post_file(), Endpoint and API-behavior tests., test_b01_valid_pdf_upload_accepted(), test_b02_valid_jpeg_upload_accepted(), test_b03_html_with_pdf_content_type_rejected(), test_b04_random_bytes_with_pdf_content_type_rejected(), test_b05_pdf_magic_bytes_with_jpeg_content_type_rejected() (+5 more)

### Community 34 - "Navigationbarhelper Init"
Cohesion: 0.1
Nodes (5): AppConnectivityMonitor, AppUserFacingError, NavbarProfile, NavigationBarHelper, PremiumBackButton

### Community 35 - "Audioenginemanager Acquireplaybackse"
Cohesion: 0.11
Nodes (8): AudioEngineManager, InstrumentType, electricPiano, grandPiano, CaseIterable, LegalTab, privacy, terms

### Community 36 - "Pitchdetector Configureaudiosession"
Cohesion: 0.12
Nodes (8): PitchDetector, PitchDetectorDelegate, StartFailure, audioSessionConfigurationFailed, engineStartFailed, fftInitializationFailed, microphonePermissionMissing, noInputRouteAvailable

### Community 37 - "Discoversongpreviewviewcontroller As"
Cohesion: 0.13
Nodes (4): AssetError, missingPDF, remoteFetchFailed, DiscoverSongPreviewViewController

### Community 38 - "Componentcolors Authscreen"
Cohesion: 0.09
Nodes (22): App, AuthScreen, Chip, ComponentColors, DestructiveButton, DiscoverScreen, DiscoverySongCard, Divider (+14 more)

### Community 39 - "Homeviewcontroller Deinit"
Cohesion: 0.19
Nodes (1): HomeViewController

### Community 40 - "Playalongsongdetailviewcontroller Ap"
Cohesion: 0.15
Nodes (1): PlayAlongSongDetailViewController

### Community 41 - "Test_recovery_simple Recovery"
Cohesion: 0.11
Nodes (7): Recovery and queue tests using the in-memory harness., Verify supervisor.conf exists and is readable., TestAPIHealth, TestQueueStatusIntegration, TestRecoveryLoopConfiguration, TestRecoveryLoopWillStart, TestRedisQueue

### Community 42 - "Pianologic Chorddetector"
Cohesion: 0.26
Nodes (2): ChordDetector, String

### Community 43 - "Analyticsmanager Logauthfailed"
Cohesion: 0.23
Nodes (1): AnalyticsManager

### Community 44 - "Topview Lessonnavbarview"
Cohesion: 0.18
Nodes (1): LessonNavBarView

### Community 45 - "Dailygoalmanager Addpracticeduration"
Cohesion: 0.26
Nodes (3): DailyGoalManager, DateFormatter, HomeViewController

### Community 46 - "Appthememanager Apptheme"
Cohesion: 0.22
Nodes (6): AppTheme, dark, light, system, AppThemeManager, Int

### Community 47 - "Imageloader Cacheddiskimage"
Cohesion: 0.3
Nodes (2): ImageLoader, UIImage

### Community 48 - "Semanticcolors Background"
Cohesion: 0.18
Nodes (9): Background, Border, DataViz, Icon, SemanticColors, Shadow, State, Text (+1 more)

### Community 49 - "Onboardingviewmodel Observableobject"
Cohesion: 0.36
Nodes (3): ObservableObject, OnboardingPayload, OnboardingViewModel

### Community 50 - "Generate_rehearse_excel_files Border"
Cohesion: 0.36
Nodes (10): bordered(), create_functional_tests(), create_sprint_retro(), main(), set_widths(), sprint_1_rows(), sprint_2_rows(), style_header_row() (+2 more)

### Community 51 - "Mock That"
Cohesion: 0.2
Nodes (9): failing_job(), infinite_loop_job(), long_running_job(), quick_job(), Helper functions and mock jobs for tests., Mock job that completes quickly., Mock job that always fails., Mock job that loops infinitely (for timeout testing). (+1 more)

### Community 52 - "Inputvalidator Digitsonly"
Cohesion: 0.29
Nodes (1): InputValidator

### Community 53 - "Waveview Commoninit"
Cohesion: 0.25
Nodes (1): WaveView

### Community 54 - "Homeviewcontrollercontinuelearning H"
Cohesion: 0.29
Nodes (1): HomeViewController

### Community 55 - "Chordaudiomanager Start"
Cohesion: 0.43
Nodes (2): ChordAudioManager, ChordAudioManagerDelegate

### Community 56 - "Environment Variables"
Cohesion: 0.33
Nodes (5): Configuration module for loading environment variables., Application settings loaded from environment variables., Validate the Audiveris backend URL., Settings, validate_audiveris_api_url()

### Community 57 - "Pianodemomanager Init"
Cohesion: 0.33
Nodes (0): 

### Community 58 - "Brandcolors Uicolor"
Cohesion: 0.4
Nodes (2): BrandColors, UIColor

### Community 59 - "Pianodatamanager Notegroup"
Cohesion: 0.5
Nodes (2): NoteGroup, PianoDataManager

### Community 60 - "Homeviewcontrolleruploadsection Home"
Cohesion: 0.5
Nodes (1): HomeViewController

### Community 61 - "Audiveris Audiveris_client"
Cohesion: 0.5
Nodes (3): Call Audiveris API with PDF file and return JSON output.          Args:, Client for calling Audiveris HTTP API., run_audiveris()

### Community 62 - "Index Addpath"
Cohesion: 0.5
Nodes (0): 

### Community 63 - "Organize_red_folders_fixed Find_grou"
Cohesion: 1.0
Nodes (2): find_group(), main()

### Community 64 - "Limiter Rate_limit_key"
Cohesion: 0.67
Nodes (2): _rate_limit_key(), Return the rate-limit bucket key for this request.      Authenticated (valid Bea

### Community 65 - "Uiimage Normalization"
Cohesion: 0.67
Nodes (1): UIImage

### Community 66 - "Generate_rehearse_test_cases Autofit"
Cohesion: 1.0
Nodes (2): autofit_columns(), main()

### Community 67 - "Guestfeatureaccesspolicy Shouldgates"
Cohesion: 0.67
Nodes (1): GuestFeatureAccessPolicy

### Community 68 - "Inspect_pbxproj Print_group"
Cohesion: 1.0
Nodes (0): 

### Community 69 - "Organize_fix Main"
Cohesion: 1.0
Nodes (0): 

### Community 70 - "Organize Main"
Cohesion: 1.0
Nodes (0): 

### Community 71 - "Organize_red_folders Main"
Cohesion: 1.0
Nodes (0): 

### Community 72 - "Uicolorlegacybridge Uicolor"
Cohesion: 1.0
Nodes (1): UIColor

### Community 73 - "Init__ Package"
Cohesion: 1.0
Nodes (1): Test package initialization.

### Community 74 - "Songchord"
Cohesion: 1.0
Nodes (1): SongChord

## Knowledge Gaps
- **296 isolated node(s):** `UIColor`, `BrandColors`, `SemanticColors`, `Background`, `Text` (+291 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Inspect_pbxproj Print_group`** (2 nodes): `inspect_pbxproj.rb`, `print_group()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Organize_fix Main`** (2 nodes): `organize_fix.rb`, `main()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Organize Main`** (2 nodes): `organize.rb`, `main()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Organize_red_folders Main`** (2 nodes): `organize_red_folders.rb`, `main()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Uicolorlegacybridge Uicolor`** (2 nodes): `UIColorLegacyBridge.swift`, `UIColor`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Init__ Package`** (2 nodes): `__init__.py`, `Test package initialization.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Songchord`** (2 nodes): `SongChord.swift`, `SongChord`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UploadScreen` connect `Init Uploadquizpopupdelegate` to `Init Pianoview`, `Presentationcontrollerdiddismiss Vie`, `Viewdidload Allrecentsviewcontroller`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Why does `UserProfileViewController` connect `Init Userprofileviewcontroller` to `Setupui Viewdidload`, `Viewdidload Allrecentsviewcontroller`?**
  _High betweenness centrality (0.040) - this node is a cross-community bridge._
- **Why does `LessonDetailViewController` connect `Init Layoutsubviews` to `Init Pianoview`, `Viewdidload Allrecentsviewcontroller`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Are the 42 inferred relationships involving `DatabaseClient` (e.g. with `Worker function for processing jobs from the Redis queue.` and `Wrap each page's existing content stream in a q/Q graphics-state save/restore`) actually correct?**
  _`DatabaseClient` has 42 INFERRED edges - model-reasoned connections that need verification._
- **What connects `UIColor`, `BrandColors`, `SemanticColors` to the rest of the system?**
  _296 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Init Uploadquizpopupdelegate` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Init Layoutsubviews` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
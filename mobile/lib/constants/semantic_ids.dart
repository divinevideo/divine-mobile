// ABOUTME: Central constants for Semantics identifiers used as UI-test
// ABOUTME: anchors (XCUITest screenshot pipeline, integration tests).

/// Stable `Semantics(identifier: ...)` values.
///
/// These surface as iOS `accessibilityIdentifier`s / Android resource ids,
/// so UI tests (including the fastlane screenshot suite under
/// `ios/DivineUITests`) can wait on them instead of brittle label text.
/// Keep values snake_case and never reuse one for a different widget.
abstract class SemanticIds {
  static const String exploreTab = 'explore_tab';

  static const String classicVinersRow = 'classic_viners_row';

  static String classicVideoTile(int index) => 'classic_video_tile_$index';

  static const String videoTitle = 'video_title';

  static const String humanMadeBadge = 'human_made_badge';
  static const String verificationSection = 'verification_section';

  static String cameraMode(String mode) => 'camera_mode_$mode';
  static const String cameraRecordButton = 'camera_record_button';

  /// Classic mode's shutter. It has no record button — the square preview
  /// itself is the tap target — so it gets its own id rather than reusing
  /// [cameraRecordButton] for a different widget. The E2E asserts pin the
  /// record button *absent* in classic and this one absent in every
  /// capture-stack mode, which is what proves the right stack is up.
  static const String cameraClassicShutter = 'camera_classic_shutter';

  /// Recorder chrome. Close, next and delete-clip come from the capture
  /// stack, which capture, stop-motion and lip-sync all render, and from
  /// classic mode's own top bar and action row; the library button lives in
  /// the bottom bar, which every mode renders. Every label behind these is
  /// localized, so the E2E recorder flows drive them by id.
  ///
  /// The two stacks reveal next and delete differently, and the E2E asserts
  /// have to match: capture fades them out of the semantics tree entirely
  /// when the session is empty, while classic keeps next mounted and
  /// disables it — so an empty classic session reads `enabled: false` there,
  /// not `notVisible`.
  static const String cameraCloseButton = 'camera_close_button';
  static const String cameraNextButton = 'camera_next_button';
  static const String cameraDeleteClipButton = 'camera_delete_clip_button';
  static const String cameraLibraryButton = 'camera_library_button';

  /// Capture-mode control rail, top to bottom. Flash, aspect ratio and the
  /// lens switch are unconditional, so every mode that renders the rail drives
  /// them with the same three E2E utils. Timer and stabilization are rendered
  /// only by the modes that declare them — capture and lip-sync, which share
  /// the rail unchanged and drive all five with `driveCaptureRail`.
  static const String cameraFlashButton = 'camera_flash_button';
  static const String cameraTimerButton = 'camera_timer_button';
  static const String cameraAspectRatioButton = 'camera_aspect_ratio_button';
  static const String cameraSwitchCameraButton = 'camera_switch_camera_button';
  static const String cameraStabilizationButton = 'camera_stabilization_button';

  /// Sound picker on [VideoEditorAudioChip]. Lip-sync puts it in the top-bar
  /// slot capture mode leaves empty, and because the two render an identical
  /// control rail it is the *only* thing separating those viewfinders — so
  /// `assertCaptureMode` asserts its absence.
  ///
  /// The chip is shared with the editor's audio-timing screen, which is a
  /// different route, so the id stays unambiguous on any one screen.
  static const String audioChip = 'audio_chip';

  /// Search field in the sound picker the chip opens.
  static const String audioSearchField = 'audio_search_field';

  /// Sound picker result tile. Tiles are indexed because the list is a search
  /// result: the E2E narrows it to one entry and takes index 0, rather than
  /// depending on the manifest's order.
  static String audioSoundTile(int index) => 'audio_sound_tile_$index';

  /// Confirms the currently selected sound in the sound picker.
  static const String audioSelectionDoneButton = 'audio_selection_done_button';

  /// What stop-motion adds to that rail (both gated on `capturesStills`), plus
  /// the shot budget it puts in the top bar's center slot. Which viewfinder is
  /// up is settled by the mode wheel's `selected` state, not by these — the
  /// rest of the chrome is shared, since stop-motion is the capture stack. The
  /// E2E asserts pin their absence in the modes that do not declare them, so a
  /// control leaking across modes fails a run rather than passing quietly.
  ///
  /// Classic mode renders its own grid and ghost toggles in
  /// `video_recorder_classic_actions_bottom.dart`, and its own lens switch
  /// next to them. They drive the same bloc state and announce the same
  /// `toggled` / `value`, so they carry the same ids and the E2E flow drives
  /// them with the same per-control utils.
  static const String cameraGhostFrameButton = 'camera_ghost_frame_button';
  static const String cameraGridButton = 'camera_grid_button';
  static const String cameraStopMotionBudget = 'camera_stop_motion_budget';

  /// Welcome screen. The fresh-install and returning-user branches show
  /// different buttons, so each action gets its own id rather than being
  /// disambiguated by position.
  static const String authCreateAccountButton = 'create_account_button';
  static const String authSignInButton = 'sign_in_button';
  static const String authContinueAsButton = 'continue_as_button';
  static const String authUseAnotherAccountButton =
      'use_another_account_button';

  /// Sign-in options screen. The info button opens the sheet explaining each
  /// sign-in method; the back control there reuses
  /// `DiVineAppBarLeading.backButtonSemanticId`.
  static const String authSignInOptionsInfoButton =
      'sign_in_options_info_button';

  /// Invite gate. Account creation is gated on a code here, so these two sit
  /// on the critical path of every flow that signs up.
  static const String authInviteCodeField = 'invite_code_field';
  static const String authInviteSubmitButton = 'invite_submit_button';

  /// Settings rows on the path to signing the device out. removeKeys is the
  /// teardown of every E2E flow, so this route has to stay addressable.
  static const String settingsNostrRow = 'nostr_settings_tile';
  static const String settingsRemoveKeysRow = 'remove_keys_tile';

  /// Account portability. The row leaves the app for the hosted Divine Exit
  /// flow, so an E2E flow can only assert the handoff by addressing the row.
  static const String settingsMoveAccountRow = 'move_account_tile';

  /// Search. The results screen has no tabs and its rows are keyed by
  /// pubkey, so E2E flows need an ordinal handle plus anchors for the
  /// chrome — otherwise they fall back to matching translated copy or
  /// tapping fixed screen coordinates.
  static const String exploreSearchBar = 'explore_search_bar';
  static const String searchField = 'search_field';
  static const String searchBackButton = 'search_back_button';
  static const String searchFilterPill = 'search_filter_pill';

  static String searchSectionHeader(String section) =>
      'search_section_header_$section';

  /// Ordinal handle for a People result row, alongside the pubkey-keyed
  /// `search_user_tile_<pubkey>` that the row itself carries.
  static String searchUserTileAt(int index) => 'search_user_tile_$index';

  /// Comments sheet title. Doubles as the drag anchor: the sheet has no
  /// close button, so dismissing it means dragging the header down.
  static const String commentsSheetTitle = 'comments_sheet_title';

  static const String profileStatsRow = 'profile_stats_row';

  /// Opens Settings from the own-profile header. This is the only entry
  /// point to Settings in the app, so it gates every E2E flow that ends in
  /// key removal.
  static const String profileSettingsButton = 'settings_button';

  /// Opens the profile editor from the own-profile action row. The pencil is
  /// the only entry point to Edit Profile in the app, so it anchors the
  /// edit-profile E2E journey (#6950).
  static const String profileEditButton = 'edit_profile_button';
  static const String profileBackButton = 'profile_back_button';
  static const String profileMoreButton = 'profile_more_button';
  static const String profileUnfollowAction = 'profile_unfollow_action';

  static const String settingsExperimentalFeaturesRow =
      'experimental_features_tile';
  static const String settingsAccountSwitchAction = 'account_switch_action';

  static const String featureFlagAccountSwitching =
      'feature_flag_account_switching';

  /// Profile content tabs. The bar is icon-only and its tab count varies by
  /// profile (6 on the own profile, 5 on another user's), so tests address a
  /// tab by identifier rather than by position or by the compound
  /// "Tab N of M" label Material generates.
  static const String profileVideosTab = 'videos_tab';
  static const String profileCollabsTab = 'collabs_tab';
  static const String profileLikedTab = 'liked_tab';
  static const String profileRepostsTab = 'reposted_tab';
  static const String profileListsTab = 'lists_tab';
  static const String profileCommentsTab = 'comments_tab';

  static String likedVideoThumbnail(int index) =>
      'liked_video_thumbnail_$index';
  static String savedVideoThumbnail(int index) =>
      'saved_video_thumbnail_$index';

  static String listCard(int index) => 'list_card_$index';

  static String categoryTile(int index) => 'category_tile_$index';

  static const String shareButton = 'share_button';
  static const String shareWithSection = 'share_with_section';

  static String shareContact(int index) => 'share_contact_$index';

  static const String editorTimeline = 'editor_timeline';

  static const String videoDetailLoading = 'video_detail_loading';

  /// Fullscreen pooled feed placeholders. Both states used to be the same
  /// unlabelled spinner, so an E2E run could not tell "still loading" from
  /// "this feed has nothing left" and simply timed out (#6949).
  static const String fullscreenFeedLoading = 'fullscreen_feed_loading';
  static const String fullscreenFeedEmpty = 'fullscreen_feed_empty';
}

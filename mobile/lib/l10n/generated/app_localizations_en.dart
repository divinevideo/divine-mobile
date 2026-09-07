// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Clip Recovery';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Finds recordings stored under another account and video files no entry references any more.';

  @override
  String get devOptionsClipRecoveryScan => 'Scan';

  @override
  String get devOptionsClipRecoveryFailure => 'Clip recovery failed';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips clips',
      one: '$clips clip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts drafts',
      one: '$drafts draft',
    );
    return 'Visible now: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts =>
      'Hidden under other accounts';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips clips',
      one: '$clips clip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts drafts',
      one: '$drafts draft',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Move to this account';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Unreferenced files: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Rebuild in library';

  @override
  String get devOptionsClipRecoveryEmpty => 'Nothing to recover';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recovered $count clips',
      one: 'Recovered $count clip',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Recovery report copied';

  @override
  String get devOptionsStorageFootprint => 'Storage Footprint';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Every directory the app writes to. Clearing caches only reclaims part of this.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Measure';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Total: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Storage report copied';

  @override
  String get devOptionsStorageFootprintFailure => 'Could not measure storage';

  @override
  String get feedTuningMoreLabel => 'More like this';

  @override
  String get feedTuningLessLabel => 'Less like this';

  @override
  String get feedTuningUndo => 'Undo';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Open the referenced video';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSecureAccount => 'Secure Your Account';

  @override
  String get settingsSessionExpired => 'Session Expired';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Sign in again to restore full access';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Creator Analytics';

  @override
  String get settingsSupportCenter => 'Support Center';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsBlueskyPublishing => 'Bluesky Publishing';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Manage crossposting to Bluesky';

  @override
  String get settingsNostrSettings => 'Nostr Settings';

  @override
  String get settingsIntegratedApps => 'Integrated Apps';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Approved third-party apps that run inside Divine';

  @override
  String get settingsExperimentalFeatures => 'Experimental Features';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Tweaks that may hiccup—try them if you are curious.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Integration Permissions';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Review and revoke remembered integration approvals';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Developer mode is already enabled';

  @override
  String get settingsDeveloperModeEnabled => 'Developer mode enabled!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more taps to enable developer mode',
      one: '$count more tap to enable developer mode',
    );
    return '$_temp0';
  }

  @override
  String get settingsShareDivine => 'Share Divine with your friends';

  @override
  String get settingsSwitchAccount => 'Switch account';

  @override
  String get settingsAddAnotherAccount => 'Add another account';

  @override
  String get settingsAccountSwitchFailed =>
      'Couldn\'t switch accounts. Please try again.';

  @override
  String get settingsUnsavedDraftsTitle => 'Unsaved Drafts';

  @override
  String get settingsUploadInProgressTitle => 'Upload in progress';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos',
      one: 'video',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos stay as drafts',
      one: 'video stays as a draft',
    );
    return 'You still have $count $_temp0 uploading. Switching accounts stops the upload — your $_temp1 in this account.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'drafts',
      one: 'draft',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'drafts',
      one: 'draft',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them',
      one: 'it',
    );
    return 'You have $count unsaved $_temp0. Switching accounts will keep your $_temp1, but you may want to publish or review $_temp2 first.';
  }

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsSwitchAnyway => 'Switch Anyway';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'That account\'s session ran out. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsAppVersionLabel => 'App version';

  @override
  String get settingsAppLanguage => 'App Language';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (device default)';
  }

  @override
  String get settingsAppLanguageTitle => 'App Language';

  @override
  String get settingsAppLanguageDescription =>
      'Choose the language for the app interface';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Use device language';

  @override
  String get settingsGeneralTitle => 'General Settings';

  @override
  String get settingsContentSafetyTitle => 'Content & Safety';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRATIONS';

  @override
  String get generalSettingsSectionViewing => 'VIEWING';

  @override
  String get generalSettingsSectionCreating => 'CREATING';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get appearanceSettingsTitle => 'Appearance';

  @override
  String get appearanceSettingsSubtitle =>
      'Choose how Divine looks on this device';

  @override
  String get appearanceSettingsSystem => 'System default';

  @override
  String get appearanceSettingsLight => 'Light';

  @override
  String get appearanceSettingsDark => 'Dark';

  @override
  String get generalSettingsClosedCaptions => 'Closed Captions';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Show captions when videos include them';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Square videos only';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Keep feeds in the classic square format';

  @override
  String get contentPreferencesTitle => 'Content Preferences';

  @override
  String get contentPreferencesContentFilters => 'Content Filters';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Manage content warning filters';

  @override
  String get contentPreferencesContentLanguage => 'Content Language';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (device default)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tag your videos with a language so viewers can filter content.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Use device language (default)';

  @override
  String get contentPreferencesAudioSharing =>
      'Make my audio available for reuse';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'When enabled, others can use audio from your videos';

  @override
  String get contentPreferencesMusicMode => 'Music mode';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Skips the noise cleanup that flattens instruments. Better for music, rougher on voices.';

  @override
  String get contentPreferencesAccountLabels => 'Account Labels';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'Self-label your content';

  @override
  String get contentPreferencesAccountContentLabels => 'Account Content Labels';

  @override
  String get contentPreferencesClearAll => 'Clear All';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Select all that apply to your account';

  @override
  String get contentPreferencesDoneNoLabels => 'Done (No Labels)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Done ($count selected)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Audio Input Device';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (recommended)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Automatically selects the best microphone';

  @override
  String get contentPreferencesSelectAudioInput => 'Select Audio Input';

  @override
  String get contentPreferencesUnknownMicrophone => 'Unknown Microphone';

  @override
  String get contentFiltersAdultContent => 'ADULT CONTENT';

  @override
  String get contentFiltersViolenceGore => 'VIOLENCE & GORE';

  @override
  String get contentFiltersSubstances => 'SUBSTANCES';

  @override
  String get contentFiltersOther => 'OTHER';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verify your age in Safety & Privacy settings to unlock adult content filters';

  @override
  String get contentFiltersShow => 'Show';

  @override
  String get contentFiltersWarn => 'Warn';

  @override
  String get contentFiltersFilterOut => 'Filter Out';

  @override
  String get profileBlockedAccountNotAvailable =>
      'This account is not available';

  @override
  String get profileInvalidId => 'Invalid profile ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Check out $displayName on Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName on Divine';
  }

  @override
  String get profileShareFailed => 'Failed to share profile. Please try again.';

  @override
  String get profileCopyPublicKey => 'Copy public key (npub)';

  @override
  String get profileGetEmbedCode => 'Get embed code';

  @override
  String get profilePublicKeyCopied => 'Public key copied to clipboard';

  @override
  String get profileEmbedCodeCopied => 'Embed code copied to clipboard';

  @override
  String get profileMoreTooltip => 'More';

  @override
  String get profileMoreSemanticLabel => 'More options';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Close avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => 'Close avatar preview';

  @override
  String get profileFollowingLabel => 'Following';

  @override
  String get profileFollowLabel => 'Follow';

  @override
  String get profileBlockedLabel => 'Blocked';

  @override
  String get profileFollowersLabel => 'Followers';

  @override
  String get profileFollowingStatLabel => 'Following';

  @override
  String get profileVideosLabel => 'Videos';

  @override
  String get profileCollabsLabel => 'Collabs';

  @override
  String get profileLikedLabel => 'Liked';

  @override
  String get profileRepostsLabel => 'Reposts';

  @override
  String get profileListsLabel => 'Lists';

  @override
  String get profileCommentsLabel => 'Comments';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites still need to send',
      one: '1 collaborator invite still needs to send',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'We kept the invite queued. Retry it here.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'For \"$title\". Retry it here.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Retry';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Retrying';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Collaborator invite retry is unavailable right now.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites still need to send.',
      one: '1 collaborator invite still needs to send.',
      zero: 'Collaborator invites sent.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborators can\'t receive invites.',
      one: '1 collaborator can\'t receive invites.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users',
      one: '$count user',
    );
    return '$_temp0';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Block $displayName?';
  }

  @override
  String get profileBlockExplanation => 'When you block a user:';

  @override
  String get profileBlockBulletHidePosts =>
      'Their posts will not appear in your feeds.';

  @override
  String get profileBlockBulletCantView =>
      'They will be unable to view your profile, follow you, or view your posts.';

  @override
  String get profileBlockBulletNoNotify =>
      'They will not be notified of this change.';

  @override
  String get profileBlockBulletYouCanView =>
      'You will still be able to view their profile.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Block $displayName';
  }

  @override
  String get profileCancelButton => 'Cancel';

  @override
  String get profileLearnMore => 'Learn More';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Unblock $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'When you unblock this user:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Their posts will appear in your feeds.';

  @override
  String get profileUnblockBulletCanView =>
      'They will be able to view your profile, follow you, and view your posts.';

  @override
  String get profileUnblockBulletNoNotify =>
      'They will not be notified of this change.';

  @override
  String get profileLearnMoreAt => 'Learn more at ';

  @override
  String get profileUnblockButton => 'Unblock';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Unfollow $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Block $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Unblock $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Report $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Add $displayName to a list';
  }

  @override
  String get profileNoCollabsTitle => 'No collabs yet';

  @override
  String get profileCollabsOwnEmpty =>
      'Videos you collaborate on will appear here.';

  @override
  String get profileCollabsOtherEmpty =>
      'Videos they collaborate on will appear here.';

  @override
  String get profileErrorLoadingCollabs => 'Error loading collab videos';

  @override
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

  @override
  String get profileNoCommentsOwnTitle => 'No comments yet';

  @override
  String get profileNoCommentsOtherTitle => 'No comments yet';

  @override
  String get profileCommentsOwnEmpty =>
      'Your comments and replies will appear here.';

  @override
  String get profileCommentsOtherEmpty =>
      'Their comments and replies will appear here.';

  @override
  String get profileErrorLoadingComments => 'Error loading comments';

  @override
  String get profileVideoRepliesSection => 'Video Replies';

  @override
  String get profileCommentsSection => 'Comments';

  @override
  String get profileEditLabel => 'Edit';

  @override
  String get profileLibraryLabel => 'Library';

  @override
  String get profileNoLikedVideosTitle => 'No likes yet';

  @override
  String get profileLikedOwnEmpty =>
      'When something catches your eye, tap the heart. Your likes will show up here.';

  @override
  String get profileLikedOtherEmpty =>
      'Nothing caught their eye yet. Give it time.';

  @override
  String get profileErrorLoadingLiked => 'Error loading liked videos';

  @override
  String get profileNoRepostsTitle => 'No reposts yet';

  @override
  String get profileRepostsOwnEmpty =>
      'See something worth sharing? Repost it and it\'ll appear here.';

  @override
  String get profileRepostsOtherEmpty =>
      'They haven\'t passed anything on yet. When they do, it\'ll show up here.';

  @override
  String get profileErrorLoadingReposts => 'Error loading reposted videos';

  @override
  String get profileNoVideosTitle => 'No videos yet';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Your stage is set. Start posting and your videos will live here.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'The world is waiting. Follow them so you don\'t miss it.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Video thumbnail $number';
  }

  @override
  String get profileShowMore => 'Show more';

  @override
  String get profileShowLess => 'Show less';

  @override
  String get dmMessageDisplayLimitReached =>
      'The rest of this message isn\'t displayed.';

  @override
  String get profileCompleteYourProfile => 'Complete Your Profile';

  @override
  String get profileCompleteSubtitle =>
      'Add your name, bio, and picture to get started';

  @override
  String get profilePleaseTryAgain => 'Please try again';

  @override
  String get profileSecureYourAccount => 'Secure Your Account';

  @override
  String get profileSecureSubtitle =>
      'Add email & password to recover your account on any device';

  @override
  String get profileRetryButton => 'Retry';

  @override
  String get profileSessionExpired => 'Session Expired';

  @override
  String get profileSignInToRestore => 'Sign in again to restore full access';

  @override
  String get profileSignInButton => 'Sign in';

  @override
  String get profileMaybeLaterLabel => 'Maybe Later';

  @override
  String get profileSecurePrimaryButton => 'Add Email & Password';

  @override
  String get profileCompletePrimaryButton => 'Update Your Profile';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Likes';

  @override
  String get profileMyLibraryLabel => 'My Library';

  @override
  String get profileMessageLabel => 'Message';

  @override
  String get profileShareLabel => 'Share profile';

  @override
  String get profileDeletedAccountName => 'Deleted account';

  @override
  String get inboxActionReportVanishedAccount => 'Report this account';

  @override
  String get inboxActionBlockVanishedAccount => 'Block this account';

  @override
  String get inboxActionUnblockVanishedAccount => 'Unblock this account';

  @override
  String get inboxReportedVanishedAccount => 'Reported this account';

  @override
  String get inboxBlockedVanishedAccount => 'Blocked this account';

  @override
  String get inboxUnblockedVanishedAccount => 'Unblocked this account';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'This removes the conversation from your inbox. If they message you again, a new conversation starts.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'This account was deleted';

  @override
  String get profileUserFallback => 'user';

  @override
  String get profileLinkCopied => 'Profile link copied';

  @override
  String get profileSetupEditProfileTitle => 'Edit Profile';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Set up your profile before adding a NIP-05 address.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Create profile';

  @override
  String get profileSetupBackLabel => 'Back';

  @override
  String get profileSetupAboutNostr => 'About Nostr';

  @override
  String get profileSetupProfilePublished => 'Profile published successfully!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Save changes?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Save your edits before leaving, or discard them and keep moving.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Save changes';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Discard changes';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Keep editing';

  @override
  String get profileSetupCreateNewProfile => 'Create new profile?';

  @override
  String get profileSetupNoExistingProfile =>
      'We didn\'t find an existing profile on your relays. Publishing will create a new profile. Continue?';

  @override
  String get profileSetupPublishButton => 'Publish';

  @override
  String get profileSetupUsernameTaken =>
      'Username was just taken. Please choose another.';

  @override
  String get profileSetupClaimFailed =>
      'Failed to claim username. Please try again.';

  @override
  String get profileSetupPublishFailed =>
      'Failed to publish profile. Please try again.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Couldn\'t reach the network. Check your connection and try again.';

  @override
  String get profileSetupDisplayNameLabel => 'Display Name';

  @override
  String get profileSetupDisplayNameRequired => 'Please enter a display name';

  @override
  String get profileSetupBioLabel => 'Bio (Optional)';

  @override
  String get profileSetupWebsiteLabel => 'Website (Optional)';

  @override
  String get profileSetupPublicKeyLabel => 'Public key (npub)';

  @override
  String get profileSetupUsernameLabel => 'Username (Optional)';

  @override
  String get profileSetupUsernameHelper =>
      'Use letters, numbers, or hyphens. Your username becomes a divine.video address. Use your display name for spaces or symbols.';

  @override
  String get profileSetupSaveButton => 'Save';

  @override
  String get profileSetupSavingButton => 'Saving...';

  @override
  String get profileSetupImageUrlTitle => 'Add image URL';

  @override
  String get profileSetupImageSelectionFailed =>
      'Image selection failed. Please paste an image URL below instead.';

  @override
  String get profileSetupImagesTypeGroup => 'images';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Camera access is off. Turn it on in Settings to take a photo.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Camera access isn\'t allowed on this device.';

  @override
  String get cameraPickErrorBusy =>
      'The picker is already open. Close it and try again.';

  @override
  String get cameraPickErrorGeneric => 'Couldn\'t open the camera. Try again.';

  @override
  String get profileSetupGotItButton => 'Got it';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Upload failed. Please try again later.';

  @override
  String get profileSetupUploadNetworkError =>
      'Network error: Please check your internet connection and try again.';

  @override
  String get profileSetupUploadAuthError =>
      'Authentication error: Please try logging out and back in.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'File too large: Please choose a smaller image (max 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Upload failed. Our servers are temporarily unavailable. Please try again in a moment.';

  @override
  String get profileSetupBannerClearButton => 'Clear banner';

  @override
  String get profileSetupBannerChangeColor => 'Banner color';

  @override
  String get profileSetupChangeBannerTitle => 'Change banner';

  @override
  String get profileSetupBannerColorPickerTitle => 'Change banner color';

  @override
  String get profileSetupBannerColorCustom => 'Custom';

  @override
  String get profileSetupBannerColorNone => 'No color';

  @override
  String get profileSetupBannerColorLime => 'Lime';

  @override
  String get profileSetupBannerColorYellow => 'Yellow';

  @override
  String get profileSetupBannerColorViolet => 'Violet';

  @override
  String get profileSetupBannerColorPink => 'Pink';

  @override
  String get profileSetupBannerColorOrange => 'Orange';

  @override
  String get profileSetupBannerColorPurple => 'Purple';

  @override
  String get profileSetupAvatarClearButton => 'Remove photo';

  @override
  String get profileSetupImageTakePhoto => 'Take photo';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Upload from camera roll';

  @override
  String get profileSetupImagePasteLink => 'Paste an image link';

  @override
  String get profileSetupEditAvatarLabel => 'Edit profile picture';

  @override
  String get profileSetupEditBannerLabel => 'Edit banner';

  @override
  String get profileSetupUsernameChecking => 'Checking availability...';

  @override
  String get profileSetupUsernameAvailable => 'Username available!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Username already taken';

  @override
  String get profileSetupUsernameReserved => 'Username is reserved';

  @override
  String get profileSetupContactSupport => 'Contact support';

  @override
  String get profileSetupCheckAgain => 'Check again';

  @override
  String get profileSetupUsernameBurned =>
      'This username is no longer available';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Only letters, numbers, and hyphens are allowed';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Username can\'t start or end with a hyphen';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Username must be 3-63 characters';

  @override
  String get profileSetupUsernameNetworkError =>
      'Could not check availability. Please try again.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Invalid username format';

  @override
  String get profileSetupUsernameCheckFailed => 'Failed to check availability';

  @override
  String get profileSetupUsernameReservedTitle => 'Username reserved';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'The name $username is reserved. Tell us why it should be yours.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'e.g. It\'s my brand name, stage name, etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Already contacted support? Tap \"Check again\" to see if it\'s been released to you.';

  @override
  String get profileSetupSupportRequestSent =>
      'Support request sent! We\'ll get back to you soon.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Couldn\'t open email. Send to: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Send request';

  @override
  String get profileSetupUseOwnNip05 => 'Use your own NIP-05 address';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 Address';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Invalid NIP-05 format (e.g., name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Use the username field above for divine.video';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 address';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Use your divine.video username, or point your handle at a NIP-05 address on a domain you control.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Save NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 saved';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Couldn\'t save NIP-05. Please try again.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Use your own NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 maps a name like you@yourdomain.com to your Nostr identity. You need to control the domain and host a verification file at the right path. If it\'s wrong, people can\'t find you and your verified handle disappears. Continue only if you\'ve set this up.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Continue';

  @override
  String get profileSetupNip05ConfirmCancel => 'Cancel';

  @override
  String get profileSetupProfilePicturePreview => 'Profile picture preview';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine is built on Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' a censorship-resistant open protocol that lets people communicate online without relying on a single company or platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'When you sign up for Divine, you get a new Nostr identity.';

  @override
  String get nostrInfoOwnership =>
      'Nostr lets you own your content, identity and social graph, which you can use across many apps. The result is more choice, less lock-in, and a healthier, more resilient social internet.';

  @override
  String get nostrInfoLingo => 'Nostr lingo:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Your public Nostr address. It\'s safe to share and lets others find, follow, or message you across Nostr apps.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Your private key and proof of ownership. It gives full control of your Nostr identity, so ';

  @override
  String get nostrInfoNsecWarning => 'always keep it secret!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr username:';

  @override
  String get nostrInfoUsernameDescription =>
      ' A human-readable name (like @name.divine.video) that links to your npub. It makes your Nostr identity easier to recognize and verify, similar to an email address.';

  @override
  String get nostrInfoLearnMoreAt => 'Learn more at ';

  @override
  String get nostrInfoGotIt => 'Got it!';

  @override
  String get videoGridRefreshLabel => 'Searching for more videos';

  @override
  String get videoGridOptionsTitle => 'Video Options';

  @override
  String get videoGridEditVideo => 'Edit Video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Update title, description, and hashtags';

  @override
  String get videoGridDeleteVideo => 'Delete Video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Remove this video from Divine. It may still appear on other Nostr clients.';

  @override
  String get videoGridDeletingContent => 'Deleting content...';

  @override
  String get exploreTabFeatured => 'Featured';

  @override
  String get exploreTabClassics => 'Classics';

  @override
  String get exploreTabNew => 'New';

  @override
  String get exploreTabPopular => 'Popular';

  @override
  String get exploreTabCategories => 'Categories';

  @override
  String get exploreTabForYou => 'For You';

  @override
  String get exploreTabLists => 'Lists';

  @override
  String get exploreTabIntegratedApps => 'Integrated Apps';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Nothing here yet. Check back soon.';

  @override
  String get featuredTabLoadFailed => 'Couldn\'t load this collection.';

  @override
  String get featuredTabRetry => 'Try again';

  @override
  String get exploreNoVideosAvailable => 'No videos available';

  @override
  String get exploreDiscoverLists => 'Discover Lists';

  @override
  String get exploreAboutLists => 'About Lists';

  @override
  String get exploreAboutListsDescription =>
      'Lists help you organize and curate Divine content in two ways:';

  @override
  String get explorePeopleLists => 'People Lists';

  @override
  String get explorePeopleListsDescription =>
      'Follow groups of creators and see their latest videos';

  @override
  String get exploreVideoLists => 'Video Lists';

  @override
  String get exploreVideoListsDescription =>
      'Create playlists of your favorite videos to watch later';

  @override
  String get exploreMyLists => 'My Lists';

  @override
  String get exploreSubscribedLists => 'Subscribed Lists';

  @override
  String get exploreErrorLoadingLists =>
      'Error loading lists. Please try again.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new videos',
      one: '1 new video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos',
      one: 'video',
    );
    return 'Load $count new $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Play video';

  @override
  String get videoPlayerMute => 'Mute video';

  @override
  String get videoPlayerUnmute => 'Unmute video';

  @override
  String get videoPlayerTapHint => 'Tap to play or pause. Double tap to like.';

  @override
  String get videoSettingsMenuOpen => 'Open playback settings';

  @override
  String get videoSettingsMenuClose => 'Close playback settings';

  @override
  String get videoSettingsCaptionsEnable => 'Enable captions';

  @override
  String get videoSettingsCaptionsDisable => 'Disable captions';

  @override
  String get videoSettingsAutoAdvanceOn => 'Auto advance on';

  @override
  String get videoSettingsAutoAdvanceOff => 'Auto advance off';

  @override
  String get videoSettingsCaptionsOn => 'Captions on';

  @override
  String get videoSettingsCaptionsOff => 'Captions off';

  @override
  String get videoSettingsCaptionsOnForVideo => 'Captions on for this video';

  @override
  String get videoSettingsCaptionsOffForVideo => 'Captions off for this video';

  @override
  String get contentWarningLabel => 'Content Warning';

  @override
  String get contentWarningNudity => 'Nudity';

  @override
  String get contentWarningSexualContent => 'Sexual Content';

  @override
  String get contentWarningPornography => 'Pornography';

  @override
  String get contentWarningGraphicMedia => 'Graphic Media';

  @override
  String get contentWarningViolence => 'Violence';

  @override
  String get contentWarningSelfHarm => 'Self-Harm';

  @override
  String get contentWarningDrugUse => 'Drug Use';

  @override
  String get contentWarningAlcohol => 'Alcohol';

  @override
  String get contentWarningTobacco => 'Tobacco';

  @override
  String get contentWarningGambling => 'Gambling';

  @override
  String get contentWarningProfanity => 'Profanity';

  @override
  String get contentWarningFlashingLights => 'Flashing Lights';

  @override
  String get contentWarningAiGenerated => 'AI-Generated';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Sensitive Content';

  @override
  String get contentWarningDescNudity => 'Contains nudity or partial nudity';

  @override
  String get contentWarningDescSexual => 'Contains sexual content';

  @override
  String get contentWarningDescPorn => 'Contains explicit pornographic content';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contains graphic or disturbing imagery';

  @override
  String get contentWarningDescViolence => 'Contains violent content';

  @override
  String get contentWarningDescSelfHarm => 'Contains references to self-harm';

  @override
  String get contentWarningDescDrugs => 'Contains drug-related content';

  @override
  String get contentWarningDescAlcohol => 'Contains alcohol-related content';

  @override
  String get contentWarningDescTobacco => 'Contains tobacco-related content';

  @override
  String get contentWarningDescGambling => 'Contains gambling-related content';

  @override
  String get contentWarningDescProfanity => 'Contains strong language';

  @override
  String get contentWarningDescFlashingLights =>
      'Contains flashing lights (photosensitivity warning)';

  @override
  String get contentWarningDescAiGenerated =>
      'This content was generated by AI';

  @override
  String get contentWarningDescSpoiler => 'Contains spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'Creator marked this as sensitive';

  @override
  String get contentWarningDescDefault => 'Creator flagged this content';

  @override
  String get contentWarningDetailsTitle => 'Content Warnings';

  @override
  String get contentWarningDetailsSubtitle =>
      'The creator applied these labels:';

  @override
  String get contentWarningManageFilters => 'Manage content filters';

  @override
  String get contentWarningViewAnyway => 'View Anyway';

  @override
  String get contentWarningReportContentTooltip => 'Report Content';

  @override
  String get contentWarningBlockUserTooltip => 'Block User';

  @override
  String get contentWarningBlockedTitle => 'Content Blocked';

  @override
  String get contentWarningBlockedPolicy =>
      'This content has been blocked due to policy violations.';

  @override
  String get contentWarningNoticeTitle => 'Content Notice';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potentially Harmful Content';

  @override
  String get contentWarningView => 'View';

  @override
  String get contentWarningReportAction => 'Report';

  @override
  String get contentWarningHideAllLikeThis => 'Hide all content like this';

  @override
  String get contentWarningNoFilterYet =>
      'No saved filter for this warning yet.';

  @override
  String get contentWarningHiddenConfirmation =>
      'We\'ll hide posts like this from now on.';

  @override
  String get communitySuggestTitle => 'Help classify this';

  @override
  String get communitySuggestSubtitle =>
      'Missing a content warning? Your suggestion is public, signed, and can\'t be taken back.';

  @override
  String get communitySuggestSubmit => 'Suggest';

  @override
  String get communitySuggestSuccess => 'Thanks. Your suggestion was sent.';

  @override
  String get communitySuggestFailure =>
      'Couldn\'t send your suggestion. Try again.';

  @override
  String get communitySuggestAlready => 'You suggested this';

  @override
  String get communitySuggestActionLabel => 'Classify';

  @override
  String get videoErrorNotFound => 'Video not found';

  @override
  String get videoErrorPlayback => 'Video playback error';

  @override
  String get videoErrorAgeRestricted => 'Age-restricted content';

  @override
  String get videoErrorUnavailable => 'Video unavailable';

  @override
  String get videoErrorUnavailableBody =>
      'This video isn\'t available right now.';

  @override
  String get videoErrorRetry => 'Retry';

  @override
  String get videoErrorContentRestricted => 'Content restricted';

  @override
  String get videoErrorContentRestrictedBody =>
      'This video was removed for breaking our content rules.';

  @override
  String get videoErrorVerifyAgeBody => 'Verify your age to view this video.';

  @override
  String get videoErrorSkip => 'Skip';

  @override
  String get videoErrorVerifyAgeButton => 'Verify age';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Couldn\'t verify your age. Please try again.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Verification timed out. Check your connection or try again shortly.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Adult content is switched off';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Turn it on in your content filters to watch this one.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Open Content Filters';

  @override
  String get videoDetailLoadError => 'Failed to load video';

  @override
  String get videoDetailLoadErrorBody =>
      'Something went sideways on the way here. Give it another try.';

  @override
  String get videoDetailNotFoundBody =>
      'It could be gone, out of reach, or hidden by your settings.';

  @override
  String get databaseCorruptionTitle => 'Your local data got scrambled';

  @override
  String get databaseCorruptionBody =>
      'Close Divine and open it again — we\'ll patch it up automatically. We\'ll save what drafts and clips we can, everything else reloads.';

  @override
  String get databaseCorruptionCloseButton => 'Close Divine';

  @override
  String get videoDetailContextTitle => 'Shared Video';

  @override
  String get videoDetailCloseSemanticLabel => 'Close video player';

  @override
  String get videoFollowButtonFollow => 'Follow';

  @override
  String get audioAttributionOriginalSound => 'Original sound';

  @override
  String get audioAttributionUnavailableSound => 'Sound unavailable';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspired by @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspired by @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'with @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'with @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborators',
      one: '1 collaborator',
    );
    return '$_temp0. Tap to view profile.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Pending';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Pending collaborator';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending pending)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Tap to view profile.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Tap to view videos with this hashtag.';
  }

  @override
  String get listAttributionFallback => 'List';

  @override
  String get shareVideoLabel => 'Share video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post shared with $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Post shared with $count people',
      one: 'Post shared with $count person',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Failed to send video';

  @override
  String get shareAddedToBookmarks => 'Added to bookmarks';

  @override
  String get shareRemovedFromBookmarks => 'Removed from bookmarks';

  @override
  String get shareFailedToAddBookmark => 'Failed to add bookmark';

  @override
  String get shareFailedToRemoveBookmark => 'Failed to remove bookmark';

  @override
  String get shareActionFailed => 'Action failed';

  @override
  String get shareWithTitle => 'Share with';

  @override
  String get shareFindPeople => 'Find people';

  @override
  String get shareFindPeopleMultiline => 'Find\npeople';

  @override
  String get shareSent => 'Sent';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return 'Selected $name';
  }

  @override
  String get shareMessageHint => 'Add optional message...';

  @override
  String get videoActionUnlike => 'Unlike video';

  @override
  String get videoActionLike => 'Like video';

  @override
  String get videoActionAutoLabel => 'Compilation';

  @override
  String get videoActionLikeLabel => 'Like';

  @override
  String get videoActionReplyLabel => 'Reply';

  @override
  String get videoActionRepostLabel => 'Revine';

  @override
  String get videoActionShareLabel => 'Share';

  @override
  String get videoActionReportLabel => 'Report';

  @override
  String get videoActionReport => 'Report video';

  @override
  String get videoActionEditLabel => 'Edit';

  @override
  String get videoActionEdit => 'Edit video';

  @override
  String get videoActionAboutLabel => 'About';

  @override
  String get videoActionEnableAutoAdvance => 'Enable auto advance';

  @override
  String get videoActionDisableAutoAdvance => 'Disable auto advance';

  @override
  String get videoActionRemoveRepost => 'Remove repost';

  @override
  String get videoActionRepost => 'Repost video';

  @override
  String get videoActionViewComments => 'View comments';

  @override
  String get videoActionMoreOptions => 'More options';

  @override
  String get videoEngagementLikersTitle => 'Liked by';

  @override
  String get videoEngagementRepostersTitle => 'Reposted by';

  @override
  String get videoEngagementLikersEmpty => 'No likes yet';

  @override
  String get videoEngagementRepostersEmpty => 'No reposts yet';

  @override
  String get videoEngagementLoadFailed => 'Couldn\'t load that list';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Open video details';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Open video details';

  @override
  String get videoOverlayCommentBarHint => 'Add comment...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Add a comment';

  @override
  String get videoOverlayCommentBarSendLabel => 'Send comment';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Comment posted';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'Couldn\'t post comment';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loops',
      one: 'loop',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Not Divine';

  @override
  String get metadataBadgeHumanMade => 'Human-Made';

  @override
  String get metadataSoundsLabel => 'Sounds';

  @override
  String get metadataOriginalSound => 'Original sound';

  @override
  String get metadataVerificationLabel => 'Verification';

  @override
  String get metadataDeviceAttestation => 'Device attestation';

  @override
  String get metadataPgpSignature => 'PGP signature';

  @override
  String get metadataC2paCredentials => 'C2PA Content Credentials';

  @override
  String get metadataProofManifest => 'Proof manifest';

  @override
  String get metadataVerificationInfoTooltip => 'What do these checks mean?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'What these checks mean';

  @override
  String get metadataVerificationInfoIntro =>
      'These signals come from the camera and the video file itself. The more of them a video carries, the more we can prove about where it came from.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'The phone\'s operating system vouched for the app that recorded this. Strong evidence it came off a camera, not a file someone uploaded.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'The video was cryptographically signed the moment it was captured. Change a single frame afterwards and the signature breaks.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'An industry-standard record of where the video came from, carried inside the file — so apps other than Divine can check it too.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'The full ProofMode record: file fingerprint, timestamp and capture context, bundled with the video.';

  @override
  String get metadataVerificationInfoFootnote =>
      'A missing check doesn\'t make a video fake. Older clips and uploads never got one — it only means we can\'t prove that part.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Learn more at $url';
  }

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Collaborators';

  @override
  String get metadataInspiredByLabel => 'Inspired by';

  @override
  String get metadataRepostedByLabel => 'Reposted by';

  @override
  String metadataMoreReposters(int count) {
    return '+$count more';
  }

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loops',
      one: 'Loop',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Likes';

  @override
  String get metadataCommentsLabel => 'Comments';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get metadataVineStatsLabel => 'On Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loops · $likes likes · $comments comments · $reposts reposts';
  }

  @override
  String get metadataDivineStatsLabel => 'On Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views views · $likes likes · $comments comments · $reposts reposts';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Posted on $date';
  }

  @override
  String get devOptionsTitle => 'Developer Options';

  @override
  String get devOptionsDisableDeveloperMode => 'Disable Developer Mode';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Hide developer options from settings';

  @override
  String get devOptionsDisableDeveloperModeToast => 'Developer mode disabled';

  @override
  String get devOptionsShorebirdTitle => 'Shorebird Patches';

  @override
  String get devOptionsShorebirdPatchLabel => 'Running patch';

  @override
  String get devOptionsShorebirdNoPatch => 'No patch installed';

  @override
  String get devOptionsShorebirdUnavailable => 'Not available in this build';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Patches only run in a build made by shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Reading patch state…';

  @override
  String get devOptionsShorebirdNotChecked => 'Staging track not checked yet.';

  @override
  String get devOptionsShorebirdCheck => 'Check staging track';

  @override
  String get devOptionsShorebirdApply => 'Apply staged patch';

  @override
  String get devOptionsShorebirdUseStable => 'Return to stable updates';

  @override
  String get devOptionsShorebirdChecking => 'Checking the staging track…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'A staged patch is ready to apply.';

  @override
  String get devOptionsShorebirdUpToDate => 'No staged patch for this release.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Downloaded. Restart the app to load it.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'A rollback is ready. Restart to return to the base release.';

  @override
  String get devOptionsShorebirdApplying => 'Downloading and installing…';

  @override
  String get devOptionsShorebirdApplied =>
      'Installed. Restart the app to load it.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Nothing was installed. Check the staging track and try again.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Selecting stable track…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Stable track selected. Restart to check for a stable patch.';

  @override
  String get devOptionsShorebirdFailure =>
      'That didn\'t work. Check the logs for details.';

  @override
  String get devOptionsPageLoadTimes => 'Page Load Times';

  @override
  String get devOptionsNoPageLoads =>
      'No page loads recorded yet.\nNavigate around the app to see timing data.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visible: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Slowest Screens';

  @override
  String get devOptionsVideoPlaybackFormat => 'Video Playback Format';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Switch Environment?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Switch to $envName?\n\nThis will clear cached video data and reconnect to the new relay.';
  }

  @override
  String get devOptionsCancel => 'Cancel';

  @override
  String get devOptionsSwitch => 'Switch';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Switched to $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Switched to $formatName — cache cleared';
  }

  @override
  String get featureFlagTitle => 'Feature Flags';

  @override
  String get featureFlagResetAllTooltip => 'Reset all flags to defaults';

  @override
  String get featureFlagError => 'Error';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine is an open system - you control your connections';

  @override
  String get relaySettingsInfoDescription =>
      'These relays distribute your content across the decentralized Nostr network. You can add or remove relays as you wish.';

  @override
  String get relaySettingsLearnMoreNostr => 'Learn more about Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Find public relays at nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App Not Functional';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine requires at least one relay to load videos, post content, and sync data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Restore Default Relay';

  @override
  String get relaySettingsAddCustomRelay => 'Add Custom Relay';

  @override
  String get relaySettingsAddRelay => 'Add Relay';

  @override
  String get relaySettingsRetry => 'Retry';

  @override
  String get relaySettingsNoStats => 'No statistics available yet';

  @override
  String get relaySettingsConnection => 'Connection';

  @override
  String get relaySettingsConnected => 'Connected';

  @override
  String get relaySettingsDisconnected => 'Disconnected';

  @override
  String get relaySettingsSessionDuration => 'Session Duration';

  @override
  String get relaySettingsLastConnected => 'Last Connected';

  @override
  String get relaySettingsDisconnectedLabel => 'Disconnected';

  @override
  String get relaySettingsReason => 'Reason';

  @override
  String get relaySettingsActiveSubscriptions => 'Active Subscriptions';

  @override
  String get relaySettingsTotalSubscriptions => 'Total Subscriptions';

  @override
  String get relaySettingsEventsReceived => 'Events Received';

  @override
  String get relaySettingsEventsSent => 'Events Sent';

  @override
  String get relaySettingsRequestsThisSession => 'Requests This Session';

  @override
  String get relaySettingsFailedRequests => 'Failed Requests';

  @override
  String get relaySettingsLoadingRelayInfo => 'Loading relay info...';

  @override
  String get relaySettingsAboutRelay => 'About Relay';

  @override
  String get relaySettingsSupportedNips => 'Supported NIPs';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'View Website';

  @override
  String get relaySettingsRemoveRelayTitle => 'Remove Relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Are you sure you want to remove this relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Remove Divine Relay?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Removing Divine\'s relay will degrade the app experience. Videos, posting, and sync may be less reliable. This should only be done by experienced Nostr users.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Remove relay';

  @override
  String get relaySettingsCancel => 'Cancel';

  @override
  String get relaySettingsRemove => 'Remove';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Removed relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Failed to remove relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forcing relay reconnection...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connected to $count relays!',
      one: 'Connected to $count relay!',
    );
    return '$_temp0';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Failed to connect to relays. Please check your network connection.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Saved on this device. We\'ll sync it to your account when publishing works again.';

  @override
  String get relaySettingsAddRelayTitle => 'Add Relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Enter the WebSocket URL of the relay you want to add:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Browse public relays at nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Add';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Added relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Failed to add relay. Please check the URL and try again.';

  @override
  String get relaySettingsInvalidUrl =>
      'Relay URL must start with wss:// or ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'Relay URL must use wss:// (ws:// is allowed only for localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Restored default relay: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Failed to restore default relay. Please check your network connection.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Could not open browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Failed to open link';

  @override
  String get relaySettingsExternalRelay => 'External relay';

  @override
  String get relaySettingsNotConnected => 'Not connected';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Disconnected $duration ago';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subs',
      one: '$count sub',
    );
    return '$_temp0';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$count events',
      one: '$count event',
    );
    return '$_temp0';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration ago';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine uses the Nostr protocol for decentralized publishing. Your content lives on relays you choose, and your keys are your identity.';

  @override
  String get nostrSettingsSectionNetwork => 'Network';

  @override
  String get nostrSettingsSectionAccount => 'Account';

  @override
  String get nostrSettingsSectionDangerZone => 'Danger Zone';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle => 'Manage Nostr relay connections';

  @override
  String get nostrSettingsRelayDiagnostics => 'Relay Diagnostics';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debug relay connectivity and network issues';

  @override
  String get nostrSettingsMediaServers => 'Media Servers';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configure Blossom upload servers';

  @override
  String get settingsDeveloperOptions => 'Developer Options';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Environment switcher and debug settings';

  @override
  String get nostrSettingsKeyManagement => 'Key Management';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Export, backup, and restore your Nostr keys';

  @override
  String get nostrSettingsClientAttribution => 'Client Attribution';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Include a Divine client tag on events you publish so other Nostr apps can attribute them correctly. Without it, reports you send carry less weight when our moderators review them.';

  @override
  String get nostrSettingsMoveAccount => 'Move your account';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Download your archive and move your posts and videos to another relay or media server.';

  @override
  String get nostrSettingsRemoveKeys => 'Remove this account from this device';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Remove this account\'s local login from this device. Your local drafts and clips stay saved for this account.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Could not remove this account from this device. Please try again.';

  @override
  String get nostrSettingsDeleteAccount => 'Delete Account and Data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Sends deletion requests for your content and signs you out on this device. Relays, clients, search indexes, and other signed-in devices may keep copies.';

  @override
  String get relayDiagnosticTitle => 'Relay Diagnostics';

  @override
  String get relayDiagnosticRefreshTooltip => 'Refresh diagnostics';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Last refresh: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relay Status';

  @override
  String get relayDiagnosticInitialized => 'Initialized';

  @override
  String get relayDiagnosticReady => 'Ready';

  @override
  String get relayDiagnosticNotInitialized => 'Not initialized';

  @override
  String get relayDiagnosticDatabaseEvents => 'Database Events';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Active Subscriptions';

  @override
  String get relayDiagnosticExternalRelays => 'External Relays';

  @override
  String get relayDiagnosticConfigured => 'Configured';

  @override
  String relayDiagnosticRelayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relays',
      one: '$count relay',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Connected';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video Events';

  @override
  String get relayDiagnosticHomeFeed => 'Home Feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticDiscovery => 'Discovery';

  @override
  String get relayDiagnosticLoading => 'Loading';

  @override
  String get relayDiagnosticYes => 'Yes';

  @override
  String get relayDiagnosticNo => 'No';

  @override
  String get relayDiagnosticTestDirectQuery => 'Test Direct Query';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Network Connectivity';

  @override
  String get relayDiagnosticRunNetworkTest => 'Run Network Test';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom Server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Test All Endpoints';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Error';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Base URL';

  @override
  String get relayDiagnosticSummary => 'Summary';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (avg ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retest All';

  @override
  String get relayDiagnosticRetrying => 'Retrying...';

  @override
  String get relayDiagnosticRetryConnection => 'Retry Connection';

  @override
  String get relayDiagnosticTroubleshooting => 'Troubleshooting';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Green status = Connected and working\n• Red status = Connection failed\n• If network test fails, check internet connection\n• If relays are configured but not connected, tap \"Retry Connection\"\n• Screenshot this screen for debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'All REST endpoints healthy!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Some REST endpoints failed - see details above';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count video events in database',
      one: 'Found $count video event in database',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticQueryFailed => 'Query failed. Please try again.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connected to $count relays!',
      one: 'Connected to $count relay!',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Failed to connect to any relays';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Connection retry failed. Please try again.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Connected & Authenticated';

  @override
  String get relayDiagnosticConnectedOnly => 'Connected';

  @override
  String get relayDiagnosticNotConnected => 'Not connected';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'No relays configured';

  @override
  String get relayDiagnosticFailed => 'Failed';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSettingsResetTooltip => 'Reset to defaults';

  @override
  String get notificationSettingsTypes => 'Notification Types';

  @override
  String get notificationSettingsLikes => 'Likes';

  @override
  String get notificationSettingsLikesSubtitle =>
      'When someone likes your videos';

  @override
  String get notificationSettingsComments => 'Comments';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'When someone comments on your videos';

  @override
  String get notificationSettingsFollows => 'Follows';

  @override
  String get notificationSettingsFollowsSubtitle => 'When someone follows you';

  @override
  String get notificationSettingsMentions => 'Mentions';

  @override
  String get notificationSettingsMentionsSubtitle => 'When you are mentioned';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'When someone reposts your videos';

  @override
  String get notificationSettingsNewPosts => 'New vines';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'When someone you\'re watching posts';

  @override
  String get notificationSettingsActions => 'Actions';

  @override
  String get notificationSettingsMarkAllAsRead => 'Mark All as Read';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Mark all notifications as read';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'All notifications marked as read';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Failed to mark all as read';

  @override
  String get notificationSettingsResetToDefaults =>
      'Settings reset to defaults';

  @override
  String get notificationSettingsAbout => 'About Notifications';

  @override
  String get notificationSettingsAboutDescription =>
      'Notifications are powered by the Nostr protocol. Real-time updates depend on your connection to Nostr relays. Some notifications may have delays.';

  @override
  String get safetySettingsWhatYouSee => 'WHAT YOU SEE';

  @override
  String get safetySettingsWhatYouPublish => 'WHAT YOU PUBLISH';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Only show Divine-hosted videos';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Hide videos served from other media hosts';

  @override
  String get safetySettingsModeration => 'MODERATION';

  @override
  String get safetySettingsBlockedUsers => 'BLOCKED USERS';

  @override
  String get safetySettingsAgeVerification => 'AGE VERIFICATION';

  @override
  String get safetySettingsAgeConfirmation =>
      'I confirm I am 18 years or older';

  @override
  String get safetySettingsAgeRequired => 'Required to view adult content';

  @override
  String get safetySettingsAgeLockedForMinor => 'Locked for your account';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Official moderation service (on by default)';

  @override
  String get safetySettingsPeopleIFollow => 'People I follow';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Subscribe to labels from people you follow';

  @override
  String get safetySettingsAddCustomLabeler => 'Add Custom Labeler';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Enter npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'Add custom labeler';

  @override
  String get safetySettingsRemoveLabeler => 'Remove labeler';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Enter npub address';

  @override
  String get safetySettingsNoBlockedUsers => 'No blocked users';

  @override
  String get safetySettingsUnblock => 'Unblock';

  @override
  String get safetySettingsUserUnblocked => 'User unblocked';

  @override
  String get safetySettingsCancel => 'Cancel';

  @override
  String get safetySettingsAdd => 'Add';

  @override
  String get analyticsTitle => 'Creator Analytics';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostics';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Toggle diagnostics';

  @override
  String get analyticsRetry => 'Retry';

  @override
  String get analyticsUnableToLoad => 'Unable to load analytics.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired => 'Sign in to view creator analytics.';

  @override
  String get analyticsViewDataUnavailable =>
      'Views are currently unavailable from the relay for these posts. Like/comment/repost metrics are still accurate.';

  @override
  String get analyticsViewDataTitle => 'View Data';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Updated $time • Scores use likes, comments, reposts, and views/loops from Funnelcake when available.';
  }

  @override
  String get analyticsVideos => 'Videos';

  @override
  String get analyticsViews => 'Views';

  @override
  String get analyticsInteractions => 'Interactions';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Followers';

  @override
  String get analyticsAvgPerPost => 'Avg/Post';

  @override
  String get analyticsInteractionMix => 'Interaction Mix';

  @override
  String get analyticsLikes => 'Likes';

  @override
  String get analyticsComments => 'Comments';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Performance Highlights';

  @override
  String get analyticsMostViewed => 'Most viewed';

  @override
  String get analyticsMostDiscussed => 'Most discussed';

  @override
  String get analyticsMostReposted => 'Most reposted';

  @override
  String get analyticsNoVideosYet => 'No videos yet';

  @override
  String get analyticsViewDataUnavailableShort => 'View data unavailable';

  @override
  String analyticsViewsCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$count views',
      one: '$count view',
    );
    return '$_temp0';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$count comments',
      one: '$count comment',
    );
    return '$_temp0';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$count reposts',
      one: '$count repost',
    );
    return '$_temp0';
  }

  @override
  String get analyticsTopContent => 'Top Content';

  @override
  String get analyticsPublishPrompt => 'Publish a few videos to see rankings.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Right-side % = Engagement Rate (interactions divided by views).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Engagement Rate needs view data; values show as N/A until views are available.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'views unavailable';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$count interactions',
      one: '$count interaction',
    );
    return '$_temp0';
  }

  @override
  String get analyticsPostAnalytics => 'Post Analytics';

  @override
  String get analyticsOpenPost => 'Open Post';

  @override
  String get analyticsRecentDailyInteractions => 'Recent Daily Interactions';

  @override
  String get analyticsNoActivityYet => 'No activity in this range yet.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interactions = likes + comments + reposts by post date.';

  @override
  String get analyticsDailyBarExplainer =>
      'Bar length is relative to your highest day in this window.';

  @override
  String get analyticsAudienceSnapshot => 'Audience Snapshot';

  @override
  String analyticsFollowersCount(String count) {
    return 'Followers: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Following: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Audience source/geo/time breakdowns will populate as Funnelcake adds audience analytics endpoints.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Retention curve and watch-time breakdown will appear once per-second/per-bucket retention arrives from Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retention data unavailable until view+watch-time analytics are returned by Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostics';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total videos: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'With views: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Missing views: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydrated (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydrated (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sources: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Use fixture data';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Create a new Divine account';

  @override
  String get authCreateNewAccountShort => 'Create new account';

  @override
  String get authSignInDifferentAccount => 'Sign in with an existing account';

  @override
  String get authUseAnotherAccount => 'Use another account';

  @override
  String authContinueAs(String displayName) {
    return 'Continue as $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Your drafts and clips are saved for this account';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Signing in here will hide those drafts and clips';

  @override
  String get authTermsPrefix =>
      'By selecting an option below, you confirm you are at least 16 years old (or have completed ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine age authorization';

  @override
  String get authTermsAfterAgeAuthorization => ') and agree to the ';

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authTermsAnd => ', and ';

  @override
  String get authSafetyStandards => 'Safety Standards';

  @override
  String get authAmberNotInstalled => 'Amber app is not installed';

  @override
  String get authAmberConnectionFailed => 'Failed to connect with Amber';

  @override
  String get authPasswordResetSent =>
      'If an account exists with that email, a password reset link has been sent.';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authEmailRequired => 'Email is required';

  @override
  String get authEmailInvalid => 'Please enter a valid email';

  @override
  String get authPasswordRequired => 'Password is required';

  @override
  String get authConfirmPasswordRequired => 'Please confirm your password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords don\'t match';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authImportNostrKey => 'Import Nostr key';

  @override
  String get authConnectSignerApp => 'Connect with a signer app';

  @override
  String get authSignInWithAmber => 'Sign in with Amber';

  @override
  String get authSignInWithBrowserExtension => 'Sign in with browser extension';

  @override
  String get authNip07ConnectionFailed =>
      'Couldn\'t connect to your browser extension.';

  @override
  String get authNip07ExtensionNotFound =>
      'No browser extension found. Install Alby, nos2x, or another NIP-07 compatible extension.';

  @override
  String get authSignInOptionsTitle => 'Sign-in options';

  @override
  String get authInfoEmailPasswordTitle => 'Email & Password';

  @override
  String get authInfoEmailPasswordDescription =>
      'Sign in with your Divine account. If you registered with an email and password, use them here.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Already have a Nostr identity? Import your nsec private key from another client.';

  @override
  String get authInfoSignerAppTitle => 'Signer App';

  @override
  String get authInfoSignerAppDescription =>
      'Connect using a NIP-46 compatible remote signer like nsecBunker for enhanced key security.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Use the Amber signer app on Android to manage your Nostr keys securely.';

  @override
  String get authInfoBrowserExtensionTitle => 'Browser Extension';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Sign in with a NIP-07 browser extension like Alby or nos2x. Your keys stay in the extension — Divine never sees them.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Wrong email or password. Give it another try.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Verify your email before signing in — check your inbox for the link.';

  @override
  String get authSignInErrorInvalidEmail =>
      'That doesn\'t look like a valid email address.';

  @override
  String get authSignInErrorNetwork =>
      'Can\'t reach the server. Check your connection and try again.';

  @override
  String get authSignInErrorGeneric =>
      'Something went wrong. Please try again.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Not sure how you got in last time? ';

  @override
  String get authSignInOptionsHintCta => 'See every sign-in option';

  @override
  String get authCreateAccountTitle => 'Create account';

  @override
  String get authBackToInviteCode => 'Back to invite code';

  @override
  String get authUseDivineNoBackup => 'Use Divine with no backup';

  @override
  String get authSkipConfirmTitle => 'One last thing...';

  @override
  String get authSkipConfirmKeyCreated =>
      'You\'re in! We\'ll create a secure key that powers your Divine account.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Without an email, your key is the only way Divine knows this account is yours.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'You can access your key in the app, but, if you\'re not technical we recommend adding an email and password now. It makes it easier to sign in and restore your account if you lose or reset this device.';

  @override
  String get authAddEmailPassword => 'Add email & password';

  @override
  String get authUseThisDeviceOnly => 'Use this device only';

  @override
  String get authCompleteRegistration => 'Complete your registration';

  @override
  String get authVerifying => 'Verifying...';

  @override
  String get authVerificationLinkSent => 'We sent a verification link to:';

  @override
  String get authClickVerificationLink =>
      'Please click the link in your email to\ncomplete your registration.';

  @override
  String get authPleaseWaitVerifying =>
      'Please wait while we verify your email...';

  @override
  String get authWaitingForVerification => 'Waiting for verification';

  @override
  String get authOpenEmailApp => 'Open email app';

  @override
  String get authVerificationPinPrompt =>
      'Or enter the 6-digit code from your email';

  @override
  String get authVerificationPinFieldLabel => '6-digit code';

  @override
  String get authVerificationPinSubmit => 'Verify code';

  @override
  String get authVerificationResendPrompt => 'Didn\'t get it?';

  @override
  String get authVerificationResend => 'Resend';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Resend in $time';
  }

  @override
  String get authVerificationResendFailed =>
      'We couldn\'t resend the email. Try again.';

  @override
  String get authVerificationResendExpired =>
      'That signup expired. Start again to get a fresh code.';

  @override
  String get authVerificationResendUnavailable =>
      'Resending isn\'t available right now. Use the 6-digit code from the email we already sent you.';

  @override
  String get authVerificationPollingStopped =>
      'We stopped checking for you. Enter the 6-digit code from your email to finish signing in.';

  @override
  String get authWelcomeToDivine => 'Welcome to Divine!';

  @override
  String get authEmailVerified => 'Your email has been verified.';

  @override
  String get authSigningYouIn => 'Signing you in';

  @override
  String get authErrorTitle => 'Uh oh.';

  @override
  String get authVerificationFailed =>
      'We failed to verify your email.\nPlease try again.';

  @override
  String get authStartOver => 'Start over';

  @override
  String get authEmailVerifiedLogin =>
      'Email verified! Please log in to continue.';

  @override
  String get authVerificationLinkExpired =>
      'This verification link is no longer valid.';

  @override
  String get authVerificationConnectionError =>
      'Unable to verify email. Please check your connection and try again.';

  @override
  String get authWaitlistConfirmTitle => 'You\'re in!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'We\'ll share updates at $email.\nWhen more invite codes are available, we\'ll send them your way.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Try again';

  @override
  String get authContactSupport => 'Contact support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Could not open $email';
  }

  @override
  String get authAddInviteCode => 'Add your invite code';

  @override
  String get authInviteCodeLabel => 'Invite code';

  @override
  String get authEnterYourCode => 'Enter your code';

  @override
  String get authNext => 'Next';

  @override
  String get authJoinWaitlist => 'Join waitlist';

  @override
  String get authJoinWaitlistTitle => 'Join the waitlist';

  @override
  String get authJoinWaitlistDescription =>
      'Share your email and we\'ll send an invite code as access opens up.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'Invite access help';

  @override
  String get authGeneratingConnection => 'Generating connection...';

  @override
  String get authConnectedAuthenticating => 'Connected! Authenticating...';

  @override
  String get authConnectionTimedOut => 'Connection timed out';

  @override
  String get authApproveConnection =>
      'Make sure you approved the connection in your signer app.';

  @override
  String get authConnectionCancelled => 'Connection cancelled';

  @override
  String get authConnectionCancelledMessage => 'The connection was cancelled.';

  @override
  String get authConnectionFailed => 'Connection failed';

  @override
  String get authUnknownError => 'An unknown error occurred.';

  @override
  String get authNostrConnectStartFailed =>
      'Couldn\'t reach the signer. Check your connection and try again.';

  @override
  String get authNostrConnectInvalidSession =>
      'This connection link is no longer valid. Start a new one.';

  @override
  String get authNostrConnectSetupFailed =>
      'Almost there — we couldn\'t finish signing you in. Try again.';

  @override
  String get authUrlCopied => 'URL copied to clipboard';

  @override
  String get authConnectToDivine => 'Connect to Divine';

  @override
  String get authPasteBunkerUrl => 'Paste bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Invalid bunker URL. It should start with bunker://';

  @override
  String get authScanSignerApp => 'Scan with your\nsigner app to connect.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Waiting for connection... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copy URL';

  @override
  String get authShare => 'Share';

  @override
  String get authAddBunker => 'Add bunker';

  @override
  String get authCompatibleSignerApps => 'Compatible Signer apps';

  @override
  String get authFailedToConnect => 'Failed to connect';

  @override
  String get authResetPasswordTitle => 'Reset Password';

  @override
  String get authResetPasswordSubtitle =>
      'Please enter your new password. It must be at least 8 characters in length.';

  @override
  String get authNewPasswordLabel => 'New Password';

  @override
  String get authConfirmNewPasswordLabel => 'Confirm new password';

  @override
  String get authPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get authPasswordResetSuccess =>
      'Password reset successful. Please log in.';

  @override
  String get authPasswordResetFailed => 'Password reset failed';

  @override
  String get authUnexpectedError =>
      'An unexpected error occurred. Please try again.';

  @override
  String get authUpdatePassword => 'Update password';

  @override
  String get authSecureAccountTitle => 'Secure account';

  @override
  String get authUnableToAccessKeys =>
      'Unable to access your keys. Please try again.';

  @override
  String get authRegistrationFailed => 'Registration failed';

  @override
  String get authRegistrationComplete =>
      'Registration complete. Please check your email.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'Failed to send reset email.';

  @override
  String get authSending => 'Sending...';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authVerificationErrorTimeout =>
      'Verification timed out. Please try registering again.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verification failed — missing authorization code.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verification failed. Please try again.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Network error during sign-in. Please try again.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verification failed. Please try registering again.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Sign-in failed. Please try logging in manually.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'This email is already registered. Sign in instead.';

  @override
  String get authVerificationErrorPinInvalid =>
      'That code didn\'t match. Double-check it and try again.';

  @override
  String get authVerificationErrorPinExpired =>
      'That code has expired. Tap resend to get a new one.';

  @override
  String get authVerificationErrorPinLocked =>
      'Too many tries. Tap resend to get a fresh code.';

  @override
  String get authVerificationErrorPinFailed =>
      'We couldn\'t verify that code. Please try again.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Code entry isn\'t available right now. Tap the link in your email, or resend to get a fresh one.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Enter an invite code like ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'That invite code does not look valid.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'That invite code has already been used or revoked.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'This creator\'s invites are full';

  @override
  String get authInviteGateErrorUnavailable =>
      'That invite code is unavailable. Join the waitlist and we\'ll send an invite when there\'s room.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'We couldn\'t check that code. Try again.';

  @override
  String get authInviteGateErrorUnknown =>
      'Something went wrong. Try your invite code again.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'That invite code is no longer available. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get authInviteErrorInvalid =>
      'That invite code cannot be used right now. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get authInviteErrorTemporary =>
      'We couldn\'t confirm your invite right now. Go back to your invite code and try again, or contact support.';

  @override
  String get authInviteErrorUnknown =>
      'We couldn\'t activate your invite. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get shareSheetSave => 'Save';

  @override
  String get shareSheetRemoveFromSaved => 'Remove from saved';

  @override
  String get shareSheetSaveToGallery => 'Save to Gallery';

  @override
  String get shareSheetSaveWithWatermark => 'Save with Watermark';

  @override
  String get shareSheetSaveVideo => 'Save Video';

  @override
  String get shareSheetAddToClips => 'Add to clips';

  @override
  String get shareSheetNameClipTitle => 'Name this clip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Pick a name you\'ll recognize in your library.';

  @override
  String get shareSheetClipTitleLabel => 'Clip title';

  @override
  String get shareSheetSaveClip => 'Save clip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Saved \"$title\" to clips';
  }

  @override
  String get shareSheetUntitledClip => 'Untitled clip';

  @override
  String get shareSheetAddToClipsFailed => 'Couldn\'t add to clips';

  @override
  String get shareSheetAddToList => 'Add to List';

  @override
  String get shareSheetCopy => 'Copy';

  @override
  String get shareSheetShareVia => 'Share via';

  @override
  String get shareSheetEventJson => 'Event JSON';

  @override
  String get shareSheetEventId => 'Event ID';

  @override
  String get shareSheetMoreActions => 'More actions';

  @override
  String get shareSheetCrosspost => 'Crosspost';

  @override
  String get crosspostSheetTitle => 'Crosspost this video';

  @override
  String get crosspostSheetSubtitle =>
      'Send it to your connected platforms. Posting can take a few minutes.';

  @override
  String get crosspostSubmit => 'Crosspost';

  @override
  String get crosspostStatusQueued => 'Queued';

  @override
  String get crosspostStatusUploading => 'Uploading';

  @override
  String get crosspostStatusProcessing => 'Processing';

  @override
  String get crosspostStatusPosted => 'Posted';

  @override
  String get crosspostStatusFailed => 'Failed';

  @override
  String get crosspostStatusSkipped => 'Skipped';

  @override
  String get crosspostStatusNeedsReauth => 'Needs reconnecting';

  @override
  String get crosspostViewPost => 'View post';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Reconnect $platform in crossposting settings to keep posting.';
  }

  @override
  String get crosspostReconnect => 'Reconnect';

  @override
  String get crosspostErrorNotOwner =>
      'Only your own videos can be crossposted.';

  @override
  String get crosspostErrorNotEligible =>
      'This video isn\'t eligible for crossposting.';

  @override
  String get crosspostErrorNotConnected => 'That platform isn\'t connected.';

  @override
  String get crosspostErrorUnauthorized =>
      'Reconnect your account, then try again.';

  @override
  String get crosspostErrorNetwork =>
      'Couldn\'t reach the crossposter. Try again in a moment.';

  @override
  String get crosspostFailedGeneric => 'Crosspost failed.';

  @override
  String get crosspostStillWorking =>
      'Still working. You can close this — posting continues in the background.';

  @override
  String get crosspostDone => 'Done';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Saved to Camera Roll';

  @override
  String get watermarkDownloadShare => 'Share';

  @override
  String get watermarkDownloadDone => 'Done';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Photos Access Needed';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'To save videos, allow Photos access in Settings.';

  @override
  String get watermarkDownloadOpenSettings => 'Open Settings';

  @override
  String get watermarkDownloadNotNow => 'Not Now';

  @override
  String get watermarkDownloadFailed => 'Download Failed';

  @override
  String get watermarkDownloadDismiss => 'Dismiss';

  @override
  String get watermarkDownloadStageDownloading => 'Downloading Video';

  @override
  String get watermarkDownloadStageWatermarking => 'Adding Watermark';

  @override
  String get watermarkDownloadStageSaving => 'Saving to Camera Roll';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Fetching the video from the network...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Applying the Divine watermark...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Saving the watermarked video to your camera roll...';

  @override
  String get shareMenuBookmarks => 'Bookmarks';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count follow sets available',
      one: '$count follow set available',
    );
    return '$_temp0';
  }

  @override
  String get peopleListsAddToList => 'Add to list';

  @override
  String get peopleListsSheetTitle => 'Add to list';

  @override
  String get peopleListsEmptyTitle => 'No lists yet';

  @override
  String get peopleListsEmptySubtitle =>
      'Create a list to start grouping people.';

  @override
  String get peopleListsCreateList => 'Create list';

  @override
  String get peopleListsNewListTitle => 'New list';

  @override
  String get peopleListsRouteTitle => 'People list';

  @override
  String get peopleListsListNameLabel => 'List name';

  @override
  String get peopleListsListNameHint => 'Close friends';

  @override
  String get peopleListsCreateButton => 'Create';

  @override
  String get peopleListsAddPeopleTitle => 'Add people';

  @override
  String get peopleListsAddPeopleTooltip => 'Add people';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Add people to list';

  @override
  String get peopleListsListNotFoundTitle => 'List not found';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'List not found. It may have been deleted.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'This list may have been deleted.';

  @override
  String get peopleListsNoPeopleTitle => 'No people in this list';

  @override
  String get peopleListsNoPeopleSubtitle => 'Add some people to get started';

  @override
  String get peopleListsNoVideosTitle => 'No videos yet';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Videos from list members will appear here';

  @override
  String get peopleListsNoVideosAvailable => 'No videos available';

  @override
  String get peopleListsFailedToLoadVideos => 'Failed to load videos';

  @override
  String get peopleListsVideoNotAvailable => 'Video not available';

  @override
  String get peopleListsBackToGridTooltip => 'Back to grid';

  @override
  String get peopleListsErrorLoadingVideos => 'Error loading videos';

  @override
  String get peopleListsNoPeopleToAdd => 'No people available to add.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Add to $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Search people';

  @override
  String get peopleListsAddPeopleError =>
      'Couldn\'t load people. Please try again.';

  @override
  String get peopleListsAddPeopleRetry => 'Try again';

  @override
  String get peopleListsAddButton => 'Add';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Add $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count lists',
      one: 'In 1 list',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'They will be removed from this list.';

  @override
  String get peopleListsRemove => 'Remove';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Removed $name from list';
  }

  @override
  String get peopleListsUndo => 'Undo';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profile for $name. Long press to remove.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'View profile for $name';
  }

  @override
  String get shareMenuEditVideo => 'Edit Video';

  @override
  String get shareMenuDeleteVideo => 'Delete Video';

  @override
  String shareMenuVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'This will permanently delete this video from Divine. It may still appear on third-party Nostr clients that use other relays.';

  @override
  String get shareMenuCancel => 'Cancel';

  @override
  String get shareMenuDelete => 'Delete';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Deletion isn\'t ready yet. Try again in a moment.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'You can only delete your own videos.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Sign in again, then try deleting.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Couldn\'t sign the delete request. Try again.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'The relay wouldn\'t accept this delete request. Try again in a moment.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Deleted. Not every relay confirmed, so it may still show up in other apps.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Couldn\'t delete this video. Try again.';

  @override
  String get shareMenuUpdate => 'Update';

  @override
  String get shareMenuChangeCover => 'Change Cover';

  @override
  String get shareMenuVideoUpdated => 'Video updated successfully';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites did not send.',
      one: '1 collaborator invite did not send.',
    );
    return 'Video updated, but $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Sign in again, then try updating.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'This video has no playable source, so it can\'t be updated.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Couldn\'t sign the update. Try again.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'The relay wouldn\'t accept the update. Try again in a moment.';

  @override
  String get videoUpdateErrorGeneric =>
      'Couldn\'t update this video. Try again.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Delete Video?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Removing video…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Video deleted.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Video deleted. It may take a little while to disappear everywhere.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Video deleted, but we couldn\'t remove every copy. Please contact support.';

  @override
  String get authSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Failed to sign in. Please try again.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Web authentication not supported in secure mode. Please use mobile app for secure key management.';

  @override
  String get webAuthEnterBunkerUri => 'Please enter a bunker URI';

  @override
  String get webAuthConnectTitle => 'Connect to Divine';

  @override
  String get webAuthChooseMethod =>
      'Choose your preferred Nostr authentication method';

  @override
  String get webAuthBrowserExtension => 'Browser Extension';

  @override
  String get webAuthRecommended => 'RECOMMENDED';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Connect to a remote signer';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Paste from clipboard';

  @override
  String get webAuthConnectToBunker => 'Connect to Bunker';

  @override
  String get webAuthNewToNostr => 'New to Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Install a browser extension like Alby or nos2x for the easiest experience, or use nsec bunker for secure remote signing.';

  @override
  String get soundsTitle => 'Sounds';

  @override
  String get soundsSearchHint => 'Search sounds...';

  @override
  String get soundsSearchResults => 'Search Results';

  @override
  String get soundsNoSoundsFound => 'No sounds found';

  @override
  String get soundsNoSoundsFoundDescription => 'Try a different search term';

  @override
  String get soundsSavedToLibrary => 'Saved to Sounds';

  @override
  String get soundsAlreadySavedToLibrary => 'Already in Sounds';

  @override
  String get soundsSavedLibraryTitle => 'My Sounds';

  @override
  String get soundsSavedEmptyTitle => 'No saved sounds yet';

  @override
  String get soundsSavedEmptyDescription =>
      'Tap Use Sound on a video to save it here.';

  @override
  String get soundsRemoveSavedSound => 'Remove sound';

  @override
  String get savedSoundSaveAction => 'Save';

  @override
  String get savedSoundPausePreviewAction => 'Pause preview';

  @override
  String get savedSoundResumePreviewAction => 'Resume preview';

  @override
  String get savedSoundDetailsSheetTitle => 'Sound details';

  @override
  String get savedSoundRemoveConfirmTitle => 'Remove this sound?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'It leaves your library, but you can save it again from any video that uses it.';

  @override
  String get soundsRemovedFromLibrary => 'Removed from Sounds';

  @override
  String get soundsSaveFailed => 'Couldn\'t save that sound. Try again.';

  @override
  String get soundsRemoveFailed => 'Couldn\'t remove that sound. Try again.';

  @override
  String get soundSyncStatusSyncing => 'Syncing your sounds…';

  @override
  String get soundSyncStatusSynced => 'Sounds up to date';

  @override
  String get soundSyncStatusFailed =>
      'Couldn\'t sync your sounds. We\'ll try again.';

  @override
  String get soundSyncStatusLocked =>
      'Can\'t unlock your synced library on this device.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileMoreOptions => 'More options';

  @override
  String profileBlockedUser(String name) {
    return 'Blocked $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Unblocked $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Unfollowed $name';
  }

  @override
  String get profileFeedError =>
      'Can\'t reach the server. Check your connection and try again.';

  @override
  String get profileFeedLoadMoreError =>
      'Couldn\'t load more videos. Pull to refresh.';

  @override
  String get notificationsTabAll => 'All';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Comments';

  @override
  String get notificationsTabFollows => 'Follows';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Failed to load notifications';

  @override
  String get notificationsRetry => 'Retry';

  @override
  String get notificationsRefreshError =>
      'Couldn\'t refresh — showing what you have';

  @override
  String get notificationsUnreadPrefix => 'Unread notification';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'View $displayName profile';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'View profiles';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Video thumbnail for $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Video thumbnail';

  @override
  String get notificationsInviteSingular =>
      'You have 1 invite to share with a friend!';

  @override
  String notificationsInvitePlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count invites to share with friends!',
      one: 'You have $count invite to share with friends!',
    );
    return '$_temp0';
  }

  @override
  String notificationsTabBadges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Badges ($count)',
      zero: 'Badges',
    );
    return '$_temp0';
  }

  @override
  String notificationsPendingBadges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count badges are waiting for you to accept them',
      one: 'A badge is waiting for you to accept it',
    );
    return '$_temp0';
  }

  @override
  String get notificationsBadgesEmpty =>
      'No badges waiting. When someone awards you one, it lands here.';

  @override
  String get notificationsVideoUnavailable => 'Video unavailable';

  @override
  String get feedFailedToLoadVideos => 'Failed to load videos';

  @override
  String get feedRetry => 'Retry';

  @override
  String get feedNoFollowedUsers =>
      'No followed users.\nFollow someone to see their videos here.';

  @override
  String get feedModeForYou => 'For You';

  @override
  String get feedModeNew => 'New';

  @override
  String get feedModeFollowing => 'Following';

  @override
  String get feedModeClassics => 'Classics';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Feed mode: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Video author: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Author avatar';

  @override
  String get feedForYouEmpty =>
      'Your For You feed is empty.\nExplore videos and follow creators to shape it.';

  @override
  String get feedFollowingEmpty =>
      'No videos from people you follow yet.\nFind creators you like and follow them.';

  @override
  String get feedLatestEmpty => 'No new videos yet.\nCheck back soon.';

  @override
  String get feedClassicEmpty => 'No classic Vines yet.\nCheck back soon.';

  @override
  String get feedExploreVideos => 'Explore Videos';

  @override
  String get feedLoadingMore => 'Loading more videos…';

  @override
  String get feedRefreshed => 'Feed refreshed';

  @override
  String get uploadUploadingVideo => 'Uploading video';

  @override
  String get postPublishConfirmationTitle => 'Published to your profile';

  @override
  String get postPublishConfirmationView => 'View';

  @override
  String get postPublishConfirmationShare => 'Share';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Thumbnail of the video you just published';

  @override
  String get userSearchNoResults => 'No users found';

  @override
  String get userPickerFilterByNameHint => 'Filter by name...';

  @override
  String get userPickerSearchByNameHint => 'Search by name...';

  @override
  String get userPickerClearSearchSemantics => 'Clear search';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name already added';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Select $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Remove $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Your crew is out there';

  @override
  String get userPickerEmptyFollowListBody =>
      'Follow people you vibe with. When they follow back, you can collab.';

  @override
  String get userPickerGoBack => 'Go back';

  @override
  String get userPickerTypeNameToSearch => 'Type a name to search';

  @override
  String get userPickerUnavailable =>
      'User search is unavailable. Please try again later.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Search failed. Please try again.';

  @override
  String get forgotPasswordTitle => 'Reset Password';

  @override
  String get forgotPasswordDescription =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get forgotPasswordEmailLabel => 'Email Address';

  @override
  String get forgotPasswordCancel => 'Cancel';

  @override
  String get forgotPasswordSendLink => 'Email Reset Link';

  @override
  String get ageVerificationContentWarning => 'Content Warning';

  @override
  String get ageVerificationTitle => 'Age Verification';

  @override
  String get ageVerificationAdultDescription =>
      'This content has been flagged as potentially containing adult material. You must be 18 or older to view it.';

  @override
  String get ageVerificationCreationDescription =>
      'To use the camera and create content, you must be at least 16 years old.';

  @override
  String get ageVerificationAdultQuestion =>
      'Are you 18 years of age or older?';

  @override
  String get ageVerificationCreationQuestion =>
      'Are you 16 years of age or older?';

  @override
  String get ageVerificationNo => 'No';

  @override
  String get ageVerificationYes => 'Yes';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profile';

  @override
  String get navMyProfile => 'My Profile';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navOpenCamera => 'Open camera';

  @override
  String get navExploreClassics => 'Classics';

  @override
  String get navExploreNewVideos => 'New Videos';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'For You';

  @override
  String get navExploreLists => 'Lists';

  @override
  String get routeErrorTitle => 'Error';

  @override
  String get routeInvalidHashtag => 'Invalid hashtag';

  @override
  String get routeInvalidConversationId => 'Invalid conversation ID';

  @override
  String get routeInvalidRequestId => 'Invalid request ID';

  @override
  String get routeInvalidListId => 'Invalid list ID';

  @override
  String get routeInvalidUserId => 'Invalid user ID';

  @override
  String get routeInvalidVideoId => 'Invalid video ID';

  @override
  String get routeInvalidSoundId => 'Invalid sound ID';

  @override
  String get routeInvalidCategory => 'Invalid category';

  @override
  String get routeNoVideosToDisplay => 'No videos to display';

  @override
  String get routeGoHome => 'Go home';

  @override
  String get routeInvalidProfileId => 'Invalid profile ID';

  @override
  String get routeUnknownPath => 'That page isn’t in the app.';

  @override
  String get routeDefaultListName => 'List';

  @override
  String get supportTitle => 'Support Center';

  @override
  String get supportContactSupport => 'Contact Support';

  @override
  String get supportContactSupportSubtitle =>
      'Start a conversation or view past messages';

  @override
  String get supportReportBug => 'Report a Bug';

  @override
  String get supportReportBugSubtitle => 'Technical issues with the app';

  @override
  String get supportRequestFeature => 'Request a Feature';

  @override
  String get supportRequestFeatureSubtitle =>
      'Suggest an improvement or new feature';

  @override
  String get supportSaveLogs => 'Save Logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Export logs to file for manual sending';

  @override
  String get supportClearLogs => 'Clear Logs';

  @override
  String get supportClearLogsSubtitle => 'Wipe captured logs and start fresh';

  @override
  String get supportClearLogsConfirmTitle => 'Clear captured logs?';

  @override
  String get supportClearLogsConfirmButton => 'Clear';

  @override
  String get supportLogsCleared => 'Logs cleared';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Common questions & answers';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Helping parents and teens build healthy habits online';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'How we handle accounts by age';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Learn about verification and authenticity';

  @override
  String get supportLoginRequired => 'Log in to contact support';

  @override
  String get supportExportingLogs => 'Exporting logs...';

  @override
  String get supportExportLogsFailed => 'Failed to export logs';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Logs saved to $path';
  }

  @override
  String get supportRevealLogsAction => 'Show in folder';

  @override
  String get supportChatNotAvailable => 'Support chat not available';

  @override
  String get supportCouldNotOpenMessages => 'Could not open support messages';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Could not open $pageName';
  }

  @override
  String get reportWhyReporting => 'Why are you reporting this content?';

  @override
  String get reportPolicyNotice =>
      'Divine will act on content reports within 24 hours by removing the content and ejecting the user who provided the offending content.';

  @override
  String get reportBlockUser => 'Block this user';

  @override
  String get reportCancel => 'Cancel';

  @override
  String get reportSubmit => 'Report';

  @override
  String get reportSelectReason =>
      'Please select a reason for reporting this content';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportDetailsTextOnly =>
      'Text only — photos and GIFs can’t be attached here.';

  @override
  String get reportDetailsImageNotAttached =>
      'That wasn’t attached. Reports are text only, so describe it in words.';

  @override
  String get bugReportImageInsertionRejected =>
      'That image wasn’t added. You can attach up to 3 images below.';

  @override
  String get featureRequestImageInsertionRejected =>
      'That image wasn’t attached. Describe it in words instead.';

  @override
  String get reportReasonSpam => 'Spam or Unwanted Content';

  @override
  String get reportReasonSpamSubtitle => 'Unwanted or repetitive content';

  @override
  String get reportReasonHarassment => 'Harassment, Bullying, or Threats';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Harmful and unwanted replies or mentions';

  @override
  String get reportReasonViolence => 'Violent or Extremist Content';

  @override
  String get reportReasonViolenceSubtitle =>
      'Violent, extremist, or harmful content';

  @override
  String get reportReasonSexualContent => 'Sexual or Adult Content';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nudity, porn, or explicit content';

  @override
  String get reportReasonCopyright => 'Copyright Violation';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Unauthorized use of intellectual property';

  @override
  String get reportReasonFalseInfo => 'False Information';

  @override
  String get reportReasonFalseInfoSubtitle => 'Misleading or false claims';

  @override
  String get reportReasonChildSafety => 'Child Safety Violation';

  @override
  String get reportReasonChildSafetySubtitle =>
      'General concerns about minors\' safety';

  @override
  String get reportReasonCsam => 'Child Sexual Abuse';

  @override
  String get reportReasonCsamSubtitle =>
      'Content depicting sexual abuse of minors';

  @override
  String get reportReasonUnderageUser => 'User Appears Under 16';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Account holder appears to be underage';

  @override
  String get reportReasonAiGenerated => 'AI-Generated Content';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Suspected AI-generated content';

  @override
  String get reportReasonOther => 'Other Policy Violation';

  @override
  String get reportReasonOtherSubtitle => 'Violations not listed above';

  @override
  String get reportFailed => 'Failed to report content. Please try again.';

  @override
  String get reportNotSent =>
      'Couldn\'t send your report. Check your connection and try again.';

  @override
  String get reportReceivedTitle => 'Report Received';

  @override
  String get reportReceivedThankYou =>
      'Thank you for helping keep Divine safe.';

  @override
  String get reportReceivedReviewNotice =>
      'Our team will review your report and take appropriate action. You may receive updates via direct message.';

  @override
  String get reportModerationDmDelayed =>
      'We couldn\'t reach the moderation team directly just now, but your report was received and will be reviewed.';

  @override
  String get reportContactModeration => 'Message the moderation team';

  @override
  String get reportLearnMoreAt => 'Learn more at';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Close';

  @override
  String get listAddToList => 'Add to List';

  @override
  String listVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'By ';

  @override
  String get listNewList => 'New List';

  @override
  String get listDone => 'Done';

  @override
  String get listErrorLoading => 'Error loading lists';

  @override
  String listRemovedFrom(String name) {
    return 'Removed from $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Added to $name';
  }

  @override
  String get listCreateNewList => 'Create New List';

  @override
  String get listNewPeopleList => 'New people list';

  @override
  String get listCollaboratorsNone => 'None';

  @override
  String get listAddCollaboratorTitle => 'Add a collaborator';

  @override
  String get listCollaboratorSearchHint => 'Search Divine...';

  @override
  String get listNameLabel => 'List Name';

  @override
  String get listDescriptionLabel => 'Description (optional)';

  @override
  String get listPublicList => 'Public List';

  @override
  String get listPublicListSubtitle => 'Others can follow and see this list';

  @override
  String get listPrivateListSubtitle =>
      'Videos stay private. Name, description, tags, and cover stay visible.';

  @override
  String get listVisibilityPublic => 'Public';

  @override
  String get listVisibilityPrivate => 'Private';

  @override
  String get profileListsEmpty =>
      'No lists yet. Make one for the loops you want to keep together.';

  @override
  String get listEditTitle => 'Edit list';

  @override
  String get listEditInfoAction => 'Edit list info';

  @override
  String get listManageVideosAction => 'Manage videos';

  @override
  String get listFollowButton => 'Follow';

  @override
  String get listFollowingButton => 'Following';

  @override
  String listRemoveVideosButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count videos',
      one: 'Remove video',
      zero: 'Remove video',
    );
    return '$_temp0';
  }

  @override
  String listRemoveVideosSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count videos',
      one: 'Removed 1 video',
    );
    return '$_temp0';
  }

  @override
  String listRemoveVideosFailure(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn\'t remove $count videos. Try again.',
      one: 'Couldn\'t remove 1 video. Try again.',
    );
    return '$_temp0';
  }

  @override
  String get listShareAction => 'Share list';

  @override
  String get listShareFailed => 'Couldn\'t share this list. Try again.';

  @override
  String get listSave => 'Save';

  @override
  String get listContinue => 'Continue';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => 'Couldn\'t update this list. Try again.';

  @override
  String get listMakePrivateTitle => 'Make this list private?';

  @override
  String get listMakePrivateWarning =>
      'Its videos get encrypted so only you can see them. The name, description, tags, and cover stay visible, and copies shared before now may persist.';

  @override
  String get listMakePublicTitle => 'Make this list public?';

  @override
  String get listMakePublicWarning =>
      'Anyone with the link can see this list and its videos.';

  @override
  String listShareText(String name, String url) {
    return 'Check out $name on Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name on Divine';
  }

  @override
  String get listCancel => 'Cancel';

  @override
  String get listCreate => 'Create';

  @override
  String get listCreateFailed => 'Failed to create list';

  @override
  String get keyManagementTitle => 'Nostr Keys';

  @override
  String get keyManagementWhatAreKeys => 'What are Nostr keys?';

  @override
  String get keyManagementExplanation =>
      'Your Nostr identity is a cryptographic key pair:\n\n• Your public key (npub) is like your username - share it freely\n• Your private key (nsec) is like your password - keep it secret!\n\nYour nsec lets you access your account on any Nostr app.';

  @override
  String get keyManagementImportTitle => 'Import Existing Key';

  @override
  String get keyManagementImportSubtitle =>
      'Already have a Nostr account? Paste your private key (nsec) to access it here.';

  @override
  String get keyManagementImportButton => 'Import Key';

  @override
  String get keyManagementImportWarning =>
      'This will replace your current key!';

  @override
  String get keyManagementBackupTitle => 'Backup Your Key';

  @override
  String get keyManagementBackupSubtitle =>
      'Save your private key (nsec) to use your account in other Nostr apps.';

  @override
  String get keyManagementCopyNsec => 'Copy My Private Key (nsec)';

  @override
  String get keyManagementNeverShare => 'Never share your nsec with anyone!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Your key lives on Divine\'s login service, not on this device. Confirm your password and we\'ll fetch it for you.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Your key is kept by Divine\'s login service. Enter your account password and we\'ll fetch it.';

  @override
  String get keyManagementKeycastCopyKey => 'Copy key';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Your device blocked the copy, so your key didn\'t reach the clipboard.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'That password doesn\'t match. Try again.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Too many tries. Close this and start over.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Too many key requests. Wait a few minutes and try again.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Your session has expired. Sign in again to copy your key.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Verify your email address before copying your key.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine looks after this account\'s keys, so they can\'t be copied here.';

  @override
  String get keyManagementKeycastNoKey =>
      'There\'s no key on record for this account.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Couldn\'t reach the login service. Please try again.';

  @override
  String get keyManagementRestrictedTitle => 'Your keys are managed by Divine';

  @override
  String get keyManagementRestrictedBody =>
      'To keep your account safe, key backup and importing a different key aren\'t available here.';

  @override
  String get keyManagementPasteKey => 'Please paste your private key';

  @override
  String get keyManagementInvalidFormat =>
      'Invalid key format. Must start with \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Import This Key?';

  @override
  String get keyManagementConfirmImportBody =>
      'This will replace your current identity with the imported one.\n\nYour current key will be lost unless you backed it up first.';

  @override
  String get keyManagementImportConfirm => 'Import';

  @override
  String get keyManagementImportSuccess => 'Key imported successfully!';

  @override
  String get keyManagementImportFailed =>
      'Failed to import key. Please try again.';

  @override
  String get keyManagementExportSuccess =>
      'Private key copied to clipboard!\n\nStore it somewhere safe.';

  @override
  String get keyManagementExportFailed =>
      'Failed to export key. Please try again.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Your public key (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copy public key';

  @override
  String get keyManagementPublicKeyCopied => 'Public key copied';

  @override
  String get saveOriginalSavedToCameraRoll => 'Saved to Camera Roll';

  @override
  String get saveOriginalShare => 'Share';

  @override
  String get saveOriginalDone => 'Done';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Photos Access Needed';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'To save videos, allow Photos access in Settings.';

  @override
  String get saveOriginalOpenSettings => 'Open Settings';

  @override
  String get saveOriginalNotNow => 'Not Now';

  @override
  String get saveOriginalDownloadFailed => 'Download Failed';

  @override
  String get saveOriginalDismiss => 'Dismiss';

  @override
  String get saveOriginalDownloadingVideo => 'Downloading Video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Saving to Camera Roll';

  @override
  String get saveOriginalFetchingVideo =>
      'Fetching the video from the network...';

  @override
  String get saveOriginalSavingVideo =>
      'Saving the original video to your camera roll...';

  @override
  String get soundTitle => 'Sound';

  @override
  String get soundOriginalSound => 'Original sound';

  @override
  String get soundVideosUsingThisSound => 'Videos using this sound';

  @override
  String get soundSourceVideo => 'Source video';

  @override
  String get soundNoVideosYet => 'No videos yet';

  @override
  String get soundBeFirstToUse => 'Be the first to use this sound!';

  @override
  String get soundFailedToLoadVideos => 'Failed to load videos';

  @override
  String get soundRetry => 'Retry';

  @override
  String get soundVideosUnavailable => 'Videos unavailable';

  @override
  String get soundCouldNotLoadDetails => 'Could not load video details';

  @override
  String get soundPreview => 'Preview';

  @override
  String get soundStop => 'Stop';

  @override
  String get soundUseSound => 'Use Sound';

  @override
  String get soundUntitled => 'Untitled sound';

  @override
  String get soundStopPreview => 'Stop preview';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Preview $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'View details for $title';
  }

  @override
  String get soundNoVideoCount => 'No videos yet';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String get soundUnableToPreview =>
      'Unable to preview sound - no audio available';

  @override
  String get soundPreviewFailed => 'Failed to play preview. Please try again.';

  @override
  String get soundViewSource => 'View source';

  @override
  String get soundCloseTooltip => 'Close';

  @override
  String get exploreNotExploreRoute => 'Not an explore route';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Terms of Service';

  @override
  String get legalTermsOfServiceSubtitle => 'Usage terms and conditions';

  @override
  String get legalPrivacyPolicy => 'Privacy Policy';

  @override
  String get legalPrivacyPolicySubtitle => 'How we handle your data';

  @override
  String get legalSafetyStandards => 'Safety Standards';

  @override
  String get legalSafetyStandardsSubtitle => 'Community guidelines and safety';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Copyright and takedown policy';

  @override
  String get legalOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Third-party package attributions';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Could not open $pageName';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Adventure';

  @override
  String get categoryAnimals => 'Animals';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Architecture';

  @override
  String get categoryArt => 'Art';

  @override
  String get categoryAutomotive => 'Automotive';

  @override
  String get categoryAwardShow => 'Award Show';

  @override
  String get categoryAwards => 'Awards';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basketball';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryBeverage => 'Beverage';

  @override
  String get categoryCars => 'Cars';

  @override
  String get categoryCelebration => 'Celebration';

  @override
  String get categoryCelebrities => 'Celebrities';

  @override
  String get categoryCelebrity => 'Celebrity';

  @override
  String get categoryCityscape => 'Cityscape';

  @override
  String get categoryComedy => 'Comedy';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryCooking => 'Cooking';

  @override
  String get categoryCostume => 'Costume';

  @override
  String get categoryCrafts => 'Crafts';

  @override
  String get categoryCrime => 'Crime';

  @override
  String get categoryCulture => 'Culture';

  @override
  String get categoryDance => 'Dance';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryEmotional => 'Emotional';

  @override
  String get categoryEmotions => 'Emotions';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryFamily => 'Family';

  @override
  String get categoryFans => 'Fans';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Style';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Furniture';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Grooming';

  @override
  String get categoryGuitar => 'Guitar';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Holiday';

  @override
  String get categoryHome => 'Home';

  @override
  String get categoryHomeImprovement => 'Home Improvement';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Hospital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Interior Design';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Kids';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magic';

  @override
  String get categoryMakeup => 'Makeup';

  @override
  String get categoryMedical => 'Medical';

  @override
  String get categoryMusic => 'Music';

  @override
  String get categoryMystery => 'Mystery';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryNews => 'News';

  @override
  String get categoryOutdoor => 'Outdoor';

  @override
  String get categoryParty => 'Party';

  @override
  String get categoryPeople => 'People';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Pets';

  @override
  String get categoryPolitics => 'Politics';

  @override
  String get categoryPrank => 'Prank';

  @override
  String get categoryPranks => 'Pranks';

  @override
  String get categoryRealityShow => 'Reality Show';

  @override
  String get categoryRelationship => 'Relationship';

  @override
  String get categoryRelationships => 'Relationships';

  @override
  String get categoryRomance => 'Romance';

  @override
  String get categorySchool => 'School';

  @override
  String get categoryScienceFiction => 'Science Fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Skincare';

  @override
  String get categorySoccer => 'Soccer';

  @override
  String get categorySocialGathering => 'Social Gathering';

  @override
  String get categorySocialMedia => 'Social Media';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryTalkShow => 'Talk Show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technology';

  @override
  String get categoryTelevision => 'Television';

  @override
  String get categoryToys => 'Toys';

  @override
  String get categoryTransportation => 'Transportation';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Violence';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadStaged => 'Uploaded — tap Save to apply';

  @override
  String inboxReportedUser(String displayName) {
    return 'Reported $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Blocked $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Unblocked $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Removed conversation';

  @override
  String get inboxRestorePausedTitle =>
      'Some chats haven\'t finished restoring';

  @override
  String get conversationRestorePausedTitle =>
      'This chat hasn\'t finished restoring';

  @override
  String get inboxRestoreRetryAction => 'Retry';

  @override
  String get inboxRestoringMessages => 'Restoring your messages…';

  @override
  String get inboxEmptyTitle => 'No messages yet';

  @override
  String get inboxEmptySubtitle => 'That + button won\'t bite.';

  @override
  String get inboxLoadErrorTitle => 'Messages didn\'t load';

  @override
  String get inboxLoadErrorSubtitle =>
      'Check your connection and give it another go.';

  @override
  String get inboxFilterAll => 'All';

  @override
  String get inboxFilterUnread => 'Unread';

  @override
  String get dmBlockedThreadTitle => 'You blocked this account';

  @override
  String get dmBlockedThreadBody =>
      'Messages stay here so you can read or screenshot them. Unblock to reply.';

  @override
  String get inboxFilterBlocked => 'Blocked';

  @override
  String get inboxBlockedEmptyTitle => 'No blocked chats';

  @override
  String get inboxBlockedEmptySubtitle => 'Accounts you block show up here.';

  @override
  String get inboxBlockedNoMessages => 'No messages';

  @override
  String get inboxUnreadEmptyTitle => 'You\'re all caught up';

  @override
  String get inboxUnreadEmptySubtitle => 'No unread messages right now.';

  @override
  String get inboxSearchHint => 'Search messages';

  @override
  String get inboxSupportRowTitle => 'Divine Moderation';

  @override
  String get inboxSupportRowSubtitle =>
      'Bugs, moderation, account stuff — we\'re listening.';

  @override
  String get inboxSearchEmptyTitle => 'No matches';

  @override
  String get inboxSearchEmptySubtitle => 'Try a different name or word.';

  @override
  String get inboxActionMute => 'Mute conversation';

  @override
  String inboxActionReport(String displayName) {
    return 'Report $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Block $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Unblock $displayName';
  }

  @override
  String get inboxActionRemove => 'Remove conversation';

  @override
  String get inboxRemoveConfirmTitle => 'Remove conversation?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'This removes your conversation with $displayName from your inbox. If they message you again, a new conversation starts.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'This removes the group conversation from your inbox. If anyone messages the group again, a new conversation starts.';

  @override
  String get inboxRemoveConfirmConfirm => 'Remove';

  @override
  String get inboxConversationMuted => 'Conversation muted';

  @override
  String get inboxConversationUnmuted => 'Conversation unmuted';

  @override
  String get inboxCollabInviteCardTitle => 'Collaborator invite';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Untitled video';

  @override
  String get clickableTextViewVideoLink => 'View video';

  @override
  String get messageExternalLinkDialogTitle => 'Open external link?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'This link goes to an external site and may not be safe:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Open';

  @override
  String get inboxCollabInviteCoPostButton => 'Co-post';

  @override
  String get inboxCollabInviteNotMineButton => 'Not mine';

  @override
  String get inboxCollabInvitePreviewTitle => 'Co-post invite';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Co-post invite from $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Co-posting adds this video to your timeline as a collaboration.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Accepted';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignored';

  @override
  String get inboxCollabInviteAcceptError => 'Could not accept. Try again.';

  @override
  String get inboxCollabInviteSentStatus => 'Invitation sent';

  @override
  String get inboxConversationCollabInvitePreview => 'Collaborator invite';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'You were invited to collaborate on $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'You were invited to collaborate on a video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites did not send.',
      one: '1 collaborator invite did not send.',
    );
    return 'Video posted, but $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'We couldn\'t tell who this thread is with. Open it again from your inbox.';

  @override
  String get dmSendBlockedMessage =>
      'You can only message official Divine accounts';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Nobody is reading this conversation. Message Divine Moderation instead.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Couldn\'t delete for everyone.';

  @override
  String get dmDeleteRefusedDetails =>
      'Some people may still be able to see this message.';

  @override
  String get dmRetiredThreadClosedTitle => 'This conversation is closed.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'This Divine Moderation notice can\'t be removed.';

  @override
  String get dmRetiredThreadClosedBody =>
      'We moved Divine Moderation to a new account. Nobody reads this one anymore.';

  @override
  String get dmRetiredThreadOpenSupport => 'Message Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Message couldn\'t be sent';

  @override
  String get dmResendFailedMessage => 'Still couldn\'t send';

  @override
  String get dmSendFailedSubtitle => 'Resend it now, or stop trying.';

  @override
  String get dmSendFailedRetry => 'Retry';

  @override
  String get dmSendPartialMessage =>
      'Sent, but didn\'t sync to your other devices';

  @override
  String get dmConversationLoadError => 'Could not load messages';

  @override
  String get dmMessageInputHint => 'Say something…';

  @override
  String get dmMessageBubbleSentHint => 'Sent message';

  @override
  String get dmMessageBubbleReceivedHint => 'Received message';

  @override
  String get dmMessageBubbleLongPressHint => 'Message actions';

  @override
  String get dmMessageBubbleFailedTapHint => 'Resend or delete this message';

  @override
  String get dmMessageActionCopyText => 'Copy text';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copy video URL';

  @override
  String get dmMessageActionDeleteForEveryone => 'Delete for everyone';

  @override
  String get dmMessageActionReport => 'Report';

  @override
  String get dmMessageActionRetrySend => 'Resend';

  @override
  String get dmMessageActionCancelSend => 'Stop trying';

  @override
  String get dmReactionAddCustomA11yLabel => 'Add custom emoji reaction';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Message $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Reply to yourself…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Reply to this reel';

  @override
  String get dmReelReplyViewChat => 'View chat';

  @override
  String get dmReelReplySentAnnouncement => 'Reply sent';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Reacted $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Couldn\'t send';

  @override
  String get dmReelReplyUnverified => 'Couldn\'t confirm that sent';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Your reaction: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name reacted with $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Sending reaction: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reaction failed, double tap to retry';

  @override
  String get dmReactionChipRetryAnnouncement => 'Retrying reaction';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Finish removing your previous reaction before adding another.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reactions';

  @override
  String get dmReactionsViewA11yLabel => 'See who reacted';

  @override
  String get dmReactionRemoveAction => 'Remove';

  @override
  String get dmReactionRetryAction => 'Retry';

  @override
  String get dmFormatBold => 'Bold';

  @override
  String get dmFormatItalic => 'Italic';

  @override
  String get dmFormatStrikethrough => 'Strikethrough';

  @override
  String get dmFormatCode => 'Code';

  @override
  String get dmStatusFailed => 'Failed to send';

  @override
  String get inboxConversationActionsSheetLabel => 'Conversation actions';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayName conversation';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Unread, $displayName conversation';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count others',
      one: '$count other',
    );
    return '$name and $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Show conversation actions';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Title: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Search...';

  @override
  String categoryVideoCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Failed to update subscription. Please try again.';

  @override
  String get discoverListsTitle => 'Discover Lists';

  @override
  String get discoverListsFailedToLoad => 'Failed to load lists';

  @override
  String get discoverListsLoading => 'Discovering public lists...';

  @override
  String get discoverListsRelayTimeout =>
      'The relay did not return lists in time. Try again.';

  @override
  String get discoverListsServiceUnavailable => 'Service not available.';

  @override
  String get discoverListsEmptyTitle => 'No public lists found';

  @override
  String get discoverListsEmptySubtitle => 'Check back later for new lists';

  @override
  String get discoverListsByAuthorPrefix => 'by';

  @override
  String get curatedListEmptyTitle => 'No videos in this list';

  @override
  String get curatedListEmptySubtitle => 'Add some videos to get started';

  @override
  String get curatedListLoadingVideos => 'Loading videos...';

  @override
  String get curatedListFailedToLoad => 'Failed to load list';

  @override
  String get curatedListVideoNotAvailable => 'Video not available';

  @override
  String get curatedListActionsTooltip => 'List actions';

  @override
  String get curatedListDeleteConfirmTitle => 'Delete list?';

  @override
  String get curatedListDeleteConfirmBody =>
      'This removes the list from relays. Videos in the list will not be deleted.';

  @override
  String get curatedListDeletedSnack => 'Deleted list';

  @override
  String get curatedListDeleteFailed => 'Couldn\'t delete list';

  @override
  String get peopleListsActionsTooltip => 'List actions';

  @override
  String get listDeleteAction => 'Delete list';

  @override
  String get peopleListsDeleteConfirmTitle => 'Delete list?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'This removes the list for everyone. The people in it will not be unfollowed.';

  @override
  String get peopleListsDeleteFailed => 'Couldn\'t delete list';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonLoading => 'Loading';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Couldn\'t update the cover. Try again.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Cover updated';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Post without the human-made check?';

  @override
  String get videoMetadataC2paMissingBody =>
      'We couldn\'t add content credentials, so this video won\'t be confirmed as Human-Made. Regenerate to try again, or post it as-is.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Content credentials need an internet connection.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'The content credential service didn\'t respond. This isn\'t your connection.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Regenerate';

  @override
  String get videoMetadataC2paMissingSkip => 'Skip';

  @override
  String get videoMetadataGenerationFailed => 'Generation failed';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Expiration';

  @override
  String get videoMetadataExpirationNotExpire => 'Does not expire';

  @override
  String get videoMetadataExpirationOneDay => '1 day';

  @override
  String get videoMetadataExpirationOneWeek => '1 week';

  @override
  String get videoMetadataExpirationOneMonth => '1 month';

  @override
  String get videoMetadataExpirationOneYear => '1 year';

  @override
  String get videoMetadataExpirationOneDecade => '1 decade';

  @override
  String get videoMetadataContentWarnings => 'Content Warnings';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Trending';

  @override
  String get libraryDeleteConfirm => 'Delete';

  @override
  String get libraryWebUnavailableHeadline =>
      'Library is available in the mobile app';

  @override
  String get libraryWebUnavailableDescription =>
      'Drafts and clips are saved on your device, so open Divine on your phone to manage them.';

  @override
  String get libraryTabDrafts => 'Drafts';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Delete selected clips';

  @override
  String get libraryCloseSemanticLabel => 'Close library';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Stop selecting clips';

  @override
  String get librarySelectClipsSemanticLabel => 'Select clips';

  @override
  String get libraryGridSizeLabel => 'Grid size';

  @override
  String get libraryDisplayOptionsLabel => 'Sort & grid size';

  @override
  String get libraryMoreActionsSemanticLabel => 'More library actions';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count columns',
      one: '1 column',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Select';

  @override
  String get librarySortNewestCreation => 'Newest Creation';

  @override
  String get librarySortOldestCreation => 'Oldest Creation';

  @override
  String get librarySortLongestClip => 'Longest Clip';

  @override
  String get librarySortShortestClip => 'Shortest Clip';

  @override
  String get librarySortSquareFirst => 'Square First';

  @override
  String get librarySortVerticalFirst => 'Vertical First';

  @override
  String get libraryDeleteClipsWarning =>
      'This action cannot be undone. The video files will be permanently removed from your device.';

  @override
  String get libraryPreparingVideo => 'Preparing video...';

  @override
  String libraryCreateVideo(int count) {
    return 'Create Video ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return '$_temp0 saved to $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount saved, $failureCount failed';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Couldn\'t save to $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination permission denied';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips deleted',
      one: '1 clip deleted',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Undo';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Auto-deletes in $daysLeft days',
      one: 'Auto-deletes tomorrow',
      zero: 'Auto-deletes today',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Couldn\'t load drafts';

  @override
  String get libraryCouldNotLoadClips => 'Couldn\'t load clips';

  @override
  String get libraryOpenErrorDescription =>
      'Something went wrong while opening your library. You can try again.';

  @override
  String get libraryNoDraftsYetTitle => 'No Drafts Yet';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Videos you save as draft will appear here';

  @override
  String get libraryNoClipsYetTitle => 'No Clips Yet';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Your recorded video clips will appear here';

  @override
  String get libraryDraftDeletedSnackbar => 'Draft deleted';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Failed to delete draft';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Draft duplicated';

  @override
  String get libraryDraftDuplicateFailedSnackbar => 'Failed to duplicate draft';

  @override
  String get libraryDraftInProgressBadge => 'In progress';

  @override
  String get libraryDraftActionPost => 'Post';

  @override
  String get libraryDraftActionEdit => 'Edit';

  @override
  String get libraryDraftActionDuplicate => 'Duplicate';

  @override
  String get libraryDraftActionDelete => 'Delete draft';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (copy $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Delete Draft';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Delete Clip';

  @override
  String get libraryDeleteClipMessage =>
      'Are you sure you want to delete this clip?';

  @override
  String libraryClipDuration(String seconds) {
    return '${seconds}s';
  }

  @override
  String get libraryRecordVideo => 'Record a Video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Video clip, $duration seconds';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Archived. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Stop-motion clip, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Selected, number $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Selected';

  @override
  String get videoClipSemanticValueNotSelected => 'Not selected';

  @override
  String get videoClipSemanticHintDisabled => 'Disabled';

  @override
  String get videoClipSemanticHintSelect =>
      'Tap to select, long press to preview';

  @override
  String get videoClipSemanticHintDeselect =>
      'Tap to deselect, long press to preview';

  @override
  String get routerInvalidCreator => 'Invalid creator';

  @override
  String get routerInvalidHashtagRoute => 'Invalid hashtag route';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Could not load videos';

  @override
  String get categoryGalleryNoVideosInCategory => 'No videos in this category';

  @override
  String get categoryGallerySortOptionsLabel => 'Category sort options';

  @override
  String get categoryGallerySortHot => 'Hot';

  @override
  String get categoryGallerySortNew => 'New';

  @override
  String get categoryGallerySortClassic => 'Classic';

  @override
  String get categoryGallerySortForYou => 'For You';

  @override
  String get categoriesCouldNotLoadCategories => 'Could not load categories';

  @override
  String get categoriesNoCategoriesAvailable => 'No categories available';

  @override
  String get notificationsEmptyTitle => 'No activity yet';

  @override
  String get notificationsEmptySubtitle =>
      'When people interact with your content, you\'ll see it here';

  @override
  String get appsPermissionsTitle => 'Integration Permissions';

  @override
  String get appsPermissionsRevoke => 'Revoke';

  @override
  String get appsPermissionsEmptyTitle => 'No saved integration permissions';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Approved integrations will appear here after you remember an access approval.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName wants your approval';
  }

  @override
  String get nostrAppPermissionDescription =>
      'This app is requesting access through Divine\'s vetted sandbox.';

  @override
  String get nostrAppPermissionOrigin => 'Origin';

  @override
  String get nostrAppPermissionMethod => 'Method';

  @override
  String get nostrAppPermissionCapability => 'Capability';

  @override
  String get nostrAppPermissionEventKind => 'Event kind';

  @override
  String get nostrAppPermissionAllow => 'Allow';

  @override
  String get appsDetailDefaultTitle => 'Integrated App';

  @override
  String get appsDetailNotFoundTitle => 'Integration not found';

  @override
  String get appsDetailNotFoundSubtitle =>
      'This approved integration is no longer available in Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'How it works';

  @override
  String get appsDetailHowItWorksBody =>
      'This is an approved third-party app that runs inside Divine. Divine only grants reviewed capabilities for this integration, and blocks navigation outside its approved origins.';

  @override
  String get appsDetailAboutTitle => 'About';

  @override
  String get appsDetailPrimaryOriginTitle => 'Primary origin';

  @override
  String get appsDetailApprovedOriginsTitle => 'Approved origins';

  @override
  String get appsDetailCapabilitiesTitle => 'Available capabilities';

  @override
  String get appsDetailAskBeforeTitle => 'Ask before';

  @override
  String get appsDetailOpenButton => 'Open Integration';

  @override
  String get appsDetailNoneDeclared => 'None declared yet';

  @override
  String get appsDirectoryTitle => 'Integrated Apps';

  @override
  String get appsDirectoryIntroTitle => 'Approved third-party apps';

  @override
  String get appsDirectoryIntroBody =>
      'Approved third-party apps that run inside Divine';

  @override
  String get appsDirectoryErrorTitle => 'Could not load integrated apps';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Pull to try the approved integrations again.';

  @override
  String get appsDirectoryEmptyTitle => 'No approved integrations yet';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Approved third-party apps will appear here as Divine adds them.';

  @override
  String get appsDirectoryRefresh => 'Refresh';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Integrated Apps run in Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Approved integrations are only available on mobile for now.';

  @override
  String get appsSandboxUnavailableTitle => 'Integration unavailable';

  @override
  String get appsSandboxUnavailableBody =>
      'Open approved integrations from the Integrated Apps tab so Divine can apply the right access policy.';

  @override
  String get appsSandboxLoadingTitle => 'Loading integration';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Checking the approved integration before launch.';

  @override
  String get appsSandboxBlockedTitle => 'Blocked for safety';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'This integration tried to leave its approved origin.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Link to post copied to clipboard';

  @override
  String get shareCopiedEventJson => 'Nostr event JSON copied to clipboard';

  @override
  String get shareCopiedEventId => 'Nostr event ID copied to clipboard';

  @override
  String get authHeroTaglineAuthentic => 'Authentic moments.';

  @override
  String get authHeroTaglineHuman => 'Human creativity.';

  @override
  String get keyImportFailedToImport =>
      'Failed to import key or connect bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'Invalid bunker URL';

  @override
  String get keyImportInvalidFormat =>
      'Invalid format. Use nsec..., hex, ncryptsec1..., or bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Invalid nsec format. Should be 63 characters';

  @override
  String get keyImportKeyFieldLabel => 'Private key or bunker URL';

  @override
  String get keyImportKeyRequired =>
      'Please enter your private key or bunker URL';

  @override
  String get keyImportPasswordRequired =>
      'Please enter the password for this encrypted key';

  @override
  String get keyImportSecurityWarningBody =>
      'Never share your private key with anyone. This key gives full access to your Nostr identity.';

  @override
  String get keyImportSecurityWarningTitle => 'Keep your private key secure!';

  @override
  String get keyImportSubtitle =>
      'Import your existing Nostr identity using your private key or a bunker URL.';

  @override
  String get keyImportTitle => 'Import your\nNostr identity';

  @override
  String get commentAuthorYouIndicator => 'You';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'View $name\'s profile';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Delete comment';

  @override
  String get commentOptionsEditSemanticLabel => 'Edit comment';

  @override
  String get commentOptionsFlagContentLabel => 'Flag Content';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Flag this content';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Select a reason for flagging this comment';

  @override
  String get commentOptionsFlagSubmit => 'Submit';

  @override
  String get commentOptionsTitle => 'Options';

  @override
  String get commentsEmptyClassicVineMessage =>
      'We\'re still working on importing old comments from the archive. They\'re not ready yet.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Editing';

  @override
  String get commentsInputSemanticHint => 'Add a comment';

  @override
  String get commentsInputSemanticHintEdit => 'Edit comment';

  @override
  String get commentsInputSemanticHintReply => 'Add a reply';

  @override
  String get commentsInputSemanticLabel => 'Comment input';

  @override
  String get commentsInputSemanticLabelEdit => 'Edit input';

  @override
  String get commentsInputSemanticLabelReply => 'Reply input';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'View profile for $displayName';
  }

  @override
  String get classicsEmptyDescription => 'The Classics archive is being loaded';

  @override
  String get classicsEmptyTitle => 'No Classics Found';

  @override
  String get classicsErrorTitle => 'Failed to load Classics';

  @override
  String get classicsUnavailableDescription =>
      'Classics are only available when connected to Funnelcake relays.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Switch to a Funnelcake-enabled relay in Settings to access the Classics archive.';

  @override
  String get classicsUnavailableTitle => 'Classics Unavailable';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Be the first to post a video with this hashtag!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'No videos found for #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'This may take a few moments';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Loading videos about #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Add hashtags... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'Check back later for new content';

  @override
  String get newVideosTabEmptyTitle => 'No videos in New Videos';

  @override
  String get popularVideosContextTitle => 'Popular Videos';

  @override
  String get popularVideosEmptySubtitle => 'Check back later for new content';

  @override
  String get popularVideosEmptyTitle => 'No videos in Popular Videos';

  @override
  String get popularVideosErrorTitle => 'Failed to load trending videos';

  @override
  String get popularVideosFeedSourceLabel => 'Popular feed source';

  @override
  String get trendingHashtagsLoading => 'Loading hashtags...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'View videos tagged $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Video author: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Video description: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine\'s vision is to give you true algorithmic choice. Instead of being locked into a single black-box algorithm, you\'ll be able to choose from multiple recommendation approaches:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Chronological timeline from creators you follow';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'This puts you in control of your attention rather than leaving it up to the platform. You should know how your feed is curated and have the power to change it whenever you want.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Community-created custom feeds for topics like music, comedy, or art';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Personalized \"For You\" feed';

  @override
  String get forYouAlgorithmChoiceTitle => 'Your Algorithm, Your Choice';

  @override
  String get forYouAlgorithmChoiceTrending => 'Trending and popular content';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Strong signal — you were engaged enough to respond';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine pays attention to how you interact with content to understand what you enjoy. Every time you watch a video, give it a reaction, leave a comment, or repost it, the system takes note.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'How It Works';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Different actions signal different levels of interest:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'If you haven\'t built up a viewing history yet, we show a mix of what\'s currently popular and trending alongside recent uploads. This gives you a great starting point to explore.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'As you watch, like, and engage with content, recommendations gradually become more personalized. Over time, your For You feed surfaces videos from creators you might never have discovered on your own.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'New to Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'We\'re building an open system where developers can implement their own algorithms, and you can choose which ones to use — or opt out entirely.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open Source & Transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Medium signal — a quick way to show appreciation';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reactions';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Strongest signal — sharing with your followers is a powerful endorsement';

  @override
  String get forYouAlgorithmSubtitle =>
      'Powered by Gorse, an open-source recommendation engine';

  @override
  String get forYouAlgorithmTitle => 'The Divine Algorithm';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Light signal — indicates basic interest';

  @override
  String get forYouEmptyDescription =>
      'Watch and like some videos to get personalized recommendations.';

  @override
  String get forYouEmptyTitle => 'No Recommendations Yet';

  @override
  String get forYouErrorTitle => 'Failed to load recommendations';

  @override
  String get forYouUnavailableDescription =>
      'Personalized recommendations require connection to Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'For You Unavailable';

  @override
  String get inboxConversationOptionsLabel => 'Options';

  @override
  String get inboxConversationViewProfileButton => 'View profile';

  @override
  String get inboxMessageRequestsEmpty => 'No message requests';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Message requests, $requestCount pending';
  }

  @override
  String get inboxMessageRequestsTitle => 'Message requests';

  @override
  String get inboxMessagesTab => 'Messages';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayName message request';
  }

  @override
  String get inboxRequestTileSubtitle => 'Sent a message request';

  @override
  String get inboxRequestsMarkAllRead => 'Mark all requests as read';

  @override
  String get inboxRequestsRemoveAll => 'Remove all requests';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Decline and remove';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Declined $displayName\'s request';
  }

  @override
  String get messageRequestLoadFailed => 'Couldn\'t load this request.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$count Followers',
      one: '$count Follower',
    );
    return '$_temp0';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$count videos',
      one: '$count video',
    );
    return '$_temp0';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'View messages';

  @override
  String get messageRequestViewProfileButton => 'View profile';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName wants to message you, they\'ve sent $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'You switched accounts, so nothing was deleted. Reopen delete for the account you want to remove.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'To confirm, type:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'To confirm, type your username:';

  @override
  String get deleteAccountConfirmationHint => 'Type DELETE';

  @override
  String get deleteAccountConfirmationHintUsername => 'Type your username';

  @override
  String get deleteAccountDeleteAllContentButton => 'Delete All Content';

  @override
  String get accountDeletionRecoveryTitle => 'Deleting your account';

  @override
  String get accountDeletionRecoveryBody =>
      'We couldn\'t finish deleting your account. Your username is reserved for you and can still be restored.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Restore my username';

  @override
  String get accountDeletionFinishingBody =>
      'Your deletion request is still being processed. You can use another account while we finish.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Another account deletion is still being processed on this device. Wait for it to finish before deleting this account.';

  @override
  String get accountDeletionCancellingBody =>
      'We\'re cancelling your deletion. Check again before leaving this screen.';

  @override
  String get accountDeletionRecoveryFailed =>
      'We couldn\'t restore your username yet. Check your connection and try again.';

  @override
  String get accountDeletionUsernameRestored =>
      'Your username is restored. Your account was not deleted.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'We couldn\'t check your deletion status. Check your connection and try again.';

  @override
  String get accountDeletionCancelAttemptBody =>
      'We couldn\'t finish deleting your account. You can cancel this attempt and keep your account.';

  @override
  String get accountDeletionCancelAttempt => 'Keep my account';

  @override
  String get accountDeletionAttemptCancelled =>
      'Account deletion cancelled. Your account was not deleted.';

  @override
  String get accountDeletionTerminalFailureBody =>
      'We couldn\'t delete your account. Contact support for help or sign out to leave this screen.';

  @override
  String get accountDeletionSignOut => 'Sign out';

  @override
  String get deleteAccountDeletionUnavailable =>
      'Account deletion isn\'t available right now. Nothing was deleted.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'We couldn\'t finish deleting your account. Try again.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Final Confirmation';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Deletion requests sent, but your keys may not have been fully removed from this device. Go to Settings → Nostr Keys → Remove Keys to retry.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Deletion requests sent and you\'re signed out, but some local data could not be removed from this device.';

  @override
  String get deleteAccountPreparingDeletion => 'Preparing deletion...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total events';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'This removes the local login for this account from this device. It won\'t delete your Divine account or Nostr identity.\n\nYour drafts and clips stay saved on this device for this account. If this is your last local account, you\'ll return to the login screen.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Remove from device';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Remove this account from this device?';

  @override
  String get deleteAccountReauthRequired =>
      'Sign in again to delete your account. Nothing has been deleted yet.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Deletion requests sent for your posts, but we couldn\'t finish deleting your account. Try again in a bit.';

  @override
  String get deleteAccountSuccess =>
      'Your Divine account was deleted. Deletion requests were sent for your Nostr posts, but some relays, clients, or caches may keep copies.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Account deletion requested. Some existing posts could not be individually confirmed for deletion.';

  @override
  String get deleteAccountWarningBody =>
      'This sends deletion requests for your account and content, deletes your Divine account when possible, and signs you out on this device. Some relays, clients, and search indexes may keep copies. Other signed-in devices stay active until you remove the keys there.';

  @override
  String get findPeopleNoContacts =>
      'No contacts found.\nStart following people to see them here.';

  @override
  String get geoBlockedCityLabel => 'City';

  @override
  String get geoBlockedCountryLabel => 'Country';

  @override
  String get geoBlockedDefaultReason =>
      'This service is not available in your region due to local regulations.';

  @override
  String get geoBlockedLegalNotice =>
      'We respect your local laws and regulations. This restriction is based on your IP address location.';

  @override
  String get geoBlockedRegionLabel => 'Region';

  @override
  String get geoBlockedTitle => 'Service Unavailable';

  @override
  String get likedVideosEmpty => 'No liked videos';

  @override
  String get likedVideosInvalidRoute => 'Invalid route';

  @override
  String get likedVideosTitle => 'Liked Videos';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Retrying upload…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Save to Drafts';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Saved to drafts';

  @override
  String get uploadFailureSheetTitle => 'Upload Failed';

  @override
  String get uploadFailureSheetTryAgainButton => 'Try Again';

  @override
  String get videoEditorAudioImportAudio => 'Import audio';

  @override
  String get videoEditorAudioImportFailed => 'Audio import failed.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn => 'Please sign in to publish videos.';

  @override
  String get publishErrorNoRetry => 'No upload to retry.';

  @override
  String get publishErrorNoInternet =>
      'No internet connection. Check your Wi-Fi or mobile data and try again.';

  @override
  String get publishErrorServerUnreachable =>
      'Could not reach the server. Please try again in a moment.';

  @override
  String get publishErrorTimeout =>
      'The upload timed out. Try a stronger connection or a smaller video.';

  @override
  String get publishErrorTls =>
      'Secure connection failed. Check your network — public Wi-Fi can block uploads.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'The media server ($serverName) is not available. You can choose another in your settings.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'The video file is too large for the server. Try trimming it or lowering the quality.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'The media server ($serverName) had an internal error. You can choose another in your settings.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'The media server ($serverName) is temporarily down. Try again shortly or choose another in your settings.';
  }

  @override
  String get publishErrorForbidden =>
      'You don’t have permission to upload to this server.';

  @override
  String get publishErrorFileNotFound =>
      'The video file could not be found. It may have been deleted. Re-record and try again.';

  @override
  String get publishErrorLowStorage =>
      'Not enough storage on your device. Free up some space and try again.';

  @override
  String get publishErrorThumbnailFailed =>
      'The video uploaded, but the thumbnail could not be prepared. Please try again.';

  @override
  String get publishErrorNostrPublishFailed =>
      'The video uploaded but the post could not be published. Check your relay settings and try again.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'The video uploaded, but its sound isn\'t cleared for reuse. Pick a different sound to post it.';

  @override
  String get publishErrorInterrupted =>
      'This upload was interrupted. Would you like to try again?';

  @override
  String get publishErrorAccountChanged =>
      'This video belongs to a different account. Switch back to that account to post it.';

  @override
  String get publishErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get publishErrorRateLimited =>
      'Too many uploads right now. Wait a moment and try again.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Your upload session expired. Please try again.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine doesn’t have permission to upload. Check app permissions in your settings and try again.';

  @override
  String get publishErrorOutOfMemory =>
      'Your device is low on memory. Close some apps and try again.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'The text and stickers on this draft couldn’t be prepared. Open it in the editor, then post again.';

  @override
  String get publishErrorUnknownServer => 'Unknown server';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'No results found for \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'View videos tagged $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Sound: $soundName by $creatorName. Tap to view sound details.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Original sound by $creatorName. Tap to use this sound.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Sound: $soundName by $creatorName. Tap to view details.';
  }

  @override
  String get soundDetailLoadError => 'Failed to load sound. Please try again.';

  @override
  String get soundDetailNotFoundMessage => 'This sound could not be found';

  @override
  String get soundDetailNotFoundTitle => 'Sound Not Found';

  @override
  String videoFeedLoopCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔁 $count loops',
      one: '🔁 $count loop',
    );
    return '$_temp0';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Audio from this video is not available separately.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Original sound - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'This person posted an original Vine that Divine found in the archive. It is not an account verification badge.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Profile checkmark';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine gives this checkmark to team accounts. It is separate from NIP-05, verified account links, and OG Viner status.';

  @override
  String get unfollowConfirmButton => 'Unfollow';

  @override
  String get videoClipSaveFailed => 'Failed to save clip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Save to $destination';
  }

  @override
  String get videoClipDelete => 'Delete clip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspired by $creatorName +$additionalCreatorCount. Tap to view their profile.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspired by $creatorName. Tap to view their profile.';
  }

  @override
  String get bugReportSendReport => 'Send Report';

  @override
  String get supportSubjectRequiredLabel => 'Subject *';

  @override
  String get supportPublicSubmissionTitle => 'Public GitHub post';

  @override
  String get supportPublicSubmissionMessage =>
      'Everything you submit here will be posted to our open-source repository on GitHub so developers can pick it up. Your post and the account you\'re signed in with will be publicly visible to everyone.';

  @override
  String get supportRequiredHelper => 'Required';

  @override
  String get supportFieldLimitReached =>
      'That\'s the maximum length. Anything past this wasn\'t added.';

  @override
  String get bugReportSubjectHint => 'Brief summary of the issue';

  @override
  String get bugReportDescriptionRequiredLabel => 'What happened? *';

  @override
  String get bugReportDescriptionHint => 'Describe the issue you encountered';

  @override
  String get bugReportStepsLabel => 'Steps to Reproduce';

  @override
  String get bugReportStepsHint => '1. Go to...\n2. Tap on...\n3. See error';

  @override
  String get bugReportExpectedBehaviorLabel => 'Expected Behavior';

  @override
  String get bugReportExpectedBehaviorHint =>
      'What should have happened instead?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Device info and logs will be included automatically.';

  @override
  String get bugReportSuccessMessage =>
      'Thank you! We\'ve received your report and will use it to make Divine better.';

  @override
  String get bugReportAttachImages => 'Attach images';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count of $max images selected';
  }

  @override
  String get bugReportRemoveImage => 'Remove image';

  @override
  String get bugReportUploadFailed =>
      'We couldn\'t upload the selected image. Try again or send the report without it.';

  @override
  String get bugReportSendFailed =>
      'Failed to send bug report. Please try again later.';

  @override
  String get featureRequestSendRequest => 'Send Request';

  @override
  String get featureRequestSubjectHint => 'Brief summary of your idea';

  @override
  String get featureRequestDescriptionRequiredLabel => 'What would you like? *';

  @override
  String get featureRequestDescriptionHint => 'Describe the feature you want';

  @override
  String get featureRequestUsefulnessLabel => 'How would this be useful?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explain the benefit this feature would provide';

  @override
  String get featureRequestWhenLabel => 'When would you use this?';

  @override
  String get featureRequestWhenHint =>
      'Describe the situations where this would help';

  @override
  String get featureRequestSuccessMessage =>
      'Thank you! We\'ve received your feature request and will review it.';

  @override
  String get featureRequestSendFailed =>
      'Failed to send feature request. Please try again later.';

  @override
  String get notificationFollowBack => 'Follow back';

  @override
  String get followingTitle => 'Following';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName\'s Following';
  }

  @override
  String get followingFailedToLoadList => 'Failed to load following list';

  @override
  String get followingEmptyTitle => 'Not following anyone yet';

  @override
  String get followersTitle => 'Followers';

  @override
  String followersTitleForName(String displayName) {
    return '$displayName\'s Followers';
  }

  @override
  String get followersFailedToLoadList => 'Failed to load followers list';

  @override
  String get followersEmptyTitle => 'No followers yet';

  @override
  String get followersUpdateFollowFailed =>
      'Failed to update follow status. Please try again.';

  @override
  String get followersSortSemanticLabel => 'Sort followers';

  @override
  String get followingSortSemanticLabel => 'Sort following';

  @override
  String get followSortTitle => 'Sort by';

  @override
  String get followSortNewest => 'Newest first';

  @override
  String get followSortOldest => 'Oldest first';

  @override
  String get newMessageTitle => 'New message';

  @override
  String get newMessageFindPeople => 'Find people';

  @override
  String get newMessageNoContacts =>
      'No contacts found.\nFollow people to see them here.';

  @override
  String get newMessageNoUsersFound => 'No users found';

  @override
  String get hashtagSearchTitle => 'Search for hashtags';

  @override
  String get hashtagSearchSubtitle => 'Discover trending topics and content';

  @override
  String hashtagSearchNoResults(String query) {
    return 'No hashtags found for \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Search failed';

  @override
  String get userNotAvailableTitle => 'Account not available';

  @override
  String get userNotAvailableBody => 'This account isn\'t available right now.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Failed to save settings. Please try again.';

  @override
  String get blossomValidServerUrl =>
      'Please enter a valid server URL (e.g., https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom settings saved';

  @override
  String get blossomSaveTooltip => 'Save';

  @override
  String get blossomAboutTitle => 'About Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom is a decentralized media storage protocol that allows you to upload videos to any compatible server. By default, videos are uploaded to Divine\'s Blossom server. Enable the option below to use a custom server instead.';

  @override
  String get blossomUseCustomServer => 'Use Custom Blossom Server';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Videos will be uploaded to your custom Blossom server';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Your videos are currently being uploaded to Divine\'s Blossom server';

  @override
  String get blossomCustomServerUrl => 'Custom Blossom Server URL';

  @override
  String get blossomCustomServerHelper =>
      'Enter the URL of your custom Blossom server';

  @override
  String get blossomPopularServers => 'Popular Blossom Servers';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom server URL must use https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Failed to update crosspost setting';

  @override
  String get blueskySignInRequired => 'Sign in to manage Bluesky settings';

  @override
  String get blueskyPublishVideos => 'Publish videos to Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Your videos will be published to Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Your videos will not be published to Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle => 'Your past videos will post too';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'When you turn this on, Divine will start sending your older videos to Bluesky, oldest first, without rushing the daily limit.';

  @override
  String get blueskyHandle => 'Bluesky Handle';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Account provisioned and ready';

  @override
  String get blueskyStatusPending => 'Account provisioning in progress...';

  @override
  String get blueskyStatusFailed => 'Account provisioning failed';

  @override
  String get blueskyStatusDisabled => 'Account disabled';

  @override
  String get blueskyStatusNotLinked => 'No Bluesky account linked';

  @override
  String get blueskyUsernameRequired =>
      'Set up a divine.video handle before publishing to Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Bluesky publishing needs a claimed username.divine.video handle.';

  @override
  String get blueskyUsernameSyncPending =>
      'Your Divine handle is claimed. We are linking it to Bluesky - try again in a moment.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'We could not check your Divine handle. Try again.';

  @override
  String get blueskySetUpHandle => 'Set up';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Bluesky publishing is temporarily unavailable. Please try again.';

  @override
  String get invitesTitle => 'Invite Friends';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invites ready to generate',
      one: '1 invite ready to generate',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Generate a code when you are ready to share one.';

  @override
  String get invitesGenerateButtonLabel => 'Generate invite';

  @override
  String get invitesNoneAvailable => 'No invites available right now';

  @override
  String get invitesShareWithPeople => 'Share Divine with people you know';

  @override
  String get invitesUsedInvites => 'Used invites';

  @override
  String invitesShareMessage(String code) {
    return 'Join me on Divine! Use invite code $code to get started:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copy invite';

  @override
  String get invitesCopied => 'Invite copied!';

  @override
  String get invitesShareInvite => 'Share invite';

  @override
  String get invitesShareSubject => 'Join me on Divine';

  @override
  String get invitesClaimed => 'Claimed';

  @override
  String get invitesCouldNotLoad => 'Could not load invites';

  @override
  String get invitesRetry => 'Retry';

  @override
  String get searchSomethingWentWrong => 'Something went wrong';

  @override
  String get searchTryAgain => 'Try again';

  @override
  String get searchForLists => 'Search for lists';

  @override
  String get searchFindCuratedVideoLists => 'Find curated video lists';

  @override
  String get searchEnterQuery => 'Enter a search query';

  @override
  String get searchDiscoverSomethingInteresting =>
      'Discover something interesting';

  @override
  String get searchPeopleSectionHeader => 'People';

  @override
  String get searchPeopleLoadingLabel => 'Loading people results';

  @override
  String get searchTagsSectionHeader => 'Tags';

  @override
  String get searchTagsLoadingLabel => 'Loading tag results';

  @override
  String get searchVideosSectionHeader => 'Videos';

  @override
  String get searchVideosLoadingLabel => 'Loading video results';

  @override
  String get searchVideosSortOptionsLabel => 'Sort video results';

  @override
  String get searchVideosSortTrending => 'Hot';

  @override
  String get searchVideosSortLoops => 'Most loops';

  @override
  String get searchVideosSortEngagement => 'Most engaged';

  @override
  String get searchVideosSortRecent => 'Recent';

  @override
  String get searchListsSectionHeader => 'Lists';

  @override
  String get searchListsLoadingLabel => 'Loading list results';

  @override
  String get cameraAgeRestriction =>
      'You must be 16 or older to create content';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker relay must use wss:// (ws:// is allowed only for localhost)';

  @override
  String get timeNow => 'now';

  @override
  String timeShortMinutes(int count) {
    return '${count}m';
  }

  @override
  String timeShortHours(int count) {
    return '${count}h';
  }

  @override
  String timeShortDays(int count) {
    return '${count}d';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}w';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}mo';
  }

  @override
  String timeShortYears(int count) {
    return '${count}y';
  }

  @override
  String get timeVerboseNow => 'Now';

  @override
  String timeAgo(String time) {
    return '$time ago';
  }

  @override
  String get timeToday => 'Today';

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get draftTimeJustNow => 'Just now';

  @override
  String get contentLabelNudity => 'Nudity';

  @override
  String get contentLabelSexualContent => 'Sexual Content';

  @override
  String get contentLabelPornography => 'Pornography';

  @override
  String get contentLabelGraphicMedia => 'Graphic Media';

  @override
  String get contentLabelViolence => 'Violence';

  @override
  String get contentLabelSelfHarm => 'Self-Harm/Suicide';

  @override
  String get contentLabelDrugUse => 'Drug Use';

  @override
  String get contentLabelAlcohol => 'Alcohol';

  @override
  String get contentLabelTobacco => 'Tobacco/Smoking';

  @override
  String get contentLabelGambling => 'Gambling';

  @override
  String get contentLabelProfanity => 'Profanity';

  @override
  String get contentLabelHateSpeech => 'Hate Speech';

  @override
  String get contentLabelHarassment => 'Harassment';

  @override
  String get contentLabelFlashingLights => 'Flashing Lights';

  @override
  String get contentLabelAiGenerated => 'AI-Generated';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Scam/Fraud';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Misleading';

  @override
  String get contentLabelSensitiveContent => 'Sensitive Content';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName liked your video';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName liked your comment';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName commented on your video';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName started following you';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName mentioned you';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName reposted your video';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName posted a new vine';
  }

  @override
  String notificationAddedYourVideosToList(
    String actorName,
    int count,
    String listName,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count of your vines',
      one: 'your vine',
    );
    return '$actorName added $_temp0 to $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName replied to your comment';
  }

  @override
  String get notificationAndConnector => 'and';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count others',
      one: '1 other',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'You have a new update';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Hide keyboard';

  @override
  String get commentsErrorLoadFailed => 'Failed to load comments';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Please sign in to comment';

  @override
  String get commentsErrorPostCommentFailed => 'Failed to post comment';

  @override
  String get commentsErrorPostReplyFailed => 'Failed to post reply';

  @override
  String get commentsErrorEditFailed => 'Failed to edit comment';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Please sign in to interact';

  @override
  String get commentsErrorVoteFailed => 'Failed to vote on comment';

  @override
  String get commentsErrorReportFailed => 'Failed to report comment';

  @override
  String get commentsErrorBlockFailed => 'Failed to block user';

  @override
  String get commentsErrorDeleteFailed => 'Failed to delete comment';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Comments',
      one: '$count Comment',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Posting…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Your video reply is posting';

  @override
  String get commentsSortNew => 'New';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get commentsSortOld => 'Old';

  @override
  String get commentsSortSemanticLabel => 'Comments sorting';

  @override
  String get commentReply => 'Reply';

  @override
  String get commentReplySemanticLabel => 'Reply to comment';

  @override
  String get commentUpvoteLabel => 'Upvote comment';

  @override
  String get commentRemoveUpvoteLabel => 'Remove upvote';

  @override
  String get commentDownvoteLabel => 'Downvote comment';

  @override
  String get commentRemoveDownvoteLabel => 'Remove downvote';

  @override
  String get commentsInputHint => 'Add comment...';

  @override
  String get commentsInputHintEdit => 'Edit comment...';

  @override
  String get commentsEmptyTitle => 'No comments yet';

  @override
  String get commentsEmptySubtitle => 'Get the party started!';

  @override
  String get draftUntitled => 'Untitled';

  @override
  String get contentWarningNone => 'None';

  @override
  String get textBackgroundNone => 'None';

  @override
  String get textBackgroundSolid => 'Solid';

  @override
  String get textBackgroundHighlight => 'Highlight';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Left';

  @override
  String get textAlignRight => 'Right';

  @override
  String get textAlignCenter => 'Center';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Camera not supported on web yet';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Camera capture and recording are not available in the web version yet.';

  @override
  String get cameraPermissionBackToFeed => 'Back to feed';

  @override
  String get cameraCouldNotStart => 'Couldn\'t start the camera';

  @override
  String get cameraUnsupportedPlatform =>
      'The camera is not available on this platform yet.\nYou can still browse and watch videos.';

  @override
  String get cameraPermissionErrorTitle => 'Permission Error';

  @override
  String get cameraPermissionErrorDescription =>
      'Something went wrong while checking permissions.';

  @override
  String get cameraPermissionRetry => 'Retry';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Allow camera & microphone access';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'This allows you to capture and edit videos right here in the app, nothing more.';

  @override
  String get cameraPermissionGoToSettings => 'Go to settings';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Why six seconds?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Quick clips make space for spontaneity. The 6-second format helps you capture authentic moments as they happen.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Got it!';

  @override
  String get videoRecorderUploadTitle => 'Why no upload?';

  @override
  String get videoRecorderUploadBody =>
      'What you see on Divine is human-made: raw and captured in the moment. Unlike platforms that allow highly produced or AI-generated uploads, we prioritize the authenticity of the camera-direct experience.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'By keeping creation inside the app, we can better guarantee that content is real and unedited. We aren\'t opening up external gallery uploads at this time to protect that realness and keep our community free of synthetic content as much as we can.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Switch to Capture or Classic to roll something real.';

  @override
  String get videoRecorderUploadLearnMore => 'Learn how verification works';

  @override
  String get videoRecorderAutosaveFoundTitle => 'We found work in progress';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Would you like to continue where you left off?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Yes, continue';

  @override
  String get videoRecorderAutosaveDiscardButton => 'No, start a new video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Could not restore your draft';

  @override
  String get videoRecorderStopRecordingTooltip => 'Stop recording';

  @override
  String get videoRecorderStartRecordingTooltip => 'Start recording';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Recording. Tap anywhere to stop';

  @override
  String get videoRecorderTapToStartLabel => 'Tap anywhere to start recording';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Delete last clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Switch camera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoom to $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Toggle grid';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Toggle ghost frame';

  @override
  String get videoRecorderGhostFrameEnabled => 'Ghost frame enabled';

  @override
  String get videoRecorderGhostFrameDisabled => 'Ghost frame disabled';

  @override
  String get videoRecorderClipDeletedMessage => 'Clip moved to trash';

  @override
  String get videoRecorderClipUndoLabel => 'Undo';

  @override
  String get libraryTrashEmptyTitle => 'Trash is empty';

  @override
  String get libraryTrashEmptySubtitle =>
      'Deleted clips live here for 30 days before being removed for good.';

  @override
  String get libraryTrashRestoreLabel => 'Restore';

  @override
  String get libraryTrashDeleteNowLabel => 'Delete now';

  @override
  String get libraryTrashEmptyAllLabel => 'Empty trash';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Delete clip now?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'This removes the clip from trash right away.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Empty trash?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return 'This permanently deletes $_temp0 from trash right away.';
  }

  @override
  String get videoRecorderCloseLabel => 'Close video recorder';

  @override
  String get videoRecorderContinueToEditorLabel => 'Continue to video editor';

  @override
  String get videoRecorderCameraPreviewLabel => 'Camera preview';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Focus camera';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Switch to $mode mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => 'Add audio before recording';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Couldn\'t create the video. Try again.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shots left',
      one: '1 shot left',
      zero: 'No shots left',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Toggle flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Cycle timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Toggle aspect ratio';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilization';

  @override
  String get videoRecorderStabilizationModeOff => 'Off';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinematic';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematic Extended';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Preview Optimized';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Low Latency';

  @override
  String get videoRecorderStabilizationModeAuto => 'Auto';

  @override
  String get videoRecorderFlashValueOff => 'Off';

  @override
  String get videoRecorderFlashValueOn => 'On';

  @override
  String get videoRecorderFlashValueAuto => 'Auto';

  @override
  String get videoRecorderTimerValueOff => 'Off';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 seconds';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 seconds';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Square';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Vertical';

  @override
  String get videoRecorderCameraValueFront => 'Front camera';

  @override
  String get videoRecorderCameraValueBack => 'Back camera';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Clip library, no clips';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Open clip library, $clipCount clips',
      one: 'Open clip library, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Open stop-motion library, $frameCount frames',
      one: 'Open stop-motion library, 1 frame',
      zero: 'Open stop-motion library',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Camera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Open camera';

  @override
  String get videoEditorLibraryLabel => 'Library';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Draw';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorTuneLabel => 'Adjust';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Open adjustments editor';

  @override
  String get videoEditorTuneBrightness => 'Brightness';

  @override
  String get videoEditorTuneContrast => 'Contrast';

  @override
  String get videoEditorTuneSaturation => 'Saturation';

  @override
  String get videoEditorTuneExposure => 'Exposure';

  @override
  String get videoEditorTuneHue => 'Hue';

  @override
  String get videoEditorTuneTemperature => 'Temperature';

  @override
  String get videoEditorTuneTint => 'Tint';

  @override
  String get videoEditorTuneFade => 'Fade';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Add';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Open Library';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Open audio editor';

  @override
  String get videoEditorCaptionsLabel => 'Captions';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'Open captions editor';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Burn into video';

  @override
  String get videoEditorCaptionsPresetCustom => 'Custom';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Custom style';

  @override
  String get videoEditorCaptionsCustomApply => 'Apply';

  @override
  String get videoEditorCaptionsCustomFont => 'Font';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Text color';

  @override
  String get videoEditorCaptionsCustomBackground => 'Background';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Background color';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animation';

  @override
  String get videoEditorCaptionsAnimationNone => 'None';

  @override
  String get videoEditorCaptionsAnimationFade => 'Fade';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Spring';

  @override
  String get videoEditorCaptionsEditTitle => 'Captions';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Listening for speech…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Turning your audio into caption suggestions.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'We couldn\'t hear any speech. You can still write captions yourself.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Speech recognition isn\'t available on this device. You can write captions yourself.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Speech recognition isn\'t allowed. Enable it in Settings or write captions yourself.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Transcription didn\'t work this time. You can write captions yourself.';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'Write captions myself';

  @override
  String get videoEditorCaptionsAddCue => 'Add caption';

  @override
  String get videoEditorCaptionsCueTextHint => 'Caption text';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Delete caption';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Remove all captions';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => 'Remove captions?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'All caption text and timing will be gone.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => 'Close captions editor';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Confirm captions';

  @override
  String get videoEditorCaptionsPresetTitle => 'Caption style';

  @override
  String get videoEditorCaptionsPresetClassic => 'Classic';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Headline';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Typewriter';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marker';

  @override
  String get videoEditorCaptionsPresetScript => 'Script';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegant';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bubble';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Bold';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Dreamy';

  @override
  String get videoEditorCaptionsPresetOcean => 'Ocean';

  @override
  String get videoEditorCaptionsPresetSunny => 'Sunny';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Handwritten';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Stamp';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Open text editor';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Open draw editor';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Open filter editor';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Open sticker editor';

  @override
  String get videoEditorSaveDraftTitle => 'Save your draft?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Keep your edits for later, or discard them and leave the editor.';

  @override
  String get videoEditorSaveDraftButton => 'Save draft';

  @override
  String get videoEditorDiscardChangesButton => 'Discard changes';

  @override
  String get videoEditorKeepEditingButton => 'Keep editing';

  @override
  String get videoEditorDeleteLayerDropZone => 'Delete layer drop zone';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Release to delete layer';

  @override
  String get videoEditorDoneLabel => 'Done';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Play or pause video';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Split position invalid. Both clips must be at least ${minDurationMs}ms long.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Save selected clip';

  @override
  String get videoEditorSaveClip => 'Save clip';

  @override
  String get videoEditorClipSavedSuccess => 'Clip saved to library';

  @override
  String get videoEditorClipSaveFailed => 'Failed to save clip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Color picker';

  @override
  String get videoEditorUndoSemanticLabel => 'Undo';

  @override
  String get videoEditorRedoSemanticLabel => 'Redo';

  @override
  String get videoEditorTextColorSemanticLabel => 'Text color';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Text alignment';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Text background';

  @override
  String get videoEditorFontSemanticLabel => 'Font';

  @override
  String get videoEditorNoStickersFound => 'No stickers found';

  @override
  String get videoEditorNoStickersAvailable => 'No stickers available';

  @override
  String get videoEditorFailedLoadStickers => 'Failed to load stickers';

  @override
  String get videoEditorVoiceOverLabel => 'Voice over';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Recording $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Record a voice over';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Start recording';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Stop recording';

  @override
  String get videoEditorVoiceOverHint =>
      'Tap to record. Add as many takes as you like.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings',
      one: '1 recording',
      zero: 'No recordings yet',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Delete last recording';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Microphone access needed';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Allow microphone access to record a voice over.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Open settings';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Recording started';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Recording saved';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Recording is longer than your video';

  @override
  String get videoEditorPlaySemanticLabel => 'Play';

  @override
  String get videoEditorPauseSemanticLabel => 'Pause';

  @override
  String get videoEditorVolumeSemanticLabel => 'Adjust volume';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Slide to adjust';

  @override
  String get videoEditorChromaKeyLabel => 'Green screen';

  @override
  String get videoEditorChromaKeyTitle => 'Green screen';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Set up the green screen for this clip';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Discard green screen changes';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Apply the green screen';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Auto-detect';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Green';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Blue';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Screen color';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Amount';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'How much of the screen color disappears';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Edge';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Softens the cutout so hair doesn\'t turn jagged';

  @override
  String get videoEditorChromaKeySpillLabel => 'Spill';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Pulls the screen\'s color back off your subject';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Replace with';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Nothing';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Color';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Image';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Video can\'t hold transparency, so this exports as black.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Couldn\'t find a screen. It has to reach the edges of the frame — pick the color by hand instead.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Pick a clip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Your library is empty. Save a clip first, then use it as a background.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Couldn\'t load that image.';

  @override
  String get videoEditorChromaKeyRemove => 'Remove green screen';

  @override
  String get videoEditorChromaKeyFailed =>
      'Couldn\'t apply the green screen. Your clip is unchanged.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Couldn\'t remove the green screen. Your clip is unchanged.';

  @override
  String get videoEditorChromaKeyApplying => 'Applying the green screen…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'This device can\'t show the live preview. Your settings still apply when you export.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Delete';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Delete selected item';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Frames per image';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames',
      one: '1 frame',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Frames';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames per image',
      one: '$count frame per image',
    );
    return '$_temp0';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Stop-motion frame $position of $total';
  }

  @override
  String get videoEditorEditLabel => 'Edit';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'Edit selected item';

  @override
  String get videoEditorDuplicateLabel => 'Duplicate';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplicate selected item';

  @override
  String get videoEditorCombineLabel => 'Combine';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Combine selected drawings into one layer';

  @override
  String get videoEditorSplitLabel => 'Split';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'Split selected clip';

  @override
  String get videoEditorExtractAudioLabel => 'Extract Audio';

  @override
  String get videoEditorClipAudioTitle => 'Clip Audio';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Extract audio from clip and mute original';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Cannot extract audio: clip is not locally available.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Could not extract audio. Please try again.';

  @override
  String get videoEditorSpeedLabel => 'Speed';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Set playback speed for selected clip';

  @override
  String get videoEditorReverseLabel => 'Reverse';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Toggle reverse playback for selected clip';

  @override
  String get videoEditorReverseProgressLabel =>
      'One moment, we\'re reversing your clip';

  @override
  String get videoEditorTransformLabel => 'Transform';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Crop, rotate, or flip selected clip';

  @override
  String get videoEditorTransformProgressLabel =>
      'One moment, we\'re transforming your clip';

  @override
  String get videoEditorTransformFailed =>
      'Could not transform clip. Please try again.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Cannot transform: clip is not locally available.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Crop, rotate, or flip selected frame';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'One moment, we\'re transforming your frame';

  @override
  String get videoEditorTransformFrameFailed =>
      'Could not transform frame. Please try again.';

  @override
  String get videoEditorTransformRotateLabel => 'Rotate';

  @override
  String get videoEditorTransformFlipLabel => 'Flip';

  @override
  String get videoEditorTransformResetLabel => 'Reset';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Apply transform';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'Cancel transform';

  @override
  String get videoEditorTransformPlayLabel => 'Play';

  @override
  String get videoEditorTransformPauseLabel => 'Pause';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Cannot reverse: clip is not locally available.';

  @override
  String get videoEditorReverseFailed =>
      'Could not reverse clip. Please try again.';

  @override
  String get videoEditorSpeedSheetTitle => 'Clip Speed';

  @override
  String get videoEditorTransitionSheetTitle => 'Transition';

  @override
  String get videoEditorTransitionNone => 'None';

  @override
  String get videoEditorTransitionDissolve => 'Dissolve';

  @override
  String get videoEditorTransitionFadeToBlack => 'Fade to black';

  @override
  String get videoEditorTransitionFadeToWhite => 'Fade to white';

  @override
  String get videoEditorTransitionSlide => 'Slide';

  @override
  String get videoEditorTransitionPush => 'Push';

  @override
  String get videoEditorTransitionWipe => 'Wipe';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Edit transition';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Loop transition';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Edit loop transition';

  @override
  String get videoEditorTransitionDuration => 'Duration';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Shortened to avoid overlapping the neighbouring transition.';

  @override
  String get videoEditorTransitionCurve => 'Curve';

  @override
  String get videoEditorTransitionDirection => 'Direction';

  @override
  String get videoEditorTransitionDirectionLeft => 'Left';

  @override
  String get videoEditorTransitionDirectionRight => 'Right';

  @override
  String get videoEditorTransitionDirectionUp => 'Up';

  @override
  String get videoEditorTransitionDirectionDown => 'Down';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Easing curve $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animation';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Edit layer animation';

  @override
  String get videoEditorLayerAnimationEnter => 'Enter';

  @override
  String get videoEditorLayerAnimationLeave => 'Leave';

  @override
  String get videoEditorLayerAnimationFade => 'Fade';

  @override
  String get videoEditorLayerAnimationScale => 'Scale';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Scale from';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Finish timeline editing';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Play preview';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Pause preview';

  @override
  String get videoEditorAudioUntitledSound => 'Untitled sound';

  @override
  String get videoEditorAudioUntitled => 'Untitled';

  @override
  String get videoEditorAudioAddAudio => 'Add audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'No sounds available';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Sounds will appear here when creators share audio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Failed to load sounds';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Select the audio segment for your video';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Community';

  @override
  String get videoEditorAudioCategoryFeatured => 'Featured';

  @override
  String get videoEditorAudioCategoryMySounds => 'My Sounds';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Arrow tool';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Eraser tool';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Marker tool';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Pencil tool';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Show timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Hide timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Avoid placing content behind these areas.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originals';

  @override
  String get videoEditorStickerSearchHint => 'Search stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Select font';

  @override
  String get videoEditorFontUnknown => 'Unknown';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Playhead must be within the selected clip to split.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Trim start';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Trim end';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Trim clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Drag handles to adjust clip duration';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Dragging clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index of $total, $duration seconds';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'Long press to reorder';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Move left';

  @override
  String get videoEditorTimelineClipMoveRight => 'Move right';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index of $total, selected';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index of $total, not selected';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Select';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Select multiple clips';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Done selecting clips';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips selected',
      one: '1 clip selected',
      zero: 'No clips selected',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Select multiple drawings';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Done selecting drawings';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Delete selected drawings';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drawings selected',
      one: '1 drawing selected',
      zero: 'No drawings selected',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Merge';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Merge selected clips';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Delete selected clips';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Delete selected frames';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Reverse selected frames';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplicate selected frames';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Your video needs at least ${seconds}s — capture a few more frames.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'One moment, we\'re merging your clips';

  @override
  String get videoEditorMergeFailed =>
      'Could not merge clips. Please try again.';

  @override
  String get videoEditorTimelineLongPressToDragHint => 'Long press to drag';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Video timeline';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, selected';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Close color picker';

  @override
  String get videoEditorPickColorTitle => 'Pick color';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirm color';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturation and brightness';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturation $saturation%, Brightness $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Hue';

  @override
  String get videoEditorAddElementSemanticLabel => 'Add element';

  @override
  String get videoEditorDoneSemanticLabel => 'Done';

  @override
  String get videoEditorLevelSemanticLabel => 'Level';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel => 'Close post details';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Dismiss help dialog';

  @override
  String get videoMetadataGotItButton => 'Got it!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB limit reached. Remove some content to continue.';

  @override
  String get videoMetadataExpirationLabel => 'Expiration';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Select expiration time';

  @override
  String get videoMetadataTitleLabel => 'Title';

  @override
  String get videoMetadataDescriptionLabel => 'Description';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Delete Tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Add content warning';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Select content warnings';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Select all that apply';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Let others save and reuse this video\'s audio.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Your video is up, but the sound didn\'t publish. Edit the video to share it.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Add collaborators';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Invite collaborator';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Mutual followers';

  @override
  String get videoMetadataInspiredByLabel => 'Add inspired by';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Set inspired by';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'This creator cannot be referenced.';

  @override
  String get videoMetadataPostDetailsTitle => 'Post details';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Saved to library';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Failed to save';

  @override
  String get videoMetadataGoToLibraryButton => 'Go to Library';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'Save for later button';

  @override
  String get videoMetadataSavingVideoHint => 'Saving video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Save video to drafts and $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Save video to drafts. No rendered video yet, so no copy is added to $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Save for Later';

  @override
  String get videoMetadataPostSemanticLabel => 'Post button';

  @override
  String get videoMetadataPublishVideoHint => 'Publish video to feed';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Also share to my feed';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Off keeps this video only in the comment thread.';

  @override
  String get videoMetadataFormNotReadyHint => 'Fill out the form to enable';

  @override
  String get videoMetadataPostButton => 'Post';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Open post preview screen';

  @override
  String get videoMetadataShareTitle => 'Share';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Video details';

  @override
  String get videoMetadataClassicDoneButton => 'Done';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Play preview';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Pause preview';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Close video preview';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Remove';

  @override
  String get fullscreenFeedRemovedMessage => 'Video removed';

  @override
  String get fullscreenFeedEmptyMessage => 'Nothing left to play here';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle =>
      'Accept awards and check issued badge status.';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesLoadError => 'Could not load badges';

  @override
  String get badgesUpdateError => 'Could not update badge';

  @override
  String get badgesAwardedEmptyTitle => 'No badge awards yet';

  @override
  String get badgesAwardedEmptySubtitle =>
      'When someone awards you a Nostr badge, it will land here.';

  @override
  String get badgesStatusAccepted => 'Accepted';

  @override
  String get badgesStatusNotAccepted => 'Not accepted';

  @override
  String get badgesActionRemove => 'Remove';

  @override
  String get badgesActionAccept => 'Accept';

  @override
  String get badgesActionReject => 'Reject';

  @override
  String get badgesIssuedEmptyTitle => 'No issued badges yet';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Badges you issue will show acceptance status here.';

  @override
  String get badgesIssuedNoRecipients => 'No recipients found for this award.';

  @override
  String get badgesRecipientAcceptedStatus => 'Accepted by recipient';

  @override
  String get badgesRecipientWaitingStatus => 'Waiting for recipient';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hidden ($count)',
      one: 'Hidden (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Restore';

  @override
  String get badgesHiddenSnackbar => 'Badge hidden';

  @override
  String get badgesHiddenSnackbarUndo => 'Undo';

  @override
  String get badgesTabAwarded => 'Awarded';

  @override
  String get badgesTabCreated => 'Created';

  @override
  String get badgesTabIssued => 'Issued';

  @override
  String get badgesCreateAction => 'New badge';

  @override
  String get badgesCreatedEmptyTitle => 'No badges made yet';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Make one and hand it to someone who earned it.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Awarded to $count people',
      one: 'Awarded to 1 person',
      zero: 'Not awarded yet',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'New badge';

  @override
  String get badgeEditorEditTitle => 'Edit badge';

  @override
  String get badgeEditorNameLabel => 'Name';

  @override
  String get badgeEditorNameHint => 'Scene Stealer';

  @override
  String get badgeEditorIdentifierLabel => 'Identifier';

  @override
  String get badgeEditorIdentifierHelp =>
      'Part of the badge\'s address, so it stays put once the badge exists.';

  @override
  String get badgeEditorIdentifierTaken =>
      'You already have a badge with this identifier. Edit that one instead — publishing here would replace it.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Every badge needs an identifier — type one if the name did not fill it in.';

  @override
  String get badgeEditorDescriptionLabel => 'Description';

  @override
  String get badgeEditorDescriptionHint =>
      'For the one who steals the scroll with a single loop.';

  @override
  String get badgeEditorArtworkLabel => 'Artwork';

  @override
  String get badgeEditorArtworkAdd => 'Add artwork';

  @override
  String get badgeEditorArtworkReplace => 'Replace';

  @override
  String get badgeEditorArtworkError => 'Could not upload that image';

  @override
  String get badgeEditorArtworkRequired => 'Every badge needs artwork.';

  @override
  String get badgeEditorArtworkRemove => 'Remove artwork';

  @override
  String get badgeEditorArtworkSheetTitle => 'Badge artwork';

  @override
  String get badgeDetailDeleteAction => 'Delete badge';

  @override
  String get badgeDetailDeleteTitle => 'Delete this badge?';

  @override
  String get badgeDetailDeleteBody =>
      'This asks relays to drop the badge and every award you handed out for it. Relays can refuse, and anyone who pinned it keeps it on their profile until they remove it.';

  @override
  String get badgeDetailDeleteConfirm => 'Delete';

  @override
  String get badgeEditorSaveAction => 'Publish badge';

  @override
  String get badgeEditorSaveError => 'Could not publish the badge';

  @override
  String get badgeEditorLoadError => 'Could not load this badge';

  @override
  String get badgeDetailTitle => 'Badge';

  @override
  String get badgeDetailMadeBy => 'Made by';

  @override
  String get badgeDetailRecipientsTitle => 'Awarded to';

  @override
  String get badgeDetailNoRecipients => 'Nobody has this one yet.';

  @override
  String get badgeDetailAwardAction => 'Award this badge';

  @override
  String get badgeDetailEditAction => 'Edit badge';

  @override
  String get badgeDetailShareAction => 'Share';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Check out this badge on Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Take badge back';

  @override
  String get badgeDetailRevokeTitle => 'Take this badge back?';

  @override
  String get badgeDetailRevokeBody =>
      'This asks relays to drop the award you gave this person. Relays can refuse, and if they already pinned the badge it stays on their profile until they take it down. Either way, they are not told.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'This asks relays to drop the award you gave yourself, and takes the badge off your profile. If the relays refuse the deletion, nothing changes.';

  @override
  String get badgeDetailRevokeConfirm => 'Take it back';

  @override
  String get badgeDetailRevokeSuccess => 'Badge taken back';

  @override
  String get badgeDetailBlockClaimantsAction => 'Block badge claimants';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Block badge claimants';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Could not load claimants for this badge';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'No one claims this badge right now';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'We did not find any current claimants to block.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Block $count claimants?',
      one: 'Block 1 claimant?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This blocks the $count accounts currently claiming this badge. Their posts will leave your feeds, and they will not be notified.',
      one:
          'This blocks the account currently claiming this badge. Their posts will leave your feeds, and they will not be notified.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Block $count accounts',
      one: 'Block 1 account',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Badge claimants blocked';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Could not block badge claimants';

  @override
  String get badgeDetailLoadError => 'Could not load this badge';

  @override
  String get badgeDetailMissing => 'We could not find this badge on any relay.';

  @override
  String get badgeDetailActionError => 'That did not go through';

  @override
  String get badgeAwardTitle => 'Award badge';

  @override
  String get badgeAwardPickAction => 'Pick people';

  @override
  String get badgeAwardManualLabel => 'Or paste keys';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Pick at least one person.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Award to $count people',
      one: 'Award to 1 person',
      zero: 'Award badge',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Awarded by';

  @override
  String get profileBadgeRecipients => 'Recipients';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count more';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name badge';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Badge';

  @override
  String get profileBadgeFooterBody =>
      'Badges are little awards anyone can make on Nostr. Give one to a friend, a creator, or someone who made your day.';

  @override
  String get profileBadgeFooterLink => 'Make your own badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Family guide';

  @override
  String get minorAccountReviewWelcomeTitle => 'Not 16 yet? That\'s OK.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'If you clicked through to this page instead of just picking the answer that got you in, that matters. It shows honesty, backbone, and real care for the people around you.\n\nRules for people under 16 vary depending on where you live. At Divine, we want families to talk it through together and decide what healthy social media use looks like.';

  @override
  String get minorAccountReviewModerationTitle => 'We need one more step';

  @override
  String get minorAccountReviewModerationBody =>
      'We were asked to take a closer look at this account because it may belong to someone under 16. This flow keeps the next steps private and points you to the right path for your age.';

  @override
  String get minorAccountReviewRulesTitle =>
      'The rules are not the same everywhere';

  @override
  String get minorAccountReviewRulesBody =>
      'Different countries and regions treat teen social media use differently. That is why we ask families to slow down, check the facts, and choose the next step together.';

  @override
  String get minorAccountReviewApproachTitle => 'How Divine thinks about it';

  @override
  String get minorAccountReviewApproachBody =>
      'We think healthy tech habits come from pausing, reflecting, and redirecting attention toward better things, not from spying on kids or turning parents into hall monitors. Research backs that up too.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'More for families';

  @override
  String get minorAccountReviewKidsPolicyCta => 'Read Divine\'s kids policy';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'Choose the path that fits';

  @override
  String get minorAccountReviewUnder13Cta => 'Under 13';

  @override
  String get minorAccountReviewTeenCta => 'Age 13-15';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Visit the Divine family guide for practical tips, conversation tools, and resources for helping teens use social media more safely.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Get family guides and tips';

  @override
  String get minorAccountReviewFooter =>
      'If you are 16 or older and got sent here by mistake, contact Divine support so a real person can review it.';

  @override
  String get minorAccountReviewTitle => 'Account Review';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Checking account status...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Please wait while we confirm this account\'s current review status.';

  @override
  String get minorAccountReviewDefaultTitle => 'Account review required';

  @override
  String get minorAccountReviewDefaultBody =>
      'We need to review this account before it can use Divine normally.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Case ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Case ID';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'What is restricted right now';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Posting and publishing are paused';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Comments, likes, reposts, and follows are paused';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Starting or replying to regular messages is paused';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Support and your moderation message remain available';

  @override
  String get minorAccountReviewContentTitle => 'What happens to your videos';

  @override
  String get minorAccountReviewContentBody =>
      'Your videos are hidden while this review is open. If your account is cleared, they come back. If the review closes without a response, your account is closed and your videos are deleted.';

  @override
  String get minorAccountReviewResponseClockRunningTitle => 'Time to respond';

  @override
  String minorAccountReviewResponseClockRunningDays(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 left to respond. Deadline: $date.';
  }

  @override
  String minorAccountReviewResponseClockRunningHours(int hours, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0 left to respond. Deadline: $date.';
  }

  @override
  String get minorAccountReviewResponseClockPausedTitle =>
      'Response clock paused';

  @override
  String minorAccountReviewResponseClockPausedBody(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'The response clock is paused. About $_temp0 will remain when it restarts.';
  }

  @override
  String get minorAccountReviewResponseClockExpiredTitle =>
      'Response deadline passed';

  @override
  String get minorAccountReviewResponseClockExpiredBody =>
      'The response deadline has passed. Contact Support Center if you need help.';

  @override
  String get minorAccountReviewResponseClockUnavailableTitle =>
      'Deadline unavailable';

  @override
  String get minorAccountReviewResponseClockUnavailableBody =>
      'We can\'t show your response deadline right now. Contact Support Center if you need help.';

  @override
  String get minorAccountReviewAppealTitle => 'Think we got this wrong?';

  @override
  String get minorAccountReviewAppealTeenBody =>
      'Contact Support Center and tell us what happened. We’ll take another look, but we can’t promise the decision will change.';

  @override
  String get minorAccountReviewAppealUnder13Body =>
      'Your parent or guardian can contact Support Center and tell us what happened. We’ll take another look, but we can’t promise the decision will change.';

  @override
  String get minorAccountReviewOpenSupportCenter => 'Open Support Center';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Open Moderation Message';

  @override
  String get minorAccountReviewOpenReviewPage => 'Open review page';

  @override
  String get minorAccountReviewCheckAgain => 'Check Again';

  @override
  String get minorAccountReviewLogOut => 'Log out';

  @override
  String get minorAccountReviewNextStepTitle => 'Next step';

  @override
  String get minorAccountReviewNextStepBody =>
      'Open the support center or your moderation message if you need help with this review.';

  @override
  String get minorAccountReviewInProgressTitle => 'Review in progress';

  @override
  String get minorAccountReviewInProgressBody =>
      'We have what we need for now. Our team is reviewing this case before restoring normal account access.';

  @override
  String get minorAccountReviewUnder13Title => 'Under-13 accounts';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'If this account belongs to someone under 13, a parent or guardian must email $supportEmail and include the case ID.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'We can\'t give you an account yet';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine isn\'t built for kids under 13 and the social media rules around the world tie our hands.\n\nA lot of things on the internet push you to lie to get what you want, and we hate that. It\'s the wrong lesson for life, and we\'re not going to teach it to you here.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'What your family can do instead';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'A parent or guardian can hold the account and do the posting, and you can absolutely be in the videos with them. We want families to enjoy Divine in whatever way is right for them.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'When you turn 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Depending on the rules where you live, you may be able to come back and apply for your own account. In that case, if you’re between 13 and 15, you’ll need consent from a parent or guardian.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Why we won\'t tell you to just click back';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'A lot of the internet is set up to reward people for saying whatever gets them through the gate. We don\'t think that\'s great. Yes, you could go back and say you\'re older than you are, but that wouldn\'t be honest, and we\'re not going to coach you into lying to get what you want.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'We\'re trying to help young people use Divine in ways that are healthy and positive for them and the people around them. We also have to follow laws that are different in different places. So, if you\'re under 13, the answer is that you can\'t have your own account today.';

  @override
  String get minorAccountReviewTeenBody =>
      'If this account belongs to someone 13 to 15, use the moderation message or support path to follow the parental consent instructions.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'If the account will belong to someone 13 to 15';

  @override
  String get minorAccountReviewParentConsentBody =>
      'A parent or guardian should email Divine support with a short private video. Our team will review it and help with next steps.\n\nIf parent or guardian contact is not possible or would put someone at risk, email Divine support and let us know.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'This is a pause while the Divine support team reviews the video. If it is approved, they will guide you through setting up the new account.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Why we ask a parent or guardian to be involved';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine has to follow age-related laws around the world. We also know that most technical age gates are imperfect. Rather than pretending the rules don\'t exist or that it\'s cool to lie about your age, we want teens and families to make thoughtful decisions about how best to use Divine. That\'s why, for 13-15 year olds, we ask parents to be part of the account creation process.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'We also have to follow the law, and those rules are different depending on where someone lives. So instead of pretending the rules do not exist, we ask for a parent or guardian to be part of the process.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'What the video should show';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'The teen in the video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'A parent or guardian speaking on camera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'A clear statement that the teen is 13 to 15 and has permission to use Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'A clear statement that the parent or guardian knows about the account and will supervise its use';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'How to send it';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Attach the video when you email Divine support';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Keep the video private and do not post it in the app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Our team will review it and reply with next steps';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Email Divine support';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine Greenlight review help (ages 13-15)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hi Divine support,\n\nI am contacting Divine about Divine Greenlight for a teen who is 13-15.\n\nI have attached a short private video that shows:\n- the teen\n- a parent or guardian speaking on camera\n- that the teen has permission to use Divine\n- that the parent or guardian knows about the account and will supervise its use\n\nCountry/ies of residence:\n\nHelpful context:\n\nThanks.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Parent Support Instructions';

  @override
  String get minorAccountReviewContinue => 'Continue';

  @override
  String get minorAccountReviewErrorTitle =>
      'We could not load your account review status.';

  @override
  String get minorAccountReviewErrorBody => 'Please try again in a moment.';

  @override
  String get minorAccountReviewTryAgain => 'Try Again';

  @override
  String get minorAccountReviewParentContactTitle => 'Parent Contact';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Add a parent or guardian email';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'We will use this address for the parental consent review on case $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Parent or guardian email';

  @override
  String get minorAccountReviewSubmitting => 'Submitting...';

  @override
  String get minorAccountReviewSubmitEmail => 'Submit Email';

  @override
  String get minorAccountReviewBackToReview => 'Back to Account Review';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Email submitted';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'We submitted $email for review. We\'ll email this address to confirm. Once your parent or guardian responds, your case will move forward. Use Check Again from the account review screen for updates.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'We received the parent or guardian contact for this account. Our team will review it before restoring access.';

  @override
  String get minorAccountReviewMissingCase =>
      'We could not find an active review case for this account.';

  @override
  String get minorAccountReviewParentContactError =>
      'Could not submit the parent email. Please try again.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Parent Support';

  @override
  String get minorAccountReviewUnder13Heading =>
      'A parent or guardian must contact Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'For likely under-13 accounts, the next step is parent or guardian contact by email.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Support email';

  @override
  String get minorAccountReviewCopySupportEmail => 'Copy support email';

  @override
  String get minorAccountReviewSupportEmailCopied => 'Support email copied';

  @override
  String get minorAccountReviewCopyCaseId => 'Copy case ID';

  @override
  String get minorAccountReviewCaseIdCopied => 'Case ID copied';

  @override
  String get minorAccountReviewUnavailable => 'Unavailable';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Ask the parent or guardian to include the case ID and explain that they are contacting Divine about this account review.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Under-13 account review for case $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Hi Divine support,\n\nI am the parent or guardian for a child under 13 and I am contacting Divine about account review case $caseId.\n\nThanks.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Minor Account Review Simulation';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Current state';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Restricted ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Active';

  @override
  String get devOptionsMinorReviewStateLoading => 'Loading...';

  @override
  String get devOptionsMinorReviewStateError => 'Error loading state';

  @override
  String get devOptionsMinorReviewClearTitle => 'Clear simulation override';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Use backend or default active state again';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Simulate 13-15 review case';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Restricted account with parent contact path';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simulate under-13 support case';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Restricted account with parent-email-only instructions';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Minor account review simulation cleared';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Simulated under-13 support case enabled';

  @override
  String get devOptionsMinorReviewResponseClockTitle => 'Response clock';

  @override
  String get devOptionsMinorReviewResponseClockRunning => 'Running';

  @override
  String get devOptionsMinorReviewResponseClockPaused => 'Paused';

  @override
  String get devOptionsMinorReviewResponseClockExpired => 'Expired';

  @override
  String get devOptionsMinorReviewResponseClockNotApplicable =>
      'Not applicable';

  @override
  String get devOptionsMinorReviewResponseClockMalformed => 'Malformed payload';

  @override
  String get devOptionsMinorReviewResponseClockRunningToast =>
      'Simulated running response clock';

  @override
  String get devOptionsMinorReviewResponseClockPausedToast =>
      'Simulated paused response clock';

  @override
  String get devOptionsMinorReviewResponseClockExpiredToast =>
      'Simulated expired response clock';

  @override
  String get devOptionsMinorReviewResponseClockNotApplicableToast =>
      'Simulated not-applicable response clock';

  @override
  String get devOptionsMinorReviewResponseClockMalformedToast =>
      'Simulated malformed response clock';

  @override
  String get devOptionsProtectedMinorSimulationTitle =>
      'Protected Minor Simulation';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Current state';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Protected minor (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Not protected';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Loading…';

  @override
  String get devOptionsProtectedMinorStateError => 'Error reading state';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'No override (real account state)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Override: forced protected';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Override: forced not protected';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simulate protected minor (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Force the protected-minor state to QA the #175/#176 protections';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simulate non-minor';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Force not-protected (explicit negative, distinct from no override)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Clear override';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Return to the real Keycast-driven account state';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Protected-minor state forced on';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Protected-minor state forced off';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Protected-minor override cleared';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Signup invites';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Current state';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Server value: loading';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Server value: enabled';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Server value: disabled';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Server value: unknown';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Override: use server value';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Override: force enabled';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Override: force disabled';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Use server value';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Follow the invite service onboardingMode';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Force enabled';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Show signup invite gates and management locally';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Force disabled';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Hide signup invite UI locally without changing the server';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Signup invites now follow the server';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Signup invites forced on';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Signup invites forced off';

  @override
  String get commentsRecordVideoButtonLabel => 'Record video comment';

  @override
  String get commentsOpenVideoLabel => 'Open video comment';

  @override
  String get commentsMuteVideoReplyLabel => 'Mute video reply';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Unmute video reply';

  @override
  String get commentsOpenReplyParentLabel => 'Open video this replies to';

  @override
  String get commentsReplyParentSectionTitle => 'In reply to';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Reply to $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Reply to video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Verified $platform account: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Verified accounts';

  @override
  String get profileEditGetVerifiedCta => 'Get verified';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Link your social media accounts so people know it\'s really you.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Visit website: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Could not open website';

  @override
  String get videoMetadataEditCoverTitle => 'Edit cover';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Discard cover changes';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Use selected frame as video cover';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Seek through video to select cover frame';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Search or add tags';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Add tags to help people discover your video';

  @override
  String get videoMetadataTagsPickerNoResults => 'No matching tags';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Add \"#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Not 16 yet? That\'s OK. ';

  @override
  String get authUnder16ChoicesCta => 'Here are your choices.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Here\'s why';

  @override
  String get generalSettingsHoldToRecord => 'Hold to record';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Start recording when you press and hold, then stop when you release';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos published to your profile',
      one: 'Video published to your profile',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Send message';

  @override
  String get emojiPickerSearchHint => 'Search';

  @override
  String get emojiCategoryRecent => 'Recent';

  @override
  String get emojiCategorySmileys => 'Smileys & People';

  @override
  String get emojiCategoryAnimals => 'Animals & Nature';

  @override
  String get emojiCategoryFood => 'Food & Drink';

  @override
  String get emojiCategoryActivities => 'Activities';

  @override
  String get emojiCategoryTravel => 'Travel & Places';

  @override
  String get emojiCategoryObjects => 'Objects';

  @override
  String get emojiCategorySymbols => 'Symbols';

  @override
  String get emojiCategoryFlags => 'Flags';

  @override
  String get videoEditorMarkerLabel => 'Marker';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel => 'Add timeline marker';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Remove timeline marker';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Remove marker at playhead';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Delete marker?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'This removes the marker from the timeline. Your edit stays intact.';

  @override
  String get videoEditorVolumeLongPressHint => 'Mute or unmute all tracks';

  @override
  String get videoEditorSplitFailed => 'Split failed. Please try again.';

  @override
  String get videoEditEditSubtitles => 'Edit subtitles';

  @override
  String get subtitleEditorTitle => 'Edit subtitles';

  @override
  String get subtitleEditorSave => 'Save';

  @override
  String get subtitleEditorProcessing =>
      'Subtitles are still being generated. Check back in a moment.';

  @override
  String get subtitleEditorNoSpeech =>
      'No speech was detected in this video, so there\'s nothing to caption.';

  @override
  String get subtitleEditorWriteOwn => 'Write them yourself';

  @override
  String get subtitleEditorAddCue => 'Add a line';

  @override
  String get subtitleEditorRemoveCue => 'Remove this line';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'The video can\'t be played right now, but you can still fix the captions.';

  @override
  String get subtitleEditorPlayPreview => 'Play the video';

  @override
  String get subtitleEditorPausePreview => 'Pause the video';

  @override
  String get subtitleEditorInvalidHint =>
      'Every line needs text and an end after its start.';

  @override
  String get subtitleEditorLoadError => 'Couldn\'t load subtitles. Try again.';

  @override
  String get subtitleEditorSaveSuccess => 'Subtitles updated';

  @override
  String get subtitleEditorSaveError => 'Couldn\'t save subtitles. Try again.';

  @override
  String get subtitleEditorRetry => 'Retry';

  @override
  String get subtitleEditorCueHint => 'Caption text';

  @override
  String get imageCropEditorRotateLabel => 'Rotate';

  @override
  String get imageCropEditorFlipLabel => 'Flip';

  @override
  String get imageCropEditorResetLabel => 'Reset';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Cancel cropping';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Apply crop';

  @override
  String get imageCropEditorProcessing => 'Applying crop…';

  @override
  String get backgroundUploadNotificationTitle => 'Uploading video';

  @override
  String get monetizationSettingsTitle => 'Creator Support';

  @override
  String get monetizationSettingsSubtitle => 'Add tip and subscription links';

  @override
  String get monetizationSettingsIntroTitle => 'Outbound links only';

  @override
  String get monetizationSettingsIntroBody =>
      'Add creator-controlled destinations. Divine never handles the payment or unlocks in-app content from these links.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active links on your profile',
      one: '$count active link on your profile',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Send a tip';

  @override
  String get monetizationSettingsSubscriptionSection => 'Subscribe / support';

  @override
  String get monetizationSettingsSave => 'Save support links';

  @override
  String get monetizationSettingsSaving => 'Saving...';

  @override
  String get monetizationSettingsSaved => 'Support links updated';

  @override
  String get monetizationSettingsSaveFailed =>
      'Could not save support links. Check your connection and try again.';

  @override
  String get monetizationSettingsErrorEmpty => 'Add a handle or URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'That link does not look right.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Use a link for this provider.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag or cash.app link';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me handle or link';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo handle or link';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon handle or link';

  @override
  String get monetizationSettingsHintSubstack => 'Substack domain or link';

  @override
  String get monetizationSettingsHintMedium => 'Medium handle or link';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective slug or link';

  @override
  String get profileSupportSheetTitle => 'Support this creator';

  @override
  String get profileSupportSheetBody =>
      'These links open outside Divine. Nothing here unlocks content in the app.';

  @override
  String get profileSupportTipSection => 'Send a tip';

  @override
  String get profileSupportSubscriptionSection => 'Subscribe / support';

  @override
  String get profileSupportButtonLabel => 'Support';

  @override
  String get monetizationTipsSettingsTitle => 'Tips';

  @override
  String get monetizationTipsSettingsSubtitle => 'Add optional tip links';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Optional tips only';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Tips are optional user-to-user gifts. They do not unlock content, subscriptions, features, ranking, visibility, or access in Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active tip links on your profile',
      one: '$count active tip link on your profile',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Save tip links';

  @override
  String get monetizationTipsSettingsSaved => 'Tip links updated';

  @override
  String get profileTipButtonLabel => 'Tip';

  @override
  String get profileTipSheetTitle => 'Tip this creator';

  @override
  String get profileTipSheetBody =>
      'Tips open outside Divine. They are optional and do not unlock content, subscriptions, features, or access in Divine.';

  @override
  String get settingsStorageTitle => 'Storage';

  @override
  String get settingsStorageCacheSectionTitle => 'Cached media';

  @override
  String get settingsStorageCacheDescription =>
      'Cached feed videos, thumbnails and temporary renders. Clearing them is safe — they\'re re-downloaded or regenerated when needed.';

  @override
  String get settingsStorageMeasuring => 'Measuring…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size in use';
  }

  @override
  String get settingsStorageClearButton => 'Clear cache';

  @override
  String get settingsStorageClearConfirmTitle => 'Clear cached media?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'This frees up $size. Your clip library is not affected.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Clear';

  @override
  String get settingsStorageCleared => 'Cache cleared';

  @override
  String get settingsStorageLibrarySectionTitle => 'Clip library';

  @override
  String get settingsStorageLibraryDescription =>
      'Check for broken clips whose video file is missing.';

  @override
  String get settingsStorageScanButton => 'Check library';

  @override
  String get settingsStorageLibraryHealthy => 'No broken clips found';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Broken clips found: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Remove broken clips';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Broken clips removed';

  @override
  String get settingsStorageError => 'Something went wrong';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Maximum video cache';

  @override
  String settingsStorageApproxVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '≈ $count videos',
      one: '≈ $count video',
    );
    return '$_temp0';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle => 'Remove broken clips?';

  @override
  String get settingsStorageRepairSectionTitle => 'Repair install';

  @override
  String get settingsStorageRepairDescription =>
      'If the app keeps crashing or acting strange, resetting its local data usually fixes it. Your clips and drafts stay.';

  @override
  String get settingsStorageRepairButton => 'Reset app data';

  @override
  String get settingsStorageRepairConfirmTitle => 'Reset app data?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'This clears cached feed data and temporary files. Your clips, drafts, settings and sign-in stay, but you\'ll need to restart the app afterwards.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size will be removed';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Reset';

  @override
  String get settingsStorageRepairInProgress => 'Resetting…';

  @override
  String get settingsStorageRepairSuccess =>
      'Done — restart the app to finish.';

  @override
  String get settingsStorageRepairFailure =>
      'Couldn\'t reset everything. Try again after a restart.';

  @override
  String get nostrSettingsSignatureVerification => 'Signature verification';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Choose when Divine checks relay event signatures. Event IDs are always validated first.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'All relays';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Safest. Verify every relay event signature.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => 'Untrusted relays';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Skip checks for relays already in your configured pool.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Non-Divine relays';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Trust Divine relays, verify the rest.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle =>
      'Share your videos to other platforms';

  @override
  String get crosspostingSignInRequired =>
      'Sign in with Divine to manage crossposting';

  @override
  String get crosspostingLoadFailed =>
      'Couldn\'t load your crossposting settings';

  @override
  String get crosspostingNoPlatforms =>
      'No crossposting platforms are available right now';

  @override
  String get crosspostingRetry => 'Retry';

  @override
  String get crosspostingNotConnected => 'Not connected';

  @override
  String get crosspostingConnected => 'Connected';

  @override
  String get crosspostingNeedsReconnect => 'Needs reconnecting';

  @override
  String get crosspostingConnect => 'Connect';

  @override
  String get crosspostingReconnect => 'Reconnect';

  @override
  String get crosspostingDisconnect => 'Disconnect';

  @override
  String get crosspostingModeOff => 'Off';

  @override
  String get crosspostingModeManual => 'Manual';

  @override
  String get crosspostingModeManualSubtitle => 'You choose per video';

  @override
  String get crosspostingModeAutomatic => 'Automatic';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Future videos post automatically — only videos published after you turn this on';

  @override
  String get crosspostingNotConnectedError =>
      'Connect this platform first to change how it posts.';

  @override
  String get crosspostingGenericError => 'Something went wrong. Try again.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'We never heard back from the sign-in page. If you finished connecting there, refresh — your account may already be linked.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform connected';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Couldn\'t connect $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Connection was canceled on $platform';
  }

  @override
  String get supporterTitle => 'Divine Supporters';

  @override
  String get supporterTileSubtitle =>
      'Support Divine with an optional monthly subscription.';

  @override
  String get supporterHeroTitle => 'Keep Divine running';

  @override
  String get supporterHeroBody =>
      'Divine is free and always will be. If you want to help us keep the loops going, become a monthly supporter. Nothing is locked — it just keeps the lights on and earns our thanks.';

  @override
  String get supporterActiveBadge =>
      'You\'re a Divine Supporter. Thank you for keeping this going.';

  @override
  String get supporterPurchasePending => 'Your purchase is pending approval.';

  @override
  String get supporterPurchaseConfirming => 'Confirming your support…';

  @override
  String get supporterStoreChecking => 'Checking the store…';

  @override
  String get supporterUnavailable =>
      'Supporter subscriptions are not available here right now.';

  @override
  String get supporterRestorePurchases => 'Restore purchases';

  @override
  String get supporterDismissError => 'Dismiss error';

  @override
  String get supporterErrorStoreUnavailable =>
      'The store is unavailable on this device.';

  @override
  String get supporterErrorPurchaseFailed =>
      'The purchase did not complete. You were not charged.';

  @override
  String get supporterErrorPurchasePending =>
      'Your purchase is pending approval.';

  @override
  String get supporterErrorRestoreFailed =>
      'No supporter subscription was found to restore.';

  @override
  String get supporterErrorOwnershipConflict =>
      'This purchase belongs to another Divine account.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine could not confirm supporter status right now.';

  @override
  String get supporterErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get supporterDisclaimer =>
      'Divine confirms supporter status after the store verifies your purchase. Recognition is optional, and the halo is not verification.';

  @override
  String get profileNotifyBellOff => 'Get notified about new vines';

  @override
  String get profileNotifyBellOn => 'Stop notifying me about new vines';

  @override
  String get profileNotifyUpdateFailed => 'Couldn\'t save that. Try again?';

  @override
  String get savedSoundYourLabel => 'Your label';

  @override
  String get savedSoundAddHashtags => 'Add hashtags';

  @override
  String get savedSoundDeviceOnly => 'Saved on this device';

  @override
  String get savedSoundDetailsRetry =>
      'Couldn’t save those details. Tap to retry.';

  @override
  String get savedSoundFallbackTitle => 'Saved sound';

  @override
  String get savedSoundPreviewAction => 'Preview sound';

  @override
  String get savedSoundEditAction => 'Edit sound details';

  @override
  String get savedSoundRemoveAction => 'Remove saved sound';

  @override
  String get savedSoundClearHashtagFilter => 'Clear hashtag filter';

  @override
  String get soundAllowRemix => 'Allow others to remix this sound';

  @override
  String get soundReuseUnavailable => 'This sound can\'t be remixed right now.';

  @override
  String get soundPublicCredit => 'Public sound credit';

  @override
  String get soundCreditRequired => 'Add public sound credit before posting.';

  @override
  String get soundSharedAs => 'Shared as';

  @override
  String get soundOwnWork => 'I made this sound';

  @override
  String soundCreatorBy(String creator) {
    return 'By $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Shared by $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remixing allowed';

  @override
  String get soundCreditOnly => 'Credit only';

  @override
  String get soundCreditTitleLabel => 'Sound title';

  @override
  String get soundCreditCreatorLabel => 'Creator';

  @override
  String get soundCreditSourceUrlLabel => 'Source URL';

  @override
  String get soundCreditPublicHashtagsLabel => 'Public hashtags';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Cancel tag selection';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Apply selected tags';

  @override
  String get userPickerCancelSemanticLabel => 'Cancel user selection';

  @override
  String get userPickerConfirmSemanticLabel => 'Confirm selected users';

  @override
  String get userPickerClearSelectionSemanticLabel => 'Clear user selection';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Cancel content warning selection';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Apply selected content warnings';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Close video editor';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Continue to post details';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Discard changes in $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Apply changes in $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Remove audio';

  @override
  String rgbColorSemanticLabel(int red, int green, int blue) {
    return 'RGB $red, $green, $blue';
  }

  @override
  String videoEditorColorPickerSwatchSemanticLabel(
    String picker,
    String color,
  ) {
    return '$picker, $color';
  }

  @override
  String get verifyTitle => 'Verified accounts';

  @override
  String get verifySignedOutMessage => 'Sign in to link your accounts.';

  @override
  String get verifyIntro =>
      'Link accounts you already have, so people can tell it\'s really you.';

  @override
  String get verifyLoadFailed => 'Couldn\'t load your links.';

  @override
  String get verifyRetry => 'Try again';

  @override
  String get verifyLinkedSectionTitle => 'Linked';

  @override
  String get verifyVerifierUnreachable =>
      'Couldn\'t reach the verifier, so these show as unchecked.';

  @override
  String get verifyAddSectionTitle => 'Add an account';

  @override
  String get verifyAllPlatformsLinked =>
      'You\'ve linked everything we support.';

  @override
  String get verifyStatusVerified => 'Verified';

  @override
  String get verifyStatusUnverified => 'Not verified';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Unlink $platform account $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Unlink $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity stops showing on your profile. You can link it again later, but you will have to sign in or post a new proof.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Unlink';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Link your $platform account';
  }

  @override
  String get verifyOneTapBadge => 'One tap';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Sign in to $platform and we\'ll handle the rest. Nothing gets posted.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Continue with $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Or post a proof';

  @override
  String get verifyConnectProofExplainer =>
      'Post your npub on your account, then paste the link to that post.';

  @override
  String get verifyNpubLabel => 'Your npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Copy your npub';

  @override
  String get verifyNpubCopied => 'npub copied';

  @override
  String get verifyIdentityLabel => 'Account name';

  @override
  String get verifyProofLabel => 'Link to your post';

  @override
  String get verifyConnectProofCta => 'Check and link';

  @override
  String get verifyErrorProofRejected =>
      'That didn\'t check out. Check the link and the account name, then try again.';

  @override
  String get verifyErrorProofMissingNpub =>
      'We couldn\'t find your npub in that post.';

  @override
  String get verifyErrorDiscordDmLink =>
      'That\'s a link to a DM, which our bot can\'t read. Post your npub in a server channel instead.';

  @override
  String get verifyErrorDiscordChannelLink =>
      'That\'s a link to the channel, not your message. Long-press your message and pick Copy Message Link.';

  @override
  String get verifyErrorDiscordMessageNotFound =>
      'We couldn\'t find that message. Check the link, and make sure the message is still up.';

  @override
  String get verifyErrorDiscordBotNoAccess =>
      'Our bot can\'t read that channel. Post your npub somewhere it can see.';

  @override
  String get verifyErrorDiscordAuthorMismatch =>
      'That message is from a different account. Use your Discord username — the one on your profile, not your display name.';

  @override
  String get verifyErrorDiscordContentUnavailable =>
      'We couldn\'t read that message\'s text. That\'s on us — please tell support.';

  @override
  String get verifyErrorVerifierUnreachable =>
      'Couldn\'t reach the verifier. Try again in a moment.';

  @override
  String get verifyErrorOauthFailed =>
      'That didn\'t go through. Give it another go.';

  @override
  String get verifyErrorHandleRequired => 'Enter your handle first.';

  @override
  String get verifyErrorPublishFailed =>
      'Verified, but no relay took the update. Try again.';

  @override
  String get verifyErrorOauthUnavailable =>
      'One-tap sign-in isn\'t set up for this one yet. Use the proof post below.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Make a public gist with your npub in the first file, then paste the gist link.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Post your npub in a Discord channel our bot can read, then paste the message link. A server invite proves nothing.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tweet your npub from that account, then paste the link to the tweet.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Post your npub from that account, then paste the link. The account name needs its instance — mastodon.social/@alice, not just alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'The channel gets linked, not your Telegram account. It needs a public link first (Telegram makes new ones private). Post your npub there and paste the message link.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Signed in above? Nothing else needed. Otherwise post your npub and paste the link to that post.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Put your npub in a video caption, then paste the link to that video.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Put your npub in a video description, then paste the link to that video.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform is linked.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'That\'s a private channel or an invite. Give the channel a public link, then paste the message link.';

  @override
  String get verifyErrorRemoveFailed => 'Couldn\'t unlink that. Try again.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Couldn\'t read your current links, so nothing was changed. Check your connection and try again.';

  @override
  String get verifyChannelLabel => 'Channel name';

  @override
  String get verifyHowItWorksTitle => 'How does it work?';

  @override
  String get verifyHowItWorksIntro =>
      'Think of it as a handshake between two accounts:';

  @override
  String get verifyHowItWorksYourSide =>
      'Your Divine profile says: “I\'m @alice on Twitter.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Your Twitter account confirms: “Yes, that Divine profile is mine.”';

  @override
  String get verifyHowItWorksBothSides =>
      'We check both sides. If they match, you\'re verified. Nobody can fake it — someone can copy your name and photo, but they can\'t post from your real account.';

  @override
  String get verifyHowItWorksOwnership =>
      'The links live on your own Nostr identity, so you can remove any of them here whenever you want.';

  @override
  String get generalSettingsSectionIdentity => 'Identity';

  @override
  String get libraryFilterAll => 'All';

  @override
  String get libraryFilterArchive => 'Archive';

  @override
  String get libraryFilterDeleted => 'Deleted';

  @override
  String get libraryCategoryNewChipLabel => 'New';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Create a category';

  @override
  String get libraryCategoryCreateTitle => 'New category';

  @override
  String get libraryCategoryCreateAction => 'Create';

  @override
  String get libraryCategoryRenameTitle => 'Rename category';

  @override
  String get libraryCategoryRenameAction => 'Rename';

  @override
  String get libraryCategoryDeleteAction => 'Delete category';

  @override
  String get libraryCategoryNameLabel => 'Category name';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Your clips stay put. They just move back to All.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Rename or delete this category';

  @override
  String get libraryCategoryMoveTitle => 'Move to';

  @override
  String get libraryCategoryMoveNone => 'No category';

  @override
  String get libraryCategoryMoveNewCategory => 'New category';

  @override
  String get libraryArchiveAction => 'Archive';

  @override
  String get libraryUnarchiveAction => 'Unarchive';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keep in these categories?',
      one: 'Keep in this category?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Keep in $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'Keep in their categories';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Remove from $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Remove from their categories';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Move selected clips';

  @override
  String get libraryCategoryEmptyTitle => 'Nothing filed here yet';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Select a few clips and move them into this category.';

  @override
  String get libraryArchiveEmptyTitle => 'Nothing archived';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Archived clips wait here, out of the way of your main library.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips moved to $name',
      one: '1 clip moved to $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips removed from their category',
      one: '1 clip removed from its category',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips archived',
      one: '1 clip archived',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips back in your library',
      one: '1 clip back in your library',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Change email';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Move your account to a different address';

  @override
  String get accountSettingsChangePassword => 'Change password';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Pick a new password for signing in';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Your session ran out. Sign in again to make this change.';

  @override
  String get accountCredentialsRateLimited =>
      'Too many tries. Give it a few minutes.';

  @override
  String get accountCredentialsNetwork =>
      'Couldn\'t reach Divine. Check your connection and try again.';

  @override
  String get accountCredentialsUnknown =>
      'That didn\'t work. Please try again.';

  @override
  String get changePasswordSubtitle =>
      'Type your current password, then pick a new one.';

  @override
  String get changePasswordCurrentLabel => 'Current password';

  @override
  String get changePasswordWrongCurrent => 'That\'s not your current password.';

  @override
  String get changePasswordSuccess => 'Password changed.';

  @override
  String get changeEmailSubtitle =>
      'We\'ll email a confirmation link to your new address and to the one on your account. Your email changes once you confirm from both.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'On your account: $email';
  }

  @override
  String get changeEmailNewLabel => 'New email';

  @override
  String get changeEmailPasswordLabel => 'Your password';

  @override
  String get changeEmailSameAsCurrent => 'That\'s already your email address.';

  @override
  String get changeEmailWrongPassword => 'That\'s not your password.';

  @override
  String get changeEmailSubmit => 'Send confirmation links';

  @override
  String get changeEmailSentTitle => 'Two links are on their way';

  @override
  String changeEmailSentMessage(String email) {
    return 'Confirm from $email and from the address on your account. Your email switches once both are done.';
  }

  @override
  String get changeEmailSentExpiry => 'The links stop working after 24 hours.';

  @override
  String get changeEmailSentDone => 'Got it';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount videos',
      one: '$formattedCount video',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Mutual';

  @override
  String get socialProofFollowsYou => 'Follows you';

  @override
  String get socialProofYouFollow => 'You follow';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount followers',
      one: '$formattedCount follower',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Videos aren\'t loading right now.\nIt\'s us, not you — we\'re on it.';

  @override
  String get feedOfflineMessage =>
      'You\'re offline.\nCheck your connection and try again.';

  @override
  String get dbFailureTitle => 'couldn\'t unlock your local database';

  @override
  String get dbFailureAdviceResettable =>
      'A restart won\'t fix this one. Resetting the local database below gives Divine a clean start — your account stays.';

  @override
  String get dbFailureAdviceRestart =>
      'Restart Divine after unlocking your device. If this keeps happening, update the app or contact support.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Try restarting Divine once. If this keeps happening, update the app or contact support. Your local data is still here.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostic: $code';
  }

  @override
  String get dbFailureCloseApp => 'close Divine';

  @override
  String get dbFailureResetAction => 'reset local database';

  @override
  String get dbFailureConfirmTitle => 'reset your local database?';

  @override
  String get dbFailureConfirmBody =>
      'Your account stays. Drafts and clips saved on this device are deleted — messages and feeds come back from the network.';

  @override
  String get dbFailureResetConfirm => 'reset local database now';

  @override
  String get dbFailureCancel => 'cancel';

  @override
  String get dbFailureResetFailed =>
      'That didn\'t work. Close Divine and try again.';

  @override
  String get dbFailureResetDoneTitle => 'local database reset';

  @override
  String get dbFailureResetDoneBody =>
      'Close Divine and open it again — the next launch builds a fresh local database.';

  @override
  String get authSignInOptionsInfo => 'About sign-in options';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get followUserSemanticLabel => 'Follow user';

  @override
  String get unfollowUserSemanticLabel => 'Unfollow user';

  @override
  String get commentsLoadingSemanticLabel => 'Loading comments';

  @override
  String get analyticsWindowAll => 'All';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Follow user $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Unfollow user $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / month';
  }

  @override
  String get videoDetailHiddenBySettingsTitle => 'Hidden by your settings';

  @override
  String videoDetailHiddenByHostFilterBody(String host) {
    return 'This one\'s hosted on $host, and you\'re set to only show Divine-hosted videos.';
  }

  @override
  String get videoDetailHiddenByContentFilterBody =>
      'Your content filters are hiding this one.';

  @override
  String get videoDetailHiddenByProvenanceFilterBody =>
      'This one has no capture chain back to a camera, and you\'re set to only show camera-verified videos.';

  @override
  String get videoDetailHiddenShowAnyway => 'Show it anyway';

  @override
  String get videoDetailHiddenOpenSettings => 'Change setting';

  @override
  String get safetySettingsShowVerifiedOnly =>
      'Only show camera-verified videos';

  @override
  String get safetySettingsShowVerifiedOnlySubtitle =>
      'Hide videos without a capture chain back to a camera. Vine archive videos are always shown.';

  @override
  String get accountStatusTitle => 'Account status';

  @override
  String get accountStatusTileSubtitleRestricted =>
      'Your account is restricted';

  @override
  String get accountStatusAllClearHeading => 'Everything looks good!';

  @override
  String get profileAccountRestricted => 'Account restricted';

  @override
  String get accountStatusSuspendedHeading => 'Your account is suspended';

  @override
  String get accountStatusSuspendedBody =>
      'You can\'t post, comment, or send messages on Divine right now. Your videos are hidden rather than deleted, and they come back if the suspension is lifted.';

  @override
  String get accountStatusBannedHeading => 'Your account is banned';

  @override
  String get accountStatusBannedBody =>
      'You can\'t post, comment, or send messages on Divine, and your videos have been taken down from Divine.';

  @override
  String get accountStatusRestrictedHeading => 'Your account is restricted';

  @override
  String get accountStatusRestrictedBody =>
      'Some things you can normally do on Divine are unavailable right now. Updating the app may show you more detail.';

  @override
  String get accountStatusLastKnownBody =>
      'We couldn\'t refresh your status. This is the last status we received.';

  @override
  String get accountStatusUnavailableHeading =>
      'We couldn\'t check your status';

  @override
  String get accountStatusUnavailableBody =>
      'Check your connection and try again.';

  @override
  String get accountStatusSignedOutHeading =>
      'Sign in to check your account status';

  @override
  String get accountStatusSignedOutBody =>
      'There isn\'t a signed-in account to check right now.';

  @override
  String get accountStatusKeysUnaffectedHeading =>
      'Your account still belongs to you';

  @override
  String get accountStatusKeysUnaffectedBody =>
      'This restriction applies to Divine. Your keys and your identity are yours, your followers travel with them, and you can keep using them on other apps and servers that Divine doesn\'t run.';

  @override
  String get accountStatusAppealHeading => 'If you think this is wrong';

  @override
  String get accountStatusAppealBody =>
      'Divine may review requests to reconsider a moderation decision, but is not obligated to. If you want to raise it, contact support and tell us what happened.';

  @override
  String get accountStatusContactSupport => 'Contact support';

  @override
  String get accountStatusMoveAccount => 'Move your account';

  @override
  String get accountStatusRetry => 'Try again';

  @override
  String get updateGentleBanner =>
      'A fresh update just dropped. Check it out →';

  @override
  String get updateModerateTitle =>
      'There\'s been an update since you last checked';

  @override
  String get updateUrgentTitle => 'You\'re missing important fixes';

  @override
  String get updateNotNow => 'Not now';

  @override
  String get updateAction => 'Update';

  @override
  String updateNewIn(String version) {
    return 'New in $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Update available';
}

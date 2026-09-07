import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_bg.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fil.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_te.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('am'),
    Locale('ar'),
    Locale('bg'),
    Locale('de'),
    Locale('es'),
    Locale('fil'),
    Locale('fr'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('ms'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ro'),
    Locale('sv'),
    Locale('te'),
    Locale('tr'),
    Locale('ur'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// Header of the Developer Options section that recovers clips the app can no longer show.
  ///
  /// In en, this message translates to:
  /// **'Clip Recovery'**
  String get devOptionsClipRecovery;

  /// Explains that the tool finds clips hidden under another account plus video files with no database row.
  ///
  /// In en, this message translates to:
  /// **'Finds recordings stored under another account and video files no entry references any more.'**
  String get devOptionsClipRecoveryDescription;

  /// Button that starts the clip-recovery scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get devOptionsClipRecoveryScan;

  /// Shown when the clip-recovery scan failed.
  ///
  /// In en, this message translates to:
  /// **'Clip recovery failed'**
  String get devOptionsClipRecoveryFailure;

  /// How much of the local library the signed-in account can already see.
  ///
  /// In en, this message translates to:
  /// **'Visible now: {clips, plural, =1{{clips} clip} other{{clips} clips}}, {drafts, plural, =1{{drafts} draft} other{{drafts} drafts}}'**
  String devOptionsClipRecoveryVisible(int clips, int drafts);

  /// Subheading above the groups of rows stored under a different account.
  ///
  /// In en, this message translates to:
  /// **'Hidden under other accounts'**
  String get devOptionsClipRecoveryOtherAccounts;

  /// How many clips and drafts one owner group holds.
  ///
  /// In en, this message translates to:
  /// **'{clips, plural, =1{{clips} clip} other{{clips} clips}}, {drafts, plural, =1{{drafts} draft} other{{drafts} drafts}}'**
  String devOptionsClipRecoveryCounts(int clips, int drafts);

  /// Button that restamps an owner group onto the signed-in account.
  ///
  /// In en, this message translates to:
  /// **'Move to this account'**
  String get devOptionsClipRecoveryClaim;

  /// How many video files on disk no database row references, and their total size.
  ///
  /// In en, this message translates to:
  /// **'Unreferenced files: {count} ({size})'**
  String devOptionsClipRecoveryOrphanFiles(int count, String size);

  /// Button that rebuilds library entries for the unreferenced video files.
  ///
  /// In en, this message translates to:
  /// **'Rebuild in library'**
  String get devOptionsClipRecoveryImport;

  /// Shown when a scan found no hidden owners and no unreferenced files.
  ///
  /// In en, this message translates to:
  /// **'Nothing to recover'**
  String get devOptionsClipRecoveryEmpty;

  /// Confirmation of how many clips the last claim or rebuild recovered.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Recovered {count} clip} other{Recovered {count} clips}}'**
  String devOptionsClipRecoveryRecovered(int count);

  /// Confirmation shown after the recovery report is copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Recovery report copied'**
  String get devOptionsClipRecoveryCopied;

  /// Header of the Developer Options section that measures the app's on-disk footprint.
  ///
  /// In en, this message translates to:
  /// **'Storage Footprint'**
  String get devOptionsStorageFootprint;

  /// Explains that the footprint covers more than the caches the Storage screen can clear.
  ///
  /// In en, this message translates to:
  /// **'Every directory the app writes to. Clearing caches only reclaims part of this.'**
  String get devOptionsStorageFootprintDescription;

  /// Button that starts walking every directory the app writes to.
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get devOptionsStorageFootprintMeasure;

  /// Total bytes across every measured directory.
  ///
  /// In en, this message translates to:
  /// **'Total: {size}'**
  String devOptionsStorageFootprintTotal(String size);

  /// Confirmation shown after the footprint report is copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Storage report copied'**
  String get devOptionsStorageFootprintCopied;

  /// Shown when the footprint measurement failed.
  ///
  /// In en, this message translates to:
  /// **'Could not measure storage'**
  String get devOptionsStorageFootprintFailure;

  /// Indicator and snackbar text when the user swipes right to get more videos like the current one.
  ///
  /// In en, this message translates to:
  /// **'More like this'**
  String get feedTuningMoreLabel;

  /// Indicator and snackbar text when the user swipes left to get fewer videos like the current one.
  ///
  /// In en, this message translates to:
  /// **'Less like this'**
  String get feedTuningLessLabel;

  /// Snackbar action that retracts a just-published feed-tuning swipe.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get feedTuningUndo;

  /// Accessibility label for the compact quoted-video preview shown above a DM reply that references a shared video; activating it opens that video.
  ///
  /// In en, this message translates to:
  /// **'Open the referenced video'**
  String get dmMessageBubbleVideoReplyHint;

  /// App title shown in task switcher
  ///
  /// In en, this message translates to:
  /// **'Divine'**
  String get appTitle;

  /// Settings screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSecureAccount.
  ///
  /// In en, this message translates to:
  /// **'Secure Your Account'**
  String get settingsSecureAccount;

  /// No description provided for @settingsSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get settingsSessionExpired;

  /// No description provided for @settingsSessionExpiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to restore full access'**
  String get settingsSessionExpiredSubtitle;

  /// Title of the account-switch confirmation sheet when local keys for the selected account cannot be restored on this device.
  ///
  /// In en, this message translates to:
  /// **'Account Restore Failed'**
  String get settingsAccountRestoreFailed;

  /// Body of the confirmation sheet shown when the account the user picked in the switcher cannot be restored from local keys. Confirming signs the current, working account out to reach the sign-in flow.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.'**
  String get settingsAccountRestoreFailedSwitchMessage;

  /// No description provided for @settingsCreatorAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Creator Analytics'**
  String get settingsCreatorAnalytics;

  /// No description provided for @settingsSupportCenter.
  ///
  /// In en, this message translates to:
  /// **'Support Center'**
  String get settingsSupportCenter;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsBlueskyPublishing.
  ///
  /// In en, this message translates to:
  /// **'Bluesky Publishing'**
  String get settingsBlueskyPublishing;

  /// No description provided for @settingsBlueskyPublishingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage crossposting to Bluesky'**
  String get settingsBlueskyPublishingSubtitle;

  /// No description provided for @settingsNostrSettings.
  ///
  /// In en, this message translates to:
  /// **'Nostr Settings'**
  String get settingsNostrSettings;

  /// No description provided for @settingsIntegratedApps.
  ///
  /// In en, this message translates to:
  /// **'Integrated Apps'**
  String get settingsIntegratedApps;

  /// No description provided for @settingsIntegratedAppsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approved third-party apps that run inside Divine'**
  String get settingsIntegratedAppsSubtitle;

  /// No description provided for @settingsExperimentalFeatures.
  ///
  /// In en, this message translates to:
  /// **'Experimental Features'**
  String get settingsExperimentalFeatures;

  /// No description provided for @settingsExperimentalFeaturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tweaks that may hiccup—try them if you are curious.'**
  String get settingsExperimentalFeaturesSubtitle;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// No description provided for @settingsIntegrationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Integration Permissions'**
  String get settingsIntegrationPermissions;

  /// No description provided for @settingsIntegrationPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and revoke remembered integration approvals'**
  String get settingsIntegrationPermissionsSubtitle;

  /// App version label in settings footer
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// Version label when version string is not yet loaded
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersionEmpty;

  /// No description provided for @settingsDeveloperModeAlreadyEnabled.
  ///
  /// In en, this message translates to:
  /// **'Developer mode is already enabled'**
  String get settingsDeveloperModeAlreadyEnabled;

  /// No description provided for @settingsDeveloperModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Developer mode enabled!'**
  String get settingsDeveloperModeEnabled;

  /// No description provided for @settingsDeveloperModeTapsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} more tap to enable developer mode} other{{count} more taps to enable developer mode}}'**
  String settingsDeveloperModeTapsRemaining(int count);

  /// Button that opens the share sheet with Divine's download link
  ///
  /// In en, this message translates to:
  /// **'Share Divine with your friends'**
  String get settingsShareDivine;

  /// No description provided for @settingsSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get settingsSwitchAccount;

  /// No description provided for @settingsAddAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Add another account'**
  String get settingsAddAnotherAccount;

  /// Snackbar shown when an in-place account switch fails and the current account is kept.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t switch accounts. Please try again.'**
  String get settingsAccountSwitchFailed;

  /// No description provided for @settingsUnsavedDraftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Drafts'**
  String get settingsUnsavedDraftsTitle;

  /// No description provided for @settingsUploadInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload in progress'**
  String get settingsUploadInProgressTitle;

  /// Confirmation shown before an account switch while videos are still uploading. {count} is the number of in-flight uploads.
  ///
  /// In en, this message translates to:
  /// **'You still have {count} {count, plural, =1{video} other{videos}} uploading. Switching accounts stops the upload — your {count, plural, =1{video stays as a draft} other{videos stay as drafts}} in this account.'**
  String settingsUploadInProgressMessage(int count);

  /// No description provided for @settingsUnsavedDraftsMessage.
  ///
  /// In en, this message translates to:
  /// **'You have {count} unsaved {count, plural, =1{draft} other{drafts}}. Switching accounts will keep your {count, plural, =1{draft} other{drafts}}, but you may want to publish or review {count, plural, =1{it} other{them}} first.'**
  String settingsUnsavedDraftsMessage(int count);

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsSwitchAnyway.
  ///
  /// In en, this message translates to:
  /// **'Switch Anyway'**
  String get settingsSwitchAnyway;

  /// Body of the confirmation sheet shown when the account the user picked in the switcher has an unusable session. Confirming signs the current, working account out to reach the sign-in flow, so the copy has to say so.
  ///
  /// In en, this message translates to:
  /// **'That account\'s session ran out. Signing back into it means signing out of the one you\'re on now.'**
  String get settingsSessionExpiredSwitchMessage;

  /// No description provided for @settingsAppVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsAppVersionLabel;

  /// No description provided for @settingsAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguage;

  /// Subtitle for app language tile when using device default
  ///
  /// In en, this message translates to:
  /// **'{language} (device default)'**
  String settingsAppLanguageDeviceDefault(String language);

  /// Title shown at top of locale picker bottom sheet
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguageTitle;

  /// No description provided for @settingsAppLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for the app interface'**
  String get settingsAppLanguageDescription;

  /// No description provided for @settingsAppLanguageUseDeviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get settingsAppLanguageUseDeviceLanguage;

  /// No description provided for @settingsGeneralTitle.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get settingsGeneralTitle;

  /// No description provided for @settingsContentSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Content & Safety'**
  String get settingsContentSafetyTitle;

  /// No description provided for @generalSettingsSectionIntegrations.
  ///
  /// In en, this message translates to:
  /// **'INTEGRATIONS'**
  String get generalSettingsSectionIntegrations;

  /// No description provided for @generalSettingsSectionViewing.
  ///
  /// In en, this message translates to:
  /// **'VIEWING'**
  String get generalSettingsSectionViewing;

  /// No description provided for @generalSettingsSectionCreating.
  ///
  /// In en, this message translates to:
  /// **'CREATING'**
  String get generalSettingsSectionCreating;

  /// No description provided for @generalSettingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'APP'**
  String get generalSettingsSectionApp;

  /// No description provided for @appearanceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSettingsTitle;

  /// No description provided for @appearanceSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how Divine looks on this device'**
  String get appearanceSettingsSubtitle;

  /// No description provided for @appearanceSettingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get appearanceSettingsSystem;

  /// No description provided for @appearanceSettingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceSettingsLight;

  /// No description provided for @appearanceSettingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceSettingsDark;

  /// No description provided for @generalSettingsClosedCaptions.
  ///
  /// In en, this message translates to:
  /// **'Closed Captions'**
  String get generalSettingsClosedCaptions;

  /// No description provided for @generalSettingsClosedCaptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show captions when videos include them'**
  String get generalSettingsClosedCaptionsSubtitle;

  /// No description provided for @generalSettingsVideoShapeSquareOnly.
  ///
  /// In en, this message translates to:
  /// **'Square videos only'**
  String get generalSettingsVideoShapeSquareOnly;

  /// No description provided for @generalSettingsVideoShapeSquareOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep feeds in the classic square format'**
  String get generalSettingsVideoShapeSquareOnlySubtitle;

  /// Content preferences screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Content Preferences'**
  String get contentPreferencesTitle;

  /// No description provided for @contentPreferencesContentFilters.
  ///
  /// In en, this message translates to:
  /// **'Content Filters'**
  String get contentPreferencesContentFilters;

  /// No description provided for @contentPreferencesContentFiltersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage content warning filters'**
  String get contentPreferencesContentFiltersSubtitle;

  /// No description provided for @contentPreferencesContentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Content Language'**
  String get contentPreferencesContentLanguage;

  /// No description provided for @contentPreferencesContentLanguageDeviceDefault.
  ///
  /// In en, this message translates to:
  /// **'{language} (device default)'**
  String contentPreferencesContentLanguageDeviceDefault(String language);

  /// No description provided for @contentPreferencesTagYourVideos.
  ///
  /// In en, this message translates to:
  /// **'Tag your videos with a language so viewers can filter content.'**
  String get contentPreferencesTagYourVideos;

  /// No description provided for @contentPreferencesUseDeviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use device language (default)'**
  String get contentPreferencesUseDeviceLanguage;

  /// No description provided for @contentPreferencesAudioSharing.
  ///
  /// In en, this message translates to:
  /// **'Make my audio available for reuse'**
  String get contentPreferencesAudioSharing;

  /// No description provided for @contentPreferencesAudioSharingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, others can use audio from your videos'**
  String get contentPreferencesAudioSharingSubtitle;

  /// No description provided for @contentPreferencesMusicMode.
  ///
  /// In en, this message translates to:
  /// **'Music mode'**
  String get contentPreferencesMusicMode;

  /// Explains the trade-off behind the Music mode switch in Settings -> Content Preferences. Enabling it drops the platform's speech-tuned noise suppression, so instruments keep their real level but spoken audio loses the cleanup that flatters it.
  ///
  /// In en, this message translates to:
  /// **'Skips the noise cleanup that flattens instruments. Better for music, rougher on voices.'**
  String get contentPreferencesMusicModeSubtitle;

  /// No description provided for @contentPreferencesAccountLabels.
  ///
  /// In en, this message translates to:
  /// **'Account Labels'**
  String get contentPreferencesAccountLabels;

  /// No description provided for @contentPreferencesAccountLabelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Self-label your content'**
  String get contentPreferencesAccountLabelsEmpty;

  /// No description provided for @contentPreferencesAccountContentLabels.
  ///
  /// In en, this message translates to:
  /// **'Account Content Labels'**
  String get contentPreferencesAccountContentLabels;

  /// No description provided for @contentPreferencesClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get contentPreferencesClearAll;

  /// No description provided for @contentPreferencesSelectAllThatApply.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply to your account'**
  String get contentPreferencesSelectAllThatApply;

  /// No description provided for @contentPreferencesDoneNoLabels.
  ///
  /// In en, this message translates to:
  /// **'Done (No Labels)'**
  String get contentPreferencesDoneNoLabels;

  /// No description provided for @contentPreferencesDoneCount.
  ///
  /// In en, this message translates to:
  /// **'Done ({count} selected)'**
  String contentPreferencesDoneCount(int count);

  /// No description provided for @contentPreferencesAudioInputDevice.
  ///
  /// In en, this message translates to:
  /// **'Audio Input Device'**
  String get contentPreferencesAudioInputDevice;

  /// No description provided for @contentPreferencesAutoRecommended.
  ///
  /// In en, this message translates to:
  /// **'Auto (recommended)'**
  String get contentPreferencesAutoRecommended;

  /// No description provided for @contentPreferencesAutoSelectsBest.
  ///
  /// In en, this message translates to:
  /// **'Automatically selects the best microphone'**
  String get contentPreferencesAutoSelectsBest;

  /// No description provided for @contentPreferencesSelectAudioInput.
  ///
  /// In en, this message translates to:
  /// **'Select Audio Input'**
  String get contentPreferencesSelectAudioInput;

  /// No description provided for @contentPreferencesUnknownMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Unknown Microphone'**
  String get contentPreferencesUnknownMicrophone;

  /// No description provided for @contentFiltersAdultContent.
  ///
  /// In en, this message translates to:
  /// **'ADULT CONTENT'**
  String get contentFiltersAdultContent;

  /// No description provided for @contentFiltersViolenceGore.
  ///
  /// In en, this message translates to:
  /// **'VIOLENCE & GORE'**
  String get contentFiltersViolenceGore;

  /// No description provided for @contentFiltersSubstances.
  ///
  /// In en, this message translates to:
  /// **'SUBSTANCES'**
  String get contentFiltersSubstances;

  /// No description provided for @contentFiltersOther.
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get contentFiltersOther;

  /// No description provided for @contentFiltersAgeGateMessage.
  ///
  /// In en, this message translates to:
  /// **'Verify your age in Safety & Privacy settings to unlock adult content filters'**
  String get contentFiltersAgeGateMessage;

  /// No description provided for @contentFiltersShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get contentFiltersShow;

  /// No description provided for @contentFiltersWarn.
  ///
  /// In en, this message translates to:
  /// **'Warn'**
  String get contentFiltersWarn;

  /// No description provided for @contentFiltersFilterOut.
  ///
  /// In en, this message translates to:
  /// **'Filter Out'**
  String get contentFiltersFilterOut;

  /// No description provided for @profileBlockedAccountNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This account is not available'**
  String get profileBlockedAccountNotAvailable;

  /// No description provided for @profileInvalidId.
  ///
  /// In en, this message translates to:
  /// **'Invalid profile ID'**
  String get profileInvalidId;

  /// No description provided for @profileShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out {displayName} on Divine!\n\nhttps://divine.video/profile/{npub}'**
  String profileShareText(String displayName, String npub);

  /// No description provided for @profileShareSubject.
  ///
  /// In en, this message translates to:
  /// **'{displayName} on Divine'**
  String profileShareSubject(String displayName);

  /// No description provided for @profileShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share profile. Please try again.'**
  String get profileShareFailed;

  /// No description provided for @profileCopyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Copy public key (npub)'**
  String get profileCopyPublicKey;

  /// No description provided for @profileGetEmbedCode.
  ///
  /// In en, this message translates to:
  /// **'Get embed code'**
  String get profileGetEmbedCode;

  /// No description provided for @profilePublicKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Public key copied to clipboard'**
  String get profilePublicKeyCopied;

  /// No description provided for @profileEmbedCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Embed code copied to clipboard'**
  String get profileEmbedCodeCopied;

  /// No description provided for @profileMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get profileMoreTooltip;

  /// No description provided for @profileMoreSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get profileMoreSemanticLabel;

  /// Screen-reader label for the dismissable scrim behind the maximized profile-avatar dialog. Read aloud when focus lands on the barrier.
  ///
  /// In en, this message translates to:
  /// **'Close avatar'**
  String get profileAvatarLightboxBarrierLabel;

  /// Screen-reader label for the maximized profile-avatar dialog's tap-to-close gesture detector.
  ///
  /// In en, this message translates to:
  /// **'Close avatar preview'**
  String get profileAvatarLightboxCloseSemanticLabel;

  /// No description provided for @profileFollowingLabel.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowingLabel;

  /// No description provided for @profileFollowLabel.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollowLabel;

  /// No description provided for @profileBlockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get profileBlockedLabel;

  /// No description provided for @profileFollowersLabel.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileFollowersLabel;

  /// No description provided for @profileFollowingStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowingStatLabel;

  /// No description provided for @profileVideosLabel.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get profileVideosLabel;

  /// Accessible name for the Collabs tab on a profile. The tab is icon-only, so this is the only name a screen reader can read. Refers to collaboration videos, not the collaborators themselves.
  ///
  /// In en, this message translates to:
  /// **'Collabs'**
  String get profileCollabsLabel;

  /// Accessible name for the Liked tab on a profile. The tab is icon-only. Refers to videos this user liked — distinct from profileLikesLabel, which counts likes received.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get profileLikedLabel;

  /// Accessible name for the Reposts tab on a profile. The tab is icon-only.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get profileRepostsLabel;

  /// Accessible name for the Lists tab on the own profile. The tab is icon-only.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get profileListsLabel;

  /// Accessible name for the Comments tab on a profile. The tab is icon-only.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get profileCommentsLabel;

  /// No description provided for @profileCollaboratorInvitePendingHeadline.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 collaborator invite still needs to send} other{{count} collaborator invites still need to send}}'**
  String profileCollaboratorInvitePendingHeadline(int count);

  /// No description provided for @profileCollaboratorInvitePendingDetail.
  ///
  /// In en, this message translates to:
  /// **'We kept the invite queued. Retry it here.'**
  String get profileCollaboratorInvitePendingDetail;

  /// No description provided for @profileCollaboratorInvitePendingDetailWithTitle.
  ///
  /// In en, this message translates to:
  /// **'For \"{title}\". Retry it here.'**
  String profileCollaboratorInvitePendingDetailWithTitle(String title);

  /// No description provided for @profileCollaboratorInviteRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get profileCollaboratorInviteRetryAction;

  /// No description provided for @profileCollaboratorInviteRetryingAction.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get profileCollaboratorInviteRetryingAction;

  /// No description provided for @profileCollaboratorInviteRetryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Collaborator invite retry is unavailable right now.'**
  String get profileCollaboratorInviteRetryUnavailable;

  /// No description provided for @profileCollaboratorInviteRetryResult.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Collaborator invites sent.} =1{1 collaborator invite still needs to send.} other{{count} collaborator invites still need to send.}}'**
  String profileCollaboratorInviteRetryResult(int count);

  /// Shown after retrying queued collaborator invites when some were terminally dropped because the collaborator is not an approved DM recipient (a confirmed #176 protected-minor policy block). The invite can never be delivered, so it is reported separately from invites that still need to send.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 collaborator can\'t receive invites.} other{{count} collaborators can\'t receive invites.}}'**
  String profileCollaboratorInviteBlockedResult(int count);

  /// No description provided for @profileFollowerCountUsers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} user} other{{count} users}}'**
  String profileFollowerCountUsers(int count);

  /// No description provided for @profileBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {displayName}?'**
  String profileBlockTitle(String displayName);

  /// No description provided for @profileBlockExplanation.
  ///
  /// In en, this message translates to:
  /// **'When you block a user:'**
  String get profileBlockExplanation;

  /// No description provided for @profileBlockBulletHidePosts.
  ///
  /// In en, this message translates to:
  /// **'Their posts will not appear in your feeds.'**
  String get profileBlockBulletHidePosts;

  /// No description provided for @profileBlockBulletCantView.
  ///
  /// In en, this message translates to:
  /// **'They will be unable to view your profile, follow you, or view your posts.'**
  String get profileBlockBulletCantView;

  /// No description provided for @profileBlockBulletNoNotify.
  ///
  /// In en, this message translates to:
  /// **'They will not be notified of this change.'**
  String get profileBlockBulletNoNotify;

  /// No description provided for @profileBlockBulletYouCanView.
  ///
  /// In en, this message translates to:
  /// **'You will still be able to view their profile.'**
  String get profileBlockBulletYouCanView;

  /// No description provided for @profileBlockConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Block {displayName}'**
  String profileBlockConfirmButton(String displayName);

  /// No description provided for @profileCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancelButton;

  /// No description provided for @profileLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get profileLearnMore;

  /// No description provided for @profileUnblockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unblock {displayName}?'**
  String profileUnblockTitle(String displayName);

  /// No description provided for @profileUnblockExplanation.
  ///
  /// In en, this message translates to:
  /// **'When you unblock this user:'**
  String get profileUnblockExplanation;

  /// No description provided for @profileUnblockBulletShowPosts.
  ///
  /// In en, this message translates to:
  /// **'Their posts will appear in your feeds.'**
  String get profileUnblockBulletShowPosts;

  /// No description provided for @profileUnblockBulletCanView.
  ///
  /// In en, this message translates to:
  /// **'They will be able to view your profile, follow you, and view your posts.'**
  String get profileUnblockBulletCanView;

  /// No description provided for @profileUnblockBulletNoNotify.
  ///
  /// In en, this message translates to:
  /// **'They will not be notified of this change.'**
  String get profileUnblockBulletNoNotify;

  /// No description provided for @profileLearnMoreAt.
  ///
  /// In en, this message translates to:
  /// **'Learn more at '**
  String get profileLearnMoreAt;

  /// No description provided for @profileUnblockButton.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get profileUnblockButton;

  /// No description provided for @profileUnfollowDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Unfollow {displayName}'**
  String profileUnfollowDisplayName(String displayName);

  /// No description provided for @profileBlockDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Block {displayName}'**
  String profileBlockDisplayName(String displayName);

  /// No description provided for @profileUnblockDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Unblock {displayName}'**
  String profileUnblockDisplayName(String displayName);

  /// No description provided for @profileReportDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Report {displayName}'**
  String profileReportDisplayName(String displayName);

  /// No description provided for @profileAddToListDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Add {displayName} to a list'**
  String profileAddToListDisplayName(String displayName);

  /// No description provided for @profileNoCollabsTitle.
  ///
  /// In en, this message translates to:
  /// **'No collabs yet'**
  String get profileNoCollabsTitle;

  /// No description provided for @profileCollabsOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos you collaborate on will appear here.'**
  String get profileCollabsOwnEmpty;

  /// No description provided for @profileCollabsOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos they collaborate on will appear here.'**
  String get profileCollabsOtherEmpty;

  /// No description provided for @profileErrorLoadingCollabs.
  ///
  /// In en, this message translates to:
  /// **'Error loading collab videos'**
  String get profileErrorLoadingCollabs;

  /// No description provided for @profileNoSavedVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get profileNoSavedVideosTitle;

  /// No description provided for @profileSavedOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'Bookmark videos from the share sheet and they\'ll show up here.'**
  String get profileSavedOwnEmpty;

  /// No description provided for @profileErrorLoadingSaved.
  ///
  /// In en, this message translates to:
  /// **'Error loading saved videos'**
  String get profileErrorLoadingSaved;

  /// No description provided for @profileNoCommentsOwnTitle.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get profileNoCommentsOwnTitle;

  /// No description provided for @profileNoCommentsOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get profileNoCommentsOtherTitle;

  /// No description provided for @profileCommentsOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your comments and replies will appear here.'**
  String get profileCommentsOwnEmpty;

  /// No description provided for @profileCommentsOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'Their comments and replies will appear here.'**
  String get profileCommentsOtherEmpty;

  /// No description provided for @profileErrorLoadingComments.
  ///
  /// In en, this message translates to:
  /// **'Error loading comments'**
  String get profileErrorLoadingComments;

  /// No description provided for @profileVideoRepliesSection.
  ///
  /// In en, this message translates to:
  /// **'Video Replies'**
  String get profileVideoRepliesSection;

  /// No description provided for @profileCommentsSection.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get profileCommentsSection;

  /// No description provided for @profileEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEditLabel;

  /// No description provided for @profileLibraryLabel.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get profileLibraryLabel;

  /// No description provided for @profileNoLikedVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'No likes yet'**
  String get profileNoLikedVideosTitle;

  /// No description provided for @profileLikedOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'When something catches your eye, tap the heart. Your likes will show up here.'**
  String get profileLikedOwnEmpty;

  /// No description provided for @profileLikedOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing caught their eye yet. Give it time.'**
  String get profileLikedOtherEmpty;

  /// No description provided for @profileErrorLoadingLiked.
  ///
  /// In en, this message translates to:
  /// **'Error loading liked videos'**
  String get profileErrorLoadingLiked;

  /// No description provided for @profileNoRepostsTitle.
  ///
  /// In en, this message translates to:
  /// **'No reposts yet'**
  String get profileNoRepostsTitle;

  /// No description provided for @profileRepostsOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'See something worth sharing? Repost it and it\'ll appear here.'**
  String get profileRepostsOwnEmpty;

  /// No description provided for @profileRepostsOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'They haven\'t passed anything on yet. When they do, it\'ll show up here.'**
  String get profileRepostsOtherEmpty;

  /// No description provided for @profileErrorLoadingReposts.
  ///
  /// In en, this message translates to:
  /// **'Error loading reposted videos'**
  String get profileErrorLoadingReposts;

  /// No description provided for @profileNoVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'No videos yet'**
  String get profileNoVideosTitle;

  /// No description provided for @profileNoVideosOwnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your stage is set. Start posting and your videos will live here.'**
  String get profileNoVideosOwnSubtitle;

  /// No description provided for @profileNoVideosOtherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The world is waiting. Follow them so you don\'t miss it.'**
  String get profileNoVideosOtherSubtitle;

  /// No description provided for @profileVideoThumbnailLabel.
  ///
  /// In en, this message translates to:
  /// **'Video thumbnail {number}'**
  String profileVideoThumbnailLabel(int number);

  /// No description provided for @profileShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get profileShowMore;

  /// No description provided for @profileShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get profileShowLess;

  /// No description provided for @dmMessageDisplayLimitReached.
  ///
  /// In en, this message translates to:
  /// **'The rest of this message isn\'t displayed.'**
  String get dmMessageDisplayLimitReached;

  /// No description provided for @profileCompleteYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get profileCompleteYourProfile;

  /// No description provided for @profileCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your name, bio, and picture to get started'**
  String get profileCompleteSubtitle;

  /// No description provided for @profilePleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get profilePleaseTryAgain;

  /// No description provided for @profileSecureYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Secure Your Account'**
  String get profileSecureYourAccount;

  /// No description provided for @profileSecureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add email & password to recover your account on any device'**
  String get profileSecureSubtitle;

  /// No description provided for @profileRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get profileRetryButton;

  /// No description provided for @profileSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get profileSessionExpired;

  /// No description provided for @profileSignInToRestore.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to restore full access'**
  String get profileSignInToRestore;

  /// No description provided for @profileSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get profileSignInButton;

  /// No description provided for @profileMaybeLaterLabel.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get profileMaybeLaterLabel;

  /// No description provided for @profileSecurePrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Add Email & Password'**
  String get profileSecurePrimaryButton;

  /// No description provided for @profileCompletePrimaryButton.
  ///
  /// In en, this message translates to:
  /// **'Update Your Profile'**
  String get profileCompletePrimaryButton;

  /// No description provided for @profileLoopsLabel.
  ///
  /// In en, this message translates to:
  /// **'Loops'**
  String get profileLoopsLabel;

  /// No description provided for @profileLikesLabel.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get profileLikesLabel;

  /// No description provided for @profileMyLibraryLabel.
  ///
  /// In en, this message translates to:
  /// **'My Library'**
  String get profileMyLibraryLabel;

  /// No description provided for @profileMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileMessageLabel;

  /// Accessible name of the icon-only share button on the profile action row, on both the viewer's own profile and other people's. Announced by screen readers only; the button shows a share icon and no text.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get profileShareLabel;

  /// Stands in for the display name of an account that requested deletion. A noun phrase used wherever a person's name would normally appear, in DM and non-DM surfaces alike — the inbox row, the conversation header, the following bar, the profile screen and header, the people picker, and the shared people row.
  ///
  /// In en, this message translates to:
  /// **'Deleted account'**
  String get profileDeletedAccountName;

  /// Report action for a direct-message peer whose account was deleted. A complete sentence so each locale controls its grammar.
  ///
  /// In en, this message translates to:
  /// **'Report this account'**
  String get inboxActionReportVanishedAccount;

  /// Block action for a direct-message peer whose account was deleted. A complete sentence so each locale controls its grammar.
  ///
  /// In en, this message translates to:
  /// **'Block this account'**
  String get inboxActionBlockVanishedAccount;

  /// Unblock action for a direct-message peer whose account was deleted. A complete sentence so each locale controls its grammar.
  ///
  /// In en, this message translates to:
  /// **'Unblock this account'**
  String get inboxActionUnblockVanishedAccount;

  /// Confirmation after reporting a direct-message peer whose account was deleted. A complete sentence so each locale controls its grammar.
  ///
  /// In en, this message translates to:
  /// **'Reported this account'**
  String get inboxReportedVanishedAccount;

  /// Confirmation after blocking a direct-message peer whose account was deleted. A complete sentence so each locale controls its grammar.
  ///
  /// In en, this message translates to:
  /// **'Blocked this account'**
  String get inboxBlockedVanishedAccount;

  /// Confirmation after unblocking a direct-message peer whose account was deleted. A complete sentence so each locale controls its grammar.
  ///
  /// In en, this message translates to:
  /// **'Unblocked this account'**
  String get inboxUnblockedVanishedAccount;

  /// Remove-conversation confirmation for a direct-message peer whose account was deleted. Complete copy without a display-name placeholder so each locale controls its grammar.
  ///
  /// In en, this message translates to:
  /// **'This removes the conversation from your inbox. If they message you again, a new conversation starts.'**
  String get inboxRemoveConfirmBodyVanishedAccount;

  /// Shown under the name in a direct-message conversation header when the other participant deleted their account. Replaces their handle.
  ///
  /// In en, this message translates to:
  /// **'This account was deleted'**
  String get inboxConversationDeletedAccountSubtitle;

  /// Generic fallback noun for a user whose display name is unknown. Used in sentences like 'Unfollow {user}?'.
  ///
  /// In en, this message translates to:
  /// **'user'**
  String get profileUserFallback;

  /// No description provided for @profileLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Profile link copied'**
  String get profileLinkCopied;

  /// No description provided for @profileSetupEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileSetupEditProfileTitle;

  /// Empty-state message on NIP-05 settings when the account has not published a profile yet.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile before adding a NIP-05 address.'**
  String get nostrSettingsNip05ProfileRequired;

  /// Button that opens first-profile setup from NIP-05 settings.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get nostrSettingsNip05CreateProfileAction;

  /// No description provided for @profileSetupBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get profileSetupBackLabel;

  /// No description provided for @profileSetupAboutNostr.
  ///
  /// In en, this message translates to:
  /// **'About Nostr'**
  String get profileSetupAboutNostr;

  /// No description provided for @profileSetupProfilePublished.
  ///
  /// In en, this message translates to:
  /// **'Profile published successfully!'**
  String get profileSetupProfilePublished;

  /// No description provided for @profileSetupUnsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save changes?'**
  String get profileSetupUnsavedChangesTitle;

  /// No description provided for @profileSetupUnsavedChangesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your edits before leaving, or discard them and keep moving.'**
  String get profileSetupUnsavedChangesSubtitle;

  /// No description provided for @profileSetupUnsavedChangesSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSetupUnsavedChangesSaveButton;

  /// No description provided for @profileSetupUnsavedChangesDiscardButton.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get profileSetupUnsavedChangesDiscardButton;

  /// No description provided for @profileSetupUnsavedChangesKeepButton.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get profileSetupUnsavedChangesKeepButton;

  /// No description provided for @profileSetupCreateNewProfile.
  ///
  /// In en, this message translates to:
  /// **'Create new profile?'**
  String get profileSetupCreateNewProfile;

  /// No description provided for @profileSetupNoExistingProfile.
  ///
  /// In en, this message translates to:
  /// **'We didn\'t find an existing profile on your relays. Publishing will create a new profile. Continue?'**
  String get profileSetupNoExistingProfile;

  /// No description provided for @profileSetupPublishButton.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get profileSetupPublishButton;

  /// No description provided for @profileSetupUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username was just taken. Please choose another.'**
  String get profileSetupUsernameTaken;

  /// No description provided for @profileSetupClaimFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to claim username. Please try again.'**
  String get profileSetupClaimFailed;

  /// No description provided for @profileSetupPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish profile. Please try again.'**
  String get profileSetupPublishFailed;

  /// No description provided for @profileSetupNoRelaysConnected.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the network. Check your connection and try again.'**
  String get profileSetupNoRelaysConnected;

  /// No description provided for @profileSetupDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get profileSetupDisplayNameLabel;

  /// No description provided for @profileSetupDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a display name'**
  String get profileSetupDisplayNameRequired;

  /// No description provided for @profileSetupBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio (Optional)'**
  String get profileSetupBioLabel;

  /// No description provided for @profileSetupWebsiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website (Optional)'**
  String get profileSetupWebsiteLabel;

  /// Label above the read-only npub row on the edit-profile screen.
  ///
  /// In en, this message translates to:
  /// **'Public key (npub)'**
  String get profileSetupPublicKeyLabel;

  /// No description provided for @profileSetupUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username (Optional)'**
  String get profileSetupUsernameLabel;

  /// No description provided for @profileSetupUsernameHelper.
  ///
  /// In en, this message translates to:
  /// **'Use letters, numbers, or hyphens. Your username becomes a divine.video address. Use your display name for spaces or symbols.'**
  String get profileSetupUsernameHelper;

  /// No description provided for @profileSetupSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSetupSaveButton;

  /// No description provided for @profileSetupSavingButton.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get profileSetupSavingButton;

  /// No description provided for @profileSetupImageUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'Add image URL'**
  String get profileSetupImageUrlTitle;

  /// No description provided for @profileSetupImageSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Image selection failed. Please paste an image URL below instead.'**
  String get profileSetupImageSelectionFailed;

  /// No description provided for @profileSetupImagesTypeGroup.
  ///
  /// In en, this message translates to:
  /// **'images'**
  String get profileSetupImagesTypeGroup;

  /// No description provided for @cameraPickErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Turn it on in Settings to take a photo.'**
  String get cameraPickErrorPermissionDenied;

  /// No description provided for @cameraPickErrorPermissionRestricted.
  ///
  /// In en, this message translates to:
  /// **'Camera access isn\'t allowed on this device.'**
  String get cameraPickErrorPermissionRestricted;

  /// No description provided for @cameraPickErrorBusy.
  ///
  /// In en, this message translates to:
  /// **'The picker is already open. Close it and try again.'**
  String get cameraPickErrorBusy;

  /// No description provided for @cameraPickErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera. Try again.'**
  String get cameraPickErrorGeneric;

  /// No description provided for @profileSetupGotItButton.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get profileSetupGotItButton;

  /// No description provided for @profileSetupUploadFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again later.'**
  String get profileSetupUploadFailedGeneric;

  /// No description provided for @profileSetupUploadNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: Please check your internet connection and try again.'**
  String get profileSetupUploadNetworkError;

  /// No description provided for @profileSetupUploadAuthError.
  ///
  /// In en, this message translates to:
  /// **'Authentication error: Please try logging out and back in.'**
  String get profileSetupUploadAuthError;

  /// No description provided for @profileSetupUploadFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large: Please choose a smaller image (max 10MB).'**
  String get profileSetupUploadFileTooLarge;

  /// No description provided for @profileSetupUploadServerError.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Our servers are temporarily unavailable. Please try again in a moment.'**
  String get profileSetupUploadServerError;

  /// Label on the button that removes the currently selected profile banner image.
  ///
  /// In en, this message translates to:
  /// **'Clear banner'**
  String get profileSetupBannerClearButton;

  /// Label of the colour input in the banner picker sheet, and the heading of the swatch sheet it opens.
  ///
  /// In en, this message translates to:
  /// **'Banner color'**
  String get profileSetupBannerChangeColor;

  /// Title of the bottom sheet that offers the banner image sources.
  ///
  /// In en, this message translates to:
  /// **'Change banner'**
  String get profileSetupChangeBannerTitle;

  /// Title of the bottom sheet holding the banner colour swatches.
  ///
  /// In en, this message translates to:
  /// **'Change banner color'**
  String get profileSetupBannerColorPickerTitle;

  /// Name of the banner colour chosen through the full colour picker rather than the preset palette.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get profileSetupBannerColorCustom;

  /// Name of the swatch that leaves the banner without a colour, shown in the colour picker and as the value of the banner colour input.
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get profileSetupBannerColorNone;

  /// Name of the lime green banner colour.
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get profileSetupBannerColorLime;

  /// Name of the yellow banner colour.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get profileSetupBannerColorYellow;

  /// Name of the violet banner colour, a pale blue-purple.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get profileSetupBannerColorViolet;

  /// Name of the pink banner colour.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get profileSetupBannerColorPink;

  /// Name of the orange banner colour.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get profileSetupBannerColorOrange;

  /// Name of the purple banner colour, deeper than the violet swatch.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get profileSetupBannerColorPurple;

  /// Action in the profile picture sheet that removes the current picture.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profileSetupAvatarClearButton;

  /// Action in the avatar/banner image sheet that opens the camera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get profileSetupImageTakePhoto;

  /// Action in the avatar/banner image sheet that opens the photo gallery.
  ///
  /// In en, this message translates to:
  /// **'Upload from camera roll'**
  String get profileSetupImageUploadFromCameraRoll;

  /// Action in the avatar/banner image sheet that opens a field for an image URL.
  ///
  /// In en, this message translates to:
  /// **'Paste an image link'**
  String get profileSetupImagePasteLink;

  /// Semantic label and tooltip on the pencil button overlapping the avatar.
  ///
  /// In en, this message translates to:
  /// **'Edit profile picture'**
  String get profileSetupEditAvatarLabel;

  /// Semantic label and tooltip on the pencil button in the banner's top corner.
  ///
  /// In en, this message translates to:
  /// **'Edit banner'**
  String get profileSetupEditBannerLabel;

  /// No description provided for @profileSetupUsernameChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking availability...'**
  String get profileSetupUsernameChecking;

  /// No description provided for @profileSetupUsernameAvailable.
  ///
  /// In en, this message translates to:
  /// **'Username available!'**
  String get profileSetupUsernameAvailable;

  /// No description provided for @profileSetupUsernameTakenIndicator.
  ///
  /// In en, this message translates to:
  /// **'Username already taken'**
  String get profileSetupUsernameTakenIndicator;

  /// No description provided for @profileSetupUsernameReserved.
  ///
  /// In en, this message translates to:
  /// **'Username is reserved'**
  String get profileSetupUsernameReserved;

  /// No description provided for @profileSetupContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get profileSetupContactSupport;

  /// No description provided for @profileSetupCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get profileSetupCheckAgain;

  /// No description provided for @profileSetupUsernameBurned.
  ///
  /// In en, this message translates to:
  /// **'This username is no longer available'**
  String get profileSetupUsernameBurned;

  /// No description provided for @profileSetupUsernameInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Only letters, numbers, and hyphens are allowed'**
  String get profileSetupUsernameInvalidFormat;

  /// No description provided for @profileSetupUsernameInvalidHyphenPlacement.
  ///
  /// In en, this message translates to:
  /// **'Username can\'t start or end with a hyphen'**
  String get profileSetupUsernameInvalidHyphenPlacement;

  /// No description provided for @profileSetupUsernameInvalidLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be 3-63 characters'**
  String get profileSetupUsernameInvalidLength;

  /// No description provided for @profileSetupUsernameNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not check availability. Please try again.'**
  String get profileSetupUsernameNetworkError;

  /// No description provided for @profileSetupUsernameInvalidFormatGeneric.
  ///
  /// In en, this message translates to:
  /// **'Invalid username format'**
  String get profileSetupUsernameInvalidFormatGeneric;

  /// No description provided for @profileSetupUsernameCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check availability'**
  String get profileSetupUsernameCheckFailed;

  /// No description provided for @profileSetupUsernameReservedTitle.
  ///
  /// In en, this message translates to:
  /// **'Username reserved'**
  String get profileSetupUsernameReservedTitle;

  /// No description provided for @profileSetupUsernameReservedBody.
  ///
  /// In en, this message translates to:
  /// **'The name {username} is reserved. Tell us why it should be yours.'**
  String profileSetupUsernameReservedBody(String username);

  /// No description provided for @profileSetupUsernameReservedHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. It\'s my brand name, stage name, etc.'**
  String get profileSetupUsernameReservedHint;

  /// No description provided for @profileSetupUsernameReservedCheckHint.
  ///
  /// In en, this message translates to:
  /// **'Already contacted support? Tap \"Check again\" to see if it\'s been released to you.'**
  String get profileSetupUsernameReservedCheckHint;

  /// No description provided for @profileSetupSupportRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Support request sent! We\'ll get back to you soon.'**
  String get profileSetupSupportRequestSent;

  /// No description provided for @profileSetupCouldntOpenEmail.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open email. Send to: names@divine.video'**
  String get profileSetupCouldntOpenEmail;

  /// No description provided for @profileSetupSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get profileSetupSendRequest;

  /// No description provided for @profileSetupUseOwnNip05.
  ///
  /// In en, this message translates to:
  /// **'Use your own NIP-05 address'**
  String get profileSetupUseOwnNip05;

  /// No description provided for @profileSetupNip05AddressLabel.
  ///
  /// In en, this message translates to:
  /// **'NIP-05 Address'**
  String get profileSetupNip05AddressLabel;

  /// No description provided for @profileSetupExternalNip05InvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid NIP-05 format (e.g., name@domain.com)'**
  String get profileSetupExternalNip05InvalidFormat;

  /// No description provided for @profileSetupExternalNip05DivineDomain.
  ///
  /// In en, this message translates to:
  /// **'Use the username field above for divine.video'**
  String get profileSetupExternalNip05DivineDomain;

  /// No description provided for @nostrSettingsNip05Address.
  ///
  /// In en, this message translates to:
  /// **'NIP-05 address'**
  String get nostrSettingsNip05Address;

  /// No description provided for @nostrSettingsNip05AddressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your divine.video username, or point your handle at a NIP-05 address on a domain you control.'**
  String get nostrSettingsNip05AddressSubtitle;

  /// No description provided for @nostrSettingsNip05AddressHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get nostrSettingsNip05AddressHint;

  /// No description provided for @nostrSettingsNip05SaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save NIP-05'**
  String get nostrSettingsNip05SaveAction;

  /// No description provided for @nostrSettingsNip05Saved.
  ///
  /// In en, this message translates to:
  /// **'NIP-05 saved'**
  String get nostrSettingsNip05Saved;

  /// No description provided for @nostrSettingsNip05SaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save NIP-05. Please try again.'**
  String get nostrSettingsNip05SaveFailed;

  /// No description provided for @profileSetupNip05ConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Use your own NIP-05?'**
  String get profileSetupNip05ConfirmTitle;

  /// No description provided for @profileSetupNip05ConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'NIP-05 maps a name like you@yourdomain.com to your Nostr identity. You need to control the domain and host a verification file at the right path. If it\'s wrong, people can\'t find you and your verified handle disappears. Continue only if you\'ve set this up.'**
  String get profileSetupNip05ConfirmBody;

  /// No description provided for @profileSetupNip05ConfirmContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profileSetupNip05ConfirmContinue;

  /// No description provided for @profileSetupNip05ConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileSetupNip05ConfirmCancel;

  /// No description provided for @profileSetupProfilePicturePreview.
  ///
  /// In en, this message translates to:
  /// **'Profile picture preview'**
  String get profileSetupProfilePicturePreview;

  /// No description provided for @nostrInfoIntroBuiltOn.
  ///
  /// In en, this message translates to:
  /// **'Divine is built on Nostr,'**
  String get nostrInfoIntroBuiltOn;

  /// No description provided for @nostrInfoIntroDescription.
  ///
  /// In en, this message translates to:
  /// **' a censorship-resistant open protocol that lets people communicate online without relying on a single company or platform. '**
  String get nostrInfoIntroDescription;

  /// No description provided for @nostrInfoIntroIdentity.
  ///
  /// In en, this message translates to:
  /// **'When you sign up for Divine, you get a new Nostr identity.'**
  String get nostrInfoIntroIdentity;

  /// No description provided for @nostrInfoOwnership.
  ///
  /// In en, this message translates to:
  /// **'Nostr lets you own your content, identity and social graph, which you can use across many apps. The result is more choice, less lock-in, and a healthier, more resilient social internet.'**
  String get nostrInfoOwnership;

  /// No description provided for @nostrInfoLingo.
  ///
  /// In en, this message translates to:
  /// **'Nostr lingo:'**
  String get nostrInfoLingo;

  /// No description provided for @nostrInfoNpubLabel.
  ///
  /// In en, this message translates to:
  /// **'npub:'**
  String get nostrInfoNpubLabel;

  /// No description provided for @nostrInfoNpubDescription.
  ///
  /// In en, this message translates to:
  /// **' Your public Nostr address. It\'s safe to share and lets others find, follow, or message you across Nostr apps.'**
  String get nostrInfoNpubDescription;

  /// No description provided for @nostrInfoNsecLabel.
  ///
  /// In en, this message translates to:
  /// **'nsec:'**
  String get nostrInfoNsecLabel;

  /// No description provided for @nostrInfoNsecDescription.
  ///
  /// In en, this message translates to:
  /// **' Your private key and proof of ownership. It gives full control of your Nostr identity, so '**
  String get nostrInfoNsecDescription;

  /// No description provided for @nostrInfoNsecWarning.
  ///
  /// In en, this message translates to:
  /// **'always keep it secret!'**
  String get nostrInfoNsecWarning;

  /// No description provided for @nostrInfoUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nostr username:'**
  String get nostrInfoUsernameLabel;

  /// No description provided for @nostrInfoUsernameDescription.
  ///
  /// In en, this message translates to:
  /// **' A human-readable name (like @name.divine.video) that links to your npub. It makes your Nostr identity easier to recognize and verify, similar to an email address.'**
  String get nostrInfoUsernameDescription;

  /// No description provided for @nostrInfoLearnMoreAt.
  ///
  /// In en, this message translates to:
  /// **'Learn more at '**
  String get nostrInfoLearnMoreAt;

  /// No description provided for @nostrInfoGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get nostrInfoGotIt;

  /// No description provided for @videoGridRefreshLabel.
  ///
  /// In en, this message translates to:
  /// **'Searching for more videos'**
  String get videoGridRefreshLabel;

  /// No description provided for @videoGridOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Options'**
  String get videoGridOptionsTitle;

  /// No description provided for @videoGridEditVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit Video'**
  String get videoGridEditVideo;

  /// No description provided for @videoGridEditVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update title, description, and hashtags'**
  String get videoGridEditVideoSubtitle;

  /// No description provided for @videoGridDeleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete Video'**
  String get videoGridDeleteVideo;

  /// No description provided for @videoGridDeleteVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this video from Divine. It may still appear on other Nostr clients.'**
  String get videoGridDeleteVideoSubtitle;

  /// No description provided for @videoGridDeletingContent.
  ///
  /// In en, this message translates to:
  /// **'Deleting content...'**
  String get videoGridDeletingContent;

  /// Name of the Explore tab that shows a server-curated collection. The collection's own name is not this string — it rides beside it in a pill.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get exploreTabFeatured;

  /// No description provided for @exploreTabClassics.
  ///
  /// In en, this message translates to:
  /// **'Classics'**
  String get exploreTabClassics;

  /// No description provided for @exploreTabNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get exploreTabNew;

  /// No description provided for @exploreTabPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get exploreTabPopular;

  /// No description provided for @exploreTabCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get exploreTabCategories;

  /// No description provided for @exploreTabForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get exploreTabForYou;

  /// No description provided for @exploreTabLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get exploreTabLists;

  /// No description provided for @exploreTabIntegratedApps.
  ///
  /// In en, this message translates to:
  /// **'Integrated Apps'**
  String get exploreTabIntegratedApps;

  /// Commercial disclosure shown with a sponsored featured collection in grid and fullscreen views. This is a disclosure, not marketing copy: translate it so it clearly communicates commercial sponsorship rather than an editorial credit. Many languages may render this more naturally as a noun label than a prepositional phrase, or may need the brand name to lead. {sponsor} is a brand name supplied by the server and must not be translated.
  ///
  /// In en, this message translates to:
  /// **'Sponsored by {sponsor}'**
  String exploreFeaturedSponsoredBy(String sponsor);

  /// Spoken label for the featured tab's collection pill when the collection is sponsored. The pill's pink colour conveys this visually; this carries the same state to screen readers. {name} is the collection name supplied by the server.
  ///
  /// In en, this message translates to:
  /// **'{name}, sponsored'**
  String exploreFeaturedSponsoredPillSemanticLabel(String name);

  /// Empty state for a server-configured featured Explore tab whose content snapshot has not caught up yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Check back soon.'**
  String get featuredTabEmpty;

  /// Shown when the featured Explore tab's video request fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this collection.'**
  String get featuredTabLoadFailed;

  /// Retry button on the featured Explore tab's failure state.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get featuredTabRetry;

  /// No description provided for @exploreNoVideosAvailable.
  ///
  /// In en, this message translates to:
  /// **'No videos available'**
  String get exploreNoVideosAvailable;

  /// No description provided for @exploreDiscoverLists.
  ///
  /// In en, this message translates to:
  /// **'Discover Lists'**
  String get exploreDiscoverLists;

  /// No description provided for @exploreAboutLists.
  ///
  /// In en, this message translates to:
  /// **'About Lists'**
  String get exploreAboutLists;

  /// No description provided for @exploreAboutListsDescription.
  ///
  /// In en, this message translates to:
  /// **'Lists help you organize and curate Divine content in two ways:'**
  String get exploreAboutListsDescription;

  /// No description provided for @explorePeopleLists.
  ///
  /// In en, this message translates to:
  /// **'People Lists'**
  String get explorePeopleLists;

  /// No description provided for @explorePeopleListsDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow groups of creators and see their latest videos'**
  String get explorePeopleListsDescription;

  /// No description provided for @exploreVideoLists.
  ///
  /// In en, this message translates to:
  /// **'Video Lists'**
  String get exploreVideoLists;

  /// No description provided for @exploreVideoListsDescription.
  ///
  /// In en, this message translates to:
  /// **'Create playlists of your favorite videos to watch later'**
  String get exploreVideoListsDescription;

  /// No description provided for @exploreMyLists.
  ///
  /// In en, this message translates to:
  /// **'My Lists'**
  String get exploreMyLists;

  /// No description provided for @exploreSubscribedLists.
  ///
  /// In en, this message translates to:
  /// **'Subscribed Lists'**
  String get exploreSubscribedLists;

  /// No description provided for @exploreErrorLoadingLists.
  ///
  /// In en, this message translates to:
  /// **'Error loading lists. Please try again.'**
  String get exploreErrorLoadingLists;

  /// No description provided for @exploreNewVideosCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new video} other{{count} new videos}}'**
  String exploreNewVideosCount(int count);

  /// No description provided for @exploreLoadNewVideosLabel.
  ///
  /// In en, this message translates to:
  /// **'Load {count} new {count, plural, =1{video} other{videos}}'**
  String exploreLoadNewVideosLabel(int count);

  /// No description provided for @videoPlayerPlayVideo.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get videoPlayerPlayVideo;

  /// No description provided for @videoPlayerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute video'**
  String get videoPlayerMute;

  /// No description provided for @videoPlayerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute video'**
  String get videoPlayerUnmute;

  /// No description provided for @videoPlayerTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to play or pause. Double tap to like.'**
  String get videoPlayerTapHint;

  /// Semantic label for the More button in the home feed top bar that opens the playback-settings popover.
  ///
  /// In en, this message translates to:
  /// **'Open playback settings'**
  String get videoSettingsMenuOpen;

  /// Semantic label for the More button in the home feed top bar when the playback-settings popover is open.
  ///
  /// In en, this message translates to:
  /// **'Close playback settings'**
  String get videoSettingsMenuClose;

  /// Semantic label for the closed-captions toggle in the playback-settings popover when captions are currently off.
  ///
  /// In en, this message translates to:
  /// **'Enable captions'**
  String get videoSettingsCaptionsEnable;

  /// Semantic label for the closed-captions toggle in the playback-settings popover when captions are currently on.
  ///
  /// In en, this message translates to:
  /// **'Disable captions'**
  String get videoSettingsCaptionsDisable;

  /// Snackbar confirming that auto advance was just turned on from the playback-settings pill.
  ///
  /// In en, this message translates to:
  /// **'Auto advance on'**
  String get videoSettingsAutoAdvanceOn;

  /// Snackbar confirming that auto advance was just turned off from the playback-settings pill.
  ///
  /// In en, this message translates to:
  /// **'Auto advance off'**
  String get videoSettingsAutoAdvanceOff;

  /// Snackbar confirming that captions were just turned on from the playback-settings pill.
  ///
  /// In en, this message translates to:
  /// **'Captions on'**
  String get videoSettingsCaptionsOn;

  /// Snackbar confirming that captions were just turned off from the playback-settings pill.
  ///
  /// In en, this message translates to:
  /// **'Captions off'**
  String get videoSettingsCaptionsOff;

  /// Snackbar confirming that captions were just turned on for the current video from the playback-settings pill.
  ///
  /// In en, this message translates to:
  /// **'Captions on for this video'**
  String get videoSettingsCaptionsOnForVideo;

  /// Snackbar confirming that captions were just turned off for the current video from the playback-settings pill.
  ///
  /// In en, this message translates to:
  /// **'Captions off for this video'**
  String get videoSettingsCaptionsOffForVideo;

  /// No description provided for @contentWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Content Warning'**
  String get contentWarningLabel;

  /// No description provided for @contentWarningNudity.
  ///
  /// In en, this message translates to:
  /// **'Nudity'**
  String get contentWarningNudity;

  /// No description provided for @contentWarningSexualContent.
  ///
  /// In en, this message translates to:
  /// **'Sexual Content'**
  String get contentWarningSexualContent;

  /// No description provided for @contentWarningPornography.
  ///
  /// In en, this message translates to:
  /// **'Pornography'**
  String get contentWarningPornography;

  /// No description provided for @contentWarningGraphicMedia.
  ///
  /// In en, this message translates to:
  /// **'Graphic Media'**
  String get contentWarningGraphicMedia;

  /// No description provided for @contentWarningViolence.
  ///
  /// In en, this message translates to:
  /// **'Violence'**
  String get contentWarningViolence;

  /// No description provided for @contentWarningSelfHarm.
  ///
  /// In en, this message translates to:
  /// **'Self-Harm'**
  String get contentWarningSelfHarm;

  /// No description provided for @contentWarningDrugUse.
  ///
  /// In en, this message translates to:
  /// **'Drug Use'**
  String get contentWarningDrugUse;

  /// No description provided for @contentWarningAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Alcohol'**
  String get contentWarningAlcohol;

  /// No description provided for @contentWarningTobacco.
  ///
  /// In en, this message translates to:
  /// **'Tobacco'**
  String get contentWarningTobacco;

  /// No description provided for @contentWarningGambling.
  ///
  /// In en, this message translates to:
  /// **'Gambling'**
  String get contentWarningGambling;

  /// No description provided for @contentWarningProfanity.
  ///
  /// In en, this message translates to:
  /// **'Profanity'**
  String get contentWarningProfanity;

  /// No description provided for @contentWarningFlashingLights.
  ///
  /// In en, this message translates to:
  /// **'Flashing Lights'**
  String get contentWarningFlashingLights;

  /// No description provided for @contentWarningAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI-Generated'**
  String get contentWarningAiGenerated;

  /// No description provided for @contentWarningSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get contentWarningSpoiler;

  /// No description provided for @contentWarningSensitiveContent.
  ///
  /// In en, this message translates to:
  /// **'Sensitive Content'**
  String get contentWarningSensitiveContent;

  /// No description provided for @contentWarningDescNudity.
  ///
  /// In en, this message translates to:
  /// **'Contains nudity or partial nudity'**
  String get contentWarningDescNudity;

  /// No description provided for @contentWarningDescSexual.
  ///
  /// In en, this message translates to:
  /// **'Contains sexual content'**
  String get contentWarningDescSexual;

  /// No description provided for @contentWarningDescPorn.
  ///
  /// In en, this message translates to:
  /// **'Contains explicit pornographic content'**
  String get contentWarningDescPorn;

  /// No description provided for @contentWarningDescGraphicMedia.
  ///
  /// In en, this message translates to:
  /// **'Contains graphic or disturbing imagery'**
  String get contentWarningDescGraphicMedia;

  /// No description provided for @contentWarningDescViolence.
  ///
  /// In en, this message translates to:
  /// **'Contains violent content'**
  String get contentWarningDescViolence;

  /// No description provided for @contentWarningDescSelfHarm.
  ///
  /// In en, this message translates to:
  /// **'Contains references to self-harm'**
  String get contentWarningDescSelfHarm;

  /// No description provided for @contentWarningDescDrugs.
  ///
  /// In en, this message translates to:
  /// **'Contains drug-related content'**
  String get contentWarningDescDrugs;

  /// No description provided for @contentWarningDescAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Contains alcohol-related content'**
  String get contentWarningDescAlcohol;

  /// No description provided for @contentWarningDescTobacco.
  ///
  /// In en, this message translates to:
  /// **'Contains tobacco-related content'**
  String get contentWarningDescTobacco;

  /// No description provided for @contentWarningDescGambling.
  ///
  /// In en, this message translates to:
  /// **'Contains gambling-related content'**
  String get contentWarningDescGambling;

  /// No description provided for @contentWarningDescProfanity.
  ///
  /// In en, this message translates to:
  /// **'Contains strong language'**
  String get contentWarningDescProfanity;

  /// No description provided for @contentWarningDescFlashingLights.
  ///
  /// In en, this message translates to:
  /// **'Contains flashing lights (photosensitivity warning)'**
  String get contentWarningDescFlashingLights;

  /// No description provided for @contentWarningDescAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'This content was generated by AI'**
  String get contentWarningDescAiGenerated;

  /// No description provided for @contentWarningDescSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Contains spoilers'**
  String get contentWarningDescSpoiler;

  /// No description provided for @contentWarningDescContentWarning.
  ///
  /// In en, this message translates to:
  /// **'Creator marked this as sensitive'**
  String get contentWarningDescContentWarning;

  /// No description provided for @contentWarningDescDefault.
  ///
  /// In en, this message translates to:
  /// **'Creator flagged this content'**
  String get contentWarningDescDefault;

  /// No description provided for @contentWarningDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Warnings'**
  String get contentWarningDetailsTitle;

  /// No description provided for @contentWarningDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The creator applied these labels:'**
  String get contentWarningDetailsSubtitle;

  /// No description provided for @contentWarningManageFilters.
  ///
  /// In en, this message translates to:
  /// **'Manage content filters'**
  String get contentWarningManageFilters;

  /// No description provided for @contentWarningViewAnyway.
  ///
  /// In en, this message translates to:
  /// **'View Anyway'**
  String get contentWarningViewAnyway;

  /// No description provided for @contentWarningReportContentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Report Content'**
  String get contentWarningReportContentTooltip;

  /// No description provided for @contentWarningBlockUserTooltip.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get contentWarningBlockUserTooltip;

  /// No description provided for @contentWarningBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Blocked'**
  String get contentWarningBlockedTitle;

  /// No description provided for @contentWarningBlockedPolicy.
  ///
  /// In en, this message translates to:
  /// **'This content has been blocked due to policy violations.'**
  String get contentWarningBlockedPolicy;

  /// No description provided for @contentWarningNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Notice'**
  String get contentWarningNoticeTitle;

  /// No description provided for @contentWarningPotentiallyHarmfulTitle.
  ///
  /// In en, this message translates to:
  /// **'Potentially Harmful Content'**
  String get contentWarningPotentiallyHarmfulTitle;

  /// No description provided for @contentWarningView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get contentWarningView;

  /// No description provided for @contentWarningReportAction.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get contentWarningReportAction;

  /// No description provided for @contentWarningHideAllLikeThis.
  ///
  /// In en, this message translates to:
  /// **'Hide all content like this'**
  String get contentWarningHideAllLikeThis;

  /// No description provided for @contentWarningNoFilterYet.
  ///
  /// In en, this message translates to:
  /// **'No saved filter for this warning yet.'**
  String get contentWarningNoFilterYet;

  /// No description provided for @contentWarningHiddenConfirmation.
  ///
  /// In en, this message translates to:
  /// **'We\'ll hide posts like this from now on.'**
  String get contentWarningHiddenConfirmation;

  /// Title of the sheet where a viewer suggests content-warning labels for someone else's video.
  ///
  /// In en, this message translates to:
  /// **'Help classify this'**
  String get communitySuggestTitle;

  /// No description provided for @communitySuggestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Missing a content warning? Your suggestion is public, signed, and can\'t be taken back.'**
  String get communitySuggestSubtitle;

  /// No description provided for @communitySuggestSubmit.
  ///
  /// In en, this message translates to:
  /// **'Suggest'**
  String get communitySuggestSubmit;

  /// No description provided for @communitySuggestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Your suggestion was sent.'**
  String get communitySuggestSuccess;

  /// No description provided for @communitySuggestFailure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your suggestion. Try again.'**
  String get communitySuggestFailure;

  /// Badge shown next to a label the current viewer has already suggested for this video.
  ///
  /// In en, this message translates to:
  /// **'You suggested this'**
  String get communitySuggestAlready;

  /// Short caption under the video overlay action that opens the community content-warning suggestion sheet.
  ///
  /// In en, this message translates to:
  /// **'Classify'**
  String get communitySuggestActionLabel;

  /// No description provided for @videoErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Video not found'**
  String get videoErrorNotFound;

  /// No description provided for @videoErrorPlayback.
  ///
  /// In en, this message translates to:
  /// **'Video playback error'**
  String get videoErrorPlayback;

  /// No description provided for @videoErrorAgeRestricted.
  ///
  /// In en, this message translates to:
  /// **'Age-restricted content'**
  String get videoErrorAgeRestricted;

  /// Title shown when authenticated retry still cannot play a video, so the app should not claim age restriction.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get videoErrorUnavailable;

  /// Body shown when authenticated retry still cannot play a video. The copy should be neutral and not blame age verification.
  ///
  /// In en, this message translates to:
  /// **'This video isn\'t available right now.'**
  String get videoErrorUnavailableBody;

  /// No description provided for @videoErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get videoErrorRetry;

  /// No description provided for @videoErrorContentRestricted.
  ///
  /// In en, this message translates to:
  /// **'Content restricted'**
  String get videoErrorContentRestricted;

  /// Body copy for videos blocked by platform moderation, quarantine, or a media-server 403. Do not mention Nostr relays or user relay settings.
  ///
  /// In en, this message translates to:
  /// **'This video was removed for breaking our content rules.'**
  String get videoErrorContentRestrictedBody;

  /// No description provided for @videoErrorVerifyAgeBody.
  ///
  /// In en, this message translates to:
  /// **'Verify your age to view this video.'**
  String get videoErrorVerifyAgeBody;

  /// No description provided for @videoErrorSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get videoErrorSkip;

  /// No description provided for @videoErrorVerifyAgeButton.
  ///
  /// In en, this message translates to:
  /// **'Verify age'**
  String get videoErrorVerifyAgeButton;

  /// No description provided for @videoErrorVerifyAgeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t verify your age. Please try again.'**
  String get videoErrorVerifyAgeFailed;

  /// Snackbar shown when tapping Verify age on an age-restricted video and the remote signer didn't respond in time (timeout). Distinct from videoErrorVerifyAgeFailed because the remedy is checking connectivity, not re-verifying age.
  ///
  /// In en, this message translates to:
  /// **'Verification timed out. Check your connection or try again shortly.'**
  String get videoErrorVerifyAgeSignerUnreachable;

  /// Title of the bottom sheet shown when an age-verified viewer taps Verify age on an age-restricted video but their Content Filters keep adult content hidden.
  ///
  /// In en, this message translates to:
  /// **'Adult content is switched off'**
  String get videoErrorAdultContentHiddenTitle;

  /// Body of the adult-content-hidden sheet. The remedy is switching adult content on in Content Filters, not re-verifying age.
  ///
  /// In en, this message translates to:
  /// **'Turn it on in your content filters to watch this one.'**
  String get videoErrorAdultContentHiddenBody;

  /// Primary button on the adult-content-hidden sheet; opens the Content Filters settings screen.
  ///
  /// In en, this message translates to:
  /// **'Open Content Filters'**
  String get videoErrorAdultContentHiddenAction;

  /// No description provided for @videoDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load video'**
  String get videoDetailLoadError;

  /// Supporting copy under the 'Failed to load video' title on the shared-link video screen, shown next to a Retry button. Deliberately vague about the cause because the failure can be network, relay, or parsing.
  ///
  /// In en, this message translates to:
  /// **'Something went sideways on the way here. Give it another try.'**
  String get videoDetailLoadErrorBody;

  /// Supporting copy under the 'Video not found' title on the shared-link video screen. The screen shows this for three different causes it cannot tell apart: the video was deleted, it cannot be fetched from any connected relay, or it is hidden by a filter (a blocked or muted author, or the default-on Divine-hosted-only setting). It must not promise the video is gone for good, and it must not be read as covering only the first two.
  ///
  /// In en, this message translates to:
  /// **'It could be gone, out of reach, or hidden by your settings.'**
  String get videoDetailNotFoundBody;

  /// Title of the full-screen takeover shown when the local database reports on-disk corruption at runtime. 'Scrambled' is deliberately non-technical: the user did nothing wrong and cannot act on the real cause.
  ///
  /// In en, this message translates to:
  /// **'Your local data got scrambled'**
  String get databaseCorruptionTitle;

  /// Body of the database-corruption takeover, explaining that a restart triggers the repair. The hedge on drafts and clips is deliberate and must be preserved when translating: the next launch salvages on a best-effort basis and can drop rows sitting on damaged pages, so promising they all survive would be a lie.
  ///
  /// In en, this message translates to:
  /// **'Close Divine and open it again — we\'ll patch it up automatically. We\'ll save what drafts and clips we can, everything else reloads.'**
  String get databaseCorruptionBody;

  /// Button on the database-corruption takeover that closes the app so the user can reopen it. Flutter cannot relaunch its own process, so closing is the most we can offer.
  ///
  /// In en, this message translates to:
  /// **'Close Divine'**
  String get databaseCorruptionCloseButton;

  /// App bar title over the fullscreen player when a video is opened from a share/deep link; also forwarded verbatim as the feedMode analytics dimension.
  ///
  /// In en, this message translates to:
  /// **'Shared Video'**
  String get videoDetailContextTitle;

  /// No description provided for @videoDetailCloseSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Close video player'**
  String get videoDetailCloseSemanticLabel;

  /// No description provided for @videoFollowButtonFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get videoFollowButtonFollow;

  /// No description provided for @audioAttributionOriginalSound.
  ///
  /// In en, this message translates to:
  /// **'Original sound'**
  String get audioAttributionOriginalSound;

  /// Neutral label shown when a video references a shared sound event that cannot currently be fetched. Must not imply the video author's original sound.
  ///
  /// In en, this message translates to:
  /// **'Sound unavailable'**
  String get audioAttributionUnavailableSound;

  /// No description provided for @videoInspiredByAttributionMultiple.
  ///
  /// In en, this message translates to:
  /// **'Inspired by @{creatorName} +{additionalCreatorCount}'**
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  );

  /// No description provided for @videoInspiredByAttribution.
  ///
  /// In en, this message translates to:
  /// **'Inspired by @{creatorName}'**
  String videoInspiredByAttribution(String creatorName);

  /// No description provided for @videoCollaboratorWithOne.
  ///
  /// In en, this message translates to:
  /// **'with @{name}'**
  String videoCollaboratorWithOne(String name);

  /// No description provided for @videoCollaboratorWithMore.
  ///
  /// In en, this message translates to:
  /// **'with @{name} +{count}'**
  String videoCollaboratorWithMore(String name, int count);

  /// No description provided for @videoCollaboratorCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 collaborator} other{{count} collaborators}}. Tap to view profile.'**
  String videoCollaboratorCountLabel(int count);

  /// Small badge next to a collaborator's name or avatar when the creator (viewing their own video) has invited them but they have not yet accepted.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get videoCollaboratorPendingDecoration;

  /// Screen reader label for a dimmed pending collaborator avatar on the creator's own video.
  ///
  /// In en, this message translates to:
  /// **'Pending collaborator'**
  String get videoCollaboratorPendingSemanticLabel;

  /// Appends a pending count to the collaborator label on the creator's own video. {label} is the existing 'with @name' / 'with @name +N' phrase.
  ///
  /// In en, this message translates to:
  /// **'{label} ({pending} pending)'**
  String videoCollaboratorWithPendingSuffix(String label, int pending);

  /// Screen reader hint announced when a user-chip in the metadata sheet is focused. {name} is the user's display name.
  ///
  /// In en, this message translates to:
  /// **'{name}. Tap to view profile.'**
  String profileChipTapHint(String name);

  /// Screen reader hint announced when a hashtag chip in the metadata sheet is focused. {hashtag} is the hashtag without the leading # prefix.
  ///
  /// In en, this message translates to:
  /// **'#{hashtag}. Tap to view videos with this hashtag.'**
  String metadataHashtagChipTapHint(String hashtag);

  /// No description provided for @listAttributionFallback.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listAttributionFallback;

  /// No description provided for @shareVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Share video'**
  String get shareVideoLabel;

  /// No description provided for @sharePostSharedWith.
  ///
  /// In en, this message translates to:
  /// **'Post shared with {recipientName}'**
  String sharePostSharedWith(String recipientName);

  /// Snackbar after sharing a video to two or more people at once. Only used for count >= 2.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Post shared with {count} person} other{Post shared with {count} people}}'**
  String sharePostSharedWithCount(int count);

  /// No description provided for @shareFailedToSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send video'**
  String get shareFailedToSend;

  /// No description provided for @shareAddedToBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Added to bookmarks'**
  String get shareAddedToBookmarks;

  /// Snackbar shown after removing a video from global bookmarks via Save on the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Removed from bookmarks'**
  String get shareRemovedFromBookmarks;

  /// No description provided for @shareFailedToAddBookmark.
  ///
  /// In en, this message translates to:
  /// **'Failed to add bookmark'**
  String get shareFailedToAddBookmark;

  /// Snackbar when toggling Save off (remove from bookmarks) fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove bookmark'**
  String get shareFailedToRemoveBookmark;

  /// No description provided for @shareActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get shareActionFailed;

  /// No description provided for @shareWithTitle.
  ///
  /// In en, this message translates to:
  /// **'Share with'**
  String get shareWithTitle;

  /// No description provided for @shareFindPeople.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get shareFindPeople;

  /// No description provided for @shareFindPeopleMultiline.
  ///
  /// In en, this message translates to:
  /// **'Find\npeople'**
  String get shareFindPeopleMultiline;

  /// No description provided for @shareSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get shareSent;

  /// Screen reader announcement when a person is selected in the share sheet. Selection opens the optional message composer but does not send the video.
  ///
  /// In en, this message translates to:
  /// **'Selected {name}'**
  String shareSelectedRecipientAnnouncement(String name);

  /// No description provided for @shareMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Add optional message...'**
  String get shareMessageHint;

  /// No description provided for @videoActionUnlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike video'**
  String get videoActionUnlike;

  /// No description provided for @videoActionLike.
  ///
  /// In en, this message translates to:
  /// **'Like video'**
  String get videoActionLike;

  /// No description provided for @videoActionAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'Compilation'**
  String get videoActionAutoLabel;

  /// No description provided for @videoActionLikeLabel.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get videoActionLikeLabel;

  /// No description provided for @videoActionReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get videoActionReplyLabel;

  /// No description provided for @videoActionRepostLabel.
  ///
  /// In en, this message translates to:
  /// **'Revine'**
  String get videoActionRepostLabel;

  /// No description provided for @videoActionShareLabel.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get videoActionShareLabel;

  /// Short caption shown beneath the Report icon in the video overlay action column.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get videoActionReportLabel;

  /// Screen reader label for the Report action button in the video overlay action column. Tapping opens the report-content dialog.
  ///
  /// In en, this message translates to:
  /// **'Report video'**
  String get videoActionReport;

  /// Short caption shown beneath the Edit icon in the video overlay action column. Only visible to the owner of the video.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get videoActionEditLabel;

  /// Screen reader label for the Edit action button in the video overlay action column. Tapping opens the video edit dialog.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get videoActionEdit;

  /// No description provided for @videoActionAboutLabel.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get videoActionAboutLabel;

  /// No description provided for @videoActionEnableAutoAdvance.
  ///
  /// In en, this message translates to:
  /// **'Enable auto advance'**
  String get videoActionEnableAutoAdvance;

  /// No description provided for @videoActionDisableAutoAdvance.
  ///
  /// In en, this message translates to:
  /// **'Disable auto advance'**
  String get videoActionDisableAutoAdvance;

  /// No description provided for @videoActionRemoveRepost.
  ///
  /// In en, this message translates to:
  /// **'Remove repost'**
  String get videoActionRemoveRepost;

  /// No description provided for @videoActionRepost.
  ///
  /// In en, this message translates to:
  /// **'Repost video'**
  String get videoActionRepost;

  /// No description provided for @videoActionViewComments.
  ///
  /// In en, this message translates to:
  /// **'View comments'**
  String get videoActionViewComments;

  /// No description provided for @videoActionMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get videoActionMoreOptions;

  /// Title of the screen shown when the video owner taps the Like button on their own video — lists the users who liked it.
  ///
  /// In en, this message translates to:
  /// **'Liked by'**
  String get videoEngagementLikersTitle;

  /// Title of the screen shown when the video owner taps the Repost button on their own video — lists the users who reposted it.
  ///
  /// In en, this message translates to:
  /// **'Reposted by'**
  String get videoEngagementRepostersTitle;

  /// Empty-state message on the likers list screen when no one has liked the video yet.
  ///
  /// In en, this message translates to:
  /// **'No likes yet'**
  String get videoEngagementLikersEmpty;

  /// Empty-state message on the reposters list screen when no one has reposted the video yet.
  ///
  /// In en, this message translates to:
  /// **'No reposts yet'**
  String get videoEngagementRepostersEmpty;

  /// Error-state heading on the engagement list screen when the relay query fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load that list'**
  String get videoEngagementLoadFailed;

  /// Screen-reader label for the tappable title row on the video overlay. Action-oriented: describes what tapping does (opens the metadata sheet), not the title text itself — that's already read aloud by the underlying Text widget.
  ///
  /// In en, this message translates to:
  /// **'Open video details'**
  String get videoOverlayOpenMetadataFromTitle;

  /// Screen-reader label for the tappable description row on the video overlay. Action-oriented: describes what tapping does (opens the metadata sheet), not the description text itself — that's already read aloud by the underlying Text widget.
  ///
  /// In en, this message translates to:
  /// **'Open video details'**
  String get videoOverlayOpenMetadataFromDescription;

  /// Placeholder shown inside the inline comment field at the bottom of the fullscreen video player (used by Explore, Search, and Profile entry points). Tapping the field opens the keyboard so the user can post a comment without opening the full comments sheet.
  ///
  /// In en, this message translates to:
  /// **'Add comment...'**
  String get videoOverlayCommentBarHint;

  /// Screen-reader label for the inline comment field at the bottom of the fullscreen video player. Action-oriented: describes what the field is for.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get videoOverlayCommentBarSemanticLabel;

  /// Screen-reader label for the send button next to the inline comment field at the bottom of the fullscreen video player.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get videoOverlayCommentBarSendLabel;

  /// Snackbar confirmation shown after the user posts a comment from the inline comment field at the bottom of the fullscreen video player.
  ///
  /// In en, this message translates to:
  /// **'Comment posted'**
  String get videoOverlayCommentPostedSnackbar;

  /// Snackbar shown when posting a comment from the inline comment field fails (e.g. relay unreachable).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t post comment'**
  String get videoOverlayCommentPostFailedSnackbar;

  /// No description provided for @videoFeedLoopCountLine.
  ///
  /// In en, this message translates to:
  /// **'{compactCount} {count, plural, =1{loop} other{loops}}'**
  String videoFeedLoopCountLine(String compactCount, int count);

  /// No description provided for @metadataBadgeNotDivine.
  ///
  /// In en, this message translates to:
  /// **'Not Divine'**
  String get metadataBadgeNotDivine;

  /// No description provided for @metadataBadgeHumanMade.
  ///
  /// In en, this message translates to:
  /// **'Human-Made'**
  String get metadataBadgeHumanMade;

  /// No description provided for @metadataSoundsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get metadataSoundsLabel;

  /// No description provided for @metadataOriginalSound.
  ///
  /// In en, this message translates to:
  /// **'Original sound'**
  String get metadataOriginalSound;

  /// No description provided for @metadataVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get metadataVerificationLabel;

  /// No description provided for @metadataDeviceAttestation.
  ///
  /// In en, this message translates to:
  /// **'Device attestation'**
  String get metadataDeviceAttestation;

  /// No description provided for @metadataPgpSignature.
  ///
  /// In en, this message translates to:
  /// **'PGP signature'**
  String get metadataPgpSignature;

  /// No description provided for @metadataC2paCredentials.
  ///
  /// In en, this message translates to:
  /// **'C2PA Content Credentials'**
  String get metadataC2paCredentials;

  /// No description provided for @metadataProofManifest.
  ///
  /// In en, this message translates to:
  /// **'Proof manifest'**
  String get metadataProofManifest;

  /// Accessibility label and tooltip for the info button next to the Verification section header in the video metadata sheet. Opens a sheet explaining the four verification checks.
  ///
  /// In en, this message translates to:
  /// **'What do these checks mean?'**
  String get metadataVerificationInfoTooltip;

  /// Accessibility label for a metadata section header that also opens an info sheet. {section} is the visible section title, e.g. 'Verification'. {question} describes the info action, e.g. 'What do these checks mean?'.
  ///
  /// In en, this message translates to:
  /// **'{section}. {question}'**
  String metadataSectionInfoSemanticsLabel(String section, String question);

  /// Title of the bottom sheet explaining the four ProofMode/C2PA verification checks shown in the video metadata sheet.
  ///
  /// In en, this message translates to:
  /// **'What these checks mean'**
  String get metadataVerificationInfoTitle;

  /// Intro paragraph of the verification explainer sheet, framing the four checks as evidence about a video's origin.
  ///
  /// In en, this message translates to:
  /// **'These signals come from the camera and the video file itself. The more of them a video carries, the more we can prove about where it came from.'**
  String get metadataVerificationInfoIntro;

  /// Explanation of the 'Device attestation' check in the verification explainer sheet.
  ///
  /// In en, this message translates to:
  /// **'The phone\'s operating system vouched for the app that recorded this. Strong evidence it came off a camera, not a file someone uploaded.'**
  String get metadataVerificationInfoDeviceAttestation;

  /// Explanation of the 'PGP signature' check in the verification explainer sheet.
  ///
  /// In en, this message translates to:
  /// **'The video was cryptographically signed the moment it was captured. Change a single frame afterwards and the signature breaks.'**
  String get metadataVerificationInfoPgpSignature;

  /// Explanation of the 'C2PA Content Credentials' check in the verification explainer sheet.
  ///
  /// In en, this message translates to:
  /// **'An industry-standard record of where the video came from, carried inside the file — so apps other than Divine can check it too.'**
  String get metadataVerificationInfoC2paCredentials;

  /// Explanation of the 'Proof manifest' check in the verification explainer sheet.
  ///
  /// In en, this message translates to:
  /// **'The full ProofMode record: file fingerprint, timestamp and capture context, bundled with the video.'**
  String get metadataVerificationInfoProofManifest;

  /// Closing caveat of the verification explainer sheet. States the deliberate limit of the claim — a missing check is not evidence of forgery. Do not strengthen this into a guarantee.
  ///
  /// In en, this message translates to:
  /// **'A missing check doesn\'t make a video fake. Older clips and uploads never got one — it only means we can\'t prove that part.'**
  String get metadataVerificationInfoFootnote;

  /// Sentence linking out to the public ProofMode page at the bottom of the verification explainer sheet. {url} is the scheme-less URL and is not translated; it is rendered underlined, so keep it as one placeholder and place it wherever the sentence reads naturally.
  ///
  /// In en, this message translates to:
  /// **'Learn more at {url}'**
  String metadataVerificationInfoLearnMore(String url);

  /// No description provided for @metadataCreatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get metadataCreatorLabel;

  /// No description provided for @metadataCollaboratorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Collaborators'**
  String get metadataCollaboratorsLabel;

  /// No description provided for @metadataInspiredByLabel.
  ///
  /// In en, this message translates to:
  /// **'Inspired by'**
  String get metadataInspiredByLabel;

  /// No description provided for @metadataRepostedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Reposted by'**
  String get metadataRepostedByLabel;

  /// Chip in the video metadata sheet opening the full reposters list, showing how many reposters are not displayed.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String metadataMoreReposters(int count);

  /// No description provided for @metadataLoopsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Loop} other{Loops}}'**
  String metadataLoopsLabel(int count);

  /// No description provided for @metadataLikesLabel.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get metadataLikesLabel;

  /// No description provided for @metadataCommentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get metadataCommentsLabel;

  /// No description provided for @metadataRepostsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get metadataRepostsLabel;

  /// Row label in the video info sheet for the archival engagement a classic Vine earned on the original Vine platform.
  ///
  /// In en, this message translates to:
  /// **'On Vine'**
  String get metadataVineStatsLabel;

  /// Archival engagement summary for a classic Vine. Each placeholder is a pre-formatted compact count, e.g. '142.7M'.
  ///
  /// In en, this message translates to:
  /// **'{loops} loops · {likes} likes · {comments} comments · {reposts} reposts'**
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  );

  /// Row label in the video info sheet for the engagement a classic Vine has earned from Divine viewers.
  ///
  /// In en, this message translates to:
  /// **'On Divine'**
  String get metadataDivineStatsLabel;

  /// Live Divine engagement summary for a classic Vine. Each placeholder is a pre-formatted compact count, e.g. '3K'.
  ///
  /// In en, this message translates to:
  /// **'{views} views · {likes} likes · {comments} comments · {reposts} reposts'**
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  );

  /// Screen reader label for the publish date in the video info sheet. {date} is the locale-formatted absolute date, e.g. 'Apr 22, 2003'.
  ///
  /// In en, this message translates to:
  /// **'Posted on {date}'**
  String metadataPostedDateSemantics(String date);

  /// Developer options screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Developer Options'**
  String get devOptionsTitle;

  /// Button that turns developer mode off and hides the developer options entry from settings
  ///
  /// In en, this message translates to:
  /// **'Disable Developer Mode'**
  String get devOptionsDisableDeveloperMode;

  /// No description provided for @devOptionsDisableDeveloperModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide developer options from settings'**
  String get devOptionsDisableDeveloperModeSubtitle;

  /// No description provided for @devOptionsDisableDeveloperModeToast.
  ///
  /// In en, this message translates to:
  /// **'Developer mode disabled'**
  String get devOptionsDisableDeveloperModeToast;

  /// No description provided for @devOptionsShorebirdTitle.
  ///
  /// In en, this message translates to:
  /// **'Shorebird Patches'**
  String get devOptionsShorebirdTitle;

  /// Row label for the Shorebird patch number currently running. The number itself renders as the row's value, so a tester can report exactly what they validated.
  ///
  /// In en, this message translates to:
  /// **'Running patch'**
  String get devOptionsShorebirdPatchLabel;

  /// No description provided for @devOptionsShorebirdNoPatch.
  ///
  /// In en, this message translates to:
  /// **'No patch installed'**
  String get devOptionsShorebirdNoPatch;

  /// No description provided for @devOptionsShorebirdUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available in this build'**
  String get devOptionsShorebirdUnavailable;

  /// No description provided for @devOptionsShorebirdUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Patches only run in a build made by shorebird release.'**
  String get devOptionsShorebirdUnavailableSubtitle;

  /// No description provided for @devOptionsShorebirdLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading patch state…'**
  String get devOptionsShorebirdLoading;

  /// No description provided for @devOptionsShorebirdNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Staging track not checked yet.'**
  String get devOptionsShorebirdNotChecked;

  /// No description provided for @devOptionsShorebirdCheck.
  ///
  /// In en, this message translates to:
  /// **'Check staging track'**
  String get devOptionsShorebirdCheck;

  /// No description provided for @devOptionsShorebirdApply.
  ///
  /// In en, this message translates to:
  /// **'Apply staged patch'**
  String get devOptionsShorebirdApply;

  /// No description provided for @devOptionsShorebirdUseStable.
  ///
  /// In en, this message translates to:
  /// **'Return to stable updates'**
  String get devOptionsShorebirdUseStable;

  /// No description provided for @devOptionsShorebirdChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the staging track…'**
  String get devOptionsShorebirdChecking;

  /// No description provided for @devOptionsShorebirdUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'A staged patch is ready to apply.'**
  String get devOptionsShorebirdUpdateAvailable;

  /// No description provided for @devOptionsShorebirdUpToDate.
  ///
  /// In en, this message translates to:
  /// **'No staged patch for this release.'**
  String get devOptionsShorebirdUpToDate;

  /// No description provided for @devOptionsShorebirdRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'Downloaded. Restart the app to load it.'**
  String get devOptionsShorebirdRestartRequired;

  /// No description provided for @devOptionsShorebirdRollbackRequired.
  ///
  /// In en, this message translates to:
  /// **'A rollback is ready. Restart to return to the base release.'**
  String get devOptionsShorebirdRollbackRequired;

  /// No description provided for @devOptionsShorebirdApplying.
  ///
  /// In en, this message translates to:
  /// **'Downloading and installing…'**
  String get devOptionsShorebirdApplying;

  /// No description provided for @devOptionsShorebirdApplied.
  ///
  /// In en, this message translates to:
  /// **'Installed. Restart the app to load it.'**
  String get devOptionsShorebirdApplied;

  /// No description provided for @devOptionsShorebirdUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing was installed. Check the staging track and try again.'**
  String get devOptionsShorebirdUnchanged;

  /// No description provided for @devOptionsShorebirdSelectingStableTrack.
  ///
  /// In en, this message translates to:
  /// **'Selecting stable track…'**
  String get devOptionsShorebirdSelectingStableTrack;

  /// No description provided for @devOptionsShorebirdStableRestored.
  ///
  /// In en, this message translates to:
  /// **'Stable track selected. Restart to check for a stable patch.'**
  String get devOptionsShorebirdStableRestored;

  /// No description provided for @devOptionsShorebirdFailure.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Check the logs for details.'**
  String get devOptionsShorebirdFailure;

  /// No description provided for @devOptionsPageLoadTimes.
  ///
  /// In en, this message translates to:
  /// **'Page Load Times'**
  String get devOptionsPageLoadTimes;

  /// No description provided for @devOptionsNoPageLoads.
  ///
  /// In en, this message translates to:
  /// **'No page loads recorded yet.\nNavigate around the app to see timing data.'**
  String get devOptionsNoPageLoads;

  /// No description provided for @devOptionsPageLoadVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible: {visibleMs}ms  |  Data: {dataMs}ms'**
  String devOptionsPageLoadVisible(String visibleMs, String dataMs);

  /// No description provided for @devOptionsSlowestScreens.
  ///
  /// In en, this message translates to:
  /// **'Slowest Screens'**
  String get devOptionsSlowestScreens;

  /// No description provided for @devOptionsVideoPlaybackFormat.
  ///
  /// In en, this message translates to:
  /// **'Video Playback Format'**
  String get devOptionsVideoPlaybackFormat;

  /// No description provided for @devOptionsSwitchEnvironmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Environment?'**
  String get devOptionsSwitchEnvironmentTitle;

  /// No description provided for @devOptionsSwitchEnvironmentMessage.
  ///
  /// In en, this message translates to:
  /// **'Switch to {envName}?\n\nThis will clear cached video data and reconnect to the new relay.'**
  String devOptionsSwitchEnvironmentMessage(String envName);

  /// No description provided for @devOptionsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get devOptionsCancel;

  /// No description provided for @devOptionsSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get devOptionsSwitch;

  /// No description provided for @devOptionsSwitchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {envName}'**
  String devOptionsSwitchedTo(String envName);

  /// No description provided for @devOptionsSwitchedFormat.
  ///
  /// In en, this message translates to:
  /// **'Switched to {formatName} — cache cleared'**
  String devOptionsSwitchedFormat(String formatName);

  /// Feature flags screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Feature Flags'**
  String get featureFlagTitle;

  /// No description provided for @featureFlagResetAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset all flags to defaults'**
  String get featureFlagResetAllTooltip;

  /// No description provided for @featureFlagError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get featureFlagError;

  /// Relay settings screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Relays'**
  String get relaySettingsTitle;

  /// No description provided for @relaySettingsInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Divine is an open system - you control your connections'**
  String get relaySettingsInfoTitle;

  /// No description provided for @relaySettingsInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'These relays distribute your content across the decentralized Nostr network. You can add or remove relays as you wish.'**
  String get relaySettingsInfoDescription;

  /// No description provided for @relaySettingsLearnMoreNostr.
  ///
  /// In en, this message translates to:
  /// **'Learn more about Nostr →'**
  String get relaySettingsLearnMoreNostr;

  /// No description provided for @relaySettingsFindPublicRelays.
  ///
  /// In en, this message translates to:
  /// **'Find public relays at nostr.co.uk →'**
  String get relaySettingsFindPublicRelays;

  /// No description provided for @relaySettingsAppNotFunctional.
  ///
  /// In en, this message translates to:
  /// **'App Not Functional'**
  String get relaySettingsAppNotFunctional;

  /// No description provided for @relaySettingsRequiresRelay.
  ///
  /// In en, this message translates to:
  /// **'Divine requires at least one relay to load videos, post content, and sync data.'**
  String get relaySettingsRequiresRelay;

  /// No description provided for @relaySettingsRestoreDefaultRelay.
  ///
  /// In en, this message translates to:
  /// **'Restore Default Relay'**
  String get relaySettingsRestoreDefaultRelay;

  /// No description provided for @relaySettingsAddCustomRelay.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Relay'**
  String get relaySettingsAddCustomRelay;

  /// No description provided for @relaySettingsAddRelay.
  ///
  /// In en, this message translates to:
  /// **'Add Relay'**
  String get relaySettingsAddRelay;

  /// No description provided for @relaySettingsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get relaySettingsRetry;

  /// No description provided for @relaySettingsNoStats.
  ///
  /// In en, this message translates to:
  /// **'No statistics available yet'**
  String get relaySettingsNoStats;

  /// No description provided for @relaySettingsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get relaySettingsConnection;

  /// No description provided for @relaySettingsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get relaySettingsConnected;

  /// No description provided for @relaySettingsDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get relaySettingsDisconnected;

  /// No description provided for @relaySettingsSessionDuration.
  ///
  /// In en, this message translates to:
  /// **'Session Duration'**
  String get relaySettingsSessionDuration;

  /// No description provided for @relaySettingsLastConnected.
  ///
  /// In en, this message translates to:
  /// **'Last Connected'**
  String get relaySettingsLastConnected;

  /// No description provided for @relaySettingsDisconnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get relaySettingsDisconnectedLabel;

  /// No description provided for @relaySettingsReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get relaySettingsReason;

  /// No description provided for @relaySettingsActiveSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Active Subscriptions'**
  String get relaySettingsActiveSubscriptions;

  /// No description provided for @relaySettingsTotalSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Total Subscriptions'**
  String get relaySettingsTotalSubscriptions;

  /// No description provided for @relaySettingsEventsReceived.
  ///
  /// In en, this message translates to:
  /// **'Events Received'**
  String get relaySettingsEventsReceived;

  /// No description provided for @relaySettingsEventsSent.
  ///
  /// In en, this message translates to:
  /// **'Events Sent'**
  String get relaySettingsEventsSent;

  /// No description provided for @relaySettingsRequestsThisSession.
  ///
  /// In en, this message translates to:
  /// **'Requests This Session'**
  String get relaySettingsRequestsThisSession;

  /// No description provided for @relaySettingsFailedRequests.
  ///
  /// In en, this message translates to:
  /// **'Failed Requests'**
  String get relaySettingsFailedRequests;

  /// No description provided for @relaySettingsLoadingRelayInfo.
  ///
  /// In en, this message translates to:
  /// **'Loading relay info...'**
  String get relaySettingsLoadingRelayInfo;

  /// No description provided for @relaySettingsAboutRelay.
  ///
  /// In en, this message translates to:
  /// **'About Relay'**
  String get relaySettingsAboutRelay;

  /// No description provided for @relaySettingsSupportedNips.
  ///
  /// In en, this message translates to:
  /// **'Supported NIPs'**
  String get relaySettingsSupportedNips;

  /// No description provided for @relaySettingsSoftware.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get relaySettingsSoftware;

  /// No description provided for @relaySettingsViewWebsite.
  ///
  /// In en, this message translates to:
  /// **'View Website'**
  String get relaySettingsViewWebsite;

  /// No description provided for @relaySettingsRemoveRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Relay?'**
  String get relaySettingsRemoveRelayTitle;

  /// No description provided for @relaySettingsRemoveRelayMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this relay?\n\n{relayUrl}'**
  String relaySettingsRemoveRelayMessage(String relayUrl);

  /// No description provided for @relaySettingsRemoveDefaultRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Divine Relay?'**
  String get relaySettingsRemoveDefaultRelayTitle;

  /// No description provided for @relaySettingsRemoveDefaultRelayMessage.
  ///
  /// In en, this message translates to:
  /// **'Removing Divine\'s relay will degrade the app experience. Videos, posting, and sync may be less reliable. This should only be done by experienced Nostr users.\n\n{relayUrl}'**
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl);

  /// No description provided for @relaySettingsRemoveRelayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove relay'**
  String get relaySettingsRemoveRelayTooltip;

  /// No description provided for @relaySettingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get relaySettingsCancel;

  /// No description provided for @relaySettingsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get relaySettingsRemove;

  /// No description provided for @relaySettingsRemovedRelay.
  ///
  /// In en, this message translates to:
  /// **'Removed relay: {relayUrl}'**
  String relaySettingsRemovedRelay(String relayUrl);

  /// No description provided for @relaySettingsFailedToRemoveRelay.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove relay'**
  String get relaySettingsFailedToRemoveRelay;

  /// No description provided for @relaySettingsForcingReconnection.
  ///
  /// In en, this message translates to:
  /// **'Forcing relay reconnection...'**
  String get relaySettingsForcingReconnection;

  /// No description provided for @relaySettingsConnectedToRelays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Connected to {count} relay!} other{Connected to {count} relays!}}'**
  String relaySettingsConnectedToRelays(int count);

  /// No description provided for @relaySettingsFailedToConnectCheck.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to relays. Please check your network connection.'**
  String get relaySettingsFailedToConnectCheck;

  /// No description provided for @relaySettingsSavedLocallyPublishPending.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. We\'ll sync it to your account when publishing works again.'**
  String get relaySettingsSavedLocallyPublishPending;

  /// No description provided for @relaySettingsAddRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Relay'**
  String get relaySettingsAddRelayTitle;

  /// No description provided for @relaySettingsAddRelayPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the WebSocket URL of the relay you want to add:'**
  String get relaySettingsAddRelayPrompt;

  /// No description provided for @relaySettingsBrowsePublicRelays.
  ///
  /// In en, this message translates to:
  /// **'Browse public relays at nostr.co.uk'**
  String get relaySettingsBrowsePublicRelays;

  /// No description provided for @relaySettingsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get relaySettingsAdd;

  /// No description provided for @relaySettingsAddedRelay.
  ///
  /// In en, this message translates to:
  /// **'Added relay: {relayUrl}'**
  String relaySettingsAddedRelay(String relayUrl);

  /// No description provided for @relaySettingsFailedToAddRelay.
  ///
  /// In en, this message translates to:
  /// **'Failed to add relay. Please check the URL and try again.'**
  String get relaySettingsFailedToAddRelay;

  /// No description provided for @relaySettingsInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Relay URL must start with wss:// or ws://'**
  String get relaySettingsInvalidUrl;

  /// Shown when a user enters a relay URL that uses cleartext ws:// or http:// for a non-loopback host. Pairs with relaySettingsInvalidUrl which is for malformed URLs.
  ///
  /// In en, this message translates to:
  /// **'Relay URL must use wss:// (ws:// is allowed only for localhost)'**
  String get relaySettingsInsecureUrl;

  /// No description provided for @relaySettingsRestoredDefault.
  ///
  /// In en, this message translates to:
  /// **'Restored default relay: {defaultRelay}'**
  String relaySettingsRestoredDefault(String defaultRelay);

  /// No description provided for @relaySettingsFailedToRestoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore default relay. Please check your network connection.'**
  String get relaySettingsFailedToRestoreDefault;

  /// No description provided for @relaySettingsCouldNotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser'**
  String get relaySettingsCouldNotOpenBrowser;

  /// No description provided for @relaySettingsFailedToOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Failed to open link'**
  String get relaySettingsFailedToOpenLink;

  /// No description provided for @relaySettingsExternalRelay.
  ///
  /// In en, this message translates to:
  /// **'External relay'**
  String get relaySettingsExternalRelay;

  /// No description provided for @relaySettingsNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get relaySettingsNotConnected;

  /// No description provided for @relaySettingsDisconnectedAgo.
  ///
  /// In en, this message translates to:
  /// **'Disconnected {duration} ago'**
  String relaySettingsDisconnectedAgo(String duration);

  /// No description provided for @relaySettingsSubscriptionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} sub} other{{count} subs}}'**
  String relaySettingsSubscriptionsSummary(int count);

  /// No description provided for @relaySettingsEventsSummary.
  ///
  /// In en, this message translates to:
  /// **'{countValue, plural, =1{{count} event} other{{count} events}}'**
  String relaySettingsEventsSummary(int countValue, String count);

  /// No description provided for @relaySettingsTimeAgo.
  ///
  /// In en, this message translates to:
  /// **'{duration} ago'**
  String relaySettingsTimeAgo(String duration);

  /// No description provided for @nostrSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Divine uses the Nostr protocol for decentralized publishing. Your content lives on relays you choose, and your keys are your identity.'**
  String get nostrSettingsIntro;

  /// No description provided for @nostrSettingsSectionNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get nostrSettingsSectionNetwork;

  /// No description provided for @nostrSettingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get nostrSettingsSectionAccount;

  /// No description provided for @nostrSettingsSectionDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get nostrSettingsSectionDangerZone;

  /// No description provided for @nostrSettingsRelays.
  ///
  /// In en, this message translates to:
  /// **'Relays'**
  String get nostrSettingsRelays;

  /// No description provided for @nostrSettingsRelaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Nostr relay connections'**
  String get nostrSettingsRelaysSubtitle;

  /// No description provided for @nostrSettingsRelayDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Relay Diagnostics'**
  String get nostrSettingsRelayDiagnostics;

  /// No description provided for @nostrSettingsRelayDiagnosticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Debug relay connectivity and network issues'**
  String get nostrSettingsRelayDiagnosticsSubtitle;

  /// No description provided for @nostrSettingsMediaServers.
  ///
  /// In en, this message translates to:
  /// **'Media Servers'**
  String get nostrSettingsMediaServers;

  /// No description provided for @nostrSettingsMediaServersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Blossom upload servers'**
  String get nostrSettingsMediaServersSubtitle;

  /// No description provided for @settingsDeveloperOptions.
  ///
  /// In en, this message translates to:
  /// **'Developer Options'**
  String get settingsDeveloperOptions;

  /// No description provided for @settingsDeveloperOptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Environment switcher and debug settings'**
  String get settingsDeveloperOptionsSubtitle;

  /// No description provided for @nostrSettingsKeyManagement.
  ///
  /// In en, this message translates to:
  /// **'Key Management'**
  String get nostrSettingsKeyManagement;

  /// No description provided for @nostrSettingsKeyManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export, backup, and restore your Nostr keys'**
  String get nostrSettingsKeyManagementSubtitle;

  /// No description provided for @nostrSettingsClientAttribution.
  ///
  /// In en, this message translates to:
  /// **'Client Attribution'**
  String get nostrSettingsClientAttribution;

  /// Subtitle for the Nostr settings client-attribution switch. The second sentence states the consequence of turning it off: a report with no client tag is still reviewed, but cannot count toward automatic moderation action.
  ///
  /// In en, this message translates to:
  /// **'Include a Divine client tag on events you publish so other Nostr apps can attribute them correctly. Without it, reports you send carry less weight when our moderators review them.'**
  String get nostrSettingsClientAttributionSubtitle;

  /// No description provided for @nostrSettingsMoveAccount.
  ///
  /// In en, this message translates to:
  /// **'Move your account'**
  String get nostrSettingsMoveAccount;

  /// Subtitle for the Nostr settings account-portability row. The web flow lets users download an archive and move their Nostr posts/videos to other infrastructure.
  ///
  /// In en, this message translates to:
  /// **'Download your archive and move your posts and videos to another relay or media server.'**
  String get nostrSettingsMoveAccountSubtitle;

  /// No description provided for @nostrSettingsRemoveKeys.
  ///
  /// In en, this message translates to:
  /// **'Remove this account from this device'**
  String get nostrSettingsRemoveKeys;

  /// No description provided for @nostrSettingsRemoveKeysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this account\'s local login from this device. Your local drafts and clips stay saved for this account.'**
  String get nostrSettingsRemoveKeysSubtitle;

  /// No description provided for @nostrSettingsCouldNotRemoveKeys.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this account from this device. Please try again.'**
  String get nostrSettingsCouldNotRemoveKeys;

  /// No description provided for @nostrSettingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account and Data'**
  String get nostrSettingsDeleteAccount;

  /// Subtitle for the destructive account deletion settings row. Be clear that Nostr deletion is request-based, not a guarantee that every relay, client, cache, search index, or other signed-in device will forget the account.
  ///
  /// In en, this message translates to:
  /// **'Sends deletion requests for your content and signs you out on this device. Relays, clients, search indexes, and other signed-in devices may keep copies.'**
  String get nostrSettingsDeleteAccountSubtitle;

  /// Relay diagnostics screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Relay Diagnostics'**
  String get relayDiagnosticTitle;

  /// No description provided for @relayDiagnosticRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh diagnostics'**
  String get relayDiagnosticRefreshTooltip;

  /// No description provided for @relayDiagnosticLastRefresh.
  ///
  /// In en, this message translates to:
  /// **'Last refresh: {time}'**
  String relayDiagnosticLastRefresh(String time);

  /// No description provided for @relayDiagnosticRelayStatus.
  ///
  /// In en, this message translates to:
  /// **'Relay Status'**
  String get relayDiagnosticRelayStatus;

  /// No description provided for @relayDiagnosticInitialized.
  ///
  /// In en, this message translates to:
  /// **'Initialized'**
  String get relayDiagnosticInitialized;

  /// No description provided for @relayDiagnosticReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get relayDiagnosticReady;

  /// No description provided for @relayDiagnosticNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'Not initialized'**
  String get relayDiagnosticNotInitialized;

  /// No description provided for @relayDiagnosticDatabaseEvents.
  ///
  /// In en, this message translates to:
  /// **'Database Events'**
  String get relayDiagnosticDatabaseEvents;

  /// No description provided for @relayDiagnosticActiveSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Active Subscriptions'**
  String get relayDiagnosticActiveSubscriptions;

  /// No description provided for @relayDiagnosticExternalRelays.
  ///
  /// In en, this message translates to:
  /// **'External Relays'**
  String get relayDiagnosticExternalRelays;

  /// No description provided for @relayDiagnosticConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get relayDiagnosticConfigured;

  /// No description provided for @relayDiagnosticRelayCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} relay} other{{count} relays}}'**
  String relayDiagnosticRelayCount(int count);

  /// No description provided for @relayDiagnosticConnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get relayDiagnosticConnectedLabel;

  /// No description provided for @relayDiagnosticConnectedRatio.
  ///
  /// In en, this message translates to:
  /// **'{connected}/{total}'**
  String relayDiagnosticConnectedRatio(int connected, int total);

  /// No description provided for @relayDiagnosticVideoEvents.
  ///
  /// In en, this message translates to:
  /// **'Video Events'**
  String get relayDiagnosticVideoEvents;

  /// No description provided for @relayDiagnosticHomeFeed.
  ///
  /// In en, this message translates to:
  /// **'Home Feed'**
  String get relayDiagnosticHomeFeed;

  /// No description provided for @relayDiagnosticVideosCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} video} other{{count} videos}}'**
  String relayDiagnosticVideosCount(int count);

  /// No description provided for @relayDiagnosticDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get relayDiagnosticDiscovery;

  /// No description provided for @relayDiagnosticLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get relayDiagnosticLoading;

  /// No description provided for @relayDiagnosticYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get relayDiagnosticYes;

  /// No description provided for @relayDiagnosticNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get relayDiagnosticNo;

  /// No description provided for @relayDiagnosticTestDirectQuery.
  ///
  /// In en, this message translates to:
  /// **'Test Direct Query'**
  String get relayDiagnosticTestDirectQuery;

  /// No description provided for @relayDiagnosticNetworkConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Network Connectivity'**
  String get relayDiagnosticNetworkConnectivity;

  /// No description provided for @relayDiagnosticRunNetworkTest.
  ///
  /// In en, this message translates to:
  /// **'Run Network Test'**
  String get relayDiagnosticRunNetworkTest;

  /// No description provided for @relayDiagnosticBlossomServer.
  ///
  /// In en, this message translates to:
  /// **'Blossom Server'**
  String get relayDiagnosticBlossomServer;

  /// No description provided for @relayDiagnosticTestAllEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Test All Endpoints'**
  String get relayDiagnosticTestAllEndpoints;

  /// No description provided for @relayDiagnosticStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get relayDiagnosticStatus;

  /// No description provided for @relayDiagnosticUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get relayDiagnosticUrl;

  /// No description provided for @relayDiagnosticError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get relayDiagnosticError;

  /// No description provided for @relayDiagnosticFunnelCakeApi.
  ///
  /// In en, this message translates to:
  /// **'FunnelCake API'**
  String get relayDiagnosticFunnelCakeApi;

  /// No description provided for @relayDiagnosticBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get relayDiagnosticBaseUrl;

  /// No description provided for @relayDiagnosticSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get relayDiagnosticSummary;

  /// No description provided for @relayDiagnosticEndpointSummary.
  ///
  /// In en, this message translates to:
  /// **'{successCount}/{totalCount} OK (avg {avgMs}ms)'**
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  );

  /// No description provided for @relayDiagnosticRetestAll.
  ///
  /// In en, this message translates to:
  /// **'Retest All'**
  String get relayDiagnosticRetestAll;

  /// No description provided for @relayDiagnosticRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get relayDiagnosticRetrying;

  /// No description provided for @relayDiagnosticRetryConnection.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get relayDiagnosticRetryConnection;

  /// No description provided for @relayDiagnosticTroubleshooting.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get relayDiagnosticTroubleshooting;

  /// No description provided for @relayDiagnosticTroubleshootingGuide.
  ///
  /// In en, this message translates to:
  /// **'• Green status = Connected and working\n• Red status = Connection failed\n• If network test fails, check internet connection\n• If relays are configured but not connected, tap \"Retry Connection\"\n• Screenshot this screen for debugging'**
  String get relayDiagnosticTroubleshootingGuide;

  /// No description provided for @relayDiagnosticAllEndpointsHealthy.
  ///
  /// In en, this message translates to:
  /// **'All REST endpoints healthy!'**
  String get relayDiagnosticAllEndpointsHealthy;

  /// No description provided for @relayDiagnosticSomeEndpointsFailed.
  ///
  /// In en, this message translates to:
  /// **'Some REST endpoints failed - see details above'**
  String get relayDiagnosticSomeEndpointsFailed;

  /// No description provided for @relayDiagnosticFoundVideoEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Found {count} video event in database} other{Found {count} video events in database}}'**
  String relayDiagnosticFoundVideoEvents(int count);

  /// No description provided for @relayDiagnosticQueryFailed.
  ///
  /// In en, this message translates to:
  /// **'Query failed. Please try again.'**
  String get relayDiagnosticQueryFailed;

  /// No description provided for @relayDiagnosticConnectedToRelays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Connected to {count} relay!} other{Connected to {count} relays!}}'**
  String relayDiagnosticConnectedToRelays(int count);

  /// No description provided for @relayDiagnosticFailedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to any relays'**
  String get relayDiagnosticFailedToConnect;

  /// No description provided for @relayDiagnosticConnectionRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection retry failed. Please try again.'**
  String get relayDiagnosticConnectionRetryFailed;

  /// No description provided for @relayDiagnosticConnectedAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Connected & Authenticated'**
  String get relayDiagnosticConnectedAuthenticated;

  /// No description provided for @relayDiagnosticConnectedOnly.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get relayDiagnosticConnectedOnly;

  /// No description provided for @relayDiagnosticNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get relayDiagnosticNotConnected;

  /// No description provided for @relayDiagnosticNoRelaysConfigured.
  ///
  /// In en, this message translates to:
  /// **'No relays configured'**
  String get relayDiagnosticNoRelaysConfigured;

  /// No description provided for @relayDiagnosticFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get relayDiagnosticFailed;

  /// Notification settings screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get notificationSettingsResetTooltip;

  /// No description provided for @notificationSettingsTypes.
  ///
  /// In en, this message translates to:
  /// **'Notification Types'**
  String get notificationSettingsTypes;

  /// No description provided for @notificationSettingsLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get notificationSettingsLikes;

  /// No description provided for @notificationSettingsLikesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone likes your videos'**
  String get notificationSettingsLikesSubtitle;

  /// No description provided for @notificationSettingsComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get notificationSettingsComments;

  /// No description provided for @notificationSettingsCommentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone comments on your videos'**
  String get notificationSettingsCommentsSubtitle;

  /// No description provided for @notificationSettingsFollows.
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get notificationSettingsFollows;

  /// No description provided for @notificationSettingsFollowsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone follows you'**
  String get notificationSettingsFollowsSubtitle;

  /// No description provided for @notificationSettingsMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get notificationSettingsMentions;

  /// No description provided for @notificationSettingsMentionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you are mentioned'**
  String get notificationSettingsMentionsSubtitle;

  /// No description provided for @notificationSettingsReposts.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get notificationSettingsReposts;

  /// No description provided for @notificationSettingsRepostsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone reposts your videos'**
  String get notificationSettingsRepostsSubtitle;

  /// No description provided for @notificationSettingsNewPosts.
  ///
  /// In en, this message translates to:
  /// **'New vines'**
  String get notificationSettingsNewPosts;

  /// No description provided for @notificationSettingsNewPostsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone you\'re watching posts'**
  String get notificationSettingsNewPostsSubtitle;

  /// No description provided for @notificationSettingsActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get notificationSettingsActions;

  /// No description provided for @notificationSettingsMarkAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get notificationSettingsMarkAllAsRead;

  /// No description provided for @notificationSettingsMarkAllAsReadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark all notifications as read'**
  String get notificationSettingsMarkAllAsReadSubtitle;

  /// No description provided for @notificationSettingsAllMarkedAsRead.
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read'**
  String get notificationSettingsAllMarkedAsRead;

  /// No description provided for @notificationSettingsMarkAllAsReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to mark all as read'**
  String get notificationSettingsMarkAllAsReadFailed;

  /// No description provided for @notificationSettingsResetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get notificationSettingsResetToDefaults;

  /// No description provided for @notificationSettingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Notifications'**
  String get notificationSettingsAbout;

  /// No description provided for @notificationSettingsAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Notifications are powered by the Nostr protocol. Real-time updates depend on your connection to Nostr relays. Some notifications may have delays.'**
  String get notificationSettingsAboutDescription;

  /// No description provided for @safetySettingsWhatYouSee.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU SEE'**
  String get safetySettingsWhatYouSee;

  /// No description provided for @safetySettingsWhatYouPublish.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU PUBLISH'**
  String get safetySettingsWhatYouPublish;

  /// No description provided for @safetySettingsShowDivineHostedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only show Divine-hosted videos'**
  String get safetySettingsShowDivineHostedOnly;

  /// No description provided for @safetySettingsShowDivineHostedOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide videos served from other media hosts'**
  String get safetySettingsShowDivineHostedOnlySubtitle;

  /// No description provided for @safetySettingsModeration.
  ///
  /// In en, this message translates to:
  /// **'MODERATION'**
  String get safetySettingsModeration;

  /// No description provided for @safetySettingsBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'BLOCKED USERS'**
  String get safetySettingsBlockedUsers;

  /// No description provided for @safetySettingsAgeVerification.
  ///
  /// In en, this message translates to:
  /// **'AGE VERIFICATION'**
  String get safetySettingsAgeVerification;

  /// No description provided for @safetySettingsAgeConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm I am 18 years or older'**
  String get safetySettingsAgeConfirmation;

  /// No description provided for @safetySettingsAgeRequired.
  ///
  /// In en, this message translates to:
  /// **'Required to view adult content'**
  String get safetySettingsAgeRequired;

  /// Subtitle on the disabled adult-content toggle for protected minors
  ///
  /// In en, this message translates to:
  /// **'Locked for your account'**
  String get safetySettingsAgeLockedForMinor;

  /// No description provided for @safetySettingsDivine.
  ///
  /// In en, this message translates to:
  /// **'Divine'**
  String get safetySettingsDivine;

  /// No description provided for @safetySettingsDivineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Official moderation service (on by default)'**
  String get safetySettingsDivineSubtitle;

  /// No description provided for @safetySettingsPeopleIFollow.
  ///
  /// In en, this message translates to:
  /// **'People I follow'**
  String get safetySettingsPeopleIFollow;

  /// No description provided for @safetySettingsPeopleIFollowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to labels from people you follow'**
  String get safetySettingsPeopleIFollowSubtitle;

  /// No description provided for @safetySettingsAddCustomLabeler.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Labeler'**
  String get safetySettingsAddCustomLabeler;

  /// No description provided for @safetySettingsAddCustomLabelerHint.
  ///
  /// In en, this message translates to:
  /// **'Enter npub...'**
  String get safetySettingsAddCustomLabelerHint;

  /// No description provided for @safetySettingsAddCustomLabelerListTitle.
  ///
  /// In en, this message translates to:
  /// **'Add custom labeler'**
  String get safetySettingsAddCustomLabelerListTitle;

  /// No description provided for @safetySettingsRemoveLabeler.
  ///
  /// In en, this message translates to:
  /// **'Remove labeler'**
  String get safetySettingsRemoveLabeler;

  /// No description provided for @safetySettingsAddCustomLabelerListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter npub address'**
  String get safetySettingsAddCustomLabelerListSubtitle;

  /// No description provided for @safetySettingsNoBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get safetySettingsNoBlockedUsers;

  /// No description provided for @safetySettingsUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get safetySettingsUnblock;

  /// No description provided for @safetySettingsUserUnblocked.
  ///
  /// In en, this message translates to:
  /// **'User unblocked'**
  String get safetySettingsUserUnblocked;

  /// No description provided for @safetySettingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get safetySettingsCancel;

  /// No description provided for @safetySettingsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get safetySettingsAdd;

  /// Creator analytics screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Creator Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsDiagnosticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get analyticsDiagnosticsTooltip;

  /// No description provided for @analyticsDiagnosticsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle diagnostics'**
  String get analyticsDiagnosticsSemanticLabel;

  /// No description provided for @analyticsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get analyticsRetry;

  /// No description provided for @analyticsUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load analytics.'**
  String get analyticsUnableToLoad;

  /// No description provided for @analyticsServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Creator analytics is having server trouble. Please try again in a moment.'**
  String get analyticsServerUnavailable;

  /// No description provided for @analyticsConnectionIssue.
  ///
  /// In en, this message translates to:
  /// **'Creator analytics could not connect. Check your connection and try again.'**
  String get analyticsConnectionIssue;

  /// No description provided for @analyticsSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view creator analytics.'**
  String get analyticsSignInRequired;

  /// No description provided for @analyticsViewDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Views are currently unavailable from the relay for these posts. Like/comment/repost metrics are still accurate.'**
  String get analyticsViewDataUnavailable;

  /// No description provided for @analyticsViewDataTitle.
  ///
  /// In en, this message translates to:
  /// **'View Data'**
  String get analyticsViewDataTitle;

  /// No description provided for @analyticsUpdatedTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Updated {time} • Scores use likes, comments, reposts, and views/loops from Funnelcake when available.'**
  String analyticsUpdatedTimestamp(String time);

  /// No description provided for @analyticsVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get analyticsVideos;

  /// No description provided for @analyticsViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get analyticsViews;

  /// No description provided for @analyticsInteractions.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get analyticsInteractions;

  /// No description provided for @analyticsEngagement.
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get analyticsEngagement;

  /// No description provided for @analyticsFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get analyticsFollowers;

  /// No description provided for @analyticsAvgPerPost.
  ///
  /// In en, this message translates to:
  /// **'Avg/Post'**
  String get analyticsAvgPerPost;

  /// No description provided for @analyticsInteractionMix.
  ///
  /// In en, this message translates to:
  /// **'Interaction Mix'**
  String get analyticsInteractionMix;

  /// No description provided for @analyticsLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get analyticsLikes;

  /// No description provided for @analyticsComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get analyticsComments;

  /// No description provided for @analyticsReposts.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get analyticsReposts;

  /// No description provided for @analyticsPerformanceHighlights.
  ///
  /// In en, this message translates to:
  /// **'Performance Highlights'**
  String get analyticsPerformanceHighlights;

  /// No description provided for @analyticsMostViewed.
  ///
  /// In en, this message translates to:
  /// **'Most viewed'**
  String get analyticsMostViewed;

  /// No description provided for @analyticsMostDiscussed.
  ///
  /// In en, this message translates to:
  /// **'Most discussed'**
  String get analyticsMostDiscussed;

  /// No description provided for @analyticsMostReposted.
  ///
  /// In en, this message translates to:
  /// **'Most reposted'**
  String get analyticsMostReposted;

  /// No description provided for @analyticsNoVideosYet.
  ///
  /// In en, this message translates to:
  /// **'No videos yet'**
  String get analyticsNoVideosYet;

  /// No description provided for @analyticsViewDataUnavailableShort.
  ///
  /// In en, this message translates to:
  /// **'View data unavailable'**
  String get analyticsViewDataUnavailableShort;

  /// No description provided for @analyticsViewsCount.
  ///
  /// In en, this message translates to:
  /// **'{countValue, plural, =1{{count} view} other{{count} views}}'**
  String analyticsViewsCount(int countValue, String count);

  /// No description provided for @analyticsCommentsCount.
  ///
  /// In en, this message translates to:
  /// **'{countValue, plural, =1{{count} comment} other{{count} comments}}'**
  String analyticsCommentsCount(int countValue, String count);

  /// No description provided for @analyticsRepostsCount.
  ///
  /// In en, this message translates to:
  /// **'{countValue, plural, =1{{count} repost} other{{count} reposts}}'**
  String analyticsRepostsCount(int countValue, String count);

  /// No description provided for @analyticsTopContent.
  ///
  /// In en, this message translates to:
  /// **'Top Content'**
  String get analyticsTopContent;

  /// No description provided for @analyticsPublishPrompt.
  ///
  /// In en, this message translates to:
  /// **'Publish a few videos to see rankings.'**
  String get analyticsPublishPrompt;

  /// No description provided for @analyticsEngagementRateExplainer.
  ///
  /// In en, this message translates to:
  /// **'Right-side % = Engagement Rate (interactions divided by views).'**
  String get analyticsEngagementRateExplainer;

  /// No description provided for @analyticsEngagementRateNoViews.
  ///
  /// In en, this message translates to:
  /// **'Engagement Rate needs view data; values show as N/A until views are available.'**
  String get analyticsEngagementRateNoViews;

  /// No description provided for @analyticsEngagementLabel.
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get analyticsEngagementLabel;

  /// No description provided for @analyticsViewsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'views unavailable'**
  String get analyticsViewsUnavailable;

  /// No description provided for @analyticsInteractionsCount.
  ///
  /// In en, this message translates to:
  /// **'{countValue, plural, =1{{count} interaction} other{{count} interactions}}'**
  String analyticsInteractionsCount(int countValue, String count);

  /// No description provided for @analyticsPostAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Post Analytics'**
  String get analyticsPostAnalytics;

  /// No description provided for @analyticsOpenPost.
  ///
  /// In en, this message translates to:
  /// **'Open Post'**
  String get analyticsOpenPost;

  /// No description provided for @analyticsRecentDailyInteractions.
  ///
  /// In en, this message translates to:
  /// **'Recent Daily Interactions'**
  String get analyticsRecentDailyInteractions;

  /// No description provided for @analyticsNoActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity in this range yet.'**
  String get analyticsNoActivityYet;

  /// No description provided for @analyticsDailyInteractionsExplainer.
  ///
  /// In en, this message translates to:
  /// **'Interactions = likes + comments + reposts by post date.'**
  String get analyticsDailyInteractionsExplainer;

  /// No description provided for @analyticsDailyBarExplainer.
  ///
  /// In en, this message translates to:
  /// **'Bar length is relative to your highest day in this window.'**
  String get analyticsDailyBarExplainer;

  /// No description provided for @analyticsAudienceSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Audience Snapshot'**
  String get analyticsAudienceSnapshot;

  /// No description provided for @analyticsFollowersCount.
  ///
  /// In en, this message translates to:
  /// **'Followers: {count}'**
  String analyticsFollowersCount(String count);

  /// No description provided for @analyticsFollowingCount.
  ///
  /// In en, this message translates to:
  /// **'Following: {count}'**
  String analyticsFollowingCount(String count);

  /// No description provided for @analyticsAudiencePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Audience source/geo/time breakdowns will populate as Funnelcake adds audience analytics endpoints.'**
  String get analyticsAudiencePlaceholder;

  /// No description provided for @analyticsRetention.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get analyticsRetention;

  /// No description provided for @analyticsRetentionWithViews.
  ///
  /// In en, this message translates to:
  /// **'Retention curve and watch-time breakdown will appear once per-second/per-bucket retention arrives from Funnelcake.'**
  String get analyticsRetentionWithViews;

  /// No description provided for @analyticsRetentionWithoutViews.
  ///
  /// In en, this message translates to:
  /// **'Retention data unavailable until view+watch-time analytics are returned by Funnelcake.'**
  String get analyticsRetentionWithoutViews;

  /// No description provided for @analyticsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get analyticsDiagnostics;

  /// No description provided for @analyticsDiagnosticsTotalVideos.
  ///
  /// In en, this message translates to:
  /// **'Total videos: {count}'**
  String analyticsDiagnosticsTotalVideos(int count);

  /// No description provided for @analyticsDiagnosticsWithViews.
  ///
  /// In en, this message translates to:
  /// **'With views: {count}'**
  String analyticsDiagnosticsWithViews(int count);

  /// No description provided for @analyticsDiagnosticsMissingViews.
  ///
  /// In en, this message translates to:
  /// **'Missing views: {count}'**
  String analyticsDiagnosticsMissingViews(int count);

  /// No description provided for @analyticsDiagnosticsHydratedBulk.
  ///
  /// In en, this message translates to:
  /// **'Hydrated (bulk): {count}'**
  String analyticsDiagnosticsHydratedBulk(int count);

  /// No description provided for @analyticsDiagnosticsHydratedViews.
  ///
  /// In en, this message translates to:
  /// **'Hydrated (/views): {count}'**
  String analyticsDiagnosticsHydratedViews(int count);

  /// No description provided for @analyticsDiagnosticsSources.
  ///
  /// In en, this message translates to:
  /// **'Sources: {sources}'**
  String analyticsDiagnosticsSources(String sources);

  /// No description provided for @analyticsDiagnosticsFailedSources.
  ///
  /// In en, this message translates to:
  /// **'Failed sources: {sources}'**
  String analyticsDiagnosticsFailedSources(String sources);

  /// No description provided for @analyticsDiagnosticsUseFixture.
  ///
  /// In en, this message translates to:
  /// **'Use fixture data'**
  String get analyticsDiagnosticsUseFixture;

  /// No description provided for @analyticsNa.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get analyticsNa;

  /// No description provided for @authCreateNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a new Divine account'**
  String get authCreateNewAccount;

  /// Short returning-user welcome-screen action label for creating a new account.
  ///
  /// In en, this message translates to:
  /// **'Create new account'**
  String get authCreateNewAccountShort;

  /// No description provided for @authSignInDifferentAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in with an existing account'**
  String get authSignInDifferentAccount;

  /// Returning-user welcome-screen action label for signing in with a different existing account.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get authUseAnotherAccount;

  /// Primary returning-user welcome-screen action that resumes the selected cached account.
  ///
  /// In en, this message translates to:
  /// **'Continue as {displayName}'**
  String authContinueAs(String displayName);

  /// No description provided for @authRecoveryDraftsOwner.
  ///
  /// In en, this message translates to:
  /// **'Your drafts and clips are saved for this account'**
  String get authRecoveryDraftsOwner;

  /// No description provided for @authRecoveryOtherAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'Signing in here will hide those drafts and clips'**
  String get authRecoveryOtherAccountWarning;

  /// No description provided for @authTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By selecting an option below, you confirm you are at least 16 years old (or have completed '**
  String get authTermsPrefix;

  /// Inline link in the welcome-screen terms notice that opens the public family-guidance / age-authorization flow.
  ///
  /// In en, this message translates to:
  /// **'Divine age authorization'**
  String get authTermsAgeAuthorizationCta;

  /// Text after the Divine age authorization link in the welcome-screen terms notice.
  ///
  /// In en, this message translates to:
  /// **') and agree to the '**
  String get authTermsAfterAgeAuthorization;

  /// No description provided for @authTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authTermsOfService;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// No description provided for @authTermsAnd.
  ///
  /// In en, this message translates to:
  /// **', and '**
  String get authTermsAnd;

  /// No description provided for @authSafetyStandards.
  ///
  /// In en, this message translates to:
  /// **'Safety Standards'**
  String get authSafetyStandards;

  /// No description provided for @authAmberNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Amber app is not installed'**
  String get authAmberNotInstalled;

  /// No description provided for @authAmberConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect with Amber'**
  String get authAmberConnectionFailed;

  /// No description provided for @authPasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists with that email, a password reset link has been sent.'**
  String get authPasswordResetSent;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInTitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get authPasswordRequired;

  /// No description provided for @authConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get authConfirmPasswordRequired;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authImportNostrKey.
  ///
  /// In en, this message translates to:
  /// **'Import Nostr key'**
  String get authImportNostrKey;

  /// No description provided for @authConnectSignerApp.
  ///
  /// In en, this message translates to:
  /// **'Connect with a signer app'**
  String get authConnectSignerApp;

  /// No description provided for @authSignInWithAmber.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Amber'**
  String get authSignInWithAmber;

  /// No description provided for @authSignInWithBrowserExtension.
  ///
  /// In en, this message translates to:
  /// **'Sign in with browser extension'**
  String get authSignInWithBrowserExtension;

  /// No description provided for @authNip07ConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to your browser extension.'**
  String get authNip07ConnectionFailed;

  /// No description provided for @authNip07ExtensionNotFound.
  ///
  /// In en, this message translates to:
  /// **'No browser extension found. Install Alby, nos2x, or another NIP-07 compatible extension.'**
  String get authNip07ExtensionNotFound;

  /// No description provided for @authSignInOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in options'**
  String get authSignInOptionsTitle;

  /// No description provided for @authInfoEmailPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Email & Password'**
  String get authInfoEmailPasswordTitle;

  /// No description provided for @authInfoEmailPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Divine account. If you registered with an email and password, use them here.'**
  String get authInfoEmailPasswordDescription;

  /// No description provided for @authInfoImportNostrKeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Already have a Nostr identity? Import your nsec private key from another client.'**
  String get authInfoImportNostrKeyDescription;

  /// No description provided for @authInfoSignerAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Signer App'**
  String get authInfoSignerAppTitle;

  /// No description provided for @authInfoSignerAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect using a NIP-46 compatible remote signer like nsecBunker for enhanced key security.'**
  String get authInfoSignerAppDescription;

  /// No description provided for @authInfoAmberTitle.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get authInfoAmberTitle;

  /// No description provided for @authInfoAmberDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the Amber signer app on Android to manage your Nostr keys securely.'**
  String get authInfoAmberDescription;

  /// No description provided for @authInfoBrowserExtensionTitle.
  ///
  /// In en, this message translates to:
  /// **'Browser Extension'**
  String get authInfoBrowserExtensionTitle;

  /// No description provided for @authInfoBrowserExtensionDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a NIP-07 browser extension like Alby or nos2x. Your keys stay in the extension — Divine never sees them.'**
  String get authInfoBrowserExtensionDescription;

  /// Shown when email/password sign-in fails. Must stay neutral about whether the account exists — the server returns the same error for a wrong password and an unknown account.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password. Give it another try.'**
  String get authSignInErrorInvalidCredentials;

  /// Shown when the account exists but its email is not yet verified (HTTP 403 on sign-in).
  ///
  /// In en, this message translates to:
  /// **'Verify your email before signing in — check your inbox for the link.'**
  String get authSignInErrorEmailNotVerified;

  /// Shown when the submitted email is malformed on sign-in.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a valid email address.'**
  String get authSignInErrorInvalidEmail;

  /// Shown when a network/transport problem prevents a sign-in verdict.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection and try again.'**
  String get authSignInErrorNetwork;

  /// Fallback shown for any other sign-in failure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authSignInErrorGeneric;

  /// Leading prose of the tappable hint under a failed sign-in, before the call-to-action span. Trailing space is intentional.
  ///
  /// In en, this message translates to:
  /// **'Not sure how you got in last time? '**
  String get authSignInOptionsHintPrefix;

  /// Tappable call-to-action span of the failed-sign-in hint. Opens the sheet listing all sign-in methods.
  ///
  /// In en, this message translates to:
  /// **'See every sign-in option'**
  String get authSignInOptionsHintCta;

  /// No description provided for @authCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountTitle;

  /// No description provided for @authBackToInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Back to invite code'**
  String get authBackToInviteCode;

  /// No description provided for @authUseDivineNoBackup.
  ///
  /// In en, this message translates to:
  /// **'Use Divine with no backup'**
  String get authUseDivineNoBackup;

  /// No description provided for @authSkipConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'One last thing...'**
  String get authSkipConfirmTitle;

  /// No description provided for @authSkipConfirmKeyCreated.
  ///
  /// In en, this message translates to:
  /// **'You\'re in! We\'ll create a secure key that powers your Divine account.'**
  String get authSkipConfirmKeyCreated;

  /// No description provided for @authSkipConfirmKeyOnly.
  ///
  /// In en, this message translates to:
  /// **'Without an email, your key is the only way Divine knows this account is yours.'**
  String get authSkipConfirmKeyOnly;

  /// No description provided for @authSkipConfirmRecommendEmail.
  ///
  /// In en, this message translates to:
  /// **'You can access your key in the app, but, if you\'re not technical we recommend adding an email and password now. It makes it easier to sign in and restore your account if you lose or reset this device.'**
  String get authSkipConfirmRecommendEmail;

  /// No description provided for @authAddEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Add email & password'**
  String get authAddEmailPassword;

  /// No description provided for @authUseThisDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Use this device only'**
  String get authUseThisDeviceOnly;

  /// No description provided for @authCompleteRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete your registration'**
  String get authCompleteRegistration;

  /// No description provided for @authVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get authVerifying;

  /// No description provided for @authVerificationLinkSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to:'**
  String get authVerificationLinkSent;

  /// No description provided for @authClickVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'Please click the link in your email to\ncomplete your registration.'**
  String get authClickVerificationLink;

  /// No description provided for @authPleaseWaitVerifying.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we verify your email...'**
  String get authPleaseWaitVerifying;

  /// No description provided for @authWaitingForVerification.
  ///
  /// In en, this message translates to:
  /// **'Waiting for verification'**
  String get authWaitingForVerification;

  /// No description provided for @authOpenEmailApp.
  ///
  /// In en, this message translates to:
  /// **'Open email app'**
  String get authOpenEmailApp;

  /// No description provided for @authVerificationPinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Or enter the 6-digit code from your email'**
  String get authVerificationPinPrompt;

  /// No description provided for @authVerificationPinFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get authVerificationPinFieldLabel;

  /// No description provided for @authVerificationPinSubmit.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get authVerificationPinSubmit;

  /// No description provided for @authVerificationResendPrompt.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get it?'**
  String get authVerificationResendPrompt;

  /// No description provided for @authVerificationResend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get authVerificationResend;

  /// Disabled-state label for the resend button during its cooldown. {time} is a preformatted m:ss countdown (e.g. 4:59).
  ///
  /// In en, this message translates to:
  /// **'Resend in {time}'**
  String authVerificationResendCooldown(String time);

  /// No description provided for @authVerificationResendFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t resend the email. Try again.'**
  String get authVerificationResendFailed;

  /// Shown beneath the Resend button when the pending signup registration has expired, so resending cannot recover it. Tells the user to restart signup.
  ///
  /// In en, this message translates to:
  /// **'That signup expired. Start again to get a fresh code.'**
  String get authVerificationResendExpired;

  /// Shown beneath the Resend button when the server has no resend endpoint, so retrying cannot help. The button stays tappable; only the resend request is unavailable. Points the user at the PIN in the email they already received.
  ///
  /// In en, this message translates to:
  /// **'Resending isn\'t available right now. Use the 6-digit code from the email we already sent you.'**
  String get authVerificationResendUnavailable;

  /// Shown on the email-verification screen after the 15-minute polling window elapses, explaining why the waiting spinner disappeared and what to do instead.
  ///
  /// In en, this message translates to:
  /// **'We stopped checking for you. Enter the 6-digit code from your email to finish signing in.'**
  String get authVerificationPollingStopped;

  /// No description provided for @authWelcomeToDivine.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Divine!'**
  String get authWelcomeToDivine;

  /// No description provided for @authEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Your email has been verified.'**
  String get authEmailVerified;

  /// No description provided for @authSigningYouIn.
  ///
  /// In en, this message translates to:
  /// **'Signing you in'**
  String get authSigningYouIn;

  /// No description provided for @authErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Uh oh.'**
  String get authErrorTitle;

  /// No description provided for @authVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'We failed to verify your email.\nPlease try again.'**
  String get authVerificationFailed;

  /// No description provided for @authStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get authStartOver;

  /// No description provided for @authEmailVerifiedLogin.
  ///
  /// In en, this message translates to:
  /// **'Email verified! Please log in to continue.'**
  String get authEmailVerifiedLogin;

  /// No description provided for @authVerificationLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This verification link is no longer valid.'**
  String get authVerificationLinkExpired;

  /// No description provided for @authVerificationConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Unable to verify email. Please check your connection and try again.'**
  String get authVerificationConnectionError;

  /// No description provided for @authWaitlistConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re in!'**
  String get authWaitlistConfirmTitle;

  /// Waitlist confirmation message with email
  ///
  /// In en, this message translates to:
  /// **'We\'ll share updates at {email}.\nWhen more invite codes are available, we\'ll send them your way.'**
  String authWaitlistUpdatesAt(String email);

  /// No description provided for @authOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get authOk;

  /// No description provided for @authTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get authTryAgain;

  /// No description provided for @authContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get authContactSupport;

  /// Error when email client cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open {email}'**
  String authCouldNotOpenEmail(String email);

  /// No description provided for @authAddInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Add your invite code'**
  String get authAddInviteCode;

  /// No description provided for @authInviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get authInviteCodeLabel;

  /// No description provided for @authEnterYourCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your code'**
  String get authEnterYourCode;

  /// No description provided for @authNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get authNext;

  /// No description provided for @authJoinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join waitlist'**
  String get authJoinWaitlist;

  /// No description provided for @authJoinWaitlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the waitlist'**
  String get authJoinWaitlistTitle;

  /// No description provided for @authJoinWaitlistDescription.
  ///
  /// In en, this message translates to:
  /// **'Share your email and we\'ll send an invite code as access opens up.'**
  String get authJoinWaitlistDescription;

  /// No description provided for @authJoinWaitlistNewsletterOptIn.
  ///
  /// In en, this message translates to:
  /// **'Send me Divine inspiration'**
  String get authJoinWaitlistNewsletterOptIn;

  /// No description provided for @authInviteAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'Invite access help'**
  String get authInviteAccessHelp;

  /// No description provided for @authGeneratingConnection.
  ///
  /// In en, this message translates to:
  /// **'Generating connection...'**
  String get authGeneratingConnection;

  /// No description provided for @authConnectedAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Connected! Authenticating...'**
  String get authConnectedAuthenticating;

  /// No description provided for @authConnectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get authConnectionTimedOut;

  /// No description provided for @authApproveConnection.
  ///
  /// In en, this message translates to:
  /// **'Make sure you approved the connection in your signer app.'**
  String get authApproveConnection;

  /// No description provided for @authConnectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Connection cancelled'**
  String get authConnectionCancelled;

  /// No description provided for @authConnectionCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'The connection was cancelled.'**
  String get authConnectionCancelledMessage;

  /// No description provided for @authConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get authConnectionFailed;

  /// No description provided for @authUnknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get authUnknownError;

  /// No description provided for @authNostrConnectStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the signer. Check your connection and try again.'**
  String get authNostrConnectStartFailed;

  /// No description provided for @authNostrConnectInvalidSession.
  ///
  /// In en, this message translates to:
  /// **'This connection link is no longer valid. Start a new one.'**
  String get authNostrConnectInvalidSession;

  /// No description provided for @authNostrConnectSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Almost there — we couldn\'t finish signing you in. Try again.'**
  String get authNostrConnectSetupFailed;

  /// No description provided for @authUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied to clipboard'**
  String get authUrlCopied;

  /// No description provided for @authConnectToDivine.
  ///
  /// In en, this message translates to:
  /// **'Connect to Divine'**
  String get authConnectToDivine;

  /// No description provided for @authPasteBunkerUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste bunker:// URL'**
  String get authPasteBunkerUrl;

  /// No description provided for @authBunkerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'bunker:// URL'**
  String get authBunkerUrlHint;

  /// No description provided for @authInvalidBunkerUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid bunker URL. It should start with bunker://'**
  String get authInvalidBunkerUrl;

  /// No description provided for @authScanSignerApp.
  ///
  /// In en, this message translates to:
  /// **'Scan with your\nsigner app to connect.'**
  String get authScanSignerApp;

  /// Waiting indicator with elapsed seconds
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection... {seconds}s'**
  String authWaitingForConnection(int seconds);

  /// No description provided for @authCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get authCopyUrl;

  /// No description provided for @authShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get authShare;

  /// No description provided for @authAddBunker.
  ///
  /// In en, this message translates to:
  /// **'Add bunker'**
  String get authAddBunker;

  /// No description provided for @authCompatibleSignerApps.
  ///
  /// In en, this message translates to:
  /// **'Compatible Signer apps'**
  String get authCompatibleSignerApps;

  /// No description provided for @authFailedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect'**
  String get authFailedToConnect;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPasswordTitle;

  /// No description provided for @authResetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter your new password. It must be at least 8 characters in length.'**
  String get authResetPasswordSubtitle;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get authNewPasswordLabel;

  /// No description provided for @authConfirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get authConfirmNewPasswordLabel;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successful. Please log in.'**
  String get authPasswordResetSuccess;

  /// No description provided for @authPasswordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Password reset failed'**
  String get authPasswordResetFailed;

  /// No description provided for @authUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get authUnexpectedError;

  /// No description provided for @authUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get authUpdatePassword;

  /// No description provided for @authSecureAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure account'**
  String get authSecureAccountTitle;

  /// No description provided for @authUnableToAccessKeys.
  ///
  /// In en, this message translates to:
  /// **'Unable to access your keys. Please try again.'**
  String get authUnableToAccessKeys;

  /// No description provided for @authRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get authRegistrationFailed;

  /// No description provided for @authRegistrationComplete.
  ///
  /// In en, this message translates to:
  /// **'Registration complete. Please check your email.'**
  String get authRegistrationComplete;

  /// Shown in place on the Secure account screen when registration fails with a server CONFLICT, which covers both the key already being registered and the entered email already being taken. Deliberately does not assert the user owns the account, since the email case may belong to a different account. Presents two primary actions (retry with a different email, or sign in to the existing account) with Contact support as a fallback, not an equal option.
  ///
  /// In en, this message translates to:
  /// **'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.'**
  String get authSecureAccountAlreadyRegistered;

  /// No description provided for @authFailedToSendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email.'**
  String get authFailedToSendResetEmail;

  /// No description provided for @authSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get authSending;

  /// No description provided for @authSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// No description provided for @authVerificationErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Verification timed out. Please try registering again.'**
  String get authVerificationErrorTimeout;

  /// No description provided for @authVerificationErrorMissingCode.
  ///
  /// In en, this message translates to:
  /// **'Verification failed — missing authorization code.'**
  String get authVerificationErrorMissingCode;

  /// No description provided for @authVerificationErrorPollFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please try again.'**
  String get authVerificationErrorPollFailed;

  /// No description provided for @authVerificationErrorNetworkExchange.
  ///
  /// In en, this message translates to:
  /// **'Network error during sign-in. Please try again.'**
  String get authVerificationErrorNetworkExchange;

  /// No description provided for @authVerificationErrorOAuthExchange.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please try registering again.'**
  String get authVerificationErrorOAuthExchange;

  /// No description provided for @authVerificationErrorSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try logging in manually.'**
  String get authVerificationErrorSignInFailed;

  /// No description provided for @authVerificationEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Sign in instead.'**
  String get authVerificationEmailAlreadyRegistered;

  /// No description provided for @authVerificationErrorPinInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t match. Double-check it and try again.'**
  String get authVerificationErrorPinInvalid;

  /// No description provided for @authVerificationErrorPinExpired.
  ///
  /// In en, this message translates to:
  /// **'That code has expired. Tap resend to get a new one.'**
  String get authVerificationErrorPinExpired;

  /// No description provided for @authVerificationErrorPinLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Tap resend to get a fresh code.'**
  String get authVerificationErrorPinLocked;

  /// No description provided for @authVerificationErrorPinFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify that code. Please try again.'**
  String get authVerificationErrorPinFailed;

  /// No description provided for @authVerificationErrorPinUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Code entry isn\'t available right now. Tap the link in your email, or resend to get a fresh one.'**
  String get authVerificationErrorPinUnavailable;

  /// Inline error on the invite-code field when the typed text is not shaped like an invite code.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code like ABCD-EFGH.'**
  String get authInviteCodeErrorMalformed;

  /// Inline error on the invite-code field when the server does not recognise the code.
  ///
  /// In en, this message translates to:
  /// **'That invite code does not look valid.'**
  String get authInviteCodeErrorNotFound;

  /// Inline error on the invite-code field when the code was already claimed or revoked.
  ///
  /// In en, this message translates to:
  /// **'That invite code has already been used or revoked.'**
  String get authInviteCodeErrorAlreadyUsed;

  /// Block error on the invite gate when the creator has no invites left.
  ///
  /// In en, this message translates to:
  /// **'This creator\'s invites are full'**
  String get authInviteGateErrorCreatorFull;

  /// Block error on the invite gate when the code is real but no longer usable.
  ///
  /// In en, this message translates to:
  /// **'That invite code is unavailable. Join the waitlist and we\'ll send an invite when there\'s room.'**
  String get authInviteGateErrorUnavailable;

  /// Block error on the invite gate when the invite service could not give a verdict. Retryable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check that code. Try again.'**
  String get authInviteGateErrorCheckFailed;

  /// Block error on the invite gate when an inbound link reported an unclassifiable problem.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try your invite code again.'**
  String get authInviteGateErrorUnknown;

  /// No description provided for @authInviteErrorAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'That invite code is no longer available. Go back to your invite code, join the waitlist, or contact support.'**
  String get authInviteErrorAlreadyUsed;

  /// No description provided for @authInviteErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'That invite code cannot be used right now. Go back to your invite code, join the waitlist, or contact support.'**
  String get authInviteErrorInvalid;

  /// No description provided for @authInviteErrorTemporary.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm your invite right now. Go back to your invite code and try again, or contact support.'**
  String get authInviteErrorTemporary;

  /// No description provided for @authInviteErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t activate your invite. Go back to your invite code, join the waitlist, or contact support.'**
  String get authInviteErrorUnknown;

  /// No description provided for @shareSheetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shareSheetSave;

  /// Share-sheet action label shown in place of "Save" once a relay-reconciled read confirms the video is already in the user's global bookmarks. It names the direction of the tap, which removes the bookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get shareSheetRemoveFromSaved;

  /// No description provided for @shareSheetSaveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to Gallery'**
  String get shareSheetSaveToGallery;

  /// No description provided for @shareSheetSaveWithWatermark.
  ///
  /// In en, this message translates to:
  /// **'Save with Watermark'**
  String get shareSheetSaveWithWatermark;

  /// No description provided for @shareSheetSaveVideo.
  ///
  /// In en, this message translates to:
  /// **'Save Video'**
  String get shareSheetSaveVideo;

  /// Share sheet action label for importing a classic Vine into the clip library
  ///
  /// In en, this message translates to:
  /// **'Add to clips'**
  String get shareSheetAddToClips;

  /// Title for the sheet that lets a user choose the local library title for an imported clip
  ///
  /// In en, this message translates to:
  /// **'Name this clip'**
  String get shareSheetNameClipTitle;

  /// Subtitle for the sheet that lets a user choose the local library title for an imported clip
  ///
  /// In en, this message translates to:
  /// **'Pick a name you\'ll recognize in your library.'**
  String get shareSheetNameClipSubtitle;

  /// Label for the text field where the user names an imported clip
  ///
  /// In en, this message translates to:
  /// **'Clip title'**
  String get shareSheetClipTitleLabel;

  /// Button label confirming the imported clip title and saving it to the local library
  ///
  /// In en, this message translates to:
  /// **'Save clip'**
  String get shareSheetSaveClip;

  /// Snackbar shown after importing a clip into the local library with its chosen title
  ///
  /// In en, this message translates to:
  /// **'Saved \"{title}\" to clips'**
  String shareSheetSavedClipToClips(String title);

  /// Fallback title if a saved clip somehow has no local library title
  ///
  /// In en, this message translates to:
  /// **'Untitled clip'**
  String get shareSheetUntitledClip;

  /// Snackbar shown when importing a classic Vine into the clip library fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add to clips'**
  String get shareSheetAddToClipsFailed;

  /// No description provided for @shareSheetAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get shareSheetAddToList;

  /// No description provided for @shareSheetCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get shareSheetCopy;

  /// No description provided for @shareSheetShareVia.
  ///
  /// In en, this message translates to:
  /// **'Share via'**
  String get shareSheetShareVia;

  /// No description provided for @shareSheetEventJson.
  ///
  /// In en, this message translates to:
  /// **'Event JSON'**
  String get shareSheetEventJson;

  /// No description provided for @shareSheetEventId.
  ///
  /// In en, this message translates to:
  /// **'Event ID'**
  String get shareSheetEventId;

  /// No description provided for @shareSheetMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get shareSheetMoreActions;

  /// No description provided for @shareSheetCrosspost.
  ///
  /// In en, this message translates to:
  /// **'Crosspost'**
  String get shareSheetCrosspost;

  /// No description provided for @crosspostSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Crosspost this video'**
  String get crosspostSheetTitle;

  /// No description provided for @crosspostSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send it to your connected platforms. Posting can take a few minutes.'**
  String get crosspostSheetSubtitle;

  /// No description provided for @crosspostSubmit.
  ///
  /// In en, this message translates to:
  /// **'Crosspost'**
  String get crosspostSubmit;

  /// No description provided for @crosspostStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get crosspostStatusQueued;

  /// No description provided for @crosspostStatusUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get crosspostStatusUploading;

  /// No description provided for @crosspostStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get crosspostStatusProcessing;

  /// No description provided for @crosspostStatusPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get crosspostStatusPosted;

  /// No description provided for @crosspostStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get crosspostStatusFailed;

  /// No description provided for @crosspostStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get crosspostStatusSkipped;

  /// No description provided for @crosspostStatusNeedsReauth.
  ///
  /// In en, this message translates to:
  /// **'Needs reconnecting'**
  String get crosspostStatusNeedsReauth;

  /// No description provided for @crosspostViewPost.
  ///
  /// In en, this message translates to:
  /// **'View post'**
  String get crosspostViewPost;

  /// No description provided for @crosspostReconnectPrompt.
  ///
  /// In en, this message translates to:
  /// **'Reconnect {platform} in crossposting settings to keep posting.'**
  String crosspostReconnectPrompt(String platform);

  /// No description provided for @crosspostReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get crosspostReconnect;

  /// No description provided for @crosspostErrorNotOwner.
  ///
  /// In en, this message translates to:
  /// **'Only your own videos can be crossposted.'**
  String get crosspostErrorNotOwner;

  /// No description provided for @crosspostErrorNotEligible.
  ///
  /// In en, this message translates to:
  /// **'This video isn\'t eligible for crossposting.'**
  String get crosspostErrorNotEligible;

  /// No description provided for @crosspostErrorNotConnected.
  ///
  /// In en, this message translates to:
  /// **'That platform isn\'t connected.'**
  String get crosspostErrorNotConnected;

  /// No description provided for @crosspostErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Reconnect your account, then try again.'**
  String get crosspostErrorUnauthorized;

  /// No description provided for @crosspostErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the crossposter. Try again in a moment.'**
  String get crosspostErrorNetwork;

  /// No description provided for @crosspostFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Crosspost failed.'**
  String get crosspostFailedGeneric;

  /// No description provided for @crosspostStillWorking.
  ///
  /// In en, this message translates to:
  /// **'Still working. You can close this — posting continues in the background.'**
  String get crosspostStillWorking;

  /// No description provided for @crosspostDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get crosspostDone;

  /// No description provided for @watermarkDownloadSavedToCameraRoll.
  ///
  /// In en, this message translates to:
  /// **'Saved to Camera Roll'**
  String get watermarkDownloadSavedToCameraRoll;

  /// No description provided for @watermarkDownloadShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get watermarkDownloadShare;

  /// No description provided for @watermarkDownloadDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get watermarkDownloadDone;

  /// No description provided for @watermarkDownloadPhotosAccessNeeded.
  ///
  /// In en, this message translates to:
  /// **'Photos Access Needed'**
  String get watermarkDownloadPhotosAccessNeeded;

  /// No description provided for @watermarkDownloadPhotosAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'To save videos, allow Photos access in Settings.'**
  String get watermarkDownloadPhotosAccessDescription;

  /// No description provided for @watermarkDownloadOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get watermarkDownloadOpenSettings;

  /// No description provided for @watermarkDownloadNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get watermarkDownloadNotNow;

  /// No description provided for @watermarkDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get watermarkDownloadFailed;

  /// No description provided for @watermarkDownloadDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get watermarkDownloadDismiss;

  /// No description provided for @watermarkDownloadStageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading Video'**
  String get watermarkDownloadStageDownloading;

  /// No description provided for @watermarkDownloadStageWatermarking.
  ///
  /// In en, this message translates to:
  /// **'Adding Watermark'**
  String get watermarkDownloadStageWatermarking;

  /// No description provided for @watermarkDownloadStageSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving to Camera Roll'**
  String get watermarkDownloadStageSaving;

  /// No description provided for @watermarkDownloadStageDownloadingDesc.
  ///
  /// In en, this message translates to:
  /// **'Fetching the video from the network...'**
  String get watermarkDownloadStageDownloadingDesc;

  /// No description provided for @watermarkDownloadStageWatermarkingDesc.
  ///
  /// In en, this message translates to:
  /// **'Applying the Divine watermark...'**
  String get watermarkDownloadStageWatermarkingDesc;

  /// No description provided for @watermarkDownloadStageSavingDesc.
  ///
  /// In en, this message translates to:
  /// **'Saving the watermarked video to your camera roll...'**
  String get watermarkDownloadStageSavingDesc;

  /// No description provided for @shareMenuBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get shareMenuBookmarks;

  /// No description provided for @shareMenuFollowSetsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} follow set available} other{{count} follow sets available}}'**
  String shareMenuFollowSetsAvailable(int count);

  /// No description provided for @peopleListsAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get peopleListsAddToList;

  /// No description provided for @peopleListsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get peopleListsSheetTitle;

  /// No description provided for @peopleListsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No lists yet'**
  String get peopleListsEmptyTitle;

  /// No description provided for @peopleListsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a list to start grouping people.'**
  String get peopleListsEmptySubtitle;

  /// No description provided for @peopleListsCreateList.
  ///
  /// In en, this message translates to:
  /// **'Create list'**
  String get peopleListsCreateList;

  /// No description provided for @peopleListsNewListTitle.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get peopleListsNewListTitle;

  /// AppBar title for the people-list members route when it is reached with a missing or empty list id (e.g., via a malformed deep link).
  ///
  /// In en, this message translates to:
  /// **'People list'**
  String get peopleListsRouteTitle;

  /// No description provided for @peopleListsListNameLabel.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get peopleListsListNameLabel;

  /// No description provided for @peopleListsListNameHint.
  ///
  /// In en, this message translates to:
  /// **'Close friends'**
  String get peopleListsListNameHint;

  /// No description provided for @peopleListsCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get peopleListsCreateButton;

  /// No description provided for @peopleListsAddPeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get peopleListsAddPeopleTitle;

  /// No description provided for @peopleListsAddPeopleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get peopleListsAddPeopleTooltip;

  /// No description provided for @peopleListsAddPeopleSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Add people to list'**
  String get peopleListsAddPeopleSemanticLabel;

  /// No description provided for @peopleListsListNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'List not found'**
  String get peopleListsListNotFoundTitle;

  /// No description provided for @peopleListsListNotFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'List not found. It may have been deleted.'**
  String get peopleListsListNotFoundSubtitle;

  /// No description provided for @peopleListsListDeletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This list may have been deleted.'**
  String get peopleListsListDeletedSubtitle;

  /// No description provided for @peopleListsNoPeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'No people in this list'**
  String get peopleListsNoPeopleTitle;

  /// No description provided for @peopleListsNoPeopleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add some people to get started'**
  String get peopleListsNoPeopleSubtitle;

  /// No description provided for @peopleListsNoVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'No videos yet'**
  String get peopleListsNoVideosTitle;

  /// No description provided for @peopleListsNoVideosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos from list members will appear here'**
  String get peopleListsNoVideosSubtitle;

  /// No description provided for @peopleListsNoVideosAvailable.
  ///
  /// In en, this message translates to:
  /// **'No videos available'**
  String get peopleListsNoVideosAvailable;

  /// No description provided for @peopleListsFailedToLoadVideos.
  ///
  /// In en, this message translates to:
  /// **'Failed to load videos'**
  String get peopleListsFailedToLoadVideos;

  /// No description provided for @peopleListsVideoNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Video not available'**
  String get peopleListsVideoNotAvailable;

  /// No description provided for @peopleListsBackToGridTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to grid'**
  String get peopleListsBackToGridTooltip;

  /// No description provided for @peopleListsErrorLoadingVideos.
  ///
  /// In en, this message translates to:
  /// **'Error loading videos'**
  String get peopleListsErrorLoadingVideos;

  /// No description provided for @peopleListsNoPeopleToAdd.
  ///
  /// In en, this message translates to:
  /// **'No people available to add.'**
  String get peopleListsNoPeopleToAdd;

  /// No description provided for @peopleListsAddToListName.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}'**
  String peopleListsAddToListName(String name);

  /// No description provided for @peopleListsAddPeopleSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get peopleListsAddPeopleSearchHint;

  /// No description provided for @peopleListsAddPeopleError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load people. Please try again.'**
  String get peopleListsAddPeopleError;

  /// No description provided for @peopleListsAddPeopleRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get peopleListsAddPeopleRetry;

  /// No description provided for @peopleListsAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get peopleListsAddButton;

  /// No description provided for @peopleListsAddButtonWithCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String peopleListsAddButtonWithCount(int count);

  /// No description provided for @peopleListsInNLists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{In 1 list} other{In {count} lists}}'**
  String peopleListsInNLists(int count);

  /// No description provided for @peopleListsRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String peopleListsRemoveConfirmTitle(String name);

  /// No description provided for @peopleListsRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They will be removed from this list.'**
  String get peopleListsRemoveConfirmBody;

  /// No description provided for @peopleListsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get peopleListsRemove;

  /// No description provided for @peopleListsRemovedFromList.
  ///
  /// In en, this message translates to:
  /// **'Removed {name} from list'**
  String peopleListsRemovedFromList(String name);

  /// No description provided for @peopleListsUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get peopleListsUndo;

  /// No description provided for @peopleListsProfileLongPressHint.
  ///
  /// In en, this message translates to:
  /// **'Profile for {name}. Long press to remove.'**
  String peopleListsProfileLongPressHint(String name);

  /// No description provided for @peopleListsViewProfileHint.
  ///
  /// In en, this message translates to:
  /// **'View profile for {name}'**
  String peopleListsViewProfileHint(String name);

  /// No description provided for @shareMenuEditVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit Video'**
  String get shareMenuEditVideo;

  /// No description provided for @shareMenuDeleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete Video'**
  String get shareMenuDeleteVideo;

  /// No description provided for @shareMenuVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} video} other{{count} videos}}'**
  String shareMenuVideoCount(int count);

  /// No description provided for @shareMenuDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this video from Divine. It may still appear on third-party Nostr clients that use other relays.'**
  String get shareMenuDeleteConfirmation;

  /// No description provided for @shareMenuCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shareMenuCancel;

  /// No description provided for @shareMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get shareMenuDelete;

  /// No description provided for @shareMenuDeleteFailedNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'Deletion isn\'t ready yet. Try again in a moment.'**
  String get shareMenuDeleteFailedNotInitialized;

  /// No description provided for @shareMenuDeleteFailedNotOwner.
  ///
  /// In en, this message translates to:
  /// **'You can only delete your own videos.'**
  String get shareMenuDeleteFailedNotOwner;

  /// No description provided for @shareMenuDeleteFailedNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Sign in again, then try deleting.'**
  String get shareMenuDeleteFailedNotAuthenticated;

  /// No description provided for @shareMenuDeleteFailedCouldNotSign.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign the delete request. Try again.'**
  String get shareMenuDeleteFailedCouldNotSign;

  /// No description provided for @shareMenuDeleteFailedRelayRejected.
  ///
  /// In en, this message translates to:
  /// **'The relay wouldn\'t accept this delete request. Try again in a moment.'**
  String get shareMenuDeleteFailedRelayRejected;

  /// Shown when every responding relay explicitly rejects an owner's content-deletion request because the publishing account is suspended or banned.
  ///
  /// In en, this message translates to:
  /// **'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.'**
  String get shareMenuDeleteFailedAccountRestricted;

  /// No description provided for @shareMenuDeleteFailedRelayNoResponse.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the relay. Check your connection and try again.'**
  String get shareMenuDeleteFailedRelayNoResponse;

  /// No description provided for @shareMenuDeletePartiallyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Deleted. Not every relay confirmed, so it may still show up in other apps.'**
  String get shareMenuDeletePartiallyConfirmed;

  /// No description provided for @shareMenuDeleteFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete this video. Try again.'**
  String get shareMenuDeleteFailedGeneric;

  /// No description provided for @shareMenuUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get shareMenuUpdate;

  /// Label for the button that opens the cover-image editor on the video metadata edit screen.
  ///
  /// In en, this message translates to:
  /// **'Change Cover'**
  String get shareMenuChangeCover;

  /// No description provided for @shareMenuVideoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Video updated successfully'**
  String get shareMenuVideoUpdated;

  /// Snackbar shown after republishing a video when one or more DM invites to newly added collaborators failed to send. {count} is the number of failed invites (always >= 1).
  ///
  /// In en, this message translates to:
  /// **'Video updated, but {count, plural, =1{1 collaborator invite did not send.} other{{count} collaborator invites did not send.}}'**
  String shareMenuVideoUpdatedWithInviteFailures(int count);

  /// No description provided for @videoUpdateErrorNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Sign in again, then try updating.'**
  String get videoUpdateErrorNotAuthenticated;

  /// No description provided for @videoUpdateErrorNoPlayableVideo.
  ///
  /// In en, this message translates to:
  /// **'This video has no playable source, so it can\'t be updated.'**
  String get videoUpdateErrorNoPlayableVideo;

  /// No description provided for @videoUpdateErrorCouldNotSign.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign the update. Try again.'**
  String get videoUpdateErrorCouldNotSign;

  /// No description provided for @videoUpdateErrorPublishRejected.
  ///
  /// In en, this message translates to:
  /// **'The relay wouldn\'t accept the update. Try again in a moment.'**
  String get videoUpdateErrorPublishRejected;

  /// No description provided for @videoUpdateErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update this video. Try again.'**
  String get videoUpdateErrorGeneric;

  /// Snackbar shown when an edit is stopped because the original video's complete metadata could not be loaded safely.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the original video. Try again in a moment.'**
  String get shareMenuOriginalVideoUnavailable;

  /// No description provided for @shareMenuDeleteVideoQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Video?'**
  String get shareMenuDeleteVideoQuestion;

  /// No description provided for @shareMenuDeleteCleanupInProgress.
  ///
  /// In en, this message translates to:
  /// **'Removing video…'**
  String get shareMenuDeleteCleanupInProgress;

  /// No description provided for @shareMenuDeleteCleanupConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Video deleted.'**
  String get shareMenuDeleteCleanupConfirmed;

  /// No description provided for @shareMenuDeleteCleanupDelayed.
  ///
  /// In en, this message translates to:
  /// **'Video deleted. It may take a little while to disappear everywhere.'**
  String get shareMenuDeleteCleanupDelayed;

  /// No description provided for @shareMenuDeleteCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Video deleted, but we couldn\'t remove every copy. Please contact support.'**
  String get shareMenuDeleteCleanupFailed;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get authSessionExpired;

  /// Snackbar shown on the welcome screen when a saved local-key account cannot be restored on this device.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t unlock that account on this device. Sign in again.'**
  String get authAccountRestoreFailed;

  /// No description provided for @authSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign in. Please try again.'**
  String get authSignInFailed;

  /// No description provided for @webAuthNotSupportedSecureMode.
  ///
  /// In en, this message translates to:
  /// **'Web authentication not supported in secure mode. Please use mobile app for secure key management.'**
  String get webAuthNotSupportedSecureMode;

  /// No description provided for @webAuthEnterBunkerUri.
  ///
  /// In en, this message translates to:
  /// **'Please enter a bunker URI'**
  String get webAuthEnterBunkerUri;

  /// No description provided for @webAuthConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to Divine'**
  String get webAuthConnectTitle;

  /// No description provided for @webAuthChooseMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred Nostr authentication method'**
  String get webAuthChooseMethod;

  /// No description provided for @webAuthBrowserExtension.
  ///
  /// In en, this message translates to:
  /// **'Browser Extension'**
  String get webAuthBrowserExtension;

  /// No description provided for @webAuthRecommended.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED'**
  String get webAuthRecommended;

  /// No description provided for @webAuthNsecBunker.
  ///
  /// In en, this message translates to:
  /// **'nsec bunker'**
  String get webAuthNsecBunker;

  /// No description provided for @webAuthConnectRemoteSigner.
  ///
  /// In en, this message translates to:
  /// **'Connect to a remote signer'**
  String get webAuthConnectRemoteSigner;

  /// No description provided for @webAuthBunkerHint.
  ///
  /// In en, this message translates to:
  /// **'bunker://pubkey?relay=wss://...'**
  String get webAuthBunkerHint;

  /// No description provided for @webAuthPasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get webAuthPasteFromClipboard;

  /// No description provided for @webAuthConnectToBunker.
  ///
  /// In en, this message translates to:
  /// **'Connect to Bunker'**
  String get webAuthConnectToBunker;

  /// No description provided for @webAuthNewToNostr.
  ///
  /// In en, this message translates to:
  /// **'New to Nostr?'**
  String get webAuthNewToNostr;

  /// No description provided for @webAuthNostrHelp.
  ///
  /// In en, this message translates to:
  /// **'Install a browser extension like Alby or nos2x for the easiest experience, or use nsec bunker for secure remote signing.'**
  String get webAuthNostrHelp;

  /// No description provided for @soundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get soundsTitle;

  /// No description provided for @soundsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search sounds...'**
  String get soundsSearchHint;

  /// No description provided for @soundsSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get soundsSearchResults;

  /// No description provided for @soundsNoSoundsFound.
  ///
  /// In en, this message translates to:
  /// **'No sounds found'**
  String get soundsNoSoundsFound;

  /// No description provided for @soundsNoSoundsFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get soundsNoSoundsFoundDescription;

  /// No description provided for @soundsSavedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Saved to Sounds'**
  String get soundsSavedToLibrary;

  /// No description provided for @soundsAlreadySavedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Already in Sounds'**
  String get soundsAlreadySavedToLibrary;

  /// No description provided for @soundsSavedLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'My Sounds'**
  String get soundsSavedLibraryTitle;

  /// No description provided for @soundsSavedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved sounds yet'**
  String get soundsSavedEmptyTitle;

  /// No description provided for @soundsSavedEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap Use Sound on a video to save it here.'**
  String get soundsSavedEmptyDescription;

  /// No description provided for @soundsRemoveSavedSound.
  ///
  /// In en, this message translates to:
  /// **'Remove sound'**
  String get soundsRemoveSavedSound;

  /// Label of the button that commits the saved-sound label and hashtag edits and closes the sheet.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savedSoundSaveAction;

  /// Accessibility label on the saved-sound card's preview button while that sound is playing. Tapping it pauses the preview, which resumes where it left off.
  ///
  /// In en, this message translates to:
  /// **'Pause preview'**
  String get savedSoundPausePreviewAction;

  /// Accessibility label on the saved-sound card's preview button while that sound is paused mid-preview. Tapping it resumes from the current position.
  ///
  /// In en, this message translates to:
  /// **'Resume preview'**
  String get savedSoundResumePreviewAction;

  /// Title of the bottom sheet that edits a saved sound's private label and hashtags.
  ///
  /// In en, this message translates to:
  /// **'Sound details'**
  String get savedSoundDetailsSheetTitle;

  /// Title of the confirmation sheet shown before removing a sound from the device-local library.
  ///
  /// In en, this message translates to:
  /// **'Remove this sound?'**
  String get savedSoundRemoveConfirmTitle;

  /// Body of the remove-sound confirmation sheet. Reassures the user that removal is local and reversible.
  ///
  /// In en, this message translates to:
  /// **'It leaves your library, but you can save it again from any video that uses it.'**
  String get savedSoundRemoveConfirmMessage;

  /// No description provided for @soundsRemovedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Removed from Sounds'**
  String get soundsRemovedFromLibrary;

  /// Snackbar shown when saving a sound to the local library fails to persist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that sound. Try again.'**
  String get soundsSaveFailed;

  /// Snackbar shown when removing a sound from the local library fails to persist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove that sound. Try again.'**
  String get soundsRemoveFailed;

  /// Shown while a saved-sound library sync pass with other devices is in progress.
  ///
  /// In en, this message translates to:
  /// **'Syncing your sounds…'**
  String get soundSyncStatusSyncing;

  /// Shown after a saved-sound library sync pass completes successfully; the local library matches other devices.
  ///
  /// In en, this message translates to:
  /// **'Sounds up to date'**
  String get soundSyncStatusSynced;

  /// Shown when a saved-sound library sync pass fails for a transient reason (e.g. the relay is unreachable). The app will retry automatically on the next trigger.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync your sounds. We\'ll try again.'**
  String get soundSyncStatusFailed;

  /// Shown when this device cannot obtain the encryption key that protects the synced sound library (e.g. the signer refused to decrypt it, or the account has no key yet). Sync stays disabled until this resolves; it is not a network error.
  ///
  /// In en, this message translates to:
  /// **'Can\'t unlock your synced library on this device.'**
  String get soundSyncStatusLocked;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get profileMoreOptions;

  /// No description provided for @profileBlockedUser.
  ///
  /// In en, this message translates to:
  /// **'Blocked {name}'**
  String profileBlockedUser(String name);

  /// No description provided for @profileUnblockedUser.
  ///
  /// In en, this message translates to:
  /// **'Unblocked {name}'**
  String profileUnblockedUser(String name);

  /// No description provided for @profileUnfollowedUser.
  ///
  /// In en, this message translates to:
  /// **'Unfollowed {name}'**
  String profileUnfollowedUser(String name);

  /// Full-screen message shown when an author's profile feed fails to load. This state is only reached when the API could not be reached at all — an author with genuinely no videos gets the empty state instead — so the copy names the connection rather than implying the profile is empty. Wording deliberately matches authSignInErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection and try again.'**
  String get profileFeedError;

  /// Transient message shown when paginating an author's profile feed fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more videos. Pull to refresh.'**
  String get profileFeedLoadMoreError;

  /// No description provided for @notificationsTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsTabAll;

  /// No description provided for @notificationsTabLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get notificationsTabLikes;

  /// No description provided for @notificationsTabComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get notificationsTabComments;

  /// No description provided for @notificationsTabFollows.
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get notificationsTabFollows;

  /// No description provided for @notificationsTabReposts.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get notificationsTabReposts;

  /// No description provided for @notificationsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load notifications'**
  String get notificationsFailedToLoad;

  /// No description provided for @notificationsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get notificationsRetry;

  /// Inline banner above the cached notifications list when the most recent refresh failed but cached items are still rendered. Retry button next to this label reuses the existing `notificationsRetry` key.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh — showing what you have'**
  String get notificationsRefreshError;

  /// Screen-reader prefix announced before an unread notification row's content, so the user hears that the row is unread before the message itself.
  ///
  /// In en, this message translates to:
  /// **'Unread notification'**
  String get notificationsUnreadPrefix;

  /// Screen-reader announcement for the notifications badge overlay on top of nav icons. Conveys the unread count to assistive technology users.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread notification} other{{count} unread notifications}}'**
  String notificationsBadgeUnread(int count);

  /// Screen-reader label for the avatar tap target on a notification row, which opens the user's profile.
  ///
  /// In en, this message translates to:
  /// **'View {displayName} profile'**
  String notificationsViewProfileSemanticLabel(String displayName);

  /// Screen-reader label for a grouped notification's avatar stack, which opens the list of involved profiles.
  ///
  /// In en, this message translates to:
  /// **'View profiles'**
  String get notificationsViewProfilesSemanticLabel;

  /// Screen-reader label for the video thumbnail on a video-anchored notification row when the video title is known.
  ///
  /// In en, this message translates to:
  /// **'Video thumbnail for {title}'**
  String notificationsVideoThumbnailFor(String title);

  /// Screen-reader fallback label for the video thumbnail on a video-anchored notification row when the title is missing.
  ///
  /// In en, this message translates to:
  /// **'Video thumbnail'**
  String get notificationsVideoThumbnail;

  /// No description provided for @notificationsInviteSingular.
  ///
  /// In en, this message translates to:
  /// **'You have 1 invite to share with a friend!'**
  String get notificationsInviteSingular;

  /// No description provided for @notificationsInvitePlural.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have {count} invite to share with friends!} other{You have {count} invites to share with friends!}}'**
  String notificationsInvitePlural(int count);

  /// Inbox tab listing badge awards that still need an accept or reject, counting those waiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Badges} other{Badges ({count})}}'**
  String notificationsTabBadges(int count);

  /// Banner on the All inbox tab pointing at undecided badge awards.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A badge is waiting for you to accept it} other{{count} badges are waiting for you to accept them}}'**
  String notificationsPendingBadges(int count);

  /// Empty state for the Badges inbox tab.
  ///
  /// In en, this message translates to:
  /// **'No badges waiting. When someone awards you one, it lands here.'**
  String get notificationsBadgesEmpty;

  /// No description provided for @notificationsVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video unavailable'**
  String get notificationsVideoUnavailable;

  /// No description provided for @feedFailedToLoadVideos.
  ///
  /// In en, this message translates to:
  /// **'Failed to load videos'**
  String get feedFailedToLoadVideos;

  /// No description provided for @feedRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get feedRetry;

  /// No description provided for @feedNoFollowedUsers.
  ///
  /// In en, this message translates to:
  /// **'No followed users.\nFollow someone to see their videos here.'**
  String get feedNoFollowedUsers;

  /// No description provided for @feedModeForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get feedModeForYou;

  /// No description provided for @feedModeNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get feedModeNew;

  /// No description provided for @feedModeFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get feedModeFollowing;

  /// No description provided for @feedModeClassics.
  ///
  /// In en, this message translates to:
  /// **'Classics'**
  String get feedModeClassics;

  /// Semantic label for the feed mode row (current mode plus affordance hint). Screen reader only.
  ///
  /// In en, this message translates to:
  /// **'Feed mode: {label}'**
  String feedModeSemanticLabel(String label);

  /// Semantic label for the video author's display name region. Screen reader only.
  ///
  /// In en, this message translates to:
  /// **'Video author: {displayName}'**
  String videoAuthorSemanticLabel(String displayName);

  /// Semantic label for the author's circular profile avatar on feed video metadata. Screen reader only.
  ///
  /// In en, this message translates to:
  /// **'Author avatar'**
  String get videoAuthorAvatarSemanticLabel;

  /// No description provided for @feedForYouEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your For You feed is empty.\nExplore videos and follow creators to shape it.'**
  String get feedForYouEmpty;

  /// No description provided for @feedFollowingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No videos from people you follow yet.\nFind creators you like and follow them.'**
  String get feedFollowingEmpty;

  /// No description provided for @feedLatestEmpty.
  ///
  /// In en, this message translates to:
  /// **'No new videos yet.\nCheck back soon.'**
  String get feedLatestEmpty;

  /// No description provided for @feedClassicEmpty.
  ///
  /// In en, this message translates to:
  /// **'No classic Vines yet.\nCheck back soon.'**
  String get feedClassicEmpty;

  /// No description provided for @feedExploreVideos.
  ///
  /// In en, this message translates to:
  /// **'Explore Videos'**
  String get feedExploreVideos;

  /// Shown in a small pill at the bottom of the fullscreen video feed while the next page of videos is being fetched.
  ///
  /// In en, this message translates to:
  /// **'Loading more videos…'**
  String get feedLoadingMore;

  /// Screen-reader announcement after the home feed finished reloading because the user re-tapped the home tab.
  ///
  /// In en, this message translates to:
  /// **'Feed refreshed'**
  String get feedRefreshed;

  /// No description provided for @uploadUploadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Uploading video'**
  String get uploadUploadingVideo;

  /// Heading of the sheet shown right after a video finishes publishing, offering to view or share it.
  ///
  /// In en, this message translates to:
  /// **'Published to your profile'**
  String get postPublishConfirmationTitle;

  /// Button on the post-publish confirmation that opens the video the user just published.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get postPublishConfirmationView;

  /// Button on the post-publish confirmation that opens the system share sheet with a link to the video.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get postPublishConfirmationShare;

  /// Screen reader label for the preview image on the post-publish confirmation.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail of the video you just published'**
  String get postPublishConfirmationThumbnailLabel;

  /// No description provided for @userSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get userSearchNoResults;

  /// No description provided for @userPickerFilterByNameHint.
  ///
  /// In en, this message translates to:
  /// **'Filter by name...'**
  String get userPickerFilterByNameHint;

  /// No description provided for @userPickerSearchByNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get userPickerSearchByNameHint;

  /// Semantic label for the button that clears the text in the user picker search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get userPickerClearSearchSemantics;

  /// No description provided for @userPickerAlreadyAddedSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name} already added'**
  String userPickerAlreadyAddedSemantics(String name);

  /// No description provided for @userPickerSelectSemantics.
  ///
  /// In en, this message translates to:
  /// **'Select {name}'**
  String userPickerSelectSemantics(String name);

  /// Semantic label for the remove button on a selected user chip in the user picker. {name} is the user's display name.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String userPickerRemoveSelectionSemantics(String name);

  /// No description provided for @userPickerEmptyFollowListTitle.
  ///
  /// In en, this message translates to:
  /// **'Your crew is out there'**
  String get userPickerEmptyFollowListTitle;

  /// No description provided for @userPickerEmptyFollowListBody.
  ///
  /// In en, this message translates to:
  /// **'Follow people you vibe with. When they follow back, you can collab.'**
  String get userPickerEmptyFollowListBody;

  /// No description provided for @userPickerGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get userPickerGoBack;

  /// No description provided for @userPickerTypeNameToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type a name to search'**
  String get userPickerTypeNameToSearch;

  /// No description provided for @userPickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'User search is unavailable. Please try again later.'**
  String get userPickerUnavailable;

  /// No description provided for @userPickerSearchFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get userPickerSearchFailedTryAgain;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get forgotPasswordDescription;

  /// No description provided for @forgotPasswordEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get forgotPasswordEmailLabel;

  /// No description provided for @forgotPasswordCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get forgotPasswordCancel;

  /// No description provided for @forgotPasswordSendLink.
  ///
  /// In en, this message translates to:
  /// **'Email Reset Link'**
  String get forgotPasswordSendLink;

  /// No description provided for @ageVerificationContentWarning.
  ///
  /// In en, this message translates to:
  /// **'Content Warning'**
  String get ageVerificationContentWarning;

  /// No description provided for @ageVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Age Verification'**
  String get ageVerificationTitle;

  /// No description provided for @ageVerificationAdultDescription.
  ///
  /// In en, this message translates to:
  /// **'This content has been flagged as potentially containing adult material. You must be 18 or older to view it.'**
  String get ageVerificationAdultDescription;

  /// No description provided for @ageVerificationCreationDescription.
  ///
  /// In en, this message translates to:
  /// **'To use the camera and create content, you must be at least 16 years old.'**
  String get ageVerificationCreationDescription;

  /// No description provided for @ageVerificationAdultQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you 18 years of age or older?'**
  String get ageVerificationAdultQuestion;

  /// No description provided for @ageVerificationCreationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you 16 years of age or older?'**
  String get ageVerificationCreationQuestion;

  /// No description provided for @ageVerificationNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get ageVerificationNo;

  /// No description provided for @ageVerificationYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get ageVerificationYes;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get navInbox;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navMyProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get navMyProfile;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get navOpenCamera;

  /// No description provided for @navExploreClassics.
  ///
  /// In en, this message translates to:
  /// **'Classics'**
  String get navExploreClassics;

  /// No description provided for @navExploreNewVideos.
  ///
  /// In en, this message translates to:
  /// **'New Videos'**
  String get navExploreNewVideos;

  /// No description provided for @navExploreTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get navExploreTrending;

  /// No description provided for @navExploreForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get navExploreForYou;

  /// No description provided for @navExploreLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get navExploreLists;

  /// No description provided for @routeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get routeErrorTitle;

  /// No description provided for @routeInvalidHashtag.
  ///
  /// In en, this message translates to:
  /// **'Invalid hashtag'**
  String get routeInvalidHashtag;

  /// No description provided for @routeInvalidConversationId.
  ///
  /// In en, this message translates to:
  /// **'Invalid conversation ID'**
  String get routeInvalidConversationId;

  /// No description provided for @routeInvalidRequestId.
  ///
  /// In en, this message translates to:
  /// **'Invalid request ID'**
  String get routeInvalidRequestId;

  /// No description provided for @routeInvalidListId.
  ///
  /// In en, this message translates to:
  /// **'Invalid list ID'**
  String get routeInvalidListId;

  /// No description provided for @routeInvalidUserId.
  ///
  /// In en, this message translates to:
  /// **'Invalid user ID'**
  String get routeInvalidUserId;

  /// No description provided for @routeInvalidVideoId.
  ///
  /// In en, this message translates to:
  /// **'Invalid video ID'**
  String get routeInvalidVideoId;

  /// No description provided for @routeInvalidSoundId.
  ///
  /// In en, this message translates to:
  /// **'Invalid sound ID'**
  String get routeInvalidSoundId;

  /// No description provided for @routeInvalidCategory.
  ///
  /// In en, this message translates to:
  /// **'Invalid category'**
  String get routeInvalidCategory;

  /// No description provided for @routeNoVideosToDisplay.
  ///
  /// In en, this message translates to:
  /// **'No videos to display'**
  String get routeNoVideosToDisplay;

  /// Button on a full-screen route error page that navigates back to the home feed. Always shown so the user is never stranded on a dead-end error screen.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get routeGoHome;

  /// No description provided for @routeInvalidProfileId.
  ///
  /// In en, this message translates to:
  /// **'Invalid profile ID'**
  String get routeInvalidProfileId;

  /// Body text when navigation hits an unknown route (GoRouter.errorBuilder).
  ///
  /// In en, this message translates to:
  /// **'That page isn’t in the app.'**
  String get routeUnknownPath;

  /// No description provided for @routeDefaultListName.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get routeDefaultListName;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Center'**
  String get supportTitle;

  /// No description provided for @supportContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get supportContactSupport;

  /// No description provided for @supportContactSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation or view past messages'**
  String get supportContactSupportSubtitle;

  /// No description provided for @supportReportBug.
  ///
  /// In en, this message translates to:
  /// **'Report a Bug'**
  String get supportReportBug;

  /// No description provided for @supportReportBugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Technical issues with the app'**
  String get supportReportBugSubtitle;

  /// No description provided for @supportRequestFeature.
  ///
  /// In en, this message translates to:
  /// **'Request a Feature'**
  String get supportRequestFeature;

  /// No description provided for @supportRequestFeatureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest an improvement or new feature'**
  String get supportRequestFeatureSubtitle;

  /// No description provided for @supportSaveLogs.
  ///
  /// In en, this message translates to:
  /// **'Save Logs'**
  String get supportSaveLogs;

  /// No description provided for @supportSaveLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export logs to file for manual sending'**
  String get supportSaveLogsSubtitle;

  /// No description provided for @supportClearLogs.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get supportClearLogs;

  /// No description provided for @supportClearLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wipe captured logs and start fresh'**
  String get supportClearLogsSubtitle;

  /// Title of the confirmation sheet shown before clearing the in-memory log buffer.
  ///
  /// In en, this message translates to:
  /// **'Clear captured logs?'**
  String get supportClearLogsConfirmTitle;

  /// Confirm button on the clear-logs confirmation sheet, under the title 'Clear captured logs?'.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get supportClearLogsConfirmButton;

  /// Snackbar shown after the in-memory log buffer is cleared.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared'**
  String get supportLogsCleared;

  /// No description provided for @supportFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get supportFaq;

  /// No description provided for @supportFaqSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Common questions & answers'**
  String get supportFaqSubtitle;

  /// Title of the Support Center row linking to the Divine Family resource hub. Product name, left untranslated.
  ///
  /// In en, this message translates to:
  /// **'Divine Family'**
  String get supportFamily;

  /// Subtitle under the Divine Family row, describing resources that help parents and teenagers build healthy social media habits.
  ///
  /// In en, this message translates to:
  /// **'Helping parents and teens build healthy habits online'**
  String get supportFamilySubtitle;

  /// Title of the Support Center row linking to the Divine Kids policy page. Product name, left untranslated.
  ///
  /// In en, this message translates to:
  /// **'Divine Kids'**
  String get supportKids;

  /// Subtitle under the Divine Kids row, describing the policy for how accounts are handled differently depending on the account holder's age.
  ///
  /// In en, this message translates to:
  /// **'How we handle accounts by age'**
  String get supportKidsSubtitle;

  /// No description provided for @supportProofMode.
  ///
  /// In en, this message translates to:
  /// **'ProofMode'**
  String get supportProofMode;

  /// No description provided for @supportProofModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn about verification and authenticity'**
  String get supportProofModeSubtitle;

  /// No description provided for @supportLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Log in to contact support'**
  String get supportLoginRequired;

  /// No description provided for @supportExportingLogs.
  ///
  /// In en, this message translates to:
  /// **'Exporting logs...'**
  String get supportExportingLogs;

  /// No description provided for @supportExportLogsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export logs'**
  String get supportExportLogsFailed;

  /// Shown when the user exports or copies logs but the in-memory capture buffer is empty, which is what happens after a crash or force-quit. Tells them the logs do not survive a restart so they know to reproduce first.
  ///
  /// In en, this message translates to:
  /// **'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.'**
  String get supportNoLogsToExport;

  /// Shown on Android when the share sheet was presented but the platform reported no outcome, so the share may well have succeeded. Deliberately not phrased as an error.
  ///
  /// In en, this message translates to:
  /// **'Logs handed off. Check the app you shared to.'**
  String get supportExportLogsUnconfirmed;

  /// Snackbar shown after exporting logs to a file on desktop platforms. {path} is the absolute filesystem path of the saved log file.
  ///
  /// In en, this message translates to:
  /// **'Logs saved to {path}'**
  String supportLogsSavedTo(String path);

  /// SnackBar action label that opens the folder containing the just-saved log file. Desktop platforms only.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get supportRevealLogsAction;

  /// No description provided for @supportChatNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Support chat not available'**
  String get supportChatNotAvailable;

  /// No description provided for @supportCouldNotOpenMessages.
  ///
  /// In en, this message translates to:
  /// **'Could not open support messages'**
  String get supportCouldNotOpenMessages;

  /// No description provided for @supportCouldNotOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Could not open {pageName}'**
  String supportCouldNotOpenPage(String pageName);

  /// No description provided for @reportWhyReporting.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this content?'**
  String get reportWhyReporting;

  /// No description provided for @reportPolicyNotice.
  ///
  /// In en, this message translates to:
  /// **'Divine will act on content reports within 24 hours by removing the content and ejecting the user who provided the offending content.'**
  String get reportPolicyNotice;

  /// No description provided for @reportBlockUser.
  ///
  /// In en, this message translates to:
  /// **'Block this user'**
  String get reportBlockUser;

  /// No description provided for @reportCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get reportCancel;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportSubmit;

  /// No description provided for @reportSelectReason.
  ///
  /// In en, this message translates to:
  /// **'Please select a reason for reporting this content'**
  String get reportSelectReason;

  /// No description provided for @reportOtherRequiresDetails.
  ///
  /// In en, this message translates to:
  /// **'Please describe the issue when selecting Other'**
  String get reportOtherRequiresDetails;

  /// No description provided for @reportDetailsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please describe the issue'**
  String get reportDetailsRequired;

  /// Shown above the content report details field to warn that photos, screenshots, and GIFs cannot be attached.
  ///
  /// In en, this message translates to:
  /// **'Text only — photos and GIFs can’t be attached here.'**
  String get reportDetailsTextOnly;

  /// Shown in the content report details field the moment the user tries to insert a photo or GIF from the keyboard. Reports carry no attachments, so the image is intentionally dropped; this confirms it was not attached and redirects the reporter to describing the issue in words.
  ///
  /// In en, this message translates to:
  /// **'That wasn’t attached. Reports are text only, so describe it in words.'**
  String get reportDetailsImageNotAttached;

  /// Shown when a keyboard image insertion is rejected from a bug report field. Directs the reporter to the attachment area without naming its add button, which is hidden once the three-image limit is reached.
  ///
  /// In en, this message translates to:
  /// **'That image wasn’t added. You can attach up to 3 images below.'**
  String get bugReportImageInsertionRejected;

  /// Shown when a keyboard image insertion is rejected from a text-only feature request field.
  ///
  /// In en, this message translates to:
  /// **'That image wasn’t attached. Describe it in words instead.'**
  String get featureRequestImageInsertionRejected;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or Unwanted Content'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonSpamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unwanted or repetitive content'**
  String get reportReasonSpamSubtitle;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment, Bullying, or Threats'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonHarassmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Harmful and unwanted replies or mentions'**
  String get reportReasonHarassmentSubtitle;

  /// No description provided for @reportReasonViolence.
  ///
  /// In en, this message translates to:
  /// **'Violent or Extremist Content'**
  String get reportReasonViolence;

  /// No description provided for @reportReasonViolenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Violent, extremist, or harmful content'**
  String get reportReasonViolenceSubtitle;

  /// No description provided for @reportReasonSexualContent.
  ///
  /// In en, this message translates to:
  /// **'Sexual or Adult Content'**
  String get reportReasonSexualContent;

  /// No description provided for @reportReasonSexualContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Nudity, porn, or explicit content'**
  String get reportReasonSexualContentSubtitle;

  /// No description provided for @reportReasonCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright Violation'**
  String get reportReasonCopyright;

  /// No description provided for @reportReasonCopyrightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized use of intellectual property'**
  String get reportReasonCopyrightSubtitle;

  /// No description provided for @reportReasonFalseInfo.
  ///
  /// In en, this message translates to:
  /// **'False Information'**
  String get reportReasonFalseInfo;

  /// No description provided for @reportReasonFalseInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Misleading or false claims'**
  String get reportReasonFalseInfoSubtitle;

  /// No description provided for @reportReasonChildSafety.
  ///
  /// In en, this message translates to:
  /// **'Child Safety Violation'**
  String get reportReasonChildSafety;

  /// No description provided for @reportReasonChildSafetySubtitle.
  ///
  /// In en, this message translates to:
  /// **'General concerns about minors\' safety'**
  String get reportReasonChildSafetySubtitle;

  /// No description provided for @reportReasonCsam.
  ///
  /// In en, this message translates to:
  /// **'Child Sexual Abuse'**
  String get reportReasonCsam;

  /// No description provided for @reportReasonCsamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Content depicting sexual abuse of minors'**
  String get reportReasonCsamSubtitle;

  /// No description provided for @reportReasonUnderageUser.
  ///
  /// In en, this message translates to:
  /// **'User Appears Under 16'**
  String get reportReasonUnderageUser;

  /// No description provided for @reportReasonUnderageUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account holder appears to be underage'**
  String get reportReasonUnderageUserSubtitle;

  /// No description provided for @reportReasonAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI-Generated Content'**
  String get reportReasonAiGenerated;

  /// No description provided for @reportReasonAiGeneratedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Suspected AI-generated content'**
  String get reportReasonAiGeneratedSubtitle;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other Policy Violation'**
  String get reportReasonOther;

  /// No description provided for @reportReasonOtherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Violations not listed above'**
  String get reportReasonOtherSubtitle;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to report content. Please try again.'**
  String get reportFailed;

  /// Shown when a submitted report reached no channel off the device — every publish target refused it, which in practice almost always means no connectivity. Covers both content and user reports, so it must not name either subject.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your report. Check your connection and try again.'**
  String get reportNotSent;

  /// No description provided for @reportReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Received'**
  String get reportReceivedTitle;

  /// No description provided for @reportReceivedThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for helping keep Divine safe.'**
  String get reportReceivedThankYou;

  /// No description provided for @reportReceivedReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Our team will review your report and take appropriate action. You may receive updates via direct message.'**
  String get reportReceivedReviewNotice;

  /// Calm, non-blocking notice shown on the report confirmation screen when the secondary NIP-17 direct message to the moderation team failed to send. The report itself still succeeded via other channels.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the moderation team directly just now, but your report was received and will be reviewed.'**
  String get reportModerationDmDelayed;

  /// Button on the report confirmation screen that opens a direct-message conversation with the Divine moderation team so the user can follow up about their report.
  ///
  /// In en, this message translates to:
  /// **'Message the moderation team'**
  String get reportContactModeration;

  /// No description provided for @reportLearnMoreAt.
  ///
  /// In en, this message translates to:
  /// **'Learn more at'**
  String get reportLearnMoreAt;

  /// No description provided for @reportSafetyUrl.
  ///
  /// In en, this message translates to:
  /// **'divine.video/safety'**
  String get reportSafetyUrl;

  /// No description provided for @reportClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get reportClose;

  /// No description provided for @listAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get listAddToList;

  /// No description provided for @listVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} video} other{{count} videos}}'**
  String listVideoCount(int count);

  /// No description provided for @listPersonCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String listPersonCount(int count);

  /// No description provided for @listByAuthorPrefix.
  ///
  /// In en, this message translates to:
  /// **'By '**
  String get listByAuthorPrefix;

  /// No description provided for @listNewList.
  ///
  /// In en, this message translates to:
  /// **'New List'**
  String get listNewList;

  /// No description provided for @listDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get listDone;

  /// No description provided for @listErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading lists'**
  String get listErrorLoading;

  /// No description provided for @listRemovedFrom.
  ///
  /// In en, this message translates to:
  /// **'Removed from {name}'**
  String listRemovedFrom(String name);

  /// No description provided for @listAddedTo.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String listAddedTo(String name);

  /// No description provided for @listCreateNewList.
  ///
  /// In en, this message translates to:
  /// **'Create New List'**
  String get listCreateNewList;

  /// No description provided for @listNewPeopleList.
  ///
  /// In en, this message translates to:
  /// **'New people list'**
  String get listNewPeopleList;

  /// No description provided for @listCollaboratorsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get listCollaboratorsNone;

  /// No description provided for @listAddCollaboratorTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a collaborator'**
  String get listAddCollaboratorTitle;

  /// No description provided for @listCollaboratorSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Divine...'**
  String get listCollaboratorSearchHint;

  /// No description provided for @listNameLabel.
  ///
  /// In en, this message translates to:
  /// **'List Name'**
  String get listNameLabel;

  /// No description provided for @listDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get listDescriptionLabel;

  /// No description provided for @listPublicList.
  ///
  /// In en, this message translates to:
  /// **'Public List'**
  String get listPublicList;

  /// No description provided for @listPublicListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Others can follow and see this list'**
  String get listPublicListSubtitle;

  /// No description provided for @listPrivateListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos stay private. Name, description, tags, and cover stay visible.'**
  String get listPrivateListSubtitle;

  /// No description provided for @listVisibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get listVisibilityPublic;

  /// No description provided for @listVisibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get listVisibilityPrivate;

  /// No description provided for @profileListsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lists yet. Make one for the loops you want to keep together.'**
  String get profileListsEmpty;

  /// No description provided for @listEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit list'**
  String get listEditTitle;

  /// No description provided for @listEditInfoAction.
  ///
  /// In en, this message translates to:
  /// **'Edit list info'**
  String get listEditInfoAction;

  /// No description provided for @listManageVideosAction.
  ///
  /// In en, this message translates to:
  /// **'Manage videos'**
  String get listManageVideosAction;

  /// Button to follow (subscribe to) a curated video list. Not a person-follow — some locales translate the two differently.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get listFollowButton;

  /// State of the list follow button once the viewer follows the list. Tapping it unfollows.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get listFollowingButton;

  /// Manage-videos action button. Zero keeps the singular label on the disabled button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Remove video} =1{Remove video} other{Remove {count} videos}}'**
  String listRemoveVideosButton(int count);

  /// Snackbar after removing videos from a list in manage mode.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removed 1 video} other{Removed {count} videos}}'**
  String listRemoveVideosSuccess(int count);

  /// Snackbar when selected videos are still in the list after a removal batch.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Couldn\'t remove 1 video. Try again.} other{Couldn\'t remove {count} videos. Try again.}}'**
  String listRemoveVideosFailure(int count);

  /// No description provided for @listShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share list'**
  String get listShareAction;

  /// No description provided for @listShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share this list. Try again.'**
  String get listShareFailed;

  /// No description provided for @listSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get listSave;

  /// No description provided for @listContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get listContinue;

  /// Shown when a video cannot be added to a private list because its encrypted payload would exceed the NIP-44 size limit. Retrying cannot succeed, so the copy must not suggest trying again.
  ///
  /// In en, this message translates to:
  /// **'This private list is full. Remove something to add more.'**
  String get listPrivateFull;

  /// No description provided for @listUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update this list. Try again.'**
  String get listUpdateFailed;

  /// No description provided for @listMakePrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Make this list private?'**
  String get listMakePrivateTitle;

  /// No description provided for @listMakePrivateWarning.
  ///
  /// In en, this message translates to:
  /// **'Its videos get encrypted so only you can see them. The name, description, tags, and cover stay visible, and copies shared before now may persist.'**
  String get listMakePrivateWarning;

  /// No description provided for @listMakePublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Make this list public?'**
  String get listMakePublicTitle;

  /// No description provided for @listMakePublicWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can see this list and its videos.'**
  String get listMakePublicWarning;

  /// No description provided for @listShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out {name} on Divine: {url}'**
  String listShareText(String name, String url);

  /// No description provided for @listShareSubject.
  ///
  /// In en, this message translates to:
  /// **'{name} on Divine'**
  String listShareSubject(String name);

  /// No description provided for @listCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get listCancel;

  /// No description provided for @listCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get listCreate;

  /// No description provided for @listCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create list'**
  String get listCreateFailed;

  /// No description provided for @keyManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Nostr Keys'**
  String get keyManagementTitle;

  /// No description provided for @keyManagementWhatAreKeys.
  ///
  /// In en, this message translates to:
  /// **'What are Nostr keys?'**
  String get keyManagementWhatAreKeys;

  /// No description provided for @keyManagementExplanation.
  ///
  /// In en, this message translates to:
  /// **'Your Nostr identity is a cryptographic key pair:\n\n• Your public key (npub) is like your username - share it freely\n• Your private key (nsec) is like your password - keep it secret!\n\nYour nsec lets you access your account on any Nostr app.'**
  String get keyManagementExplanation;

  /// No description provided for @keyManagementImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Existing Key'**
  String get keyManagementImportTitle;

  /// No description provided for @keyManagementImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Already have a Nostr account? Paste your private key (nsec) to access it here.'**
  String get keyManagementImportSubtitle;

  /// No description provided for @keyManagementImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import Key'**
  String get keyManagementImportButton;

  /// No description provided for @keyManagementImportWarning.
  ///
  /// In en, this message translates to:
  /// **'This will replace your current key!'**
  String get keyManagementImportWarning;

  /// No description provided for @keyManagementBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Your Key'**
  String get keyManagementBackupTitle;

  /// No description provided for @keyManagementBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your private key (nsec) to use your account in other Nostr apps.'**
  String get keyManagementBackupSubtitle;

  /// No description provided for @keyManagementCopyNsec.
  ///
  /// In en, this message translates to:
  /// **'Copy My Private Key (nsec)'**
  String get keyManagementCopyNsec;

  /// No description provided for @keyManagementNeverShare.
  ///
  /// In en, this message translates to:
  /// **'Never share your nsec with anyone!'**
  String get keyManagementNeverShare;

  /// Explanation shown above the copy-private-key button for an account whose signing key is held by Divine's login service, so the key is fetched from the service rather than read off the device.
  ///
  /// In en, this message translates to:
  /// **'Your key lives on Divine\'s login service, not on this device. Confirm your password and we\'ll fetch it for you.'**
  String get keyManagementKeycastRemoteSigning;

  /// Body text of the dialog that asks for the account password before fetching the private key from Divine's login service. Confirming copies the key straight to the clipboard; it is never shown on screen.
  ///
  /// In en, this message translates to:
  /// **'Your key is kept by Divine\'s login service. Enter your account password and we\'ll fetch it.'**
  String get keyManagementKeycastPasswordPrompt;

  /// Confirm button in the password sheet. Confirming fetches the private key from Divine's login service and copies it straight to the clipboard; the key is never shown on screen.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get keyManagementKeycastCopyKey;

  /// Error shown when the private key was fetched but the device refused the clipboard write, so nothing was copied. Neither platform reports a failed clipboard write, so this is only reachable because the value is read back and compared.
  ///
  /// In en, this message translates to:
  /// **'Your device blocked the copy, so your key didn\'t reach the clipboard.'**
  String get keyManagementKeycastCopyBlocked;

  /// Inline error under the password field when the account password was rejected. The dialog stays open so the user can retry.
  ///
  /// In en, this message translates to:
  /// **'That password doesn\'t match. Try again.'**
  String get keyManagementKeycastWrongPassword;

  /// Inline error under the password field once the sheet has taken as many wrong passwords as it will accept. The user has to dismiss the sheet and reopen it to try again.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Close this and start over.'**
  String get keyManagementKeycastTooManyAttempts;

  /// Error shown when the login service is refusing further key export requests for now, so waiting is the remedy rather than retrying straight away.
  ///
  /// In en, this message translates to:
  /// **'Too many key requests. Wait a few minutes and try again.'**
  String get keyManagementKeycastRateLimited;

  /// Error shown when the saved session could not be refreshed, so fetching the key needs a fresh sign-in rather than a retry.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Sign in again to copy your key.'**
  String get keyManagementKeycastSignInAgain;

  /// Error shown when the login service refuses to release the key because the account's email address is not verified yet.
  ///
  /// In en, this message translates to:
  /// **'Verify your email address before copying your key.'**
  String get keyManagementKeycastEmailUnverified;

  /// Error shown when the login service refuses to release the key by policy, such as an account whose keys Divine manages custodially.
  ///
  /// In en, this message translates to:
  /// **'Divine looks after this account\'s keys, so they can\'t be copied here.'**
  String get keyManagementKeycastDenied;

  /// Error shown when the login service answers definitively that it holds no exportable key for this account, so retrying will not help.
  ///
  /// In en, this message translates to:
  /// **'There\'s no key on record for this account.'**
  String get keyManagementKeycastNoKey;

  /// Fallback reason inserted into keyManagementExportFailed when the login service gave no usable explanation. Lowercase because it is embedded mid-sentence.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the login service. Please try again.'**
  String get keyManagementKeycastGenericFailure;

  /// Heading shown in place of the key backup/export and key import sections for a protected-minor account whose signing key is managed by Divine (Keycast custody).
  ///
  /// In en, this message translates to:
  /// **'Your keys are managed by Divine'**
  String get keyManagementRestrictedTitle;

  /// Explanation shown to a protected-minor account for why the copy-private-key and import-key affordances are unavailable.
  ///
  /// In en, this message translates to:
  /// **'To keep your account safe, key backup and importing a different key aren\'t available here.'**
  String get keyManagementRestrictedBody;

  /// No description provided for @keyManagementPasteKey.
  ///
  /// In en, this message translates to:
  /// **'Please paste your private key'**
  String get keyManagementPasteKey;

  /// No description provided for @keyManagementInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid key format. Must start with \"nsec1\"'**
  String get keyManagementInvalidFormat;

  /// No description provided for @keyManagementConfirmImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import This Key?'**
  String get keyManagementConfirmImportTitle;

  /// No description provided for @keyManagementConfirmImportBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace your current identity with the imported one.\n\nYour current key will be lost unless you backed it up first.'**
  String get keyManagementConfirmImportBody;

  /// No description provided for @keyManagementImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get keyManagementImportConfirm;

  /// No description provided for @keyManagementImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Key imported successfully!'**
  String get keyManagementImportSuccess;

  /// No description provided for @keyManagementImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import key. Please try again.'**
  String get keyManagementImportFailed;

  /// No description provided for @keyManagementExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Private key copied to clipboard!\n\nStore it somewhere safe.'**
  String get keyManagementExportSuccess;

  /// No description provided for @keyManagementExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export key. Please try again.'**
  String get keyManagementExportFailed;

  /// Label above the truncated npub display on the key management screen.
  ///
  /// In en, this message translates to:
  /// **'Your public key (npub)'**
  String get keyManagementYourPublicKeyLabel;

  /// Tooltip / accessibility label for the copy-to-clipboard icon button next to the user's npub.
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get keyManagementCopyPublicKeyTooltip;

  /// SnackBar shown after the user taps the copy icon next to their npub.
  ///
  /// In en, this message translates to:
  /// **'Public key copied'**
  String get keyManagementPublicKeyCopied;

  /// No description provided for @saveOriginalSavedToCameraRoll.
  ///
  /// In en, this message translates to:
  /// **'Saved to Camera Roll'**
  String get saveOriginalSavedToCameraRoll;

  /// No description provided for @saveOriginalShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get saveOriginalShare;

  /// No description provided for @saveOriginalDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get saveOriginalDone;

  /// No description provided for @saveOriginalPhotosAccessNeeded.
  ///
  /// In en, this message translates to:
  /// **'Photos Access Needed'**
  String get saveOriginalPhotosAccessNeeded;

  /// No description provided for @saveOriginalPhotosAccessMessage.
  ///
  /// In en, this message translates to:
  /// **'To save videos, allow Photos access in Settings.'**
  String get saveOriginalPhotosAccessMessage;

  /// No description provided for @saveOriginalOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get saveOriginalOpenSettings;

  /// No description provided for @saveOriginalNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get saveOriginalNotNow;

  /// No description provided for @saveOriginalDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get saveOriginalDownloadFailed;

  /// No description provided for @saveOriginalDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get saveOriginalDismiss;

  /// No description provided for @saveOriginalDownloadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Downloading Video'**
  String get saveOriginalDownloadingVideo;

  /// No description provided for @saveOriginalSavingToCameraRoll.
  ///
  /// In en, this message translates to:
  /// **'Saving to Camera Roll'**
  String get saveOriginalSavingToCameraRoll;

  /// No description provided for @saveOriginalFetchingVideo.
  ///
  /// In en, this message translates to:
  /// **'Fetching the video from the network...'**
  String get saveOriginalFetchingVideo;

  /// No description provided for @saveOriginalSavingVideo.
  ///
  /// In en, this message translates to:
  /// **'Saving the original video to your camera roll...'**
  String get saveOriginalSavingVideo;

  /// No description provided for @soundTitle.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get soundTitle;

  /// No description provided for @soundOriginalSound.
  ///
  /// In en, this message translates to:
  /// **'Original sound'**
  String get soundOriginalSound;

  /// No description provided for @soundVideosUsingThisSound.
  ///
  /// In en, this message translates to:
  /// **'Videos using this sound'**
  String get soundVideosUsingThisSound;

  /// No description provided for @soundSourceVideo.
  ///
  /// In en, this message translates to:
  /// **'Source video'**
  String get soundSourceVideo;

  /// No description provided for @soundNoVideosYet.
  ///
  /// In en, this message translates to:
  /// **'No videos yet'**
  String get soundNoVideosYet;

  /// No description provided for @soundBeFirstToUse.
  ///
  /// In en, this message translates to:
  /// **'Be the first to use this sound!'**
  String get soundBeFirstToUse;

  /// No description provided for @soundFailedToLoadVideos.
  ///
  /// In en, this message translates to:
  /// **'Failed to load videos'**
  String get soundFailedToLoadVideos;

  /// No description provided for @soundRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get soundRetry;

  /// No description provided for @soundVideosUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Videos unavailable'**
  String get soundVideosUnavailable;

  /// No description provided for @soundCouldNotLoadDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not load video details'**
  String get soundCouldNotLoadDetails;

  /// No description provided for @soundPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get soundPreview;

  /// No description provided for @soundStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get soundStop;

  /// No description provided for @soundUseSound.
  ///
  /// In en, this message translates to:
  /// **'Use Sound'**
  String get soundUseSound;

  /// No description provided for @soundUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled sound'**
  String get soundUntitled;

  /// No description provided for @soundStopPreview.
  ///
  /// In en, this message translates to:
  /// **'Stop preview'**
  String get soundStopPreview;

  /// No description provided for @soundPreviewSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview {title}'**
  String soundPreviewSemanticLabel(String title);

  /// No description provided for @soundViewDetailsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'View details for {title}'**
  String soundViewDetailsSemanticLabel(String title);

  /// No description provided for @soundNoVideoCount.
  ///
  /// In en, this message translates to:
  /// **'No videos yet'**
  String get soundNoVideoCount;

  /// No description provided for @soundOneVideo.
  ///
  /// In en, this message translates to:
  /// **'1 video'**
  String get soundOneVideo;

  /// No description provided for @soundVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} video} other{{count} videos}}'**
  String soundVideoCount(int count);

  /// No description provided for @soundUnableToPreview.
  ///
  /// In en, this message translates to:
  /// **'Unable to preview sound - no audio available'**
  String get soundUnableToPreview;

  /// No description provided for @soundPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to play preview. Please try again.'**
  String get soundPreviewFailed;

  /// No description provided for @soundViewSource.
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get soundViewSource;

  /// No description provided for @soundCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get soundCloseTooltip;

  /// No description provided for @exploreNotExploreRoute.
  ///
  /// In en, this message translates to:
  /// **'Not an explore route'**
  String get exploreNotExploreRoute;

  /// No description provided for @legalTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legalTitle;

  /// No description provided for @legalTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalTermsOfService;

  /// No description provided for @legalTermsOfServiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Usage terms and conditions'**
  String get legalTermsOfServiceSubtitle;

  /// No description provided for @legalPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyPolicy;

  /// No description provided for @legalPrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How we handle your data'**
  String get legalPrivacyPolicySubtitle;

  /// No description provided for @legalSafetyStandards.
  ///
  /// In en, this message translates to:
  /// **'Safety Standards'**
  String get legalSafetyStandards;

  /// No description provided for @legalSafetyStandardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Community guidelines and safety'**
  String get legalSafetyStandardsSubtitle;

  /// No description provided for @legalDmca.
  ///
  /// In en, this message translates to:
  /// **'DMCA'**
  String get legalDmca;

  /// No description provided for @legalDmcaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copyright and takedown policy'**
  String get legalDmcaSubtitle;

  /// No description provided for @legalOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get legalOpenSourceLicenses;

  /// No description provided for @legalOpenSourceLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Third-party package attributions'**
  String get legalOpenSourceLicensesSubtitle;

  /// No description provided for @legalAppName.
  ///
  /// In en, this message translates to:
  /// **'Divine'**
  String get legalAppName;

  /// No description provided for @legalCouldNotOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Could not open {pageName}'**
  String legalCouldNotOpenPage(String pageName);

  /// No description provided for @categoryAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get categoryAction;

  /// No description provided for @categoryAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get categoryAdventure;

  /// No description provided for @categoryAnimals.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get categoryAnimals;

  /// No description provided for @categoryAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get categoryAnimation;

  /// No description provided for @categoryArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get categoryArchitecture;

  /// No description provided for @categoryArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get categoryArt;

  /// No description provided for @categoryAutomotive.
  ///
  /// In en, this message translates to:
  /// **'Automotive'**
  String get categoryAutomotive;

  /// No description provided for @categoryAwardShow.
  ///
  /// In en, this message translates to:
  /// **'Award Show'**
  String get categoryAwardShow;

  /// No description provided for @categoryAwards.
  ///
  /// In en, this message translates to:
  /// **'Awards'**
  String get categoryAwards;

  /// No description provided for @categoryBaseball.
  ///
  /// In en, this message translates to:
  /// **'Baseball'**
  String get categoryBaseball;

  /// No description provided for @categoryBasketball.
  ///
  /// In en, this message translates to:
  /// **'Basketball'**
  String get categoryBasketball;

  /// No description provided for @categoryBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryBeauty;

  /// No description provided for @categoryBeverage.
  ///
  /// In en, this message translates to:
  /// **'Beverage'**
  String get categoryBeverage;

  /// No description provided for @categoryCars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get categoryCars;

  /// No description provided for @categoryCelebration.
  ///
  /// In en, this message translates to:
  /// **'Celebration'**
  String get categoryCelebration;

  /// No description provided for @categoryCelebrities.
  ///
  /// In en, this message translates to:
  /// **'Celebrities'**
  String get categoryCelebrities;

  /// No description provided for @categoryCelebrity.
  ///
  /// In en, this message translates to:
  /// **'Celebrity'**
  String get categoryCelebrity;

  /// No description provided for @categoryCityscape.
  ///
  /// In en, this message translates to:
  /// **'Cityscape'**
  String get categoryCityscape;

  /// No description provided for @categoryComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get categoryComedy;

  /// No description provided for @categoryConcert.
  ///
  /// In en, this message translates to:
  /// **'Concert'**
  String get categoryConcert;

  /// No description provided for @categoryCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get categoryCooking;

  /// No description provided for @categoryCostume.
  ///
  /// In en, this message translates to:
  /// **'Costume'**
  String get categoryCostume;

  /// No description provided for @categoryCrafts.
  ///
  /// In en, this message translates to:
  /// **'Crafts'**
  String get categoryCrafts;

  /// No description provided for @categoryCrime.
  ///
  /// In en, this message translates to:
  /// **'Crime'**
  String get categoryCrime;

  /// No description provided for @categoryCulture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get categoryCulture;

  /// No description provided for @categoryDance.
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get categoryDance;

  /// No description provided for @categoryDiy.
  ///
  /// In en, this message translates to:
  /// **'DIY'**
  String get categoryDiy;

  /// No description provided for @categoryDrama.
  ///
  /// In en, this message translates to:
  /// **'Drama'**
  String get categoryDrama;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categoryEmotional.
  ///
  /// In en, this message translates to:
  /// **'Emotional'**
  String get categoryEmotional;

  /// No description provided for @categoryEmotions.
  ///
  /// In en, this message translates to:
  /// **'Emotions'**
  String get categoryEmotions;

  /// No description provided for @categoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// No description provided for @categoryEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get categoryEvent;

  /// No description provided for @categoryFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get categoryFamily;

  /// No description provided for @categoryFans.
  ///
  /// In en, this message translates to:
  /// **'Fans'**
  String get categoryFans;

  /// No description provided for @categoryFantasy.
  ///
  /// In en, this message translates to:
  /// **'Fantasy'**
  String get categoryFantasy;

  /// No description provided for @categoryFashion.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get categoryFashion;

  /// No description provided for @categoryFestival.
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get categoryFestival;

  /// No description provided for @categoryFilm.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get categoryFilm;

  /// No description provided for @categoryFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get categoryFitness;

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryFootball.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get categoryFootball;

  /// No description provided for @categoryFurniture.
  ///
  /// In en, this message translates to:
  /// **'Furniture'**
  String get categoryFurniture;

  /// No description provided for @categoryGaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get categoryGaming;

  /// No description provided for @categoryGolf.
  ///
  /// In en, this message translates to:
  /// **'Golf'**
  String get categoryGolf;

  /// No description provided for @categoryGrooming.
  ///
  /// In en, this message translates to:
  /// **'Grooming'**
  String get categoryGrooming;

  /// No description provided for @categoryGuitar.
  ///
  /// In en, this message translates to:
  /// **'Guitar'**
  String get categoryGuitar;

  /// No description provided for @categoryHalloween.
  ///
  /// In en, this message translates to:
  /// **'Halloween'**
  String get categoryHalloween;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryHockey.
  ///
  /// In en, this message translates to:
  /// **'Hockey'**
  String get categoryHockey;

  /// No description provided for @categoryHoliday.
  ///
  /// In en, this message translates to:
  /// **'Holiday'**
  String get categoryHoliday;

  /// No description provided for @categoryHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get categoryHome;

  /// No description provided for @categoryHomeImprovement.
  ///
  /// In en, this message translates to:
  /// **'Home Improvement'**
  String get categoryHomeImprovement;

  /// No description provided for @categoryHorror.
  ///
  /// In en, this message translates to:
  /// **'Horror'**
  String get categoryHorror;

  /// No description provided for @categoryHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get categoryHospital;

  /// No description provided for @categoryHumor.
  ///
  /// In en, this message translates to:
  /// **'Humor'**
  String get categoryHumor;

  /// No description provided for @categoryInteriorDesign.
  ///
  /// In en, this message translates to:
  /// **'Interior Design'**
  String get categoryInteriorDesign;

  /// No description provided for @categoryInterview.
  ///
  /// In en, this message translates to:
  /// **'Interview'**
  String get categoryInterview;

  /// No description provided for @categoryKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get categoryKids;

  /// No description provided for @categoryLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get categoryLifestyle;

  /// No description provided for @categoryMagic.
  ///
  /// In en, this message translates to:
  /// **'Magic'**
  String get categoryMagic;

  /// No description provided for @categoryMakeup.
  ///
  /// In en, this message translates to:
  /// **'Makeup'**
  String get categoryMakeup;

  /// No description provided for @categoryMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get categoryMedical;

  /// No description provided for @categoryMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get categoryMusic;

  /// No description provided for @categoryMystery.
  ///
  /// In en, this message translates to:
  /// **'Mystery'**
  String get categoryMystery;

  /// No description provided for @categoryNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get categoryNature;

  /// No description provided for @categoryNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get categoryNews;

  /// No description provided for @categoryOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get categoryOutdoor;

  /// No description provided for @categoryParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get categoryParty;

  /// No description provided for @categoryPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get categoryPeople;

  /// No description provided for @categoryPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get categoryPerformance;

  /// No description provided for @categoryPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get categoryPets;

  /// No description provided for @categoryPolitics.
  ///
  /// In en, this message translates to:
  /// **'Politics'**
  String get categoryPolitics;

  /// No description provided for @categoryPrank.
  ///
  /// In en, this message translates to:
  /// **'Prank'**
  String get categoryPrank;

  /// No description provided for @categoryPranks.
  ///
  /// In en, this message translates to:
  /// **'Pranks'**
  String get categoryPranks;

  /// No description provided for @categoryRealityShow.
  ///
  /// In en, this message translates to:
  /// **'Reality Show'**
  String get categoryRealityShow;

  /// No description provided for @categoryRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get categoryRelationship;

  /// No description provided for @categoryRelationships.
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get categoryRelationships;

  /// No description provided for @categoryRomance.
  ///
  /// In en, this message translates to:
  /// **'Romance'**
  String get categoryRomance;

  /// No description provided for @categorySchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get categorySchool;

  /// No description provided for @categoryScienceFiction.
  ///
  /// In en, this message translates to:
  /// **'Science Fiction'**
  String get categoryScienceFiction;

  /// No description provided for @categorySelfie.
  ///
  /// In en, this message translates to:
  /// **'Selfie'**
  String get categorySelfie;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categorySkateboarding.
  ///
  /// In en, this message translates to:
  /// **'Skateboarding'**
  String get categorySkateboarding;

  /// No description provided for @categorySkincare.
  ///
  /// In en, this message translates to:
  /// **'Skincare'**
  String get categorySkincare;

  /// No description provided for @categorySoccer.
  ///
  /// In en, this message translates to:
  /// **'Soccer'**
  String get categorySoccer;

  /// No description provided for @categorySocialGathering.
  ///
  /// In en, this message translates to:
  /// **'Social Gathering'**
  String get categorySocialGathering;

  /// No description provided for @categorySocialMedia.
  ///
  /// In en, this message translates to:
  /// **'Social Media'**
  String get categorySocialMedia;

  /// No description provided for @categorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get categorySports;

  /// No description provided for @categoryTalkShow.
  ///
  /// In en, this message translates to:
  /// **'Talk Show'**
  String get categoryTalkShow;

  /// No description provided for @categoryTech.
  ///
  /// In en, this message translates to:
  /// **'Tech'**
  String get categoryTech;

  /// No description provided for @categoryTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get categoryTechnology;

  /// No description provided for @categoryTelevision.
  ///
  /// In en, this message translates to:
  /// **'Television'**
  String get categoryTelevision;

  /// No description provided for @categoryToys.
  ///
  /// In en, this message translates to:
  /// **'Toys'**
  String get categoryToys;

  /// No description provided for @categoryTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get categoryTransportation;

  /// No description provided for @categoryTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTravel;

  /// No description provided for @categoryUrban.
  ///
  /// In en, this message translates to:
  /// **'Urban'**
  String get categoryUrban;

  /// No description provided for @categoryViolence.
  ///
  /// In en, this message translates to:
  /// **'Violence'**
  String get categoryViolence;

  /// No description provided for @categoryVlog.
  ///
  /// In en, this message translates to:
  /// **'Vlog'**
  String get categoryVlog;

  /// No description provided for @categoryVlogging.
  ///
  /// In en, this message translates to:
  /// **'Vlogging'**
  String get categoryVlogging;

  /// No description provided for @categoryWrestling.
  ///
  /// In en, this message translates to:
  /// **'Wrestling'**
  String get categoryWrestling;

  /// Snackbar shown after a profile picture upload succeeds on the profile edit screen. The new picture is staged in the form but not yet published; the user must tap Save for it to take effect.
  ///
  /// In en, this message translates to:
  /// **'Uploaded — tap Save to apply'**
  String get profileSetupUploadStaged;

  /// No description provided for @inboxReportedUser.
  ///
  /// In en, this message translates to:
  /// **'Reported {displayName}'**
  String inboxReportedUser(String displayName);

  /// No description provided for @inboxBlockedUser.
  ///
  /// In en, this message translates to:
  /// **'Blocked {displayName}'**
  String inboxBlockedUser(String displayName);

  /// No description provided for @inboxUnblockedUser.
  ///
  /// In en, this message translates to:
  /// **'Unblocked {displayName}'**
  String inboxUnblockedUser(String displayName);

  /// No description provided for @inboxRemovedConversation.
  ///
  /// In en, this message translates to:
  /// **'Removed conversation'**
  String get inboxRemovedConversation;

  /// Title of the inbox banner shown when the one-time DM history recovery stopped before finishing, so conversations that would appear as message requests are still hidden. Paired with a Retry action.
  ///
  /// In en, this message translates to:
  /// **'Some chats haven\'t finished restoring'**
  String get inboxRestorePausedTitle;

  /// Short note shown in a single empty DM conversation when history recovery has run but stopped before finishing, so this chat may still receive restored messages.
  ///
  /// In en, this message translates to:
  /// **'This chat hasn\'t finished restoring'**
  String get conversationRestorePausedTitle;

  /// Label of the action on the inbox restore-paused banner that re-runs the DM history recovery.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get inboxRestoreRetryAction;

  /// Accessibility label on the progress bar shown at the top of the Messages list while a one-time DM history recovery (after reinstall) is still running, so the user knows older chats are still being restored.
  ///
  /// In en, this message translates to:
  /// **'Restoring your messages…'**
  String get inboxRestoringMessages;

  /// No description provided for @inboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get inboxEmptyTitle;

  /// No description provided for @inboxEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'That + button won\'t bite.'**
  String get inboxEmptySubtitle;

  /// No description provided for @inboxLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages didn\'t load'**
  String get inboxLoadErrorTitle;

  /// No description provided for @inboxLoadErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and give it another go.'**
  String get inboxLoadErrorSubtitle;

  /// Filter chip label showing all conversations in the Messages inbox.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get inboxFilterAll;

  /// Filter chip label showing only unread conversations in the Messages inbox.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get inboxFilterUnread;

  /// Title of the notice that replaces the message composer in a conversation with an account the viewer has blocked.
  ///
  /// In en, this message translates to:
  /// **'You blocked this account'**
  String get dmBlockedThreadTitle;

  /// Body of the notice replacing the composer in a blocked conversation. Explains that history is preserved and names unblocking as the way to reply again.
  ///
  /// In en, this message translates to:
  /// **'Messages stay here so you can read or screenshot them. Unblock to reply.'**
  String get dmBlockedThreadBody;

  /// Filter chip label showing conversations with accounts the viewer has blocked. Only rendered once the viewer has blocked someone.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get inboxFilterBlocked;

  /// Shown in place of the conversation list when the Blocked filter is on and a search query matches none of the blocked chats.
  ///
  /// In en, this message translates to:
  /// **'No blocked chats'**
  String get inboxBlockedEmptyTitle;

  /// Subtitle under inboxBlockedEmptyTitle explaining what the Blocked filter collects.
  ///
  /// In en, this message translates to:
  /// **'Accounts you block show up here.'**
  String get inboxBlockedEmptySubtitle;

  /// Preview text on a Blocked row for an account the viewer blocked but never exchanged messages with. The row is not tappable.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get inboxBlockedNoMessages;

  /// Shown in place of the conversation list when the Unread filter is on and every conversation has been read.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get inboxUnreadEmptyTitle;

  /// No description provided for @inboxUnreadEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No unread messages right now.'**
  String get inboxUnreadEmptySubtitle;

  /// Hint text in the inbox Messages search field.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get inboxSearchHint;

  /// Title of the pinned Divine Moderation support row at the top of the Messages inbox. A brand account name, so it is intentionally identical in every locale.
  ///
  /// In en, this message translates to:
  /// **'Divine Moderation'**
  String get inboxSupportRowTitle;

  /// One-line summary under the pinned Divine Moderation support row, describing what the moderation team can help with.
  ///
  /// In en, this message translates to:
  /// **'Bugs, moderation, account stuff — we\'re listening.'**
  String get inboxSupportRowSubtitle;

  /// Shown in place of the conversation list when an inbox search matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get inboxSearchEmptyTitle;

  /// No description provided for @inboxSearchEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different name or word.'**
  String get inboxSearchEmptySubtitle;

  /// No description provided for @inboxActionMute.
  ///
  /// In en, this message translates to:
  /// **'Mute conversation'**
  String get inboxActionMute;

  /// No description provided for @inboxActionReport.
  ///
  /// In en, this message translates to:
  /// **'Report {displayName}'**
  String inboxActionReport(String displayName);

  /// No description provided for @inboxActionBlock.
  ///
  /// In en, this message translates to:
  /// **'Block {displayName}'**
  String inboxActionBlock(String displayName);

  /// No description provided for @inboxActionUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock {displayName}'**
  String inboxActionUnblock(String displayName);

  /// No description provided for @inboxActionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove conversation'**
  String get inboxActionRemove;

  /// No description provided for @inboxRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove conversation?'**
  String get inboxRemoveConfirmTitle;

  /// No description provided for @inboxRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes your conversation with {displayName} from your inbox. If they message you again, a new conversation starts.'**
  String inboxRemoveConfirmBody(String displayName);

  /// Body of the remove-conversation confirmation for a GROUP thread. Names nobody, because a group has no single counterparty — the 1:1 wording `inboxRemoveConfirmBody` says 'your conversation with {displayName}', which would read as a conversation with the room's title. Mirrors `inboxRemoveConfirmBodyVanishedAccount`, which is name-free for the same reason.
  ///
  /// In en, this message translates to:
  /// **'This removes the group conversation from your inbox. If anyone messages the group again, a new conversation starts.'**
  String get inboxRemoveConfirmBodyGroup;

  /// No description provided for @inboxRemoveConfirmConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get inboxRemoveConfirmConfirm;

  /// No description provided for @inboxConversationMuted.
  ///
  /// In en, this message translates to:
  /// **'Conversation muted'**
  String get inboxConversationMuted;

  /// No description provided for @inboxConversationUnmuted.
  ///
  /// In en, this message translates to:
  /// **'Conversation unmuted'**
  String get inboxConversationUnmuted;

  /// Header label on a collaborator invite card in the DM conversation.
  ///
  /// In en, this message translates to:
  /// **'Collaborator invite'**
  String get inboxCollabInviteCardTitle;

  /// Fallback shown as the collaborator invite card title when the invited video has no title. Avoids exposing the raw d-tag identifier.
  ///
  /// In en, this message translates to:
  /// **'Untitled video'**
  String get inboxCollabInviteCardUntitledVideo;

  /// Tappable label rendered in rich text in place of a Nostr video/event reference. Opens the linked video.
  ///
  /// In en, this message translates to:
  /// **'View video'**
  String get clickableTextViewVideoLink;

  /// Confirmation dialog title shown before opening an untrusted external URL from a DM.
  ///
  /// In en, this message translates to:
  /// **'Open external link?'**
  String get messageExternalLinkDialogTitle;

  /// Confirmation dialog body shown before opening an untrusted external URL from a DM.
  ///
  /// In en, this message translates to:
  /// **'This link goes to an external site and may not be safe:\n\n{url}'**
  String messageExternalLinkDialogBody(String url);

  /// Confirmation button that opens an untrusted external URL from a DM.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get messageExternalLinkDialogOpen;

  /// Primary action on a collaborator invite card. Accepts the invite and co-posts the video to the recipient's timeline as a collaboration.
  ///
  /// In en, this message translates to:
  /// **'Co-post'**
  String get inboxCollabInviteCoPostButton;

  /// Secondary action on a collaborator invite card. Ignores the invite because the recipient does not claim the video as their collaboration.
  ///
  /// In en, this message translates to:
  /// **'Not mine'**
  String get inboxCollabInviteNotMineButton;

  /// Header label shown over the video preview on a collaborator invite card.
  ///
  /// In en, this message translates to:
  /// **'Co-post invite'**
  String get inboxCollabInvitePreviewTitle;

  /// Header label shown over the video preview on a collaborator invite card when the inviter's display name is known.
  ///
  /// In en, this message translates to:
  /// **'Co-post invite from {displayName}'**
  String inboxCollabInvitePreviewTitleFrom(String displayName);

  /// Explains what accepting a collaborator invite does.
  ///
  /// In en, this message translates to:
  /// **'Co-posting adds this video to your timeline as a collaboration.'**
  String get inboxCollabInviteTimelineConsequence;

  /// No description provided for @inboxCollabInviteAcceptedStatus.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get inboxCollabInviteAcceptedStatus;

  /// No description provided for @inboxCollabInviteIgnoredStatus.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get inboxCollabInviteIgnoredStatus;

  /// No description provided for @inboxCollabInviteAcceptError.
  ///
  /// In en, this message translates to:
  /// **'Could not accept. Try again.'**
  String get inboxCollabInviteAcceptError;

  /// Shown on the inviter's own outgoing collaborator invite card in their DM with the collaborator. Replaces Accept/Ignore which are recipient-only actions.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent'**
  String get inboxCollabInviteSentStatus;

  /// Substituted for the legacy NIP-04 plaintext invite copy when shown as the most-recent-message preview in the DM conversation list. The plaintext copy ('Open Divine to review and accept') is misleading inside Divine.
  ///
  /// In en, this message translates to:
  /// **'Collaborator invite'**
  String get inboxConversationCollabInvitePreview;

  /// Plaintext body of the encrypted DM that invites someone to collaborate on a video. Includes a clickable web link so non-Divine Nostr clients can preview the video. The trailing 'Open Divine to review and accept.' sentence MUST stay verbatim — Divine uses it as a marker to suppress legacy plaintext invites in conversation views.
  ///
  /// In en, this message translates to:
  /// **'You were invited to collaborate on {title}: {url}\n\nOpen Divine to review and accept.'**
  String collaboratorInviteDmBody(String title, String url);

  /// Plaintext body of the encrypted DM that invites someone to collaborate on a video where the video has no title. Includes a clickable web link so non-Divine Nostr clients can preview the video. The trailing 'Open Divine to review and accept.' sentence MUST stay verbatim — Divine uses it as a marker to suppress legacy plaintext invites in conversation views.
  ///
  /// In en, this message translates to:
  /// **'You were invited to collaborate on a video: {url}\n\nOpen Divine to review and accept.'**
  String collaboratorInviteDmBodyUntitled(String url);

  /// No description provided for @videoPublishCollaboratorInviteWarning.
  ///
  /// In en, this message translates to:
  /// **'Video posted, but {count, plural, =1{1 collaborator invite did not send.} other{{count} collaborator invites did not send.}}'**
  String videoPublishCollaboratorInviteWarning(int count);

  /// SnackBar text shown when a send is dispatched with no recipient (#7335). Unlike every other send failure there is no queue row and so no red "Not delivered" bubble to carry the news, which is why this one outcome gets a toast. Reachable only by opening the conversation route without participants, e.g. a hand-crafted deep link.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t tell who this thread is with. Open it again from your inbox.'**
  String get dmSendNoRecipientMessage;

  /// SnackBar text shown when a protected minor (13-15) tries to DM a non-approved account (#176). Neutral, no retry action.
  ///
  /// In en, this message translates to:
  /// **'You can only message official Divine accounts'**
  String get dmSendBlockedMessage;

  /// SnackBar text shown when a send is refused because the recipient is a moderation account Divine has rotated away from (#6416). Used instead of `dmSendBlockedMessage`, whose copy is wrong here: a retired moderation key IS an official Divine account, it is just one nobody reads any more. Reached only by deep link, queue drain, or share-to-DM — the conversation itself shows `dmRetiredThreadClosedTitle` in place of the composer.
  ///
  /// In en, this message translates to:
  /// **'Nobody is reading this conversation. Message Divine Moderation instead.'**
  String get dmSendBlockedRetiredMessage;

  /// Names an own message whose delete-for-everyone is still in flight. Used twice: as the screen-reader label on the bubble's spinner, and as the visible title of the sheet that offers to try again. Keep it short enough to read as a sheet title.
  ///
  /// In en, this message translates to:
  /// **'Deleting for everyone'**
  String get dmDeletePendingLabel;

  /// Temporary SnackBar text and failed-retraction sheet title shown when Delete for everyone was not confirmed for every recipient (#8201).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete for everyone.'**
  String get dmDeleteRefusedMessage;

  /// Explanation in the action sheet opened from the warning icon beside an own message whose deletion was not confirmed for everyone.
  ///
  /// In en, this message translates to:
  /// **'Some people may still be able to see this message.'**
  String get dmDeleteRefusedDetails;

  /// Heading of the notice that replaces the message composer in a DM thread keyed on a retired Divine Moderation account (#6416).
  ///
  /// In en, this message translates to:
  /// **'This conversation is closed.'**
  String get dmRetiredThreadClosedTitle;

  /// SnackBar shown when a user tries to remove a conversation that resolves to a protected Divine Moderation notice. Used on the request-preview decline, the Message Requests bulk sweep, and the inbox long-press remove (#6971, #8347, #8391).
  ///
  /// In en, this message translates to:
  /// **'This Divine Moderation notice can\'t be removed.'**
  String get messageRequestModerationNoticeCannotBeRemoved;

  /// Body of the closed-thread notice in a retired Divine Moderation DM thread (#6416), below `dmRetiredThreadClosedTitle`. Deliberately promises no reply: the current support inbox is ingested but only lightly staffed, so copy implying someone is waiting would overstate it. 'Divine Moderation' is the account name — keep it as shown in `inboxSupportRowTitle` for this locale.
  ///
  /// In en, this message translates to:
  /// **'We moved Divine Moderation to a new account. Nobody reads this one anymore.'**
  String get dmRetiredThreadClosedBody;

  /// Action on the closed-thread notice (#6416) that opens the current pinned Divine Moderation conversation. A redirect, not a promise of a response. 'Divine Moderation' is the account name — keep it as shown in `inboxSupportRowTitle` for this locale.
  ///
  /// In en, this message translates to:
  /// **'Message Divine Moderation'**
  String get dmRetiredThreadOpenSupport;

  /// Shown when a DM is refused because the encrypted rumor would exceed the NIP-44 size limit. The message stays in the composer, so the copy asks the user to shorten it rather than warning that it was lost.
  ///
  /// In en, this message translates to:
  /// **'That message is too long to send. Shorten it and try again.'**
  String get dmSendTooLongMessage;

  /// Accessibility announcement text, and the recovery bottom sheet's title, shown in a DM conversation when a send fails (relay error, signer error, network error). The bottom sheet pairs it with `dmSendFailedSubtitle` and the `dmMessageActionRetrySend` / `dmMessageActionCancelSend` actions.
  ///
  /// In en, this message translates to:
  /// **'Message couldn\'t be sent'**
  String get dmSendFailedMessage;

  /// SnackBar text shown in a DM conversation when the user taps Resend on a failed message and the retry fails again. Distinct from `dmSendFailedMessage`, which titles the recovery sheet and announces a FIRST send failure: on a resend the bubble is already red, so the red bubble cannot signal the new attempt and a toast is the only feedback the user gets.
  ///
  /// In en, this message translates to:
  /// **'Still couldn\'t send'**
  String get dmResendFailedMessage;

  /// Subtitle in the recovery bottom sheet shown when a failed own DM bubble is tapped, below the `dmSendFailedMessage` title.
  ///
  /// In en, this message translates to:
  /// **'Resend it now, or stop trying.'**
  String get dmSendFailedSubtitle;

  /// SnackBarAction button label that retries the failed DM send. Keep short — fits next to the SnackBar message.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dmSendFailedRetry;

  /// SnackBar text shown in a DM conversation after a send where the recipient received the message but the sender's self-addressed gift wrap failed to publish. The sender's other devices won't see this message on relay-only restore. Paired with the retry action `dmSendFailedRetry`.
  ///
  /// In en, this message translates to:
  /// **'Sent, but didn\'t sync to your other devices'**
  String get dmSendPartialMessage;

  /// Error text shown in place of the message list when DmRepository.watchMessages emits an error (e.g. local DB read failure). Distinct from send failures (which use `dmSendFailedMessage`).
  ///
  /// In en, this message translates to:
  /// **'Could not load messages'**
  String get dmConversationLoadError;

  /// Placeholder text shown inside the compose field at the bottom of a DM conversation when the user hasn't typed anything yet.
  ///
  /// In en, this message translates to:
  /// **'Say something…'**
  String get dmMessageInputHint;

  /// Accessibility hint announcing that a direct message bubble was sent by the current user
  ///
  /// In en, this message translates to:
  /// **'Sent message'**
  String get dmMessageBubbleSentHint;

  /// Accessibility hint announcing that a direct message bubble was received from another user
  ///
  /// In en, this message translates to:
  /// **'Received message'**
  String get dmMessageBubbleReceivedHint;

  /// Accessibility hint announcing that a direct message bubble supports a long-press action menu
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get dmMessageBubbleLongPressHint;

  /// Accessibility tap hint on a failed own message bubble: tapping opens the resend-or-delete actions
  ///
  /// In en, this message translates to:
  /// **'Resend or delete this message'**
  String get dmMessageBubbleFailedTapHint;

  /// Long-press menu action on a DM bubble that copies the message's plaintext content to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get dmMessageActionCopyText;

  /// Long-press menu action on a shared-video DM bubble that copies the underlying divine.video URL (without the surrounding personal-note text) to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy video URL'**
  String get dmMessageActionCopyVideoUrl;

  /// Long-press menu action on a sent DM bubble that publishes a NIP-09 kind 5 deletion event so the message disappears for both participants.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get dmMessageActionDeleteForEveryone;

  /// Long-press menu action on a received DM bubble that opens the report flow for that specific message.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get dmMessageActionReport;

  /// Primary action in the recovery bottom sheet shown when a failed own DM bubble is tapped; re-attempts delivery of that queued message.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get dmMessageActionRetrySend;

  /// Secondary action in the recovery bottom sheet shown when a failed own DM bubble is tapped; gives up on the queued message and removes it.
  ///
  /// In en, this message translates to:
  /// **'Stop trying'**
  String get dmMessageActionCancelSend;

  /// Screen-reader label for the '+' button at the end of the quick-row that opens the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Add custom emoji reaction'**
  String get dmReactionAddCustomA11yLabel;

  /// Hint text in the in-player reply composer when replying to a reel that {name} shared in a DM.
  ///
  /// In en, this message translates to:
  /// **'Message {name}…'**
  String dmReelReplyComposerHint(String name);

  /// Hint text in the in-player reply composer when the reel was shared by the current user themselves.
  ///
  /// In en, this message translates to:
  /// **'Reply to yourself…'**
  String get dmReelReplyComposerHintSelf;

  /// Screen-reader label for the in-player reel reply text field.
  ///
  /// In en, this message translates to:
  /// **'Reply to this reel'**
  String get dmReelReplyComposerSemanticLabel;

  /// Tappable action in the 'Sent · View chat' confirmation that opens the DM conversation.
  ///
  /// In en, this message translates to:
  /// **'View chat'**
  String get dmReelReplyViewChat;

  /// Screen-reader announcement after a reel reply sends successfully.
  ///
  /// In en, this message translates to:
  /// **'Reply sent'**
  String get dmReelReplySentAnnouncement;

  /// Screen-reader announcement after a reel quick-reaction is sent.
  ///
  /// In en, this message translates to:
  /// **'Reacted {emoji}'**
  String dmReelReactionSentAnnouncement(String emoji);

  /// Transient toast shown in the reel player when a reply or reaction fails to send.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send'**
  String get dmReelReplyFailed;

  /// Transient toast shown in the reel player when a retry could not determine whether the reply was delivered. Offers 'View chat' rather than another retry, because retrying could send a duplicate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm that sent'**
  String get dmReelReplyUnverified;

  /// Screen-reader label for a reaction chip created by the current account.
  ///
  /// In en, this message translates to:
  /// **'Your reaction: {emoji}'**
  String dmReactionChipOwnA11yLabel(String emoji);

  /// Screen-reader label for a reaction chip created by another participant.
  ///
  /// In en, this message translates to:
  /// **'{name} reacted with {emoji}'**
  String dmReactionChipOtherA11yLabel(String name, String emoji);

  /// Screen-reader label for a reaction chip whose publish is in flight.
  ///
  /// In en, this message translates to:
  /// **'Sending reaction: {emoji}'**
  String dmReactionChipPendingA11yLabel(String emoji);

  /// Screen-reader label for a reaction chip whose publish failed.
  ///
  /// In en, this message translates to:
  /// **'Reaction failed, double tap to retry'**
  String get dmReactionChipFailedA11yLabel;

  /// Live-region announcement on chip retry.
  ///
  /// In en, this message translates to:
  /// **'Retrying reaction'**
  String get dmReactionChipRetryAnnouncement;

  /// Screen-reader label for an own reaction whose removal was refused.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove your {emoji} reaction. Double tap to try again'**
  String dmReactionRemovalRefusedA11yLabel(String emoji);

  /// Title of the retry prompt for a refused DM reaction removal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove your reaction.'**
  String get dmReactionRemovalRefusedTitle;

  /// Snackbar shown when adding a DM reaction is blocked until an earlier removal finishes.
  ///
  /// In en, this message translates to:
  /// **'Finish removing your previous reaction before adding another.'**
  String get dmReactionAddBlockedByRemoval;

  /// Detail text explaining that a refused DM reaction removal may remain visible to recipients.
  ///
  /// In en, this message translates to:
  /// **'Some people may still be able to see this reaction.'**
  String get dmReactionRemovalRefusedDetails;

  /// Title of the bottom sheet listing everyone who reacted to a DM message.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get dmReactionsSheetTitle;

  /// Screen-reader label for the combined reaction pill button that opens the who-reacted sheet.
  ///
  /// In en, this message translates to:
  /// **'See who reacted'**
  String get dmReactionsViewA11yLabel;

  /// Action on the current account's own row in the reactions sheet to remove their reaction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get dmReactionRemoveAction;

  /// Action on the current account's own failed reaction row in the reactions sheet to retry publishing.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dmReactionRetryAction;

  /// Label for the Bold formatting action in the DM composer's text-selection context menu. Wraps the selected text with markdown bold markers (e.g. **text**).
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get dmFormatBold;

  /// Label for the Italic formatting action in the DM composer's text-selection context menu. Wraps the selected text with markdown italic markers (e.g. _text_).
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get dmFormatItalic;

  /// Label for the Strikethrough formatting action in the DM composer's text-selection context menu. Wraps the selected text with markdown strikethrough markers (e.g. ~~text~~).
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get dmFormatStrikethrough;

  /// Label for the inline-code formatting action in the DM composer's text-selection context menu. Wraps the selected text with markdown inline-code markers (e.g. `text`).
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get dmFormatCode;

  /// Accessibility label / tooltip on the error indicator at the bottom of a sent DM bubble whose recipient gift wrap publish has failed and is awaiting retry.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get dmStatusFailed;

  /// Accessibility label announced by screen readers when the long-press actions bottom sheet for a conversation row opens.
  ///
  /// In en, this message translates to:
  /// **'Conversation actions'**
  String get inboxConversationActionsSheetLabel;

  /// Accessibility label for a conversation row in the inbox list, read by screen readers when the row receives focus. Use the other participant's display name.
  ///
  /// In en, this message translates to:
  /// **'{displayName} conversation'**
  String inboxConversationTileLabel(String displayName);

  /// Accessibility label for an UNREAD conversation row in the inbox list, read by screen readers when the row receives focus. Prefixes the unread status before the display name so assistive-technology users get the same unread signal sighted users get from the dot and emphasized preview.
  ///
  /// In en, this message translates to:
  /// **'Unread, {displayName} conversation'**
  String inboxConversationTileLabelUnread(String displayName);

  /// Names a group DM thread that carries no NIP-17 `subject` tag, from the first other participant plus how many participants remain beyond them. Example: 'Alice and 2 others'. A room that DOES carry a subject renders that instead, untranslated, because a participant chose it.
  ///
  /// In en, this message translates to:
  /// **'{name} and {count, plural, =1{{count} other} other{{count} others}}'**
  String inboxGroupConversationTitle(String name, int count);

  /// Accessibility hint announced when a conversation row is focused, telling the user that long-pressing opens the actions sheet (mute, report, block, remove).
  ///
  /// In en, this message translates to:
  /// **'Show conversation actions'**
  String get inboxConversationTileLongPressHint;

  /// No description provided for @exploreVideoId.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String exploreVideoId(String id);

  /// No description provided for @exploreVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Title: {title}'**
  String exploreVideoTitle(String title);

  /// No description provided for @exploreVideoCounter.
  ///
  /// In en, this message translates to:
  /// **'Video {current}/{total}'**
  String exploreVideoCounter(int current, int total);

  /// No description provided for @exploreSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get exploreSearchHint;

  /// No description provided for @categoryVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{countValue, plural, =1{{count} video} other{{count} videos}}'**
  String categoryVideoCount(int countValue, String count);

  /// No description provided for @discoverListsFailedToUpdateSubscription.
  ///
  /// In en, this message translates to:
  /// **'Failed to update subscription. Please try again.'**
  String get discoverListsFailedToUpdateSubscription;

  /// No description provided for @discoverListsTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover Lists'**
  String get discoverListsTitle;

  /// No description provided for @discoverListsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load lists'**
  String get discoverListsFailedToLoad;

  /// No description provided for @discoverListsLoading.
  ///
  /// In en, this message translates to:
  /// **'Discovering public lists...'**
  String get discoverListsLoading;

  /// No description provided for @discoverListsRelayTimeout.
  ///
  /// In en, this message translates to:
  /// **'The relay did not return lists in time. Try again.'**
  String get discoverListsRelayTimeout;

  /// No description provided for @discoverListsServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service not available.'**
  String get discoverListsServiceUnavailable;

  /// No description provided for @discoverListsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No public lists found'**
  String get discoverListsEmptyTitle;

  /// No description provided for @discoverListsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new lists'**
  String get discoverListsEmptySubtitle;

  /// No description provided for @discoverListsByAuthorPrefix.
  ///
  /// In en, this message translates to:
  /// **'by'**
  String get discoverListsByAuthorPrefix;

  /// No description provided for @curatedListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No videos in this list'**
  String get curatedListEmptyTitle;

  /// No description provided for @curatedListEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add some videos to get started'**
  String get curatedListEmptySubtitle;

  /// No description provided for @curatedListLoadingVideos.
  ///
  /// In en, this message translates to:
  /// **'Loading videos...'**
  String get curatedListLoadingVideos;

  /// No description provided for @curatedListFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load list'**
  String get curatedListFailedToLoad;

  /// No description provided for @curatedListVideoNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Video not available'**
  String get curatedListVideoNotAvailable;

  /// No description provided for @curatedListActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'List actions'**
  String get curatedListActionsTooltip;

  /// No description provided for @curatedListDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete list?'**
  String get curatedListDeleteConfirmTitle;

  /// No description provided for @curatedListDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the list from relays. Videos in the list will not be deleted.'**
  String get curatedListDeleteConfirmBody;

  /// No description provided for @curatedListDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Deleted list'**
  String get curatedListDeletedSnack;

  /// No description provided for @curatedListDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete list'**
  String get curatedListDeleteFailed;

  /// No description provided for @peopleListsActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'List actions'**
  String get peopleListsActionsTooltip;

  /// No description provided for @listDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get listDeleteAction;

  /// No description provided for @peopleListsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete list?'**
  String get peopleListsDeleteConfirmTitle;

  /// No description provided for @peopleListsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the list for everyone. The people in it will not be unfollowed.'**
  String get peopleListsDeleteConfirmBody;

  /// No description provided for @peopleListsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete list'**
  String get peopleListsDeleteFailed;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Generic error message shown when an async load fails and no more specific message applies. Must not embed raw exception text.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// Screen-reader label for a progress indicator, announced while content or an action is loading. Covers both a full-screen spinner that blocks the content behind it and a small inline one next to content that stays reachable.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// Snackbar message shown when saving the chosen cover thumbnail fails on the cover-edit screen. The user can dismiss and try again.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the cover. Try again.'**
  String get videoMetadataEditCoverFailedSnackbar;

  /// Screen-reader announcement spoken after the user confirms a new cover thumbnail and the screen is about to close. Visual users get the screen pop as feedback; this is the audio equivalent.
  ///
  /// In en, this message translates to:
  /// **'Cover updated'**
  String get videoMetadataEditCoverSuccessAnnouncement;

  /// Title of a bottom sheet shown after rendering a video when the C2PA content-credential signature could not be created (e.g. offline). Asks whether to regenerate or post without provenance.
  ///
  /// In en, this message translates to:
  /// **'Post without the human-made check?'**
  String get videoMetadataC2paMissingTitle;

  /// Body text of the bottom sheet warning that a video will be published without a C2PA content credential, meaning it will not be verifiably confirmed as human-made.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t add content credentials, so this video won\'t be confirmed as Human-Made. Regenerate to try again, or post it as-is.'**
  String get videoMetadataC2paMissingBody;

  /// Small trailing note under the missing-content-credential bottom sheet, shown when the device is offline, where connectivity really is the likely cause. When the device is online, videoMetadataC2paMissingNoteServiceUnavailable is shown instead.
  ///
  /// In en, this message translates to:
  /// **'Content credentials need an internet connection.'**
  String get videoMetadataC2paMissingNote;

  /// Small trailing note under the missing-content-credential bottom sheet, shown when the device IS online, so signing failed on the service side (outage, misconfigured endpoint, rejected request). Explicitly rules out the user's connection, because the previous connectivity-only wording sent users to debug working wifi.
  ///
  /// In en, this message translates to:
  /// **'The content credential service didn\'t respond. This isn\'t your connection.'**
  String get videoMetadataC2paMissingNoteServiceUnavailable;

  /// Primary button on the missing-content-credential bottom sheet. Re-renders the video to attempt the C2PA signature again.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get videoMetadataC2paMissingRegenerate;

  /// Secondary button on the missing-content-credential bottom sheet. Dismisses the prompt and continues without a C2PA content credential, so the user can post the video without provenance.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get videoMetadataC2paMissingSkip;

  /// Warning shown over the metadata screen preview when rendering (generating) the final video failed and no clip was produced. Sits above a retry icon button.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get videoMetadataGenerationFailed;

  /// No description provided for @videoMetadataTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get videoMetadataTags;

  /// No description provided for @videoMetadataExpiration.
  ///
  /// In en, this message translates to:
  /// **'Expiration'**
  String get videoMetadataExpiration;

  /// No description provided for @videoMetadataExpirationNotExpire.
  ///
  /// In en, this message translates to:
  /// **'Does not expire'**
  String get videoMetadataExpirationNotExpire;

  /// No description provided for @videoMetadataExpirationOneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get videoMetadataExpirationOneDay;

  /// No description provided for @videoMetadataExpirationOneWeek.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get videoMetadataExpirationOneWeek;

  /// No description provided for @videoMetadataExpirationOneMonth.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get videoMetadataExpirationOneMonth;

  /// No description provided for @videoMetadataExpirationOneYear.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get videoMetadataExpirationOneYear;

  /// No description provided for @videoMetadataExpirationOneDecade.
  ///
  /// In en, this message translates to:
  /// **'1 decade'**
  String get videoMetadataExpirationOneDecade;

  /// No description provided for @videoMetadataContentWarnings.
  ///
  /// In en, this message translates to:
  /// **'Content Warnings'**
  String get videoMetadataContentWarnings;

  /// No description provided for @videoEditorStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get videoEditorStickers;

  /// No description provided for @trendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trendingTitle;

  /// No description provided for @libraryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get libraryDeleteConfirm;

  /// No description provided for @libraryWebUnavailableHeadline.
  ///
  /// In en, this message translates to:
  /// **'Library is available in the mobile app'**
  String get libraryWebUnavailableHeadline;

  /// No description provided for @libraryWebUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Drafts and clips are saved on your device, so open Divine on your phone to manage them.'**
  String get libraryWebUnavailableDescription;

  /// No description provided for @libraryTabDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get libraryTabDrafts;

  /// No description provided for @libraryTabClips.
  ///
  /// In en, this message translates to:
  /// **'Clips'**
  String get libraryTabClips;

  /// No description provided for @libraryDeleteSelectedClipsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected clips'**
  String get libraryDeleteSelectedClipsTooltip;

  /// Accessibility label for the library toolbar button that leaves the library screen.
  ///
  /// In en, this message translates to:
  /// **'Close library'**
  String get libraryCloseSemanticLabel;

  /// Accessibility label for the library toolbar button that exits clip-selection mode.
  ///
  /// In en, this message translates to:
  /// **'Stop selecting clips'**
  String get libraryStopSelectingClipsSemanticLabel;

  /// Accessibility label for the library toolbar button that enters clip-selection mode.
  ///
  /// In en, this message translates to:
  /// **'Select clips'**
  String get librarySelectClipsSemanticLabel;

  /// Row in the library sort menu that opens the clip grid size options. The same choice can be made by pinching the grid, which assistive technology cannot perform.
  ///
  /// In en, this message translates to:
  /// **'Grid size'**
  String get libraryGridSizeLabel;

  /// Names the library action that opens the sorting and grid size options. Used twice: as the accessibility label of the toolbar button, and as the visible label of its overflow-menu row when the toolbar is too narrow to show that button.
  ///
  /// In en, this message translates to:
  /// **'Sort & grid size'**
  String get libraryDisplayOptionsLabel;

  /// Accessibility label for the library toolbar button that opens the actions which did not fit in the toolbar.
  ///
  /// In en, this message translates to:
  /// **'More library actions'**
  String get libraryMoreActionsSemanticLabel;

  /// Option in the library grid size menu, naming how many columns of clips the grid shows. The range is 2 to 5. English never selects the singular arm in that range, but other locales do — Filipino selects `one` at 2, 3 and 5 — so every arm must interpolate {count} rather than spell out a digit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 column} other{{count} columns}}'**
  String libraryGridSizeColumns(int count);

  /// No description provided for @librarySelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get librarySelect;

  /// No description provided for @librarySortNewestCreation.
  ///
  /// In en, this message translates to:
  /// **'Newest Creation'**
  String get librarySortNewestCreation;

  /// No description provided for @librarySortOldestCreation.
  ///
  /// In en, this message translates to:
  /// **'Oldest Creation'**
  String get librarySortOldestCreation;

  /// No description provided for @librarySortLongestClip.
  ///
  /// In en, this message translates to:
  /// **'Longest Clip'**
  String get librarySortLongestClip;

  /// No description provided for @librarySortShortestClip.
  ///
  /// In en, this message translates to:
  /// **'Shortest Clip'**
  String get librarySortShortestClip;

  /// No description provided for @librarySortSquareFirst.
  ///
  /// In en, this message translates to:
  /// **'Square First'**
  String get librarySortSquareFirst;

  /// No description provided for @librarySortVerticalFirst.
  ///
  /// In en, this message translates to:
  /// **'Vertical First'**
  String get librarySortVerticalFirst;

  /// No description provided for @libraryDeleteClipsWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. The video files will be permanently removed from your device.'**
  String get libraryDeleteClipsWarning;

  /// No description provided for @libraryPreparingVideo.
  ///
  /// In en, this message translates to:
  /// **'Preparing video...'**
  String get libraryPreparingVideo;

  /// No description provided for @libraryCreateVideo.
  ///
  /// In en, this message translates to:
  /// **'Create Video ({count})'**
  String libraryCreateVideo(int count);

  /// No description provided for @libraryClipsSavedToDestination.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clip} other{{count} clips}} saved to {destination}'**
  String libraryClipsSavedToDestination(int count, String destination);

  /// No description provided for @libraryClipsSavePartialResult.
  ///
  /// In en, this message translates to:
  /// **'{successCount} saved, {failureCount} failed'**
  String libraryClipsSavePartialResult(int successCount, int failureCount);

  /// Snackbar shown when saving selected clips to the device gallery fails unexpectedly. {destination} is the platform gallery name (e.g. "Camera Roll").
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save to {destination}'**
  String libraryClipsSaveFailed(String destination);

  /// No description provided for @libraryGalleryPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'{destination} permission denied'**
  String libraryGalleryPermissionDenied(String destination);

  /// No description provided for @libraryClipsDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clip deleted} other{{count} clips deleted}}'**
  String libraryClipsDeletedCount(int count);

  /// Action button on the 'N clips deleted' snackbar shown after the user deletes clips from their library. Tapping it restores the clips from the trash bin.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get libraryClipsDeletedUndoLabel;

  /// Subtitle on a trashed clip tile counting down to when the 30-day retention purge will permanently delete it. Replaces the recorded-date subtitle in the trash view.
  ///
  /// In en, this message translates to:
  /// **'{daysLeft, plural, =0{Auto-deletes today} =1{Auto-deletes tomorrow} other{Auto-deletes in {daysLeft} days}}'**
  String libraryTrashAutoDeletes(int daysLeft);

  /// No description provided for @libraryCouldNotLoadDrafts.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load drafts'**
  String get libraryCouldNotLoadDrafts;

  /// No description provided for @libraryCouldNotLoadClips.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load clips'**
  String get libraryCouldNotLoadClips;

  /// No description provided for @libraryOpenErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while opening your library. You can try again.'**
  String get libraryOpenErrorDescription;

  /// No description provided for @libraryNoDraftsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No Drafts Yet'**
  String get libraryNoDraftsYetTitle;

  /// No description provided for @libraryNoDraftsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos you save as draft will appear here'**
  String get libraryNoDraftsYetSubtitle;

  /// No description provided for @libraryNoClipsYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No Clips Yet'**
  String get libraryNoClipsYetTitle;

  /// No description provided for @libraryNoClipsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your recorded video clips will appear here'**
  String get libraryNoClipsYetSubtitle;

  /// No description provided for @libraryDraftDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted'**
  String get libraryDraftDeletedSnackbar;

  /// No description provided for @libraryDraftDeleteFailedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete draft'**
  String get libraryDraftDeleteFailedSnackbar;

  /// No description provided for @libraryDraftDuplicatedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Draft duplicated'**
  String get libraryDraftDuplicatedSnackbar;

  /// No description provided for @libraryDraftDuplicateFailedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to duplicate draft'**
  String get libraryDraftDuplicateFailedSnackbar;

  /// No description provided for @libraryDraftInProgressBadge.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get libraryDraftInProgressBadge;

  /// No description provided for @libraryDraftActionPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get libraryDraftActionPost;

  /// No description provided for @libraryDraftActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get libraryDraftActionEdit;

  /// No description provided for @libraryDraftActionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get libraryDraftActionDuplicate;

  /// No description provided for @libraryDraftActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get libraryDraftActionDelete;

  /// Title given to a duplicated draft. {number} disambiguates repeated copies, e.g. "Trip (copy 2)".
  ///
  /// In en, this message translates to:
  /// **'{title} (copy {number})'**
  String libraryDraftCopyTitle(String title, int number);

  /// No description provided for @libraryDeleteDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Draft'**
  String get libraryDeleteDraftTitle;

  /// No description provided for @libraryDeleteDraftMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String libraryDeleteDraftMessage(String title);

  /// No description provided for @libraryDeleteClipTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Clip'**
  String get libraryDeleteClipTitle;

  /// No description provided for @libraryDeleteClipMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this clip?'**
  String get libraryDeleteClipMessage;

  /// Compact clip duration shown in the library trash row. {seconds} is already formatted with two decimal places, e.g. '5.73'.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String libraryClipDuration(String seconds);

  /// No description provided for @libraryRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record a Video'**
  String get libraryRecordVideo;

  /// Accessibility label for a video clip thumbnail. Duration is formatted as seconds with 2 decimal places, e.g. '5.73'.
  ///
  /// In en, this message translates to:
  /// **'Video clip, {duration} seconds'**
  String videoClipSemanticLabel(String duration);

  /// Accessibility label for an archived clip thumbnail shown inside a category. Wraps the clip's own label.
  ///
  /// In en, this message translates to:
  /// **'Archived. {label}'**
  String videoClipArchivedSemanticLabel(String label);

  /// Accessibility label for a stop-motion clip thumbnail. {frames} is the already-localized frame count from videoEditorStopMotionFramesCount. Replaces the duration label, which is a misleading value for stop-motion and is hidden visually for the same reason.
  ///
  /// In en, this message translates to:
  /// **'Stop-motion clip, {frames}'**
  String videoClipStopMotionSemanticLabel(String frames);

  /// Accessibility value for a selected video clip thumbnail, announcing its position in the selection order. Mirrors the number shown in the on-screen selection badge.
  ///
  /// In en, this message translates to:
  /// **'Selected, number {position}'**
  String videoClipSemanticValueSelectedAtPosition(int position);

  /// No description provided for @videoClipSemanticValueSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get videoClipSemanticValueSelected;

  /// No description provided for @videoClipSemanticValueNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get videoClipSemanticValueNotSelected;

  /// No description provided for @videoClipSemanticHintDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get videoClipSemanticHintDisabled;

  /// No description provided for @videoClipSemanticHintSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select, long press to preview'**
  String get videoClipSemanticHintSelect;

  /// No description provided for @videoClipSemanticHintDeselect.
  ///
  /// In en, this message translates to:
  /// **'Tap to deselect, long press to preview'**
  String get videoClipSemanticHintDeselect;

  /// No description provided for @routerInvalidCreator.
  ///
  /// In en, this message translates to:
  /// **'Invalid creator'**
  String get routerInvalidCreator;

  /// No description provided for @routerInvalidHashtagRoute.
  ///
  /// In en, this message translates to:
  /// **'Invalid hashtag route'**
  String get routerInvalidHashtagRoute;

  /// No description provided for @categoryGalleryCouldNotLoadVideos.
  ///
  /// In en, this message translates to:
  /// **'Could not load videos'**
  String get categoryGalleryCouldNotLoadVideos;

  /// No description provided for @categoryGalleryNoVideosInCategory.
  ///
  /// In en, this message translates to:
  /// **'No videos in this category'**
  String get categoryGalleryNoVideosInCategory;

  /// No description provided for @categoryGallerySortOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Category sort options'**
  String get categoryGallerySortOptionsLabel;

  /// No description provided for @categoryGallerySortHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get categoryGallerySortHot;

  /// No description provided for @categoryGallerySortNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get categoryGallerySortNew;

  /// No description provided for @categoryGallerySortClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get categoryGallerySortClassic;

  /// No description provided for @categoryGallerySortForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get categoryGallerySortForYou;

  /// No description provided for @categoriesCouldNotLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories'**
  String get categoriesCouldNotLoadCategories;

  /// No description provided for @categoriesNoCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No categories available'**
  String get categoriesNoCategoriesAvailable;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When people interact with your content, you\'ll see it here'**
  String get notificationsEmptySubtitle;

  /// No description provided for @appsPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Integration Permissions'**
  String get appsPermissionsTitle;

  /// No description provided for @appsPermissionsRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get appsPermissionsRevoke;

  /// No description provided for @appsPermissionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved integration permissions'**
  String get appsPermissionsEmptyTitle;

  /// No description provided for @appsPermissionsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approved integrations will appear here after you remember an access approval.'**
  String get appsPermissionsEmptySubtitle;

  /// No description provided for @nostrAppPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'{appName} wants your approval'**
  String nostrAppPermissionTitle(String appName);

  /// No description provided for @nostrAppPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'This app is requesting access through Divine\'s vetted sandbox.'**
  String get nostrAppPermissionDescription;

  /// No description provided for @nostrAppPermissionOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get nostrAppPermissionOrigin;

  /// No description provided for @nostrAppPermissionMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get nostrAppPermissionMethod;

  /// No description provided for @nostrAppPermissionCapability.
  ///
  /// In en, this message translates to:
  /// **'Capability'**
  String get nostrAppPermissionCapability;

  /// No description provided for @nostrAppPermissionEventKind.
  ///
  /// In en, this message translates to:
  /// **'Event kind'**
  String get nostrAppPermissionEventKind;

  /// No description provided for @nostrAppPermissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get nostrAppPermissionAllow;

  /// No description provided for @appsDetailDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrated App'**
  String get appsDetailDefaultTitle;

  /// No description provided for @appsDetailNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Integration not found'**
  String get appsDetailNotFoundTitle;

  /// No description provided for @appsDetailNotFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This approved integration is no longer available in Divine.'**
  String get appsDetailNotFoundSubtitle;

  /// No description provided for @appsDetailHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get appsDetailHowItWorksTitle;

  /// No description provided for @appsDetailHowItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'This is an approved third-party app that runs inside Divine. Divine only grants reviewed capabilities for this integration, and blocks navigation outside its approved origins.'**
  String get appsDetailHowItWorksBody;

  /// No description provided for @appsDetailAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get appsDetailAboutTitle;

  /// No description provided for @appsDetailPrimaryOriginTitle.
  ///
  /// In en, this message translates to:
  /// **'Primary origin'**
  String get appsDetailPrimaryOriginTitle;

  /// No description provided for @appsDetailApprovedOriginsTitle.
  ///
  /// In en, this message translates to:
  /// **'Approved origins'**
  String get appsDetailApprovedOriginsTitle;

  /// No description provided for @appsDetailCapabilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Available capabilities'**
  String get appsDetailCapabilitiesTitle;

  /// No description provided for @appsDetailAskBeforeTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask before'**
  String get appsDetailAskBeforeTitle;

  /// No description provided for @appsDetailOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Open Integration'**
  String get appsDetailOpenButton;

  /// No description provided for @appsDetailNoneDeclared.
  ///
  /// In en, this message translates to:
  /// **'None declared yet'**
  String get appsDetailNoneDeclared;

  /// No description provided for @appsDirectoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrated Apps'**
  String get appsDirectoryTitle;

  /// No description provided for @appsDirectoryIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Approved third-party apps'**
  String get appsDirectoryIntroTitle;

  /// No description provided for @appsDirectoryIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Approved third-party apps that run inside Divine'**
  String get appsDirectoryIntroBody;

  /// No description provided for @appsDirectoryErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load integrated apps'**
  String get appsDirectoryErrorTitle;

  /// No description provided for @appsDirectoryErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pull to try the approved integrations again.'**
  String get appsDirectoryErrorSubtitle;

  /// No description provided for @appsDirectoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No approved integrations yet'**
  String get appsDirectoryEmptyTitle;

  /// No description provided for @appsDirectoryEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approved third-party apps will appear here as Divine adds them.'**
  String get appsDirectoryEmptySubtitle;

  /// No description provided for @appsDirectoryRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get appsDirectoryRefresh;

  /// No description provided for @appsDirectoryUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrated Apps run in Divine mobile'**
  String get appsDirectoryUnsupportedTitle;

  /// No description provided for @appsDirectoryUnsupportedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approved integrations are only available on mobile for now.'**
  String get appsDirectoryUnsupportedSubtitle;

  /// No description provided for @appsSandboxUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Integration unavailable'**
  String get appsSandboxUnavailableTitle;

  /// No description provided for @appsSandboxUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Open approved integrations from the Integrated Apps tab so Divine can apply the right access policy.'**
  String get appsSandboxUnavailableBody;

  /// No description provided for @appsSandboxLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading integration'**
  String get appsSandboxLoadingTitle;

  /// No description provided for @appsSandboxLoadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checking the approved integration before launch.'**
  String get appsSandboxLoadingSubtitle;

  /// No description provided for @appsSandboxBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked for safety'**
  String get appsSandboxBlockedTitle;

  /// Shown when a sandboxed integration tries to navigate outside its approved origin. {uri} is the blocked URL.
  ///
  /// In en, this message translates to:
  /// **'This integration tried to leave its approved origin.\n\n{uri}'**
  String appsSandboxBlockedSubtitle(String uri);

  /// No description provided for @shareCopiedPostLink.
  ///
  /// In en, this message translates to:
  /// **'Link to post copied to clipboard'**
  String get shareCopiedPostLink;

  /// No description provided for @shareCopiedEventJson.
  ///
  /// In en, this message translates to:
  /// **'Nostr event JSON copied to clipboard'**
  String get shareCopiedEventJson;

  /// No description provided for @shareCopiedEventId.
  ///
  /// In en, this message translates to:
  /// **'Nostr event ID copied to clipboard'**
  String get shareCopiedEventId;

  /// No description provided for @authHeroTaglineAuthentic.
  ///
  /// In en, this message translates to:
  /// **'Authentic moments.'**
  String get authHeroTaglineAuthentic;

  /// No description provided for @authHeroTaglineHuman.
  ///
  /// In en, this message translates to:
  /// **'Human creativity.'**
  String get authHeroTaglineHuman;

  /// No description provided for @keyImportFailedToImport.
  ///
  /// In en, this message translates to:
  /// **'Failed to import key or connect bunker'**
  String get keyImportFailedToImport;

  /// No description provided for @keyImportInvalidBunkerUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid bunker URL'**
  String get keyImportInvalidBunkerUrl;

  /// No description provided for @keyImportInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid format. Use nsec..., hex, ncryptsec1..., or bunker://...'**
  String get keyImportInvalidFormat;

  /// No description provided for @keyImportInvalidNsecFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid nsec format. Should be 63 characters'**
  String get keyImportInvalidNsecFormat;

  /// No description provided for @keyImportKeyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Private key or bunker URL'**
  String get keyImportKeyFieldLabel;

  /// No description provided for @keyImportKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your private key or bunker URL'**
  String get keyImportKeyRequired;

  /// No description provided for @keyImportPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the password for this encrypted key'**
  String get keyImportPasswordRequired;

  /// No description provided for @keyImportSecurityWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Never share your private key with anyone. This key gives full access to your Nostr identity.'**
  String get keyImportSecurityWarningBody;

  /// No description provided for @keyImportSecurityWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your private key secure!'**
  String get keyImportSecurityWarningTitle;

  /// No description provided for @keyImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import your existing Nostr identity using your private key or a bunker URL.'**
  String get keyImportSubtitle;

  /// No description provided for @keyImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import your\nNostr identity'**
  String get keyImportTitle;

  /// No description provided for @commentAuthorYouIndicator.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get commentAuthorYouIndicator;

  /// Screen-reader label for the tappable comment author avatar, which opens the author's profile. {name} is the author's display name.
  ///
  /// In en, this message translates to:
  /// **'View {name}\'s profile'**
  String commentAuthorAvatarSemanticLabel(String name);

  /// No description provided for @commentOptionsDeleteSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get commentOptionsDeleteSemanticLabel;

  /// No description provided for @commentOptionsEditSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get commentOptionsEditSemanticLabel;

  /// No description provided for @commentOptionsFlagContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Flag Content'**
  String get commentOptionsFlagContentLabel;

  /// No description provided for @commentOptionsFlagContentSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Flag this content'**
  String get commentOptionsFlagContentSemanticLabel;

  /// No description provided for @commentOptionsFlagReasonPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a reason for flagging this comment'**
  String get commentOptionsFlagReasonPrompt;

  /// No description provided for @commentOptionsFlagSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commentOptionsFlagSubmit;

  /// No description provided for @commentOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get commentOptionsTitle;

  /// No description provided for @commentsEmptyClassicVineMessage.
  ///
  /// In en, this message translates to:
  /// **'We\'re still working on importing old comments from the archive. They\'re not ready yet.'**
  String get commentsEmptyClassicVineMessage;

  /// No description provided for @commentsEmptyClassicVineTitle.
  ///
  /// In en, this message translates to:
  /// **'Classic Vine'**
  String get commentsEmptyClassicVineTitle;

  /// No description provided for @commentsInputEditingLabel.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get commentsInputEditingLabel;

  /// No description provided for @commentsInputSemanticHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get commentsInputSemanticHint;

  /// No description provided for @commentsInputSemanticHintEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get commentsInputSemanticHintEdit;

  /// No description provided for @commentsInputSemanticHintReply.
  ///
  /// In en, this message translates to:
  /// **'Add a reply'**
  String get commentsInputSemanticHintReply;

  /// No description provided for @commentsInputSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment input'**
  String get commentsInputSemanticLabel;

  /// No description provided for @commentsInputSemanticLabelEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit input'**
  String get commentsInputSemanticLabelEdit;

  /// No description provided for @commentsInputSemanticLabelReply.
  ///
  /// In en, this message translates to:
  /// **'Reply input'**
  String get commentsInputSemanticLabelReply;

  /// No description provided for @classicVinersViewProfileSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'View profile for {displayName}'**
  String classicVinersViewProfileSemanticLabel(String displayName);

  /// No description provided for @classicsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'The Classics archive is being loaded'**
  String get classicsEmptyDescription;

  /// No description provided for @classicsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Classics Found'**
  String get classicsEmptyTitle;

  /// No description provided for @classicsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Classics'**
  String get classicsErrorTitle;

  /// No description provided for @classicsUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Classics are only available when connected to Funnelcake relays.'**
  String get classicsUnavailableDescription;

  /// No description provided for @classicsUnavailableSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Switch to a Funnelcake-enabled relay in Settings to access the Classics archive.'**
  String get classicsUnavailableSettingsHint;

  /// No description provided for @classicsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Classics Unavailable'**
  String get classicsUnavailableTitle;

  /// No description provided for @hashtagFeedEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to post a video with this hashtag!'**
  String get hashtagFeedEmptySubtitle;

  /// No description provided for @hashtagFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No videos found for #{hashtag}'**
  String hashtagFeedEmptyTitle(String hashtag);

  /// No description provided for @hashtagFeedLoadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This may take a few moments'**
  String get hashtagFeedLoadingSubtitle;

  /// No description provided for @hashtagFeedLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading videos about #{hashtag}...'**
  String hashtagFeedLoadingTitle(String hashtag);

  /// No description provided for @hashtagInputHint.
  ///
  /// In en, this message translates to:
  /// **'Add hashtags... #vine #nostr'**
  String get hashtagInputHint;

  /// No description provided for @newVideosTabEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new content'**
  String get newVideosTabEmptySubtitle;

  /// No description provided for @newVideosTabEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No videos in New Videos'**
  String get newVideosTabEmptyTitle;

  /// No description provided for @popularVideosContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Popular Videos'**
  String get popularVideosContextTitle;

  /// No description provided for @popularVideosEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new content'**
  String get popularVideosEmptySubtitle;

  /// No description provided for @popularVideosEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No videos in Popular Videos'**
  String get popularVideosEmptyTitle;

  /// No description provided for @popularVideosErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load trending videos'**
  String get popularVideosErrorTitle;

  /// No description provided for @popularVideosFeedSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Popular feed source'**
  String get popularVideosFeedSourceLabel;

  /// No description provided for @trendingHashtagsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading hashtags...'**
  String get trendingHashtagsLoading;

  /// No description provided for @trendingHashtagsViewVideosTagged.
  ///
  /// In en, this message translates to:
  /// **'View videos tagged {hashtag}'**
  String trendingHashtagsViewVideosTagged(String hashtag);

  /// No description provided for @videoGridAuthorSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Video author: {name}'**
  String videoGridAuthorSemanticLabel(String name);

  /// No description provided for @videoGridDescriptionSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Video description: {description}'**
  String videoGridDescriptionSemanticLabel(String description);

  /// No description provided for @forYouAlgorithmChoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Divine\'s vision is to give you true algorithmic choice. Instead of being locked into a single black-box algorithm, you\'ll be able to choose from multiple recommendation approaches:'**
  String get forYouAlgorithmChoiceBody;

  /// No description provided for @forYouAlgorithmChoiceChronological.
  ///
  /// In en, this message translates to:
  /// **'Chronological timeline from creators you follow'**
  String get forYouAlgorithmChoiceChronological;

  /// No description provided for @forYouAlgorithmChoiceClosing.
  ///
  /// In en, this message translates to:
  /// **'This puts you in control of your attention rather than leaving it up to the platform. You should know how your feed is curated and have the power to change it whenever you want.'**
  String get forYouAlgorithmChoiceClosing;

  /// No description provided for @forYouAlgorithmChoiceCustomFeeds.
  ///
  /// In en, this message translates to:
  /// **'Community-created custom feeds for topics like music, comedy, or art'**
  String get forYouAlgorithmChoiceCustomFeeds;

  /// No description provided for @forYouAlgorithmChoicePersonalizedFeed.
  ///
  /// In en, this message translates to:
  /// **'Personalized \"For You\" feed'**
  String get forYouAlgorithmChoicePersonalizedFeed;

  /// No description provided for @forYouAlgorithmChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Algorithm, Your Choice'**
  String get forYouAlgorithmChoiceTitle;

  /// No description provided for @forYouAlgorithmChoiceTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending and popular content'**
  String get forYouAlgorithmChoiceTrending;

  /// No description provided for @forYouAlgorithmCommentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Strong signal — you were engaged enough to respond'**
  String get forYouAlgorithmCommentsDescription;

  /// No description provided for @forYouAlgorithmHowItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'Divine pays attention to how you interact with content to understand what you enjoy. Every time you watch a video, give it a reaction, leave a comment, or repost it, the system takes note.'**
  String get forYouAlgorithmHowItWorksBody;

  /// No description provided for @forYouAlgorithmHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How It Works'**
  String get forYouAlgorithmHowItWorksTitle;

  /// No description provided for @forYouAlgorithmInteractionsIntro.
  ///
  /// In en, this message translates to:
  /// **'Different actions signal different levels of interest:'**
  String get forYouAlgorithmInteractionsIntro;

  /// No description provided for @forYouAlgorithmNewToDivineBody1.
  ///
  /// In en, this message translates to:
  /// **'If you haven\'t built up a viewing history yet, we show a mix of what\'s currently popular and trending alongside recent uploads. This gives you a great starting point to explore.'**
  String get forYouAlgorithmNewToDivineBody1;

  /// No description provided for @forYouAlgorithmNewToDivineBody2.
  ///
  /// In en, this message translates to:
  /// **'As you watch, like, and engage with content, recommendations gradually become more personalized. Over time, your For You feed surfaces videos from creators you might never have discovered on your own.'**
  String get forYouAlgorithmNewToDivineBody2;

  /// No description provided for @forYouAlgorithmNewToDivineTitle.
  ///
  /// In en, this message translates to:
  /// **'New to Divine?'**
  String get forYouAlgorithmNewToDivineTitle;

  /// No description provided for @forYouAlgorithmOpenSourceBody.
  ///
  /// In en, this message translates to:
  /// **'We\'re building an open system where developers can implement their own algorithms, and you can choose which ones to use — or opt out entirely.'**
  String get forYouAlgorithmOpenSourceBody;

  /// No description provided for @forYouAlgorithmOpenSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source & Transparent'**
  String get forYouAlgorithmOpenSourceTitle;

  /// No description provided for @forYouAlgorithmReactionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Medium signal — a quick way to show appreciation'**
  String get forYouAlgorithmReactionsDescription;

  /// No description provided for @forYouAlgorithmReactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get forYouAlgorithmReactionsTitle;

  /// No description provided for @forYouAlgorithmRepostsDescription.
  ///
  /// In en, this message translates to:
  /// **'Strongest signal — sharing with your followers is a powerful endorsement'**
  String get forYouAlgorithmRepostsDescription;

  /// No description provided for @forYouAlgorithmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Powered by Gorse, an open-source recommendation engine'**
  String get forYouAlgorithmSubtitle;

  /// No description provided for @forYouAlgorithmTitle.
  ///
  /// In en, this message translates to:
  /// **'The Divine Algorithm'**
  String get forYouAlgorithmTitle;

  /// No description provided for @forYouAlgorithmViewsDescription.
  ///
  /// In en, this message translates to:
  /// **'Light signal — indicates basic interest'**
  String get forYouAlgorithmViewsDescription;

  /// No description provided for @forYouEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Watch and like some videos to get personalized recommendations.'**
  String get forYouEmptyDescription;

  /// No description provided for @forYouEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Recommendations Yet'**
  String get forYouEmptyTitle;

  /// No description provided for @forYouErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load recommendations'**
  String get forYouErrorTitle;

  /// No description provided for @forYouUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Personalized recommendations require connection to Funnelcake.'**
  String get forYouUnavailableDescription;

  /// No description provided for @forYouUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'For You Unavailable'**
  String get forYouUnavailableTitle;

  /// No description provided for @inboxConversationOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get inboxConversationOptionsLabel;

  /// No description provided for @inboxConversationViewProfileButton.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get inboxConversationViewProfileButton;

  /// No description provided for @inboxMessageRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No message requests'**
  String get inboxMessageRequestsEmpty;

  /// No description provided for @inboxMessageRequestsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Message requests, {requestCount} pending'**
  String inboxMessageRequestsSemanticLabel(int requestCount);

  /// No description provided for @inboxMessageRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Message requests'**
  String get inboxMessageRequestsTitle;

  /// No description provided for @inboxMessagesTab.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get inboxMessagesTab;

  /// No description provided for @inboxRequestTileLabel.
  ///
  /// In en, this message translates to:
  /// **'{displayName} message request'**
  String inboxRequestTileLabel(String displayName);

  /// No description provided for @inboxRequestTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sent a message request'**
  String get inboxRequestTileSubtitle;

  /// No description provided for @inboxRequestsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all requests as read'**
  String get inboxRequestsMarkAllRead;

  /// No description provided for @inboxRequestsRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all requests'**
  String get inboxRequestsRemoveAll;

  /// No description provided for @messageRequestDeclineAndRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Decline and remove'**
  String get messageRequestDeclineAndRemoveButton;

  /// No description provided for @messageRequestDeclinedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Declined {displayName}\'s request'**
  String messageRequestDeclinedSnackbar(String displayName);

  /// Shown in place of the request preview when its database read fails (#7335), next to a `commonRetry` button. The screen previously fell through to the loaded layout, so a failed read rendered a generated placeholder name, a count of 0, and live accept/decline buttons over an unknown sender.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this request.'**
  String get messageRequestLoadFailed;

  /// No description provided for @messageRequestFollowersCount.
  ///
  /// In en, this message translates to:
  /// **'{countValue, plural, =1{{count} Follower} other{{count} Followers}}'**
  String messageRequestFollowersCount(int countValue, String count);

  /// No description provided for @messageRequestVideosCount.
  ///
  /// In en, this message translates to:
  /// **'{countValue, plural, =1{{count} video} other{{count} videos}}'**
  String messageRequestVideosCount(int countValue, String count);

  /// No description provided for @messageRequestMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String messageRequestMessageCount(int count);

  /// No description provided for @messageRequestViewMessagesButton.
  ///
  /// In en, this message translates to:
  /// **'View messages'**
  String get messageRequestViewMessagesButton;

  /// No description provided for @messageRequestViewProfileButton.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get messageRequestViewProfileButton;

  /// No description provided for @messageRequestWantsToMessageYou.
  ///
  /// In en, this message translates to:
  /// **'{displayName} wants to message you, they\'ve sent {messageText}.'**
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  );

  /// Error shown when the signed-in account changed between confirming a deletion and executing it; nothing was deleted.
  ///
  /// In en, this message translates to:
  /// **'You switched accounts, so nothing was deleted. Reopen delete for the account you want to remove.'**
  String get deleteAccountAccountChanged;

  /// Prompt above the confirmation field when the account has no username; the user types the word DELETE.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type:'**
  String get deleteAccountConfirmDeletePrompt;

  /// Prompt above the confirmation field when the account has a username; the user re-types their username to confirm deletion.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type your username:'**
  String get deleteAccountConfirmUsernamePrompt;

  /// Label on the delete-confirmation field when the user must type the DELETE token. Shown inside the field when empty and floating above it once focused, so it stays visible while typing.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE'**
  String get deleteAccountConfirmationHint;

  /// Label on the delete-confirmation field when the user must type their username. Shown inside the field when empty and floating above it once focused, so it stays visible while typing.
  ///
  /// In en, this message translates to:
  /// **'Type your username'**
  String get deleteAccountConfirmationHintUsername;

  /// No description provided for @deleteAccountDeleteAllContentButton.
  ///
  /// In en, this message translates to:
  /// **'Delete All Content'**
  String get deleteAccountDeleteAllContentButton;

  /// Title of the full-screen gate that blocks account use while deletion is recoverable, processing, failed, or awaiting acknowledgement.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account'**
  String get accountDeletionRecoveryTitle;

  /// Explains that an interrupted deletion left the username safely reserved and recoverable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish deleting your account. Your username is reserved for you and can still be restored.'**
  String get accountDeletionRecoveryBody;

  /// Explains that an interrupted deletion left the username safely reserved until the coordinator's expiry date.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish deleting your account. Your username is reserved for you until {expiryDate} and can still be restored.'**
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate);

  /// Button that cancels an interrupted account deletion and restores its pending username.
  ///
  /// In en, this message translates to:
  /// **'Restore my username'**
  String get accountDeletionRestoreUsername;

  /// Shown while the server is durably completing an account deletion.
  ///
  /// In en, this message translates to:
  /// **'Your deletion request is still being processed. You can use another account while we finish.'**
  String get accountDeletionFinishingBody;

  /// Snackbar shown when this installation already holds a pending deletion receipt for a different account.
  ///
  /// In en, this message translates to:
  /// **'Another account deletion is still being processed on this device. Wait for it to finish before deleting this account.'**
  String get accountDeletionOtherAccountPending;

  /// Shown while the server is rolling back an account-deletion attempt the user asked to cancel.
  ///
  /// In en, this message translates to:
  /// **'We\'re cancelling your deletion. Check again before leaving this screen.'**
  String get accountDeletionCancellingBody;

  /// Shown when rollback of a pending username release was not confirmed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t restore your username yet. Check your connection and try again.'**
  String get accountDeletionRecoveryFailed;

  /// Confirms that cancelling an interrupted deletion restored the pending username.
  ///
  /// In en, this message translates to:
  /// **'Your username is restored. Your account was not deleted.'**
  String get accountDeletionUsernameRestored;

  /// Shown when the app cannot load a durable account-deletion attempt.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check your deletion status. Check your connection and try again.'**
  String get accountDeletionRecoveryStatusFailed;

  /// Explains that an interrupted deletion without a reserved username can be cancelled safely.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish deleting your account. You can cancel this attempt and keep your account.'**
  String get accountDeletionCancelAttemptBody;

  /// Button that cancels an interrupted account-deletion attempt that has not begun server processing.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get accountDeletionCancelAttempt;

  /// Confirms cancellation of an interrupted account-deletion attempt without claiming a username was restored.
  ///
  /// In en, this message translates to:
  /// **'Account deletion cancelled. Your account was not deleted.'**
  String get accountDeletionAttemptCancelled;

  /// Fallback explanation for a terminal account-deletion failure when the server supplies no safe detail.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t delete your account. Contact support for help or sign out to leave this screen.'**
  String get accountDeletionTerminalFailureBody;

  /// Secondary action that leaves an account-deletion recovery gate without deleting local credentials.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountDeletionSignOut;

  /// Error shown when account deletion cannot start because the deletion coordinator is unavailable; no destructive deletion has occurred.
  ///
  /// In en, this message translates to:
  /// **'Account deletion isn\'t available right now. Nothing was deleted.'**
  String get deleteAccountDeletionUnavailable;

  /// Neutral error when account deletion could not complete and no claim about username state is safe.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t finish deleting your account. Try again.'**
  String get deleteAccountDeletionIncomplete;

  /// Error shown when account deletion could not be started — an unexpected preparation error, or the account's Divine name ownership could not be confirmed. Nothing was deleted; the user can retry.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t start deleting your account. Nothing was deleted. Try again.'**
  String get deleteAccountDeletionNotStarted;

  /// No description provided for @deleteAccountFinalConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Final Confirmation'**
  String get deleteAccountFinalConfirmationTitle;

  /// No description provided for @deleteAccountKeyDeletionWarning.
  ///
  /// In en, this message translates to:
  /// **'Deletion requests sent, but your keys may not have been fully removed from this device. Go to Settings → Nostr Keys → Remove Keys to retry.'**
  String get deleteAccountKeyDeletionWarning;

  /// No description provided for @deleteAccountLocalDataDeletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion requests sent and you\'re signed out, but some local data could not be removed from this device.'**
  String get deleteAccountLocalDataDeletionFailed;

  /// No description provided for @deleteAccountPreparingDeletion.
  ///
  /// In en, this message translates to:
  /// **'Preparing deletion...'**
  String get deleteAccountPreparingDeletion;

  /// No description provided for @deleteAccountProgressEvents.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total} events'**
  String deleteAccountProgressEvents(int current, int total);

  /// No description provided for @deleteAccountRemoveKeysBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the local login for this account from this device. It won\'t delete your Divine account or Nostr identity.\n\nYour drafts and clips stay saved on this device for this account. If this is your last local account, you\'ll return to the login screen.'**
  String get deleteAccountRemoveKeysBody;

  /// No description provided for @deleteAccountRemoveKeysConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove from device'**
  String get deleteAccountRemoveKeysConfirm;

  /// No description provided for @deleteAccountRemoveKeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this account from this device?'**
  String get deleteAccountRemoveKeysTitle;

  /// Shown when account deletion is blocked before anything is published because the session cannot authorize the server-side account deletion. Tells the user to sign in again and makes clear nothing was deleted.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to delete your account. Nothing has been deleted yet.'**
  String get deleteAccountReauthRequired;

  /// Snackbar shown when the Nostr deletion requests were already published but the server-side Divine account deletion failed for a reason a fresh sign-in cannot clear (5xx, 404, or an unreachable server). Must not claim that nothing was deleted, because the vanish request has already reached relays, and must not tell the user to sign in again, which does not clear a server failure.
  ///
  /// In en, this message translates to:
  /// **'Deletion requests sent for your posts, but we couldn\'t finish deleting your account. Try again in a bit.'**
  String get deleteAccountServerDeletionFailed;

  /// Confirmation shown only after the coordinator reports that the Divine account deletion completed. Restates that Nostr content deletion cannot be guaranteed everywhere.
  ///
  /// In en, this message translates to:
  /// **'Your Divine account was deleted. Deletion requests were sent for your Nostr posts, but some relays, clients, or caches may keep copies.'**
  String get deleteAccountSuccess;

  /// Snackbar when the account-wide vanish request was published but the relay query failed or at least one per-item deletion request was not confirmed. Must not imply every existing post was individually requested or confirmed for deletion.
  ///
  /// In en, this message translates to:
  /// **'Account deletion requested. Some existing posts could not be individually confirmed for deletion.'**
  String get deleteAccountSuccessContentUnverified;

  /// Warning body in the delete-account confirmation dialog, shown above the type-to-confirm field. Be clear that Nostr deletion is request-based, not a guarantee that every relay, client, cache, search index, or other signed-in device will forget the account.
  ///
  /// In en, this message translates to:
  /// **'This sends deletion requests for your account and content, deletes your Divine account when possible, and signs you out on this device. Some relays, clients, and search indexes may keep copies. Other signed-in devices stay active until you remove the keys there.'**
  String get deleteAccountWarningBody;

  /// No description provided for @findPeopleNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts found.\nStart following people to see them here.'**
  String get findPeopleNoContacts;

  /// No description provided for @geoBlockedCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get geoBlockedCityLabel;

  /// No description provided for @geoBlockedCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get geoBlockedCountryLabel;

  /// No description provided for @geoBlockedDefaultReason.
  ///
  /// In en, this message translates to:
  /// **'This service is not available in your region due to local regulations.'**
  String get geoBlockedDefaultReason;

  /// No description provided for @geoBlockedLegalNotice.
  ///
  /// In en, this message translates to:
  /// **'We respect your local laws and regulations. This restriction is based on your IP address location.'**
  String get geoBlockedLegalNotice;

  /// No description provided for @geoBlockedRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get geoBlockedRegionLabel;

  /// No description provided for @geoBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Service Unavailable'**
  String get geoBlockedTitle;

  /// No description provided for @likedVideosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No liked videos'**
  String get likedVideosEmpty;

  /// No description provided for @likedVideosInvalidRoute.
  ///
  /// In en, this message translates to:
  /// **'Invalid route'**
  String get likedVideosInvalidRoute;

  /// No description provided for @likedVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'Liked Videos'**
  String get likedVideosTitle;

  /// No description provided for @uploadFailureSheetRetryingSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Retrying upload…'**
  String get uploadFailureSheetRetryingSnackbar;

  /// No description provided for @uploadFailureSheetSaveToDraftsButton.
  ///
  /// In en, this message translates to:
  /// **'Save to Drafts'**
  String get uploadFailureSheetSaveToDraftsButton;

  /// No description provided for @uploadFailureSheetSavedToDraftsSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Saved to drafts'**
  String get uploadFailureSheetSavedToDraftsSnackbar;

  /// No description provided for @uploadFailureSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Failed'**
  String get uploadFailureSheetTitle;

  /// No description provided for @uploadFailureSheetTryAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get uploadFailureSheetTryAgainButton;

  /// No description provided for @videoEditorAudioImportAudio.
  ///
  /// In en, this message translates to:
  /// **'Import audio'**
  String get videoEditorAudioImportAudio;

  /// No description provided for @videoEditorAudioImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio import failed.'**
  String get videoEditorAudioImportFailed;

  /// No description provided for @videoIconPlaceholderLabel.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoIconPlaceholderLabel;

  /// No description provided for @publishErrorNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to publish videos.'**
  String get publishErrorNotSignedIn;

  /// No description provided for @publishErrorNoRetry.
  ///
  /// In en, this message translates to:
  /// **'No upload to retry.'**
  String get publishErrorNoRetry;

  /// No description provided for @publishErrorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your Wi-Fi or mobile data and try again.'**
  String get publishErrorNoInternet;

  /// No description provided for @publishErrorServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Please try again in a moment.'**
  String get publishErrorServerUnreachable;

  /// No description provided for @publishErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The upload timed out. Try a stronger connection or a smaller video.'**
  String get publishErrorTimeout;

  /// No description provided for @publishErrorTls.
  ///
  /// In en, this message translates to:
  /// **'Secure connection failed. Check your network — public Wi-Fi can block uploads.'**
  String get publishErrorTls;

  /// Shown when the media (Blossom) server returns 404. {serverName} is the server host.
  ///
  /// In en, this message translates to:
  /// **'The media server ({serverName}) is not available. You can choose another in your settings.'**
  String publishErrorServerNotFound(String serverName);

  /// No description provided for @publishErrorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The video file is too large for the server. Try trimming it or lowering the quality.'**
  String get publishErrorFileTooLarge;

  /// Shown when the media (Blossom) server returns 500. {serverName} is the server host.
  ///
  /// In en, this message translates to:
  /// **'The media server ({serverName}) had an internal error. You can choose another in your settings.'**
  String publishErrorServerInternalError(String serverName);

  /// Shown when the media (Blossom) server returns 502/503. {serverName} is the server host.
  ///
  /// In en, this message translates to:
  /// **'The media server ({serverName}) is temporarily down. Try again shortly or choose another in your settings.'**
  String publishErrorServerDown(String serverName);

  /// No description provided for @publishErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don’t have permission to upload to this server.'**
  String get publishErrorForbidden;

  /// No description provided for @publishErrorFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'The video file could not be found. It may have been deleted. Re-record and try again.'**
  String get publishErrorFileNotFound;

  /// No description provided for @publishErrorLowStorage.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage on your device. Free up some space and try again.'**
  String get publishErrorLowStorage;

  /// No description provided for @publishErrorThumbnailFailed.
  ///
  /// In en, this message translates to:
  /// **'The video uploaded, but the thumbnail could not be prepared. Please try again.'**
  String get publishErrorThumbnailFailed;

  /// No description provided for @publishErrorNostrPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'The video uploaded but the post could not be published. Check your relay settings and try again.'**
  String get publishErrorNostrPublishFailed;

  /// Terminal publish error shown when the authoritative Divine relay rejects the signed-in account.
  ///
  /// In en, this message translates to:
  /// **'Your account is restricted, so this post couldn’t be published.'**
  String get publishErrorAccountRestricted;

  /// Button on a restricted-account publish failure that opens Account status instead of retrying.
  ///
  /// In en, this message translates to:
  /// **'View Account Status'**
  String get uploadFailureSheetAccountStatusButton;

  /// No description provided for @publishErrorAudioReuseNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'The video uploaded, but its sound isn\'t cleared for reuse. Pick a different sound to post it.'**
  String get publishErrorAudioReuseNotPermitted;

  /// No description provided for @publishErrorInterrupted.
  ///
  /// In en, this message translates to:
  /// **'This upload was interrupted. Would you like to try again?'**
  String get publishErrorInterrupted;

  /// No description provided for @publishErrorAccountChanged.
  ///
  /// In en, this message translates to:
  /// **'This video belongs to a different account. Switch back to that account to post it.'**
  String get publishErrorAccountChanged;

  /// No description provided for @publishErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get publishErrorGeneric;

  /// No description provided for @publishErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many uploads right now. Wait a moment and try again.'**
  String get publishErrorRateLimited;

  /// No description provided for @publishErrorUploadSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your upload session expired. Please try again.'**
  String get publishErrorUploadSessionExpired;

  /// No description provided for @publishErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Divine doesn’t have permission to upload. Check app permissions in your settings and try again.'**
  String get publishErrorPermissionDenied;

  /// No description provided for @publishErrorOutOfMemory.
  ///
  /// In en, this message translates to:
  /// **'Your device is low on memory. Close some apps and try again.'**
  String get publishErrorOutOfMemory;

  /// No description provided for @publishErrorOverlaysUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The text and stickers on this draft couldn’t be prepared. Open it in the editor, then post again.'**
  String get publishErrorOverlaysUnavailable;

  /// No description provided for @publishErrorUnknownServer.
  ///
  /// In en, this message translates to:
  /// **'Unknown server'**
  String get publishErrorUnknownServer;

  /// No description provided for @searchFilterPillSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter: {filter}'**
  String searchFilterPillSemanticLabel(String filter);

  /// No description provided for @searchNoResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String searchNoResultsFound(String query);

  /// No description provided for @searchTagChipViewVideosTaggedLabel.
  ///
  /// In en, this message translates to:
  /// **'View videos tagged {tag}'**
  String searchTagChipViewVideosTaggedLabel(String tag);

  /// No description provided for @audioAttributionRowSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound: {soundName} by {creatorName}. Tap to view sound details.'**
  String audioAttributionRowSemanticLabel(String soundName, String creatorName);

  /// No description provided for @metadataSoundsOriginalSoundSemantics.
  ///
  /// In en, this message translates to:
  /// **'Original sound by {creatorName}. Tap to use this sound.'**
  String metadataSoundsOriginalSoundSemantics(String creatorName);

  /// No description provided for @metadataSoundsSharedSoundSemantics.
  ///
  /// In en, this message translates to:
  /// **'Sound: {soundName} by {creatorName}. Tap to view details.'**
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  );

  /// No description provided for @soundDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sound. Please try again.'**
  String get soundDetailLoadError;

  /// No description provided for @soundDetailNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This sound could not be found'**
  String get soundDetailNotFoundMessage;

  /// No description provided for @soundDetailNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Sound Not Found'**
  String get soundDetailNotFoundTitle;

  /// No description provided for @videoFeedLoopCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{🔁 {count} loop} other{🔁 {count} loops}}'**
  String videoFeedLoopCountLabel(int count);

  /// No description provided for @originalSoundUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Audio from this video is not available separately.'**
  String get originalSoundUnavailableBody;

  /// No description provided for @originalSoundByCreator.
  ///
  /// In en, this message translates to:
  /// **'Original sound - {creatorName}'**
  String originalSoundByCreator(String creatorName);

  /// No description provided for @ogVinerBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'OG Viner'**
  String get ogVinerBadgeLabel;

  /// Body copy explaining that the OG Viner profile badge identifies original Vine archive participation, not account verification.
  ///
  /// In en, this message translates to:
  /// **'This person posted an original Vine that Divine found in the archive. It is not an account verification badge.'**
  String get profileBadgeOgVinerBody;

  /// Label for the badge marking accounts that tested Divine during the beta. Currently mirrored verbatim into every locale, but 'Beta Tester' is an ordinary noun phrase and translators should adapt it where the target language has one.
  ///
  /// In en, this message translates to:
  /// **'OG Beta Tester'**
  String get ogBetaTesterBadgeLabel;

  /// Body copy explaining that the OG Beta Tester profile badge identifies early beta participation, not account verification.
  ///
  /// In en, this message translates to:
  /// **'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.'**
  String get profileBadgeOgBetaTesterBody;

  /// Title for the dialog explaining the special profile checkmark badge.
  ///
  /// In en, this message translates to:
  /// **'Profile checkmark'**
  String get profileBadgeCheckmarkTitle;

  /// Body copy explaining that the special profile checkmark marks Divine team accounts, not NIP-05, verified-account links, or OG Viner status.
  ///
  /// In en, this message translates to:
  /// **'Divine gives this checkmark to team accounts. It is separate from NIP-05, verified account links, and OG Viner status.'**
  String get profileBadgeCheckmarkBody;

  /// No description provided for @unfollowConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollowConfirmButton;

  /// No description provided for @videoClipSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save clip'**
  String get videoClipSaveFailed;

  /// No description provided for @videoClipSaveTo.
  ///
  /// In en, this message translates to:
  /// **'Save to {destination}'**
  String videoClipSaveTo(String destination);

  /// No description provided for @videoClipDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete clip'**
  String get videoClipDelete;

  /// No description provided for @inspiredByAttributionMultipleSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Inspired by {creatorName} +{additionalCreatorCount}. Tap to view their profile.'**
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  );

  /// No description provided for @inspiredByAttributionSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Inspired by {creatorName}. Tap to view their profile.'**
  String inspiredByAttributionSemanticLabel(String creatorName);

  /// No description provided for @bugReportSendReport.
  ///
  /// In en, this message translates to:
  /// **'Send Report'**
  String get bugReportSendReport;

  /// No description provided for @supportSubjectRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject *'**
  String get supportSubjectRequiredLabel;

  /// No description provided for @supportPublicSubmissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Public GitHub post'**
  String get supportPublicSubmissionTitle;

  /// No description provided for @supportPublicSubmissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Everything you submit here will be posted to our open-source repository on GitHub so developers can pick it up. Your post and the account you\'re signed in with will be publicly visible to everyone.'**
  String get supportPublicSubmissionMessage;

  /// No description provided for @supportRequiredHelper.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get supportRequiredHelper;

  /// Helper shown under a support form field when the user's text hit the character cap and the rest was dropped.
  ///
  /// In en, this message translates to:
  /// **'That\'s the maximum length. Anything past this wasn\'t added.'**
  String get supportFieldLimitReached;

  /// No description provided for @bugReportSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Brief summary of the issue'**
  String get bugReportSubjectHint;

  /// No description provided for @bugReportDescriptionRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'What happened? *'**
  String get bugReportDescriptionRequiredLabel;

  /// No description provided for @bugReportDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue you encountered'**
  String get bugReportDescriptionHint;

  /// No description provided for @bugReportStepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps to Reproduce'**
  String get bugReportStepsLabel;

  /// No description provided for @bugReportStepsHint.
  ///
  /// In en, this message translates to:
  /// **'1. Go to...\n2. Tap on...\n3. See error'**
  String get bugReportStepsHint;

  /// No description provided for @bugReportExpectedBehaviorLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected Behavior'**
  String get bugReportExpectedBehaviorLabel;

  /// No description provided for @bugReportExpectedBehaviorHint.
  ///
  /// In en, this message translates to:
  /// **'What should have happened instead?'**
  String get bugReportExpectedBehaviorHint;

  /// No description provided for @bugReportDiagnosticsNotice.
  ///
  /// In en, this message translates to:
  /// **'Device info and logs will be included automatically.'**
  String get bugReportDiagnosticsNotice;

  /// No description provided for @bugReportSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you! We\'ve received your report and will use it to make Divine better.'**
  String get bugReportSuccessMessage;

  /// No description provided for @bugReportAttachImages.
  ///
  /// In en, this message translates to:
  /// **'Attach images'**
  String get bugReportAttachImages;

  /// No description provided for @bugReportImagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} images selected'**
  String bugReportImagesCount(int count, int max);

  /// No description provided for @bugReportRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get bugReportRemoveImage;

  /// No description provided for @bugReportUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t upload the selected image. Try again or send the report without it.'**
  String get bugReportUploadFailed;

  /// No description provided for @bugReportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send bug report. Please try again later.'**
  String get bugReportSendFailed;

  /// No description provided for @featureRequestSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get featureRequestSendRequest;

  /// No description provided for @featureRequestSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Brief summary of your idea'**
  String get featureRequestSubjectHint;

  /// No description provided for @featureRequestDescriptionRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'What would you like? *'**
  String get featureRequestDescriptionRequiredLabel;

  /// No description provided for @featureRequestDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the feature you want'**
  String get featureRequestDescriptionHint;

  /// No description provided for @featureRequestUsefulnessLabel.
  ///
  /// In en, this message translates to:
  /// **'How would this be useful?'**
  String get featureRequestUsefulnessLabel;

  /// No description provided for @featureRequestUsefulnessHint.
  ///
  /// In en, this message translates to:
  /// **'Explain the benefit this feature would provide'**
  String get featureRequestUsefulnessHint;

  /// No description provided for @featureRequestWhenLabel.
  ///
  /// In en, this message translates to:
  /// **'When would you use this?'**
  String get featureRequestWhenLabel;

  /// No description provided for @featureRequestWhenHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the situations where this would help'**
  String get featureRequestWhenHint;

  /// No description provided for @featureRequestSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you! We\'ve received your feature request and will review it.'**
  String get featureRequestSuccessMessage;

  /// No description provided for @featureRequestSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send feature request. Please try again later.'**
  String get featureRequestSendFailed;

  /// No description provided for @notificationFollowBack.
  ///
  /// In en, this message translates to:
  /// **'Follow back'**
  String get notificationFollowBack;

  /// No description provided for @followingTitle.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingTitle;

  /// No description provided for @followingTitleForName.
  ///
  /// In en, this message translates to:
  /// **'{displayName}\'s Following'**
  String followingTitleForName(String displayName);

  /// No description provided for @followingFailedToLoadList.
  ///
  /// In en, this message translates to:
  /// **'Failed to load following list'**
  String get followingFailedToLoadList;

  /// No description provided for @followingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet'**
  String get followingEmptyTitle;

  /// No description provided for @followersTitle.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followersTitle;

  /// No description provided for @followersTitleForName.
  ///
  /// In en, this message translates to:
  /// **'{displayName}\'s Followers'**
  String followersTitleForName(String displayName);

  /// No description provided for @followersFailedToLoadList.
  ///
  /// In en, this message translates to:
  /// **'Failed to load followers list'**
  String get followersFailedToLoadList;

  /// No description provided for @followersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get followersEmptyTitle;

  /// No description provided for @followersUpdateFollowFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update follow status. Please try again.'**
  String get followersUpdateFollowFailed;

  /// Accessibility label for the app bar button that opens the follower sort options.
  ///
  /// In en, this message translates to:
  /// **'Sort followers'**
  String get followersSortSemanticLabel;

  /// Accessibility label for the app bar button that opens the sort options for the list of people the user follows.
  ///
  /// In en, this message translates to:
  /// **'Sort following'**
  String get followingSortSemanticLabel;

  /// Header of the bottom sheet listing sort options. Shared by the followers and following lists.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get followSortTitle;

  /// Sort option showing the most recent follow at the top of the list. Shared by the followers and following lists.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get followSortNewest;

  /// Sort option showing the longest-standing follow at the top of the list. Shared by the followers and following lists.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get followSortOldest;

  /// No description provided for @newMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessageTitle;

  /// No description provided for @newMessageFindPeople.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get newMessageFindPeople;

  /// No description provided for @newMessageNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts found.\nFollow people to see them here.'**
  String get newMessageNoContacts;

  /// No description provided for @newMessageNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get newMessageNoUsersFound;

  /// No description provided for @hashtagSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search for hashtags'**
  String get hashtagSearchTitle;

  /// No description provided for @hashtagSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover trending topics and content'**
  String get hashtagSearchSubtitle;

  /// No description provided for @hashtagSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No hashtags found for \"{query}\"'**
  String hashtagSearchNoResults(String query);

  /// No description provided for @hashtagSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get hashtagSearchFailed;

  /// No description provided for @userNotAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Account not available'**
  String get userNotAvailableTitle;

  /// No description provided for @userNotAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'This account isn\'t available right now.'**
  String get userNotAvailableBody;

  /// No description provided for @classicVinersTitle.
  ///
  /// In en, this message translates to:
  /// **'OG Viners'**
  String get classicVinersTitle;

  /// No description provided for @blossomFailedToSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings. Please try again.'**
  String get blossomFailedToSaveSettings;

  /// No description provided for @blossomValidServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid server URL (e.g., https://blossom.band)'**
  String get blossomValidServerUrl;

  /// No description provided for @blossomSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Blossom settings saved'**
  String get blossomSettingsSaved;

  /// No description provided for @blossomSaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get blossomSaveTooltip;

  /// No description provided for @blossomAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Blossom'**
  String get blossomAboutTitle;

  /// No description provided for @blossomAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Blossom is a decentralized media storage protocol that allows you to upload videos to any compatible server. By default, videos are uploaded to Divine\'s Blossom server. Enable the option below to use a custom server instead.'**
  String get blossomAboutDescription;

  /// No description provided for @blossomUseCustomServer.
  ///
  /// In en, this message translates to:
  /// **'Use Custom Blossom Server'**
  String get blossomUseCustomServer;

  /// No description provided for @blossomCustomServerEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos will be uploaded to your custom Blossom server'**
  String get blossomCustomServerEnabledSubtitle;

  /// No description provided for @blossomCustomServerDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your videos are currently being uploaded to Divine\'s Blossom server'**
  String get blossomCustomServerDisabledSubtitle;

  /// No description provided for @blossomCustomServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Custom Blossom Server URL'**
  String get blossomCustomServerUrl;

  /// No description provided for @blossomCustomServerHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter the URL of your custom Blossom server'**
  String get blossomCustomServerHelper;

  /// No description provided for @blossomPopularServers.
  ///
  /// In en, this message translates to:
  /// **'Popular Blossom Servers'**
  String get blossomPopularServers;

  /// Snackbar shown when the user typed a non-loopback http:// Blossom server URL. Under release transport security those uploads would silently fail at the OS layer; the validator rejects them with this hint instead.
  ///
  /// In en, this message translates to:
  /// **'Blossom server URL must use https://'**
  String get blossomServerUrlMustUseHttps;

  /// No description provided for @blueskyFailedToUpdateCrosspost.
  ///
  /// In en, this message translates to:
  /// **'Failed to update crosspost setting'**
  String get blueskyFailedToUpdateCrosspost;

  /// No description provided for @blueskySignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage Bluesky settings'**
  String get blueskySignInRequired;

  /// No description provided for @blueskyPublishVideos.
  ///
  /// In en, this message translates to:
  /// **'Publish videos to Bluesky'**
  String get blueskyPublishVideos;

  /// No description provided for @blueskyEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your videos will be published to Bluesky'**
  String get blueskyEnabledSubtitle;

  /// No description provided for @blueskyDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your videos will not be published to Bluesky'**
  String get blueskyDisabledSubtitle;

  /// Title for the Bluesky publishing disclosure explaining historical videos are backfilled when crossposting is enabled.
  ///
  /// In en, this message translates to:
  /// **'Your past videos will post too'**
  String get blueskyBackfillDisclosureTitle;

  /// Body text for the Bluesky publishing disclosure explaining that enabling crossposting starts a historical video backfill.
  ///
  /// In en, this message translates to:
  /// **'When you turn this on, Divine will start sending your older videos to Bluesky, oldest first, without rushing the daily limit.'**
  String get blueskyBackfillDisclosureSubtitle;

  /// No description provided for @blueskyHandle.
  ///
  /// In en, this message translates to:
  /// **'Bluesky Handle'**
  String get blueskyHandle;

  /// Label for the ATProto DID shown when a Bluesky account is provisioned.
  ///
  /// In en, this message translates to:
  /// **'Bluesky DID'**
  String get blueskyDid;

  /// No description provided for @blueskyStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get blueskyStatus;

  /// No description provided for @blueskyStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Account provisioned and ready'**
  String get blueskyStatusReady;

  /// No description provided for @blueskyStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Account provisioning in progress...'**
  String get blueskyStatusPending;

  /// No description provided for @blueskyStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Account provisioning failed'**
  String get blueskyStatusFailed;

  /// No description provided for @blueskyStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Account disabled'**
  String get blueskyStatusDisabled;

  /// No description provided for @blueskyStatusNotLinked.
  ///
  /// In en, this message translates to:
  /// **'No Bluesky account linked'**
  String get blueskyStatusNotLinked;

  /// No description provided for @blueskyUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Set up a divine.video handle before publishing to Bluesky'**
  String get blueskyUsernameRequired;

  /// No description provided for @blueskyUsernameRequiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bluesky publishing needs a claimed username.divine.video handle.'**
  String get blueskyUsernameRequiredSubtitle;

  /// No description provided for @blueskyUsernameSyncPending.
  ///
  /// In en, this message translates to:
  /// **'Your Divine handle is claimed. We are linking it to Bluesky - try again in a moment.'**
  String get blueskyUsernameSyncPending;

  /// No description provided for @blueskyStatusUnavailableRetry.
  ///
  /// In en, this message translates to:
  /// **'We could not check your Divine handle. Try again.'**
  String get blueskyStatusUnavailableRetry;

  /// No description provided for @blueskySetUpHandle.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get blueskySetUpHandle;

  /// No description provided for @blueskyTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bluesky publishing is temporarily unavailable. Please try again.'**
  String get blueskyTemporarilyUnavailable;

  /// No description provided for @invitesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends'**
  String get invitesTitle;

  /// Title of the generate-invite card on the invites screen, shown when the user has invite capacity that has not been generated as codes yet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 invite ready to generate} other{{count} invites ready to generate}}'**
  String invitesGenerateCardTitle(int count);

  /// Body text on the generate-invite card explaining what tapping the button does.
  ///
  /// In en, this message translates to:
  /// **'Generate a code when you are ready to share one.'**
  String get invitesGenerateCardSubtitle;

  /// Label of the button on the generate-invite card that creates a new invite code from remaining capacity.
  ///
  /// In en, this message translates to:
  /// **'Generate invite'**
  String get invitesGenerateButtonLabel;

  /// No description provided for @invitesNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No invites available right now'**
  String get invitesNoneAvailable;

  /// No description provided for @invitesShareWithPeople.
  ///
  /// In en, this message translates to:
  /// **'Share Divine with people you know'**
  String get invitesShareWithPeople;

  /// No description provided for @invitesUsedInvites.
  ///
  /// In en, this message translates to:
  /// **'Used invites'**
  String get invitesUsedInvites;

  /// No description provided for @invitesShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Join me on Divine! Use invite code {code} to get started:\nhttps://divine.video/invite/{code}'**
  String invitesShareMessage(String code);

  /// No description provided for @invitesCopyInvite.
  ///
  /// In en, this message translates to:
  /// **'Copy invite'**
  String get invitesCopyInvite;

  /// No description provided for @invitesCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite copied!'**
  String get invitesCopied;

  /// No description provided for @invitesShareInvite.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get invitesShareInvite;

  /// No description provided for @invitesShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Join me on Divine'**
  String get invitesShareSubject;

  /// No description provided for @invitesClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get invitesClaimed;

  /// No description provided for @invitesCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load invites'**
  String get invitesCouldNotLoad;

  /// No description provided for @invitesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get invitesRetry;

  /// No description provided for @searchSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get searchSomethingWentWrong;

  /// No description provided for @searchTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get searchTryAgain;

  /// No description provided for @searchForLists.
  ///
  /// In en, this message translates to:
  /// **'Search for lists'**
  String get searchForLists;

  /// No description provided for @searchFindCuratedVideoLists.
  ///
  /// In en, this message translates to:
  /// **'Find curated video lists'**
  String get searchFindCuratedVideoLists;

  /// Title of the empty-query placeholder shown on the search results screen before the user has entered a query.
  ///
  /// In en, this message translates to:
  /// **'Enter a search query'**
  String get searchEnterQuery;

  /// Subtitle of the empty-query placeholder shown on the search results screen before the user has entered a query.
  ///
  /// In en, this message translates to:
  /// **'Discover something interesting'**
  String get searchDiscoverSomethingInteresting;

  /// No description provided for @searchPeopleSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchPeopleSectionHeader;

  /// No description provided for @searchPeopleLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading people results'**
  String get searchPeopleLoadingLabel;

  /// No description provided for @searchTagsSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get searchTagsSectionHeader;

  /// No description provided for @searchTagsLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading tag results'**
  String get searchTagsLoadingLabel;

  /// No description provided for @searchVideosSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get searchVideosSectionHeader;

  /// No description provided for @searchVideosLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading video results'**
  String get searchVideosLoadingLabel;

  /// No description provided for @searchVideosSortOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort video results'**
  String get searchVideosSortOptionsLabel;

  /// Label for the video search sort option that shows currently popular or trending results.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get searchVideosSortTrending;

  /// Label for the video search sort option that ranks results by loop count.
  ///
  /// In en, this message translates to:
  /// **'Most loops'**
  String get searchVideosSortLoops;

  /// Label for the video search sort option that ranks results by engagement.
  ///
  /// In en, this message translates to:
  /// **'Most engaged'**
  String get searchVideosSortEngagement;

  /// Label for the video search sort option that shows the newest results first.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get searchVideosSortRecent;

  /// No description provided for @searchListsSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get searchListsSectionHeader;

  /// No description provided for @searchListsLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading list results'**
  String get searchListsLoadingLabel;

  /// No description provided for @cameraAgeRestriction.
  ///
  /// In en, this message translates to:
  /// **'You must be 16 or older to create content'**
  String get cameraAgeRestriction;

  /// Shown when a pasted bunker:// or nostrconnect:// URL contains a relay parameter that uses cleartext ws:// for a non-loopback host.
  ///
  /// In en, this message translates to:
  /// **'Bunker relay must use wss:// (ws:// is allowed only for localhost)'**
  String get keyImportInsecureBunkerRelay;

  /// Relative time label for less than one minute ago (short form)
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// Short relative time in minutes, e.g. 3m
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String timeShortMinutes(int count);

  /// Short relative time in hours, e.g. 2h
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String timeShortHours(int count);

  /// Short relative time in days, e.g. 3d
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String timeShortDays(int count);

  /// Short relative time in weeks, e.g. 2w
  ///
  /// In en, this message translates to:
  /// **'{count}w'**
  String timeShortWeeks(int count);

  /// Short relative time in months, e.g. 1mo
  ///
  /// In en, this message translates to:
  /// **'{count}mo'**
  String timeShortMonths(int count);

  /// Short relative time in years, e.g. 1y
  ///
  /// In en, this message translates to:
  /// **'{count}y'**
  String timeShortYears(int count);

  /// Verbose relative time label for less than one minute ago
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get timeVerboseNow;

  /// Verbose relative time with ago suffix, e.g. 3m ago
  ///
  /// In en, this message translates to:
  /// **'{time} ago'**
  String timeAgo(String time);

  /// Date label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get timeToday;

  /// Date label for yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// Verbose relative time for less than one minute (lowercase)
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// Relative time in minutes with ago suffix
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String timeMinutesAgo(int count);

  /// Relative time in hours with ago suffix
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeHoursAgo(int count);

  /// Relative time in days with ago suffix
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeDaysAgo(int count);

  /// Draft age label for less than one minute (capitalized)
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get draftTimeJustNow;

  /// No description provided for @contentLabelNudity.
  ///
  /// In en, this message translates to:
  /// **'Nudity'**
  String get contentLabelNudity;

  /// No description provided for @contentLabelSexualContent.
  ///
  /// In en, this message translates to:
  /// **'Sexual Content'**
  String get contentLabelSexualContent;

  /// No description provided for @contentLabelPornography.
  ///
  /// In en, this message translates to:
  /// **'Pornography'**
  String get contentLabelPornography;

  /// No description provided for @contentLabelGraphicMedia.
  ///
  /// In en, this message translates to:
  /// **'Graphic Media'**
  String get contentLabelGraphicMedia;

  /// No description provided for @contentLabelViolence.
  ///
  /// In en, this message translates to:
  /// **'Violence'**
  String get contentLabelViolence;

  /// No description provided for @contentLabelSelfHarm.
  ///
  /// In en, this message translates to:
  /// **'Self-Harm/Suicide'**
  String get contentLabelSelfHarm;

  /// No description provided for @contentLabelDrugUse.
  ///
  /// In en, this message translates to:
  /// **'Drug Use'**
  String get contentLabelDrugUse;

  /// No description provided for @contentLabelAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Alcohol'**
  String get contentLabelAlcohol;

  /// No description provided for @contentLabelTobacco.
  ///
  /// In en, this message translates to:
  /// **'Tobacco/Smoking'**
  String get contentLabelTobacco;

  /// No description provided for @contentLabelGambling.
  ///
  /// In en, this message translates to:
  /// **'Gambling'**
  String get contentLabelGambling;

  /// No description provided for @contentLabelProfanity.
  ///
  /// In en, this message translates to:
  /// **'Profanity'**
  String get contentLabelProfanity;

  /// No description provided for @contentLabelHateSpeech.
  ///
  /// In en, this message translates to:
  /// **'Hate Speech'**
  String get contentLabelHateSpeech;

  /// No description provided for @contentLabelHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get contentLabelHarassment;

  /// No description provided for @contentLabelFlashingLights.
  ///
  /// In en, this message translates to:
  /// **'Flashing Lights'**
  String get contentLabelFlashingLights;

  /// No description provided for @contentLabelAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI-Generated'**
  String get contentLabelAiGenerated;

  /// No description provided for @contentLabelDeepfake.
  ///
  /// In en, this message translates to:
  /// **'Deepfake'**
  String get contentLabelDeepfake;

  /// No description provided for @contentLabelSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get contentLabelSpam;

  /// No description provided for @contentLabelScam.
  ///
  /// In en, this message translates to:
  /// **'Scam/Fraud'**
  String get contentLabelScam;

  /// No description provided for @contentLabelSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get contentLabelSpoiler;

  /// No description provided for @contentLabelMisleading.
  ///
  /// In en, this message translates to:
  /// **'Misleading'**
  String get contentLabelMisleading;

  /// No description provided for @contentLabelSensitiveContent.
  ///
  /// In en, this message translates to:
  /// **'Sensitive Content'**
  String get contentLabelSensitiveContent;

  /// No description provided for @notificationLikedYourVideo.
  ///
  /// In en, this message translates to:
  /// **'{actorName} liked your video'**
  String notificationLikedYourVideo(String actorName);

  /// Notification text when someone reacts to a comment the user posted (typically under another user's video).
  ///
  /// In en, this message translates to:
  /// **'{actorName} liked your comment'**
  String notificationLikedYourComment(String actorName);

  /// No description provided for @notificationCommentedOnYourVideo.
  ///
  /// In en, this message translates to:
  /// **'{actorName} commented on your video'**
  String notificationCommentedOnYourVideo(String actorName);

  /// No description provided for @notificationStartedFollowing.
  ///
  /// In en, this message translates to:
  /// **'{actorName} started following you'**
  String notificationStartedFollowing(String actorName);

  /// No description provided for @notificationMentionedYou.
  ///
  /// In en, this message translates to:
  /// **'{actorName} mentioned you'**
  String notificationMentionedYou(String actorName);

  /// No description provided for @notificationRepostedYourVideo.
  ///
  /// In en, this message translates to:
  /// **'{actorName} reposted your video'**
  String notificationRepostedYourVideo(String actorName);

  /// Shown when a creator the user subscribed to (belled) publishes a new video. Unlike the other notification verbs this is not a reaction to the user's own content.
  ///
  /// In en, this message translates to:
  /// **'{actorName} posted a new vine'**
  String notificationPostedNewVine(String actorName);

  /// Shown when someone adds the user's videos to a public curated list. Uses an ICU plural so locales with more than two plural categories can inflect correctly.
  ///
  /// In en, this message translates to:
  /// **'{actorName} added {count, plural, =1{your vine} other{{count} of your vines}} to {listName}'**
  String notificationAddedYourVideosToList(
    String actorName,
    int count,
    String listName,
  );

  /// Full sentence shown for a reply notification.
  ///
  /// In en, this message translates to:
  /// **'{actorName} replied to your comment'**
  String notificationRepliedToYourComment(String actorName);

  /// Connector word between the first actor and the 'N others' count in a grouped notification (e.g. 'Alice and 3 others liked your video').
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get notificationAndConnector;

  /// Number of additional actors beyond the first in a grouped notification.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 other} other{{count} others}}'**
  String notificationOthersCount(int count);

  /// Default body text for a system notification row when no actor is associated with it (e.g. an app-level update or announcement).
  ///
  /// In en, this message translates to:
  /// **'You have a new update'**
  String get notificationSystemUpdate;

  /// Short prefix shown before a replied-to username (e.g. 'Re: alice'). Used in the orphaned-reply chip on a comment item and above the comment input when actively replying.
  ///
  /// In en, this message translates to:
  /// **'Re:'**
  String get commentReplyToPrefix;

  /// Accessibility label for the comment input control that dismisses the keyboard.
  ///
  /// In en, this message translates to:
  /// **'Hide keyboard'**
  String get commentHideKeyboard;

  /// Snackbar shown when the comments bottom sheet cannot fetch its list of comments from relays.
  ///
  /// In en, this message translates to:
  /// **'Failed to load comments'**
  String get commentsErrorLoadFailed;

  /// Snackbar shown when an unauthenticated user attempts to post a comment, reply, or edit.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to comment'**
  String get commentsErrorNotAuthenticatedComment;

  /// Snackbar shown when publishing a new top-level comment fails after the optimistic placeholder.
  ///
  /// In en, this message translates to:
  /// **'Failed to post comment'**
  String get commentsErrorPostCommentFailed;

  /// Snackbar shown when publishing a reply to a comment fails after the optimistic placeholder.
  ///
  /// In en, this message translates to:
  /// **'Failed to post reply'**
  String get commentsErrorPostReplyFailed;

  /// Snackbar shown when the delete+repost flow that backs comment editing fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to edit comment'**
  String get commentsErrorEditFailed;

  /// Snackbar shown when an unauthenticated user attempts to vote / report / block / delete a comment.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to interact'**
  String get commentsErrorNotAuthenticatedInteract;

  /// Snackbar shown when up/down-voting a comment fails to publish to the relay.
  ///
  /// In en, this message translates to:
  /// **'Failed to vote on comment'**
  String get commentsErrorVoteFailed;

  /// Snackbar shown when submitting an NIP-56 comment report fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to report comment'**
  String get commentsErrorReportFailed;

  /// Snackbar shown when blocking a comment author (kind-30000 mute list publish) fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to block user'**
  String get commentsErrorBlockFailed;

  /// Snackbar shown when deleting one of the user's own comments fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete comment'**
  String get commentsErrorDeleteFailed;

  /// Header above the comments list showing the total comment count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} Comment} other{{count} Comments}}'**
  String commentsHeaderCount(int count);

  /// Short status shown on the placeholder tile while a recorded video reply is uploading and publishing.
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get commentsVideoReplyPending;

  /// Screen-reader label for the pending video-reply row in the comments sheet.
  ///
  /// In en, this message translates to:
  /// **'Your video reply is posting'**
  String get commentsVideoReplyPendingSemanticLabel;

  /// Comments-sort toggle label for newest-first order.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commentsSortNew;

  /// Comments-sort toggle label for engagement-weighted order.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get commentsSortTop;

  /// Comments-sort toggle label for oldest-first order.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get commentsSortOld;

  /// Accessibility label for the comments-sort toggle group.
  ///
  /// In en, this message translates to:
  /// **'Comments sorting'**
  String get commentsSortSemanticLabel;

  /// Button label under a comment that opens the reply composer.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commentReply;

  /// Accessibility label for the reply button under a comment.
  ///
  /// In en, this message translates to:
  /// **'Reply to comment'**
  String get commentReplySemanticLabel;

  /// Accessibility label announced when the upvote button is not currently active.
  ///
  /// In en, this message translates to:
  /// **'Upvote comment'**
  String get commentUpvoteLabel;

  /// Accessibility label announced when the upvote button is currently active and tapping it would clear the vote.
  ///
  /// In en, this message translates to:
  /// **'Remove upvote'**
  String get commentRemoveUpvoteLabel;

  /// Accessibility label announced when the downvote button is not currently active.
  ///
  /// In en, this message translates to:
  /// **'Downvote comment'**
  String get commentDownvoteLabel;

  /// Accessibility label announced when the downvote button is currently active and tapping it would clear the vote.
  ///
  /// In en, this message translates to:
  /// **'Remove downvote'**
  String get commentRemoveDownvoteLabel;

  /// Placeholder shown in the comments composer text field when posting a new comment or reply.
  ///
  /// In en, this message translates to:
  /// **'Add comment...'**
  String get commentsInputHint;

  /// Placeholder shown in the comments composer text field when editing an existing comment.
  ///
  /// In en, this message translates to:
  /// **'Edit comment...'**
  String get commentsInputHintEdit;

  /// Empty state title shown in the comments sheet when a video has no comments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get commentsEmptyTitle;

  /// Empty state encouragement shown below the no-comments title, prompting the viewer to post the first comment.
  ///
  /// In en, this message translates to:
  /// **'Get the party started!'**
  String get commentsEmptySubtitle;

  /// No description provided for @draftUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get draftUntitled;

  /// No description provided for @contentWarningNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get contentWarningNone;

  /// No description provided for @textBackgroundNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get textBackgroundNone;

  /// No description provided for @textBackgroundSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get textBackgroundSolid;

  /// No description provided for @textBackgroundHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get textBackgroundHighlight;

  /// No description provided for @textBackgroundTransparent.
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get textBackgroundTransparent;

  /// No description provided for @textAlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get textAlignLeft;

  /// No description provided for @textAlignRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get textAlignRight;

  /// No description provided for @textAlignCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get textAlignCenter;

  /// No description provided for @cameraPermissionWebUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera not supported on web yet'**
  String get cameraPermissionWebUnsupportedTitle;

  /// No description provided for @cameraPermissionWebUnsupportedDescription.
  ///
  /// In en, this message translates to:
  /// **'Camera capture and recording are not available in the web version yet.'**
  String get cameraPermissionWebUnsupportedDescription;

  /// No description provided for @cameraPermissionBackToFeed.
  ///
  /// In en, this message translates to:
  /// **'Back to feed'**
  String get cameraPermissionBackToFeed;

  /// Shown in the camera preview placeholder when the camera fails to initialize.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the camera'**
  String get cameraCouldNotStart;

  /// Shown in the camera preview placeholder on platforms with no camera support at all (currently Linux), where retrying cannot help.
  ///
  /// In en, this message translates to:
  /// **'The camera is not available on this platform yet.\nYou can still browse and watch videos.'**
  String get cameraUnsupportedPlatform;

  /// No description provided for @cameraPermissionErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Error'**
  String get cameraPermissionErrorTitle;

  /// No description provided for @cameraPermissionErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while checking permissions.'**
  String get cameraPermissionErrorDescription;

  /// No description provided for @cameraPermissionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get cameraPermissionRetry;

  /// No description provided for @cameraPermissionAllowAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow camera & microphone access'**
  String get cameraPermissionAllowAccessTitle;

  /// No description provided for @cameraPermissionAllowAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'This allows you to capture and edit videos right here in the app, nothing more.'**
  String get cameraPermissionAllowAccessDescription;

  /// No description provided for @cameraPermissionGoToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to settings'**
  String get cameraPermissionGoToSettings;

  /// No description provided for @videoRecorderWhySixSecondsTitle.
  ///
  /// In en, this message translates to:
  /// **'Why six seconds?'**
  String get videoRecorderWhySixSecondsTitle;

  /// No description provided for @videoRecorderWhySixSecondsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick clips make space for spontaneity. The 6-second format helps you capture authentic moments as they happen.'**
  String get videoRecorderWhySixSecondsSubtitle;

  /// No description provided for @videoRecorderWhySixSecondsButton.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get videoRecorderWhySixSecondsButton;

  /// Headline on the camera Upload mode explainer panel. Phrased as the question the user is implicitly asking by tapping the Upload tab.
  ///
  /// In en, this message translates to:
  /// **'Why no upload?'**
  String get videoRecorderUploadTitle;

  /// First body paragraph on the Upload explainer. States the camera-direct mission and contrasts with platforms that allow produced or AI-generated uploads.
  ///
  /// In en, this message translates to:
  /// **'What you see on Divine is human-made: raw and captured in the moment. Unlike platforms that allow highly produced or AI-generated uploads, we prioritize the authenticity of the camera-direct experience.'**
  String get videoRecorderUploadBody;

  /// Second body paragraph on the Upload explainer. Explains why keeping creation in-app supports the realness goal. Note the deliberate hedges 'better guarantee' and 'as much as we can' — do not strengthen these claims.
  ///
  /// In en, this message translates to:
  /// **'By keeping creation inside the app, we can better guarantee that content is real and unedited. We aren\'t opening up external gallery uploads at this time to protect that realness and keep our community free of synthetic content as much as we can.'**
  String get videoRecorderUploadBodyDetail;

  /// Closing line on the Upload explainer pointing the user back to the Capture and Classic recording modes.
  ///
  /// In en, this message translates to:
  /// **'Switch to Capture or Classic to roll something real.'**
  String get videoRecorderUploadBodyCta;

  /// Outbound link label that opens divine.video/proofmode in the browser.
  ///
  /// In en, this message translates to:
  /// **'Learn how verification works'**
  String get videoRecorderUploadLearnMore;

  /// No description provided for @videoRecorderAutosaveFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'We found work in progress'**
  String get videoRecorderAutosaveFoundTitle;

  /// No description provided for @videoRecorderAutosaveFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Would you like to continue where you left off?'**
  String get videoRecorderAutosaveFoundSubtitle;

  /// No description provided for @videoRecorderAutosaveContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Yes, continue'**
  String get videoRecorderAutosaveContinueButton;

  /// No description provided for @videoRecorderAutosaveDiscardButton.
  ///
  /// In en, this message translates to:
  /// **'No, start a new video'**
  String get videoRecorderAutosaveDiscardButton;

  /// No description provided for @videoRecorderAutosaveRestoreFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not restore your draft'**
  String get videoRecorderAutosaveRestoreFailure;

  /// No description provided for @videoRecorderStopRecordingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get videoRecorderStopRecordingTooltip;

  /// No description provided for @videoRecorderStartRecordingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get videoRecorderStartRecordingTooltip;

  /// No description provided for @videoRecorderRecordingTapToStopLabel.
  ///
  /// In en, this message translates to:
  /// **'Recording. Tap anywhere to stop'**
  String get videoRecorderRecordingTapToStopLabel;

  /// No description provided for @videoRecorderTapToStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to start recording'**
  String get videoRecorderTapToStartLabel;

  /// No description provided for @videoRecorderDeleteLastClipLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete last clip'**
  String get videoRecorderDeleteLastClipLabel;

  /// No description provided for @videoRecorderSwitchCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get videoRecorderSwitchCameraLabel;

  /// Accessibility label for the transient camera zoom ruler shown while pinch-zooming. {zoom} is a zoom factor like 0.5, 1, or 2.
  ///
  /// In en, this message translates to:
  /// **'Zoom to {zoom}×'**
  String videoRecorderZoomLevelLabel(String zoom);

  /// No description provided for @videoRecorderToggleGridLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle grid'**
  String get videoRecorderToggleGridLabel;

  /// No description provided for @videoRecorderToggleGhostFrameLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle ghost frame'**
  String get videoRecorderToggleGhostFrameLabel;

  /// No description provided for @videoRecorderGhostFrameEnabled.
  ///
  /// In en, this message translates to:
  /// **'Ghost frame enabled'**
  String get videoRecorderGhostFrameEnabled;

  /// No description provided for @videoRecorderGhostFrameDisabled.
  ///
  /// In en, this message translates to:
  /// **'Ghost frame disabled'**
  String get videoRecorderGhostFrameDisabled;

  /// No description provided for @videoRecorderClipDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Clip moved to trash'**
  String get videoRecorderClipDeletedMessage;

  /// Action button on the 'Clip moved to trash' snackbar shown after the user deletes the last recorded clip. Tapping it restores the clip to its original position in the recording tray.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get videoRecorderClipUndoLabel;

  /// Empty-state title shown in the clip trash bin when there are no recently deleted clips.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get libraryTrashEmptyTitle;

  /// Empty-state subtitle explaining the 30-day clip trash retention.
  ///
  /// In en, this message translates to:
  /// **'Deleted clips live here for 30 days before being removed for good.'**
  String get libraryTrashEmptySubtitle;

  /// Button on a trashed clip that restores it back to the active library.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get libraryTrashRestoreLabel;

  /// Button on a trashed clip that skips the retention window and permanently deletes it immediately.
  ///
  /// In en, this message translates to:
  /// **'Delete now'**
  String get libraryTrashDeleteNowLabel;

  /// Button that permanently deletes every clip currently in trash.
  ///
  /// In en, this message translates to:
  /// **'Empty trash'**
  String get libraryTrashEmptyAllLabel;

  /// Confirmation-sheet title shown before permanently deleting a single clip from trash.
  ///
  /// In en, this message translates to:
  /// **'Delete clip now?'**
  String get libraryTrashDeleteConfirmTitle;

  /// Confirmation-sheet subtitle shown before permanently deleting a single clip from trash.
  ///
  /// In en, this message translates to:
  /// **'This removes the clip from trash right away.'**
  String get libraryTrashDeleteConfirmMessage;

  /// Confirmation-sheet title shown before permanently deleting every clip from trash.
  ///
  /// In en, this message translates to:
  /// **'Empty trash?'**
  String get libraryTrashEmptyConfirmTitle;

  /// Confirmation-sheet subtitle shown before permanently deleting every clip from trash.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes {count, plural, =1{1 clip} other{{count} clips}} from trash right away.'**
  String libraryTrashEmptyConfirmMessage(int count);

  /// No description provided for @videoRecorderCloseLabel.
  ///
  /// In en, this message translates to:
  /// **'Close video recorder'**
  String get videoRecorderCloseLabel;

  /// No description provided for @videoRecorderContinueToEditorLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue to video editor'**
  String get videoRecorderContinueToEditorLabel;

  /// Accessibility label for the live camera viewfinder when tap-to-focus is enabled.
  ///
  /// In en, this message translates to:
  /// **'Camera preview'**
  String get videoRecorderCameraPreviewLabel;

  /// Accessibility tap-action hint for the live camera viewfinder. Screen readers add their own activation instruction.
  ///
  /// In en, this message translates to:
  /// **'Focus camera'**
  String get videoRecorderCameraPreviewFocusHint;

  /// Accessibility label for an unselected video recorder mode. Announces the result of activating the mode selector.
  ///
  /// In en, this message translates to:
  /// **'Switch to {mode} mode'**
  String videoRecorderSwitchToModeLabel(String mode);

  /// Snackbar shown when the user taps the record button in lip-sync mode without first selecting a sound.
  ///
  /// In en, this message translates to:
  /// **'Add audio before recording'**
  String get videoRecorderLipSyncAddAudioFirst;

  /// Snackbar shown when assembling captured stop-motion frames into a video failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the video. Try again.'**
  String get videoRecorderStopMotionAssembleFailed;

  /// Label above the stop-motion budget bar in the recorder top bar, counting how many more stills fit in the maximum clip length.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No shots left} =1{1 shot left} other{{count} shots left}}'**
  String videoRecorderStopMotionShotsLeft(int count);

  /// No description provided for @videoRecorderToggleFlashLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle flash'**
  String get videoRecorderToggleFlashLabel;

  /// No description provided for @videoRecorderCycleTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Cycle timer'**
  String get videoRecorderCycleTimerLabel;

  /// No description provided for @videoRecorderToggleAspectRatioLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle aspect ratio'**
  String get videoRecorderToggleAspectRatioLabel;

  /// No description provided for @videoRecorderStabilizationLabel.
  ///
  /// In en, this message translates to:
  /// **'Stabilization'**
  String get videoRecorderStabilizationLabel;

  /// No description provided for @videoRecorderStabilizationModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get videoRecorderStabilizationModeOff;

  /// No description provided for @videoRecorderStabilizationModeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get videoRecorderStabilizationModeStandard;

  /// No description provided for @videoRecorderStabilizationModeCinematic.
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get videoRecorderStabilizationModeCinematic;

  /// No description provided for @videoRecorderStabilizationModeCinematicExtended.
  ///
  /// In en, this message translates to:
  /// **'Cinematic Extended'**
  String get videoRecorderStabilizationModeCinematicExtended;

  /// No description provided for @videoRecorderStabilizationModePreviewOptimized.
  ///
  /// In en, this message translates to:
  /// **'Preview Optimized'**
  String get videoRecorderStabilizationModePreviewOptimized;

  /// No description provided for @videoRecorderStabilizationModeLowLatency.
  ///
  /// In en, this message translates to:
  /// **'Low Latency'**
  String get videoRecorderStabilizationModeLowLatency;

  /// No description provided for @videoRecorderStabilizationModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get videoRecorderStabilizationModeAuto;

  /// Screen-reader state of the recorder's flash button when flash is off. Announced after the button label, e.g. 'Toggle flash, Off'.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get videoRecorderFlashValueOff;

  /// Screen-reader state of the recorder's flash button when the light stays on (torch). Announced after the button label.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get videoRecorderFlashValueOn;

  /// Screen-reader state of the recorder's flash button when the camera decides whether to fire the flash. Announced after the button label.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get videoRecorderFlashValueAuto;

  /// Screen-reader state of the recorder's countdown-timer button when no delay is set. Announced after the button label, e.g. 'Cycle timer, Off'.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get videoRecorderTimerValueOff;

  /// Screen-reader state of the recorder's countdown-timer button when recording starts after a 3 second delay.
  ///
  /// In en, this message translates to:
  /// **'3 seconds'**
  String get videoRecorderTimerValueThreeSeconds;

  /// Screen-reader state of the recorder's countdown-timer button when recording starts after a 10 second delay.
  ///
  /// In en, this message translates to:
  /// **'10 seconds'**
  String get videoRecorderTimerValueTenSeconds;

  /// Screen-reader state of the recorder's aspect-ratio button when recording in 1:1. Announced after the button label.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get videoRecorderAspectRatioValueSquare;

  /// Screen-reader state of the recorder's aspect-ratio button when recording in 9:16. Announced after the button label.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get videoRecorderAspectRatioValueVertical;

  /// Screen-reader state of the recorder's switch-camera button while the selfie camera is active. Announced after the button label.
  ///
  /// In en, this message translates to:
  /// **'Front camera'**
  String get videoRecorderCameraValueFront;

  /// Screen-reader state of the recorder's switch-camera button while the rear camera is active. Announced after the button label.
  ///
  /// In en, this message translates to:
  /// **'Back camera'**
  String get videoRecorderCameraValueBack;

  /// No description provided for @videoRecorderLibraryEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'Clip library, no clips'**
  String get videoRecorderLibraryEmptyLabel;

  /// No description provided for @videoRecorderLibraryOpenLabel.
  ///
  /// In en, this message translates to:
  /// **'{clipCount, plural, one{Open clip library, 1 clip} other{Open clip library, {clipCount} clips}}'**
  String videoRecorderLibraryOpenLabel(int clipCount);

  /// Screen-reader label for the recorder's library button during a stop-motion session. The count is captured stills (frames), not clips. The zero case covers opening a previous session's library before the first still of this one is shot.
  ///
  /// In en, this message translates to:
  /// **'{frameCount, plural, =0{Open stop-motion library} one{Open stop-motion library, 1 frame} other{Open stop-motion library, {frameCount} frames}}'**
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount);

  /// No description provided for @videoEditorCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get videoEditorCameraLabel;

  /// No description provided for @videoEditorOpenCameraSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get videoEditorOpenCameraSemanticLabel;

  /// No description provided for @videoEditorLibraryLabel.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get videoEditorLibraryLabel;

  /// No description provided for @videoEditorTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get videoEditorTextLabel;

  /// No description provided for @videoEditorDrawLabel.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get videoEditorDrawLabel;

  /// No description provided for @videoEditorFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get videoEditorFilterLabel;

  /// No description provided for @videoEditorTuneLabel.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get videoEditorTuneLabel;

  /// No description provided for @videoEditorOpenTuneSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open adjustments editor'**
  String get videoEditorOpenTuneSemanticLabel;

  /// No description provided for @videoEditorTuneBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get videoEditorTuneBrightness;

  /// No description provided for @videoEditorTuneContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get videoEditorTuneContrast;

  /// No description provided for @videoEditorTuneSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get videoEditorTuneSaturation;

  /// No description provided for @videoEditorTuneExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get videoEditorTuneExposure;

  /// No description provided for @videoEditorTuneHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get videoEditorTuneHue;

  /// No description provided for @videoEditorTuneTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get videoEditorTuneTemperature;

  /// No description provided for @videoEditorTuneTint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get videoEditorTuneTint;

  /// No description provided for @videoEditorTuneFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get videoEditorTuneFade;

  /// No description provided for @videoEditorAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get videoEditorAudioLabel;

  /// No description provided for @videoEditorAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get videoEditorAddTitle;

  /// No description provided for @videoEditorOpenLibrarySemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open Library'**
  String get videoEditorOpenLibrarySemanticLabel;

  /// No description provided for @videoEditorOpenAudioSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open audio editor'**
  String get videoEditorOpenAudioSemanticLabel;

  /// No description provided for @videoEditorCaptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get videoEditorCaptionsLabel;

  /// No description provided for @videoEditorOpenCaptionsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open captions editor'**
  String get videoEditorOpenCaptionsSemanticLabel;

  /// Checkbox label in the captions sheet to additionally burn the captions into the exported video (closed captions are always published).
  ///
  /// In en, this message translates to:
  /// **'Burn into video'**
  String get videoEditorCaptionsBurnInLabel;

  /// No description provided for @videoEditorCaptionsPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get videoEditorCaptionsPresetCustom;

  /// No description provided for @videoEditorCaptionsCustomStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom style'**
  String get videoEditorCaptionsCustomStyleTitle;

  /// No description provided for @videoEditorCaptionsCustomApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get videoEditorCaptionsCustomApply;

  /// No description provided for @videoEditorCaptionsCustomFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get videoEditorCaptionsCustomFont;

  /// No description provided for @videoEditorCaptionsCustomTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get videoEditorCaptionsCustomTextColor;

  /// No description provided for @videoEditorCaptionsCustomBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get videoEditorCaptionsCustomBackground;

  /// No description provided for @videoEditorCaptionsCustomBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get videoEditorCaptionsCustomBackgroundColor;

  /// No description provided for @videoEditorCaptionsCustomAnimation.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get videoEditorCaptionsCustomAnimation;

  /// No description provided for @videoEditorCaptionsAnimationNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get videoEditorCaptionsAnimationNone;

  /// No description provided for @videoEditorCaptionsAnimationFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get videoEditorCaptionsAnimationFade;

  /// No description provided for @videoEditorCaptionsAnimationPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get videoEditorCaptionsAnimationPop;

  /// No description provided for @videoEditorCaptionsAnimationSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get videoEditorCaptionsAnimationSpring;

  /// No description provided for @videoEditorCaptionsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get videoEditorCaptionsEditTitle;

  /// No description provided for @videoEditorCaptionsGeneratingTitle.
  ///
  /// In en, this message translates to:
  /// **'Listening for speech…'**
  String get videoEditorCaptionsGeneratingTitle;

  /// No description provided for @videoEditorCaptionsGeneratingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turning your audio into caption suggestions.'**
  String get videoEditorCaptionsGeneratingSubtitle;

  /// No description provided for @videoEditorCaptionsNoSpeechMessage.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t hear any speech. You can still write captions yourself.'**
  String get videoEditorCaptionsNoSpeechMessage;

  /// No description provided for @videoEditorCaptionsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition isn\'t available on this device. You can write captions yourself.'**
  String get videoEditorCaptionsUnavailableMessage;

  /// No description provided for @videoEditorCaptionsNotAuthorizedMessage.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition isn\'t allowed. Enable it in Settings or write captions yourself.'**
  String get videoEditorCaptionsNotAuthorizedMessage;

  /// No description provided for @videoEditorCaptionsFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Transcription didn\'t work this time. You can write captions yourself.'**
  String get videoEditorCaptionsFailedMessage;

  /// No description provided for @videoEditorCaptionsStartEmptyButton.
  ///
  /// In en, this message translates to:
  /// **'Write captions myself'**
  String get videoEditorCaptionsStartEmptyButton;

  /// No description provided for @videoEditorCaptionsAddCue.
  ///
  /// In en, this message translates to:
  /// **'Add caption'**
  String get videoEditorCaptionsAddCue;

  /// No description provided for @videoEditorCaptionsCueTextHint.
  ///
  /// In en, this message translates to:
  /// **'Caption text'**
  String get videoEditorCaptionsCueTextHint;

  /// No description provided for @videoEditorCaptionsCueDeleteSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete caption'**
  String get videoEditorCaptionsCueDeleteSemanticLabel;

  /// No description provided for @videoEditorCaptionsDeleteTrack.
  ///
  /// In en, this message translates to:
  /// **'Remove all captions'**
  String get videoEditorCaptionsDeleteTrack;

  /// No description provided for @videoEditorCaptionsDeleteTrackConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove captions?'**
  String get videoEditorCaptionsDeleteTrackConfirmTitle;

  /// No description provided for @videoEditorCaptionsDeleteTrackConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All caption text and timing will be gone.'**
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle;

  /// No description provided for @videoEditorCaptionsCloseSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Close captions editor'**
  String get videoEditorCaptionsCloseSemanticLabel;

  /// No description provided for @videoEditorCaptionsDoneSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm captions'**
  String get videoEditorCaptionsDoneSemanticLabel;

  /// No description provided for @videoEditorCaptionsPresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Caption style'**
  String get videoEditorCaptionsPresetTitle;

  /// No description provided for @videoEditorCaptionsPresetClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get videoEditorCaptionsPresetClassic;

  /// No description provided for @videoEditorCaptionsPresetPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get videoEditorCaptionsPresetPop;

  /// No description provided for @videoEditorCaptionsPresetZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get videoEditorCaptionsPresetZoom;

  /// No description provided for @videoEditorCaptionsPresetSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring'**
  String get videoEditorCaptionsPresetSpring;

  /// No description provided for @videoEditorCaptionsPresetMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get videoEditorCaptionsPresetMono;

  /// No description provided for @videoEditorCaptionsPresetHeadline.
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get videoEditorCaptionsPresetHeadline;

  /// No description provided for @videoEditorCaptionsPresetTypewriter.
  ///
  /// In en, this message translates to:
  /// **'Typewriter'**
  String get videoEditorCaptionsPresetTypewriter;

  /// No description provided for @videoEditorCaptionsPresetMarker.
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get videoEditorCaptionsPresetMarker;

  /// No description provided for @videoEditorCaptionsPresetScript.
  ///
  /// In en, this message translates to:
  /// **'Script'**
  String get videoEditorCaptionsPresetScript;

  /// No description provided for @videoEditorCaptionsPresetRetro.
  ///
  /// In en, this message translates to:
  /// **'Retro'**
  String get videoEditorCaptionsPresetRetro;

  /// No description provided for @videoEditorCaptionsPresetElegant.
  ///
  /// In en, this message translates to:
  /// **'Elegant'**
  String get videoEditorCaptionsPresetElegant;

  /// No description provided for @videoEditorCaptionsPresetBubble.
  ///
  /// In en, this message translates to:
  /// **'Bubble'**
  String get videoEditorCaptionsPresetBubble;

  /// No description provided for @videoEditorCaptionsPresetNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get videoEditorCaptionsPresetNeon;

  /// No description provided for @videoEditorCaptionsPresetBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get videoEditorCaptionsPresetBold;

  /// No description provided for @videoEditorCaptionsPresetDreamy.
  ///
  /// In en, this message translates to:
  /// **'Dreamy'**
  String get videoEditorCaptionsPresetDreamy;

  /// No description provided for @videoEditorCaptionsPresetOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get videoEditorCaptionsPresetOcean;

  /// No description provided for @videoEditorCaptionsPresetSunny.
  ///
  /// In en, this message translates to:
  /// **'Sunny'**
  String get videoEditorCaptionsPresetSunny;

  /// No description provided for @videoEditorCaptionsPresetHandwritten.
  ///
  /// In en, this message translates to:
  /// **'Handwritten'**
  String get videoEditorCaptionsPresetHandwritten;

  /// No description provided for @videoEditorCaptionsPresetSerif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get videoEditorCaptionsPresetSerif;

  /// No description provided for @videoEditorCaptionsPresetStamp.
  ///
  /// In en, this message translates to:
  /// **'Stamp'**
  String get videoEditorCaptionsPresetStamp;

  /// No description provided for @videoEditorOpenTextSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open text editor'**
  String get videoEditorOpenTextSemanticLabel;

  /// No description provided for @videoEditorOpenDrawSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open draw editor'**
  String get videoEditorOpenDrawSemanticLabel;

  /// No description provided for @videoEditorOpenFilterSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open filter editor'**
  String get videoEditorOpenFilterSemanticLabel;

  /// No description provided for @videoEditorOpenStickerSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open sticker editor'**
  String get videoEditorOpenStickerSemanticLabel;

  /// No description provided for @videoEditorSaveDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your draft?'**
  String get videoEditorSaveDraftTitle;

  /// No description provided for @videoEditorSaveDraftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your edits for later, or discard them and leave the editor.'**
  String get videoEditorSaveDraftSubtitle;

  /// No description provided for @videoEditorSaveDraftButton.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get videoEditorSaveDraftButton;

  /// No description provided for @videoEditorDiscardChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get videoEditorDiscardChangesButton;

  /// No description provided for @videoEditorKeepEditingButton.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get videoEditorKeepEditingButton;

  /// No description provided for @videoEditorDeleteLayerDropZone.
  ///
  /// In en, this message translates to:
  /// **'Delete layer drop zone'**
  String get videoEditorDeleteLayerDropZone;

  /// No description provided for @videoEditorReleaseToDeleteLayer.
  ///
  /// In en, this message translates to:
  /// **'Release to delete layer'**
  String get videoEditorReleaseToDeleteLayer;

  /// No description provided for @videoEditorDoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get videoEditorDoneLabel;

  /// No description provided for @videoEditorPlayPauseSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Play or pause video'**
  String get videoEditorPlayPauseSemanticLabel;

  /// No description provided for @videoEditorSplitPositionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Split position invalid. Both clips must be at least {minDurationMs}ms long.'**
  String videoEditorSplitPositionInvalid(int minDurationMs);

  /// No description provided for @videoEditorSaveSelectedClip.
  ///
  /// In en, this message translates to:
  /// **'Save selected clip'**
  String get videoEditorSaveSelectedClip;

  /// No description provided for @videoEditorSaveClip.
  ///
  /// In en, this message translates to:
  /// **'Save clip'**
  String get videoEditorSaveClip;

  /// No description provided for @videoEditorClipSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Clip saved to library'**
  String get videoEditorClipSavedSuccess;

  /// No description provided for @videoEditorClipSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save clip'**
  String get videoEditorClipSaveFailed;

  /// No description provided for @videoEditorColorPickerSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Color picker'**
  String get videoEditorColorPickerSemanticLabel;

  /// No description provided for @videoEditorUndoSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get videoEditorUndoSemanticLabel;

  /// No description provided for @videoEditorRedoSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get videoEditorRedoSemanticLabel;

  /// No description provided for @videoEditorTextColorSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get videoEditorTextColorSemanticLabel;

  /// No description provided for @videoEditorTextAlignmentSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Text alignment'**
  String get videoEditorTextAlignmentSemanticLabel;

  /// No description provided for @videoEditorTextBackgroundSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Text background'**
  String get videoEditorTextBackgroundSemanticLabel;

  /// No description provided for @videoEditorFontSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get videoEditorFontSemanticLabel;

  /// No description provided for @videoEditorNoStickersFound.
  ///
  /// In en, this message translates to:
  /// **'No stickers found'**
  String get videoEditorNoStickersFound;

  /// No description provided for @videoEditorNoStickersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No stickers available'**
  String get videoEditorNoStickersAvailable;

  /// No description provided for @videoEditorFailedLoadStickers.
  ///
  /// In en, this message translates to:
  /// **'Failed to load stickers'**
  String get videoEditorFailedLoadStickers;

  /// No description provided for @videoEditorVoiceOverLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice over'**
  String get videoEditorVoiceOverLabel;

  /// Title for a single recorded voice-over take, numbered by capture position.
  ///
  /// In en, this message translates to:
  /// **'Recording {number}'**
  String videoEditorVoiceOverTakeName(int number);

  /// No description provided for @videoEditorOpenVoiceOverSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Record a voice over'**
  String get videoEditorOpenVoiceOverSemanticLabel;

  /// No description provided for @videoEditorVoiceOverRecordSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get videoEditorVoiceOverRecordSemanticLabel;

  /// No description provided for @videoEditorVoiceOverStopSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get videoEditorVoiceOverStopSemanticLabel;

  /// No description provided for @videoEditorVoiceOverHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to record. Add as many takes as you like.'**
  String get videoEditorVoiceOverHint;

  /// Counts the voice-over takes recorded so far in the recorder screen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No recordings yet} =1{1 recording} other{{count} recordings}}'**
  String videoEditorVoiceOverRecordingsCount(int count);

  /// No description provided for @videoEditorVoiceOverDeleteLast.
  ///
  /// In en, this message translates to:
  /// **'Delete last recording'**
  String get videoEditorVoiceOverDeleteLast;

  /// No description provided for @videoEditorVoiceOverPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone access needed'**
  String get videoEditorVoiceOverPermissionTitle;

  /// No description provided for @videoEditorVoiceOverPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access to record a voice over.'**
  String get videoEditorVoiceOverPermissionBody;

  /// No description provided for @videoEditorVoiceOverOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get videoEditorVoiceOverOpenSettings;

  /// No description provided for @videoEditorVoiceOverRecordingStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording started'**
  String get videoEditorVoiceOverRecordingStarted;

  /// No description provided for @videoEditorVoiceOverRecordingSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording saved'**
  String get videoEditorVoiceOverRecordingSaved;

  /// Screen-reader announcement and warning cue shown when the recorded voice-over runs longer than the video it will be laid over.
  ///
  /// In en, this message translates to:
  /// **'Recording is longer than your video'**
  String get videoEditorVoiceOverTooLong;

  /// No description provided for @videoEditorPlaySemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get videoEditorPlaySemanticLabel;

  /// No description provided for @videoEditorPauseSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get videoEditorPauseSemanticLabel;

  /// No description provided for @videoEditorVolumeSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Adjust volume'**
  String get videoEditorVolumeSemanticLabel;

  /// No description provided for @videoEditorTimelineVolumePreview.
  ///
  /// In en, this message translates to:
  /// **'Volume {percent}%'**
  String videoEditorTimelineVolumePreview(int percent);

  /// No description provided for @videoEditorTimelineSlideToAdjust.
  ///
  /// In en, this message translates to:
  /// **'Slide to adjust'**
  String get videoEditorTimelineSlideToAdjust;

  /// No description provided for @videoEditorChromaKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Green screen'**
  String get videoEditorChromaKeyLabel;

  /// No description provided for @videoEditorChromaKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Green screen'**
  String get videoEditorChromaKeyTitle;

  /// No description provided for @videoEditorChromaKeySemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Set up the green screen for this clip'**
  String get videoEditorChromaKeySemanticLabel;

  /// No description provided for @videoEditorChromaKeyCloseSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Discard green screen changes'**
  String get videoEditorChromaKeyCloseSemanticLabel;

  /// No description provided for @videoEditorChromaKeyDoneSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply the green screen'**
  String get videoEditorChromaKeyDoneSemanticLabel;

  /// No description provided for @videoEditorChromaKeyAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect'**
  String get videoEditorChromaKeyAutoDetect;

  /// No description provided for @videoEditorChromaKeyPresetGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get videoEditorChromaKeyPresetGreen;

  /// No description provided for @videoEditorChromaKeyPresetBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get videoEditorChromaKeyPresetBlue;

  /// No description provided for @videoEditorChromaKeyScreenColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Screen color'**
  String get videoEditorChromaKeyScreenColorLabel;

  /// No description provided for @videoEditorChromaKeyAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get videoEditorChromaKeyAmountLabel;

  /// Hint under the chroma-key similarity slider. Raise it when parts of the screen survive, lower it when the subject starts disappearing.
  ///
  /// In en, this message translates to:
  /// **'How much of the screen color disappears'**
  String get videoEditorChromaKeyAmountHint;

  /// No description provided for @videoEditorChromaKeyEdgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get videoEditorChromaKeyEdgeLabel;

  /// No description provided for @videoEditorChromaKeyEdgeHint.
  ///
  /// In en, this message translates to:
  /// **'Softens the cutout so hair doesn\'t turn jagged'**
  String get videoEditorChromaKeyEdgeHint;

  /// No description provided for @videoEditorChromaKeySpillLabel.
  ///
  /// In en, this message translates to:
  /// **'Spill'**
  String get videoEditorChromaKeySpillLabel;

  /// No description provided for @videoEditorChromaKeySpillHint.
  ///
  /// In en, this message translates to:
  /// **'Pulls the screen\'s color back off your subject'**
  String get videoEditorChromaKeySpillHint;

  /// No description provided for @videoEditorChromaKeyBackgroundLabel.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get videoEditorChromaKeyBackgroundLabel;

  /// No description provided for @videoEditorChromaKeyBackgroundNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get videoEditorChromaKeyBackgroundNone;

  /// No description provided for @videoEditorChromaKeyBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get videoEditorChromaKeyBackgroundColor;

  /// No description provided for @videoEditorChromaKeyBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get videoEditorChromaKeyBackgroundImage;

  /// No description provided for @videoEditorChromaKeyBackgroundVideo.
  ///
  /// In en, this message translates to:
  /// **'Clip'**
  String get videoEditorChromaKeyBackgroundVideo;

  /// No description provided for @videoEditorChromaKeyTransparentHint.
  ///
  /// In en, this message translates to:
  /// **'Video can\'t hold transparency, so this exports as black.'**
  String get videoEditorChromaKeyTransparentHint;

  /// No description provided for @videoEditorChromaKeyDetectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find a screen. It has to reach the edges of the frame — pick the color by hand instead.'**
  String get videoEditorChromaKeyDetectFailed;

  /// No description provided for @videoEditorChromaKeyPickClipTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a clip'**
  String get videoEditorChromaKeyPickClipTitle;

  /// No description provided for @videoEditorChromaKeyNoLibraryClips.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty. Save a clip first, then use it as a background.'**
  String get videoEditorChromaKeyNoLibraryClips;

  /// No description provided for @videoEditorChromaKeyImagePickFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load that image.'**
  String get videoEditorChromaKeyImagePickFailed;

  /// No description provided for @videoEditorChromaKeyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove green screen'**
  String get videoEditorChromaKeyRemove;

  /// No description provided for @videoEditorChromaKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply the green screen. Your clip is unchanged.'**
  String get videoEditorChromaKeyFailed;

  /// Shown when dropping a clip's already-baked green screen fails, so the clip keeps the keyed video. The counterpart videoEditorChromaKeyFailed is for the opposite direction — applying one.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove the green screen. Your clip is unchanged.'**
  String get videoEditorChromaKeyRemoveFailed;

  /// No description provided for @videoEditorChromaKeyApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying the green screen…'**
  String get videoEditorChromaKeyApplying;

  /// Shown in the green-screen editor when the renderer has no shader image filter, so the preview cannot show the key applied.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t show the live preview. Your settings still apply when you export.'**
  String get videoEditorChromaKeyPreviewUnavailable;

  /// No description provided for @videoEditorClipVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Clip {index}'**
  String videoEditorClipVolumeLabel(int index);

  /// No description provided for @videoEditorDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get videoEditorDeleteLabel;

  /// No description provided for @videoEditorDeleteSelectedItemSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete selected item'**
  String get videoEditorDeleteSelectedItemSemanticLabel;

  /// Label for the stop-motion control that sets how many output frames each captured still is held for.
  ///
  /// In en, this message translates to:
  /// **'Frames per image'**
  String get videoEditorStopMotionFramesPerImageLabel;

  /// Short frames-per-image value shown on the stop-motion preview badge and action button (e.g. '2 frames').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 frame} other{{count} frames}}'**
  String videoEditorStopMotionFramesCount(int count);

  /// Short label under the stop-motion frames-per-image action button in the timeline edit bar.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get videoEditorStopMotionFramesPerImageButtonLabel;

  /// Accessibility value announcing the current stop-motion hold length, in output frames per still.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} frame per image} other{{count} frames per image}}'**
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count);

  /// Accessibility label for a single still tile in the stop-motion timeline strip.
  ///
  /// In en, this message translates to:
  /// **'Stop-motion frame {position} of {total}'**
  String videoEditorStopMotionFrameSemanticLabel(int position, int total);

  /// No description provided for @videoEditorEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get videoEditorEditLabel;

  /// No description provided for @videoEditorEditSelectedItemSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit selected item'**
  String get videoEditorEditSelectedItemSemanticLabel;

  /// No description provided for @videoEditorDuplicateLabel.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get videoEditorDuplicateLabel;

  /// No description provided for @videoEditorDuplicateSelectedItemSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Duplicate selected item'**
  String get videoEditorDuplicateSelectedItemSemanticLabel;

  /// No description provided for @videoEditorCombineLabel.
  ///
  /// In en, this message translates to:
  /// **'Combine'**
  String get videoEditorCombineLabel;

  /// No description provided for @videoEditorCombineDrawLayersSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Combine selected drawings into one layer'**
  String get videoEditorCombineDrawLayersSemanticLabel;

  /// No description provided for @videoEditorSplitLabel.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get videoEditorSplitLabel;

  /// No description provided for @videoEditorSplitSelectedClipSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Split selected clip'**
  String get videoEditorSplitSelectedClipSemanticLabel;

  /// No description provided for @videoEditorExtractAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Extract Audio'**
  String get videoEditorExtractAudioLabel;

  /// No description provided for @videoEditorClipAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Clip Audio'**
  String get videoEditorClipAudioTitle;

  /// No description provided for @videoEditorExtractAudioFromClipSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Extract audio from clip and mute original'**
  String get videoEditorExtractAudioFromClipSemanticLabel;

  /// No description provided for @videoEditorExtractAudioNoLocalFile.
  ///
  /// In en, this message translates to:
  /// **'Cannot extract audio: clip is not locally available.'**
  String get videoEditorExtractAudioNoLocalFile;

  /// No description provided for @videoEditorExtractAudioFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not extract audio. Please try again.'**
  String get videoEditorExtractAudioFailed;

  /// Label shown next to the speed value in the clip speed bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get videoEditorSpeedLabel;

  /// Accessibility label for the Set Speed button in the timeline clip controls.
  ///
  /// In en, this message translates to:
  /// **'Set playback speed for selected clip'**
  String get videoEditorSetClipSpeedSemanticLabel;

  /// Label for the Reverse button in the timeline clip controls.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get videoEditorReverseLabel;

  /// Accessibility label for the Reverse button in the timeline clip controls.
  ///
  /// In en, this message translates to:
  /// **'Toggle reverse playback for selected clip'**
  String get videoEditorReverseClipSemanticLabel;

  /// Status text shown while the selected clip is being rendered in reverse for preview playback.
  ///
  /// In en, this message translates to:
  /// **'One moment, we\'re reversing your clip'**
  String get videoEditorReverseProgressLabel;

  /// Label for the Transform button in the timeline clip controls that opens the crop/rotate editor.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get videoEditorTransformLabel;

  /// Accessibility label for the Transform button in the timeline clip controls.
  ///
  /// In en, this message translates to:
  /// **'Crop, rotate, or flip selected clip'**
  String get videoEditorTransformSelectedClipSemanticLabel;

  /// Status text shown while the selected clip is being re-rendered with the applied crop/rotate transform.
  ///
  /// In en, this message translates to:
  /// **'One moment, we\'re transforming your clip'**
  String get videoEditorTransformProgressLabel;

  /// Snackbar message shown when re-rendering a clip with its crop/rotate transform fails.
  ///
  /// In en, this message translates to:
  /// **'Could not transform clip. Please try again.'**
  String get videoEditorTransformFailed;

  /// Snackbar message shown when a transform is requested for a clip that has no locally available file.
  ///
  /// In en, this message translates to:
  /// **'Cannot transform: clip is not locally available.'**
  String get videoEditorTransformNoLocalFile;

  /// Accessibility label for the Transform button in the stop-motion frame controls.
  ///
  /// In en, this message translates to:
  /// **'Crop, rotate, or flip selected frame'**
  String get videoEditorTransformSelectedFrameSemanticLabel;

  /// Status text shown while a stop-motion frame is being rendered with the applied crop/rotate transform.
  ///
  /// In en, this message translates to:
  /// **'One moment, we\'re transforming your frame'**
  String get videoEditorTransformFrameProgressLabel;

  /// Snackbar message shown when saving a transformed stop-motion frame fails.
  ///
  /// In en, this message translates to:
  /// **'Could not transform frame. Please try again.'**
  String get videoEditorTransformFrameFailed;

  /// Label for the rotate action button in the clip transform editor.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get videoEditorTransformRotateLabel;

  /// Label for the flip action button in the clip transform editor.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get videoEditorTransformFlipLabel;

  /// Label for the reset action button in the clip transform editor.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get videoEditorTransformResetLabel;

  /// Accessibility label for the done button that applies the clip transform.
  ///
  /// In en, this message translates to:
  /// **'Apply transform'**
  String get videoEditorTransformApplySemanticLabel;

  /// Accessibility label for the back button that cancels the clip transform.
  ///
  /// In en, this message translates to:
  /// **'Cancel transform'**
  String get videoEditorTransformCancelSemanticLabel;

  /// Label for the play button in the clip transform editor bottom bar.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get videoEditorTransformPlayLabel;

  /// Label for the pause button in the clip transform editor bottom bar.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get videoEditorTransformPauseLabel;

  /// Snackbar message shown when a reverse is requested for a clip that has no locally available file.
  ///
  /// In en, this message translates to:
  /// **'Cannot reverse: clip is not locally available.'**
  String get videoEditorReverseNoLocalFile;

  /// Snackbar message shown when reversing a clip fails during rendering.
  ///
  /// In en, this message translates to:
  /// **'Could not reverse clip. Please try again.'**
  String get videoEditorReverseFailed;

  /// Title of the bottom sheet for adjusting clip playback speed.
  ///
  /// In en, this message translates to:
  /// **'Clip Speed'**
  String get videoEditorSpeedSheetTitle;

  /// Title of the bottom sheet for choosing the transition between two adjacent clips.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get videoEditorTransitionSheetTitle;

  /// Transition option for a hard cut between clips (no transition).
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get videoEditorTransitionNone;

  /// Transition option that cross-dissolves one clip into the next.
  ///
  /// In en, this message translates to:
  /// **'Dissolve'**
  String get videoEditorTransitionDissolve;

  /// Transition option that dips through black between clips.
  ///
  /// In en, this message translates to:
  /// **'Fade to black'**
  String get videoEditorTransitionFadeToBlack;

  /// Transition option that dips through white between clips.
  ///
  /// In en, this message translates to:
  /// **'Fade to white'**
  String get videoEditorTransitionFadeToWhite;

  /// Transition option where the next clip slides in over the current one.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get videoEditorTransitionSlide;

  /// Transition option where the next clip pushes the current one out of frame.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get videoEditorTransitionPush;

  /// Transition option where the next clip is progressively revealed over the current one.
  ///
  /// In en, this message translates to:
  /// **'Wipe'**
  String get videoEditorTransitionWipe;

  /// Accessibility label for the button between two clips that opens the transition picker.
  ///
  /// In en, this message translates to:
  /// **'Edit transition'**
  String get videoEditorTransitionButtonSemanticLabel;

  /// Title of the bottom sheet for choosing the loop-restart transition, where the last clip's tail blends into the first clip's head so the video loops seamlessly.
  ///
  /// In en, this message translates to:
  /// **'Loop transition'**
  String get videoEditorLoopTransitionSheetTitle;

  /// Accessibility label for the button at the end of the timeline that opens the loop-restart transition picker.
  ///
  /// In en, this message translates to:
  /// **'Edit loop transition'**
  String get videoEditorLoopTransitionButtonSemanticLabel;

  /// Section label above the transition duration presets in the transition picker.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get videoEditorTransitionDuration;

  /// Hint shown below the transition duration slider when the maximum length is reduced because an adjacent clip already has a transition that uses part of the shared clip.
  ///
  /// In en, this message translates to:
  /// **'Shortened to avoid overlapping the neighbouring transition.'**
  String get videoEditorTransitionDurationLimitedHint;

  /// Section label above the transition easing-curve options in the transition picker.
  ///
  /// In en, this message translates to:
  /// **'Curve'**
  String get videoEditorTransitionCurve;

  /// Section label above the slide/push/wipe direction options in the transition picker.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get videoEditorTransitionDirection;

  /// Accessibility label for the left direction option of a slide/push/wipe transition.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get videoEditorTransitionDirectionLeft;

  /// Accessibility label for the right direction option of a slide/push/wipe transition.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get videoEditorTransitionDirectionRight;

  /// Accessibility label for the up direction option of a slide/push/wipe transition.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get videoEditorTransitionDirectionUp;

  /// Accessibility label for the down direction option of a slide/push/wipe transition.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get videoEditorTransitionDirectionDown;

  /// Accessibility label for an easing-curve option in the transition picker, identified by its position. The curve shape is shown visually as a glyph; screen readers announce the option number instead.
  ///
  /// In en, this message translates to:
  /// **'Easing curve {number}'**
  String videoEditorTransitionCurveOptionSemanticLabel(int number);

  /// Label for the control that opens the enter/leave animation picker for a text/sticker/drawing layer, and the picker's title.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get videoEditorLayerAnimationLabel;

  /// Accessibility label for the button that opens the layer enter/leave animation picker.
  ///
  /// In en, this message translates to:
  /// **'Edit layer animation'**
  String get videoEditorLayerAnimationButtonSemanticLabel;

  /// Tab/segment label for the animation a layer plays when it appears.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get videoEditorLayerAnimationEnter;

  /// Tab/segment label for the animation a layer plays when it disappears.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get videoEditorLayerAnimationLeave;

  /// Layer animation type that fades the layer's opacity in or out.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get videoEditorLayerAnimationFade;

  /// Layer animation type that scales the layer from a smaller size up to full size (or back).
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get videoEditorLayerAnimationScale;

  /// Section label above the slider that sets the starting size for a scale animation (0% to 100%).
  ///
  /// In en, this message translates to:
  /// **'Scale from'**
  String get videoEditorLayerAnimationScaleFrom;

  /// No description provided for @videoEditorFinishTimelineEditingSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Finish timeline editing'**
  String get videoEditorFinishTimelineEditingSemanticLabel;

  /// No description provided for @videoEditorAudioPlayPreviewSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Play preview'**
  String get videoEditorAudioPlayPreviewSemanticLabel;

  /// No description provided for @videoEditorAudioPausePreviewSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Pause preview'**
  String get videoEditorAudioPausePreviewSemanticLabel;

  /// No description provided for @videoEditorAudioUntitledSound.
  ///
  /// In en, this message translates to:
  /// **'Untitled sound'**
  String get videoEditorAudioUntitledSound;

  /// No description provided for @videoEditorAudioUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get videoEditorAudioUntitled;

  /// No description provided for @videoEditorAudioAddAudio.
  ///
  /// In en, this message translates to:
  /// **'Add audio'**
  String get videoEditorAudioAddAudio;

  /// No description provided for @videoEditorAudioNoSoundsAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'No sounds available'**
  String get videoEditorAudioNoSoundsAvailableTitle;

  /// No description provided for @videoEditorAudioNoSoundsAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sounds will appear here when creators share audio'**
  String get videoEditorAudioNoSoundsAvailableSubtitle;

  /// No description provided for @videoEditorAudioFailedToLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sounds'**
  String get videoEditorAudioFailedToLoadTitle;

  /// No description provided for @videoEditorAudioSegmentInstruction.
  ///
  /// In en, this message translates to:
  /// **'Select the audio segment for your video'**
  String get videoEditorAudioSegmentInstruction;

  /// No description provided for @videoEditorAudioCategoryDivine.
  ///
  /// In en, this message translates to:
  /// **'Divine'**
  String get videoEditorAudioCategoryDivine;

  /// No description provided for @videoEditorAudioCategoryCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get videoEditorAudioCategoryCommunity;

  /// No description provided for @videoEditorAudioCategoryFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get videoEditorAudioCategoryFeatured;

  /// No description provided for @videoEditorAudioCategoryMySounds.
  ///
  /// In en, this message translates to:
  /// **'My Sounds'**
  String get videoEditorAudioCategoryMySounds;

  /// No description provided for @videoEditorDrawToolArrowSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Arrow tool'**
  String get videoEditorDrawToolArrowSemanticLabel;

  /// No description provided for @videoEditorDrawToolEraserSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Eraser tool'**
  String get videoEditorDrawToolEraserSemanticLabel;

  /// No description provided for @videoEditorDrawToolMarkerSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Marker tool'**
  String get videoEditorDrawToolMarkerSemanticLabel;

  /// No description provided for @videoEditorDrawToolPencilSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Pencil tool'**
  String get videoEditorDrawToolPencilSemanticLabel;

  /// No description provided for @videoEditorShowTimelineSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Show timeline'**
  String get videoEditorShowTimelineSemanticLabel;

  /// No description provided for @videoEditorHideTimelineSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Hide timeline'**
  String get videoEditorHideTimelineSemanticLabel;

  /// No description provided for @videoEditorFeedPreviewContent.
  ///
  /// In en, this message translates to:
  /// **'Avoid placing content behind these areas.'**
  String get videoEditorFeedPreviewContent;

  /// No description provided for @videoEditorStickersDivineOriginals.
  ///
  /// In en, this message translates to:
  /// **'Divine Originals'**
  String get videoEditorStickersDivineOriginals;

  /// No description provided for @videoEditorStickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search stickers...'**
  String get videoEditorStickerSearchHint;

  /// No description provided for @videoEditorSelectFontSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Select font'**
  String get videoEditorSelectFontSemanticLabel;

  /// No description provided for @videoEditorFontUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get videoEditorFontUnknown;

  /// No description provided for @videoEditorSplitPlayheadOutsideClip.
  ///
  /// In en, this message translates to:
  /// **'Playhead must be within the selected clip to split.'**
  String get videoEditorSplitPlayheadOutsideClip;

  /// No description provided for @videoEditorTimelineTrimStartSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Trim start'**
  String get videoEditorTimelineTrimStartSemanticLabel;

  /// No description provided for @videoEditorTimelineTrimEndSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Trim end'**
  String get videoEditorTimelineTrimEndSemanticLabel;

  /// No description provided for @videoEditorTimelineTrimClipSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Trim clip'**
  String get videoEditorTimelineTrimClipSemanticLabel;

  /// No description provided for @videoEditorTimelineTrimClipHint.
  ///
  /// In en, this message translates to:
  /// **'Drag handles to adjust clip duration'**
  String get videoEditorTimelineTrimClipHint;

  /// No description provided for @videoEditorTimelineDraggingClipSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Dragging clip {index}'**
  String videoEditorTimelineDraggingClipSemanticLabel(int index);

  /// No description provided for @videoEditorTimelineClipSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Clip {index} of {total}, {duration} seconds'**
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  );

  /// No description provided for @videoEditorTimelineClipReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Long press to reorder'**
  String get videoEditorTimelineClipReorderHint;

  /// No description provided for @videoEditorTimelineClipMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get videoEditorTimelineClipMoveLeft;

  /// No description provided for @videoEditorTimelineClipMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get videoEditorTimelineClipMoveRight;

  /// Accessibility label for a timeline clip that is selected in multi-select mode.
  ///
  /// In en, this message translates to:
  /// **'Clip {index} of {total}, selected'**
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total);

  /// Accessibility label for a timeline clip that is not selected in multi-select mode.
  ///
  /// In en, this message translates to:
  /// **'Clip {index} of {total}, not selected'**
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total);

  /// Label for the button that starts multi-select mode on the timeline.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get videoEditorMultiSelectLabel;

  /// Accessibility label for the button that starts multi-select mode on the timeline.
  ///
  /// In en, this message translates to:
  /// **'Select multiple clips'**
  String get videoEditorMultiSelectSemanticLabel;

  /// Accessibility label for the button that exits multi-select mode.
  ///
  /// In en, this message translates to:
  /// **'Done selecting clips'**
  String get videoEditorMultiSelectDoneSemanticLabel;

  /// Header shown in the multi-select action bar reporting how many clips are selected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No clips selected} =1{1 clip selected} other{{count} clips selected}}'**
  String videoEditorMultiSelectCountLabel(int count);

  /// Accessibility label for the button that starts draw-layer multi-select mode.
  ///
  /// In en, this message translates to:
  /// **'Select multiple drawings'**
  String get videoEditorLayerMultiSelectSemanticLabel;

  /// Accessibility label for the button that exits draw-layer multi-select mode.
  ///
  /// In en, this message translates to:
  /// **'Done selecting drawings'**
  String get videoEditorLayerMultiSelectDoneSemanticLabel;

  /// Accessibility label for the button that deletes the selected drawings in draw-layer multi-select mode.
  ///
  /// In en, this message translates to:
  /// **'Delete selected drawings'**
  String get videoEditorDeleteSelectedDrawingsSemanticLabel;

  /// Header shown in the draw-layer multi-select action bar reporting how many drawings are selected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No drawings selected} =1{1 drawing selected} other{{count} drawings selected}}'**
  String videoEditorLayerMultiSelectCountLabel(int count);

  /// Label for the button that merges the selected clips into one.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get videoEditorMergeLabel;

  /// Accessibility label for the button that merges the selected clips into one.
  ///
  /// In en, this message translates to:
  /// **'Merge selected clips'**
  String get videoEditorMergeSelectedClipsSemanticLabel;

  /// Accessibility label for the button that deletes the selected clips.
  ///
  /// In en, this message translates to:
  /// **'Delete selected clips'**
  String get videoEditorDeleteSelectedClipsSemanticLabel;

  /// Semantic label for the delete button while stop-motion stills are multi-selected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected frames'**
  String get videoEditorDeleteSelectedFramesSemanticLabel;

  /// Semantic label for the reverse button while stop-motion stills are multi-selected.
  ///
  /// In en, this message translates to:
  /// **'Reverse selected frames'**
  String get videoEditorReverseSelectedFramesSemanticLabel;

  /// Semantic label for the duplicate button while stop-motion stills are multi-selected.
  ///
  /// In en, this message translates to:
  /// **'Duplicate selected frames'**
  String get videoEditorDuplicateSelectedFramesSemanticLabel;

  /// Snackbar shown when Done is pressed on a stop-motion composition shorter than the minimum output duration.
  ///
  /// In en, this message translates to:
  /// **'Your video needs at least {seconds}s — capture a few more frames.'**
  String videoEditorStopMotionTooShortSnackbar(int seconds);

  /// Status text shown while the selected clips are being concatenated into a single clip.
  ///
  /// In en, this message translates to:
  /// **'One moment, we\'re merging your clips'**
  String get videoEditorMergeProgressLabel;

  /// Snackbar message shown when merging the selected clips fails during rendering.
  ///
  /// In en, this message translates to:
  /// **'Could not merge clips. Please try again.'**
  String get videoEditorMergeFailed;

  /// No description provided for @videoEditorTimelineLongPressToDragHint.
  ///
  /// In en, this message translates to:
  /// **'Long press to drag'**
  String get videoEditorTimelineLongPressToDragHint;

  /// No description provided for @videoEditorVideoTimelineSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Video timeline'**
  String get videoEditorVideoTimelineSemanticLabel;

  /// No description provided for @videoEditorTimelinePositionFormat.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String videoEditorTimelinePositionFormat(int minutes, String seconds);

  /// No description provided for @videoEditorColorSelectedSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{colorName}, selected'**
  String videoEditorColorSelectedSemanticLabel(String colorName);

  /// No description provided for @videoEditorCloseColorPickerSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Close color picker'**
  String get videoEditorCloseColorPickerSemanticLabel;

  /// No description provided for @videoEditorPickColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick color'**
  String get videoEditorPickColorTitle;

  /// No description provided for @videoEditorConfirmColorSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm color'**
  String get videoEditorConfirmColorSemanticLabel;

  /// No description provided for @videoEditorSaturationBrightnessSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Saturation and brightness'**
  String get videoEditorSaturationBrightnessSemanticLabel;

  /// No description provided for @videoEditorSaturationBrightnessValue.
  ///
  /// In en, this message translates to:
  /// **'Saturation {saturation}%, Brightness {brightness}%'**
  String videoEditorSaturationBrightnessValue(int saturation, int brightness);

  /// No description provided for @videoEditorHueSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get videoEditorHueSemanticLabel;

  /// No description provided for @videoEditorAddElementSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Add element'**
  String get videoEditorAddElementSemanticLabel;

  /// No description provided for @videoEditorDoneSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get videoEditorDoneSemanticLabel;

  /// No description provided for @videoEditorLevelSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get videoEditorLevelSemanticLabel;

  /// No description provided for @videoMetadataClosePostDetailsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Close post details'**
  String get videoMetadataClosePostDetailsSemanticLabel;

  /// No description provided for @videoMetadataDismissHelpDialogSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Dismiss help dialog'**
  String get videoMetadataDismissHelpDialogSemanticLabel;

  /// No description provided for @videoMetadataGotItButton.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get videoMetadataGotItButton;

  /// No description provided for @videoMetadataLimitReachedWarning.
  ///
  /// In en, this message translates to:
  /// **'64KB limit reached. Remove some content to continue.'**
  String get videoMetadataLimitReachedWarning;

  /// No description provided for @videoMetadataExpirationLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiration'**
  String get videoMetadataExpirationLabel;

  /// No description provided for @videoMetadataSelectExpirationSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Select expiration time'**
  String get videoMetadataSelectExpirationSemanticLabel;

  /// No description provided for @videoMetadataTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get videoMetadataTitleLabel;

  /// No description provided for @videoMetadataDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get videoMetadataDescriptionLabel;

  /// No description provided for @videoMetadataTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get videoMetadataTagsLabel;

  /// No description provided for @videoMetadataDeleteTagHint.
  ///
  /// In en, this message translates to:
  /// **'Delete Tag {tag}'**
  String videoMetadataDeleteTagHint(String tag);

  /// No description provided for @videoMetadataContentWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Add content warning'**
  String get videoMetadataContentWarningLabel;

  /// No description provided for @videoMetadataSelectContentWarningsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Select content warnings'**
  String get videoMetadataSelectContentWarningsSemanticLabel;

  /// No description provided for @videoMetadataContentWarningSelectAllThatApply.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply'**
  String get videoMetadataContentWarningSelectAllThatApply;

  /// No description provided for @videoMetadataAudioReuseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let others save and reuse this video\'s audio.'**
  String get videoMetadataAudioReuseSubtitle;

  /// Snackbar shown after a successful publish when the creator opted into a reusable sound but extracting or publishing it failed, so the video posted without the sharing choice they made.
  ///
  /// In en, this message translates to:
  /// **'Your video is up, but the sound didn\'t publish. Edit the video to share it.'**
  String get publishAudioReuseDegradedWarning;

  /// No description provided for @videoMetadataCollaboratorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Add collaborators'**
  String get videoMetadataCollaboratorsLabel;

  /// No description provided for @videoMetadataAddCollaboratorSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite collaborator'**
  String get videoMetadataAddCollaboratorSemanticLabel;

  /// No description provided for @videoMetadataMutualFollowersSearchText.
  ///
  /// In en, this message translates to:
  /// **'Mutual followers'**
  String get videoMetadataMutualFollowersSearchText;

  /// No description provided for @videoMetadataInspiredByLabel.
  ///
  /// In en, this message translates to:
  /// **'Add inspired by'**
  String get videoMetadataInspiredByLabel;

  /// No description provided for @videoMetadataSetInspiredBySemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Set inspired by'**
  String get videoMetadataSetInspiredBySemanticLabel;

  /// No description provided for @videoMetadataCreatorCannotBeReferencedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'This creator cannot be referenced.'**
  String get videoMetadataCreatorCannotBeReferencedSnackbar;

  /// No description provided for @videoMetadataPostDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Post details'**
  String get videoMetadataPostDetailsTitle;

  /// No description provided for @videoMetadataSavedToLibrarySnackbar.
  ///
  /// In en, this message translates to:
  /// **'Saved to library'**
  String get videoMetadataSavedToLibrarySnackbar;

  /// No description provided for @videoMetadataFailedToSaveSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get videoMetadataFailedToSaveSnackbar;

  /// No description provided for @videoMetadataGoToLibraryButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Library'**
  String get videoMetadataGoToLibraryButton;

  /// No description provided for @videoMetadataSaveForLaterSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Save for later button'**
  String get videoMetadataSaveForLaterSemanticLabel;

  /// No description provided for @videoMetadataSavingVideoHint.
  ///
  /// In en, this message translates to:
  /// **'Saving video...'**
  String get videoMetadataSavingVideoHint;

  /// No description provided for @videoMetadataSaveToDraftsHint.
  ///
  /// In en, this message translates to:
  /// **'Save video to drafts and {destination}'**
  String videoMetadataSaveToDraftsHint(String destination);

  /// Accessibility hint on the Save-for-later button while no rendered video file exists yet — the render is still running, or it failed. The button stays enabled, since a draft needs no rendered file, but the gallery copy is made from that file and is therefore skipped.
  ///
  /// In en, this message translates to:
  /// **'Save video to drafts. No rendered video yet, so no copy is added to {destination}.'**
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination);

  /// No description provided for @videoMetadataSaveForLaterButton.
  ///
  /// In en, this message translates to:
  /// **'Save for Later'**
  String get videoMetadataSaveForLaterButton;

  /// No description provided for @videoMetadataPostSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Post button'**
  String get videoMetadataPostSemanticLabel;

  /// No description provided for @videoMetadataPublishVideoHint.
  ///
  /// In en, this message translates to:
  /// **'Publish video to feed'**
  String get videoMetadataPublishVideoHint;

  /// Label for the toggle that also surfaces a video reply in normal feeds.
  ///
  /// In en, this message translates to:
  /// **'Also share to my feed'**
  String get videoMetadataShareReplyToFeedTitle;

  /// Helper text for the video reply feed visibility toggle.
  ///
  /// In en, this message translates to:
  /// **'Off keeps this video only in the comment thread.'**
  String get videoMetadataShareReplyToFeedSubtitle;

  /// No description provided for @videoMetadataFormNotReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Fill out the form to enable'**
  String get videoMetadataFormNotReadyHint;

  /// No description provided for @videoMetadataPostButton.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get videoMetadataPostButton;

  /// No description provided for @videoMetadataOpenPreviewSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Open post preview screen'**
  String get videoMetadataOpenPreviewSemanticLabel;

  /// No description provided for @videoMetadataShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get videoMetadataShareTitle;

  /// No description provided for @videoMetadataVideoDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Video details'**
  String get videoMetadataVideoDetailsSubtitle;

  /// No description provided for @videoMetadataClassicDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get videoMetadataClassicDoneButton;

  /// No description provided for @videoMetadataPlayPreviewSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Play preview'**
  String get videoMetadataPlayPreviewSemanticLabel;

  /// No description provided for @videoMetadataPausePreviewSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Pause preview'**
  String get videoMetadataPausePreviewSemanticLabel;

  /// No description provided for @videoMetadataClosePreviewSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Close video preview'**
  String get videoMetadataClosePreviewSemanticLabel;

  /// No description provided for @videoMetadataRemoveSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get videoMetadataRemoveSemanticLabel;

  /// Empty-state message shown in the fullscreen feed when the last visible video has just been deleted, blocked, or muted and the route cannot be popped back to a parent (e.g. a cold deep-link).
  ///
  /// In en, this message translates to:
  /// **'Video removed'**
  String get fullscreenFeedRemovedMessage;

  /// Empty-state message shown in the fullscreen feed when the feed it is playing has drained after having had videos — for example the viewer unliked the last video in their Liked feed.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to play here'**
  String get fullscreenFeedEmptyMessage;

  /// No description provided for @settingsBadgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get settingsBadgesTitle;

  /// No description provided for @settingsBadgesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Accept awards and check issued badge status.'**
  String get settingsBadgesSubtitle;

  /// No description provided for @badgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badgesTitle;

  /// No description provided for @badgesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load badges'**
  String get badgesLoadError;

  /// No description provided for @badgesUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update badge'**
  String get badgesUpdateError;

  /// No description provided for @badgesAwardedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No badge awards yet'**
  String get badgesAwardedEmptyTitle;

  /// No description provided for @badgesAwardedEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone awards you a Nostr badge, it will land here.'**
  String get badgesAwardedEmptySubtitle;

  /// No description provided for @badgesStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get badgesStatusAccepted;

  /// No description provided for @badgesStatusNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get badgesStatusNotAccepted;

  /// No description provided for @badgesActionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get badgesActionRemove;

  /// No description provided for @badgesActionAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get badgesActionAccept;

  /// No description provided for @badgesActionReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get badgesActionReject;

  /// No description provided for @badgesIssuedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No issued badges yet'**
  String get badgesIssuedEmptyTitle;

  /// No description provided for @badgesIssuedEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Badges you issue will show acceptance status here.'**
  String get badgesIssuedEmptySubtitle;

  /// No description provided for @badgesIssuedNoRecipients.
  ///
  /// In en, this message translates to:
  /// **'No recipients found for this award.'**
  String get badgesIssuedNoRecipients;

  /// No description provided for @badgesRecipientAcceptedStatus.
  ///
  /// In en, this message translates to:
  /// **'Accepted by recipient'**
  String get badgesRecipientAcceptedStatus;

  /// No description provided for @badgesRecipientWaitingStatus.
  ///
  /// In en, this message translates to:
  /// **'Waiting for recipient'**
  String get badgesRecipientWaitingStatus;

  /// Header of the collapsible section listing badge awards the user dismissed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Hidden (1)} other{Hidden ({count})}}'**
  String badgesHiddenSectionTitle(int count);

  /// No description provided for @badgesActionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get badgesActionRestore;

  /// No description provided for @badgesHiddenSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Badge hidden'**
  String get badgesHiddenSnackbar;

  /// No description provided for @badgesHiddenSnackbarUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get badgesHiddenSnackbarUndo;

  /// No description provided for @badgesTabAwarded.
  ///
  /// In en, this message translates to:
  /// **'Awarded'**
  String get badgesTabAwarded;

  /// No description provided for @badgesTabCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get badgesTabCreated;

  /// No description provided for @badgesTabIssued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get badgesTabIssued;

  /// No description provided for @badgesCreateAction.
  ///
  /// In en, this message translates to:
  /// **'New badge'**
  String get badgesCreateAction;

  /// No description provided for @badgesCreatedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No badges made yet'**
  String get badgesCreatedEmptyTitle;

  /// No description provided for @badgesCreatedEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make one and hand it to someone who earned it.'**
  String get badgesCreatedEmptySubtitle;

  /// Summary line under a badge the user created, counting the distinct people who received it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not awarded yet} =1{Awarded to 1 person} other{Awarded to {count} people}}'**
  String badgesCreatedAwardSummary(int count);

  /// No description provided for @badgeEditorCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New badge'**
  String get badgeEditorCreateTitle;

  /// No description provided for @badgeEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit badge'**
  String get badgeEditorEditTitle;

  /// No description provided for @badgeEditorNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get badgeEditorNameLabel;

  /// No description provided for @badgeEditorNameHint.
  ///
  /// In en, this message translates to:
  /// **'Scene Stealer'**
  String get badgeEditorNameHint;

  /// No description provided for @badgeEditorIdentifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get badgeEditorIdentifierLabel;

  /// No description provided for @badgeEditorIdentifierHelp.
  ///
  /// In en, this message translates to:
  /// **'Part of the badge\'s address, so it stays put once the badge exists.'**
  String get badgeEditorIdentifierHelp;

  /// No description provided for @badgeEditorIdentifierTaken.
  ///
  /// In en, this message translates to:
  /// **'You already have a badge with this identifier. Edit that one instead — publishing here would replace it.'**
  String get badgeEditorIdentifierTaken;

  /// No description provided for @badgeEditorIdentifierRequired.
  ///
  /// In en, this message translates to:
  /// **'Every badge needs an identifier — type one if the name did not fill it in.'**
  String get badgeEditorIdentifierRequired;

  /// No description provided for @badgeEditorDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get badgeEditorDescriptionLabel;

  /// No description provided for @badgeEditorDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'For the one who steals the scroll with a single loop.'**
  String get badgeEditorDescriptionHint;

  /// No description provided for @badgeEditorArtworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get badgeEditorArtworkLabel;

  /// No description provided for @badgeEditorArtworkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add artwork'**
  String get badgeEditorArtworkAdd;

  /// No description provided for @badgeEditorArtworkReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get badgeEditorArtworkReplace;

  /// No description provided for @badgeEditorArtworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not upload that image'**
  String get badgeEditorArtworkError;

  /// No description provided for @badgeEditorArtworkRequired.
  ///
  /// In en, this message translates to:
  /// **'Every badge needs artwork.'**
  String get badgeEditorArtworkRequired;

  /// No description provided for @badgeEditorArtworkRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove artwork'**
  String get badgeEditorArtworkRemove;

  /// No description provided for @badgeEditorArtworkSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Badge artwork'**
  String get badgeEditorArtworkSheetTitle;

  /// No description provided for @badgeDetailDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete badge'**
  String get badgeDetailDeleteAction;

  /// No description provided for @badgeDetailDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this badge?'**
  String get badgeDetailDeleteTitle;

  /// No description provided for @badgeDetailDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This asks relays to drop the badge and every award you handed out for it. Relays can refuse, and anyone who pinned it keeps it on their profile until they remove it.'**
  String get badgeDetailDeleteBody;

  /// No description provided for @badgeDetailDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get badgeDetailDeleteConfirm;

  /// No description provided for @badgeEditorSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Publish badge'**
  String get badgeEditorSaveAction;

  /// No description provided for @badgeEditorSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not publish the badge'**
  String get badgeEditorSaveError;

  /// No description provided for @badgeEditorLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this badge'**
  String get badgeEditorLoadError;

  /// No description provided for @badgeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get badgeDetailTitle;

  /// No description provided for @badgeDetailMadeBy.
  ///
  /// In en, this message translates to:
  /// **'Made by'**
  String get badgeDetailMadeBy;

  /// No description provided for @badgeDetailRecipientsTitle.
  ///
  /// In en, this message translates to:
  /// **'Awarded to'**
  String get badgeDetailRecipientsTitle;

  /// No description provided for @badgeDetailNoRecipients.
  ///
  /// In en, this message translates to:
  /// **'Nobody has this one yet.'**
  String get badgeDetailNoRecipients;

  /// No description provided for @badgeDetailAwardAction.
  ///
  /// In en, this message translates to:
  /// **'Award this badge'**
  String get badgeDetailAwardAction;

  /// No description provided for @badgeDetailEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit badge'**
  String get badgeDetailEditAction;

  /// No description provided for @badgeDetailShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get badgeDetailShareAction;

  /// Body of the share sheet when sharing a badge. The link is an naddr reference.
  ///
  /// In en, this message translates to:
  /// **'Check out this badge on Divine: {link}'**
  String badgeDetailShareMessage(String link);

  /// Label of the per-recipient revoke button on the badge detail screen, shown only to the badge's issuer.
  ///
  /// In en, this message translates to:
  /// **'Take badge back'**
  String get badgeDetailRevokeAction;

  /// No description provided for @badgeDetailRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Take this badge back?'**
  String get badgeDetailRevokeTitle;

  /// No description provided for @badgeDetailRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'This asks relays to drop the award you gave this person. Relays can refuse, and if they already pinned the badge it stays on their profile until they take it down. Either way, they are not told.'**
  String get badgeDetailRevokeBody;

  /// Body of the revoke sheet when the issuer is taking the badge back from themselves. Unlike the general case, their own pin is removed too, because the profile badge list is their own event.
  ///
  /// In en, this message translates to:
  /// **'This asks relays to drop the award you gave yourself, and takes the badge off your profile. If the relays refuse the deletion, nothing changes.'**
  String get badgeDetailRevokeSelfBody;

  /// No description provided for @badgeDetailRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Take it back'**
  String get badgeDetailRevokeConfirm;

  /// No description provided for @badgeDetailRevokeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Badge taken back'**
  String get badgeDetailRevokeSuccess;

  /// No description provided for @badgeDetailBlockClaimantsAction.
  ///
  /// In en, this message translates to:
  /// **'Block badge claimants'**
  String get badgeDetailBlockClaimantsAction;

  /// No description provided for @badgeDetailBlockClaimantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Block badge claimants'**
  String get badgeDetailBlockClaimantsTitle;

  /// No description provided for @badgeDetailBlockClaimantsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load claimants for this badge'**
  String get badgeDetailBlockClaimantsLoadError;

  /// No description provided for @badgeDetailBlockClaimantsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No one claims this badge right now'**
  String get badgeDetailBlockClaimantsEmptyTitle;

  /// No description provided for @badgeDetailBlockClaimantsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'We did not find any current claimants to block.'**
  String get badgeDetailBlockClaimantsEmptyBody;

  /// Full-screen confirmation heading before blocking everyone who currently claims a badge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Block 1 claimant?} other{Block {count} claimants?}}'**
  String badgeDetailBlockClaimantsHeading(int count);

  /// Full-screen confirmation body explaining the effect of blocking everyone who currently claims a badge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This blocks the account currently claiming this badge. Their posts will leave your feeds, and they will not be notified.} other{This blocks the {count} accounts currently claiming this badge. Their posts will leave your feeds, and they will not be notified.}}'**
  String badgeDetailBlockClaimantsBody(int count);

  /// Destructive confirmation button for blocking everyone who currently claims a badge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Block 1 account} other{Block {count} accounts}}'**
  String badgeDetailBlockClaimantsConfirm(int count);

  /// No description provided for @badgeDetailBlockClaimantsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Badge claimants blocked'**
  String get badgeDetailBlockClaimantsSuccess;

  /// No description provided for @badgeDetailBlockClaimantsFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not block badge claimants'**
  String get badgeDetailBlockClaimantsFailure;

  /// No description provided for @badgeDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this badge'**
  String get badgeDetailLoadError;

  /// No description provided for @badgeDetailMissing.
  ///
  /// In en, this message translates to:
  /// **'We could not find this badge on any relay.'**
  String get badgeDetailMissing;

  /// No description provided for @badgeDetailActionError.
  ///
  /// In en, this message translates to:
  /// **'That did not go through'**
  String get badgeDetailActionError;

  /// No description provided for @badgeAwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Award badge'**
  String get badgeAwardTitle;

  /// No description provided for @badgeAwardPickAction.
  ///
  /// In en, this message translates to:
  /// **'Pick people'**
  String get badgeAwardPickAction;

  /// No description provided for @badgeAwardManualLabel.
  ///
  /// In en, this message translates to:
  /// **'Or paste keys'**
  String get badgeAwardManualLabel;

  /// No description provided for @badgeAwardManualHint.
  ///
  /// In en, this message translates to:
  /// **'npub1…, npub1…'**
  String get badgeAwardManualHint;

  /// No description provided for @badgeAwardEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one person.'**
  String get badgeAwardEmptyHint;

  /// Confirm button on the award badge screen, counting the selected recipients.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Award badge} =1{Award to 1 person} other{Award to {count} people}}'**
  String badgeAwardSubmitAction(int count);

  /// No description provided for @profileBadgeAwardedBy.
  ///
  /// In en, this message translates to:
  /// **'Awarded by'**
  String get profileBadgeAwardedBy;

  /// No description provided for @profileBadgeRecipients.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get profileBadgeRecipients;

  /// Shown in the profile badge detail sheet when an award has more recipients than are displayed.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String profileBadgeMoreRecipients(int count);

  /// Accessibility label for a tappable profile badge chip.
  ///
  /// In en, this message translates to:
  /// **'{name} badge'**
  String profileBadgeSemanticLabel(String name);

  /// No description provided for @profileBadgeFallbackSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get profileBadgeFallbackSemanticLabel;

  /// Short explainer at the bottom of the profile badge detail sheet, inviting people to create their own badges.
  ///
  /// In en, this message translates to:
  /// **'Badges are little awards anyone can make on Nostr. Give one to a friend, a creator, or someone who made your day.'**
  String get profileBadgeFooterBody;

  /// Button label in the profile badge detail sheet that opens the in-app badge editor.
  ///
  /// In en, this message translates to:
  /// **'Make your own badge'**
  String get profileBadgeFooterLink;

  /// No description provided for @minorAccountReviewWelcomePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Family guide'**
  String get minorAccountReviewWelcomePageTitle;

  /// No description provided for @minorAccountReviewWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Not 16 yet? That\'s OK.'**
  String get minorAccountReviewWelcomeTitle;

  /// No description provided for @minorAccountReviewWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'If you clicked through to this page instead of just picking the answer that got you in, that matters. It shows honesty, backbone, and real care for the people around you.\n\nRules for people under 16 vary depending on where you live. At Divine, we want families to talk it through together and decide what healthy social media use looks like.'**
  String get minorAccountReviewWelcomeBody;

  /// No description provided for @minorAccountReviewModerationTitle.
  ///
  /// In en, this message translates to:
  /// **'We need one more step'**
  String get minorAccountReviewModerationTitle;

  /// No description provided for @minorAccountReviewModerationBody.
  ///
  /// In en, this message translates to:
  /// **'We were asked to take a closer look at this account because it may belong to someone under 16. This flow keeps the next steps private and points you to the right path for your age.'**
  String get minorAccountReviewModerationBody;

  /// No description provided for @minorAccountReviewRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'The rules are not the same everywhere'**
  String get minorAccountReviewRulesTitle;

  /// No description provided for @minorAccountReviewRulesBody.
  ///
  /// In en, this message translates to:
  /// **'Different countries and regions treat teen social media use differently. That is why we ask families to slow down, check the facts, and choose the next step together.'**
  String get minorAccountReviewRulesBody;

  /// No description provided for @minorAccountReviewApproachTitle.
  ///
  /// In en, this message translates to:
  /// **'How Divine thinks about it'**
  String get minorAccountReviewApproachTitle;

  /// No description provided for @minorAccountReviewApproachBody.
  ///
  /// In en, this message translates to:
  /// **'We think healthy tech habits come from pausing, reflecting, and redirecting attention toward better things, not from spying on kids or turning parents into hall monitors. Research backs that up too.'**
  String get minorAccountReviewApproachBody;

  /// No description provided for @minorAccountReviewLearnMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'More for families'**
  String get minorAccountReviewLearnMoreTitle;

  /// No description provided for @minorAccountReviewKidsPolicyCta.
  ///
  /// In en, this message translates to:
  /// **'Read Divine\'s kids policy'**
  String get minorAccountReviewKidsPolicyCta;

  /// No description provided for @minorAccountReviewChooseAgeBandTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the path that fits'**
  String get minorAccountReviewChooseAgeBandTitle;

  /// No description provided for @minorAccountReviewUnder13Cta.
  ///
  /// In en, this message translates to:
  /// **'Under 13'**
  String get minorAccountReviewUnder13Cta;

  /// No description provided for @minorAccountReviewTeenCta.
  ///
  /// In en, this message translates to:
  /// **'Age 13-15'**
  String get minorAccountReviewTeenCta;

  /// No description provided for @minorAccountReviewFamilyResourcesBody.
  ///
  /// In en, this message translates to:
  /// **'Visit the Divine family guide for practical tips, conversation tools, and resources for helping teens use social media more safely.'**
  String get minorAccountReviewFamilyResourcesBody;

  /// No description provided for @minorAccountReviewFamilyResourcesCta.
  ///
  /// In en, this message translates to:
  /// **'Get family guides and tips'**
  String get minorAccountReviewFamilyResourcesCta;

  /// No description provided for @minorAccountReviewFooter.
  ///
  /// In en, this message translates to:
  /// **'If you are 16 or older and got sent here by mistake, contact Divine support so a real person can review it.'**
  String get minorAccountReviewFooter;

  /// No description provided for @minorAccountReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Review'**
  String get minorAccountReviewTitle;

  /// No description provided for @minorAccountReviewCheckingStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Checking account status...'**
  String get minorAccountReviewCheckingStatusTitle;

  /// No description provided for @minorAccountReviewCheckingStatusBody.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we confirm this account\'s current review status.'**
  String get minorAccountReviewCheckingStatusBody;

  /// No description provided for @minorAccountReviewDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Account review required'**
  String get minorAccountReviewDefaultTitle;

  /// No description provided for @minorAccountReviewDefaultBody.
  ///
  /// In en, this message translates to:
  /// **'We need to review this account before it can use Divine normally.'**
  String get minorAccountReviewDefaultBody;

  /// No description provided for @minorAccountReviewCaseId.
  ///
  /// In en, this message translates to:
  /// **'Case ID: {caseId}'**
  String minorAccountReviewCaseId(String caseId);

  /// No description provided for @minorAccountReviewCaseIdShortLabel.
  ///
  /// In en, this message translates to:
  /// **'Case ID'**
  String get minorAccountReviewCaseIdShortLabel;

  /// No description provided for @minorAccountReviewRestrictionsTitle.
  ///
  /// In en, this message translates to:
  /// **'What is restricted right now'**
  String get minorAccountReviewRestrictionsTitle;

  /// No description provided for @minorAccountReviewRestrictionPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting and publishing are paused'**
  String get minorAccountReviewRestrictionPosting;

  /// No description provided for @minorAccountReviewRestrictionEngagement.
  ///
  /// In en, this message translates to:
  /// **'Comments, likes, reposts, and follows are paused'**
  String get minorAccountReviewRestrictionEngagement;

  /// No description provided for @minorAccountReviewRestrictionMessaging.
  ///
  /// In en, this message translates to:
  /// **'Starting or replying to regular messages is paused'**
  String get minorAccountReviewRestrictionMessaging;

  /// No description provided for @minorAccountReviewRestrictionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support and your moderation message remain available'**
  String get minorAccountReviewRestrictionSupport;

  /// Heading that explains how a restricted minor's existing videos are handled during and after review.
  ///
  /// In en, this message translates to:
  /// **'What happens to your videos'**
  String get minorAccountReviewContentTitle;

  /// Explains that existing videos are hidden during review, restored after clearance, and deleted if an unanswered review closes.
  ///
  /// In en, this message translates to:
  /// **'Your videos are hidden while this review is open. If your account is cleared, they come back. If the review closes without a response, your account is closed and your videos are deleted.'**
  String get minorAccountReviewContentBody;

  /// No description provided for @minorAccountReviewResponseClockRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to respond'**
  String get minorAccountReviewResponseClockRunningTitle;

  /// No description provided for @minorAccountReviewResponseClockRunningDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1 {1 day} other {{days} days}} left to respond. Deadline: {date}.'**
  String minorAccountReviewResponseClockRunningDays(int days, String date);

  /// No description provided for @minorAccountReviewResponseClockRunningHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1 {1 hour} other {{hours} hours}} left to respond. Deadline: {date}.'**
  String minorAccountReviewResponseClockRunningHours(int hours, String date);

  /// No description provided for @minorAccountReviewResponseClockPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Response clock paused'**
  String get minorAccountReviewResponseClockPausedTitle;

  /// No description provided for @minorAccountReviewResponseClockPausedBody.
  ///
  /// In en, this message translates to:
  /// **'The response clock is paused. About {days, plural, =1 {1 day} other {{days} days}} will remain when it restarts.'**
  String minorAccountReviewResponseClockPausedBody(int days);

  /// No description provided for @minorAccountReviewResponseClockExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Response deadline passed'**
  String get minorAccountReviewResponseClockExpiredTitle;

  /// No description provided for @minorAccountReviewResponseClockExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'The response deadline has passed. Contact Support Center if you need help.'**
  String get minorAccountReviewResponseClockExpiredBody;

  /// No description provided for @minorAccountReviewResponseClockUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Deadline unavailable'**
  String get minorAccountReviewResponseClockUnavailableTitle;

  /// No description provided for @minorAccountReviewResponseClockUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'We can\'t show your response deadline right now. Contact Support Center if you need help.'**
  String get minorAccountReviewResponseClockUnavailableBody;

  /// Heading above the support action that introduces the restricted-minor reconsideration policy. Approved wording from #8239 — do not reword without a product decision.
  ///
  /// In en, this message translates to:
  /// **'Think we got this wrong?'**
  String get minorAccountReviewAppealTitle;

  /// Tells a restricted 13-to-15-year-old how to ask support to reconsider the decision without promising a reversal. Approved wording from #8239, used verbatim.
  ///
  /// In en, this message translates to:
  /// **'Contact Support Center and tell us what happened. We’ll take another look, but we can’t promise the decision will change.'**
  String get minorAccountReviewAppealTeenBody;

  /// Tells a restricted child under 13 that a parent or guardian may ask support to reconsider the decision without promising a reversal. The approved #8239 wording with the actor changed to the parent or guardian; the promise language is unchanged.
  ///
  /// In en, this message translates to:
  /// **'Your parent or guardian can contact Support Center and tell us what happened. We’ll take another look, but we can’t promise the decision will change.'**
  String get minorAccountReviewAppealUnder13Body;

  /// No description provided for @minorAccountReviewOpenSupportCenter.
  ///
  /// In en, this message translates to:
  /// **'Open Support Center'**
  String get minorAccountReviewOpenSupportCenter;

  /// No description provided for @minorAccountReviewOpenModerationMessage.
  ///
  /// In en, this message translates to:
  /// **'Open Moderation Message'**
  String get minorAccountReviewOpenModerationMessage;

  /// No description provided for @minorAccountReviewOpenReviewPage.
  ///
  /// In en, this message translates to:
  /// **'Open review page'**
  String get minorAccountReviewOpenReviewPage;

  /// No description provided for @minorAccountReviewCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check Again'**
  String get minorAccountReviewCheckAgain;

  /// No description provided for @minorAccountReviewLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get minorAccountReviewLogOut;

  /// No description provided for @minorAccountReviewNextStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get minorAccountReviewNextStepTitle;

  /// No description provided for @minorAccountReviewNextStepBody.
  ///
  /// In en, this message translates to:
  /// **'Open the support center or your moderation message if you need help with this review.'**
  String get minorAccountReviewNextStepBody;

  /// No description provided for @minorAccountReviewInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Review in progress'**
  String get minorAccountReviewInProgressTitle;

  /// No description provided for @minorAccountReviewInProgressBody.
  ///
  /// In en, this message translates to:
  /// **'We have what we need for now. Our team is reviewing this case before restoring normal account access.'**
  String get minorAccountReviewInProgressBody;

  /// No description provided for @minorAccountReviewUnder13Title.
  ///
  /// In en, this message translates to:
  /// **'Under-13 accounts'**
  String get minorAccountReviewUnder13Title;

  /// No description provided for @minorAccountReviewUnder13Body.
  ///
  /// In en, this message translates to:
  /// **'If this account belongs to someone under 13, a parent or guardian must email {supportEmail} and include the case ID.'**
  String minorAccountReviewUnder13Body(String supportEmail);

  /// No description provided for @minorAccountReviewUnder13PublicTitle.
  ///
  /// In en, this message translates to:
  /// **'We can\'t give you an account yet'**
  String get minorAccountReviewUnder13PublicTitle;

  /// No description provided for @minorAccountReviewUnder13PublicBody.
  ///
  /// In en, this message translates to:
  /// **'Divine isn\'t built for kids under 13 and the social media rules around the world tie our hands.\n\nA lot of things on the internet push you to lie to get what you want, and we hate that. It\'s the wrong lesson for life, and we\'re not going to teach it to you here.'**
  String get minorAccountReviewUnder13PublicBody;

  /// No description provided for @minorAccountReviewUnder13FamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'What your family can do instead'**
  String get minorAccountReviewUnder13FamilyTitle;

  /// No description provided for @minorAccountReviewUnder13FamilyBody.
  ///
  /// In en, this message translates to:
  /// **'A parent or guardian can hold the account and do the posting, and you can absolutely be in the videos with them. We want families to enjoy Divine in whatever way is right for them.'**
  String get minorAccountReviewUnder13FamilyBody;

  /// No description provided for @minorAccountReviewUnder13ComeBackTitle.
  ///
  /// In en, this message translates to:
  /// **'When you turn 13'**
  String get minorAccountReviewUnder13ComeBackTitle;

  /// No description provided for @minorAccountReviewUnder13ComeBackBody.
  ///
  /// In en, this message translates to:
  /// **'Depending on the rules where you live, you may be able to come back and apply for your own account. In that case, if you’re between 13 and 15, you’ll need consent from a parent or guardian.'**
  String get minorAccountReviewUnder13ComeBackBody;

  /// No description provided for @minorAccountReviewUnder13HonestyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why we won\'t tell you to just click back'**
  String get minorAccountReviewUnder13HonestyTitle;

  /// No description provided for @minorAccountReviewUnder13HonestyBody.
  ///
  /// In en, this message translates to:
  /// **'A lot of the internet is set up to reward people for saying whatever gets them through the gate. We don\'t think that\'s great. Yes, you could go back and say you\'re older than you are, but that wouldn\'t be honest, and we\'re not going to coach you into lying to get what you want.'**
  String get minorAccountReviewUnder13HonestyBody;

  /// No description provided for @minorAccountReviewUnder13LegalBody.
  ///
  /// In en, this message translates to:
  /// **'We\'re trying to help young people use Divine in ways that are healthy and positive for them and the people around them. We also have to follow laws that are different in different places. So, if you\'re under 13, the answer is that you can\'t have your own account today.'**
  String get minorAccountReviewUnder13LegalBody;

  /// No description provided for @minorAccountReviewTeenBody.
  ///
  /// In en, this message translates to:
  /// **'If this account belongs to someone 13 to 15, use the moderation message or support path to follow the parental consent instructions.'**
  String get minorAccountReviewTeenBody;

  /// No description provided for @minorAccountReviewParentConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'If the account will belong to someone 13 to 15'**
  String get minorAccountReviewParentConsentTitle;

  /// No description provided for @minorAccountReviewParentConsentBody.
  ///
  /// In en, this message translates to:
  /// **'A parent or guardian should email Divine support with a short private video. Our team will review it and help with next steps.\n\nIf parent or guardian contact is not possible or would put someone at risk, email Divine support and let us know.'**
  String get minorAccountReviewParentConsentBody;

  /// No description provided for @minorAccountReviewParentConsentPauseNote.
  ///
  /// In en, this message translates to:
  /// **'This is a pause while the Divine support team reviews the video. If it is approved, they will guide you through setting up the new account.'**
  String get minorAccountReviewParentConsentPauseNote;

  /// No description provided for @minorAccountReviewParentConsentHonestyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why we ask a parent or guardian to be involved'**
  String get minorAccountReviewParentConsentHonestyTitle;

  /// No description provided for @minorAccountReviewParentConsentHonestyBody.
  ///
  /// In en, this message translates to:
  /// **'Divine has to follow age-related laws around the world. We also know that most technical age gates are imperfect. Rather than pretending the rules don\'t exist or that it\'s cool to lie about your age, we want teens and families to make thoughtful decisions about how best to use Divine. That\'s why, for 13-15 year olds, we ask parents to be part of the account creation process.'**
  String get minorAccountReviewParentConsentHonestyBody;

  /// No description provided for @minorAccountReviewParentConsentLegalBody.
  ///
  /// In en, this message translates to:
  /// **'We also have to follow the law, and those rules are different depending on where someone lives. So instead of pretending the rules do not exist, we ask for a parent or guardian to be part of the process.'**
  String get minorAccountReviewParentConsentLegalBody;

  /// No description provided for @minorAccountReviewParentConsentChecklist.
  ///
  /// In en, this message translates to:
  /// **'What the video should show'**
  String get minorAccountReviewParentConsentChecklist;

  /// No description provided for @minorAccountReviewParentConsentChecklistKid.
  ///
  /// In en, this message translates to:
  /// **'The teen in the video'**
  String get minorAccountReviewParentConsentChecklistKid;

  /// No description provided for @minorAccountReviewParentConsentChecklistPermission.
  ///
  /// In en, this message translates to:
  /// **'A parent or guardian speaking on camera'**
  String get minorAccountReviewParentConsentChecklistPermission;

  /// No description provided for @minorAccountReviewParentConsentChecklistAgeBand.
  ///
  /// In en, this message translates to:
  /// **'A clear statement that the teen is 13 to 15 and has permission to use Divine'**
  String get minorAccountReviewParentConsentChecklistAgeBand;

  /// No description provided for @minorAccountReviewParentConsentChecklistSupervision.
  ///
  /// In en, this message translates to:
  /// **'A clear statement that the parent or guardian knows about the account and will supervise its use'**
  String get minorAccountReviewParentConsentChecklistSupervision;

  /// No description provided for @minorAccountReviewParentConsentPrivacy.
  ///
  /// In en, this message translates to:
  /// **'How to send it'**
  String get minorAccountReviewParentConsentPrivacy;

  /// No description provided for @minorAccountReviewParentConsentNeverPost.
  ///
  /// In en, this message translates to:
  /// **'Attach the video when you email Divine support'**
  String get minorAccountReviewParentConsentNeverPost;

  /// No description provided for @minorAccountReviewParentConsentDoNotSave.
  ///
  /// In en, this message translates to:
  /// **'Keep the video private and do not post it in the app'**
  String get minorAccountReviewParentConsentDoNotSave;

  /// No description provided for @minorAccountReviewParentConsentOneMove.
  ///
  /// In en, this message translates to:
  /// **'Our team will review it and reply with next steps'**
  String get minorAccountReviewParentConsentOneMove;

  /// No description provided for @minorAccountReviewParentConsentEmailCta.
  ///
  /// In en, this message translates to:
  /// **'Email Divine support'**
  String get minorAccountReviewParentConsentEmailCta;

  /// No description provided for @minorAccountReviewParentConsentEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Divine Greenlight review help (ages 13-15)'**
  String get minorAccountReviewParentConsentEmailSubject;

  /// No description provided for @minorAccountReviewParentConsentEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Hi Divine support,\n\nI am contacting Divine about Divine Greenlight for a teen who is 13-15.\n\nI have attached a short private video that shows:\n- the teen\n- a parent or guardian speaking on camera\n- that the teen has permission to use Divine\n- that the parent or guardian knows about the account and will supervise its use\n\nCountry/ies of residence:\n\nHelpful context:\n\nThanks.'**
  String get minorAccountReviewParentConsentEmailBody;

  /// No description provided for @minorAccountReviewParentSupportInstructions.
  ///
  /// In en, this message translates to:
  /// **'Parent Support Instructions'**
  String get minorAccountReviewParentSupportInstructions;

  /// No description provided for @minorAccountReviewContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get minorAccountReviewContinue;

  /// No description provided for @minorAccountReviewErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'We could not load your account review status.'**
  String get minorAccountReviewErrorTitle;

  /// No description provided for @minorAccountReviewErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get minorAccountReviewErrorBody;

  /// No description provided for @minorAccountReviewTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get minorAccountReviewTryAgain;

  /// No description provided for @minorAccountReviewParentContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Contact'**
  String get minorAccountReviewParentContactTitle;

  /// No description provided for @minorAccountReviewParentContactHeading.
  ///
  /// In en, this message translates to:
  /// **'Add a parent or guardian email'**
  String get minorAccountReviewParentContactHeading;

  /// No description provided for @minorAccountReviewParentContactBody.
  ///
  /// In en, this message translates to:
  /// **'We will use this address for the parental consent review on case {caseId}.'**
  String minorAccountReviewParentContactBody(String caseId);

  /// No description provided for @minorAccountReviewParentContactFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent or guardian email'**
  String get minorAccountReviewParentContactFieldLabel;

  /// No description provided for @minorAccountReviewSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get minorAccountReviewSubmitting;

  /// No description provided for @minorAccountReviewSubmitEmail.
  ///
  /// In en, this message translates to:
  /// **'Submit Email'**
  String get minorAccountReviewSubmitEmail;

  /// No description provided for @minorAccountReviewBackToReview.
  ///
  /// In en, this message translates to:
  /// **'Back to Account Review'**
  String get minorAccountReviewBackToReview;

  /// No description provided for @minorAccountReviewSubmissionReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Email submitted'**
  String get minorAccountReviewSubmissionReceivedTitle;

  /// No description provided for @minorAccountReviewSubmissionReceivedBody.
  ///
  /// In en, this message translates to:
  /// **'We submitted {email} for review. We\'ll email this address to confirm. Once your parent or guardian responds, your case will move forward. Use Check Again from the account review screen for updates.'**
  String minorAccountReviewSubmissionReceivedBody(String email);

  /// No description provided for @minorAccountReviewSubmissionReceivedLocalBody.
  ///
  /// In en, this message translates to:
  /// **'We received the parent or guardian contact for this account. Our team will review it before restoring access.'**
  String get minorAccountReviewSubmissionReceivedLocalBody;

  /// No description provided for @minorAccountReviewMissingCase.
  ///
  /// In en, this message translates to:
  /// **'We could not find an active review case for this account.'**
  String get minorAccountReviewMissingCase;

  /// No description provided for @minorAccountReviewParentContactError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit the parent email. Please try again.'**
  String get minorAccountReviewParentContactError;

  /// No description provided for @minorAccountReviewUnder13SupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Support'**
  String get minorAccountReviewUnder13SupportTitle;

  /// No description provided for @minorAccountReviewUnder13Heading.
  ///
  /// In en, this message translates to:
  /// **'A parent or guardian must contact Divine'**
  String get minorAccountReviewUnder13Heading;

  /// No description provided for @minorAccountReviewUnder13SupportBody.
  ///
  /// In en, this message translates to:
  /// **'For likely under-13 accounts, the next step is parent or guardian contact by email.'**
  String get minorAccountReviewUnder13SupportBody;

  /// No description provided for @minorAccountReviewSupportEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Support email'**
  String get minorAccountReviewSupportEmailLabel;

  /// No description provided for @minorAccountReviewCopySupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Copy support email'**
  String get minorAccountReviewCopySupportEmail;

  /// No description provided for @minorAccountReviewSupportEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Support email copied'**
  String get minorAccountReviewSupportEmailCopied;

  /// No description provided for @minorAccountReviewCopyCaseId.
  ///
  /// In en, this message translates to:
  /// **'Copy case ID'**
  String get minorAccountReviewCopyCaseId;

  /// No description provided for @minorAccountReviewCaseIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Case ID copied'**
  String get minorAccountReviewCaseIdCopied;

  /// No description provided for @minorAccountReviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get minorAccountReviewUnavailable;

  /// No description provided for @minorAccountReviewUnder13Instructions.
  ///
  /// In en, this message translates to:
  /// **'Ask the parent or guardian to include the case ID and explain that they are contacting Divine about this account review.'**
  String get minorAccountReviewUnder13Instructions;

  /// No description provided for @minorAccountReviewUnder13EmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Under-13 account review for case {caseId}'**
  String minorAccountReviewUnder13EmailSubject(String caseId);

  /// No description provided for @minorAccountReviewUnder13EmailBody.
  ///
  /// In en, this message translates to:
  /// **'Hi Divine support,\n\nI am the parent or guardian for a child under 13 and I am contacting Divine about account review case {caseId}.\n\nThanks.'**
  String minorAccountReviewUnder13EmailBody(String caseId);

  /// No description provided for @devOptionsMinorReviewSimulationTitle.
  ///
  /// In en, this message translates to:
  /// **'Minor Account Review Simulation'**
  String get devOptionsMinorReviewSimulationTitle;

  /// No description provided for @devOptionsMinorReviewCurrentStateLabel.
  ///
  /// In en, this message translates to:
  /// **'Current state'**
  String get devOptionsMinorReviewCurrentStateLabel;

  /// No description provided for @devOptionsMinorReviewStateRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted ({state})'**
  String devOptionsMinorReviewStateRestricted(String state);

  /// No description provided for @devOptionsMinorReviewStateActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get devOptionsMinorReviewStateActive;

  /// No description provided for @devOptionsMinorReviewStateLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get devOptionsMinorReviewStateLoading;

  /// No description provided for @devOptionsMinorReviewStateError.
  ///
  /// In en, this message translates to:
  /// **'Error loading state'**
  String get devOptionsMinorReviewStateError;

  /// No description provided for @devOptionsMinorReviewClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear simulation override'**
  String get devOptionsMinorReviewClearTitle;

  /// No description provided for @devOptionsMinorReviewClearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use backend or default active state again'**
  String get devOptionsMinorReviewClearSubtitle;

  /// No description provided for @devOptionsMinorReviewTeenTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate 13-15 review case'**
  String get devOptionsMinorReviewTeenTitle;

  /// No description provided for @devOptionsMinorReviewTeenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restricted account with parent contact path'**
  String get devOptionsMinorReviewTeenSubtitle;

  /// No description provided for @devOptionsMinorReviewUnder13Title.
  ///
  /// In en, this message translates to:
  /// **'Simulate under-13 support case'**
  String get devOptionsMinorReviewUnder13Title;

  /// No description provided for @devOptionsMinorReviewUnder13Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Restricted account with parent-email-only instructions'**
  String get devOptionsMinorReviewUnder13Subtitle;

  /// No description provided for @devOptionsMinorReviewClearedToast.
  ///
  /// In en, this message translates to:
  /// **'Minor account review simulation cleared'**
  String get devOptionsMinorReviewClearedToast;

  /// No description provided for @devOptionsMinorReviewUnder13EnabledToast.
  ///
  /// In en, this message translates to:
  /// **'Simulated under-13 support case enabled'**
  String get devOptionsMinorReviewUnder13EnabledToast;

  /// No description provided for @devOptionsMinorReviewResponseClockTitle.
  ///
  /// In en, this message translates to:
  /// **'Response clock'**
  String get devOptionsMinorReviewResponseClockTitle;

  /// No description provided for @devOptionsMinorReviewResponseClockRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get devOptionsMinorReviewResponseClockRunning;

  /// No description provided for @devOptionsMinorReviewResponseClockPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get devOptionsMinorReviewResponseClockPaused;

  /// No description provided for @devOptionsMinorReviewResponseClockExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get devOptionsMinorReviewResponseClockExpired;

  /// No description provided for @devOptionsMinorReviewResponseClockNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Not applicable'**
  String get devOptionsMinorReviewResponseClockNotApplicable;

  /// No description provided for @devOptionsMinorReviewResponseClockMalformed.
  ///
  /// In en, this message translates to:
  /// **'Malformed payload'**
  String get devOptionsMinorReviewResponseClockMalformed;

  /// No description provided for @devOptionsMinorReviewResponseClockRunningToast.
  ///
  /// In en, this message translates to:
  /// **'Simulated running response clock'**
  String get devOptionsMinorReviewResponseClockRunningToast;

  /// No description provided for @devOptionsMinorReviewResponseClockPausedToast.
  ///
  /// In en, this message translates to:
  /// **'Simulated paused response clock'**
  String get devOptionsMinorReviewResponseClockPausedToast;

  /// No description provided for @devOptionsMinorReviewResponseClockExpiredToast.
  ///
  /// In en, this message translates to:
  /// **'Simulated expired response clock'**
  String get devOptionsMinorReviewResponseClockExpiredToast;

  /// No description provided for @devOptionsMinorReviewResponseClockNotApplicableToast.
  ///
  /// In en, this message translates to:
  /// **'Simulated not-applicable response clock'**
  String get devOptionsMinorReviewResponseClockNotApplicableToast;

  /// No description provided for @devOptionsMinorReviewResponseClockMalformedToast.
  ///
  /// In en, this message translates to:
  /// **'Simulated malformed response clock'**
  String get devOptionsMinorReviewResponseClockMalformedToast;

  /// No description provided for @devOptionsProtectedMinorSimulationTitle.
  ///
  /// In en, this message translates to:
  /// **'Protected Minor Simulation'**
  String get devOptionsProtectedMinorSimulationTitle;

  /// No description provided for @devOptionsProtectedMinorCurrentStateLabel.
  ///
  /// In en, this message translates to:
  /// **'Current state'**
  String get devOptionsProtectedMinorCurrentStateLabel;

  /// No description provided for @devOptionsProtectedMinorStateProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected minor (13-15)'**
  String get devOptionsProtectedMinorStateProtected;

  /// No description provided for @devOptionsProtectedMinorStateNotProtected.
  ///
  /// In en, this message translates to:
  /// **'Not protected'**
  String get devOptionsProtectedMinorStateNotProtected;

  /// No description provided for @devOptionsProtectedMinorStateLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get devOptionsProtectedMinorStateLoading;

  /// No description provided for @devOptionsProtectedMinorStateError.
  ///
  /// In en, this message translates to:
  /// **'Error reading state'**
  String get devOptionsProtectedMinorStateError;

  /// No description provided for @devOptionsProtectedMinorOverrideNone.
  ///
  /// In en, this message translates to:
  /// **'No override (real account state)'**
  String get devOptionsProtectedMinorOverrideNone;

  /// No description provided for @devOptionsProtectedMinorOverrideProtected.
  ///
  /// In en, this message translates to:
  /// **'Override: forced protected'**
  String get devOptionsProtectedMinorOverrideProtected;

  /// No description provided for @devOptionsProtectedMinorOverrideNotProtected.
  ///
  /// In en, this message translates to:
  /// **'Override: forced not protected'**
  String get devOptionsProtectedMinorOverrideNotProtected;

  /// No description provided for @devOptionsProtectedMinorSimulateTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate protected minor (13-15)'**
  String get devOptionsProtectedMinorSimulateTitle;

  /// No description provided for @devOptionsProtectedMinorSimulateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Force the protected-minor state to QA the #175/#176 protections'**
  String get devOptionsProtectedMinorSimulateSubtitle;

  /// No description provided for @devOptionsProtectedMinorSimulateNonMinorTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate non-minor'**
  String get devOptionsProtectedMinorSimulateNonMinorTitle;

  /// No description provided for @devOptionsProtectedMinorSimulateNonMinorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Force not-protected (explicit negative, distinct from no override)'**
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle;

  /// No description provided for @devOptionsProtectedMinorClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear override'**
  String get devOptionsProtectedMinorClearTitle;

  /// No description provided for @devOptionsProtectedMinorClearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Return to the real Keycast-driven account state'**
  String get devOptionsProtectedMinorClearSubtitle;

  /// No description provided for @devOptionsProtectedMinorEnabledToast.
  ///
  /// In en, this message translates to:
  /// **'Protected-minor state forced on'**
  String get devOptionsProtectedMinorEnabledToast;

  /// No description provided for @devOptionsProtectedMinorNonMinorToast.
  ///
  /// In en, this message translates to:
  /// **'Protected-minor state forced off'**
  String get devOptionsProtectedMinorNonMinorToast;

  /// No description provided for @devOptionsProtectedMinorClearedToast.
  ///
  /// In en, this message translates to:
  /// **'Protected-minor override cleared'**
  String get devOptionsProtectedMinorClearedToast;

  /// No description provided for @devOptionsInviteAvailabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Signup invites'**
  String get devOptionsInviteAvailabilityTitle;

  /// No description provided for @devOptionsInviteAvailabilityCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current state'**
  String get devOptionsInviteAvailabilityCurrentLabel;

  /// No description provided for @devOptionsInviteAvailabilityServerLoading.
  ///
  /// In en, this message translates to:
  /// **'Server value: loading'**
  String get devOptionsInviteAvailabilityServerLoading;

  /// No description provided for @devOptionsInviteAvailabilityServerEnabled.
  ///
  /// In en, this message translates to:
  /// **'Server value: enabled'**
  String get devOptionsInviteAvailabilityServerEnabled;

  /// No description provided for @devOptionsInviteAvailabilityServerDisabled.
  ///
  /// In en, this message translates to:
  /// **'Server value: disabled'**
  String get devOptionsInviteAvailabilityServerDisabled;

  /// No description provided for @devOptionsInviteAvailabilityServerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Server value: unknown'**
  String get devOptionsInviteAvailabilityServerUnknown;

  /// No description provided for @devOptionsInviteAvailabilityOverrideNone.
  ///
  /// In en, this message translates to:
  /// **'Override: use server value'**
  String get devOptionsInviteAvailabilityOverrideNone;

  /// No description provided for @devOptionsInviteAvailabilityOverrideEnabled.
  ///
  /// In en, this message translates to:
  /// **'Override: force enabled'**
  String get devOptionsInviteAvailabilityOverrideEnabled;

  /// No description provided for @devOptionsInviteAvailabilityOverrideDisabled.
  ///
  /// In en, this message translates to:
  /// **'Override: force disabled'**
  String get devOptionsInviteAvailabilityOverrideDisabled;

  /// No description provided for @devOptionsInviteAvailabilityUseServer.
  ///
  /// In en, this message translates to:
  /// **'Use server value'**
  String get devOptionsInviteAvailabilityUseServer;

  /// No description provided for @devOptionsInviteAvailabilityUseServerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow the invite service onboardingMode'**
  String get devOptionsInviteAvailabilityUseServerSubtitle;

  /// No description provided for @devOptionsInviteAvailabilityForceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Force enabled'**
  String get devOptionsInviteAvailabilityForceEnabled;

  /// No description provided for @devOptionsInviteAvailabilityForceEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show signup invite gates and management locally'**
  String get devOptionsInviteAvailabilityForceEnabledSubtitle;

  /// No description provided for @devOptionsInviteAvailabilityForceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Force disabled'**
  String get devOptionsInviteAvailabilityForceDisabled;

  /// No description provided for @devOptionsInviteAvailabilityForceDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide signup invite UI locally without changing the server'**
  String get devOptionsInviteAvailabilityForceDisabledSubtitle;

  /// No description provided for @devOptionsInviteAvailabilityUseServerToast.
  ///
  /// In en, this message translates to:
  /// **'Signup invites now follow the server'**
  String get devOptionsInviteAvailabilityUseServerToast;

  /// No description provided for @devOptionsInviteAvailabilityForceEnabledToast.
  ///
  /// In en, this message translates to:
  /// **'Signup invites forced on'**
  String get devOptionsInviteAvailabilityForceEnabledToast;

  /// No description provided for @devOptionsInviteAvailabilityForceDisabledToast.
  ///
  /// In en, this message translates to:
  /// **'Signup invites forced off'**
  String get devOptionsInviteAvailabilityForceDisabledToast;

  /// Semantics label for the button that opens the recorder to create a video reply in comments.
  ///
  /// In en, this message translates to:
  /// **'Record video comment'**
  String get commentsRecordVideoButtonLabel;

  /// Semantics label for the button that opens an inline video reply in the full video detail route.
  ///
  /// In en, this message translates to:
  /// **'Open video comment'**
  String get commentsOpenVideoLabel;

  /// Semantics label for the button that mutes inline video comment playback.
  ///
  /// In en, this message translates to:
  /// **'Mute video reply'**
  String get commentsMuteVideoReplyLabel;

  /// Semantics label for the button that unmutes inline video comment playback.
  ///
  /// In en, this message translates to:
  /// **'Unmute video reply'**
  String get commentsUnmuteVideoReplyLabel;

  /// Semantics label for the UI that opens the parent video for a video reply.
  ///
  /// In en, this message translates to:
  /// **'Open video this replies to'**
  String get commentsOpenReplyParentLabel;

  /// Section title shown above the parent video label for a video reply.
  ///
  /// In en, this message translates to:
  /// **'In reply to'**
  String get commentsReplyParentSectionTitle;

  /// Label describing the parent video a reply points to.
  ///
  /// In en, this message translates to:
  /// **'Reply to {target}'**
  String commentsReplyParentLabel(String target);

  /// Fallback label when the parent video has no title, author name, or usable content.
  ///
  /// In en, this message translates to:
  /// **'Reply to video'**
  String get commentsReplyParentFallbackLabel;

  /// Screen reader label for a verified-account chip on a user's profile.
  ///
  /// In en, this message translates to:
  /// **'Verified {platform} account: {identity}'**
  String verifiedAccountChipSemanticLabel(String platform, String identity);

  /// Section header on the edit profile screen above the verified-accounts chip row and the Get verified CTA.
  ///
  /// In en, this message translates to:
  /// **'Verified accounts'**
  String get profileEditVerifiedAccountsTitle;

  /// Primary CTA tile on edit profile that opens the verifier integrated-app sandbox.
  ///
  /// In en, this message translates to:
  /// **'Get verified'**
  String get profileEditGetVerifiedCta;

  /// Subtitle under the Get verified tile, harmonized with verifier.divine.video landing copy.
  ///
  /// In en, this message translates to:
  /// **'Link your social media accounts so people know it\'s really you.'**
  String get profileEditGetVerifiedSubtitle;

  /// Screen reader label for the website link row on a user's profile.
  ///
  /// In en, this message translates to:
  /// **'Visit website: {url}'**
  String profileWebsiteSemanticLabel(String url);

  /// Snackbar message shown when url_launcher fails to open the profile website link.
  ///
  /// In en, this message translates to:
  /// **'Could not open website'**
  String get profileCouldNotOpenWebsite;

  /// No description provided for @videoMetadataEditCoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit cover'**
  String get videoMetadataEditCoverTitle;

  /// No description provided for @videoMetadataEditCoverCloseSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Discard cover changes'**
  String get videoMetadataEditCoverCloseSemanticLabel;

  /// No description provided for @videoMetadataEditCoverConfirmSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Use selected frame as video cover'**
  String get videoMetadataEditCoverConfirmSemanticLabel;

  /// No description provided for @videoMetadataEditCoverStripSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Seek through video to select cover frame'**
  String get videoMetadataEditCoverStripSemanticLabel;

  /// No description provided for @videoMetadataTagsPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search or add tags'**
  String get videoMetadataTagsPickerSearchHint;

  /// No description provided for @videoMetadataTagsPickerEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add tags to help people discover your video'**
  String get videoMetadataTagsPickerEmptyHint;

  /// No description provided for @videoMetadataTagsPickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching tags'**
  String get videoMetadataTagsPickerNoResults;

  /// No description provided for @videoMetadataTagsPickerAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add \"#{tag}\"'**
  String videoMetadataTagsPickerAddTag(String tag);

  /// Welcome-screen Divine Greenlight label above the sign-in / create-account buttons.
  ///
  /// In en, this message translates to:
  /// **'Divine Greenlight'**
  String get authMinAgeNotice;

  /// Lead-in white text rendered on the welcome screen immediately before the green 'Here are your choices.' link.
  ///
  /// In en, this message translates to:
  /// **'Not 16 yet? That\'s OK. '**
  String get authUnder16Prefix;

  /// Inline green call-to-action on the welcome screen that opens the family-guidance flow for under-16 users.
  ///
  /// In en, this message translates to:
  /// **'Here are your choices.'**
  String get authUnder16ChoicesCta;

  /// No description provided for @minorAccountReviewUnder13WhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Here\'s why'**
  String get minorAccountReviewUnder13WhyTitle;

  /// No description provided for @generalSettingsHoldToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record'**
  String get generalSettingsHoldToRecord;

  /// No description provided for @generalSettingsHoldToRecordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start recording when you press and hold, then stop when you release'**
  String get generalSettingsHoldToRecordSubtitle;

  /// Snackbar shown after one or more background uploads succeed, e.g. after a re-auth redirect during which uploads completed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Video published to your profile} other{{count} videos published to your profile}}'**
  String uploadPublishedCountMessage(int count);

  /// Screen-reader label for the send button at the bottom of a DM conversation.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get dmMessageSendLabel;

  /// Hint text in the search field of the full emoji picker opened from the DM reaction '+' button.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get emojiPickerSearchHint;

  /// Title for the 'Recent' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get emojiCategoryRecent;

  /// Title for the 'Smileys & People' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Smileys & People'**
  String get emojiCategorySmileys;

  /// Title for the 'Animals & Nature' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Animals & Nature'**
  String get emojiCategoryAnimals;

  /// Title for the 'Food & Drink' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Food & Drink'**
  String get emojiCategoryFood;

  /// Title for the 'Activities' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get emojiCategoryActivities;

  /// Title for the 'Travel & Places' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Travel & Places'**
  String get emojiCategoryTravel;

  /// Title for the 'Objects' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get emojiCategoryObjects;

  /// Title for the 'Symbols' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Symbols'**
  String get emojiCategorySymbols;

  /// Title for the 'Flags' category in the full emoji picker.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get emojiCategoryFlags;

  /// No description provided for @videoEditorMarkerLabel.
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get videoEditorMarkerLabel;

  /// No description provided for @videoEditorAddTimelineMarkerSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Add timeline marker'**
  String get videoEditorAddTimelineMarkerSemanticLabel;

  /// No description provided for @videoEditorRemoveTimelineMarkerSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove timeline marker'**
  String get videoEditorRemoveTimelineMarkerSemanticLabel;

  /// Semantic label for the marker-mode bottom-bar delete button, which immediately removes the marker at the current playhead position. Distinct from videoEditorRemoveTimelineMarkerSemanticLabel (the per-marker dot, which asks for confirmation) so screen-reader users can tell the two delete controls apart.
  ///
  /// In en, this message translates to:
  /// **'Remove marker at playhead'**
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel;

  /// No description provided for @videoEditorDeleteTimelineMarkerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete marker?'**
  String get videoEditorDeleteTimelineMarkerTitle;

  /// No description provided for @videoEditorDeleteTimelineMarkerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This removes the marker from the timeline. Your edit stays intact.'**
  String get videoEditorDeleteTimelineMarkerSubtitle;

  /// Semantic long-press hint for a volume arc control. Screen readers announce this as the long-press affordance, which mutes or unmutes all timeline tracks at once.
  ///
  /// In en, this message translates to:
  /// **'Mute or unmute all tracks'**
  String get videoEditorVolumeLongPressHint;

  /// No description provided for @videoEditorSplitFailed.
  ///
  /// In en, this message translates to:
  /// **'Split failed. Please try again.'**
  String get videoEditorSplitFailed;

  /// No description provided for @videoEditEditSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Edit subtitles'**
  String get videoEditEditSubtitles;

  /// No description provided for @subtitleEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit subtitles'**
  String get subtitleEditorTitle;

  /// No description provided for @subtitleEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get subtitleEditorSave;

  /// No description provided for @subtitleEditorProcessing.
  ///
  /// In en, this message translates to:
  /// **'Subtitles are still being generated. Check back in a moment.'**
  String get subtitleEditorProcessing;

  /// No description provided for @subtitleEditorNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech was detected in this video, so there\'s nothing to caption.'**
  String get subtitleEditorNoSpeech;

  /// No description provided for @subtitleEditorWriteOwn.
  ///
  /// In en, this message translates to:
  /// **'Write them yourself'**
  String get subtitleEditorWriteOwn;

  /// No description provided for @subtitleEditorAddCue.
  ///
  /// In en, this message translates to:
  /// **'Add a line'**
  String get subtitleEditorAddCue;

  /// No description provided for @subtitleEditorRemoveCue.
  ///
  /// In en, this message translates to:
  /// **'Remove this line'**
  String get subtitleEditorRemoveCue;

  /// Shown in place of the subtitle editor's video preview when the video cannot be played, so the creator knows the captions are still editable.
  ///
  /// In en, this message translates to:
  /// **'The video can\'t be played right now, but you can still fix the captions.'**
  String get subtitleEditorPreviewUnavailable;

  /// Screen-reader label for the subtitle editor's video preview while it is paused; tapping it starts playback.
  ///
  /// In en, this message translates to:
  /// **'Play the video'**
  String get subtitleEditorPlayPreview;

  /// Screen-reader label for the subtitle editor's video preview while it is playing; tapping it pauses playback.
  ///
  /// In en, this message translates to:
  /// **'Pause the video'**
  String get subtitleEditorPausePreview;

  /// No description provided for @subtitleEditorInvalidHint.
  ///
  /// In en, this message translates to:
  /// **'Every line needs text and an end after its start.'**
  String get subtitleEditorInvalidHint;

  /// No description provided for @subtitleEditorLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load subtitles. Try again.'**
  String get subtitleEditorLoadError;

  /// No description provided for @subtitleEditorSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subtitles updated'**
  String get subtitleEditorSaveSuccess;

  /// No description provided for @subtitleEditorSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save subtitles. Try again.'**
  String get subtitleEditorSaveError;

  /// No description provided for @subtitleEditorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get subtitleEditorRetry;

  /// No description provided for @subtitleEditorCueHint.
  ///
  /// In en, this message translates to:
  /// **'Caption text'**
  String get subtitleEditorCueHint;

  /// Bottom-bar action in the image crop editor that rotates the image 90 degrees.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get imageCropEditorRotateLabel;

  /// Bottom-bar action in the image crop editor that mirrors the image horizontally.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get imageCropEditorFlipLabel;

  /// Bottom-bar action in the image crop editor that reverts all crop, rotate and flip changes.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get imageCropEditorResetLabel;

  /// Accessibility label for the close button in the image crop editor that discards changes and returns without uploading.
  ///
  /// In en, this message translates to:
  /// **'Cancel cropping'**
  String get imageCropEditorCloseSemanticLabel;

  /// Accessibility label for the done button in the image crop editor that confirms the crop and proceeds with the upload.
  ///
  /// In en, this message translates to:
  /// **'Apply crop'**
  String get imageCropEditorDoneSemanticLabel;

  /// Loading message shown while the image crop editor generates the final cropped image after the user taps done.
  ///
  /// In en, this message translates to:
  /// **'Applying crop…'**
  String get imageCropEditorProcessing;

  /// Title of the Android foreground-service notification shown while a video uploads in the background so the transfer survives app suspension.
  ///
  /// In en, this message translates to:
  /// **'Uploading video'**
  String get backgroundUploadNotificationTitle;

  /// Title for the settings screen where creators configure outbound support links.
  ///
  /// In en, this message translates to:
  /// **'Creator Support'**
  String get monetizationSettingsTitle;

  /// Subtitle for the settings row that opens creator support link settings.
  ///
  /// In en, this message translates to:
  /// **'Add tip and subscription links'**
  String get monetizationSettingsSubtitle;

  /// Heading explaining monetization links do not create in-app payments.
  ///
  /// In en, this message translates to:
  /// **'Outbound links only'**
  String get monetizationSettingsIntroTitle;

  /// Body copy explaining profile monetization links are external only.
  ///
  /// In en, this message translates to:
  /// **'Add creator-controlled destinations. Divine never handles the payment or unlocks in-app content from these links.'**
  String get monetizationSettingsIntroBody;

  /// Summary of active monetization links configured on the profile.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} active link on your profile} other{{count} active links on your profile}}'**
  String monetizationSettingsConfiguredCount(int count);

  /// Section header for one-time tip link providers.
  ///
  /// In en, this message translates to:
  /// **'Send a tip'**
  String get monetizationSettingsTipSection;

  /// Section header for recurring or creator-support link providers.
  ///
  /// In en, this message translates to:
  /// **'Subscribe / support'**
  String get monetizationSettingsSubscriptionSection;

  /// Button label to save profile monetization links.
  ///
  /// In en, this message translates to:
  /// **'Save support links'**
  String get monetizationSettingsSave;

  /// Button label while profile monetization links are saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get monetizationSettingsSaving;

  /// Snackbar shown after monetization links are saved.
  ///
  /// In en, this message translates to:
  /// **'Support links updated'**
  String get monetizationSettingsSaved;

  /// Snackbar shown when profile monetization links fail to save.
  ///
  /// In en, this message translates to:
  /// **'Could not save support links. Check your connection and try again.'**
  String get monetizationSettingsSaveFailed;

  /// Validation error for an empty monetization link input.
  ///
  /// In en, this message translates to:
  /// **'Add a handle or URL.'**
  String get monetizationSettingsErrorEmpty;

  /// Validation error for a malformed monetization link input.
  ///
  /// In en, this message translates to:
  /// **'That link does not look right.'**
  String get monetizationSettingsErrorInvalid;

  /// Validation error when a monetization link uses the wrong provider domain.
  ///
  /// In en, this message translates to:
  /// **'Use a link for this provider.'**
  String get monetizationSettingsErrorWrongProvider;

  /// Input hint for Cash App monetization link.
  ///
  /// In en, this message translates to:
  /// **'\$cashtag or cash.app link'**
  String get monetizationSettingsHintCashApp;

  /// Input hint for PayPal monetization link.
  ///
  /// In en, this message translates to:
  /// **'PayPal.me handle or link'**
  String get monetizationSettingsHintPayPal;

  /// Input hint for Venmo monetization link.
  ///
  /// In en, this message translates to:
  /// **'Venmo handle or link'**
  String get monetizationSettingsHintVenmo;

  /// Input hint for Patreon monetization link.
  ///
  /// In en, this message translates to:
  /// **'Patreon handle or link'**
  String get monetizationSettingsHintPatreon;

  /// Input hint for Substack monetization link.
  ///
  /// In en, this message translates to:
  /// **'Substack domain or link'**
  String get monetizationSettingsHintSubstack;

  /// Input hint for Medium monetization link.
  ///
  /// In en, this message translates to:
  /// **'Medium handle or link'**
  String get monetizationSettingsHintMedium;

  /// Input hint for Open Collective monetization link.
  ///
  /// In en, this message translates to:
  /// **'Open Collective slug or link'**
  String get monetizationSettingsHintOpenCollective;

  /// Title for the profile support links bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Support this creator'**
  String get profileSupportSheetTitle;

  /// Policy copy in the profile support links bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'These links open outside Divine. Nothing here unlocks content in the app.'**
  String get profileSupportSheetBody;

  /// Section header for tip links in the profile support sheet.
  ///
  /// In en, this message translates to:
  /// **'Send a tip'**
  String get profileSupportTipSection;

  /// Section header for subscription links in the profile support sheet.
  ///
  /// In en, this message translates to:
  /// **'Subscribe / support'**
  String get profileSupportSubscriptionSection;

  /// Compact button label on a profile that opens creator support links.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSupportButtonLabel;

  /// App Store-safe title for the settings screen where creators configure optional tip links.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get monetizationTipsSettingsTitle;

  /// App Store-safe subtitle for the settings row that opens optional tip link settings.
  ///
  /// In en, this message translates to:
  /// **'Add optional tip links'**
  String get monetizationTipsSettingsSubtitle;

  /// App Store-safe heading explaining tip links are optional user-to-user gifts.
  ///
  /// In en, this message translates to:
  /// **'Optional tips only'**
  String get monetizationTipsSettingsIntroTitle;

  /// App Store-safe body copy explaining tips do not unlock digital content or services.
  ///
  /// In en, this message translates to:
  /// **'Tips are optional user-to-user gifts. They do not unlock content, subscriptions, features, ranking, visibility, or access in Divine.'**
  String get monetizationTipsSettingsIntroBody;

  /// App Store-safe summary of active tip links configured on the profile.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} active tip link on your profile} other{{count} active tip links on your profile}}'**
  String monetizationTipsSettingsConfiguredCount(int count);

  /// App Store-safe button label to save optional tip links.
  ///
  /// In en, this message translates to:
  /// **'Save tip links'**
  String get monetizationTipsSettingsSave;

  /// App Store-safe snackbar shown after optional tip links are saved.
  ///
  /// In en, this message translates to:
  /// **'Tip links updated'**
  String get monetizationTipsSettingsSaved;

  /// App Store-safe compact button label on a profile that opens optional creator tip links.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get profileTipButtonLabel;

  /// App Store-safe title for the profile tip links bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Tip this creator'**
  String get profileTipSheetTitle;

  /// App Store-safe policy copy in the profile tip links bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Tips open outside Divine. They are optional and do not unlock content, subscriptions, features, or access in Divine.'**
  String get profileTipSheetBody;

  /// Title of the Storage settings screen and its entry in the settings list.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorageTitle;

  /// Section header for the clearable media caches on the Storage screen.
  ///
  /// In en, this message translates to:
  /// **'Cached media'**
  String get settingsStorageCacheSectionTitle;

  /// Explains what the cached-media section clears and that it is safe.
  ///
  /// In en, this message translates to:
  /// **'Cached feed videos, thumbnails and temporary renders. Clearing them is safe — they\'re re-downloaded or regenerated when needed.'**
  String get settingsStorageCacheDescription;

  /// Placeholder shown while the cache size is being computed.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get settingsStorageMeasuring;

  /// Shows how much disk the caches currently use.
  ///
  /// In en, this message translates to:
  /// **'{size} in use'**
  String settingsStorageCacheInUse(String size);

  /// Button that clears the media caches.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsStorageClearButton;

  /// Title of the confirmation sheet before clearing caches.
  ///
  /// In en, this message translates to:
  /// **'Clear cached media?'**
  String get settingsStorageClearConfirmTitle;

  /// Body of the clear-cache confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'This frees up {size}. Your clip library is not affected.'**
  String settingsStorageClearConfirmMessage(String size);

  /// Confirm button that performs the cache clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsStorageClearConfirmAction;

  /// Accessibility announcement after the cache is cleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsStorageCleared;

  /// Section header for the clip-library audit on the Storage screen.
  ///
  /// In en, this message translates to:
  /// **'Clip library'**
  String get settingsStorageLibrarySectionTitle;

  /// Explains what the clip-library check does.
  ///
  /// In en, this message translates to:
  /// **'Check for broken clips whose video file is missing.'**
  String get settingsStorageLibraryDescription;

  /// Button that scans the clip library for broken clips.
  ///
  /// In en, this message translates to:
  /// **'Check library'**
  String get settingsStorageScanButton;

  /// Shown when the library scan finds no broken clips.
  ///
  /// In en, this message translates to:
  /// **'No broken clips found'**
  String get settingsStorageLibraryHealthy;

  /// Shows how many broken clips the scan found.
  ///
  /// In en, this message translates to:
  /// **'Broken clips found: {count}'**
  String settingsStorageBrokenClipsFound(int count);

  /// Button that removes the broken clips found by the scan.
  ///
  /// In en, this message translates to:
  /// **'Remove broken clips'**
  String get settingsStorageRemoveBrokenButton;

  /// Accessibility announcement after broken clips are removed.
  ///
  /// In en, this message translates to:
  /// **'Broken clips removed'**
  String get settingsStorageBrokenClipsRemoved;

  /// Generic error shown when a storage operation fails.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get settingsStorageError;

  /// Label above the slider that sets the maximum video-cache size.
  ///
  /// In en, this message translates to:
  /// **'Maximum video cache'**
  String get settingsStorageMaxVideoCacheLabel;

  /// Approximate number of videos that fit in the chosen cache size.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{≈ {count} video} other{≈ {count} videos}}'**
  String settingsStorageApproxVideos(int count);

  /// Title of the confirmation sheet before permanently removing broken clips whose video file is gone.
  ///
  /// In en, this message translates to:
  /// **'Remove broken clips?'**
  String get settingsStorageRemoveBrokenConfirmTitle;

  /// Section header for the last-resort local-data reset on the Storage screen.
  ///
  /// In en, this message translates to:
  /// **'Repair install'**
  String get settingsStorageRepairSectionTitle;

  /// Explains when to reach for the repair reset and what survives it.
  ///
  /// In en, this message translates to:
  /// **'If the app keeps crashing or acting strange, resetting its local data usually fixes it. Your clips and drafts stay.'**
  String get settingsStorageRepairDescription;

  /// Button that wipes local app data to recover from a broken install.
  ///
  /// In en, this message translates to:
  /// **'Reset app data'**
  String get settingsStorageRepairButton;

  /// Title of the confirmation sheet before the repair reset.
  ///
  /// In en, this message translates to:
  /// **'Reset app data?'**
  String get settingsStorageRepairConfirmTitle;

  /// Body of the repair confirmation sheet: what is removed, what survives, and that a restart is needed.
  ///
  /// In en, this message translates to:
  /// **'This clears cached feed data and temporary files. Your clips, drafts, settings and sign-in stay, but you\'ll need to restart the app afterwards.'**
  String get settingsStorageRepairConfirmMessage;

  /// Shows how much disk the repair reset frees, inside the confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'{size} will be removed'**
  String settingsStorageRepairFootprint(String size);

  /// Confirm button that performs the repair reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsStorageRepairConfirmAction;

  /// Shown while the repair reset is running.
  ///
  /// In en, this message translates to:
  /// **'Resetting…'**
  String get settingsStorageRepairInProgress;

  /// Shown and announced after a successful repair reset.
  ///
  /// In en, this message translates to:
  /// **'Done — restart the app to finish.'**
  String get settingsStorageRepairSuccess;

  /// Shown and announced when the repair reset could not complete.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reset everything. Try again after a restart.'**
  String get settingsStorageRepairFailure;

  /// Title for the Nostr relay signature verification setting.
  ///
  /// In en, this message translates to:
  /// **'Signature verification'**
  String get nostrSettingsSignatureVerification;

  /// Intro copy for the Nostr relay signature verification setting screen.
  ///
  /// In en, this message translates to:
  /// **'Choose when Divine checks relay event signatures. Event IDs are always validated first.'**
  String get nostrSettingsSignatureVerificationIntro;

  /// Option label to verify event signatures from all Nostr relays.
  ///
  /// In en, this message translates to:
  /// **'All relays'**
  String get nostrSettingsSignatureVerificationAll;

  /// Option subtitle for verifying every Nostr relay event signature.
  ///
  /// In en, this message translates to:
  /// **'Safest. Verify every relay event signature.'**
  String get nostrSettingsSignatureVerificationAllSubtitle;

  /// Option label to verify event signatures only from untrusted Nostr relays.
  ///
  /// In en, this message translates to:
  /// **'Untrusted relays'**
  String get nostrSettingsSignatureVerificationUntrusted;

  /// Option subtitle for skipping signature checks on configured relays.
  ///
  /// In en, this message translates to:
  /// **'Skip checks for relays already in your configured pool.'**
  String get nostrSettingsSignatureVerificationUntrustedSubtitle;

  /// Option label to verify event signatures only from non-Divine Nostr relays.
  ///
  /// In en, this message translates to:
  /// **'Non-Divine relays'**
  String get nostrSettingsSignatureVerificationNonDivine;

  /// Option subtitle for trusting Divine-hosted relays while verifying other relay signatures.
  ///
  /// In en, this message translates to:
  /// **'Trust Divine relays, verify the rest.'**
  String get nostrSettingsSignatureVerificationNonDivineSubtitle;

  /// Settings row and screen title for crossposting videos to external platforms.
  ///
  /// In en, this message translates to:
  /// **'Crossposting'**
  String get settingsCrosspostingTitle;

  /// Settings row subtitle for the crossposting screen.
  ///
  /// In en, this message translates to:
  /// **'Share your videos to other platforms'**
  String get settingsCrosspostingSubtitle;

  /// Shown on the crossposting screen when the user is signed out.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Divine to manage crossposting'**
  String get crosspostingSignInRequired;

  /// Error shown when the crossposting settings fail to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your crossposting settings'**
  String get crosspostingLoadFailed;

  /// Empty state when the service has no enabled crossposting platforms.
  ///
  /// In en, this message translates to:
  /// **'No crossposting platforms are available right now'**
  String get crosspostingNoPlatforms;

  /// Button label to retry loading crossposting settings.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get crosspostingRetry;

  /// Status line for a platform without a linked account.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get crosspostingNotConnected;

  /// Status line for a connected platform whose account name and external ID are unavailable.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get crosspostingConnected;

  /// Status line for a platform whose account link expired.
  ///
  /// In en, this message translates to:
  /// **'Needs reconnecting'**
  String get crosspostingNeedsReconnect;

  /// Button label to link an external platform account.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get crosspostingConnect;

  /// Button label to re-link a platform account that needs re-authorization.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get crosspostingReconnect;

  /// Button label to unlink an external platform account.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get crosspostingDisconnect;

  /// Posting-mode option: never crosspost to this platform.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get crosspostingModeOff;

  /// Posting-mode option: user picks per video.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get crosspostingModeManual;

  /// Explains the manual posting mode.
  ///
  /// In en, this message translates to:
  /// **'You choose per video'**
  String get crosspostingModeManualSubtitle;

  /// Posting-mode option: every future video is crossposted.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get crosspostingModeAutomatic;

  /// Explains the automatic posting mode and that it is not retroactive.
  ///
  /// In en, this message translates to:
  /// **'Future videos post automatically — only videos published after you turn this on'**
  String get crosspostingModeAutomaticSubtitle;

  /// Error shown when a posting mode is set on a platform that isn't connected.
  ///
  /// In en, this message translates to:
  /// **'Connect this platform first to change how it posts.'**
  String get crosspostingNotConnectedError;

  /// Generic error for failed crossposting actions.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get crosspostingGenericError;

  /// Error shown when the crossposting OAuth browser session ends without a validated callback (for example when Android app-link verification fails).
  ///
  /// In en, this message translates to:
  /// **'We never heard back from the sign-in page. If you finished connecting there, refresh — your account may already be linked.'**
  String get crosspostingCallbackTimeoutError;

  /// Snackbar after returning from a successful platform connection.
  ///
  /// In en, this message translates to:
  /// **'{platform} connected'**
  String crosspostingConnectionSuccess(String platform);

  /// Snackbar after returning from a failed platform connection.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect {platform}'**
  String crosspostingConnectionFailed(String platform);

  /// Snackbar when the user denied the connection on the provider's page.
  ///
  /// In en, this message translates to:
  /// **'Connection was canceled on {platform}'**
  String crosspostingConnectionDenied(String platform);

  /// Title of the supporter subscription settings screen and its settings tile.
  ///
  /// In en, this message translates to:
  /// **'Divine Supporters'**
  String get supporterTitle;

  /// Subtitle of the supporter subscription settings tile.
  ///
  /// In en, this message translates to:
  /// **'Support Divine with an optional monthly subscription.'**
  String get supporterTileSubtitle;

  /// Headline at the top of the supporter subscription screen.
  ///
  /// In en, this message translates to:
  /// **'Keep Divine running'**
  String get supporterHeroTitle;

  /// Introductory copy on the supporter subscription screen explaining the optional monthly support.
  ///
  /// In en, this message translates to:
  /// **'Divine is free and always will be. If you want to help us keep the loops going, become a monthly supporter. Nothing is locked — it just keeps the lights on and earns our thanks.'**
  String get supporterHeroBody;

  /// Confirmation shown to users with an active supporter subscription.
  ///
  /// In en, this message translates to:
  /// **'You\'re a Divine Supporter. Thank you for keeping this going.'**
  String get supporterActiveBadge;

  /// Status note shown while a supporter purchase awaits store approval.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is pending approval.'**
  String get supporterPurchasePending;

  /// Status note shown while the server verifies a supporter purchase.
  ///
  /// In en, this message translates to:
  /// **'Confirming your support…'**
  String get supporterPurchaseConfirming;

  /// Loading note shown while supporter subscription tiers are fetched from the store.
  ///
  /// In en, this message translates to:
  /// **'Checking the store…'**
  String get supporterStoreChecking;

  /// Note shown when no supporter subscription tiers are available on this device or storefront.
  ///
  /// In en, this message translates to:
  /// **'Supporter subscriptions are not available here right now.'**
  String get supporterUnavailable;

  /// Button label that re-checks the store for an existing supporter subscription.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get supporterRestorePurchases;

  /// Accessibility label for the button that dismisses the supporter error banner.
  ///
  /// In en, this message translates to:
  /// **'Dismiss error'**
  String get supporterDismissError;

  /// Error shown when the device cannot reach the app store billing client.
  ///
  /// In en, this message translates to:
  /// **'The store is unavailable on this device.'**
  String get supporterErrorStoreUnavailable;

  /// Error shown when a supporter purchase fails or is cancelled.
  ///
  /// In en, this message translates to:
  /// **'The purchase did not complete. You were not charged.'**
  String get supporterErrorPurchaseFailed;

  /// Error-banner variant shown when a supporter purchase is left in a pending state.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is pending approval.'**
  String get supporterErrorPurchasePending;

  /// Error shown when restoring purchases finds no supporter subscription.
  ///
  /// In en, this message translates to:
  /// **'No supporter subscription was found to restore.'**
  String get supporterErrorRestoreFailed;

  /// Error shown when the store purchase is already claimed by a different Divine account.
  ///
  /// In en, this message translates to:
  /// **'This purchase belongs to another Divine account.'**
  String get supporterErrorOwnershipConflict;

  /// Error shown when the server-side verification of a supporter purchase is temporarily unavailable.
  ///
  /// In en, this message translates to:
  /// **'Divine could not confirm supporter status right now.'**
  String get supporterErrorVerificationUnavailable;

  /// Generic supporter flow error shown when no more specific message applies.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get supporterErrorUnknown;

  /// Footnote on the supporter screen explaining server-side confirmation and that recognition is optional.
  ///
  /// In en, this message translates to:
  /// **'Divine confirms supporter status after the store verifies your purchase. Recognition is optional, and the halo is not verification.'**
  String get supporterDisclaimer;

  /// Accessibility label on the profile bell when the viewer is not subscribed. Describes the action the tap performs, not the current state.
  ///
  /// In en, this message translates to:
  /// **'Get notified about new vines'**
  String get profileNotifyBellOff;

  /// Accessibility label on the profile bell when the viewer is subscribed. Describes the action the tap performs.
  ///
  /// In en, this message translates to:
  /// **'Stop notifying me about new vines'**
  String get profileNotifyBellOn;

  /// Transient message when publishing the notification-subscription list fails. The bell has already reverted to its previous state.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that. Try again?'**
  String get profileNotifyUpdateFailed;

  /// No description provided for @savedSoundYourLabel.
  ///
  /// In en, this message translates to:
  /// **'Your label'**
  String get savedSoundYourLabel;

  /// No description provided for @savedSoundAddHashtags.
  ///
  /// In en, this message translates to:
  /// **'Add hashtags'**
  String get savedSoundAddHashtags;

  /// No description provided for @savedSoundDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get savedSoundDeviceOnly;

  /// No description provided for @savedSoundDetailsRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save those details. Tap to retry.'**
  String get savedSoundDetailsRetry;

  /// No description provided for @savedSoundFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved sound'**
  String get savedSoundFallbackTitle;

  /// No description provided for @savedSoundPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview sound'**
  String get savedSoundPreviewAction;

  /// No description provided for @savedSoundEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit sound details'**
  String get savedSoundEditAction;

  /// No description provided for @savedSoundRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove saved sound'**
  String get savedSoundRemoveAction;

  /// No description provided for @savedSoundClearHashtagFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear hashtag filter'**
  String get savedSoundClearHashtagFilter;

  /// No description provided for @soundAllowRemix.
  ///
  /// In en, this message translates to:
  /// **'Allow others to remix this sound'**
  String get soundAllowRemix;

  /// No description provided for @soundReuseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This sound can\'t be remixed right now.'**
  String get soundReuseUnavailable;

  /// No description provided for @soundPublicCredit.
  ///
  /// In en, this message translates to:
  /// **'Public sound credit'**
  String get soundPublicCredit;

  /// No description provided for @soundCreditRequired.
  ///
  /// In en, this message translates to:
  /// **'Add public sound credit before posting.'**
  String get soundCreditRequired;

  /// No description provided for @soundSharedAs.
  ///
  /// In en, this message translates to:
  /// **'Shared as'**
  String get soundSharedAs;

  /// No description provided for @soundOwnWork.
  ///
  /// In en, this message translates to:
  /// **'I made this sound'**
  String get soundOwnWork;

  /// No description provided for @soundCreatorBy.
  ///
  /// In en, this message translates to:
  /// **'By {creator}'**
  String soundCreatorBy(String creator);

  /// No description provided for @soundSharedBy.
  ///
  /// In en, this message translates to:
  /// **'Shared by {publisher}'**
  String soundSharedBy(String publisher);

  /// No description provided for @soundRemixingAllowed.
  ///
  /// In en, this message translates to:
  /// **'Remixing allowed'**
  String get soundRemixingAllowed;

  /// No description provided for @soundCreditOnly.
  ///
  /// In en, this message translates to:
  /// **'Credit only'**
  String get soundCreditOnly;

  /// No description provided for @soundCreditTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Sound title'**
  String get soundCreditTitleLabel;

  /// No description provided for @soundCreditCreatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get soundCreditCreatorLabel;

  /// No description provided for @soundCreditSourceUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Source URL'**
  String get soundCreditSourceUrlLabel;

  /// No description provided for @soundCreditPublicHashtagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Public hashtags'**
  String get soundCreditPublicHashtagsLabel;

  /// No description provided for @videoMetadataTagsPickerCancelSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel tag selection'**
  String get videoMetadataTagsPickerCancelSemanticLabel;

  /// No description provided for @videoMetadataTagsPickerConfirmSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply selected tags'**
  String get videoMetadataTagsPickerConfirmSemanticLabel;

  /// No description provided for @userPickerCancelSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel user selection'**
  String get userPickerCancelSemanticLabel;

  /// No description provided for @userPickerConfirmSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm selected users'**
  String get userPickerConfirmSemanticLabel;

  /// No description provided for @userPickerClearSelectionSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear user selection'**
  String get userPickerClearSelectionSemanticLabel;

  /// No description provided for @videoMetadataContentWarningsPickerCancelSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel content warning selection'**
  String get videoMetadataContentWarningsPickerCancelSemanticLabel;

  /// No description provided for @videoMetadataContentWarningsPickerConfirmSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply selected content warnings'**
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel;

  /// No description provided for @videoEditorCloseEditorSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Close video editor'**
  String get videoEditorCloseEditorSemanticLabel;

  /// No description provided for @videoEditorContinueToPostDetailsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue to post details'**
  String get videoEditorContinueToPostDetailsSemanticLabel;

  /// Accessibility label for closing a named video-editor tool without applying its changes.
  ///
  /// In en, this message translates to:
  /// **'Discard changes in {tool}'**
  String videoEditorDiscardToolChangesSemanticLabel(String tool);

  /// Accessibility label for applying changes made in a named video-editor tool.
  ///
  /// In en, this message translates to:
  /// **'Apply changes in {tool}'**
  String videoEditorApplyToolChangesSemanticLabel(String tool);

  /// No description provided for @videoEditorRemoveAudioSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove audio'**
  String get videoEditorRemoveAudioSemanticLabel;

  /// Accessibility label announcing a color swatch as its RGB triplet, used when the color has no human-readable name.
  ///
  /// In en, this message translates to:
  /// **'RGB {red}, {green}, {blue}'**
  String rgbColorSemanticLabel(int red, int green, int blue);

  /// Joins the custom color swatch's picker role and its color description into one accessibility label. Translate the separator, not the placeholders: locales that do not list with a Latin comma should use their own (for example '、' or '، '), matching rgbColorSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'{picker}, {color}'**
  String videoEditorColorPickerSwatchSemanticLabel(String picker, String color);

  /// Title of the screen listing the accounts a user has linked to their Nostr identity (NIP-39).
  ///
  /// In en, this message translates to:
  /// **'Verified accounts'**
  String get verifyTitle;

  /// Shown on the verify screen when no identity is signed in yet.
  ///
  /// In en, this message translates to:
  /// **'Sign in to link your accounts.'**
  String get verifySignedOutMessage;

  /// Intro line above the list of linked accounts, explaining what linking is for.
  ///
  /// In en, this message translates to:
  /// **'Link accounts you already have, so people can tell it\'s really you.'**
  String get verifyIntro;

  /// Shown when the linked accounts could not be read from relays.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your links.'**
  String get verifyLoadFailed;

  /// Button that retries loading the linked accounts.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get verifyRetry;

  /// Section header above the accounts that are already linked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get verifyLinkedSectionTitle;

  /// Caption shown when the verification service could not be reached, so linked accounts cannot be shown as verified or not.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the verifier, so these show as unchecked.'**
  String get verifyVerifierUnreachable;

  /// Section header above the platforms that can still be linked.
  ///
  /// In en, this message translates to:
  /// **'Add an account'**
  String get verifyAddSectionTitle;

  /// Shown in place of the platform list when every supported platform is already linked.
  ///
  /// In en, this message translates to:
  /// **'You\'ve linked everything we support.'**
  String get verifyAllPlatformsLinked;

  /// Pill on a linked account the verification service confirmed.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifyStatusVerified;

  /// Pill on a linked account the verification service did not confirm.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get verifyStatusUnverified;

  /// Screen reader label for the button that removes a linked account.
  ///
  /// In en, this message translates to:
  /// **'Unlink {platform} account {identity}'**
  String verifyUnlinkSemanticLabel(String platform, String identity);

  /// Title of the sheet confirming an account unlink. {platform} is the platform's display name.
  ///
  /// In en, this message translates to:
  /// **'Unlink {platform}?'**
  String verifyUnlinkConfirmTitle(String platform);

  /// Body of the sheet confirming an account unlink. {identity} is the handle being unlinked.
  ///
  /// In en, this message translates to:
  /// **'{identity} stops showing on your profile. You can link it again later, but you will have to sign in or post a new proof.'**
  String verifyUnlinkConfirmSubtitle(String identity);

  /// Destructive confirm button on the sheet confirming an account unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get verifyUnlinkConfirmCta;

  /// Screen reader label for a row that opens the flow for linking one platform.
  ///
  /// In en, this message translates to:
  /// **'Link your {platform} account'**
  String verifyLinkSemanticLabel(String platform);

  /// Small marker on platforms that can be linked by signing in, without posting a proof.
  ///
  /// In en, this message translates to:
  /// **'One tap'**
  String get verifyOneTapBadge;

  /// Explains the sign-in route for linking a platform. Reassures that nothing is posted to the account.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {platform} and we\'ll handle the rest. Nothing gets posted.'**
  String verifyConnectOauthExplainer(String platform);

  /// Button that opens the platform's sign-in page to link the account.
  ///
  /// In en, this message translates to:
  /// **'Continue with {platform}'**
  String verifyConnectOauthCta(String platform);

  /// Section header above the proof-post form. Reads as an alternative when a sign-in route is also offered.
  ///
  /// In en, this message translates to:
  /// **'Or post a proof'**
  String get verifyConnectProofTitle;

  /// Explains the proof-post route: publish your npub on the platform, then paste the link to that post.
  ///
  /// In en, this message translates to:
  /// **'Post your npub on your account, then paste the link to that post.'**
  String get verifyConnectProofExplainer;

  /// Caption above the user's own npub, shown so it can be copied into a proof post.
  ///
  /// In en, this message translates to:
  /// **'Your npub'**
  String get verifyNpubLabel;

  /// Screen reader label for the button that copies the user's npub.
  ///
  /// In en, this message translates to:
  /// **'Copy your npub'**
  String get verifyCopyNpubSemanticLabel;

  /// Confirmation shown after the npub was copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'npub copied'**
  String get verifyNpubCopied;

  /// Label of the field asking for the account name or handle on the platform being linked.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get verifyIdentityLabel;

  /// Label of the field asking for the URL of the proof post.
  ///
  /// In en, this message translates to:
  /// **'Link to your post'**
  String get verifyProofLabel;

  /// Button that verifies the proof post and, if it checks out, publishes the link.
  ///
  /// In en, this message translates to:
  /// **'Check and link'**
  String get verifyConnectProofCta;

  /// Fallback error when the verifier refused a proof for a reason this build cannot name — every platform without rejection codes lands here, so the wording must stay true of any refusal, including a wrong account name or an unreachable post.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t check out. Check the link and the account name, then try again.'**
  String get verifyErrorProofRejected;

  /// Error shown when the proof post exists and belongs to the right account, but does not contain the user's npub.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find your npub in that post.'**
  String get verifyErrorProofMissingNpub;

  /// Error shown when the pasted Discord link points at a direct message. No bot can read someone's DMs, so this can never verify.
  ///
  /// In en, this message translates to:
  /// **'That\'s a link to a DM, which our bot can\'t read. Post your npub in a server channel instead.'**
  String get verifyErrorDiscordDmLink;

  /// Error shown when the pasted Discord link points at a channel instead of a specific message.
  ///
  /// In en, this message translates to:
  /// **'That\'s a link to the channel, not your message. Long-press your message and pick Copy Message Link.'**
  String get verifyErrorDiscordChannelLink;

  /// Error shown when Discord has no message at the pasted link, or it was deleted.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that message. Check the link, and make sure the message is still up.'**
  String get verifyErrorDiscordMessageNotFound;

  /// Error shown when Divine's Discord bot cannot see the channel the proof message was posted in.
  ///
  /// In en, this message translates to:
  /// **'Our bot can\'t read that channel. Post your npub somewhere it can see.'**
  String get verifyErrorDiscordBotNoAccess;

  /// Error shown when the Discord message was posted by an account other than the one being claimed. Discord usernames are lowercase and differ from the display name shown in chat.
  ///
  /// In en, this message translates to:
  /// **'That message is from a different account. Use your Discord username — the one on your profile, not your display name.'**
  String get verifyErrorDiscordAuthorMismatch;

  /// Error shown when Discord returns the proof message with empty text, which means Divine's bot is missing a permission. Not the user's mistake.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read that message\'s text. That\'s on us — please tell support.'**
  String get verifyErrorDiscordContentUnavailable;

  /// Error shown when the verification service could not be reached.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the verifier. Try again in a moment.'**
  String get verifyErrorVerifierUnreachable;

  /// Error shown when the platform sign-in ended without a usable confirmation.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. Give it another go.'**
  String get verifyErrorOauthFailed;

  /// Error shown when Bluesky sign-in is started without a handle, which it needs to find the user's server.
  ///
  /// In en, this message translates to:
  /// **'Enter your handle first.'**
  String get verifyErrorHandleRequired;

  /// Error shown when the account verified but no relay accepted the identity event carrying the link.
  ///
  /// In en, this message translates to:
  /// **'Verified, but no relay took the update. Try again.'**
  String get verifyErrorPublishFailed;

  /// Error shown when the platform's one-tap sign-in has no credentials configured on the verification service, so only the proof-post route works.
  ///
  /// In en, this message translates to:
  /// **'One-tap sign-in isn\'t set up for this one yet. Use the proof post below.'**
  String get verifyErrorOauthUnavailable;

  /// GitHub-specific proof instructions. GitHub proof must be a public gist, and the service reads only the gist's first file.
  ///
  /// In en, this message translates to:
  /// **'Make a public gist with your npub in the first file, then paste the gist link.'**
  String get verifyConnectProofExplainerGithub;

  /// Discord-specific proof instructions. The proof is a message link from a channel the Divine bot can read; server invites are rejected because they cannot prove account ownership.
  ///
  /// In en, this message translates to:
  /// **'Post your npub in a Discord channel our bot can read, then paste the message link. A server invite proves nothing.'**
  String get verifyConnectProofExplainerDiscord;

  /// Twitter/X proof instructions. The verifier reads the tweet and looks for the npub in its text.
  ///
  /// In en, this message translates to:
  /// **'Tweet your npub from that account, then paste the link to the tweet.'**
  String get verifyConnectProofExplainerTwitter;

  /// Mastodon proof instructions. Also warns that the account name must carry the instance, because the verifier needs it to find the server.
  ///
  /// In en, this message translates to:
  /// **'Post your npub from that account, then paste the link. The account name needs its instance — mastodon.social/@alice, not just alice.'**
  String get verifyConnectProofExplainerMastodon;

  /// Telegram proof instructions. Verification reads a public channel message, so a private chat cannot work.
  ///
  /// In en, this message translates to:
  /// **'The channel gets linked, not your Telegram account. It needs a public link first (Telegram makes new ones private). Post your npub there and paste the message link.'**
  String get verifyConnectProofExplainerTelegram;

  /// Bluesky proof instructions. Signing in writes an identity record, so the proof post is only needed when the user did not sign in.
  ///
  /// In en, this message translates to:
  /// **'Signed in above? Nothing else needed. Otherwise post your npub and paste the link to that post.'**
  String get verifyConnectProofExplainerBluesky;

  /// TikTok proof instructions. The verifier reads the video caption, not the profile bio.
  ///
  /// In en, this message translates to:
  /// **'Put your npub in a video caption, then paste the link to that video.'**
  String get verifyConnectProofExplainerTiktok;

  /// YouTube proof instructions. The verifier reads the video description, not the channel about page.
  ///
  /// In en, this message translates to:
  /// **'Put your npub in a video description, then paste the link to that video.'**
  String get verifyConnectProofExplainerYoutube;

  /// Confirmation shown on the verify screen right after an account was linked and published. {platform} is the platform's display name.
  ///
  /// In en, this message translates to:
  /// **'{platform} is linked.'**
  String verifyLinkedConfirmation(String platform);

  /// Error shown when the pasted Telegram link is a private channel message (t.me/c/...) or an invite link, neither of which the verification service can read. New Telegram channels are private until the user gives them a public link.
  ///
  /// In en, this message translates to:
  /// **'That\'s a private channel or an invite. Give the channel a public link, then paste the message link.'**
  String get verifyErrorTelegramNotPublic;

  /// Error shown when unlinking an account did not reach any relay, so the account is still linked.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unlink that. Try again.'**
  String get verifyErrorRemoveFailed;

  /// Error shown when the accounts already linked could not be read from relays. Writing anyway would have replaced them with an incomplete list, so nothing was changed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read your current links, so nothing was changed. Check your connection and try again.'**
  String get verifyErrorLinksUnreadable;

  /// Label of the account field for platforms where the thing being linked is a channel rather than a personal account: Telegram and YouTube verify the channel that published the proof, not the user's own handle.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get verifyChannelLabel;

  /// Title of the explainer sheet, and the label of the link that opens it. Phrased as the question a user would ask.
  ///
  /// In en, this message translates to:
  /// **'How does it work?'**
  String get verifyHowItWorksTitle;

  /// Opening line of the explainer, introducing the handshake metaphor used on verify.divine.video.
  ///
  /// In en, this message translates to:
  /// **'Think of it as a handshake between two accounts:'**
  String get verifyHowItWorksIntro;

  /// First half of the handshake: what the user's Divine profile claims. The quoted example uses a placeholder handle, not a real one.
  ///
  /// In en, this message translates to:
  /// **'Your Divine profile says: “I\'m @alice on Twitter.”'**
  String get verifyHowItWorksYourSide;

  /// Second half of the handshake: what the external account confirms.
  ///
  /// In en, this message translates to:
  /// **'Your Twitter account confirms: “Yes, that Divine profile is mine.”'**
  String get verifyHowItWorksOtherSide;

  /// Explains that both sides are checked and why an impersonator cannot fake it.
  ///
  /// In en, this message translates to:
  /// **'We check both sides. If they match, you\'re verified. Nobody can fake it — someone can copy your name and photo, but they can\'t post from your real account.'**
  String get verifyHowItWorksBothSides;

  /// Notes that the links live on the user's own Nostr identity and can be removed again.
  ///
  /// In en, this message translates to:
  /// **'The links live on your own Nostr identity, so you can remove any of them here whenever you want.'**
  String get verifyHowItWorksOwnership;

  /// Section header in General settings above the entry that opens the verified-accounts screen.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get generalSettingsSectionIdentity;

  /// Clip library filter chip showing every clip that is neither archived nor deleted.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryFilterAll;

  /// Clip library filter chip that shows archived clips. Noun label, not an imperative action.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get libraryFilterArchive;

  /// Clip library filter chip that opens the trash view for recently deleted clips.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get libraryFilterDeleted;

  /// Short chip label that creates a new clip-library category.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get libraryCategoryNewChipLabel;

  /// Accessibility label for the chip that creates a new clip-library category.
  ///
  /// In en, this message translates to:
  /// **'Create a category'**
  String get libraryCategoryCreateSemanticLabel;

  /// Title of the bottom sheet for naming a new clip-library category.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get libraryCategoryCreateTitle;

  /// Button label that confirms creating a new clip-library category.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get libraryCategoryCreateAction;

  /// Title of the bottom sheet for renaming a clip-library category.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get libraryCategoryRenameTitle;

  /// Button or menu label that starts or confirms renaming a clip-library category.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get libraryCategoryRenameAction;

  /// Destructive menu action that deletes only the category, not the clips inside it.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get libraryCategoryDeleteAction;

  /// Text-field label for the user's own clip-library category name.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get libraryCategoryNameLabel;

  /// Confirmation title before deleting a user-created clip-library category.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String libraryCategoryDeleteConfirmTitle(String name);

  /// Explains that deleting a category keeps the clips and removes their category assignment.
  ///
  /// In en, this message translates to:
  /// **'Your clips stay put. They just move back to All.'**
  String get libraryCategoryDeleteConfirmMessage;

  /// Accessibility label for the toolbar button that manages the active clip-library category.
  ///
  /// In en, this message translates to:
  /// **'Rename or delete this category'**
  String get libraryCategoryManageSemanticLabel;

  /// Title of the sheet for filing selected clips into a category, archiving them, or removing their category.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get libraryCategoryMoveTitle;

  /// Move-sheet option that removes selected clips from any user-created category.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get libraryCategoryMoveNone;

  /// Move-sheet option that creates a new category before filing the selected clips into it.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get libraryCategoryMoveNewCategory;

  /// Move-sheet action that archives selected clips out of the main library view.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get libraryArchiveAction;

  /// Move-sheet action that brings selected archived clips back into the main library view.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get libraryUnarchiveAction;

  /// Title of the sheet asking whether clips being archived should stay visible in the categories they are filed under. {count} is how many distinct categories the selection spans, not how many clips it holds — the title names the destination, and the action labels below it name the same one or several.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Keep in this category?} other{Keep in these categories?}}'**
  String libraryArchiveKeepCategoryTitle(int count);

  /// Archive-question option that archives the clips but leaves them filed under the named category.
  ///
  /// In en, this message translates to:
  /// **'Keep in {name}'**
  String libraryArchiveKeepCategoryAction(String name);

  /// Archive-question option that archives the clips but leaves each one filed under its own category. Used when the selection spans more than one category.
  ///
  /// In en, this message translates to:
  /// **'Keep in their categories'**
  String get libraryArchiveKeepCategoryActionMixed;

  /// Archive-question option that archives the clips and takes them out of the named category.
  ///
  /// In en, this message translates to:
  /// **'Remove from {name}'**
  String libraryArchiveRemoveCategoryAction(String name);

  /// Archive-question option that archives the clips and takes each one out of its category. Used when the selection spans more than one category.
  ///
  /// In en, this message translates to:
  /// **'Remove from their categories'**
  String get libraryArchiveRemoveCategoryActionMixed;

  /// Accessibility label for the toolbar button that opens the selected-clips move sheet.
  ///
  /// In en, this message translates to:
  /// **'Move selected clips'**
  String get libraryMoveSelectedClipsTooltip;

  /// Empty-state title for a user-created category that has no clips.
  ///
  /// In en, this message translates to:
  /// **'Nothing filed here yet'**
  String get libraryCategoryEmptyTitle;

  /// Empty-state subtitle for a user-created category that has no clips.
  ///
  /// In en, this message translates to:
  /// **'Select a few clips and move them into this category.'**
  String get libraryCategoryEmptySubtitle;

  /// Empty-state title for the archive filter when no clips are archived.
  ///
  /// In en, this message translates to:
  /// **'Nothing archived'**
  String get libraryArchiveEmptyTitle;

  /// Empty-state subtitle for the archive filter when no clips are archived.
  ///
  /// In en, this message translates to:
  /// **'Archived clips wait here, out of the way of your main library.'**
  String get libraryArchiveEmptySubtitle;

  /// Snackbar after selected clips are filed into a user-created category.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clip moved to {name}} other{{count} clips moved to {name}}}'**
  String libraryClipsMovedToCategory(int count, String name);

  /// Snackbar after selected clips are removed from their user-created category.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clip removed from its category} other{{count} clips removed from their category}}'**
  String libraryClipsRemovedFromCategory(int count);

  /// Snackbar after selected clips are archived out of the main library view.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clip archived} other{{count} clips archived}}'**
  String libraryClipsArchived(int count);

  /// Snackbar after selected archived clips are returned to the main library view.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 clip back in your library} other{{count} clips back in your library}}'**
  String libraryClipsUnarchived(int count);

  /// No description provided for @accountSettingsChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get accountSettingsChangeEmail;

  /// No description provided for @accountSettingsChangeEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Move your account to a different address'**
  String get accountSettingsChangeEmailSubtitle;

  /// No description provided for @accountSettingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountSettingsChangePassword;

  /// No description provided for @accountSettingsChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a new password for signing in'**
  String get accountSettingsChangePasswordSubtitle;

  /// Shown when the session can no longer authorize an email or password change.
  ///
  /// In en, this message translates to:
  /// **'Your session ran out. Sign in again to make this change.'**
  String get accountCredentialsNeedsSignIn;

  /// No description provided for @accountCredentialsRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Give it a few minutes.'**
  String get accountCredentialsRateLimited;

  /// No description provided for @accountCredentialsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Divine. Check your connection and try again.'**
  String get accountCredentialsNetwork;

  /// No description provided for @accountCredentialsUnknown.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Please try again.'**
  String get accountCredentialsUnknown;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type your current password, then pick a new one.'**
  String get changePasswordSubtitle;

  /// No description provided for @changePasswordCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordCurrentLabel;

  /// No description provided for @changePasswordWrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'That\'s not your current password.'**
  String get changePasswordWrongCurrent;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get changePasswordSuccess;

  /// No description provided for @changeEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email a confirmation link to your new address and to the one on your account. Your email changes once you confirm from both.'**
  String get changeEmailSubtitle;

  /// Shows the email address currently on the account.
  ///
  /// In en, this message translates to:
  /// **'On your account: {email}'**
  String changeEmailCurrentAddress(String email);

  /// No description provided for @changeEmailNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get changeEmailNewLabel;

  /// No description provided for @changeEmailPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get changeEmailPasswordLabel;

  /// No description provided for @changeEmailSameAsCurrent.
  ///
  /// In en, this message translates to:
  /// **'That\'s already your email address.'**
  String get changeEmailSameAsCurrent;

  /// No description provided for @changeEmailWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'That\'s not your password.'**
  String get changeEmailWrongPassword;

  /// No description provided for @changeEmailSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send confirmation links'**
  String get changeEmailSubmit;

  /// No description provided for @changeEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Two links are on their way'**
  String get changeEmailSentTitle;

  /// Confirmation copy after an email change was requested; {email} is the new address.
  ///
  /// In en, this message translates to:
  /// **'Confirm from {email} and from the address on your account. Your email switches once both are done.'**
  String changeEmailSentMessage(String email);

  /// No description provided for @changeEmailSentExpiry.
  ///
  /// In en, this message translates to:
  /// **'The links stop working after 24 hours.'**
  String get changeEmailSentExpiry;

  /// No description provided for @changeEmailSentDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get changeEmailSentDone;

  /// Secondary line on a people-search result row: how many videos this user has published.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formattedCount} video} other{{formattedCount} videos}}'**
  String searchUserVideoCount(int count, String formattedCount);

  /// Secondary line on a user row: the viewer and this account follow each other. Shown in place of a truncated npub, which cannot tell two same-named people apart.
  ///
  /// In en, this message translates to:
  /// **'Mutual'**
  String get socialProofMutual;

  /// Secondary line on a user row: this account follows the viewer, who does not follow back.
  ///
  /// In en, this message translates to:
  /// **'Follows you'**
  String get socialProofFollowsYou;

  /// Secondary line on a user row: the viewer follows this account, which does not follow back.
  ///
  /// In en, this message translates to:
  /// **'You follow'**
  String get socialProofYouFollow;

  /// Secondary line on a user row: how many followers this account has. Joined to the relationship label with a middot.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{formattedCount} follower} other{{formattedCount} followers}}'**
  String socialProofFollowerCount(int count, String formattedCount);

  /// Shown on the video feed when the Divine status page confirms a component the feed depends on is impaired. Says plainly that the fault is ours.
  ///
  /// In en, this message translates to:
  /// **'Videos aren\'t loading right now.\nIt\'s us, not you — we\'re on it.'**
  String get feedOutageMessage;

  /// Shown on the video feed when the device has no network, or when even the status page (on a different CDN) is unreachable.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline.\nCheck your connection and try again.'**
  String get feedOfflineMessage;

  /// Title of the fail-closed startup screen shown when the encrypted local database cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t unlock your local database'**
  String get dbFailureTitle;

  /// Advice on the database-failure screen when a reset is offered, because the database is provably unusable.
  ///
  /// In en, this message translates to:
  /// **'A restart won\'t fix this one. Resetting the local database below gives Divine a clean start — your account stays.'**
  String get dbFailureAdviceResettable;

  /// Advice on the database-failure screen when no reset is offered, because the database is intact and only its keystore was unreachable.
  ///
  /// In en, this message translates to:
  /// **'Restart Divine after unlocking your device. If this keeps happening, update the app or contact support.'**
  String get dbFailureAdviceRestart;

  /// Advice shown when SQLite could not safely replay a hot rollback journal and the app preserves the local database for recovery.
  ///
  /// In en, this message translates to:
  /// **'Try restarting Divine once. If this keeps happening, update the app or contact support. Your local data is still here.'**
  String get dbFailureAdviceHotJournal;

  /// Short diagnostic code rendered on the database-failure screen so a support report can name the cause without a stack trace.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic: {code}'**
  String dbFailureDiagnostic(String code);

  /// Button that quits the app from the database-failure screen.
  ///
  /// In en, this message translates to:
  /// **'close Divine'**
  String get dbFailureCloseApp;

  /// Button that opens the confirmation step for the destructive local-database reset.
  ///
  /// In en, this message translates to:
  /// **'reset local database'**
  String get dbFailureResetAction;

  /// Title of the confirmation step before the local database is reset.
  ///
  /// In en, this message translates to:
  /// **'reset your local database?'**
  String get dbFailureConfirmTitle;

  /// Body of the confirmation step explaining what a local-database reset deletes and what survives.
  ///
  /// In en, this message translates to:
  /// **'Your account stays. Drafts and clips saved on this device are deleted — messages and feeds come back from the network.'**
  String get dbFailureConfirmBody;

  /// Destructive confirmation button that performs the local-database reset. Supported platforms close afterward; unsupported platforms remain on the completion step.
  ///
  /// In en, this message translates to:
  /// **'reset local database now'**
  String get dbFailureResetConfirm;

  /// Button that returns from the reset confirmation to the failure screen.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get dbFailureCancel;

  /// Message shown when the local-database reset itself failed or timed out.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Close Divine and try again.'**
  String get dbFailureResetFailed;

  /// Title of the terminal step after a successful local-database reset.
  ///
  /// In en, this message translates to:
  /// **'local database reset'**
  String get dbFailureResetDoneTitle;

  /// Body of the terminal step after a successful reset, telling the user to relaunch.
  ///
  /// In en, this message translates to:
  /// **'Close Divine and open it again — the next launch builds a fresh local database.'**
  String get dbFailureResetDoneBody;

  /// Screen-reader label for the info button on the sign-in options screen, which opens a sheet explaining each sign-in method.
  ///
  /// In en, this message translates to:
  /// **'About sign-in options'**
  String get authSignInOptionsInfo;

  /// Screen-reader label for the control that reveals the typed password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Screen-reader label for the control that re-masks the typed password.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// Screen-reader label for the follow button on a user row.
  ///
  /// In en, this message translates to:
  /// **'Follow user'**
  String get followUserSemanticLabel;

  /// Screen-reader label for the unfollow button on a user row.
  ///
  /// In en, this message translates to:
  /// **'Unfollow user'**
  String get unfollowUserSemanticLabel;

  /// Screen-reader label announced while the comment list is still loading.
  ///
  /// In en, this message translates to:
  /// **'Loading comments'**
  String get commentsLoadingSemanticLabel;

  /// Creator-analytics time window covering all time, shown next to 7D / 28D / 90D.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get analyticsWindowAll;

  /// Screen-reader label for the follow button on a user row inside a list, carrying the row position so end-to-end flows can target a specific row.
  ///
  /// In en, this message translates to:
  /// **'Follow user {index}'**
  String followUserIndexedSemanticLabel(String index);

  /// Screen-reader label for the unfollow button on a user row inside a list, carrying the row position so end-to-end flows can target a specific row.
  ///
  /// In en, this message translates to:
  /// **'Unfollow user {index}'**
  String unfollowUserIndexedSemanticLabel(String index);

  /// Label on a supporter subscription button: the tier name, its price, and the monthly billing period.
  ///
  /// In en, this message translates to:
  /// **'{title} — {price} / month'**
  String supporterTierMonthlyLabel(String title, String price);

  /// No description provided for @videoDetailHiddenBySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hidden by your settings'**
  String get videoDetailHiddenBySettingsTitle;

  /// Shown when a video is hidden because its media host is not a Divine host and the 'only show Divine-hosted videos' safety setting is on.
  ///
  /// In en, this message translates to:
  /// **'This one\'s hosted on {host}, and you\'re set to only show Divine-hosted videos.'**
  String videoDetailHiddenByHostFilterBody(String host);

  /// No description provided for @videoDetailHiddenByContentFilterBody.
  ///
  /// In en, this message translates to:
  /// **'Your content filters are hiding this one.'**
  String get videoDetailHiddenByContentFilterBody;

  /// No description provided for @videoDetailHiddenByProvenanceFilterBody.
  ///
  /// In en, this message translates to:
  /// **'This one has no capture chain back to a camera, and you\'re set to only show camera-verified videos.'**
  String get videoDetailHiddenByProvenanceFilterBody;

  /// No description provided for @videoDetailHiddenShowAnyway.
  ///
  /// In en, this message translates to:
  /// **'Show it anyway'**
  String get videoDetailHiddenShowAnyway;

  /// No description provided for @videoDetailHiddenOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Change setting'**
  String get videoDetailHiddenOpenSettings;

  /// No description provided for @safetySettingsShowVerifiedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only show camera-verified videos'**
  String get safetySettingsShowVerifiedOnly;

  /// No description provided for @safetySettingsShowVerifiedOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide videos without a capture chain back to a camera. Vine archive videos are always shown.'**
  String get safetySettingsShowVerifiedOnlySubtitle;

  /// Title of the account status screen, and of the settings row that opens it.
  ///
  /// In en, this message translates to:
  /// **'Account status'**
  String get accountStatusTitle;

  /// Settings row subtitle shown when the signed-in account is under enforcement.
  ///
  /// In en, this message translates to:
  /// **'Your account is restricted'**
  String get accountStatusTileSubtitleRestricted;

  /// Sole line on the account status screen when Funnelcake confirms there is no restriction. Deliberately has no body copy.
  ///
  /// In en, this message translates to:
  /// **'Everything looks good!'**
  String get accountStatusAllClearHeading;

  /// Persistent profile-avatar badge label shown when Divine has confirmed an account restriction.
  ///
  /// In en, this message translates to:
  /// **'Account restricted'**
  String get profileAccountRestricted;

  /// Heading shown when the account is suspended.
  ///
  /// In en, this message translates to:
  /// **'Your account is suspended'**
  String get accountStatusSuspendedHeading;

  /// Explains what a suspension restricts and that content is hidden rather than deleted.
  ///
  /// In en, this message translates to:
  /// **'You can\'t post, comment, or send messages on Divine right now. Your videos are hidden rather than deleted, and they come back if the suspension is lifted.'**
  String get accountStatusSuspendedBody;

  /// Heading shown when the account is banned.
  ///
  /// In en, this message translates to:
  /// **'Your account is banned'**
  String get accountStatusBannedHeading;

  /// Explains that a ban takes content down from Divine without claiming physical deletion.
  ///
  /// In en, this message translates to:
  /// **'You can\'t post, comment, or send messages on Divine, and your videos have been taken down from Divine.'**
  String get accountStatusBannedBody;

  /// Heading shown when a publish rejection confirms a restriction this app version does not recognize.
  ///
  /// In en, this message translates to:
  /// **'Your account is restricted'**
  String get accountStatusRestrictedHeading;

  /// Body shown when a publish rejection confirms a restriction this app version does not recognize.
  ///
  /// In en, this message translates to:
  /// **'Some things you can normally do on Divine are unavailable right now. Updating the app may show you more detail.'**
  String get accountStatusRestrictedBody;

  /// Shown with a retained confirmed restriction after its refresh fails.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t refresh your status. This is the last status we received.'**
  String get accountStatusLastKnownBody;

  /// Heading shown when account enforcement status could not be checked and no confirmed restriction is retained.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check your status'**
  String get accountStatusUnavailableHeading;

  /// Body shown when account enforcement status could not be checked and no confirmed restriction is retained.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get accountStatusUnavailableBody;

  /// Heading shown when the account-status route is opened without a signed-in account.
  ///
  /// In en, this message translates to:
  /// **'Sign in to check your account status'**
  String get accountStatusSignedOutHeading;

  /// Body shown when the account-status route is opened without a signed-in account.
  ///
  /// In en, this message translates to:
  /// **'There isn\'t a signed-in account to check right now.'**
  String get accountStatusSignedOutBody;

  /// Heading for the section explaining that Divine's enforcement does not affect the user's Nostr identity.
  ///
  /// In en, this message translates to:
  /// **'Your account still belongs to you'**
  String get accountStatusKeysUnaffectedHeading;

  /// Explains that the restriction is limited to Divine-operated surfaces and the user's Nostr identity is untouched.
  ///
  /// In en, this message translates to:
  /// **'This restriction applies to Divine. Your keys and your identity are yours, your followers travel with them, and you can keep using them on other apps and servers that Divine doesn\'t run.'**
  String get accountStatusKeysUnaffectedBody;

  /// Heading for the appeal section.
  ///
  /// In en, this message translates to:
  /// **'If you think this is wrong'**
  String get accountStatusAppealHeading;

  /// States the appeals policy plainly and points to support as the channel, without promising a formal appeals process.
  ///
  /// In en, this message translates to:
  /// **'Divine may review requests to reconsider a moderation decision, but is not obligated to. If you want to raise it, contact support and tell us what happened.'**
  String get accountStatusAppealBody;

  /// Button opening the in-app support center.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get accountStatusContactSupport;

  /// Button opening the account portability page.
  ///
  /// In en, this message translates to:
  /// **'Move your account'**
  String get accountStatusMoveAccount;

  /// Button that refetches the account status.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get accountStatusRetry;

  /// No description provided for @updateGentleBanner.
  ///
  /// In en, this message translates to:
  /// **'A fresh update just dropped. Check it out →'**
  String get updateGentleBanner;

  /// No description provided for @updateModerateTitle.
  ///
  /// In en, this message translates to:
  /// **'There\'s been an update since you last checked'**
  String get updateModerateTitle;

  /// No description provided for @updateUrgentTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re missing important fixes'**
  String get updateUrgentTitle;

  /// No description provided for @updateNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get updateNotNow;

  /// No description provided for @updateAction.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateAction;

  /// Heading before highlights for an available app update.
  ///
  /// In en, this message translates to:
  /// **'New in {version}:'**
  String updateNewIn(String version);

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get settingsUpdateAvailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'am',
    'ar',
    'bg',
    'de',
    'en',
    'es',
    'fil',
    'fr',
    'id',
    'it',
    'ja',
    'ko',
    'ms',
    'nl',
    'pl',
    'pt',
    'ro',
    'sv',
    'te',
    'tr',
    'ur',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'ar':
      return AppLocalizationsAr();
    case 'bg':
      return AppLocalizationsBg();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fil':
      return AppLocalizationsFil();
    case 'fr':
      return AppLocalizationsFr();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ms':
      return AppLocalizationsMs();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
    case 'sv':
      return AppLocalizationsSv();
    case 'te':
      return AppLocalizationsTe();
    case 'tr':
      return AppLocalizationsTr();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

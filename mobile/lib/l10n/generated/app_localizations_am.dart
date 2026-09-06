// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'የክሊፕ መልሶ ማግኛ';

  @override
  String get devOptionsClipRecoveryDescription =>
      'በሌላ መለያ ስር የተቀመጡ ቀረጻዎችን እና ማንኛውም ግቤት የማይጠቅሳቸውን የቪዲዮ ፋይሎችን ያገኛል።';

  @override
  String get devOptionsClipRecoveryScan => 'ቃኝ';

  @override
  String get devOptionsClipRecoveryFailure => 'የክሊፕ መልሶ ማግኘት አልተሳካም';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips ክሊፖች',
      one: '$clips ክሊፕ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts ረቂቆች',
      one: '$drafts ረቂቅ',
    );
    return 'አሁን የሚታዩ፦ $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'በሌሎች መለያዎች ስር የተደበቁ';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips ክሊፖች',
      one: '$clips ክሊፕ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts ረቂቆች',
      one: '$drafts ረቂቅ',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'ወደዚህ መለያ አዛውር';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'ያልተጠቀሱ ፋይሎች፦ $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'በቤተ-መጻሕፍት ውስጥ መልሶ ገንባ';

  @override
  String get devOptionsClipRecoveryEmpty => 'መልሶ የሚገኝ ነገር የለም';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች ተመልሰዋል',
      one: '$count ክሊፕ ተመልሷል',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'የመልሶ ማግኛ ሪፖርት ተቀድቷል';

  @override
  String get devOptionsStorageFootprint => 'የማከማቻ አጠቃቀም';

  @override
  String get devOptionsStorageFootprintDescription =>
      'መተግበሪያው የሚጽፍበት እያንዳንዱ አቃፊ። መሸጎጫን ማጽዳት ከዚህ ውስጥ የተወሰነውን ብቻ ነው የሚለቀው።';

  @override
  String get devOptionsStorageFootprintMeasure => 'ለካ';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'ጠቅላላ፦ $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'የማከማቻ ሪፖርት ተቀድቷል';

  @override
  String get devOptionsStorageFootprintFailure => 'ማከማቻውን መለካት አልተቻለም';

  @override
  String get feedTuningMoreLabel => 'እንደዚህ ያሉ ተጨማሪ';

  @override
  String get feedTuningLessLabel => 'እንደዚህ ያሉ ያነሱ';

  @override
  String get feedTuningUndo => 'መልስ';

  @override
  String get dmMessageBubbleVideoReplyHint => 'የተጠቀሰውን ቪዲዮ ክፈት';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'ቅንብሮች';

  @override
  String get settingsSecureAccount => 'የመለያዎን ደህንነት ይጠብቁ';

  @override
  String get settingsSessionExpired => 'ክፍለ ጊዜው አልፎበታል።';

  @override
  String get settingsSessionExpiredSubtitle => 'ሙሉ መዳረሻን ለመመለስ እንደገና ይግቡ';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'የፈጣሪ ትንታኔ';

  @override
  String get settingsSupportCenter => 'የድጋፍ ማዕከል';

  @override
  String get settingsNotifications => 'ማሳወቂያዎች';

  @override
  String get settingsBlueskyPublishing => 'Bluesky ማተም';

  @override
  String get settingsBlueskyPublishingSubtitle => 'ወደ Bluesky መለጠፍን ያስተዳድሩ';

  @override
  String get settingsNostrSettings => 'Nostr ቅንብሮች';

  @override
  String get settingsIntegratedApps => 'የተዋሃዱ መተግበሪያዎች';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'በDivine ውስጥ የሚሰሩ የጸደቁ የሶስተኛ ወገን መተግበሪያዎች';

  @override
  String get settingsExperimentalFeatures => 'የሙከራ ባህሪያት';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'ሊያደናቅፉ የሚችሉ ለውጦች - ለማወቅ ከፈለጉ ይሞክሩት።';

  @override
  String get settingsLegal => 'ህጋዊ';

  @override
  String get settingsIntegrationPermissions => 'የውህደት ፈቃዶች';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'የሚታወሱ የውህደት ማጽደቆችን ይገምግሙ እና ይሽሩ';

  @override
  String settingsVersion(String version) {
    return 'ስሪት $version';
  }

  @override
  String get settingsVersionEmpty => 'ሥሪት';

  @override
  String get settingsDeveloperModeAlreadyEnabled => 'የገንቢ ሁነታ አስቀድሞ ነቅቷል።';

  @override
  String get settingsDeveloperModeEnabled => 'የገንቢ ሁነታ ነቅቷል!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count የገንቢ ሁነታን ለማንቃት ተጨማሪ መታ ማድረግ';
  }

  @override
  String get settingsShareDivine => 'Divineን ከጓደኞችዎ ጋር ያጋሩ';

  @override
  String get settingsSwitchAccount => 'መለያ ቀይር';

  @override
  String get settingsAddAnotherAccount => 'ሌላ መለያ ያክሉ';

  @override
  String get settingsAccountSwitchFailed =>
      'መለያዎችን መቀየር አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get settingsUnsavedDraftsTitle => 'ያልተቀመጡ ረቂቆች';

  @override
  String get settingsUploadInProgressTitle => 'ስቀላ በሂደት ላይ';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ቪዲዮዎች',
      one: 'ቪዲዮ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ናቸው',
      one: 'ነው',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ቪዲዮዎችህ እንደ ረቂቆች',
      one: 'ቪዲዮህ እንደ ረቂቅ',
    );
    return 'አሁንም $count $_temp0 በመስቀል ላይ $_temp1። አካውንት መቀየር ስቀላውን ያቆማል — $_temp2 በዚህ አካውንት ውስጥ ይቀራሉ።';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ረቂቆች',
      one: 'ረቂቅ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ረቂቆቹ',
      one: 'ረቂቁ',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ልታትማቸው ወይም ልትመለከታቸው',
      one: 'ልታትመው ወይም ልትመለከተው',
    );
    return 'ያልተቀመጡ $count $_temp0 አሉህ። አካውንት ስትቀይር $_temp1 ይቀመጣሉ፣ ግን መጀመሪያ $_temp2 ትችላለህ።';
  }

  @override
  String get settingsCancel => 'ተወው';

  @override
  String get settingsSwitchAnyway => 'ለማንኛውም ቀይር';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'የዚያ መለያ ክፍለ ጊዜ አብቅቷል። እንደገና ወደ እሱ መግባት ማለት አሁን ካሉበት መለያ መውጣት ማለት ነው።';

  @override
  String get settingsAppVersionLabel => 'የመተግበሪያ ስሪት';

  @override
  String get settingsAppLanguage => 'የመተግበሪያ ቋንቋ';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (የመሣሪያ ነባሪ)';
  }

  @override
  String get settingsAppLanguageTitle => 'የመተግበሪያ ቋንቋ';

  @override
  String get settingsAppLanguageDescription => 'የመተግበሪያውን በይነገጽ ቋንቋ ምረጥ';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'የመሣሪያውን ቋንቋ ተጠቀም';

  @override
  String get settingsGeneralTitle => 'አጠቃላይ ቅንብሮች';

  @override
  String get settingsContentSafetyTitle => 'ይዘት እና ደህንነት';

  @override
  String get generalSettingsSectionIntegrations => 'ውህደቶች';

  @override
  String get generalSettingsSectionViewing => 'ማየት';

  @override
  String get generalSettingsSectionCreating => 'መፍጠር';

  @override
  String get generalSettingsSectionApp => 'መተግበሪያ';

  @override
  String get appearanceSettingsTitle => 'መልክ';

  @override
  String get appearanceSettingsSubtitle =>
      'Divine በዚህ መሣሪያ ላይ እንዴት እንደሚታይ ይምረጡ';

  @override
  String get appearanceSettingsSystem => 'የሥርዓት ነባሪ';

  @override
  String get appearanceSettingsLight => 'ብሩህ';

  @override
  String get appearanceSettingsDark => 'ጨለማ';

  @override
  String get generalSettingsClosedCaptions => 'የተዘጉ መግለጫዎች';

  @override
  String get generalSettingsClosedCaptionsSubtitle => 'ቪዲዮዎች መግለጫዎችን ሲያካትቱ አሳይ';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'ካሬ ቪዲዮዎች ብቻ';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'ምግቦችን በክላሲክ ካሬ ቅርጽ ያቆዩ';

  @override
  String get contentPreferencesTitle => 'የይዘት ምርጫዎች';

  @override
  String get contentPreferencesContentFilters => 'የይዘት ማጣሪያዎች';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'የይዘት ማስጠንቀቂያ ማጣሪያዎችን ያቀናብሩ';

  @override
  String get contentPreferencesContentLanguage => 'የይዘት ቋንቋ';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (የመሣሪያ ነባሪ)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'ተመልካቾች ይዘትን ማጣራት እንዲችሉ ቪዲዮዎችዎን በቋንቋ መለያ ይስጡ።';

  @override
  String get contentPreferencesUseDeviceLanguage => 'የመሣሪያውን ቋንቋ ተጠቀም (ነባሪ)';

  @override
  String get contentPreferencesAudioSharing =>
      'የእኔን ኦዲዮ ለእንደገና ጥቅም ላይ እንዲውል አድርግ';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'ሲነቃ ሌሎች ከቪዲዮዎችዎ ኦዲዮን መጠቀም ይችላሉ።';

  @override
  String get contentPreferencesMusicMode => 'የሙዚቃ ሁነታ';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'የሙዚቃ መሣሪያዎችን የሚያደበዝዘውን የድምፅ ማጽጃ ያጠፋል። ለሙዚቃ የተሻለ፣ ለድምፅ ግን ትንሽ ሻካራ።';

  @override
  String get contentPreferencesAccountLabels => 'መለያ መለያዎች';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'ይዘትዎን በራስ-ይሰይሙ';

  @override
  String get contentPreferencesAccountContentLabels => 'የመለያ ይዘት መለያዎች';

  @override
  String get contentPreferencesClearAll => 'ሁሉንም አጽዳ';

  @override
  String get contentPreferencesSelectAllThatApply => 'በመለያህ ላይ የሚመለከተውን ሁሉ ምረጥ';

  @override
  String get contentPreferencesDoneNoLabels => 'ተከናውኗል (ምንም መለያዎች የሉም)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'ተከናውኗል ($count ተመርጧል)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'የድምጽ ግቤት መሣሪያ';

  @override
  String get contentPreferencesAutoRecommended => 'ራስ-ሰር (የሚመከር)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'በጣም ጥሩውን ማይክሮፎን በራስ-ሰር ይመርጣል';

  @override
  String get contentPreferencesSelectAudioInput => 'የድምጽ ግቤትን ይምረጡ';

  @override
  String get contentPreferencesUnknownMicrophone => 'ያልታወቀ ማይክሮፎን';

  @override
  String get contentFiltersAdultContent => 'የአዋቂዎች ይዘት';

  @override
  String get contentFiltersViolenceGore => 'ግፍ እና ደም';

  @override
  String get contentFiltersSubstances => 'ንጥረ ነገሮች';

  @override
  String get contentFiltersOther => 'ሌላ';

  @override
  String get contentFiltersAgeGateMessage =>
      'የአዋቂዎች ይዘት ማጣሪያዎችን ለመክፈት በደህንነት እና ግላዊነት ቅንብሮች ውስጥ እድሜዎን ያረጋግጡ';

  @override
  String get contentFiltersShow => 'አሳይ';

  @override
  String get contentFiltersWarn => 'አስጠንቅቅ';

  @override
  String get contentFiltersFilterOut => 'አጣራ';

  @override
  String get profileBlockedAccountNotAvailable => 'ይህ መለያ አይገኝም';

  @override
  String get profileInvalidId => 'ልክ ያልሆነ የመገለጫ መታወቂያ';

  @override
  String profileShareText(String displayName, String npub) {
    return '$displayName በDivine ላይ ይመልከቱ!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName በ Divine ላይ';
  }

  @override
  String get profileShareFailed => 'መገለጫን ማጋራት አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get profileCopyPublicKey => 'የህዝብ ቁልፍ ቅዳ (npub)';

  @override
  String get profileGetEmbedCode => 'የተከተተ ኮድ ያግኙ';

  @override
  String get profilePublicKeyCopied => 'የህዝብ ቁልፍ ወደ ቅንጥብ ሰሌዳ ተቀድቷል።';

  @override
  String get profileEmbedCodeCopied => 'ኮድ ክተት ወደ ቅንጥብ ሰሌዳ ተቀድቷል።';

  @override
  String get profileMoreTooltip => 'ተጨማሪ';

  @override
  String get profileMoreSemanticLabel => 'ተጨማሪ አማራጮች';

  @override
  String get profileAvatarLightboxBarrierLabel => 'አምሳያ ዝጋ';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => 'የአቫታር ቅድመ እይታን ዝጋ';

  @override
  String get profileFollowingLabel => 'በመከተል ላይ';

  @override
  String get profileFollowLabel => 'ተከተል';

  @override
  String get profileBlockedLabel => 'ታግዷል';

  @override
  String get profileFollowersLabel => 'ተከታዮች';

  @override
  String get profileFollowingStatLabel => 'በመከተል ላይ';

  @override
  String get profileVideosLabel => 'ቪዲዮዎች';

  @override
  String get profileCollabsLabel => 'ትብብሮች';

  @override
  String get profileLikedLabel => 'የተወደዱ';

  @override
  String get profileRepostsLabel => 'ድጋሚ ልጥፎች';

  @override
  String get profileListsLabel => 'ዝርዝሮች';

  @override
  String get profileCommentsLabel => 'አስተያየቶች';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count የተባባሪ ግብዣዎች አሁንም መላክ ይፈልጋሉ',
      one: '$count የተባባሪ ግብዣ አሁንም መላክ ይፈልጋል',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'ግብዣውን በወረፋ አስቀምጠነዋል። እዚህ እንደገና ይሞክሩት።';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'ለ\"$title\"። እዚህ እንደገና ይሞክሩት።';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'እንደገና ሞክር';

  @override
  String get profileCollaboratorInviteRetryingAction => 'እንደገና በመሞከር ላይ';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'የተባባሪ ግብዣ እንደገና መሞከር አሁን አይገኝም።';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count የተባባሪ ግብዣዎች አሁንም መላክ ይፈልጋሉ።',
      one: '$count የተባባሪ ግብዣ አሁንም መላክ ይፈልጋል።',
      zero: 'የተባባሪ ግብዣዎች ተልከዋል።',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ተባባሪዎች ግብዣ መቀበል አይችሉም።',
      one: '$count ተባባሪ ግብዣ መቀበል አይችልም።',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count ተጠቃሚዎች';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'አግድ $displayName?';
  }

  @override
  String get profileBlockExplanation => 'ተጠቃሚን ሲያግዱ፡-';

  @override
  String get profileBlockBulletHidePosts => 'ልጥፎቻቸው በምግብዎ ውስጥ አይታዩም።';

  @override
  String get profileBlockBulletCantView =>
      'መገለጫዎን ሊመለከቱዎት፣ እርስዎን መከተል ወይም ልጥፎችዎን ማየት አይችሉም።';

  @override
  String get profileBlockBulletNoNotify => 'ስለዚህ ለውጥ ማሳወቂያ አይደርሳቸውም።';

  @override
  String get profileBlockBulletYouCanView => 'አሁንም መገለጫቸውን ማየት ይችላሉ።';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'አግድ $displayName';
  }

  @override
  String get profileCancelButton => 'ሰርዝ';

  @override
  String get profileLearnMore => 'የበለጠ ተማር';

  @override
  String profileUnblockTitle(String displayName) {
    return 'የ$displayNameን እገዳ ልታነሳ?';
  }

  @override
  String get profileUnblockExplanation => 'የዚህን ተጠቃሚ እገዳ ስታነቁ፡-';

  @override
  String get profileUnblockBulletShowPosts => 'ልጥፎቻቸው በምግብዎ ውስጥ ይታያሉ።';

  @override
  String get profileUnblockBulletCanView =>
      'እነሱ የእርስዎን መገለጫ ማየት፣ እርስዎን መከተል እና ልጥፎችዎን ማየት ይችላሉ።';

  @override
  String get profileUnblockBulletNoNotify => 'ስለዚህ ለውጥ ማሳወቂያ አይደርሳቸውም።';

  @override
  String get profileLearnMoreAt => 'በ ላይ የበለጠ ይረዱ';

  @override
  String get profileUnblockButton => 'እገዳ አንሳ';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayNameን አትከተል';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'አግድ $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'እገዳን አንሳ $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '$displayNameን ሪፖርት አድርግ';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayNameን ወደ ዝርዝር ጨምር';
  }

  @override
  String get profileNoCollabsTitle => 'እስካሁን ምንም ትብብር የለም።';

  @override
  String get profileCollabsOwnEmpty => 'የምትተባበሩባቸው ቪዲዮዎች እዚህ ይታያሉ።';

  @override
  String get profileCollabsOtherEmpty => 'የሚተባበሩባቸው ቪዲዮዎች እዚህ ይታያሉ።';

  @override
  String get profileErrorLoadingCollabs => 'የትብብር ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get profileNoSavedVideosTitle => 'እስካሁን ምንም አልተቀመጠም።';

  @override
  String get profileSavedOwnEmpty =>
      'ቪዲዮዎችን ከማጋሪያ ሉህ ላይ ዕልባት አድርግ እና እዚህ ይታያሉ።';

  @override
  String get profileErrorLoadingSaved => 'የተቀመጡ ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get profileNoCommentsOwnTitle => 'እስካሁን ምንም አስተያየት የለም።';

  @override
  String get profileNoCommentsOtherTitle => 'እስካሁን ምንም አስተያየት የለም።';

  @override
  String get profileCommentsOwnEmpty => 'የእርስዎ አስተያየቶች እና ምላሾች እዚህ ይታያሉ።';

  @override
  String get profileCommentsOtherEmpty => 'የእነሱ አስተያየት እና ምላሾች እዚህ ይታያሉ.';

  @override
  String get profileErrorLoadingComments => 'አስተያየቶችን መጫን ላይ ስህተት';

  @override
  String get profileVideoRepliesSection => 'የቪዲዮ መልሶች';

  @override
  String get profileCommentsSection => 'አስተያየቶች';

  @override
  String get profileEditLabel => 'አርትዕ';

  @override
  String get profileLibraryLabel => 'ቤተ መፃህፍት';

  @override
  String get profileNoLikedVideosTitle => 'እስካሁን ምንም መውደዶች የሉም';

  @override
  String get profileLikedOwnEmpty =>
      'የሆነ ነገር ዓይንዎን ሲይዝ, ልብን ይንኩ. መውደዶችዎ እዚህ ይታያሉ።';

  @override
  String get profileLikedOtherEmpty => 'እስካሁን ዓይናቸውን የሳበ ነገር የለም። ጊዜ ስጠው።';

  @override
  String get profileErrorLoadingLiked => 'የተወደዱ ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get profileNoRepostsTitle => 'እስካሁን ምንም ድጋሚ የተለጠፈ የለም።';

  @override
  String get profileRepostsOwnEmpty =>
      'ማጋራት የሚገባ ነገር አየህ? እንደገና ይለጥፉት እና እዚህ ይታያል።';

  @override
  String get profileRepostsOtherEmpty => 'እስካሁን ምንም አላለፉም። ሲያደርጉ፣ እዚህ ይታያል።';

  @override
  String get profileErrorLoadingReposts => 'እንደገና የተለጠፉ ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get profileNoVideosTitle => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get profileNoVideosOwnSubtitle =>
      'መድረክህ ተዘጋጅቷል። መለጠፍ ይጀምሩ እና ቪዲዮዎችዎ እዚህ ይኖራሉ።';

  @override
  String get profileNoVideosOtherSubtitle => 'አለም እየጠበቀች ነው። እንዳያመልጥዎ ይከተሏቸው።';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'የቪዲዮ ድንክዬ $number';
  }

  @override
  String get profileShowMore => 'ተጨማሪ አሳይ';

  @override
  String get profileShowLess => 'ያነሰ አሳይ';

  @override
  String get dmMessageDisplayLimitReached => 'የቀረው መልዕክት አይታይም።';

  @override
  String get profileCompleteYourProfile => 'መገለጫዎን ያጠናቅቁ';

  @override
  String get profileCompleteSubtitle => 'ለመጀመር የእርስዎን ስም፣ የህይወት ታሪክ እና ምስል ያክሉ';

  @override
  String get profilePleaseTryAgain => 'እባክህ እንደገና ሞክር';

  @override
  String get profileSecureYourAccount => 'የመለያዎን ደህንነት ይጠብቁ';

  @override
  String get profileSecureSubtitle =>
      'መለያዎን በማንኛውም መሳሪያ ላይ ለማግኘት ኢሜይል እና የይለፍ ቃል ያክሉ';

  @override
  String get profileRetryButton => 'እንደገና ይሞክሩ';

  @override
  String get profileSessionExpired => 'ክፍለ ጊዜው አልፎበታል።';

  @override
  String get profileSignInToRestore => 'ሙሉ መዳረሻን ለመመለስ እንደገና ይግቡ';

  @override
  String get profileSignInButton => 'ይግቡ';

  @override
  String get profileMaybeLaterLabel => 'ምናልባት በኋላ';

  @override
  String get profileSecurePrimaryButton => 'ኢሜይል እና የይለፍ ቃል ያክሉ';

  @override
  String get profileCompletePrimaryButton => 'መገለጫዎን ያዘምኑ';

  @override
  String get profileLoopsLabel => 'ቀለበቶች';

  @override
  String get profileLikesLabel => 'መውደዶች';

  @override
  String get profileMyLibraryLabel => 'የእኔ ቤተ-መጽሐፍት';

  @override
  String get profileMessageLabel => 'መልእክት';

  @override
  String get profileShareLabel => 'መገለጫ ማጋራት';

  @override
  String get profileDeletedAccountName => 'የተሰረዘ መለያ';

  @override
  String get inboxActionReportVanishedAccount => 'ሪፖርት ይህን መለያ';

  @override
  String get inboxActionBlockVanishedAccount => 'አግድ ይህን መለያ';

  @override
  String get inboxActionUnblockVanishedAccount => 'እገዳን አንሳ ይህን መለያ';

  @override
  String get inboxReportedVanishedAccount => 'ሪፖርት ተደርጓል ይህን መለያ';

  @override
  String get inboxBlockedVanishedAccount => 'ታግዷል ይህን መለያ';

  @override
  String get inboxUnblockedVanishedAccount => 'እገዳው ተነስቷል ይህን መለያ';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'ይህ ውይይቱን ከመልእክት ሳጥንህ ያስወግዳል። እንደገና መልእክት ከላከልህ አዲስ ውይይት ይጀምራል።';

  @override
  String get inboxConversationDeletedAccountSubtitle => 'ይህ መለያ ተሰርዟል';

  @override
  String get profileUserFallback => 'ተጠቃሚ';

  @override
  String get profileLinkCopied => 'የመገለጫ አገናኝ ተቀድቷል።';

  @override
  String get profileSetupEditProfileTitle => 'መገለጫ አርትዕ';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'የNIP-05 አድራሻ ከማከልዎ በፊት መገለጫዎን ያዘጋጁ።';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'መገለጫ ይፍጠሩ';

  @override
  String get profileSetupBackLabel => 'ተመለስ';

  @override
  String get profileSetupAboutNostr => 'ስለ Nostr';

  @override
  String get profileSetupProfilePublished => 'መገለጫ በተሳካ ሁኔታ ታትሟል!';

  @override
  String get profileSetupUnsavedChangesTitle => 'ለውጦቹ ይቀመጡ?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'ከመውጣትህ በፊት ለውጦችህን አስቀምጥ፣ ወይም ጣላቸውና ቀጥል።';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'ለውጦቹን አስቀምጥ';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'ለውጦቹን ጣል';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'አርትዖቱን ቀጥል';

  @override
  String get profileSetupCreateNewProfile => 'አዲስ መገለጫ ይፈጠር?';

  @override
  String get profileSetupNoExistingProfile =>
      'በእርስዎ ማስተላለፊያዎች ላይ ነባር መገለጫ አላገኘንም። ማተም አዲስ መገለጫ ይፈጥራል። ይቀጥል?';

  @override
  String get profileSetupPublishButton => 'አትም';

  @override
  String get profileSetupUsernameTaken => 'የተጠቃሚ ስም አሁን ተወስዷል። እባክዎ ሌላ ይምረጡ።';

  @override
  String get profileSetupClaimFailed =>
      'የተጠቃሚ ስም መጠየቅ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get profileSetupPublishFailed => 'መገለጫን ማተም አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get profileSetupNoRelaysConnected =>
      'አውታረ መረቡ ላይ መድረስ አልተቻለም። ግንኙነትዎን ይፈትሹ እና እንደገና ይሞክሩ።';

  @override
  String get profileSetupDisplayNameLabel => 'የማሳያ ስም';

  @override
  String get profileSetupDisplayNameRequired => 'እባክዎ የማሳያ ስም ያስገቡ';

  @override
  String get profileSetupBioLabel => 'ባዮ (አማራጭ)';

  @override
  String get profileSetupWebsiteLabel => 'ድረ-ገጽ (አማራጭ)';

  @override
  String get profileSetupPublicKeyLabel => 'የህዝብ ቁልፍ (npub)';

  @override
  String get profileSetupUsernameLabel => 'የተጠቃሚ ስም (አማራጭ)';

  @override
  String get profileSetupUsernameHelper =>
      'ፊደላትን፣ ቁጥሮችን ወይም ሀሰረ መስመሮችን ተጠቀም። የተጠቃሚ ስምህ የdivine.video አድራሻ ይሆናል። ለክፍተቶች ወይም ምልክቶች የማሳያ ስምህን ተጠቀም።';

  @override
  String get profileSetupSaveButton => 'አስቀምጥ';

  @override
  String get profileSetupSavingButton => 'በማስቀመጥ ላይ...';

  @override
  String get profileSetupImageUrlTitle => 'ምስል ያክሉ URL';

  @override
  String get profileSetupImageSelectionFailed =>
      'የምስል ምርጫ አልተሳካም። እባክህ በምትኩ ምስል URL ከታች ለጥፍ።';

  @override
  String get profileSetupImagesTypeGroup => 'ምስሎች';

  @override
  String get cameraPickErrorPermissionDenied =>
      'የካሜራ መዳረሻ ጠፍቷል። ፎቶ ለማንሳት ከቅንብሮች አብራው።';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'በዚህ መሣሪያ ላይ የካሜራ መዳረሻ አይፈቀድም።';

  @override
  String get cameraPickErrorBusy => 'መምረጫው አስቀድሞ ተከፍቷል። ዝጋውና እንደገና ሞክር።';

  @override
  String get cameraPickErrorGeneric => 'ካሜራውን መክፈት አልተቻለም። እንደገና ሞክር።';

  @override
  String get profileSetupGotItButton => 'ገባኝ';

  @override
  String get profileSetupUploadFailedGeneric =>
      'ምስል መስቀል አልተሳካም። ቆይተህ እንደገና ሞክር።';

  @override
  String get profileSetupUploadNetworkError =>
      'የአውታረ መረብ ስህተት፡ እባክህ የበይነመረብ ግንኙነትህን ፈትሽ እና እንደገና ሞክር።';

  @override
  String get profileSetupUploadAuthError =>
      'የማረጋገጫ ስህተት፡ እባክዎ ዘግተው ለመውጣት ይሞክሩ።';

  @override
  String get profileSetupUploadFileTooLarge =>
      'ፋይሉ በጣም ትልቅ ነው፡ እባክዎን ትንሽ ምስል ይምረጡ (ከፍተኛ 10 ሜባ)።';

  @override
  String get profileSetupUploadServerError =>
      'ምስል መስቀል አልተሳካም። አገልጋዮቻችን ለጊዜው አይገኙም። ትንሽ ቆይተህ እንደገና ሞክር።';

  @override
  String get profileSetupBannerClearButton => 'ባነርን አጥፋ';

  @override
  String get profileSetupBannerChangeColor => 'የባነር ቀለም';

  @override
  String get profileSetupChangeBannerTitle => 'ባነር ቀይር';

  @override
  String get profileSetupBannerColorPickerTitle => 'የባነር ቀለም ቀይር';

  @override
  String get profileSetupBannerColorCustom => 'ብጁ';

  @override
  String get profileSetupBannerColorNone => 'ቀለም የለም';

  @override
  String get profileSetupBannerColorLime => 'ላይም';

  @override
  String get profileSetupBannerColorYellow => 'ቢጫ';

  @override
  String get profileSetupBannerColorViolet => 'ቫዮሌት';

  @override
  String get profileSetupBannerColorPink => 'ሮዝ';

  @override
  String get profileSetupBannerColorOrange => 'ብርቱካናማ';

  @override
  String get profileSetupBannerColorPurple => 'ወይን ጠጅ';

  @override
  String get profileSetupAvatarClearButton => 'ፎቶ አስወግድ';

  @override
  String get profileSetupImageTakePhoto => 'ፎቶ አንሳ';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'ከካሜራ ሮል ስቀል';

  @override
  String get profileSetupImagePasteLink => 'የምስል አገናኝ ለጥፍ';

  @override
  String get profileSetupEditAvatarLabel => 'የመገለጫ ፎቶ አርትዕ';

  @override
  String get profileSetupEditBannerLabel => 'ባነር አርትዕ';

  @override
  String get profileSetupUsernameChecking => 'ተገኝነትን በማጣራት ላይ...';

  @override
  String get profileSetupUsernameAvailable => 'የተጠቃሚ ስም አለ!';

  @override
  String get profileSetupUsernameTakenIndicator => 'የተጠቃሚ ስም አስቀድሞ ተወስዷል';

  @override
  String get profileSetupUsernameReserved => 'የተጠቃሚ ስም የተጠበቀ ነው።';

  @override
  String get profileSetupContactSupport => 'ድጋፍን ያነጋግሩ';

  @override
  String get profileSetupCheckAgain => 'እንደገና ያረጋግጡ';

  @override
  String get profileSetupUsernameBurned => 'ይህ የተጠቃሚ ስም ከአሁን በኋላ አይገኝም';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'ፊደሎች፣ ቁጥሮች እና ሰረዞች ብቻ ይፈቀዳሉ።';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'የተጠቃሚ ስም በሀሰረ መስመር ሊጀምር ወይም ሊጨርስ አይችልም።';

  @override
  String get profileSetupUsernameInvalidLength =>
      'የተጠቃሚ ስም 3-63 ቁምፊዎች መሆን አለበት።';

  @override
  String get profileSetupUsernameNetworkError =>
      'ተገኝነትን ማረጋገጥ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get profileSetupUsernameInvalidFormatGeneric => 'የተሳሳተ የተጠቃሚ ስም ቅርጸት';

  @override
  String get profileSetupUsernameCheckFailed => 'ተገኝነትን ማረጋገጥ አልተሳካም።';

  @override
  String get profileSetupUsernameReservedTitle => 'የተጠቃሚ ስም ተቀምጧል';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'ስሙ $username የተጠበቀ ነው። ለምን ያንተ መሆን እንዳለበት ንገረን።';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'ለምሳሌ. የእኔ የምርት ስም፣ የመድረክ ስም፣ ወዘተ ነው።';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'ድጋፍን አስቀድመው አነጋግረዋል? ለእርስዎ እንደተለቀቀ ለማየት \"እንደገና አረጋግጥ\" ን መታ ያድርጉ።';

  @override
  String get profileSetupSupportRequestSent => 'የድጋፍ ጥያቄ ተልኳል! በቅርቡ እንመለስዎታለን።';

  @override
  String get profileSetupCouldntOpenEmail =>
      'ኢሜይል መክፈት አልተቻለም። ወደ names@divine.video ላክ';

  @override
  String get profileSetupSendRequest => 'ጥያቄ ላክ';

  @override
  String get profileSetupUseOwnNip05 => 'የራስህን NIP-05 አድራሻ ተጠቀም';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 አድራሻ';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'ልክ ያልሆነ NIP-05 ቅርጸት (ለምሳሌ name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'ለdivine.video ከላይ ያለውን የተጠቃሚ ስም መስክ ይጠቀሙ';

  @override
  String get nostrSettingsNip05Address => 'የNIP-05 አድራሻ';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'የdivine.video የተጠቃሚ ስምህን ተጠቀም፣ ወይም መለያህን በምትቆጣጠረው ጎራ ላይ ወዳለ የNIP-05 አድራሻ አመልክት።';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'NIP-05 አስቀምጥ';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 ተቀምጧል';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'NIP-05 ማስቀመጥ አልተቻለም። እባክህ እንደገና ሞክር።';

  @override
  String get profileSetupNip05ConfirmTitle => 'የራስህን NIP-05 ትጠቀማለህ?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 እንደ you@yourdomain.com ያለ ስምን ከNostr ማንነትህ ጋር ያገናኛል። ጎራውን መቆጣጠርና የማረጋገጫ ፋይል በትክክለኛው መንገድ ማስቀመጥ አለብህ። ስህተት ካለ ሰዎች ሊያገኙህ አይችሉም፣ የተረጋገጠው መለያህም ይጠፋል። ይህን አዘጋጅተህ ከሆነ ብቻ ቀጥል።';

  @override
  String get profileSetupNip05ConfirmContinue => 'ቀጥል';

  @override
  String get profileSetupNip05ConfirmCancel => 'ሰርዝ';

  @override
  String get profileSetupProfilePicturePreview => 'የመገለጫ ስዕል ቅድመ እይታ';

  @override
  String get nostrInfoIntroBuiltOn => 'ዳይቪን የተገነባው በNostr ላይ ነው፣';

  @override
  String get nostrInfoIntroDescription =>
      'ሳንሱርን የሚቋቋም ክፍት ፕሮቶኮል ሰዎች በአንድ ኩባንያ ወይም መድረክ ላይ ሳይመሰረቱ በመስመር ላይ እንዲግባቡ ያስችላቸዋል።';

  @override
  String get nostrInfoIntroIdentity => 'ለDivine ሲመዘገቡ አዲስ Nostr መታወቂያ ያገኛሉ።';

  @override
  String get nostrInfoOwnership =>
      'Nostr የእርስዎን ይዘት፣ ማንነት እና ማህበራዊ ግራፍ በባለቤትነት እንዲይዙ ያስችልዎታል፣ ይህም በብዙ መተግበሪያዎች ላይ ሊጠቀሙበት ይችላሉ። ውጤቱ የበለጠ ምርጫ፣ መቆለፊያው ያነሰ እና ጤናማ፣ የበለጠ ጠንካራ ማህበራዊ ኢንተርኔት ነው።';

  @override
  String get nostrInfoLingo => 'Nostr ሊንጎ፡-';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' የህዝብ Nostr አድራሻህ። ማጋራት ደህና ነው፣ ሌሎችም በNostr መተግበሪያዎች ላይ እንዲያገኙህ፣ እንዲከተሉህ ወይም መልዕክት እንዲልኩልህ ያስችላል።';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      'የእርስዎ የግል ቁልፍ እና የባለቤትነት ማረጋገጫ። የእርስዎን Nostr ማንነት ሙሉ ቁጥጥር ይሰጣል፣ ስለዚህ';

  @override
  String get nostrInfoNsecWarning => 'ሁልጊዜ በሚስጥር ይያዙት!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr የተጠቃሚ ስም፡-';

  @override
  String get nostrInfoUsernameDescription =>
      ' ለሰው የሚነበብ ስም (እንደ @name.divine.video) ከnpubህ ጋር የሚገናኝ። የNostr ማንነትህን እንደ ኢሜይል አድራሻ ለመለየትና ለማረጋገጥ ያቀላል።';

  @override
  String get nostrInfoLearnMoreAt => 'በ ላይ የበለጠ ይረዱ';

  @override
  String get nostrInfoGotIt => 'ገባኝ!';

  @override
  String get videoGridRefreshLabel => 'ተጨማሪ ቪዲዮዎችን በመፈለግ ላይ';

  @override
  String get videoGridOptionsTitle => 'የቪዲዮ አማራጮች';

  @override
  String get videoGridEditVideo => 'ቪዲዮ አርትዕ';

  @override
  String get videoGridEditVideoSubtitle => 'ርዕስ፣ መግለጫ እና ሃሽታጎችን ያዘምኑ';

  @override
  String get videoGridDeleteVideo => 'ቪዲዮ ሰርዝ';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'ይህን ቪዲዮ ከDivine አስወግድ። በሌሎች Nostr ደንበኞች ላይ አሁንም ሊታይ ይችላል።';

  @override
  String get videoGridDeletingContent => 'ይዘትን በመሰረዝ ላይ...';

  @override
  String get exploreTabFeatured => 'ተለይተው የቀረቡ';

  @override
  String get exploreTabClassics => 'ክላሲኮች';

  @override
  String get exploreTabNew => 'አዲስ';

  @override
  String get exploreTabPopular => 'ታዋቂ';

  @override
  String get exploreTabCategories => 'ምድቦች';

  @override
  String get exploreTabForYou => 'ለእርስዎ';

  @override
  String get exploreTabLists => 'ዝርዝሮች';

  @override
  String get exploreTabIntegratedApps => 'የተዋሃዱ መተግበሪያዎች';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'እስካሁን እዚህ ምንም የለም። በቅርቡ ተመልሰህ ተመልከት።';

  @override
  String get featuredTabLoadFailed => 'ይህን ስብስብ መጫን አልተቻለም።';

  @override
  String get featuredTabRetry => 'እንደገና ሞክር';

  @override
  String get exploreNoVideosAvailable => 'ምንም ቪዲዮዎች የሉም';

  @override
  String get exploreDiscoverLists => 'ዝርዝሮችን ያግኙ';

  @override
  String get exploreAboutLists => 'ስለ ዝርዝሮች';

  @override
  String get exploreAboutListsDescription =>
      'ዝርዝሮች የDivine ይዘትን በሁለት መንገድ እንዲያደራጁ እና እንዲያዘጋጁ ያግዝዎታል፡';

  @override
  String get explorePeopleLists => 'የሰዎች ዝርዝሮች';

  @override
  String get explorePeopleListsDescription =>
      'የፈጣሪዎችን ቡድኖች ይከተሉ እና የቅርብ ጊዜ ቪዲዮዎቻቸውን ይመልከቱ';

  @override
  String get exploreVideoLists => 'የቪዲዮ ዝርዝሮች';

  @override
  String get exploreVideoListsDescription =>
      'በኋላ ለመመልከት የሚወዷቸውን ቪዲዮዎች አጫዋች ዝርዝሮችን ይፍጠሩ';

  @override
  String get exploreMyLists => 'የእኔ ዝርዝሮች';

  @override
  String get exploreSubscribedLists => 'የተመዘገቡ ዝርዝሮች';

  @override
  String get exploreErrorLoadingLists => 'ዝርዝሮችን መጫን ላይ ስህተት። እባክህ እንደገና ሞክር።';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count አዳዲስ ቪዲዮዎች',
      one: '$count አዲስ ቪዲዮ',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count አዳዲስ ቪዲዮዎች ጫን',
      one: '$count አዲስ ቪዲዮ ጫን',
    );
    return '$_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'ቪዲዮ አጫውት።';

  @override
  String get videoPlayerMute => 'ቪዲዮ ድምጸ-ከል አድርግ';

  @override
  String get videoPlayerUnmute => 'የቪዲዮ ድምጸ-ከል አንሳ';

  @override
  String get videoPlayerTapHint => 'ለማጫወት ወይም ለማቆም ይንኩ። ለመውደድ ሁለት ጊዜ ይንኩ።';

  @override
  String get videoSettingsMenuOpen => 'የመልሶ ማጫወቻ ቅንብሮችን ክፈት';

  @override
  String get videoSettingsMenuClose => 'የመልሶ ማጫወቻ ቅንብሮችን ዝጋ';

  @override
  String get videoSettingsCaptionsEnable => 'መግለጫ ጽሑፎችን አንቃ';

  @override
  String get videoSettingsCaptionsDisable => 'መግለጫ ጽሑፎችን አሰናክል';

  @override
  String get videoSettingsAutoAdvanceOn => 'ራስ-ሰር ማስቀደም በርቷል';

  @override
  String get videoSettingsAutoAdvanceOff => 'ራስ-ሰር ማስቀደም ጠፍቷል';

  @override
  String get videoSettingsCaptionsOn => 'መግለጫ ጽሑፎች በርተዋል';

  @override
  String get videoSettingsCaptionsOff => 'መግለጫ ጽሑፎች ጠፍተዋል';

  @override
  String get videoSettingsCaptionsOnForVideo => 'ለዚህ ቪዲዮ የጽሑፍ መግለጫዎች በርተዋል';

  @override
  String get videoSettingsCaptionsOffForVideo => 'ለዚህ ቪዲዮ የጽሑፍ መግለጫዎች ጠፍተዋል';

  @override
  String get contentWarningLabel => 'የይዘት ማስጠንቀቂያ';

  @override
  String get contentWarningNudity => 'እርቃንነት';

  @override
  String get contentWarningSexualContent => 'ወሲባዊ ይዘት';

  @override
  String get contentWarningPornography => 'የብልግና ሥዕሎች';

  @override
  String get contentWarningGraphicMedia => 'ግራፊክ ሚዲያ';

  @override
  String get contentWarningViolence => 'ብጥብጥ';

  @override
  String get contentWarningSelfHarm => 'ራስን መጉዳት።';

  @override
  String get contentWarningDrugUse => 'የመድሃኒት አጠቃቀም';

  @override
  String get contentWarningAlcohol => 'አልኮል';

  @override
  String get contentWarningTobacco => 'ትምባሆ';

  @override
  String get contentWarningGambling => 'ቁማር';

  @override
  String get contentWarningProfanity => 'ስድብ';

  @override
  String get contentWarningFlashingLights => 'ብልጭ ድርግም የሚሉ መብራቶች';

  @override
  String get contentWarningAiGenerated => 'በAI የተፈጠረ';

  @override
  String get contentWarningSpoiler => 'ስፒለር';

  @override
  String get contentWarningSensitiveContent => 'ሚስጥራዊነት ያለው ይዘት';

  @override
  String get contentWarningDescNudity => 'እርቃን ወይም ከፊል እርቃንነትን ይይዛል';

  @override
  String get contentWarningDescSexual => 'ወሲባዊ ይዘት ይዟል';

  @override
  String get contentWarningDescPorn => 'ግልጽ የሆነ የወሲብ ስራ ይዘት ይዟል';

  @override
  String get contentWarningDescGraphicMedia => 'ግራፊክ ወይም የሚረብሽ ምስሎችን ይዟል';

  @override
  String get contentWarningDescViolence => 'የጥቃት ይዘት ይዟል';

  @override
  String get contentWarningDescSelfHarm => 'ራስን መጉዳት ማጣቀሻዎችን ይዟል';

  @override
  String get contentWarningDescDrugs => 'ከመድኃኒት ጋር የተያያዘ ይዘት ይዟል';

  @override
  String get contentWarningDescAlcohol => 'ከአልኮል ጋር የተያያዘ ይዘት ይዟል';

  @override
  String get contentWarningDescTobacco => 'ከትንባሆ ጋር የተያያዘ ይዘት ይዟል';

  @override
  String get contentWarningDescGambling => 'ከቁማር ጋር የተያያዘ ይዘት ይዟል';

  @override
  String get contentWarningDescProfanity => 'ጠንካራ ቋንቋ ይይዛል';

  @override
  String get contentWarningDescFlashingLights =>
      'ብልጭ ድርግም የሚሉ መብራቶችን ይዟል (የፎቶ ትብነት ማስጠንቀቂያ)';

  @override
  String get contentWarningDescAiGenerated => 'ይህ ይዘት በ AI የመነጨ ነው።';

  @override
  String get contentWarningDescSpoiler => 'አጥፊዎችን ይይዛል';

  @override
  String get contentWarningDescContentWarning =>
      'ፈጣሪ ይህንን እንደ ሚስጥራዊነት ምልክት አድርጎታል።';

  @override
  String get contentWarningDescDefault => 'ፈጣሪ ይህንን ይዘት ጠቁሟል';

  @override
  String get contentWarningDetailsTitle => 'የይዘት ማስጠንቀቂያዎች';

  @override
  String get contentWarningDetailsSubtitle => 'ፈጣሪው እነዚህን መለያዎች ተግባራዊ አድርጓል፡-';

  @override
  String get contentWarningManageFilters => 'የይዘት ማጣሪያዎችን ያቀናብሩ';

  @override
  String get contentWarningViewAnyway => 'ለማንኛውም ይመልከቱ';

  @override
  String get contentWarningReportContentTooltip => 'ይዘትን ሪፖርት አድርግ';

  @override
  String get contentWarningBlockUserTooltip => 'ተጠቃሚን አግድ';

  @override
  String get contentWarningBlockedTitle => 'ይዘት ታግዷል';

  @override
  String get contentWarningBlockedPolicy => 'ይህ ይዘት በፖሊሲ ጥሰቶች ምክንያት ታግዷል።';

  @override
  String get contentWarningNoticeTitle => 'የይዘት ማሳሰቢያ';

  @override
  String get contentWarningPotentiallyHarmfulTitle => 'ሊጎዳ የሚችል ይዘት';

  @override
  String get contentWarningView => 'ይመልከቱ';

  @override
  String get contentWarningReportAction => 'ሪፖርት';

  @override
  String get contentWarningHideAllLikeThis => 'ሁሉንም እንደዚህ ያሉ ይዘቶችን ደብቅ';

  @override
  String get contentWarningNoFilterYet =>
      'ለዚህ ማስጠንቀቂያ እስካሁን ምንም የተቀመጠ ማጣሪያ የለም።';

  @override
  String get contentWarningHiddenConfirmation =>
      'ከአሁን በኋላ እንደዚህ አይነት ልጥፎችን እንደብቃለን።';

  @override
  String get communitySuggestTitle => 'ለመመደብ ያግዙን';

  @override
  String get communitySuggestSubtitle =>
      'የይዘት ማስጠንቀቂያ ይጎድለዋል? ጥቆማዎ የሕዝባዊ፣ የተፈረመ እና ወደ ኋላ መመለስ የማይችል ነው።';

  @override
  String get communitySuggestSubmit => 'ጥቆማ አድርግ';

  @override
  String get communitySuggestSuccess => 'እናመሰግናለን። ጥቆማዎ ተልኳል።';

  @override
  String get communitySuggestFailure => 'ጥቆማዎን መላክ አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get communitySuggestAlready => 'ይህንን ጥቆማ አድርገዋል';

  @override
  String get communitySuggestActionLabel => 'መድብ';

  @override
  String get videoErrorNotFound => 'ቪዲዮ አልተገኘም።';

  @override
  String get videoErrorPlayback => 'የቪዲዮ መልሶ ማጫወት ስህተት';

  @override
  String get videoErrorAgeRestricted => 'በእድሜ የተገደበ ይዘት';

  @override
  String get videoErrorUnavailable => 'ቪዲዮ አይገኝም';

  @override
  String get videoErrorUnavailableBody => 'ይህ ቪዲዮ አሁን አይገኝም።';

  @override
  String get videoErrorRetry => 'እንደገና ይሞክሩ';

  @override
  String get videoErrorContentRestricted => 'ይዘት ተገድቧል';

  @override
  String get videoErrorContentRestrictedBody =>
      'ይህ ቪዲዮ የይዘት ደንቦቻችንን በመጣሱ ተወግዷል።';

  @override
  String get videoErrorVerifyAgeBody => 'ይህን ቪዲዮ ለማየት እድሜዎን ያረጋግጡ።';

  @override
  String get videoErrorSkip => 'ዝለል';

  @override
  String get videoErrorVerifyAgeButton => 'ዕድሜን ያረጋግጡ';

  @override
  String get videoErrorVerifyAgeFailed => 'ዕድሜህን ማረጋገጥ አልተቻለም። እባክህ እንደገና ሞክር';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'ማረጋገጡ ጊዜው አልፎበታል። ግንኙነትህን አረጋግጥ ወይም ትንሽ ቆይተህ እንደገና ሞክር።';

  @override
  String get videoErrorAdultContentHiddenTitle => 'የአዋቂዎች ይዘት ጠፍቷል';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'ይህን ቪዲዮ ለማየት በይዘት ማጣሪያዎችዎ ውስጥ ያብሩት።';

  @override
  String get videoErrorAdultContentHiddenAction => 'የይዘት ማጣሪያዎችን ክፈት';

  @override
  String get videoDetailLoadError => 'ቪዲዮ መጫን አልተሳካም';

  @override
  String get videoDetailLoadErrorBody => 'እዚህ ሲደርስ የሆነ ችግር ተፈጥሯል። እንደገና ሞክር።';

  @override
  String get videoDetailNotFoundBody =>
      'ተሰርዞ ሊሆን ይችላል፣ ከአቅም ውጭ ሊሆን ይችላል፣ ወይም በቅንብሮችህ ተደብቆ ሊሆን ይችላል።';

  @override
  String get databaseCorruptionTitle => 'የአካባቢዎ ውሂብ ተበላሽቷል';

  @override
  String get databaseCorruptionBody =>
      'Divine ን ዘግተው እንደገና ይክፈቱት — በራስ-ሰር እናስተካክለዋለን። የቻልነውን ያህል ረቂቆችዎን እና ክሊፖችዎን እናስቀራለን፣ የቀረው እንደገና ይጫናል።';

  @override
  String get databaseCorruptionCloseButton => 'Divine ን ዝጋ';

  @override
  String get videoDetailContextTitle => 'የተጋራ ቪዲዮ';

  @override
  String get videoDetailCloseSemanticLabel => 'የቪዲዮ ማጫወቻን ዝጋ';

  @override
  String get videoFollowButtonFollow => 'ተከተል';

  @override
  String get audioAttributionOriginalSound => 'ኦሪጅናል ድምጽ';

  @override
  String get audioAttributionUnavailableSound => 'ድምጽ አይገኝም';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'በ@$creatorName +$additionalCreatorCount የተነሳሳ';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'በ@$creatorName የተነሳሳ';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'ከ@$name ጋር';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'ከ@$name +$count ጋር';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ተባባሪዎች',
      one: '$count ተባባሪ',
    );
    return '$_temp0። መገለጫውን ለማየት መታ አድርግ።';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'በመጠባበቅ ላይ';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'በመጠባበቅ ላይ ያለ ተባባሪ';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending በመጠባበቅ ላይ)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name። መገለጫውን ለማየት ንካ።';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag። ይህን ሃሽታግ ያላቸውን ቪዲዮዎች ለማየት መታ ያድርጉ።';
  }

  @override
  String get listAttributionFallback => 'ዝርዝር';

  @override
  String get shareVideoLabel => 'ቪዲዮ አጋራ';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'ልጥፍ ለ$recipientName ተጋርቷል።';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ልጥፍ ለ$count ሰዎች ተጋርቷል።',
      one: 'ልጥፍ ለ$count ሰው ተጋርቷል።',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'ቪዲዮ መላክ አልተሳካም።';

  @override
  String get shareAddedToBookmarks => 'ወደ ዕልባቶች ታክሏል።';

  @override
  String get shareRemovedFromBookmarks => 'ከዕልባቶች ተወግዷል';

  @override
  String get shareFailedToAddBookmark => 'ዕልባት ማከል አልተሳካም።';

  @override
  String get shareFailedToRemoveBookmark => 'ዕልባትን ማስወገድ አልተሳካም።';

  @override
  String get shareActionFailed => 'እርምጃ አልተሳካም።';

  @override
  String get shareWithTitle => 'ሼር በማድረግ ያካፍሉ።';

  @override
  String get shareFindPeople => 'ሰዎችን ያግኙ';

  @override
  String get shareFindPeopleMultiline => 'አግኝ\nሰዎች';

  @override
  String get shareSent => 'ተልኳል።';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name ተመርጧል';
  }

  @override
  String get shareMessageHint => 'አማራጭ መልእክት አክል...';

  @override
  String get videoActionUnlike => 'ከቪዲዮ በተቃራኒ';

  @override
  String get videoActionLike => 'ልክ እንደ ቪዲዮ';

  @override
  String get videoActionAutoLabel => 'ማጠናቀር';

  @override
  String get videoActionLikeLabel => 'እንደ';

  @override
  String get videoActionReplyLabel => 'መልስ';

  @override
  String get videoActionRepostLabel => 'እንደገና ይለጥፉ';

  @override
  String get videoActionShareLabel => 'አጋራ';

  @override
  String get videoActionReportLabel => 'ሪፖርት';

  @override
  String get videoActionReport => 'ቪዲዮውን ሪፖርት አድርግ';

  @override
  String get videoActionEditLabel => 'አርትዕ';

  @override
  String get videoActionEdit => 'ቪዲዮውን አርትዕ';

  @override
  String get videoActionAboutLabel => 'ስለ';

  @override
  String get videoActionEnableAutoAdvance => 'አውቶማቲክ ማስቀደምን አንቃ';

  @override
  String get videoActionDisableAutoAdvance => 'ራስ-ሰር ማስቀደምን አሰናክል';

  @override
  String get videoActionRemoveRepost => 'ድጋሚ ልጥፍን ያስወግዱ';

  @override
  String get videoActionRepost => 'ቪዲዮውን እንደገና ይለጥፉ';

  @override
  String get videoActionViewComments => 'አስተያየቶችን ይመልከቱ';

  @override
  String get videoActionMoreOptions => 'ተጨማሪ አማራጮች';

  @override
  String get videoEngagementLikersTitle => 'የወደዱት';

  @override
  String get videoEngagementRepostersTitle => 'እንደገና ያጋሩት';

  @override
  String get videoEngagementLikersEmpty => 'እስካሁን ምንም ምልክት የለም';

  @override
  String get videoEngagementRepostersEmpty => 'እስካሁን ምንም ድጋሚ ጋራ የለም';

  @override
  String get videoEngagementLoadFailed => 'ዝርዝሩን መጫን አልተቻለም';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'የቪዲዮ ዝርዝሮችን ይክፈቱ';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'የቪዲዮ ዝርዝሮችን ይክፈቱ';

  @override
  String get videoOverlayCommentBarHint => 'አስተያየት አክል...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'አስተያየት አክል';

  @override
  String get videoOverlayCommentBarSendLabel => 'አስተያየት ላክ';

  @override
  String get videoOverlayCommentPostedSnackbar => 'አስተያየት ተለጠፈ';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'አስተያየት መለጠፍ አልተቻለም';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ሉፖች',
      one: 'ሉፕ',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'አይደለም Divine';

  @override
  String get metadataBadgeHumanMade => 'ሰው ሰራሽ';

  @override
  String get metadataSoundsLabel => 'ይሰማል።';

  @override
  String get metadataOriginalSound => 'ኦሪጅናል ድምጽ';

  @override
  String get metadataVerificationLabel => 'ማረጋገጥ';

  @override
  String get metadataDeviceAttestation => 'የመሣሪያ ማረጋገጫ';

  @override
  String get metadataPgpSignature => 'PGP ፊርማ';

  @override
  String get metadataC2paCredentials => 'C2PA የይዘት ምስክርነቶች';

  @override
  String get metadataProofManifest => 'ማረጋገጫ አንጸባራቂ';

  @override
  String get metadataVerificationInfoTooltip => 'እነዚህ ማረጋገጫዎች ምን ማለት ናቸው?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'እነዚህ ማረጋገጫዎች ምን ማለት እንደሆኑ';

  @override
  String get metadataVerificationInfoIntro =>
      'እነዚህ ምልክቶች ከካሜራውና ከቪዲዮ ፋይሉ ራሱ ይመጣሉ። አንድ ቪዲዮ ብዙ ምልክቶች ሲኖሩት፣ ስለ መነሻው ማረጋገጥ የምንችለው ነገር ይበዛል።';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'የስልኩ ኦፕሬቲንግ ሲስተም ይህን የቀረጸውን መተግበሪያ አረጋግጦለታል። ይህ ከካሜራ እንደመጣ እንጂ አንድ ሰው የጫነው ፋይል እንዳልሆነ ጠንካራ ማስረጃ ነው።';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'ቪዲዮው በተቀረጸበት ቅጽበት በምስጠራ ተፈርሟል። ከዚያ በኋላ አንድ ፍሬም እንኳ ከተቀየረ ፊርማው ይሰበራል።';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'በፋይሉ ውስጥ አብሮ የሚጓዝ የኢንዱስትሪ ደረጃ የመነሻ መዝገብ — ስለዚህ ከDivine ውጪ ያሉ መተግበሪያዎችም ሊያረጋግጡት ይችላሉ።';

  @override
  String get metadataVerificationInfoProofManifest =>
      'ሙሉው የProofMode መዝገብ፦ የፋይል አሻራ፣ የጊዜ ማህተም እና የቀረጻ አውድ ከቪዲዮው ጋር አብረው።';

  @override
  String get metadataVerificationInfoFootnote =>
      'አንድ ማረጋገጫ መጥፋቱ ቪዲዮውን ሐሰተኛ አያደርገውም። የቆዩ ክሊፖችና የተጫኑ ፋይሎች ከመጀመሪያውም አልነበራቸውም — ያንን ክፍል ማረጋገጥ አንችልም ማለት ብቻ ነው።';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'ተጨማሪ በ$url ይመልከቱ';
  }

  @override
  String get metadataCreatorLabel => 'ፈጣሪ';

  @override
  String get metadataCollaboratorsLabel => 'ተባባሪዎች';

  @override
  String get metadataInspiredByLabel => 'ተመስጦ';

  @override
  String get metadataRepostedByLabel => 'በድጋሚ የተለጠፈው በ';

  @override
  String metadataMoreReposters(int count) {
    return '+$count ተጨማሪ';
  }

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ሉፖች',
      one: 'ሉፕ',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'መውደዶች';

  @override
  String get metadataCommentsLabel => 'አስተያየቶች';

  @override
  String get metadataRepostsLabel => 'ድጋሚ ልጥፎች';

  @override
  String get metadataVineStatsLabel => 'በVine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops ሉፖች · $likes መውደዶች · $comments አስተያየቶች · $reposts ድጋሚ ልጥፎች';
  }

  @override
  String get metadataDivineStatsLabel => 'በDivine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views እይታዎች · $likes መውደዶች · $comments አስተያየቶች · $reposts ድጋሚ ልጥፎች';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'የተለጠፈው $date ላይ ነው።';
  }

  @override
  String get devOptionsTitle => 'የገንቢ አማራጮች';

  @override
  String get devOptionsDisableDeveloperMode => 'የገንቢ ሁነታን አሰናክል';

  @override
  String get devOptionsDisableDeveloperModeSubtitle => 'የገንቢ አማራጮችን ከቅንብሮች ደብቅ';

  @override
  String get devOptionsDisableDeveloperModeToast => 'የገንቢ ሁነታ ተሰናክሏል';

  @override
  String get devOptionsShorebirdTitle => 'የShorebird ማስተካከያዎች';

  @override
  String get devOptionsShorebirdPatchLabel => 'እየሰራ ያለ ማስተካከያ';

  @override
  String get devOptionsShorebirdNoPatch => 'ምንም ማስተካከያ አልተጫነም';

  @override
  String get devOptionsShorebirdUnavailable => 'በዚህ ግንባታ ውስጥ አይገኝም';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'ማስተካከያዎች በshorebird release በተፈጠረ ግንባታ ውስጥ ብቻ ይሰራሉ።';

  @override
  String get devOptionsShorebirdLoading => 'የማስተካከያ ሁኔታ እየተነበበ ነው…';

  @override
  String get devOptionsShorebirdNotChecked => 'የሙከራ ትራኩ ገና አልተፈተሸም።';

  @override
  String get devOptionsShorebirdCheck => 'የሙከራ ትራኩን ፈትሽ';

  @override
  String get devOptionsShorebirdApply => 'የሙከራ ማስተካከያውን ተግብር';

  @override
  String get devOptionsShorebirdUseStable => 'ወደ የተረጋጋ ዝማኔዎች ተመለስ';

  @override
  String get devOptionsShorebirdChecking => 'የሙከራ ትራኩ እየተፈተሸ ነው…';

  @override
  String get devOptionsShorebirdUpdateAvailable => 'የሙከራ ማስተካከያ ለመተግበር ዝግጁ ነው።';

  @override
  String get devOptionsShorebirdUpToDate => 'ለዚህ ልቀት የሙከራ ማስተካከያ የለም።';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'ወርዷል። ለመጫን መተግበሪያውን እንደገና ያስጀምሩ።';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'መመለሻ ዝግጁ ነው። ወደ መሰረታዊ ልቀት ለመመለስ እንደገና ያስጀምሩ።';

  @override
  String get devOptionsShorebirdApplying => 'እየወረደ እና እየተጫነ ነው…';

  @override
  String get devOptionsShorebirdApplied => 'ተጭኗል። ለመጫን መተግበሪያውን እንደገና ያስጀምሩ።';

  @override
  String get devOptionsShorebirdUnchanged =>
      'ምንም አልተጫነም። የሙከራ ትራኩን ፈትሸው እንደገና ይሞክሩ።';

  @override
  String get devOptionsShorebirdSelectingStableTrack => 'የተረጋጋ ትራክ በመምረጥ ላይ…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'የተረጋጋ ትራክ ተመርጧል። የተረጋጋ ፓች ለመፈተሽ መተግበሪያውን ዳግም ያስጀምሩ።';

  @override
  String get devOptionsShorebirdFailure => 'አልተሳካም። ለዝርዝሮች ምዝግቦቹን ይመልከቱ።';

  @override
  String get devOptionsPageLoadTimes => 'የገጽ ጭነት ጊዜያት';

  @override
  String get devOptionsNoPageLoads =>
      'እስካሁን ምንም የገጽ ጭነቶች አልተመዘገበም።\nየጊዜ ውሂብን ለማየት በመተግበሪያው ውስጥ ያስሱ።';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'የሚታይ፡ ${visibleMs}ms | ውሂብ፡ ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'በጣም ቀርፋፋ ስክሪኖች';

  @override
  String get devOptionsVideoPlaybackFormat => 'የቪዲዮ መልሶ ማጫወት ቅርጸት';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'አካባቢ ይቀየር?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'ወደ $envName ቀይር?\n\nይህ የተሸጎጠ የቪዲዮ ውሂብን ያጸዳል እና ከአዲሱ ሪሌይ ጋር እንደገና ይገናኛል።';
  }

  @override
  String get devOptionsCancel => 'ሰርዝ';

  @override
  String get devOptionsSwitch => 'ቀይር';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'ወደ $envName ተቀይሯል';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'ወደ $formatName ተቀይሯል - መሸጎጫ ጸድቷል።';
  }

  @override
  String get featureFlagTitle => 'የባህሪ ባንዲራዎች';

  @override
  String get featureFlagResetAllTooltip => 'ሁሉንም ባንዲራዎች ወደ ነባሪዎች ዳግም ያስጀምሩ';

  @override
  String get featureFlagError => 'ስህተት';

  @override
  String get relaySettingsTitle => 'ቅብብሎሽ';

  @override
  String get relaySettingsInfoTitle => 'Divine ክፍት ስርዓት ነው - ግንኙነቶችዎን ይቆጣጠራሉ።';

  @override
  String get relaySettingsInfoDescription =>
      'እነዚህ ማስተላለፊያዎች የእርስዎን ይዘት ባልተማከለው Nostr አውታረ መረብ ላይ ያሰራጫሉ። እንደፈለጉ ማሰራጫዎችን ማከል ወይም ማስወገድ ይችላሉ።';

  @override
  String get relaySettingsLearnMoreNostr => 'ስለ Nostr ተጨማሪ ተማር →';

  @override
  String get relaySettingsFindPublicRelays => 'የህዝብ ሪሌዮችን በ nostr.co.uk ፈልግ →';

  @override
  String get relaySettingsAppNotFunctional => 'መተግበሪያ ተግባራዊ አይደለም።';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine ቪዲዮዎችን ለመጫን፣ ይዘትን ለመለጠፍ እና ውሂብ ለማመሳሰል ቢያንስ አንድ ቅብብል ያስፈልገዋል።';

  @override
  String get relaySettingsRestoreDefaultRelay => 'ነባሪ ቅብብሎሽ እነበረበት መልስ';

  @override
  String get relaySettingsAddCustomRelay => 'ብጁ ቅብብል ያክሉ';

  @override
  String get relaySettingsAddRelay => 'ቅብብል ጨምር';

  @override
  String get relaySettingsRetry => 'እንደገና ይሞክሩ';

  @override
  String get relaySettingsNoStats => 'እስካሁን ምንም ስታቲስቲክስ የለም።';

  @override
  String get relaySettingsConnection => 'ግንኙነት';

  @override
  String get relaySettingsConnected => 'ተገናኝቷል።';

  @override
  String get relaySettingsDisconnected => 'ግንኙነቱ ተቋርጧል';

  @override
  String get relaySettingsSessionDuration => 'የክፍለ ጊዜው ቆይታ';

  @override
  String get relaySettingsLastConnected => 'መጨረሻ የተገናኘው።';

  @override
  String get relaySettingsDisconnectedLabel => 'ግንኙነቱ ተቋርጧል';

  @override
  String get relaySettingsReason => 'ምክንያት';

  @override
  String get relaySettingsActiveSubscriptions => 'ንቁ የደንበኝነት ምዝገባዎች';

  @override
  String get relaySettingsTotalSubscriptions => 'ጠቅላላ የደንበኝነት ምዝገባዎች';

  @override
  String get relaySettingsEventsReceived => 'ክስተቶች ተቀብለዋል';

  @override
  String get relaySettingsEventsSent => 'ክስተቶች ተልከዋል።';

  @override
  String get relaySettingsRequestsThisSession => 'ይህንን ክፍለ ጊዜ ጠይቋል';

  @override
  String get relaySettingsFailedRequests => 'ያልተሳኩ ጥያቄዎች';

  @override
  String get relaySettingsLoadingRelayInfo => 'የማስተላለፊያ መረጃን በመጫን ላይ...';

  @override
  String get relaySettingsAboutRelay => 'ስለ ሪሌይ';

  @override
  String get relaySettingsSupportedNips => 'የሚደገፉ NIPዎች';

  @override
  String get relaySettingsSoftware => 'ሶፍትዌር';

  @override
  String get relaySettingsViewWebsite => 'ድህረ ገጽ ይመልከቱ';

  @override
  String get relaySettingsRemoveRelayTitle => 'ሪሌይ ይወገድ?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'እርግጠኛ ነዎት ይህን ቅብብል ማስወገድ ይፈልጋሉ?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'የDivine ቅብብሎሽ ይወገድ?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'የDivine ቅብብሎሽን ማስወገድ የመተግበሪያውን አጠቃቀም ያዳክማል። ቪዲዮዎች፣ ልጥፎች እና ማመሳሰል አስተማማኝ ላይሆኑ ይችላሉ። ይህን ማድረግ ያለባቸው ልምድ ያላቸው የNostr ተጠቃሚዎች ብቻ ናቸው።\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'ቅብብሎሽ አስወግድ';

  @override
  String get relaySettingsCancel => 'ሰርዝ';

  @override
  String get relaySettingsRemove => 'አስወግድ';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'የተወገደ ቅብብል፡ $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'ቅብብሎሽ ማስወገድ አልተሳካም።';

  @override
  String get relaySettingsForcingReconnection =>
      'የዝውውር ዳግም ግንኙነትን በማስገደድ ላይ...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'ከ $count ሪሌይ(ዎች) ጋር ተገናኝቷል!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'ከቅብብሎሽ ጋር መገናኘት አልተሳካም። እባክዎ የአውታረ መረብ ግንኙነትዎን ያረጋግጡ።';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'በዚህ መሣሪያ ላይ ተቀምጧል። ማተም እንደገና ሲሰራ ወደ መለያዎ እናስመሳስለዋለን።';

  @override
  String get relaySettingsAddRelayTitle => 'ቅብብል ጨምር';

  @override
  String get relaySettingsAddRelayPrompt =>
      'ማከል የምትፈልገውን የሪሌይ WebSocket URL አስገባ:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'በ nostr.co.uk ላይ የህዝብ ማሰራጫዎችን ያስሱ';

  @override
  String get relaySettingsAdd => 'አክል';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'የተጨመረው ቅብብሎሽ፡ $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'ቅብብሎሽ ማከል አልተሳካም። እባክህ URLን ተመልከት እና እንደገና ሞክር።';

  @override
  String get relaySettingsInvalidUrl => 'ሪሌይ URL በ wss:// ወይም ws:// መጀመር አለበት።';

  @override
  String get relaySettingsInsecureUrl =>
      'የሪሌይ URL wss:// መጠቀም አለበት (ws:// ለlocalhost ብቻ ይፈቀዳል)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'ወደነበረበት የተመለሰ ነባሪ ቅብብሎሽ፡ $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'ነባሪ ቅብብሎሽ ወደነበረበት መመለስ አልተሳካም። እባክዎ የአውታረ መረብ ግንኙነትዎን ያረጋግጡ።';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'አሳሽ መክፈት አልተቻለም';

  @override
  String get relaySettingsFailedToOpenLink => 'አገናኝ መክፈት አልተሳካም።';

  @override
  String get relaySettingsExternalRelay => 'ውጫዊ ቅብብሎሽ';

  @override
  String get relaySettingsNotConnected => 'አልተገናኘም';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'ከ$duration በፊት ተቋርጧል';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count ደንበኝነቶች';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count ክስተቶች';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'ከ$duration በፊት';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine ለያልተማከለ ማተም Nostr ፕሮቶኮልን ይጠቀማል። ይዘትዎ በሚመርጧቸው ቅብብሎሾች ላይ ይኖራል፣ ቁልፎችዎም ማንነትዎ ናቸው።';

  @override
  String get nostrSettingsSectionNetwork => 'አውታረ መረብ';

  @override
  String get nostrSettingsSectionAccount => 'መለያ';

  @override
  String get nostrSettingsSectionDangerZone => 'አደገኛ ቦታ';

  @override
  String get nostrSettingsRelays => 'ቅብብሎሾች';

  @override
  String get nostrSettingsRelaysSubtitle => 'የNostr ቅብብሎሽ ግንኙነቶችን ያስተዳድሩ';

  @override
  String get nostrSettingsRelayDiagnostics => 'የቅብብሎሽ ምርመራ';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'የቅብብሎሽ ግንኙነትን እና የአውታረ መረብ ችግሮችን ያስሱ';

  @override
  String get nostrSettingsMediaServers => 'የሚዲያ አገልጋዮች';

  @override
  String get nostrSettingsMediaServersSubtitle => 'የBlossom ማስጫኛ አገልጋዮችን ያቀናብሩ';

  @override
  String get settingsDeveloperOptions => 'የገንቢ አማራጮች';

  @override
  String get settingsDeveloperOptionsSubtitle => 'የአካባቢ መቀየሪያ እና የማረሚያ ቅንብሮች';

  @override
  String get nostrSettingsKeyManagement => 'የቁልፍ አስተዳደር';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'የNostr ቁልፎችዎን ወደ ውጭ ይላኩ፣ ምትኬ ያስቀምጡ እና ይመልሱ';

  @override
  String get nostrSettingsClientAttribution => 'የደንበኛ መለያ';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'በሚያትሟቸው ክስተቶች ላይ የDivine ደንበኛ መለያ ያክሉ፣ ሌሎች የNostr መተግበሪያዎች በትክክል እንዲጠቅሷቸው። ያለሱ፣ የሚልኳቸው ሪፖርቶች አወያዮቻችን ሲገመግሟቸው ያነሰ ክብደት ይኖራቸዋል።';

  @override
  String get nostrSettingsMoveAccount => 'መለያዎን ያንቀሳቅሱ';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'ማህደርዎን ያውርዱ እና ልጥፎችዎን እና ቪዲዮዎችዎን ወደ ሌላ relay ወይም የሚዲያ አገልጋይ ያንቀሳቅሱ።';

  @override
  String get nostrSettingsRemoveKeys => 'ቁልፎችን ከመሣሪያው አስወግድ';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'የግል ቁልፍዎን ከዚህ መሣሪያ ብቻ ይሰርዙ። ይዘትዎ በቅብብሎሾች ላይ ይቆያል፣ ግን መለያዎን እንደገና ለመጠቀም የnsec ምትኬዎን ያስፈልግዎታል።';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'ይህን መለያ ከዚህ መሣሪያ ማስወገድ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get nostrSettingsDeleteAccount => 'መለያ እና ውሂብ ሰርዝ';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'የይዘትዎን የመሰረዝ ጥያቄዎች ይልካል እና ከዚህ መሣሪያ ያስወጣዎታል። ቅብብሎሾች፣ ደንበኞች፣ የፍለጋ ማውጫዎች እና ሌሎች የገቡ መሣሪያዎች ቅጂዎችን ሊይዙ ይችላሉ።';

  @override
  String get relayDiagnosticTitle => 'ቅብብል ምርመራዎች';

  @override
  String get relayDiagnosticRefreshTooltip => 'ምርመራዎችን ያድሱ';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'የመጨረሻው መታደስ፡ $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'የማስተላለፊያ ሁኔታ';

  @override
  String get relayDiagnosticInitialized => 'ተጀመረ';

  @override
  String get relayDiagnosticReady => 'ዝግጁ';

  @override
  String get relayDiagnosticNotInitialized => 'አልተጀመረም።';

  @override
  String get relayDiagnosticDatabaseEvents => 'የውሂብ ጎታ ክስተቶች';

  @override
  String get relayDiagnosticActiveSubscriptions => 'ንቁ የደንበኝነት ምዝገባዎች';

  @override
  String get relayDiagnosticExternalRelays => 'የውጭ ማስተላለፊያዎች';

  @override
  String get relayDiagnosticConfigured => 'የተዋቀረ';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count ቅብብል(ዎች)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'ተገናኝቷል።';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'የቪዲዮ ዝግጅቶች';

  @override
  String get relayDiagnosticHomeFeed => 'የቤት ምግብ';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String get relayDiagnosticDiscovery => 'ግኝት';

  @override
  String get relayDiagnosticLoading => 'በመጫን ላይ';

  @override
  String get relayDiagnosticYes => 'አዎ';

  @override
  String get relayDiagnosticNo => 'አይ';

  @override
  String get relayDiagnosticTestDirectQuery => 'ቀጥተኛ መጠይቅን ሞክር';

  @override
  String get relayDiagnosticNetworkConnectivity => 'የአውታረ መረብ ግንኙነት';

  @override
  String get relayDiagnosticRunNetworkTest => 'የአውታረ መረብ ሙከራን አሂድ';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom አገልጋይ';

  @override
  String get relayDiagnosticTestAllEndpoints => 'ሁሉንም የመጨረሻ ነጥቦችን ይሞክሩ';

  @override
  String get relayDiagnosticStatus => 'ሁኔታ';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'ስህተት';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake ኤፒአይ';

  @override
  String get relayDiagnosticBaseUrl => 'መሰረታዊ URL';

  @override
  String get relayDiagnosticSummary => 'ማጠቃለያ';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount እሺ (አማካኝ ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'ሁሉንም እንደገና ሞክር';

  @override
  String get relayDiagnosticRetrying => 'እንደገና በመሞከር ላይ...';

  @override
  String get relayDiagnosticRetryConnection => 'ግንኙነትን እንደገና ይሞክሩ';

  @override
  String get relayDiagnosticTroubleshooting => 'መላ መፈለግ';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• አረንጓዴ ሁኔታ = የተገናኘ እና የሚሰራ\n• ቀይ ሁኔታ = ግንኙነት አልተሳካም።\n• የአውታረ መረብ ሙከራ ካልተሳካ የበይነመረብ ግንኙነትን ያረጋግጡ\n• ማስተላለፎች ከተዋቀሩ ግን ካልተገናኙ \"ግንኙነቱን እንደገና ሞክር\" ን ይንኩ።\n• ለማረም ይህንን ስክሪን ያንሱ';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'ሁሉም REST የመጨረሻ ነጥቦች ጤናማ ናቸው!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'አንዳንድ REST የመጨረሻ ነጥቦች አልተሳኩም - ዝርዝሮችን ከላይ ይመልከቱ';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'በመረጃ ቋት ውስጥ $count የቪዲዮ ክስተቶች ተገኝተዋል';
  }

  @override
  String get relayDiagnosticQueryFailed => 'መጠይቁ አልተሳካም፡። እባክህ እንደገና ሞክር።';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'ከ $count ሪሌይ(ዎች) ጋር ተገናኝቷል!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'ከማንኛውም ማስተላለፊያዎች ጋር መገናኘት አልተሳካም።';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'የግንኙነት ድጋሚ መሞከር አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'ተገናኝቷል እና የተረጋገጠ';

  @override
  String get relayDiagnosticConnectedOnly => 'ተገናኝቷል።';

  @override
  String get relayDiagnosticNotConnected => 'አልተገናኘም።';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'ምንም ቅብብሎሽ አልተዋቀረም።';

  @override
  String get relayDiagnosticFailed => 'አልተሳካም።';

  @override
  String get notificationSettingsTitle => 'ማሳወቂያዎች';

  @override
  String get notificationSettingsResetTooltip => 'ወደ ነባሪዎች ዳግም አስጀምር';

  @override
  String get notificationSettingsTypes => 'የማሳወቂያ ዓይነቶች';

  @override
  String get notificationSettingsLikes => 'መውደዶች';

  @override
  String get notificationSettingsLikesSubtitle => 'አንድ ሰው ቪዲዮዎችዎን ሲወድ';

  @override
  String get notificationSettingsComments => 'አስተያየቶች';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'አንድ ሰው በቪዲዮዎችዎ ላይ አስተያየት ሲሰጥ';

  @override
  String get notificationSettingsFollows => 'ይከተላል';

  @override
  String get notificationSettingsFollowsSubtitle => 'ሰው ሲከተልህ';

  @override
  String get notificationSettingsMentions => 'ይጠቅሳል';

  @override
  String get notificationSettingsMentionsSubtitle => 'እርስዎ ሲጠቀሱ';

  @override
  String get notificationSettingsReposts => 'ድጋሚ ልጥፎች';

  @override
  String get notificationSettingsRepostsSubtitle => 'አንድ ሰው ቪዲዮዎችህን በድጋሚ ሲለጥፍ';

  @override
  String get notificationSettingsNewPosts => 'አዲስ ቫይኖች';

  @override
  String get notificationSettingsNewPostsSubtitle => 'የምትከታተለው ሰው ሲለጥፍ';

  @override
  String get notificationSettingsActions => 'ድርጊቶች';

  @override
  String get notificationSettingsMarkAllAsRead => 'ሁሉንም እንደተነበቡ ምልክት ያድርጉበት';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'ሁሉንም ማሳወቂያዎች እንደተነበቡ ምልክት ያድርጉባቸው';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'ሁሉም ማሳወቂያዎች እንደተነበቡ ምልክት ተደርጎባቸዋል';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'ሁሉንም እንደተነበቡ ለማመልከት አልተሳካም';

  @override
  String get notificationSettingsResetToDefaults =>
      'ቅንብሮች ወደ ነባሪዎች ዳግም ተጀምረዋል።';

  @override
  String get notificationSettingsAbout => 'ስለ ማሳወቂያዎች';

  @override
  String get notificationSettingsAboutDescription =>
      'ማሳወቂያዎች የተጎላበተው በNostr ፕሮቶኮል ነው። የቅጽበታዊ ዝማኔዎች ከNostr ቅብብሎሽ ጋር ባለዎት ግንኙነት ይወሰናል። አንዳንድ ማሳወቂያዎች መዘግየቶች ሊኖራቸው ይችላል።';

  @override
  String get safetySettingsWhatYouSee => 'የሚያዩት';

  @override
  String get safetySettingsWhatYouPublish => 'የሚያትሙት';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'በDivine የተስተናገዱ ቪዲዮዎችን ብቻ አሳይ';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'ከሌሎች የሚዲያ አስተናጋጆች የቀረቡ ቪዲዮዎችን ደብቅ';

  @override
  String get safetySettingsModeration => 'ሞደሬሽን';

  @override
  String get safetySettingsBlockedUsers => 'የታገዱ ተጠቃሚዎች';

  @override
  String get safetySettingsAgeVerification => 'የዕድሜ ማረጋገጫ';

  @override
  String get safetySettingsAgeConfirmation =>
      '18 ዓመት ወይም ከዚያ በላይ መሆኔን አረጋግጣለሁ።';

  @override
  String get safetySettingsAgeRequired => 'የአዋቂ ይዘት ለማየት ያስፈልጋል';

  @override
  String get safetySettingsAgeLockedForMinor => 'ለመለያዎ ተቆልፏል';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle => 'ይፋዊ የሽምግልና አገልግሎት (በነባሪ)';

  @override
  String get safetySettingsPeopleIFollow => 'የምከተላቸው ሰዎች';

  @override
  String get safetySettingsPeopleIFollowSubtitle => 'ለሚከተሏቸው ሰዎች መለያዎች ይመዝገቡ';

  @override
  String get safetySettingsAddCustomLabeler => 'ብጁ መሰየሚያ ያክሉ';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub አስገባ...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'ብጁ መለያ አክል';

  @override
  String get safetySettingsRemoveLabeler => 'መለያ አስወግድ';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub አድራሻ አስገባ';

  @override
  String get safetySettingsNoBlockedUsers => 'ምንም የታገዱ ተጠቃሚዎች የሉም';

  @override
  String get safetySettingsUnblock => 'እገዳ አንሳ';

  @override
  String get safetySettingsUserUnblocked => 'ተጠቃሚው ታግዷል';

  @override
  String get safetySettingsCancel => 'ሰርዝ';

  @override
  String get safetySettingsAdd => 'አክል';

  @override
  String get analyticsTitle => 'የፈጣሪ ትንታኔ';

  @override
  String get analyticsDiagnosticsTooltip => 'ምርመራዎች';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'ምርመራዎችን ቀያይር';

  @override
  String get analyticsRetry => 'እንደገና ይሞክሩ';

  @override
  String get analyticsUnableToLoad => 'ትንታኔዎችን መጫን አልተቻለም።';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired => 'የፈጣሪ ትንታኔን ለማየት ይግቡ።';

  @override
  String get analyticsViewDataUnavailable =>
      'ለእነዚህ ልጥፎች ከቅብብሎሽ እይታዎች በአሁኑ ጊዜ አይገኙም። መውደድ/አስተያየት/እንደገና መለጠፍ መለኪያዎች አሁንም ትክክል ናቸው።';

  @override
  String get analyticsViewDataTitle => 'ውሂብ ይመልከቱ';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'ተዘምኗል $time • ውጤቶች ሲገኙ መውደዶችን፣ አስተያየቶችን፣ ድጋሚ ልጥፎችን እና እይታዎችን ከFunnelcake ይጠቀማሉ።';
  }

  @override
  String get analyticsVideos => 'ቪዲዮዎች';

  @override
  String get analyticsViews => 'እይታዎች';

  @override
  String get analyticsInteractions => 'መስተጋብር';

  @override
  String get analyticsEngagement => 'ተሳትፎ';

  @override
  String get analyticsFollowers => 'ተከታዮች';

  @override
  String get analyticsAvgPerPost => 'አማካኝ/ልጥፍ';

  @override
  String get analyticsInteractionMix => 'መስተጋብር ድብልቅ';

  @override
  String get analyticsLikes => 'መውደዶች';

  @override
  String get analyticsComments => 'አስተያየቶች';

  @override
  String get analyticsReposts => 'ድጋሚ ልጥፎች';

  @override
  String get analyticsPerformanceHighlights => 'የአፈጻጸም ድምቀቶች';

  @override
  String get analyticsMostViewed => 'በብዛት የታዩት።';

  @override
  String get analyticsMostDiscussed => 'በብዛት ተወያይተዋል።';

  @override
  String get analyticsMostReposted => 'በጣም በድጋሚ የተለጠፈ';

  @override
  String get analyticsNoVideosYet => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get analyticsViewDataUnavailableShort => 'የእይታ ውሂብ አይገኝም';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count እይታዎች';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count አስተያየቶች';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count ድጋሚ ልጥፎች';
  }

  @override
  String get analyticsTopContent => 'ከፍተኛ ይዘት';

  @override
  String get analyticsPublishPrompt => 'ደረጃዎችን ለማየት ጥቂት ቪዲዮዎችን ያትሙ።';

  @override
  String get analyticsEngagementRateExplainer =>
      'የቀኝ ጎን % = የተሳትፎ መጠን (ግንኙነቶች በእይታዎች የተከፋፈሉ)።';

  @override
  String get analyticsEngagementRateNoViews =>
      'የተሳትፎ መጠን የእይታ ውሂብ ያስፈልገዋል; እይታዎች እስኪገኙ ድረስ እሴቶች እንደ N/A ያሳያሉ።';

  @override
  String get analyticsEngagementLabel => 'ተሳትፎ';

  @override
  String get analyticsViewsUnavailable => 'እይታዎች አይገኙም።';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count መስተጋብር';
  }

  @override
  String get analyticsPostAnalytics => 'ትንታኔ ይለጥፉ';

  @override
  String get analyticsOpenPost => 'ፖስት ክፈት';

  @override
  String get analyticsRecentDailyInteractions => 'የቅርብ ጊዜ ዕለታዊ ግንኙነቶች';

  @override
  String get analyticsNoActivityYet => 'በዚህ ክልል ውስጥ እስካሁን ምንም እንቅስቃሴ የለም።';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'መስተጋብር = መውደዶች + አስተያየቶች + በፖስታ ቀን የተለጠፈ።';

  @override
  String get analyticsDailyBarExplainer =>
      'የአሞሌ ርዝመት በዚህ መስኮት ውስጥ ካለህ ከፍተኛ ቀን ጋር አንጻራዊ ነው።';

  @override
  String get analyticsAudienceSnapshot => 'የታዳሚዎች ቅጽበታዊ ገጽ እይታ';

  @override
  String analyticsFollowersCount(String count) {
    return 'ተከታዮች፡ $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'በመከተል፡ $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Funnelcake የታዳሚ ትንታኔ መጨረሻ ነጥቦችን ሲጨምር፣ የታዳሚ ምንጭ/ጂኦ/ጊዜ ዝርዝሮች ይሞላሉ።';

  @override
  String get analyticsRetention => 'ማቆየት።';

  @override
  String get analyticsRetentionWithViews =>
      'የማቆያ ኩርባ እና የምልከታ ጊዜ መከፋፈል በሰከንድ/በባልዲ ማቆየት ከFunnelcake ሲመጣ ይታያል።';

  @override
  String get analyticsRetentionWithoutViews =>
      'የእይታ+ሰዓት-ጊዜ ትንታኔ በFunnelcake እስኪመለስ ድረስ የማቆየት ውሂብ አይገኝም።';

  @override
  String get analyticsDiagnostics => 'ምርመራዎች';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'ጠቅላላ ቪዲዮዎች፡ $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'ከእይታዎች ጋር፡ $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'የጎደሉ እይታዎች፡ $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'ሃይድሬድ (ጅምላ)፡ $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'የደረቀ (/እይታዎች)፡ $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'ምንጮች፡ $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'የቋሚ መረጃን ተጠቀም';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'አዲስ Divine መለያ ይፍጠሩ';

  @override
  String get authCreateNewAccountShort => 'አዲስ መለያ ፍጠር';

  @override
  String get authSignInDifferentAccount => 'በተለየ መለያ ይግቡ';

  @override
  String get authUseAnotherAccount => 'ሌላ መለያ ተጠቀም';

  @override
  String authContinueAs(String displayName) {
    return 'እንደ $displayName ቀጥል';
  }

  @override
  String get authRecoveryDraftsOwner => 'ረቂቆችዎ እና ክሊፖችዎ ለዚህ መለያ ተቀምጠዋል';

  @override
  String get authRecoveryOtherAccountWarning =>
      'እዚህ መግባት እነዚያ ረቂቆች እና ክሊፖች ይደብቃቸዋል';

  @override
  String get authTermsPrefix => 'ከታች አማራጭ በመምረጥህ ቢያንስ 16 ዓመት እንደሆንህ (ወይም ';

  @override
  String get authTermsAgeAuthorizationCta => 'የDivine የዕድሜ ፈቃድ';

  @override
  String get authTermsAfterAgeAuthorization => ' እንዳጠናቀቅህ) ታረጋግጣለህ፣ እንዲሁም ';

  @override
  String get authTermsOfService => 'የአገልግሎት ውል';

  @override
  String get authPrivacyPolicy => 'የግላዊነት ፖሊሲ';

  @override
  String get authTermsAnd => ', እና';

  @override
  String get authSafetyStandards => 'የደህንነት ደረጃዎች';

  @override
  String get authAmberNotInstalled => 'Amber መተግበሪያ አልተጫነም።';

  @override
  String get authAmberConnectionFailed => 'ከAmber ጋር መገናኘት አልተሳካም';

  @override
  String get authPasswordResetSent =>
      'በዚያ ኢሜይል መለያ ካለ፣ የይለፍ ቃል ዳግም ማስጀመሪያ አገናኝ ተልኳል።';

  @override
  String get authSignInTitle => 'ይግቡ';

  @override
  String get authEmailLabel => 'ኢሜይል';

  @override
  String get authPasswordLabel => 'የይለፍ ቃል';

  @override
  String get authConfirmPasswordLabel => 'የይለፍ ቃል አረጋግጥ';

  @override
  String get authEmailRequired => 'ኢሜይል ያስፈልጋል';

  @override
  String get authEmailInvalid => 'እባክህ ትክክለኛ ኢሜይል አስገባ';

  @override
  String get authPasswordRequired => 'የይለፍ ቃል ያስፈልጋል';

  @override
  String get authConfirmPasswordRequired => 'እባክህ የይለፍ ቃልህን አረጋግጥ';

  @override
  String get authPasswordsDoNotMatch => 'የይለፍ ቃሎቹ አይዛመዱም';

  @override
  String get authForgotPassword => 'የይለፍ ቃል ረሱ?';

  @override
  String get authImportNostrKey => 'አስመጣ Nostr ቁልፍ';

  @override
  String get authConnectSignerApp => 'ከፈራሚ መተግበሪያ ጋር ይገናኙ';

  @override
  String get authSignInWithAmber => 'በAmber ግባ';

  @override
  String get authSignInWithBrowserExtension => 'በአሳሽ ቅጥያ ይግቡ';

  @override
  String get authNip07ConnectionFailed => 'ከአሳሽ ቅጥያዎ ጋር መገናኘት አልተቻለም።';

  @override
  String get authNip07ExtensionNotFound =>
      'የአሳሽ ቅጥያ አልተገኘም። Alby፣ nos2x ወይም ሌላ ከ NIP-07 ጋር ተኳሃኝ የሆነ ቅጥያ ይጫኑ።';

  @override
  String get authSignInOptionsTitle => 'የመግባት አማራጮች';

  @override
  String get authInfoEmailPasswordTitle => 'ኢሜይል እና የይለፍ ቃል';

  @override
  String get authInfoEmailPasswordDescription =>
      'በDivine መለያህ ግባ። በኢሜይል እና በይለፍ ቃል ከተመዘገብክ፣ እዚህ ተጠቀማቸው።';

  @override
  String get authInfoImportNostrKeyDescription =>
      'አስቀድሞ Nostr ማንነት አለህ? የእርስዎን nsec የግል ቁልፍ ከሌላ ደንበኛ ያስመጡ።';

  @override
  String get authInfoSignerAppTitle => 'Signer መተግበሪያ';

  @override
  String get authInfoSignerAppDescription =>
      'ለተሻሻለ ቁልፍ ደህንነት እንደ NIP-46 ተስማሚ የርቀት ፈራሚ በመጠቀም ይገናኙ።';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'የእርስዎን Nostr ቁልፎች ደህንነቱ በተጠበቀ ሁኔታ ለማስተዳደር የAmber ፈራሚ መተግበሪያን በAndroid ይጠቀሙ።';

  @override
  String get authInfoBrowserExtensionTitle => 'አሳሽ ቅጥያ';

  @override
  String get authInfoBrowserExtensionDescription =>
      'እንደ Alby ወይም nos2x ያሉ የ NIP-07 አሳሽ ቅጥያ በመጠቀም ይግቡ። ቁልፎችዎ በቅጥያው ውስጥ ይቀራሉ — Divine በፍፁም አያያቸውም።';

  @override
  String get authSignInErrorInvalidCredentials =>
      'የተሳሳተ ኢሜይል ወይም የይለፍ ቃል። እንደገና ይሞክሩ።';

  @override
  String get authSignInErrorEmailNotVerified =>
      'ከመግባትዎ በፊት ኢሜይልዎን ያረጋግጡ — ለአገናኙ የገቢ መልእክት ሳጥንዎን ይመልከቱ።';

  @override
  String get authSignInErrorInvalidEmail => 'ይህ ትክክለኛ የኢሜይል አድራሻ አይመስልም።';

  @override
  String get authSignInErrorNetwork =>
      'አገልጋዩ ጋር መድረስ አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get authSignInErrorGeneric => 'የሆነ ችግር ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authSignInOptionsHintPrefix => 'ባለፈው ጊዜ እንዴት እንደገቡ እርግጠኛ አይደሉም? ';

  @override
  String get authSignInOptionsHintCta => 'ሁሉንም የመግቢያ አማራጮች ይመልከቱ';

  @override
  String get authCreateAccountTitle => 'መለያ ይፍጠሩ';

  @override
  String get authBackToInviteCode => 'ወደ ግብዣ ኮድ ተመለስ';

  @override
  String get authUseDivineNoBackup => 'ምንም ምትኬ ሳይኖር Divine ተጠቀም';

  @override
  String get authSkipConfirmTitle => 'አንድ የመጨረሻ ነገር...';

  @override
  String get authSkipConfirmKeyCreated =>
      'ገብተሃል! የእርስዎን Divine መለያ የሚያስተናግድ አስተማማኝ ቁልፍ እንፈጥራለን።';

  @override
  String get authSkipConfirmKeyOnly =>
      'ያለ ኢሜል፣ ይህ መለያ የእርስዎ መሆኑን የሚያውቅ ብቸኛው መንገድ የእርስዎ ቁልፍ ነው።';

  @override
  String get authSkipConfirmRecommendEmail =>
      'በመተግበሪያው ውስጥ ቁልፍዎን መድረስ ይችላሉ ፣ ግን ቴክኒካል ካልሆኑ አሁን ኢሜይል እና የይለፍ ቃል ማከል እንመክራለን። ይህ መሳሪያ ከጠፋብዎት ወይም ዳግም ካስጀመሩት ወደ መለያዎ መግባት እና ወደነበረበት መመለስ ቀላል ያደርገዋል።';

  @override
  String get authAddEmailPassword => 'ኢሜይል እና የይለፍ ቃል ያክሉ';

  @override
  String get authUseThisDeviceOnly => 'ይህንን መሳሪያ ብቻ ይጠቀሙ';

  @override
  String get authCompleteRegistration => 'ምዝገባዎን ያጠናቅቁ';

  @override
  String get authVerifying => 'በማረጋገጥ ላይ...';

  @override
  String get authVerificationLinkSent => 'የማረጋገጫ አገናኝ ልከናል ወደ፡-';

  @override
  String get authClickVerificationLink =>
      'እባክዎን በኢሜልዎ ውስጥ ያለውን አገናኝ ጠቅ ያድርጉ\nምዝገባዎን ያጠናቅቁ.';

  @override
  String get authPleaseWaitVerifying => 'እባክህ ኢሜልህን እስክናረጋግጥ ጠብቅ...';

  @override
  String get authWaitingForVerification => 'ማረጋገጫን በመጠበቅ ላይ';

  @override
  String get authOpenEmailApp => 'የኢሜል መተግበሪያን ይክፈቱ';

  @override
  String get authVerificationPinPrompt => 'ወይም ከኢሜይልዎ የ6-አሃዝ ኮድ ያስገቡ';

  @override
  String get authVerificationPinFieldLabel => 'የ6-አሃዝ ኮድ';

  @override
  String get authVerificationPinSubmit => 'ኮዱን አረጋግጥ';

  @override
  String get authVerificationResendPrompt => 'አልደረሰዎትም?';

  @override
  String get authVerificationResend => 'እንደገና ላክ';

  @override
  String authVerificationResendCooldown(String time) {
    return 'ከ$time በኋላ እንደገና ላክ';
  }

  @override
  String get authVerificationResendFailed =>
      'ኢሜይሉን እንደገና መላክ አልቻልንም። እንደገና ይሞክሩ።';

  @override
  String get authVerificationResendExpired =>
      'ያ ምዝገባ ጊዜው አልፎበታል። አዲስ ኮድ ለማግኘት እንደገና ጀምር።';

  @override
  String get authVerificationResendUnavailable =>
      'አሁን እንደገና መላክ አይቻልም። ቀደም ብለን በላክንልህ ኢሜይል ውስጥ ያለውን የ6 አኃዝ ኮድ ተጠቀም።';

  @override
  String get authVerificationPollingStopped =>
      'ስለአንተ ማረጋገጡን አቁመናል። መግባትን ለማጠናቀቅ ከኢሜይልህ ውስጥ ያለውን የ6 አኃዝ ኮድ አስገባ።';

  @override
  String get authWelcomeToDivine => 'እንኳን ወደ Divine በደህና መጣህ!';

  @override
  String get authEmailVerified => 'ኢሜይልህ ተረጋግጧል።';

  @override
  String get authSigningYouIn => 'እርስዎን በማስገባት ላይ';

  @override
  String get authErrorTitle => 'ኧረ ወይኔ.';

  @override
  String get authVerificationFailed => 'ኢሜልህን ማረጋገጥ አልቻልንም።\nእባክዎ እንደገና ይሞክሩ።';

  @override
  String get authStartOver => 'እንደገና ጀምር';

  @override
  String get authEmailVerifiedLogin => 'ኢሜል ተረጋግጧል! ለመቀጠል እባክዎ ይግቡ።';

  @override
  String get authVerificationLinkExpired =>
      'ይህ የማረጋገጫ አገናኝ ከአሁን በኋላ የሚሰራ አይደለም።';

  @override
  String get authVerificationConnectionError =>
      'ኢሜይል ማረጋገጥ አልተቻለም። እባክዎ ግንኙነትዎን ያረጋግጡ እና እንደገና ይሞክሩ።';

  @override
  String get authWaitlistConfirmTitle => 'ገብተሃል!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'ዝመናዎችን በ$email እናጋራለን።\nተጨማሪ የግብዣ ኮዶች ሲገኙ፣ እንልክልሃለን።';
  }

  @override
  String get authOk => 'እሺ';

  @override
  String get authTryAgain => 'እንደገና ይሞክሩ';

  @override
  String get authContactSupport => 'ድጋፍን ያነጋግሩ';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email መክፈት አልተቻለም';
  }

  @override
  String get authAddInviteCode => 'የግብዣ ኮድዎን ያክሉ';

  @override
  String get authInviteCodeLabel => 'የግብዣ ኮድ';

  @override
  String get authEnterYourCode => 'ኮድዎን ያስገቡ';

  @override
  String get authNext => 'ቀጥሎ';

  @override
  String get authJoinWaitlist => 'የተጠባባቂ ዝርዝሩን ይቀላቀሉ';

  @override
  String get authJoinWaitlistTitle => 'የተጠባባቂ ዝርዝሩን ይቀላቀሉ';

  @override
  String get authJoinWaitlistDescription =>
      'ኢሜልዎን ያጋሩ እና መዳረሻ ሲከፈት ማሻሻያዎችን እንልካለን።';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'የDivine መነሳሳት ላክልኝ';

  @override
  String get authInviteAccessHelp => 'የመዳረሻ እገዛን ጋብዝ';

  @override
  String get authGeneratingConnection => 'ግንኙነት በማመንጨት ላይ...';

  @override
  String get authConnectedAuthenticating => 'ተገናኝቷል! በማረጋገጥ ላይ...';

  @override
  String get authConnectionTimedOut => 'ግንኙነቱ ጊዜው አልፎበታል።';

  @override
  String get authApproveConnection =>
      'በፈራሚ መተግበሪያዎ ውስጥ ያለውን ግንኙነት ማጽደቁን ያረጋግጡ።';

  @override
  String get authConnectionCancelled => 'ግንኙነት ተሰርዟል።';

  @override
  String get authConnectionCancelledMessage => 'ግንኙነቱ ተሰርዟል።';

  @override
  String get authConnectionFailed => 'ግንኙነት አልተሳካም።';

  @override
  String get authUnknownError => 'ያልታወቀ ስህተት ተከስቷል።';

  @override
  String get authNostrConnectStartFailed =>
      'ፈራሚውን ማግኘት አልተቻለም። ግንኙነትዎን ያረጋግጡ እና እንደገና ይሞክሩ።';

  @override
  String get authNostrConnectInvalidSession =>
      'ይህ የግንኙነት አገናኝ ከአሁን በኋላ የሚሰራ አይደለም። አዲስ ይጀምሩ።';

  @override
  String get authNostrConnectSetupFailed =>
      'ጥቂት ቀርቷል — መግባትዎን ማጠናቀቅ አልቻልንም። እንደገና ይሞክሩ።';

  @override
  String get authUrlCopied => 'URL ወደ ቅንጥብ ሰሌዳ ተቀድቷል።';

  @override
  String get authConnectToDivine => 'ከDivine ጋር ተገናኝ';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL ለጥፍ';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'ልክ ያልሆነ Bunker URL። በ bunker:// መጀመር አለበት';

  @override
  String get authScanSignerApp => 'ከእርስዎ ጋር ይቃኙ\nለማገናኘት ፈራሚ መተግበሪያ።';

  @override
  String authWaitingForConnection(int seconds) {
    return 'ግንኙነትን በመጠበቅ ላይ... $secondsዎች';
  }

  @override
  String get authCopyUrl => 'ቅዳ URL';

  @override
  String get authShare => 'አጋራ';

  @override
  String get authAddBunker => 'ማሰሪያ ጨምር';

  @override
  String get authCompatibleSignerApps => 'ተኳኋኝ Signer መተግበሪያዎች';

  @override
  String get authFailedToConnect => 'መገናኘት አልተሳካም።';

  @override
  String get authResetPasswordTitle => 'የይለፍ ቃል ዳግም አስጀምር';

  @override
  String get authResetPasswordSubtitle =>
      'እባክዎ አዲሱን የይለፍ ቃልዎን ያስገቡ። ርዝመቱ ቢያንስ 8 ቁምፊዎች መሆን አለበት።';

  @override
  String get authNewPasswordLabel => 'አዲስ የይለፍ ቃል';

  @override
  String get authConfirmNewPasswordLabel => 'አዲሱን የይለፍ ቃል አረጋግጥ';

  @override
  String get authPasswordTooShort => 'የይለፍ ቃል ቢያንስ 8 ቁምፊዎች መሆን አለበት።';

  @override
  String get authPasswordResetSuccess => 'የይለፍ ቃል ዳግም ማስጀመር ተሳክቷል። እባክዎ ይግቡ።';

  @override
  String get authPasswordResetFailed => 'የይለፍ ቃል ዳግም ማስጀመር አልተሳካም።';

  @override
  String get authUnexpectedError => 'ያልተጠበቀ ስህተት ተከስቷል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authUpdatePassword => 'የይለፍ ቃል አዘምን';

  @override
  String get authSecureAccountTitle => 'ደህንነቱ የተጠበቀ መለያ';

  @override
  String get authUnableToAccessKeys => 'ቁልፎችዎን መድረስ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authRegistrationFailed => 'ምዝገባ አልተሳካም።';

  @override
  String get authRegistrationComplete => 'ምዝገባው ተጠናቅቋል። እባክህ ኢሜልህን አረጋግጥ።';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'ዳግም ማስጀመር ኢሜይል መላክ አልተሳካም።';

  @override
  String get authSending => 'በመላክ ላይ...';

  @override
  String get authSignInButton => 'ይግቡ';

  @override
  String get authVerificationErrorTimeout =>
      'የማረጋገጫ ጊዜ አልቋል። እባክዎ እንደገና ለመመዝገብ ይሞክሩ።';

  @override
  String get authVerificationErrorMissingCode => 'ማረጋገጥ አልተሳካም - የፈቀዳ ኮድ ጠፍቷል።';

  @override
  String get authVerificationErrorPollFailed =>
      'ማረጋገጥ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authVerificationErrorNetworkExchange =>
      'በመለያ መግቢያ ጊዜ የአውታረ መረብ ስህተት። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authVerificationErrorOAuthExchange =>
      'ማረጋገጥ አልተሳካም። እባክዎ እንደገና ለመመዝገብ ይሞክሩ።';

  @override
  String get authVerificationErrorSignInFailed =>
      'መግባት አልተሳካም። እባክህ ራስህ ለመግባት ሞክር።';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'ይህ ኢሜይል አስቀድሞ ተመዝግቧል። በምትኩ ግባ።';

  @override
  String get authVerificationErrorPinInvalid =>
      'ያ ኮድ አልተዛመደም። ደግመው ያረጋግጡት እና እንደገና ይሞክሩ።';

  @override
  String get authVerificationErrorPinExpired =>
      'ያ ኮድ ጊዜው አልፎበታል። አዲስ ለማግኘት እንደገና ላክ የሚለውን ይንኩ።';

  @override
  String get authVerificationErrorPinLocked =>
      'በጣም ብዙ ሙከራዎች። አዲስ ኮድ ለማግኘት እንደገና ላክ የሚለውን ይንኩ።';

  @override
  String get authVerificationErrorPinFailed =>
      'ያን ኮድ ማረጋገጥ አልቻልንም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authVerificationErrorPinUnavailable =>
      'የኮድ ማስገቢያ አሁን አይገኝም። በኢሜይልዎ ውስጥ ያለውን አገናኝ ይንኩ፣ ወይም አዲስ ለማግኘት እንደገና ይላኩ።';

  @override
  String get authInviteCodeErrorMalformed => 'እንደ ABCD-EFGH ያለ የግብዣ ኮድ ያስገቡ።';

  @override
  String get authInviteCodeErrorNotFound => 'ያ የግብዣ ኮድ ትክክል አይመስልም።';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'ያ የግብዣ ኮድ ቀደም ሲል ጥቅም ላይ ውሏል ወይም ተሰርዟል።';

  @override
  String get authInviteGateErrorCreatorFull => 'የዚህ ፈጣሪ ግብዣዎች አልቀዋል';

  @override
  String get authInviteGateErrorUnavailable =>
      'ያ የግብዣ ኮድ አይገኝም። በተጠባባቂ ዝርዝሩ ይመዝገቡ፣ ቦታ ሲኖር ግብዣ እንልክልዎታለን።';

  @override
  String get authInviteGateErrorCheckFailed =>
      'ያንን ኮድ ማረጋገጥ አልቻልንም። እንደገና ይሞክሩ።';

  @override
  String get authInviteGateErrorUnknown =>
      'የሆነ ችግር ተፈጥሯል። የግብዣ ኮድዎን እንደገና ይሞክሩ።';

  @override
  String get authInviteErrorAlreadyUsed =>
      'ያ የግብዣ ኮድ ከአሁን በኋላ አይገኝም። ወደ የግብዣ ኮድዎ ይመለሱ፣ የተጠባባቂ ዝርዝሩን ይቀላቀሉ ወይም ድጋፍ ሰጪን ያግኙ።';

  @override
  String get authInviteErrorInvalid =>
      'ያ የግብዣ ኮድ አሁን መጠቀም አይቻልም። ወደ የግብዣ ኮድዎ ይመለሱ፣ የተጠባባቂ ዝርዝሩን ይቀላቀሉ ወይም ድጋፍ ሰጪን ያግኙ።';

  @override
  String get authInviteErrorTemporary =>
      'ግብዣህን አሁን ማረጋገጥ አልቻልንም። ወደ የግብዣ ኮድዎ ይመለሱ እና እንደገና ይሞክሩ፣ ወይም ድጋፍን ያግኙ።';

  @override
  String get authInviteErrorUnknown =>
      'ግብዣህን ማግበር አልቻልንም። ወደ የግብዣ ኮድዎ ይመለሱ፣ የተጠባባቂ ዝርዝሩን ይቀላቀሉ ወይም ድጋፍ ሰጪን ያግኙ።';

  @override
  String get shareSheetSave => 'አስቀምጥ';

  @override
  String get shareSheetRemoveFromSaved => 'ከዕልባቶች አስወግድ';

  @override
  String get shareSheetSaveToGallery => 'ወደ ማዕከለ-ስዕላት አስቀምጥ';

  @override
  String get shareSheetSaveWithWatermark => 'በውሃ ምልክት አስቀምጥ';

  @override
  String get shareSheetSaveVideo => 'ቪዲዮ አስቀምጥ';

  @override
  String get shareSheetAddToClips => 'ወደ ቅንጥቦች ያክሉ';

  @override
  String get shareSheetNameClipTitle => 'ይህን ክሊፕ ሰይም';

  @override
  String get shareSheetNameClipSubtitle => 'በቤተ-መጻሕፍትዎ ውስጥ የሚያውቁትን ስም ይምረጡ።';

  @override
  String get shareSheetClipTitleLabel => 'የክሊፕ ርዕስ';

  @override
  String get shareSheetSaveClip => 'ክሊፕ አስቀምጥ';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\" ወደ ክሊፖች ተቀምጧል';
  }

  @override
  String get shareSheetUntitledClip => 'ያለ ርዕስ ክሊፕ';

  @override
  String get shareSheetAddToClipsFailed => 'ወደ ቅንጥቦች ማከል አልተቻለም';

  @override
  String get shareSheetAddToList => 'ወደ ዝርዝር ያክሉ';

  @override
  String get shareSheetCopy => 'ቅዳ';

  @override
  String get shareSheetShareVia => 'በ በኩል አጋራ';

  @override
  String get shareSheetEventJson => 'ክስተት JSON';

  @override
  String get shareSheetEventId => 'የክስተት መታወቂያ';

  @override
  String get shareSheetMoreActions => 'ተጨማሪ ድርጊቶች';

  @override
  String get shareSheetCrosspost => 'ተሻግሮ ማተም';

  @override
  String get crosspostSheetTitle => 'ይህን ቪዲዮ ተሻግሮ ማተም';

  @override
  String get crosspostSheetSubtitle =>
      'ወደ የተገናኙ መድረኮችዎ ይላኩት። ማተሙ ጥቂት ደቂቃዎች ሊወስድ ይችላል።';

  @override
  String get crosspostSubmit => 'ተሻግሮ ማተም';

  @override
  String get crosspostStatusQueued => 'ተሰልፏል';

  @override
  String get crosspostStatusUploading => 'በመስቀል ላይ';

  @override
  String get crosspostStatusProcessing => 'በማቀነባበር ላይ';

  @override
  String get crosspostStatusPosted => 'ታትሟል';

  @override
  String get crosspostStatusFailed => 'አልተሳካም';

  @override
  String get crosspostStatusSkipped => 'ተዝሏል';

  @override
  String get crosspostStatusNeedsReauth => 'እንደገና መገናኘት ያስፈልጋል';

  @override
  String get crosspostViewPost => 'ልጥፉን ይመልከቱ';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'መለጠፍን ለመቀጠል $platformን በተሻግሮ ማተም ቅንብሮች እንደገና ይገናኙ።';
  }

  @override
  String get crosspostReconnect => 'እንደገና ይገናኙ';

  @override
  String get crosspostErrorNotOwner => 'የራስዎ ቪዲዮዎች ብቻ ናቸው ተሻግሮ መታተም የሚችሉት።';

  @override
  String get crosspostErrorNotEligible => 'ይህ ቪዲዮ ለተሻግሮ ማተም አይበቃም።';

  @override
  String get crosspostErrorNotConnected => 'ያ መድረክ አልተገናኘም።';

  @override
  String get crosspostErrorUnauthorized => 'መለያዎን እንደገና ይገናኙ፣ ከዚያ እንደገና ይሞክሩ።';

  @override
  String get crosspostErrorNetwork =>
      'ተሻግሮ ማተሚያው ላይ መድረስ አልተቻለም። ከአፍታ በኋላ እንደገና ይሞክሩ።';

  @override
  String get crosspostFailedGeneric => 'ተሻግሮ ማተም አልተሳካም።';

  @override
  String get crosspostStillWorking =>
      'አሁንም በሥራ ላይ ነው። ይህንን መዝጋት ይችላሉ — ማተሙ በጀርባ ይቀጥላል።';

  @override
  String get crosspostDone => 'ተከናውኗል';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'ወደ ካሜራ ጥቅል ተቀምጧል';

  @override
  String get watermarkDownloadShare => 'አጋራ';

  @override
  String get watermarkDownloadDone => 'ተከናውኗል';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'የፎቶዎች መዳረሻ ያስፈልጋል';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'ቪዲዮዎችን ለማስቀመጥ በቅንብሮች ውስጥ የፎቶዎች መዳረሻ ፍቀድ።';

  @override
  String get watermarkDownloadOpenSettings => 'ቅንብሮችን ይክፈቱ';

  @override
  String get watermarkDownloadNotNow => 'አሁን አይደለም';

  @override
  String get watermarkDownloadFailed => 'ማውረድ አልተሳካም።';

  @override
  String get watermarkDownloadDismiss => 'አሰናብት';

  @override
  String get watermarkDownloadStageDownloading => 'ቪዲዮን በማውረድ ላይ';

  @override
  String get watermarkDownloadStageWatermarking => 'የውሃ ምልክት ማከል';

  @override
  String get watermarkDownloadStageSaving => 'ወደ ካሜራ ጥቅል በማስቀመጥ ላይ';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'ቪዲዮውን ከአውታረ መረብ በማምጣት ላይ...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'የDivine የውሃ ምልክትን በመተግበር ላይ...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'በውሃ ምልክት የተደረገበትን ቪዲዮ ወደ ካሜራ ጥቅልዎ በማስቀመጥ ላይ...';

  @override
  String get shareMenuBookmarks => 'ዕልባቶች';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count የሚገኙ ስብስቦችን ይከተሉ';
  }

  @override
  String get peopleListsAddToList => 'ወደ ዝርዝር ያክሉ';

  @override
  String get peopleListsSheetTitle => 'ወደ ዝርዝር ያክሉ';

  @override
  String get peopleListsEmptyTitle => 'እስካሁን ምንም ዝርዝሮች የሉም';

  @override
  String get peopleListsEmptySubtitle => 'ሰዎችን መቧደን ለመጀመር ዝርዝር ይፍጠሩ።';

  @override
  String get peopleListsCreateList => 'ዝርዝር ይፍጠሩ';

  @override
  String get peopleListsNewListTitle => 'አዲስ ዝርዝር';

  @override
  String get peopleListsRouteTitle => 'የሰዎች ዝርዝር';

  @override
  String get peopleListsListNameLabel => 'የዝርዝር ስም';

  @override
  String get peopleListsListNameHint => 'የቅርብ ጓደኞች';

  @override
  String get peopleListsCreateButton => 'ፍጠር';

  @override
  String get peopleListsAddPeopleTitle => 'ሰዎችን ጨምር';

  @override
  String get peopleListsAddPeopleTooltip => 'ሰዎችን ጨምር';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'ሰዎችን ወደ ዝርዝር ያክሉ';

  @override
  String get peopleListsListNotFoundTitle => 'ዝርዝር አልተገኘም።';

  @override
  String get peopleListsListNotFoundSubtitle => 'ዝርዝር አልተገኘም። ተሰርዞ ሊሆን ይችላል።';

  @override
  String get peopleListsListDeletedSubtitle => 'ይህ ዝርዝር ተሰርዞ ሊሆን ይችላል።';

  @override
  String get peopleListsNoPeopleTitle => 'በዚህ ዝርዝር ውስጥ ምንም ሰዎች የሉም';

  @override
  String get peopleListsNoPeopleSubtitle => 'ለመጀመር አንዳንድ ሰዎችን ያክሉ';

  @override
  String get peopleListsNoVideosTitle => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get peopleListsNoVideosSubtitle => 'ከዝርዝር አባላት የመጡ ቪዲዮዎች እዚህ ይታያሉ';

  @override
  String get peopleListsNoVideosAvailable => 'ምንም ቪዲዮዎች የሉም';

  @override
  String get peopleListsFailedToLoadVideos => 'ቪዲዮዎችን መጫን አልተሳካም።';

  @override
  String get peopleListsVideoNotAvailable => 'ቪዲዮ አይገኝም';

  @override
  String get peopleListsBackToGridTooltip => 'ወደ ፍርግርግ ተመለስ';

  @override
  String get peopleListsErrorLoadingVideos => 'ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get peopleListsNoPeopleToAdd => 'ምንም የሚታከሉ ሰዎች የሉም።';

  @override
  String peopleListsAddToListName(String name) {
    return 'ወደ $name ጨምር';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'ሰዎችን ፈልግ';

  @override
  String get peopleListsAddPeopleError => 'ሰዎችን መጫን አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get peopleListsAddPeopleRetry => 'እንደገና ይሞክሩ';

  @override
  String get peopleListsAddButton => 'አክል';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'አክል $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'በ$count ዝርዝሮች ውስጥ',
      one: 'በ$count ዝርዝር ውስጥ',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'ይወገድ $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'ከዚህ ዝርዝር ውስጥ ይወገዳሉ.';

  @override
  String get peopleListsRemove => 'አስወግድ';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name ከዝርዝሩ ተወግዷል';
  }

  @override
  String get peopleListsUndo => 'ቀልብስ';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'መገለጫ ለ$name። ለማስወገድ በረጅሙ ተጫን።';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'ለ$name መገለጫ ይመልከቱ';
  }

  @override
  String get shareMenuEditVideo => 'ቪዲዮ አርትዕ';

  @override
  String get shareMenuDeleteVideo => 'ቪዲዮ ሰርዝ';

  @override
  String shareMenuVideoCount(int count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'ይሄ ይህን ቪዲዮ ከDivine እስከመጨረሻው ይሰርዘዋል። አሁንም ሌሎች ማስተላለፊያዎችን በሚጠቀሙ የሶስተኛ ወገን Nostr ደንበኞች ላይ ሊታይ ይችላል።';

  @override
  String get shareMenuCancel => 'ሰርዝ';

  @override
  String get shareMenuDelete => 'ሰርዝ';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'መሰረዝ ገና ዝግጁ አይደለም። ከአፍታ በኋላ እንደገና ይሞክሩ።';

  @override
  String get shareMenuDeleteFailedNotOwner => 'የእራስዎን ቪዲዮዎች ብቻ መሰረዝ ይችላሉ.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'እንደገና ይግቡ፣ ከዚያ ለመሰረዝ ይሞክሩ።';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'የመሰረዝ ጥያቄውን መፈረም አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'ሪሌው ይህን የመሰረዝ ጥያቄ አልተቀበለውም። ከጥቂት ቆይታ በኋላ እንደገና ሞክር።';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'ሪሌውን ማግኘት አልተቻለም። ግንኙነትህን አረጋግጥና እንደገና ሞክር።';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'ተሰርዟል። ሁሉም ሪሌዎች አላረጋገጡም፣ ስለዚህ በሌሎች መተግበሪያዎች ላይ አሁንም ሊታይ ይችላል።';

  @override
  String get shareMenuDeleteFailedGeneric => 'ይህን ቪዲዮ መሰረዝ አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get shareMenuUpdate => 'አዘምን';

  @override
  String get shareMenuChangeCover => 'ሽፋን ቀይር';

  @override
  String get shareMenuVideoUpdated => 'ቪዲዮው በተሳካ ሁኔታ ተዘምኗል';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count የተባባሪ ግብዣዎች አልተላኩም።',
      one: '$count የተባባሪ ግብዣ አልተላከም።',
    );
    return 'ቪዲዮ ተዘምኗል፣ ግን $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated => 'እንደገና ግባ፣ ከዚያ ደግመህ ሞክር።';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'ይህ ቪዲዮ ሊጫወት የሚችል ምንጭ የለውም፣ ስለዚህ ሊስተካከል አይችልም።';

  @override
  String get videoUpdateErrorCouldNotSign => 'ማዘመኛውን መፈረም አልተቻለም። እንደገና ሞክር።';

  @override
  String get videoUpdateErrorPublishRejected =>
      'ማስተላለፊያው ማዘመኛውን አልተቀበለም። ትንሽ ቆይተህ እንደገና ሞክር።';

  @override
  String get videoUpdateErrorGeneric => 'ይህን ቪዲዮ ማዘመን አልተቻለም። እንደገና ሞክር።';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'ቪዲዮ ይሰረዝ?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'ቪዲዮው እየተወገደ ነው…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'ቪዲዮው ተሰርዟል።';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'ቪዲዮው ተሰርዟል። ከሁሉም ቦታ ለመጥፋት ትንሽ ጊዜ ሊወስድ ይችላል።';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'ቪዲዮው ተሰርዟል፣ ግን ሁሉንም ቅጂዎች ማስወገድ አልቻልንም። ድጋፍን ያነጋግሩ።';

  @override
  String get authSessionExpired => 'ክፍለ ጊዜዎ ጊዜው አልፎበታል። እባክዎ እንደገና ይግቡ።';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'መግባት አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get webAuthNotSupportedSecureMode =>
      'የድር ማረጋገጥ በአስተማማኝ ሁነታ አይደገፍም። እባክዎን ደህንነቱ የተጠበቀ ቁልፍ አስተዳደር ለማግኘት የሞባይል መተግበሪያን ይጠቀሙ።';

  @override
  String get webAuthEnterBunkerUri => 'እባክህ ማስቀመጫ አስገባ URI';

  @override
  String get webAuthConnectTitle => 'ከDivine ጋር ተገናኝ';

  @override
  String get webAuthChooseMethod => 'የመረጡትን Nostr የማረጋገጫ ዘዴ ይምረጡ';

  @override
  String get webAuthBrowserExtension => 'የአሳሽ ቅጥያ';

  @override
  String get webAuthRecommended => 'የሚመከር';

  @override
  String get webAuthNsecBunker => 'nsec ማሰሪያ';

  @override
  String get webAuthConnectRemoteSigner => 'ከርቀት ፈራሚ ጋር ይገናኙ';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'ከቅንጥብ ሰሌዳ ለጥፍ';

  @override
  String get webAuthConnectToBunker => 'ከBunker ጋር ተገናኝ';

  @override
  String get webAuthNewToNostr => 'ለNostr አዲስ?';

  @override
  String get webAuthNostrHelp =>
      'በጣም ቀላሉን ለማግኘት እንደ Alby ወይም nos2x ያለ አሳሽ ቅጥያ ጫን ወይም ደህንነቱ የተጠበቀ የርቀት ፊርማ nsec ተጠቀም።';

  @override
  String get soundsTitle => 'ይሰማል።';

  @override
  String get soundsSearchHint => 'ድምፆችን ፈልግ...';

  @override
  String get soundsSearchResults => 'የፍለጋ ውጤቶች';

  @override
  String get soundsNoSoundsFound => 'ምንም ድምፆች አልተገኙም።';

  @override
  String get soundsNoSoundsFoundDescription => 'የተለየ የፍለጋ ቃል ይሞክሩ';

  @override
  String get soundsSavedToLibrary => 'ወደ ድምፆች ተቀመጠ';

  @override
  String get soundsAlreadySavedToLibrary => 'ቀድሞውኑ በድምፆች ውስጥ';

  @override
  String get soundsSavedLibraryTitle => 'የእኔ ድምፆች';

  @override
  String get soundsSavedEmptyTitle => 'ገና የተቀመጠ ድምፅ የለም';

  @override
  String get soundsSavedEmptyDescription =>
      'ድምፅን እዚህ ለማስቀመጥ በቪዲዮ ላይ ድምፅ ተጠቀም የሚለውን ይንኩ።';

  @override
  String get soundsRemoveSavedSound => 'ድምፁን አስወግድ';

  @override
  String get savedSoundSaveAction => 'አስቀምጥ';

  @override
  String get savedSoundPausePreviewAction => 'ቅድመ ዕይታን አቁም';

  @override
  String get savedSoundResumePreviewAction => 'ቅድመ ዕይታን ቀጥል';

  @override
  String get savedSoundDetailsSheetTitle => 'የድምፅ ዝርዝሮች';

  @override
  String get savedSoundRemoveConfirmTitle => 'ይህን ድምፅ ላስወግድ?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'ከቤተ መጻሕፍትህ ይጠፋል፣ ግን እሱን ከሚጠቀም ማንኛውም ቪዲዮ እንደገና ማስቀመጥ ትችላለህ።';

  @override
  String get soundsRemovedFromLibrary => 'ከድምፆች ተወገደ';

  @override
  String get soundsSaveFailed => 'ያን ድምፅ ማስቀመጥ አልተቻለም። እንደገና ሞክር።';

  @override
  String get soundsRemoveFailed => 'ያን ድምፅ ማስወገድ አልተቻለም። እንደገና ሞክር።';

  @override
  String get soundSyncStatusSyncing => 'ድምፆችዎ በማመሳሰል ላይ…';

  @override
  String get soundSyncStatusSynced => 'ድምፆች ወቅታዊ ናቸው';

  @override
  String get soundSyncStatusFailed => 'ድምፆችዎን ማመሳሰል አልተቻለም። እንደገና እንሞክራለን።';

  @override
  String get soundSyncStatusLocked =>
      'በዚህ መሣሪያ ላይ የተመሳሰለ ቤተ-መጻሕፍትዎን መክፈት አልተቻለም።';

  @override
  String get profileTitle => 'መገለጫ';

  @override
  String get profileMoreOptions => 'ተጨማሪ አማራጮች';

  @override
  String profileBlockedUser(String name) {
    return 'ታግዷል $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'ታግዷል $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'ያልተከተለ $name';
  }

  @override
  String get profileFeedError =>
      'አገልጋዩ ጋር መድረስ አልተቻለም። ግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get profileFeedLoadMoreError =>
      'ተጨማሪ ቪዲዮዎችን መጫን አልተቻለም። ለማደስ ወደታች ሳብ።';

  @override
  String get notificationsTabAll => 'ሁሉም';

  @override
  String get notificationsTabLikes => 'መውደዶች';

  @override
  String get notificationsTabComments => 'አስተያየቶች';

  @override
  String get notificationsTabFollows => 'ይከተላል';

  @override
  String get notificationsTabReposts => 'ድጋሚ ልጥፎች';

  @override
  String get notificationsFailedToLoad => 'ማሳወቂያዎችን መጫን አልተሳካም።';

  @override
  String get notificationsRetry => 'እንደገና ይሞክሩ';

  @override
  String get notificationsRefreshError => 'ማደስ አልተቻለም — ያለዎትን እያሳየ ነው';

  @override
  String get notificationsUnreadPrefix => 'ያልተነበበ ማስታወቂያ';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ያልተነበቡ ማሳወቂያዎች',
      one: '$count ያልተነበበ ማሳወቂያ',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'የ$displayName መገለጫ ይመልከቱ';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'መገለጫዎችን ይመልከቱ';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'የ$title ቪዲዮ ድንክዬ';
  }

  @override
  String get notificationsVideoThumbnail => 'የቪዲዮ ድንክዬ';

  @override
  String get notificationsInviteSingular => 'ከጓደኛዎ ጋር ለመጋራት 1 ግብዣ አለዎት!';

  @override
  String notificationsInvitePlural(int count) {
    return 'ከጓደኞችዎ ጋር ለመጋራት $count ግብዣዎች አሉዎት!';
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
  String get notificationsVideoUnavailable => 'ቪዲዮ አይገኝም';

  @override
  String get feedFailedToLoadVideos => 'ቪዲዮዎችን መጫን አልተሳካም።';

  @override
  String get feedRetry => 'እንደገና ይሞክሩ';

  @override
  String get feedNoFollowedUsers =>
      'ምንም የተከተሉት ተጠቃሚዎች የሉም።\nቪዲዮዎቻቸውን እዚህ ለማየት አንድ ሰው ይከተሉ።';

  @override
  String get feedModeForYou => 'ለእርስዎ';

  @override
  String get feedModeNew => 'አዲስ';

  @override
  String get feedModeFollowing => 'እየተከተሉ';

  @override
  String get feedModeClassics => 'ክላሲኮች';

  @override
  String feedModeSemanticLabel(String label) {
    return 'የፊድ ሁነታ: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'የቪድዮ ፈጣሪ: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'የፈጣሪ ፎቶ';

  @override
  String get feedForYouEmpty =>
      'የእርስዎ ለአንተ ምግብ ባዶ ነው።\nቪዲዮዎችን ያስሱ እና ለመቅረጽ ፈጣሪዎችን ይከተሉ።';

  @override
  String get feedFollowingEmpty =>
      'እስካሁን ከምትከተላቸው ሰዎች ምንም ቪዲዮዎች የሉም።\nየሚወዷቸውን ፈጣሪዎች ያግኙ እና ይከተሉዋቸው።';

  @override
  String get feedLatestEmpty => 'እስካሁን ምንም አዲስ ቪዲዮዎች የሉም።\nበቅርቡ ተመልሰው ይመልከቱ።';

  @override
  String get feedClassicEmpty => 'እስካሁን ምንም ክላሲኮች የሉም።\nበቅርቡ ተመልሰው ይመልከቱ።';

  @override
  String get feedExploreVideos => 'ቪዲዮዎችን ያስሱ';

  @override
  String get feedLoadingMore => 'ተጨማሪ ቪዲዮዎችን በመጫን ላይ…';

  @override
  String get feedRefreshed => 'ፊድ ታድሷል';

  @override
  String get uploadUploadingVideo => 'ቪዲዮ በመስቀል ላይ';

  @override
  String get postPublishConfirmationTitle => 'ወደ መገለጫዎ ታትሟል';

  @override
  String get postPublishConfirmationView => 'ይመልከቱ';

  @override
  String get postPublishConfirmationShare => 'አጋራ';

  @override
  String get postPublishConfirmationThumbnailLabel => 'አሁን ያሳተሙት ቪዲዮ ድንክዬ';

  @override
  String get userSearchNoResults => 'ምንም ተጠቃሚዎች አልተገኙም።';

  @override
  String get userPickerFilterByNameHint => 'በስም አጣራ...';

  @override
  String get userPickerSearchByNameHint => 'በስም ፈልግ...';

  @override
  String get userPickerClearSearchSemantics => 'ፍለጋን አጽዳ';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name አስቀድሞ ታክሏል።';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name ምረጥ';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Remove $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'የእርስዎ ሠራተኞች እዚያ አሉ።';

  @override
  String get userPickerEmptyFollowListBody =>
      'የሚወዷቸውን ሰዎች ይከተሉ። ተመልሰው ሲከተሉ፣ መተባበር ይችላሉ።';

  @override
  String get userPickerGoBack => 'ተመለስ';

  @override
  String get userPickerTypeNameToSearch => 'ለመፈለግ ስም ይተይቡ';

  @override
  String get userPickerUnavailable => 'የተጠቃሚ ፍለጋ አይገኝም። እባክዎ ቆይተው እንደገና ይሞክሩ።';

  @override
  String get userPickerSearchFailedTryAgain => 'ፍለጋ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get forgotPasswordTitle => 'የይለፍ ቃል ዳግም አስጀምር';

  @override
  String get forgotPasswordDescription =>
      'የኢሜል አድራሻዎን ያስገቡ እና የይለፍ ቃልዎን እንደገና የሚያስጀምሩበት አገናኝ እንልክልዎታለን።';

  @override
  String get forgotPasswordEmailLabel => 'ኢሜል አድራሻ';

  @override
  String get forgotPasswordCancel => 'ሰርዝ';

  @override
  String get forgotPasswordSendLink => 'የኢሜል ዳግም ማስጀመሪያ አገናኝ';

  @override
  String get ageVerificationContentWarning => 'የይዘት ማስጠንቀቂያ';

  @override
  String get ageVerificationTitle => 'የዕድሜ ማረጋገጫ';

  @override
  String get ageVerificationAdultDescription =>
      'ይህ ይዘት የጎልማሳ ቁሳቁስ ሊይዝ እንደሚችል ተጠቁሟል። እሱን ለማየት 18 ወይም ከዚያ በላይ መሆን አለቦት።';

  @override
  String get ageVerificationCreationDescription =>
      'ካሜራውን ለመጠቀም እና ይዘት ለመፍጠር ዕድሜዎ ቢያንስ 16 ዓመት መሆን አለበት።';

  @override
  String get ageVerificationAdultQuestion => 'ዕድሜዎ 18 ዓመት ወይም ከዚያ በላይ ነው?';

  @override
  String get ageVerificationCreationQuestion => 'ዕድሜዎ 16 ወይም ከዚያ በላይ ነው?';

  @override
  String get ageVerificationNo => 'አይ';

  @override
  String get ageVerificationYes => 'አዎ';

  @override
  String get navHome => 'ቤት';

  @override
  String get navExplore => 'ያስሱ';

  @override
  String get navInbox => 'የገቢ መልእክት ሳጥን';

  @override
  String get navProfile => 'መገለጫ';

  @override
  String get navMyProfile => 'የእኔ መገለጫ';

  @override
  String get navNotifications => 'ማሳወቂያዎች';

  @override
  String get navOpenCamera => 'ካሜራ ክፈት';

  @override
  String get navExploreClassics => 'ክላሲኮች';

  @override
  String get navExploreNewVideos => 'አዳዲስ ቪዲዮዎች';

  @override
  String get navExploreTrending => 'በመታየት ላይ ያለ';

  @override
  String get navExploreForYou => 'ለእርስዎ';

  @override
  String get navExploreLists => 'ዝርዝሮች';

  @override
  String get routeErrorTitle => 'ስህተት';

  @override
  String get routeInvalidHashtag => 'ልክ ያልሆነ ሃሽታግ';

  @override
  String get routeInvalidConversationId => 'ልክ ያልሆነ የውይይት መታወቂያ';

  @override
  String get routeInvalidRequestId => 'ልክ ያልሆነ የጥያቄ መታወቂያ';

  @override
  String get routeInvalidListId => 'ልክ ያልሆነ ዝርዝር መታወቂያ';

  @override
  String get routeInvalidUserId => 'የተሳሳተ የተጠቃሚ መታወቂያ';

  @override
  String get routeInvalidVideoId => 'ልክ ያልሆነ የቪዲዮ መታወቂያ';

  @override
  String get routeInvalidSoundId => 'ልክ ያልሆነ የድምጽ መታወቂያ';

  @override
  String get routeInvalidCategory => 'ልክ ያልሆነ ምድብ';

  @override
  String get routeNoVideosToDisplay => 'ምንም የሚታዩ ቪዲዮዎች የሉም';

  @override
  String get routeGoHome => 'ወደ ቤት ሂድ';

  @override
  String get routeInvalidProfileId => 'ልክ ያልሆነ የመገለጫ መታወቂያ';

  @override
  String get routeUnknownPath => 'ያ ገጽ በመተግበሪያው ውስጥ የለም።';

  @override
  String get routeDefaultListName => 'ዝርዝር';

  @override
  String get supportTitle => 'የድጋፍ ማዕከል';

  @override
  String get supportContactSupport => 'ድጋፍን ያነጋግሩ';

  @override
  String get supportContactSupportSubtitle => 'ውይይት ይጀምሩ ወይም ያለፉ መልዕክቶችን ይመልከቱ';

  @override
  String get supportReportBug => 'ሳንካ ሪፖርት አድርግ';

  @override
  String get supportReportBugSubtitle => 'ከመተግበሪያው ጋር ቴክኒካዊ ጉዳዮች';

  @override
  String get supportRequestFeature => 'ባህሪ ይጠይቁ';

  @override
  String get supportRequestFeatureSubtitle => 'ማሻሻያ ወይም አዲስ ባህሪን ይጠቁሙ';

  @override
  String get supportSaveLogs => 'ምዝግብ ማስታወሻዎችን ያስቀምጡ';

  @override
  String get supportSaveLogsSubtitle => 'በእጅ ለመላክ የምዝግብ ማስታወሻዎችን ወደ ፋይል ይላኩ።';

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
  String get supportFaq => 'የሚጠየቁ ጥያቄዎች';

  @override
  String get supportFaqSubtitle => 'የተለመዱ ጥያቄዎች እና መልሶች';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'ወላጆችና ታዳጊዎች በመስመር ላይ ጤናማ ልማዶችን እንዲገነቡ መርዳት';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'መለያዎችን በዕድሜ መሠረት እንዴት እንደምናስተዳድር';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => 'ስለ ማረጋገጫ እና ትክክለኛነት ይወቁ';

  @override
  String get supportLoginRequired => 'ድጋፍን ለማግኘት ይግቡ';

  @override
  String get supportExportingLogs => 'ምዝግብ ማስታወሻዎችን በመላክ ላይ...';

  @override
  String get supportExportLogsFailed => 'ምዝግብ ማስታወሻዎችን ወደ ውጭ መላክ አልተሳካም።';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'ምዝግቦች ተቀምጠዋል በ $path';
  }

  @override
  String get supportRevealLogsAction => 'በአቃፊ ውስጥ አሳይ';

  @override
  String get supportChatNotAvailable => 'የድጋፍ ውይይት አይገኝም';

  @override
  String get supportCouldNotOpenMessages => 'የድጋፍ መልዕክቶችን መክፈት አልተቻለም';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName መክፈት አልተቻለም';
  }

  @override
  String get reportWhyReporting => 'ይህን ይዘት ለምን ሪፖርት ያደርጋሉ?';

  @override
  String get reportPolicyNotice =>
      'Divine ይዘቱን በማስወገድ እና አጸያፊ ይዘቱን ያቀረበውን ተጠቃሚ በማስወጣት የይዘት ሪፖርቶችን በ24 ሰዓታት ውስጥ ይሰራል።';

  @override
  String get reportBlockUser => 'ይህን ተጠቃሚ አግድ';

  @override
  String get reportCancel => 'ሰርዝ';

  @override
  String get reportSubmit => 'ሪፖርት አድርግ';

  @override
  String get reportSelectReason => 'እባክዎ ይህን ይዘት ሪፖርት ለማድረግ ምክንያት ይምረጡ';

  @override
  String get reportOtherRequiresDetails => '«ሌላ» ስትመርጥ እባክህ ችግሩን ግለጽ';

  @override
  String get reportDetailsRequired => 'እባክህ ችግሩን ግለጽ';

  @override
  String get reportDetailsTextOnly =>
      'ጽሑፍ ብቻ — ፎቶዎችን እና GIF-ዎችን እዚህ ማያያዝ አይቻልም።';

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
  String get reportReasonSpam => 'አይፈለጌ መልእክት ወይም የማይፈለግ ይዘት';

  @override
  String get reportReasonSpamSubtitle => 'ያልተፈለገ ወይም ተደጋጋሚ ይዘት';

  @override
  String get reportReasonHarassment => 'ማስፈራራት፣ ማስፈራራት ወይም ማስፈራራት';

  @override
  String get reportReasonHarassmentSubtitle => 'ጎጂ እና ያልተፈለጉ መልሶች ወይም ጥቅሶች';

  @override
  String get reportReasonViolence => 'የጥቃት ወይም ጽንፈኛ ይዘት';

  @override
  String get reportReasonViolenceSubtitle => 'ጥቃት፣ ጽንፈኛ፣ ወይም ጎጂ ይዘት';

  @override
  String get reportReasonSexualContent => 'ወሲባዊ ወይም የአዋቂ ይዘት';

  @override
  String get reportReasonSexualContentSubtitle => 'እርቃንነት፣ ወሲባዊ፣ ወይም ግልጽ ይዘት';

  @override
  String get reportReasonCopyright => 'የቅጂ መብት ጥሰት';

  @override
  String get reportReasonCopyrightSubtitle => 'የአዕምሯዊ ንብረትን ሳይፈቀድ መጠቀም';

  @override
  String get reportReasonFalseInfo => 'የውሸት መረጃ';

  @override
  String get reportReasonFalseInfoSubtitle => 'አሳሳች ወይም የውሸት ማስታወቂያዎች';

  @override
  String get reportReasonChildSafety => 'የልጆች ደህንነት ጥሰት';

  @override
  String get reportReasonChildSafetySubtitle => 'ስለ ታዳጊዎች ደህንነት አጠቃላይ ስጋቶች';

  @override
  String get reportReasonCsam => 'የህጻናት ወሲባዊ ጥቃት';

  @override
  String get reportReasonCsamSubtitle =>
      'ለአካለ መጠን ያልደረሱ ልጆች ላይ የሚፈጸም ወሲባዊ ጥቃትን የሚያሳይ ይዘት';

  @override
  String get reportReasonUnderageUser => 'ተጠቃሚው ከ16 ዓመት በታች ይመስላል';

  @override
  String get reportReasonUnderageUserSubtitle => 'የመለያው ባለቤት ዕድሜው ያልደረሰ ይመስላል';

  @override
  String get reportReasonAiGenerated => 'በAI የተፈጠረ ይዘት';

  @override
  String get reportReasonAiGeneratedSubtitle => 'AI የመነጨ ሊሆን የሚችል ይዘት';

  @override
  String get reportReasonOther => 'ሌላ የፖሊሲ ጥሰት';

  @override
  String get reportReasonOtherSubtitle => 'ከላይ ያልተዘረዘሩ ጥሰቶች';

  @override
  String get reportFailed => 'ይዘትን ሪፖርት ማድረግ አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get reportNotSent => 'ሪፖርትዎን መላክ አልተቻለም። ግንኙነትዎን ይፈትሹ እና እንደገና ይሞክሩ።';

  @override
  String get reportReceivedTitle => 'ሪፖርት ደርሷል';

  @override
  String get reportReceivedThankYou => 'Divine ደህንነትን ለመጠበቅ ስለረዱዎት እናመሰግናለን።';

  @override
  String get reportReceivedReviewNotice =>
      'ቡድናችን የእርስዎን ሪፖርት ተመልክቶ ተገቢውን እርምጃ ይወስዳል። ዝማኔዎችን በቀጥታ መልእክት ሊቀበሉ ይችላሉ።';

  @override
  String get reportModerationDmDelayed =>
      'አሁን የልከኝነት ቡድኑን በቀጥታ ማግኘት አልቻልንም፣ ነገር ግን ሪፖርትዎ ተቀብሏል እና ይገመገማል።';

  @override
  String get reportContactModeration => 'የልከኝነት ቡድኑን መልእክት ላክ';

  @override
  String get reportLearnMoreAt => 'የበለጠ ይወቁ በ';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'ገጠመ';

  @override
  String get listAddToList => 'ወደ ዝርዝር ያክሉ';

  @override
  String listVideoCount(int count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ሰዎች',
      one: '$count ሰው',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'በ';

  @override
  String get listNewList => 'አዲስ ዝርዝር';

  @override
  String get listDone => 'ተከናውኗል';

  @override
  String get listErrorLoading => 'ዝርዝሮችን መጫን ላይ ስህተት';

  @override
  String listRemovedFrom(String name) {
    return 'ከ$name ተወግዷል';
  }

  @override
  String listAddedTo(String name) {
    return 'ወደ $name ታክሏል።';
  }

  @override
  String get listCreateNewList => 'አዲስ ዝርዝር ይፍጠሩ';

  @override
  String get listNewPeopleList => 'አዲስ ሰዎች ዝርዝር';

  @override
  String get listCollaboratorsNone => 'ምንም';

  @override
  String get listAddCollaboratorTitle => 'ተባባሪ ጨምር';

  @override
  String get listCollaboratorSearchHint => 'Divine ፈልግ...';

  @override
  String get listNameLabel => 'የዝርዝር ስም';

  @override
  String get listDescriptionLabel => 'መግለጫ (አማራጭ)';

  @override
  String get listPublicList => 'የህዝብ ዝርዝር';

  @override
  String get listPublicListSubtitle => 'ሌሎች ሊከተሉት እና ይህንን ዝርዝር ማየት ይችላሉ።';

  @override
  String get listPrivateListSubtitle =>
      'ቪዲዮዎቹ የግል ሆነው ይቆያሉ። ስም፣ መግለጫ፣ መለያዎች እና ሽፋን ይታያሉ።';

  @override
  String get listVisibilityPublic => 'ይፋዊ';

  @override
  String get listVisibilityPrivate => 'የግል';

  @override
  String get profileListsEmpty =>
      'እስካሁን ዝርዝር የለም። አብረው እንዲቆዩ የሚፈልጓቸውን ሉፖች የሚያሰባስብ ዝርዝር ይፍጠሩ።';

  @override
  String get listEditTitle => 'ዝርዝር አርትዕ';

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
  String get listShareAction => 'ዝርዝር አጋራ';

  @override
  String get listShareFailed => 'ይህን ዝርዝር ማጋራት አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get listSave => 'አስቀምጥ';

  @override
  String get listContinue => 'ቀጥል';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => 'ይህን ዝርዝር ማዘመን አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get listMakePrivateTitle => 'ይህ ዝርዝር የግል ይሁን?';

  @override
  String get listMakePrivateWarning =>
      'ቪዲዮዎቹ ይመሰጠራሉ፤ ስለዚህ እርስዎ ብቻ ማየት ይችላሉ። ስም፣ መግለጫ፣ መለያዎች እና ሽፋን ይታያሉ፣ እስካሁን የተጋሩ ቅጂዎችም ሊቀሩ ይችላሉ።';

  @override
  String get listMakePublicTitle => 'ይህ ዝርዝር ይፋዊ ይሁን?';

  @override
  String get listMakePublicWarning =>
      'አገናኙ ያለው ማንኛውም ሰው ይህን ዝርዝርና ቪዲዮዎቹን ማየት ይችላል።';

  @override
  String listShareText(String name, String url) {
    return '$nameን በDivine ላይ ይመልከቱ፦ $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name በDivine ላይ';
  }

  @override
  String get listCancel => 'ሰርዝ';

  @override
  String get listCreate => 'ፍጠር';

  @override
  String get listCreateFailed => 'ዝርዝር መፍጠር አልተሳካም።';

  @override
  String get keyManagementTitle => 'Nostr ቁልፎች';

  @override
  String get keyManagementWhatAreKeys => 'Nostr ቁልፎች ምንድን ናቸው?';

  @override
  String get keyManagementExplanation =>
      'የNostr ማንነትህ የክሪፕቶግራፊ ቁልፍ ጥንድ ነው፡\n\n• የህዝብ ቁልፍህ (npub) እንደ ተጠቃሚ ስምህ ነው - በነጻ አጋራው\n• የግል ቁልፍህ (nsec) እንደ ይለፍ ቃልህ ነው - በሚስጥር ያዘው!\n\nnsecህ በማንኛውም Nostr መተግበሪያ ላይ መለያህን እንድትጠቀም ያስችልሃል።';

  @override
  String get keyManagementImportTitle => 'ነባር ቁልፍ አስመጣ';

  @override
  String get keyManagementImportSubtitle =>
      'Nostr መለያ አለህ? እዚህ ለመጠቀም የግል ቁልፍህን (nsec) ለጥፍ።';

  @override
  String get keyManagementImportButton => 'የማስመጣት ቁልፍ';

  @override
  String get keyManagementImportWarning => 'ይህ የአሁኑን ቁልፍ ይተካዋል!';

  @override
  String get keyManagementBackupTitle => 'የእርስዎን ቁልፍ ምትኬ ያስቀምጡ';

  @override
  String get keyManagementBackupSubtitle =>
      'መለያዎን በሌሎች Nostr መተግበሪያዎች ለመጠቀም የግል ቁልፍዎን (nsec) ያስቀምጡ።';

  @override
  String get keyManagementCopyNsec => 'የእኔን የግል ቁልፍ ቅዳ (nsec)';

  @override
  String get keyManagementNeverShare => 'የእርስዎን nsec ለማንም አያካፍሉ!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'ቁልፍዎ በዚህ መሣሪያ ላይ አይደለም፤ በDivine የመግቢያ አገልግሎት ውስጥ ተቀምጧል። የይለፍ ቃልዎን ያረጋግጡ፤ እኛም እናመጣዋለን።';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'ቁልፍዎ በDivine የመግቢያ አገልግሎት ተቀምጧል። የመለያዎን የይለፍ ቃል ያስገቡ፤ እኛም እናመጣዋለን።';

  @override
  String get keyManagementKeycastCopyKey => 'ቁልፍ ቅዳ';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'መሣሪያዎ ቅጂውን አግዷል፣ ስለዚህ ቁልፍዎ ወደ ቅንጥብ ሰሌዳ አልደረሰም።';

  @override
  String get keyManagementKeycastWrongPassword => 'የይለፍ ቃሉ አይዛመድም። እንደገና ይሞክሩ።';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'በጣም ብዙ ሙከራዎች። ይህን ዝጋና ከመጀመሪያው ጀምር።';

  @override
  String get keyManagementKeycastRateLimited =>
      'በጣም ብዙ የቁልፍ ጥያቄዎች። ጥቂት ደቂቃዎች ጠብቀው እንደገና ይሞክሩ።';

  @override
  String get keyManagementKeycastSignInAgain =>
      'ክፍለ ጊዜዎ አልቋል። ቁልፍዎን ለመቅዳት እንደገና ይግቡ።';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'ቁልፍዎን ከመቅዳት በፊት የኢሜይል አድራሻዎን ያረጋግጡ።';

  @override
  String get keyManagementKeycastDenied =>
      'የዚህ መለያ ቁልፎች በDivine ይተዳደራሉ፤ ስለዚህ በዚህ ቦታ መቅዳት አይቻልም።';

  @override
  String get keyManagementKeycastNoKey => 'ለዚህ መለያ የተመዘገበ ቁልፍ የለም።';

  @override
  String get keyManagementKeycastGenericFailure =>
      'የመግቢያ አገልግሎቱን ማግኘት አልተቻለም። እንደገና ሞክር።';

  @override
  String get keyManagementRestrictedTitle => 'ቁልፎችህ በDivine ይተዳደራሉ';

  @override
  String get keyManagementRestrictedBody =>
      'መለያህን ደኅንነቱ የተጠበቀ ለማድረግ፣ የቁልፍ ምትኬና ሌላ ቁልፍ ማስመጣት እዚህ አይገኙም።';

  @override
  String get keyManagementPasteKey => 'እባክህ የግል ቁልፍህን ለጥፍ';

  @override
  String get keyManagementInvalidFormat =>
      'ልክ ያልሆነ የቁልፍ ቅርጸት። በ\"nsec1\" መጀመር አለበት';

  @override
  String get keyManagementConfirmImportTitle => 'ይህ ቁልፍ ይምጣ?';

  @override
  String get keyManagementConfirmImportBody =>
      'ይህ አሁን ያለዎትን ማንነት ከውጪ በመጣው ይተካዋል።\n\nመጀመሪያ ምትኬ ካላስቀመጥከው በስተቀር የአሁኑ ቁልፍህ ይጠፋል።';

  @override
  String get keyManagementImportConfirm => 'አስመጣ';

  @override
  String get keyManagementImportSuccess => 'ቁልፍ በተሳካ ሁኔታ ገብቷል!';

  @override
  String get keyManagementImportFailed => 'ቁልፍ ማስመጣት አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get keyManagementExportSuccess =>
      'የግል ቁልፍ ወደ ቅንጥብ ሰሌዳ ተቀድቷል!\n\nደህንነቱ በተጠበቀ ቦታ ያስቀምጡት።';

  @override
  String get keyManagementExportFailed =>
      'ቁልፉን ወደ ውጭ መላክ አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get keyManagementYourPublicKeyLabel => 'የህዝብ ቁልፍህ (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'የህዝብ ቁልፍ ቅዳ';

  @override
  String get keyManagementPublicKeyCopied => 'የህዝብ ቁልፍ ተቀድቷል';

  @override
  String get saveOriginalSavedToCameraRoll => 'ወደ ካሜራ ጥቅል ተቀምጧል';

  @override
  String get saveOriginalShare => 'አጋራ';

  @override
  String get saveOriginalDone => 'ተከናውኗል';

  @override
  String get saveOriginalPhotosAccessNeeded => 'የፎቶዎች መዳረሻ ያስፈልጋል';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'ቪዲዮዎችን ለማስቀመጥ በቅንብሮች ውስጥ የፎቶዎች መዳረሻ ፍቀድ።';

  @override
  String get saveOriginalOpenSettings => 'ቅንብሮችን ይክፈቱ';

  @override
  String get saveOriginalNotNow => 'አሁን አይደለም';

  @override
  String get saveOriginalDownloadFailed => 'ማውረድ አልተሳካም።';

  @override
  String get saveOriginalDismiss => 'አሰናብት';

  @override
  String get saveOriginalDownloadingVideo => 'ቪዲዮን በማውረድ ላይ';

  @override
  String get saveOriginalSavingToCameraRoll => 'ወደ ካሜራ ጥቅል በማስቀመጥ ላይ';

  @override
  String get saveOriginalFetchingVideo => 'ቪዲዮውን ከአውታረ መረብ በማምጣት ላይ...';

  @override
  String get saveOriginalSavingVideo => 'የመጀመሪያውን ቪዲዮ ወደ ካሜራ ጥቅልዎ በማስቀመጥ ላይ...';

  @override
  String get soundTitle => 'ድምፅ';

  @override
  String get soundOriginalSound => 'ኦሪጅናል ድምጽ';

  @override
  String get soundVideosUsingThisSound => 'ይህን ድምፅ በመጠቀም ቪዲዮዎች';

  @override
  String get soundSourceVideo => 'ምንጭ ቪዲዮ';

  @override
  String get soundNoVideosYet => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get soundBeFirstToUse => 'ይህን ድምጽ ለመጠቀም የመጀመሪያው ይሁኑ!';

  @override
  String get soundFailedToLoadVideos => 'ቪዲዮዎችን መጫን አልተሳካም።';

  @override
  String get soundRetry => 'እንደገና ይሞክሩ';

  @override
  String get soundVideosUnavailable => 'ቪዲዮዎች አይገኙም።';

  @override
  String get soundCouldNotLoadDetails => 'የቪዲዮ ዝርዝሮችን መጫን አልተቻለም';

  @override
  String get soundPreview => 'ቅድመ እይታ';

  @override
  String get soundStop => 'ተወ';

  @override
  String get soundUseSound => 'ድምጽን ተጠቀም';

  @override
  String get soundUntitled => 'ርዕስ የሌለው ድምፅ';

  @override
  String get soundStopPreview => 'ቅድመ እይታን አቁም';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '$titleን ቀድመው ያጫውቱ';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'የ$title ዝርዝሮችን ይመልከቱ';
  }

  @override
  String get soundNoVideoCount => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get soundOneVideo => '1 ቪዲዮ';

  @override
  String soundVideoCount(int count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String get soundUnableToPreview => 'ድምጽን አስቀድሞ ማየት አልተቻለም - ምንም ኦዲዮ የለም።';

  @override
  String get soundPreviewFailed => 'ቅድመ እይታን ማጫወት አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get soundViewSource => 'ምንጭ ይመልከቱ';

  @override
  String get soundCloseTooltip => 'ገጠመ';

  @override
  String get exploreNotExploreRoute => 'የአሰሳ መንገድ አይደለም።';

  @override
  String get legalTitle => 'ህጋዊ';

  @override
  String get legalTermsOfService => 'የአገልግሎት ውል';

  @override
  String get legalTermsOfServiceSubtitle => 'የአጠቃቀም ደንቦች እና ሁኔታዎች';

  @override
  String get legalPrivacyPolicy => 'የግላዊነት ፖሊሲ';

  @override
  String get legalPrivacyPolicySubtitle => 'የእርስዎን ውሂብ እንዴት እንደምንይዝ';

  @override
  String get legalSafetyStandards => 'የደህንነት ደረጃዎች';

  @override
  String get legalSafetyStandardsSubtitle => 'የማህበረሰብ መመሪያዎች እና ደህንነት';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'የቅጂ መብት እና የማውረድ ፖሊሲ';

  @override
  String get legalOpenSourceLicenses => 'ክፍት ምንጭ ፍቃዶች';

  @override
  String get legalOpenSourceLicensesSubtitle => 'የሶስተኛ ወገን ጥቅል ባህሪያት';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName መክፈት አልተቻለም';
  }

  @override
  String get categoryAction => 'ድርጊት';

  @override
  String get categoryAdventure => 'ጀብዱ';

  @override
  String get categoryAnimals => 'እንስሳት';

  @override
  String get categoryAnimation => 'አኒሜሽን';

  @override
  String get categoryArchitecture => 'አርክቴክቸር';

  @override
  String get categoryArt => 'ስነ ጥበብ';

  @override
  String get categoryAutomotive => 'አውቶሞቲቭ';

  @override
  String get categoryAwardShow => 'የሽልማት ትርዒት';

  @override
  String get categoryAwards => 'ሽልማቶች';

  @override
  String get categoryBaseball => 'ቤዝቦል';

  @override
  String get categoryBasketball => 'የቅርጫት ኳስ';

  @override
  String get categoryBeauty => 'ውበት';

  @override
  String get categoryBeverage => 'መጠጥ';

  @override
  String get categoryCars => 'መኪኖች';

  @override
  String get categoryCelebration => 'አከባበር';

  @override
  String get categoryCelebrities => 'ታዋቂ ሰዎች';

  @override
  String get categoryCelebrity => 'ታዋቂ ሰው';

  @override
  String get categoryCityscape => 'የከተማ ገጽታ';

  @override
  String get categoryComedy => 'አስቂኝ';

  @override
  String get categoryConcert => 'ኮንሰርት';

  @override
  String get categoryCooking => 'ምግብ ማብሰል';

  @override
  String get categoryCostume => 'አልባሳት';

  @override
  String get categoryCrafts => 'የእጅ ሥራዎች';

  @override
  String get categoryCrime => 'ወንጀል';

  @override
  String get categoryCulture => 'ባህል';

  @override
  String get categoryDance => 'ዳንስ';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'ድራማ';

  @override
  String get categoryEducation => 'ትምህርት';

  @override
  String get categoryEmotional => 'ስሜታዊ';

  @override
  String get categoryEmotions => 'ስሜቶች';

  @override
  String get categoryEntertainment => 'መዝናኛ';

  @override
  String get categoryEvent => 'ክስተት';

  @override
  String get categoryFamily => 'ቤተሰብ';

  @override
  String get categoryFans => 'ደጋፊዎች';

  @override
  String get categoryFantasy => 'ምናባዊ';

  @override
  String get categoryFashion => 'ቅጥ';

  @override
  String get categoryFestival => 'በዓል';

  @override
  String get categoryFilm => 'ፊልም';

  @override
  String get categoryFitness => 'የአካል ብቃት';

  @override
  String get categoryFood => 'ምግብ';

  @override
  String get categoryFootball => 'እግር ኳስ';

  @override
  String get categoryFurniture => 'የቤት ዕቃዎች';

  @override
  String get categoryGaming => 'ጨዋታ';

  @override
  String get categoryGolf => 'ጎልፍ';

  @override
  String get categoryGrooming => 'ማበጠር';

  @override
  String get categoryGuitar => 'ጊታር';

  @override
  String get categoryHalloween => 'ሃሎዊን';

  @override
  String get categoryHealth => 'ጤና';

  @override
  String get categoryHockey => 'ሆኪ';

  @override
  String get categoryHoliday => 'በዓል';

  @override
  String get categoryHome => 'ቤት';

  @override
  String get categoryHomeImprovement => 'የቤት መሻሻል';

  @override
  String get categoryHorror => 'አስፈሪ';

  @override
  String get categoryHospital => 'ሆስፒታል';

  @override
  String get categoryHumor => 'ቀልድ';

  @override
  String get categoryInteriorDesign => 'የውስጥ ንድፍ';

  @override
  String get categoryInterview => 'ቃለ መጠይቅ';

  @override
  String get categoryKids => 'ልጆች';

  @override
  String get categoryLifestyle => 'የአኗኗር ዘይቤ';

  @override
  String get categoryMagic => 'አስማት';

  @override
  String get categoryMakeup => 'ሜካፕ';

  @override
  String get categoryMedical => 'ሕክምና';

  @override
  String get categoryMusic => 'ሙዚቃ';

  @override
  String get categoryMystery => 'ምስጢር';

  @override
  String get categoryNature => 'ተፈጥሮ';

  @override
  String get categoryNews => 'ዜና';

  @override
  String get categoryOutdoor => 'ከቤት ውጭ';

  @override
  String get categoryParty => 'ፓርቲ';

  @override
  String get categoryPeople => 'ሰዎች';

  @override
  String get categoryPerformance => 'አፈጻጸም';

  @override
  String get categoryPets => 'የቤት እንስሳት';

  @override
  String get categoryPolitics => 'ፖለቲካ';

  @override
  String get categoryPrank => 'ፕራንክ';

  @override
  String get categoryPranks => 'ፕራንክ';

  @override
  String get categoryRealityShow => 'የእውነታ ትርኢት';

  @override
  String get categoryRelationship => 'ግንኙነት';

  @override
  String get categoryRelationships => 'ግንኙነቶች';

  @override
  String get categoryRomance => 'የፍቅር ጓደኝነት';

  @override
  String get categorySchool => 'ትምህርት ቤት';

  @override
  String get categoryScienceFiction => 'የሳይንስ ልብወለድ';

  @override
  String get categorySelfie => 'የራስ ፎቶ';

  @override
  String get categoryShopping => 'ግዢ';

  @override
  String get categorySkateboarding => 'የስኬትቦርዲንግ';

  @override
  String get categorySkincare => 'የቆዳ እንክብካቤ';

  @override
  String get categorySoccer => 'እግር ኳስ';

  @override
  String get categorySocialGathering => 'ማህበራዊ ስብሰባ';

  @override
  String get categorySocialMedia => 'ማህበራዊ ሚዲያ';

  @override
  String get categorySports => 'ስፖርት';

  @override
  String get categoryTalkShow => 'የውይይት ትዕይንት';

  @override
  String get categoryTech => 'ቴክ';

  @override
  String get categoryTechnology => 'ቴክኖሎጂ';

  @override
  String get categoryTelevision => 'ቴሌቪዥን';

  @override
  String get categoryToys => 'መጫወቻዎች';

  @override
  String get categoryTransportation => 'መጓጓዣ';

  @override
  String get categoryTravel => 'ጉዞ';

  @override
  String get categoryUrban => 'ከተማ';

  @override
  String get categoryViolence => 'ብጥብጥ';

  @override
  String get categoryVlog => 'ቪሎግ';

  @override
  String get categoryVlogging => 'ቭሎግ ማድረግ';

  @override
  String get categoryWrestling => 'ትግል';

  @override
  String get profileSetupUploadStaged => 'ተሰቅሏል — ለመተግበር አስቀምጥን ጠቅ ያድርጉ';

  @override
  String inboxReportedUser(String displayName) {
    return 'ሪፖርት ተደርጓል $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'ታግዷል $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'ታግዷል $displayName';
  }

  @override
  String get inboxRemovedConversation => 'ውይይት ተወግዷል';

  @override
  String get inboxRestorePausedTitle => 'አንዳንድ ውይይቶች ወደነበሩበት መመለስ አላጠናቀቁም';

  @override
  String get conversationRestorePausedTitle => 'ይህ ውይይት ወደነበረበት መመለስ አላጠናቀቀም';

  @override
  String get inboxRestoreRetryAction => 'እንደገና ሞክር';

  @override
  String get inboxRestoringMessages => 'መልዕክቶችዎን ወደነበሩበት በመመለስ ላይ…';

  @override
  String get inboxEmptyTitle => 'እስካሁን ምንም መልዕክቶች የሉም';

  @override
  String get inboxEmptySubtitle => 'ያ + ቁልፍ አይነክሰውም።';

  @override
  String get inboxLoadErrorTitle => 'መልዕክቶቹ አልተጫኑም';

  @override
  String get inboxLoadErrorSubtitle => 'ግንኙነትህን አረጋግጠህ እንደገና ሞክር።';

  @override
  String get inboxFilterAll => 'ሁሉም';

  @override
  String get inboxFilterUnread => 'ያልተነበቡ';

  @override
  String get dmBlockedThreadTitle => 'ይህን መለያ አግደዋል';

  @override
  String get dmBlockedThreadBody =>
      'መልእክቶቹ እዚህ ይቆያሉ፣ ስለዚህ ማንበብ ወይም ቅጽበታዊ ገጽ እይታ ማንሳት ይችላሉ። ለመመለስ እገዳውን ያንሱ።';

  @override
  String get inboxFilterBlocked => 'የታገዱ';

  @override
  String get inboxBlockedEmptyTitle => 'የታገዱ ውይይቶች የሉም';

  @override
  String get inboxBlockedEmptySubtitle => 'የሚያግዷቸው መለያዎች እዚህ ይታያሉ።';

  @override
  String get inboxBlockedNoMessages => 'መልእክቶች የሉም';

  @override
  String get inboxUnreadEmptyTitle => 'ሁሉንም አንብበሃል';

  @override
  String get inboxUnreadEmptySubtitle => 'አሁን ያልተነበበ መልዕክት የለም።';

  @override
  String get inboxSearchHint => 'መልዕክቶችን ፈልግ';

  @override
  String get inboxSupportRowTitle => 'የDivine ቁጥጥር';

  @override
  String get inboxSupportRowSubtitle => 'ሳንካዎች፣ ማጣራት፣ የመለያ ጉዳዮች — እያዳመጥን ነው።';

  @override
  String get inboxSearchEmptyTitle => 'ምንም አልተገኘም';

  @override
  String get inboxSearchEmptySubtitle => 'ሌላ ስም ወይም ቃል ሞክር።';

  @override
  String get inboxActionMute => 'ውይይት ድምጸ-ከል አድርግ';

  @override
  String inboxActionReport(String displayName) {
    return 'ሪፖርት $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'አግድ $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'እገዳን አንሳ $displayName';
  }

  @override
  String get inboxActionRemove => 'ውይይት አስወግድ';

  @override
  String get inboxRemoveConfirmTitle => 'ውይይት ይወገድ?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'ይህ ከ$displayName ጋር ያለህን ውይይት ከመልእክት ሳጥንህ ያስወግዳል። እንደገና መልእክት ከላከልህ አዲስ ውይይት ይጀምራል።';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'ይህ የቡድን ውይይቱን ከመልእክት ሳጥንዎ ያስወግዳል። ማንኛውም ሰው እንደገና ለቡድኑ መልእክት ከላከ አዲስ ውይይት ይጀምራል።';

  @override
  String get inboxRemoveConfirmConfirm => 'አስወግድ';

  @override
  String get inboxConversationMuted => 'ውይይት ድምጸ-ከል ተደርጓል';

  @override
  String get inboxConversationUnmuted => 'ውይይቱ ድምጸ-ከል ተነስቷል።';

  @override
  String get inboxCollabInviteCardTitle => 'የተባባሪ ግብዣ';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'ርዕስ የሌለው ቪዲዮ';

  @override
  String get clickableTextViewVideoLink => 'ቪዲዮውን ይመልከቱ';

  @override
  String get messageExternalLinkDialogTitle => 'ውጫዊ ሊንክ ይክፈቱ?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'ይህ ሊንክ ወደ ውጫዊ ድረ-ገጽ ይሄዳል እና ደህንነቱ አልተረጋገጠም:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'ክፈት';

  @override
  String get inboxCollabInviteCoPostButton => 'አብረህ ለጥፍ';

  @override
  String get inboxCollabInviteNotMineButton => 'የኔ አይደለም';

  @override
  String get inboxCollabInvitePreviewTitle => 'የጋራ ልጥፍ ግብዣ';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'ከ$displayName የጋራ ልጥፍ ግብዣ';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'አብሮ መለጠፍ ይህን ቪዲዮ እንደ ትብብር ወደ የጊዜ መስመርህ ያክለዋል።';

  @override
  String get inboxCollabInviteAcceptedStatus => 'ተቀባይነት አግኝቷል';

  @override
  String get inboxCollabInviteIgnoredStatus => 'ችላ ተብሏል';

  @override
  String get inboxCollabInviteAcceptError => 'መቀበል አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get inboxCollabInviteSentStatus => 'ግብዣ ተልኳል።';

  @override
  String get inboxConversationCollabInvitePreview => 'የተባባሪ ግብዣ';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'በ$title ላይ እንድትተባበር ተጋብዘሃል፦ $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'በቪዲዮ ላይ እንድትተባበር ተጋብዘሃል፦ $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count የተባባሪ ግብዣዎች አልተላኩም።',
      one: '$count የተባባሪ ግብዣ አልተላከም።',
    );
    return 'ቪዲዮ ተለጠፈ፣ ግን $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'ይህ ውይይት ከማን ጋር እንደሆነ ማወቅ አልቻልንም። ከመልእክት ሳጥንህ እንደገና ክፈተው።';

  @override
  String get dmSendBlockedMessage =>
      'መልእክት መላክ የምትችለው ለኦፊሴላዊ የDivine መለያዎች ብቻ ነው';

  @override
  String get dmSendBlockedRetiredMessage =>
      'ይህን ውይይት የሚያነበው የለም። በምትኩ Divine Moderation ላይ መልእክት ይላኩ።';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'ለሁሉም ሰው መሰረዝ አልተቻለም።';

  @override
  String get dmDeleteRefusedDetails => 'አንዳንድ ሰዎች አሁንም ይህን መልእክት ማየት ይችላሉ።';

  @override
  String get dmRetiredThreadClosedTitle => 'ይህ ውይይት ተዘግቷል።';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'ይህ የDivine Moderation ማሳወቂያ ሊወገድ አይችልም።';

  @override
  String get dmRetiredThreadClosedBody =>
      'Divine Moderation ወደ አዲስ መለያ አዛውረናል። ይህን መለያ የሚያነበው የለም።';

  @override
  String get dmRetiredThreadOpenSupport => 'Divine Moderation ላይ መልእክት ይላኩ';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'መልዕክቱ መላክ አልተሳካም';

  @override
  String get dmResendFailedMessage => 'አሁንም መላክ አልተሳካም';

  @override
  String get dmSendFailedSubtitle => 'አሁን እንደገና ላክ ወይም መሞከር አቁም።';

  @override
  String get dmSendFailedRetry => 'እንደገና ይሞክሩ';

  @override
  String get dmSendPartialMessage => 'ተልኳል፣ ግን ወደ ሌሎች መሣሪያዎች አልተመሳሰለም';

  @override
  String get dmConversationLoadError => 'መልዕክቶችን መጫን አልተቻለም';

  @override
  String get dmMessageInputHint => 'አንድ ነገር በል…';

  @override
  String get dmMessageBubbleSentHint => 'የተላከ መልእክት';

  @override
  String get dmMessageBubbleReceivedHint => 'የተቀበለ መልእክት';

  @override
  String get dmMessageBubbleLongPressHint => 'የመልእክት እርምጃዎች';

  @override
  String get dmMessageBubbleFailedTapHint => 'መልእክቱን እንደገና ይላኩ ወይም ይሰርዙ';

  @override
  String get dmMessageActionCopyText => 'ጽሑፍ ቅዳ';

  @override
  String get dmMessageActionCopyVideoUrl => 'የቪዲዮ URL ቅዳ';

  @override
  String get dmMessageActionDeleteForEveryone => 'ለሁሉም ሰው ሰርዝ';

  @override
  String get dmMessageActionReport => 'ሪፖርት አድርግ';

  @override
  String get dmMessageActionRetrySend => 'እንደገና ላክ';

  @override
  String get dmMessageActionCancelSend => 'መሞከር አቁም';

  @override
  String get dmReactionAddCustomA11yLabel => 'ብጁ የኢሞጂ ምላሽ አክል';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'ለ$name መልእክት…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'ለራስዎ ይመልሱ…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'ለዚህ ሪል ይመልሱ';

  @override
  String get dmReelReplyViewChat => 'ውይይት ይመልከቱ';

  @override
  String get dmReelReplySentAnnouncement => 'መልስ ተልኳል';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'በ$emoji ምላሽ ሰጥተዋል';
  }

  @override
  String get dmReelReplyFailed => 'መላክ አልተቻለም';

  @override
  String get dmReelReplyUnverified => 'መላኩን ማረጋገጥ አልተቻለም';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'የአንተ ምላሽ፦ $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name በ$emoji ምላሽ ሰጥቷል';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'ምላሽ በመላክ ላይ፦ $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel => 'ምላሹ አልተሳካም፣ እንደገና ለመሞከር ሁለቴ ንካ';

  @override
  String get dmReactionChipRetryAnnouncement => 'ምላሹን እንደገና በመሞከር ላይ';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'ሌላ ምላሽ ከማከልዎ በፊት የቀድሞውን ምላሽዎን ማስወገድ ያጠናቅቁ።';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'ምላሾች';

  @override
  String get dmReactionsViewA11yLabel => 'ማን ምላሽ እንደሰጠ ይመልከቱ';

  @override
  String get dmReactionRemoveAction => 'አስወግድ';

  @override
  String get dmReactionRetryAction => 'እንደገና ሞክር';

  @override
  String get dmFormatBold => 'ደማቅ';

  @override
  String get dmFormatItalic => 'አዘንብል';

  @override
  String get dmFormatStrikethrough => 'መሰረዝ';

  @override
  String get dmFormatCode => 'ኮድ';

  @override
  String get dmStatusFailed => 'መላክ አልተሳካም';

  @override
  String get inboxConversationActionsSheetLabel => 'የውይይት እርምጃዎች';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'የ$displayName ውይይት';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'ያልተነበበ፣ የ$displayName ውይይት';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ሌሎች',
      one: '$count ሌላ',
    );
    return '$name እና $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'የውይይት እርምጃዎችን አሳይ';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'ርዕስ፡ $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'ቪዲዮ $current/$total';
  }

  @override
  String get exploreSearchHint => 'ይፈልጉ...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'የደንበኝነት ምዝገባን ማዘመን አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get discoverListsTitle => 'ዝርዝሮችን ያግኙ';

  @override
  String get discoverListsFailedToLoad => 'ዝርዝሮችን መጫን አልተሳካም';

  @override
  String get discoverListsLoading => 'የህዝብ ዝርዝሮችን በመፈለግ ላይ...';

  @override
  String get discoverListsRelayTimeout => 'ሪሌው በጊዜው ዝርዝሮችን አልመለሰም። እንደገና ሞክር።';

  @override
  String get discoverListsServiceUnavailable => 'አገልግሎቱ አይገኝም።';

  @override
  String get discoverListsEmptyTitle => 'ምንም የህዝብ ዝርዝሮች አልተገኙም';

  @override
  String get discoverListsEmptySubtitle => 'ለአዳዲስ ዝርዝሮች ቆይተው ይመልከቱ';

  @override
  String get discoverListsByAuthorPrefix => 'በ';

  @override
  String get curatedListEmptyTitle => 'በዚህ ዝርዝር ውስጥ ምንም ቪዲዮዎች የሉም';

  @override
  String get curatedListEmptySubtitle => 'ለመጀመር ቪዲዮዎችን ያክሉ';

  @override
  String get curatedListLoadingVideos => 'ቪዲዮዎችን በመጫን ላይ...';

  @override
  String get curatedListFailedToLoad => 'ዝርዝሩን መጫን አልተሳካም';

  @override
  String get curatedListVideoNotAvailable => 'ቪዲዮው አይገኝም';

  @override
  String get curatedListActionsTooltip => 'የዝርዝር እርምጃዎች';

  @override
  String get curatedListDeleteConfirmTitle => 'ዝርዝር ይሰረዝ?';

  @override
  String get curatedListDeleteConfirmBody =>
      'ይህ ዝርዝሩን ከማስተላለፊያዎች ያስወግዳል። በዝርዝሩ ውስጥ ያሉ ቪዲዮዎች አይሰረዙም።';

  @override
  String get curatedListDeletedSnack => 'ዝርዝሩ ተሰርዟል';

  @override
  String get curatedListDeleteFailed => 'ዝርዝሩን መሰረዝ አልተቻለም';

  @override
  String get peopleListsActionsTooltip => 'የዝርዝር እርምጃዎች';

  @override
  String get listDeleteAction => 'ዝርዝር ሰርዝ';

  @override
  String get peopleListsDeleteConfirmTitle => 'ዝርዝር ይሰረዝ?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'ይህ ዝርዝሩን ለሁሉም ሰው ያስወግዳል። በውስጡ ያሉ ሰዎች ክትትል አይቋረጥም።';

  @override
  String get peopleListsDeleteFailed => 'ዝርዝሩን መሰረዝ አልተቻለም';

  @override
  String get commonRetry => 'እንደገና ይሞክሩ';

  @override
  String get commonSomethingWentWrong => 'የሆነ ችግር ተፈጥሯል';

  @override
  String get commonDelete => 'ሰርዝ';

  @override
  String get commonCancel => 'ሰርዝ';

  @override
  String get commonBack => 'ተመለስ';

  @override
  String get commonClose => 'ዝጋ';

  @override
  String get commonNotNow => 'አሁን አይደለም';

  @override
  String get commonLoading => 'በመጫን ላይ';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'ሽፋኑን ማዘመን አልተቻለም። እንደገና ሞክር።';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'ሽፋን ተዘምኗል';

  @override
  String get videoMetadataC2paMissingTitle => 'ያለ የእውነተኛነት ማረጋገጫ ይለጠፍ?';

  @override
  String get videoMetadataC2paMissingBody =>
      'የይዘት መታወቂያዎችን መጨመር አልቻልንም፣ ስለዚህ ይህ ቪዲዮ በሰው እንደተሰራ አይረጋገጥም። እንደገና ለመሞከር እንደገና ይፍጠሩ ወይም እንዳለ ይለጥፉ።';

  @override
  String get videoMetadataC2paMissingNote =>
      'የይዘት መታወቂያዎች የበይነመረብ ግንኙነት ያስፈልጋቸዋል።';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'የይዘት ማረጋገጫ አገልግሎቱ ምላሽ አልሰጠም። ይህ የአንተ ግንኙነት ችግር አይደለም።';

  @override
  String get videoMetadataC2paMissingRegenerate => 'እንደገና ፍጠር';

  @override
  String get videoMetadataC2paMissingSkip => 'ዝለል';

  @override
  String get videoMetadataGenerationFailed => 'ማመንጨት አልተሳካም';

  @override
  String get videoMetadataTags => 'መለያዎች';

  @override
  String get videoMetadataExpiration => 'የማለቂያ ጊዜ';

  @override
  String get videoMetadataExpirationNotExpire => 'ጊዜው አያልቅም።';

  @override
  String get videoMetadataExpirationOneDay => '1 ቀን';

  @override
  String get videoMetadataExpirationOneWeek => '1 ሳምንት';

  @override
  String get videoMetadataExpirationOneMonth => '1 ወር';

  @override
  String get videoMetadataExpirationOneYear => '1 አመት';

  @override
  String get videoMetadataExpirationOneDecade => '1 አስርት አመታት';

  @override
  String get videoMetadataContentWarnings => 'የይዘት ማስጠንቀቂያዎች';

  @override
  String get videoEditorStickers => 'ተለጣፊዎች';

  @override
  String get trendingTitle => 'በመታየት ላይ ያለ';

  @override
  String get libraryDeleteConfirm => 'ሰርዝ';

  @override
  String get libraryWebUnavailableHeadline => 'ቤተ-መጽሐፍት በሞባይል መተግበሪያ ውስጥ ይገኛል።';

  @override
  String get libraryWebUnavailableDescription =>
      'ረቂቆች እና ክሊፖች በመሳሪያዎ ላይ ተቀምጠዋል፣ስለዚህ እነሱን ለማስተዳደር በስልክዎ ላይ Divineን ይክፈቱ።';

  @override
  String get libraryTabDrafts => 'ረቂቆች';

  @override
  String get libraryTabClips => 'ክሊፖች';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'የተመረጡ ቅንጥቦችን ሰርዝ';

  @override
  String get libraryCloseSemanticLabel => 'ቤተ-መጻሕፍቱን ዝጋ';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'ቅንጥቦችን መምረጥ አቁም';

  @override
  String get librarySelectClipsSemanticLabel => 'ቅንጥቦችን ምረጥ';

  @override
  String get libraryGridSizeLabel => 'የፍርግርግ መጠን';

  @override
  String get libraryDisplayOptionsLabel => 'መደርደር እና የፍርግርግ መጠን';

  @override
  String get libraryMoreActionsSemanticLabel => 'ተጨማሪ የቤተ-መጽሐፍት እርምጃዎች';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count አምዶች',
      one: '$count አምድ',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'ምረጥ';

  @override
  String get librarySortNewestCreation => 'በጣም አዲስ የተፈጠረ';

  @override
  String get librarySortOldestCreation => 'በጣም አሮጌ የተፈጠረ';

  @override
  String get librarySortLongestClip => 'ረጅሙ ክሊፕ';

  @override
  String get librarySortShortestClip => 'አጭሩ ክሊፕ';

  @override
  String get librarySortSquareFirst => 'ካሬ በመጀመሪያ';

  @override
  String get librarySortVerticalFirst => 'ቁመት በመጀመሪያ';

  @override
  String get libraryDeleteClipsWarning =>
      'ይህ እርምጃ ሊቀለበስ አይችልም። የቪዲዮ ፋይሎቹ እስከመጨረሻው ከመሣሪያዎ ይወገዳሉ።';

  @override
  String get libraryPreparingVideo => 'ቪዲዮ በማዘጋጀት ላይ...';

  @override
  String libraryCreateVideo(int count) {
    return 'ቪዲዮ ፍጠር ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች',
      one: '$count ክሊፕ',
    );
    return '$_temp0 ወደ $destination ተቀምጠዋል';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount ተቀምጧል፣ $failureCount አልተሳካም።';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'ወደ $destination ማስቀመጥ አልተቻለም';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination ፍቃድ ተከልክሏል።';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች ተሰርዘዋል',
      one: '$count ክሊፕ ተሰርዟል',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'ቀልብስ';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'በ$daysLeft ቀናት ውስጥ በራስ-ሰር ይሰረዛል',
      one: 'ነገ በራስ-ሰር ይሰረዛል',
      zero: 'ዛሬ በራስ-ሰር ይሰረዛል',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'ረቂቆችን መጫን አልተቻለም';

  @override
  String get libraryCouldNotLoadClips => 'ቅንጥቦችን መጫን አልተቻለም';

  @override
  String get libraryOpenErrorDescription =>
      'ቤተ-መጽሐፍትህን በመክፈት ላይ ሳለ የሆነ ችግር ተፈጥሯል። እንደገና መሞከር ይችላሉ።';

  @override
  String get libraryNoDraftsYetTitle => 'እስካሁን ምንም ረቂቅ የለም።';

  @override
  String get libraryNoDraftsYetSubtitle => 'እንደ ረቂቅ ያስቀመጥካቸው ቪዲዮዎች እዚህ ይታያሉ';

  @override
  String get libraryNoClipsYetTitle => 'እስካሁን ምንም ክሊፖች የሉም';

  @override
  String get libraryNoClipsYetSubtitle => 'የተቀዱ የቪዲዮ ቅንጥቦችህ እዚህ ይታያሉ';

  @override
  String get libraryDraftDeletedSnackbar => 'ረቂቅ ተሰርዟል።';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'ረቂቅን መሰረዝ አልተሳካም።';

  @override
  String get libraryDraftDuplicatedSnackbar => 'ረቂቅ ተባዝቷል።';

  @override
  String get libraryDraftDuplicateFailedSnackbar => 'ረቂቅን ማባዛት አልተሳካም።';

  @override
  String get libraryDraftInProgressBadge => 'በሂደት ላይ';

  @override
  String get libraryDraftActionPost => 'ለጥፍ';

  @override
  String get libraryDraftActionEdit => 'አርትዕ';

  @override
  String get libraryDraftActionDuplicate => 'አባዛ';

  @override
  String get libraryDraftActionDelete => 'ረቂቅ ሰርዝ';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (ቅጂ $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'ረቂቅ ሰርዝ';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'እርግጠኛ ነህ \"$title\" መሰረዝ ትፈልጋለህ?';
  }

  @override
  String get libraryDeleteClipTitle => 'ክሊፕን ሰርዝ';

  @override
  String get libraryDeleteClipMessage => 'እርግጠኛ ነዎት ይህን ክሊፕ መሰረዝ ይፈልጋሉ?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds ሰከ';
  }

  @override
  String get libraryRecordVideo => 'ቪዲዮ ይቅረጹ';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'የቪዲዮ ክሊፕ፣ $duration ሰከንድ';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'መዝገብ ውስጥ ተቀምጧል። $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'የእንቅስቃሴ-አልባ ቅንጥብ፣ $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'ተመርጧል፣ ቁጥር $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'ተመርጧል';

  @override
  String get videoClipSemanticValueNotSelected => 'አልተመረጠም';

  @override
  String get videoClipSemanticHintDisabled => 'ተሰናክሏል';

  @override
  String get videoClipSemanticHintSelect =>
      'ለመምረጥ ነካ ያድርጉ፣ ቅድሚያ ለማሳየት ረዘም ያሉ ጫን';

  @override
  String get videoClipSemanticHintDeselect =>
      'ለማቋረጥ ነካ ያድርጉ፣ ቅድሚያ ለማሳየት ረዘም ያሉ ጫን';

  @override
  String get routerInvalidCreator => 'ልክ ያልሆነ ፈጣሪ';

  @override
  String get routerInvalidHashtagRoute => 'ልክ ያልሆነ የሃሽታግ መስመር';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'ቪዲዮዎችን መጫን አልተቻለም';

  @override
  String get categoryGalleryNoVideosInCategory => 'በዚህ ምድብ ውስጥ ምንም ቪዲዮዎች የሉም';

  @override
  String get categoryGallerySortOptionsLabel => 'የምድብ መደርደሪያ አማራጮች';

  @override
  String get categoryGallerySortHot => 'ታዋቂ';

  @override
  String get categoryGallerySortNew => 'አዲስ';

  @override
  String get categoryGallerySortClassic => 'ክላሲክ';

  @override
  String get categoryGallerySortForYou => 'ለእርስዎ';

  @override
  String get categoriesCouldNotLoadCategories => 'ምድቦችን መጫን አልተቻለም';

  @override
  String get categoriesNoCategoriesAvailable => 'ምንም ምድቦች የሉም';

  @override
  String get notificationsEmptyTitle => 'እስካሁን እንቅስቃሴ የለም';

  @override
  String get notificationsEmptySubtitle => 'ሰዎች ከይዘትዎ ጋር ሲገናኙ እዚህ ያያሉ';

  @override
  String get appsPermissionsTitle => 'የተዋሃዱ መተግበሪያዎች ፈቃዶች';

  @override
  String get appsPermissionsRevoke => 'ሰርዝ';

  @override
  String get appsPermissionsEmptyTitle => 'ምንም የተቀመጡ የተዋሃዱ መተግበሪያ ፈቃዶች የሉም';

  @override
  String get appsPermissionsEmptySubtitle =>
      'አንድ የመዳረሻ ፈቃድ እንዲታወስ ከፈቀዱ በኋላ የተፈቀዱ መተግበሪያዎች እዚህ ይታያሉ።';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName ፈቃድዎን ይፈልጋል';
  }

  @override
  String get nostrAppPermissionDescription =>
      'ይህ መተግበሪያ በDivine የተመረመረ sandbox በኩል መዳረሻ ይጠይቃል።';

  @override
  String get nostrAppPermissionOrigin => 'መነሻ';

  @override
  String get nostrAppPermissionMethod => 'ዘዴ';

  @override
  String get nostrAppPermissionCapability => 'ችሎታ';

  @override
  String get nostrAppPermissionEventKind => 'የክስተት አይነት';

  @override
  String get nostrAppPermissionAllow => 'ፍቀድ';

  @override
  String get appsDetailDefaultTitle => 'የተዋሃደ መተግበሪያ';

  @override
  String get appsDetailNotFoundTitle => 'ውህደት አልተገኘም';

  @override
  String get appsDetailNotFoundSubtitle =>
      'ይህ የጸደቀ ውህደት ከአሁን በኋላ በDivine ውስጥ አይገኝም።';

  @override
  String get appsDetailHowItWorksTitle => 'እንዴት እንደሚሰራ';

  @override
  String get appsDetailHowItWorksBody =>
      'ይህ በDivine ውስጥ የሚሰራ የጸደቀ የሶስተኛ ወገን መተግበሪያ ነው። Divine ለዚህ ውህደት የተገመገሙ አቅሞችን ብቻ ይሰጣል፣ እና ከጸደቁ ምንጮቹ ውጭ የሚደረግ አሰሳን ያግዳል።';

  @override
  String get appsDetailAboutTitle => 'ስለ';

  @override
  String get appsDetailPrimaryOriginTitle => 'ዋና ምንጭ';

  @override
  String get appsDetailApprovedOriginsTitle => 'የጸደቁ ምንጮች';

  @override
  String get appsDetailCapabilitiesTitle => 'የሚገኙ አቅሞች';

  @override
  String get appsDetailAskBeforeTitle => 'ከዚህ በፊት ጠይቅ';

  @override
  String get appsDetailOpenButton => 'ውህደት ክፈት';

  @override
  String get appsDetailNoneDeclared => 'እስካሁን ምንም አልተገለጸም';

  @override
  String get appsDirectoryTitle => 'የተዋሃዱ መተግበሪያዎች';

  @override
  String get appsDirectoryIntroTitle => 'የጸደቁ የሶስተኛ ወገን መተግበሪያዎች';

  @override
  String get appsDirectoryIntroBody =>
      'በDivine ውስጥ የሚሰሩ የጸደቁ የሶስተኛ ወገን መተግበሪያዎች';

  @override
  String get appsDirectoryErrorTitle => 'የተዋሃዱ መተግበሪያዎችን መጫን አልተቻለም';

  @override
  String get appsDirectoryErrorSubtitle => 'የጸደቁ ውህደቶችን እንደገና ለመሞከር ይጎትቱ።';

  @override
  String get appsDirectoryEmptyTitle => 'እስካሁን ምንም የጸደቁ ውህደቶች የሉም';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Divine ሲጨምራቸው የጸደቁ የሶስተኛ ወገን መተግበሪያዎች እዚህ ይታያሉ።';

  @override
  String get appsDirectoryRefresh => 'አድስ';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'የተዋሃዱ መተግበሪያዎች በDivine ሞባይል ውስጥ ይሰራሉ';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'የጸደቁ ውህደቶች ለአሁን በሞባይል ላይ ብቻ ይገኛሉ።';

  @override
  String get appsSandboxUnavailableTitle => 'ውህደት አይገኝም';

  @override
  String get appsSandboxUnavailableBody =>
      'Divine ትክክለኛውን የመዳረሻ ፖሊሲ እንዲተገብር የጸደቁ ውህደቶችን ከተዋሃዱ መተግበሪያዎች ትር ይክፈቱ።';

  @override
  String get appsSandboxLoadingTitle => 'ውህደት በመጫን ላይ';

  @override
  String get appsSandboxLoadingSubtitle => 'ከመጀመሩ በፊት የጸደቀውን ውህደት በመፈተሽ ላይ።';

  @override
  String get appsSandboxBlockedTitle => 'ለደህንነት ታግዷል';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'ይህ ውህደት ከጸደቀው ምንጩ ለመውጣት ሞክሯል።\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'የልጥፉ አገናኝ ወደ ቅንጥብ ሰሌዳ ተቀድቷል';

  @override
  String get shareCopiedEventJson => 'የNostr ክስተት JSON ወደ ቅንጥብ ሰሌዳ ተቀድቷል';

  @override
  String get shareCopiedEventId => 'የNostr ክስተት መለያ ወደ ቅንጥብ ሰሌዳ ተቀድቷል';

  @override
  String get authHeroTaglineAuthentic => 'እውነተኛ አፍታዎች።';

  @override
  String get authHeroTaglineHuman => 'የሰው ፈጠራ።';

  @override
  String get keyImportFailedToImport => 'ቁልፍ ማስመጣት ወይም ከቡንከር ጋር መገናኘት አልተሳካም';

  @override
  String get keyImportInvalidBunkerUrl => 'ልክ ያልሆነ የቡንከር URL';

  @override
  String get keyImportInvalidFormat =>
      'ልክ ያልሆነ ቅርጸት። nsec...፣ hex፣ ncryptsec1...፣ ወይም bunker://... ይጠቀሙ';

  @override
  String get keyImportInvalidNsecFormat =>
      'ልክ ያልሆነ የnsec ቅርጸት። 63 ቁምፊዎች መሆን አለበት';

  @override
  String get keyImportKeyFieldLabel => 'የግል ቁልፍ ወይም የቡንከር URL';

  @override
  String get keyImportKeyRequired => 'እባክዎ የግል ቁልፍዎን ወይም የቡንከር URL ያስገቡ';

  @override
  String get keyImportPasswordRequired => 'እባክዎ ለዚህ የተመሰጠረ ቁልፍ የይለፍ ቃል ያስገቡ';

  @override
  String get keyImportSecurityWarningBody =>
      'የግል ቁልፍዎን ከማንም ሰው ጋር በጭራሽ አያጋሩ። ይህ ቁልፍ ለNostr ማንነትዎ ሙሉ መዳረሻ ይሰጣል።';

  @override
  String get keyImportSecurityWarningTitle => 'የግል ቁልፍዎን ደህንነቱ የተጠበቀ ያድርጉ!';

  @override
  String get keyImportSubtitle =>
      'ነባሩን የNostr ማንነትዎን የግል ቁልፍዎን ወይም የቡንከር URL በመጠቀም ያስመጡ።';

  @override
  String get keyImportTitle => 'የNostr ማንነትዎን\nያስመጡ';

  @override
  String get commentAuthorYouIndicator => 'እርስዎ';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'የ$nameን መገለጫ ይመልከቱ';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'አስተያየት ሰርዝ';

  @override
  String get commentOptionsEditSemanticLabel => 'አስተያየት አርትዕ';

  @override
  String get commentOptionsFlagContentLabel => 'ይዘት ምልክት አድርግ';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'ይህን ይዘት ምልክት አድርግ';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'ይህን አስተያየት ምልክት ለማድረግ ምክንያት ይምረጡ';

  @override
  String get commentOptionsFlagSubmit => 'አስገባ';

  @override
  String get commentOptionsTitle => 'አማራጮች';

  @override
  String get commentsEmptyClassicVineMessage =>
      'አሮጌ አስተያየቶችን ከማህደሩ ማስመጣት ላይ አሁንም እየሰራን ነው። እስካሁን ዝግጁ አይደሉም።';

  @override
  String get commentsEmptyClassicVineTitle => 'ክላሲክ Vine';

  @override
  String get commentsInputEditingLabel => 'በማረም ላይ';

  @override
  String get commentsInputSemanticHint => 'አስተያየት አክል';

  @override
  String get commentsInputSemanticHintEdit => 'አስተያየት አርትዕ';

  @override
  String get commentsInputSemanticHintReply => 'ምላሽ አክል';

  @override
  String get commentsInputSemanticLabel => 'የአስተያየት ግቤት';

  @override
  String get commentsInputSemanticLabelEdit => 'የአርትዖት ግቤት';

  @override
  String get commentsInputSemanticLabelReply => 'የምላሽ ግቤት';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'የ$displayNameን መገለጫ ይመልከቱ';
  }

  @override
  String get classicsEmptyDescription => 'የክላሲኮች ማህደር በመጫን ላይ ነው';

  @override
  String get classicsEmptyTitle => 'ምንም ክላሲኮች አልተገኙም';

  @override
  String get classicsErrorTitle => 'ክላሲኮችን መጫን አልተሳካም';

  @override
  String get classicsUnavailableDescription =>
      'ክላሲኮች ከFunnelcake ማስተላለፊያዎች ጋር ሲገናኙ ብቻ ይገኛሉ።';

  @override
  String get classicsUnavailableSettingsHint =>
      'የክላሲኮች ማህደርን ለመድረስ በቅንብሮች ውስጥ ወደ Funnelcake-የነቃ ማስተላለፊያ ይቀይሩ።';

  @override
  String get classicsUnavailableTitle => 'ክላሲኮች አይገኙም';

  @override
  String get hashtagFeedEmptySubtitle => 'ይህን ሃሽታግ ያለው ቪዲዮ የመለጠፍ የመጀመሪያው ይሁኑ!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'ለ#$hashtag ምንም ቪዲዮ አልተገኘም';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'ይህ ጥቂት ጊዜ ሊወስድ ይችላል';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'ስለ #$hashtag ቪዲዮዎችን በመጫን ላይ...';
  }

  @override
  String get hashtagInputHint => 'ሃሽታጎችን አክል... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'አዲስ ይዘት ለማየት በኋላ ተመልሰው ይመልከቱ';

  @override
  String get newVideosTabEmptyTitle => 'በአዲስ ቪዲዮዎች ውስጥ ምንም ቪዲዮ የለም';

  @override
  String get popularVideosContextTitle => 'ታዋቂ ቪዲዮዎች';

  @override
  String get popularVideosEmptySubtitle => 'አዲስ ይዘት ለማየት በኋላ ተመልሰው ይመልከቱ';

  @override
  String get popularVideosEmptyTitle => 'በታዋቂ ቪዲዮዎች ውስጥ ምንም ቪዲዮ የለም';

  @override
  String get popularVideosErrorTitle => 'በመታየት ላይ ያሉ ቪዲዮዎችን መጫን አልተሳካም';

  @override
  String get popularVideosFeedSourceLabel => 'የታዋቂ ምግብ ምንጭ';

  @override
  String get trendingHashtagsLoading => 'ሃሽታጎችን በመጫን ላይ...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return '$hashtag የተሰየሙ ቪዲዮዎችን ይመልከቱ';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'የቪዲዮ ደራሲ፡ $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'የቪዲዮ መግለጫ፡ $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'የDivine ራዕይ እውነተኛ የአልጎሪዝም ምርጫ እንዲኖርዎት ማድረግ ነው። በአንድ ጥቁር-ሳጥን አልጎሪዝም ውስጥ ከመታሰር ይልቅ፣ ከበርካታ የምክረ-ሃሳብ አቀራረቦች መምረጥ ትችላለህ፦';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'ከምትከተላቸው ፈጣሪዎች በጊዜ ቅደም ተከተል የተደረደረ የጊዜ መስመር';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'ይህ ለመድረኩ ከመተው ይልቅ ትኩረትህን በእጅህ ያደርገዋል። ምግብህ እንዴት እንደሚዘጋጅ ማወቅ አለብህ እና በፈለግከው ጊዜ የመቀየር ኃይል ሊኖርህ ይገባል።';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'እንደ ሙዚቃ፣ ኮሜዲ ወይም ስነ-ጥበብ ላሉ ርዕሶች በማህበረሰብ የተፈጠሩ ብጁ ምግቦች';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed => 'ግላዊ የተደረገ \"ላንተ\" ምግብ';

  @override
  String get forYouAlgorithmChoiceTitle => 'የአንተ አልጎሪዝም፣ የአንተ ምርጫ';

  @override
  String get forYouAlgorithmChoiceTrending => 'በመታየት ላይ ያለ እና ታዋቂ ይዘት';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'ጠንካራ ምልክት — ምላሽ ለመስጠት በበቂ ሁኔታ ተሳትፈሃል';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine የምትደሰትበትን ለመረዳት ከይዘት ጋር እንዴት እንደምትገናኝ ትኩረት ይሰጣል። ቪዲዮ በተመለከትክ፣ ምላሽ በሰጠህ፣ አስተያየት በተውክ ወይም እንደገና በለጠፍክ ቁጥር ስርዓቱ ማስታወሻ ይይዛል።';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'እንዴት እንደሚሰራ';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'የተለያዩ እርምጃዎች የተለያዩ የፍላጎት ደረጃዎችን ያመለክታሉ፦';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'እስካሁን የመመልከቻ ታሪክ ካልገነባህ፣ በአሁኑ ጊዜ ታዋቂ እና በመታየት ላይ ያለውን ከቅርብ ጊዜ ልጥፎች ጋር ቀላቅለን እናሳያለን። ይህ ለማሰስ ጥሩ መነሻ ይሰጥሃል።';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'በምትመለከትበት፣ በምትወድበት እና ከይዘት ጋር በምትገናኝበት ጊዜ፣ ምክረ-ሃሳቦች ቀስ በቀስ ይበልጥ ግላዊ ይሆናሉ። ከጊዜ በኋላ የላንተ ምግብ በራስህ ልታገኛቸው የማትችላቸውን ፈጣሪዎች ቪዲዮዎች ያመጣል።';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Divine አዲስ ነው?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'ገንቢዎች የራሳቸውን አልጎሪዝም መተግበር የሚችሉበት ክፍት ስርዓት እየገነባን ነው፣ እና የትኞቹን እንደምትጠቀም መምረጥ — ወይም ሙሉ በሙሉ ማቆም — ትችላለህ።';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'ክፍት ምንጭ እና ግልጽ';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'መካከለኛ ምልክት — አድናቆትን ለማሳየት ፈጣን መንገድ';

  @override
  String get forYouAlgorithmReactionsTitle => 'ምላሾች';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'በጣም ጠንካራ ምልክት — ከተከታዮችህ ጋር ማጋራት ኃይለኛ ማጽደቅ ነው';

  @override
  String get forYouAlgorithmSubtitle => 'በGorse የተጎላበተ፣ ክፍት-ምንጭ የምክረ-ሃሳብ ሞተር';

  @override
  String get forYouAlgorithmTitle => 'የDivine አልጎሪዝም';

  @override
  String get forYouAlgorithmViewsDescription => 'ቀላል ምልክት — መሰረታዊ ፍላጎትን ያመለክታል';

  @override
  String get forYouEmptyDescription =>
      'ግላዊ ምክረ-ሃሳቦችን ለማግኘት አንዳንድ ቪዲዮዎችን ይመልከቱ እና ይውደዱ።';

  @override
  String get forYouEmptyTitle => 'እስካሁን ምንም ምክረ-ሃሳብ የለም';

  @override
  String get forYouErrorTitle => 'ምክረ-ሃሳቦችን መጫን አልተሳካም';

  @override
  String get forYouUnavailableDescription =>
      'ግላዊ ምክረ-ሃሳቦች ከFunnelcake ጋር ግንኙነት ይፈልጋሉ።';

  @override
  String get forYouUnavailableTitle => 'ላንተ አይገኝም';

  @override
  String get inboxConversationOptionsLabel => 'አማራጮች';

  @override
  String get inboxConversationViewProfileButton => 'መገለጫ ይመልከቱ';

  @override
  String get inboxMessageRequestsEmpty => 'ምንም የመልእክት ጥያቄዎች የሉም';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'የመልእክት ጥያቄዎች፣ $requestCount በመጠባበቅ ላይ';
  }

  @override
  String get inboxMessageRequestsTitle => 'የመልእክት ጥያቄዎች';

  @override
  String get inboxMessagesTab => 'መልእክቶች';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'የ$displayName የመልእክት ጥያቄ';
  }

  @override
  String get inboxRequestTileSubtitle => 'የመልእክት ጥያቄ ልኳል';

  @override
  String get inboxRequestsMarkAllRead => 'ሁሉንም ጥያቄዎች እንደተነበቡ ምልክት አድርግ';

  @override
  String get inboxRequestsRemoveAll => 'ሁሉንም ጥያቄዎች አስወግድ';

  @override
  String get messageRequestDeclineAndRemoveButton => 'አትቀበል እና አስወግድ';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'የ$displayName ጥያቄ ውድቅ ተደርጓል';
  }

  @override
  String get messageRequestLoadFailed => 'ይህን ጥያቄ መጫን አልተቻለም።';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count ተከታዮች';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count መልእክቶች',
      one: '$count መልእክት',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'መልእክቶችን ይመልከቱ';

  @override
  String get messageRequestViewProfileButton => 'መገለጫ ይመልከቱ';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName ሊልክልህ ይፈልጋል፣ $messageText ልከዋል።';
  }

  @override
  String get deleteAccountAccountChanged =>
      'መለያዎችን ቀይረዋል፣ ስለዚህ ምንም አልተሰረዘም። ለማስወገድ ለሚፈልጉት መለያ ስረዛን እንደገና ይክፈቱ።';

  @override
  String get deleteAccountConfirmDeletePrompt => 'ለማረጋገጥ፣ ይተይቡ፦';

  @override
  String get deleteAccountConfirmUsernamePrompt => 'ለማረጋገጥ፣ የተጠቃሚ ስምዎን ይተይቡ፦';

  @override
  String get deleteAccountConfirmationHint => 'DELETE ብለው ይተይቡ';

  @override
  String get deleteAccountConfirmationHintUsername => 'የተጠቃሚ ስምዎን ይተይቡ';

  @override
  String get deleteAccountDeleteAllContentButton => 'ሁሉንም ይዘት ሰርዝ';

  @override
  String get accountDeletionRecoveryTitle => 'መለያዎ በመሰረዝ ላይ';

  @override
  String get accountDeletionRecoveryBody =>
      'መለያዎን መሰረዝ ማጠናቀቅ አልቻልንም። የተጠቃሚ ስምዎ ለእርስዎ ተይዞልዎታል፣ አሁንም መመለስ ይቻላል።';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'የተጠቃሚ ስሜን ይመልሱ';

  @override
  String get accountDeletionFinishingBody =>
      'የመለያዎ ስረዛ ጥያቄ አሁንም በሂደት ላይ ነው። እስክናጠናቅቅ ድረስ ሌላ መለያ መጠቀም ይችላሉ።';

  @override
  String get accountDeletionOtherAccountPending =>
      'በዚህ መሣሪያ ላይ የሌላ መለያ ስረዛ አሁንም በሂደት ላይ ነው። ይህን መለያ ከመሰረዝዎ በፊት እስኪጠናቀቅ ይጠብቁ።';

  @override
  String get accountDeletionCancellingBody =>
      'የመሰረዝ ጥያቄዎን እየሰረዝን ነው። ይህን ማያ ገጽ ከመልቀቅዎ በፊት እንደገና ያረጋግጡ።';

  @override
  String get accountDeletionRecoveryFailed =>
      'የተጠቃሚ ስምዎን ገና መመለስ አልቻልንም። ግንኙነትዎን ያረጋግጡና እንደገና ይሞክሩ።';

  @override
  String get accountDeletionUsernameRestored =>
      'የተጠቃሚ ስምዎ ተመልሷል። መለያዎ አልተሰረዘም።';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'የመሰረዙን ሁኔታ ማረጋገጥ አልቻልንም። ግንኙነትዎን ያረጋግጡና እንደገና ይሞክሩ።';

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
      'የመለያ ስረዛ አሁን አይገኝም። ምንም አልተሰረዘም።';

  @override
  String get deleteAccountDeletionIncomplete =>
      'መለያዎን መሰረዝ ማጠናቀቅ አልቻልንም። እንደገና ይሞክሩ።';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ የመጨረሻ ማረጋገጫ';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'የመሰረዝ ጥያቄዎች ተልከዋል፣ ግን ቁልፎችዎ ከዚህ መሣሪያ ሙሉ በሙሉ ላይወገዱ ይችላሉ። እንደገና ለመሞከር ወደ ቅንብሮች → Nostr ቁልፎች → ቁልፎችን አስወግድ ይሂዱ።';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'የመሰረዝ ጥያቄዎች ተልከዋል እና ወጥተዋል፣ ግን አንዳንድ የአካባቢ ውሂብ ከዚህ መሣሪያ ማስወገድ አልተቻለም።';

  @override
  String get deleteAccountPreparingDeletion => 'ስረዛን በማዘጋጀት ላይ...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total ክስተቶች';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'ይህ የዚህን መለያ የአካባቢ መግቢያ ከዚህ መሣሪያ ያስወግዳል። የDivine መለያዎን ወይም የNostr ማንነትዎን አይሰርዝም።\n\nየዚህ መለያ ረቂቆችዎ እና ክሊፖችዎ በዚህ መሣሪያ ላይ ተቀምጠው ይቆያሉ። ይህ የመጨረሻው የአካባቢ መለያዎ ከሆነ፣ ወደ መግቢያ ማያ ገጹ ይመለሳሉ።';

  @override
  String get deleteAccountRemoveKeysConfirm => 'ከመሣሪያ አስወግድ';

  @override
  String get deleteAccountRemoveKeysTitle => 'ይህን መለያ ከዚህ መሣሪያ ማስወገድ?';

  @override
  String get deleteAccountReauthRequired =>
      'መለያዎን ለመሰረዝ እንደገና ይግቡ። እስካሁን ምንም አልተሰረዘም።';

  @override
  String get deleteAccountServerDeletionFailed =>
      'የልጥፎችዎ የመሰረዝ ጥያቄዎች ተልከዋል፣ ነገር ግን መለያዎን መሰረዝ ማጠናቀቅ አልቻልንም። ትንሽ ቆይተው እንደገና ይሞክሩ።';

  @override
  String get deleteAccountSuccess =>
      'የDivine መለያዎ ተሰርዟል። ለNostr ልጥፎችዎ የስረዛ ጥያቄዎች ተልከዋል፣ ነገር ግን አንዳንድ ሪሌዎች፣ ደንበኞች ወይም መሸጎጫዎች ቅጂዎችን ሊያቆዩ ይችላሉ።';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'የመለያ ስረዛ ተጠይቋል። የአንዳንድ ነባር ልጥፎች ስረዛ በተናጠል ማረጋገጥ አልተቻለም።';

  @override
  String get deleteAccountWarningBody =>
      'ይህ ለመለያዎ እና ለይዘትዎ የመሰረዝ ጥያቄዎችን ይልካል፣ የሚቻል ከሆነ የDivine መለያዎን ይሰርዛል እና ከዚህ መሣሪያ ያስወጣዎታል። አንዳንድ ቅብብሎሾች፣ ደንበኞች እና የፍለጋ ማውጫዎች ቅጂዎችን ሊይዙ ይችላሉ። ሌሎች የገቡ መሣሪያዎች እዚያ ቁልፎችን እስኪያስወግዱ ድረስ ንቁ ሆነው ይቆያሉ።';

  @override
  String get findPeopleNoContacts =>
      'ምንም እውቂያዎች አልተገኙም።\nእዚህ ለማየት ሰዎችን መከተል ይጀምሩ።';

  @override
  String get geoBlockedCityLabel => 'ከተማ';

  @override
  String get geoBlockedCountryLabel => 'ሀገር';

  @override
  String get geoBlockedDefaultReason =>
      'ይህ አገልግሎት በአካባቢ ደንቦች ምክንያት በክልልዎ ውስጥ አይገኝም።';

  @override
  String get geoBlockedLegalNotice =>
      'የአካባቢ ህጎችዎን እና ደንቦችዎን እናከብራለን። ይህ ገደብ በIP አድራሻዎ አካባቢ ላይ የተመሰረተ ነው።';

  @override
  String get geoBlockedRegionLabel => 'ክልል';

  @override
  String get geoBlockedTitle => 'አገልግሎት አይገኝም';

  @override
  String get likedVideosEmpty => 'ምንም የተወደዱ ቪዲዮዎች የሉም';

  @override
  String get likedVideosInvalidRoute => 'ልክ ያልሆነ መንገድ';

  @override
  String get likedVideosTitle => 'የተወደዱ ቪዲዮዎች';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'ስቀላን እንደገና በመሞከር ላይ…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'ወደ ረቂቆች አስቀምጥ';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'ወደ ረቂቆች ተቀምጧል';

  @override
  String get uploadFailureSheetTitle => 'ስቀላ አልተሳካም';

  @override
  String get uploadFailureSheetTryAgainButton => 'እንደገና ይሞክሩ';

  @override
  String get videoEditorAudioImportAudio => 'ኦዲዮ አስመጣ';

  @override
  String get videoEditorAudioImportFailed => 'ኦዲዮ ማስመጣት አልተሳካም።';

  @override
  String get videoIconPlaceholderLabel => 'ቪዲዮ';

  @override
  String get publishErrorNotSignedIn => 'ቪዲዮዎችን ለማተም እባክዎ ይግቡ።';

  @override
  String get publishErrorNoRetry => 'እንደገና የሚሞከር ስቀላ የለም።';

  @override
  String get publishErrorNoInternet =>
      'የበይነመረብ ግንኙነት የለም። ዋይ ፋይዎን ወይም የሞባይል ዳታዎን ይፈትሹ እና እንደገና ይሞክሩ።';

  @override
  String get publishErrorServerUnreachable =>
      'አገልጋዩ ላይ መድረስ አልተቻለም። እባክዎ ከአፍታ በኋላ እንደገና ይሞክሩ።';

  @override
  String get publishErrorTimeout =>
      'ስቀላው ጊዜው አልፎበታል። ጠንካራ ግንኙነት ወይም አነስ ያለ ቪዲዮ ይሞክሩ።';

  @override
  String get publishErrorTls =>
      'ደህንነቱ የተጠበቀ ግንኙነት አልተሳካም። አውታረ መረብዎን ይፈትሹ — የሕዝብ ዋይ ፋይ ስቀላዎችን ሊያግድ ይችላል።';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'የሚዲያ አገልጋዩ ($serverName) አይገኝም። በቅንብሮችዎ ውስጥ ሌላ መምረጥ ይችላሉ።';
  }

  @override
  String get publishErrorFileTooLarge =>
      'የቪዲዮ ፋይሉ ለአገልጋዩ በጣም ትልቅ ነው። ቆርጠው ለማሳጠር ወይም ጥራቱን ለመቀነስ ይሞክሩ።';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'የሚዲያ አገልጋዩ ($serverName) የውስጥ ስህተት አጋጥሞታል። በቅንብሮችዎ ውስጥ ሌላ መምረጥ ይችላሉ።';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'የሚዲያ አገልጋዩ ($serverName) ለጊዜው ተቋርጧል። ከጥቂት ጊዜ በኋላ እንደገና ይሞክሩ ወይም በቅንብሮችዎ ውስጥ ሌላ ይምረጡ።';
  }

  @override
  String get publishErrorForbidden => 'ወደዚህ አገልጋይ ለመስቀል ፈቃድ የለዎትም።';

  @override
  String get publishErrorFileNotFound =>
      'የቪዲዮ ፋይሉ ሊገኝ አልቻለም። ምናልባት ተሰርዞ ሊሆን ይችላል። እንደገና ይቅረጹ እና ይሞክሩ።';

  @override
  String get publishErrorLowStorage =>
      'በመሣሪያዎ ላይ በቂ ማከማቻ የለም። ትንሽ ቦታ ነፃ ያድርጉ እና እንደገና ይሞክሩ።';

  @override
  String get publishErrorThumbnailFailed =>
      'ቪዲዮው ተሰቅሏል፣ ነገር ግን ድንክዬው ሊዘጋጅ አልቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get publishErrorNostrPublishFailed =>
      'ቪዲዮው ተሰቅሏል ነገር ግን ልጥፉ ሊታተም አልቻለም። የቅብብሎሽ ቅንብሮችዎን ይፈትሹ እና እንደገና ይሞክሩ።';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'ቪዲዮው ተሰቅሏል፣ ነገር ግን ድምፁ ለዳግም ጥቅም አልተፈቀደም። ለመለጠፍ ሌላ ድምፅ ይምረጡ።';

  @override
  String get publishErrorInterrupted => 'ይህ ስቀላ ተቋርጧል። እንደገና መሞከር ይፈልጋሉ?';

  @override
  String get publishErrorAccountChanged =>
      'ይህ ቪዲዮ የሌላ መለያ ነው። ለመለጠፍ ወደዚያ መለያ ተመለስ።';

  @override
  String get publishErrorGeneric => 'የሆነ ችግር ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get publishErrorRateLimited =>
      'አሁን በጣም ብዙ ስቀላዎች አሉ። ከአፍታ በኋላ እንደገና ይሞክሩ።';

  @override
  String get publishErrorUploadSessionExpired =>
      'የስቀላ ክፍለ ጊዜዎ አብቅቷል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get publishErrorPermissionDenied =>
      'Divine ለመስቀል ፈቃድ የለውም። በቅንብሮችዎ ውስጥ የመተግበሪያ ፈቃዶችን ይፈትሹ እና እንደገና ይሞክሩ።';

  @override
  String get publishErrorOutOfMemory =>
      'የመሣሪያዎ ማህደረ ትውስታ እያለቀ ነው። አንዳንድ መተግበሪያዎችን ይዝጉ እና እንደገና ይሞክሩ።';

  @override
  String get publishErrorOverlaysUnavailable =>
      'የዚህ ረቂቅ ጽሑፍና ተለጣፊዎች ሊዘጋጁ አልቻሉም። በአራሚው ውስጥ ይክፈቱት፣ ከዚያ እንደገና ይለጥፉ።';

  @override
  String get publishErrorUnknownServer => 'ያልታወቀ አገልጋይ';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'ማጣሪያ፡ $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'ለ\"$query\" ምንም ውጤት አልተገኘም';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return '$tag የተሰየሙ ቪዲዮዎችን ይመልከቱ';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'ድምጽ፡ $soundName በ$creatorName። የድምጽ ዝርዝሮችን ለማየት መታ ያድርጉ።';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'በ$creatorName ኦሪጅናል ድምጽ። ይህን ድምጽ ለመጠቀም መታ ያድርጉ።';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'ድምጽ፡ $soundName በ$creatorName። ዝርዝሮችን ለማየት መታ ያድርጉ።';
  }

  @override
  String get soundDetailLoadError => 'ድምጽ መጫን አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get soundDetailNotFoundMessage => 'ይህ ድምጽ ሊገኝ አልቻለም';

  @override
  String get soundDetailNotFoundTitle => 'ድምጽ አልተገኘም';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count ሉፖች';
  }

  @override
  String get originalSoundUnavailableBody => 'ከዚህ ቪዲዮ የሚገኘው ኦዲዮ ለብቻው አይገኝም።';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'ኦሪጅናል ድምጽ - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'ይህ ሰው Divine በማህደር ውስጥ ያገኘውን ዋና Vine ለጥፏል። ይህ የመለያ ማረጋገጫ ባጅ አይደለም።';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'የመገለጫ ምልክት';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine ይህን ምልክት ለቡድን መለያዎች ይሰጣል። ከNIP-05፣ ከተረጋገጡ የመለያ አገናኞች እና ከOG Viner ሁኔታ የተለየ ነው።';

  @override
  String get unfollowConfirmButton => 'አትከተል';

  @override
  String get videoClipSaveFailed => 'ክሊፕ ማስቀመጥ አልተሳካም';

  @override
  String videoClipSaveTo(String destination) {
    return 'ወደ $destination አስቀምጥ';
  }

  @override
  String get videoClipDelete => 'ክሊፕ ሰርዝ';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'በ$creatorName +$additionalCreatorCount የተነሳሳ። መገለጫቸውን ለማየት መታ ያድርጉ።';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'በ$creatorName የተነሳሳ። መገለጫቸውን ለማየት መታ ያድርጉ።';
  }

  @override
  String get bugReportSendReport => 'ሪፖርት ላክ';

  @override
  String get supportSubjectRequiredLabel => 'ርዕስ *';

  @override
  String get supportPublicSubmissionTitle => 'ይፋዊ የGitHub ልጥፍ';

  @override
  String get supportPublicSubmissionMessage =>
      'እዚህ የምታስገባው ሁሉ ገንቢዎች እንዲሰሩበት በGitHub ላይ ባለው ክፍት ምንጭ ማከማቻችን ውስጥ ይለጠፋል። ልጥፉንና የገባህበትን መለያ ማንኛውም ሰው በይፋ ማየት ይችላል።';

  @override
  String get supportRequiredHelper => 'ያስፈልጋል';

  @override
  String get supportFieldLimitReached =>
      'ይህ ከፍተኛው ርዝመት ነው። ከዚህ በኋላ ያለው አልተጨመረም።';

  @override
  String get bugReportSubjectHint => 'የችግሩ አጭር ማጠቃለያ';

  @override
  String get bugReportDescriptionRequiredLabel => 'ምን ተከሰተ? *';

  @override
  String get bugReportDescriptionHint => 'ያጋጠመዎትን ችግር ይግለጹ';

  @override
  String get bugReportStepsLabel => 'ለመድገም የሚወሰዱ እርምጃዎች';

  @override
  String get bugReportStepsHint =>
      '1. ወደ... ይሂዱ\n2. ... ላይ መታ ያድርጉ\n3. ስህተቱን ይመልከቱ';

  @override
  String get bugReportExpectedBehaviorLabel => 'የሚጠበቀው ባህሪ';

  @override
  String get bugReportExpectedBehaviorHint => 'በምትኩ ምን መሆን ነበረበት?';

  @override
  String get bugReportDiagnosticsNotice => 'የመሳሪያ መረጃ እና ሎጎች በራስ-ሰር ይካተታሉ።';

  @override
  String get bugReportSuccessMessage =>
      'እናመሰግናለን! ሪፖርትዎን ተቀብለናል፣ Divineን ለማሻሻል እንጠቀምበታለን።';

  @override
  String get bugReportAttachImages => 'ምስሎችን አያይዝ';

  @override
  String bugReportImagesCount(int count, int max) {
    return 'ከ$max ምስሎች $count ተመርጠዋል';
  }

  @override
  String get bugReportRemoveImage => 'ምስሉን አስወግድ';

  @override
  String get bugReportUploadFailed =>
      'የተመረጠውን ምስል መስቀል አልቻልንም። እንደገና ሞክር ወይም ሪፖርቱን ያለ እሱ ላክ።';

  @override
  String get bugReportSendFailed => 'የሳንካ ሪፖርት መላክ አልተሳካም። እባክዎ ቆይተው ይሞክሩ።';

  @override
  String get featureRequestSendRequest => 'ጥያቄ ላክ';

  @override
  String get featureRequestSubjectHint => 'የሀሳብዎ አጭር ማጠቃለያ';

  @override
  String get featureRequestDescriptionRequiredLabel => 'ምን ይፈልጋሉ? *';

  @override
  String get featureRequestDescriptionHint => 'የሚፈልጉትን ባህሪ ይግለጹ';

  @override
  String get featureRequestUsefulnessLabel => 'ይህ እንዴት ይጠቅማል?';

  @override
  String get featureRequestUsefulnessHint => 'ይህ ባህሪ የሚሰጠውን ጥቅም ያብራሩ';

  @override
  String get featureRequestWhenLabel => 'ይህን መቼ ይጠቀማሉ?';

  @override
  String get featureRequestWhenHint => 'ይህ የሚረዳባቸውን ሁኔታዎች ይግለጹ';

  @override
  String get featureRequestSuccessMessage =>
      'እናመሰግናለን! የባህሪ ጥያቄዎን ተቀብለናል፣ እንመለከተዋለን።';

  @override
  String get featureRequestSendFailed => 'የባህሪ ጥያቄ መላክ አልተሳካም። እባክዎ ቆይተው ይሞክሩ።';

  @override
  String get notificationFollowBack => 'ተመለስ ተከታተል።';

  @override
  String get followingTitle => 'የሚከተሉት';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName የሚከተላቸው';
  }

  @override
  String get followingFailedToLoadList => 'የሚከተለውን ዝርዝር መጫን አልተሳካም።';

  @override
  String get followingEmptyTitle => 'እስካሁን ማንንም አይከተሉም';

  @override
  String get followersTitle => 'ተከታዮች';

  @override
  String followersTitleForName(String displayName) {
    return 'የ$displayName ተከታዮች';
  }

  @override
  String get followersFailedToLoadList => 'የተከታዮች ዝርዝርን መጫን አልተሳካም።';

  @override
  String get followersEmptyTitle => 'እስካሁን ምንም ተከታዮች የሉም';

  @override
  String get followersUpdateFollowFailed =>
      'የመከተል ሁኔታን ማዘመን አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get followersSortSemanticLabel => 'ተከታዮችን ደርድር';

  @override
  String get followingSortSemanticLabel => 'የሚከተሉትን ደርድር';

  @override
  String get followSortTitle => 'ደርድር በ';

  @override
  String get followSortNewest => 'አዲሶቹ መጀመሪያ';

  @override
  String get followSortOldest => 'አሮጌዎቹ መጀመሪያ';

  @override
  String get newMessageTitle => 'አዲስ መልዕክት';

  @override
  String get newMessageFindPeople => 'ሰዎችን ይፈልጉ';

  @override
  String get newMessageNoContacts =>
      'ምንም እውቂያዎች አልተገኙም።\nሰዎችን ይከተሉ እና እዚህ ያያሉ።';

  @override
  String get newMessageNoUsersFound => 'ምንም ተጠቃሚዎች አልተገኙም';

  @override
  String get hashtagSearchTitle => 'ሃሽታጎችን ይፈልጉ';

  @override
  String get hashtagSearchSubtitle => 'በመታየት ላይ ያሉ ርዕሶችን እና ይዘትን ያግኙ';

  @override
  String hashtagSearchNoResults(String query) {
    return 'ለ\"$query\" ምንም ሃሽታጎች አልተገኙም';
  }

  @override
  String get hashtagSearchFailed => 'ፍለጋው አልተሳካም';

  @override
  String get userNotAvailableTitle => 'መለያው አይገኝም';

  @override
  String get userNotAvailableBody => 'ይህ መለያ አሁን አይገኝም።';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'ቅንብሮችን ማስቀመጥ አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get blossomValidServerUrl =>
      'እባክዎ ትክክለኛ የአገልጋይ URL ያስገቡ (ለምሳሌ፦ https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'የBlossom ቅንብሮች ተቀምጠዋል';

  @override
  String get blossomSaveTooltip => 'አስቀምጥ';

  @override
  String get blossomAboutTitle => 'ስለ Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom ቪዲዮዎችን ወደ ማንኛውም ተኳሃኝ አገልጋይ ለመስቀል የሚያስችል ያልተማከለ የሚዲያ ማከማቻ ፕሮቶኮል ነው። በነባሪነት ቪዲዮዎች ወደ Divine የBlossom አገልጋይ ይሰቀላሉ። በምትኩ ብጁ አገልጋይ ለመጠቀም ከታች ያለውን አማራጭ ያንቁ።';

  @override
  String get blossomUseCustomServer => 'ብጁ Blossom አገልጋይ ተጠቀም';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'ቪዲዮዎች ወደ ብጁ Blossom አገልጋይዎ ይሰቀላሉ';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'ቪዲዮዎችዎ አሁን ወደ Divine የBlossom አገልጋይ እየተሰቀሉ ናቸው';

  @override
  String get blossomCustomServerUrl => 'ብጁ Blossom አገልጋይ URL';

  @override
  String get blossomCustomServerHelper => 'የብጁ Blossom አገልጋይዎን URL ያስገቡ';

  @override
  String get blossomPopularServers => 'ታዋቂ የBlossom አገልጋዮች';

  @override
  String get blossomServerUrlMustUseHttps =>
      'የBlossom አገልጋይ URL https:// መጠቀም አለበት';

  @override
  String get blueskyFailedToUpdateCrosspost => 'መስቀለኛ መንገድን ማዘመን አልተሳካም።';

  @override
  String get blueskySignInRequired => 'የBluesky ቅንብሮችን ለማስተዳደር ይግቡ';

  @override
  String get blueskyPublishVideos => 'ቪዲዮዎችን ወደ Bluesky አትም';

  @override
  String get blueskyEnabledSubtitle => 'ቪዲዮዎችዎ ወደ Bluesky ይታተማሉ';

  @override
  String get blueskyDisabledSubtitle => 'ቪዲዮዎችዎ ወደ Bluesky አይታተሙም';

  @override
  String get blueskyBackfillDisclosureTitle => 'ያለፉ ቪዲዮዎችህም ይለጠፋሉ';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'ይህን ሲያበሩ፣ Divine የቆዩ ቪዲዮዎችህን ወደ Bluesky ከአሮጌዎቹ ጀምሮ፣ የቀን ገደቡን ሳይጣደፍ መላክ ይጀምራል።';

  @override
  String get blueskyHandle => 'የBluesky መያዣ';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => 'ሁኔታ';

  @override
  String get blueskyStatusReady => 'መለያው ተዘጋጅቷል እና ዝግጁ ነው';

  @override
  String get blueskyStatusPending => 'መለያው በመዘጋጀት ላይ ነው...';

  @override
  String get blueskyStatusFailed => 'መለያውን ማዘጋጀት አልተሳካም';

  @override
  String get blueskyStatusDisabled => 'መለያው ተሰናክሏል';

  @override
  String get blueskyStatusNotLinked => 'ምንም የBluesky መለያ አልተገናኘም';

  @override
  String get blueskyUsernameRequired =>
      'ወደ Bluesky ከማተምህ በፊት የdivine.video መለያ አዘጋጅ';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'በBluesky ማተም የተያዘ username.divine.video መለያ ይፈልጋል።';

  @override
  String get blueskyUsernameSyncPending =>
      'የDivine መለያህ ተይዟል። ከBluesky ጋር በማገናኘት ላይ ነን — ከጥቂት ቆይታ በኋላ እንደገና ሞክር።';

  @override
  String get blueskyStatusUnavailableRetry =>
      'የDivine መለያህን ማረጋገጥ አልቻልንም። እንደገና ሞክር።';

  @override
  String get blueskySetUpHandle => 'አዘጋጅ';

  @override
  String get blueskyTemporarilyUnavailable =>
      'በBluesky ማተም ለጊዜው አይገኝም። እባክህ እንደገና ሞክር።';

  @override
  String get invitesTitle => 'ጓደኞችን ይጋብዙ';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ግብዣዎች ለመፍጠር ዝግጁ ናቸው',
      one: '$count ግብዣ ለመፍጠር ዝግጁ ነው',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle => 'አንዱን ለማጋራት ስትዘጋጅ ኮድ ፍጠር።';

  @override
  String get invitesGenerateButtonLabel => 'ግብዣ ፍጠር';

  @override
  String get invitesNoneAvailable => 'አሁን ምንም ግብዣዎች የሉም';

  @override
  String get invitesShareWithPeople => 'Divineን ከሚያውቋቸው ሰዎች ጋር ያጋሩ';

  @override
  String get invitesUsedInvites => 'ያገለገሉ ግብዣዎች';

  @override
  String invitesShareMessage(String code) {
    return 'Divine ላይ አብረኝ ግባ! ለመጀመር የግብዣ ኮድ $code ተጠቀም፦\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'ግብዣ ቅዳ';

  @override
  String get invitesCopied => 'ግብዣው ተቀድቷል!';

  @override
  String get invitesShareInvite => 'ግብዣ አጋራ';

  @override
  String get invitesShareSubject => 'Divine ላይ አብረኝ ግባ';

  @override
  String get invitesClaimed => 'ተጠቅመዋል';

  @override
  String get invitesCouldNotLoad => 'ግብዣዎችን መጫን አልተቻለም';

  @override
  String get invitesRetry => 'እንደገና ሞክር';

  @override
  String get searchSomethingWentWrong => 'የሆነ ችግር ተፈጥሯል።';

  @override
  String get searchTryAgain => 'እንደገና ይሞክሩ';

  @override
  String get searchForLists => 'ዝርዝሮችን ይፈልጉ';

  @override
  String get searchFindCuratedVideoLists => 'የተመረጡ የቪዲዮ ዝርዝሮችን ያግኙ';

  @override
  String get searchEnterQuery => 'የፍለጋ ጥያቄ አስገባ';

  @override
  String get searchDiscoverSomethingInteresting => 'አንድ አስደሳች ነገር ያግኙ';

  @override
  String get searchPeopleSectionHeader => 'ሰዎች';

  @override
  String get searchPeopleLoadingLabel => 'የሰዎች ውጤቶች በመጫን ላይ';

  @override
  String get searchTagsSectionHeader => 'መለያዎች';

  @override
  String get searchTagsLoadingLabel => 'የመለያ ውጤቶች በመጫን ላይ';

  @override
  String get searchVideosSectionHeader => 'ቪዲዮዎች';

  @override
  String get searchVideosLoadingLabel => 'የቪዲዮ ውጤቶች በመጫን ላይ';

  @override
  String get searchVideosSortOptionsLabel => 'የቪዲዮ ውጤቶችን ደርድር';

  @override
  String get searchVideosSortTrending => 'ትኩስ';

  @override
  String get searchVideosSortLoops => 'አብዛኛ ሉፖች';

  @override
  String get searchVideosSortEngagement => 'አብዛኛ ተሳትፎ';

  @override
  String get searchVideosSortRecent => 'የቅርብ ጊዜ';

  @override
  String get searchListsSectionHeader => 'ዝርዝሮች';

  @override
  String get searchListsLoadingLabel => 'የዝርዝር ውጤቶችን በመጫን ላይ';

  @override
  String get cameraAgeRestriction => 'ይዘት ለመፍጠር 16 ወይም ከዚያ በላይ መሆን አለቦት';

  @override
  String get keyImportInsecureBunkerRelay =>
      'የBunker ሪሌይ wss:// መጠቀም አለበት (ws:// ለlocalhost ብቻ ይፈቀዳል)';

  @override
  String get timeNow => 'አሁን';

  @override
  String timeShortMinutes(int count) {
    return '$countም';
  }

  @override
  String timeShortHours(int count) {
    return '$countሸ';
  }

  @override
  String timeShortDays(int count) {
    return '$countመ';
  }

  @override
  String timeShortWeeks(int count) {
    return '$countወ';
  }

  @override
  String timeShortMonths(int count) {
    return '$countሞ';
  }

  @override
  String timeShortYears(int count) {
    return '$countይ';
  }

  @override
  String get timeVerboseNow => 'አሁን';

  @override
  String timeAgo(String time) {
    return '$time በፊት';
  }

  @override
  String get timeToday => 'ዛሬ';

  @override
  String get timeYesterday => 'ትናንት';

  @override
  String get timeJustNow => 'ልክ አሁን';

  @override
  String timeMinutesAgo(int count) {
    return '$countደቂቃ በፊት';
  }

  @override
  String timeHoursAgo(int count) {
    return '$countሰ በፊት';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d በፊት';
  }

  @override
  String get draftTimeJustNow => 'ልክ አሁን';

  @override
  String get contentLabelNudity => 'እርቃንነት';

  @override
  String get contentLabelSexualContent => 'ወሲባዊ ይዘት';

  @override
  String get contentLabelPornography => 'የብልግና ሥዕሎች';

  @override
  String get contentLabelGraphicMedia => 'ግራፊክ ሚዲያ';

  @override
  String get contentLabelViolence => 'ብጥብጥ';

  @override
  String get contentLabelSelfHarm => 'ራስን መጉዳት/ ራስን ማጥፋት';

  @override
  String get contentLabelDrugUse => 'የመድሃኒት አጠቃቀም';

  @override
  String get contentLabelAlcohol => 'አልኮል';

  @override
  String get contentLabelTobacco => 'ትምባሆ/ማጨስ';

  @override
  String get contentLabelGambling => 'ቁማር';

  @override
  String get contentLabelProfanity => 'ስድብ';

  @override
  String get contentLabelHateSpeech => 'የጥላቻ ንግግር';

  @override
  String get contentLabelHarassment => 'ትንኮሳ';

  @override
  String get contentLabelFlashingLights => 'ብልጭ ድርግም የሚሉ መብራቶች';

  @override
  String get contentLabelAiGenerated => 'በAI የተፈጠረ';

  @override
  String get contentLabelDeepfake => 'ጥልቅ ሐሰት';

  @override
  String get contentLabelSpam => 'አይፈለጌ መልእክት';

  @override
  String get contentLabelScam => 'ማጭበርበር/ማጭበርበር';

  @override
  String get contentLabelSpoiler => 'ስፒለር';

  @override
  String get contentLabelMisleading => 'አሳሳች';

  @override
  String get contentLabelSensitiveContent => 'ሚስጥራዊነት ያለው ይዘት';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName ቪዲዮህን ወደውታል።';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName አስተያየትህን ወደውታል።';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName በቪዲዮዎ ላይ አስተያየት ሰጥቷል';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName አንተን መከተል ጀመረ';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName ጠቅሶሃል';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName ቪዲዮህን በድጋሚ ለጥፏል';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName አዲስ ቫይን ለጠፈ';
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
      other: '$count ቫይኖችህን',
      one: 'ቫይንህን',
    );
    return '$actorName $_temp0 ወደ $listName ጨምሯል';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName ለአስተያየትዎ ምላሽ ሰጥተዋል';
  }

  @override
  String get notificationAndConnector => 'እና';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ሌሎች',
      one: '$count ሌላ',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'አዲስ ማሻሻያ አለህ።';

  @override
  String get commentReplyToPrefix => 'ድጋሚ፡';

  @override
  String get commentHideKeyboard => 'የቁልፍ ሰሌዳውን ደብቅ';

  @override
  String get commentsErrorLoadFailed => 'አስተያየቶችን መጫን አልተሳካም';

  @override
  String get commentsErrorNotAuthenticatedComment => 'አስተያየት ለመስጠት እባክህ ግባ';

  @override
  String get commentsErrorPostCommentFailed => 'አስተያየቱን ማተም አልተሳካም';

  @override
  String get commentsErrorPostReplyFailed => 'ምላሹን ማተም አልተሳካም';

  @override
  String get commentsErrorEditFailed => 'አስተያየቱን ማረም አልተሳካም';

  @override
  String get commentsErrorNotAuthenticatedInteract => 'ለመሳተፍ እባክህ ግባ';

  @override
  String get commentsErrorVoteFailed => 'በአስተያየቱ ላይ መምረጥ አልተሳካም';

  @override
  String get commentsErrorReportFailed => 'አስተያየቱን ሪፖርት ማድረግ አልተሳካም';

  @override
  String get commentsErrorBlockFailed => 'ተጠቃሚውን ማገድ አልተሳካም';

  @override
  String get commentsErrorDeleteFailed => 'አስተያየቱን መሰረዝ አልተሳካም';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count አስተያየቶች',
      one: '$count አስተያየት',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'በመለጠፍ ላይ…';

  @override
  String get commentsVideoReplyPendingSemanticLabel => 'የቪዲዮ ምላሽዎ በመለጠፍ ላይ ነው';

  @override
  String get commentsSortNew => 'አዲስ';

  @override
  String get commentsSortTop => 'ከፍተኛ';

  @override
  String get commentsSortOld => 'አሮጌ';

  @override
  String get commentsSortSemanticLabel => 'የአስተያየቶች ቅደም ተከተል';

  @override
  String get commentReply => 'መልስ';

  @override
  String get commentReplySemanticLabel => 'ለአስተያየቱ መልስ ስጥ';

  @override
  String get commentUpvoteLabel => 'አስተያየቱን ደግፍ';

  @override
  String get commentRemoveUpvoteLabel => 'ድጋፉን አስወግድ';

  @override
  String get commentDownvoteLabel => 'አስተያየቱን ተቃወም';

  @override
  String get commentRemoveDownvoteLabel => 'ተቃውሞውን አስወግድ';

  @override
  String get commentsInputHint => 'አስተያየት አክል...';

  @override
  String get commentsInputHintEdit => 'አስተያየቱን አርም...';

  @override
  String get commentsEmptyTitle => 'እስካሁን አስተያየት የለም';

  @override
  String get commentsEmptySubtitle => 'ድግሱን ጀምር!';

  @override
  String get draftUntitled => 'ርዕስ አልባ';

  @override
  String get contentWarningNone => 'ምንም';

  @override
  String get textBackgroundNone => 'ምንም';

  @override
  String get textBackgroundSolid => 'ድፍን';

  @override
  String get textBackgroundHighlight => 'አድምቅ';

  @override
  String get textBackgroundTransparent => 'ግልጽ';

  @override
  String get textAlignLeft => 'ግራ';

  @override
  String get textAlignRight => 'ቀኝ';

  @override
  String get textAlignCenter => 'መሃል';

  @override
  String get cameraPermissionWebUnsupportedTitle => 'ካሜራ እስካሁን በድር ላይ አይደገፍም።';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'የካሜራ ቀረጻ እና ቀረጻ እስካሁን በድር ስሪት ውስጥ አይገኙም።';

  @override
  String get cameraPermissionBackToFeed => 'ወደ ምግብ ተመለስ';

  @override
  String get cameraCouldNotStart => 'ካሜራውን ማስጀመር አልተቻለም';

  @override
  String get cameraUnsupportedPlatform =>
      'ካሜራው በዚህ መድረክ ላይ ገና አይገኝም።\nአሁንም ቪዲዮዎችን ማሰስና መመልከት ይችላሉ።';

  @override
  String get cameraPermissionErrorTitle => 'የፍቃድ ስህተት';

  @override
  String get cameraPermissionErrorDescription =>
      'ፈቃዶችን በመፈተሽ ላይ ሳለ የሆነ ችግር ተፈጥሯል።';

  @override
  String get cameraPermissionRetry => 'እንደገና ይሞክሩ';

  @override
  String get cameraPermissionAllowAccessTitle => 'የካሜራ እና ማይክሮፎን መዳረሻ ፍቀድ';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'ይህ በመተግበሪያው ውስጥ ቪዲዮዎችን እንዲቀርጹ እና እንዲያርትዑ ይፈቅድልዎታል፣ ምንም ተጨማሪ ነገር የለም።';

  @override
  String get cameraPermissionGoToSettings => 'ወደ ቅንብሮች ይሂዱ';

  @override
  String get videoRecorderWhySixSecondsTitle => 'ለምን ስድስት ሰከንዶች?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'ፈጣን ቅንጥቦች ለድንገተኛነት ቦታ ይፈጥራሉ። የ6 ሰከንድ ቅርጸት ትክክለኛ ጊዜዎችን በሚከሰቱበት ጊዜ እንዲይዙ ያግዝዎታል።';

  @override
  String get videoRecorderWhySixSecondsButton => 'ገባኝ!';

  @override
  String get videoRecorderUploadTitle => 'ለምን መጫን የለም?';

  @override
  String get videoRecorderUploadBody =>
      'በዲቫይን ላይ የምታየው በሰው የተሰራ ነው፦ ጥሬ እና በወቅቱ የተቀረጸ። በከፍተኛ የተዘጋጁ ወይም በAI የተፈጠሩ ጭነቶችን የሚፈቅዱ መድረኮች በተለየ መልኩ፣ የቀጥታ ካሜራ ተሞክሮን ትክክለኛነት እናስቀድማለን።';

  @override
  String get videoRecorderUploadBodyDetail =>
      'ፍጠራን ከመተግበሪያው ውስጥ በማቆየት፣ ይዘቱ እውነተኛ እና ያልተስተካከለ መሆኑን በተሻለ ሁኔታ ልንዋስ እንችላለን። ያን እውነተኛነት ለመጠበቅና ማህበረሰባችንን በተቻለ መጠን ከሰው ሰራሽ ይዘት ነጻ ለማድረግ፣ በአሁኑ ጊዜ ከውጪ ጋለሪ መጫን አንፈቅድም።';

  @override
  String get videoRecorderUploadBodyCta =>
      'እውነተኛ ነገር ለመቅረጽ ወደ Capture ወይም Classic ቀይር።';

  @override
  String get videoRecorderUploadLearnMore => 'ማረጋገጫ እንዴት እንደሚሰራ ተማር';

  @override
  String get videoRecorderAutosaveFoundTitle => 'በሂደት ላይ ያለ ስራ አግኝተናል';

  @override
  String get videoRecorderAutosaveFoundSubtitle => 'ካቆሙበት መቀጠል ይፈልጋሉ?';

  @override
  String get videoRecorderAutosaveContinueButton => 'አዎ ቀጥል።';

  @override
  String get videoRecorderAutosaveDiscardButton => 'አይ፣ አዲስ ቪዲዮ ጀምር';

  @override
  String get videoRecorderAutosaveRestoreFailure => 'ረቂቅዎን ወደነበረበት መመለስ አልተቻለም';

  @override
  String get videoRecorderStopRecordingTooltip => 'መቅዳት አቁም';

  @override
  String get videoRecorderStartRecordingTooltip => 'መቅዳት ጀምር';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'መቅዳት. ለማቆም የትኛውም ቦታ ላይ መታ ያድርጉ';

  @override
  String get videoRecorderTapToStartLabel => 'መቅዳት ለመጀመር የትኛውም ቦታ ላይ መታ ያድርጉ';

  @override
  String get videoRecorderDeleteLastClipLabel => 'የመጨረሻውን ቅንጥብ ሰርዝ';

  @override
  String get videoRecorderSwitchCameraLabel => 'ካሜራ ቀይር';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'ወደ $zoom× አጉላ';
  }

  @override
  String get videoRecorderToggleGridLabel => 'ፍርግርግ ቀያይር';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'የGhost ፍሬም ሁኔታ ቀይር';

  @override
  String get videoRecorderGhostFrameEnabled => 'Ghost ፍሬም በርቷል';

  @override
  String get videoRecorderGhostFrameDisabled => 'Ghost ፍሬም ጠፍቷል';

  @override
  String get videoRecorderClipDeletedMessage => 'ክሊፕ ወደ መጣያ ተንቀሳቅሷል።';

  @override
  String get videoRecorderClipUndoLabel => 'ቀልብስ';

  @override
  String get libraryTrashEmptyTitle => 'መጣያው ባዶ ነው።';

  @override
  String get libraryTrashEmptySubtitle =>
      'የተሰረዙ ክሊፖች ለ30 ቀናት እዚህ ይቆያሉ ከዚያም በቋሚነት ይወገዳሉ።';

  @override
  String get libraryTrashRestoreLabel => 'መልስ';

  @override
  String get libraryTrashDeleteNowLabel => 'አሁን ሰርዝ';

  @override
  String get libraryTrashEmptyAllLabel => 'መጣያን ባዶ አድርግ';

  @override
  String get libraryTrashDeleteConfirmTitle => 'አሁኑኑ ክሊፑን ሰርዝ?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'ይህ ክሊፑን ከቆሻሻ መጣያው ወዲያውኑ ያስወግደዋል።';

  @override
  String get libraryTrashEmptyConfirmTitle => 'ቆሻሻ መጣያውን ባዶ አድርግ?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች',
      one: '$count ክሊፕ',
    );
    return '$_temp0 ከቆሻሻ መጣያው ወዲያውኑ በቋሚነት ይሰረዛሉ።';
  }

  @override
  String get videoRecorderCloseLabel => 'የቪዲዮ መቅረጫ ዝጋ';

  @override
  String get videoRecorderContinueToEditorLabel => 'ወደ ቪዲዮ አርታዒ ይቀጥሉ';

  @override
  String get videoRecorderCameraPreviewLabel => 'የካሜራ ቅድመ እይታ';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'ካሜራውን አተኩር';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'ወደ $mode ሁነታ ቀይር';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => 'ከመቅረጽ በፊት ኦዲዮ ያክሉ';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'ቪዲዮውን መፍጠር አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ፎቶዎች ቀርተዋል',
      one: '$count ፎቶ ቀርቷል',
      zero: 'ምንም የቀረ ፎቶ የለም',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'ብልጭታ ቀያይር';

  @override
  String get videoRecorderCycleTimerLabel => 'የዑደት ሰዓት ቆጣሪ';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'ምጥጥን ቀያይር';

  @override
  String get videoRecorderStabilizationLabel => 'ማረጋጊያ';

  @override
  String get videoRecorderStabilizationModeOff => 'ጠፍቷል';

  @override
  String get videoRecorderStabilizationModeStandard => 'መደበኛ';

  @override
  String get videoRecorderStabilizationModeCinematic => 'ሲኒማቲክ';

  @override
  String get videoRecorderStabilizationModeCinematicExtended => 'የተራዘመ ሲኒማቲክ';

  @override
  String get videoRecorderStabilizationModePreviewOptimized => 'ለቅድመ-እይታ የተመቻቸ';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'ዝቅተኛ መዘግየት';

  @override
  String get videoRecorderStabilizationModeAuto => 'ራስ-ሰር';

  @override
  String get videoRecorderFlashValueOff => 'ጠፍቷል';

  @override
  String get videoRecorderFlashValueOn => 'በርቷል';

  @override
  String get videoRecorderFlashValueAuto => 'ራስ-ሰር';

  @override
  String get videoRecorderTimerValueOff => 'ጠፍቷል';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 ሰከንድ';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 ሰከንድ';

  @override
  String get videoRecorderAspectRatioValueSquare => 'ካሬ';

  @override
  String get videoRecorderAspectRatioValueVertical => 'አቀባዊ';

  @override
  String get videoRecorderCameraValueFront => 'የፊት ካሜራ';

  @override
  String get videoRecorderCameraValueBack => 'የኋላ ካሜራ';

  @override
  String get videoRecorderLibraryEmptyLabel => 'ክሊፕ ቤተ-መጽሐፍት፣ ምንም ቅንጥቦች የሉም';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'የክሊፕ ቤተ-መዝገብ ክፈት፣ $clipCount ክሊፖች',
      one: 'የክሊፕ ቤተ-መዝገብ ክፈት፣ $clipCount ክሊፕ',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'የስቶፕ-ሞሽን ቤተ-መዝገብ ክፈት፣ $frameCount ፍሬሞች',
      one: 'የስቶፕ-ሞሽን ቤተ-መዝገብ ክፈት፣ $frameCount ፍሬም',
      zero: 'የስቶፕ-ሞሽን ቤተ-መዝገብ ክፈት',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'ካሜራ';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'ካሜራ ክፈት';

  @override
  String get videoEditorLibraryLabel => 'ቤተ መፃህፍት';

  @override
  String get videoEditorTextLabel => 'ጽሑፍ';

  @override
  String get videoEditorDrawLabel => 'ይሳሉ';

  @override
  String get videoEditorFilterLabel => 'አጣራ';

  @override
  String get videoEditorTuneLabel => 'አስተካክል';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'የማስተካከያ አርታዒን ክፈት';

  @override
  String get videoEditorTuneBrightness => 'ብሩህነት';

  @override
  String get videoEditorTuneContrast => 'ንፅፅር';

  @override
  String get videoEditorTuneSaturation => 'ሙሌት';

  @override
  String get videoEditorTuneExposure => 'ተጋላጭነት';

  @override
  String get videoEditorTuneHue => 'ቀለም';

  @override
  String get videoEditorTuneTemperature => 'ሙቀት';

  @override
  String get videoEditorTuneTint => 'ቲንት';

  @override
  String get videoEditorTuneFade => 'መደብዘዝ';

  @override
  String get videoEditorAudioLabel => 'ኦዲዮ';

  @override
  String get videoEditorAddTitle => 'አክል';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'ቤተ መፃህፍት ክፈት';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'የድምጽ አርታዒን ክፈት';

  @override
  String get videoEditorCaptionsLabel => 'የግርጌ ጽሑፎች';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'የግርጌ ጽሑፍ አርታዒን ክፈት';

  @override
  String get videoEditorCaptionsBurnInLabel => 'በቪዲዮ ውስጥ አስገባ';

  @override
  String get videoEditorCaptionsPresetCustom => 'ብጁ';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'ብጁ ቅጥ';

  @override
  String get videoEditorCaptionsCustomApply => 'ተግብር';

  @override
  String get videoEditorCaptionsCustomFont => 'ቅርጸ-ቁምፊ';

  @override
  String get videoEditorCaptionsCustomTextColor => 'የጽሑፍ ቀለም';

  @override
  String get videoEditorCaptionsCustomBackground => 'ዳራ';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'የዳራ ቀለም';

  @override
  String get videoEditorCaptionsCustomAnimation => 'እነማ';

  @override
  String get videoEditorCaptionsAnimationNone => 'የለም';

  @override
  String get videoEditorCaptionsAnimationFade => 'መደብዘዝ';

  @override
  String get videoEditorCaptionsAnimationPop => 'ፖፕ';

  @override
  String get videoEditorCaptionsAnimationSpring => 'ስፕሪንግ';

  @override
  String get videoEditorCaptionsEditTitle => 'የግርጌ ጽሑፎች';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'እያዳመጥን ነው…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'ድምጽህን ወደ የግርጌ ጽሑፍ ሐሳቦች እየቀየርን ነው።';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'ምንም ንግግር አልሰማንም። አሁንም የግርጌ ጽሑፎቹን ራስህ መጻፍ ትችላለህ።';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'በዚህ መሣሪያ ላይ የንግግር ማወቂያ አይገኝም። የግርጌ ጽሑፎቹን ራስህ መጻፍ ትችላለህ።';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'የንግግር ማወቂያ አልተፈቀደም። በቅንብሮች ውስጥ አብራው ወይም የግርጌ ጽሑፎቹን ራስህ ጻፍ።';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'ወደ ጽሑፍ መቀየሩ በዚህ ጊዜ አልሰራም። የግርጌ ጽሑፎቹን ራስህ መጻፍ ትችላለህ።';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'የግርጌ ጽሑፎቹን ራሴ እጽፋለሁ';

  @override
  String get videoEditorCaptionsAddCue => 'የግርጌ ጽሑፍ ጨምር';

  @override
  String get videoEditorCaptionsCueTextHint => 'የግርጌ ጽሑፍ';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'የግርጌ ጽሑፉን ሰርዝ';

  @override
  String get videoEditorCaptionsDeleteTrack => 'ሁሉንም የግርጌ ጽሑፎች አስወግድ';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => 'የግርጌ ጽሑፎቹ ይወገዱ?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'ሁሉም ጽሑፍ እና ጊዜዎች ይጠፋሉ።';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => 'የግርጌ ጽሑፍ አርታዒን ዝጋ';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'የግርጌ ጽሑፎችን አረጋግጥ';

  @override
  String get videoEditorCaptionsPresetTitle => 'የግርጌ ጽሑፍ ቅጥ';

  @override
  String get videoEditorCaptionsPresetClassic => 'ክላሲክ';

  @override
  String get videoEditorCaptionsPresetPop => 'ፖፕ';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'ስፕሪንግ';

  @override
  String get videoEditorCaptionsPresetMono => 'ሞኖ';

  @override
  String get videoEditorCaptionsPresetHeadline => 'አርዕስት';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'የጽሕፈት መኪና';

  @override
  String get videoEditorCaptionsPresetMarker => 'ማርከር';

  @override
  String get videoEditorCaptionsPresetScript => 'ካሊግራፊ';

  @override
  String get videoEditorCaptionsPresetRetro => 'ሬትሮ';

  @override
  String get videoEditorCaptionsPresetElegant => 'ቄንጠኛ';

  @override
  String get videoEditorCaptionsPresetBubble => 'አረፋ';

  @override
  String get videoEditorCaptionsPresetNeon => 'ኒዮን';

  @override
  String get videoEditorCaptionsPresetBold => 'ደማቅ';

  @override
  String get videoEditorCaptionsPresetDreamy => 'ህልማዊ';

  @override
  String get videoEditorCaptionsPresetOcean => 'ውቅያኖስ';

  @override
  String get videoEditorCaptionsPresetSunny => 'ፀሐያማ';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'የእጅ ጽሑፍ';

  @override
  String get videoEditorCaptionsPresetSerif => 'ሴሪፍ';

  @override
  String get videoEditorCaptionsPresetStamp => 'ማህተም';

  @override
  String get videoEditorOpenTextSemanticLabel => 'የጽሑፍ አርታዒን ክፈት';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'የስዕል አርታዒን ክፈት';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'የማጣሪያ አርታዒን ክፈት';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'ተለጣፊ አርታዒን ክፈት';

  @override
  String get videoEditorSaveDraftTitle => 'ረቂቅዎን ይቆጥቡ?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'አርትዖቶችዎን ለበለጠ ጊዜ ያቆዩት ወይም ያስወግዱዋቸው እና አርታዒውን ይተዉት።';

  @override
  String get videoEditorSaveDraftButton => 'ረቂቅ አስቀምጥ';

  @override
  String get videoEditorDiscardChangesButton => 'ለውጦችን አስወግድ';

  @override
  String get videoEditorKeepEditingButton => 'ማረምዎን ይቀጥሉ';

  @override
  String get videoEditorDeleteLayerDropZone => 'የንብርብር ጠብታ ዞን ሰርዝ';

  @override
  String get videoEditorReleaseToDeleteLayer => 'ንብርብር ለመሰረዝ ይልቀቁ';

  @override
  String get videoEditorDoneLabel => 'ተከናውኗል';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'ቪዲዮን ያጫውቱ ወይም ለአፍታ ያቁሙ';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'የመክፈል ቦታው ልክ አይደለም። ሁለቱም ክሊፖች ቢያንስ ${minDurationMs}ms ርዝመት ሊኖራቸው ይገባል።';
  }

  @override
  String get videoEditorSaveSelectedClip => 'የተመረጠውን ቅንጥብ ያስቀምጡ';

  @override
  String get videoEditorSaveClip => 'ቅንጥብ ያስቀምጡ';

  @override
  String get videoEditorClipSavedSuccess => 'ክሊፕ ወደ ቤተ-መጽሐፍት ተቀምጧል';

  @override
  String get videoEditorClipSaveFailed => 'ቅንጥብ ማስቀመጥ አልተሳካም።';

  @override
  String get videoEditorColorPickerSemanticLabel => 'ቀለም መራጭ';

  @override
  String get videoEditorUndoSemanticLabel => 'ቀልብስ';

  @override
  String get videoEditorRedoSemanticLabel => 'ድገም';

  @override
  String get videoEditorTextColorSemanticLabel => 'የጽሑፍ ቀለም';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'የጽሑፍ አሰላለፍ';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'የጽሑፍ ዳራ';

  @override
  String get videoEditorFontSemanticLabel => 'ቅርጸ-ቁምፊ';

  @override
  String get videoEditorNoStickersFound => 'ምንም ተለጣፊዎች አልተገኙም።';

  @override
  String get videoEditorNoStickersAvailable => 'ምንም ተለጣፊዎች አይገኙም።';

  @override
  String get videoEditorFailedLoadStickers => 'ተለጣፊዎችን መጫን አልተሳካም።';

  @override
  String get videoEditorVoiceOverLabel => 'የድምፅ ትረካ';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'ቅረጻ $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'የድምፅ ትረካ ቅዳ';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'ቅረጻ ጀምር';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'ቅረጻ አቁም';

  @override
  String get videoEditorVoiceOverHint => 'ለመቅዳት ንካ። የፈለግከውን ያህል ቅረጻዎች አክል።';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ቅረጻዎች',
      one: '$count ቅረጻ',
      zero: 'እስካሁን ቅረጻ የለም',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'የመጨረሻውን ቅረጻ ሰርዝ';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'የማይክሮፎን መዳረሻ ያስፈልጋል';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'የድምፅ ትረካ ለመቅዳት የማይክሮፎን መዳረሻ ፍቀድ።';

  @override
  String get videoEditorVoiceOverOpenSettings => 'ቅንብሮችን ክፈት';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'ቅረጻ ተጀመረ';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'ቅረጻ ተቀምጧል';

  @override
  String get videoEditorVoiceOverTooLong => 'ቅረጻው ከቪዲዮዎ ይረዝማል';

  @override
  String get videoEditorPlaySemanticLabel => 'ይጫወቱ';

  @override
  String get videoEditorPauseSemanticLabel => 'ለአፍታ አቁም';

  @override
  String get videoEditorVolumeSemanticLabel => 'ድምጽ አስተካክል';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'ድምጽ $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'ለማስተካከል ያንሸራትቱ';

  @override
  String get videoEditorChromaKeyLabel => 'አረንጓዴ ስክሪን';

  @override
  String get videoEditorChromaKeyTitle => 'አረንጓዴ ስክሪን';

  @override
  String get videoEditorChromaKeySemanticLabel => 'ለዚህ ቅንጥብ አረንጓዴ ስክሪን አዘጋጅ';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel => 'የአረንጓዴ ስክሪን ለውጦችን ተው';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'አረንጓዴ ስክሪኑን ተግብር';

  @override
  String get videoEditorChromaKeyAutoDetect => 'በራስ-ሰር ለይ';

  @override
  String get videoEditorChromaKeyPresetGreen => 'አረንጓዴ';

  @override
  String get videoEditorChromaKeyPresetBlue => 'ሰማያዊ';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'የስክሪኑ ቀለም';

  @override
  String get videoEditorChromaKeyAmountLabel => 'መጠን';

  @override
  String get videoEditorChromaKeyAmountHint => 'ከስክሪኑ ቀለም ምን ያህል እንደሚጠፋ';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'ጠርዝ';

  @override
  String get videoEditorChromaKeyEdgeHint => 'ፀጉር እንዳይሸበሸብ መቁረጡን ያለሰልሳል';

  @override
  String get videoEditorChromaKeySpillLabel => 'ቀለም መፍሰስ';

  @override
  String get videoEditorChromaKeySpillHint => 'የስክሪኑን ቀለም ከሰውዬው ላይ ያነሳል';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'በዚህ ተካ';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'ምንም';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'ቀለም';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'ምስል';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'ቅንጥብ';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'ቪዲዮ ግልጽነት መያዝ አይችልም፣ ስለዚህ ሲወጣ ጥቁር ይሆናል።';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'ስክሪን አልተገኘም። እስከ ፍሬሙ ጠርዝ መድረስ አለበት — ካልሆነ ቀለሙን በእጅ ምረጥ።';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'ቅንጥብ ምረጥ';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'ቤተ-መጻሕፍትህ ባዶ ነው። መጀመሪያ ቅንጥብ አስቀምጥ፣ ከዚያ እንደ ዳራ ተጠቀምበት።';

  @override
  String get videoEditorChromaKeyImagePickFailed => 'ያንን ምስል መጫን አልተቻለም።';

  @override
  String get videoEditorChromaKeyRemove => 'አረንጓዴ ስክሪኑን አስወግድ';

  @override
  String get videoEditorChromaKeyFailed =>
      'አረንጓዴ ስክሪኑን መተግበር አልተቻለም። ቅንጥብህ ሳይለወጥ ይቆያል።';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'አረንጓዴ ስክሪኑን ማስወገድ አልተቻለም። ቅንጥብህ ሳይለወጥ ይቆያል።';

  @override
  String get videoEditorChromaKeyApplying => 'አረንጓዴ ስክሪን እየተተገበረ ነው…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'ይህ መሣሪያ ቀጥታ ቅድመ-እይታን ማሳየት አይችልም። ቅንብሮችህ ግን ወደ ውጭ ሲወጣ ይሠራሉ።';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'ቅንጥብ $index';
  }

  @override
  String get videoEditorDeleteLabel => 'ሰርዝ';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => 'የተመረጠውን ንጥል ሰርዝ';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'በአንድ ምስል ፍሬሞች';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ፍሬሞች',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'ፍሬሞች';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return 'በአንድ ምስል $count ፍሬሞች';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'የስቶፕ-ሞሽን ፍሬም $position ከ$total';
  }

  @override
  String get videoEditorEditLabel => 'አርትዕ';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'የተመረጠውን ንጥል ያርትዑ';

  @override
  String get videoEditorDuplicateLabel => 'ማባዛት።';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel => 'የተመረጠውን ንጥል ያባዛ';

  @override
  String get videoEditorCombineLabel => 'አዋህድ';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'የተመረጡ ስዕሎችን ወደ አንድ ንብርብር አዋህድ';

  @override
  String get videoEditorSplitLabel => 'ተከፈለ';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'የተመረጠውን ቅንጥብ ክፈል።';

  @override
  String get videoEditorExtractAudioLabel => 'ኦዲዮ ያውጡ';

  @override
  String get videoEditorClipAudioTitle => 'ክሊፕ ኦዲዮ';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'ከቅንጥብ ኦዲዮ ያውጡ እና ኦሪጅናሉን ያጥፉ';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'ድምፅ ማዎጣት አልተቻለም፤ ቅንጥቡ በሀገር ዉስጥ አይገኝም።';

  @override
  String get videoEditorExtractAudioFailed => 'ድምፅ ማዎጣት አልተቻለም። እንደገና ሞክር።';

  @override
  String get videoEditorSpeedLabel => 'ፍጥነት';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'ለተመረጠው ክሊፕ የማጫወቻ ፍጥነት ያዘጋጁ';

  @override
  String get videoEditorReverseLabel => 'ወደ ኋላ';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'ለተመረጠው ክሊፕ የኋላ ወደ ፊት ማጫወቻ ቀይር';

  @override
  String get videoEditorReverseProgressLabel =>
      'አንድ ትንሽ ቆይ፣ ክሊፕዎን ወደ ኋላ እየቀየርን ነው';

  @override
  String get videoEditorTransformLabel => 'መለወጥ';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'የተመረጠውን ክሊፕ ይከርክሙ፣ ያሽከርክሩ ወይም ይገልብጡ';

  @override
  String get videoEditorTransformProgressLabel => 'አንድ አፍታ፣ ክሊፕዎን እያስተካከልን ነው';

  @override
  String get videoEditorTransformFailed => 'ክሊፑን መለወጥ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get videoEditorTransformNoLocalFile => 'መለወጥ አይቻልም፦ ክሊፑ በአካባቢው አይገኝም።';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'የተመረጠውን ፍሬም ቁረጥ፣ አሽከርክር ወይም ገልብጥ';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'ትንሽ ይቆዩ፣ ፍሬምዎን እየለወጥን ነው';

  @override
  String get videoEditorTransformFrameFailed =>
      'ፍሬሙን መለወጥ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get videoEditorTransformRotateLabel => 'አሽከርክር';

  @override
  String get videoEditorTransformFlipLabel => 'ግልብጥ';

  @override
  String get videoEditorTransformResetLabel => 'ዳግም አስጀምር';

  @override
  String get videoEditorTransformApplySemanticLabel => 'ለውጥን ተግብር';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'ለውጥን ሰርዝ';

  @override
  String get videoEditorTransformPlayLabel => 'አጫውት';

  @override
  String get videoEditorTransformPauseLabel => 'ለአፍታ አቁም';

  @override
  String get videoEditorReverseNoLocalFile =>
      'ወደ ኋላ መቀየር አልተቻለም፤ ቅንጥቡ በሀገር ዉስጥ አይገኝም።';

  @override
  String get videoEditorReverseFailed => 'ቅንጥቡን ወደ ኋላ መቀየር አልተቻለም። እንደገና ሞክር።';

  @override
  String get videoEditorSpeedSheetTitle => 'የክሊፕ ፍጥነት';

  @override
  String get videoEditorTransitionSheetTitle => 'ሽግግር';

  @override
  String get videoEditorTransitionNone => 'ምንም';

  @override
  String get videoEditorTransitionDissolve => 'መሟሟት';

  @override
  String get videoEditorTransitionFadeToBlack => 'ወደ ጥቁር መደብዘዝ';

  @override
  String get videoEditorTransitionFadeToWhite => 'ወደ ነጭ መደብዘዝ';

  @override
  String get videoEditorTransitionSlide => 'ማንሸራተት';

  @override
  String get videoEditorTransitionPush => 'መግፋት';

  @override
  String get videoEditorTransitionWipe => 'ማበስ';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'ሽግግርን አርትዕ';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'የዙር ሽግግር';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel => 'የዙር ሽግግርን አርትዕ';

  @override
  String get videoEditorTransitionDuration => 'ቆይታ';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'በአጎራባች ሽግግር ላይ እንዳይደራረብ ተቀንሷል።';

  @override
  String get videoEditorTransitionCurve => 'ኩርባ';

  @override
  String get videoEditorTransitionDirection => 'አቅጣጫ';

  @override
  String get videoEditorTransitionDirectionLeft => 'ግራ';

  @override
  String get videoEditorTransitionDirectionRight => 'ቀኝ';

  @override
  String get videoEditorTransitionDirectionUp => 'ላይ';

  @override
  String get videoEditorTransitionDirectionDown => 'ታች';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'የአኒሜሽን ከርቭ $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'እነማ';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel => 'የንብርብር እነማ አርትዕ';

  @override
  String get videoEditorLayerAnimationEnter => 'መግቢያ';

  @override
  String get videoEditorLayerAnimationLeave => 'መውጫ';

  @override
  String get videoEditorLayerAnimationFade => 'ፌድ';

  @override
  String get videoEditorLayerAnimationScale => 'መጠን';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'ከመጠን';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'የጊዜ መስመር አርትዖትን ጨርስ';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'ቅድመ እይታን አጫውት።';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'ቅድመ እይታን ባለበት አቁም';

  @override
  String get videoEditorAudioUntitledSound => 'ርዕስ አልባ ድምጽ';

  @override
  String get videoEditorAudioUntitled => 'ርዕስ አልባ';

  @override
  String get videoEditorAudioAddAudio => 'ኦዲዮ ያክሉ';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'ምንም ድምፆች የሉም';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'ፈጣሪዎች ኦዲዮን ሲያጋሩ ድምጾች እዚህ ይታያሉ';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'ድምጾችን መጫን አልተሳካም።';

  @override
  String get videoEditorAudioSegmentInstruction => 'ለቪዲዮዎ የድምጽ ክፍሉን ይምረጡ';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'ማህበረሰብ';

  @override
  String get videoEditorAudioCategoryFeatured => 'ተለይቶ የቀረበ';

  @override
  String get videoEditorAudioCategoryMySounds => 'የእኔ ድምፆች';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'የቀስት መሣሪያ';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'መጥረጊያ መሳሪያ';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'ምልክት ማድረጊያ መሳሪያ';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'የእርሳስ መሳሪያ';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'የጊዜ መስመር አሳይ';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'የጊዜ መስመርን ደብቅ';

  @override
  String get videoEditorFeedPreviewContent =>
      'ከእነዚህ አካባቢዎች በስተጀርባ ይዘትን ከማስቀመጥ ተቆጠብ።';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine ኦሪጅናል';

  @override
  String get videoEditorStickerSearchHint => 'ተለጣፊዎችን ፈልግ...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'ቅርጸ-ቁምፊ ይምረጡ';

  @override
  String get videoEditorFontUnknown => 'ያልታወቀ';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'የመጫወቻ ቦታ ለመከፋፈል በተመረጠው ቅንጥብ ውስጥ መሆን አለበት።';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'ጅምር ይከርክሙ';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'መጨረሻውን ይከርክሙ';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'ቅንጥብ ይከርክሙ';

  @override
  String get videoEditorTimelineTrimClipHint => 'የቅንጥብ ቆይታ ለማስተካከል መያዣዎችን ይጎትቱ';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'ቅንጥብ መጎተት $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'የ$index የ$total፣ $duration ሴኮንዶች ቅንጥብ';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'እንደገና ለመደርደር በረጅሙ ተጫን';

  @override
  String get videoEditorTimelineClipMoveLeft => 'ወደ ግራ ውሰድ';

  @override
  String get videoEditorTimelineClipMoveRight => 'ወደ ቀኝ አንቀሳቅስ';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'ቅንጥብ $index ከ $total፣ ተመርጧል';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'ቅንጥብ $index ከ $total፣ አልተመረጠም';
  }

  @override
  String get videoEditorMultiSelectLabel => 'ምረጥ';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'ብዙ ቅንጥቦችን ምረጥ';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'ምርጫን ጨርስ';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ቅንጥቦች ተመርጠዋል',
      one: '$count ቅንጥብ ተመርጧል',
      zero: 'ምንም ቅንጥብ አልተመረጠም',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel => 'ብዙ ስዕሎችን ይምረጡ';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel => 'ስዕሎችን መምረጥ ጨርስ';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'የተመረጡ ስዕሎችን ሰርዝ';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ስዕሎች ተመርጠዋል',
      one: '$count ስዕል ተመርጧል',
      zero: 'ምንም ስዕል አልተመረጠም',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'አዋህድ';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel => 'የተመረጡ ቅንጥቦችን አዋህድ';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel => 'የተመረጡ ቅንጥቦችን ሰርዝ';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel => 'የተመረጡ ፍሬሞችን ሰርዝ';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'የተመረጡ ፍሬሞችን አገላብጥ';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'የተመረጡ ፍሬሞችን ያባዛ';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'ቪዲዮው ቢያንስ $seconds ሰከንድ መሆን አለበት — ጥቂት ተጨማሪ ፍሬሞችን ያንሱ።';
  }

  @override
  String get videoEditorMergeProgressLabel => 'ትንሽ ይቆዩ፣ ቅንጥቦችዎን እያዋሃድን ነው';

  @override
  String get videoEditorMergeFailed => 'ቅንጥቦችን ማዋሃድ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get videoEditorTimelineLongPressToDragHint => 'ለመጎተት በረጅሙ ተጫን';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'የቪዲዮ የጊዜ መስመር';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName፣ ተመርጧል';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'የቀለም መራጭን ይዝጉ';

  @override
  String get videoEditorPickColorTitle => 'ቀለም ይምረጡ';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'ቀለም ያረጋግጡ';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => 'ሙሌት እና ብሩህነት';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'ሙሌት $saturation%፣ ብሩህነት $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'ሁ';

  @override
  String get videoEditorAddElementSemanticLabel => 'ኤለመንት አክል';

  @override
  String get videoEditorDoneSemanticLabel => 'ተከናውኗል';

  @override
  String get videoEditorLevelSemanticLabel => 'ደረጃ';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel => 'የልጥፍ ዝርዝሮችን ዝጋ';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => 'የእገዛ ንግግርን አሰናብት';

  @override
  String get videoMetadataGotItButton => 'ገባኝ!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB ገደብ ላይ ደርሷል። ለመቀጠል አንዳንድ ይዘቶችን ያስወግዱ።';

  @override
  String get videoMetadataExpirationLabel => 'የማለቂያ ጊዜ';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => 'የማለቂያ ጊዜን ይምረጡ';

  @override
  String get videoMetadataTitleLabel => 'ርዕስ';

  @override
  String get videoMetadataDescriptionLabel => 'መግለጫ';

  @override
  String get videoMetadataTagsLabel => 'መለያዎች';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'መለያን ሰርዝ $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'የይዘት ማስጠንቀቂያ';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'የይዘት ማስጠንቀቂያዎችን ይምረጡ';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'በይዘትህ ላይ የሚመለከተውን ሁሉ ምረጥ';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'ሌሎች የዚህን ቪዲዮ ድምፅ እንዲያስቀምጡ እና እንደገና እንዲጠቀሙ ፍቀድ።';

  @override
  String get publishAudioReuseDegradedWarning =>
      'ቪዲዮህ ወጥቷል፣ ነገር ግን ድምፁ አልታተመም። ለማጋራት ቪዲዮውን አርም።';

  @override
  String get videoMetadataCollaboratorsLabel => 'ተባባሪዎች';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'ተባባሪ ጋብዝ';

  @override
  String get videoMetadataMutualFollowersSearchText => 'የጋራ ተከታዮች';

  @override
  String get videoMetadataInspiredByLabel => 'ተመስጦ';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'ተመስጦ የተዘጋጀ';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'ይህ ፈጣሪ ሊጠቀስ አይችልም።';

  @override
  String get videoMetadataPostDetailsTitle => 'ዝርዝሮችን ይለጥፉ';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'ወደ ቤተ-መጽሐፍት ተቀምጧል';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'ማስቀመጥ አልተሳካም።';

  @override
  String get videoMetadataGoToLibraryButton => 'ወደ ቤተ-መጽሐፍት ሂድ';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'ለበኋላ አዝራር አስቀምጥ';

  @override
  String get videoMetadataSavingVideoHint => 'ቪዲዮ በማስቀመጥ ላይ...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'ቪዲዮን ወደ ረቂቆች እና $destination አስቀምጥ';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'ቪዲዮውን ወደ ረቂቆች አስቀምጥ። ገና የተዘጋጀ ቪዲዮ ስለሌለ ወደ $destination ቅጂ አይታከልም።';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'በኋላ ላይ አስቀምጥ';

  @override
  String get videoMetadataPostSemanticLabel => 'የመለጠፍ ቁልፍ';

  @override
  String get videoMetadataPublishVideoHint => 'ለመመገብ ቪዲዮ ያትሙ';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'በፊዴ ላይም አጋራ';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'ሲጠፋ ይህ ቪዲዮ በአስተያየት ክር ውስጥ ብቻ ይቀራል።';

  @override
  String get videoMetadataFormNotReadyHint => 'ለማንቃት ቅጹን ይሙሉ';

  @override
  String get videoMetadataPostButton => 'ለጥፍ';

  @override
  String get videoMetadataOpenPreviewSemanticLabel => 'የልጥፍ ቅድመ እይታ ማያን ክፈት';

  @override
  String get videoMetadataShareTitle => 'አጋራ';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'የቪዲዮ ዝርዝሮች';

  @override
  String get videoMetadataClassicDoneButton => 'ተከናውኗል';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'ቅድመ እይታን አጫውት።';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'ቅድመ እይታን ባለበት አቁም';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'የቪዲዮ ቅድመ እይታን ዝጋ';

  @override
  String get videoMetadataRemoveSemanticLabel => 'አስወግድ';

  @override
  String get fullscreenFeedRemovedMessage => 'ቪዲዮ ተወግዷል';

  @override
  String get fullscreenFeedEmptyMessage => 'እዚህ የሚጫወት ምንም አልቀረም';

  @override
  String get settingsBadgesTitle => 'ባጆች';

  @override
  String get settingsBadgesSubtitle => 'ሽልማቶችን ተቀበል እና የተሰጡ ባጆችን ሁኔታ ተመልከት።';

  @override
  String get badgesTitle => 'ባጆች';

  @override
  String get badgesLoadError => 'ባጆችን መጫን አልተቻለም';

  @override
  String get badgesUpdateError => 'ባጅን ማዘመን አልተቻለም';

  @override
  String get badgesAwardedEmptyTitle => 'እስካሁን ምንም የባጅ ሽልማት የለም';

  @override
  String get badgesAwardedEmptySubtitle => 'አንድ ሰው የNostr ባጅ ሲሸልምህ፣ እዚህ ይታያል።';

  @override
  String get badgesStatusAccepted => 'ተቀብሏል';

  @override
  String get badgesStatusNotAccepted => 'አልተቀበለም';

  @override
  String get badgesActionRemove => 'አስወግድ';

  @override
  String get badgesActionAccept => 'ተቀበል';

  @override
  String get badgesActionReject => 'አትቀበል';

  @override
  String get badgesIssuedEmptyTitle => 'እስካሁን ምንም የተሰጡ ባጆች የሉም';

  @override
  String get badgesIssuedEmptySubtitle => 'የምትሰጣቸው ባጆች የመቀበል ሁኔታቸውን እዚህ ያሳያሉ።';

  @override
  String get badgesIssuedNoRecipients => 'ለዚህ ሽልማት ምንም ተቀባዮች አልተገኙም።';

  @override
  String get badgesRecipientAcceptedStatus => 'ተቀባዩ ተቀብሎታል';

  @override
  String get badgesRecipientWaitingStatus => 'ተቀባይን በመጠባበቅ ላይ';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'የተደበቁ ($count)',
      one: 'የተደበቀ ($count)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'መልስ';

  @override
  String get badgesHiddenSnackbar => 'ባጁ ተደብቋል';

  @override
  String get badgesHiddenSnackbarUndo => 'ቀልብስ';

  @override
  String get badgesTabAwarded => 'የተቀበልካቸው';

  @override
  String get badgesTabCreated => 'የፈጠርካቸው';

  @override
  String get badgesTabIssued => 'የሰጠሃቸው';

  @override
  String get badgesCreateAction => 'አዲስ ባጅ';

  @override
  String get badgesCreatedEmptyTitle => 'እስካሁን ባጅ አልሠራህም';

  @override
  String get badgesCreatedEmptySubtitle => 'አንድ ሥራና ለሚገባው ሰው ስጠው።';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ለ$count ሰዎች ተሰጥቷል',
      one: 'ለ$count ሰው ተሰጥቷል',
      zero: 'እስካሁን አልተሰጠም',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'አዲስ ባጅ';

  @override
  String get badgeEditorEditTitle => 'ባጅ አርትዕ';

  @override
  String get badgeEditorNameLabel => 'ስም';

  @override
  String get badgeEditorNameHint => 'ትዕይንት ሰርቆ';

  @override
  String get badgeEditorIdentifierLabel => 'መለያ';

  @override
  String get badgeEditorIdentifierHelp =>
      'የባጁ አድራሻ አካል ነው፤ ስለዚህ ባጁ ከተፈጠረ በኋላ አይለወጥም።';

  @override
  String get badgeEditorIdentifierTaken =>
      'በዚህ መለያ ያለህ ባጅ አስቀድሞ አለ። እዚህ ማተም እሱን ስለሚተካ ያንን አርትዕ አድርግ።';

  @override
  String get badgeEditorIdentifierRequired =>
      'እያንዳንዱ ባጅ መለያ ያስፈልገዋል — ስሙ ካልሞላው በእጅ ጻፍ።';

  @override
  String get badgeEditorDescriptionLabel => 'መግለጫ';

  @override
  String get badgeEditorDescriptionHint => 'በአንድ ሉፕ ብቻ ትዕይንቱን ለሚሰርቀው።';

  @override
  String get badgeEditorArtworkLabel => 'ሥዕል';

  @override
  String get badgeEditorArtworkAdd => 'ሥዕል ጨምር';

  @override
  String get badgeEditorArtworkReplace => 'ተካ';

  @override
  String get badgeEditorArtworkError => 'ያንን ምስል መጫን አልተቻለም';

  @override
  String get badgeEditorArtworkRequired => 'እያንዳንዱ ባጅ ሥዕል ያስፈልገዋል።';

  @override
  String get badgeEditorArtworkRemove => 'ሥዕሉን አስወግድ';

  @override
  String get badgeEditorArtworkSheetTitle => 'የባጅ ሥዕል';

  @override
  String get badgeDetailDeleteAction => 'ባጅ ሰርዝ';

  @override
  String get badgeDetailDeleteTitle => 'ይህን ባጅ ልሰርዘው?';

  @override
  String get badgeDetailDeleteBody =>
      'ይህ ሪሌዮች ባጁንና የሰጠሃቸውን ሁሉንም ሽልማቶች እንዲያስወግዱ ይጠይቃል። ሪሌዮች ሊከለክሉ ይችላሉ፣ በመገለጫቸው ላይ የሰኩትም እስኪያስወግዱት ድረስ ይይዙታል።';

  @override
  String get badgeDetailDeleteConfirm => 'ሰርዝ';

  @override
  String get badgeEditorSaveAction => 'ባጁን አትም';

  @override
  String get badgeEditorSaveError => 'ባጁን ማተም አልተቻለም';

  @override
  String get badgeEditorLoadError => 'ይህን ባጅ መጫን አልተቻለም';

  @override
  String get badgeDetailTitle => 'ባጅ';

  @override
  String get badgeDetailMadeBy => 'የሠራው';

  @override
  String get badgeDetailRecipientsTitle => 'የተሰጠው ለ';

  @override
  String get badgeDetailNoRecipients => 'እስካሁን ማንም የለውም።';

  @override
  String get badgeDetailAwardAction => 'ይህን ባጅ ስጥ';

  @override
  String get badgeDetailEditAction => 'ባጅ አርትዕ';

  @override
  String get badgeDetailShareAction => 'አጋራ';

  @override
  String badgeDetailShareMessage(String link) {
    return 'ይህን ባጅ በDivine ተመልከት፦ $link';
  }

  @override
  String get badgeDetailRevokeAction => 'ባጁን መልስ';

  @override
  String get badgeDetailRevokeTitle => 'ይህን ባጅ ትመልሰዋለህ?';

  @override
  String get badgeDetailRevokeBody =>
      'ይህ ሪሌዮች ለዚህ ሰው የሰጠኸውን ሽልማት እንዲያስወግዱ ይጠይቃል። ሪሌዮች ሊከለክሉ ይችላሉ፣ ባጁን በመገለጫቸው ላይ ሰክተውት ከሆነም እስኪያስወግዱት ድረስ እዚያው ይቆያል። ለማንኛውም አይነገራቸውም።';

  @override
  String get badgeDetailRevokeSelfBody =>
      'ይህ ሪሌዮች ለራስህ የሰጠኸውን ሽልማት እንዲያስወግዱ ይጠይቃል፣ ባጁንም ከመገለጫህ ላይ ያነሳል። ሪሌዮቹ ስረዛውን ካልተቀበሉት ምንም አይለወጥም።';

  @override
  String get badgeDetailRevokeConfirm => 'መልስ';

  @override
  String get badgeDetailRevokeSuccess => 'ባጁ ተመልሷል';

  @override
  String get badgeDetailBlockClaimantsAction => 'የባጅ ጠያቂዎችን አግድ';

  @override
  String get badgeDetailBlockClaimantsTitle => 'የባጅ ጠያቂዎችን አግድ';

  @override
  String get badgeDetailBlockClaimantsLoadError => 'ይህን ባጅ የጠየቁትን መጫን አልተቻለም';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle => 'አሁን ይህን ባጅ የጠየቀ የለም';

  @override
  String get badgeDetailBlockClaimantsEmptyBody => 'ለማገድ የአሁን ጠያቂዎችን አላገኘንም።';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count መለያዎች ይታገዱ?',
      one: '$count መለያ ይታገድ?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ይህ አሁን ይህን ባጅ የጠየቁትን $count መለያዎች ያግዳል። ፖስቶቻቸው ከፊዶችህ ይጠፋሉ፣ ማሳወቂያም አይደርሳቸውም።',
      one: 'ይህ አሁን ይህን ባጅ የጠየቀውን መለያ ያግዳል። ፖስቶቹ ከፊዶችህ ይጠፋሉ፣ ማሳወቂያም አይደርሰውም።',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count መለያዎች አግድ',
      one: '$count መለያ አግድ',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'የባጅ ጠያቂዎች ታግደዋል';

  @override
  String get badgeDetailBlockClaimantsFailure => 'የባጅ ጠያቂዎችን ማገድ አልተቻለም';

  @override
  String get badgeDetailLoadError => 'ይህን ባጅ መጫን አልተቻለም';

  @override
  String get badgeDetailMissing => 'ይህን ባጅ በየትኛውም ሪሌይ ላይ አላገኘነውም።';

  @override
  String get badgeDetailActionError => 'አልተሳካም';

  @override
  String get badgeAwardTitle => 'ባጅ ስጥ';

  @override
  String get badgeAwardPickAction => 'ሰዎችን ምረጥ';

  @override
  String get badgeAwardManualLabel => 'ወይም ቁልፎችን ለጥፍ';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'ቢያንስ አንድ ሰው ምረጥ።';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ለ$count ሰዎች ስጥ',
      one: 'ለ$count ሰው ስጥ',
      zero: 'ባጅ ስጥ',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'የሰጠው';

  @override
  String get profileBadgeRecipients => 'ተቀባዮች';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count ተጨማሪ';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name ባጅ';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'ባጅ';

  @override
  String get profileBadgeFooterBody =>
      'ባጆች በNostr ላይ ማንኛውም ሰው መፍጠር የሚችላቸው ትንንሽ ሽልማቶች ናቸው። ለጓደኛ፣ ለፈጣሪ ወይም ቀንህን ላሳመረልህ ሰው አንዷን ስጥ።';

  @override
  String get profileBadgeFooterLink => 'የራስህን ባጅ ሥራ';

  @override
  String get minorAccountReviewWelcomePageTitle => 'የቤተሰብ መመሪያ';

  @override
  String get minorAccountReviewWelcomeTitle => 'እስካሁን 16 አልሞላህም? ችግር የለም።';

  @override
  String get minorAccountReviewWelcomeBody =>
      'ወደዚህ ገጽ ገብተህ ማንበብን መረጥክ እንጂ በቀላሉ የሚያስገባህን መልስ አልመረጥክም፤ ይህ ትርጉም አለው። ታማኝነትን፣ ጥንካሬንና በዙሪያህ ላሉ ሰዎች እውነተኛ አሳቢነትን ያሳያል።\n\nከ16 ዓመት በታች ላሉ ሰዎች ያሉት ደንቦች በምትኖርበት ቦታ ይለያያሉ። በDivine ቤተሰቦች አብረው እንዲወያዩና ጤናማ የማኅበራዊ ሚዲያ አጠቃቀም ምን እንደሚመስል አብረው እንዲወስኑ እንፈልጋለን።';

  @override
  String get minorAccountReviewModerationTitle => 'አንድ ተጨማሪ ደረጃ ያስፈልገናል';

  @override
  String get minorAccountReviewModerationBody =>
      'ይህ መለያ ከ16 ዓመት በታች የሆነ ሰው ሊሆን ስለሚችል በጥልቀት እንድንመለከተው ተጠይቀናል። ይህ ሂደት ቀጣይ ደረጃዎችን በግል ይይዛል፣ ለዕድሜህ ወደሚስማማው መንገድም ይመራሃል።';

  @override
  String get minorAccountReviewRulesTitle => 'ደንቦቹ በሁሉም ቦታ አንድ አይደሉም';

  @override
  String get minorAccountReviewRulesBody =>
      'የተለያዩ አገሮችና ክልሎች ታዳጊዎች ማኅበራዊ ሚዲያን እንዴት እንደሚጠቀሙ በተለያየ መንገድ ይመለከቱታል። ስለዚህ ቤተሰቦች ትንሽ እንዲረጋጉ፣ እውነታዎቹን እንዲያረጋግጡና ቀጣዩን ደረጃ አብረው እንዲመርጡ እንጠይቃለን።';

  @override
  String get minorAccountReviewApproachTitle => 'Divine እንዴት እንደሚያየው';

  @override
  String get minorAccountReviewApproachBody =>
      'ጤናማ የቴክኖሎጂ ልማዶች የሚመጡት ቆም ብሎ በማሰብና ትኩረትን ወደ የተሻሉ ነገሮች በመመለስ እንጂ ልጆችን በመሰለልና ወላጆችን ጠባቂ በማድረግ አይደለም ብለን እናምናለን። ጥናቶችም ይህንኑ ይደግፋሉ።';

  @override
  String get minorAccountReviewLearnMoreTitle => 'ለቤተሰቦች ተጨማሪ';

  @override
  String get minorAccountReviewKidsPolicyCta => 'የDivineን የልጆች ፖሊሲ አንብብ';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'የሚስማማህን መንገድ ምረጥ';

  @override
  String get minorAccountReviewUnder13Cta => 'ከ13 በታች';

  @override
  String get minorAccountReviewTeenCta => 'ከ13 እስከ 15 ዓመት';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'ታዳጊዎች ማኅበራዊ ሚዲያን በበለጠ ደኅንነት እንዲጠቀሙ የሚረዱ ተግባራዊ ምክሮችን፣ የውይይት መሣሪያዎችንና ግብዓቶችን ለማግኘት የDivine የቤተሰብ መመሪያን ጎብኝ።';

  @override
  String get minorAccountReviewFamilyResourcesCta => 'የቤተሰብ መመሪያዎችንና ምክሮችን አግኝ';

  @override
  String get minorAccountReviewFooter =>
      '16 ወይም ከዚያ በላይ ከሆንህና በስህተት እዚህ ከደረስክ፣ እውነተኛ ሰው እንዲመረምረው የDivine ድጋፍን አግኝ።';

  @override
  String get minorAccountReviewTitle => 'የመለያ ግምገማ';

  @override
  String get minorAccountReviewCheckingStatusTitle => 'የመለያ ሁኔታ በመፈተሽ ላይ...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'የዚህን መለያ የአሁኑን የግምገማ ሁኔታ እስክናረጋግጥ እባክህ ጠብቅ።';

  @override
  String get minorAccountReviewDefaultTitle => 'የመለያ ግምገማ ያስፈልጋል';

  @override
  String get minorAccountReviewDefaultBody =>
      'ይህ መለያ Divineን በመደበኛነት ከመጠቀሙ በፊት ልንገመግመው ይገባል።';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'የጉዳይ መለያ፦ $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'የጉዳይ መለያ';

  @override
  String get minorAccountReviewRestrictionsTitle => 'አሁን የተገደበው ምንድን ነው';

  @override
  String get minorAccountReviewRestrictionPosting => 'መለጠፍና ማተም ቆመዋል';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'አስተያየቶች፣ መውደዶች፣ ድጋሚ ልጥፎችና መከታተያዎች ቆመዋል';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'መደበኛ መልእክቶችን መጀመር ወይም መመለስ ቆሟል';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'ድጋፍና የቁጥጥር መልእክትህ አሁንም ይገኛሉ';

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
  String get minorAccountReviewOpenSupportCenter => 'የድጋፍ ማዕከልን ክፈት';

  @override
  String get minorAccountReviewOpenModerationMessage => 'የቁጥጥር መልእክቱን ክፈት';

  @override
  String get minorAccountReviewOpenReviewPage => 'የግምገማ ገጹን ክፈት';

  @override
  String get minorAccountReviewCheckAgain => 'እንደገና ፈትሽ';

  @override
  String get minorAccountReviewLogOut => 'ውጣ';

  @override
  String get minorAccountReviewNextStepTitle => 'ቀጣይ ደረጃ';

  @override
  String get minorAccountReviewNextStepBody =>
      'በዚህ ግምገማ እርዳታ ከፈለግህ የድጋፍ ማዕከሉን ወይም የቁጥጥር መልእክትህን ክፈት።';

  @override
  String get minorAccountReviewInProgressTitle => 'ግምገማው በሂደት ላይ ነው';

  @override
  String get minorAccountReviewInProgressBody =>
      'ለአሁኑ የሚያስፈልገን አለን። መደበኛውን የመለያ መዳረሻ ከመመለሱ በፊት ቡድናችን ይህን ጉዳይ እየገመገመ ነው።';

  @override
  String get minorAccountReviewUnder13Title => 'ከ13 ዓመት በታች መለያዎች';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'ይህ መለያ ከ13 ዓመት በታች የሆነ ሰው ከሆነ፣ ወላጅ ወይም አሳዳጊ ወደ $supportEmail ኢሜይል መላክና የጉዳይ መለያውን ማካተት አለበት።';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle => 'ገና መለያ ልንሰጥህ አንችልም';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine ከ13 ዓመት በታች ላሉ ልጆች የተሠራ አይደለም፣ በዓለም ዙሪያ ያሉ የማኅበራዊ ሚዲያ ደንቦችም እጃችንን ያስራሉ።\n\nበኢንተርኔት ላይ ብዙ ነገሮች የፈለግከውን ለማግኘት እንድትዋሽ ይገፋፉሃል፣ እኛ ደግሞ ይህን እንጠላለን። ለሕይወት የተሳሳተ ትምህርት ነው፣ እዚህም አናስተምርህም።';

  @override
  String get minorAccountReviewUnder13FamilyTitle => 'ቤተሰብህ በምትኩ ምን ማድረግ ይችላል';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'ወላጅ ወይም አሳዳጊ መለያውን ይዞ መለጠፍ ይችላል፣ አንተም ከእነሱ ጋር በቪዲዮዎቹ ውስጥ በእርግጠኝነት መሆን ትችላለህ። ቤተሰቦች Divineን ለእነሱ በሚስማማ መንገድ እንዲደሰቱበት እንፈልጋለን።';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => '13 ዓመት ስትሞላህ';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'በምትኖርበት ቦታ ባሉ ደንቦች መሠረት፣ ተመልሰህ የራስህን መለያ ማመልከት ትችል ይሆናል። በዚያን ጊዜ ከ13 እስከ 15 ከሆንክ የወላጅ ወይም የአሳዳጊ ፈቃድ ያስፈልግሃል።';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'ለምን ወደ ኋላ ጠቅ አድርግ ብቻ እንደማንልህ';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'አብዛኛው የበይነመረብ ክፍል ሰዎችን በሩን ለማለፍ የሚያስፈልገውን ማንኛውንም ነገር በመናገር እንዲሸለሙ ተዘጋጅቷል። ይህ ጥሩ ነው ብለን አናስብም። አዎ፣ ወደ ኋላ ተመልሰህ ከዕድሜህ በላይ ነኝ ልትል ትችላለህ፣ ግን ያ ታማኝ አይሆንም፣ እናም የፈለግከውን ለማግኘት ውሸት እንድትዋሽ አናሠለጥንህም።';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'ወጣቶች Divine ን ለእነሱ እና በዙሪያቸው ላሉ ሰዎች ጤናማ እና አዎንታዊ በሆኑ መንገዶች እንዲጠቀሙ ለመርዳት እየሞከርን ነው። እንዲሁም በተለያዩ ቦታዎች የተለያዩ ህጎችን መከተል አለብን። ስለዚህ ዕድሜህ ከ13 በታች ከሆነ፣ መልሱ ዛሬ የራስህ መለያ ሊኖርህ አይችልም የሚል ነው።';

  @override
  String get minorAccountReviewTeenBody =>
      'ይህ መለያ ከ13 እስከ 15 ዓመት የሆነ ሰው ከሆነ፣ የወላጅ ፈቃድ መመሪያዎችን ለመከተል የቁጥጥር መልእክቱን ወይም የድጋፍ መንገዱን ተጠቀም።';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'መለያው ከ13 እስከ 15 ዓመት ለሆነ ሰው የሚሆን ከሆነ';

  @override
  String get minorAccountReviewParentConsentBody =>
      'ወላጅ ወይም ሞግዚት ለDivine ድጋፍ አጭር የግል ቪዲዮ በኢሜይል መላክ አለበት። ቡድናችን ይገመግመዋል፣ በቀጣይ ደረጃዎችም ይረዳሃል።\n\nወላጅ ወይም ሞግዚትን ማግኘት የማይቻል ከሆነ ወይም ማንንም አደጋ ላይ የሚጥል ከሆነ፣ ለDivine ድጋፍ ኢሜይል ልከህ አሳውቀን።';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'ይህ የDivine ድጋፍ ቡድን ቪዲዮውን እስኪገመግም ድረስ ያለ ማቆሚያ ነው። ከጸደቀ፣ አዲሱን መለያ በማዘጋጀት ሂደት ውስጥ ይመሩሃል።';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'ወላጅ ወይም ሞግዚት እንዲሳተፍ ለምን እንደምንጠይቅ';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine በዓለም ዙሪያ ከዕድሜ ጋር የተያያዙ ህጎችን መከተል አለበት። እንዲሁም አብዛኞቹ ቴክኒካዊ የዕድሜ በሮች ፍጹም እንዳልሆኑ እናውቃለን። ደንቦቹ የሉም ወይም ስለ ዕድሜህ መዋሸት ጥሩ ነው ከማስመሰል ይልቅ፣ ወጣቶች እና ቤተሰቦች Divine ን እንዴት በተሻለ ሁኔታ መጠቀም እንደሚችሉ በጥንቃቄ ውሳኔ እንዲወስኑ እንፈልጋለን። ለዚህም ነው ከ13-15 ዓመት ለሆኑ፣ ወላጆች የመለያ አፈጣጠር ሂደት አካል እንዲሆኑ የምንጠይቀው።';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'እንዲሁም ህጉን መከተል አለብን፣ እና እነዚያ ደንቦች አንድ ሰው በሚኖርበት ቦታ ላይ ተመስርተው ይለያያሉ። ስለዚህ ደንቦቹ የሉም ከማስመሰል ይልቅ፣ ወላጅ ወይም ሞግዚት የሂደቱ አካል እንዲሆን እንጠይቃለን።';

  @override
  String get minorAccountReviewParentConsentChecklist => 'ቪዲዮው ምን ማሳየት አለበት';

  @override
  String get minorAccountReviewParentConsentChecklistKid => 'ታዳጊውን በቪዲዮው ውስጥ';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'በካሜራ ፊት የሚናገር ወላጅ ወይም አሳዳጊ';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'ታዳጊው ከ13 እስከ 15 መሆኑንና Divineን ለመጠቀም ፈቃድ እንዳለው የሚገልጽ ግልጽ አነጋገር';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'ወላጁ ወይም አሳዳጊው ስለ መለያው እንደሚያውቅና አጠቃቀሙን እንደሚቆጣጠር የሚገልጽ ግልጽ አነጋገር';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'እንዴት እንደሚላክ';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'ለDivine ድጋፍ ኢሜይል ስትልክ ቪዲዮውን አያይዝ';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'ቪዲዮውን በግል ያዝ፣ በመተግበሪያው ውስጥም አትለጥፈው';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'ቡድናችን ይገመግመዋል፣ በቀጣይ ደረጃዎችም ይመልስልሃል';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'ለDivine ድጋፍ ኢሜይል ላክ';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'የDivine Greenlight ግምገማ እርዳታ (ከ13 እስከ 15 ዓመት)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'ሰላም የDivine ድጋፍ ቡድን፣\n\nከ13 እስከ 15 ዓመት ስለሆነ ታዳጊ በተመለከተ ስለ Divine Greenlight እያገኘኋችሁ ነው።\n\nየሚከተለውን የሚያሳይ አጭር የግል ቪዲዮ አያይዣለሁ፦\n- ታዳጊውን\n- በካሜራ ፊት የሚናገር ወላጅ ወይም አሳዳጊ\n- ታዳጊው Divineን ለመጠቀም ፈቃድ እንዳለው\n- ወላጁ ወይም አሳዳጊው ስለ መለያው እንደሚያውቅና አጠቃቀሙን እንደሚቆጣጠር\n\nየመኖሪያ አገር/አገሮች፦\n\nጠቃሚ ዳራ፦\n\nአመሰግናለሁ።';

  @override
  String get minorAccountReviewParentSupportInstructions => 'የወላጅ ድጋፍ መመሪያዎች';

  @override
  String get minorAccountReviewContinue => 'ቀጥል';

  @override
  String get minorAccountReviewErrorTitle => 'የመለያህን የግምገማ ሁኔታ መጫን አልቻልንም።';

  @override
  String get minorAccountReviewErrorBody => 'እባክህ ከጥቂት ቆይታ በኋላ እንደገና ሞክር።';

  @override
  String get minorAccountReviewTryAgain => 'እንደገና ሞክር';

  @override
  String get minorAccountReviewParentContactTitle => 'የወላጅ አድራሻ';

  @override
  String get minorAccountReviewParentContactHeading =>
      'የወላጅ ወይም የአሳዳጊ ኢሜይል አክል';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'ይህን አድራሻ በጉዳይ $caseId ላይ ላለው የወላጅ ፈቃድ ግምገማ እንጠቀማለን።';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel => 'የወላጅ ወይም የአሳዳጊ ኢሜይል';

  @override
  String get minorAccountReviewSubmitting => 'በመላክ ላይ...';

  @override
  String get minorAccountReviewSubmitEmail => 'ኢሜይሉን ላክ';

  @override
  String get minorAccountReviewBackToReview => 'ወደ መለያ ግምገማ ተመለስ';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'ኢሜይሉ ተልኳል';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return '$emailን ለግምገማ አስገብተናል። ለማረጋገጥ ወደዚህ አድራሻ ኢሜይል እንልካለን። ወላጅህ ወይም አሳዳጊህ ምላሽ ሲሰጥ ጉዳይህ ወደፊት ይሄዳል። ለዝማኔዎች ከመለያ ግምገማ ገጹ ላይ «እንደገና ፈትሽ»ን ተጠቀም።';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'ለዚህ መለያ የወላጅ ወይም የአሳዳጊ አድራሻ ደርሶናል። መዳረሻውን ከመመለሱ በፊት ቡድናችን ይገመግመዋል።';

  @override
  String get minorAccountReviewMissingCase =>
      'ለዚህ መለያ ንቁ የግምገማ ጉዳይ ማግኘት አልቻልንም።';

  @override
  String get minorAccountReviewParentContactError =>
      'የወላጁን ኢሜይል መላክ አልተቻለም። እባክህ እንደገና ሞክር።';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'የወላጅ ድጋፍ';

  @override
  String get minorAccountReviewUnder13Heading =>
      'ወላጅ ወይም አሳዳጊ Divineን ማግኘት አለበት';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'ከ13 ዓመት በታች ሳይሆኑ ለማይቀሩ መለያዎች፣ ቀጣዩ ደረጃ የወላጅ ወይም የአሳዳጊ ኢሜይል ግንኙነት ነው።';

  @override
  String get minorAccountReviewSupportEmailLabel => 'የድጋፍ ኢሜይል';

  @override
  String get minorAccountReviewCopySupportEmail => 'የድጋፍ ኢሜይሉን ቅዳ';

  @override
  String get minorAccountReviewSupportEmailCopied => 'የድጋፍ ኢሜይሉ ተቀድቷል';

  @override
  String get minorAccountReviewCopyCaseId => 'የጉዳይ መለያውን ቅዳ';

  @override
  String get minorAccountReviewCaseIdCopied => 'የጉዳይ መለያው ተቀድቷል';

  @override
  String get minorAccountReviewUnavailable => 'አይገኝም';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'ወላጁ ወይም አሳዳጊው የጉዳይ መለያውን እንዲያካትትና ስለዚህ የመለያ ግምገማ Divineን እያገኘ መሆኑን እንዲያብራራ ጠይቅ።';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'ለጉዳይ $caseId ከ13 ዓመት በታች የመለያ ግምገማ';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'ሰላም የDivine ድጋፍ ቡድን፣\n\nከ13 ዓመት በታች የሆነ ልጅ ወላጅ ወይም አሳዳጊ ነኝ፣ ስለ መለያ ግምገማ ጉዳይ $caseId እያገኘኋችሁ ነው።\n\nአመሰግናለሁ።';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'የአካለ መጠን ያልደረሰ መለያ ግምገማ ማስመሰያ';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'የአሁኑ ሁኔታ';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'የተገደበ ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'ንቁ';

  @override
  String get devOptionsMinorReviewStateLoading => 'በመጫን ላይ...';

  @override
  String get devOptionsMinorReviewStateError => 'ሁኔታውን በመጫን ላይ ስህተት';

  @override
  String get devOptionsMinorReviewClearTitle => 'የማስመሰያ ሽፋንን አጽዳ';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'እንደገና የኋላ አገልግሎቱን ወይም ነባሪውን ንቁ ሁኔታ ተጠቀም';

  @override
  String get devOptionsMinorReviewTeenTitle => 'የ13–15 ግምገማ ጉዳይ አስመስል';

  @override
  String get devOptionsMinorReviewTeenSubtitle => 'የተገደበ መለያ ከወላጅ አድራሻ መንገድ ጋር';

  @override
  String get devOptionsMinorReviewUnder13Title => 'ከ13 በታች የድጋፍ ጉዳይ አስመስል';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'የተገደበ መለያ በወላጅ ኢሜይል ብቻ መመሪያዎች';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'የአካለ መጠን ያልደረሰ መለያ ግምገማ ማስመሰያ ጸድቷል';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'የተመሰለው ከ13 በታች የድጋፍ ጉዳይ በርቷል';

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
  String get devOptionsProtectedMinorSimulationTitle => 'የተጠበቀ ታዳጊ ማስመሰያ';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'የአሁኑ ሁኔታ';

  @override
  String get devOptionsProtectedMinorStateProtected => 'የተጠበቀ ታዳጊ (13–15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'ያልተጠበቀ';

  @override
  String get devOptionsProtectedMinorStateLoading => 'በመጫን ላይ…';

  @override
  String get devOptionsProtectedMinorStateError => 'ሁኔታውን በማንበብ ላይ ስህተት';

  @override
  String get devOptionsProtectedMinorOverrideNone => 'ሽፋን የለም (እውነተኛ የመለያ ሁኔታ)';

  @override
  String get devOptionsProtectedMinorOverrideProtected => 'ሽፋን፦ የተጠበቀ ተገዷል';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected => 'ሽፋን፦ ያልተጠበቀ ተገዷል';

  @override
  String get devOptionsProtectedMinorSimulateTitle => 'የተጠበቀ ታዳጊ አስመስል (13–15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'የ#175/#176 ጥበቃዎችን ለመፈተሽ የተጠበቀ-ታዳጊ ሁኔታን አስገድድ';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle => 'አዋቂ አስመስል';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'ያልተጠበቀን አስገድድ (ግልጽ አሉታዊ፣ ሽፋን ከሌለው የተለየ)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'ሽፋኑን አጽዳ';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'ወደ እውነተኛው በKeycast የሚመራ የመለያ ሁኔታ ተመለስ';

  @override
  String get devOptionsProtectedMinorEnabledToast => 'የተጠበቀ-ታዳጊ ሁኔታ ተገዷል';

  @override
  String get devOptionsProtectedMinorNonMinorToast => 'የተጠበቀ-ታዳጊ ሁኔታ ጠፍቷል';

  @override
  String get devOptionsProtectedMinorClearedToast => 'የተጠበቀ-ታዳጊ ሽፋን ጸድቷል';

  @override
  String get devOptionsInviteAvailabilityTitle => 'የምዝገባ ግብዣዎች';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'የአሁኑ ሁኔታ';

  @override
  String get devOptionsInviteAvailabilityServerLoading => 'የአገልጋይ እሴት፦ በመጫን ላይ';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => 'የአገልጋይ እሴት፦ በርቷል';

  @override
  String get devOptionsInviteAvailabilityServerDisabled => 'የአገልጋይ እሴት፦ ጠፍቷል';

  @override
  String get devOptionsInviteAvailabilityServerUnknown => 'የአገልጋይ እሴት፦ አይታወቅም';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'ሽፋን፦ የአገልጋዩን እሴት ተጠቀም';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled => 'ሽፋን፦ ማብራት አስገድድ';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled => 'ሽፋን፦ ማጥፋት አስገድድ';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'የአገልጋዩን እሴት ተጠቀም';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'የግብዣ አገልግሎቱን onboardingMode ተከተል';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'ማብራት አስገድድ';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'የምዝገባ ግብዣ በሮችንና አስተዳደሩን በአካባቢው አሳይ';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'ማጥፋት አስገድድ';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'አገልጋዩን ሳትቀይር የምዝገባ ግብዣ ገጽታን በአካባቢው ደብቅ';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'የምዝገባ ግብዣዎች አሁን አገልጋዩን ይከተላሉ';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'የምዝገባ ግብዣዎች በግድ በርተዋል';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'የምዝገባ ግብዣዎች በግድ ጠፍተዋል';

  @override
  String get commentsRecordVideoButtonLabel => 'የቪዲዮ አስተያየት ቅረጽ';

  @override
  String get commentsOpenVideoLabel => 'የቪዲዮ አስተያየት ክፈት';

  @override
  String get commentsMuteVideoReplyLabel => 'የቪዲዮ ምላሽን ዝም አድርግ';

  @override
  String get commentsUnmuteVideoReplyLabel => 'የቪዲዮ ምላሽን ድምጽ አስጀምር';

  @override
  String get commentsOpenReplyParentLabel => 'ይህ የሚመልስበትን ቪዲዮ ክፈት';

  @override
  String get commentsReplyParentSectionTitle => 'ምላሽ ለ';

  @override
  String commentsReplyParentLabel(String target) {
    return 'ምላሽ ለ $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'ምላሽ ለ ቪዲዮ';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'የተረጋገጠ $platform መለያ: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'የተረጋገጡ መለያዎች';

  @override
  String get profileEditGetVerifiedCta => 'ተረጋግጥ';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'ሰዎች በእርግጥ አንተ መሆንህን እንዲያውቁ የማህበራዊ ሚዲያ መለያዎችህን አገናኝ።';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'ድረ-ገጹን ጎብኝ፦ $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'ድረ-ገጹን መክፈት አልተቻለም';

  @override
  String get videoMetadataEditCoverTitle => 'ሽፋን አርትዕ';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => 'የሽፋን ለውጦችን አስወግድ';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'የተመረጠውን ፍሬም እንደ ቪዲዮ ሽፋን ተጠቀም';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'የሽፋን ፍሬም ለመምረጥ በቪዲዮው ውስጥ ፈልግ';

  @override
  String get videoMetadataTagsPickerSearchHint => 'መለያዎችን ይፈልጉ ወይም ያክሉ';

  @override
  String get videoMetadataTagsPickerEmptyHint => 'ሰዎች ቪዲዮዎን እንዲያገኙ መለያዎችን ያክሉ';

  @override
  String get videoMetadataTagsPickerNoResults => 'ተዛማጅ መለያዎች የሉም';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '\"#$tag\" ያክሉ';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'እስካሁን 16 አልሆንክም? ችግር የለም። ';

  @override
  String get authUnder16ChoicesCta => 'ምርጫዎችህ እነሆ።';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'ምክንያቱ ይኸው';

  @override
  String get generalSettingsHoldToRecord => 'ለቀረጻ ይያዙ';

  @override
  String get generalSettingsHoldToRecordSubtitle => 'ሲይዙ ቀረጻ ይጀምራል፣ ሲለቁ ይቆማል';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ቪዲዮዎች ወደ መገለጫዎ ታትሟቸዋል',
      one: 'ቪዲዮ ወደ መገለጫዎ ታትሟል',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'መልእክት ላክ';

  @override
  String get emojiPickerSearchHint => 'ፍለጋ';

  @override
  String get emojiCategoryRecent => 'የቅርብ ጊዜ';

  @override
  String get emojiCategorySmileys => 'ፈገግታዎች እና ሰዎች';

  @override
  String get emojiCategoryAnimals => 'እንስሳት እና ተፈጥሮ';

  @override
  String get emojiCategoryFood => 'ምግብ እና መጠጥ';

  @override
  String get emojiCategoryActivities => 'እንቅስቃሴዎች';

  @override
  String get emojiCategoryTravel => 'ጉዞ እና ቦታዎች';

  @override
  String get emojiCategoryObjects => 'ቁሶች';

  @override
  String get emojiCategorySymbols => 'ምልክቶች';

  @override
  String get emojiCategoryFlags => 'ባንዲራዎች';

  @override
  String get videoEditorMarkerLabel => 'ማርከር';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel => 'የጊዜ መስመር ማርከር አክል';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'የጊዜ መስመር ማርከር አስወግድ';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'በማጫወቻ ቦታ ያለውን ማርከር አስወግድ';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'ማርከሩን ይሰርዙ?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'ይህ ማርከሩን ከጊዜ መስመሩ ያስወግዳል። አርትዖትዎ እንዳለ ይቀራል።';

  @override
  String get videoEditorVolumeLongPressHint => 'ሁሉንም ትራኮች ያጥፉ ወይም ያብሩ';

  @override
  String get videoEditorSplitFailed => 'መከፋፈሉ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get videoEditEditSubtitles => 'የትርጉም ጽሑፎችን አርትዕ';

  @override
  String get subtitleEditorTitle => 'የትርጉም ጽሑፎችን አርትዕ';

  @override
  String get subtitleEditorSave => 'አስቀምጥ';

  @override
  String get subtitleEditorProcessing =>
      'የትርጉም ጽሑፎች አሁንም እየተፈጠሩ ነው። ከአፍታ በኋላ ተመልሰው ይመልከቱ።';

  @override
  String get subtitleEditorNoSpeech =>
      'በዚህ ቪዲዮ ውስጥ ንግግር አልተገኘም፤ ስለዚህ የሚጻፍ ትርጉም የለም።';

  @override
  String get subtitleEditorWriteOwn => 'እራስዎ ይጻፉ';

  @override
  String get subtitleEditorAddCue => 'መስመር ያክሉ';

  @override
  String get subtitleEditorRemoveCue => 'ይህን መስመር ያስወግዱ';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'ቪዲዮው አሁን ሊጫወት አልቻለም፣ ግን አሁንም መግለጫ ጽሑፎቹን ማስተካከል ይችላሉ።';

  @override
  String get subtitleEditorPlayPreview => 'ቪዲዮውን ያጫውቱ';

  @override
  String get subtitleEditorPausePreview => 'ቪዲዮውን ያቁሙ';

  @override
  String get subtitleEditorInvalidHint =>
      'እያንዳንዱ መስመር ጽሑፍና ከመጀመሪያው በኋላ የሆነ መጨረሻ ያስፈልገዋል።';

  @override
  String get subtitleEditorLoadError => 'የትርጉም ጽሑፎችን መጫን አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get subtitleEditorSaveSuccess => 'የትርጉም ጽሑፎች ተዘምነዋል';

  @override
  String get subtitleEditorSaveError => 'የትርጉም ጽሑፎችን ማስቀመጥ አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get subtitleEditorRetry => 'እንደገና ሞክር';

  @override
  String get subtitleEditorCueHint => 'የመግለጫ ጽሑፍ';

  @override
  String get imageCropEditorRotateLabel => 'አሽከርክር';

  @override
  String get imageCropEditorFlipLabel => 'ግልብጥ';

  @override
  String get imageCropEditorResetLabel => 'ዳግም አስጀምር';

  @override
  String get imageCropEditorCloseSemanticLabel => 'መከርከምን ሰርዝ';

  @override
  String get imageCropEditorDoneSemanticLabel => 'መከርከምን ተግብር';

  @override
  String get imageCropEditorProcessing => 'መከርከም በመተግበር ላይ…';

  @override
  String get backgroundUploadNotificationTitle => 'ቪዲዮ በመስቀል ላይ';

  @override
  String get monetizationSettingsTitle => 'የፈጣሪ ድጋፍ';

  @override
  String get monetizationSettingsSubtitle => 'የጉርሻና የደንበኝነት ምዝገባ አገናኞችን አክል';

  @override
  String get monetizationSettingsIntroTitle => 'የውጭ አገናኞች ብቻ';

  @override
  String get monetizationSettingsIntroBody =>
      'አንተ የምትቆጣጠራቸውን መድረሻዎች አክል። Divine ክፍያውን ፈጽሞ አያስተናግድም፣ በእነዚህ አገናኞችም በመተግበሪያ ውስጥ ያለ ይዘት አይከፍትም።';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'በመገለጫህ ላይ $count ንቁ አገናኞች',
      one: 'በመገለጫህ ላይ $count ንቁ አገናኝ',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'ጉርሻ ላክ';

  @override
  String get monetizationSettingsSubscriptionSection => 'ደንበኛ ሁን / ደግፍ';

  @override
  String get monetizationSettingsSave => 'የድጋፍ አገናኞችን አስቀምጥ';

  @override
  String get monetizationSettingsSaving => 'በማስቀመጥ ላይ...';

  @override
  String get monetizationSettingsSaved => 'የድጋፍ አገናኞች ተዘምነዋል';

  @override
  String get monetizationSettingsSaveFailed =>
      'የድጋፍ አገናኞችን ማስቀመጥ አልተቻለም። ግንኙነትህን አረጋግጥና እንደገና ሞክር።';

  @override
  String get monetizationSettingsErrorEmpty => 'መለያ ወይም URL አክል።';

  @override
  String get monetizationSettingsErrorInvalid => 'ይህ አገናኝ ትክክል አይመስልም።';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'ለዚህ አቅራቢ የሚሆን አገናኝ ተጠቀም።';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag ወይም የcash.app አገናኝ';

  @override
  String get monetizationSettingsHintPayPal => 'የPayPal.me መለያ ወይም አገናኝ';

  @override
  String get monetizationSettingsHintVenmo => 'የVenmo መለያ ወይም አገናኝ';

  @override
  String get monetizationSettingsHintPatreon => 'የPatreon መለያ ወይም አገናኝ';

  @override
  String get monetizationSettingsHintSubstack => 'የSubstack ጎራ ወይም አገናኝ';

  @override
  String get monetizationSettingsHintMedium => 'የMedium መለያ ወይም አገናኝ';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'የOpen Collective መለያ ወይም አገናኝ';

  @override
  String get profileSupportSheetTitle => 'ይህን ፈጣሪ ደግፍ';

  @override
  String get profileSupportSheetBody =>
      'እነዚህ አገናኞች ከDivine ውጭ ይከፈታሉ። እዚህ ያለ ምንም ነገር በመተግበሪያው ውስጥ ይዘት አይከፍትም።';

  @override
  String get profileSupportTipSection => 'ጉርሻ ላክ';

  @override
  String get profileSupportSubscriptionSection => 'ደንበኛ ሁን / ደግፍ';

  @override
  String get profileSupportButtonLabel => 'ደግፍ';

  @override
  String get monetizationTipsSettingsTitle => 'ጉርሻዎች';

  @override
  String get monetizationTipsSettingsSubtitle => 'አማራጭ የጉርሻ አገናኞችን አክል';

  @override
  String get monetizationTipsSettingsIntroTitle => 'አማራጭ ጉርሻዎች ብቻ';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'ጉርሻዎች በተጠቃሚዎች መካከል የሚደረጉ አማራጭ ስጦታዎች ናቸው። በDivine ውስጥ ይዘት፣ የደንበኝነት ምዝገባ፣ ባህሪያት፣ ደረጃ፣ ታይነት ወይም መዳረሻ አይከፍቱም።';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'በመገለጫህ ላይ $count ንቁ የጉርሻ አገናኞች',
      one: 'በመገለጫህ ላይ $count ንቁ የጉርሻ አገናኝ',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'የጉርሻ አገናኞችን አስቀምጥ';

  @override
  String get monetizationTipsSettingsSaved => 'የጉርሻ አገናኞች ተዘምነዋል';

  @override
  String get profileTipButtonLabel => 'ጉርሻ';

  @override
  String get profileTipSheetTitle => 'ለዚህ ፈጣሪ ጉርሻ ስጥ';

  @override
  String get profileTipSheetBody =>
      'የጉርሻ አገናኞች ከDivine ውጭ ይከፈታሉ። አማራጭ ናቸው፣ በDivine ውስጥም ይዘት፣ የደንበኝነት ምዝገባ፣ ባህሪያት ወይም መዳረሻ አይከፍቱም።';

  @override
  String get settingsStorageTitle => 'ማከማቻ';

  @override
  String get settingsStorageCacheSectionTitle => 'የተሸጎጠ ሚዲያ';

  @override
  String get settingsStorageCacheDescription =>
      'የተሸጎጡ የፊድ ቪዲዮዎች፣ ድንክዬዎች እና ጊዜያዊ ሬንደሮች። ማጽዳት ደህና ነው — ሲያስፈልግ እንደገና ይወርዳሉ ወይም ይፈጠራሉ።';

  @override
  String get settingsStorageMeasuring => 'በማስላት ላይ…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size ጥቅም ላይ ውሏል';
  }

  @override
  String get settingsStorageClearButton => 'መሸጎጫ አጽዳ';

  @override
  String get settingsStorageClearConfirmTitle => 'የተሸጎጠውን ሚዲያ ማጽዳት?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'ይህ $size ነጻ ያደርጋል። የክሊፕ ቤተ-መጻሕፍትህ አይነካም።';
  }

  @override
  String get settingsStorageClearConfirmAction => 'አጽዳ';

  @override
  String get settingsStorageCleared => 'መሸጎጫ ጸድቷል';

  @override
  String get settingsStorageLibrarySectionTitle => 'የክሊፕ ቤተ-መጻሕፍት';

  @override
  String get settingsStorageLibraryDescription =>
      'የቪዲዮ ፋይላቸው የጠፋ የተበላሹ ክሊፖችን ፈትሽ።';

  @override
  String get settingsStorageScanButton => 'ቤተ-መጻሕፍትን ፈትሽ';

  @override
  String get settingsStorageLibraryHealthy => 'የተበላሹ ክሊፖች አልተገኙም';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'የተገኙ የተበላሹ ክሊፖች፦ $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'የተበላሹ ክሊፖችን አስወግድ';

  @override
  String get settingsStorageBrokenClipsRemoved => 'የተበላሹ ክሊፖች ተወግደዋል';

  @override
  String get settingsStorageError => 'የሆነ ችግር ተፈጥሯል';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'ከፍተኛ የቪዲዮ መሸጎጫ';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count ቪዲዮዎች';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle => 'የተበላሹ ክሊፖችን ማስወገድ?';

  @override
  String get settingsStorageRepairSectionTitle => 'ጭነትን ጠግን';

  @override
  String get settingsStorageRepairDescription =>
      'መተግበሪያው በተደጋጋሚ የሚቋረጥ ወይም እንግዳ ባህሪ የሚያሳይ ከሆነ፣ የአካባቢ ውሂቡን ዳግም ማስጀመር አብዛኛውን ጊዜ ይፈታዋል። ክሊፖችህና ረቂቆችህ ይቀራሉ።';

  @override
  String get settingsStorageRepairButton => 'የመተግበሪያ ውሂብ ዳግም አስጀምር';

  @override
  String get settingsStorageRepairConfirmTitle => 'የመተግበሪያ ውሂብ ዳግም ይጀመር?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'ይህ የተቀመጠ የፊድ ውሂብንና ጊዜያዊ ፋይሎችን ያጸዳል። ክሊፖችህ፣ ረቂቆችህ፣ ቅንብሮችህና መግቢያህ ይቀራሉ፣ ነገር ግን ከዚያ በኋላ መተግበሪያውን እንደገና ማስጀመር አለብህ።';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size ይሰረዛል';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'ዳግም አስጀምር';

  @override
  String get settingsStorageRepairInProgress => 'ዳግም በማስጀመር ላይ…';

  @override
  String get settingsStorageRepairSuccess =>
      'ተጠናቋል — ለማጠናቀቅ መተግበሪያውን እንደገና አስጀምር።';

  @override
  String get settingsStorageRepairFailure =>
      'ሁሉንም ዳግም ማስጀመር አልተቻለም። እንደገና ካስጀመርክ በኋላ ሞክር።';

  @override
  String get nostrSettingsSignatureVerification => 'የፊርማ ማረጋገጫ';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Divine የሬሌይ ክስተት ፊርማዎችን መቼ እንደሚፈትሽ ይምረጡ። የክስተት IDዎች ሁልጊዜ መጀመሪያ ይረጋገጣሉ።';

  @override
  String get nostrSettingsSignatureVerificationAll => 'ሁሉም ሬሌዮች';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'በጣም ደህና። የእያንዳንዱን ሬሌይ ክስተት ፊርማ አረጋግጥ።';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => 'ያልታመኑ ሬሌዮች';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'ቀድሞ በተዋቀረው የሬሌይ ስብስብዎ ውስጥ ላሉ ሬሌዮች ፍተሻዎችን ዝለል።';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Divine ያልሆኑ ሬሌዮች';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'የDivine ሬሌዮችን እመን፣ የቀሩትን አረጋግጥ።';

  @override
  String get settingsCrosspostingTitle => 'ተሻግሮ ማተም';

  @override
  String get settingsCrosspostingSubtitle => 'ቪዲዮዎችዎን ወደ ሌሎች መድረኮች ያጋሩ';

  @override
  String get crosspostingSignInRequired => 'ተሻግሮ ማተምን ለማስተዳደር በDivine ይግቡ';

  @override
  String get crosspostingLoadFailed => 'የተሻግሮ ማተም ቅንብሮችዎ መጫን አልተቻለም';

  @override
  String get crosspostingNoPlatforms => 'አሁን ምንም የተሻግሮ ማተሚያ መድረክ የለም';

  @override
  String get crosspostingRetry => 'እንደገና ይሞክሩ';

  @override
  String get crosspostingNotConnected => 'አልተገናኘም';

  @override
  String get crosspostingConnected => 'ተገናኝቷል።';

  @override
  String get crosspostingNeedsReconnect => 'እንደገና መገናኘት ያስፈልገዋል';

  @override
  String get crosspostingConnect => 'ያገናኙ';

  @override
  String get crosspostingReconnect => 'እንደገና ገና';

  @override
  String get crosspostingDisconnect => 'ግንኙነቱን ያቋርጡ';

  @override
  String get crosspostingModeOff => 'ጠፍቷል';

  @override
  String get crosspostingModeManual => 'በእጅ';

  @override
  String get crosspostingModeManualSubtitle => 'ለእያንዳንዱ ቪዲዮ እርስዎ ይመርጣሉ';

  @override
  String get crosspostingModeAutomatic => 'ራስ-ሰር';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'ወደፊት የሚወጡ ቪዲዮዎች በራሳቸው ይለጠፋሉ — ይህን ካበሩ በኋላ የሚያትሙት ብቻ';

  @override
  String get crosspostingNotConnectedError =>
      'እንዴት እንደሚለጥፍ ለመቀየር መጀመሪያ ይህን መድረክ ያገናኙ።';

  @override
  String get crosspostingGenericError => 'የሆነ ችግር ተፈጥሯል። እንደገና ይሞክሩ።';

  @override
  String get crosspostingCallbackTimeoutError =>
      'ከመግቢያ ገጹ ምንም ምላሽ አልደረሰንም። እዚያ ጨርሰው ከሆነ ያድሱ — መለያዎ አስቀድሞ ተያይዞ ሊሆን ይችላል።';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform ተገናኝቷል';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return '$platform ማገናኘት አልተቻለም';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'ግንኙነቱ በ$platform ላይ ተሰርዟል';
  }

  @override
  String get supporterTitle => 'የDivine ደጋፊዎች';

  @override
  String get supporterTileSubtitle => 'Divineን በአማራጭ ወርሃዊ የደንበኝነት ምዝገባ ይደግፉ።';

  @override
  String get supporterHeroTitle => 'Divineን እንዲቀጥል ያድርጉ';

  @override
  String get supporterHeroBody =>
      'Divine ነፃ ነው እና ሁልጊዜም ይሆናል። ሉፖቹ እንዲቀጥሉ ለመርዳት ከፈለጉ፣ ወርሃዊ ደጋፊ ይሁኑ። ምንም አይታገድም — መብራቱን የሚያቆይ እና ምስጋናችንን የሚያገኝ ብቻ ነው።';

  @override
  String get supporterActiveBadge => 'የDivine ደጋፊ ነዎት። ይህንን ስላስቀጠሉ እናመሰግናለን።';

  @override
  String get supporterPurchasePending => 'ግዢዎ ፈቃድ በመጠባበቅ ላይ ነው።';

  @override
  String get supporterPurchaseConfirming => 'ድጋፍዎን በማረጋገጥ ላይ…';

  @override
  String get supporterStoreChecking => 'መደብሩን በመፈተሽ ላይ…';

  @override
  String get supporterUnavailable => 'የደጋፊ የደንበኝነት ምዝገባዎች እዚህ ለአሁኑ አይገኙም።';

  @override
  String get supporterRestorePurchases => 'ግዢዎችን መልስ';

  @override
  String get supporterDismissError => 'ስህተቱን አሰናብት';

  @override
  String get supporterErrorStoreUnavailable => 'መደብሩ በዚህ መሣሪያ ላይ አይገኝም።';

  @override
  String get supporterErrorPurchaseFailed =>
      'ግዢው አልተጠናቀቀም። ምንም ክፍያ አልተጠየቀብዎትም።';

  @override
  String get supporterErrorPurchasePending => 'ግዢዎ ፈቃድ በመጠባበቅ ላይ ነው።';

  @override
  String get supporterErrorRestoreFailed => 'የሚመለስ የደጋፊ የደንበኝነት ምዝገባ አልተገኘም።';

  @override
  String get supporterErrorOwnershipConflict => 'ይህ ግዢ የሌላ የDivine መለያ ነው።';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine የደጋፊ ሁኔታን አሁን ማረጋገጥ አልቻለም።';

  @override
  String get supporterErrorUnknown => 'የሆነ ችግር ተፈጥሯል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get supporterDisclaimer =>
      'መደብሩ ግዢዎን ካረጋገጠ በኋላ Divine የደጋፊ ሁኔታን ያረጋግጣል። እውቅናው አማራጭ ነው፣ እና ሄሎው ማረጋገጫ አይደለም።';

  @override
  String get profileNotifyBellOff => 'ስለ አዲስ ቫይኖች አሳውቀኝ';

  @override
  String get profileNotifyBellOn => 'ስለ አዲስ ቫይኖች አታሳውቀኝ';

  @override
  String get profileNotifyUpdateFailed => 'ማስቀመጥ አልተቻለም። እንደገና ይሞክሩ?';

  @override
  String get savedSoundYourLabel => 'የአንተ መለያ ጽሑፍ';

  @override
  String get savedSoundAddHashtags => 'ሃሽታጎችን አክል';

  @override
  String get savedSoundDeviceOnly => 'በዚህ መሣሪያ ላይ ተቀምጧል';

  @override
  String get savedSoundDetailsRetry =>
      'እነዚያን ዝርዝሮች ማስቀመጥ አልተቻለም። እንደገና ለመሞከር ንካ።';

  @override
  String get savedSoundFallbackTitle => 'የተቀመጠ ድምፅ';

  @override
  String get savedSoundPreviewAction => 'ድምፁን አዳምጥ';

  @override
  String get savedSoundEditAction => 'የድምፅ ዝርዝሮችን አርም';

  @override
  String get savedSoundRemoveAction => 'የተቀመጠውን ድምፅ አስወግድ';

  @override
  String get savedSoundClearHashtagFilter => 'የሃሽታግ ማጣሪያን አጽዳ';

  @override
  String get soundAllowRemix => 'ሌሎች ይህን ድምፅ እንዲቀላቅሉ ፍቀድ';

  @override
  String get soundReuseUnavailable => 'ይህ ድምፅ አሁን መቀላቀል አይችልም።';

  @override
  String get soundPublicCredit => 'የይፋ ድምፅ ምስጋና';

  @override
  String get soundCreditRequired => 'ከመለጠፍህ በፊት የይፋ ድምፅ ምስጋና አክል።';

  @override
  String get soundSharedAs => 'የተጋራው እንደ';

  @override
  String get soundOwnWork => 'ይህን ድምፅ የሠራሁት እኔ ነኝ';

  @override
  String soundCreatorBy(String creator) {
    return 'በ$creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'በ$publisher ተጋርቷል';
  }

  @override
  String get soundRemixingAllowed => 'መቀላቀል ተፈቅዷል';

  @override
  String get soundCreditOnly => 'ምስጋና ብቻ';

  @override
  String get soundCreditTitleLabel => 'የድምፅ ርዕስ';

  @override
  String get soundCreditCreatorLabel => 'ፈጣሪ';

  @override
  String get soundCreditSourceUrlLabel => 'የምንጭ URL';

  @override
  String get soundCreditPublicHashtagsLabel => 'የይፋ ሃሽታጎች';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel => 'የመለያ ምርጫን ሰርዝ';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel => 'የተመረጡ መለያዎችን ተግብር';

  @override
  String get userPickerCancelSemanticLabel => 'የተጠቃሚ ምርጫን ሰርዝ';

  @override
  String get userPickerConfirmSemanticLabel => 'የተመረጡ ተጠቃሚዎችን አረጋግጥ';

  @override
  String get userPickerClearSelectionSemanticLabel => 'የተጠቃሚ ምርጫን አጽዳ';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'የይዘት ማስጠንቀቂያ ምርጫን ሰርዝ';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'የተመረጡ የይዘት ማስጠንቀቂያዎችን ተግብር';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'የቪዲዮ አርታዒውን ዝጋ';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'ወደ ልጥፍ ዝርዝሮች ቀጥል';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'በ$tool ውስጥ የተደረጉ ለውጦችን አስወግድ';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'በ$tool ውስጥ የተደረጉ ለውጦችን ተግብር';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'ኦዲዮን አስወግድ';

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
  String get verifyTitle => 'የተረጋገጡ መለያዎች';

  @override
  String get verifySignedOutMessage => 'መለያዎችህን ለማገናኘት ግባ።';

  @override
  String get verifyIntro =>
      'አስቀድመህ ያሉህን መለያዎች አገናኝ፣ ሰዎች በእርግጥ አንተ መሆንህን እንዲያውቁ።';

  @override
  String get verifyLoadFailed => 'ግንኙነቶችህን መጫን አልተቻለም።';

  @override
  String get verifyRetry => 'እንደገና ሞክር';

  @override
  String get verifyLinkedSectionTitle => 'የተገናኙ';

  @override
  String get verifyVerifierUnreachable =>
      'አረጋጋጩ አልተገኘም፣ ስለዚህ ሁሉም ያልተመረመሩ ሆነው ይታያሉ።';

  @override
  String get verifyAddSectionTitle => 'መለያ ጨምር';

  @override
  String get verifyAllPlatformsLinked => 'የምንደግፈውን ሁሉ አገናኝተሃል።';

  @override
  String get verifyStatusVerified => 'የተረጋገጠ';

  @override
  String get verifyStatusUnverified => 'ያልተረጋገጠ';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'የ$platform መለያ $identity ግንኙነት አቋርጥ';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'የ$platform ግንኙነት ይቋረጥ?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity ከመገለጫህ ላይ መታየቱ ይቆማል። በኋላ እንደገና ማገናኘት ትችላለህ፣ ግን እንደገና መግባት ወይም አዲስ ማረጋገጫ መለጠፍ ይኖርብሃል።';
  }

  @override
  String get verifyUnlinkConfirmCta => 'ግንኙነት አቋርጥ';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'የ$platform መለያህን አገናኝ';
  }

  @override
  String get verifyOneTapBadge => 'አንድ ንክኪ';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'ወደ $platform ግባ፣ የቀረውን እኛ እንሠራዋለን። ምንም አይለጠፍም።';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'በ$platform ቀጥል';
  }

  @override
  String get verifyConnectProofTitle => 'ወይም ማስረጃ ለጥፍ';

  @override
  String get verifyConnectProofExplainer =>
      'npub ህን በመለያህ ላይ ለጥፍ፣ ከዚያ የዚያን ልጥፍ አገናኝ ለጥፍ።';

  @override
  String get verifyNpubLabel => 'የአንተ npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'npub ህን ቅዳ';

  @override
  String get verifyNpubCopied => 'npub ተቀድቷል';

  @override
  String get verifyIdentityLabel => 'የመለያ ስም';

  @override
  String get verifyProofLabel => 'የልጥፍህ አገናኝ';

  @override
  String get verifyConnectProofCta => 'መርምር እና አገናኝ';

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
  String get verifyErrorVerifierUnreachable => 'አረጋጋጩ አልተገኘም። ትንሽ ቆይተህ ሞክር።';

  @override
  String get verifyErrorOauthFailed => 'አልተሳካም። እንደገና ሞክር።';

  @override
  String get verifyErrorHandleRequired => 'መጀመሪያ ሃንድልህን አስገባ።';

  @override
  String get verifyErrorPublishFailed =>
      'ተረጋግጧል፣ ግን ማንኛውም ሪሌይ ዝማኔውን አልተቀበለም። እንደገና ሞክር።';

  @override
  String get verifyErrorOauthUnavailable =>
      'የአንድ ንክኪ መግቢያ ለዚህ ገና አልተዘጋጀም። ከታች ያለውን ማስረጃ ተጠቀም።';

  @override
  String get verifyConnectProofExplainerGithub =>
      'npub ህ በመጀመሪያው ፋይል ውስጥ ያለበት ይፋዊ gist ፍጠር፣ ከዚያ የgist አገናኝ ለጥፍ።';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'ቦታችን ሊያነበው በሚችል የDiscord ቻናል ውስጥ npub ህን ለጥፍ፣ ከዚያ የመልእክቱን አገናኝ ለጥፍ። የአገልጋይ ግብዣ ምንም አያረጋግጥም።';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'npub ህን ከዚያ መለያ ለጥፍ፣ ከዚያ የtweet ኡን አገናኝ ለጥፍ።';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'npub ህን ከዚያ መለያ ለጥፍ፣ ከዚያ አገናኙን ለጥፍ። የመለያው ስም ኢንስታንሱን ይፈልጋል — alice ብቻ ሳይሆን mastodon.social/@alice።';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'የሚገናኘው ቻናሉ ነው፣ የቴሌግራም መለያህ አይደለም። ቻናሉ መጀመሪያ ይፋዊ አገናኝ ያስፈልገዋል (ቴሌግራም አዲሶቹን የግል ያደርጋቸዋል)። npub ህን እዚያ ለጥፍ እና የመልእክቱን አገናኝ ለጥፍ።';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'ከላይ ገብተሃል? ከዚያ ሌላ ምንም አያስፈልግም። ካልሆነ npub ህን ለጥፍ እና የዚያን ልጥፍ አገናኝ ለጥፍ።';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'npub ህን በቪዲዮ መግለጫ ውስጥ አስገባ፣ ከዚያ የዚያን ቪዲዮ አገናኝ ለጥፍ።';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'npub ህን በቪዲዮ መግለጫ ውስጥ አስገባ፣ ከዚያ የዚያን ቪዲዮ አገናኝ ለጥፍ።';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform ተገናኝቷል።';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'ያ የግል ቻናል ወይም ግብዣ ነው። ለቻናሉ ይፋዊ አገናኝ ስጠው፣ ከዚያ የመልእክቱን አገናኝ ለጥፍ።';

  @override
  String get verifyErrorRemoveFailed => 'ግንኙነቱ አልተቋረጠም። እንደገና ሞክር።';

  @override
  String get verifyErrorLinksUnreadable =>
      'አሁን ያሉህ ግንኙነቶች ሊነበቡ አልቻሉም፣ ስለዚህ ምንም አልተቀየረም። ግንኙነትህን አረጋግጠህ እንደገና ሞክር።';

  @override
  String get verifyChannelLabel => 'የቻናል ስም';

  @override
  String get verifyHowItWorksTitle => 'ይህ እንዴት ይሠራል?';

  @override
  String get verifyHowItWorksIntro => 'እንደ ሁለት መለያዎች መጨባበጥ አስበው፦';

  @override
  String get verifyHowItWorksYourSide =>
      'የDivine መገለጫህ „በTwitter ላይ @alice እኔ ነኝ“ ይላል።';

  @override
  String get verifyHowItWorksOtherSide =>
      'የTwitter መለያህ „አዎ፣ ያ የDivine መገለጫ የእኔ ነው“ ብሎ ያረጋግጣል።';

  @override
  String get verifyHowItWorksBothSides =>
      'ሁለቱንም ወገን እንመረምራለን። ከተዛመዱ ተረጋግጠሃል። ማጭበርበር አይቻልም — ስምህንና ፎቶህን መቅዳት ይቻላል፣ ከእውነተኛ መለያህ መለጠፍ ግን አይቻልም።';

  @override
  String get verifyHowItWorksOwnership =>
      'ግንኙነቶቹ በራስህ የNostr ማንነት ላይ ናቸው፣ ስለዚህ በፈለግህ ጊዜ ከዚህ ማስወገድ ትችላለህ።';

  @override
  String get generalSettingsSectionIdentity => 'ማንነት';

  @override
  String get libraryFilterAll => 'ሁሉም';

  @override
  String get libraryFilterArchive => 'መዝገብ';

  @override
  String get libraryFilterDeleted => 'የተሰረዙ';

  @override
  String get libraryCategoryNewChipLabel => 'አዲስ';

  @override
  String get libraryCategoryCreateSemanticLabel => 'ምድብ ይፍጠሩ';

  @override
  String get libraryCategoryCreateTitle => 'አዲስ ምድብ';

  @override
  String get libraryCategoryCreateAction => 'ፍጠር';

  @override
  String get libraryCategoryRenameTitle => 'የምድቡን ስም ቀይር';

  @override
  String get libraryCategoryRenameAction => 'ስም ቀይር';

  @override
  String get libraryCategoryDeleteAction => 'ምድብ ሰርዝ';

  @override
  String get libraryCategoryNameLabel => 'የምድብ ስም';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '“$name”ን ይሰረዝ?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'ክሊፖችዎ እንደነበሩ ይቆያሉ። ወደ “ሁሉም” ብቻ ይመለሳሉ።';

  @override
  String get libraryCategoryManageSemanticLabel => 'ይህን ምድብ ስም ይቀይሩ ወይም ይሰርዙ';

  @override
  String get libraryCategoryMoveTitle => 'ወደዚህ አንቀሳቅስ';

  @override
  String get libraryCategoryMoveNone => 'ምድብ የለም';

  @override
  String get libraryCategoryMoveNewCategory => 'አዲስ ምድብ';

  @override
  String get libraryArchiveAction => 'መዝገብ ውስጥ አስቀምጥ';

  @override
  String get libraryUnarchiveAction => 'ከመዝገብ አውጣ';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'በእነዚህ ምድቦች ውስጥ ማቆየት?',
      one: 'በዚህ ምድብ ውስጥ ማቆየት?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'በ$name ውስጥ አቆይ';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'በምድቦቻቸው ውስጥ አቆይ';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'ከ$name አስወግድ';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed => 'ከምድቦቻቸው አስወግድ';

  @override
  String get libraryMoveSelectedClipsTooltip => 'የተመረጡ ክሊፖችን አንቀሳቅስ';

  @override
  String get libraryCategoryEmptyTitle => 'እዚህ እስካሁን ምንም የለም';

  @override
  String get libraryCategoryEmptySubtitle => 'ጥቂት ክሊፖችን ይምረጡና ወደዚህ ምድብ ያንቀሳቅሱ።';

  @override
  String get libraryArchiveEmptyTitle => 'በመዝገብ ውስጥ ምንም የለም';

  @override
  String get libraryArchiveEmptySubtitle =>
      'በመዝገብ የተቀመጡ ክሊፖች ከዋናው ቤተ-መጻሕፍትዎ ተለይተው እዚህ ይጠብቃሉ።';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች ወደ $name ተንቀሳቅሰዋል',
      one: '$count ክሊፕ ወደ $name ተንቀሳቅሷል',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች ከምድባቸው ወጥተዋል',
      one: '$count ክሊፕ ከምድቡ ወጥቷል',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች በመዝገብ ተቀምጠዋል',
      one: '$count ክሊፕ በመዝገብ ተቀምጧል',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች ወደ ቤተ-መጻሕፍትዎ ተመልሰዋል',
      one: '$count ክሊፕ ወደ ቤተ-መጻሕፍትዎ ተመልሷል',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'ኢሜይል ቀይር';

  @override
  String get accountSettingsChangeEmailSubtitle => 'መለያህን ወደ ሌላ አድራሻ አዛውር';

  @override
  String get accountSettingsChangePassword => 'የይለፍ ቃል ቀይር';

  @override
  String get accountSettingsChangePasswordSubtitle => 'ለመግቢያ አዲስ የይለፍ ቃል ምረጥ';

  @override
  String get accountCredentialsNeedsSignIn =>
      'ክፍለ ጊዜህ አልቋል። ይህን ለመቀየር እንደገና ግባ።';

  @override
  String get accountCredentialsRateLimited => 'በጣም ብዙ ሙከራ። ጥቂት ደቂቃ ቆይ።';

  @override
  String get accountCredentialsNetwork =>
      'Divine ላይ መድረስ አልተቻለም። ግንኙነትህን አረጋግጠህ እንደገና ሞክር።';

  @override
  String get accountCredentialsUnknown => 'አልተሳካም። እባክህ እንደገና ሞክር።';

  @override
  String get changePasswordSubtitle => 'አሁን ያለህን የይለፍ ቃል ጻፍ፣ ከዚያ አዲስ ምረጥ።';

  @override
  String get changePasswordCurrentLabel => 'አሁን ያለ የይለፍ ቃል';

  @override
  String get changePasswordWrongCurrent => 'ይህ አሁን ያለህ የይለፍ ቃል አይደለም።';

  @override
  String get changePasswordSuccess => 'የይለፍ ቃል ተቀይሯል።';

  @override
  String get changeEmailSubtitle =>
      'ወደ አዲሱ አድራሻህ እና በመለያህ ላይ ወዳለው አድራሻ የማረጋገጫ ማገናኛ እንልካለን። ከሁለቱም ስታረጋግጥ ኢሜይልህ ይቀየራል።';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'በመለያህ ላይ: $email';
  }

  @override
  String get changeEmailNewLabel => 'አዲስ ኢሜይል';

  @override
  String get changeEmailPasswordLabel => 'የይለፍ ቃልህ';

  @override
  String get changeEmailSameAsCurrent => 'ይህ አስቀድሞ የኢሜይል አድራሻህ ነው።';

  @override
  String get changeEmailWrongPassword => 'ይህ የይለፍ ቃልህ አይደለም።';

  @override
  String get changeEmailSubmit => 'የማረጋገጫ ማገናኛዎችን ላክ';

  @override
  String get changeEmailSentTitle => 'ሁለት ማገናኛዎች በመንገድ ላይ ናቸው';

  @override
  String changeEmailSentMessage(String email) {
    return 'ከ$email እና በመለያህ ላይ ካለው አድራሻ አረጋግጥ። ሁለቱም ሲጠናቀቁ ኢሜይልህ ይቀየራል።';
  }

  @override
  String get changeEmailSentExpiry => 'ማገናኛዎቹ ከ24 ሰዓት በኋላ አይሠሩም።';

  @override
  String get changeEmailSentDone => 'ገባኝ';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount ቪዲዮዎች',
      one: '$formattedCount ቪዲዮ',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'እርስ በርስ';

  @override
  String get socialProofFollowsYou => 'ይከተልዎታል';

  @override
  String get socialProofYouFollow => 'ይከተላሉ';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount ተከታዮች',
      one: '$formattedCount ተከታይ',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'ቪዲዮዎች አሁን እየተጫኑ አይደሉም።\nችግሩ የእኛ ነው፤ እየሠራንበት ነው።';

  @override
  String get feedOfflineMessage => 'ከመስመር ውጭ ነዎት።\nግንኙነትዎን አረጋግጠው እንደገና ይሞክሩ።';

  @override
  String get dbFailureTitle => 'የአካባቢ ዳታቤዝዎን መክፈት አልተቻለም';

  @override
  String get dbFailureAdviceResettable =>
      'እንደገና ማስጀመር ይህን አያስተካክለውም። ከታች ያለውን የአካባቢ ዳታቤዝ ዳግም ማስጀመር ለDivine ንጹህ ጅምር ይሰጣል — መለያዎ ይቀራል።';

  @override
  String get dbFailureAdviceRestart =>
      'መሣሪያዎን ከከፈቱ በኋላ Divineን እንደገና ያስጀምሩ። ይህ የሚቀጥል ከሆነ መተግበሪያውን ያዘምኑ ወይም ድጋፍን ያግኙ።';

  @override
  String get dbFailureAdviceHotJournal =>
      'Divineን አንድ ጊዜ እንደገና ለማስጀመር ይሞክሩ። ይህ ከቀጠለ መተግበሪያውን ያዘምኑ ወይም ድጋፍን ያነጋግሩ። የአካባቢዎ ውሂብ አሁንም አለ።';

  @override
  String dbFailureDiagnostic(String code) {
    return 'ምርመራ: $code';
  }

  @override
  String get dbFailureCloseApp => 'Divineን ዝጋ';

  @override
  String get dbFailureResetAction => 'የአካባቢ ዳታቤዝ ዳግም አስጀምር';

  @override
  String get dbFailureConfirmTitle => 'የአካባቢ ዳታቤዝዎን ዳግም ያስጀምሩ?';

  @override
  String get dbFailureConfirmBody =>
      'መለያዎ ይቀራል። በዚህ መሣሪያ ላይ የተቀመጡ ረቂቆች እና ክሊፖች ይሰረዛሉ — መልእክቶች እና ምግቦች ከአውታረ መረቡ ይመለሳሉ።';

  @override
  String get dbFailureResetConfirm => 'የአካባቢ ዳታቤዝ አሁን ዳግም አስጀምር';

  @override
  String get dbFailureCancel => 'ሰርዝ';

  @override
  String get dbFailureResetFailed => 'ያ አልሰራም። Divineን ዘግተው እንደገና ይሞክሩ።';

  @override
  String get dbFailureResetDoneTitle => 'የአካባቢ ዳታቤዝ ዳግም ተጀምሯል';

  @override
  String get dbFailureResetDoneBody =>
      'Divineን ዝጋ እና እንደገና ክፈተው — ቀጣዩ ጅምር አዲስ የአካባቢ ዳታቤዝ ይገነባል።';

  @override
  String get authSignInOptionsInfo => 'ስለ መግቢያ አማራጮች';

  @override
  String get authShowPassword => 'የይለፍ ቃል አሳይ';

  @override
  String get authHidePassword => 'የይለፍ ቃል ደብቅ';

  @override
  String get followUserSemanticLabel => 'ተጠቃሚን ተከታተል';

  @override
  String get unfollowUserSemanticLabel => 'ተጠቃሚን መከታተል አቁም';

  @override
  String get commentsLoadingSemanticLabel => 'አስተያየቶች በመጫን ላይ';

  @override
  String get analyticsWindowAll => 'ሁሉም';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'ተጠቃሚን ተከታተል $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'ተጠቃሚን መከታተል አቁም $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / በወር';
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
  String get updateGentleBanner => 'አዲስ ዝማኔ ወጥቷል። ይመልከቱት →';

  @override
  String get updateModerateTitle => 'ካለፈው ጊዜ ጀምሮ አዲስ ዝማኔ አለ';

  @override
  String get updateUrgentTitle => 'አስፈላጊ ማስተካከያዎች እያመለጡዎት ነው';

  @override
  String get updateNotNow => 'አሁን አይደለም';

  @override
  String get updateAction => 'አዘምን';

  @override
  String updateNewIn(String version) {
    return 'በ$version አዲስ፦';
  }

  @override
  String get settingsUpdateAvailable => 'ዝማኔ አለ';
}

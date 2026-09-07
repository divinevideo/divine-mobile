// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'کلپ کی بازیابی';

  @override
  String get devOptionsClipRecoveryDescription =>
      'کسی دوسرے اکاؤنٹ کے تحت محفوظ ریکارڈنگز اور ایسی ویڈیو فائلیں تلاش کرتا ہے جن کا اب کوئی اندراج حوالہ نہیں دیتا۔';

  @override
  String get devOptionsClipRecoveryScan => 'اسکین کریں';

  @override
  String get devOptionsClipRecoveryFailure => 'کلپ بازیابی ناکام ہو گئی';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips کلپس',
      one: '$clips کلپ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts مسودے',
      one: '$drafts مسودہ',
    );
    return 'اس وقت نظر آنے والے: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts =>
      'دوسرے اکاؤنٹس میں چھپے ہوئے';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips کلپس',
      one: '$clips کلپ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts مسودے',
      one: '$drafts مسودہ',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'اس اکاؤنٹ میں منتقل کریں';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'بغیر حوالہ فائلیں: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'لائبریری میں دوبارہ بنائیں';

  @override
  String get devOptionsClipRecoveryEmpty => 'بازیاب کرنے کو کچھ نہیں';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس بازیاب ہو گئے',
      one: '$count کلپ بازیاب ہو گیا',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'بازیابی رپورٹ کاپی ہو گئی';

  @override
  String get devOptionsStorageFootprint => 'اسٹوریج کا استعمال';

  @override
  String get devOptionsStorageFootprintDescription =>
      'ہر وہ فولڈر جس میں ایپ لکھتی ہے۔ کیشے صاف کرنے سے اس کا صرف کچھ حصہ خالی ہوتا ہے۔';

  @override
  String get devOptionsStorageFootprintMeasure => 'پیمائش کریں';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'کل: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'اسٹوریج رپورٹ کاپی ہو گئی';

  @override
  String get devOptionsStorageFootprintFailure =>
      'اسٹوریج کی پیمائش نہیں ہو سکی';

  @override
  String get feedTuningMoreLabel => 'مزید اسی طرح کی';

  @override
  String get feedTuningLessLabel => 'کم اسی طرح کی';

  @override
  String get feedTuningUndo => 'واپس کریں';

  @override
  String get dmMessageBubbleVideoReplyHint => 'حوالہ والی ویڈیو کھولیں';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'ترتیبات';

  @override
  String get settingsSecureAccount => 'اپنا اکاؤنٹ محفوظ کریں';

  @override
  String get settingsSessionExpired => 'سیشن ختم ہو گیا';

  @override
  String get settingsSessionExpiredSubtitle =>
      'مکمل رسائی بحال کرنے کے لیے دوبارہ سائن ان کریں';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'کریئیٹر تجزیات';

  @override
  String get settingsSupportCenter => 'مدد کا مرکز';

  @override
  String get settingsNotifications => 'اطلاعات';

  @override
  String get settingsBlueskyPublishing => 'Bluesky اشاعت';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Bluesky پر کراس پوسٹنگ کا انتظام کریں';

  @override
  String get settingsNostrSettings => 'Nostr ترتیبات';

  @override
  String get settingsIntegratedApps => 'مربوط ایپس';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'منظور شدہ تھرڈ پارٹی ایپس جو Divine کے اندر چلتی ہیں';

  @override
  String get settingsExperimentalFeatures => 'تجرباتی خصوصیات';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'کچھ ٹویکس جو کبھی کبھار لڑکھڑا سکتے ہیں — تجسس ہو تو آزما لیں۔';

  @override
  String get settingsLegal => 'قانونی';

  @override
  String get settingsIntegrationPermissions => 'انضمام کی اجازتیں';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'یاد رکھی گئی انضمام کی منظوریوں کا جائزہ لیں اور منسوخ کریں';

  @override
  String settingsVersion(String version) {
    return 'ورژن $version';
  }

  @override
  String get settingsVersionEmpty => 'ورژن';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'ڈویلپر موڈ پہلے ہی فعال ہے';

  @override
  String get settingsDeveloperModeEnabled => 'ڈویلپر موڈ فعال ہو گیا!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'ڈویلپر موڈ فعال کرنے کے لیے $count مزید ٹیپ درکار';
  }

  @override
  String get settingsShareDivine => 'Divine کو اپنے دوستوں کے ساتھ شیئر کریں';

  @override
  String get settingsSwitchAccount => 'اکاؤنٹ تبدیل کریں';

  @override
  String get settingsAddAnotherAccount => 'ایک اور اکاؤنٹ شامل کریں';

  @override
  String get settingsAccountSwitchFailed =>
      'اکاؤنٹ تبدیل نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get settingsUnsavedDraftsTitle => 'غیر محفوظ مسودے';

  @override
  String get settingsUploadInProgressTitle => 'اپلوڈ جاری ہے';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ویڈیوز',
      one: 'ویڈیو',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'آپ کی ویڈیوز اس اکاؤنٹ میں مسودوں کے طور پر رہ جائیں گی',
      one: 'آپ کی ویڈیو اس اکاؤنٹ میں مسودے کے طور پر رہ جائے گی',
    );
    return 'آپ کی $count $_temp0 ابھی اپلوڈ ہو رہی ہیں۔ اکاؤنٹ تبدیل کرنے سے اپلوڈ رک جائے گا — $_temp1۔';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مسودے',
      one: 'مسودہ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مسودے',
      one: 'مسودہ',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'انہیں',
      one: 'اسے',
    );
    return 'آپ کے پاس $count غیر محفوظ $_temp0 ہیں۔ اکاؤنٹ تبدیل کرنے سے آپ کے $_temp1 برقرار رہیں گے، لیکن بہتر ہوگا کہ پہلے $_temp2 شائع یا دیکھ لیں۔';
  }

  @override
  String get settingsCancel => 'منسوخ کریں';

  @override
  String get settingsSwitchAnyway => 'پھر بھی تبدیل کریں';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'اس اکاؤنٹ کا سیشن ختم ہو چکا ہے۔ اس میں دوبارہ سائن ان کرنے کا مطلب ہے کہ آپ اس اکاؤنٹ سے سائن آؤٹ ہو جائیں گے جو ابھی استعمال کر رہے ہیں۔';

  @override
  String get settingsAppVersionLabel => 'ایپ ورژن';

  @override
  String get settingsAppLanguage => 'ایپ کی زبان';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (ڈیوائس ڈیفالٹ)';
  }

  @override
  String get settingsAppLanguageTitle => 'ایپ کی زبان';

  @override
  String get settingsAppLanguageDescription => 'ایپ انٹرفیس کی زبان منتخب کریں';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'ڈیوائس کی زبان استعمال کریں';

  @override
  String get settingsGeneralTitle => 'عمومی ترتیبات';

  @override
  String get settingsContentSafetyTitle => 'مواد اور حفاظت';

  @override
  String get generalSettingsSectionIntegrations => 'انضمام';

  @override
  String get generalSettingsSectionViewing => 'دیکھنا';

  @override
  String get generalSettingsSectionCreating => 'تخلیق';

  @override
  String get generalSettingsSectionApp => 'ایپ';

  @override
  String get appearanceSettingsTitle => 'ظاہری شکل';

  @override
  String get appearanceSettingsSubtitle =>
      'منتخب کریں کہ Divine اس ڈیوائس پر کیسا دکھے';

  @override
  String get appearanceSettingsSystem => 'سسٹم ڈیفالٹ';

  @override
  String get appearanceSettingsLight => 'لائٹ';

  @override
  String get appearanceSettingsDark => 'ڈارک';

  @override
  String get generalSettingsClosedCaptions => 'کلوزڈ کیپشنز';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'جب ویڈیوز میں کیپشن شامل ہوں تو دکھائیں';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'صرف چوکور ویڈیوز';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'فیڈز کو کلاسک چوکور فارمیٹ میں رکھیں';

  @override
  String get contentPreferencesTitle => 'مواد کی ترجیحات';

  @override
  String get contentPreferencesContentFilters => 'مواد فلٹرز';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'مواد کے انتباہی فلٹرز کا انتظام کریں';

  @override
  String get contentPreferencesContentLanguage => 'مواد کی زبان';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (ڈیوائس ڈیفالٹ)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'اپنی ویڈیوز پر زبان کا ٹیگ لگائیں تاکہ ناظرین مواد فلٹر کر سکیں۔';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'ڈیوائس کی زبان استعمال کریں (ڈیفالٹ)';

  @override
  String get contentPreferencesAudioSharing =>
      'میری آڈیو دوبارہ استعمال کے لیے دستیاب کریں';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'فعال ہونے پر دوسرے لوگ آپ کی ویڈیوز کی آڈیو استعمال کر سکتے ہیں';

  @override
  String get contentPreferencesMusicMode => 'موسیقی موڈ';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'شور کی وہ صفائی بند کر دیتا ہے جو سازوں کو دبا دیتی ہے۔ موسیقی کے لیے بہتر، آوازوں کے لیے کچھ کھردرا۔';

  @override
  String get contentPreferencesAccountLabels => 'اکاؤنٹ لیبلز';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'اپنے مواد کو خود لیبل کریں';

  @override
  String get contentPreferencesAccountContentLabels => 'اکاؤنٹ مواد لیبلز';

  @override
  String get contentPreferencesClearAll => 'سب صاف کریں';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'اپنے اکاؤنٹ پر لاگو سب کچھ منتخب کریں';

  @override
  String get contentPreferencesDoneNoLabels => 'ہو گیا (کوئی لیبل نہیں)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'ہو گیا ($count منتخب)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'آڈیو ان پٹ ڈیوائس';

  @override
  String get contentPreferencesAutoRecommended => 'خودکار (تجویز کردہ)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'خودبخود بہترین مائکروفون منتخب کرتا ہے';

  @override
  String get contentPreferencesSelectAudioInput => 'آڈیو ان پٹ منتخب کریں';

  @override
  String get contentPreferencesUnknownMicrophone => 'نامعلوم مائکروفون';

  @override
  String get contentFiltersAdultContent => 'بالغ مواد';

  @override
  String get contentFiltersViolenceGore => 'تشدد اور خون خرابا';

  @override
  String get contentFiltersSubstances => 'منشیات';

  @override
  String get contentFiltersOther => 'دیگر';

  @override
  String get contentFiltersAgeGateMessage =>
      'بالغ مواد فلٹرز کھولنے کے لیے حفاظت اور رازداری ترتیبات میں اپنی عمر کی تصدیق کریں';

  @override
  String get contentFiltersShow => 'دکھائیں';

  @override
  String get contentFiltersWarn => 'انتباہ';

  @override
  String get contentFiltersFilterOut => 'فلٹر کریں';

  @override
  String get profileBlockedAccountNotAvailable => 'یہ اکاؤنٹ دستیاب نہیں ہے';

  @override
  String get profileInvalidId => 'غلط پروفائل ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Divine پر $displayName کو دیکھیں!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine پر $displayName';
  }

  @override
  String get profileShareFailed =>
      'پروفائل شیئر نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get profileCopyPublicKey => 'عوامی کلید (npub) کاپی کریں';

  @override
  String get profileGetEmbedCode => 'ایمبیڈ کوڈ حاصل کریں';

  @override
  String get profilePublicKeyCopied => 'عوامی کلید کلپ بورڈ پر کاپی ہو گئی';

  @override
  String get profileEmbedCodeCopied => 'ایمبیڈ کوڈ کلپ بورڈ پر کاپی ہو گیا';

  @override
  String get profileMoreTooltip => 'مزید';

  @override
  String get profileMoreSemanticLabel => 'مزید اختیارات';

  @override
  String get profileAvatarLightboxBarrierLabel => 'اواتار بند کریں';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'اواتار پیش منظر بند کریں';

  @override
  String get profileFollowingLabel => 'فالو کر رہے ہیں';

  @override
  String get profileFollowLabel => 'فالو کریں';

  @override
  String get profileBlockedLabel => 'بلاک شدہ';

  @override
  String get profileFollowersLabel => 'فالوورز';

  @override
  String get profileFollowingStatLabel => 'فالوئنگ';

  @override
  String get profileVideosLabel => 'ویڈیوز';

  @override
  String get profileCollabsLabel => 'اشتراکات';

  @override
  String get profileLikedLabel => 'پسندیدہ';

  @override
  String get profileRepostsLabel => 'ریپوسٹس';

  @override
  String get profileListsLabel => 'فہرستیں';

  @override
  String get profileCommentsLabel => 'تبصرے';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شریک کار دعوتیں ابھی بھیجنی باقی ہیں',
      one: '1 شریک کار دعوت ابھی بھیجنا باقی ہے',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'ہم نے دعوت قطار میں رکھی ہوئی ہے۔ یہاں دوبارہ کوشش کریں۔';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return '\"$title\" کے لیے۔ یہاں دوبارہ کوشش کریں۔';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'دوبارہ کوشش کریں';

  @override
  String get profileCollaboratorInviteRetryingAction => 'دوبارہ کوشش جاری ہے';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'شریک کار دعوت کی دوبارہ کوشش فی الحال دستیاب نہیں ہے۔';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شریک کار دعوتیں ابھی بھیجنی باقی ہیں۔',
      one: '1 شریک کار دعوت ابھی بھیجنا باقی ہے۔',
      zero: 'شریک کار دعوتیں بھیج دی گئیں۔',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شریک کار دعوتیں وصول نہیں کر سکتے۔',
      one: '1 شریک کار دعوتیں وصول نہیں کر سکتا۔',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count صارفین';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName کو بلاک کریں؟';
  }

  @override
  String get profileBlockExplanation => 'جب آپ کسی صارف کو بلاک کرتے ہیں:';

  @override
  String get profileBlockBulletHidePosts =>
      'ان کی پوسٹیں آپ کے فیڈز میں نظر نہیں آئیں گی۔';

  @override
  String get profileBlockBulletCantView =>
      'وہ آپ کا پروفائل نہیں دیکھ سکیں گے، نہ آپ کو فالو کر سکیں گے، نہ آپ کی پوسٹیں دیکھ سکیں گے۔';

  @override
  String get profileBlockBulletNoNotify =>
      'انہیں اس تبدیلی کی اطلاع نہیں دی جائے گی۔';

  @override
  String get profileBlockBulletYouCanView =>
      'آپ پھر بھی ان کا پروفائل دیکھ سکیں گے۔';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName کو بلاک کریں';
  }

  @override
  String get profileCancelButton => 'منسوخ کریں';

  @override
  String get profileLearnMore => 'مزید جانیں';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName کو ان بلاک کریں؟';
  }

  @override
  String get profileUnblockExplanation => 'جب آپ اس صارف کو ان بلاک کرتے ہیں:';

  @override
  String get profileUnblockBulletShowPosts =>
      'ان کی پوسٹیں آپ کے فیڈز میں نظر آئیں گی۔';

  @override
  String get profileUnblockBulletCanView =>
      'وہ آپ کا پروفائل دیکھ سکیں گے، آپ کو فالو کر سکیں گے، اور آپ کی پوسٹیں دیکھ سکیں گے۔';

  @override
  String get profileUnblockBulletNoNotify =>
      'انہیں اس تبدیلی کی اطلاع نہیں دی جائے گی۔';

  @override
  String get profileLearnMoreAt => 'مزید جانیں ';

  @override
  String get profileUnblockButton => 'ان بلاک کریں';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName کو ان فالو کریں';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName کو بلاک کریں';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName کو ان بلاک کریں';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '$displayName کی رپورٹ کریں';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayName کو فہرست میں شامل کریں';
  }

  @override
  String get profileNoCollabsTitle => 'ابھی کوئی کولیب نہیں';

  @override
  String get profileCollabsOwnEmpty =>
      'جن ویڈیوز میں آپ کولیب کریں گے وہ یہاں نظر آئیں گی۔';

  @override
  String get profileCollabsOtherEmpty =>
      'جن ویڈیوز میں وہ کولیب کریں گے وہ یہاں نظر آئیں گی۔';

  @override
  String get profileErrorLoadingCollabs => 'کولیب ویڈیوز لوڈ کرنے میں خرابی';

  @override
  String get profileNoSavedVideosTitle => 'ابھی کچھ محفوظ نہیں';

  @override
  String get profileSavedOwnEmpty =>
      'شیئر شیٹ سے ویڈیوز بک مارک کریں اور وہ یہاں نظر آئیں گی۔';

  @override
  String get profileErrorLoadingSaved => 'محفوظ ویڈیوز لوڈ کرنے میں خرابی';

  @override
  String get profileNoCommentsOwnTitle => 'ابھی کوئی تبصرہ نہیں';

  @override
  String get profileNoCommentsOtherTitle => 'ابھی کوئی تبصرہ نہیں';

  @override
  String get profileCommentsOwnEmpty =>
      'آپ کے تبصرے اور جوابات یہاں نظر آئیں گے۔';

  @override
  String get profileCommentsOtherEmpty =>
      'ان کے تبصرے اور جوابات یہاں نظر آئیں گے۔';

  @override
  String get profileErrorLoadingComments => 'تبصرے لوڈ کرنے میں خرابی';

  @override
  String get profileVideoRepliesSection => 'ویڈیو جوابات';

  @override
  String get profileCommentsSection => 'تبصرے';

  @override
  String get profileEditLabel => 'ترمیم';

  @override
  String get profileLibraryLabel => 'لائبریری';

  @override
  String get profileNoLikedVideosTitle => 'ابھی کوئی پسند نہیں';

  @override
  String get profileLikedOwnEmpty =>
      'جب کچھ نگاہ بھائے، دل پر ٹیپ کریں۔ آپ کی پسندیں یہاں نظر آئیں گی۔';

  @override
  String get profileLikedOtherEmpty =>
      'ابھی تک کچھ ان کی نگاہ نہیں بھایا۔ تھوڑا وقت دیں۔';

  @override
  String get profileErrorLoadingLiked => 'پسندیدہ ویڈیوز لوڈ کرنے میں خرابی';

  @override
  String get profileNoRepostsTitle => 'ابھی کوئی ریپوسٹ نہیں';

  @override
  String get profileRepostsOwnEmpty =>
      'کچھ شیئر کے قابل دکھے؟ ریپوسٹ کریں اور وہ یہاں نظر آئے گا۔';

  @override
  String get profileRepostsOtherEmpty =>
      'انہوں نے ابھی تک کچھ آگے نہیں بڑھایا۔ جب کریں گے تو یہاں نظر آئے گا۔';

  @override
  String get profileErrorLoadingReposts =>
      'ریپوسٹ شدہ ویڈیوز لوڈ کرنے میں خرابی';

  @override
  String get profileNoVideosTitle => 'ابھی کوئی ویڈیو نہیں';

  @override
  String get profileNoVideosOwnSubtitle =>
      'آپ کا اسٹیج تیار ہے۔ پوسٹ کرنا شروع کریں اور آپ کی ویڈیوز یہیں رہیں گی۔';

  @override
  String get profileNoVideosOtherSubtitle =>
      'دنیا انتظار کر رہی ہے۔ انہیں فالو کریں تاکہ کچھ نہ چھوٹے۔';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'ویڈیو تھمب نیل $number';
  }

  @override
  String get profileShowMore => 'مزید دکھائیں';

  @override
  String get profileShowLess => 'کم دکھائیں';

  @override
  String get dmMessageDisplayLimitReached =>
      'اس پیغام کا باقی حصہ نہیں دکھایا گیا۔';

  @override
  String get profileCompleteYourProfile => 'اپنا پروفائل مکمل کریں';

  @override
  String get profileCompleteSubtitle =>
      'شروع کرنے کے لیے اپنا نام، بائیو اور تصویر شامل کریں';

  @override
  String get profilePleaseTryAgain => 'براہ کرم دوبارہ کوشش کریں';

  @override
  String get profileSecureYourAccount => 'اپنا اکاؤنٹ محفوظ کریں';

  @override
  String get profileSecureSubtitle =>
      'کسی بھی ڈیوائس پر اپنا اکاؤنٹ بحال کرنے کے لیے ای میل اور پاس ورڈ شامل کریں';

  @override
  String get profileRetryButton => 'دوبارہ کوشش کریں';

  @override
  String get profileSessionExpired => 'سیشن ختم ہو گیا';

  @override
  String get profileSignInToRestore =>
      'مکمل رسائی بحال کرنے کے لیے دوبارہ سائن ان کریں';

  @override
  String get profileSignInButton => 'سائن ان کریں';

  @override
  String get profileMaybeLaterLabel => 'شاید بعد میں';

  @override
  String get profileSecurePrimaryButton => 'ای میل اور پاس ورڈ شامل کریں';

  @override
  String get profileCompletePrimaryButton => 'اپنا پروفائل اپڈیٹ کریں';

  @override
  String get profileLoopsLabel => 'لوپ';

  @override
  String get profileLikesLabel => 'پسندیں';

  @override
  String get profileMyLibraryLabel => 'میری لائبریری';

  @override
  String get profileMessageLabel => 'پیغام';

  @override
  String get profileShareLabel => 'پروفائل شیئر کریں';

  @override
  String get profileDeletedAccountName => 'حذف شدہ اکاؤنٹ';

  @override
  String get inboxActionReportVanishedAccount => 'اس اکاؤنٹ کی رپورٹ کریں';

  @override
  String get inboxActionBlockVanishedAccount => 'اس اکاؤنٹ کو بلاک کریں';

  @override
  String get inboxActionUnblockVanishedAccount => 'اس اکاؤنٹ کو ان بلاک کریں';

  @override
  String get inboxReportedVanishedAccount => 'اس اکاؤنٹ کی رپورٹ کی';

  @override
  String get inboxBlockedVanishedAccount => 'اس اکاؤنٹ کو بلاک کیا';

  @override
  String get inboxUnblockedVanishedAccount => 'اس اکاؤنٹ کو ان بلاک کیا';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'اس سے گفتگو آپ کے ان باکس سے ہٹ جائے گی۔ اگر وہ آپ کو دوبارہ پیغام بھیجیں تو نئی گفتگو شروع ہو جائے گی۔';

  @override
  String get inboxConversationDeletedAccountSubtitle => 'یہ اکاؤنٹ حذف ہو گیا';

  @override
  String get profileUserFallback => 'صارف';

  @override
  String get profileLinkCopied => 'پروفائل لنک کاپی ہو گیا';

  @override
  String get profileSetupEditProfileTitle => 'پروفائل میں ترمیم کریں';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'NIP-05 پتہ شامل کرنے سے پہلے اپنا پروفائل ترتیب دیں۔';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'پروفائل بنائیں';

  @override
  String get profileSetupBackLabel => 'واپس';

  @override
  String get profileSetupAboutNostr => 'Nostr کے بارے میں';

  @override
  String get profileSetupProfilePublished => 'پروفائل کامیابی سے شائع ہو گیا!';

  @override
  String get profileSetupUnsavedChangesTitle => 'تبدیلیاں محفوظ کریں؟';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'جانے سے پہلے اپنی تبدیلیاں محفوظ کریں، یا انہیں رد کر کے آگے بڑھیں۔';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'تبدیلیاں محفوظ کریں';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'تبدیلیاں رد کریں';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'ترمیم جاری رکھیں';

  @override
  String get profileSetupCreateNewProfile => 'نیا پروفائل بنائیں؟';

  @override
  String get profileSetupNoExistingProfile =>
      'آپ کے ریلے پر کوئی موجودہ پروفائل نہیں ملا۔ شائع کرنے سے نیا پروفائل بن جائے گا۔ جاری رکھیں؟';

  @override
  String get profileSetupPublishButton => 'شائع کریں';

  @override
  String get profileSetupUsernameTaken =>
      'صارف نام ابھی کسی اور نے لے لیا۔ براہ کرم کوئی اور منتخب کریں۔';

  @override
  String get profileSetupClaimFailed =>
      'صارف نام حاصل نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get profileSetupPublishFailed =>
      'پروفائل شائع نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get profileSetupNoRelaysConnected =>
      'نیٹ ورک تک رسائی نہیں ہو سکی۔ اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get profileSetupDisplayNameLabel => 'ڈسپلے نام';

  @override
  String get profileSetupDisplayNameRequired => 'براہ کرم ڈسپلے نام درج کریں';

  @override
  String get profileSetupBioLabel => 'بائیو (اختیاری)';

  @override
  String get profileSetupWebsiteLabel => 'ویب سائٹ (اختیاری)';

  @override
  String get profileSetupPublicKeyLabel => 'عوامی کلید (npub)';

  @override
  String get profileSetupUsernameLabel => 'صارف نام (اختیاری)';

  @override
  String get profileSetupUsernameHelper =>
      'حروف، ہندسے یا ہائفن استعمال کریں۔ آپ کا صارف نام divine.video پتہ بن جاتا ہے۔ خالی جگہ یا علامتوں کے لیے اپنا ظاہری نام استعمال کریں۔';

  @override
  String get profileSetupSaveButton => 'محفوظ کریں';

  @override
  String get profileSetupSavingButton => 'محفوظ ہو رہا ہے...';

  @override
  String get profileSetupImageUrlTitle => 'تصویر کا URL شامل کریں';

  @override
  String get profileSetupImageSelectionFailed =>
      'تصویر منتخب نہیں ہو سکی۔ اس کے بجائے نیچے تصویر کا URL پیسٹ کریں۔';

  @override
  String get profileSetupImagesTypeGroup => 'تصاویر';

  @override
  String get cameraPickErrorPermissionDenied =>
      'کیمرے تک رسائی بند ہے۔ تصویر لینے کے لیے ترتیبات میں اسے آن کریں۔';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'اس ڈیوائس پر کیمرے تک رسائی کی اجازت نہیں ہے۔';

  @override
  String get cameraPickErrorBusy =>
      'پکر پہلے سے کھلا ہے۔ اسے بند کر کے دوبارہ کوشش کریں۔';

  @override
  String get cameraPickErrorGeneric => 'کیمرہ نہیں کھل سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get profileSetupGotItButton => 'سمجھ گیا';

  @override
  String get profileSetupUploadFailedGeneric =>
      'اپلوڈ ناکام۔ براہ کرم بعد میں دوبارہ کوشش کریں۔';

  @override
  String get profileSetupUploadNetworkError =>
      'نیٹ ورک خرابی: براہ کرم اپنا انٹرنیٹ کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get profileSetupUploadAuthError =>
      'تصدیق کی خرابی: براہ کرم لاگ آؤٹ کر کے دوبارہ لاگ ان کریں۔';

  @override
  String get profileSetupUploadFileTooLarge =>
      'فائل بہت بڑی ہے: براہ کرم چھوٹی تصویر منتخب کریں (زیادہ سے زیادہ 10MB)۔';

  @override
  String get profileSetupUploadServerError =>
      'اپلوڈ ناکام۔ ہمارے سرور عارضی طور پر دستیاب نہیں ہیں۔ براہ کرم تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get profileSetupBannerClearButton => 'بینر ہٹائیں';

  @override
  String get profileSetupBannerChangeColor => 'بینر کا رنگ';

  @override
  String get profileSetupChangeBannerTitle => 'بینر تبدیل کریں';

  @override
  String get profileSetupBannerColorPickerTitle => 'بینر کا رنگ تبدیل کریں';

  @override
  String get profileSetupBannerColorCustom => 'حسبِ ضرورت';

  @override
  String get profileSetupBannerColorNone => 'کوئی رنگ نہیں';

  @override
  String get profileSetupBannerColorLime => 'لائم';

  @override
  String get profileSetupBannerColorYellow => 'پیلا';

  @override
  String get profileSetupBannerColorViolet => 'بنفشی';

  @override
  String get profileSetupBannerColorPink => 'گلابی';

  @override
  String get profileSetupBannerColorOrange => 'نارنجی';

  @override
  String get profileSetupBannerColorPurple => 'جامنی';

  @override
  String get profileSetupAvatarClearButton => 'تصویر ہٹائیں';

  @override
  String get profileSetupImageTakePhoto => 'تصویر لیں';

  @override
  String get profileSetupImageUploadFromCameraRoll =>
      'کیمرہ رول سے اپ لوڈ کریں';

  @override
  String get profileSetupImagePasteLink => 'تصویر کا لنک چسپاں کریں';

  @override
  String get profileSetupEditAvatarLabel => 'پروفائل تصویر میں ترمیم کریں';

  @override
  String get profileSetupEditBannerLabel => 'بینر میں ترمیم کریں';

  @override
  String get profileSetupUsernameChecking => 'دستیابی چیک ہو رہی ہے...';

  @override
  String get profileSetupUsernameAvailable => 'صارف نام دستیاب ہے!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'صارف نام پہلے ہی لیا جا چکا ہے';

  @override
  String get profileSetupUsernameReserved => 'صارف نام مخصوص ہے';

  @override
  String get profileSetupContactSupport => 'سپورٹ سے رابطہ کریں';

  @override
  String get profileSetupCheckAgain => 'دوبارہ چیک کریں';

  @override
  String get profileSetupUsernameBurned => 'یہ صارف نام اب دستیاب نہیں ہے';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'صرف حروف، اعداد اور ہائفن کی اجازت ہے';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'صارف نام ہائفن سے شروع یا ختم نہیں ہو سکتا';

  @override
  String get profileSetupUsernameInvalidLength =>
      'صارف نام 3 تا 63 حروف کا ہونا چاہیے';

  @override
  String get profileSetupUsernameNetworkError =>
      'دستیابی چیک نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'صارف نام کا فارمیٹ غلط ہے';

  @override
  String get profileSetupUsernameCheckFailed => 'دستیابی چیک کرنے میں ناکامی';

  @override
  String get profileSetupUsernameReservedTitle => 'صارف نام مخصوص ہے';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'نام $username مخصوص ہے۔ بتائیں کہ یہ آپ کا کیوں ہونا چاہیے۔';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'مثلاً یہ میرے برانڈ کا نام ہے، اسٹیج نام ہے وغیرہ۔';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'پہلے سے سپورٹ سے رابطہ کر چکے ہیں؟ دیکھنے کے لیے \"دوبارہ چیک کریں\" پر ٹیپ کریں کہ یہ آپ کو مل گیا ہے یا نہیں۔';

  @override
  String get profileSetupSupportRequestSent =>
      'سپورٹ درخواست بھیج دی گئی! ہم جلد آپ سے رابطہ کریں گے۔';

  @override
  String get profileSetupCouldntOpenEmail =>
      'ای میل نہیں کھل سکی۔ یہاں بھیجیں: names@divine.video';

  @override
  String get profileSetupSendRequest => 'درخواست بھیجیں';

  @override
  String get profileSetupUseOwnNip05 => 'اپنا NIP-05 ایڈریس استعمال کریں';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 ایڈریس';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'NIP-05 فارمیٹ غلط ہے (مثلاً name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'divine.video کے لیے اوپر والا صارف نام فیلڈ استعمال کریں';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 ایڈریس';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'اپنا divine.video صارف نام استعمال کریں، یا اپنے ہینڈل کو کسی ایسے ڈومین کے NIP-05 ایڈریس کی طرف اشارہ کریں جو آپ کے کنٹرول میں ہو۔';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'NIP-05 محفوظ کریں';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 محفوظ ہو گیا';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'NIP-05 محفوظ نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get profileSetupNip05ConfirmTitle => 'اپنا NIP-05 استعمال کریں؟';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 آپ کی Nostr شناخت کو you@yourdomain.com جیسے نام سے جوڑتا ہے۔ آپ کے پاس ڈومین کا کنٹرول ہونا چاہیے اور صحیح پاتھ پر تصدیقی فائل ہوسٹ کرنی ہوگی۔ اگر یہ غلط ہوا تو لوگ آپ کو نہیں ڈھونڈ سکیں گے اور آپ کا تصدیق شدہ ہینڈل غائب ہو جائے گا۔ صرف تب جاری رکھیں جب آپ نے یہ سیٹ اپ کر رکھا ہو۔';

  @override
  String get profileSetupNip05ConfirmContinue => 'جاری رکھیں';

  @override
  String get profileSetupNip05ConfirmCancel => 'منسوخ کریں';

  @override
  String get profileSetupProfilePicturePreview => 'پروفائل تصویر کا پیش منظر';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine، Nostr پر بنا ہے،';

  @override
  String get nostrInfoIntroDescription =>
      ' ایک سنسرشپ مزاحم کھلا پروٹوکول ہے جو لوگوں کو کسی ایک کمپنی یا پلیٹ فارم پر انحصار کیے بغیر آن لائن بات چیت کرنے دیتا ہے۔ ';

  @override
  String get nostrInfoIntroIdentity =>
      'جب آپ Divine پر سائن اپ کرتے ہیں تو آپ کو ایک نئی Nostr شناخت ملتی ہے۔';

  @override
  String get nostrInfoOwnership =>
      'Nostr آپ کو اپنے مواد، شناخت اور سوشل گراف کی ملکیت دیتا ہے، جسے آپ کئی ایپس میں استعمال کر سکتے ہیں۔ نتیجہ: زیادہ چوائس، کم لاک اِن، اور ایک زیادہ صحت مند اور مضبوط سماجی انٹرنیٹ۔';

  @override
  String get nostrInfoLingo => 'Nostr کی اصطلاحات:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' آپ کا عوامی Nostr ایڈریس۔ اسے شیئر کرنا محفوظ ہے اور اس سے دوسرے لوگ Nostr ایپس میں آپ کو ڈھونڈ سکتے ہیں، فالو کر سکتے ہیں یا پیغام بھیج سکتے ہیں۔';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' آپ کی نجی کلید اور ملکیت کا ثبوت۔ یہ آپ کی Nostr شناخت کا مکمل کنٹرول دیتی ہے، اس لیے ';

  @override
  String get nostrInfoNsecWarning => 'اسے ہمیشہ خفیہ رکھیں!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr صارف نام:';

  @override
  String get nostrInfoUsernameDescription =>
      ' ایک انسان کے پڑھنے کے قابل نام (جیسے @name.divine.video) جو آپ کے npub سے جڑتا ہے۔ یہ آپ کی Nostr شناخت کو پہچاننا اور تصدیق کرنا آسان بناتا ہے، بالکل ای میل ایڈریس کی طرح۔';

  @override
  String get nostrInfoLearnMoreAt => 'مزید جانیں ';

  @override
  String get nostrInfoGotIt => 'سمجھ گیا!';

  @override
  String get videoGridRefreshLabel => 'مزید ویڈیوز تلاش ہو رہی ہیں';

  @override
  String get videoGridOptionsTitle => 'ویڈیو اختیارات';

  @override
  String get videoGridEditVideo => 'ویڈیو میں ترمیم کریں';

  @override
  String get videoGridEditVideoSubtitle =>
      'عنوان، تفصیل اور ہیش ٹیگز اپڈیٹ کریں';

  @override
  String get videoGridDeleteVideo => 'ویڈیو حذف کریں';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'یہ ویڈیو Divine سے ہٹائیں۔ یہ دیگر Nostr کلائنٹس پر پھر بھی نظر آ سکتی ہے۔';

  @override
  String get videoGridDeletingContent => 'مواد حذف ہو رہا ہے...';

  @override
  String get exploreTabFeatured => 'نمایاں';

  @override
  String get exploreTabClassics => 'کلاسکس';

  @override
  String get exploreTabNew => 'نئی';

  @override
  String get exploreTabPopular => 'مقبول';

  @override
  String get exploreTabCategories => 'زمرے';

  @override
  String get exploreTabForYou => 'آپ کے لیے';

  @override
  String get exploreTabLists => 'فہرستیں';

  @override
  String get exploreTabIntegratedApps => 'مربوط ایپس';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'یہاں ابھی کچھ نہیں ہے۔ جلد دوبارہ دیکھیں۔';

  @override
  String get featuredTabLoadFailed => 'یہ مجموعہ لوڈ نہیں ہو سکا۔';

  @override
  String get featuredTabRetry => 'دوبارہ کوشش کریں';

  @override
  String get exploreNoVideosAvailable => 'کوئی ویڈیو دستیاب نہیں';

  @override
  String get exploreDiscoverLists => 'فہرستیں دریافت کریں';

  @override
  String get exploreAboutLists => 'فہرستوں کے بارے میں';

  @override
  String get exploreAboutListsDescription =>
      'فہرستیں Divine مواد کو دو طریقوں سے ترتیب دینے اور منتخب کرنے میں مدد دیتی ہیں:';

  @override
  String get explorePeopleLists => 'لوگوں کی فہرستیں';

  @override
  String get explorePeopleListsDescription =>
      'کریئیٹرز کے گروہوں کو فالو کریں اور ان کی تازہ ویڈیوز دیکھیں';

  @override
  String get exploreVideoLists => 'ویڈیو فہرستیں';

  @override
  String get exploreVideoListsDescription =>
      'بعد میں دیکھنے کے لیے اپنی پسندیدہ ویڈیوز کی پلے لسٹیں بنائیں';

  @override
  String get exploreMyLists => 'میری فہرستیں';

  @override
  String get exploreSubscribedLists => 'سبسکرائب شدہ فہرستیں';

  @override
  String get exploreErrorLoadingLists =>
      'فہرستیں لوڈ کرنے میں خرابی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نئی ویڈیوز',
      one: '1 نئی ویڈیو',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ویڈیوز',
      one: 'ویڈیو',
    );
    return '$count نئی $_temp0 لوڈ کریں';
  }

  @override
  String get videoPlayerPlayVideo => 'ویڈیو چلائیں';

  @override
  String get videoPlayerMute => 'ویڈیو میوٹ کریں';

  @override
  String get videoPlayerUnmute => 'ویڈیو ان میوٹ کریں';

  @override
  String get videoPlayerTapHint =>
      'چلانے یا روکنے کے لیے ٹیپ کریں۔ پسند کے لیے ڈبل ٹیپ کریں۔';

  @override
  String get videoSettingsMenuOpen => 'پلے بیک ترتیبات کھولیں';

  @override
  String get videoSettingsMenuClose => 'پلے بیک ترتیبات بند کریں';

  @override
  String get videoSettingsCaptionsEnable => 'کیپشن فعال کریں';

  @override
  String get videoSettingsCaptionsDisable => 'کیپشن غیر فعال کریں';

  @override
  String get videoSettingsAutoAdvanceOn => 'خودکار آگے بڑھنا آن';

  @override
  String get videoSettingsAutoAdvanceOff => 'خودکار آگے بڑھنا آف';

  @override
  String get videoSettingsCaptionsOn => 'کیپشن آن';

  @override
  String get videoSettingsCaptionsOff => 'کیپشن آف';

  @override
  String get videoSettingsCaptionsOnForVideo => 'اس ویڈیو کے لیے کیپشنز آن ہیں';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'اس ویڈیو کے لیے کیپشنز آف ہیں';

  @override
  String get contentWarningLabel => 'مواد انتباہ';

  @override
  String get contentWarningNudity => 'عریانیت';

  @override
  String get contentWarningSexualContent => 'جنسی مواد';

  @override
  String get contentWarningPornography => 'فحش مواد';

  @override
  String get contentWarningGraphicMedia => 'گرافک میڈیا';

  @override
  String get contentWarningViolence => 'تشدد';

  @override
  String get contentWarningSelfHarm => 'خود کو نقصان';

  @override
  String get contentWarningDrugUse => 'منشیات کا استعمال';

  @override
  String get contentWarningAlcohol => 'شراب';

  @override
  String get contentWarningTobacco => 'تمباکو';

  @override
  String get contentWarningGambling => 'جوا';

  @override
  String get contentWarningProfanity => 'گالم گلوچ';

  @override
  String get contentWarningFlashingLights => 'چمکتی روشنیاں';

  @override
  String get contentWarningAiGenerated => 'AI تیار کردہ';

  @override
  String get contentWarningSpoiler => 'اسپوائلر';

  @override
  String get contentWarningSensitiveContent => 'حساس مواد';

  @override
  String get contentWarningDescNudity => 'عریانیت یا جزوی عریانیت پر مشتمل';

  @override
  String get contentWarningDescSexual => 'جنسی مواد پر مشتمل';

  @override
  String get contentWarningDescPorn => 'صریح فحش مواد پر مشتمل';

  @override
  String get contentWarningDescGraphicMedia =>
      'گرافک یا پریشان کن مناظر پر مشتمل';

  @override
  String get contentWarningDescViolence => 'پرتشدد مواد پر مشتمل';

  @override
  String get contentWarningDescSelfHarm =>
      'خود کو نقصان پہنچانے کے حوالے پر مشتمل';

  @override
  String get contentWarningDescDrugs => 'منشیات سے متعلق مواد پر مشتمل';

  @override
  String get contentWarningDescAlcohol => 'شراب سے متعلق مواد پر مشتمل';

  @override
  String get contentWarningDescTobacco => 'تمباکو سے متعلق مواد پر مشتمل';

  @override
  String get contentWarningDescGambling => 'جوے سے متعلق مواد پر مشتمل';

  @override
  String get contentWarningDescProfanity => 'سخت زبان پر مشتمل';

  @override
  String get contentWarningDescFlashingLights =>
      'چمکتی روشنیاں پر مشتمل (روشنی سے حساسیت کا انتباہ)';

  @override
  String get contentWarningDescAiGenerated => 'یہ مواد AI نے تیار کیا ہے';

  @override
  String get contentWarningDescSpoiler => 'اسپوائلر پر مشتمل';

  @override
  String get contentWarningDescContentWarning =>
      'کریئیٹر نے اسے حساس قرار دیا ہے';

  @override
  String get contentWarningDescDefault => 'کریئیٹر نے اس مواد کو فلیگ کیا ہے';

  @override
  String get contentWarningDetailsTitle => 'مواد انتباہات';

  @override
  String get contentWarningDetailsSubtitle => 'کریئیٹر نے یہ لیبل لگائے ہیں:';

  @override
  String get contentWarningManageFilters => 'مواد فلٹرز کا انتظام کریں';

  @override
  String get contentWarningViewAnyway => 'پھر بھی دیکھیں';

  @override
  String get contentWarningReportContentTooltip => 'مواد کی رپورٹ کریں';

  @override
  String get contentWarningBlockUserTooltip => 'صارف کو بلاک کریں';

  @override
  String get contentWarningBlockedTitle => 'مواد بلاک شدہ';

  @override
  String get contentWarningBlockedPolicy =>
      'پالیسی خلاف ورزیوں کی وجہ سے یہ مواد بلاک کر دیا گیا ہے۔';

  @override
  String get contentWarningNoticeTitle => 'مواد نوٹس';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'ممکنہ طور پر نقصان دہ مواد';

  @override
  String get contentWarningView => 'دیکھیں';

  @override
  String get contentWarningReportAction => 'رپورٹ کریں';

  @override
  String get contentWarningHideAllLikeThis => 'اسی طرح کا تمام مواد چھپائیں';

  @override
  String get contentWarningNoFilterYet =>
      'اس انتباہ کے لیے ابھی کوئی محفوظ فلٹر نہیں۔';

  @override
  String get contentWarningHiddenConfirmation =>
      'اب سے ہم ایسی پوسٹیں چھپا دیں گے۔';

  @override
  String get communitySuggestTitle => 'اس کی درجہ بندی میں مدد کریں';

  @override
  String get communitySuggestSubtitle =>
      'مواد انتباہ غائب ہے؟ آپ کی تجویز عوامی، دستخط شدہ ہوگی اور واپس نہیں لی جا سکے گی۔';

  @override
  String get communitySuggestSubmit => 'تجویز کریں';

  @override
  String get communitySuggestSuccess => 'شکریہ۔ آپ کی تجویز بھیج دی گئی۔';

  @override
  String get communitySuggestFailure =>
      'آپ کی تجویز نہیں بھیجی جا سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get communitySuggestAlready => 'آپ یہ تجویز کر چکے ہیں';

  @override
  String get communitySuggestActionLabel => 'درجہ بندی کریں';

  @override
  String get videoErrorNotFound => 'ویڈیو نہیں ملی';

  @override
  String get videoErrorPlayback => 'ویڈیو پلے بیک خرابی';

  @override
  String get videoErrorAgeRestricted => 'عمر محدود مواد';

  @override
  String get videoErrorUnavailable => 'ویڈیو دستیاب نہیں';

  @override
  String get videoErrorUnavailableBody => 'یہ ویڈیو اس وقت دستیاب نہیں ہے۔';

  @override
  String get videoErrorRetry => 'دوبارہ کوشش کریں';

  @override
  String get videoErrorContentRestricted => 'مواد محدود';

  @override
  String get videoErrorContentRestrictedBody =>
      'یہ ویڈیو ہمارے مواد کے قواعد توڑنے پر ہٹا دی گئی۔';

  @override
  String get videoErrorVerifyAgeBody =>
      'یہ ویڈیو دیکھنے کے لیے اپنی عمر کی تصدیق کریں۔';

  @override
  String get videoErrorSkip => 'چھوڑیں';

  @override
  String get videoErrorVerifyAgeButton => 'عمر کی تصدیق کریں';

  @override
  String get videoErrorVerifyAgeFailed =>
      'آپ کی عمر کی تصدیق نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'تصدیق کا وقت ختم ہو گیا۔ اپنا کنکشن چیک کریں یا تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get videoErrorAdultContentHiddenTitle => 'بالغ مواد بند ہے';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'یہ ویڈیو دیکھنے کے لیے اسے مواد فلٹرز میں چالو کریں۔';

  @override
  String get videoErrorAdultContentHiddenAction => 'مواد فلٹرز کھولیں';

  @override
  String get videoDetailLoadError => 'ویڈیو لوڈ نہیں ہو سکی';

  @override
  String get videoDetailLoadErrorBody =>
      'یہاں پہنچتے پہنچتے کچھ گڑبڑ ہو گئی۔ دوبارہ کوشش کریں۔';

  @override
  String get videoDetailNotFoundBody =>
      'ہو سکتا ہے یہ حذف ہو چکی ہو، ہماری پہنچ سے باہر ہو، یا آپ کی ترتیبات نے اسے چھپا دیا ہو۔';

  @override
  String get databaseCorruptionTitle => 'آپ کا مقامی ڈیٹا بگڑ گیا';

  @override
  String get databaseCorruptionBody =>
      'Divine بند کر کے دوبارہ کھولیں — ہم اسے خودکار طور پر ٹھیک کر دیں گے۔ ہم جتنے مسودے اور کلپس بچا سکیں گے بچا لیں گے، باقی سب دوبارہ لوڈ ہو جائے گا۔';

  @override
  String get databaseCorruptionCloseButton => 'Divine بند کریں';

  @override
  String get videoDetailContextTitle => 'شیئر شدہ ویڈیو';

  @override
  String get videoDetailCloseSemanticLabel => 'ویڈیو پلیئر بند کریں';

  @override
  String get videoFollowButtonFollow => 'فالو کریں';

  @override
  String get audioAttributionOriginalSound => 'اصل آواز';

  @override
  String get audioAttributionUnavailableSound => 'آواز دستیاب نہیں';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '@$creatorName +$additionalCreatorCount سے متاثر';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '@$creatorName سے متاثر';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '@$name کے ساتھ';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '@$name کے ساتھ +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شریک کار',
      one: '1 شریک کار',
    );
    return '$_temp0۔ پروفائل دیکھنے کے لیے ٹیپ کریں۔';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'زیر التواء';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'زیر التواء شریک کار';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending زیر التواء)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name۔ پروفائل دیکھنے کے لیے ٹیپ کریں۔';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag۔ اس ہیش ٹیگ والی ویڈیوز دیکھنے کے لیے ٹیپ کریں۔';
  }

  @override
  String get listAttributionFallback => 'فہرست';

  @override
  String get shareVideoLabel => 'ویڈیو شیئر کریں';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'پوسٹ $recipientName کے ساتھ شیئر ہوئی';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'پوسٹ $count لوگوں کے ساتھ شیئر ہوئی',
      one: 'پوسٹ $count شخص کے ساتھ شیئر ہوئی',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'ویڈیو نہیں بھیجی جا سکی';

  @override
  String get shareAddedToBookmarks => 'بک مارکس میں شامل ہو گئی';

  @override
  String get shareRemovedFromBookmarks => 'بک مارکس سے ہٹا دی گئی';

  @override
  String get shareFailedToAddBookmark => 'بک مارک شامل نہیں ہو سکا';

  @override
  String get shareFailedToRemoveBookmark => 'بک مارک نہیں ہٹایا جا سکا';

  @override
  String get shareActionFailed => 'کارروائی ناکام';

  @override
  String get shareWithTitle => 'کس کے ساتھ شیئر کریں';

  @override
  String get shareFindPeople => 'لوگ تلاش کریں';

  @override
  String get shareFindPeopleMultiline => 'لوگ\nتلاش کریں';

  @override
  String get shareSent => 'بھیج دیا';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name منتخب ہوئے';
  }

  @override
  String get shareMessageHint => 'اختیاری پیغام شامل کریں...';

  @override
  String get videoActionUnlike => 'ویڈیو ناپسند کریں';

  @override
  String get videoActionLike => 'ویڈیو پسند کریں';

  @override
  String get videoActionAutoLabel => 'تالیف';

  @override
  String get videoActionLikeLabel => 'پسند';

  @override
  String get videoActionReplyLabel => 'جواب';

  @override
  String get videoActionRepostLabel => 'ریوائن';

  @override
  String get videoActionShareLabel => 'شیئر';

  @override
  String get videoActionReportLabel => 'رپورٹ';

  @override
  String get videoActionReport => 'ویڈیو کی رپورٹ کریں';

  @override
  String get videoActionEditLabel => 'ترمیم';

  @override
  String get videoActionEdit => 'ویڈیو میں ترمیم کریں';

  @override
  String get videoActionAboutLabel => 'تفصیلات';

  @override
  String get videoActionEnableAutoAdvance => 'خودکار آگے بڑھنا فعال کریں';

  @override
  String get videoActionDisableAutoAdvance => 'خودکار آگے بڑھنا غیر فعال کریں';

  @override
  String get videoActionRemoveRepost => 'ریپوسٹ ہٹائیں';

  @override
  String get videoActionRepost => 'ویڈیو ریپوسٹ کریں';

  @override
  String get videoActionViewComments => 'تبصرے دیکھیں';

  @override
  String get videoActionMoreOptions => 'مزید اختیارات';

  @override
  String get videoEngagementLikersTitle => 'پسند کرنے والے';

  @override
  String get videoEngagementRepostersTitle => 'ریپوسٹ کرنے والے';

  @override
  String get videoEngagementLikersEmpty => 'ابھی کوئی پسند نہیں';

  @override
  String get videoEngagementRepostersEmpty => 'ابھی کوئی ریپوسٹ نہیں';

  @override
  String get videoEngagementLoadFailed => 'وہ فہرست لوڈ نہیں ہو سکی';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'ویڈیو تفصیلات کھولیں';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'ویڈیو تفصیلات کھولیں';

  @override
  String get videoOverlayCommentBarHint => 'تبصرہ شامل کریں...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'تبصرہ شامل کریں';

  @override
  String get videoOverlayCommentBarSendLabel => 'تبصرہ بھیجیں';

  @override
  String get videoOverlayCommentPostedSnackbar => 'تبصرہ پوسٹ ہو گیا';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'تبصرہ پوسٹ نہیں ہو سکا';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لوپ',
      one: 'لوپ',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Divine نہیں';

  @override
  String get metadataBadgeHumanMade => 'انسان کی بنائی ہوئی';

  @override
  String get metadataSoundsLabel => 'آوازیں';

  @override
  String get metadataOriginalSound => 'اصل آواز';

  @override
  String get metadataVerificationLabel => 'تصدیق';

  @override
  String get metadataDeviceAttestation => 'ڈیوائس تصدیق';

  @override
  String get metadataPgpSignature => 'PGP دستخط';

  @override
  String get metadataC2paCredentials => 'C2PA مواد اسناد';

  @override
  String get metadataProofManifest => 'ثبوت مینی فیسٹ';

  @override
  String get metadataVerificationInfoTooltip => 'ان جانچوں کا کیا مطلب ہے؟';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'ان جانچوں کا مطلب';

  @override
  String get metadataVerificationInfoIntro =>
      'یہ اشارے کیمرے اور خود ویڈیو فائل سے آتے ہیں۔ ویڈیو کے پاس جتنے زیادہ اشارے ہوں، ہم اس کے ماخذ کے بارے میں اتنا ہی زیادہ ثابت کر سکتے ہیں۔';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'فون کے آپریٹنگ سسٹم نے اُس ایپ کی ضمانت دی جس نے یہ ریکارڈ کیا۔ یہ اس بات کا مضبوط ثبوت ہے کہ یہ کیمرے سے آیا، نہ کہ کسی کی اپ لوڈ کی ہوئی فائل سے۔';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'ویڈیو کو ریکارڈ ہوتے ہی خفیہ نگاری سے دستخط کیا گیا۔ بعد میں ایک فریم بھی بدلے تو دستخط ٹوٹ جاتا ہے۔';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'صنعتی معیار کا ماخذ ریکارڈ جو فائل کے اندر ساتھ سفر کرتا ہے — اس لیے Divine کے علاوہ ایپس بھی اسے جانچ سکتی ہیں۔';

  @override
  String get metadataVerificationInfoProofManifest =>
      'مکمل ProofMode ریکارڈ: فائل کا فنگر پرنٹ، وقت کی مہر اور ریکارڈنگ کا سیاق، ویڈیو کے ساتھ منسلک۔';

  @override
  String get metadataVerificationInfoFootnote =>
      'کسی جانچ کا نہ ہونا ویڈیو کو جعلی نہیں بناتا۔ پرانی کلپس اور اپ لوڈز کے پاس یہ کبھی تھا ہی نہیں — اس کا مطلب صرف یہ ہے کہ ہم وہ حصہ ثابت نہیں کر سکتے۔';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return '$url پر مزید جانیں';
  }

  @override
  String get metadataCreatorLabel => 'کریئیٹر';

  @override
  String get metadataCollaboratorsLabel => 'شریک کار';

  @override
  String get metadataInspiredByLabel => 'متاثر از';

  @override
  String get metadataRepostedByLabel => 'ریپوسٹ کرنے والے';

  @override
  String metadataMoreReposters(int count) {
    return '+$count مزید';
  }

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لوپ',
      one: 'لوپ',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'پسندیں';

  @override
  String get metadataCommentsLabel => 'تبصرے';

  @override
  String get metadataRepostsLabel => 'ریپوسٹس';

  @override
  String get metadataVineStatsLabel => 'Vine پر';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops لوپ · $likes پسندیں · $comments تبصرے · $reposts ریپوسٹس';
  }

  @override
  String get metadataDivineStatsLabel => 'Divine پر';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views ویوز · $likes پسندیں · $comments تبصرے · $reposts ریپوسٹس';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return '$date کو پوسٹ کیا گیا';
  }

  @override
  String get devOptionsTitle => 'ڈویلپر اختیارات';

  @override
  String get devOptionsDisableDeveloperMode => 'ڈویلپر موڈ غیر فعال کریں';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'ترتیبات سے ڈویلپر اختیارات چھپائیں';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'ڈویلپر موڈ غیر فعال ہو گیا';

  @override
  String get devOptionsShorebirdTitle => 'Shorebird پیچز';

  @override
  String get devOptionsShorebirdPatchLabel => 'چلتا ہوا پیچ';

  @override
  String get devOptionsShorebirdNoPatch => 'کوئی پیچ انسٹال نہیں';

  @override
  String get devOptionsShorebirdUnavailable => 'اس بلڈ میں دستیاب نہیں';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'پیچ صرف shorebird release سے بنائی گئی بلڈ میں کام کرتے ہیں۔';

  @override
  String get devOptionsShorebirdLoading => 'پیچ کی حالت پڑھی جا رہی ہے…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'اسٹیجنگ ٹریک ابھی چیک نہیں کیا گیا۔';

  @override
  String get devOptionsShorebirdCheck => 'اسٹیجنگ ٹریک چیک کریں';

  @override
  String get devOptionsShorebirdApply => 'اسٹیجنگ پیچ لگائیں';

  @override
  String get devOptionsShorebirdUseStable => 'مستحکم اپ ڈیٹس پر واپس جائیں';

  @override
  String get devOptionsShorebirdChecking => 'اسٹیجنگ ٹریک چیک ہو رہا ہے…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'اسٹیجنگ پیچ لگانے کے لیے تیار ہے۔';

  @override
  String get devOptionsShorebirdUpToDate =>
      'اس ریلیز کے لیے کوئی اسٹیجنگ پیچ نہیں۔';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'ڈاؤن لوڈ ہو گیا۔ اسے لوڈ کرنے کے لیے ایپ دوبارہ شروع کریں۔';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'رول بیک تیار ہے۔ بنیادی ریلیز پر واپس جانے کے لیے دوبارہ شروع کریں۔';

  @override
  String get devOptionsShorebirdApplying => 'ڈاؤن لوڈ اور انسٹال ہو رہا ہے…';

  @override
  String get devOptionsShorebirdApplied =>
      'انسٹال ہو گیا۔ اسے لوڈ کرنے کے لیے ایپ دوبارہ شروع کریں۔';

  @override
  String get devOptionsShorebirdUnchanged =>
      'کچھ انسٹال نہیں ہوا۔ اسٹیجنگ ٹریک چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'مستحکم ٹریک منتخب کیا جا رہا ہے…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'مستحکم ٹریک منتخب ہو گیا۔ مستحکم پیچ چیک کرنے کے لیے ایپ دوبارہ شروع کریں۔';

  @override
  String get devOptionsShorebirdFailure =>
      'یہ کام نہیں ہوا۔ تفصیلات کے لیے لاگز دیکھیں۔';

  @override
  String get devOptionsPageLoadTimes => 'صفحہ لوڈ اوقات';

  @override
  String get devOptionsNoPageLoads =>
      'ابھی کوئی صفحہ لوڈ ریکارڈ نہیں ہوا۔\nٹائمنگ ڈیٹا دیکھنے کے لیے ایپ میں یہاں وہاں جائیں۔';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'نظر آیا: ${visibleMs}ms  |  ڈیٹا: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'سب سے سست اسکرینیں';

  @override
  String get devOptionsVideoPlaybackFormat => 'ویڈیو پلے بیک فارمیٹ';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'ماحول تبدیل کریں؟';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '$envName پر جائیں؟\n\nاس سے کیش شدہ ویڈیو ڈیٹا صاف ہو جائے گا اور نئے ریلے سے دوبارہ کنکشن ہوگا۔';
  }

  @override
  String get devOptionsCancel => 'منسوخ کریں';

  @override
  String get devOptionsSwitch => 'تبدیل کریں';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '$envName پر تبدیل ہو گیا';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '$formatName پر تبدیل ہو گیا — کیش صاف ہو گئی';
  }

  @override
  String get featureFlagTitle => 'فیچر فلیگز';

  @override
  String get featureFlagResetAllTooltip => 'تمام فلیگز ڈیفالٹ پر ری سیٹ کریں';

  @override
  String get featureFlagError => 'خرابی';

  @override
  String get relaySettingsTitle => 'ریلے';

  @override
  String get relaySettingsInfoTitle =>
      'Divine ایک کھلا سسٹم ہے — آپ اپنے کنکشنز خود کنٹرول کرتے ہیں';

  @override
  String get relaySettingsInfoDescription =>
      'یہ ریلے آپ کے مواد کو غیر مرکزی Nostr نیٹ ورک میں تقسیم کرتے ہیں۔ آپ جیسی مرضی ریلے شامل یا ہٹا سکتے ہیں۔';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr کے بارے میں مزید جانیں →';

  @override
  String get relaySettingsFindPublicRelays =>
      'عوامی ریلے nostr.co.uk پر تلاش کریں →';

  @override
  String get relaySettingsAppNotFunctional => 'ایپ کام نہیں کر رہی';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine کو ویڈیوز لوڈ کرنے، مواد پوسٹ کرنے اور ڈیٹا سنک کرنے کے لیے کم از کم ایک ریلے درکار ہے۔';

  @override
  String get relaySettingsRestoreDefaultRelay => 'ڈیفالٹ ریلے بحال کریں';

  @override
  String get relaySettingsAddCustomRelay => 'کسٹم ریلے شامل کریں';

  @override
  String get relaySettingsAddRelay => 'ریلے شامل کریں';

  @override
  String get relaySettingsRetry => 'دوبارہ کوشش کریں';

  @override
  String get relaySettingsNoStats => 'ابھی کوئی اعداد و شمار دستیاب نہیں';

  @override
  String get relaySettingsConnection => 'کنکشن';

  @override
  String get relaySettingsConnected => 'منسلک';

  @override
  String get relaySettingsDisconnected => 'منقطع';

  @override
  String get relaySettingsSessionDuration => 'سیشن دورانیہ';

  @override
  String get relaySettingsLastConnected => 'آخری منسلک';

  @override
  String get relaySettingsDisconnectedLabel => 'منقطع';

  @override
  String get relaySettingsReason => 'وجہ';

  @override
  String get relaySettingsActiveSubscriptions => 'فعال سبسکرپشنز';

  @override
  String get relaySettingsTotalSubscriptions => 'کل سبسکرپشنز';

  @override
  String get relaySettingsEventsReceived => 'موصول شدہ ایونٹس';

  @override
  String get relaySettingsEventsSent => 'بھیجے گئے ایونٹس';

  @override
  String get relaySettingsRequestsThisSession => 'اس سیشن کی درخواستیں';

  @override
  String get relaySettingsFailedRequests => 'ناکام درخواستیں';

  @override
  String get relaySettingsLoadingRelayInfo => 'ریلے معلومات لوڈ ہو رہی ہیں...';

  @override
  String get relaySettingsAboutRelay => 'ریلے کے بارے میں';

  @override
  String get relaySettingsSupportedNips => 'تعاون یافتہ NIPs';

  @override
  String get relaySettingsSoftware => 'سافٹ ویئر';

  @override
  String get relaySettingsViewWebsite => 'ویب سائٹ دیکھیں';

  @override
  String get relaySettingsRemoveRelayTitle => 'ریلے ہٹائیں؟';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'کیا آپ واقعی یہ ریلے ہٹانا چاہتے ہیں؟\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Divine کا ریلے ہٹائیں؟';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Divine کا ریلے ہٹانے سے ایپ کا تجربہ خراب ہو جائے گا۔ ویڈیوز، پوسٹنگ اور سنک کم قابلِ بھروسہ ہو سکتے ہیں۔ یہ صرف تجربہ کار Nostr صارفین کو کرنا چاہیے۔\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'ریلے ہٹائیں';

  @override
  String get relaySettingsCancel => 'منسوخ کریں';

  @override
  String get relaySettingsRemove => 'ہٹائیں';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'ریلے ہٹا دیا گیا: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'ریلے نہیں ہٹایا جا سکا';

  @override
  String get relaySettingsForcingReconnection =>
      'ریلے دوبارہ کنکشن پر مجبور کیا جا رہا ہے...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '$count ریلے سے منسلک!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'ریلے سے منسلک نہیں ہو سکا۔ براہ کرم اپنا نیٹ ورک کنکشن چیک کریں۔';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'اس ڈیوائس پر محفوظ ہو گیا۔ اشاعت دوبارہ کام کرنے لگے تو ہم اسے آپ کے اکاؤنٹ سے ہم آہنگ کر دیں گے۔';

  @override
  String get relaySettingsAddRelayTitle => 'ریلے شامل کریں';

  @override
  String get relaySettingsAddRelayPrompt =>
      'جس ریلے کو شامل کرنا چاہتے ہیں اس کا WebSocket URL درج کریں:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'عوامی ریلے nostr.co.uk پر دیکھیں';

  @override
  String get relaySettingsAdd => 'شامل کریں';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'ریلے شامل ہو گیا: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'ریلے شامل نہیں ہو سکا۔ براہ کرم URL چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get relaySettingsInvalidUrl =>
      'ریلے URL کا آغاز wss:// یا ws:// سے ہونا چاہیے';

  @override
  String get relaySettingsInsecureUrl =>
      'ریلے URL میں wss:// ہونا چاہیے (ws:// صرف localhost کے لیے جائز ہے)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'ڈیفالٹ ریلے بحال ہو گیا: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'ڈیفالٹ ریلے بحال نہیں ہو سکا۔ براہ کرم اپنا نیٹ ورک کنکشن چیک کریں۔';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'براؤزر نہیں کھل سکا';

  @override
  String get relaySettingsFailedToOpenLink => 'لنک نہیں کھل سکا';

  @override
  String get relaySettingsExternalRelay => 'بیرونی ریلے';

  @override
  String get relaySettingsNotConnected => 'منسلک نہیں';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return '$duration پہلے منقطع';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count سبسکرپشنز';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count ایونٹس';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration پہلے';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine غیر مرکزی اشاعت کے لیے Nostr پروٹوکول استعمال کرتا ہے۔ آپ کا مواد آپ کے منتخب کردہ ریلے پر رہتا ہے، اور آپ کی کلیدیں ہی آپ کی شناخت ہیں۔';

  @override
  String get nostrSettingsSectionNetwork => 'نیٹ ورک';

  @override
  String get nostrSettingsSectionAccount => 'اکاؤنٹ';

  @override
  String get nostrSettingsSectionDangerZone => 'خطرناک زون';

  @override
  String get nostrSettingsRelays => 'ریلے';

  @override
  String get nostrSettingsRelaysSubtitle => 'Nostr ریلے کنکشنز کا انتظام کریں';

  @override
  String get nostrSettingsRelayDiagnostics => 'ریلے تشخیص';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'ریلے کنکٹیویٹی اور نیٹ ورک مسائل کی ڈیبگنگ کریں';

  @override
  String get nostrSettingsMediaServers => 'میڈیا سرورز';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Blossom اپلوڈ سرورز کنفیگر کریں';

  @override
  String get settingsDeveloperOptions => 'ڈویلپر اختیارات';

  @override
  String get settingsDeveloperOptionsSubtitle => 'ماحول سوئچر اور ڈیبگ ترتیبات';

  @override
  String get nostrSettingsKeyManagement => 'کلید مینجمنٹ';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'اپنی Nostr کلیدیں ایکسپورٹ، بیک اپ اور بحال کریں';

  @override
  String get nostrSettingsClientAttribution => 'کلائنٹ انتساب';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'آپ کے شائع کردہ ایونٹس پر Divine کلائنٹ ٹیگ شامل کریں تاکہ دیگر Nostr ایپس انہیں درست طریقے سے منسوب کر سکیں۔ اس کے بغیر، آپ کی بھیجی گئی رپورٹس ہمارے ماڈریٹرز کے جائزے میں کم وزن رکھتی ہیں۔';

  @override
  String get nostrSettingsMoveAccount => 'اپنا اکاؤنٹ منتقل کریں';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'اپنا آرکائیو ڈاؤن لوڈ کریں اور اپنی پوسٹس اور ویڈیوز کو کسی اور ریلے یا میڈیا سرور پر منتقل کریں۔';

  @override
  String get nostrSettingsRemoveKeys => 'اس اکاؤنٹ کو اس ڈیوائس سے ہٹائیں';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'اس ڈیوائس سے اس اکاؤنٹ کا مقامی لاگ اِن ہٹائیں۔ اس اکاؤنٹ کے مقامی مسودے اور کلپس محفوظ رہیں گے۔';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'اس اکاؤنٹ کو اس ڈیوائس سے نہیں ہٹایا جا سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get nostrSettingsDeleteAccount => 'اکاؤنٹ اور ڈیٹا حذف کریں';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'آپ کے مواد کے لیے حذف کی درخواستیں بھیجتا ہے اور اس ڈیوائس پر آپ کو سائن آؤٹ کرتا ہے۔ ریلے، کلائنٹس، سرچ انڈیکسز اور دیگر سائن اِن ڈیوائسز کے پاس کاپیاں رہ سکتی ہیں۔';

  @override
  String get relayDiagnosticTitle => 'ریلے تشخیص';

  @override
  String get relayDiagnosticRefreshTooltip => 'تشخیص ریفریش کریں';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'آخری ریفریش: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'ریلے اسٹیٹس';

  @override
  String get relayDiagnosticInitialized => 'تیار شدہ';

  @override
  String get relayDiagnosticReady => 'تیار';

  @override
  String get relayDiagnosticNotInitialized => 'تیار نہیں ہوا';

  @override
  String get relayDiagnosticDatabaseEvents => 'ڈیٹابیس ایونٹس';

  @override
  String get relayDiagnosticActiveSubscriptions => 'فعال سبسکرپشنز';

  @override
  String get relayDiagnosticExternalRelays => 'بیرونی ریلے';

  @override
  String get relayDiagnosticConfigured => 'کنفیگر شدہ';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count ریلے';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'منسلک';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'ویڈیو ایونٹس';

  @override
  String get relayDiagnosticHomeFeed => 'ہوم فیڈ';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count ویڈیوز';
  }

  @override
  String get relayDiagnosticDiscovery => 'دریافت';

  @override
  String get relayDiagnosticLoading => 'لوڈ ہو رہا ہے';

  @override
  String get relayDiagnosticYes => 'ہاں';

  @override
  String get relayDiagnosticNo => 'نہیں';

  @override
  String get relayDiagnosticTestDirectQuery => 'براہ راست استفسار ٹیسٹ کریں';

  @override
  String get relayDiagnosticNetworkConnectivity => 'نیٹ ورک کنکٹیویٹی';

  @override
  String get relayDiagnosticRunNetworkTest => 'نیٹ ورک ٹیسٹ چلائیں';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom سرور';

  @override
  String get relayDiagnosticTestAllEndpoints => 'تمام اینڈ پوائنٹس ٹیسٹ کریں';

  @override
  String get relayDiagnosticStatus => 'اسٹیٹس';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'خرابی';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'بیس URL';

  @override
  String get relayDiagnosticSummary => 'خلاصہ';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount ٹھیک (اوسط ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'سب دوبارہ ٹیسٹ کریں';

  @override
  String get relayDiagnosticRetrying => 'دوبارہ کوشش ہو رہی ہے...';

  @override
  String get relayDiagnosticRetryConnection => 'کنکشن دوبارہ کوشش کریں';

  @override
  String get relayDiagnosticTroubleshooting => 'خرابی کا ازالہ';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• سبز اسٹیٹس = منسلک اور کام کر رہا ہے\n• سرخ اسٹیٹس = کنکشن ناکام\n• اگر نیٹ ورک ٹیسٹ ناکام ہو تو انٹرنیٹ کنکشن چیک کریں\n• اگر ریلے کنفیگر ہیں مگر منسلک نہیں تو \"کنکشن دوبارہ کوشش کریں\" پر ٹیپ کریں\n• ڈیبگنگ کے لیے اس اسکرین کا اسکرین شاٹ لیں';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'تمام REST اینڈ پوائنٹس صحت مند ہیں!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'کچھ REST اینڈ پوائنٹس ناکام ہوئے — تفصیلات اوپر دیکھیں';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'ڈیٹابیس میں $count ویڈیو ایونٹس ملے';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'استفسار ناکام۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '$count ریلے سے منسلک!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'کسی بھی ریلے سے منسلک نہیں ہو سکا';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'کنکشن کی دوبارہ کوشش ناکام۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'منسلک اور تصدیق شدہ';

  @override
  String get relayDiagnosticConnectedOnly => 'منسلک';

  @override
  String get relayDiagnosticNotConnected => 'منسلک نہیں';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'کوئی ریلے کنفیگر نہیں';

  @override
  String get relayDiagnosticFailed => 'ناکام';

  @override
  String get notificationSettingsTitle => 'اطلاعات';

  @override
  String get notificationSettingsResetTooltip => 'ڈیفالٹ پر ری سیٹ کریں';

  @override
  String get notificationSettingsTypes => 'اطلاعات کی اقسام';

  @override
  String get notificationSettingsLikes => 'پسندیں';

  @override
  String get notificationSettingsLikesSubtitle =>
      'جب کوئی آپ کی ویڈیوز پسند کرے';

  @override
  String get notificationSettingsComments => 'تبصرے';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'جب کوئی آپ کی ویڈیوز پر تبصرہ کرے';

  @override
  String get notificationSettingsFollows => 'فالو';

  @override
  String get notificationSettingsFollowsSubtitle => 'جب کوئی آپ کو فالو کرے';

  @override
  String get notificationSettingsMentions => 'ذکر';

  @override
  String get notificationSettingsMentionsSubtitle => 'جب آپ کا ذکر ہو';

  @override
  String get notificationSettingsReposts => 'ریپوسٹس';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'جب کوئی آپ کی ویڈیوز ریپوسٹ کرے';

  @override
  String get notificationSettingsNewPosts => 'نئی ویڈیوز';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'جب آپ کا فالو کردہ کوئی شخص پوسٹ کرے';

  @override
  String get notificationSettingsActions => 'کارروائیاں';

  @override
  String get notificationSettingsMarkAllAsRead => 'سب کو پڑھا ہوا قرار دیں';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'تمام اطلاعات کو پڑھا ہوا قرار دیں';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'تمام اطلاعات پڑھی ہوئی قرار دے دی گئیں';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'سب کو پڑھا ہوا قرار دینا ناکام';

  @override
  String get notificationSettingsResetToDefaults =>
      'ترتیبات ڈیفالٹ پر ری سیٹ ہو گئیں';

  @override
  String get notificationSettingsAbout => 'اطلاعات کے بارے میں';

  @override
  String get notificationSettingsAboutDescription =>
      'اطلاعات Nostr پروٹوکول پر چلتی ہیں۔ ریئل ٹائم اپڈیٹس کا انحصار Nostr ریلے سے آپ کے کنکشن پر ہے۔ کچھ اطلاعات میں تاخیر ہو سکتی ہے۔';

  @override
  String get safetySettingsWhatYouSee => 'آپ کیا دیکھتے ہیں';

  @override
  String get safetySettingsWhatYouPublish => 'آپ کیا شائع کرتے ہیں';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'صرف Divine ہوسٹ شدہ ویڈیوز دکھائیں';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'دیگر میڈیا ہوسٹس سے پیش کی جانے والی ویڈیوز چھپائیں';

  @override
  String get safetySettingsModeration => 'موڈریشن';

  @override
  String get safetySettingsBlockedUsers => 'بلاک شدہ صارفین';

  @override
  String get safetySettingsAgeVerification => 'عمر کی تصدیق';

  @override
  String get safetySettingsAgeConfirmation =>
      'میں تصدیق کرتا ہوں کہ میری عمر 18 سال یا اس سے زیادہ ہے';

  @override
  String get safetySettingsAgeRequired => 'بالغ مواد دیکھنے کے لیے درکار';

  @override
  String get safetySettingsAgeLockedForMinor => 'آپ کے اکاؤنٹ کے لیے مقفل';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'سرکاری موڈریشن سروس (ڈیفالٹ طور پر فعال)';

  @override
  String get safetySettingsPeopleIFollow => 'میرے فالو کیے ہوئے لوگ';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'آپ کے فالو کیے ہوئے لوگوں کے لیبلز سبسکرائب کریں';

  @override
  String get safetySettingsAddCustomLabeler => 'کسٹم لیبلر شامل کریں';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub درج کریں...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'کسٹم لیبلر شامل کریں';

  @override
  String get safetySettingsRemoveLabeler => 'لیبلر ہٹائیں';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'npub ایڈریس درج کریں';

  @override
  String get safetySettingsNoBlockedUsers => 'کوئی بلاک شدہ صارف نہیں';

  @override
  String get safetySettingsUnblock => 'ان بلاک کریں';

  @override
  String get safetySettingsUserUnblocked => 'صارف ان بلاک ہو گیا';

  @override
  String get safetySettingsCancel => 'منسوخ کریں';

  @override
  String get safetySettingsAdd => 'شامل کریں';

  @override
  String get analyticsTitle => 'کریئیٹر تجزیات';

  @override
  String get analyticsDiagnosticsTooltip => 'تشخیص';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'تشخیص ٹوگل کریں';

  @override
  String get analyticsRetry => 'دوبارہ کوشش کریں';

  @override
  String get analyticsUnableToLoad => 'تجزیات لوڈ نہیں ہو سکے۔';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'کریئیٹر تجزیات دیکھنے کے لیے سائن ان کریں۔';

  @override
  String get analyticsViewDataUnavailable =>
      'ان پوسٹس کے لیے ریلے سے ویوز فی الحال دستیاب نہیں ہیں۔ پسند/تبصرہ/ریپوسٹ میٹرکس پھر بھی درست ہیں۔';

  @override
  String get analyticsViewDataTitle => 'ویوز ڈیٹا';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'اپڈیٹ $time • اسکورز دستیاب ہونے پر Funnelcake سے پسندیں، تبصرے، ریپوسٹس اور ویوز/لوپ استعمال کرتے ہیں۔';
  }

  @override
  String get analyticsVideos => 'ویڈیوز';

  @override
  String get analyticsViews => 'ویوز';

  @override
  String get analyticsInteractions => 'تفاعلات';

  @override
  String get analyticsEngagement => 'مصروفیت';

  @override
  String get analyticsFollowers => 'فالوورز';

  @override
  String get analyticsAvgPerPost => 'اوسط/پوسٹ';

  @override
  String get analyticsInteractionMix => 'تفاعلات کا امتزاج';

  @override
  String get analyticsLikes => 'پسندیں';

  @override
  String get analyticsComments => 'تبصرے';

  @override
  String get analyticsReposts => 'ریپوسٹس';

  @override
  String get analyticsPerformanceHighlights => 'کارکردگی کی جھلکیاں';

  @override
  String get analyticsMostViewed => 'سب سے زیادہ دیکھی گئی';

  @override
  String get analyticsMostDiscussed => 'سب سے زیادہ زیر بحث';

  @override
  String get analyticsMostReposted => 'سب سے زیادہ ریپوسٹ شدہ';

  @override
  String get analyticsNoVideosYet => 'ابھی کوئی ویڈیو نہیں';

  @override
  String get analyticsViewDataUnavailableShort => 'ویوز ڈیٹا دستیاب نہیں';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count ویوز';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count تبصرے';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count ریپوسٹس';
  }

  @override
  String get analyticsTopContent => 'سرفہرست مواد';

  @override
  String get analyticsPublishPrompt =>
      'رینکنگ دیکھنے کے لیے کچھ ویڈیوز شائع کریں۔';

  @override
  String get analyticsEngagementRateExplainer =>
      'دائیں طرف کی % = مصروفیت کی شرح (تفاعلات تقسیم ویوز)۔';

  @override
  String get analyticsEngagementRateNoViews =>
      'مصروفیت کی شرح کو ویوز ڈیٹا درکار ہے؛ ویوز دستیاب ہونے تک اقدار N/A دکھائیں گی۔';

  @override
  String get analyticsEngagementLabel => 'مصروفیت';

  @override
  String get analyticsViewsUnavailable => 'ویوز دستیاب نہیں';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count تفاعلات';
  }

  @override
  String get analyticsPostAnalytics => 'پوسٹ تجزیات';

  @override
  String get analyticsOpenPost => 'پوسٹ کھولیں';

  @override
  String get analyticsRecentDailyInteractions => 'حالیہ روزانہ تفاعلات';

  @override
  String get analyticsNoActivityYet => 'اس دورانیے میں ابھی کوئی سرگرمی نہیں۔';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'تفاعلات = پوسٹ کی تاریخ کے مطابق پسندیں + تبصرے + ریپوسٹس۔';

  @override
  String get analyticsDailyBarExplainer =>
      'بار کی لمبائی اس ونڈو میں آپ کے سب سے اونچے دن کے حساب سے ہے۔';

  @override
  String get analyticsAudienceSnapshot => 'سامعین کی جھلک';

  @override
  String analyticsFollowersCount(String count) {
    return 'فالوورز: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'فالوئنگ: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'جیسے جیسے Funnelcake سامعین کے تجزیات اینڈ پوائنٹس شامل کرے گا، سامعین کے ذریعہ/جغرافیہ/وقت کی تفصیلات بھر جائیں گی۔';

  @override
  String get analyticsRetention => 'برقراری';

  @override
  String get analyticsRetentionWithViews =>
      'جب Funnelcake سے فی سیکنڈ/فی بکٹ برقراری آ جائے گی تو برقراری منحنی اور دیکھنے کے وقت کی تفصیل نظر آئے گی۔';

  @override
  String get analyticsRetentionWithoutViews =>
      'جب تک Funnelcake ویوز + دیکھنے کے وقت کے تجزیات نہیں دیتا، برقراری ڈیٹا دستیاب نہیں ہوگا۔';

  @override
  String get analyticsDiagnostics => 'تشخیص';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'کل ویڈیوز: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'ویوز والی: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'غائب ویوز: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'ہائیڈریٹڈ (بلک): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'ہائیڈریٹڈ (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'ذرائع: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'فکسچر ڈیٹا استعمال کریں';

  @override
  String get analyticsNa => 'لاگو نہیں';

  @override
  String get authCreateNewAccount => 'نیا Divine اکاؤنٹ بنائیں';

  @override
  String get authCreateNewAccountShort => 'نیا اکاؤنٹ بنائیں';

  @override
  String get authSignInDifferentAccount => 'موجودہ اکاؤنٹ سے سائن ان کریں';

  @override
  String get authUseAnotherAccount => 'دوسرا اکاؤنٹ استعمال کریں';

  @override
  String authContinueAs(String displayName) {
    return '$displayName کے طور پر جاری رکھیں';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'آپ کے مسودے اور کلپس اس اکاؤنٹ کے لیے محفوظ ہیں';

  @override
  String get authRecoveryOtherAccountWarning =>
      'یہاں سائن ان کرنے سے وہ مسودے اور کلپس چھپ جائیں گے';

  @override
  String get authTermsPrefix =>
      'نیچے کوئی آپشن منتخب کر کے، آپ تصدیق کرتے ہیں کہ آپ کی عمر کم از کم 16 سال ہے (یا آپ نے ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine عمر کی اجازت';

  @override
  String get authTermsAfterAgeAuthorization => ' مکمل کر لی ہے) اور آپ ';

  @override
  String get authTermsOfService => 'شرائطِ خدمت';

  @override
  String get authPrivacyPolicy => 'رازداری کی پالیسی';

  @override
  String get authTermsAnd => '، اور ';

  @override
  String get authSafetyStandards => 'حفاظتی معیارات سے متفق ہیں';

  @override
  String get authAmberNotInstalled => 'Amber ایپ انسٹال نہیں ہے';

  @override
  String get authAmberConnectionFailed => 'Amber سے منسلک نہیں ہو سکا';

  @override
  String get authPasswordResetSent =>
      'اگر اس ای میل سے کوئی اکاؤنٹ موجود ہے تو پاس ورڈ ری سیٹ لنک بھیج دیا گیا ہے۔';

  @override
  String get authSignInTitle => 'سائن ان کریں';

  @override
  String get authEmailLabel => 'ای میل';

  @override
  String get authPasswordLabel => 'پاس ورڈ';

  @override
  String get authConfirmPasswordLabel => 'پاس ورڈ کی تصدیق کریں';

  @override
  String get authEmailRequired => 'ای میل درکار ہے';

  @override
  String get authEmailInvalid => 'براہ کرم درست ای میل درج کریں';

  @override
  String get authPasswordRequired => 'پاس ورڈ درکار ہے';

  @override
  String get authConfirmPasswordRequired =>
      'براہ کرم اپنے پاس ورڈ کی تصدیق کریں';

  @override
  String get authPasswordsDoNotMatch => 'پاس ورڈ میل نہیں کھاتے';

  @override
  String get authForgotPassword => 'پاس ورڈ بھول گئے؟';

  @override
  String get authImportNostrKey => 'Nostr کلید درآمد کریں';

  @override
  String get authConnectSignerApp => 'سائنر ایپ سے منسلک ہوں';

  @override
  String get authSignInWithAmber => 'Amber سے سائن ان کریں';

  @override
  String get authSignInWithBrowserExtension =>
      'براؤزر ایکسٹینشن سے سائن ان کریں';

  @override
  String get authNip07ConnectionFailed =>
      'آپ کی براؤزر ایکسٹینشن سے منسلک نہیں ہو سکا۔';

  @override
  String get authNip07ExtensionNotFound =>
      'کوئی براؤزر ایکسٹینشن نہیں ملی۔ Alby، nos2x یا کوئی اور NIP-07 ہم آہنگ ایکسٹینشن انسٹال کریں۔';

  @override
  String get authSignInOptionsTitle => 'سائن ان اختیارات';

  @override
  String get authInfoEmailPasswordTitle => 'ای میل اور پاس ورڈ';

  @override
  String get authInfoEmailPasswordDescription =>
      'اپنے Divine اکاؤنٹ سے سائن ان کریں۔ اگر آپ نے ای میل اور پاس ورڈ سے رجسٹر کیا تھا تو وہ یہاں استعمال کریں۔';

  @override
  String get authInfoImportNostrKeyDescription =>
      'پہلے سے Nostr شناخت رکھتے ہیں؟ کسی اور کلائنٹ سے اپنی nsec نجی کلید درآمد کریں۔';

  @override
  String get authInfoSignerAppTitle => 'سائنر ایپ';

  @override
  String get authInfoSignerAppDescription =>
      'بہتر کلید سیکیورٹی کے لیے nsecBunker جیسے NIP-46 ہم آہنگ ریموٹ سائنر سے منسلک ہوں۔';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'اپنی Nostr کلیدیں محفوظ طریقے سے سنبھالنے کے لیے Android پر Amber سائنر ایپ استعمال کریں۔';

  @override
  String get authInfoBrowserExtensionTitle => 'براؤزر ایکسٹینشن';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Alby یا nos2x جیسی NIP-07 براؤزر ایکسٹینشن سے سائن ان کریں۔ آپ کی کلیدیں ایکسٹینشن میں ہی رہتی ہیں — Divine انہیں کبھی نہیں دیکھتا۔';

  @override
  String get authSignInErrorInvalidCredentials =>
      'ای میل یا پاس ورڈ غلط ہے۔ ایک بار پھر کوشش کریں۔';

  @override
  String get authSignInErrorEmailNotVerified =>
      'سائن ان سے پہلے اپنی ای میل کی تصدیق کریں — لنک کے لیے اپنا ان باکس چیک کریں۔';

  @override
  String get authSignInErrorInvalidEmail => 'یہ درست ای میل ایڈریس نہیں لگتا۔';

  @override
  String get authSignInErrorNetwork =>
      'سرور تک رسائی نہیں ہو رہی۔ اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get authSignInErrorGeneric =>
      'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get authSignInOptionsHintPrefix =>
      'پچھلی بار کیسے داخل ہوئے تھے، یاد نہیں؟ ';

  @override
  String get authSignInOptionsHintCta => 'ہر سائن ان آپشن دیکھیں';

  @override
  String get authCreateAccountTitle => 'اکاؤنٹ بنائیں';

  @override
  String get authBackToInviteCode => 'دعوتی کوڈ پر واپس';

  @override
  String get authUseDivineNoBackup => 'بغیر بیک اپ کے Divine استعمال کریں';

  @override
  String get authSkipConfirmTitle => 'ایک آخری بات...';

  @override
  String get authSkipConfirmKeyCreated =>
      'آپ داخل ہو گئے! ہم ایک محفوظ کلید بنائیں گے جو آپ کے Divine اکاؤنٹ کو چلائے گی۔';

  @override
  String get authSkipConfirmKeyOnly =>
      'ای میل کے بغیر، آپ کی کلید ہی واحد طریقہ ہے جس سے Divine جانتا ہے کہ یہ اکاؤنٹ آپ کا ہے۔';

  @override
  String get authSkipConfirmRecommendEmail =>
      'آپ ایپ میں اپنی کلید تک رسائی کر سکتے ہیں، لیکن اگر آپ تکنیکی نہیں ہیں تو ہم تجویز کرتے ہیں کہ ابھی ای میل اور پاس ورڈ شامل کر لیں۔ اس ڈیوائس کے کھونے یا ری سیٹ ہونے پر سائن ان اور اکاؤنٹ بحال کرنا آسان ہو جاتا ہے۔';

  @override
  String get authAddEmailPassword => 'ای میل اور پاس ورڈ شامل کریں';

  @override
  String get authUseThisDeviceOnly => 'صرف اس ڈیوائس پر استعمال کریں';

  @override
  String get authCompleteRegistration => 'اپنی رجسٹریشن مکمل کریں';

  @override
  String get authVerifying => 'تصدیق ہو رہی ہے...';

  @override
  String get authVerificationLinkSent => 'ہم نے تصدیقی لنک بھیجا ہے:';

  @override
  String get authClickVerificationLink =>
      'اپنی رجسٹریشن مکمل کرنے کے لیے\nاپنی ای میل میں دیے گئے لنک پر کلک کریں۔';

  @override
  String get authPleaseWaitVerifying =>
      'براہ کرم انتظار کریں، ہم آپ کی ای میل کی تصدیق کر رہے ہیں...';

  @override
  String get authWaitingForVerification => 'تصدیق کا انتظار ہے';

  @override
  String get authOpenEmailApp => 'ای میل ایپ کھولیں';

  @override
  String get authVerificationPinPrompt =>
      'یا اپنی ای میل سے 6 ہندسوں کا کوڈ درج کریں';

  @override
  String get authVerificationPinFieldLabel => '6 ہندسوں کا کوڈ';

  @override
  String get authVerificationPinSubmit => 'کوڈ کی تصدیق کریں';

  @override
  String get authVerificationResendPrompt => 'نہیں ملا؟';

  @override
  String get authVerificationResend => 'دوبارہ بھیجیں';

  @override
  String authVerificationResendCooldown(String time) {
    return '$time میں دوبارہ بھیجیں';
  }

  @override
  String get authVerificationResendFailed =>
      'ہم ای میل دوبارہ نہیں بھیج سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get authVerificationResendExpired =>
      'یہ سائن اپ ختم ہو گیا۔ نیا کوڈ حاصل کرنے کے لیے دوبارہ شروع کریں۔';

  @override
  String get authVerificationResendUnavailable =>
      'ابھی دوبارہ بھیجنا دستیاب نہیں ہے۔ جو ای میل ہم پہلے ہی بھیج چکے ہیں، اس میں موجود 6 ہندسوں کا کوڈ استعمال کریں۔';

  @override
  String get authVerificationPollingStopped =>
      'ہم نے آپ کے لیے چیک کرنا بند کر دیا ہے۔ سائن ان مکمل کرنے کے لیے اپنی ای میل میں موجود 6 ہندسوں کا کوڈ درج کریں۔';

  @override
  String get authWelcomeToDivine => 'Divine میں خوش آمدید!';

  @override
  String get authEmailVerified => 'آپ کی ای میل کی تصدیق ہو گئی ہے۔';

  @override
  String get authSigningYouIn => 'آپ کو سائن ان کیا جا رہا ہے';

  @override
  String get authErrorTitle => 'اوہ اوہ۔';

  @override
  String get authVerificationFailed =>
      'ہم آپ کی ای میل کی تصدیق نہیں کر سکے۔\nبراہ کرم دوبارہ کوشش کریں۔';

  @override
  String get authStartOver => 'دوبارہ شروع کریں';

  @override
  String get authEmailVerifiedLogin =>
      'ای میل تصدیق ہو گئی! جاری رکھنے کے لیے لاگ ان کریں۔';

  @override
  String get authVerificationLinkExpired => 'یہ تصدیقی لنک اب درست نہیں رہا۔';

  @override
  String get authVerificationConnectionError =>
      'ای میل کی تصدیق نہیں ہو سکی۔ براہ کرم اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get authWaitlistConfirmTitle => 'آپ شامل ہو گئے!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'ہم $email پر اپڈیٹس بھیجیں گے۔\nجب مزید دعوتی کوڈز دستیاب ہوں گے، ہم آپ کو بھیج دیں گے۔';
  }

  @override
  String get authOk => 'ٹھیک ہے';

  @override
  String get authTryAgain => 'دوبارہ کوشش کریں';

  @override
  String get authContactSupport => 'سپورٹ سے رابطہ کریں';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email نہیں کھل سکا';
  }

  @override
  String get authAddInviteCode => 'اپنا دعوتی کوڈ درج کریں';

  @override
  String get authInviteCodeLabel => 'دعوتی کوڈ';

  @override
  String get authEnterYourCode => 'اپنا کوڈ درج کریں';

  @override
  String get authNext => 'آگے';

  @override
  String get authJoinWaitlist => 'ویٹ لسٹ میں شامل ہوں';

  @override
  String get authJoinWaitlistTitle => 'ویٹ لسٹ میں شامل ہوں';

  @override
  String get authJoinWaitlistDescription =>
      'اپنی ای میل بتائیں اور رسائی کھلنے پر ہم آپ کو دعوتی کوڈ بھیج دیں گے۔';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'مجھے Divine کی تحریک بھیجیں';

  @override
  String get authInviteAccessHelp => 'دعوتی رسائی میں مدد';

  @override
  String get authGeneratingConnection => 'کنکشن بنایا جا رہا ہے...';

  @override
  String get authConnectedAuthenticating => 'منسلک! تصدیق ہو رہی ہے...';

  @override
  String get authConnectionTimedOut => 'کنکشن کا وقت ختم ہو گیا';

  @override
  String get authApproveConnection =>
      'یقینی بنائیں کہ آپ نے اپنی سائنر ایپ میں کنکشن کی منظوری دی ہے۔';

  @override
  String get authConnectionCancelled => 'کنکشن منسوخ ہو گیا';

  @override
  String get authConnectionCancelledMessage => 'کنکشن منسوخ کر دیا گیا۔';

  @override
  String get authConnectionFailed => 'کنکشن ناکام';

  @override
  String get authUnknownError => 'ایک نامعلوم خرابی پیش آئی۔';

  @override
  String get authNostrConnectStartFailed =>
      'سائنر تک رسائی نہیں ہو سکی۔ اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get authNostrConnectInvalidSession =>
      'یہ کنکشن لنک اب درست نہیں رہا۔ نیا شروع کریں۔';

  @override
  String get authNostrConnectSetupFailed =>
      'بس قریب تھے — ہم آپ کا سائن ان مکمل نہیں کر سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get authUrlCopied => 'URL کلپ بورڈ پر کاپی ہو گیا';

  @override
  String get authConnectToDivine => 'Divine سے منسلک ہوں';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL پیسٹ کریں';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'bunker URL غلط ہے۔ اس کا آغاز bunker:// سے ہونا چاہیے';

  @override
  String get authScanSignerApp =>
      'منسلک ہونے کے لیے اپنی\nسائنر ایپ سے اسکین کریں۔';

  @override
  String authWaitingForConnection(int seconds) {
    return 'کنکشن کا انتظار... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'URL کاپی کریں';

  @override
  String get authShare => 'شیئر';

  @override
  String get authAddBunker => 'bunker شامل کریں';

  @override
  String get authCompatibleSignerApps => 'ہم آہنگ سائنر ایپس';

  @override
  String get authFailedToConnect => 'منسلک نہیں ہو سکا';

  @override
  String get authResetPasswordTitle => 'پاس ورڈ ری سیٹ کریں';

  @override
  String get authResetPasswordSubtitle =>
      'براہ کرم اپنا نیا پاس ورڈ درج کریں۔ یہ کم از کم 8 حروف کا ہونا چاہیے۔';

  @override
  String get authNewPasswordLabel => 'نیا پاس ورڈ';

  @override
  String get authConfirmNewPasswordLabel => 'نئے پاس ورڈ کی تصدیق کریں';

  @override
  String get authPasswordTooShort => 'پاس ورڈ کم از کم 8 حروف کا ہونا چاہیے';

  @override
  String get authPasswordResetSuccess =>
      'پاس ورڈ ری سیٹ کامیاب۔ براہ کرم لاگ ان کریں۔';

  @override
  String get authPasswordResetFailed => 'پاس ورڈ ری سیٹ ناکام';

  @override
  String get authUnexpectedError =>
      'ایک غیر متوقع خرابی پیش آئی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get authUpdatePassword => 'پاس ورڈ اپڈیٹ کریں';

  @override
  String get authSecureAccountTitle => 'اکاؤنٹ محفوظ کریں';

  @override
  String get authUnableToAccessKeys =>
      'آپ کی کلیدوں تک رسائی نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get authRegistrationFailed => 'رجسٹریشن ناکام';

  @override
  String get authRegistrationComplete =>
      'رجسٹریشن مکمل۔ براہ کرم اپنی ای میل چیک کریں۔';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'ری سیٹ ای میل نہیں بھیجی جا سکی۔';

  @override
  String get authSending => 'بھیجا جا رہا ہے...';

  @override
  String get authSignInButton => 'سائن ان کریں';

  @override
  String get authVerificationErrorTimeout =>
      'تصدیق کا وقت ختم ہو گیا۔ براہ کرم دوبارہ رجسٹر کریں۔';

  @override
  String get authVerificationErrorMissingCode =>
      'تصدیق ناکام — اجازتی کوڈ غائب ہے۔';

  @override
  String get authVerificationErrorPollFailed =>
      'تصدیق ناکام۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get authVerificationErrorNetworkExchange =>
      'سائن ان کے دوران نیٹ ورک خرابی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get authVerificationErrorOAuthExchange =>
      'تصدیق ناکام۔ براہ کرم دوبارہ رجسٹر کریں۔';

  @override
  String get authVerificationErrorSignInFailed =>
      'سائن ان ناکام۔ براہ کرم دستی طور پر لاگ ان کر کے دیکھیں۔';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'یہ ای میل پہلے سے رجسٹر ہے۔ اس کے بجائے سائن ان کریں۔';

  @override
  String get authVerificationErrorPinInvalid =>
      'وہ کوڈ میل نہیں کھایا۔ اچھی طرح چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get authVerificationErrorPinExpired =>
      'اس کوڈ کی میعاد ختم ہو گئی ہے۔ نیا کوڈ پانے کے لیے دوبارہ بھیجیں پر ٹیپ کریں۔';

  @override
  String get authVerificationErrorPinLocked =>
      'بہت زیادہ کوششیں۔ تازہ کوڈ پانے کے لیے دوبارہ بھیجیں پر ٹیپ کریں۔';

  @override
  String get authVerificationErrorPinFailed =>
      'ہم اس کوڈ کی تصدیق نہیں کر سکے۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get authVerificationErrorPinUnavailable =>
      'کوڈ درج کرنا فی الحال دستیاب نہیں۔ اپنی ای میل میں دیا گیا لنک کھولیں، یا تازہ کوڈ کے لیے دوبارہ بھیجیں۔';

  @override
  String get authInviteCodeErrorMalformed =>
      'ABCD-EFGH جیسا دعوتی کوڈ درج کریں۔';

  @override
  String get authInviteCodeErrorNotFound => 'یہ دعوتی کوڈ درست نہیں لگتا۔';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'یہ دعوتی کوڈ پہلے ہی استعمال ہو چکا ہے یا منسوخ کر دیا گیا ہے۔';

  @override
  String get authInviteGateErrorCreatorFull =>
      'اس تخلیق کار کی دعوتیں ختم ہو چکی ہیں';

  @override
  String get authInviteGateErrorUnavailable =>
      'یہ دعوتی کوڈ دستیاب نہیں ہے۔ ویٹ لسٹ میں شامل ہوں، جگہ بنتے ہی ہم دعوت بھیج دیں گے۔';

  @override
  String get authInviteGateErrorCheckFailed =>
      'ہم اس کوڈ کی تصدیق نہیں کر سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get authInviteGateErrorUnknown =>
      'کچھ غلط ہو گیا۔ اپنا دعوتی کوڈ دوبارہ آزمائیں۔';

  @override
  String get authInviteErrorAlreadyUsed =>
      'وہ دعوتی کوڈ اب دستیاب نہیں رہا۔ اپنے دعوتی کوڈ پر واپس جائیں، ویٹ لسٹ میں شامل ہوں، یا سپورٹ سے رابطہ کریں۔';

  @override
  String get authInviteErrorInvalid =>
      'وہ دعوتی کوڈ فی الحال استعمال نہیں ہو سکتا۔ اپنے دعوتی کوڈ پر واپس جائیں، ویٹ لسٹ میں شامل ہوں، یا سپورٹ سے رابطہ کریں۔';

  @override
  String get authInviteErrorTemporary =>
      'ہم فی الحال آپ کی دعوت کی تصدیق نہیں کر سکے۔ اپنے دعوتی کوڈ پر واپس جا کر دوبارہ کوشش کریں، یا سپورٹ سے رابطہ کریں۔';

  @override
  String get authInviteErrorUnknown =>
      'ہم آپ کی دعوت فعال نہیں کر سکے۔ اپنے دعوتی کوڈ پر واپس جائیں، ویٹ لسٹ میں شامل ہوں، یا سپورٹ سے رابطہ کریں۔';

  @override
  String get shareSheetSave => 'محفوظ کریں';

  @override
  String get shareSheetRemoveFromSaved => 'محفوظات سے ہٹائیں';

  @override
  String get shareSheetSaveToGallery => 'گیلری میں محفوظ کریں';

  @override
  String get shareSheetSaveWithWatermark => 'واٹر مارک کے ساتھ محفوظ کریں';

  @override
  String get shareSheetSaveVideo => 'ویڈیو محفوظ کریں';

  @override
  String get shareSheetAddToClips => 'کلپس میں شامل کریں';

  @override
  String get shareSheetNameClipTitle => 'اس کلپ کا نام رکھیں';

  @override
  String get shareSheetNameClipSubtitle =>
      'ایسا نام منتخب کریں جو آپ اپنی لائبریری میں پہچان سکیں۔';

  @override
  String get shareSheetClipTitleLabel => 'کلپ کا عنوان';

  @override
  String get shareSheetSaveClip => 'کلپ محفوظ کریں';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\" کلپس میں محفوظ ہو گیا';
  }

  @override
  String get shareSheetUntitledClip => 'بلا عنوان کلپ';

  @override
  String get shareSheetAddToClipsFailed => 'کلپس میں شامل نہیں ہو سکا';

  @override
  String get shareSheetAddToList => 'فہرست میں شامل کریں';

  @override
  String get shareSheetCopy => 'کاپی کریں';

  @override
  String get shareSheetShareVia => 'کے ذریعے شیئر کریں';

  @override
  String get shareSheetEventJson => 'ایونٹ JSON';

  @override
  String get shareSheetEventId => 'ایونٹ ID';

  @override
  String get shareSheetMoreActions => 'مزید کارروائیاں';

  @override
  String get shareSheetCrosspost => 'کراس پوسٹ';

  @override
  String get crosspostSheetTitle => 'یہ ویڈیو کراس پوسٹ کریں';

  @override
  String get crosspostSheetSubtitle =>
      'اسے اپنے منسلک پلیٹ فارمز پر بھیجیں۔ پوسٹنگ میں چند منٹ لگ سکتے ہیں۔';

  @override
  String get crosspostSubmit => 'کراس پوسٹ';

  @override
  String get crosspostStatusQueued => 'قطار میں';

  @override
  String get crosspostStatusUploading => 'اپلوڈ ہو رہا ہے';

  @override
  String get crosspostStatusProcessing => 'پروسیسنگ';

  @override
  String get crosspostStatusPosted => 'پوسٹ ہو گیا';

  @override
  String get crosspostStatusFailed => 'ناکام';

  @override
  String get crosspostStatusSkipped => 'چھوڑ دیا گیا';

  @override
  String get crosspostStatusNeedsReauth => 'دوبارہ منسلک کرنا ہوگا';

  @override
  String get crosspostViewPost => 'پوسٹ دیکھیں';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'پوسٹنگ جاری رکھنے کے لیے کراس پوسٹنگ ترتیبات میں $platform دوبارہ منسلک کریں۔';
  }

  @override
  String get crosspostReconnect => 'دوبارہ منسلک کریں';

  @override
  String get crosspostErrorNotOwner =>
      'صرف آپ کی اپنی ویڈیوز کراس پوسٹ ہو سکتی ہیں۔';

  @override
  String get crosspostErrorNotEligible =>
      'یہ ویڈیو کراس پوسٹنگ کی اہل نہیں ہے۔';

  @override
  String get crosspostErrorNotConnected => 'وہ پلیٹ فارم منسلک نہیں ہے۔';

  @override
  String get crosspostErrorUnauthorized =>
      'اپنا اکاؤنٹ دوبارہ منسلک کریں، پھر دوبارہ کوشش کریں۔';

  @override
  String get crosspostErrorNetwork =>
      'کراس پوسٹر تک رسائی نہیں ہو سکی۔ تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get crosspostFailedGeneric => 'کراس پوسٹ ناکام۔';

  @override
  String get crosspostStillWorking =>
      'کام جاری ہے۔ آپ یہ بند کر سکتے ہیں — پوسٹنگ پس منظر میں جاری رہے گی۔';

  @override
  String get crosspostDone => 'ہو گیا';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'کیمرہ رول میں محفوظ ہو گئی';

  @override
  String get watermarkDownloadShare => 'شیئر';

  @override
  String get watermarkDownloadDone => 'ہو گیا';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'تصاویر تک رسائی درکار ہے';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'ویڈیوز محفوظ کرنے کے لیے ترتیبات میں تصاویر تک رسائی کی اجازت دیں۔';

  @override
  String get watermarkDownloadOpenSettings => 'ترتیبات کھولیں';

  @override
  String get watermarkDownloadNotNow => 'ابھی نہیں';

  @override
  String get watermarkDownloadFailed => 'ڈاؤن لوڈ ناکام';

  @override
  String get watermarkDownloadDismiss => 'ہٹائیں';

  @override
  String get watermarkDownloadStageDownloading => 'ویڈیو ڈاؤن لوڈ ہو رہی ہے';

  @override
  String get watermarkDownloadStageWatermarking => 'واٹر مارک لگایا جا رہا ہے';

  @override
  String get watermarkDownloadStageSaving => 'کیمرہ رول میں محفوظ ہو رہی ہے';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'نیٹ ورک سے ویڈیو حاصل کی جا رہی ہے...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine واٹر مارک لگایا جا رہا ہے...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'واٹر مارک والی ویڈیو آپ کے کیمرہ رول میں محفوظ ہو رہی ہے...';

  @override
  String get shareMenuBookmarks => 'بک مارکس';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count فالو سیٹس دستیاب ہیں';
  }

  @override
  String get peopleListsAddToList => 'فہرست میں شامل کریں';

  @override
  String get peopleListsSheetTitle => 'فہرست میں شامل کریں';

  @override
  String get peopleListsEmptyTitle => 'ابھی کوئی فہرست نہیں';

  @override
  String get peopleListsEmptySubtitle =>
      'لوگوں کو گروہ میں باندھنے کے لیے فہرست بنائیں۔';

  @override
  String get peopleListsCreateList => 'فہرست بنائیں';

  @override
  String get peopleListsNewListTitle => 'نئی فہرست';

  @override
  String get peopleListsRouteTitle => 'لوگوں کی فہرست';

  @override
  String get peopleListsListNameLabel => 'فہرست کا نام';

  @override
  String get peopleListsListNameHint => 'قریبی دوست';

  @override
  String get peopleListsCreateButton => 'بنائیں';

  @override
  String get peopleListsAddPeopleTitle => 'لوگ شامل کریں';

  @override
  String get peopleListsAddPeopleTooltip => 'لوگ شامل کریں';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'فہرست میں لوگ شامل کریں';

  @override
  String get peopleListsListNotFoundTitle => 'فہرست نہیں ملی';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'فہرست نہیں ملی۔ ممکن ہے اسے حذف کر دیا گیا ہو۔';

  @override
  String get peopleListsListDeletedSubtitle =>
      'ممکن ہے یہ فہرست حذف کر دی گئی ہو۔';

  @override
  String get peopleListsNoPeopleTitle => 'اس فہرست میں کوئی نہیں';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'شروع کرنے کے لیے کچھ لوگ شامل کریں';

  @override
  String get peopleListsNoVideosTitle => 'ابھی کوئی ویڈیو نہیں';

  @override
  String get peopleListsNoVideosSubtitle =>
      'فہرست کے ممبران کی ویڈیوز یہاں نظر آئیں گی';

  @override
  String get peopleListsNoVideosAvailable => 'کوئی ویڈیو دستیاب نہیں';

  @override
  String get peopleListsFailedToLoadVideos => 'ویڈیوز لوڈ نہیں ہو سکیں';

  @override
  String get peopleListsVideoNotAvailable => 'ویڈیو دستیاب نہیں';

  @override
  String get peopleListsBackToGridTooltip => 'گرڈ پر واپس';

  @override
  String get peopleListsErrorLoadingVideos => 'ویڈیوز لوڈ کرنے میں خرابی';

  @override
  String get peopleListsNoPeopleToAdd =>
      'شامل کرنے کے لیے کوئی لوگ دستیاب نہیں۔';

  @override
  String peopleListsAddToListName(String name) {
    return '$name میں شامل کریں';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'لوگ تلاش کریں';

  @override
  String get peopleListsAddPeopleError =>
      'لوگ لوڈ نہیں ہو سکے۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get peopleListsAddPeopleRetry => 'دوبارہ کوشش کریں';

  @override
  String get peopleListsAddButton => 'شامل کریں';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count شامل کریں';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فہرستوں میں',
      one: '1 فہرست میں',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$name کو ہٹائیں؟';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'انہیں اس فہرست سے ہٹا دیا جائے گا۔';

  @override
  String get peopleListsRemove => 'ہٹائیں';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name کو فہرست سے ہٹا دیا گیا';
  }

  @override
  String get peopleListsUndo => 'واپس کریں';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return '$name کا پروفائل۔ ہٹانے کے لیے دیر تک دبائیں۔';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return '$name کا پروفائل دیکھیں';
  }

  @override
  String get shareMenuEditVideo => 'ویڈیو میں ترمیم کریں';

  @override
  String get shareMenuDeleteVideo => 'ویڈیو حذف کریں';

  @override
  String shareMenuVideoCount(int count) {
    return '$count ویڈیوز';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'یہ ویڈیو Divine سے مستقل طور پر حذف ہو جائے گی۔ دیگر ریلے استعمال کرنے والے تھرڈ پارٹی Nostr کلائنٹس پر یہ پھر بھی نظر آ سکتی ہے۔';

  @override
  String get shareMenuCancel => 'منسوخ کریں';

  @override
  String get shareMenuDelete => 'حذف کریں';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'حذف کرنے کی سہولت ابھی تیار نہیں۔ تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'آپ صرف اپنی ویڈیوز حذف کر سکتے ہیں۔';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'دوبارہ سائن ان کریں، پھر حذف کر کے دیکھیں۔';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'حذف کی درخواست پر دستخط نہیں ہو سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'ریلے نے حذف کی یہ درخواست قبول نہیں کی۔ تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'ریلے تک رسائی نہیں ہو سکی۔ اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'حذف ہو گیا۔ سب ریلے نے تصدیق نہیں کی، اس لیے یہ اب بھی دوسری ایپس میں دکھائی دے سکتا ہے۔';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'یہ ویڈیو حذف نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get shareMenuUpdate => 'اپڈیٹ کریں';

  @override
  String get shareMenuChangeCover => 'کور تبدیل کریں';

  @override
  String get shareMenuVideoUpdated => 'ویڈیو کامیابی سے اپڈیٹ ہو گئی';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شریک کار دعوتیں نہیں بھیجی جا سکیں۔',
      one: '1 شریک کار دعوت نہیں بھیجی جا سکی۔',
    );
    return 'ویڈیو اپڈیٹ ہو گئی، لیکن $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'دوبارہ سائن ان کریں، پھر کوشش کریں۔';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'اس ویڈیو کا کوئی قابلِ چلاؤ ماخذ نہیں، اس لیے اسے ایڈٹ نہیں کیا جا سکتا۔';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'اپ ڈیٹ پر دستخط نہیں ہو سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get videoUpdateErrorPublishRejected =>
      'ریلے نے اپ ڈیٹ قبول نہیں کی۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get videoUpdateErrorGeneric =>
      'اس ویڈیو کو اپ ڈیٹ نہیں کیا جا سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'ویڈیو حذف کریں؟';

  @override
  String get shareMenuDeleteCleanupInProgress => 'ویڈیو ہٹائی جا رہی ہے…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'ویڈیو حذف کر دی گئی۔';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'ویڈیو حذف کر دی گئی۔ اسے ہر جگہ سے غائب ہونے میں کچھ وقت لگ سکتا ہے۔';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'ویڈیو حذف کر دی گئی، لیکن ہم ہر نقل کو نہیں ہٹا سکے۔ سپورٹ سے رابطہ کریں۔';

  @override
  String get authSessionExpired =>
      'آپ کا سیشن ختم ہو گیا ہے۔ براہ کرم دوبارہ سائن ان کریں۔';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed =>
      'سائن ان نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get webAuthNotSupportedSecureMode =>
      'محفوظ موڈ میں ویب تصدیق تعاون یافتہ نہیں ہے۔ محفوظ کلید مینجمنٹ کے لیے براہ کرم موبائل ایپ استعمال کریں۔';

  @override
  String get webAuthEnterBunkerUri => 'براہ کرم bunker URI درج کریں';

  @override
  String get webAuthConnectTitle => 'Divine سے منسلک ہوں';

  @override
  String get webAuthChooseMethod =>
      'اپنا پسندیدہ Nostr تصدیقی طریقہ منتخب کریں';

  @override
  String get webAuthBrowserExtension => 'براؤزر ایکسٹینشن';

  @override
  String get webAuthRecommended => 'تجویز کردہ';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'ریموٹ سائنر سے منسلک ہوں';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'کلپ بورڈ سے پیسٹ کریں';

  @override
  String get webAuthConnectToBunker => 'Bunker سے منسلک ہوں';

  @override
  String get webAuthNewToNostr => 'Nostr پر نئے ہیں؟';

  @override
  String get webAuthNostrHelp =>
      'سب سے آسان تجربے کے لیے Alby یا nos2x جیسی براؤزر ایکسٹینشن انسٹال کریں، یا محفوظ ریموٹ سائننگ کے لیے nsec bunker استعمال کریں۔';

  @override
  String get soundsTitle => 'آوازیں';

  @override
  String get soundsSearchHint => 'آوازیں تلاش کریں...';

  @override
  String get soundsSearchResults => 'تلاش کے نتائج';

  @override
  String get soundsNoSoundsFound => 'کوئی آواز نہیں ملی';

  @override
  String get soundsNoSoundsFoundDescription =>
      'کوئی اور تلاش کی اصطلاح آزمائیں';

  @override
  String get soundsSavedToLibrary => 'آوازوں میں محفوظ ہو گئی';

  @override
  String get soundsAlreadySavedToLibrary => 'پہلے سے آوازوں میں ہے';

  @override
  String get soundsSavedLibraryTitle => 'میری آوازیں';

  @override
  String get soundsSavedEmptyTitle => 'ابھی کوئی محفوظ آواز نہیں';

  @override
  String get soundsSavedEmptyDescription =>
      'کسی ویڈیو پر آواز استعمال کریں پر ٹیپ کریں تاکہ وہ یہاں محفوظ ہو جائے۔';

  @override
  String get soundsRemoveSavedSound => 'آواز ہٹائیں';

  @override
  String get savedSoundSaveAction => 'محفوظ کریں';

  @override
  String get savedSoundPausePreviewAction => 'پیش نظارہ روکیں';

  @override
  String get savedSoundResumePreviewAction => 'پیش نظارہ دوبارہ چلائیں';

  @override
  String get savedSoundDetailsSheetTitle => 'آواز کی تفصیلات';

  @override
  String get savedSoundRemoveConfirmTitle => 'کیا یہ آواز ہٹا دیں؟';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'یہ آپ کی لائبریری سے ہٹ جائے گی، لیکن آپ اسے استعمال کرنے والی کسی بھی ویڈیو سے دوبارہ محفوظ کر سکتے ہیں۔';

  @override
  String get soundsRemovedFromLibrary => 'آوازوں سے ہٹا دی گئی';

  @override
  String get soundsSaveFailed =>
      'وہ ساؤنڈ محفوظ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get soundsRemoveFailed =>
      'وہ ساؤنڈ ہٹایا نہیں جا سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get soundSyncStatusSyncing => 'آپ کی آوازیں ہم آہنگ ہو رہی ہیں…';

  @override
  String get soundSyncStatusSynced => 'آوازیں تازہ ترین ہیں';

  @override
  String get soundSyncStatusFailed =>
      'آپ کی آوازیں ہم آہنگ نہیں ہو سکیں۔ ہم دوبارہ کوشش کریں گے۔';

  @override
  String get soundSyncStatusLocked =>
      'اس ڈیوائس پر آپ کی ہم آہنگ لائبریری کھولی نہیں جا سکتی۔';

  @override
  String get profileTitle => 'پروفائل';

  @override
  String get profileMoreOptions => 'مزید اختیارات';

  @override
  String profileBlockedUser(String name) {
    return '$name بلاک ہو گیا';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name ان بلاک ہو گیا';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name کو ان فالو کیا';
  }

  @override
  String get profileFeedError =>
      'سرور تک رسائی نہیں ہو رہی۔ اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get profileFeedLoadMoreError =>
      'مزید ویڈیوز لوڈ نہیں ہو سکیں۔ ریفریش کے لیے کھینچیں۔';

  @override
  String get notificationsTabAll => 'سب';

  @override
  String get notificationsTabLikes => 'پسندیں';

  @override
  String get notificationsTabComments => 'تبصرے';

  @override
  String get notificationsTabFollows => 'فالو';

  @override
  String get notificationsTabReposts => 'ریپوسٹس';

  @override
  String get notificationsFailedToLoad => 'اطلاعات لوڈ نہیں ہو سکیں';

  @override
  String get notificationsRetry => 'دوبارہ کوشش کریں';

  @override
  String get notificationsRefreshError =>
      'ریفریش نہیں ہو سکا — آپ کے پاس موجود مواد دکھا رہے ہیں';

  @override
  String get notificationsUnreadPrefix => 'غیر پڑھی ہوئی اطلاع';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غیر پڑھی ہوئی اطلاعات',
      one: '1 غیر پڑھی ہوئی اطلاع',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return '$displayName کا پروفائل دیکھیں';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'پروفائلز دیکھیں';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return '$title کا ویڈیو تھمب نیل';
  }

  @override
  String get notificationsVideoThumbnail => 'ویڈیو تھمب نیل';

  @override
  String get notificationsInviteSingular =>
      'آپ کے پاس 1 دعوت ہے جو کسی دوست کے ساتھ شیئر کریں!';

  @override
  String notificationsInvitePlural(int count) {
    return 'آپ کے پاس $count دعوتیں ہیں جو دوستوں کے ساتھ شیئر کریں!';
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
  String get notificationsVideoUnavailable => 'ویڈیو دستیاب نہیں';

  @override
  String get feedFailedToLoadVideos => 'ویڈیوز لوڈ نہیں ہو سکیں';

  @override
  String get feedRetry => 'دوبارہ کوشش کریں';

  @override
  String get feedNoFollowedUsers =>
      'کوئی فالو شدہ صارف نہیں۔\nان کی ویڈیوز یہاں دیکھنے کے لیے کسی کو فالو کریں۔';

  @override
  String get feedModeForYou => 'آپ کے لیے';

  @override
  String get feedModeNew => 'نئی';

  @override
  String get feedModeFollowing => 'فالو کردہ';

  @override
  String get feedModeClassics => 'کلاسکس';

  @override
  String feedModeSemanticLabel(String label) {
    return 'فیڈ موڈ: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'ویڈیو تخلیق کار: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'تخلیق کار کا اواتار';

  @override
  String get feedForYouEmpty =>
      'آپ کا \'آپ کے لیے\' فیڈ خالی ہے۔\nاسے سنوارنے کے لیے ویڈیوز دریافت کریں اور کریئیٹرز کو فالو کریں۔';

  @override
  String get feedFollowingEmpty =>
      'آپ کے فالو کردہ لوگوں کی ابھی کوئی ویڈیو نہیں۔\nاپنے پسندیدہ کریئیٹرز تلاش کریں اور انہیں فالو کریں۔';

  @override
  String get feedLatestEmpty => 'ابھی کوئی نئی ویڈیو نہیں۔\nجلد دوبارہ دیکھیں۔';

  @override
  String get feedClassicEmpty =>
      'ابھی کوئی کلاسک Vine نہیں۔\nجلد دوبارہ دیکھیں۔';

  @override
  String get feedExploreVideos => 'ویڈیوز دریافت کریں';

  @override
  String get feedLoadingMore => 'مزید ویڈیوز لوڈ ہو رہی ہیں…';

  @override
  String get feedRefreshed => 'فیڈ ریفریش ہو گئی';

  @override
  String get uploadUploadingVideo => 'ویڈیو اپلوڈ ہو رہی ہے';

  @override
  String get postPublishConfirmationTitle => 'آپ کے پروفائل پر شائع ہو گئی';

  @override
  String get postPublishConfirmationView => 'دیکھیں';

  @override
  String get postPublishConfirmationShare => 'شیئر';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'اس ویڈیو کا تھمب نیل جو آپ نے ابھی شائع کی';

  @override
  String get userSearchNoResults => 'کوئی صارف نہیں ملا';

  @override
  String get userPickerFilterByNameHint => 'نام سے فلٹر کریں...';

  @override
  String get userPickerSearchByNameHint => 'نام سے تلاش کریں...';

  @override
  String get userPickerClearSearchSemantics => 'تلاش صاف کریں';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name پہلے سے شامل ہے';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name منتخب کریں';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return '$name ہٹائیں';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'آپ کا ٹولہ کہیں باہر ہے';

  @override
  String get userPickerEmptyFollowListBody =>
      'اپنے مزاج کے لوگوں کو فالو کریں۔ جب وہ فالو بیک کریں گے، آپ کولیب کر سکیں گے۔';

  @override
  String get userPickerGoBack => 'واپس جائیں';

  @override
  String get userPickerTypeNameToSearch => 'تلاش کے لیے نام لکھیں';

  @override
  String get userPickerUnavailable =>
      'صارف تلاش دستیاب نہیں ہے۔ براہ کرم بعد میں دوبارہ کوشش کریں۔';

  @override
  String get userPickerSearchFailedTryAgain =>
      'تلاش ناکام۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get forgotPasswordTitle => 'پاس ورڈ ری سیٹ کریں';

  @override
  String get forgotPasswordDescription =>
      'اپنا ای میل ایڈریس درج کریں اور ہم آپ کو پاس ورڈ ری سیٹ کرنے کا لنک بھیج دیں گے۔';

  @override
  String get forgotPasswordEmailLabel => 'ای میل ایڈریس';

  @override
  String get forgotPasswordCancel => 'منسوخ کریں';

  @override
  String get forgotPasswordSendLink => 'ری سیٹ لنک ای میل کریں';

  @override
  String get ageVerificationContentWarning => 'مواد انتباہ';

  @override
  String get ageVerificationTitle => 'عمر کی تصدیق';

  @override
  String get ageVerificationAdultDescription =>
      'اس مواد کو ممکنہ بالغ مواد کے طور پر فلیگ کیا گیا ہے۔ اسے دیکھنے کے لیے آپ کی عمر 18 سال یا زیادہ ہونی چاہیے۔';

  @override
  String get ageVerificationCreationDescription =>
      'کیمرہ استعمال کرنے اور مواد بنانے کے لیے آپ کی عمر کم از کم 16 سال ہونی چاہیے۔';

  @override
  String get ageVerificationAdultQuestion =>
      'کیا آپ کی عمر 18 سال یا زیادہ ہے؟';

  @override
  String get ageVerificationCreationQuestion =>
      'کیا آپ کی عمر 16 سال یا زیادہ ہے؟';

  @override
  String get ageVerificationNo => 'نہیں';

  @override
  String get ageVerificationYes => 'ہاں';

  @override
  String get navHome => 'ہوم';

  @override
  String get navExplore => 'دریافت';

  @override
  String get navInbox => 'ان باکس';

  @override
  String get navProfile => 'پروفائل';

  @override
  String get navMyProfile => 'میرا پروفائل';

  @override
  String get navNotifications => 'اطلاعات';

  @override
  String get navOpenCamera => 'کیمرہ کھولیں';

  @override
  String get navExploreClassics => 'کلاسکس';

  @override
  String get navExploreNewVideos => 'نئی ویڈیوز';

  @override
  String get navExploreTrending => 'مقبول';

  @override
  String get navExploreForYou => 'آپ کے لیے';

  @override
  String get navExploreLists => 'فہرستیں';

  @override
  String get routeErrorTitle => 'خرابی';

  @override
  String get routeInvalidHashtag => 'غلط ہیش ٹیگ';

  @override
  String get routeInvalidConversationId => 'غلط گفتگو ID';

  @override
  String get routeInvalidRequestId => 'غلط درخواست ID';

  @override
  String get routeInvalidListId => 'غلط فہرست ID';

  @override
  String get routeInvalidUserId => 'غلط صارف ID';

  @override
  String get routeInvalidVideoId => 'غلط ویڈیو ID';

  @override
  String get routeInvalidSoundId => 'غلط آواز ID';

  @override
  String get routeInvalidCategory => 'غلط زمرہ';

  @override
  String get routeNoVideosToDisplay => 'دکھانے کے لیے کوئی ویڈیو نہیں';

  @override
  String get routeGoHome => 'ہوم پر جائیں';

  @override
  String get routeInvalidProfileId => 'غلط پروفائل ID';

  @override
  String get routeUnknownPath => 'وہ صفحہ ایپ میں نہیں ہے۔';

  @override
  String get routeDefaultListName => 'فہرست';

  @override
  String get supportTitle => 'مدد کا مرکز';

  @override
  String get supportContactSupport => 'سپورٹ سے رابطہ کریں';

  @override
  String get supportContactSupportSubtitle =>
      'گفتگو شروع کریں یا پرانے پیغامات دیکھیں';

  @override
  String get supportReportBug => 'بگ کی رپورٹ کریں';

  @override
  String get supportReportBugSubtitle => 'ایپ کے تکنیکی مسائل';

  @override
  String get supportRequestFeature => 'فیچر کی درخواست کریں';

  @override
  String get supportRequestFeatureSubtitle =>
      'کوئی بہتری یا نیا فیچر تجویز کریں';

  @override
  String get supportSaveLogs => 'لاگز محفوظ کریں';

  @override
  String get supportSaveLogsSubtitle =>
      'دستی بھیجنے کے لیے لاگز فائل میں ایکسپورٹ کریں';

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
  String get supportFaq => 'عمومی سوالات';

  @override
  String get supportFaqSubtitle => 'عام سوالات اور جوابات';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'والدین اور نوجوانوں کو آن لائن صحت مند عادات بنانے میں مدد';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'ہم عمر کے مطابق اکاؤنٹس کو کیسے سنبھالتے ہیں';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => 'تصدیق اور اصالت کے بارے میں جانیں';

  @override
  String get supportLoginRequired => 'سپورٹ سے رابطہ کے لیے لاگ ان کریں';

  @override
  String get supportExportingLogs => 'لاگز ایکسپورٹ ہو رہے ہیں...';

  @override
  String get supportExportLogsFailed => 'لاگز ایکسپورٹ نہیں ہو سکے';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'لاگز $path میں محفوظ ہوئے';
  }

  @override
  String get supportRevealLogsAction => 'فولڈر میں دکھائیں';

  @override
  String get supportChatNotAvailable => 'سپورٹ چیٹ دستیاب نہیں';

  @override
  String get supportCouldNotOpenMessages => 'سپورٹ پیغامات نہیں کھل سکے';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName نہیں کھل سکا';
  }

  @override
  String get reportWhyReporting => 'آپ یہ مواد کیوں رپورٹ کر رہے ہیں؟';

  @override
  String get reportPolicyNotice =>
      'Divine مواد کی رپورٹس پر 24 گھنٹوں کے اندر کارروائی کرے گا: مواد ہٹا کر اور قاعدہ توڑنے والا مواد دینے والے صارف کو نکال کر۔';

  @override
  String get reportBlockUser => 'اس صارف کو بلاک کریں';

  @override
  String get reportCancel => 'منسوخ کریں';

  @override
  String get reportSubmit => 'رپورٹ کریں';

  @override
  String get reportSelectReason =>
      'براہ کرم اس مواد کی رپورٹ کرنے کی وجہ منتخب کریں';

  @override
  String get reportOtherRequiresDetails =>
      'دیگر منتخب کرنے پر براہ کرم مسئلہ بیان کریں';

  @override
  String get reportDetailsRequired => 'براہ کرم مسئلہ بیان کریں';

  @override
  String get reportDetailsTextOnly =>
      'صرف متن — یہاں تصاویر یا GIF منسلک نہیں کیے جا سکتے۔';

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
  String get reportReasonSpam => 'اسپیم یا ناپسندیدہ مواد';

  @override
  String get reportReasonSpamSubtitle => 'ناپسندیدہ یا بار بار کا مواد';

  @override
  String get reportReasonHarassment => 'ہراسانی، دھتکار، یا دھمکیاں';

  @override
  String get reportReasonHarassmentSubtitle =>
      'نقصان دہ اور ناپسندیدہ جوابات یا ذکر';

  @override
  String get reportReasonViolence => 'پرتشدد یا انتہا پسند مواد';

  @override
  String get reportReasonViolenceSubtitle =>
      'پرتشدد، انتہا پسند، یا نقصان دہ مواد';

  @override
  String get reportReasonSexualContent => 'جنسی یا بالغ مواد';

  @override
  String get reportReasonSexualContentSubtitle => 'عریانیت، فحش، یا صریح مواد';

  @override
  String get reportReasonCopyright => 'کاپی رائٹ خلاف ورزی';

  @override
  String get reportReasonCopyrightSubtitle => 'ملکیتی حقوق کا غیر مجاز استعمال';

  @override
  String get reportReasonFalseInfo => 'جھوٹی معلومات';

  @override
  String get reportReasonFalseInfoSubtitle => 'گمراہ کن یا جھوٹے دعوے';

  @override
  String get reportReasonChildSafety => 'بچوں کی حفاظت کی خلاف ورزی';

  @override
  String get reportReasonChildSafetySubtitle =>
      'نابالغوں کی حفاظت کے عمومی خدشات';

  @override
  String get reportReasonCsam => 'بچوں کی جنسی زیادتی';

  @override
  String get reportReasonCsamSubtitle =>
      'نابالغوں کی جنسی زیادتی دکھانے والا مواد';

  @override
  String get reportReasonUnderageUser => 'صارف 16 سال سے کم لگتا ہے';

  @override
  String get reportReasonUnderageUserSubtitle => 'اکاؤنٹ ہولڈر نابالغ لگتا ہے';

  @override
  String get reportReasonAiGenerated => 'AI تیار کردہ مواد';

  @override
  String get reportReasonAiGeneratedSubtitle => 'مشتبہ AI تیار کردہ مواد';

  @override
  String get reportReasonOther => 'پالیسی کی دیگر خلاف ورزی';

  @override
  String get reportReasonOtherSubtitle => 'اوپر درج نہیں کی گئی خلاف ورزیاں';

  @override
  String get reportFailed => 'مواد کی رپورٹ ناکام۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get reportNotSent =>
      'آپ کی رپورٹ نہیں بھیجی جا سکی۔ اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get reportReceivedTitle => 'رپورٹ موصول ہو گئی';

  @override
  String get reportReceivedThankYou =>
      'Divine کو محفوظ رکھنے میں مدد کے لیے شکریہ۔';

  @override
  String get reportReceivedReviewNotice =>
      'ہماری ٹیم آپ کی رپورٹ کا جائزہ لے گی اور مناسب کارروائی کرے گی۔ آپ کو براہ راست پیغام کے ذریعے اپڈیٹس مل سکتی ہیں۔';

  @override
  String get reportModerationDmDelayed =>
      'ہم ابھی موڈریشن ٹیم تک براہ راست نہیں پہنچ سکے، لیکن آپ کی رپورٹ موصول ہو گئی ہے اور اس کا جائزہ لیا جائے گا۔';

  @override
  String get reportContactModeration => 'موڈریشن ٹیم کو پیغام بھیجیں';

  @override
  String get reportLearnMoreAt => 'مزید جانیں';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'بند کریں';

  @override
  String get listAddToList => 'فہرست میں شامل کریں';

  @override
  String listVideoCount(int count) {
    return '$count ویڈیوز';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count لوگ',
      one: '1 شخص',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'از ';

  @override
  String get listNewList => 'نئی فہرست';

  @override
  String get listDone => 'ہو گیا';

  @override
  String get listErrorLoading => 'فہرستیں لوڈ کرنے میں خرابی';

  @override
  String listRemovedFrom(String name) {
    return '$name سے ہٹا دی گئی';
  }

  @override
  String listAddedTo(String name) {
    return '$name میں شامل کر دی گئی';
  }

  @override
  String get listCreateNewList => 'نئی فہرست بنائیں';

  @override
  String get listNewPeopleList => 'لوگوں کی نئی فہرست';

  @override
  String get listCollaboratorsNone => 'کوئی نہیں';

  @override
  String get listAddCollaboratorTitle => 'شریک کار شامل کریں';

  @override
  String get listCollaboratorSearchHint => 'Divine میں تلاش کریں...';

  @override
  String get listNameLabel => 'فہرست کا نام';

  @override
  String get listDescriptionLabel => 'تفصیل (اختیاری)';

  @override
  String get listPublicList => 'عوامی فہرست';

  @override
  String get listPublicListSubtitle =>
      'دوسرے اس فہرست کو فالو اور دیکھ سکتے ہیں';

  @override
  String get listPrivateListSubtitle =>
      'ویڈیوز نجی رہتی ہیں۔ نام، تفصیل، ٹیگز اور کور نظر آتے رہتے ہیں۔';

  @override
  String get listVisibilityPublic => 'عوامی';

  @override
  String get listVisibilityPrivate => 'نجی';

  @override
  String get profileListsEmpty =>
      'ابھی کوئی فہرست نہیں۔ جو لوپ ساتھ رکھنے ہیں، ان کے لیے ایک بنائیں۔';

  @override
  String get listEditTitle => 'فہرست میں ترمیم کریں';

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
  String get listShareAction => 'فہرست شیئر کریں';

  @override
  String get listShareFailed => 'یہ فہرست شیئر نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get listSave => 'محفوظ کریں';

  @override
  String get listContinue => 'جاری رکھیں';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'یہ فہرست اپ ڈیٹ نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get listMakePrivateTitle => 'اس فہرست کو نجی بنائیں؟';

  @override
  String get listMakePrivateWarning =>
      'ویڈیوز خفیہ کر دی جائیں گی تاکہ انہیں صرف آپ دیکھ سکیں۔ نام، تفصیل، ٹیگز اور کور نظر آتے رہیں گے، اور پہلے شیئر کی گئی کاپیاں باقی رہ سکتی ہیں۔';

  @override
  String get listMakePublicTitle => 'اس فہرست کو عوامی بنائیں؟';

  @override
  String get listMakePublicWarning =>
      'جس کے پاس بھی لنک ہو، وہ یہ فہرست اور اس کی ویڈیوز دیکھ سکتا ہے۔';

  @override
  String listShareText(String name, String url) {
    return 'Divine پر $name دیکھیں: $url';
  }

  @override
  String listShareSubject(String name) {
    return 'Divine پر $name';
  }

  @override
  String get listCancel => 'منسوخ کریں';

  @override
  String get listCreate => 'بنائیں';

  @override
  String get listCreateFailed => 'فہرست نہیں بن سکی';

  @override
  String get keyManagementTitle => 'Nostr کلیدیں';

  @override
  String get keyManagementWhatAreKeys => 'Nostr کلیدیں کیا ہیں؟';

  @override
  String get keyManagementExplanation =>
      'آپ کی Nostr شناخت ایک خفیاتیکی کلیدی جوڑا ہے:\n\n• آپ کی عوامی کلید (npub) آپ کے صارف نام جیسی ہے — اسے کھل کر شیئر کریں\n• آپ کی نجی کلید (nsec) آپ کے پاس ورڈ جیسی ہے — اسے خفیہ رکھیں!\n\nآپ کا nsec آپ کو کسی بھی Nostr ایپ پر اپنے اکاؤنٹ تک رسائی دیتا ہے۔';

  @override
  String get keyManagementImportTitle => 'موجودہ کلید درآمد کریں';

  @override
  String get keyManagementImportSubtitle =>
      'پہلے سے Nostr اکاؤنٹ ہے؟ یہاں رسائی کے لیے اپنی نجی کلید (nsec) پیسٹ کریں۔';

  @override
  String get keyManagementImportButton => 'کلید درآمد کریں';

  @override
  String get keyManagementImportWarning =>
      'یہ آپ کی موجودہ کلید کی جگہ لے لے گا!';

  @override
  String get keyManagementBackupTitle => 'اپنی کلید کا بیک اپ لیں';

  @override
  String get keyManagementBackupSubtitle =>
      'دیگر Nostr ایپس میں اپنا اکاؤنٹ استعمال کرنے کے لیے اپنی نجی کلید (nsec) محفوظ کریں۔';

  @override
  String get keyManagementCopyNsec => 'میری نجی کلید (nsec) کاپی کریں';

  @override
  String get keyManagementNeverShare =>
      'اپنا nsec کبھی کسی کے ساتھ شیئر نہ کریں!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'آپ کی کلید اس ڈیوائس پر نہیں بلکہ Divine کی لاگ اِن سروس پر رہتی ہے۔ اپنے پاس ورڈ کی تصدیق کریں اور ہم اسے آپ کے لیے لے آئیں گے۔';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'آپ کی کلید Divine کی لاگ اِن سروس کے پاس محفوظ ہے۔ اپنے اکاؤنٹ کا پاس ورڈ درج کریں اور ہم اسے لے آئیں گے۔';

  @override
  String get keyManagementKeycastCopyKey => 'کلید کاپی کریں';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'آپ کی ڈیوائس نے کاپی روک دی، اس لیے آپ کی کلید کلپ بورڈ تک نہیں پہنچی۔';

  @override
  String get keyManagementKeycastWrongPassword =>
      'یہ پاس ورڈ میل نہیں کھاتا۔ دوبارہ کوشش کریں۔';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'بہت زیادہ کوششیں۔ اسے بند کر کے دوبارہ شروع کریں۔';

  @override
  String get keyManagementKeycastRateLimited =>
      'کلید کی بہت زیادہ درخواستیں۔ چند منٹ انتظار کر کے دوبارہ کوشش کریں۔';

  @override
  String get keyManagementKeycastSignInAgain =>
      'آپ کا سیشن ختم ہو گیا ہے۔ اپنی کلید کاپی کرنے کے لیے دوبارہ سائن ان کریں۔';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'اپنی کلید کاپی کرنے سے پہلے اپنے ای میل ایڈریس کی تصدیق کریں۔';

  @override
  String get keyManagementKeycastDenied =>
      'Divine اس اکاؤنٹ کی کلیدیں سنبھالتا ہے، اس لیے انہیں یہاں کاپی نہیں کیا جا سکتا۔';

  @override
  String get keyManagementKeycastNoKey =>
      'اس اکاؤنٹ کے لیے ریکارڈ میں کوئی کلید نہیں ہے۔';

  @override
  String get keyManagementKeycastGenericFailure =>
      'لاگ اِن سروس سے رابطہ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get keyManagementRestrictedTitle => 'آپ کی کلیدیں Divine سنبھالتی ہے';

  @override
  String get keyManagementRestrictedBody =>
      'آپ کے اکاؤنٹ کو محفوظ رکھنے کے لیے، کلید کا بیک اپ اور دوسری کلید درآمد کرنا یہاں دستیاب نہیں ہے۔';

  @override
  String get keyManagementPasteKey => 'براہ کرم اپنی نجی کلید پیسٹ کریں';

  @override
  String get keyManagementInvalidFormat =>
      'کلید کا فارمیٹ غلط ہے۔ آغاز \"nsec1\" سے ہونا چاہیے';

  @override
  String get keyManagementConfirmImportTitle => 'یہ کلید درآمد کریں؟';

  @override
  String get keyManagementConfirmImportBody =>
      'یہ آپ کی موجودہ شناخت کی جگہ درآمد شدہ شناخت لے آئے گا۔\n\nاگر آپ نے پہلے بیک اپ نہیں لیا تو آپ کی موجودہ کلید کھو جائے گی۔';

  @override
  String get keyManagementImportConfirm => 'درآمد کریں';

  @override
  String get keyManagementImportSuccess => 'کلید کامیابی سے درآمد ہو گئی!';

  @override
  String get keyManagementImportFailed =>
      'کلید درآمد نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get keyManagementExportSuccess =>
      'نجی کلید کلپ بورڈ پر کاپی ہو گئی!\n\nاسے کسی محفوظ جگہ رکھیں۔';

  @override
  String get keyManagementExportFailed =>
      'کلید ایکسپورٹ نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get keyManagementYourPublicKeyLabel => 'آپ کی عوامی کلید (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'عوامی کلید کاپی کریں';

  @override
  String get keyManagementPublicKeyCopied => 'عوامی کلید کاپی ہو گئی';

  @override
  String get saveOriginalSavedToCameraRoll => 'کیمرہ رول میں محفوظ ہو گئی';

  @override
  String get saveOriginalShare => 'شیئر';

  @override
  String get saveOriginalDone => 'ہو گیا';

  @override
  String get saveOriginalPhotosAccessNeeded => 'تصاویر تک رسائی درکار ہے';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'ویڈیوز محفوظ کرنے کے لیے ترتیبات میں تصاویر تک رسائی کی اجازت دیں۔';

  @override
  String get saveOriginalOpenSettings => 'ترتیبات کھولیں';

  @override
  String get saveOriginalNotNow => 'ابھی نہیں';

  @override
  String get saveOriginalDownloadFailed => 'ڈاؤن لوڈ ناکام';

  @override
  String get saveOriginalDismiss => 'ہٹائیں';

  @override
  String get saveOriginalDownloadingVideo => 'ویڈیو ڈاؤن لوڈ ہو رہی ہے';

  @override
  String get saveOriginalSavingToCameraRoll => 'کیمرہ رول میں محفوظ ہو رہی ہے';

  @override
  String get saveOriginalFetchingVideo =>
      'نیٹ ورک سے ویڈیو حاصل کی جا رہی ہے...';

  @override
  String get saveOriginalSavingVideo =>
      'اصل ویڈیو آپ کے کیمرہ رول میں محفوظ ہو رہی ہے...';

  @override
  String get soundTitle => 'آواز';

  @override
  String get soundOriginalSound => 'اصل آواز';

  @override
  String get soundVideosUsingThisSound => 'یہ آواز استعمال کرنے والی ویڈیوز';

  @override
  String get soundSourceVideo => 'ماخذ ویڈیو';

  @override
  String get soundNoVideosYet => 'ابھی کوئی ویڈیو نہیں';

  @override
  String get soundBeFirstToUse => 'یہ آواز استعمال کرنے والے پہلے شخص بنیں!';

  @override
  String get soundFailedToLoadVideos => 'ویڈیوز لوڈ نہیں ہو سکیں';

  @override
  String get soundRetry => 'دوبارہ کوشش کریں';

  @override
  String get soundVideosUnavailable => 'ویڈیوز دستیاب نہیں';

  @override
  String get soundCouldNotLoadDetails => 'ویڈیو تفصیلات لوڈ نہیں ہو سکیں';

  @override
  String get soundPreview => 'پیش منظر';

  @override
  String get soundStop => 'روکیں';

  @override
  String get soundUseSound => 'آواز استعمال کریں';

  @override
  String get soundUntitled => 'بلا عنوان آواز';

  @override
  String get soundStopPreview => 'پیش منظر روکیں';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '$title کا پیش منظر';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return '$title کی تفصیلات دیکھیں';
  }

  @override
  String get soundNoVideoCount => 'ابھی کوئی ویڈیو نہیں';

  @override
  String get soundOneVideo => '1 ویڈیو';

  @override
  String soundVideoCount(int count) {
    return '$count ویڈیوز';
  }

  @override
  String get soundUnableToPreview =>
      'آواز کا پیش منظر نہیں دکھایا جا سکتا — کوئی آڈیو دستیاب نہیں';

  @override
  String get soundPreviewFailed =>
      'پیش منظر نہیں چلایا جا سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get soundViewSource => 'ماخذ دیکھیں';

  @override
  String get soundCloseTooltip => 'بند کریں';

  @override
  String get exploreNotExploreRoute => 'دریافت روٹ نہیں ہے';

  @override
  String get legalTitle => 'قانونی';

  @override
  String get legalTermsOfService => 'شرائطِ خدمت';

  @override
  String get legalTermsOfServiceSubtitle => 'استعمال کی شرائط و ضوابط';

  @override
  String get legalPrivacyPolicy => 'رازداری کی پالیسی';

  @override
  String get legalPrivacyPolicySubtitle => 'ہم آپ کے ڈیٹا کو کیسے سنبھالتے ہیں';

  @override
  String get legalSafetyStandards => 'حفاظتی معیارات';

  @override
  String get legalSafetyStandardsSubtitle => 'کمیونٹی رہنما اصول اور حفاظت';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'کاپی رائٹ اور ہٹانے کی پالیسی';

  @override
  String get legalOpenSourceLicenses => 'اوپن سورس لائسنسز';

  @override
  String get legalOpenSourceLicensesSubtitle => 'تھرڈ پارٹی پیکج انتسابات';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName نہیں کھل سکا';
  }

  @override
  String get categoryAction => 'ایکشن';

  @override
  String get categoryAdventure => 'مہم جوئی';

  @override
  String get categoryAnimals => 'جانور';

  @override
  String get categoryAnimation => 'اینیمیشن';

  @override
  String get categoryArchitecture => 'معماری';

  @override
  String get categoryArt => 'فن';

  @override
  String get categoryAutomotive => 'گاڑیاں';

  @override
  String get categoryAwardShow => 'ایوارڈ شو';

  @override
  String get categoryAwards => 'ایوارڈز';

  @override
  String get categoryBaseball => 'بیس بال';

  @override
  String get categoryBasketball => 'باسکٹ بال';

  @override
  String get categoryBeauty => 'خوبصورتی';

  @override
  String get categoryBeverage => 'مشروبات';

  @override
  String get categoryCars => 'گاڑیاں';

  @override
  String get categoryCelebration => 'جشن';

  @override
  String get categoryCelebrities => 'مشاہیر';

  @override
  String get categoryCelebrity => 'مشہور شخصیت';

  @override
  String get categoryCityscape => 'شہری منظر';

  @override
  String get categoryComedy => 'کامیڈی';

  @override
  String get categoryConcert => 'کنسرٹ';

  @override
  String get categoryCooking => 'کھانا پکانا';

  @override
  String get categoryCostume => 'لباس';

  @override
  String get categoryCrafts => 'دستکاری';

  @override
  String get categoryCrime => 'جرائم';

  @override
  String get categoryCulture => 'ثقافت';

  @override
  String get categoryDance => 'رقص';

  @override
  String get categoryDiy => 'خود کریں (DIY)';

  @override
  String get categoryDrama => 'ڈرامہ';

  @override
  String get categoryEducation => 'تعلیم';

  @override
  String get categoryEmotional => 'جذباتی';

  @override
  String get categoryEmotions => 'جذبات';

  @override
  String get categoryEntertainment => 'تفریح';

  @override
  String get categoryEvent => 'تقریب';

  @override
  String get categoryFamily => 'خاندان';

  @override
  String get categoryFans => 'مداح';

  @override
  String get categoryFantasy => 'فینٹسی';

  @override
  String get categoryFashion => 'اسٹائل';

  @override
  String get categoryFestival => 'تہوار';

  @override
  String get categoryFilm => 'فلم';

  @override
  String get categoryFitness => 'فٹنس';

  @override
  String get categoryFood => 'کھانا';

  @override
  String get categoryFootball => 'امریکی فٹ بال';

  @override
  String get categoryFurniture => 'فرنیچر';

  @override
  String get categoryGaming => 'گیمنگ';

  @override
  String get categoryGolf => 'گولف';

  @override
  String get categoryGrooming => 'آراستگی';

  @override
  String get categoryGuitar => 'گٹار';

  @override
  String get categoryHalloween => 'ہالووین';

  @override
  String get categoryHealth => 'صحت';

  @override
  String get categoryHockey => 'ہاکی';

  @override
  String get categoryHoliday => 'چھٹی';

  @override
  String get categoryHome => 'گھر';

  @override
  String get categoryHomeImprovement => 'گھر کی بہتری';

  @override
  String get categoryHorror => 'ڈراؤنی';

  @override
  String get categoryHospital => 'ہسپتال';

  @override
  String get categoryHumor => 'مزاح';

  @override
  String get categoryInteriorDesign => 'انٹیریئر ڈیزائن';

  @override
  String get categoryInterview => 'انٹرویو';

  @override
  String get categoryKids => 'بچے';

  @override
  String get categoryLifestyle => 'طرزِ زندگی';

  @override
  String get categoryMagic => 'جادو';

  @override
  String get categoryMakeup => 'میک اپ';

  @override
  String get categoryMedical => 'طبی';

  @override
  String get categoryMusic => 'موسیقی';

  @override
  String get categoryMystery => 'معمہ';

  @override
  String get categoryNature => 'قدرت';

  @override
  String get categoryNews => 'خبریں';

  @override
  String get categoryOutdoor => 'بیرونِ گھر';

  @override
  String get categoryParty => 'پارٹی';

  @override
  String get categoryPeople => 'لوگ';

  @override
  String get categoryPerformance => 'پرفارمنس';

  @override
  String get categoryPets => 'پالتو جانور';

  @override
  String get categoryPolitics => 'سیاست';

  @override
  String get categoryPrank => 'شرارت';

  @override
  String get categoryPranks => 'شرارتیں';

  @override
  String get categoryRealityShow => 'ریئلٹی شو';

  @override
  String get categoryRelationship => 'رشتہ';

  @override
  String get categoryRelationships => 'رشتے';

  @override
  String get categoryRomance => 'رومانس';

  @override
  String get categorySchool => 'اسکول';

  @override
  String get categoryScienceFiction => 'سائنس فکشن';

  @override
  String get categorySelfie => 'سیلفی';

  @override
  String get categoryShopping => 'خریداری';

  @override
  String get categorySkateboarding => 'اسکیٹ بورڈنگ';

  @override
  String get categorySkincare => 'جلد کی دیکھ بھال';

  @override
  String get categorySoccer => 'فٹ بال';

  @override
  String get categorySocialGathering => 'سماجی محفل';

  @override
  String get categorySocialMedia => 'سوشل میڈیا';

  @override
  String get categorySports => 'کھیل';

  @override
  String get categoryTalkShow => 'ٹاک شو';

  @override
  String get categoryTech => 'ٹیک';

  @override
  String get categoryTechnology => 'ٹیکنالوجی';

  @override
  String get categoryTelevision => 'ٹیلی ویژن';

  @override
  String get categoryToys => 'کھلونے';

  @override
  String get categoryTransportation => 'نقل و حمل';

  @override
  String get categoryTravel => 'سفر';

  @override
  String get categoryUrban => 'شہری';

  @override
  String get categoryViolence => 'تشدد';

  @override
  String get categoryVlog => 'ولاگ';

  @override
  String get categoryVlogging => 'ولاگنگ';

  @override
  String get categoryWrestling => 'کشتی';

  @override
  String get profileSetupUploadStaged =>
      'اپلوڈ ہو گئی — لاگو کرنے کے لیے محفوظ کریں پر ٹیپ کریں';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName کی رپورٹ کی';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName کو بلاک کیا';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName کو ان بلاک کیا';
  }

  @override
  String get inboxRemovedConversation => 'گفتگو ہٹا دی گئی';

  @override
  String get inboxRestorePausedTitle => 'کچھ چیٹس کی بحالی ابھی مکمل نہیں ہوئی';

  @override
  String get conversationRestorePausedTitle =>
      'اس چیٹ کی بحالی ابھی مکمل نہیں ہوئی';

  @override
  String get inboxRestoreRetryAction => 'دوبارہ کوشش کریں';

  @override
  String get inboxRestoringMessages => 'آپ کے پیغامات بحال ہو رہے ہیں…';

  @override
  String get inboxEmptyTitle => 'ابھی کوئی پیغام نہیں';

  @override
  String get inboxEmptySubtitle => 'وہ + بٹن کاٹ نہیں کھائے گا۔';

  @override
  String get inboxLoadErrorTitle => 'پیغامات لوڈ نہیں ہوئے';

  @override
  String get inboxLoadErrorSubtitle =>
      'اپنا کنکشن چیک کریں اور ایک بار پھر کوشش کریں۔';

  @override
  String get inboxFilterAll => 'سب';

  @override
  String get inboxFilterUnread => 'غیر پڑھی ہوئی';

  @override
  String get dmBlockedThreadTitle => 'آپ نے یہ اکاؤنٹ مسدود کیا ہے';

  @override
  String get dmBlockedThreadBody =>
      'پیغامات یہیں رہتے ہیں تاکہ آپ انہیں پڑھ سکیں یا اسکرین شاٹ لے سکیں۔ جواب دینے کے لیے بلاک ہٹائیں۔';

  @override
  String get inboxFilterBlocked => 'مسدود';

  @override
  String get inboxBlockedEmptyTitle => 'کوئی مسدود چیٹ نہیں';

  @override
  String get inboxBlockedEmptySubtitle =>
      'آپ جن اکاؤنٹس کو مسدود کرتے ہیں وہ یہاں دکھائی دیتے ہیں۔';

  @override
  String get inboxBlockedNoMessages => 'کوئی پیغام نہیں';

  @override
  String get inboxUnreadEmptyTitle => 'آپ سب پڑھ چکے ہیں';

  @override
  String get inboxUnreadEmptySubtitle => 'ابھی کوئی غیر پڑھا پیغام نہیں۔';

  @override
  String get inboxSearchHint => 'پیغامات تلاش کریں';

  @override
  String get inboxSupportRowTitle => 'Divine ماڈریشن';

  @override
  String get inboxSupportRowSubtitle =>
      'بگز، موڈریشن، اکاؤنٹ کی باتیں — ہم سن رہے ہیں۔';

  @override
  String get inboxSearchEmptyTitle => 'کوئی میل نہیں';

  @override
  String get inboxSearchEmptySubtitle => 'کوئی اور نام یا لفظ آزمائیں۔';

  @override
  String get inboxActionMute => 'گفتگو میوٹ کریں';

  @override
  String inboxActionReport(String displayName) {
    return '$displayName کی رپورٹ کریں';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayName کو بلاک کریں';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayName کو ان بلاک کریں';
  }

  @override
  String get inboxActionRemove => 'گفتگو ہٹائیں';

  @override
  String get inboxRemoveConfirmTitle => 'گفتگو ہٹائیں؟';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'اس سے $displayName کے ساتھ آپ کی گفتگو آپ کے ان باکس سے ہٹ جائے گی۔ اگر وہ آپ کو دوبارہ پیغام بھیجیں تو نئی گفتگو شروع ہو جائے گی۔';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'اس سے گروپ گفتگو آپ کے ان باکس سے ہٹ جائے گی۔ اگر کوئی گروپ میں دوبارہ پیغام بھیجے تو نئی گفتگو شروع ہو جائے گی۔';

  @override
  String get inboxRemoveConfirmConfirm => 'ہٹائیں';

  @override
  String get inboxConversationMuted => 'گفتگو میوٹ ہو گئی';

  @override
  String get inboxConversationUnmuted => 'گفتگو ان میوٹ ہو گئی';

  @override
  String get inboxCollabInviteCardTitle => 'شریک کار دعوت';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'بلا عنوان ویڈیو';

  @override
  String get clickableTextViewVideoLink => 'ویڈیو دیکھیں';

  @override
  String get messageExternalLinkDialogTitle => 'بیرونی لنک کھولیں؟';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'یہ لنک کسی بیرونی سائٹ پر جاتا ہے اور شاید محفوظ نہ ہو:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'کھولیں';

  @override
  String get inboxCollabInviteCoPostButton => 'مشترکہ پوسٹ';

  @override
  String get inboxCollabInviteNotMineButton => 'میری نہیں';

  @override
  String get inboxCollabInvitePreviewTitle => 'مشترکہ پوسٹ دعوت';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return '$displayName کی طرف سے مشترکہ پوسٹ دعوت';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'مشترکہ پوسٹ کرنے سے یہ ویڈیو تعاون کے طور پر آپ کی ٹائم لائن میں شامل ہو جائے گی۔';

  @override
  String get inboxCollabInviteAcceptedStatus => 'قبول کی گئی';

  @override
  String get inboxCollabInviteIgnoredStatus => 'نظرانداز کی گئی';

  @override
  String get inboxCollabInviteAcceptError =>
      'قبول نہیں ہو سکی۔ دوبارہ کوشش کریں۔';

  @override
  String get inboxCollabInviteSentStatus => 'دعوت بھیج دی گئی';

  @override
  String get inboxConversationCollabInvitePreview => 'شریک کار دعوت';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'آپ کو $title پر تعاون کی دعوت دی گئی: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'آپ کو ایک ویڈیو پر تعاون کی دعوت دی گئی: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شریک کار دعوتیں نہیں بھیجی جا سکیں۔',
      one: '1 شریک کار دعوت نہیں بھیجی جا سکی۔',
    );
    return 'ویڈیو پوسٹ ہو گئی، لیکن $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'ہم نہیں جان سکے کہ یہ گفتگو کس کے ساتھ ہے۔ اسے اپنے ان باکس سے دوبارہ کھولیں۔';

  @override
  String get dmSendBlockedMessage =>
      'آپ صرف سرکاری Divine اکاؤنٹس کو پیغام بھیج سکتے ہیں';

  @override
  String get dmSendBlockedRetiredMessage =>
      'یہ گفتگو کوئی نہیں پڑھ رہا۔ اس کے بجائے Divine Moderation کو پیغام بھیجیں۔';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'سب کے لیے حذف نہیں ہو سکا۔';

  @override
  String get dmDeleteRefusedDetails => 'کچھ لوگ اب بھی یہ پیغام دیکھ سکتے ہیں۔';

  @override
  String get dmRetiredThreadClosedTitle => 'یہ گفتگو بند ہو چکی ہے۔';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Divine Moderation کا یہ نوٹس ہٹایا نہیں جا سکتا۔';

  @override
  String get dmRetiredThreadClosedBody =>
      'ہم نے Divine Moderation کو نئے اکاؤنٹ پر منتقل کر دیا ہے۔ اسے اب کوئی نہیں پڑھتا۔';

  @override
  String get dmRetiredThreadOpenSupport => 'Divine Moderation کو پیغام بھیجیں';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'پیغام نہیں بھیجا جا سکا';

  @override
  String get dmResendFailedMessage => 'اب بھی نہیں بھیجا جا سکا';

  @override
  String get dmSendFailedSubtitle => 'ابھی دوبارہ بھیجیں، یا کوشش بند کر دیں۔';

  @override
  String get dmSendFailedRetry => 'دوبارہ کوشش کریں';

  @override
  String get dmSendPartialMessage =>
      'بھیج دیا گیا، لیکن آپ کی دوسری ڈیوائسز پر سنک نہیں ہوا';

  @override
  String get dmConversationLoadError => 'پیغامات لوڈ نہیں ہو سکے';

  @override
  String get dmMessageInputHint => 'کچھ کہیں…';

  @override
  String get dmMessageBubbleSentHint => 'بھیجا گیا پیغام';

  @override
  String get dmMessageBubbleReceivedHint => 'موصول شدہ پیغام';

  @override
  String get dmMessageBubbleLongPressHint => 'پیغام کارروائیاں';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'یہ پیغام دوبارہ بھیجیں یا حذف کریں';

  @override
  String get dmMessageActionCopyText => 'متن کاپی کریں';

  @override
  String get dmMessageActionCopyVideoUrl => 'ویڈیو URL کاپی کریں';

  @override
  String get dmMessageActionDeleteForEveryone => 'سب کے لیے حذف کریں';

  @override
  String get dmMessageActionReport => 'رپورٹ کریں';

  @override
  String get dmMessageActionRetrySend => 'دوبارہ بھیجیں';

  @override
  String get dmMessageActionCancelSend => 'کوشش بند کریں';

  @override
  String get dmReactionAddCustomA11yLabel => 'کسٹم ایموجی ردعمل شامل کریں';

  @override
  String dmReelReplyComposerHint(String name) {
    return '$name کو پیغام…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'خود کو جواب دیں…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'اس ریل کو جواب دیں';

  @override
  String get dmReelReplyViewChat => 'چیٹ دیکھیں';

  @override
  String get dmReelReplySentAnnouncement => 'جواب بھیج دیا گیا';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return '$emoji ردعمل دیا';
  }

  @override
  String get dmReelReplyFailed => 'نہیں بھیجا جا سکا';

  @override
  String get dmReelReplyUnverified => 'بھیجنے کی تصدیق نہیں ہو سکی';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'آپ کا ردعمل: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name نے $emoji سے ردعمل دیا';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'ردعمل بھیجا جا رہا ہے: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'ردعمل ناکام، دوبارہ کوشش کے لیے ڈبل ٹیپ کریں';

  @override
  String get dmReactionChipRetryAnnouncement => 'ردعمل دوبارہ کوشش ہو رہی ہے';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'کوئی دوسرا ردعمل شامل کرنے سے پہلے پچھلا ردعمل ہٹانے کا عمل مکمل کریں۔';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'ردعملات';

  @override
  String get dmReactionsViewA11yLabel => 'دیکھیں کس نے ردعمل دیا';

  @override
  String get dmReactionRemoveAction => 'ہٹائیں';

  @override
  String get dmReactionRetryAction => 'دوبارہ کوشش کریں';

  @override
  String get dmFormatBold => 'گہرا';

  @override
  String get dmFormatItalic => 'ترچھا';

  @override
  String get dmFormatStrikethrough => 'کٹی ہوئی لکیر';

  @override
  String get dmFormatCode => 'کوڈ';

  @override
  String get dmStatusFailed => 'نہیں بھیجا جا سکا';

  @override
  String get inboxConversationActionsSheetLabel => 'گفتگو کارروائیاں';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayName کی گفتگو';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'غیر پڑھی ہوئی، $displayName کی گفتگو';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دیگر',
    );
    return '$name اور $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'گفتگو کارروائیاں دکھائیں';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'عنوان: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'ویڈیو $current/$total';
  }

  @override
  String get exploreSearchHint => 'تلاش کریں...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count ویڈیوز';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'سبسکرپشن اپڈیٹ نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get discoverListsTitle => 'فہرستیں دریافت کریں';

  @override
  String get discoverListsFailedToLoad => 'فہرستیں لوڈ نہیں ہو سکیں';

  @override
  String get discoverListsLoading => 'عوامی فہرستیں دریافت ہو رہی ہیں...';

  @override
  String get discoverListsRelayTimeout =>
      'ریلے نے وقت پر فہرستیں واپس نہیں کیں۔ دوبارہ کوشش کریں۔';

  @override
  String get discoverListsServiceUnavailable => 'سروس دستیاب نہیں ہے۔';

  @override
  String get discoverListsEmptyTitle => 'کوئی عوامی فہرست نہیں ملی';

  @override
  String get discoverListsEmptySubtitle => 'نئی فہرستوں کے لیے بعد میں دیکھیں';

  @override
  String get discoverListsByAuthorPrefix => 'از';

  @override
  String get curatedListEmptyTitle => 'اس فہرست میں کوئی ویڈیو نہیں';

  @override
  String get curatedListEmptySubtitle =>
      'شروع کرنے کے لیے کچھ ویڈیوز شامل کریں';

  @override
  String get curatedListLoadingVideos => 'ویڈیوز لوڈ ہو رہی ہیں...';

  @override
  String get curatedListFailedToLoad => 'فہرست لوڈ نہیں ہو سکی';

  @override
  String get curatedListVideoNotAvailable => 'ویڈیو دستیاب نہیں';

  @override
  String get curatedListActionsTooltip => 'فہرست کارروائیاں';

  @override
  String get curatedListDeleteConfirmTitle => 'فہرست حذف کریں؟';

  @override
  String get curatedListDeleteConfirmBody =>
      'اس سے فہرست ریلے سے ہٹ جائے گی۔ فہرست کی ویڈیوز حذف نہیں ہوں گی۔';

  @override
  String get curatedListDeletedSnack => 'فہرست حذف ہو گئی';

  @override
  String get curatedListDeleteFailed => 'فہرست حذف نہیں ہو سکی';

  @override
  String get peopleListsActionsTooltip => 'فہرست کارروائیاں';

  @override
  String get listDeleteAction => 'فہرست حذف کریں';

  @override
  String get peopleListsDeleteConfirmTitle => 'فہرست حذف کریں؟';

  @override
  String get peopleListsDeleteConfirmBody =>
      'یہ فہرست سب کے لیے ہٹا دے گا۔ اس کے لوگ ان فالو نہیں ہوں گے۔';

  @override
  String get peopleListsDeleteFailed => 'فہرست حذف نہیں ہو سکی';

  @override
  String get commonRetry => 'دوبارہ کوشش کریں';

  @override
  String get commonSomethingWentWrong => 'کچھ غلط ہو گیا';

  @override
  String get commonDelete => 'حذف کریں';

  @override
  String get commonCancel => 'منسوخ کریں';

  @override
  String get commonBack => 'واپس';

  @override
  String get commonClose => 'بند کریں';

  @override
  String get commonNotNow => 'ابھی نہیں';

  @override
  String get commonLoading => 'لوڈ ہو رہا ہے';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'کور اپڈیٹ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'کور اپڈیٹ ہو گیا';

  @override
  String get videoMetadataC2paMissingTitle =>
      'انسانی بنائی جانچ کے بغیر پوسٹ کریں؟';

  @override
  String get videoMetadataC2paMissingBody =>
      'ہم مواد اسناد شامل نہیں کر سکے، اس لیے یہ ویڈیو انسان کی بنائی ہوئی کے طور پر تصدیق نہیں ہو گی۔ دوبارہ بنانے کے لیے ری جنریٹ کریں، یا جوں کی توں پوسٹ کریں۔';

  @override
  String get videoMetadataC2paMissingNote =>
      'مواد اسناد کے لیے انٹرنیٹ کنکشن درکار ہے۔';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'کنٹینٹ کریڈنشل سروس نے جواب نہیں دیا۔ یہ آپ کے کنکشن کا مسئلہ نہیں ہے۔';

  @override
  String get videoMetadataC2paMissingRegenerate => 'دوبارہ بنائیں';

  @override
  String get videoMetadataC2paMissingSkip => 'چھوڑیں';

  @override
  String get videoMetadataGenerationFailed => 'بنانا ناکام';

  @override
  String get videoMetadataTags => 'ٹیگز';

  @override
  String get videoMetadataExpiration => 'میعاد';

  @override
  String get videoMetadataExpirationNotExpire => 'میعاد ختم نہیں ہوتی';

  @override
  String get videoMetadataExpirationOneDay => '1 دن';

  @override
  String get videoMetadataExpirationOneWeek => '1 ہفتہ';

  @override
  String get videoMetadataExpirationOneMonth => '1 مہینہ';

  @override
  String get videoMetadataExpirationOneYear => '1 سال';

  @override
  String get videoMetadataExpirationOneDecade => '1 دہائی';

  @override
  String get videoMetadataContentWarnings => 'مواد انتباہات';

  @override
  String get videoEditorStickers => 'اسٹیکرز';

  @override
  String get trendingTitle => 'مقبول';

  @override
  String get libraryDeleteConfirm => 'حذف کریں';

  @override
  String get libraryWebUnavailableHeadline =>
      'لائبریری موبائل ایپ میں دستیاب ہے';

  @override
  String get libraryWebUnavailableDescription =>
      'مسودے اور کلپس آپ کی ڈیوائس پر محفوظ ہوتے ہیں، اس لیے انہیں سنبھالنے کے لیے اپنے فون پر Divine کھولیں۔';

  @override
  String get libraryTabDrafts => 'مسودے';

  @override
  String get libraryTabClips => 'کلپس';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'منتخب کلپس حذف کریں';

  @override
  String get libraryCloseSemanticLabel => 'لائبریری بند کریں';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'کلپس منتخب کرنا بند کریں';

  @override
  String get librarySelectClipsSemanticLabel => 'کلپس منتخب کریں';

  @override
  String get libraryGridSizeLabel => 'گرڈ کا سائز';

  @override
  String get libraryDisplayOptionsLabel => 'ترتیب اور گرڈ سائز';

  @override
  String get libraryMoreActionsSemanticLabel => 'لائبریری کی مزید کارروائیاں';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کالم',
      one: '1 کالم',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'منتخب کریں';

  @override
  String get librarySortNewestCreation => 'تازہ ترین تخلیق';

  @override
  String get librarySortOldestCreation => 'قدیم ترین تخلیق';

  @override
  String get librarySortLongestClip => 'سب سے لمبی کلپ';

  @override
  String get librarySortShortestClip => 'سب سے چھوٹی کلپ';

  @override
  String get librarySortSquareFirst => 'پہلے چوکور';

  @override
  String get librarySortVerticalFirst => 'پہلے عمودی';

  @override
  String get libraryDeleteClipsWarning =>
      'یہ کارروائی واپس نہیں ہو سکتی۔ ویڈیو فائلیں آپ کی ڈیوائس سے مستقل طور پر ہٹا دی جائیں گی۔';

  @override
  String get libraryPreparingVideo => 'ویڈیو تیار ہو رہی ہے...';

  @override
  String libraryCreateVideo(int count) {
    return 'ویڈیو بنائیں ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس',
      one: '1 کلپ',
    );
    return '$_temp0 $destination میں محفوظ ہو گئیں';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount محفوظ، $failureCount ناکام';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return '$destination میں محفوظ نہیں ہو سکا';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination کی اجازت نہیں ملی';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس حذف ہو گئیں',
      one: '1 کلپ حذف ہو گئی',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'واپس کریں';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: '$daysLeft دنوں میں خودکار حذف ہو گا',
      one: 'کل خودکار حذف ہو گا',
      zero: 'آج خودکار حذف ہو گا',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'مسودے لوڈ نہیں ہو سکے';

  @override
  String get libraryCouldNotLoadClips => 'کلپس لوڈ نہیں ہو سکے';

  @override
  String get libraryOpenErrorDescription =>
      'آپ کی لائبریری کھولتے وقت کچھ غلط ہو گیا۔ آپ دوبارہ کوشش کر سکتے ہیں۔';

  @override
  String get libraryNoDraftsYetTitle => 'ابھی کوئی مسودہ نہیں';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'جو ویڈیوز آپ مسودے میں محفوظ کریں گے وہ یہاں نظر آئیں گی';

  @override
  String get libraryNoClipsYetTitle => 'ابھی کوئی کلپ نہیں';

  @override
  String get libraryNoClipsYetSubtitle =>
      'آپ کی ریکارڈ شدہ ویڈیو کلپس یہاں نظر آئیں گی';

  @override
  String get libraryDraftDeletedSnackbar => 'مسودہ حذف ہو گیا';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'مسودہ حذف نہیں ہو سکا';

  @override
  String get libraryDraftDuplicatedSnackbar => 'مسودہ نقل ہو گیا';

  @override
  String get libraryDraftDuplicateFailedSnackbar => 'مسودہ نقل نہیں ہو سکا';

  @override
  String get libraryDraftInProgressBadge => 'جاری ہے';

  @override
  String get libraryDraftActionPost => 'پوسٹ کریں';

  @override
  String get libraryDraftActionEdit => 'ترمیم';

  @override
  String get libraryDraftActionDuplicate => 'نقل کریں';

  @override
  String get libraryDraftActionDelete => 'مسودہ حذف کریں';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (نقل $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'مسودہ حذف کریں';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'کیا آپ واقعی \"$title\" حذف کرنا چاہتے ہیں؟';
  }

  @override
  String get libraryDeleteClipTitle => 'کلپ حذف کریں';

  @override
  String get libraryDeleteClipMessage =>
      'کیا آپ واقعی یہ کلپ حذف کرنا چاہتے ہیں؟';

  @override
  String libraryClipDuration(String seconds) {
    return '${seconds}s';
  }

  @override
  String get libraryRecordVideo => 'ویڈیو ریکارڈ کریں';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'ویڈیو کلپ، $duration سیکنڈ';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'آرکائیو شدہ۔ $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'اسٹاپ موشن کلپ، $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'منتخب، نمبر $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'منتخب';

  @override
  String get videoClipSemanticValueNotSelected => 'منتخب نہیں';

  @override
  String get videoClipSemanticHintDisabled => 'غیر فعال';

  @override
  String get videoClipSemanticHintSelect =>
      'منتخب کرنے کے لیے ٹیپ کریں، پیش منظر کے لیے دیر تک دبائیں';

  @override
  String get videoClipSemanticHintDeselect =>
      'انتخاب ختم کرنے کے لیے ٹیپ کریں، پیش منظر کے لیے دیر تک دبائیں';

  @override
  String get routerInvalidCreator => 'غلط کریئیٹر';

  @override
  String get routerInvalidHashtagRoute => 'غلط ہیش ٹیگ روٹ';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'ویڈیوز لوڈ نہیں ہو سکیں';

  @override
  String get categoryGalleryNoVideosInCategory => 'اس زمرے میں کوئی ویڈیو نہیں';

  @override
  String get categoryGallerySortOptionsLabel => 'زمرہ ترتیب اختیارات';

  @override
  String get categoryGallerySortHot => 'مقبول';

  @override
  String get categoryGallerySortNew => 'نئی';

  @override
  String get categoryGallerySortClassic => 'کلاسک';

  @override
  String get categoryGallerySortForYou => 'آپ کے لیے';

  @override
  String get categoriesCouldNotLoadCategories => 'زمرے لوڈ نہیں ہو سکے';

  @override
  String get categoriesNoCategoriesAvailable => 'کوئی زمرہ دستیاب نہیں';

  @override
  String get notificationsEmptyTitle => 'ابھی کوئی سرگرمی نہیں';

  @override
  String get notificationsEmptySubtitle =>
      'جب لوگ آپ کے مواد سے تفاعل کریں گے، آپ یہاں دیکھیں گے';

  @override
  String get appsPermissionsTitle => 'انضمام کی اجازتیں';

  @override
  String get appsPermissionsRevoke => 'منسوخ کریں';

  @override
  String get appsPermissionsEmptyTitle => 'کوئی محفوظ انضمام اجازتیں نہیں';

  @override
  String get appsPermissionsEmptySubtitle =>
      'جب آپ رسائی کی منظوری یاد رکھیں گے تو منظور شدہ انضمام یہاں نظر آئیں گے۔';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName آپ کی منظوری چاہتا ہے';
  }

  @override
  String get nostrAppPermissionDescription =>
      'یہ ایپ Divine کے جانچے ہوئے سینڈ باکس کے ذریعے رسائی مانگ رہی ہے۔';

  @override
  String get nostrAppPermissionOrigin => 'ماخذ';

  @override
  String get nostrAppPermissionMethod => 'طریقہ';

  @override
  String get nostrAppPermissionCapability => 'صلاحیت';

  @override
  String get nostrAppPermissionEventKind => 'ایونٹ قسم';

  @override
  String get nostrAppPermissionAllow => 'اجازت دیں';

  @override
  String get appsDetailDefaultTitle => 'مربوط ایپ';

  @override
  String get appsDetailNotFoundTitle => 'انضمام نہیں ملا';

  @override
  String get appsDetailNotFoundSubtitle =>
      'یہ منظور شدہ انضمام اب Divine میں دستیاب نہیں ہے۔';

  @override
  String get appsDetailHowItWorksTitle => 'یہ کیسے کام کرتا ہے';

  @override
  String get appsDetailHowItWorksBody =>
      'یہ ایک منظور شدہ تھرڈ پارٹی ایپ ہے جو Divine کے اندر چلتی ہے۔ Divine اس انضمام کے لیے صرف جائزہ شدہ صلاحیتیں دیتا ہے، اور اس کے منظور شدہ ماخذات سے باہر نیویگیشن بلاک کرتا ہے۔';

  @override
  String get appsDetailAboutTitle => 'تفصیلات';

  @override
  String get appsDetailPrimaryOriginTitle => 'بنیادی ماخذ';

  @override
  String get appsDetailApprovedOriginsTitle => 'منظور شدہ ماخذات';

  @override
  String get appsDetailCapabilitiesTitle => 'دستیاب صلاحیتیں';

  @override
  String get appsDetailAskBeforeTitle => 'پہلے پوچھیں';

  @override
  String get appsDetailOpenButton => 'انضمام کھولیں';

  @override
  String get appsDetailNoneDeclared => 'ابھی کچھ اعلان نہیں';

  @override
  String get appsDirectoryTitle => 'مربوط ایپس';

  @override
  String get appsDirectoryIntroTitle => 'منظور شدہ تھرڈ پارٹی ایپس';

  @override
  String get appsDirectoryIntroBody =>
      'منظور شدہ تھرڈ پارٹی ایپس جو Divine کے اندر چلتی ہیں';

  @override
  String get appsDirectoryErrorTitle => 'مربوط ایپس لوڈ نہیں ہو سکیں';

  @override
  String get appsDirectoryErrorSubtitle =>
      'منظور شدہ انضمام دوبارہ آزمانے کے لیے کھینچیں۔';

  @override
  String get appsDirectoryEmptyTitle => 'ابھی کوئی منظور شدہ انضمام نہیں';

  @override
  String get appsDirectoryEmptySubtitle =>
      'جیسے جیسے Divine شامل کرے گا، منظور شدہ تھرڈ پارٹی ایپس یہاں نظر آئیں گی۔';

  @override
  String get appsDirectoryRefresh => 'ریفریش';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'مربوط ایپس Divine موبائل میں چلتی ہیں';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'منظور شدہ انضمام فی الحال صرف موبائل پر دستیاب ہیں۔';

  @override
  String get appsSandboxUnavailableTitle => 'انضمام دستیاب نہیں';

  @override
  String get appsSandboxUnavailableBody =>
      'منظور شدہ انضمام مربوط ایپس ٹیب سے کھولیں تاکہ Divine صحیح رسائی پالیسی لاگو کر سکے۔';

  @override
  String get appsSandboxLoadingTitle => 'انضمام لوڈ ہو رہا ہے';

  @override
  String get appsSandboxLoadingSubtitle =>
      'لانچ سے پہلے منظور شدہ انضمام چیک ہو رہا ہے۔';

  @override
  String get appsSandboxBlockedTitle => 'حفاظت کے لیے بلاک کیا گیا';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'اس انضمام نے اپنے منظور شدہ ماخذ سے باہر جانے کی کوشش کی۔\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'پوسٹ کا لنک کلپ بورڈ پر کاپی ہو گیا';

  @override
  String get shareCopiedEventJson => 'Nostr ایونٹ JSON کلپ بورڈ پر کاپی ہو گیا';

  @override
  String get shareCopiedEventId => 'Nostr ایونٹ ID کلپ بورڈ پر کاپی ہو گیا';

  @override
  String get authHeroTaglineAuthentic => 'سچے لمحے۔';

  @override
  String get authHeroTaglineHuman => 'انسانی تخلیقیت۔';

  @override
  String get keyImportFailedToImport =>
      'کلید درآمد یا bunker سے منسلک نہیں ہو سکا';

  @override
  String get keyImportInvalidBunkerUrl => 'bunker URL غلط ہے';

  @override
  String get keyImportInvalidFormat =>
      'فارمیٹ غلط ہے۔ nsec...، hex، ncryptsec1... یا bunker://... استعمال کریں';

  @override
  String get keyImportInvalidNsecFormat =>
      'nsec فارمیٹ غلط ہے۔ 63 حروف کا ہونا چاہیے';

  @override
  String get keyImportKeyFieldLabel => 'نجی کلید یا bunker URL';

  @override
  String get keyImportKeyRequired =>
      'براہ کرم اپنی نجی کلید یا bunker URL درج کریں';

  @override
  String get keyImportPasswordRequired =>
      'براہ کرم اس خفیہ شدہ کلید کا پاس ورڈ درج کریں';

  @override
  String get keyImportSecurityWarningBody =>
      'اپنی نجی کلید کبھی کسی کے ساتھ شیئر نہ کریں۔ یہ کلید آپ کی Nostr شناخت تک مکمل رسائی دیتی ہے۔';

  @override
  String get keyImportSecurityWarningTitle => 'اپنی نجی کلید محفوظ رکھیں!';

  @override
  String get keyImportSubtitle =>
      'اپنی نجی کلید یا bunker URL سے اپنی موجودہ Nostr شناخت درآمد کریں۔';

  @override
  String get keyImportTitle => 'اپنی Nostr شناخت\nدرآمد کریں';

  @override
  String get commentAuthorYouIndicator => 'آپ';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return '$name کا پروفائل دیکھیں';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'تبصرہ حذف کریں';

  @override
  String get commentOptionsEditSemanticLabel => 'تبصرہ میں ترمیم کریں';

  @override
  String get commentOptionsFlagContentLabel => 'مواد فلیگ کریں';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'یہ مواد فلیگ کریں';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'اس تبصرے کو فلیگ کرنے کی وجہ منتخب کریں';

  @override
  String get commentOptionsFlagSubmit => 'جمع کریں';

  @override
  String get commentOptionsTitle => 'اختیارات';

  @override
  String get commentsEmptyClassicVineMessage =>
      'ہم آرکائیو سے پرانے تبصرے درآمد کرنے پر ابھی کام کر رہے ہیں۔ وہ ابھی تیار نہیں ہیں۔';

  @override
  String get commentsEmptyClassicVineTitle => 'کلاسک Vine';

  @override
  String get commentsInputEditingLabel => 'ترمیم ہو رہی ہے';

  @override
  String get commentsInputSemanticHint => 'تبصرہ شامل کریں';

  @override
  String get commentsInputSemanticHintEdit => 'تبصرہ میں ترمیم کریں';

  @override
  String get commentsInputSemanticHintReply => 'جواب شامل کریں';

  @override
  String get commentsInputSemanticLabel => 'تبصرہ ان پٹ';

  @override
  String get commentsInputSemanticLabelEdit => 'ترمیم ان پٹ';

  @override
  String get commentsInputSemanticLabelReply => 'جواب ان پٹ';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return '$displayName کا پروفائل دیکھیں';
  }

  @override
  String get classicsEmptyDescription => 'کلاسکس آرکائیو لوڈ ہو رہا ہے';

  @override
  String get classicsEmptyTitle => 'کوئی کلاسکس نہیں ملے';

  @override
  String get classicsErrorTitle => 'کلاسکس لوڈ نہیں ہو سکے';

  @override
  String get classicsUnavailableDescription =>
      'کلاسکس صرف Funnelcake ریلے سے منسلک ہونے پر دستیاب ہیں۔';

  @override
  String get classicsUnavailableSettingsHint =>
      'کلاسکس آرکائیو تک رسائی کے لیے ترتیبات میں Funnelcake فعال ریلے پر جائیں۔';

  @override
  String get classicsUnavailableTitle => 'کلاسکس دستیاب نہیں';

  @override
  String get hashtagFeedEmptySubtitle =>
      'اس ہیش ٹیگ کے ساتھ ویڈیو پوسٹ کرنے والے پہلے شخص بنیں!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return '#$hashtag کے لیے کوئی ویڈیو نہیں ملی';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'اس میں چند لمحے لگ سکتے ہیں';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return '#$hashtag کے بارے میں ویڈیوز لوڈ ہو رہی ہیں...';
  }

  @override
  String get hashtagInputHint => 'ہیش ٹیگز شامل کریں... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'نئے مواد کے لیے بعد میں دیکھیں';

  @override
  String get newVideosTabEmptyTitle => 'نئی ویڈیوز میں کوئی ویڈیو نہیں';

  @override
  String get popularVideosContextTitle => 'مقبول ویڈیوز';

  @override
  String get popularVideosEmptySubtitle => 'نئے مواد کے لیے بعد میں دیکھیں';

  @override
  String get popularVideosEmptyTitle => 'مقبول ویڈیوز میں کوئی ویڈیو نہیں';

  @override
  String get popularVideosErrorTitle => 'مقبول ویڈیوز لوڈ نہیں ہو سکیں';

  @override
  String get popularVideosFeedSourceLabel => 'مقبول فیڈ کا ماخذ';

  @override
  String get trendingHashtagsLoading => 'ہیش ٹیگز لوڈ ہو رہے ہیں...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return '$hashtag ٹیگ شدہ ویڈیوز دیکھیں';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'ویڈیو تخلیق کار: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'ویڈیو تفصیل: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine کا وژن ہے کہ آپ کو حقیقی الگورتھم چوائس ملے۔ ایک بلیک باکس الگورتھم میں قید رہنے کے بجائے، آپ متعدد سفارشی طریقوں میں سے منتخب کر سکیں گے:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'آپ کے فالو کردہ کریئیٹرز کی زمانی ترتیب والی ٹائم لائن';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'اس سے آپ کی توجہ کا کنٹرول آپ کے پاس ہوتا ہے، پلیٹ فارم کے پاس نہیں۔ آپ کو پتہ ہونا چاہیے کہ آپ کا فیڈ کیسے منتخب ہوتا ہے اور جب چاہیں اسے بدلنے کی طاقت ہونی چاہیے۔';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'موسیقی، کامیڈی یا فن جیسے موضوعات کے لیے کمیونٹی کے بنائے کسٹم فیڈز';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'ذاتی نوعیت کا \"آپ کے لیے\" فیڈ';

  @override
  String get forYouAlgorithmChoiceTitle => 'آپ کا الگورتھم، آپ کی پسند';

  @override
  String get forYouAlgorithmChoiceTrending => 'مقبول اور رجحان والا مواد';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'مضبوط اشارہ — آپ اتنے مصروف تھے کہ جواب دیا';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine آپ کے مواد سے تفاعل پر توجہ دیتا ہے تاکہ سمجھ سکے کہ آپ کو کیا پسند ہے۔ جب بھی آپ کوئی ویڈیو دیکھتے ہیں، ردعمل دیتے ہیں، تبصرہ کرتے ہیں یا ریپوسٹ کرتے ہیں، سسٹم نوٹ لے لیتا ہے۔';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'یہ کیسے کام کرتا ہے';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'مختلف کارروائیاں دلچسپی کی مختلف سطحوں کا اشارہ دیتی ہیں:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'اگر آپ نے ابھی تک دیکھنے کی تاریخ نہیں بنائی تو ہم فی الحال مقبول اور رجحان والا مواد حالیہ اپلوڈز کے ساتھ مل کر دکھاتے ہیں۔ یہ آپ کو دریافت کے لیے ایک اچھا نقطہ آغاز دیتا ہے۔';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'جیسے جیسے آپ دیکھتے، پسند کرتے اور مواد سے تفاعل کرتے ہیں، سفارشات بتدریج زیادہ ذاتی ہو جاتی ہیں۔ وقت کے ساتھ، آپ کا \'آپ کے لیے\' فیڈ ایسے کریئیٹرز کی ویڈیوز سامنے لاتا ہے جنہیں آپ شاید کبھی خود نہ ڈھونڈ پاتے۔';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Divine پر نئے ہیں؟';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'ہم ایک کھلا سسٹم بنا رہے ہیں جہاں ڈویلپرز اپنے الگورتھم بنا سکتے ہیں، اور آپ منتخب کر سکتے ہیں کہ کون سے استعمال کرنے ہیں — یا مکمل طور پر باہر نکل جائیں۔';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'اوپن سورس اور شفاف';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'درمیانا اشارہ — تعریف دکھانے کا فوری طریقہ';

  @override
  String get forYouAlgorithmReactionsTitle => 'ردعملات';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'سب سے مضبوط اشارہ — اپنے فالوورز کے ساتھ شیئر کرنا ایک طاقتور سفارش ہے';

  @override
  String get forYouAlgorithmSubtitle =>
      'Gorse پر چلتا ہے، ایک اوپن سورس سفارشی انجن';

  @override
  String get forYouAlgorithmTitle => 'Divine الگورتھم';

  @override
  String get forYouAlgorithmViewsDescription =>
      'ہلکا اشارہ — بنیادی دلچسپی دکھاتا ہے';

  @override
  String get forYouEmptyDescription =>
      'ذاتی سفارشات پانے کے لیے کچھ ویڈیوز دیکھیں اور پسند کریں۔';

  @override
  String get forYouEmptyTitle => 'ابھی کوئی سفارش نہیں';

  @override
  String get forYouErrorTitle => 'سفارشات لوڈ نہیں ہو سکیں';

  @override
  String get forYouUnavailableDescription =>
      'ذاتی سفارشات کے لیے Funnelcake سے کنکشن درکار ہے۔';

  @override
  String get forYouUnavailableTitle => '\'آپ کے لیے\' دستیاب نہیں';

  @override
  String get inboxConversationOptionsLabel => 'اختیارات';

  @override
  String get inboxConversationViewProfileButton => 'پروفائل دیکھیں';

  @override
  String get inboxMessageRequestsEmpty => 'کوئی پیغام درخواست نہیں';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'پیغام درخواستیں، $requestCount زیر التواء';
  }

  @override
  String get inboxMessageRequestsTitle => 'پیغام درخواستیں';

  @override
  String get inboxMessagesTab => 'پیغامات';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayName کی پیغام درخواست';
  }

  @override
  String get inboxRequestTileSubtitle => 'پیغام درخواست بھیجی';

  @override
  String get inboxRequestsMarkAllRead => 'تمام درخواستیں پڑھی ہوئی قرار دیں';

  @override
  String get inboxRequestsRemoveAll => 'تمام درخواستیں ہٹائیں';

  @override
  String get messageRequestDeclineAndRemoveButton => 'انکار کر کے ہٹائیں';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return '$displayName کی درخواست مسترد کر دی';
  }

  @override
  String get messageRequestLoadFailed => 'یہ درخواست لوڈ نہیں ہو سکی۔';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count فالوورز';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count ویڈیوز';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پیغامات',
      one: '1 پیغام',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'پیغامات دیکھیں';

  @override
  String get messageRequestViewProfileButton => 'پروفائل دیکھیں';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName آپ کو پیغام بھیجنا چاہتا ہے، انہوں نے $messageText بھیجا ہے۔';
  }

  @override
  String get deleteAccountAccountChanged =>
      'آپ نے اکاؤنٹ تبدیل کر لیا، اس لیے کچھ حذف نہیں ہوا۔ جس اکاؤنٹ کو ہٹانا چاہتے ہیں اس کے لیے حذف کا آپشن دوبارہ کھولیں۔';

  @override
  String get deleteAccountConfirmDeletePrompt => 'تصدیق کے لیے لکھیں:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'تصدیق کے لیے اپنا صارف نام لکھیں:';

  @override
  String get deleteAccountConfirmationHint => 'DELETE لکھیں';

  @override
  String get deleteAccountConfirmationHintUsername => 'اپنا صارف نام لکھیں';

  @override
  String get deleteAccountDeleteAllContentButton => 'تمام مواد حذف کریں';

  @override
  String get accountDeletionRecoveryTitle => 'آپ کا اکاؤنٹ حذف کیا جا رہا ہے';

  @override
  String get accountDeletionRecoveryBody =>
      'ہم آپ کا اکاؤنٹ مکمل حذف نہیں کر سکے۔ آپ کا صارف نام آپ کے لیے محفوظ ہے اور اب بھی بحال کیا جا سکتا ہے۔';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'میرا صارف نام بحال کریں';

  @override
  String get accountDeletionFinishingBody =>
      'آپ کے اکاؤنٹ کو حذف کرنے کی درخواست پر ابھی کارروائی ہو رہی ہے۔ ہمارے مکمل کرنے تک آپ کوئی دوسرا اکاؤنٹ استعمال کر سکتے ہیں۔';

  @override
  String get accountDeletionOtherAccountPending =>
      'اس ڈیوائس پر کسی دوسرے اکاؤنٹ کو حذف کرنے کی کارروائی ابھی جاری ہے۔ اس اکاؤنٹ کو حذف کرنے سے پہلے اس کے مکمل ہونے کا انتظار کریں۔';

  @override
  String get accountDeletionCancellingBody =>
      'ہم آپ کی حذف کی درخواست منسوخ کر رہے ہیں۔ یہ اسکرین چھوڑنے سے پہلے دوبارہ دیکھ لیں۔';

  @override
  String get accountDeletionRecoveryFailed =>
      'ہم ابھی آپ کا صارف نام بحال نہیں کر سکے۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get accountDeletionUsernameRestored =>
      'آپ کا صارف نام بحال ہو گیا۔ آپ کا اکاؤنٹ حذف نہیں ہوا۔';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'ہم آپ کے حذف کی صورتحال چیک نہیں کر سکے۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

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
      'اکاؤنٹ حذف کرنے کی سہولت ابھی دستیاب نہیں ہے۔ کچھ بھی حذف نہیں ہوا۔';

  @override
  String get deleteAccountDeletionIncomplete =>
      'ہم آپ کا اکاؤنٹ مکمل حذف نہیں کر سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ آخری تصدیق';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'حذف کی درخواستیں بھیج دی گئیں، لیکن ممکن ہے آپ کی کلیدیں اس ڈیوائس سے مکمل نہ ہٹائی گئی ہوں۔ دوبارہ کوشش کے لیے ترتیبات → Nostr کلیدیں → کلیدیں ہٹائیں پر جائیں۔';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'حذف کی درخواستیں بھیج دی گئیں اور آپ سائن آؤٹ ہو گئے، لیکن کچھ مقامی ڈیٹا اس ڈیوائس سے نہیں ہٹایا جا سکا۔';

  @override
  String get deleteAccountPreparingDeletion => 'حذف کی تیاری ہو رہی ہے...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total ایونٹس';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'یہ اس ڈیوائس سے اس اکاؤنٹ کا مقامی لاگ اِن ہٹا دیتا ہے۔ یہ آپ کا Divine اکاؤنٹ یا Nostr شناخت حذف نہیں کرے گا۔\n\nآپ کے مسودے اور کلپس اس ڈیوائس پر اس اکاؤنٹ کے لیے محفوظ رہیں گے۔ اگر یہ آپ کا آخری مقامی اکاؤنٹ ہے تو آپ لاگ ان اسکرین پر واپس جائیں گے۔';

  @override
  String get deleteAccountRemoveKeysConfirm => 'ڈیوائس سے ہٹائیں';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'اس اکاؤنٹ کو اس ڈیوائس سے ہٹائیں؟';

  @override
  String get deleteAccountReauthRequired =>
      'اپنا اکاؤنٹ حذف کرنے کے لیے دوبارہ سائن ان کریں۔ ابھی کچھ حذف نہیں ہوا۔';

  @override
  String get deleteAccountServerDeletionFailed =>
      'آپ کی پوسٹس کے لیے حذف کی درخواستیں بھیج دی گئیں، لیکن ہم آپ کا اکاؤنٹ مکمل حذف نہیں کر سکے۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔';

  @override
  String get deleteAccountSuccess =>
      'آپ کا Divine اکاؤنٹ حذف کر دیا گیا ہے۔ آپ کی Nostr پوسٹس کے لیے حذف کرنے کی درخواستیں بھیج دی گئی ہیں، لیکن کچھ ریلے، کلائنٹس یا کیشز ان کی نقول محفوظ رکھ سکتے ہیں۔';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'اکاؤنٹ حذف کی درخواست بھیج دی گئی۔ کچھ موجودہ پوسٹس کی انفرادی حذف کی تصدیق نہیں ہو سکی۔';

  @override
  String get deleteAccountWarningBody =>
      'یہ آپ کے اکاؤنٹ اور مواد کے لیے حذف کی درخواستیں بھیجتا ہے، ممکن ہونے پر آپ کا Divine اکاؤنٹ حذف کرتا ہے، اور اس ڈیوائس پر آپ کو سائن آؤٹ کرتا ہے۔ کچھ ریلے، کلائنٹس اور سرچ انڈیکسز کے پاس کاپیاں رہ سکتی ہیں۔ دیگر سائن اِن ڈیوائسز اس وقت تک فعال رہتی ہیں جب تک آپ وہاں کلیدیں نہ ہٹا دیں۔';

  @override
  String get findPeopleNoContacts =>
      'کوئی رابطہ نہیں ملا۔\nلوگوں کو یہاں دیکھنے کے لیے انہیں فالو کرنا شروع کریں۔';

  @override
  String get geoBlockedCityLabel => 'شہر';

  @override
  String get geoBlockedCountryLabel => 'ملک';

  @override
  String get geoBlockedDefaultReason =>
      'مقامی ضوابط کی وجہ سے یہ سروس آپ کے علاقے میں دستیاب نہیں ہے۔';

  @override
  String get geoBlockedLegalNotice =>
      'ہم آپ کے مقامی قوانین اور ضوابط کا احترام کرتے ہیں۔ یہ پابندی آپ کے IP ایڈریس کے مقام پر مبنی ہے۔';

  @override
  String get geoBlockedRegionLabel => 'علاقہ';

  @override
  String get geoBlockedTitle => 'سروس دستیاب نہیں';

  @override
  String get likedVideosEmpty => 'کوئی پسندیدہ ویڈیو نہیں';

  @override
  String get likedVideosInvalidRoute => 'غلط روٹ';

  @override
  String get likedVideosTitle => 'پسندیدہ ویڈیوز';

  @override
  String get uploadFailureSheetRetryingSnackbar =>
      'اپلوڈ دوبارہ کوشش ہو رہی ہے…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'مسودوں میں محفوظ کریں';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar =>
      'مسودوں میں محفوظ ہو گیا';

  @override
  String get uploadFailureSheetTitle => 'اپلوڈ ناکام';

  @override
  String get uploadFailureSheetTryAgainButton => 'دوبارہ کوشش کریں';

  @override
  String get videoEditorAudioImportAudio => 'آڈیو درآمد کریں';

  @override
  String get videoEditorAudioImportFailed => 'آڈیو درآمد ناکام۔';

  @override
  String get videoIconPlaceholderLabel => 'ویڈیو';

  @override
  String get publishErrorNotSignedIn =>
      'ویڈیوز شائع کرنے کے لیے براہ کرم سائن ان کریں۔';

  @override
  String get publishErrorNoRetry => 'دوبارہ کوشش کے لیے کوئی اپلوڈ نہیں۔';

  @override
  String get publishErrorNoInternet =>
      'کوئی انٹرنیٹ کنکشن نہیں۔ اپنا Wi-Fi یا موبائل ڈیٹا چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get publishErrorServerUnreachable =>
      'سرور تک رسائی نہیں ہو سکی۔ براہ کرم تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get publishErrorTimeout =>
      'اپلوڈ کا وقت ختم ہو گیا۔ مضبوط کنکشن یا چھوٹی ویڈیو آزمائیں۔';

  @override
  String get publishErrorTls =>
      'محفوظ کنکشن ناکام۔ اپنا نیٹ ورک چیک کریں — عوامی Wi-Fi اپلوڈز بلاک کر سکتا ہے۔';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'میڈیا سرور ($serverName) دستیاب نہیں ہے۔ آپ اپنی ترتیبات میں کوئی اور منتخب کر سکتے ہیں۔';
  }

  @override
  String get publishErrorFileTooLarge =>
      'ویڈیو فائل سرور کے لیے بہت بڑی ہے۔ اسے چھوٹا کریں یا کوالٹی کم کر کے دیکھیں۔';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'میڈیا سرور ($serverName) میں اندرونی خرابی آئی۔ آپ اپنی ترتیبات میں کوئی اور منتخب کر سکتے ہیں۔';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'میڈیا سرور ($serverName) عارضی طور پر بند ہے۔ تھوڑی دیر میں دوبارہ کوشش کریں یا اپنی ترتیبات میں کوئی اور منتخب کریں۔';
  }

  @override
  String get publishErrorForbidden =>
      'آپ کو اس سرور پر اپلوڈ کرنے کی اجازت نہیں ہے۔';

  @override
  String get publishErrorFileNotFound =>
      'ویڈیو فائل نہیں مل سکی۔ ممکن ہے حذف ہو گئی ہو۔ دوبارہ ریکارڈ کر کے کوشش کریں۔';

  @override
  String get publishErrorLowStorage =>
      'آپ کی ڈیوائس میں جگہ کافی نہیں۔ کچھ جگہ خالی کر کے دوبارہ کوشش کریں۔';

  @override
  String get publishErrorThumbnailFailed =>
      'ویڈیو اپلوڈ ہو گئی، لیکن تھمب نیل تیار نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get publishErrorNostrPublishFailed =>
      'ویڈیو اپلوڈ ہو گئی لیکن پوسٹ شائع نہیں ہو سکی۔ اپنی ریلے ترتیبات چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'ویڈیو اپلوڈ ہو گئی لیکن اس کی آڈیو دوبارہ استعمال کے لیے دستیاب نہیں۔ پوسٹ کرنے کے لیے کوئی دوسری آڈیو منتخب کریں۔';

  @override
  String get publishErrorInterrupted =>
      'یہ اپلوڈ رک گیا۔ کیا آپ دوبارہ کوشش کرنا چاہیں گے؟';

  @override
  String get publishErrorAccountChanged =>
      'یہ ویڈیو کسی اور اکاؤنٹ کی ہے۔ اسے پوسٹ کرنے کے لیے اُسی اکاؤنٹ پر واپس جائیں۔';

  @override
  String get publishErrorGeneric =>
      'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get publishErrorRateLimited =>
      'ابھی بہت زیادہ اپلوڈز ہیں۔ تھوڑا انتظار کر کے دوبارہ کوشش کریں۔';

  @override
  String get publishErrorUploadSessionExpired =>
      'آپ کا اپلوڈ سیشن ختم ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get publishErrorPermissionDenied =>
      'Divine کو اپلوڈ کرنے کی اجازت نہیں ہے۔ اپنی ترتیبات میں ایپ اجازتیں چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get publishErrorOutOfMemory =>
      'آپ کی ڈیوائس کی میموری کم ہے۔ کچھ ایپس بند کر کے دوبارہ کوشش کریں۔';

  @override
  String get publishErrorOverlaysUnavailable =>
      'اس مسودے کا ٹیکسٹ اور اسٹیکرز تیار نہیں ہو سکے۔ اسے ایڈیٹر میں کھولیں، پھر دوبارہ پوسٹ کریں۔';

  @override
  String get publishErrorUnknownServer => 'نامعلوم سرور';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'فلٹر: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return '\"$query\" کے لیے کوئی نتیجہ نہیں ملا';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return '$tag ٹیگ شدہ ویڈیوز دیکھیں';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'آواز: $creatorName کی $soundName۔ آواز کی تفصیلات دیکھنے کے لیے ٹیپ کریں۔';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return '$creatorName کی اصل آواز۔ یہ آواز استعمال کرنے کے لیے ٹیپ کریں۔';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'آواز: $creatorName کی $soundName۔ تفصیلات دیکھنے کے لیے ٹیپ کریں۔';
  }

  @override
  String get soundDetailLoadError =>
      'آواز لوڈ نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get soundDetailNotFoundMessage => 'یہ آواز نہیں مل سکی';

  @override
  String get soundDetailNotFoundTitle => 'آواز نہیں ملی';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count لوپ';
  }

  @override
  String get originalSoundUnavailableBody =>
      'اس ویڈیو کی آڈیو الگ سے دستیاب نہیں ہے۔';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'اصل آواز - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'اس شخص نے ایک اصل Vine پوسٹ کیا تھا جو Divine کو آرکائیو میں ملا۔ یہ اکاؤنٹ کی تصدیق کا بیج نہیں ہے۔';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'پروفائل چیک مارک';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine یہ چیک مارک ٹیم کے اکاؤنٹس کو دیتا ہے۔ یہ NIP-05، تصدیق شدہ اکاؤنٹ لنکس اور OG Viner اسٹیٹس سے الگ ہے۔';

  @override
  String get unfollowConfirmButton => 'ان فالو کریں';

  @override
  String get videoClipSaveFailed => 'کلپ محفوظ نہیں ہو سکی';

  @override
  String videoClipSaveTo(String destination) {
    return '$destination میں محفوظ کریں';
  }

  @override
  String get videoClipDelete => 'کلپ حذف کریں';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '$creatorName +$additionalCreatorCount سے متاثر۔ ان کا پروفائل دیکھنے کے لیے ٹیپ کریں۔';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return '$creatorName سے متاثر۔ ان کا پروفائل دیکھنے کے لیے ٹیپ کریں۔';
  }

  @override
  String get bugReportSendReport => 'رپورٹ بھیجیں';

  @override
  String get supportSubjectRequiredLabel => 'موضوع *';

  @override
  String get supportPublicSubmissionTitle => 'عوامی GitHub پوسٹ';

  @override
  String get supportPublicSubmissionMessage =>
      'آپ یہاں جو کچھ بھی جمع کرائیں گے وہ ہمارے اوپن سورس GitHub ریپوزٹری میں پوسٹ کیا جائے گا تاکہ ڈویلپرز اس پر کام کر سکیں۔ یہ پوسٹ اور وہ اکاؤنٹ جس سے آپ سائن اِن ہیں، سب کو عوامی طور پر نظر آئیں گے۔';

  @override
  String get supportRequiredHelper => 'درکار';

  @override
  String get supportFieldLimitReached =>
      'یہ زیادہ سے زیادہ لمبائی ہے۔ اس کے بعد کچھ بھی شامل نہیں کیا گیا۔';

  @override
  String get bugReportSubjectHint => 'مسئلے کا مختصر خلاصہ';

  @override
  String get bugReportDescriptionRequiredLabel => 'کیا ہوا؟ *';

  @override
  String get bugReportDescriptionHint => 'جو مسئلہ آیا اسے بیان کریں';

  @override
  String get bugReportStepsLabel => 'دوبارہ پیدا کرنے کے مراحل';

  @override
  String get bugReportStepsHint =>
      '1. جائیں...\n2. ٹیپ کریں...\n3. خرابی دیکھیں';

  @override
  String get bugReportExpectedBehaviorLabel => 'متوقع برتاؤ';

  @override
  String get bugReportExpectedBehaviorHint => 'اس کے بجائے کیا ہونا چاہیے تھا؟';

  @override
  String get bugReportDiagnosticsNotice =>
      'ڈیوائس کی معلومات اور لاگز خودکار طور پر شامل ہوں گے۔';

  @override
  String get bugReportSuccessMessage =>
      'شکریہ! ہمیں آپ کی رپورٹ مل گئی ہے اور ہم اسے Divine کو بہتر بنانے کے لیے استعمال کریں گے۔';

  @override
  String get bugReportAttachImages => 'تصاویر منسلک کریں';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$max میں سے $count تصاویر منتخب';
  }

  @override
  String get bugReportRemoveImage => 'تصویر ہٹائیں';

  @override
  String get bugReportUploadFailed =>
      'ہم منتخب تصویر اپلوڈ نہیں کر سکے۔ دوبارہ کوشش کریں یا اس کے بغیر رپورٹ بھیجیں۔';

  @override
  String get bugReportSendFailed =>
      'بگ رپورٹ نہیں بھیجی جا سکی۔ براہ کرم بعد میں دوبارہ کوشش کریں۔';

  @override
  String get featureRequestSendRequest => 'درخواست بھیجیں';

  @override
  String get featureRequestSubjectHint => 'آپ کے آئیڈیے کا مختصر خلاصہ';

  @override
  String get featureRequestDescriptionRequiredLabel => 'آپ کیا چاہیں گے؟ *';

  @override
  String get featureRequestDescriptionHint =>
      'جو فیچر آپ چاہتے ہیں اسے بیان کریں';

  @override
  String get featureRequestUsefulnessLabel => 'یہ کیسے مفید ہوگا؟';

  @override
  String get featureRequestUsefulnessHint =>
      'بتائیں کہ یہ فیچر کیا فائدہ دے گا';

  @override
  String get featureRequestWhenLabel => 'آپ یہ کب استعمال کریں گے؟';

  @override
  String get featureRequestWhenHint => 'ان حالات بیان کریں جہاں یہ مدد دے گا';

  @override
  String get featureRequestSuccessMessage =>
      'شکریہ! ہمیں آپ کی فیچر درخواست مل گئی ہے اور ہم اس کا جائزہ لیں گے۔';

  @override
  String get featureRequestSendFailed =>
      'فیچر درخواست نہیں بھیجی جا سکی۔ براہ کرم بعد میں دوبارہ کوشش کریں۔';

  @override
  String get notificationFollowBack => 'فالو بیک کریں';

  @override
  String get followingTitle => 'فالوئنگ';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName کی فالوئنگ';
  }

  @override
  String get followingFailedToLoadList => 'فالوئنگ فہرست لوڈ نہیں ہو سکی';

  @override
  String get followingEmptyTitle => 'ابھی کسی کو فالو نہیں کیا';

  @override
  String get followersTitle => 'فالوورز';

  @override
  String followersTitleForName(String displayName) {
    return '$displayName کے فالوورز';
  }

  @override
  String get followersFailedToLoadList => 'فالوورز فہرست لوڈ نہیں ہو سکی';

  @override
  String get followersEmptyTitle => 'ابھی کوئی فالوور نہیں';

  @override
  String get followersUpdateFollowFailed =>
      'فالو اسٹیٹس اپڈیٹ نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get followersSortSemanticLabel => 'فالوورز ترتیب دیں';

  @override
  String get followingSortSemanticLabel => 'فالوئنگ ترتیب دیں';

  @override
  String get followSortTitle => 'ترتیب بلحاظ';

  @override
  String get followSortNewest => 'پہلے نئے';

  @override
  String get followSortOldest => 'پہلے پرانے';

  @override
  String get newMessageTitle => 'نیا پیغام';

  @override
  String get newMessageFindPeople => 'لوگ تلاش کریں';

  @override
  String get newMessageNoContacts =>
      'کوئی رابطہ نہیں ملا۔\nلوگوں کو یہاں دیکھنے کے لیے انہیں فالو کریں۔';

  @override
  String get newMessageNoUsersFound => 'کوئی صارف نہیں ملا';

  @override
  String get hashtagSearchTitle => 'ہیش ٹیگز تلاش کریں';

  @override
  String get hashtagSearchSubtitle => 'مقبول موضوعات اور مواد دریافت کریں';

  @override
  String hashtagSearchNoResults(String query) {
    return '\"$query\" کے لیے کوئی ہیش ٹیگ نہیں ملا';
  }

  @override
  String get hashtagSearchFailed => 'تلاش ناکام';

  @override
  String get userNotAvailableTitle => 'اکاؤنٹ دستیاب نہیں';

  @override
  String get userNotAvailableBody => 'یہ اکاؤنٹ ابھی دستیاب نہیں ہے۔';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'ترتیبات محفوظ نہیں ہو سکیں۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get blossomValidServerUrl =>
      'براہ کرم درست سرور URL درج کریں (مثلاً https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom ترتیبات محفوظ ہو گئیں';

  @override
  String get blossomSaveTooltip => 'محفوظ کریں';

  @override
  String get blossomAboutTitle => 'Blossom کے بارے میں';

  @override
  String get blossomAboutDescription =>
      'Blossom ایک غیر مرکزی میڈیا سٹوریج پروٹوکول ہے جو آپ کو کسی بھی ہم آہنگ سرور پر ویڈیوز اپلوڈ کرنے دیتا ہے۔ ڈیفالٹ طور پر، ویڈیوز Divine کے Blossom سرور پر اپلوڈ ہوتی ہیں۔ اس کے بجائے کسٹم سرور استعمال کرنے کے لیے نیچے والا آپشن فعال کریں۔';

  @override
  String get blossomUseCustomServer => 'کسٹم Blossom سرور استعمال کریں';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'ویڈیوز آپ کے کسٹم Blossom سرور پر اپلوڈ ہوں گی';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'آپ کی ویڈیوز فی الحال Divine کے Blossom سرور پر اپلوڈ ہو رہی ہیں';

  @override
  String get blossomCustomServerUrl => 'کسٹم Blossom سرور URL';

  @override
  String get blossomCustomServerHelper =>
      'اپنے کسٹم Blossom سرور کا URL درج کریں';

  @override
  String get blossomPopularServers => 'مقبول Blossom سرورز';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom سرور URL میں https:// ہونا چاہیے';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'کراس پوسٹ ترتیب اپڈیٹ نہیں ہو سکی';

  @override
  String get blueskySignInRequired =>
      'Bluesky ترتیبات سنبھالنے کے لیے سائن ان کریں';

  @override
  String get blueskyPublishVideos => 'Bluesky پر ویڈیوز شائع کریں';

  @override
  String get blueskyEnabledSubtitle => 'آپ کی ویڈیوز Bluesky پر شائع ہوں گی';

  @override
  String get blueskyDisabledSubtitle =>
      'آپ کی ویڈیوز Bluesky پر شائع نہیں ہوں گی';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'آپ کی پچھلی ویڈیوز بھی پوسٹ ہوں گی';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'جب آپ اسے آن کریں گے تو Divine آپ کی پرانی ویڈیوز Bluesky پر بھیجنا شروع کرے گا، سب سے پرانی پہلے، روزانہ حد میں جلدی کیے بغیر۔';

  @override
  String get blueskyHandle => 'Bluesky ہینڈل';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => 'اسٹیٹس';

  @override
  String get blueskyStatusReady => 'اکاؤنٹ تیار اور دستیاب ہے';

  @override
  String get blueskyStatusPending => 'اکاؤنٹ تیار ہو رہا ہے...';

  @override
  String get blueskyStatusFailed => 'اکاؤنٹ تیار کرنا ناکام';

  @override
  String get blueskyStatusDisabled => 'اکاؤنٹ غیر فعال';

  @override
  String get blueskyStatusNotLinked => 'کوئی Bluesky اکاؤنٹ منسلک نہیں';

  @override
  String get blueskyUsernameRequired =>
      'Bluesky پر شائع کرنے سے پہلے divine.video ہینڈل سیٹ اپ کریں';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Bluesky اشاعت کے لیے حاصل شدہ username.divine.video ہینڈل درکار ہے۔';

  @override
  String get blueskyUsernameSyncPending =>
      'آپ کا Divine ہینڈل حاصل ہو گیا ہے۔ ہم اسے Bluesky سے جوڑ رہے ہیں — تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get blueskyStatusUnavailableRetry =>
      'ہم آپ کا Divine ہینڈل چیک نہیں کر سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get blueskySetUpHandle => 'سیٹ اپ کریں';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Bluesky اشاعت عارضی طور پر دستیاب نہیں ہے۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get invitesTitle => 'دوستوں کو دعوت دیں';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوتیں بنانے کے لیے تیار',
      one: '1 دعوت بنانے کے لیے تیار',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'جب آپ کوئی دعوت شیئر کرنے کے لیے تیار ہوں تو کوڈ بنائیں۔';

  @override
  String get invitesGenerateButtonLabel => 'دعوت بنائیں';

  @override
  String get invitesNoneAvailable => 'ابھی کوئی دعوت دستیاب نہیں';

  @override
  String get invitesShareWithPeople =>
      'جنہیں آپ جانتے ہیں ان کے ساتھ Divine شیئر کریں';

  @override
  String get invitesUsedInvites => 'استعمال شدہ دعوتیں';

  @override
  String invitesShareMessage(String code) {
    return 'Divine پر میرے ساتھ آئیں! شروع کرنے کے لیے دعوتی کوڈ $code استعمال کریں:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'دعوت کاپی کریں';

  @override
  String get invitesCopied => 'دعوت کاپی ہو گئی!';

  @override
  String get invitesShareInvite => 'دعوت شیئر کریں';

  @override
  String get invitesShareSubject => 'Divine پر میرے ساتھ آئیں';

  @override
  String get invitesClaimed => 'حاصل کی گئی';

  @override
  String get invitesCouldNotLoad => 'دعوتیں لوڈ نہیں ہو سکیں';

  @override
  String get invitesRetry => 'دوبارہ کوشش کریں';

  @override
  String get searchSomethingWentWrong => 'کچھ غلط ہو گیا';

  @override
  String get searchTryAgain => 'دوبارہ کوشش کریں';

  @override
  String get searchForLists => 'فہرستیں تلاش کریں';

  @override
  String get searchFindCuratedVideoLists => 'منتخب ویڈیو فہرستیں تلاش کریں';

  @override
  String get searchEnterQuery => 'تلاش کی اصطلاح درج کریں';

  @override
  String get searchDiscoverSomethingInteresting => 'کچھ دلچسپ دریافت کریں';

  @override
  String get searchPeopleSectionHeader => 'لوگ';

  @override
  String get searchPeopleLoadingLabel => 'لوگوں کے نتائج لوڈ ہو رہے ہیں';

  @override
  String get searchTagsSectionHeader => 'ٹیگز';

  @override
  String get searchTagsLoadingLabel => 'ٹیگ نتائج لوڈ ہو رہے ہیں';

  @override
  String get searchVideosSectionHeader => 'ویڈیوز';

  @override
  String get searchVideosLoadingLabel => 'ویڈیو نتائج لوڈ ہو رہے ہیں';

  @override
  String get searchVideosSortOptionsLabel => 'ویڈیو نتائج ترتیب دیں';

  @override
  String get searchVideosSortTrending => 'مقبول';

  @override
  String get searchVideosSortLoops => 'سب سے زیادہ لوپ';

  @override
  String get searchVideosSortEngagement => 'سب سے زیادہ مصروفیت';

  @override
  String get searchVideosSortRecent => 'تازہ ترین';

  @override
  String get searchListsSectionHeader => 'فہرستیں';

  @override
  String get searchListsLoadingLabel => 'فہرست نتائج لوڈ ہو رہے ہیں';

  @override
  String get cameraAgeRestriction =>
      'مواد بنانے کے لیے آپ کی عمر 16 سال یا زیادہ ہونی چاہیے';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker ریلے میں wss:// ہونا چاہیے (ws:// صرف localhost کے لیے جائز ہے)';

  @override
  String get timeNow => 'ابھی';

  @override
  String timeShortMinutes(int count) {
    return '$count منٹ';
  }

  @override
  String timeShortHours(int count) {
    return '$count گھنٹہ';
  }

  @override
  String timeShortDays(int count) {
    return '$count دن';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count ہفتہ';
  }

  @override
  String timeShortMonths(int count) {
    return '$count مہینہ';
  }

  @override
  String timeShortYears(int count) {
    return '$count سال';
  }

  @override
  String get timeVerboseNow => 'ابھی';

  @override
  String timeAgo(String time) {
    return '$time پہلے';
  }

  @override
  String get timeToday => 'آج';

  @override
  String get timeYesterday => 'کل';

  @override
  String get timeJustNow => 'ابھی ابھی';

  @override
  String timeMinutesAgo(int count) {
    return '$count منٹ پہلے';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count گھنٹے پہلے';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count دن پہلے';
  }

  @override
  String get draftTimeJustNow => 'ابھی ابھی';

  @override
  String get contentLabelNudity => 'عریانیت';

  @override
  String get contentLabelSexualContent => 'جنسی مواد';

  @override
  String get contentLabelPornography => 'فحش مواد';

  @override
  String get contentLabelGraphicMedia => 'گرافک میڈیا';

  @override
  String get contentLabelViolence => 'تشدد';

  @override
  String get contentLabelSelfHarm => 'خود کو نقصان/خودکشی';

  @override
  String get contentLabelDrugUse => 'منشیات کا استعمال';

  @override
  String get contentLabelAlcohol => 'شراب';

  @override
  String get contentLabelTobacco => 'تمباکو/سگریٹ';

  @override
  String get contentLabelGambling => 'جوا';

  @override
  String get contentLabelProfanity => 'گالم گلوچ';

  @override
  String get contentLabelHateSpeech => 'نفرت انگیز تقریر';

  @override
  String get contentLabelHarassment => 'ہراسانی';

  @override
  String get contentLabelFlashingLights => 'چمکتی روشنیاں';

  @override
  String get contentLabelAiGenerated => 'AI تیار کردہ';

  @override
  String get contentLabelDeepfake => 'ڈیپ فیک';

  @override
  String get contentLabelSpam => 'اسپیم';

  @override
  String get contentLabelScam => 'فراڈ/دھوکہ';

  @override
  String get contentLabelSpoiler => 'اسپوائلر';

  @override
  String get contentLabelMisleading => 'گمراہ کن';

  @override
  String get contentLabelSensitiveContent => 'حساس مواد';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName نے آپ کی ویڈیو پسند کی';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName نے آپ کا تبصرہ پسند کیا';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName نے آپ کی ویڈیو پر تبصرہ کیا';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName نے آپ کو فالو کرنا شروع کیا';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName نے آپ کا ذکر کیا';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName نے آپ کی ویڈیو ریپوسٹ کی';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName نے نئی ویڈیو پوسٹ کی';
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
      other: 'آپ کی $count وائنز',
      one: 'آپ کی وائن',
    );
    return '$actorName نے $_temp0 کو $listName میں شامل کیا';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName نے آپ کے تبصرے کا جواب دیا';
  }

  @override
  String get notificationAndConnector => 'اور';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دیگر',
      one: '1 دیگر',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'آپ کے لیے ایک نئی اپڈیٹ ہے';

  @override
  String get commentReplyToPrefix => 'جواب:';

  @override
  String get commentHideKeyboard => 'کی بورڈ چھپائیں';

  @override
  String get commentsErrorLoadFailed => 'تبصرے لوڈ نہیں ہو سکے';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'تبصرہ کرنے کے لیے براہ کرم سائن ان کریں';

  @override
  String get commentsErrorPostCommentFailed => 'تبصرہ پوسٹ نہیں ہو سکا';

  @override
  String get commentsErrorPostReplyFailed => 'جواب پوسٹ نہیں ہو سکا';

  @override
  String get commentsErrorEditFailed => 'تبصرہ میں ترمیم نہیں ہو سکی';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'تفاعل کے لیے براہ کرم سائن ان کریں';

  @override
  String get commentsErrorVoteFailed => 'تبصرے پر ووٹ نہیں ہو سکا';

  @override
  String get commentsErrorReportFailed => 'تبصرے کی رپورٹ نہیں ہو سکی';

  @override
  String get commentsErrorBlockFailed => 'صارف بلاک نہیں ہو سکا';

  @override
  String get commentsErrorDeleteFailed => 'تبصرہ حذف نہیں ہو سکا';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تبصرے',
      one: '$count تبصرہ',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'پوسٹ ہو رہا ہے…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'آپ کا ویڈیو جواب پوسٹ ہو رہا ہے';

  @override
  String get commentsSortNew => 'نئے';

  @override
  String get commentsSortTop => 'بہترین';

  @override
  String get commentsSortOld => 'پرانے';

  @override
  String get commentsSortSemanticLabel => 'تبصروں کی ترتیب';

  @override
  String get commentReply => 'جواب';

  @override
  String get commentReplySemanticLabel => 'تبصرے کا جواب دیں';

  @override
  String get commentUpvoteLabel => 'تبصرے کو اپ ووٹ کریں';

  @override
  String get commentRemoveUpvoteLabel => 'اپ ووٹ ہٹائیں';

  @override
  String get commentDownvoteLabel => 'تبصرے کو ڈاؤن ووٹ کریں';

  @override
  String get commentRemoveDownvoteLabel => 'ڈاؤن ووٹ ہٹائیں';

  @override
  String get commentsInputHint => 'تبصرہ شامل کریں...';

  @override
  String get commentsInputHintEdit => 'تبصرہ میں ترمیم کریں...';

  @override
  String get commentsEmptyTitle => 'ابھی کوئی تبصرہ نہیں';

  @override
  String get commentsEmptySubtitle => 'پارٹی شروع کریں!';

  @override
  String get draftUntitled => 'بلا عنوان';

  @override
  String get contentWarningNone => 'کوئی نہیں';

  @override
  String get textBackgroundNone => 'کوئی نہیں';

  @override
  String get textBackgroundSolid => 'ٹھوس';

  @override
  String get textBackgroundHighlight => 'نمایاں';

  @override
  String get textBackgroundTransparent => 'شفاف';

  @override
  String get textAlignLeft => 'بائیں';

  @override
  String get textAlignRight => 'دائیں';

  @override
  String get textAlignCenter => 'درمیان';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'کیمرہ ابھی ویب پر تعاون یافتہ نہیں';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'کیمرہ کیپچر اور ریکارڈنگ ابھی ویب ورژن میں دستیاب نہیں ہیں۔';

  @override
  String get cameraPermissionBackToFeed => 'فیڈ پر واپس';

  @override
  String get cameraCouldNotStart => 'کیمرہ شروع نہیں ہو سکا';

  @override
  String get cameraUnsupportedPlatform =>
      'اس پلیٹ فارم پر کیمرہ ابھی دستیاب نہیں ہے۔\nآپ پھر بھی ویڈیوز دیکھ سکتے ہیں۔';

  @override
  String get cameraPermissionErrorTitle => 'اجازت کی خرابی';

  @override
  String get cameraPermissionErrorDescription =>
      'اجازتیں چیک کرتے وقت کچھ غلط ہو گیا۔';

  @override
  String get cameraPermissionRetry => 'دوبارہ کوشش کریں';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'کیمرہ اور مائکروفون تک رسائی کی اجازت دیں';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'اس سے آپ ایپ کے اندر ہی ویڈیوز کیپچر اور ایڈٹ کر سکتے ہیں، بس اتنا ہی۔';

  @override
  String get cameraPermissionGoToSettings => 'ترتیبات پر جائیں';

  @override
  String get videoRecorderWhySixSecondsTitle => 'چھ سیکنڈ کیوں؟';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'چھوٹی کلپس بے ساختگی کی جگہ بناتی ہیں۔ 6 سیکنڈ کا فارمیٹ آپ کو سچے لمحے جوں کے توں قید کرنے میں مدد دیتا ہے۔';

  @override
  String get videoRecorderWhySixSecondsButton => 'سمجھ گیا!';

  @override
  String get videoRecorderUploadTitle => 'اپلوڈ کیوں نہیں؟';

  @override
  String get videoRecorderUploadBody =>
      'Divine پر جو کچھ آپ دیکھتے ہیں وہ انسانوں کا بنایا ہوا ہے: کچا اور اسی لمحے میں پکڑا گیا۔ جن پلیٹ فارمز پر تیار کردہ یا AI بنائی ہوئی اپلوڈز ہوتی ہیں ان کے برعکس، ہم کیمرہ براہ راست تجربے کی اصالت کو ترجیح دیتے ہیں۔';

  @override
  String get videoRecorderUploadBodyDetail =>
      'تخلیق کو ایپ کے اندر رکھ کر، ہم بہتر طور پر ضمانت دے سکتے ہیں کہ مواد اصلی اور غیر ترمیم شدہ ہے۔ ہم اس وقت بیرونی گیلری اپلوڈز نہیں کھول رہے تاکہ اس اصلیت کی حفاظت ہو سکے اور اپنی کمیونٹی کو مصنوعی مواد سے جتنا ممکن ہو پاک رکھ سکیں۔';

  @override
  String get videoRecorderUploadBodyCta =>
      'کچھ اصلی بنانے کے لیے Capture یا Classic پر جائیں۔';

  @override
  String get videoRecorderUploadLearnMore => 'جانیں کہ تصدیق کیسے کام کرتی ہے';

  @override
  String get videoRecorderAutosaveFoundTitle => 'ہمیں جاری کام ملا';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'کیا آپ جہاں چھوڑا تھا وہیں سے جاری رکھنا چاہیں گے؟';

  @override
  String get videoRecorderAutosaveContinueButton => 'ہاں، جاری رکھیں';

  @override
  String get videoRecorderAutosaveDiscardButton => 'نہیں، نئی ویڈیو شروع کریں';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'آپ کا مسودہ بحال نہیں ہو سکا';

  @override
  String get videoRecorderStopRecordingTooltip => 'ریکارڈنگ روکیں';

  @override
  String get videoRecorderStartRecordingTooltip => 'ریکارڈنگ شروع کریں';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'ریکارڈنگ ہو رہی ہے۔ روکنے کے لیے کہیں بھی ٹیپ کریں';

  @override
  String get videoRecorderTapToStartLabel =>
      'ریکارڈنگ شروع کرنے کے لیے کہیں بھی ٹیپ کریں';

  @override
  String get videoRecorderDeleteLastClipLabel => 'آخری کلپ حذف کریں';

  @override
  String get videoRecorderSwitchCameraLabel => 'کیمرہ بدلیں';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return '$zoom× تک زوم کریں';
  }

  @override
  String get videoRecorderToggleGridLabel => 'گرڈ ٹوگل کریں';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'گھوسٹ فریم ٹوگل کریں';

  @override
  String get videoRecorderGhostFrameEnabled => 'گھوسٹ فریم فعال';

  @override
  String get videoRecorderGhostFrameDisabled => 'گھوسٹ فریم غیر فعال';

  @override
  String get videoRecorderClipDeletedMessage => 'کلپ ٹریش میں منتقل ہو گئی';

  @override
  String get videoRecorderClipUndoLabel => 'واپس کریں';

  @override
  String get libraryTrashEmptyTitle => 'ٹریش خالی ہے';

  @override
  String get libraryTrashEmptySubtitle =>
      'حذف شدہ کلپس ہمیشہ کے لیے ہٹانے سے پہلے 30 دن یہاں رہتی ہیں۔';

  @override
  String get libraryTrashRestoreLabel => 'بحال کریں';

  @override
  String get libraryTrashDeleteNowLabel => 'ابھی حذف کریں';

  @override
  String get libraryTrashEmptyAllLabel => 'ٹریش خالی کریں';

  @override
  String get libraryTrashDeleteConfirmTitle => 'کلپ ابھی حذف کریں؟';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'یہ کلپ فوراً ٹریش سے ہٹا دے گا۔';

  @override
  String get libraryTrashEmptyConfirmTitle => 'ٹریش خالی کریں؟';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس',
      one: '1 کلپ',
    );
    return 'یہ $_temp0 فوراً ٹریش سے مستقل طور پر حذف کر دے گا۔';
  }

  @override
  String get videoRecorderCloseLabel => 'ویڈیو ریکارڈر بند کریں';

  @override
  String get videoRecorderContinueToEditorLabel => 'ویڈیو ایڈیٹر پر جائیں';

  @override
  String get videoRecorderCameraPreviewLabel => 'کیمرہ پیش منظر';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'کیمرے کو فوکس کریں';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return '$mode موڈ پر سوئچ کریں';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'ریکارڈنگ سے پہلے آڈیو شامل کریں';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'ویڈیو نہیں بن سکی۔ دوبارہ کوشش کریں۔';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شاٹس باقی',
      one: '1 شاٹ باقی',
      zero: 'کوئی شاٹ باقی نہیں',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'فلیش ٹوگل کریں';

  @override
  String get videoRecorderCycleTimerLabel => 'ٹائمر تبدیل کریں';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'ایسپیکٹ ریشو ٹوگل کریں';

  @override
  String get videoRecorderStabilizationLabel => 'استحکام';

  @override
  String get videoRecorderStabilizationModeOff => 'بند';

  @override
  String get videoRecorderStabilizationModeStandard => 'معیاری';

  @override
  String get videoRecorderStabilizationModeCinematic => 'سنیمیٹک';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'سنیمیٹک توسیعی';

  @override
  String get videoRecorderStabilizationModePreviewOptimized => 'پیش منظر بہتر';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'کم تاخیر';

  @override
  String get videoRecorderStabilizationModeAuto => 'خودکار';

  @override
  String get videoRecorderFlashValueOff => 'بند';

  @override
  String get videoRecorderFlashValueOn => 'چالو';

  @override
  String get videoRecorderFlashValueAuto => 'خودکار';

  @override
  String get videoRecorderTimerValueOff => 'بند';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 سیکنڈ';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 سیکنڈ';

  @override
  String get videoRecorderAspectRatioValueSquare => 'مربع';

  @override
  String get videoRecorderAspectRatioValueVertical => 'عمودی';

  @override
  String get videoRecorderCameraValueFront => 'سامنے والا کیمرہ';

  @override
  String get videoRecorderCameraValueBack => 'پچھلا کیمرہ';

  @override
  String get videoRecorderLibraryEmptyLabel => 'کلپ لائبریری، کوئی کلپ نہیں';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'کلپ لائبریری کھولیں، $clipCount کلپس',
      one: 'کلپ لائبریری کھولیں، 1 کلپ',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'اسٹاپ موشن لائبریری کھولیں، $frameCount فریم',
      one: 'اسٹاپ موشن لائبریری کھولیں، 1 فریم',
      zero: 'اسٹاپ موشن لائبریری کھولیں',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'کیمرہ';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'کیمرہ کھولیں';

  @override
  String get videoEditorLibraryLabel => 'لائبریری';

  @override
  String get videoEditorTextLabel => 'ٹیکسٹ';

  @override
  String get videoEditorDrawLabel => 'ڈرائنگ';

  @override
  String get videoEditorFilterLabel => 'فلٹر';

  @override
  String get videoEditorTuneLabel => 'ایڈجسٹ';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'ایڈجسٹمنٹ ایڈیٹر کھولیں';

  @override
  String get videoEditorTuneBrightness => 'چمک';

  @override
  String get videoEditorTuneContrast => 'کنٹراسٹ';

  @override
  String get videoEditorTuneSaturation => 'سیچوریشن';

  @override
  String get videoEditorTuneExposure => 'ایکسپوژر';

  @override
  String get videoEditorTuneHue => 'رنگت';

  @override
  String get videoEditorTuneTemperature => 'درجہ حرارت';

  @override
  String get videoEditorTuneTint => 'ٹنٹ';

  @override
  String get videoEditorTuneFade => 'فیڈ';

  @override
  String get videoEditorAudioLabel => 'آڈیو';

  @override
  String get videoEditorAddTitle => 'شامل کریں';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'لائبریری کھولیں';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'آڈیو ایڈیٹر کھولیں';

  @override
  String get videoEditorCaptionsLabel => 'کیپشن';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'کیپشن ایڈیٹر کھولیں';

  @override
  String get videoEditorCaptionsBurnInLabel => 'ویڈیو میں جا کریں';

  @override
  String get videoEditorCaptionsPresetCustom => 'کسٹم';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'کسٹم اسٹائل';

  @override
  String get videoEditorCaptionsCustomApply => 'لاگو کریں';

  @override
  String get videoEditorCaptionsCustomFont => 'فانٹ';

  @override
  String get videoEditorCaptionsCustomTextColor => 'ٹیکسٹ کا رنگ';

  @override
  String get videoEditorCaptionsCustomBackground => 'پس منظر';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'پس منظر کا رنگ';

  @override
  String get videoEditorCaptionsCustomAnimation => 'اینیمیشن';

  @override
  String get videoEditorCaptionsAnimationNone => 'کوئی نہیں';

  @override
  String get videoEditorCaptionsAnimationFade => 'فیڈ';

  @override
  String get videoEditorCaptionsAnimationPop => 'پاپ';

  @override
  String get videoEditorCaptionsAnimationSpring => 'اسپرنگ';

  @override
  String get videoEditorCaptionsEditTitle => 'کیپشن';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'آواز سن رہے ہیں…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'آپ کی آڈیو کو کیپشن تجاویز میں بدل رہے ہیں۔';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'ہمیں کوئی آواز نہیں سنائی دی۔ آپ پھر بھی خود کیپشن لکھ سکتے ہیں۔';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'اس ڈیوائس پر آواز شناخت دستیاب نہیں ہے۔ آپ خود کیپشن لکھ سکتے ہیں۔';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'آواز شناخت کی اجازت نہیں ہے۔ اسے ترتیبات میں فعال کریں یا خود کیپشن لکھیں۔';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'اس بار ٹرانسکرپشن نہیں ہو سکی۔ آپ خود کیپشن لکھ سکتے ہیں۔';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'خود کیپشن لکھوں';

  @override
  String get videoEditorCaptionsAddCue => 'کیپشن شامل کریں';

  @override
  String get videoEditorCaptionsCueTextHint => 'کیپشن متن';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'کیپشن حذف کریں';

  @override
  String get videoEditorCaptionsDeleteTrack => 'تمام کیپشن ہٹائیں';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => 'کیپشن ہٹائیں؟';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'تمام کیپشن متن اور ٹائمنگ ختم ہو جائے گی۔';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => 'کیپشن ایڈیٹر بند کریں';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'کیپشن کی تصدیق کریں';

  @override
  String get videoEditorCaptionsPresetTitle => 'کیپشن اسٹائل';

  @override
  String get videoEditorCaptionsPresetClassic => 'کلاسک';

  @override
  String get videoEditorCaptionsPresetPop => 'پاپ';

  @override
  String get videoEditorCaptionsPresetZoom => 'زوم';

  @override
  String get videoEditorCaptionsPresetSpring => 'اسپرنگ';

  @override
  String get videoEditorCaptionsPresetMono => 'مونو';

  @override
  String get videoEditorCaptionsPresetHeadline => 'ہیڈلائن';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'ٹائپ رائٹر';

  @override
  String get videoEditorCaptionsPresetMarker => 'مارکر';

  @override
  String get videoEditorCaptionsPresetScript => 'سکرپٹ';

  @override
  String get videoEditorCaptionsPresetRetro => 'ریٹرو';

  @override
  String get videoEditorCaptionsPresetElegant => 'نفیس';

  @override
  String get videoEditorCaptionsPresetBubble => 'بلبلہ';

  @override
  String get videoEditorCaptionsPresetNeon => 'نیون';

  @override
  String get videoEditorCaptionsPresetBold => 'گہرا';

  @override
  String get videoEditorCaptionsPresetDreamy => 'خوابناک';

  @override
  String get videoEditorCaptionsPresetOcean => 'سمندری';

  @override
  String get videoEditorCaptionsPresetSunny => 'دھوپ دار';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'ہاتھ کی لکھائی';

  @override
  String get videoEditorCaptionsPresetSerif => 'سیرف';

  @override
  String get videoEditorCaptionsPresetStamp => 'مہر';

  @override
  String get videoEditorOpenTextSemanticLabel => 'ٹیکسٹ ایڈیٹر کھولیں';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'ڈرائنگ ایڈیٹر کھولیں';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'فلٹر ایڈیٹر کھولیں';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'اسٹیکر ایڈیٹر کھولیں';

  @override
  String get videoEditorSaveDraftTitle => 'اپنا مسودہ محفوظ کریں؟';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'اپنی ترامیم بعد کے لیے رکھیں، یا انہیں چھوڑ کر ایڈیٹر سے نکل جائیں۔';

  @override
  String get videoEditorSaveDraftButton => 'مسودہ محفوظ کریں';

  @override
  String get videoEditorDiscardChangesButton => 'تبدیلیاں چھوڑ دیں';

  @override
  String get videoEditorKeepEditingButton => 'ترمیم جاری رکھیں';

  @override
  String get videoEditorDeleteLayerDropZone => 'لیئر حذف ڈراپ زون';

  @override
  String get videoEditorReleaseToDeleteLayer => 'لیئر حذف کرنے کے لیے چھوڑیں';

  @override
  String get videoEditorDoneLabel => 'ہو گیا';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'ویڈیو چلائیں یا روکیں';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'تقسیم کی پوزیشن غلط ہے۔ دونوں کلپس کم از کم ${minDurationMs}ms لمبی ہونی چاہئیں۔';
  }

  @override
  String get videoEditorSaveSelectedClip => 'منتخب کلپ محفوظ کریں';

  @override
  String get videoEditorSaveClip => 'کلپ محفوظ کریں';

  @override
  String get videoEditorClipSavedSuccess => 'کلپ لائبریری میں محفوظ ہو گئی';

  @override
  String get videoEditorClipSaveFailed => 'کلپ محفوظ نہیں ہو سکی';

  @override
  String get videoEditorColorPickerSemanticLabel => 'رنگ چننے والا';

  @override
  String get videoEditorUndoSemanticLabel => 'واپس کریں';

  @override
  String get videoEditorRedoSemanticLabel => 'دوبارہ کریں';

  @override
  String get videoEditorTextColorSemanticLabel => 'ٹیکسٹ کا رنگ';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'ٹیکسٹ سیدھ';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'ٹیکسٹ پس منظر';

  @override
  String get videoEditorFontSemanticLabel => 'فانٹ';

  @override
  String get videoEditorNoStickersFound => 'کوئی اسٹیکر نہیں ملا';

  @override
  String get videoEditorNoStickersAvailable => 'کوئی اسٹیکر دستیاب نہیں';

  @override
  String get videoEditorFailedLoadStickers => 'اسٹیکرز لوڈ نہیں ہو سکے';

  @override
  String get videoEditorVoiceOverLabel => 'وائس اوور';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'ریکارڈنگ $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'وائس اوور ریکارڈ کریں';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'ریکارڈنگ شروع کریں';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'ریکارڈنگ روکیں';

  @override
  String get videoEditorVoiceOverHint =>
      'ریکارڈ کرنے کے لیے ٹیپ کریں۔ جتنے چاہیں ٹیک شامل کریں۔';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ریکارڈنگز',
      one: '1 ریکارڈنگ',
      zero: 'ابھی کوئی ریکارڈنگ نہیں',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'آخری ریکارڈنگ حذف کریں';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'مائکروفون تک رسائی درکار ہے';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'وائس اوور ریکارڈ کرنے کے لیے مائکروفون تک رسائی کی اجازت دیں۔';

  @override
  String get videoEditorVoiceOverOpenSettings => 'ترتیبات کھولیں';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'ریکارڈنگ شروع ہو گئی';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'ریکارڈنگ محفوظ ہو گئی';

  @override
  String get videoEditorVoiceOverTooLong => 'ریکارڈنگ آپ کی ویڈیو سے لمبی ہے';

  @override
  String get videoEditorPlaySemanticLabel => 'چلائیں';

  @override
  String get videoEditorPauseSemanticLabel => 'روکیں';

  @override
  String get videoEditorVolumeSemanticLabel => 'آواز ایڈجسٹ کریں';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'آواز $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust =>
      'ایڈجسٹ کرنے کے لیے سلائیڈ کریں';

  @override
  String get videoEditorChromaKeyLabel => 'گرین اسکرین';

  @override
  String get videoEditorChromaKeyTitle => 'گرین اسکرین';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'اس کلپ کے لیے گرین اسکرین سیٹ کریں';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'گرین اسکرین کی تبدیلیاں رد کریں';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'گرین اسکرین لاگو کریں';

  @override
  String get videoEditorChromaKeyAutoDetect => 'خودکار شناخت';

  @override
  String get videoEditorChromaKeyPresetGreen => 'سبز';

  @override
  String get videoEditorChromaKeyPresetBlue => 'نیلا';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'اسکرین کا رنگ';

  @override
  String get videoEditorChromaKeyAmountLabel => 'مقدار';

  @override
  String get videoEditorChromaKeyAmountHint => 'اسکرین کا رنگ کتنا غائب ہوگا';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'کنارہ';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'کٹاؤ کو نرم کرتا ہے تاکہ بال کھردرے نہ لگیں';

  @override
  String get videoEditorChromaKeySpillLabel => 'رنگ کی جھلک';

  @override
  String get videoEditorChromaKeySpillHint =>
      'اسکرین کا رنگ آپ کے سبجیکٹ سے ہٹاتا ہے';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'اس سے بدلیں';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'کچھ نہیں';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'رنگ';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'تصویر';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'کلپ';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'ویڈیو شفافیت محفوظ نہیں رکھ سکتی، اس لیے یہ سیاہ ایکسپورٹ ہوگی۔';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'کوئی اسکرین نہیں ملی۔ اسے فریم کے کناروں تک پہنچنا چاہیے — ورنہ رنگ خود منتخب کریں۔';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'کلپ چنیں';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'آپ کی لائبریری خالی ہے۔ پہلے کوئی کلپ محفوظ کریں، پھر اسے پس منظر کے طور پر استعمال کریں۔';

  @override
  String get videoEditorChromaKeyImagePickFailed => 'وہ تصویر لوڈ نہیں ہو سکی۔';

  @override
  String get videoEditorChromaKeyRemove => 'گرین اسکرین ہٹائیں';

  @override
  String get videoEditorChromaKeyFailed =>
      'گرین اسکرین لاگو نہیں ہو سکی۔ آپ کا کلپ ویسا ہی ہے۔';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'گرین اسکرین ہٹائی نہیں جا سکی۔ آپ کا کلپ ویسا ہی ہے۔';

  @override
  String get videoEditorChromaKeyApplying => 'گرین اسکرین لاگو ہو رہی ہے…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'یہ ڈیوائس لائیو پیش منظر نہیں دکھا سکتی۔ ایکسپورٹ کے وقت آپ کی ترتیبات پھر بھی لاگو ہوں گی۔';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'کلپ $index';
  }

  @override
  String get videoEditorDeleteLabel => 'حذف کریں';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'منتخب آئٹم حذف کریں';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'فی تصویر فریم';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فریم',
      one: '1 فریم',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'فریم';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return 'فی تصویر $count فریم';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'اسٹاپ موشن فریم $total میں سے $position';
  }

  @override
  String get videoEditorEditLabel => 'ترمیم';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'منتخب آئٹم میں ترمیم کریں';

  @override
  String get videoEditorDuplicateLabel => 'نقل کریں';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'منتخب آئٹم کی نقل کریں';

  @override
  String get videoEditorCombineLabel => 'ملائیں';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'منتخب ڈرائنگز کو ایک لیئر میں ملائیں';

  @override
  String get videoEditorSplitLabel => 'تقسیم کریں';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'منتخب کلپ تقسیم کریں';

  @override
  String get videoEditorExtractAudioLabel => 'آڈیو نکالیں';

  @override
  String get videoEditorClipAudioTitle => 'کلپ آڈیو';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'کلپ سے آڈیو نکالیں اور اصل کو میوٹ کریں';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'آڈیو نہیں نکالی جا سکتی: کلپ مقامی طور پر دستیاب نہیں ہے۔';

  @override
  String get videoEditorExtractAudioFailed =>
      'آڈیو نہیں نکالی جا سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get videoEditorSpeedLabel => 'رفتار';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'منتخب کلپ کی پلے بیک رفتار مقرر کریں';

  @override
  String get videoEditorReverseLabel => 'الٹائیں';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'منتخب کلپ کی الٹی پلے بیک ٹوگل کریں';

  @override
  String get videoEditorReverseProgressLabel =>
      'ایک لمحہ، ہم آپ کی کلپ الٹا رہے ہیں';

  @override
  String get videoEditorTransformLabel => 'ٹرانسفارم';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'منتخب کلپ کراپ، گھمائیں یا پلٹیں';

  @override
  String get videoEditorTransformProgressLabel =>
      'ایک لمحہ، ہم آپ کی کلپ ٹرانسفارم کر رہے ہیں';

  @override
  String get videoEditorTransformFailed =>
      'کلپ ٹرانسفارم نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get videoEditorTransformNoLocalFile =>
      'ٹرانسفارم نہیں ہو سکتا: کلپ مقامی طور پر دستیاب نہیں ہے۔';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'منتخب فریم کو کراپ، گھمائیں یا پلٹیں';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'ایک لمحہ، ہم آپ کا فریم تبدیل کر رہے ہیں';

  @override
  String get videoEditorTransformFrameFailed =>
      'فریم تبدیل نہیں ہو سکا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get videoEditorTransformRotateLabel => 'گھمائیں';

  @override
  String get videoEditorTransformFlipLabel => 'پلٹیں';

  @override
  String get videoEditorTransformResetLabel => 'ری سیٹ';

  @override
  String get videoEditorTransformApplySemanticLabel => 'ٹرانسفارم لاگو کریں';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'ٹرانسفارم منسوخ کریں';

  @override
  String get videoEditorTransformPlayLabel => 'چلائیں';

  @override
  String get videoEditorTransformPauseLabel => 'روکیں';

  @override
  String get videoEditorReverseNoLocalFile =>
      'الٹا نہیں ہو سکتا: کلپ مقامی طور پر دستیاب نہیں ہے۔';

  @override
  String get videoEditorReverseFailed =>
      'کلپ الٹی نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get videoEditorSpeedSheetTitle => 'کلپ رفتار';

  @override
  String get videoEditorTransitionSheetTitle => 'ٹرانزیشن';

  @override
  String get videoEditorTransitionNone => 'کوئی نہیں';

  @override
  String get videoEditorTransitionDissolve => 'ڈیزالو';

  @override
  String get videoEditorTransitionFadeToBlack => 'سیاہ میں فیڈ';

  @override
  String get videoEditorTransitionFadeToWhite => 'سفید میں فیڈ';

  @override
  String get videoEditorTransitionSlide => 'سلائیڈ';

  @override
  String get videoEditorTransitionPush => 'پش';

  @override
  String get videoEditorTransitionWipe => 'وائپ';

  @override
  String get videoEditorTransitionButtonSemanticLabel =>
      'ٹرانزیشن میں ترمیم کریں';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'لوپ ٹرانزیشن';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'لوپ ٹرانزیشن میں ترمیم کریں';

  @override
  String get videoEditorTransitionDuration => 'دورانیہ';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'پڑوسی ٹرانزیشن سے ٹکرانے سے بچنے کے لیے چھوٹا کیا گیا۔';

  @override
  String get videoEditorTransitionCurve => 'منحنی';

  @override
  String get videoEditorTransitionDirection => 'سمت';

  @override
  String get videoEditorTransitionDirectionLeft => 'بائیں';

  @override
  String get videoEditorTransitionDirectionRight => 'دائیں';

  @override
  String get videoEditorTransitionDirectionUp => 'اوپر';

  @override
  String get videoEditorTransitionDirectionDown => 'نیچے';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'ایزنگ منحنی $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'اینیمیشن';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'لیئر اینیمیشن میں ترمیم کریں';

  @override
  String get videoEditorLayerAnimationEnter => 'آنا';

  @override
  String get videoEditorLayerAnimationLeave => 'جانا';

  @override
  String get videoEditorLayerAnimationFade => 'فیڈ';

  @override
  String get videoEditorLayerAnimationScale => 'اسکیل';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'اسکیل آغاز';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'ٹائم لائن ترمیم مکمل کریں';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'پیش منظر چلائیں';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'پیش منظر روکیں';

  @override
  String get videoEditorAudioUntitledSound => 'بلا عنوان آواز';

  @override
  String get videoEditorAudioUntitled => 'بلا عنوان';

  @override
  String get videoEditorAudioAddAudio => 'آڈیو شامل کریں';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'کوئی آواز دستیاب نہیں';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'جب کریئیٹرز آڈیو شیئر کریں گے تو آوازیں یہاں نظر آئیں گی';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'آوازیں لوڈ نہیں ہو سکیں';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'اپنی ویڈیو کے لیے آڈیو حصہ منتخب کریں';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'کمیونٹی';

  @override
  String get videoEditorAudioCategoryFeatured => 'نمایاں';

  @override
  String get videoEditorAudioCategoryMySounds => 'میری آوازیں';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'تیر ٹول';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'ایریزر ٹول';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'مارکر ٹول';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'پنسل ٹول';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'ٹائم لائن دکھائیں';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'ٹائم لائن چھپائیں';

  @override
  String get videoEditorFeedPreviewContent =>
      'ان علاقوں کے پیچھے مواد رکھنے سے گریز کریں۔';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine اوریجنلز';

  @override
  String get videoEditorStickerSearchHint => 'اسٹیکرز تلاش کریں...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'فانٹ منتخب کریں';

  @override
  String get videoEditorFontUnknown => 'نامعلوم';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'تقسیم کے لیے پلے ہیڈ منتخب کلپ کے اندر ہونا چاہیے۔';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'آغاز ترم کریں';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'اختتام ترم کریں';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'کلپ ترم کریں';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'کلپ کا دورانیہ ایڈجسٹ کرنے کے لیے ہینڈلز کھینچیں';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'کلپ $index کھینچی جا رہی ہے';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'کلپ $total میں سے $index، $duration سیکنڈ';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'ترتیب بدلنے کے لیے دیر تک دبائیں';

  @override
  String get videoEditorTimelineClipMoveLeft => 'بائیں منتقل کریں';

  @override
  String get videoEditorTimelineClipMoveRight => 'دائیں منتقل کریں';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'کلپ $total میں سے $index، منتخب';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'کلپ $total میں سے $index، منتخب نہیں';
  }

  @override
  String get videoEditorMultiSelectLabel => 'منتخب کریں';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'کئی کلپس منتخب کریں';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'کلپس کا انتخاب مکمل';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس منتخب',
      one: '1 کلپ منتخب',
      zero: 'کوئی کلپ منتخب نہیں',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'کئی ڈرائنگز منتخب کریں';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'ڈرائنگز کا انتخاب مکمل';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'منتخب ڈرائنگز حذف کریں';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ڈرائنگز منتخب',
      one: '1 ڈرائنگ منتخب',
      zero: 'کوئی ڈرائنگ منتخب نہیں',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'ملائیں';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel => 'منتخب کلپس ملائیں';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'منتخب کلپس حذف کریں';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'منتخب فریم حذف کریں';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'منتخب فریم الٹائیں';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'منتخب فریم کی نقل کریں';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'آپ کی ویڈیو کو کم از کم ${seconds}s چاہیے — کچھ اور فریم پکڑیں۔';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'ایک لمحہ، ہم آپ کی کلپس ملا رہے ہیں';

  @override
  String get videoEditorMergeFailed =>
      'کلپس نہیں ملائی جا سکیں۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'کھینچنے کے لیے دیر تک دبائیں';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'ویڈیو ٹائم لائن';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName، منتخب';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'رنگ چننے والا بند کریں';

  @override
  String get videoEditorPickColorTitle => 'رنگ منتخب کریں';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'رنگ کی تصدیق کریں';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => 'سیچوریشن اور چمک';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'سیچوریشن $saturation%، چمک $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'رنگت';

  @override
  String get videoEditorAddElementSemanticLabel => 'عنصر شامل کریں';

  @override
  String get videoEditorDoneSemanticLabel => 'ہو گیا';

  @override
  String get videoEditorLevelSemanticLabel => 'سطح';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'پوسٹ کی تفصیلات بند کریں';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'مدد کا ڈائیلاگ ہٹائیں';

  @override
  String get videoMetadataGotItButton => 'سمجھ گیا!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB کی حد پوری ہو گئی۔ جاری رکھنے کے لیے کچھ مواد ہٹائیں۔';

  @override
  String get videoMetadataExpirationLabel => 'میعاد';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'میعاد کا وقت منتخب کریں';

  @override
  String get videoMetadataTitleLabel => 'عنوان';

  @override
  String get videoMetadataDescriptionLabel => 'تفصیل';

  @override
  String get videoMetadataTagsLabel => 'ٹیگز';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'ٹیگ $tag حذف کریں';
  }

  @override
  String get videoMetadataContentWarningLabel => 'مواد انتباہ شامل کریں';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'مواد انتباہات منتخب کریں';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'جو لاگو ہو سب منتخب کریں';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'دوسروں کو اس ویڈیو کی آڈیو محفوظ اور دوبارہ استعمال کرنے دیں۔';

  @override
  String get publishAudioReuseDegradedWarning =>
      'آپ کی ویڈیو لگ گئی ہے، لیکن ساؤنڈ شائع نہیں ہوا۔ اسے شیئر کرنے کے لیے ویڈیو میں ترمیم کریں۔';

  @override
  String get videoMetadataCollaboratorsLabel => 'شریک کار شامل کریں';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'شریک کار کو دعوت دیں';

  @override
  String get videoMetadataMutualFollowersSearchText => 'باہمی فالوورز';

  @override
  String get videoMetadataInspiredByLabel => 'متاثر از شامل کریں';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'متاثر از مقرر کریں';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'اس کریئیٹر کا حوالہ نہیں دیا جا سکتا۔';

  @override
  String get videoMetadataPostDetailsTitle => 'پوسٹ تفصیلات';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'لائبریری میں محفوظ ہو گئی';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'محفوظ نہیں ہو سکی';

  @override
  String get videoMetadataGoToLibraryButton => 'لائبریری پر جائیں';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'بعد کے لیے محفوظ کریں بٹن';

  @override
  String get videoMetadataSavingVideoHint => 'ویڈیو محفوظ ہو رہی ہے...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'ویڈیو مسودوں اور $destination میں محفوظ کریں';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'ویڈیو کو مسودوں میں محفوظ کریں۔ ابھی کوئی رینڈر شدہ ویڈیو نہیں ہے، اس لیے $destination میں کاپی شامل نہیں ہوگی۔';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'بعد کے لیے محفوظ کریں';

  @override
  String get videoMetadataPostSemanticLabel => 'پوسٹ بٹن';

  @override
  String get videoMetadataPublishVideoHint => 'ویڈیو فیڈ پر شائع کریں';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'اپنے فیڈ پر بھی شیئر کریں';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'بند رکھنے سے یہ ویڈیو صرف تبصرہ تھریڈ میں رہے گی۔';

  @override
  String get videoMetadataFormNotReadyHint => 'فعال کرنے کے لیے فارم پورا کریں';

  @override
  String get videoMetadataPostButton => 'پوسٹ کریں';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'پوسٹ پیش منظر اسکرین کھولیں';

  @override
  String get videoMetadataShareTitle => 'شیئر';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'ویڈیو تفصیلات';

  @override
  String get videoMetadataClassicDoneButton => 'ہو گیا';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'پیش منظر چلائیں';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'پیش منظر روکیں';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'ویڈیو پیش منظر بند کریں';

  @override
  String get videoMetadataRemoveSemanticLabel => 'ہٹائیں';

  @override
  String get fullscreenFeedRemovedMessage => 'ویڈیو ہٹا دی گئی';

  @override
  String get fullscreenFeedEmptyMessage => 'یہاں چلانے کے لیے اب کچھ نہیں بچا';

  @override
  String get settingsBadgesTitle => 'بیجز';

  @override
  String get settingsBadgesSubtitle =>
      'ایوارڈز قبول کریں اور جاری شدہ بیج اسٹیٹس چیک کریں۔';

  @override
  String get badgesTitle => 'بیجز';

  @override
  String get badgesLoadError => 'بیجز لوڈ نہیں ہو سکے';

  @override
  String get badgesUpdateError => 'بیج اپڈیٹ نہیں ہو سکا';

  @override
  String get badgesAwardedEmptyTitle => 'ابھی کوئی بیج ایوارڈ نہیں';

  @override
  String get badgesAwardedEmptySubtitle =>
      'جب کوئی آپ کو Nostr بیج دے گا، وہ یہاں آئے گا۔';

  @override
  String get badgesStatusAccepted => 'قبول شدہ';

  @override
  String get badgesStatusNotAccepted => 'قبول نہیں شدہ';

  @override
  String get badgesActionRemove => 'ہٹائیں';

  @override
  String get badgesActionAccept => 'قبول کریں';

  @override
  String get badgesActionReject => 'انکار کریں';

  @override
  String get badgesIssuedEmptyTitle => 'ابھی کوئی جاری شدہ بیج نہیں';

  @override
  String get badgesIssuedEmptySubtitle =>
      'آپ کے جاری کردہ بیجز کی قبولیت کی صورتحال یہاں نظر آئے گی۔';

  @override
  String get badgesIssuedNoRecipients =>
      'اس ایوارڈ کے لیے کوئی وصول کنندہ نہیں ملا۔';

  @override
  String get badgesRecipientAcceptedStatus => 'وصول کنندہ نے قبول کیا';

  @override
  String get badgesRecipientWaitingStatus => 'وصول کنندہ کا انتظار ہے';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'پوشیدہ ($count)',
      one: 'پوشیدہ (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'بحال کریں';

  @override
  String get badgesHiddenSnackbar => 'بیج چھپا دیا گیا';

  @override
  String get badgesHiddenSnackbarUndo => 'واپس کریں';

  @override
  String get badgesTabAwarded => 'موصول';

  @override
  String get badgesTabCreated => 'بنائے گئے';

  @override
  String get badgesTabIssued => 'دیے گئے';

  @override
  String get badgesCreateAction => 'نیا بیج';

  @override
  String get badgesCreatedEmptyTitle => 'ابھی کوئی بیج نہیں بنایا';

  @override
  String get badgesCreatedEmptySubtitle => 'ایک بنائیں اور کسی حق دار کو دیں۔';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count افراد کو دیا',
      one: '1 شخص کو دیا',
      zero: 'ابھی کسی کو نہیں دیا',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'نیا بیج';

  @override
  String get badgeEditorEditTitle => 'بیج میں ترمیم';

  @override
  String get badgeEditorNameLabel => 'نام';

  @override
  String get badgeEditorNameHint => 'منظر چرانے والا';

  @override
  String get badgeEditorIdentifierLabel => 'شناخت کنندہ';

  @override
  String get badgeEditorIdentifierHelp =>
      'یہ بیج کے پتے کا حصہ ہے، اس لیے بیج بننے کے بعد یہ تبدیل نہیں ہوتا۔';

  @override
  String get badgeEditorIdentifierTaken =>
      'اس شناخت کنندہ کے ساتھ آپ کے پاس پہلے ہی ایک بیج ہے۔ اسی میں ترمیم کریں — یہاں شائع کرنے سے وہ بدل جائے گا۔';

  @override
  String get badgeEditorIdentifierRequired =>
      'ہر بیج کو ایک شناخت کنندہ چاہیے — اگر نام سے نہ بھرا ہو تو خود لکھیں۔';

  @override
  String get badgeEditorDescriptionLabel => 'تفصیل';

  @override
  String get badgeEditorDescriptionHint =>
      'اُس کے لیے جو ایک ہی لوپ سے سب کی توجہ چرا لے۔';

  @override
  String get badgeEditorArtworkLabel => 'تصویر';

  @override
  String get badgeEditorArtworkAdd => 'تصویر شامل کریں';

  @override
  String get badgeEditorArtworkReplace => 'بدلیں';

  @override
  String get badgeEditorArtworkError => 'یہ تصویر اپ لوڈ نہیں ہو سکی';

  @override
  String get badgeEditorArtworkRequired => 'ہر بیج کے لیے تصویر ضروری ہے۔';

  @override
  String get badgeEditorArtworkRemove => 'تصویر ہٹائیں';

  @override
  String get badgeEditorArtworkSheetTitle => 'بیج کی تصویر';

  @override
  String get badgeDetailDeleteAction => 'بیج حذف کریں';

  @override
  String get badgeDetailDeleteTitle => 'کیا یہ بیج حذف کر دیں؟';

  @override
  String get badgeDetailDeleteBody =>
      'یہ ریلے سے کہتا ہے کہ بیج اور آپ کے دیے گئے تمام ایوارڈ ہٹا دیں۔ ریلے انکار کر سکتے ہیں، اور جس نے اسے پروفائل پر لگایا ہے وہ خود ہٹانے تک رکھے گا۔';

  @override
  String get badgeDetailDeleteConfirm => 'حذف کریں';

  @override
  String get badgeEditorSaveAction => 'بیج شائع کریں';

  @override
  String get badgeEditorSaveError => 'بیج شائع نہیں ہو سکا';

  @override
  String get badgeEditorLoadError => 'یہ بیج لوڈ نہیں ہو سکا';

  @override
  String get badgeDetailTitle => 'بیج';

  @override
  String get badgeDetailMadeBy => 'بنانے والا';

  @override
  String get badgeDetailRecipientsTitle => 'دیا گیا';

  @override
  String get badgeDetailNoRecipients => 'ابھی کسی کے پاس نہیں ہے۔';

  @override
  String get badgeDetailAwardAction => 'یہ بیج دیں';

  @override
  String get badgeDetailEditAction => 'بیج میں ترمیم';

  @override
  String get badgeDetailShareAction => 'شیئر کریں';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Divine پر یہ بیج دیکھیں: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'بیج واپس لیں';

  @override
  String get badgeDetailRevokeTitle => 'یہ بیج واپس لیں؟';

  @override
  String get badgeDetailRevokeBody =>
      'یہ ریلے سے کہتا ہے کہ اس شخص کو دیا گیا ایوارڈ ہٹا دیں۔ ریلے انکار کر سکتے ہیں، اور اگر بیج پہلے ہی پروفائل پر لگا ہے تو وہ خود ہٹانے تک وہیں رہے گا۔ دونوں صورتوں میں انہیں اطلاع نہیں دی جاتی۔';

  @override
  String get badgeDetailRevokeSelfBody =>
      'یہ ریلے سے کہتا ہے کہ آپ نے خود کو دیا گیا ایوارڈ ہٹا دیں، اور بیج کو آپ کے پروفائل سے اتار دیتا ہے۔ اگر ریلے حذف کرنے سے انکار کر دیں تو کچھ نہیں بدلتا۔';

  @override
  String get badgeDetailRevokeConfirm => 'واپس لیں';

  @override
  String get badgeDetailRevokeSuccess => 'بیج واپس لے لیا گیا';

  @override
  String get badgeDetailBlockClaimantsAction => 'بیج رکھنے والوں کو بلاک کریں';

  @override
  String get badgeDetailBlockClaimantsTitle => 'بیج رکھنے والوں کو بلاک کریں';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'اس بیج کو رکھنے والوں کو لوڈ نہیں کیا جا سکا';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'ابھی کوئی یہ بیج نہیں رکھتا';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'ہمیں فی الحال بلاک کرنے کے لیے کوئی نہیں ملا۔';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اکاؤنٹس بلاک کریں؟',
      one: '1 اکاؤنٹ بلاک کریں؟',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'اس سے وہ $count اکاؤنٹس بلاک ہو جائیں گے جو ابھی یہ بیج رکھتے ہیں۔ ان کی پوسٹیں آپ کے فیڈز میں نظر نہیں آئیں گی اور انہیں اطلاع نہیں دی جائے گی۔',
      one:
          'اس سے وہ اکاؤنٹ بلاک ہو جائے گا جو ابھی یہ بیج رکھتا ہے۔ ان کی پوسٹیں آپ کے فیڈز میں نظر نہیں آئیں گی اور انہیں اطلاع نہیں دی جائے گی۔',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اکاؤنٹس بلاک کریں',
      one: '1 اکاؤنٹ بلاک کریں',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'بیج رکھنے والے بلاک کر دیے گئے';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'بیج رکھنے والوں کو بلاک نہیں کیا جا سکا';

  @override
  String get badgeDetailLoadError => 'یہ بیج لوڈ نہیں ہو سکا';

  @override
  String get badgeDetailMissing => 'ہمیں یہ بیج کسی ریلے پر نہیں ملا۔';

  @override
  String get badgeDetailActionError => 'یہ کام نہیں ہو سکا';

  @override
  String get badgeAwardTitle => 'بیج دیں';

  @override
  String get badgeAwardPickAction => 'لوگ منتخب کریں';

  @override
  String get badgeAwardManualLabel => 'یا کلیدیں پیسٹ کریں';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'کم از کم ایک شخص منتخب کریں۔';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count افراد کو دیں',
      one: '1 شخص کو دیں',
      zero: 'بیج دیں',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'دینے والا';

  @override
  String get profileBadgeRecipients => 'وصول کنندگان';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count مزید';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name بیج';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'بیج';

  @override
  String get profileBadgeFooterBody =>
      'بیجز چھوٹے انعامات ہیں جو کوئی بھی Nostr پر بنا سکتا ہے۔ کسی دوست، تخلیق کار، یا اس شخص کو دیں جس نے آپ کا دن بنا دیا۔';

  @override
  String get profileBadgeFooterLink => 'اپنا بیج بنائیں';

  @override
  String get minorAccountReviewWelcomePageTitle => 'خاندانی رہنما';

  @override
  String get minorAccountReviewWelcomeTitle =>
      'ابھی 16 کے نہیں؟ کوئی بات نہیں۔';

  @override
  String get minorAccountReviewWelcomeBody =>
      'اگر آپ نے صرف وہ جواب منتخب کرنے کے بجائے اس صفحے پر آنے کا فیصلہ کیا جو آپ کو اندر لے آتا، تو یہ اہم ہے۔ یہ ایمانداری، ہمت اور اپنے اردگرد کے لوگوں کی حقیقی فکر دکھاتا ہے۔\n\n16 سال سے کم لوگوں کے قواعد ہر جگہ مختلف ہوتے ہیں۔ Divine پر ہم چاہتے ہیں کہ خاندان مل کر بات کریں اور فیصلہ کریں کہ سوشل میڈیا کا صحت مند استعمال کیسا دکھتا ہے۔';

  @override
  String get minorAccountReviewModerationTitle => 'ہمیں ایک اور قدم درکار ہے';

  @override
  String get minorAccountReviewModerationBody =>
      'ہمیں اس اکاؤنٹ کا قریب سے جائزہ لینے کو کہا گیا کیونکہ ممکن ہے یہ کسی 16 سال سے کم شخص کا ہو۔ یہ عمل اگلے قدموں کو نجی رکھتا ہے اور آپ کو آپ کی عمر کے مطابق صحیح راستہ دکھاتا ہے۔';

  @override
  String get minorAccountReviewRulesTitle => 'قواعد ہر جگہ ایک جیسے نہیں ہیں';

  @override
  String get minorAccountReviewRulesBody =>
      'مختلف ممالک اور علاقے نوجوانوں کے سوشل میڈیا استعمال سے مختلف طریقے سے نمٹتے ہیں۔ اسی لیے ہم خاندانوں سے کہتے ہیں کہ آہستہ چلیں، حقائق چیک کریں، اور اگلا قدم مل کر منتخب کریں۔';

  @override
  String get minorAccountReviewApproachTitle =>
      'Divine اس بارے میں کیا سوچتا ہے';

  @override
  String get minorAccountReviewApproachBody =>
      'ہمارے خیال میں صحت مند ٹیک عادات رک کر سوچنے اور توجہ کو بہتر چیزوں کی طرف موڑنے سے آتی ہیں، بچوں پر جاسوسی کرنے یا والدین کو نگران بنا دینے سے نہیں۔ تحقیق بھی اسی کی تائید کرتی ہے۔';

  @override
  String get minorAccountReviewLearnMoreTitle => 'خاندانوں کے لیے مزید';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Divine کی بچوں کی پالیسی پڑھیں';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'وہ راستہ منتخب کریں جو مناسب ہو';

  @override
  String get minorAccountReviewUnder13Cta => '13 سال سے کم';

  @override
  String get minorAccountReviewTeenCta => 'عمر 13-15';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'عملی مشوروں، بات چیت کے ٹولز اور نوجوانوں کے محفوظ سوشل میڈیا استعمال میں مدد کے وسائل کے لیے Divine خاندانی رہنما دیکھیں۔';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'خاندانی رہنما اور مشورے حاصل کریں';

  @override
  String get minorAccountReviewFooter =>
      'اگر آپ 16 سال یا زیادہ کے ہیں اور غلطی سے یہاں بھیج دیے گئے ہیں، تو Divine سپورٹ سے رابطہ کریں تاکہ کوئی حقیقی شخص جائزہ لے سکے۔';

  @override
  String get minorAccountReviewTitle => 'اکاؤنٹ جائزہ';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'اکاؤنٹ اسٹیٹس چیک ہو رہا ہے...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'براہ کرم انتظار کریں، ہم اس اکاؤنٹ کی موجودہ جائزہ صورتحال کی تصدیق کر رہے ہیں۔';

  @override
  String get minorAccountReviewDefaultTitle => 'اکاؤنٹ جائزہ درکار ہے';

  @override
  String get minorAccountReviewDefaultBody =>
      'اس اکاؤنٹ کے عام طور پر Divine استعمال کرنے سے پہلے ہمیں اس کا جائزہ لینا ہوگا۔';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'کیس ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'کیس ID';

  @override
  String get minorAccountReviewRestrictionsTitle => 'ابھی کیا محدود ہے';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'پوسٹنگ اور اشاعت روکی گئی ہے';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'تبصرے، پسند، ریپوسٹ اور فالو روکے گئے ہیں';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'عام پیغامات شروع کرنے یا ان کا جواب دینے پر روک ہے';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'سپورٹ اور آپ کا موڈریشن پیغام دستیاب رہتے ہیں';

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
  String get minorAccountReviewOpenSupportCenter => 'مدد کا مرکز کھولیں';

  @override
  String get minorAccountReviewOpenModerationMessage => 'موڈریشن پیغام کھولیں';

  @override
  String get minorAccountReviewOpenReviewPage => 'جائزہ صفحہ کھولیں';

  @override
  String get minorAccountReviewCheckAgain => 'دوبارہ چیک کریں';

  @override
  String get minorAccountReviewLogOut => 'لاگ آؤٹ';

  @override
  String get minorAccountReviewNextStepTitle => 'اگلا قدم';

  @override
  String get minorAccountReviewNextStepBody =>
      'اگر اس جائزے میں مدد چاہیے تو مدد کا مرکز یا اپنا موڈریشن پیغام کھولیں۔';

  @override
  String get minorAccountReviewInProgressTitle => 'جائزہ جاری ہے';

  @override
  String get minorAccountReviewInProgressBody =>
      'فی الحال ہمارے پاس درکار سب کچھ ہے۔ عام اکاؤنٹ رسائی بحال کرنے سے پہلے ہماری ٹیم اس کیس کا جائزہ لے رہی ہے۔';

  @override
  String get minorAccountReviewUnder13Title => '13 سال سے کم کے اکاؤنٹس';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'اگر یہ اکاؤنٹ کسی 13 سال سے کم شخص کا ہے، تو والدین یا سرپرست کو $supportEmail پر ای میل کرنی ہوگی اور کیس ID شامل کرنی ہوگی۔';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'ہم ابھی آپ کو اکاؤنٹ نہیں دے سکتے';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine 13 سال سے کم بچوں کے لیے نہیں بنا، اور دنیا بھر کے سوشل میڈیا قواعد ہمارے ہاتھ باندھ دیتے ہیں۔\n\nانٹرنیٹ پر بہت سی چیزیں آپ کو اپنی مرضی کی چیز پانے کے لیے جھوٹ بولنے پر ابھارتی ہیں، اور ہمیں یہ ناپسند ہے۔ یہ زندگی کے لیے غلط سبق ہے، اور ہم یہاں آپ کو یہ سبق نہیں سکھائیں گے۔';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'آپ کا خاندان اس کے بجائے کیا کر سکتا ہے';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'والدین یا سرپرست اکاؤنٹ سنبھال سکتے ہیں اور پوسٹنگ کر سکتے ہیں، اور آپ بالکل ان کے ساتھ ویڈیوز میں ہو سکتے ہیں۔ ہم چاہتے ہیں کہ خاندان Divine سے جس طرح ان کے لیے ٹھیک ہو لطف انداز ہوں۔';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'جب آپ 13 کے ہوں';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'آپ کے رہنے کی جگہ کے قواعد کے مطابق، ممکن ہے آپ واپس آ کر اپنے اکاؤنٹ کے لیے درخواست دے سکیں۔ اس صورت میں، اگر آپ کی عمر 13 سے 15 کے درمیان ہے، تو آپ کو والدین یا سرپرست کی اجازت درکار ہوگی۔';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'ہم آپ سے صرف \'واپس جائیں\' کیوں نہیں کہتے';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'انٹرنیٹ کا ایک بڑا حصہ ایسے بنا ہے جو لوگوں کو دروازہ پار کرنے کے لیے کچھ بھی کہہ دینے پر انعام دیتا ہے۔ ہم نہیں سمجھتے کہ یہ ٹھیک ہے۔ ہاں، آپ واپس جا کر کہہ سکتے ہیں کہ آپ اپنی عمر سے بڑے ہیں، لیکن یہ ایمانداری نہیں ہوگی، اور ہم آپ کو اپنی مرضی کی چیز پانے کے لیے جھوٹ بولنا نہیں سکھائیں گے۔';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'ہم نوجوانوں کی مدد کرنا چاہتے ہیں کہ وہ Divine ایسے طریقوں سے استعمال کریں جو ان کے لیے اور ان کے اردگرد کے لوگوں کے لیے صحت مند اور مثبت ہوں۔ ہمیں ان قوانین کی بھی پابندی کرنی ہے جو مختلف جگہوں پر مختلف ہیں۔ تو اگر آپ 13 سال سے کم ہیں، تو جواب یہ ہے کہ آج آپ اپنا اکاؤنٹ نہیں بنا سکتے۔';

  @override
  String get minorAccountReviewTeenBody =>
      'اگر یہ اکاؤنٹ کسی 13 تا 15 سال کے شخص کا ہے، تو والدین کی رضامندی کی ہدایات کے لیے موڈریشن پیغام یا سپورٹ کا راستہ استعمال کریں۔';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'اگر اکاؤنٹ کسی 13 تا 15 سال کے شخص کا ہوگا';

  @override
  String get minorAccountReviewParentConsentBody =>
      'والدین یا سرپرست کو ایک چھوٹی نجی ویڈیو کے ساتھ Divine سپورٹ کو ای میل کرنی چاہیے۔ ہماری ٹیم اس کا جائزہ لے گی اور اگلے قدموں میں مدد کرے گی۔\n\nاگر والدین یا سرپرست سے رابطہ ممکن نہیں یا کسی کو خطرے میں ڈال سکتا ہے، تو Divine سپورٹ کو ای میل کر کے ہمیں بتائیں۔';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'یہ ایک وقفہ ہے جب تک Divine سپورٹ ٹیم ویڈیو کا جائزہ لیتی ہے۔ اگر منظور ہو گئی، تو وہ آپ کو نیا اکاؤنٹ سیٹ اپ کرنے میں رہنمائی کرے گی۔';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'ہم والدین یا سرپرست کو شامل کیوں کرتے ہیں';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine کو دنیا بھر کے عمر سے متعلق قوانین کی پابندی کرنی ہے۔ ہم یہ بھی جانتے ہیں کہ زیادہ تر تکنیکی عمر کی رکاوٹیں نامکمل ہیں۔ قواعد کے نہ ہونے کا بہانہ کرنے یا عمر چھپانے کو \'ٹھیک\' سمجھنے کے بجائے، ہم چاہتے ہیں کہ نوجوان اور خاندان Divine کے بہترین استعمال کے بارے میں سوچ سمجھ کر فیصلے کریں۔ اسی لیے 13-15 سال کے بچوں کے لیے ہم چاہتے ہیں کہ والدین اکاؤنٹ بنانے کے عمل کا حصہ ہوں۔';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'ہمیں قانون کی بھی پابندی کرنی ہے، اور وہ قواعد جگہ کے حساب سے مختلف ہوتے ہیں۔ اس لیے قواعد کے نہ ہونے کا بہانہ کرنے کے بجائے، ہم والدین یا سرپرست کو عمل کا حصہ بننے کو کہتے ہیں۔';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'ویڈیو میں کیا ہونا چاہیے';

  @override
  String get minorAccountReviewParentConsentChecklistKid => 'ویڈیو میں نوجوان';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'کوئی والد یا سرپرست کیمرے پر بولتا ہوا';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'واضح بیان کہ نوجوان 13 تا 15 سال کا ہے اور اسے Divine استعمال کرنے کی اجازت ہے';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'واضح بیان کہ والد یا سرپرست کو اکاؤنٹ کا علم ہے اور وہ اس کے استعمال کی نگرانی کرے گا';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'اسے کیسے بھیجیں';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Divine سپورٹ کو ای میل کرتے وقت ویڈیو منسلک کریں';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'ویڈیو کو نجی رکھیں اور اسے ایپ میں پوسٹ نہ کریں';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'ہماری ٹیم اس کا جائزہ لے گی اور اگلے قدموں کے ساتھ جواب دے گی';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Divine سپورٹ کو ای میل کریں';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine Greenlight جائزہ مدد (عمر 13-15)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Divine سپورٹ، السلام علیکم،\n\nمیں 13-15 سال کے نوجوان کے لیے Divine Greenlight کے بارے میں Divine سے رابطہ کر رہا/رہی ہوں۔\n\nمیں نے ایک چھوٹی نجی ویڈیو منسلک کی ہے جس میں ہے:\n- نوجوان\n- کوئی والد یا سرپرست کیمرے پر بولتا ہوا\n- کہ نوجوان کو Divine استعمال کرنے کی اجازت ہے\n- کہ والد یا سرپرست کو اکاؤنٹ کا علم ہے اور وہ اس کے استعمال کی نگرانی کرے گا\n\nرہائشی ملک:\n\nمفید پس منظر:\n\nشکریہ۔';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'والدین کی سپورٹ ہدایات';

  @override
  String get minorAccountReviewContinue => 'جاری رکھیں';

  @override
  String get minorAccountReviewErrorTitle =>
      'ہم آپ کے اکاؤنٹ جائزہ کی صورتحال لوڈ نہیں کر سکے۔';

  @override
  String get minorAccountReviewErrorBody =>
      'براہ کرم تھوڑی دیر میں دوبارہ کوشش کریں۔';

  @override
  String get minorAccountReviewTryAgain => 'دوبارہ کوشش کریں';

  @override
  String get minorAccountReviewParentContactTitle => 'والدین کا رابطہ';

  @override
  String get minorAccountReviewParentContactHeading =>
      'والد یا سرپرست کی ای میل شامل کریں';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'ہم اس ایڈریس کو کیس $caseId کے والدین رضامندی جائزے کے لیے استعمال کریں گے۔';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'والد یا سرپرست کی ای میل';

  @override
  String get minorAccountReviewSubmitting => 'جمع ہو رہا ہے...';

  @override
  String get minorAccountReviewSubmitEmail => 'ای میل جمع کریں';

  @override
  String get minorAccountReviewBackToReview => 'اکاؤنٹ جائزہ پر واپس';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'ای میل جمع ہو گئی';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'ہم نے جائزے کے لیے $email جمع کر دیا ہے۔ تصدیق کے لیے ہم اس ایڈریس پر ای میل کریں گے۔ جب آپ کے والد یا سرپرست جواب دیں گے، آپ کا کیس آگے بڑھے گا۔ اپڈیٹس کے لیے اکاؤنٹ جائزہ اسکرین سے دوبارہ چیک کریں استعمال کریں۔';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'ہمیں اس اکاؤنٹ کے لیے والد یا سرپرست کا رابطہ مل گیا ہے۔ رسائی بحال کرنے سے پہلے ہماری ٹیم اس کا جائزہ لے گی۔';

  @override
  String get minorAccountReviewMissingCase =>
      'ہمیں اس اکاؤنٹ کے لیے کوئی فعال جائزہ کیس نہیں ملا۔';

  @override
  String get minorAccountReviewParentContactError =>
      'والدین کی ای میل جمع نہیں ہو سکی۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'والدین کی سپورٹ';

  @override
  String get minorAccountReviewUnder13Heading =>
      'کسی والد یا سرپرست کو Divine سے رابطہ کرنا ہوگا';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      '13 سال سے کم ہونے کے امکان والے اکاؤنٹس کے لیے، اگلا قدم والدین یا سرپرست کا ای میل سے رابطہ ہے۔';

  @override
  String get minorAccountReviewSupportEmailLabel => 'سپورٹ ای میل';

  @override
  String get minorAccountReviewCopySupportEmail => 'سپورٹ ای میل کاپی کریں';

  @override
  String get minorAccountReviewSupportEmailCopied => 'سپورٹ ای میل کاپی ہو گئی';

  @override
  String get minorAccountReviewCopyCaseId => 'کیس ID کاپی کریں';

  @override
  String get minorAccountReviewCaseIdCopied => 'کیس ID کاپی ہو گئی';

  @override
  String get minorAccountReviewUnavailable => 'دستیاب نہیں';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'والدین یا سرپرست سے کہیں کہ وہ کیس ID شامل کریں اور بتائیں کہ وہ اس اکاؤنٹ جائزے کے بارے میں Divine سے رابطہ کر رہے ہیں۔';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'کیس $caseId کے لیے 13 سال سے کم اکاؤنٹ جائزہ';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Divine سپورٹ، السلام علیکم،\n\nمیں 13 سال سے کم بچے کا والد یا سرپرست ہوں اور میں اکاؤنٹ جائزہ کیس $caseId کے بارے میں Divine سے رابطہ کر رہا/رہی ہوں۔\n\nشکریہ۔';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'نابالغ اکاؤنٹ جائزہ سیمولیشن';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'موجودہ حالت';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'محدود ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'فعال';

  @override
  String get devOptionsMinorReviewStateLoading => 'لوڈ ہو رہا ہے...';

  @override
  String get devOptionsMinorReviewStateError => 'حالت لوڈ کرنے میں خرابی';

  @override
  String get devOptionsMinorReviewClearTitle => 'سیمولیشن اووررائیڈ صاف کریں';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'دوبارہ بیک اینڈ یا ڈیفالٹ فعال حالت استعمال کریں';

  @override
  String get devOptionsMinorReviewTeenTitle => '13-15 جائزہ کیس سیمولیٹ کریں';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'والدین رابطہ راستے والا محدود اکاؤنٹ';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      '13 سال سے کم سپورٹ کیس سیمولیٹ کریں';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'صرف والدین ای میل ہدایات والا محدود اکاؤنٹ';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'نابالغ اکاؤنٹ جائزہ سیمولیشن صاف ہو گئی';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'سیمولیٹ شدہ 13 سال سے کم سپورٹ کیس فعال';

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
  String get devOptionsProtectedMinorSimulationTitle => 'محفوظ نابالغ سیمولیشن';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'موجودہ حالت';

  @override
  String get devOptionsProtectedMinorStateProtected => 'محفوظ نابالغ (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'محفوظ نہیں';

  @override
  String get devOptionsProtectedMinorStateLoading => 'لوڈ ہو رہا ہے…';

  @override
  String get devOptionsProtectedMinorStateError => 'حالت پڑھنے میں خرابی';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'کوئی اووررائیڈ نہیں (اصل اکاؤنٹ حالت)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'اووررائیڈ: زبردستی محفوظ';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'اووررائیڈ: زبردستی غیر محفوظ';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'محفوظ نابالغ سیمولیٹ کریں (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      '#175/#176 تحفظات کی QA کے لیے محفوظ نابالغ حالت پر مجبور کریں';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'غیر نابالغ سیمولیٹ کریں';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'غیر محفوظ پر مجبور کریں (واضح منفی، بلا اووررائیڈ سے مختلف)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'اووررائیڈ صاف کریں';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'اصل Keycast چلنے والی اکاؤنٹ حالت پر واپس جائیں';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'محفوظ نابالغ حالت زبردستی فعال';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'محفوظ نابالغ حالت زبردستی بند';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'محفوظ نابالغ اووررائیڈ صاف ہو گیا';

  @override
  String get devOptionsInviteAvailabilityTitle => 'سائن اپ دعوت نامے';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'موجودہ حالت';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'سرور ویلیو: لوڈ ہو رہی ہے';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => 'سرور ویلیو: فعال';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'سرور ویلیو: غیر فعال';

  @override
  String get devOptionsInviteAvailabilityServerUnknown => 'سرور ویلیو: نامعلوم';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'اوور رائیڈ: سرور ویلیو استعمال کریں';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'اوور رائیڈ: زبردستی فعال';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'اوور رائیڈ: زبردستی غیر فعال';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'سرور ویلیو استعمال کریں';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'دعوت سروس کے onboardingMode کی پیروی کریں';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'زبردستی فعال کریں';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'سائن اپ دعوت گیٹس اور انتظام مقامی طور پر دکھائیں';

  @override
  String get devOptionsInviteAvailabilityForceDisabled =>
      'زبردستی غیر فعال کریں';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'سرور کو تبدیل کیے بغیر سائن اپ دعوت UI مقامی طور پر چھپائیں';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'سائن اپ دعوت نامے اب سرور کی پیروی کرتے ہیں';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'سائن اپ دعوت نامے زبردستی فعال';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'سائن اپ دعوت نامے زبردستی غیر فعال';

  @override
  String get commentsRecordVideoButtonLabel => 'ویڈیو تبصرہ ریکارڈ کریں';

  @override
  String get commentsOpenVideoLabel => 'ویڈیو تبصرہ کھولیں';

  @override
  String get commentsMuteVideoReplyLabel => 'ویڈیو جواب میوٹ کریں';

  @override
  String get commentsUnmuteVideoReplyLabel => 'ویڈیو جواب ان میوٹ کریں';

  @override
  String get commentsOpenReplyParentLabel => 'وہ ویڈیو کھولیں جس کا یہ جواب ہے';

  @override
  String get commentsReplyParentSectionTitle => 'کے جواب میں';

  @override
  String commentsReplyParentLabel(String target) {
    return '$target کا جواب';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'ویڈیو کا جواب';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'تصدیق شدہ $platform اکاؤنٹ: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'تصدیق شدہ اکاؤنٹس';

  @override
  String get profileEditGetVerifiedCta => 'تصدیق حاصل کریں';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'اپنے سوشل میڈیا اکاؤنٹس جوڑیں تاکہ لوگ جانیں کہ یہ واقعی آپ ہیں۔';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'ویب سائٹ دیکھیں: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'ویب سائٹ نہیں کھل سکی';

  @override
  String get videoMetadataEditCoverTitle => 'کور میں ترمیم کریں';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'کور کی تبدیلیاں مسترد کریں';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'منتخب فریم کو ویڈیو کور کے طور پر استعمال کریں';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'کور فریم منتخب کرنے کے لیے ویڈیو میں آگے پیچھے جائیں';

  @override
  String get videoMetadataTagsPickerSearchHint => 'ٹیگز تلاش یا شامل کریں';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'لوگوں کی آپ کی ویڈیو دریافت کرنے میں مدد کے لیے ٹیگز شامل کریں';

  @override
  String get videoMetadataTagsPickerNoResults => 'کوئی میلتا ٹیگ نہیں';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '\"#$tag\" شامل کریں';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'ابھی 16 کے نہیں؟ کوئی بات نہیں۔ ';

  @override
  String get authUnder16ChoicesCta => 'یہ ہیں آپ کے اختیارات۔';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'یہ ہے وجہ';

  @override
  String get generalSettingsHoldToRecord => 'دبا کر ریکارڈ کریں';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'دبا کر رکھنے پر ریکارڈنگ شروع ہو، چھوڑنے پر رک جائے';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ویڈیوز آپ کے پروفائل پر شائع ہو گئیں',
      one: 'ویڈیو آپ کے پروفائل پر شائع ہو گئی',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'پیغام بھیجیں';

  @override
  String get emojiPickerSearchHint => 'تلاش';

  @override
  String get emojiCategoryRecent => 'حالیہ';

  @override
  String get emojiCategorySmileys => 'اسمائیلی اور لوگ';

  @override
  String get emojiCategoryAnimals => 'جانور اور قدرت';

  @override
  String get emojiCategoryFood => 'کھانا اور مشروبات';

  @override
  String get emojiCategoryActivities => 'سرگرمیاں';

  @override
  String get emojiCategoryTravel => 'سفر اور مقامات';

  @override
  String get emojiCategoryObjects => 'اشیاء';

  @override
  String get emojiCategorySymbols => 'علامتیں';

  @override
  String get emojiCategoryFlags => 'جھنڈے';

  @override
  String get videoEditorMarkerLabel => 'مارکر';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'ٹائم لائن مارکر شامل کریں';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'ٹائم لائن مارکر ہٹائیں';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'پلے ہیڈ پر مارکر ہٹائیں';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'مارکر حذف کریں؟';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'یہ مارکر ٹائم لائن سے ہٹا دے گا۔ آپ کی ترمیم محفوظ رہے گی۔';

  @override
  String get videoEditorVolumeLongPressHint =>
      'تمام ٹریکس میوٹ یا ان میوٹ کریں';

  @override
  String get videoEditorSplitFailed =>
      'تقسیم ناکام۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get videoEditEditSubtitles => 'سب ٹائٹلز میں ترمیم کریں';

  @override
  String get subtitleEditorTitle => 'سب ٹائٹلز میں ترمیم کریں';

  @override
  String get subtitleEditorSave => 'محفوظ کریں';

  @override
  String get subtitleEditorProcessing =>
      'سب ٹائٹلز ابھی بن رہے ہیں۔ تھوڑی دیر میں دیکھیں۔';

  @override
  String get subtitleEditorNoSpeech =>
      'اس ویڈیو میں کوئی گفتگو نہیں ملی، اس لیے سب ٹائٹل بنانے کے لیے کچھ نہیں ہے۔';

  @override
  String get subtitleEditorWriteOwn => 'خود لکھیں';

  @override
  String get subtitleEditorAddCue => 'ایک لائن شامل کریں';

  @override
  String get subtitleEditorRemoveCue => 'یہ لائن ہٹائیں';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'ویڈیو ابھی نہیں چل سکتی، لیکن آپ پھر بھی کیپشنز درست کر سکتے ہیں۔';

  @override
  String get subtitleEditorPlayPreview => 'ویڈیو چلائیں';

  @override
  String get subtitleEditorPausePreview => 'ویڈیو روکیں';

  @override
  String get subtitleEditorInvalidHint =>
      'ہر لائن میں متن اور شروع کے بعد اختتام ہونا چاہیے۔';

  @override
  String get subtitleEditorLoadError =>
      'سب ٹائٹلز لوڈ نہیں ہو سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get subtitleEditorSaveSuccess => 'سب ٹائٹلز اپڈیٹ ہو گئے';

  @override
  String get subtitleEditorSaveError =>
      'سب ٹائٹلز محفوظ نہیں ہو سکے۔ دوبارہ کوشش کریں۔';

  @override
  String get subtitleEditorRetry => 'دوبارہ کوشش کریں';

  @override
  String get subtitleEditorCueHint => 'کیپشن متن';

  @override
  String get imageCropEditorRotateLabel => 'گھمائیں';

  @override
  String get imageCropEditorFlipLabel => 'پلٹیں';

  @override
  String get imageCropEditorResetLabel => 'ری سیٹ';

  @override
  String get imageCropEditorCloseSemanticLabel => 'کراپنگ منسوخ کریں';

  @override
  String get imageCropEditorDoneSemanticLabel => 'کراپ لاگو کریں';

  @override
  String get imageCropEditorProcessing => 'کراپ لاگو ہو رہا ہے…';

  @override
  String get backgroundUploadNotificationTitle => 'ویڈیو اپلوڈ ہو رہی ہے';

  @override
  String get monetizationSettingsTitle => 'کریئیٹر سپورٹ';

  @override
  String get monetizationSettingsSubtitle => 'ٹپ اور سبسکرپشن لنکس شامل کریں';

  @override
  String get monetizationSettingsIntroTitle => 'صرف بیرونی لنکس';

  @override
  String get monetizationSettingsIntroBody =>
      'کریئیٹر کنٹرولڈ منزلیں شامل کریں۔ Divine کبھی بھی ان لنکس سے پیمنٹ نہیں سنبھالتا یا ان ایپ مواد نہیں کھولتا۔';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    return 'آپ کے پروفائل پر $count فعال لنکس';
  }

  @override
  String get monetizationSettingsTipSection => 'ٹپ بھیجیں';

  @override
  String get monetizationSettingsSubscriptionSection => 'سبسکرائب / سپورٹ';

  @override
  String get monetizationSettingsSave => 'سپورٹ لنکس محفوظ کریں';

  @override
  String get monetizationSettingsSaving => 'محفوظ ہو رہے ہیں...';

  @override
  String get monetizationSettingsSaved => 'سپورٹ لنکس اپڈیٹ ہو گئے';

  @override
  String get monetizationSettingsSaveFailed =>
      'سپورٹ لنکس محفوظ نہیں ہو سکے۔ اپنا کنکشن چیک کر کے دوبارہ کوشش کریں۔';

  @override
  String get monetizationSettingsErrorEmpty => 'ہینڈل یا URL شامل کریں۔';

  @override
  String get monetizationSettingsErrorInvalid => 'یہ لنک ٹھیک نہیں لگتا۔';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'اسی فراہم کنندہ کا لنک استعمال کریں۔';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag یا cash.app لنک';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me ہینڈل یا لنک';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo ہینڈل یا لنک';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon ہینڈل یا لنک';

  @override
  String get monetizationSettingsHintSubstack => 'Substack ڈومین یا لنک';

  @override
  String get monetizationSettingsHintMedium => 'Medium ہینڈل یا لنک';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective سلگ یا لنک';

  @override
  String get profileSupportSheetTitle => 'اس کریئیٹر کی سپورٹ کریں';

  @override
  String get profileSupportSheetBody =>
      'یہ لنکس Divine سے باہر کھلتے ہیں۔ یہاں کچھ بھی ایپ میں مواد نہیں کھولتا۔';

  @override
  String get profileSupportTipSection => 'ٹپ بھیجیں';

  @override
  String get profileSupportSubscriptionSection => 'سبسکرائب / سپورٹ';

  @override
  String get profileSupportButtonLabel => 'سپورٹ';

  @override
  String get monetizationTipsSettingsTitle => 'ٹپس';

  @override
  String get monetizationTipsSettingsSubtitle => 'اختیاری ٹپ لنکس شامل کریں';

  @override
  String get monetizationTipsSettingsIntroTitle => 'صرف اختیاری ٹپس';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'ٹپس صارف سے صارف کے اختیاری تحفے ہیں۔ یہ Divine میں مواد، سبسکرپشنز، فیچرز، رینکنگ، نمائش یا رسائی نہیں کھولتی ہیں۔';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    return 'آپ کے پروفائل پر $count فعال ٹپ لنکس';
  }

  @override
  String get monetizationTipsSettingsSave => 'ٹپ لنکس محفوظ کریں';

  @override
  String get monetizationTipsSettingsSaved => 'ٹپ لنکس اپڈیٹ ہو گئے';

  @override
  String get profileTipButtonLabel => 'ٹپ';

  @override
  String get profileTipSheetTitle => 'اس کریئیٹر کو ٹپ دیں';

  @override
  String get profileTipSheetBody =>
      'ٹپس Divine سے باہر کھلتی ہیں۔ یہ اختیاری ہیں اور Divine میں مواد، سبسکرپشنز، فیچرز یا رسائی نہیں کھولتی ہیں۔';

  @override
  String get settingsStorageTitle => 'اسٹوریج';

  @override
  String get settingsStorageCacheSectionTitle => 'کیش شدہ میڈیا';

  @override
  String get settingsStorageCacheDescription =>
      'کیش شدہ فیڈ ویڈیوز، تھمب نیلز اور عارضی رینڈرز۔ انہیں صاف کرنا محفوظ ہے — ضرورت پڑنے پر یہ دوبارہ ڈاؤن لوڈ یا بن جائیں گے۔';

  @override
  String get settingsStorageMeasuring => 'ناپا جا رہا ہے…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size استعمال میں';
  }

  @override
  String get settingsStorageClearButton => 'کیش صاف کریں';

  @override
  String get settingsStorageClearConfirmTitle => 'کیش شدہ میڈیا صاف کریں؟';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'اس سے $size جگہ خالی ہوگی۔ آپ کی کلپ لائبریری متاثر نہیں ہوگی۔';
  }

  @override
  String get settingsStorageClearConfirmAction => 'صاف کریں';

  @override
  String get settingsStorageCleared => 'کیش صاف ہو گئی';

  @override
  String get settingsStorageLibrarySectionTitle => 'کلپ لائبریری';

  @override
  String get settingsStorageLibraryDescription =>
      'ٹوٹی ہوئی کلپس چیک کریں جن کی ویڈیو فائل غائب ہے۔';

  @override
  String get settingsStorageScanButton => 'لائبریری چیک کریں';

  @override
  String get settingsStorageLibraryHealthy => 'کوئی ٹوٹی ہوئی کلپ نہیں ملی';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'ٹوٹی ہوئی کلپس ملی ہیں: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'ٹوٹی ہوئی کلپس ہٹائیں';

  @override
  String get settingsStorageBrokenClipsRemoved => 'ٹوٹی ہوئی کلپس ہٹا دی گئیں';

  @override
  String get settingsStorageError => 'کچھ غلط ہو گیا';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'زیادہ سے زیادہ ویڈیو کیش';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count ویڈیوز';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'ٹوٹی ہوئی کلپس ہٹائیں؟';

  @override
  String get settingsStorageRepairSectionTitle => 'انسٹالیشن کی مرمت';

  @override
  String get settingsStorageRepairDescription =>
      'اگر ایپ بار بار بند ہو رہی ہے یا عجیب چل رہی ہے تو مقامی ڈیٹا ری سیٹ کرنے سے عموماً مسئلہ حل ہو جاتا ہے۔ آپ کی کلپس اور ڈرافٹس محفوظ رہیں گے۔';

  @override
  String get settingsStorageRepairButton => 'ایپ ڈیٹا ری سیٹ کریں';

  @override
  String get settingsStorageRepairConfirmTitle => 'ایپ ڈیٹا ری سیٹ کریں؟';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'اس سے کیش شدہ فیڈ ڈیٹا اور عارضی فائلیں مٹ جائیں گی۔ آپ کی کلپس، ڈرافٹس، ترتیبات اور لاگ اِن رہیں گے، لیکن بعد میں ایپ دوبارہ شروع کرنی ہوگی۔';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size حذف ہو جائے گا';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'ری سیٹ';

  @override
  String get settingsStorageRepairInProgress => 'ری سیٹ ہو رہا ہے…';

  @override
  String get settingsStorageRepairSuccess =>
      'ہو گیا — مکمل کرنے کے لیے ایپ دوبارہ شروع کریں۔';

  @override
  String get settingsStorageRepairFailure =>
      'سب کچھ ری سیٹ نہیں ہو سکا۔ دوبارہ شروع کرنے کے بعد کوشش کریں۔';

  @override
  String get nostrSettingsSignatureVerification => 'دستخط کی تصدیق';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'منتخب کریں کہ Divine ریلے ایونٹ دستخط کب چیک کرے۔ ایونٹ IDs ہمیشہ پہلے جانچے جاتے ہیں۔';

  @override
  String get nostrSettingsSignatureVerificationAll => 'تمام ریلے';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'سب سے محفوظ۔ ہر ریلے ایونٹ دستخط کی تصدیق کریں۔';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'غیر قابلِ اعتبار ریلے';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'آپ کے کنفیگرڈ پول میں موجود ریلے کی جانچ چھوڑ دیں۔';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'غیر Divine ریلے';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Divine ریلے پر بھروسہ کریں، باقی کی تصدیق کریں۔';

  @override
  String get settingsCrosspostingTitle => 'کراس پوسٹنگ';

  @override
  String get settingsCrosspostingSubtitle =>
      'اپنی ویڈیوز دوسرے پلیٹ فارمز پر شیئر کریں';

  @override
  String get crosspostingSignInRequired =>
      'کراس پوسٹنگ کا انتظام کرنے کے لیے Divine سے سائن ان کریں';

  @override
  String get crosspostingLoadFailed =>
      'آپ کی کراس پوسٹنگ ترتیبات لوڈ نہیں ہو سکیں';

  @override
  String get crosspostingNoPlatforms =>
      'اس وقت کوئی کراس پوسٹنگ پلیٹ فارم دستیاب نہیں';

  @override
  String get crosspostingRetry => 'دوبارہ کوشش کریں';

  @override
  String get crosspostingNotConnected => 'منسلک نہیں';

  @override
  String get crosspostingConnected => 'منسلک';

  @override
  String get crosspostingNeedsReconnect => 'دوبارہ منسلک کرنا ہوگا';

  @override
  String get crosspostingConnect => 'منسلک کریں';

  @override
  String get crosspostingReconnect => 'دوبارہ منسلک کریں';

  @override
  String get crosspostingDisconnect => 'منقطع کریں';

  @override
  String get crosspostingModeOff => 'بند';

  @override
  String get crosspostingModeManual => 'دستی';

  @override
  String get crosspostingModeManualSubtitle =>
      'آپ ہر ویڈیو کے لیے خود منتخب کریں';

  @override
  String get crosspostingModeAutomatic => 'خودکار';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'آئندہ ویڈیوز خودکار طور پر پوسٹ ہوں گی — صرف وہ جو آپ اسے آن کرنے کے بعد شائع کریں';

  @override
  String get crosspostingNotConnectedError =>
      'یہ کیسے پوسٹ کرتا ہے، بدلنے کے لیے پہلے اس پلیٹ فارم کو منسلک کریں۔';

  @override
  String get crosspostingGenericError => 'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔';

  @override
  String get crosspostingCallbackTimeoutError =>
      'سائن ان صفحے سے کوئی جواب نہیں آیا۔ اگر آپ نے وہاں منسلک کر لیا ہے تو ریفریش کریں — ہو سکتا ہے آپ کا اکاؤنٹ پہلے ہی منسلک ہو۔';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform منسلک ہو گیا';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return '$platform منسلک نہیں ہو سکا';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return '$platform پر کنکشن منسوخ کر دیا گیا';
  }

  @override
  String get supporterTitle => 'Divine سپورٹرز';

  @override
  String get supporterTileSubtitle =>
      'اختیاری ماہانہ سبسکرپشن سے Divine کی سپورٹ کریں۔';

  @override
  String get supporterHeroTitle => 'Divine کو چلتے رکھیں';

  @override
  String get supporterHeroBody =>
      'Divine مفت ہے اور ہمیشہ رہے گا۔ اگر آپ لوپ چلتے رکھنے میں ہماری مدد کرنا چاہتے ہیں تو ماہانہ سپورٹر بنیں۔ کچھ بھی مقفل نہیں — یہ بس چراغ جلائے رکھتا ہے اور ہمارا شکریہ کما لیتا ہے۔';

  @override
  String get supporterActiveBadge =>
      'آپ Divine سپورٹر ہیں۔ اسے چلتے رکھنے کے لیے شکریہ۔';

  @override
  String get supporterPurchasePending => 'آپ کی خریداری منظوری کے منتظر ہے۔';

  @override
  String get supporterPurchaseConfirming => 'آپ کی سپورٹ کی تصدیق ہو رہی ہے…';

  @override
  String get supporterStoreChecking => 'اسٹور چیک ہو رہا ہے…';

  @override
  String get supporterUnavailable =>
      'سپورٹر سبسکرپشنز ابھی یہاں دستیاب نہیں ہیں۔';

  @override
  String get supporterRestorePurchases => 'خریداریاں بحال کریں';

  @override
  String get supporterDismissError => 'خرابی ہٹائیں';

  @override
  String get supporterErrorStoreUnavailable =>
      'اس ڈیوائس پر اسٹور دستیاب نہیں ہے۔';

  @override
  String get supporterErrorPurchaseFailed =>
      'خریداری مکمل نہیں ہوئی۔ آپ سے کوئی رقم نہیں لی گئی۔';

  @override
  String get supporterErrorPurchasePending =>
      'آپ کی خریداری منظوری کے منتظر ہے۔';

  @override
  String get supporterErrorRestoreFailed =>
      'بحال کرنے کے لیے کوئی سپورٹر سبسکرپشن نہیں ملی۔';

  @override
  String get supporterErrorOwnershipConflict =>
      'یہ خریداری کسی دوسرے Divine اکاؤنٹ کی ہے۔';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine ابھی سپورٹر اسٹیٹس کی تصدیق نہیں کر سکا۔';

  @override
  String get supporterErrorUnknown =>
      'کچھ غلط ہو گیا۔ براہ کرم دوبارہ کوشش کریں۔';

  @override
  String get supporterDisclaimer =>
      'اسٹور آپ کی خریداری کی تصدیق کرنے کے بعد Divine سپورٹر اسٹیٹس کی تصدیق کرتا ہے۔ پہچان اختیاری ہے، اور ہالہ تصدیق نہیں ہے۔';

  @override
  String get profileNotifyBellOff => 'نئی ویڈیوز کی اطلاع دیں';

  @override
  String get profileNotifyBellOn => 'نئی ویڈیوز کی اطلاعات بند کریں';

  @override
  String get profileNotifyUpdateFailed =>
      'محفوظ نہیں ہو سکا۔ دوبارہ کوشش کریں؟';

  @override
  String get savedSoundYourLabel => 'آپ کا لیبل';

  @override
  String get savedSoundAddHashtags => 'ہیش ٹیگز شامل کریں';

  @override
  String get savedSoundDeviceOnly => 'اس ڈیوائس پر محفوظ';

  @override
  String get savedSoundDetailsRetry =>
      'وہ تفصیلات محفوظ نہیں ہو سکیں۔ دوبارہ کوشش کے لیے تھپتھپائیں۔';

  @override
  String get savedSoundFallbackTitle => 'محفوظ شدہ ساؤنڈ';

  @override
  String get savedSoundPreviewAction => 'ساؤنڈ سنیں';

  @override
  String get savedSoundEditAction => 'ساؤنڈ کی تفصیلات میں ترمیم کریں';

  @override
  String get savedSoundRemoveAction => 'محفوظ شدہ ساؤنڈ ہٹائیں';

  @override
  String get savedSoundClearHashtagFilter => 'ہیش ٹیگ فلٹر صاف کریں';

  @override
  String get soundAllowRemix => 'دوسروں کو اس ساؤنڈ کو ری مکس کرنے دیں';

  @override
  String get soundReuseUnavailable =>
      'اس ساؤنڈ کو ابھی ری مکس نہیں کیا جا سکتا۔';

  @override
  String get soundPublicCredit => 'عوامی ساؤنڈ کریڈٹ';

  @override
  String get soundCreditRequired =>
      'پوسٹ کرنے سے پہلے عوامی ساؤنڈ کریڈٹ شامل کریں۔';

  @override
  String get soundSharedAs => 'بطور شیئر کیا گیا';

  @override
  String get soundOwnWork => 'یہ ساؤنڈ میں نے بنایا ہے';

  @override
  String soundCreatorBy(String creator) {
    return 'بذریعہ $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return '$publisher کی جانب سے شیئر کیا گیا';
  }

  @override
  String get soundRemixingAllowed => 'ری مکسنگ کی اجازت ہے';

  @override
  String get soundCreditOnly => 'صرف کریڈٹ';

  @override
  String get soundCreditTitleLabel => 'ساؤنڈ کا عنوان';

  @override
  String get soundCreditCreatorLabel => 'تخلیق کار';

  @override
  String get soundCreditSourceUrlLabel => 'ماخذ URL';

  @override
  String get soundCreditPublicHashtagsLabel => 'عوامی ہیش ٹیگز';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'ٹیگ کا انتخاب منسوخ کریں';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'منتخب ٹیگز لاگو کریں';

  @override
  String get userPickerCancelSemanticLabel => 'صارف کا انتخاب منسوخ کریں';

  @override
  String get userPickerConfirmSemanticLabel => 'منتخب صارفین کی تصدیق کریں';

  @override
  String get userPickerClearSelectionSemanticLabel => 'صارف کا انتخاب صاف کریں';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'مواد کی وارننگز کا انتخاب منسوخ کریں';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'منتخب مواد کی وارننگز لاگو کریں';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'ویڈیو ایڈیٹر بند کریں';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'پوسٹ کی تفصیلات پر جائیں';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return '$tool میں تبدیلیاں مسترد کریں';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return '$tool میں تبدیلیاں لاگو کریں';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'آڈیو ہٹائیں';

  @override
  String rgbColorSemanticLabel(int red, int green, int blue) {
    return 'RGB $red، $green، $blue';
  }

  @override
  String videoEditorColorPickerSwatchSemanticLabel(
    String picker,
    String color,
  ) {
    return '$picker، $color';
  }

  @override
  String get verifyTitle => 'تصدیق شدہ اکاؤنٹس';

  @override
  String get verifySignedOutMessage =>
      'اپنے اکاؤنٹس جوڑنے کے لیے سائن اِن کریں۔';

  @override
  String get verifyIntro =>
      'جو اکاؤنٹس آپ کے پاس پہلے سے ہیں انہیں جوڑیں، تاکہ لوگ جان سکیں کہ یہ واقعی آپ ہیں۔';

  @override
  String get verifyLoadFailed => 'آپ کے جوڑ لوڈ نہیں ہو سکے۔';

  @override
  String get verifyRetry => 'دوبارہ کوشش کریں';

  @override
  String get verifyLinkedSectionTitle => 'جُڑے ہوئے';

  @override
  String get verifyVerifierUnreachable =>
      'تصدیقی سروس تک رسائی نہیں ہو سکی، اس لیے سب غیر جانچا ہوا دکھ رہا ہے۔';

  @override
  String get verifyAddSectionTitle => 'اکاؤنٹ شامل کریں';

  @override
  String get verifyAllPlatformsLinked =>
      'جو کچھ ہم سپورٹ کرتے ہیں، آپ سب جوڑ چکے ہیں۔';

  @override
  String get verifyStatusVerified => 'تصدیق شدہ';

  @override
  String get verifyStatusUnverified => 'غیر تصدیق شدہ';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return '$platform اکاؤنٹ $identity کا جوڑ ختم کریں';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return '$platform کا جوڑ ختم کریں؟';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity اب آپ کے پروفائل پر نظر نہیں آئے گا۔ آپ بعد میں اسے دوبارہ جوڑ سکتے ہیں، لیکن پھر آپ کو دوبارہ سائن ان کرنا ہوگا یا نیا ثبوت پوسٹ کرنا ہوگا۔';
  }

  @override
  String get verifyUnlinkConfirmCta => 'جوڑ ختم کریں';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'اپنا $platform اکاؤنٹ جوڑیں';
  }

  @override
  String get verifyOneTapBadge => 'ایک ٹیپ';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return '$platform میں سائن اِن کریں، باقی ہم سنبھال لیں گے۔ کچھ پوسٹ نہیں ہوگا۔';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return '$platform کے ساتھ جاری رکھیں';
  }

  @override
  String get verifyConnectProofTitle => 'یا ثبوت پوسٹ کریں';

  @override
  String get verifyConnectProofExplainer =>
      'اپنا npub اپنے اکاؤنٹ پر پوسٹ کریں، پھر اس پوسٹ کا لنک یہاں چسپاں کریں۔';

  @override
  String get verifyNpubLabel => 'آپ کا npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'اپنا npub کاپی کریں';

  @override
  String get verifyNpubCopied => 'npub کاپی ہو گیا';

  @override
  String get verifyIdentityLabel => 'اکاؤنٹ کا نام';

  @override
  String get verifyProofLabel => 'آپ کی پوسٹ کا لنک';

  @override
  String get verifyConnectProofCta => 'جانچیں اور جوڑیں';

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
      'تصدیقی سروس تک رسائی نہیں ہوئی۔ تھوڑی دیر بعد کوشش کریں۔';

  @override
  String get verifyErrorOauthFailed => 'بات نہیں بنی۔ ایک بار پھر کوشش کریں۔';

  @override
  String get verifyErrorHandleRequired => 'پہلے اپنا ہینڈل درج کریں۔';

  @override
  String get verifyErrorPublishFailed =>
      'تصدیق ہو گئی، مگر کسی ریلے نے اپ ڈیٹ قبول نہیں کی۔ دوبارہ کوشش کریں۔';

  @override
  String get verifyErrorOauthUnavailable =>
      'ایک ٹیپ والا سائن اِن ابھی اس کے لیے تیار نہیں۔ نیچے والا ثبوت استعمال کریں۔';

  @override
  String get verifyConnectProofExplainerGithub =>
      'ایک عوامی gist بنائیں جس کی پہلی فائل میں آپ کا npub ہو، پھر gist کا لنک چسپاں کریں۔';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'اپنا npub ایسے Discord چینل میں پوسٹ کریں جسے ہمارا بوٹ پڑھ سکے، پھر پیغام کا لنک چسپاں کریں۔ سرور کی دعوت کچھ ثابت نہیں کرتی۔';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'اُس اکاؤنٹ سے اپنا npub ٹویٹ کریں، پھر ٹویٹ کا لنک چسپاں کریں۔';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'اُس اکاؤنٹ سے اپنا npub پوسٹ کریں، پھر لنک چسپاں کریں۔ اکاؤنٹ کے نام میں انسٹنس بھی چاہیے — صرف alice نہیں بلکہ mastodon.social/@alice۔';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'جُڑتا چینل ہے، آپ کا ٹیلیگرام اکاؤنٹ نہیں۔ چینل کو پہلے عوامی لنک چاہیے (ٹیلیگرام نئے چینل نجی بناتا ہے)۔ وہاں اپنا npub پوسٹ کریں اور پیغام کا لنک چسپاں کریں۔';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'اوپر سائن اِن کر لیا؟ تو اور کچھ درکار نہیں۔ ورنہ اپنا npub پوسٹ کریں اور اُس پوسٹ کا لنک چسپاں کریں۔';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'اپنا npub ویڈیو کے کیپشن میں لکھیں، پھر اُس ویڈیو کا لنک چسپاں کریں۔';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'اپنا npub ویڈیو کی تفصیل میں لکھیں، پھر اُس ویڈیو کا لنک چسپاں کریں۔';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform جُڑ گیا۔';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'یہ نجی چینل یا دعوت کا لنک ہے۔ چینل کو عوامی لنک دیں، پھر پیغام کا لنک چسپاں کریں۔';

  @override
  String get verifyErrorRemoveFailed =>
      'جوڑ ختم نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get verifyErrorLinksUnreadable =>
      'آپ کے موجودہ جوڑ پڑھے نہیں جا سکے، اس لیے کچھ تبدیل نہیں ہوا۔ اپنا کنکشن دیکھ کر دوبارہ کوشش کریں۔';

  @override
  String get verifyChannelLabel => 'چینل کا نام';

  @override
  String get verifyHowItWorksTitle => 'یہ کام کیسے کرتا ہے؟';

  @override
  String get verifyHowItWorksIntro =>
      'اسے دو اکاؤنٹس کے درمیان ہاتھ ملانے کی طرح سمجھیں:';

  @override
  String get verifyHowItWorksYourSide =>
      'آپ کا Divine پروفائل کہتا ہے: ”میں ٹوئٹر پر @alice ہوں۔“';

  @override
  String get verifyHowItWorksOtherSide =>
      'آپ کا ٹوئٹر اکاؤنٹ تصدیق کرتا ہے: ”ہاں، وہ Divine پروفائل میرا ہے۔“';

  @override
  String get verifyHowItWorksBothSides =>
      'ہم دونوں طرف جانچتے ہیں۔ مطابقت ہو تو آپ تصدیق شدہ ہیں۔ اسے جعلی نہیں بنایا جا سکتا — نام اور تصویر نقل ہو سکتی ہے، آپ کے اصلی اکاؤنٹ سے پوسٹ کرنا نہیں۔';

  @override
  String get verifyHowItWorksOwnership =>
      'یہ جوڑ آپ کی اپنی Nostr شناخت پر رہتے ہیں، اس لیے آپ انہیں یہاں سے جب چاہیں ہٹا سکتے ہیں۔';

  @override
  String get generalSettingsSectionIdentity => 'شناخت';

  @override
  String get libraryFilterAll => 'سب';

  @override
  String get libraryFilterArchive => 'آرکائیو';

  @override
  String get libraryFilterDeleted => 'حذف شدہ';

  @override
  String get libraryCategoryNewChipLabel => 'نئی';

  @override
  String get libraryCategoryCreateSemanticLabel => 'زمرہ بنائیں';

  @override
  String get libraryCategoryCreateTitle => 'نیا زمرہ';

  @override
  String get libraryCategoryCreateAction => 'بنائیں';

  @override
  String get libraryCategoryRenameTitle => 'زمرے کا نام بدلیں';

  @override
  String get libraryCategoryRenameAction => 'نام بدلیں';

  @override
  String get libraryCategoryDeleteAction => 'زمرہ حذف کریں';

  @override
  String get libraryCategoryNameLabel => 'زمرے کا نام';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '\"$name\" حذف کریں؟';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'آپ کی کلپس رہیں گی، وہ صرف \"سب\" میں واپس چلی جائیں گی۔';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'اس زمرے کا نام بدلیں یا اسے حذف کریں';

  @override
  String get libraryCategoryMoveTitle => 'منتقل کریں بطرف';

  @override
  String get libraryCategoryMoveNone => 'کوئی زمرہ نہیں';

  @override
  String get libraryCategoryMoveNewCategory => 'نیا زمرہ';

  @override
  String get libraryArchiveAction => 'آرکائیو کریں';

  @override
  String get libraryUnarchiveAction => 'آرکائیو سے نکالیں';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ان زمروں میں رکھیں؟',
      one: 'اس زمرے میں رکھیں؟',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return '$name میں رکھیں';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'اپنے زمروں میں رکھیں';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return '$name سے ہٹائیں';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed => 'اپنے زمروں سے ہٹائیں';

  @override
  String get libraryMoveSelectedClipsTooltip => 'منتخب کلپس منتقل کریں';

  @override
  String get libraryCategoryEmptyTitle => 'یہاں ابھی کچھ نہیں';

  @override
  String get libraryCategoryEmptySubtitle =>
      'کچھ کلپس منتخب کریں اور انہیں اس زمرے میں منتقل کریں۔';

  @override
  String get libraryArchiveEmptyTitle => 'آرکائیو میں کچھ نہیں';

  @override
  String get libraryArchiveEmptySubtitle =>
      'آرکائیو کی گئی کلپس یہاں رہتی ہیں، آپ کی مرکزی لائبریری سے الگ۔';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس $name میں منتقل ہو گئیں',
      one: '1 کلپ $name میں منتقل ہو گئی',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس اپنے زمرے سے نکال دی گئیں',
      one: '1 کلپ اپنے زمرے سے نکال دی گئی',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس آرکائیو ہو گئیں',
      one: '1 کلپ آرکائیو ہو گئی',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count کلپس لائبریری میں واپس آ گئیں',
      one: '1 کلپ لائبریری میں واپس آ گئی',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'ای میل تبدیل کریں';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'اپنا اکاؤنٹ کسی دوسرے پتے پر منتقل کریں';

  @override
  String get accountSettingsChangePassword => 'پاس ورڈ تبدیل کریں';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'سائن اِن کے لیے نیا پاس ورڈ چنیں';

  @override
  String get accountCredentialsNeedsSignIn =>
      'آپ کا سیشن ختم ہو گیا۔ یہ تبدیلی کرنے کے لیے دوبارہ سائن اِن کریں۔';

  @override
  String get accountCredentialsRateLimited =>
      'بہت زیادہ کوششیں۔ چند منٹ انتظار کریں۔';

  @override
  String get accountCredentialsNetwork =>
      'Divine تک نہیں پہنچ سکے۔ اپنا کنکشن دیکھ کر دوبارہ کوشش کریں۔';

  @override
  String get accountCredentialsUnknown => 'یہ نہیں ہو سکا۔ دوبارہ کوشش کریں۔';

  @override
  String get changePasswordSubtitle =>
      'اپنا موجودہ پاس ورڈ لکھیں، پھر نیا چنیں۔';

  @override
  String get changePasswordCurrentLabel => 'موجودہ پاس ورڈ';

  @override
  String get changePasswordWrongCurrent => 'یہ آپ کا موجودہ پاس ورڈ نہیں ہے۔';

  @override
  String get changePasswordSuccess => 'پاس ورڈ تبدیل ہو گیا۔';

  @override
  String get changeEmailSubtitle =>
      'ہم آپ کے نئے پتے اور اکاؤنٹ والے پتے، دونوں پر تصدیقی لنک بھیجیں گے۔ دونوں سے تصدیق کے بعد آپ کی ای میل بدل جائے گی۔';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'آپ کے اکاؤنٹ پر: $email';
  }

  @override
  String get changeEmailNewLabel => 'نئی ای میل';

  @override
  String get changeEmailPasswordLabel => 'آپ کا پاس ورڈ';

  @override
  String get changeEmailSameAsCurrent => 'یہ پہلے ہی آپ کا ای میل پتہ ہے۔';

  @override
  String get changeEmailWrongPassword => 'یہ آپ کا پاس ورڈ نہیں ہے۔';

  @override
  String get changeEmailSubmit => 'تصدیقی لنک بھیجیں';

  @override
  String get changeEmailSentTitle => 'دو لنک بھیج دیے گئے ہیں';

  @override
  String changeEmailSentMessage(String email) {
    return '$email سے اور اپنے اکاؤنٹ والے پتے سے تصدیق کریں۔ دونوں مکمل ہونے پر ای میل بدل جائے گی۔';
  }

  @override
  String get changeEmailSentExpiry =>
      'لنک 24 گھنٹے بعد کام کرنا بند کر دیتے ہیں۔';

  @override
  String get changeEmailSentDone => 'سمجھ گیا';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount ویڈیوز',
      one: '$formattedCount ویڈیو',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'باہمی';

  @override
  String get socialProofFollowsYou => 'آپ کو فالو کرتا ہے';

  @override
  String get socialProofYouFollow => 'آپ فالو کرتے ہیں';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount فالوورز',
      one: '$formattedCount فالوور',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'ابھی ویڈیوز لوڈ نہیں ہو رہیں۔\nمسئلہ ہماری طرف سے ہے، ہم اسے ٹھیک کر رہے ہیں۔';

  @override
  String get feedOfflineMessage =>
      'آپ آف لائن ہیں۔\nاپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔';

  @override
  String get dbFailureTitle => 'آپ کا مقامی ڈیٹابیس کھولا نہیں جا سکا';

  @override
  String get dbFailureAdviceResettable =>
      'دوبارہ شروع کرنے سے یہ ٹھیک نہیں ہوگا۔ نیچے مقامی ڈیٹابیس ری سیٹ کرنے سے Divine کو صاف آغاز ملتا ہے — آپ کا اکاؤنٹ برقرار رہتا ہے۔';

  @override
  String get dbFailureAdviceRestart =>
      'اپنا ڈیوائس اَن لاک کرنے کے بعد Divine دوبارہ شروع کریں۔ اگر یہ ہوتا رہے تو ایپ اپ ڈیٹ کریں یا سپورٹ سے رابطہ کریں۔';

  @override
  String get dbFailureAdviceHotJournal =>
      'Divine کو ایک بار دوبارہ شروع کر کے دیکھیں۔ اگر یہ مسئلہ برقرار رہے تو ایپ اپ ڈیٹ کریں یا سپورٹ سے رابطہ کریں۔ آپ کا مقامی ڈیٹا اب بھی محفوظ ہے۔';

  @override
  String dbFailureDiagnostic(String code) {
    return 'تشخیص: $code';
  }

  @override
  String get dbFailureCloseApp => 'Divine بند کریں';

  @override
  String get dbFailureResetAction => 'مقامی ڈیٹابیس ری سیٹ کریں';

  @override
  String get dbFailureConfirmTitle => 'اپنا مقامی ڈیٹابیس ری سیٹ کریں؟';

  @override
  String get dbFailureConfirmBody =>
      'آپ کا اکاؤنٹ برقرار رہتا ہے۔ اس ڈیوائس پر محفوظ ڈرافٹس اور کلپس حذف ہو جائیں گے — پیغامات اور فیڈز نیٹ ورک سے واپس آ جاتے ہیں۔';

  @override
  String get dbFailureResetConfirm => 'مقامی ڈیٹابیس ابھی ری سیٹ کریں';

  @override
  String get dbFailureCancel => 'منسوخ کریں';

  @override
  String get dbFailureResetFailed =>
      'یہ کام نہیں کیا۔ Divine بند کریں اور دوبارہ کوشش کریں۔';

  @override
  String get dbFailureResetDoneTitle => 'مقامی ڈیٹابیس ری سیٹ ہو گیا';

  @override
  String get dbFailureResetDoneBody =>
      'Divine بند کریں اور دوبارہ کھولیں — اگلی بار شروع ہونے پر نیا مقامی ڈیٹابیس بنے گا۔';

  @override
  String get authSignInOptionsInfo => 'سائن ان کے اختیارات کے بارے میں';

  @override
  String get authShowPassword => 'پاس ورڈ دکھائیں';

  @override
  String get authHidePassword => 'پاس ورڈ چھپائیں';

  @override
  String get followUserSemanticLabel => 'صارف کو فالو کریں';

  @override
  String get unfollowUserSemanticLabel => 'صارف کو ان فالو کریں';

  @override
  String get commentsLoadingSemanticLabel => 'تبصرے لوڈ ہو رہے ہیں';

  @override
  String get analyticsWindowAll => 'سب';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'صارف کو فالو کریں $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'صارف کو ان فالو کریں $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / ماہ';
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
  String get updateGentleBanner => 'ایک نئی اپ ڈیٹ آ گئی ہے۔ دیکھیں ←';

  @override
  String get updateModerateTitle =>
      'آپ کے آخری بار چیک کرنے کے بعد ایک اپ ڈیٹ آئی ہے';

  @override
  String get updateUrgentTitle => 'آپ اہم اصلاحات سے محروم ہیں';

  @override
  String get updateNotNow => 'ابھی نہیں';

  @override
  String get updateAction => 'اپ ڈیٹ کریں';

  @override
  String updateNewIn(String version) {
    return '$version میں نیا:';
  }

  @override
  String get settingsUpdateAvailable => 'اپ ڈیٹ دستیاب ہے';
}

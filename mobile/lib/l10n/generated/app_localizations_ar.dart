// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'استرداد المقاطع';

  @override
  String get devOptionsClipRecoveryDescription =>
      'يعثر على التسجيلات المحفوظة ضمن حساب آخر وعلى ملفات الفيديو التي لم يعد أي سجل يشير إليها.';

  @override
  String get devOptionsClipRecoveryScan => 'فحص';

  @override
  String get devOptionsClipRecoveryFailure => 'فشل استرداد المقاطع';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips مقاطع',
      one: 'مقطع واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts مسودات',
      one: 'مسودة واحدة',
    );
    return 'ظاهر الآن: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'مخفية ضمن حسابات أخرى';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips مقاطع',
      one: 'مقطع واحد',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts مسودات',
      one: 'مسودة واحدة',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'نقل إلى هذا الحساب';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'ملفات غير مُشار إليها: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'إعادة البناء في المكتبة';

  @override
  String get devOptionsClipRecoveryEmpty => 'لا يوجد ما يمكن استرداده';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم استرداد $count مقاطع',
      one: 'تم استرداد مقطع واحد',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'تم نسخ تقرير الاسترداد';

  @override
  String get devOptionsStorageFootprint => 'مساحة التخزين المستخدمة';

  @override
  String get devOptionsStorageFootprintDescription =>
      'كل مجلد يكتب فيه التطبيق. مسح ذاكرة التخزين المؤقت يحرر جزءًا منها فقط.';

  @override
  String get devOptionsStorageFootprintMeasure => 'قياس';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'الإجمالي: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'تم نسخ تقرير التخزين';

  @override
  String get devOptionsStorageFootprintFailure => 'تعذر قياس مساحة التخزين';

  @override
  String get feedTuningMoreLabel => 'المزيد مثل هذا';

  @override
  String get feedTuningLessLabel => 'أقل مثل هذا';

  @override
  String get feedTuningUndo => 'تراجع';

  @override
  String get dmMessageBubbleVideoReplyHint => 'افتح الفيديو المُشار إليه';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSecureAccount => 'أمّن حسابك';

  @override
  String get settingsSessionExpired => 'انتهت الجلسة';

  @override
  String get settingsSessionExpiredSubtitle =>
      'سجّل الدخول مرّة أخرى لاستعادة الوصول الكامل';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'تحليلات الصانع';

  @override
  String get settingsSupportCenter => 'مركز الدعم';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get settingsBlueskyPublishing => 'النشر على Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'أدر النشر المتزامن إلى Bluesky';

  @override
  String get settingsNostrSettings => 'إعدادات Nostr';

  @override
  String get settingsIntegratedApps => 'التطبيقات المدمجة';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'تطبيقات خارجية موثوقة تعمل داخل Divine';

  @override
  String get settingsExperimentalFeatures => 'ميزات تجريبية';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'تعديلات قد تتعثّر—جرّبها إن كنت فضوليًا.';

  @override
  String get settingsLegal => 'الأمور القانونية';

  @override
  String get settingsIntegrationPermissions => 'صلاحيات التطبيقات المدمجة';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'راجع وألغِ موافقات التطبيقات المخزّنة';

  @override
  String settingsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsVersionEmpty => 'الإصدار';

  @override
  String get settingsDeveloperModeAlreadyEnabled => 'وضع المطوّر مُفعّل مسبقًا';

  @override
  String get settingsDeveloperModeEnabled => 'تم تفعيل وضع المطوّر!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count نقرة إضافية لتفعيل وضع المطوّر';
  }

  @override
  String get settingsShareDivine => 'مشاركة Divine مع الأصدقاء';

  @override
  String get settingsSwitchAccount => 'تبديل الحساب';

  @override
  String get settingsAddAnotherAccount => 'إضافة حساب آخر';

  @override
  String get settingsAccountSwitchFailed =>
      'تعذر تبديل الحسابات. يُرجى المحاولة مرة أخرى.';

  @override
  String get settingsUnsavedDraftsTitle => 'مسودات غير محفوظة';

  @override
  String get settingsUploadInProgressTitle => 'جارٍ الرفع';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع قيد الرفع',
      many: '$count مقطعًا قيد الرفع',
      few: '$count مقاطع قيد الرفع',
      two: 'مقطعان قيد الرفع',
      one: 'مقطع واحد قيد الرفع',
      zero: 'مقاطع قيد الرفع',
    );
    return 'لا يزال لديك $_temp0. تبديل الحساب يوقف الرفع — تبقى المقاطع كمسودات في هذا الحساب.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسودة غير محفوظة',
      many: '$count مسودة غير محفوظة',
      few: '$count مسودات غير محفوظة',
      two: 'مسودتان غير محفوظتين',
      one: 'مسودة واحدة غير محفوظة',
      zero: 'مسودات غير محفوظة',
    );
    return 'لديك $_temp0. تبديل الحسابات سيحتفظ بها، لكن قد ترغب في نشرها أو مراجعتها أولاً.';
  }

  @override
  String get settingsCancel => 'إلغاء';

  @override
  String get settingsSwitchAnyway => 'تبديل على أي حال';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'انتهت جلسة ذلك الحساب. تسجيل الدخول إليه مرة أخرى يعني تسجيل الخروج من الحساب الذي تستخدمه الآن.';

  @override
  String get settingsAppVersionLabel => 'إصدار التطبيق';

  @override
  String get settingsAppLanguage => 'لغة التطبيق';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (افتراضي الجهاز)';
  }

  @override
  String get settingsAppLanguageTitle => 'لغة التطبيق';

  @override
  String get settingsAppLanguageDescription => 'اختر لغة واجهة التطبيق';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'استخدام لغة الجهاز';

  @override
  String get settingsGeneralTitle => 'الإعدادات العامة';

  @override
  String get settingsContentSafetyTitle => 'المحتوى والأمان';

  @override
  String get generalSettingsSectionIntegrations => 'التكاملات';

  @override
  String get generalSettingsSectionViewing => 'المشاهدة';

  @override
  String get generalSettingsSectionCreating => 'الإنشاء';

  @override
  String get generalSettingsSectionApp => 'التطبيق';

  @override
  String get appearanceSettingsTitle => 'المظهر';

  @override
  String get appearanceSettingsSubtitle => 'اختر شكل Divine على هذا الجهاز';

  @override
  String get appearanceSettingsSystem => 'إعداد النظام';

  @override
  String get appearanceSettingsLight => 'فاتح';

  @override
  String get appearanceSettingsDark => 'داكن';

  @override
  String get generalSettingsClosedCaptions => 'الترجمة المصاحبة';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'اعرض الترجمة عندما تتضمّنها الفيديوهات';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'فيديوهات مربّعة فقط';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'أبقِ التغذيات بالشكل المربّع الكلاسيكي';

  @override
  String get contentPreferencesTitle => 'تفضيلات المحتوى';

  @override
  String get contentPreferencesContentFilters => 'مرشّحات المحتوى';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'أدر مرشّحات تحذيرات المحتوى';

  @override
  String get contentPreferencesContentLanguage => 'لغة المحتوى';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (افتراضي الجهاز)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'وسِم فيديوهاتك بلغة حتى يتمكّن المشاهدون من تصفية المحتوى.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'استخدام لغة الجهاز (افتراضي)';

  @override
  String get contentPreferencesAudioSharing => 'إتاحة صوتي للاستخدام';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'عند التفعيل، يمكن للآخرين استخدام الصوت من فيديوهاتك';

  @override
  String get contentPreferencesMusicMode => 'وضع الموسيقى';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'يوقف تنقية الضوضاء التي تُخفّت صوت الآلات الموسيقية. أفضل للموسيقى، وأقسى على الأصوات.';

  @override
  String get contentPreferencesAccountLabels => 'وسوم الحساب';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'ضع وسومًا لمحتواك';

  @override
  String get contentPreferencesAccountContentLabels => 'وسوم محتوى الحساب';

  @override
  String get contentPreferencesClearAll => 'مسح الكل';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'اختر كل ما ينطبق على حسابك';

  @override
  String get contentPreferencesDoneNoLabels => 'تم (بدون وسوم)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'تم ($count محدد)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'جهاز إدخال الصوت';

  @override
  String get contentPreferencesAutoRecommended => 'تلقائي (موصى به)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'يختار تلقائيًا أفضل ميكروفون';

  @override
  String get contentPreferencesSelectAudioInput => 'حدد إدخال الصوت';

  @override
  String get contentPreferencesUnknownMicrophone => 'ميكروفون غير معروف';

  @override
  String get contentFiltersAdultContent => 'محتوى للبالغين';

  @override
  String get contentFiltersViolenceGore => 'العنف والدماء';

  @override
  String get contentFiltersSubstances => 'المواد';

  @override
  String get contentFiltersOther => 'أخرى';

  @override
  String get contentFiltersAgeGateMessage =>
      'تحقّق من عمرك في إعدادات الأمان والخصوصية لفتح مرشّحات محتوى البالغين';

  @override
  String get contentFiltersShow => 'عرض';

  @override
  String get contentFiltersWarn => 'تحذير';

  @override
  String get contentFiltersFilterOut => 'إخفاء';

  @override
  String get profileBlockedAccountNotAvailable => 'هذا الحساب غير متاح';

  @override
  String get profileInvalidId => 'معرّف الملف الشخصي غير صالح';

  @override
  String profileShareText(String displayName, String npub) {
    return 'شاهد $displayName على Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName على Divine';
  }

  @override
  String get profileShareFailed =>
      'تعذّرت مشاركة الملف الشخصي. يرجى المحاولة مرّة أخرى.';

  @override
  String get profileCopyPublicKey => 'نسخ المفتاح العام (npub)';

  @override
  String get profileGetEmbedCode => 'الحصول على كود التضمين';

  @override
  String get profilePublicKeyCopied => 'تم نسخ المفتاح العام إلى الحافظة';

  @override
  String get profileEmbedCodeCopied => 'تم نسخ كود التضمين إلى الحافظة';

  @override
  String get profileMoreTooltip => 'المزيد';

  @override
  String get profileMoreSemanticLabel => 'خيارات إضافية';

  @override
  String get profileAvatarLightboxBarrierLabel => 'إغلاق الصورة الرمزية';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'إغلاق معاينة الصورة الرمزية';

  @override
  String get profileFollowingLabel => 'متابع';

  @override
  String get profileFollowLabel => 'متابعة';

  @override
  String get profileBlockedLabel => 'محظور';

  @override
  String get profileFollowersLabel => 'المتابِعون';

  @override
  String get profileFollowingStatLabel => 'يتابِع';

  @override
  String get profileVideosLabel => 'الفيديوهات';

  @override
  String get profileCollabsLabel => 'التعاونات';

  @override
  String get profileLikedLabel => 'أعجبني';

  @override
  String get profileRepostsLabel => 'إعادات النشر';

  @override
  String get profileListsLabel => 'القوائم';

  @override
  String get profileCommentsLabel => 'التعليقات';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوة تعاون ما زالت بحاجة للإرسال',
      many: '$count دعوة تعاون ما زالت بحاجة للإرسال',
      few: '$count دعوات تعاون ما زالت بحاجة للإرسال',
      two: 'دعوتا تعاون ما زالتا بحاجة للإرسال',
      one: 'دعوة تعاون واحدة ما زالت بحاجة للإرسال',
      zero: 'لا دعوات تعاون بحاجة للإرسال',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'أبقينا الدعوة في قائمة الانتظار. أعد المحاولة من هنا.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'لأجل \"$title\". أعد المحاولة من هنا.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'إعادة المحاولة';

  @override
  String get profileCollaboratorInviteRetryingAction => 'جارٍ إعادة المحاولة';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'إعادة محاولة دعوة التعاون غير متاحة الآن.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوة تعاون ما زالت بحاجة للإرسال.',
      many: '$count دعوة تعاون ما زالت بحاجة للإرسال.',
      few: '$count دعوات تعاون ما زالت بحاجة للإرسال.',
      two: 'دعوتا تعاون ما زالتا بحاجة للإرسال.',
      one: 'دعوة تعاون واحدة ما زالت بحاجة للإرسال.',
      zero: 'تم إرسال دعوات التعاون.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count متعاون لا يمكنه استقبال الدعوات.',
      many: '$count متعاونًا لا يمكنه استقبال الدعوات.',
      few: '$count متعاونين لا يمكنهم استقبال الدعوات.',
      two: 'متعاونان لا يمكنهما استقبال الدعوات.',
      one: 'متعاون واحد لا يمكنه استقبال الدعوات.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count مستخدم';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'حظر $displayName؟';
  }

  @override
  String get profileBlockExplanation => 'عند حظر مستخدم:';

  @override
  String get profileBlockBulletHidePosts => 'لن تظهر منشوراته في تغذياتك.';

  @override
  String get profileBlockBulletCantView =>
      'لن يتمكن من رؤية ملفك الشخصي أو متابعتك أو مشاهدة منشوراتك.';

  @override
  String get profileBlockBulletNoNotify => 'لن يتم إبلاغه بهذا التغيير.';

  @override
  String get profileBlockBulletYouCanView =>
      'لا يزال بإمكانك رؤية ملفه الشخصي.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'حظر $displayName';
  }

  @override
  String get profileCancelButton => 'إلغاء';

  @override
  String get profileLearnMore => 'اعرف المزيد';

  @override
  String profileUnblockTitle(String displayName) {
    return 'إلغاء حظر $displayName؟';
  }

  @override
  String get profileUnblockExplanation => 'عند إلغاء حظر هذا المستخدم:';

  @override
  String get profileUnblockBulletShowPosts => 'ستظهر منشوراته في تغذياتك.';

  @override
  String get profileUnblockBulletCanView =>
      'سيتمكّن من رؤية ملفك الشخصي ومتابعتك ومشاهدة منشوراتك.';

  @override
  String get profileUnblockBulletNoNotify => 'لن يتم إبلاغه بهذا التغيير.';

  @override
  String get profileLearnMoreAt => 'اعرف المزيد على ';

  @override
  String get profileUnblockButton => 'إلغاء الحظر';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'إلغاء متابعة $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'حظر $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'إلغاء حظر $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'أبلغ عن $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'أضف $displayName إلى قائمة';
  }

  @override
  String get profileNoCollabsTitle => 'لا توجد تعاونات بعد';

  @override
  String get profileCollabsOwnEmpty => 'ستظهر هنا الفيديوهات التي تتعاون عليها';

  @override
  String get profileCollabsOtherEmpty =>
      'ستظهر هنا الفيديوهات التي يتعاون عليها';

  @override
  String get profileErrorLoadingCollabs => 'خطأ في تحميل فيديوهات التعاون';

  @override
  String get profileNoSavedVideosTitle => 'لا شيء محفوظ بعد';

  @override
  String get profileSavedOwnEmpty =>
      'احفظ الفيديوهات من قائمة المشاركة وستظهر هنا.';

  @override
  String get profileErrorLoadingSaved => 'خطأ في تحميل الفيديوهات المحفوظة';

  @override
  String get profileNoCommentsOwnTitle => 'لا توجد تعليقات بعد';

  @override
  String get profileNoCommentsOtherTitle => 'لا توجد تعليقات';

  @override
  String get profileCommentsOwnEmpty => 'ستظهر هنا تعليقاتك وردودك';

  @override
  String get profileCommentsOtherEmpty => 'ستظهر هنا تعليقاته وردوده';

  @override
  String get profileErrorLoadingComments => 'خطأ في تحميل التعليقات';

  @override
  String get profileVideoRepliesSection => 'ردود الفيديو';

  @override
  String get profileCommentsSection => 'التعليقات';

  @override
  String get profileEditLabel => 'تعديل';

  @override
  String get profileLibraryLabel => 'المكتبة';

  @override
  String get profileNoLikedVideosTitle => 'لا توجد فيديوهات معجب بها بعد';

  @override
  String get profileLikedOwnEmpty => 'ستظهر هنا الفيديوهات التي تعجبك';

  @override
  String get profileLikedOtherEmpty => 'ستظهر هنا الفيديوهات التي تعجبه';

  @override
  String get profileErrorLoadingLiked => 'خطأ في تحميل الفيديوهات المعجب بها';

  @override
  String get profileNoRepostsTitle => 'لا توجد إعادات نشر بعد';

  @override
  String get profileRepostsOwnEmpty => 'ستظهر هنا الفيديوهات التي تعيد نشرها';

  @override
  String get profileRepostsOtherEmpty => 'ستظهر هنا الفيديوهات التي يعيد نشرها';

  @override
  String get profileErrorLoadingReposts =>
      'خطأ في تحميل الفيديوهات المعاد نشرها';

  @override
  String get profileNoVideosTitle => 'لا توجد فيديوهات بعد';

  @override
  String get profileNoVideosOwnSubtitle => 'شارك أول فيديو لك ليظهر هنا';

  @override
  String get profileNoVideosOtherSubtitle =>
      'لم يشارك هذا المستخدم أي فيديو بعد';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'صورة مصغّرة للفيديو $number';
  }

  @override
  String get profileShowMore => 'عرض المزيد';

  @override
  String get profileShowLess => 'عرض أقل';

  @override
  String get dmMessageDisplayLimitReached => 'لن يتم عرض بقية هذه الرسالة.';

  @override
  String get profileCompleteYourProfile => 'أكمل ملفك الشخصي';

  @override
  String get profileCompleteSubtitle => 'أضف اسمك ونبذة عنك وصورة للبدء';

  @override
  String get profilePleaseTryAgain => 'يرجى المحاولة مرّة أخرى';

  @override
  String get profileSecureYourAccount => 'أمّن حسابك';

  @override
  String get profileSecureSubtitle =>
      'أضف بريدًا وكلمة مرور لاستعادة حسابك من أي جهاز';

  @override
  String get profileRetryButton => 'إعادة المحاولة';

  @override
  String get profileSessionExpired => 'انتهت الجلسة';

  @override
  String get profileSignInToRestore =>
      'سجّل الدخول مرّة أخرى لاستعادة الوصول الكامل';

  @override
  String get profileSignInButton => 'تسجيل الدخول';

  @override
  String get profileMaybeLaterLabel => 'ربما لاحقًا';

  @override
  String get profileSecurePrimaryButton => 'أضف بريدًا وكلمة مرور';

  @override
  String get profileCompletePrimaryButton => 'حدّث ملفك الشخصي';

  @override
  String get profileLoopsLabel => 'التكرارات';

  @override
  String get profileLikesLabel => 'الإعجابات';

  @override
  String get profileMyLibraryLabel => 'مكتبتي';

  @override
  String get profileMessageLabel => 'رسالة';

  @override
  String get profileShareLabel => 'مشاركة الملف الشخصي';

  @override
  String get profileDeletedAccountName => 'حساب محذوف';

  @override
  String get inboxActionReportVanishedAccount => 'الإبلاغ عن هذا الحساب';

  @override
  String get inboxActionBlockVanishedAccount => 'حظر هذا الحساب';

  @override
  String get inboxActionUnblockVanishedAccount => 'إلغاء حظر هذا الحساب';

  @override
  String get inboxReportedVanishedAccount => 'تم الإبلاغ عن هذا الحساب';

  @override
  String get inboxBlockedVanishedAccount => 'تم حظر هذا الحساب';

  @override
  String get inboxUnblockedVanishedAccount => 'تم إلغاء حظر هذا الحساب';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'يؤدي هذا إلى إزالة المحادثة من صندوق الوارد. إذا راسلك مرة أخرى، تبدأ محادثة جديدة.';

  @override
  String get inboxConversationDeletedAccountSubtitle => 'تم حذف هذا الحساب';

  @override
  String get profileUserFallback => 'مستخدم';

  @override
  String get profileLinkCopied => 'تم نسخ رابط الملف الشخصي';

  @override
  String get profileSetupEditProfileTitle => 'تعديل الملف الشخصي';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'أعِدّ ملفك الشخصي قبل إضافة عنوان NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'إنشاء ملف شخصي';

  @override
  String get profileSetupBackLabel => 'رجوع';

  @override
  String get profileSetupAboutNostr => 'عن Nostr';

  @override
  String get profileSetupProfilePublished => 'تم نشر الملف الشخصي بنجاح!';

  @override
  String get profileSetupUnsavedChangesTitle => 'حفظ التغييرات؟';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'احفظ تعديلاتك قبل المغادرة، أو تجاهلها وواصل.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'حفظ التغييرات';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'تجاهل التغييرات';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'متابعة التعديل';

  @override
  String get profileSetupCreateNewProfile => 'إنشاء ملف شخصي جديد؟';

  @override
  String get profileSetupNoExistingProfile =>
      'لم نجد ملفًا موجودًا على المحولات الخاصة بك. النشر سينشئ ملفًا جديدًا. هل تريد المتابعة؟';

  @override
  String get profileSetupPublishButton => 'نشر';

  @override
  String get profileSetupUsernameTaken =>
      'تم أخذ اسم المستخدم للتو. يرجى اختيار اسم آخر.';

  @override
  String get profileSetupClaimFailed =>
      'تعذّرت المطالبة باسم المستخدم. حاول مرّة أخرى.';

  @override
  String get profileSetupPublishFailed =>
      'تعذّر نشر الملف الشخصي. حاول مرّة أخرى.';

  @override
  String get profileSetupNoRelaysConnected =>
      'لا يمكن الوصول إلى الشبكة. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get profileSetupDisplayNameLabel => 'الاسم المعروض';

  @override
  String get profileSetupDisplayNameRequired => 'يرجى إدخال اسم معروض';

  @override
  String get profileSetupBioLabel => 'نبذة (اختيارية)';

  @override
  String get profileSetupWebsiteLabel => 'الموقع الإلكتروني (اختياري)';

  @override
  String get profileSetupPublicKeyLabel => 'المفتاح العام (npub)';

  @override
  String get profileSetupUsernameLabel => 'اسم المستخدم (اختياري)';

  @override
  String get profileSetupUsernameHelper =>
      'استخدم الحروف والأرقام أو الشرطات. يصبح اسم المستخدم عنوانًا على divine.video. استخدم اسم العرض للمسافات أو الرموز.';

  @override
  String get profileSetupSaveButton => 'حفظ';

  @override
  String get profileSetupSavingButton => 'جاري الحفظ...';

  @override
  String get profileSetupImageUrlTitle => 'إضافة رابط صورة';

  @override
  String get profileSetupImageSelectionFailed =>
      'فشل اختيار الصورة. يرجى لصق رابط الصورة أدناه بدلاً من ذلك.';

  @override
  String get profileSetupImagesTypeGroup => 'صور';

  @override
  String get cameraPickErrorPermissionDenied =>
      'الوصول إلى الكاميرا مغلق. فعّله من الإعدادات لالتقاط صورة.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'الوصول إلى الكاميرا غير مسموح على هذا الجهاز.';

  @override
  String get cameraPickErrorBusy =>
      'المُنتقي مفتوح بالفعل. أغلقه وحاول مرّة أخرى.';

  @override
  String get cameraPickErrorGeneric => 'تعذّر فتح الكاميرا. حاول مرّة أخرى.';

  @override
  String get profileSetupGotItButton => 'فهمت';

  @override
  String get profileSetupUploadFailedGeneric =>
      'فشل رفع الصورة. يُرجى المحاولة مرة أخرى لاحقًا.';

  @override
  String get profileSetupUploadNetworkError =>
      'خطأ في الشبكة: يرجى التحقق من اتصالك والمحاولة مرّة أخرى.';

  @override
  String get profileSetupUploadAuthError =>
      'خطأ في المصادقة: حاول تسجيل الخروج ثم الدخول مجددًا.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'الملف كبير جدًا: يرجى اختيار صورة أصغر (10 ميغابايت كحد أقصى).';

  @override
  String get profileSetupUploadServerError =>
      'فشل رفع الصورة. خوادمنا غير متاحة مؤقتًا. يُرجى المحاولة مرة أخرى بعد قليل.';

  @override
  String get profileSetupBannerClearButton => 'مسح الغلاف';

  @override
  String get profileSetupBannerChangeColor => 'لون اللافتة';

  @override
  String get profileSetupChangeBannerTitle => 'تغيير اللافتة';

  @override
  String get profileSetupBannerColorPickerTitle => 'تغيير لون اللافتة';

  @override
  String get profileSetupBannerColorCustom => 'مخصص';

  @override
  String get profileSetupBannerColorNone => 'بدون لون';

  @override
  String get profileSetupBannerColorLime => 'ليموني';

  @override
  String get profileSetupBannerColorYellow => 'أصفر';

  @override
  String get profileSetupBannerColorViolet => 'بنفسجي فاتح';

  @override
  String get profileSetupBannerColorPink => 'وردي';

  @override
  String get profileSetupBannerColorOrange => 'برتقالي';

  @override
  String get profileSetupBannerColorPurple => 'أرجواني';

  @override
  String get profileSetupAvatarClearButton => 'إزالة الصورة';

  @override
  String get profileSetupImageTakePhoto => 'التقاط صورة';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'الرفع من معرض الصور';

  @override
  String get profileSetupImagePasteLink => 'لصق رابط صورة';

  @override
  String get profileSetupEditAvatarLabel => 'تعديل صورة الملف الشخصي';

  @override
  String get profileSetupEditBannerLabel => 'تعديل اللافتة';

  @override
  String get profileSetupUsernameChecking => 'جاري التحقق من التوفر...';

  @override
  String get profileSetupUsernameAvailable => 'اسم المستخدم متاح!';

  @override
  String get profileSetupUsernameTakenIndicator => 'اسم المستخدم مأخوذ مسبقًا';

  @override
  String get profileSetupUsernameReserved => 'اسم المستخدم محجوز';

  @override
  String get profileSetupContactSupport => 'اتصل بالدعم';

  @override
  String get profileSetupCheckAgain => 'تحقّق مجددًا';

  @override
  String get profileSetupUsernameBurned => 'اسم المستخدم هذا لم يعد متاحًا';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'يُسمح بالأحرف والأرقام والواصلات فقط';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'لا يمكن أن يبدأ اسم المستخدم أو ينتهي بشرطة';

  @override
  String get profileSetupUsernameInvalidLength =>
      'يجب أن يتراوح طول اسم المستخدم بين 3 و 63 حرفًا';

  @override
  String get profileSetupUsernameNetworkError =>
      'تعذّر التحقق من التوفر. حاول مرّة أخرى.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'تنسيق اسم المستخدم غير صالح';

  @override
  String get profileSetupUsernameCheckFailed => 'تعذّر التحقق من التوفر';

  @override
  String get profileSetupUsernameReservedTitle => 'اسم المستخدم محجوز';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'الاسم $username محجوز. أخبرنا لماذا يجب أن يكون لك.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'مثل: هو اسم علامتي التجارية، اسم الشهرة، إلخ.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'هل تواصلت مع الدعم بالفعل؟ انقر على \"تحقّق مجددًا\" لترى إن كان قد أُفرج عنه لك.';

  @override
  String get profileSetupSupportRequestSent =>
      'تم إرسال طلب الدعم! سنرد عليك قريبًا.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'تعذّر فتح البريد. أرسل إلى: names@divine.video';

  @override
  String get profileSetupSendRequest => 'إرسال الطلب';

  @override
  String get profileSetupUseOwnNip05 => 'استخدم عنوان NIP-05 الخاص بك';

  @override
  String get profileSetupNip05AddressLabel => 'عنوان NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'صيغة NIP-05 غير صالحة (مثال: name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'استخدم حقل اسم المستخدم أعلاه لـ divine.video';

  @override
  String get nostrSettingsNip05Address => 'عنوان NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'استخدم اسم المستخدم الخاص بك على divine.video، أو وجّه معرّفك إلى عنوان NIP-05 على نطاق تتحكم به.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'حفظ NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'تم حفظ NIP-05';

  @override
  String get nostrSettingsNip05SaveFailed => 'تعذّر حفظ NIP-05. حاول مرة أخرى.';

  @override
  String get profileSetupNip05ConfirmTitle => 'استخدام NIP-05 خاص بك؟';

  @override
  String get profileSetupNip05ConfirmBody =>
      'يربط NIP-05 اسمًا مثل you@yourdomain.com بهويتك على Nostr. عليك التحكم في النطاق واستضافة ملف تحقق في المسار الصحيح. إذا كان الإعداد خاطئًا، فلن يجدك الناس وسيختفي معرّفك الموثّق. تابع فقط إذا كنت قد أعددت ذلك.';

  @override
  String get profileSetupNip05ConfirmContinue => 'متابعة';

  @override
  String get profileSetupNip05ConfirmCancel => 'إلغاء';

  @override
  String get profileSetupProfilePicturePreview => 'معاينة صورة الملف الشخصي';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine مبني على Nostr،';

  @override
  String get nostrInfoIntroDescription =>
      ' بروتوكول مفتوح مقاوم للرقابة يسمح للناس بالتواصل عبر الإنترنت دون الاعتماد على شركة أو منصّة واحدة. ';

  @override
  String get nostrInfoIntroIdentity =>
      'عند التسجيل في Divine، تحصل على هوية Nostr جديدة.';

  @override
  String get nostrInfoOwnership =>
      'Nostr يسمح لك بامتلاك محتواك وهويتك وشبكتك الاجتماعية، والتي يمكنك استخدامها في تطبيقات عديدة. النتيجة خيارات أكثر، واحتكار أقل، وإنترنت اجتماعي أكثر صحة ومرونة.';

  @override
  String get nostrInfoLingo => 'مصطلحات Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' عنوان Nostr العام الخاص بك. يمكن مشاركته بأمان ويسمح للآخرين بالعثور عليك أو متابعتك أو مراسلتك عبر تطبيقات Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' مفتاحك الخاص ودليل ملكيتك. يمنحك التحكم الكامل بهويتك في Nostr، لذلك ';

  @override
  String get nostrInfoNsecWarning => 'احتفظ به سريًا دومًا!';

  @override
  String get nostrInfoUsernameLabel => 'اسم مستخدم Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' اسم قابل للقراءة (مثل @name.divine.video) يرتبط بـ npub الخاص بك. يجعل هويتك في Nostr أسهل للتعرّف والتحقق، مثل عنوان البريد الإلكتروني.';

  @override
  String get nostrInfoLearnMoreAt => 'اعرف المزيد على ';

  @override
  String get nostrInfoGotIt => 'فهمت!';

  @override
  String get videoGridRefreshLabel => 'البحث عن المزيد من الفيديوهات';

  @override
  String get videoGridOptionsTitle => 'خيارات الفيديو';

  @override
  String get videoGridEditVideo => 'تعديل الفيديو';

  @override
  String get videoGridEditVideoSubtitle => 'تحديث العنوان والوصف والوسوم';

  @override
  String get videoGridDeleteVideo => 'حذف الفيديو';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'أزل هذا الفيديو من Divine. قد يظل يظهر في عملاء Nostr آخرين.';

  @override
  String get videoGridDeletingContent => 'جاري حذف المحتوى...';

  @override
  String get exploreTabFeatured => 'مميز';

  @override
  String get exploreTabClassics => 'الكلاسيكيات';

  @override
  String get exploreTabNew => 'جديد';

  @override
  String get exploreTabPopular => 'الرائج';

  @override
  String get exploreTabCategories => 'الفئات';

  @override
  String get exploreTabForYou => 'لأجلك';

  @override
  String get exploreTabLists => 'القوائم';

  @override
  String get exploreTabIntegratedApps => 'التطبيقات المدمجة';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'لا شيء هنا بعد. عد قريبًا.';

  @override
  String get featuredTabLoadFailed => 'تعذّر تحميل هذه المجموعة.';

  @override
  String get featuredTabRetry => 'حاول مرة أخرى';

  @override
  String get exploreNoVideosAvailable => 'لا توجد فيديوهات متاحة';

  @override
  String get exploreDiscoverLists => 'اكتشف القوائم';

  @override
  String get exploreAboutLists => 'عن القوائم';

  @override
  String get exploreAboutListsDescription =>
      'القوائم تساعدك في تنظيم محتوى Divine بطريقتين:';

  @override
  String get explorePeopleLists => 'قوائم الأشخاص';

  @override
  String get explorePeopleListsDescription =>
      'تابع مجموعات من الصناع وشاهد أحدث فيديوهاتهم';

  @override
  String get exploreVideoLists => 'قوائم الفيديو';

  @override
  String get exploreVideoListsDescription =>
      'أنشئ قوائم تشغيل لفيديوهاتك المفضلة لمشاهدتها لاحقًا';

  @override
  String get exploreMyLists => 'قوائمي';

  @override
  String get exploreSubscribedLists => 'القوائم المشترك بها';

  @override
  String get exploreErrorLoadingLists =>
      'خطأ في تحميل القوائم. يرجى المحاولة مرّة أخرى.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو جديد',
      many: '$count فيديو جديد',
      few: '$count فيديوهات جديدة',
      two: 'فيديوان جديدان',
      one: 'فيديو جديد واحد',
      zero: 'لا توجد فيديوهات جديدة',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو جديد',
      many: '$count فيديو جديد',
      few: '$count فيديوهات جديدة',
      two: 'فيديوين جديدين',
      one: 'فيديو جديد واحد',
      zero: 'لا شيء',
    );
    return 'تحميل $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'تشغيل الفيديو';

  @override
  String get videoPlayerMute => 'كتم الفيديو';

  @override
  String get videoPlayerUnmute => 'إلغاء كتم الفيديو';

  @override
  String get videoPlayerTapHint =>
      'اضغط للتشغيل أو الإيقاف المؤقت. اضغط مرتين للإعجاب.';

  @override
  String get videoSettingsMenuOpen => 'افتح إعدادات التشغيل';

  @override
  String get videoSettingsMenuClose => 'أغلق إعدادات التشغيل';

  @override
  String get videoSettingsCaptionsEnable => 'تفعيل الترجمة';

  @override
  String get videoSettingsCaptionsDisable => 'إيقاف الترجمة';

  @override
  String get videoSettingsAutoAdvanceOn => 'التشغيل التلقائي مفعّل';

  @override
  String get videoSettingsAutoAdvanceOff => 'التشغيل التلقائي متوقف';

  @override
  String get videoSettingsCaptionsOn => 'الترجمة مفعّلة';

  @override
  String get videoSettingsCaptionsOff => 'الترجمة متوقفة';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'التسميات التوضيحية مفعّلة لهذا الفيديو';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'التسميات التوضيحية معطّلة لهذا الفيديو';

  @override
  String get contentWarningLabel => 'تحذير محتوى';

  @override
  String get contentWarningNudity => 'عري';

  @override
  String get contentWarningSexualContent => 'محتوى جنسي';

  @override
  String get contentWarningPornography => 'إباحية';

  @override
  String get contentWarningGraphicMedia => 'محتوى مصور صادم';

  @override
  String get contentWarningViolence => 'عنف';

  @override
  String get contentWarningSelfHarm => 'إيذاء النفس';

  @override
  String get contentWarningDrugUse => 'تعاطي المخدرات';

  @override
  String get contentWarningAlcohol => 'كحول';

  @override
  String get contentWarningTobacco => 'تبغ';

  @override
  String get contentWarningGambling => 'قمار';

  @override
  String get contentWarningProfanity => 'ألفاظ نابية';

  @override
  String get contentWarningFlashingLights => 'أضواء وامضة';

  @override
  String get contentWarningAiGenerated => 'مُنشأ بالذكاء الاصطناعي';

  @override
  String get contentWarningSpoiler => 'حرق أحداث';

  @override
  String get contentWarningSensitiveContent => 'محتوى حساس';

  @override
  String get contentWarningDescNudity => 'يحتوي على عري كلي أو جزئي';

  @override
  String get contentWarningDescSexual => 'يحتوي على محتوى جنسي';

  @override
  String get contentWarningDescPorn => 'يحتوي على محتوى إباحي صريح';

  @override
  String get contentWarningDescGraphicMedia => 'يحتوي على صور صادمة أو مزعجة';

  @override
  String get contentWarningDescViolence => 'يحتوي على محتوى عنيف';

  @override
  String get contentWarningDescSelfHarm => 'يحتوي على إشارات لإيذاء النفس';

  @override
  String get contentWarningDescDrugs => 'يحتوي على محتوى متعلق بالمخدرات';

  @override
  String get contentWarningDescAlcohol => 'يحتوي على محتوى متعلق بالكحول';

  @override
  String get contentWarningDescTobacco => 'يحتوي على محتوى متعلق بالتبغ';

  @override
  String get contentWarningDescGambling => 'يحتوي على محتوى متعلق بالقمار';

  @override
  String get contentWarningDescProfanity => 'يحتوي على لغة قوية';

  @override
  String get contentWarningDescFlashingLights =>
      'يحتوي على أضواء وامضة (تحذير للحساسية الضوئية)';

  @override
  String get contentWarningDescAiGenerated =>
      'تم إنشاء هذا المحتوى بواسطة الذكاء الاصطناعي';

  @override
  String get contentWarningDescSpoiler => 'يحتوي على حرق أحداث';

  @override
  String get contentWarningDescContentWarning =>
      'صنّف الصانع هذا المحتوى بوصفه حساسًا';

  @override
  String get contentWarningDescDefault => 'وضع الصانع علامة على هذا المحتوى';

  @override
  String get contentWarningDetailsTitle => 'تحذيرات المحتوى';

  @override
  String get contentWarningDetailsSubtitle => 'طبّق الصانع هذه الوسوم:';

  @override
  String get contentWarningManageFilters => 'إدارة مرشّحات المحتوى';

  @override
  String get contentWarningViewAnyway => 'العرض على أي حال';

  @override
  String get contentWarningReportContentTooltip => 'الإبلاغ عن المحتوى';

  @override
  String get contentWarningBlockUserTooltip => 'حظر المستخدم';

  @override
  String get contentWarningBlockedTitle => 'تم حظر المحتوى';

  @override
  String get contentWarningBlockedPolicy =>
      'تم حظر هذا المحتوى بسبب مخالفات السياسة.';

  @override
  String get contentWarningNoticeTitle => 'تنبيه بشأن المحتوى';

  @override
  String get contentWarningPotentiallyHarmfulTitle => 'محتوى قد يكون ضارًّا';

  @override
  String get contentWarningView => 'عرض';

  @override
  String get contentWarningReportAction => 'إبلاغ';

  @override
  String get contentWarningHideAllLikeThis => 'إخفاء كل المحتوى المشابه';

  @override
  String get contentWarningNoFilterYet =>
      'لا يوجد مرشّح محفوظ لهذا التحذير بعد.';

  @override
  String get contentWarningHiddenConfirmation =>
      'سنخفي المنشورات المشابهة من الآن فصاعدًا.';

  @override
  String get communitySuggestTitle => 'ساعد في تصنيف هذا';

  @override
  String get communitySuggestSubtitle =>
      'تحذير محتوى مفقود؟ اقتراحك علني وموقَّع ولا يمكن التراجع عنه.';

  @override
  String get communitySuggestSubmit => 'اقترح';

  @override
  String get communitySuggestSuccess => 'شكرًا. تم إرسال اقتراحك.';

  @override
  String get communitySuggestFailure => 'تعذّر إرسال اقتراحك. حاول مرّة أخرى.';

  @override
  String get communitySuggestAlready => 'لقد اقترحت هذا';

  @override
  String get communitySuggestActionLabel => 'صنّف';

  @override
  String get videoErrorNotFound => 'لم يُعثر على الفيديو';

  @override
  String get videoErrorPlayback => 'خطأ في تشغيل الفيديو';

  @override
  String get videoErrorAgeRestricted => 'محتوى مقيّد بالعمر';

  @override
  String get videoErrorUnavailable => 'الفيديو غير متاح';

  @override
  String get videoErrorUnavailableBody => 'هذا الفيديو غير متاح الآن.';

  @override
  String get videoErrorRetry => 'إعادة المحاولة';

  @override
  String get videoErrorContentRestricted => 'المحتوى مقيّد';

  @override
  String get videoErrorContentRestrictedBody =>
      'تمت إزالة هذا الفيديو لمخالفته قواعد المحتوى لدينا.';

  @override
  String get videoErrorVerifyAgeBody => 'تحقّق من عمرك لعرض هذا الفيديو.';

  @override
  String get videoErrorSkip => 'تخطّي';

  @override
  String get videoErrorVerifyAgeButton => 'تحقّق من العمر';

  @override
  String get videoErrorVerifyAgeFailed =>
      'تعذّر التحقق من عمرك. يرجى المحاولة مرّة أخرى.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'انتهت مهلة التحقق. تحقّق من اتصالك أو حاول مرّة أخرى بعد قليل.';

  @override
  String get videoErrorAdultContentHiddenTitle => 'المحتوى للبالغين مُعطَّل';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'فعّله من مرشّحات المحتوى لمشاهدة هذا الفيديو.';

  @override
  String get videoErrorAdultContentHiddenAction => 'فتح مرشّحات المحتوى';

  @override
  String get videoDetailLoadError => 'فشل تحميل الفيديو';

  @override
  String get videoDetailLoadErrorBody => 'حدث خطأ ما في الطريق. جرّب مرة أخرى.';

  @override
  String get videoDetailNotFoundBody =>
      'قد يكون محذوفًا، أو بعيدًا عن متناولنا، أو مخفيًا بواسطة إعداداتك.';

  @override
  String get databaseCorruptionTitle => 'بياناتك المحلية تعرضت للتلف';

  @override
  String get databaseCorruptionBody =>
      'أغلق Divine وافتحه من جديد — سنصلح ذلك تلقائيًا. سنحفظ ما نستطيع من مسوداتك ومقاطعك، وسيُعاد تحميل الباقي.';

  @override
  String get databaseCorruptionCloseButton => 'إغلاق Divine';

  @override
  String get videoDetailContextTitle => 'فيديو تمت مشاركته';

  @override
  String get videoDetailCloseSemanticLabel => 'إغلاق مشغل الفيديو';

  @override
  String get videoFollowButtonFollow => 'متابعة';

  @override
  String get audioAttributionOriginalSound => 'صوت أصلي';

  @override
  String get audioAttributionUnavailableSound => 'الصوت غير متاح';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'مستوحى من @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'مستوحى من @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'مع @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'مع @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count متعاون',
      many: '$count متعاونًا',
      few: '$count متعاونين',
      two: 'متعاونان',
      one: 'متعاون واحد',
      zero: 'لا يوجد متعاونون',
    );
    return '$_temp0. انقر لعرض الملف الشخصي.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'قيد الانتظار';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'متعاون قيد الانتظار';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending قيد الانتظار)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. انقر لعرض الملف الشخصي.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. اضغط لعرض الفيديوهات بهذا الوسم.';
  }

  @override
  String get listAttributionFallback => 'قائمة';

  @override
  String get shareVideoLabel => 'مشاركة الفيديو';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'تمت مشاركة المنشور مع $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت مشاركة المنشور مع $count شخص',
      many: 'تمت مشاركة المنشور مع $count شخصًا',
      few: 'تمت مشاركة المنشور مع $count أشخاص',
      two: 'تمت مشاركة المنشور مع شخصين',
      one: 'تمت مشاركة المنشور مع شخص واحد',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'فشل إرسال الفيديو';

  @override
  String get shareAddedToBookmarks => 'تمت الإضافة إلى الإشارات المرجعية';

  @override
  String get shareRemovedFromBookmarks => 'تمت الإزالة من الإشارات المرجعية';

  @override
  String get shareFailedToAddBookmark => 'فشل إضافة الإشارة المرجعية';

  @override
  String get shareFailedToRemoveBookmark => 'فشل إزالة الإشارة المرجعية';

  @override
  String get shareActionFailed => 'فشل الإجراء';

  @override
  String get shareWithTitle => 'المشاركة مع';

  @override
  String get shareFindPeople => 'ابحث عن أشخاص';

  @override
  String get shareFindPeopleMultiline => 'ابحثعن أشخاص';

  @override
  String get shareSent => 'تم الإرسال';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return 'تم تحديد $name';
  }

  @override
  String get shareMessageHint => 'أضف رسالة اختيارية...';

  @override
  String get videoActionUnlike => 'إلغاء الإعجاب بالفيديو';

  @override
  String get videoActionLike => 'الإعجاب بالفيديو';

  @override
  String get videoActionAutoLabel => 'تلقائي';

  @override
  String get videoActionLikeLabel => 'إعجاب';

  @override
  String get videoActionReplyLabel => 'ردّ';

  @override
  String get videoActionRepostLabel => 'إعادة نشر';

  @override
  String get videoActionShareLabel => 'مشاركة';

  @override
  String get videoActionReportLabel => 'إبلاغ';

  @override
  String get videoActionReport => 'أبلِغ عن الفيديو';

  @override
  String get videoActionEditLabel => 'تعديل';

  @override
  String get videoActionEdit => 'عدّل الفيديو';

  @override
  String get videoActionAboutLabel => 'حول';

  @override
  String get videoActionEnableAutoAdvance => 'تفعيل التشغيل التلقائي';

  @override
  String get videoActionDisableAutoAdvance => 'تعطيل التشغيل التلقائي';

  @override
  String get videoActionRemoveRepost => 'إزالة إعادة النشر';

  @override
  String get videoActionRepost => 'إعادة نشر الفيديو';

  @override
  String get videoActionViewComments => 'عرض التعليقات';

  @override
  String get videoActionMoreOptions => 'خيارات إضافية';

  @override
  String get videoEngagementLikersTitle => 'أعجب به';

  @override
  String get videoEngagementRepostersTitle => 'أعاد نشره';

  @override
  String get videoEngagementLikersEmpty => 'لا توجد إعجابات بعد';

  @override
  String get videoEngagementRepostersEmpty => 'لا توجد إعادات نشر بعد';

  @override
  String get videoEngagementLoadFailed => 'تعذّر تحميل القائمة';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'فتح تفاصيل الفيديو';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'فتح تفاصيل الفيديو';

  @override
  String get videoOverlayCommentBarHint => 'أضف تعليقًا...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'أضف تعليقًا';

  @override
  String get videoOverlayCommentBarSendLabel => 'إرسال التعليق';

  @override
  String get videoOverlayCommentPostedSnackbar => 'تم نشر التعليق';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'تعذّر نشر التعليق';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تكرارات',
      one: 'تكرار',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'ليس Divine';

  @override
  String get metadataBadgeHumanMade => 'من صنع البشر';

  @override
  String get metadataSoundsLabel => 'أصوات';

  @override
  String get metadataOriginalSound => 'صوت أصلي';

  @override
  String get metadataVerificationLabel => 'التحقق';

  @override
  String get metadataDeviceAttestation => 'تصديق الجهاز';

  @override
  String get metadataPgpSignature => 'توقيع PGP';

  @override
  String get metadataC2paCredentials => 'بيانات اعتماد المحتوى C2PA';

  @override
  String get metadataProofManifest => 'بيان الإثبات';

  @override
  String get metadataVerificationInfoTooltip => 'ماذا تعني هذه الفحوصات؟';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'ماذا تعني هذه الفحوصات';

  @override
  String get metadataVerificationInfoIntro =>
      'تأتي هذه الإشارات من الكاميرا ومن ملف الفيديو نفسه. كلما حمل الفيديو عددًا أكبر منها، زاد ما يمكننا إثباته عن مصدره.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'ضمِن نظام تشغيل الهاتف التطبيق الذي سجّل هذا المقطع. دليل قوي على أنه جاء من كاميرا، لا من ملف رفعه أحدهم.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'وُقّع الفيديو تشفيريًا لحظة تصويره. غيّر إطارًا واحدًا بعد ذلك ينكسر التوقيع.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'سجل مصدر وفق معيار الصناعة يُحمل داخل الملف، فتستطيع تطبيقات غير Divine التحقق منه أيضًا.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'سجل ProofMode الكامل: بصمة الملف والطابع الزمني وسياق التصوير، مرفقة مع الفيديو.';

  @override
  String get metadataVerificationInfoFootnote =>
      'غياب فحص لا يجعل الفيديو مزيفًا. المقاطع القديمة والملفات المرفوعة لم تحصل عليه أصلًا، وهذا يعني فقط أننا لا نستطيع إثبات ذلك الجزء.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'اعرف المزيد على $url';
  }

  @override
  String get metadataCreatorLabel => 'الصانع';

  @override
  String get metadataCollaboratorsLabel => 'المتعاونون';

  @override
  String get metadataInspiredByLabel => 'مستوحى من';

  @override
  String get metadataRepostedByLabel => 'أعاد نشره';

  @override
  String metadataMoreReposters(int count) {
    return '+$count آخرين';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'التكرارات';
  }

  @override
  String get metadataLikesLabel => 'الإعجابات';

  @override
  String get metadataCommentsLabel => 'التعليقات';

  @override
  String get metadataRepostsLabel => 'إعادات النشر';

  @override
  String get metadataVineStatsLabel => 'على Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops تكرارات · $likes إعجابات · $comments تعليقات · $reposts إعادات نشر';
  }

  @override
  String get metadataDivineStatsLabel => 'على Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views مشاهدات · $likes إعجابات · $comments تعليقات · $reposts إعادات نشر';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'نُشر في $date';
  }

  @override
  String get devOptionsTitle => 'خيارات المطور';

  @override
  String get devOptionsDisableDeveloperMode => 'تعطيل وضع المطوّر';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'إخفاء خيارات المطوّر من الإعدادات';

  @override
  String get devOptionsDisableDeveloperModeToast => 'تم تعطيل وضع المطوّر';

  @override
  String get devOptionsShorebirdTitle => 'تصحيحات Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'التصحيح قيد التشغيل';

  @override
  String get devOptionsShorebirdNoPatch => 'لا يوجد تصحيح مثبّت';

  @override
  String get devOptionsShorebirdUnavailable => 'غير متاح في هذا الإصدار';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'تعمل التصحيحات فقط في إصدار تم إنشاؤه باستخدام shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'جارٍ قراءة حالة التصحيح…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'لم يتم التحقق من مسار الاختبار بعد.';

  @override
  String get devOptionsShorebirdCheck => 'التحقق من مسار الاختبار';

  @override
  String get devOptionsShorebirdApply => 'تطبيق تصحيح الاختبار';

  @override
  String get devOptionsShorebirdUseStable => 'العودة إلى التحديثات المستقرة';

  @override
  String get devOptionsShorebirdChecking => 'جارٍ التحقق من مسار الاختبار…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'يوجد تصحيح اختبار جاهز للتطبيق.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'لا يوجد تصحيح اختبار لهذا الإصدار.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'تم التنزيل. أعد تشغيل التطبيق لتحميله.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'التراجع جاهز. أعد التشغيل للعودة إلى الإصدار الأساسي.';

  @override
  String get devOptionsShorebirdApplying => 'جارٍ التنزيل والتثبيت…';

  @override
  String get devOptionsShorebirdApplied =>
      'تم التثبيت. أعد تشغيل التطبيق لتحميله.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'لم يتم تثبيت أي شيء. تحقق من مسار الاختبار وحاول مرة أخرى.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'جارٍ اختيار المسار المستقر…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'تم اختيار المسار المستقر. أعد تشغيل التطبيق للتحقق من وجود تصحيح مستقر.';

  @override
  String get devOptionsShorebirdFailure =>
      'لم تنجح العملية. تحقق من السجلات للحصول على التفاصيل.';

  @override
  String get devOptionsPageLoadTimes => 'أوقات تحميل الصفحات';

  @override
  String get devOptionsNoPageLoads =>
      'لم يتم تسجيل أي تحميل صفحة بعد.\nتنقّل في التطبيق لرؤية بيانات التوقيت.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'مرئي: $visibleMs ملليثانية  |  البيانات: $dataMs ملليثانية';
  }

  @override
  String get devOptionsSlowestScreens => 'أبطأ الشاشات';

  @override
  String get devOptionsVideoPlaybackFormat => 'تنسيق تشغيل الفيديو';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'تبديل البيئة؟';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'التبديل إلى $envName؟\n\nسيؤدي هذا إلى مسح بيانات الفيديو المخزّنة وإعادة الاتصال بالمحول الجديد.';
  }

  @override
  String get devOptionsCancel => 'إلغاء';

  @override
  String get devOptionsSwitch => 'تبديل';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'تم التبديل إلى $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'تم التبديل إلى $formatName — تم مسح الذاكرة المؤقتة';
  }

  @override
  String get featureFlagTitle => 'أعلام الميزات';

  @override
  String get featureFlagResetAllTooltip => 'إعادة جميع الأعلام إلى الافتراضي';

  @override
  String get featureFlagError => 'خطأ';

  @override
  String get relaySettingsTitle => 'المحولات';

  @override
  String get relaySettingsInfoTitle =>
      'Divine نظام مفتوح - أنت تتحكم في اتصالاتك';

  @override
  String get relaySettingsInfoDescription =>
      'هذه المحولات توزّع محتواك عبر شبكة Nostr اللامركزية. يمكنك إضافة أو إزالة المحولات كما ترغب.';

  @override
  String get relaySettingsLearnMoreNostr => 'اعرف المزيد عن Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'اعثر على محولات عامة في nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'التطبيق غير فعّال';

  @override
  String get relaySettingsRequiresRelay =>
      'يتطلب Divine محولًا واحدًا على الأقل لتحميل الفيديوهات ونشر المحتوى ومزامنة البيانات.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'استعادة المحول الافتراضي';

  @override
  String get relaySettingsAddCustomRelay => 'إضافة محول مخصّص';

  @override
  String get relaySettingsAddRelay => 'إضافة محول';

  @override
  String get relaySettingsRetry => 'إعادة المحاولة';

  @override
  String get relaySettingsNoStats => 'لا توجد إحصائيات متاحة بعد';

  @override
  String get relaySettingsConnection => 'الاتصال';

  @override
  String get relaySettingsConnected => 'متصل';

  @override
  String get relaySettingsDisconnected => 'غير متصل';

  @override
  String get relaySettingsSessionDuration => 'مدة الجلسة';

  @override
  String get relaySettingsLastConnected => 'آخر اتصال';

  @override
  String get relaySettingsDisconnectedLabel => 'غير متصل';

  @override
  String get relaySettingsReason => 'السبب';

  @override
  String get relaySettingsActiveSubscriptions => 'الاشتراكات النشطة';

  @override
  String get relaySettingsTotalSubscriptions => 'إجمالي الاشتراكات';

  @override
  String get relaySettingsEventsReceived => 'الأحداث الواردة';

  @override
  String get relaySettingsEventsSent => 'الأحداث المرسلة';

  @override
  String get relaySettingsRequestsThisSession => 'الطلبات في هذه الجلسة';

  @override
  String get relaySettingsFailedRequests => 'الطلبات الفاشلة';

  @override
  String get relaySettingsLoadingRelayInfo => 'جاري تحميل معلومات المحول...';

  @override
  String get relaySettingsAboutRelay => 'عن المحول';

  @override
  String get relaySettingsSupportedNips => 'NIPs المدعومة';

  @override
  String get relaySettingsSoftware => 'البرنامج';

  @override
  String get relaySettingsViewWebsite => 'عرض الموقع';

  @override
  String get relaySettingsRemoveRelayTitle => 'إزالة المحول؟';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'هل أنت متأكد من رغبتك في إزالة هذا المحول؟\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'إزالة محوّل Divine؟';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'إزالة محوّل Divine ستضعف تجربتك في التطبيق. قد تصبح الفيديوهات والنشر والمزامنة أقل موثوقية. يُفضّل ألا يفعل ذلك إلا مستخدمو Nostr ذوو الخبرة.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'إزالة المحوّل';

  @override
  String get relaySettingsCancel => 'إلغاء';

  @override
  String get relaySettingsRemove => 'إزالة';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'تم إزالة المحول: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'فشل إزالة المحول';

  @override
  String get relaySettingsForcingReconnection =>
      'جاري فرض إعادة اتصال المحول...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'تم الاتصال بـ $count محول!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'فشل الاتصال بالمحولات. يرجى التحقق من اتصال الشبكة.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'تم الحفظ على هذا الجهاز. سنزامنه مع حسابك عندما يعمل النشر مرة أخرى.';

  @override
  String get relaySettingsAddRelayTitle => 'إضافة محول';

  @override
  String get relaySettingsAddRelayPrompt =>
      'أدخل رابط WebSocket للمحول الذي تريد إضافته:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'تصفّح المحولات العامة في nostr.co.uk';

  @override
  String get relaySettingsAdd => 'إضافة';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'تمت إضافة المحول: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'فشلت إضافة المحول. تحقّق من الرابط وحاول مرّة أخرى.';

  @override
  String get relaySettingsInvalidUrl =>
      'يجب أن يبدأ رابط المحول بـ wss:// أو ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'يجب أن يستخدم رابط المحول wss:// (يُسمح بـ ws:// لـ localhost فقط)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'تمت استعادة المحول الافتراضي: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'فشلت استعادة المحول الافتراضي. تحقّق من اتصال الشبكة.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'تعذّر فتح المتصفح';

  @override
  String get relaySettingsFailedToOpenLink => 'تعذّر فتح الرابط';

  @override
  String get relaySettingsExternalRelay => 'محول خارجي';

  @override
  String get relaySettingsNotConnected => 'غير متصل';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'انقطع منذ $duration';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count اشتراك';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count حدث';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'منذ $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'يستخدم Divine بروتوكول Nostr للنشر اللامركزي. يعيش محتواك على المحولات التي تختارها، ومفاتيحك هي هويتك.';

  @override
  String get nostrSettingsSectionNetwork => 'الشبكة';

  @override
  String get nostrSettingsSectionAccount => 'الحساب';

  @override
  String get nostrSettingsSectionDangerZone => 'منطقة الخطر';

  @override
  String get nostrSettingsRelays => 'المحولات';

  @override
  String get nostrSettingsRelaysSubtitle => 'أدر اتصالات محولات Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'تشخيص المحولات';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'تصحيح اتصال المحولات ومشكلات الشبكة';

  @override
  String get nostrSettingsMediaServers => 'خوادم الوسائط';

  @override
  String get nostrSettingsMediaServersSubtitle => 'إعداد خوادم الرفع Blossom';

  @override
  String get settingsDeveloperOptions => 'خيارات المطوّر';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'مبدّل البيئة وإعدادات التصحيح';

  @override
  String get nostrSettingsKeyManagement => 'إدارة المفاتيح';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'تصدير مفاتيح Nostr ونسخها واستعادتها';

  @override
  String get nostrSettingsClientAttribution => 'إسناد العميل';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'أضِف وسم عميل Divine إلى الأحداث التي تنشرها حتى تتمكن تطبيقات Nostr الأخرى من إسنادها بشكل صحيح. بدونه، تحمل البلاغات التي ترسلها وزنًا أقل عند مراجعتها من مشرفينا.';

  @override
  String get nostrSettingsMoveAccount => 'نقل حسابك';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'نزّل أرشيفك وانقل منشوراتك ومقاطع الفيديو الخاصة بك إلى مرحّل أو خادم وسائط آخر.';

  @override
  String get nostrSettingsRemoveKeys => 'إزالة المفاتيح من الجهاز';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'احذف مفتاحك الخاص من هذا الجهاز فقط. سيبقى محتواك على المحولات، لكنّك ستحتاج إلى نسخة nsec الاحتياطية للوصول إلى حسابك مرّة أخرى.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'تعذّرت إزالة هذا الحساب من هذا الجهاز. حاول مرّة أخرى.';

  @override
  String get nostrSettingsDeleteAccount => 'حذف الحساب والبيانات';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'يرسل طلبات حذف لمحتواك ويسجّل خروجك من هذا الجهاز. قد تحتفظ المحوّلات والعملاء وفهارس البحث والأجهزة الأخرى المسجّلة الدخول بنسخ.';

  @override
  String get relayDiagnosticTitle => 'تشخيص المحول';

  @override
  String get relayDiagnosticRefreshTooltip => 'تحديث التشخيص';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'آخر تحديث: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'حالة المحول';

  @override
  String get relayDiagnosticInitialized => 'تمت التهيئة';

  @override
  String get relayDiagnosticReady => 'جاهز';

  @override
  String get relayDiagnosticNotInitialized => 'غير مهيأ';

  @override
  String get relayDiagnosticDatabaseEvents => 'أحداث قاعدة البيانات';

  @override
  String get relayDiagnosticActiveSubscriptions => 'الاشتراكات النشطة';

  @override
  String get relayDiagnosticExternalRelays => 'المحولات الخارجية';

  @override
  String get relayDiagnosticConfigured => 'مُعدّات';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count محول';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'متصل';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'أحداث الفيديو';

  @override
  String get relayDiagnosticHomeFeed => 'التغذية الرئيسية';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count فيديو';
  }

  @override
  String get relayDiagnosticDiscovery => 'اكتشاف';

  @override
  String get relayDiagnosticLoading => 'جاري التحميل';

  @override
  String get relayDiagnosticYes => 'نعم';

  @override
  String get relayDiagnosticNo => 'لا';

  @override
  String get relayDiagnosticTestDirectQuery => 'اختبار استعلام مباشر';

  @override
  String get relayDiagnosticNetworkConnectivity => 'اتصال الشبكة';

  @override
  String get relayDiagnosticRunNetworkTest => 'تشغيل اختبار الشبكة';

  @override
  String get relayDiagnosticBlossomServer => 'خادم Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'اختبار جميع نقاط النهاية';

  @override
  String get relayDiagnosticStatus => 'الحالة';

  @override
  String get relayDiagnosticUrl => 'الرابط';

  @override
  String get relayDiagnosticError => 'خطأ';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'الرابط الأساسي';

  @override
  String get relayDiagnosticSummary => 'الملخص';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount على ما يرام (المتوسط $avgMs ملليثانية)';
  }

  @override
  String get relayDiagnosticRetestAll => 'إعادة اختبار الكل';

  @override
  String get relayDiagnosticRetrying => 'جاري إعادة المحاولة...';

  @override
  String get relayDiagnosticRetryConnection => 'إعادة محاولة الاتصال';

  @override
  String get relayDiagnosticTroubleshooting => 'استكشاف الأخطاء';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• حالة خضراء = متصل ويعمل\n• حالة حمراء = فشل الاتصال\n• إذا فشل اختبار الشبكة، تحقّق من اتصال الإنترنت\n• إذا كانت المحولات مُعدّة وليست متصلة، انقر على \"إعادة محاولة الاتصال\"\n• التقط صورة لهذه الشاشة للتصحيح';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'جميع نقاط نهاية REST سليمة!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'فشلت بعض نقاط نهاية REST - انظر التفاصيل أعلاه';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'تم العثور على $count حدث فيديو في قاعدة البيانات';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'فشل الاستعلام. يرجى المحاولة مرّة أخرى.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'تم الاتصال بـ $count محول!';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'فشل الاتصال بأي محول';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'فشلت إعادة محاولة الاتصال. يرجى المحاولة مرّة أخرى.';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'متصل ومُصادَق عليه';

  @override
  String get relayDiagnosticConnectedOnly => 'متصل';

  @override
  String get relayDiagnosticNotConnected => 'غير متصل';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'لا توجد محولات مُعدّة';

  @override
  String get relayDiagnosticFailed => 'فشل';

  @override
  String get notificationSettingsTitle => 'الإشعارات';

  @override
  String get notificationSettingsResetTooltip => 'إعادة الضبط الافتراضي';

  @override
  String get notificationSettingsTypes => 'أنواع الإشعارات';

  @override
  String get notificationSettingsLikes => 'الإعجابات';

  @override
  String get notificationSettingsLikesSubtitle => 'عندما يعجب أحدهم بفيديوهاتك';

  @override
  String get notificationSettingsComments => 'التعليقات';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'عندما يعلّق أحدهم على فيديوهاتك';

  @override
  String get notificationSettingsFollows => 'المتابعون';

  @override
  String get notificationSettingsFollowsSubtitle => 'عندما يتابعك أحدهم';

  @override
  String get notificationSettingsMentions => 'الإشارات';

  @override
  String get notificationSettingsMentionsSubtitle => 'عندما تتم الإشارة إليك';

  @override
  String get notificationSettingsReposts => 'إعادات النشر';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'عندما يعيد أحدهم نشر فيديوهاتك';

  @override
  String get notificationSettingsNewPosts => 'مقاطع جديدة';

  @override
  String get notificationSettingsNewPostsSubtitle => 'عندما ينشر شخص تتابعه';

  @override
  String get notificationSettingsActions => 'الإجراءات';

  @override
  String get notificationSettingsMarkAllAsRead => 'وسم الكل كمقروء';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'وسم جميع الإشعارات كمقروءة';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'تم وسم جميع الإشعارات كمقروءة';

  @override
  String get notificationSettingsMarkAllAsReadFailed => 'تعذّر وسم الكل كمقروء';

  @override
  String get notificationSettingsResetToDefaults =>
      'تمت إعادة الإعدادات إلى الافتراضي';

  @override
  String get notificationSettingsAbout => 'عن الإشعارات';

  @override
  String get notificationSettingsAboutDescription =>
      'الإشعارات مدعومة ببروتوكول Nostr. التحديثات الفورية تعتمد على اتصالك بمحولات Nostr. قد تواجه بعض الإشعارات تأخيرًا.';

  @override
  String get safetySettingsWhatYouSee => 'ما تراه';

  @override
  String get safetySettingsWhatYouPublish => 'ما تنشره';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'عرض الفيديوهات المستضافة على Divine فقط';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'إخفاء الفيديوهات المقدّمة من مصادر أخرى';

  @override
  String get safetySettingsModeration => 'الإشراف';

  @override
  String get safetySettingsBlockedUsers => 'المستخدمون المحظورون';

  @override
  String get safetySettingsAgeVerification => 'التحقق من العمر';

  @override
  String get safetySettingsAgeConfirmation =>
      'أؤكّد أنّي في الثامنة عشرة من عمري أو أكبر';

  @override
  String get safetySettingsAgeRequired => 'مطلوب لعرض المحتوى للبالغين';

  @override
  String get safetySettingsAgeLockedForMinor => 'مقفل لحسابك';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'خدمة الإشراف الرسمية (مُفعّلة افتراضيًا)';

  @override
  String get safetySettingsPeopleIFollow => 'الأشخاص الذين أتابعهم';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'اشترك في الوسوم من الأشخاص الذين تتابعهم';

  @override
  String get safetySettingsAddCustomLabeler => 'إضافة واسم مخصّص';

  @override
  String get safetySettingsAddCustomLabelerHint => 'أدخل npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'إضافة واسم مخصّص';

  @override
  String get safetySettingsRemoveLabeler => 'إزالة الواسم';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'أدخل عنوان npub';

  @override
  String get safetySettingsNoBlockedUsers => 'لا يوجد مستخدمون محظورون';

  @override
  String get safetySettingsUnblock => 'إلغاء الحظر';

  @override
  String get safetySettingsUserUnblocked => 'تم إلغاء حظر المستخدم';

  @override
  String get safetySettingsCancel => 'إلغاء';

  @override
  String get safetySettingsAdd => 'إضافة';

  @override
  String get analyticsTitle => 'تحليلات الصانع';

  @override
  String get analyticsDiagnosticsTooltip => 'التشخيص';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'تبديل التشخيص';

  @override
  String get analyticsRetry => 'إعادة المحاولة';

  @override
  String get analyticsUnableToLoad => 'تعذّر تحميل التحليلات.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired => 'سجل الدخول لعرض تحليلات الصانع.';

  @override
  String get analyticsViewDataUnavailable =>
      'المشاهدات غير متاحة حاليًا من المحول لهذه المنشورات. مقاييس الإعجاب والتعليق وإعادة النشر لا تزال دقيقة.';

  @override
  String get analyticsViewDataTitle => 'بيانات المشاهدة';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'آخر تحديث $time • تستخدم الدرجات الإعجابات والتعليقات وإعادات النشر والمشاهدات/التكرارات من Funnelcake عند التوفر.';
  }

  @override
  String get analyticsVideos => 'الفيديوهات';

  @override
  String get analyticsViews => 'المشاهدات';

  @override
  String get analyticsInteractions => 'التفاعلات';

  @override
  String get analyticsEngagement => 'التفاعل';

  @override
  String get analyticsFollowers => 'المتابِعون';

  @override
  String get analyticsAvgPerPost => 'المتوسط/منشور';

  @override
  String get analyticsInteractionMix => 'مزيج التفاعلات';

  @override
  String get analyticsLikes => 'الإعجابات';

  @override
  String get analyticsComments => 'التعليقات';

  @override
  String get analyticsReposts => 'إعادات النشر';

  @override
  String get analyticsPerformanceHighlights => 'أبرز لحظات الأداء';

  @override
  String get analyticsMostViewed => 'الأكثر مشاهدة';

  @override
  String get analyticsMostDiscussed => 'الأكثر نقاشًا';

  @override
  String get analyticsMostReposted => 'الأكثر إعادة نشر';

  @override
  String get analyticsNoVideosYet => 'لا توجد فيديوهات بعد';

  @override
  String get analyticsViewDataUnavailableShort => 'بيانات المشاهدة غير متاحة';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count مشاهدة';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count تعليق';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count إعادة نشر';
  }

  @override
  String get analyticsTopContent => 'أفضل المحتوى';

  @override
  String get analyticsPublishPrompt => 'انشر بعض الفيديوهات لرؤية الترتيبات.';

  @override
  String get analyticsEngagementRateExplainer =>
      'النسبة المئوية على الجانب الأيمن = معدل التفاعل (التفاعلات مقسومة على المشاهدات).';

  @override
  String get analyticsEngagementRateNoViews =>
      'معدل التفاعل يتطلب بيانات المشاهدة؛ ستظهر القيم باسم غير متوفر حتى تتوفر المشاهدات.';

  @override
  String get analyticsEngagementLabel => 'التفاعل';

  @override
  String get analyticsViewsUnavailable => 'المشاهدات غير متاحة';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count تفاعل';
  }

  @override
  String get analyticsPostAnalytics => 'تحليلات المنشور';

  @override
  String get analyticsOpenPost => 'فتح المنشور';

  @override
  String get analyticsRecentDailyInteractions => 'التفاعلات اليومية الأخيرة';

  @override
  String get analyticsNoActivityYet => 'لا يوجد نشاط في هذه الفترة بعد.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'التفاعلات = الإعجابات + التعليقات + إعادات النشر حسب تاريخ المنشور.';

  @override
  String get analyticsDailyBarExplainer =>
      'طول الشريط نسبي لأعلى يوم في هذه النافذة.';

  @override
  String get analyticsAudienceSnapshot => 'لمحة عن الجمهور';

  @override
  String analyticsFollowersCount(String count) {
    return 'المتابِعون: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'يتابِع: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'ستظهر تفاصيل مصدر الجمهور والموقع الجغرافي والوقت عندما يضيف Funnelcake نقاط نهاية تحليلات الجمهور.';

  @override
  String get analyticsRetention => 'الاحتفاظ';

  @override
  String get analyticsRetentionWithViews =>
      'ستظهر منحنى الاحتفاظ وتفاصيل وقت المشاهدة عندما تصل بيانات الاحتفاظ التفصيلية من Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'بيانات الاحتفاظ غير متاحة حتى تعود تحليلات المشاهدات ووقت المشاهدة من Funnelcake.';

  @override
  String get analyticsDiagnostics => 'التشخيص';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'إجمالي الفيديوهات: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'بمشاهدات: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'بدون مشاهدات: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'مجلوب (دفعة): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'مجلوب (/مشاهدات): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'المصادر: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'استخدام بيانات وهمية';

  @override
  String get analyticsNa => 'غير متوفر';

  @override
  String get authCreateNewAccount => 'إنشاء حساب Divine جديد';

  @override
  String get authCreateNewAccountShort => 'إنشاء حساب جديد';

  @override
  String get authSignInDifferentAccount => 'تسجيل الدخول بحساب آخر';

  @override
  String get authUseAnotherAccount => 'استخدام حساب آخر';

  @override
  String authContinueAs(String displayName) {
    return 'المتابعة باسم $displayName';
  }

  @override
  String get authRecoveryDraftsOwner => 'مسوداتك ومقاطعك محفوظة لهذا الحساب';

  @override
  String get authRecoveryOtherAccountWarning =>
      'تسجيل الدخول هنا سيُخفي تلك المسودات والمقاطع';

  @override
  String get authTermsPrefix =>
      'باختيارك أحد الخيارات أدناه، فإنك تؤكد أن عمرك 16 عامًا على الأقل (أو أنك أكملت ';

  @override
  String get authTermsAgeAuthorizationCta => 'تفويض العمر من Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') وتوافق على ';

  @override
  String get authTermsOfService => 'شروط الخدمة';

  @override
  String get authPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get authTermsAnd => '، و';

  @override
  String get authSafetyStandards => 'معايير الأمان';

  @override
  String get authAmberNotInstalled => 'تطبيق Amber غير مثبّت';

  @override
  String get authAmberConnectionFailed => 'فشل الاتصال بـ Amber';

  @override
  String get authPasswordResetSent =>
      'إذا كان هناك حساب بهذا البريد، فسيتم إرسال رابط إعادة تعيين كلمة المرور.';

  @override
  String get authSignInTitle => 'تسجيل الدخول';

  @override
  String get authEmailLabel => 'البريد الإلكتروني';

  @override
  String get authPasswordLabel => 'كلمة المرور';

  @override
  String get authConfirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get authEmailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get authEmailInvalid => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get authPasswordRequired => 'كلمة المرور مطلوبة';

  @override
  String get authConfirmPasswordRequired => 'أكّد كلمة المرور';

  @override
  String get authPasswordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authImportNostrKey => 'استيراد مفتاح Nostr';

  @override
  String get authConnectSignerApp => 'الاتصال بتطبيق توقيع';

  @override
  String get authSignInWithAmber => 'تسجيل الدخول بـ Amber';

  @override
  String get authSignInWithBrowserExtension => 'تسجيل الدخول بإضافة المتصفح';

  @override
  String get authNip07ConnectionFailed => 'تعذّر الاتصال بإضافة المتصفح.';

  @override
  String get authNip07ExtensionNotFound =>
      'لم يتم العثور على إضافة متصفح. ثبّت Alby أو nos2x أو أي إضافة متوافقة مع NIP-07.';

  @override
  String get authSignInOptionsTitle => 'خيارات تسجيل الدخول';

  @override
  String get authInfoEmailPasswordTitle => 'بريد إلكتروني وكلمة مرور';

  @override
  String get authInfoEmailPasswordDescription =>
      'سجّل الدخول بحساب Divine الخاص بك. إذا سجّلت ببريد وكلمة مرور، استخدمهما هنا.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'لديك هوية Nostr بالفعل؟ استورد مفتاح nsec الخاص بك من تطبيق آخر.';

  @override
  String get authInfoSignerAppTitle => 'تطبيق توقيع';

  @override
  String get authInfoSignerAppDescription =>
      'اتصل باستخدام موقّع خارجي متوافق مع NIP-46 مثل nsecBunker لأمان مفاتيح أفضل.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'استخدم تطبيق توقيع Amber على أندرويد لإدارة مفاتيح Nostr الخاصة بك بأمان.';

  @override
  String get authInfoBrowserExtensionTitle => 'إضافة المتصفح';

  @override
  String get authInfoBrowserExtensionDescription =>
      'سجّل الدخول باستخدام إضافة متصفح NIP-07 مثل Alby أو nos2x. تبقى مفاتيحك داخل الإضافة — Divine لا يراها أبدًا.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة. حاول مرة أخرى.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'تحقق من بريدك الإلكتروني قبل تسجيل الدخول — راجع صندوق الوارد للحصول على الرابط.';

  @override
  String get authSignInErrorInvalidEmail =>
      'لا يبدو هذا عنوان بريد إلكتروني صالحًا.';

  @override
  String get authSignInErrorNetwork =>
      'تعذّر الوصول إلى الخادم. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get authSignInErrorGeneric => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get authSignInOptionsHintPrefix =>
      'لست متأكدًا كيف سجّلت الدخول آخر مرة؟ ';

  @override
  String get authSignInOptionsHintCta => 'عرض جميع خيارات تسجيل الدخول';

  @override
  String get authCreateAccountTitle => 'إنشاء حساب';

  @override
  String get authBackToInviteCode => 'العودة إلى رمز الدعوة';

  @override
  String get authUseDivineNoBackup => 'استخدم Divine بدون نسخة احتياطية';

  @override
  String get authSkipConfirmTitle => 'أمر أخير...';

  @override
  String get authSkipConfirmKeyCreated =>
      'أنت في الداخل! سننشئ مفتاحًا آمنًا يشغّل حسابك في Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'بدون بريد إلكتروني، مفتاحك هو الطريقة الوحيدة ليعرف Divine أن هذا الحساب لك.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'يمكنك الوصول إلى مفتاحك في التطبيق، لكن إذا لم تكن ملمًا بالتقنية، نوصي بإضافة بريد وكلمة مرور الآن. سيجعل ذلك تسجيل الدخول واستعادة حسابك أسهل إذا فقدت هذا الجهاز أو أعدت ضبطه.';

  @override
  String get authAddEmailPassword => 'إضافة بريد وكلمة مرور';

  @override
  String get authUseThisDeviceOnly => 'استخدم هذا الجهاز فقط';

  @override
  String get authCompleteRegistration => 'أكمل تسجيلك';

  @override
  String get authVerifying => 'جاري التحقق...';

  @override
  String get authVerificationLinkSent => 'أرسلنا رابط تحقق إلى:';

  @override
  String get authClickVerificationLink =>
      'يرجى النقر على الرابط في بريدك الإلكتروني\nلإكمال التسجيل.';

  @override
  String get authPleaseWaitVerifying =>
      'يرجى الانتظار بينما نتحقّق من بريدك...';

  @override
  String get authWaitingForVerification => 'في انتظار التحقق';

  @override
  String get authOpenEmailApp => 'فتح تطبيق البريد';

  @override
  String get authVerificationPinPrompt =>
      'أو أدخل الرمز المكوّن من 6 أرقام من بريدك الإلكتروني';

  @override
  String get authVerificationPinFieldLabel => 'الرمز المكوّن من 6 أرقام';

  @override
  String get authVerificationPinSubmit => 'تحقّق من الرمز';

  @override
  String get authVerificationResendPrompt => 'لم يصلك؟';

  @override
  String get authVerificationResend => 'إعادة الإرسال';

  @override
  String authVerificationResendCooldown(String time) {
    return 'إعادة الإرسال بعد $time';
  }

  @override
  String get authVerificationResendFailed =>
      'تعذّر علينا إعادة إرسال البريد الإلكتروني. حاول مرّة أخرى.';

  @override
  String get authVerificationResendExpired =>
      'انتهت صلاحية هذا التسجيل. ابدأ من جديد للحصول على رمز جديد.';

  @override
  String get authVerificationResendUnavailable =>
      'إعادة الإرسال غير متاحة الآن. استخدم الرمز المكوّن من 6 أرقام من البريد الذي أرسلناه لك بالفعل.';

  @override
  String get authVerificationPollingStopped =>
      'توقفنا عن التحقق نيابةً عنك. أدخل الرمز المكوّن من 6 أرقام من بريدك لإكمال تسجيل الدخول.';

  @override
  String get authWelcomeToDivine => 'أهلاً بك في Divine!';

  @override
  String get authEmailVerified => 'تم التحقق من بريدك الإلكتروني.';

  @override
  String get authSigningYouIn => 'جاري تسجيل دخولك';

  @override
  String get authErrorTitle => 'عفوًا.';

  @override
  String get authVerificationFailed =>
      'فشلنا في التحقق من بريدك.\nحاول مرّة أخرى.';

  @override
  String get authStartOver => 'البدء من جديد';

  @override
  String get authEmailVerifiedLogin =>
      'تم التحقق من البريد! يرجى تسجيل الدخول للمتابعة.';

  @override
  String get authVerificationLinkExpired => 'رابط التحقق هذا لم يعد صالحًا.';

  @override
  String get authVerificationConnectionError =>
      'تعذّر التحقق من البريد. تحقّق من اتصالك وحاول مرّة أخرى.';

  @override
  String get authWaitlistConfirmTitle => 'أنت في الداخل!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'سنشارك التحديثات على $email.\nعندما تتوفر رموز دعوة إضافية، سنرسلها إليك.';
  }

  @override
  String get authOk => 'حسنًا';

  @override
  String get authTryAgain => 'حاول مرّة أخرى';

  @override
  String get authContactSupport => 'اتصل بالدعم';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'تعذّر فتح $email';
  }

  @override
  String get authAddInviteCode => 'أضف رمز الدعوة الخاص بك';

  @override
  String get authInviteCodeLabel => 'رمز الدعوة';

  @override
  String get authEnterYourCode => 'أدخل رمزك';

  @override
  String get authNext => 'التالي';

  @override
  String get authJoinWaitlist => 'انضم لقائمة الانتظار';

  @override
  String get authJoinWaitlistTitle => 'انضم إلى قائمة الانتظار';

  @override
  String get authJoinWaitlistDescription =>
      'شاركنا بريدك وسنرسل لك التحديثات عند فتح الوصول.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'أرسل لي إلهام Divine';

  @override
  String get authInviteAccessHelp => 'مساعدة وصول الدعوة';

  @override
  String get authGeneratingConnection => 'جاري إنشاء الاتصال...';

  @override
  String get authConnectedAuthenticating => 'تم الاتصال! جاري المصادقة...';

  @override
  String get authConnectionTimedOut => 'انتهت مهلة الاتصال';

  @override
  String get authApproveConnection =>
      'تأكد أنّك وافقت على الاتصال في تطبيق التوقيع الخاص بك.';

  @override
  String get authConnectionCancelled => 'تم إلغاء الاتصال';

  @override
  String get authConnectionCancelledMessage => 'تم إلغاء الاتصال.';

  @override
  String get authConnectionFailed => 'فشل الاتصال';

  @override
  String get authUnknownError => 'حدث خطأ غير معروف.';

  @override
  String get authNostrConnectStartFailed =>
      'تعذّر الوصول إلى تطبيق التوقيع. تحقّق من اتصالك وحاول مرّة أخرى.';

  @override
  String get authNostrConnectInvalidSession =>
      'لم يعد رابط الاتصال هذا صالحًا. أنشئ رابطًا جديدًا.';

  @override
  String get authNostrConnectSetupFailed =>
      'اقتربنا — لكن لم نتمكّن من إتمام تسجيل دخولك. حاول مرّة أخرى.';

  @override
  String get authUrlCopied => 'تم نسخ الرابط إلى الحافظة';

  @override
  String get authConnectToDivine => 'الاتصال بـ Divine';

  @override
  String get authPasteBunkerUrl => 'الصق رابط bunker://';

  @override
  String get authBunkerUrlHint => 'رابط bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'رابط bunker غير صالح. يجب أن يبدأ بـ bunker://';

  @override
  String get authScanSignerApp => 'امسح بتطبيق التوقيع الخاص بك\nللاتصال.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'في انتظار الاتصال... $seconds ث';
  }

  @override
  String get authCopyUrl => 'نسخ الرابط';

  @override
  String get authShare => 'مشاركة';

  @override
  String get authAddBunker => 'إضافة bunker';

  @override
  String get authCompatibleSignerApps => 'تطبيقات توقيع متوافقة';

  @override
  String get authFailedToConnect => 'فشل الاتصال';

  @override
  String get authResetPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get authResetPasswordSubtitle =>
      'يرجى إدخال كلمة المرور الجديدة. يجب ألّا تقل عن 8 أحرف.';

  @override
  String get authNewPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get authConfirmNewPasswordLabel => 'تأكيد كلمة المرور الجديدة';

  @override
  String get authPasswordTooShort => 'يجب ألّا تقل كلمة المرور عن 8 أحرف';

  @override
  String get authPasswordResetSuccess =>
      'تمت إعادة تعيين كلمة المرور بنجاح. يرجى تسجيل الدخول.';

  @override
  String get authPasswordResetFailed => 'فشل إعادة تعيين كلمة المرور';

  @override
  String get authUnexpectedError => 'حدث خطأ غير متوقّع. حاول مرّة أخرى.';

  @override
  String get authUpdatePassword => 'تحديث كلمة المرور';

  @override
  String get authSecureAccountTitle => 'حساب آمن';

  @override
  String get authUnableToAccessKeys =>
      'تعذّر الوصول إلى مفاتيحك. حاول مرّة أخرى.';

  @override
  String get authRegistrationFailed => 'فشل التسجيل';

  @override
  String get authRegistrationComplete =>
      'تم التسجيل. يرجى تفقّد بريدك الإلكتروني.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'فشل إرسال بريد إعادة التعيين.';

  @override
  String get authSending => 'جاري الإرسال...';

  @override
  String get authSignInButton => 'تسجيل الدخول';

  @override
  String get authVerificationErrorTimeout =>
      'انتهت مهلة التحقق. حاول التسجيل مرّة أخرى.';

  @override
  String get authVerificationErrorMissingCode =>
      'فشل التحقق — رمز التفويض مفقود.';

  @override
  String get authVerificationErrorPollFailed => 'فشل التحقق. حاول مرّة أخرى.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'خطأ في الشبكة أثناء تسجيل الدخول. حاول مرّة أخرى.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'فشل التحقق. حاول التسجيل مرّة أخرى.';

  @override
  String get authVerificationErrorSignInFailed =>
      'فشل تسجيل الدخول. حاول تسجيل الدخول يدويًا.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'هذا البريد الإلكتروني مسجل بالفعل. سجّل الدخول بدلًا من ذلك.';

  @override
  String get authVerificationErrorPinInvalid =>
      'هذا الرمز غير مطابق. تحقّق منه مجددًا وحاول مرّة أخرى.';

  @override
  String get authVerificationErrorPinExpired =>
      'انتهت صلاحية هذا الرمز. اضغط «إعادة الإرسال» للحصول على رمز جديد.';

  @override
  String get authVerificationErrorPinLocked =>
      'محاولات كثيرة جدًا. اضغط «إعادة الإرسال» للحصول على رمز جديد.';

  @override
  String get authVerificationErrorPinFailed =>
      'تعذّر علينا التحقق من هذا الرمز. يرجى المحاولة مرّة أخرى.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'إدخال الرمز غير متاح حاليًا. اضغط على الرابط في بريدك الإلكتروني، أو أعد الإرسال للحصول على رمز جديد.';

  @override
  String get authInviteCodeErrorMalformed => 'أدخل رمز دعوة مثل ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound => 'رمز الدعوة هذا لا يبدو صالحًا.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'تم استخدام رمز الدعوة هذا أو إلغاؤه.';

  @override
  String get authInviteGateErrorCreatorFull => 'نفدت دعوات هذا المنشئ';

  @override
  String get authInviteGateErrorUnavailable =>
      'رمز الدعوة هذا غير متاح. انضم إلى قائمة الانتظار وسنرسل دعوة عند توفر مكان.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'تعذّر التحقق من هذا الرمز. حاول مرة أخرى.';

  @override
  String get authInviteGateErrorUnknown =>
      'حدث خطأ ما. حاول إدخال رمز الدعوة مرة أخرى.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'رمز الدعوة هذا لم يعد متاحًا. عد إلى رمز دعوتك، انضم لقائمة الانتظار، أو تواصل مع الدعم.';

  @override
  String get authInviteErrorInvalid =>
      'رمز الدعوة هذا لا يمكن استخدامه الآن. عد إلى رمز دعوتك، انضم لقائمة الانتظار، أو تواصل مع الدعم.';

  @override
  String get authInviteErrorTemporary =>
      'لم نتمكّن من تأكيد دعوتك الآن. عد إلى رمز دعوتك وحاول مرّة أخرى، أو تواصل مع الدعم.';

  @override
  String get authInviteErrorUnknown =>
      'لم نتمكّن من تفعيل دعوتك. عد إلى رمز دعوتك، انضم لقائمة الانتظار، أو تواصل مع الدعم.';

  @override
  String get shareSheetSave => 'حفظ';

  @override
  String get shareSheetRemoveFromSaved => 'إزالة المحفوظ';

  @override
  String get shareSheetSaveToGallery => 'حفظ في المعرض';

  @override
  String get shareSheetSaveWithWatermark => 'حفظ مع العلامة المائية';

  @override
  String get shareSheetSaveVideo => 'حفظ الفيديو';

  @override
  String get shareSheetAddToClips => 'إضافة إلى المقاطع';

  @override
  String get shareSheetNameClipTitle => 'سمِّ هذا المقطع';

  @override
  String get shareSheetNameClipSubtitle =>
      'اختر اسمًا يسهل عليك تمييزه في مكتبتك.';

  @override
  String get shareSheetClipTitleLabel => 'عنوان المقطع';

  @override
  String get shareSheetSaveClip => 'حفظ المقطع';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'تم حفظ \"$title\" في المقاطع';
  }

  @override
  String get shareSheetUntitledClip => 'مقطع بدون عنوان';

  @override
  String get shareSheetAddToClipsFailed => 'تعذّرت الإضافة إلى المقاطع';

  @override
  String get shareSheetAddToList => 'إضافة إلى قائمة';

  @override
  String get shareSheetCopy => 'نسخ';

  @override
  String get shareSheetShareVia => 'مشاركة عبر';

  @override
  String get shareSheetEventJson => 'JSON الحدث';

  @override
  String get shareSheetEventId => 'معرّف الحدث';

  @override
  String get shareSheetMoreActions => 'إجراءات إضافية';

  @override
  String get shareSheetCrosspost => 'نشر متقاطع';

  @override
  String get crosspostSheetTitle => 'النشر المتقاطع لهذا الفيديو';

  @override
  String get crosspostSheetSubtitle =>
      'أرسله إلى منصّاتك المرتبطة. قد يستغرق النشر بضع دقائق.';

  @override
  String get crosspostSubmit => 'نشر متقاطع';

  @override
  String get crosspostStatusQueued => 'في الانتظار';

  @override
  String get crosspostStatusUploading => 'جارٍ الرفع';

  @override
  String get crosspostStatusProcessing => 'جارٍ المعالجة';

  @override
  String get crosspostStatusPosted => 'تم النشر';

  @override
  String get crosspostStatusFailed => 'فشل';

  @override
  String get crosspostStatusSkipped => 'تم التخطّي';

  @override
  String get crosspostStatusNeedsReauth => 'يتطلّب إعادة الربط';

  @override
  String get crosspostViewPost => 'عرض المنشور';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'أعد ربط $platform في إعدادات النشر المتقاطع لمواصلة النشر.';
  }

  @override
  String get crosspostReconnect => 'إعادة الربط';

  @override
  String get crosspostErrorNotOwner =>
      'النشر المتقاطع متاح فقط لفيديوهاتك الخاصة.';

  @override
  String get crosspostErrorNotEligible =>
      'هذا الفيديو غير مؤهّل للنشر المتقاطع.';

  @override
  String get crosspostErrorNotConnected => 'تلك المنصّة غير مرتبطة.';

  @override
  String get crosspostErrorUnauthorized => 'أعد ربط حسابك، ثم حاول مرّة أخرى.';

  @override
  String get crosspostErrorNetwork =>
      'تعذّر الوصول إلى خدمة النشر المتقاطع. حاول مرّة أخرى بعد قليل.';

  @override
  String get crosspostFailedGeneric => 'فشل النشر المتقاطع.';

  @override
  String get crosspostStillWorking =>
      'ما زال العمل جاريًا. يمكنك إغلاق هذا — سيستمر النشر في الخلفية.';

  @override
  String get crosspostDone => 'تم';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'تم الحفظ في ألبوم الكاميرا';

  @override
  String get watermarkDownloadShare => 'مشاركة';

  @override
  String get watermarkDownloadDone => 'تم';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'مطلوب الوصول إلى الصور';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'لحفظ الفيديوهات، اسمح بالوصول إلى الصور في الإعدادات.';

  @override
  String get watermarkDownloadOpenSettings => 'فتح الإعدادات';

  @override
  String get watermarkDownloadNotNow => 'ليس الآن';

  @override
  String get watermarkDownloadFailed => 'فشل التنزيل';

  @override
  String get watermarkDownloadDismiss => 'تجاهل';

  @override
  String get watermarkDownloadStageDownloading => 'جاري تنزيل الفيديو';

  @override
  String get watermarkDownloadStageWatermarking => 'إضافة العلامة المائية';

  @override
  String get watermarkDownloadStageSaving => 'جاري الحفظ في ألبوم الكاميرا';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'جاري جلب الفيديو من الشبكة...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'جاري تطبيق علامة Divine المائية...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'جاري حفظ الفيديو في ألبوم الكاميرا...';

  @override
  String get shareMenuBookmarks => 'الإشارات المرجعية';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count مجموعة متابعة متاحة';
  }

  @override
  String get peopleListsAddToList => 'أضف إلى القائمة';

  @override
  String get peopleListsSheetTitle => 'أضف إلى القائمة';

  @override
  String get peopleListsEmptyTitle => 'لا توجد قوائم بعد';

  @override
  String get peopleListsEmptySubtitle => 'أنشئ قائمة لبدء تجميع الأشخاص.';

  @override
  String get peopleListsCreateList => 'إنشاء قائمة';

  @override
  String get peopleListsNewListTitle => 'قائمة جديدة';

  @override
  String get peopleListsRouteTitle => 'قائمة الأشخاص';

  @override
  String get peopleListsListNameLabel => 'اسم القائمة';

  @override
  String get peopleListsListNameHint => 'أصدقاء مقربون';

  @override
  String get peopleListsCreateButton => 'إنشاء';

  @override
  String get peopleListsAddPeopleTitle => 'إضافة أشخاص';

  @override
  String get peopleListsAddPeopleTooltip => 'إضافة أشخاص';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'أضف أشخاصًا إلى القائمة';

  @override
  String get peopleListsListNotFoundTitle => 'القائمة غير موجودة';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'القائمة غير موجودة. ربما تم حذفها.';

  @override
  String get peopleListsListDeletedSubtitle => 'ربما تم حذف هذه القائمة.';

  @override
  String get peopleListsNoPeopleTitle => 'لا يوجد أشخاص في هذه القائمة';

  @override
  String get peopleListsNoPeopleSubtitle => 'أضف بعض الأشخاص للبدء';

  @override
  String get peopleListsNoVideosTitle => 'لا توجد مقاطع فيديو بعد';

  @override
  String get peopleListsNoVideosSubtitle =>
      'ستظهر هنا مقاطع الفيديو من أعضاء القائمة';

  @override
  String get peopleListsNoVideosAvailable => 'لا تتوفر مقاطع فيديو';

  @override
  String get peopleListsFailedToLoadVideos => 'فشل تحميل مقاطع الفيديو';

  @override
  String get peopleListsVideoNotAvailable => 'الفيديو غير متاح';

  @override
  String get peopleListsBackToGridTooltip => 'العودة إلى الشبكة';

  @override
  String get peopleListsErrorLoadingVideos => 'خطأ في تحميل مقاطع الفيديو';

  @override
  String get peopleListsNoPeopleToAdd => 'لا يوجد أشخاص متاحون للإضافة.';

  @override
  String peopleListsAddToListName(String name) {
    return 'أضف إلى $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'البحث عن أشخاص';

  @override
  String get peopleListsAddPeopleError =>
      'تعذر تحميل الأشخاص. يرجى المحاولة مجددًا.';

  @override
  String get peopleListsAddPeopleRetry => 'حاول مجددًا';

  @override
  String get peopleListsAddButton => 'إضافة';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'إضافة $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'في $count قوائم',
      many: 'في $count قائمة',
      few: 'في $count قوائم',
      two: 'في قائمتين',
      one: 'في قائمة واحدة',
      zero: 'في صفر قوائم',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'هل تريد إزالة $name؟';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'سيتم إزالته/إزالتها من هذه القائمة.';

  @override
  String get peopleListsRemove => 'إزالة';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'تمت إزالة $name من القائمة';
  }

  @override
  String get peopleListsUndo => 'تراجع';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'ملف $name الشخصي. اضغط مطولًا للإزالة.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'عرض ملف $name الشخصي';
  }

  @override
  String get shareMenuEditVideo => 'تعديل الفيديو';

  @override
  String get shareMenuDeleteVideo => 'حذف الفيديو';

  @override
  String shareMenuVideoCount(int count) {
    return '$count فيديو';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'سيؤدي هذا إلى حذف هذا الفيديو نهائيًا من Divine. قد يظل يظهر في عملاء Nostr تابعين لجهات خارجية يستخدمون مرحّلات أخرى.';

  @override
  String get shareMenuCancel => 'إلغاء';

  @override
  String get shareMenuDelete => 'حذف';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'الحذف غير جاهز بعد. حاول مرة أخرى بعد لحظة.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'يمكنك حذف مقاطع الفيديو الخاصة بك فقط.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'سجّل الدخول مرة أخرى، ثم حاول الحذف.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'لم نتمكن من توقيع طلب الحذف. حاول مرة أخرى.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'لم يقبل الريلاي طلب الحذف هذا. حاول مرة أخرى بعد قليل.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'تعذّر الوصول إلى الريلاي. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'تم الحذف. لم تؤكّد كل المرحّلات، لذا قد يظل ظاهرًا في تطبيقات أخرى.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'تعذّر حذف هذا الفيديو. حاول مرة أخرى.';

  @override
  String get shareMenuUpdate => 'تحديث';

  @override
  String get shareMenuChangeCover => 'تغيير الغلاف';

  @override
  String get shareMenuVideoUpdated => 'تم تحديث الفيديو بنجاح';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لم يتم إرسال $count دعوات متعاونين.',
      one: 'لم يتم إرسال دعوة متعاون واحدة.',
    );
    return 'تم تحديث الفيديو، لكن $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'سجّل الدخول من جديد ثم حاول مرّة أخرى.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'هذا الفيديو ليس له مصدر قابل للتشغيل، لذا لا يمكن تعديله.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'تعذّر توقيع التحديث. حاول مرّة أخرى.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'لم يقبل الريلاي التحديث. حاول مرّة أخرى بعد قليل.';

  @override
  String get videoUpdateErrorGeneric =>
      'تعذّر تحديث هذا الفيديو. حاول مرّة أخرى.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'حذف الفيديو؟';

  @override
  String get shareMenuDeleteCleanupInProgress => 'جارٍ إزالة الفيديو…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'تم حذف الفيديو.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'تم حذف الفيديو. قد يستغرق اختفاؤه من كل مكان بعض الوقت.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'تم حذف الفيديو، لكننا لم نتمكن من إزالة كل نسخة. التواصل مع الدعم.';

  @override
  String get authSessionExpired => 'انتهت جلستك. يرجى تسجيل الدخول مرّة أخرى.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'فشل تسجيل الدخول. حاول مرّة أخرى.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'مصادقة الويب غير مدعومة في الوضع الآمن. يرجى استخدام تطبيق الجوال لإدارة المفاتيح بأمان.';

  @override
  String get webAuthEnterBunkerUri => 'يرجى إدخال رابط bunker';

  @override
  String get webAuthConnectTitle => 'الاتصال بـ Divine';

  @override
  String get webAuthChooseMethod => 'اختر طريقة مصادقة Nostr المفضّلة لديك';

  @override
  String get webAuthBrowserExtension => 'إضافة المتصفح';

  @override
  String get webAuthRecommended => 'موصى به';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'الاتصال بموقّع خارجي';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'لصق من الحافظة';

  @override
  String get webAuthConnectToBunker => 'الاتصال بـ Bunker';

  @override
  String get webAuthNewToNostr => 'جديد على Nostr؟';

  @override
  String get webAuthNostrHelp =>
      'ثبّت إضافة متصفح مثل Alby أو nos2x لتجربة أسهل، أو استخدم nsec bunker للتوقيع الخارجي الآمن.';

  @override
  String get soundsTitle => 'الأصوات';

  @override
  String get soundsSearchHint => 'البحث عن أصوات...';

  @override
  String get soundsSearchResults => 'نتائج البحث';

  @override
  String get soundsNoSoundsFound => 'لم يُعثر على أصوات';

  @override
  String get soundsNoSoundsFoundDescription => 'جرِّب كلمة بحث مختلفة';

  @override
  String get soundsSavedToLibrary => 'حُفظ في الأصوات';

  @override
  String get soundsAlreadySavedToLibrary => 'موجود بالفعل في الأصوات';

  @override
  String get soundsSavedLibraryTitle => 'أصواتي';

  @override
  String get soundsSavedEmptyTitle => 'لا توجد أصوات محفوظة بعد';

  @override
  String get soundsSavedEmptyDescription =>
      'اضغط على استخدام الصوت في فيديو لحفظه هنا.';

  @override
  String get soundsRemoveSavedSound => 'إزالة الصوت';

  @override
  String get savedSoundSaveAction => 'حفظ';

  @override
  String get savedSoundPausePreviewAction => 'إيقاف المعاينة مؤقتًا';

  @override
  String get savedSoundResumePreviewAction => 'استئناف المعاينة';

  @override
  String get savedSoundDetailsSheetTitle => 'تفاصيل الصوت';

  @override
  String get savedSoundRemoveConfirmTitle => 'هل تريد إزالة هذا الصوت؟';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'سيختفي من مكتبتك، لكن يمكنك حفظه مرة أخرى من أي فيديو يستخدمه.';

  @override
  String get soundsRemovedFromLibrary => 'أُزيل من الأصوات';

  @override
  String get soundsSaveFailed => 'تعذّر حفظ هذا الصوت. حاول مرة أخرى.';

  @override
  String get soundsRemoveFailed => 'تعذّرت إزالة هذا الصوت. حاول مرة أخرى.';

  @override
  String get soundSyncStatusSyncing => 'جارٍ مزامنة أصواتك…';

  @override
  String get soundSyncStatusSynced => 'الأصوات محدَّثة';

  @override
  String get soundSyncStatusFailed => 'تعذّرت مزامنة أصواتك. سنحاول مرة أخرى.';

  @override
  String get soundSyncStatusLocked =>
      'تعذّر فتح مكتبتك المتزامنة على هذا الجهاز.';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileMoreOptions => 'خيارات أخرى';

  @override
  String profileBlockedUser(String name) {
    return 'تم حظر $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'تم إلغاء حظر $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'تم إلغاء متابعة $name';
  }

  @override
  String get profileFeedError =>
      'تعذّر الوصول إلى الخادم. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get profileFeedLoadMoreError =>
      'تعذّر تحميل المزيد من الفيديوهات. اسحب للتحديث.';

  @override
  String get notificationsTabAll => 'الكل';

  @override
  String get notificationsTabLikes => 'الإعجابات';

  @override
  String get notificationsTabComments => 'التعليقات';

  @override
  String get notificationsTabFollows => 'المتابعات';

  @override
  String get notificationsTabReposts => 'إعادة النشر';

  @override
  String get notificationsFailedToLoad => 'تعذر تحميل الإشعارات';

  @override
  String get notificationsRetry => 'إعادة المحاولة';

  @override
  String get notificationsRefreshError => 'تعذّر التحديث — يتم عرض ما هو متاح';

  @override
  String get notificationsUnreadPrefix => 'إشعار غير مقروء';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعار غير مقروء',
      many: '$count إشعارًا غير مقروء',
      few: '$count إشعارات غير مقروءة',
      two: 'إشعاران غير مقروءين',
      one: 'إشعار واحد غير مقروء',
      zero: 'لا إشعارات غير مقروءة',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'عرض ملف $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'عرض الملفات الشخصية';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'صورة مصغرة لفيديو $title';
  }

  @override
  String get notificationsVideoThumbnail => 'صورة مصغرة للفيديو';

  @override
  String get notificationsInviteSingular =>
      'لديك دعوة واحدة لمشاركتها مع صديق!';

  @override
  String notificationsInvitePlural(int count) {
    return 'لديك $count دعوات لمشاركتها مع الأصدقاء!';
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
  String get notificationsVideoUnavailable => 'الفيديو غير متاح';

  @override
  String get feedFailedToLoadVideos => 'تعذر تحميل مقاطع الفيديو';

  @override
  String get feedRetry => 'إعادة المحاولة';

  @override
  String get feedNoFollowedUsers =>
      'لا يوجد مستخدمون متابَعون.\nتابِع شخصًا ما لترى مقاطع الفيديو هنا.';

  @override
  String get feedModeForYou => 'لك';

  @override
  String get feedModeNew => 'جديد';

  @override
  String get feedModeFollowing => 'المتابَعون';

  @override
  String get feedModeClassics => 'الكلاسيكيات';

  @override
  String feedModeSemanticLabel(String label) {
    return 'وضع الموجز: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'صانع الفيديو: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'صورة رمز صانع المحتوى';

  @override
  String get feedForYouEmpty =>
      'خلاصة لك فارغة.\nاستكشف المقاطع واتبع صناع المحتوى لتخصيصها.';

  @override
  String get feedFollowingEmpty =>
      'لا توجد مقاطع بعد من الأشخاص الذين تتابعهم.\nاعثر على صناع محتوى يعجبونك وتابعهم.';

  @override
  String get feedLatestEmpty => 'لا توجد مقاطع جديدة بعد.\nعد لاحقًا.';

  @override
  String get feedClassicEmpty => 'لا توجد كلاسيكيات بعد.\nعد لاحقًا.';

  @override
  String get feedExploreVideos => 'استكشاف مقاطع الفيديو';

  @override
  String get feedLoadingMore => 'جارٍ تحميل المزيد من الفيديوهات…';

  @override
  String get feedRefreshed => 'تم تحديث الخلاصة';

  @override
  String get uploadUploadingVideo => 'جارٍ رفع الفيديو';

  @override
  String get postPublishConfirmationTitle => 'تم النشر في ملفك الشخصي';

  @override
  String get postPublishConfirmationView => 'عرض';

  @override
  String get postPublishConfirmationShare => 'مشاركة';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'صورة مصغرة للفيديو الذي نشرته للتو';

  @override
  String get userSearchNoResults => 'لم يُعثر على مستخدمين';

  @override
  String get userPickerFilterByNameHint => 'التصفية بالاسم...';

  @override
  String get userPickerSearchByNameHint => 'البحث بالاسم...';

  @override
  String get userPickerClearSearchSemantics => 'مسح البحث';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return 'تمت إضافة $name بالفعل';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'اختيار $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'إزالة $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'فريقك موجود في مكان ما';

  @override
  String get userPickerEmptyFollowListBody =>
      'تابع الأشخاص الذين تنسجم معهم. وعندما يتابعونك بدورهم، يمكنكم التعاون معًا.';

  @override
  String get userPickerGoBack => 'العودة';

  @override
  String get userPickerTypeNameToSearch => 'اكتب اسمًا للبحث';

  @override
  String get userPickerUnavailable =>
      'البحث عن المستخدمين غير متاح حاليًا. حاول مرة أخرى لاحقًا.';

  @override
  String get userPickerSearchFailedTryAgain => 'فشل البحث. حاول مرة أخرى.';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPasswordDescription =>
      'أدخل بريدك الإلكتروني وسنُرسل إليك رابطًا لإعادة تعيين كلمة المرور.';

  @override
  String get forgotPasswordEmailLabel => 'البريد الإلكتروني';

  @override
  String get forgotPasswordCancel => 'إلغاء';

  @override
  String get forgotPasswordSendLink => 'إرسال رابط إعادة التعيين';

  @override
  String get ageVerificationContentWarning => 'تحذير محتوى';

  @override
  String get ageVerificationTitle => 'التحقق من العمر';

  @override
  String get ageVerificationAdultDescription =>
      'تم وسم هذا المحتوى باعتباره قد يحتوي على مواد للبالغين. يجب أن يكون عمرك 18 عامًا أو أكثر لمشاهدته.';

  @override
  String get ageVerificationCreationDescription =>
      'لاستخدام الكاميرا وإنشاء محتوى، يجب أن يكون عمرك 16 عامًا على الأقل.';

  @override
  String get ageVerificationAdultQuestion => 'هل عمرك 18 عامًا أو أكثر؟';

  @override
  String get ageVerificationCreationQuestion => 'هل عمرك 16 عامًا أو أكثر؟';

  @override
  String get ageVerificationNo => 'لا';

  @override
  String get ageVerificationYes => 'نعم';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navExplore => 'استكشاف';

  @override
  String get navInbox => 'الوارد';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get navMyProfile => 'ملفي الشخصي';

  @override
  String get navNotifications => 'الإشعارات';

  @override
  String get navOpenCamera => 'فتح الكاميرا';

  @override
  String get navExploreClassics => 'الكلاسيكيات';

  @override
  String get navExploreNewVideos => 'فيديوهات جديدة';

  @override
  String get navExploreTrending => 'الرائجة';

  @override
  String get navExploreForYou => 'مُقترَح لك';

  @override
  String get navExploreLists => 'القوائم';

  @override
  String get routeErrorTitle => 'خطأ';

  @override
  String get routeInvalidHashtag => 'وسم غير صالح';

  @override
  String get routeInvalidConversationId => 'مُعرِّف محادثة غير صالح';

  @override
  String get routeInvalidRequestId => 'مُعرِّف طلب غير صالح';

  @override
  String get routeInvalidListId => 'مُعرِّف قائمة غير صالح';

  @override
  String get routeInvalidUserId => 'مُعرِّف مستخدم غير صالح';

  @override
  String get routeInvalidVideoId => 'مُعرِّف فيديو غير صالح';

  @override
  String get routeInvalidSoundId => 'مُعرِّف صوت غير صالح';

  @override
  String get routeInvalidCategory => 'فئة غير صالحة';

  @override
  String get routeNoVideosToDisplay => 'لا توجد مقاطع فيديو لعرضها';

  @override
  String get routeGoHome => 'الذهاب إلى الرئيسية';

  @override
  String get routeInvalidProfileId => 'مُعرِّف ملف شخصي غير صالح';

  @override
  String get routeUnknownPath => 'هذه الصفحة غير متوفرة في التطبيق.';

  @override
  String get routeDefaultListName => 'قائمة';

  @override
  String get supportTitle => 'مركز الدعم';

  @override
  String get supportContactSupport => 'التواصل مع الدعم';

  @override
  String get supportContactSupportSubtitle =>
      'ابدأ محادثة أو اطّلع على الرسائل السابقة';

  @override
  String get supportReportBug => 'الإبلاغ عن خطأ';

  @override
  String get supportReportBugSubtitle => 'مشاكل تقنية في التطبيق';

  @override
  String get supportRequestFeature => 'طلب ميزة';

  @override
  String get supportRequestFeatureSubtitle => 'اقتراح تحسين أو ميزة جديدة';

  @override
  String get supportSaveLogs => 'حفظ السجلات';

  @override
  String get supportSaveLogsSubtitle => 'تصدير السجلات إلى ملف للإرسال يدويًا';

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
  String get supportFaq => 'الأسئلة الشائعة';

  @override
  String get supportFaqSubtitle => 'الأسئلة والأجوبة الشائعة';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'مساعدة الآباء والمراهقين على بناء عادات صحية على الإنترنت';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'كيف نتعامل مع الحسابات حسب العمر';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => 'تعرَّف على التحقق والأصالة';

  @override
  String get supportLoginRequired => 'سجِّل الدخول للتواصل مع الدعم';

  @override
  String get supportExportingLogs => 'جارٍ تصدير السجلات...';

  @override
  String get supportExportLogsFailed => 'تعذر تصدير السجلات';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'حُفظت السجلات في $path';
  }

  @override
  String get supportRevealLogsAction => 'إظهار في المجلد';

  @override
  String get supportChatNotAvailable => 'محادثة الدعم غير متاحة';

  @override
  String get supportCouldNotOpenMessages => 'تعذر فتح رسائل الدعم';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'تعذر فتح $pageName';
  }

  @override
  String get reportWhyReporting => 'لماذا تُبلِّغ عن هذا المحتوى؟';

  @override
  String get reportPolicyNotice =>
      'ستتصرف Divine بشأن بلاغات المحتوى خلال 24 ساعة بإزالة المحتوى وإخراج المستخدم الذي قدَّم المحتوى المخالف.';

  @override
  String get reportBlockUser => 'حظر هذا المستخدم';

  @override
  String get reportCancel => 'إلغاء';

  @override
  String get reportSubmit => 'إبلاغ';

  @override
  String get reportSelectReason => 'يُرجى اختيار سبب للإبلاغ عن هذا المحتوى';

  @override
  String get reportOtherRequiresDetails => 'يرجى وصف المشكلة عند اختيار «أخرى»';

  @override
  String get reportDetailsRequired => 'يرجى وصف المشكلة';

  @override
  String get reportDetailsTextOnly =>
      'نص فقط — لا يمكن إرفاق الصور أو ملفات GIF هنا.';

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
  String get reportReasonSpam => 'محتوى غير مرغوب فيه أو مزعج';

  @override
  String get reportReasonSpamSubtitle => 'محتوى غير مرغوب فيه أو متكرر';

  @override
  String get reportReasonHarassment => 'تحرُّش أو تنمُّر أو تهديدات';

  @override
  String get reportReasonHarassmentSubtitle =>
      'ردود أو إشارات ضارة وغير مرغوب فيها';

  @override
  String get reportReasonViolence => 'محتوى عنيف أو متطرف';

  @override
  String get reportReasonViolenceSubtitle => 'محتوى عنيف أو متطرف أو ضار';

  @override
  String get reportReasonSexualContent => 'محتوى جنسي أو للبالغين';

  @override
  String get reportReasonSexualContentSubtitle => 'عُري أو محتوى إباحي أو صريح';

  @override
  String get reportReasonCopyright => 'انتهاك حقوق الملكية';

  @override
  String get reportReasonCopyrightSubtitle =>
      'استخدام غير مصرح به للملكية الفكرية';

  @override
  String get reportReasonFalseInfo => 'معلومات كاذبة';

  @override
  String get reportReasonFalseInfoSubtitle => 'ادعاءات مضللة أو كاذبة';

  @override
  String get reportReasonChildSafety => 'انتهاك سلامة الأطفال';

  @override
  String get reportReasonChildSafetySubtitle =>
      'مخاوف عامة بشأن سلامة القُصَّر';

  @override
  String get reportReasonCsam => 'الاعتداء الجنسي على الأطفال';

  @override
  String get reportReasonCsamSubtitle =>
      'محتوى يصوّر الاعتداء الجنسي على القاصرين';

  @override
  String get reportReasonUnderageUser => 'يبدو أن المستخدم دون 16 عامًا';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'يبدو أن صاحب الحساب دون السن القانونية';

  @override
  String get reportReasonAiGenerated => 'محتوى مُولَّد بالذكاء الاصطناعي';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'محتوى يُشتبه أنه من إنشاء الذكاء الاصطناعي';

  @override
  String get reportReasonOther => 'انتهاك آخر للسياسة';

  @override
  String get reportReasonOtherSubtitle => 'انتهاكات غير مدرجة أعلاه';

  @override
  String get reportFailed =>
      'تعذر الإبلاغ عن المحتوى. يرجى المحاولة مرّة أخرى.';

  @override
  String get reportNotSent =>
      'تعذّر إرسال بلاغك. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get reportReceivedTitle => 'تم استلام البلاغ';

  @override
  String get reportReceivedThankYou =>
      'شكرًا لمساعدتك في الحفاظ على سلامة Divine.';

  @override
  String get reportReceivedReviewNotice =>
      'سيُراجع فريقنا بلاغك ويتخذ الإجراء المناسب. قد تتلقى تحديثات عبر رسالة مباشرة.';

  @override
  String get reportModerationDmDelayed =>
      'تعذّر علينا الوصول إلى فريق الإشراف مباشرةً الآن، لكن تم استلام بلاغك وسيُراجَع.';

  @override
  String get reportContactModeration => 'راسل فريق الإشراف';

  @override
  String get reportLearnMoreAt => 'اعرف المزيد على';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'إغلاق';

  @override
  String get listAddToList => 'إضافة إلى قائمة';

  @override
  String listVideoCount(int count) {
    return '$count مقاطع فيديو';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص',
      many: '$count شخصًا',
      few: '$count أشخاص',
      two: 'شخصان',
      one: 'شخص واحد',
      zero: 'لا أحد',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'بقلم ';

  @override
  String get listNewList => 'قائمة جديدة';

  @override
  String get listDone => 'تم';

  @override
  String get listErrorLoading => 'تعذر تحميل القوائم';

  @override
  String listRemovedFrom(String name) {
    return 'تمت الإزالة من $name';
  }

  @override
  String listAddedTo(String name) {
    return 'تمت الإضافة إلى $name';
  }

  @override
  String get listCreateNewList => 'إنشاء قائمة جديدة';

  @override
  String get listNewPeopleList => 'قائمة أشخاص جديدة';

  @override
  String get listCollaboratorsNone => 'لا أحد';

  @override
  String get listAddCollaboratorTitle => 'إضافة متعاون';

  @override
  String get listCollaboratorSearchHint => 'ابحث في Divine...';

  @override
  String get listNameLabel => 'اسم القائمة';

  @override
  String get listDescriptionLabel => 'الوصف (اختياري)';

  @override
  String get listPublicList => 'قائمة عامة';

  @override
  String get listPublicListSubtitle =>
      'يمكن للآخرين متابعة هذه القائمة ورؤيتها';

  @override
  String get listPrivateListSubtitle =>
      'تبقى مقاطع الفيديو خاصة. يبقى الاسم والوصف والوسوم والغلاف ظاهرين.';

  @override
  String get listVisibilityPublic => 'عامة';

  @override
  String get listVisibilityPrivate => 'خاصة';

  @override
  String get profileListsEmpty =>
      'لا توجد قوائم بعد. أنشئ واحدة للمقاطع التي تريد جمعها معًا.';

  @override
  String get listEditTitle => 'تعديل القائمة';

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
  String get listShareAction => 'مشاركة القائمة';

  @override
  String get listShareFailed => 'تعذّرت مشاركة هذه القائمة. حاول مرة أخرى.';

  @override
  String get listSave => 'حفظ';

  @override
  String get listContinue => 'متابعة';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => 'تعذّر تحديث هذه القائمة. حاول مرة أخرى.';

  @override
  String get listMakePrivateTitle => 'هل تريد جعل هذه القائمة خاصة؟';

  @override
  String get listMakePrivateWarning =>
      'سيتم تشفير مقاطع الفيديو بحيث لا يراها سواك. يبقى الاسم والوصف والوسوم والغلاف ظاهرين، وقد تبقى النسخ التي شاركتها سابقًا.';

  @override
  String get listMakePublicTitle => 'هل تريد جعل هذه القائمة عامة؟';

  @override
  String get listMakePublicWarning =>
      'يمكن لأي شخص لديه الرابط رؤية هذه القائمة ومقاطعها.';

  @override
  String listShareText(String name, String url) {
    return 'شاهد $name على Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name على Divine';
  }

  @override
  String get listCancel => 'إلغاء';

  @override
  String get listCreate => 'إنشاء';

  @override
  String get listCreateFailed => 'تعذر إنشاء القائمة';

  @override
  String get keyManagementTitle => 'مفاتيح Nostr';

  @override
  String get keyManagementWhatAreKeys => 'ما هي مفاتيح Nostr؟';

  @override
  String get keyManagementExplanation =>
      'هويتك في Nostr عبارة عن زوج مفاتيح مُشفَّرة:\n\n• مفتاحك العام (npub) بمثابة اسم المستخدم - شاركه بحرية\n• مفتاحك الخاص (nsec) بمثابة كلمة المرور - احتفظ به سريًا!\n\nيُتيح لك nsec الوصول إلى حسابك على أي تطبيق Nostr.';

  @override
  String get keyManagementImportTitle => 'استيراد مفتاح موجود';

  @override
  String get keyManagementImportSubtitle =>
      'هل لديك حساب Nostr بالفعل؟ الصق مفتاحك الخاص (nsec) للوصول إليه هنا.';

  @override
  String get keyManagementImportButton => 'استيراد المفتاح';

  @override
  String get keyManagementImportWarning => 'سيحل هذا محل مفتاحك الحالي!';

  @override
  String get keyManagementBackupTitle => 'النسخ الاحتياطي لمفتاحك';

  @override
  String get keyManagementBackupSubtitle =>
      'احفظ مفتاحك الخاص (nsec) لاستخدام حسابك في تطبيقات Nostr أخرى.';

  @override
  String get keyManagementCopyNsec => 'نسخ مفتاحي الخاص (nsec)';

  @override
  String get keyManagementNeverShare => 'لا تُشارك nsec مع أي شخص أبدًا!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'مفتاحك محفوظ في خدمة تسجيل الدخول الخاصة بـ Divine، وليس على هذا الجهاز. أكِّد كلمة المرور وسنجلبه لك.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'مفتاحك محفوظ في خدمة تسجيل الدخول الخاصة بـ Divine. أدخل كلمة مرور حسابك وسنجلبه لك.';

  @override
  String get keyManagementKeycastCopyKey => 'نسخ المفتاح';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'جهازك منع النسخ، لذلك لم يصل مفتاحك إلى الحافظة.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'كلمة المرور غير مطابقة. حاول مرة أخرى.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'محاولات كثيرة جدًا. أغلق هذا وابدأ من جديد.';

  @override
  String get keyManagementKeycastRateLimited =>
      'طلبات كثيرة جدًا للمفتاح. انتظر بضع دقائق ثم حاول مرة أخرى.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'انتهت صلاحية جلستك. سجّل الدخول مرة أخرى لنسخ مفتاحك.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'أكِّد عنوان بريدك الإلكتروني قبل نسخ المفتاح.';

  @override
  String get keyManagementKeycastDenied =>
      'تدير Divine مفاتيح هذا الحساب، لذا لا يمكن نسخها هنا.';

  @override
  String get keyManagementKeycastNoKey => 'لا يوجد مفتاح مسجّل لهذا الحساب.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'تعذّر الوصول إلى خدمة تسجيل الدخول. حاول مرّة أخرى.';

  @override
  String get keyManagementRestrictedTitle => 'مفاتيحك يديرها Divine';

  @override
  String get keyManagementRestrictedBody =>
      'للحفاظ على أمان حسابك، النسخ الاحتياطي للمفتاح واستيراد مفتاح آخر غير متاحين هنا.';

  @override
  String get keyManagementPasteKey => 'يُرجى لصق مفتاحك الخاص';

  @override
  String get keyManagementInvalidFormat =>
      'تنسيق مفتاح غير صالح. يجب أن يبدأ بـ \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'استيراد هذا المفتاح؟';

  @override
  String get keyManagementConfirmImportBody =>
      'سيحل هذا محل هويتك الحالية بالهوية المستوردة.\n\nسيُفقد مفتاحك الحالي ما لم تقم بعمل نسخة احتياطية منه أولًا.';

  @override
  String get keyManagementImportConfirm => 'استيراد';

  @override
  String get keyManagementImportSuccess => 'تم استيراد المفتاح بنجاح!';

  @override
  String get keyManagementImportFailed =>
      'تعذر استيراد المفتاح. يرجى المحاولة مرّة أخرى.';

  @override
  String get keyManagementExportSuccess =>
      'تم نسخ المفتاح الخاص إلى الحافظة!\n\nاحفظه في مكان آمن.';

  @override
  String get keyManagementExportFailed =>
      'تعذر تصدير المفتاح. يرجى المحاولة مرّة أخرى.';

  @override
  String get keyManagementYourPublicKeyLabel => 'مفتاحك العام (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'نسخ المفتاح العام';

  @override
  String get keyManagementPublicKeyCopied => 'تم نسخ المفتاح العام';

  @override
  String get saveOriginalSavedToCameraRoll => 'تم الحفظ في ألبوم الكاميرا';

  @override
  String get saveOriginalShare => 'مشاركة';

  @override
  String get saveOriginalDone => 'تم';

  @override
  String get saveOriginalPhotosAccessNeeded => 'مطلوب الوصول إلى الصور';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'لحفظ مقاطع الفيديو، اسمح بالوصول إلى الصور في الإعدادات.';

  @override
  String get saveOriginalOpenSettings => 'فتح الإعدادات';

  @override
  String get saveOriginalNotNow => 'ليس الآن';

  @override
  String get saveOriginalDownloadFailed => 'فشل التنزيل';

  @override
  String get saveOriginalDismiss => 'إخفاء';

  @override
  String get saveOriginalDownloadingVideo => 'جارٍ تنزيل الفيديو';

  @override
  String get saveOriginalSavingToCameraRoll => 'جارٍ الحفظ في ألبوم الكاميرا';

  @override
  String get saveOriginalFetchingVideo => 'جارٍ جلب الفيديو من الشبكة...';

  @override
  String get saveOriginalSavingVideo =>
      'جارٍ حفظ الفيديو الأصلي في ألبوم الكاميرا...';

  @override
  String get soundTitle => 'الصوت';

  @override
  String get soundOriginalSound => 'الصوت الأصلي';

  @override
  String get soundVideosUsingThisSound => 'مقاطع الفيديو التي تستخدم هذا الصوت';

  @override
  String get soundSourceVideo => 'فيديو المصدر';

  @override
  String get soundNoVideosYet => 'لا توجد مقاطع فيديو بعد';

  @override
  String get soundBeFirstToUse => 'كُن أول من يستخدم هذا الصوت!';

  @override
  String get soundFailedToLoadVideos => 'تعذر تحميل مقاطع الفيديو';

  @override
  String get soundRetry => 'إعادة المحاولة';

  @override
  String get soundVideosUnavailable => 'مقاطع الفيديو غير متاحة';

  @override
  String get soundCouldNotLoadDetails => 'تعذر تحميل تفاصيل الفيديو';

  @override
  String get soundPreview => 'معاينة';

  @override
  String get soundStop => 'إيقاف';

  @override
  String get soundUseSound => 'استخدام الصوت';

  @override
  String get soundUntitled => 'صوت بلا عنوان';

  @override
  String get soundStopPreview => 'إيقاف المعاينة';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'معاينة $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'عرض تفاصيل $title';
  }

  @override
  String get soundNoVideoCount => 'لا توجد مقاطع فيديو بعد';

  @override
  String get soundOneVideo => 'فيديو واحد';

  @override
  String soundVideoCount(int count) {
    return '$count مقاطع فيديو';
  }

  @override
  String get soundUnableToPreview => 'تعذر معاينة الصوت - لا يوجد صوت متاح';

  @override
  String get soundPreviewFailed =>
      'تعذر تشغيل المعاينة. يرجى المحاولة مرّة أخرى.';

  @override
  String get soundViewSource => 'عرض المصدر';

  @override
  String get soundCloseTooltip => 'إغلاق';

  @override
  String get exploreNotExploreRoute => 'ليس مسار استكشاف';

  @override
  String get legalTitle => 'قانوني';

  @override
  String get legalTermsOfService => 'شروط الخدمة';

  @override
  String get legalTermsOfServiceSubtitle => 'شروط وأحكام الاستخدام';

  @override
  String get legalPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get legalPrivacyPolicySubtitle => 'كيف نتعامل مع بياناتك';

  @override
  String get legalSafetyStandards => 'معايير السلامة';

  @override
  String get legalSafetyStandardsSubtitle => 'إرشادات المجتمع والسلامة';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'سياسة حقوق النشر والإزالة';

  @override
  String get legalOpenSourceLicenses => 'تراخيص المصدر المفتوح';

  @override
  String get legalOpenSourceLicensesSubtitle => 'نسب حقوق حزم الطرف الثالث';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'تعذر فتح $pageName';
  }

  @override
  String get categoryAction => 'أكشن';

  @override
  String get categoryAdventure => 'مغامرة';

  @override
  String get categoryAnimals => 'حيوانات';

  @override
  String get categoryAnimation => 'رسوم متحركة';

  @override
  String get categoryArchitecture => 'هندسة معمارية';

  @override
  String get categoryArt => 'فن';

  @override
  String get categoryAutomotive => 'سيارات';

  @override
  String get categoryAwardShow => 'حفل جوائز';

  @override
  String get categoryAwards => 'جوائز';

  @override
  String get categoryBaseball => 'بيسبول';

  @override
  String get categoryBasketball => 'كرة السلة';

  @override
  String get categoryBeauty => 'جمال';

  @override
  String get categoryBeverage => 'مشروبات';

  @override
  String get categoryCars => 'سيارات';

  @override
  String get categoryCelebration => 'احتفال';

  @override
  String get categoryCelebrities => 'مشاهير';

  @override
  String get categoryCelebrity => 'مشهور';

  @override
  String get categoryCityscape => 'مناظر المدينة';

  @override
  String get categoryComedy => 'كوميديا';

  @override
  String get categoryConcert => 'حفلة موسيقية';

  @override
  String get categoryCooking => 'طبخ';

  @override
  String get categoryCostume => 'أزياء';

  @override
  String get categoryCrafts => 'حرف يدوية';

  @override
  String get categoryCrime => 'جريمة';

  @override
  String get categoryCulture => 'ثقافة';

  @override
  String get categoryDance => 'رقص';

  @override
  String get categoryDiy => 'اصنعها بنفسك';

  @override
  String get categoryDrama => 'دراما';

  @override
  String get categoryEducation => 'تعليم';

  @override
  String get categoryEmotional => 'عاطفي';

  @override
  String get categoryEmotions => 'مشاعر';

  @override
  String get categoryEntertainment => 'ترفيه';

  @override
  String get categoryEvent => 'حدث';

  @override
  String get categoryFamily => 'عائلة';

  @override
  String get categoryFans => 'معجبون';

  @override
  String get categoryFantasy => 'خيال';

  @override
  String get categoryFashion => 'أزياء';

  @override
  String get categoryFestival => 'مهرجان';

  @override
  String get categoryFilm => 'فيلم';

  @override
  String get categoryFitness => 'لياقة';

  @override
  String get categoryFood => 'طعام';

  @override
  String get categoryFootball => 'كرة قدم';

  @override
  String get categoryFurniture => 'أثاث';

  @override
  String get categoryGaming => 'ألعاب';

  @override
  String get categoryGolf => 'غولف';

  @override
  String get categoryGrooming => 'العناية الشخصية';

  @override
  String get categoryGuitar => 'غيتار';

  @override
  String get categoryHalloween => 'هالوين';

  @override
  String get categoryHealth => 'صحة';

  @override
  String get categoryHockey => 'هوكي';

  @override
  String get categoryHoliday => 'عطلة';

  @override
  String get categoryHome => 'منزل';

  @override
  String get categoryHomeImprovement => 'تحسين المنزل';

  @override
  String get categoryHorror => 'رعب';

  @override
  String get categoryHospital => 'مستشفى';

  @override
  String get categoryHumor => 'فكاهة';

  @override
  String get categoryInteriorDesign => 'تصميم داخلي';

  @override
  String get categoryInterview => 'مقابلة';

  @override
  String get categoryKids => 'أطفال';

  @override
  String get categoryLifestyle => 'أسلوب حياة';

  @override
  String get categoryMagic => 'سحر';

  @override
  String get categoryMakeup => 'مكياج';

  @override
  String get categoryMedical => 'طبي';

  @override
  String get categoryMusic => 'موسيقى';

  @override
  String get categoryMystery => 'غموض';

  @override
  String get categoryNature => 'طبيعة';

  @override
  String get categoryNews => 'أخبار';

  @override
  String get categoryOutdoor => 'أنشطة خارجية';

  @override
  String get categoryParty => 'حفلة';

  @override
  String get categoryPeople => 'أشخاص';

  @override
  String get categoryPerformance => 'أداء';

  @override
  String get categoryPets => 'حيوانات أليفة';

  @override
  String get categoryPolitics => 'سياسة';

  @override
  String get categoryPrank => 'مقلب';

  @override
  String get categoryPranks => 'مقالب';

  @override
  String get categoryRealityShow => 'برنامج واقعي';

  @override
  String get categoryRelationship => 'علاقة';

  @override
  String get categoryRelationships => 'علاقات';

  @override
  String get categoryRomance => 'رومانسية';

  @override
  String get categorySchool => 'مدرسة';

  @override
  String get categoryScienceFiction => 'خيال علمي';

  @override
  String get categorySelfie => 'سيلفي';

  @override
  String get categoryShopping => 'تسوق';

  @override
  String get categorySkateboarding => 'تزلج على اللوح';

  @override
  String get categorySkincare => 'العناية بالبشرة';

  @override
  String get categorySoccer => 'كرة قدم';

  @override
  String get categorySocialGathering => 'تجمع اجتماعي';

  @override
  String get categorySocialMedia => 'وسائل التواصل';

  @override
  String get categorySports => 'رياضة';

  @override
  String get categoryTalkShow => 'برنامج حواري';

  @override
  String get categoryTech => 'تقنية';

  @override
  String get categoryTechnology => 'تكنولوجيا';

  @override
  String get categoryTelevision => 'تلفزيون';

  @override
  String get categoryToys => 'ألعاب';

  @override
  String get categoryTransportation => 'نقل';

  @override
  String get categoryTravel => 'سفر';

  @override
  String get categoryUrban => 'حضري';

  @override
  String get categoryViolence => 'عنف';

  @override
  String get categoryVlog => 'مدونة فيديو';

  @override
  String get categoryVlogging => 'تدوين فيديو';

  @override
  String get categoryWrestling => 'مصارعة';

  @override
  String get profileSetupUploadStaged => 'تم الرفع — اضغط على حفظ للتطبيق';

  @override
  String inboxReportedUser(String displayName) {
    return 'تم الإبلاغ عن $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'تم حظر $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'تم إلغاء حظر $displayName';
  }

  @override
  String get inboxRemovedConversation => 'تمت إزالة المحادثة';

  @override
  String get inboxRestorePausedTitle => 'لم تكتمل استعادة بعض المحادثات';

  @override
  String get conversationRestorePausedTitle => 'لم تكتمل استعادة هذه المحادثة';

  @override
  String get inboxRestoreRetryAction => 'إعادة المحاولة';

  @override
  String get inboxRestoringMessages => 'جارٍ استعادة رسائلك…';

  @override
  String get inboxEmptyTitle => 'لا توجد رسائل بعد';

  @override
  String get inboxEmptySubtitle => 'زر + لن يعضّك.';

  @override
  String get inboxLoadErrorTitle => 'تعذّر تحميل الرسائل';

  @override
  String get inboxLoadErrorSubtitle => 'تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get inboxFilterAll => 'الكل';

  @override
  String get inboxFilterUnread => 'غير المقروءة';

  @override
  String get dmBlockedThreadTitle => 'لقد حظرت هذا الحساب';

  @override
  String get dmBlockedThreadBody =>
      'تبقى الرسائل هنا لتتمكن من قراءتها أو التقاط صورة لها. ألغِ الحظر للرد.';

  @override
  String get inboxFilterBlocked => 'محظور';

  @override
  String get inboxBlockedEmptyTitle => 'لا توجد محادثات محظورة';

  @override
  String get inboxBlockedEmptySubtitle => 'تظهر هنا الحسابات التي تحظرها.';

  @override
  String get inboxBlockedNoMessages => 'لا توجد رسائل';

  @override
  String get inboxUnreadEmptyTitle => 'أنت على اطلاع بكل شيء';

  @override
  String get inboxUnreadEmptySubtitle => 'لا توجد رسائل غير مقروءة حاليًا.';

  @override
  String get inboxSearchHint => 'البحث في الرسائل';

  @override
  String get inboxSupportRowTitle => 'إشراف Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'الأخطاء والإشراف ومشكلات الحساب — نحن نستمع.';

  @override
  String get inboxSearchEmptyTitle => 'لا توجد نتائج';

  @override
  String get inboxSearchEmptySubtitle => 'جرّب اسمًا أو كلمة أخرى.';

  @override
  String get inboxActionMute => 'كتم المحادثة';

  @override
  String inboxActionReport(String displayName) {
    return 'الإبلاغ عن $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'حظر $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'إلغاء حظر $displayName';
  }

  @override
  String get inboxActionRemove => 'إزالة المحادثة';

  @override
  String get inboxRemoveConfirmTitle => 'إزالة المحادثة؟';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'يؤدي هذا إلى إزالة محادثتك مع $displayName من صندوق الوارد. إذا راسلك مرة أخرى، تبدأ محادثة جديدة.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'يؤدي هذا إلى إزالة محادثة المجموعة من صندوق الوارد. إذا راسل أي شخص المجموعة مرة أخرى، تبدأ محادثة جديدة.';

  @override
  String get inboxRemoveConfirmConfirm => 'إزالة';

  @override
  String get inboxConversationMuted => 'تم كتم المحادثة';

  @override
  String get inboxConversationUnmuted => 'تم إلغاء كتم المحادثة';

  @override
  String get inboxCollabInviteCardTitle => 'دعوة للتعاون';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'فيديو بلا عنوان';

  @override
  String get clickableTextViewVideoLink => 'عرض الفيديو';

  @override
  String get messageExternalLinkDialogTitle => 'فتح رابط خارجي؟';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'هذا الرابط يذهب إلى موقع خارجي وقد لا يكون آمنًا:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'فتح';

  @override
  String get inboxCollabInviteCoPostButton => 'نشر مشترك';

  @override
  String get inboxCollabInviteNotMineButton => 'ليس لي';

  @override
  String get inboxCollabInvitePreviewTitle => 'دعوة نشر مشترك';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'دعوة نشر مشترك من $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'سيضيف النشر المشترك هذا الفيديو إلى يومياتك كتعاون.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'تم القبول';

  @override
  String get inboxCollabInviteIgnoredStatus => 'تم التجاهل';

  @override
  String get inboxCollabInviteAcceptError => 'تعذر القبول. حاول مرة أخرى.';

  @override
  String get inboxCollabInviteSentStatus => 'تم إرسال الدعوة';

  @override
  String get inboxConversationCollabInvitePreview => 'دعوة للتعاون';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'تمت دعوتك للتعاون على $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'تمت دعوتك للتعاون على فيديو: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لم تُرسَل $count دعوة تعاون.',
      many: 'لم تُرسَل $count دعوة تعاون.',
      few: 'لم تُرسَل $count دعوات تعاون.',
      two: 'لم تُرسَل دعوتا تعاون.',
      one: 'لم تُرسَل دعوة تعاون واحدة.',
      zero: 'لم تُرسَل أي دعوة تعاون.',
    );
    return 'تم نشر الفيديو، لكن $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'تعذّر علينا معرفة صاحب هذه المحادثة. افتحها من صندوق الوارد مرة أخرى.';

  @override
  String get dmSendBlockedMessage => 'يمكنك مراسلة حسابات Divine الرسمية فقط';

  @override
  String get dmSendBlockedRetiredMessage =>
      'لا أحد يقرأ هذه المحادثة. راسل Divine Moderation بدلاً من ذلك.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'تعذّر الحذف لدى الجميع.';

  @override
  String get dmDeleteRefusedDetails =>
      'قد يظل بعض الأشخاص قادرين على رؤية هذه الرسالة.';

  @override
  String get dmRetiredThreadClosedTitle => 'هذه المحادثة مغلقة.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'لا يمكن إزالة إشعار Divine Moderation هذا.';

  @override
  String get dmRetiredThreadClosedBody =>
      'نقلنا Divine Moderation إلى حساب جديد. لم يعد أحد يقرأ هذا الحساب.';

  @override
  String get dmRetiredThreadOpenSupport => 'راسل Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'تعذّر إرسال الرسالة';

  @override
  String get dmResendFailedMessage => 'ما زال الإرسال متعذّرًا';

  @override
  String get dmSendFailedSubtitle => 'أعد إرسالها الآن، أو أوقف المحاولة.';

  @override
  String get dmSendFailedRetry => 'إعادة المحاولة';

  @override
  String get dmSendPartialMessage =>
      'أُرسلت، لكنّها لم تُزامَن مع أجهزتك الأخرى';

  @override
  String get dmConversationLoadError => 'تعذّر تحميل الرسائل';

  @override
  String get dmMessageInputHint => 'قل شيئًا…';

  @override
  String get dmMessageBubbleSentHint => 'رسالة مُرسَلة';

  @override
  String get dmMessageBubbleReceivedHint => 'رسالة مُستلَمة';

  @override
  String get dmMessageBubbleLongPressHint => 'إجراءات الرسالة';

  @override
  String get dmMessageBubbleFailedTapHint => 'أعد إرسال هذه الرسالة أو احذفها';

  @override
  String get dmMessageActionCopyText => 'نسخ النص';

  @override
  String get dmMessageActionCopyVideoUrl => 'نسخ رابط الفيديو';

  @override
  String get dmMessageActionDeleteForEveryone => 'حذف للجميع';

  @override
  String get dmMessageActionReport => 'إبلاغ';

  @override
  String get dmMessageActionRetrySend => 'إعادة الإرسال';

  @override
  String get dmMessageActionCancelSend => 'إيقاف المحاولة';

  @override
  String get dmReactionAddCustomA11yLabel => 'إضافة تفاعل إيموجي مخصص';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'مراسلة $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'الرد على نفسك…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'الرد على هذا الريل';

  @override
  String get dmReelReplyViewChat => 'عرض المحادثة';

  @override
  String get dmReelReplySentAnnouncement => 'تم إرسال الرد';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'تفاعلت بـ $emoji';
  }

  @override
  String get dmReelReplyFailed => 'تعذّر الإرسال';

  @override
  String get dmReelReplyUnverified => 'تعذّر تأكيد الإرسال';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'تفاعلك: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return 'تفاعل $name بـ $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'جارٍ إرسال التفاعل: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'فشل التفاعل، انقر مرتين لإعادة المحاولة';

  @override
  String get dmReactionChipRetryAnnouncement => 'جارٍ إعادة محاولة التفاعل';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'أكمل إزالة تفاعلك السابق قبل إضافة تفاعل آخر.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'التفاعلات';

  @override
  String get dmReactionsViewA11yLabel => 'اعرف من تفاعل';

  @override
  String get dmReactionRemoveAction => 'إزالة';

  @override
  String get dmReactionRetryAction => 'إعادة المحاولة';

  @override
  String get dmFormatBold => 'عريض';

  @override
  String get dmFormatItalic => 'مائل';

  @override
  String get dmFormatStrikethrough => 'يتوسطه خط';

  @override
  String get dmFormatCode => 'رمز';

  @override
  String get dmStatusFailed => 'فشل الإرسال';

  @override
  String get inboxConversationActionsSheetLabel => 'إجراءات المحادثة';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'محادثة $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'غير مقروءة، محادثة $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخصًا آخر',
      few: '$count أشخاص آخرين',
      two: 'شخصان آخران',
      one: 'شخص آخر',
    );
    return '$name و$_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'عرض إجراءات المحادثة';

  @override
  String exploreVideoId(String id) {
    return 'المعرّف: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'العنوان: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'فيديو $current/$total';
  }

  @override
  String get exploreSearchHint => 'بحث...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count فيديو';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'فشل تحديث الاشتراك. يرجى المحاولة مرّة أخرى.';

  @override
  String get discoverListsTitle => 'اكتشف القوائم';

  @override
  String get discoverListsFailedToLoad => 'فشل تحميل القوائم';

  @override
  String get discoverListsLoading => 'جاري اكتشاف القوائم العامة...';

  @override
  String get discoverListsRelayTimeout =>
      'لم يُرجع الريلاي القوائم في الوقت المناسب. حاول مرة أخرى.';

  @override
  String get discoverListsServiceUnavailable => 'الخدمة غير متاحة.';

  @override
  String get discoverListsEmptyTitle => 'لم يتم العثور على قوائم عامة';

  @override
  String get discoverListsEmptySubtitle =>
      'عاود التحقق لاحقًا لرؤية قوائم جديدة';

  @override
  String get discoverListsByAuthorPrefix => 'بقلم';

  @override
  String get curatedListEmptyTitle => 'لا فيديوهات في هذه القائمة';

  @override
  String get curatedListEmptySubtitle => 'أضف بعض الفيديوهات للبدء';

  @override
  String get curatedListLoadingVideos => 'جاري تحميل الفيديوهات...';

  @override
  String get curatedListFailedToLoad => 'فشل تحميل القائمة';

  @override
  String get curatedListVideoNotAvailable => 'الفيديو غير متاح';

  @override
  String get curatedListActionsTooltip => 'إجراءات القائمة';

  @override
  String get curatedListDeleteConfirmTitle => 'حذف القائمة؟';

  @override
  String get curatedListDeleteConfirmBody =>
      'هذا يزيل القائمة من المحوّلات. لن تُحذف الفيديوهات الموجودة في القائمة.';

  @override
  String get curatedListDeletedSnack => 'تم حذف القائمة';

  @override
  String get curatedListDeleteFailed => 'تعذّر حذف القائمة';

  @override
  String get peopleListsActionsTooltip => 'إجراءات القائمة';

  @override
  String get listDeleteAction => 'حذف القائمة';

  @override
  String get peopleListsDeleteConfirmTitle => 'حذف القائمة؟';

  @override
  String get peopleListsDeleteConfirmBody =>
      'هذا يزيل القائمة للجميع. لن تُلغى متابعة الأشخاص الموجودين فيها.';

  @override
  String get peopleListsDeleteFailed => 'تعذّر حذف القائمة';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonSomethingWentWrong => 'حدث خطأ ما';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonNotNow => 'ليس الآن';

  @override
  String get commonLoading => 'جارٍ التحميل';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'تعذر تحديث الغلاف. حاول مرة أخرى.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'تم تحديث الغلاف';

  @override
  String get videoMetadataC2paMissingTitle =>
      'هل تريد النشر دون التحقق من الأصالة؟';

  @override
  String get videoMetadataC2paMissingBody =>
      'تعذّر علينا إضافة بيانات اعتماد المحتوى، لذا لن يتم تأكيد هذا الفيديو على أنه من صنع إنسان. أعد الإنشاء للمحاولة مرة أخرى، أو انشره كما هو.';

  @override
  String get videoMetadataC2paMissingNote =>
      'تتطلب بيانات اعتماد المحتوى اتصالاً بالإنترنت.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'لم تستجب خدمة بيانات اعتماد المحتوى. المشكلة ليست في اتصالك.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'إعادة الإنشاء';

  @override
  String get videoMetadataC2paMissingSkip => 'تخطّي';

  @override
  String get videoMetadataGenerationFailed => 'فشل الإنشاء';

  @override
  String get videoMetadataTags => 'الوسوم';

  @override
  String get videoMetadataExpiration => 'انتهاء الصلاحية';

  @override
  String get videoMetadataExpirationNotExpire => 'لا تنتهي الصلاحية';

  @override
  String get videoMetadataExpirationOneDay => 'يوم واحد';

  @override
  String get videoMetadataExpirationOneWeek => 'أسبوع واحد';

  @override
  String get videoMetadataExpirationOneMonth => 'شهر واحد';

  @override
  String get videoMetadataExpirationOneYear => 'سنة واحدة';

  @override
  String get videoMetadataExpirationOneDecade => 'عشر سنوات';

  @override
  String get videoMetadataContentWarnings => 'تحذيرات المحتوى';

  @override
  String get videoEditorStickers => 'الملصقات';

  @override
  String get trendingTitle => 'الرائج';

  @override
  String get libraryDeleteConfirm => 'حذف';

  @override
  String get libraryWebUnavailableHeadline =>
      'المكتبة متوفّرة في التطبيق على الجوال';

  @override
  String get libraryWebUnavailableDescription =>
      'تُحفظ المسودات والمقاطع على جهازك. افتح Divine على هاتفك لإدارتها.';

  @override
  String get libraryTabDrafts => 'مسودات';

  @override
  String get libraryTabClips => 'مقاطع';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'حذف المقاطع المحددة';

  @override
  String get libraryCloseSemanticLabel => 'إغلاق المكتبة';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'إيقاف تحديد المقاطع';

  @override
  String get librarySelectClipsSemanticLabel => 'تحديد المقاطع';

  @override
  String get libraryGridSizeLabel => 'حجم الشبكة';

  @override
  String get libraryDisplayOptionsLabel => 'الفرز وحجم الشبكة';

  @override
  String get libraryMoreActionsSemanticLabel => 'المزيد من إجراءات المكتبة';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عمود',
      many: '$count عمودًا',
      few: '$count أعمدة',
      two: 'عمودان',
      one: 'عمود واحد',
      zero: 'بلا أعمدة',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'تحديد';

  @override
  String get librarySortNewestCreation => 'الأحدث إنشاءً';

  @override
  String get librarySortOldestCreation => 'الأقدم إنشاءً';

  @override
  String get librarySortLongestClip => 'أطول مقطع';

  @override
  String get librarySortShortestClip => 'أقصر مقطع';

  @override
  String get librarySortSquareFirst => 'المربّع أولاً';

  @override
  String get librarySortVerticalFirst => 'العمودي أولاً';

  @override
  String get libraryDeleteClipsWarning =>
      'لا يمكن التراجع. ستُزال ملفات الفيديو نهائيًا من جهازك.';

  @override
  String get libraryPreparingVideo => 'جاري تجهيز الفيديو...';

  @override
  String libraryCreateVideo(int count) {
    return 'إنشاء فيديو ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقاطع',
      one: 'مقطع واحد',
    );
    return '$_temp0 تم حفظه في $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return 'تم حفظ $successCount، فشل $failureCount';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'تعذّر الحفظ في $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'تم رفض إذن $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count مقاطع',
      one: 'تم حذف مقطع واحد',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'تراجع';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'سيُحذف تلقائيًا خلال $daysLeft أيام',
      one: 'سيُحذف تلقائيًا غدًا',
      zero: 'سيُحذف تلقائيًا اليوم',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'تعذّر تحميل المسودات';

  @override
  String get libraryCouldNotLoadClips => 'تعذّر تحميل المقاطع';

  @override
  String get libraryOpenErrorDescription =>
      'حدث خطأ أثناء فتح المكتبة. يمكنك المحاولة مرة أخرى.';

  @override
  String get libraryNoDraftsYetTitle => 'لا توجد مسودات بعد';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'ستُظهر الفيديو الذي تحفظه كمسودة هنا';

  @override
  String get libraryNoClipsYetTitle => 'لا توجد مقاطع بعد';

  @override
  String get libraryNoClipsYetSubtitle => 'ستُظهر مقاطع الفيديو المسجّلة هنا';

  @override
  String get libraryDraftDeletedSnackbar => 'تم حذف المسودة';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'تعذّر حذف المسودة';

  @override
  String get libraryDraftDuplicatedSnackbar => 'تم تكرار المسودة';

  @override
  String get libraryDraftDuplicateFailedSnackbar => 'تعذّر تكرار المسودة';

  @override
  String get libraryDraftInProgressBadge => 'قيد التنفيذ';

  @override
  String get libraryDraftActionPost => 'نشر';

  @override
  String get libraryDraftActionEdit => 'تعديل';

  @override
  String get libraryDraftActionDuplicate => 'تكرار';

  @override
  String get libraryDraftActionDelete => 'حذف المسودة';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (نسخة $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'حذف المسودة';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'هل تريد حذُ “$title”؟';
  }

  @override
  String get libraryDeleteClipTitle => 'حذف المقطع';

  @override
  String get libraryDeleteClipMessage => 'هل تريد حذف هذا المقطع؟';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds ث';
  }

  @override
  String get libraryRecordVideo => 'تسجيل فيديو';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'مقطع فيديو، $duration ثانية';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'مؤرشف. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'مقطع حركة إيقافية، $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'محدد، رقم $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'محدد';

  @override
  String get videoClipSemanticValueNotSelected => 'غير محدد';

  @override
  String get videoClipSemanticHintDisabled => 'معطل';

  @override
  String get videoClipSemanticHintSelect =>
      'انقر للتحديد، اضغط مطولاً للمعاينة';

  @override
  String get videoClipSemanticHintDeselect =>
      'انقر لإلغاء التحديد، اضغط مطولاً للمعاينة';

  @override
  String get routerInvalidCreator => 'منشئ غير صالح';

  @override
  String get routerInvalidHashtagRoute => 'مسار هاشتاغ غير صالح';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'تعذّر تحميل الفيديوهات';

  @override
  String get categoryGalleryNoVideosInCategory => 'لا فيديوهات في هذه الفئة';

  @override
  String get categoryGallerySortOptionsLabel => 'خيارات ترتيب الفئة';

  @override
  String get categoryGallerySortHot => 'الرائج';

  @override
  String get categoryGallerySortNew => 'الجديد';

  @override
  String get categoryGallerySortClassic => 'الكلاسيكي';

  @override
  String get categoryGallerySortForYou => 'لك';

  @override
  String get categoriesCouldNotLoadCategories => 'تعذّر تحميل الفئات';

  @override
  String get categoriesNoCategoriesAvailable => 'لا توجد فئات متاحة';

  @override
  String get notificationsEmptyTitle => 'لا نشاط بعد';

  @override
  String get notificationsEmptySubtitle =>
      'عندما يتفاعل الناس مع محتواك، سترى ذلك هنا';

  @override
  String get appsPermissionsTitle => 'صلاحيات التكاملات';

  @override
  String get appsPermissionsRevoke => 'إلغاء';

  @override
  String get appsPermissionsEmptyTitle => 'لا توجد صلاحيات تكاملات محفوظة';

  @override
  String get appsPermissionsEmptySubtitle =>
      'ستظهر التكاملات الموافَق عليها هنا بعد أن تحفظ موافقة الوصول.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName يطلب موافقتك';
  }

  @override
  String get nostrAppPermissionDescription =>
      'يطلب هذا التطبيق الوصول عبر بيئة Divine الموثوقة.';

  @override
  String get nostrAppPermissionOrigin => 'الأصل';

  @override
  String get nostrAppPermissionMethod => 'الطريقة';

  @override
  String get nostrAppPermissionCapability => 'الإمكانية';

  @override
  String get nostrAppPermissionEventKind => 'نوع الحدث';

  @override
  String get nostrAppPermissionAllow => 'السماح';

  @override
  String get appsDetailDefaultTitle => 'تطبيق مدمج';

  @override
  String get appsDetailNotFoundTitle => 'التكامل غير موجود';

  @override
  String get appsDetailNotFoundSubtitle =>
      'لم يعد هذا التكامل الموثوق متاحًا في Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'كيف يعمل';

  @override
  String get appsDetailHowItWorksBody =>
      'هذا تطبيق خارجي موثوق يعمل داخل Divine. يمنح Divine هذا التكامل صلاحيات مُراجَعة فقط، ويحجب التنقّل خارج مصادره الموثوقة.';

  @override
  String get appsDetailAboutTitle => 'حول';

  @override
  String get appsDetailPrimaryOriginTitle => 'المصدر الأساسي';

  @override
  String get appsDetailApprovedOriginsTitle => 'المصادر الموثوقة';

  @override
  String get appsDetailCapabilitiesTitle => 'الصلاحيات المتاحة';

  @override
  String get appsDetailAskBeforeTitle => 'الاستئذان قبل';

  @override
  String get appsDetailOpenButton => 'فتح التكامل';

  @override
  String get appsDetailNoneDeclared => 'لم يُعلَن عن أي شيء بعد';

  @override
  String get appsDirectoryTitle => 'التطبيقات المدمجة';

  @override
  String get appsDirectoryIntroTitle => 'تطبيقات خارجية موثوقة';

  @override
  String get appsDirectoryIntroBody => 'تطبيقات خارجية موثوقة تعمل داخل Divine';

  @override
  String get appsDirectoryErrorTitle => 'تعذّر تحميل التطبيقات المدمجة';

  @override
  String get appsDirectoryErrorSubtitle =>
      'اسحب لإعادة محاولة تحميل التكاملات الموثوقة.';

  @override
  String get appsDirectoryEmptyTitle => 'لا توجد تكاملات موثوقة بعد';

  @override
  String get appsDirectoryEmptySubtitle =>
      'ستظهر هنا التطبيقات الخارجية الموثوقة كلما أضافها Divine.';

  @override
  String get appsDirectoryRefresh => 'تحديث';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'تعمل التطبيقات المدمجة في تطبيق Divine للجوال';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'التكاملات الموثوقة متاحة على الجوال فقط في الوقت الحالي.';

  @override
  String get appsSandboxUnavailableTitle => 'التكامل غير متاح';

  @override
  String get appsSandboxUnavailableBody =>
      'افتح التكاملات الموثوقة من تبويب التطبيقات المدمجة كي يتمكّن Divine من تطبيق سياسة الوصول الصحيحة.';

  @override
  String get appsSandboxLoadingTitle => 'جارٍ تحميل التكامل';

  @override
  String get appsSandboxLoadingSubtitle =>
      'يتم التحقق من التكامل الموثوق قبل التشغيل.';

  @override
  String get appsSandboxBlockedTitle => 'محجوب من أجل الأمان';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'حاول هذا التكامل مغادرة مصدره الموثوق.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'تم نسخ رابط المنشور إلى الحافظة';

  @override
  String get shareCopiedEventJson => 'تم نسخ JSON حدث Nostr إلى الحافظة';

  @override
  String get shareCopiedEventId => 'تم نسخ معرّف حدث Nostr إلى الحافظة';

  @override
  String get authHeroTaglineAuthentic => 'لحظات أصيلة.';

  @override
  String get authHeroTaglineHuman => 'إبداع إنساني.';

  @override
  String get keyImportFailedToImport =>
      'فشل استيراد المفتاح أو الاتصال بـ bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'رابط bunker غير صالح';

  @override
  String get keyImportInvalidFormat =>
      'تنسيق غير صالح. استخدم nsec... أو hex أو ncryptsec1... أو bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'تنسيق nsec غير صالح. يجب أن يتكوّن من 63 حرفًا';

  @override
  String get keyImportKeyFieldLabel => 'المفتاح الخاص أو رابط bunker';

  @override
  String get keyImportKeyRequired => 'يرجى إدخال مفتاحك الخاص أو رابط bunker';

  @override
  String get keyImportPasswordRequired =>
      'يرجى إدخال كلمة المرور لهذا المفتاح المشفّر';

  @override
  String get keyImportSecurityWarningBody =>
      'لا تشارك مفتاحك الخاص مع أي أحد أبدًا. يمنح هذا المفتاح وصولاً كاملاً إلى هويتك في Nostr.';

  @override
  String get keyImportSecurityWarningTitle => 'حافظ على أمان مفتاحك الخاص!';

  @override
  String get keyImportSubtitle =>
      'استورد هويتك الحالية في Nostr باستخدام مفتاحك الخاص أو رابط bunker.';

  @override
  String get keyImportTitle => 'استورد\nهويتك في Nostr';

  @override
  String get commentAuthorYouIndicator => 'أنت';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'عرض ملف $name الشخصي';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'حذف التعليق';

  @override
  String get commentOptionsEditSemanticLabel => 'تعديل التعليق';

  @override
  String get commentOptionsFlagContentLabel => 'الإبلاغ عن المحتوى';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'الإبلاغ عن هذا المحتوى';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'اختر سبب الإبلاغ عن هذا التعليق';

  @override
  String get commentOptionsFlagSubmit => 'إرسال';

  @override
  String get commentOptionsTitle => 'خيارات';

  @override
  String get commentsEmptyClassicVineMessage =>
      'ما زلنا نعمل على استيراد التعليقات القديمة من الأرشيف. إنها ليست جاهزة بعد.';

  @override
  String get commentsEmptyClassicVineTitle => 'Vine الكلاسيكي';

  @override
  String get commentsInputEditingLabel => 'جارٍ التعديل';

  @override
  String get commentsInputSemanticHint => 'أضف تعليقًا';

  @override
  String get commentsInputSemanticHintEdit => 'تعديل التعليق';

  @override
  String get commentsInputSemanticHintReply => 'أضف ردًّا';

  @override
  String get commentsInputSemanticLabel => 'حقل إدخال التعليق';

  @override
  String get commentsInputSemanticLabelEdit => 'حقل إدخال التعديل';

  @override
  String get commentsInputSemanticLabelReply => 'حقل إدخال الرد';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'عرض ملف $displayName الشخصي';
  }

  @override
  String get classicsEmptyDescription => 'جارٍ تحميل أرشيف الكلاسيكيات';

  @override
  String get classicsEmptyTitle => 'لم يتم العثور على كلاسيكيات';

  @override
  String get classicsErrorTitle => 'فشل تحميل الكلاسيكيات';

  @override
  String get classicsUnavailableDescription =>
      'الكلاسيكيات متاحة فقط عند الاتصال بمحوّلات Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'بدّل إلى محوّل يدعم Funnelcake من الإعدادات للوصول إلى أرشيف الكلاسيكيات.';

  @override
  String get classicsUnavailableTitle => 'الكلاسيكيات غير متاحة';

  @override
  String get hashtagFeedEmptySubtitle => 'كن أول من ينشر فيديو بهذا الوسم!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'لم يتم العثور على فيديوهات لـ #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'قد يستغرق هذا بضع لحظات';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'جارٍ تحميل الفيديوهات عن #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'أضف وسومًا... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'عُد لاحقًا لمشاهدة محتوى جديد';

  @override
  String get newVideosTabEmptyTitle => 'لا توجد فيديوهات في الفيديوهات الجديدة';

  @override
  String get popularVideosContextTitle => 'الفيديوهات الرائجة';

  @override
  String get popularVideosEmptySubtitle => 'عُد لاحقًا لمشاهدة محتوى جديد';

  @override
  String get popularVideosEmptyTitle =>
      'لا توجد فيديوهات في الفيديوهات الرائجة';

  @override
  String get popularVideosErrorTitle => 'فشل تحميل الفيديوهات الرائجة';

  @override
  String get popularVideosFeedSourceLabel => 'مصدر التغذية الرائجة';

  @override
  String get trendingHashtagsLoading => 'جارٍ تحميل الوسوم...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'عرض الفيديوهات الموسومة بـ $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'صانع الفيديو: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'وصف الفيديو: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'رؤية Divine هي منحك خيارًا حقيقيًا في الخوارزميات. بدلاً من أن تكون محصورًا في خوارزمية واحدة غامضة، ستتمكّن من الاختيار بين طرق توصية متعددة:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'خط زمني بالترتيب الزمني من الصنّاع الذين تتابعهم';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'هذا يضعك في موضع التحكّم في انتباهك بدلاً من تركه للمنصّة. يجب أن تعرف كيف تُنسَّق تغذيتك وأن تملك القدرة على تغييرها متى شئت.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'تغذيات مخصّصة ينشئها المجتمع لمواضيع مثل الموسيقى أو الكوميديا أو الفن';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed => 'تغذية \"لك\" مخصّصة';

  @override
  String get forYouAlgorithmChoiceTitle => 'خوارزميتك، اختيارك';

  @override
  String get forYouAlgorithmChoiceTrending => 'المحتوى الرائج والشائع';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'إشارة قوية — كنت متفاعلاً بما يكفي للردّ';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'ينتبه Divine إلى كيفية تفاعلك مع المحتوى ليفهم ما يعجبك. في كل مرة تشاهد فيها فيديو أو تضيف تفاعلاً أو تترك تعليقًا أو تعيد نشره، يسجّل النظام ذلك.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'كيف يعمل';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'تشير الإجراءات المختلفة إلى مستويات اهتمام مختلفة:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'إذا لم تكوّن سجلّ مشاهدة بعد، نعرض لك مزيجًا مما هو شائع ورائج حاليًا إلى جانب الفيديوهات المرفوعة حديثًا. يمنحك هذا نقطة انطلاق رائعة للاستكشاف.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'كلما شاهدت وأعجبت وتفاعلت مع المحتوى، تصبح التوصيات أكثر تخصيصًا تدريجيًا. مع مرور الوقت، تُظهر لك تغذية \"لك\" فيديوهات من صنّاع ربما لم تكن لتكتشفهم بنفسك أبدًا.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'جديد في Divine؟';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'نحن نبني نظامًا مفتوحًا يمكن فيه للمطوّرين تنفيذ خوارزمياتهم الخاصة، ويمكنك اختيار أيّها تستخدم — أو الانسحاب تمامًا.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'مفتوح المصدر وشفّاف';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'إشارة متوسطة — طريقة سريعة لإظهار التقدير';

  @override
  String get forYouAlgorithmReactionsTitle => 'التفاعلات';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'أقوى إشارة — المشاركة مع متابعيك تأييد قوي';

  @override
  String get forYouAlgorithmSubtitle =>
      'مدعوم بـ Gorse، محرّك توصية مفتوح المصدر';

  @override
  String get forYouAlgorithmTitle => 'خوارزمية Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'إشارة خفيفة — تدل على اهتمام أساسي';

  @override
  String get forYouEmptyDescription =>
      'شاهد بعض الفيديوهات وأعجب بها للحصول على توصيات مخصّصة.';

  @override
  String get forYouEmptyTitle => 'لا توجد توصيات بعد';

  @override
  String get forYouErrorTitle => 'فشل تحميل التوصيات';

  @override
  String get forYouUnavailableDescription =>
      'تتطلّب التوصيات المخصّصة الاتصال بـ Funnelcake.';

  @override
  String get forYouUnavailableTitle => '\"لك\" غير متاحة';

  @override
  String get inboxConversationOptionsLabel => 'خيارات';

  @override
  String get inboxConversationViewProfileButton => 'عرض الملف الشخصي';

  @override
  String get inboxMessageRequestsEmpty => 'لا توجد طلبات رسائل';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'طلبات الرسائل، $requestCount قيد الانتظار';
  }

  @override
  String get inboxMessageRequestsTitle => 'طلبات الرسائل';

  @override
  String get inboxMessagesTab => 'الرسائل';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'طلب رسالة من $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'أرسل طلب رسالة';

  @override
  String get inboxRequestsMarkAllRead => 'وسم جميع الطلبات كمقروءة';

  @override
  String get inboxRequestsRemoveAll => 'إزالة جميع الطلبات';

  @override
  String get messageRequestDeclineAndRemoveButton => 'رفض وإزالة';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'تم رفض طلب $displayName';
  }

  @override
  String get messageRequestLoadFailed => 'تعذّر تحميل هذا الطلب.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count متابِع';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count فيديو';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      many: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
      zero: 'لا رسائل',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'عرض الرسائل';

  @override
  String get messageRequestViewProfileButton => 'عرض الملف الشخصي';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName يريد مراسلتك، وقد أرسل $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'لقد بدّلت الحسابات، لذا لم يُحذف أي شيء. أعد فتح الحذف للحساب الذي تريد إزالته.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'للتأكيد، اكتب:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'للتأكيد، اكتب اسم المستخدم الخاص بك:';

  @override
  String get deleteAccountConfirmationHint => 'اكتب DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'اكتب اسم المستخدم الخاص بك';

  @override
  String get deleteAccountDeleteAllContentButton => 'حذف كل المحتوى';

  @override
  String get accountDeletionRecoveryTitle => 'جارٍ حذف حسابك';

  @override
  String get accountDeletionRecoveryBody =>
      'تعذّر علينا إكمال حذف حسابك. اسم المستخدم الخاص بك محجوز لك ولا يزال من الممكن استعادته.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'استعادة اسم المستخدم';

  @override
  String get accountDeletionFinishingBody =>
      'لا يزال طلب حذف حسابك قيد المعالجة. يمكنك استخدام حساب آخر إلى أن ننتهي.';

  @override
  String get accountDeletionOtherAccountPending =>
      'لا تزال عملية حذف حساب آخر قيد المعالجة على هذا الجهاز. انتظر حتى تنتهي قبل حذف هذا الحساب.';

  @override
  String get accountDeletionCancellingBody =>
      'نُلغي طلب الحذف الآن. يُرجى التحقق مرّة أخرى قبل مغادرة هذه الشاشة.';

  @override
  String get accountDeletionRecoveryFailed =>
      'تعذّرت استعادة اسم المستخدم حتى الآن. يُرجى التحقق من الاتصال والمحاولة مرّة أخرى.';

  @override
  String get accountDeletionUsernameRestored =>
      'تمّت استعادة اسم المستخدم. لم يُحذف حسابك.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'تعذّر التحقق من حالة الحذف. يُرجى التحقق من الاتصال والمحاولة مرّة أخرى.';

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
      'حذف الحساب غير متاح الآن. لم يتم حذف أي شيء.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'تعذّر علينا إكمال حذف حسابك. حاول مرّة أخرى.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ التأكيد النهائي';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'تم إرسال طلبات الحذف، لكن قد لا تكون مفاتيحك أُزيلت بالكامل من هذا الجهاز. اذهب إلى الإعدادات ← مفاتيح Nostr ← إزالة المفاتيح لإعادة المحاولة.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'تم إرسال طلبات الحذف وتم تسجيل خروجك، لكن تعذّر إزالة بعض البيانات المحلية من هذا الجهاز.';

  @override
  String get deleteAccountPreparingDeletion => 'جارٍ التحضير للحذف...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total حدث';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'هذا يزيل تسجيل الدخول المحلي لهذا الحساب من هذا الجهاز. لن يحذف حسابك في Divine أو هويتك في Nostr.\n\nستبقى مسوداتك ومقاطعك محفوظة على هذا الجهاز لهذا الحساب. إذا كان هذا آخر حساب محلي لديك، فستعود إلى شاشة تسجيل الدخول.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'إزالة من الجهاز';

  @override
  String get deleteAccountRemoveKeysTitle => 'إزالة هذا الحساب من هذا الجهاز؟';

  @override
  String get deleteAccountReauthRequired =>
      'سجّل الدخول مرة أخرى لحذف حسابك. لم يُحذف أي شيء بعد.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'تم إرسال طلبات حذف منشوراتك، لكن لم نتمكّن من إكمال حذف حسابك. حاول مرّة أخرى بعد قليل.';

  @override
  String get deleteAccountSuccess =>
      'تم حذف حسابك على Divine. أُرسلت طلبات لحذف منشوراتك على Nostr، لكن قد تحتفظ بعض المرحّلات أو التطبيقات أو ذاكرات التخزين المؤقت بنسخ منها.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'تم طلب حذف الحساب. تعذّر تأكيد حذف بعض المنشورات الحالية بشكل فردي.';

  @override
  String get deleteAccountWarningBody =>
      'هذا يرسل طلبات حذف لحسابك ومحتواك، ويحذف حساب Divine الخاص بك عند الإمكان، ويسجّل خروجك من هذا الجهاز. قد تحتفظ بعض المحوّلات والعملاء وفهارس البحث بنسخ. تبقى الأجهزة الأخرى المسجّلة الدخول نشطة حتى تزيل المفاتيح منها.';

  @override
  String get findPeopleNoContacts =>
      'لم يتم العثور على جهات اتصال.\nابدأ بمتابعة الأشخاص لتراهم هنا.';

  @override
  String get geoBlockedCityLabel => 'المدينة';

  @override
  String get geoBlockedCountryLabel => 'الدولة';

  @override
  String get geoBlockedDefaultReason =>
      'هذه الخدمة غير متاحة في منطقتك بسبب اللوائح المحلية.';

  @override
  String get geoBlockedLegalNotice =>
      'نحترم قوانينك ولوائحك المحلية. يستند هذا التقييد إلى موقع عنوان IP الخاص بك.';

  @override
  String get geoBlockedRegionLabel => 'المنطقة';

  @override
  String get geoBlockedTitle => 'الخدمة غير متاحة';

  @override
  String get likedVideosEmpty => 'لا توجد فيديوهات معجب بها';

  @override
  String get likedVideosInvalidRoute => 'مسار غير صالح';

  @override
  String get likedVideosTitle => 'الفيديوهات المعجب بها';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'جارٍ إعادة محاولة الرفع…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'حفظ في المسودات';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'تم الحفظ في المسودات';

  @override
  String get uploadFailureSheetTitle => 'فشل الرفع';

  @override
  String get uploadFailureSheetTryAgainButton => 'حاول مرّة أخرى';

  @override
  String get videoEditorAudioImportAudio => 'استيراد صوت';

  @override
  String get videoEditorAudioImportFailed => 'فشل استيراد الصوت.';

  @override
  String get videoIconPlaceholderLabel => 'فيديو';

  @override
  String get publishErrorNotSignedIn => 'يرجى تسجيل الدخول لنشر الفيديوهات.';

  @override
  String get publishErrorNoRetry => 'لا يوجد رفع لإعادة محاولته.';

  @override
  String get publishErrorNoInternet =>
      'لا يوجد اتصال بالإنترنت. تحقّق من Wi-Fi أو بيانات الجوال وحاول مرّة أخرى.';

  @override
  String get publishErrorServerUnreachable =>
      'تعذّر الوصول إلى الخادم. يرجى المحاولة مرّة أخرى بعد قليل.';

  @override
  String get publishErrorTimeout =>
      'انتهت مهلة الرفع. جرّب اتصالاً أقوى أو فيديو أصغر.';

  @override
  String get publishErrorTls =>
      'فشل الاتصال الآمن. تحقّق من شبكتك — قد تحجب شبكات Wi-Fi العامة عمليات الرفع.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'خادم الوسائط ($serverName) غير متاح. يمكنك اختيار خادم آخر من الإعدادات.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'ملف الفيديو أكبر من أن يقبله الخادم. جرّب قصّه أو خفض الجودة.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'واجه خادم الوسائط ($serverName) خطأً داخليًا. يمكنك اختيار خادم آخر من الإعدادات.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'خادم الوسائط ($serverName) متوقّف مؤقتًا. حاول مرّة أخرى بعد قليل أو اختر خادمًا آخر من الإعدادات.';
  }

  @override
  String get publishErrorForbidden => 'ليست لديك صلاحية الرفع إلى هذا الخادم.';

  @override
  String get publishErrorFileNotFound =>
      'تعذّر العثور على ملف الفيديو. ربّما تم حذفه. أعد التسجيل وحاول مرّة أخرى.';

  @override
  String get publishErrorLowStorage =>
      'لا توجد مساحة تخزين كافية على جهازك. فرّغ بعض المساحة وحاول مرّة أخرى.';

  @override
  String get publishErrorThumbnailFailed =>
      'تم رفع الفيديو، لكن تعذّر تجهيز الصورة المصغّرة. يرجى المحاولة مرّة أخرى.';

  @override
  String get publishErrorNostrPublishFailed =>
      'تم رفع الفيديو لكن تعذّر نشر المنشور. تحقّق من إعدادات المحوّلات وحاول مرّة أخرى.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'تم رفع الفيديو، لكن الصوت غير مسموح بإعادة استخدامه. اختر صوتًا آخر لنشره.';

  @override
  String get publishErrorInterrupted =>
      'تم قطع هذا الرفع. هل ترغب في المحاولة مرّة أخرى؟';

  @override
  String get publishErrorAccountChanged =>
      'هذا الفيديو يخصّ حسابًا آخر. ارجع إلى ذلك الحساب لنشره.';

  @override
  String get publishErrorGeneric => 'حدث خطأ ما. يرجى المحاولة مرّة أخرى.';

  @override
  String get publishErrorRateLimited =>
      'عمليات رفع كثيرة جدًا الآن. انتظر قليلًا وحاول مرّة أخرى.';

  @override
  String get publishErrorUploadSessionExpired =>
      'انتهت صلاحية جلسة الرفع. يرجى المحاولة مرّة أخرى.';

  @override
  String get publishErrorPermissionDenied =>
      'ليست لدى Divine صلاحية الرفع. تحقّق من أذونات التطبيق في إعدادات جهازك وحاول مرّة أخرى.';

  @override
  String get publishErrorOutOfMemory =>
      'ذاكرة جهازك منخفضة. أغلق بعض التطبيقات وحاول مرّة أخرى.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'تعذّر تجهيز النص والملصقات في هذه المسودة. افتحها في المحرّر ثم انشر مرّة أخرى.';

  @override
  String get publishErrorUnknownServer => 'خادم غير معروف';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'التصفية: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'لم يتم العثور على نتائج لـ \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'عرض الفيديوهات الموسومة بـ $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'الصوت: $soundName بواسطة $creatorName. اضغط لعرض تفاصيل الصوت.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'صوت أصلي بواسطة $creatorName. اضغط لاستخدام هذا الصوت.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'الصوت: $soundName بواسطة $creatorName. اضغط لعرض التفاصيل.';
  }

  @override
  String get soundDetailLoadError =>
      'فشل تحميل الصوت. يرجى المحاولة مرّة أخرى.';

  @override
  String get soundDetailNotFoundMessage => 'تعذّر العثور على هذا الصوت';

  @override
  String get soundDetailNotFoundTitle => 'الصوت غير موجود';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count تكرار';
  }

  @override
  String get originalSoundUnavailableBody =>
      'الصوت من هذا الفيديو غير متاح بشكل منفصل.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'صوت أصلي - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'نشر هذا الشخص مقطع Vine أصليًا عثرت عليه Divine في الأرشيف. هذه ليست شارة توثيق حساب.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'علامة الملف الشخصي';

  @override
  String get profileBadgeCheckmarkBody =>
      'تمنح Divine هذه العلامة لحسابات الفريق. وهي منفصلة عن NIP-05 وروابط الحسابات الموثّقة وحالة OG Viner.';

  @override
  String get unfollowConfirmButton => 'إلغاء المتابعة';

  @override
  String get videoClipSaveFailed => 'فشل حفظ المقطع';

  @override
  String videoClipSaveTo(String destination) {
    return 'حفظ في $destination';
  }

  @override
  String get videoClipDelete => 'حذف المقطع';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'مستوحى من $creatorName +$additionalCreatorCount. اضغط لعرض ملفه الشخصي.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'مستوحى من $creatorName. اضغط لعرض ملفه الشخصي.';
  }

  @override
  String get bugReportSendReport => 'إرسال التقرير';

  @override
  String get supportSubjectRequiredLabel => 'الموضوع *';

  @override
  String get supportPublicSubmissionTitle => 'منشور عام على GitHub';

  @override
  String get supportPublicSubmissionMessage =>
      'سيُنشر كل ما ترسله هنا في مستودعنا مفتوح المصدر على GitHub ليتمكن المطورون من العمل عليه. سيكون المنشور والحساب الذي سجّلت الدخول به متاحين للجميع علنًا.';

  @override
  String get supportRequiredHelper => 'مطلوب';

  @override
  String get supportFieldLimitReached =>
      'هذا هو الحد الأقصى للطول. لم تُضَف أي أحرف بعده.';

  @override
  String get bugReportSubjectHint => 'ملخّص قصير للمشكلة';

  @override
  String get bugReportDescriptionRequiredLabel => 'ماذا حدث؟ *';

  @override
  String get bugReportDescriptionHint => 'صِف المشكلة التي واجهتها';

  @override
  String get bugReportStepsLabel => 'خطوات إعادة الإنتاج';

  @override
  String get bugReportStepsHint =>
      '1. اذهب إلى...\n2. اضغط على...\n3. شاهد الخطأ';

  @override
  String get bugReportExpectedBehaviorLabel => 'السلوك المتوقّع';

  @override
  String get bugReportExpectedBehaviorHint =>
      'ماذا كان يجب أن يحدث بدلًا من ذلك؟';

  @override
  String get bugReportDiagnosticsNotice =>
      'ستُرفَق معلومات الجهاز والسجلات تلقائيًا.';

  @override
  String get bugReportSuccessMessage =>
      'شكرًا لك! استلمنا تقريرك وسنستخدمه لجعل Divine أفضل.';

  @override
  String get bugReportAttachImages => 'إرفاق صور';

  @override
  String bugReportImagesCount(int count, int max) {
    return 'تم اختيار $count من $max صور';
  }

  @override
  String get bugReportRemoveImage => 'إزالة الصورة';

  @override
  String get bugReportUploadFailed =>
      'تعذّر علينا رفع الصورة المختارة. حاول مرة أخرى أو أرسل التقرير بدونها.';

  @override
  String get bugReportSendFailed =>
      'فشل إرسال تقرير الخطأ. حاول مرّة أخرى لاحقًا.';

  @override
  String get featureRequestSendRequest => 'إرسال الطلب';

  @override
  String get featureRequestSubjectHint => 'ملخّص قصير لفكرتك';

  @override
  String get featureRequestDescriptionRequiredLabel => 'ماذا تودّ؟ *';

  @override
  String get featureRequestDescriptionHint => 'صِف الميزة التي تريدها';

  @override
  String get featureRequestUsefulnessLabel => 'كيف ستكون مفيدة؟';

  @override
  String get featureRequestUsefulnessHint =>
      'وضّح الفائدة التي ستقدّمها هذه الميزة';

  @override
  String get featureRequestWhenLabel => 'متى ستستخدمها؟';

  @override
  String get featureRequestWhenHint => 'صِف المواقف التي ستساعد فيها';

  @override
  String get featureRequestSuccessMessage =>
      'شكرًا لك! استلمنا طلب الميزة وسنراجعه.';

  @override
  String get featureRequestSendFailed =>
      'فشل إرسال طلب الميزة. حاول مرّة أخرى لاحقًا.';

  @override
  String get notificationFollowBack => 'متابعة بالمقابل';

  @override
  String get followingTitle => 'المتابَعون';

  @override
  String followingTitleForName(String displayName) {
    return 'متابَعو $displayName';
  }

  @override
  String get followingFailedToLoadList => 'فشل تحميل قائمة المتابَعين';

  @override
  String get followingEmptyTitle => 'لا تتابع أحدًا بعد';

  @override
  String get followersTitle => 'المتابِعون';

  @override
  String followersTitleForName(String displayName) {
    return 'متابِعو $displayName';
  }

  @override
  String get followersFailedToLoadList => 'فشل تحميل قائمة المتابعين';

  @override
  String get followersEmptyTitle => 'لا متابِعون بعد';

  @override
  String get followersUpdateFollowFailed =>
      'فشل تحديث حالة المتابعة. حاول مرّة أخرى.';

  @override
  String get followersSortSemanticLabel => 'ترتيب المتابِعين';

  @override
  String get followingSortSemanticLabel => 'ترتيب المتابَعين';

  @override
  String get followSortTitle => 'الترتيب حسب';

  @override
  String get followSortNewest => 'الأحدث أولاً';

  @override
  String get followSortOldest => 'الأقدم أولاً';

  @override
  String get newMessageTitle => 'رسالة جديدة';

  @override
  String get newMessageFindPeople => 'ابحث عن أشخاص';

  @override
  String get newMessageNoContacts => 'لا جهات اتصال.\nتابع الناس لتراهم هنا.';

  @override
  String get newMessageNoUsersFound => 'لم يُعثر على مستخدمين';

  @override
  String get hashtagSearchTitle => 'ابحث عن وسوم';

  @override
  String get hashtagSearchSubtitle => 'اكتشف المواضيع والمحتوى الرائج';

  @override
  String hashtagSearchNoResults(String query) {
    return 'لم يُعثر على وسوم لـ \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'فشل البحث';

  @override
  String get userNotAvailableTitle => 'الحساب غير متاح';

  @override
  String get userNotAvailableBody => 'هذا الحساب غير متاح في الوقت الحالي.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'فشل حفظ الإعدادات. يرجى المحاولة مرّة أخرى.';

  @override
  String get blossomValidServerUrl =>
      'أدخل رابط خادم صالحًا (مثال: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'تم حفظ إعدادات Blossom';

  @override
  String get blossomSaveTooltip => 'حفظ';

  @override
  String get blossomAboutTitle => 'عن Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom بروتوكول لتخزين الوسائط لامركزي يتيح لك رفع الفيديوهات إلى أي خادم متوافق. تُرفع الفيديوهات افتراضيًا إلى خادم Blossom الخاص بـ Divine. فعّل الخيار أدناه لاستخدام خادم مخصّص بدلًا من ذلك.';

  @override
  String get blossomUseCustomServer => 'استخدم خادم Blossom مخصّصًا';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'ستُرفع الفيديوهات إلى خادم Blossom المخصّص';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'تُرفع فيديوهاتك حاليًا إلى خادم Blossom الخاص بـ Divine';

  @override
  String get blossomCustomServerUrl => 'رابط خادم Blossom المخصّص';

  @override
  String get blossomCustomServerHelper => 'أدخل رابط خادم Blossom المخصّص';

  @override
  String get blossomPopularServers => 'خوادم Blossom الشائعة';

  @override
  String get blossomServerUrlMustUseHttps =>
      'يجب أن يستخدم رابط خادم Blossom https://';

  @override
  String get blueskyFailedToUpdateCrosspost => 'فشل تحديث إعداد النشر المتقاطع';

  @override
  String get blueskySignInRequired => 'سجّل الدخول لإدارة إعدادات Bluesky';

  @override
  String get blueskyPublishVideos => 'نشر الفيديوهات على Bluesky';

  @override
  String get blueskyEnabledSubtitle => 'ستُنشر فيديوهاتك على Bluesky';

  @override
  String get blueskyDisabledSubtitle => 'لن تُنشر فيديوهاتك على Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'سيتم نشر فيديوهاتك السابقة أيضًا';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'عند تفعيل هذا، سيبدأ Divine بإرسال فيديوهاتك الأقدم إلى Bluesky، من الأقدم أولًا، من دون استعجال حد اليوم.';

  @override
  String get blueskyHandle => 'معرّف Bluesky';

  @override
  String get blueskyDid => 'معرّف Bluesky DID';

  @override
  String get blueskyStatus => 'الحالة';

  @override
  String get blueskyStatusReady => 'تم تجهيز الحساب وهو جاهز';

  @override
  String get blueskyStatusPending => 'جاري تجهيز الحساب...';

  @override
  String get blueskyStatusFailed => 'فشل تجهيز الحساب';

  @override
  String get blueskyStatusDisabled => 'الحساب معطّل';

  @override
  String get blueskyStatusNotLinked => 'لا يوجد حساب Bluesky مرتبط';

  @override
  String get blueskyUsernameRequired =>
      'أعدّ معرّف divine.video قبل النشر على Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'يتطلب النشر على Bluesky معرّفًا محجوزًا بصيغة username.divine.video.';

  @override
  String get blueskyUsernameSyncPending =>
      'تم حجز معرّف Divine الخاص بك. نحن نربطه بـ Bluesky — حاول مرة أخرى بعد قليل.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'تعذّر علينا التحقق من معرّف Divine الخاص بك. حاول مرة أخرى.';

  @override
  String get blueskySetUpHandle => 'إعداد';

  @override
  String get blueskyTemporarilyUnavailable =>
      'النشر على Bluesky غير متاح مؤقتًا. حاول مرة أخرى.';

  @override
  String get invitesTitle => 'دعوة الأصدقاء';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دعوة جاهزة للإنشاء',
      many: '$count دعوة جاهزة للإنشاء',
      few: '$count دعوات جاهزة للإنشاء',
      two: 'دعوتان جاهزتان للإنشاء',
      one: 'دعوة واحدة جاهزة للإنشاء',
      zero: 'لا توجد دعوات جاهزة للإنشاء',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'أنشئ رمزًا عندما تكون مستعدًا لمشاركة واحد.';

  @override
  String get invitesGenerateButtonLabel => 'إنشاء دعوة';

  @override
  String get invitesNoneAvailable => 'لا توجد دعوات متاحة الآن';

  @override
  String get invitesShareWithPeople => 'شارك Divine مع من تعرفهم';

  @override
  String get invitesUsedInvites => 'الدعوات المستخدمة';

  @override
  String invitesShareMessage(String code) {
    return 'انضمّ إليّ على Divine! استخدم رمز الدعوة $code للبدء:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'نسخ الدعوة';

  @override
  String get invitesCopied => 'تم نسخ الدعوة!';

  @override
  String get invitesShareInvite => 'مشاركة الدعوة';

  @override
  String get invitesShareSubject => 'انضمّ إليّ على Divine';

  @override
  String get invitesClaimed => 'تم استخدامها';

  @override
  String get invitesCouldNotLoad => 'تعذّر تحميل الدعوات';

  @override
  String get invitesRetry => 'إعادة المحاولة';

  @override
  String get searchSomethingWentWrong => 'حدث خطأ ما';

  @override
  String get searchTryAgain => 'حاول مجددًا';

  @override
  String get searchForLists => 'البحث عن قوائم';

  @override
  String get searchFindCuratedVideoLists => 'ابحث عن قوائم فيديو مختارة';

  @override
  String get searchEnterQuery => 'أدخل استعلام البحث';

  @override
  String get searchDiscoverSomethingInteresting =>
      'اكتشف شيئًا مثيرًا للاهتمام';

  @override
  String get searchPeopleSectionHeader => 'الأشخاص';

  @override
  String get searchPeopleLoadingLabel => 'جارٍ تحميل نتائج الأشخاص';

  @override
  String get searchTagsSectionHeader => 'الوسوم';

  @override
  String get searchTagsLoadingLabel => 'جارٍ تحميل نتائج الوسوم';

  @override
  String get searchVideosSectionHeader => 'الفيديوهات';

  @override
  String get searchVideosLoadingLabel => 'جارٍ تحميل نتائج الفيديو';

  @override
  String get searchVideosSortOptionsLabel => 'ترتيب نتائج الفيديو';

  @override
  String get searchVideosSortTrending => 'الأكثر رواجًا';

  @override
  String get searchVideosSortLoops => 'الأكثر تكرارًا';

  @override
  String get searchVideosSortEngagement => 'الأكثر تفاعلاً';

  @override
  String get searchVideosSortRecent => 'الأحدث';

  @override
  String get searchListsSectionHeader => 'القوائم';

  @override
  String get searchListsLoadingLabel => 'جارٍ تحميل نتائج القوائم';

  @override
  String get cameraAgeRestriction =>
      'يجب أن يكون عمرك 16 عامًا أو أكثر لإنشاء محتوى';

  @override
  String get keyImportInsecureBunkerRelay =>
      'يجب أن يستخدم محول bunker بروتوكول wss:// (يُسمح بـ ws:// لـ localhost فقط)';

  @override
  String get timeNow => 'الآن';

  @override
  String timeShortMinutes(int count) {
    return '$count د';
  }

  @override
  String timeShortHours(int count) {
    return '$count س';
  }

  @override
  String timeShortDays(int count) {
    return '$count ي';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count أ';
  }

  @override
  String timeShortMonths(int count) {
    return '$count ش';
  }

  @override
  String timeShortYears(int count) {
    return '$count سن';
  }

  @override
  String get timeVerboseNow => 'الآن';

  @override
  String timeAgo(String time) {
    return 'منذ $time';
  }

  @override
  String get timeToday => 'اليوم';

  @override
  String get timeYesterday => 'أمس';

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    return 'منذ $count د';
  }

  @override
  String timeHoursAgo(int count) {
    return 'منذ $count س';
  }

  @override
  String timeDaysAgo(int count) {
    return 'منذ $count ي';
  }

  @override
  String get draftTimeJustNow => 'الآن';

  @override
  String get contentLabelNudity => 'عُري';

  @override
  String get contentLabelSexualContent => 'محتوى جنسي';

  @override
  String get contentLabelPornography => 'إباحية';

  @override
  String get contentLabelGraphicMedia => 'محتوى صادم';

  @override
  String get contentLabelViolence => 'عنف';

  @override
  String get contentLabelSelfHarm => 'إيذاء النفس/انتحار';

  @override
  String get contentLabelDrugUse => 'تعاطي المخدرات';

  @override
  String get contentLabelAlcohol => 'كحول';

  @override
  String get contentLabelTobacco => 'تبغ/تدخين';

  @override
  String get contentLabelGambling => 'قمار';

  @override
  String get contentLabelProfanity => 'ألفاظ بذيئة';

  @override
  String get contentLabelHateSpeech => 'خطاب كراهية';

  @override
  String get contentLabelHarassment => 'تحرّش';

  @override
  String get contentLabelFlashingLights => 'أضواء وامضة';

  @override
  String get contentLabelAiGenerated => 'محتوى مُولّد بالذكاء الاصطناعي';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'بريد مزعج';

  @override
  String get contentLabelScam => 'احتيال';

  @override
  String get contentLabelSpoiler => 'حرق أحداث';

  @override
  String get contentLabelMisleading => 'مُضلِّل';

  @override
  String get contentLabelSensitiveContent => 'محتوى حسّاس';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName أعجب بفيديوك';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName أعجب بتعليقك';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName علّق على فيديوك';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName بدأ بمتابعتك';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName أشار إليك';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName أعاد نشر فيديوك';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName نشر مقطعًا جديدًا';
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
      other: '$count من مقاطعك',
      many: '$count من مقاطعك',
      few: '$count من مقاطعك',
      two: 'مقطعيك',
      one: 'مقطعك',
      zero: 'مقاطعك',
    );
    return 'أضاف $actorName $_temp0 إلى $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName ردّ على تعليقك';
  }

  @override
  String get notificationAndConnector => 'و';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أشخاص آخرين',
      one: 'شخص آخر',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'لديك تحديث جديد';

  @override
  String get commentReplyToPrefix => 'رد:';

  @override
  String get commentHideKeyboard => 'إخفاء لوحة المفاتيح';

  @override
  String get commentsErrorLoadFailed => 'تعذّر تحميل التعليقات';

  @override
  String get commentsErrorNotAuthenticatedComment => 'سجّل الدخول للتعليق';

  @override
  String get commentsErrorPostCommentFailed => 'تعذّر نشر التعليق';

  @override
  String get commentsErrorPostReplyFailed => 'تعذّر نشر الرد';

  @override
  String get commentsErrorEditFailed => 'تعذّر تعديل التعليق';

  @override
  String get commentsErrorNotAuthenticatedInteract => 'سجّل الدخول للتفاعل';

  @override
  String get commentsErrorVoteFailed => 'تعذّر التصويت على التعليق';

  @override
  String get commentsErrorReportFailed => 'تعذّر الإبلاغ عن التعليق';

  @override
  String get commentsErrorBlockFailed => 'تعذّر حظر المستخدم';

  @override
  String get commentsErrorDeleteFailed => 'تعذّر حذف التعليق';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تعليق',
      many: '$count تعليقًا',
      few: '$count تعليقات',
      two: 'تعليقان',
      one: 'تعليق واحد',
      zero: 'لا توجد تعليقات',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'جارٍ النشر…';

  @override
  String get commentsVideoReplyPendingSemanticLabel => 'يتم نشر ردك بالفيديو';

  @override
  String get commentsSortNew => 'الأحدث';

  @override
  String get commentsSortTop => 'الأفضل';

  @override
  String get commentsSortOld => 'الأقدم';

  @override
  String get commentsSortSemanticLabel => 'ترتيب التعليقات';

  @override
  String get commentReply => 'رد';

  @override
  String get commentReplySemanticLabel => 'الرد على التعليق';

  @override
  String get commentUpvoteLabel => 'تصويت مؤيد للتعليق';

  @override
  String get commentRemoveUpvoteLabel => 'إزالة التصويت المؤيد';

  @override
  String get commentDownvoteLabel => 'تصويت معارض للتعليق';

  @override
  String get commentRemoveDownvoteLabel => 'إزالة التصويت المعارض';

  @override
  String get commentsInputHint => 'أضف تعليقًا...';

  @override
  String get commentsInputHintEdit => 'عدّل التعليق...';

  @override
  String get commentsEmptyTitle => 'لا توجد تعليقات بعد';

  @override
  String get commentsEmptySubtitle => 'ابدأ الحفلة!';

  @override
  String get draftUntitled => 'بدون عنوان';

  @override
  String get contentWarningNone => 'بلا';

  @override
  String get textBackgroundNone => 'بلا';

  @override
  String get textBackgroundSolid => 'مُصمَت';

  @override
  String get textBackgroundHighlight => 'تمييز';

  @override
  String get textBackgroundTransparent => 'شفاف';

  @override
  String get textAlignLeft => 'يسار';

  @override
  String get textAlignRight => 'يمين';

  @override
  String get textAlignCenter => 'وسط';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'الكاميرا غير مدعومة على الويب بعد';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'التقاط الكاميرا وتسجيلها غير متاحين في إصدار الويب بعد.';

  @override
  String get cameraPermissionBackToFeed => 'العودة إلى الخلاصة';

  @override
  String get cameraCouldNotStart => 'تعذّر تشغيل الكاميرا';

  @override
  String get cameraUnsupportedPlatform =>
      'الكاميرا غير متاحة على هذه المنصة بعد.\nلا يزال بالإمكان تصفّح الفيديوهات ومشاهدتها.';

  @override
  String get cameraPermissionErrorTitle => 'خطأ في الأذونات';

  @override
  String get cameraPermissionErrorDescription =>
      'حدث خطأ أثناء التحقق من الأذونات.';

  @override
  String get cameraPermissionRetry => 'إعادة المحاولة';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'السماح بالوصول إلى الكاميرا والميكروفون';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'يتيح لك هذا التقاط الفيديوهات وتعديلها مباشرة داخل التطبيق، ولا شيء أكثر.';

  @override
  String get cameraPermissionGoToSettings => 'الذهاب إلى الإعدادات';

  @override
  String get videoRecorderWhySixSecondsTitle => 'لماذا ست ثوانٍ؟';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'المقاطع القصيرة تفسح المجال للتلقائية. يساعدك التنسيق المدته 6 ثوانٍ على التقاط اللحظات الأصيلة فور حدوثها.';

  @override
  String get videoRecorderWhySixSecondsButton => 'فهمت!';

  @override
  String get videoRecorderUploadTitle => 'لماذا لا يوجد رفع؟';

  @override
  String get videoRecorderUploadBody =>
      'ما تراه على Divine من صنع البشر: خام وملتقط في اللحظة. بعكس المنصات التي تسمح بمقاطع منتجة بشكل مكثف أو مولّدة بالذكاء الاصطناعي، نُعطي الأولوية لأصالة تجربة الكاميرا المباشرة.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'بإبقاء عملية الإنشاء داخل التطبيق، يمكننا ضمان أن المحتوى حقيقي وغير معدّل بشكل أفضل. لا نفتح حاليًا عمليات الرفع من المعرض الخارجي لحماية تلك الأصالة والحفاظ على مجتمعنا خاليًا من المحتوى الاصطناعي قدر الإمكان.';

  @override
  String get videoRecorderUploadBodyCta =>
      'انتقل إلى Capture أو Classic لتصوير شيء حقيقي.';

  @override
  String get videoRecorderUploadLearnMore => 'تعرّف على آلية التحقق';

  @override
  String get videoRecorderAutosaveFoundTitle => 'وجدنا عملاً قيد التنفيذ';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'هل تريد المتابعة من حيث توقفت؟';

  @override
  String get videoRecorderAutosaveContinueButton => 'نعم، متابعة';

  @override
  String get videoRecorderAutosaveDiscardButton => 'لا، ابدأ فيديو جديد';

  @override
  String get videoRecorderAutosaveRestoreFailure => 'تعذر استعادة مسودتك';

  @override
  String get videoRecorderStopRecordingTooltip => 'إيقاف التسجيل';

  @override
  String get videoRecorderStartRecordingTooltip => 'بدء التسجيل';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'جاري التسجيل. اضغط في أي مكان للإيقاف';

  @override
  String get videoRecorderTapToStartLabel => 'اضغط في أي مكان لبدء التسجيل';

  @override
  String get videoRecorderDeleteLastClipLabel => 'حذف آخر مقطع';

  @override
  String get videoRecorderSwitchCameraLabel => 'تبديل الكاميرا';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'تكبير إلى $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'تبديل الشبكة';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'تبديل الإطار الشبحي';

  @override
  String get videoRecorderGhostFrameEnabled => 'الإطار الشبحي مفعّل';

  @override
  String get videoRecorderGhostFrameDisabled => 'الإطار الشبحي معطل';

  @override
  String get videoRecorderClipDeletedMessage => 'تم نقل المقطع إلى المهملات';

  @override
  String get videoRecorderClipUndoLabel => 'تراجع';

  @override
  String get libraryTrashEmptyTitle => 'المهملات فارغة';

  @override
  String get libraryTrashEmptySubtitle =>
      'تبقى المقاطع المحذوفة هنا لمدة 30 يومًا قبل إزالتها نهائيًا.';

  @override
  String get libraryTrashRestoreLabel => 'استعادة';

  @override
  String get libraryTrashDeleteNowLabel => 'حذف الآن';

  @override
  String get libraryTrashEmptyAllLabel => 'إفراغ المهملات';

  @override
  String get libraryTrashDeleteConfirmTitle => 'هل تريد حذف المقطع الآن؟';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'سيؤدي هذا إلى إزالة المقطع من سلة المهملات فورًا.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'إفراغ سلة المهملات؟';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقاطع',
      one: 'مقطع واحد',
    );
    return 'سيؤدي هذا إلى حذف $_temp0 نهائيًا من سلة المهملات فورًا.';
  }

  @override
  String get videoRecorderCloseLabel => 'إغلاق مسجل الفيديو';

  @override
  String get videoRecorderContinueToEditorLabel => 'المتابعة إلى محرر الفيديو';

  @override
  String get videoRecorderCameraPreviewLabel => 'معاينة الكاميرا';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'تركيز الكاميرا';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'التبديل إلى وضع $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => 'أضف صوتًا قبل التسجيل';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'تعذّر إنشاء الفيديو. حاول مرة أخرى.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تبقّت $count لقطة',
      many: 'تبقّت $count لقطة',
      few: 'تبقّت $count لقطات',
      two: 'تبقّت لقطتان',
      one: 'تبقّت لقطة واحدة',
      zero: 'لم تتبقَّ لقطات',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'تبديل الفلاش';

  @override
  String get videoRecorderCycleTimerLabel => 'تدوير المؤقت';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'تبديل نسبة العرض إلى الارتفاع';

  @override
  String get videoRecorderStabilizationLabel => 'تثبيت الفيديو';

  @override
  String get videoRecorderStabilizationModeOff => 'إيقاف';

  @override
  String get videoRecorderStabilizationModeStandard => 'قياسي';

  @override
  String get videoRecorderStabilizationModeCinematic => 'سينمائي';

  @override
  String get videoRecorderStabilizationModeCinematicExtended => 'سينمائي موسّع';

  @override
  String get videoRecorderStabilizationModePreviewOptimized => 'محسّن للمعاينة';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'زمن استجابة منخفض';

  @override
  String get videoRecorderStabilizationModeAuto => 'تلقائي';

  @override
  String get videoRecorderFlashValueOff => 'إيقاف';

  @override
  String get videoRecorderFlashValueOn => 'تشغيل';

  @override
  String get videoRecorderFlashValueAuto => 'تلقائي';

  @override
  String get videoRecorderTimerValueOff => 'إيقاف';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 ثوانٍ';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 ثوانٍ';

  @override
  String get videoRecorderAspectRatioValueSquare => 'مربع';

  @override
  String get videoRecorderAspectRatioValueVertical => 'عمودي';

  @override
  String get videoRecorderCameraValueFront => 'الكاميرا الأمامية';

  @override
  String get videoRecorderCameraValueBack => 'الكاميرا الخلفية';

  @override
  String get videoRecorderLibraryEmptyLabel => 'مكتبة المقاطع، لا توجد مقاطع';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'فتح مكتبة المقاطع، $clipCount مقاطع',
      one: 'فتح مكتبة المقاطع، مقطع واحد',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'فتح مكتبة الحركة الإيقافية، $frameCount إطار',
      many: 'فتح مكتبة الحركة الإيقافية، $frameCount إطارًا',
      few: 'فتح مكتبة الحركة الإيقافية، $frameCount إطارات',
      two: 'فتح مكتبة الحركة الإيقافية، إطاران',
      one: 'فتح مكتبة الحركة الإيقافية، إطار واحد',
      zero: 'فتح مكتبة الحركة الإيقافية',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'الكاميرا';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'فتح الكاميرا';

  @override
  String get videoEditorLibraryLabel => 'المكتبة';

  @override
  String get videoEditorTextLabel => 'النص';

  @override
  String get videoEditorDrawLabel => 'رسم';

  @override
  String get videoEditorFilterLabel => 'فلتر';

  @override
  String get videoEditorTuneLabel => 'ضبط';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'فتح محرر التعديلات';

  @override
  String get videoEditorTuneBrightness => 'السطوع';

  @override
  String get videoEditorTuneContrast => 'التباين';

  @override
  String get videoEditorTuneSaturation => 'التشبع';

  @override
  String get videoEditorTuneExposure => 'التعريض';

  @override
  String get videoEditorTuneHue => 'تدرج اللون';

  @override
  String get videoEditorTuneTemperature => 'درجة الحرارة';

  @override
  String get videoEditorTuneTint => 'الصبغة';

  @override
  String get videoEditorTuneFade => 'التلاشي';

  @override
  String get videoEditorAudioLabel => 'الصوت';

  @override
  String get videoEditorAddTitle => 'إضافة';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'فتح المكتبة';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'فتح محرر الصوت';

  @override
  String get videoEditorCaptionsLabel => 'الترجمات';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'فتح محرر الترجمات';

  @override
  String get videoEditorCaptionsBurnInLabel => 'دمج في الفيديو';

  @override
  String get videoEditorCaptionsPresetCustom => 'مخصص';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'نمط مخصص';

  @override
  String get videoEditorCaptionsCustomApply => 'تطبيق';

  @override
  String get videoEditorCaptionsCustomFont => 'الخط';

  @override
  String get videoEditorCaptionsCustomTextColor => 'لون النص';

  @override
  String get videoEditorCaptionsCustomBackground => 'الخلفية';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'لون الخلفية';

  @override
  String get videoEditorCaptionsCustomAnimation => 'الحركة';

  @override
  String get videoEditorCaptionsAnimationNone => 'بلا';

  @override
  String get videoEditorCaptionsAnimationFade => 'تلاشٍ';

  @override
  String get videoEditorCaptionsAnimationPop => 'ظهور';

  @override
  String get videoEditorCaptionsAnimationSpring => 'نابض';

  @override
  String get videoEditorCaptionsEditTitle => 'الترجمات';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'نستمع الآن…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'نحوّل صوتك إلى اقتراحات ترجمة.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'لم نسمع أي كلام. لا يزال بإمكانك كتابة الترجمات بنفسك.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'التعرف على الكلام غير متاح على هذا الجهاز. يمكنك كتابة الترجمات بنفسك.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'التعرف على الكلام غير مسموح به. فعّله من الإعدادات أو اكتب الترجمات بنفسك.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'لم ينجح التفريغ هذه المرة. يمكنك كتابة الترجمات بنفسك.';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'سأكتب الترجمات بنفسي';

  @override
  String get videoEditorCaptionsAddCue => 'إضافة ترجمة';

  @override
  String get videoEditorCaptionsCueTextHint => 'نص الترجمة';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'حذف الترجمة';

  @override
  String get videoEditorCaptionsDeleteTrack => 'إزالة كل الترجمات';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => 'إزالة الترجمات؟';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'سيُفقد كل النص والتوقيتات.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => 'إغلاق محرر الترجمات';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'تأكيد الترجمات';

  @override
  String get videoEditorCaptionsPresetTitle => 'أسلوب الترجمات';

  @override
  String get videoEditorCaptionsPresetClassic => 'كلاسيكي';

  @override
  String get videoEditorCaptionsPresetPop => 'بوب';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'نابض';

  @override
  String get videoEditorCaptionsPresetMono => 'أحادي';

  @override
  String get videoEditorCaptionsPresetHeadline => 'عنوان';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'آلة كاتبة';

  @override
  String get videoEditorCaptionsPresetMarker => 'قلم تحديد';

  @override
  String get videoEditorCaptionsPresetScript => 'خط مزخرف';

  @override
  String get videoEditorCaptionsPresetRetro => 'ريترو';

  @override
  String get videoEditorCaptionsPresetElegant => 'أنيق';

  @override
  String get videoEditorCaptionsPresetBubble => 'فقاعة';

  @override
  String get videoEditorCaptionsPresetNeon => 'نيون';

  @override
  String get videoEditorCaptionsPresetBold => 'عريض';

  @override
  String get videoEditorCaptionsPresetDreamy => 'حالم';

  @override
  String get videoEditorCaptionsPresetOcean => 'محيط';

  @override
  String get videoEditorCaptionsPresetSunny => 'مشمس';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'خط اليد';

  @override
  String get videoEditorCaptionsPresetSerif => 'سيريف';

  @override
  String get videoEditorCaptionsPresetStamp => 'ختم';

  @override
  String get videoEditorOpenTextSemanticLabel => 'فتح محرر النص';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'فتح محرر الرسم';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'فتح محرر الفلاتر';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'فتح محرر الملصقات';

  @override
  String get videoEditorSaveDraftTitle => 'حفظ المسودة؟';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'احفظ تعديلاتك لاحقًا، أو تجاهلها واخرج من المحرر.';

  @override
  String get videoEditorSaveDraftButton => 'حفظ المسودة';

  @override
  String get videoEditorDiscardChangesButton => 'تجاهل التغييرات';

  @override
  String get videoEditorKeepEditingButton => 'مواصلة التحرير';

  @override
  String get videoEditorDeleteLayerDropZone => 'منطقة إسقاط لحذف الطبقة';

  @override
  String get videoEditorReleaseToDeleteLayer => 'أفلت لحذف الطبقة';

  @override
  String get videoEditorDoneLabel => 'تم';

  @override
  String get videoEditorPlayPauseSemanticLabel =>
      'تشغيل الفيديو أو إيقافه مؤقتًا';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'موضع التقسيم غير صالح. يجب أن يكون كل مقطع $minDurationMs مللي ثانية على الأقل.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'حفظ المقطع المحدد';

  @override
  String get videoEditorSaveClip => 'حفظ المقطع';

  @override
  String get videoEditorClipSavedSuccess => 'تم حفظ المقطع في المكتبة';

  @override
  String get videoEditorClipSaveFailed => 'فشل حفظ المقطع';

  @override
  String get videoEditorColorPickerSemanticLabel => 'منتقي الألوان';

  @override
  String get videoEditorUndoSemanticLabel => 'تراجع';

  @override
  String get videoEditorRedoSemanticLabel => 'إعادة';

  @override
  String get videoEditorTextColorSemanticLabel => 'لون النص';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'محاذاة النص';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'خلفية النص';

  @override
  String get videoEditorFontSemanticLabel => 'الخط';

  @override
  String get videoEditorNoStickersFound => 'لم يتم العثور على ملصقات';

  @override
  String get videoEditorNoStickersAvailable => 'لا توجد ملصقات متاحة';

  @override
  String get videoEditorFailedLoadStickers => 'فشل تحميل الملصقات';

  @override
  String get videoEditorVoiceOverLabel => 'تعليق صوتي';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'تسجيل $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'تسجيل تعليق صوتي';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'بدء التسجيل';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'إيقاف التسجيل';

  @override
  String get videoEditorVoiceOverHint =>
      'انقر للتسجيل. أضِف أي عدد من اللقطات تريده.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تسجيلات',
      one: 'تسجيل واحد',
      zero: 'لا توجد تسجيلات بعد',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'حذف آخر تسجيل';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'يلزم الوصول إلى الميكروفون';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'اسمح بالوصول إلى الميكروفون لتسجيل تعليق صوتي.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'فتح الإعدادات';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'بدأ التسجيل';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'تم حفظ التسجيل';

  @override
  String get videoEditorVoiceOverTooLong => 'التسجيل أطول من الفيديو الخاص بك';

  @override
  String get videoEditorPlaySemanticLabel => 'تشغيل';

  @override
  String get videoEditorPauseSemanticLabel => 'إيقاف مؤقت';

  @override
  String get videoEditorVolumeSemanticLabel => 'ضبط مستوى الصوت';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'مستوى الصوت $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'اسحب للضبط';

  @override
  String get videoEditorChromaKeyLabel => 'الشاشة الخضراء';

  @override
  String get videoEditorChromaKeyTitle => 'الشاشة الخضراء';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'اضبط الشاشة الخضراء لهذا المقطع';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'تجاهل تغييرات الشاشة الخضراء';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'طبّق الشاشة الخضراء';

  @override
  String get videoEditorChromaKeyAutoDetect => 'كشف تلقائي';

  @override
  String get videoEditorChromaKeyPresetGreen => 'أخضر';

  @override
  String get videoEditorChromaKeyPresetBlue => 'أزرق';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'لون الخلفية';

  @override
  String get videoEditorChromaKeyAmountLabel => 'القوة';

  @override
  String get videoEditorChromaKeyAmountHint => 'مقدار ما يختفي من لون الخلفية';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'الحافة';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'ينعّم القص حتى لا يبدو الشعر مسنّنًا';

  @override
  String get videoEditorChromaKeySpillLabel => 'التسرّب';

  @override
  String get videoEditorChromaKeySpillHint => 'يزيل لون الخلفية عن الشخص';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'استبدلها بـ';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'لا شيء';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'لون';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'صورة';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'مقطع';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'الفيديو لا يحفظ الشفافية، لذا سيخرج هذا الجزء أسود.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'لم نعثر على خلفية. يجب أن تصل إلى حواف الإطار، وإلا فاختر اللون يدويًا.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'اختر مقطعًا';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'مكتبتك فارغة. احفظ مقطعًا أولًا ثم استخدمه كخلفية.';

  @override
  String get videoEditorChromaKeyImagePickFailed => 'تعذّر تحميل هذه الصورة.';

  @override
  String get videoEditorChromaKeyRemove => 'أزل الشاشة الخضراء';

  @override
  String get videoEditorChromaKeyFailed =>
      'تعذّر تطبيق الشاشة الخضراء. مقطعك كما هو دون تغيير.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'تعذّر إزالة الشاشة الخضراء. مقطعك كما هو دون تغيير.';

  @override
  String get videoEditorChromaKeyApplying => 'جارٍ تطبيق الشاشة الخضراء…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'لا يستطيع هذا الجهاز عرض المعاينة المباشرة. لكن إعداداتك ستُطبَّق عند التصدير.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'مقطع $index';
  }

  @override
  String get videoEditorDeleteLabel => 'حذف';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => 'حذف العنصر المحدد';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'الإطارات لكل صورة';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إطار',
      few: '$count إطارات',
      two: 'إطاران',
      one: 'إطار واحد',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'إطارات';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count إطارات لكل صورة';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'إطار الحركة الإيقافية $position من $total';
  }

  @override
  String get videoEditorEditLabel => 'تحرير';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'تحرير العنصر المحدد';

  @override
  String get videoEditorDuplicateLabel => 'تكرار';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'تكرار العنصر المحدد';

  @override
  String get videoEditorCombineLabel => 'دمج';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'دمج الرسومات المحددة في طبقة واحدة';

  @override
  String get videoEditorSplitLabel => 'تقسيم';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'تقسيم المقطع المحدد';

  @override
  String get videoEditorExtractAudioLabel => 'استخراج الصوت';

  @override
  String get videoEditorClipAudioTitle => 'صوت المقطع';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'استخراج الصوت من المقطع وكتم الصوت الأصلي';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'لا يمكن استخراج الصوت: المقطع غير متاح محليًا.';

  @override
  String get videoEditorExtractAudioFailed =>
      'تعذّر استخراج الصوت. يرجى المحاولة مجددًا.';

  @override
  String get videoEditorSpeedLabel => 'السرعة';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'تعيين سرعة التشغيل للمقطع المحدد';

  @override
  String get videoEditorReverseLabel => 'عكس';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'تبديل تشغيل المقطع المحدد بشكل معكوس';

  @override
  String get videoEditorReverseProgressLabel =>
      'لحظة من فضلك، نحن نعكس المقطع الخاص بك';

  @override
  String get videoEditorTransformLabel => 'تحويل';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'قص أو تدوير أو قلب المقطع المحدد';

  @override
  String get videoEditorTransformProgressLabel => 'لحظة، نقوم بتحويل مقطعك';

  @override
  String get videoEditorTransformFailed =>
      'تعذّر تحويل المقطع. يرجى المحاولة مرة أخرى.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'لا يمكن التحويل: المقطع غير متوفر محليًا.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'قص الإطار المحدد أو تدويره أو قلبه';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'لحظة واحدة، نحن نحوّل إطارك';

  @override
  String get videoEditorTransformFrameFailed =>
      'تعذّر تحويل الإطار. يرجى المحاولة مرة أخرى.';

  @override
  String get videoEditorTransformRotateLabel => 'تدوير';

  @override
  String get videoEditorTransformFlipLabel => 'قلب';

  @override
  String get videoEditorTransformResetLabel => 'إعادة تعيين';

  @override
  String get videoEditorTransformApplySemanticLabel => 'تطبيق التحويل';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'إلغاء التحويل';

  @override
  String get videoEditorTransformPlayLabel => 'تشغيل';

  @override
  String get videoEditorTransformPauseLabel => 'إيقاف مؤقت';

  @override
  String get videoEditorReverseNoLocalFile =>
      'لا يمكن العكس: المقطع غير متاح محليًا.';

  @override
  String get videoEditorReverseFailed =>
      'تعذّر عكس المقطع. يرجى المحاولة مجددًا.';

  @override
  String get videoEditorSpeedSheetTitle => 'سرعة المقطع';

  @override
  String get videoEditorTransitionSheetTitle => 'انتقال';

  @override
  String get videoEditorTransitionNone => 'بلا';

  @override
  String get videoEditorTransitionDissolve => 'إذابة';

  @override
  String get videoEditorTransitionFadeToBlack => 'تلاشٍ إلى الأسود';

  @override
  String get videoEditorTransitionFadeToWhite => 'تلاشٍ إلى الأبيض';

  @override
  String get videoEditorTransitionSlide => 'انزلاق';

  @override
  String get videoEditorTransitionPush => 'دفع';

  @override
  String get videoEditorTransitionWipe => 'مسح';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'تعديل الانتقال';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'انتقال التكرار';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'تعديل انتقال التكرار';

  @override
  String get videoEditorTransitionDuration => 'المدة';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'تم تقصيرها لتجنّب التداخل مع الانتقال المجاور.';

  @override
  String get videoEditorTransitionCurve => 'المنحنى';

  @override
  String get videoEditorTransitionDirection => 'الاتجاه';

  @override
  String get videoEditorTransitionDirectionLeft => 'يسار';

  @override
  String get videoEditorTransitionDirectionRight => 'يمين';

  @override
  String get videoEditorTransitionDirectionUp => 'أعلى';

  @override
  String get videoEditorTransitionDirectionDown => 'أسفل';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'منحنى الرسوم المتحركة $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'الرسوم المتحركة';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'تحرير حركة الطبقة';

  @override
  String get videoEditorLayerAnimationEnter => 'دخول';

  @override
  String get videoEditorLayerAnimationLeave => 'خروج';

  @override
  String get videoEditorLayerAnimationFade => 'تلاشٍ';

  @override
  String get videoEditorLayerAnimationScale => 'تحجيم';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'التحجيم من';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'إنهاء تحرير الجدول الزمني';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'تشغيل المعاينة';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'إيقاف المعاينة مؤقتًا';

  @override
  String get videoEditorAudioUntitledSound => 'صوت بدون عنوان';

  @override
  String get videoEditorAudioUntitled => 'بدون عنوان';

  @override
  String get videoEditorAudioAddAudio => 'إضافة صوت';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'لا توجد أصوات متاحة';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'ستظهر الأصوات هنا عندما يشاركها المبدعون';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'فشل تحميل الأصوات';

  @override
  String get videoEditorAudioSegmentInstruction => 'حدّد مقطع الصوت لفيديوك';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'المجتمع';

  @override
  String get videoEditorAudioCategoryFeatured => 'مميز';

  @override
  String get videoEditorAudioCategoryMySounds => 'أصواتي';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'أداة السهم';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'أداة الممحاة';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'أداة الماركر';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'أداة القلم';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'إظهار الجدول الزمني';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'إخفاء الجدول الزمني';

  @override
  String get videoEditorFeedPreviewContent =>
      'تجنب وضع المحتوى خلف هذه المناطق.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine الأصلية';

  @override
  String get videoEditorStickerSearchHint => 'البحث في الملصقات...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'اختيار خط';

  @override
  String get videoEditorFontUnknown => 'غير معروف';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'يجب أن يكون رأس التشغيل داخل المقطع المحدد للتقسيم.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'قص البداية';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'قص النهاية';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'قص المقطع';

  @override
  String get videoEditorTimelineTrimClipHint => 'اسحب المقابض لضبط مدة المقطع';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'سحب المقطع $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'المقطع $index من $total، مدة $duration ثانية';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'اضغط مطولاً لإعادة الترتيب';

  @override
  String get videoEditorTimelineClipMoveLeft => 'تحريك لليسار';

  @override
  String get videoEditorTimelineClipMoveRight => 'تحريك لليمين';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'المقطع $index من $total، محدد';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'المقطع $index من $total، غير محدد';
  }

  @override
  String get videoEditorMultiSelectLabel => 'تحديد';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'تحديد عدة مقاطع';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'إنهاء التحديد';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count مقاطع',
      one: 'تم تحديد مقطع واحد',
      zero: 'لم يتم تحديد مقاطع',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel => 'تحديد عدة رسومات';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'إنهاء تحديد الرسومات';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'حذف الرسومات المحددة';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم تحديد $count رسمة',
      one: 'تم تحديد رسم واحد',
      zero: 'لم يتم تحديد أي رسم',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'دمج';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'دمج المقاطع المحددة';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'حذف المقاطع المحددة';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'حذف الإطارات المحددة';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'عكس الإطارات المحددة';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'تكرار الإطارات المحددة';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'يجب أن يكون الفيديو $seconds ثانية على الأقل — التقط بضعة إطارات إضافية.';
  }

  @override
  String get videoEditorMergeProgressLabel => 'لحظة من فضلك، نقوم بدمج مقاطعك';

  @override
  String get videoEditorMergeFailed =>
      'تعذّر دمج المقاطع. يُرجى المحاولة مرة أخرى.';

  @override
  String get videoEditorTimelineLongPressToDragHint => 'اضغط مطولاً للسحب';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'الجدول الزمني للفيديو';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutesد $secondsث';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName، محدد';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'إغلاق منتقي الألوان';

  @override
  String get videoEditorPickColorTitle => 'اختيار لون';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'تأكيد اللون';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => 'التشبع والسطوع';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'التشبع $saturation%، السطوع $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'الصبغة';

  @override
  String get videoEditorAddElementSemanticLabel => 'إضافة عنصر';

  @override
  String get videoEditorDoneSemanticLabel => 'تم';

  @override
  String get videoEditorLevelSemanticLabel => 'المستوى';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'إغلاق تفاصيل المنشور';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'إغلاق مربع حوار المساعدة';

  @override
  String get videoMetadataGotItButton => 'فهمت!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'تم الوصول إلى حد 64 كيلوبايت. أزل بعض المحتوى للمتابعة.';

  @override
  String get videoMetadataExpirationLabel => 'انتهاء الصلاحية';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'اختيار وقت انتهاء الصلاحية';

  @override
  String get videoMetadataTitleLabel => 'العنوان';

  @override
  String get videoMetadataDescriptionLabel => 'الوصف';

  @override
  String get videoMetadataTagsLabel => 'الوسوم';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'حذف الوسم $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'تحذير المحتوى';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'اختيار تحذيرات المحتوى';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'اختر كل ما ينطبق على محتواك';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'اسمح للآخرين بحفظ صوت هذا الفيديو وإعادة استخدامه.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'تم نشر فيديوك، لكن الصوت لم يُنشر. عدّل الفيديو لمشاركته.';

  @override
  String get videoMetadataCollaboratorsLabel => 'المتعاونون';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'إضافة متعاون';

  @override
  String get videoMetadataMutualFollowersSearchText => 'المتابعون المتبادلون';

  @override
  String get videoMetadataInspiredByLabel => 'مستلهم من';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'تحديد مصدر الإلهام';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'لا يمكن الإشارة إلى هذا المبدع.';

  @override
  String get videoMetadataPostDetailsTitle => 'تفاصيل المنشور';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'تم الحفظ في المكتبة';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'فشل الحفظ';

  @override
  String get videoMetadataGoToLibraryButton => 'الذهاب إلى المكتبة';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'زر الحفظ لاحقًا';

  @override
  String get videoMetadataSavingVideoHint => 'جاري حفظ الفيديو...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'حفظ الفيديو في المسودات و$destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'حفظ الفيديو في المسودات. لا يوجد فيديو مُعالَج بعد، لذا لن تُضاف نسخة إلى $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'حفظ لاحقًا';

  @override
  String get videoMetadataPostSemanticLabel => 'زر النشر';

  @override
  String get videoMetadataPublishVideoHint => 'نشر الفيديو في الخلاصة';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'شارك أيضًا في موجزي';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'إيقافه يبقي هذا الفيديو داخل سلسلة التعليقات فقط.';

  @override
  String get videoMetadataFormNotReadyHint => 'أكمل النموذج للتفعيل';

  @override
  String get videoMetadataPostButton => 'نشر';

  @override
  String get videoMetadataOpenPreviewSemanticLabel => 'فتح شاشة معاينة المنشور';

  @override
  String get videoMetadataShareTitle => 'مشاركة';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'تفاصيل الفيديو';

  @override
  String get videoMetadataClassicDoneButton => 'تم';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'تشغيل المعاينة';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'إيقاف المعاينة مؤقتًا';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'إغلاق معاينة الفيديو';

  @override
  String get videoMetadataRemoveSemanticLabel => 'إزالة';

  @override
  String get fullscreenFeedRemovedMessage => 'تمت إزالة الفيديو';

  @override
  String get fullscreenFeedEmptyMessage => 'لم يتبقَّ شيء لتشغيله هنا';

  @override
  String get settingsBadgesTitle => 'الشارات';

  @override
  String get settingsBadgesSubtitle =>
      'اقبل الجوائز وتحقّق من حالة الشارات الممنوحة.';

  @override
  String get badgesTitle => 'الشارات';

  @override
  String get badgesLoadError => 'تعذّر تحميل الشارات';

  @override
  String get badgesUpdateError => 'تعذّر تحديث الشارة';

  @override
  String get badgesAwardedEmptyTitle => 'لا جوائز شارات بعد';

  @override
  String get badgesAwardedEmptySubtitle =>
      'عندما يمنحك أحدهم شارة Nostr، ستصلك هنا.';

  @override
  String get badgesStatusAccepted => 'مقبولة';

  @override
  String get badgesStatusNotAccepted => 'غير مقبولة';

  @override
  String get badgesActionRemove => 'إزالة';

  @override
  String get badgesActionAccept => 'قبول';

  @override
  String get badgesActionReject => 'رفض';

  @override
  String get badgesIssuedEmptyTitle => 'لا شارات ممنوحة بعد';

  @override
  String get badgesIssuedEmptySubtitle =>
      'ستظهر هنا حالة قبول الشارات التي تمنحها.';

  @override
  String get badgesIssuedNoRecipients => 'لم يُعثر على مستلمين لهذه الجائزة.';

  @override
  String get badgesRecipientAcceptedStatus => 'قبِلها المستلم';

  @override
  String get badgesRecipientWaitingStatus => 'بانتظار المستلم';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مخفية ($count)',
      one: 'مخفية (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'استعادة';

  @override
  String get badgesHiddenSnackbar => 'تم إخفاء الشارة';

  @override
  String get badgesHiddenSnackbarUndo => 'تراجع';

  @override
  String get badgesTabAwarded => 'المستلمة';

  @override
  String get badgesTabCreated => 'التي أنشأتها';

  @override
  String get badgesTabIssued => 'التي منحتها';

  @override
  String get badgesCreateAction => 'شارة جديدة';

  @override
  String get badgesCreatedEmptyTitle => 'لم تصنع أي شارة بعد';

  @override
  String get badgesCreatedEmptySubtitle => 'اصنع واحدة وامنحها لمن يستحقها.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مُنحت لـ $count أشخاص',
      one: 'مُنحت لشخص واحد',
      zero: 'لم تُمنح بعد',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'شارة جديدة';

  @override
  String get badgeEditorEditTitle => 'تعديل الشارة';

  @override
  String get badgeEditorNameLabel => 'الاسم';

  @override
  String get badgeEditorNameHint => 'خاطف الأضواء';

  @override
  String get badgeEditorIdentifierLabel => 'المعرّف';

  @override
  String get badgeEditorIdentifierHelp =>
      'هو جزء من عنوان الشارة، لذلك لا يتغير بعد إنشائها.';

  @override
  String get badgeEditorIdentifierTaken =>
      'لديك بالفعل شارة بهذا المعرّف. عدّل تلك الشارة — فالنشر هنا سيحل محلها.';

  @override
  String get badgeEditorIdentifierRequired =>
      'كل شارة تحتاج معرّفًا — اكتب واحدًا إن لم يملأه الاسم.';

  @override
  String get badgeEditorDescriptionLabel => 'الوصف';

  @override
  String get badgeEditorDescriptionHint => 'لمن يخطف الأنظار بمقطع واحد فقط.';

  @override
  String get badgeEditorArtworkLabel => 'الصورة';

  @override
  String get badgeEditorArtworkAdd => 'إضافة صورة';

  @override
  String get badgeEditorArtworkReplace => 'استبدال';

  @override
  String get badgeEditorArtworkError => 'تعذّر رفع هذه الصورة';

  @override
  String get badgeEditorArtworkRequired => 'كل شارة تحتاج إلى صورة.';

  @override
  String get badgeEditorArtworkRemove => 'إزالة الصورة';

  @override
  String get badgeEditorArtworkSheetTitle => 'صورة الشارة';

  @override
  String get badgeDetailDeleteAction => 'حذف الشارة';

  @override
  String get badgeDetailDeleteTitle => 'هل تحذف هذه الشارة؟';

  @override
  String get badgeDetailDeleteBody =>
      'يطلب هذا من المُرحِّلات إسقاط الشارة وكل ما منحته منها. يمكن للمُرحِّلات أن ترفض، ومن ثبّتها على ملفه يحتفظ بها حتى يزيلها بنفسه.';

  @override
  String get badgeDetailDeleteConfirm => 'حذف';

  @override
  String get badgeEditorSaveAction => 'نشر الشارة';

  @override
  String get badgeEditorSaveError => 'تعذّر نشر الشارة';

  @override
  String get badgeEditorLoadError => 'تعذّر تحميل هذه الشارة';

  @override
  String get badgeDetailTitle => 'شارة';

  @override
  String get badgeDetailMadeBy => 'من صنعها';

  @override
  String get badgeDetailRecipientsTitle => 'مُنحت لـ';

  @override
  String get badgeDetailNoRecipients => 'لا أحد يملكها بعد.';

  @override
  String get badgeDetailAwardAction => 'امنح هذه الشارة';

  @override
  String get badgeDetailEditAction => 'تعديل الشارة';

  @override
  String get badgeDetailShareAction => 'مشاركة';

  @override
  String badgeDetailShareMessage(String link) {
    return 'شاهد هذه الشارة على Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'استرجاع الشارة';

  @override
  String get badgeDetailRevokeTitle => 'تسترجع هذه الشارة؟';

  @override
  String get badgeDetailRevokeBody =>
      'يطلب هذا من المُرحِّلات إسقاط ما منحته لهذا الشخص. يمكن للمُرحِّلات أن ترفض، وإن كان قد ثبّت الشارة على ملفه فستبقى هناك حتى يزيلها بنفسه. وفي كل الأحوال لن يُخطر بذلك.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'يطلب هذا من المُرحِّلات إسقاط ما منحته لنفسك، ويزيل الشارة من ملفك. وإن رفضت المُرحِّلات الحذف، فلن يتغيّر شيء.';

  @override
  String get badgeDetailRevokeConfirm => 'استرجاع';

  @override
  String get badgeDetailRevokeSuccess => 'تم استرجاع الشارة';

  @override
  String get badgeDetailBlockClaimantsAction => 'حظر من يضعون الشارة';

  @override
  String get badgeDetailBlockClaimantsTitle => 'حظر من يضعون الشارة';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'تعذّر تحميل من يضعون هذه الشارة';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'لا أحد يضع هذه الشارة الآن';

  @override
  String get badgeDetailBlockClaimantsEmptyBody => 'لم نجد أحدًا لحظره الآن.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حظر $count حسابات؟',
      one: 'حظر حساب واحد؟',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ستُحظر $count حسابات تضع هذه الشارة الآن. لن تظهر منشوراتها في تغذياتك ولن يتم إبلاغها.',
      one:
          'سيُحظر الحساب الذي يضع هذه الشارة الآن. لن تظهر منشوراته في تغذياتك ولن يتم إبلاغه.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حظر $count حسابات',
      one: 'حظر حساب واحد',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'تم حظر من يضعون الشارة';

  @override
  String get badgeDetailBlockClaimantsFailure => 'تعذّر حظر من يضعون الشارة';

  @override
  String get badgeDetailLoadError => 'تعذّر تحميل هذه الشارة';

  @override
  String get badgeDetailMissing => 'لم نجد هذه الشارة على أي مُرحِّل.';

  @override
  String get badgeDetailActionError => 'لم تنجح العملية';

  @override
  String get badgeAwardTitle => 'منح شارة';

  @override
  String get badgeAwardPickAction => 'اختر أشخاصًا';

  @override
  String get badgeAwardManualLabel => 'أو الصق المفاتيح';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'اختر شخصًا واحدًا على الأقل.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'امنحها لـ $count أشخاص',
      one: 'امنحها لشخص واحد',
      zero: 'امنح الشارة',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'من منحها';

  @override
  String get profileBadgeRecipients => 'المستلمون';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count آخرين';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'شارة $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'شارة';

  @override
  String get profileBadgeFooterBody =>
      'الشارات جوائز صغيرة يمكن لأي شخص إنشاؤها على Nostr. امنح واحدة لصديق أو لصانع محتوى أو لشخص أسعد يومك.';

  @override
  String get profileBadgeFooterLink => 'أنشئ شارتك الخاصة';

  @override
  String get minorAccountReviewWelcomePageTitle => 'دليل العائلة';

  @override
  String get minorAccountReviewWelcomeTitle => 'لم تبلغ 16 بعد؟ لا بأس.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'دخولك إلى هذه الصفحة بدل أن تختار ببساطة الإجابة التي تُدخلك أمر مهم. إنه يدل على الصدق والشجاعة والاهتمام الحقيقي بمن حولك.\n\nالقواعد الخاصة بمن هم دون 16 تختلف حسب مكان إقامتك. في Divine نريد للعائلات أن تتحدث في الأمر معًا وتقرر كيف يبدو الاستخدام الصحي لوسائل التواصل الاجتماعي.';

  @override
  String get minorAccountReviewModerationTitle => 'نحتاج خطوة أخرى';

  @override
  String get minorAccountReviewModerationBody =>
      'طُلب منا إلقاء نظرة أدق على هذا الحساب لأنه قد يعود لشخص دون 16 عامًا. هذا المسار يبقي الخطوات التالية خاصة ويوجّهك إلى الطريق المناسب لعمرك.';

  @override
  String get minorAccountReviewRulesTitle => 'القواعد ليست واحدة في كل مكان';

  @override
  String get minorAccountReviewRulesBody =>
      'تتعامل الدول والمناطق المختلفة مع استخدام المراهقين لوسائل التواصل بطرق مختلفة. لذلك نطلب من العائلات التمهّل والتحقق من الحقائق واختيار الخطوة التالية معًا.';

  @override
  String get minorAccountReviewApproachTitle => 'كيف ينظر Divine إلى الأمر';

  @override
  String get minorAccountReviewApproachBody =>
      'نعتقد أن العادات الصحية مع التقنية تأتي من التوقف والتأمل وتوجيه الانتباه نحو أشياء أفضل، لا من التجسس على الأبناء أو تحويل الآباء إلى مراقبين. والأبحاث تدعم ذلك أيضًا.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'المزيد للعائلات';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'اقرأ سياسة Divine الخاصة بالأطفال';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'اختر المسار المناسب';

  @override
  String get minorAccountReviewUnder13Cta => 'أقل من 13';

  @override
  String get minorAccountReviewTeenCta => 'من 13 إلى 15 عامًا';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'زر دليل Divine للعائلات للحصول على نصائح عملية وأدوات للحوار وموارد تساعد المراهقين على استخدام وسائل التواصل بأمان أكبر.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'احصل على أدلة ونصائح للعائلات';

  @override
  String get minorAccountReviewFooter =>
      'إذا كنت في 16 أو أكبر ووصلت إلى هنا بالخطأ، تواصل مع دعم Divine ليراجع الأمر شخص حقيقي.';

  @override
  String get minorAccountReviewTitle => 'مراجعة الحساب';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'جارٍ التحقق من حالة الحساب...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'يرجى الانتظار بينما نؤكد حالة المراجعة الحالية لهذا الحساب.';

  @override
  String get minorAccountReviewDefaultTitle => 'مطلوب مراجعة الحساب';

  @override
  String get minorAccountReviewDefaultBody =>
      'علينا مراجعة هذا الحساب قبل أن يتمكن من استخدام Divine بشكل طبيعي.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'رقم الحالة: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'رقم الحالة';

  @override
  String get minorAccountReviewRestrictionsTitle => 'ما هو مقيّد الآن';

  @override
  String get minorAccountReviewRestrictionPosting => 'النشر متوقف مؤقتًا';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'التعليقات والإعجابات وإعادة النشر والمتابعات متوقفة مؤقتًا';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'بدء الرسائل العادية أو الرد عليها متوقف مؤقتًا';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'الدعم ورسالة الإشراف الخاصة بك تبقى متاحة';

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
  String get minorAccountReviewOpenSupportCenter => 'فتح مركز الدعم';

  @override
  String get minorAccountReviewOpenModerationMessage => 'فتح رسالة الإشراف';

  @override
  String get minorAccountReviewOpenReviewPage => 'فتح صفحة المراجعة';

  @override
  String get minorAccountReviewCheckAgain => 'تحقق مرة أخرى';

  @override
  String get minorAccountReviewLogOut => 'تسجيل الخروج';

  @override
  String get minorAccountReviewNextStepTitle => 'الخطوة التالية';

  @override
  String get minorAccountReviewNextStepBody =>
      'افتح مركز الدعم أو رسالة الإشراف إذا احتجت مساعدة بشأن هذه المراجعة.';

  @override
  String get minorAccountReviewInProgressTitle => 'المراجعة جارية';

  @override
  String get minorAccountReviewInProgressBody =>
      'لدينا ما نحتاجه في الوقت الحالي. يراجع فريقنا هذه الحالة قبل إعادة الوصول الطبيعي إلى الحساب.';

  @override
  String get minorAccountReviewUnder13Title => 'حسابات أقل من 13';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'إذا كان هذا الحساب يعود لشخص دون 13 عامًا، فيجب على أحد الوالدين أو الوصي مراسلة $supportEmail مع ذكر رقم الحالة.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'لا يمكننا منحك حسابًا بعد';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine ليس مصممًا للأطفال دون 13 عامًا، وقواعد وسائل التواصل حول العالم تقيّد أيدينا.\n\nأشياء كثيرة على الإنترنت تدفعك للكذب كي تحصل على ما تريد، ونحن نكره ذلك. إنه الدرس الخاطئ في الحياة، ولن نعلّمك إياه هنا.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'ما يمكن لعائلتك فعله بدلاً من ذلك';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'يمكن لأحد الوالدين أو الوصي أن يملك الحساب ويتولى النشر، ويمكنك بالتأكيد أن تظهر في الفيديوهات معهم. نريد للعائلات أن تستمتع بـ Divine بالطريقة التي تناسبها.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'عندما تبلغ 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'حسب القواعد في المكان الذي تعيش فيه، قد تتمكن من العودة وطلب حساب خاص بك. وفي تلك الحالة، إذا كان عمرك بين 13 و15، ستحتاج موافقة أحد الوالدين أو الوصي.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'لماذا لن نطلب منك ببساطة الرجوع';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'الكثير من الإنترنت مُصمَّم لمكافأة الناس على قول أي شيء يعبرهم البوابة. لا نظن أن هذا أمر جيد. نعم، يمكنك الرجوع والقول إنك أكبر سنًا مما أنت عليه، لكن ذلك لن يكون صادقًا، ولن ندرّبك على الكذب لتحصل على ما تريد.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'نحاول مساعدة الشباب على استخدام Divine بطرق صحية وإيجابية لهم وللأشخاص من حولهم. علينا أيضًا اتباع قوانين تختلف من مكان لآخر. لذا، إذا كنت دون 13 عامًا، فالجواب هو أنه لا يمكنك امتلاك حسابك الخاص اليوم.';

  @override
  String get minorAccountReviewTeenBody =>
      'إذا كان هذا الحساب يعود لشخص بين 13 و15 عامًا، استخدم رسالة الإشراف أو مسار الدعم لاتباع تعليمات موافقة الوالدين.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'إذا كان الحساب سيعود لشخص بين 13 و15';

  @override
  String get minorAccountReviewParentConsentBody =>
      'يجب أن يرسل أحد الوالدين أو ولي الأمر بريدًا إلكترونيًا إلى دعم Divine مع فيديو خاص قصير. سيراجعه فريقنا ويساعدك في الخطوات التالية.\n\nإذا كان التواصل مع أحد الوالدين أو ولي الأمر غير ممكن أو قد يعرّض أحدًا للخطر، راسل دعم Divine وأخبرنا.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'هذه وقفة مؤقتة ريثما يراجع فريق دعم Divine الفيديو. إذا تمت الموافقة عليه، سيرشدك الفريق خلال إعداد الحساب الجديد.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'لماذا نطلب مشاركة أحد الوالدين أو ولي الأمر';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'على Divine اتباع القوانين المتعلّقة بالعمر حول العالم. نعلم أيضًا أن معظم بوابات التحقق من العمر التقنية غير مثالية. بدلاً من التظاهر بأن القواعد غير موجودة أو أن الكذب بشأن عمرك أمر رائع، نريد من المراهقين والعائلات اتخاذ قرارات مدروسة حول أفضل طريقة لاستخدام Divine. لهذا السبب، بالنسبة لمن هم بين 13 و15 عامًا، نطلب من الوالدين أن يكونوا جزءًا من عملية إنشاء الحساب.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'علينا أيضًا اتباع القانون، وتلك القواعد تختلف تبعًا لمكان إقامة الشخص. لذا بدلاً من التظاهر بأن القواعد غير موجودة، نطلب أن يكون أحد الوالدين أو ولي الأمر جزءًا من العملية.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'ما ينبغي أن يظهره الفيديو';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'المراهق في الفيديو';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'أحد الوالدين أو الوصي يتحدث أمام الكاميرا';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'تصريح واضح بأن عمر المراهق بين 13 و15 وأن لديه إذنًا باستخدام Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'تصريح واضح بأن أحد الوالدين أو الوصي يعلم بالحساب وسيشرف على استخدامه';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'كيفية إرساله';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'أرفق الفيديو عند مراسلة دعم Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'أبقِ الفيديو خاصًا ولا تنشره في التطبيق';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'سيراجعه فريقنا ويرد عليك بالخطوات التالية';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'راسل دعم Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'مساعدة بشأن مراجعة Divine Greenlight (من 13 إلى 15 عامًا)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'مرحبًا فريق دعم Divine،\n\nأتواصل معكم بشأن Divine Greenlight لمراهق يتراوح عمره بين 13 و15.\n\nأرفقت فيديو قصيرًا خاصًا يُظهر:\n- المراهق\n- أحد الوالدين أو الوصي يتحدث أمام الكاميرا\n- أن المراهق لديه إذن باستخدام Divine\n- أن أحد الوالدين أو الوصي يعلم بالحساب وسيشرف على استخدامه\n\nبلد/بلدان الإقامة:\n\nسياق مفيد:\n\nشكرًا لكم.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'تعليمات دعم الوالدين';

  @override
  String get minorAccountReviewContinue => 'متابعة';

  @override
  String get minorAccountReviewErrorTitle =>
      'تعذّر علينا تحميل حالة مراجعة حسابك.';

  @override
  String get minorAccountReviewErrorBody => 'يرجى المحاولة مرة أخرى بعد قليل.';

  @override
  String get minorAccountReviewTryAgain => 'حاول مرة أخرى';

  @override
  String get minorAccountReviewParentContactTitle => 'التواصل مع الوالدين';

  @override
  String get minorAccountReviewParentContactHeading =>
      'أضف بريد أحد الوالدين أو الوصي';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'سنستخدم هذا العنوان لمراجعة موافقة الوالدين في الحالة $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'بريد أحد الوالدين أو الوصي';

  @override
  String get minorAccountReviewSubmitting => 'جارٍ الإرسال...';

  @override
  String get minorAccountReviewSubmitEmail => 'إرسال البريد';

  @override
  String get minorAccountReviewBackToReview => 'العودة إلى مراجعة الحساب';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'تم إرسال البريد';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'أرسلنا $email للمراجعة. سنراسل هذا العنوان للتأكيد. بمجرد رد أحد الوالدين أو الوصي، ستتقدم حالتك. استخدم «تحقق مرة أخرى» من شاشة مراجعة الحساب لمتابعة المستجدات.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'استلمنا بيانات التواصل مع أحد الوالدين أو الوصي لهذا الحساب. سيراجعها فريقنا قبل إعادة الوصول.';

  @override
  String get minorAccountReviewMissingCase =>
      'لم نجد حالة مراجعة نشطة لهذا الحساب.';

  @override
  String get minorAccountReviewParentContactError =>
      'تعذّر إرسال بريد الوالدين. حاول مرة أخرى.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'دعم الوالدين';

  @override
  String get minorAccountReviewUnder13Heading =>
      'يجب على أحد الوالدين أو الوصي التواصل مع Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'بالنسبة للحسابات التي يُرجَّح أن أصحابها دون 13 عامًا، الخطوة التالية هي تواصل أحد الوالدين أو الوصي عبر البريد.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'بريد الدعم';

  @override
  String get minorAccountReviewCopySupportEmail => 'نسخ بريد الدعم';

  @override
  String get minorAccountReviewSupportEmailCopied => 'تم نسخ بريد الدعم';

  @override
  String get minorAccountReviewCopyCaseId => 'نسخ رقم الحالة';

  @override
  String get minorAccountReviewCaseIdCopied => 'تم نسخ رقم الحالة';

  @override
  String get minorAccountReviewUnavailable => 'غير متاح';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'اطلب من أحد الوالدين أو الوصي ذكر رقم الحالة وتوضيح أنه يتواصل مع Divine بشأن مراجعة هذا الحساب.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'مراجعة حساب لمن هم دون 13 للحالة $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'مرحبًا فريق دعم Divine،\n\nأنا أحد والدي طفل دون 13 عامًا أو الوصي عليه، وأتواصل معكم بشأن حالة مراجعة الحساب $caseId.\n\nشكرًا لكم.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle => 'محاكاة مراجعة حساب قاصر';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'الحالة الحالية';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'مقيّد ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'نشط';

  @override
  String get devOptionsMinorReviewStateLoading => 'جارٍ التحميل...';

  @override
  String get devOptionsMinorReviewStateError => 'خطأ في تحميل الحالة';

  @override
  String get devOptionsMinorReviewClearTitle => 'مسح تجاوز المحاكاة';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'استخدم الخادم أو الحالة النشطة الافتراضية مجددًا';

  @override
  String get devOptionsMinorReviewTeenTitle => 'محاكاة حالة مراجعة 13–15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'حساب مقيّد مع مسار التواصل مع الوالدين';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'محاكاة حالة دعم لمن هم دون 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'حساب مقيّد مع تعليمات بريد الوالدين فقط';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'تم مسح محاكاة مراجعة حساب القاصر';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'تم تفعيل حالة الدعم المحاكاة لمن هم دون 13';

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
  String get devOptionsProtectedMinorSimulationTitle => 'محاكاة القاصر المحمي';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'الحالة الحالية';

  @override
  String get devOptionsProtectedMinorStateProtected => 'قاصر محمي (13–15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'غير محمي';

  @override
  String get devOptionsProtectedMinorStateLoading => 'جارٍ التحميل…';

  @override
  String get devOptionsProtectedMinorStateError => 'خطأ في قراءة الحالة';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'بدون تجاوز (حالة الحساب الحقيقية)';

  @override
  String get devOptionsProtectedMinorOverrideProtected => 'تجاوز: فرض الحماية';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'تجاوز: فرض عدم الحماية';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'محاكاة قاصر محمي (13–15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'افرض حالة القاصر المحمي لاختبار حمايات ‎#175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle => 'محاكاة شخص بالغ';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'افرض عدم الحماية (نفي صريح، يختلف عن عدم وجود تجاوز)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'مسح التجاوز';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'العودة إلى حالة الحساب الحقيقية من Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'تم فرض حالة القاصر المحمي';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'تم إيقاف حالة القاصر المحمي';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'تم مسح تجاوز القاصر المحمي';

  @override
  String get devOptionsInviteAvailabilityTitle => 'دعوات التسجيل';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'الحالة الحالية';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'قيمة الخادم: جارٍ التحميل';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => 'قيمة الخادم: مفعّلة';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'قيمة الخادم: معطّلة';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'قيمة الخادم: غير معروفة';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'تجاوز: استخدم قيمة الخادم';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'تجاوز: فرض التفعيل';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'تجاوز: فرض التعطيل';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'استخدم قيمة الخادم';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'اتبع onboardingMode الخاص بخدمة الدعوات';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'فرض التفعيل';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'أظهر بوابات دعوات التسجيل وإدارتها محليًا';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'فرض التعطيل';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'أخفِ واجهة دعوات التسجيل محليًا دون تغيير الخادم';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'دعوات التسجيل تتبع الخادم الآن';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'تم فرض تفعيل دعوات التسجيل';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'تم فرض تعطيل دعوات التسجيل';

  @override
  String get commentsRecordVideoButtonLabel => 'سجّل تعليق فيديو';

  @override
  String get commentsOpenVideoLabel => 'افتح تعليق الفيديو';

  @override
  String get commentsMuteVideoReplyLabel => 'اكتم رد الفيديو';

  @override
  String get commentsUnmuteVideoReplyLabel => 'ألغِ كتم رد الفيديو';

  @override
  String get commentsOpenReplyParentLabel => 'افتح الفيديو الذي يرد عليه هذا';

  @override
  String get commentsReplyParentSectionTitle => 'ردًا على';

  @override
  String commentsReplyParentLabel(String target) {
    return 'رد على $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'رد على فيديو';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'حساب $platform موثّق: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'الحسابات الموثّقة';

  @override
  String get profileEditGetVerifiedCta => 'وثّق حسابك';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'اربط حساباتك على وسائل التواصل ليعرف الناس أنّك أنت فعلًا.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'زيارة الموقع: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'تعذّر فتح الموقع';

  @override
  String get videoMetadataEditCoverTitle => 'تعديل الغلاف';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => 'تجاهل تغييرات الغلاف';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'استخدام الإطار المحدد كغلاف للفيديو';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'التنقل عبر الفيديو لاختيار إطار الغلاف';

  @override
  String get videoMetadataTagsPickerSearchHint => 'ابحث أو أضف وسوماً';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'أضف وسوماً ليكتشف الآخرون فيديوك';

  @override
  String get videoMetadataTagsPickerNoResults => 'لا توجد وسوم مطابقة';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'إضافة \"#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'لست في السادسة عشرة بعد؟ لا بأس. ';

  @override
  String get authUnder16ChoicesCta => 'إليك خياراتك.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'وإليك السبب';

  @override
  String get generalSettingsHoldToRecord => 'اضغط مطولاً للتسجيل';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'يبدأ التسجيل عند الضغط المطوّل ويتوقف عند الإفراج';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم نشر $count مقاطع فيديو في ملفك الشخصي',
      one: 'تم نشر الفيديو في ملفك الشخصي',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'إرسال رسالة';

  @override
  String get emojiPickerSearchHint => 'بحث';

  @override
  String get emojiCategoryRecent => 'الأخيرة';

  @override
  String get emojiCategorySmileys => 'الوجوه والأشخاص';

  @override
  String get emojiCategoryAnimals => 'الحيوانات والطبيعة';

  @override
  String get emojiCategoryFood => 'الطعام والشراب';

  @override
  String get emojiCategoryActivities => 'الأنشطة';

  @override
  String get emojiCategoryTravel => 'السفر والأماكن';

  @override
  String get emojiCategoryObjects => 'الأشياء';

  @override
  String get emojiCategorySymbols => 'الرموز';

  @override
  String get emojiCategoryFlags => 'الأعلام';

  @override
  String get videoEditorMarkerLabel => 'علامة';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'إضافة علامة إلى المخطط الزمني';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'إزالة علامة من المخطط الزمني';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'إزالة العلامة عند رأس التشغيل';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'حذف العلامة؟';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'سيؤدي هذا إلى إزالة العلامة من المخطط الزمني. سيبقى تعديلك كما هو.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'كتم صوت جميع المسارات أو إلغاء الكتم';

  @override
  String get videoEditorSplitFailed => 'فشل التقسيم. يرجى المحاولة مرة أخرى.';

  @override
  String get videoEditEditSubtitles => 'تعديل الترجمات';

  @override
  String get subtitleEditorTitle => 'تعديل الترجمات';

  @override
  String get subtitleEditorSave => 'حفظ';

  @override
  String get subtitleEditorProcessing =>
      'ما زالت الترجمات قيد الإنشاء. عُد بعد لحظة.';

  @override
  String get subtitleEditorNoSpeech =>
      'لم يتم رصد أي كلام في هذا الفيديو، لذا لا يوجد ما يمكن كتابته كترجمة.';

  @override
  String get subtitleEditorWriteOwn => 'اكتبها بنفسك';

  @override
  String get subtitleEditorAddCue => 'أضف سطرًا';

  @override
  String get subtitleEditorRemoveCue => 'احذف هذا السطر';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'لا يمكن تشغيل الفيديو الآن، لكن ما زال بإمكانك تصحيح التسميات التوضيحية.';

  @override
  String get subtitleEditorPlayPreview => 'شغّل الفيديو';

  @override
  String get subtitleEditorPausePreview => 'أوقف الفيديو مؤقتًا';

  @override
  String get subtitleEditorInvalidHint =>
      'كل سطر يحتاج نصًا ونهاية بعد بدايته.';

  @override
  String get subtitleEditorLoadError => 'تعذّر تحميل الترجمات. حاول مرّة أخرى.';

  @override
  String get subtitleEditorSaveSuccess => 'تم تحديث الترجمات';

  @override
  String get subtitleEditorSaveError => 'تعذّر حفظ الترجمات. حاول مرّة أخرى.';

  @override
  String get subtitleEditorRetry => 'إعادة المحاولة';

  @override
  String get subtitleEditorCueHint => 'نص الترجمة';

  @override
  String get imageCropEditorRotateLabel => 'تدوير';

  @override
  String get imageCropEditorFlipLabel => 'قلب';

  @override
  String get imageCropEditorResetLabel => 'إعادة تعيين';

  @override
  String get imageCropEditorCloseSemanticLabel => 'إلغاء الاقتصاص';

  @override
  String get imageCropEditorDoneSemanticLabel => 'تطبيق الاقتصاص';

  @override
  String get imageCropEditorProcessing => 'جارٍ تطبيق الاقتصاص…';

  @override
  String get backgroundUploadNotificationTitle => 'جارٍ رفع الفيديو';

  @override
  String get monetizationSettingsTitle => 'دعم المبدعين';

  @override
  String get monetizationSettingsSubtitle => 'أضف روابط الإكرامية والاشتراك';

  @override
  String get monetizationSettingsIntroTitle => 'روابط خارجية فقط';

  @override
  String get monetizationSettingsIntroBody =>
      'أضف وجهات تتحكم بها بنفسك. لا يتولى Divine الدفع أبدًا ولا يفتح محتوى داخل التطبيق عبر هذه الروابط.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رابط نشط في ملفك',
      many: '$count رابطًا نشطًا في ملفك',
      few: '$count روابط نشطة في ملفك',
      two: 'رابطان نشطان في ملفك',
      one: 'رابط نشط واحد في ملفك',
      zero: 'لا توجد روابط نشطة في ملفك',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'أرسل إكرامية';

  @override
  String get monetizationSettingsSubscriptionSection => 'اشترك / ادعم';

  @override
  String get monetizationSettingsSave => 'حفظ روابط الدعم';

  @override
  String get monetizationSettingsSaving => 'جارٍ الحفظ...';

  @override
  String get monetizationSettingsSaved => 'تم تحديث روابط الدعم';

  @override
  String get monetizationSettingsSaveFailed =>
      'تعذّر حفظ روابط الدعم. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get monetizationSettingsErrorEmpty => 'أضف معرّفًا أو رابطًا.';

  @override
  String get monetizationSettingsErrorInvalid => 'هذا الرابط لا يبدو صحيحًا.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'استخدم رابطًا خاصًا بهذا المزوّد.';

  @override
  String get monetizationSettingsHintCashApp => '‏\$cashtag أو رابط cash.app';

  @override
  String get monetizationSettingsHintPayPal => 'معرّف PayPal.me أو رابط';

  @override
  String get monetizationSettingsHintVenmo => 'معرّف Venmo أو رابط';

  @override
  String get monetizationSettingsHintPatreon => 'معرّف Patreon أو رابط';

  @override
  String get monetizationSettingsHintSubstack => 'نطاق Substack أو رابط';

  @override
  String get monetizationSettingsHintMedium => 'معرّف Medium أو رابط';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'معرّف Open Collective أو رابط';

  @override
  String get profileSupportSheetTitle => 'ادعم هذا المبدع';

  @override
  String get profileSupportSheetBody =>
      'تُفتح هذه الروابط خارج Divine. لا شيء هنا يفتح محتوى داخل التطبيق.';

  @override
  String get profileSupportTipSection => 'أرسل إكرامية';

  @override
  String get profileSupportSubscriptionSection => 'اشترك / ادعم';

  @override
  String get profileSupportButtonLabel => 'ادعم';

  @override
  String get monetizationTipsSettingsTitle => 'الإكراميات';

  @override
  String get monetizationTipsSettingsSubtitle => 'أضف روابط إكرامية اختيارية';

  @override
  String get monetizationTipsSettingsIntroTitle => 'إكراميات اختيارية فقط';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'الإكراميات هدايا اختيارية بين المستخدمين. لا تفتح محتوى أو اشتراكات أو ميزات أو ترتيبًا أو ظهورًا أو وصولًا في Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رابط إكرامية نشط في ملفك',
      many: '$count رابط إكرامية نشطًا في ملفك',
      few: '$count روابط إكرامية نشطة في ملفك',
      two: 'رابطا إكرامية نشطان في ملفك',
      one: 'رابط إكرامية نشط واحد في ملفك',
      zero: 'لا توجد روابط إكرامية نشطة في ملفك',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'حفظ روابط الإكرامية';

  @override
  String get monetizationTipsSettingsSaved => 'تم تحديث روابط الإكرامية';

  @override
  String get profileTipButtonLabel => 'إكرامية';

  @override
  String get profileTipSheetTitle => 'أعطِ هذا المبدع إكرامية';

  @override
  String get profileTipSheetBody =>
      'تُفتح روابط الإكرامية خارج Divine. وهي اختيارية ولا تفتح محتوى أو اشتراكات أو ميزات أو وصولًا في Divine.';

  @override
  String get settingsStorageTitle => 'التخزين';

  @override
  String get settingsStorageCacheSectionTitle => 'الوسائط المخزّنة مؤقتًا';

  @override
  String get settingsStorageCacheDescription =>
      'مقاطع فيديو الخلاصة والصور المصغّرة والمعالجات المؤقتة المخزّنة. حذفها آمن — تتم إعادة تنزيلها أو إنشاؤها عند الحاجة.';

  @override
  String get settingsStorageMeasuring => 'جارٍ الحساب…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size قيد الاستخدام';
  }

  @override
  String get settingsStorageClearButton => 'مسح ذاكرة التخزين المؤقت';

  @override
  String get settingsStorageClearConfirmTitle => 'مسح الوسائط المخزّنة مؤقتًا؟';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'سيؤدي ذلك إلى تحرير $size. لن تتأثر مكتبة المقاطع لديك.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'مسح';

  @override
  String get settingsStorageCleared => 'تم مسح ذاكرة التخزين المؤقت';

  @override
  String get settingsStorageLibrarySectionTitle => 'مكتبة المقاطع';

  @override
  String get settingsStorageLibraryDescription =>
      'ابحث عن المقاطع التالفة التي يفتقد ملف الفيديو الخاص بها.';

  @override
  String get settingsStorageScanButton => 'فحص المكتبة';

  @override
  String get settingsStorageLibraryHealthy => 'لم يتم العثور على مقاطع تالفة';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'المقاطع التالفة التي تم العثور عليها: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'إزالة المقاطع التالفة';

  @override
  String get settingsStorageBrokenClipsRemoved => 'تمت إزالة المقاطع التالفة';

  @override
  String get settingsStorageError => 'حدث خطأ ما';

  @override
  String get settingsStorageMaxVideoCacheLabel =>
      'الحد الأقصى لذاكرة تخزين الفيديو المؤقتة';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count مقطع فيديو';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'إزالة المقاطع التالفة؟';

  @override
  String get settingsStorageRepairSectionTitle => 'إصلاح التثبيت';

  @override
  String get settingsStorageRepairDescription =>
      'إذا كان التطبيق يتعطل أو يتصرف بغرابة، فإعادة ضبط بياناته المحلية تحل المشكلة غالبًا. مقاطعك ومسوداتك تبقى كما هي.';

  @override
  String get settingsStorageRepairButton => 'إعادة ضبط بيانات التطبيق';

  @override
  String get settingsStorageRepairConfirmTitle => 'إعادة ضبط بيانات التطبيق؟';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'سيؤدي هذا إلى مسح بيانات الموجز المخزنة مؤقتًا والملفات المؤقتة. تبقى مقاطعك ومسوداتك وإعداداتك وتسجيل دخولك، لكن عليك إعادة تشغيل التطبيق بعد ذلك.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return 'سيتم حذف $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'إعادة ضبط';

  @override
  String get settingsStorageRepairInProgress => 'جارٍ إعادة الضبط…';

  @override
  String get settingsStorageRepairSuccess =>
      'تم — أعد تشغيل التطبيق لإنهاء العملية.';

  @override
  String get settingsStorageRepairFailure =>
      'تعذّرت إعادة ضبط كل شيء. حاول مرة أخرى بعد إعادة التشغيل.';

  @override
  String get nostrSettingsSignatureVerification => 'التحقق من التوقيع';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'اختر متى يتحقق Divine من توقيعات أحداث المرحلات. يتم التحقق من معرّفات الأحداث أولاً دائماً.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'كل المرحلات';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'الأكثر أماناً. تحقق من توقيع كل حدث من كل مرحل.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'المرحلات غير الموثوقة';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'تجاوز الفحوصات للمرحلات الموجودة بالفعل في مجموعتك المضبوطة.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'مرحلات غير Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'ثق بمرحلات Divine، وتحقق من الباقي.';

  @override
  String get settingsCrosspostingTitle => 'النشر المتقاطع';

  @override
  String get settingsCrosspostingSubtitle => 'شارك فيديوهاتك على منصّات أخرى';

  @override
  String get crosspostingSignInRequired =>
      'سجّل الدخول بـ Divine لإدارة النشر المتقاطع';

  @override
  String get crosspostingLoadFailed => 'تعذّر تحميل إعدادات النشر المتقاطع';

  @override
  String get crosspostingNoPlatforms => 'لا توجد منصّات نشر متقاطع متاحة الآن';

  @override
  String get crosspostingRetry => 'إعادة المحاولة';

  @override
  String get crosspostingNotConnected => 'غير متصل';

  @override
  String get crosspostingConnected => 'متصل';

  @override
  String get crosspostingNeedsReconnect => 'يحتاج إعادة ربط';

  @override
  String get crosspostingConnect => 'ربط';

  @override
  String get crosspostingReconnect => 'إعادة الربط';

  @override
  String get crosspostingDisconnect => 'إلغاء الربط';

  @override
  String get crosspostingModeOff => 'إيقاف';

  @override
  String get crosspostingModeManual => 'يدوي';

  @override
  String get crosspostingModeManualSubtitle => 'تختار لكل فيديو';

  @override
  String get crosspostingModeAutomatic => 'تلقائي';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'الفيديوهات القادمة تُنشر تلقائيًا — فقط الفيديوهات التي تنشرها بعد تفعيل هذا';

  @override
  String get crosspostingNotConnectedError =>
      'اربط هذه المنصّة أولًا لتغيير طريقة النشر عليها.';

  @override
  String get crosspostingGenericError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'لم يصلنا أي رد من صفحة تسجيل الدخول. إذا أكملت الربط هناك، فحدّث الصفحة — قد يكون حسابك مرتبطًا بالفعل.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return 'تم ربط $platform';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'تعذّر ربط $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'تم إلغاء الاتصال على $platform';
  }

  @override
  String get supporterTitle => 'داعمو Divine';

  @override
  String get supporterTileSubtitle => 'ادعم Divine باشتراك شهري اختياري.';

  @override
  String get supporterHeroTitle => 'ساعد Divine على الاستمرار';

  @override
  String get supporterHeroBody =>
      'Divine مجاني وسيبقى كذلك دائمًا. إذا أردت مساعدتنا في إبقاء التكرارات مستمرة، فكن داعمًا شهريًا. لا شيء مقفل — هذا فقط يُبقي الأنوار مضاءة ويكسبك شكرنا.';

  @override
  String get supporterActiveBadge =>
      'أنت داعم لـ Divine. شكرًا لإبقائك هذا مستمرًا.';

  @override
  String get supporterPurchasePending => 'عملية شرائك في انتظار الموافقة.';

  @override
  String get supporterPurchaseConfirming => 'جارٍ تأكيد دعمك…';

  @override
  String get supporterStoreChecking => 'جارٍ التحقق من المتجر…';

  @override
  String get supporterUnavailable => 'اشتراكات الدعم غير متاحة هنا حاليًا.';

  @override
  String get supporterRestorePurchases => 'استعادة المشتريات';

  @override
  String get supporterDismissError => 'تجاهل الخطأ';

  @override
  String get supporterErrorStoreUnavailable =>
      'المتجر غير متاح على هذا الجهاز.';

  @override
  String get supporterErrorPurchaseFailed =>
      'لم تكتمل عملية الشراء. لم يُخصم منك أي مبلغ.';

  @override
  String get supporterErrorPurchasePending => 'عملية شرائك في انتظار الموافقة.';

  @override
  String get supporterErrorRestoreFailed =>
      'لم يتم العثور على اشتراك دعم لاستعادته.';

  @override
  String get supporterErrorOwnershipConflict =>
      'عملية الشراء هذه تخص حساب Divine آخر.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'تعذّر على Divine تأكيد حالة الداعم حاليًا.';

  @override
  String get supporterErrorUnknown => 'حدث خطأ ما. يرجى المحاولة مرّة أخرى.';

  @override
  String get supporterDisclaimer =>
      'يؤكّد Divine حالة الداعم بعد أن يتحقّق المتجر من عملية شرائك. التقدير اختياري، والهالة ليست توثيقًا.';

  @override
  String get profileNotifyBellOff => 'أبلغني عن المقاطع الجديدة';

  @override
  String get profileNotifyBellOn => 'أوقف إشعارات المقاطع الجديدة';

  @override
  String get profileNotifyUpdateFailed => 'لم نتمكن من الحفظ. أعد المحاولة؟';

  @override
  String get savedSoundYourLabel => 'تسميتك';

  @override
  String get savedSoundAddHashtags => 'أضف وسومًا';

  @override
  String get savedSoundDeviceOnly => 'محفوظ على هذا الجهاز';

  @override
  String get savedSoundDetailsRetry =>
      'تعذّر حفظ هذه التفاصيل. انقر لإعادة المحاولة.';

  @override
  String get savedSoundFallbackTitle => 'صوت محفوظ';

  @override
  String get savedSoundPreviewAction => 'استمع إلى الصوت';

  @override
  String get savedSoundEditAction => 'تعديل تفاصيل الصوت';

  @override
  String get savedSoundRemoveAction => 'إزالة الصوت المحفوظ';

  @override
  String get savedSoundClearHashtagFilter => 'مسح تصفية الوسوم';

  @override
  String get soundAllowRemix => 'اسمح للآخرين بإعادة مزج هذا الصوت';

  @override
  String get soundReuseUnavailable => 'لا يمكن إعادة مزج هذا الصوت الآن.';

  @override
  String get soundPublicCredit => 'إسناد علني للصوت';

  @override
  String get soundCreditRequired => 'أضف إسنادًا علنيًا للصوت قبل النشر.';

  @override
  String get soundSharedAs => 'تمت المشاركة باسم';

  @override
  String get soundOwnWork => 'أنا من صنع هذا الصوت';

  @override
  String soundCreatorBy(String creator) {
    return 'بواسطة $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'شاركه $publisher';
  }

  @override
  String get soundRemixingAllowed => 'إعادة المزج مسموحة';

  @override
  String get soundCreditOnly => 'الإسناد فقط';

  @override
  String get soundCreditTitleLabel => 'عنوان الصوت';

  @override
  String get soundCreditCreatorLabel => 'المبدع';

  @override
  String get soundCreditSourceUrlLabel => 'رابط المصدر';

  @override
  String get soundCreditPublicHashtagsLabel => 'وسوم علنية';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'إلغاء اختيار الوسوم';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'تطبيق الوسوم المحددة';

  @override
  String get userPickerCancelSemanticLabel => 'إلغاء اختيار المستخدمين';

  @override
  String get userPickerConfirmSemanticLabel => 'تأكيد المستخدمين المحددين';

  @override
  String get userPickerClearSelectionSemanticLabel => 'مسح اختيار المستخدمين';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'إلغاء اختيار تحذيرات المحتوى';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'تطبيق تحذيرات المحتوى المحددة';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'إغلاق محرر الفيديو';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'المتابعة إلى تفاصيل المنشور';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'تجاهل التغييرات في $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'تطبيق التغييرات في $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'إزالة الصوت';

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
  String get verifyTitle => 'الحسابات الموثّقة';

  @override
  String get verifySignedOutMessage => 'سجّل الدخول لربط حساباتك.';

  @override
  String get verifyIntro =>
      'اربط الحسابات التي تملكها أصلاً، ليعرف الناس أنك أنت فعلاً.';

  @override
  String get verifyLoadFailed => 'تعذّر تحميل روابطك.';

  @override
  String get verifyRetry => 'حاول مجدداً';

  @override
  String get verifyLinkedSectionTitle => 'مرتبطة';

  @override
  String get verifyVerifierUnreachable =>
      'تعذّر الوصول إلى خدمة التوثيق، لذلك تظهر كلها غير مفحوصة.';

  @override
  String get verifyAddSectionTitle => 'إضافة حساب';

  @override
  String get verifyAllPlatformsLinked => 'ربطت كل ما ندعمه.';

  @override
  String get verifyStatusVerified => 'موثّق';

  @override
  String get verifyStatusUnverified => 'غير موثّق';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'فك ارتباط حساب $platform ‏$identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'فك ارتباط $platform؟';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return 'لن يظهر $identity في ملفك الشخصي بعد الآن. يمكنك ربطه مرة أخرى لاحقًا، لكن سيتعين عليك تسجيل الدخول أو نشر إثبات جديد.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'فك الارتباط';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'اربط حسابك على $platform';
  }

  @override
  String get verifyOneTapBadge => 'نقرة واحدة';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'سجّل الدخول إلى $platform وسنتولى الباقي. لن يُنشر أي شيء.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'المتابعة باستخدام $platform';
  }

  @override
  String get verifyConnectProofTitle => 'أو انشر إثباتاً';

  @override
  String get verifyConnectProofExplainer =>
      'انشر npub الخاص بك على حسابك، ثم الصق رابط ذلك المنشور.';

  @override
  String get verifyNpubLabel => 'npub الخاص بك';

  @override
  String get verifyCopyNpubSemanticLabel => 'نسخ npub الخاص بك';

  @override
  String get verifyNpubCopied => 'تم نسخ npub';

  @override
  String get verifyIdentityLabel => 'اسم الحساب';

  @override
  String get verifyProofLabel => 'رابط منشورك';

  @override
  String get verifyConnectProofCta => 'افحص واربط';

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
      'تعذّر الوصول إلى خدمة التوثيق. حاول بعد قليل.';

  @override
  String get verifyErrorOauthFailed => 'لم تنجح العملية. جرّب مرة أخرى.';

  @override
  String get verifyErrorHandleRequired => 'أدخل المُعرّف أولاً.';

  @override
  String get verifyErrorPublishFailed =>
      'تم التوثيق، لكن لم يقبل أي مُرحِّل التحديث. حاول مجدداً.';

  @override
  String get verifyErrorOauthUnavailable =>
      'تسجيل الدخول بنقرة واحدة غير مُعدّ لهذه المنصة بعد. استخدم إثبات المنشور بالأسفل.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'أنشئ gist عاماً يحتوي npub الخاص بك في الملف الأول، ثم الصق رابط الـ gist.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'انشر npub الخاص بك في قناة Discord يستطيع بوتنا قراءتها، ثم الصق رابط الرسالة. دعوة الخادم لا تثبت شيئاً.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'انشر npub الخاص بك من ذلك الحساب، ثم الصق رابط التغريدة.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'انشر npub الخاص بك من ذلك الحساب، ثم الصق الرابط. اسم الحساب يحتاج إلى الخادم — mastodon.social/@alice وليس alice فقط.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'ما يُربط هو القناة، لا حساب تلغرام الخاص بك. تحتاج القناة أولاً رابطاً عاماً (تلغرام ينشئ الجديدة خاصة). انشر npub الخاص بك هناك والصق رابط الرسالة.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'سجّلت الدخول بالأعلى؟ لا حاجة لشيء آخر. وإلا فانشر npub الخاص بك والصق رابط المنشور.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'ضع npub الخاص بك في وصف فيديو، ثم الصق رابط ذلك الفيديو.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'ضع npub الخاص بك في وصف فيديو، ثم الصق رابط ذلك الفيديو.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return 'تم ربط $platform.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'هذه قناة خاصة أو رابط دعوة. اجعل للقناة رابطاً عاماً، ثم الصق رابط الرسالة.';

  @override
  String get verifyErrorRemoveFailed => 'تعذّر فك الارتباط. حاول مجدداً.';

  @override
  String get verifyErrorLinksUnreadable =>
      'تعذّرت قراءة روابطك الحالية، لذلك لم يتغيّر شيء. تحقق من اتصالك وحاول مجدداً.';

  @override
  String get verifyChannelLabel => 'اسم القناة';

  @override
  String get verifyHowItWorksTitle => 'كيف يعمل هذا؟';

  @override
  String get verifyHowItWorksIntro => 'تخيّله مصافحة بين حسابين:';

  @override
  String get verifyHowItWorksYourSide =>
      'ملفك في Divine يقول: «أنا @alice على تويتر».';

  @override
  String get verifyHowItWorksOtherSide =>
      'وحسابك على تويتر يؤكد: «نعم، ذلك الملف في Divine يخصني».';

  @override
  String get verifyHowItWorksBothSides =>
      'نتحقق من الطرفين. إذا تطابقا فأنت موثّق. لا يمكن تزييف ذلك — يمكن نسخ اسمك وصورتك، لكن لا يمكن النشر من حسابك الحقيقي.';

  @override
  String get verifyHowItWorksOwnership =>
      'الروابط موجودة على هويتك في Nostr، فيمكنك إزالتها من هنا متى شئت.';

  @override
  String get generalSettingsSectionIdentity => 'الهوية';

  @override
  String get libraryFilterAll => 'الكل';

  @override
  String get libraryFilterArchive => 'الأرشيف';

  @override
  String get libraryFilterDeleted => 'المحذوفة';

  @override
  String get libraryCategoryNewChipLabel => 'جديدة';

  @override
  String get libraryCategoryCreateSemanticLabel => 'إنشاء فئة';

  @override
  String get libraryCategoryCreateTitle => 'فئة جديدة';

  @override
  String get libraryCategoryCreateAction => 'إنشاء';

  @override
  String get libraryCategoryRenameTitle => 'إعادة تسمية الفئة';

  @override
  String get libraryCategoryRenameAction => 'إعادة التسمية';

  @override
  String get libraryCategoryDeleteAction => 'حذف الفئة';

  @override
  String get libraryCategoryNameLabel => 'اسم الفئة';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'حذف \"$name\"؟';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'مقاطعك تبقى كما هي، وتعود فقط إلى \"الكل\".';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'إعادة تسمية هذه الفئة أو حذفها';

  @override
  String get libraryCategoryMoveTitle => 'النقل إلى';

  @override
  String get libraryCategoryMoveNone => 'بدون فئة';

  @override
  String get libraryCategoryMoveNewCategory => 'فئة جديدة';

  @override
  String get libraryArchiveAction => 'أرشفة';

  @override
  String get libraryUnarchiveAction => 'إلغاء الأرشفة';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الإبقاء في هذه الفئات؟',
      two: 'الإبقاء في هاتين الفئتين؟',
      one: 'الإبقاء في هذه الفئة؟',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'الإبقاء في $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'الإبقاء في فئاتها';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'الإزالة من $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed => 'الإزالة من فئاتها';

  @override
  String get libraryMoveSelectedClipsTooltip => 'نقل المقاطع المحددة';

  @override
  String get libraryCategoryEmptyTitle => 'لا شيء هنا بعد';

  @override
  String get libraryCategoryEmptySubtitle =>
      'اختر بعض المقاطع وانقلها إلى هذه الفئة.';

  @override
  String get libraryArchiveEmptyTitle => 'لا يوجد شيء في الأرشيف';

  @override
  String get libraryArchiveEmptySubtitle =>
      'المقاطع المؤرشفة تنتظر هنا، بعيدًا عن مكتبتك الأساسية.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم نقل $count مقاطع إلى $name',
      one: 'تم نقل مقطع واحد إلى $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إزالة $count مقاطع من فئتها',
      one: 'تمت إزالة مقطع واحد من فئته',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت أرشفة $count مقاطع',
      one: 'تمت أرشفة مقطع واحد',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عادت $count مقاطع إلى مكتبتك',
      one: 'عاد مقطع واحد إلى مكتبتك',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'تغيير البريد';

  @override
  String get accountSettingsChangeEmailSubtitle => 'انقل حسابك إلى عنوان آخر';

  @override
  String get accountSettingsChangePassword => 'تغيير كلمة السر';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'اختر كلمة سر جديدة لتسجيل الدخول';

  @override
  String get accountCredentialsNeedsSignIn =>
      'انتهت جلستك. سجّل الدخول من جديد لإجراء هذا التغيير.';

  @override
  String get accountCredentialsRateLimited => 'محاولات كثيرة. انتظر بضع دقائق.';

  @override
  String get accountCredentialsNetwork =>
      'تعذّر الوصول إلى Divine. تحقق من اتصالك وحاول مجددًا.';

  @override
  String get accountCredentialsUnknown => 'لم ينجح ذلك. حاول مرة أخرى.';

  @override
  String get changePasswordSubtitle =>
      'اكتب كلمة السر الحالية، ثم اختر واحدة جديدة.';

  @override
  String get changePasswordCurrentLabel => 'كلمة السر الحالية';

  @override
  String get changePasswordWrongCurrent => 'هذه ليست كلمة السر الحالية.';

  @override
  String get changePasswordSuccess => 'تم تغيير كلمة السر.';

  @override
  String get changeEmailSubtitle =>
      'سنرسل رابط تأكيد إلى عنوانك الجديد وإلى العنوان المسجّل في حسابك. يتغيّر بريدك بعد التأكيد من الاثنين.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'في حسابك: $email';
  }

  @override
  String get changeEmailNewLabel => 'بريد جديد';

  @override
  String get changeEmailPasswordLabel => 'كلمة السر';

  @override
  String get changeEmailSameAsCurrent => 'هذا هو بريدك الحالي بالفعل.';

  @override
  String get changeEmailWrongPassword => 'هذه ليست كلمة السر.';

  @override
  String get changeEmailSubmit => 'إرسال روابط التأكيد';

  @override
  String get changeEmailSentTitle => 'رابطان في الطريق';

  @override
  String changeEmailSentMessage(String email) {
    return 'أكّد من $email ومن العنوان المسجّل في حسابك. يتبدّل بريدك بعد إتمام الاثنين.';
  }

  @override
  String get changeEmailSentExpiry => 'تتوقف الروابط عن العمل بعد 24 ساعة.';

  @override
  String get changeEmailSentDone => 'فهمت';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount فيديو',
      one: '$formattedCount فيديو',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'متابعة متبادلة';

  @override
  String get socialProofFollowsYou => 'يتابعك';

  @override
  String get socialProofYouFollow => 'تتابعه';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount متابِع',
      one: '$formattedCount متابِع',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'الفيديوهات لا تُحمَّل الآن.\nالمشكلة من عندنا، ونحن نصلحها.';

  @override
  String get feedOfflineMessage =>
      'أنت غير متصل.\nتحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get dbFailureTitle => 'تعذّر فتح قاعدة البيانات المحلية';

  @override
  String get dbFailureAdviceResettable =>
      'إعادة التشغيل لن تحل هذه المشكلة. إعادة تعيين قاعدة البيانات المحلية أدناه تمنح Divine بداية نظيفة — يبقى حسابك كما هو.';

  @override
  String get dbFailureAdviceRestart =>
      'أعد تشغيل Divine بعد فتح قفل جهازك. إذا استمر هذا، فحدّث التطبيق أو تواصل مع الدعم.';

  @override
  String get dbFailureAdviceHotJournal =>
      'جرّب إعادة تشغيل Divine مرة واحدة. إذا استمر ذلك، فحدّث التطبيق أو تواصل مع الدعم. لا تزال بياناتك المحلية محفوظة.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'التشخيص: $code';
  }

  @override
  String get dbFailureCloseApp => 'إغلاق Divine';

  @override
  String get dbFailureResetAction => 'إعادة تعيين قاعدة البيانات المحلية';

  @override
  String get dbFailureConfirmTitle => 'إعادة تعيين قاعدة البيانات المحلية؟';

  @override
  String get dbFailureConfirmBody =>
      'يبقى حسابك. تُحذف المسودات والمقاطع المحفوظة على هذا الجهاز — أما الرسائل والخلاصات فتعود من الشبكة.';

  @override
  String get dbFailureResetConfirm => 'إعادة تعيين قاعدة البيانات المحلية الآن';

  @override
  String get dbFailureCancel => 'إلغاء';

  @override
  String get dbFailureResetFailed => 'لم ينجح ذلك. أغلق Divine وحاول مرة أخرى.';

  @override
  String get dbFailureResetDoneTitle =>
      'تمت إعادة تعيين قاعدة البيانات المحلية';

  @override
  String get dbFailureResetDoneBody =>
      'أغلق Divine ثم افتحه مجددًا — سيبني التشغيل التالي قاعدة بيانات محلية جديدة.';

  @override
  String get authSignInOptionsInfo => 'حول خيارات تسجيل الدخول';

  @override
  String get authShowPassword => 'إظهار كلمة المرور';

  @override
  String get authHidePassword => 'إخفاء كلمة المرور';

  @override
  String get followUserSemanticLabel => 'متابعة المستخدم';

  @override
  String get unfollowUserSemanticLabel => 'إلغاء متابعة المستخدم';

  @override
  String get commentsLoadingSemanticLabel => 'جارٍ تحميل التعليقات';

  @override
  String get analyticsWindowAll => 'الكل';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'متابعة المستخدم $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'إلغاء متابعة المستخدم $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / شهريًا';
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
  String get updateGentleBanner => 'صدر تحديث جديد. ألقِ نظرة عليه ←';

  @override
  String get updateModerateTitle => 'صدر تحديث منذ آخر مرة تحققت فيها';

  @override
  String get updateUrgentTitle => 'تفوتك إصلاحات مهمة';

  @override
  String get updateNotNow => 'ليس الآن';

  @override
  String get updateAction => 'تحديث';

  @override
  String updateNewIn(String version) {
    return 'الجديد في $version:';
  }

  @override
  String get settingsUpdateAvailable => 'يتوفر تحديث';
}

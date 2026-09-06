// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Възстановяване на клипове';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Намира записи, съхранени под друг акаунт, и видеофайлове, към които вече не сочи никакъв запис.';

  @override
  String get devOptionsClipRecoveryScan => 'Сканиране';

  @override
  String get devOptionsClipRecoveryFailure =>
      'Възстановяването на клипове се провали';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips клипа',
      one: '$clips клип',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts чернови',
      one: '$drafts чернова',
    );
    return 'Видими сега: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Скрити под други акаунти';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips клипа',
      one: '$clips клип',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts чернови',
      one: '$drafts чернова',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Преместване в този акаунт';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Файлове без връзка: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Възстановяване в библиотеката';

  @override
  String get devOptionsClipRecoveryEmpty => 'Няма какво да се възстанови';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Възстановени $count клипа',
      one: 'Възстановен $count клип',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied =>
      'Отчетът за възстановяване е копиран';

  @override
  String get devOptionsStorageFootprint => 'Заето пространство';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Всяка папка, в която приложението пише. Изчистването на кеша освобождава само част от него.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Измерване';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Общо: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Отчетът за паметта е копиран';

  @override
  String get devOptionsStorageFootprintFailure =>
      'Паметта не можа да бъде измерена';

  @override
  String get feedTuningMoreLabel => 'Повече такива';

  @override
  String get feedTuningLessLabel => 'По-малко такива';

  @override
  String get feedTuningUndo => 'Отмени';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Отваряне на посочения видеоклип';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSecureAccount => 'Защити акаунта си';

  @override
  String get settingsSessionExpired => 'Сесията изтече';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Влез отново, за да си върнеш пълния достъп';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Аналитика за творци';

  @override
  String get settingsSupportCenter => 'Помощен център';

  @override
  String get settingsNotifications => 'Известия';

  @override
  String get settingsBlueskyPublishing => 'Публикуване в Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Управлявай публикуването в Bluesky';

  @override
  String get settingsNostrSettings => 'Настройки за Nostr';

  @override
  String get settingsIntegratedApps => 'Свързани приложения';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Одобрени външни приложения, които работят в Divine';

  @override
  String get settingsExperimentalFeatures => 'Експериментални функции';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Малки експерименти, които може да се държат странно. Пробвай, ако ти е любопитно.';

  @override
  String get settingsLegal => 'Правни неща';

  @override
  String get settingsIntegrationPermissions => 'Разрешения за интеграции';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Прегледай и махни запомнените одобрения за интеграции';

  @override
  String settingsVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get settingsVersionEmpty => 'Версия';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Режимът за разработчици вече е включен';

  @override
  String get settingsDeveloperModeEnabled =>
      'Режимът за разработчици е включен!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Още $count докосвания, за да включиш режима за разработчици';
  }

  @override
  String get settingsShareDivine => 'Сподели Divine с приятелите си';

  @override
  String get settingsSwitchAccount => 'Смени акаунта';

  @override
  String get settingsAddAnotherAccount => 'Добави друг акаунт';

  @override
  String get settingsAccountSwitchFailed =>
      'Не можахме да превключим акаунтите. Опитайте отново.';

  @override
  String get settingsUnsavedDraftsTitle => 'Незапазени чернови';

  @override
  String get settingsUploadInProgressTitle => 'Тече качване';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'се качват $count видеа',
      one: 'се качва $count видео',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'видеата остават като чернови',
      one: 'видеото остава като чернова',
    );
    return 'Все още $_temp0. Смяната на профила спира качването — $_temp1 в този профил.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'и чернови',
      one: 'а чернова',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'те ще се запазят',
      one: 'тя ще се запази',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ги публикуваш или прегледаш',
      one: 'я публикуваш или прегледаш',
    );
    return 'Имаш $count незапазен$_temp0. При смяна на акаунта $_temp1, но може първо да $_temp2.';
  }

  @override
  String get settingsCancel => 'Отказ';

  @override
  String get settingsSwitchAnyway => 'Смени въпреки това';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Сесията на този акаунт изтече. Ново влизане в него означава да излезеш от този, който използваш сега.';

  @override
  String get settingsAppVersionLabel => 'Версия на приложението';

  @override
  String get settingsAppLanguage => 'Език на приложението';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (език на устройството)';
  }

  @override
  String get settingsAppLanguageTitle => 'Език на приложението';

  @override
  String get settingsAppLanguageDescription =>
      'Избери езика за интерфейса на приложението';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Използвай езика на устройството';

  @override
  String get settingsGeneralTitle => 'Общи настройки';

  @override
  String get settingsContentSafetyTitle => 'Съдържание и безопасност';

  @override
  String get generalSettingsSectionIntegrations => 'ИНТЕГРАЦИИ';

  @override
  String get generalSettingsSectionViewing => 'ГЛЕДАНЕ';

  @override
  String get generalSettingsSectionCreating => 'СЪЗДАВАНЕ';

  @override
  String get generalSettingsSectionApp => 'ПРИЛОЖЕНИЕ';

  @override
  String get appearanceSettingsTitle => 'Външен вид';

  @override
  String get appearanceSettingsSubtitle =>
      'Избери как да изглежда Divine на това устройство';

  @override
  String get appearanceSettingsSystem => 'Системна настройка';

  @override
  String get appearanceSettingsLight => 'Светла';

  @override
  String get appearanceSettingsDark => 'Тъмна';

  @override
  String get generalSettingsClosedCaptions => 'Субтитри';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Показвай субтитри, когато видеата ги имат';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Само квадратни видеа';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Запази емисиите в класическия квадратен формат';

  @override
  String get contentPreferencesTitle => 'Предпочитания за съдържание';

  @override
  String get contentPreferencesContentFilters => 'Филтри за съдържание';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Управлявай филтрите за предупреждения';

  @override
  String get contentPreferencesContentLanguage => 'Език на съдържанието';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (език на устройството)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Слагай език на видеата си, за да могат хората да филтрират какво гледат.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Използвай езика на устройството (по подразбиране)';

  @override
  String get contentPreferencesAudioSharing =>
      'Позволи моето аудио да се използва отново';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Когато е включено, други могат да използват аудио от твоите видеа';

  @override
  String get contentPreferencesMusicMode => 'Музикален режим';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Изключва шумопотискането, което задушава инструментите. По-добре за музика, по-грубо за глас.';

  @override
  String get contentPreferencesAccountLabels => 'Етикети на акаунта';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Сам избираш етикетите за съдържанието си';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Етикети за съдържанието на акаунта';

  @override
  String get contentPreferencesClearAll => 'Изчисти всичко';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Избери всичко, което важи за акаунта ти';

  @override
  String get contentPreferencesDoneNoLabels => 'Готово (без етикети)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Готово ($count избрани)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Аудио вход';

  @override
  String get contentPreferencesAutoRecommended => 'Автоматично (препоръчано)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Автоматично избира най-добрия микрофон';

  @override
  String get contentPreferencesSelectAudioInput => 'Избери аудио вход';

  @override
  String get contentPreferencesUnknownMicrophone => 'Неизвестен микрофон';

  @override
  String get contentFiltersAdultContent => 'СЪДЪРЖАНИЕ ЗА ВЪЗРАСТНИ';

  @override
  String get contentFiltersViolenceGore => 'НАСИЛИЕ И КРЪВ';

  @override
  String get contentFiltersSubstances => 'ВЕЩЕСТВА';

  @override
  String get contentFiltersOther => 'ДРУГО';

  @override
  String get contentFiltersAgeGateMessage =>
      'Потвърди възрастта си в „Безопасност и поверителност“, за да отключиш филтрите за съдържание за възрастни';

  @override
  String get contentFiltersShow => 'Показвай';

  @override
  String get contentFiltersWarn => 'Предупреждавай';

  @override
  String get contentFiltersFilterOut => 'Филтрирай';

  @override
  String get profileBlockedAccountNotAvailable => 'Този акаунт не е наличен';

  @override
  String get profileInvalidId => 'Невалиден ID на профил';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Виж $displayName в Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName в Divine';
  }

  @override
  String get profileShareFailed =>
      'Не успяхме да споделим профила. Опитай пак.';

  @override
  String get profileCopyPublicKey => 'Копирай публичния ключ (npub)';

  @override
  String get profileGetEmbedCode => 'Вземи код за вграждане';

  @override
  String get profilePublicKeyCopied => 'Публичният ключ е копиран';

  @override
  String get profileEmbedCodeCopied =>
      'Кодът за вграждане е копиран в клипборда';

  @override
  String get profileMoreTooltip => 'Още';

  @override
  String get profileMoreSemanticLabel => 'Още опции';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Затваряне на аватара';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => 'Затвори аватара';

  @override
  String get profileFollowingLabel => 'Следваш';

  @override
  String get profileFollowLabel => 'Следвай';

  @override
  String get profileBlockedLabel => 'Блокиран';

  @override
  String get profileFollowersLabel => 'Последователи';

  @override
  String get profileFollowingStatLabel => 'Следва';

  @override
  String get profileVideosLabel => 'Видеа';

  @override
  String get profileCollabsLabel => 'Съвместни';

  @override
  String get profileLikedLabel => 'Харесани';

  @override
  String get profileRepostsLabel => 'Репостове';

  @override
  String get profileListsLabel => 'Списъци';

  @override
  String get profileCommentsLabel => 'Коментари';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count покани за сътрудници още чакат да бъдат изпратени',
      one: '1 покана за сътрудник още чака да бъде изпратена',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Задържахме поканата на опашката. Опитай пак оттук.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'За „$title“. Опитай пак оттук.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Опитай пак';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Опитване';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Повторното изпращане на покани за сътрудници не е налично в момента.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count покани за сътрудници още чакат да бъдат изпратени.',
      one: '1 покана за сътрудник още чака да бъде изпратена.',
      zero: 'Поканите за сътрудници са изпратени.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сътрудници не могат да получават покани.',
      one: '1 сътрудник не може да получава покани.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count потребители';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Да блокираме $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Когато блокираш потребител:';

  @override
  String get profileBlockBulletHidePosts =>
      'Публикациите им няма да се показват в емисиите ти.';

  @override
  String get profileBlockBulletCantView =>
      'Няма да могат да виждат профила ти, да те следват или да виждат публикациите ти.';

  @override
  String get profileBlockBulletNoNotify =>
      'Те няма да бъдат уведомени за тази промяна.';

  @override
  String get profileBlockBulletYouCanView =>
      'Все още ще можеш да видиш профила им.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Блокирай $displayName';
  }

  @override
  String get profileCancelButton => 'Отказ';

  @override
  String get profileLearnMore => 'Научи повече';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Да отблокираме $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Когато отблокираш този потребител:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Публикациите им пак ще се показват в емисиите ти.';

  @override
  String get profileUnblockBulletCanView =>
      'Ще могат да виждат профила ти, да те следват и да виждат публикациите ти.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Те няма да бъдат уведомени за тази промяна.';

  @override
  String get profileLearnMoreAt => 'Научи повече на';

  @override
  String get profileUnblockButton => 'Разблокирай';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Спри да следваш $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Блокирай $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Отблокирай $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Докладвай $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Добави $displayName към списък';
  }

  @override
  String get profileNoCollabsTitle => 'Още няма колаборации';

  @override
  String get profileCollabsOwnEmpty =>
      'Видеата, в които участваш, ще се появят тук.';

  @override
  String get profileCollabsOtherEmpty =>
      'Видеата, в които участват, ще се появят тук.';

  @override
  String get profileErrorLoadingCollabs =>
      'Грешка при зареждане на видеата със сътрудничества';

  @override
  String get profileNoSavedVideosTitle => 'Още нищо не е запазено';

  @override
  String get profileSavedOwnEmpty =>
      'Запази видеа от менюто за споделяне и ще се появят тук.';

  @override
  String get profileErrorLoadingSaved =>
      'Грешка при зареждане на запазените видеа';

  @override
  String get profileNoCommentsOwnTitle => 'Още няма коментари';

  @override
  String get profileNoCommentsOtherTitle => 'Още няма коментари';

  @override
  String get profileCommentsOwnEmpty =>
      'Твоите коментари и отговори ще се появят тук.';

  @override
  String get profileCommentsOtherEmpty =>
      'Техните коментари и отговори ще се показват тук.';

  @override
  String get profileErrorLoadingComments => 'Грешка при зареждане на коментари';

  @override
  String get profileVideoRepliesSection => 'Видео отговори';

  @override
  String get profileCommentsSection => 'Коментари';

  @override
  String get profileEditLabel => 'Редактиране';

  @override
  String get profileLibraryLabel => 'Библиотека';

  @override
  String get profileNoLikedVideosTitle => 'Още няма харесвания';

  @override
  String get profileLikedOwnEmpty =>
      'Когато нещо ти хване окото, натисни сърцето. Харесванията ти ще се появят тук.';

  @override
  String get profileLikedOtherEmpty =>
      'Още нищо не им е хванало окото. Дай му време.';

  @override
  String get profileErrorLoadingLiked =>
      'Грешка при зареждане на харесаните видеа';

  @override
  String get profileNoRepostsTitle => 'Още няма репостове';

  @override
  String get profileRepostsOwnEmpty =>
      'Видя нещо, което си струва да споделиш? Публикувай го пак и ще се появи тук.';

  @override
  String get profileRepostsOtherEmpty =>
      'Още не са препубликували нищо. Когато го направят, ще се появи тук.';

  @override
  String get profileErrorLoadingReposts =>
      'Грешка при зареждане на репостнатите видеа';

  @override
  String get profileNoVideosTitle => 'Още няма видеа';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Сцената е твоя. Започни да публикуваш и видеата ти ще живеят тук.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Светът чака. Последвай ги, за да не изпуснеш нищо.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Миниатюра на видео $number';
  }

  @override
  String get profileShowMore => 'Покажи повече';

  @override
  String get profileShowLess => 'Покажи по-малко';

  @override
  String get dmMessageDisplayLimitReached =>
      'Останалата част от съобщението не се показва.';

  @override
  String get profileCompleteYourProfile => 'Довърши профила си';

  @override
  String get profileCompleteSubtitle =>
      'Добави име, био и снимка, за да започнеш';

  @override
  String get profilePleaseTryAgain => 'Опитай пак';

  @override
  String get profileSecureYourAccount => 'Защити акаунта си';

  @override
  String get profileSecureSubtitle =>
      'Добави имейл и парола, за да възстановиш акаунта си на всяко устройство';

  @override
  String get profileRetryButton => 'Опитай пак';

  @override
  String get profileSessionExpired => 'Сесията изтече';

  @override
  String get profileSignInToRestore =>
      'Влез отново, за да си върнеш пълния достъп';

  @override
  String get profileSignInButton => 'Вход';

  @override
  String get profileMaybeLaterLabel => 'Може би по-късно';

  @override
  String get profileSecurePrimaryButton => 'Добави имейл и парола';

  @override
  String get profileCompletePrimaryButton => 'Обнови профила си';

  @override
  String get profileLoopsLabel => 'Лупове';

  @override
  String get profileLikesLabel => 'Харесвания';

  @override
  String get profileMyLibraryLabel => 'Моята библиотека';

  @override
  String get profileMessageLabel => 'Съобщение';

  @override
  String get profileShareLabel => 'Сподели профила';

  @override
  String get profileDeletedAccountName => 'Изтрит акаунт';

  @override
  String get inboxActionReportVanishedAccount => 'Докладвай този акаунт';

  @override
  String get inboxActionBlockVanishedAccount => 'Блокирай този акаунт';

  @override
  String get inboxActionUnblockVanishedAccount => 'Отблокирай този акаунт';

  @override
  String get inboxReportedVanishedAccount => 'Този акаунт е докладван';

  @override
  String get inboxBlockedVanishedAccount => 'Този акаунт е блокиран';

  @override
  String get inboxUnblockedVanishedAccount => 'Този акаунт е отблокиран';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Това премахва разговора от входящата ти кутия. Ако ти пише отново, започва нов разговор.';

  @override
  String get inboxConversationDeletedAccountSubtitle => 'Този акаунт е изтрит';

  @override
  String get profileUserFallback => 'Потребител';

  @override
  String get profileLinkCopied => 'Връзката към профила е копирана';

  @override
  String get profileSetupEditProfileTitle => 'Редактиране на профил';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Настрой профила си, преди да добавиш NIP-05 адрес.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Създай профил';

  @override
  String get profileSetupBackLabel => 'Назад';

  @override
  String get profileSetupAboutNostr => 'Относно Nostr';

  @override
  String get profileSetupProfilePublished => 'Профилът е публикуван успешно!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Да запазим ли промените?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Запази промените си, преди да излезеш, или ги отхвърли и продължи.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Запази промените';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Отхвърли промените';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Продължи редакцията';

  @override
  String get profileSetupCreateNewProfile => 'Създаване на нов профил?';

  @override
  String get profileSetupNoExistingProfile =>
      'Не намерихме съществуващ профил на релетата ти. Ако продължиш, ще създадем нов профил.';

  @override
  String get profileSetupPublishButton => 'Публикувай';

  @override
  String get profileSetupUsernameTaken =>
      'Това потребителско име току-що беше заето. Избери друго.';

  @override
  String get profileSetupClaimFailed =>
      'Не успяхме да запазим потребителското име. Опитай пак.';

  @override
  String get profileSetupPublishFailed =>
      'Профилът не се публикува. Опитай пак.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Не успяхме да се свържем с мрежата. Провери връзката си и опитай пак.';

  @override
  String get profileSetupDisplayNameLabel => 'Име за показване';

  @override
  String get profileSetupDisplayNameRequired => 'Въведи име за показване';

  @override
  String get profileSetupBioLabel => 'Био (по избор)';

  @override
  String get profileSetupWebsiteLabel => 'Уебсайт (по избор)';

  @override
  String get profileSetupPublicKeyLabel => 'Публичен ключ (npub)';

  @override
  String get profileSetupUsernameLabel => 'Потребителско име (по избор)';

  @override
  String get profileSetupUsernameHelper =>
      'Използвай букви, цифри или тирета. Потребителското ти име става divine.video адрес. За интервали или символи използвай показваното име.';

  @override
  String get profileSetupSaveButton => 'Запази';

  @override
  String get profileSetupSavingButton => 'Запазва се...';

  @override
  String get profileSetupImageUrlTitle => 'Добави URL адрес на изображението';

  @override
  String get profileSetupImageSelectionFailed =>
      'Не успяхме да изберем изображение. Постави URL на изображение по-долу.';

  @override
  String get profileSetupImagesTypeGroup => 'снимки';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Достъпът до камерата е изключен. Включи го от Настройки, за да снимаш.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Достъпът до камерата не е разрешен на това устройство.';

  @override
  String get cameraPickErrorBusy =>
      'Селекторът вече е отворен. Затвори го и опитай пак.';

  @override
  String get cameraPickErrorGeneric =>
      'Камерата не можа да се отвори. Опитай пак.';

  @override
  String get profileSetupGotItButton => 'Разбрах';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Качването на изображението се провали. Опитай отново след малко.';

  @override
  String get profileSetupUploadNetworkError =>
      'Мрежова грешка: провери интернет връзката си и опитай пак.';

  @override
  String get profileSetupUploadAuthError =>
      'Грешка при удостоверяване: излез и влез отново.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Файлът е твърде голям. Избери по-малко изображение (макс. 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Качването на изображението се провали. Сървърите ни временно не са достъпни. Опитай пак след малко.';

  @override
  String get profileSetupBannerClearButton => 'Изчисти банера';

  @override
  String get profileSetupBannerChangeColor => 'Цвят на банера';

  @override
  String get profileSetupChangeBannerTitle => 'Смяна на банера';

  @override
  String get profileSetupBannerColorPickerTitle => 'Промяна на цвета на банера';

  @override
  String get profileSetupBannerColorCustom => 'Персонализиран';

  @override
  String get profileSetupBannerColorNone => 'Без цвят';

  @override
  String get profileSetupBannerColorLime => 'Лайм';

  @override
  String get profileSetupBannerColorYellow => 'Жълто';

  @override
  String get profileSetupBannerColorViolet => 'Виолетово';

  @override
  String get profileSetupBannerColorPink => 'Розово';

  @override
  String get profileSetupBannerColorOrange => 'Оранжево';

  @override
  String get profileSetupBannerColorPurple => 'Лилаво';

  @override
  String get profileSetupAvatarClearButton => 'Премахване на снимката';

  @override
  String get profileSetupImageTakePhoto => 'Направете снимка';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Качване от библиотеката';

  @override
  String get profileSetupImagePasteLink => 'Поставете връзка към изображение';

  @override
  String get profileSetupEditAvatarLabel => 'Редактиране на профилната снимка';

  @override
  String get profileSetupEditBannerLabel => 'Редактиране на банера';

  @override
  String get profileSetupUsernameChecking => 'Проверява се наличността...';

  @override
  String get profileSetupUsernameAvailable => 'Потребителското име е свободно!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Потребителското име вече е заето';

  @override
  String get profileSetupUsernameReserved => 'Потребителското име е запазено';

  @override
  String get profileSetupContactSupport => 'Свържи се с поддръжката';

  @override
  String get profileSetupCheckAgain => 'Провери пак';

  @override
  String get profileSetupUsernameBurned =>
      'Това потребителско име вече не е достъпно';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Разрешени са само букви, цифри и тирета';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Потребителското име не може да започва или завършва с тире';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Потребителското име трябва да е 3-63 знака';

  @override
  String get profileSetupUsernameNetworkError =>
      'Не можем да проверим дали е свободно. Опитай пак.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Невалиден формат на потребителското име';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Неуспешна проверка за наличност';

  @override
  String get profileSetupUsernameReservedTitle =>
      'Потребителското име е запазено';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Името $username е запазено. Кажи ни защо трябва да е твое.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'Напр. Това е името на моята марка, сценично име и т.н.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Вече си се свързал с поддръжката? Натисни „Провери пак“, за да видиш дали е освободено за теб.';

  @override
  String get profileSetupSupportRequestSent =>
      'Заявката за поддръжка е изпратена! Ще се свържем с вас скоро.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Не можем да отворим имейл. Изпрати до: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Изпрати заявка';

  @override
  String get profileSetupUseOwnNip05 => 'Използвай свой NIP-05 адрес';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 Адрес';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Невалиден NIP-05 формат (напр. name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'За divine.video използвай полето за потребителско име по-горе';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 адрес';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Използвай потребителското си име в divine.video или насочи хендъла си към NIP-05 адрес в домейн, който контролираш.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Запази NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 е запазен';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'NIP-05 не можа да се запази. Опитай пак.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Да използваш собствен NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 свързва име като ти@твоятдомейн.com с твоята Nostr самоличност. Трябва да контролираш домейна и да качиш файл за проверка на правилния път. Ако нещо е сгрешено, хората няма да те намират и потвърденият ти хендъл изчезва. Продължи само ако вече си го настроил.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Продължи';

  @override
  String get profileSetupNip05ConfirmCancel => 'Отказ';

  @override
  String get profileSetupProfilePicturePreview =>
      'Визуализация на профилна снимка';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine е изграден върху Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' отворен протокол, устойчив на цензура, който позволява на хората да общуват онлайн, без да зависят от една компания или платформа. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Когато се регистрираш в Divine, получаваш нова Nostr самоличност.';

  @override
  String get nostrInfoOwnership =>
      'Nostr ти позволява да притежаваш съдържанието, самоличността и социалната си мрежа, които можеш да използваш в много приложения. Повече избор, по-малко заключване, по-здрав социален интернет.';

  @override
  String get nostrInfoLingo => 'Nostr речник:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Твоят публичен Nostr адрес. Безопасно е да го споделяш и помага на други да те намират, следват или да ти пишат в Nostr приложения.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Твоят частен ключ и доказателство за собственост. Дава пълен контрол върху Nostr самоличността ти, така че ';

  @override
  String get nostrInfoNsecWarning => 'Пази го в тайна!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr потребителско име:';

  @override
  String get nostrInfoUsernameDescription =>
      'Човешко име (като @name.divine.video), което сочи към твоя npub. Така Nostr самоличността ти се разпознава и потвърждава по-лесно, почти като имейл адрес.';

  @override
  String get nostrInfoLearnMoreAt => 'Научи повече на';

  @override
  String get nostrInfoGotIt => 'Ясно!';

  @override
  String get videoGridRefreshLabel => 'Търсим още видеа';

  @override
  String get videoGridOptionsTitle => 'Опции за видеото';

  @override
  String get videoGridEditVideo => 'Редактирай видеото';

  @override
  String get videoGridEditVideoSubtitle =>
      'Актуализирай заглавие, описание и хаштагове';

  @override
  String get videoGridDeleteVideo => 'Изтрий видеото';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Премахни това видео от Divine. Може още да се вижда в други Nostr клиенти.';

  @override
  String get videoGridDeletingContent => 'Трием съдържанието...';

  @override
  String get exploreTabFeatured => 'Избрани';

  @override
  String get exploreTabClassics => 'Класики';

  @override
  String get exploreTabNew => 'Нови';

  @override
  String get exploreTabPopular => 'Популярни';

  @override
  String get exploreTabCategories => 'Категории';

  @override
  String get exploreTabForYou => 'За теб';

  @override
  String get exploreTabLists => 'Списъци';

  @override
  String get exploreTabIntegratedApps => 'Интегрирани приложения';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Тук още няма нищо. Върни се скоро.';

  @override
  String get featuredTabLoadFailed => 'Тази колекция не можа да се зареди.';

  @override
  String get featuredTabRetry => 'Опитай пак';

  @override
  String get exploreNoVideosAvailable => 'Няма налични видеа';

  @override
  String get exploreDiscoverLists => 'Открий списъци';

  @override
  String get exploreAboutLists => 'Относно списъците';

  @override
  String get exploreAboutListsDescription =>
      'Списъците ти помагат да организираш и управляваш Divine съдържание по два начина:';

  @override
  String get explorePeopleLists => 'Списъци с хора';

  @override
  String get explorePeopleListsDescription =>
      'Следвай групи от творци и виж най-новите им видеа';

  @override
  String get exploreVideoLists => 'Видео списъци';

  @override
  String get exploreVideoListsDescription =>
      'Създай плейлисти с любимите си видеа, за да ги гледаш по-късно';

  @override
  String get exploreMyLists => 'Моите списъци';

  @override
  String get exploreSubscribedLists => 'Абонирани списъци';

  @override
  String get exploreErrorLoadingLists =>
      'Грешка при зареждане на списъците. Опитай пак.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нови видеа',
      one: '1 ново видео',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'и видеа',
      one: 'о видео',
    );
    return 'Зареди $count нов$_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Възпроизвеждане на видео';

  @override
  String get videoPlayerMute => 'Заглушаване на видеото';

  @override
  String get videoPlayerUnmute => 'Включване на звука на видеото';

  @override
  String get videoPlayerTapHint =>
      'Докоснете за пускане или пауза. Докоснете два пъти, за да харесате.';

  @override
  String get videoSettingsMenuOpen => 'Отвори настройките за възпроизвеждане';

  @override
  String get videoSettingsMenuClose => 'Затвори настройките за възпроизвеждане';

  @override
  String get videoSettingsCaptionsEnable => 'Включи субтитрите';

  @override
  String get videoSettingsCaptionsDisable => 'Изключи субтитрите';

  @override
  String get videoSettingsAutoAdvanceOn =>
      'Автоматичното продължаване е включено';

  @override
  String get videoSettingsAutoAdvanceOff =>
      'Автоматичното продължаване е изключено';

  @override
  String get videoSettingsCaptionsOn => 'Субтитрите са включени';

  @override
  String get videoSettingsCaptionsOff => 'Субтитрите са изключени';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Субтитрите са включени за това видео';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Субтитрите са изключени за това видео';

  @override
  String get contentWarningLabel => 'Предупреждение за съдържание';

  @override
  String get contentWarningNudity => 'Голота';

  @override
  String get contentWarningSexualContent => 'Сексуално съдържание';

  @override
  String get contentWarningPornography => 'Порнография';

  @override
  String get contentWarningGraphicMedia => 'Графични медии';

  @override
  String get contentWarningViolence => 'Насилие';

  @override
  String get contentWarningSelfHarm => 'Самонараняване';

  @override
  String get contentWarningDrugUse => 'Употреба на наркотици';

  @override
  String get contentWarningAlcohol => 'Алкохол';

  @override
  String get contentWarningTobacco => 'Тютюн';

  @override
  String get contentWarningGambling => 'Хазарт';

  @override
  String get contentWarningProfanity => 'Ругатни';

  @override
  String get contentWarningFlashingLights => 'Мигащи светлини';

  @override
  String get contentWarningAiGenerated => 'AI-генерирано';

  @override
  String get contentWarningSpoiler => 'Спойлер';

  @override
  String get contentWarningSensitiveContent => 'Чувствително съдържание';

  @override
  String get contentWarningDescNudity => 'Съдържа голота или частична голота';

  @override
  String get contentWarningDescSexual => 'Съдържа сексуално съдържание';

  @override
  String get contentWarningDescPorn =>
      'Съдържа изрично порнографско съдържание';

  @override
  String get contentWarningDescGraphicMedia =>
      'Съдържа графични или смущаващи изображения';

  @override
  String get contentWarningDescViolence => 'Съдържа съдържание с насилие';

  @override
  String get contentWarningDescSelfHarm =>
      'Съдържа препратки към самонараняване';

  @override
  String get contentWarningDescDrugs =>
      'Съдържа съдържание, свързано с наркотици';

  @override
  String get contentWarningDescAlcohol =>
      'Съдържа съдържание, свързано с алкохол';

  @override
  String get contentWarningDescTobacco =>
      'Съдържа съдържание, свързано с тютюна';

  @override
  String get contentWarningDescGambling =>
      'Съдържа съдържание, свързано с хазарта';

  @override
  String get contentWarningDescProfanity => 'Съдържа силен език';

  @override
  String get contentWarningDescFlashingLights =>
      'Съдържа мигащи светлини (предупреждение за фоточувствителност)';

  @override
  String get contentWarningDescAiGenerated => 'Това съдържание е AI-генерирано';

  @override
  String get contentWarningDescSpoiler => 'Съдържа спойлери';

  @override
  String get contentWarningDescContentWarning =>
      'Създателят означи това като чувствително';

  @override
  String get contentWarningDescDefault => 'Създателят маркира това съдържание';

  @override
  String get contentWarningDetailsTitle => 'Предупреждения за съдържание';

  @override
  String get contentWarningDetailsSubtitle =>
      'Създателят е приложил тези етикети:';

  @override
  String get contentWarningManageFilters =>
      'Управление на филтри за съдържание';

  @override
  String get contentWarningViewAnyway => 'Виж все пак';

  @override
  String get contentWarningReportContentTooltip => 'Докладвай съдържанието';

  @override
  String get contentWarningBlockUserTooltip => 'Блокирай потребителя';

  @override
  String get contentWarningBlockedTitle => 'Съдържанието е блокирано';

  @override
  String get contentWarningBlockedPolicy =>
      'Това съдържание е блокирано заради нарушение на правилата.';

  @override
  String get contentWarningNoticeTitle => 'Известие за съдържание';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Потенциално вредно съдържание';

  @override
  String get contentWarningView => 'Виж';

  @override
  String get contentWarningReportAction => 'Докладвай';

  @override
  String get contentWarningHideAllLikeThis => 'Скрий всичко подобно';

  @override
  String get contentWarningNoFilterYet =>
      'Още няма запазен филтър за това предупреждение.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Отсега нататък ще скриваме публикации като тази.';

  @override
  String get communitySuggestTitle => 'Помогни да класираме това';

  @override
  String get communitySuggestSubtitle =>
      'Липсва предупреждение за съдържание? Предложението ти е публично, подписано и не може да бъде отменено.';

  @override
  String get communitySuggestSubmit => 'Предложи';

  @override
  String get communitySuggestSuccess =>
      'Благодарим. Предложението ти е изпратено.';

  @override
  String get communitySuggestFailure =>
      'Предложението ти не можа да бъде изпратено. Опитай пак.';

  @override
  String get communitySuggestAlready => 'Вече предложи това';

  @override
  String get communitySuggestActionLabel => 'Класирай';

  @override
  String get videoErrorNotFound => 'Видеото не е намерено';

  @override
  String get videoErrorPlayback => 'Грешка при възпроизвеждане';

  @override
  String get videoErrorAgeRestricted => 'Съдържание с възрастово ограничение';

  @override
  String get videoErrorUnavailable => 'Видеото е недостъпно';

  @override
  String get videoErrorUnavailableBody => 'Това видео не е налично в момента.';

  @override
  String get videoErrorRetry => 'Опитай пак';

  @override
  String get videoErrorContentRestricted => 'Ограничено съдържание';

  @override
  String get videoErrorContentRestrictedBody =>
      'Това видео беше премахнато заради нарушение на правилата ни за съдържание.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Потвърди възрастта си, за да гледаш това видео.';

  @override
  String get videoErrorSkip => 'Пропусни';

  @override
  String get videoErrorVerifyAgeButton => 'Потвърди възрастта';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Възрастта ти не можа да бъде потвърдена. Опитай пак.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Потвърждаването изтече. Провери връзката си или опитай пак след малко.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Съдържанието за възрастни е изключено';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Включи го от филтрите за съдържание, за да гледаш това видео.';

  @override
  String get videoErrorAdultContentHiddenAction =>
      'Отвори филтрите за съдържание';

  @override
  String get videoDetailLoadError => 'Неуспешно зареждане на видеото';

  @override
  String get videoDetailLoadErrorBody => 'Нещо се обърка по пътя. Опитай пак.';

  @override
  String get videoDetailNotFoundBody =>
      'Може да е изтрито, да е извън обсега ни или да е скрито от твоите настройки.';

  @override
  String get databaseCorruptionTitle => 'Локалните ти данни се повредиха';

  @override
  String get databaseCorruptionBody =>
      'Затвори Divine и го отвори пак — ще го поправим автоматично. Ще запазим каквото можем от черновите и клиповете ти, останалото се презарежда.';

  @override
  String get databaseCorruptionCloseButton => 'Затвори Divine';

  @override
  String get videoDetailContextTitle => 'Споделено видео';

  @override
  String get videoDetailCloseSemanticLabel => 'Затворете видеоплейъра';

  @override
  String get videoFollowButtonFollow => 'Следвай';

  @override
  String get audioAttributionOriginalSound => 'Оригинален звук';

  @override
  String get audioAttributionUnavailableSound => 'Звукът е недостъпен';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Вдъхновен от @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Вдъхновен от @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'С @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'С @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сътрудници',
      one: '1 сътрудник',
    );
    return '$_temp0. Докосни, за да видиш профила.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Чакащо';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Чакащ съавтор';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending чакащи)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Докосни, за да видиш профила.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Докосни, за да видиш видеа с този хаштаг.';
  }

  @override
  String get listAttributionFallback => 'Списък';

  @override
  String get shareVideoLabel => 'Сподели видео';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Публикация, споделена с $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Публикация, споделена с $count души',
      one: 'Публикация, споделена с $count човек',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Не успяхме да изпратим видеото';

  @override
  String get shareAddedToBookmarks => 'Добавен към отметките';

  @override
  String get shareRemovedFromBookmarks => 'Премахнато от отметките';

  @override
  String get shareFailedToAddBookmark => 'Не успяхме да добавим отметка';

  @override
  String get shareFailedToRemoveBookmark => 'Не успяхме да премахнем отметката';

  @override
  String get shareActionFailed => 'Действието не мина';

  @override
  String get shareWithTitle => 'Сподели с';

  @override
  String get shareFindPeople => 'Намери хора';

  @override
  String get shareFindPeopleMultiline => 'Намери\nхора';

  @override
  String get shareSent => 'Изпратено';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return 'Избран е $name';
  }

  @override
  String get shareMessageHint => 'Добави съобщение (по избор)...';

  @override
  String get videoActionUnlike => 'Премахни харесването';

  @override
  String get videoActionLike => 'Харесай видеото';

  @override
  String get videoActionAutoLabel => 'Компилация';

  @override
  String get videoActionLikeLabel => 'Харесай';

  @override
  String get videoActionReplyLabel => 'Отговор';

  @override
  String get videoActionRepostLabel => 'Сподели пак';

  @override
  String get videoActionShareLabel => 'Сподели';

  @override
  String get videoActionReportLabel => 'Сигнал';

  @override
  String get videoActionReport => 'Подай сигнал за видеото';

  @override
  String get videoActionEditLabel => 'Редактирай';

  @override
  String get videoActionEdit => 'Редактирай видеото';

  @override
  String get videoActionAboutLabel => 'Инфо';

  @override
  String get videoActionEnableAutoAdvance =>
      'Включи автоматичното продължаване';

  @override
  String get videoActionDisableAutoAdvance =>
      'Изключи автоматичното продължаване';

  @override
  String get videoActionRemoveRepost => 'Премахни репоста';

  @override
  String get videoActionRepost => 'Сподели видеото пак';

  @override
  String get videoActionViewComments => 'Виж коментарите';

  @override
  String get videoActionMoreOptions => 'Още опции';

  @override
  String get videoEngagementLikersTitle => 'Харесано от';

  @override
  String get videoEngagementRepostersTitle => 'Споделено от';

  @override
  String get videoEngagementLikersEmpty => 'Още няма харесвания';

  @override
  String get videoEngagementRepostersEmpty => 'Още няма споделяния';

  @override
  String get videoEngagementLoadFailed => 'Списъкът не можа да се зареди';

  @override
  String get videoOverlayOpenMetadataFromTitle =>
      'Отвори подробностите за видеото';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Отвори подробностите за видеото';

  @override
  String get videoOverlayCommentBarHint => 'Добави коментар...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Добави коментар';

  @override
  String get videoOverlayCommentBarSendLabel => 'Изпрати коментар';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Коментарът е публикуван';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Коментарът не можа да се публикува';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'лупа',
      one: 'луп',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Не е от Divine';

  @override
  String get metadataBadgeHumanMade => 'Направено от човек';

  @override
  String get metadataSoundsLabel => 'Звуци';

  @override
  String get metadataOriginalSound => 'Оригинален звук';

  @override
  String get metadataVerificationLabel => 'Проверка';

  @override
  String get metadataDeviceAttestation => 'Атестация на устройството';

  @override
  String get metadataPgpSignature => 'PGP подпис';

  @override
  String get metadataC2paCredentials =>
      'C2PA Идентификационни данни за съдържание';

  @override
  String get metadataProofManifest => 'Доказателствен манифест';

  @override
  String get metadataVerificationInfoTooltip =>
      'Какво означават тези проверки?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Какво означават тези проверки';

  @override
  String get metadataVerificationInfoIntro =>
      'Тези сигнали идват от камерата и от самия видеофайл. Колкото повече от тях носи едно видео, толкова повече можем да докажем за произхода му.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Операционната система на телефона гарантира за приложението, което е записало това. Силно доказателство, че идва от камера, а не от качен от някого файл.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Видеото е подписано криптографски в момента на заснемане. Ако после се промени дори един кадър, подписът се чупи.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Запис за произход по индустриален стандарт, който пътува вътре във файла — така и приложения извън Divine могат да го проверят.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Пълният запис на ProofMode: отпечатък на файла, времеви печат и контекст на заснемане, заедно с видеото.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Липсваща проверка не прави видеото фалшиво. По-старите клипове и качванията никога не са имали такава — означава само, че не можем да докажем тази част.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Научете повече на $url';
  }

  @override
  String get metadataCreatorLabel => 'Създател';

  @override
  String get metadataCollaboratorsLabel => 'Сътрудници';

  @override
  String get metadataInspiredByLabel => 'Вдъхновено от';

  @override
  String get metadataRepostedByLabel => 'Повторно публикувано от';

  @override
  String metadataMoreReposters(int count) {
    return 'още $count';
  }

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Лупове',
      one: 'Луп',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Харесвания';

  @override
  String get metadataCommentsLabel => 'Коментари';

  @override
  String get metadataRepostsLabel => 'Репостове';

  @override
  String get metadataVineStatsLabel => 'Във Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops лупа · $likes харесвания · $comments коментари · $reposts репоста';
  }

  @override
  String get metadataDivineStatsLabel => 'В Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views гледания · $likes харесвания · $comments коментари · $reposts репоста';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Публикувано на $date';
  }

  @override
  String get devOptionsTitle => 'Опции за разработчици';

  @override
  String get devOptionsDisableDeveloperMode =>
      'Изключване на режим за разработчици';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Скриване на опциите за разработчици от настройките';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Режимът за разработчици е изключен';

  @override
  String get devOptionsShorebirdTitle => 'Корекции на Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Активна корекция';

  @override
  String get devOptionsShorebirdNoPatch => 'Няма инсталирана корекция';

  @override
  String get devOptionsShorebirdUnavailable => 'Не е налично в тази компилация';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Корекциите работят само в компилация, създадена с shorebird release.';

  @override
  String get devOptionsShorebirdLoading =>
      'Четене на състоянието на корекцията…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Тестовият канал още не е проверен.';

  @override
  String get devOptionsShorebirdCheck => 'Провери тестовия канал';

  @override
  String get devOptionsShorebirdApply => 'Приложи тестовата корекция';

  @override
  String get devOptionsShorebirdUseStable =>
      'Върни се към стабилни актуализации';

  @override
  String get devOptionsShorebirdChecking => 'Проверка на тестовия канал…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Има готова тестова корекция.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Няма тестова корекция за тази версия.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Изтеглено. Рестартирайте приложението, за да го заредите.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Готово е връщане назад. Рестартирайте, за да се върнете към базовата версия.';

  @override
  String get devOptionsShorebirdApplying => 'Изтегляне и инсталиране…';

  @override
  String get devOptionsShorebirdApplied =>
      'Инсталирано. Рестартирайте приложението, за да го заредите.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Нищо не е инсталирано. Проверете тестовия канал и опитайте отново.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Избиране на стабилния канал…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Стабилният канал е избран. Рестартирайте, за да проверите за стабилна корекция.';

  @override
  String get devOptionsShorebirdFailure =>
      'Не се получи. Проверете журналите за подробности.';

  @override
  String get devOptionsPageLoadTimes => 'Време за зареждане на страницата';

  @override
  String get devOptionsNoPageLoads =>
      'Още няма регистрирани зареждания на страници.\nРазгледай приложението, за да видиш данните за времето.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Видим: ${visibleMs}ms |  Данни: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Най-бавните екрани';

  @override
  String get devOptionsVideoPlaybackFormat =>
      'Формат за възпроизвеждане на видео';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Превключване на среда?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Превключване към $envName?\n\nТова ще изчисти кешираните видео данни и ще се свърже отново с новото реле.';
  }

  @override
  String get devOptionsCancel => 'Отказ';

  @override
  String get devOptionsSwitch => 'Превключване';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Превключено към $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Превключено към $formatName — кешът е изчистен';
  }

  @override
  String get featureFlagTitle => 'Флагове за функции';

  @override
  String get featureFlagResetAllTooltip =>
      'Нулирай всички флагове до стойностите по подразбиране';

  @override
  String get featureFlagError => 'Грешка';

  @override
  String get relaySettingsTitle => 'Релета';

  @override
  String get relaySettingsInfoTitle =>
      'Divine е отворена система - ти контролираш връзките си';

  @override
  String get relaySettingsInfoDescription =>
      'Тези релета разпространяват съдържанието ти в децентрализираната Nostr мрежа. Можеш да добавяш или махаш релета когато поискаш.';

  @override
  String get relaySettingsLearnMoreNostr => 'Научи повече за Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Намери публични релета на nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Приложението не функционира';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine изисква поне едно реле, за да зарежда видеа, да публикува съдържание и да синхронизира данни.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Възстановяване на релето по подразбиране';

  @override
  String get relaySettingsAddCustomRelay => 'Добави персонализирано реле';

  @override
  String get relaySettingsAddRelay => 'Добави реле';

  @override
  String get relaySettingsRetry => 'Опитай пак';

  @override
  String get relaySettingsNoStats => 'Все още няма налична статистика';

  @override
  String get relaySettingsConnection => 'Връзка';

  @override
  String get relaySettingsConnected => 'Свързано';

  @override
  String get relaySettingsDisconnected => 'Прекъснато';

  @override
  String get relaySettingsSessionDuration => 'Продължителност на сесията';

  @override
  String get relaySettingsLastConnected => 'Последно свързано';

  @override
  String get relaySettingsDisconnectedLabel => 'Прекъсната връзка';

  @override
  String get relaySettingsReason => 'Причина';

  @override
  String get relaySettingsActiveSubscriptions => 'Активни абонаменти';

  @override
  String get relaySettingsTotalSubscriptions => 'Общ брой абонаменти';

  @override
  String get relaySettingsEventsReceived => 'Получени събития';

  @override
  String get relaySettingsEventsSent => 'Изпратени събития';

  @override
  String get relaySettingsRequestsThisSession => 'Иска тази сесия';

  @override
  String get relaySettingsFailedRequests => 'Неуспешни заявки';

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Информацията за релето се зарежда...';

  @override
  String get relaySettingsAboutRelay => 'Относно релето';

  @override
  String get relaySettingsSupportedNips => 'Поддържани NIP';

  @override
  String get relaySettingsSoftware => 'Софтуер';

  @override
  String get relaySettingsViewWebsite => 'Виж уебсайта';

  @override
  String get relaySettingsRemoveRelayTitle => 'Да махнем ли релето?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Сигурен ли си, че искаш да премахнеш това реле?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Премахване на релето на Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Премахването на релето на Divine ще влоши работата на приложението. Видеата, публикуването и синхронизацията може да станат по-малко надеждни. Прави го само ако си опитен потребител на Nostr.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Премахване на релето';

  @override
  String get relaySettingsCancel => 'Отказ';

  @override
  String get relaySettingsRemove => 'Махни';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Премахнато реле: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay =>
      'Премахването на релето не бе успешно';

  @override
  String get relaySettingsForcingReconnection =>
      'Принудително повторно свързване с релето...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Свързани сме с $count реле(та)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Не успяхме да се свържем с релетата. Провери мрежовата си връзка.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Запазено е на това устройство. Ще го синхронизираме с акаунта ти, когато публикуването заработи отново.';

  @override
  String get relaySettingsAddRelayTitle => 'Добави реле';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Въведи WebSocket URL на релето, което искаш да добавиш:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Разгледай публичните релета на nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Добави';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Добавено реле: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Не успяхме да добавим релето. Провери URL адреса и опитай пак.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL адресът за предаване трябва да започва с wss:// или ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'URL на релето трябва да използва wss:// (ws:// е позволено само за localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Възстановено реле по подразбиране: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Не успяхме да възстановим релето по подразбиране. Провери мрежовата си връзка.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Браузърът не може да се отвори';

  @override
  String get relaySettingsFailedToOpenLink => 'Неуспешно отваряне на връзката';

  @override
  String get relaySettingsExternalRelay => 'Външно реле';

  @override
  String get relaySettingsNotConnected => 'Няма връзка';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Прекъсната преди $duration';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count абон.';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count събития';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'преди $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine използва протокола Nostr за децентрализирано публикуване. Съдържанието ти живее на релета, които сам избираш, а ключовете ти са твоята самоличност.';

  @override
  String get nostrSettingsSectionNetwork => 'Мрежа';

  @override
  String get nostrSettingsSectionAccount => 'Акаунт';

  @override
  String get nostrSettingsSectionDangerZone => 'Опасна зона';

  @override
  String get nostrSettingsRelays => 'Релета';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Управлявай връзките с Nostr релета';

  @override
  String get nostrSettingsRelayDiagnostics => 'Диагностика на релета';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Дебъг на свързаността с релетата и мрежови проблеми';

  @override
  String get nostrSettingsMediaServers => 'Медийни сървъри';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Настрой Blossom сървъри за качване';

  @override
  String get settingsDeveloperOptions => 'Опции за разработчици';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Превключвател на средата и настройки за дебъг';

  @override
  String get nostrSettingsKeyManagement => 'Управление на ключове';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Експортирай, архивирай и възстановявай Nostr ключовете си';

  @override
  String get nostrSettingsClientAttribution => 'Атрибуция на клиента';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Добавяй клиентски таг на Divine към събитията, които публикуваш, за да могат другите Nostr приложения да ги приписват правилно. Без него сигналите, които подаваш, тежат по-малко, когато модераторите ни ги преглеждат.';

  @override
  String get nostrSettingsMoveAccount => 'Премести акаунта си';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Изтегли архива си и премести публикациите и видеата си към друг relay или медиен сървър.';

  @override
  String get nostrSettingsRemoveKeys => 'Махни ключовете от устройството';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Изтрий частния си ключ само от това устройство. Съдържанието ти остава на релетата, но ще ти трябва nsec резервно копие, за да влезеш отново в акаунта си.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Не успяхме да махнем този акаунт от това устройство. Опитай пак.';

  @override
  String get nostrSettingsDeleteAccount => 'Изтрий акаунта и данните';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Изпраща заявки за изтриване на съдържанието ти и те отписва на това устройство. Релетата, клиентите, индексите за търсене и другите устройства с вход може да запазят копия.';

  @override
  String get relayDiagnosticTitle => 'Релейна диагностика';

  @override
  String get relayDiagnosticRefreshTooltip => 'Обновяване на диагностиката';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Последно опресняване: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Състояние на релето';

  @override
  String get relayDiagnosticInitialized => 'Инициализирано';

  @override
  String get relayDiagnosticReady => 'Готови';

  @override
  String get relayDiagnosticNotInitialized => 'Не е инициализирано';

  @override
  String get relayDiagnosticDatabaseEvents => 'Събития в базата данни';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Активни абонаменти';

  @override
  String get relayDiagnosticExternalRelays => 'Външни релета';

  @override
  String get relayDiagnosticConfigured => 'Конфигуриран';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count реле(а)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Свързан';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Видео събития';

  @override
  String get relayDiagnosticHomeFeed => 'Домашна емисия';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count видеа';
  }

  @override
  String get relayDiagnosticDiscovery => 'Откриване';

  @override
  String get relayDiagnosticLoading => 'Зарежда се';

  @override
  String get relayDiagnosticYes => 'Да';

  @override
  String get relayDiagnosticNo => 'Не';

  @override
  String get relayDiagnosticTestDirectQuery => 'Тествай директна заявка';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Мрежова свързаност';

  @override
  String get relayDiagnosticRunNetworkTest => 'Изпълни мрежов тест';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom сървър';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Тествай всички ендпойнти';

  @override
  String get relayDiagnosticStatus => 'Статус';

  @override
  String get relayDiagnosticUrl => 'URL адрес';

  @override
  String get relayDiagnosticError => 'Грешка';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API на FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'Основен URL адрес';

  @override
  String get relayDiagnosticSummary => 'Резюме';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (ср. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Повторно тестване на всички';

  @override
  String get relayDiagnosticRetrying => 'Повторен опит...';

  @override
  String get relayDiagnosticRetryConnection => 'Повторен опит за свързване';

  @override
  String get relayDiagnosticTroubleshooting => 'Отстраняване на неизправности';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Зелен статус = свързано и работи\n• Червен статус = връзката не мина\n• Ако мрежовият тест не минава, провери интернет връзката\n• Ако релетата са конфигурирани, но не са свързани, натисни „Повторен опит за свързване“\n• Направи екранна снимка на този екран за отстраняване на проблеми';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Всички REST ендпойнти работят!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Някои REST ендпойнти не минаха - виж подробностите по-горе';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Намерени $count видео събития в базата данни';
  }

  @override
  String get relayDiagnosticQueryFailed => 'Неуспешна заявка. Опитай пак.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Свързани сме с $count реле(та)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Не успяхме да се свържем с нито едно реле';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Неуспешен повторен опит за свързване. Опитай пак.';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Свързан и удостоверен';

  @override
  String get relayDiagnosticConnectedOnly => 'Свързан';

  @override
  String get relayDiagnosticNotConnected => 'Не е свързан';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Няма конфигурирани релета';

  @override
  String get relayDiagnosticFailed => 'Неуспешно';

  @override
  String get notificationSettingsTitle => 'Известия';

  @override
  String get notificationSettingsResetTooltip =>
      'Възстановяване на настройките по подразбиране';

  @override
  String get notificationSettingsTypes => 'Видове известия';

  @override
  String get notificationSettingsLikes => 'Харесвания';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Когато някой хареса видеата ти';

  @override
  String get notificationSettingsComments => 'Коментари';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Когато някой коментира видеата ти';

  @override
  String get notificationSettingsFollows => 'Следва';

  @override
  String get notificationSettingsFollowsSubtitle => 'Когато някой те следва';

  @override
  String get notificationSettingsMentions => 'Споменавания';

  @override
  String get notificationSettingsMentionsSubtitle => 'Когато те споменат';

  @override
  String get notificationSettingsReposts => 'Репостове';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Когато някой препубликува видеата ти';

  @override
  String get notificationSettingsNewPosts => 'Нови видеа';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Когато някой, когото следиш, публикува';

  @override
  String get notificationSettingsActions => 'Действия';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Маркирай всички като прочетени';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Маркирай всички известия като прочетени';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Всички известия са маркирани като прочетени';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Неуспешно маркиране на всички като прочетени';

  @override
  String get notificationSettingsResetToDefaults =>
      'Настройките се нулират до стойностите по подразбиране';

  @override
  String get notificationSettingsAbout => 'Относно известията';

  @override
  String get notificationSettingsAboutDescription =>
      'Известията се захранват от Nostr. Обновяването в реално време зависи от връзката ти с Nostr релета. Някои известия може да закъсняват.';

  @override
  String get safetySettingsWhatYouSee => 'КАКВО ВИЖДАШ';

  @override
  String get safetySettingsWhatYouPublish => 'КАКВО ПУБЛИКУВАШ';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Показвай само видеа, хостнати от Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Скривай видеа, обслужвани от други медийни хостове';

  @override
  String get safetySettingsModeration => 'УМЕРЕНОСТ';

  @override
  String get safetySettingsBlockedUsers => 'БЛОКИРАНИ ПОТРЕБИТЕЛИ';

  @override
  String get safetySettingsAgeVerification => 'ПРОВЕРКА НА ВЪЗРАСТТА';

  @override
  String get safetySettingsAgeConfirmation =>
      'Потвърждавам, че съм навършил 18 години';

  @override
  String get safetySettingsAgeRequired =>
      'Изисква се за гледане на съдържание за възрастни';

  @override
  String get safetySettingsAgeLockedForMinor => 'Заключено за твоя акаунт';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Официална услуга за модериране (включена по подразбиране)';

  @override
  String get safetySettingsPeopleIFollow => 'Хора, които следвам';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Абонирай се за етикети от хората, които следваш';

  @override
  String get safetySettingsAddCustomLabeler => 'Добави персонализиран етикет';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Въведи npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Добави персонализиран етикет';

  @override
  String get safetySettingsRemoveLabeler => 'Премахни етикета';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Въведи npub адрес';

  @override
  String get safetySettingsNoBlockedUsers => 'Няма блокирани потребители';

  @override
  String get safetySettingsUnblock => 'Разблокирай';

  @override
  String get safetySettingsUserUnblocked => 'Потребителят е деблокиран';

  @override
  String get safetySettingsCancel => 'Отказ';

  @override
  String get safetySettingsAdd => 'Добави';

  @override
  String get analyticsTitle => 'Анализ на създателите';

  @override
  String get analyticsDiagnosticsTooltip => 'Диагностика';

  @override
  String get analyticsDiagnosticsSemanticLabel =>
      'Превключване на диагностиката';

  @override
  String get analyticsRetry => 'Опитай пак';

  @override
  String get analyticsUnableToLoad => 'Анализът не може да се зареди.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Влез, за да видиш анализите за създатели.';

  @override
  String get analyticsViewDataUnavailable =>
      'Данните за гледанията в момента не са достъпни от релето за тези публикации. Показателите за харесвания, коментари и репостове все още са точни.';

  @override
  String get analyticsViewDataTitle => 'Преглед на данни';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Обновено $time • Резултатите използват харесвания, коментари, репостове и гледания/лупове от Funnelcake, когато са налични.';
  }

  @override
  String get analyticsVideos => 'Видеа';

  @override
  String get analyticsViews => 'Гледания';

  @override
  String get analyticsInteractions => 'Взаимодействия';

  @override
  String get analyticsEngagement => 'Годеж';

  @override
  String get analyticsFollowers => 'Последователи';

  @override
  String get analyticsAvgPerPost => 'Ср./Публикация';

  @override
  String get analyticsInteractionMix => 'Смес за взаимодействие';

  @override
  String get analyticsLikes => 'Харесвания';

  @override
  String get analyticsComments => 'Коментари';

  @override
  String get analyticsReposts => 'Репостове';

  @override
  String get analyticsPerformanceHighlights => 'Акценти в изпълнението';

  @override
  String get analyticsMostViewed => 'Най-гледан';

  @override
  String get analyticsMostDiscussed => 'Най-обсъждани';

  @override
  String get analyticsMostReposted => 'Най-често публикувано';

  @override
  String get analyticsNoVideosYet => 'Още няма видеа';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Данните за гледанията са недостъпни';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count показвания';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count коментара';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count репоста';
  }

  @override
  String get analyticsTopContent => 'Топ съдържание';

  @override
  String get analyticsPublishPrompt =>
      'Публикувай няколко видеа, за да видиш класациите.';

  @override
  String get analyticsEngagementRateExplainer =>
      '% от дясната страна = процент на ангажираност (взаимодействия, разделени на показвания).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Процентът на ангажираност изисква данни за гледанията; стойностите се показват като N/A, докато липсват гледания.';

  @override
  String get analyticsEngagementLabel => 'Годеж';

  @override
  String get analyticsViewsUnavailable => 'Гледанията не са налични';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count взаимодействия';
  }

  @override
  String get analyticsPostAnalytics => 'Анализи на публикацията';

  @override
  String get analyticsOpenPost => 'Отвори публикацията';

  @override
  String get analyticsRecentDailyInteractions =>
      'Скорошни ежедневни взаимодействия';

  @override
  String get analyticsNoActivityYet =>
      'Все още няма активност в този диапазон.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Взаимодействия = харесвания + коментари + репостове по дата на публикуване.';

  @override
  String get analyticsDailyBarExplainer =>
      'Дължината на лентата е спрямо най-силния ти ден в този прозорец.';

  @override
  String get analyticsAudienceSnapshot => 'Моментна снимка на аудиторията';

  @override
  String analyticsFollowersCount(String count) {
    return 'Последователи: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Следвам: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Разбивките по източник на аудитория, гео и време ще се попълнят, когато Funnelcake добави ендпойнти за анализ на аудиторията.';

  @override
  String get analyticsRetention => 'Задържане';

  @override
  String get analyticsRetentionWithViews =>
      'Кривата на задържане и разбивката на времето за гледане ще се появят, след като задържането на секунда/на кофа пристигне от Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Данните за задържане не са налични, докато анализите за гледане+време за гледане не бъдат върнати от Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Диагностика';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Общо видеа: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'С гледания: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Липсващи гледания: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Попълнени (пакетно): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Хидратирани (/гледания): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Източници: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Използвай примерни данни';

  @override
  String get analyticsNa => 'Няма';

  @override
  String get authCreateNewAccount => 'Създай нов Divine акаунт';

  @override
  String get authCreateNewAccountShort => 'Създай нов профил';

  @override
  String get authSignInDifferentAccount => 'Влез с друг акаунт';

  @override
  String get authUseAnotherAccount => 'Използвай друг профил';

  @override
  String authContinueAs(String displayName) {
    return 'Продължи като $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Черновите и клиповете ти са запазени за този акаунт';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Влизането тук ще скрие тези чернови и клипове';

  @override
  String get authTermsPrefix =>
      'Като избереш опция по-долу, потвърждаваш, че си на поне 16 години (или си преминал(а) ';

  @override
  String get authTermsAgeAuthorizationCta => 'възрастовото одобрение на Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') и приемаш ';

  @override
  String get authTermsOfService => 'Условия за ползване';

  @override
  String get authPrivacyPolicy => 'Политика за поверителност';

  @override
  String get authTermsAnd => ', и';

  @override
  String get authSafetyStandards => 'Стандарти за безопасност';

  @override
  String get authAmberNotInstalled => 'Приложението Amber не е инсталирано';

  @override
  String get authAmberConnectionFailed => 'Неуспешно свързване с Амбър';

  @override
  String get authPasswordResetSent =>
      'Ако има акаунт с този имейл, изпратихме линк за нулиране на паролата.';

  @override
  String get authSignInTitle => 'Влез';

  @override
  String get authEmailLabel => 'Имейл';

  @override
  String get authPasswordLabel => 'Парола';

  @override
  String get authConfirmPasswordLabel => 'Потвърди паролата';

  @override
  String get authEmailRequired => 'Имейлът е задължителен';

  @override
  String get authEmailInvalid => 'Моля, въведи валиден имейл';

  @override
  String get authPasswordRequired => 'Паролата е задължителна';

  @override
  String get authConfirmPasswordRequired => 'Моля, потвърди паролата си';

  @override
  String get authPasswordsDoNotMatch => 'Паролите не съвпадат';

  @override
  String get authForgotPassword => 'Забравена парола?';

  @override
  String get authImportNostrKey => 'Импортиране на ключ Nostr';

  @override
  String get authConnectSignerApp => 'Свържи приложение за подписване';

  @override
  String get authSignInWithAmber => 'Влез с Amber';

  @override
  String get authSignInWithBrowserExtension => 'Вход с разширение за браузър';

  @override
  String get authNip07ConnectionFailed =>
      'Неуспешно свързване с разширението на браузъра.';

  @override
  String get authNip07ExtensionNotFound =>
      'Не е открито разширение за браузър. Инсталирайте Alby, nos2x или друго съвместимо с NIP-07 разширение.';

  @override
  String get authSignInOptionsTitle => 'Опции за влизане';

  @override
  String get authInfoEmailPasswordTitle => 'Имейл и парола';

  @override
  String get authInfoEmailPasswordDescription =>
      'Влез с Divine акаунта си. Ако си се регистрирал с имейл и парола, използвай ги тук.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Вече имаш Nostr самоличност? Импортирай частния си nsec ключ от друг клиент.';

  @override
  String get authInfoSignerAppTitle => 'Подписващо приложение';

  @override
  String get authInfoSignerAppDescription =>
      'Свържи NIP-46 съвместим отдалечен подписващ агент като nsecBunker за по-добра сигурност на ключовете.';

  @override
  String get authInfoAmberTitle => 'Амбър';

  @override
  String get authInfoAmberDescription =>
      'Използвай Amber Signer на Android, за да управляваш Nostr ключовете си сигурно.';

  @override
  String get authInfoBrowserExtensionTitle => 'Разширение за браузър';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Влезте чрез NIP-07 разширение за браузър като Alby или nos2x. Ключовете ви остават в разширението — Divine никога не ги вижда.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Грешен имейл или парола. Опитай отново.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Потвърди имейла си, преди да влезеш — провери входящата си поща за връзката.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Това не изглежда като валиден имейл адрес.';

  @override
  String get authSignInErrorNetwork =>
      'Сървърът е недостъпен. Провери връзката си и опитай отново.';

  @override
  String get authSignInErrorGeneric => 'Нещо се обърка. Опитай отново.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Не си сигурен как влезе последния път? ';

  @override
  String get authSignInOptionsHintCta => 'Виж всички опции за вход';

  @override
  String get authCreateAccountTitle => 'Създаване на акаунт';

  @override
  String get authBackToInviteCode => 'Назад към кода на поканата';

  @override
  String get authUseDivineNoBackup => 'Използвай Divine без резервно копие';

  @override
  String get authSkipConfirmTitle => 'Едно последно нещо...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Готово, вътре си! Ще създадем сигурен ключ за Divine акаунта ти.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Без имейл ключът ти е единственият начин Divine да разбере, че акаунтът е твой.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Можеш да намериш ключа си в приложението, но ако Nostr ключовете не са ти ежедневие, добави имейл и парола сега. Така по-лесно ще влизаш и ще си върнеш акаунта, ако изгубиш или нулираш това устройство.';

  @override
  String get authAddEmailPassword => 'Добави имейл и парола';

  @override
  String get authUseThisDeviceOnly => 'Използвай само това устройство';

  @override
  String get authCompleteRegistration => 'Завърши регистрацията си';

  @override
  String get authVerifying => 'Проверка...';

  @override
  String get authVerificationLinkSent =>
      'Изпратихме връзка за потвърждение на:';

  @override
  String get authClickVerificationLink =>
      'Натисни линка в имейла си, за да завършиш регистрацията.';

  @override
  String get authPleaseWaitVerifying =>
      'Изчакай, докато потвърдим имейла ти...';

  @override
  String get authWaitingForVerification => 'Чака се проверка';

  @override
  String get authOpenEmailApp => 'Отвори имейл приложението';

  @override
  String get authVerificationPinPrompt =>
      'Или въведи 6-цифрения код от имейла си';

  @override
  String get authVerificationPinFieldLabel => '6-цифрен код';

  @override
  String get authVerificationPinSubmit => 'Потвърди кода';

  @override
  String get authVerificationResendPrompt => 'Не го получи?';

  @override
  String get authVerificationResend => 'Изпрати отново';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Изпрати отново след $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Не успяхме да изпратим имейла отново. Опитай пак.';

  @override
  String get authVerificationResendExpired =>
      'Тази регистрация изтече. Започни отново, за да получиш нов код.';

  @override
  String get authVerificationResendUnavailable =>
      'Повторното изпращане не е налично в момента. Използвай 6-цифрения код от имейла, който вече ти изпратихме.';

  @override
  String get authVerificationPollingStopped =>
      'Спряхме да проверяваме вместо теб. Въведи 6-цифрения код от имейла си, за да завършиш влизането.';

  @override
  String get authWelcomeToDivine => 'Радваме се, че си в Divine!';

  @override
  String get authEmailVerified => 'Имейлът ти е потвърден.';

  @override
  String get authSigningYouIn => 'Вписваме те';

  @override
  String get authErrorTitle => 'Опа.';

  @override
  String get authVerificationFailed =>
      'Не успяхме да потвърдим имейла ти.\nОпитай пак.';

  @override
  String get authStartOver => 'Започни отначало';

  @override
  String get authEmailVerifiedLogin =>
      'Имейлът е потвърден! Влез, за да продължиш.';

  @override
  String get authVerificationLinkExpired =>
      'Тази връзка за потвърждение вече не е валидна.';

  @override
  String get authVerificationConnectionError =>
      'Не можем да потвърдим имейла. Провери връзката си и опитай пак.';

  @override
  String get authWaitlistConfirmTitle => 'Вътре си!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Ще пращаме новини на $email.\nКогато има още кодове за покани, ще ти ги изпратим.';
  }

  @override
  String get authOk => 'Добре';

  @override
  String get authTryAgain => 'Опитай пак';

  @override
  String get authContactSupport => 'Свържи се с поддръжката';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Не може да се отвори $email';
  }

  @override
  String get authAddInviteCode => 'Добави своя код за покана';

  @override
  String get authInviteCodeLabel => 'Код за покана';

  @override
  String get authEnterYourCode => 'Въведи своя код';

  @override
  String get authNext => 'Следваща';

  @override
  String get authJoinWaitlist => 'Присъедини се към списъка с чакащи';

  @override
  String get authJoinWaitlistTitle => 'Присъедини се към списъка с чакащи';

  @override
  String get authJoinWaitlistDescription =>
      'Остави имейла си и ще ти пишем, когато достъпът се отвори.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Изпращай ми вдъхновение от Divine';

  @override
  String get authInviteAccessHelp => 'Помощ с поканите';

  @override
  String get authGeneratingConnection => 'Генериране на връзка...';

  @override
  String get authConnectedAuthenticating => 'Свързан! Удостоверява се...';

  @override
  String get authConnectionTimedOut =>
      'Времето за изчакване на връзката изтече';

  @override
  String get authApproveConnection =>
      'Увери се, че връзката е одобрена в приложението ти за подписване.';

  @override
  String get authConnectionCancelled => 'Връзката е отменена';

  @override
  String get authConnectionCancelledMessage => 'Връзката беше прекратена.';

  @override
  String get authConnectionFailed => 'Връзката е неуспешна';

  @override
  String get authUnknownError => 'Възникна неизвестна грешка.';

  @override
  String get authNostrConnectStartFailed =>
      'Не успяхме да се свържем с приложението за подписване. Провери връзката си и опитай пак.';

  @override
  String get authNostrConnectInvalidSession =>
      'Тази връзка вече не е валидна. Започни нова.';

  @override
  String get authNostrConnectSetupFailed =>
      'Почти готово — не успяхме да завършим влизането ти. Опитай пак.';

  @override
  String get authUrlCopied => 'URL адресът е копиран в клипборда';

  @override
  String get authConnectToDivine => 'Свържи се с Divine';

  @override
  String get authPasteBunkerUrl => 'Постави bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Невалиден Bunker URL. Трябва да започва с bunker://';

  @override
  String get authScanSignerApp =>
      'Сканирай с приложението си за подписване, за да се свържеш.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Изчаква се връзка... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Копирай URL';

  @override
  String get authShare => 'Сподели';

  @override
  String get authAddBunker => 'Добави Bunker';

  @override
  String get authCompatibleSignerApps => 'Съвместими приложения за подписване';

  @override
  String get authFailedToConnect => 'Неуспешно свързване';

  @override
  String get authResetPasswordTitle => 'Нулиране на парола';

  @override
  String get authResetPasswordSubtitle =>
      'Въведи новата си парола. Трябва да е поне 8 знака.';

  @override
  String get authNewPasswordLabel => 'Нова парола';

  @override
  String get authConfirmNewPasswordLabel => 'Потвърди новата парола';

  @override
  String get authPasswordTooShort => 'Паролата трябва да е поне 8 знака';

  @override
  String get authPasswordResetSuccess => 'Паролата е сменена. Влез отново.';

  @override
  String get authPasswordResetFailed => 'Неуспешно нулиране на паролата';

  @override
  String get authUnexpectedError => 'Стана неочаквана грешка. Опитай пак.';

  @override
  String get authUpdatePassword => 'Актуализиране на паролата';

  @override
  String get authSecureAccountTitle => 'Защитен акаунт';

  @override
  String get authUnableToAccessKeys =>
      'Няма достъп до ключовете ти. Опитай пак.';

  @override
  String get authRegistrationFailed => 'Регистрацията не мина';

  @override
  String get authRegistrationComplete =>
      'Регистрацията е готова. Провери имейла си.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'Не успяхме да изпратим имейл за нулиране.';

  @override
  String get authSending => 'Изпращаме...';

  @override
  String get authSignInButton => 'Вход';

  @override
  String get authVerificationErrorTimeout =>
      'Потвърждението изтече. Опитай да се регистрираш отново.';

  @override
  String get authVerificationErrorMissingCode =>
      'Потвърждението не мина - липсва код за оторизация.';

  @override
  String get authVerificationErrorPollFailed =>
      'Потвърждението не мина. Опитай пак.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Мрежова грешка при влизане. Опитай пак.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Потвърждението не мина. Опитай да се регистрираш отново.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Входът не мина. Опитай да влезеш ръчно.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Този имейл вече е регистриран. Влез вместо това.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Този код не съвпада. Провери го отново и опитай пак.';

  @override
  String get authVerificationErrorPinExpired =>
      'Този код е изтекъл. Натисни Изпрати отново, за да получиш нов.';

  @override
  String get authVerificationErrorPinLocked =>
      'Твърде много опити. Натисни Изпрати отново, за да получиш нов код.';

  @override
  String get authVerificationErrorPinFailed =>
      'Не успяхме да потвърдим този код. Опитай пак.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Въвеждането на код не е налично в момента. Натисни връзката в имейла си или изпрати отново, за да получиш нова.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Въведи код за покана като ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Този код за покана не изглежда валиден.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Този код за покана вече е използван или е отменен.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Поканите на този създател свършиха';

  @override
  String get authInviteGateErrorUnavailable =>
      'Този код за покана не е наличен. Запиши се в списъка на чакащите и ще ти изпратим покана, щом се освободи място.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Не успяхме да проверим този код. Опитай пак.';

  @override
  String get authInviteGateErrorUnknown =>
      'Нещо се обърка. Опитай пак с кода си за покана.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Този код за покана вече не е наличен. Върни се към кода за покана, присъедини се към списъка с чакащи или се свържи с поддръжката.';

  @override
  String get authInviteErrorInvalid =>
      'Този код за покана не може да се използва в момента. Върни се към кода за покана, присъедини се към списъка с чакащи или се свържи с поддръжката.';

  @override
  String get authInviteErrorTemporary =>
      'Не можахме да потвърдим поканата ти в момента. Върни се към кода за покана и опитай пак или се свържи с поддръжката.';

  @override
  String get authInviteErrorUnknown =>
      'Не успяхме да активираме поканата ти. Върни се към кода за покана, присъедини се към списъка с чакащи или се свържи с поддръжката.';

  @override
  String get shareSheetSave => 'Запази';

  @override
  String get shareSheetRemoveFromSaved => 'Премахни от запазени';

  @override
  String get shareSheetSaveToGallery => 'Запази в галерията';

  @override
  String get shareSheetSaveWithWatermark => 'Запази с воден знак';

  @override
  String get shareSheetSaveVideo => 'Запази видео';

  @override
  String get shareSheetAddToClips => 'Добави към клипове';

  @override
  String get shareSheetNameClipTitle => 'Дай име на този клип';

  @override
  String get shareSheetNameClipSubtitle =>
      'Избери име, което ще разпознаеш в библиотеката си.';

  @override
  String get shareSheetClipTitleLabel => 'Заглавие на клипа';

  @override
  String get shareSheetSaveClip => 'Запази клипа';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '„$title“ е запазен в клиповете';
  }

  @override
  String get shareSheetUntitledClip => 'Клип без заглавие';

  @override
  String get shareSheetAddToClipsFailed => 'Не можа да се добави към клипове';

  @override
  String get shareSheetAddToList => 'Добави към списъка';

  @override
  String get shareSheetCopy => 'Копие';

  @override
  String get shareSheetShareVia => 'Сподели чрез';

  @override
  String get shareSheetEventJson => 'Събитие JSON';

  @override
  String get shareSheetEventId => 'ID на събитието';

  @override
  String get shareSheetMoreActions => 'Още действия';

  @override
  String get shareSheetCrosspost => 'Публикувай кръстосано';

  @override
  String get crosspostSheetTitle => 'Кръстосано публикуване на това видео';

  @override
  String get crosspostSheetSubtitle =>
      'Изпрати го до свързаните си платформи. Публикуването може да отнеме няколко минути.';

  @override
  String get crosspostSubmit => 'Публикувай кръстосано';

  @override
  String get crosspostStatusQueued => 'В опашката';

  @override
  String get crosspostStatusUploading => 'Качва се';

  @override
  String get crosspostStatusProcessing => 'Обработва се';

  @override
  String get crosspostStatusPosted => 'Публикувано';

  @override
  String get crosspostStatusFailed => 'Неуспешно';

  @override
  String get crosspostStatusSkipped => 'Пропуснато';

  @override
  String get crosspostStatusNeedsReauth => 'Изисква повторно свързване';

  @override
  String get crosspostViewPost => 'Виж публикацията';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Свържи отново $platform в настройките за кръстосано публикуване, за да продължиш да публикуваш.';
  }

  @override
  String get crosspostReconnect => 'Свържи отново';

  @override
  String get crosspostErrorNotOwner =>
      'Само твои видеа могат да се публикуват кръстосано.';

  @override
  String get crosspostErrorNotEligible =>
      'Това видео не може да се публикува кръстосано.';

  @override
  String get crosspostErrorNotConnected => 'Тази платформа не е свързана.';

  @override
  String get crosspostErrorUnauthorized =>
      'Свържи отново акаунта си и опитай пак.';

  @override
  String get crosspostErrorNetwork =>
      'Не успяхме да достигнем услугата за кръстосано публикуване. Опитай пак след малко.';

  @override
  String get crosspostFailedGeneric => 'Кръстосаното публикуване не успя.';

  @override
  String get crosspostStillWorking =>
      'Още се работи. Можеш да затвориш това — публикуването продължава във фонов режим.';

  @override
  String get crosspostDone => 'Готово';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Запазено в галерията';

  @override
  String get watermarkDownloadShare => 'Сподели';

  @override
  String get watermarkDownloadDone => 'Готово';

  @override
  String get watermarkDownloadPhotosAccessNeeded =>
      'Необходим е достъп до снимки';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'За да запазваш видеа, дай достъп до снимките в настройките.';

  @override
  String get watermarkDownloadOpenSettings => 'Отвори Настройки';

  @override
  String get watermarkDownloadNotNow => 'Не сега';

  @override
  String get watermarkDownloadFailed => 'Неуспешно изтегляне';

  @override
  String get watermarkDownloadDismiss => 'Отхвърляне';

  @override
  String get watermarkDownloadStageDownloading => 'Изтегляне на видео';

  @override
  String get watermarkDownloadStageWatermarking => 'Добавяне на воден знак';

  @override
  String get watermarkDownloadStageSaving => 'Запазване в галерията';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Видеото се извлича от мрежата...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Добавя се воден знак Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Видеото с воден знак се запазва в галерията...';

  @override
  String get shareMenuBookmarks => 'Отметки';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count налични списъка за следване';
  }

  @override
  String get peopleListsAddToList => 'Добави към списъка';

  @override
  String get peopleListsSheetTitle => 'Добави към списък';

  @override
  String get peopleListsEmptyTitle => 'Още няма списъци';

  @override
  String get peopleListsEmptySubtitle =>
      'Създай списък, за да започнеш да групираш хора.';

  @override
  String get peopleListsCreateList => 'Създаване на списък';

  @override
  String get peopleListsNewListTitle => 'Нов списък';

  @override
  String get peopleListsRouteTitle => 'Списък с хора';

  @override
  String get peopleListsListNameLabel => 'Име на списък';

  @override
  String get peopleListsListNameHint => 'Близки приятели';

  @override
  String get peopleListsCreateButton => 'Създай';

  @override
  String get peopleListsAddPeopleTitle => 'Добави хора';

  @override
  String get peopleListsAddPeopleTooltip => 'Добави хора';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Добави хора към списъка';

  @override
  String get peopleListsListNotFoundTitle => 'Списъкът не е намерен';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Списъкът не е намерен. Може да е изтрит.';

  @override
  String get peopleListsListDeletedSubtitle => 'Този списък може да е изтрит.';

  @override
  String get peopleListsNoPeopleTitle => 'Няма хора в този списък';

  @override
  String get peopleListsNoPeopleSubtitle => 'Добави някого, за да започнеш';

  @override
  String get peopleListsNoVideosTitle => 'Още няма видеа';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Видеата от хората в списъка ще се появят тук';

  @override
  String get peopleListsNoVideosAvailable => 'Няма налични видеа';

  @override
  String get peopleListsFailedToLoadVideos => 'Не успяхме да заредим видеата';

  @override
  String get peopleListsVideoNotAvailable => 'Видеото не е налично';

  @override
  String get peopleListsBackToGridTooltip => 'Обратно към мрежата';

  @override
  String get peopleListsErrorLoadingVideos => 'Грешка при зареждане на видеа';

  @override
  String get peopleListsNoPeopleToAdd => 'Няма налични хора за добавяне.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Добави към $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Търси хора';

  @override
  String get peopleListsAddPeopleError =>
      'Не успяхме да заредим хората. Опитай пак.';

  @override
  String get peopleListsAddPeopleRetry => 'Опитай пак';

  @override
  String get peopleListsAddButton => 'Добави';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Добави $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'В $count списъка',
      one: 'В 1 списък',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Да премахнем $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Те ще бъдат премахнати от този списък.';

  @override
  String get peopleListsRemove => 'Премахни';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Премахнато $name от списъка';
  }

  @override
  String get peopleListsUndo => 'Отмяна';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Профил на $name. Натисни дълго, за да премахнеш.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Виж профила на $name';
  }

  @override
  String get shareMenuEditVideo => 'Редактиране на видео';

  @override
  String get shareMenuDeleteVideo => 'Изтрий видеото';

  @override
  String shareMenuVideoCount(int count) {
    return '$count видеа';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Това ще изтрие за постоянно това видео от Divine. Може още да се вижда в Nostr клиенти на трети страни, които използват други релета.';

  @override
  String get shareMenuCancel => 'Отказ';

  @override
  String get shareMenuDelete => 'Изтрий';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Изтриването още не е готово. Опитай пак след малко.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Можеш да триеш само собствените си видеа.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Влез отново, после пробвай да изтриеш.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Не успяхме да подпишем заявката за изтриване. Опитай пак.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Релето не прие тази заявка за изтриване. Опитай пак след малко.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Не можем да достигнем релето. Провери връзката си и опитай пак.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Изтрито. Не всички релета потвърдиха, така че може още да се вижда в други приложения.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Не успяхме да изтрием това видео. Опитай пак.';

  @override
  String get shareMenuUpdate => 'Актуализация';

  @override
  String get shareMenuChangeCover => 'Смяна на корицата';

  @override
  String get shareMenuVideoUpdated => 'Видеото е обновено';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count покани за сътрудници не бяха изпратени.',
      one: '1 покана за сътрудник не беше изпратена.',
    );
    return 'Видеото е актуализирано, но $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated => 'Влез отново и опитай пак.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Това видео няма възпроизводим източник, затова не може да се редактира.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Промяната не можа да бъде подписана. Опитай пак.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Релето не прие промяната. Опитай пак след малко.';

  @override
  String get videoUpdateErrorGeneric =>
      'Това видео не можа да бъде обновено. Опитай пак.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Да изтрием видеото?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Премахване на видеото…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Видеото е изтрито.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Видеото е изтрито. Може да отнеме малко време, докато изчезне отвсякъде.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Видеото е изтрито, но не успяхме да премахнем всяко копие. Свържи се с поддръжката.';

  @override
  String get authSessionExpired => 'Сесията ти изтече. Влез отново.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Входът не мина. Опитай пак.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Уеб удостоверяването не се поддържа в защитен режим. Използвай мобилното приложение, за да управляваш ключовете си сигурно.';

  @override
  String get webAuthEnterBunkerUri => 'Въведи Bunker URI';

  @override
  String get webAuthConnectTitle => 'Свържи се с Divine';

  @override
  String get webAuthChooseMethod =>
      'Избери предпочитания Nostr метод за удостоверяване';

  @override
  String get webAuthBrowserExtension => 'Разширение за браузър';

  @override
  String get webAuthRecommended => 'ПРЕПОРЪЧВА СЕ';

  @override
  String get webAuthNsecBunker => 'Nsec бункер';

  @override
  String get webAuthConnectRemoteSigner => 'Свържи отдалечен подписващ';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Поставяне от клипборда';

  @override
  String get webAuthConnectToBunker => 'Свържи се с Bunker';

  @override
  String get webAuthNewToNostr => 'Нов си в Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Инсталирай браузър разширение като Alby или nos2x за най-лесното изживяване, или използвай nsec bunker за сигурно отдалечено подписване.';

  @override
  String get soundsTitle => 'Звуци';

  @override
  String get soundsSearchHint => 'Звуци за търсене...';

  @override
  String get soundsSearchResults => 'Резултати от търсенето';

  @override
  String get soundsNoSoundsFound => 'Няма намерени звуци';

  @override
  String get soundsNoSoundsFoundDescription => 'Пробвай с друго търсене';

  @override
  String get soundsSavedToLibrary => 'Запазен в Звуци';

  @override
  String get soundsAlreadySavedToLibrary => 'Вече е в Звуци';

  @override
  String get soundsSavedLibraryTitle => 'Моите звуци';

  @override
  String get soundsSavedEmptyTitle => 'Все още няма запазени звуци';

  @override
  String get soundsSavedEmptyDescription =>
      'Натисни Използвай звук във видео, за да го запазиш тук.';

  @override
  String get soundsRemoveSavedSound => 'Премахни звука';

  @override
  String get savedSoundSaveAction => 'Запази';

  @override
  String get savedSoundPausePreviewAction => 'Пауза на визуализацията';

  @override
  String get savedSoundResumePreviewAction => 'Продължи визуализацията';

  @override
  String get savedSoundDetailsSheetTitle => 'Детайли за звука';

  @override
  String get savedSoundRemoveConfirmTitle => 'Да премахнем ли този звук?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Изчезва от библиотеката ти, но можеш да го запазиш отново от всяко видео, което го използва.';

  @override
  String get soundsRemovedFromLibrary => 'Премахнат от Звуци';

  @override
  String get soundsSaveFailed => 'Този звук не можа да се запази. Опитай пак.';

  @override
  String get soundsRemoveFailed =>
      'Този звук не можа да се премахне. Опитай пак.';

  @override
  String get soundSyncStatusSyncing => 'Синхронизиране на звуците ви…';

  @override
  String get soundSyncStatusSynced => 'Звуците са актуални';

  @override
  String get soundSyncStatusFailed =>
      'Звуците ви не бяха синхронизирани. Ще опитаме пак.';

  @override
  String get soundSyncStatusLocked =>
      'Синхронизираната ви библиотека не може да се отключи на това устройство.';

  @override
  String get profileTitle => 'Профил';

  @override
  String get profileMoreOptions => 'Още опции';

  @override
  String profileBlockedUser(String name) {
    return 'Блокиран $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Отблокиран $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Вече не следваш $name';
  }

  @override
  String get profileFeedError =>
      'Сървърът е недостъпен. Провери връзката си и опитай отново.';

  @override
  String get profileFeedLoadMoreError =>
      'Още видеа не можаха да се заредят. Дръпни надолу за обновяване.';

  @override
  String get notificationsTabAll => 'Всички';

  @override
  String get notificationsTabLikes => 'Харесвания';

  @override
  String get notificationsTabComments => 'Коментари';

  @override
  String get notificationsTabFollows => 'Следва';

  @override
  String get notificationsTabReposts => 'Репостове';

  @override
  String get notificationsFailedToLoad => 'Не успяхме да заредим известията';

  @override
  String get notificationsRetry => 'Опитай пак';

  @override
  String get notificationsRefreshError =>
      'Неуспешно обновяване — показва се наличното';

  @override
  String get notificationsUnreadPrefix => 'Непрочетено известие';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count непрочетени известия',
      one: '1 непрочетено известие',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Виж профила на $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Преглед на профили';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Миниатюра на видео за $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Миниатюра на видео';

  @override
  String get notificationsInviteSingular =>
      'Имаш 1 покана за споделяне с приятел!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Имаш $count покани за споделяне с приятели!';
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
  String get notificationsVideoUnavailable => 'Видеото е недостъпно';

  @override
  String get feedFailedToLoadVideos => 'Не успяхме да заредим видеата';

  @override
  String get feedRetry => 'Опитай пак';

  @override
  String get feedNoFollowedUsers =>
      'Още не следваш никого.\nПоследвай някого, за да виждаш видеата му тук.';

  @override
  String get feedModeForYou => 'За теб';

  @override
  String get feedModeNew => 'Ново';

  @override
  String get feedModeFollowing => 'Следвани';

  @override
  String get feedModeClassics => 'Класики';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Режим на емисията: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Автор на видеото: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Аватар на автора';

  @override
  String get feedForYouEmpty =>
      'Твоят фийд „За теб“ е празен.\nРазгледай видеа и последвай творци, за да го оформиш.';

  @override
  String get feedFollowingEmpty =>
      'Още няма видеа от хората, които следваш.\nНамери творци, които ти допадат, и ги последвай.';

  @override
  String get feedLatestEmpty => 'Още няма нови видеа.\nПровери пак скоро.';

  @override
  String get feedClassicEmpty => 'Още няма класики.\nПровери пак скоро.';

  @override
  String get feedExploreVideos => 'Разгледай видеа';

  @override
  String get feedLoadingMore => 'Зареждане на още видеа…';

  @override
  String get feedRefreshed => 'Емисията е опреснена';

  @override
  String get uploadUploadingVideo => 'Качва се видео';

  @override
  String get postPublishConfirmationTitle => 'Публикувано в профила ти';

  @override
  String get postPublishConfirmationView => 'Виж';

  @override
  String get postPublishConfirmationShare => 'Сподели';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Миниатюра на видеото, което току-що публикува';

  @override
  String get userSearchNoResults => 'Няма намерени потребители';

  @override
  String get userPickerFilterByNameHint => 'Филтриране по име...';

  @override
  String get userPickerSearchByNameHint => 'Търсене по име...';

  @override
  String get userPickerClearSearchSemantics => 'Изчистване на търсенето';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name вече е добавен';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Избери $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Премахни $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Твоите хора са някъде там';

  @override
  String get userPickerEmptyFollowListBody =>
      'Последвай хора, с които си на една вълна. Когато те последват обратно, ще сте готови за колаборации.';

  @override
  String get userPickerGoBack => 'Върни се назад';

  @override
  String get userPickerTypeNameToSearch => 'Въведи име за търсене';

  @override
  String get userPickerUnavailable =>
      'Търсенето на потребители не е налично. Опитай пак по-късно.';

  @override
  String get userPickerSearchFailedTryAgain => 'Търсенето не мина. Опитай пак.';

  @override
  String get forgotPasswordTitle => 'Нулиране на парола';

  @override
  String get forgotPasswordDescription =>
      'Въведи имейл адреса си и ще ти изпратим линк за възстановяване на паролата.';

  @override
  String get forgotPasswordEmailLabel => 'Имейл адрес';

  @override
  String get forgotPasswordCancel => 'Отказ';

  @override
  String get forgotPasswordSendLink => 'Връзка за нулиране на имейл';

  @override
  String get ageVerificationContentWarning => 'Предупреждение за съдържание';

  @override
  String get ageVerificationTitle => 'Проверка на възрастта';

  @override
  String get ageVerificationAdultDescription =>
      'Това съдържание е маркирано като потенциално съдържание за възрастни. Трябва да си на 18 или повече, за да го видиш.';

  @override
  String get ageVerificationCreationDescription =>
      'За да използваш камерата и да създаваш съдържание, трябва да си на 16 или повече.';

  @override
  String get ageVerificationAdultQuestion => 'На 18 или повече ли си?';

  @override
  String get ageVerificationCreationQuestion => 'На 16 или повече ли си?';

  @override
  String get ageVerificationNo => 'Не';

  @override
  String get ageVerificationYes => 'Да';

  @override
  String get navHome => 'Начало';

  @override
  String get navExplore => 'Разгледай';

  @override
  String get navInbox => 'Входяща кутия';

  @override
  String get navProfile => 'Профил';

  @override
  String get navMyProfile => 'Моят профил';

  @override
  String get navNotifications => 'Известия';

  @override
  String get navOpenCamera => 'Отвори камерата';

  @override
  String get navExploreClassics => 'Класика';

  @override
  String get navExploreNewVideos => 'Нови видеа';

  @override
  String get navExploreTrending => 'Тенденция';

  @override
  String get navExploreForYou => 'За теб';

  @override
  String get navExploreLists => 'Списъци';

  @override
  String get routeErrorTitle => 'Грешка';

  @override
  String get routeInvalidHashtag => 'Невалиден хаштаг';

  @override
  String get routeInvalidConversationId =>
      'Невалиден идентификатор на разговор';

  @override
  String get routeInvalidRequestId => 'Невалиден ID на заявката';

  @override
  String get routeInvalidListId => 'Невалиден идентификатор на списък';

  @override
  String get routeInvalidUserId => 'Невалиден потребителски идентификатор';

  @override
  String get routeInvalidVideoId => 'Невалиден идентификатор на видео';

  @override
  String get routeInvalidSoundId => 'Невалиден идентификатор на звука';

  @override
  String get routeInvalidCategory => 'Невалидна категория';

  @override
  String get routeNoVideosToDisplay => 'Няма видеа за показване';

  @override
  String get routeGoHome => 'Към началото';

  @override
  String get routeInvalidProfileId => 'Невалиден ID на потребителския профил';

  @override
  String get routeUnknownPath => 'Тази страница не е налична в приложението.';

  @override
  String get routeDefaultListName => 'Списък';

  @override
  String get supportTitle => 'Център за поддръжка';

  @override
  String get supportContactSupport => 'Свържи се с поддръжката';

  @override
  String get supportContactSupportSubtitle =>
      'Започни разговор или прегледай минали съобщения';

  @override
  String get supportReportBug => 'Докладване за грешка';

  @override
  String get supportReportBugSubtitle => 'Технически проблеми с приложението';

  @override
  String get supportRequestFeature => 'Заявка за функция';

  @override
  String get supportRequestFeatureSubtitle =>
      'Предложи подобрение или нова функция';

  @override
  String get supportSaveLogs => 'Запази логове';

  @override
  String get supportSaveLogsSubtitle =>
      'Експортирай логовете във файл за ръчно изпращане';

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
  String get supportFaq => 'ЧЗВ';

  @override
  String get supportFaqSubtitle => 'Често задавани въпроси и отговори';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Помагаме на родители и тийнейджъри да изградят здравословни навици онлайн';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Как управляваме профилите според възрастта';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => 'Научи за проверката и автентичността';

  @override
  String get supportLoginRequired => 'Влез, за да се свържеш с поддръжката';

  @override
  String get supportExportingLogs => 'Логовете се експортират...';

  @override
  String get supportExportLogsFailed => 'Не успяхме да експортираме логовете';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Логовете са запазени в $path';
  }

  @override
  String get supportRevealLogsAction => 'Покажи в папка';

  @override
  String get supportChatNotAvailable => 'Чатът за поддръжка не е наличен';

  @override
  String get supportCouldNotOpenMessages =>
      'Не можах да отворя съобщения за поддръжка';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Не може да се отвори $pageName';
  }

  @override
  String get reportWhyReporting => 'Защо подаваш сигнал за това съдържание?';

  @override
  String get reportPolicyNotice =>
      'Divine ще преглежда сигналите за съдържание до 24 часа и при нужда ще премахва съдържание или ще блокира акаунта, който го е публикувал.';

  @override
  String get reportBlockUser => 'Блокирай този потребител';

  @override
  String get reportCancel => 'Отказ';

  @override
  String get reportSubmit => 'Докладвай';

  @override
  String get reportSelectReason =>
      'Избери причина за докладване на това съдържание';

  @override
  String get reportOtherRequiresDetails =>
      'Моля, опиши проблема, когато избираш „Друго“';

  @override
  String get reportDetailsRequired => 'Моля, опиши проблема';

  @override
  String get reportDetailsTextOnly =>
      'Само текст — тук не могат да се прикачват снимки или GIF файлове.';

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
  String get reportReasonSpam => 'Спам или нежелано съдържание';

  @override
  String get reportReasonSpamSubtitle => 'Нежелано или повтарящо се съдържание';

  @override
  String get reportReasonHarassment => 'Тормоз, малтретиране или заплахи';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Вредни и нежелани отговори или споменавания';

  @override
  String get reportReasonViolence => 'Насилствено или екстремистко съдържание';

  @override
  String get reportReasonViolenceSubtitle =>
      'Насилствено, екстремистко или вредно съдържание';

  @override
  String get reportReasonSexualContent =>
      'Сексуално съдържание или съдържание за възрастни';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Голота, порнография или откровено съдържание';

  @override
  String get reportReasonCopyright => 'Нарушаване на авторски права';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Неоторизирано използване на интелектуална собственост';

  @override
  String get reportReasonFalseInfo => 'Невярна информация';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Подвеждащи или неверни твърдения';

  @override
  String get reportReasonChildSafety => 'Нарушение на безопасността на децата';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Общи притеснения за безопасността на непълнолетни';

  @override
  String get reportReasonCsam => 'Сексуално насилие над деца';

  @override
  String get reportReasonCsamSubtitle =>
      'Съдържание, изобразяващо сексуално насилие над непълнолетни';

  @override
  String get reportReasonUnderageUser => 'Потребителят изглежда под 16 г.';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Собственикът на акаунта изглежда непълнолетен';

  @override
  String get reportReasonAiGenerated => 'AI-генерирано съдържание';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Съдържание, за което се подозира, че е генерирано от ИИ';

  @override
  String get reportReasonOther => 'Друго нарушение на правилата';

  @override
  String get reportReasonOtherSubtitle =>
      'Нарушения, които не са изброени по-горе';

  @override
  String get reportFailed => 'Неуспешно докладване на съдържание. Опитай пак.';

  @override
  String get reportNotSent =>
      'Не успяхме да изпратим сигнала ти. Провери връзката си и опитай пак.';

  @override
  String get reportReceivedTitle => 'Докладът е получен';

  @override
  String get reportReceivedThankYou =>
      'Благодарим, че помагаш да запазим Divine безопасен.';

  @override
  String get reportReceivedReviewNotice =>
      'Екипът ни ще прегледа сигнала ти и ще предприеме нужните действия. Може да получаваш новини чрез директно съобщение.';

  @override
  String get reportModerationDmDelayed =>
      'Точно сега не успяхме да се свържем директно с екипа по модерация, но докладът ти е получен и ще бъде прегледан.';

  @override
  String get reportContactModeration => 'Пиши на екипа по модерация';

  @override
  String get reportLearnMoreAt => 'Научи повече на';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Затвори';

  @override
  String get listAddToList => 'Добави към списъка';

  @override
  String listVideoCount(int count) {
    return '$count видеа';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count души',
      one: '1 човек',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'От ';

  @override
  String get listNewList => 'Нов списък';

  @override
  String get listDone => 'Готово';

  @override
  String get listErrorLoading => 'Грешка при зареждане на списъците';

  @override
  String listRemovedFrom(String name) {
    return 'Премахнато от $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Добавено към $name';
  }

  @override
  String get listCreateNewList => 'Създаване на нов списък';

  @override
  String get listNewPeopleList => 'Нов списък с хора';

  @override
  String get listCollaboratorsNone => 'Няма';

  @override
  String get listAddCollaboratorTitle => 'Добави сътрудник';

  @override
  String get listCollaboratorSearchHint => 'Търсене Divine...';

  @override
  String get listNameLabel => 'Име на списък';

  @override
  String get listDescriptionLabel => 'Описание (по избор)';

  @override
  String get listPublicList => 'Публичен списък';

  @override
  String get listPublicListSubtitle =>
      'Други могат да следват и да видят този списък';

  @override
  String get listPrivateListSubtitle =>
      'Видеата остават частни. Името, описанието, таговете и корицата остават видими.';

  @override
  String get listVisibilityPublic => 'Публичен';

  @override
  String get listVisibilityPrivate => 'Частен';

  @override
  String get profileListsEmpty =>
      'Още няма списъци. Направи един за луповете, които искаш да държиш заедно.';

  @override
  String get listEditTitle => 'Редактирай списъка';

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
  String get listShareAction => 'Сподели списъка';

  @override
  String get listShareFailed =>
      'Списъкът не можа да бъде споделен. Опитай пак.';

  @override
  String get listSave => 'Запази';

  @override
  String get listContinue => 'Продължи';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Списъкът не можа да бъде обновен. Опитай пак.';

  @override
  String get listMakePrivateTitle => 'Да направим ли този списък частен?';

  @override
  String get listMakePrivateWarning =>
      'Видеата се криптират, така че само ти да ги виждаш. Името, описанието, таговете и корицата остават видими, а вече споделени копия може да останат.';

  @override
  String get listMakePublicTitle => 'Да направим ли този списък публичен?';

  @override
  String get listMakePublicWarning =>
      'Всеки с линка може да види този списък и видеата в него.';

  @override
  String listShareText(String name, String url) {
    return 'Виж $name в Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name в Divine';
  }

  @override
  String get listCancel => 'Отказ';

  @override
  String get listCreate => 'Създай';

  @override
  String get listCreateFailed => 'Неуспешно създаване на списък';

  @override
  String get keyManagementTitle => 'Nostr Ключове';

  @override
  String get keyManagementWhatAreKeys => 'Какво представляват ключовете Nostr?';

  @override
  String get keyManagementExplanation =>
      'Nostr самоличността ти е двойка криптографски ключове:\n\n• Публичният ти ключ (npub) е като потребителско име - споделяй го спокойно\n• Частният ти ключ (nsec) е като парола - пази го в тайна!\n\nТвоят nsec ти дава достъп до акаунта във всяко Nostr приложение.';

  @override
  String get keyManagementImportTitle => 'Импортиране на съществуващ ключ';

  @override
  String get keyManagementImportSubtitle =>
      'Вече имаш Nostr акаунт? Постави частния си ключ (nsec), за да го използваш тук.';

  @override
  String get keyManagementImportButton => 'Ключ за импортиране';

  @override
  String get keyManagementImportWarning => 'Това ще замени текущия ти ключ!';

  @override
  String get keyManagementBackupTitle => 'Архивирай ключа си';

  @override
  String get keyManagementBackupSubtitle =>
      'Запази частния си ключ (nsec), за да използваш акаунта си в други Nostr приложения.';

  @override
  String get keyManagementCopyNsec => 'Копирай личния ми ключ (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Никога не споделяй своя nsec с никого!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Ключът ти се съхранява в услугата за вход на Divine, а не на това устройство. Потвърди паролата си и ще го изтеглим.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Ключът ти се съхранява от услугата за вход на Divine. Въведи паролата на профила си и ще го изтеглим.';

  @override
  String get keyManagementKeycastCopyKey => 'Копирай ключа';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Устройството ти блокира копирането, така че ключът ти не стигна до клипборда.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Паролата не съвпада. Опитай отново.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Твърде много опити. Затвори това и започни отначало.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Твърде много заявки за ключа. Изчакай няколко минути и опитай пак.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Сесията ти изтече. Влез отново, за да копираш ключа си.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Потвърди имейл адреса си, преди да копираш ключа.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine управлява ключовете на този профил, така че те не могат да се копират тук.';

  @override
  String get keyManagementKeycastNoKey => 'За този профил няма записан ключ.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Услугата за вход е недостъпна. Опитай пак.';

  @override
  String get keyManagementRestrictedTitle =>
      'Ключовете ти се управляват от Divine';

  @override
  String get keyManagementRestrictedBody =>
      'За да е сигурен профилът ти, резервно копие на ключа и внасяне на друг ключ не са налични тук.';

  @override
  String get keyManagementPasteKey => 'Постави частния си ключ';

  @override
  String get keyManagementInvalidFormat =>
      'Невалиден формат на ключа. Трябва да започва с \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Импортиране на този ключ?';

  @override
  String get keyManagementConfirmImportBody =>
      'Това ще замени текущата ти самоличност с импортираната.\n\nТекущият ти ключ ще бъде загубен, освен ако първо не си го архивирал.';

  @override
  String get keyManagementImportConfirm => 'Импортиране';

  @override
  String get keyManagementImportSuccess => 'Ключът е импортиран успешно!';

  @override
  String get keyManagementImportFailed =>
      'Неуспешно импортиране на ключ. Опитай пак.';

  @override
  String get keyManagementExportSuccess =>
      'Частният ключ е копиран в клипборда!\n\nСъхранявайте го на сигурно място.';

  @override
  String get keyManagementExportFailed =>
      'Неуспешно експортиране на ключ. Опитай пак.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Твоят публичен ключ (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Копирай публичния ключ';

  @override
  String get keyManagementPublicKeyCopied => 'Публичният ключ е копиран';

  @override
  String get saveOriginalSavedToCameraRoll => 'Запазено в галерията';

  @override
  String get saveOriginalShare => 'Сподели';

  @override
  String get saveOriginalDone => 'Готово';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Необходим е достъп до снимки';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'За да запазваш видеа, дай достъп до снимките в настройките.';

  @override
  String get saveOriginalOpenSettings => 'Отвори Настройки';

  @override
  String get saveOriginalNotNow => 'Не сега';

  @override
  String get saveOriginalDownloadFailed => 'Неуспешно изтегляне';

  @override
  String get saveOriginalDismiss => 'Отхвърляне';

  @override
  String get saveOriginalDownloadingVideo => 'Изтегляне на видео';

  @override
  String get saveOriginalSavingToCameraRoll => 'Запазване в галерията';

  @override
  String get saveOriginalFetchingVideo => 'Видеото се извлича от мрежата...';

  @override
  String get saveOriginalSavingVideo =>
      'Оригиналното видео се запазва в галерията...';

  @override
  String get soundTitle => 'Звук';

  @override
  String get soundOriginalSound => 'Оригинален звук';

  @override
  String get soundVideosUsingThisSound => 'Видеоклипове, използващи този звук';

  @override
  String get soundSourceVideo => 'Източник на видео';

  @override
  String get soundNoVideosYet => 'Още няма видеа';

  @override
  String get soundBeFirstToUse => 'Бъдете първите, които използват този звук!';

  @override
  String get soundFailedToLoadVideos => 'Не успяхме да заредим видеата';

  @override
  String get soundRetry => 'Опитай пак';

  @override
  String get soundVideosUnavailable => 'Видеоклиповете са недостъпни';

  @override
  String get soundCouldNotLoadDetails =>
      'Подробностите за видеото не се заредиха';

  @override
  String get soundPreview => 'Преглед';

  @override
  String get soundStop => 'Спрете';

  @override
  String get soundUseSound => 'Използвай звук';

  @override
  String get soundUntitled => 'Звук без заглавие';

  @override
  String get soundStopPreview => 'Спри прегледа';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Прегледай $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Виж подробности за $title';
  }

  @override
  String get soundNoVideoCount => 'Още няма видеа';

  @override
  String get soundOneVideo => '1 видео';

  @override
  String soundVideoCount(int count) {
    return '$count видеа';
  }

  @override
  String get soundUnableToPreview =>
      'Не може да се визуализира звук - няма наличен звук';

  @override
  String get soundPreviewFailed =>
      'Неуспешно пускане на визуализация. Опитай пак.';

  @override
  String get soundViewSource => 'Виж източника';

  @override
  String get soundCloseTooltip => 'Затвори';

  @override
  String get exploreNotExploreRoute => 'Не е маршрут за изследване';

  @override
  String get legalTitle => 'Законни';

  @override
  String get legalTermsOfService => 'Условия за ползване';

  @override
  String get legalTermsOfServiceSubtitle => 'Правила и условия за ползване';

  @override
  String get legalPrivacyPolicy => 'Политика за поверителност';

  @override
  String get legalPrivacyPolicySubtitle => 'Как работим с данните ти';

  @override
  String get legalSafetyStandards => 'Стандарти за безопасност';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Правила на общността и безопасност';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Правила за авторско право и сваляне';

  @override
  String get legalOpenSourceLicenses => 'Лицензи за отворен код';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Приписвания на пакети на трети страни';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Не може да се отвори $pageName';
  }

  @override
  String get categoryAction => 'Действие';

  @override
  String get categoryAdventure => 'Приключение';

  @override
  String get categoryAnimals => 'Животни';

  @override
  String get categoryAnimation => 'Анимация';

  @override
  String get categoryArchitecture => 'Архитектура';

  @override
  String get categoryArt => 'Чл';

  @override
  String get categoryAutomotive => 'Автомобилен';

  @override
  String get categoryAwardShow => 'Наградно шоу';

  @override
  String get categoryAwards => 'Награди';

  @override
  String get categoryBaseball => 'Бейзбол';

  @override
  String get categoryBasketball => 'Баскетбол';

  @override
  String get categoryBeauty => 'Красота';

  @override
  String get categoryBeverage => 'Напитка';

  @override
  String get categoryCars => 'Автомобили';

  @override
  String get categoryCelebration => 'Тържество';

  @override
  String get categoryCelebrities => 'Знаменитости';

  @override
  String get categoryCelebrity => 'Знаменитост';

  @override
  String get categoryCityscape => 'Градски пейзаж';

  @override
  String get categoryComedy => 'Комедия';

  @override
  String get categoryConcert => 'Концерт';

  @override
  String get categoryCooking => 'Готвене';

  @override
  String get categoryCostume => 'Костюм';

  @override
  String get categoryCrafts => 'Занаяти';

  @override
  String get categoryCrime => 'Престъпление';

  @override
  String get categoryCulture => 'Култура';

  @override
  String get categoryDance => 'Танцувай';

  @override
  String get categoryDiy => 'Направи си сам';

  @override
  String get categoryDrama => 'Драма';

  @override
  String get categoryEducation => 'Образование';

  @override
  String get categoryEmotional => 'Емоционален';

  @override
  String get categoryEmotions => 'Емоции';

  @override
  String get categoryEntertainment => 'Развлечение';

  @override
  String get categoryEvent => 'Събитие';

  @override
  String get categoryFamily => 'Семейство';

  @override
  String get categoryFans => 'Фенове';

  @override
  String get categoryFantasy => 'Фантазия';

  @override
  String get categoryFashion => 'Стил';

  @override
  String get categoryFestival => 'Фестивал';

  @override
  String get categoryFilm => 'Филм';

  @override
  String get categoryFitness => 'Фитнес';

  @override
  String get categoryFood => 'Храна';

  @override
  String get categoryFootball => 'Футбол';

  @override
  String get categoryFurniture => 'Мебели';

  @override
  String get categoryGaming => 'Игри';

  @override
  String get categoryGolf => 'Голф';

  @override
  String get categoryGrooming => 'Подстригване';

  @override
  String get categoryGuitar => 'Китара';

  @override
  String get categoryHalloween => 'Хелоуин';

  @override
  String get categoryHealth => 'Здраве';

  @override
  String get categoryHockey => 'Хокей';

  @override
  String get categoryHoliday => 'Празник';

  @override
  String get categoryHome => 'Начало';

  @override
  String get categoryHomeImprovement => 'Подобряване на дома';

  @override
  String get categoryHorror => 'Ужас';

  @override
  String get categoryHospital => 'Болница';

  @override
  String get categoryHumor => 'Хумор';

  @override
  String get categoryInteriorDesign => 'Интериорен дизайн';

  @override
  String get categoryInterview => 'Интервю';

  @override
  String get categoryKids => 'Деца';

  @override
  String get categoryLifestyle => 'Начин на живот';

  @override
  String get categoryMagic => 'Магия';

  @override
  String get categoryMakeup => 'Грим';

  @override
  String get categoryMedical => 'Медицински';

  @override
  String get categoryMusic => 'Музика';

  @override
  String get categoryMystery => 'Мистерия';

  @override
  String get categoryNature => 'Природата';

  @override
  String get categoryNews => 'Новини';

  @override
  String get categoryOutdoor => 'На открито';

  @override
  String get categoryParty => 'Парти';

  @override
  String get categoryPeople => 'Хора';

  @override
  String get categoryPerformance => 'Изпълнение';

  @override
  String get categoryPets => 'Домашни любимци';

  @override
  String get categoryPolitics => 'Политика';

  @override
  String get categoryPrank => 'Шега';

  @override
  String get categoryPranks => 'Шеги';

  @override
  String get categoryRealityShow => 'Риалити шоу';

  @override
  String get categoryRelationship => 'Връзка';

  @override
  String get categoryRelationships => 'Връзки';

  @override
  String get categoryRomance => 'Романтика';

  @override
  String get categorySchool => 'Училище';

  @override
  String get categoryScienceFiction => 'Научна фантастика';

  @override
  String get categorySelfie => 'Селфи';

  @override
  String get categoryShopping => 'Пазаруване';

  @override
  String get categorySkateboarding => 'Скейтборд';

  @override
  String get categorySkincare => 'Грижа за кожата';

  @override
  String get categorySoccer => 'Футбол';

  @override
  String get categorySocialGathering => 'Социално събиране';

  @override
  String get categorySocialMedia => 'Социални медии';

  @override
  String get categorySports => 'Спорт';

  @override
  String get categoryTalkShow => 'Ток шоу';

  @override
  String get categoryTech => 'Техн';

  @override
  String get categoryTechnology => 'Технология';

  @override
  String get categoryTelevision => 'Телевизия';

  @override
  String get categoryToys => 'Играчки';

  @override
  String get categoryTransportation => 'Транспорт';

  @override
  String get categoryTravel => 'Пътуване';

  @override
  String get categoryUrban => 'Градски';

  @override
  String get categoryViolence => 'Насилие';

  @override
  String get categoryVlog => 'Влог';

  @override
  String get categoryVlogging => 'Влогове';

  @override
  String get categoryWrestling => 'Борба';

  @override
  String get profileSetupUploadStaged =>
      'Качено — натисни Запази, за да приложиш';

  @override
  String inboxReportedUser(String displayName) {
    return 'Докладвано $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Блокиран $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Отблокиран $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Премахнат разговор';

  @override
  String get inboxRestorePausedTitle =>
      'Някои чатове не са възстановени докрай';

  @override
  String get conversationRestorePausedTitle =>
      'Този чат още не е възстановен докрай';

  @override
  String get inboxRestoreRetryAction => 'Опитай пак';

  @override
  String get inboxRestoringMessages => 'Възстановяваме съобщенията ти…';

  @override
  String get inboxEmptyTitle => 'Все още няма съобщения';

  @override
  String get inboxEmptySubtitle => 'Този бутон + няма да ухапе.';

  @override
  String get inboxLoadErrorTitle => 'Съобщенията не се заредиха';

  @override
  String get inboxLoadErrorSubtitle => 'Провери връзката си и опитай отново.';

  @override
  String get inboxFilterAll => 'Всички';

  @override
  String get inboxFilterUnread => 'Непрочетени';

  @override
  String get dmBlockedThreadTitle => 'Блокирахте този акаунт';

  @override
  String get dmBlockedThreadBody =>
      'Съобщенията остават тук, за да можете да ги прочетете или да направите екранна снимка. Отблокирайте, за да отговорите.';

  @override
  String get inboxFilterBlocked => 'Блокирани';

  @override
  String get inboxBlockedEmptyTitle => 'Няма блокирани чатове';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Акаунтите, които блокирате, се показват тук.';

  @override
  String get inboxBlockedNoMessages => 'Няма съобщения';

  @override
  String get inboxUnreadEmptyTitle => 'В крак си с всичко';

  @override
  String get inboxUnreadEmptySubtitle =>
      'Няма непрочетени съобщения в момента.';

  @override
  String get inboxSearchHint => 'Търсене в съобщенията';

  @override
  String get inboxSupportRowTitle => 'Модерация на Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Бъгове, модерация, проблеми с акаунта — слушаме.';

  @override
  String get inboxSearchEmptyTitle => 'Няма съвпадения';

  @override
  String get inboxSearchEmptySubtitle => 'Опитай с друго име или дума.';

  @override
  String get inboxActionMute => 'Заглушаване на разговора';

  @override
  String inboxActionReport(String displayName) {
    return 'Докладвай $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Блокирай $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Отблокирай $displayName';
  }

  @override
  String get inboxActionRemove => 'Премахни разговора';

  @override
  String get inboxRemoveConfirmTitle => 'Да премахнем разговора?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Това премахва разговора ти с $displayName от входящата ти кутия. Ако ти пише отново, започва нов разговор.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Това премахва груповия разговор от входящата ти кутия. Ако някой пише отново в групата, започва нов разговор.';

  @override
  String get inboxRemoveConfirmConfirm => 'Премахни';

  @override
  String get inboxConversationMuted => 'Разговорът е заглушен';

  @override
  String get inboxConversationUnmuted => 'Разговорът е включен';

  @override
  String get inboxCollabInviteCardTitle => 'Покана за сътрудник';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Видео без заглавие';

  @override
  String get clickableTextViewVideoLink => 'Виж видеото';

  @override
  String get messageExternalLinkDialogTitle => 'Да се отвори ли външен линк?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Този линк води към външен сайт и може да не е безопасен:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Отвори';

  @override
  String get inboxCollabInviteCoPostButton => 'Съвместна публикация';

  @override
  String get inboxCollabInviteNotMineButton => 'Не е мое';

  @override
  String get inboxCollabInvitePreviewTitle => 'Покана за съвместна публикация';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Покана за съвместна публикация от $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Съвместното публикуване добавя това видео към хронологията ти като сътрудничество.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Прието';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Игнорирани';

  @override
  String get inboxCollabInviteAcceptError =>
      'Не успяхме да приемем. Опитай пак.';

  @override
  String get inboxCollabInviteSentStatus => 'Поканата е изпратена';

  @override
  String get inboxConversationCollabInvitePreview => 'Покана за сътрудник';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Поканени сте да си сътрудничите по $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Поканени сте да си сътрудничите по видеоклип: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count покани за сътрудници не се изпратиха.',
      one: '1 покана за сътрудник не се изпрати.',
    );
    return 'Видеото е публикувано, но $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Не разбрахме с кого е този разговор. Отвори го пак от входящите.';

  @override
  String get dmSendBlockedMessage =>
      'Можеш да пишеш само на официални профили на Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Никой не чете този разговор. Вместо това пишете на Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Изтриването за всички не се получи.';

  @override
  String get dmDeleteRefusedDetails =>
      'Някои хора все още може да виждат това съобщение.';

  @override
  String get dmRetiredThreadClosedTitle => 'Този разговор е затворен.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Това известие от Divine Moderation не може да бъде премахнато.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Преместихме Divine Moderation в нов профил. Този вече не се чете от никого.';

  @override
  String get dmRetiredThreadOpenSupport => 'Пишете на Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Съобщението не мина';

  @override
  String get dmResendFailedMessage => 'Още не мина';

  @override
  String get dmSendFailedSubtitle => 'Изпрати го отново сега или спри опитите.';

  @override
  String get dmSendFailedRetry => 'Опитай пак';

  @override
  String get dmSendPartialMessage =>
      'Изпратено, но не се синхронизира с другите ти устройства';

  @override
  String get dmConversationLoadError => 'Съобщенията не се заредиха';

  @override
  String get dmMessageInputHint => 'Кажи нещо…';

  @override
  String get dmMessageBubbleSentHint => 'Изпратено съобщение';

  @override
  String get dmMessageBubbleReceivedHint => 'Получено съобщение';

  @override
  String get dmMessageBubbleLongPressHint => 'Действия за съобщението';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Изпратете отново или изтрийте това съобщение';

  @override
  String get dmMessageActionCopyText => 'Копирай текста';

  @override
  String get dmMessageActionCopyVideoUrl => 'Копирай URL на видеото';

  @override
  String get dmMessageActionDeleteForEveryone => 'Изтрий за всички';

  @override
  String get dmMessageActionReport => 'Докладвай';

  @override
  String get dmMessageActionRetrySend => 'Изпрати отново';

  @override
  String get dmMessageActionCancelSend => 'Спри опитите';

  @override
  String get dmReactionAddCustomA11yLabel => 'Добави собствена емоджи реакция';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Съобщение до $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Отговорете на себе си…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Отговор на този рийл';

  @override
  String get dmReelReplyViewChat => 'Виж чата';

  @override
  String get dmReelReplySentAnnouncement => 'Отговорът е изпратен';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Реагирахте с $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Изпращането е неуспешно';

  @override
  String get dmReelReplyUnverified => 'Изпращането не е потвърдено';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Твоята реакция: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name реагира с $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Изпращане на реакция: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Реакцията не мина, докосни два пъти за нов опит';

  @override
  String get dmReactionChipRetryAnnouncement => 'Нов опит за реакцията';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Завършете премахването на предишната си реакция, преди да добавите друга.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Реакции';

  @override
  String get dmReactionsViewA11yLabel => 'Вижте кой реагира';

  @override
  String get dmReactionRemoveAction => 'Премахни';

  @override
  String get dmReactionRetryAction => 'Опитай отново';

  @override
  String get dmFormatBold => 'Получер';

  @override
  String get dmFormatItalic => 'Курсив';

  @override
  String get dmFormatStrikethrough => 'Зачеркнат';

  @override
  String get dmFormatCode => 'Код';

  @override
  String get dmStatusFailed => 'Изпращането не успя';

  @override
  String get inboxConversationActionsSheetLabel => 'Действия за разговора';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Разговор с $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Непрочетен, разговор с $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count души',
      one: '$count човек',
    );
    return '$name и още $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Покажи действията за разговора';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Заглавие: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Видео $current/$total';
  }

  @override
  String get exploreSearchHint => 'Търсене...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count видеа';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Неуспешно актуализиране на абонамента. Опитай пак.';

  @override
  String get discoverListsTitle => 'Открий списъци';

  @override
  String get discoverListsFailedToLoad => 'Зареждането на списъците не успя';

  @override
  String get discoverListsLoading => 'Откриваме публични списъци...';

  @override
  String get discoverListsRelayTimeout =>
      'Релето не върна списъци навреме. Опитай пак.';

  @override
  String get discoverListsServiceUnavailable => 'Услугата не е налична.';

  @override
  String get discoverListsEmptyTitle => 'Не са намерени публични списъци';

  @override
  String get discoverListsEmptySubtitle => 'Върни се по-късно за нови списъци';

  @override
  String get discoverListsByAuthorPrefix => 'от';

  @override
  String get curatedListEmptyTitle => 'Няма видеа в този списък';

  @override
  String get curatedListEmptySubtitle => 'Добави няколко видеа, за да започнеш';

  @override
  String get curatedListLoadingVideos => 'Видеата се зареждат...';

  @override
  String get curatedListFailedToLoad => 'Зареждането на списъка не успя';

  @override
  String get curatedListVideoNotAvailable => 'Видеото не е налично';

  @override
  String get curatedListActionsTooltip => 'Действия за списъка';

  @override
  String get curatedListDeleteConfirmTitle => 'Да изтрием списъка?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Това премахва списъка от релетата. Видеата в списъка няма да бъдат изтрити.';

  @override
  String get curatedListDeletedSnack => 'Списъкът е изтрит';

  @override
  String get curatedListDeleteFailed => 'Списъкът не можа да бъде изтрит';

  @override
  String get peopleListsActionsTooltip => 'Действия за списъка';

  @override
  String get listDeleteAction => 'Изтрий списъка';

  @override
  String get peopleListsDeleteConfirmTitle => 'Да изтрием списъка?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Това премахва списъка за всички. Хората в него няма да бъдат отписани.';

  @override
  String get peopleListsDeleteFailed => 'Списъкът не можа да бъде изтрит';

  @override
  String get commonRetry => 'Опитай пак';

  @override
  String get commonSomethingWentWrong => 'Нещо се обърка';

  @override
  String get commonDelete => 'Изтрий';

  @override
  String get commonCancel => 'Отказ';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonClose => 'Затвори';

  @override
  String get commonNotNow => 'Не сега';

  @override
  String get commonLoading => 'Зарежда се';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Корицата не можа да се обнови. Опитай пак.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Корицата е обновена';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Публикуване без проверка за автентичност?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Не успяхме да добавим удостоверения за съдържанието, затова това видео няма да бъде потвърдено като създадено от човек. Генерирайте отново, за да опитате пак, или го публикувайте както е.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Удостоверенията за съдържание изискват интернет връзка.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Услугата за удостоверяване на съдържание не отговори. Не е заради твоята връзка.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Генерирай отново';

  @override
  String get videoMetadataC2paMissingSkip => 'Пропусни';

  @override
  String get videoMetadataGenerationFailed => 'Генерирането е неуспешно';

  @override
  String get videoMetadataTags => 'Етикети';

  @override
  String get videoMetadataExpiration => 'Изтичане';

  @override
  String get videoMetadataExpirationNotExpire => 'Не изтича';

  @override
  String get videoMetadataExpirationOneDay => '1 ден';

  @override
  String get videoMetadataExpirationOneWeek => '1 седмица';

  @override
  String get videoMetadataExpirationOneMonth => '1 месец';

  @override
  String get videoMetadataExpirationOneYear => '1 година';

  @override
  String get videoMetadataExpirationOneDecade => '1 десетилетие';

  @override
  String get videoMetadataContentWarnings => 'Предупреждения за съдържанието';

  @override
  String get videoEditorStickers => 'Стикери';

  @override
  String get trendingTitle => 'Тенденция';

  @override
  String get libraryDeleteConfirm => 'Изтриване';

  @override
  String get libraryWebUnavailableHeadline =>
      'Библиотеката е налична в мобилното приложение';

  @override
  String get libraryWebUnavailableDescription =>
      'Черновите и клиповете се пазят на устройството ти, затова отвори Divine на телефона си, за да ги управляваш.';

  @override
  String get libraryTabDrafts => 'Чернови';

  @override
  String get libraryTabClips => 'Клипове';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Изтрийте избраните клипове';

  @override
  String get libraryCloseSemanticLabel => 'Затвори библиотеката';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Спри избора на клипове';

  @override
  String get librarySelectClipsSemanticLabel => 'Избери клипове';

  @override
  String get libraryGridSizeLabel => 'Размер на мрежата';

  @override
  String get libraryDisplayOptionsLabel => 'Сортиране и размер на мрежата';

  @override
  String get libraryMoreActionsSemanticLabel => 'Още действия в библиотеката';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count колони',
      one: '1 колона',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Избери';

  @override
  String get librarySortNewestCreation => 'Най-ново създадени';

  @override
  String get librarySortOldestCreation => 'Най-старо създадени';

  @override
  String get librarySortLongestClip => 'Най-дълъг клип';

  @override
  String get librarySortShortestClip => 'Най-кратък клип';

  @override
  String get librarySortSquareFirst => 'Първо квадратни';

  @override
  String get librarySortVerticalFirst => 'Първо вертикални';

  @override
  String get libraryDeleteClipsWarning =>
      'Това действие не може да бъде отменено. Видео файловете ще бъдат премахнати за постоянно от твоето устройство.';

  @override
  String get libraryPreparingVideo => 'Видеоклипът се подготвя...';

  @override
  String libraryCreateVideo(int count) {
    return 'Създаване на видео ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа',
      one: '1 клип',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'и',
      one: '',
    );
    return '$_temp0 запазен$_temp1 в $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount запазено, $failureCount неуспешно';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Не успяхме да запазим в $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Разрешението за $destination е отказано';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа са изтрити',
      one: '1 клип е изтрит',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Отмени';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Ще се изтрие автоматично след $daysLeft дни',
      one: 'Ще се изтрие автоматично утре',
      zero: 'Ще се изтрие автоматично днес',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Не успяхме да заредим черновите';

  @override
  String get libraryCouldNotLoadClips => 'Не успяхме да заредим клиповете';

  @override
  String get libraryOpenErrorDescription =>
      'Нещо се обърка при отварянето на библиотеката ти. Пробвай пак.';

  @override
  String get libraryNoDraftsYetTitle => 'Още няма чернови';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Видеата, които запазиш като чернова, ще се появят тук';

  @override
  String get libraryNoClipsYetTitle => 'Още няма клипове';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Записаните ти видео клипове ще се появят тук';

  @override
  String get libraryDraftDeletedSnackbar => 'Черновата е изтрита';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Не успяхме да изтрием черновата';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Черновата е дублирана';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Не успяхме да дублираме черновата';

  @override
  String get libraryDraftInProgressBadge => 'В процес';

  @override
  String get libraryDraftActionPost => 'Публикувай';

  @override
  String get libraryDraftActionEdit => 'Редактиране';

  @override
  String get libraryDraftActionDuplicate => 'Дублирай';

  @override
  String get libraryDraftActionDelete => 'Изтрий черновата';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (копие $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Изтрий чернова';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Сигурен ли си, че искаш да изтриеш „$title“?';
  }

  @override
  String get libraryDeleteClipTitle => 'Изтрий клип';

  @override
  String get libraryDeleteClipMessage =>
      'Сигурен ли си, че искаш да изтриеш този клип?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds сек';
  }

  @override
  String get libraryRecordVideo => 'Запишете видео';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Видео клип, $duration секунди';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Архивирано. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Стоп-моушън клип, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Избран, номер $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Избран';

  @override
  String get videoClipSemanticValueNotSelected => 'Не е избран';

  @override
  String get videoClipSemanticHintDisabled => 'Деактивиран';

  @override
  String get videoClipSemanticHintSelect =>
      'Докоснете за избор, задръжте за преглед';

  @override
  String get videoClipSemanticHintDeselect =>
      'Докоснете за премахване на избора, задръжте за преглед';

  @override
  String get routerInvalidCreator => 'Невалиден създател';

  @override
  String get routerInvalidHashtagRoute => 'Невалиден маршрут на хаштаг';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Не успяхме да заредим видеата';

  @override
  String get categoryGalleryNoVideosInCategory => 'Няма видеа в тази категория';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Опции за сортиране на категорията';

  @override
  String get categoryGallerySortHot => 'Горещо';

  @override
  String get categoryGallerySortNew => 'Ново';

  @override
  String get categoryGallerySortClassic => 'Класика';

  @override
  String get categoryGallerySortForYou => 'За теб';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Не успяхме да заредим категориите';

  @override
  String get categoriesNoCategoriesAvailable => 'Няма налични категории';

  @override
  String get notificationsEmptyTitle => 'Все още няма активност';

  @override
  String get notificationsEmptySubtitle =>
      'Когато хората взаимодействат със съдържанието ти, ще го видиш тук';

  @override
  String get appsPermissionsTitle => 'Разрешения за интеграции';

  @override
  String get appsPermissionsRevoke => 'Отнеми';

  @override
  String get appsPermissionsEmptyTitle =>
      'Няма запазени разрешения за интеграции';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Одобрените интеграции ще се появят тук, след като запомниш дадено разрешение.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName иска одобрение от теб';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Това приложение иска достъп през проверения sandbox на Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Произход';

  @override
  String get nostrAppPermissionMethod => 'Метод';

  @override
  String get nostrAppPermissionCapability => 'Възможност';

  @override
  String get nostrAppPermissionEventKind => 'Вид събитие';

  @override
  String get nostrAppPermissionAllow => 'Позволи';

  @override
  String get appsDetailDefaultTitle => 'Свързано приложение';

  @override
  String get appsDetailNotFoundTitle => 'Интеграцията не е намерена';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Тази одобрена интеграция вече не е налична в Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Как работи';

  @override
  String get appsDetailHowItWorksBody =>
      'Това е одобрено външно приложение, което работи в Divine. Divine предоставя само прегледани възможности за тази интеграция и блокира навигацията извън одобрените ѝ адреси.';

  @override
  String get appsDetailAboutTitle => 'Относно';

  @override
  String get appsDetailPrimaryOriginTitle => 'Основен адрес';

  @override
  String get appsDetailApprovedOriginsTitle => 'Одобрени адреси';

  @override
  String get appsDetailCapabilitiesTitle => 'Налични възможности';

  @override
  String get appsDetailAskBeforeTitle => 'Питай преди';

  @override
  String get appsDetailOpenButton => 'Отвори интеграцията';

  @override
  String get appsDetailNoneDeclared => 'Още няма декларирани';

  @override
  String get appsDirectoryTitle => 'Свързани приложения';

  @override
  String get appsDirectoryIntroTitle => 'Одобрени външни приложения';

  @override
  String get appsDirectoryIntroBody =>
      'Одобрени външни приложения, които работят в Divine';

  @override
  String get appsDirectoryErrorTitle =>
      'Свързаните приложения не можаха да се заредят';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Дръпни, за да опиташ пак с одобрените интеграции.';

  @override
  String get appsDirectoryEmptyTitle => 'Още няма одобрени интеграции';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Одобрените външни приложения ще се появят тук, щом Divine ги добави.';

  @override
  String get appsDirectoryRefresh => 'Опресни';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Свързаните приложения работят в Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Одобрените интеграции засега са налични само на мобилно устройство.';

  @override
  String get appsSandboxUnavailableTitle => 'Интеграцията не е налична';

  @override
  String get appsSandboxUnavailableBody =>
      'Отваряй одобрените интеграции от раздела Свързани приложения, за да може Divine да приложи правилната политика за достъп.';

  @override
  String get appsSandboxLoadingTitle => 'Зареждане на интеграцията';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Проверяваме одобрената интеграция преди стартиране.';

  @override
  String get appsSandboxBlockedTitle => 'Блокирано за безопасност';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Тази интеграция се опита да напусне одобрения си адрес.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink =>
      'Връзката към публикацията е копирана в клипборда';

  @override
  String get shareCopiedEventJson =>
      'JSON на Nostr събитието е копиран в клипборда';

  @override
  String get shareCopiedEventId =>
      'ID на Nostr събитието е копирано в клипборда';

  @override
  String get authHeroTaglineAuthentic => 'Автентични моменти.';

  @override
  String get authHeroTaglineHuman => 'Човешко творчество.';

  @override
  String get keyImportFailedToImport =>
      'Неуспешно импортиране на ключ или свързване с бункер';

  @override
  String get keyImportInvalidBunkerUrl => 'Невалиден бункер URL';

  @override
  String get keyImportInvalidFormat =>
      'Невалиден формат. Използвай nsec..., hex, ncryptsec1... или bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Невалиден nsec формат. Трябва да е 63 символа';

  @override
  String get keyImportKeyFieldLabel => 'Частен ключ или бункер URL';

  @override
  String get keyImportKeyRequired => 'Въведи частния си ключ или бункер URL';

  @override
  String get keyImportPasswordRequired =>
      'Въведи паролата за този шифрован ключ';

  @override
  String get keyImportSecurityWarningBody =>
      'Никога не споделяй частния си ключ с никого. Този ключ дава пълен достъп до твоята Nostr идентичност.';

  @override
  String get keyImportSecurityWarningTitle => 'Пази частния си ключ в тайна!';

  @override
  String get keyImportSubtitle =>
      'Импортирай съществуващата си Nostr идентичност с частния си ключ или бункер URL.';

  @override
  String get keyImportTitle => 'Импортирай своята\nNostr идентичност';

  @override
  String get commentAuthorYouIndicator => 'Ти';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Преглед на профила на $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Изтрий коментара';

  @override
  String get commentOptionsEditSemanticLabel => 'Редактирай коментара';

  @override
  String get commentOptionsFlagContentLabel => 'Сигнализирай съдържание';

  @override
  String get commentOptionsFlagContentSemanticLabel =>
      'Сигнализирай това съдържание';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Избери причина да сигнализираш този коментар';

  @override
  String get commentOptionsFlagSubmit => 'Изпрати';

  @override
  String get commentOptionsTitle => 'Опции';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Все още работим по импортирането на стари коментари от архива. Още не са готови.';

  @override
  String get commentsEmptyClassicVineTitle => 'Класически Vine';

  @override
  String get commentsInputEditingLabel => 'Редактиране';

  @override
  String get commentsInputSemanticHint => 'Добави коментар';

  @override
  String get commentsInputSemanticHintEdit => 'Редактирай коментара';

  @override
  String get commentsInputSemanticHintReply => 'Добави отговор';

  @override
  String get commentsInputSemanticLabel => 'Поле за коментар';

  @override
  String get commentsInputSemanticLabelEdit => 'Поле за редактиране';

  @override
  String get commentsInputSemanticLabelReply => 'Поле за отговор';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Виж профила на $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Архивът с класики се зарежда';

  @override
  String get classicsEmptyTitle => 'Няма намерени класики';

  @override
  String get classicsErrorTitle => 'Неуспешно зареждане на класиките';

  @override
  String get classicsUnavailableDescription =>
      'Класиките са налични само когато си свързан с релета на Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Превключи към реле с поддръжка на Funnelcake от Настройки, за да получиш достъп до архива с класики.';

  @override
  String get classicsUnavailableTitle => 'Класиките не са налични';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Бъди първият, който публикува видео с този хаштаг!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Няма намерени видеа за #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle =>
      'Това може да отнеме няколко секунди';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Зареждане на видеа за #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Добави хаштагове... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Върни се по-късно за ново съдържание';

  @override
  String get newVideosTabEmptyTitle => 'Няма видеа в Нови видеа';

  @override
  String get popularVideosContextTitle => 'Популярни видеа';

  @override
  String get popularVideosEmptySubtitle =>
      'Върни се по-късно за ново съдържание';

  @override
  String get popularVideosEmptyTitle => 'Няма видеа в Популярни видеа';

  @override
  String get popularVideosErrorTitle =>
      'Неуспешно зареждане на популярните видеа';

  @override
  String get popularVideosFeedSourceLabel => 'Източник на популярната емисия';

  @override
  String get trendingHashtagsLoading => 'Зареждане на хаштагове...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Виж видеа, отбелязани с $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Автор на видеото: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Описание на видеото: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Визията на Divine е да ти даде истински избор на алгоритъм. Вместо да си заключен в един-единствен алгоритъм тип черна кутия, ще можеш да избираш измежду няколко подхода за препоръки:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Хронологична времева линия от твоите последвани творци';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Това те поставя в контрол над вниманието ти, вместо да го оставя на платформата. Трябва да знаеш как се подрежда емисията ти и да имаш властта да я променяш, когато поискаш.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Създадени от общността персонализирани емисии за теми като музика, комедия или изкуство';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Персонализирана емисия „За теб“';

  @override
  String get forYouAlgorithmChoiceTitle => 'Твоят алгоритъм, твоят избор';

  @override
  String get forYouAlgorithmChoiceTrending => 'Актуално и популярно съдържание';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Силен сигнал — беше достатъчно ангажиран, за да отговориш';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine следи как взаимодействаш със съдържанието, за да разбере какво харесваш. Всеки път, когато гледаш видео, дадеш му реакция, оставиш коментар или го споделиш, системата взима това предвид.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Как работи';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Различните действия сигнализират различни нива на интерес:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Ако още не си натрупал история на гледане, ти показваме смесица от това, което е популярно и актуално в момента, заедно с най-новите качвания. Това ти дава чудесна отправна точка за разглеждане.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Докато гледаш, харесваш и се ангажираш със съдържание, препоръките постепенно стават по-персонализирани. С времето емисията ти „За теб“ показва видеа от творци, които може никога да не си открил сам.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Нов в Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Изграждаме отворена система, в която разработчиците могат да създават свои собствени алгоритми, а ти можеш да избираш кои да използваш — или да се откажеш напълно.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Отворен код и прозрачност';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Среден сигнал — бърз начин да покажеш одобрение';

  @override
  String get forYouAlgorithmReactionsTitle => 'Реакции';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Най-силен сигнал — споделянето с твоите последователи е мощно одобрение';

  @override
  String get forYouAlgorithmSubtitle =>
      'Задвижвано от Gorse, машина за препоръки с отворен код';

  @override
  String get forYouAlgorithmTitle => 'Алгоритъмът на Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Слаб сигнал — показва базов интерес';

  @override
  String get forYouEmptyDescription =>
      'Изгледай и хареса няколко видеа, за да получиш персонализирани препоръки.';

  @override
  String get forYouEmptyTitle => 'Още няма препоръки';

  @override
  String get forYouErrorTitle => 'Неуспешно зареждане на препоръките';

  @override
  String get forYouUnavailableDescription =>
      'Персонализираните препоръки изискват връзка с Funnelcake.';

  @override
  String get forYouUnavailableTitle => '„За теб“ не е налично';

  @override
  String get inboxConversationOptionsLabel => 'Опции';

  @override
  String get inboxConversationViewProfileButton => 'Виж профила';

  @override
  String get inboxMessageRequestsEmpty => 'Няма заявки за съобщения';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Заявки за съобщения, $requestCount в очакване';
  }

  @override
  String get inboxMessageRequestsTitle => 'Заявки за съобщения';

  @override
  String get inboxMessagesTab => 'Съобщения';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Заявка за съобщение от $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Изпрати заявка за съобщение';

  @override
  String get inboxRequestsMarkAllRead =>
      'Отбележи всички заявки като прочетени';

  @override
  String get inboxRequestsRemoveAll => 'Премахни всички заявки';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Откажи и премахни';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Заявката на $displayName е отхвърлена';
  }

  @override
  String get messageRequestLoadFailed => 'Заявката не можа да се зареди.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count последователи';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count видеа';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count съобщения',
      one: '1 съобщение',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Виж съобщенията';

  @override
  String get messageRequestViewProfileButton => 'Виж профила';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName иска да ти пише, изпрати ти $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Смени акаунта, затова нищо не беше изтрито. Отвори отново изтриването за акаунта, който искаш да премахнеш.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'За потвърждение напиши:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'За потвърждение напиши потребителското си име:';

  @override
  String get deleteAccountConfirmationHint => 'Напиши DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'Напиши потребителското си име';

  @override
  String get deleteAccountDeleteAllContentButton => 'Изтрий цялото съдържание';

  @override
  String get accountDeletionRecoveryTitle => 'Изтриване на акаунта ти';

  @override
  String get accountDeletionRecoveryBody =>
      'Не успяхме да довършим изтриването на акаунта ти. Потребителското ти име е запазено за теб и още може да бъде върнато.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Върни потребителското ми име';

  @override
  String get accountDeletionFinishingBody =>
      'Заявката ти за изтриване все още се обработва. Можеш да използваш друг акаунт, докато приключим.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Изтриването на друг акаунт все още се обработва на това устройство. Изчакай да приключи, преди да изтриеш този акаунт.';

  @override
  String get accountDeletionCancellingBody =>
      'Отменяме изтриването ти. Провери пак, преди да напуснеш този екран.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Още не успяхме да върнем потребителското ти име. Провери връзката си и опитай пак.';

  @override
  String get accountDeletionUsernameRestored =>
      'Потребителското ти име е върнато. Акаунтът ти не беше изтрит.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Не успяхме да проверим състоянието на изтриването. Провери връзката си и опитай пак.';

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
      'Изтриването на акаунт не е достъпно в момента. Нищо не беше изтрито.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Не успяхме да довършим изтриването на акаунта ти. Опитай пак.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Последно потвърждение';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Заявките за изтриване са изпратени, но ключовете ти може да не са премахнати напълно от това устройство. Отиди в Настройки → Nostr ключове → Премахни ключовете, за да опиташ пак.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Заявките за изтриване са изпратени и си отписан, но някои локални данни не можаха да бъдат премахнати от това устройство.';

  @override
  String get deleteAccountPreparingDeletion => 'Подготовка за изтриване...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total събития';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Това премахва локалния вход за този акаунт от това устройство. Няма да изтрие Divine акаунта ти или Nostr идентичността ти.\n\nЧерновите и клиповете ти остават запазени на това устройство за този акаунт. Ако това е последният ти локален акаунт, ще се върнеш към екрана за вход.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Премахни от устройството';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Да премахнем този акаунт от това устройство?';

  @override
  String get deleteAccountReauthRequired =>
      'Влез отново, за да изтриеш акаунта си. Още нищо не е изтрито.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Заявките за изтриване на публикациите ти са изпратени, но не успяхме да довършим изтриването на акаунта ти. Опитай пак след малко.';

  @override
  String get deleteAccountSuccess =>
      'Твоят Divine акаунт беше изтрит. Изпратени бяха заявки за изтриване на публикациите ти в Nostr, но някои релейни сървъри, клиенти или кешове може да запазят копия.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Заявено е изтриване на акаунта. Изтриването на някои съществуващи публикации не можа да бъде потвърдено поотделно.';

  @override
  String get deleteAccountWarningBody =>
      'Това изпраща заявки за изтриване на акаунта и съдържанието ти, изтрива акаунта ти в Divine, когато е възможно, и те отписва на това устройство. Някои релета, клиенти и индекси за търсене може да запазят копия. Другите устройства с вход остават активни, докато не премахнеш ключовете там.';

  @override
  String get findPeopleNoContacts =>
      'Няма намерени контакти.\nЗапочни да следваш хора, за да ги виждаш тук.';

  @override
  String get geoBlockedCityLabel => 'Град';

  @override
  String get geoBlockedCountryLabel => 'Държава';

  @override
  String get geoBlockedDefaultReason =>
      'Тази услуга не е налична в твоя регион поради местни разпоредби.';

  @override
  String get geoBlockedLegalNotice =>
      'Уважаваме твоите местни закони и разпоредби. Това ограничение се основава на местоположението по IP адреса ти.';

  @override
  String get geoBlockedRegionLabel => 'Регион';

  @override
  String get geoBlockedTitle => 'Услугата не е налична';

  @override
  String get likedVideosEmpty => 'Няма харесани видеа';

  @override
  String get likedVideosInvalidRoute => 'Невалиден маршрут';

  @override
  String get likedVideosTitle => 'Харесани видеа';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Повторно качване…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Запази в чернови';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Запазено в чернови';

  @override
  String get uploadFailureSheetTitle => 'Качването се провали';

  @override
  String get uploadFailureSheetTryAgainButton => 'Опитай пак';

  @override
  String get videoEditorAudioImportAudio => 'Импортирай звук';

  @override
  String get videoEditorAudioImportFailed =>
      'Импортирането на звук се провали.';

  @override
  String get videoIconPlaceholderLabel => 'Видео';

  @override
  String get publishErrorNotSignedIn => 'Влез, за да публикуваш видеа.';

  @override
  String get publishErrorNoRetry => 'Няма качване, което да повториш.';

  @override
  String get publishErrorNoInternet =>
      'Няма връзка с интернет. Провери Wi-Fi или мобилните данни и опитай пак.';

  @override
  String get publishErrorServerUnreachable =>
      'Сървърът е недостъпен. Опитай пак след малко.';

  @override
  String get publishErrorTimeout =>
      'Качването отне твърде дълго. Опитай с по-стабилна връзка или по-малко видео.';

  @override
  String get publishErrorTls =>
      'Сигурната връзка се провали. Провери мрежата си — публичният Wi-Fi може да блокира качванията.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Медийният сървър ($serverName) не е наличен. Можеш да избереш друг в настройките.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Видеофайлът е твърде голям за сървъра. Опитай да го скъсиш или да намалиш качеството.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Медийният сървър ($serverName) получи вътрешна грешка. Можеш да избереш друг в настройките.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Медийният сървър ($serverName) временно не работи. Опитай пак скоро или избери друг в настройките.';
  }

  @override
  String get publishErrorForbidden =>
      'Нямаш разрешение да качваш на този сървър.';

  @override
  String get publishErrorFileNotFound =>
      'Видеофайлът не може да бъде намерен. Може да е изтрит. Запиши отново и опитай пак.';

  @override
  String get publishErrorLowStorage =>
      'Няма достатъчно място на устройството ти. Освободи малко място и опитай пак.';

  @override
  String get publishErrorThumbnailFailed =>
      'Видеото се качи, но миниатюрата не можа да се подготви. Опитай пак.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Видеото се качи, но публикацията не можа да се пусне. Провери настройките за релета и опитай пак.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Видеото се качи, но звукът не е разрешен за повторна употреба. Избери друг звук, за да публикуваш.';

  @override
  String get publishErrorInterrupted =>
      'Качването беше прекъснато. Искаш ли да опиташ пак?';

  @override
  String get publishErrorAccountChanged =>
      'Това видео е от друг профил. Върни се към него, за да го публикуваш.';

  @override
  String get publishErrorGeneric => 'Нещо се обърка. Опитай пак.';

  @override
  String get publishErrorRateLimited =>
      'Твърде много качвания в момента. Изчакай малко и опитай пак.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Сесията ти за качване изтече. Опитай пак.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine няма разрешение да качва. Провери разрешенията на приложението в настройките и опитай пак.';

  @override
  String get publishErrorOutOfMemory =>
      'Устройството ти е с малко свободна памет. Затвори няколко приложения и опитай пак.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Текстът и стикерите в тази чернова не можаха да се подготвят. Отвори я в редактора и публикувай пак.';

  @override
  String get publishErrorUnknownServer => 'Неизвестен сървър';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Филтър: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Няма намерени резултати за „$query“';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Виж видеа, отбелязани с $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Звук: $soundName от $creatorName. Докосни, за да видиш подробности за звука.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Оригинален звук от $creatorName. Докосни, за да използваш този звук.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Звук: $soundName от $creatorName. Докосни, за да видиш подробности.';
  }

  @override
  String get soundDetailLoadError =>
      'Неуспешно зареждане на звука. Опитай пак.';

  @override
  String get soundDetailNotFoundMessage => 'Този звук не можа да бъде намерен';

  @override
  String get soundDetailNotFoundTitle => 'Звукът не е намерен';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count лупа';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Звукът от това видео не е наличен отделно.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Оригинален звук - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Този човек е публикувал оригинален Vine, който Divine намери в архива. Това не е значка за потвърден профил.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Отметка на профила';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine дава тази отметка на профилите на екипа. Това е различно от NIP-05, потвърдените връзки към профила и статуса OG Viner.';

  @override
  String get unfollowConfirmButton => 'Спри да следваш';

  @override
  String get videoClipSaveFailed => 'Неуспешно запазване на клипа';

  @override
  String videoClipSaveTo(String destination) {
    return 'Запази в $destination';
  }

  @override
  String get videoClipDelete => 'Изтрий клипа';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Вдъхновено от $creatorName +$additionalCreatorCount. Докосни, за да видиш профила им.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Вдъхновено от $creatorName. Докосни, за да видиш профила им.';
  }

  @override
  String get bugReportSendReport => 'Изпрати доклад';

  @override
  String get supportSubjectRequiredLabel => 'Тема *';

  @override
  String get supportPublicSubmissionTitle => 'Публична публикация в GitHub';

  @override
  String get supportPublicSubmissionMessage =>
      'Всичко, което изпратиш тук, ще бъде публикувано в нашето хранилище с отворен код в GitHub, за да могат разработчиците да го поемат. Публикацията и профилът, с който си влязъл, ще бъдат видими за всички.';

  @override
  String get supportRequiredHelper => 'Задължително';

  @override
  String get supportFieldLimitReached =>
      'Това е максималната дължина. Всичко след нея не беше добавено.';

  @override
  String get bugReportSubjectHint => 'Кратко резюме на проблема';

  @override
  String get bugReportDescriptionRequiredLabel => 'Какво се случи? *';

  @override
  String get bugReportDescriptionHint => 'Опиши проблема, който срещна';

  @override
  String get bugReportStepsLabel => 'Стъпки за възпроизвеждане';

  @override
  String get bugReportStepsHint =>
      '1. Отиди в...\n2. Натисни...\n3. Виж грешката';

  @override
  String get bugReportExpectedBehaviorLabel => 'Очаквано поведение';

  @override
  String get bugReportExpectedBehaviorHint =>
      'Какво трябваше да стане вместо това?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Информацията за устройството и логовете ще се прикачат автоматично.';

  @override
  String get bugReportSuccessMessage =>
      'Благодарим ти! Получихме доклада ти и ще го използваме, за да направим Divine по-добро.';

  @override
  String get bugReportAttachImages => 'Прикачи снимки';

  @override
  String bugReportImagesCount(int count, int max) {
    return 'Избрани са $count от $max снимки';
  }

  @override
  String get bugReportRemoveImage => 'Премахни снимката';

  @override
  String get bugReportUploadFailed =>
      'Не успяхме да качим избраната снимка. Опитай пак или изпрати доклада без нея.';

  @override
  String get bugReportSendFailed =>
      'Изпращането на доклада не успя. Опитай пак по-късно.';

  @override
  String get featureRequestSendRequest => 'Изпрати заявка';

  @override
  String get featureRequestSubjectHint => 'Кратко резюме на идеята ти';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Какво искаш? *';

  @override
  String get featureRequestDescriptionHint => 'Опиши функцията, която искаш';

  @override
  String get featureRequestUsefulnessLabel => 'С какво ще е полезна?';

  @override
  String get featureRequestUsefulnessHint =>
      'Обясни ползата, която тази функция ще донесе';

  @override
  String get featureRequestWhenLabel => 'Кога би я ползвал?';

  @override
  String get featureRequestWhenHint =>
      'Опиши ситуациите, в които това ще помогне';

  @override
  String get featureRequestSuccessMessage =>
      'Благодарим ти! Получихме заявката ти и ще я разгледаме.';

  @override
  String get featureRequestSendFailed =>
      'Изпращането на заявката не успя. Опитай пак по-късно.';

  @override
  String get notificationFollowBack => 'Последвай обратно';

  @override
  String get followingTitle => 'Следваш';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName следва';
  }

  @override
  String get followingFailedToLoadList =>
      'Неуспешно зареждане на следния списък';

  @override
  String get followingEmptyTitle => 'Все още не следваш никого';

  @override
  String get followersTitle => 'Последователи';

  @override
  String followersTitleForName(String displayName) {
    return 'Последователи на $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Неуспешно зареждане на списъка с последователи';

  @override
  String get followersEmptyTitle => 'Все още няма последователи';

  @override
  String get followersUpdateFollowFailed =>
      'Актуализирането на следването не успя. Опитай пак.';

  @override
  String get followersSortSemanticLabel => 'Сортиране на последователите';

  @override
  String get followingSortSemanticLabel => 'Сортиране на следваните';

  @override
  String get followSortTitle => 'Сортиране по';

  @override
  String get followSortNewest => 'Първо най-новите';

  @override
  String get followSortOldest => 'Първо най-старите';

  @override
  String get newMessageTitle => 'Ново съобщение';

  @override
  String get newMessageFindPeople => 'Намери хора';

  @override
  String get newMessageNoContacts =>
      'Не са намерени контакти.\nПоследвай хора, за да ги виждаш тук.';

  @override
  String get newMessageNoUsersFound => 'Не са намерени потребители';

  @override
  String get hashtagSearchTitle => 'Търси хаштагове';

  @override
  String get hashtagSearchSubtitle => 'Открий популярни теми и съдържание';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Няма намерени хаштагове за „$query“';
  }

  @override
  String get hashtagSearchFailed => 'Търсенето не успя';

  @override
  String get userNotAvailableTitle => 'Акаунтът не е наличен';

  @override
  String get userNotAvailableBody => 'Този акаунт в момента не е наличен.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Неуспешно запазване на настройките. Опитай пак.';

  @override
  String get blossomValidServerUrl =>
      'Въведи валиден URL на сървър (напр. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Настройките за Blossom са запазени';

  @override
  String get blossomSaveTooltip => 'Запази';

  @override
  String get blossomAboutTitle => 'Относно Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom е децентрализиран протокол за съхранение на медия, който ти позволява да качваш видеа на всеки съвместим сървър. По подразбиране видеата се качват на Blossom сървъра на Divine. Включи опцията по-долу, ако искаш да използваш персонализиран сървър.';

  @override
  String get blossomUseCustomServer =>
      'Използвай персонализиран Blossom сървър';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Видеата ще се качват на твоя персонализиран Blossom сървър';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'В момента видеата ти се качват на Blossom сървъра на Divine';

  @override
  String get blossomCustomServerUrl => 'URL на персонализиран Blossom сървър';

  @override
  String get blossomCustomServerHelper =>
      'Въведи URL на персонализирания си Blossom сървър';

  @override
  String get blossomPopularServers => 'Популярни Blossom сървъри';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL на Blossom сървъра трябва да използва https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Неуспешно актуализиране на настройката за кръстосана публикация';

  @override
  String get blueskySignInRequired =>
      'Влез, за да управляваш настройките за Bluesky';

  @override
  String get blueskyPublishVideos => 'Публикувай видеа в Bluesky';

  @override
  String get blueskyEnabledSubtitle => 'Видеата ти ще се публикуват в Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Видеата ти няма да се публикуват в Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'И старите ти видеа ще се публикуват';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Когато включиш това, Divine ще започне да изпраща по-старите ти видеа към Bluesky, първо най-старите, без да бърза с дневния лимит.';

  @override
  String get blueskyHandle => 'Bluesky потребител';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => 'Състояние';

  @override
  String get blueskyStatusReady => 'Акаунтът е създаден и готов';

  @override
  String get blueskyStatusPending => 'Създаването на акаунт е в ход...';

  @override
  String get blueskyStatusFailed => 'Създаването на акаунт не успя';

  @override
  String get blueskyStatusDisabled => 'Акаунтът е изключен';

  @override
  String get blueskyStatusNotLinked => 'Няма свързан Bluesky акаунт';

  @override
  String get blueskyUsernameRequired =>
      'Настрой divine.video хендъл, преди да публикуваш в Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'За публикуване в Bluesky е нужен заявен хендъл потребител.divine.video.';

  @override
  String get blueskyUsernameSyncPending =>
      'Хендълът ти в Divine е заявен. Свързваме го с Bluesky – опитай пак след малко.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Не успяхме да проверим хендъла ти в Divine. Опитай пак.';

  @override
  String get blueskySetUpHandle => 'Настрой';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Публикуването в Bluesky временно не е достъпно. Опитай пак.';

  @override
  String get invitesTitle => 'Покани приятели';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count покани са готови за генериране',
      one: '1 покана е готова за генериране',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Генерирай код, когато си готов да го споделиш.';

  @override
  String get invitesGenerateButtonLabel => 'Генерирай покана';

  @override
  String get invitesNoneAvailable => 'В момента няма налични покани';

  @override
  String get invitesShareWithPeople => 'Сподели Divine с хора, които познаваш';

  @override
  String get invitesUsedInvites => 'Използвани покани';

  @override
  String invitesShareMessage(String code) {
    return 'Присъедини се към мен в Divine! Използвай код за покана $code, за да започнеш:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Копирай поканата';

  @override
  String get invitesCopied => 'Поканата е копирана!';

  @override
  String get invitesShareInvite => 'Сподели поканата';

  @override
  String get invitesShareSubject => 'Присъедини се към мен в Divine';

  @override
  String get invitesClaimed => 'Използвана';

  @override
  String get invitesCouldNotLoad => 'Поканите не се заредиха';

  @override
  String get invitesRetry => 'Опитай пак';

  @override
  String get searchSomethingWentWrong => 'Нещо се обърка';

  @override
  String get searchTryAgain => 'Опитай пак';

  @override
  String get searchForLists => 'Търсете списъци';

  @override
  String get searchFindCuratedVideoLists => 'Намери подбрани видео списъци';

  @override
  String get searchEnterQuery => 'Въведи заявка за търсене';

  @override
  String get searchDiscoverSomethingInteresting => 'Открийте нещо интересно';

  @override
  String get searchPeopleSectionHeader => 'Хора';

  @override
  String get searchPeopleLoadingLabel => 'Зареждат се резултати за хора';

  @override
  String get searchTagsSectionHeader => 'Етикети';

  @override
  String get searchTagsLoadingLabel => 'Резултатите от етикета се зареждат';

  @override
  String get searchVideosSectionHeader => 'Видеоклипове';

  @override
  String get searchVideosLoadingLabel => 'Зареждат се видео резултати';

  @override
  String get searchVideosSortOptionsLabel => 'Подреди резултатите с видеа';

  @override
  String get searchVideosSortTrending => 'Актуални';

  @override
  String get searchVideosSortLoops => 'Най-много лупове';

  @override
  String get searchVideosSortEngagement => 'Най-ангажиращи';

  @override
  String get searchVideosSortRecent => 'Скорошни';

  @override
  String get searchListsSectionHeader => 'Списъци';

  @override
  String get searchListsLoadingLabel => 'Резултатите от списъка се зареждат';

  @override
  String get cameraAgeRestriction =>
      'Трябва да си на 16 или повече, за да създаваш съдържание';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker релето трябва да използва wss:// (ws:// е позволено само за localhost)';

  @override
  String get timeNow => 'Сега';

  @override
  String timeShortMinutes(int count) {
    return '$countм';
  }

  @override
  String timeShortHours(int count) {
    return '$countч';
  }

  @override
  String timeShortDays(int count) {
    return '$countд';
  }

  @override
  String timeShortWeeks(int count) {
    return '$countседм';
  }

  @override
  String timeShortMonths(int count) {
    return '$countмес';
  }

  @override
  String timeShortYears(int count) {
    return '$countг';
  }

  @override
  String get timeVerboseNow => 'Сега';

  @override
  String timeAgo(String time) {
    return 'Преди $time';
  }

  @override
  String get timeToday => 'Днес';

  @override
  String get timeYesterday => 'Вчера';

  @override
  String get timeJustNow => 'Току-що';

  @override
  String timeMinutesAgo(int count) {
    return 'Преди $count мин';
  }

  @override
  String timeHoursAgo(int count) {
    return 'Преди $countч';
  }

  @override
  String timeDaysAgo(int count) {
    return 'Преди $count дни';
  }

  @override
  String get draftTimeJustNow => 'Току-що';

  @override
  String get contentLabelNudity => 'Голота';

  @override
  String get contentLabelSexualContent => 'Сексуално съдържание';

  @override
  String get contentLabelPornography => 'Порнография';

  @override
  String get contentLabelGraphicMedia => 'Графични медии';

  @override
  String get contentLabelViolence => 'Насилие';

  @override
  String get contentLabelSelfHarm => 'Самонараняване/самоубийство';

  @override
  String get contentLabelDrugUse => 'Употреба на наркотици';

  @override
  String get contentLabelAlcohol => 'Алкохол';

  @override
  String get contentLabelTobacco => 'Тютюн/пушене';

  @override
  String get contentLabelGambling => 'Хазарт';

  @override
  String get contentLabelProfanity => 'Ругатни';

  @override
  String get contentLabelHateSpeech => 'Реч на омразата';

  @override
  String get contentLabelHarassment => 'Тормоз';

  @override
  String get contentLabelFlashingLights => 'Мигащи светлини';

  @override
  String get contentLabelAiGenerated => 'Генерирано от AI';

  @override
  String get contentLabelDeepfake => 'Дийпфейк';

  @override
  String get contentLabelSpam => 'Спам';

  @override
  String get contentLabelScam => 'Скам/измама';

  @override
  String get contentLabelSpoiler => 'Спойлер';

  @override
  String get contentLabelMisleading => 'Подвеждащи';

  @override
  String get contentLabelSensitiveContent => 'Чувствително съдържание';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName хареса видеото ти';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName хареса коментара ти';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName коментира видеото ти';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName започна да те следва';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName те спомена';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName сподели видеото ти пак';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName публикува ново видео';
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
      other: '$count твои vine-ове',
      one: 'твоята vine',
    );
    return '$actorName добави $_temp0 към $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName Отговори на коментара ти';
  }

  @override
  String get notificationAndConnector => 'И';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count други',
      one: '1 друг',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Имаш ново известие';

  @override
  String get commentReplyToPrefix => 'Отг.:';

  @override
  String get commentHideKeyboard => 'Скрий клавиатурата';

  @override
  String get commentsErrorLoadFailed => 'Коментарите не се заредиха';

  @override
  String get commentsErrorNotAuthenticatedComment => 'Влез, за да коментираш';

  @override
  String get commentsErrorPostCommentFailed => 'Коментарът не беше публикуван';

  @override
  String get commentsErrorPostReplyFailed => 'Отговорът не беше публикуван';

  @override
  String get commentsErrorEditFailed => 'Коментарът не беше редактиран';

  @override
  String get commentsErrorNotAuthenticatedInteract => 'Влез, за да участваш';

  @override
  String get commentsErrorVoteFailed => 'Гласуването за коментара не мина';

  @override
  String get commentsErrorReportFailed => 'Коментарът не беше докладван';

  @override
  String get commentsErrorBlockFailed => 'Потребителят не беше блокиран';

  @override
  String get commentsErrorDeleteFailed => 'Коментарът не беше изтрит';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count коментара',
      one: '$count коментар',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Публикуване…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Вашият видео отговор се публикува';

  @override
  String get commentsSortNew => 'Нови';

  @override
  String get commentsSortTop => 'Топ';

  @override
  String get commentsSortOld => 'Стари';

  @override
  String get commentsSortSemanticLabel => 'Подреждане на коментарите';

  @override
  String get commentReply => 'Отговори';

  @override
  String get commentReplySemanticLabel => 'Отговори на коментара';

  @override
  String get commentUpvoteLabel => 'Гласувай „за“ коментара';

  @override
  String get commentRemoveUpvoteLabel => 'Махни гласа „за“';

  @override
  String get commentDownvoteLabel => 'Гласувай „против“ коментара';

  @override
  String get commentRemoveDownvoteLabel => 'Махни гласа „против“';

  @override
  String get commentsInputHint => 'Добави коментар...';

  @override
  String get commentsInputHintEdit => 'Редактирай коментара...';

  @override
  String get commentsEmptyTitle => 'Още няма коментари';

  @override
  String get commentsEmptySubtitle => 'Дай начало на купона!';

  @override
  String get draftUntitled => 'Без заглавие';

  @override
  String get contentWarningNone => 'Няма';

  @override
  String get textBackgroundNone => 'Няма';

  @override
  String get textBackgroundSolid => 'Твърди';

  @override
  String get textBackgroundHighlight => 'Маркирайте';

  @override
  String get textBackgroundTransparent => 'Прозрачен';

  @override
  String get textAlignLeft => 'Наляво';

  @override
  String get textAlignRight => 'Вярно';

  @override
  String get textAlignCenter => 'Център';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Камерата още не се поддържа в уеб';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Снимането и записът с камера още не са налични в уеб версията.';

  @override
  String get cameraPermissionBackToFeed => 'Назад към фийда';

  @override
  String get cameraCouldNotStart => 'Не успяхме да стартираме камерата';

  @override
  String get cameraUnsupportedPlatform =>
      'Камерата все още не е налична на тази платформа.\nВсе пак можеш да разглеждаш и гледаш видеа.';

  @override
  String get cameraPermissionErrorTitle => 'Грешка с разрешенията';

  @override
  String get cameraPermissionErrorDescription =>
      'Нещо се обърка, докато проверявахме разрешенията.';

  @override
  String get cameraPermissionRetry => 'Опитай пак';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Разреши достъп до камерата и микрофона';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Това ти позволява да записваш и редактираш видеа директно в приложението. Нищо повече.';

  @override
  String get cameraPermissionGoToSettings => 'Към настройките';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Защо шест секунди?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Кратките клипове оставят място за спонтанност. 6-секундният формат ти помага да хванеш истинските моменти, докато се случват.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Разбрах!';

  @override
  String get videoRecorderUploadTitle => 'Защо няма качване?';

  @override
  String get videoRecorderUploadBody =>
      'Това, което виждаш в Divine, е направено от хора: сурово и заснето в момента. За разлика от платформи, които позволяват силно продуцирани или генерирани от ИИ качвания, ние даваме приоритет на автентичността на преживяването директно от камерата.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Като пазим създаването вътре в приложението, можем по-добре да гарантираме, че съдържанието е истинско и нередактирано. В момента не отваряме качвания от външна галерия, за да защитим тази автентичност и да пазим общността си свободна от синтетично съдържание, доколкото е възможно.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Превключи на Capture или Classic, за да заснемеш нещо истинско.';

  @override
  String get videoRecorderUploadLearnMore => 'Научи как работи проверката';

  @override
  String get videoRecorderAutosaveFoundTitle => 'Намерихме започнато видео';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Искаш ли да продължиш оттам, докъдето стигна?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Да, продължете';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Не, започни ново видео';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Не успяхме да възстановим черновата ти';

  @override
  String get videoRecorderStopRecordingTooltip => 'Спрете записа';

  @override
  String get videoRecorderStartRecordingTooltip => 'Започни записа';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Записване. Докосни навсякъде, за да спрете';

  @override
  String get videoRecorderTapToStartLabel =>
      'Докосни произволно място, за да започнете да записвате';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Изтрий последния клип';

  @override
  String get videoRecorderSwitchCameraLabel => 'Смени камерата';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Мащабиране до $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Превключване на мрежата';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Превключване на призрачна рамка';

  @override
  String get videoRecorderGhostFrameEnabled => 'Рамката призрак е активирана';

  @override
  String get videoRecorderGhostFrameDisabled =>
      'Призрачната рамка е деактивирана';

  @override
  String get videoRecorderClipDeletedMessage => 'Клипът е преместен в кошчето';

  @override
  String get videoRecorderClipUndoLabel => 'Отмени';

  @override
  String get libraryTrashEmptyTitle => 'Кошчето е празно';

  @override
  String get libraryTrashEmptySubtitle =>
      'Изтритите клипове остават тук 30 дни, преди да бъдат премахнати окончателно.';

  @override
  String get libraryTrashRestoreLabel => 'Възстанови';

  @override
  String get libraryTrashDeleteNowLabel => 'Изтрий сега';

  @override
  String get libraryTrashEmptyAllLabel => 'Изпразни кошчето';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Да изтрия ли клипа сега?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Това веднага премахва клипа от кошчето.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Да изпразня ли кошчето?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа',
      one: '1 клип',
    );
    return 'Това ще изтрие окончателно $_temp0 от кошчето веднага.';
  }

  @override
  String get videoRecorderCloseLabel => 'Затворете видеорекордер';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Продължете към видеоредактора';

  @override
  String get videoRecorderCameraPreviewLabel => 'Преглед от камерата';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Фокусиране на камерата';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Превключване към режим $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => 'Добавете аудио преди запис';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Видеото не можа да се създаде. Опитайте отново.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Остават $count кадъра',
      one: 'Остава 1 кадър',
      zero: 'Няма останали кадри',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Превключване на светкавицата';

  @override
  String get videoRecorderCycleTimerLabel => 'Цикъл таймер';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Превключване на пропорциите';

  @override
  String get videoRecorderStabilizationLabel => 'Стабилизация';

  @override
  String get videoRecorderStabilizationModeOff => 'Изкл.';

  @override
  String get videoRecorderStabilizationModeStandard => 'Стандартна';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Кинематографична';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Кинематографична разширена';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Оптимизирана за преглед';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Ниска латентност';

  @override
  String get videoRecorderStabilizationModeAuto => 'Авто';

  @override
  String get videoRecorderFlashValueOff => 'Изкл.';

  @override
  String get videoRecorderFlashValueOn => 'Вкл.';

  @override
  String get videoRecorderFlashValueAuto => 'Авто';

  @override
  String get videoRecorderTimerValueOff => 'Изкл.';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 секунди';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 секунди';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Квадратно';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Вертикално';

  @override
  String get videoRecorderCameraValueFront => 'Предна камера';

  @override
  String get videoRecorderCameraValueBack => 'Задна камера';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Библиотека с клипове, няма клипове';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Отвори библиотеката с клипове, $clipCount клипа',
      one: 'Отвори библиотеката с клипове, 1 клип',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Отвори стоп-моушън библиотеката, $frameCount кадъра',
      one: 'Отвори стоп-моушън библиотеката, 1 кадър',
      zero: 'Отвори стоп-моушън библиотеката',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Камера';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Отвори камерата';

  @override
  String get videoEditorLibraryLabel => 'Библиотека';

  @override
  String get videoEditorTextLabel => 'Текст';

  @override
  String get videoEditorDrawLabel => 'Начертайте';

  @override
  String get videoEditorFilterLabel => 'Филтър';

  @override
  String get videoEditorTuneLabel => 'Настройка';

  @override
  String get videoEditorOpenTuneSemanticLabel =>
      'Отваряне на редактора за настройки';

  @override
  String get videoEditorTuneBrightness => 'Яркост';

  @override
  String get videoEditorTuneContrast => 'Контраст';

  @override
  String get videoEditorTuneSaturation => 'Наситеност';

  @override
  String get videoEditorTuneExposure => 'Експозиция';

  @override
  String get videoEditorTuneHue => 'Нюанс';

  @override
  String get videoEditorTuneTemperature => 'Температура';

  @override
  String get videoEditorTuneTint => 'Отенък';

  @override
  String get videoEditorTuneFade => 'Избледняване';

  @override
  String get videoEditorAudioLabel => 'Аудио';

  @override
  String get videoEditorAddTitle => 'Добави';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Отвори библиотеката';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Отвори аудио редактора';

  @override
  String get videoEditorCaptionsLabel => 'Субтитри';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Отвори редактора на субтитри';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Вграждане във видеото';

  @override
  String get videoEditorCaptionsPresetCustom => 'Собствен';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Собствен стил';

  @override
  String get videoEditorCaptionsCustomApply => 'Приложи';

  @override
  String get videoEditorCaptionsCustomFont => 'Шрифт';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Цвят на текста';

  @override
  String get videoEditorCaptionsCustomBackground => 'Фон';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Цвят на фона';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Анимация';

  @override
  String get videoEditorCaptionsAnimationNone => 'Няма';

  @override
  String get videoEditorCaptionsAnimationFade => 'Избледняване';

  @override
  String get videoEditorCaptionsAnimationPop => 'Поп';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Пружина';

  @override
  String get videoEditorCaptionsEditTitle => 'Субтитри';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Слушаме…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Превръщаме аудиото ти в предложения за субтитри.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Не чухме реч. Все пак можеш да напишеш субтитрите сам.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Разпознаването на реч не е налично на това устройство. Можеш да напишеш субтитрите сам.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Разпознаването на реч не е разрешено. Включи го в Настройки или напиши субтитрите сам.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Транскрипцията не се получи този път. Можеш да напишеш субтитрите сам.';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'Ще напиша субтитрите сам';

  @override
  String get videoEditorCaptionsAddCue => 'Добави субтитър';

  @override
  String get videoEditorCaptionsCueTextHint => 'Текст на субтитъра';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Изтрий субтитъра';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Премахни всички субтитри';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Да премахнем ли субтитрите?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Целият текст и времената ще бъдат загубени.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Затвори редактора на субтитри';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Потвърди субтитрите';

  @override
  String get videoEditorCaptionsPresetTitle => 'Стил на субтитрите';

  @override
  String get videoEditorCaptionsPresetClassic => 'Класически';

  @override
  String get videoEditorCaptionsPresetPop => 'Поп';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Спринг';

  @override
  String get videoEditorCaptionsPresetMono => 'Моно';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Заглавие';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Пишеща машина';

  @override
  String get videoEditorCaptionsPresetMarker => 'Маркер';

  @override
  String get videoEditorCaptionsPresetScript => 'Калиграфия';

  @override
  String get videoEditorCaptionsPresetRetro => 'Ретро';

  @override
  String get videoEditorCaptionsPresetElegant => 'Елегантен';

  @override
  String get videoEditorCaptionsPresetBubble => 'Балонче';

  @override
  String get videoEditorCaptionsPresetNeon => 'Неон';

  @override
  String get videoEditorCaptionsPresetBold => 'Удебелен';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Мечтателен';

  @override
  String get videoEditorCaptionsPresetOcean => 'Океан';

  @override
  String get videoEditorCaptionsPresetSunny => 'Слънчев';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Ръкописен';

  @override
  String get videoEditorCaptionsPresetSerif => 'Серифен';

  @override
  String get videoEditorCaptionsPresetStamp => 'Печат';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Отвори текстовия редактор';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Отвори редактора за рисуване';

  @override
  String get videoEditorOpenFilterSemanticLabel =>
      'Отвори редактора на филтъра';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Отвори редактора на стикери';

  @override
  String get videoEditorSaveDraftTitle => 'Да запазим черновата?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Запази редакциите си за по-късно или ги отхвърлете и напуснете редактора.';

  @override
  String get videoEditorSaveDraftButton => 'Запазване на черновата';

  @override
  String get videoEditorDiscardChangesButton => 'Отхвърляне на промените';

  @override
  String get videoEditorKeepEditingButton => 'Продължете да редактирате';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Изтриване на зоната за падане на слоя';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Пуснете, за да изтриете слой';

  @override
  String get videoEditorDoneLabel => 'Готово';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Пускане или пауза на видео';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Разделената позиция е невалидна. И двата клипа трябва да са дълги поне ${minDurationMs}ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Запази избрания клип';

  @override
  String get videoEditorSaveClip => 'Запазване на клипа';

  @override
  String get videoEditorClipSavedSuccess => 'Клипът е запазен в библиотеката';

  @override
  String get videoEditorClipSaveFailed => 'Не успяхме да запазим клипа';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Избор на цвят';

  @override
  String get videoEditorUndoSemanticLabel => 'Отмяна';

  @override
  String get videoEditorRedoSemanticLabel => 'Повторете';

  @override
  String get videoEditorTextColorSemanticLabel => 'Цвят на текста';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Подравняване на текст';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Текстов фон';

  @override
  String get videoEditorFontSemanticLabel => 'Шрифт';

  @override
  String get videoEditorNoStickersFound => 'Няма намерени стикери';

  @override
  String get videoEditorNoStickersAvailable => 'Няма налични стикери';

  @override
  String get videoEditorFailedLoadStickers => 'Не успяхме да заредим стикерите';

  @override
  String get videoEditorVoiceOverLabel => 'Глас зад кадър';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Запис $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Запис на глас зад кадър';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Започни запис';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Спри записа';

  @override
  String get videoEditorVoiceOverHint =>
      'Докосни, за да записваш. Добави колкото дубъла искаш.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записа',
      one: '1 запис',
      zero: 'Все още няма записи',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Изтрий последния запис';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Нужен е достъп до микрофона';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Разреши достъп до микрофона, за да запишеш глас зад кадър.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Отвори настройките';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Записът започна';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Записът е запазен';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Записът е по-дълъг от вашето видео';

  @override
  String get videoEditorPlaySemanticLabel => 'Играйте';

  @override
  String get videoEditorPauseSemanticLabel => 'Пауза';

  @override
  String get videoEditorVolumeSemanticLabel => 'Регулиране на силата на звука';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Сила на звука $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Плъзнете за регулиране';

  @override
  String get videoEditorChromaKeyLabel => 'Зелен екран';

  @override
  String get videoEditorChromaKeyTitle => 'Зелен екран';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Настрой зеления екран за този клип';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Отхвърли промените по зеления екран';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Приложи зеления екран';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Автоматично разпознаване';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Зелено';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Синьо';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Цвят на фона';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Сила';

  @override
  String get videoEditorChromaKeyAmountHint => 'Колко от цвета на фона изчезва';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Ръб';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Омекотява изрязването, за да не назъбва косата';

  @override
  String get videoEditorChromaKeySpillLabel => 'Отблясък';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Издърпва цвета на фона от обекта ти';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Замени с';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Нищо';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Цвят';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Изображение';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Клип';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Видеото не може да носи прозрачност, затова това ще излезе черно при експорт.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Не открихме фон. Той трябва да стига до ръба на кадъра — иначе избери цвета ръчно.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Избери клип';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Библиотеката ти е празна. Първо запази клип, после го използвай като фон.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Изображението не можа да се зареди.';

  @override
  String get videoEditorChromaKeyRemove => 'Премахни зеления екран';

  @override
  String get videoEditorChromaKeyFailed =>
      'Зеленият екран не можа да се приложи. Клипът ти остава непроменен.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Зеленият екран не можа да се премахне. Клипът ти остава непроменен.';

  @override
  String get videoEditorChromaKeyApplying => 'Прилагане на зеления екран…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Това устройство не може да показва прегледа на живо. Настройките ти важат при експорт.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Клип $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Изтрий';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Изтриване на избрания елемент';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Кадри на изображение';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кадъра',
      one: '1 кадър',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Кадри';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count кадъра на изображение';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Стоп-моушън кадър $position от $total';
  }

  @override
  String get videoEditorEditLabel => 'Редактиране';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Редактиране на избрания елемент';

  @override
  String get videoEditorDuplicateLabel => 'Дубликат';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Дублиране на избрания елемент';

  @override
  String get videoEditorCombineLabel => 'Обединяване';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Обедини избраните рисунки в един слой';

  @override
  String get videoEditorSplitLabel => 'Сплит';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Разделете избрания клип';

  @override
  String get videoEditorExtractAudioLabel => 'Извличане на аудио';

  @override
  String get videoEditorClipAudioTitle => 'Аудио от клип';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Извлечи аудио от клип и заглуши оригинала';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Не може да се извлече аудио: клипът не е наличен локално.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Не можа да се извлече аудио. Моля, опитайте отново.';

  @override
  String get videoEditorSpeedLabel => 'Скорост';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Задаване на скорост на възпроизвеждане за избрания клип';

  @override
  String get videoEditorReverseLabel => 'Обратно';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Включване или изключване на обратно възпроизвеждане за избрания клип';

  @override
  String get videoEditorReverseProgressLabel => 'Момент, обръщаме клипа ви';

  @override
  String get videoEditorTransformLabel => 'Преобразуване';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Изрежете, завъртете или обърнете избрания клип';

  @override
  String get videoEditorTransformProgressLabel =>
      'Един момент, преобразуваме вашия клип';

  @override
  String get videoEditorTransformFailed =>
      'Клипът не може да бъде преобразуван. Опитайте отново.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Преобразуването е невъзможно: клипът не е наличен локално.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Изрязване, завъртане или обръщане на избрания кадър';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Само момент, преобразуваме кадъра ти';

  @override
  String get videoEditorTransformFrameFailed =>
      'Кадърът не можа да бъде преобразуван. Опитай отново.';

  @override
  String get videoEditorTransformRotateLabel => 'Завъртане';

  @override
  String get videoEditorTransformFlipLabel => 'Обръщане';

  @override
  String get videoEditorTransformResetLabel => 'Нулиране';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'Прилагане на преобразуването';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Отказ на преобразуването';

  @override
  String get videoEditorTransformPlayLabel => 'Възпроизвеждане';

  @override
  String get videoEditorTransformPauseLabel => 'Пауза';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Не може да се обърне: клипът не е наличен локално.';

  @override
  String get videoEditorReverseFailed =>
      'Клипът не можа да се обърне. Моля, опитайте отново.';

  @override
  String get videoEditorSpeedSheetTitle => 'Скорост на клипа';

  @override
  String get videoEditorTransitionSheetTitle => 'Преход';

  @override
  String get videoEditorTransitionNone => 'Без';

  @override
  String get videoEditorTransitionDissolve => 'Преливане';

  @override
  String get videoEditorTransitionFadeToBlack => 'Затъмняване';

  @override
  String get videoEditorTransitionFadeToWhite => 'Избеляване';

  @override
  String get videoEditorTransitionSlide => 'Плъзгане';

  @override
  String get videoEditorTransitionPush => 'Избутване';

  @override
  String get videoEditorTransitionWipe => 'Избърсване';

  @override
  String get videoEditorTransitionButtonSemanticLabel =>
      'Редактиране на преход';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Циклов преход';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Редактиране на циклов преход';

  @override
  String get videoEditorTransitionDuration => 'Продължителност';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Съкратено, за да не се припокрива със съседния преход.';

  @override
  String get videoEditorTransitionCurve => 'Крива';

  @override
  String get videoEditorTransitionDirection => 'Посока';

  @override
  String get videoEditorTransitionDirectionLeft => 'Ляво';

  @override
  String get videoEditorTransitionDirectionRight => 'Дясно';

  @override
  String get videoEditorTransitionDirectionUp => 'Нагоре';

  @override
  String get videoEditorTransitionDirectionDown => 'Надолу';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Крива на анимация $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Анимация';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Редактиране на анимация на слоя';

  @override
  String get videoEditorLayerAnimationEnter => 'Вход';

  @override
  String get videoEditorLayerAnimationLeave => 'Изход';

  @override
  String get videoEditorLayerAnimationFade => 'Избледняване';

  @override
  String get videoEditorLayerAnimationScale => 'Мащаб';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Мащаб от';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Завършете редактирането на времевата линия';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel =>
      'Пусни предварителен преглед';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Пауза на прегледа';

  @override
  String get videoEditorAudioUntitledSound => 'Звук без заглавие';

  @override
  String get videoEditorAudioUntitled => 'Без заглавие';

  @override
  String get videoEditorAudioAddAudio => 'Добави аудио';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Няма налични звуци';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Звуците ще се появят тук, когато творците споделят аудио';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Не успяхме да заредим звуците';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Избери аудио сегмента за видеото си';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Общност';

  @override
  String get videoEditorAudioCategoryFeatured => 'Препоръчани';

  @override
  String get videoEditorAudioCategoryMySounds => 'Моите звуци';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Инструмент със стрелка';

  @override
  String get videoEditorDrawToolEraserSemanticLabel =>
      'Инструмент за изтриване';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Инструмент за маркер';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Инструмент молив';

  @override
  String get videoEditorShowTimelineSemanticLabel =>
      'Показване на времевата линия';

  @override
  String get videoEditorHideTimelineSemanticLabel =>
      'Скриване на времевата линия';

  @override
  String get videoEditorFeedPreviewContent =>
      'Избягвайте да поставяте съдържание зад тези области.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Оригинали';

  @override
  String get videoEditorStickerSearchHint => 'Търсене на стикери...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Избери шрифт';

  @override
  String get videoEditorFontUnknown => 'Неизвестен';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Главата за възпроизвеждане трябва да е в рамките на избрания клип, за да се раздели.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Подстригване начало';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Подстригване на края';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel =>
      'Подстригване на клипса';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Плъзни дръжките, за да настроиш дължината на клипа';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Плъзгане на клип $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Клип $index от $total, $duration секунди';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Натисни дълго, за да пренаредиш';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Преместете се наляво';

  @override
  String get videoEditorTimelineClipMoveRight => 'Преместете се надясно';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Клип $index от $total, избран';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Клип $index от $total, неизбран';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Избор';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Избор на няколко клипа';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Завърши избора';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count избрани клипа',
      one: '1 избран клип',
      zero: 'Няма избрани клипове',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Избор на няколко рисунки';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Приключване на избора на рисунки';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Изтриване на избраните рисунки';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count избрани рисунки',
      one: '1 избрана рисунка',
      zero: 'Няма избрани рисунки',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Обедини';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Обединяване на избраните клипове';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Изтриване на избраните клипове';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Изтриване на избраните кадри';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Обръщане на избраните кадри';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Дублиране на избраните кадри';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Видеото трябва да е поне $secondsс — заснеми още няколко кадъра.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Един момент, обединяваме клиповете ти';

  @override
  String get videoEditorMergeFailed =>
      'Клиповете не могат да бъдат обединени. Опитай отново.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Натисни дълго, за да плъзнеш';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Времева линия на видео';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, избрано';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Затворете инструмента за избор на цвят';

  @override
  String get videoEditorPickColorTitle => 'Избери цвят';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Потвърдете цвета';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Наситеност и яркост';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Наситеност $saturation%, яркост $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Нюанс';

  @override
  String get videoEditorAddElementSemanticLabel => 'Добави елемент';

  @override
  String get videoEditorDoneSemanticLabel => 'Готово';

  @override
  String get videoEditorLevelSemanticLabel => 'Ниво';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Затваряне на подробностите за публикацията';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Отхвърляне на диалоговия прозорец за помощ';

  @override
  String get videoMetadataGotItButton => 'Разбрах!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Лимитът от 64 KB е достигнат. Премахни малко съдържание, за да продължиш.';

  @override
  String get videoMetadataExpirationLabel => 'Изтичане';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Избери време на изтичане';

  @override
  String get videoMetadataTitleLabel => 'Заглавие';

  @override
  String get videoMetadataDescriptionLabel => 'Описание';

  @override
  String get videoMetadataTagsLabel => 'Етикети';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Изтриване на маркер $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Предупреждение за съдържание';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Избери предупреждения за съдържание';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Избери всичко, което важи за съдържанието ти';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Позволи на другите да запазват и използват повторно звука на това видео.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Видеото ти е качено, но звукът не се публикува. Редактирай видеото, за да го споделиш.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Сътрудници';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Поканете сътрудник';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Взаимни последователи';

  @override
  String get videoMetadataInspiredByLabel => 'Вдъхновено от';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Комплект, вдъхновен от';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Този творец не може да бъде посочен.';

  @override
  String get videoMetadataPostDetailsTitle => 'Детайли за публикацията';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Запазено в библиотека';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Не успяхме да запазим';

  @override
  String get videoMetadataGoToLibraryButton => 'Отидете в библиотеката';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Бутон за запазване за по-късно';

  @override
  String get videoMetadataSavingVideoHint => 'Видеото се запазва...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Запази видеото в чернови и $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Запази видеото в чернови. Още няма обработено видео, затова няма копие в $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Запазване за по-късно';

  @override
  String get videoMetadataPostSemanticLabel => 'Бутон за публикуване';

  @override
  String get videoMetadataPublishVideoHint => 'Публикувай видео във фийда';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Сподели и в моя поток';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Изключено означава, че това видео остава само в нишката с коментари.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Попълни формата, за да продължиш';

  @override
  String get videoMetadataPostButton => 'Публикувай';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Отвори прегледа на публикацията';

  @override
  String get videoMetadataShareTitle => 'Сподели';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Детайли за видеото';

  @override
  String get videoMetadataClassicDoneButton => 'Готово';

  @override
  String get videoMetadataPlayPreviewSemanticLabel =>
      'Пусни предварителен преглед';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Пауза на прегледа';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Затворете визуализацията на видеото';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Премахни';

  @override
  String get fullscreenFeedRemovedMessage => 'Видеото е премахнато';

  @override
  String get fullscreenFeedEmptyMessage => 'Тук няма какво повече да се пусне';

  @override
  String get settingsBadgesTitle => 'Значки';

  @override
  String get settingsBadgesSubtitle =>
      'Приемай награди и проверявай състоянието на издадени значки.';

  @override
  String get badgesTitle => 'Значки';

  @override
  String get badgesLoadError => 'Значките не се заредиха';

  @override
  String get badgesUpdateError => 'Значката не се актуализира';

  @override
  String get badgesAwardedEmptyTitle => 'Все още няма наградени значки';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Когато някой ти награди Nostr значка, тя ще се появи тук.';

  @override
  String get badgesStatusAccepted => 'Приета';

  @override
  String get badgesStatusNotAccepted => 'Неприета';

  @override
  String get badgesActionRemove => 'Махни';

  @override
  String get badgesActionAccept => 'Приеми';

  @override
  String get badgesActionReject => 'Отхвърли';

  @override
  String get badgesIssuedEmptyTitle => 'Все още няма издадени значки';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Значките, които издаваш, ще показват състоянието на приемане тук.';

  @override
  String get badgesIssuedNoRecipients =>
      'Не са намерени получатели за тази награда.';

  @override
  String get badgesRecipientAcceptedStatus => 'Приета от получателя';

  @override
  String get badgesRecipientWaitingStatus => 'Очаква получателя';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Скрити ($count)',
      one: 'Скрит (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Възстанови';

  @override
  String get badgesHiddenSnackbar => 'Знакът е скрит';

  @override
  String get badgesHiddenSnackbarUndo => 'Отмени';

  @override
  String get badgesTabAwarded => 'Получени';

  @override
  String get badgesTabCreated => 'Създадени';

  @override
  String get badgesTabIssued => 'Раздадени';

  @override
  String get badgesCreateAction => 'Нов знак';

  @override
  String get badgesCreatedEmptyTitle => 'Още нямаш създадени знаци';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Направи един и го дай на някого, който си го заслужава.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Раздаден на $count души',
      one: 'Раздаден на 1 човек',
      zero: 'Още не е раздаден',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Нов знак';

  @override
  String get badgeEditorEditTitle => 'Редактиране на знак';

  @override
  String get badgeEditorNameLabel => 'Име';

  @override
  String get badgeEditorNameHint => 'Крадец на сцената';

  @override
  String get badgeEditorIdentifierLabel => 'Идентификатор';

  @override
  String get badgeEditorIdentifierHelp =>
      'Част е от адреса на знака, затова остава непроменен, щом знакът вече съществува.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Вече имаш знак с този идентификатор. Редактирай онзи — публикуването тук би го заместило.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Всеки знак се нуждае от идентификатор — напиши го сам, ако името не го е попълнило.';

  @override
  String get badgeEditorDescriptionLabel => 'Описание';

  @override
  String get badgeEditorDescriptionHint =>
      'За този, който открадва сцената с един-единствен луп.';

  @override
  String get badgeEditorArtworkLabel => 'Изображение';

  @override
  String get badgeEditorArtworkAdd => 'Добави изображение';

  @override
  String get badgeEditorArtworkReplace => 'Замени';

  @override
  String get badgeEditorArtworkError => 'Изображението не можа да се качи';

  @override
  String get badgeEditorArtworkRequired =>
      'Всеки знак се нуждае от изображение.';

  @override
  String get badgeEditorArtworkRemove => 'Премахни изображението';

  @override
  String get badgeEditorArtworkSheetTitle => 'Изображение на знака';

  @override
  String get badgeDetailDeleteAction => 'Изтрий знака';

  @override
  String get badgeDetailDeleteTitle => 'Да изтрием ли този знак?';

  @override
  String get badgeDetailDeleteBody =>
      'Това моли релетата да премахнат знака и всички раздавания, които си направил. Релетата може да откажат, а който го е закачил, го запазва в профила си, докато сам не го махне.';

  @override
  String get badgeDetailDeleteConfirm => 'Изтрий';

  @override
  String get badgeEditorSaveAction => 'Публикувай знака';

  @override
  String get badgeEditorSaveError => 'Знакът не можа да се публикува';

  @override
  String get badgeEditorLoadError => 'Този знак не можа да се зареди';

  @override
  String get badgeDetailTitle => 'Знак';

  @override
  String get badgeDetailMadeBy => 'Създаден от';

  @override
  String get badgeDetailRecipientsTitle => 'Раздаден на';

  @override
  String get badgeDetailNoRecipients => 'Още никой няма този знак.';

  @override
  String get badgeDetailAwardAction => 'Раздай този знак';

  @override
  String get badgeDetailEditAction => 'Редактиране на знак';

  @override
  String get badgeDetailShareAction => 'Сподели';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Виж този знак в Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Вземи знака обратно';

  @override
  String get badgeDetailRevokeTitle => 'Да вземем ли знака обратно?';

  @override
  String get badgeDetailRevokeBody =>
      'Това моли релетата да премахнат раздаването, което направи на този човек. Релетата може да откажат, а ако вече е закачил знака, той остава в профила му, докато сам не го махне. Така или иначе, никой не му казва.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Това моли релетата да премахнат раздаването, което направи на себе си, и сваля знака от профила ти. Ако релетата откажат изтриването, нищо не се променя.';

  @override
  String get badgeDetailRevokeConfirm => 'Вземи обратно';

  @override
  String get badgeDetailRevokeSuccess => 'Знакът е взет обратно';

  @override
  String get badgeDetailBlockClaimantsAction => 'Блокирай заявилите значката';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Блокирай заявилите значката';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Не можахме да заредим заявилите тази значка';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'В момента никой не заявява тази значка';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Не намерихме текущи заявили за блокиране.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Да блокираме $count акаунта?',
      one: 'Да блокираме 1 акаунт?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Това блокира $count акаунта, които в момента заявяват тази значка. Публикациите им ще излязат от твоите фийдове и няма да получат известие.',
      one:
          'Това блокира акаунта, който в момента заявява тази значка. Публикациите му ще излязат от твоите фийдове и няма да получи известие.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Блокирай $count акаунта',
      one: 'Блокирай 1 акаунт',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'Заявилите значката са блокирани';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Не можахме да блокираме заявилите значката';

  @override
  String get badgeDetailLoadError => 'Този знак не можа да се зареди';

  @override
  String get badgeDetailMissing => 'Не намираме този знак в нито едно реле.';

  @override
  String get badgeDetailActionError => 'Не се получи';

  @override
  String get badgeAwardTitle => 'Раздаване на знак';

  @override
  String get badgeAwardPickAction => 'Избери хора';

  @override
  String get badgeAwardManualLabel => 'Или постави ключове';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Избери поне един човек.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Раздай на $count души',
      one: 'Раздай на 1 човек',
      zero: 'Раздай знак',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Раздаден от';

  @override
  String get profileBadgeRecipients => 'Получатели';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+още $count';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Знак $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Знак';

  @override
  String get profileBadgeFooterBody =>
      'Значките са малки награди, които всеки може да създаде в Nostr. Подари една на приятел, на творец или на някой, който ти е разведрил деня.';

  @override
  String get profileBadgeFooterLink => 'Направи си свой знак';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Наръчник за семейства';

  @override
  String get minorAccountReviewWelcomeTitle => 'Още нямаш 16? Нищо страшно.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Това, че влезе в тази страница, вместо просто да избереш отговора, който щеше да те пусне вътре, има значение. Показва честност, характер и истинска грижа за хората около теб.\n\nПравилата за хората под 16 години са различни в зависимост от това къде живееш. В Divine искаме семействата да го обсъдят заедно и да решат как изглежда здравословната употреба на социални мрежи.';

  @override
  String get minorAccountReviewModerationTitle => 'Нужна е още една стъпка';

  @override
  String get minorAccountReviewModerationBody =>
      'Помолиха ни да разгледаме този профил по-внимателно, защото може да принадлежи на човек под 16. Този процес пази следващите стъпки лични и те насочва към правилния път за твоята възраст.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Правилата не са еднакви навсякъде';

  @override
  String get minorAccountReviewRulesBody =>
      'Различните държави и региони гледат различно на ползването на социални мрежи от тийнейджъри. Затова молим семействата да не бързат, да проверят фактите и да изберат следващата стъпка заедно.';

  @override
  String get minorAccountReviewApproachTitle => 'Как Divine гледа на това';

  @override
  String get minorAccountReviewApproachBody =>
      'Смятаме, че здравословните навици с технологиите идват от спиране, размисъл и насочване на вниманието към по-добри неща, а не от следене на децата или превръщането на родителите в надзиратели. Изследванията го потвърждават.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Още за семейства';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Прочети политиката на Divine за деца';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Избери подходящия път';

  @override
  String get minorAccountReviewUnder13Cta => 'Под 13';

  @override
  String get minorAccountReviewTeenCta => '13–15 години';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Виж наръчника на Divine за семейства с практични съвети, помощ за разговори и ресурси, които помагат на тийнейджърите да ползват социалните мрежи по-безопасно.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Вземи наръчници и съвети за семейства';

  @override
  String get minorAccountReviewFooter =>
      'Ако си на 16 или повече и си попаднал(а) тук по грешка, пиши на поддръжката на Divine, за да го прегледа истински човек.';

  @override
  String get minorAccountReviewTitle => 'Преглед на профила';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Проверяваме състоянието на профила...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Изчакай, докато потвърдим текущото състояние на прегледа на този профил.';

  @override
  String get minorAccountReviewDefaultTitle => 'Нужен е преглед на профила';

  @override
  String get minorAccountReviewDefaultBody =>
      'Трябва да прегледаме този профил, преди да може да ползва Divine нормално.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Номер на случая: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Номер на случая';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'Какво е ограничено в момента';

  @override
  String get minorAccountReviewRestrictionPosting => 'Публикуването е спряно';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Коментарите, харесванията, споделянията и последванията са спрени';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Започването и отговарянето на обикновени съобщения е спряно';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Поддръжката и съобщението от модерацията остават достъпни';

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
  String get minorAccountReviewOpenSupportCenter =>
      'Отвори центъра за поддръжка';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Отвори съобщението от модерацията';

  @override
  String get minorAccountReviewOpenReviewPage => 'Отвори страницата за преглед';

  @override
  String get minorAccountReviewCheckAgain => 'Провери пак';

  @override
  String get minorAccountReviewLogOut => 'Излез';

  @override
  String get minorAccountReviewNextStepTitle => 'Следваща стъпка';

  @override
  String get minorAccountReviewNextStepBody =>
      'Отвори центъра за поддръжка или съобщението от модерацията, ако ти трябва помощ с този преглед.';

  @override
  String get minorAccountReviewInProgressTitle => 'Прегледът е в ход';

  @override
  String get minorAccountReviewInProgressBody =>
      'Засега имаме каквото ни трябва. Екипът ни преглежда случая, преди да върне нормалния достъп до профила.';

  @override
  String get minorAccountReviewUnder13Title => 'Профили под 13 години';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Ако този профил е на човек под 13, родител или настойник трябва да пише на $supportEmail и да посочи номера на случая.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Още не можем да ти дадем профил';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine не е направен за деца под 13, а правилата за социални мрежи по света ни връзват ръцете.\n\nМного неща в интернет те тласкат да излъжеш, за да получиш каквото искаш, и това никак не ни харесва. Това е грешният урок за живота и няма да те учим на него тук.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Какво може да направи семейството ти вместо това';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Родител или настойник може да държи профила и да публикува, а ти спокойно можеш да си във видеата с тях. Искаме семействата да се радват на Divine така, както им е добре.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Когато станеш на 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'В зависимост от правилата там, където живееш, може да се върнеш и да кандидатстваш за собствен профил. Ако тогава си между 13 и 15, ще ти трябва съгласие от родител или настойник.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Защо няма да ти кажем просто да натиснеш „назад“';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Голяма част от интернет е устроен така, че да награждава хората за това, че казват каквото ги преведе през вратата. Не мислим, че това е супер. Да, можеш да се върнеш и да кажеш, че си по-голям, отколкото си, но това не би било честно, а ние няма да те учим да лъжеш, за да получиш каквото искаш.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Опитваме се да помогнем на младите хора да използват Divine по начини, които са здравословни и позитивни за тях и за хората около тях. Освен това трябва да спазваме закони, които са различни на различни места. Така че, ако си под 13 години, отговорът е, че днес не можеш да имаш собствен акаунт.';

  @override
  String get minorAccountReviewTeenBody =>
      'Ако този профил е на човек между 13 и 15, използвай съобщението от модерацията или поддръжката, за да следваш указанията за родителско съгласие.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Ако профилът ще е на човек между 13 и 15';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Родител или настойник трябва да пише на поддръжката на Divine и да прикачи кратко лично видео. Екипът ни ще го прегледа и ще помогне със следващите стъпки.\n\nАко връзка с родител или настойник не е възможна или би изложила някого на риск, пиши на поддръжката на Divine и ни кажи.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Това е пауза, докато екипът на поддръжката на Divine прегледа видеото. Ако бъде одобрено, ще те насочат как да настроиш новия профил.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Защо молим родител или настойник да участва';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine трябва да спазва закони, свързани с възрастта, по целия свят. Знаем също, че повечето технически проверки за възраст са несъвършени. Вместо да се преструваме, че правилата не съществуват или че е готино да лъжеш за възрастта си, искаме тийнейджърите и семействата да вземат обмислени решения как най-добре да използват Divine. Затова за хората на 13-15 години молим родителите да са част от процеса на създаване на акаунт.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Освен това трябва да спазваме закона, а тези правила са различни в зависимост от това къде живее човек. Затова, вместо да се преструваме, че правилата не съществуват, молим родител или настойник да е част от процеса.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Какво трябва да показва видеото';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Тийнейджъра във видеото';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Родител или настойник, който говори пред камерата';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Ясно изявление, че тийнейджърът е между 13 и 15 и има разрешение да ползва Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Ясно изявление, че родителят или настойникът знае за профила и ще наблюдава ползването му';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Как да го изпратиш';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Прикачи видеото към имейла си до поддръжката на Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Пази видеото лично и не го публикувай в приложението';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Екипът ни ще го прегледа и ще отговори със следващите стъпки';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Пиши на поддръжката на Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Помощ за преглед на Divine Greenlight (13–15 години)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Здравейте, поддръжка на Divine,\n\nпиша ви за Divine Greenlight относно тийнейджър на възраст 13–15.\n\nПрикачих кратко лично видео, което показва:\n- тийнейджъра\n- родител или настойник, който говори пред камерата\n- че тийнейджърът има разрешение да ползва Divine\n- че родителят или настойникът знае за профила и ще наблюдава ползването му\n\nДържава/и на пребиваване:\n\nПолезен контекст:\n\nБлагодаря.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Указания за родители';

  @override
  String get minorAccountReviewContinue => 'Продължи';

  @override
  String get minorAccountReviewErrorTitle =>
      'Не успяхме да заредим състоянието на прегледа на профила ти.';

  @override
  String get minorAccountReviewErrorBody => 'Опитай пак след малко.';

  @override
  String get minorAccountReviewTryAgain => 'Опитай пак';

  @override
  String get minorAccountReviewParentContactTitle => 'Контакт с родител';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Добави имейл на родител или настойник';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Ще използваме този адрес за прегледа на родителското съгласие по случай $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Имейл на родител или настойник';

  @override
  String get minorAccountReviewSubmitting => 'Изпращане...';

  @override
  String get minorAccountReviewSubmitEmail => 'Изпрати имейла';

  @override
  String get minorAccountReviewBackToReview =>
      'Обратно към прегледа на профила';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Имейлът е изпратен';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Изпратихме $email за преглед. Ще пишем на този адрес за потвърждение. Щом родителят или настойникът ти отговори, случаят ти ще продължи. Използвай „Провери пак“ от екрана за преглед на профила за новини.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Получихме контакта на родителя или настойника за този профил. Екипът ни ще го прегледа, преди да върне достъпа.';

  @override
  String get minorAccountReviewMissingCase =>
      'Не намерихме активен случай за преглед на този профил.';

  @override
  String get minorAccountReviewParentContactError =>
      'Имейлът на родителя не можа да се изпрати. Опитай пак.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Поддръжка за родители';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Родител или настойник трябва да се свърже с Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'За профили, които вероятно са под 13, следващата стъпка е контакт от родител или настойник по имейл.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Имейл на поддръжката';

  @override
  String get minorAccountReviewCopySupportEmail =>
      'Копирай имейла на поддръжката';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'Имейлът на поддръжката е копиран';

  @override
  String get minorAccountReviewCopyCaseId => 'Копирай номера на случая';

  @override
  String get minorAccountReviewCaseIdCopied => 'Номерът на случая е копиран';

  @override
  String get minorAccountReviewUnavailable => 'Недостъпно';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Помоли родителя или настойника да посочи номера на случая и да обясни, че се свързва с Divine относно този преглед на профила.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Преглед на профил под 13 години по случай $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Здравейте, поддръжка на Divine,\n\nаз съм родител или настойник на дете под 13 и се свързвам с Divine относно случай за преглед на профил $caseId.\n\nБлагодаря.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Симулация на преглед на профил на непълнолетен';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Текущо състояние';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Ограничен ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Активен';

  @override
  String get devOptionsMinorReviewStateLoading => 'Зареждане...';

  @override
  String get devOptionsMinorReviewStateError =>
      'Грешка при зареждане на състоянието';

  @override
  String get devOptionsMinorReviewClearTitle => 'Изчисти симулацията';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Използвай пак бекенда или активното състояние по подразбиране';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      'Симулирай случай за преглед 13–15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Ограничен профил с път за контакт с родител';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Симулирай случай за поддръжка под 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Ограничен профил с указания само за имейл до родител';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Симулацията на преглед на профил на непълнолетен е изчистена';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Симулираният случай за поддръжка под 13 е включен';

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
      'Симулация на защитен непълнолетен';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Текущо състояние';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Защитен непълнолетен (13–15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Незащитен';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Зареждане…';

  @override
  String get devOptionsProtectedMinorStateError =>
      'Грешка при четене на състоянието';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Без замяна (реално състояние на профила)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Замяна: наложен защитен';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Замяна: наложен незащитен';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Симулирай защитен непълнолетен (13–15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Наложи състоянието „защитен непълнолетен“, за да тестваш защитите #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Симулирай пълнолетен';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Наложи незащитен (изрично „не“, различно от липса на замяна)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Изчисти замяната';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Върни се към реалното състояние на профила от Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Състоянието „защитен непълнолетен“ е наложено';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Състоянието „защитен непълнолетен“ е изключено';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Замяната „защитен непълнолетен“ е изчистена';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Покани за регистрация';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Текущо състояние';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Стойност от сървъра: зарежда се';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Стойност от сървъра: включено';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Стойност от сървъра: изключено';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Стойност от сървъра: неизвестна';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Замяна: използвай стойността от сървъра';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Замяна: наложено включено';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Замяна: наложено изключено';

  @override
  String get devOptionsInviteAvailabilityUseServer =>
      'Използвай стойността от сървъра';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Следвай onboardingMode на услугата за покани';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Наложи включено';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Показвай локално ограниченията и управлението на поканите';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Наложи изключено';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Скрий локално интерфейса за покани, без да променяш сървъра';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Поканите за регистрация вече следват сървъра';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Поканите за регистрация са наложено включени';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Поканите за регистрация са наложено изключени';

  @override
  String get commentsRecordVideoButtonLabel => 'Запис на видео коментар';

  @override
  String get commentsOpenVideoLabel => 'Отвори видео коментара';

  @override
  String get commentsMuteVideoReplyLabel => 'Заглуши видео отговора';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Пусни звука на видео отговора';

  @override
  String get commentsOpenReplyParentLabel =>
      'Отвори видеото, към което е този отговор';

  @override
  String get commentsReplyParentSectionTitle => 'В отговор на';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Отговор на $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Отговор на видео';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Потвърден акаунт в $platform: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Потвърдени акаунти';

  @override
  String get profileEditGetVerifiedCta => 'Потвърди се';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Свържи социалните си мрежи, за да знаят хората, че това си наистина ти.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Отвори уебсайта: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Уебсайтът не можа да се отвори';

  @override
  String get videoMetadataEditCoverTitle => 'Редактирай корицата';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Отхвърляне на промените по корицата';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Използване на избрания кадър като корица на видеото';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Превърти видеото, за да избереш кадър за корица';

  @override
  String get videoMetadataTagsPickerSearchHint =>
      'Търсене или добавяне на тагове';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Добавете тагове, за да открият хората вашето видео';

  @override
  String get videoMetadataTagsPickerNoResults => 'Няма съвпадащи тагове';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Добавяне на „#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Още нямаш 16? Няма проблем. ';

  @override
  String get authUnder16ChoicesCta => 'Ето какви са възможностите ти.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Ето защо';

  @override
  String get generalSettingsHoldToRecord => 'Задръжте за запис';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Записът започва при задържане и спира при отпускане';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count видеа са публикувани в профила ти',
      one: 'Видеото е публикувано в профила ти',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Изпрати съобщение';

  @override
  String get emojiPickerSearchHint => 'Търсене';

  @override
  String get emojiCategoryRecent => 'Скорошни';

  @override
  String get emojiCategorySmileys => 'Емотикони и хора';

  @override
  String get emojiCategoryAnimals => 'Животни и природа';

  @override
  String get emojiCategoryFood => 'Храна и напитки';

  @override
  String get emojiCategoryActivities => 'Дейности';

  @override
  String get emojiCategoryTravel => 'Пътувания и места';

  @override
  String get emojiCategoryObjects => 'Обекти';

  @override
  String get emojiCategorySymbols => 'Символи';

  @override
  String get emojiCategoryFlags => 'Знамена';

  @override
  String get videoEditorMarkerLabel => 'Маркер';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Добавяне на маркер в хронологията';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Премахване на маркер от хронологията';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Премахване на маркера при плейхеда';

  @override
  String get videoEditorDeleteTimelineMarkerTitle =>
      'Да се изтрие ли маркерът?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Това премахва маркера от хронологията. Редакцията ви остава непроменена.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Заглуши или включи всички писти';

  @override
  String get videoEditorSplitFailed =>
      'Разделянето не бе успешно. Моля, опитайте отново.';

  @override
  String get videoEditEditSubtitles => 'Редактирай субтитрите';

  @override
  String get subtitleEditorTitle => 'Редактирай субтитрите';

  @override
  String get subtitleEditorSave => 'Запази';

  @override
  String get subtitleEditorProcessing =>
      'Субтитрите все още се генерират. Върни се след малко.';

  @override
  String get subtitleEditorNoSpeech =>
      'В това видео не е открита реч, така че няма какво да се субтитрира.';

  @override
  String get subtitleEditorWriteOwn => 'Напиши ги сам';

  @override
  String get subtitleEditorAddCue => 'Добави ред';

  @override
  String get subtitleEditorRemoveCue => 'Премахни този ред';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Видеото не може да се пусне в момента, но пак можеш да оправиш субтитрите.';

  @override
  String get subtitleEditorPlayPreview => 'Пусни видеото';

  @override
  String get subtitleEditorPausePreview => 'Спри видеото';

  @override
  String get subtitleEditorInvalidHint =>
      'Всеки ред се нуждае от текст и край след началото си.';

  @override
  String get subtitleEditorLoadError =>
      'Субтитрите не можаха да се заредят. Опитай пак.';

  @override
  String get subtitleEditorSaveSuccess => 'Субтитрите са обновени';

  @override
  String get subtitleEditorSaveError =>
      'Субтитрите не можаха да се запазят. Опитай пак.';

  @override
  String get subtitleEditorRetry => 'Опитай пак';

  @override
  String get subtitleEditorCueHint => 'Текст на надписа';

  @override
  String get imageCropEditorRotateLabel => 'Завъртане';

  @override
  String get imageCropEditorFlipLabel => 'Обръщане';

  @override
  String get imageCropEditorResetLabel => 'Нулиране';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Отказ от изрязването';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Прилагане на изрязването';

  @override
  String get imageCropEditorProcessing => 'Прилагане на изрязването…';

  @override
  String get backgroundUploadNotificationTitle => 'Качване на видео';

  @override
  String get monetizationSettingsTitle => 'Подкрепа за творци';

  @override
  String get monetizationSettingsSubtitle =>
      'Добави връзки за бакшиш и абонамент';

  @override
  String get monetizationSettingsIntroTitle => 'Само външни връзки';

  @override
  String get monetizationSettingsIntroBody =>
      'Добави места, които ти контролираш. Divine никога не обработва плащането и не отключва съдържание в приложението чрез тези връзки.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count активни връзки в профила ти',
      one: '1 активна връзка в профила ти',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Изпрати бакшиш';

  @override
  String get monetizationSettingsSubscriptionSection =>
      'Абонирай се / подкрепи';

  @override
  String get monetizationSettingsSave => 'Запази връзките за подкрепа';

  @override
  String get monetizationSettingsSaving => 'Запазване...';

  @override
  String get monetizationSettingsSaved => 'Връзките за подкрепа са обновени';

  @override
  String get monetizationSettingsSaveFailed =>
      'Връзките за подкрепа не можаха да се запазят. Провери връзката си и опитай пак.';

  @override
  String get monetizationSettingsErrorEmpty => 'Добави хендъл или URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Тази връзка не изглежда правилна.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Използвай връзка за този доставчик.';

  @override
  String get monetizationSettingsHintCashApp =>
      '\$cashtag или връзка към cash.app';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me хендъл или връзка';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo хендъл или връзка';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon хендъл или връзка';

  @override
  String get monetizationSettingsHintSubstack => 'Substack домейн или връзка';

  @override
  String get monetizationSettingsHintMedium => 'Medium хендъл или връзка';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective слъг или връзка';

  @override
  String get profileSupportSheetTitle => 'Подкрепи този творец';

  @override
  String get profileSupportSheetBody =>
      'Тези връзки се отварят извън Divine. Нищо тук не отключва съдържание в приложението.';

  @override
  String get profileSupportTipSection => 'Изпрати бакшиш';

  @override
  String get profileSupportSubscriptionSection => 'Абонирай се / подкрепи';

  @override
  String get profileSupportButtonLabel => 'Подкрепи';

  @override
  String get monetizationTipsSettingsTitle => 'Бакшиши';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Добави незадължителни връзки за бакшиш';

  @override
  String get monetizationTipsSettingsIntroTitle =>
      'Само незадължителни бакшиши';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Бакшишите са незадължителни подаръци между хора. Те не отключват съдържание, абонаменти, функции, класиране, видимост или достъп в Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count активни връзки за бакшиш в профила ти',
      one: '1 активна връзка за бакшиш в профила ти',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Запази връзките за бакшиш';

  @override
  String get monetizationTipsSettingsSaved => 'Връзките за бакшиш са обновени';

  @override
  String get profileTipButtonLabel => 'Бакшиш';

  @override
  String get profileTipSheetTitle => 'Дай бакшиш на този творец';

  @override
  String get profileTipSheetBody =>
      'Връзките за бакшиш се отварят извън Divine. Бакшишът е незадължителен и не отключва съдържание, абонаменти, функции или достъп в Divine.';

  @override
  String get settingsStorageTitle => 'Хранилище';

  @override
  String get settingsStorageCacheSectionTitle =>
      'Кеширани мултимедийни файлове';

  @override
  String get settingsStorageCacheDescription =>
      'Кеширани видеа от емисията, миниатюри и временни рендери. Изчистването им е безопасно – изтеглят се или се генерират отново при нужда.';

  @override
  String get settingsStorageMeasuring => 'Изчисляване…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size се използват';
  }

  @override
  String get settingsStorageClearButton => 'Изчисти кеша';

  @override
  String get settingsStorageClearConfirmTitle =>
      'Да се изчистят ли кешираните файлове?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Това освобождава $size. Библиотеката ви с клипове не се засяга.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Изчисти';

  @override
  String get settingsStorageCleared => 'Кешът е изчистен';

  @override
  String get settingsStorageLibrarySectionTitle => 'Библиотека с клипове';

  @override
  String get settingsStorageLibraryDescription =>
      'Проверете за повредени клипове, чийто видеофайл липсва.';

  @override
  String get settingsStorageScanButton => 'Провери библиотеката';

  @override
  String get settingsStorageLibraryHealthy =>
      'Не са намерени повредени клипове';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Намерени повредени клипове: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton =>
      'Премахни повредените клипове';

  @override
  String get settingsStorageBrokenClipsRemoved =>
      'Повредените клипове са премахнати';

  @override
  String get settingsStorageError => 'Нещо се обърка';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Максимален кеш за видео';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count видеа';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Премахване на повредените клипове?';

  @override
  String get settingsStorageRepairSectionTitle => 'Поправяне на инсталацията';

  @override
  String get settingsStorageRepairDescription =>
      'Ако приложението постоянно се срива или се държи странно, нулирането на локалните данни обикновено помага. Клиповете и черновите ти остават.';

  @override
  String get settingsStorageRepairButton => 'Нулиране на данните';

  @override
  String get settingsStorageRepairConfirmTitle => 'Да нулираме ли данните?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Това изчиства кешираните данни от емисията и временните файлове. Клиповете, черновите, настройките и профилът ти остават, но след това ще трябва да рестартираш приложението.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return 'Ще бъдат изтрити $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Нулирай';

  @override
  String get settingsStorageRepairInProgress => 'Нулиране…';

  @override
  String get settingsStorageRepairSuccess =>
      'Готово — рестартирай приложението, за да приключиш.';

  @override
  String get settingsStorageRepairFailure =>
      'Не всичко можа да се нулира. Опитай пак след рестарт.';

  @override
  String get nostrSettingsSignatureVerification => 'Проверка на подпис';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Избери кога Divine проверява подписите на събитията от релеите. ID-тата на събитията винаги се валидират първо.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Всички релеи';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Най-сигурно. Проверявай подписа на всяко събитие от всеки релей.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => 'Недоверени релеи';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Пропускай проверките за релеи, които вече са в конфигурирания ти пул.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Релеи извън Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Довери се на релеите на Divine, проверявай останалите.';

  @override
  String get settingsCrosspostingTitle => 'Кръстосано публикуване';

  @override
  String get settingsCrosspostingSubtitle =>
      'Споделяй видеата си в други платформи';

  @override
  String get crosspostingSignInRequired =>
      'Влез с Divine, за да управляваш кръстосаното публикуване';

  @override
  String get crosspostingLoadFailed =>
      'Настройките ти за кръстосано публикуване не се заредиха';

  @override
  String get crosspostingNoPlatforms =>
      'В момента няма налични платформи за кръстосано публикуване';

  @override
  String get crosspostingRetry => 'Опитай пак';

  @override
  String get crosspostingNotConnected => 'Няма връзка';

  @override
  String get crosspostingConnected => 'Свързано';

  @override
  String get crosspostingNeedsReconnect => 'Трябва да се свърже отново';

  @override
  String get crosspostingConnect => 'Свържи';

  @override
  String get crosspostingReconnect => 'Свържи отново';

  @override
  String get crosspostingDisconnect => 'Прекъсни';

  @override
  String get crosspostingModeOff => 'Изкл.';

  @override
  String get crosspostingModeManual => 'Ръчно';

  @override
  String get crosspostingModeManualSubtitle => 'Ти избираш за всяко видео';

  @override
  String get crosspostingModeAutomatic => 'Автоматично';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Следващите видеа се публикуват сами — само тези, които публикуваш след като включиш това';

  @override
  String get crosspostingNotConnectedError =>
      'Първо свържи тази платформа, за да промениш как публикува.';

  @override
  String get crosspostingGenericError => 'Нещо се обърка. Опитай пак.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Страницата за вход така и не отговори. Ако си приключил там, презареди — акаунтът ти може вече да е свързан.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform е свързана';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return '$platform не можа да се свърже';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Свързването беше отменено в $platform';
  }

  @override
  String get supporterTitle => 'Поддръжници на Divine';

  @override
  String get supporterTileSubtitle =>
      'Подкрепи Divine с незадължителен месечен абонамент.';

  @override
  String get supporterHeroTitle => 'Помогни на Divine да продължава';

  @override
  String get supporterHeroBody =>
      'Divine е безплатен и винаги ще бъде. Ако искаш да ни помогнеш да поддържаме луповете, стани месечен поддръжник. Нищо не е заключено — просто държиш лампите запалени и печелиш благодарността ни.';

  @override
  String get supporterActiveBadge =>
      'Ти си поддръжник на Divine. Благодарим ти, че караш това да продължава.';

  @override
  String get supporterPurchasePending => 'Покупката ти чака одобрение.';

  @override
  String get supporterPurchaseConfirming => 'Потвърждаваме подкрепата ти…';

  @override
  String get supporterStoreChecking => 'Проверяваме магазина…';

  @override
  String get supporterUnavailable =>
      'Абонаментите за поддръжници не са налични тук в момента.';

  @override
  String get supporterRestorePurchases => 'Възстанови покупките';

  @override
  String get supporterDismissError => 'Отхвърли грешката';

  @override
  String get supporterErrorStoreUnavailable =>
      'Магазинът не е наличен на това устройство.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Покупката не завърши. Не ти е начислено нищо.';

  @override
  String get supporterErrorPurchasePending => 'Покупката ти чака одобрение.';

  @override
  String get supporterErrorRestoreFailed =>
      'Не е намерен абонамент на поддръжник за възстановяване.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Тази покупка принадлежи на друг Divine акаунт.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine не можа да потвърди статуса на поддръжник в момента.';

  @override
  String get supporterErrorUnknown => 'Нещо се обърка. Опитай пак.';

  @override
  String get supporterDisclaimer =>
      'Divine потвърждава статуса на поддръжник, след като магазинът провери покупката ти. Признанието е по желание, а ореолът не е потвърждение.';

  @override
  String get profileNotifyBellOff => 'Получавай известия за нови видеа';

  @override
  String get profileNotifyBellOn => 'Спри известията за нови видеа';

  @override
  String get profileNotifyUpdateFailed => 'Не се запази. Опитай пак?';

  @override
  String get savedSoundYourLabel => 'Твоят етикет';

  @override
  String get savedSoundAddHashtags => 'Добави хаштагове';

  @override
  String get savedSoundDeviceOnly => 'Запазено на това устройство';

  @override
  String get savedSoundDetailsRetry =>
      'Тези данни не можаха да се запазят. Докосни за нов опит.';

  @override
  String get savedSoundFallbackTitle => 'Запазен звук';

  @override
  String get savedSoundPreviewAction => 'Чуй звука';

  @override
  String get savedSoundEditAction => 'Редактирай данните за звука';

  @override
  String get savedSoundRemoveAction => 'Премахни запазения звук';

  @override
  String get savedSoundClearHashtagFilter => 'Изчисти филтъра по хаштаг';

  @override
  String get soundAllowRemix => 'Позволи на другите да ремиксират този звук';

  @override
  String get soundReuseUnavailable =>
      'Този звук не може да се ремиксира в момента.';

  @override
  String get soundPublicCredit => 'Публичен кредит за звука';

  @override
  String get soundCreditRequired =>
      'Добави публичен кредит за звука, преди да публикуваш.';

  @override
  String get soundSharedAs => 'Споделено като';

  @override
  String get soundOwnWork => 'Аз създадох този звук';

  @override
  String soundCreatorBy(String creator) {
    return 'От $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Споделено от $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Ремиксирането е позволено';

  @override
  String get soundCreditOnly => 'Само кредит';

  @override
  String get soundCreditTitleLabel => 'Заглавие на звука';

  @override
  String get soundCreditCreatorLabel => 'Създател';

  @override
  String get soundCreditSourceUrlLabel => 'URL на източника';

  @override
  String get soundCreditPublicHashtagsLabel => 'Публични хаштагове';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Отказ от избора на тагове';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Прилагане на избраните тагове';

  @override
  String get userPickerCancelSemanticLabel => 'Отказ от избора на потребители';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Потвърждаване на избраните потребители';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Изчистване на избора на потребители';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Отказ от избора на предупреждения за съдържание';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Прилагане на избраните предупреждения за съдържание';

  @override
  String get videoEditorCloseEditorSemanticLabel =>
      'Затваряне на видео редактора';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Продължаване към подробностите за публикацията';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Отхвърляне на промените в $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Прилагане на промените в $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Премахване на аудиото';

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
  String get verifyTitle => 'Потвърдени профили';

  @override
  String get verifySignedOutMessage => 'Влез, за да свържеш профилите си.';

  @override
  String get verifyIntro =>
      'Свържи профилите, които вече имаш, за да се вижда, че наистина си ти.';

  @override
  String get verifyLoadFailed => 'Връзките ти не можаха да се заредят.';

  @override
  String get verifyRetry => 'Опитай пак';

  @override
  String get verifyLinkedSectionTitle => 'Свързани';

  @override
  String get verifyVerifierUnreachable =>
      'Проверяващият не отговори, затова всичко излиза като непроверено.';

  @override
  String get verifyAddSectionTitle => 'Добави профил';

  @override
  String get verifyAllPlatformsLinked => 'Свърза всичко, което поддържаме.';

  @override
  String get verifyStatusVerified => 'Потвърден';

  @override
  String get verifyStatusUnverified => 'Непотвърден';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Премахни връзката с профила $identity в $platform';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Да премахнем ли връзката с $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity вече няма да се показва в профила ти. Можеш да го свържеш пак по-късно, но ще трябва да влезеш отново или да публикуваш нов линк за потвърждение.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Премахни връзката';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Свържи профила си в $platform';
  }

  @override
  String get verifyOneTapBadge => 'Едно докосване';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Влез в $platform и ние поемаме останалото. Нищо не се публикува.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Продължи с $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Или публикувай доказателство';

  @override
  String get verifyConnectProofExplainer =>
      'Публикувай своя npub в профила си и после постави линка към публикацията.';

  @override
  String get verifyNpubLabel => 'Твоят npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Копирай своя npub';

  @override
  String get verifyNpubCopied => 'npub копиран';

  @override
  String get verifyIdentityLabel => 'Име на профила';

  @override
  String get verifyProofLabel => 'Линк към публикацията ти';

  @override
  String get verifyConnectProofCta => 'Провери и свържи';

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
      'Проверяващият не отговаря. Опитай пак след малко.';

  @override
  String get verifyErrorOauthFailed => 'Не се получи. Пробвай отново.';

  @override
  String get verifyErrorHandleRequired => 'Първо въведи своя handle.';

  @override
  String get verifyErrorPublishFailed =>
      'Потвърдено, но нито едно реле не прие промяната. Опитай пак.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Влизането с едно докосване още не е настроено тук. Използвай доказателството по-долу.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Направи публичен gist с твоя npub в първия файл и постави линка към gist-а.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Публикувай своя npub в Discord канал, който нашият бот може да чете, и постави линка към съобщението. Покана за сървър не доказва нищо.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Публикувай своя npub от този профил и постави линка към туита.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Публикувай своя npub от този профил и постави линка. Името на профила трябва да включва инстанцията — mastodon.social/@alice, не само alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Свързва се каналът, не твоят профил в Telegram. Първо му трябва публичен линк (Telegram създава новите като частни). Публикувай там своя npub и постави линка към съобщението.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Влезе ли горе? Тогава нищо повече. Иначе публикувай своя npub и постави линка към публикацията.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Сложи своя npub в описанието на видео и постави линка към това видео.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Сложи своя npub в описанието на видео и постави линка към това видео.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform е свързан.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Това е частен канал или покана. Дай на канала публичен линк и после постави линка към съобщението.';

  @override
  String get verifyErrorRemoveFailed =>
      'Връзката не можа да се премахне. Опитай пак.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Не успяхме да прочетем текущите ти връзки, затова нищо не е променено. Провери връзката си и опитай пак.';

  @override
  String get verifyChannelLabel => 'Име на канала';

  @override
  String get verifyHowItWorksTitle => 'Как работи?';

  @override
  String get verifyHowItWorksIntro =>
      'Представи си го като ръкостискане между два профила:';

  @override
  String get verifyHowItWorksYourSide =>
      'Твоят Divine профил казва: „Аз съм @alice в Twitter“.';

  @override
  String get verifyHowItWorksOtherSide =>
      'Твоят Twitter профил потвърждава: „Да, този Divine профил е мой“.';

  @override
  String get verifyHowItWorksBothSides =>
      'Проверяваме и двете страни. Съвпаднат ли, си потвърден. Не може да се подправи — име и снимка се копират, публикуване от истинския ти профил не.';

  @override
  String get verifyHowItWorksOwnership =>
      'Връзките стоят в твоята собствена Nostr идентичност, така че можеш да ги махнеш оттук когато поискаш.';

  @override
  String get generalSettingsSectionIdentity => 'Самоличност';

  @override
  String get libraryFilterAll => 'Всички';

  @override
  String get libraryFilterArchive => 'Архив';

  @override
  String get libraryFilterDeleted => 'Изтрити';

  @override
  String get libraryCategoryNewChipLabel => 'Нова';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Създаване на категория';

  @override
  String get libraryCategoryCreateTitle => 'Нова категория';

  @override
  String get libraryCategoryCreateAction => 'Създай';

  @override
  String get libraryCategoryRenameTitle => 'Преименуване на категорията';

  @override
  String get libraryCategoryRenameAction => 'Преименувай';

  @override
  String get libraryCategoryDeleteAction => 'Изтриване на категорията';

  @override
  String get libraryCategoryNameLabel => 'Име на категорията';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Да изтрием ли „$name“?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Клиповете ти остават. Просто се връщат във „Всички“.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Преименуване или изтриване на тази категория';

  @override
  String get libraryCategoryMoveTitle => 'Преместване в';

  @override
  String get libraryCategoryMoveNone => 'Без категория';

  @override
  String get libraryCategoryMoveNewCategory => 'Нова категория';

  @override
  String get libraryArchiveAction => 'Архивирай';

  @override
  String get libraryUnarchiveAction => 'Извади от архива';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Оставяне в тези категории?',
      one: 'Оставяне в тази категория?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Остави в $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'Остави в категориите им';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Премахни от $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Премахни от категориите им';

  @override
  String get libraryMoveSelectedClipsTooltip =>
      'Преместване на избраните клипове';

  @override
  String get libraryCategoryEmptyTitle => 'Тук още няма нищо';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Избери няколко клипа и ги премести в тази категория.';

  @override
  String get libraryArchiveEmptyTitle => 'Нищо в архива';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Архивираните клипове чакат тук, извън основната ти библиотека.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа са преместени в $name',
      one: '1 клип е преместен в $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа са извън категорията си',
      one: '1 клип е извън категорията си',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа са архивирани',
      one: '1 клип е архивиран',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа се върнаха в библиотеката',
      one: '1 клип се върна в библиотеката',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Смяна на имейла';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Премести акаунта си на друг адрес';

  @override
  String get accountSettingsChangePassword => 'Смяна на паролата';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Избери нова парола за вход';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Сесията ти изтече. Влез отново, за да направиш промяната.';

  @override
  String get accountCredentialsRateLimited =>
      'Твърде много опити. Изчакай няколко минути.';

  @override
  String get accountCredentialsNetwork =>
      'Не успяхме да стигнем до Divine. Провери връзката и опитай пак.';

  @override
  String get accountCredentialsUnknown => 'Не се получи. Опитай пак.';

  @override
  String get changePasswordSubtitle =>
      'Въведи текущата си парола и избери нова.';

  @override
  String get changePasswordCurrentLabel => 'Текуща парола';

  @override
  String get changePasswordWrongCurrent => 'Това не е текущата ти парола.';

  @override
  String get changePasswordSuccess => 'Паролата е сменена.';

  @override
  String get changeEmailSubtitle =>
      'Ще изпратим линк за потвърждение на новия адрес и на този в акаунта ти. Имейлът се сменя, след като потвърдиш и от двата.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'В акаунта ти: $email';
  }

  @override
  String get changeEmailNewLabel => 'Нов имейл';

  @override
  String get changeEmailPasswordLabel => 'Твоята парола';

  @override
  String get changeEmailSameAsCurrent => 'Това вече е твоят имейл адрес.';

  @override
  String get changeEmailWrongPassword => 'Това не е твоята парола.';

  @override
  String get changeEmailSubmit => 'Изпрати линковете за потвърждение';

  @override
  String get changeEmailSentTitle => 'Два линка са на път';

  @override
  String changeEmailSentMessage(String email) {
    return 'Потвърди от $email и от адреса в акаунта ти. Имейлът се сменя, щом направиш и двете.';
  }

  @override
  String get changeEmailSentExpiry =>
      'Линковете спират да работят след 24 часа.';

  @override
  String get changeEmailSentDone => 'Ясно';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount видеа',
      one: '$formattedCount видео',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Взаимно';

  @override
  String get socialProofFollowsYou => 'Следва те';

  @override
  String get socialProofYouFollow => 'Следваш';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount последователи',
      one: '$formattedCount последовател',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Видеата не се зареждат в момента.\nПроблемът е от нас и вече го оправяме.';

  @override
  String get feedOfflineMessage =>
      'Няма връзка с интернет.\nПровери връзката си и опитай пак.';

  @override
  String get dbFailureTitle => 'локалната база данни не може да се отключи';

  @override
  String get dbFailureAdviceResettable =>
      'Рестартирането няма да помогне. Нулирането на локалната база данни по-долу дава на Divine чист старт — акаунтът ти остава.';

  @override
  String get dbFailureAdviceRestart =>
      'Рестартирай Divine, след като отключиш устройството си. Ако това продължава, обнови приложението или се свържи с поддръжката.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Опитайте да рестартирате Divine веднъж. Ако това продължи, актуализирайте приложението или се свържете с поддръжката. Локалните ви данни все още са тук.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Диагностика: $code';
  }

  @override
  String get dbFailureCloseApp => 'затвори Divine';

  @override
  String get dbFailureResetAction => 'нулирай локалната база данни';

  @override
  String get dbFailureConfirmTitle => 'да нулираме ли локалната база данни?';

  @override
  String get dbFailureConfirmBody =>
      'Акаунтът ти остава. Черновите и клиповете, запазени на това устройство, се изтриват — съобщенията и емисиите се връщат от мрежата.';

  @override
  String get dbFailureResetConfirm => 'нулирай локалната база данни сега';

  @override
  String get dbFailureCancel => 'отказ';

  @override
  String get dbFailureResetFailed =>
      'Това не сработи. Затвори Divine и опитай отново.';

  @override
  String get dbFailureResetDoneTitle => 'локалната база данни е нулирана';

  @override
  String get dbFailureResetDoneBody =>
      'Затвори Divine и го отвори отново — следващото стартиране изгражда нова локална база данни.';

  @override
  String get authSignInOptionsInfo => 'Относно опциите за вход';

  @override
  String get authShowPassword => 'Показване на паролата';

  @override
  String get authHidePassword => 'Скриване на паролата';

  @override
  String get followUserSemanticLabel => 'Последвай потребителя';

  @override
  String get unfollowUserSemanticLabel => 'Спри да следваш потребителя';

  @override
  String get commentsLoadingSemanticLabel => 'Зареждане на коментарите';

  @override
  String get analyticsWindowAll => 'Всички';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Последвай потребителя $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Спри да следваш потребителя $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / месец';
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
  String get updateGentleBanner => 'Излезе нова актуализация. Вижте я →';

  @override
  String get updateModerateTitle =>
      'Има актуализация от последната ви проверка';

  @override
  String get updateUrgentTitle => 'Пропускате важни поправки';

  @override
  String get updateNotNow => 'Не сега';

  @override
  String get updateAction => 'Актуализиране';

  @override
  String updateNewIn(String version) {
    return 'Ново във версия $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Налична е актуализация';
}

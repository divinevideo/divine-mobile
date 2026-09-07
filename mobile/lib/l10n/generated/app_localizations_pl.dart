// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Odzyskiwanie klipów';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Znajduje nagrania zapisane na innym koncie oraz pliki wideo, do których nie odwołuje się już żaden wpis.';

  @override
  String get devOptionsClipRecoveryScan => 'Skanuj';

  @override
  String get devOptionsClipRecoveryFailure =>
      'Odzyskiwanie klipów nie udało się';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips klipów',
      few: '$clips klipy',
      one: '$clips klip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts wersji roboczych',
      few: '$drafts wersje robocze',
      one: '$drafts wersja robocza',
    );
    return 'Widoczne teraz: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Ukryte na innych kontach';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips klipów',
      few: '$clips klipy',
      one: '$clips klip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts wersji roboczych',
      few: '$drafts wersje robocze',
      one: '$drafts wersja robocza',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Przenieś na to konto';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Pliki bez odwołań: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Odtwórz w bibliotece';

  @override
  String get devOptionsClipRecoveryEmpty => 'Nie ma czego odzyskiwać';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odzyskano $count klipów',
      few: 'Odzyskano $count klipy',
      one: 'Odzyskano $count klip',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Skopiowano raport odzyskiwania';

  @override
  String get devOptionsStorageFootprint => 'Zajętość pamięci';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Każdy katalog, do którego zapisuje aplikacja. Czyszczenie pamięci podręcznej zwalnia tylko część.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Zmierz';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Łącznie: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Skopiowano raport pamięci';

  @override
  String get devOptionsStorageFootprintFailure =>
      'Nie udało się zmierzyć pamięci';

  @override
  String get feedTuningMoreLabel => 'Więcej takich';

  @override
  String get feedTuningLessLabel => 'Mniej takich';

  @override
  String get feedTuningUndo => 'Cofnij';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Otwórz przywołane wideo';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsSecureAccount => 'Zabezpiecz konto';

  @override
  String get settingsSessionExpired => 'Sesja wygasła';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Zaloguj się ponownie, żeby odzyskać pełny dostęp';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Statystyki twórcy';

  @override
  String get settingsSupportCenter => 'Centrum pomocy';

  @override
  String get settingsNotifications => 'Powiadomienia';

  @override
  String get settingsBlueskyPublishing => 'Publikowanie na Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Zarządzaj crosspostingiem na Bluesky';

  @override
  String get settingsNostrSettings => 'Ustawienia Nostr';

  @override
  String get settingsIntegratedApps => 'Zintegrowane aplikacje';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Zatwierdzone aplikacje innych firm działające wewnątrz Divine';

  @override
  String get settingsExperimentalFeatures => 'Funkcje eksperymentalne';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Nowinki, które mogą czkać—wypróbuj je, jeśli jesteś ciekawski.';

  @override
  String get settingsLegal => 'Informacje prawne';

  @override
  String get settingsIntegrationPermissions => 'Uprawnienia integracji';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Przejrzyj i cofnij zapamiętane zgody na integracje';

  @override
  String settingsVersion(String version) {
    return 'Wersja $version';
  }

  @override
  String get settingsVersionEmpty => 'Wersja';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Tryb dewelopera jest już włączony';

  @override
  String get settingsDeveloperModeEnabled => 'Tryb dewelopera włączony!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jeszcze $count dotknięcia, żeby włączyć tryb dewelopera',
      many: 'Jeszcze $count dotknięć, żeby włączyć tryb dewelopera',
      few: 'Jeszcze $count dotknięcia, żeby włączyć tryb dewelopera',
      one: 'Jeszcze 1 dotknięcie, żeby włączyć tryb dewelopera',
    );
    return '$_temp0';
  }

  @override
  String get settingsShareDivine => 'Udostępnij Divine znajomym';

  @override
  String get settingsSwitchAccount => 'Przełącz konto';

  @override
  String get settingsAddAnotherAccount => 'Dodaj kolejne konto';

  @override
  String get settingsAccountSwitchFailed =>
      'Nie udało się przełączyć kont. Spróbuj ponownie.';

  @override
  String get settingsUnsavedDraftsTitle => 'Niezapisane wersje robocze';

  @override
  String get settingsUploadInProgressTitle => 'Trwa przesyłanie';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'filmu',
      many: 'filmów',
      few: 'filmy',
      one: 'film',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'filmy zostaną zapisane jako szkice',
      one: 'film zostanie zapisany jako szkic',
    );
    return 'Masz jeszcze $count $_temp0 w trakcie przesyłania. Zmiana konta przerwie przesyłanie — $_temp1 na tym koncie.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'wersji roboczych',
      one: 'wersji roboczej',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'je',
      one: 'ją',
    );
    return 'Masz $count niezapisanych $_temp0. Przełączenie kont zachowa $_temp1, ale możesz chcieć je najpierw opublikować lub przejrzeć.';
  }

  @override
  String get settingsCancel => 'Anuluj';

  @override
  String get settingsSwitchAnyway => 'Przełącz mimo to';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Sesja tego konta wygasła. Ponowne zalogowanie się do niego oznacza wylogowanie z konta, na którym jesteś teraz.';

  @override
  String get settingsAppVersionLabel => 'Wersja aplikacji';

  @override
  String get settingsAppLanguage => 'Język aplikacji';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (domyślny język urządzenia)';
  }

  @override
  String get settingsAppLanguageTitle => 'Język aplikacji';

  @override
  String get settingsAppLanguageDescription =>
      'Wybierz język interfejsu aplikacji';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Użyj języka urządzenia';

  @override
  String get settingsGeneralTitle => 'Ustawienia ogólne';

  @override
  String get settingsContentSafetyTitle => 'Treści i bezpieczeństwo';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRACJE';

  @override
  String get generalSettingsSectionViewing => 'OGLĄDANIE';

  @override
  String get generalSettingsSectionCreating => 'TWORZENIE';

  @override
  String get generalSettingsSectionApp => 'APLIKACJA';

  @override
  String get appearanceSettingsTitle => 'Wygląd';

  @override
  String get appearanceSettingsSubtitle =>
      'Wybierz, jak Divine ma wyglądać na tym urządzeniu';

  @override
  String get appearanceSettingsSystem => 'Domyślne systemu';

  @override
  String get appearanceSettingsLight => 'Jasny';

  @override
  String get appearanceSettingsDark => 'Ciemny';

  @override
  String get generalSettingsClosedCaptions => 'Napisy';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Pokazuj napisy, gdy filmy je zawierają';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Tylko kwadratowe filmy';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Trzymaj feedy w klasycznym kwadratowym formacie';

  @override
  String get contentPreferencesTitle => 'Preferencje treści';

  @override
  String get contentPreferencesContentFilters => 'Filtry treści';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Zarządzaj filtrami ostrzeżeń o treściach';

  @override
  String get contentPreferencesContentLanguage => 'Język treści';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (domyślny język urządzenia)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Oznaczaj swoje filmy językiem, żeby widzowie mogli filtrować treści.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Użyj języka urządzenia (domyślnie)';

  @override
  String get contentPreferencesAudioSharing =>
      'Udostępniaj moje audio do ponownego użycia';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Gdy włączone, inni mogą używać dźwięku z twoich filmów';

  @override
  String get contentPreferencesMusicMode => 'Tryb muzyczny';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Wyłącza redukcję szumów, która spłaszcza instrumenty. Lepiej dla muzyki, gorzej dla głosu.';

  @override
  String get contentPreferencesAccountLabels => 'Etykiety konta';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'Oznacz swoje treści';

  @override
  String get contentPreferencesAccountContentLabels => 'Etykiety treści konta';

  @override
  String get contentPreferencesClearAll => 'Wyczyść wszystko';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Zaznacz wszystkie pasujące do twojego konta';

  @override
  String get contentPreferencesDoneNoLabels => 'Gotowe (bez etykiet)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Gotowe (wybrano $count)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Urządzenie wejścia audio';

  @override
  String get contentPreferencesAutoRecommended => 'Automatycznie (zalecane)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Automatycznie wybiera najlepszy mikrofon';

  @override
  String get contentPreferencesSelectAudioInput => 'Wybierz wejście audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Nieznany mikrofon';

  @override
  String get contentFiltersAdultContent => 'TREŚCI DLA DOROSŁYCH';

  @override
  String get contentFiltersViolenceGore => 'PRZEMOC I DRASTYCZNE SCENY';

  @override
  String get contentFiltersSubstances => 'SUBSTANCJE';

  @override
  String get contentFiltersOther => 'INNE';

  @override
  String get contentFiltersAgeGateMessage =>
      'Zweryfikuj wiek w Bezpieczeństwie i prywatności, żeby odblokować filtry treści dla dorosłych';

  @override
  String get contentFiltersShow => 'Pokazuj';

  @override
  String get contentFiltersWarn => 'Ostrzegaj';

  @override
  String get contentFiltersFilterOut => 'Filtruj';

  @override
  String get profileBlockedAccountNotAvailable => 'To konto jest niedostępne';

  @override
  String get profileInvalidId => 'Nieprawidłowy ID profilu';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Sprawdź $displayName na Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName na Divine';
  }

  @override
  String get profileShareFailed =>
      'Nie udało się udostępnić profilu. Spróbuj ponownie.';

  @override
  String get profileCopyPublicKey => 'Skopiuj klucz publiczny (npub)';

  @override
  String get profileGetEmbedCode => 'Pobierz kod do osadzenia';

  @override
  String get profilePublicKeyCopied => 'Klucz publiczny skopiowany do schowka';

  @override
  String get profileEmbedCodeCopied => 'Kod do osadzenia skopiowany do schowka';

  @override
  String get profileMoreTooltip => 'Więcej';

  @override
  String get profileMoreSemanticLabel => 'Więcej opcji';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Zamknij awatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Zamknij podgląd awatara';

  @override
  String get profileFollowingLabel => 'Obserwujesz';

  @override
  String get profileFollowLabel => 'Obserwuj';

  @override
  String get profileBlockedLabel => 'Zablokowany';

  @override
  String get profileFollowersLabel => 'Obserwujących';

  @override
  String get profileFollowingStatLabel => 'Obserwowanych';

  @override
  String get profileVideosLabel => 'Filmy';

  @override
  String get profileCollabsLabel => 'Współprace';

  @override
  String get profileLikedLabel => 'Polubione';

  @override
  String get profileRepostsLabel => 'Reposty';

  @override
  String get profileListsLabel => 'Listy';

  @override
  String get profileCommentsLabel => 'Komentarze';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszenia dla współtwórców wciąż czeka na wysłanie',
      many: '$count zaproszeń dla współtwórców wciąż czeka na wysłanie',
      few: '$count zaproszenia dla współtwórców wciąż czekają na wysłanie',
      one: '1 zaproszenie dla współtwórcy wciąż czeka na wysłanie',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Zaproszenie zostało w kolejce. Ponów je tutaj.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Dla „$title”. Ponów je tutaj.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Ponów';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Ponawianie';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Ponawianie zaproszenia dla współtwórcy jest teraz niedostępne.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszenia dla współtwórców wciąż czeka na wysłanie.',
      many: '$count zaproszeń dla współtwórców wciąż czeka na wysłanie.',
      few: '$count zaproszenia dla współtwórców wciąż czekają na wysłanie.',
      one: '1 zaproszenie dla współtwórcy wciąż czeka na wysłanie.',
      zero: 'Zaproszenia dla współtwórców wysłane.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count współtwórcy nie może otrzymywać zaproszeń.',
      many: '$count współtwórców nie może otrzymywać zaproszeń.',
      few: '$count współtwórcy nie mogą otrzymywać zaproszeń.',
      one: '1 współtwórca nie może otrzymywać zaproszeń.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count użytkownika',
      many: '$count użytkowników',
      few: '$count użytkowników',
      one: '1 użytkownik',
    );
    return '$_temp0';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Zablokować $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Gdy blokujesz użytkownika:';

  @override
  String get profileBlockBulletHidePosts =>
      'Jego posty nie będą pojawiać się w twoich kanałach.';

  @override
  String get profileBlockBulletCantView =>
      'Nie będzie mógł zobaczyć twojego profilu, obserwować cię ani oglądać twoich postów.';

  @override
  String get profileBlockBulletNoNotify =>
      'Nie zostanie powiadomiony o tej zmianie.';

  @override
  String get profileBlockBulletYouCanView =>
      'Wciąż będziesz mógł zobaczyć jego profil.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Zablokuj $displayName';
  }

  @override
  String get profileCancelButton => 'Anuluj';

  @override
  String get profileLearnMore => 'Dowiedz się więcej';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Odblokować $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Gdy odblokujesz tego użytkownika:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Jego posty pojawią się w twoich kanałach.';

  @override
  String get profileUnblockBulletCanView =>
      'Będzie mógł zobaczyć twój profil, obserwować cię i oglądać twoje posty.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Nie zostanie powiadomiony o tej zmianie.';

  @override
  String get profileLearnMoreAt => 'Dowiedz się więcej na ';

  @override
  String get profileUnblockButton => 'Odblokuj';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Przestań obserwować $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Zablokuj $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Odblokuj $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Zgłoś $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Dodaj $displayName do listy';
  }

  @override
  String get profileNoCollabsTitle => 'Brak współprac';

  @override
  String get profileCollabsOwnEmpty =>
      'Filmy, przy których współpracujesz, pojawią się tutaj';

  @override
  String get profileCollabsOtherEmpty =>
      'Filmy, przy których współpracuje, pojawią się tutaj';

  @override
  String get profileErrorLoadingCollabs =>
      'Błąd wczytywania filmów ze współprac';

  @override
  String get profileNoSavedVideosTitle => 'Nic jeszcze nie zapisano';

  @override
  String get profileSavedOwnEmpty =>
      'Dodawaj filmy do zakładek z menu udostępniania, a pojawią się tutaj.';

  @override
  String get profileErrorLoadingSaved => 'Błąd wczytywania zapisanych filmów';

  @override
  String get profileNoCommentsOwnTitle => 'Brak komentarzy';

  @override
  String get profileNoCommentsOtherTitle => 'Brak komentarzy';

  @override
  String get profileCommentsOwnEmpty =>
      'Twoje komentarze i odpowiedzi pojawią się tutaj';

  @override
  String get profileCommentsOtherEmpty =>
      'Jego komentarze i odpowiedzi pojawią się tutaj';

  @override
  String get profileErrorLoadingComments => 'Błąd wczytywania komentarzy';

  @override
  String get profileVideoRepliesSection => 'Odpowiedzi wideo';

  @override
  String get profileCommentsSection => 'Komentarze';

  @override
  String get profileEditLabel => 'Edytuj';

  @override
  String get profileLibraryLabel => 'Biblioteka';

  @override
  String get profileNoLikedVideosTitle => 'Brak polubionych filmów';

  @override
  String get profileLikedOwnEmpty =>
      'Polubione przez ciebie filmy pojawią się tutaj';

  @override
  String get profileLikedOtherEmpty =>
      'Polubione przez niego filmy pojawią się tutaj';

  @override
  String get profileErrorLoadingLiked => 'Błąd wczytywania polubionych filmów';

  @override
  String get profileNoRepostsTitle => 'Brak repostów';

  @override
  String get profileRepostsOwnEmpty => 'Twoje reposty pojawią się tutaj';

  @override
  String get profileRepostsOtherEmpty => 'Jego reposty pojawią się tutaj';

  @override
  String get profileErrorLoadingReposts =>
      'Błąd wczytywania repostowanych filmów';

  @override
  String get profileNoVideosTitle => 'Brak filmów';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Udostępnij swój pierwszy film, żeby go tu zobaczyć';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Ten użytkownik nie udostępnił jeszcze żadnych filmów';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatura filmu $number';
  }

  @override
  String get profileShowMore => 'Pokaż więcej';

  @override
  String get profileShowLess => 'Pokaż mniej';

  @override
  String get dmMessageDisplayLimitReached =>
      'Pozostała część tej wiadomości nie jest wyświetlana.';

  @override
  String get profileCompleteYourProfile => 'Uzupełnij swój profil';

  @override
  String get profileCompleteSubtitle =>
      'Dodaj imię, bio i zdjęcie, żeby zacząć';

  @override
  String get profilePleaseTryAgain => 'Spróbuj ponownie';

  @override
  String get profileSecureYourAccount => 'Zabezpiecz konto';

  @override
  String get profileSecureSubtitle =>
      'Dodaj e-mail i hasło, żeby odzyskać konto na dowolnym urządzeniu';

  @override
  String get profileRetryButton => 'Spróbuj ponownie';

  @override
  String get profileSessionExpired => 'Sesja wygasła';

  @override
  String get profileSignInToRestore =>
      'Zaloguj się ponownie, żeby odzyskać pełny dostęp';

  @override
  String get profileSignInButton => 'Zaloguj się';

  @override
  String get profileMaybeLaterLabel => 'Może później';

  @override
  String get profileSecurePrimaryButton => 'Dodaj e-mail i hasło';

  @override
  String get profileCompletePrimaryButton => 'Uzupełnij swój profil';

  @override
  String get profileLoopsLabel => 'Loopy';

  @override
  String get profileLikesLabel => 'Polubienia';

  @override
  String get profileMyLibraryLabel => 'Moja biblioteka';

  @override
  String get profileMessageLabel => 'Wiadomość';

  @override
  String get profileShareLabel => 'Udostępnij profil';

  @override
  String get profileDeletedAccountName => 'Usunięte konto';

  @override
  String get inboxActionReportVanishedAccount => 'Zgłoś to konto';

  @override
  String get inboxActionBlockVanishedAccount => 'Zablokuj to konto';

  @override
  String get inboxActionUnblockVanishedAccount => 'Odblokuj to konto';

  @override
  String get inboxReportedVanishedAccount => 'Zgłoszono to konto';

  @override
  String get inboxBlockedVanishedAccount => 'Zablokowano to konto';

  @override
  String get inboxUnblockedVanishedAccount => 'Odblokowano to konto';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'To usuwa rozmowę z Twojej skrzynki odbiorczej. Jeśli ta osoba znów do Ciebie napisze, rozpocznie się nowa rozmowa.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'To konto zostało usunięte';

  @override
  String get profileUserFallback => 'użytkownik';

  @override
  String get profileLinkCopied => 'Link do profilu skopiowany';

  @override
  String get profileSetupEditProfileTitle => 'Edytuj profil';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Skonfiguruj profil, zanim dodasz adres NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Utwórz profil';

  @override
  String get profileSetupBackLabel => 'Wstecz';

  @override
  String get profileSetupAboutNostr => 'O Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil opublikowany pomyślnie!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Zapisać zmiany?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Zapisz zmiany przed wyjściem albo odrzuć je i idź dalej.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Zapisz zmiany';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Odrzuć zmiany';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Edytuj dalej';

  @override
  String get profileSetupCreateNewProfile => 'Utworzyć nowy profil?';

  @override
  String get profileSetupNoExistingProfile =>
      'Nie znaleźliśmy istniejącego profilu na twoich przekaźnikach. Publikacja utworzy nowy profil. Kontynuować?';

  @override
  String get profileSetupPublishButton => 'Opublikuj';

  @override
  String get profileSetupUsernameTaken =>
      'Nazwa użytkownika została właśnie zajęta. Wybierz inną.';

  @override
  String get profileSetupClaimFailed =>
      'Nie udało się zarezerwować nazwy użytkownika. Spróbuj ponownie.';

  @override
  String get profileSetupPublishFailed =>
      'Nie udało się opublikować profilu. Spróbuj ponownie.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Nie można połączyć się z siecią. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get profileSetupDisplayNameLabel => 'Nazwa wyświetlana';

  @override
  String get profileSetupDisplayNameRequired => 'Wprowadź nazwę wyświetlaną';

  @override
  String get profileSetupBioLabel => 'Bio (opcjonalnie)';

  @override
  String get profileSetupWebsiteLabel => 'Strona internetowa (opcjonalnie)';

  @override
  String get profileSetupPublicKeyLabel => 'Klucz publiczny (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nazwa użytkownika (opcjonalnie)';

  @override
  String get profileSetupUsernameHelper =>
      'Użyj liter, cyfr lub myślników. Twoja nazwa użytkownika stanie się adresem divine.video. Spacji i symboli użyj w nazwie wyświetlanej.';

  @override
  String get profileSetupSaveButton => 'Zapisz';

  @override
  String get profileSetupSavingButton => 'Zapisywanie...';

  @override
  String get profileSetupImageUrlTitle => 'Dodaj URL obrazu';

  @override
  String get profileSetupImageSelectionFailed =>
      'Wybór obrazu nieudany. Wklej URL obrazu poniżej.';

  @override
  String get profileSetupImagesTypeGroup => 'obrazy';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Dostęp do aparatu jest wyłączony. Włącz go w Ustawieniach, żeby zrobić zdjęcie.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Dostęp do aparatu nie jest dozwolony na tym urządzeniu.';

  @override
  String get cameraPickErrorBusy =>
      'Selektor jest już otwarty. Zamknij go i spróbuj ponownie.';

  @override
  String get cameraPickErrorGeneric =>
      'Nie udało się otworzyć aparatu. Spróbuj ponownie.';

  @override
  String get profileSetupGotItButton => 'Rozumiem';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Nie udało się przesłać obrazu. Spróbuj ponownie później.';

  @override
  String get profileSetupUploadNetworkError =>
      'Błąd sieci: Sprawdź połączenie z internetem i spróbuj ponownie.';

  @override
  String get profileSetupUploadAuthError =>
      'Błąd uwierzytelnienia: Wyloguj się i zaloguj ponownie.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Plik za duży: Wybierz mniejszy obraz (maks. 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Nie udało się przesłać obrazu. Nasze serwery są tymczasowo niedostępne. Spróbuj ponownie za chwilę.';

  @override
  String get profileSetupBannerClearButton => 'Wyczyść baner';

  @override
  String get profileSetupBannerChangeColor => 'Kolor baneru';

  @override
  String get profileSetupChangeBannerTitle => 'Zmień baner';

  @override
  String get profileSetupBannerColorPickerTitle => 'Zmień kolor banera';

  @override
  String get profileSetupBannerColorCustom => 'Niestandardowy';

  @override
  String get profileSetupBannerColorNone => 'Bez koloru';

  @override
  String get profileSetupBannerColorLime => 'Limonkowy';

  @override
  String get profileSetupBannerColorYellow => 'Żółty';

  @override
  String get profileSetupBannerColorViolet => 'Fioletowy';

  @override
  String get profileSetupBannerColorPink => 'Różowy';

  @override
  String get profileSetupBannerColorOrange => 'Pomarańczowy';

  @override
  String get profileSetupBannerColorPurple => 'Purpurowy';

  @override
  String get profileSetupAvatarClearButton => 'Usuń zdjęcie';

  @override
  String get profileSetupImageTakePhoto => 'Zrób zdjęcie';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Prześlij z galerii';

  @override
  String get profileSetupImagePasteLink => 'Wklej link do obrazu';

  @override
  String get profileSetupEditAvatarLabel => 'Edytuj zdjęcie profilowe';

  @override
  String get profileSetupEditBannerLabel => 'Edytuj baner';

  @override
  String get profileSetupUsernameChecking => 'Sprawdzanie dostępności...';

  @override
  String get profileSetupUsernameAvailable => 'Nazwa użytkownika dostępna!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Nazwa użytkownika już zajęta';

  @override
  String get profileSetupUsernameReserved =>
      'Nazwa użytkownika jest zarezerwowana';

  @override
  String get profileSetupContactSupport => 'Skontaktuj się z pomocą';

  @override
  String get profileSetupCheckAgain => 'Sprawdź ponownie';

  @override
  String get profileSetupUsernameBurned =>
      'Ta nazwa użytkownika nie jest już dostępna';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Dozwolone są tylko litery, cyfry i myślniki';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Nazwa użytkownika nie może zaczynać się ani kończyć myślnikiem';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Nazwa użytkownika musi mieć od 3 do 63 znaków';

  @override
  String get profileSetupUsernameNetworkError =>
      'Nie można sprawdzić dostępności. Spróbuj ponownie.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Nieprawidłowy format nazwy użytkownika';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Nie udało się sprawdzić dostępności';

  @override
  String get profileSetupUsernameReservedTitle =>
      'Nazwa użytkownika zarezerwowana';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Nazwa $username jest zarezerwowana. Powiedz nam, dlaczego ma należeć do ciebie.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'np. To moja nazwa marki, pseudonim sceniczny itp.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Już kontaktowałeś się z pomocą? Dotknij \"Sprawdź ponownie\", żeby zobaczyć, czy została ci przyznana.';

  @override
  String get profileSetupSupportRequestSent =>
      'Prośba o pomoc wysłana! Odezwiemy się wkrótce.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Nie można otworzyć e-maila. Wyślij na: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Wyślij prośbę';

  @override
  String get profileSetupUseOwnNip05 => 'Użyj własnego adresu NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Adres NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Nieprawidłowy format NIP-05 (np. nazwa@domena.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Użyj pola nazwy użytkownika powyżej dla divine.video';

  @override
  String get nostrSettingsNip05Address => 'Adres NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Użyj swojej nazwy użytkownika divine.video albo skieruj swój identyfikator na adres NIP-05 w domenie, którą kontrolujesz.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Zapisz NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'Zapisano NIP-05';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Nie udało się zapisać NIP-05. Spróbuj ponownie.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Użyć własnego NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 łączy nazwę taką jak ty@twojadomena.pl z twoją tożsamością Nostr. Musisz kontrolować domenę i umieścić plik weryfikacyjny pod właściwą ścieżką. Jeśli coś się nie zgadza, ludzie cię nie znajdą, a zweryfikowany identyfikator zniknie. Kontynuuj tylko wtedy, gdy masz to już skonfigurowane.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Dalej';

  @override
  String get profileSetupNip05ConfirmCancel => 'Anuluj';

  @override
  String get profileSetupProfilePicturePreview => 'Podgląd zdjęcia profilowego';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine jest zbudowane na Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' otwartym protokole odpornym na cenzurę, który pozwala ludziom komunikować się online bez polegania na pojedynczej firmie czy platformie. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Gdy rejestrujesz się w Divine, otrzymujesz nową tożsamość Nostr.';

  @override
  String get nostrInfoOwnership =>
      'Nostr pozwala ci posiadać swoje treści, tożsamość i graf społeczny, których możesz używać w wielu aplikacjach. Efekt: więcej wyboru, mniej zamknięcia, zdrowszy i bardziej odporny społecznościowy internet.';

  @override
  String get nostrInfoLingo => 'Słownictwo Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Twój publiczny adres Nostr. Można go bezpiecznie udostępniać i pozwala innym znaleźć, obserwować lub napisać do ciebie w aplikacjach Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Twój klucz prywatny i dowód własności. Daje pełną kontrolę nad twoją tożsamością Nostr, więc ';

  @override
  String get nostrInfoNsecWarning => 'zawsze trzymaj go w tajemnicy!';

  @override
  String get nostrInfoUsernameLabel => 'Nazwa użytkownika Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Czytelna nazwa (jak @imie.divine.video), która linkuje do twojego npub. Ułatwia rozpoznanie i weryfikację twojej tożsamości Nostr, podobnie jak adres e-mail.';

  @override
  String get nostrInfoLearnMoreAt => 'Dowiedz się więcej na ';

  @override
  String get nostrInfoGotIt => 'Rozumiem!';

  @override
  String get videoGridRefreshLabel => 'Szukanie większej liczby filmów';

  @override
  String get videoGridOptionsTitle => 'Opcje filmu';

  @override
  String get videoGridEditVideo => 'Edytuj film';

  @override
  String get videoGridEditVideoSubtitle => 'Zaktualizuj tytuł, opis i hashtagi';

  @override
  String get videoGridDeleteVideo => 'Usuń film';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Usuń ten film z Divine. Może nadal pojawiać się w innych klientach Nostr.';

  @override
  String get videoGridDeletingContent => 'Usuwanie treści...';

  @override
  String get exploreTabFeatured => 'Polecane';

  @override
  String get exploreTabClassics => 'Klasyki';

  @override
  String get exploreTabNew => 'Nowe';

  @override
  String get exploreTabPopular => 'Popularne';

  @override
  String get exploreTabCategories => 'Kategorie';

  @override
  String get exploreTabForYou => 'Dla ciebie';

  @override
  String get exploreTabLists => 'Listy';

  @override
  String get exploreTabIntegratedApps => 'Zintegrowane aplikacje';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Jeszcze nic tu nie ma. Zajrzyj wkrótce.';

  @override
  String get featuredTabLoadFailed => 'Nie udało się wczytać tej kolekcji.';

  @override
  String get featuredTabRetry => 'Spróbuj ponownie';

  @override
  String get exploreNoVideosAvailable => 'Brak dostępnych filmów';

  @override
  String get exploreDiscoverLists => 'Odkrywaj listy';

  @override
  String get exploreAboutLists => 'O listach';

  @override
  String get exploreAboutListsDescription =>
      'Listy pomagają ci porządkować i kuratorować treści Divine na dwa sposoby:';

  @override
  String get explorePeopleLists => 'Listy osób';

  @override
  String get explorePeopleListsDescription =>
      'Obserwuj grupy twórców i zobacz ich najnowsze filmy';

  @override
  String get exploreVideoLists => 'Listy filmów';

  @override
  String get exploreVideoListsDescription =>
      'Twórz playlisty ulubionych filmów do oglądania później';

  @override
  String get exploreMyLists => 'Moje listy';

  @override
  String get exploreSubscribedLists => 'Subskrybowane listy';

  @override
  String get exploreErrorLoadingLists =>
      'Błąd wczytywania list. Spróbuj ponownie.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nowego filmu',
      many: '$count nowych filmów',
      few: '$count nowe filmy',
      one: '1 nowy film',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nowego filmu',
      many: '$count nowych filmów',
      few: '$count nowe filmy',
      one: '1 nowy film',
    );
    return 'Wczytaj $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Odtwórz film';

  @override
  String get videoPlayerMute => 'Wycisz film';

  @override
  String get videoPlayerUnmute => 'Włącz dźwięk filmu';

  @override
  String get videoPlayerTapHint =>
      'Dotknij, aby odtworzyć lub wstrzymać. Dotknij dwukrotnie, aby polubić.';

  @override
  String get videoSettingsMenuOpen => 'Otwórz ustawienia odtwarzania';

  @override
  String get videoSettingsMenuClose => 'Zamknij ustawienia odtwarzania';

  @override
  String get videoSettingsCaptionsEnable => 'Włącz napisy';

  @override
  String get videoSettingsCaptionsDisable => 'Wyłącz napisy';

  @override
  String get videoSettingsAutoAdvanceOn =>
      'Automatyczne przechodzenie włączone';

  @override
  String get videoSettingsAutoAdvanceOff =>
      'Automatyczne przechodzenie wyłączone';

  @override
  String get videoSettingsCaptionsOn => 'Napisy włączone';

  @override
  String get videoSettingsCaptionsOff => 'Napisy wyłączone';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Napisy włączone dla tego filmu';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Napisy wyłączone dla tego filmu';

  @override
  String get contentWarningLabel => 'Ostrzeżenie o treści';

  @override
  String get contentWarningNudity => 'Nagość';

  @override
  String get contentWarningSexualContent => 'Treści seksualne';

  @override
  String get contentWarningPornography => 'Pornografia';

  @override
  String get contentWarningGraphicMedia => 'Drastyczne media';

  @override
  String get contentWarningViolence => 'Przemoc';

  @override
  String get contentWarningSelfHarm => 'Samookaleczenie';

  @override
  String get contentWarningDrugUse => 'Narkotyki';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tytoń';

  @override
  String get contentWarningGambling => 'Hazard';

  @override
  String get contentWarningProfanity => 'Wulgarny język';

  @override
  String get contentWarningFlashingLights => 'Migające światła';

  @override
  String get contentWarningAiGenerated => 'Wygenerowane przez AI';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Wrażliwe treści';

  @override
  String get contentWarningDescNudity => 'Zawiera nagość lub częściową nagość';

  @override
  String get contentWarningDescSexual => 'Zawiera treści seksualne';

  @override
  String get contentWarningDescPorn => 'Zawiera jawnie pornograficzne treści';

  @override
  String get contentWarningDescGraphicMedia =>
      'Zawiera drastyczne lub niepokojące obrazy';

  @override
  String get contentWarningDescViolence => 'Zawiera treści z przemocą';

  @override
  String get contentWarningDescSelfHarm =>
      'Zawiera odniesienia do samookaleczenia';

  @override
  String get contentWarningDescDrugs => 'Zawiera treści związane z narkotykami';

  @override
  String get contentWarningDescAlcohol => 'Zawiera treści związane z alkoholem';

  @override
  String get contentWarningDescTobacco => 'Zawiera treści związane z tytoniem';

  @override
  String get contentWarningDescGambling => 'Zawiera treści związane z hazardem';

  @override
  String get contentWarningDescProfanity => 'Zawiera mocny język';

  @override
  String get contentWarningDescFlashingLights =>
      'Zawiera migające światła (ostrzeżenie o fotowrażliwości)';

  @override
  String get contentWarningDescAiGenerated =>
      'Ta treść została wygenerowana przez AI';

  @override
  String get contentWarningDescSpoiler => 'Zawiera spoilery';

  @override
  String get contentWarningDescContentWarning =>
      'Twórca oznaczył to jako wrażliwe';

  @override
  String get contentWarningDescDefault => 'Twórca oflagował tę treść';

  @override
  String get contentWarningDetailsTitle => 'Ostrzeżenia o treściach';

  @override
  String get contentWarningDetailsSubtitle => 'Twórca zastosował te etykiety:';

  @override
  String get contentWarningManageFilters => 'Zarządzaj filtrami treści';

  @override
  String get contentWarningViewAnyway => 'Zobacz mimo to';

  @override
  String get contentWarningReportContentTooltip => 'Zgłoś treść';

  @override
  String get contentWarningBlockUserTooltip => 'Zablokuj użytkownika';

  @override
  String get contentWarningBlockedTitle => 'Treść zablokowana';

  @override
  String get contentWarningBlockedPolicy =>
      'Ta treść została zablokowana z powodu naruszenia zasad.';

  @override
  String get contentWarningNoticeTitle => 'Informacja o treści';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potencjalnie szkodliwa treść';

  @override
  String get contentWarningView => 'Zobacz';

  @override
  String get contentWarningReportAction => 'Zgłoś';

  @override
  String get contentWarningHideAllLikeThis => 'Ukrywaj wszystkie takie treści';

  @override
  String get contentWarningNoFilterYet =>
      'Brak zapisanego filtra dla tego ostrzeżenia.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Od teraz będziemy ukrywać takie posty.';

  @override
  String get communitySuggestTitle => 'Pomóż to sklasyfikować';

  @override
  String get communitySuggestSubtitle =>
      'Brakuje ostrzeżenia o treści? Twoja sugestia jest publiczna, podpisana i nie można jej cofnąć.';

  @override
  String get communitySuggestSubmit => 'Zaproponuj';

  @override
  String get communitySuggestSuccess =>
      'Dzięki. Twoja sugestia została wysłana.';

  @override
  String get communitySuggestFailure =>
      'Nie udało się wysłać sugestii. Spróbuj ponownie.';

  @override
  String get communitySuggestAlready => 'Twoja sugestia';

  @override
  String get communitySuggestActionLabel => 'Sklasyfikuj';

  @override
  String get videoErrorNotFound => 'Nie znaleziono filmu';

  @override
  String get videoErrorPlayback => 'Błąd odtwarzania filmu';

  @override
  String get videoErrorAgeRestricted => 'Treść z ograniczeniem wiekowym';

  @override
  String get videoErrorUnavailable => 'Film niedostępny';

  @override
  String get videoErrorUnavailableBody => 'Ten film nie jest teraz dostępny.';

  @override
  String get videoErrorRetry => 'Spróbuj ponownie';

  @override
  String get videoErrorContentRestricted => 'Treść ograniczona';

  @override
  String get videoErrorContentRestrictedBody =>
      'Ten film został usunięty za złamanie naszych zasad dotyczących treści.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Zweryfikuj swój wiek, żeby zobaczyć ten film.';

  @override
  String get videoErrorSkip => 'Pomiń';

  @override
  String get videoErrorVerifyAgeButton => 'Zweryfikuj wiek';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Nie udało się zweryfikować Twojego wieku. Spróbuj ponownie.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Przekroczono czas weryfikacji. Sprawdź połączenie lub spróbuj ponownie za chwilę.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Treści dla dorosłych są wyłączone';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Włącz je w filtrach treści, żeby obejrzeć ten film.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Otwórz filtry treści';

  @override
  String get videoDetailLoadError => 'Nie udało się wczytać filmu';

  @override
  String get videoDetailLoadErrorBody =>
      'Coś poszło nie tak po drodze. Spróbuj jeszcze raz.';

  @override
  String get videoDetailNotFoundBody =>
      'Mógł zostać usunięty, być poza zasięgiem albo ukryty przez twoje ustawienia.';

  @override
  String get databaseCorruptionTitle => 'Twoje lokalne dane się uszkodziły';

  @override
  String get databaseCorruptionBody =>
      'Zamknij Divine i otwórz ponownie — naprawimy to automatycznie. Zachowamy tyle Twoich szkiców i klipów, ile się da, reszta wczyta się na nowo.';

  @override
  String get databaseCorruptionCloseButton => 'Zamknij Divine';

  @override
  String get videoDetailContextTitle => 'Udostępniony film';

  @override
  String get videoDetailCloseSemanticLabel => 'Zamknij odtwarzacz wideo';

  @override
  String get videoFollowButtonFollow => 'Obserwuj';

  @override
  String get audioAttributionOriginalSound => 'Oryginalny dźwięk';

  @override
  String get audioAttributionUnavailableSound => 'Dźwięk niedostępny';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Zainspirowane przez @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Zainspirowane przez @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'z @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'z @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count współtwórcy',
      many: '$count współtwórców',
      few: '$count współtwórców',
      one: '1 współtwórca',
    );
    return '$_temp0. Dotknij, żeby zobaczyć profil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Oczekuje';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Oczekujący współtwórca';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending oczekuje)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Dotknij, aby zobaczyć profil.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Dotknij, aby zobaczyć filmy z tym hashtagiem.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Udostępnij film';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post udostępniony z $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Post udostępniony z $count osobami',
      many: 'Post udostępniony z $count osobami',
      few: 'Post udostępniony z $count osobami',
      one: 'Post udostępniony z $count osobą',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Nie udało się wysłać filmu';

  @override
  String get shareAddedToBookmarks => 'Dodano do zakładek';

  @override
  String get shareRemovedFromBookmarks => 'Usunięto z zakładek';

  @override
  String get shareFailedToAddBookmark => 'Nie udało się dodać zakładki';

  @override
  String get shareFailedToRemoveBookmark => 'Nie udało się usunąć zakładki';

  @override
  String get shareActionFailed => 'Akcja nieudana';

  @override
  String get shareWithTitle => 'Udostępnij z';

  @override
  String get shareFindPeople => 'Znajdź ludzi';

  @override
  String get shareFindPeopleMultiline => 'Znajdź\nludzi';

  @override
  String get shareSent => 'Wysłano';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return 'Wybrano $name';
  }

  @override
  String get shareMessageHint => 'Dodaj opcjonalną wiadomość...';

  @override
  String get videoActionUnlike => 'Cofnij polubienie';

  @override
  String get videoActionLike => 'Polub film';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Polub';

  @override
  String get videoActionReplyLabel => 'Odpowiedz';

  @override
  String get videoActionRepostLabel => 'Repostuj';

  @override
  String get videoActionShareLabel => 'Udostępnij';

  @override
  String get videoActionReportLabel => 'Zgłoś';

  @override
  String get videoActionReport => 'Zgłoś wideo';

  @override
  String get videoActionEditLabel => 'Edytuj';

  @override
  String get videoActionEdit => 'Edytuj wideo';

  @override
  String get videoActionAboutLabel => 'O filmie';

  @override
  String get videoActionEnableAutoAdvance =>
      'Włącz automatyczne przechodzenie dalej';

  @override
  String get videoActionDisableAutoAdvance =>
      'Wyłącz automatyczne przechodzenie dalej';

  @override
  String get videoActionRemoveRepost => 'Usuń repost';

  @override
  String get videoActionRepost => 'Repostuj film';

  @override
  String get videoActionViewComments => 'Zobacz komentarze';

  @override
  String get videoActionMoreOptions => 'Więcej opcji';

  @override
  String get videoEngagementLikersTitle => 'Polubione przez';

  @override
  String get videoEngagementRepostersTitle => 'Udostępnione przez';

  @override
  String get videoEngagementLikersEmpty => 'Brak polubień';

  @override
  String get videoEngagementRepostersEmpty => 'Brak udostępnień';

  @override
  String get videoEngagementLoadFailed => 'Nie udało się wczytać listy';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Otwórz szczegóły filmu';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Otwórz szczegóły filmu';

  @override
  String get videoOverlayCommentBarHint => 'Dodaj komentarz...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Dodaj komentarz';

  @override
  String get videoOverlayCommentBarSendLabel => 'Wyślij komentarz';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Komentarz opublikowany';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Nie udało się opublikować komentarza';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pętli',
      many: 'pętli',
      few: 'pętle',
      one: 'pętla',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Nie Divine';

  @override
  String get metadataBadgeHumanMade => 'Zrobione przez człowieka';

  @override
  String get metadataSoundsLabel => 'Dźwięki';

  @override
  String get metadataOriginalSound => 'Oryginalny dźwięk';

  @override
  String get metadataVerificationLabel => 'Weryfikacja';

  @override
  String get metadataDeviceAttestation => 'Atestacja urządzenia';

  @override
  String get metadataPgpSignature => 'Podpis PGP';

  @override
  String get metadataC2paCredentials => 'Poświadczenia treści C2PA';

  @override
  String get metadataProofManifest => 'Manifest dowodowy';

  @override
  String get metadataVerificationInfoTooltip => 'Co oznaczają te sprawdzenia?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Co oznaczają te sprawdzenia';

  @override
  String get metadataVerificationInfoIntro =>
      'Te sygnały pochodzą z aparatu i z samego pliku wideo. Im więcej ich ma nagranie, tym więcej możemy udowodnić o jego pochodzeniu.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'System operacyjny telefonu poręczył za aplikację, która to nagrała. Mocna przesłanka, że pochodzi z kamery, a nie z przesłanego pliku.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Wideo zostało podpisane kryptograficznie w chwili nagrania. Jeśli później zmieni się choć jedna klatka, podpis przestaje się zgadzać.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Zapis pochodzenia w standardzie branżowym, przenoszony wewnątrz pliku – dzięki temu sprawdzą go też aplikacje inne niż Divine.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Pełny zapis ProofMode: odcisk pliku, znacznik czasu i kontekst nagrania, dołączone do wideo.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Brak jednego sprawdzenia nie oznacza, że wideo jest fałszywe. Starsze klipy i przesłane pliki nigdy go nie miały — to znaczy tylko, że tej części nie możemy udowodnić.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Więcej informacji na $url';
  }

  @override
  String get metadataCreatorLabel => 'Twórca';

  @override
  String get metadataCollaboratorsLabel => 'Współtwórcy';

  @override
  String get metadataInspiredByLabel => 'Zainspirowane przez';

  @override
  String get metadataRepostedByLabel => 'Repostowane przez';

  @override
  String metadataMoreReposters(int count) {
    return '+$count więcej';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Pętle';
  }

  @override
  String get metadataLikesLabel => 'Polubienia';

  @override
  String get metadataCommentsLabel => 'Komentarze';

  @override
  String get metadataRepostsLabel => 'Reposty';

  @override
  String get metadataVineStatsLabel => 'Na Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops pętli · $likes polubień · $comments komentarzy · $reposts repostów';
  }

  @override
  String get metadataDivineStatsLabel => 'Na Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views wyświetleń · $likes polubień · $comments komentarzy · $reposts repostów';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Opublikowano $date';
  }

  @override
  String get devOptionsTitle => 'Opcje dewelopera';

  @override
  String get devOptionsDisableDeveloperMode => 'Wyłącz tryb dewelopera';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Ukryj opcje deweloperskie w ustawieniach';

  @override
  String get devOptionsDisableDeveloperModeToast => 'Tryb dewelopera wyłączony';

  @override
  String get devOptionsShorebirdTitle => 'Poprawki Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Aktywna poprawka';

  @override
  String get devOptionsShorebirdNoPatch => 'Brak zainstalowanej poprawki';

  @override
  String get devOptionsShorebirdUnavailable => 'Niedostępne w tej kompilacji';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Poprawki działają tylko w kompilacji utworzonej przez shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Odczytywanie stanu poprawki…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Kanał testowy nie został jeszcze sprawdzony.';

  @override
  String get devOptionsShorebirdCheck => 'Sprawdź kanał testowy';

  @override
  String get devOptionsShorebirdApply => 'Zastosuj poprawkę testową';

  @override
  String get devOptionsShorebirdUseStable => 'Wróć do stabilnych aktualizacji';

  @override
  String get devOptionsShorebirdChecking => 'Sprawdzanie kanału testowego…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Poprawka testowa jest gotowa do zastosowania.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Brak poprawki testowej dla tej wersji.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Pobrano. Uruchom aplikację ponownie, aby ją wczytać.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Wycofanie jest gotowe. Uruchom ponownie, aby wrócić do wersji bazowej.';

  @override
  String get devOptionsShorebirdApplying => 'Pobieranie i instalowanie…';

  @override
  String get devOptionsShorebirdApplied =>
      'Zainstalowano. Uruchom aplikację ponownie, aby ją wczytać.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Nic nie zainstalowano. Sprawdź kanał testowy i spróbuj ponownie.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Wybieranie stabilnego kanału…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Wybrano stabilny kanał. Uruchom aplikację ponownie, aby sprawdzić stabilną poprawkę.';

  @override
  String get devOptionsShorebirdFailure =>
      'Nie udało się. Szczegóły znajdziesz w dziennikach.';

  @override
  String get devOptionsPageLoadTimes => 'Czasy ładowania stron';

  @override
  String get devOptionsNoPageLoads =>
      'Brak zarejestrowanych ładowań stron.\nPorusz się po aplikacji, żeby zobaczyć dane.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Widoczne: ${visibleMs}ms  |  Dane: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Najwolniejsze ekrany';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format odtwarzania wideo';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Przełączyć środowisko?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Przełączyć na $envName?\n\nTo wyczyści cache wideo i połączy ponownie z nowym przekaźnikiem.';
  }

  @override
  String get devOptionsCancel => 'Anuluj';

  @override
  String get devOptionsSwitch => 'Przełącz';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Przełączono na $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Przełączono na $formatName — cache wyczyszczony';
  }

  @override
  String get featureFlagTitle => 'Flagi funkcji';

  @override
  String get featureFlagResetAllTooltip =>
      'Zresetuj wszystkie flagi do domyślnych';

  @override
  String get featureFlagError => 'Błąd';

  @override
  String get relaySettingsTitle => 'Przekaźniki';

  @override
  String get relaySettingsInfoTitle =>
      'Divine to otwarty system - ty kontrolujesz swoje połączenia';

  @override
  String get relaySettingsInfoDescription =>
      'Te przekaźniki dystrybuują twoje treści w zdecentralizowanej sieci Nostr. Możesz dodawać lub usuwać przekaźniki według uznania.';

  @override
  String get relaySettingsLearnMoreNostr => 'Dowiedz się więcej o Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Znajdź publiczne przekaźniki na nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Aplikacja niedziałająca';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine wymaga przynajmniej jednego przekaźnika, żeby wczytać filmy, publikować treści i synchronizować dane.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Przywróć domyślny przekaźnik';

  @override
  String get relaySettingsAddCustomRelay => 'Dodaj własny przekaźnik';

  @override
  String get relaySettingsAddRelay => 'Dodaj przekaźnik';

  @override
  String get relaySettingsRetry => 'Spróbuj ponownie';

  @override
  String get relaySettingsNoStats => 'Brak dostępnych statystyk';

  @override
  String get relaySettingsConnection => 'Połączenie';

  @override
  String get relaySettingsConnected => 'Połączono';

  @override
  String get relaySettingsDisconnected => 'Rozłączono';

  @override
  String get relaySettingsSessionDuration => 'Czas trwania sesji';

  @override
  String get relaySettingsLastConnected => 'Ostatnie połączenie';

  @override
  String get relaySettingsDisconnectedLabel => 'Rozłączono';

  @override
  String get relaySettingsReason => 'Powód';

  @override
  String get relaySettingsActiveSubscriptions => 'Aktywne subskrypcje';

  @override
  String get relaySettingsTotalSubscriptions => 'Łączna liczba subskrypcji';

  @override
  String get relaySettingsEventsReceived => 'Odebrane zdarzenia';

  @override
  String get relaySettingsEventsSent => 'Wysłane zdarzenia';

  @override
  String get relaySettingsRequestsThisSession => 'Żądania w tej sesji';

  @override
  String get relaySettingsFailedRequests => 'Nieudane żądania';

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Wczytywanie informacji o przekaźniku...';

  @override
  String get relaySettingsAboutRelay => 'O przekaźniku';

  @override
  String get relaySettingsSupportedNips => 'Obsługiwane NIP-y';

  @override
  String get relaySettingsSoftware => 'Oprogramowanie';

  @override
  String get relaySettingsViewWebsite => 'Zobacz stronę';

  @override
  String get relaySettingsRemoveRelayTitle => 'Usunąć przekaźnik?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Na pewno chcesz usunąć ten przekaźnik?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Usunąć przekaźnik Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Usunięcie przekaźnika Divine pogorszy działanie aplikacji. Filmy, publikowanie i synchronizacja mogą być mniej niezawodne. Rób to tylko, jeśli znasz się na Nostr.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Usuń przekaźnik';

  @override
  String get relaySettingsCancel => 'Anuluj';

  @override
  String get relaySettingsRemove => 'Usuń';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Usunięto przekaźnik: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay =>
      'Nie udało się usunąć przekaźnika';

  @override
  String get relaySettingsForcingReconnection =>
      'Wymuszanie ponownego połączenia z przekaźnikiem...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Połączono z $count przekaźnikami!',
      many: 'Połączono z $count przekaźnikami!',
      few: 'Połączono z $count przekaźnikami!',
      one: 'Połączono z 1 przekaźnikiem!',
    );
    return '$_temp0';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Nie udało się połączyć z przekaźnikami. Sprawdź połączenie z siecią.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Zapisano na tym urządzeniu. Zsynchronizujemy to z Twoim kontem, gdy publikowanie znów zadziała.';

  @override
  String get relaySettingsAddRelayTitle => 'Dodaj przekaźnik';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Wprowadź URL WebSocket przekaźnika, który chcesz dodać:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Przeglądaj publiczne przekaźniki na nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Dodaj';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Dodano przekaźnik: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Nie udało się dodać przekaźnika. Sprawdź URL i spróbuj ponownie.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL przekaźnika musi zaczynać się od wss:// lub ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'URL przekaźnika musi używać wss:// (ws:// jest dozwolony tylko dla localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Przywrócono domyślny przekaźnik: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Nie udało się przywrócić domyślnego przekaźnika. Sprawdź połączenie z siecią.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Nie można otworzyć przeglądarki';

  @override
  String get relaySettingsFailedToOpenLink => 'Nie udało się otworzyć linku';

  @override
  String get relaySettingsExternalRelay => 'Zewnętrzny przekaźnik';

  @override
  String get relaySettingsNotConnected => 'Niepołączony';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Rozłączono $duration temu';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count sub.';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count zdarzeń';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration temu';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine używa protokołu Nostr do zdecentralizowanego publikowania. Twoje treści żyją na przekaźnikach, które wybierasz, a twoje klucze są twoją tożsamością.';

  @override
  String get nostrSettingsSectionNetwork => 'Sieć';

  @override
  String get nostrSettingsSectionAccount => 'Konto';

  @override
  String get nostrSettingsSectionDangerZone => 'Strefa zagrożenia';

  @override
  String get nostrSettingsRelays => 'Przekaźniki';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Zarządzaj połączeniami z przekaźnikami Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostyka przekaźników';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debuguj łączność z przekaźnikami i problemy sieciowe';

  @override
  String get nostrSettingsMediaServers => 'Serwery mediów';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Skonfiguruj serwery uploadu Blossom';

  @override
  String get settingsDeveloperOptions => 'Opcje deweloperskie';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Przełącznik środowiska i ustawienia debugowania';

  @override
  String get nostrSettingsKeyManagement => 'Zarządzanie kluczami';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Eksportuj, twórz kopie zapasowe i przywracaj swoje klucze Nostr';

  @override
  String get nostrSettingsClientAttribution => 'Atrybucja klienta';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Dodawaj tag klienta Divine do publikowanych zdarzeń, aby inne aplikacje Nostr mogły je poprawnie przypisać. Bez niego zgłoszenia, które wysyłasz, mają mniejszą wagę przy przeglądzie przez naszych moderatorów.';

  @override
  String get nostrSettingsMoveAccount => 'Przenieś swoje konto';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Pobierz swoje archiwum i przenieś posty oraz filmy do innego relaya lub serwera multimediów.';

  @override
  String get nostrSettingsRemoveKeys => 'Usuń klucze z urządzenia';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Usuń swój klucz prywatny tylko z tego urządzenia. Twoje treści zostają na przekaźnikach, ale do ponownego dostępu do konta potrzebna będzie kopia zapasowa nsec.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Nie udało się usunąć tego konta z tego urządzenia. Spróbuj ponownie.';

  @override
  String get nostrSettingsDeleteAccount => 'Usuń konto i dane';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Wysyła żądania usunięcia twoich treści i wylogowuje cię na tym urządzeniu. Przekaźniki, klienty, indeksy wyszukiwania i inne zalogowane urządzenia mogą zachować kopie.';

  @override
  String get relayDiagnosticTitle => 'Diagnostyka przekaźnika';

  @override
  String get relayDiagnosticRefreshTooltip => 'Odśwież diagnostykę';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Ostatnie odświeżenie: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status przekaźnika';

  @override
  String get relayDiagnosticInitialized => 'Zainicjalizowany';

  @override
  String get relayDiagnosticReady => 'Gotowy';

  @override
  String get relayDiagnosticNotInitialized => 'Nie zainicjalizowany';

  @override
  String get relayDiagnosticDatabaseEvents => 'Zdarzenia w bazie danych';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Aktywne subskrypcje';

  @override
  String get relayDiagnosticExternalRelays => 'Zewnętrzne przekaźniki';

  @override
  String get relayDiagnosticConfigured => 'Skonfigurowane';

  @override
  String relayDiagnosticRelayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count przekaźnika',
      many: '$count przekaźników',
      few: '$count przekaźniki',
      one: '1 przekaźnik',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Połączono';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Zdarzenia wideo';

  @override
  String get relayDiagnosticHomeFeed => 'Kanał główny';

  @override
  String relayDiagnosticVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticDiscovery => 'Odkrywanie';

  @override
  String get relayDiagnosticLoading => 'Wczytywanie';

  @override
  String get relayDiagnosticYes => 'Tak';

  @override
  String get relayDiagnosticNo => 'Nie';

  @override
  String get relayDiagnosticTestDirectQuery => 'Testuj bezpośrednie zapytanie';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Łączność sieciowa';

  @override
  String get relayDiagnosticRunNetworkTest => 'Uruchom test sieci';

  @override
  String get relayDiagnosticBlossomServer => 'Serwer Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testuj wszystkie endpointy';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Błąd';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Bazowy URL';

  @override
  String get relayDiagnosticSummary => 'Podsumowanie';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (śr. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retestuj wszystko';

  @override
  String get relayDiagnosticRetrying => 'Ponawianie...';

  @override
  String get relayDiagnosticRetryConnection => 'Ponów połączenie';

  @override
  String get relayDiagnosticTroubleshooting => 'Rozwiązywanie problemów';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Zielony status = Połączono i działa\n• Czerwony status = Połączenie nieudane\n• Jeśli test sieci nie powiedzie się, sprawdź połączenie z internetem\n• Jeśli przekaźniki są skonfigurowane, ale nie połączone, dotknij \"Ponów połączenie\"\n• Zrzut ekranu tego ekranu pomoże w debugowaniu';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Wszystkie endpointy REST działają!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Niektóre endpointy REST nie działają - zobacz szczegóły powyżej';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Znaleziono $count zdarzenia wideo w bazie',
      many: 'Znaleziono $count zdarzeń wideo w bazie',
      few: 'Znaleziono $count zdarzenia wideo w bazie',
      one: 'Znaleziono 1 zdarzenie wideo w bazie',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'Zapytanie nieudane. Spróbuj ponownie.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Połączono z $count przekaźnikami!',
      many: 'Połączono z $count przekaźnikami!',
      few: 'Połączono z $count przekaźnikami!',
      one: 'Połączono z 1 przekaźnikiem!',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Nie udało się połączyć z żadnym przekaźnikiem';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Ponowne połączenie nieudane. Spróbuj ponownie.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Połączono i uwierzytelniono';

  @override
  String get relayDiagnosticConnectedOnly => 'Połączono';

  @override
  String get relayDiagnosticNotConnected => 'Nie połączono';

  @override
  String get relayDiagnosticNoRelaysConfigured =>
      'Brak skonfigurowanych przekaźników';

  @override
  String get relayDiagnosticFailed => 'Nieudane';

  @override
  String get notificationSettingsTitle => 'Powiadomienia';

  @override
  String get notificationSettingsResetTooltip => 'Zresetuj do domyślnych';

  @override
  String get notificationSettingsTypes => 'Typy powiadomień';

  @override
  String get notificationSettingsLikes => 'Polubienia';

  @override
  String get notificationSettingsLikesSubtitle => 'Gdy ktoś polubi twoje filmy';

  @override
  String get notificationSettingsComments => 'Komentarze';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Gdy ktoś skomentuje twoje filmy';

  @override
  String get notificationSettingsFollows => 'Obserwacje';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Gdy ktoś zacznie cię obserwować';

  @override
  String get notificationSettingsMentions => 'Wzmianki';

  @override
  String get notificationSettingsMentionsSubtitle =>
      'Gdy zostaniesz wspomniany';

  @override
  String get notificationSettingsReposts => 'Reposty';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Gdy ktoś repostuje twoje filmy';

  @override
  String get notificationSettingsNewPosts => 'Nowe vine\'y';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Gdy ktoś, kogo obserwujesz, publikuje';

  @override
  String get notificationSettingsActions => 'Akcje';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Oznacz wszystkie jako przeczytane';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Oznacz wszystkie powiadomienia jako przeczytane';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Wszystkie powiadomienia oznaczone jako przeczytane';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Nie udało się oznaczyć wszystkich jako przeczytane';

  @override
  String get notificationSettingsResetToDefaults =>
      'Ustawienia zresetowane do domyślnych';

  @override
  String get notificationSettingsAbout => 'O powiadomieniach';

  @override
  String get notificationSettingsAboutDescription =>
      'Powiadomienia są zasilane przez protokół Nostr. Aktualizacje w czasie rzeczywistym zależą od twojego połączenia z przekaźnikami Nostr. Niektóre powiadomienia mogą mieć opóźnienia.';

  @override
  String get safetySettingsWhatYouSee => 'CO WIDZISZ';

  @override
  String get safetySettingsWhatYouPublish => 'CO PUBLIKUJESZ';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Pokazuj tylko filmy hostowane na Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ukryj filmy serwowane z innych hostów mediów';

  @override
  String get safetySettingsModeration => 'MODERACJA';

  @override
  String get safetySettingsBlockedUsers => 'ZABLOKOWANI UŻYTKOWNICY';

  @override
  String get safetySettingsAgeVerification => 'WERYFIKACJA WIEKU';

  @override
  String get safetySettingsAgeConfirmation =>
      'Potwierdzam, że mam 18 lat lub więcej';

  @override
  String get safetySettingsAgeRequired =>
      'Wymagane do oglądania treści dla dorosłych';

  @override
  String get safetySettingsAgeLockedForMinor => 'Zablokowane dla twojego konta';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Oficjalna usługa moderacji (domyślnie włączona)';

  @override
  String get safetySettingsPeopleIFollow => 'Osoby, które obserwuję';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Subskrybuj etykiety od osób, które obserwujesz';

  @override
  String get safetySettingsAddCustomLabeler => 'Dodaj własny etykietę';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Wprowadź npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'Dodaj własną etykietę';

  @override
  String get safetySettingsRemoveLabeler => 'Usuń etykietę';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Wprowadź adres npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Brak zablokowanych użytkowników';

  @override
  String get safetySettingsUnblock => 'Odblokuj';

  @override
  String get safetySettingsUserUnblocked => 'Użytkownik odblokowany';

  @override
  String get safetySettingsCancel => 'Anuluj';

  @override
  String get safetySettingsAdd => 'Dodaj';

  @override
  String get analyticsTitle => 'Statystyki twórcy';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostyka';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Przełącz diagnostykę';

  @override
  String get analyticsRetry => 'Spróbuj ponownie';

  @override
  String get analyticsUnableToLoad => 'Nie można wczytać statystyk.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Zaloguj się, żeby zobaczyć statystyki twórcy.';

  @override
  String get analyticsViewDataUnavailable =>
      'Wyświetlenia są aktualnie niedostępne z przekaźnika dla tych postów. Metryki polubień, komentarzy i repostów są nadal dokładne.';

  @override
  String get analyticsViewDataTitle => 'Dane wyświetleń';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Zaktualizowano $time • Wyniki używają polubień, komentarzy, repostów i wyświetleń/pętli z Funnelcake, gdy są dostępne.';
  }

  @override
  String get analyticsVideos => 'Filmy';

  @override
  String get analyticsViews => 'Wyświetlenia';

  @override
  String get analyticsInteractions => 'Interakcje';

  @override
  String get analyticsEngagement => 'Zaangażowanie';

  @override
  String get analyticsFollowers => 'Obserwujących';

  @override
  String get analyticsAvgPerPost => 'Śr./post';

  @override
  String get analyticsInteractionMix => 'Miks interakcji';

  @override
  String get analyticsLikes => 'Polubienia';

  @override
  String get analyticsComments => 'Komentarze';

  @override
  String get analyticsReposts => 'Reposty';

  @override
  String get analyticsPerformanceHighlights => 'Najważniejsze wyniki';

  @override
  String get analyticsMostViewed => 'Najczęściej oglądane';

  @override
  String get analyticsMostDiscussed => 'Najczęściej dyskutowane';

  @override
  String get analyticsMostReposted => 'Najczęściej repostowane';

  @override
  String get analyticsNoVideosYet => 'Brak filmów';

  @override
  String get analyticsViewDataUnavailableShort => 'Dane wyświetleń niedostępne';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count wyświetleń';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count komentarzy';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count repostów';
  }

  @override
  String get analyticsTopContent => 'Najlepsze treści';

  @override
  String get analyticsPublishPrompt =>
      'Opublikuj kilka filmów, żeby zobaczyć rankingi.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Prawa strona % = Wskaźnik zaangażowania (interakcje podzielone przez wyświetlenia).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Wskaźnik zaangażowania wymaga danych wyświetleń; wartości pokazują się jako N/D, dopóki wyświetlenia nie są dostępne.';

  @override
  String get analyticsEngagementLabel => 'Zaangażowanie';

  @override
  String get analyticsViewsUnavailable => 'wyświetlenia niedostępne';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interakcji';
  }

  @override
  String get analyticsPostAnalytics => 'Statystyki posta';

  @override
  String get analyticsOpenPost => 'Otwórz post';

  @override
  String get analyticsRecentDailyInteractions => 'Niedawne dzienne interakcje';

  @override
  String get analyticsNoActivityYet => 'Brak aktywności w tym zakresie.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interakcje = polubienia + komentarze + reposty według daty posta.';

  @override
  String get analyticsDailyBarExplainer =>
      'Długość paska jest względem twojego największego dnia w tym oknie.';

  @override
  String get analyticsAudienceSnapshot => 'Snapshot widowni';

  @override
  String analyticsFollowersCount(String count) {
    return 'Obserwujących: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Obserwowanych: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Podziały widowni źródło/geo/czas pojawią się, gdy Funnelcake doda endpointy statystyk widowni.';

  @override
  String get analyticsRetention => 'Retencja';

  @override
  String get analyticsRetentionWithViews =>
      'Krzywa retencji i podział czasu oglądania pojawią się, gdy retencja per-sekundę/per-kubeł przyjdzie z Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Dane retencji niedostępne, dopóki statystyki wyświetleń i czasu oglądania nie zostaną zwrócone przez Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostyka';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Łącznie filmów: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Z wyświetleniami: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Brakujące wyświetlenia: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Nawodnione (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Nawodnione (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Źródła: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Użyj danych testowych';

  @override
  String get analyticsNa => 'N/D';

  @override
  String get authCreateNewAccount => 'Utwórz nowe konto Divine';

  @override
  String get authCreateNewAccountShort => 'Utwórz nowe konto';

  @override
  String get authSignInDifferentAccount => 'Zaloguj się na inne konto';

  @override
  String get authUseAnotherAccount => 'Użyj innego konta';

  @override
  String authContinueAs(String displayName) {
    return 'Kontynuuj jako $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Twoje szkice i klipy są zapisane dla tego konta';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Zalogowanie się tutaj ukryje te szkice i klipy';

  @override
  String get authTermsPrefix =>
      'Wybierając opcję poniżej, potwierdzasz, że masz co najmniej 16 lat (lub przeszedłeś(-aś) ';

  @override
  String get authTermsAgeAuthorizationCta => 'weryfikację wieku Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') i zgadzasz się z ';

  @override
  String get authTermsOfService => 'Regulaminem';

  @override
  String get authPrivacyPolicy => 'Polityką prywatności';

  @override
  String get authTermsAnd => ', oraz ';

  @override
  String get authSafetyStandards => 'Standardami bezpieczeństwa';

  @override
  String get authAmberNotInstalled => 'Aplikacja Amber nie jest zainstalowana';

  @override
  String get authAmberConnectionFailed => 'Nie udało się połączyć z Amber';

  @override
  String get authPasswordResetSent =>
      'Jeśli konto z tym e-mailem istnieje, link do resetu hasła został wysłany.';

  @override
  String get authSignInTitle => 'Zaloguj się';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Hasło';

  @override
  String get authConfirmPasswordLabel => 'Potwierdź hasło';

  @override
  String get authEmailRequired => 'E-mail jest wymagany';

  @override
  String get authEmailInvalid => 'Wprowadź prawidłowy e-mail';

  @override
  String get authPasswordRequired => 'Hasło jest wymagane';

  @override
  String get authConfirmPasswordRequired => 'Potwierdź swoje hasło';

  @override
  String get authPasswordsDoNotMatch => 'Hasła nie pasują do siebie';

  @override
  String get authForgotPassword => 'Zapomniałeś hasła?';

  @override
  String get authImportNostrKey => 'Importuj klucz Nostr';

  @override
  String get authConnectSignerApp => 'Połącz z aplikacją do podpisywania';

  @override
  String get authSignInWithAmber => 'Zaloguj się przez Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Zaloguj się przez rozszerzenie przeglądarki';

  @override
  String get authNip07ConnectionFailed =>
      'Nie udało się połączyć z rozszerzeniem przeglądarki.';

  @override
  String get authNip07ExtensionNotFound =>
      'Nie znaleziono rozszerzenia przeglądarki. Zainstaluj Alby, nos2x lub inne rozszerzenie zgodne z NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opcje logowania';

  @override
  String get authInfoEmailPasswordTitle => 'E-mail i hasło';

  @override
  String get authInfoEmailPasswordDescription =>
      'Zaloguj się na swoje konto Divine. Jeśli rejestrowałeś się z e-mailem i hasłem, użyj ich tutaj.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Masz już tożsamość Nostr? Importuj swój klucz prywatny nsec z innego klienta.';

  @override
  String get authInfoSignerAppTitle => 'Aplikacja do podpisywania';

  @override
  String get authInfoSignerAppDescription =>
      'Połącz przez zgodnego z NIP-46 zdalnego sygnatariusza, jak nsecBunker, dla lepszego bezpieczeństwa kluczy.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Użyj aplikacji Amber na Androidzie, żeby bezpiecznie zarządzać kluczami Nostr.';

  @override
  String get authInfoBrowserExtensionTitle => 'Rozszerzenie przeglądarki';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Zaloguj się przez rozszerzenie przeglądarki NIP-07, takie jak Alby lub nos2x. Twoje klucze pozostają w rozszerzeniu — Divine nigdy ich nie widzi.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Nieprawidłowy e-mail lub hasło. Spróbuj ponownie.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Zweryfikuj swój e-mail przed zalogowaniem — sprawdź link w skrzynce odbiorczej.';

  @override
  String get authSignInErrorInvalidEmail =>
      'To nie wygląda na prawidłowy adres e-mail.';

  @override
  String get authSignInErrorNetwork =>
      'Nie można połączyć się z serwerem. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get authSignInErrorGeneric => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Nie wiesz, jak zalogowałeś się ostatnim razem? ';

  @override
  String get authSignInOptionsHintCta => 'Zobacz wszystkie opcje logowania';

  @override
  String get authCreateAccountTitle => 'Utwórz konto';

  @override
  String get authBackToInviteCode => 'Wróć do kodu zaproszenia';

  @override
  String get authUseDivineNoBackup => 'Używaj Divine bez kopii zapasowej';

  @override
  String get authSkipConfirmTitle => 'Ostatnia rzecz...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Jesteś w środku! Utworzymy bezpieczny klucz, który zasila twoje konto Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Bez e-maila twój klucz to jedyny sposób, w jaki Divine wie, że to konto należy do ciebie.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Możesz uzyskać dostęp do klucza w aplikacji, ale jeśli nie jesteś techniczny, polecamy dodanie e-maila i hasła teraz. Łatwiej będzie się logować i przywrócić konto, jeśli zgubisz lub zresetujesz to urządzenie.';

  @override
  String get authAddEmailPassword => 'Dodaj e-mail i hasło';

  @override
  String get authUseThisDeviceOnly => 'Używaj tylko tego urządzenia';

  @override
  String get authCompleteRegistration => 'Dokończ rejestrację';

  @override
  String get authVerifying => 'Weryfikowanie...';

  @override
  String get authVerificationLinkSent => 'Wysłaliśmy link weryfikacyjny do:';

  @override
  String get authClickVerificationLink =>
      'Kliknij link w e-mailu, żeby\ndokończyć rejestrację.';

  @override
  String get authPleaseWaitVerifying => 'Czekaj, weryfikujemy twój e-mail...';

  @override
  String get authWaitingForVerification => 'Czekam na weryfikację';

  @override
  String get authOpenEmailApp => 'Otwórz aplikację e-mail';

  @override
  String get authVerificationPinPrompt => 'Albo wpisz 6-cyfrowy kod z e-maila';

  @override
  String get authVerificationPinFieldLabel => '6-cyfrowy kod';

  @override
  String get authVerificationPinSubmit => 'Zweryfikuj kod';

  @override
  String get authVerificationResendPrompt => 'Nie dotarło?';

  @override
  String get authVerificationResend => 'Wyślij ponownie';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Wyślij ponownie za $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Nie udało się wysłać e-maila ponownie. Spróbuj jeszcze raz.';

  @override
  String get authVerificationResendExpired =>
      'Ta rejestracja wygasła. Zacznij od nowa, aby dostać świeży kod.';

  @override
  String get authVerificationResendUnavailable =>
      'Ponowne wysłanie jest teraz niedostępne. Użyj 6-cyfrowego kodu z e-maila, który już wysłaliśmy.';

  @override
  String get authVerificationPollingStopped =>
      'Przestaliśmy sprawdzać za ciebie. Wpisz 6-cyfrowy kod z e-maila, aby dokończyć logowanie.';

  @override
  String get authWelcomeToDivine => 'Witaj w Divine!';

  @override
  String get authEmailVerified => 'Twój e-mail został zweryfikowany.';

  @override
  String get authSigningYouIn => 'Logujemy cię';

  @override
  String get authErrorTitle => 'O nie.';

  @override
  String get authVerificationFailed =>
      'Nie udało nam się zweryfikować twojego e-maila.\nSpróbuj ponownie.';

  @override
  String get authStartOver => 'Zacznij od nowa';

  @override
  String get authEmailVerifiedLogin =>
      'E-mail zweryfikowany! Zaloguj się, żeby kontynuować.';

  @override
  String get authVerificationLinkExpired =>
      'Ten link weryfikacyjny nie jest już ważny.';

  @override
  String get authVerificationConnectionError =>
      'Nie można zweryfikować e-maila. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get authWaitlistConfirmTitle => 'Jesteś w środku!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Będziemy dzielić się aktualizacjami na $email.\nGdy będą dostępne kolejne kody zaproszeń, wyślemy je do ciebie.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Spróbuj ponownie';

  @override
  String get authContactSupport => 'Skontaktuj się z pomocą';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Nie można otworzyć $email';
  }

  @override
  String get authAddInviteCode => 'Dodaj swój kod zaproszenia';

  @override
  String get authInviteCodeLabel => 'Kod zaproszenia';

  @override
  String get authEnterYourCode => 'Wpisz swój kod';

  @override
  String get authNext => 'Dalej';

  @override
  String get authJoinWaitlist => 'Dołącz do listy oczekujących';

  @override
  String get authJoinWaitlistTitle => 'Dołącz do listy oczekujących';

  @override
  String get authJoinWaitlistDescription =>
      'Podaj swój e-mail, a będziemy wysyłać aktualizacje, gdy dostęp się otworzy.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Wysyłajcie mi inspiracje od Divine';

  @override
  String get authInviteAccessHelp => 'Pomoc z dostępem z zaproszenia';

  @override
  String get authGeneratingConnection => 'Generowanie połączenia...';

  @override
  String get authConnectedAuthenticating => 'Połączono! Uwierzytelnianie...';

  @override
  String get authConnectionTimedOut => 'Przekroczono czas połączenia';

  @override
  String get authApproveConnection =>
      'Upewnij się, że zatwierdziłeś połączenie w aplikacji do podpisywania.';

  @override
  String get authConnectionCancelled => 'Połączenie anulowane';

  @override
  String get authConnectionCancelledMessage => 'Połączenie zostało anulowane.';

  @override
  String get authConnectionFailed => 'Połączenie nieudane';

  @override
  String get authUnknownError => 'Wystąpił nieznany błąd.';

  @override
  String get authNostrConnectStartFailed =>
      'Nie udało się połączyć z aplikacją do podpisywania. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get authNostrConnectInvalidSession =>
      'Ten link do połączenia jest już nieważny. Utwórz nowy.';

  @override
  String get authNostrConnectSetupFailed =>
      'Prawie gotowe — nie udało się dokończyć logowania. Spróbuj ponownie.';

  @override
  String get authUrlCopied => 'URL skopiowany do schowka';

  @override
  String get authConnectToDivine => 'Połącz z Divine';

  @override
  String get authPasteBunkerUrl => 'Wklej URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'Nieprawidłowy URL bunker. Powinien zaczynać się od bunker://';

  @override
  String get authScanSignerApp =>
      'Zeskanuj aplikacją\ndo podpisywania, żeby połączyć.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Czekam na połączenie... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Kopiuj URL';

  @override
  String get authShare => 'Udostępnij';

  @override
  String get authAddBunker => 'Dodaj bunker';

  @override
  String get authCompatibleSignerApps =>
      'Kompatybilne aplikacje do podpisywania';

  @override
  String get authFailedToConnect => 'Nie udało się połączyć';

  @override
  String get authResetPasswordTitle => 'Zresetuj hasło';

  @override
  String get authResetPasswordSubtitle =>
      'Wprowadź nowe hasło. Musi mieć przynajmniej 8 znaków.';

  @override
  String get authNewPasswordLabel => 'Nowe hasło';

  @override
  String get authConfirmNewPasswordLabel => 'Potwierdź nowe hasło';

  @override
  String get authPasswordTooShort => 'Hasło musi mieć przynajmniej 8 znaków';

  @override
  String get authPasswordResetSuccess => 'Reset hasła udany. Zaloguj się.';

  @override
  String get authPasswordResetFailed => 'Reset hasła nieudany';

  @override
  String get authUnexpectedError =>
      'Wystąpił nieoczekiwany błąd. Spróbuj ponownie.';

  @override
  String get authUpdatePassword => 'Zaktualizuj hasło';

  @override
  String get authSecureAccountTitle => 'Zabezpiecz konto';

  @override
  String get authUnableToAccessKeys =>
      'Nie można uzyskać dostępu do twoich kluczy. Spróbuj ponownie.';

  @override
  String get authRegistrationFailed => 'Rejestracja nieudana';

  @override
  String get authRegistrationComplete =>
      'Rejestracja ukończona. Sprawdź e-mail.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'Nie udało się wysłać e-maila z resetem.';

  @override
  String get authSending => 'Wysyłanie...';

  @override
  String get authSignInButton => 'Zaloguj się';

  @override
  String get authVerificationErrorTimeout =>
      'Weryfikacja przekroczyła czas. Spróbuj zarejestrować się ponownie.';

  @override
  String get authVerificationErrorMissingCode =>
      'Weryfikacja nieudana — brak kodu autoryzacyjnego.';

  @override
  String get authVerificationErrorPollFailed =>
      'Weryfikacja nieudana. Spróbuj ponownie.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Błąd sieci podczas logowania. Spróbuj ponownie.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Weryfikacja nieudana. Spróbuj zarejestrować się ponownie.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Logowanie nieudane. Spróbuj zalogować się ręcznie.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Ten adres e-mail jest już zarejestrowany. Zaloguj się zamiast tego.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Ten kod nie pasuje. Sprawdź go i spróbuj ponownie.';

  @override
  String get authVerificationErrorPinExpired =>
      'Ten kod wygasł. Dotknij Wyślij ponownie, aby otrzymać nowy.';

  @override
  String get authVerificationErrorPinLocked =>
      'Zbyt wiele prób. Dotknij Wyślij ponownie, aby otrzymać nowy kod.';

  @override
  String get authVerificationErrorPinFailed =>
      'Nie udało się zweryfikować tego kodu. Spróbuj ponownie.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Wpisywanie kodu jest teraz niedostępne. Dotknij linku w e-mailu albo wyślij ponownie, aby otrzymać nowy.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Wpisz kod zaproszenia w formacie ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Ten kod zaproszenia nie wygląda na prawidłowy.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Ten kod zaproszenia został już użyty lub unieważniony.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Zaproszenia tego twórcy się skończyły';

  @override
  String get authInviteGateErrorUnavailable =>
      'Ten kod zaproszenia jest niedostępny. Zapisz się na listę oczekujących, a wyślemy zaproszenie, gdy zwolni się miejsce.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Nie udało się sprawdzić tego kodu. Spróbuj ponownie.';

  @override
  String get authInviteGateErrorUnknown =>
      'Coś poszło nie tak. Spróbuj ponownie ze swoim kodem zaproszenia.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Ten kod zaproszenia nie jest już dostępny. Wróć do kodu zaproszenia, dołącz do listy oczekujących lub skontaktuj się z pomocą.';

  @override
  String get authInviteErrorInvalid =>
      'Ten kod zaproszenia nie może być teraz użyty. Wróć do kodu zaproszenia, dołącz do listy oczekujących lub skontaktuj się z pomocą.';

  @override
  String get authInviteErrorTemporary =>
      'Nie mogliśmy teraz potwierdzić twojego zaproszenia. Wróć do kodu zaproszenia i spróbuj ponownie, lub skontaktuj się z pomocą.';

  @override
  String get authInviteErrorUnknown =>
      'Nie mogliśmy aktywować twojego zaproszenia. Wróć do kodu zaproszenia, dołącz do listy oczekujących lub skontaktuj się z pomocą.';

  @override
  String get shareSheetSave => 'Zapisz';

  @override
  String get shareSheetRemoveFromSaved => 'Usuń z zapisanych';

  @override
  String get shareSheetSaveToGallery => 'Zapisz w galerii';

  @override
  String get shareSheetSaveWithWatermark => 'Zapisz ze znakiem wodnym';

  @override
  String get shareSheetSaveVideo => 'Zapisz film';

  @override
  String get shareSheetAddToClips => 'Dodaj do klipów';

  @override
  String get shareSheetNameClipTitle => 'Nazwij ten klip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Wybierz nazwę, którą rozpoznasz w swojej bibliotece.';

  @override
  String get shareSheetClipTitleLabel => 'Tytuł klipu';

  @override
  String get shareSheetSaveClip => 'Zapisz klip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Zapisano „$title” do klipów';
  }

  @override
  String get shareSheetUntitledClip => 'Klip bez tytułu';

  @override
  String get shareSheetAddToClipsFailed => 'Nie można dodać do klipów';

  @override
  String get shareSheetAddToList => 'Dodaj do listy';

  @override
  String get shareSheetCopy => 'Kopiuj';

  @override
  String get shareSheetShareVia => 'Udostępnij przez';

  @override
  String get shareSheetEventJson => 'JSON zdarzenia';

  @override
  String get shareSheetEventId => 'ID zdarzenia';

  @override
  String get shareSheetMoreActions => 'Więcej akcji';

  @override
  String get shareSheetCrosspost => 'Crosspostuj';

  @override
  String get crosspostSheetTitle => 'Crosspostuj ten film';

  @override
  String get crosspostSheetSubtitle =>
      'Wyślij go na połączone platformy. Publikacja może potrwać kilka minut.';

  @override
  String get crosspostSubmit => 'Crosspostuj';

  @override
  String get crosspostStatusQueued => 'W kolejce';

  @override
  String get crosspostStatusUploading => 'Przesyłanie';

  @override
  String get crosspostStatusProcessing => 'Przetwarzanie';

  @override
  String get crosspostStatusPosted => 'Opublikowano';

  @override
  String get crosspostStatusFailed => 'Niepowodzenie';

  @override
  String get crosspostStatusSkipped => 'Pominięto';

  @override
  String get crosspostStatusNeedsReauth => 'Wymaga ponownego połączenia';

  @override
  String get crosspostViewPost => 'Zobacz post';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Połącz ponownie $platform w ustawieniach crosspostingu, aby kontynuować publikowanie.';
  }

  @override
  String get crosspostReconnect => 'Połącz ponownie';

  @override
  String get crosspostErrorNotOwner =>
      'Crosspostować można tylko własne filmy.';

  @override
  String get crosspostErrorNotEligible =>
      'Ten film nie kwalifikuje się do crosspostingu.';

  @override
  String get crosspostErrorNotConnected => 'Ta platforma nie jest połączona.';

  @override
  String get crosspostErrorUnauthorized =>
      'Połącz konto ponownie i spróbuj jeszcze raz.';

  @override
  String get crosspostErrorNetwork =>
      'Nie udało się połączyć z usługą crosspostingu. Spróbuj ponownie za chwilę.';

  @override
  String get crosspostFailedGeneric => 'Crossposting nie powiódł się.';

  @override
  String get crosspostStillWorking =>
      'Wciąż pracujemy. Możesz to zamknąć — publikowanie będzie kontynuowane w tle.';

  @override
  String get crosspostDone => 'Gotowe';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Zapisano w rolce aparatu';

  @override
  String get watermarkDownloadShare => 'Udostępnij';

  @override
  String get watermarkDownloadDone => 'Gotowe';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Potrzebny dostęp do zdjęć';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Aby zapisać filmy, zezwól na dostęp do Zdjęć w Ustawieniach.';

  @override
  String get watermarkDownloadOpenSettings => 'Otwórz Ustawienia';

  @override
  String get watermarkDownloadNotNow => 'Nie teraz';

  @override
  String get watermarkDownloadFailed => 'Pobieranie nieudane';

  @override
  String get watermarkDownloadDismiss => 'Odrzuć';

  @override
  String get watermarkDownloadStageDownloading => 'Pobieranie filmu';

  @override
  String get watermarkDownloadStageWatermarking => 'Dodawanie znaku wodnego';

  @override
  String get watermarkDownloadStageSaving => 'Zapisywanie w rolce aparatu';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Pobieranie filmu z sieci...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Nakładanie znaku wodnego Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Zapisywanie filmu ze znakiem wodnym w rolce aparatu...';

  @override
  String get shareMenuBookmarks => 'Zakładki';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zestawu obserwowanych dostępne',
      many: '$count zestawów obserwowanych dostępnych',
      few: '$count zestawy obserwowanych dostępne',
      one: '1 zestaw obserwowanych dostępny',
    );
    return '$_temp0';
  }

  @override
  String get peopleListsAddToList => 'Dodaj do listy';

  @override
  String get peopleListsSheetTitle => 'Dodaj do listy';

  @override
  String get peopleListsEmptyTitle => 'Brak list';

  @override
  String get peopleListsEmptySubtitle =>
      'Utwórz listę, aby zacząć grupować osoby.';

  @override
  String get peopleListsCreateList => 'Utwórz listę';

  @override
  String get peopleListsNewListTitle => 'Nowa lista';

  @override
  String get peopleListsRouteTitle => 'Lista osób';

  @override
  String get peopleListsListNameLabel => 'Nazwa listy';

  @override
  String get peopleListsListNameHint => 'Bliscy znajomi';

  @override
  String get peopleListsCreateButton => 'Utwórz';

  @override
  String get peopleListsAddPeopleTitle => 'Dodaj osoby';

  @override
  String get peopleListsAddPeopleTooltip => 'Dodaj osoby';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Dodaj osoby do listy';

  @override
  String get peopleListsListNotFoundTitle => 'Lista nie znaleziona';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lista nie znaleziona. Mogła zostać usunięta.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Ta lista mogła zostać usunięta.';

  @override
  String get peopleListsNoPeopleTitle => 'Brak osób na tej liście';

  @override
  String get peopleListsNoPeopleSubtitle => 'Dodaj osoby, aby zacząć';

  @override
  String get peopleListsNoVideosTitle => 'Brak filmów';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Filmy od członków listy pojawią się tutaj';

  @override
  String get peopleListsNoVideosAvailable => 'Brak dostępnych filmów';

  @override
  String get peopleListsFailedToLoadVideos => 'Nie udało się załadować filmów';

  @override
  String get peopleListsVideoNotAvailable => 'Film niedostępny';

  @override
  String get peopleListsBackToGridTooltip => 'Powrót do siatki';

  @override
  String get peopleListsErrorLoadingVideos => 'Błąd podczas ładowania filmów';

  @override
  String get peopleListsNoPeopleToAdd => 'Brak osób dostępnych do dodania.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Dodaj do $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Szukaj osób';

  @override
  String get peopleListsAddPeopleError =>
      'Nie udało się załadować osób. Spróbuj ponownie.';

  @override
  String get peopleListsAddPeopleRetry => 'Spróbuj ponownie';

  @override
  String get peopleListsAddButton => 'Dodaj';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Dodaj $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Na $count listach',
      many: 'Na $count listach',
      few: 'Na $count listach',
      one: 'Na 1 liście',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Usunąć $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Osoba zostanie usunięta z tej listy.';

  @override
  String get peopleListsRemove => 'Usuń';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Usunięto $name z listy';
  }

  @override
  String get peopleListsUndo => 'Cofnij';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil $name. Przytrzymaj, aby usunąć.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Zobacz profil $name';
  }

  @override
  String get shareMenuEditVideo => 'Edytuj film';

  @override
  String get shareMenuDeleteVideo => 'Usuń film';

  @override
  String shareMenuVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'To trwale usunie ten film z Divine. Może nadal pojawiać się w zewnętrznych klientach Nostr, które używają innych przekaźników.';

  @override
  String get shareMenuCancel => 'Anuluj';

  @override
  String get shareMenuDelete => 'Usuń';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Usuwanie nie jest jeszcze gotowe. Spróbuj ponownie za chwilę.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Możesz usuwać tylko własne filmy.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Zaloguj się ponownie i spróbuj usunąć.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Nie udało się podpisać żądania usunięcia. Spróbuj ponownie.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Przekaźnik nie przyjął tego żądania usunięcia. Spróbuj ponownie za chwilę.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Nie udało się połączyć z przekaźnikiem. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Usunięto. Nie wszystkie przekaźniki potwierdziły, więc może się jeszcze pojawiać w innych aplikacjach.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Nie udało się usunąć tego filmu. Spróbuj ponownie.';

  @override
  String get shareMenuUpdate => 'Zaktualizuj';

  @override
  String get shareMenuChangeCover => 'Zmień okładkę';

  @override
  String get shareMenuVideoUpdated => 'Film zaktualizowany pomyślnie';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszeń współpracowników nie zostało wysłanych.',
      one: '1 zaproszenie współpracownika nie zostało wysłane.',
    );
    return 'Film zaktualizowany, ale $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Zaloguj się ponownie i spróbuj jeszcze raz.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Ten film nie ma odtwarzalnego źródła, więc nie można go edytować.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Nie udało się podpisać zmiany. Spróbuj ponownie.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Przekaźnik nie przyjął zmiany. Spróbuj za chwilę.';

  @override
  String get videoUpdateErrorGeneric =>
      'Nie udało się zaktualizować tego filmu. Spróbuj ponownie.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Usunąć film?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Usuwanie filmu…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Film usunięty.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Film usunięty. Może minąć trochę czasu, zanim zniknie wszędzie.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Film usunięty, ale nie udało nam się usunąć każdej kopii. Skontaktuj się z pomocą.';

  @override
  String get authSessionExpired => 'Twoja sesja wygasła. Zaloguj się ponownie.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Nie udało się zalogować. Spróbuj ponownie.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Uwierzytelnianie przez WWW nie jest obsługiwane w trybie bezpiecznym. Użyj aplikacji mobilnej do bezpiecznego zarządzania kluczami.';

  @override
  String get webAuthEnterBunkerUri => 'Wprowadź URI bunker';

  @override
  String get webAuthConnectTitle => 'Połącz z Divine';

  @override
  String get webAuthChooseMethod =>
      'Wybierz preferowaną metodę uwierzytelnienia Nostr';

  @override
  String get webAuthBrowserExtension => 'Rozszerzenie przeglądarki';

  @override
  String get webAuthRecommended => 'ZALECANE';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Połącz ze zdalnym sygnatariuszem';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Wklej ze schowka';

  @override
  String get webAuthConnectToBunker => 'Połącz z Bunker';

  @override
  String get webAuthNewToNostr => 'Nowy w Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Zainstaluj rozszerzenie przeglądarki jak Alby lub nos2x dla najprostszego doświadczenia, lub użyj nsec bunker dla bezpiecznego zdalnego podpisywania.';

  @override
  String get soundsTitle => 'Dźwięki';

  @override
  String get soundsSearchHint => 'Szukaj dźwięków...';

  @override
  String get soundsSearchResults => 'Wyniki wyszukiwania';

  @override
  String get soundsNoSoundsFound => 'Nie znaleziono dźwięków';

  @override
  String get soundsNoSoundsFoundDescription => 'Spróbuj innego wyszukiwania';

  @override
  String get soundsSavedToLibrary => 'Zapisano w Dźwiękach';

  @override
  String get soundsAlreadySavedToLibrary => 'Już w Dźwiękach';

  @override
  String get soundsSavedLibraryTitle => 'Moje dźwięki';

  @override
  String get soundsSavedEmptyTitle => 'Brak zapisanych dźwięków';

  @override
  String get soundsSavedEmptyDescription =>
      'Stuknij Użyj dźwięku w wideo, aby zapisać go tutaj.';

  @override
  String get soundsRemoveSavedSound => 'Usuń dźwięk';

  @override
  String get savedSoundSaveAction => 'Zapisz';

  @override
  String get savedSoundPausePreviewAction => 'Wstrzymaj podgląd';

  @override
  String get savedSoundResumePreviewAction => 'Wznów podgląd';

  @override
  String get savedSoundDetailsSheetTitle => 'Szczegóły dźwięku';

  @override
  String get savedSoundRemoveConfirmTitle => 'Usunąć ten dźwięk?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Zniknie z Twojej biblioteki, ale możesz zapisać go ponownie z dowolnego filmu, który go używa.';

  @override
  String get soundsRemovedFromLibrary => 'Usunięto z Dźwięków';

  @override
  String get soundsSaveFailed =>
      'Nie udało się zapisać tego dźwięku. Spróbuj ponownie.';

  @override
  String get soundsRemoveFailed =>
      'Nie udało się usunąć tego dźwięku. Spróbuj ponownie.';

  @override
  String get soundSyncStatusSyncing => 'Synchronizowanie twoich dźwięków…';

  @override
  String get soundSyncStatusSynced => 'Dźwięki są aktualne';

  @override
  String get soundSyncStatusFailed =>
      'Nie udało się zsynchronizować twoich dźwięków. Spróbujemy ponownie.';

  @override
  String get soundSyncStatusLocked =>
      'Nie można odblokować zsynchronizowanej biblioteki na tym urządzeniu.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMoreOptions => 'Więcej opcji';

  @override
  String profileBlockedUser(String name) {
    return 'Zablokowano $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Odblokowano $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Przestano obserwować $name';
  }

  @override
  String get profileFeedError =>
      'Nie można połączyć się z serwerem. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get profileFeedLoadMoreError =>
      'Nie udało się wczytać kolejnych filmów. Pociągnij, aby odświeżyć.';

  @override
  String get notificationsTabAll => 'Wszystkie';

  @override
  String get notificationsTabLikes => 'Polubienia';

  @override
  String get notificationsTabComments => 'Komentarze';

  @override
  String get notificationsTabFollows => 'Obserwacje';

  @override
  String get notificationsTabReposts => 'Reposty';

  @override
  String get notificationsFailedToLoad => 'Nie udało się wczytać powiadomień';

  @override
  String get notificationsRetry => 'Spróbuj ponownie';

  @override
  String get notificationsRefreshError =>
      'Nie udało się odświeżyć — pokazuję dostępne';

  @override
  String get notificationsUnreadPrefix => 'Nieprzeczytane powiadomienie';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieprzeczytanego powiadomienia',
      many: '$count nieprzeczytanych powiadomień',
      few: '$count nieprzeczytane powiadomienia',
      one: '1 nieprzeczytane powiadomienie',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Zobacz profil użytkownika $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Zobacz profile';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Miniatura wideo dla $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Miniatura wideo';

  @override
  String get notificationsInviteSingular =>
      'Masz 1 zaproszenie do podzielenia się z przyjacielem!';

  @override
  String notificationsInvitePlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Masz $count zaproszenia do podzielenia się z przyjaciółmi!',
      many: 'Masz $count zaproszeń do podzielenia się z przyjaciółmi!',
      few: 'Masz $count zaproszenia do podzielenia się z przyjaciółmi!',
      one: 'Masz 1 zaproszenie do podzielenia się z przyjaciółmi!',
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
  String get notificationsVideoUnavailable => 'Film niedostępny';

  @override
  String get feedFailedToLoadVideos => 'Nie udało się wczytać filmów';

  @override
  String get feedRetry => 'Spróbuj ponownie';

  @override
  String get feedNoFollowedUsers =>
      'Nie obserwujesz nikogo.\nZacznij obserwować, żeby zobaczyć ich filmy tutaj.';

  @override
  String get feedModeForYou => 'Dla ciebie';

  @override
  String get feedModeNew => 'Nowe';

  @override
  String get feedModeFollowing => 'Obserwowane';

  @override
  String get feedModeClassics => 'Klasyki';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Tryb kanału: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Autor filmu: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Awatar autora';

  @override
  String get feedForYouEmpty =>
      'Twój kanał Dla Ciebie jest pusty.\nOdkrywaj filmy i obserwuj twórców, aby go ukształtować.';

  @override
  String get feedFollowingEmpty =>
      'Brak filmów od osób, które obserwujesz.\nZnajdź twórców, których lubisz i zacznij ich obserwować.';

  @override
  String get feedLatestEmpty => 'Brak nowych filmów.\nWróć tu wkrótce.';

  @override
  String get feedClassicEmpty => 'Brak klasyków.\nWróć tu wkrótce.';

  @override
  String get feedExploreVideos => 'Odkrywaj filmy';

  @override
  String get feedLoadingMore => 'Wczytywanie kolejnych filmów…';

  @override
  String get feedRefreshed => 'Kanał odświeżony';

  @override
  String get uploadUploadingVideo => 'Przesyłanie filmu';

  @override
  String get postPublishConfirmationTitle => 'Opublikowano na twoim profilu';

  @override
  String get postPublishConfirmationView => 'Zobacz';

  @override
  String get postPublishConfirmationShare => 'Udostępnij';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Miniatura właśnie opublikowanego filmu';

  @override
  String get userSearchNoResults => 'Nie znaleziono użytkowników';

  @override
  String get userPickerFilterByNameHint => 'Filtruj po nazwie...';

  @override
  String get userPickerSearchByNameHint => 'Szukaj po nazwie...';

  @override
  String get userPickerClearSearchSemantics => 'Wyczyść wyszukiwanie';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name już dodano';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Wybierz $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Usuń $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Twoja ekipa czeka';

  @override
  String get userPickerEmptyFollowListBody =>
      'Obserwuj osoby, z którymi nadajesz na tych samych falach. Gdy obserwujecie się wzajemnie, możecie współtworzyć.';

  @override
  String get userPickerGoBack => 'Wróć';

  @override
  String get userPickerTypeNameToSearch => 'Wpisz nazwę, aby wyszukać';

  @override
  String get userPickerUnavailable =>
      'Wyszukiwanie użytkowników jest niedostępne. Spróbuj ponownie później.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Wyszukiwanie nie powiodło się. Spróbuj ponownie.';

  @override
  String get forgotPasswordTitle => 'Zresetuj hasło';

  @override
  String get forgotPasswordDescription =>
      'Wprowadź swój adres e-mail, a wyślemy ci link do zresetowania hasła.';

  @override
  String get forgotPasswordEmailLabel => 'Adres e-mail';

  @override
  String get forgotPasswordCancel => 'Anuluj';

  @override
  String get forgotPasswordSendLink => 'Wyślij link resetujący';

  @override
  String get ageVerificationContentWarning => 'Ostrzeżenie o treści';

  @override
  String get ageVerificationTitle => 'Weryfikacja wieku';

  @override
  String get ageVerificationAdultDescription =>
      'Ta treść została oznaczona jako potencjalnie zawierająca materiały dla dorosłych. Musisz mieć 18 lat lub więcej, żeby ją oglądać.';

  @override
  String get ageVerificationCreationDescription =>
      'Żeby używać aparatu i tworzyć treści, musisz mieć przynajmniej 16 lat.';

  @override
  String get ageVerificationAdultQuestion => 'Masz 18 lat lub więcej?';

  @override
  String get ageVerificationCreationQuestion => 'Masz 16 lat lub więcej?';

  @override
  String get ageVerificationNo => 'Nie';

  @override
  String get ageVerificationYes => 'Tak';

  @override
  String get navHome => 'Główna';

  @override
  String get navExplore => 'Odkrywaj';

  @override
  String get navInbox => 'Skrzynka';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Mój profil';

  @override
  String get navNotifications => 'Powiadomienia';

  @override
  String get navOpenCamera => 'Otwórz aparat';

  @override
  String get navExploreClassics => 'Klasyki';

  @override
  String get navExploreNewVideos => 'Nowe filmy';

  @override
  String get navExploreTrending => 'Na topie';

  @override
  String get navExploreForYou => 'Dla ciebie';

  @override
  String get navExploreLists => 'Listy';

  @override
  String get routeErrorTitle => 'Błąd';

  @override
  String get routeInvalidHashtag => 'Nieprawidłowy hashtag';

  @override
  String get routeInvalidConversationId => 'Nieprawidłowy ID rozmowy';

  @override
  String get routeInvalidRequestId => 'Nieprawidłowy ID żądania';

  @override
  String get routeInvalidListId => 'Nieprawidłowy ID listy';

  @override
  String get routeInvalidUserId => 'Nieprawidłowy ID użytkownika';

  @override
  String get routeInvalidVideoId => 'Nieprawidłowy ID filmu';

  @override
  String get routeInvalidSoundId => 'Nieprawidłowy ID dźwięku';

  @override
  String get routeInvalidCategory => 'Nieprawidłowa kategoria';

  @override
  String get routeNoVideosToDisplay => 'Brak filmów do wyświetlenia';

  @override
  String get routeGoHome => 'Przejdź do strony głównej';

  @override
  String get routeInvalidProfileId => 'Nieprawidłowy ID profilu';

  @override
  String get routeUnknownPath => 'Tej strony nie ma w aplikacji.';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Centrum pomocy';

  @override
  String get supportContactSupport => 'Skontaktuj się z pomocą';

  @override
  String get supportContactSupportSubtitle =>
      'Zacznij rozmowę lub zobacz poprzednie wiadomości';

  @override
  String get supportReportBug => 'Zgłoś błąd';

  @override
  String get supportReportBugSubtitle => 'Problemy techniczne z aplikacją';

  @override
  String get supportRequestFeature => 'Poproś o funkcję';

  @override
  String get supportRequestFeatureSubtitle =>
      'Zasugeruj usprawnienie lub nową funkcję';

  @override
  String get supportSaveLogs => 'Zapisz logi';

  @override
  String get supportSaveLogsSubtitle =>
      'Eksportuj logi do pliku do ręcznego wysłania';

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
  String get supportFaqSubtitle => 'Częste pytania i odpowiedzi';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Pomagamy rodzicom i nastolatkom budować zdrowe nawyki online';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Jak zarządzamy kontami w zależności od wieku';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Dowiedz się o weryfikacji i autentyczności';

  @override
  String get supportLoginRequired =>
      'Zaloguj się, żeby skontaktować się z pomocą';

  @override
  String get supportExportingLogs => 'Eksportowanie logów...';

  @override
  String get supportExportLogsFailed => 'Nie udało się wyeksportować logów';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Logi zapisano w $path';
  }

  @override
  String get supportRevealLogsAction => 'Pokaż w folderze';

  @override
  String get supportChatNotAvailable => 'Czat z pomocą niedostępny';

  @override
  String get supportCouldNotOpenMessages =>
      'Nie można otworzyć wiadomości pomocy';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Nie można otworzyć $pageName';
  }

  @override
  String get reportWhyReporting => 'Dlaczego zgłaszasz tę treść?';

  @override
  String get reportPolicyNotice =>
      'Divine zareaguje na zgłoszenia treści w ciągu 24 godzin, usuwając treść i wyrzucając użytkownika, który dostarczył obraźliwą treść.';

  @override
  String get reportBlockUser => 'Zablokuj tego użytkownika';

  @override
  String get reportCancel => 'Anuluj';

  @override
  String get reportSubmit => 'Zgłoś';

  @override
  String get reportSelectReason => 'Wybierz powód zgłoszenia tej treści';

  @override
  String get reportOtherRequiresDetails => 'Przy wyborze „Inne” opisz problem';

  @override
  String get reportDetailsRequired => 'Opisz problem';

  @override
  String get reportDetailsTextOnly =>
      'Tylko tekst — nie można tu dołączać zdjęć ani plików GIF.';

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
  String get reportReasonSpam => 'Spam lub niechciana treść';

  @override
  String get reportReasonSpamSubtitle =>
      'Niechciane lub powtarzające się treści';

  @override
  String get reportReasonHarassment => 'Nagabywanie, zniesławianie lub groźby';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Szkodliwe i niechciane odpowiedzi lub wzmianki';

  @override
  String get reportReasonViolence => 'Treści brutalne lub ekstremistyczne';

  @override
  String get reportReasonViolenceSubtitle =>
      'Treści brutalne, ekstremistyczne lub szkodliwe';

  @override
  String get reportReasonSexualContent => 'Treści seksualne lub dla dorosłych';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nagość, pornografia lub treści jednoznaczne';

  @override
  String get reportReasonCopyright => 'Naruszenie praw autorskich';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Nieuprawnione użycie własności intelektualnej';

  @override
  String get reportReasonFalseInfo => 'Fałszywe informacje';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Wprowadzające w błąd lub fałszywe twierdzenia';

  @override
  String get reportReasonChildSafety => 'Naruszenie bezpieczeństwa dzieci';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Ogólne obawy o bezpieczeństwo nieletnich';

  @override
  String get reportReasonCsam => 'Wykorzystywanie seksualne dzieci';

  @override
  String get reportReasonCsamSubtitle =>
      'Treści przedstawiające wykorzystywanie seksualne nieletnich';

  @override
  String get reportReasonUnderageUser =>
      'Użytkownik wygląda na osobę poniżej 16 lat';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Właściciel konta wygląda na osobę niepełnoletnią';

  @override
  String get reportReasonAiGenerated => 'Treść wygenerowana przez AI';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Treści podejrzane o wygenerowanie przez AI';

  @override
  String get reportReasonOther => 'Inne naruszenie regulaminu';

  @override
  String get reportReasonOtherSubtitle => 'Naruszenia niewymienione powyżej';

  @override
  String get reportFailed => 'Nie udało się zgłosić treści. Spróbuj ponownie.';

  @override
  String get reportNotSent =>
      'Nie udało się wysłać zgłoszenia. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get reportReceivedTitle => 'Zgłoszenie odebrane';

  @override
  String get reportReceivedThankYou =>
      'Dziękujemy za pomoc w utrzymaniu Divine bezpiecznym.';

  @override
  String get reportReceivedReviewNotice =>
      'Nasz zespół przejrzy twoje zgłoszenie i podejmie odpowiednie działania. Możesz otrzymać aktualizacje przez wiadomość bezpośrednią.';

  @override
  String get reportModerationDmDelayed =>
      'Nie udało nam się teraz bezpośrednio skontaktować z zespołem moderacji, ale twoje zgłoszenie zostało przyjęte i zostanie rozpatrzone.';

  @override
  String get reportContactModeration => 'Napisz do zespołu moderacji';

  @override
  String get reportLearnMoreAt => 'Dowiedz się więcej na';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Zamknij';

  @override
  String get listAddToList => 'Dodaj do listy';

  @override
  String listVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count osoby',
      many: '$count osób',
      few: '$count osoby',
      one: '1 osoba',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Autor: ';

  @override
  String get listNewList => 'Nowa lista';

  @override
  String get listDone => 'Gotowe';

  @override
  String get listErrorLoading => 'Błąd wczytywania list';

  @override
  String listRemovedFrom(String name) {
    return 'Usunięto z $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Dodano do $name';
  }

  @override
  String get listCreateNewList => 'Utwórz nową listę';

  @override
  String get listNewPeopleList => 'Nowa lista osób';

  @override
  String get listCollaboratorsNone => 'Brak';

  @override
  String get listAddCollaboratorTitle => 'Dodaj współpracownika';

  @override
  String get listCollaboratorSearchHint => 'Szukaj w Divine...';

  @override
  String get listNameLabel => 'Nazwa listy';

  @override
  String get listDescriptionLabel => 'Opis (opcjonalnie)';

  @override
  String get listPublicList => 'Publiczna lista';

  @override
  String get listPublicListSubtitle =>
      'Inni mogą obserwować i widzieć tę listę';

  @override
  String get listPrivateListSubtitle =>
      'Filmy zostają prywatne. Nazwa, opis, tagi i okładka pozostają widoczne.';

  @override
  String get listVisibilityPublic => 'Publiczna';

  @override
  String get listVisibilityPrivate => 'Prywatna';

  @override
  String get profileListsEmpty =>
      'Nie masz jeszcze list. Stwórz jedną dla pętli, które chcesz trzymać razem.';

  @override
  String get listEditTitle => 'Edytuj listę';

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
  String get listShareAction => 'Udostępnij listę';

  @override
  String get listShareFailed =>
      'Nie udało się udostępnić tej listy. Spróbuj ponownie.';

  @override
  String get listSave => 'Zapisz';

  @override
  String get listContinue => 'Dalej';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Nie udało się zaktualizować tej listy. Spróbuj ponownie.';

  @override
  String get listMakePrivateTitle => 'Ustawić tę listę jako prywatną?';

  @override
  String get listMakePrivateWarning =>
      'Filmy zostaną zaszyfrowane, więc zobaczysz je tylko ty. Nazwa, opis, tagi i okładka pozostają widoczne, a już udostępnione kopie mogą się zachować.';

  @override
  String get listMakePublicTitle => 'Ustawić tę listę jako publiczną?';

  @override
  String get listMakePublicWarning =>
      'Każdy, kto ma link, zobaczy tę listę i jej filmy.';

  @override
  String listShareText(String name, String url) {
    return 'Zobacz $name na Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name na Divine';
  }

  @override
  String get listCancel => 'Anuluj';

  @override
  String get listCreate => 'Utwórz';

  @override
  String get listCreateFailed => 'Nie udało się utworzyć listy';

  @override
  String get keyManagementTitle => 'Klucze Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Czym są klucze Nostr?';

  @override
  String get keyManagementExplanation =>
      'Twoja tożsamość Nostr to kryptograficzna para kluczy:\n\n• Twój klucz publiczny (npub) jest jak nazwa użytkownika - udostępniaj go swobodnie\n• Twój klucz prywatny (nsec) jest jak hasło - trzymaj w tajemnicy!\n\nTwój nsec pozwala ci uzyskać dostęp do konta w dowolnej aplikacji Nostr.';

  @override
  String get keyManagementImportTitle => 'Importuj istniejący klucz';

  @override
  String get keyManagementImportSubtitle =>
      'Masz już konto Nostr? Wklej swój klucz prywatny (nsec), żeby uzyskać tutaj dostęp.';

  @override
  String get keyManagementImportButton => 'Importuj klucz';

  @override
  String get keyManagementImportWarning => 'To zastąpi twój aktualny klucz!';

  @override
  String get keyManagementBackupTitle => 'Zrób kopię zapasową klucza';

  @override
  String get keyManagementBackupSubtitle =>
      'Zapisz swój klucz prywatny (nsec), żeby używać konta w innych aplikacjach Nostr.';

  @override
  String get keyManagementCopyNsec => 'Kopiuj mój klucz prywatny (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Nigdy nie udostępniaj swojego nsec nikomu!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Twój klucz jest przechowywany przez serwis logowania Divine, a nie na tym urządzeniu. Potwierdź hasło, a go pobierzemy.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Twój klucz przechowuje serwis logowania Divine. Podaj hasło do konta, a go pobierzemy.';

  @override
  String get keyManagementKeycastCopyKey => 'Kopiuj klucz';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Twoje urządzenie zablokowało kopiowanie, więc klucz nie trafił do schowka.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'To hasło się nie zgadza. Spróbuj ponownie.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Za dużo prób. Zamknij to i zacznij od nowa.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Za dużo próśb o klucz. Odczekaj kilka minut i spróbuj ponownie.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Twoja sesja wygasła. Zaloguj się ponownie, aby skopiować klucz.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Potwierdź swój adres e-mail, zanim skopiujesz klucz.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine zarządza kluczami tego konta, więc nie można ich tutaj skopiować.';

  @override
  String get keyManagementKeycastNoKey =>
      'Dla tego konta nie ma zapisanego klucza.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Nie udało się połączyć z serwisem logowania. Spróbuj ponownie.';

  @override
  String get keyManagementRestrictedTitle => 'Twoimi kluczami zarządza Divine';

  @override
  String get keyManagementRestrictedBody =>
      'Aby zapewnić bezpieczeństwo konta, kopia zapasowa klucza i import innego klucza nie są tutaj dostępne.';

  @override
  String get keyManagementPasteKey => 'Wklej swój klucz prywatny';

  @override
  String get keyManagementInvalidFormat =>
      'Nieprawidłowy format klucza. Musi zaczynać się od \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importować ten klucz?';

  @override
  String get keyManagementConfirmImportBody =>
      'To zastąpi twoją aktualną tożsamość importowaną.\n\nTwój aktualny klucz zostanie utracony, chyba że zrobiłeś najpierw kopię zapasową.';

  @override
  String get keyManagementImportConfirm => 'Importuj';

  @override
  String get keyManagementImportSuccess => 'Klucz zaimportowany pomyślnie!';

  @override
  String get keyManagementImportFailed =>
      'Nie udało się zaimportować klucza. Spróbuj ponownie.';

  @override
  String get keyManagementExportSuccess =>
      'Klucz prywatny skopiowany do schowka!\n\nPrzechowuj go w bezpiecznym miejscu.';

  @override
  String get keyManagementExportFailed =>
      'Nie udało się wyeksportować klucza. Spróbuj ponownie.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Twój klucz publiczny (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Kopiuj klucz publiczny';

  @override
  String get keyManagementPublicKeyCopied => 'Skopiowano klucz publiczny';

  @override
  String get saveOriginalSavedToCameraRoll => 'Zapisano w rolce aparatu';

  @override
  String get saveOriginalShare => 'Udostępnij';

  @override
  String get saveOriginalDone => 'Gotowe';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Potrzebny dostęp do zdjęć';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Aby zapisać filmy, zezwól na dostęp do Zdjęć w Ustawieniach.';

  @override
  String get saveOriginalOpenSettings => 'Otwórz Ustawienia';

  @override
  String get saveOriginalNotNow => 'Nie teraz';

  @override
  String get saveOriginalDownloadFailed => 'Pobieranie nieudane';

  @override
  String get saveOriginalDismiss => 'Odrzuć';

  @override
  String get saveOriginalDownloadingVideo => 'Pobieranie filmu';

  @override
  String get saveOriginalSavingToCameraRoll => 'Zapisywanie w rolce aparatu';

  @override
  String get saveOriginalFetchingVideo => 'Pobieranie filmu z sieci...';

  @override
  String get saveOriginalSavingVideo =>
      'Zapisywanie oryginalnego filmu w rolce aparatu...';

  @override
  String get soundTitle => 'Dźwięk';

  @override
  String get soundOriginalSound => 'Oryginalny dźwięk';

  @override
  String get soundVideosUsingThisSound => 'Filmy używające tego dźwięku';

  @override
  String get soundSourceVideo => 'Film źródłowy';

  @override
  String get soundNoVideosYet => 'Brak filmów';

  @override
  String get soundBeFirstToUse => 'Bądź pierwszy, który użyje tego dźwięku!';

  @override
  String get soundFailedToLoadVideos => 'Nie udało się wczytać filmów';

  @override
  String get soundRetry => 'Spróbuj ponownie';

  @override
  String get soundVideosUnavailable => 'Filmy niedostępne';

  @override
  String get soundCouldNotLoadDetails => 'Nie można wczytać szczegółów filmu';

  @override
  String get soundPreview => 'Podgląd';

  @override
  String get soundStop => 'Zatrzymaj';

  @override
  String get soundUseSound => 'Użyj dźwięku';

  @override
  String get soundUntitled => 'Dźwięk bez tytułu';

  @override
  String get soundStopPreview => 'Zatrzymaj podgląd';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Odsłuchaj $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Zobacz szczegóły dźwięku $title';
  }

  @override
  String get soundNoVideoCount => 'Brak filmów';

  @override
  String get soundOneVideo => '1 film';

  @override
  String soundVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String get soundUnableToPreview =>
      'Nie można odtworzyć podglądu dźwięku - brak dostępnego audio';

  @override
  String get soundPreviewFailed =>
      'Nie udało się odtworzyć podglądu. Spróbuj ponownie.';

  @override
  String get soundViewSource => 'Zobacz źródło';

  @override
  String get soundCloseTooltip => 'Zamknij';

  @override
  String get exploreNotExploreRoute => 'Nie jest trasa eksploracji';

  @override
  String get legalTitle => 'Informacje prawne';

  @override
  String get legalTermsOfService => 'Regulamin';

  @override
  String get legalTermsOfServiceSubtitle => 'Warunki i zasady użytkowania';

  @override
  String get legalPrivacyPolicy => 'Polityka prywatności';

  @override
  String get legalPrivacyPolicySubtitle => 'Jak obchodzimy się z twoimi danymi';

  @override
  String get legalSafetyStandards => 'Standardy bezpieczeństwa';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Wytyczne społeczności i bezpieczeństwo';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Polityka praw autorskich i usuwania';

  @override
  String get legalOpenSourceLicenses => 'Licencje open source';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Atrybucje pakietów stron trzecich';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Nie można otworzyć $pageName';
  }

  @override
  String get categoryAction => 'Akcja';

  @override
  String get categoryAdventure => 'Przygoda';

  @override
  String get categoryAnimals => 'Zwierzęta';

  @override
  String get categoryAnimation => 'Animacja';

  @override
  String get categoryArchitecture => 'Architektura';

  @override
  String get categoryArt => 'Sztuka';

  @override
  String get categoryAutomotive => 'Motoryzacja';

  @override
  String get categoryAwardShow => 'Gala nagród';

  @override
  String get categoryAwards => 'Nagrody';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Koszykówka';

  @override
  String get categoryBeauty => 'Uroda';

  @override
  String get categoryBeverage => 'Napoje';

  @override
  String get categoryCars => 'Samochody';

  @override
  String get categoryCelebration => 'Święto';

  @override
  String get categoryCelebrities => 'Celebryci';

  @override
  String get categoryCelebrity => 'Celebryta';

  @override
  String get categoryCityscape => 'Pejzaż miejski';

  @override
  String get categoryComedy => 'Komedia';

  @override
  String get categoryConcert => 'Koncert';

  @override
  String get categoryCooking => 'Gotowanie';

  @override
  String get categoryCostume => 'Kostium';

  @override
  String get categoryCrafts => 'Rękodzieło';

  @override
  String get categoryCrime => 'Kryminał';

  @override
  String get categoryCulture => 'Kultura';

  @override
  String get categoryDance => 'Taniec';

  @override
  String get categoryDiy => 'Zrób to sam';

  @override
  String get categoryDrama => 'Dramat';

  @override
  String get categoryEducation => 'Edukacja';

  @override
  String get categoryEmotional => 'Emocjonalne';

  @override
  String get categoryEmotions => 'Emocje';

  @override
  String get categoryEntertainment => 'Rozrywka';

  @override
  String get categoryEvent => 'Wydarzenie';

  @override
  String get categoryFamily => 'Rodzina';

  @override
  String get categoryFans => 'Fani';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festiwal';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Jedzenie';

  @override
  String get categoryFootball => 'Futbol';

  @override
  String get categoryFurniture => 'Meble';

  @override
  String get categoryGaming => 'Gry';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Pielęgnacja';

  @override
  String get categoryGuitar => 'Gitara';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Zdrowie';

  @override
  String get categoryHockey => 'Hokej';

  @override
  String get categoryHoliday => 'Wakacje';

  @override
  String get categoryHome => 'Dom';

  @override
  String get categoryHomeImprovement => 'Remont';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Szpital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Wnętrza';

  @override
  String get categoryInterview => 'Wywiad';

  @override
  String get categoryKids => 'Dzieci';

  @override
  String get categoryLifestyle => 'Styl życia';

  @override
  String get categoryMagic => 'Magia';

  @override
  String get categoryMakeup => 'Makijaż';

  @override
  String get categoryMedical => 'Medycyna';

  @override
  String get categoryMusic => 'Muzyka';

  @override
  String get categoryMystery => 'Tajemnica';

  @override
  String get categoryNature => 'Natura';

  @override
  String get categoryNews => 'Wiadomości';

  @override
  String get categoryOutdoor => 'Na świeżym powietrzu';

  @override
  String get categoryParty => 'Impreza';

  @override
  String get categoryPeople => 'Ludzie';

  @override
  String get categoryPerformance => 'Występ';

  @override
  String get categoryPets => 'Zwierzaki';

  @override
  String get categoryPolitics => 'Polityka';

  @override
  String get categoryPrank => 'Psikus';

  @override
  String get categoryPranks => 'Psikusy';

  @override
  String get categoryRealityShow => 'Reality show';

  @override
  String get categoryRelationship => 'Związek';

  @override
  String get categoryRelationships => 'Związki';

  @override
  String get categoryRomance => 'Romans';

  @override
  String get categorySchool => 'Szkoła';

  @override
  String get categoryScienceFiction => 'Science fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Zakupy';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Pielęgnacja skóry';

  @override
  String get categorySoccer => 'Piłka nożna';

  @override
  String get categorySocialGathering => 'Spotkanie';

  @override
  String get categorySocialMedia => 'Media społecznościowe';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technologia';

  @override
  String get categoryTelevision => 'Telewizja';

  @override
  String get categoryToys => 'Zabawki';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Podróże';

  @override
  String get categoryUrban => 'Miejskie';

  @override
  String get categoryViolence => 'Przemoc';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogowanie';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadStaged =>
      'Przesłano — dotknij Zapisz, aby zastosować';

  @override
  String inboxReportedUser(String displayName) {
    return 'Zgłoszono $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Zablokowano $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Odblokowano $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Usunięto rozmowę';

  @override
  String get inboxRestorePausedTitle =>
      'Część czatów nie została w pełni odzyskana';

  @override
  String get conversationRestorePausedTitle =>
      'Ten czat nie został jeszcze w pełni odzyskany';

  @override
  String get inboxRestoreRetryAction => 'Spróbuj ponownie';

  @override
  String get inboxRestoringMessages => 'Odzyskiwanie wiadomości…';

  @override
  String get inboxEmptyTitle => 'Brak wiadomości';

  @override
  String get inboxEmptySubtitle => 'Ten przycisk + nie gryzie.';

  @override
  String get inboxLoadErrorTitle => 'Wiadomości się nie wczytały';

  @override
  String get inboxLoadErrorSubtitle => 'Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get inboxFilterAll => 'Wszystkie';

  @override
  String get inboxFilterUnread => 'Nieprzeczytane';

  @override
  String get dmBlockedThreadTitle => 'Zablokowano to konto';

  @override
  String get dmBlockedThreadBody =>
      'Wiadomości pozostają tutaj, żebyś mógł je przeczytać lub zrobić zrzut ekranu. Odblokuj, aby odpowiedzieć.';

  @override
  String get inboxFilterBlocked => 'Zablokowane';

  @override
  String get inboxBlockedEmptyTitle => 'Brak zablokowanych czatów';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Konta, które zablokujesz, pojawią się tutaj.';

  @override
  String get inboxBlockedNoMessages => 'Brak wiadomości';

  @override
  String get inboxUnreadEmptyTitle => 'Wszystko nadrobione';

  @override
  String get inboxUnreadEmptySubtitle => 'Brak nieprzeczytanych wiadomości.';

  @override
  String get inboxSearchHint => 'Szukaj wiadomości';

  @override
  String get inboxSupportRowTitle => 'Moderacja Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Błędy, moderacja, sprawy konta — słuchamy.';

  @override
  String get inboxSearchEmptyTitle => 'Brak wyników';

  @override
  String get inboxSearchEmptySubtitle => 'Spróbuj innego imienia lub słowa.';

  @override
  String get inboxActionMute => 'Wycisz rozmowę';

  @override
  String inboxActionReport(String displayName) {
    return 'Zgłoś $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Zablokuj $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Odblokuj $displayName';
  }

  @override
  String get inboxActionRemove => 'Usuń rozmowę';

  @override
  String get inboxRemoveConfirmTitle => 'Usunąć rozmowę?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'To usuwa rozmowę z $displayName z Twojej skrzynki odbiorczej. Jeśli ta osoba znów do Ciebie napisze, rozpocznie się nowa rozmowa.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'To usuwa rozmowę grupową z Twojej skrzynki odbiorczej. Jeśli ktoś znów napisze w grupie, rozpocznie się nowa rozmowa.';

  @override
  String get inboxRemoveConfirmConfirm => 'Usuń';

  @override
  String get inboxConversationMuted => 'Wyciszono rozmowę';

  @override
  String get inboxConversationUnmuted => 'Wyłączono wyciszenie rozmowy';

  @override
  String get inboxCollabInviteCardTitle => 'Zaproszenie do współpracy';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Film bez tytułu';

  @override
  String get clickableTextViewVideoLink => 'Zobacz wideo';

  @override
  String get messageExternalLinkDialogTitle => 'Otworzyć link zewnętrzny?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Ten link prowadzi do zewnętrznej strony i może nie być bezpieczny:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Otwórz';

  @override
  String get inboxCollabInviteCoPostButton => 'Współopublikuj';

  @override
  String get inboxCollabInviteNotMineButton => 'Nie moje';

  @override
  String get inboxCollabInvitePreviewTitle =>
      'Zaproszenie do współopublikowania';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Zaproszenie do współopublikowania od $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Współopublikowanie doda ten film do Twojej osi czasu jako współpracę.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Zaakceptowano';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Zignorowano';

  @override
  String get inboxCollabInviteAcceptError =>
      'Nie udało się zaakceptować. Spróbuj ponownie.';

  @override
  String get inboxCollabInviteSentStatus => 'Zaproszenie wysłane';

  @override
  String get inboxConversationCollabInvitePreview =>
      'Zaproszenie do współpracy';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Zaproszono Cię do współpracy nad $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Zaproszono Cię do współpracy nad filmem: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszenia dla współtwórców nie zostało wysłanych.',
      many: '$count zaproszeń dla współtwórców nie zostało wysłanych.',
      few: '$count zaproszenia dla współtwórców nie zostały wysłane.',
      one: '1 zaproszenie dla współtwórcy nie zostało wysłane.',
    );
    return 'Film opublikowany, ale $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Nie udało się ustalić, z kim jest ta rozmowa. Otwórz ją ponownie ze skrzynki odbiorczej.';

  @override
  String get dmSendBlockedMessage =>
      'Możesz pisać tylko do oficjalnych kont Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Nikt nie czyta tej rozmowy. Napisz do Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Nie udało się usunąć dla wszystkich.';

  @override
  String get dmDeleteRefusedDetails =>
      'Niektóre osoby mogą nadal widzieć tę wiadomość.';

  @override
  String get dmRetiredThreadClosedTitle => 'Ta rozmowa jest zamknięta.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Tego powiadomienia od Divine Moderation nie można usunąć.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Przenieśliśmy Divine Moderation na nowe konto. Tego nikt już nie czyta.';

  @override
  String get dmRetiredThreadOpenSupport => 'Napisz do Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Nie udało się wysłać wiadomości';

  @override
  String get dmResendFailedMessage => 'Nadal nie udało się wysłać';

  @override
  String get dmSendFailedSubtitle =>
      'Wyślij ją ponownie teraz albo przestań próbować.';

  @override
  String get dmSendFailedRetry => 'Spróbuj ponownie';

  @override
  String get dmSendPartialMessage =>
      'Wysłano, ale nie zsynchronizowano z twoimi innymi urządzeniami';

  @override
  String get dmConversationLoadError => 'Nie udało się wczytać wiadomości';

  @override
  String get dmMessageInputHint => 'Napisz coś…';

  @override
  String get dmMessageBubbleSentHint => 'Wysłana wiadomość';

  @override
  String get dmMessageBubbleReceivedHint => 'Otrzymana wiadomość';

  @override
  String get dmMessageBubbleLongPressHint => 'Akcje wiadomości';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Wyślij ponownie lub usuń tę wiadomość';

  @override
  String get dmMessageActionCopyText => 'Kopiuj tekst';

  @override
  String get dmMessageActionCopyVideoUrl => 'Kopiuj URL filmu';

  @override
  String get dmMessageActionDeleteForEveryone => 'Usuń dla wszystkich';

  @override
  String get dmMessageActionReport => 'Zgłoś';

  @override
  String get dmMessageActionRetrySend => 'Wyślij ponownie';

  @override
  String get dmMessageActionCancelSend => 'Przestań próbować';

  @override
  String get dmReactionAddCustomA11yLabel => 'Dodaj własną reakcję emoji';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Wyślij wiadomość do $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Odpowiedz sobie…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Odpowiedz na ten reel';

  @override
  String get dmReelReplyViewChat => 'Zobacz czat';

  @override
  String get dmReelReplySentAnnouncement => 'Odpowiedź wysłana';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Zareagowano $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Nie udało się wysłać';

  @override
  String get dmReelReplyUnverified => 'Nie udało się potwierdzić wysłania';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Twoja reakcja: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name zareagował(a) emoji $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Wysyłanie reakcji: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reakcja się nie powiodła, dotknij dwukrotnie, aby ponowić';

  @override
  String get dmReactionChipRetryAnnouncement => 'Ponawianie reakcji';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Dokończ usuwanie poprzedniej reakcji, zanim dodasz kolejną.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reakcje';

  @override
  String get dmReactionsViewA11yLabel => 'Zobacz, kto zareagował';

  @override
  String get dmReactionRemoveAction => 'Usuń';

  @override
  String get dmReactionRetryAction => 'Spróbuj ponownie';

  @override
  String get dmFormatBold => 'Pogrubienie';

  @override
  String get dmFormatItalic => 'Kursywa';

  @override
  String get dmFormatStrikethrough => 'Przekreślenie';

  @override
  String get dmFormatCode => 'Kod';

  @override
  String get dmStatusFailed => 'Nie udało się wysłać';

  @override
  String get inboxConversationActionsSheetLabel => 'Akcje rozmowy';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Rozmowa z $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Nieprzeczytana, rozmowa z $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count innych osób',
      many: '$count innych osób',
      few: '$count inne osoby',
      one: '$count inna osoba',
    );
    return '$name i $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Pokaż akcje rozmowy';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Tytuł: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Film $current/$total';
  }

  @override
  String get exploreSearchHint => 'Szukaj...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count filmów';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Nie udało się zaktualizować subskrypcji. Spróbuj ponownie.';

  @override
  String get discoverListsTitle => 'Odkrywaj listy';

  @override
  String get discoverListsFailedToLoad => 'Nie udało się wczytać list';

  @override
  String get discoverListsLoading => 'Odkrywanie publicznych list...';

  @override
  String get discoverListsRelayTimeout =>
      'Relay nie zwrócił list na czas. Spróbuj ponownie.';

  @override
  String get discoverListsServiceUnavailable => 'Usługa niedostępna.';

  @override
  String get discoverListsEmptyTitle => 'Nie znaleziono publicznych list';

  @override
  String get discoverListsEmptySubtitle => 'Wróć później po nowe listy';

  @override
  String get discoverListsByAuthorPrefix => 'od';

  @override
  String get curatedListEmptyTitle => 'Brak filmów na tej liście';

  @override
  String get curatedListEmptySubtitle => 'Dodaj kilka filmów, żeby zacząć';

  @override
  String get curatedListLoadingVideos => 'Wczytywanie filmów...';

  @override
  String get curatedListFailedToLoad => 'Nie udało się wczytać listy';

  @override
  String get curatedListVideoNotAvailable => 'Film niedostępny';

  @override
  String get curatedListActionsTooltip => 'Akcje listy';

  @override
  String get curatedListDeleteConfirmTitle => 'Usunąć listę?';

  @override
  String get curatedListDeleteConfirmBody =>
      'To usunie listę z przekaźników. Filmy z listy nie zostaną usunięte.';

  @override
  String get curatedListDeletedSnack => 'Lista usunięta';

  @override
  String get curatedListDeleteFailed => 'Nie udało się usunąć listy';

  @override
  String get peopleListsActionsTooltip => 'Akcje listy';

  @override
  String get listDeleteAction => 'Usuń listę';

  @override
  String get peopleListsDeleteConfirmTitle => 'Usunąć listę?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'To usunie listę dla wszystkich. Osoby z listy nie przestaną być obserwowane.';

  @override
  String get peopleListsDeleteFailed => 'Nie udało się usunąć listy';

  @override
  String get commonRetry => 'Ponów';

  @override
  String get commonSomethingWentWrong => 'Coś poszło nie tak';

  @override
  String get commonDelete => 'Usuń';

  @override
  String get commonCancel => 'Anuluj';

  @override
  String get commonBack => 'Wstecz';

  @override
  String get commonClose => 'Zamknij';

  @override
  String get commonNotNow => 'Nie teraz';

  @override
  String get commonLoading => 'Ładowanie';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Nie udało się zaktualizować okładki. Spróbuj ponownie.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement =>
      'Zaktualizowano okładkę';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Opublikować bez weryfikacji autentyczności?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Nie udało się dodać poświadczeń treści, więc ten film nie zostanie potwierdzony jako stworzony przez człowieka. Wygeneruj ponownie, aby spróbować jeszcze raz, lub opublikuj bez zmian.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Poświadczenia treści wymagają połączenia z internetem.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Usługa poświadczeń treści nie odpowiedziała. To nie wina twojego połączenia.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Wygeneruj ponownie';

  @override
  String get videoMetadataC2paMissingSkip => 'Pomiń';

  @override
  String get videoMetadataGenerationFailed => 'Generowanie nie powiodło się';

  @override
  String get videoMetadataTags => 'Tagi';

  @override
  String get videoMetadataExpiration => 'Wygaśnięcie';

  @override
  String get videoMetadataExpirationNotExpire => 'Nie wygasa';

  @override
  String get videoMetadataExpirationOneDay => '1 dzień';

  @override
  String get videoMetadataExpirationOneWeek => '1 tydzień';

  @override
  String get videoMetadataExpirationOneMonth => '1 miesiąc';

  @override
  String get videoMetadataExpirationOneYear => '1 rok';

  @override
  String get videoMetadataExpirationOneDecade => '1 dekada';

  @override
  String get videoMetadataContentWarnings => 'Ostrzeżenia o treści';

  @override
  String get videoEditorStickers => 'Naklejki';

  @override
  String get trendingTitle => 'Na czasie';

  @override
  String get libraryDeleteConfirm => 'Usuń';

  @override
  String get libraryWebUnavailableHeadline =>
      'Biblioteka jest w aplikacji mobilnej';

  @override
  String get libraryWebUnavailableDescription =>
      'Wersje robocze i klipy są na urządzeniu — otwórz Divine w telefonie, żeby nimi zarządzać.';

  @override
  String get libraryTabDrafts => 'Wersje robocze';

  @override
  String get libraryTabClips => 'Klify';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Usuń wybrane klipy';

  @override
  String get libraryCloseSemanticLabel => 'Zamknij bibliotekę';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'Zakończ wybieranie klipów';

  @override
  String get librarySelectClipsSemanticLabel => 'Wybierz klipy';

  @override
  String get libraryGridSizeLabel => 'Rozmiar siatki';

  @override
  String get libraryDisplayOptionsLabel => 'Sortowanie i rozmiar siatki';

  @override
  String get libraryMoreActionsSemanticLabel => 'Więcej akcji biblioteki';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolumny',
      many: '$count kolumn',
      few: '$count kolumny',
      one: '1 kolumna',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Wybierz';

  @override
  String get librarySortNewestCreation => 'Najnowsze utworzone';

  @override
  String get librarySortOldestCreation => 'Najstarsze utworzone';

  @override
  String get librarySortLongestClip => 'Najdłuższy klip';

  @override
  String get librarySortShortestClip => 'Najkrótszy klip';

  @override
  String get librarySortSquareFirst => 'Najpierw kwadratowe';

  @override
  String get librarySortVerticalFirst => 'Najpierw pionowe';

  @override
  String get libraryDeleteClipsWarning =>
      'Tego nie cofniesz. Pliki wideo zostaną trwale usunięte z urządzenia.';

  @override
  String get libraryPreparingVideo => 'Przygotowywanie wideo...';

  @override
  String libraryCreateVideo(int count) {
    return 'Utwórz wideo ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zapisano $count klipów',
      many: 'Zapisano $count klipów',
      few: 'Zapisano $count klipy',
      one: 'Zapisano 1 klip',
    );
    return '$_temp0 w $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return 'Zapisano $successCount, niepowodzeń: $failureCount';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Nie udało się zapisać do $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Odmowa uprawnień: $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunięto $count klipów',
      many: 'Usunięto $count klipów',
      few: 'Usunięto $count klipy',
      one: 'Usunięto 1 klip',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Cofnij';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Zostanie automatycznie usunięty za $daysLeft dni',
      one: 'Zostanie automatycznie usunięty jutro',
      zero: 'Zostanie automatycznie usunięty dzisiaj',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Nie udało się wczytać wersji roboczych';

  @override
  String get libraryCouldNotLoadClips => 'Nie udało się wczytać klipów';

  @override
  String get libraryOpenErrorDescription =>
      'Coś poszło nie tak przy otwieraniu biblioteki. Możesz spróbować ponownie.';

  @override
  String get libraryNoDraftsYetTitle => 'Brak wersji roboczych';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Wideo zapisane jako wersja robocza pojawi się tutaj';

  @override
  String get libraryNoClipsYetTitle => 'Brak klipów';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Nagrane klipy wideo pojawią się tutaj';

  @override
  String get libraryDraftDeletedSnackbar => 'Usunięto wersję roboczą';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Nie udało się usunąć wersji roboczej';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Zduplikowano wersję roboczą';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Nie udało się zduplikować wersji roboczej';

  @override
  String get libraryDraftInProgressBadge => 'W toku';

  @override
  String get libraryDraftActionPost => 'Opublikuj';

  @override
  String get libraryDraftActionEdit => 'Edytuj';

  @override
  String get libraryDraftActionDuplicate => 'Duplikuj';

  @override
  String get libraryDraftActionDelete => 'Usuń wersję roboczą';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (kopia $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Usuń wersję roboczą';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Na pewno usunąć „$title”?';
  }

  @override
  String get libraryDeleteClipTitle => 'Usuń klip';

  @override
  String get libraryDeleteClipMessage => 'Na pewno usunąć ten klip?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds s';
  }

  @override
  String get libraryRecordVideo => 'Nagraj wideo';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Klip wideo, $duration sekund';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Zarchiwizowano. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Klip poklatkowy, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Zaznaczono, numer $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Zaznaczono';

  @override
  String get videoClipSemanticValueNotSelected => 'Niezaznaczono';

  @override
  String get videoClipSemanticHintDisabled => 'Wyłączono';

  @override
  String get videoClipSemanticHintSelect =>
      'Dotknij, aby wybrać, przytrzymaj, aby podejrzeć';

  @override
  String get videoClipSemanticHintDeselect =>
      'Dotknij, aby odznaczyć, przytrzymaj, aby podejrzeć';

  @override
  String get routerInvalidCreator => 'Nieprawidłowy twórca';

  @override
  String get routerInvalidHashtagRoute => 'Nieprawidłowa ścieżka hashtagu';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Nie udało się załadować filmów';

  @override
  String get categoryGalleryNoVideosInCategory => 'Brak filmów w tej kategorii';

  @override
  String get categoryGallerySortOptionsLabel => 'Opcje sortowania kategorii';

  @override
  String get categoryGallerySortHot => 'Na czasie';

  @override
  String get categoryGallerySortNew => 'Nowe';

  @override
  String get categoryGallerySortClassic => 'Klasyki';

  @override
  String get categoryGallerySortForYou => 'Dla ciebie';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Nie udało się załadować kategorii';

  @override
  String get categoriesNoCategoriesAvailable => 'Brak dostępnych kategorii';

  @override
  String get notificationsEmptyTitle => 'Brak aktywności';

  @override
  String get notificationsEmptySubtitle =>
      'Gdy ludzie zaczną wchodzić w interakcję z twoimi treściami, zobaczysz to tutaj';

  @override
  String get appsPermissionsTitle => 'Uprawnienia integracji';

  @override
  String get appsPermissionsRevoke => 'Cofnij';

  @override
  String get appsPermissionsEmptyTitle =>
      'Brak zapamiętanych uprawnień integracji';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Zatwierdzone integracje pojawią się tutaj, gdy zapamiętasz zgodę na dostęp.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName prosi o twoją zgodę';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Ta aplikacja prosi o dostęp przez sprawdzoną piaskownicę Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Źródło';

  @override
  String get nostrAppPermissionMethod => 'Metoda';

  @override
  String get nostrAppPermissionCapability => 'Uprawnienie';

  @override
  String get nostrAppPermissionEventKind => 'Typ zdarzenia';

  @override
  String get nostrAppPermissionAllow => 'Zezwól';

  @override
  String get appsDetailDefaultTitle => 'Zintegrowana aplikacja';

  @override
  String get appsDetailNotFoundTitle => 'Nie znaleziono integracji';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Ta zatwierdzona integracja nie jest już dostępna w Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Jak to działa';

  @override
  String get appsDetailHowItWorksBody =>
      'To zatwierdzona aplikacja innej firmy, która działa wewnątrz Divine. Divine przyznaje tylko sprawdzone uprawnienia dla tej integracji i blokuje nawigację poza jej zatwierdzone źródła.';

  @override
  String get appsDetailAboutTitle => 'O aplikacji';

  @override
  String get appsDetailPrimaryOriginTitle => 'Główne źródło';

  @override
  String get appsDetailApprovedOriginsTitle => 'Zatwierdzone źródła';

  @override
  String get appsDetailCapabilitiesTitle => 'Dostępne uprawnienia';

  @override
  String get appsDetailAskBeforeTitle => 'Pytaj przed';

  @override
  String get appsDetailOpenButton => 'Otwórz integrację';

  @override
  String get appsDetailNoneDeclared => 'Nic jeszcze nie zadeklarowano';

  @override
  String get appsDirectoryTitle => 'Zintegrowane aplikacje';

  @override
  String get appsDirectoryIntroTitle => 'Zatwierdzone aplikacje innych firm';

  @override
  String get appsDirectoryIntroBody =>
      'Zatwierdzone aplikacje innych firm działające wewnątrz Divine';

  @override
  String get appsDirectoryErrorTitle =>
      'Nie udało się wczytać zintegrowanych aplikacji';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Pociągnij, aby ponownie spróbować zatwierdzonych integracji.';

  @override
  String get appsDirectoryEmptyTitle => 'Brak zatwierdzonych integracji';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Zatwierdzone aplikacje innych firm pojawią się tutaj, gdy Divine je doda.';

  @override
  String get appsDirectoryRefresh => 'Odśwież';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Zintegrowane aplikacje działają w Divine na urządzeniach mobilnych';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Zatwierdzone integracje są na razie dostępne tylko na urządzeniach mobilnych.';

  @override
  String get appsSandboxUnavailableTitle => 'Integracja niedostępna';

  @override
  String get appsSandboxUnavailableBody =>
      'Otwieraj zatwierdzone integracje z zakładki Zintegrowane aplikacje, aby Divine mogło zastosować właściwą politykę dostępu.';

  @override
  String get appsSandboxLoadingTitle => 'Wczytywanie integracji';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Sprawdzanie zatwierdzonej integracji przed uruchomieniem.';

  @override
  String get appsSandboxBlockedTitle => 'Zablokowane dla bezpieczeństwa';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Ta integracja próbowała opuścić swoje zatwierdzone źródło.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Link do posta skopiowany do schowka';

  @override
  String get shareCopiedEventJson =>
      'JSON zdarzenia Nostr skopiowany do schowka';

  @override
  String get shareCopiedEventId => 'ID zdarzenia Nostr skopiowane do schowka';

  @override
  String get authHeroTaglineAuthentic => 'Autentyczne chwile.';

  @override
  String get authHeroTaglineHuman => 'Ludzka kreatywność.';

  @override
  String get keyImportFailedToImport =>
      'Nie udało się zaimportować klucza ani połączyć z bunkrem';

  @override
  String get keyImportInvalidBunkerUrl => 'Nieprawidłowy URL bunkra';

  @override
  String get keyImportInvalidFormat =>
      'Nieprawidłowy format. Użyj nsec..., hex, ncryptsec1... lub bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Nieprawidłowy format nsec. Powinien mieć 63 znaki';

  @override
  String get keyImportKeyFieldLabel => 'Klucz prywatny lub URL bunkra';

  @override
  String get keyImportKeyRequired =>
      'Wprowadź swój klucz prywatny lub URL bunkra';

  @override
  String get keyImportPasswordRequired =>
      'Wprowadź hasło do tego zaszyfrowanego klucza';

  @override
  String get keyImportSecurityWarningBody =>
      'Nigdy nie udostępniaj nikomu swojego klucza prywatnego. Ten klucz daje pełny dostęp do twojej tożsamości Nostr.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Trzymaj swój klucz prywatny w bezpiecznym miejscu!';

  @override
  String get keyImportSubtitle =>
      'Zaimportuj swoją istniejącą tożsamość Nostr za pomocą klucza prywatnego lub URL bunkra.';

  @override
  String get keyImportTitle => 'Zaimportuj swoją\ntożsamość Nostr';

  @override
  String get commentAuthorYouIndicator => 'Ty';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Zobacz profil użytkownika $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Usuń komentarz';

  @override
  String get commentOptionsEditSemanticLabel => 'Edytuj komentarz';

  @override
  String get commentOptionsFlagContentLabel => 'Zgłoś treść';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Zgłoś tę treść';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Wybierz powód zgłoszenia tego komentarza';

  @override
  String get commentOptionsFlagSubmit => 'Wyślij';

  @override
  String get commentOptionsTitle => 'Opcje';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Wciąż pracujemy nad importem starych komentarzy z archiwum. Nie są jeszcze gotowe.';

  @override
  String get commentsEmptyClassicVineTitle => 'Klasyczny Vine';

  @override
  String get commentsInputEditingLabel => 'Edytowanie';

  @override
  String get commentsInputSemanticHint => 'Dodaj komentarz';

  @override
  String get commentsInputSemanticHintEdit => 'Edytuj komentarz';

  @override
  String get commentsInputSemanticHintReply => 'Dodaj odpowiedź';

  @override
  String get commentsInputSemanticLabel => 'Pole komentarza';

  @override
  String get commentsInputSemanticLabelEdit => 'Pole edycji';

  @override
  String get commentsInputSemanticLabelReply => 'Pole odpowiedzi';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Zobacz profil użytkownika $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Archiwum Klasyków jest wczytywane';

  @override
  String get classicsEmptyTitle => 'Nie znaleziono Klasyków';

  @override
  String get classicsErrorTitle => 'Nie udało się wczytać Klasyków';

  @override
  String get classicsUnavailableDescription =>
      'Klasyki są dostępne tylko po połączeniu z przekaźnikami Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Przełącz się na przekaźnik obsługujący Funnelcake w Ustawieniach, aby uzyskać dostęp do archiwum Klasyków.';

  @override
  String get classicsUnavailableTitle => 'Klasyki niedostępne';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Bądź pierwszą osobą, która opublikuje film z tym hashtagiem!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Nie znaleziono filmów dla #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'To może chwilę potrwać';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Wczytywanie filmów o #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Dodaj hashtagi... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'Zajrzyj później po nowe treści';

  @override
  String get newVideosTabEmptyTitle => 'Brak filmów w Nowych filmach';

  @override
  String get popularVideosContextTitle => 'Popularne filmy';

  @override
  String get popularVideosEmptySubtitle => 'Zajrzyj później po nowe treści';

  @override
  String get popularVideosEmptyTitle => 'Brak filmów w Popularnych filmach';

  @override
  String get popularVideosErrorTitle =>
      'Nie udało się wczytać popularnych filmów';

  @override
  String get popularVideosFeedSourceLabel => 'Źródło popularnego kanału';

  @override
  String get trendingHashtagsLoading => 'Wczytywanie hashtagów...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Zobacz filmy oznaczone $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Autor filmu: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Opis filmu: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Wizją Divine jest dać ci prawdziwy wybór algorytmu. Zamiast być zamkniętym w jednym algorytmie działającym jak czarna skrzynka, będziesz mieć możliwość wyboru spośród wielu podejść do rekomendacji:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Chronologiczna oś czasu od obserwowanych twórców';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'To daje ci kontrolę nad twoją uwagą, zamiast zostawiać ją platformie. Powinieneś wiedzieć, jak twój kanał jest kuratorowany, i mieć możliwość zmiany tego, kiedy tylko chcesz.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Tworzone przez społeczność niestandardowe kanały na tematy takie jak muzyka, komedia czy sztuka';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Spersonalizowany kanał „Dla Ciebie”';

  @override
  String get forYouAlgorithmChoiceTitle => 'Twój algorytm, twój wybór';

  @override
  String get forYouAlgorithmChoiceTrending => 'Popularne i modne treści';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Silny sygnał — byłeś na tyle zaangażowany, by odpowiedzieć';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine zwraca uwagę na to, jak wchodzisz w interakcję z treściami, aby zrozumieć, co lubisz. Za każdym razem, gdy oglądasz film, reagujesz na niego, zostawiasz komentarz lub go repostujesz, system to odnotowuje.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Jak to działa';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Różne działania sygnalizują różny poziom zainteresowania:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Jeśli nie masz jeszcze historii oglądania, pokazujemy mieszankę tego, co obecnie popularne i modne, wraz z najnowszymi wgraniami. To daje ci świetny punkt wyjścia do odkrywania.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'W miarę jak oglądasz, lubisz i angażujesz się w treści, rekomendacje stopniowo stają się bardziej spersonalizowane. Z czasem twój kanał Dla Ciebie wyławia filmy od twórców, których być może nigdy nie odkryłbyś samodzielnie.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Jesteś nowy w Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Budujemy otwarty system, w którym deweloperzy mogą wdrażać własne algorytmy, a ty możesz wybrać, których używać — albo zrezygnować z nich całkowicie.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Otwarte źródło i przejrzystość';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Średni sygnał — szybki sposób na okazanie uznania';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reakcje';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Najsilniejszy sygnał — udostępnienie obserwującym to potężna rekomendacja';

  @override
  String get forYouAlgorithmSubtitle =>
      'Napędzany przez Gorse, silnik rekomendacji o otwartym kodzie źródłowym';

  @override
  String get forYouAlgorithmTitle => 'Algorytm Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Lekki sygnał — wskazuje podstawowe zainteresowanie';

  @override
  String get forYouEmptyDescription =>
      'Obejrzyj i polub kilka filmów, aby otrzymać spersonalizowane rekomendacje.';

  @override
  String get forYouEmptyTitle => 'Brak rekomendacji';

  @override
  String get forYouErrorTitle => 'Nie udało się wczytać rekomendacji';

  @override
  String get forYouUnavailableDescription =>
      'Spersonalizowane rekomendacje wymagają połączenia z Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Dla Ciebie niedostępne';

  @override
  String get inboxConversationOptionsLabel => 'Opcje';

  @override
  String get inboxConversationViewProfileButton => 'Zobacz profil';

  @override
  String get inboxMessageRequestsEmpty => 'Brak próśb o wiadomość';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Prośby o wiadomość, $requestCount oczekujących';
  }

  @override
  String get inboxMessageRequestsTitle => 'Prośby o wiadomość';

  @override
  String get inboxMessagesTab => 'Wiadomości';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Prośba o wiadomość od $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Wysłał prośbę o wiadomość';

  @override
  String get inboxRequestsMarkAllRead =>
      'Oznacz wszystkie prośby jako przeczytane';

  @override
  String get inboxRequestsRemoveAll => 'Usuń wszystkie prośby';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Odrzuć i usuń';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Odrzucono prośbę od $displayName';
  }

  @override
  String get messageRequestLoadFailed => 'Nie udało się wczytać tej prośby.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count obserwujących';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count filmów';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wiadomości',
      many: '$count wiadomości',
      few: '$count wiadomości',
      one: '1 wiadomość',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Zobacz wiadomości';

  @override
  String get messageRequestViewProfileButton => 'Zobacz profil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName chce do ciebie napisać, wysłał $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Przełączono konto, więc nic nie zostało usunięte. Otwórz ponownie usuwanie dla konta, które chcesz usunąć.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Aby potwierdzić, wpisz:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Aby potwierdzić, wpisz swoją nazwę użytkownika:';

  @override
  String get deleteAccountConfirmationHint => 'Wpisz DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'Wpisz swoją nazwę użytkownika';

  @override
  String get deleteAccountDeleteAllContentButton => 'Usuń wszystkie treści';

  @override
  String get accountDeletionRecoveryTitle => 'Usuwanie konta';

  @override
  String get accountDeletionRecoveryBody =>
      'Nie udało się dokończyć usuwania konta. Twoja nazwa użytkownika jest dla ciebie zarezerwowana i wciąż można ją odzyskać.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername =>
      'Odzyskaj moją nazwę użytkownika';

  @override
  String get accountDeletionFinishingBody =>
      'Twoje żądanie usunięcia jest nadal przetwarzane. W tym czasie możesz korzystać z innego konta.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Usuwanie innego konta jest nadal przetwarzane na tym urządzeniu. Zaczekaj na zakończenie, zanim usuniesz to konto.';

  @override
  String get accountDeletionCancellingBody =>
      'Anulujemy usuwanie twojego konta. Sprawdź ponownie, zanim opuścisz ten ekran.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Nie udało się jeszcze odzyskać twojej nazwy użytkownika. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get accountDeletionUsernameRestored =>
      'Twoja nazwa użytkownika została odzyskana. Twoje konto nie zostało usunięte.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Nie udało się sprawdzić stanu usuwania. Sprawdź połączenie i spróbuj ponownie.';

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
      'Usuwanie konta jest teraz niedostępne. Nic nie zostało usunięte.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Nie udało się dokończyć usuwania konta. Spróbuj ponownie.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle =>
      '⚠️ Ostateczne potwierdzenie';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Żądania usunięcia wysłane, ale twoje klucze mogły nie zostać w pełni usunięte z tego urządzenia. Przejdź do Ustawienia → Klucze Nostr → Usuń klucze, aby spróbować ponownie.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Żądania usunięcia wysłane i wylogowano cię, ale niektórych danych lokalnych nie udało się usunąć z tego urządzenia.';

  @override
  String get deleteAccountPreparingDeletion => 'Przygotowywanie usuwania...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total zdarzeń';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'To usuwa lokalne logowanie do tego konta z tego urządzenia. Nie usunie to twojego konta Divine ani tożsamości Nostr.\n\nTwoje wersje robocze i klipy pozostaną zapisane na tym urządzeniu dla tego konta. Jeśli to twoje ostatnie lokalne konto, wrócisz do ekranu logowania.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Usuń z urządzenia';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Usunąć to konto z tego urządzenia?';

  @override
  String get deleteAccountReauthRequired =>
      'Zaloguj się ponownie, aby usunąć konto. Nic jeszcze nie zostało usunięte.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Prośby o usunięcie twoich postów zostały wysłane, ale nie udało się dokończyć usuwania twojego konta. Spróbuj ponownie za chwilę.';

  @override
  String get deleteAccountSuccess =>
      'Twoje konto Divine zostało usunięte. Wysłano żądania usunięcia twoich postów w Nostr, ale niektóre przekaźniki, klienty lub pamięci podręczne mogą zachować kopie.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Wysłano żądanie usunięcia konta. Usunięcia niektórych istniejących postów nie udało się potwierdzić osobno.';

  @override
  String get deleteAccountWarningBody =>
      'To wysyła żądania usunięcia twojego konta i treści, usuwa twoje konto Divine, gdy to możliwe, i wylogowuje cię na tym urządzeniu. Niektóre przekaźniki, klienty i indeksy wyszukiwania mogą zachować kopie. Inne zalogowane urządzenia pozostają aktywne, dopóki nie usuniesz na nich kluczy.';

  @override
  String get findPeopleNoContacts =>
      'Nie znaleziono kontaktów.\nZacznij obserwować ludzi, aby zobaczyć ich tutaj.';

  @override
  String get geoBlockedCityLabel => 'Miasto';

  @override
  String get geoBlockedCountryLabel => 'Kraj';

  @override
  String get geoBlockedDefaultReason =>
      'Ta usługa jest niedostępna w twoim regionie z powodu lokalnych przepisów.';

  @override
  String get geoBlockedLegalNotice =>
      'Szanujemy twoje lokalne prawa i przepisy. To ograniczenie opiera się na lokalizacji twojego adresu IP.';

  @override
  String get geoBlockedRegionLabel => 'Region';

  @override
  String get geoBlockedTitle => 'Usługa niedostępna';

  @override
  String get likedVideosEmpty => 'Brak polubionych filmów';

  @override
  String get likedVideosInvalidRoute => 'Nieprawidłowa trasa';

  @override
  String get likedVideosTitle => 'Polubione filmy';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Ponawianie przesyłania…';

  @override
  String get uploadFailureSheetSaveToDraftsButton =>
      'Zapisz do wersji roboczych';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar =>
      'Zapisano do wersji roboczych';

  @override
  String get uploadFailureSheetTitle => 'Przesyłanie nie powiodło się';

  @override
  String get uploadFailureSheetTryAgainButton => 'Spróbuj ponownie';

  @override
  String get videoEditorAudioImportAudio => 'Zaimportuj dźwięk';

  @override
  String get videoEditorAudioImportFailed => 'Import dźwięku nie powiódł się.';

  @override
  String get videoIconPlaceholderLabel => 'Film';

  @override
  String get publishErrorNotSignedIn => 'Zaloguj się, aby publikować filmy.';

  @override
  String get publishErrorNoRetry => 'Brak przesyłania do ponowienia.';

  @override
  String get publishErrorNoInternet =>
      'Brak połączenia z internetem. Sprawdź Wi-Fi lub dane komórkowe i spróbuj ponownie.';

  @override
  String get publishErrorServerUnreachable =>
      'Nie udało się połączyć z serwerem. Spróbuj ponownie za chwilę.';

  @override
  String get publishErrorTimeout =>
      'Przesyłanie przekroczyło limit czasu. Spróbuj użyć lepszego połączenia lub mniejszego filmu.';

  @override
  String get publishErrorTls =>
      'Bezpieczne połączenie nie powiodło się. Sprawdź swoją sieć — publiczne Wi-Fi może blokować przesyłanie.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Serwer multimediów ($serverName) jest niedostępny. Możesz wybrać inny w ustawieniach.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Plik wideo jest za duży dla serwera. Spróbuj go przyciąć lub obniżyć jakość.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Serwer multimediów ($serverName) napotkał błąd wewnętrzny. Możesz wybrać inny w ustawieniach.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Serwer multimediów ($serverName) jest chwilowo niedostępny. Spróbuj ponownie za moment lub wybierz inny w ustawieniach.';
  }

  @override
  String get publishErrorForbidden =>
      'Nie masz uprawnień, aby przesyłać na ten serwer.';

  @override
  String get publishErrorFileNotFound =>
      'Nie znaleziono pliku wideo. Mógł zostać usunięty. Nagraj ponownie i spróbuj jeszcze raz.';

  @override
  String get publishErrorLowStorage =>
      'Za mało miejsca w pamięci urządzenia. Zwolnij trochę miejsca i spróbuj ponownie.';

  @override
  String get publishErrorThumbnailFailed =>
      'Film został przesłany, ale nie udało się przygotować miniatury. Spróbuj ponownie.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Film został przesłany, ale nie udało się opublikować posta. Sprawdź ustawienia przekaźników i spróbuj ponownie.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Film został przesłany, ale ten dźwięk nie jest dopuszczony do ponownego użycia. Wybierz inny dźwięk, żeby opublikować.';

  @override
  String get publishErrorInterrupted =>
      'Przesyłanie zostało przerwane. Chcesz spróbować ponownie?';

  @override
  String get publishErrorAccountChanged =>
      'Ten film należy do innego konta. Wróć na tamto konto, żeby go opublikować.';

  @override
  String get publishErrorGeneric => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get publishErrorRateLimited =>
      'Zbyt wiele przesyłań w tej chwili. Poczekaj chwilę i spróbuj ponownie.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Sesja przesyłania wygasła. Spróbuj ponownie.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine nie ma uprawnień do przesyłania. Sprawdź uprawnienia aplikacji w ustawieniach i spróbuj ponownie.';

  @override
  String get publishErrorOutOfMemory =>
      'Za mało pamięci operacyjnej urządzenia. Zamknij kilka aplikacji i spróbuj ponownie.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Nie udało się przygotować tekstu i naklejek z tej wersji roboczej. Otwórz ją w edytorze i opublikuj ponownie.';

  @override
  String get publishErrorUnknownServer => 'Nieznany serwer';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filtr: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Brak wyników dla „$query”';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Zobacz filmy oznaczone $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Dźwięk: $soundName od $creatorName. Dotknij, aby zobaczyć szczegóły dźwięku.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Oryginalny dźwięk od $creatorName. Dotknij, aby użyć tego dźwięku.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Dźwięk: $soundName od $creatorName. Dotknij, aby zobaczyć szczegóły.';
  }

  @override
  String get soundDetailLoadError =>
      'Nie udało się wczytać dźwięku. Spróbuj ponownie.';

  @override
  String get soundDetailNotFoundMessage => 'Nie udało się znaleźć tego dźwięku';

  @override
  String get soundDetailNotFoundTitle => 'Nie znaleziono dźwięku';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count pętli';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Dźwięk z tego filmu nie jest dostępny osobno.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Oryginalny dźwięk - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Ta osoba opublikowała oryginalnego Vine\'a, którego Divine znalazło w archiwum. To nie jest odznaka weryfikacji konta.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Znacznik profilu';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine przyznaje ten znacznik kontom zespołu. To coś innego niż NIP-05, zweryfikowane linki konta i status OG Viner.';

  @override
  String get unfollowConfirmButton => 'Przestań obserwować';

  @override
  String get videoClipSaveFailed => 'Nie udało się zapisać klipu';

  @override
  String videoClipSaveTo(String destination) {
    return 'Zapisz do $destination';
  }

  @override
  String get videoClipDelete => 'Usuń klip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Zainspirowane przez $creatorName +$additionalCreatorCount. Dotknij, aby zobaczyć jego profil.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Zainspirowane przez $creatorName. Dotknij, aby zobaczyć jego profil.';
  }

  @override
  String get bugReportSendReport => 'Wyślij zgłoszenie';

  @override
  String get supportSubjectRequiredLabel => 'Temat *';

  @override
  String get supportPublicSubmissionTitle => 'Publiczny wpis na GitHubie';

  @override
  String get supportPublicSubmissionMessage =>
      'Wszystko, co tu prześlesz, zostanie opublikowane w naszym repozytorium open source na GitHubie, aby deweloperzy mogli się tym zająć. Wpis oraz konto, na które jesteś zalogowany, będą publicznie widoczne dla wszystkich.';

  @override
  String get supportRequiredHelper => 'Wymagane';

  @override
  String get supportFieldLimitReached =>
      'To maksymalna długość. Wszystko powyżej nie zostało dodane.';

  @override
  String get bugReportSubjectHint => 'Krótkie podsumowanie problemu';

  @override
  String get bugReportDescriptionRequiredLabel => 'Co się stało? *';

  @override
  String get bugReportDescriptionHint => 'Opisz problem, na który natrafiłeś';

  @override
  String get bugReportStepsLabel => 'Kroki do odtworzenia';

  @override
  String get bugReportStepsHint =>
      '1. Przejdź do...\n2. Stuknij w...\n3. Zobacz błąd';

  @override
  String get bugReportExpectedBehaviorLabel => 'Oczekiwane zachowanie';

  @override
  String get bugReportExpectedBehaviorHint =>
      'Co powinno się stać zamiast tego?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Informacje o urządzeniu i logi zostaną dołączone automatycznie.';

  @override
  String get bugReportSuccessMessage =>
      'Dzięki! Dostaliśmy twoje zgłoszenie i wykorzystamy je, żeby ulepszyć Divine.';

  @override
  String get bugReportAttachImages => 'Dołącz zdjęcia';

  @override
  String bugReportImagesCount(int count, int max) {
    return 'Wybrano $count z $max zdjęć';
  }

  @override
  String get bugReportRemoveImage => 'Usuń zdjęcie';

  @override
  String get bugReportUploadFailed =>
      'Nie udało się przesłać wybranego zdjęcia. Spróbuj ponownie albo wyślij zgłoszenie bez niego.';

  @override
  String get bugReportSendFailed =>
      'Nie udało się wysłać zgłoszenia błędu. Spróbuj ponownie później.';

  @override
  String get featureRequestSendRequest => 'Wyślij prośbę';

  @override
  String get featureRequestSubjectHint =>
      'Krótkie podsumowanie twojego pomysłu';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Czego byś chciał? *';

  @override
  String get featureRequestDescriptionHint => 'Opisz funkcję, której chcesz';

  @override
  String get featureRequestUsefulnessLabel => 'Jak by to było przydatne?';

  @override
  String get featureRequestUsefulnessHint =>
      'Wyjaśnij, jaką korzyść dałaby ta funkcja';

  @override
  String get featureRequestWhenLabel => 'Kiedy byś tego użył?';

  @override
  String get featureRequestWhenHint =>
      'Opisz sytuacje, w których to by pomogło';

  @override
  String get featureRequestSuccessMessage =>
      'Dzięki! Dostaliśmy twoją prośbę i ją przejrzymy.';

  @override
  String get featureRequestSendFailed =>
      'Nie udało się wysłać prośby o funkcję. Spróbuj ponownie później.';

  @override
  String get notificationFollowBack => 'Zaobserwuj';

  @override
  String get followingTitle => 'Obserwowani';

  @override
  String followingTitleForName(String displayName) {
    return 'Kogo obserwuje $displayName';
  }

  @override
  String get followingFailedToLoadList =>
      'Nie udało się załadować listy obserwowanych';

  @override
  String get followingEmptyTitle => 'Jeszcze nikogo nie obserwujesz';

  @override
  String get followersTitle => 'Obserwujący';

  @override
  String followersTitleForName(String displayName) {
    return 'Obserwujący $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Nie udało się załadować listy obserwujących';

  @override
  String get followersEmptyTitle => 'Jeszcze brak obserwujących';

  @override
  String get followersUpdateFollowFailed =>
      'Nie udało się zaktualizować statusu obserwowania. Spróbuj ponownie.';

  @override
  String get followersSortSemanticLabel => 'Sortuj obserwujących';

  @override
  String get followingSortSemanticLabel => 'Sortuj obserwowanych';

  @override
  String get followSortTitle => 'Sortuj według';

  @override
  String get followSortNewest => 'Najpierw najnowsi';

  @override
  String get followSortOldest => 'Najpierw najstarsi';

  @override
  String get newMessageTitle => 'Nowa wiadomość';

  @override
  String get newMessageFindPeople => 'Znajdź ludzi';

  @override
  String get newMessageNoContacts =>
      'Brak kontaktów.\nObserwuj ludzi, żeby tu się pojawili.';

  @override
  String get newMessageNoUsersFound => 'Nie znaleziono użytkowników';

  @override
  String get hashtagSearchTitle => 'Szukaj hashtagów';

  @override
  String get hashtagSearchSubtitle => 'Odkrywaj popularne tematy i treści';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Nie znaleziono hashtagów dla \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Wyszukiwanie nieudane';

  @override
  String get userNotAvailableTitle => 'Konto niedostępne';

  @override
  String get userNotAvailableBody => 'To konto jest teraz niedostępne.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Nie udało się zapisać ustawień. Spróbuj ponownie.';

  @override
  String get blossomValidServerUrl =>
      'Wprowadź prawidłowy URL serwera (np. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Zapisano ustawienia Blossom';

  @override
  String get blossomSaveTooltip => 'Zapisz';

  @override
  String get blossomAboutTitle => 'O Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom to zdecentralizowany protokół przechowywania mediów, który pozwala uploadować filmy na dowolny kompatybilny serwer. Domyślnie filmy są uploadowane na serwer Blossom Divine. Włącz opcję poniżej, żeby zamiast tego użyć własnego serwera.';

  @override
  String get blossomUseCustomServer => 'Użyj własnego serwera Blossom';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Filmy będą uploadowane na twój własny serwer Blossom';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Twoje filmy są aktualnie uploadowane na serwer Blossom Divine';

  @override
  String get blossomCustomServerUrl => 'URL własnego serwera Blossom';

  @override
  String get blossomCustomServerHelper =>
      'Wprowadź URL swojego własnego serwera Blossom';

  @override
  String get blossomPopularServers => 'Popularne serwery Blossom';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL serwera Blossom musi używać https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Nie udało się zaktualizować ustawienia crosspostu';

  @override
  String get blueskySignInRequired =>
      'Zaloguj się, żeby zarządzać ustawieniami Bluesky';

  @override
  String get blueskyPublishVideos => 'Publikuj filmy na Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Twoje filmy będą publikowane na Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Twoje filmy nie będą publikowane na Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Twoje wcześniejsze filmy też zostaną opublikowane';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Gdy to włączysz, Divine zacznie wysyłać Twoje starsze filmy do Bluesky, od najstarszych, bez pośpiechu z dziennym limitem.';

  @override
  String get blueskyHandle => 'Nazwa Bluesky';

  @override
  String get blueskyDid => 'DID Bluesky';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Konto przygotowane i gotowe';

  @override
  String get blueskyStatusPending => 'Trwa przygotowywanie konta...';

  @override
  String get blueskyStatusFailed => 'Przygotowywanie konta nieudane';

  @override
  String get blueskyStatusDisabled => 'Konto wyłączone';

  @override
  String get blueskyStatusNotLinked => 'Brak powiązanego konta Bluesky';

  @override
  String get blueskyUsernameRequired =>
      'Skonfiguruj identyfikator divine.video przed publikacją na Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Publikowanie na Bluesky wymaga zarezerwowanego identyfikatora nazwa.divine.video.';

  @override
  String get blueskyUsernameSyncPending =>
      'Twój identyfikator Divine jest zarezerwowany. Łączymy go z Bluesky – spróbuj ponownie za chwilę.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Nie udało nam się sprawdzić twojego identyfikatora Divine. Spróbuj ponownie.';

  @override
  String get blueskySetUpHandle => 'Skonfiguruj';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Publikowanie na Bluesky jest chwilowo niedostępne. Spróbuj ponownie.';

  @override
  String get invitesTitle => 'Zaproś znajomych';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszenia gotowych do wygenerowania',
      many: '$count zaproszeń gotowych do wygenerowania',
      few: '$count zaproszenia gotowe do wygenerowania',
      one: '1 zaproszenie gotowe do wygenerowania',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Wygeneruj kod, gdy będziesz gotowy(-a) się nim podzielić.';

  @override
  String get invitesGenerateButtonLabel => 'Wygeneruj zaproszenie';

  @override
  String get invitesNoneAvailable => 'Brak dostępnych zaproszeń w tej chwili';

  @override
  String get invitesShareWithPeople =>
      'Udostępniaj Divine ludziom, których znasz';

  @override
  String get invitesUsedInvites => 'Wykorzystane zaproszenia';

  @override
  String invitesShareMessage(String code) {
    return 'Dołącz do mnie na Divine! Użyj kodu zaproszenia $code, żeby zacząć:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Kopiuj zaproszenie';

  @override
  String get invitesCopied => 'Skopiowano zaproszenie!';

  @override
  String get invitesShareInvite => 'Udostępnij zaproszenie';

  @override
  String get invitesShareSubject => 'Dołącz do mnie na Divine';

  @override
  String get invitesClaimed => 'Wykorzystane';

  @override
  String get invitesCouldNotLoad => 'Nie udało się wczytać zaproszeń';

  @override
  String get invitesRetry => 'Spróbuj ponownie';

  @override
  String get searchSomethingWentWrong => 'Coś poszło nie tak';

  @override
  String get searchTryAgain => 'Spróbuj ponownie';

  @override
  String get searchForLists => 'Szukaj list';

  @override
  String get searchFindCuratedVideoLists =>
      'Znajdź wyselekcjonowane listy filmów';

  @override
  String get searchEnterQuery => 'Wpisz zapytanie';

  @override
  String get searchDiscoverSomethingInteresting => 'Odkryj coś ciekawego';

  @override
  String get searchPeopleSectionHeader => 'Osoby';

  @override
  String get searchPeopleLoadingLabel => 'Wczytywanie wyników wśród osób';

  @override
  String get searchTagsSectionHeader => 'Tagi';

  @override
  String get searchTagsLoadingLabel => 'Wczytywanie wyników wśród tagów';

  @override
  String get searchVideosSectionHeader => 'Filmy';

  @override
  String get searchVideosLoadingLabel => 'Wczytywanie wyników wśród filmów';

  @override
  String get searchVideosSortOptionsLabel => 'Sortuj wyniki filmów';

  @override
  String get searchVideosSortTrending => 'Na czasie';

  @override
  String get searchVideosSortLoops => 'Najwięcej pętli';

  @override
  String get searchVideosSortEngagement => 'Najbardziej angażujące';

  @override
  String get searchVideosSortRecent => 'Najnowsze';

  @override
  String get searchListsSectionHeader => 'Listy';

  @override
  String get searchListsLoadingLabel => 'Ładowanie wyników list';

  @override
  String get cameraAgeRestriction =>
      'Musisz mieć co najmniej 16 lat, aby tworzyć treści';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Przekaźnik bunker musi używać wss:// (ws:// jest dozwolony tylko dla localhost)';

  @override
  String get timeNow => 'teraz';

  @override
  String timeShortMinutes(int count) {
    return '${count}min';
  }

  @override
  String timeShortHours(int count) {
    return '${count}g';
  }

  @override
  String timeShortDays(int count) {
    return '${count}d';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}tyg';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}mie';
  }

  @override
  String timeShortYears(int count) {
    return '${count}r';
  }

  @override
  String get timeVerboseNow => 'Teraz';

  @override
  String timeAgo(String time) {
    return '$time temu';
  }

  @override
  String get timeToday => 'Dzisiaj';

  @override
  String get timeYesterday => 'Wczoraj';

  @override
  String get timeJustNow => 'przed chwilą';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min temu';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}g temu';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d temu';
  }

  @override
  String get draftTimeJustNow => 'Przed chwilą';

  @override
  String get contentLabelNudity => 'Nagość';

  @override
  String get contentLabelSexualContent => 'Treści seksualne';

  @override
  String get contentLabelPornography => 'Pornografia';

  @override
  String get contentLabelGraphicMedia => 'Drastyczne treści';

  @override
  String get contentLabelViolence => 'Przemoc';

  @override
  String get contentLabelSelfHarm => 'Samookaleczenie/Samobójstwo';

  @override
  String get contentLabelDrugUse => 'Używanie narkotyków';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tytoń/Palenie';

  @override
  String get contentLabelGambling => 'Hazard';

  @override
  String get contentLabelProfanity => 'Wulgaryzmy';

  @override
  String get contentLabelHateSpeech => 'Mowa nienawiści';

  @override
  String get contentLabelHarassment => 'Nękanie';

  @override
  String get contentLabelFlashingLights => 'Migające światła';

  @override
  String get contentLabelAiGenerated => 'Wygenerowane przez AI';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Oszustwo';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Wprowadzające w błąd';

  @override
  String get contentLabelSensitiveContent => 'Wrażliwe treści';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName polubił(a) Twoje wideo';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName polubił(a) Twój komentarz';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName skomentował(a) Twoje wideo';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName zaczął/zaczęła Cię obserwować';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName wspomniał(a) o Tobie';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName udostępnił(a) Twoje wideo';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName opublikował nowy vine';
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
      other: '$count twoich vine\'ów',
      many: '$count twoich vine\'ów',
      few: '$count twoje vine\'y',
      one: 'twojego vine\'a',
    );
    return '$actorName dodał(a) $_temp0 do $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName odpowiedział(a) na Twój komentarz';
  }

  @override
  String get notificationAndConnector => 'i';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count innych osób',
      one: '1 inna osoba',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Masz nową aktualizację';

  @override
  String get commentReplyToPrefix => 'Odp.:';

  @override
  String get commentHideKeyboard => 'Ukryj klawiaturę';

  @override
  String get commentsErrorLoadFailed => 'Nie udało się wczytać komentarzy';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Zaloguj się, aby komentować';

  @override
  String get commentsErrorPostCommentFailed => 'Nie udało się dodać komentarza';

  @override
  String get commentsErrorPostReplyFailed => 'Nie udało się dodać odpowiedzi';

  @override
  String get commentsErrorEditFailed => 'Nie udało się edytować komentarza';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Zaloguj się, aby brać udział';

  @override
  String get commentsErrorVoteFailed => 'Nie udało się zagłosować na komentarz';

  @override
  String get commentsErrorReportFailed => 'Nie udało się zgłosić komentarza';

  @override
  String get commentsErrorBlockFailed => 'Nie udało się zablokować użytkownika';

  @override
  String get commentsErrorDeleteFailed => 'Nie udało się usunąć komentarza';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count komentarza',
      many: '$count komentarzy',
      few: '$count komentarze',
      one: '$count komentarz',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Publikowanie…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Twoja odpowiedź wideo jest publikowana';

  @override
  String get commentsSortNew => 'Nowe';

  @override
  String get commentsSortTop => 'Najlepsze';

  @override
  String get commentsSortOld => 'Stare';

  @override
  String get commentsSortSemanticLabel => 'Sortowanie komentarzy';

  @override
  String get commentReply => 'Odpowiedz';

  @override
  String get commentReplySemanticLabel => 'Odpowiedz na komentarz';

  @override
  String get commentUpvoteLabel => 'Zagłosuj za komentarzem';

  @override
  String get commentRemoveUpvoteLabel => 'Usuń głos za';

  @override
  String get commentDownvoteLabel => 'Zagłosuj przeciw komentarzowi';

  @override
  String get commentRemoveDownvoteLabel => 'Usuń głos przeciw';

  @override
  String get commentsInputHint => 'Dodaj komentarz...';

  @override
  String get commentsInputHintEdit => 'Edytuj komentarz...';

  @override
  String get commentsEmptyTitle => 'Jeszcze nie ma komentarzy';

  @override
  String get commentsEmptySubtitle => 'Zacznij imprezę!';

  @override
  String get draftUntitled => 'Bez tytułu';

  @override
  String get contentWarningNone => 'Brak';

  @override
  String get textBackgroundNone => 'Brak';

  @override
  String get textBackgroundSolid => 'Pełne';

  @override
  String get textBackgroundHighlight => 'Wyróżnienie';

  @override
  String get textBackgroundTransparent => 'Przezroczyste';

  @override
  String get textAlignLeft => 'Lewo';

  @override
  String get textAlignRight => 'Prawo';

  @override
  String get textAlignCenter => 'Środek';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Aparat nie jest jeszcze obsługiwany w wersji webowej';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Robienie zdjęć i nagrywanie kamerą nie są jeszcze dostępne w wersji webowej.';

  @override
  String get cameraPermissionBackToFeed => 'Wróć do feedu';

  @override
  String get cameraCouldNotStart => 'Nie udało się uruchomić aparatu';

  @override
  String get cameraUnsupportedPlatform =>
      'Aparat nie jest jeszcze dostępny na tej platformie.\nNadal możesz przeglądać i oglądać filmy.';

  @override
  String get cameraPermissionErrorTitle => 'Błąd uprawnień';

  @override
  String get cameraPermissionErrorDescription =>
      'Wystąpił błąd podczas sprawdzania uprawnień.';

  @override
  String get cameraPermissionRetry => 'Spróbuj ponownie';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Zezwól na dostęp do aparatu i mikrofonu';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'To pozwala nagrywać i edytować filmy bezpośrednio w aplikacji i nic więcej.';

  @override
  String get cameraPermissionGoToSettings => 'Przejdź do ustawień';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Dlaczego sześć sekund?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Krótkie klipy dają przestrzeń na spontaniczność. Format 6 sekund pomaga uchwycić autentyczne chwile w momencie, gdy się dzieją.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Rozumiem!';

  @override
  String get videoRecorderUploadTitle => 'Dlaczego nie ma uploadu?';

  @override
  String get videoRecorderUploadBody =>
      'To, co widzisz na Divine, zostało stworzone przez ludzi: surowe i uchwycone w danej chwili. W przeciwieństwie do platform, które zezwalają na mocno wyprodukowane lub generowane przez AI uploady, stawiamy na autentyczność doświadczenia bezpośrednio z kamery.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Trzymając tworzenie wewnątrz aplikacji, możemy lepiej zagwarantować, że treści są prawdziwe i niezmienione. Nie otwieramy obecnie uploadów z zewnętrznej galerii, aby chronić tę autentyczność i utrzymać naszą społeczność wolną od syntetycznych treści w jak największym stopniu.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Przełącz na Capture lub Classic, żeby nakręcić coś prawdziwego.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Dowiedz się, jak działa weryfikacja';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Znaleźliśmy niedokończoną pracę';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Czy chcesz kontynuować od miejsca, w którym skończyłeś?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Tak, kontynuuj';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Nie, rozpocznij nowy film';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Nie udało się przywrócić wersji roboczej';

  @override
  String get videoRecorderStopRecordingTooltip => 'Zatrzymaj nagrywanie';

  @override
  String get videoRecorderStartRecordingTooltip => 'Rozpocznij nagrywanie';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Nagrywanie. Dotknij dowolnego miejsca, aby zatrzymać';

  @override
  String get videoRecorderTapToStartLabel =>
      'Dotknij dowolnego miejsca, aby rozpocząć nagrywanie';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Usuń ostatni klip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Przełącz aparat';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Powiększ do $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Przełącz siatkę';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Przełącz klatkę odniesienia';

  @override
  String get videoRecorderGhostFrameEnabled => 'Klatka odniesienia włączona';

  @override
  String get videoRecorderGhostFrameDisabled => 'Klatka odniesienia wyłączona';

  @override
  String get videoRecorderClipDeletedMessage => 'Klip przeniesiony do kosza';

  @override
  String get videoRecorderClipUndoLabel => 'Cofnij';

  @override
  String get libraryTrashEmptyTitle => 'Kosz jest pusty';

  @override
  String get libraryTrashEmptySubtitle =>
      'Usunięte klipy pozostają tutaj przez 30 dni, zanim zostaną trwale usunięte.';

  @override
  String get libraryTrashRestoreLabel => 'Przywróć';

  @override
  String get libraryTrashDeleteNowLabel => 'Usuń teraz';

  @override
  String get libraryTrashEmptyAllLabel => 'Opróżnij kosz';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Usunąć klip teraz?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'To od razu usunie klip z kosza.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Opróżnić kosz?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipów',
      one: '1 klip',
    );
    return 'To od razu trwale usunie z kosza $_temp0.';
  }

  @override
  String get videoRecorderCloseLabel => 'Zamknij rejestrator wideo';

  @override
  String get videoRecorderContinueToEditorLabel => 'Przejdź do edytora wideo';

  @override
  String get videoRecorderCameraPreviewLabel => 'Podgląd aparatu';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Ustaw ostrość aparatu';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Przełącz na tryb $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => 'Dodaj audio przed nagraniem';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Nie udało się utworzyć filmu. Spróbuj ponownie.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zostało $count ujęcia',
      many: 'Zostało $count ujęć',
      few: 'Zostały $count ujęcia',
      one: 'Zostało 1 ujęcie',
      zero: 'Brak wolnych ujęć',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Przełącz lampę błyskową';

  @override
  String get videoRecorderCycleTimerLabel => 'Zmień timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Przełącz proporcje';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilizacja';

  @override
  String get videoRecorderStabilizationModeOff => 'Wyłączona';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standardowa';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Filmowa';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Filmowa rozszerzona';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Zoptymalizowana pod podgląd';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Niskie opóźnienie';

  @override
  String get videoRecorderStabilizationModeAuto => 'Automatyczna';

  @override
  String get videoRecorderFlashValueOff => 'Wyłączona';

  @override
  String get videoRecorderFlashValueOn => 'Włączona';

  @override
  String get videoRecorderFlashValueAuto => 'Automatyczna';

  @override
  String get videoRecorderTimerValueOff => 'Wyłączony';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 sekundy';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 sekund';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Kwadratowy';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Pionowy';

  @override
  String get videoRecorderCameraValueFront => 'Aparat przedni';

  @override
  String get videoRecorderCameraValueBack => 'Aparat tylny';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Biblioteka klipów, brak klipów';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Otwórz bibliotekę klipów, $clipCount klipów',
      one: 'Otwórz bibliotekę klipów, 1 klip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Otwórz bibliotekę poklatkową, $frameCount klatki',
      many: 'Otwórz bibliotekę poklatkową, $frameCount klatek',
      few: 'Otwórz bibliotekę poklatkową, $frameCount klatki',
      one: 'Otwórz bibliotekę poklatkową, 1 klatka',
      zero: 'Otwórz bibliotekę poklatkową',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Otwórz kamerę';

  @override
  String get videoEditorLibraryLabel => 'Biblioteka';

  @override
  String get videoEditorTextLabel => 'Tekst';

  @override
  String get videoEditorDrawLabel => 'Rysuj';

  @override
  String get videoEditorFilterLabel => 'Filtr';

  @override
  String get videoEditorTuneLabel => 'Dostosuj';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Otwórz edytor korekt';

  @override
  String get videoEditorTuneBrightness => 'Jasność';

  @override
  String get videoEditorTuneContrast => 'Kontrast';

  @override
  String get videoEditorTuneSaturation => 'Nasycenie';

  @override
  String get videoEditorTuneExposure => 'Ekspozycja';

  @override
  String get videoEditorTuneHue => 'Odcień';

  @override
  String get videoEditorTuneTemperature => 'Temperatura';

  @override
  String get videoEditorTuneTint => 'Zabarwienie';

  @override
  String get videoEditorTuneFade => 'Zanikanie';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Dodaj';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Otwórz bibliotekę';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Otwórz edytor audio';

  @override
  String get videoEditorCaptionsLabel => 'Napisy';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'Otwórz edytor napisów';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Wypal na wideo';

  @override
  String get videoEditorCaptionsPresetCustom => 'Własny';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Własny styl';

  @override
  String get videoEditorCaptionsCustomApply => 'Zastosuj';

  @override
  String get videoEditorCaptionsCustomFont => 'Czcionka';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Kolor tekstu';

  @override
  String get videoEditorCaptionsCustomBackground => 'Tło';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Kolor tła';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animacja';

  @override
  String get videoEditorCaptionsAnimationNone => 'Brak';

  @override
  String get videoEditorCaptionsAnimationFade => 'Zanikanie';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Sprężyna';

  @override
  String get videoEditorCaptionsEditTitle => 'Napisy';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Słuchamy…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Zamieniamy Twoje audio w propozycje napisów.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Nie usłyszeliśmy żadnej mowy. Nadal możesz napisać napisy samodzielnie.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Rozpoznawanie mowy nie jest dostępne na tym urządzeniu. Możesz napisać napisy samodzielnie.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Rozpoznawanie mowy nie jest dozwolone. Włącz je w Ustawieniach albo napisz napisy samodzielnie.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Transkrypcja tym razem się nie udała. Możesz napisać napisy samodzielnie.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Napiszę napisy samodzielnie';

  @override
  String get videoEditorCaptionsAddCue => 'Dodaj napis';

  @override
  String get videoEditorCaptionsCueTextHint => 'Tekst napisu';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Usuń napis';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Usuń wszystkie napisy';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => 'Usunąć napisy?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Cały tekst i czasy zostaną utracone.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => 'Zamknij edytor napisów';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Zatwierdź napisy';

  @override
  String get videoEditorCaptionsPresetTitle => 'Styl napisów';

  @override
  String get videoEditorCaptionsPresetClassic => 'Klasyczny';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Nagłówek';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Maszyna do pisania';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marker';

  @override
  String get videoEditorCaptionsPresetScript => 'Kaligrafia';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegancki';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bąbelek';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Pogrubiony';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Marzycielski';

  @override
  String get videoEditorCaptionsPresetOcean => 'Ocean';

  @override
  String get videoEditorCaptionsPresetSunny => 'Słoneczny';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Odręczny';

  @override
  String get videoEditorCaptionsPresetSerif => 'Szeryfowy';

  @override
  String get videoEditorCaptionsPresetStamp => 'Stempel';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Otwórz edytor tekstu';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Otwórz edytor rysowania';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Otwórz edytor filtrów';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Otwórz edytor naklejek';

  @override
  String get videoEditorSaveDraftTitle => 'Zapisać wersję roboczą?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Zachowaj edycje na później albo odrzuć je i opuść edytor.';

  @override
  String get videoEditorSaveDraftButton => 'Zapisz wersję roboczą';

  @override
  String get videoEditorDiscardChangesButton => 'Odrzuć zmiany';

  @override
  String get videoEditorKeepEditingButton => 'Kontynuuj edycję';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Strefa upuszczania do usuwania warstwy';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Puść, aby usunąć warstwę';

  @override
  String get videoEditorDoneLabel => 'Gotowe';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Odtwórz lub wstrzymaj wideo';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Nieprawidłowa pozycja podziału. Oba klipy muszą mieć co najmniej $minDurationMs ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Zapisz wybrany klip';

  @override
  String get videoEditorSaveClip => 'Zapisz klip';

  @override
  String get videoEditorClipSavedSuccess => 'Klip zapisany w bibliotece';

  @override
  String get videoEditorClipSaveFailed => 'Nie udało się zapisać klipu';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Wybór koloru';

  @override
  String get videoEditorUndoSemanticLabel => 'Cofnij';

  @override
  String get videoEditorRedoSemanticLabel => 'Ponów';

  @override
  String get videoEditorTextColorSemanticLabel => 'Kolor tekstu';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Wyrównanie tekstu';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Tło tekstu';

  @override
  String get videoEditorFontSemanticLabel => 'Czcionka';

  @override
  String get videoEditorNoStickersFound => 'Nie znaleziono naklejek';

  @override
  String get videoEditorNoStickersAvailable => 'Brak dostępnych naklejek';

  @override
  String get videoEditorFailedLoadStickers => 'Nie udało się wczytać naklejek';

  @override
  String get videoEditorVoiceOverLabel => 'Narracja';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Nagranie $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Nagraj narrację';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Rozpocznij nagrywanie';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Zatrzymaj nagrywanie';

  @override
  String get videoEditorVoiceOverHint =>
      'Dotknij, aby nagrać. Dodaj dowolną liczbę ujęć.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nagrań',
      one: '1 nagranie',
      zero: 'Brak nagrań',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Usuń ostatnie nagranie';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Wymagany dostęp do mikrofonu';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Zezwól na dostęp do mikrofonu, aby nagrać narrację.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Otwórz ustawienia';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Rozpoczęto nagrywanie';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Zapisano nagranie';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Nagranie jest dłuższe niż Twój film';

  @override
  String get videoEditorPlaySemanticLabel => 'Odtwórz';

  @override
  String get videoEditorPauseSemanticLabel => 'Wstrzymaj';

  @override
  String get videoEditorVolumeSemanticLabel => 'Dostosuj głośność';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Głośność $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Przesuń, aby dostosować';

  @override
  String get videoEditorChromaKeyLabel => 'Zielone tło';

  @override
  String get videoEditorChromaKeyTitle => 'Zielone tło';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Skonfiguruj zielone tło dla tego klipu';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Odrzuć zmiany zielonego tła';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Zastosuj zielone tło';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Wykryj automatycznie';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Zielony';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Niebieski';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Kolor tła';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Siła';

  @override
  String get videoEditorChromaKeyAmountHint => 'Ile koloru tła znika';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Krawędź';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Zmiękcza wycięcie, żeby włosy nie były poszarpane';

  @override
  String get videoEditorChromaKeySpillLabel => 'Poświata';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Ściąga kolor tła z twojego obiektu';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Zastąp przez';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Nic';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Kolor';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Obraz';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Klip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Wideo nie przechowuje przezroczystości, więc w eksporcie będzie czarne.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Nie znaleziono tła. Musi sięgać krawędzi kadru — w przeciwnym razie wybierz kolor ręcznie.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Wybierz klip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Twoja biblioteka jest pusta. Zapisz najpierw klip, a potem użyj go jako tła.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Nie udało się wczytać tego obrazu.';

  @override
  String get videoEditorChromaKeyRemove => 'Usuń zielone tło';

  @override
  String get videoEditorChromaKeyFailed =>
      'Nie udało się zastosować zielonego tła. Twój klip pozostaje bez zmian.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Nie udało się usunąć zielonego tła. Twój klip pozostaje bez zmian.';

  @override
  String get videoEditorChromaKeyApplying => 'Stosowanie zielonego tła…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'To urządzenie nie pokaże podglądu na żywo. Twoje ustawienia i tak zadziałają przy eksporcie.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Klip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Usuń';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Usuń wybrany element';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Klatki na obraz';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klatki',
      many: '$count klatek',
      few: '$count klatki',
      one: '1 klatka',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Klatki';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count klatek na obraz';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Klatka poklatkowa $position z $total';
  }

  @override
  String get videoEditorEditLabel => 'Edytuj';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Edytuj wybrany element';

  @override
  String get videoEditorDuplicateLabel => 'Duplikuj';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplikuj wybrany element';

  @override
  String get videoEditorCombineLabel => 'Połącz';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Połącz wybrane rysunki w jedną warstwę';

  @override
  String get videoEditorSplitLabel => 'Podziel';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Podziel wybrany klip';

  @override
  String get videoEditorExtractAudioLabel => 'Wyodrębnij dźwięk';

  @override
  String get videoEditorClipAudioTitle => 'Dźwięk klipu';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Wyodrębnij dźwięk z klipu i wycisz oryginał';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Nie można wyodrębnić audio: klip nie jest dostępny lokalnie.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Nie udało się wyodrębnić audio. Spróbuj ponownie.';

  @override
  String get videoEditorSpeedLabel => 'Prędkość';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Ustaw prędkość odtwarzania dla wybranego klipu';

  @override
  String get videoEditorReverseLabel => 'Odwróć';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Włącz lub wyłącz odwrotne odtwarzanie dla wybranego klipu';

  @override
  String get videoEditorReverseProgressLabel =>
      'Chwileczkę, odwracamy Twój klip';

  @override
  String get videoEditorTransformLabel => 'Przekształć';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Przytnij, obróć lub odbij wybrany klip';

  @override
  String get videoEditorTransformProgressLabel =>
      'Chwila, przekształcamy Twój klip';

  @override
  String get videoEditorTransformFailed =>
      'Nie udało się przekształcić klipu. Spróbuj ponownie.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Nie można przekształcić: klip nie jest dostępny lokalnie.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Przytnij, obróć lub odbij zaznaczoną klatkę';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Chwileczkę, przekształcamy twoją klatkę';

  @override
  String get videoEditorTransformFrameFailed =>
      'Nie udało się przekształcić klatki. Spróbuj ponownie.';

  @override
  String get videoEditorTransformRotateLabel => 'Obróć';

  @override
  String get videoEditorTransformFlipLabel => 'Odbij';

  @override
  String get videoEditorTransformResetLabel => 'Resetuj';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'Zastosuj przekształcenie';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Anuluj przekształcenie';

  @override
  String get videoEditorTransformPlayLabel => 'Odtwórz';

  @override
  String get videoEditorTransformPauseLabel => 'Pauza';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Nie można odwrócić: klip nie jest dostępny lokalnie.';

  @override
  String get videoEditorReverseFailed =>
      'Nie udało się odwrócić klipu. Spróbuj ponownie.';

  @override
  String get videoEditorSpeedSheetTitle => 'Prędkość klipu';

  @override
  String get videoEditorTransitionSheetTitle => 'Przejście';

  @override
  String get videoEditorTransitionNone => 'Brak';

  @override
  String get videoEditorTransitionDissolve => 'Przenikanie';

  @override
  String get videoEditorTransitionFadeToBlack => 'Ściemnienie do czerni';

  @override
  String get videoEditorTransitionFadeToWhite => 'Rozjaśnienie do bieli';

  @override
  String get videoEditorTransitionSlide => 'Wsuwanie';

  @override
  String get videoEditorTransitionPush => 'Wypychanie';

  @override
  String get videoEditorTransitionWipe => 'Wycieranie';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Edytuj przejście';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Przejście pętli';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Edytuj przejście pętli';

  @override
  String get videoEditorTransitionDuration => 'Czas trwania';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Skrócono, aby nie nakładała się na sąsiednie przejście.';

  @override
  String get videoEditorTransitionCurve => 'Krzywa';

  @override
  String get videoEditorTransitionDirection => 'Kierunek';

  @override
  String get videoEditorTransitionDirectionLeft => 'Lewo';

  @override
  String get videoEditorTransitionDirectionRight => 'Prawo';

  @override
  String get videoEditorTransitionDirectionUp => 'Góra';

  @override
  String get videoEditorTransitionDirectionDown => 'Dół';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Krzywa animacji $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animacja';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Edytuj animację warstwy';

  @override
  String get videoEditorLayerAnimationEnter => 'Wejście';

  @override
  String get videoEditorLayerAnimationLeave => 'Wyjście';

  @override
  String get videoEditorLayerAnimationFade => 'Zanikanie';

  @override
  String get videoEditorLayerAnimationScale => 'Skala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Skaluj od';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Zakończ edycję osi czasu';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Odtwórz podgląd';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Wstrzymaj podgląd';

  @override
  String get videoEditorAudioUntitledSound => 'Nienazwany dźwięk';

  @override
  String get videoEditorAudioUntitled => 'Bez tytułu';

  @override
  String get videoEditorAudioAddAudio => 'Dodaj audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Brak dostępnych dźwięków';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Dźwięki pojawią się tutaj, gdy twórcy udostępnią audio';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Nie udało się wczytać dźwięków';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Wybierz fragment audio dla swojego filmu';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Społeczność';

  @override
  String get videoEditorAudioCategoryFeatured => 'Wyróżnione';

  @override
  String get videoEditorAudioCategoryMySounds => 'Moje dźwięki';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Narzędzie strzałki';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Narzędzie gumki';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Narzędzie markera';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Narzędzie ołówka';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Pokaż oś czasu';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ukryj oś czasu';

  @override
  String get videoEditorFeedPreviewContent =>
      'Unikaj umieszczania treści za tymi obszarami.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Oryginały';

  @override
  String get videoEditorStickerSearchHint => 'Szukaj naklejek...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Wybierz czcionkę';

  @override
  String get videoEditorFontUnknown => 'Nieznana';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Aby podzielić, głowica odtwarzania musi znajdować się w wybranym klipie.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Przytnij początek';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Przytnij koniec';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Przytnij klip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Przeciągnij uchwyty, aby dostosować długość klipu';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Przeciąganie klipu $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Klip $index z $total, $duration sekund';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Przytrzymaj, aby zmienić kolejność';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Przesuń w lewo';

  @override
  String get videoEditorTimelineClipMoveRight => 'Przesuń w prawo';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Klip $index z $total, zaznaczony';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Klip $index z $total, niezaznaczony';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Zaznacz';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Zaznacz wiele klipów';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Zakończ zaznaczanie';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zaznaczono $count klipów',
      one: 'Zaznaczono 1 klip',
      zero: 'Nie zaznaczono klipów',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Wybierz wiele rysunków';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Zakończ wybieranie rysunków';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Usuń wybrane rysunki';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wybrano rysunki: $count',
      one: 'Wybrano 1 rysunek',
      zero: 'Nie wybrano rysunków',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Scal';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Scal zaznaczone klipy';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Usuń zaznaczone klipy';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Usuń zaznaczone klatki';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Odwróć zaznaczone klatki';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplikuj zaznaczone klatki';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Twój film musi trwać co najmniej ${seconds}s – dodaj jeszcze kilka klatek.';
  }

  @override
  String get videoEditorMergeProgressLabel => 'Chwila, scalamy Twoje klipy';

  @override
  String get videoEditorMergeFailed =>
      'Nie udało się scalić klipów. Spróbuj ponownie.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Przytrzymaj, aby przeciągnąć';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Oś czasu wideo';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, wybrany';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Zamknij wybór koloru';

  @override
  String get videoEditorPickColorTitle => 'Wybierz kolor';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Potwierdź kolor';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Nasycenie i jasność';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Nasycenie $saturation%, jasność $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Odcień';

  @override
  String get videoEditorAddElementSemanticLabel => 'Dodaj element';

  @override
  String get videoEditorDoneSemanticLabel => 'Gotowe';

  @override
  String get videoEditorLevelSemanticLabel => 'Poziom';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Zamknij szczegóły posta';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Zamknij okno pomocy';

  @override
  String get videoMetadataGotItButton => 'Rozumiem!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Osiągnięto limit 64 KB. Usuń część treści, aby kontynuować.';

  @override
  String get videoMetadataExpirationLabel => 'Wygaśnięcie';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Wybierz czas wygaśnięcia';

  @override
  String get videoMetadataTitleLabel => 'Tytuł';

  @override
  String get videoMetadataDescriptionLabel => 'Opis';

  @override
  String get videoMetadataTagsLabel => 'Tagi';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Usuń tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Ostrzeżenie o treści';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Wybierz ostrzeżenia o treści';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Wybierz wszystko, co dotyczy Twojej treści';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Pozwól innym zapisać i ponownie użyć dźwięku z tego wideo.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Twój film jest opublikowany, ale dźwięk nie. Edytuj film, aby go udostępnić.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Współtwórcy';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Dodaj współtwórcę';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Wzajemni obserwujący';

  @override
  String get videoMetadataInspiredByLabel => 'Zainspirowane przez';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Ustaw zainspirowane przez';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Nie można odwołać się do tego twórcy.';

  @override
  String get videoMetadataPostDetailsTitle => 'Szczegóły posta';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Zapisano w bibliotece';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Nie udało się zapisać';

  @override
  String get videoMetadataGoToLibraryButton => 'Przejdź do biblioteki';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Przycisk zapisz na później';

  @override
  String get videoMetadataSavingVideoHint => 'Zapisywanie wideo...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Zapisz wideo w wersjach roboczych i $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Zapisz film w wersjach roboczych. Nie ma jeszcze wyrenderowanego filmu, więc kopia nie trafi do $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Zapisz na później';

  @override
  String get videoMetadataPostSemanticLabel => 'Przycisk opublikuj';

  @override
  String get videoMetadataPublishVideoHint => 'Opublikuj wideo w feedzie';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Udostępnij też w moim feedzie';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Wyłączenie sprawia, że ten film zostaje tylko w wątku komentarzy.';

  @override
  String get videoMetadataFormNotReadyHint => 'Wypełnij formularz, aby włączyć';

  @override
  String get videoMetadataPostButton => 'Opublikuj';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Otwórz ekran podglądu posta';

  @override
  String get videoMetadataShareTitle => 'Udostępnij';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Szczegóły wideo';

  @override
  String get videoMetadataClassicDoneButton => 'Gotowe';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Odtwórz podgląd';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Wstrzymaj podgląd';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Zamknij podgląd wideo';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Usuń';

  @override
  String get fullscreenFeedRemovedMessage => 'Film usunięty';

  @override
  String get fullscreenFeedEmptyMessage => 'Nie ma tu już nic do odtworzenia';

  @override
  String get settingsBadgesTitle => 'Odznaki';

  @override
  String get settingsBadgesSubtitle =>
      'Akceptuj nagrody i sprawdzaj status wydanych odznak.';

  @override
  String get badgesTitle => 'Odznaki';

  @override
  String get badgesLoadError => 'Nie udało się wczytać odznak';

  @override
  String get badgesUpdateError => 'Nie udało się zaktualizować odznaki';

  @override
  String get badgesAwardedEmptyTitle => 'Jeszcze brak odznak';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Gdy ktoś przyzna ci odznakę Nostr, wyląduje tutaj.';

  @override
  String get badgesStatusAccepted => 'Zaakceptowano';

  @override
  String get badgesStatusNotAccepted => 'Niezaakceptowano';

  @override
  String get badgesActionRemove => 'Usuń';

  @override
  String get badgesActionAccept => 'Akceptuj';

  @override
  String get badgesActionReject => 'Odrzuć';

  @override
  String get badgesIssuedEmptyTitle => 'Jeszcze brak wydanych odznak';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Odznaki, które wydasz, pokażą tutaj status akceptacji.';

  @override
  String get badgesIssuedNoRecipients =>
      'Nie znaleziono odbiorców tej nagrody.';

  @override
  String get badgesRecipientAcceptedStatus => 'Zaakceptowane przez odbiorcę';

  @override
  String get badgesRecipientWaitingStatus => 'Oczekiwanie na odbiorcę';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ukryte ($count)',
      one: 'Ukryta (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Przywróć';

  @override
  String get badgesHiddenSnackbar => 'Odznaka ukryta';

  @override
  String get badgesHiddenSnackbarUndo => 'Cofnij';

  @override
  String get badgesTabAwarded => 'Otrzymane';

  @override
  String get badgesTabCreated => 'Utworzone';

  @override
  String get badgesTabIssued => 'Przyznane';

  @override
  String get badgesCreateAction => 'Nowa odznaka';

  @override
  String get badgesCreatedEmptyTitle => 'Nie masz jeszcze odznak';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Zrób jedną i daj komuś, kto na nią zasłużył.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Przyznana $count osobom',
      one: 'Przyznana 1 osobie',
      zero: 'Jeszcze nieprzyznana',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Nowa odznaka';

  @override
  String get badgeEditorEditTitle => 'Edytuj odznakę';

  @override
  String get badgeEditorNameLabel => 'Nazwa';

  @override
  String get badgeEditorNameHint => 'Kradnie scenę';

  @override
  String get badgeEditorIdentifierLabel => 'Identyfikator';

  @override
  String get badgeEditorIdentifierHelp =>
      'To część adresu odznaki, więc po jej utworzeniu już się nie zmienia.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Masz już odznakę z tym identyfikatorem. Edytuj tamtą — opublikowanie tutaj by ją zastąpiło.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Każda odznaka potrzebuje identyfikatora — wpisz go, jeśli nazwa go nie uzupełniła.';

  @override
  String get badgeEditorDescriptionLabel => 'Opis';

  @override
  String get badgeEditorDescriptionHint =>
      'Dla kogoś, kto kradnie scenę jedną pętlą.';

  @override
  String get badgeEditorArtworkLabel => 'Grafika';

  @override
  String get badgeEditorArtworkAdd => 'Dodaj grafikę';

  @override
  String get badgeEditorArtworkReplace => 'Zamień';

  @override
  String get badgeEditorArtworkError => 'Nie udało się wysłać tego obrazu';

  @override
  String get badgeEditorArtworkRequired => 'Każda odznaka potrzebuje grafiki.';

  @override
  String get badgeEditorArtworkRemove => 'Usuń grafikę';

  @override
  String get badgeEditorArtworkSheetTitle => 'Grafika odznaki';

  @override
  String get badgeDetailDeleteAction => 'Usuń odznakę';

  @override
  String get badgeDetailDeleteTitle => 'Usunąć tę odznakę?';

  @override
  String get badgeDetailDeleteBody =>
      'To prosi przekaźniki o usunięcie odznaki i wszystkich przyznań, których dokonałeś. Przekaźniki mogą odmówić, a kto przypiął ją do profilu, zachowa ją do czasu, aż sam ją usunie.';

  @override
  String get badgeDetailDeleteConfirm => 'Usuń';

  @override
  String get badgeEditorSaveAction => 'Opublikuj odznakę';

  @override
  String get badgeEditorSaveError => 'Nie udało się opublikować odznaki';

  @override
  String get badgeEditorLoadError => 'Nie udało się wczytać tej odznaki';

  @override
  String get badgeDetailTitle => 'Odznaka';

  @override
  String get badgeDetailMadeBy => 'Autor';

  @override
  String get badgeDetailRecipientsTitle => 'Przyznana';

  @override
  String get badgeDetailNoRecipients => 'Nikt jej jeszcze nie ma.';

  @override
  String get badgeDetailAwardAction => 'Przyznaj tę odznakę';

  @override
  String get badgeDetailEditAction => 'Edytuj odznakę';

  @override
  String get badgeDetailShareAction => 'Udostępnij';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Zobacz tę odznakę na Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Odbierz odznakę';

  @override
  String get badgeDetailRevokeTitle => 'Odebrać tę odznakę?';

  @override
  String get badgeDetailRevokeBody =>
      'To prosi przekaźniki o usunięcie przyznania, którego dokonałeś tej osobie. Przekaźniki mogą odmówić, a jeśli odznaka jest już przypięta, zostaje na profilu, dopóki sama jej nie usunie. Tak czy inaczej, nikt jej o tym nie powiadomi.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'To prosi przekaźniki o usunięcie przyznania, którego dokonałeś sobie, i zdejmuje odznakę z twojego profilu. Jeśli przekaźniki odmówią usunięcia, nic się nie zmieni.';

  @override
  String get badgeDetailRevokeConfirm => 'Odbierz';

  @override
  String get badgeDetailRevokeSuccess => 'Odznaka odebrana';

  @override
  String get badgeDetailBlockClaimantsAction => 'Zablokuj osoby z tą odznaką';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Zablokuj osoby z tą odznaką';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Nie udało się wczytać osób z tą odznaką';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Nikt teraz nie ma tej odznaki';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Nie znaleźliśmy teraz nikogo do zablokowania.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zablokować $count konta?',
      many: 'Zablokować $count kont?',
      few: 'Zablokować $count konta?',
      one: 'Zablokować 1 konto?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'To zablokuje $count konta, które mają teraz tę odznakę. Ich posty nie będą pojawiać się w twoich kanałach i nie zostaną powiadomione.',
      many:
          'To zablokuje $count kont, które mają teraz tę odznakę. Ich posty nie będą pojawiać się w twoich kanałach i nie zostaną powiadomione.',
      few:
          'To zablokuje $count konta, które mają teraz tę odznakę. Ich posty nie będą pojawiać się w twoich kanałach i nie zostaną powiadomione.',
      one:
          'To zablokuje konto, które ma teraz tę odznakę. Jego posty nie będą pojawiać się w twoich kanałach i nie zostanie powiadomione.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zablokuj $count konta',
      many: 'Zablokuj $count kont',
      few: 'Zablokuj $count konta',
      one: 'Zablokuj 1 konto',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'Zablokowano osoby z tą odznaką';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Nie udało się zablokować osób z tą odznaką';

  @override
  String get badgeDetailLoadError => 'Nie udało się wczytać tej odznaki';

  @override
  String get badgeDetailMissing =>
      'Nie znaleźliśmy tej odznaki na żadnym przekaźniku.';

  @override
  String get badgeDetailActionError => 'To się nie udało';

  @override
  String get badgeAwardTitle => 'Przyznaj odznakę';

  @override
  String get badgeAwardPickAction => 'Wybierz osoby';

  @override
  String get badgeAwardManualLabel => 'Albo wklej klucze';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Wybierz przynajmniej jedną osobę.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Przyznaj $count osobom',
      one: 'Przyznaj 1 osobie',
      zero: 'Przyznaj odznakę',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Przyznana przez';

  @override
  String get profileBadgeRecipients => 'Odbiorcy';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count więcej';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Odznaka $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Odznaka';

  @override
  String get profileBadgeFooterBody =>
      'Odznaki to małe wyróżnienia, które każdy może stworzyć w Nostr. Podaruj jedną przyjacielowi, twórcy albo komuś, kto umilił ci dzień.';

  @override
  String get profileBadgeFooterLink => 'Zrób własną odznakę';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Przewodnik dla rodzin';

  @override
  String get minorAccountReviewWelcomeTitle =>
      'Nie masz jeszcze 16 lat? W porządku.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'To, że kliknąłeś na tę stronę, zamiast po prostu wybrać odpowiedź, która by cię wpuściła, ma znaczenie. Pokazuje uczciwość, charakter i prawdziwą troskę o ludzi wokół ciebie.\n\nZasady dla osób poniżej 16 lat różnią się w zależności od miejsca zamieszkania. W Divine chcemy, żeby rodziny porozmawiały o tym razem i wspólnie zdecydowały, jak wygląda zdrowe korzystanie z mediów społecznościowych.';

  @override
  String get minorAccountReviewModerationTitle =>
      'Potrzebujemy jeszcze jednego kroku';

  @override
  String get minorAccountReviewModerationBody =>
      'Poproszono nas o dokładniejsze przyjrzenie się temu kontu, bo może należeć do osoby poniżej 16 lat. Ten proces zachowuje kolejne kroki prywatnie i pokazuje ścieżkę właściwą dla twojego wieku.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Zasady nie wszędzie są takie same';

  @override
  String get minorAccountReviewRulesBody =>
      'Różne kraje i regiony inaczej podchodzą do korzystania z mediów społecznościowych przez nastolatków. Dlatego prosimy rodziny, żeby zwolniły, sprawdziły fakty i wspólnie wybrały kolejny krok.';

  @override
  String get minorAccountReviewApproachTitle => 'Jak patrzy na to Divine';

  @override
  String get minorAccountReviewApproachBody =>
      'Uważamy, że zdrowe nawyki technologiczne biorą się z zatrzymania się, refleksji i kierowania uwagi na lepsze rzeczy, a nie ze śledzenia dzieci czy robienia z rodziców strażników. Badania też to potwierdzają.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Więcej dla rodzin';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Przeczytaj politykę Divine dotyczącą dzieci';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Wybierz pasującą ścieżkę';

  @override
  String get minorAccountReviewUnder13Cta => 'Poniżej 13 lat';

  @override
  String get minorAccountReviewTeenCta => '13–15 lat';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Zajrzyj do przewodnika Divine dla rodzin po praktyczne wskazówki, narzędzia do rozmowy i materiały pomagające nastolatkom bezpieczniej korzystać z mediów społecznościowych.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Pobierz przewodniki i wskazówki dla rodzin';

  @override
  String get minorAccountReviewFooter =>
      'Jeśli masz 16 lat lub więcej i trafiłeś(-aś) tu przez pomyłkę, skontaktuj się ze wsparciem Divine, żeby sprawdził to prawdziwy człowiek.';

  @override
  String get minorAccountReviewTitle => 'Weryfikacja konta';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Sprawdzanie stanu konta...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Poczekaj, aż potwierdzimy bieżący stan weryfikacji tego konta.';

  @override
  String get minorAccountReviewDefaultTitle => 'Wymagana weryfikacja konta';

  @override
  String get minorAccountReviewDefaultBody =>
      'Musimy sprawdzić to konto, zanim będzie mogło normalnie korzystać z Divine.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Numer sprawy: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Numer sprawy';

  @override
  String get minorAccountReviewRestrictionsTitle => 'Co jest teraz ograniczone';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Publikowanie jest wstrzymane';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Komentarze, polubienia, udostępnienia i obserwacje są wstrzymane';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Rozpoczynanie i odpowiadanie na zwykłe wiadomości jest wstrzymane';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Wsparcie i twoja wiadomość od moderacji pozostają dostępne';

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
  String get minorAccountReviewOpenSupportCenter => 'Otwórz centrum pomocy';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Otwórz wiadomość od moderacji';

  @override
  String get minorAccountReviewOpenReviewPage => 'Otwórz stronę weryfikacji';

  @override
  String get minorAccountReviewCheckAgain => 'Sprawdź ponownie';

  @override
  String get minorAccountReviewLogOut => 'Wyloguj się';

  @override
  String get minorAccountReviewNextStepTitle => 'Następny krok';

  @override
  String get minorAccountReviewNextStepBody =>
      'Otwórz centrum pomocy lub wiadomość od moderacji, jeśli potrzebujesz pomocy przy tej weryfikacji.';

  @override
  String get minorAccountReviewInProgressTitle => 'Weryfikacja w toku';

  @override
  String get minorAccountReviewInProgressBody =>
      'Na razie mamy to, czego potrzebujemy. Nasz zespół sprawdza tę sprawę, zanim przywróci normalny dostęp do konta.';

  @override
  String get minorAccountReviewUnder13Title => 'Konta osób poniżej 13 lat';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Jeśli to konto należy do osoby poniżej 13 lat, rodzic lub opiekun musi napisać na $supportEmail i podać numer sprawy.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Nie możemy jeszcze dać ci konta';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine nie jest tworzone dla dzieci poniżej 13 lat, a przepisy o mediach społecznościowych na świecie wiążą nam ręce.\n\nWiele rzeczy w internecie popycha cię do kłamstwa, żeby dostać to, czego chcesz, i tego nie znosimy. To zła lekcja na życie i nie będziemy cię jej tu uczyć.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Co zamiast tego może zrobić twoja rodzina';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Rodzic lub opiekun może prowadzić konto i publikować, a ty spokojnie możesz występować z nimi w filmach. Chcemy, żeby rodziny korzystały z Divine tak, jak im pasuje.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Gdy skończysz 13 lat';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'W zależności od przepisów w twoim kraju możesz wtedy wrócić i poprosić o własne konto. Jeśli będziesz mieć od 13 do 15 lat, potrzebna będzie zgoda rodzica lub opiekuna.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Dlaczego nie powiemy ci po prostu „kliknij wstecz”';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Duża część internetu jest tak ustawiona, by nagradzać ludzi za mówienie tego, co pozwoli im przejść przez bramkę. Nie uważamy, że to dobre. Tak, mógłbyś wrócić i powiedzieć, że jesteś starszy, niż jesteś, ale to nie byłoby uczciwe, a my nie zamierzamy uczyć cię kłamania, żeby dostać to, czego chcesz.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Staramy się pomóc młodym ludziom korzystać z Divine w sposób zdrowy i pozytywny dla nich i osób wokół nich. Musimy też przestrzegać praw, które są różne w różnych miejscach. Więc jeśli masz mniej niż 13 lat, odpowiedź jest taka, że dzisiaj nie możesz mieć własnego konta.';

  @override
  String get minorAccountReviewTeenBody =>
      'Jeśli to konto należy do osoby w wieku 13–15 lat, skorzystaj z wiadomości od moderacji lub ze wsparcia, aby wykonać instrukcje dotyczące zgody rodzica.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Jeśli konto ma należeć do osoby w wieku 13–15 lat';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Rodzic lub opiekun powinien napisać do wsparcia Divine i dołączyć krótki prywatny film. Nasz zespół sprawdzi go i pomoże z kolejnymi krokami.\n\nJeśli kontakt z rodzicem lub opiekunem nie jest możliwy albo naraziłby kogoś na niebezpieczeństwo, napisz do wsparcia Divine i daj nam znać.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'To przerwa na czas, gdy zespół wsparcia Divine sprawdza film. Jeśli zostanie zatwierdzony, przeprowadzą cię przez zakładanie nowego konta.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Dlaczego prosimy o zaangażowanie rodzica lub opiekuna';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine musi przestrzegać przepisów dotyczących wieku na całym świecie. Wiemy też, że większość technicznych bramek wiekowych jest niedoskonała. Zamiast udawać, że zasady nie istnieją, albo że fajnie jest kłamać na temat swojego wieku, chcemy, by nastolatki i rodziny podejmowały przemyślane decyzje o tym, jak najlepiej korzystać z Divine. Dlatego w przypadku osób w wieku 13-15 lat prosimy rodziców, by byli częścią procesu zakładania konta.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Musimy też przestrzegać prawa, a te zasady różnią się w zależności od miejsca zamieszkania. Więc zamiast udawać, że zasady nie istnieją, prosimy, by rodzic lub opiekun był częścią tego procesu.';

  @override
  String get minorAccountReviewParentConsentChecklist => 'Co ma pokazywać film';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Nastolatka na filmie';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Rodzica lub opiekuna mówiącego do kamery';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Wyraźne stwierdzenie, że nastolatek ma od 13 do 15 lat i ma zgodę na korzystanie z Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Wyraźne stwierdzenie, że rodzic lub opiekun wie o koncie i będzie nadzorował jego używanie';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Jak to wysłać';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Załącz film do e-maila do wsparcia Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Zachowaj film prywatnie i nie publikuj go w aplikacji';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Nasz zespół sprawdzi go i odpisze z kolejnymi krokami';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Napisz do wsparcia Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Pomoc przy weryfikacji Divine Greenlight (13–15 lat)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Dzień dobry, wsparcie Divine,\n\npiszę w sprawie Divine Greenlight dla nastolatka w wieku 13–15 lat.\n\nZałączam krótki prywatny film, który pokazuje:\n- nastolatka\n- rodzica lub opiekuna mówiącego do kamery\n- że nastolatek ma zgodę na korzystanie z Divine\n- że rodzic lub opiekun wie o koncie i będzie nadzorował jego używanie\n\nKraj/kraje zamieszkania:\n\nPrzydatny kontekst:\n\nDziękuję.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Instrukcje wsparcia dla rodziców';

  @override
  String get minorAccountReviewContinue => 'Dalej';

  @override
  String get minorAccountReviewErrorTitle =>
      'Nie udało nam się wczytać stanu weryfikacji twojego konta.';

  @override
  String get minorAccountReviewErrorBody => 'Spróbuj ponownie za chwilę.';

  @override
  String get minorAccountReviewTryAgain => 'Spróbuj ponownie';

  @override
  String get minorAccountReviewParentContactTitle => 'Kontakt do rodzica';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Dodaj e-mail rodzica lub opiekuna';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Użyjemy tego adresu do weryfikacji zgody rodzica w sprawie $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'E-mail rodzica lub opiekuna';

  @override
  String get minorAccountReviewSubmitting => 'Wysyłanie...';

  @override
  String get minorAccountReviewSubmitEmail => 'Wyślij e-mail';

  @override
  String get minorAccountReviewBackToReview => 'Wróć do weryfikacji konta';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'E-mail wysłany';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Przesłaliśmy $email do weryfikacji. Napiszemy na ten adres z potwierdzeniem. Gdy rodzic lub opiekun odpowie, sprawa ruszy dalej. Po aktualizacje użyj „Sprawdź ponownie” na ekranie weryfikacji konta.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Otrzymaliśmy kontakt do rodzica lub opiekuna dla tego konta. Nasz zespół sprawdzi go przed przywróceniem dostępu.';

  @override
  String get minorAccountReviewMissingCase =>
      'Nie znaleźliśmy aktywnej sprawy weryfikacyjnej dla tego konta.';

  @override
  String get minorAccountReviewParentContactError =>
      'Nie udało się wysłać e-maila rodzica. Spróbuj ponownie.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Wsparcie dla rodziców';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Rodzic lub opiekun musi skontaktować się z Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'W przypadku kont prawdopodobnie należących do osób poniżej 13 lat kolejnym krokiem jest kontakt e-mailowy od rodzica lub opiekuna.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'E-mail wsparcia';

  @override
  String get minorAccountReviewCopySupportEmail => 'Skopiuj e-mail wsparcia';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'Skopiowano e-mail wsparcia';

  @override
  String get minorAccountReviewCopyCaseId => 'Skopiuj numer sprawy';

  @override
  String get minorAccountReviewCaseIdCopied => 'Skopiowano numer sprawy';

  @override
  String get minorAccountReviewUnavailable => 'Niedostępne';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Poproś rodzica lub opiekuna, żeby podał numer sprawy i wyjaśnił, że kontaktuje się z Divine w sprawie tej weryfikacji konta.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Weryfikacja konta osoby poniżej 13 lat, sprawa $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Dzień dobry, wsparcie Divine,\n\njestem rodzicem lub opiekunem dziecka poniżej 13 lat i piszę w sprawie weryfikacji konta $caseId.\n\nDziękuję.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Symulacja weryfikacji konta osoby niepełnoletniej';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Bieżący stan';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Ograniczone ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Aktywne';

  @override
  String get devOptionsMinorReviewStateLoading => 'Wczytywanie...';

  @override
  String get devOptionsMinorReviewStateError => 'Błąd wczytywania stanu';

  @override
  String get devOptionsMinorReviewClearTitle => 'Wyczyść nadpisanie symulacji';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Znów używaj backendu lub domyślnego stanu aktywnego';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      'Symuluj sprawę weryfikacji 13–15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Ograniczone konto ze ścieżką kontaktu z rodzicem';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Symuluj sprawę wsparcia poniżej 13 lat';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Ograniczone konto z instrukcjami tylko przez e-mail rodzica';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Wyczyszczono symulację weryfikacji konta osoby niepełnoletniej';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Włączono symulowaną sprawę wsparcia poniżej 13 lat';

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
      'Symulacja chronionej osoby niepełnoletniej';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Bieżący stan';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Chroniona osoba niepełnoletnia (13–15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Niechronione';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Wczytywanie…';

  @override
  String get devOptionsProtectedMinorStateError => 'Błąd odczytu stanu';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Bez nadpisania (rzeczywisty stan konta)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Nadpisanie: wymuszona ochrona';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Nadpisanie: wymuszony brak ochrony';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Symuluj chronioną osobę niepełnoletnią (13–15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Wymuś stan chronionej osoby niepełnoletniej, aby przetestować zabezpieczenia #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Symuluj osobę pełnoletnią';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Wymuś brak ochrony (wyraźne „nie”, co różni się od braku nadpisania)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Wyczyść nadpisanie';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Wróć do rzeczywistego stanu konta z Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Wymuszono stan chronionej osoby niepełnoletniej';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Wyłączono stan chronionej osoby niepełnoletniej';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Wyczyszczono nadpisanie chronionej osoby niepełnoletniej';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Zaproszenia rejestracyjne';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Bieżący stan';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Wartość serwera: wczytywanie';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Wartość serwera: włączone';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Wartość serwera: wyłączone';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Wartość serwera: nieznana';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Nadpisanie: użyj wartości serwera';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Nadpisanie: wymuś włączenie';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Nadpisanie: wymuś wyłączenie';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Użyj wartości serwera';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Podążaj za onboardingMode usługi zaproszeń';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Wymuś włączenie';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Pokaż lokalnie bramki zaproszeń rejestracyjnych i zarządzanie nimi';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Wymuś wyłączenie';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Ukryj lokalnie interfejs zaproszeń rejestracyjnych bez zmiany serwera';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Zaproszenia rejestracyjne podążają teraz za serwerem';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Wymuszono włączenie zaproszeń rejestracyjnych';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Wymuszono wyłączenie zaproszeń rejestracyjnych';

  @override
  String get commentsRecordVideoButtonLabel => 'Nagraj komentarz wideo';

  @override
  String get commentsOpenVideoLabel => 'Otwórz komentarz wideo';

  @override
  String get commentsMuteVideoReplyLabel => 'Wycisz odpowiedź wideo';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Włącz dźwięk odpowiedzi wideo';

  @override
  String get commentsOpenReplyParentLabel =>
      'Otwórz film, na który to odpowiada';

  @override
  String get commentsReplyParentSectionTitle => 'W odpowiedzi na';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Odpowiedź na $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Odpowiedź na film';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Zweryfikowane konto $platform: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Zweryfikowane konta';

  @override
  String get profileEditGetVerifiedCta => 'Zweryfikuj się';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Połącz swoje konta w mediach społecznościowych, żeby ludzie wiedzieli, że to naprawdę ty.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Odwiedź stronę: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Nie udało się otworzyć strony';

  @override
  String get videoMetadataEditCoverTitle => 'Edytuj okładkę';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Odrzuć zmiany okładki';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Użyj wybranej klatki jako okładki filmu';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Przewijaj wideo, aby wybrać klatkę okładki';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Szukaj lub dodaj tagi';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Dodaj tagi, aby inni odkryli Twój film';

  @override
  String get videoMetadataTagsPickerNoResults => 'Brak pasujących tagów';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Dodaj „#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Nie masz jeszcze 16 lat? To w porządku. ';

  @override
  String get authUnder16ChoicesCta => 'Oto twoje możliwości.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Oto dlaczego';

  @override
  String get generalSettingsHoldToRecord => 'Przytrzymaj, aby nagrywać';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Nagrywanie rozpoczyna się po przytrzymaniu i zatrzymuje się po zwolnieniu';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmów opublikowanych na twoim profilu',
      many: '$count filmów opublikowanych na twoim profilu',
      few: '$count filmy opublikowane na twoim profilu',
      one: 'Film opublikowany na twoim profilu',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Wyślij wiadomość';

  @override
  String get emojiPickerSearchHint => 'Szukaj';

  @override
  String get emojiCategoryRecent => 'Ostatnie';

  @override
  String get emojiCategorySmileys => 'Uśmiechy i ludzie';

  @override
  String get emojiCategoryAnimals => 'Zwierzęta i natura';

  @override
  String get emojiCategoryFood => 'Jedzenie i napoje';

  @override
  String get emojiCategoryActivities => 'Aktywności';

  @override
  String get emojiCategoryTravel => 'Podróże i miejsca';

  @override
  String get emojiCategoryObjects => 'Przedmioty';

  @override
  String get emojiCategorySymbols => 'Symbole';

  @override
  String get emojiCategoryFlags => 'Flagi';

  @override
  String get videoEditorMarkerLabel => 'Znacznik';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Dodaj znacznik osi czasu';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Usuń znacznik osi czasu';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Usuń znacznik przy głowicy odtwarzania';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Usunąć znacznik?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Spowoduje to usunięcie znacznika z osi czasu. Twoja edycja pozostanie bez zmian.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Wycisz lub wyłącz wyciszenie wszystkich ścieżek';

  @override
  String get videoEditorSplitFailed => 'Podział nieudany. Spróbuj ponownie.';

  @override
  String get videoEditEditSubtitles => 'Edytuj napisy';

  @override
  String get subtitleEditorTitle => 'Edytuj napisy';

  @override
  String get subtitleEditorSave => 'Zapisz';

  @override
  String get subtitleEditorProcessing =>
      'Napisy są jeszcze generowane. Zajrzyj za chwilę.';

  @override
  String get subtitleEditorNoSpeech =>
      'Nie wykryto mowy w tym filmie, więc nie ma nic do opisania napisami.';

  @override
  String get subtitleEditorWriteOwn => 'Napisz je sam';

  @override
  String get subtitleEditorAddCue => 'Dodaj linijkę';

  @override
  String get subtitleEditorRemoveCue => 'Usuń tę linijkę';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Filmu nie da się teraz odtworzyć, ale napisy nadal możesz poprawić.';

  @override
  String get subtitleEditorPlayPreview => 'Odtwórz film';

  @override
  String get subtitleEditorPausePreview => 'Wstrzymaj film';

  @override
  String get subtitleEditorInvalidHint =>
      'Każda linijka potrzebuje tekstu i końca po swoim początku.';

  @override
  String get subtitleEditorLoadError =>
      'Nie udało się wczytać napisów. Spróbuj ponownie.';

  @override
  String get subtitleEditorSaveSuccess => 'Napisy zaktualizowane';

  @override
  String get subtitleEditorSaveError =>
      'Nie udało się zapisać napisów. Spróbuj ponownie.';

  @override
  String get subtitleEditorRetry => 'Spróbuj ponownie';

  @override
  String get subtitleEditorCueHint => 'Tekst napisu';

  @override
  String get imageCropEditorRotateLabel => 'Obróć';

  @override
  String get imageCropEditorFlipLabel => 'Odbij';

  @override
  String get imageCropEditorResetLabel => 'Resetuj';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Anuluj kadrowanie';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Zastosuj kadrowanie';

  @override
  String get imageCropEditorProcessing => 'Stosowanie kadrowania…';

  @override
  String get backgroundUploadNotificationTitle => 'Przesyłanie wideo';

  @override
  String get monetizationSettingsTitle => 'Wsparcie twórców';

  @override
  String get monetizationSettingsSubtitle =>
      'Dodaj linki do napiwków i subskrypcji';

  @override
  String get monetizationSettingsIntroTitle => 'Tylko linki zewnętrzne';

  @override
  String get monetizationSettingsIntroBody =>
      'Dodaj miejsca, które sam(a) kontrolujesz. Divine nigdy nie obsługuje płatności ani nie odblokowuje treści w aplikacji przez te linki.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktywnych linków w twoim profilu',
      many: '$count aktywnych linków w twoim profilu',
      few: '$count aktywne linki w twoim profilu',
      one: '1 aktywny link w twoim profilu',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Wyślij napiwek';

  @override
  String get monetizationSettingsSubscriptionSection => 'Subskrybuj / wesprzyj';

  @override
  String get monetizationSettingsSave => 'Zapisz linki wsparcia';

  @override
  String get monetizationSettingsSaving => 'Zapisywanie...';

  @override
  String get monetizationSettingsSaved => 'Zaktualizowano linki wsparcia';

  @override
  String get monetizationSettingsSaveFailed =>
      'Nie udało się zapisać linków wsparcia. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'Dodaj nazwę użytkownika lub URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Ten link nie wygląda poprawnie.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Użyj linku dla tego dostawcy.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag lub link cash.app';

  @override
  String get monetizationSettingsHintPayPal => 'Nazwa lub link PayPal.me';

  @override
  String get monetizationSettingsHintVenmo => 'Nazwa lub link Venmo';

  @override
  String get monetizationSettingsHintPatreon => 'Nazwa lub link Patreon';

  @override
  String get monetizationSettingsHintSubstack => 'Domena lub link Substack';

  @override
  String get monetizationSettingsHintMedium => 'Nazwa lub link Medium';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Identyfikator lub link Open Collective';

  @override
  String get profileSupportSheetTitle => 'Wesprzyj tego twórcę';

  @override
  String get profileSupportSheetBody =>
      'Te linki otwierają się poza Divine. Nic tutaj nie odblokowuje treści w aplikacji.';

  @override
  String get profileSupportTipSection => 'Wyślij napiwek';

  @override
  String get profileSupportSubscriptionSection => 'Subskrybuj / wesprzyj';

  @override
  String get profileSupportButtonLabel => 'Wesprzyj';

  @override
  String get monetizationTipsSettingsTitle => 'Napiwki';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Dodaj opcjonalne linki do napiwków';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Tylko opcjonalne napiwki';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Napiwki to opcjonalne prezenty od użytkownika dla użytkownika. Nie odblokowują w Divine treści, subskrypcji, funkcji, pozycji w rankingu, widoczności ani dostępu.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktywnych linków do napiwków w twoim profilu',
      many: '$count aktywnych linków do napiwków w twoim profilu',
      few: '$count aktywne linki do napiwków w twoim profilu',
      one: '1 aktywny link do napiwków w twoim profilu',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Zapisz linki do napiwków';

  @override
  String get monetizationTipsSettingsSaved =>
      'Zaktualizowano linki do napiwków';

  @override
  String get profileTipButtonLabel => 'Napiwek';

  @override
  String get profileTipSheetTitle => 'Daj napiwek temu twórcy';

  @override
  String get profileTipSheetBody =>
      'Linki do napiwków otwierają się poza Divine. Są opcjonalne i nie odblokowują w Divine treści, subskrypcji, funkcji ani dostępu.';

  @override
  String get settingsStorageTitle => 'Pamięć';

  @override
  String get settingsStorageCacheSectionTitle =>
      'Multimedia w pamięci podręcznej';

  @override
  String get settingsStorageCacheDescription =>
      'Filmy z kanału, miniatury i tymczasowe rendery w pamięci podręcznej. Ich wyczyszczenie jest bezpieczne – zostaną ponownie pobrane lub wygenerowane w razie potrzeby.';

  @override
  String get settingsStorageMeasuring => 'Obliczanie…';

  @override
  String settingsStorageCacheInUse(String size) {
    return 'Zajęte: $size';
  }

  @override
  String get settingsStorageClearButton => 'Wyczyść pamięć podręczną';

  @override
  String get settingsStorageClearConfirmTitle =>
      'Wyczyścić multimedia z pamięci podręcznej?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'To zwolni $size. Twoja biblioteka klipów nie zostanie naruszona.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Wyczyść';

  @override
  String get settingsStorageCleared => 'Pamięć podręczna wyczyszczona';

  @override
  String get settingsStorageLibrarySectionTitle => 'Biblioteka klipów';

  @override
  String get settingsStorageLibraryDescription =>
      'Sprawdź uszkodzone klipy, których plik wideo jest niedostępny.';

  @override
  String get settingsStorageScanButton => 'Sprawdź bibliotekę';

  @override
  String get settingsStorageLibraryHealthy =>
      'Nie znaleziono uszkodzonych klipów';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Znalezione uszkodzone klipy: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Usuń uszkodzone klipy';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Uszkodzone klipy usunięte';

  @override
  String get settingsStorageError => 'Coś poszło nie tak';

  @override
  String get settingsStorageMaxVideoCacheLabel =>
      'Maksymalna pamięć podręczna wideo';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count filmów';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Usunąć uszkodzone klipy?';

  @override
  String get settingsStorageRepairSectionTitle => 'Napraw instalację';

  @override
  String get settingsStorageRepairDescription =>
      'Jeśli aplikacja się wysypuje albo dziwnie działa, zresetowanie danych lokalnych zwykle pomaga. Twoje klipy i wersje robocze zostają.';

  @override
  String get settingsStorageRepairButton => 'Zresetuj dane aplikacji';

  @override
  String get settingsStorageRepairConfirmTitle => 'Zresetować dane aplikacji?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'To usunie zapisane dane kanału i pliki tymczasowe. Twoje klipy, wersje robocze, ustawienia i zalogowanie zostaną, ale trzeba będzie potem zrestartować aplikację.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return 'Zostanie usunięte: $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Zresetuj';

  @override
  String get settingsStorageRepairInProgress => 'Resetowanie…';

  @override
  String get settingsStorageRepairSuccess =>
      'Gotowe — zrestartuj aplikację, żeby zakończyć.';

  @override
  String get settingsStorageRepairFailure =>
      'Nie udało się zresetować wszystkiego. Spróbuj ponownie po restarcie.';

  @override
  String get nostrSettingsSignatureVerification => 'Weryfikacja podpisu';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Wybierz, kiedy Divine sprawdza podpisy zdarzeń z relayów. ID zdarzeń są zawsze walidowane jako pierwsze.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Wszystkie relaye';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Najbezpieczniej. Weryfikuj podpis każdego zdarzenia z relaya.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => 'Niezaufane relaye';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Pomiń sprawdzanie relayów, które są już w skonfigurowanej puli.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Relaye spoza Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Ufaj relayom Divine, weryfikuj resztę.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle =>
      'Udostępniaj swoje filmy na innych platformach';

  @override
  String get crosspostingSignInRequired =>
      'Zaloguj się przez Divine, żeby zarządzać crosspostingiem';

  @override
  String get crosspostingLoadFailed =>
      'Nie udało się wczytać twoich ustawień crosspostingu';

  @override
  String get crosspostingNoPlatforms =>
      'W tej chwili nie ma dostępnych platform crosspostingu';

  @override
  String get crosspostingRetry => 'Ponów';

  @override
  String get crosspostingNotConnected => 'Niepołączony';

  @override
  String get crosspostingConnected => 'Połączono';

  @override
  String get crosspostingNeedsReconnect => 'Wymaga ponownego połączenia';

  @override
  String get crosspostingConnect => 'Połącz';

  @override
  String get crosspostingReconnect => 'Połącz ponownie';

  @override
  String get crosspostingDisconnect => 'Odłącz';

  @override
  String get crosspostingModeOff => 'Wyłączony';

  @override
  String get crosspostingModeManual => 'Ręczny';

  @override
  String get crosspostingModeManualSubtitle => 'Wybierasz przy każdym filmie';

  @override
  String get crosspostingModeAutomatic => 'Automatyczny';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Kolejne filmy publikują się same — tylko te opublikowane po włączeniu tej opcji';

  @override
  String get crosspostingNotConnectedError =>
      'Najpierw połącz tę platformę, żeby zmienić sposób publikowania.';

  @override
  String get crosspostingGenericError =>
      'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Strona logowania nigdy nie odpowiedziała. Jeśli udało ci się tam skończyć, odśwież — twoje konto może już być połączone.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return 'Połączono $platform';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Nie udało się połączyć $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Połączenie zostało anulowane na $platform';
  }

  @override
  String get supporterTitle => 'Wspierający Divine';

  @override
  String get supporterTileSubtitle =>
      'Wesprzyj Divine opcjonalną miesięczną subskrypcją.';

  @override
  String get supporterHeroTitle => 'Niech Divine działa dalej';

  @override
  String get supporterHeroBody =>
      'Divine jest darmowe i zawsze będzie. Jeśli chcesz pomóc nam utrzymać pętle w ruchu, zostań miesięcznym wspierającym. Nic nie jest zablokowane — to po prostu pozwala nam utrzymać światło włączone i zapewnia naszą wdzięczność.';

  @override
  String get supporterActiveBadge =>
      'Jesteś w gronie Wspierających Divine. Dziękujemy, że utrzymujesz to w ruchu.';

  @override
  String get supporterPurchasePending => 'Zakup oczekuje na zatwierdzenie.';

  @override
  String get supporterPurchaseConfirming => 'Potwierdzanie wsparcia…';

  @override
  String get supporterStoreChecking => 'Sprawdzanie sklepu…';

  @override
  String get supporterUnavailable =>
      'Subskrypcje wspierające nie są tu teraz dostępne.';

  @override
  String get supporterRestorePurchases => 'Przywróć zakupy';

  @override
  String get supporterDismissError => 'Zamknij błąd';

  @override
  String get supporterErrorStoreUnavailable =>
      'Sklep jest niedostępny na tym urządzeniu.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Zakup nie został zrealizowany. Nie pobrano opłaty.';

  @override
  String get supporterErrorPurchasePending =>
      'Zakup oczekuje na zatwierdzenie.';

  @override
  String get supporterErrorRestoreFailed =>
      'Nie znaleziono subskrypcji wspierającej do przywrócenia.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Ten zakup należy do innego konta Divine.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine nie może teraz potwierdzić statusu wspierającego.';

  @override
  String get supporterErrorUnknown => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get supporterDisclaimer =>
      'Divine potwierdza status wspierającego po zweryfikowaniu zakupu przez sklep. Wyróżnienie jest opcjonalne, a halo nie jest weryfikacją.';

  @override
  String get profileNotifyBellOff => 'Powiadamiaj o nowych vine\'ach';

  @override
  String get profileNotifyBellOn => 'Nie powiadamiaj o nowych vine\'ach';

  @override
  String get profileNotifyUpdateFailed =>
      'Nie udało się zapisać. Spróbować ponownie?';

  @override
  String get savedSoundYourLabel => 'Twoja etykieta';

  @override
  String get savedSoundAddHashtags => 'Dodaj hashtagi';

  @override
  String get savedSoundDeviceOnly => 'Zapisane na tym urządzeniu';

  @override
  String get savedSoundDetailsRetry =>
      'Nie udało się zapisać tych danych. Dotknij, aby ponowić.';

  @override
  String get savedSoundFallbackTitle => 'Zapisany dźwięk';

  @override
  String get savedSoundPreviewAction => 'Posłuchaj dźwięku';

  @override
  String get savedSoundEditAction => 'Edytuj dane dźwięku';

  @override
  String get savedSoundRemoveAction => 'Usuń zapisany dźwięk';

  @override
  String get savedSoundClearHashtagFilter => 'Wyczyść filtr hashtagów';

  @override
  String get soundAllowRemix => 'Pozwól innym remiksować ten dźwięk';

  @override
  String get soundReuseUnavailable =>
      'Tego dźwięku nie można teraz remiksować.';

  @override
  String get soundPublicCredit => 'Publiczne oznaczenie autora dźwięku';

  @override
  String get soundCreditRequired =>
      'Dodaj publiczne oznaczenie autora dźwięku przed opublikowaniem.';

  @override
  String get soundSharedAs => 'Udostępnione jako';

  @override
  String get soundOwnWork => 'To ja stworzyłem(-am) ten dźwięk';

  @override
  String soundCreatorBy(String creator) {
    return 'Autor: $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Udostępnione przez $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remiksowanie dozwolone';

  @override
  String get soundCreditOnly => 'Tylko oznaczenie autora';

  @override
  String get soundCreditTitleLabel => 'Tytuł dźwięku';

  @override
  String get soundCreditCreatorLabel => 'Twórca';

  @override
  String get soundCreditSourceUrlLabel => 'URL źródła';

  @override
  String get soundCreditPublicHashtagsLabel => 'Publiczne hashtagi';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel => 'Anuluj wybór tagów';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Zastosuj wybrane tagi';

  @override
  String get userPickerCancelSemanticLabel => 'Anuluj wybór użytkowników';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Potwierdź wybranych użytkowników';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Wyczyść wybór użytkowników';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Anuluj wybór ostrzeżeń o treści';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Zastosuj wybrane ostrzeżenia o treści';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Zamknij edytor wideo';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Przejdź do szczegółów posta';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Odrzuć zmiany w $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Zastosuj zmiany w $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Usuń dźwięk';

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
  String get verifyTitle => 'Zweryfikowane konta';

  @override
  String get verifySignedOutMessage =>
      'Zaloguj się, żeby połączyć swoje konta.';

  @override
  String get verifyIntro =>
      'Połącz konta, które już masz, żeby było widać, że to naprawdę ty.';

  @override
  String get verifyLoadFailed => 'Nie udało się wczytać twoich połączeń.';

  @override
  String get verifyRetry => 'Spróbuj ponownie';

  @override
  String get verifyLinkedSectionTitle => 'Połączone';

  @override
  String get verifyVerifierUnreachable =>
      'Weryfikator był nieosiągalny, więc wszystko pokazuje się jako niesprawdzone.';

  @override
  String get verifyAddSectionTitle => 'Dodaj konto';

  @override
  String get verifyAllPlatformsLinked =>
      'Połączyłeś już wszystko, co obsługujemy.';

  @override
  String get verifyStatusVerified => 'Zweryfikowane';

  @override
  String get verifyStatusUnverified => 'Niezweryfikowane';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Odłącz konto $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Odłączyć $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity przestanie być widoczne w twoim profilu. Możesz połączyć je ponownie później, ale trzeba będzie zalogować się jeszcze raz albo opublikować nowy dowód.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Odłącz';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Połącz swoje konto $platform';
  }

  @override
  String get verifyOneTapBadge => 'Jedno tapnięcie';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Zaloguj się na $platform, resztą zajmiemy się my. Nic nie zostanie opublikowane.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Kontynuuj z $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Albo opublikuj dowód';

  @override
  String get verifyConnectProofExplainer =>
      'Opublikuj swój npub na koncie, a potem wklej link do tego wpisu.';

  @override
  String get verifyNpubLabel => 'Twój npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Skopiuj swój npub';

  @override
  String get verifyNpubCopied => 'npub skopiowany';

  @override
  String get verifyIdentityLabel => 'Nazwa konta';

  @override
  String get verifyProofLabel => 'Link do twojego wpisu';

  @override
  String get verifyConnectProofCta => 'Sprawdź i połącz';

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
      'Weryfikator nieosiągalny. Spróbuj za chwilę.';

  @override
  String get verifyErrorOauthFailed => 'Nie poszło. Spróbuj jeszcze raz.';

  @override
  String get verifyErrorHandleRequired => 'Najpierw podaj swój handle.';

  @override
  String get verifyErrorPublishFailed =>
      'Zweryfikowane, ale żaden przekaźnik nie przyjął aktualizacji. Spróbuj ponownie.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Logowanie jednym tapnięciem nie jest tu jeszcze skonfigurowane. Skorzystaj z dowodu poniżej.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Utwórz publiczny gist z npub w pierwszym pliku i wklej link do gista.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Opublikuj swój npub na kanale Discorda, który nasz bot może czytać, i wklej link do wiadomości. Zaproszenie na serwer niczego nie dowodzi.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Wrzuć tweeta ze swoim npub z tego konta i wklej link do tweeta.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Opublikuj swój npub z tego konta i wklej link. Nazwa konta musi zawierać instancję — mastodon.social/@alice, nie samo alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Łączony jest kanał, nie twoje konto Telegram. Najpierw potrzebuje publicznego linku (Telegram tworzy nowe jako prywatne). Opublikuj tam npub i wklej link do wiadomości.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Zalogowano powyżej? Nic więcej nie trzeba. W przeciwnym razie opublikuj npub i wklej link do wpisu.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Wpisz swój npub w opisie filmu i wklej link do tego filmu.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Wpisz swój npub w opisie filmu i wklej link do tego filmu.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform połączone.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'To prywatny kanał albo zaproszenie. Nadaj kanałowi publiczny link, a potem wklej link do wiadomości.';

  @override
  String get verifyErrorRemoveFailed =>
      'Nie udało się odłączyć. Spróbuj ponownie.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Nie udało się odczytać twoich obecnych połączeń, więc nic nie zmieniono. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get verifyChannelLabel => 'Nazwa kanału';

  @override
  String get verifyHowItWorksTitle => 'Jak to działa?';

  @override
  String get verifyHowItWorksIntro =>
      'Pomyśl o tym jak o uścisku dłoni między dwoma kontami:';

  @override
  String get verifyHowItWorksYourSide =>
      'Twój profil Divine mówi: „Jestem @alice na Twitterze”.';

  @override
  String get verifyHowItWorksOtherSide =>
      'Twoje konto na Twitterze potwierdza: „Tak, ten profil Divine jest mój”.';

  @override
  String get verifyHowItWorksBothSides =>
      'Sprawdzamy obie strony. Jeśli się zgadzają, jesteś zweryfikowany. Nie da się tego podrobić — imię i zdjęcie można skopiować, opublikować z twojego prawdziwego konta nie.';

  @override
  String get verifyHowItWorksOwnership =>
      'Połączenia znajdują się w twojej własnej tożsamości Nostr, więc możesz je stąd usunąć, kiedy zechcesz.';

  @override
  String get generalSettingsSectionIdentity => 'Tożsamość';

  @override
  String get libraryFilterAll => 'Wszystkie';

  @override
  String get libraryFilterArchive => 'Archiwum';

  @override
  String get libraryFilterDeleted => 'Usunięte';

  @override
  String get libraryCategoryNewChipLabel => 'Nowa';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Utwórz kategorię';

  @override
  String get libraryCategoryCreateTitle => 'Nowa kategoria';

  @override
  String get libraryCategoryCreateAction => 'Utwórz';

  @override
  String get libraryCategoryRenameTitle => 'Zmień nazwę kategorii';

  @override
  String get libraryCategoryRenameAction => 'Zmień nazwę';

  @override
  String get libraryCategoryDeleteAction => 'Usuń kategorię';

  @override
  String get libraryCategoryNameLabel => 'Nazwa kategorii';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Twoje klipy zostają. Wracają tylko do Wszystkich.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Zmień nazwę lub usuń tę kategorię';

  @override
  String get libraryCategoryMoveTitle => 'Przenieś do';

  @override
  String get libraryCategoryMoveNone => 'Bez kategorii';

  @override
  String get libraryCategoryMoveNewCategory => 'Nowa kategoria';

  @override
  String get libraryArchiveAction => 'Archiwizuj';

  @override
  String get libraryUnarchiveAction => 'Przywróć z archiwum';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zostawić w tych kategoriach?',
      one: 'Zostawić w tej kategorii?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Zostaw w $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'Zostaw w kategoriach';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Usuń z $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed => 'Usuń z kategorii';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Przenieś wybrane klipy';

  @override
  String get libraryCategoryEmptyTitle => 'Jeszcze nic tu nie ma';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Wybierz kilka klipów i przenieś je do tej kategorii.';

  @override
  String get libraryArchiveEmptyTitle => 'Nic w archiwum';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Zarchiwizowane klipy czekają tutaj, poza główną biblioteką.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Przeniesiono $count klipów do $name',
      many: 'Przeniesiono $count klipów do $name',
      few: 'Przeniesiono $count klipy do $name',
      one: 'Przeniesiono 1 klip do $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunięto $count klipów z kategorii',
      many: 'Usunięto $count klipów z kategorii',
      few: 'Usunięto $count klipy z kategorii',
      one: 'Usunięto 1 klip z kategorii',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zarchiwizowano $count klipów',
      many: 'Zarchiwizowano $count klipów',
      few: 'Zarchiwizowano $count klipy',
      one: 'Zarchiwizowano 1 klip',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipów wróciło do biblioteki',
      many: '$count klipów wróciło do biblioteki',
      few: '$count klipy wróciły do biblioteki',
      one: '1 klip wrócił do biblioteki',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Zmień e-mail';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Przenieś konto na inny adres';

  @override
  String get accountSettingsChangePassword => 'Zmień hasło';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Wybierz nowe hasło do logowania';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Sesja wygasła. Zaloguj się ponownie, żeby to zmienić.';

  @override
  String get accountCredentialsRateLimited =>
      'Za dużo prób. Odczekaj kilka minut.';

  @override
  String get accountCredentialsNetwork =>
      'Nie udało się połączyć z Divine. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get accountCredentialsUnknown => 'Nie udało się. Spróbuj ponownie.';

  @override
  String get changePasswordSubtitle =>
      'Wpisz obecne hasło, a potem wybierz nowe.';

  @override
  String get changePasswordCurrentLabel => 'Obecne hasło';

  @override
  String get changePasswordWrongCurrent => 'To nie jest twoje obecne hasło.';

  @override
  String get changePasswordSuccess => 'Hasło zmienione.';

  @override
  String get changeEmailSubtitle =>
      'Wyślemy link potwierdzający na nowy adres i na ten z twojego konta. E-mail zmieni się, gdy potwierdzisz z obu.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Na twoim koncie: $email';
  }

  @override
  String get changeEmailNewLabel => 'Nowy e-mail';

  @override
  String get changeEmailPasswordLabel => 'Twoje hasło';

  @override
  String get changeEmailSameAsCurrent => 'To już jest twój adres e-mail.';

  @override
  String get changeEmailWrongPassword => 'To nie jest twoje hasło.';

  @override
  String get changeEmailSubmit => 'Wyślij linki potwierdzające';

  @override
  String get changeEmailSentTitle => 'Dwa linki są w drodze';

  @override
  String changeEmailSentMessage(String email) {
    return 'Potwierdź z $email i z adresu na twoim koncie. E-mail zmieni się, gdy zrobisz oba.';
  }

  @override
  String get changeEmailSentExpiry =>
      'Linki przestają działać po 24 godzinach.';

  @override
  String get changeEmailSentDone => 'Jasne';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount filmu',
      many: '$formattedCount filmów',
      few: '$formattedCount filmy',
      one: '$formattedCount film',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Obserwujecie się';

  @override
  String get socialProofFollowsYou => 'Obserwuje Cię';

  @override
  String get socialProofYouFollow => 'Obserwujesz';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount obserwujących',
      many: '$formattedCount obserwujących',
      few: '$formattedCount obserwujących',
      one: '$formattedCount obserwujący',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Filmy się teraz nie ładują.\nTo po naszej stronie — już to naprawiamy.';

  @override
  String get feedOfflineMessage =>
      'Jesteś offline.\nSprawdź połączenie i spróbuj ponownie.';

  @override
  String get dbFailureTitle => 'nie można odblokować lokalnej bazy danych';

  @override
  String get dbFailureAdviceResettable =>
      'Ponowne uruchomienie tego nie naprawi. Zresetowanie lokalnej bazy danych poniżej da Divine czysty start — Twoje konto zostaje.';

  @override
  String get dbFailureAdviceRestart =>
      'Uruchom Divine ponownie po odblokowaniu urządzenia. Jeśli to się powtarza, zaktualizuj aplikację lub skontaktuj się z pomocą techniczną.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Spróbuj raz ponownie uruchomić Divine. Jeśli problem będzie się powtarzał, zaktualizuj aplikację lub skontaktuj się z pomocą. Twoje lokalne dane nadal są zachowane.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostyka: $code';
  }

  @override
  String get dbFailureCloseApp => 'zamknij Divine';

  @override
  String get dbFailureResetAction => 'zresetuj lokalną bazę danych';

  @override
  String get dbFailureConfirmTitle => 'zresetować lokalną bazę danych?';

  @override
  String get dbFailureConfirmBody =>
      'Twoje konto zostaje. Wersje robocze i klipy zapisane na tym urządzeniu zostaną usunięte — wiadomości i kanały wrócą z sieci.';

  @override
  String get dbFailureResetConfirm => 'zresetuj teraz lokalną bazę danych';

  @override
  String get dbFailureCancel => 'anuluj';

  @override
  String get dbFailureResetFailed =>
      'To nie zadziałało. Zamknij Divine i spróbuj ponownie.';

  @override
  String get dbFailureResetDoneTitle => 'lokalna baza danych zresetowana';

  @override
  String get dbFailureResetDoneBody =>
      'Zamknij Divine i otwórz go ponownie — następne uruchomienie utworzy nową lokalną bazę danych.';

  @override
  String get authSignInOptionsInfo => 'Informacje o opcjach logowania';

  @override
  String get authShowPassword => 'Pokaż hasło';

  @override
  String get authHidePassword => 'Ukryj hasło';

  @override
  String get followUserSemanticLabel => 'Obserwuj użytkownika';

  @override
  String get unfollowUserSemanticLabel => 'Przestań obserwować użytkownika';

  @override
  String get commentsLoadingSemanticLabel => 'Wczytywanie komentarzy';

  @override
  String get analyticsWindowAll => 'Wszystko';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Obserwuj użytkownika $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Przestań obserwować użytkownika $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / miesiąc';
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
      'Właśnie pojawiła się nowa aktualizacja. Sprawdź ją →';

  @override
  String get updateModerateTitle =>
      'Od ostatniego sprawdzenia pojawiła się aktualizacja';

  @override
  String get updateUrgentTitle => 'Brakuje Ci ważnych poprawek';

  @override
  String get updateNotNow => 'Nie teraz';

  @override
  String get updateAction => 'Aktualizuj';

  @override
  String updateNewIn(String version) {
    return 'Nowości w wersji $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Dostępna aktualizacja';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Clip-Wiederherstellung';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Findet Aufnahmen unter einem anderen Konto und Videodateien, auf die kein Eintrag mehr verweist.';

  @override
  String get devOptionsClipRecoveryScan => 'Scannen';

  @override
  String get devOptionsClipRecoveryFailure =>
      'Clip-Wiederherstellung fehlgeschlagen';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips Clips',
      one: '$clips Clip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts Entwürfe',
      one: '$drafts Entwurf',
    );
    return 'Jetzt sichtbar: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts =>
      'Unter anderen Konten verborgen';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips Clips',
      one: '$clips Clip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts Entwürfe',
      one: '$drafts Entwurf',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Zu diesem Konto verschieben';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Nicht referenzierte Dateien: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'In Bibliothek wiederherstellen';

  @override
  String get devOptionsClipRecoveryEmpty => 'Nichts wiederherzustellen';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips wiederhergestellt',
      one: '$count Clip wiederhergestellt',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied =>
      'Wiederherstellungsbericht kopiert';

  @override
  String get devOptionsStorageFootprint => 'Speicherverbrauch';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Jedes Verzeichnis, in das die App schreibt. Cache leeren gibt nur einen Teil davon frei.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Messen';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Gesamt: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Speicherbericht kopiert';

  @override
  String get devOptionsStorageFootprintFailure =>
      'Speicher konnte nicht gemessen werden';

  @override
  String get feedTuningMoreLabel => 'Mehr davon';

  @override
  String get feedTuningLessLabel => 'Weniger davon';

  @override
  String get feedTuningUndo => 'Rückgängig';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Referenziertes Video öffnen';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSecureAccount => 'Konto absichern';

  @override
  String get settingsSessionExpired => 'Sitzung abgelaufen';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Melde dich erneut an, um wieder vollen Zugriff zu haben';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Creator-Analytics';

  @override
  String get settingsSupportCenter => 'Support-Center';

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsBlueskyPublishing => 'Bluesky-Veröffentlichung';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Crossposting zu Bluesky verwalten';

  @override
  String get settingsNostrSettings => 'Nostr-Einstellungen';

  @override
  String get settingsIntegratedApps => 'Integrierte Apps';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Genehmigte Drittanbieter-Apps, die in Divine laufen';

  @override
  String get settingsExperimentalFeatures => 'Experimentelle Funktionen';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Spielereien, die noch holpern können—probier sie aus, wenn du neugierig bist.';

  @override
  String get settingsLegal => 'Rechtliches';

  @override
  String get settingsIntegrationPermissions => 'Integrations-Berechtigungen';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Gemerkte Integrations-Freigaben prüfen und widerrufen';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Entwicklermodus ist bereits aktiv';

  @override
  String get settingsDeveloperModeEnabled => 'Entwicklermodus aktiviert!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Noch $count Tippen, um den Entwicklermodus zu aktivieren';
  }

  @override
  String get settingsShareDivine => 'Teile Divine mit deinen Freunden';

  @override
  String get settingsSwitchAccount => 'Konto wechseln';

  @override
  String get settingsAddAnotherAccount => 'Weiteres Konto hinzufügen';

  @override
  String get settingsAccountSwitchFailed =>
      'Konten konnten nicht gewechselt werden. Bitte versuch es erneut.';

  @override
  String get settingsUnsavedDraftsTitle => 'Ungespeicherte Entwürfe';

  @override
  String get settingsUploadInProgressTitle => 'Upload läuft';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Videos',
      one: 'Video',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'deine Videos bleiben als Entwürfe',
      one: 'dein Video bleibt als Entwurf',
    );
    return 'Du lädst gerade noch $count $_temp0 hoch. Beim Kontowechsel wird der Upload gestoppt — $_temp1 in diesem Konto.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entwürfe',
      one: 'Entwurf',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entwürfe',
      one: 'Entwurf',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sie',
      one: 'ihn',
    );
    return 'Du hast $count ungespeicherte $_temp0. Beim Kontowechsel bleiben deine $_temp1 erhalten, aber du solltest $_temp2 vorher vielleicht veröffentlichen oder durchgehen.';
  }

  @override
  String get settingsCancel => 'Abbrechen';

  @override
  String get settingsSwitchAnyway => 'Trotzdem wechseln';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Die Sitzung dieses Kontos ist abgelaufen. Dich dort neu anzumelden heißt, dich aus dem Konto abzumelden, in dem du gerade bist.';

  @override
  String get settingsAppVersionLabel => 'App-Version';

  @override
  String get settingsAppLanguage => 'App-Sprache';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (Gerätestandard)';
  }

  @override
  String get settingsAppLanguageTitle => 'App-Sprache';

  @override
  String get settingsAppLanguageDescription =>
      'Wähle die Sprache für die App-Oberfläche';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Gerätesprache verwenden';

  @override
  String get settingsGeneralTitle => 'Allgemeine Einstellungen';

  @override
  String get settingsContentSafetyTitle => 'Inhalte & Sicherheit';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRATIONEN';

  @override
  String get generalSettingsSectionViewing => 'ANSEHEN';

  @override
  String get generalSettingsSectionCreating => 'ERSTELLEN';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get appearanceSettingsTitle => 'Erscheinungsbild';

  @override
  String get appearanceSettingsSubtitle =>
      'Wähle, wie Divine auf diesem Gerät aussieht';

  @override
  String get appearanceSettingsSystem => 'Systemstandard';

  @override
  String get appearanceSettingsLight => 'Hell';

  @override
  String get appearanceSettingsDark => 'Dunkel';

  @override
  String get generalSettingsClosedCaptions => 'Untertitel';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Untertitel anzeigen, wenn Videos welche haben';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Nur quadratische Videos';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Halt deinen Feed im klassischen Quadratformat';

  @override
  String get contentPreferencesTitle => 'Inhaltseinstellungen';

  @override
  String get contentPreferencesContentFilters => 'Inhaltsfilter';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Inhaltswarnungs-Filter verwalten';

  @override
  String get contentPreferencesContentLanguage => 'Inhaltssprache';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (Gerätestandard)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tagge deine Videos mit einer Sprache, damit Zuschauer filtern können.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Gerätesprache verwenden (Standard)';

  @override
  String get contentPreferencesAudioSharing =>
      'Mein Audio zur Wiederverwendung freigeben';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Wenn aktiviert, können andere Audio aus deinen Videos verwenden';

  @override
  String get contentPreferencesMusicMode => 'Musikmodus';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Schaltet die Rauschunterdrückung ab, die Instrumente plattmacht. Besser für Musik, rauer für Stimmen.';

  @override
  String get contentPreferencesAccountLabels => 'Konto-Labels';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Kennzeichne deine Inhalte selbst';

  @override
  String get contentPreferencesAccountContentLabels => 'Konto-Inhalts-Labels';

  @override
  String get contentPreferencesClearAll => 'Alles löschen';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Wähle alles aus, was auf dein Konto zutrifft';

  @override
  String get contentPreferencesDoneNoLabels => 'Fertig (keine Labels)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Fertig ($count ausgewählt)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Audio-Eingabegerät';

  @override
  String get contentPreferencesAutoRecommended => 'Automatisch (empfohlen)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Wählt automatisch das beste Mikrofon';

  @override
  String get contentPreferencesSelectAudioInput => 'Audio-Eingabe wählen';

  @override
  String get contentPreferencesUnknownMicrophone => 'Unbekanntes Mikrofon';

  @override
  String get contentFiltersAdultContent => 'INHALTE FÜR ERWACHSENE';

  @override
  String get contentFiltersViolenceGore => 'GEWALT & BLUT';

  @override
  String get contentFiltersSubstances => 'SUBSTANZEN';

  @override
  String get contentFiltersOther => 'SONSTIGES';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifizier dein Alter unter Sicherheit & Datenschutz, um Filter für Erwachseneninhalte freizuschalten';

  @override
  String get contentFiltersShow => 'Anzeigen';

  @override
  String get contentFiltersWarn => 'Warnen';

  @override
  String get contentFiltersFilterOut => 'Ausblenden';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Dieses Konto ist nicht verfügbar';

  @override
  String get profileInvalidId => 'Ungültige Profil-ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Schau dir $displayName auf Divine an!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName auf Divine';
  }

  @override
  String get profileShareFailed =>
      'Profil konnte nicht geteilt werden. Bitte versuch es nochmal.';

  @override
  String get profileCopyPublicKey => 'Public Key (npub) kopieren';

  @override
  String get profileGetEmbedCode => 'Embed-Code holen';

  @override
  String get profilePublicKeyCopied =>
      'Public Key in die Zwischenablage kopiert';

  @override
  String get profileEmbedCodeCopied =>
      'Embed-Code in die Zwischenablage kopiert';

  @override
  String get profileMoreTooltip => 'Mehr';

  @override
  String get profileMoreSemanticLabel => 'Weitere Optionen';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Avatar schließen';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Avatar-Vorschau schließen';

  @override
  String get profileFollowingLabel => 'Gefolgt';

  @override
  String get profileFollowLabel => 'Folgen';

  @override
  String get profileBlockedLabel => 'Blockiert';

  @override
  String get profileFollowersLabel => 'Follower';

  @override
  String get profileFollowingStatLabel => 'Folgt';

  @override
  String get profileVideosLabel => 'Videos';

  @override
  String get profileCollabsLabel => 'Collabs';

  @override
  String get profileLikedLabel => 'Gefällt mir';

  @override
  String get profileRepostsLabel => 'Reposts';

  @override
  String get profileListsLabel => 'Listen';

  @override
  String get profileCommentsLabel => 'Kommentare';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitwirkenden-Einladungen müssen noch gesendet werden',
      one: '1 Mitwirkenden-Einladung muss noch gesendet werden',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Wir haben die Einladung in der Warteschlange gelassen. Hier erneut versuchen.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Für „$title“. Hier erneut versuchen.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Erneut versuchen';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Wird wiederholt';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Das erneute Senden der Mitwirkenden-Einladung ist gerade nicht möglich.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitwirkenden-Einladungen müssen noch gesendet werden.',
      one: '1 Mitwirkenden-Einladung muss noch gesendet werden.',
      zero: 'Mitwirkenden-Einladungen gesendet.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitwirkende können keine Einladungen empfangen.',
      one: '1 Mitwirkender kann keine Einladungen empfangen.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count Nutzer';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName blockieren?';
  }

  @override
  String get profileBlockExplanation => 'Wenn du einen Nutzer blockierst:';

  @override
  String get profileBlockBulletHidePosts =>
      'Seine Beiträge tauchen nicht mehr in deinen Feeds auf.';

  @override
  String get profileBlockBulletCantView =>
      'Er kann dein Profil nicht mehr ansehen, dir folgen oder deine Beiträge sehen.';

  @override
  String get profileBlockBulletNoNotify =>
      'Er wird nicht über die Änderung informiert.';

  @override
  String get profileBlockBulletYouCanView =>
      'Du kannst sein Profil weiterhin ansehen.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName blockieren';
  }

  @override
  String get profileCancelButton => 'Abbrechen';

  @override
  String get profileLearnMore => 'Mehr erfahren';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName entsperren?';
  }

  @override
  String get profileUnblockExplanation => 'Wenn du diesen Nutzer entsperrst:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Seine Beiträge erscheinen wieder in deinen Feeds.';

  @override
  String get profileUnblockBulletCanView =>
      'Er kann dein Profil sehen, dir folgen und deine Beiträge ansehen.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Er wird nicht über die Änderung informiert.';

  @override
  String get profileLearnMoreAt => 'Mehr erfahren auf ';

  @override
  String get profileUnblockButton => 'Entsperren';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName entfolgen';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName blockieren';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName entsperren';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '$displayName melden';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayName zu einer Liste hinzufügen';
  }

  @override
  String get profileNoCollabsTitle => 'Noch keine Collabs';

  @override
  String get profileCollabsOwnEmpty =>
      'Videos, bei denen du mitmachst, erscheinen hier';

  @override
  String get profileCollabsOtherEmpty =>
      'Videos, bei denen er mitmacht, erscheinen hier';

  @override
  String get profileErrorLoadingCollabs =>
      'Fehler beim Laden der Collab-Videos';

  @override
  String get profileNoSavedVideosTitle => 'Noch nichts gespeichert';

  @override
  String get profileSavedOwnEmpty =>
      'Setz im Teilen-Menü ein Lesezeichen für Videos und sie tauchen hier auf.';

  @override
  String get profileErrorLoadingSaved =>
      'Fehler beim Laden gespeicherter Videos';

  @override
  String get profileNoCommentsOwnTitle => 'Noch keine Kommentare';

  @override
  String get profileNoCommentsOtherTitle => 'Keine Kommentare';

  @override
  String get profileCommentsOwnEmpty =>
      'Deine Kommentare und Antworten erscheinen hier';

  @override
  String get profileCommentsOtherEmpty =>
      'Seine Kommentare und Antworten erscheinen hier';

  @override
  String get profileErrorLoadingComments => 'Fehler beim Laden der Kommentare';

  @override
  String get profileVideoRepliesSection => 'Video-Antworten';

  @override
  String get profileCommentsSection => 'Kommentare';

  @override
  String get profileEditLabel => 'Bearbeiten';

  @override
  String get profileLibraryLabel => 'Bibliothek';

  @override
  String get profileNoLikedVideosTitle => 'Noch keine gelikten Videos';

  @override
  String get profileLikedOwnEmpty => 'Videos, die du likest, erscheinen hier';

  @override
  String get profileLikedOtherEmpty => 'Videos, die er likest, erscheinen hier';

  @override
  String get profileErrorLoadingLiked =>
      'Fehler beim Laden der gelikten Videos';

  @override
  String get profileNoRepostsTitle => 'Noch keine Reposts';

  @override
  String get profileRepostsOwnEmpty =>
      'Videos, die du repostest, erscheinen hier';

  @override
  String get profileRepostsOtherEmpty =>
      'Videos, die er repostest, erscheinen hier';

  @override
  String get profileErrorLoadingReposts => 'Fehler beim Laden der Reposts';

  @override
  String get profileNoVideosTitle => 'Noch keine Videos';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Teile dein erstes Video, um es hier zu sehen';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Dieser Nutzer hat noch keine Videos geteilt';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Video-Vorschaubild $number';
  }

  @override
  String get profileShowMore => 'Mehr anzeigen';

  @override
  String get profileShowLess => 'Weniger anzeigen';

  @override
  String get dmMessageDisplayLimitReached =>
      'Der Rest dieser Nachricht wird nicht angezeigt.';

  @override
  String get profileCompleteYourProfile => 'Profil vervollständigen';

  @override
  String get profileCompleteSubtitle =>
      'Füge Name, Bio und Bild hinzu, um loszulegen';

  @override
  String get profilePleaseTryAgain => 'Bitte versuch es nochmal';

  @override
  String get profileSecureYourAccount => 'Konto absichern';

  @override
  String get profileSecureSubtitle =>
      'Füge E-Mail & Passwort hinzu, um dein Konto auf jedem Gerät wiederherzustellen';

  @override
  String get profileRetryButton => 'Erneut versuchen';

  @override
  String get profileSessionExpired => 'Sitzung abgelaufen';

  @override
  String get profileSignInToRestore =>
      'Melde dich erneut an, um wieder vollen Zugriff zu haben';

  @override
  String get profileSignInButton => 'Anmelden';

  @override
  String get profileMaybeLaterLabel => 'Vielleicht später';

  @override
  String get profileSecurePrimaryButton => 'E-Mail & Passwort hinzufügen';

  @override
  String get profileCompletePrimaryButton => 'Profil aktualisieren';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Likes';

  @override
  String get profileMyLibraryLabel => 'Meine Bibliothek';

  @override
  String get profileMessageLabel => 'Nachricht';

  @override
  String get profileShareLabel => 'Profil teilen';

  @override
  String get profileDeletedAccountName => 'Gelöschtes Konto';

  @override
  String get inboxActionReportVanishedAccount => 'Dieses Konto melden';

  @override
  String get inboxActionBlockVanishedAccount => 'Dieses Konto blockieren';

  @override
  String get inboxActionUnblockVanishedAccount => 'Dieses Konto entblocken';

  @override
  String get inboxReportedVanishedAccount => 'Dieses Konto wurde gemeldet';

  @override
  String get inboxBlockedVanishedAccount => 'Dieses Konto wurde blockiert';

  @override
  String get inboxUnblockedVanishedAccount => 'Dieses Konto wurde entblockt';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Dadurch wird die Unterhaltung aus deinem Posteingang entfernt. Wenn dir diese Person wieder schreibt, beginnt eine neue Unterhaltung.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Dieses Konto wurde gelöscht';

  @override
  String get profileUserFallback => 'Nutzer';

  @override
  String get profileLinkCopied => 'Profil-Link kopiert';

  @override
  String get profileSetupEditProfileTitle => 'Profil bearbeiten';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Richte dein Profil ein, bevor du eine NIP-05-Adresse hinzufügst.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Profil erstellen';

  @override
  String get profileSetupBackLabel => 'Zurück';

  @override
  String get profileSetupAboutNostr => 'Über Nostr';

  @override
  String get profileSetupProfilePublished =>
      'Profil erfolgreich veröffentlicht!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Änderungen speichern?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Speichere deine Änderungen, bevor du gehst – oder verwirf sie und mach weiter.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Änderungen speichern';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Änderungen verwerfen';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Weiter bearbeiten';

  @override
  String get profileSetupCreateNewProfile => 'Neues Profil erstellen?';

  @override
  String get profileSetupNoExistingProfile =>
      'Wir haben kein bestehendes Profil auf deinen Relays gefunden. Beim Veröffentlichen wird ein neues Profil erstellt. Weitermachen?';

  @override
  String get profileSetupPublishButton => 'Veröffentlichen';

  @override
  String get profileSetupUsernameTaken =>
      'Der Benutzername wurde gerade vergeben. Bitte wähl einen anderen.';

  @override
  String get profileSetupClaimFailed =>
      'Benutzername konnte nicht reserviert werden. Bitte versuch es nochmal.';

  @override
  String get profileSetupPublishFailed =>
      'Profil konnte nicht veröffentlicht werden. Bitte versuch es nochmal.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Netzwerk nicht erreichbar. Überprüfe deine Verbindung und versuch es nochmal.';

  @override
  String get profileSetupDisplayNameLabel => 'Anzeigename';

  @override
  String get profileSetupDisplayNameRequired =>
      'Bitte gib einen Anzeigenamen ein';

  @override
  String get profileSetupBioLabel => 'Bio (optional)';

  @override
  String get profileSetupWebsiteLabel => 'Website (optional)';

  @override
  String get profileSetupPublicKeyLabel => 'Öffentlicher Schlüssel (npub)';

  @override
  String get profileSetupUsernameLabel => 'Benutzername (optional)';

  @override
  String get profileSetupUsernameHelper =>
      'Verwende Buchstaben, Zahlen oder Bindestriche. Dein Benutzername wird zu einer divine.video-Adresse. Leerzeichen und Symbole kannst du im Anzeigenamen verwenden.';

  @override
  String get profileSetupSaveButton => 'Speichern';

  @override
  String get profileSetupSavingButton => 'Wird gespeichert...';

  @override
  String get profileSetupImageUrlTitle => 'Bild-URL hinzufügen';

  @override
  String get profileSetupImageSelectionFailed =>
      'Bildauswahl fehlgeschlagen. Bitte füg stattdessen eine Bild-URL unten ein.';

  @override
  String get profileSetupImagesTypeGroup => 'Bilder';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Der Kamerazugriff ist aus. Schalte ihn in den Einstellungen ein, um ein Foto zu machen.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Der Kamerazugriff ist auf diesem Gerät nicht erlaubt.';

  @override
  String get cameraPickErrorBusy =>
      'Die Auswahl ist schon offen. Schließ sie und versuch es nochmal.';

  @override
  String get cameraPickErrorGeneric =>
      'Die Kamera konnte nicht geöffnet werden. Versuch es nochmal.';

  @override
  String get profileSetupGotItButton => 'Verstanden';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Bild konnte nicht hochgeladen werden. Bitte versuche es später noch einmal.';

  @override
  String get profileSetupUploadNetworkError =>
      'Netzwerkfehler: Bitte prüf deine Internetverbindung und versuch es nochmal.';

  @override
  String get profileSetupUploadAuthError =>
      'Authentifizierungsfehler: Bitte melde dich ab und wieder an.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Datei zu groß: Bitte wähl ein kleineres Bild (max. 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Bild konnte nicht hochgeladen werden. Unsere Server sind vorübergehend nicht verfügbar. Bitte versuche es gleich noch einmal.';

  @override
  String get profileSetupBannerClearButton => 'Banner entfernen';

  @override
  String get profileSetupBannerChangeColor => 'Bannerfarbe';

  @override
  String get profileSetupChangeBannerTitle => 'Banner ändern';

  @override
  String get profileSetupBannerColorPickerTitle => 'Bannerfarbe ändern';

  @override
  String get profileSetupBannerColorCustom => 'Benutzerdefiniert';

  @override
  String get profileSetupBannerColorNone => 'Keine Farbe';

  @override
  String get profileSetupBannerColorLime => 'Limette';

  @override
  String get profileSetupBannerColorYellow => 'Gelb';

  @override
  String get profileSetupBannerColorViolet => 'Violett';

  @override
  String get profileSetupBannerColorPink => 'Pink';

  @override
  String get profileSetupBannerColorOrange => 'Orange';

  @override
  String get profileSetupBannerColorPurple => 'Lila';

  @override
  String get profileSetupAvatarClearButton => 'Foto entfernen';

  @override
  String get profileSetupImageTakePhoto => 'Foto aufnehmen';

  @override
  String get profileSetupImageUploadFromCameraRoll =>
      'Aus der Galerie hochladen';

  @override
  String get profileSetupImagePasteLink => 'Bildlink einfügen';

  @override
  String get profileSetupEditAvatarLabel => 'Profilbild bearbeiten';

  @override
  String get profileSetupEditBannerLabel => 'Banner bearbeiten';

  @override
  String get profileSetupUsernameChecking => 'Verfügbarkeit wird geprüft...';

  @override
  String get profileSetupUsernameAvailable => 'Benutzername verfügbar!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Benutzername bereits vergeben';

  @override
  String get profileSetupUsernameReserved => 'Benutzername ist reserviert';

  @override
  String get profileSetupContactSupport => 'Support kontaktieren';

  @override
  String get profileSetupCheckAgain => 'Erneut prüfen';

  @override
  String get profileSetupUsernameBurned =>
      'Dieser Benutzername ist nicht mehr verfügbar';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Nur Buchstaben, Zahlen und Bindestriche sind erlaubt';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Der Benutzername darf nicht mit einem Bindestrich beginnen oder enden';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Benutzername muss 3-63 Zeichen lang sein';

  @override
  String get profileSetupUsernameNetworkError =>
      'Verfügbarkeit konnte nicht geprüft werden. Bitte versuch es nochmal.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Ungültiges Benutzernamen-Format';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Verfügbarkeit konnte nicht geprüft werden';

  @override
  String get profileSetupUsernameReservedTitle => 'Benutzername reserviert';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Der Name $username ist reserviert. Sag uns, warum er dir gehören sollte.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'z.B. Es ist mein Markenname, Künstlername usw.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Schon den Support kontaktiert? Tippe auf \"Erneut prüfen\", um zu sehen, ob er dir freigegeben wurde.';

  @override
  String get profileSetupSupportRequestSent =>
      'Support-Anfrage gesendet! Wir melden uns bald bei dir.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'E-Mail konnte nicht geöffnet werden. Sende an: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Anfrage senden';

  @override
  String get profileSetupUseOwnNip05 => 'Eigene NIP-05-Adresse verwenden';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05-Adresse';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Ungültiges NIP-05-Format (z. B. name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Nutz das Nutzernamen-Feld oben für divine.video';

  @override
  String get nostrSettingsNip05Address => 'NIP-05-Adresse';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Nutze deinen divine.video-Nutzernamen oder verweise deinen Handle auf eine NIP-05-Adresse auf einer Domain, die dir gehört.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'NIP-05 speichern';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 gespeichert';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'NIP-05 konnte nicht gespeichert werden. Bitte versuch es erneut.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Eigene NIP-05 verwenden?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 verknüpft einen Namen wie du@deinedomain.de mit deiner Nostr-Identität. Du musst die Domain kontrollieren und eine Verifizierungsdatei am richtigen Pfad hinterlegen. Stimmt etwas nicht, finden dich Leute nicht mehr und dein verifizierter Handle verschwindet. Mach nur weiter, wenn du das eingerichtet hast.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Weiter';

  @override
  String get profileSetupNip05ConfirmCancel => 'Abbrechen';

  @override
  String get profileSetupProfilePicturePreview => 'Profilbild-Vorschau';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine basiert auf Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' einem zensurresistenten offenen Protokoll, das es Menschen ermöglicht, online zu kommunizieren, ohne von einem einzelnen Unternehmen oder einer Plattform abhängig zu sein. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Wenn du dich bei Divine anmeldest, bekommst du eine neue Nostr-Identität.';

  @override
  String get nostrInfoOwnership =>
      'Mit Nostr gehören dir deine Inhalte, deine Identität und dein soziales Netzwerk, die du in vielen Apps nutzen kannst. Das Ergebnis: mehr Auswahl, weniger Lock-in und ein gesünderes, widerstandsfähigeres soziales Internet.';

  @override
  String get nostrInfoLingo => 'Nostr-Vokabular:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Deine öffentliche Nostr-Adresse. Du kannst sie bedenkenlos teilen—damit finden dich andere, folgen dir oder schreiben dir in Nostr-Apps.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Dein privater Schlüssel und Eigentumsnachweis. Er gibt vollen Zugriff auf deine Nostr-Identität, also ';

  @override
  String get nostrInfoNsecWarning => 'halt ihn immer geheim!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr-Benutzername:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Ein lesbarer Name (wie @name.divine.video), der auf deinen npub verweist. Er macht deine Nostr-Identität leichter erkennbar und verifizierbar, ähnlich wie eine E-Mail-Adresse.';

  @override
  String get nostrInfoLearnMoreAt => 'Mehr erfahren auf ';

  @override
  String get nostrInfoGotIt => 'Verstanden!';

  @override
  String get videoGridRefreshLabel => 'Suche nach weiteren Videos';

  @override
  String get videoGridOptionsTitle => 'Video-Optionen';

  @override
  String get videoGridEditVideo => 'Video bearbeiten';

  @override
  String get videoGridEditVideoSubtitle =>
      'Titel, Beschreibung und Hashtags aktualisieren';

  @override
  String get videoGridDeleteVideo => 'Video löschen';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Dieses Video aus Divine entfernen. Es kann weiterhin in anderen Nostr-Clients erscheinen.';

  @override
  String get videoGridDeletingContent => 'Inhalt wird gelöscht...';

  @override
  String get exploreTabFeatured => 'Empfohlen';

  @override
  String get exploreTabClassics => 'Klassiker';

  @override
  String get exploreTabNew => 'Neu';

  @override
  String get exploreTabPopular => 'Beliebt';

  @override
  String get exploreTabCategories => 'Kategorien';

  @override
  String get exploreTabForYou => 'Für dich';

  @override
  String get exploreTabLists => 'Listen';

  @override
  String get exploreTabIntegratedApps => 'Integrierte Apps';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty =>
      'Hier ist noch nichts. Schau bald wieder rein.';

  @override
  String get featuredTabLoadFailed =>
      'Diese Sammlung konnte nicht geladen werden.';

  @override
  String get featuredTabRetry => 'Erneut versuchen';

  @override
  String get exploreNoVideosAvailable => 'Keine Videos verfügbar';

  @override
  String get exploreDiscoverLists => 'Listen entdecken';

  @override
  String get exploreAboutLists => 'Über Listen';

  @override
  String get exploreAboutListsDescription =>
      'Listen helfen dir, Divine-Inhalte auf zwei Arten zu organisieren und zu kuratieren:';

  @override
  String get explorePeopleLists => 'Personen-Listen';

  @override
  String get explorePeopleListsDescription =>
      'Folge Gruppen von Creatorn und sieh ihre neuesten Videos';

  @override
  String get exploreVideoLists => 'Video-Listen';

  @override
  String get exploreVideoListsDescription =>
      'Erstelle Playlists deiner Lieblingsvideos, um sie später anzusehen';

  @override
  String get exploreMyLists => 'Meine Listen';

  @override
  String get exploreSubscribedLists => 'Abonnierte Listen';

  @override
  String get exploreErrorLoadingLists =>
      'Fehler beim Laden der Listen. Bitte versuch es nochmal.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Videos',
      one: '1 neues Video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Videos',
      one: 's Video',
    );
    return '$count neue$_temp0 laden';
  }

  @override
  String get videoPlayerPlayVideo => 'Video abspielen';

  @override
  String get videoPlayerMute => 'Video stummschalten';

  @override
  String get videoPlayerUnmute => 'Video-Ton einschalten';

  @override
  String get videoPlayerTapHint =>
      'Tippe zum Abspielen oder Pausieren. Doppelt tippen zum Liken.';

  @override
  String get videoSettingsMenuOpen => 'Wiedergabeeinstellungen öffnen';

  @override
  String get videoSettingsMenuClose => 'Wiedergabeeinstellungen schließen';

  @override
  String get videoSettingsCaptionsEnable => 'Untertitel aktivieren';

  @override
  String get videoSettingsCaptionsDisable => 'Untertitel deaktivieren';

  @override
  String get videoSettingsAutoAdvanceOn => 'Automatisches Weiterblättern an';

  @override
  String get videoSettingsAutoAdvanceOff => 'Automatisches Weiterblättern aus';

  @override
  String get videoSettingsCaptionsOn => 'Untertitel an';

  @override
  String get videoSettingsCaptionsOff => 'Untertitel aus';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Untertitel für dieses Video an';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Untertitel für dieses Video aus';

  @override
  String get contentWarningLabel => 'Inhaltswarnung';

  @override
  String get contentWarningNudity => 'Nacktheit';

  @override
  String get contentWarningSexualContent => 'Sexuelle Inhalte';

  @override
  String get contentWarningPornography => 'Pornografie';

  @override
  String get contentWarningGraphicMedia => 'Explizite Inhalte';

  @override
  String get contentWarningViolence => 'Gewalt';

  @override
  String get contentWarningSelfHarm => 'Selbstverletzung';

  @override
  String get contentWarningDrugUse => 'Drogenkonsum';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tabak';

  @override
  String get contentWarningGambling => 'Glücksspiel';

  @override
  String get contentWarningProfanity => 'Vulgäre Sprache';

  @override
  String get contentWarningFlashingLights => 'Blinkende Lichter';

  @override
  String get contentWarningAiGenerated => 'KI-generiert';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Sensible Inhalte';

  @override
  String get contentWarningDescNudity => 'Enthält Nacktheit oder Teilnacktheit';

  @override
  String get contentWarningDescSexual => 'Enthält sexuelle Inhalte';

  @override
  String get contentWarningDescPorn =>
      'Enthält explizite pornografische Inhalte';

  @override
  String get contentWarningDescGraphicMedia =>
      'Enthält explizite oder verstörende Bilder';

  @override
  String get contentWarningDescViolence => 'Enthält gewalttätige Inhalte';

  @override
  String get contentWarningDescSelfHarm =>
      'Enthält Hinweise auf Selbstverletzung';

  @override
  String get contentWarningDescDrugs => 'Enthält drogenbezogene Inhalte';

  @override
  String get contentWarningDescAlcohol => 'Enthält alkoholbezogene Inhalte';

  @override
  String get contentWarningDescTobacco => 'Enthält tabakbezogene Inhalte';

  @override
  String get contentWarningDescGambling =>
      'Enthält glücksspielbezogene Inhalte';

  @override
  String get contentWarningDescProfanity => 'Enthält vulgäre Sprache';

  @override
  String get contentWarningDescFlashingLights =>
      'Enthält blinkende Lichter (Warnung bei Photosensibilität)';

  @override
  String get contentWarningDescAiGenerated =>
      'Dieser Inhalt wurde von KI generiert';

  @override
  String get contentWarningDescSpoiler => 'Enthält Spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Creator hat dies als sensibel markiert';

  @override
  String get contentWarningDescDefault =>
      'Creator hat diesen Inhalt gekennzeichnet';

  @override
  String get contentWarningDetailsTitle => 'Inhaltswarnungen';

  @override
  String get contentWarningDetailsSubtitle =>
      'Der Creator hat diese Labels gesetzt:';

  @override
  String get contentWarningManageFilters => 'Inhaltsfilter verwalten';

  @override
  String get contentWarningViewAnyway => 'Trotzdem ansehen';

  @override
  String get contentWarningReportContentTooltip => 'Inhalt melden';

  @override
  String get contentWarningBlockUserTooltip => 'Nutzer blockieren';

  @override
  String get contentWarningBlockedTitle => 'Inhalt blockiert';

  @override
  String get contentWarningBlockedPolicy =>
      'Dieser Inhalt wurde wegen Richtlinienverstößen blockiert.';

  @override
  String get contentWarningNoticeTitle => 'Hinweis zum Inhalt';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potenziell schädlicher Inhalt';

  @override
  String get contentWarningView => 'Anzeigen';

  @override
  String get contentWarningReportAction => 'Melden';

  @override
  String get contentWarningHideAllLikeThis =>
      'Alle Inhalte wie diesen ausblenden';

  @override
  String get contentWarningNoFilterYet =>
      'Noch kein gespeicherter Filter für diese Warnung.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Wir blenden Beiträge wie diesen ab jetzt aus.';

  @override
  String get communitySuggestTitle => 'Hilf mit, das einzuordnen';

  @override
  String get communitySuggestSubtitle =>
      'Fehlt eine Inhaltswarnung? Dein Vorschlag ist öffentlich, signiert und kann nicht zurückgenommen werden.';

  @override
  String get communitySuggestSubmit => 'Vorschlagen';

  @override
  String get communitySuggestSuccess => 'Danke. Dein Vorschlag wurde gesendet.';

  @override
  String get communitySuggestFailure =>
      'Dein Vorschlag konnte nicht gesendet werden. Versuch es erneut.';

  @override
  String get communitySuggestAlready => 'Von dir vorgeschlagen';

  @override
  String get communitySuggestActionLabel => 'Einordnen';

  @override
  String get videoErrorNotFound => 'Video nicht gefunden';

  @override
  String get videoErrorPlayback => 'Video-Wiedergabefehler';

  @override
  String get videoErrorAgeRestricted => 'Altersbeschränkter Inhalt';

  @override
  String get videoErrorUnavailable => 'Video nicht verfügbar';

  @override
  String get videoErrorUnavailableBody =>
      'Dieses Video ist gerade nicht verfügbar.';

  @override
  String get videoErrorRetry => 'Erneut versuchen';

  @override
  String get videoErrorContentRestricted => 'Inhalt eingeschränkt';

  @override
  String get videoErrorContentRestrictedBody =>
      'Dieses Video wurde entfernt, weil es gegen unsere Inhaltsregeln verstößt.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifiziere dein Alter, um dieses Video zu sehen.';

  @override
  String get videoErrorSkip => 'Überspringen';

  @override
  String get videoErrorVerifyAgeButton => 'Alter verifizieren';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Wir konnten dein Alter nicht bestätigen. Bitte versuch es nochmal.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Zeitüberschreitung bei der Überprüfung. Prüf deine Verbindung oder versuch es gleich nochmal.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Inhalte für Erwachsene sind ausgeschaltet';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Schalte sie in deinen Inhaltsfiltern ein, um dieses Video zu sehen.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Inhaltsfilter öffnen';

  @override
  String get videoDetailLoadError => 'Video konnte nicht geladen werden';

  @override
  String get videoDetailLoadErrorBody =>
      'Auf dem Weg hierher ist was schiefgelaufen. Probier\'s nochmal.';

  @override
  String get videoDetailNotFoundBody =>
      'Vielleicht ist es gelöscht, gerade nicht erreichbar oder durch deine Einstellungen ausgeblendet.';

  @override
  String get databaseCorruptionTitle => 'Deine lokalen Daten sind beschädigt';

  @override
  String get databaseCorruptionBody =>
      'Schließ Divine und öffne es neu — wir reparieren das automatisch. Wir retten so viel wie möglich von deinen Entwürfen und Clips, alles andere lädt neu.';

  @override
  String get databaseCorruptionCloseButton => 'Divine schließen';

  @override
  String get videoDetailContextTitle => 'Geteiltes Video';

  @override
  String get videoDetailCloseSemanticLabel => 'Videoplayer schließen';

  @override
  String get videoFollowButtonFollow => 'Folgen';

  @override
  String get audioAttributionOriginalSound => 'Originalton';

  @override
  String get audioAttributionUnavailableSound => 'Ton nicht verfügbar';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspiriert von @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspiriert von @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'mit @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'mit @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitwirkende',
      one: '1 Mitwirkender',
    );
    return '$_temp0. Tippe für das Profil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Ausstehend';

  @override
  String get videoCollaboratorPendingSemanticLabel =>
      'Ausstehende Zusammenarbeit';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending ausstehend)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Tippe, um das Profil anzusehen.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Tippen, um Videos mit diesem Hashtag anzusehen.';
  }

  @override
  String get listAttributionFallback => 'Liste';

  @override
  String get shareVideoLabel => 'Video teilen';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Beitrag mit $recipientName geteilt';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Beitrag mit $count Personen geteilt',
      one: 'Beitrag mit $count Person geteilt',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Video konnte nicht gesendet werden';

  @override
  String get shareAddedToBookmarks => 'Zu Lesezeichen hinzugefügt';

  @override
  String get shareRemovedFromBookmarks => 'Aus Lesezeichen entfernt';

  @override
  String get shareFailedToAddBookmark =>
      'Lesezeichen konnte nicht hinzugefügt werden';

  @override
  String get shareFailedToRemoveBookmark =>
      'Lesezeichen konnte nicht entfernt werden';

  @override
  String get shareActionFailed => 'Aktion fehlgeschlagen';

  @override
  String get shareWithTitle => 'Teilen mit';

  @override
  String get shareFindPeople => 'Leute finden';

  @override
  String get shareFindPeopleMultiline => 'Leute\nfinden';

  @override
  String get shareSent => 'Gesendet';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name ausgewählt';
  }

  @override
  String get shareMessageHint => 'Optionale Nachricht hinzufügen...';

  @override
  String get videoActionUnlike => 'Like entfernen';

  @override
  String get videoActionLike => 'Video liken';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Liken';

  @override
  String get videoActionReplyLabel => 'Antworten';

  @override
  String get videoActionRepostLabel => 'Reposten';

  @override
  String get videoActionShareLabel => 'Teilen';

  @override
  String get videoActionReportLabel => 'Melden';

  @override
  String get videoActionReport => 'Video melden';

  @override
  String get videoActionEditLabel => 'Bearbeiten';

  @override
  String get videoActionEdit => 'Video bearbeiten';

  @override
  String get videoActionAboutLabel => 'Info';

  @override
  String get videoActionEnableAutoAdvance =>
      'Automatisches Weiterblättern aktivieren';

  @override
  String get videoActionDisableAutoAdvance =>
      'Automatisches Weiterblättern deaktivieren';

  @override
  String get videoActionRemoveRepost => 'Repost entfernen';

  @override
  String get videoActionRepost => 'Video reposten';

  @override
  String get videoActionViewComments => 'Kommentare ansehen';

  @override
  String get videoActionMoreOptions => 'Weitere Optionen';

  @override
  String get videoEngagementLikersTitle => 'Geliket von';

  @override
  String get videoEngagementRepostersTitle => 'Repostet von';

  @override
  String get videoEngagementLikersEmpty => 'Noch keine Likes';

  @override
  String get videoEngagementRepostersEmpty => 'Noch keine Reposts';

  @override
  String get videoEngagementLoadFailed => 'Liste konnte nicht geladen werden';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Videodetails öffnen';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Videodetails öffnen';

  @override
  String get videoOverlayCommentBarHint => 'Kommentar hinzufügen …';

  @override
  String get videoOverlayCommentBarSemanticLabel =>
      'Einen Kommentar hinzufügen';

  @override
  String get videoOverlayCommentBarSendLabel => 'Kommentar senden';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Kommentar gepostet';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Kommentar konnte nicht gepostet werden';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loops',
      one: 'Loop',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Nicht Divine';

  @override
  String get metadataBadgeHumanMade => 'Von Menschenhand';

  @override
  String get metadataSoundsLabel => 'Sounds';

  @override
  String get metadataOriginalSound => 'Originalton';

  @override
  String get metadataVerificationLabel => 'Verifizierung';

  @override
  String get metadataDeviceAttestation => 'Geräteattestierung';

  @override
  String get metadataPgpSignature => 'PGP-Signatur';

  @override
  String get metadataC2paCredentials => 'C2PA Content Credentials';

  @override
  String get metadataProofManifest => 'Proof-Manifest';

  @override
  String get metadataVerificationInfoTooltip => 'Was bedeuten diese Prüfungen?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Was diese Prüfungen bedeuten';

  @override
  String get metadataVerificationInfoIntro =>
      'Diese Signale stammen von der Kamera und aus der Videodatei selbst. Je mehr davon ein Video mitbringt, desto mehr können wir über seine Herkunft belegen.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Das Betriebssystem des Handys hat für die App gebürgt, die hier aufgenommen hat. Ein starkes Indiz, dass es aus einer Kamera kommt und nicht aus einer hochgeladenen Datei.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Das Video wurde im Moment der Aufnahme kryptografisch signiert. Ändert sich danach auch nur ein Einzelbild, bricht die Signatur.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Ein Herkunftsnachweis nach Industriestandard, der in der Datei mitreist – so können ihn auch andere Apps als Divine prüfen.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Der vollständige ProofMode-Datensatz: Dateifingerabdruck, Zeitstempel und Aufnahmekontext, zusammen mit dem Video.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Eine fehlende Prüfung macht ein Video nicht zur Fälschung. Ältere Clips und Uploads hatten nie eine – es heißt nur, dass wir diesen Teil nicht belegen können.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Mehr erfahren auf $url';
  }

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Mitwirkende';

  @override
  String get metadataInspiredByLabel => 'Inspiriert von';

  @override
  String get metadataRepostedByLabel => 'Repostet von';

  @override
  String metadataMoreReposters(int count) {
    return '+$count weitere';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'Likes';

  @override
  String get metadataCommentsLabel => 'Kommentare';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get metadataVineStatsLabel => 'Auf Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops Loops · $likes Likes · $comments Kommentare · $reposts Reposts';
  }

  @override
  String get metadataDivineStatsLabel => 'Auf Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views Aufrufe · $likes Likes · $comments Kommentare · $reposts Reposts';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Veröffentlicht am $date';
  }

  @override
  String get devOptionsTitle => 'Entwickleroptionen';

  @override
  String get devOptionsDisableDeveloperMode => 'Entwicklermodus deaktivieren';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Entwickleroptionen aus den Einstellungen ausblenden';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Entwicklermodus deaktiviert';

  @override
  String get devOptionsShorebirdTitle => 'Shorebird-Patches';

  @override
  String get devOptionsShorebirdPatchLabel => 'Aktiver Patch';

  @override
  String get devOptionsShorebirdNoPatch => 'Kein Patch installiert';

  @override
  String get devOptionsShorebirdUnavailable =>
      'In diesem Build nicht verfügbar';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Patches funktionieren nur in einem mit shorebird release erstellten Build.';

  @override
  String get devOptionsShorebirdLoading => 'Patch-Status wird gelesen…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Staging-Track noch nicht geprüft.';

  @override
  String get devOptionsShorebirdCheck => 'Staging-Track prüfen';

  @override
  String get devOptionsShorebirdApply => 'Staging-Patch anwenden';

  @override
  String get devOptionsShorebirdUseStable => 'Zu stabilen Updates zurückkehren';

  @override
  String get devOptionsShorebirdChecking => 'Staging-Track wird geprüft…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Ein Staging-Patch kann angewendet werden.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Kein Staging-Patch für diese Version.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Heruntergeladen. App neu starten, um ihn zu laden.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Ein Rollback ist bereit. Neu starten, um zur Basisversion zurückzukehren.';

  @override
  String get devOptionsShorebirdApplying =>
      'Wird heruntergeladen und installiert…';

  @override
  String get devOptionsShorebirdApplied =>
      'Installiert. App neu starten, um ihn zu laden.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Nichts wurde installiert. Staging-Track prüfen und erneut versuchen.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Stabiler Kanal wird ausgewählt…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Stabiler Kanal ausgewählt. Starte die App neu, um nach einem stabilen Patch zu suchen.';

  @override
  String get devOptionsShorebirdFailure =>
      'Das hat nicht funktioniert. Details stehen in den Logs.';

  @override
  String get devOptionsPageLoadTimes => 'Seiten-Ladezeiten';

  @override
  String get devOptionsNoPageLoads =>
      'Noch keine Seitenladevorgänge aufgezeichnet.\nNavigiere durch die App, um Timing-Daten zu sehen.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Sichtbar: ${visibleMs}ms  |  Daten: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Langsamste Screens';

  @override
  String get devOptionsVideoPlaybackFormat => 'Video-Wiedergabeformat';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Umgebung wechseln?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Zu $envName wechseln?\n\nDamit werden zwischengespeicherte Videodaten gelöscht und die Verbindung zum neuen Relay aufgebaut.';
  }

  @override
  String get devOptionsCancel => 'Abbrechen';

  @override
  String get devOptionsSwitch => 'Wechseln';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Zu $envName gewechselt';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Zu $formatName gewechselt — Cache geleert';
  }

  @override
  String get featureFlagTitle => 'Feature-Flags';

  @override
  String get featureFlagResetAllTooltip =>
      'Alle Flags auf Standard zurücksetzen';

  @override
  String get featureFlagError => 'Fehler';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine ist ein offenes System - du kontrollierst deine Verbindungen';

  @override
  String get relaySettingsInfoDescription =>
      'Diese Relays verteilen deine Inhalte im dezentralen Nostr-Netzwerk. Du kannst Relays nach Belieben hinzufügen oder entfernen.';

  @override
  String get relaySettingsLearnMoreNostr => 'Mehr über Nostr erfahren →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Öffentliche Relays auf nostr.co.uk finden →';

  @override
  String get relaySettingsAppNotFunctional => 'App nicht funktionsfähig';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine benötigt mindestens ein Relay, um Videos zu laden, Inhalte zu posten und Daten zu synchronisieren.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Standard-Relay wiederherstellen';

  @override
  String get relaySettingsAddCustomRelay => 'Eigenes Relay hinzufügen';

  @override
  String get relaySettingsAddRelay => 'Relay hinzufügen';

  @override
  String get relaySettingsRetry => 'Erneut versuchen';

  @override
  String get relaySettingsNoStats => 'Noch keine Statistiken verfügbar';

  @override
  String get relaySettingsConnection => 'Verbindung';

  @override
  String get relaySettingsConnected => 'Verbunden';

  @override
  String get relaySettingsDisconnected => 'Getrennt';

  @override
  String get relaySettingsSessionDuration => 'Sitzungsdauer';

  @override
  String get relaySettingsLastConnected => 'Zuletzt verbunden';

  @override
  String get relaySettingsDisconnectedLabel => 'Getrennt';

  @override
  String get relaySettingsReason => 'Grund';

  @override
  String get relaySettingsActiveSubscriptions => 'Aktive Abonnements';

  @override
  String get relaySettingsTotalSubscriptions => 'Gesamtabonnements';

  @override
  String get relaySettingsEventsReceived => 'Empfangene Events';

  @override
  String get relaySettingsEventsSent => 'Gesendete Events';

  @override
  String get relaySettingsRequestsThisSession => 'Anfragen in dieser Sitzung';

  @override
  String get relaySettingsFailedRequests => 'Fehlgeschlagene Anfragen';

  @override
  String get relaySettingsLoadingRelayInfo => 'Relay-Infos werden geladen...';

  @override
  String get relaySettingsAboutRelay => 'Über Relay';

  @override
  String get relaySettingsSupportedNips => 'Unterstützte NIPs';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Website ansehen';

  @override
  String get relaySettingsRemoveRelayTitle => 'Relay entfernen?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Bist du sicher, dass du dieses Relay entfernen willst?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Divine-Relay entfernen?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Wenn du Divines Relay entfernst, wird die App-Erfahrung schlechter. Videos, Posten und Synchronisierung können unzuverlässiger werden. Das sollten nur erfahrene Nostr-Nutzer tun.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Relay entfernen';

  @override
  String get relaySettingsCancel => 'Abbrechen';

  @override
  String get relaySettingsRemove => 'Entfernen';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay entfernt: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay =>
      'Relay konnte nicht entfernt werden';

  @override
  String get relaySettingsForcingReconnection =>
      'Relay-Verbindung wird erzwungen...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Mit $count Relay(s) verbunden!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Verbindung zu Relays fehlgeschlagen. Bitte prüf deine Netzwerkverbindung.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Auf diesem Gerät gespeichert. Wir synchronisieren es mit deinem Konto, sobald das Veröffentlichen wieder funktioniert.';

  @override
  String get relaySettingsAddRelayTitle => 'Relay hinzufügen';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Gib die WebSocket-URL des Relays ein, das du hinzufügen willst:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Öffentliche Relays auf nostr.co.uk durchsuchen';

  @override
  String get relaySettingsAdd => 'Hinzufügen';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay hinzugefügt: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Relay konnte nicht hinzugefügt werden. Bitte prüf die URL und versuch es nochmal.';

  @override
  String get relaySettingsInvalidUrl =>
      'Relay-URL muss mit wss:// oder ws:// beginnen';

  @override
  String get relaySettingsInsecureUrl =>
      'Relay-URL muss wss:// nutzen (ws:// ist nur für localhost erlaubt)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Standard-Relay wiederhergestellt: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Standard-Relay konnte nicht wiederhergestellt werden. Bitte prüf deine Netzwerkverbindung.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Browser konnte nicht geöffnet werden';

  @override
  String get relaySettingsFailedToOpenLink =>
      'Link konnte nicht geöffnet werden';

  @override
  String get relaySettingsExternalRelay => 'Externes Relay';

  @override
  String get relaySettingsNotConnected => 'Nicht verbunden';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Vor $duration getrennt';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count Subs';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count Events';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'vor $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine nutzt das Nostr-Protokoll für dezentrales Veröffentlichen. Deine Inhalte liegen auf Relays deiner Wahl, und deine Schlüssel sind deine Identität.';

  @override
  String get nostrSettingsSectionNetwork => 'Netzwerk';

  @override
  String get nostrSettingsSectionAccount => 'Konto';

  @override
  String get nostrSettingsSectionDangerZone => 'Gefahrenzone';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Nostr-Relay-Verbindungen verwalten';

  @override
  String get nostrSettingsRelayDiagnostics => 'Relay-Diagnose';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Relay-Verbindungen und Netzwerkprobleme debuggen';

  @override
  String get nostrSettingsMediaServers => 'Medienserver';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Blossom-Upload-Server konfigurieren';

  @override
  String get settingsDeveloperOptions => 'Entwickleroptionen';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Umgebungswechsler und Debug-Einstellungen';

  @override
  String get nostrSettingsKeyManagement => 'Schlüsselverwaltung';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Deine Nostr-Schlüssel exportieren, sichern und wiederherstellen';

  @override
  String get nostrSettingsClientAttribution => 'Client-Zuordnung';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Füge den Events, die du veröffentlichst, einen Divine-Client-Tag hinzu, damit andere Nostr-Apps sie korrekt zuordnen können. Ohne ihn wiegen deine Meldungen weniger, wenn unsere Moderatoren sie prüfen.';

  @override
  String get nostrSettingsMoveAccount => 'Konto umziehen';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Lade dein Archiv herunter und verschiebe deine Beiträge und Videos zu einem anderen Relay oder Medienserver.';

  @override
  String get nostrSettingsRemoveKeys => 'Schlüssel vom Gerät entfernen';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Lösch deinen privaten Schlüssel nur von diesem Gerät. Deine Inhalte bleiben auf den Relays, aber du brauchst dein nsec-Backup, um wieder auf dein Konto zuzugreifen.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Dieses Konto konnte nicht von diesem Gerät entfernt werden. Versuch es nochmal.';

  @override
  String get nostrSettingsDeleteAccount => 'Konto und Daten löschen';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Sendet Löschanfragen für deine Inhalte und meldet dich auf diesem Gerät ab. Relays, Clients, Suchindizes und andere angemeldete Geräte behalten möglicherweise Kopien.';

  @override
  String get relayDiagnosticTitle => 'Relay-Diagnose';

  @override
  String get relayDiagnosticRefreshTooltip => 'Diagnose aktualisieren';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Letzte Aktualisierung: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relay-Status';

  @override
  String get relayDiagnosticInitialized => 'Initialisiert';

  @override
  String get relayDiagnosticReady => 'Bereit';

  @override
  String get relayDiagnosticNotInitialized => 'Nicht initialisiert';

  @override
  String get relayDiagnosticDatabaseEvents => 'Datenbank-Events';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Aktive Abonnements';

  @override
  String get relayDiagnosticExternalRelays => 'Externe Relays';

  @override
  String get relayDiagnosticConfigured => 'Konfiguriert';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count Relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Verbunden';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video-Events';

  @override
  String get relayDiagnosticHomeFeed => 'Home-Feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count Videos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Discovery';

  @override
  String get relayDiagnosticLoading => 'Wird geladen';

  @override
  String get relayDiagnosticYes => 'Ja';

  @override
  String get relayDiagnosticNo => 'Nein';

  @override
  String get relayDiagnosticTestDirectQuery => 'Direkte Abfrage testen';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Netzwerkkonnektivität';

  @override
  String get relayDiagnosticRunNetworkTest => 'Netzwerktest starten';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom-Server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Alle Endpoints testen';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Fehler';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake-API';

  @override
  String get relayDiagnosticBaseUrl => 'Basis-URL';

  @override
  String get relayDiagnosticSummary => 'Zusammenfassung';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (Durchschn. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Alle erneut testen';

  @override
  String get relayDiagnosticRetrying => 'Wird erneut versucht...';

  @override
  String get relayDiagnosticRetryConnection => 'Verbindung erneut versuchen';

  @override
  String get relayDiagnosticTroubleshooting => 'Fehlerbehebung';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Grüner Status = Verbunden und funktioniert\n• Roter Status = Verbindung fehlgeschlagen\n• Wenn der Netzwerktest fehlschlägt, prüf deine Internetverbindung\n• Wenn Relays konfiguriert, aber nicht verbunden sind, tippe auf \"Verbindung erneut versuchen\"\n• Mach einen Screenshot dieses Screens zum Debuggen';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Alle REST-Endpoints funktionieren!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Einige REST-Endpoints sind fehlgeschlagen - siehe Details oben';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '$count Video-Events in der Datenbank gefunden';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'Abfrage fehlgeschlagen. Bitte versuch es nochmal.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Mit $count Relay(s) verbunden!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Verbindung zu Relays fehlgeschlagen';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Verbindungsversuch fehlgeschlagen. Bitte versuch es nochmal.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Verbunden & Authentifiziert';

  @override
  String get relayDiagnosticConnectedOnly => 'Verbunden';

  @override
  String get relayDiagnosticNotConnected => 'Nicht verbunden';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Keine Relays konfiguriert';

  @override
  String get relayDiagnosticFailed => 'Fehlgeschlagen';

  @override
  String get notificationSettingsTitle => 'Benachrichtigungen';

  @override
  String get notificationSettingsResetTooltip => 'Auf Standard zurücksetzen';

  @override
  String get notificationSettingsTypes => 'Benachrichtigungstypen';

  @override
  String get notificationSettingsLikes => 'Likes';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Wenn jemand deine Videos likest';

  @override
  String get notificationSettingsComments => 'Kommentare';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Wenn jemand deine Videos kommentiert';

  @override
  String get notificationSettingsFollows => 'Follower';

  @override
  String get notificationSettingsFollowsSubtitle => 'Wenn dir jemand folgt';

  @override
  String get notificationSettingsMentions => 'Erwähnungen';

  @override
  String get notificationSettingsMentionsSubtitle => 'Wenn du erwähnt wirst';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Wenn jemand deine Videos repostet';

  @override
  String get notificationSettingsNewPosts => 'Neue Vines';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Wenn jemand, den du beobachtest, postet';

  @override
  String get notificationSettingsActions => 'Aktionen';

  @override
  String get notificationSettingsMarkAllAsRead => 'Alle als gelesen markieren';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Alle Benachrichtigungen als gelesen markieren';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Alle Benachrichtigungen als gelesen markiert';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Konnten nicht alle als gelesen markiert werden';

  @override
  String get notificationSettingsResetToDefaults =>
      'Einstellungen auf Standard zurückgesetzt';

  @override
  String get notificationSettingsAbout => 'Über Benachrichtigungen';

  @override
  String get notificationSettingsAboutDescription =>
      'Benachrichtigungen werden über das Nostr-Protokoll bereitgestellt. Echtzeit-Updates hängen von deiner Verbindung zu den Nostr-Relays ab. Manche Benachrichtigungen können verzögert sein.';

  @override
  String get safetySettingsWhatYouSee => 'WAS DU SIEHST';

  @override
  String get safetySettingsWhatYouPublish => 'WAS DU VERÖFFENTLICHST';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Nur Divine-gehostete Videos anzeigen';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Videos von anderen Medien-Hosts ausblenden';

  @override
  String get safetySettingsModeration => 'MODERATION';

  @override
  String get safetySettingsBlockedUsers => 'BLOCKIERTE NUTZER';

  @override
  String get safetySettingsAgeVerification => 'ALTERSVERIFIZIERUNG';

  @override
  String get safetySettingsAgeConfirmation =>
      'Ich bestätige, dass ich 18 Jahre oder älter bin';

  @override
  String get safetySettingsAgeRequired =>
      'Erforderlich, um Inhalte für Erwachsene zu sehen';

  @override
  String get safetySettingsAgeLockedForMinor => 'Für dein Konto gesperrt';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Offizieller Moderationsdienst (standardmäßig aktiv)';

  @override
  String get safetySettingsPeopleIFollow => 'Leute, denen ich folge';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Labels von Leuten abonnieren, denen du folgst';

  @override
  String get safetySettingsAddCustomLabeler => 'Eigenen Labeler hinzufügen';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub eingeben...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Eigenen Labeler hinzufügen';

  @override
  String get safetySettingsRemoveLabeler => 'Labeler entfernen';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'npub-Adresse eingeben';

  @override
  String get safetySettingsNoBlockedUsers => 'Keine blockierten Nutzer';

  @override
  String get safetySettingsUnblock => 'Entsperren';

  @override
  String get safetySettingsUserUnblocked => 'Nutzer entsperrt';

  @override
  String get safetySettingsCancel => 'Abbrechen';

  @override
  String get safetySettingsAdd => 'Hinzufügen';

  @override
  String get analyticsTitle => 'Creator-Analytics';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnose';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Diagnose umschalten';

  @override
  String get analyticsRetry => 'Erneut versuchen';

  @override
  String get analyticsUnableToLoad => 'Analytics konnten nicht geladen werden.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Melde dich an, um Creator-Analytics zu sehen.';

  @override
  String get analyticsViewDataUnavailable =>
      'Aufrufe sind für diese Beiträge derzeit nicht vom Relay verfügbar. Like-, Kommentar- und Repost-Metriken sind trotzdem korrekt.';

  @override
  String get analyticsViewDataTitle => 'Aufrufdaten';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Aktualisiert $time • Scores nutzen Likes, Kommentare, Reposts und Aufrufe/Loops von Funnelcake, sofern verfügbar.';
  }

  @override
  String get analyticsVideos => 'Videos';

  @override
  String get analyticsViews => 'Aufrufe';

  @override
  String get analyticsInteractions => 'Interaktionen';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Follower';

  @override
  String get analyticsAvgPerPost => 'Ø/Beitrag';

  @override
  String get analyticsInteractionMix => 'Interaktions-Mix';

  @override
  String get analyticsLikes => 'Likes';

  @override
  String get analyticsComments => 'Kommentare';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Performance-Highlights';

  @override
  String get analyticsMostViewed => 'Meistgesehen';

  @override
  String get analyticsMostDiscussed => 'Meistdiskutiert';

  @override
  String get analyticsMostReposted => 'Meistrepostet';

  @override
  String get analyticsNoVideosYet => 'Noch keine Videos';

  @override
  String get analyticsViewDataUnavailableShort => 'Aufrufdaten nicht verfügbar';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count Aufrufe';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count Kommentare';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count Reposts';
  }

  @override
  String get analyticsTopContent => 'Top-Inhalte';

  @override
  String get analyticsPublishPrompt =>
      'Veröffentliche ein paar Videos, um Rankings zu sehen.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Rechts in % = Engagement-Rate (Interaktionen geteilt durch Aufrufe).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Die Engagement-Rate braucht Aufrufdaten; Werte erscheinen als N/V, bis Aufrufe verfügbar sind.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'Aufrufe nicht verfügbar';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count Interaktionen';
  }

  @override
  String get analyticsPostAnalytics => 'Beitrags-Analytics';

  @override
  String get analyticsOpenPost => 'Beitrag öffnen';

  @override
  String get analyticsRecentDailyInteractions =>
      'Tägliche Interaktionen der letzten Zeit';

  @override
  String get analyticsNoActivityYet =>
      'Noch keine Aktivität in diesem Zeitraum.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interaktionen = Likes + Kommentare + Reposts nach Beitragsdatum.';

  @override
  String get analyticsDailyBarExplainer =>
      'Balkenlänge ist relativ zu deinem besten Tag in diesem Zeitraum.';

  @override
  String get analyticsAudienceSnapshot => 'Publikums-Snapshot';

  @override
  String analyticsFollowersCount(String count) {
    return 'Follower: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Folgt: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Publikums-Aufschlüsselungen nach Quelle/Geo/Zeit werden verfügbar, sobald Funnelcake Publikums-Analytics-Endpoints hinzufügt.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Retention-Kurve und Wiedergabezeit-Aufschlüsselung erscheinen, sobald Retention pro Sekunde/Bucket von Funnelcake verfügbar ist.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retention-Daten nicht verfügbar, bis Aufruf- und Wiedergabezeit-Analytics von Funnelcake zurückgegeben werden.';

  @override
  String get analyticsDiagnostics => 'Diagnose';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Videos insgesamt: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Mit Aufrufen: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Ohne Aufrufe: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydriert (Bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydriert (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Quellen: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Fixture-Daten verwenden';

  @override
  String get analyticsNa => 'N/V';

  @override
  String get authCreateNewAccount => 'Neues Divine-Konto erstellen';

  @override
  String get authCreateNewAccountShort => 'Neues Konto erstellen';

  @override
  String get authSignInDifferentAccount => 'Mit anderem Konto anmelden';

  @override
  String get authUseAnotherAccount => 'Anderes Konto verwenden';

  @override
  String authContinueAs(String displayName) {
    return 'Weiter als $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Deine Entwürfe und Clips sind für dieses Konto gespeichert';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Hier anmelden verbirgt diese Entwürfe und Clips';

  @override
  String get authTermsPrefix =>
      'Mit einer Auswahl unten bestätigst du, dass du mindestens 16 Jahre alt bist (oder die ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine-Altersfreigabe';

  @override
  String get authTermsAfterAgeAuthorization =>
      ' abgeschlossen hast) und akzeptierst die ';

  @override
  String get authTermsOfService => 'Nutzungsbedingungen';

  @override
  String get authPrivacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get authTermsAnd => ' und ';

  @override
  String get authSafetyStandards => 'Sicherheitsstandards';

  @override
  String get authAmberNotInstalled => 'Amber-App ist nicht installiert';

  @override
  String get authAmberConnectionFailed => 'Verbindung zu Amber fehlgeschlagen';

  @override
  String get authPasswordResetSent =>
      'Wenn ein Konto mit dieser E-Mail existiert, wurde ein Link zum Passwort-Zurücksetzen gesendet.';

  @override
  String get authSignInTitle => 'Anmelden';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authConfirmPasswordLabel => 'Passwort bestätigen';

  @override
  String get authEmailRequired => 'E-Mail ist erforderlich';

  @override
  String get authEmailInvalid => 'Bitte gib eine gültige E-Mail-Adresse ein';

  @override
  String get authPasswordRequired => 'Passwort ist erforderlich';

  @override
  String get authConfirmPasswordRequired => 'Bitte bestätige dein Passwort';

  @override
  String get authPasswordsDoNotMatch => 'Passwörter stimmen nicht überein';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authImportNostrKey => 'Nostr-Schlüssel importieren';

  @override
  String get authConnectSignerApp => 'Mit einer Signer-App verbinden';

  @override
  String get authSignInWithAmber => 'Mit Amber anmelden';

  @override
  String get authSignInWithBrowserExtension =>
      'Mit Browser-Erweiterung anmelden';

  @override
  String get authNip07ConnectionFailed =>
      'Verbindung zur Browser-Erweiterung fehlgeschlagen.';

  @override
  String get authNip07ExtensionNotFound =>
      'Keine Browser-Erweiterung gefunden. Installiere Alby, nos2x oder eine andere NIP-07-kompatible Erweiterung.';

  @override
  String get authSignInOptionsTitle => 'Anmeldeoptionen';

  @override
  String get authInfoEmailPasswordTitle => 'E-Mail & Passwort';

  @override
  String get authInfoEmailPasswordDescription =>
      'Melde dich mit deinem Divine-Konto an. Wenn du dich mit einer E-Mail und einem Passwort registriert hast, nutze sie hier.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Du hast bereits eine Nostr-Identität? Importiere deinen nsec-Privatschlüssel von einem anderen Client.';

  @override
  String get authInfoSignerAppTitle => 'Signer-App';

  @override
  String get authInfoSignerAppDescription =>
      'Verbinde dich mit einem NIP-46-kompatiblen Remote-Signer wie nsecBunker für verbesserte Schlüsselsicherheit.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Nutze die Amber-Signer-App auf Android, um deine Nostr-Schlüssel sicher zu verwalten.';

  @override
  String get authInfoBrowserExtensionTitle => 'Browser-Erweiterung';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Melde dich mit einer NIP-07-Browser-Erweiterung wie Alby oder nos2x an. Deine Schlüssel bleiben in der Erweiterung — Divine sieht sie nie.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Falsche E-Mail oder falsches Passwort. Versuch es noch mal.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Bestätige deine E-Mail, bevor du dich anmeldest – schau in deinem Posteingang nach dem Link.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Das sieht nicht nach einer gültigen E-Mail-Adresse aus.';

  @override
  String get authSignInErrorNetwork =>
      'Server nicht erreichbar. Prüf deine Verbindung und versuch es noch mal.';

  @override
  String get authSignInErrorGeneric =>
      'Etwas ist schiefgelaufen. Bitte versuch es noch mal.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Nicht sicher, wie du letztes Mal reingekommen bist? ';

  @override
  String get authSignInOptionsHintCta => 'Alle Anmeldeoptionen ansehen';

  @override
  String get authCreateAccountTitle => 'Konto erstellen';

  @override
  String get authBackToInviteCode => 'Zurück zum Einladungscode';

  @override
  String get authUseDivineNoBackup => 'Divine ohne Backup verwenden';

  @override
  String get authSkipConfirmTitle => 'Noch eine Sache...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Du bist drin! Wir erstellen einen sicheren Schlüssel, der dein Divine-Konto antreibt.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Ohne E-Mail ist dein Schlüssel der einzige Weg, wie Divine weiß, dass dieses Konto dir gehört.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Du kannst in der App auf deinen Schlüssel zugreifen, aber wenn du nicht technisch versiert bist, empfehlen wir, jetzt eine E-Mail und ein Passwort hinzuzufügen. Damit ist es einfacher, dich anzumelden und dein Konto wiederherzustellen, wenn du dieses Gerät verlierst oder zurücksetzt.';

  @override
  String get authAddEmailPassword => 'E-Mail & Passwort hinzufügen';

  @override
  String get authUseThisDeviceOnly => 'Nur dieses Gerät verwenden';

  @override
  String get authCompleteRegistration => 'Registrierung abschließen';

  @override
  String get authVerifying => 'Wird verifiziert...';

  @override
  String get authVerificationLinkSent =>
      'Wir haben einen Verifizierungslink gesendet an:';

  @override
  String get authClickVerificationLink =>
      'Bitte klick auf den Link in deiner E-Mail, um\ndie Registrierung abzuschließen.';

  @override
  String get authPleaseWaitVerifying =>
      'Bitte warte, während wir deine E-Mail verifizieren...';

  @override
  String get authWaitingForVerification => 'Warten auf Verifizierung';

  @override
  String get authOpenEmailApp => 'E-Mail-App öffnen';

  @override
  String get authVerificationPinPrompt =>
      'Oder gib den 6-stelligen Code aus deiner E-Mail ein';

  @override
  String get authVerificationPinFieldLabel => '6-stelliger Code';

  @override
  String get authVerificationPinSubmit => 'Code verifizieren';

  @override
  String get authVerificationResendPrompt => 'Nichts bekommen?';

  @override
  String get authVerificationResend => 'Erneut senden';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Erneut senden in $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Wir konnten die E-Mail nicht erneut senden. Versuch es noch mal.';

  @override
  String get authVerificationResendExpired =>
      'Diese Anmeldung ist abgelaufen. Fang neu an, um einen frischen Code zu bekommen.';

  @override
  String get authVerificationResendUnavailable =>
      'Erneut senden geht gerade nicht. Nimm den 6-stelligen Code aus der E-Mail, die wir dir schon geschickt haben.';

  @override
  String get authVerificationPollingStopped =>
      'Wir prüfen nicht mehr automatisch. Gib den 6-stelligen Code aus deiner E-Mail ein, um die Anmeldung abzuschließen.';

  @override
  String get authWelcomeToDivine => 'Willkommen bei Divine!';

  @override
  String get authEmailVerified => 'Deine E-Mail wurde verifiziert.';

  @override
  String get authSigningYouIn => 'Du wirst angemeldet';

  @override
  String get authErrorTitle => 'Hoppla.';

  @override
  String get authVerificationFailed =>
      'Wir konnten deine E-Mail nicht verifizieren.\nBitte versuch es nochmal.';

  @override
  String get authStartOver => 'Von vorne anfangen';

  @override
  String get authEmailVerifiedLogin =>
      'E-Mail verifiziert! Bitte melde dich an, um fortzufahren.';

  @override
  String get authVerificationLinkExpired =>
      'Dieser Verifizierungslink ist nicht mehr gültig.';

  @override
  String get authVerificationConnectionError =>
      'E-Mail konnte nicht verifiziert werden. Bitte prüf deine Verbindung und versuch es nochmal.';

  @override
  String get authWaitlistConfirmTitle => 'Du bist drin!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Wir schicken Updates an $email.\nSobald mehr Einladungscodes verfügbar sind, bekommst du welche.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Erneut versuchen';

  @override
  String get authContactSupport => 'Support kontaktieren';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email konnte nicht geöffnet werden';
  }

  @override
  String get authAddInviteCode => 'Einladungscode hinzufügen';

  @override
  String get authInviteCodeLabel => 'Einladungscode';

  @override
  String get authEnterYourCode => 'Gib deinen Code ein';

  @override
  String get authNext => 'Weiter';

  @override
  String get authJoinWaitlist => 'Auf Warteliste';

  @override
  String get authJoinWaitlistTitle => 'Auf die Warteliste';

  @override
  String get authJoinWaitlistDescription =>
      'Teile deine E-Mail und wir schicken Updates, sobald Zugang frei wird.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Schick mir Divine-Inspiration';

  @override
  String get authInviteAccessHelp => 'Hilfe zum Einladungszugang';

  @override
  String get authGeneratingConnection => 'Verbindung wird erstellt...';

  @override
  String get authConnectedAuthenticating =>
      'Verbunden! Authentifizierung läuft...';

  @override
  String get authConnectionTimedOut => 'Verbindung abgelaufen';

  @override
  String get authApproveConnection =>
      'Stell sicher, dass du die Verbindung in deiner Signer-App bestätigt hast.';

  @override
  String get authConnectionCancelled => 'Verbindung abgebrochen';

  @override
  String get authConnectionCancelledMessage =>
      'Die Verbindung wurde abgebrochen.';

  @override
  String get authConnectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get authUnknownError => 'Ein unbekannter Fehler ist aufgetreten.';

  @override
  String get authNostrConnectStartFailed =>
      'Die Signer-App ist nicht erreichbar. Prüf deine Verbindung und versuch es nochmal.';

  @override
  String get authNostrConnectInvalidSession =>
      'Dieser Verbindungslink ist nicht mehr gültig. Starte einen neuen.';

  @override
  String get authNostrConnectSetupFailed =>
      'Fast geschafft — wir konnten dich nicht ganz anmelden. Versuch es nochmal.';

  @override
  String get authUrlCopied => 'URL in die Zwischenablage kopiert';

  @override
  String get authConnectToDivine => 'Mit Divine verbinden';

  @override
  String get authPasteBunkerUrl => 'bunker://-URL einfügen';

  @override
  String get authBunkerUrlHint => 'bunker://-URL';

  @override
  String get authInvalidBunkerUrl =>
      'Ungültige Bunker-URL. Sie sollte mit bunker:// beginnen';

  @override
  String get authScanSignerApp =>
      'Scanne mit deiner\nSigner-App, um zu verbinden.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Warte auf Verbindung... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'URL kopieren';

  @override
  String get authShare => 'Teilen';

  @override
  String get authAddBunker => 'Bunker hinzufügen';

  @override
  String get authCompatibleSignerApps => 'Kompatible Signer-Apps';

  @override
  String get authFailedToConnect => 'Verbindung fehlgeschlagen';

  @override
  String get authResetPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get authResetPasswordSubtitle =>
      'Bitte gib dein neues Passwort ein. Es muss mindestens 8 Zeichen lang sein.';

  @override
  String get authNewPasswordLabel => 'Neues Passwort';

  @override
  String get authConfirmNewPasswordLabel => 'Neues Passwort bestätigen';

  @override
  String get authPasswordTooShort =>
      'Passwort muss mindestens 8 Zeichen lang sein';

  @override
  String get authPasswordResetSuccess =>
      'Passwort erfolgreich zurückgesetzt. Bitte melde dich an.';

  @override
  String get authPasswordResetFailed => 'Passwort-Zurücksetzen fehlgeschlagen';

  @override
  String get authUnexpectedError =>
      'Ein unerwarteter Fehler ist aufgetreten. Bitte versuch es nochmal.';

  @override
  String get authUpdatePassword => 'Passwort aktualisieren';

  @override
  String get authSecureAccountTitle => 'Konto absichern';

  @override
  String get authUnableToAccessKeys =>
      'Zugriff auf deine Schlüssel nicht möglich. Bitte versuch es nochmal.';

  @override
  String get authRegistrationFailed => 'Registrierung fehlgeschlagen';

  @override
  String get authRegistrationComplete =>
      'Registrierung abgeschlossen. Bitte prüf deine E-Mails.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'Reset-E-Mail konnte nicht gesendet werden.';

  @override
  String get authSending => 'Wird gesendet...';

  @override
  String get authSignInButton => 'Anmelden';

  @override
  String get authVerificationErrorTimeout =>
      'Verifizierung abgelaufen. Bitte registriere dich erneut.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verifizierung fehlgeschlagen — Autorisierungscode fehlt.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verifizierung fehlgeschlagen. Bitte versuch es nochmal.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Netzwerkfehler bei der Anmeldung. Bitte versuch es nochmal.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verifizierung fehlgeschlagen. Bitte registriere dich erneut.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuch es mit einer manuellen Anmeldung.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Diese E-Mail ist bereits registriert. Melde dich stattdessen an.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Dieser Code stimmt nicht. Prüfe ihn noch mal und versuch es erneut.';

  @override
  String get authVerificationErrorPinExpired =>
      'Dieser Code ist abgelaufen. Tippe auf Erneut senden, um einen neuen zu bekommen.';

  @override
  String get authVerificationErrorPinLocked =>
      'Zu viele Versuche. Tippe auf Erneut senden, um einen neuen Code zu bekommen.';

  @override
  String get authVerificationErrorPinFailed =>
      'Wir konnten diesen Code nicht verifizieren. Bitte versuch es erneut.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Die Code-Eingabe ist gerade nicht verfügbar. Tippe auf den Link in deiner E-Mail oder sende erneut, um einen neuen zu bekommen.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Gib einen Einladungscode wie ABCD-EFGH ein.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Dieser Einladungscode sieht nicht gültig aus.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Dieser Einladungscode wurde bereits verwendet oder widerrufen.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Die Einladungen dieses Creators sind aufgebraucht';

  @override
  String get authInviteGateErrorUnavailable =>
      'Dieser Einladungscode ist nicht verfügbar. Trag dich in die Warteliste ein und wir schicken dir eine Einladung, sobald wieder Platz ist.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Wir konnten diesen Code nicht prüfen. Versuch es noch mal.';

  @override
  String get authInviteGateErrorUnknown =>
      'Etwas ist schiefgelaufen. Versuch es noch mal mit deinem Einladungscode.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Dieser Einladungscode ist nicht mehr verfügbar. Geh zurück zu deinem Einladungscode, tritt der Warteliste bei oder kontaktier den Support.';

  @override
  String get authInviteErrorInvalid =>
      'Dieser Einladungscode kann derzeit nicht verwendet werden. Geh zurück zu deinem Einladungscode, tritt der Warteliste bei oder kontaktier den Support.';

  @override
  String get authInviteErrorTemporary =>
      'Wir konnten deine Einladung gerade nicht bestätigen. Geh zurück zu deinem Einladungscode und versuch es nochmal oder kontaktier den Support.';

  @override
  String get authInviteErrorUnknown =>
      'Wir konnten deine Einladung nicht aktivieren. Geh zurück zu deinem Einladungscode, tritt der Warteliste bei oder kontaktier den Support.';

  @override
  String get shareSheetSave => 'Speichern';

  @override
  String get shareSheetRemoveFromSaved => 'Lesezeichen entfernen';

  @override
  String get shareSheetSaveToGallery => 'In Galerie speichern';

  @override
  String get shareSheetSaveWithWatermark => 'Mit Wasserzeichen speichern';

  @override
  String get shareSheetSaveVideo => 'Video speichern';

  @override
  String get shareSheetAddToClips => 'Zu Clips hinzufügen';

  @override
  String get shareSheetNameClipTitle => 'Diesen Clip benennen';

  @override
  String get shareSheetNameClipSubtitle =>
      'Wähle einen Namen, den du in deiner Bibliothek wiedererkennst.';

  @override
  String get shareSheetClipTitleLabel => 'Clip-Titel';

  @override
  String get shareSheetSaveClip => 'Clip speichern';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '„$title“ in Clips gespeichert';
  }

  @override
  String get shareSheetUntitledClip => 'Clip ohne Titel';

  @override
  String get shareSheetAddToClipsFailed => 'Konnte nicht zu Clips hinzufügen';

  @override
  String get shareSheetAddToList => 'Zur Liste hinzufügen';

  @override
  String get shareSheetCopy => 'Kopieren';

  @override
  String get shareSheetShareVia => 'Teilen via';

  @override
  String get shareSheetEventJson => 'Event-JSON';

  @override
  String get shareSheetEventId => 'Event-ID';

  @override
  String get shareSheetMoreActions => 'Weitere Aktionen';

  @override
  String get shareSheetCrosspost => 'Crossposten';

  @override
  String get crosspostSheetTitle => 'Dieses Video crossposten';

  @override
  String get crosspostSheetSubtitle =>
      'Schick es an deine verbundenen Plattformen. Das Posten kann ein paar Minuten dauern.';

  @override
  String get crosspostSubmit => 'Crossposten';

  @override
  String get crosspostStatusQueued => 'In Warteschlange';

  @override
  String get crosspostStatusUploading => 'Wird hochgeladen';

  @override
  String get crosspostStatusProcessing => 'Wird verarbeitet';

  @override
  String get crosspostStatusPosted => 'Veröffentlicht';

  @override
  String get crosspostStatusFailed => 'Fehlgeschlagen';

  @override
  String get crosspostStatusSkipped => 'Übersprungen';

  @override
  String get crosspostStatusNeedsReauth => 'Neu verbinden nötig';

  @override
  String get crosspostViewPost => 'Beitrag ansehen';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Verbinde $platform in den Crossposting-Einstellungen neu, um weiter zu posten.';
  }

  @override
  String get crosspostReconnect => 'Neu verbinden';

  @override
  String get crosspostErrorNotOwner =>
      'Nur deine eigenen Videos können gecrosspostet werden.';

  @override
  String get crosspostErrorNotEligible =>
      'Dieses Video ist nicht zum Crossposten geeignet.';

  @override
  String get crosspostErrorNotConnected =>
      'Diese Plattform ist nicht verbunden.';

  @override
  String get crosspostErrorUnauthorized =>
      'Verbinde dein Konto neu und versuch es dann erneut.';

  @override
  String get crosspostErrorNetwork =>
      'Der Crossposter ist nicht erreichbar. Versuch es gleich noch mal.';

  @override
  String get crosspostFailedGeneric => 'Crosspost fehlgeschlagen.';

  @override
  String get crosspostStillWorking =>
      'Läuft noch. Du kannst das hier schließen – das Posten geht im Hintergrund weiter.';

  @override
  String get crosspostDone => 'Fertig';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'In Aufnahmen gespeichert';

  @override
  String get watermarkDownloadShare => 'Teilen';

  @override
  String get watermarkDownloadDone => 'Fertig';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Fotozugriff erforderlich';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Um Videos zu speichern, erlaube den Fotozugriff in den Einstellungen.';

  @override
  String get watermarkDownloadOpenSettings => 'Einstellungen öffnen';

  @override
  String get watermarkDownloadNotNow => 'Nicht jetzt';

  @override
  String get watermarkDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get watermarkDownloadDismiss => 'Schließen';

  @override
  String get watermarkDownloadStageDownloading => 'Video wird heruntergeladen';

  @override
  String get watermarkDownloadStageWatermarking =>
      'Wasserzeichen wird hinzugefügt';

  @override
  String get watermarkDownloadStageSaving => 'Speichern in Aufnahmen';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Video wird aus dem Netzwerk geladen...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine-Wasserzeichen wird angewendet...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Video mit Wasserzeichen wird in deinen Aufnahmen gespeichert...';

  @override
  String get shareMenuBookmarks => 'Lesezeichen';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count Follow-Sets verfügbar';
  }

  @override
  String get peopleListsAddToList => 'Zur Liste hinzufügen';

  @override
  String get peopleListsSheetTitle => 'Zur Liste hinzufügen';

  @override
  String get peopleListsEmptyTitle => 'Noch keine Listen';

  @override
  String get peopleListsEmptySubtitle =>
      'Erstelle eine Liste, um Personen zu gruppieren.';

  @override
  String get peopleListsCreateList => 'Liste erstellen';

  @override
  String get peopleListsNewListTitle => 'Neue Liste';

  @override
  String get peopleListsRouteTitle => 'Personenliste';

  @override
  String get peopleListsListNameLabel => 'Listenname';

  @override
  String get peopleListsListNameHint => 'Enge Freunde';

  @override
  String get peopleListsCreateButton => 'Erstellen';

  @override
  String get peopleListsAddPeopleTitle => 'Personen hinzufügen';

  @override
  String get peopleListsAddPeopleTooltip => 'Personen hinzufügen';

  @override
  String get peopleListsAddPeopleSemanticLabel =>
      'Personen zur Liste hinzufügen';

  @override
  String get peopleListsListNotFoundTitle => 'Liste nicht gefunden';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Liste nicht gefunden. Sie wurde möglicherweise gelöscht.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Diese Liste wurde möglicherweise gelöscht.';

  @override
  String get peopleListsNoPeopleTitle => 'Keine Personen in dieser Liste';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'Füge Personen hinzu, um loszulegen';

  @override
  String get peopleListsNoVideosTitle => 'Noch keine Videos';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Videos von Listenmitgliedern erscheinen hier';

  @override
  String get peopleListsNoVideosAvailable => 'Keine Videos verfügbar';

  @override
  String get peopleListsFailedToLoadVideos =>
      'Videos konnten nicht geladen werden';

  @override
  String get peopleListsVideoNotAvailable => 'Video nicht verfügbar';

  @override
  String get peopleListsBackToGridTooltip => 'Zurück zum Raster';

  @override
  String get peopleListsErrorLoadingVideos => 'Fehler beim Laden der Videos';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Keine Personen zum Hinzufügen verfügbar.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Zu $name hinzufügen';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Personen suchen';

  @override
  String get peopleListsAddPeopleError =>
      'Personen konnten nicht geladen werden. Bitte versuche es erneut.';

  @override
  String get peopleListsAddPeopleRetry => 'Erneut versuchen';

  @override
  String get peopleListsAddButton => 'Hinzufügen';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count hinzufügen';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count Listen',
      one: 'In 1 Liste',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$name entfernen?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Sie werden aus dieser Liste entfernt.';

  @override
  String get peopleListsRemove => 'Entfernen';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name aus Liste entfernt';
  }

  @override
  String get peopleListsUndo => 'Rückgängig';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil von $name. Gedrückt halten zum Entfernen.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Profil von $name anzeigen';
  }

  @override
  String get shareMenuEditVideo => 'Video bearbeiten';

  @override
  String get shareMenuDeleteVideo => 'Video löschen';

  @override
  String shareMenuVideoCount(int count) {
    return '$count Videos';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Dadurch wird dieses Video dauerhaft aus Divine gelöscht. Es kann weiterhin in Nostr-Clients von Drittanbietern erscheinen, die andere Relays verwenden.';

  @override
  String get shareMenuCancel => 'Abbrechen';

  @override
  String get shareMenuDelete => 'Löschen';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Löschen ist noch nicht bereit. Versuch es gleich noch einmal.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Du kannst nur deine eigenen Videos löschen.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Melde dich erneut an und versuch es nochmal.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Die Löschanfrage konnte nicht signiert werden. Versuch es nochmal.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Das Relay hat diese Löschanfrage nicht angenommen. Versuch es gleich noch einmal.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Das Relay war nicht erreichbar. Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Gelöscht. Nicht alle Relays haben bestätigt, es kann also noch in anderen Apps auftauchen.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Dieses Video konnte nicht gelöscht werden. Versuch es nochmal.';

  @override
  String get shareMenuUpdate => 'Aktualisieren';

  @override
  String get shareMenuChangeCover => 'Cover ändern';

  @override
  String get shareMenuVideoUpdated => 'Video erfolgreich aktualisiert';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitwirkenden-Einladungen wurden nicht gesendet.',
      one: '1 Mitwirkenden-Einladung wurde nicht gesendet.',
    );
    return 'Video aktualisiert, aber $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Melde dich neu an und versuch es dann nochmal.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Dieses Video hat keine abspielbare Quelle und kann nicht bearbeitet werden.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Die Änderung konnte nicht signiert werden. Versuch es nochmal.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Das Relay hat die Änderung nicht angenommen. Versuch es gleich nochmal.';

  @override
  String get videoUpdateErrorGeneric =>
      'Dieses Video konnte nicht aktualisiert werden. Versuch es nochmal.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Video löschen?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Video wird entfernt…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Video gelöscht.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Video gelöscht. Es kann etwas dauern, bis es überall verschwindet.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Video gelöscht, aber wir konnten nicht jede Kopie entfernen. Kontaktiere bitte den Support.';

  @override
  String get authSessionExpired =>
      'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuch es nochmal.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Web-Authentifizierung wird im sicheren Modus nicht unterstützt. Bitte nutze die mobile App für sichere Schlüsselverwaltung.';

  @override
  String get webAuthEnterBunkerUri => 'Bitte gib eine Bunker-URI ein';

  @override
  String get webAuthConnectTitle => 'Mit Divine verbinden';

  @override
  String get webAuthChooseMethod =>
      'Wähle deine bevorzugte Nostr-Authentifizierungsmethode';

  @override
  String get webAuthBrowserExtension => 'Browser-Erweiterung';

  @override
  String get webAuthRecommended => 'EMPFOHLEN';

  @override
  String get webAuthNsecBunker => 'nsec-Bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Mit einem Remote-Signer verbinden';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Aus Zwischenablage einfügen';

  @override
  String get webAuthConnectToBunker => 'Mit Bunker verbinden';

  @override
  String get webAuthNewToNostr => 'Neu bei Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Installiere eine Browser-Erweiterung wie Alby oder nos2x für das einfachste Erlebnis oder nutze nsec-Bunker für sicheres Remote-Signing.';

  @override
  String get soundsTitle => 'Sounds';

  @override
  String get soundsSearchHint => 'Sounds suchen...';

  @override
  String get soundsSearchResults => 'Suchergebnisse';

  @override
  String get soundsNoSoundsFound => 'Keine Sounds gefunden';

  @override
  String get soundsNoSoundsFoundDescription =>
      'Versuch einen anderen Suchbegriff';

  @override
  String get soundsSavedToLibrary => 'In Sounds gespeichert';

  @override
  String get soundsAlreadySavedToLibrary => 'Bereits in Sounds';

  @override
  String get soundsSavedLibraryTitle => 'Meine Sounds';

  @override
  String get soundsSavedEmptyTitle => 'Noch keine gespeicherten Sounds';

  @override
  String get soundsSavedEmptyDescription =>
      'Tippe in einem Video auf Sound verwenden, um ihn hier zu speichern.';

  @override
  String get soundsRemoveSavedSound => 'Sound entfernen';

  @override
  String get savedSoundSaveAction => 'Speichern';

  @override
  String get savedSoundPausePreviewAction => 'Vorschau pausieren';

  @override
  String get savedSoundResumePreviewAction => 'Vorschau fortsetzen';

  @override
  String get savedSoundDetailsSheetTitle => 'Sound-Details';

  @override
  String get savedSoundRemoveConfirmTitle => 'Diesen Sound entfernen?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Er verschwindet aus deiner Bibliothek. Du kannst ihn jederzeit aus einem Video wieder speichern.';

  @override
  String get soundsRemovedFromLibrary => 'Aus Sounds entfernt';

  @override
  String get soundsSaveFailed =>
      'Der Sound konnte nicht gespeichert werden. Versuch es erneut.';

  @override
  String get soundsRemoveFailed =>
      'Der Sound konnte nicht entfernt werden. Versuch es erneut.';

  @override
  String get soundSyncStatusSyncing => 'Deine Sounds werden synchronisiert…';

  @override
  String get soundSyncStatusSynced => 'Sounds sind aktuell';

  @override
  String get soundSyncStatusFailed =>
      'Deine Sounds konnten nicht synchronisiert werden. Wir versuchen es erneut.';

  @override
  String get soundSyncStatusLocked =>
      'Deine synchronisierte Bibliothek lässt sich auf diesem Gerät nicht entsperren.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMoreOptions => 'Weitere Optionen';

  @override
  String profileBlockedUser(String name) {
    return '$name blockiert';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name entsperrt';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name entfolgt';
  }

  @override
  String get profileFeedError =>
      'Server nicht erreichbar. Prüf deine Verbindung und versuch es noch mal.';

  @override
  String get profileFeedLoadMoreError =>
      'Weitere Videos konnten nicht geladen werden. Zieh nach unten zum Aktualisieren.';

  @override
  String get notificationsTabAll => 'Alle';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Kommentare';

  @override
  String get notificationsTabFollows => 'Follower';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad =>
      'Benachrichtigungen konnten nicht geladen werden';

  @override
  String get notificationsRetry => 'Erneut versuchen';

  @override
  String get notificationsRefreshError =>
      'Aktualisierung fehlgeschlagen – Vorhandenes wird angezeigt';

  @override
  String get notificationsUnreadPrefix => 'Ungelesene Benachrichtigung';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ungelesene Benachrichtigungen',
      one: '1 ungelesene Benachrichtigung',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Profil von $displayName öffnen';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Profile öffnen';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Videovorschaubild für $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Videovorschaubild';

  @override
  String get notificationsInviteSingular =>
      'Du hast 1 Einladung, die du mit einem Freund teilen kannst!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Du hast $count Einladungen, die du mit Freunden teilen kannst!';
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
  String get notificationsVideoUnavailable => 'Video nicht verfügbar';

  @override
  String get feedFailedToLoadVideos => 'Videos konnten nicht geladen werden';

  @override
  String get feedRetry => 'Erneut versuchen';

  @override
  String get feedNoFollowedUsers =>
      'Keine abonnierten Nutzer.\nFolge jemandem, um hier seine Videos zu sehen.';

  @override
  String get feedModeForYou => 'Für dich';

  @override
  String get feedModeNew => 'Neu';

  @override
  String get feedModeFollowing => 'Abonniert';

  @override
  String get feedModeClassics => 'Klassiker';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Feed-Modus: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Urheber des Videos: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar des Urhebers';

  @override
  String get feedForYouEmpty =>
      'Dein Für-dich-Feed ist leer.\nEntdecke Videos und folge Creator:innen, um ihn zu personalisieren.';

  @override
  String get feedFollowingEmpty =>
      'Noch keine Videos von Personen, denen du folgst.\nFinde Creator:innen, die dir gefallen, und folge ihnen.';

  @override
  String get feedLatestEmpty =>
      'Noch keine neuen Videos.\nSchau bald wieder vorbei.';

  @override
  String get feedClassicEmpty =>
      'Noch keine Klassiker.\nSchau bald wieder vorbei.';

  @override
  String get feedExploreVideos => 'Videos entdecken';

  @override
  String get feedLoadingMore => 'Weitere Videos werden geladen …';

  @override
  String get feedRefreshed => 'Feed aktualisiert';

  @override
  String get uploadUploadingVideo => 'Video wird hochgeladen';

  @override
  String get postPublishConfirmationTitle => 'In deinem Profil veröffentlicht';

  @override
  String get postPublishConfirmationView => 'Anzeigen';

  @override
  String get postPublishConfirmationShare => 'Teilen';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Vorschaubild des Videos, das du gerade veröffentlicht hast';

  @override
  String get userSearchNoResults => 'Keine Nutzer gefunden';

  @override
  String get userPickerFilterByNameHint => 'Nach Namen filtern...';

  @override
  String get userPickerSearchByNameHint => 'Nach Namen suchen...';

  @override
  String get userPickerClearSearchSemantics => 'Suche löschen';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name bereits hinzugefügt';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name auswählen';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return '$name entfernen';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Deine Crew ist da draußen';

  @override
  String get userPickerEmptyFollowListBody =>
      'Folge Leuten, die zu dir passen. Wenn sie zurückfolgen, könnt ihr zusammenarbeiten.';

  @override
  String get userPickerGoBack => 'Zurück';

  @override
  String get userPickerTypeNameToSearch => 'Name zum Suchen eingeben';

  @override
  String get userPickerUnavailable =>
      'Die Nutzersuche ist nicht verfügbar. Bitte versuche es später erneut.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Suche fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get forgotPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get forgotPasswordDescription =>
      'Gib deine E-Mail-Adresse ein, und wir schicken dir einen Link zum Passwort-Zurücksetzen.';

  @override
  String get forgotPasswordEmailLabel => 'E-Mail-Adresse';

  @override
  String get forgotPasswordCancel => 'Abbrechen';

  @override
  String get forgotPasswordSendLink => 'Reset-Link per E-Mail senden';

  @override
  String get ageVerificationContentWarning => 'Inhaltswarnung';

  @override
  String get ageVerificationTitle => 'Altersverifizierung';

  @override
  String get ageVerificationAdultDescription =>
      'Dieser Inhalt wurde als potenziell für Erwachsene markiert. Du musst 18 Jahre oder älter sein, um ihn zu sehen.';

  @override
  String get ageVerificationCreationDescription =>
      'Um die Kamera zu nutzen und Inhalte zu erstellen, musst du mindestens 16 Jahre alt sein.';

  @override
  String get ageVerificationAdultQuestion => 'Bist du 18 Jahre oder älter?';

  @override
  String get ageVerificationCreationQuestion => 'Bist du 16 Jahre oder älter?';

  @override
  String get ageVerificationNo => 'Nein';

  @override
  String get ageVerificationYes => 'Ja';

  @override
  String get navHome => 'Start';

  @override
  String get navExplore => 'Entdecken';

  @override
  String get navInbox => 'Posteingang';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Mein Profil';

  @override
  String get navNotifications => 'Benachrichtigungen';

  @override
  String get navOpenCamera => 'Kamera öffnen';

  @override
  String get navExploreClassics => 'Klassiker';

  @override
  String get navExploreNewVideos => 'Neue Videos';

  @override
  String get navExploreTrending => 'Angesagt';

  @override
  String get navExploreForYou => 'Für dich';

  @override
  String get navExploreLists => 'Listen';

  @override
  String get routeErrorTitle => 'Fehler';

  @override
  String get routeInvalidHashtag => 'Ungültiger Hashtag';

  @override
  String get routeInvalidConversationId => 'Ungültige Konversations-ID';

  @override
  String get routeInvalidRequestId => 'Ungültige Anfrage-ID';

  @override
  String get routeInvalidListId => 'Ungültige Listen-ID';

  @override
  String get routeInvalidUserId => 'Ungültige Nutzer-ID';

  @override
  String get routeInvalidVideoId => 'Ungültige Video-ID';

  @override
  String get routeInvalidSoundId => 'Ungültige Sound-ID';

  @override
  String get routeInvalidCategory => 'Ungültige Kategorie';

  @override
  String get routeNoVideosToDisplay => 'Keine Videos zum Anzeigen';

  @override
  String get routeGoHome => 'Zur Startseite';

  @override
  String get routeInvalidProfileId => 'Ungültige Profil-ID';

  @override
  String get routeUnknownPath => 'Diese Seite gibt es in der App nicht.';

  @override
  String get routeDefaultListName => 'Liste';

  @override
  String get supportTitle => 'Support-Center';

  @override
  String get supportContactSupport => 'Support kontaktieren';

  @override
  String get supportContactSupportSubtitle =>
      'Konversation starten oder vergangene Nachrichten ansehen';

  @override
  String get supportReportBug => 'Bug melden';

  @override
  String get supportReportBugSubtitle => 'Technische Probleme mit der App';

  @override
  String get supportRequestFeature => 'Feature wünschen';

  @override
  String get supportRequestFeatureSubtitle =>
      'Eine Verbesserung oder ein neues Feature vorschlagen';

  @override
  String get supportSaveLogs => 'Logs speichern';

  @override
  String get supportSaveLogsSubtitle =>
      'Logs als Datei exportieren, um sie manuell zu senden';

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
  String get supportFaqSubtitle => 'Häufige Fragen & Antworten';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Eltern und Jugendliche beim Aufbau gesunder Online-Gewohnheiten unterstützen';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'Wie wir Konten je nach Alter behandeln';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Mehr über Verifizierung und Authentizität erfahren';

  @override
  String get supportLoginRequired =>
      'Melde dich an, um den Support zu kontaktieren';

  @override
  String get supportExportingLogs => 'Logs werden exportiert...';

  @override
  String get supportExportLogsFailed => 'Logs konnten nicht exportiert werden';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Logs gespeichert unter $path';
  }

  @override
  String get supportRevealLogsAction => 'Im Ordner anzeigen';

  @override
  String get supportChatNotAvailable => 'Support-Chat nicht verfügbar';

  @override
  String get supportCouldNotOpenMessages =>
      'Support-Nachrichten konnten nicht geöffnet werden';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName konnte nicht geöffnet werden';
  }

  @override
  String get reportWhyReporting => 'Warum meldest du diesen Inhalt?';

  @override
  String get reportPolicyNotice =>
      'Divine reagiert innerhalb von 24 Stunden auf Inhaltsmeldungen, indem der Inhalt entfernt und der Nutzer, der den problematischen Inhalt bereitgestellt hat, ausgeschlossen wird.';

  @override
  String get reportBlockUser => 'Diesen Nutzer blockieren';

  @override
  String get reportCancel => 'Abbrechen';

  @override
  String get reportSubmit => 'Melden';

  @override
  String get reportSelectReason =>
      'Bitte wähl einen Grund für die Meldung dieses Inhalts';

  @override
  String get reportOtherRequiresDetails =>
      'Bitte beschreib das Problem, wenn du „Sonstiges“ wählst';

  @override
  String get reportDetailsRequired => 'Bitte beschreib das Problem';

  @override
  String get reportDetailsTextOnly =>
      'Nur Text – Fotos und GIFs können hier nicht angehängt werden.';

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
  String get reportReasonSpam => 'Spam oder unerwünschte Inhalte';

  @override
  String get reportReasonSpamSubtitle =>
      'Unerwünschte oder sich wiederholende Inhalte';

  @override
  String get reportReasonHarassment => 'Belästigung, Mobbing oder Drohungen';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Schädliche und unerwünschte Antworten oder Erwähnungen';

  @override
  String get reportReasonViolence => 'Gewalttätige oder extremistische Inhalte';

  @override
  String get reportReasonViolenceSubtitle =>
      'Gewalttätige, extremistische oder schädliche Inhalte';

  @override
  String get reportReasonSexualContent => 'Sexuelle oder Erwachseneninhalte';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nacktheit, Porno oder explizite Inhalte';

  @override
  String get reportReasonCopyright => 'Urheberrechtsverletzung';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Unbefugte Nutzung von geistigem Eigentum';

  @override
  String get reportReasonFalseInfo => 'Falschinformationen';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Irreführende oder falsche Behauptungen';

  @override
  String get reportReasonChildSafety => 'Verstoß gegen den Kinderschutz';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Allgemeine Bedenken zur Sicherheit von Minderjährigen';

  @override
  String get reportReasonCsam => 'Sexueller Kindesmissbrauch';

  @override
  String get reportReasonCsamSubtitle =>
      'Inhalte, die sexuellen Missbrauch von Minderjährigen darstellen';

  @override
  String get reportReasonUnderageUser => 'Nutzer scheint unter 16 zu sein';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Kontoinhaber scheint minderjährig zu sein';

  @override
  String get reportReasonAiGenerated => 'KI-generierter Inhalt';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Mutmaßlich KI-generierte Inhalte';

  @override
  String get reportReasonOther => 'Andere Richtlinienverletzung';

  @override
  String get reportReasonOtherSubtitle =>
      'Verstöße, die oben nicht aufgeführt sind';

  @override
  String get reportFailed =>
      'Inhalt konnte nicht gemeldet werden. Bitte versuch es nochmal.';

  @override
  String get reportNotSent =>
      'Deine Meldung konnte nicht gesendet werden. Überprüfe deine Verbindung und versuch es nochmal.';

  @override
  String get reportReceivedTitle => 'Meldung erhalten';

  @override
  String get reportReceivedThankYou =>
      'Danke, dass du hilfst, Divine sicher zu halten.';

  @override
  String get reportReceivedReviewNotice =>
      'Unser Team prüft deine Meldung und ergreift entsprechende Maßnahmen. Du erhältst möglicherweise Updates per Direktnachricht.';

  @override
  String get reportModerationDmDelayed =>
      'Wir konnten das Moderationsteam gerade nicht direkt erreichen, aber deine Meldung ist eingegangen und wird geprüft.';

  @override
  String get reportContactModeration => 'Moderationsteam anschreiben';

  @override
  String get reportLearnMoreAt => 'Mehr erfahren unter';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Schließen';

  @override
  String get listAddToList => 'Zur Liste hinzufügen';

  @override
  String listVideoCount(int count) {
    return '$count Videos';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '1 Person',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Von ';

  @override
  String get listNewList => 'Neue Liste';

  @override
  String get listDone => 'Fertig';

  @override
  String get listErrorLoading => 'Fehler beim Laden der Listen';

  @override
  String listRemovedFrom(String name) {
    return 'Aus $name entfernt';
  }

  @override
  String listAddedTo(String name) {
    return 'Zu $name hinzugefügt';
  }

  @override
  String get listCreateNewList => 'Neue Liste erstellen';

  @override
  String get listNewPeopleList => 'Neue Personenliste';

  @override
  String get listCollaboratorsNone => 'Keine';

  @override
  String get listAddCollaboratorTitle => 'Mitarbeiter hinzufügen';

  @override
  String get listCollaboratorSearchHint => 'Divine durchsuchen...';

  @override
  String get listNameLabel => 'Listenname';

  @override
  String get listDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get listPublicList => 'Öffentliche Liste';

  @override
  String get listPublicListSubtitle =>
      'Andere können folgen und diese Liste sehen';

  @override
  String get listPrivateListSubtitle =>
      'Videos bleiben privat. Name, Beschreibung, Tags und Cover bleiben sichtbar.';

  @override
  String get listVisibilityPublic => 'Öffentlich';

  @override
  String get listVisibilityPrivate => 'Privat';

  @override
  String get profileListsEmpty =>
      'Noch keine Listen. Leg eine an für die Loops, die zusammengehören.';

  @override
  String get listEditTitle => 'Liste bearbeiten';

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
  String get listShareAction => 'Liste teilen';

  @override
  String get listShareFailed =>
      'Liste konnte nicht geteilt werden. Versuch es nochmal.';

  @override
  String get listSave => 'Speichern';

  @override
  String get listContinue => 'Weiter';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Liste konnte nicht aktualisiert werden. Versuch es nochmal.';

  @override
  String get listMakePrivateTitle => 'Diese Liste privat machen?';

  @override
  String get listMakePrivateWarning =>
      'Die Videos werden verschlüsselt, sodass nur du sie sehen kannst. Name, Beschreibung, Tags und Cover bleiben sichtbar, und bereits geteilte Kopien können bestehen bleiben.';

  @override
  String get listMakePublicTitle => 'Diese Liste öffentlich machen?';

  @override
  String get listMakePublicWarning =>
      'Alle mit dem Link können diese Liste und ihre Videos sehen.';

  @override
  String listShareText(String name, String url) {
    return 'Schau dir $name auf Divine an: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name auf Divine';
  }

  @override
  String get listCancel => 'Abbrechen';

  @override
  String get listCreate => 'Erstellen';

  @override
  String get listCreateFailed => 'Liste konnte nicht erstellt werden';

  @override
  String get keyManagementTitle => 'Nostr-Schlüssel';

  @override
  String get keyManagementWhatAreKeys => 'Was sind Nostr-Schlüssel?';

  @override
  String get keyManagementExplanation =>
      'Deine Nostr-Identität ist ein kryptografisches Schlüsselpaar:\n\n• Dein Public Key (npub) ist wie dein Benutzername — teil ihn gerne\n• Dein Private Key (nsec) ist wie dein Passwort — halt ihn geheim!\n\nDein nsec erlaubt dir, auf dein Konto in jeder Nostr-App zuzugreifen.';

  @override
  String get keyManagementImportTitle => 'Bestehenden Schlüssel importieren';

  @override
  String get keyManagementImportSubtitle =>
      'Du hast schon ein Nostr-Konto? Füg deinen Private Key (nsec) ein, um hier darauf zuzugreifen.';

  @override
  String get keyManagementImportButton => 'Schlüssel importieren';

  @override
  String get keyManagementImportWarning =>
      'Damit wird dein aktueller Schlüssel ersetzt!';

  @override
  String get keyManagementBackupTitle => 'Schlüssel sichern';

  @override
  String get keyManagementBackupSubtitle =>
      'Sichere deinen Private Key (nsec), um dein Konto in anderen Nostr-Apps zu nutzen.';

  @override
  String get keyManagementCopyNsec => 'Meinen Private Key (nsec) kopieren';

  @override
  String get keyManagementNeverShare =>
      'Teile deinen nsec niemals mit jemandem!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Dein Schlüssel liegt beim Login-Dienst von Divine, nicht auf diesem Gerät. Bestätige dein Passwort, dann holen wir ihn für dich.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Dein Schlüssel wird beim Login-Dienst von Divine aufbewahrt. Gib dein Konto-Passwort ein, dann holen wir ihn.';

  @override
  String get keyManagementKeycastCopyKey => 'Schlüssel kopieren';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Dein Gerät hat das Kopieren blockiert, dein Schlüssel ist also nicht in der Zwischenablage gelandet.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Das Passwort stimmt nicht. Versuch es noch einmal.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Zu viele Versuche. Schließ das und fang neu an.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Zu viele Schlüssel-Anfragen. Warte ein paar Minuten und versuch es erneut.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Deine Sitzung ist abgelaufen. Melde dich erneut an, um deinen Schlüssel zu kopieren.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Bestätige deine E-Mail-Adresse, bevor du deinen Schlüssel kopierst.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine verwaltet die Schlüssel dieses Kontos, daher können sie hier nicht kopiert werden.';

  @override
  String get keyManagementKeycastNoKey =>
      'Für dieses Konto ist kein Schlüssel hinterlegt.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Der Login-Dienst war nicht erreichbar. Bitte versuch es nochmal.';

  @override
  String get keyManagementRestrictedTitle =>
      'Deine Schlüssel werden von Divine verwaltet';

  @override
  String get keyManagementRestrictedBody =>
      'Zur Sicherheit deines Kontos sind Schlüssel-Backup und der Import eines anderen Schlüssels hier nicht verfügbar.';

  @override
  String get keyManagementPasteKey => 'Bitte füg deinen Private Key ein';

  @override
  String get keyManagementInvalidFormat =>
      'Ungültiges Schlüsselformat. Muss mit \"nsec1\" beginnen';

  @override
  String get keyManagementConfirmImportTitle => 'Diesen Schlüssel importieren?';

  @override
  String get keyManagementConfirmImportBody =>
      'Damit wird deine aktuelle Identität durch die importierte ersetzt.\n\nDein aktueller Schlüssel geht verloren, wenn du ihn nicht vorher gesichert hast.';

  @override
  String get keyManagementImportConfirm => 'Importieren';

  @override
  String get keyManagementImportSuccess => 'Schlüssel erfolgreich importiert!';

  @override
  String get keyManagementImportFailed =>
      'Schlüssel konnte nicht importiert werden. Bitte versuch es nochmal.';

  @override
  String get keyManagementExportSuccess =>
      'Private Key in die Zwischenablage kopiert!\n\nBewahre ihn sicher auf.';

  @override
  String get keyManagementExportFailed =>
      'Schlüssel konnte nicht exportiert werden. Bitte versuch es nochmal.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Dein Public Key (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Public Key kopieren';

  @override
  String get keyManagementPublicKeyCopied => 'Public Key kopiert';

  @override
  String get saveOriginalSavedToCameraRoll => 'In Aufnahmen gespeichert';

  @override
  String get saveOriginalShare => 'Teilen';

  @override
  String get saveOriginalDone => 'Fertig';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Fotozugriff erforderlich';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Um Videos zu speichern, erlaube den Fotozugriff in den Einstellungen.';

  @override
  String get saveOriginalOpenSettings => 'Einstellungen öffnen';

  @override
  String get saveOriginalNotNow => 'Nicht jetzt';

  @override
  String get saveOriginalDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get saveOriginalDismiss => 'Schließen';

  @override
  String get saveOriginalDownloadingVideo => 'Video wird heruntergeladen';

  @override
  String get saveOriginalSavingToCameraRoll => 'Speichern in Aufnahmen';

  @override
  String get saveOriginalFetchingVideo =>
      'Video wird aus dem Netzwerk geladen...';

  @override
  String get saveOriginalSavingVideo =>
      'Original-Video wird in deinen Aufnahmen gespeichert...';

  @override
  String get soundTitle => 'Sound';

  @override
  String get soundOriginalSound => 'Originalton';

  @override
  String get soundVideosUsingThisSound => 'Videos, die diesen Sound nutzen';

  @override
  String get soundSourceVideo => 'Quellvideo';

  @override
  String get soundNoVideosYet => 'Noch keine Videos';

  @override
  String get soundBeFirstToUse =>
      'Sei die/der Erste, die/der diesen Sound nutzt!';

  @override
  String get soundFailedToLoadVideos => 'Videos konnten nicht geladen werden';

  @override
  String get soundRetry => 'Erneut versuchen';

  @override
  String get soundVideosUnavailable => 'Videos nicht verfügbar';

  @override
  String get soundCouldNotLoadDetails =>
      'Video-Details konnten nicht geladen werden';

  @override
  String get soundPreview => 'Vorschau';

  @override
  String get soundStop => 'Stopp';

  @override
  String get soundUseSound => 'Sound verwenden';

  @override
  String get soundUntitled => 'Unbenannter Sound';

  @override
  String get soundStopPreview => 'Vorschau stoppen';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '$title anhören';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Details zu $title ansehen';
  }

  @override
  String get soundNoVideoCount => 'Noch keine Videos';

  @override
  String get soundOneVideo => '1 Video';

  @override
  String soundVideoCount(int count) {
    return '$count Videos';
  }

  @override
  String get soundUnableToPreview =>
      'Vorschau nicht möglich — kein Audio verfügbar';

  @override
  String get soundPreviewFailed =>
      'Vorschau-Wiedergabe fehlgeschlagen. Bitte versuch es nochmal.';

  @override
  String get soundViewSource => 'Quelle ansehen';

  @override
  String get soundCloseTooltip => 'Schließen';

  @override
  String get exploreNotExploreRoute => 'Keine Entdecken-Route';

  @override
  String get legalTitle => 'Rechtliches';

  @override
  String get legalTermsOfService => 'Nutzungsbedingungen';

  @override
  String get legalTermsOfServiceSubtitle => 'Nutzungsbedingungen';

  @override
  String get legalPrivacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get legalPrivacyPolicySubtitle => 'Wie wir mit deinen Daten umgehen';

  @override
  String get legalSafetyStandards => 'Sicherheitsstandards';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Community-Richtlinien und Sicherheit';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Urheberrechts- und Takedown-Richtlinie';

  @override
  String get legalOpenSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Angaben zu Drittanbieter-Paketen';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName konnte nicht geöffnet werden';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Abenteuer';

  @override
  String get categoryAnimals => 'Tiere';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Architektur';

  @override
  String get categoryArt => 'Kunst';

  @override
  String get categoryAutomotive => 'Autos';

  @override
  String get categoryAwardShow => 'Preisverleihung';

  @override
  String get categoryAwards => 'Auszeichnungen';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basketball';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryBeverage => 'Getränke';

  @override
  String get categoryCars => 'Autos';

  @override
  String get categoryCelebration => 'Feier';

  @override
  String get categoryCelebrities => 'Promis';

  @override
  String get categoryCelebrity => 'Promi';

  @override
  String get categoryCityscape => 'Stadtbild';

  @override
  String get categoryComedy => 'Comedy';

  @override
  String get categoryConcert => 'Konzert';

  @override
  String get categoryCooking => 'Kochen';

  @override
  String get categoryCostume => 'Kostüm';

  @override
  String get categoryCrafts => 'Basteln';

  @override
  String get categoryCrime => 'Krimi';

  @override
  String get categoryCulture => 'Kultur';

  @override
  String get categoryDance => 'Tanz';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Bildung';

  @override
  String get categoryEmotional => 'Emotional';

  @override
  String get categoryEmotions => 'Emotionen';

  @override
  String get categoryEntertainment => 'Unterhaltung';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryFamily => 'Familie';

  @override
  String get categoryFans => 'Fans';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Mode';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Essen';

  @override
  String get categoryFootball => 'American Football';

  @override
  String get categoryFurniture => 'Möbel';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Körperpflege';

  @override
  String get categoryGuitar => 'Gitarre';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Gesundheit';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Urlaub';

  @override
  String get categoryHome => 'Zuhause';

  @override
  String get categoryHomeImprovement => 'Heimwerken';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Krankenhaus';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Inneneinrichtung';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Kinder';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magie';

  @override
  String get categoryMakeup => 'Make-up';

  @override
  String get categoryMedical => 'Medizin';

  @override
  String get categoryMusic => 'Musik';

  @override
  String get categoryMystery => 'Mystery';

  @override
  String get categoryNature => 'Natur';

  @override
  String get categoryNews => 'News';

  @override
  String get categoryOutdoor => 'Outdoor';

  @override
  String get categoryParty => 'Party';

  @override
  String get categoryPeople => 'Menschen';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Haustiere';

  @override
  String get categoryPolitics => 'Politik';

  @override
  String get categoryPrank => 'Streich';

  @override
  String get categoryPranks => 'Streiche';

  @override
  String get categoryRealityShow => 'Reality-Show';

  @override
  String get categoryRelationship => 'Beziehung';

  @override
  String get categoryRelationships => 'Beziehungen';

  @override
  String get categoryRomance => 'Romantik';

  @override
  String get categorySchool => 'Schule';

  @override
  String get categoryScienceFiction => 'Science-Fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Hautpflege';

  @override
  String get categorySoccer => 'Fußball';

  @override
  String get categorySocialGathering => 'Gesellschaft';

  @override
  String get categorySocialMedia => 'Social Media';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talkshow';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryTelevision => 'Fernsehen';

  @override
  String get categoryToys => 'Spielzeug';

  @override
  String get categoryTransportation => 'Verkehr';

  @override
  String get categoryTravel => 'Reisen';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Gewalt';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadStaged =>
      'Hochgeladen – tippe auf Speichern, um zu übernehmen';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName gemeldet';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName blockiert';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName entblockt';
  }

  @override
  String get inboxRemovedConversation => 'Unterhaltung entfernt';

  @override
  String get inboxRestorePausedTitle =>
      'Einige Chats sind noch nicht wiederhergestellt';

  @override
  String get conversationRestorePausedTitle =>
      'Dieser Chat ist noch nicht vollständig wiederhergestellt';

  @override
  String get inboxRestoreRetryAction => 'Erneut versuchen';

  @override
  String get inboxRestoringMessages =>
      'Deine Nachrichten werden wiederhergestellt…';

  @override
  String get inboxEmptyTitle => 'Noch keine Nachrichten';

  @override
  String get inboxEmptySubtitle => 'Der + Button beißt nicht.';

  @override
  String get inboxLoadErrorTitle => 'Nachrichten konnten nicht geladen werden';

  @override
  String get inboxLoadErrorSubtitle =>
      'Prüf deine Verbindung und versuch es nochmal.';

  @override
  String get inboxFilterAll => 'Alle';

  @override
  String get inboxFilterUnread => 'Ungelesen';

  @override
  String get dmBlockedThreadTitle => 'Du hast dieses Konto blockiert';

  @override
  String get dmBlockedThreadBody =>
      'Nachrichten bleiben hier, damit du sie lesen oder einen Screenshot machen kannst. Hebe die Blockierung auf, um zu antworten.';

  @override
  String get inboxFilterBlocked => 'Blockiert';

  @override
  String get inboxBlockedEmptyTitle => 'Keine blockierten Chats';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Konten, die du blockierst, erscheinen hier.';

  @override
  String get inboxBlockedNoMessages => 'Keine Nachrichten';

  @override
  String get inboxUnreadEmptyTitle => 'Du bist auf dem Laufenden';

  @override
  String get inboxUnreadEmptySubtitle =>
      'Gerade keine ungelesenen Nachrichten.';

  @override
  String get inboxSearchHint => 'Nachrichten durchsuchen';

  @override
  String get inboxSupportRowTitle => 'Divine-Moderation';

  @override
  String get inboxSupportRowSubtitle =>
      'Bugs, Moderation, Kontofragen — wir hören zu.';

  @override
  String get inboxSearchEmptyTitle => 'Keine Treffer';

  @override
  String get inboxSearchEmptySubtitle =>
      'Versuch einen anderen Namen oder ein anderes Wort.';

  @override
  String get inboxActionMute => 'Unterhaltung stummschalten';

  @override
  String inboxActionReport(String displayName) {
    return '$displayName melden';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayName blockieren';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayName entblocken';
  }

  @override
  String get inboxActionRemove => 'Unterhaltung entfernen';

  @override
  String get inboxRemoveConfirmTitle => 'Unterhaltung entfernen?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Dadurch wird deine Unterhaltung mit $displayName aus deinem Posteingang entfernt. Wenn dir diese Person wieder schreibt, beginnt eine neue Unterhaltung.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Dadurch wird die Gruppenunterhaltung aus deinem Posteingang entfernt. Wenn jemand wieder in die Gruppe schreibt, beginnt eine neue Unterhaltung.';

  @override
  String get inboxRemoveConfirmConfirm => 'Entfernen';

  @override
  String get inboxConversationMuted => 'Unterhaltung stummgeschaltet';

  @override
  String get inboxConversationUnmuted =>
      'Unterhaltung nicht mehr stummgeschaltet';

  @override
  String get inboxCollabInviteCardTitle => 'Einladung zur Zusammenarbeit';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video ohne Titel';

  @override
  String get clickableTextViewVideoLink => 'Video ansehen';

  @override
  String get messageExternalLinkDialogTitle => 'Externen Link öffnen?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Dieser Link führt zu einer externen Website und ist möglicherweise nicht sicher:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Öffnen';

  @override
  String get inboxCollabInviteCoPostButton => 'Mitposten';

  @override
  String get inboxCollabInviteNotMineButton => 'Nicht meins';

  @override
  String get inboxCollabInvitePreviewTitle => 'Einladung zum Mitposten';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Einladung zum Mitposten von $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Mitposten fügt dieses Video als Zusammenarbeit zu deiner Timeline hinzu.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Angenommen';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignoriert';

  @override
  String get inboxCollabInviteAcceptError =>
      'Annahme fehlgeschlagen. Erneut versuchen.';

  @override
  String get inboxCollabInviteSentStatus => 'Einladung gesendet';

  @override
  String get inboxConversationCollabInvitePreview =>
      'Einladung zur Zusammenarbeit';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Du wurdest eingeladen, an $title mitzuarbeiten: $url\n\nÖffne Divine, um sie zu prüfen und anzunehmen.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Du wurdest eingeladen, an einem Video mitzuarbeiten: $url\n\nÖffne Divine, um sie zu prüfen und anzunehmen.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitwirkenden-Einladungen wurden nicht gesendet.',
      one: '1 Mitwirkenden-Einladung wurde nicht gesendet.',
    );
    return 'Video gepostet, aber $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Wir konnten nicht erkennen, mit wem diese Unterhaltung ist. Öffne sie noch mal aus deinem Postfach.';

  @override
  String get dmSendBlockedMessage =>
      'Du kannst nur offiziellen Divine-Konten schreiben';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Diese Unterhaltung liest niemand. Schreib stattdessen an Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Für alle löschen hat nicht geklappt.';

  @override
  String get dmDeleteRefusedDetails =>
      'Einige Personen können diese Nachricht möglicherweise noch sehen.';

  @override
  String get dmRetiredThreadClosedTitle =>
      'Diese Unterhaltung ist geschlossen.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Dieser Hinweis von Divine Moderation kann nicht entfernt werden.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Wir haben Divine Moderation auf ein neues Konto umgezogen. Dieses hier liest niemand mehr.';

  @override
  String get dmRetiredThreadOpenSupport => 'Divine Moderation schreiben';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Nachricht konnte nicht gesendet werden';

  @override
  String get dmResendFailedMessage => 'Konnte weiterhin nicht gesendet werden';

  @override
  String get dmSendFailedSubtitle =>
      'Sende sie jetzt erneut oder versuche es nicht mehr.';

  @override
  String get dmSendFailedRetry => 'Erneut versuchen';

  @override
  String get dmSendPartialMessage =>
      'Gesendet, aber nicht mit deinen anderen Geräten synchronisiert';

  @override
  String get dmConversationLoadError =>
      'Nachrichten konnten nicht geladen werden';

  @override
  String get dmMessageInputHint => 'Sag was …';

  @override
  String get dmMessageBubbleSentHint => 'Gesendete Nachricht';

  @override
  String get dmMessageBubbleReceivedHint => 'Empfangene Nachricht';

  @override
  String get dmMessageBubbleLongPressHint => 'Nachrichtenaktionen';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Nachricht erneut senden oder löschen';

  @override
  String get dmMessageActionCopyText => 'Text kopieren';

  @override
  String get dmMessageActionCopyVideoUrl => 'Video-URL kopieren';

  @override
  String get dmMessageActionDeleteForEveryone => 'Für alle löschen';

  @override
  String get dmMessageActionReport => 'Melden';

  @override
  String get dmMessageActionRetrySend => 'Erneut senden';

  @override
  String get dmMessageActionCancelSend => 'Nicht mehr versuchen';

  @override
  String get dmReactionAddCustomA11yLabel => 'Eigene Emoji-Reaktion hinzufügen';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Nachricht an $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Dir selbst antworten…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Auf dieses Reel antworten';

  @override
  String get dmReelReplyViewChat => 'Chat ansehen';

  @override
  String get dmReelReplySentAnnouncement => 'Antwort gesendet';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Mit $emoji reagiert';
  }

  @override
  String get dmReelReplyFailed => 'Senden fehlgeschlagen';

  @override
  String get dmReelReplyUnverified => 'Senden nicht bestätigt';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Deine Reaktion: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name hat mit $emoji reagiert';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Reaktion wird gesendet: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reaktion fehlgeschlagen, doppelt tippen zum Wiederholen';

  @override
  String get dmReactionChipRetryAnnouncement => 'Reaktion wird wiederholt';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Entferne zuerst deine vorherige Reaktion, bevor du eine neue hinzufügst.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reaktionen';

  @override
  String get dmReactionsViewA11yLabel => 'Sehen, wer reagiert hat';

  @override
  String get dmReactionRemoveAction => 'Entfernen';

  @override
  String get dmReactionRetryAction => 'Erneut versuchen';

  @override
  String get dmFormatBold => 'Fett';

  @override
  String get dmFormatItalic => 'Kursiv';

  @override
  String get dmFormatStrikethrough => 'Durchgestrichen';

  @override
  String get dmFormatCode => 'Code';

  @override
  String get dmStatusFailed => 'Senden fehlgeschlagen';

  @override
  String get inboxConversationActionsSheetLabel => 'Unterhaltungsaktionen';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Unterhaltung mit $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Ungelesen, Unterhaltung mit $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Personen',
      one: '$count weitere Person',
    );
    return '$name und $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Unterhaltungsaktionen anzeigen';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Titel: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Suchen...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count Videos';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Abo konnte nicht aktualisiert werden. Bitte versuch es nochmal.';

  @override
  String get discoverListsTitle => 'Listen entdecken';

  @override
  String get discoverListsFailedToLoad => 'Listen konnten nicht geladen werden';

  @override
  String get discoverListsLoading => 'Öffentliche Listen werden entdeckt...';

  @override
  String get discoverListsRelayTimeout =>
      'Das Relay hat nicht rechtzeitig Listen geliefert. Versuch es nochmal.';

  @override
  String get discoverListsServiceUnavailable => 'Dienst nicht verfügbar.';

  @override
  String get discoverListsEmptyTitle => 'Keine öffentlichen Listen gefunden';

  @override
  String get discoverListsEmptySubtitle =>
      'Schau später nochmal nach neuen Listen';

  @override
  String get discoverListsByAuthorPrefix => 'von';

  @override
  String get curatedListEmptyTitle => 'Keine Videos in dieser Liste';

  @override
  String get curatedListEmptySubtitle =>
      'Füg ein paar Videos hinzu, um loszulegen';

  @override
  String get curatedListLoadingVideos => 'Videos werden geladen...';

  @override
  String get curatedListFailedToLoad => 'Liste konnte nicht geladen werden';

  @override
  String get curatedListVideoNotAvailable => 'Video nicht verfügbar';

  @override
  String get curatedListActionsTooltip => 'Listenaktionen';

  @override
  String get curatedListDeleteConfirmTitle => 'Liste löschen?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Dadurch wird die Liste von den Relays entfernt. Videos in der Liste werden nicht gelöscht.';

  @override
  String get curatedListDeletedSnack => 'Liste gelöscht';

  @override
  String get curatedListDeleteFailed => 'Liste konnte nicht gelöscht werden';

  @override
  String get peopleListsActionsTooltip => 'Listenaktionen';

  @override
  String get listDeleteAction => 'Liste löschen';

  @override
  String get peopleListsDeleteConfirmTitle => 'Liste löschen?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Dadurch wird die Liste für alle entfernt. Die enthaltenen Personen werden nicht entfolgt.';

  @override
  String get peopleListsDeleteFailed => 'Liste konnte nicht gelöscht werden';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonSomethingWentWrong => 'Etwas ist schiefgelaufen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonNotNow => 'Nicht jetzt';

  @override
  String get commonLoading => 'Wird geladen';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Cover konnte nicht aktualisiert werden. Versuche es erneut.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Cover aktualisiert';

  @override
  String get videoMetadataC2paMissingTitle => 'Ohne Echtheitsnachweis posten?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Wir konnten keine Content Credentials hinzufügen – dieses Video wird daher nicht als von Menschen gemacht bestätigt. Neu generieren, um es erneut zu versuchen, oder so posten.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Content Credentials brauchen eine Internetverbindung.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Der Dienst für Inhaltsnachweise hat nicht geantwortet. Es liegt nicht an deiner Verbindung.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Neu generieren';

  @override
  String get videoMetadataC2paMissingSkip => 'Überspringen';

  @override
  String get videoMetadataGenerationFailed => 'Generierung fehlgeschlagen';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Verfallszeit';

  @override
  String get videoMetadataExpirationNotExpire => 'Läuft nicht ab';

  @override
  String get videoMetadataExpirationOneDay => '1 Tag';

  @override
  String get videoMetadataExpirationOneWeek => '1 Woche';

  @override
  String get videoMetadataExpirationOneMonth => '1 Monat';

  @override
  String get videoMetadataExpirationOneYear => '1 Jahr';

  @override
  String get videoMetadataExpirationOneDecade => '1 Jahrzehnt';

  @override
  String get videoMetadataContentWarnings => 'Inhaltswarnungen';

  @override
  String get videoEditorStickers => 'Sticker';

  @override
  String get trendingTitle => 'Im Trend';

  @override
  String get libraryDeleteConfirm => 'Löschen';

  @override
  String get libraryWebUnavailableHeadline =>
      'Mediathek ist in der mobilen App';

  @override
  String get libraryWebUnavailableDescription =>
      'Entwürfe und Clips werden auf deinem Gerät gespeichert. Öffne Divine auf dem Smartphone, um sie zu verwalten.';

  @override
  String get libraryTabDrafts => 'Entwürfe';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Ausgewählte Clips löschen';

  @override
  String get libraryCloseSemanticLabel => 'Bibliothek schließen';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Clip-Auswahl beenden';

  @override
  String get librarySelectClipsSemanticLabel => 'Clips auswählen';

  @override
  String get libraryGridSizeLabel => 'Rastergröße';

  @override
  String get libraryDisplayOptionsLabel => 'Sortierung & Rastergröße';

  @override
  String get libraryMoreActionsSemanticLabel => 'Weitere Bibliotheksaktionen';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Spalten',
      one: '1 Spalte',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Auswählen';

  @override
  String get librarySortNewestCreation => 'Neueste Aufnahme';

  @override
  String get librarySortOldestCreation => 'Älteste Aufnahme';

  @override
  String get librarySortLongestClip => 'Längster Clip';

  @override
  String get librarySortShortestClip => 'Kürzester Clip';

  @override
  String get librarySortSquareFirst => 'Quadratisch zuerst';

  @override
  String get librarySortVerticalFirst => 'Vertikal zuerst';

  @override
  String get libraryDeleteClipsWarning =>
      'Das kann nicht rückgängig gemacht werden. Die Videodateien werden dauerhaft von deinem Gerät entfernt.';

  @override
  String get libraryPreparingVideo => 'Video wird vorbereitet …';

  @override
  String libraryCreateVideo(int count) {
    return 'Video erstellen ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips',
      one: '1 Clip',
    );
    return '$_temp0 in $destination gespeichert';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount gespeichert, $failureCount fehlgeschlagen';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Speichern in $destination fehlgeschlagen';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination: Berechtigung verweigert';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips gelöscht',
      one: '1 Clip gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Rückgängig';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Wird in $daysLeft Tagen automatisch gelöscht',
      one: 'Wird morgen automatisch gelöscht',
      zero: 'Wird heute automatisch gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Entwürfe konnten nicht geladen werden';

  @override
  String get libraryCouldNotLoadClips => 'Clips konnten nicht geladen werden';

  @override
  String get libraryOpenErrorDescription =>
      'Beim Öffnen deiner Mediathek ist etwas schiefgelaufen. Versuch es noch einmal.';

  @override
  String get libraryNoDraftsYetTitle => 'Noch keine Entwürfe';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Videos, die du als Entwurf speicherst, erscheinen hier';

  @override
  String get libraryNoClipsYetTitle => 'Noch keine Clips';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Deine aufgenommenen Videoclips erscheinen hier';

  @override
  String get libraryDraftDeletedSnackbar => 'Entwurf gelöscht';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Entwurf konnte nicht gelöscht werden';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Entwurf dupliziert';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Entwurf konnte nicht dupliziert werden';

  @override
  String get libraryDraftInProgressBadge => 'In Arbeit';

  @override
  String get libraryDraftActionPost => 'Posten';

  @override
  String get libraryDraftActionEdit => 'Bearbeiten';

  @override
  String get libraryDraftActionDuplicate => 'Duplizieren';

  @override
  String get libraryDraftActionDelete => 'Entwurf löschen';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (Kopie $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Entwurf löschen';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '„$title“ wirklich löschen?';
  }

  @override
  String get libraryDeleteClipTitle => 'Clip löschen';

  @override
  String get libraryDeleteClipMessage => 'Diesen Clip wirklich löschen?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds Sek';
  }

  @override
  String get libraryRecordVideo => 'Video aufnehmen';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Videoclip, $duration Sekunden';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Archiviert. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Stop-Motion-Clip, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Ausgewählt, Nummer $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Ausgewählt';

  @override
  String get videoClipSemanticValueNotSelected => 'Nicht ausgewählt';

  @override
  String get videoClipSemanticHintDisabled => 'Deaktiviert';

  @override
  String get videoClipSemanticHintSelect =>
      'Tippen zum Auswählen, lang drücken für Vorschau';

  @override
  String get videoClipSemanticHintDeselect =>
      'Tippen zum Abwählen, lang drücken für Vorschau';

  @override
  String get routerInvalidCreator => 'Ungültiger Ersteller';

  @override
  String get routerInvalidHashtagRoute => 'Ungültige Hashtag-Route';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Videos konnten nicht geladen werden';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Keine Videos in dieser Kategorie';

  @override
  String get categoryGallerySortOptionsLabel => 'Sortieroptionen für Kategorie';

  @override
  String get categoryGallerySortHot => 'Beliebt';

  @override
  String get categoryGallerySortNew => 'Neu';

  @override
  String get categoryGallerySortClassic => 'Klassiker';

  @override
  String get categoryGallerySortForYou => 'Für dich';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Kategorien konnten nicht geladen werden';

  @override
  String get categoriesNoCategoriesAvailable => 'Keine Kategorien verfügbar';

  @override
  String get notificationsEmptyTitle => 'Hier ist noch nichts los';

  @override
  String get notificationsEmptySubtitle =>
      'Sobald Leute mit deinen Inhalten interagieren, siehst du es hier';

  @override
  String get appsPermissionsTitle => 'Integrations-Berechtigungen';

  @override
  String get appsPermissionsRevoke => 'Widerrufen';

  @override
  String get appsPermissionsEmptyTitle =>
      'Keine gespeicherten Integrations-Berechtigungen';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Genehmigte Integrationen tauchen hier auf, sobald du eine Zugriffsfreigabe merkst.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName bittet um deine Freigabe';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Diese App fordert Zugriff über die geprüfte Sandbox von Divine an.';

  @override
  String get nostrAppPermissionOrigin => 'Herkunft';

  @override
  String get nostrAppPermissionMethod => 'Methode';

  @override
  String get nostrAppPermissionCapability => 'Funktion';

  @override
  String get nostrAppPermissionEventKind => 'Event-Kind';

  @override
  String get nostrAppPermissionAllow => 'Erlauben';

  @override
  String get appsDetailDefaultTitle => 'Integrierte App';

  @override
  String get appsDetailNotFoundTitle => 'Integration nicht gefunden';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Diese genehmigte Integration ist in Divine nicht mehr verfügbar.';

  @override
  String get appsDetailHowItWorksTitle => 'So funktioniert’s';

  @override
  String get appsDetailHowItWorksBody =>
      'Dies ist eine genehmigte Drittanbieter-App, die in Divine läuft. Divine gewährt dieser Integration nur geprüfte Funktionen und blockiert die Navigation außerhalb der genehmigten Ursprünge.';

  @override
  String get appsDetailAboutTitle => 'Über';

  @override
  String get appsDetailPrimaryOriginTitle => 'Primärer Ursprung';

  @override
  String get appsDetailApprovedOriginsTitle => 'Genehmigte Ursprünge';

  @override
  String get appsDetailCapabilitiesTitle => 'Verfügbare Funktionen';

  @override
  String get appsDetailAskBeforeTitle => 'Nachfragen vor';

  @override
  String get appsDetailOpenButton => 'Integration öffnen';

  @override
  String get appsDetailNoneDeclared => 'Noch nichts angegeben';

  @override
  String get appsDirectoryTitle => 'Integrierte Apps';

  @override
  String get appsDirectoryIntroTitle => 'Genehmigte Drittanbieter-Apps';

  @override
  String get appsDirectoryIntroBody =>
      'Genehmigte Drittanbieter-Apps, die in Divine laufen';

  @override
  String get appsDirectoryErrorTitle =>
      'Integrierte Apps konnten nicht geladen werden';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Zieh nach unten, um die genehmigten Integrationen erneut zu versuchen.';

  @override
  String get appsDirectoryEmptyTitle => 'Noch keine genehmigten Integrationen';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Genehmigte Drittanbieter-Apps erscheinen hier, sobald Divine sie hinzufügt.';

  @override
  String get appsDirectoryRefresh => 'Aktualisieren';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Integrierte Apps laufen in Divine Mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Genehmigte Integrationen sind vorerst nur auf dem Handy verfügbar.';

  @override
  String get appsSandboxUnavailableTitle => 'Integration nicht verfügbar';

  @override
  String get appsSandboxUnavailableBody =>
      'Öffne genehmigte Integrationen über den Tab „Integrierte Apps“, damit Divine die richtige Zugriffsrichtlinie anwenden kann.';

  @override
  String get appsSandboxLoadingTitle => 'Integration wird geladen';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Die genehmigte Integration wird vor dem Start geprüft.';

  @override
  String get appsSandboxBlockedTitle => 'Aus Sicherheitsgründen blockiert';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Diese Integration hat versucht, ihren genehmigten Ursprung zu verlassen.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink =>
      'Link zum Beitrag in die Zwischenablage kopiert';

  @override
  String get shareCopiedEventJson =>
      'Nostr-Event-JSON in die Zwischenablage kopiert';

  @override
  String get shareCopiedEventId =>
      'Nostr-Event-ID in die Zwischenablage kopiert';

  @override
  String get authHeroTaglineAuthentic => 'Echte Momente.';

  @override
  String get authHeroTaglineHuman => 'Menschliche Kreativität.';

  @override
  String get keyImportFailedToImport =>
      'Schlüssel konnte nicht importiert oder Bunker nicht verbunden werden';

  @override
  String get keyImportInvalidBunkerUrl => 'Ungültige Bunker-URL';

  @override
  String get keyImportInvalidFormat =>
      'Ungültiges Format. Verwende nsec…, hex, ncryptsec1… oder bunker://…';

  @override
  String get keyImportInvalidNsecFormat =>
      'Ungültiges nsec-Format. Sollte 63 Zeichen lang sein';

  @override
  String get keyImportKeyFieldLabel => 'Privater Schlüssel oder Bunker-URL';

  @override
  String get keyImportKeyRequired =>
      'Bitte gib deinen privaten Schlüssel oder deine Bunker-URL ein';

  @override
  String get keyImportPasswordRequired =>
      'Bitte gib das Passwort für diesen verschlüsselten Schlüssel ein';

  @override
  String get keyImportSecurityWarningBody =>
      'Teile deinen privaten Schlüssel niemals mit anderen. Dieser Schlüssel gibt vollen Zugriff auf deine Nostr-Identität.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Halte deinen privaten Schlüssel sicher!';

  @override
  String get keyImportSubtitle =>
      'Importiere deine bestehende Nostr-Identität mit deinem privaten Schlüssel oder einer Bunker-URL.';

  @override
  String get keyImportTitle => 'Importiere deine\nNostr-Identität';

  @override
  String get commentAuthorYouIndicator => 'Du';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Profil von $name ansehen';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Kommentar löschen';

  @override
  String get commentOptionsEditSemanticLabel => 'Kommentar bearbeiten';

  @override
  String get commentOptionsFlagContentLabel => 'Inhalt melden';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Diesen Inhalt melden';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Wähle einen Grund für die Meldung dieses Kommentars';

  @override
  String get commentOptionsFlagSubmit => 'Absenden';

  @override
  String get commentOptionsTitle => 'Optionen';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Wir arbeiten noch daran, alte Kommentare aus dem Archiv zu importieren. Sie sind noch nicht bereit.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Bearbeiten';

  @override
  String get commentsInputSemanticHint => 'Einen Kommentar hinzufügen';

  @override
  String get commentsInputSemanticHintEdit => 'Kommentar bearbeiten';

  @override
  String get commentsInputSemanticHintReply => 'Eine Antwort hinzufügen';

  @override
  String get commentsInputSemanticLabel => 'Kommentareingabe';

  @override
  String get commentsInputSemanticLabelEdit => 'Eingabe bearbeiten';

  @override
  String get commentsInputSemanticLabelReply => 'Antworteingabe';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Profil von $displayName ansehen';
  }

  @override
  String get classicsEmptyDescription => 'Das Klassiker-Archiv wird geladen';

  @override
  String get classicsEmptyTitle => 'Keine Klassiker gefunden';

  @override
  String get classicsErrorTitle => 'Klassiker konnten nicht geladen werden';

  @override
  String get classicsUnavailableDescription =>
      'Klassiker sind nur verfügbar, wenn du mit Funnelcake-Relays verbunden bist.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Wechsle in den Einstellungen zu einem Funnelcake-fähigen Relay, um auf das Klassiker-Archiv zuzugreifen.';

  @override
  String get classicsUnavailableTitle => 'Klassiker nicht verfügbar';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Sei der Erste, der ein Video mit diesem Hashtag postet!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Keine Videos für #$hashtag gefunden';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Das kann einen Moment dauern';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Videos zu #$hashtag werden geladen …';
  }

  @override
  String get hashtagInputHint => 'Hashtags hinzufügen … #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Schau später wieder für neue Inhalte vorbei';

  @override
  String get newVideosTabEmptyTitle => 'Keine Videos unter „Neue Videos“';

  @override
  String get popularVideosContextTitle => 'Beliebte Videos';

  @override
  String get popularVideosEmptySubtitle =>
      'Schau später wieder für neue Inhalte vorbei';

  @override
  String get popularVideosEmptyTitle => 'Keine Videos unter „Beliebte Videos“';

  @override
  String get popularVideosErrorTitle =>
      'Trending-Videos konnten nicht geladen werden';

  @override
  String get popularVideosFeedSourceLabel => 'Quelle des Beliebt-Feeds';

  @override
  String get trendingHashtagsLoading => 'Hashtags werden geladen …';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Videos mit $hashtag ansehen';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Video-Autor: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Videobeschreibung: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divines Vision ist es, dir echte algorithmische Wahlfreiheit zu geben. Statt an einen einzigen Blackbox-Algorithmus gebunden zu sein, kannst du aus mehreren Empfehlungsansätzen wählen:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Chronologische Timeline von Creators, denen du folgst';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'So hast du die Kontrolle über deine Aufmerksamkeit, statt sie der Plattform zu überlassen. Du solltest wissen, wie dein Feed kuratiert wird, und die Möglichkeit haben, das jederzeit zu ändern.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Von der Community erstellte eigene Feeds zu Themen wie Musik, Comedy oder Kunst';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Personalisierter „Für dich“-Feed';

  @override
  String get forYouAlgorithmChoiceTitle => 'Dein Algorithmus, deine Wahl';

  @override
  String get forYouAlgorithmChoiceTrending => 'Angesagte und beliebte Inhalte';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Starkes Signal – du warst engagiert genug, um zu antworten';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine achtet darauf, wie du mit Inhalten interagierst, um zu verstehen, was dir gefällt. Jedes Mal, wenn du ein Video ansiehst, darauf reagierst, einen Kommentar hinterlässt oder es repostest, merkt sich das System das.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'So funktioniert’s';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Verschiedene Aktionen signalisieren unterschiedliches Interesse:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Wenn du noch keinen Verlauf aufgebaut hast, zeigen wir dir einen Mix aus aktuell Beliebtem und Angesagtem sowie neuen Uploads. Das ist ein guter Ausgangspunkt zum Entdecken.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Während du Inhalte ansiehst, likest und mit ihnen interagierst, werden die Empfehlungen nach und nach persönlicher. Mit der Zeit zeigt dein „Für dich“-Feed Videos von Creators, die du sonst vielleicht nie entdeckt hättest.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Neu bei Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Wir bauen ein offenes System, in dem Entwickler eigene Algorithmen umsetzen können und du wählst, welche du nutzt – oder ganz darauf verzichtest.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open Source & transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Mittleres Signal – eine schnelle Art, Wertschätzung zu zeigen';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reaktionen';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Stärkstes Signal – mit deinen Followern zu teilen ist eine kraftvolle Empfehlung';

  @override
  String get forYouAlgorithmSubtitle =>
      'Angetrieben von Gorse, einer Open-Source-Empfehlungsmaschine';

  @override
  String get forYouAlgorithmTitle => 'Der Divine-Algorithmus';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Leichtes Signal – deutet auf grundlegendes Interesse hin';

  @override
  String get forYouEmptyDescription =>
      'Sieh dir ein paar Videos an und like sie, um personalisierte Empfehlungen zu erhalten.';

  @override
  String get forYouEmptyTitle => 'Noch keine Empfehlungen';

  @override
  String get forYouErrorTitle => 'Empfehlungen konnten nicht geladen werden';

  @override
  String get forYouUnavailableDescription =>
      'Personalisierte Empfehlungen erfordern eine Verbindung zu Funnelcake.';

  @override
  String get forYouUnavailableTitle => '„Für dich“ nicht verfügbar';

  @override
  String get inboxConversationOptionsLabel => 'Optionen';

  @override
  String get inboxConversationViewProfileButton => 'Profil ansehen';

  @override
  String get inboxMessageRequestsEmpty => 'Keine Nachrichtenanfragen';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Nachrichtenanfragen, $requestCount ausstehend';
  }

  @override
  String get inboxMessageRequestsTitle => 'Nachrichtenanfragen';

  @override
  String get inboxMessagesTab => 'Nachrichten';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Nachrichtenanfrage von $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Hat eine Nachrichtenanfrage gesendet';

  @override
  String get inboxRequestsMarkAllRead => 'Alle Anfragen als gelesen markieren';

  @override
  String get inboxRequestsRemoveAll => 'Alle Anfragen entfernen';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Ablehnen und entfernen';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Anfrage von $displayName abgelehnt';
  }

  @override
  String get messageRequestLoadFailed =>
      'Diese Anfrage konnte nicht geladen werden.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count Follower';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count Videos';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten',
      one: '1 Nachricht',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Nachrichten ansehen';

  @override
  String get messageRequestViewProfileButton => 'Profil ansehen';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName möchte dir schreiben und hat $messageText gesendet.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Du hast das Konto gewechselt, also wurde nichts gelöscht. Öffne das Löschen erneut für das Konto, das du entfernen willst.';

  @override
  String get deleteAccountConfirmDeletePrompt =>
      'Gib zur Bestätigung Folgendes ein:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Gib zur Bestätigung deinen Benutzernamen ein:';

  @override
  String get deleteAccountConfirmationHint => 'DELETE eingeben';

  @override
  String get deleteAccountConfirmationHintUsername => 'Benutzername eingeben';

  @override
  String get deleteAccountDeleteAllContentButton => 'Alle Inhalte löschen';

  @override
  String get accountDeletionRecoveryTitle => 'Dein Konto wird gelöscht';

  @override
  String get accountDeletionRecoveryBody =>
      'Wir konnten das Löschen deines Kontos nicht abschließen. Dein Benutzername ist für dich reserviert und kann noch zurückgeholt werden.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Benutzernamen zurückholen';

  @override
  String get accountDeletionFinishingBody =>
      'Deine Löschanfrage wird noch bearbeitet. Währenddessen kannst du ein anderes Konto verwenden.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Die Löschung eines anderen Kontos wird auf diesem Gerät noch bearbeitet. Warte, bis sie abgeschlossen ist, bevor du dieses Konto löschst.';

  @override
  String get accountDeletionCancellingBody =>
      'Wir brechen deine Löschung gerade ab. Schau nochmal nach, bevor du diesen Bildschirm verlässt.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Wir konnten deinen Benutzernamen noch nicht zurückholen. Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get accountDeletionUsernameRestored =>
      'Dein Benutzername ist zurück. Dein Konto wurde nicht gelöscht.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Wir konnten den Status deiner Löschung nicht prüfen. Prüfe deine Verbindung und versuch es erneut.';

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
      'Die Kontolöschung ist gerade nicht verfügbar. Es wurde nichts gelöscht.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Wir konnten das Löschen deines Kontos nicht abschließen. Versuch es erneut.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Letzte Bestätigung';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Löschanfragen gesendet, aber deine Schlüssel wurden möglicherweise nicht vollständig von diesem Gerät entfernt. Gehe zu Einstellungen → Nostr-Schlüssel → Schlüssel entfernen, um es erneut zu versuchen.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Löschanfragen gesendet und du bist abgemeldet, aber einige lokale Daten konnten nicht von diesem Gerät entfernt werden.';

  @override
  String get deleteAccountPreparingDeletion => 'Löschung wird vorbereitet …';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total Events';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Dadurch wird der lokale Login für dieses Konto von diesem Gerät entfernt. Dein Divine-Konto oder deine Nostr-Identität werden nicht gelöscht.\n\nDeine Entwürfe und Clips bleiben für dieses Konto auf diesem Gerät gespeichert. Wenn dies dein letztes lokales Konto ist, gelangst du zurück zum Anmeldebildschirm.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Vom Gerät entfernen';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Dieses Konto von diesem Gerät entfernen?';

  @override
  String get deleteAccountReauthRequired =>
      'Melde dich erneut an, um dein Konto zu löschen. Es wurde noch nichts gelöscht.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Löschanfragen für deine Beiträge wurden gesendet, aber wir konnten dein Konto nicht vollständig löschen. Versuch es später noch mal.';

  @override
  String get deleteAccountSuccess =>
      'Dein Divine-Konto wurde gelöscht. Für deine Nostr-Beiträge wurden Löschanfragen gesendet, aber einige Relays, Clients oder Caches behalten möglicherweise Kopien.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Kontolöschung angefragt. Für einige vorhandene Beiträge konnte die Löschung nicht einzeln bestätigt werden.';

  @override
  String get deleteAccountWarningBody =>
      'Das sendet Löschanfragen für dein Konto und deine Inhalte, löscht dein Divine-Konto wenn möglich und meldet dich auf diesem Gerät ab. Einige Relays, Clients und Suchindizes behalten möglicherweise Kopien. Andere angemeldete Geräte bleiben aktiv, bis du dort die Schlüssel entfernst.';

  @override
  String get findPeopleNoContacts =>
      'Keine Kontakte gefunden.\nFolge Leuten, um sie hier zu sehen.';

  @override
  String get geoBlockedCityLabel => 'Stadt';

  @override
  String get geoBlockedCountryLabel => 'Land';

  @override
  String get geoBlockedDefaultReason =>
      'Dieser Dienst ist in deiner Region aufgrund lokaler Vorschriften nicht verfügbar.';

  @override
  String get geoBlockedLegalNotice =>
      'Wir respektieren deine lokalen Gesetze und Vorschriften. Diese Einschränkung basiert auf dem Standort deiner IP-Adresse.';

  @override
  String get geoBlockedRegionLabel => 'Region';

  @override
  String get geoBlockedTitle => 'Dienst nicht verfügbar';

  @override
  String get likedVideosEmpty => 'Keine gelikten Videos';

  @override
  String get likedVideosInvalidRoute => 'Ungültige Route';

  @override
  String get likedVideosTitle => 'Gelikte Videos';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Upload wird wiederholt …';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'In Entwürfen speichern';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar =>
      'In Entwürfen gespeichert';

  @override
  String get uploadFailureSheetTitle => 'Upload fehlgeschlagen';

  @override
  String get uploadFailureSheetTryAgainButton => 'Erneut versuchen';

  @override
  String get videoEditorAudioImportAudio => 'Audio importieren';

  @override
  String get videoEditorAudioImportFailed => 'Audio-Import fehlgeschlagen.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn =>
      'Melde dich an, um Videos zu veröffentlichen.';

  @override
  String get publishErrorNoRetry => 'Kein Upload zum Wiederholen.';

  @override
  String get publishErrorNoInternet =>
      'Keine Internetverbindung. Prüfe dein WLAN oder deine mobilen Daten und versuch es erneut.';

  @override
  String get publishErrorServerUnreachable =>
      'Server nicht erreichbar. Versuch es gleich noch einmal.';

  @override
  String get publishErrorTimeout =>
      'Zeitüberschreitung beim Upload. Versuch\'s mit einer stabileren Verbindung oder einem kleineren Video.';

  @override
  String get publishErrorTls =>
      'Sichere Verbindung fehlgeschlagen. Prüfe dein Netzwerk – öffentliches WLAN kann Uploads blockieren.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Der Medienserver ($serverName) ist nicht verfügbar. In den Einstellungen kannst du einen anderen auswählen.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Die Videodatei ist zu groß für den Server. Kürze sie oder verringere die Qualität.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Beim Medienserver ($serverName) ist ein interner Fehler aufgetreten. In den Einstellungen kannst du einen anderen auswählen.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Der Medienserver ($serverName) ist vorübergehend nicht erreichbar. Versuch\'s gleich noch einmal oder wähle in den Einstellungen einen anderen.';
  }

  @override
  String get publishErrorForbidden =>
      'Du hast keine Berechtigung, auf diesen Server hochzuladen.';

  @override
  String get publishErrorFileNotFound =>
      'Die Videodatei wurde nicht gefunden. Vielleicht wurde sie gelöscht. Nimm sie neu auf und versuch es erneut.';

  @override
  String get publishErrorLowStorage =>
      'Nicht genug Speicher auf deinem Gerät. Schaffe etwas Platz und versuch es erneut.';

  @override
  String get publishErrorThumbnailFailed =>
      'Das Video wurde hochgeladen, aber das Vorschaubild konnte nicht erstellt werden. Bitte versuch es erneut.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Das Video wurde hochgeladen, aber der Beitrag konnte nicht veröffentlicht werden. Prüfe deine Relay-Einstellungen und versuch es erneut.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Das Video wurde hochgeladen, aber der Sound ist nicht zur Wiederverwendung freigegeben. Wähl einen anderen Sound, um zu posten.';

  @override
  String get publishErrorInterrupted =>
      'Dieser Upload wurde unterbrochen. Möchtest du es erneut versuchen?';

  @override
  String get publishErrorAccountChanged =>
      'Dieses Video gehört zu einem anderen Konto. Wechsle zurück zu diesem Konto, um es zu posten.';

  @override
  String get publishErrorGeneric =>
      'Etwas ist schiefgelaufen. Bitte versuch es erneut.';

  @override
  String get publishErrorRateLimited =>
      'Zu viele Uploads gerade. Warte einen Moment und versuch es erneut.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Deine Upload-Sitzung ist abgelaufen. Bitte versuch es erneut.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine hat keine Berechtigung zum Hochladen. Prüfe die App-Berechtigungen in den Einstellungen und versuch es erneut.';

  @override
  String get publishErrorOutOfMemory =>
      'Dein Gerät hat wenig Arbeitsspeicher. Schließe ein paar Apps und versuch es erneut.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Text und Sticker dieses Entwurfs konnten nicht vorbereitet werden. Öffne ihn im Editor und poste dann erneut.';

  @override
  String get publishErrorUnknownServer => 'Unbekannter Server';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Keine Ergebnisse für „$query“ gefunden';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Videos mit $tag ansehen';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Sound: $soundName von $creatorName. Tippen, um Sound-Details anzusehen.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Originalton von $creatorName. Tippen, um diesen Sound zu verwenden.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Sound: $soundName von $creatorName. Tippen, um Details anzusehen.';
  }

  @override
  String get soundDetailLoadError =>
      'Sound konnte nicht geladen werden. Bitte versuch es nochmal.';

  @override
  String get soundDetailNotFoundMessage =>
      'Dieser Sound konnte nicht gefunden werden';

  @override
  String get soundDetailNotFoundTitle => 'Sound nicht gefunden';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count Loops';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Der Ton aus diesem Video ist nicht separat verfügbar.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Originalton – $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Diese Person hat ein Original-Vine gepostet, das Divine im Archiv gefunden hat. Das ist kein Verifizierungs-Badge fürs Konto.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Profil-Häkchen';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine vergibt dieses Häkchen an Team-Konten. Das ist unabhängig von NIP-05, verifizierten Konto-Links und dem OG-Viner-Status.';

  @override
  String get unfollowConfirmButton => 'Nicht mehr folgen';

  @override
  String get videoClipSaveFailed => 'Clip konnte nicht gespeichert werden';

  @override
  String videoClipSaveTo(String destination) {
    return 'In $destination speichern';
  }

  @override
  String get videoClipDelete => 'Clip löschen';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspiriert von $creatorName +$additionalCreatorCount. Tippen, um das Profil anzusehen.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspiriert von $creatorName. Tippen, um das Profil anzusehen.';
  }

  @override
  String get bugReportSendReport => 'Bericht senden';

  @override
  String get supportSubjectRequiredLabel => 'Betreff *';

  @override
  String get supportPublicSubmissionTitle => 'Öffentlicher GitHub-Beitrag';

  @override
  String get supportPublicSubmissionMessage =>
      'Alles, was du hier sendest, wird in unserem Open-Source-Repository auf GitHub veröffentlicht, damit Entwickler den Task aufnehmen können. Der Beitrag und das Konto, mit dem du angemeldet bist, sind für alle öffentlich einsehbar.';

  @override
  String get supportRequiredHelper => 'Pflichtfeld';

  @override
  String get supportFieldLimitReached =>
      'Das ist die maximale Länge. Alles darüber hinaus wurde nicht übernommen.';

  @override
  String get bugReportSubjectHint => 'Kurze Zusammenfassung des Problems';

  @override
  String get bugReportDescriptionRequiredLabel => 'Was ist passiert? *';

  @override
  String get bugReportDescriptionHint =>
      'Beschreib das Problem, auf das du gestoßen bist';

  @override
  String get bugReportStepsLabel => 'Schritte zum Reproduzieren';

  @override
  String get bugReportStepsHint =>
      '1. Geh zu...\n2. Tipp auf...\n3. Fehler erscheint';

  @override
  String get bugReportExpectedBehaviorLabel => 'Erwartetes Verhalten';

  @override
  String get bugReportExpectedBehaviorHint =>
      'Was hätte stattdessen passieren sollen?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Geräteinfos und Logs werden automatisch beigelegt.';

  @override
  String get bugReportSuccessMessage =>
      'Danke! Wir haben deinen Bericht erhalten und nutzen ihn, um Divine besser zu machen.';

  @override
  String get bugReportAttachImages => 'Bilder anhängen';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count von $max Bildern ausgewählt';
  }

  @override
  String get bugReportRemoveImage => 'Bild entfernen';

  @override
  String get bugReportUploadFailed =>
      'Wir konnten das ausgewählte Bild nicht hochladen. Versuch es erneut oder schick den Bericht ohne Bild.';

  @override
  String get bugReportSendFailed =>
      'Bug-Bericht konnte nicht gesendet werden. Versuch es später nochmal.';

  @override
  String get featureRequestSendRequest => 'Anfrage senden';

  @override
  String get featureRequestSubjectHint => 'Kurze Zusammenfassung deiner Idee';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Was wünschst du dir? *';

  @override
  String get featureRequestDescriptionHint =>
      'Beschreib das Feature, das du dir wünschst';

  @override
  String get featureRequestUsefulnessLabel => 'Wofür wäre das nützlich?';

  @override
  String get featureRequestUsefulnessHint =>
      'Erklär, was dieses Feature bringen würde';

  @override
  String get featureRequestWhenLabel => 'Wann würdest du das nutzen?';

  @override
  String get featureRequestWhenHint =>
      'Beschreib die Situationen, in denen das helfen würde';

  @override
  String get featureRequestSuccessMessage =>
      'Danke! Wir haben deinen Feature-Wunsch erhalten und schauen ihn uns an.';

  @override
  String get featureRequestSendFailed =>
      'Feature-Wunsch konnte nicht gesendet werden. Versuch es später nochmal.';

  @override
  String get notificationFollowBack => 'Zurückfolgen';

  @override
  String get followingTitle => 'Folge ich';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName folgt';
  }

  @override
  String get followingFailedToLoadList =>
      'Folge-ich-Liste konnte nicht geladen werden';

  @override
  String get followingEmptyTitle => 'Folgst noch niemandem';

  @override
  String get followersTitle => 'Follower';

  @override
  String followersTitleForName(String displayName) {
    return 'Follower von $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Follower-Liste konnte nicht geladen werden';

  @override
  String get followersEmptyTitle => 'Noch keine Follower';

  @override
  String get followersUpdateFollowFailed =>
      'Follow-Status konnte nicht aktualisiert werden. Versuch es nochmal.';

  @override
  String get followersSortSemanticLabel => 'Follower sortieren';

  @override
  String get followingSortSemanticLabel => 'Gefolgte sortieren';

  @override
  String get followSortTitle => 'Sortieren nach';

  @override
  String get followSortNewest => 'Neueste zuerst';

  @override
  String get followSortOldest => 'Älteste zuerst';

  @override
  String get newMessageTitle => 'Neue Nachricht';

  @override
  String get newMessageFindPeople => 'Leute finden';

  @override
  String get newMessageNoContacts =>
      'Keine Kontakte gefunden.\nFolg Leuten, um sie hier zu sehen.';

  @override
  String get newMessageNoUsersFound => 'Keine Nutzer gefunden';

  @override
  String get hashtagSearchTitle => 'Nach Hashtags suchen';

  @override
  String get hashtagSearchSubtitle => 'Trends und Inhalte entdecken';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Keine Hashtags für „$query“ gefunden';
  }

  @override
  String get hashtagSearchFailed => 'Suche fehlgeschlagen';

  @override
  String get userNotAvailableTitle => 'Konto nicht verfügbar';

  @override
  String get userNotAvailableBody => 'Dieses Konto ist gerade nicht verfügbar.';

  @override
  String get classicVinersTitle => 'OG Viner';

  @override
  String get blossomFailedToSaveSettings =>
      'Einstellungen konnten nicht gespeichert werden. Bitte versuch es nochmal.';

  @override
  String get blossomValidServerUrl =>
      'Bitte gib eine gültige Server-URL ein (z. B. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom-Einstellungen gespeichert';

  @override
  String get blossomSaveTooltip => 'Speichern';

  @override
  String get blossomAboutTitle => 'Über Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom ist ein dezentrales Medienspeicher-Protokoll, mit dem du Videos auf jeden kompatiblen Server hochladen kannst. Standardmäßig werden Videos auf den Blossom-Server von Divine hochgeladen. Aktivier die Option unten, um stattdessen einen eigenen Server zu nutzen.';

  @override
  String get blossomUseCustomServer => 'Eigenen Blossom-Server nutzen';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Videos werden auf deinen eigenen Blossom-Server hochgeladen';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Deine Videos werden gerade auf den Blossom-Server von Divine hochgeladen';

  @override
  String get blossomCustomServerUrl => 'URL des eigenen Blossom-Servers';

  @override
  String get blossomCustomServerHelper =>
      'Gib die URL deines eigenen Blossom-Servers ein';

  @override
  String get blossomPopularServers => 'Beliebte Blossom-Server';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom-Server-URL muss https:// nutzen';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Crosspost-Einstellung konnte nicht aktualisiert werden';

  @override
  String get blueskySignInRequired =>
      'Melde dich an, um Bluesky-Einstellungen zu verwalten';

  @override
  String get blueskyPublishVideos => 'Videos auf Bluesky veröffentlichen';

  @override
  String get blueskyEnabledSubtitle =>
      'Deine Videos werden auf Bluesky veröffentlicht';

  @override
  String get blueskyDisabledSubtitle =>
      'Deine Videos werden nicht auf Bluesky veröffentlicht';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Deine früheren Videos werden auch gepostet';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Wenn du das aktivierst, sendet Divine deine älteren Videos an Bluesky, die ältesten zuerst, ohne das Tageslimit zu überstürzen.';

  @override
  String get blueskyHandle => 'Bluesky-Handle';

  @override
  String get blueskyDid => 'Bluesky-DID';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Konto bereitgestellt und einsatzbereit';

  @override
  String get blueskyStatusPending => 'Konto wird bereitgestellt...';

  @override
  String get blueskyStatusFailed => 'Kontobereitstellung fehlgeschlagen';

  @override
  String get blueskyStatusDisabled => 'Konto deaktiviert';

  @override
  String get blueskyStatusNotLinked => 'Kein Bluesky-Konto verknüpft';

  @override
  String get blueskyUsernameRequired =>
      'Richte einen divine.video-Handle ein, bevor du auf Bluesky veröffentlichst';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Zum Veröffentlichen auf Bluesky brauchst du einen beanspruchten nutzername.divine.video-Handle.';

  @override
  String get blueskyUsernameSyncPending =>
      'Dein Divine-Handle ist beansprucht. Wir verknüpfen ihn gerade mit Bluesky – versuch es gleich noch einmal.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Wir konnten deinen Divine-Handle nicht prüfen. Versuch es erneut.';

  @override
  String get blueskySetUpHandle => 'Einrichten';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Das Veröffentlichen auf Bluesky ist vorübergehend nicht verfügbar. Bitte versuch es erneut.';

  @override
  String get invitesTitle => 'Freunde einladen';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einladungen bereit zum Erstellen',
      one: '1 Einladung bereit zum Erstellen',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Erstell einen Code, wenn du bereit bist, einen zu teilen.';

  @override
  String get invitesGenerateButtonLabel => 'Einladung erstellen';

  @override
  String get invitesNoneAvailable => 'Gerade keine Einladungen verfügbar';

  @override
  String get invitesShareWithPeople => 'Teil Divine mit Leuten, die du kennst';

  @override
  String get invitesUsedInvites => 'Eingelöste Einladungen';

  @override
  String invitesShareMessage(String code) {
    return 'Komm zu mir auf Divine! Nutz den Einladungscode $code, um loszulegen:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Einladung kopieren';

  @override
  String get invitesCopied => 'Einladung kopiert!';

  @override
  String get invitesShareInvite => 'Einladung teilen';

  @override
  String get invitesShareSubject => 'Komm zu mir auf Divine';

  @override
  String get invitesClaimed => 'Eingelöst';

  @override
  String get invitesCouldNotLoad => 'Einladungen konnten nicht geladen werden';

  @override
  String get invitesRetry => 'Erneut versuchen';

  @override
  String get searchSomethingWentWrong => 'Etwas ist schiefgelaufen';

  @override
  String get searchTryAgain => 'Erneut versuchen';

  @override
  String get searchForLists => 'Nach Listen suchen';

  @override
  String get searchFindCuratedVideoLists => 'Kuratierte Videolisten finden';

  @override
  String get searchEnterQuery => 'Suchbegriff eingeben';

  @override
  String get searchDiscoverSomethingInteresting =>
      'Entdecke etwas Interessantes';

  @override
  String get searchPeopleSectionHeader => 'Personen';

  @override
  String get searchPeopleLoadingLabel => 'Personenergebnisse werden geladen';

  @override
  String get searchTagsSectionHeader => 'Tags';

  @override
  String get searchTagsLoadingLabel => 'Tag-Ergebnisse werden geladen';

  @override
  String get searchVideosSectionHeader => 'Videos';

  @override
  String get searchVideosLoadingLabel => 'Videoergebnisse werden geladen';

  @override
  String get searchVideosSortOptionsLabel => 'Videoergebnisse sortieren';

  @override
  String get searchVideosSortTrending => 'Angesagt';

  @override
  String get searchVideosSortLoops => 'Meiste Loops';

  @override
  String get searchVideosSortEngagement => 'Meiste Interaktionen';

  @override
  String get searchVideosSortRecent => 'Neueste';

  @override
  String get searchListsSectionHeader => 'Listen';

  @override
  String get searchListsLoadingLabel => 'Listenergebnisse werden geladen';

  @override
  String get cameraAgeRestriction =>
      'Du musst mindestens 16 Jahre alt sein, um Inhalte zu erstellen';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker-Relay muss wss:// nutzen (ws:// ist nur für localhost erlaubt)';

  @override
  String get timeNow => 'jetzt';

  @override
  String timeShortMinutes(int count) {
    return '$count Min';
  }

  @override
  String timeShortHours(int count) {
    return '$count Std';
  }

  @override
  String timeShortDays(int count) {
    return '$count T';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count W';
  }

  @override
  String timeShortMonths(int count) {
    return '$count Mo';
  }

  @override
  String timeShortYears(int count) {
    return '$count J';
  }

  @override
  String get timeVerboseNow => 'Jetzt';

  @override
  String timeAgo(String time) {
    return 'vor $time';
  }

  @override
  String get timeToday => 'Heute';

  @override
  String get timeYesterday => 'Gestern';

  @override
  String get timeJustNow => 'gerade eben';

  @override
  String timeMinutesAgo(int count) {
    return 'vor $count Min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'vor $count Std';
  }

  @override
  String timeDaysAgo(int count) {
    return 'vor $count T';
  }

  @override
  String get draftTimeJustNow => 'Gerade eben';

  @override
  String get contentLabelNudity => 'Nacktheit';

  @override
  String get contentLabelSexualContent => 'Sexueller Inhalt';

  @override
  String get contentLabelPornography => 'Pornografie';

  @override
  String get contentLabelGraphicMedia => 'Verstörende Inhalte';

  @override
  String get contentLabelViolence => 'Gewalt';

  @override
  String get contentLabelSelfHarm => 'Selbstverletzung/Suizid';

  @override
  String get contentLabelDrugUse => 'Drogenkonsum';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tabak/Rauchen';

  @override
  String get contentLabelGambling => 'Glücksspiel';

  @override
  String get contentLabelProfanity => 'Vulgärsprache';

  @override
  String get contentLabelHateSpeech => 'Hassrede';

  @override
  String get contentLabelHarassment => 'Belästigung';

  @override
  String get contentLabelFlashingLights => 'Blitzlichter';

  @override
  String get contentLabelAiGenerated => 'KI-generiert';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Betrug';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Irreführend';

  @override
  String get contentLabelSensitiveContent => 'Sensibler Inhalt';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName hat dein Video geliked';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName hat deinen Kommentar geliked';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName hat dein Video kommentiert';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName folgt dir jetzt';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName hat dich erwähnt';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName hat dein Video geteilt';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName hat einen neuen Vine gepostet';
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
      other: '$count deiner Vines',
      one: 'deine Vine',
    );
    return '$actorName hat $_temp0 zu $listName hinzugefügt';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName hat auf deinen Kommentar geantwortet';
  }

  @override
  String get notificationAndConnector => 'und';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Personen',
      one: '1 weitere Person',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Du hast eine neue Aktualisierung';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Tastatur ausblenden';

  @override
  String get commentsErrorLoadFailed =>
      'Kommentare konnten nicht geladen werden';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Melde dich an, um zu kommentieren';

  @override
  String get commentsErrorPostCommentFailed =>
      'Kommentar konnte nicht gepostet werden';

  @override
  String get commentsErrorPostReplyFailed =>
      'Antwort konnte nicht gepostet werden';

  @override
  String get commentsErrorEditFailed =>
      'Kommentar konnte nicht bearbeitet werden';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Melde dich an, um mitzumachen';

  @override
  String get commentsErrorVoteFailed =>
      'Abstimmen über den Kommentar fehlgeschlagen';

  @override
  String get commentsErrorReportFailed =>
      'Kommentar konnte nicht gemeldet werden';

  @override
  String get commentsErrorBlockFailed => 'Person konnte nicht blockiert werden';

  @override
  String get commentsErrorDeleteFailed =>
      'Kommentar konnte nicht gelöscht werden';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kommentare',
      one: '$count Kommentar',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Wird gepostet…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Deine Videoantwort wird gepostet';

  @override
  String get commentsSortNew => 'Neu';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get commentsSortOld => 'Alt';

  @override
  String get commentsSortSemanticLabel => 'Kommentare sortieren';

  @override
  String get commentReply => 'Antworten';

  @override
  String get commentReplySemanticLabel => 'Auf Kommentar antworten';

  @override
  String get commentUpvoteLabel => 'Kommentar hochstufen';

  @override
  String get commentRemoveUpvoteLabel => 'Hochstufung entfernen';

  @override
  String get commentDownvoteLabel => 'Kommentar runterstufen';

  @override
  String get commentRemoveDownvoteLabel => 'Runterstufung entfernen';

  @override
  String get commentsInputHint => 'Kommentar hinzufügen …';

  @override
  String get commentsInputHintEdit => 'Kommentar bearbeiten …';

  @override
  String get commentsEmptyTitle => 'Noch keine Kommentare';

  @override
  String get commentsEmptySubtitle => 'Mach den Anfang!';

  @override
  String get draftUntitled => 'Ohne Titel';

  @override
  String get contentWarningNone => 'Keine';

  @override
  String get textBackgroundNone => 'Keine';

  @override
  String get textBackgroundSolid => 'Deckend';

  @override
  String get textBackgroundHighlight => 'Hervorhebung';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Links';

  @override
  String get textAlignRight => 'Rechts';

  @override
  String get textAlignCenter => 'Zentriert';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kamera wird im Web noch nicht unterstützt';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Kameraaufnahme und -aufzeichnung sind in der Webversion noch nicht verfügbar.';

  @override
  String get cameraPermissionBackToFeed => 'Zurück zum Feed';

  @override
  String get cameraCouldNotStart => 'Kamera konnte nicht gestartet werden';

  @override
  String get cameraUnsupportedPlatform =>
      'Die Kamera ist auf dieser Plattform noch nicht verfügbar.\nDu kannst trotzdem Videos ansehen.';

  @override
  String get cameraPermissionErrorTitle => 'Berechtigungsfehler';

  @override
  String get cameraPermissionErrorDescription =>
      'Beim Prüfen der Berechtigungen ist etwas schiefgelaufen.';

  @override
  String get cameraPermissionRetry => 'Erneut versuchen';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Kamera- und Mikrofonzugriff erlauben';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Damit kannst du Videos direkt hier in der App aufnehmen und bearbeiten, sonst nichts.';

  @override
  String get cameraPermissionGoToSettings => 'Zu den Einstellungen';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Warum sechs Sekunden?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Kurze Clips schaffen Raum für Spontanität. Das 6-Sekunden-Format hilft dir, echte Momente festzuhalten, während sie passieren.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Verstanden!';

  @override
  String get videoRecorderUploadTitle => 'Warum kein Upload?';

  @override
  String get videoRecorderUploadBody =>
      'Was du auf Divine siehst, ist von Menschen gemacht: roh und im Moment aufgenommen. Anders als Plattformen, die stark produzierte oder KI-generierte Uploads erlauben, setzen wir auf die Authentizität der Kamera-direkten Erfahrung.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Indem wir die Erstellung in der App halten, können wir besser garantieren, dass die Inhalte echt und unbearbeitet sind. Wir öffnen externe Galerie-Uploads derzeit nicht, um diese Echtheit zu schützen und unsere Community so weit wie möglich frei von synthetischen Inhalten zu halten.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Wechsle zu Capture oder Classic, um etwas Echtes aufzunehmen.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Erfahre, wie die Verifizierung funktioniert';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Wir haben einen Entwurf gefunden';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Möchtest du dort weitermachen, wo du aufgehört hast?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Ja, weiter';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Nein, neues Video starten';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Dein Entwurf konnte nicht wiederhergestellt werden';

  @override
  String get videoRecorderStopRecordingTooltip => 'Aufnahme stoppen';

  @override
  String get videoRecorderStartRecordingTooltip => 'Aufnahme starten';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Aufnahme läuft. Tippe irgendwo, um zu stoppen';

  @override
  String get videoRecorderTapToStartLabel =>
      'Tippe irgendwo, um die Aufnahme zu starten';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Letzten Clip löschen';

  @override
  String get videoRecorderSwitchCameraLabel => 'Kamera wechseln';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Auf $zoom× zoomen';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Raster ein-/ausblenden';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Geisterbild ein-/ausblenden';

  @override
  String get videoRecorderGhostFrameEnabled => 'Geisterbild aktiviert';

  @override
  String get videoRecorderGhostFrameDisabled => 'Geisterbild deaktiviert';

  @override
  String get videoRecorderClipDeletedMessage =>
      'Clip in den Papierkorb verschoben';

  @override
  String get videoRecorderClipUndoLabel => 'Rückgängig';

  @override
  String get libraryTrashEmptyTitle => 'Papierkorb ist leer';

  @override
  String get libraryTrashEmptySubtitle =>
      'Gelöschte Clips bleiben 30 Tage hier, bevor sie endgültig entfernt werden.';

  @override
  String get libraryTrashRestoreLabel => 'Wiederherstellen';

  @override
  String get libraryTrashDeleteNowLabel => 'Jetzt löschen';

  @override
  String get libraryTrashEmptyAllLabel => 'Papierkorb leeren';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Clip jetzt löschen?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Dadurch wird der Clip sofort aus dem Papierkorb entfernt.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Papierkorb leeren?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips',
      one: '1 Clip',
    );
    return '$_temp0 werden sofort dauerhaft aus dem Papierkorb gelöscht.';
  }

  @override
  String get videoRecorderCloseLabel => 'Videorecorder schließen';

  @override
  String get videoRecorderContinueToEditorLabel => 'Zum Videoeditor weiter';

  @override
  String get videoRecorderCameraPreviewLabel => 'Kameravorschau';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Kamera fokussieren';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Zum Modus „$mode“ wechseln';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Audio vor der Aufnahme hinzufügen';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Video konnte nicht erstellt werden. Bitte erneut versuchen.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Aufnahmen übrig',
      one: 'Noch 1 Aufnahme übrig',
      zero: 'Keine Aufnahmen mehr übrig',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Blitz ein-/ausschalten';

  @override
  String get videoRecorderCycleTimerLabel => 'Timer wechseln';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Seitenverhältnis wechseln';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilisierung';

  @override
  String get videoRecorderStabilizationModeOff => 'Aus';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Filmisch';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematic erweitert';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Vorschau-optimiert';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Niedrige Latenz';

  @override
  String get videoRecorderStabilizationModeAuto => 'Auto';

  @override
  String get videoRecorderFlashValueOff => 'Aus';

  @override
  String get videoRecorderFlashValueOn => 'Ein';

  @override
  String get videoRecorderFlashValueAuto => 'Auto';

  @override
  String get videoRecorderTimerValueOff => 'Aus';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 Sekunden';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 Sekunden';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Quadratisch';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Hochformat';

  @override
  String get videoRecorderCameraValueFront => 'Frontkamera';

  @override
  String get videoRecorderCameraValueBack => 'Rückkamera';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Clip-Mediathek, keine Clips';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Clip-Mediathek öffnen, $clipCount Clips',
      one: 'Clip-Mediathek öffnen, 1 Clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Stop-Motion-Mediathek öffnen, $frameCount Frames',
      one: 'Stop-Motion-Mediathek öffnen, 1 Frame',
      zero: 'Stop-Motion-Mediathek öffnen',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Kamera öffnen';

  @override
  String get videoEditorLibraryLabel => 'Mediathek';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Zeichnen';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorTuneLabel => 'Anpassen';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Anpassungseditor öffnen';

  @override
  String get videoEditorTuneBrightness => 'Helligkeit';

  @override
  String get videoEditorTuneContrast => 'Kontrast';

  @override
  String get videoEditorTuneSaturation => 'Sättigung';

  @override
  String get videoEditorTuneExposure => 'Belichtung';

  @override
  String get videoEditorTuneHue => 'Farbton';

  @override
  String get videoEditorTuneTemperature => 'Temperatur';

  @override
  String get videoEditorTuneTint => 'Tönung';

  @override
  String get videoEditorTuneFade => 'Verblassen';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Hinzufügen';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Mediathek öffnen';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Audio-Editor öffnen';

  @override
  String get videoEditorCaptionsLabel => 'Untertitel';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'Untertitel-Editor öffnen';

  @override
  String get videoEditorCaptionsBurnInLabel => 'In Video einbrennen';

  @override
  String get videoEditorCaptionsPresetCustom => 'Eigen';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Eigener Stil';

  @override
  String get videoEditorCaptionsCustomApply => 'Anwenden';

  @override
  String get videoEditorCaptionsCustomFont => 'Schrift';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Textfarbe';

  @override
  String get videoEditorCaptionsCustomBackground => 'Hintergrund';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Hintergrundfarbe';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animation';

  @override
  String get videoEditorCaptionsAnimationNone => 'Keine';

  @override
  String get videoEditorCaptionsAnimationFade => 'Einblenden';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Feder';

  @override
  String get videoEditorCaptionsEditTitle => 'Untertitel';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Wir hören zu…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Wir machen aus deinem Audio Untertitel-Vorschläge.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Wir konnten keine Sprache hören. Du kannst die Untertitel trotzdem selbst schreiben.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Spracherkennung ist auf diesem Gerät nicht verfügbar. Du kannst die Untertitel selbst schreiben.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Spracherkennung ist nicht erlaubt. Aktiviere sie in den Einstellungen oder schreib die Untertitel selbst.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Die Transkription hat diesmal nicht geklappt. Du kannst die Untertitel selbst schreiben.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Untertitel selbst schreiben';

  @override
  String get videoEditorCaptionsAddCue => 'Untertitel hinzufügen';

  @override
  String get videoEditorCaptionsCueTextHint => 'Untertiteltext';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Untertitel löschen';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Alle Untertitel entfernen';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Untertitel entfernen?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Alle Texte und Zeiten gehen verloren.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Untertitel-Editor schließen';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Untertitel bestätigen';

  @override
  String get videoEditorCaptionsPresetTitle => 'Untertitel-Style';

  @override
  String get videoEditorCaptionsPresetClassic => 'Klassisch';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Schlagzeile';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Schreibmaschine';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marker';

  @override
  String get videoEditorCaptionsPresetScript => 'Schreibschrift';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegant';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bubble';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Fett';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Verträumt';

  @override
  String get videoEditorCaptionsPresetOcean => 'Ozean';

  @override
  String get videoEditorCaptionsPresetSunny => 'Sonnig';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Handschrift';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Stempel';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Text-Editor öffnen';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Zeichen-Editor öffnen';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Filter-Editor öffnen';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Sticker-Editor öffnen';

  @override
  String get videoEditorSaveDraftTitle => 'Entwurf speichern?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Bewahre deine Bearbeitungen für später auf oder verwerfe sie und verlasse den Editor.';

  @override
  String get videoEditorSaveDraftButton => 'Entwurf speichern';

  @override
  String get videoEditorDiscardChangesButton => 'Änderungen verwerfen';

  @override
  String get videoEditorKeepEditingButton => 'Weiter bearbeiten';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Drop-Zone zum Löschen von Ebenen';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Loslassen, um Ebene zu löschen';

  @override
  String get videoEditorDoneLabel => 'Fertig';

  @override
  String get videoEditorPlayPauseSemanticLabel =>
      'Video abspielen oder pausieren';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Ungültige Teilungsposition. Beide Clips müssen mindestens $minDurationMs ms lang sein.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Ausgewählten Clip speichern';

  @override
  String get videoEditorSaveClip => 'Clip speichern';

  @override
  String get videoEditorClipSavedSuccess => 'Clip in Mediathek gespeichert';

  @override
  String get videoEditorClipSaveFailed =>
      'Clip konnte nicht gespeichert werden';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Farbwähler';

  @override
  String get videoEditorUndoSemanticLabel => 'Rückgängig';

  @override
  String get videoEditorRedoSemanticLabel => 'Wiederholen';

  @override
  String get videoEditorTextColorSemanticLabel => 'Textfarbe';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Textausrichtung';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Texthintergrund';

  @override
  String get videoEditorFontSemanticLabel => 'Schriftart';

  @override
  String get videoEditorNoStickersFound => 'Keine Sticker gefunden';

  @override
  String get videoEditorNoStickersAvailable => 'Keine Sticker verfügbar';

  @override
  String get videoEditorFailedLoadStickers =>
      'Sticker konnten nicht geladen werden';

  @override
  String get videoEditorVoiceOverLabel => 'Voiceover';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Aufnahme $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Voiceover aufnehmen';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Aufnahme starten';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Aufnahme stoppen';

  @override
  String get videoEditorVoiceOverHint =>
      'Zum Aufnehmen tippen. Nimm so viele Takes auf, wie du möchtest.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen',
      one: '1 Aufnahme',
      zero: 'Noch keine Aufnahmen',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Letzte Aufnahme löschen';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Mikrofonzugriff erforderlich';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Erlaube den Mikrofonzugriff, um ein Voiceover aufzunehmen.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Einstellungen öffnen';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Aufnahme gestartet';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Aufnahme gespeichert';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Aufnahme ist länger als dein Video';

  @override
  String get videoEditorPlaySemanticLabel => 'Abspielen';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausieren';

  @override
  String get videoEditorVolumeSemanticLabel => 'Lautstärke anpassen';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Lautstärke $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Zum Anpassen schieben';

  @override
  String get videoEditorChromaKeyLabel => 'Greenscreen';

  @override
  String get videoEditorChromaKeyTitle => 'Greenscreen';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Greenscreen für diesen Clip einrichten';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Greenscreen-Änderungen verwerfen';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Greenscreen anwenden';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Automatisch erkennen';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Grün';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Blau';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Screen-Farbe';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Stärke';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Wie viel von der Screen-Farbe verschwindet';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Kante';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Macht den Ausschnitt weicher, damit Haare nicht ausfransen';

  @override
  String get videoEditorChromaKeySpillLabel => 'Farbstich';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Zieht die Screen-Farbe von deinem Motiv ab';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Ersetzen durch';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Nichts';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Farbe';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Bild';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Video kann keine Transparenz speichern – das wird beim Export schwarz.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Kein Screen gefunden. Er muss bis an den Bildrand reichen – wähl die Farbe sonst von Hand.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Clip auswählen';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Deine Bibliothek ist leer. Speicher erst einen Clip, dann kannst du ihn als Hintergrund nutzen.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Das Bild konnte nicht geladen werden.';

  @override
  String get videoEditorChromaKeyRemove => 'Greenscreen entfernen';

  @override
  String get videoEditorChromaKeyFailed =>
      'Der Greenscreen konnte nicht angewendet werden. Dein Clip bleibt unverändert.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Der Greenscreen konnte nicht entfernt werden. Dein Clip bleibt unverändert.';

  @override
  String get videoEditorChromaKeyApplying => 'Greenscreen wird angewendet …';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Dieses Gerät kann die Live-Vorschau nicht zeigen. Deine Einstellungen wirken beim Export trotzdem.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Löschen';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Ausgewähltes Element löschen';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Frames pro Bild';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Frames',
      one: '1 Frame',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Frames';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count Frames pro Bild';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Stop-Motion-Bild $position von $total';
  }

  @override
  String get videoEditorEditLabel => 'Bearbeiten';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Ausgewähltes Element bearbeiten';

  @override
  String get videoEditorDuplicateLabel => 'Duplizieren';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Ausgewähltes Element duplizieren';

  @override
  String get videoEditorCombineLabel => 'Zusammenführen';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Ausgewählte Zeichnungen zu einer Ebene zusammenführen';

  @override
  String get videoEditorSplitLabel => 'Teilen';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Ausgewählten Clip teilen';

  @override
  String get videoEditorExtractAudioLabel => 'Audio extrahieren';

  @override
  String get videoEditorClipAudioTitle => 'Clip-Audio';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Audio aus Clip extrahieren und Original stummschalten';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Audio kann nicht extrahiert werden: Clip ist lokal nicht verfügbar.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Audio konnte nicht extrahiert werden. Bitte erneut versuchen.';

  @override
  String get videoEditorSpeedLabel => 'Geschwindigkeit';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Wiedergabegeschwindigkeit für ausgewählten Clip festlegen';

  @override
  String get videoEditorReverseLabel => 'Rückwärts';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Rückwärtswiedergabe für ausgewählten Clip umschalten';

  @override
  String get videoEditorReverseProgressLabel =>
      'Einen Moment, wir drehen deinen Clip rückwärts';

  @override
  String get videoEditorTransformLabel => 'Transformieren';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Ausgewählten Clip zuschneiden, drehen oder spiegeln';

  @override
  String get videoEditorTransformProgressLabel =>
      'Einen Moment, wir transformieren deinen Clip';

  @override
  String get videoEditorTransformFailed =>
      'Clip konnte nicht transformiert werden. Bitte versuche es erneut.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Transformieren nicht möglich: Clip ist nicht lokal verfügbar.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Ausgewähltes Frame zuschneiden, drehen oder spiegeln';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Einen Moment, wir transformieren dein Frame';

  @override
  String get videoEditorTransformFrameFailed =>
      'Frame konnte nicht transformiert werden. Bitte versuche es erneut.';

  @override
  String get videoEditorTransformRotateLabel => 'Drehen';

  @override
  String get videoEditorTransformFlipLabel => 'Spiegeln';

  @override
  String get videoEditorTransformResetLabel => 'Zurücksetzen';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'Transformation anwenden';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Transformation abbrechen';

  @override
  String get videoEditorTransformPlayLabel => 'Abspielen';

  @override
  String get videoEditorTransformPauseLabel => 'Pause';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Rückwärtsdrehen nicht möglich: Clip ist lokal nicht verfügbar.';

  @override
  String get videoEditorReverseFailed =>
      'Clip konnte nicht rückwärts gedreht werden. Bitte erneut versuchen.';

  @override
  String get videoEditorSpeedSheetTitle => 'Clip-Geschwindigkeit';

  @override
  String get videoEditorTransitionSheetTitle => 'Übergang';

  @override
  String get videoEditorTransitionNone => 'Kein';

  @override
  String get videoEditorTransitionDissolve => 'Überblenden';

  @override
  String get videoEditorTransitionFadeToBlack => 'Schwarzblende';

  @override
  String get videoEditorTransitionFadeToWhite => 'Weißblende';

  @override
  String get videoEditorTransitionSlide => 'Schieben';

  @override
  String get videoEditorTransitionPush => 'Verdrängen';

  @override
  String get videoEditorTransitionWipe => 'Wischen';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Übergang bearbeiten';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Loop-Übergang';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Loop-Übergang bearbeiten';

  @override
  String get videoEditorTransitionDuration => 'Dauer';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Gekürzt, damit sie sich nicht mit dem benachbarten Übergang überlappt.';

  @override
  String get videoEditorTransitionCurve => 'Kurve';

  @override
  String get videoEditorTransitionDirection => 'Richtung';

  @override
  String get videoEditorTransitionDirectionLeft => 'Links';

  @override
  String get videoEditorTransitionDirectionRight => 'Rechts';

  @override
  String get videoEditorTransitionDirectionUp => 'Oben';

  @override
  String get videoEditorTransitionDirectionDown => 'Unten';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Animationskurve $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animation';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Ebenen-Animation bearbeiten';

  @override
  String get videoEditorLayerAnimationEnter => 'Eingang';

  @override
  String get videoEditorLayerAnimationLeave => 'Ausgang';

  @override
  String get videoEditorLayerAnimationFade => 'Überblenden';

  @override
  String get videoEditorLayerAnimationScale => 'Skalieren';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Skalieren von';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Timeline-Bearbeitung abschließen';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Vorschau abspielen';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Vorschau pausieren';

  @override
  String get videoEditorAudioUntitledSound => 'Unbenannter Sound';

  @override
  String get videoEditorAudioUntitled => 'Unbenannt';

  @override
  String get videoEditorAudioAddAudio => 'Audio hinzufügen';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Keine Sounds verfügbar';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Sounds erscheinen hier, wenn Creator Audio teilen';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Sounds konnten nicht geladen werden';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Wähle den Audiobereich für dein Video aus';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Community';

  @override
  String get videoEditorAudioCategoryFeatured => 'Vorgestellt';

  @override
  String get videoEditorAudioCategoryMySounds => 'Meine Sounds';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Pfeil-Werkzeug';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Radiergummi-Werkzeug';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Marker-Werkzeug';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Bleistift-Werkzeug';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Timeline anzeigen';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Timeline ausblenden';

  @override
  String get videoEditorFeedPreviewContent =>
      'Vermeide es, Inhalte hinter diesen Bereichen zu platzieren.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originale';

  @override
  String get videoEditorStickerSearchHint => 'Sticker suchen...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Schriftart auswählen';

  @override
  String get videoEditorFontUnknown => 'Unbekannt';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Der Abspielkopf muss innerhalb des ausgewählten Clips liegen, um zu teilen.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Anfang trimmen';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Ende trimmen';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Clip trimmen';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Ziehe die Griffe, um die Clip-Dauer anzupassen';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Clip $index wird gezogen';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index von $total, $duration Sekunden';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Lange drücken zum Neuordnen';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Nach links verschieben';

  @override
  String get videoEditorTimelineClipMoveRight => 'Nach rechts verschieben';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index von $total, ausgewählt';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index von $total, nicht ausgewählt';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Auswählen';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Mehrere Clips auswählen';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Auswahl abschließen';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips ausgewählt',
      one: '1 Clip ausgewählt',
      zero: 'Keine Clips ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Mehrere Zeichnungen auswählen';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Auswahl der Zeichnungen abschließen';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Ausgewählte Zeichnungen löschen';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeichnungen ausgewählt',
      one: '1 Zeichnung ausgewählt',
      zero: 'Keine Zeichnungen ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Zusammenführen';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Ausgewählte Clips zusammenführen';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Ausgewählte Clips löschen';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Ausgewählte Frames löschen';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Ausgewählte Frames umkehren';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Ausgewählte Frames duplizieren';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Dein Video braucht mindestens ${seconds}s – nimm noch ein paar Frames auf.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Einen Moment, wir führen deine Clips zusammen';

  @override
  String get videoEditorMergeFailed =>
      'Clips konnten nicht zusammengeführt werden. Bitte versuche es erneut.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Lange drücken zum Ziehen';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Video-Timeline';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes Min $seconds Sek';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, ausgewählt';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Farbwähler schließen';

  @override
  String get videoEditorPickColorTitle => 'Farbe auswählen';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Farbe bestätigen';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Sättigung und Helligkeit';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Sättigung $saturation %, Helligkeit $brightness %';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Farbton';

  @override
  String get videoEditorAddElementSemanticLabel => 'Element hinzufügen';

  @override
  String get videoEditorDoneSemanticLabel => 'Fertig';

  @override
  String get videoEditorLevelSemanticLabel => 'Stufe';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Beitragsdetails schließen';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Hilfedialog schließen';

  @override
  String get videoMetadataGotItButton => 'Verstanden!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB-Limit erreicht. Entferne einige Inhalte, um fortzufahren.';

  @override
  String get videoMetadataExpirationLabel => 'Verfallszeit';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Verfallszeit auswählen';

  @override
  String get videoMetadataTitleLabel => 'Titel';

  @override
  String get videoMetadataDescriptionLabel => 'Beschreibung';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Tag $tag löschen';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Inhaltswarnung';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Inhaltswarnungen auswählen';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Wähle alles aus, was auf deinen Inhalt zutrifft';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Lass andere den Audio dieses Videos speichern und wiederverwenden.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Dein Video ist online, aber der Sound wurde nicht veröffentlicht. Bearbeite das Video, um ihn zu teilen.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Mitwirkende';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Mitwirkende hinzufügen';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Gemeinsame Follower';

  @override
  String get videoMetadataInspiredByLabel => 'Inspiriert von';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      '\"Inspiriert von\" festlegen';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Dieser Creator kann nicht referenziert werden.';

  @override
  String get videoMetadataPostDetailsTitle => 'Beitragsdetails';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'In Mediathek gespeichert';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Speichern fehlgeschlagen';

  @override
  String get videoMetadataGoToLibraryButton => 'Zur Mediathek';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Button \"Für später speichern\"';

  @override
  String get videoMetadataSavingVideoHint => 'Video wird gespeichert...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Video als Entwurf speichern und $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Video als Entwurf speichern. Noch kein gerendertes Video, daher keine Kopie in $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Für später speichern';

  @override
  String get videoMetadataPostSemanticLabel => 'Button \"Posten\"';

  @override
  String get videoMetadataPublishVideoHint => 'Video im Feed veröffentlichen';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Auch in meinem Feed teilen';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Aus bedeutet, dass dieses Video nur im Kommentar-Thread bleibt.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Fülle das Formular aus, um es zu aktivieren';

  @override
  String get videoMetadataPostButton => 'Posten';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Vorschau-Bildschirm des Beitrags öffnen';

  @override
  String get videoMetadataShareTitle => 'Teilen';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Videodetails';

  @override
  String get videoMetadataClassicDoneButton => 'Fertig';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Vorschau abspielen';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Vorschau pausieren';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Videovorschau schließen';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Entfernen';

  @override
  String get fullscreenFeedRemovedMessage => 'Video entfernt';

  @override
  String get fullscreenFeedEmptyMessage =>
      'Hier gibt es nichts mehr abzuspielen';

  @override
  String get settingsBadgesTitle => 'Abzeichen';

  @override
  String get settingsBadgesSubtitle =>
      'Auszeichnungen annehmen und Status vergebener Badges prüfen.';

  @override
  String get badgesTitle => 'Abzeichen';

  @override
  String get badgesLoadError => 'Badges konnten nicht geladen werden';

  @override
  String get badgesUpdateError => 'Badge konnte nicht aktualisiert werden';

  @override
  String get badgesAwardedEmptyTitle => 'Noch keine Badge-Auszeichnungen';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Wenn dir jemand ein Nostr-Badge verleiht, landet es hier.';

  @override
  String get badgesStatusAccepted => 'Angenommen';

  @override
  String get badgesStatusNotAccepted => 'Nicht angenommen';

  @override
  String get badgesActionRemove => 'Entfernen';

  @override
  String get badgesActionAccept => 'Annehmen';

  @override
  String get badgesActionReject => 'Ablehnen';

  @override
  String get badgesIssuedEmptyTitle => 'Noch keine vergebenen Badges';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Badges, die du vergibst, zeigen hier ihren Annahmestatus.';

  @override
  String get badgesIssuedNoRecipients =>
      'Keine Empfänger für diese Auszeichnung gefunden.';

  @override
  String get badgesRecipientAcceptedStatus => 'Vom Empfänger angenommen';

  @override
  String get badgesRecipientWaitingStatus => 'Wartet auf Empfänger';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ausgeblendet ($count)',
      one: 'Ausgeblendet (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Wiederherstellen';

  @override
  String get badgesHiddenSnackbar => 'Badge ausgeblendet';

  @override
  String get badgesHiddenSnackbarUndo => 'Rückgängig';

  @override
  String get badgesTabAwarded => 'Erhalten';

  @override
  String get badgesTabCreated => 'Erstellt';

  @override
  String get badgesTabIssued => 'Vergeben';

  @override
  String get badgesCreateAction => 'Neues Badge';

  @override
  String get badgesCreatedEmptyTitle => 'Noch keine Badges gemacht';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Mach eins und gib es jemandem, der es verdient hat.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An $count Personen vergeben',
      one: 'An 1 Person vergeben',
      zero: 'Noch nicht vergeben',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Neues Badge';

  @override
  String get badgeEditorEditTitle => 'Badge bearbeiten';

  @override
  String get badgeEditorNameLabel => 'Name';

  @override
  String get badgeEditorNameHint => 'Szenendieb';

  @override
  String get badgeEditorIdentifierLabel => 'Kennung';

  @override
  String get badgeEditorIdentifierHelp =>
      'Teil der Badge-Adresse — sie bleibt fest, sobald das Badge existiert.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Du hast schon ein Badge mit dieser Kennung. Bearbeite lieber jenes — hier zu veröffentlichen würde es ersetzen.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Jedes Badge braucht eine Kennung — tipp eine ein, wenn der Name sie nicht gefüllt hat.';

  @override
  String get badgeEditorDescriptionLabel => 'Beschreibung';

  @override
  String get badgeEditorDescriptionHint =>
      'Für alle, die mit einem einzigen Loop die Show stehlen.';

  @override
  String get badgeEditorArtworkLabel => 'Artwork';

  @override
  String get badgeEditorArtworkAdd => 'Artwork hinzufügen';

  @override
  String get badgeEditorArtworkReplace => 'Ersetzen';

  @override
  String get badgeEditorArtworkError => 'Bild konnte nicht hochgeladen werden';

  @override
  String get badgeEditorArtworkRequired => 'Jedes Badge braucht ein Artwork.';

  @override
  String get badgeEditorArtworkRemove => 'Artwork entfernen';

  @override
  String get badgeEditorArtworkSheetTitle => 'Badge-Artwork';

  @override
  String get badgeDetailDeleteAction => 'Badge löschen';

  @override
  String get badgeDetailDeleteTitle => 'Dieses Badge löschen?';

  @override
  String get badgeDetailDeleteBody =>
      'Damit bitten wir die Relays, das Badge und alle Auszeichnungen dafür zu entfernen. Relays können das ablehnen, und wer es angepinnt hat, behält es im Profil, bis er es selbst entfernt.';

  @override
  String get badgeDetailDeleteConfirm => 'Löschen';

  @override
  String get badgeEditorSaveAction => 'Badge veröffentlichen';

  @override
  String get badgeEditorSaveError => 'Badge konnte nicht veröffentlicht werden';

  @override
  String get badgeEditorLoadError => 'Dieses Badge konnte nicht geladen werden';

  @override
  String get badgeDetailTitle => 'Badge';

  @override
  String get badgeDetailMadeBy => 'Gemacht von';

  @override
  String get badgeDetailRecipientsTitle => 'Vergeben an';

  @override
  String get badgeDetailNoRecipients => 'Das hat noch niemand.';

  @override
  String get badgeDetailAwardAction => 'Badge vergeben';

  @override
  String get badgeDetailEditAction => 'Badge bearbeiten';

  @override
  String get badgeDetailShareAction => 'Teilen';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Schau dir dieses Badge auf Divine an: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Badge zurücknehmen';

  @override
  String get badgeDetailRevokeTitle => 'Dieses Badge zurücknehmen?';

  @override
  String get badgeDetailRevokeBody =>
      'Damit bitten wir die Relays, die Auszeichnung für diese Person zu entfernen. Relays können das ablehnen, und wer das Badge schon angepinnt hat, behält es im Profil, bis er es selbst entfernt. Eine Benachrichtigung gibt es so oder so nicht.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Damit bitten wir die Relays, die Auszeichnung an dich selbst zu entfernen, und nehmen das Badge von deinem Profil. Lehnen die Relays die Löschung ab, ändert sich nichts.';

  @override
  String get badgeDetailRevokeConfirm => 'Zurücknehmen';

  @override
  String get badgeDetailRevokeSuccess => 'Badge zurückgenommen';

  @override
  String get badgeDetailBlockClaimantsAction => 'Badge-Träger blockieren';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Badge-Träger blockieren';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Wir konnten die Träger dieses Badges nicht laden';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Gerade trägt niemand dieses Badge';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Wir haben gerade niemanden zum Blockieren gefunden.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten blockieren?',
      one: '1 Konto blockieren?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Das blockiert die $count Konten, die dieses Badge gerade tragen. Ihre Beiträge tauchen nicht mehr in deinen Feeds auf, und sie werden nicht informiert.',
      one:
          'Das blockiert das Konto, das dieses Badge gerade trägt. Seine Beiträge tauchen nicht mehr in deinen Feeds auf, und es wird nicht informiert.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten blockieren',
      one: '1 Konto blockieren',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Badge-Träger blockiert';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Wir konnten die Badge-Träger nicht blockieren';

  @override
  String get badgeDetailLoadError => 'Dieses Badge konnte nicht geladen werden';

  @override
  String get badgeDetailMissing => 'Wir finden dieses Badge auf keinem Relay.';

  @override
  String get badgeDetailActionError => 'Das hat nicht geklappt';

  @override
  String get badgeAwardTitle => 'Badge vergeben';

  @override
  String get badgeAwardPickAction => 'Leute auswählen';

  @override
  String get badgeAwardManualLabel => 'Oder Schlüssel einfügen';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Wähl mindestens eine Person aus.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An $count Personen vergeben',
      one: 'An 1 Person vergeben',
      zero: 'Badge vergeben',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Vergeben von';

  @override
  String get profileBadgeRecipients => 'Empfänger';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count weitere';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Badge $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Badge';

  @override
  String get profileBadgeFooterBody =>
      'Badges sind kleine Auszeichnungen, die jeder auf Nostr erstellen kann. Verschenk eins an eine Freundin, einen Creator oder jemanden, der dir den Tag gerettet hat.';

  @override
  String get profileBadgeFooterLink => 'Mach dein eigenes Badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Familien-Guide';

  @override
  String get minorAccountReviewWelcomeTitle => 'Noch nicht 16? Kein Problem.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Dass du dich auf diese Seite durchgeklickt hast, statt einfach die Antwort zu wählen, die dich reinlässt, zählt. Das zeigt Ehrlichkeit, Rückgrat und echte Rücksicht auf die Menschen um dich herum.\n\nDie Regeln für Menschen unter 16 sind je nach Wohnort verschieden. Bei Divine wollen wir, dass Familien gemeinsam darüber sprechen und entscheiden, wie gesunde Social-Media-Nutzung für sie aussieht.';

  @override
  String get minorAccountReviewModerationTitle =>
      'Wir brauchen noch einen Schritt';

  @override
  String get minorAccountReviewModerationBody =>
      'Wir wurden gebeten, dieses Konto genauer anzusehen, weil es jemandem unter 16 gehören könnte. Dieser Ablauf hält die nächsten Schritte privat und zeigt dir den richtigen Weg für dein Alter.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Die Regeln sind nicht überall gleich';

  @override
  String get minorAccountReviewRulesBody =>
      'Länder und Regionen gehen unterschiedlich damit um, wie Jugendliche soziale Medien nutzen. Deshalb bitten wir Familien, kurz innezuhalten, die Fakten zu prüfen und den nächsten Schritt gemeinsam zu wählen.';

  @override
  String get minorAccountReviewApproachTitle => 'Wie Divine das sieht';

  @override
  String get minorAccountReviewApproachBody =>
      'Wir glauben, dass gesunde Tech-Gewohnheiten aus Innehalten, Nachdenken und dem Lenken der Aufmerksamkeit auf bessere Dinge entstehen – nicht daraus, Kinder auszuspionieren oder Eltern zu Aufpassern zu machen. Die Forschung sieht das genauso.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Mehr für Familien';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Divines Kinderrichtlinie lesen';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Wähl den passenden Weg';

  @override
  String get minorAccountReviewUnder13Cta => 'Unter 13';

  @override
  String get minorAccountReviewTeenCta => '13 bis 15 Jahre';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Im Divine-Familien-Guide findest du praktische Tipps, Gesprächshilfen und Materialien, damit Jugendliche soziale Medien sicherer nutzen.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Familien-Guides und Tipps holen';

  @override
  String get minorAccountReviewFooter =>
      'Wenn du 16 oder älter bist und versehentlich hier gelandet bist, wende dich an den Divine-Support – ein echter Mensch schaut sich das an.';

  @override
  String get minorAccountReviewTitle => 'Kontoprüfung';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Kontostatus wird geprüft …';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Bitte warte, während wir den aktuellen Prüfstatus dieses Kontos bestätigen.';

  @override
  String get minorAccountReviewDefaultTitle => 'Kontoprüfung erforderlich';

  @override
  String get minorAccountReviewDefaultBody =>
      'Wir müssen dieses Konto prüfen, bevor es Divine normal nutzen kann.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Fall-ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Fall-ID';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'Was gerade eingeschränkt ist';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Posten und Veröffentlichen sind pausiert';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Kommentare, Likes, Reposts und Follows sind pausiert';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Normale Nachrichten zu starten oder zu beantworten ist pausiert';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Support und deine Moderationsnachricht bleiben verfügbar';

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
  String get minorAccountReviewOpenSupportCenter => 'Support-Center öffnen';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Moderationsnachricht öffnen';

  @override
  String get minorAccountReviewOpenReviewPage => 'Prüfseite öffnen';

  @override
  String get minorAccountReviewCheckAgain => 'Erneut prüfen';

  @override
  String get minorAccountReviewLogOut => 'Abmelden';

  @override
  String get minorAccountReviewNextStepTitle => 'Nächster Schritt';

  @override
  String get minorAccountReviewNextStepBody =>
      'Öffne das Support-Center oder deine Moderationsnachricht, wenn du Hilfe bei dieser Prüfung brauchst.';

  @override
  String get minorAccountReviewInProgressTitle => 'Prüfung läuft';

  @override
  String get minorAccountReviewInProgressBody =>
      'Wir haben erst mal alles, was wir brauchen. Unser Team prüft diesen Fall, bevor der normale Kontozugang wiederhergestellt wird.';

  @override
  String get minorAccountReviewUnder13Title => 'Konten unter 13';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Wenn dieses Konto jemandem unter 13 gehört, muss ein Elternteil oder Erziehungsberechtigter eine E-Mail an $supportEmail schicken und die Fall-ID angeben.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Wir können dir noch kein Konto geben';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine ist nicht für Kinder unter 13 gemacht, und die Social-Media-Regeln weltweit binden uns die Hände.\n\nVieles im Internet bringt dich dazu zu lügen, um zu bekommen, was du willst – und das finden wir mies. Das ist die falsche Lektion fürs Leben, und wir bringen sie dir hier nicht bei.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Was deine Familie stattdessen tun kann';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Ein Elternteil oder Erziehungsberechtigter kann das Konto führen und posten – und du darfst natürlich in den Videos dabei sein. Wir wollen, dass Familien Divine so genießen, wie es für sie passt.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Wenn du 13 wirst';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Je nach den Regeln bei dir vor Ort kannst du dann vielleicht wiederkommen und dein eigenes Konto beantragen. Wenn du zwischen 13 und 15 bist, brauchst du dafür die Einwilligung eines Elternteils oder Erziehungsberechtigten.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Warum wir dir nicht einfach sagen, du sollst zurückgehen';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Ein großer Teil des Internets ist so aufgebaut, dass Leute belohnt werden, wenn sie einfach das sagen, was sie durch die Tür bringt. Das finden wir nicht gut. Ja, du könntest zurückgehen und angeben, dass du älter bist, als du bist, aber das wäre nicht ehrlich, und wir werden dir nicht beibringen, zu lügen, um zu bekommen, was du willst.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Wir versuchen, jungen Menschen zu helfen, Divine auf eine Weise zu nutzen, die für sie und ihr Umfeld gesund und positiv ist. Wir müssen uns außerdem an Gesetze halten, die von Ort zu Ort unterschiedlich sind. Wenn du also unter 13 bist, lautet die Antwort, dass du heute noch kein eigenes Konto haben kannst.';

  @override
  String get minorAccountReviewTeenBody =>
      'Wenn dieses Konto jemandem zwischen 13 und 15 gehört, folge über die Moderationsnachricht oder den Support-Weg der Anleitung zur Einwilligung der Eltern.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Wenn das Konto jemandem zwischen 13 und 15 gehören soll';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Ein Elternteil oder Erziehungsberechtigter sollte dem Divine-Support ein kurzes privates Video per E-Mail schicken. Unser Team prüft es und hilft bei den nächsten Schritten.\n\nWenn der Kontakt zu einem Elternteil oder Erziehungsberechtigten nicht möglich ist oder jemanden gefährden würde, schreib dem Divine-Support und sag uns Bescheid.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Das ist eine Pause, während das Divine-Support-Team das Video prüft. Wenn es freigegeben wird, führen sie dich durch die Einrichtung des neuen Kontos.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Warum wir darum bitten, dass ein Elternteil oder Erziehungsberechtigter einbezogen wird';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine muss sich weltweit an altersbezogene Gesetze halten. Wir wissen auch, dass die meisten technischen Alterskontrollen unvollkommen sind. Anstatt so zu tun, als gäbe es die Regeln nicht oder als wäre es cool, beim Alter zu lügen, möchten wir, dass Teenager und Familien überlegte Entscheidungen darüber treffen, wie sie Divine am besten nutzen. Deshalb bitten wir bei 13- bis 15-Jährigen die Eltern, Teil des Kontoerstellungsprozesses zu sein.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Wir müssen uns außerdem an das Gesetz halten, und diese Regeln sind je nach Wohnort unterschiedlich. Anstatt so zu tun, als gäbe es die Regeln nicht, bitten wir also darum, dass ein Elternteil oder Erziehungsberechtigter Teil des Prozesses ist.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Was das Video zeigen soll';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Den Teenager im Video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Ein Elternteil oder einen Erziehungsberechtigten, der vor der Kamera spricht';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Eine klare Aussage, dass der Teenager 13 bis 15 ist und Divine nutzen darf';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Eine klare Aussage, dass das Elternteil oder der Erziehungsberechtigte vom Konto weiß und die Nutzung beaufsichtigt';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'So schickst du es';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Häng das Video an deine E-Mail an den Divine-Support an';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Halte das Video privat und poste es nicht in der App';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Unser Team prüft es und meldet sich mit den nächsten Schritten';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'E-Mail an den Divine-Support';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Hilfe zur Divine-Greenlight-Prüfung (13 bis 15 Jahre)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hallo Divine-Support,\n\nich wende mich wegen Divine Greenlight für einen Teenager im Alter von 13 bis 15 an euch.\n\nIch habe ein kurzes privates Video angehängt, das zeigt:\n- den Teenager\n- ein Elternteil oder einen Erziehungsberechtigten, der vor der Kamera spricht\n- dass der Teenager Divine nutzen darf\n- dass das Elternteil oder der Erziehungsberechtigte vom Konto weiß und die Nutzung beaufsichtigt\n\nWohnsitzland/-länder:\n\nHilfreicher Kontext:\n\nDanke.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Anleitung für Eltern';

  @override
  String get minorAccountReviewContinue => 'Weiter';

  @override
  String get minorAccountReviewErrorTitle =>
      'Wir konnten den Prüfstatus deines Kontos nicht laden.';

  @override
  String get minorAccountReviewErrorBody =>
      'Bitte versuch es gleich noch einmal.';

  @override
  String get minorAccountReviewTryAgain => 'Erneut versuchen';

  @override
  String get minorAccountReviewParentContactTitle => 'Elternkontakt';

  @override
  String get minorAccountReviewParentContactHeading =>
      'E-Mail eines Elternteils oder Erziehungsberechtigten hinzufügen';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Wir verwenden diese Adresse für die Prüfung der elterlichen Einwilligung im Fall $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'E-Mail des Elternteils oder Erziehungsberechtigten';

  @override
  String get minorAccountReviewSubmitting => 'Wird gesendet …';

  @override
  String get minorAccountReviewSubmitEmail => 'E-Mail senden';

  @override
  String get minorAccountReviewBackToReview => 'Zurück zur Kontoprüfung';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'E-Mail gesendet';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Wir haben $email zur Prüfung eingereicht. Wir schicken eine Bestätigung an diese Adresse. Sobald dein Elternteil oder Erziehungsberechtigter antwortet, geht dein Fall weiter. Tippe auf der Kontoprüfungsseite auf „Erneut prüfen“, um Updates zu sehen.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Wir haben den Kontakt des Elternteils oder Erziehungsberechtigten für dieses Konto erhalten. Unser Team prüft ihn, bevor der Zugang wiederhergestellt wird.';

  @override
  String get minorAccountReviewMissingCase =>
      'Wir konnten keinen aktiven Prüffall für dieses Konto finden.';

  @override
  String get minorAccountReviewParentContactError =>
      'Die E-Mail der Eltern konnte nicht gesendet werden. Bitte versuch es erneut.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Eltern-Support';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Ein Elternteil oder Erziehungsberechtigter muss Divine kontaktieren';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Bei Konten, die vermutlich unter 13 sind, ist der nächste Schritt eine E-Mail von einem Elternteil oder Erziehungsberechtigten.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Support-E-Mail';

  @override
  String get minorAccountReviewCopySupportEmail => 'Support-E-Mail kopieren';

  @override
  String get minorAccountReviewSupportEmailCopied => 'Support-E-Mail kopiert';

  @override
  String get minorAccountReviewCopyCaseId => 'Fall-ID kopieren';

  @override
  String get minorAccountReviewCaseIdCopied => 'Fall-ID kopiert';

  @override
  String get minorAccountReviewUnavailable => 'Nicht verfügbar';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Bitte das Elternteil oder den Erziehungsberechtigten, die Fall-ID anzugeben und zu erklären, dass es um diese Kontoprüfung geht.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Kontoprüfung unter 13 für Fall $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Hallo Divine-Support,\n\nich bin das Elternteil bzw. der Erziehungsberechtigte eines Kindes unter 13 und wende mich wegen der Kontoprüfung mit dem Fall $caseId an euch.\n\nDanke.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulation der Minderjährigen-Kontoprüfung';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Aktueller Status';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Eingeschränkt ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Aktiv';

  @override
  String get devOptionsMinorReviewStateLoading => 'Wird geladen …';

  @override
  String get devOptionsMinorReviewStateError => 'Fehler beim Laden des Status';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Simulations-Override zurücksetzen';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Wieder Backend- oder Standardstatus „aktiv“ verwenden';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Prüffall 13–15 simulieren';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Eingeschränktes Konto mit Elternkontakt-Weg';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Support-Fall unter 13 simulieren';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Eingeschränktes Konto mit Anleitung nur per Eltern-E-Mail';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simulation der Minderjährigen-Kontoprüfung zurückgesetzt';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Simulierter Support-Fall unter 13 aktiviert';

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
      'Simulation geschützter Minderjähriger';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Aktueller Status';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Geschützt, minderjährig (13–15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Nicht geschützt';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Wird geladen …';

  @override
  String get devOptionsProtectedMinorStateError =>
      'Fehler beim Lesen des Status';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Kein Override (echter Kontostatus)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Override: geschützt erzwungen';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Override: nicht geschützt erzwungen';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Geschützte Minderjährige simulieren (13–15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Status „geschützt, minderjährig“ erzwingen, um die Schutzmaßnahmen #175/#176 zu testen';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Volljährige simulieren';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Nicht geschützt erzwingen (explizites Nein, nicht dasselbe wie kein Override)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Override zurücksetzen';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Zurück zum echten, von Keycast gesteuerten Kontostatus';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Status „geschützt, minderjährig“ erzwungen';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Status „geschützt, minderjährig“ abgeschaltet';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Override „geschützt, minderjährig“ zurückgesetzt';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Anmelde-Einladungen';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Aktueller Status';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Serverwert: wird geladen';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Serverwert: aktiviert';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Serverwert: deaktiviert';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Serverwert: unbekannt';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Override: Serverwert verwenden';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Override: aktiviert erzwingen';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Override: deaktiviert erzwingen';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Serverwert verwenden';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Dem onboardingMode des Einladungsdienstes folgen';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Aktiviert erzwingen';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Einladungs-Gates und -Verwaltung lokal anzeigen';

  @override
  String get devOptionsInviteAvailabilityForceDisabled =>
      'Deaktiviert erzwingen';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Einladungs-UI lokal ausblenden, ohne den Server zu ändern';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Anmelde-Einladungen folgen jetzt dem Server';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Anmelde-Einladungen erzwungen aktiviert';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Anmelde-Einladungen erzwungen deaktiviert';

  @override
  String get commentsRecordVideoButtonLabel => 'Videokommentar aufnehmen';

  @override
  String get commentsOpenVideoLabel => 'Videokommentar öffnen';

  @override
  String get commentsMuteVideoReplyLabel => 'Videoantwort stummschalten';

  @override
  String get commentsUnmuteVideoReplyLabel =>
      'Stummschaltung der Videoantwort aufheben';

  @override
  String get commentsOpenReplyParentLabel =>
      'Video öffnen, auf das hier geantwortet wird';

  @override
  String get commentsReplyParentSectionTitle => 'Als Antwort auf';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Antwort auf $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Antwort auf Video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Verifiziertes $platform-Konto: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Verifizierte Konten';

  @override
  String get profileEditGetVerifiedCta => 'Lass dich verifizieren';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Verknüpfe deine Social-Media-Konten, damit alle wissen, dass du es bist.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Website besuchen: $url';
  }

  @override
  String get profileCouldNotOpenWebsite =>
      'Website konnte nicht geöffnet werden';

  @override
  String get videoMetadataEditCoverTitle => 'Cover bearbeiten';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Cover-Änderungen verwerfen';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Ausgewählten Frame als Video-Cover verwenden';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Durch Video scrollen, um Cover-Frame auszuwählen';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Tags suchen oder hinzufügen';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Tags hinzufügen, damit andere dein Video entdecken';

  @override
  String get videoMetadataTagsPickerNoResults => 'Keine passenden Tags';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '„#$tag\" hinzufügen';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Noch keine 16? Das ist okay. ';

  @override
  String get authUnder16ChoicesCta => 'Hier sind deine Möglichkeiten.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Warum das so ist';

  @override
  String get generalSettingsHoldToRecord => 'Gedrückt halten zum Aufnehmen';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Die Aufnahme beginnt, wenn du gedrückt hältst, und stoppt, wenn du loslässt';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Videos in deinem Profil veröffentlicht',
      one: 'Video in deinem Profil veröffentlicht',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Nachricht senden';

  @override
  String get emojiPickerSearchHint => 'Suchen';

  @override
  String get emojiCategoryRecent => 'Zuletzt verwendet';

  @override
  String get emojiCategorySmileys => 'Smileys und Menschen';

  @override
  String get emojiCategoryAnimals => 'Tiere und Natur';

  @override
  String get emojiCategoryFood => 'Essen und Trinken';

  @override
  String get emojiCategoryActivities => 'Aktivitäten';

  @override
  String get emojiCategoryTravel => 'Reisen und Orte';

  @override
  String get emojiCategoryObjects => 'Objekte';

  @override
  String get emojiCategorySymbols => 'Symbole';

  @override
  String get emojiCategoryFlags => 'Flaggen';

  @override
  String get videoEditorMarkerLabel => 'Markierung';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Timeline-Markierung hinzufügen';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Timeline-Markierung entfernen';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Markierung an der Abspielposition entfernen';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Markierung löschen?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Das entfernt die Markierung aus der Timeline. Deine Bearbeitung bleibt erhalten.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Alle Spuren stumm schalten oder aktivieren';

  @override
  String get videoEditorSplitFailed =>
      'Teilen fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get videoEditEditSubtitles => 'Untertitel bearbeiten';

  @override
  String get subtitleEditorTitle => 'Untertitel bearbeiten';

  @override
  String get subtitleEditorSave => 'Speichern';

  @override
  String get subtitleEditorProcessing =>
      'Untertitel werden noch erstellt. Schau gleich noch mal vorbei.';

  @override
  String get subtitleEditorNoSpeech =>
      'In diesem Video wurde keine Sprache erkannt – es gibt nichts zu untertiteln.';

  @override
  String get subtitleEditorWriteOwn => 'Selbst schreiben';

  @override
  String get subtitleEditorAddCue => 'Zeile hinzufügen';

  @override
  String get subtitleEditorRemoveCue => 'Diese Zeile entfernen';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Das Video lässt sich gerade nicht abspielen — die Untertitel kannst du trotzdem korrigieren.';

  @override
  String get subtitleEditorPlayPreview => 'Video abspielen';

  @override
  String get subtitleEditorPausePreview => 'Video pausieren';

  @override
  String get subtitleEditorInvalidHint =>
      'Jede Zeile braucht Text und ein Ende nach dem Start.';

  @override
  String get subtitleEditorLoadError =>
      'Untertitel konnten nicht geladen werden. Versuch es erneut.';

  @override
  String get subtitleEditorSaveSuccess => 'Untertitel aktualisiert';

  @override
  String get subtitleEditorSaveError =>
      'Untertitel konnten nicht gespeichert werden. Versuch es erneut.';

  @override
  String get subtitleEditorRetry => 'Erneut versuchen';

  @override
  String get subtitleEditorCueHint => 'Untertiteltext';

  @override
  String get imageCropEditorRotateLabel => 'Drehen';

  @override
  String get imageCropEditorFlipLabel => 'Spiegeln';

  @override
  String get imageCropEditorResetLabel => 'Zurücksetzen';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Zuschneiden abbrechen';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Zuschnitt übernehmen';

  @override
  String get imageCropEditorProcessing => 'Zuschnitt wird angewendet…';

  @override
  String get backgroundUploadNotificationTitle => 'Video wird hochgeladen';

  @override
  String get monetizationSettingsTitle => 'Creator unterstützen';

  @override
  String get monetizationSettingsSubtitle =>
      'Trinkgeld- und Abo-Links hinzufügen';

  @override
  String get monetizationSettingsIntroTitle => 'Nur externe Links';

  @override
  String get monetizationSettingsIntroBody =>
      'Füge Ziele hinzu, die du selbst kontrollierst. Divine wickelt keine Zahlungen ab und schaltet über diese Links keine Inhalte in der App frei.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktive Links in deinem Profil',
      one: '1 aktiver Link in deinem Profil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Trinkgeld senden';

  @override
  String get monetizationSettingsSubscriptionSection =>
      'Abonnieren / unterstützen';

  @override
  String get monetizationSettingsSave => 'Support-Links speichern';

  @override
  String get monetizationSettingsSaving => 'Wird gespeichert …';

  @override
  String get monetizationSettingsSaved => 'Support-Links aktualisiert';

  @override
  String get monetizationSettingsSaveFailed =>
      'Die Support-Links konnten nicht gespeichert werden. Prüfe deine Verbindung und versuch es erneut.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'Füge einen Handle oder eine URL hinzu.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Dieser Link sieht nicht richtig aus.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Nimm einen Link für diesen Anbieter.';

  @override
  String get monetizationSettingsHintCashApp => '\$Cashtag oder cash.app-Link';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me-Handle oder -Link';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo-Handle oder -Link';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon-Handle oder -Link';

  @override
  String get monetizationSettingsHintSubstack => 'Substack-Domain oder -Link';

  @override
  String get monetizationSettingsHintMedium => 'Medium-Handle oder -Link';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open-Collective-Slug oder -Link';

  @override
  String get profileSupportSheetTitle => 'Diesen Creator unterstützen';

  @override
  String get profileSupportSheetBody =>
      'Diese Links öffnen sich außerhalb von Divine. Nichts davon schaltet Inhalte in der App frei.';

  @override
  String get profileSupportTipSection => 'Trinkgeld senden';

  @override
  String get profileSupportSubscriptionSection => 'Abonnieren / unterstützen';

  @override
  String get profileSupportButtonLabel => 'Unterstützen';

  @override
  String get monetizationTipsSettingsTitle => 'Trinkgeld';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Optionale Trinkgeld-Links hinzufügen';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Nur freiwilliges Trinkgeld';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Trinkgeld ist ein freiwilliges Geschenk von Person zu Person. Es schaltet in Divine keine Inhalte, Abos, Funktionen, Rankings, Sichtbarkeit oder Zugänge frei.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktive Trinkgeld-Links in deinem Profil',
      one: '1 aktiver Trinkgeld-Link in deinem Profil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Trinkgeld-Links speichern';

  @override
  String get monetizationTipsSettingsSaved => 'Trinkgeld-Links aktualisiert';

  @override
  String get profileTipButtonLabel => 'Trinkgeld';

  @override
  String get profileTipSheetTitle => 'Diesem Creator Trinkgeld geben';

  @override
  String get profileTipSheetBody =>
      'Trinkgeld-Links öffnen sich außerhalb von Divine. Trinkgeld ist freiwillig und schaltet in Divine keine Inhalte, Abos, Funktionen oder Zugänge frei.';

  @override
  String get settingsStorageTitle => 'Speicher';

  @override
  String get settingsStorageCacheSectionTitle => 'Zwischenspeicher';

  @override
  String get settingsStorageCacheDescription =>
      'Gecachte Feed-Videos, Vorschaubilder und temporäre Renders. Löschen ist unbedenklich – sie werden bei Bedarf neu geladen oder neu erzeugt.';

  @override
  String get settingsStorageMeasuring => 'Wird berechnet…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size belegt';
  }

  @override
  String get settingsStorageClearButton => 'Zwischenspeicher leeren';

  @override
  String get settingsStorageClearConfirmTitle => 'Zwischenspeicher leeren?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Das gibt $size frei. Deine Clip-Bibliothek bleibt unberührt.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Leeren';

  @override
  String get settingsStorageCleared => 'Zwischenspeicher geleert';

  @override
  String get settingsStorageLibrarySectionTitle => 'Clip-Bibliothek';

  @override
  String get settingsStorageLibraryDescription =>
      'Nach defekten Clips suchen, deren Videodatei fehlt.';

  @override
  String get settingsStorageScanButton => 'Bibliothek prüfen';

  @override
  String get settingsStorageLibraryHealthy => 'Keine defekten Clips gefunden';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Defekte Clips gefunden: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Defekte Clips entfernen';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Defekte Clips entfernt';

  @override
  String get settingsStorageError => 'Etwas ist schiefgelaufen';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Maximaler Video-Cache';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count Videos';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Defekte Clips entfernen?';

  @override
  String get settingsStorageRepairSectionTitle => 'Installation reparieren';

  @override
  String get settingsStorageRepairDescription =>
      'Wenn die App ständig abstürzt oder sich seltsam verhält, hilft meist ein Zurücksetzen der lokalen Daten. Deine Clips und Entwürfe bleiben.';

  @override
  String get settingsStorageRepairButton => 'App-Daten zurücksetzen';

  @override
  String get settingsStorageRepairConfirmTitle => 'App-Daten zurücksetzen?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Das löscht zwischengespeicherte Feed-Daten und temporäre Dateien. Deine Clips, Entwürfe, Einstellungen und Anmeldung bleiben, aber du musst die App danach neu starten.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size werden gelöscht';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Zurücksetzen';

  @override
  String get settingsStorageRepairInProgress => 'Wird zurückgesetzt…';

  @override
  String get settingsStorageRepairSuccess =>
      'Fertig — starte die App neu, um abzuschließen.';

  @override
  String get settingsStorageRepairFailure =>
      'Es konnte nicht alles zurückgesetzt werden. Versuch es nach einem Neustart nochmal.';

  @override
  String get nostrSettingsSignatureVerification => 'Signaturprüfung';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Wähle, wann Divine Signaturen von Relay-Events prüft. Event-IDs werden immer zuerst validiert.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Alle Relays';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Am sichersten. Prüft jede Relay-Event-Signatur.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Nicht vertrauenswürdige Relays';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Überspringt Prüfungen für Relays, die bereits in deinem konfigurierten Pool sind.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Nicht-Divine-Relays';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Vertraue Divine-Relays, prüfe den Rest.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle =>
      'Teile deine Videos auf anderen Plattformen';

  @override
  String get crosspostingSignInRequired =>
      'Melde dich mit Divine an, um Crossposting zu verwalten';

  @override
  String get crosspostingLoadFailed =>
      'Deine Crossposting-Einstellungen konnten nicht geladen werden';

  @override
  String get crosspostingNoPlatforms =>
      'Gerade sind keine Crossposting-Plattformen verfügbar';

  @override
  String get crosspostingRetry => 'Erneut versuchen';

  @override
  String get crosspostingNotConnected => 'Nicht verbunden';

  @override
  String get crosspostingConnected => 'Verbunden';

  @override
  String get crosspostingNeedsReconnect => 'Muss neu verbunden werden';

  @override
  String get crosspostingConnect => 'Verbinden';

  @override
  String get crosspostingReconnect => 'Neu verbinden';

  @override
  String get crosspostingDisconnect => 'Trennen';

  @override
  String get crosspostingModeOff => 'Aus';

  @override
  String get crosspostingModeManual => 'Manuell';

  @override
  String get crosspostingModeManualSubtitle => 'Du entscheidest pro Video';

  @override
  String get crosspostingModeAutomatic => 'Automatisch';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Künftige Videos werden automatisch gepostet — nur Videos, die du nach dem Einschalten veröffentlichst';

  @override
  String get crosspostingNotConnectedError =>
      'Verbinde diese Plattform zuerst, um zu ändern, wie sie postet.';

  @override
  String get crosspostingGenericError =>
      'Da ist was schiefgelaufen. Versuch es nochmal.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Von der Anmeldeseite kam nie eine Rückmeldung. Wenn du dort fertig geworden bist, aktualisiere — dein Konto ist vielleicht schon verknüpft.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform verbunden';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return '$platform konnte nicht verbunden werden';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Verbindung wurde auf $platform abgebrochen';
  }

  @override
  String get supporterTitle => 'Divine-Supporter';

  @override
  String get supporterTileSubtitle =>
      'Unterstütze Divine mit einem optionalen monatlichen Abo.';

  @override
  String get supporterHeroTitle => 'Halte Divine am Laufen';

  @override
  String get supporterHeroBody =>
      'Divine ist kostenlos und wird es immer bleiben. Wenn du uns helfen willst, die Loops am Laufen zu halten, werde monatlicher Supporter. Nichts ist gesperrt – du hältst damit einfach das Licht an und hast unseren Dank.';

  @override
  String get supporterActiveBadge =>
      'Du bist Divine-Supporter. Danke, dass du das hier am Laufen hältst.';

  @override
  String get supporterPurchasePending => 'Dein Kauf wartet auf Genehmigung.';

  @override
  String get supporterPurchaseConfirming =>
      'Deine Unterstützung wird bestätigt …';

  @override
  String get supporterStoreChecking => 'Der Store wird geprüft …';

  @override
  String get supporterUnavailable =>
      'Supporter-Abos sind hier gerade nicht verfügbar.';

  @override
  String get supporterRestorePurchases => 'Käufe wiederherstellen';

  @override
  String get supporterDismissError => 'Fehler ausblenden';

  @override
  String get supporterErrorStoreUnavailable =>
      'Der Store ist auf diesem Gerät nicht verfügbar.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Der Kauf wurde nicht abgeschlossen. Dir wurde nichts berechnet.';

  @override
  String get supporterErrorPurchasePending =>
      'Dein Kauf wartet auf Genehmigung.';

  @override
  String get supporterErrorRestoreFailed =>
      'Es wurde kein Supporter-Abo zum Wiederherstellen gefunden.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Dieser Kauf gehört zu einem anderen Divine-Konto.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine konnte den Supporter-Status gerade nicht bestätigen.';

  @override
  String get supporterErrorUnknown =>
      'Etwas ist schiefgelaufen. Bitte versuch es erneut.';

  @override
  String get supporterDisclaimer =>
      'Divine bestätigt den Supporter-Status, nachdem der Store deinen Kauf verifiziert hat. Anerkennung ist optional, und der Heiligenschein ist keine Verifizierung.';

  @override
  String get profileNotifyBellOff => 'Über neue Vines benachrichtigen';

  @override
  String get profileNotifyBellOn => 'Keine Benachrichtigungen über neue Vines';

  @override
  String get profileNotifyUpdateFailed =>
      'Konnte nicht gespeichert werden. Nochmal?';

  @override
  String get savedSoundYourLabel => 'Dein Label';

  @override
  String get savedSoundAddHashtags => 'Hashtags hinzufügen';

  @override
  String get savedSoundDeviceOnly => 'Auf diesem Gerät gespeichert';

  @override
  String get savedSoundDetailsRetry =>
      'Die Details konnten nicht gespeichert werden. Tippe, um es erneut zu versuchen.';

  @override
  String get savedSoundFallbackTitle => 'Gespeicherter Sound';

  @override
  String get savedSoundPreviewAction => 'Sound anhören';

  @override
  String get savedSoundEditAction => 'Sound-Details bearbeiten';

  @override
  String get savedSoundRemoveAction => 'Gespeicherten Sound entfernen';

  @override
  String get savedSoundClearHashtagFilter => 'Hashtag-Filter zurücksetzen';

  @override
  String get soundAllowRemix => 'Anderen erlauben, diesen Sound zu remixen';

  @override
  String get soundReuseUnavailable =>
      'Dieser Sound kann gerade nicht remixt werden.';

  @override
  String get soundPublicCredit => 'Öffentlicher Sound-Credit';

  @override
  String get soundCreditRequired =>
      'Füge vor dem Posten einen öffentlichen Sound-Credit hinzu.';

  @override
  String get soundSharedAs => 'Geteilt als';

  @override
  String get soundOwnWork => 'Ich habe diesen Sound gemacht';

  @override
  String soundCreatorBy(String creator) {
    return 'Von $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Geteilt von $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remixen erlaubt';

  @override
  String get soundCreditOnly => 'Nur Credit';

  @override
  String get soundCreditTitleLabel => 'Sound-Titel';

  @override
  String get soundCreditCreatorLabel => 'Creator';

  @override
  String get soundCreditSourceUrlLabel => 'Quell-URL';

  @override
  String get soundCreditPublicHashtagsLabel => 'Öffentliche Hashtags';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Tag-Auswahl abbrechen';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Ausgewählte Tags anwenden';

  @override
  String get userPickerCancelSemanticLabel => 'Nutzerauswahl abbrechen';

  @override
  String get userPickerConfirmSemanticLabel => 'Ausgewählte Nutzer bestätigen';

  @override
  String get userPickerClearSelectionSemanticLabel => 'Nutzerauswahl leeren';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Auswahl der Inhaltswarnungen abbrechen';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Ausgewählte Inhaltswarnungen anwenden';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Videoeditor schließen';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Weiter zu den Beitragsdetails';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Änderungen in „$tool“ verwerfen';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Änderungen in „$tool“ anwenden';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Audio entfernen';

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
  String get verifyTitle => 'Verifizierte Konten';

  @override
  String get verifySignedOutMessage =>
      'Melde dich an, um deine Konten zu verknüpfen.';

  @override
  String get verifyIntro =>
      'Verknüpfe Konten, die du schon hast, damit alle sehen, dass du es wirklich bist.';

  @override
  String get verifyLoadFailed =>
      'Deine Verknüpfungen konnten nicht geladen werden.';

  @override
  String get verifyRetry => 'Nochmal versuchen';

  @override
  String get verifyLinkedSectionTitle => 'Verknüpft';

  @override
  String get verifyVerifierUnreachable =>
      'Der Verifizierer war nicht erreichbar, deshalb steht hier überall „ungeprüft“.';

  @override
  String get verifyAddSectionTitle => 'Konto hinzufügen';

  @override
  String get verifyAllPlatformsLinked =>
      'Du hast alles verknüpft, was wir unterstützen.';

  @override
  String get verifyStatusVerified => 'Verifiziert';

  @override
  String get verifyStatusUnverified => 'Nicht verifiziert';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return '$platform-Konto $identity trennen';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return '$platform trennen?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity wird nicht mehr in deinem Profil angezeigt. Du kannst das Konto später wieder verknüpfen, musst dich dann aber neu anmelden oder einen neuen Nachweis posten.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Trennen';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Dein $platform-Konto verknüpfen';
  }

  @override
  String get verifyOneTapBadge => 'Ein Tipp';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Melde dich bei $platform an, den Rest übernehmen wir. Es wird nichts gepostet.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Weiter mit $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Oder einen Nachweis posten';

  @override
  String get verifyConnectProofExplainer =>
      'Poste deinen npub in deinem Konto und füge dann den Link zu diesem Post ein.';

  @override
  String get verifyNpubLabel => 'Dein npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Deinen npub kopieren';

  @override
  String get verifyNpubCopied => 'npub kopiert';

  @override
  String get verifyIdentityLabel => 'Kontoname';

  @override
  String get verifyProofLabel => 'Link zu deinem Post';

  @override
  String get verifyConnectProofCta => 'Prüfen und verknüpfen';

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
      'Der Verifizierer war nicht erreichbar. Versuch es gleich nochmal.';

  @override
  String get verifyErrorOauthFailed =>
      'Das hat nicht geklappt. Versuch es nochmal.';

  @override
  String get verifyErrorHandleRequired => 'Gib zuerst dein Handle ein.';

  @override
  String get verifyErrorPublishFailed =>
      'Verifiziert, aber kein Relay hat das Update angenommen. Versuch es nochmal.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Ein-Tipp-Anmeldung ist hier noch nicht eingerichtet. Nimm den Nachweis-Post unten.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Leg einen öffentlichen Gist an, mit deinem npub in der ersten Datei, und füge den Gist-Link ein.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Poste deinen npub in einem Discord-Kanal, den unser Bot lesen kann, und füge den Nachrichten-Link ein. Eine Server-Einladung beweist nichts.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tweete deinen npub von diesem Konto und füge den Link zum Tweet ein.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Poste deinen npub von diesem Konto und füge den Link ein. Der Kontoname braucht die Instanz — mastodon.social/@alice, nicht nur alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Verknüpft wird der Kanal, nicht dein Telegram-Konto. Er braucht zuerst einen öffentlichen Link — Telegram legt neue Kanäle privat an. Poste dort deinen npub und füge den Nachrichten-Link ein.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Oben angemeldet? Dann ist nichts weiter nötig. Sonst poste deinen npub und füge den Link zu dem Post ein.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Schreib deinen npub in eine Video-Caption und füge den Link zu dem Video ein.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Schreib deinen npub in eine Videobeschreibung und füge den Link zu dem Video ein.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform ist verknüpft.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Das ist ein privater Kanal oder eine Einladung. Gib dem Kanal einen öffentlichen Link und füge dann den Nachrichten-Link ein.';

  @override
  String get verifyErrorRemoveFailed =>
      'Konnte nicht getrennt werden. Versuch es nochmal.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Deine aktuellen Verknüpfungen waren nicht lesbar, deshalb wurde nichts geändert. Prüf deine Verbindung und versuch es nochmal.';

  @override
  String get verifyChannelLabel => 'Kanalname';

  @override
  String get verifyHowItWorksTitle => 'Wie funktioniert das?';

  @override
  String get verifyHowItWorksIntro =>
      'Stell es dir als Handschlag zwischen zwei Konten vor:';

  @override
  String get verifyHowItWorksYourSide =>
      'Dein Divine-Profil sagt: „Ich bin @alice auf Twitter.“';

  @override
  String get verifyHowItWorksOtherSide =>
      'Dein Twitter-Konto bestätigt: „Ja, dieses Divine-Profil gehört mir.“';

  @override
  String get verifyHowItWorksBothSides =>
      'Wir prüfen beide Seiten. Passt es zusammen, bist du verifiziert. Fälschen geht nicht — Name und Foto kann jemand kopieren, von deinem echten Konto posten nicht.';

  @override
  String get verifyHowItWorksOwnership =>
      'Die Verknüpfungen liegen in deiner eigenen Nostr-Identität, du kannst sie hier jederzeit wieder entfernen.';

  @override
  String get generalSettingsSectionIdentity => 'Identität';

  @override
  String get libraryFilterAll => 'Alle';

  @override
  String get libraryFilterArchive => 'Archiv';

  @override
  String get libraryFilterDeleted => 'Gelöscht';

  @override
  String get libraryCategoryNewChipLabel => 'Neu';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Kategorie erstellen';

  @override
  String get libraryCategoryCreateTitle => 'Neue Kategorie';

  @override
  String get libraryCategoryCreateAction => 'Erstellen';

  @override
  String get libraryCategoryRenameTitle => 'Kategorie umbenennen';

  @override
  String get libraryCategoryRenameAction => 'Umbenennen';

  @override
  String get libraryCategoryDeleteAction => 'Kategorie löschen';

  @override
  String get libraryCategoryNameLabel => 'Name der Kategorie';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Deine Clips bleiben. Sie wandern nur zurück zu „Alle“.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Kategorie umbenennen oder löschen';

  @override
  String get libraryCategoryMoveTitle => 'Verschieben nach';

  @override
  String get libraryCategoryMoveNone => 'Keine Kategorie';

  @override
  String get libraryCategoryMoveNewCategory => 'Neue Kategorie';

  @override
  String get libraryArchiveAction => 'Archivieren';

  @override
  String get libraryUnarchiveAction => 'Aus Archiv holen';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In diesen Kategorien behalten?',
      one: 'In dieser Kategorie behalten?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'In $name behalten';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'In den Kategorien behalten';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Aus $name entfernen';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Aus den Kategorien entfernen';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Ausgewählte Clips verschieben';

  @override
  String get libraryCategoryEmptyTitle => 'Hier ist noch nichts';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Wähl ein paar Clips aus und verschieb sie in diese Kategorie.';

  @override
  String get libraryArchiveEmptyTitle => 'Nichts archiviert';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Archivierte Clips warten hier, außerhalb deiner Hauptbibliothek.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips nach $name verschoben',
      one: '1 Clip nach $name verschoben',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips aus ihrer Kategorie entfernt',
      one: '1 Clip aus der Kategorie entfernt',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips archiviert',
      one: '1 Clip archiviert',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips zurück in deiner Bibliothek',
      one: '1 Clip zurück in deiner Bibliothek',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'E-Mail ändern';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Verschieb dein Konto auf eine andere Adresse';

  @override
  String get accountSettingsChangePassword => 'Passwort ändern';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Wähl ein neues Passwort für die Anmeldung';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Deine Sitzung ist abgelaufen. Melde dich neu an, um das zu ändern.';

  @override
  String get accountCredentialsRateLimited =>
      'Zu viele Versuche. Warte ein paar Minuten.';

  @override
  String get accountCredentialsNetwork =>
      'Divine ist gerade nicht erreichbar. Prüf deine Verbindung und versuch es erneut.';

  @override
  String get accountCredentialsUnknown =>
      'Das hat nicht geklappt. Bitte versuch es erneut.';

  @override
  String get changePasswordSubtitle =>
      'Gib dein aktuelles Passwort ein und wähl dann ein neues.';

  @override
  String get changePasswordCurrentLabel => 'Aktuelles Passwort';

  @override
  String get changePasswordWrongCurrent =>
      'Das ist nicht dein aktuelles Passwort.';

  @override
  String get changePasswordSuccess => 'Passwort geändert.';

  @override
  String get changeEmailSubtitle =>
      'Wir schicken einen Bestätigungslink an deine neue Adresse und an die in deinem Konto. Deine E-Mail ändert sich, sobald du beide bestätigst.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'In deinem Konto: $email';
  }

  @override
  String get changeEmailNewLabel => 'Neue E-Mail';

  @override
  String get changeEmailPasswordLabel => 'Dein Passwort';

  @override
  String get changeEmailSameAsCurrent =>
      'Das ist bereits deine E-Mail-Adresse.';

  @override
  String get changeEmailWrongPassword => 'Das ist nicht dein Passwort.';

  @override
  String get changeEmailSubmit => 'Bestätigungslinks senden';

  @override
  String get changeEmailSentTitle => 'Zwei Links sind unterwegs';

  @override
  String changeEmailSentMessage(String email) {
    return 'Bestätige über $email und über die Adresse in deinem Konto. Deine E-Mail wechselt, sobald beides erledigt ist.';
  }

  @override
  String get changeEmailSentExpiry => 'Die Links laufen nach 24 Stunden ab.';

  @override
  String get changeEmailSentDone => 'Alles klar';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount Videos',
      one: '$formattedCount Video',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Gegenseitig';

  @override
  String get socialProofFollowsYou => 'Folgt dir';

  @override
  String get socialProofYouFollow => 'Du folgst';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount Follower',
      one: '$formattedCount Follower',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Videos laden gerade nicht.\nDas liegt an uns, nicht an dir – wir sind dran.';

  @override
  String get feedOfflineMessage =>
      'Du bist offline.\nPrüfe deine Verbindung und versuch es nochmal.';

  @override
  String get dbFailureTitle => 'Lokale Datenbank konnte nicht entsperrt werden';

  @override
  String get dbFailureAdviceResettable =>
      'Ein Neustart hilft hier nicht. Das Zurücksetzen der lokalen Datenbank unten gibt Divine einen sauberen Start — dein Konto bleibt bestehen.';

  @override
  String get dbFailureAdviceRestart =>
      'Starte Divine neu, nachdem du dein Gerät entsperrt hast. Wenn das weiterhin passiert, aktualisiere die App oder wende dich an den Support.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Versuche, Divine einmal neu zu starten. Wenn das weiterhin passiert, aktualisiere die App oder kontaktiere den Support. Deine lokalen Daten sind noch vorhanden.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnose: $code';
  }

  @override
  String get dbFailureCloseApp => 'Divine schließen';

  @override
  String get dbFailureResetAction => 'Lokale Datenbank zurücksetzen';

  @override
  String get dbFailureConfirmTitle => 'Lokale Datenbank zurücksetzen?';

  @override
  String get dbFailureConfirmBody =>
      'Dein Konto bleibt. Auf diesem Gerät gespeicherte Entwürfe und Clips werden gelöscht — Nachrichten und Feeds kommen aus dem Netzwerk zurück.';

  @override
  String get dbFailureResetConfirm => 'Lokale Datenbank jetzt zurücksetzen';

  @override
  String get dbFailureCancel => 'Abbrechen';

  @override
  String get dbFailureResetFailed =>
      'Das hat nicht geklappt. Schließe Divine und versuche es erneut.';

  @override
  String get dbFailureResetDoneTitle => 'Lokale Datenbank zurückgesetzt';

  @override
  String get dbFailureResetDoneBody =>
      'Schließe Divine und öffne es erneut — der nächste Start legt eine frische lokale Datenbank an.';

  @override
  String get authSignInOptionsInfo => 'Über Anmeldeoptionen';

  @override
  String get authShowPassword => 'Passwort anzeigen';

  @override
  String get authHidePassword => 'Passwort ausblenden';

  @override
  String get followUserSemanticLabel => 'Nutzer folgen';

  @override
  String get unfollowUserSemanticLabel => 'Nutzer nicht mehr folgen';

  @override
  String get commentsLoadingSemanticLabel => 'Kommentare werden geladen';

  @override
  String get analyticsWindowAll => 'Alle';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Nutzer folgen $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Nutzer nicht mehr folgen $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / Monat';
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
      'Ein frisches Update ist da. Schau es dir an →';

  @override
  String get updateModerateTitle =>
      'Seit deinem letzten Besuch gibt es ein Update';

  @override
  String get updateUrgentTitle => 'Dir fehlen wichtige Fehlerbehebungen';

  @override
  String get updateNotNow => 'Nicht jetzt';

  @override
  String get updateAction => 'Aktualisieren';

  @override
  String updateNewIn(String version) {
    return 'Neu in $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Update verfügbar';
}

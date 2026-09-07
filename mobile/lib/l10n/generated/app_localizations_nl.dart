// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Clipherstel';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Vindt opnamen die onder een ander account staan en videobestanden waarnaar geen enkel item meer verwijst.';

  @override
  String get devOptionsClipRecoveryScan => 'Scannen';

  @override
  String get devOptionsClipRecoveryFailure => 'Clipherstel mislukt';

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
      other: '$drafts concepten',
      one: '$drafts concept',
    );
    return 'Nu zichtbaar: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts =>
      'Verborgen onder andere accounts';

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
      other: '$drafts concepten',
      one: '$drafts concept',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Naar dit account verplaatsen';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Bestanden zonder verwijzing: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Herstellen in bibliotheek';

  @override
  String get devOptionsClipRecoveryEmpty => 'Niets te herstellen';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips hersteld',
      one: '$count clip hersteld',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Herstelrapport gekopieerd';

  @override
  String get devOptionsStorageFootprint => 'Opslaggebruik';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Elke map waarin de app schrijft. Cache wissen maakt daar maar een deel van vrij.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Meten';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Totaal: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Opslagrapport gekopieerd';

  @override
  String get devOptionsStorageFootprintFailure => 'Kan opslag niet meten';

  @override
  String get feedTuningMoreLabel => 'Meer zoals dit';

  @override
  String get feedTuningLessLabel => 'Minder zoals dit';

  @override
  String get feedTuningUndo => 'Ongedaan maken';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Verwezen video openen';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get settingsSecureAccount => 'Beveilig je account';

  @override
  String get settingsSessionExpired => 'Sessie verlopen';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Log opnieuw in om volledige toegang te herstellen';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Creator-statistieken';

  @override
  String get settingsSupportCenter => 'Supportcentrum';

  @override
  String get settingsNotifications => 'Meldingen';

  @override
  String get settingsBlueskyPublishing => 'Bluesky-publicatie';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Beheer crossposting naar Bluesky';

  @override
  String get settingsNostrSettings => 'Nostr-instellingen';

  @override
  String get settingsIntegratedApps => 'Geïntegreerde apps';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Goedgekeurde externe apps die binnen Divine draaien';

  @override
  String get settingsExperimentalFeatures => 'Experimentele functies';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Tweaks die soms haperen—probeer ze als je nieuwsgierig bent.';

  @override
  String get settingsLegal => 'Juridisch';

  @override
  String get settingsIntegrationPermissions => 'Integratierechten';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Bekijk en trek onthouden integratiegoedkeuringen in';

  @override
  String settingsVersion(String version) {
    return 'Versie $version';
  }

  @override
  String get settingsVersionEmpty => 'Versie';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Ontwikkelaarsmodus is al ingeschakeld';

  @override
  String get settingsDeveloperModeEnabled => 'Ontwikkelaarsmodus ingeschakeld!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Nog $count keer tikken om ontwikkelaarsmodus in te schakelen';
  }

  @override
  String get settingsShareDivine => 'Deel Divine met je vrienden';

  @override
  String get settingsSwitchAccount => 'Wissel van account';

  @override
  String get settingsAddAnotherAccount => 'Nog een account toevoegen';

  @override
  String get settingsAccountSwitchFailed =>
      'Kan niet van account wisselen. Probeer het opnieuw.';

  @override
  String get settingsUnsavedDraftsTitle => 'Niet-opgeslagen concepten';

  @override
  String get settingsUploadInProgressTitle => 'Upload bezig';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'worden nog $count video\'s',
      one: 'wordt nog $count video',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'je video\'s blijven als concepten',
      one: 'je video blijft als concept',
    );
    return 'Er $_temp0 geüpload. Van account wisselen stopt de upload — $_temp1 in dit account.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count niet-opgeslagen concepten',
      one: '1 niet-opgeslagen concept',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'je concepten',
      one: 'je concept',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ze',
      one: 'het',
    );
    return 'Je hebt $_temp0. Als je van account wisselt blijven $_temp1 bewaard, maar misschien wil je $_temp2 eerst publiceren of nakijken.';
  }

  @override
  String get settingsCancel => 'Annuleren';

  @override
  String get settingsSwitchAnyway => 'Toch wisselen';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'De sessie van dat account is verlopen. Er opnieuw op inloggen betekent uitloggen bij het account waar je nu op zit.';

  @override
  String get settingsAppVersionLabel => 'App-versie';

  @override
  String get settingsAppLanguage => 'App-taal';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (standaard op apparaat)';
  }

  @override
  String get settingsAppLanguageTitle => 'App-taal';

  @override
  String get settingsAppLanguageDescription =>
      'Kies de taal voor de app-interface';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Gebruik apparaattaal';

  @override
  String get settingsGeneralTitle => 'Algemene instellingen';

  @override
  String get settingsContentSafetyTitle => 'Inhoud & veiligheid';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRATIES';

  @override
  String get generalSettingsSectionViewing => 'BEKIJKEN';

  @override
  String get generalSettingsSectionCreating => 'MAKEN';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get appearanceSettingsTitle => 'Weergave';

  @override
  String get appearanceSettingsSubtitle =>
      'Kies hoe Divine eruitziet op dit apparaat';

  @override
  String get appearanceSettingsSystem => 'Systeemstandaard';

  @override
  String get appearanceSettingsLight => 'Licht';

  @override
  String get appearanceSettingsDark => 'Donker';

  @override
  String get generalSettingsClosedCaptions => 'Ondertiteling';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Toon ondertiteling als video\'s die hebben';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Alleen vierkante video\'s';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Hou feeds in het klassieke vierkante formaat';

  @override
  String get contentPreferencesTitle => 'Inhoudsvoorkeuren';

  @override
  String get contentPreferencesContentFilters => 'Inhoudsfilters';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Beheer filters voor inhoudswaarschuwingen';

  @override
  String get contentPreferencesContentLanguage => 'Inhoudstaal';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (standaard op apparaat)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tag je video\'s met een taal zodat kijkers inhoud kunnen filteren.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Gebruik apparaattaal (standaard)';

  @override
  String get contentPreferencesAudioSharing =>
      'Maak mijn audio beschikbaar voor hergebruik';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Als dit aanstaat kunnen anderen audio uit je video\'s gebruiken';

  @override
  String get contentPreferencesMusicMode => 'Muziekmodus';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Zet de ruisonderdrukking uit die instrumenten platslaat. Beter voor muziek, ruwer voor stemmen.';

  @override
  String get contentPreferencesAccountLabels => 'Accountlabels';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'Label je eigen inhoud';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Inhoudslabels voor account';

  @override
  String get contentPreferencesClearAll => 'Alles wissen';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Selecteer alles wat op jouw account van toepassing is';

  @override
  String get contentPreferencesDoneNoLabels => 'Klaar (geen labels)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Klaar ($count geselecteerd)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Audio-invoerapparaat';

  @override
  String get contentPreferencesAutoRecommended => 'Automatisch (aanbevolen)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Kiest automatisch de beste microfoon';

  @override
  String get contentPreferencesSelectAudioInput => 'Kies audio-invoer';

  @override
  String get contentPreferencesUnknownMicrophone => 'Onbekende microfoon';

  @override
  String get contentFiltersAdultContent => 'INHOUD VOOR VOLWASSENEN';

  @override
  String get contentFiltersViolenceGore => 'GEWELD & BLOED';

  @override
  String get contentFiltersSubstances => 'MIDDELEN';

  @override
  String get contentFiltersOther => 'OVERIG';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifieer je leeftijd bij Veiligheid & privacy om filters voor volwassen inhoud vrij te schakelen';

  @override
  String get contentFiltersShow => 'Tonen';

  @override
  String get contentFiltersWarn => 'Waarschuwen';

  @override
  String get contentFiltersFilterOut => 'Eruit filteren';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Dit account is niet beschikbaar';

  @override
  String get profileInvalidId => 'Ongeldige profiel-ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Bekijk $displayName op Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName op Divine';
  }

  @override
  String get profileShareFailed =>
      'Profiel delen mislukt. Probeer het opnieuw.';

  @override
  String get profileCopyPublicKey => 'Publieke sleutel kopiëren (npub)';

  @override
  String get profileGetEmbedCode => 'Embedcode ophalen';

  @override
  String get profilePublicKeyCopied =>
      'Publieke sleutel gekopieerd naar klembord';

  @override
  String get profileEmbedCodeCopied => 'Embedcode gekopieerd naar klembord';

  @override
  String get profileMoreTooltip => 'Meer';

  @override
  String get profileMoreSemanticLabel => 'Meer opties';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Avatar sluiten';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Avatarvoorbeeld sluiten';

  @override
  String get profileFollowingLabel => 'Volgend';

  @override
  String get profileFollowLabel => 'Volgen';

  @override
  String get profileBlockedLabel => 'Geblokkeerd';

  @override
  String get profileFollowersLabel => 'Volgers';

  @override
  String get profileFollowingStatLabel => 'Volgend';

  @override
  String get profileVideosLabel => 'Video\'s';

  @override
  String get profileCollabsLabel => 'Collabs';

  @override
  String get profileLikedLabel => 'Leuk gevonden';

  @override
  String get profileRepostsLabel => 'Reposts';

  @override
  String get profileListsLabel => 'Lijsten';

  @override
  String get profileCommentsLabel => 'Reacties';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count uitnodigingen voor samenwerking moeten nog verzonden worden',
      one: '1 uitnodiging voor samenwerking moet nog verzonden worden',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'We hebben de uitnodiging in de wachtrij gezet. Probeer het hier opnieuw.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Voor \"$title\". Probeer het hier opnieuw.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Opnieuw proberen';

  @override
  String get profileCollaboratorInviteRetryingAction =>
      'Bezig met opnieuw proberen';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Opnieuw proberen van samenwerkingsuitnodiging is nu niet beschikbaar.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samenwerkingsuitnodigingen moeten nog verzonden worden.',
      one: '1 samenwerkingsuitnodiging moet nog verzonden worden.',
      zero: 'Samenwerkingsuitnodigingen verzonden.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samenwerkers kunnen geen uitnodigingen ontvangen.',
      one: '1 samenwerker kan geen uitnodigingen ontvangen.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count gebruikers';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName blokkeren?';
  }

  @override
  String get profileBlockExplanation => 'Als je iemand blokkeert:';

  @override
  String get profileBlockBulletHidePosts =>
      'Hun posts verschijnen niet meer in jouw feeds.';

  @override
  String get profileBlockBulletCantView =>
      'Ze kunnen jouw profiel niet bekijken, je niet volgen en je posts niet zien.';

  @override
  String get profileBlockBulletNoNotify => 'Ze krijgen hiervan geen melding.';

  @override
  String get profileBlockBulletYouCanView =>
      'Jij kunt hun profiel nog wel bekijken.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName blokkeren';
  }

  @override
  String get profileCancelButton => 'Annuleren';

  @override
  String get profileLearnMore => 'Meer info';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName deblokkeren?';
  }

  @override
  String get profileUnblockExplanation => 'Als je deze gebruiker deblokkeert:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Hun posts verschijnen weer in jouw feeds.';

  @override
  String get profileUnblockBulletCanView =>
      'Ze kunnen jouw profiel bekijken, je volgen en je posts zien.';

  @override
  String get profileUnblockBulletNoNotify => 'Ze krijgen hiervan geen melding.';

  @override
  String get profileLearnMoreAt => 'Meer info op ';

  @override
  String get profileUnblockButton => 'Deblokkeren';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName ontvolgen';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName blokkeren';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName deblokkeren';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '$displayName rapporteren';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayName aan een lijst toevoegen';
  }

  @override
  String get profileNoCollabsTitle => 'Nog geen samenwerkingen';

  @override
  String get profileCollabsOwnEmpty =>
      'Video\'s waar je aan meewerkt verschijnen hier';

  @override
  String get profileCollabsOtherEmpty =>
      'Video\'s waar zij aan meewerken verschijnen hier';

  @override
  String get profileErrorLoadingCollabs =>
      'Fout bij laden van samenwerkingsvideo\'s';

  @override
  String get profileNoSavedVideosTitle => 'Nog niets bewaard';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark video\'s vanuit het deelmenu en ze duiken hier op.';

  @override
  String get profileErrorLoadingSaved => 'Fout bij laden van bewaarde video\'s';

  @override
  String get profileNoCommentsOwnTitle => 'Nog geen reacties';

  @override
  String get profileNoCommentsOtherTitle => 'Geen reacties';

  @override
  String get profileCommentsOwnEmpty =>
      'Je reacties en antwoorden verschijnen hier';

  @override
  String get profileCommentsOtherEmpty =>
      'Hun reacties en antwoorden verschijnen hier';

  @override
  String get profileErrorLoadingComments => 'Fout bij laden van reacties';

  @override
  String get profileVideoRepliesSection => 'Videoreacties';

  @override
  String get profileCommentsSection => 'Reacties';

  @override
  String get profileEditLabel => 'Bewerken';

  @override
  String get profileLibraryLabel => 'Bibliotheek';

  @override
  String get profileNoLikedVideosTitle => 'Nog geen gelikete video\'s';

  @override
  String get profileLikedOwnEmpty => 'Video\'s die je liket verschijnen hier';

  @override
  String get profileLikedOtherEmpty =>
      'Video\'s die zij liken verschijnen hier';

  @override
  String get profileErrorLoadingLiked => 'Fout bij laden van gelikete video\'s';

  @override
  String get profileNoRepostsTitle => 'Nog geen reposts';

  @override
  String get profileRepostsOwnEmpty =>
      'Video\'s die je repost verschijnen hier';

  @override
  String get profileRepostsOtherEmpty =>
      'Video\'s die zij reposten verschijnen hier';

  @override
  String get profileErrorLoadingReposts => 'Fout bij laden van reposts';

  @override
  String get profileNoVideosTitle => 'Nog geen video\'s';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Deel je eerste video om hem hier te zien';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Deze gebruiker heeft nog geen video\'s gedeeld';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Videominiatuur $number';
  }

  @override
  String get profileShowMore => 'Meer weergeven';

  @override
  String get profileShowLess => 'Minder weergeven';

  @override
  String get dmMessageDisplayLimitReached =>
      'De rest van dit bericht wordt niet weergegeven.';

  @override
  String get profileCompleteYourProfile => 'Maak je profiel af';

  @override
  String get profileCompleteSubtitle =>
      'Voeg je naam, bio en foto toe om te beginnen';

  @override
  String get profilePleaseTryAgain => 'Probeer het opnieuw';

  @override
  String get profileSecureYourAccount => 'Beveilig je account';

  @override
  String get profileSecureSubtitle =>
      'Voeg e-mail & wachtwoord toe om je account op elk apparaat te herstellen';

  @override
  String get profileRetryButton => 'Opnieuw proberen';

  @override
  String get profileSessionExpired => 'Sessie verlopen';

  @override
  String get profileSignInToRestore =>
      'Log opnieuw in om volledige toegang te herstellen';

  @override
  String get profileSignInButton => 'Inloggen';

  @override
  String get profileMaybeLaterLabel => 'Misschien later';

  @override
  String get profileSecurePrimaryButton => 'E-mail & wachtwoord toevoegen';

  @override
  String get profileCompletePrimaryButton => 'Werk je profiel bij';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Likes';

  @override
  String get profileMyLibraryLabel => 'Mijn bibliotheek';

  @override
  String get profileMessageLabel => 'Bericht';

  @override
  String get profileShareLabel => 'Profiel delen';

  @override
  String get profileDeletedAccountName => 'Verwijderd account';

  @override
  String get inboxActionReportVanishedAccount => 'Dit account rapporteren';

  @override
  String get inboxActionBlockVanishedAccount => 'Dit account blokkeren';

  @override
  String get inboxActionUnblockVanishedAccount => 'Dit account deblokkeren';

  @override
  String get inboxReportedVanishedAccount => 'Dit account is gerapporteerd';

  @override
  String get inboxBlockedVanishedAccount => 'Dit account is geblokkeerd';

  @override
  String get inboxUnblockedVanishedAccount => 'Dit account is gedeblokkeerd';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Hiermee verwijder je het gesprek uit je inbox. Als deze persoon je weer een bericht stuurt, begint er een nieuw gesprek.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Dit account is verwijderd';

  @override
  String get profileUserFallback => 'gebruiker';

  @override
  String get profileLinkCopied => 'Profiellink gekopieerd';

  @override
  String get profileSetupEditProfileTitle => 'Profiel bewerken';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Stel je profiel in voordat je een NIP-05-adres toevoegt.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Profiel maken';

  @override
  String get profileSetupBackLabel => 'Terug';

  @override
  String get profileSetupAboutNostr => 'Over Nostr';

  @override
  String get profileSetupProfilePublished => 'Profiel succesvol gepubliceerd!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Wijzigingen opslaan?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Sla je wijzigingen op voordat je weggaat, of gooi ze weg en ga verder.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Wijzigingen opslaan';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Wijzigingen weggooien';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Verder bewerken';

  @override
  String get profileSetupCreateNewProfile => 'Nieuw profiel aanmaken?';

  @override
  String get profileSetupNoExistingProfile =>
      'We vonden geen bestaand profiel op je relays. Publiceren maakt een nieuw profiel aan. Doorgaan?';

  @override
  String get profileSetupPublishButton => 'Publiceren';

  @override
  String get profileSetupUsernameTaken =>
      'Deze gebruikersnaam is net bezet. Kies een andere.';

  @override
  String get profileSetupClaimFailed =>
      'Gebruikersnaam claimen mislukt. Probeer het opnieuw.';

  @override
  String get profileSetupPublishFailed =>
      'Profiel publiceren mislukt. Probeer het opnieuw.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Kan het netwerk niet bereiken. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get profileSetupDisplayNameLabel => 'Weergavenaam';

  @override
  String get profileSetupDisplayNameRequired => 'Voer een weergavenaam in';

  @override
  String get profileSetupBioLabel => 'Bio (optioneel)';

  @override
  String get profileSetupWebsiteLabel => 'Website (optioneel)';

  @override
  String get profileSetupPublicKeyLabel => 'Publieke sleutel (npub)';

  @override
  String get profileSetupUsernameLabel => 'Gebruikersnaam (optioneel)';

  @override
  String get profileSetupUsernameHelper =>
      'Gebruik letters, cijfers of koppeltekens. Je gebruikersnaam wordt een divine.video-adres. Gebruik je weergavenaam voor spaties of symbolen.';

  @override
  String get profileSetupSaveButton => 'Opslaan';

  @override
  String get profileSetupSavingButton => 'Opslaan...';

  @override
  String get profileSetupImageUrlTitle => 'Afbeeldings-URL toevoegen';

  @override
  String get profileSetupImageSelectionFailed =>
      'Afbeelding kiezen mislukt. Plak hieronder een afbeeldings-URL.';

  @override
  String get profileSetupImagesTypeGroup => 'afbeeldingen';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Cameratoegang staat uit. Zet het aan in Instellingen om een foto te maken.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Cameratoegang is niet toegestaan op dit apparaat.';

  @override
  String get cameraPickErrorBusy =>
      'De kiezer is al open. Sluit hem en probeer het opnieuw.';

  @override
  String get cameraPickErrorGeneric =>
      'De camera kon niet geopend worden. Probeer het opnieuw.';

  @override
  String get profileSetupGotItButton => 'Begrepen';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Uploaden van afbeelding mislukt. Probeer het later opnieuw.';

  @override
  String get profileSetupUploadNetworkError =>
      'Netwerkfout: check je internetverbinding en probeer opnieuw.';

  @override
  String get profileSetupUploadAuthError =>
      'Authenticatiefout: log uit en weer in.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Bestand te groot: kies een kleinere afbeelding (max 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Uploaden van afbeelding mislukt. Onze servers zijn tijdelijk niet beschikbaar. Probeer het zo opnieuw.';

  @override
  String get profileSetupBannerClearButton => 'Banner wissen';

  @override
  String get profileSetupBannerChangeColor => 'Bannerkleur';

  @override
  String get profileSetupChangeBannerTitle => 'Banner wijzigen';

  @override
  String get profileSetupBannerColorPickerTitle => 'Bannerkleur wijzigen';

  @override
  String get profileSetupBannerColorCustom => 'Aangepast';

  @override
  String get profileSetupBannerColorNone => 'Geen kleur';

  @override
  String get profileSetupBannerColorLime => 'Limoen';

  @override
  String get profileSetupBannerColorYellow => 'Geel';

  @override
  String get profileSetupBannerColorViolet => 'Violet';

  @override
  String get profileSetupBannerColorPink => 'Roze';

  @override
  String get profileSetupBannerColorOrange => 'Oranje';

  @override
  String get profileSetupBannerColorPurple => 'Paars';

  @override
  String get profileSetupAvatarClearButton => 'Foto verwijderen';

  @override
  String get profileSetupImageTakePhoto => 'Foto maken';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Uploaden uit de fotorol';

  @override
  String get profileSetupImagePasteLink => 'Afbeeldingslink plakken';

  @override
  String get profileSetupEditAvatarLabel => 'Profielfoto bewerken';

  @override
  String get profileSetupEditBannerLabel => 'Banner bewerken';

  @override
  String get profileSetupUsernameChecking => 'Beschikbaarheid controleren...';

  @override
  String get profileSetupUsernameAvailable => 'Gebruikersnaam beschikbaar!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Gebruikersnaam al in gebruik';

  @override
  String get profileSetupUsernameReserved => 'Gebruikersnaam is gereserveerd';

  @override
  String get profileSetupContactSupport => 'Neem contact op met support';

  @override
  String get profileSetupCheckAgain => 'Opnieuw controleren';

  @override
  String get profileSetupUsernameBurned =>
      'Deze gebruikersnaam is niet meer beschikbaar';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Alleen letters, cijfers en koppeltekens zijn toegestaan';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'De gebruikersnaam mag niet met een koppelteken beginnen of eindigen';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Gebruikersnaam moet 3-63 tekens zijn';

  @override
  String get profileSetupUsernameNetworkError =>
      'Beschikbaarheid checken mislukt. Probeer opnieuw.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Ongeldig formaat voor gebruikersnaam';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Beschikbaarheid checken mislukt';

  @override
  String get profileSetupUsernameReservedTitle => 'Gebruikersnaam gereserveerd';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'De naam $username is gereserveerd. Vertel ons waarom hij van jou zou moeten zijn.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'Bijv. het is mijn merknaam, artiestennaam, enz.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Al contact opgenomen met support? Tik op \"Opnieuw controleren\" om te zien of hij aan jou is toegewezen.';

  @override
  String get profileSetupSupportRequestSent =>
      'Supportverzoek verzonden! We nemen snel contact op.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'E-mail openen mislukt. Stuur naar: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Verzoek versturen';

  @override
  String get profileSetupUseOwnNip05 => 'Gebruik je eigen NIP-05-adres';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05-adres';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Ongeldig NIP-05-formaat (bijv. naam@domein.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Gebruik het gebruikersnaamveld hierboven voor divine.video';

  @override
  String get nostrSettingsNip05Address => 'NIP-05-adres';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Gebruik je divine.video-gebruikersnaam, of laat je handle wijzen naar een NIP-05-adres op een domein dat je zelf beheert.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'NIP-05 opslaan';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 opgeslagen';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'NIP-05 kon niet worden opgeslagen. Probeer het opnieuw.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Je eigen NIP-05 gebruiken?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 koppelt een naam als jij@jouwdomein.nl aan je Nostr-identiteit. Je moet het domein beheren en een verificatiebestand op het juiste pad zetten. Klopt er iets niet, dan vinden mensen je niet meer en verdwijnt je geverifieerde handle. Ga alleen verder als je dit al hebt ingesteld.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Doorgaan';

  @override
  String get profileSetupNip05ConfirmCancel => 'Annuleren';

  @override
  String get profileSetupProfilePicturePreview => 'Voorbeeld profielfoto';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine is gebouwd op Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' een censuurbestendig open protocol waarmee mensen online kunnen communiceren zonder afhankelijk te zijn van één bedrijf of platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Als je je aanmeldt bij Divine krijg je een nieuwe Nostr-identiteit.';

  @override
  String get nostrInfoOwnership =>
      'Met Nostr heb je je eigen inhoud, identiteit en sociale graaf in handen, die je in veel apps kunt gebruiken. Resultaat: meer keuze, minder lock-in en een gezonder, veerkrachtiger sociaal internet.';

  @override
  String get nostrInfoLingo => 'Nostr-jargon:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Je publieke Nostr-adres. Veilig om te delen: anderen kunnen je zo vinden, volgen of berichten sturen in Nostr-apps.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Je privésleutel en eigendomsbewijs. Hij geeft volledige controle over je Nostr-identiteit, dus ';

  @override
  String get nostrInfoNsecWarning => 'houd hem altijd geheim!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr-gebruikersnaam:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Een menselijk leesbare naam (zoals @naam.divine.video) die naar je npub verwijst. Het maakt je Nostr-identiteit makkelijker te herkennen en verifiëren, vergelijkbaar met een e-mailadres.';

  @override
  String get nostrInfoLearnMoreAt => 'Meer info op ';

  @override
  String get nostrInfoGotIt => 'Begrepen!';

  @override
  String get videoGridRefreshLabel => 'Zoeken naar meer video\'s';

  @override
  String get videoGridOptionsTitle => 'Video-opties';

  @override
  String get videoGridEditVideo => 'Video bewerken';

  @override
  String get videoGridEditVideoSubtitle =>
      'Titel, beschrijving en hashtags bijwerken';

  @override
  String get videoGridDeleteVideo => 'Video verwijderen';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Deze video uit Divine verwijderen. Hij kan nog steeds verschijnen in andere Nostr-clients.';

  @override
  String get videoGridDeletingContent => 'Inhoud verwijderen...';

  @override
  String get exploreTabFeatured => 'Uitgelicht';

  @override
  String get exploreTabClassics => 'Klassiekers';

  @override
  String get exploreTabNew => 'Nieuw';

  @override
  String get exploreTabPopular => 'Populair';

  @override
  String get exploreTabCategories => 'Categorieën';

  @override
  String get exploreTabForYou => 'Voor jou';

  @override
  String get exploreTabLists => 'Lijsten';

  @override
  String get exploreTabIntegratedApps => 'Geïntegreerde apps';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Hier staat nog niets. Kom binnenkort terug.';

  @override
  String get featuredTabLoadFailed => 'Deze collectie kon niet worden geladen.';

  @override
  String get featuredTabRetry => 'Probeer opnieuw';

  @override
  String get exploreNoVideosAvailable => 'Geen video\'s beschikbaar';

  @override
  String get exploreDiscoverLists => 'Lijsten ontdekken';

  @override
  String get exploreAboutLists => 'Over lijsten';

  @override
  String get exploreAboutListsDescription =>
      'Met lijsten kun je Divine-inhoud op twee manieren organiseren en samenstellen:';

  @override
  String get explorePeopleLists => 'Personenlijsten';

  @override
  String get explorePeopleListsDescription =>
      'Volg groepen makers en bekijk hun nieuwste video\'s';

  @override
  String get exploreVideoLists => 'Videolijsten';

  @override
  String get exploreVideoListsDescription =>
      'Maak afspeellijsten van je favoriete video\'s om later te bekijken';

  @override
  String get exploreMyLists => 'Mijn lijsten';

  @override
  String get exploreSubscribedLists => 'Gevolgde lijsten';

  @override
  String get exploreErrorLoadingLists =>
      'Fout bij laden van lijsten. Probeer het opnieuw.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieuwe video\'\'s',
      one: '1 nieuwe video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieuwe video\'\'s',
      one: '1 nieuwe video',
    );
    return '$_temp0 laden';
  }

  @override
  String get videoPlayerPlayVideo => 'Video afspelen';

  @override
  String get videoPlayerMute => 'Video dempen';

  @override
  String get videoPlayerUnmute => 'Videogeluid inschakelen';

  @override
  String get videoPlayerTapHint =>
      'Tik om af te spelen of te pauzeren. Dubbel tikken om te liken.';

  @override
  String get videoSettingsMenuOpen => 'Afspeelinstellingen openen';

  @override
  String get videoSettingsMenuClose => 'Afspeelinstellingen sluiten';

  @override
  String get videoSettingsCaptionsEnable => 'Ondertiteling inschakelen';

  @override
  String get videoSettingsCaptionsDisable => 'Ondertiteling uitschakelen';

  @override
  String get videoSettingsAutoAdvanceOn => 'Automatisch doorgaan aan';

  @override
  String get videoSettingsAutoAdvanceOff => 'Automatisch doorgaan uit';

  @override
  String get videoSettingsCaptionsOn => 'Ondertiteling aan';

  @override
  String get videoSettingsCaptionsOff => 'Ondertiteling uit';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Ondertiteling aan voor deze video';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Ondertiteling uit voor deze video';

  @override
  String get contentWarningLabel => 'Inhoudswaarschuwing';

  @override
  String get contentWarningNudity => 'Naaktheid';

  @override
  String get contentWarningSexualContent => 'Seksuele inhoud';

  @override
  String get contentWarningPornography => 'Pornografie';

  @override
  String get contentWarningGraphicMedia => 'Expliciete media';

  @override
  String get contentWarningViolence => 'Geweld';

  @override
  String get contentWarningSelfHarm => 'Zelfbeschadiging';

  @override
  String get contentWarningDrugUse => 'Drugsgebruik';

  @override
  String get contentWarningAlcohol => 'Alcohol';

  @override
  String get contentWarningTobacco => 'Tabak';

  @override
  String get contentWarningGambling => 'Gokken';

  @override
  String get contentWarningProfanity => 'Grof taalgebruik';

  @override
  String get contentWarningFlashingLights => 'Flitslichten';

  @override
  String get contentWarningAiGenerated => 'AI-gegenereerd';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Gevoelige inhoud';

  @override
  String get contentWarningDescNudity =>
      'Bevat naaktheid of gedeeltelijke naaktheid';

  @override
  String get contentWarningDescSexual => 'Bevat seksuele inhoud';

  @override
  String get contentWarningDescPorn => 'Bevat expliciete pornografische inhoud';

  @override
  String get contentWarningDescGraphicMedia =>
      'Bevat expliciete of verontrustende beelden';

  @override
  String get contentWarningDescViolence => 'Bevat gewelddadige inhoud';

  @override
  String get contentWarningDescSelfHarm =>
      'Bevat verwijzingen naar zelfbeschadiging';

  @override
  String get contentWarningDescDrugs => 'Bevat drugsgerelateerde inhoud';

  @override
  String get contentWarningDescAlcohol => 'Bevat alcoholgerelateerde inhoud';

  @override
  String get contentWarningDescTobacco => 'Bevat tabaksgerelateerde inhoud';

  @override
  String get contentWarningDescGambling => 'Bevat gokgerelateerde inhoud';

  @override
  String get contentWarningDescProfanity => 'Bevat grof taalgebruik';

  @override
  String get contentWarningDescFlashingLights =>
      'Bevat flitslichten (waarschuwing voor lichtgevoeligheid)';

  @override
  String get contentWarningDescAiGenerated =>
      'Deze inhoud is door AI gegenereerd';

  @override
  String get contentWarningDescSpoiler => 'Bevat spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'De maker heeft dit als gevoelig gemarkeerd';

  @override
  String get contentWarningDescDefault =>
      'De maker heeft deze inhoud gemarkeerd';

  @override
  String get contentWarningDetailsTitle => 'Inhoudswaarschuwingen';

  @override
  String get contentWarningDetailsSubtitle =>
      'De maker heeft deze labels toegepast:';

  @override
  String get contentWarningManageFilters => 'Inhoudsfilters beheren';

  @override
  String get contentWarningViewAnyway => 'Toch bekijken';

  @override
  String get contentWarningReportContentTooltip => 'Inhoud rapporteren';

  @override
  String get contentWarningBlockUserTooltip => 'Gebruiker blokkeren';

  @override
  String get contentWarningBlockedTitle => 'Inhoud geblokkeerd';

  @override
  String get contentWarningBlockedPolicy =>
      'Deze inhoud is geblokkeerd vanwege schending van het beleid.';

  @override
  String get contentWarningNoticeTitle => 'Inhoudsmelding';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Mogelijk schadelijke inhoud';

  @override
  String get contentWarningView => 'Bekijken';

  @override
  String get contentWarningReportAction => 'Rapporteren';

  @override
  String get contentWarningHideAllLikeThis => 'Verberg alle inhoud zoals deze';

  @override
  String get contentWarningNoFilterYet =>
      'Nog geen opgeslagen filter voor deze waarschuwing.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Vanaf nu verbergen we posts zoals deze.';

  @override
  String get communitySuggestTitle => 'Help dit te classificeren';

  @override
  String get communitySuggestSubtitle =>
      'Mist er een inhoudswaarschuwing? Je suggestie is openbaar, ondertekend en kan niet worden teruggenomen.';

  @override
  String get communitySuggestSubmit => 'Voorstellen';

  @override
  String get communitySuggestSuccess => 'Bedankt. Je suggestie is verstuurd.';

  @override
  String get communitySuggestFailure =>
      'Je suggestie kon niet worden verstuurd. Probeer het opnieuw.';

  @override
  String get communitySuggestAlready => 'Je hebt dit al voorgesteld';

  @override
  String get communitySuggestActionLabel => 'Classificeren';

  @override
  String get videoErrorNotFound => 'Video niet gevonden';

  @override
  String get videoErrorPlayback => 'Fout bij afspelen video';

  @override
  String get videoErrorAgeRestricted => 'Leeftijdsbeperkte inhoud';

  @override
  String get videoErrorUnavailable => 'Video niet beschikbaar';

  @override
  String get videoErrorUnavailableBody => 'Deze video is nu niet beschikbaar.';

  @override
  String get videoErrorRetry => 'Opnieuw';

  @override
  String get videoErrorContentRestricted => 'Inhoud beperkt';

  @override
  String get videoErrorContentRestrictedBody =>
      'Deze video is verwijderd omdat hij onze contentregels overtrad.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifieer je leeftijd om deze video te bekijken.';

  @override
  String get videoErrorSkip => 'Overslaan';

  @override
  String get videoErrorVerifyAgeButton => 'Leeftijd verifiëren';

  @override
  String get videoErrorVerifyAgeFailed =>
      'We konden je leeftijd niet verifiëren. Probeer het opnieuw.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Verificatie duurde te lang. Controleer je verbinding of probeer het straks opnieuw.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Inhoud voor volwassenen staat uit';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Zet het aan in je inhoudsfilters om deze video te bekijken.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Inhoudsfilters openen';

  @override
  String get videoDetailLoadError => 'Video laden mislukt';

  @override
  String get videoDetailLoadErrorBody =>
      'Er ging onderweg iets mis. Probeer het nog eens.';

  @override
  String get videoDetailNotFoundBody =>
      'Misschien is hij verwijderd, buiten bereik, of verborgen door je instellingen.';

  @override
  String get databaseCorruptionTitle => 'Je lokale gegevens zijn beschadigd';

  @override
  String get databaseCorruptionBody =>
      'Sluit Divine en open het opnieuw — we repareren het automatisch. We redden wat we kunnen van je concepten en clips, de rest laadt opnieuw.';

  @override
  String get databaseCorruptionCloseButton => 'Divine sluiten';

  @override
  String get videoDetailContextTitle => 'Gedeelde video';

  @override
  String get videoDetailCloseSemanticLabel => 'Videospeler sluiten';

  @override
  String get videoFollowButtonFollow => 'Volgen';

  @override
  String get audioAttributionOriginalSound => 'Origineel geluid';

  @override
  String get audioAttributionUnavailableSound => 'Geluid niet beschikbaar';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Geïnspireerd door @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Geïnspireerd door @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'met @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'met @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samenwerkers',
      one: '1 samenwerker',
    );
    return '$_temp0. Tik om het profiel te bekijken.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'In afwachting';

  @override
  String get videoCollaboratorPendingSemanticLabel =>
      'Samenwerker in afwachting';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending in afwachting)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Tik om het profiel te bekijken.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Tik om video\'s met deze hashtag te bekijken.';
  }

  @override
  String get listAttributionFallback => 'Lijst';

  @override
  String get shareVideoLabel => 'Video delen';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post gedeeld met $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Post gedeeld met $count personen',
      one: 'Post gedeeld met $count persoon',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Video versturen mislukt';

  @override
  String get shareAddedToBookmarks => 'Toegevoegd aan bladwijzers';

  @override
  String get shareRemovedFromBookmarks => 'Verwijderd uit bladwijzers';

  @override
  String get shareFailedToAddBookmark => 'Bladwijzer toevoegen mislukt';

  @override
  String get shareFailedToRemoveBookmark =>
      'Verwijderen uit bladwijzers mislukt';

  @override
  String get shareActionFailed => 'Actie mislukt';

  @override
  String get shareWithTitle => 'Delen met';

  @override
  String get shareFindPeople => 'Mensen zoeken';

  @override
  String get shareFindPeopleMultiline => 'Mensen\nzoeken';

  @override
  String get shareSent => 'Verzonden';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name geselecteerd';
  }

  @override
  String get shareMessageHint => 'Voeg optioneel een bericht toe...';

  @override
  String get videoActionUnlike => 'Like verwijderen';

  @override
  String get videoActionLike => 'Video liken';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Liken';

  @override
  String get videoActionReplyLabel => 'Reageren';

  @override
  String get videoActionRepostLabel => 'Repost';

  @override
  String get videoActionShareLabel => 'Delen';

  @override
  String get videoActionReportLabel => 'Rapporteren';

  @override
  String get videoActionReport => 'Video rapporteren';

  @override
  String get videoActionEditLabel => 'Bewerken';

  @override
  String get videoActionEdit => 'Video bewerken';

  @override
  String get videoActionAboutLabel => 'Over';

  @override
  String get videoActionEnableAutoAdvance => 'Automatisch doorgaan inschakelen';

  @override
  String get videoActionDisableAutoAdvance =>
      'Automatisch doorgaan uitschakelen';

  @override
  String get videoActionRemoveRepost => 'Repost verwijderen';

  @override
  String get videoActionRepost => 'Video reposten';

  @override
  String get videoActionViewComments => 'Reacties bekijken';

  @override
  String get videoActionMoreOptions => 'Meer opties';

  @override
  String get videoEngagementLikersTitle => 'Geliket door';

  @override
  String get videoEngagementRepostersTitle => 'Gerepost door';

  @override
  String get videoEngagementLikersEmpty => 'Nog geen likes';

  @override
  String get videoEngagementRepostersEmpty => 'Nog geen reposts';

  @override
  String get videoEngagementLoadFailed => 'Kon die lijst niet laden';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Videodetails openen';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Videodetails openen';

  @override
  String get videoOverlayCommentBarHint => 'Reactie toevoegen...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Een reactie toevoegen';

  @override
  String get videoOverlayCommentBarSendLabel => 'Reactie verzenden';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Reactie geplaatst';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Reactie plaatsen mislukt';

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
  String get metadataBadgeNotDivine => 'Niet Divine';

  @override
  String get metadataBadgeHumanMade => 'Door mensen gemaakt';

  @override
  String get metadataSoundsLabel => 'Geluiden';

  @override
  String get metadataOriginalSound => 'Origineel geluid';

  @override
  String get metadataVerificationLabel => 'Verificatie';

  @override
  String get metadataDeviceAttestation => 'Apparaatattestatie';

  @override
  String get metadataPgpSignature => 'PGP-handtekening';

  @override
  String get metadataC2paCredentials => 'C2PA Content Credentials';

  @override
  String get metadataProofManifest => 'Proof-manifest';

  @override
  String get metadataVerificationInfoTooltip => 'Wat betekenen deze controles?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Wat deze controles betekenen';

  @override
  String get metadataVerificationInfoIntro =>
      'Deze signalen komen van de camera en uit het videobestand zelf. Hoe meer een video er heeft, hoe meer we over de herkomst kunnen aantonen.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Het besturingssysteem van de telefoon stond in voor de app die dit opnam. Sterk bewijs dat het van een camera komt en niet van een geüpload bestand.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'De video is op het moment van opname cryptografisch ondertekend. Verandert daarna één beeldje, dan breekt de handtekening.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Een herkomstbewijs volgens de industriestandaard dat in het bestand meereist — zo kunnen ook andere apps dan Divine het controleren.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Het volledige ProofMode-record: bestandsvingerafdruk, tijdstempel en opnamecontext, samen met de video.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Een ontbrekende controle maakt een video niet nep. Oudere clips en uploads kregen er nooit een — het betekent alleen dat we dat deel niet kunnen aantonen.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Meer weten op $url';
  }

  @override
  String get metadataCreatorLabel => 'Maker';

  @override
  String get metadataCollaboratorsLabel => 'Samenwerkers';

  @override
  String get metadataInspiredByLabel => 'Geïnspireerd door';

  @override
  String get metadataRepostedByLabel => 'Gerepost door';

  @override
  String metadataMoreReposters(int count) {
    return '+$count meer';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'Likes';

  @override
  String get metadataCommentsLabel => 'Reacties';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get metadataVineStatsLabel => 'Op Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loops · $likes likes · $comments reacties · $reposts reposts';
  }

  @override
  String get metadataDivineStatsLabel => 'Op Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views weergaven · $likes likes · $comments reacties · $reposts reposts';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Geplaatst op $date';
  }

  @override
  String get devOptionsTitle => 'Ontwikkelaarsopties';

  @override
  String get devOptionsDisableDeveloperMode =>
      'Ontwikkelaarsmodus uitschakelen';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Ontwikkelaarsopties verbergen in instellingen';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Ontwikkelaarsmodus uitgeschakeld';

  @override
  String get devOptionsShorebirdTitle => 'Shorebird-patches';

  @override
  String get devOptionsShorebirdPatchLabel => 'Actieve patch';

  @override
  String get devOptionsShorebirdNoPatch => 'Geen patch geïnstalleerd';

  @override
  String get devOptionsShorebirdUnavailable => 'Niet beschikbaar in deze build';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Patches werken alleen in een build die met shorebird release is gemaakt.';

  @override
  String get devOptionsShorebirdLoading => 'Patchstatus lezen…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Stagingtrack nog niet gecontroleerd.';

  @override
  String get devOptionsShorebirdCheck => 'Stagingtrack controleren';

  @override
  String get devOptionsShorebirdApply => 'Stagingpatch toepassen';

  @override
  String get devOptionsShorebirdUseStable => 'Terug naar stabiele updates';

  @override
  String get devOptionsShorebirdChecking => 'Stagingtrack controleren…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Er staat een stagingpatch klaar.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Geen stagingpatch voor deze versie.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Gedownload. Start de app opnieuw om hem te laden.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Er staat een terugdraaiing klaar. Start opnieuw om terug te gaan naar de basisversie.';

  @override
  String get devOptionsShorebirdApplying => 'Downloaden en installeren…';

  @override
  String get devOptionsShorebirdApplied =>
      'Geïnstalleerd. Start de app opnieuw om hem te laden.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Er is niets geïnstalleerd. Controleer de stagingtrack en probeer opnieuw.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Stabiel kanaal selecteren…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Stabiel kanaal geselecteerd. Start de app opnieuw om op een stabiele patch te controleren.';

  @override
  String get devOptionsShorebirdFailure =>
      'Dat werkte niet. Bekijk de logs voor details.';

  @override
  String get devOptionsPageLoadTimes => 'Laadtijden per pagina';

  @override
  String get devOptionsNoPageLoads =>
      'Nog geen paginaladingen geregistreerd.\nNavigeer door de app om timingdata te zien.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Zichtbaar: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Traagste schermen';

  @override
  String get devOptionsVideoPlaybackFormat => 'Videoformaat voor afspelen';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Omgeving wisselen?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Wisselen naar $envName?\n\nDit wist cached videodata en verbindt opnieuw met de nieuwe relay.';
  }

  @override
  String get devOptionsCancel => 'Annuleren';

  @override
  String get devOptionsSwitch => 'Wisselen';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Gewisseld naar $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Gewisseld naar $formatName — cache gewist';
  }

  @override
  String get featureFlagTitle => 'Feature flags';

  @override
  String get featureFlagResetAllTooltip =>
      'Alle flags terugzetten naar standaard';

  @override
  String get featureFlagError => 'Fout';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine is een open systeem — jij beheert je verbindingen';

  @override
  String get relaySettingsInfoDescription =>
      'Deze relays verspreiden jouw inhoud over het gedecentraliseerde Nostr-netwerk. Je kunt relays naar wens toevoegen of verwijderen.';

  @override
  String get relaySettingsLearnMoreNostr => 'Meer over Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Vind publieke relays op nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App niet functioneel';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine heeft minstens één relay nodig om video\'s te laden, inhoud te posten en data te synchroniseren.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Standaardrelay herstellen';

  @override
  String get relaySettingsAddCustomRelay => 'Eigen relay toevoegen';

  @override
  String get relaySettingsAddRelay => 'Relay toevoegen';

  @override
  String get relaySettingsRetry => 'Opnieuw';

  @override
  String get relaySettingsNoStats => 'Nog geen statistieken beschikbaar';

  @override
  String get relaySettingsConnection => 'Verbinding';

  @override
  String get relaySettingsConnected => 'Verbonden';

  @override
  String get relaySettingsDisconnected => 'Verbinding verbroken';

  @override
  String get relaySettingsSessionDuration => 'Sessieduur';

  @override
  String get relaySettingsLastConnected => 'Laatst verbonden';

  @override
  String get relaySettingsDisconnectedLabel => 'Verbinding verbroken';

  @override
  String get relaySettingsReason => 'Reden';

  @override
  String get relaySettingsActiveSubscriptions => 'Actieve abonnementen';

  @override
  String get relaySettingsTotalSubscriptions => 'Totaal abonnementen';

  @override
  String get relaySettingsEventsReceived => 'Ontvangen events';

  @override
  String get relaySettingsEventsSent => 'Verzonden events';

  @override
  String get relaySettingsRequestsThisSession => 'Verzoeken deze sessie';

  @override
  String get relaySettingsFailedRequests => 'Mislukte verzoeken';

  @override
  String get relaySettingsLoadingRelayInfo => 'Relay-info laden...';

  @override
  String get relaySettingsAboutRelay => 'Over relay';

  @override
  String get relaySettingsSupportedNips => 'Ondersteunde NIPs';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Website bekijken';

  @override
  String get relaySettingsRemoveRelayTitle => 'Relay verwijderen?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Weet je zeker dat je deze relay wilt verwijderen?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Divine-relay verwijderen?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Als je Divines relay verwijdert, gaat de app-ervaring achteruit. Video\'s, posten en synchroniseren worden mogelijk minder betrouwbaar. Doe dit alleen als je ervaring hebt met Nostr.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Relay verwijderen';

  @override
  String get relaySettingsCancel => 'Annuleren';

  @override
  String get relaySettingsRemove => 'Verwijderen';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay verwijderd: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Relay verwijderen mislukt';

  @override
  String get relaySettingsForcingReconnection =>
      'Relay opnieuw verbinden forceren...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Verbonden met $count relay(s)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Verbinden met relays mislukt. Check je netwerkverbinding.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Op dit apparaat opgeslagen. We synchroniseren het met je account zodra publiceren weer werkt.';

  @override
  String get relaySettingsAddRelayTitle => 'Relay toevoegen';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Voer de WebSocket-URL in van de relay die je wilt toevoegen:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Bekijk publieke relays op nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Toevoegen';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay toegevoegd: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Relay toevoegen mislukt. Check de URL en probeer opnieuw.';

  @override
  String get relaySettingsInvalidUrl =>
      'Relay-URL moet beginnen met wss:// of ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'Relay-URL moet wss:// gebruiken (ws:// is alleen toegestaan voor localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Standaardrelay hersteld: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Standaardrelay herstellen mislukt. Check je netwerkverbinding.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Browser openen mislukt';

  @override
  String get relaySettingsFailedToOpenLink => 'Link openen mislukt';

  @override
  String get relaySettingsExternalRelay => 'Externe relay';

  @override
  String get relaySettingsNotConnected => 'Niet verbonden';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return '$duration geleden verbroken';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count abonnementen';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count gebeurtenissen';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration geleden';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine gebruikt het Nostr-protocol voor decentraal publiceren. Je inhoud staat op relays die jij kiest, en je sleutels zijn je identiteit.';

  @override
  String get nostrSettingsSectionNetwork => 'Netwerk';

  @override
  String get nostrSettingsSectionAccount => 'Account';

  @override
  String get nostrSettingsSectionDangerZone => 'Gevarenzone';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle => 'Beheer Nostr-relayverbindingen';

  @override
  String get nostrSettingsRelayDiagnostics => 'Relaydiagnostiek';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debug relayverbinding en netwerkproblemen';

  @override
  String get nostrSettingsMediaServers => 'Mediaservers';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configureer Blossom-uploadservers';

  @override
  String get settingsDeveloperOptions => 'Ontwikkelaarsopties';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Omgevingswisselaar en debug-instellingen';

  @override
  String get nostrSettingsKeyManagement => 'Sleutelbeheer';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exporteer, back-up en herstel je Nostr-sleutels';

  @override
  String get nostrSettingsClientAttribution => 'Clienttoeschrijving';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Voeg een Divine-clienttag toe aan events die je publiceert, zodat andere Nostr-apps ze correct kunnen toeschrijven. Zonder die tag wegen je meldingen minder zwaar als onze moderators ze bekijken.';

  @override
  String get nostrSettingsMoveAccount => 'Verplaats je account';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Download je archief en verplaats je berichten en video\'s naar een andere relay of mediaserver.';

  @override
  String get nostrSettingsRemoveKeys => 'Sleutels van apparaat verwijderen';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Verwijder je privésleutel alleen van dit apparaat. Je inhoud blijft op relays staan, maar je hebt je nsec-back-up nodig om weer bij je account te komen.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Dit account kon niet van dit apparaat verwijderd worden. Probeer het opnieuw.';

  @override
  String get nostrSettingsDeleteAccount => 'Account en data verwijderen';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Stuurt verwijderverzoeken voor je content en meldt je op dit apparaat af. Relays, clients, zoekindexen en andere aangemelde apparaten kunnen kopieën bewaren.';

  @override
  String get relayDiagnosticTitle => 'Relay-diagnostiek';

  @override
  String get relayDiagnosticRefreshTooltip => 'Diagnostiek vernieuwen';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Laatste vernieuwing: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relay-status';

  @override
  String get relayDiagnosticInitialized => 'Geïnitialiseerd';

  @override
  String get relayDiagnosticReady => 'Klaar';

  @override
  String get relayDiagnosticNotInitialized => 'Niet geïnitialiseerd';

  @override
  String get relayDiagnosticDatabaseEvents => 'Database-events';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Actieve abonnementen';

  @override
  String get relayDiagnosticExternalRelays => 'Externe relays';

  @override
  String get relayDiagnosticConfigured => 'Geconfigureerd';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Verbonden';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video-events';

  @override
  String get relayDiagnosticHomeFeed => 'Home-feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video\'s';
  }

  @override
  String get relayDiagnosticDiscovery => 'Ontdekken';

  @override
  String get relayDiagnosticLoading => 'Laden';

  @override
  String get relayDiagnosticYes => 'Ja';

  @override
  String get relayDiagnosticNo => 'Nee';

  @override
  String get relayDiagnosticTestDirectQuery => 'Directe query testen';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Netwerkverbinding';

  @override
  String get relayDiagnosticRunNetworkTest => 'Netwerktest uitvoeren';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom-server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Alle endpoints testen';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Fout';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Basis-URL';

  @override
  String get relayDiagnosticSummary => 'Samenvatting';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (gem. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Alles opnieuw testen';

  @override
  String get relayDiagnosticRetrying => 'Opnieuw proberen...';

  @override
  String get relayDiagnosticRetryConnection => 'Verbinding opnieuw proberen';

  @override
  String get relayDiagnosticTroubleshooting => 'Probleemoplossing';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Groene status = verbonden en werkend\n• Rode status = verbinding mislukt\n• Als de netwerktest faalt, check je internetverbinding\n• Als relays geconfigureerd zijn maar niet verbonden, tik op \"Verbinding opnieuw proberen\"\n• Maak een screenshot van dit scherm voor debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Alle REST-endpoints gezond!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Sommige REST-endpoints faalden — zie details hierboven';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '$count video-events gevonden in database';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'Query mislukt. Probeer het opnieuw.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Verbonden met $count relay(s)!';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'Verbinden met relays mislukt';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Verbinding opnieuw proberen mislukt. Probeer het opnieuw.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Verbonden & geauthenticeerd';

  @override
  String get relayDiagnosticConnectedOnly => 'Verbonden';

  @override
  String get relayDiagnosticNotConnected => 'Niet verbonden';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Geen relays geconfigureerd';

  @override
  String get relayDiagnosticFailed => 'Mislukt';

  @override
  String get notificationSettingsTitle => 'Meldingen';

  @override
  String get notificationSettingsResetTooltip => 'Terug naar standaard';

  @override
  String get notificationSettingsTypes => 'Soorten meldingen';

  @override
  String get notificationSettingsLikes => 'Likes';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Wanneer iemand je video\'s liket';

  @override
  String get notificationSettingsComments => 'Reacties';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Wanneer iemand op je video\'s reageert';

  @override
  String get notificationSettingsFollows => 'Volgers';

  @override
  String get notificationSettingsFollowsSubtitle => 'Wanneer iemand je volgt';

  @override
  String get notificationSettingsMentions => 'Vermeldingen';

  @override
  String get notificationSettingsMentionsSubtitle => 'Wanneer je wordt genoemd';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Wanneer iemand je video\'s repost';

  @override
  String get notificationSettingsNewPosts => 'Nieuwe vines';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Wanneer iemand die je volgt post';

  @override
  String get notificationSettingsActions => 'Acties';

  @override
  String get notificationSettingsMarkAllAsRead => 'Alles als gelezen markeren';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Markeer alle meldingen als gelezen';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Alle meldingen als gelezen gemarkeerd';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Alles als gelezen markeren mislukt';

  @override
  String get notificationSettingsResetToDefaults =>
      'Instellingen teruggezet naar standaard';

  @override
  String get notificationSettingsAbout => 'Over meldingen';

  @override
  String get notificationSettingsAboutDescription =>
      'Meldingen werken via het Nostr-protocol. Realtime updates hangen af van je verbinding met Nostr-relays. Sommige meldingen kunnen vertraging hebben.';

  @override
  String get safetySettingsWhatYouSee => 'WAT JIJ ZIET';

  @override
  String get safetySettingsWhatYouPublish => 'WAT JIJ PUBLICEERT';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Alleen op Divine gehoste video\'s tonen';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Verberg video\'s die bij andere mediahosts staan';

  @override
  String get safetySettingsModeration => 'MODERATIE';

  @override
  String get safetySettingsBlockedUsers => 'GEBLOKKEERDE GEBRUIKERS';

  @override
  String get safetySettingsAgeVerification => 'LEEFTIJDSVERIFICATIE';

  @override
  String get safetySettingsAgeConfirmation =>
      'Ik bevestig dat ik 18 jaar of ouder ben';

  @override
  String get safetySettingsAgeRequired =>
      'Vereist om inhoud voor volwassenen te bekijken';

  @override
  String get safetySettingsAgeLockedForMinor => 'Vergrendeld voor je account';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Officiële moderatieservice (standaard aan)';

  @override
  String get safetySettingsPeopleIFollow => 'Mensen die ik volg';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Abonneer je op labels van mensen die je volgt';

  @override
  String get safetySettingsAddCustomLabeler => 'Eigen labeler toevoegen';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Voer npub in...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Eigen labeler toevoegen';

  @override
  String get safetySettingsRemoveLabeler => 'Labeler verwijderen';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Voer npub-adres in';

  @override
  String get safetySettingsNoBlockedUsers => 'Geen geblokkeerde gebruikers';

  @override
  String get safetySettingsUnblock => 'Deblokkeren';

  @override
  String get safetySettingsUserUnblocked => 'Gebruiker gedeblokkeerd';

  @override
  String get safetySettingsCancel => 'Annuleren';

  @override
  String get safetySettingsAdd => 'Toevoegen';

  @override
  String get analyticsTitle => 'Creator-statistieken';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostiek';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Diagnostiek omschakelen';

  @override
  String get analyticsRetry => 'Opnieuw';

  @override
  String get analyticsUnableToLoad => 'Statistieken laden lukt niet.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Log in om creator-statistieken te bekijken.';

  @override
  String get analyticsViewDataUnavailable =>
      'Weergaven zijn nu niet beschikbaar vanuit de relay voor deze posts. Likes/reacties/reposts-metrics kloppen nog wel.';

  @override
  String get analyticsViewDataTitle => 'Weergavedata';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Bijgewerkt $time • Scores gebruiken likes, reacties, reposts en views/loops van Funnelcake als beschikbaar.';
  }

  @override
  String get analyticsVideos => 'Video\'s';

  @override
  String get analyticsViews => 'Weergaven';

  @override
  String get analyticsInteractions => 'Interacties';

  @override
  String get analyticsEngagement => 'Betrokkenheid';

  @override
  String get analyticsFollowers => 'Volgers';

  @override
  String get analyticsAvgPerPost => 'Gem./post';

  @override
  String get analyticsInteractionMix => 'Interactiemix';

  @override
  String get analyticsLikes => 'Likes';

  @override
  String get analyticsComments => 'Reacties';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Prestatie-hoogtepunten';

  @override
  String get analyticsMostViewed => 'Meest bekeken';

  @override
  String get analyticsMostDiscussed => 'Meest besproken';

  @override
  String get analyticsMostReposted => 'Meest gerepost';

  @override
  String get analyticsNoVideosYet => 'Nog geen video\'s';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Weergavedata niet beschikbaar';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count weergaven';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count reacties';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Top-inhoud';

  @override
  String get analyticsPublishPrompt =>
      'Publiceer een paar video\'s om de ranglijst te zien.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Rechts het % = betrokkenheidsratio (interacties gedeeld door weergaven).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Betrokkenheidsratio heeft weergavedata nodig; waarden tonen N.v.t. tot er weergaven beschikbaar zijn.';

  @override
  String get analyticsEngagementLabel => 'Betrokkenheid';

  @override
  String get analyticsViewsUnavailable => 'weergaven niet beschikbaar';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interacties';
  }

  @override
  String get analyticsPostAnalytics => 'Post-statistieken';

  @override
  String get analyticsOpenPost => 'Post openen';

  @override
  String get analyticsRecentDailyInteractions =>
      'Recente dagelijkse interacties';

  @override
  String get analyticsNoActivityYet => 'Nog geen activiteit in dit bereik.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interacties = likes + reacties + reposts op postdatum.';

  @override
  String get analyticsDailyBarExplainer =>
      'Balklengte is relatief tot je hoogste dag in dit venster.';

  @override
  String get analyticsAudienceSnapshot => 'Publieksoverzicht';

  @override
  String analyticsFollowersCount(String count) {
    return 'Volgers: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Volgend: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Publieksbron/geo/tijd-overzichten komen zodra Funnelcake publieksanalytics-endpoints toevoegt.';

  @override
  String get analyticsRetention => 'Retentie';

  @override
  String get analyticsRetentionWithViews =>
      'Retentiecurve en kijktijd-overzicht verschijnen zodra per-seconde/per-bucket-retentie binnenkomt van Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retentiedata niet beschikbaar tot weergave- en kijktijd-analytics binnenkomen van Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostiek';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Totaal video\'s: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Met weergaven: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Zonder weergaven: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Gehydrateerd (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Gehydrateerd (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Bronnen: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Fixture-data gebruiken';

  @override
  String get analyticsNa => 'N.v.t.';

  @override
  String get authCreateNewAccount => 'Nieuw Divine-account aanmaken';

  @override
  String get authCreateNewAccountShort => 'Nieuw account maken';

  @override
  String get authSignInDifferentAccount => 'Inloggen met een ander account';

  @override
  String get authUseAnotherAccount => 'Een ander account gebruiken';

  @override
  String authContinueAs(String displayName) {
    return 'Doorgaan als $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Je concepten en clips zijn opgeslagen voor dit account';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Hier inloggen verbergt die concepten en clips';

  @override
  String get authTermsPrefix =>
      'Door hieronder een optie te kiezen bevestig je dat je minstens 16 jaar bent (of de ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine-leeftijdsverificatie';

  @override
  String get authTermsAfterAgeAuthorization =>
      ' hebt afgerond) en ga je akkoord met de ';

  @override
  String get authTermsOfService => 'Servicevoorwaarden';

  @override
  String get authPrivacyPolicy => 'Privacybeleid';

  @override
  String get authTermsAnd => ', en ';

  @override
  String get authSafetyStandards => 'Veiligheidsstandaarden';

  @override
  String get authAmberNotInstalled => 'Amber-app is niet geïnstalleerd';

  @override
  String get authAmberConnectionFailed => 'Verbinden met Amber mislukt';

  @override
  String get authPasswordResetSent =>
      'Als er een account bestaat met dat e-mailadres, is er een link verstuurd om je wachtwoord te resetten.';

  @override
  String get authSignInTitle => 'Inloggen';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Wachtwoord';

  @override
  String get authConfirmPasswordLabel => 'Wachtwoord bevestigen';

  @override
  String get authEmailRequired => 'E-mail is verplicht';

  @override
  String get authEmailInvalid => 'Voer een geldig e-mailadres in';

  @override
  String get authPasswordRequired => 'Wachtwoord is verplicht';

  @override
  String get authConfirmPasswordRequired => 'Bevestig je wachtwoord';

  @override
  String get authPasswordsDoNotMatch => 'Wachtwoorden komen niet overeen';

  @override
  String get authForgotPassword => 'Wachtwoord vergeten?';

  @override
  String get authImportNostrKey => 'Nostr-sleutel importeren';

  @override
  String get authConnectSignerApp => 'Verbinden met een signer-app';

  @override
  String get authSignInWithAmber => 'Inloggen met Amber';

  @override
  String get authSignInWithBrowserExtension => 'Aanmelden met browserextensie';

  @override
  String get authNip07ConnectionFailed =>
      'Kan geen verbinding maken met je browserextensie.';

  @override
  String get authNip07ExtensionNotFound =>
      'Geen browserextensie gevonden. Installeer Alby, nos2x of een andere NIP-07-compatibele extensie.';

  @override
  String get authSignInOptionsTitle => 'Inlogopties';

  @override
  String get authInfoEmailPasswordTitle => 'E-mail & wachtwoord';

  @override
  String get authInfoEmailPasswordDescription =>
      'Log in met je Divine-account. Als je geregistreerd bent met e-mail en wachtwoord, gebruik die dan hier.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Heb je al een Nostr-identiteit? Importeer je nsec privésleutel uit een andere client.';

  @override
  String get authInfoSignerAppTitle => 'Signer-app';

  @override
  String get authInfoSignerAppDescription =>
      'Verbind met een NIP-46-compatibele remote signer zoals nsecBunker voor extra sleutelbeveiliging.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Gebruik de Amber signer-app op Android om je Nostr-sleutels veilig te beheren.';

  @override
  String get authInfoBrowserExtensionTitle => 'Browserextensie';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Meld je aan met een NIP-07-browserextensie zoals Alby of nos2x. Je sleutels blijven in de extensie — Divine ziet ze nooit.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Verkeerd e-mailadres of wachtwoord. Probeer het opnieuw.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Verifieer je e-mail voordat je inlogt — check je inbox voor de link.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Dat lijkt geen geldig e-mailadres.';

  @override
  String get authSignInErrorNetwork =>
      'Kan de server niet bereiken. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get authSignInErrorGeneric => 'Er ging iets mis. Probeer het opnieuw.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Weet je niet meer hoe je de vorige keer inlogde? ';

  @override
  String get authSignInOptionsHintCta => 'Bekijk alle inlogopties';

  @override
  String get authCreateAccountTitle => 'Account aanmaken';

  @override
  String get authBackToInviteCode => 'Terug naar invite-code';

  @override
  String get authUseDivineNoBackup => 'Divine gebruiken zonder back-up';

  @override
  String get authSkipConfirmTitle => 'Nog één ding...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Je zit erin! We maken een veilige sleutel die je Divine-account aandrijft.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Zonder e-mail is je sleutel de enige manier waarop Divine weet dat dit account van jou is.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Je kunt je sleutel in de app openen, maar als je niet technisch bent raden we aan nu een e-mail en wachtwoord toe te voegen. Het maakt inloggen en je account herstellen makkelijker als je dit apparaat kwijtraakt of reset.';

  @override
  String get authAddEmailPassword => 'E-mail & wachtwoord toevoegen';

  @override
  String get authUseThisDeviceOnly => 'Alleen dit apparaat gebruiken';

  @override
  String get authCompleteRegistration => 'Maak je registratie af';

  @override
  String get authVerifying => 'Verifiëren...';

  @override
  String get authVerificationLinkSent =>
      'We hebben een verificatielink gestuurd naar:';

  @override
  String get authClickVerificationLink =>
      'Klik op de link in je e-mail om\nje registratie af te ronden.';

  @override
  String get authPleaseWaitVerifying =>
      'Even geduld terwijl we je e-mail verifiëren...';

  @override
  String get authWaitingForVerification => 'Wachten op verificatie';

  @override
  String get authOpenEmailApp => 'E-mail-app openen';

  @override
  String get authVerificationPinPrompt =>
      'Of voer de 6-cijferige code uit je e-mail in';

  @override
  String get authVerificationPinFieldLabel => '6-cijferige code';

  @override
  String get authVerificationPinSubmit => 'Code verifiëren';

  @override
  String get authVerificationResendPrompt => 'Niets ontvangen?';

  @override
  String get authVerificationResend => 'Opnieuw versturen';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Opnieuw versturen over $time';
  }

  @override
  String get authVerificationResendFailed =>
      'We konden de e-mail niet opnieuw versturen. Probeer het opnieuw.';

  @override
  String get authVerificationResendExpired =>
      'Die aanmelding is verlopen. Begin opnieuw voor een verse code.';

  @override
  String get authVerificationResendUnavailable =>
      'Opnieuw versturen kan nu niet. Gebruik de 6-cijferige code uit de e-mail die we al hebben gestuurd.';

  @override
  String get authVerificationPollingStopped =>
      'We controleren niet meer voor je. Vul de 6-cijferige code uit je e-mail in om het inloggen af te ronden.';

  @override
  String get authWelcomeToDivine => 'Welkom bij Divine!';

  @override
  String get authEmailVerified => 'Je e-mailadres is geverifieerd.';

  @override
  String get authSigningYouIn => 'Je wordt ingelogd';

  @override
  String get authErrorTitle => 'Oei.';

  @override
  String get authVerificationFailed =>
      'We konden je e-mail niet verifiëren.\nProbeer het opnieuw.';

  @override
  String get authStartOver => 'Opnieuw beginnen';

  @override
  String get authEmailVerifiedLogin =>
      'E-mail geverifieerd! Log in om door te gaan.';

  @override
  String get authVerificationLinkExpired =>
      'Deze verificatielink is niet meer geldig.';

  @override
  String get authVerificationConnectionError =>
      'E-mail verifiëren lukt niet. Check je verbinding en probeer opnieuw.';

  @override
  String get authWaitlistConfirmTitle => 'Je staat erop!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'We delen updates via $email.\nZodra er meer invite-codes beschikbaar zijn, sturen we die naar je toe.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Opnieuw proberen';

  @override
  String get authContactSupport => 'Contact met support';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email openen lukt niet';
  }

  @override
  String get authAddInviteCode => 'Voeg je invite-code toe';

  @override
  String get authInviteCodeLabel => 'Invite-code';

  @override
  String get authEnterYourCode => 'Voer je code in';

  @override
  String get authNext => 'Volgende';

  @override
  String get authJoinWaitlist => 'Op de wachtlijst';

  @override
  String get authJoinWaitlistTitle => 'Op de wachtlijst';

  @override
  String get authJoinWaitlistDescription =>
      'Deel je e-mailadres en we sturen updates zodra toegang opengaat.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Stuur me inspiratie van Divine';

  @override
  String get authInviteAccessHelp => 'Hulp bij invite-toegang';

  @override
  String get authGeneratingConnection => 'Verbinding genereren...';

  @override
  String get authConnectedAuthenticating => 'Verbonden! Authenticeren...';

  @override
  String get authConnectionTimedOut => 'Verbinding duurde te lang';

  @override
  String get authApproveConnection =>
      'Zorg dat je de verbinding in je signer-app hebt goedgekeurd.';

  @override
  String get authConnectionCancelled => 'Verbinding geannuleerd';

  @override
  String get authConnectionCancelledMessage => 'De verbinding is geannuleerd.';

  @override
  String get authConnectionFailed => 'Verbinding mislukt';

  @override
  String get authUnknownError => 'Er is een onbekende fout opgetreden.';

  @override
  String get authNostrConnectStartFailed =>
      'De signer-app is niet bereikbaar. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get authNostrConnectInvalidSession =>
      'Deze verbindingslink is niet meer geldig. Start een nieuwe.';

  @override
  String get authNostrConnectSetupFailed =>
      'Bijna gelukt — we konden het inloggen niet afronden. Probeer het opnieuw.';

  @override
  String get authUrlCopied => 'URL gekopieerd naar klembord';

  @override
  String get authConnectToDivine => 'Verbinden met Divine';

  @override
  String get authPasteBunkerUrl => 'Plak bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Ongeldige bunker-URL. Moet beginnen met bunker://';

  @override
  String get authScanSignerApp => 'Scan met je\nsigner-app om te verbinden.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Wachten op verbinding... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'URL kopiëren';

  @override
  String get authShare => 'Delen';

  @override
  String get authAddBunker => 'Bunker toevoegen';

  @override
  String get authCompatibleSignerApps => 'Compatibele signer-apps';

  @override
  String get authFailedToConnect => 'Verbinden mislukt';

  @override
  String get authResetPasswordTitle => 'Wachtwoord resetten';

  @override
  String get authResetPasswordSubtitle =>
      'Voer je nieuwe wachtwoord in. Minimaal 8 tekens.';

  @override
  String get authNewPasswordLabel => 'Nieuw wachtwoord';

  @override
  String get authConfirmNewPasswordLabel => 'Nieuw wachtwoord bevestigen';

  @override
  String get authPasswordTooShort => 'Wachtwoord moet minstens 8 tekens zijn';

  @override
  String get authPasswordResetSuccess => 'Wachtwoord gereset. Log in.';

  @override
  String get authPasswordResetFailed => 'Wachtwoord resetten mislukt';

  @override
  String get authUnexpectedError =>
      'Er is een onverwachte fout opgetreden. Probeer het opnieuw.';

  @override
  String get authUpdatePassword => 'Wachtwoord bijwerken';

  @override
  String get authSecureAccountTitle => 'Account beveiligen';

  @override
  String get authUnableToAccessKeys =>
      'Toegang tot je sleutels mislukt. Probeer het opnieuw.';

  @override
  String get authRegistrationFailed => 'Registratie mislukt';

  @override
  String get authRegistrationComplete =>
      'Registratie voltooid. Check je e-mail.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'Resetmail versturen mislukt.';

  @override
  String get authSending => 'Versturen...';

  @override
  String get authSignInButton => 'Inloggen';

  @override
  String get authVerificationErrorTimeout =>
      'Verificatie duurde te lang. Probeer opnieuw te registreren.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verificatie mislukt — autorisatiecode ontbreekt.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verificatie mislukt. Probeer het opnieuw.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Netwerkfout tijdens inloggen. Probeer het opnieuw.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verificatie mislukt. Probeer opnieuw te registreren.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Inloggen mislukt. Probeer handmatig in te loggen.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Dit e-mailadres is al geregistreerd. Log in plaats daarvan in.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Die code klopt niet. Controleer hem en probeer het opnieuw.';

  @override
  String get authVerificationErrorPinExpired =>
      'Die code is verlopen. Tik op Opnieuw versturen voor een nieuwe.';

  @override
  String get authVerificationErrorPinLocked =>
      'Te veel pogingen. Tik op Opnieuw versturen voor een nieuwe code.';

  @override
  String get authVerificationErrorPinFailed =>
      'We konden die code niet verifiëren. Probeer het opnieuw.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Een code invoeren is nu niet beschikbaar. Tik op de link in je e-mail, of verstuur opnieuw voor een nieuwe.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Voer een uitnodigingscode in zoals ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Deze uitnodigingscode lijkt niet geldig.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Deze uitnodigingscode is al gebruikt of ingetrokken.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'De uitnodigingen van deze creator zijn op';

  @override
  String get authInviteGateErrorUnavailable =>
      'Deze uitnodigingscode is niet beschikbaar. Zet je op de wachtlijst, dan sturen we een uitnodiging zodra er plek is.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'We konden die code niet controleren. Probeer het opnieuw.';

  @override
  String get authInviteGateErrorUnknown =>
      'Er ging iets mis. Probeer je uitnodigingscode opnieuw.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Die invite-code is niet meer beschikbaar. Ga terug naar je invite-code, kom op de wachtlijst of neem contact op met support.';

  @override
  String get authInviteErrorInvalid =>
      'Die invite-code kan nu niet worden gebruikt. Ga terug naar je invite-code, kom op de wachtlijst of neem contact op met support.';

  @override
  String get authInviteErrorTemporary =>
      'We konden je invite nu niet bevestigen. Ga terug naar je invite-code en probeer het opnieuw, of neem contact op met support.';

  @override
  String get authInviteErrorUnknown =>
      'We konden je invite niet activeren. Ga terug naar je invite-code, kom op de wachtlijst of neem contact op met support.';

  @override
  String get shareSheetSave => 'Opslaan';

  @override
  String get shareSheetRemoveFromSaved => 'Verwijder bladwijzer';

  @override
  String get shareSheetSaveToGallery => 'Opslaan in galerij';

  @override
  String get shareSheetSaveWithWatermark => 'Opslaan met watermerk';

  @override
  String get shareSheetSaveVideo => 'Video opslaan';

  @override
  String get shareSheetAddToClips => 'Toevoegen aan clips';

  @override
  String get shareSheetNameClipTitle => 'Geef deze clip een naam';

  @override
  String get shareSheetNameClipSubtitle =>
      'Kies een naam die je herkent in je bibliotheek.';

  @override
  String get shareSheetClipTitleLabel => 'Cliptitel';

  @override
  String get shareSheetSaveClip => 'Clip opslaan';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\" opgeslagen bij clips';
  }

  @override
  String get shareSheetUntitledClip => 'Naamloze clip';

  @override
  String get shareSheetAddToClipsFailed => 'Kon niet toevoegen aan clips';

  @override
  String get shareSheetAddToList => 'Toevoegen aan lijst';

  @override
  String get shareSheetCopy => 'Kopiëren';

  @override
  String get shareSheetShareVia => 'Delen via';

  @override
  String get shareSheetEventJson => 'Event-JSON';

  @override
  String get shareSheetEventId => 'Event-ID';

  @override
  String get shareSheetMoreActions => 'Meer acties';

  @override
  String get shareSheetCrosspost => 'Crossposten';

  @override
  String get crosspostSheetTitle => 'Deze video crossposten';

  @override
  String get crosspostSheetSubtitle =>
      'Stuur \'m naar je gekoppelde platforms. Het posten kan een paar minuten duren.';

  @override
  String get crosspostSubmit => 'Crossposten';

  @override
  String get crosspostStatusQueued => 'In de wachtrij';

  @override
  String get crosspostStatusUploading => 'Uploaden';

  @override
  String get crosspostStatusProcessing => 'Verwerken';

  @override
  String get crosspostStatusPosted => 'Geplaatst';

  @override
  String get crosspostStatusFailed => 'Mislukt';

  @override
  String get crosspostStatusSkipped => 'Overgeslagen';

  @override
  String get crosspostStatusNeedsReauth => 'Opnieuw verbinden nodig';

  @override
  String get crosspostViewPost => 'Post bekijken';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Verbind $platform opnieuw in de crosspost-instellingen om te blijven posten.';
  }

  @override
  String get crosspostReconnect => 'Opnieuw verbinden';

  @override
  String get crosspostErrorNotOwner =>
      'Je kunt alleen je eigen video\'s crossposten.';

  @override
  String get crosspostErrorNotEligible =>
      'Deze video komt niet in aanmerking voor crossposting.';

  @override
  String get crosspostErrorNotConnected => 'Dat platform is niet gekoppeld.';

  @override
  String get crosspostErrorUnauthorized =>
      'Verbind je account opnieuw en probeer het nog eens.';

  @override
  String get crosspostErrorNetwork =>
      'Kan de crossposter niet bereiken. Probeer het zo opnieuw.';

  @override
  String get crosspostFailedGeneric => 'Crossposten mislukt.';

  @override
  String get crosspostStillWorking =>
      'Nog bezig. Je kunt dit sluiten — het posten gaat op de achtergrond door.';

  @override
  String get crosspostDone => 'Klaar';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Opgeslagen in camerarol';

  @override
  String get watermarkDownloadShare => 'Delen';

  @override
  String get watermarkDownloadDone => 'Klaar';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Toegang tot Foto\'s nodig';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Om video\'s op te slaan, geef je in Instellingen toegang tot Foto\'s.';

  @override
  String get watermarkDownloadOpenSettings => 'Instellingen openen';

  @override
  String get watermarkDownloadNotNow => 'Niet nu';

  @override
  String get watermarkDownloadFailed => 'Download mislukt';

  @override
  String get watermarkDownloadDismiss => 'Sluiten';

  @override
  String get watermarkDownloadStageDownloading => 'Video downloaden';

  @override
  String get watermarkDownloadStageWatermarking => 'Watermerk toevoegen';

  @override
  String get watermarkDownloadStageSaving => 'Opslaan in camerarol';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Video ophalen van het netwerk...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Het Divine-watermerk toepassen...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'De video met watermerk in je camerarol opslaan...';

  @override
  String get shareMenuBookmarks => 'Bladwijzers';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count volgsets beschikbaar';
  }

  @override
  String get peopleListsAddToList => 'Toevoegen aan lijst';

  @override
  String get peopleListsSheetTitle => 'Toevoegen aan lijst';

  @override
  String get peopleListsEmptyTitle => 'Nog geen lijsten';

  @override
  String get peopleListsEmptySubtitle =>
      'Maak een lijst om mensen te groeperen.';

  @override
  String get peopleListsCreateList => 'Lijst aanmaken';

  @override
  String get peopleListsNewListTitle => 'Nieuwe lijst';

  @override
  String get peopleListsRouteTitle => 'Personenlijst';

  @override
  String get peopleListsListNameLabel => 'Lijstnaam';

  @override
  String get peopleListsListNameHint => 'Goede vrienden';

  @override
  String get peopleListsCreateButton => 'Aanmaken';

  @override
  String get peopleListsAddPeopleTitle => 'Mensen toevoegen';

  @override
  String get peopleListsAddPeopleTooltip => 'Mensen toevoegen';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Mensen aan lijst toevoegen';

  @override
  String get peopleListsListNotFoundTitle => 'Lijst niet gevonden';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lijst niet gevonden. Mogelijk is deze verwijderd.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Deze lijst is mogelijk verwijderd.';

  @override
  String get peopleListsNoPeopleTitle => 'Geen mensen in deze lijst';

  @override
  String get peopleListsNoPeopleSubtitle => 'Voeg mensen toe om te beginnen';

  @override
  String get peopleListsNoVideosTitle => 'Nog geen video\'s';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Video\'s van lijstleden verschijnen hier';

  @override
  String get peopleListsNoVideosAvailable => 'Geen video\'s beschikbaar';

  @override
  String get peopleListsFailedToLoadVideos => 'Video\'s laden mislukt';

  @override
  String get peopleListsVideoNotAvailable => 'Video niet beschikbaar';

  @override
  String get peopleListsBackToGridTooltip => 'Terug naar raster';

  @override
  String get peopleListsErrorLoadingVideos => 'Fout bij laden van video\'s';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Geen mensen beschikbaar om toe te voegen.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Toevoegen aan $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Mensen zoeken';

  @override
  String get peopleListsAddPeopleError =>
      'Kon mensen niet laden. Probeer het opnieuw.';

  @override
  String get peopleListsAddPeopleRetry => 'Opnieuw proberen';

  @override
  String get peopleListsAddButton => 'Toevoegen';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count toevoegen';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count lijsten',
      one: 'In 1 lijst',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$name verwijderen?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Ze worden uit deze lijst verwijderd.';

  @override
  String get peopleListsRemove => 'Verwijderen';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name verwijderd uit lijst';
  }

  @override
  String get peopleListsUndo => 'Ongedaan maken';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profiel van $name. Lang indrukken om te verwijderen.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Profiel van $name bekijken';
  }

  @override
  String get shareMenuEditVideo => 'Video bewerken';

  @override
  String get shareMenuDeleteVideo => 'Video verwijderen';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video\'s';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Hiermee wordt deze video permanent uit Divine verwijderd. Hij kan nog steeds verschijnen in Nostr-clients van derden die andere relays gebruiken.';

  @override
  String get shareMenuCancel => 'Annuleren';

  @override
  String get shareMenuDelete => 'Verwijderen';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Verwijderen is nog niet klaar. Probeer het zo meteen opnieuw.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Je kunt alleen je eigen video\'s verwijderen.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Log opnieuw in en probeer te verwijderen.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Kon het verwijderverzoek niet ondertekenen. Probeer opnieuw.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'De relay accepteerde dit verwijderverzoek niet. Probeer het zo nog eens.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'De relay was niet bereikbaar. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Verwijderd. Niet elke relay heeft bevestigd, dus hij kan nog in andere apps opduiken.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Kon deze video niet verwijderen. Probeer opnieuw.';

  @override
  String get shareMenuUpdate => 'Bijwerken';

  @override
  String get shareMenuChangeCover => 'Cover wijzigen';

  @override
  String get shareMenuVideoUpdated => 'Video succesvol bijgewerkt';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uitnodigingen voor medewerkers zijn niet verzonden.',
      one: '1 uitnodiging voor medewerker is niet verzonden.',
    );
    return 'Video bijgewerkt, maar $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Log opnieuw in en probeer het dan nog eens.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Deze video heeft geen afspeelbare bron en kan niet worden bewerkt.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'De wijziging kon niet ondertekend worden. Probeer het opnieuw.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'De relay accepteerde de wijziging niet. Probeer het zo nog eens.';

  @override
  String get videoUpdateErrorGeneric =>
      'Deze video kon niet bijgewerkt worden. Probeer het opnieuw.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Video verwijderen?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Video verwijderen…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Video verwijderd.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Video verwijderd. Het kan even duren voordat die overal verdwenen is.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Video verwijderd, maar we konden niet elke kopie weghalen. Neem contact op met support.';

  @override
  String get authSessionExpired => 'Je sessie is verlopen. Log opnieuw in.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Inloggen mislukt. Probeer het opnieuw.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Webauthenticatie wordt niet ondersteund in veilige modus. Gebruik de mobiele app voor veilig sleutelbeheer.';

  @override
  String get webAuthEnterBunkerUri => 'Voer een bunker-URI in';

  @override
  String get webAuthConnectTitle => 'Verbinden met Divine';

  @override
  String get webAuthChooseMethod =>
      'Kies je voorkeursmethode voor Nostr-authenticatie';

  @override
  String get webAuthBrowserExtension => 'Browserextensie';

  @override
  String get webAuthRecommended => 'AANBEVOLEN';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Verbinden met een remote signer';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Plakken uit klembord';

  @override
  String get webAuthConnectToBunker => 'Verbinden met Bunker';

  @override
  String get webAuthNewToNostr => 'Nieuw op Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Installeer een browserextensie zoals Alby of nos2x voor de makkelijkste ervaring, of gebruik nsec bunker voor veilig remote signen.';

  @override
  String get soundsTitle => 'Geluiden';

  @override
  String get soundsSearchHint => 'Zoek geluiden...';

  @override
  String get soundsSearchResults => 'Zoekresultaten';

  @override
  String get soundsNoSoundsFound => 'Geen geluiden gevonden';

  @override
  String get soundsNoSoundsFoundDescription => 'Probeer een andere zoekterm';

  @override
  String get soundsSavedToLibrary => 'Opgeslagen in Sounds';

  @override
  String get soundsAlreadySavedToLibrary => 'Al in Sounds';

  @override
  String get soundsSavedLibraryTitle => 'Mijn sounds';

  @override
  String get soundsSavedEmptyTitle => 'Nog geen opgeslagen sounds';

  @override
  String get soundsSavedEmptyDescription =>
      'Tik op Sound gebruiken in een video om die hier op te slaan.';

  @override
  String get soundsRemoveSavedSound => 'Sound verwijderen';

  @override
  String get savedSoundSaveAction => 'Opslaan';

  @override
  String get savedSoundPausePreviewAction => 'Voorbeeld pauzeren';

  @override
  String get savedSoundResumePreviewAction => 'Voorbeeld hervatten';

  @override
  String get savedSoundDetailsSheetTitle => 'Geluidsdetails';

  @override
  String get savedSoundRemoveConfirmTitle => 'Dit geluid verwijderen?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Het verdwijnt uit je bibliotheek, maar je kunt het opnieuw opslaan vanuit elke video die het gebruikt.';

  @override
  String get soundsRemovedFromLibrary => 'Verwijderd uit Sounds';

  @override
  String get soundsSaveFailed =>
      'Dat geluid kon niet worden opgeslagen. Probeer het opnieuw.';

  @override
  String get soundsRemoveFailed =>
      'Dat geluid kon niet worden verwijderd. Probeer het opnieuw.';

  @override
  String get soundSyncStatusSyncing => 'Je sounds worden gesynchroniseerd…';

  @override
  String get soundSyncStatusSynced => 'Sounds zijn up-to-date';

  @override
  String get soundSyncStatusFailed =>
      'Je sounds konden niet worden gesynchroniseerd. We proberen het opnieuw.';

  @override
  String get soundSyncStatusLocked =>
      'Je gesynchroniseerde bibliotheek kan op dit apparaat niet worden ontgrendeld.';

  @override
  String get profileTitle => 'Profiel';

  @override
  String get profileMoreOptions => 'Meer opties';

  @override
  String profileBlockedUser(String name) {
    return '$name geblokkeerd';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name gedeblokkeerd';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name ontvolgd';
  }

  @override
  String get profileFeedError =>
      'Kan de server niet bereiken. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get profileFeedLoadMoreError =>
      'Meer video\'s konden niet worden geladen. Trek omlaag om te vernieuwen.';

  @override
  String get notificationsTabAll => 'Alles';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Reacties';

  @override
  String get notificationsTabFollows => 'Volgers';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Meldingen laden mislukt';

  @override
  String get notificationsRetry => 'Opnieuw';

  @override
  String get notificationsRefreshError =>
      'Vernieuwen mislukt — toont beschikbare items';

  @override
  String get notificationsUnreadPrefix => 'Ongelezen melding';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ongelezen meldingen',
      one: '1 ongelezen melding',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Profiel van $displayName bekijken';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Profielen bekijken';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Videominiatuur van $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Videominiatuur';

  @override
  String get notificationsInviteSingular =>
      'Je hebt 1 uitnodiging om met een vriend te delen!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Je hebt $count uitnodigingen om met vrienden te delen!';
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
  String get notificationsVideoUnavailable => 'Video niet beschikbaar';

  @override
  String get feedFailedToLoadVideos => 'Video\'s laden mislukt';

  @override
  String get feedRetry => 'Opnieuw';

  @override
  String get feedNoFollowedUsers =>
      'Geen gevolgde gebruikers.\nVolg iemand om hun video\'s hier te zien.';

  @override
  String get feedModeForYou => 'Voor jou';

  @override
  String get feedModeNew => 'Nieuw';

  @override
  String get feedModeFollowing => 'Volgend';

  @override
  String get feedModeClassics => 'Klassiekers';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Feedmodus: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Video-auteur: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar van maker';

  @override
  String get feedForYouEmpty =>
      'Je Voor jou-feed is leeg.\nVerken video\'s en volg makers om hem vorm te geven.';

  @override
  String get feedFollowingEmpty =>
      'Nog geen video\'s van mensen die je volgt.\nVind makers die je leuk vindt en volg ze.';

  @override
  String get feedLatestEmpty =>
      'Nog geen nieuwe video\'s.\nKom binnenkort terug.';

  @override
  String get feedClassicEmpty => 'Nog geen klassiekers.\nKom binnenkort terug.';

  @override
  String get feedExploreVideos => 'Video\'s verkennen';

  @override
  String get feedLoadingMore => 'Meer video\'s laden…';

  @override
  String get feedRefreshed => 'Feed vernieuwd';

  @override
  String get uploadUploadingVideo => 'Video uploaden';

  @override
  String get postPublishConfirmationTitle => 'Gepubliceerd op je profiel';

  @override
  String get postPublishConfirmationView => 'Bekijken';

  @override
  String get postPublishConfirmationShare => 'Delen';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Miniatuur van de video die je zojuist hebt gepubliceerd';

  @override
  String get userSearchNoResults => 'Geen gebruikers gevonden';

  @override
  String get userPickerFilterByNameHint => 'Filteren op naam...';

  @override
  String get userPickerSearchByNameHint => 'Zoeken op naam...';

  @override
  String get userPickerClearSearchSemantics => 'Zoekopdracht wissen';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name al toegevoegd';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Selecteer $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return '$name verwijderen';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Je crew is daarbuiten';

  @override
  String get userPickerEmptyFollowListBody =>
      'Volg mensen met wie je klikt. Als ze je terugvolgen, kunnen jullie samenwerken.';

  @override
  String get userPickerGoBack => 'Ga terug';

  @override
  String get userPickerTypeNameToSearch => 'Typ een naam om te zoeken';

  @override
  String get userPickerUnavailable =>
      'Zoeken naar gebruikers is niet beschikbaar. Probeer het later opnieuw.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Zoeken is mislukt. Probeer het opnieuw.';

  @override
  String get forgotPasswordTitle => 'Wachtwoord resetten';

  @override
  String get forgotPasswordDescription =>
      'Voer je e-mailadres in en we sturen je een link om je wachtwoord te resetten.';

  @override
  String get forgotPasswordEmailLabel => 'E-mailadres';

  @override
  String get forgotPasswordCancel => 'Annuleren';

  @override
  String get forgotPasswordSendLink => 'Resetlink e-mailen';

  @override
  String get ageVerificationContentWarning => 'Inhoudswaarschuwing';

  @override
  String get ageVerificationTitle => 'Leeftijdsverificatie';

  @override
  String get ageVerificationAdultDescription =>
      'Deze inhoud is gemarkeerd als mogelijk materiaal voor volwassenen. Je moet 18 of ouder zijn om het te bekijken.';

  @override
  String get ageVerificationCreationDescription =>
      'Om de camera te gebruiken en inhoud te maken moet je minstens 16 zijn.';

  @override
  String get ageVerificationAdultQuestion => 'Ben je 18 jaar of ouder?';

  @override
  String get ageVerificationCreationQuestion => 'Ben je 16 jaar of ouder?';

  @override
  String get ageVerificationNo => 'Nee';

  @override
  String get ageVerificationYes => 'Ja';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Ontdekken';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profiel';

  @override
  String get navMyProfile => 'Mijn profiel';

  @override
  String get navNotifications => 'Meldingen';

  @override
  String get navOpenCamera => 'Camera openen';

  @override
  String get navExploreClassics => 'Klassiekers';

  @override
  String get navExploreNewVideos => 'Nieuwe video\'s';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'Voor jou';

  @override
  String get navExploreLists => 'Lijsten';

  @override
  String get routeErrorTitle => 'Fout';

  @override
  String get routeInvalidHashtag => 'Ongeldige hashtag';

  @override
  String get routeInvalidConversationId => 'Ongeldige gesprek-ID';

  @override
  String get routeInvalidRequestId => 'Ongeldige verzoek-ID';

  @override
  String get routeInvalidListId => 'Ongeldige lijst-ID';

  @override
  String get routeInvalidUserId => 'Ongeldige gebruikers-ID';

  @override
  String get routeInvalidVideoId => 'Ongeldige video-ID';

  @override
  String get routeInvalidSoundId => 'Ongeldige geluid-ID';

  @override
  String get routeInvalidCategory => 'Ongeldige categorie';

  @override
  String get routeNoVideosToDisplay => 'Geen video\'s om weer te geven';

  @override
  String get routeGoHome => 'Naar home';

  @override
  String get routeInvalidProfileId => 'Ongeldige profiel-ID';

  @override
  String get routeUnknownPath => 'Die pagina zit niet in de app.';

  @override
  String get routeDefaultListName => 'Lijst';

  @override
  String get supportTitle => 'Supportcentrum';

  @override
  String get supportContactSupport => 'Contact met support';

  @override
  String get supportContactSupportSubtitle =>
      'Start een gesprek of bekijk eerdere berichten';

  @override
  String get supportReportBug => 'Bug melden';

  @override
  String get supportReportBugSubtitle => 'Technische problemen met de app';

  @override
  String get supportRequestFeature => 'Functie aanvragen';

  @override
  String get supportRequestFeatureSubtitle =>
      'Stel een verbetering of nieuwe functie voor';

  @override
  String get supportSaveLogs => 'Logs opslaan';

  @override
  String get supportSaveLogsSubtitle =>
      'Exporteer logs naar bestand om handmatig te versturen';

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
  String get supportFaq => 'Veelgestelde vragen';

  @override
  String get supportFaqSubtitle => 'Veelgestelde vragen & antwoorden';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Ouders en tieners helpen gezonde online gewoonten op te bouwen';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'Hoe we accounts per leeftijd behandelen';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Leer over verificatie en authenticiteit';

  @override
  String get supportLoginRequired =>
      'Log in om contact op te nemen met support';

  @override
  String get supportExportingLogs => 'Logs exporteren...';

  @override
  String get supportExportLogsFailed => 'Logs exporteren mislukt';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Logs opgeslagen in $path';
  }

  @override
  String get supportRevealLogsAction => 'Tonen in map';

  @override
  String get supportChatNotAvailable => 'Supportchat niet beschikbaar';

  @override
  String get supportCouldNotOpenMessages => 'Supportberichten openen mislukt';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName openen mislukt';
  }

  @override
  String get reportWhyReporting => 'Waarom meld je deze inhoud?';

  @override
  String get reportPolicyNotice =>
      'Divine handelt binnen 24 uur op meldingen van inhoud door de inhoud te verwijderen en de gebruiker die de schendende inhoud plaatste eruit te zetten.';

  @override
  String get reportBlockUser => 'Deze gebruiker blokkeren';

  @override
  String get reportCancel => 'Annuleren';

  @override
  String get reportSubmit => 'Melden';

  @override
  String get reportSelectReason =>
      'Selecteer een reden om deze inhoud te melden';

  @override
  String get reportOtherRequiresDetails =>
      'Beschrijf het probleem als je Overig kiest';

  @override
  String get reportDetailsRequired => 'Beschrijf het probleem';

  @override
  String get reportDetailsTextOnly =>
      'Alleen tekst — je kunt hier geen foto\'s of GIF\'s toevoegen.';

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
  String get reportReasonSpam => 'Spam of ongewenste inhoud';

  @override
  String get reportReasonSpamSubtitle => 'Ongewenste of repetitieve content';

  @override
  String get reportReasonHarassment => 'Intimidatie, pesten of bedreigingen';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Schadelijke en ongewenste reacties of vermeldingen';

  @override
  String get reportReasonViolence => 'Gewelddadige of extremistische inhoud';

  @override
  String get reportReasonViolenceSubtitle =>
      'Gewelddadige, extremistische of schadelijke content';

  @override
  String get reportReasonSexualContent =>
      'Seksuele inhoud of inhoud voor volwassenen';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Naaktheid, porno of expliciete content';

  @override
  String get reportReasonCopyright => 'Auteursrechtschending';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Ongeoorloofd gebruik van intellectueel eigendom';

  @override
  String get reportReasonFalseInfo => 'Valse informatie';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Misleidende of onware beweringen';

  @override
  String get reportReasonChildSafety => 'Schending van kinderveiligheid';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Algemene zorgen over de veiligheid van minderjarigen';

  @override
  String get reportReasonCsam => 'Seksueel kindermisbruik';

  @override
  String get reportReasonCsamSubtitle =>
      'Content die seksueel misbruik van minderjarigen toont';

  @override
  String get reportReasonUnderageUser => 'Gebruiker lijkt jonger dan 16';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Accounthouder lijkt minderjarig';

  @override
  String get reportReasonAiGenerated => 'AI-gegenereerde inhoud';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Vermoedelijk door AI gegenereerde content';

  @override
  String get reportReasonOther => 'Andere beleidsschending';

  @override
  String get reportReasonOtherSubtitle =>
      'Overtredingen die hierboven niet staan';

  @override
  String get reportFailed => 'Inhoud melden mislukt. Probeer het opnieuw.';

  @override
  String get reportNotSent =>
      'Kan je melding niet versturen. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get reportReceivedTitle => 'Melding ontvangen';

  @override
  String get reportReceivedThankYou =>
      'Bedankt dat je helpt Divine veilig te houden.';

  @override
  String get reportReceivedReviewNotice =>
      'Ons team bekijkt je melding en onderneemt passende actie. Je kunt updates ontvangen via directe berichten.';

  @override
  String get reportModerationDmDelayed =>
      'We konden het moderatieteam zojuist niet rechtstreeks bereiken, maar je melding is ontvangen en wordt bekeken.';

  @override
  String get reportContactModeration => 'Stuur het moderatieteam een bericht';

  @override
  String get reportLearnMoreAt => 'Meer info op';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Sluiten';

  @override
  String get listAddToList => 'Toevoegen aan lijst';

  @override
  String listVideoCount(int count) {
    return '$count video\'s';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personen',
      one: '1 persoon',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Door ';

  @override
  String get listNewList => 'Nieuwe lijst';

  @override
  String get listDone => 'Klaar';

  @override
  String get listErrorLoading => 'Fout bij laden van lijsten';

  @override
  String listRemovedFrom(String name) {
    return 'Verwijderd uit $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Toegevoegd aan $name';
  }

  @override
  String get listCreateNewList => 'Nieuwe lijst maken';

  @override
  String get listNewPeopleList => 'Nieuwe personenlijst';

  @override
  String get listCollaboratorsNone => 'Geen';

  @override
  String get listAddCollaboratorTitle => 'Medewerker toevoegen';

  @override
  String get listCollaboratorSearchHint => 'Zoek in Divine...';

  @override
  String get listNameLabel => 'Lijstnaam';

  @override
  String get listDescriptionLabel => 'Beschrijving (optioneel)';

  @override
  String get listPublicList => 'Openbare lijst';

  @override
  String get listPublicListSubtitle =>
      'Anderen kunnen deze lijst volgen en zien';

  @override
  String get listPrivateListSubtitle =>
      'Video\'s blijven privé. Naam, beschrijving, tags en omslag blijven zichtbaar.';

  @override
  String get listVisibilityPublic => 'Openbaar';

  @override
  String get listVisibilityPrivate => 'Privé';

  @override
  String get profileListsEmpty =>
      'Nog geen lijsten. Maak er een voor de loops die je bij elkaar wilt houden.';

  @override
  String get listEditTitle => 'Lijst bewerken';

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
  String get listShareAction => 'Lijst delen';

  @override
  String get listShareFailed =>
      'Kon deze lijst niet delen. Probeer het opnieuw.';

  @override
  String get listSave => 'Opslaan';

  @override
  String get listContinue => 'Doorgaan';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Kon deze lijst niet bijwerken. Probeer het opnieuw.';

  @override
  String get listMakePrivateTitle => 'Deze lijst privé maken?';

  @override
  String get listMakePrivateWarning =>
      'De video\'s worden versleuteld, zodat alleen jij ze kunt zien. Naam, beschrijving, tags en omslag blijven zichtbaar, en al gedeelde kopieën kunnen blijven bestaan.';

  @override
  String get listMakePublicTitle => 'Deze lijst openbaar maken?';

  @override
  String get listMakePublicWarning =>
      'Iedereen met de link kan deze lijst en de video\'s erin zien.';

  @override
  String listShareText(String name, String url) {
    return 'Check $name op Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name op Divine';
  }

  @override
  String get listCancel => 'Annuleren';

  @override
  String get listCreate => 'Maken';

  @override
  String get listCreateFailed => 'Lijst maken mislukt';

  @override
  String get keyManagementTitle => 'Nostr-sleutels';

  @override
  String get keyManagementWhatAreKeys => 'Wat zijn Nostr-sleutels?';

  @override
  String get keyManagementExplanation =>
      'Je Nostr-identiteit is een cryptografisch sleutelpaar:\n\n• Je publieke sleutel (npub) is als je gebruikersnaam — deel hem gerust\n• Je privésleutel (nsec) is als je wachtwoord — houd hem geheim!\n\nJe nsec geeft je toegang tot je account in elke Nostr-app.';

  @override
  String get keyManagementImportTitle => 'Bestaande sleutel importeren';

  @override
  String get keyManagementImportSubtitle =>
      'Heb je al een Nostr-account? Plak je privésleutel (nsec) om er hier toegang toe te krijgen.';

  @override
  String get keyManagementImportButton => 'Sleutel importeren';

  @override
  String get keyManagementImportWarning => 'Dit vervangt je huidige sleutel!';

  @override
  String get keyManagementBackupTitle => 'Maak een back-up van je sleutel';

  @override
  String get keyManagementBackupSubtitle =>
      'Sla je privésleutel (nsec) op om je account in andere Nostr-apps te gebruiken.';

  @override
  String get keyManagementCopyNsec => 'Mijn privésleutel kopiëren (nsec)';

  @override
  String get keyManagementNeverShare => 'Deel je nsec nooit met iemand!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Je sleutel staat bij de inlogservice van Divine, niet op dit apparaat. Bevestig je wachtwoord en we halen hem op.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Je sleutel wordt bewaard door de inlogservice van Divine. Voer het wachtwoord van je account in en we halen hem op.';

  @override
  String get keyManagementKeycastCopyKey => 'Sleutel kopiëren';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Je apparaat blokkeerde het kopiëren, dus je sleutel is niet op het klembord beland.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Dat wachtwoord klopt niet. Probeer het opnieuw.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Te veel pogingen. Sluit dit en begin opnieuw.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Te veel sleutelverzoeken. Wacht een paar minuten en probeer het opnieuw.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Je sessie is verlopen. Meld je opnieuw aan om je sleutel te kopiëren.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Bevestig je e-mailadres voordat je je sleutel kopieert.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine beheert de sleutels van dit account, dus ze kunnen hier niet worden gekopieerd.';

  @override
  String get keyManagementKeycastNoKey =>
      'Voor dit account staat geen sleutel geregistreerd.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'De inlogservice was niet bereikbaar. Probeer het opnieuw.';

  @override
  String get keyManagementRestrictedTitle =>
      'Je sleutels worden beheerd door Divine';

  @override
  String get keyManagementRestrictedBody =>
      'Om je account veilig te houden zijn sleutelback-up en het importeren van een andere sleutel hier niet beschikbaar.';

  @override
  String get keyManagementPasteKey => 'Plak je privésleutel';

  @override
  String get keyManagementInvalidFormat =>
      'Ongeldig sleutelformaat. Moet beginnen met \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Deze sleutel importeren?';

  @override
  String get keyManagementConfirmImportBody =>
      'Dit vervangt je huidige identiteit door de geïmporteerde.\n\nJe huidige sleutel is weg tenzij je eerst een back-up hebt gemaakt.';

  @override
  String get keyManagementImportConfirm => 'Importeren';

  @override
  String get keyManagementImportSuccess => 'Sleutel succesvol geïmporteerd!';

  @override
  String get keyManagementImportFailed =>
      'Sleutel importeren mislukt. Probeer het opnieuw.';

  @override
  String get keyManagementExportSuccess =>
      'Privésleutel gekopieerd naar klembord!\n\nBewaar hem ergens veilig.';

  @override
  String get keyManagementExportFailed =>
      'Sleutel exporteren mislukt. Probeer het opnieuw.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Je publieke sleutel (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Publieke sleutel kopiëren';

  @override
  String get keyManagementPublicKeyCopied => 'Publieke sleutel gekopieerd';

  @override
  String get saveOriginalSavedToCameraRoll => 'Opgeslagen in camerarol';

  @override
  String get saveOriginalShare => 'Delen';

  @override
  String get saveOriginalDone => 'Klaar';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Toegang tot Foto\'s nodig';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Om video\'s op te slaan, geef je in Instellingen toegang tot Foto\'s.';

  @override
  String get saveOriginalOpenSettings => 'Instellingen openen';

  @override
  String get saveOriginalNotNow => 'Niet nu';

  @override
  String get saveOriginalDownloadFailed => 'Download mislukt';

  @override
  String get saveOriginalDismiss => 'Sluiten';

  @override
  String get saveOriginalDownloadingVideo => 'Video downloaden';

  @override
  String get saveOriginalSavingToCameraRoll => 'Opslaan in camerarol';

  @override
  String get saveOriginalFetchingVideo => 'Video ophalen van het netwerk...';

  @override
  String get saveOriginalSavingVideo =>
      'Originele video in je camerarol opslaan...';

  @override
  String get soundTitle => 'Geluid';

  @override
  String get soundOriginalSound => 'Origineel geluid';

  @override
  String get soundVideosUsingThisSound => 'Video\'s die dit geluid gebruiken';

  @override
  String get soundSourceVideo => 'Bronvideo';

  @override
  String get soundNoVideosYet => 'Nog geen video\'s';

  @override
  String get soundBeFirstToUse => 'Wees de eerste die dit geluid gebruikt!';

  @override
  String get soundFailedToLoadVideos => 'Video\'s laden mislukt';

  @override
  String get soundRetry => 'Opnieuw';

  @override
  String get soundVideosUnavailable => 'Video\'s niet beschikbaar';

  @override
  String get soundCouldNotLoadDetails => 'Videodetails laden mislukt';

  @override
  String get soundPreview => 'Voorbeluisteren';

  @override
  String get soundStop => 'Stoppen';

  @override
  String get soundUseSound => 'Geluid gebruiken';

  @override
  String get soundUntitled => 'Geluid zonder titel';

  @override
  String get soundStopPreview => 'Preview stoppen';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Voorbeeld van $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Details bekijken voor $title';
  }

  @override
  String get soundNoVideoCount => 'Nog geen video\'s';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video\'s';
  }

  @override
  String get soundUnableToPreview =>
      'Geluid voorbeluisteren lukt niet — geen audio beschikbaar';

  @override
  String get soundPreviewFailed =>
      'Voorbeluistering afspelen mislukt. Probeer het opnieuw.';

  @override
  String get soundViewSource => 'Bron bekijken';

  @override
  String get soundCloseTooltip => 'Sluiten';

  @override
  String get exploreNotExploreRoute => 'Geen explore-route';

  @override
  String get legalTitle => 'Juridisch';

  @override
  String get legalTermsOfService => 'Servicevoorwaarden';

  @override
  String get legalTermsOfServiceSubtitle => 'Gebruiksvoorwaarden en -condities';

  @override
  String get legalPrivacyPolicy => 'Privacybeleid';

  @override
  String get legalPrivacyPolicySubtitle => 'Hoe we met je data omgaan';

  @override
  String get legalSafetyStandards => 'Veiligheidsstandaarden';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Communityrichtlijnen en veiligheid';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Auteursrecht- en verwijderbeleid';

  @override
  String get legalOpenSourceLicenses => 'Open source-licenties';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Attributies van externe packages';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName openen mislukt';
  }

  @override
  String get categoryAction => 'Actie';

  @override
  String get categoryAdventure => 'Avontuur';

  @override
  String get categoryAnimals => 'Dieren';

  @override
  String get categoryAnimation => 'Animatie';

  @override
  String get categoryArchitecture => 'Architectuur';

  @override
  String get categoryArt => 'Kunst';

  @override
  String get categoryAutomotive => 'Auto\'s';

  @override
  String get categoryAwardShow => 'Awardshow';

  @override
  String get categoryAwards => 'Awards';

  @override
  String get categoryBaseball => 'Honkbal';

  @override
  String get categoryBasketball => 'Basketbal';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryBeverage => 'Drank';

  @override
  String get categoryCars => 'Auto\'s';

  @override
  String get categoryCelebration => 'Feest';

  @override
  String get categoryCelebrities => 'Beroemdheden';

  @override
  String get categoryCelebrity => 'Beroemdheid';

  @override
  String get categoryCityscape => 'Stadsgezicht';

  @override
  String get categoryComedy => 'Comedy';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryCooking => 'Koken';

  @override
  String get categoryCostume => 'Kostuum';

  @override
  String get categoryCrafts => 'Knutselen';

  @override
  String get categoryCrime => 'Misdaad';

  @override
  String get categoryCulture => 'Cultuur';

  @override
  String get categoryDance => 'Dans';

  @override
  String get categoryDiy => 'Zelf doen';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Onderwijs';

  @override
  String get categoryEmotional => 'Emotioneel';

  @override
  String get categoryEmotions => 'Emoties';

  @override
  String get categoryEntertainment => 'Entertainment';

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
  String get categoryFood => 'Eten';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Meubels';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Verzorging';

  @override
  String get categoryGuitar => 'Gitaar';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Gezondheid';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Vakantie';

  @override
  String get categoryHome => 'Thuis';

  @override
  String get categoryHomeImprovement => 'Klussen';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Ziekenhuis';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Interieur';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Kids';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magie';

  @override
  String get categoryMakeup => 'Make-up';

  @override
  String get categoryMedical => 'Medisch';

  @override
  String get categoryMusic => 'Muziek';

  @override
  String get categoryMystery => 'Mysterie';

  @override
  String get categoryNature => 'Natuur';

  @override
  String get categoryNews => 'Nieuws';

  @override
  String get categoryOutdoor => 'Buiten';

  @override
  String get categoryParty => 'Feest';

  @override
  String get categoryPeople => 'Mensen';

  @override
  String get categoryPerformance => 'Optreden';

  @override
  String get categoryPets => 'Huisdieren';

  @override
  String get categoryPolitics => 'Politiek';

  @override
  String get categoryPrank => 'Grap';

  @override
  String get categoryPranks => 'Grappen';

  @override
  String get categoryRealityShow => 'Realityshow';

  @override
  String get categoryRelationship => 'Relatie';

  @override
  String get categoryRelationships => 'Relaties';

  @override
  String get categoryRomance => 'Romantiek';

  @override
  String get categorySchool => 'School';

  @override
  String get categoryScienceFiction => 'Sciencefiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Winkelen';

  @override
  String get categorySkateboarding => 'Skateboarden';

  @override
  String get categorySkincare => 'Huidverzorging';

  @override
  String get categorySoccer => 'Voetbal';

  @override
  String get categorySocialGathering => 'Samenkomst';

  @override
  String get categorySocialMedia => 'Social media';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talkshow';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryTelevision => 'Televisie';

  @override
  String get categoryToys => 'Speelgoed';

  @override
  String get categoryTransportation => 'Vervoer';

  @override
  String get categoryTravel => 'Reizen';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Geweld';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vloggen';

  @override
  String get categoryWrestling => 'Worstelen';

  @override
  String get profileSetupUploadStaged =>
      'Geüpload — tik op Opslaan om toe te passen';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName gerapporteerd';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName geblokkeerd';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName gedeblokkeerd';
  }

  @override
  String get inboxRemovedConversation => 'Gesprek verwijderd';

  @override
  String get inboxRestorePausedTitle => 'Sommige chats zijn nog niet hersteld';

  @override
  String get conversationRestorePausedTitle => 'Deze chat is nog niet hersteld';

  @override
  String get inboxRestoreRetryAction => 'Opnieuw proberen';

  @override
  String get inboxRestoringMessages => 'Je berichten worden hersteld…';

  @override
  String get inboxEmptyTitle => 'Nog geen berichten';

  @override
  String get inboxEmptySubtitle => 'Die +-knop bijt niet.';

  @override
  String get inboxLoadErrorTitle => 'Berichten zijn niet geladen';

  @override
  String get inboxLoadErrorSubtitle =>
      'Check je verbinding en probeer het opnieuw.';

  @override
  String get inboxFilterAll => 'Alles';

  @override
  String get inboxFilterUnread => 'Ongelezen';

  @override
  String get dmBlockedThreadTitle => 'Je hebt dit account geblokkeerd';

  @override
  String get dmBlockedThreadBody =>
      'Berichten blijven hier staan zodat je ze kunt lezen of er een screenshot van kunt maken. Deblokkeer om te reageren.';

  @override
  String get inboxFilterBlocked => 'Geblokkeerd';

  @override
  String get inboxBlockedEmptyTitle => 'Geen geblokkeerde chats';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Accounts die je blokkeert verschijnen hier.';

  @override
  String get inboxBlockedNoMessages => 'Geen berichten';

  @override
  String get inboxUnreadEmptyTitle => 'Je bent helemaal bij';

  @override
  String get inboxUnreadEmptySubtitle =>
      'Geen ongelezen berichten op dit moment.';

  @override
  String get inboxSearchHint => 'Berichten zoeken';

  @override
  String get inboxSupportRowTitle => 'Divine-moderatie';

  @override
  String get inboxSupportRowSubtitle =>
      'Bugs, moderatie, accountzaken — we luisteren.';

  @override
  String get inboxSearchEmptyTitle => 'Geen resultaten';

  @override
  String get inboxSearchEmptySubtitle =>
      'Probeer een andere naam of een ander woord.';

  @override
  String get inboxActionMute => 'Gesprek dempen';

  @override
  String inboxActionReport(String displayName) {
    return '$displayName rapporteren';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayName blokkeren';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayName deblokkeren';
  }

  @override
  String get inboxActionRemove => 'Gesprek verwijderen';

  @override
  String get inboxRemoveConfirmTitle => 'Gesprek verwijderen?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Hiermee verwijder je je gesprek met $displayName uit je inbox. Als deze persoon je weer een bericht stuurt, begint er een nieuw gesprek.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Hiermee verwijder je het groepsgesprek uit je inbox. Als iemand weer een bericht naar de groep stuurt, begint er een nieuw gesprek.';

  @override
  String get inboxRemoveConfirmConfirm => 'Verwijderen';

  @override
  String get inboxConversationMuted => 'Gesprek gedempt';

  @override
  String get inboxConversationUnmuted => 'Gesprek niet meer gedempt';

  @override
  String get inboxCollabInviteCardTitle => 'Uitnodiging om samen te werken';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video zonder titel';

  @override
  String get clickableTextViewVideoLink => 'Video bekijken';

  @override
  String get messageExternalLinkDialogTitle => 'Externe link openen?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Deze link gaat naar een externe site en is mogelijk niet veilig:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Openen';

  @override
  String get inboxCollabInviteCoPostButton => 'Samen plaatsen';

  @override
  String get inboxCollabInviteNotMineButton => 'Niet van mij';

  @override
  String get inboxCollabInvitePreviewTitle =>
      'Uitnodiging om samen te plaatsen';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Uitnodiging om samen te plaatsen van $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Samen plaatsen voegt deze video als samenwerking toe aan je tijdlijn.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Geaccepteerd';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Genegeerd';

  @override
  String get inboxCollabInviteAcceptError =>
      'Accepteren is niet gelukt. Probeer het opnieuw.';

  @override
  String get inboxCollabInviteSentStatus => 'Uitnodiging verzonden';

  @override
  String get inboxConversationCollabInvitePreview =>
      'Uitnodiging om samen te werken';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Je bent uitgenodigd om samen te werken aan $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Je bent uitgenodigd om samen te werken aan een video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samenwerkingsuitnodigingen zijn niet verzonden.',
      one: '1 samenwerkingsuitnodiging is niet verzonden.',
    );
    return 'Video geplaatst, maar $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'We konden niet zien met wie dit gesprek is. Open het opnieuw vanuit je inbox.';

  @override
  String get dmSendBlockedMessage =>
      'Je kunt alleen officiële Divine-accounts een bericht sturen';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Niemand leest dit gesprek. Stuur in plaats daarvan een bericht naar Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage =>
      'Verwijderen voor iedereen is niet gelukt.';

  @override
  String get dmDeleteRefusedDetails =>
      'Sommige mensen kunnen dit bericht mogelijk nog zien.';

  @override
  String get dmRetiredThreadClosedTitle => 'Dit gesprek is gesloten.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Deze melding van Divine Moderation kan niet worden verwijderd.';

  @override
  String get dmRetiredThreadClosedBody =>
      'We hebben Divine Moderation naar een nieuw account verplaatst. Dit account leest niemand meer.';

  @override
  String get dmRetiredThreadOpenSupport =>
      'Bericht sturen naar Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Bericht kon niet worden verzonden';

  @override
  String get dmResendFailedMessage => 'Kon nog steeds niet worden verzonden';

  @override
  String get dmSendFailedSubtitle =>
      'Verstuur het nu opnieuw, of stop met proberen.';

  @override
  String get dmSendFailedRetry => 'Opnieuw';

  @override
  String get dmSendPartialMessage =>
      'Verzonden, maar niet gesynchroniseerd met je andere apparaten';

  @override
  String get dmConversationLoadError => 'Berichten konden niet worden geladen';

  @override
  String get dmMessageInputHint => 'Zeg iets…';

  @override
  String get dmMessageBubbleSentHint => 'Verzonden bericht';

  @override
  String get dmMessageBubbleReceivedHint => 'Ontvangen bericht';

  @override
  String get dmMessageBubbleLongPressHint => 'Berichtacties';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Bericht opnieuw verzenden of verwijderen';

  @override
  String get dmMessageActionCopyText => 'Tekst kopiëren';

  @override
  String get dmMessageActionCopyVideoUrl => 'Video-URL kopiëren';

  @override
  String get dmMessageActionDeleteForEveryone => 'Voor iedereen verwijderen';

  @override
  String get dmMessageActionReport => 'Melden';

  @override
  String get dmMessageActionRetrySend => 'Opnieuw sturen';

  @override
  String get dmMessageActionCancelSend => 'Stoppen met proberen';

  @override
  String get dmReactionAddCustomA11yLabel => 'Eigen emoji-reactie toevoegen';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Bericht aan $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Jezelf beantwoorden…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Reageer op deze reel';

  @override
  String get dmReelReplyViewChat => 'Chat bekijken';

  @override
  String get dmReelReplySentAnnouncement => 'Antwoord verzonden';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Gereageerd met $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Verzenden mislukt';

  @override
  String get dmReelReplyUnverified => 'Verzenden niet bevestigd';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Jouw reactie: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name reageerde met $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Reactie versturen: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reactie mislukt, dubbeltik om opnieuw te proberen';

  @override
  String get dmReactionChipRetryAnnouncement => 'Reactie opnieuw proberen';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Voltooi eerst het verwijderen van je vorige reactie voordat je een andere toevoegt.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reacties';

  @override
  String get dmReactionsViewA11yLabel => 'Bekijk wie heeft gereageerd';

  @override
  String get dmReactionRemoveAction => 'Verwijderen';

  @override
  String get dmReactionRetryAction => 'Opnieuw proberen';

  @override
  String get dmFormatBold => 'Vet';

  @override
  String get dmFormatItalic => 'Cursief';

  @override
  String get dmFormatStrikethrough => 'Doorgestreept';

  @override
  String get dmFormatCode => 'Code';

  @override
  String get dmStatusFailed => 'Versturen mislukt';

  @override
  String get inboxConversationActionsSheetLabel => 'Gespreksacties';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Gesprek met $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Ongelezen, Gesprek met $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anderen',
      one: '$count ander',
    );
    return '$name en $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Gespreksacties tonen';

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
  String get exploreSearchHint => 'Zoeken...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count video\'s';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Abonnement bijwerken mislukt. Probeer het opnieuw.';

  @override
  String get discoverListsTitle => 'Lijsten ontdekken';

  @override
  String get discoverListsFailedToLoad => 'Lijsten laden mislukt';

  @override
  String get discoverListsLoading => 'Publieke lijsten worden ontdekt...';

  @override
  String get discoverListsRelayTimeout =>
      'De relay leverde niet op tijd lijsten. Probeer het opnieuw.';

  @override
  String get discoverListsServiceUnavailable => 'Service niet beschikbaar.';

  @override
  String get discoverListsEmptyTitle => 'Geen publieke lijsten gevonden';

  @override
  String get discoverListsEmptySubtitle =>
      'Kom later terug voor nieuwe lijsten';

  @override
  String get discoverListsByAuthorPrefix => 'door';

  @override
  String get curatedListEmptyTitle => 'Geen video\'s in deze lijst';

  @override
  String get curatedListEmptySubtitle => 'Voeg wat video\'s toe om te beginnen';

  @override
  String get curatedListLoadingVideos => 'Video\'s laden...';

  @override
  String get curatedListFailedToLoad => 'Lijst laden mislukt';

  @override
  String get curatedListVideoNotAvailable => 'Video niet beschikbaar';

  @override
  String get curatedListActionsTooltip => 'Lijstacties';

  @override
  String get curatedListDeleteConfirmTitle => 'Lijst verwijderen?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Hiermee wordt de lijst van de relays verwijderd. Video\'s in de lijst worden niet verwijderd.';

  @override
  String get curatedListDeletedSnack => 'Lijst verwijderd';

  @override
  String get curatedListDeleteFailed => 'Lijst verwijderen mislukt';

  @override
  String get peopleListsActionsTooltip => 'Lijstacties';

  @override
  String get listDeleteAction => 'Lijst verwijderen';

  @override
  String get peopleListsDeleteConfirmTitle => 'Lijst verwijderen?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Hiermee wordt de lijst voor iedereen verwijderd. De mensen erin worden niet ontvolgd.';

  @override
  String get peopleListsDeleteFailed => 'Lijst verwijderen mislukt';

  @override
  String get commonRetry => 'Opnieuw proberen';

  @override
  String get commonSomethingWentWrong => 'Er ging iets mis';

  @override
  String get commonDelete => 'Verwijderen';

  @override
  String get commonCancel => 'Annuleren';

  @override
  String get commonBack => 'Terug';

  @override
  String get commonClose => 'Sluiten';

  @override
  String get commonNotNow => 'Niet nu';

  @override
  String get commonLoading => 'Laden';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Kan de cover niet bijwerken. Probeer het opnieuw.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Omslag bijgewerkt';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Plaatsen zonder echtheidscontrole?';

  @override
  String get videoMetadataC2paMissingBody =>
      'We konden geen content credentials toevoegen, dus deze video wordt niet bevestigd als door mensen gemaakt. Genereer opnieuw om het nog eens te proberen, of plaats hem zo.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Content credentials hebben een internetverbinding nodig.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'De dienst voor contentcredentials gaf geen antwoord. Het ligt niet aan je verbinding.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Opnieuw genereren';

  @override
  String get videoMetadataC2paMissingSkip => 'Overslaan';

  @override
  String get videoMetadataGenerationFailed => 'Genereren mislukt';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Vervaldatum';

  @override
  String get videoMetadataExpirationNotExpire => 'Verloopt niet';

  @override
  String get videoMetadataExpirationOneDay => '1 dag';

  @override
  String get videoMetadataExpirationOneWeek => '1 week';

  @override
  String get videoMetadataExpirationOneMonth => '1 maand';

  @override
  String get videoMetadataExpirationOneYear => '1 jaar';

  @override
  String get videoMetadataExpirationOneDecade => '1 decennium';

  @override
  String get videoMetadataContentWarnings => 'Inhoudswaarschuwingen';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Trending';

  @override
  String get libraryDeleteConfirm => 'Verwijderen';

  @override
  String get libraryWebUnavailableHeadline =>
      'Bibliotheek is beschikbaar in de mobiele app';

  @override
  String get libraryWebUnavailableDescription =>
      'Concepten en clips worden op je apparaat opgeslagen. Open Divine op je telefoon om ze te beheren.';

  @override
  String get libraryTabDrafts => 'Concepten';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'Geselecteerde clips verwijderen';

  @override
  String get libraryCloseSemanticLabel => 'Bibliotheek sluiten';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'Stoppen met clips selecteren';

  @override
  String get librarySelectClipsSemanticLabel => 'Clips selecteren';

  @override
  String get libraryGridSizeLabel => 'Rastergrootte';

  @override
  String get libraryDisplayOptionsLabel => 'Sortering en rastergrootte';

  @override
  String get libraryMoreActionsSemanticLabel => 'Meer bibliotheekacties';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolommen',
      one: '1 kolom',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Selecteren';

  @override
  String get librarySortNewestCreation => 'Nieuwst aangemaakt';

  @override
  String get librarySortOldestCreation => 'Oudst aangemaakt';

  @override
  String get librarySortLongestClip => 'Langste clip';

  @override
  String get librarySortShortestClip => 'Kortste clip';

  @override
  String get librarySortSquareFirst => 'Vierkant eerst';

  @override
  String get librarySortVerticalFirst => 'Verticaal eerst';

  @override
  String get libraryDeleteClipsWarning =>
      'Dit kan niet ongedaan worden gemaakt. De videobestanden worden permanent van je apparaat verwijderd.';

  @override
  String get libraryPreparingVideo => 'Video voorbereiden...';

  @override
  String libraryCreateVideo(int count) {
    return 'Video maken ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return '$_temp0 opgeslagen in $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount opgeslagen, $failureCount mislukt';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Opslaan bij $destination mislukt';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Toestemming geweigerd voor $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips verwijderd',
      one: '1 clip verwijderd',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Ongedaan maken';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Wordt over $daysLeft dagen automatisch verwijderd',
      one: 'Wordt morgen automatisch verwijderd',
      zero: 'Wordt vandaag automatisch verwijderd',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Concepten konden niet worden geladen';

  @override
  String get libraryCouldNotLoadClips => 'Clips konden niet worden geladen';

  @override
  String get libraryOpenErrorDescription =>
      'Er ging iets mis bij het openen van je bibliotheek. Probeer het opnieuw.';

  @override
  String get libraryNoDraftsYetTitle => 'Nog geen concepten';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Video\'\'s die je als concept opslaat, verschijnen hier';

  @override
  String get libraryNoClipsYetTitle => 'Nog geen clips';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Je opgenomen videoclips verschijnen hier';

  @override
  String get libraryDraftDeletedSnackbar => 'Concept verwijderd';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Concept verwijderen mislukt';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Concept gedupliceerd';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Concept dupliceren mislukt';

  @override
  String get libraryDraftInProgressBadge => 'Bezig';

  @override
  String get libraryDraftActionPost => 'Plaatsen';

  @override
  String get libraryDraftActionEdit => 'Bewerken';

  @override
  String get libraryDraftActionDuplicate => 'Dupliceren';

  @override
  String get libraryDraftActionDelete => 'Concept verwijderen';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (kopie $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Concept verwijderen';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Weet je zeker dat je \"$title\" wilt verwijderen?';
  }

  @override
  String get libraryDeleteClipTitle => 'Clip verwijderen';

  @override
  String get libraryDeleteClipMessage =>
      'Weet je zeker dat je deze clip wilt verwijderen?';

  @override
  String libraryClipDuration(String seconds) {
    return '${seconds}s';
  }

  @override
  String get libraryRecordVideo => 'Video opnemen';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Videoclip, $duration seconden';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Gearchiveerd. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Stop-motionclip, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Geselecteerd, nummer $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Geselecteerd';

  @override
  String get videoClipSemanticValueNotSelected => 'Niet geselecteerd';

  @override
  String get videoClipSemanticHintDisabled => 'Uitgeschakeld';

  @override
  String get videoClipSemanticHintSelect =>
      'Tik om te selecteren, houd vast voor voorbeeld';

  @override
  String get videoClipSemanticHintDeselect =>
      'Tik om te deselecteren, houd vast voor voorbeeld';

  @override
  String get routerInvalidCreator => 'Ongeldige maker';

  @override
  String get routerInvalidHashtagRoute => 'Ongeldige hashtagroute';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Video\'s konden niet worden geladen';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Geen video\'s in deze categorie';

  @override
  String get categoryGallerySortOptionsLabel => 'Sorteeropties categorie';

  @override
  String get categoryGallerySortHot => 'Populair';

  @override
  String get categoryGallerySortNew => 'Nieuw';

  @override
  String get categoryGallerySortClassic => 'Klassiek';

  @override
  String get categoryGallerySortForYou => 'Voor jou';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Categorieën konden niet worden geladen';

  @override
  String get categoriesNoCategoriesAvailable => 'Geen categorieën beschikbaar';

  @override
  String get notificationsEmptyTitle => 'Nog geen activiteit';

  @override
  String get notificationsEmptySubtitle =>
      'Wanneer mensen reageren op je inhoud, zie je het hier';

  @override
  String get appsPermissionsTitle => 'Integratierechten';

  @override
  String get appsPermissionsRevoke => 'Intrekken';

  @override
  String get appsPermissionsEmptyTitle => 'Geen opgeslagen integratierechten';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Goedgekeurde integraties verschijnen hier nadat je een toegangsgoedkeuring onthoudt.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName vraagt jouw goedkeuring';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Deze app vraagt toegang via Divine\'s gecontroleerde sandbox.';

  @override
  String get nostrAppPermissionOrigin => 'Oorsprong';

  @override
  String get nostrAppPermissionMethod => 'Methode';

  @override
  String get nostrAppPermissionCapability => 'Bevoegdheid';

  @override
  String get nostrAppPermissionEventKind => 'Event-kind';

  @override
  String get nostrAppPermissionAllow => 'Toestaan';

  @override
  String get appsDetailDefaultTitle => 'Geïntegreerde app';

  @override
  String get appsDetailNotFoundTitle => 'Integratie niet gevonden';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Deze goedgekeurde integratie is niet meer beschikbaar in Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Hoe het werkt';

  @override
  String get appsDetailHowItWorksBody =>
      'Dit is een goedgekeurde externe app die binnen Divine draait. Divine verleent alleen beoordeelde functies aan deze integratie en blokkeert navigatie buiten de goedgekeurde origins.';

  @override
  String get appsDetailAboutTitle => 'Over';

  @override
  String get appsDetailPrimaryOriginTitle => 'Primaire origin';

  @override
  String get appsDetailApprovedOriginsTitle => 'Goedgekeurde origins';

  @override
  String get appsDetailCapabilitiesTitle => 'Beschikbare functies';

  @override
  String get appsDetailAskBeforeTitle => 'Vraag vooraf';

  @override
  String get appsDetailOpenButton => 'Integratie openen';

  @override
  String get appsDetailNoneDeclared => 'Nog niets opgegeven';

  @override
  String get appsDirectoryTitle => 'Geïntegreerde apps';

  @override
  String get appsDirectoryIntroTitle => 'Goedgekeurde externe apps';

  @override
  String get appsDirectoryIntroBody =>
      'Goedgekeurde externe apps die binnen Divine draaien';

  @override
  String get appsDirectoryErrorTitle => 'Geïntegreerde apps laden mislukt';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Trek om de goedgekeurde integraties opnieuw te proberen.';

  @override
  String get appsDirectoryEmptyTitle => 'Nog geen goedgekeurde integraties';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Goedgekeurde externe apps verschijnen hier zodra Divine ze toevoegt.';

  @override
  String get appsDirectoryRefresh => 'Vernieuwen';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Geïntegreerde apps draaien in Divine mobiel';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Goedgekeurde integraties zijn voorlopig alleen op mobiel beschikbaar.';

  @override
  String get appsSandboxUnavailableTitle => 'Integratie niet beschikbaar';

  @override
  String get appsSandboxUnavailableBody =>
      'Open goedgekeurde integraties via het tabblad Geïntegreerde apps, zodat Divine het juiste toegangsbeleid kan toepassen.';

  @override
  String get appsSandboxLoadingTitle => 'Integratie laden';

  @override
  String get appsSandboxLoadingSubtitle =>
      'De goedgekeurde integratie wordt gecontroleerd voor het starten.';

  @override
  String get appsSandboxBlockedTitle => 'Geblokkeerd voor de veiligheid';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Deze integratie probeerde zijn goedgekeurde origin te verlaten.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Link naar post gekopieerd naar klembord';

  @override
  String get shareCopiedEventJson =>
      'Nostr-event-JSON gekopieerd naar klembord';

  @override
  String get shareCopiedEventId => 'Nostr-event-ID gekopieerd naar klembord';

  @override
  String get authHeroTaglineAuthentic => 'Authentieke momenten.';

  @override
  String get authHeroTaglineHuman => 'Menselijke creativiteit.';

  @override
  String get keyImportFailedToImport =>
      'Sleutel importeren of bunker verbinden mislukt';

  @override
  String get keyImportInvalidBunkerUrl => 'Ongeldige bunker-URL';

  @override
  String get keyImportInvalidFormat =>
      'Ongeldig formaat. Gebruik nsec..., hex, ncryptsec1... of bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Ongeldig nsec-formaat. Moet 63 tekens zijn';

  @override
  String get keyImportKeyFieldLabel => 'Privésleutel of bunker-URL';

  @override
  String get keyImportKeyRequired => 'Voer je privésleutel of bunker-URL in';

  @override
  String get keyImportPasswordRequired =>
      'Voer het wachtwoord voor deze versleutelde sleutel in';

  @override
  String get keyImportSecurityWarningBody =>
      'Deel je privésleutel nooit met iemand. Deze sleutel geeft volledige toegang tot je Nostr-identiteit.';

  @override
  String get keyImportSecurityWarningTitle => 'Houd je privésleutel veilig!';

  @override
  String get keyImportSubtitle =>
      'Importeer je bestaande Nostr-identiteit met je privésleutel of een bunker-URL.';

  @override
  String get keyImportTitle => 'Importeer je\nNostr-identiteit';

  @override
  String get commentAuthorYouIndicator => 'Jij';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Profiel van $name bekijken';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Reactie verwijderen';

  @override
  String get commentOptionsEditSemanticLabel => 'Reactie bewerken';

  @override
  String get commentOptionsFlagContentLabel => 'Inhoud markeren';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Deze inhoud markeren';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Selecteer een reden om deze reactie te markeren';

  @override
  String get commentOptionsFlagSubmit => 'Verzenden';

  @override
  String get commentOptionsTitle => 'Opties';

  @override
  String get commentsEmptyClassicVineMessage =>
      'We werken nog aan het importeren van oude reacties uit het archief. Ze zijn nog niet klaar.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Bewerken';

  @override
  String get commentsInputSemanticHint => 'Een reactie toevoegen';

  @override
  String get commentsInputSemanticHintEdit => 'Reactie bewerken';

  @override
  String get commentsInputSemanticHintReply => 'Een antwoord toevoegen';

  @override
  String get commentsInputSemanticLabel => 'Reactieveld';

  @override
  String get commentsInputSemanticLabelEdit => 'Bewerkveld';

  @override
  String get commentsInputSemanticLabelReply => 'Antwoordveld';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Profiel van $displayName bekijken';
  }

  @override
  String get classicsEmptyDescription =>
      'Het Klassiekers-archief wordt geladen';

  @override
  String get classicsEmptyTitle => 'Geen Klassiekers gevonden';

  @override
  String get classicsErrorTitle => 'Klassiekers laden mislukt';

  @override
  String get classicsUnavailableDescription =>
      'Klassiekers zijn alleen beschikbaar wanneer je verbonden bent met Funnelcake-relays.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Schakel in Instellingen over naar een relay met Funnelcake om toegang te krijgen tot het Klassiekers-archief.';

  @override
  String get classicsUnavailableTitle => 'Klassiekers niet beschikbaar';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Wees de eerste die een video met deze hashtag plaatst!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Geen video\'s gevonden voor #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Dit kan even duren';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Video\'s over #$hashtag laden...';
  }

  @override
  String get hashtagInputHint => 'Hashtags toevoegen... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'Kom later terug voor nieuwe inhoud';

  @override
  String get newVideosTabEmptyTitle => 'Geen video\'s bij Nieuwe video\'s';

  @override
  String get popularVideosContextTitle => 'Populaire video\'s';

  @override
  String get popularVideosEmptySubtitle => 'Kom later terug voor nieuwe inhoud';

  @override
  String get popularVideosEmptyTitle => 'Geen video\'s bij Populaire video\'s';

  @override
  String get popularVideosErrorTitle => 'Trending video\'s laden mislukt';

  @override
  String get popularVideosFeedSourceLabel => 'Bron van populaire feed';

  @override
  String get trendingHashtagsLoading => 'Hashtags laden...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Video\'s getagd met $hashtag bekijken';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Video-auteur: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Videobeschrijving: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine\'s visie is om jou echte keuze in algoritmes te geven. In plaats van vast te zitten aan één blackbox-algoritme kun je kiezen uit meerdere aanbevelingsmethoden:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Chronologische tijdlijn van makers die je volgt';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Zo houd jij de controle over je aandacht in plaats van dat je die aan het platform overlaat. Je hoort te weten hoe je feed wordt samengesteld en de macht te hebben om dit te veranderen wanneer je maar wilt.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Door de community gemaakte aangepaste feeds voor onderwerpen als muziek, comedy of kunst';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Gepersonaliseerde \"Voor jou\"-feed';

  @override
  String get forYouAlgorithmChoiceTitle => 'Jouw algoritme, jouw keuze';

  @override
  String get forYouAlgorithmChoiceTrending => 'Trending en populaire inhoud';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Sterk signaal — je was betrokken genoeg om te reageren';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine let op hoe je met inhoud omgaat om te begrijpen waar je van geniet. Telkens wanneer je een video bekijkt, er een reactie op geeft, een opmerking plaatst of hem repost, houdt het systeem dat bij.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Hoe het werkt';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Verschillende acties duiden op verschillende niveaus van interesse:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Als je nog geen kijkgeschiedenis hebt opgebouwd, tonen we een mix van wat momenteel populair is en trending, naast recente uploads. Dit geeft je een mooi startpunt om te ontdekken.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Naarmate je meer kijkt, liket en met inhoud omgaat, worden aanbevelingen geleidelijk persoonlijker. Na verloop van tijd toont je Voor jou-feed video\'s van makers die je op eigen kracht misschien nooit had ontdekt.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Nieuw bij Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'We bouwen een open systeem waarin ontwikkelaars hun eigen algoritmes kunnen bouwen, en jij kiest welke je gebruikt — of je haakt helemaal af.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Opensource en transparant';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Gemiddeld signaal — een snelle manier om waardering te tonen';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reacties';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Sterkste signaal — delen met je volgers is een krachtige aanbeveling';

  @override
  String get forYouAlgorithmSubtitle =>
      'Mogelijk gemaakt door Gorse, een opensource-aanbevelingsengine';

  @override
  String get forYouAlgorithmTitle => 'Het Divine-algoritme';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Zwak signaal — duidt op basisinteresse';

  @override
  String get forYouEmptyDescription =>
      'Bekijk en like een paar video\'s om persoonlijke aanbevelingen te krijgen.';

  @override
  String get forYouEmptyTitle => 'Nog geen aanbevelingen';

  @override
  String get forYouErrorTitle => 'Aanbevelingen laden mislukt';

  @override
  String get forYouUnavailableDescription =>
      'Persoonlijke aanbevelingen vereisen een verbinding met Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Voor jou niet beschikbaar';

  @override
  String get inboxConversationOptionsLabel => 'Opties';

  @override
  String get inboxConversationViewProfileButton => 'Profiel bekijken';

  @override
  String get inboxMessageRequestsEmpty => 'Geen berichtverzoeken';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Berichtverzoeken, $requestCount in behandeling';
  }

  @override
  String get inboxMessageRequestsTitle => 'Berichtverzoeken';

  @override
  String get inboxMessagesTab => 'Berichten';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Berichtverzoek van $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Heeft een berichtverzoek gestuurd';

  @override
  String get inboxRequestsMarkAllRead => 'Alle verzoeken als gelezen markeren';

  @override
  String get inboxRequestsRemoveAll => 'Alle verzoeken verwijderen';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Weigeren en verwijderen';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Verzoek van $displayName geweigerd';
  }

  @override
  String get messageRequestLoadFailed =>
      'Dit berichtverzoek kon niet worden geladen.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count volgers';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count video\'s';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count berichten',
      one: '1 bericht',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Berichten bekijken';

  @override
  String get messageRequestViewProfileButton => 'Profiel bekijken';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName wil je een bericht sturen en heeft $messageText gestuurd.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Je bent van account gewisseld, dus er is niets verwijderd. Open de verwijdering opnieuw voor het account dat je wilt verwijderen.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Typ ter bevestiging:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Typ ter bevestiging je gebruikersnaam:';

  @override
  String get deleteAccountConfirmationHint => 'Typ DELETE';

  @override
  String get deleteAccountConfirmationHintUsername => 'Typ je gebruikersnaam';

  @override
  String get deleteAccountDeleteAllContentButton => 'Alle inhoud verwijderen';

  @override
  String get accountDeletionRecoveryTitle => 'Je account wordt verwijderd';

  @override
  String get accountDeletionRecoveryBody =>
      'We konden je account niet volledig verwijderen. Je gebruikersnaam is voor je gereserveerd en kan nog worden teruggezet.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername =>
      'Mijn gebruikersnaam terugzetten';

  @override
  String get accountDeletionFinishingBody =>
      'Je verwijderverzoek wordt nog verwerkt. Je kunt een ander account gebruiken terwijl wij dit afronden.';

  @override
  String get accountDeletionOtherAccountPending =>
      'De verwijdering van een ander account wordt nog verwerkt op dit apparaat. Wacht tot die is afgerond voordat je dit account verwijdert.';

  @override
  String get accountDeletionCancellingBody =>
      'We annuleren je verwijderverzoek. Controleer het opnieuw voordat je dit scherm verlaat.';

  @override
  String get accountDeletionRecoveryFailed =>
      'We konden je gebruikersnaam nog niet terugzetten. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get accountDeletionUsernameRestored =>
      'Je gebruikersnaam is teruggezet. Je account is niet verwijderd.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'We konden de status van je verwijdering niet controleren. Controleer je verbinding en probeer het opnieuw.';

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
      'Je account kan op dit moment niet worden verwijderd. Er is niets verwijderd.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'We konden je account niet volledig verwijderen. Probeer het opnieuw.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Laatste bevestiging';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Verwijderverzoeken verstuurd, maar je sleutels zijn mogelijk niet volledig van dit apparaat verwijderd. Ga naar Instellingen → Nostr-sleutels → Sleutels verwijderen om het opnieuw te proberen.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Verwijderverzoeken verstuurd en je bent afgemeld, maar sommige lokale gegevens konden niet van dit apparaat worden verwijderd.';

  @override
  String get deleteAccountPreparingDeletion => 'Verwijdering voorbereiden...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total events';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Hiermee wordt de lokale login voor dit account van dit apparaat verwijderd. Je Divine-account of Nostr-identiteit wordt hierdoor niet verwijderd.\n\nJe concepten en clips blijven voor dit account op dit apparaat bewaard. Als dit je laatste lokale account is, keer je terug naar het inlogscherm.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Van apparaat verwijderen';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Dit account van dit apparaat verwijderen?';

  @override
  String get deleteAccountReauthRequired =>
      'Log opnieuw in om je account te verwijderen. Er is nog niets verwijderd.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Verwijderverzoeken voor je posts zijn verstuurd, maar we konden je account niet volledig verwijderen. Probeer het straks opnieuw.';

  @override
  String get deleteAccountSuccess =>
      'Je Divine-account is verwijderd. Voor je Nostr-posts zijn verwijderverzoeken verstuurd, maar sommige relays, clients of caches bewaren mogelijk kopieën.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Accountverwijdering aangevraagd. Voor sommige bestaande posts kon de verwijdering niet afzonderlijk worden bevestigd.';

  @override
  String get deleteAccountWarningBody =>
      'Dit stuurt verwijderverzoeken voor je account en content, verwijdert je Divine-account waar mogelijk en meldt je op dit apparaat af. Sommige relays, clients en zoekindexen kunnen kopieën bewaren. Andere aangemelde apparaten blijven actief totdat je daar de sleutels verwijdert.';

  @override
  String get findPeopleNoContacts =>
      'Geen contacten gevonden.\nBegin mensen te volgen om ze hier te zien.';

  @override
  String get geoBlockedCityLabel => 'Stad';

  @override
  String get geoBlockedCountryLabel => 'Land';

  @override
  String get geoBlockedDefaultReason =>
      'Deze dienst is niet beschikbaar in jouw regio vanwege lokale regelgeving.';

  @override
  String get geoBlockedLegalNotice =>
      'We respecteren je lokale wetten en regels. Deze beperking is gebaseerd op de locatie van je IP-adres.';

  @override
  String get geoBlockedRegionLabel => 'Regio';

  @override
  String get geoBlockedTitle => 'Dienst niet beschikbaar';

  @override
  String get likedVideosEmpty => 'Geen gelikete video\'s';

  @override
  String get likedVideosInvalidRoute => 'Ongeldige route';

  @override
  String get likedVideosTitle => 'Gelikete video\'s';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Upload opnieuw proberen…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Opslaan als concept';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar =>
      'Opgeslagen als concept';

  @override
  String get uploadFailureSheetTitle => 'Upload mislukt';

  @override
  String get uploadFailureSheetTryAgainButton => 'Opnieuw proberen';

  @override
  String get videoEditorAudioImportAudio => 'Audio importeren';

  @override
  String get videoEditorAudioImportFailed => 'Audio importeren mislukt.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn => 'Log in om video\'s te publiceren.';

  @override
  String get publishErrorNoRetry => 'Geen upload om opnieuw te proberen.';

  @override
  String get publishErrorNoInternet =>
      'Geen internetverbinding. Controleer je wifi of mobiele data en probeer het opnieuw.';

  @override
  String get publishErrorServerUnreachable =>
      'Kan de server niet bereiken. Probeer het zo opnieuw.';

  @override
  String get publishErrorTimeout =>
      'De upload duurde te lang. Probeer een sterkere verbinding of een kleinere video.';

  @override
  String get publishErrorTls =>
      'Beveiligde verbinding mislukt. Controleer je netwerk — openbare wifi kan uploads blokkeren.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'De mediaserver ($serverName) is niet beschikbaar. Je kunt een andere kiezen in je instellingen.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Het videobestand is te groot voor de server. Knip het in of verlaag de kwaliteit.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'De mediaserver ($serverName) had een interne fout. Je kunt een andere kiezen in je instellingen.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'De mediaserver ($serverName) is tijdelijk uit de lucht. Probeer het zo opnieuw of kies een andere in je instellingen.';
  }

  @override
  String get publishErrorForbidden =>
      'Je hebt geen toestemming om naar deze server te uploaden.';

  @override
  String get publishErrorFileNotFound =>
      'Het videobestand is niet gevonden. Misschien is het verwijderd. Neem opnieuw op en probeer het nog eens.';

  @override
  String get publishErrorLowStorage =>
      'Niet genoeg opslag op je apparaat. Maak wat ruimte vrij en probeer het opnieuw.';

  @override
  String get publishErrorThumbnailFailed =>
      'De video is geüpload, maar de thumbnail kon niet worden voorbereid. Probeer het opnieuw.';

  @override
  String get publishErrorNostrPublishFailed =>
      'De video is geüpload, maar de post kon niet worden gepubliceerd. Controleer je relay-instellingen en probeer het opnieuw.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'De video is geüpload, maar de sound mag niet hergebruikt worden. Kies een andere sound om te posten.';

  @override
  String get publishErrorInterrupted =>
      'Deze upload is onderbroken. Wil je het opnieuw proberen?';

  @override
  String get publishErrorAccountChanged =>
      'Deze video hoort bij een ander account. Ga terug naar dat account om hem te posten.';

  @override
  String get publishErrorGeneric => 'Er ging iets mis. Probeer het opnieuw.';

  @override
  String get publishErrorRateLimited =>
      'Te veel uploads op dit moment. Wacht even en probeer het opnieuw.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Je uploadsessie is verlopen. Probeer het opnieuw.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine heeft geen toestemming om te uploaden. Controleer de app-rechten in je instellingen en probeer het opnieuw.';

  @override
  String get publishErrorOutOfMemory =>
      'Je apparaat heeft weinig werkgeheugen. Sluit een paar apps en probeer het opnieuw.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'De tekst en stickers van dit concept konden niet worden voorbereid. Open het in de editor en post opnieuw.';

  @override
  String get publishErrorUnknownServer => 'Onbekende server';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Geen resultaten gevonden voor \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Video\'s getagd met $tag bekijken';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Geluid: $soundName van $creatorName. Tik om geluidsdetails te bekijken.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Origineel geluid van $creatorName. Tik om dit geluid te gebruiken.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Geluid: $soundName van $creatorName. Tik om details te bekijken.';
  }

  @override
  String get soundDetailLoadError =>
      'Geluid laden mislukt. Probeer het opnieuw.';

  @override
  String get soundDetailNotFoundMessage =>
      'Dit geluid kon niet worden gevonden';

  @override
  String get soundDetailNotFoundTitle => 'Geluid niet gevonden';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loops';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Audio van deze video is niet afzonderlijk beschikbaar.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Origineel geluid - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Deze persoon plaatste een originele Vine die Divine in het archief vond. Dit is geen verificatiebadge voor het account.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Profielvinkje';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine geeft dit vinkje aan teamaccounts. Dat staat los van NIP-05, geverifieerde accountlinks en de OG Viner-status.';

  @override
  String get unfollowConfirmButton => 'Ontvolgen';

  @override
  String get videoClipSaveFailed => 'Clip opslaan mislukt';

  @override
  String videoClipSaveTo(String destination) {
    return 'Opslaan bij $destination';
  }

  @override
  String get videoClipDelete => 'Clip verwijderen';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Geïnspireerd door $creatorName +$additionalCreatorCount. Tik om hun profiel te bekijken.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Geïnspireerd door $creatorName. Tik om hun profiel te bekijken.';
  }

  @override
  String get bugReportSendReport => 'Rapport verzenden';

  @override
  String get supportSubjectRequiredLabel => 'Onderwerp *';

  @override
  String get supportPublicSubmissionTitle => 'Openbaar GitHub-bericht';

  @override
  String get supportPublicSubmissionMessage =>
      'Alles wat je hier indient, wordt in onze opensource-repository op GitHub geplaatst, zodat ontwikkelaars ermee aan de slag kunnen. Het bericht en het account waarmee je bent ingelogd zijn voor iedereen openbaar zichtbaar.';

  @override
  String get supportRequiredHelper => 'Verplicht';

  @override
  String get supportFieldLimitReached =>
      'Dat is de maximale lengte. Alles daarna is niet toegevoegd.';

  @override
  String get bugReportSubjectHint => 'Korte samenvatting van het probleem';

  @override
  String get bugReportDescriptionRequiredLabel => 'Wat is er gebeurd? *';

  @override
  String get bugReportDescriptionHint =>
      'Beschrijf het probleem dat je tegenkwam';

  @override
  String get bugReportStepsLabel => 'Stappen om te reproduceren';

  @override
  String get bugReportStepsHint => '1. Ga naar...\n2. Tik op...\n3. Zie fout';

  @override
  String get bugReportExpectedBehaviorLabel => 'Verwacht gedrag';

  @override
  String get bugReportExpectedBehaviorHint => 'Wat had er moeten gebeuren?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Apparaatinfo en logs worden automatisch meegestuurd.';

  @override
  String get bugReportSuccessMessage =>
      'Dank je! We hebben je rapport ontvangen en gebruiken het om Divine beter te maken.';

  @override
  String get bugReportAttachImages => 'Afbeeldingen toevoegen';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count van $max afbeeldingen geselecteerd';
  }

  @override
  String get bugReportRemoveImage => 'Afbeelding verwijderen';

  @override
  String get bugReportUploadFailed =>
      'We konden de gekozen afbeelding niet uploaden. Probeer het opnieuw of stuur de melding zonder.';

  @override
  String get bugReportSendFailed =>
      'Bugrapport verzenden mislukt. Probeer het later opnieuw.';

  @override
  String get featureRequestSendRequest => 'Verzoek verzenden';

  @override
  String get featureRequestSubjectHint => 'Korte samenvatting van je idee';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Wat zou je willen? *';

  @override
  String get featureRequestDescriptionHint =>
      'Beschrijf de functie die je wilt';

  @override
  String get featureRequestUsefulnessLabel => 'Hoe zou dit nuttig zijn?';

  @override
  String get featureRequestUsefulnessHint =>
      'Leg uit welk voordeel deze functie zou bieden';

  @override
  String get featureRequestWhenLabel => 'Wanneer zou je dit gebruiken?';

  @override
  String get featureRequestWhenHint =>
      'Beschrijf de situaties waarin dit zou helpen';

  @override
  String get featureRequestSuccessMessage =>
      'Dank je! We hebben je functieverzoek ontvangen en zullen het bekijken.';

  @override
  String get featureRequestSendFailed =>
      'Functieverzoek verzenden mislukt. Probeer het later opnieuw.';

  @override
  String get notificationFollowBack => 'Terugvolgen';

  @override
  String get followingTitle => 'Volgend';

  @override
  String followingTitleForName(String displayName) {
    return 'Volgers van $displayName';
  }

  @override
  String get followingFailedToLoadList => 'Volglijst kon niet worden geladen';

  @override
  String get followingEmptyTitle => 'Volgt nog niemand';

  @override
  String get followersTitle => 'Volgers';

  @override
  String followersTitleForName(String displayName) {
    return 'Volgers van $displayName';
  }

  @override
  String get followersFailedToLoadList => 'Volgerlijst kon niet worden geladen';

  @override
  String get followersEmptyTitle => 'Nog geen volgers';

  @override
  String get followersUpdateFollowFailed =>
      'Volgstatus bijwerken mislukt. Probeer het opnieuw.';

  @override
  String get followersSortSemanticLabel => 'Volgers sorteren';

  @override
  String get followingSortSemanticLabel => 'Gevolgden sorteren';

  @override
  String get followSortTitle => 'Sorteren op';

  @override
  String get followSortNewest => 'Nieuwste eerst';

  @override
  String get followSortOldest => 'Oudste eerst';

  @override
  String get newMessageTitle => 'Nieuw bericht';

  @override
  String get newMessageFindPeople => 'Mensen zoeken';

  @override
  String get newMessageNoContacts =>
      'Geen contacten gevonden.\nVolg mensen om ze hier te zien.';

  @override
  String get newMessageNoUsersFound => 'Geen gebruikers gevonden';

  @override
  String get hashtagSearchTitle => 'Zoek hashtags';

  @override
  String get hashtagSearchSubtitle => 'Ontdek trending onderwerpen en inhoud';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Geen hashtags gevonden voor \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Zoeken mislukt';

  @override
  String get userNotAvailableTitle => 'Account niet beschikbaar';

  @override
  String get userNotAvailableBody =>
      'Dit account is op dit moment niet beschikbaar.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Instellingen opslaan mislukt. Probeer het opnieuw.';

  @override
  String get blossomValidServerUrl =>
      'Voer een geldige server-URL in (bijv. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom-instellingen opgeslagen';

  @override
  String get blossomSaveTooltip => 'Opslaan';

  @override
  String get blossomAboutTitle => 'Over Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom is een gedecentraliseerd protocol voor mediaopslag waarmee je video\'s kunt uploaden naar elke compatibele server. Standaard worden video\'s geüpload naar Divine\'s Blossom-server. Schakel de optie hieronder in om een eigen server te gebruiken.';

  @override
  String get blossomUseCustomServer => 'Eigen Blossom-server gebruiken';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Video\'s worden geüpload naar je eigen Blossom-server';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Je video\'s worden momenteel geüpload naar Divine\'s Blossom-server';

  @override
  String get blossomCustomServerUrl => 'URL eigen Blossom-server';

  @override
  String get blossomCustomServerHelper =>
      'Voer de URL in van je eigen Blossom-server';

  @override
  String get blossomPopularServers => 'Populaire Blossom-servers';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom-server-URL moet https:// gebruiken';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Crosspost-instelling bijwerken mislukt';

  @override
  String get blueskySignInRequired =>
      'Log in om Bluesky-instellingen te beheren';

  @override
  String get blueskyPublishVideos => 'Video\'s publiceren naar Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Je video\'s worden gepubliceerd naar Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Je video\'s worden niet gepubliceerd naar Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Je eerdere video’s worden ook geplaatst';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Als je dit aanzet, stuurt Divine je oudere video’s naar Bluesky, de oudste eerst, zonder de daglimiet te forceren.';

  @override
  String get blueskyHandle => 'Bluesky-handle';

  @override
  String get blueskyDid => 'Bluesky-DID';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Account aangemaakt en klaar';

  @override
  String get blueskyStatusPending => 'Account wordt aangemaakt...';

  @override
  String get blueskyStatusFailed => 'Account aanmaken mislukt';

  @override
  String get blueskyStatusDisabled => 'Account uitgeschakeld';

  @override
  String get blueskyStatusNotLinked => 'Geen Bluesky-account gekoppeld';

  @override
  String get blueskyUsernameRequired =>
      'Stel een divine.video-handle in voordat je op Bluesky publiceert';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Publiceren op Bluesky vraagt om een geclaimde handle gebruikersnaam.divine.video.';

  @override
  String get blueskyUsernameSyncPending =>
      'Je Divine-handle is geclaimd. We koppelen hem aan Bluesky – probeer het zo nog eens.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'We konden je Divine-handle niet controleren. Probeer het opnieuw.';

  @override
  String get blueskySetUpHandle => 'Instellen';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Publiceren op Bluesky is tijdelijk niet beschikbaar. Probeer het opnieuw.';

  @override
  String get invitesTitle => 'Vrienden uitnodigen';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uitnodigingen klaar om te maken',
      one: '1 uitnodiging klaar om te maken',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Maak een code zodra je er een wilt delen.';

  @override
  String get invitesGenerateButtonLabel => 'Uitnodiging maken';

  @override
  String get invitesNoneAvailable =>
      'Op dit moment geen uitnodigingen beschikbaar';

  @override
  String get invitesShareWithPeople => 'Deel Divine met mensen die je kent';

  @override
  String get invitesUsedInvites => 'Gebruikte uitnodigingen';

  @override
  String invitesShareMessage(String code) {
    return 'Doe met me mee op Divine! Gebruik invite-code $code om te beginnen:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Uitnodiging kopiëren';

  @override
  String get invitesCopied => 'Uitnodiging gekopieerd!';

  @override
  String get invitesShareInvite => 'Uitnodiging delen';

  @override
  String get invitesShareSubject => 'Doe met me mee op Divine';

  @override
  String get invitesClaimed => 'Geclaimd';

  @override
  String get invitesCouldNotLoad => 'Uitnodigingen konden niet geladen worden';

  @override
  String get invitesRetry => 'Opnieuw proberen';

  @override
  String get searchSomethingWentWrong => 'Er ging iets mis';

  @override
  String get searchTryAgain => 'Opnieuw proberen';

  @override
  String get searchForLists => 'Zoek naar lijsten';

  @override
  String get searchFindCuratedVideoLists => 'Vind samengestelde videolijsten';

  @override
  String get searchEnterQuery => 'Voer een zoekopdracht in';

  @override
  String get searchDiscoverSomethingInteresting => 'Ontdek iets interessants';

  @override
  String get searchPeopleSectionHeader => 'Mensen';

  @override
  String get searchPeopleLoadingLabel => 'Resultaten voor mensen laden';

  @override
  String get searchTagsSectionHeader => 'Tags';

  @override
  String get searchTagsLoadingLabel => 'Resultaten voor tags laden';

  @override
  String get searchVideosSectionHeader => 'Video\'s';

  @override
  String get searchVideosLoadingLabel => 'Resultaten voor video\'s laden';

  @override
  String get searchVideosSortOptionsLabel => 'Videoresultaten sorteren';

  @override
  String get searchVideosSortTrending => 'Hot';

  @override
  String get searchVideosSortLoops => 'Meeste loops';

  @override
  String get searchVideosSortEngagement => 'Meeste interactie';

  @override
  String get searchVideosSortRecent => 'Recent';

  @override
  String get searchListsSectionHeader => 'Lijsten';

  @override
  String get searchListsLoadingLabel => 'Lijstresultaten laden';

  @override
  String get cameraAgeRestriction =>
      'Je moet 16 jaar of ouder zijn om content te maken';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker-relay moet wss:// gebruiken (ws:// is alleen toegestaan voor localhost)';

  @override
  String get timeNow => 'nu';

  @override
  String timeShortMinutes(int count) {
    return '${count}min';
  }

  @override
  String timeShortHours(int count) {
    return '${count}u';
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
    return '${count}ma';
  }

  @override
  String timeShortYears(int count) {
    return '${count}j';
  }

  @override
  String get timeVerboseNow => 'Nu';

  @override
  String timeAgo(String time) {
    return '$time geleden';
  }

  @override
  String get timeToday => 'Vandaag';

  @override
  String get timeYesterday => 'Gisteren';

  @override
  String get timeJustNow => 'zojuist';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min geleden';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}u geleden';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d geleden';
  }

  @override
  String get draftTimeJustNow => 'Zojuist';

  @override
  String get contentLabelNudity => 'Naaktheid';

  @override
  String get contentLabelSexualContent => 'Seksuele inhoud';

  @override
  String get contentLabelPornography => 'Pornografie';

  @override
  String get contentLabelGraphicMedia => 'Schokkende media';

  @override
  String get contentLabelViolence => 'Geweld';

  @override
  String get contentLabelSelfHarm => 'Zelfbeschadiging/Suïcide';

  @override
  String get contentLabelDrugUse => 'Drugsgebruik';

  @override
  String get contentLabelAlcohol => 'Alcohol';

  @override
  String get contentLabelTobacco => 'Tabak/Roken';

  @override
  String get contentLabelGambling => 'Gokken';

  @override
  String get contentLabelProfanity => 'Grof taalgebruik';

  @override
  String get contentLabelHateSpeech => 'Haatspraak';

  @override
  String get contentLabelHarassment => 'Intimidatie';

  @override
  String get contentLabelFlashingLights => 'Flitsende lichten';

  @override
  String get contentLabelAiGenerated => 'AI-gegenereerd';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Oplichting/Fraude';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Misleidend';

  @override
  String get contentLabelSensitiveContent => 'Gevoelige inhoud';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName vond je video leuk';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName vond je reactie leuk';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName heeft op je video gereageerd';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName volgt je nu';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName heeft je genoemd';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName heeft je video gedeeld';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName heeft een nieuwe vine gepost';
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
      other: '$count van jouw vines',
      one: 'jouw vine',
    );
    return '$actorName heeft $_temp0 toegevoegd aan $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName heeft op je reactie gereageerd';
  }

  @override
  String get notificationAndConnector => 'en';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anderen',
      one: '1 ander',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Je hebt een nieuwe update';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Toetsenbord verbergen';

  @override
  String get commentsErrorLoadFailed => 'Reacties konden niet worden geladen';

  @override
  String get commentsErrorNotAuthenticatedComment => 'Log in om te reageren';

  @override
  String get commentsErrorPostCommentFailed =>
      'Reactie kon niet worden geplaatst';

  @override
  String get commentsErrorPostReplyFailed =>
      'Antwoord kon niet worden geplaatst';

  @override
  String get commentsErrorEditFailed => 'Reactie kon niet worden bewerkt';

  @override
  String get commentsErrorNotAuthenticatedInteract => 'Log in om mee te doen';

  @override
  String get commentsErrorVoteFailed => 'Stemmen op de reactie is mislukt';

  @override
  String get commentsErrorReportFailed => 'Reactie kon niet worden gemeld';

  @override
  String get commentsErrorBlockFailed =>
      'Gebruiker kon niet worden geblokkeerd';

  @override
  String get commentsErrorDeleteFailed => 'Reactie kon niet worden verwijderd';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reacties',
      one: '$count reactie',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Plaatsen…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Je videoreactie wordt geplaatst';

  @override
  String get commentsSortNew => 'Nieuw';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get commentsSortOld => 'Oud';

  @override
  String get commentsSortSemanticLabel => 'Sortering van reacties';

  @override
  String get commentReply => 'Antwoorden';

  @override
  String get commentReplySemanticLabel => 'Op reactie antwoorden';

  @override
  String get commentUpvoteLabel => 'Reactie omhoog stemmen';

  @override
  String get commentRemoveUpvoteLabel => 'Stem omhoog intrekken';

  @override
  String get commentDownvoteLabel => 'Reactie omlaag stemmen';

  @override
  String get commentRemoveDownvoteLabel => 'Stem omlaag intrekken';

  @override
  String get commentsInputHint => 'Reactie toevoegen...';

  @override
  String get commentsInputHintEdit => 'Reactie bewerken...';

  @override
  String get commentsEmptyTitle => 'Nog geen reacties';

  @override
  String get commentsEmptySubtitle => 'Zet jij het feest in gang!';

  @override
  String get draftUntitled => 'Naamloos';

  @override
  String get contentWarningNone => 'Geen';

  @override
  String get textBackgroundNone => 'Geen';

  @override
  String get textBackgroundSolid => 'Dekkend';

  @override
  String get textBackgroundHighlight => 'Markering';

  @override
  String get textBackgroundTransparent => 'Transparant';

  @override
  String get textAlignLeft => 'Links';

  @override
  String get textAlignRight => 'Rechts';

  @override
  String get textAlignCenter => 'Gecentreerd';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Camera wordt nog niet ondersteund op het web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Camerabeelden opnemen en video opnemen zijn nog niet beschikbaar in de webversie.';

  @override
  String get cameraPermissionBackToFeed => 'Terug naar feed';

  @override
  String get cameraCouldNotStart => 'Camera kon niet worden gestart';

  @override
  String get cameraUnsupportedPlatform =>
      'De camera is nog niet beschikbaar op dit platform.\nJe kunt nog steeds video’s bekijken.';

  @override
  String get cameraPermissionErrorTitle => 'Machtigingsfout';

  @override
  String get cameraPermissionErrorDescription =>
      'Er is iets misgegaan bij het controleren van machtigingen.';

  @override
  String get cameraPermissionRetry => 'Opnieuw proberen';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Toegang tot camera en microfoon toestaan';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Hiermee kun je video\'s rechtstreeks in de app opnemen en bewerken, verder niets.';

  @override
  String get cameraPermissionGoToSettings => 'Naar instellingen';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Waarom zes seconden?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Korte clips geven ruimte aan spontaniteit. Het 6-secondenformaat helpt je om authentieke momenten vast te leggen terwijl ze gebeuren.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Begrepen!';

  @override
  String get videoRecorderUploadTitle => 'Waarom geen upload?';

  @override
  String get videoRecorderUploadBody =>
      'Wat je op Divine ziet, is door mensen gemaakt: rauw en op het moment vastgelegd. In tegenstelling tot platforms die zwaar geproduceerde of door AI gegenereerde uploads toestaan, geven we prioriteit aan de authenticiteit van de camera-directe ervaring.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Door creatie binnen de app te houden, kunnen we beter garanderen dat content echt en onbewerkt is. We openen op dit moment geen externe galerij-uploads om die echtheid te beschermen en onze community zoveel mogelijk vrij te houden van synthetische content.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Schakel over naar Capture of Classic om iets echts op te nemen.';

  @override
  String get videoRecorderUploadLearnMore => 'Ontdek hoe verificatie werkt';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'We hebben werk in uitvoering gevonden';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Wil je doorgaan waar je was gebleven?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Ja, doorgaan';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Nee, start een nieuwe video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Je concept kon niet worden hersteld';

  @override
  String get videoRecorderStopRecordingTooltip => 'Opname stoppen';

  @override
  String get videoRecorderStartRecordingTooltip => 'Opname starten';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Bezig met opnemen. Tik ergens om te stoppen';

  @override
  String get videoRecorderTapToStartLabel =>
      'Tik ergens om de opname te starten';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Laatste clip verwijderen';

  @override
  String get videoRecorderSwitchCameraLabel => 'Camera wisselen';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoomen naar $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Raster in-/uitschakelen';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Spookframe in-/uitschakelen';

  @override
  String get videoRecorderGhostFrameEnabled => 'Spookframe ingeschakeld';

  @override
  String get videoRecorderGhostFrameDisabled => 'Spookframe uitgeschakeld';

  @override
  String get videoRecorderClipDeletedMessage =>
      'Clip naar prullenbak verplaatst';

  @override
  String get videoRecorderClipUndoLabel => 'Ongedaan maken';

  @override
  String get libraryTrashEmptyTitle => 'Prullenbak is leeg';

  @override
  String get libraryTrashEmptySubtitle =>
      'Verwijderde clips blijven hier 30 dagen voordat ze definitief worden verwijderd.';

  @override
  String get libraryTrashRestoreLabel => 'Herstellen';

  @override
  String get libraryTrashDeleteNowLabel => 'Nu verwijderen';

  @override
  String get libraryTrashEmptyAllLabel => 'Prullenbak legen';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Clip nu verwijderen?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Hiermee wordt de clip meteen uit de prullenbak verwijderd.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Prullenbak legen?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return 'Hiermee worden $_temp0 meteen definitief uit de prullenbak verwijderd.';
  }

  @override
  String get videoRecorderCloseLabel => 'Videorecorder sluiten';

  @override
  String get videoRecorderContinueToEditorLabel => 'Doorgaan naar video-editor';

  @override
  String get videoRecorderCameraPreviewLabel => 'Cameravoorbeeld';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Camera scherpstellen';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Overschakelen naar de modus $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Voeg audio toe vóór de opname';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Kan de video niet maken. Probeer het opnieuw.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nog $count opnames over',
      one: 'Nog 1 opname over',
      zero: 'Geen opnames meer over',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Flitser in-/uitschakelen';

  @override
  String get videoRecorderCycleTimerLabel => 'Timer wisselen';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Beeldverhouding wisselen';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilisatie';

  @override
  String get videoRecorderStabilizationModeOff => 'Uit';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standaard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinematisch';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematisch uitgebreid';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Voorbeeld-geoptimaliseerd';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Lage latentie';

  @override
  String get videoRecorderStabilizationModeAuto => 'Automatisch';

  @override
  String get videoRecorderFlashValueOff => 'Uit';

  @override
  String get videoRecorderFlashValueOn => 'Aan';

  @override
  String get videoRecorderFlashValueAuto => 'Automatisch';

  @override
  String get videoRecorderTimerValueOff => 'Uit';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 seconden';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 seconden';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Vierkant';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Verticaal';

  @override
  String get videoRecorderCameraValueFront => 'Frontcamera';

  @override
  String get videoRecorderCameraValueBack => 'Achtercamera';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Clipbibliotheek, geen clips';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Clipbibliotheek openen, $clipCount clips',
      one: 'Clipbibliotheek openen, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Stop-motion-bibliotheek openen, $frameCount frames',
      one: 'Stop-motion-bibliotheek openen, 1 frame',
      zero: 'Stop-motion-bibliotheek openen',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Camera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Camera openen';

  @override
  String get videoEditorLibraryLabel => 'Bibliotheek';

  @override
  String get videoEditorTextLabel => 'Tekst';

  @override
  String get videoEditorDrawLabel => 'Tekenen';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorTuneLabel => 'Aanpassen';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Aanpassingseditor openen';

  @override
  String get videoEditorTuneBrightness => 'Helderheid';

  @override
  String get videoEditorTuneContrast => 'Contrast';

  @override
  String get videoEditorTuneSaturation => 'Verzadiging';

  @override
  String get videoEditorTuneExposure => 'Belichting';

  @override
  String get videoEditorTuneHue => 'Tint';

  @override
  String get videoEditorTuneTemperature => 'Temperatuur';

  @override
  String get videoEditorTuneTint => 'Kleurtint';

  @override
  String get videoEditorTuneFade => 'Vervagen';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Toevoegen';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Bibliotheek openen';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Audio-editor openen';

  @override
  String get videoEditorCaptionsLabel => 'Ondertitels';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'Ondertiteleditor openen';

  @override
  String get videoEditorCaptionsBurnInLabel => 'In video branden';

  @override
  String get videoEditorCaptionsPresetCustom => 'Eigen';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Eigen stijl';

  @override
  String get videoEditorCaptionsCustomApply => 'Toepassen';

  @override
  String get videoEditorCaptionsCustomFont => 'Lettertype';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Tekstkleur';

  @override
  String get videoEditorCaptionsCustomBackground => 'Achtergrond';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Achtergrondkleur';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animatie';

  @override
  String get videoEditorCaptionsAnimationNone => 'Geen';

  @override
  String get videoEditorCaptionsAnimationFade => 'Vervagen';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Veer';

  @override
  String get videoEditorCaptionsEditTitle => 'Ondertitels';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'We luisteren…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'We maken ondertitelsuggesties van je audio.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'We hoorden geen spraak. Je kunt de ondertitels alsnog zelf schrijven.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Spraakherkenning is niet beschikbaar op dit apparaat. Je kunt de ondertitels zelf schrijven.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Spraakherkenning is niet toegestaan. Zet het aan in Instellingen of schrijf de ondertitels zelf.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'De transcriptie is deze keer niet gelukt. Je kunt de ondertitels zelf schrijven.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Zelf ondertitels schrijven';

  @override
  String get videoEditorCaptionsAddCue => 'Ondertitel toevoegen';

  @override
  String get videoEditorCaptionsCueTextHint => 'Ondertiteltekst';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel =>
      'Ondertitel verwijderen';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Alle ondertitels verwijderen';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Ondertitels verwijderen?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Alle tekst en timing gaan verloren.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Ondertiteleditor sluiten';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Ondertitels bevestigen';

  @override
  String get videoEditorCaptionsPresetTitle => 'Ondertitelstijl';

  @override
  String get videoEditorCaptionsPresetClassic => 'Klassiek';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Kop';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Typemachine';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marker';

  @override
  String get videoEditorCaptionsPresetScript => 'Kalligrafie';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegant';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bubbel';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Vet';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Dromerig';

  @override
  String get videoEditorCaptionsPresetOcean => 'Oceaan';

  @override
  String get videoEditorCaptionsPresetSunny => 'Zonnig';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Handschrift';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Stempel';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Teksteditor openen';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Tekeneditor openen';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Filtereditor openen';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Stickereditor openen';

  @override
  String get videoEditorSaveDraftTitle => 'Je concept opslaan?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Bewaar je bewerkingen voor later, of verwerp ze en verlaat de editor.';

  @override
  String get videoEditorSaveDraftButton => 'Concept opslaan';

  @override
  String get videoEditorDiscardChangesButton => 'Wijzigingen verwerpen';

  @override
  String get videoEditorKeepEditingButton => 'Doorgaan met bewerken';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Sleepzone om laag te verwijderen';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Loslaten om laag te verwijderen';

  @override
  String get videoEditorDoneLabel => 'Gereed';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Video afspelen of pauzeren';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Ongeldige splitpositie. Beide clips moeten minimaal $minDurationMs ms lang zijn.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Geselecteerde clip opslaan';

  @override
  String get videoEditorSaveClip => 'Clip opslaan';

  @override
  String get videoEditorClipSavedSuccess => 'Clip opgeslagen in bibliotheek';

  @override
  String get videoEditorClipSaveFailed => 'Clip opslaan mislukt';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Kleurkiezer';

  @override
  String get videoEditorUndoSemanticLabel => 'Ongedaan maken';

  @override
  String get videoEditorRedoSemanticLabel => 'Opnieuw';

  @override
  String get videoEditorTextColorSemanticLabel => 'Tekstkleur';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Tekstuitlijning';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Tekstachtergrond';

  @override
  String get videoEditorFontSemanticLabel => 'Lettertype';

  @override
  String get videoEditorNoStickersFound => 'Geen stickers gevonden';

  @override
  String get videoEditorNoStickersAvailable => 'Geen stickers beschikbaar';

  @override
  String get videoEditorFailedLoadStickers => 'Stickers laden mislukt';

  @override
  String get videoEditorVoiceOverLabel => 'Voice-over';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Opname $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Een voice-over opnemen';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Opname starten';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Opname stoppen';

  @override
  String get videoEditorVoiceOverHint =>
      'Tik om op te nemen. Voeg zoveel opnames toe als je wilt.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opnames',
      one: '1 opname',
      zero: 'Nog geen opnames',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Laatste opname verwijderen';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Microfoontoegang vereist';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Geef toegang tot de microfoon om een voice-over op te nemen.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Instellingen openen';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Opname gestart';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Opname opgeslagen';

  @override
  String get videoEditorVoiceOverTooLong => 'Opname is langer dan je video';

  @override
  String get videoEditorPlaySemanticLabel => 'Afspelen';

  @override
  String get videoEditorPauseSemanticLabel => 'Pauzeren';

  @override
  String get videoEditorVolumeSemanticLabel => 'Volume aanpassen';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Schuif om aan te passen';

  @override
  String get videoEditorChromaKeyLabel => 'Greenscreen';

  @override
  String get videoEditorChromaKeyTitle => 'Greenscreen';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Greenscreen voor deze clip instellen';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Greenscreen-wijzigingen verwerpen';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Greenscreen toepassen';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Automatisch detecteren';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Groen';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Blauw';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Achtergrondkleur';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Sterkte';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Hoeveel van de achtergrondkleur verdwijnt';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Rand';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Maakt de uitsnede zachter zodat haar niet rafelt';

  @override
  String get videoEditorChromaKeySpillLabel => 'Kleurzweem';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Haalt de kleur van de achtergrond van je onderwerp af';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Vervangen door';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Niets';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Kleur';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Afbeelding';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Video kan geen transparantie bevatten, dus dit wordt zwart geëxporteerd.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Geen achtergrond gevonden. Die moet tot aan de rand van het beeld komen — kies anders de kleur met de hand.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Kies een clip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Je bibliotheek is leeg. Bewaar eerst een clip en gebruik die dan als achtergrond.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Kon die afbeelding niet laden.';

  @override
  String get videoEditorChromaKeyRemove => 'Greenscreen verwijderen';

  @override
  String get videoEditorChromaKeyFailed =>
      'Kon het greenscreen niet toepassen. Je clip blijft ongewijzigd.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Kon het greenscreen niet verwijderen. Je clip blijft ongewijzigd.';

  @override
  String get videoEditorChromaKeyApplying => 'Greenscreen wordt toegepast…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Dit toestel kan de live voorbeeldweergave niet tonen. Je instellingen gelden nog steeds bij het exporteren.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Verwijderen';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Geselecteerd item verwijderen';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Frames per beeld';

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
    return '$count frames per beeld';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Stop-motion-beeld $position van $total';
  }

  @override
  String get videoEditorEditLabel => 'Bewerken';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Geselecteerd item bewerken';

  @override
  String get videoEditorDuplicateLabel => 'Dupliceren';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Geselecteerd item dupliceren';

  @override
  String get videoEditorCombineLabel => 'Combineren';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Geselecteerde tekeningen samenvoegen tot één laag';

  @override
  String get videoEditorSplitLabel => 'Splitsen';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Geselecteerde clip splitsen';

  @override
  String get videoEditorExtractAudioLabel => 'Audio extraheren';

  @override
  String get videoEditorClipAudioTitle => 'Clip-audio';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Audio uit clip extraheren en origineel dempen';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Kan audio niet extraheren: clip is niet lokaal beschikbaar.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Kon audio niet extraheren. Probeer het opnieuw.';

  @override
  String get videoEditorSpeedLabel => 'Snelheid';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Afspeelsnelheid voor geselecteerd clip instellen';

  @override
  String get videoEditorReverseLabel => 'Omgekeerd';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Omgekeerde weergave voor geselecteerde clip in-/uitschakelen';

  @override
  String get videoEditorReverseProgressLabel =>
      'Een moment, we draaien je clip om';

  @override
  String get videoEditorTransformLabel => 'Transformeren';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Geselecteerde clip bijsnijden, draaien of spiegelen';

  @override
  String get videoEditorTransformProgressLabel =>
      'Een moment, we transformeren je clip';

  @override
  String get videoEditorTransformFailed =>
      'Kan clip niet transformeren. Probeer het opnieuw.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Transformeren niet mogelijk: clip is niet lokaal beschikbaar.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Geselecteerd frame bijsnijden, draaien of spiegelen';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Momentje, we transformeren je frame';

  @override
  String get videoEditorTransformFrameFailed =>
      'Frame kon niet worden getransformeerd. Probeer het opnieuw.';

  @override
  String get videoEditorTransformRotateLabel => 'Draaien';

  @override
  String get videoEditorTransformFlipLabel => 'Spiegelen';

  @override
  String get videoEditorTransformResetLabel => 'Resetten';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'Transformatie toepassen';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Transformatie annuleren';

  @override
  String get videoEditorTransformPlayLabel => 'Afspelen';

  @override
  String get videoEditorTransformPauseLabel => 'Pauze';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Kan niet omdraaien: clip is niet lokaal beschikbaar.';

  @override
  String get videoEditorReverseFailed =>
      'Kon clip niet omdraaien. Probeer het opnieuw.';

  @override
  String get videoEditorSpeedSheetTitle => 'Clipsnelheid';

  @override
  String get videoEditorTransitionSheetTitle => 'Overgang';

  @override
  String get videoEditorTransitionNone => 'Geen';

  @override
  String get videoEditorTransitionDissolve => 'Vervloeien';

  @override
  String get videoEditorTransitionFadeToBlack => 'Vervagen naar zwart';

  @override
  String get videoEditorTransitionFadeToWhite => 'Vervagen naar wit';

  @override
  String get videoEditorTransitionSlide => 'Schuiven';

  @override
  String get videoEditorTransitionPush => 'Duwen';

  @override
  String get videoEditorTransitionWipe => 'Vegen';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Overgang bewerken';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Loop-overgang';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Loop-overgang bewerken';

  @override
  String get videoEditorTransitionDuration => 'Duur';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Ingekort zodat deze niet overlapt met de aangrenzende overgang.';

  @override
  String get videoEditorTransitionCurve => 'Curve';

  @override
  String get videoEditorTransitionDirection => 'Richting';

  @override
  String get videoEditorTransitionDirectionLeft => 'Links';

  @override
  String get videoEditorTransitionDirectionRight => 'Rechts';

  @override
  String get videoEditorTransitionDirectionUp => 'Omhoog';

  @override
  String get videoEditorTransitionDirectionDown => 'Omlaag';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Animatiecurve $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animatie';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Laaganimatie bewerken';

  @override
  String get videoEditorLayerAnimationEnter => 'Ingang';

  @override
  String get videoEditorLayerAnimationLeave => 'Uitgang';

  @override
  String get videoEditorLayerAnimationFade => 'Vervagen';

  @override
  String get videoEditorLayerAnimationScale => 'Schaal';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Schalen vanaf';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Bewerken van tijdlijn voltooien';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Voorbeeld afspelen';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Voorbeeld pauzeren';

  @override
  String get videoEditorAudioUntitledSound => 'Naamloos geluid';

  @override
  String get videoEditorAudioUntitled => 'Naamloos';

  @override
  String get videoEditorAudioAddAudio => 'Audio toevoegen';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Geen geluiden beschikbaar';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Geluiden verschijnen hier wanneer creators audio delen';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Geluiden laden mislukt';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Selecteer het audiofragment voor je video';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Gemeenschap';

  @override
  String get videoEditorAudioCategoryFeatured => 'Uitgelicht';

  @override
  String get videoEditorAudioCategoryMySounds => 'Mijn sounds';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Pijlgereedschap';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Gumgereedschap';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Markeergereedschap';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Potloodgereedschap';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Tijdlijn tonen';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Tijdlijn verbergen';

  @override
  String get videoEditorFeedPreviewContent =>
      'Plaats geen content achter deze gebieden.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originelen';

  @override
  String get videoEditorStickerSearchHint => 'Stickers zoeken...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Lettertype selecteren';

  @override
  String get videoEditorFontUnknown => 'Onbekend';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'De afspeelkop moet binnen de geselecteerde clip staan om te splitsen.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Begin bijsnijden';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Einde bijsnijden';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Clip bijsnijden';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Sleep de handgrepen om de clipduur aan te passen';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Clip $index slepen';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index van $total, $duration seconden';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Lang indrukken om te slepen';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Naar links verplaatsen';

  @override
  String get videoEditorTimelineClipMoveRight => 'Naar rechts verplaatsen';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index van $total, geselecteerd';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index van $total, niet geselecteerd';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Selecteren';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Meerdere clips selecteren';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Selectie voltooien';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips geselecteerd',
      one: '1 clip geselecteerd',
      zero: 'Geen clips geselecteerd',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Meerdere tekeningen selecteren';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Klaar met tekeningen selecteren';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Geselecteerde tekeningen verwijderen';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tekeningen geselecteerd',
      one: '1 tekening geselecteerd',
      zero: 'Geen tekeningen geselecteerd',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Samenvoegen';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Geselecteerde clips samenvoegen';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Geselecteerde clips verwijderen';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Geselecteerde frames verwijderen';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Geselecteerde frames omkeren';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Geselecteerde frames dupliceren';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Je video moet minstens ${seconds}s duren – leg nog een paar frames vast.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Een moment, we voegen je clips samen';

  @override
  String get videoEditorMergeFailed =>
      'Kan clips niet samenvoegen. Probeer het opnieuw.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Lang indrukken om te slepen';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Videotijdlijn';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, geselecteerd';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Kleurkiezer sluiten';

  @override
  String get videoEditorPickColorTitle => 'Kleur kiezen';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Kleur bevestigen';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Verzadiging en helderheid';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Verzadiging $saturation%, Helderheid $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Tint';

  @override
  String get videoEditorAddElementSemanticLabel => 'Element toevoegen';

  @override
  String get videoEditorDoneSemanticLabel => 'Gereed';

  @override
  String get videoEditorLevelSemanticLabel => 'Niveau';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Berichtdetails sluiten';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Helpdialoog sluiten';

  @override
  String get videoMetadataGotItButton => 'Begrepen!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limiet van 64KB bereikt. Verwijder wat inhoud om door te gaan.';

  @override
  String get videoMetadataExpirationLabel => 'Vervaldatum';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Vervaltijd selecteren';

  @override
  String get videoMetadataTitleLabel => 'Titel';

  @override
  String get videoMetadataDescriptionLabel => 'Beschrijving';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Tag $tag verwijderen';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Inhoudswaarschuwing';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Inhoudswaarschuwingen selecteren';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Selecteer alles wat van toepassing is op je inhoud';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Laat anderen de audio van deze video opslaan en hergebruiken.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Je video staat online, maar het geluid is niet gepubliceerd. Bewerk de video om het te delen.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Samenwerkers';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Samenwerker toevoegen';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Wederzijdse volgers';

  @override
  String get videoMetadataInspiredByLabel => 'Geinspireerd door';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Geinspireerd door instellen';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Naar deze creator kan niet worden verwezen.';

  @override
  String get videoMetadataPostDetailsTitle => 'Berichtdetails';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Opgeslagen in bibliotheek';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Opslaan mislukt';

  @override
  String get videoMetadataGoToLibraryButton => 'Naar bibliotheek';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Knop opslaan voor later';

  @override
  String get videoMetadataSavingVideoHint => 'Video opslaan...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Video opslaan in concepten en $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Video opslaan in concepten. Nog geen gerenderde video, dus geen kopie in $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Opslaan voor later';

  @override
  String get videoMetadataPostSemanticLabel => 'Knop plaatsen';

  @override
  String get videoMetadataPublishVideoHint => 'Video publiceren naar feed';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Ook delen in mijn feed';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Uit laat deze video alleen in de reactiethread staan.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Vul het formulier in om in te schakelen';

  @override
  String get videoMetadataPostButton => 'Plaatsen';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Scherm met berichtvoorbeeld openen';

  @override
  String get videoMetadataShareTitle => 'Delen';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Videodetails';

  @override
  String get videoMetadataClassicDoneButton => 'Gereed';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Voorbeeld afspelen';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Voorbeeld pauzeren';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Videovoorbeeld sluiten';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Verwijderen';

  @override
  String get fullscreenFeedRemovedMessage => 'Video verwijderd';

  @override
  String get fullscreenFeedEmptyMessage => 'Hier is niets meer om af te spelen';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle =>
      'Accepteer onderscheidingen en bekijk de status van uitgereikte badges.';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesLoadError => 'Badges konden niet geladen worden';

  @override
  String get badgesUpdateError => 'Badge kon niet bijgewerkt worden';

  @override
  String get badgesAwardedEmptyTitle => 'Nog geen badges toegekend';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Wanneer iemand je een Nostr-badge toekent, landt die hier.';

  @override
  String get badgesStatusAccepted => 'Geaccepteerd';

  @override
  String get badgesStatusNotAccepted => 'Niet geaccepteerd';

  @override
  String get badgesActionRemove => 'Verwijderen';

  @override
  String get badgesActionAccept => 'Accepteren';

  @override
  String get badgesActionReject => 'Weigeren';

  @override
  String get badgesIssuedEmptyTitle => 'Nog geen uitgereikte badges';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Badges die je uitreikt tonen hier hun acceptatiestatus.';

  @override
  String get badgesIssuedNoRecipients =>
      'Geen ontvangers gevonden voor deze toekenning.';

  @override
  String get badgesRecipientAcceptedStatus => 'Geaccepteerd door ontvanger';

  @override
  String get badgesRecipientWaitingStatus => 'Wacht op ontvanger';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verborgen ($count)',
      one: 'Verborgen (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Herstellen';

  @override
  String get badgesHiddenSnackbar => 'Badge verborgen';

  @override
  String get badgesHiddenSnackbarUndo => 'Ongedaan maken';

  @override
  String get badgesTabAwarded => 'Ontvangen';

  @override
  String get badgesTabCreated => 'Gemaakt';

  @override
  String get badgesTabIssued => 'Uitgereikt';

  @override
  String get badgesCreateAction => 'Nieuwe badge';

  @override
  String get badgesCreatedEmptyTitle => 'Nog geen badges gemaakt';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Maak er een en geef hem aan iemand die het verdient.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uitgereikt aan $count personen',
      one: 'Uitgereikt aan 1 persoon',
      zero: 'Nog niet uitgereikt',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Nieuwe badge';

  @override
  String get badgeEditorEditTitle => 'Badge bewerken';

  @override
  String get badgeEditorNameLabel => 'Naam';

  @override
  String get badgeEditorNameHint => 'Scènedief';

  @override
  String get badgeEditorIdentifierLabel => 'Identificatie';

  @override
  String get badgeEditorIdentifierHelp =>
      'Onderdeel van het adres van de badge, dus die ligt vast zodra de badge bestaat.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Je hebt al een badge met deze identificatie. Bewerk die — hier publiceren zou hem vervangen.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Elke badge heeft een identificatie nodig — typ er zelf een als de naam er geen invulde.';

  @override
  String get badgeEditorDescriptionLabel => 'Omschrijving';

  @override
  String get badgeEditorDescriptionHint =>
      'Voor wie de show steelt met één perfecte loop.';

  @override
  String get badgeEditorArtworkLabel => 'Artwork';

  @override
  String get badgeEditorArtworkAdd => 'Artwork toevoegen';

  @override
  String get badgeEditorArtworkReplace => 'Vervangen';

  @override
  String get badgeEditorArtworkError =>
      'Die afbeelding kon niet worden geüpload';

  @override
  String get badgeEditorArtworkRequired => 'Elke badge heeft artwork nodig.';

  @override
  String get badgeEditorArtworkRemove => 'Artwork verwijderen';

  @override
  String get badgeEditorArtworkSheetTitle => 'Badge-artwork';

  @override
  String get badgeDetailDeleteAction => 'Badge verwijderen';

  @override
  String get badgeDetailDeleteTitle => 'Deze badge verwijderen?';

  @override
  String get badgeDetailDeleteBody =>
      'Dit vraagt relays om de badge en alle uitreikingen ervan te laten vallen. Relays mogen weigeren, en wie hem heeft vastgezet houdt hem op zijn profiel tot hij hem zelf weghaalt.';

  @override
  String get badgeDetailDeleteConfirm => 'Verwijderen';

  @override
  String get badgeEditorSaveAction => 'Badge publiceren';

  @override
  String get badgeEditorSaveError => 'De badge kon niet worden gepubliceerd';

  @override
  String get badgeEditorLoadError => 'Deze badge kon niet worden geladen';

  @override
  String get badgeDetailTitle => 'Badge';

  @override
  String get badgeDetailMadeBy => 'Gemaakt door';

  @override
  String get badgeDetailRecipientsTitle => 'Uitgereikt aan';

  @override
  String get badgeDetailNoRecipients => 'Niemand heeft deze nog.';

  @override
  String get badgeDetailAwardAction => 'Deze badge uitreiken';

  @override
  String get badgeDetailEditAction => 'Badge bewerken';

  @override
  String get badgeDetailShareAction => 'Delen';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Kijk naar deze badge op Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Badge terugnemen';

  @override
  String get badgeDetailRevokeTitle => 'Deze badge terugnemen?';

  @override
  String get badgeDetailRevokeBody =>
      'Dit vraagt relays om de uitreiking aan deze persoon te laten vallen. Relays mogen weigeren, en als de badge al is vastgezet, blijft hij op het profiel staan tot die hem zelf weghaalt. Hoe dan ook krijgt diegene geen bericht.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Dit vraagt relays om de uitreiking aan jezelf te laten vallen en haalt de badge van je profiel. Weigeren de relays de verwijdering, dan verandert er niets.';

  @override
  String get badgeDetailRevokeConfirm => 'Terugnemen';

  @override
  String get badgeDetailRevokeSuccess => 'Badge teruggenomen';

  @override
  String get badgeDetailBlockClaimantsAction =>
      'Iedereen met deze badge blokkeren';

  @override
  String get badgeDetailBlockClaimantsTitle =>
      'Iedereen met deze badge blokkeren';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Kan niet laden wie deze badge heeft';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Niemand heeft deze badge op dit moment';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'We vonden nu niemand om te blokkeren.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts blokkeren?',
      one: '1 account blokkeren?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dit blokkeert de $count accounts die deze badge nu hebben. Hun posts verschijnen niet meer in jouw feeds en ze krijgen hiervan geen melding.',
      one:
          'Dit blokkeert het account dat deze badge nu heeft. Hun posts verschijnen niet meer in jouw feeds en ze krijgen hiervan geen melding.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts blokkeren',
      one: '1 account blokkeren',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'Accounts met de badge geblokkeerd';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Kan de accounts met deze badge niet blokkeren';

  @override
  String get badgeDetailLoadError => 'Deze badge kon niet worden geladen';

  @override
  String get badgeDetailMissing => 'We vinden deze badge op geen enkele relay.';

  @override
  String get badgeDetailActionError => 'Dat is niet gelukt';

  @override
  String get badgeAwardTitle => 'Badge uitreiken';

  @override
  String get badgeAwardPickAction => 'Mensen kiezen';

  @override
  String get badgeAwardManualLabel => 'Of plak sleutels';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Kies minstens één persoon.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uitreiken aan $count personen',
      one: 'Uitreiken aan 1 persoon',
      zero: 'Badge uitreiken',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Uitgereikt door';

  @override
  String get profileBadgeRecipients => 'Ontvangers';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count meer';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Badge $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Badge';

  @override
  String get profileBadgeFooterBody =>
      'Badges zijn kleine onderscheidingen die iedereen op Nostr kan maken. Geef er een aan een vriend, een creator of iemand die je dag goedmaakte.';

  @override
  String get profileBadgeFooterLink => 'Maak je eigen badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Gezinsgids';

  @override
  String get minorAccountReviewWelcomeTitle => 'Nog geen 16? Geen probleem.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Dat je naar deze pagina bent doorgeklikt in plaats van gewoon het antwoord te kiezen waarmee je binnenkwam, dat telt. Het laat eerlijkheid, ruggengraat en echte zorg voor de mensen om je heen zien.\n\nDe regels voor mensen onder de 16 verschillen afhankelijk van waar je woont. Bij Divine willen we dat gezinnen er samen over praten en bepalen hoe gezond socialmediagebruik eruitziet.';

  @override
  String get minorAccountReviewModerationTitle =>
      'We hebben nog één stap nodig';

  @override
  String get minorAccountReviewModerationBody =>
      'We zijn gevraagd dit account beter te bekijken, omdat het van iemand onder de 16 kan zijn. Deze route houdt de volgende stappen privé en wijst je het pad dat bij jouw leeftijd past.';

  @override
  String get minorAccountReviewRulesTitle =>
      'De regels zijn niet overal hetzelfde';

  @override
  String get minorAccountReviewRulesBody =>
      'Landen en regio\'s gaan verschillend om met tieners op sociale media. Daarom vragen we gezinnen om even rustig aan te doen, de feiten te checken en samen de volgende stap te kiezen.';

  @override
  String get minorAccountReviewApproachTitle => 'Hoe Divine erover denkt';

  @override
  String get minorAccountReviewApproachBody =>
      'Wij denken dat gezonde techgewoontes ontstaan door te pauzeren, na te denken en je aandacht naar betere dingen te verleggen – niet door kinderen te bespioneren of ouders tot toezichthouders te maken. Onderzoek wijst dezelfde kant op.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Meer voor gezinnen';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Lees het kinderbeleid van Divine';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Kies het pad dat past';

  @override
  String get minorAccountReviewUnder13Cta => 'Onder de 13';

  @override
  String get minorAccountReviewTeenCta => '13-15 jaar';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Bekijk de gezinsgids van Divine voor praktische tips, gesprekshulpmiddelen en materiaal waarmee tieners sociale media veiliger gebruiken.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Bekijk gezinsgidsen en tips';

  @override
  String get minorAccountReviewFooter =>
      'Ben je 16 of ouder en hier per ongeluk beland? Neem contact op met Divine-support, dan kijkt een echt mens ernaar.';

  @override
  String get minorAccountReviewTitle => 'Accountbeoordeling';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Accountstatus controleren...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Even wachten terwijl we de huidige beoordelingsstatus van dit account bevestigen.';

  @override
  String get minorAccountReviewDefaultTitle => 'Accountbeoordeling nodig';

  @override
  String get minorAccountReviewDefaultBody =>
      'We moeten dit account beoordelen voordat het Divine normaal kan gebruiken.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Zaaknummer: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Zaaknummer';

  @override
  String get minorAccountReviewRestrictionsTitle => 'Wat nu beperkt is';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Posten en publiceren staat op pauze';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Reacties, likes, reposts en volgen staan op pauze';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Gewone berichten starten of beantwoorden staat op pauze';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Support en je moderatiebericht blijven beschikbaar';

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
  String get minorAccountReviewOpenSupportCenter => 'Supportcentrum openen';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Moderatiebericht openen';

  @override
  String get minorAccountReviewOpenReviewPage => 'Beoordelingspagina openen';

  @override
  String get minorAccountReviewCheckAgain => 'Opnieuw controleren';

  @override
  String get minorAccountReviewLogOut => 'Uitloggen';

  @override
  String get minorAccountReviewNextStepTitle => 'Volgende stap';

  @override
  String get minorAccountReviewNextStepBody =>
      'Open het supportcentrum of je moderatiebericht als je hulp nodig hebt bij deze beoordeling.';

  @override
  String get minorAccountReviewInProgressTitle => 'Beoordeling loopt';

  @override
  String get minorAccountReviewInProgressBody =>
      'Voorlopig hebben we wat we nodig hebben. Ons team bekijkt deze zaak voordat het account weer normaal toegang krijgt.';

  @override
  String get minorAccountReviewUnder13Title => 'Accounts onder de 13';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Als dit account van iemand onder de 13 is, moet een ouder of voogd mailen naar $supportEmail met vermelding van het zaaknummer.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'We kunnen je nog geen account geven';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine is niet gemaakt voor kinderen onder de 13, en de regels voor sociale media wereldwijd binden ons de handen.\n\nVeel dingen op internet duwen je richting liegen om te krijgen wat je wilt, en daar hebben we een hekel aan. Dat is de verkeerde les voor het leven, en die gaan we je hier niet leren.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Wat je gezin in plaats daarvan kan doen';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Een ouder of voogd kan het account beheren en posten, en jij mag natuurlijk gewoon in de video\'s staan. We willen dat gezinnen van Divine genieten op de manier die bij hen past.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Als je 13 wordt';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Afhankelijk van de regels waar je woont kun je dan misschien terugkomen en een eigen account aanvragen. Ben je dan tussen de 13 en 15, dan heb je toestemming van een ouder of voogd nodig.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Waarom we je niet vertellen om gewoon terug te klikken';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Een groot deel van internet is zo opgezet dat mensen worden beloond voor het zeggen van wat hen door de poort krijgt. Wij vinden dat niet oké. Ja, je zou terug kunnen gaan en zeggen dat je ouder bent dan je bent, maar dat zou niet eerlijk zijn, en we gaan je niet aanleren om te liegen om je zin te krijgen.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'We proberen jongeren te helpen Divine te gebruiken op manieren die gezond en positief zijn voor henzelf en de mensen om hen heen. We moeten ons ook houden aan wetten die per plek verschillen. Dus als je jonger dan 13 bent, is het antwoord dat je vandaag nog geen eigen account kunt hebben.';

  @override
  String get minorAccountReviewTeenBody =>
      'Als dit account van iemand van 13 tot 15 is, gebruik dan het moderatiebericht of de supportroute om de instructies voor ouderlijke toestemming te volgen.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Als het account van iemand van 13 tot 15 wordt';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Een ouder of voogd moet Divine-support mailen met een korte privévideo. Ons team bekijkt hem en helpt met de volgende stappen.\n\nAls contact met een ouder of voogd niet mogelijk is of iemand in gevaar zou brengen, mail Divine-support en laat het ons weten.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Dit is een pauze terwijl het Divine-supportteam de video bekijkt. Als hij wordt goedgekeurd, helpen ze je met het opzetten van het nieuwe account.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Waarom we vragen om een ouder of voogd erbij te betrekken';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine moet zich houden aan leeftijdsgerelateerde wetten over de hele wereld. We weten ook dat de meeste technische leeftijdscontroles niet waterdicht zijn. In plaats van te doen alsof de regels niet bestaan of alsof het stoer is om over je leeftijd te liegen, willen we dat tieners en families weloverwogen beslissingen nemen over hoe ze Divine het best kunnen gebruiken. Daarom vragen we voor 13- tot 15-jarigen aan ouders om deel te nemen aan het aanmaken van het account.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'We moeten ons ook aan de wet houden, en die regels verschillen afhankelijk van waar iemand woont. Dus in plaats van te doen alsof de regels niet bestaan, vragen we een ouder of voogd om deel uit te maken van het proces.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Wat de video moet laten zien';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'De tiener in de video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Een ouder of voogd die in de camera praat';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Een duidelijke verklaring dat de tiener 13 tot 15 is en toestemming heeft om Divine te gebruiken';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Een duidelijke verklaring dat de ouder of voogd van het account weet en toezicht houdt op het gebruik';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Hoe je het stuurt';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Voeg de video toe als bijlage bij je mail aan Divine-support';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Houd de video privé en post hem niet in de app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Ons team bekijkt hem en reageert met de volgende stappen';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Mail Divine-support';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Hulp bij Divine Greenlight-beoordeling (13-15 jaar)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hallo Divine-support,\n\nik neem contact op over Divine Greenlight voor een tiener van 13-15 jaar.\n\nIk heb een korte privévideo bijgevoegd die laat zien:\n- de tiener\n- een ouder of voogd die in de camera praat\n- dat de tiener toestemming heeft om Divine te gebruiken\n- dat de ouder of voogd van het account weet en toezicht houdt op het gebruik\n\nLand(en) van verblijf:\n\nHandige context:\n\nBedankt.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Supportinstructies voor ouders';

  @override
  String get minorAccountReviewContinue => 'Doorgaan';

  @override
  String get minorAccountReviewErrorTitle =>
      'We konden de beoordelingsstatus van je account niet laden.';

  @override
  String get minorAccountReviewErrorBody => 'Probeer het zo nog eens.';

  @override
  String get minorAccountReviewTryAgain => 'Probeer opnieuw';

  @override
  String get minorAccountReviewParentContactTitle => 'Contact met ouder';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Voeg het e-mailadres van een ouder of voogd toe';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'We gebruiken dit adres voor de beoordeling van de ouderlijke toestemming in zaak $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'E-mailadres van ouder of voogd';

  @override
  String get minorAccountReviewSubmitting => 'Versturen...';

  @override
  String get minorAccountReviewSubmitEmail => 'E-mail versturen';

  @override
  String get minorAccountReviewBackToReview =>
      'Terug naar de accountbeoordeling';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'E-mail verstuurd';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'We hebben $email ter beoordeling ingediend. We mailen dit adres ter bevestiging. Zodra je ouder of voogd reageert, gaat je zaak verder. Gebruik Opnieuw controleren op het accountbeoordelingsscherm voor updates.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'We hebben het contact van de ouder of voogd voor dit account ontvangen. Ons team bekijkt het voordat de toegang wordt hersteld.';

  @override
  String get minorAccountReviewMissingCase =>
      'We konden geen actieve beoordelingszaak voor dit account vinden.';

  @override
  String get minorAccountReviewParentContactError =>
      'Het e-mailadres van de ouder kon niet worden verstuurd. Probeer het opnieuw.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Support voor ouders';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Een ouder of voogd moet contact opnemen met Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Bij accounts die waarschijnlijk van iemand onder de 13 zijn, is de volgende stap contact per e-mail door een ouder of voogd.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'E-mailadres van support';

  @override
  String get minorAccountReviewCopySupportEmail =>
      'E-mailadres van support kopiëren';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'E-mailadres van support gekopieerd';

  @override
  String get minorAccountReviewCopyCaseId => 'Zaaknummer kopiëren';

  @override
  String get minorAccountReviewCaseIdCopied => 'Zaaknummer gekopieerd';

  @override
  String get minorAccountReviewUnavailable => 'Niet beschikbaar';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Vraag de ouder of voogd om het zaaknummer te vermelden en uit te leggen dat het over deze accountbeoordeling gaat.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Accountbeoordeling onder de 13 voor zaak $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Hallo Divine-support,\n\nik ben de ouder of voogd van een kind onder de 13 en neem contact op over accountbeoordelingszaak $caseId.\n\nBedankt.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulatie accountbeoordeling minderjarige';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Huidige status';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Beperkt ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Actief';

  @override
  String get devOptionsMinorReviewStateLoading => 'Laden...';

  @override
  String get devOptionsMinorReviewStateError =>
      'Fout bij het laden van de status';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Simulatie-overschrijving wissen';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Weer de backend of de standaard actieve status gebruiken';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      'Beoordelingszaak 13-15 simuleren';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Beperkt account met route voor oudercontact';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Supportzaak onder de 13 simuleren';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Beperkt account met instructies alleen via e-mail van de ouder';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simulatie accountbeoordeling minderjarige gewist';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Gesimuleerde supportzaak onder de 13 ingeschakeld';

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
      'Simulatie beschermde minderjarige';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Huidige status';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Beschermde minderjarige (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Niet beschermd';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Laden…';

  @override
  String get devOptionsProtectedMinorStateError =>
      'Fout bij het lezen van de status';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Geen overschrijving (echte accountstatus)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Overschrijving: beschermd afgedwongen';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Overschrijving: niet beschermd afgedwongen';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Beschermde minderjarige simuleren (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Dwing de status beschermde minderjarige af om de beveiligingen #175/#176 te testen';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Meerderjarige simuleren';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Dwing niet beschermd af (een expliciet nee, anders dan geen overschrijving)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Overschrijving wissen';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Terug naar de echte accountstatus vanuit Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Status beschermde minderjarige afgedwongen';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Status beschermde minderjarige uitgezet';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Overschrijving beschermde minderjarige gewist';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Aanmelduitnodigingen';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Huidige status';

  @override
  String get devOptionsInviteAvailabilityServerLoading => 'Serverwaarde: laden';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => 'Serverwaarde: aan';

  @override
  String get devOptionsInviteAvailabilityServerDisabled => 'Serverwaarde: uit';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Serverwaarde: onbekend';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Overschrijving: serverwaarde gebruiken';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Overschrijving: aan afdwingen';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Overschrijving: uit afdwingen';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Serverwaarde gebruiken';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'De onboardingMode van de uitnodigingsdienst volgen';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Aan afdwingen';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Toon lokaal de drempels en het beheer van aanmelduitnodigingen';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Uit afdwingen';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Verberg de uitnodigingsinterface lokaal zonder de server te wijzigen';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Aanmelduitnodigingen volgen nu de server';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Aanmelduitnodigingen afgedwongen op aan';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Aanmelduitnodigingen afgedwongen op uit';

  @override
  String get commentsRecordVideoButtonLabel => 'Videoreactie opnemen';

  @override
  String get commentsOpenVideoLabel => 'Videoreactie openen';

  @override
  String get commentsMuteVideoReplyLabel => 'Videoreactie dempen';

  @override
  String get commentsUnmuteVideoReplyLabel =>
      'Dempen van videoreactie opheffen';

  @override
  String get commentsOpenReplyParentLabel => 'Video openen waarop dit reageert';

  @override
  String get commentsReplyParentSectionTitle => 'Als reactie op';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Reactie op $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Reactie op video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Geverifieerd $platform-account: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Geverifieerde accounts';

  @override
  String get profileEditGetVerifiedCta => 'Laat je verifiëren';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Koppel je social-media-accounts zodat mensen weten dat jij het bent.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Website bezoeken: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Website kon niet worden geopend';

  @override
  String get videoMetadataEditCoverTitle => 'Omslag bewerken';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Wijzigingen aan omslag negeren';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Geselecteerd frame als video-omslag gebruiken';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Door video scrollen om omslagframe te selecteren';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Tags zoeken of toevoegen';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Voeg tags toe zodat anderen je video ontdekken';

  @override
  String get videoMetadataTagsPickerNoResults => 'Geen overeenkomende tags';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '«#$tag» toevoegen';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Nog geen 16? Dat geeft niet. ';

  @override
  String get authUnder16ChoicesCta => 'Dit zijn je keuzes.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Dit is waarom';

  @override
  String get generalSettingsHoldToRecord => 'Ingedrukt houden om op te nemen';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Opname start wanneer je ingedrukt houdt en stopt wanneer je loslaat';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos gepubliceerd op je profiel',
      one: 'Video gepubliceerd op je profiel',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Bericht versturen';

  @override
  String get emojiPickerSearchHint => 'Zoeken';

  @override
  String get emojiCategoryRecent => 'Recent';

  @override
  String get emojiCategorySmileys => 'Smileys en mensen';

  @override
  String get emojiCategoryAnimals => 'Dieren en natuur';

  @override
  String get emojiCategoryFood => 'Eten en drinken';

  @override
  String get emojiCategoryActivities => 'Activiteiten';

  @override
  String get emojiCategoryTravel => 'Reizen en plaatsen';

  @override
  String get emojiCategoryObjects => 'Objecten';

  @override
  String get emojiCategorySymbols => 'Symbolen';

  @override
  String get emojiCategoryFlags => 'Vlaggen';

  @override
  String get videoEditorMarkerLabel => 'Markering';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Tijdlijnmarkering toevoegen';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Tijdlijnmarkering verwijderen';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Markering bij de afspeelkop verwijderen';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Markering verwijderen?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Dit verwijdert de markering uit de tijdlijn. Je bewerking blijft intact.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Alle tracks dempen of hervatten';

  @override
  String get videoEditorSplitFailed => 'Splitsen mislukt. Probeer het opnieuw.';

  @override
  String get videoEditEditSubtitles => 'Ondertitels bewerken';

  @override
  String get subtitleEditorTitle => 'Ondertitels bewerken';

  @override
  String get subtitleEditorSave => 'Opslaan';

  @override
  String get subtitleEditorProcessing =>
      'Ondertitels worden nog gegenereerd. Kom zo terug.';

  @override
  String get subtitleEditorNoSpeech =>
      'Er is geen spraak gevonden in deze video, dus er valt niets te ondertitelen.';

  @override
  String get subtitleEditorWriteOwn => 'Schrijf ze zelf';

  @override
  String get subtitleEditorAddCue => 'Regel toevoegen';

  @override
  String get subtitleEditorRemoveCue => 'Deze regel verwijderen';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'De video kan nu niet worden afgespeeld, maar je kunt de ondertitels nog steeds aanpassen.';

  @override
  String get subtitleEditorPlayPreview => 'Video afspelen';

  @override
  String get subtitleEditorPausePreview => 'Video pauzeren';

  @override
  String get subtitleEditorInvalidHint =>
      'Elke regel heeft tekst nodig en een einde na de start.';

  @override
  String get subtitleEditorLoadError =>
      'Ondertitels laden mislukt. Probeer het opnieuw.';

  @override
  String get subtitleEditorSaveSuccess => 'Ondertitels bijgewerkt';

  @override
  String get subtitleEditorSaveError =>
      'Ondertitels opslaan mislukt. Probeer het opnieuw.';

  @override
  String get subtitleEditorRetry => 'Opnieuw proberen';

  @override
  String get subtitleEditorCueHint => 'Ondertiteltekst';

  @override
  String get imageCropEditorRotateLabel => 'Draaien';

  @override
  String get imageCropEditorFlipLabel => 'Spiegelen';

  @override
  String get imageCropEditorResetLabel => 'Resetten';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Bijsnijden annuleren';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Bijsnijden toepassen';

  @override
  String get imageCropEditorProcessing => 'Bijsnijden toepassen…';

  @override
  String get backgroundUploadNotificationTitle => 'Video uploaden';

  @override
  String get monetizationSettingsTitle => 'Steun voor creators';

  @override
  String get monetizationSettingsSubtitle =>
      'Voeg links voor fooien en abonnementen toe';

  @override
  String get monetizationSettingsIntroTitle => 'Alleen externe links';

  @override
  String get monetizationSettingsIntroBody =>
      'Voeg bestemmingen toe die je zelf beheert. Divine verwerkt de betaling nooit en ontgrendelt via deze links geen content in de app.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actieve links op je profiel',
      one: '1 actieve link op je profiel',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Fooi sturen';

  @override
  String get monetizationSettingsSubscriptionSection => 'Abonneren / steunen';

  @override
  String get monetizationSettingsSave => 'Steunlinks opslaan';

  @override
  String get monetizationSettingsSaving => 'Opslaan...';

  @override
  String get monetizationSettingsSaved => 'Steunlinks bijgewerkt';

  @override
  String get monetizationSettingsSaveFailed =>
      'Steunlinks konden niet worden opgeslagen. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get monetizationSettingsErrorEmpty => 'Voeg een handle of URL toe.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Die link ziet er niet goed uit.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Gebruik een link van deze dienst.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag of cash.app-link';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me-handle of link';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo-handle of link';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon-handle of link';

  @override
  String get monetizationSettingsHintSubstack => 'Substack-domein of link';

  @override
  String get monetizationSettingsHintMedium => 'Medium-handle of link';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective-slug of link';

  @override
  String get profileSupportSheetTitle => 'Steun deze creator';

  @override
  String get profileSupportSheetBody =>
      'Deze links openen buiten Divine. Niets hiervan ontgrendelt content in de app.';

  @override
  String get profileSupportTipSection => 'Fooi sturen';

  @override
  String get profileSupportSubscriptionSection => 'Abonneren / steunen';

  @override
  String get profileSupportButtonLabel => 'Steunen';

  @override
  String get monetizationTipsSettingsTitle => 'Fooien';

  @override
  String get monetizationTipsSettingsSubtitle => 'Voeg optionele fooilinks toe';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Alleen optionele fooien';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Fooien zijn optionele cadeautjes tussen mensen. Ze ontgrendelen geen content, abonnementen, functies, ranking, zichtbaarheid of toegang in Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actieve fooilinks op je profiel',
      one: '1 actieve fooilink op je profiel',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Fooilinks opslaan';

  @override
  String get monetizationTipsSettingsSaved => 'Fooilinks bijgewerkt';

  @override
  String get profileTipButtonLabel => 'Fooi';

  @override
  String get profileTipSheetTitle => 'Geef deze creator een fooi';

  @override
  String get profileTipSheetBody =>
      'Fooilinks openen buiten Divine. Ze zijn optioneel en ontgrendelen geen content, abonnementen, functies of toegang in Divine.';

  @override
  String get settingsStorageTitle => 'Opslag';

  @override
  String get settingsStorageCacheSectionTitle => 'Media in cache';

  @override
  String get settingsStorageCacheDescription =>
      'Feedvideo\'s, miniaturen en tijdelijke renders in cache. Wissen is veilig: ze worden opnieuw gedownload of gegenereerd wanneer nodig.';

  @override
  String get settingsStorageMeasuring => 'Berekenen…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size in gebruik';
  }

  @override
  String get settingsStorageClearButton => 'Cache wissen';

  @override
  String get settingsStorageClearConfirmTitle => 'Media in cache wissen?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Dit maakt $size vrij. Je clipbibliotheek blijft ongemoeid.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Wissen';

  @override
  String get settingsStorageCleared => 'Cache gewist';

  @override
  String get settingsStorageLibrarySectionTitle => 'Clipbibliotheek';

  @override
  String get settingsStorageLibraryDescription =>
      'Controleer op kapotte clips waarvan het videobestand ontbreekt.';

  @override
  String get settingsStorageScanButton => 'Bibliotheek controleren';

  @override
  String get settingsStorageLibraryHealthy => 'Geen kapotte clips gevonden';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Kapotte clips gevonden: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Kapotte clips verwijderen';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Kapotte clips verwijderd';

  @override
  String get settingsStorageError => 'Er ging iets mis';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Maximale videocache';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count video\'s';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Kapotte clips verwijderen?';

  @override
  String get settingsStorageRepairSectionTitle => 'Installatie repareren';

  @override
  String get settingsStorageRepairDescription =>
      'Als de app blijft crashen of raar doet, helpt het meestal om de lokale gegevens te resetten. Je clips en concepten blijven staan.';

  @override
  String get settingsStorageRepairButton => 'App-gegevens resetten';

  @override
  String get settingsStorageRepairConfirmTitle => 'App-gegevens resetten?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Dit wist gecachte feedgegevens en tijdelijke bestanden. Je clips, concepten, instellingen en aanmelding blijven, maar je moet de app daarna opnieuw starten.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size wordt verwijderd';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Resetten';

  @override
  String get settingsStorageRepairInProgress => 'Bezig met resetten…';

  @override
  String get settingsStorageRepairSuccess =>
      'Klaar — start de app opnieuw om af te ronden.';

  @override
  String get settingsStorageRepairFailure =>
      'Kon niet alles resetten. Probeer het opnieuw na een herstart.';

  @override
  String get nostrSettingsSignatureVerification => 'Handtekeningverificatie';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Kies wanneer Divine handtekeningen van relay-events controleert. Event-ID\'s worden altijd eerst gevalideerd.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Alle relays';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Veiligst. Verifieer elke handtekening van een relay-event.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Niet-vertrouwde relays';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Sla controles over voor relays die al in je geconfigureerde pool staan.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Niet-Divine-relays';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Vertrouw Divine-relays, verifieer de rest.';

  @override
  String get settingsCrosspostingTitle => 'Crossposten';

  @override
  String get settingsCrosspostingSubtitle =>
      'Deel je video’s op andere platforms';

  @override
  String get crosspostingSignInRequired =>
      'Log in met Divine om crossposten te beheren';

  @override
  String get crosspostingLoadFailed =>
      'Je crosspost-instellingen konden niet geladen worden';

  @override
  String get crosspostingNoPlatforms =>
      'Er zijn nu geen crosspost-platforms beschikbaar';

  @override
  String get crosspostingRetry => 'Opnieuw proberen';

  @override
  String get crosspostingNotConnected => 'Niet verbonden';

  @override
  String get crosspostingConnected => 'Verbonden';

  @override
  String get crosspostingNeedsReconnect => 'Moet opnieuw gekoppeld worden';

  @override
  String get crosspostingConnect => 'Verbinden';

  @override
  String get crosspostingReconnect => 'Opnieuw verbinden';

  @override
  String get crosspostingDisconnect => 'Loskoppelen';

  @override
  String get crosspostingModeOff => 'Uit';

  @override
  String get crosspostingModeManual => 'Handmatig';

  @override
  String get crosspostingModeManualSubtitle => 'Jij kiest per video';

  @override
  String get crosspostingModeAutomatic => 'Automatisch';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Toekomstige video’s worden automatisch gepost — alleen video’s die je publiceert nadat je dit aanzet';

  @override
  String get crosspostingNotConnectedError =>
      'Koppel dit platform eerst om te wijzigen hoe het post.';

  @override
  String get crosspostingGenericError =>
      'Er ging iets mis. Probeer het opnieuw.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'We hebben nooit iets teruggehoord van de inlogpagina. Als je daar klaar was, ververs dan — je account is misschien al gekoppeld.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform verbonden';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Kon $platform niet verbinden';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'De verbinding is geannuleerd op $platform';
  }

  @override
  String get supporterTitle => 'Divine-supporters';

  @override
  String get supporterTileSubtitle =>
      'Steun Divine met een optioneel maandelijks abonnement.';

  @override
  String get supporterHeroTitle => 'Houd Divine draaiende';

  @override
  String get supporterHeroBody =>
      'Divine is gratis en blijft dat ook. Wil je ons helpen de loops te laten doorgaan, word dan maandelijks supporter. Niets zit op slot — het houdt alleen het licht aan en levert onze dank op.';

  @override
  String get supporterActiveBadge =>
      'Je bent een Divine-supporter. Bedankt dat je dit laat doorgaan.';

  @override
  String get supporterPurchasePending => 'Je aankoop wacht op goedkeuring.';

  @override
  String get supporterPurchaseConfirming => 'Je steun wordt bevestigd…';

  @override
  String get supporterStoreChecking => 'De store wordt gecontroleerd…';

  @override
  String get supporterUnavailable =>
      'Supporter-abonnementen zijn hier nu niet beschikbaar.';

  @override
  String get supporterRestorePurchases => 'Aankopen herstellen';

  @override
  String get supporterDismissError => 'Fout negeren';

  @override
  String get supporterErrorStoreUnavailable =>
      'De store is niet beschikbaar op dit apparaat.';

  @override
  String get supporterErrorPurchaseFailed =>
      'De aankoop is niet voltooid. Er is niets in rekening gebracht.';

  @override
  String get supporterErrorPurchasePending =>
      'Je aankoop wacht op goedkeuring.';

  @override
  String get supporterErrorRestoreFailed =>
      'Geen supporter-abonnement gevonden om te herstellen.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Deze aankoop hoort bij een ander Divine-account.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine kon je supporterstatus nu niet bevestigen.';

  @override
  String get supporterErrorUnknown => 'Er ging iets mis. Probeer het opnieuw.';

  @override
  String get supporterDisclaimer =>
      'Divine bevestigt je supporterstatus nadat de store je aankoop heeft geverifieerd. Erkenning is optioneel, en de halo is geen verificatie.';

  @override
  String get profileNotifyBellOff => 'Melden bij nieuwe vines';

  @override
  String get profileNotifyBellOn => 'Niet meer melden bij nieuwe vines';

  @override
  String get profileNotifyUpdateFailed => 'Kon niet opslaan. Opnieuw proberen?';

  @override
  String get savedSoundYourLabel => 'Jouw label';

  @override
  String get savedSoundAddHashtags => 'Hashtags toevoegen';

  @override
  String get savedSoundDeviceOnly => 'Opgeslagen op dit apparaat';

  @override
  String get savedSoundDetailsRetry =>
      'Die gegevens konden niet worden opgeslagen. Tik om opnieuw te proberen.';

  @override
  String get savedSoundFallbackTitle => 'Opgeslagen geluid';

  @override
  String get savedSoundPreviewAction => 'Geluid beluisteren';

  @override
  String get savedSoundEditAction => 'Geluidsgegevens bewerken';

  @override
  String get savedSoundRemoveAction => 'Opgeslagen geluid verwijderen';

  @override
  String get savedSoundClearHashtagFilter => 'Hashtagfilter wissen';

  @override
  String get soundAllowRemix => 'Laat anderen dit geluid remixen';

  @override
  String get soundReuseUnavailable => 'Dit geluid kan nu niet worden geremixt.';

  @override
  String get soundPublicCredit => 'Openbare geluidsvermelding';

  @override
  String get soundCreditRequired =>
      'Voeg een openbare geluidsvermelding toe voordat je post.';

  @override
  String get soundSharedAs => 'Gedeeld als';

  @override
  String get soundOwnWork => 'Dit geluid heb ik gemaakt';

  @override
  String soundCreatorBy(String creator) {
    return 'Door $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Gedeeld door $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remixen toegestaan';

  @override
  String get soundCreditOnly => 'Alleen vermelding';

  @override
  String get soundCreditTitleLabel => 'Titel van het geluid';

  @override
  String get soundCreditCreatorLabel => 'Maker';

  @override
  String get soundCreditSourceUrlLabel => 'Bron-URL';

  @override
  String get soundCreditPublicHashtagsLabel => 'Openbare hashtags';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Tagselectie annuleren';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Geselecteerde tags toepassen';

  @override
  String get userPickerCancelSemanticLabel => 'Gebruikersselectie annuleren';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Geselecteerde gebruikers bevestigen';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Gebruikersselectie wissen';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Selectie van inhoudswaarschuwingen annuleren';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Geselecteerde inhoudswaarschuwingen toepassen';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Video-editor sluiten';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Doorgaan naar berichtdetails';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Wijzigingen in $tool negeren';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Wijzigingen in $tool toepassen';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Audio verwijderen';

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
  String get verifyTitle => 'Geverifieerde accounts';

  @override
  String get verifySignedOutMessage => 'Log in om je accounts te koppelen.';

  @override
  String get verifyIntro =>
      'Koppel accounts die je al hebt, zodat iedereen ziet dat jij het echt bent.';

  @override
  String get verifyLoadFailed => 'Je koppelingen konden niet worden geladen.';

  @override
  String get verifyRetry => 'Opnieuw proberen';

  @override
  String get verifyLinkedSectionTitle => 'Gekoppeld';

  @override
  String get verifyVerifierUnreachable =>
      'De verifier was niet bereikbaar, dus alles staat op ongecontroleerd.';

  @override
  String get verifyAddSectionTitle => 'Account toevoegen';

  @override
  String get verifyAllPlatformsLinked =>
      'Je hebt alles gekoppeld wat we ondersteunen.';

  @override
  String get verifyStatusVerified => 'Geverifieerd';

  @override
  String get verifyStatusUnverified => 'Niet geverifieerd';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return '$platform-account $identity ontkoppelen';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return '$platform ontkoppelen?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity wordt niet meer op je profiel getoond. Je kunt het later opnieuw koppelen, maar dan moet je opnieuw inloggen of een nieuw bewijs posten.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Ontkoppelen';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Je $platform-account koppelen';
  }

  @override
  String get verifyOneTapBadge => 'Eén tik';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Log in bij $platform, de rest doen wij. Er wordt niets gepost.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Doorgaan met $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Of post een bewijs';

  @override
  String get verifyConnectProofExplainer =>
      'Post je npub op je account en plak daarna de link naar die post.';

  @override
  String get verifyNpubLabel => 'Je npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Je npub kopiëren';

  @override
  String get verifyNpubCopied => 'npub gekopieerd';

  @override
  String get verifyIdentityLabel => 'Accountnaam';

  @override
  String get verifyProofLabel => 'Link naar je post';

  @override
  String get verifyConnectProofCta => 'Controleren en koppelen';

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
      'Verifier niet bereikbaar. Probeer het zo nog eens.';

  @override
  String get verifyErrorOauthFailed =>
      'Dat ging niet door. Probeer het nog eens.';

  @override
  String get verifyErrorHandleRequired => 'Vul eerst je handle in.';

  @override
  String get verifyErrorPublishFailed =>
      'Geverifieerd, maar geen enkele relay nam de update aan. Probeer het nog eens.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Inloggen met één tik is hier nog niet ingesteld. Gebruik het bewijs hieronder.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Maak een openbare gist met je npub in het eerste bestand en plak de gist-link.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Post je npub in een Discord-kanaal dat onze bot kan lezen en plak de berichtlink. Een serveruitnodiging bewijst niets.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tweet je npub vanaf dat account en plak de link naar de tweet.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Post je npub vanaf dat account en plak de link. De accountnaam heeft de instantie nodig — mastodon.social/@alice, niet alleen alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Het kanaal wordt gekoppeld, niet je Telegram-account. Het heeft eerst een openbare link nodig (Telegram maakt nieuwe kanalen privé). Post je npub daar en plak de berichtlink.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Hierboven ingelogd? Dan hoeft er niets meer. Zo niet, post je npub en plak de link naar die post.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Zet je npub in een videobijschrift en plak de link naar die video.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Zet je npub in een videobeschrijving en plak de link naar die video.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform is gekoppeld.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Dat is een privékanaal of een uitnodiging. Geef het kanaal een openbare link en plak dan de berichtlink.';

  @override
  String get verifyErrorRemoveFailed =>
      'Ontkoppelen lukte niet. Probeer het nog eens.';

  @override
  String get verifyErrorLinksUnreadable =>
      'We konden je huidige koppelingen niet lezen, dus er is niets gewijzigd. Controleer je verbinding en probeer het nog eens.';

  @override
  String get verifyChannelLabel => 'Kanaalnaam';

  @override
  String get verifyHowItWorksTitle => 'Hoe werkt het?';

  @override
  String get verifyHowItWorksIntro =>
      'Zie het als een handdruk tussen twee accounts:';

  @override
  String get verifyHowItWorksYourSide =>
      'Je Divine-profiel zegt: “Ik ben @alice op Twitter.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Je Twitter-account bevestigt: “Ja, dat Divine-profiel is van mij.”';

  @override
  String get verifyHowItWorksBothSides =>
      'We checken beide kanten. Komt het overeen, dan ben je geverifieerd. Namaken kan niet: je naam en foto zijn te kopiëren, posten vanaf je echte account niet.';

  @override
  String get verifyHowItWorksOwnership =>
      'De koppelingen staan op je eigen Nostr-identiteit, dus je haalt ze hier weg wanneer je wilt.';

  @override
  String get generalSettingsSectionIdentity => 'Identiteit';

  @override
  String get libraryFilterAll => 'Alles';

  @override
  String get libraryFilterArchive => 'Archief';

  @override
  String get libraryFilterDeleted => 'Verwijderd';

  @override
  String get libraryCategoryNewChipLabel => 'Nieuw';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Een categorie maken';

  @override
  String get libraryCategoryCreateTitle => 'Nieuwe categorie';

  @override
  String get libraryCategoryCreateAction => 'Maken';

  @override
  String get libraryCategoryRenameTitle => 'Categorie hernoemen';

  @override
  String get libraryCategoryRenameAction => 'Hernoemen';

  @override
  String get libraryCategoryDeleteAction => 'Categorie verwijderen';

  @override
  String get libraryCategoryNameLabel => 'Naam van de categorie';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '‘$name’ verwijderen?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Je clips blijven gewoon staan. Ze gaan alleen terug naar Alles.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Deze categorie hernoemen of verwijderen';

  @override
  String get libraryCategoryMoveTitle => 'Verplaatsen naar';

  @override
  String get libraryCategoryMoveNone => 'Geen categorie';

  @override
  String get libraryCategoryMoveNewCategory => 'Nieuwe categorie';

  @override
  String get libraryArchiveAction => 'Archiveren';

  @override
  String get libraryUnarchiveAction => 'Uit archief halen';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In deze categorieën houden?',
      one: 'In deze categorie houden?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'In $name houden';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'In hun categorieën houden';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Uit $name verwijderen';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Uit hun categorieën verwijderen';

  @override
  String get libraryMoveSelectedClipsTooltip =>
      'Geselecteerde clips verplaatsen';

  @override
  String get libraryCategoryEmptyTitle => 'Hier staat nog niets';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Selecteer een paar clips en verplaats ze naar deze categorie.';

  @override
  String get libraryArchiveEmptyTitle => 'Niets gearchiveerd';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Gearchiveerde clips wachten hier, buiten je hoofdbibliotheek.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips verplaatst naar $name',
      one: '1 clip verplaatst naar $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips uit hun categorie gehaald',
      one: '1 clip uit de categorie gehaald',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips gearchiveerd',
      one: '1 clip gearchiveerd',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips terug in je bibliotheek',
      one: '1 clip terug in je bibliotheek',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'E-mail wijzigen';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Verplaats je account naar een ander adres';

  @override
  String get accountSettingsChangePassword => 'Wachtwoord wijzigen';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Kies een nieuw wachtwoord om in te loggen';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Je sessie is verlopen. Log opnieuw in om dit te wijzigen.';

  @override
  String get accountCredentialsRateLimited =>
      'Te veel pogingen. Wacht een paar minuten.';

  @override
  String get accountCredentialsNetwork =>
      'We konden Divine niet bereiken. Check je verbinding en probeer het opnieuw.';

  @override
  String get accountCredentialsUnknown =>
      'Dat werkte niet. Probeer het opnieuw.';

  @override
  String get changePasswordSubtitle =>
      'Typ je huidige wachtwoord en kies daarna een nieuw.';

  @override
  String get changePasswordCurrentLabel => 'Huidig wachtwoord';

  @override
  String get changePasswordWrongCurrent => 'Dat is niet je huidige wachtwoord.';

  @override
  String get changePasswordSuccess => 'Wachtwoord gewijzigd.';

  @override
  String get changeEmailSubtitle =>
      'We sturen een bevestigingslink naar je nieuwe adres en naar dat van je account. Je e-mail verandert zodra je beide bevestigt.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Op je account: $email';
  }

  @override
  String get changeEmailNewLabel => 'Nieuw e-mailadres';

  @override
  String get changeEmailPasswordLabel => 'Je wachtwoord';

  @override
  String get changeEmailSameAsCurrent => 'Dat is al je e-mailadres.';

  @override
  String get changeEmailWrongPassword => 'Dat is niet je wachtwoord.';

  @override
  String get changeEmailSubmit => 'Bevestigingslinks sturen';

  @override
  String get changeEmailSentTitle => 'Er zijn twee links onderweg';

  @override
  String changeEmailSentMessage(String email) {
    return 'Bevestig vanaf $email en vanaf het adres op je account. Je e-mail wisselt zodra beide gedaan zijn.';
  }

  @override
  String get changeEmailSentExpiry => 'De links werken 24 uur.';

  @override
  String get changeEmailSentDone => 'Duidelijk';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount video\'\'s',
      one: '$formattedCount video',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Wederzijds';

  @override
  String get socialProofFollowsYou => 'Volgt jou';

  @override
  String get socialProofYouFollow => 'Jij volgt';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount volgers',
      one: '$formattedCount volger',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Er laden nu geen video\'s.\nHet ligt aan ons, niet aan jou — we zijn ermee bezig.';

  @override
  String get feedOfflineMessage =>
      'Je bent offline.\nControleer je verbinding en probeer het opnieuw.';

  @override
  String get dbFailureTitle => 'kan je lokale database niet ontgrendelen';

  @override
  String get dbFailureAdviceResettable =>
      'Opnieuw opstarten lost dit niet op. De lokale database hieronder resetten geeft Divine een schone start — je account blijft behouden.';

  @override
  String get dbFailureAdviceRestart =>
      'Start Divine opnieuw nadat je je apparaat hebt ontgrendeld. Blijft dit gebeuren, werk de app dan bij of neem contact op met support.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Probeer Divine één keer opnieuw te starten. Als dit blijft gebeuren, werk de app dan bij of neem contact op met support. Je lokale gegevens zijn er nog.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnose: $code';
  }

  @override
  String get dbFailureCloseApp => 'Divine sluiten';

  @override
  String get dbFailureResetAction => 'lokale database resetten';

  @override
  String get dbFailureConfirmTitle => 'je lokale database resetten?';

  @override
  String get dbFailureConfirmBody =>
      'Je account blijft behouden. Concepten en clips die op dit apparaat zijn opgeslagen worden verwijderd — berichten en feeds komen terug van het netwerk.';

  @override
  String get dbFailureResetConfirm => 'lokale database nu resetten';

  @override
  String get dbFailureCancel => 'annuleren';

  @override
  String get dbFailureResetFailed =>
      'Dat werkte niet. Sluit Divine en probeer het opnieuw.';

  @override
  String get dbFailureResetDoneTitle => 'lokale database gereset';

  @override
  String get dbFailureResetDoneBody =>
      'Sluit Divine en open het opnieuw — bij de volgende start wordt een nieuwe lokale database aangemaakt.';

  @override
  String get authSignInOptionsInfo => 'Over aanmeldopties';

  @override
  String get authShowPassword => 'Wachtwoord tonen';

  @override
  String get authHidePassword => 'Wachtwoord verbergen';

  @override
  String get followUserSemanticLabel => 'Gebruiker volgen';

  @override
  String get unfollowUserSemanticLabel => 'Gebruiker ontvolgen';

  @override
  String get commentsLoadingSemanticLabel => 'Reacties laden';

  @override
  String get analyticsWindowAll => 'Alles';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Gebruiker volgen $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Gebruiker ontvolgen $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / maand';
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
  String get updateGentleBanner => 'Er is een nieuwe update. Bekijk hem →';

  @override
  String get updateModerateTitle =>
      'Er is een update sinds je laatste controle';

  @override
  String get updateUrgentTitle => 'Je mist belangrijke oplossingen';

  @override
  String get updateNotNow => 'Niet nu';

  @override
  String get updateAction => 'Bijwerken';

  @override
  String updateNewIn(String version) {
    return 'Nieuw in $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Update beschikbaar';
}

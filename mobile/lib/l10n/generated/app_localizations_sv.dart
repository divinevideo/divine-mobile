// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Klippåterställning';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Hittar inspelningar som lagrats under ett annat konto och videofiler som ingen post längre refererar till.';

  @override
  String get devOptionsClipRecoveryScan => 'Sök igenom';

  @override
  String get devOptionsClipRecoveryFailure =>
      'Klippåterställningen misslyckades';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips klipp',
      one: '$clips klipp',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts utkast',
      one: '$drafts utkast',
    );
    return 'Synliga nu: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Dolda under andra konton';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips klipp',
      one: '$clips klipp',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts utkast',
      one: '$drafts utkast',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Flytta till detta konto';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Filer utan referens: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Återskapa i biblioteket';

  @override
  String get devOptionsClipRecoveryEmpty => 'Inget att återställa';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Återställde $count klipp',
      one: 'Återställde $count klipp',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Återställningsrapport kopierad';

  @override
  String get devOptionsStorageFootprint => 'Lagringsanvändning';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Varje mapp appen skriver till. Att rensa cachen frigör bara en del av det.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Mät';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Totalt: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Lagringsrapport kopierad';

  @override
  String get devOptionsStorageFootprintFailure => 'Kunde inte mäta lagringen';

  @override
  String get feedTuningMoreLabel => 'Mer så här';

  @override
  String get feedTuningLessLabel => 'Mindre så här';

  @override
  String get feedTuningUndo => 'Ångra';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Öppna den refererade videon';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Inställningar';

  @override
  String get settingsSecureAccount => 'Säkra ditt konto';

  @override
  String get settingsSessionExpired => 'Sessionen har löpt ut';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Logga in igen för att återfå full åtkomst';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Kreatörsstatistik';

  @override
  String get settingsSupportCenter => 'Supportcenter';

  @override
  String get settingsNotifications => 'Aviseringar';

  @override
  String get settingsBlueskyPublishing => 'Bluesky-publicering';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Hantera korspostning till Bluesky';

  @override
  String get settingsNostrSettings => 'Nostr-inställningar';

  @override
  String get settingsIntegratedApps => 'Integrerade appar';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Godkända tredjepartsappar som körs inuti Divine';

  @override
  String get settingsExperimentalFeatures => 'Experimentella funktioner';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Finjusteringar som kan hicka—testa om du är nyfiken.';

  @override
  String get settingsLegal => 'Juridik';

  @override
  String get settingsIntegrationPermissions => 'Integrationsbehörigheter';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Granska och återkalla sparade integrationsgodkännanden';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Utvecklarläge är redan aktiverat';

  @override
  String get settingsDeveloperModeEnabled => 'Utvecklarläge aktiverat!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count tryck till för att aktivera utvecklarläge';
  }

  @override
  String get settingsShareDivine => 'Dela Divine med dina vänner';

  @override
  String get settingsSwitchAccount => 'Byt konto';

  @override
  String get settingsAddAnotherAccount => 'Lägg till ett till konto';

  @override
  String get settingsAccountSwitchFailed =>
      'Det gick inte att byta konto. Försök igen.';

  @override
  String get settingsUnsavedDraftsTitle => 'Osparade utkast';

  @override
  String get settingsUploadInProgressTitle => 'Uppladdning pågår';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videor',
      one: 'video',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dina videor sparas som utkast',
      one: 'din video sparas som utkast',
    );
    return 'Du har fortfarande $count $_temp0 som laddas upp. Att byta konto stoppar uppladdningen — $_temp1 i det här kontot.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'utkast',
      one: 'utkast',
    );
    return 'Du har $count osparade $_temp0. Att byta konto behåller dina utkast, men du kanske vill publicera eller granska dem först.';
  }

  @override
  String get settingsCancel => 'Avbryt';

  @override
  String get settingsSwitchAnyway => 'Byt ändå';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Sessionen för det kontot har gått ut. Att logga in där igen betyder att du loggas ut från det du använder nu.';

  @override
  String get settingsAppVersionLabel => 'Appversion';

  @override
  String get settingsAppLanguage => 'Appspråk';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (enhetens standard)';
  }

  @override
  String get settingsAppLanguageTitle => 'Appspråk';

  @override
  String get settingsAppLanguageDescription =>
      'Välj språk för appens gränssnitt';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Använd enhetens språk';

  @override
  String get settingsGeneralTitle => 'Allmänna inställningar';

  @override
  String get settingsContentSafetyTitle => 'Innehåll och säkerhet';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRATIONER';

  @override
  String get generalSettingsSectionViewing => 'VISNING';

  @override
  String get generalSettingsSectionCreating => 'SKAPANDE';

  @override
  String get generalSettingsSectionApp => 'APPEN';

  @override
  String get appearanceSettingsTitle => 'Utseende';

  @override
  String get appearanceSettingsSubtitle =>
      'Välj hur Divine ska se ut på den här enheten';

  @override
  String get appearanceSettingsSystem => 'Systemstandard';

  @override
  String get appearanceSettingsLight => 'Ljust';

  @override
  String get appearanceSettingsDark => 'Mörkt';

  @override
  String get generalSettingsClosedCaptions => 'Undertexter';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Visa undertexter när videor har dem';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Endast kvadratiska videor';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Behåll flöden i klassiskt kvadratiskt format';

  @override
  String get contentPreferencesTitle => 'Innehållsinställningar';

  @override
  String get contentPreferencesContentFilters => 'Innehållsfilter';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Hantera filter för innehållsvarningar';

  @override
  String get contentPreferencesContentLanguage => 'Innehållsspråk';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (enhetens standard)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tagga dina videor med ett språk så tittarna kan filtrera innehåll.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Använd enhetens språk (standard)';

  @override
  String get contentPreferencesAudioSharing =>
      'Gör mitt ljud tillgängligt för återanvändning';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'När aktiverat kan andra använda ljud från dina videor';

  @override
  String get contentPreferencesMusicMode => 'Musikläge';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Stänger av brusreduceringen som plattar till instrument. Bättre för musik, råare för röster.';

  @override
  String get contentPreferencesAccountLabels => 'Kontoetiketter';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'Självmärk ditt innehåll';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etiketter för kontoinnehåll';

  @override
  String get contentPreferencesClearAll => 'Rensa alla';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Välj allt som gäller för ditt konto';

  @override
  String get contentPreferencesDoneNoLabels => 'Klar (Inga etiketter)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Klar ($count valda)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Ljudingångsenhet';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (rekommenderas)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Väljer automatiskt den bästa mikrofonen';

  @override
  String get contentPreferencesSelectAudioInput => 'Välj ljudingång';

  @override
  String get contentPreferencesUnknownMicrophone => 'Okänd mikrofon';

  @override
  String get contentFiltersAdultContent => 'VUXENINNEHÅLL';

  @override
  String get contentFiltersViolenceGore => 'VÅLD OCH BLOD';

  @override
  String get contentFiltersSubstances => 'SUBSTANSER';

  @override
  String get contentFiltersOther => 'ÖVRIGT';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifiera din ålder under Säkerhet och integritet för att låsa upp filter för vuxeninnehåll';

  @override
  String get contentFiltersShow => 'Visa';

  @override
  String get contentFiltersWarn => 'Varna';

  @override
  String get contentFiltersFilterOut => 'Filtrera bort';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Det här kontot är inte tillgängligt';

  @override
  String get profileInvalidId => 'Ogiltigt profil-ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Kolla in $displayName på Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName på Divine';
  }

  @override
  String get profileShareFailed => 'Kunde inte dela profil. Försök igen.';

  @override
  String get profileCopyPublicKey => 'Kopiera publik nyckel (npub)';

  @override
  String get profileGetEmbedCode => 'Hämta inbäddningskod';

  @override
  String get profilePublicKeyCopied => 'Publik nyckel kopierad till urklipp';

  @override
  String get profileEmbedCodeCopied => 'Inbäddningskod kopierad till urklipp';

  @override
  String get profileMoreTooltip => 'Mer';

  @override
  String get profileMoreSemanticLabel => 'Fler alternativ';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Stäng avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Stäng avatarförhandsvisning';

  @override
  String get profileFollowingLabel => 'Följer';

  @override
  String get profileFollowLabel => 'Följ';

  @override
  String get profileBlockedLabel => 'Blockerad';

  @override
  String get profileFollowersLabel => 'Följare';

  @override
  String get profileFollowingStatLabel => 'Följer';

  @override
  String get profileVideosLabel => 'Videor';

  @override
  String get profileCollabsLabel => 'Samarbeten';

  @override
  String get profileLikedLabel => 'Gillade';

  @override
  String get profileRepostsLabel => 'Återpubliceringar';

  @override
  String get profileListsLabel => 'Listor';

  @override
  String get profileCommentsLabel => 'Kommentarer';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetsinbjudningar behöver fortfarande skickas',
      one: '1 samarbetsinbjudan behöver fortfarande skickas',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Vi köade inbjudan. Försök igen här.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'För \"$title\". Försök igen här.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Försök igen';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Försöker igen';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Det går inte att skicka samarbetsinbjudan igen just nu.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetsinbjudningar behöver fortfarande skickas.',
      one: '1 samarbetsinbjudan behöver fortfarande skickas.',
      zero: 'Samarbetsinbjudningar skickade.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetspartner kan inte ta emot inbjudningar.',
      one: '1 samarbetspartner kan inte ta emot inbjudningar.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count användare';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Blockera $displayName?';
  }

  @override
  String get profileBlockExplanation => 'När du blockerar en användare:';

  @override
  String get profileBlockBulletHidePosts =>
      'Deras inlägg visas inte i dina flöden.';

  @override
  String get profileBlockBulletCantView =>
      'De kommer inte kunna se din profil, följa dig eller se dina inlägg.';

  @override
  String get profileBlockBulletNoNotify => 'De meddelas inte om denna ändring.';

  @override
  String get profileBlockBulletYouCanView =>
      'Du kommer fortfarande kunna se deras profil.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Blockera $displayName';
  }

  @override
  String get profileCancelButton => 'Avbryt';

  @override
  String get profileLearnMore => 'Läs mer';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Avblockera $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'När du avblockerar den här användaren:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Deras inlägg visas i dina flöden.';

  @override
  String get profileUnblockBulletCanView =>
      'De kommer kunna se din profil, följa dig och se dina inlägg.';

  @override
  String get profileUnblockBulletNoNotify =>
      'De meddelas inte om denna ändring.';

  @override
  String get profileLearnMoreAt => 'Läs mer på ';

  @override
  String get profileUnblockButton => 'Avblockera';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Sluta följa $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Blockera $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Avblockera $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Rapportera $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Lägg till $displayName i en lista';
  }

  @override
  String get profileNoCollabsTitle => 'Inga samarbeten än';

  @override
  String get profileCollabsOwnEmpty => 'Videor du samarbetar kring visas här';

  @override
  String get profileCollabsOtherEmpty => 'Videor de samarbetar kring visas här';

  @override
  String get profileErrorLoadingCollabs =>
      'Fel vid inläsning av samarbetsvideor';

  @override
  String get profileNoSavedVideosTitle => 'Inget sparat än';

  @override
  String get profileSavedOwnEmpty =>
      'Bokmärk videor från dela-menyn så dyker de upp här.';

  @override
  String get profileErrorLoadingSaved => 'Kunde inte ladda sparade videor';

  @override
  String get profileNoCommentsOwnTitle => 'Inga kommentarer än';

  @override
  String get profileNoCommentsOtherTitle => 'Inga kommentarer';

  @override
  String get profileCommentsOwnEmpty => 'Dina kommentarer och svar visas här';

  @override
  String get profileCommentsOtherEmpty =>
      'Deras kommentarer och svar visas här';

  @override
  String get profileErrorLoadingComments => 'Fel vid inläsning av kommentarer';

  @override
  String get profileVideoRepliesSection => 'Videosvar';

  @override
  String get profileCommentsSection => 'Kommentarer';

  @override
  String get profileEditLabel => 'Redigera';

  @override
  String get profileLibraryLabel => 'Bibliotek';

  @override
  String get profileNoLikedVideosTitle => 'Inga gillade videor än';

  @override
  String get profileLikedOwnEmpty => 'Videor du gillar visas här';

  @override
  String get profileLikedOtherEmpty => 'Videor de gillar visas här';

  @override
  String get profileErrorLoadingLiked => 'Fel vid inläsning av gillade videor';

  @override
  String get profileNoRepostsTitle => 'Inga återpubliceringar än';

  @override
  String get profileRepostsOwnEmpty => 'Videor du återpublicerar visas här';

  @override
  String get profileRepostsOtherEmpty => 'Videor de återpublicerar visas här';

  @override
  String get profileErrorLoadingReposts =>
      'Fel vid inläsning av återpublicerade videor';

  @override
  String get profileNoVideosTitle => 'Inga videor än';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Dela din första video för att se den här';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Den här användaren har inte delat några videor än';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Videominiatyr $number';
  }

  @override
  String get profileShowMore => 'Visa mer';

  @override
  String get profileShowLess => 'Visa mindre';

  @override
  String get dmMessageDisplayLimitReached =>
      'Resten av meddelandet visas inte.';

  @override
  String get profileCompleteYourProfile => 'Komplettera din profil';

  @override
  String get profileCompleteSubtitle =>
      'Lägg till namn, bio och bild för att komma igång';

  @override
  String get profilePleaseTryAgain => 'Försök igen';

  @override
  String get profileSecureYourAccount => 'Säkra ditt konto';

  @override
  String get profileSecureSubtitle =>
      'Lägg till e-post och lösenord för att återställa ditt konto på vilken enhet som helst';

  @override
  String get profileRetryButton => 'Försök igen';

  @override
  String get profileSessionExpired => 'Sessionen har löpt ut';

  @override
  String get profileSignInToRestore =>
      'Logga in igen för att återfå full åtkomst';

  @override
  String get profileSignInButton => 'Logga in';

  @override
  String get profileMaybeLaterLabel => 'Kanske senare';

  @override
  String get profileSecurePrimaryButton => 'Lägg till e-post och lösenord';

  @override
  String get profileCompletePrimaryButton => 'Uppdatera din profil';

  @override
  String get profileLoopsLabel => 'Loopar';

  @override
  String get profileLikesLabel => 'Gilla-markeringar';

  @override
  String get profileMyLibraryLabel => 'Mitt bibliotek';

  @override
  String get profileMessageLabel => 'Meddelande';

  @override
  String get profileShareLabel => 'Dela profil';

  @override
  String get profileDeletedAccountName => 'Raderat konto';

  @override
  String get inboxActionReportVanishedAccount => 'Rapportera det här kontot';

  @override
  String get inboxActionBlockVanishedAccount => 'Blockera det här kontot';

  @override
  String get inboxActionUnblockVanishedAccount => 'Avblockera det här kontot';

  @override
  String get inboxReportedVanishedAccount => 'Det här kontot har rapporterats';

  @override
  String get inboxBlockedVanishedAccount => 'Det här kontot har blockerats';

  @override
  String get inboxUnblockedVanishedAccount => 'Det här kontot har avblockerats';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Det här tar bort konversationen från din inkorg. Om personen skriver till dig igen startar en ny konversation.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Det här kontot har raderats';

  @override
  String get profileUserFallback => 'användare';

  @override
  String get profileLinkCopied => 'Profillänk kopierad';

  @override
  String get profileSetupEditProfileTitle => 'Redigera profil';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Konfigurera din profil innan du lägger till en NIP-05-adress.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Skapa profil';

  @override
  String get profileSetupBackLabel => 'Tillbaka';

  @override
  String get profileSetupAboutNostr => 'Om Nostr';

  @override
  String get profileSetupProfilePublished => 'Profilen publicerades!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Spara ändringar?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Spara dina ändringar innan du går, eller släng dem och fortsätt.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Spara ändringar';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Släng ändringar';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Fortsätt redigera';

  @override
  String get profileSetupCreateNewProfile => 'Skapa ny profil?';

  @override
  String get profileSetupNoExistingProfile =>
      'Vi hittade ingen befintlig profil på dina reler. Publicering skapar en ny profil. Fortsätta?';

  @override
  String get profileSetupPublishButton => 'Publicera';

  @override
  String get profileSetupUsernameTaken =>
      'Användarnamnet togs precis. Välj ett annat.';

  @override
  String get profileSetupClaimFailed =>
      'Kunde inte claima användarnamnet. Försök igen.';

  @override
  String get profileSetupPublishFailed =>
      'Kunde inte publicera profilen. Försök igen.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Kunde inte nå nätverket. Kontrollera din anslutning och försök igen.';

  @override
  String get profileSetupDisplayNameLabel => 'Visningsnamn';

  @override
  String get profileSetupDisplayNameRequired => 'Ange ett visningsnamn';

  @override
  String get profileSetupBioLabel => 'Bio (valfritt)';

  @override
  String get profileSetupWebsiteLabel => 'Webbplats (valfritt)';

  @override
  String get profileSetupPublicKeyLabel => 'Publik nyckel (npub)';

  @override
  String get profileSetupUsernameLabel => 'Användarnamn (valfritt)';

  @override
  String get profileSetupUsernameHelper =>
      'Använd bokstäver, siffror eller bindestreck. Ditt användarnamn blir en divine.video-adress. Använd visningsnamnet för mellanslag eller symboler.';

  @override
  String get profileSetupSaveButton => 'Spara';

  @override
  String get profileSetupSavingButton => 'Sparar...';

  @override
  String get profileSetupImageUrlTitle => 'Lägg till bild-URL';

  @override
  String get profileSetupImageSelectionFailed =>
      'Bildval misslyckades. Klistra in en bild-URL nedan istället.';

  @override
  String get profileSetupImagesTypeGroup => 'bilder';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Kameraåtkomst är av. Slå på den i Inställningar för att ta ett foto.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Kameraåtkomst är inte tillåten på den här enheten.';

  @override
  String get cameraPickErrorBusy =>
      'Väljaren är redan öppen. Stäng den och försök igen.';

  @override
  String get cameraPickErrorGeneric => 'Kunde inte öppna kameran. Försök igen.';

  @override
  String get profileSetupGotItButton => 'Jag fattar';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Det gick inte att ladda upp bilden. Försök igen senare.';

  @override
  String get profileSetupUploadNetworkError =>
      'Nätverksfel: Kolla din internetanslutning och försök igen.';

  @override
  String get profileSetupUploadAuthError =>
      'Autentiseringsfel: Logga ut och in igen.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Filen är för stor: Välj en mindre bild (max 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Det gick inte att ladda upp bilden. Våra servrar är tillfälligt otillgängliga. Försök igen om en liten stund.';

  @override
  String get profileSetupBannerClearButton => 'Rensa banner';

  @override
  String get profileSetupBannerChangeColor => 'Bannerfärg';

  @override
  String get profileSetupChangeBannerTitle => 'Byt banner';

  @override
  String get profileSetupBannerColorPickerTitle => 'Ändra bannerfärg';

  @override
  String get profileSetupBannerColorCustom => 'Anpassad';

  @override
  String get profileSetupBannerColorNone => 'Ingen färg';

  @override
  String get profileSetupBannerColorLime => 'Lime';

  @override
  String get profileSetupBannerColorYellow => 'Gul';

  @override
  String get profileSetupBannerColorViolet => 'Violett';

  @override
  String get profileSetupBannerColorPink => 'Rosa';

  @override
  String get profileSetupBannerColorOrange => 'Orange';

  @override
  String get profileSetupBannerColorPurple => 'Lila';

  @override
  String get profileSetupAvatarClearButton => 'Ta bort foto';

  @override
  String get profileSetupImageTakePhoto => 'Ta ett foto';

  @override
  String get profileSetupImageUploadFromCameraRoll =>
      'Ladda upp från kamerarullen';

  @override
  String get profileSetupImagePasteLink => 'Klistra in en bildlänk';

  @override
  String get profileSetupEditAvatarLabel => 'Redigera profilbild';

  @override
  String get profileSetupEditBannerLabel => 'Redigera banner';

  @override
  String get profileSetupUsernameChecking => 'Kollar tillgänglighet...';

  @override
  String get profileSetupUsernameAvailable => 'Användarnamnet är ledigt!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Användarnamnet är redan taget';

  @override
  String get profileSetupUsernameReserved => 'Användarnamnet är reserverat';

  @override
  String get profileSetupContactSupport => 'Kontakta support';

  @override
  String get profileSetupCheckAgain => 'Kolla igen';

  @override
  String get profileSetupUsernameBurned =>
      'Det här användarnamnet är inte längre tillgängligt';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Endast bokstäver, siffror och bindestreck är tillåtna';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Användarnamnet får inte börja eller sluta med ett bindestreck';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Användarnamnet måste vara 3–63 tecken';

  @override
  String get profileSetupUsernameNetworkError =>
      'Kunde inte kolla tillgänglighet. Försök igen.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Ogiltigt format på användarnamn';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Kunde inte kolla tillgänglighet';

  @override
  String get profileSetupUsernameReservedTitle =>
      'Användarnamnet är reserverat';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Namnet $username är reserverat. Berätta varför det borde vara ditt.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      't.ex. Det är mitt varumärkesnamn, artistnamn osv.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Har du redan kontaktat supporten? Tryck på \"Kolla igen\" för att se om det har släppts till dig.';

  @override
  String get profileSetupSupportRequestSent =>
      'Supportförfrågan skickad! Vi hör av oss snart.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Kunde inte öppna e-post. Skicka till: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Skicka förfrågan';

  @override
  String get profileSetupUseOwnNip05 => 'Använd din egen NIP-05-adress';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05-adress';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Ogiltigt NIP-05-format (t.ex. namn@domän.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Använd användarnamnsfältet ovan för divine.video';

  @override
  String get nostrSettingsNip05Address => 'NIP-05-adress';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Använd ditt divine.video-användarnamn, eller peka ditt handtag mot en NIP-05-adress på en domän du kontrollerar.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Spara NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 sparad';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Kunde inte spara NIP-05. Försök igen.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Använda din egen NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 kopplar ett namn som du@dindomän.se till din Nostr-identitet. Du måste kontrollera domänen och lägga en verifieringsfil på rätt sökväg. Blir det fel hittar folk dig inte och ditt verifierade handtag försvinner. Fortsätt bara om du har satt upp det här.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Fortsätt';

  @override
  String get profileSetupNip05ConfirmCancel => 'Avbryt';

  @override
  String get profileSetupProfilePicturePreview =>
      'Förhandsvisning av profilbild';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine är byggt på Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' ett censurresistent öppet protokoll som låter folk kommunicera online utan att förlita sig på ett enda företag eller en enda plattform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'När du skapar ett Divine-konto får du en ny Nostr-identitet.';

  @override
  String get nostrInfoOwnership =>
      'Nostr låter dig äga ditt innehåll, din identitet och ditt sociala nätverk, vilket du kan använda i många appar. Resultatet är fler valmöjligheter, mindre inlåsning och ett sundare, mer motståndskraftigt socialt internet.';

  @override
  String get nostrInfoLingo => 'Nostr-jargong:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Din publika Nostr-adress. Den är säker att dela och låter andra hitta, följa eller meddela dig i Nostr-appar.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Din privata nyckel och ditt ägandebevis. Den ger full kontroll över din Nostr-identitet, så ';

  @override
  String get nostrInfoNsecWarning => 'håll den alltid hemlig!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr-användarnamn:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Ett människoläsbart namn (som @namn.divine.video) som länkar till din npub. Det gör din Nostr-identitet lättare att känna igen och verifiera, ungefär som en e-postadress.';

  @override
  String get nostrInfoLearnMoreAt => 'Läs mer på ';

  @override
  String get nostrInfoGotIt => 'Uppfattat!';

  @override
  String get videoGridRefreshLabel => 'Söker efter fler videor';

  @override
  String get videoGridOptionsTitle => 'Videoalternativ';

  @override
  String get videoGridEditVideo => 'Redigera video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Uppdatera titel, beskrivning och hashtags';

  @override
  String get videoGridDeleteVideo => 'Ta bort video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Ta bort den här videon från Divine. Den kan fortfarande visas i andra Nostr-klienter.';

  @override
  String get videoGridDeletingContent => 'Tar bort innehåll...';

  @override
  String get exploreTabFeatured => 'Utvalda';

  @override
  String get exploreTabClassics => 'Klassiker';

  @override
  String get exploreTabNew => 'Nytt';

  @override
  String get exploreTabPopular => 'Populärt';

  @override
  String get exploreTabCategories => 'Kategorier';

  @override
  String get exploreTabForYou => 'För dig';

  @override
  String get exploreTabLists => 'Listor';

  @override
  String get exploreTabIntegratedApps => 'Integrerade appar';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Inget här än. Kika in igen snart.';

  @override
  String get featuredTabLoadFailed => 'Kunde inte läsa in den här samlingen.';

  @override
  String get featuredTabRetry => 'Försök igen';

  @override
  String get exploreNoVideosAvailable => 'Inga videor tillgängliga';

  @override
  String get exploreDiscoverLists => 'Upptäck listor';

  @override
  String get exploreAboutLists => 'Om listor';

  @override
  String get exploreAboutListsDescription =>
      'Listor hjälper dig organisera och kuratera Divine-innehåll på två sätt:';

  @override
  String get explorePeopleLists => 'Personlistor';

  @override
  String get explorePeopleListsDescription =>
      'Följ grupper av kreatörer och se deras senaste videor';

  @override
  String get exploreVideoLists => 'Videolistor';

  @override
  String get exploreVideoListsDescription =>
      'Skapa spellistor med dina favoritvideor för att titta på senare';

  @override
  String get exploreMyLists => 'Mina listor';

  @override
  String get exploreSubscribedLists => 'Prenumererade listor';

  @override
  String get exploreErrorLoadingLists =>
      'Fel vid inläsning av listor. Försök igen.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya videor',
      one: '1 ny video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nya videor',
      one: 'ny video',
    );
    return 'Ladda $count $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Spela upp video';

  @override
  String get videoPlayerMute => 'Stäng av ljudet på videon';

  @override
  String get videoPlayerUnmute => 'Slå på ljudet för videon';

  @override
  String get videoPlayerTapHint =>
      'Tryck för att spela eller pausa. Dubbeltryck för att gilla.';

  @override
  String get videoSettingsMenuOpen => 'Öppna uppspelningsinställningar';

  @override
  String get videoSettingsMenuClose => 'Stäng uppspelningsinställningar';

  @override
  String get videoSettingsCaptionsEnable => 'Aktivera textning';

  @override
  String get videoSettingsCaptionsDisable => 'Avaktivera textning';

  @override
  String get videoSettingsAutoAdvanceOn => 'Automatisk fortsättning på';

  @override
  String get videoSettingsAutoAdvanceOff => 'Automatisk fortsättning av';

  @override
  String get videoSettingsCaptionsOn => 'Textning på';

  @override
  String get videoSettingsCaptionsOff => 'Textning av';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Undertexter på för den här videon';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Undertexter av för den här videon';

  @override
  String get contentWarningLabel => 'Innehållsvarning';

  @override
  String get contentWarningNudity => 'Nakenhet';

  @override
  String get contentWarningSexualContent => 'Sexuellt innehåll';

  @override
  String get contentWarningPornography => 'Pornografi';

  @override
  String get contentWarningGraphicMedia => 'Grafiskt material';

  @override
  String get contentWarningViolence => 'Våld';

  @override
  String get contentWarningSelfHarm => 'Självskada';

  @override
  String get contentWarningDrugUse => 'Drogbruk';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tobak';

  @override
  String get contentWarningGambling => 'Spel om pengar';

  @override
  String get contentWarningProfanity => 'Grovt språk';

  @override
  String get contentWarningFlashingLights => 'Blinkande ljus';

  @override
  String get contentWarningAiGenerated => 'AI-genererat';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Känsligt innehåll';

  @override
  String get contentWarningDescNudity =>
      'Innehåller nakenhet eller delvis nakenhet';

  @override
  String get contentWarningDescSexual => 'Innehåller sexuellt innehåll';

  @override
  String get contentWarningDescPorn =>
      'Innehåller explicit pornografiskt innehåll';

  @override
  String get contentWarningDescGraphicMedia =>
      'Innehåller grafiska eller störande bilder';

  @override
  String get contentWarningDescViolence => 'Innehåller våldsamt innehåll';

  @override
  String get contentWarningDescSelfHarm =>
      'Innehåller referenser till självskada';

  @override
  String get contentWarningDescDrugs => 'Innehåller drogrelaterat innehåll';

  @override
  String get contentWarningDescAlcohol =>
      'Innehåller alkoholrelaterat innehåll';

  @override
  String get contentWarningDescTobacco => 'Innehåller tobaksrelaterat innehåll';

  @override
  String get contentWarningDescGambling => 'Innehåller spelrelaterat innehåll';

  @override
  String get contentWarningDescProfanity => 'Innehåller grovt språk';

  @override
  String get contentWarningDescFlashingLights =>
      'Innehåller blinkande ljus (varning för ljuskänslighet)';

  @override
  String get contentWarningDescAiGenerated =>
      'Det här innehållet genererades av AI';

  @override
  String get contentWarningDescSpoiler => 'Innehåller spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'Kreatören markerade detta som känsligt';

  @override
  String get contentWarningDescDefault =>
      'Kreatören flaggade det här innehållet';

  @override
  String get contentWarningDetailsTitle => 'Innehållsvarningar';

  @override
  String get contentWarningDetailsSubtitle =>
      'Kreatören applicerade dessa etiketter:';

  @override
  String get contentWarningManageFilters => 'Hantera innehållsfilter';

  @override
  String get contentWarningViewAnyway => 'Visa ändå';

  @override
  String get contentWarningReportContentTooltip => 'Rapportera innehåll';

  @override
  String get contentWarningBlockUserTooltip => 'Blockera användare';

  @override
  String get contentWarningBlockedTitle => 'Innehåll blockerat';

  @override
  String get contentWarningBlockedPolicy =>
      'Det här innehållet har blockerats på grund av riktlinjebrott.';

  @override
  String get contentWarningNoticeTitle => 'Innehållsvarning';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potentiellt skadligt innehåll';

  @override
  String get contentWarningView => 'Visa';

  @override
  String get contentWarningReportAction => 'Rapportera';

  @override
  String get contentWarningHideAllLikeThis => 'Dölj allt innehåll som det här';

  @override
  String get contentWarningNoFilterYet =>
      'Inget sparat filter för den här varningen än.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Vi döljer inlägg som det här från och med nu.';

  @override
  String get communitySuggestTitle => 'Hjälp till att klassificera det här';

  @override
  String get communitySuggestSubtitle =>
      'Saknas en innehållsvarning? Ditt förslag är offentligt, signerat och kan inte återtas.';

  @override
  String get communitySuggestSubmit => 'Föreslå';

  @override
  String get communitySuggestSuccess => 'Tack. Ditt förslag har skickats.';

  @override
  String get communitySuggestFailure =>
      'Kunde inte skicka ditt förslag. Försök igen.';

  @override
  String get communitySuggestAlready => 'Du har föreslagit det här';

  @override
  String get communitySuggestActionLabel => 'Klassificera';

  @override
  String get videoErrorNotFound => 'Videon hittades inte';

  @override
  String get videoErrorPlayback => 'Fel vid videouppspelning';

  @override
  String get videoErrorAgeRestricted => 'Åldersbegränsat innehåll';

  @override
  String get videoErrorUnavailable => 'Videon är otillgänglig';

  @override
  String get videoErrorUnavailableBody =>
      'Den här videon är inte tillgänglig just nu.';

  @override
  String get videoErrorRetry => 'Försök igen';

  @override
  String get videoErrorContentRestricted => 'Innehåll begränsat';

  @override
  String get videoErrorContentRestrictedBody =>
      'Den här videon togs bort för att den bröt mot våra innehållsregler.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifiera din ålder för att se den här videon.';

  @override
  String get videoErrorSkip => 'Hoppa över';

  @override
  String get videoErrorVerifyAgeButton => 'Verifiera ålder';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Det gick inte att verifiera din ålder. Försök igen.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Timeout vid verifiering. Kontrollera din anslutning eller försök igen om en stund.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Innehåll för vuxna är avstängt';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Slå på det i dina innehållsfilter för att se den här videon.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Öppna innehållsfilter';

  @override
  String get videoDetailLoadError => 'Kunde inte läsa in videon';

  @override
  String get videoDetailLoadErrorBody =>
      'Något gick snett på vägen hit. Testa igen.';

  @override
  String get videoDetailNotFoundBody =>
      'Den kan vara borttagen, utom räckhåll eller dold av dina inställningar.';

  @override
  String get databaseCorruptionTitle => 'Dina lokala data har skadats';

  @override
  String get databaseCorruptionBody =>
      'Stäng Divine och öppna appen igen – vi fixar det automatiskt. Vi räddar så mycket vi kan av dina utkast och klipp, resten laddas om.';

  @override
  String get databaseCorruptionCloseButton => 'Stäng Divine';

  @override
  String get videoDetailContextTitle => 'Delad video';

  @override
  String get videoDetailCloseSemanticLabel => 'Stäng videospelaren';

  @override
  String get videoFollowButtonFollow => 'Följ';

  @override
  String get audioAttributionOriginalSound => 'Originalljud';

  @override
  String get audioAttributionUnavailableSound => 'Ljud otillgängligt';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirerad av @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirerad av @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'med @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'med @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetspartner',
      one: '1 samarbetspartner',
    );
    return '$_temp0. Tryck för att se profil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Väntar';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Väntande medskapare';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending väntar)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Tryck för att se profilen.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Tryck för att se videor med den här hashtaggen.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Dela video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Inlägg delat med $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Inlägg delat med $count personer',
      one: 'Inlägg delat med $count person',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Kunde inte skicka video';

  @override
  String get shareAddedToBookmarks => 'Tillagd i bokmärken';

  @override
  String get shareRemovedFromBookmarks => 'Borttagen från bokmärken';

  @override
  String get shareFailedToAddBookmark => 'Kunde inte lägga till bokmärket';

  @override
  String get shareFailedToRemoveBookmark => 'Kunde inte ta bort från bokmärken';

  @override
  String get shareActionFailed => 'Åtgärden misslyckades';

  @override
  String get shareWithTitle => 'Dela med';

  @override
  String get shareFindPeople => 'Hitta personer';

  @override
  String get shareFindPeopleMultiline => 'Hitta\npersoner';

  @override
  String get shareSent => 'Skickat';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name vald';
  }

  @override
  String get shareMessageHint => 'Lägg till valfritt meddelande...';

  @override
  String get videoActionUnlike => 'Sluta gilla videon';

  @override
  String get videoActionLike => 'Gilla videon';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Gilla';

  @override
  String get videoActionReplyLabel => 'Svara';

  @override
  String get videoActionRepostLabel => 'Dela vidare';

  @override
  String get videoActionShareLabel => 'Dela';

  @override
  String get videoActionReportLabel => 'Anmäl';

  @override
  String get videoActionReport => 'Anmäl video';

  @override
  String get videoActionEditLabel => 'Redigera';

  @override
  String get videoActionEdit => 'Redigera video';

  @override
  String get videoActionAboutLabel => 'Om';

  @override
  String get videoActionEnableAutoAdvance => 'Aktivera automatisk fortsättning';

  @override
  String get videoActionDisableAutoAdvance =>
      'Inaktivera automatisk fortsättning';

  @override
  String get videoActionRemoveRepost => 'Ta bort återpublicering';

  @override
  String get videoActionRepost => 'Återpublicera video';

  @override
  String get videoActionViewComments => 'Visa kommentarer';

  @override
  String get videoActionMoreOptions => 'Fler alternativ';

  @override
  String get videoEngagementLikersTitle => 'Gillat av';

  @override
  String get videoEngagementRepostersTitle => 'Repostat av';

  @override
  String get videoEngagementLikersEmpty => 'Inga gillningar än';

  @override
  String get videoEngagementRepostersEmpty => 'Inga reposts än';

  @override
  String get videoEngagementLoadFailed => 'Det gick inte att läsa in listan';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Öppna videodetaljer';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Öppna videodetaljer';

  @override
  String get videoOverlayCommentBarHint => 'Lägg till kommentar...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Lägg till en kommentar';

  @override
  String get videoOverlayCommentBarSendLabel => 'Skicka kommentar';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Kommentar publicerad';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Kunde inte publicera kommentaren';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loopar',
      one: 'loop',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Inte Divine';

  @override
  String get metadataBadgeHumanMade => 'Gjord av människa';

  @override
  String get metadataSoundsLabel => 'Ljud';

  @override
  String get metadataOriginalSound => 'Originalljud';

  @override
  String get metadataVerificationLabel => 'Verifiering';

  @override
  String get metadataDeviceAttestation => 'Enhetsattestering';

  @override
  String get metadataPgpSignature => 'PGP-signatur';

  @override
  String get metadataC2paCredentials => 'C2PA Content Credentials';

  @override
  String get metadataProofManifest => 'Bevismanifest';

  @override
  String get metadataVerificationInfoTooltip =>
      'Vad betyder de här kontrollerna?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Vad kontrollerna betyder';

  @override
  String get metadataVerificationInfoIntro =>
      'Signalerna kommer från kameran och från själva videofilen. Ju fler en video bär med sig, desto mer kan vi bevisa om var den kommer ifrån.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Telefonens operativsystem gick i god för appen som spelade in. Starkt stöd för att det kommer från en kamera och inte från en uppladdad fil.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Videon signerades kryptografiskt i samma stund den spelades in. Ändras en enda bildruta efteråt bryts signaturen.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Ett ursprungsintyg enligt branschstandard som följer med i filen – så att även andra appar än Divine kan kontrollera det.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Hela ProofMode-posten: filens fingeravtryck, tidsstämpel och inspelningskontext, tillsammans med videon.';

  @override
  String get metadataVerificationInfoFootnote =>
      'En kontroll som saknas gör inte videon falsk. Äldre klipp och uppladdningar fick aldrig någon – det betyder bara att vi inte kan bevisa den delen.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Läs mer på $url';
  }

  @override
  String get metadataCreatorLabel => 'Kreatör';

  @override
  String get metadataCollaboratorsLabel => 'Samarbetspartner';

  @override
  String get metadataInspiredByLabel => 'Inspirerad av';

  @override
  String get metadataRepostedByLabel => 'Återpublicerad av';

  @override
  String metadataMoreReposters(int count) {
    return '+$count till';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Loopar';
  }

  @override
  String get metadataLikesLabel => 'Gillamarkeringar';

  @override
  String get metadataCommentsLabel => 'Kommentarer';

  @override
  String get metadataRepostsLabel => 'Återpubliceringar';

  @override
  String get metadataVineStatsLabel => 'På Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loopar · $likes gillamarkeringar · $comments kommentarer · $reposts återpubliceringar';
  }

  @override
  String get metadataDivineStatsLabel => 'På Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views visningar · $likes gillamarkeringar · $comments kommentarer · $reposts återpubliceringar';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publicerat den $date';
  }

  @override
  String get devOptionsTitle => 'Utvecklaralternativ';

  @override
  String get devOptionsDisableDeveloperMode => 'Inaktivera utvecklarläge';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Dölj utvecklaralternativ från inställningarna';

  @override
  String get devOptionsDisableDeveloperModeToast => 'Utvecklarläge inaktiverat';

  @override
  String get devOptionsShorebirdTitle => 'Shorebird-korrigeringar';

  @override
  String get devOptionsShorebirdPatchLabel => 'Aktiv korrigering';

  @override
  String get devOptionsShorebirdNoPatch => 'Ingen korrigering installerad';

  @override
  String get devOptionsShorebirdUnavailable =>
      'Inte tillgängligt i den här versionen';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Korrigeringar fungerar bara i en version skapad med shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Läser korrigeringsstatus…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Testspåret har inte kontrollerats än.';

  @override
  String get devOptionsShorebirdCheck => 'Kontrollera testspåret';

  @override
  String get devOptionsShorebirdApply => 'Tillämpa testkorrigering';

  @override
  String get devOptionsShorebirdUseStable =>
      'Återgå till stabila uppdateringar';

  @override
  String get devOptionsShorebirdChecking => 'Kontrollerar testspåret…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'En testkorrigering är redo att tillämpas.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Ingen testkorrigering för den här versionen.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Hämtad. Starta om appen för att läsa in den.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'En återställning är redo. Starta om för att återgå till basversionen.';

  @override
  String get devOptionsShorebirdApplying => 'Hämtar och installerar…';

  @override
  String get devOptionsShorebirdApplied =>
      'Installerad. Starta om appen för att läsa in den.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Inget installerades. Kontrollera testspåret och försök igen.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Väljer den stabila kanalen…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Den stabila kanalen har valts. Starta om appen för att söka efter en stabil patch.';

  @override
  String get devOptionsShorebirdFailure =>
      'Det fungerade inte. Kontrollera loggarna för mer information.';

  @override
  String get devOptionsPageLoadTimes => 'Sidladdningstider';

  @override
  String get devOptionsNoPageLoads =>
      'Inga sidladdningar registrerade än.\nNavigera i appen för att se tidsdata.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Synlig: $visibleMs ms  |  Data: $dataMs ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Långsammaste skärmarna';

  @override
  String get devOptionsVideoPlaybackFormat => 'Videouppspelningsformat';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Byta miljö?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Byta till $envName?\n\nDetta rensar cachad videodata och åternsluter till den nya relen.';
  }

  @override
  String get devOptionsCancel => 'Avbryt';

  @override
  String get devOptionsSwitch => 'Byt';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Bytte till $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Bytte till $formatName — cache rensad';
  }

  @override
  String get featureFlagTitle => 'Funktionsflaggor';

  @override
  String get featureFlagResetAllTooltip =>
      'Återställ alla flaggor till standard';

  @override
  String get featureFlagError => 'Fel';

  @override
  String get relaySettingsTitle => 'Reler';

  @override
  String get relaySettingsInfoTitle =>
      'Divine är ett öppet system – du styr dina anslutningar';

  @override
  String get relaySettingsInfoDescription =>
      'De här relerna distribuerar ditt innehåll över det decentraliserade Nostr-nätverket. Du kan lägga till eller ta bort reler som du vill.';

  @override
  String get relaySettingsLearnMoreNostr => 'Läs mer om Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Hitta publika reler på nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Appen fungerar inte';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine kräver minst en rel för att ladda videor, publicera innehåll och synka data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Återställ standardrel';

  @override
  String get relaySettingsAddCustomRelay => 'Lägg till egen rel';

  @override
  String get relaySettingsAddRelay => 'Lägg till rel';

  @override
  String get relaySettingsRetry => 'Försök igen';

  @override
  String get relaySettingsNoStats => 'Ingen statistik tillgänglig än';

  @override
  String get relaySettingsConnection => 'Anslutning';

  @override
  String get relaySettingsConnected => 'Ansluten';

  @override
  String get relaySettingsDisconnected => 'Frånkopplad';

  @override
  String get relaySettingsSessionDuration => 'Sessionslängd';

  @override
  String get relaySettingsLastConnected => 'Senast ansluten';

  @override
  String get relaySettingsDisconnectedLabel => 'Frånkopplad';

  @override
  String get relaySettingsReason => 'Anledning';

  @override
  String get relaySettingsActiveSubscriptions => 'Aktiva prenumerationer';

  @override
  String get relaySettingsTotalSubscriptions => 'Totala prenumerationer';

  @override
  String get relaySettingsEventsReceived => 'Mottagna händelser';

  @override
  String get relaySettingsEventsSent => 'Skickade händelser';

  @override
  String get relaySettingsRequestsThisSession =>
      'Förfrågningar i den här sessionen';

  @override
  String get relaySettingsFailedRequests => 'Misslyckade förfrågningar';

  @override
  String get relaySettingsLoadingRelayInfo => 'Läser in relinfo...';

  @override
  String get relaySettingsAboutRelay => 'Om relen';

  @override
  String get relaySettingsSupportedNips => 'NIP:er som stöds';

  @override
  String get relaySettingsSoftware => 'Mjukvara';

  @override
  String get relaySettingsViewWebsite => 'Visa webbplats';

  @override
  String get relaySettingsRemoveRelayTitle => 'Ta bort rel?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Är du säker på att du vill ta bort den här relen?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Ta bort Divines rel?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Att ta bort Divines rel försämrar upplevelsen i appen. Videor, publicering och synk kan bli mindre pålitliga. Gör bara det här om du är en van Nostr-användare.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Ta bort rel';

  @override
  String get relaySettingsCancel => 'Avbryt';

  @override
  String get relaySettingsRemove => 'Ta bort';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Rel borttagen: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Kunde inte ta bort relen';

  @override
  String get relaySettingsForcingReconnection => 'Tvingar återanslutning...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Ansluten till $count rel(er)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Kunde inte ansluta till reler. Kolla din nätverksanslutning.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Sparat på den här enheten. Vi synkar det till ditt konto när publicering fungerar igen.';

  @override
  String get relaySettingsAddRelayTitle => 'Lägg till rel';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Ange WebSocket-URL:en för relen du vill lägga till:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Bläddra bland publika reler på nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Lägg till';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Rel tillagd: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Kunde inte lägga till relen. Kolla URL:en och försök igen.';

  @override
  String get relaySettingsInvalidUrl =>
      'Rel-URL måste börja med wss:// eller ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'Rel-URL måste använda wss:// (ws:// tillåts endast för localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Återställde standardrel: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Kunde inte återställa standardrelen. Kolla din nätverksanslutning.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Kunde inte öppna webbläsaren';

  @override
  String get relaySettingsFailedToOpenLink => 'Kunde inte öppna länken';

  @override
  String get relaySettingsExternalRelay => 'Extern rel';

  @override
  String get relaySettingsNotConnected => 'Inte ansluten';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Frånkopplad för $duration sedan';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count prenumerationer';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count händelser';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'för $duration sedan';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine använder Nostr-protokollet för decentraliserad publicering. Ditt innehåll lever på reler du väljer, och dina nycklar är din identitet.';

  @override
  String get nostrSettingsSectionNetwork => 'Nätverk';

  @override
  String get nostrSettingsSectionAccount => 'Konto';

  @override
  String get nostrSettingsSectionDangerZone => 'Riskzon';

  @override
  String get nostrSettingsRelays => 'Reler';

  @override
  String get nostrSettingsRelaysSubtitle => 'Hantera Nostr-relanslutningar';

  @override
  String get nostrSettingsRelayDiagnostics => 'Reldiagnostik';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Felsök relanslutningar och nätverksproblem';

  @override
  String get nostrSettingsMediaServers => 'Mediaservrar';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Konfigurera Blossom-uppladdningsservrar';

  @override
  String get settingsDeveloperOptions => 'Utvecklaralternativ';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Miljöväxlare och felsökningsinställningar';

  @override
  String get nostrSettingsKeyManagement => 'Nyckelhantering';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exportera, säkerhetskopiera och återställ dina Nostr-nycklar';

  @override
  String get nostrSettingsClientAttribution => 'Klientattribuering';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Lägg till en Divine-klienttagg på events du publicerar så att andra Nostr-appar kan attribuera dem korrekt. Utan den väger dina rapporter mindre när våra moderatorer granskar dem.';

  @override
  String get nostrSettingsMoveAccount => 'Flytta ditt konto';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Ladda ner ditt arkiv och flytta dina inlägg och videor till en annan relay eller medieserver.';

  @override
  String get nostrSettingsRemoveKeys => 'Ta bort nycklar från enheten';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Radera din privata nyckel från endast den här enheten. Ditt innehåll stannar på relerna, men du behöver din nsec-säkerhetskopia för att komma åt kontot igen.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Kunde inte ta bort det här kontot från enheten. Försök igen.';

  @override
  String get nostrSettingsDeleteAccount => 'Radera konto och data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Skickar raderingsförfrågningar för ditt innehåll och loggar ut dig på den här enheten. Reläer, klienter, sökindex och andra inloggade enheter kan behålla kopior.';

  @override
  String get relayDiagnosticTitle => 'Reldiagnostik';

  @override
  String get relayDiagnosticRefreshTooltip => 'Uppdatera diagnostik';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Senaste uppdatering: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relstatus';

  @override
  String get relayDiagnosticInitialized => 'Initierad';

  @override
  String get relayDiagnosticReady => 'Redo';

  @override
  String get relayDiagnosticNotInitialized => 'Inte initierad';

  @override
  String get relayDiagnosticDatabaseEvents => 'Databashändelser';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Aktiva prenumerationer';

  @override
  String get relayDiagnosticExternalRelays => 'Externa reler';

  @override
  String get relayDiagnosticConfigured => 'Konfigurerad';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count rel(er)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Ansluten';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Videohändelser';

  @override
  String get relayDiagnosticHomeFeed => 'Hemflöde';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count videor';
  }

  @override
  String get relayDiagnosticDiscovery => 'Upptäck';

  @override
  String get relayDiagnosticLoading => 'Laddar';

  @override
  String get relayDiagnosticYes => 'Ja';

  @override
  String get relayDiagnosticNo => 'Nej';

  @override
  String get relayDiagnosticTestDirectQuery => 'Testa direktförfrågan';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Nätverksanslutning';

  @override
  String get relayDiagnosticRunNetworkTest => 'Kör nätverkstest';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom-server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testa alla ändpunkter';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Fel';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake-API';

  @override
  String get relayDiagnosticBaseUrl => 'Bas-URL';

  @override
  String get relayDiagnosticSummary => 'Sammanfattning';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (snitt $avgMs ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Testa allt igen';

  @override
  String get relayDiagnosticRetrying => 'Försöker igen...';

  @override
  String get relayDiagnosticRetryConnection => 'Försök ansluta igen';

  @override
  String get relayDiagnosticTroubleshooting => 'Felsökning';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Grön status = Ansluten och fungerar\n• Röd status = Anslutningen misslyckades\n• Om nätverkstestet misslyckas, kolla internetanslutningen\n• Om reler är konfigurerade men inte anslutna, tryck på \"Försök ansluta igen\"\n• Ta en skärmdump av den här skärmen för felsökning';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Alla REST-ändpunkter är friska!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Vissa REST-ändpunkter misslyckades – se detaljer ovan';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Hittade $count videohändelser i databasen';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'Förfrågan misslyckades. Försök igen.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Ansluten till $count rel(er)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Kunde inte ansluta till några reler';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Förnyat anslutningsförsök misslyckades. Försök igen.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Ansluten och autentiserad';

  @override
  String get relayDiagnosticConnectedOnly => 'Ansluten';

  @override
  String get relayDiagnosticNotConnected => 'Inte ansluten';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Inga reler konfigurerade';

  @override
  String get relayDiagnosticFailed => 'Misslyckades';

  @override
  String get notificationSettingsTitle => 'Aviseringar';

  @override
  String get notificationSettingsResetTooltip => 'Återställ till standard';

  @override
  String get notificationSettingsTypes => 'Aviseringstyper';

  @override
  String get notificationSettingsLikes => 'Gillamarkeringar';

  @override
  String get notificationSettingsLikesSubtitle =>
      'När någon gillar dina videor';

  @override
  String get notificationSettingsComments => 'Kommentarer';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'När någon kommenterar dina videor';

  @override
  String get notificationSettingsFollows => 'Följare';

  @override
  String get notificationSettingsFollowsSubtitle => 'När någon följer dig';

  @override
  String get notificationSettingsMentions => 'Omnämnanden';

  @override
  String get notificationSettingsMentionsSubtitle => 'När du omnämns';

  @override
  String get notificationSettingsReposts => 'Återpubliceringar';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'När någon återpublicerar dina videor';

  @override
  String get notificationSettingsNewPosts => 'Nya vines';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'När någon du bevakar publicerar';

  @override
  String get notificationSettingsActions => 'Åtgärder';

  @override
  String get notificationSettingsMarkAllAsRead => 'Markera alla som lästa';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Markera alla aviseringar som lästa';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Alla aviseringar markerade som lästa';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Kunde inte markera alla som lästa';

  @override
  String get notificationSettingsResetToDefaults =>
      'Inställningar återställda till standard';

  @override
  String get notificationSettingsAbout => 'Om aviseringar';

  @override
  String get notificationSettingsAboutDescription =>
      'Aviseringar drivs av Nostr-protokollet. Realtidsuppdateringar beror på din anslutning till Nostr-reler. Vissa aviseringar kan vara fördröjda.';

  @override
  String get safetySettingsWhatYouSee => 'VAD DU SER';

  @override
  String get safetySettingsWhatYouPublish => 'VAD DU PUBLICERAR';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Visa endast Divine-hostade videor';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Dölj videor som serveras från andra mediavärdar';

  @override
  String get safetySettingsModeration => 'MODERERING';

  @override
  String get safetySettingsBlockedUsers => 'BLOCKERADE ANVÄNDARE';

  @override
  String get safetySettingsAgeVerification => 'ÅLDERSVERIFIERING';

  @override
  String get safetySettingsAgeConfirmation =>
      'Jag bekräftar att jag är 18 år eller äldre';

  @override
  String get safetySettingsAgeRequired => 'Krävs för att se vuxeninnehåll';

  @override
  String get safetySettingsAgeLockedForMinor => 'Låst för ditt konto';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Officiell modereringstjänst (på som standard)';

  @override
  String get safetySettingsPeopleIFollow => 'Personer jag följer';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Prenumerera på etiketter från personer du följer';

  @override
  String get safetySettingsAddCustomLabeler => 'Lägg till egen etiketterare';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Ange npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Lägg till egen etiketterare';

  @override
  String get safetySettingsRemoveLabeler => 'Ta bort etiketterare';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Ange npub-adress';

  @override
  String get safetySettingsNoBlockedUsers => 'Inga blockerade användare';

  @override
  String get safetySettingsUnblock => 'Avblockera';

  @override
  String get safetySettingsUserUnblocked => 'Användare avblockerad';

  @override
  String get safetySettingsCancel => 'Avbryt';

  @override
  String get safetySettingsAdd => 'Lägg till';

  @override
  String get analyticsTitle => 'Kreatörsstatistik';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostik';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Växla diagnostik';

  @override
  String get analyticsRetry => 'Försök igen';

  @override
  String get analyticsUnableToLoad => 'Kunde inte läsa in statistik.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Logga in för att se kreatörsstatistik.';

  @override
  String get analyticsViewDataUnavailable =>
      'Visningar är för tillfället inte tillgängliga från relen för de här inläggen. Gillamarkeringar/kommentarer/återpubliceringar är fortfarande exakta.';

  @override
  String get analyticsViewDataTitle => 'Visningsdata';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Uppdaterad $time • Poäng använder gillamarkeringar, kommentarer, återpubliceringar och visningar/loopar från Funnelcake när tillgängliga.';
  }

  @override
  String get analyticsVideos => 'Videor';

  @override
  String get analyticsViews => 'Visningar';

  @override
  String get analyticsInteractions => 'Interaktioner';

  @override
  String get analyticsEngagement => 'Engagemang';

  @override
  String get analyticsFollowers => 'Följare';

  @override
  String get analyticsAvgPerPost => 'Snitt/inlägg';

  @override
  String get analyticsInteractionMix => 'Interaktionsmix';

  @override
  String get analyticsLikes => 'Gillamarkeringar';

  @override
  String get analyticsComments => 'Kommentarer';

  @override
  String get analyticsReposts => 'Återpubliceringar';

  @override
  String get analyticsPerformanceHighlights => 'Prestandahöjdpunkter';

  @override
  String get analyticsMostViewed => 'Mest sedda';

  @override
  String get analyticsMostDiscussed => 'Mest diskuterade';

  @override
  String get analyticsMostReposted => 'Mest återpublicerade';

  @override
  String get analyticsNoVideosYet => 'Inga videor än';

  @override
  String get analyticsViewDataUnavailableShort => 'Visningsdata otillgänglig';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count visningar';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count kommentarer';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count återpubliceringar';
  }

  @override
  String get analyticsTopContent => 'Topp-innehåll';

  @override
  String get analyticsPublishPrompt =>
      'Publicera några videor för att se rankningar.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Högersidig % = engagemangsgrad (interaktioner delat med visningar).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Engagemangsgrad kräver visningsdata; värden visas som N/A tills visningar finns tillgängliga.';

  @override
  String get analyticsEngagementLabel => 'Engagemang';

  @override
  String get analyticsViewsUnavailable => 'visningar otillgängliga';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interaktioner';
  }

  @override
  String get analyticsPostAnalytics => 'Inläggsstatistik';

  @override
  String get analyticsOpenPost => 'Öppna inlägg';

  @override
  String get analyticsRecentDailyInteractions =>
      'Senaste dagliga interaktioner';

  @override
  String get analyticsNoActivityYet =>
      'Ingen aktivitet i det här intervallet än.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interaktioner = gillamarkeringar + kommentarer + återpubliceringar per publiceringsdatum.';

  @override
  String get analyticsDailyBarExplainer =>
      'Stapellängden är relativ till din högsta dag i det här fönstret.';

  @override
  String get analyticsAudienceSnapshot => 'Publikmomentbild';

  @override
  String analyticsFollowersCount(String count) {
    return 'Följare: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Följer: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Publikkälla/geografi/tidsuppdelningar kommer att fyllas i när Funnelcake lägger till publikstatistikslutpunkter.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Retentionskurva och visningstidsuppdelning visas när per-sekund/per-hink-retention kommer från Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retentionsdata otillgänglig tills visnings- och tittartidsstatistik returneras av Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostik';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Totalt antal videor: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Med visningar: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Saknar visningar: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydrerade (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydrerade (/visningar): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Källor: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Använd fixturedata';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Skapa ett nytt Divine-konto';

  @override
  String get authCreateNewAccountShort => 'Skapa nytt konto';

  @override
  String get authSignInDifferentAccount => 'Logga in med ett annat konto';

  @override
  String get authUseAnotherAccount => 'Använd ett annat konto';

  @override
  String authContinueAs(String displayName) {
    return 'Fortsätt som $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Dina utkast och klipp är sparade för det här kontot';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Loggar du in här döljs de utkasten och klippen';

  @override
  String get authTermsPrefix =>
      'Genom att välja ett alternativ nedan bekräftar du att du är minst 16 år (eller har genomfört ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divines åldersgodkännande';

  @override
  String get authTermsAfterAgeAuthorization => ') och godkänner ';

  @override
  String get authTermsOfService => 'Användarvillkor';

  @override
  String get authPrivacyPolicy => 'Integritetspolicy';

  @override
  String get authTermsAnd => ', och ';

  @override
  String get authSafetyStandards => 'Säkerhetsstandarder';

  @override
  String get authAmberNotInstalled => 'Amber-appen är inte installerad';

  @override
  String get authAmberConnectionFailed => 'Kunde inte ansluta med Amber';

  @override
  String get authPasswordResetSent =>
      'Om ett konto finns med den e-postadressen har en länk för lösenordsåterställning skickats.';

  @override
  String get authSignInTitle => 'Logga in';

  @override
  String get authEmailLabel => 'E-post';

  @override
  String get authPasswordLabel => 'Lösenord';

  @override
  String get authConfirmPasswordLabel => 'Bekräfta lösenord';

  @override
  String get authEmailRequired => 'E-post krävs';

  @override
  String get authEmailInvalid => 'Ange en giltig e-postadress';

  @override
  String get authPasswordRequired => 'Lösenord krävs';

  @override
  String get authConfirmPasswordRequired => 'Bekräfta ditt lösenord';

  @override
  String get authPasswordsDoNotMatch => 'Lösenorden matchar inte';

  @override
  String get authForgotPassword => 'Glömt lösenord?';

  @override
  String get authImportNostrKey => 'Importera Nostr-nyckel';

  @override
  String get authConnectSignerApp => 'Anslut med en sign-app';

  @override
  String get authSignInWithAmber => 'Logga in med Amber';

  @override
  String get authSignInWithBrowserExtension => 'Logga in med webbläsartillägg';

  @override
  String get authNip07ConnectionFailed =>
      'Det gick inte att ansluta till ditt webbläsartillägg.';

  @override
  String get authNip07ExtensionNotFound =>
      'Inget webbläsartillägg hittades. Installera Alby, nos2x eller ett annat NIP-07-kompatibelt tillägg.';

  @override
  String get authSignInOptionsTitle => 'Inloggningsalternativ';

  @override
  String get authInfoEmailPasswordTitle => 'E-post och lösenord';

  @override
  String get authInfoEmailPasswordDescription =>
      'Logga in med ditt Divine-konto. Om du registrerade dig med e-post och lösenord, använd dem här.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Har du redan en Nostr-identitet? Importera din nsec-privatnyckel från en annan klient.';

  @override
  String get authInfoSignerAppTitle => 'Sign-app';

  @override
  String get authInfoSignerAppDescription =>
      'Anslut med hjälp av en NIP-46-kompatibel fjärrsigner som nsecBunker för förbättrad nyckelsäkerhet.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Använd Amber-signappen på Android för att hantera dina Nostr-nycklar säkert.';

  @override
  String get authInfoBrowserExtensionTitle => 'Webbläsartillägg';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Logga in med ett NIP-07-webbläsartillägg som Alby eller nos2x. Dina nycklar stannar i tillägget — Divine ser dem aldrig.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Fel e-post eller lösenord. Försök igen.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Verifiera din e-post innan du loggar in – kolla din inkorg efter länken.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Det där ser inte ut som en giltig e-postadress.';

  @override
  String get authSignInErrorNetwork =>
      'Kan inte nå servern. Kontrollera din anslutning och försök igen.';

  @override
  String get authSignInErrorGeneric => 'Något gick fel. Försök igen.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Osäker på hur du loggade in förra gången? ';

  @override
  String get authSignInOptionsHintCta => 'Se alla inloggningsalternativ';

  @override
  String get authCreateAccountTitle => 'Skapa konto';

  @override
  String get authBackToInviteCode => 'Tillbaka till inbjudningskod';

  @override
  String get authUseDivineNoBackup => 'Använd Divine utan backup';

  @override
  String get authSkipConfirmTitle => 'En sista grej...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Du är inne! Vi skapar en säker nyckel som driver ditt Divine-konto.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Utan en e-post är din nyckel det enda sättet Divine vet att det här kontot är ditt.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Du kan nå din nyckel i appen, men om du inte är särskilt teknisk rekommenderar vi att du lägger till en e-post och ett lösenord nu. Det gör det enklare att logga in och återställa ditt konto om du tappar eller återställer den här enheten.';

  @override
  String get authAddEmailPassword => 'Lägg till e-post och lösenord';

  @override
  String get authUseThisDeviceOnly => 'Använd bara den här enheten';

  @override
  String get authCompleteRegistration => 'Slutför din registrering';

  @override
  String get authVerifying => 'Verifierar...';

  @override
  String get authVerificationLinkSent =>
      'Vi skickade en verifieringslänk till:';

  @override
  String get authClickVerificationLink =>
      'Klicka på länken i din e-post för att\nslutföra din registrering.';

  @override
  String get authPleaseWaitVerifying =>
      'Vänta medan vi verifierar din e-post...';

  @override
  String get authWaitingForVerification => 'Väntar på verifiering';

  @override
  String get authOpenEmailApp => 'Öppna e-postappen';

  @override
  String get authVerificationPinPrompt =>
      'Eller ange den 6-siffriga koden från din e-post';

  @override
  String get authVerificationPinFieldLabel => '6-siffrig kod';

  @override
  String get authVerificationPinSubmit => 'Verifiera kod';

  @override
  String get authVerificationResendPrompt => 'Fick du den inte?';

  @override
  String get authVerificationResend => 'Skicka igen';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Skicka igen om $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Vi kunde inte skicka mejlet igen. Försök igen.';

  @override
  String get authVerificationResendExpired =>
      'Registreringen har gått ut. Börja om för att få en ny kod.';

  @override
  String get authVerificationResendUnavailable =>
      'Det går inte att skicka igen just nu. Använd den sexsiffriga koden i mejlet vi redan skickade.';

  @override
  String get authVerificationPollingStopped =>
      'Vi slutade kontrollera åt dig. Ange den sexsiffriga koden från mejlet för att logga in.';

  @override
  String get authWelcomeToDivine => 'Välkommen till Divine!';

  @override
  String get authEmailVerified => 'Din e-post har verifierats.';

  @override
  String get authSigningYouIn => 'Loggar in dig';

  @override
  String get authErrorTitle => 'Oj då.';

  @override
  String get authVerificationFailed =>
      'Vi misslyckades att verifiera din e-post.\nFörsök igen.';

  @override
  String get authStartOver => 'Börja om';

  @override
  String get authEmailVerifiedLogin =>
      'E-post verifierad! Logga in för att fortsätta.';

  @override
  String get authVerificationLinkExpired =>
      'Den här verifieringslänken är inte längre giltig.';

  @override
  String get authVerificationConnectionError =>
      'Kunde inte verifiera e-post. Kolla din anslutning och försök igen.';

  @override
  String get authWaitlistConfirmTitle => 'Du är på listan!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Vi delar uppdateringar på $email.\nNär fler inbjudningskoder blir tillgängliga skickar vi dem till dig.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Försök igen';

  @override
  String get authContactSupport => 'Kontakta support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Kunde inte öppna $email';
  }

  @override
  String get authAddInviteCode => 'Lägg till din inbjudningskod';

  @override
  String get authInviteCodeLabel => 'Inbjudningskod';

  @override
  String get authEnterYourCode => 'Ange din kod';

  @override
  String get authNext => 'Nästa';

  @override
  String get authJoinWaitlist => 'Ansluta till väntelistan';

  @override
  String get authJoinWaitlistTitle => 'Ansluta till väntelistan';

  @override
  String get authJoinWaitlistDescription =>
      'Dela din e-post så skickar vi uppdateringar när åtkomst öppnas.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Skicka mig inspiration från Divine';

  @override
  String get authInviteAccessHelp => 'Hjälp med inbjudningsåtkomst';

  @override
  String get authGeneratingConnection => 'Genererar anslutning...';

  @override
  String get authConnectedAuthenticating => 'Ansluten! Autentiserar...';

  @override
  String get authConnectionTimedOut => 'Anslutningen tog slut på tid';

  @override
  String get authApproveConnection =>
      'Se till att du godkände anslutningen i din sign-app.';

  @override
  String get authConnectionCancelled => 'Anslutning avbruten';

  @override
  String get authConnectionCancelledMessage => 'Anslutningen avbröts.';

  @override
  String get authConnectionFailed => 'Anslutning misslyckades';

  @override
  String get authUnknownError => 'Ett okänt fel uppstod.';

  @override
  String get authNostrConnectStartFailed =>
      'Kunde inte nå sign-appen. Kontrollera din anslutning och försök igen.';

  @override
  String get authNostrConnectInvalidSession =>
      'Den här anslutningslänken är inte längre giltig. Starta en ny.';

  @override
  String get authNostrConnectSetupFailed =>
      'Nästan klart — vi kunde inte slutföra inloggningen. Försök igen.';

  @override
  String get authUrlCopied => 'URL kopierad till urklipp';

  @override
  String get authConnectToDivine => 'Anslut till Divine';

  @override
  String get authPasteBunkerUrl => 'Klistra in bunker://-URL';

  @override
  String get authBunkerUrlHint => 'bunker://-URL';

  @override
  String get authInvalidBunkerUrl =>
      'Ogiltig bunker-URL. Den ska börja med bunker://';

  @override
  String get authScanSignerApp => 'Skanna med din\nsign-app för att ansluta.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Väntar på anslutning... $seconds s';
  }

  @override
  String get authCopyUrl => 'Kopiera URL';

  @override
  String get authShare => 'Dela';

  @override
  String get authAddBunker => 'Lägg till bunker';

  @override
  String get authCompatibleSignerApps => 'Kompatibla sign-appar';

  @override
  String get authFailedToConnect => 'Kunde inte ansluta';

  @override
  String get authResetPasswordTitle => 'Återställ lösenord';

  @override
  String get authResetPasswordSubtitle =>
      'Ange ditt nya lösenord. Det måste vara minst 8 tecken långt.';

  @override
  String get authNewPasswordLabel => 'Nytt lösenord';

  @override
  String get authConfirmNewPasswordLabel => 'Bekräfta nytt lösenord';

  @override
  String get authPasswordTooShort => 'Lösenordet måste vara minst 8 tecken';

  @override
  String get authPasswordResetSuccess => 'Lösenordet återställdes. Logga in.';

  @override
  String get authPasswordResetFailed => 'Lösenordsåterställning misslyckades';

  @override
  String get authUnexpectedError => 'Ett oväntat fel uppstod. Försök igen.';

  @override
  String get authUpdatePassword => 'Uppdatera lösenord';

  @override
  String get authSecureAccountTitle => 'Säkra konto';

  @override
  String get authUnableToAccessKeys =>
      'Kunde inte komma åt dina nycklar. Försök igen.';

  @override
  String get authRegistrationFailed => 'Registrering misslyckades';

  @override
  String get authRegistrationComplete => 'Registrering klar. Kolla din e-post.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'Kunde inte skicka återställningsmejl.';

  @override
  String get authSending => 'Skickar...';

  @override
  String get authSignInButton => 'Logga in';

  @override
  String get authVerificationErrorTimeout =>
      'Verifieringen tog slut på tid. Försök registrera dig igen.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verifiering misslyckades – auktoriseringskod saknas.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verifiering misslyckades. Försök igen.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Nätverksfel vid inloggning. Försök igen.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verifiering misslyckades. Försök registrera dig igen.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Inloggning misslyckades. Försök logga in manuellt.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Den här mejladressen är redan registrerad. Logga in i stället.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Koden stämde inte. Dubbelkolla den och försök igen.';

  @override
  String get authVerificationErrorPinExpired =>
      'Koden har gått ut. Tryck på Skicka igen för att få en ny.';

  @override
  String get authVerificationErrorPinLocked =>
      'För många försök. Tryck på Skicka igen för att få en ny kod.';

  @override
  String get authVerificationErrorPinFailed =>
      'Vi kunde inte verifiera koden. Försök igen.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Kodinmatning är inte tillgänglig just nu. Tryck på länken i din e-post eller skicka igen för att få en ny.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Ange en inbjudningskod som ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Den inbjudningskoden ser inte giltig ut.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Den inbjudningskoden är redan använd eller återkallad.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Den här kreatörens inbjudningar är slut';

  @override
  String get authInviteGateErrorUnavailable =>
      'Den inbjudningskoden är inte tillgänglig. Ställ dig i kön så skickar vi en inbjudan när det finns plats.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Vi kunde inte kontrollera koden. Försök igen.';

  @override
  String get authInviteGateErrorUnknown =>
      'Något gick fel. Försök med din inbjudningskod igen.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Den inbjudningskoden är inte längre tillgänglig. Gå tillbaka till din inbjudningskod, gå med i väntelistan eller kontakta supporten.';

  @override
  String get authInviteErrorInvalid =>
      'Den inbjudningskoden kan inte användas just nu. Gå tillbaka till din inbjudningskod, gå med i väntelistan eller kontakta supporten.';

  @override
  String get authInviteErrorTemporary =>
      'Vi kunde inte bekräfta din inbjudan just nu. Gå tillbaka till din inbjudningskod och försök igen, eller kontakta supporten.';

  @override
  String get authInviteErrorUnknown =>
      'Vi kunde inte aktivera din inbjudan. Gå tillbaka till din inbjudningskod, gå med i väntelistan eller kontakta supporten.';

  @override
  String get shareSheetSave => 'Spara';

  @override
  String get shareSheetRemoveFromSaved => 'Ta bort från sparade';

  @override
  String get shareSheetSaveToGallery => 'Spara i galleriet';

  @override
  String get shareSheetSaveWithWatermark => 'Spara med vattenmärke';

  @override
  String get shareSheetSaveVideo => 'Spara video';

  @override
  String get shareSheetAddToClips => 'Lägg till i klipp';

  @override
  String get shareSheetNameClipTitle => 'Namnge det här klippet';

  @override
  String get shareSheetNameClipSubtitle =>
      'Välj ett namn du känner igen i ditt bibliotek.';

  @override
  String get shareSheetClipTitleLabel => 'Klippets titel';

  @override
  String get shareSheetSaveClip => 'Spara klipp';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Sparade \"$title\" till klipp';
  }

  @override
  String get shareSheetUntitledClip => 'Namnlöst klipp';

  @override
  String get shareSheetAddToClipsFailed => 'Kunde inte lägga till i klipp';

  @override
  String get shareSheetAddToList => 'Lägg till i lista';

  @override
  String get shareSheetCopy => 'Kopiera';

  @override
  String get shareSheetShareVia => 'Dela via';

  @override
  String get shareSheetEventJson => 'Händelse-JSON';

  @override
  String get shareSheetEventId => 'Händelse-ID';

  @override
  String get shareSheetMoreActions => 'Fler åtgärder';

  @override
  String get shareSheetCrosspost => 'Korsposta';

  @override
  String get crosspostSheetTitle => 'Korsposta den här videon';

  @override
  String get crosspostSheetSubtitle =>
      'Skicka den till dina anslutna plattformar. Publicering kan ta några minuter.';

  @override
  String get crosspostSubmit => 'Korsposta';

  @override
  String get crosspostStatusQueued => 'I kö';

  @override
  String get crosspostStatusUploading => 'Laddar upp';

  @override
  String get crosspostStatusProcessing => 'Bearbetar';

  @override
  String get crosspostStatusPosted => 'Publicerad';

  @override
  String get crosspostStatusFailed => 'Misslyckades';

  @override
  String get crosspostStatusSkipped => 'Överhoppad';

  @override
  String get crosspostStatusNeedsReauth => 'Behöver återanslutas';

  @override
  String get crosspostViewPost => 'Visa inlägg';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Återanslut $platform i korspostningsinställningarna för att fortsätta publicera.';
  }

  @override
  String get crosspostReconnect => 'Återanslut';

  @override
  String get crosspostErrorNotOwner => 'Bara dina egna videor kan korspostas.';

  @override
  String get crosspostErrorNotEligible => 'Den här videon kan inte korspostas.';

  @override
  String get crosspostErrorNotConnected => 'Den plattformen är inte ansluten.';

  @override
  String get crosspostErrorUnauthorized =>
      'Återanslut ditt konto och försök sedan igen.';

  @override
  String get crosspostErrorNetwork =>
      'Kunde inte nå korspostningstjänsten. Försök igen om en stund.';

  @override
  String get crosspostFailedGeneric => 'Korspostningen misslyckades.';

  @override
  String get crosspostStillWorking =>
      'Jobbar fortfarande. Du kan stänga det här – publiceringen fortsätter i bakgrunden.';

  @override
  String get crosspostDone => 'Klar';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Sparad i kamerarullen';

  @override
  String get watermarkDownloadShare => 'Dela';

  @override
  String get watermarkDownloadDone => 'Klar';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Fotoåtkomst behövs';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'För att spara videor, tillåt fotoåtkomst i Inställningar.';

  @override
  String get watermarkDownloadOpenSettings => 'Öppna inställningar';

  @override
  String get watermarkDownloadNotNow => 'Inte nu';

  @override
  String get watermarkDownloadFailed => 'Nedladdning misslyckades';

  @override
  String get watermarkDownloadDismiss => 'Avfärda';

  @override
  String get watermarkDownloadStageDownloading => 'Laddar ner video';

  @override
  String get watermarkDownloadStageWatermarking => 'Lägger till vattenmärke';

  @override
  String get watermarkDownloadStageSaving => 'Sparar i kamerarullen';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Hämtar videon från nätverket...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Lägger till Divine-vattenmärket...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Sparar den vattenmärkta videon i din kamerarulle...';

  @override
  String get shareMenuBookmarks => 'Bokmärken';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count följsamlingar tillgängliga';
  }

  @override
  String get peopleListsAddToList => 'Lägg till i lista';

  @override
  String get peopleListsSheetTitle => 'Lägg till i lista';

  @override
  String get peopleListsEmptyTitle => 'Inga listor än';

  @override
  String get peopleListsEmptySubtitle =>
      'Skapa en lista för att börja gruppera personer.';

  @override
  String get peopleListsCreateList => 'Skapa lista';

  @override
  String get peopleListsNewListTitle => 'Ny lista';

  @override
  String get peopleListsRouteTitle => 'Personlista';

  @override
  String get peopleListsListNameLabel => 'Listnamn';

  @override
  String get peopleListsListNameHint => 'Nära vänner';

  @override
  String get peopleListsCreateButton => 'Skapa';

  @override
  String get peopleListsAddPeopleTitle => 'Lägg till personer';

  @override
  String get peopleListsAddPeopleTooltip => 'Lägg till personer';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Lägg till personer i listan';

  @override
  String get peopleListsListNotFoundTitle => 'Listan hittades inte';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Listan hittades inte. Den kan ha tagits bort.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Den här listan kan ha tagits bort.';

  @override
  String get peopleListsNoPeopleTitle => 'Inga personer i den här listan';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'Lägg till personer för att komma igång';

  @override
  String get peopleListsNoVideosTitle => 'Inga videor än';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Videor från listmedlemmar visas här';

  @override
  String get peopleListsNoVideosAvailable => 'Inga videor tillgängliga';

  @override
  String get peopleListsFailedToLoadVideos =>
      'Det gick inte att läsa in videor';

  @override
  String get peopleListsVideoNotAvailable => 'Video ej tillgänglig';

  @override
  String get peopleListsBackToGridTooltip => 'Tillbaka till rutnät';

  @override
  String get peopleListsErrorLoadingVideos => 'Fel vid inläsning av videor';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Inga personer tillgängliga att lägga till.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Lägg till i $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Sök personer';

  @override
  String get peopleListsAddPeopleError =>
      'Det gick inte att läsa in personer. Försök igen.';

  @override
  String get peopleListsAddPeopleRetry => 'Försök igen';

  @override
  String get peopleListsAddButton => 'Lägg till';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Lägg till $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I $count listor',
      one: 'I 1 lista',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Ta bort $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'De kommer att tas bort från den här listan.';

  @override
  String get peopleListsRemove => 'Ta bort';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name borttagen från listan';
  }

  @override
  String get peopleListsUndo => 'Ångra';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil för $name. Håll intryckt för att ta bort.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Visa profil för $name';
  }

  @override
  String get shareMenuEditVideo => 'Redigera video';

  @override
  String get shareMenuDeleteVideo => 'Ta bort video';

  @override
  String shareMenuVideoCount(int count) {
    return '$count videor';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Det här tar bort videon permanent från Divine. Den kan fortfarande visas i Nostr-klienter från tredje part som använder andra reler.';

  @override
  String get shareMenuCancel => 'Avbryt';

  @override
  String get shareMenuDelete => 'Ta bort';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Borttagningen är inte redo än. Försök igen om en stund.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Du kan bara ta bort dina egna videor.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Logga in igen och försök ta bort.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Kunde inte signera borttagningsbegäran. Försök igen.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Relät accepterade inte den här raderingsbegäran. Försök igen om en stund.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Kunde inte nå relät. Kontrollera anslutningen och försök igen.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Raderad. Alla reläer bekräftade inte, så den kan fortfarande dyka upp i andra appar.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Kunde inte ta bort den här videon. Försök igen.';

  @override
  String get shareMenuUpdate => 'Uppdatera';

  @override
  String get shareMenuChangeCover => 'Byt omslag';

  @override
  String get shareMenuVideoUpdated => 'Videon uppdaterades';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inbjudningar till medarbetare skickades inte.',
      one: '1 inbjudan till medarbetare skickades inte.',
    );
    return 'Videon uppdaterades, men $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Logga in igen och försök sedan på nytt.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Den här videon har ingen spelbar källa och kan inte redigeras.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Kunde inte signera ändringen. Försök igen.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Relät accepterade inte ändringen. Försök igen om en stund.';

  @override
  String get videoUpdateErrorGeneric =>
      'Kunde inte uppdatera videon. Försök igen.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Ta bort video?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Tar bort videon…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Videon har raderats.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Videon har tagits bort. Det kan ta en stund innan den försvinner överallt.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Videon har tagits bort, men vi kunde inte ta bort alla kopior. Kontakta supporten.';

  @override
  String get authSessionExpired => 'Din session har löpt ut. Logga in igen.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Kunde inte logga in. Försök igen.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Webbautentisering stöds inte i säkert läge. Använd mobilappen för säker nyckelhantering.';

  @override
  String get webAuthEnterBunkerUri => 'Ange en bunker-URI';

  @override
  String get webAuthConnectTitle => 'Anslut till Divine';

  @override
  String get webAuthChooseMethod =>
      'Välj din föredragna Nostr-autentiseringsmetod';

  @override
  String get webAuthBrowserExtension => 'Webbläsartillägg';

  @override
  String get webAuthRecommended => 'REKOMMENDERAS';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Anslut till en fjärrsigner';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Klistra in från urklipp';

  @override
  String get webAuthConnectToBunker => 'Anslut till bunker';

  @override
  String get webAuthNewToNostr => 'Ny på Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Installera ett webbläsartillägg som Alby eller nos2x för enklaste upplevelsen, eller använd nsec bunker för säker fjärrsignering.';

  @override
  String get soundsTitle => 'Ljud';

  @override
  String get soundsSearchHint => 'Sök ljud...';

  @override
  String get soundsSearchResults => 'Sökresultat';

  @override
  String get soundsNoSoundsFound => 'Inga ljud hittades';

  @override
  String get soundsNoSoundsFoundDescription => 'Testa en annan sökterm';

  @override
  String get soundsSavedToLibrary => 'Sparat i Ljud';

  @override
  String get soundsAlreadySavedToLibrary => 'Finns redan i Ljud';

  @override
  String get soundsSavedLibraryTitle => 'Mina ljud';

  @override
  String get soundsSavedEmptyTitle => 'Inga sparade ljud ännu';

  @override
  String get soundsSavedEmptyDescription =>
      'Tryck på Använd ljud i en video för att spara det här.';

  @override
  String get soundsRemoveSavedSound => 'Ta bort ljud';

  @override
  String get savedSoundSaveAction => 'Spara';

  @override
  String get savedSoundPausePreviewAction => 'Pausa förhandsvisningen';

  @override
  String get savedSoundResumePreviewAction => 'Återuppta förhandslyssning';

  @override
  String get savedSoundDetailsSheetTitle => 'Ljuddetaljer';

  @override
  String get savedSoundRemoveConfirmTitle => 'Ta bort det här ljudet?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Det försvinner från ditt bibliotek, men du kan spara det igen från vilken video som helst som använder det.';

  @override
  String get soundsRemovedFromLibrary => 'Borttaget från Ljud';

  @override
  String get soundsSaveFailed => 'Kunde inte spara det ljudet. Försök igen.';

  @override
  String get soundsRemoveFailed =>
      'Kunde inte ta bort det ljudet. Försök igen.';

  @override
  String get soundSyncStatusSyncing => 'Synkar dina ljud…';

  @override
  String get soundSyncStatusSynced => 'Ljuden är uppdaterade';

  @override
  String get soundSyncStatusFailed =>
      'Kunde inte synka dina ljud. Vi försöker igen.';

  @override
  String get soundSyncStatusLocked =>
      'Det går inte att låsa upp ditt synkade bibliotek på den här enheten.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMoreOptions => 'Fler alternativ';

  @override
  String profileBlockedUser(String name) {
    return 'Blockerade $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Avblockerade $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Slutade följa $name';
  }

  @override
  String get profileFeedError =>
      'Kan inte nå servern. Kontrollera din anslutning och försök igen.';

  @override
  String get profileFeedLoadMoreError =>
      'Kunde inte läsa in fler videor. Dra för att uppdatera.';

  @override
  String get notificationsTabAll => 'Alla';

  @override
  String get notificationsTabLikes => 'Gillamarkeringar';

  @override
  String get notificationsTabComments => 'Kommentarer';

  @override
  String get notificationsTabFollows => 'Följare';

  @override
  String get notificationsTabReposts => 'Återpubliceringar';

  @override
  String get notificationsFailedToLoad => 'Kunde inte läsa in aviseringar';

  @override
  String get notificationsRetry => 'Försök igen';

  @override
  String get notificationsRefreshError =>
      'Kunde inte uppdatera — visar tillgängliga';

  @override
  String get notificationsUnreadPrefix => 'Oläst avisering';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count olästa aviseringar',
      one: '1 oläst avisering',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Visa ${displayName}s profil';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Visa profiler';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Videominiatyr för $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Videominiatyr';

  @override
  String get notificationsInviteSingular =>
      'Du har 1 inbjudan att dela med en vän!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Du har $count inbjudningar att dela med vänner!';
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
  String get notificationsVideoUnavailable => 'Videon är otillgänglig';

  @override
  String get feedFailedToLoadVideos => 'Kunde inte läsa in videor';

  @override
  String get feedRetry => 'Försök igen';

  @override
  String get feedNoFollowedUsers =>
      'Inga följda användare.\nFölj någon för att se deras videor här.';

  @override
  String get feedModeForYou => 'För dig';

  @override
  String get feedModeNew => 'Nytt';

  @override
  String get feedModeFollowing => 'Följer';

  @override
  String get feedModeClassics => 'Klassiker';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Flödesläge: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Videoförfattare: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Skapares avatar';

  @override
  String get feedForYouEmpty =>
      'Ditt För dig-flöde är tomt.\nUtforska videor och följ kreatörer för att forma det.';

  @override
  String get feedFollowingEmpty =>
      'Inga videor från personer du följer än.\nHitta kreatörer du gillar och följ dem.';

  @override
  String get feedLatestEmpty => 'Inga nya videor än.\nTitta in igen snart.';

  @override
  String get feedClassicEmpty => 'Inga klassiker än.\nTitta in igen snart.';

  @override
  String get feedExploreVideos => 'Upptäck videor';

  @override
  String get feedLoadingMore => 'Läser in fler videor…';

  @override
  String get feedRefreshed => 'Flödet har uppdaterats';

  @override
  String get uploadUploadingVideo => 'Laddar upp video';

  @override
  String get postPublishConfirmationTitle => 'Publicerad till din profil';

  @override
  String get postPublishConfirmationView => 'Visa';

  @override
  String get postPublishConfirmationShare => 'Dela';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Miniatyr av videon du precis publicerade';

  @override
  String get userSearchNoResults => 'Inga användare hittades';

  @override
  String get userPickerFilterByNameHint => 'Filtrera efter namn...';

  @override
  String get userPickerSearchByNameHint => 'Sök efter namn...';

  @override
  String get userPickerClearSearchSemantics => 'Rensa sökning';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name har redan lagts till';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Välj $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Ta bort $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Ditt crew finns där ute';

  @override
  String get userPickerEmptyFollowListBody =>
      'Följ personer du vibbar med. När de följer tillbaka kan ni samarbeta.';

  @override
  String get userPickerGoBack => 'Gå tillbaka';

  @override
  String get userPickerTypeNameToSearch => 'Skriv ett namn för att söka';

  @override
  String get userPickerUnavailable =>
      'Användarsökning är inte tillgänglig. Försök igen senare.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Sökningen misslyckades. Försök igen.';

  @override
  String get forgotPasswordTitle => 'Återställ lösenord';

  @override
  String get forgotPasswordDescription =>
      'Ange din e-postadress så skickar vi en länk för att återställa ditt lösenord.';

  @override
  String get forgotPasswordEmailLabel => 'E-postadress';

  @override
  String get forgotPasswordCancel => 'Avbryt';

  @override
  String get forgotPasswordSendLink => 'E-posta återställningslänk';

  @override
  String get ageVerificationContentWarning => 'Innehållsvarning';

  @override
  String get ageVerificationTitle => 'Åldersverifiering';

  @override
  String get ageVerificationAdultDescription =>
      'Det här innehållet har flaggats som potentiellt innehållande vuxenmaterial. Du måste vara 18 eller äldre för att se det.';

  @override
  String get ageVerificationCreationDescription =>
      'För att använda kameran och skapa innehåll måste du vara minst 16 år gammal.';

  @override
  String get ageVerificationAdultQuestion => 'Är du 18 år eller äldre?';

  @override
  String get ageVerificationCreationQuestion => 'Är du 16 år eller äldre?';

  @override
  String get ageVerificationNo => 'Nej';

  @override
  String get ageVerificationYes => 'Ja';

  @override
  String get navHome => 'Hem';

  @override
  String get navExplore => 'Upptäck';

  @override
  String get navInbox => 'Inkorg';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Min profil';

  @override
  String get navNotifications => 'Aviseringar';

  @override
  String get navOpenCamera => 'Öppna kamera';

  @override
  String get navExploreClassics => 'Klassiker';

  @override
  String get navExploreNewVideos => 'Nya videor';

  @override
  String get navExploreTrending => 'Trendar';

  @override
  String get navExploreForYou => 'För dig';

  @override
  String get navExploreLists => 'Listor';

  @override
  String get routeErrorTitle => 'Fel';

  @override
  String get routeInvalidHashtag => 'Ogiltig hashtag';

  @override
  String get routeInvalidConversationId => 'Ogiltigt konversations-ID';

  @override
  String get routeInvalidRequestId => 'Ogiltigt förfrågans-ID';

  @override
  String get routeInvalidListId => 'Ogiltigt list-ID';

  @override
  String get routeInvalidUserId => 'Ogiltigt användar-ID';

  @override
  String get routeInvalidVideoId => 'Ogiltigt video-ID';

  @override
  String get routeInvalidSoundId => 'Ogiltigt ljud-ID';

  @override
  String get routeInvalidCategory => 'Ogiltig kategori';

  @override
  String get routeNoVideosToDisplay => 'Inga videor att visa';

  @override
  String get routeGoHome => 'Till startsidan';

  @override
  String get routeInvalidProfileId => 'Ogiltigt profil-ID';

  @override
  String get routeUnknownPath => 'Den sidan finns inte i appen.';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Supportcenter';

  @override
  String get supportContactSupport => 'Kontakta support';

  @override
  String get supportContactSupportSubtitle =>
      'Starta en konversation eller visa tidigare meddelanden';

  @override
  String get supportReportBug => 'Rapportera en bugg';

  @override
  String get supportReportBugSubtitle => 'Tekniska problem med appen';

  @override
  String get supportRequestFeature => 'Begär en funktion';

  @override
  String get supportRequestFeatureSubtitle =>
      'Föreslå en förbättring eller ny funktion';

  @override
  String get supportSaveLogs => 'Spara loggar';

  @override
  String get supportSaveLogsSubtitle =>
      'Exportera loggar till fil för manuell sändning';

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
  String get supportFaqSubtitle => 'Vanliga frågor och svar';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Hjälper föräldrar och tonåringar att bygga sunda vanor online';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'Så hanterar vi konton utifrån ålder';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => 'Läs om verifiering och äkthet';

  @override
  String get supportLoginRequired => 'Logga in för att kontakta supporten';

  @override
  String get supportExportingLogs => 'Exporterar loggar...';

  @override
  String get supportExportLogsFailed => 'Kunde inte exportera loggar';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Loggar sparade i $path';
  }

  @override
  String get supportRevealLogsAction => 'Visa i mapp';

  @override
  String get supportChatNotAvailable => 'Supportchatten är inte tillgänglig';

  @override
  String get supportCouldNotOpenMessages =>
      'Kunde inte öppna supportmeddelanden';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Kunde inte öppna $pageName';
  }

  @override
  String get reportWhyReporting => 'Varför rapporterar du det här innehållet?';

  @override
  String get reportPolicyNotice =>
      'Divine agerar på innehållsrapporter inom 24 timmar genom att ta bort innehållet och stänga av användaren som tillhandahöll det felaktiga innehållet.';

  @override
  String get reportBlockUser => 'Blockera den här användaren';

  @override
  String get reportCancel => 'Avbryt';

  @override
  String get reportSubmit => 'Rapportera';

  @override
  String get reportSelectReason =>
      'Välj en anledning för att rapportera det här innehållet';

  @override
  String get reportOtherRequiresDetails =>
      'Beskriv problemet när du väljer Övrigt';

  @override
  String get reportDetailsRequired => 'Beskriv problemet';

  @override
  String get reportDetailsTextOnly =>
      'Endast text – foton och GIF-bilder kan inte bifogas här.';

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
  String get reportReasonSpam => 'Skräppost eller ovälkommet innehåll';

  @override
  String get reportReasonSpamSubtitle => 'Oönskat eller repetitivt innehåll';

  @override
  String get reportReasonHarassment => 'Trakasserier, mobbning eller hot';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Skadliga och oönskade svar eller omnämnanden';

  @override
  String get reportReasonViolence => 'Våldsamt eller extremistiskt innehåll';

  @override
  String get reportReasonViolenceSubtitle =>
      'Våldsamt, extremistiskt eller skadligt innehåll';

  @override
  String get reportReasonSexualContent => 'Sexuellt eller vuxeninnehåll';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nakenhet, porr eller explicit innehåll';

  @override
  String get reportReasonCopyright => 'Upphovsrättsbrott';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Otillåten användning av immateriella rättigheter';

  @override
  String get reportReasonFalseInfo => 'Felaktig information';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Vilseledande eller falska påståenden';

  @override
  String get reportReasonChildSafety => 'Brott mot barns säkerhet';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Allmänna farhågor om minderårigas säkerhet';

  @override
  String get reportReasonCsam => 'Sexuella övergrepp mot barn';

  @override
  String get reportReasonCsamSubtitle =>
      'Innehåll som skildrar sexuella övergrepp mot minderåriga';

  @override
  String get reportReasonUnderageUser => 'Användaren verkar vara under 16';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Kontoinnehavaren verkar vara minderårig';

  @override
  String get reportReasonAiGenerated => 'AI-genererat innehåll';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Misstänkt AI-genererat innehåll';

  @override
  String get reportReasonOther => 'Annat policybrott';

  @override
  String get reportReasonOtherSubtitle => 'Överträdelser som inte listas ovan';

  @override
  String get reportFailed => 'Kunde inte rapportera innehåll. Försök igen.';

  @override
  String get reportNotSent =>
      'Kunde inte skicka din anmälan. Kontrollera din anslutning och försök igen.';

  @override
  String get reportReceivedTitle => 'Rapport mottagen';

  @override
  String get reportReceivedThankYou =>
      'Tack för att du hjälper till att hålla Divine säkert.';

  @override
  String get reportReceivedReviewNotice =>
      'Vårt team granskar din rapport och vidtar lämpliga åtgärder. Du kan få uppdateringar via direktmeddelande.';

  @override
  String get reportModerationDmDelayed =>
      'Vi kunde inte nå modereringsteamet direkt just nu, men din anmälan togs emot och kommer att granskas.';

  @override
  String get reportContactModeration => 'Meddela modereringsteamet';

  @override
  String get reportLearnMoreAt => 'Läs mer på';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Stäng';

  @override
  String get listAddToList => 'Lägg till i lista';

  @override
  String listVideoCount(int count) {
    return '$count videor';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Av ';

  @override
  String get listNewList => 'Ny lista';

  @override
  String get listDone => 'Klar';

  @override
  String get listErrorLoading => 'Fel vid inläsning av listor';

  @override
  String listRemovedFrom(String name) {
    return 'Borttagen från $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Tillagd i $name';
  }

  @override
  String get listCreateNewList => 'Skapa ny lista';

  @override
  String get listNewPeopleList => 'Ny personlista';

  @override
  String get listCollaboratorsNone => 'Inga';

  @override
  String get listAddCollaboratorTitle => 'Lägg till medarbetare';

  @override
  String get listCollaboratorSearchHint => 'Sök i Divine...';

  @override
  String get listNameLabel => 'Listnamn';

  @override
  String get listDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String get listPublicList => 'Publik lista';

  @override
  String get listPublicListSubtitle => 'Andra kan följa och se den här listan';

  @override
  String get listPrivateListSubtitle =>
      'Videorna förblir privata. Namn, beskrivning, taggar och omslag förblir synliga.';

  @override
  String get listVisibilityPublic => 'Offentlig';

  @override
  String get listVisibilityPrivate => 'Privat';

  @override
  String get profileListsEmpty =>
      'Inga listor än. Skapa en för looparna du vill hålla ihop.';

  @override
  String get listEditTitle => 'Redigera lista';

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
  String get listShareAction => 'Dela lista';

  @override
  String get listShareFailed => 'Kunde inte dela listan. Försök igen.';

  @override
  String get listSave => 'Spara';

  @override
  String get listContinue => 'Fortsätt';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => 'Kunde inte uppdatera listan. Försök igen.';

  @override
  String get listMakePrivateTitle => 'Göra listan privat?';

  @override
  String get listMakePrivateWarning =>
      'Videorna krypteras så att bara du kan se dem. Namn, beskrivning, taggar och omslag förblir synliga, och redan delade kopior kan finnas kvar.';

  @override
  String get listMakePublicTitle => 'Göra listan offentlig?';

  @override
  String get listMakePublicWarning =>
      'Alla med länken kan se listan och dess videor.';

  @override
  String listShareText(String name, String url) {
    return 'Kolla in $name på Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name på Divine';
  }

  @override
  String get listCancel => 'Avbryt';

  @override
  String get listCreate => 'Skapa';

  @override
  String get listCreateFailed => 'Kunde inte skapa listan';

  @override
  String get keyManagementTitle => 'Nostr-nycklar';

  @override
  String get keyManagementWhatAreKeys => 'Vad är Nostr-nycklar?';

  @override
  String get keyManagementExplanation =>
      'Din Nostr-identitet är ett kryptografiskt nyckelpar:\n\n• Din publika nyckel (npub) är som ditt användarnamn – dela den fritt\n• Din privata nyckel (nsec) är som ditt lösenord – håll den hemlig!\n\nDin nsec låter dig nå ditt konto i vilken Nostr-app som helst.';

  @override
  String get keyManagementImportTitle => 'Importera befintlig nyckel';

  @override
  String get keyManagementImportSubtitle =>
      'Har du redan ett Nostr-konto? Klistra in din privata nyckel (nsec) för att nå det här.';

  @override
  String get keyManagementImportButton => 'Importera nyckel';

  @override
  String get keyManagementImportWarning =>
      'Detta ersätter din nuvarande nyckel!';

  @override
  String get keyManagementBackupTitle => 'Säkerhetskopiera din nyckel';

  @override
  String get keyManagementBackupSubtitle =>
      'Spara din privata nyckel (nsec) för att använda ditt konto i andra Nostr-appar.';

  @override
  String get keyManagementCopyNsec => 'Kopiera min privata nyckel (nsec)';

  @override
  String get keyManagementNeverShare => 'Dela aldrig din nsec med någon!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Din nyckel finns hos Divines inloggningstjänst, inte på den här enheten. Bekräfta ditt lösenord så hämtar vi den.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Din nyckel förvaras av Divines inloggningstjänst. Ange kontots lösenord så hämtar vi den.';

  @override
  String get keyManagementKeycastCopyKey => 'Kopiera nyckel';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Din enhet blockerade kopieringen, så din nyckel hamnade inte i urklipp.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Lösenordet stämmer inte. Försök igen.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'För många försök. Stäng det här och börja om.';

  @override
  String get keyManagementKeycastRateLimited =>
      'För många nyckelförfrågningar. Vänta några minuter och försök igen.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Din session har gått ut. Logga in igen för att kopiera nyckeln.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Bekräfta din e-postadress innan du kopierar nyckeln.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine sköter nycklarna för det här kontot, så de kan inte kopieras här.';

  @override
  String get keyManagementKeycastNoKey =>
      'Det finns ingen nyckel registrerad för det här kontot.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Inloggningstjänsten kunde inte nås. Försök igen.';

  @override
  String get keyManagementRestrictedTitle => 'Dina nycklar hanteras av Divine';

  @override
  String get keyManagementRestrictedBody =>
      'För att hålla ditt konto säkert går det inte att säkerhetskopiera nyckeln eller importera en annan nyckel här.';

  @override
  String get keyManagementPasteKey => 'Klistra in din privata nyckel';

  @override
  String get keyManagementInvalidFormat =>
      'Ogiltigt nyckelformat. Måste börja med \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importera den här nyckeln?';

  @override
  String get keyManagementConfirmImportBody =>
      'Detta ersätter din nuvarande identitet med den importerade.\n\nDin nuvarande nyckel går förlorad om du inte säkerhetskopierade den först.';

  @override
  String get keyManagementImportConfirm => 'Importera';

  @override
  String get keyManagementImportSuccess => 'Nyckeln importerades!';

  @override
  String get keyManagementImportFailed =>
      'Kunde inte importera nyckeln. Försök igen.';

  @override
  String get keyManagementExportSuccess =>
      'Privat nyckel kopierad till urklipp!\n\nFörvara den på ett säkert ställe.';

  @override
  String get keyManagementExportFailed =>
      'Kunde inte exportera nyckeln. Försök igen.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Din publika nyckel (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Kopiera publik nyckel';

  @override
  String get keyManagementPublicKeyCopied => 'Publik nyckel kopierad';

  @override
  String get saveOriginalSavedToCameraRoll => 'Sparad i kamerarullen';

  @override
  String get saveOriginalShare => 'Dela';

  @override
  String get saveOriginalDone => 'Klar';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Fotoåtkomst behövs';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'För att spara videor, tillåt fotoåtkomst i Inställningar.';

  @override
  String get saveOriginalOpenSettings => 'Öppna inställningar';

  @override
  String get saveOriginalNotNow => 'Inte nu';

  @override
  String get saveOriginalDownloadFailed => 'Nedladdning misslyckades';

  @override
  String get saveOriginalDismiss => 'Avfärda';

  @override
  String get saveOriginalDownloadingVideo => 'Laddar ner video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Sparar i kamerarullen';

  @override
  String get saveOriginalFetchingVideo => 'Hämtar videon från nätverket...';

  @override
  String get saveOriginalSavingVideo =>
      'Sparar originalvideon i din kamerarulle...';

  @override
  String get soundTitle => 'Ljud';

  @override
  String get soundOriginalSound => 'Originalljud';

  @override
  String get soundVideosUsingThisSound => 'Videor som använder det här ljudet';

  @override
  String get soundSourceVideo => 'Källvideo';

  @override
  String get soundNoVideosYet => 'Inga videor än';

  @override
  String get soundBeFirstToUse => 'Var först med att använda det här ljudet!';

  @override
  String get soundFailedToLoadVideos => 'Kunde inte läsa in videor';

  @override
  String get soundRetry => 'Försök igen';

  @override
  String get soundVideosUnavailable => 'Videor otillgängliga';

  @override
  String get soundCouldNotLoadDetails => 'Kunde inte läsa in videodetaljer';

  @override
  String get soundPreview => 'Förhandsvisning';

  @override
  String get soundStop => 'Stoppa';

  @override
  String get soundUseSound => 'Använd ljud';

  @override
  String get soundUntitled => 'Namnlöst ljud';

  @override
  String get soundStopPreview => 'Stoppa förhandsvisning';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Förhandsvisa $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Visa detaljer för $title';
  }

  @override
  String get soundNoVideoCount => 'Inga videor än';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count videor';
  }

  @override
  String get soundUnableToPreview =>
      'Kan inte förhandsvisa ljud – inget ljud tillgängligt';

  @override
  String get soundPreviewFailed =>
      'Kunde inte spela förhandsvisning. Försök igen.';

  @override
  String get soundViewSource => 'Visa källa';

  @override
  String get soundCloseTooltip => 'Stäng';

  @override
  String get exploreNotExploreRoute => 'Inte en upptäcktsrutt';

  @override
  String get legalTitle => 'Juridik';

  @override
  String get legalTermsOfService => 'Användarvillkor';

  @override
  String get legalTermsOfServiceSubtitle => 'Användningsvillkor';

  @override
  String get legalPrivacyPolicy => 'Integritetspolicy';

  @override
  String get legalPrivacyPolicySubtitle => 'Hur vi hanterar dina data';

  @override
  String get legalSafetyStandards => 'Säkerhetsstandarder';

  @override
  String get legalSafetyStandardsSubtitle => 'Communityriktlinjer och säkerhet';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Upphovsrätt och borttagningspolicy';

  @override
  String get legalOpenSourceLicenses => 'Öppen källkod-licenser';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Tillskrivningar till tredjepartspaket';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Kunde inte öppna $pageName';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Äventyr';

  @override
  String get categoryAnimals => 'Djur';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Arkitektur';

  @override
  String get categoryArt => 'Konst';

  @override
  String get categoryAutomotive => 'Bilar';

  @override
  String get categoryAwardShow => 'Prisutdelning';

  @override
  String get categoryAwards => 'Priser';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basket';

  @override
  String get categoryBeauty => 'Skönhet';

  @override
  String get categoryBeverage => 'Dryck';

  @override
  String get categoryCars => 'Bilar';

  @override
  String get categoryCelebration => 'Firande';

  @override
  String get categoryCelebrities => 'Kändisar';

  @override
  String get categoryCelebrity => 'Kändis';

  @override
  String get categoryCityscape => 'Stadsbild';

  @override
  String get categoryComedy => 'Komedi';

  @override
  String get categoryConcert => 'Konsert';

  @override
  String get categoryCooking => 'Matlagning';

  @override
  String get categoryCostume => 'Kostym';

  @override
  String get categoryCrafts => 'Hantverk';

  @override
  String get categoryCrime => 'Brott';

  @override
  String get categoryCulture => 'Kultur';

  @override
  String get categoryDance => 'Dans';

  @override
  String get categoryDiy => 'Gör det själv';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Utbildning';

  @override
  String get categoryEmotional => 'Känslosam';

  @override
  String get categoryEmotions => 'Känslor';

  @override
  String get categoryEntertainment => 'Underhållning';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryFamily => 'Familj';

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
  String get categoryFitness => 'Träning';

  @override
  String get categoryFood => 'Mat';

  @override
  String get categoryFootball => 'Amerikansk fotboll';

  @override
  String get categoryFurniture => 'Möbler';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Skötsel';

  @override
  String get categoryGuitar => 'Gitarr';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Hälsa';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Semester';

  @override
  String get categoryHome => 'Hem';

  @override
  String get categoryHomeImprovement => 'Renovering';

  @override
  String get categoryHorror => 'Skräck';

  @override
  String get categoryHospital => 'Sjukhus';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Inredning';

  @override
  String get categoryInterview => 'Intervju';

  @override
  String get categoryKids => 'Barn';

  @override
  String get categoryLifestyle => 'Livsstil';

  @override
  String get categoryMagic => 'Magi';

  @override
  String get categoryMakeup => 'Smink';

  @override
  String get categoryMedical => 'Medicin';

  @override
  String get categoryMusic => 'Musik';

  @override
  String get categoryMystery => 'Mysterium';

  @override
  String get categoryNature => 'Natur';

  @override
  String get categoryNews => 'Nyheter';

  @override
  String get categoryOutdoor => 'Utomhus';

  @override
  String get categoryParty => 'Fest';

  @override
  String get categoryPeople => 'Människor';

  @override
  String get categoryPerformance => 'Uppträdande';

  @override
  String get categoryPets => 'Husdjur';

  @override
  String get categoryPolitics => 'Politik';

  @override
  String get categoryPrank => 'Skämt';

  @override
  String get categoryPranks => 'Skämt';

  @override
  String get categoryRealityShow => 'Reality-show';

  @override
  String get categoryRelationship => 'Relation';

  @override
  String get categoryRelationships => 'Relationer';

  @override
  String get categoryRomance => 'Romantik';

  @override
  String get categorySchool => 'Skola';

  @override
  String get categoryScienceFiction => 'Science fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboard';

  @override
  String get categorySkincare => 'Hudvård';

  @override
  String get categorySoccer => 'Fotboll';

  @override
  String get categorySocialGathering => 'Sammankomst';

  @override
  String get categorySocialMedia => 'Sociala medier';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talkshow';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Teknologi';

  @override
  String get categoryTelevision => 'TV';

  @override
  String get categoryToys => 'Leksaker';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Resor';

  @override
  String get categoryUrban => 'Urbant';

  @override
  String get categoryViolence => 'Våld';

  @override
  String get categoryVlog => 'Vlogg';

  @override
  String get categoryVlogging => 'Vloggning';

  @override
  String get categoryWrestling => 'Brottning';

  @override
  String get profileSetupUploadStaged =>
      'Uppladdad — tryck på Spara för att tillämpa';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName rapporterad';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName blockerad';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName avblockerad';
  }

  @override
  String get inboxRemovedConversation => 'Konversation borttagen';

  @override
  String get inboxRestorePausedTitle =>
      'Vissa chattar har inte återställts klart';

  @override
  String get conversationRestorePausedTitle =>
      'Den här chatten har inte återställts klart';

  @override
  String get inboxRestoreRetryAction => 'Försök igen';

  @override
  String get inboxRestoringMessages => 'Återställer dina meddelanden…';

  @override
  String get inboxEmptyTitle => 'Inga meddelanden än';

  @override
  String get inboxEmptySubtitle => '+-knappen bits inte.';

  @override
  String get inboxLoadErrorTitle => 'Meddelandena kunde inte laddas';

  @override
  String get inboxLoadErrorSubtitle => 'Kolla din anslutning och försök igen.';

  @override
  String get inboxFilterAll => 'Alla';

  @override
  String get inboxFilterUnread => 'Olästa';

  @override
  String get dmBlockedThreadTitle => 'Du blockerade det här kontot';

  @override
  String get dmBlockedThreadBody =>
      'Meddelandena stannar kvar så att du kan läsa dem eller ta en skärmbild. Häv blockeringen för att svara.';

  @override
  String get inboxFilterBlocked => 'Blockerade';

  @override
  String get inboxBlockedEmptyTitle => 'Inga blockerade chattar';

  @override
  String get inboxBlockedEmptySubtitle => 'Konton du blockerar visas här.';

  @override
  String get inboxBlockedNoMessages => 'Inga meddelanden';

  @override
  String get inboxUnreadEmptyTitle => 'Du är helt ikapp';

  @override
  String get inboxUnreadEmptySubtitle => 'Inga olästa meddelanden just nu.';

  @override
  String get inboxSearchHint => 'Sök meddelanden';

  @override
  String get inboxSupportRowTitle => 'Divine-moderering';

  @override
  String get inboxSupportRowSubtitle =>
      'Buggar, moderering, kontofrågor – vi lyssnar.';

  @override
  String get inboxSearchEmptyTitle => 'Inga träffar';

  @override
  String get inboxSearchEmptySubtitle => 'Prova ett annat namn eller ord.';

  @override
  String get inboxActionMute => 'Tysta konversation';

  @override
  String inboxActionReport(String displayName) {
    return 'Rapportera $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Blockera $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Avblockera $displayName';
  }

  @override
  String get inboxActionRemove => 'Ta bort konversation';

  @override
  String get inboxRemoveConfirmTitle => 'Ta bort konversation?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Det här tar bort din konversation med $displayName från din inkorg. Om personen skriver till dig igen startar en ny konversation.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Det här tar bort gruppkonversationen från din inkorg. Om någon skriver i gruppen igen startar en ny konversation.';

  @override
  String get inboxRemoveConfirmConfirm => 'Ta bort';

  @override
  String get inboxConversationMuted => 'Konversation tystad';

  @override
  String get inboxConversationUnmuted => 'Konversation inte tystad';

  @override
  String get inboxCollabInviteCardTitle => 'Inbjudan att samarbeta';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video utan titel';

  @override
  String get clickableTextViewVideoLink => 'Visa video';

  @override
  String get messageExternalLinkDialogTitle => 'Öppna extern länk?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Den här länken går till en extern webbplats och kanske inte är säker:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Öppna';

  @override
  String get inboxCollabInviteCoPostButton => 'Sampublicera';

  @override
  String get inboxCollabInviteNotMineButton => 'Inte min';

  @override
  String get inboxCollabInvitePreviewTitle => 'Inbjudan att sampublicera';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Inbjudan att sampublicera från $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Sampublicering lägger till den här videon på din tidslinje som ett samarbete.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Accepterad';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorerad';

  @override
  String get inboxCollabInviteAcceptError =>
      'Det gick inte att acceptera. Försök igen.';

  @override
  String get inboxCollabInviteSentStatus => 'Inbjudan skickad';

  @override
  String get inboxConversationCollabInvitePreview => 'Inbjudan att samarbeta';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Du har bjudits in att samarbeta på $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Du har bjudits in att samarbeta på en video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetsinbjudningar skickades inte.',
      one: '1 samarbetsinbjudan skickades inte.',
    );
    return 'Videon publicerades, men $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Vi kunde inte se vem den här konversationen är med. Öppna den igen från inkorgen.';

  @override
  String get dmSendBlockedMessage =>
      'Du kan bara skicka meddelanden till officiella Divine-konton';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Ingen läser den här konversationen. Skriv till Divine Moderation i stället.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Det gick inte att radera för alla.';

  @override
  String get dmDeleteRefusedDetails =>
      'Vissa personer kan fortfarande se det här meddelandet.';

  @override
  String get dmRetiredThreadClosedTitle => 'Den här konversationen är stängd.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Det här meddelandet från Divine Moderation kan inte tas bort.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Vi har flyttat Divine Moderation till ett nytt konto. Det här kontot läser ingen längre.';

  @override
  String get dmRetiredThreadOpenSupport => 'Skriv till Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Meddelandet kunde inte skickas';

  @override
  String get dmResendFailedMessage => 'Kunde fortfarande inte skickas';

  @override
  String get dmSendFailedSubtitle => 'Skicka det igen nu, eller sluta försöka.';

  @override
  String get dmSendFailedRetry => 'Försök igen';

  @override
  String get dmSendPartialMessage =>
      'Skickat, men inte synkat till dina andra enheter';

  @override
  String get dmConversationLoadError =>
      'Det gick inte att läsa in meddelandena';

  @override
  String get dmMessageInputHint => 'Säg något…';

  @override
  String get dmMessageBubbleSentHint => 'Skickat meddelande';

  @override
  String get dmMessageBubbleReceivedHint => 'Mottaget meddelande';

  @override
  String get dmMessageBubbleLongPressHint => 'Meddelandeåtgärder';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Skicka om eller radera det här meddelandet';

  @override
  String get dmMessageActionCopyText => 'Kopiera text';

  @override
  String get dmMessageActionCopyVideoUrl => 'Kopiera video-URL';

  @override
  String get dmMessageActionDeleteForEveryone => 'Ta bort för alla';

  @override
  String get dmMessageActionReport => 'Rapportera';

  @override
  String get dmMessageActionRetrySend => 'Skicka igen';

  @override
  String get dmMessageActionCancelSend => 'Sluta försöka';

  @override
  String get dmReactionAddCustomA11yLabel => 'Lägg till egen emojireaktion';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Meddela $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Svara dig själv…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Svara på den här reelen';

  @override
  String get dmReelReplyViewChat => 'Visa chatt';

  @override
  String get dmReelReplySentAnnouncement => 'Svar skickat';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Reagerade $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Det gick inte att skicka';

  @override
  String get dmReelReplyUnverified =>
      'Det gick inte att bekräfta att det skickades';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Din reaktion: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name reagerade med $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Skickar reaktion: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reaktionen misslyckades, dubbeltryck för att försöka igen';

  @override
  String get dmReactionChipRetryAnnouncement => 'Försöker med reaktionen igen';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Slutför borttagningen av din tidigare reaktion innan du lägger till en ny.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reaktioner';

  @override
  String get dmReactionsViewA11yLabel => 'Se vilka som reagerat';

  @override
  String get dmReactionRemoveAction => 'Ta bort';

  @override
  String get dmReactionRetryAction => 'Försök igen';

  @override
  String get dmFormatBold => 'Fet';

  @override
  String get dmFormatItalic => 'Kursiv';

  @override
  String get dmFormatStrikethrough => 'Genomstruken';

  @override
  String get dmFormatCode => 'Kod';

  @override
  String get dmStatusFailed => 'Kunde inte skicka';

  @override
  String get inboxConversationActionsSheetLabel => 'Konversationsåtgärder';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Konversation med $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Oläst, konversation med $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count till',
    );
    return '$name och $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Visa konversationsåtgärder';

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
  String get exploreSearchHint => 'Sök...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count videor';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Kunde inte uppdatera prenumerationen. Försök igen.';

  @override
  String get discoverListsTitle => 'Upptäck listor';

  @override
  String get discoverListsFailedToLoad => 'Kunde inte ladda listor';

  @override
  String get discoverListsLoading => 'Söker upp publika listor...';

  @override
  String get discoverListsRelayTimeout =>
      'Relayen returnerade inga listor i tid. Försök igen.';

  @override
  String get discoverListsServiceUnavailable => 'Tjänsten är inte tillgänglig.';

  @override
  String get discoverListsEmptyTitle => 'Inga publika listor hittades';

  @override
  String get discoverListsEmptySubtitle => 'Kom tillbaka senare för nya listor';

  @override
  String get discoverListsByAuthorPrefix => 'av';

  @override
  String get curatedListEmptyTitle => 'Inga videor i den här listan';

  @override
  String get curatedListEmptySubtitle =>
      'Lägg till några videor för att komma igång';

  @override
  String get curatedListLoadingVideos => 'Laddar videor...';

  @override
  String get curatedListFailedToLoad => 'Kunde inte ladda listan';

  @override
  String get curatedListVideoNotAvailable => 'Video inte tillgänglig';

  @override
  String get curatedListActionsTooltip => 'Liståtgärder';

  @override
  String get curatedListDeleteConfirmTitle => 'Ta bort lista?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Detta tar bort listan från relerna. Videorna i listan tas inte bort.';

  @override
  String get curatedListDeletedSnack => 'Listan borttagen';

  @override
  String get curatedListDeleteFailed => 'Kunde inte ta bort listan';

  @override
  String get peopleListsActionsTooltip => 'Liståtgärder';

  @override
  String get listDeleteAction => 'Ta bort lista';

  @override
  String get peopleListsDeleteConfirmTitle => 'Ta bort lista?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Detta tar bort listan för alla. Personerna i den slutar du inte följa.';

  @override
  String get peopleListsDeleteFailed => 'Kunde inte ta bort listan';

  @override
  String get commonRetry => 'Försök igen';

  @override
  String get commonSomethingWentWrong => 'Något gick fel';

  @override
  String get commonDelete => 'Radera';

  @override
  String get commonCancel => 'Avbryt';

  @override
  String get commonBack => 'Tillbaka';

  @override
  String get commonClose => 'Stäng';

  @override
  String get commonNotNow => 'Inte nu';

  @override
  String get commonLoading => 'Läser in';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Det gick inte att uppdatera omslaget. Försök igen.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Omslag uppdaterat';

  @override
  String get videoMetadataC2paMissingTitle => 'Publicera utan äkthetskontroll?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Vi kunde inte lägga till innehållsuppgifter, så den här videon bekräftas inte som gjord av människa. Generera om för att försöka igen, eller publicera som den är.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Innehållsuppgifter kräver en internetanslutning.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Tjänsten för innehållsintyg svarade inte. Det beror inte på din anslutning.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Generera om';

  @override
  String get videoMetadataC2paMissingSkip => 'Hoppa över';

  @override
  String get videoMetadataGenerationFailed => 'Genereringen misslyckades';

  @override
  String get videoMetadataTags => 'Taggar';

  @override
  String get videoMetadataExpiration => 'Utgångsdatum';

  @override
  String get videoMetadataExpirationNotExpire => 'Löper inte ut';

  @override
  String get videoMetadataExpirationOneDay => '1 dag';

  @override
  String get videoMetadataExpirationOneWeek => '1 vecka';

  @override
  String get videoMetadataExpirationOneMonth => '1 månad';

  @override
  String get videoMetadataExpirationOneYear => '1 år';

  @override
  String get videoMetadataExpirationOneDecade => '1 decennium';

  @override
  String get videoMetadataContentWarnings => 'Innehållsvarningar';

  @override
  String get videoEditorStickers => 'Klistermärken';

  @override
  String get trendingTitle => 'Trendande';

  @override
  String get libraryDeleteConfirm => 'Radera';

  @override
  String get libraryWebUnavailableHeadline => 'Biblioteket finns i mobilappen';

  @override
  String get libraryWebUnavailableDescription =>
      'Utkast och klipp sparas på enheten — öppna Divine i mobilen för att hantera dem.';

  @override
  String get libraryTabDrafts => 'Utkast';

  @override
  String get libraryTabClips => 'Klipp';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Ta bort valda klipp';

  @override
  String get libraryCloseSemanticLabel => 'Stäng biblioteket';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Sluta välja klipp';

  @override
  String get librarySelectClipsSemanticLabel => 'Välj klipp';

  @override
  String get libraryGridSizeLabel => 'Rutnätets storlek';

  @override
  String get libraryDisplayOptionsLabel => 'Sortering och rutnätsstorlek';

  @override
  String get libraryMoreActionsSemanticLabel => 'Fler biblioteksåtgärder';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolumner',
      one: '1 kolumn',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Välj';

  @override
  String get librarySortNewestCreation => 'Senast skapade';

  @override
  String get librarySortOldestCreation => 'Äldst skapade';

  @override
  String get librarySortLongestClip => 'Längsta klipp';

  @override
  String get librarySortShortestClip => 'Kortaste klipp';

  @override
  String get librarySortSquareFirst => 'Kvadratiska först';

  @override
  String get librarySortVerticalFirst => 'Vertikala först';

  @override
  String get libraryDeleteClipsWarning =>
      'Det går inte att ångra. Videofilerna tas bort permanent från enheten.';

  @override
  String get libraryPreparingVideo => 'Förbereder video...';

  @override
  String libraryCreateVideo(int count) {
    return 'Skapa video ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp',
      one: '1 klipp',
    );
    return '$_temp0 sparade i $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount sparade, $failureCount misslyckades';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Det gick inte att spara till $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Behörighet nekad för $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp borttagna',
      one: '1 klipp borttaget',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Ångra';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Raderas automatiskt om $daysLeft dagar',
      one: 'Raderas automatiskt i morgon',
      zero: 'Raderas automatiskt i dag',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Det gick inte att ladda utkast';

  @override
  String get libraryCouldNotLoadClips => 'Det gick inte att ladda klipp';

  @override
  String get libraryOpenErrorDescription =>
      'Något gick fel när biblioteket öppnades. Försök igen.';

  @override
  String get libraryNoDraftsYetTitle => 'Inga utkast än';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Videor du sparar som utkast visas här';

  @override
  String get libraryNoClipsYetTitle => 'Inga klipp än';

  @override
  String get libraryNoClipsYetSubtitle => 'Dina inspelade videoklipp visas här';

  @override
  String get libraryDraftDeletedSnackbar => 'Utkast borttaget';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Det gick inte att ta bort utkastet';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Utkast duplicerat';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Det gick inte att duplicera utkastet';

  @override
  String get libraryDraftInProgressBadge => 'Pågår';

  @override
  String get libraryDraftActionPost => 'Publicera';

  @override
  String get libraryDraftActionEdit => 'Redigera';

  @override
  String get libraryDraftActionDuplicate => 'Duplicera';

  @override
  String get libraryDraftActionDelete => 'Ta bort utkast';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (kopia $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Ta bort utkast';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Vill du ta bort \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Ta bort klipp';

  @override
  String get libraryDeleteClipMessage => 'Vill du ta bort det här klippet?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds s';
  }

  @override
  String get libraryRecordVideo => 'Spela in video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Videoklipp, $duration sekunder';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Arkiverad. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Stop motion-klipp, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Valt, nummer $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Valt';

  @override
  String get videoClipSemanticValueNotSelected => 'Inte valt';

  @override
  String get videoClipSemanticHintDisabled => 'Inaktiverat';

  @override
  String get videoClipSemanticHintSelect =>
      'Tryck för att välja, håll för förhandsgranskning';

  @override
  String get videoClipSemanticHintDeselect =>
      'Tryck för att avmarkera, håll för förhandsgranskning';

  @override
  String get routerInvalidCreator => 'Ogiltig skapare';

  @override
  String get routerInvalidHashtagRoute => 'Ogiltig hashtagrutt';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Kunde inte ladda videor';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Inga videor i den här kategorin';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Sorteringsalternativ för kategori';

  @override
  String get categoryGallerySortHot => 'Hett';

  @override
  String get categoryGallerySortNew => 'Nytt';

  @override
  String get categoryGallerySortClassic => 'Klassiskt';

  @override
  String get categoryGallerySortForYou => 'För dig';

  @override
  String get categoriesCouldNotLoadCategories => 'Kunde inte ladda kategorier';

  @override
  String get categoriesNoCategoriesAvailable => 'Inga kategorier tillgängliga';

  @override
  String get notificationsEmptyTitle => 'Ingen aktivitet än';

  @override
  String get notificationsEmptySubtitle =>
      'När folk interagerar med ditt innehåll dyker det upp här';

  @override
  String get appsPermissionsTitle => 'Integrationsbehörigheter';

  @override
  String get appsPermissionsRevoke => 'Återkalla';

  @override
  String get appsPermissionsEmptyTitle =>
      'Inga sparade integrationsbehörigheter';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Godkända integrationer dyker upp här efter att du sparat ett åtkomstgodkännande.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName vill ha ditt godkännande';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Den här appen begär åtkomst genom Divines granskade sandlåda.';

  @override
  String get nostrAppPermissionOrigin => 'Ursprung';

  @override
  String get nostrAppPermissionMethod => 'Metod';

  @override
  String get nostrAppPermissionCapability => 'Funktion';

  @override
  String get nostrAppPermissionEventKind => 'Händelsetyp';

  @override
  String get nostrAppPermissionAllow => 'Tillåt';

  @override
  String get appsDetailDefaultTitle => 'Integrerad app';

  @override
  String get appsDetailNotFoundTitle => 'Integrationen hittades inte';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Den här godkända integrationen är inte längre tillgänglig i Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Så fungerar det';

  @override
  String get appsDetailHowItWorksBody =>
      'Detta är en godkänd tredjepartsapp som körs inuti Divine. Divine beviljar bara granskade funktioner för den här integrationen och blockerar navigering utanför dess godkända ursprung.';

  @override
  String get appsDetailAboutTitle => 'Om';

  @override
  String get appsDetailPrimaryOriginTitle => 'Primärt ursprung';

  @override
  String get appsDetailApprovedOriginsTitle => 'Godkända ursprung';

  @override
  String get appsDetailCapabilitiesTitle => 'Tillgängliga funktioner';

  @override
  String get appsDetailAskBeforeTitle => 'Fråga innan';

  @override
  String get appsDetailOpenButton => 'Öppna integration';

  @override
  String get appsDetailNoneDeclared => 'Inga deklarerade än';

  @override
  String get appsDirectoryTitle => 'Integrerade appar';

  @override
  String get appsDirectoryIntroTitle => 'Godkända tredjepartsappar';

  @override
  String get appsDirectoryIntroBody =>
      'Godkända tredjepartsappar som körs inuti Divine';

  @override
  String get appsDirectoryErrorTitle => 'Kunde inte läsa in integrerade appar';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Dra för att försöka med de godkända integrationerna igen.';

  @override
  String get appsDirectoryEmptyTitle => 'Inga godkända integrationer än';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Godkända tredjepartsappar dyker upp här när Divine lägger till dem.';

  @override
  String get appsDirectoryRefresh => 'Uppdatera';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Integrerade appar körs i Divine mobil';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Godkända integrationer är bara tillgängliga på mobil för tillfället.';

  @override
  String get appsSandboxUnavailableTitle => 'Integrationen är inte tillgänglig';

  @override
  String get appsSandboxUnavailableBody =>
      'Öppna godkända integrationer från fliken Integrerade appar så att Divine kan tillämpa rätt åtkomstpolicy.';

  @override
  String get appsSandboxLoadingTitle => 'Läser in integration';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Kontrollerar den godkända integrationen innan start.';

  @override
  String get appsSandboxBlockedTitle => 'Blockerad av säkerhetsskäl';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Den här integrationen försökte lämna sitt godkända ursprung.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Länk till inlägget kopierad till urklipp';

  @override
  String get shareCopiedEventJson =>
      'Nostr-händelsens JSON kopierad till urklipp';

  @override
  String get shareCopiedEventId => 'Nostr-händelsens ID kopierat till urklipp';

  @override
  String get authHeroTaglineAuthentic => 'Äkta ögonblick.';

  @override
  String get authHeroTaglineHuman => 'Mänsklig kreativitet.';

  @override
  String get keyImportFailedToImport =>
      'Kunde inte importera nyckel eller ansluta bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'Ogiltig bunker-URL';

  @override
  String get keyImportInvalidFormat =>
      'Ogiltigt format. Använd nsec..., hex, ncryptsec1... eller bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Ogiltigt nsec-format. Ska vara 63 tecken';

  @override
  String get keyImportKeyFieldLabel => 'Privat nyckel eller bunker-URL';

  @override
  String get keyImportKeyRequired => 'Ange din privata nyckel eller bunker-URL';

  @override
  String get keyImportPasswordRequired =>
      'Ange lösenordet för den här krypterade nyckeln';

  @override
  String get keyImportSecurityWarningBody =>
      'Dela aldrig din privata nyckel med någon. Nyckeln ger full åtkomst till din Nostr-identitet.';

  @override
  String get keyImportSecurityWarningTitle => 'Håll din privata nyckel säker!';

  @override
  String get keyImportSubtitle =>
      'Importera din befintliga Nostr-identitet med din privata nyckel eller en bunker-URL.';

  @override
  String get keyImportTitle => 'Importera din\nNostr-identitet';

  @override
  String get commentAuthorYouIndicator => 'Du';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Visa ${name}s profil';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Ta bort kommentar';

  @override
  String get commentOptionsEditSemanticLabel => 'Redigera kommentar';

  @override
  String get commentOptionsFlagContentLabel => 'Flagga innehåll';

  @override
  String get commentOptionsFlagContentSemanticLabel =>
      'Flagga det här innehållet';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Välj en anledning till att flagga den här kommentaren';

  @override
  String get commentOptionsFlagSubmit => 'Skicka';

  @override
  String get commentOptionsTitle => 'Alternativ';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Vi jobbar fortfarande med att importera gamla kommentarer från arkivet. De är inte klara än.';

  @override
  String get commentsEmptyClassicVineTitle => 'Klassiska Vine';

  @override
  String get commentsInputEditingLabel => 'Redigerar';

  @override
  String get commentsInputSemanticHint => 'Lägg till en kommentar';

  @override
  String get commentsInputSemanticHintEdit => 'Redigera kommentar';

  @override
  String get commentsInputSemanticHintReply => 'Lägg till ett svar';

  @override
  String get commentsInputSemanticLabel => 'Kommentarsfält';

  @override
  String get commentsInputSemanticLabelEdit => 'Redigeringsfält';

  @override
  String get commentsInputSemanticLabelReply => 'Svarsfält';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Visa profil för $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Klassiker-arkivet läses in';

  @override
  String get classicsEmptyTitle => 'Inga klassiker hittades';

  @override
  String get classicsErrorTitle => 'Kunde inte läsa in Klassiker';

  @override
  String get classicsUnavailableDescription =>
      'Klassiker är bara tillgängliga när du är ansluten till Funnelcake-reler.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Byt till en Funnelcake-aktiverad rel i Inställningar för att komma åt Klassiker-arkivet.';

  @override
  String get classicsUnavailableTitle => 'Klassiker är inte tillgängliga';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Bli först med att publicera en video med den här hashtaggen!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Inga videor hittades för #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Det kan ta en liten stund';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Läser in videor om #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Lägg till hashtaggar... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Kom tillbaka senare för nytt innehåll';

  @override
  String get newVideosTabEmptyTitle => 'Inga videor i Nya videor';

  @override
  String get popularVideosContextTitle => 'Populära videor';

  @override
  String get popularVideosEmptySubtitle =>
      'Kom tillbaka senare för nytt innehåll';

  @override
  String get popularVideosEmptyTitle => 'Inga videor i Populära videor';

  @override
  String get popularVideosErrorTitle => 'Kunde inte läsa in trendande videor';

  @override
  String get popularVideosFeedSourceLabel => 'Källa för populärt flöde';

  @override
  String get trendingHashtagsLoading => 'Läser in hashtaggar...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Visa videor taggade med $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Videons skapare: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Videons beskrivning: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divines vision är att ge dig ett verkligt algoritmiskt val. I stället för att vara låst till en enda svart låda-algoritm kommer du att kunna välja mellan flera rekommendationssätt:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Kronologisk tidslinje från skapare du följer';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Detta ger dig kontroll över din uppmärksamhet i stället för att lämna den till plattformen. Du bör veta hur ditt flöde kurateras och ha makten att ändra det när du vill.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Community-skapade egna flöden för ämnen som musik, komedi eller konst';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Personligt \"För dig\"-flöde';

  @override
  String get forYouAlgorithmChoiceTitle => 'Din algoritm, ditt val';

  @override
  String get forYouAlgorithmChoiceTrending => 'Trendande och populärt innehåll';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Stark signal — du var engagerad nog att svara';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine uppmärksammar hur du interagerar med innehåll för att förstå vad du gillar. Varje gång du tittar på en video, ger den en reaktion, lämnar en kommentar eller återpublicerar den så noterar systemet det.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Så fungerar det';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Olika handlingar signalerar olika grader av intresse:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Om du inte har byggt upp någon tittarhistorik än visar vi en blandning av det som är populärt och trendar just nu tillsammans med senaste uppladdningar. Det ger dig en bra utgångspunkt för att utforska.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'När du tittar, gillar och engagerar dig i innehåll blir rekommendationerna gradvis mer personliga. Med tiden lyfter ditt För dig-flöde fram videor från skapare du kanske aldrig hade upptäckt på egen hand.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Ny på Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Vi bygger ett öppet system där utvecklare kan implementera sina egna algoritmer, och du kan välja vilka du vill använda — eller välja bort dem helt.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Öppen källkod och transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Medelstark signal — ett snabbt sätt att visa uppskattning';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reaktioner';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Starkaste signalen — att dela med dina följare är ett kraftfullt stöd';

  @override
  String get forYouAlgorithmSubtitle =>
      'Drivs av Gorse, en rekommendationsmotor med öppen källkod';

  @override
  String get forYouAlgorithmTitle => 'Divine-algoritmen';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Svag signal — visar grundläggande intresse';

  @override
  String get forYouEmptyDescription =>
      'Titta på och gilla några videor för att få personliga rekommendationer.';

  @override
  String get forYouEmptyTitle => 'Inga rekommendationer än';

  @override
  String get forYouErrorTitle => 'Kunde inte läsa in rekommendationer';

  @override
  String get forYouUnavailableDescription =>
      'Personliga rekommendationer kräver anslutning till Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'För dig är inte tillgängligt';

  @override
  String get inboxConversationOptionsLabel => 'Alternativ';

  @override
  String get inboxConversationViewProfileButton => 'Visa profil';

  @override
  String get inboxMessageRequestsEmpty => 'Inga meddelandeförfrågningar';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Meddelandeförfrågningar, $requestCount väntande';
  }

  @override
  String get inboxMessageRequestsTitle => 'Meddelandeförfrågningar';

  @override
  String get inboxMessagesTab => 'Meddelanden';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Meddelandeförfrågan från $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Skickade en meddelandeförfrågan';

  @override
  String get inboxRequestsMarkAllRead => 'Markera alla förfrågningar som lästa';

  @override
  String get inboxRequestsRemoveAll => 'Ta bort alla förfrågningar';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Avböj och ta bort';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Förfrågan från $displayName avvisad';
  }

  @override
  String get messageRequestLoadFailed =>
      'Kunde inte läsa in den här förfrågan.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count följare';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count videor';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meddelanden',
      one: '1 meddelande',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Visa meddelanden';

  @override
  String get messageRequestViewProfileButton => 'Visa profil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName vill skicka meddelanden till dig och har skickat $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Du bytte konto, så ingenting raderades. Öppna raderingen igen för kontot du vill ta bort.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Bekräfta genom att skriva:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Bekräfta genom att skriva ditt användarnamn:';

  @override
  String get deleteAccountConfirmationHint => 'Skriv DELETE';

  @override
  String get deleteAccountConfirmationHintUsername => 'Skriv ditt användarnamn';

  @override
  String get deleteAccountDeleteAllContentButton => 'Ta bort allt innehåll';

  @override
  String get accountDeletionRecoveryTitle => 'Ditt konto tas bort';

  @override
  String get accountDeletionRecoveryBody =>
      'Vi kunde inte slutföra raderingen av ditt konto. Ditt användarnamn är reserverat åt dig och kan fortfarande återställas.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Återställ mitt användarnamn';

  @override
  String get accountDeletionFinishingBody =>
      'Din begäran om radering behandlas fortfarande. Du kan använda ett annat konto medan vi slutför processen.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Raderingen av ett annat konto behandlas fortfarande på den här enheten. Vänta tills den är klar innan du raderar det här kontot.';

  @override
  String get accountDeletionCancellingBody =>
      'Vi avbryter din radering. Kolla igen innan du lämnar den här skärmen.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Vi kunde inte återställa ditt användarnamn än. Kontrollera anslutningen och försök igen.';

  @override
  String get accountDeletionUsernameRestored =>
      'Ditt användarnamn är återställt. Ditt konto raderades inte.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Vi kunde inte kontrollera status för raderingen. Kontrollera anslutningen och försök igen.';

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
      'Kontoborttagning är inte tillgänglig just nu. Ingenting har tagits bort.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Vi kunde inte slutföra raderingen av ditt konto. Försök igen.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Slutgiltig bekräftelse';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Raderingsförfrågningar skickade, men dina nycklar kan finnas kvar på den här enheten. Gå till Inställningar → Nostr-nycklar → Ta bort nycklar för att försöka igen.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Raderingsförfrågningar skickade och du är utloggad, men vissa lokala data kunde inte tas bort från den här enheten.';

  @override
  String get deleteAccountPreparingDeletion => 'Förbereder borttagning...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total händelser';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Detta tar bort den lokala inloggningen för det här kontot från den här enheten. Det tar inte bort ditt Divine-konto eller din Nostr-identitet.\n\nDina utkast och klipp finns kvar sparade på den här enheten för det här kontot. Om det här är ditt sista lokala konto återgår du till inloggningsskärmen.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Ta bort från enheten';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Ta bort det här kontot från den här enheten?';

  @override
  String get deleteAccountReauthRequired =>
      'Logga in igen för att radera ditt konto. Inget har raderats än.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Raderingsförfrågningar för dina inlägg har skickats, men vi kunde inte slutföra raderingen av ditt konto. Försök igen om en stund.';

  @override
  String get deleteAccountSuccess =>
      'Ditt Divine-konto har tagits bort. Begäranden om att radera dina Nostr-inlägg har skickats, men vissa reläer, klienter eller cacheminnen kan behålla kopior.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Radering av kontot har begärts. Raderingen av vissa befintliga inlägg kunde inte bekräftas individuellt.';

  @override
  String get deleteAccountWarningBody =>
      'Det här skickar raderingsförfrågningar för ditt konto och innehåll, tar bort ditt Divine-konto när det går och loggar ut dig på den här enheten. Vissa reläer, klienter och sökindex kan behålla kopior. Andra inloggade enheter förblir aktiva tills du tar bort nycklarna där.';

  @override
  String get findPeopleNoContacts =>
      'Inga kontakter hittades.\nBörja följa personer för att se dem här.';

  @override
  String get geoBlockedCityLabel => 'Stad';

  @override
  String get geoBlockedCountryLabel => 'Land';

  @override
  String get geoBlockedDefaultReason =>
      'Tjänsten är inte tillgänglig i din region på grund av lokala regler.';

  @override
  String get geoBlockedLegalNotice =>
      'Vi respekterar dina lokala lagar och regler. Den här begränsningen baseras på platsen för din IP-adress.';

  @override
  String get geoBlockedRegionLabel => 'Region';

  @override
  String get geoBlockedTitle => 'Tjänsten är inte tillgänglig';

  @override
  String get likedVideosEmpty => 'Inga gillade videor';

  @override
  String get likedVideosInvalidRoute => 'Ogiltig rutt';

  @override
  String get likedVideosTitle => 'Gillade videor';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Försöker ladda upp igen…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Spara till utkast';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Sparat till utkast';

  @override
  String get uploadFailureSheetTitle => 'Uppladdningen misslyckades';

  @override
  String get uploadFailureSheetTryAgainButton => 'Försök igen';

  @override
  String get videoEditorAudioImportAudio => 'Importera ljud';

  @override
  String get videoEditorAudioImportFailed => 'Ljudimporten misslyckades.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn => 'Logga in för att publicera videor.';

  @override
  String get publishErrorNoRetry => 'Ingen uppladdning att försöka igen med.';

  @override
  String get publishErrorNoInternet =>
      'Ingen internetanslutning. Kontrollera ditt wifi eller mobildata och försök igen.';

  @override
  String get publishErrorServerUnreachable =>
      'Kunde inte nå servern. Försök igen om en stund.';

  @override
  String get publishErrorTimeout =>
      'Uppladdningen tog för lång tid. Prova en starkare anslutning eller en mindre video.';

  @override
  String get publishErrorTls =>
      'Den säkra anslutningen misslyckades. Kontrollera ditt nätverk – offentligt wifi kan blockera uppladdningar.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Mediaservern ($serverName) är inte tillgänglig. Du kan välja en annan i dina inställningar.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Videofilen är för stor för servern. Prova att korta ner den eller sänka kvaliteten.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Mediaservern ($serverName) råkade ut för ett internt fel. Du kan välja en annan i dina inställningar.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Mediaservern ($serverName) är tillfälligt nere. Försök igen snart eller välj en annan i dina inställningar.';
  }

  @override
  String get publishErrorForbidden =>
      'Du har inte behörighet att ladda upp till den här servern.';

  @override
  String get publishErrorFileNotFound =>
      'Videofilen kunde inte hittas. Den kan ha raderats. Spela in på nytt och försök igen.';

  @override
  String get publishErrorLowStorage =>
      'Det finns inte tillräckligt med lagringsutrymme på enheten. Frigör utrymme och försök igen.';

  @override
  String get publishErrorThumbnailFailed =>
      'Videon laddades upp, men miniatyrbilden kunde inte skapas. Försök igen.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Videon laddades upp men inlägget kunde inte publiceras. Kontrollera dina relinställningar och försök igen.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Videon laddades upp men ljudet får inte återanvändas. Välj ett annat ljud för att posta.';

  @override
  String get publishErrorInterrupted =>
      'Uppladdningen avbröts. Vill du försöka igen?';

  @override
  String get publishErrorAccountChanged =>
      'Den här videon hör till ett annat konto. Byt tillbaka till det kontot för att posta den.';

  @override
  String get publishErrorGeneric => 'Något gick fel. Försök igen.';

  @override
  String get publishErrorRateLimited =>
      'För många uppladdningar just nu. Vänta en stund och försök igen.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Din uppladdningssession har gått ut. Försök igen.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine har inte behörighet att ladda upp. Kontrollera appens behörigheter i dina inställningar och försök igen.';

  @override
  String get publishErrorOutOfMemory =>
      'Enheten har ont om minne. Stäng några appar och försök igen.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Texten och dekalerna i det här utkastet kunde inte förberedas. Öppna det i redigeraren och posta igen.';

  @override
  String get publishErrorUnknownServer => 'Okänd server';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Inga resultat hittades för \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Visa videor taggade med $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Ljud: $soundName av $creatorName. Tryck för att se ljuddetaljer.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Originalljud av $creatorName. Tryck för att använda det här ljudet.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Ljud: $soundName av $creatorName. Tryck för att se detaljer.';
  }

  @override
  String get soundDetailLoadError => 'Kunde inte läsa in ljud. Försök igen.';

  @override
  String get soundDetailNotFoundMessage => 'Det här ljudet kunde inte hittas';

  @override
  String get soundDetailNotFoundTitle => 'Ljudet hittades inte';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loopar';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Ljudet från den här videon är inte tillgängligt separat.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Originalljud – $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Den här personen postade en originalvine som Divine hittade i arkivet. Det är inte en verifieringsbadge för kontot.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Profilbock';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine ger den här bocken till teamets konton. Det är skilt från NIP-05, verifierade kontolänkar och OG Viner-status.';

  @override
  String get unfollowConfirmButton => 'Sluta följa';

  @override
  String get videoClipSaveFailed => 'Kunde inte spara klipp';

  @override
  String videoClipSaveTo(String destination) {
    return 'Spara till $destination';
  }

  @override
  String get videoClipDelete => 'Ta bort klipp';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirerad av $creatorName +$additionalCreatorCount. Tryck för att se deras profil.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspirerad av $creatorName. Tryck för att se deras profil.';
  }

  @override
  String get bugReportSendReport => 'Skicka rapport';

  @override
  String get supportSubjectRequiredLabel => 'Ämne *';

  @override
  String get supportPublicSubmissionTitle => 'Offentligt GitHub-inlägg';

  @override
  String get supportPublicSubmissionMessage =>
      'Allt du skickar in här publiceras i vårt öppna GitHub-arkiv så att utvecklare kan ta hand om det. Inlägget och kontot du är inloggad med blir offentligt synliga för alla.';

  @override
  String get supportRequiredHelper => 'Obligatoriskt';

  @override
  String get supportFieldLimitReached =>
      'Det är maxlängden. Allt därutöver lades inte till.';

  @override
  String get bugReportSubjectHint => 'Kort sammanfattning av problemet';

  @override
  String get bugReportDescriptionRequiredLabel => 'Vad hände? *';

  @override
  String get bugReportDescriptionHint => 'Beskriv problemet du stötte på';

  @override
  String get bugReportStepsLabel => 'Steg för att återskapa';

  @override
  String get bugReportStepsHint => '1. Gå till...\n2. Tryck på...\n3. Se felet';

  @override
  String get bugReportExpectedBehaviorLabel => 'Förväntat beteende';

  @override
  String get bugReportExpectedBehaviorHint => 'Vad borde ha hänt istället?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Enhetsinfo och loggar inkluderas automatiskt.';

  @override
  String get bugReportSuccessMessage =>
      'Tack! Vi har fått din rapport och använder den för att göra Divine bättre.';

  @override
  String get bugReportAttachImages => 'Bifoga bilder';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count av $max bilder valda';
  }

  @override
  String get bugReportRemoveImage => 'Ta bort bilden';

  @override
  String get bugReportUploadFailed =>
      'Vi kunde inte ladda upp den valda bilden. Försök igen eller skicka rapporten utan den.';

  @override
  String get bugReportSendFailed =>
      'Kunde inte skicka buggrapporten. Försök igen senare.';

  @override
  String get featureRequestSendRequest => 'Skicka önskemål';

  @override
  String get featureRequestSubjectHint => 'Kort sammanfattning av din idé';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Vad önskar du? *';

  @override
  String get featureRequestDescriptionHint => 'Beskriv funktionen du vill ha';

  @override
  String get featureRequestUsefulnessLabel =>
      'Hur skulle detta vara användbart?';

  @override
  String get featureRequestUsefulnessHint =>
      'Förklara nyttan funktionen skulle ge';

  @override
  String get featureRequestWhenLabel => 'När skulle du använda det?';

  @override
  String get featureRequestWhenHint =>
      'Beskriv situationerna där detta skulle hjälpa';

  @override
  String get featureRequestSuccessMessage =>
      'Tack! Vi har fått ditt önskemål och kommer att granska det.';

  @override
  String get featureRequestSendFailed =>
      'Kunde inte skicka funktionsönskemålet. Försök igen senare.';

  @override
  String get notificationFollowBack => 'Följ tillbaka';

  @override
  String get followingTitle => 'Följer';

  @override
  String followingTitleForName(String displayName) {
    return '${displayName}s följer';
  }

  @override
  String get followingFailedToLoadList => 'Kunde inte ladda följer-listan';

  @override
  String get followingEmptyTitle => 'Följer ingen än';

  @override
  String get followersTitle => 'Följare';

  @override
  String followersTitleForName(String displayName) {
    return '${displayName}s följare';
  }

  @override
  String get followersFailedToLoadList => 'Kunde inte ladda följarlistan';

  @override
  String get followersEmptyTitle => 'Inga följare än';

  @override
  String get followersUpdateFollowFailed =>
      'Kunde inte uppdatera följstatus. Försök igen.';

  @override
  String get followersSortSemanticLabel => 'Sortera följare';

  @override
  String get followingSortSemanticLabel => 'Sortera följda';

  @override
  String get followSortTitle => 'Sortera efter';

  @override
  String get followSortNewest => 'Nyaste först';

  @override
  String get followSortOldest => 'Äldsta först';

  @override
  String get newMessageTitle => 'Nytt meddelande';

  @override
  String get newMessageFindPeople => 'Hitta personer';

  @override
  String get newMessageNoContacts =>
      'Inga kontakter hittades.\nFölj personer för att se dem här.';

  @override
  String get newMessageNoUsersFound => 'Inga användare hittades';

  @override
  String get hashtagSearchTitle => 'Sök efter hashtags';

  @override
  String get hashtagSearchSubtitle => 'Upptäck trendande ämnen och innehåll';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Inga hashtags hittades för \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Sökning misslyckades';

  @override
  String get userNotAvailableTitle => 'Konto ej tillgängligt';

  @override
  String get userNotAvailableBody =>
      'Det här kontot är inte tillgängligt just nu.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Kunde inte spara inställningarna. Försök igen.';

  @override
  String get blossomValidServerUrl =>
      'Ange en giltig server-URL (t.ex. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom-inställningar sparade';

  @override
  String get blossomSaveTooltip => 'Spara';

  @override
  String get blossomAboutTitle => 'Om Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom är ett decentraliserat protokoll för medialagring som låter dig ladda upp videor till valfri kompatibel server. Som standard laddas videor upp till Divines Blossom-server. Aktivera alternativet nedan för att använda en egen server istället.';

  @override
  String get blossomUseCustomServer => 'Använd egen Blossom-server';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Videor laddas upp till din egen Blossom-server';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Dina videor laddas just nu upp till Divines Blossom-server';

  @override
  String get blossomCustomServerUrl => 'URL till egen Blossom-server';

  @override
  String get blossomCustomServerHelper =>
      'Ange URL:en till din egen Blossom-server';

  @override
  String get blossomPopularServers => 'Populära Blossom-servrar';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL till Blossom-server måste använda https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Kunde inte uppdatera crosspost-inställningen';

  @override
  String get blueskySignInRequired =>
      'Logga in för att hantera Bluesky-inställningar';

  @override
  String get blueskyPublishVideos => 'Publicera videor till Bluesky';

  @override
  String get blueskyEnabledSubtitle => 'Dina videor publiceras till Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Dina videor publiceras inte till Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Dina tidigare videor publiceras också';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'När du slår på detta börjar Divine skicka dina äldre videor till Bluesky, äldst först, utan att stressa dagsgränsen.';

  @override
  String get blueskyHandle => 'Bluesky-handtag';

  @override
  String get blueskyDid => 'Bluesky-DID';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Konto provisionerat och klart';

  @override
  String get blueskyStatusPending => 'Konto provisioneras...';

  @override
  String get blueskyStatusFailed => 'Kontoprovisionering misslyckades';

  @override
  String get blueskyStatusDisabled => 'Konto inaktiverat';

  @override
  String get blueskyStatusNotLinked => 'Inget Bluesky-konto kopplat';

  @override
  String get blueskyUsernameRequired =>
      'Skapa ett divine.video-handtag innan du publicerar på Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Publicering på Bluesky kräver ett registrerat handtag i formen användarnamn.divine.video.';

  @override
  String get blueskyUsernameSyncPending =>
      'Ditt Divine-handtag är registrerat. Vi kopplar det till Bluesky – försök igen om en stund.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Vi kunde inte kontrollera ditt Divine-handtag. Försök igen.';

  @override
  String get blueskySetUpHandle => 'Skapa';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Publicering på Bluesky är tillfälligt otillgänglig. Försök igen.';

  @override
  String get invitesTitle => 'Bjud in vänner';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inbjudningar redo att skapas',
      one: '1 inbjudan redo att skapas',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Skapa en kod när du är redo att dela en.';

  @override
  String get invitesGenerateButtonLabel => 'Skapa inbjudan';

  @override
  String get invitesNoneAvailable => 'Inga inbjudningar tillgängliga just nu';

  @override
  String get invitesShareWithPeople => 'Dela Divine med folk du känner';

  @override
  String get invitesUsedInvites => 'Använda inbjudningar';

  @override
  String invitesShareMessage(String code) {
    return 'Häng med mig på Divine! Använd inbjudningskoden $code för att komma igång:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Kopiera inbjudan';

  @override
  String get invitesCopied => 'Inbjudan kopierad!';

  @override
  String get invitesShareInvite => 'Dela inbjudan';

  @override
  String get invitesShareSubject => 'Häng med mig på Divine';

  @override
  String get invitesClaimed => 'Inlöst';

  @override
  String get invitesCouldNotLoad => 'Kunde inte ladda inbjudningar';

  @override
  String get invitesRetry => 'Försök igen';

  @override
  String get searchSomethingWentWrong => 'Något gick fel';

  @override
  String get searchTryAgain => 'Försök igen';

  @override
  String get searchForLists => 'Sök efter listor';

  @override
  String get searchFindCuratedVideoLists => 'Hitta kurerade videolistor';

  @override
  String get searchEnterQuery => 'Skriv en sökterm';

  @override
  String get searchDiscoverSomethingInteresting => 'Upptäck något intressant';

  @override
  String get searchPeopleSectionHeader => 'Personer';

  @override
  String get searchPeopleLoadingLabel => 'Läser in personresultat';

  @override
  String get searchTagsSectionHeader => 'Taggar';

  @override
  String get searchTagsLoadingLabel => 'Läser in taggresultat';

  @override
  String get searchVideosSectionHeader => 'Videor';

  @override
  String get searchVideosLoadingLabel => 'Läser in videoresultat';

  @override
  String get searchVideosSortOptionsLabel => 'Sortera videoresultat';

  @override
  String get searchVideosSortTrending => 'Hett';

  @override
  String get searchVideosSortLoops => 'Flest loopar';

  @override
  String get searchVideosSortEngagement => 'Mest engagemang';

  @override
  String get searchVideosSortRecent => 'Senaste';

  @override
  String get searchListsSectionHeader => 'Listor';

  @override
  String get searchListsLoadingLabel => 'Laddar listresultat';

  @override
  String get cameraAgeRestriction =>
      'Du måste vara 16 år eller äldre för att skapa innehåll';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker-rel måste använda wss:// (ws:// tillåts endast för localhost)';

  @override
  String get timeNow => 'nu';

  @override
  String timeShortMinutes(int count) {
    return '${count}min';
  }

  @override
  String timeShortHours(int count) {
    return '${count}t';
  }

  @override
  String timeShortDays(int count) {
    return '${count}d';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}v';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}må';
  }

  @override
  String timeShortYears(int count) {
    return '$countå';
  }

  @override
  String get timeVerboseNow => 'Nu';

  @override
  String timeAgo(String time) {
    return '$time sedan';
  }

  @override
  String get timeToday => 'Idag';

  @override
  String get timeYesterday => 'Igår';

  @override
  String get timeJustNow => 'nyss';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min sedan';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}t sedan';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d sedan';
  }

  @override
  String get draftTimeJustNow => 'Nyss';

  @override
  String get contentLabelNudity => 'Nakenhet';

  @override
  String get contentLabelSexualContent => 'Sexuellt innehåll';

  @override
  String get contentLabelPornography => 'Pornografi';

  @override
  String get contentLabelGraphicMedia => 'Grafiskt innehåll';

  @override
  String get contentLabelViolence => 'Våld';

  @override
  String get contentLabelSelfHarm => 'Självskada/Självmord';

  @override
  String get contentLabelDrugUse => 'Droganvändning';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tobak/Rökning';

  @override
  String get contentLabelGambling => 'Spelande';

  @override
  String get contentLabelProfanity => 'Svordomar';

  @override
  String get contentLabelHateSpeech => 'Hatretorik';

  @override
  String get contentLabelHarassment => 'Trakasserier';

  @override
  String get contentLabelFlashingLights => 'Blinkande ljus';

  @override
  String get contentLabelAiGenerated => 'AI-genererat';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Bedrägeri';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Vilseledande';

  @override
  String get contentLabelSensitiveContent => 'Känsligt innehåll';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName gillade din video';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName gillade din kommentar';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName kommenterade din video';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName började följa dig';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName nämnde dig';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName delade din video';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName publicerade en ny vine';
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
      other: '$count av dina vines',
      one: 'din vine',
    );
    return '$actorName lade till $_temp0 i $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName svarade på din kommentar';
  }

  @override
  String get notificationAndConnector => 'och';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count till',
      one: '1 till',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Du har en ny uppdatering';

  @override
  String get commentReplyToPrefix => 'Sv:';

  @override
  String get commentHideKeyboard => 'Dölj tangentbordet';

  @override
  String get commentsErrorLoadFailed => 'Kunde inte läsa in kommentarer';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Logga in för att kommentera';

  @override
  String get commentsErrorPostCommentFailed =>
      'Kunde inte publicera kommentaren';

  @override
  String get commentsErrorPostReplyFailed => 'Kunde inte publicera svaret';

  @override
  String get commentsErrorEditFailed => 'Kunde inte redigera kommentaren';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Logga in för att vara med';

  @override
  String get commentsErrorVoteFailed => 'Kunde inte rösta på kommentaren';

  @override
  String get commentsErrorReportFailed => 'Kunde inte rapportera kommentaren';

  @override
  String get commentsErrorBlockFailed => 'Kunde inte blockera användaren';

  @override
  String get commentsErrorDeleteFailed => 'Kunde inte radera kommentaren';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kommentarer',
      one: '$count kommentar',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Publicerar…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Ditt videosvar publiceras';

  @override
  String get commentsSortNew => 'Nya';

  @override
  String get commentsSortTop => 'Bästa';

  @override
  String get commentsSortOld => 'Äldsta';

  @override
  String get commentsSortSemanticLabel => 'Sortering av kommentarer';

  @override
  String get commentReply => 'Svara';

  @override
  String get commentReplySemanticLabel => 'Svara på kommentaren';

  @override
  String get commentUpvoteLabel => 'Rösta upp kommentaren';

  @override
  String get commentRemoveUpvoteLabel => 'Ta bort upprösten';

  @override
  String get commentDownvoteLabel => 'Rösta ner kommentaren';

  @override
  String get commentRemoveDownvoteLabel => 'Ta bort nerrösten';

  @override
  String get commentsInputHint => 'Lägg till kommentar...';

  @override
  String get commentsInputHintEdit => 'Redigera kommentar...';

  @override
  String get commentsEmptyTitle => 'Inga kommentarer än';

  @override
  String get commentsEmptySubtitle => 'Dra igång festen!';

  @override
  String get draftUntitled => 'Namnlös';

  @override
  String get contentWarningNone => 'Ingen';

  @override
  String get textBackgroundNone => 'Ingen';

  @override
  String get textBackgroundSolid => 'Heltäckande';

  @override
  String get textBackgroundHighlight => 'Markering';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Vänster';

  @override
  String get textAlignRight => 'Höger';

  @override
  String get textAlignCenter => 'Centrera';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kameran stöds inte på webben än';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Kamerainspelning och videoinspelning är ännu inte tillgängliga i webbversionen.';

  @override
  String get cameraPermissionBackToFeed => 'Tillbaka till flödet';

  @override
  String get cameraCouldNotStart => 'Det gick inte att starta kameran';

  @override
  String get cameraUnsupportedPlatform =>
      'Kameran är inte tillgänglig på den här plattformen än.\nDu kan fortfarande bläddra och titta på videor.';

  @override
  String get cameraPermissionErrorTitle => 'Behörighetsfel';

  @override
  String get cameraPermissionErrorDescription =>
      'Något gick fel när behörigheterna kontrollerades.';

  @override
  String get cameraPermissionRetry => 'Försök igen';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Tillåt åtkomst till kamera och mikrofon';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Detta låter dig spela in och redigera videor direkt i appen, inget mer.';

  @override
  String get cameraPermissionGoToSettings => 'Gå till inställningar';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Varför sex sekunder?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Snabba klipp skapar utrymme för spontanitet. Formatet på 6 sekunder hjälper dig att fånga äkta ögonblick när de händer.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Jag fattar!';

  @override
  String get videoRecorderUploadTitle => 'Varför ingen uppladdning?';

  @override
  String get videoRecorderUploadBody =>
      'Det du ser på Divine är gjort av människor: rått och fångat i stunden. Till skillnad från plattformar som tillåter starkt producerade eller AI-genererade uppladdningar prioriterar vi äktheten i kamera-direkt-upplevelsen.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Genom att behålla skapandet i appen kan vi bättre garantera att innehållet är äkta och oredigerat. Vi öppnar inte upp för uppladdningar från externt galleri just nu, för att skydda den äktheten och hålla vår community fri från syntetiskt innehåll i största möjliga mån.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Byt till Capture eller Classic för att filma något äkta.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Läs om hur verifieringen fungerar';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Vi hittade ett pågående arbete';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Vill du fortsätta där du slutade?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Ja, fortsätt';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Nej, starta en ny video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Det gick inte att återställa ditt utkast';

  @override
  String get videoRecorderStopRecordingTooltip => 'Stoppa inspelning';

  @override
  String get videoRecorderStartRecordingTooltip => 'Starta inspelning';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Spelar in. Tryck var som helst för att stoppa';

  @override
  String get videoRecorderTapToStartLabel =>
      'Tryck var som helst för att starta inspelningen';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Ta bort senaste klippet';

  @override
  String get videoRecorderSwitchCameraLabel => 'Byt kamera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zooma till $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Växla rutnät';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Växla spökram';

  @override
  String get videoRecorderGhostFrameEnabled => 'Spökram aktiverad';

  @override
  String get videoRecorderGhostFrameDisabled => 'Spökram inaktiverad';

  @override
  String get videoRecorderClipDeletedMessage =>
      'Klipp flyttat till papperskorgen';

  @override
  String get videoRecorderClipUndoLabel => 'Ångra';

  @override
  String get libraryTrashEmptyTitle => 'Papperskorgen är tom';

  @override
  String get libraryTrashEmptySubtitle =>
      'Borttagna klipp finns kvar här i 30 dagar innan de tas bort permanent.';

  @override
  String get libraryTrashRestoreLabel => 'Återställ';

  @override
  String get libraryTrashDeleteNowLabel => 'Ta bort nu';

  @override
  String get libraryTrashEmptyAllLabel => 'Töm papperskorgen';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Radera klippet nu?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Detta tar bort klippet från papperskorgen direkt.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Töm papperskorgen?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp',
      one: '1 klipp',
    );
    return 'Detta raderar $_temp0 permanent från papperskorgen direkt.';
  }

  @override
  String get videoRecorderCloseLabel => 'Stäng videoinspelaren';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Fortsätt till videoredigeraren';

  @override
  String get videoRecorderCameraPreviewLabel => 'Kameraförhandsvisning';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Fokusera kameran';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Byt till läget $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Lägg till ljud innan inspelning';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Det gick inte att skapa videon. Försök igen.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bilder kvar',
      one: '1 bild kvar',
      zero: 'Inga bilder kvar',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Växla blixt';

  @override
  String get videoRecorderCycleTimerLabel => 'Växla timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Växla bildförhållande';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilisering';

  @override
  String get videoRecorderStabilizationModeOff => 'Av';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Filmisk';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Filmisk utökad';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Förhandsoptimerad';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Låg latens';

  @override
  String get videoRecorderStabilizationModeAuto => 'Auto';

  @override
  String get videoRecorderFlashValueOff => 'Av';

  @override
  String get videoRecorderFlashValueOn => 'På';

  @override
  String get videoRecorderFlashValueAuto => 'Auto';

  @override
  String get videoRecorderTimerValueOff => 'Av';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 sekunder';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 sekunder';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Kvadratisk';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Stående';

  @override
  String get videoRecorderCameraValueFront => 'Främre kamera';

  @override
  String get videoRecorderCameraValueBack => 'Bakre kamera';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Klippbibliotek, inga klipp';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Öppna klippbibliotek, $clipCount klipp',
      one: 'Öppna klippbibliotek, 1 klipp',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Öppna stop motion-bibliotek, $frameCount bildrutor',
      one: 'Öppna stop motion-bibliotek, 1 bildruta',
      zero: 'Öppna stop motion-bibliotek',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Öppna kamera';

  @override
  String get videoEditorLibraryLabel => 'Bibliotek';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Rita';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorTuneLabel => 'Justera';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Öppna justeringsredigeraren';

  @override
  String get videoEditorTuneBrightness => 'Ljusstyrka';

  @override
  String get videoEditorTuneContrast => 'Kontrast';

  @override
  String get videoEditorTuneSaturation => 'Mättnad';

  @override
  String get videoEditorTuneExposure => 'Exponering';

  @override
  String get videoEditorTuneHue => 'Nyans';

  @override
  String get videoEditorTuneTemperature => 'Temperatur';

  @override
  String get videoEditorTuneTint => 'Färgton';

  @override
  String get videoEditorTuneFade => 'Uttoning';

  @override
  String get videoEditorAudioLabel => 'Ljud';

  @override
  String get videoEditorAddTitle => 'Lägg till';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Öppna bibliotek';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Öppna ljudredigerare';

  @override
  String get videoEditorCaptionsLabel => 'Undertexter';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Öppna undertextredigeraren';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Bränn in i videon';

  @override
  String get videoEditorCaptionsPresetCustom => 'Egen';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Egen stil';

  @override
  String get videoEditorCaptionsCustomApply => 'Använd';

  @override
  String get videoEditorCaptionsCustomFont => 'Typsnitt';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Textfärg';

  @override
  String get videoEditorCaptionsCustomBackground => 'Bakgrund';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Bakgrundsfärg';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animation';

  @override
  String get videoEditorCaptionsAnimationNone => 'Ingen';

  @override
  String get videoEditorCaptionsAnimationFade => 'Tona';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Fjäder';

  @override
  String get videoEditorCaptionsEditTitle => 'Undertexter';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Lyssnar…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Vi gör undertextförslag av ditt ljud.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Vi hörde inget tal. Du kan ändå skriva undertexterna själv.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Taligenkänning är inte tillgängligt på den här enheten. Du kan skriva undertexterna själv.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Taligenkänning är inte tillåtet. Aktivera det i Inställningar eller skriv undertexterna själv.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Transkriberingen fungerade inte den här gången. Du kan skriva undertexterna själv.';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'Skriv undertexterna själv';

  @override
  String get videoEditorCaptionsAddCue => 'Lägg till undertext';

  @override
  String get videoEditorCaptionsCueTextHint => 'Undertextens text';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Ta bort undertext';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Ta bort alla undertexter';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Ta bort undertexterna?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'All text och timing försvinner.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Stäng undertextredigeraren';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Bekräfta undertexter';

  @override
  String get videoEditorCaptionsPresetTitle => 'Undertextstil';

  @override
  String get videoEditorCaptionsPresetClassic => 'Klassisk';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Rubrik';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Skrivmaskin';

  @override
  String get videoEditorCaptionsPresetMarker => 'Märkpenna';

  @override
  String get videoEditorCaptionsPresetScript => 'Kalligrafi';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegant';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bubbla';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Fet';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Drömsk';

  @override
  String get videoEditorCaptionsPresetOcean => 'Ocean';

  @override
  String get videoEditorCaptionsPresetSunny => 'Solig';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Handskriven';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Stämpel';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Öppna textredigerare';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Öppna ritredigerare';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Öppna filtereditor';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Öppna klistermärkesredigerare';

  @override
  String get videoEditorSaveDraftTitle => 'Spara ditt utkast?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Spara dina redigeringar till senare, eller kasta dem och lämna redigeraren.';

  @override
  String get videoEditorSaveDraftButton => 'Spara utkast';

  @override
  String get videoEditorDiscardChangesButton => 'Kasta ändringar';

  @override
  String get videoEditorKeepEditingButton => 'Fortsätt redigera';

  @override
  String get videoEditorDeleteLayerDropZone => 'Släppzon för att ta bort lager';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Släpp för att ta bort lager';

  @override
  String get videoEditorDoneLabel => 'Klar';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Spela upp eller pausa video';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Ogiltig delningsposition. Båda klippen måste vara minst $minDurationMs ms långa.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Spara valt klipp';

  @override
  String get videoEditorSaveClip => 'Spara klipp';

  @override
  String get videoEditorClipSavedSuccess => 'Klipp sparat i bibliotek';

  @override
  String get videoEditorClipSaveFailed => 'Det gick inte att spara klipp';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Färgväljare';

  @override
  String get videoEditorUndoSemanticLabel => 'Ångra';

  @override
  String get videoEditorRedoSemanticLabel => 'Gör om';

  @override
  String get videoEditorTextColorSemanticLabel => 'Textfärg';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Textjustering';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Textbakgrund';

  @override
  String get videoEditorFontSemanticLabel => 'Typsnitt';

  @override
  String get videoEditorNoStickersFound => 'Inga stickers hittades';

  @override
  String get videoEditorNoStickersAvailable => 'Inga stickers tillgängliga';

  @override
  String get videoEditorFailedLoadStickers =>
      'Det gick inte att ladda stickers';

  @override
  String get videoEditorVoiceOverLabel => 'Voice-over';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Inspelning $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Spela in en voice-over';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Starta inspelning';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Stoppa inspelning';

  @override
  String get videoEditorVoiceOverHint =>
      'Tryck för att spela in. Lägg till hur många tagningar du vill.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inspelningar',
      one: '1 inspelning',
      zero: 'Inga inspelningar än',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Ta bort senaste inspelningen';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Mikrofonåtkomst krävs';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Tillåt åtkomst till mikrofonen för att spela in en voice-over.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Öppna inställningar';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Inspelning startad';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Inspelning sparad';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Inspelningen är längre än din video';

  @override
  String get videoEditorPlaySemanticLabel => 'Spela';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausa';

  @override
  String get videoEditorVolumeSemanticLabel => 'Justera volym';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volym $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Dra för att justera';

  @override
  String get videoEditorChromaKeyLabel => 'Green screen';

  @override
  String get videoEditorChromaKeyTitle => 'Green screen';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Ställ in green screen för det här klippet';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Ignorera ändringarna av green screen';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Använd green screen';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Hitta automatiskt';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Grön';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Blå';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Bakgrundsfärg';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Styrka';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Hur mycket av bakgrundsfärgen som försvinner';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Kant';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Mjukar upp urklippet så att hår inte blir taggigt';

  @override
  String get videoEditorChromaKeySpillLabel => 'Färgspill';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Drar bort bakgrundens färg från ditt motiv';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Ersätt med';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Inget';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Färg';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Bild';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Klipp';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Video kan inte spara transparens, så det här exporteras som svart.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Hittade ingen bakgrund. Den måste nå ut till bildkanten – välj annars färgen för hand.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Välj ett klipp';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Ditt bibliotek är tomt. Spara ett klipp först, sedan kan du använda det som bakgrund.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Det gick inte att läsa in bilden.';

  @override
  String get videoEditorChromaKeyRemove => 'Ta bort green screen';

  @override
  String get videoEditorChromaKeyFailed =>
      'Det gick inte att använda green screen. Ditt klipp är oförändrat.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Det gick inte att ta bort green screen. Ditt klipp är oförändrat.';

  @override
  String get videoEditorChromaKeyApplying => 'Använder green screen …';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Den här enheten kan inte visa förhandsvisningen live. Dina inställningar gäller ändå vid export.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Klipp $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Ta bort';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Ta bort valt objekt';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Bildrutor per bild';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bildrutor',
      one: '1 bildruta',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Bildrutor';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count bildrutor per bild';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Stop motion-bild $position av $total';
  }

  @override
  String get videoEditorEditLabel => 'Redigera';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'Redigera valt objekt';

  @override
  String get videoEditorDuplicateLabel => 'Duplicera';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplicera valt objekt';

  @override
  String get videoEditorCombineLabel => 'Kombinera';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Kombinera valda teckningar till ett lager';

  @override
  String get videoEditorSplitLabel => 'Dela';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'Dela valt klipp';

  @override
  String get videoEditorExtractAudioLabel => 'Extrahera ljud';

  @override
  String get videoEditorClipAudioTitle => 'Klippljud';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Extrahera ljud från klipp och tysta originalet';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Kan inte extrahera ljud: klippet är inte tillgängligt lokalt.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Kunde inte extrahera ljud. Försök igen.';

  @override
  String get videoEditorSpeedLabel => 'Hastighet';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Ange uppspelningshastighet för valt klipp';

  @override
  String get videoEditorReverseLabel => 'Baklänges';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Aktivera eller inaktivera omvänd uppspelning för valt klipp';

  @override
  String get videoEditorReverseProgressLabel =>
      'Ett ögonblick, vi vänder ditt klipp baklänges';

  @override
  String get videoEditorTransformLabel => 'Transformera';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Beskär, rotera eller vänd det valda klippet';

  @override
  String get videoEditorTransformProgressLabel =>
      'Ett ögonblick, vi transformerar ditt klipp';

  @override
  String get videoEditorTransformFailed =>
      'Det gick inte att transformera klippet. Försök igen.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Kan inte transformera: klippet är inte tillgängligt lokalt.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Beskär, rotera eller spegelvänd markerad bildruta';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Ett ögonblick, vi transformerar din bildruta';

  @override
  String get videoEditorTransformFrameFailed =>
      'Det gick inte att transformera bildrutan. Försök igen.';

  @override
  String get videoEditorTransformRotateLabel => 'Rotera';

  @override
  String get videoEditorTransformFlipLabel => 'Vänd';

  @override
  String get videoEditorTransformResetLabel => 'Återställ';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'Tillämpa transformering';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'Avbryt transformering';

  @override
  String get videoEditorTransformPlayLabel => 'Spela';

  @override
  String get videoEditorTransformPauseLabel => 'Pausa';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Kan inte vända baklänges: klippet är inte tillgängligt lokalt.';

  @override
  String get videoEditorReverseFailed =>
      'Kunde inte vända klippet baklänges. Försök igen.';

  @override
  String get videoEditorSpeedSheetTitle => 'Klipphastighet';

  @override
  String get videoEditorTransitionSheetTitle => 'Övergång';

  @override
  String get videoEditorTransitionNone => 'Ingen';

  @override
  String get videoEditorTransitionDissolve => 'Övertoning';

  @override
  String get videoEditorTransitionFadeToBlack => 'Tona till svart';

  @override
  String get videoEditorTransitionFadeToWhite => 'Tona till vitt';

  @override
  String get videoEditorTransitionSlide => 'Glidning';

  @override
  String get videoEditorTransitionPush => 'Putta';

  @override
  String get videoEditorTransitionWipe => 'Svep';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Redigera övergång';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Loopövergång';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Redigera loopövergång';

  @override
  String get videoEditorTransitionDuration => 'Längd';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Förkortad så att den inte överlappar den intilliggande övergången.';

  @override
  String get videoEditorTransitionCurve => 'Kurva';

  @override
  String get videoEditorTransitionDirection => 'Riktning';

  @override
  String get videoEditorTransitionDirectionLeft => 'Vänster';

  @override
  String get videoEditorTransitionDirectionRight => 'Höger';

  @override
  String get videoEditorTransitionDirectionUp => 'Upp';

  @override
  String get videoEditorTransitionDirectionDown => 'Ned';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Animeringskurva $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animering';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Redigera lageranimering';

  @override
  String get videoEditorLayerAnimationEnter => 'In';

  @override
  String get videoEditorLayerAnimationLeave => 'Ut';

  @override
  String get videoEditorLayerAnimationFade => 'Toning';

  @override
  String get videoEditorLayerAnimationScale => 'Skala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Skala från';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Avsluta redigering av tidslinje';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel =>
      'Spela förhandsvisning';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'Pausa förhandsvisning';

  @override
  String get videoEditorAudioUntitledSound => 'Namnlöst ljud';

  @override
  String get videoEditorAudioUntitled => 'Namnlös';

  @override
  String get videoEditorAudioAddAudio => 'Lägg till ljud';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Inga ljud tillgängliga';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Ljud visas här när skapare delar ljud';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Det gick inte att ladda ljud';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Välj ljudsegmentet för din video';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Gemenskap';

  @override
  String get videoEditorAudioCategoryFeatured => 'Utvalda';

  @override
  String get videoEditorAudioCategoryMySounds => 'Mina ljud';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Pilverktyg';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Suddverktyg';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Markeringsverktyg';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Pennverktyg';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Visa tidslinje';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Dölj tidslinje';

  @override
  String get videoEditorFeedPreviewContent =>
      'Undvik att placera innehåll bakom dessa områden.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Original';

  @override
  String get videoEditorStickerSearchHint => 'Sök stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Välj typsnitt';

  @override
  String get videoEditorFontUnknown => 'Okänt';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Uppspelningshuvudet måste vara inom det valda klippet för att dela.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Trimma start';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Trimma slut';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Trimma klipp';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Dra handtagen för att justera klippets längd';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Drar klipp $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Klipp $index av $total, $duration sekunder';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'Håll ned för att ordna om';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Flytta vänster';

  @override
  String get videoEditorTimelineClipMoveRight => 'Flytta höger';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Klipp $index av $total, markerat';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Klipp $index av $total, inte markerat';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Markera';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Markera flera klipp';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Slutför markering';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp markerade',
      one: '1 klipp markerat',
      zero: 'Inga klipp markerade',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Välj flera teckningar';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Klar med att välja teckningar';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Ta bort valda teckningar';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count teckningar valda',
      one: '1 teckning vald',
      zero: 'Inga teckningar valda',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Slå samman';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Slå samman markerade klipp';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Ta bort markerade klipp';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Ta bort markerade bildrutor';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Vänd markerade bildrutor';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplicera markerade bildrutor';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Din video måste vara minst ${seconds}s – ta några bildrutor till.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Ett ögonblick, vi slår samman dina klipp';

  @override
  String get videoEditorMergeFailed =>
      'Det gick inte att slå samman klippen. Försök igen.';

  @override
  String get videoEditorTimelineLongPressToDragHint => 'Håll ned för att dra';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Videotidslinje';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, vald';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Stäng färgväljare';

  @override
  String get videoEditorPickColorTitle => 'Välj färg';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Bekräfta färg';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Mättnad och ljusstyrka';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Mättnad $saturation%, Ljusstyrka $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Nyans';

  @override
  String get videoEditorAddElementSemanticLabel => 'Lägg till element';

  @override
  String get videoEditorDoneSemanticLabel => 'Klar';

  @override
  String get videoEditorLevelSemanticLabel => 'Nivå';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Stäng inläggsdetaljer';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => 'Stäng hjälpdialog';

  @override
  String get videoMetadataGotItButton => 'Jag fattar!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Gränsen på 64KB är nådd. Ta bort innehåll för att fortsätta.';

  @override
  String get videoMetadataExpirationLabel => 'Utgång';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => 'Välj utgångstid';

  @override
  String get videoMetadataTitleLabel => 'Titel';

  @override
  String get videoMetadataDescriptionLabel => 'Beskrivning';

  @override
  String get videoMetadataTagsLabel => 'Taggar';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Ta bort tagg $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Innehållsvarning';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Välj innehållsvarningar';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Välj allt som gäller för ditt innehåll';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Låt andra spara och återanvända videons ljud.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Din video är uppe, men ljudet publicerades inte. Redigera videon för att dela ljudet.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Samarbetspartners';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Lägg till samarbetspartner';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Ömsesidiga följare';

  @override
  String get videoMetadataInspiredByLabel => 'Inspirerad av';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Ange inspirerad av';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Den här skaparen kan inte refereras.';

  @override
  String get videoMetadataPostDetailsTitle => 'Inläggsdetaljer';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Sparad i bibliotek';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Det gick inte att spara';

  @override
  String get videoMetadataGoToLibraryButton => 'Gå till bibliotek';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Knapp spara till senare';

  @override
  String get videoMetadataSavingVideoHint => 'Sparar video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Spara video till utkast och $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Spara videon som utkast. Ingen renderad video ännu, så ingen kopia läggs till i $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Spara till senare';

  @override
  String get videoMetadataPostSemanticLabel => 'Knapp publicera';

  @override
  String get videoMetadataPublishVideoHint => 'Publicera video i flödet';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Dela också i mitt flöde';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Av betyder att den här videon bara stannar i kommentarstråden.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Fyll i formuläret för att aktivera';

  @override
  String get videoMetadataPostButton => 'Publicera';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Öppna förhandsgranskningsskärm för inlägg';

  @override
  String get videoMetadataShareTitle => 'Dela';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Videodetaljer';

  @override
  String get videoMetadataClassicDoneButton => 'Klar';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Spela förhandsvisning';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Pausa förhandsvisning';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Stäng videoförhandsvisning';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Ta bort';

  @override
  String get fullscreenFeedRemovedMessage => 'Video borttagen';

  @override
  String get fullscreenFeedEmptyMessage =>
      'Det finns inget mer att spela upp här';

  @override
  String get settingsBadgesTitle => 'Märken';

  @override
  String get settingsBadgesSubtitle =>
      'Acceptera utmärkelser och kolla status på utfärdade märken.';

  @override
  String get badgesTitle => 'Märken';

  @override
  String get badgesLoadError => 'Kunde inte ladda märken';

  @override
  String get badgesUpdateError => 'Kunde inte uppdatera märke';

  @override
  String get badgesAwardedEmptyTitle => 'Inga märkesutmärkelser än';

  @override
  String get badgesAwardedEmptySubtitle =>
      'När någon tilldelar dig ett Nostr-märke landar det här.';

  @override
  String get badgesStatusAccepted => 'Accepterat';

  @override
  String get badgesStatusNotAccepted => 'Inte accepterat';

  @override
  String get badgesActionRemove => 'Ta bort';

  @override
  String get badgesActionAccept => 'Acceptera';

  @override
  String get badgesActionReject => 'Avvisa';

  @override
  String get badgesIssuedEmptyTitle => 'Inga utfärdade märken än';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Märken du utfärdar visar acceptansstatus här.';

  @override
  String get badgesIssuedNoRecipients =>
      'Inga mottagare hittades för den här utmärkelsen.';

  @override
  String get badgesRecipientAcceptedStatus => 'Accepterat av mottagare';

  @override
  String get badgesRecipientWaitingStatus => 'Väntar på mottagare';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dolda ($count)',
      one: 'Dold (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Återställ';

  @override
  String get badgesHiddenSnackbar => 'Badge dold';

  @override
  String get badgesHiddenSnackbarUndo => 'Ångra';

  @override
  String get badgesTabAwarded => 'Mottagna';

  @override
  String get badgesTabCreated => 'Skapade';

  @override
  String get badgesTabIssued => 'Utdelade';

  @override
  String get badgesCreateAction => 'Ny badge';

  @override
  String get badgesCreatedEmptyTitle => 'Inga badges gjorda än';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Gör en och ge den till någon som förtjänar den.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Utdelad till $count personer',
      one: 'Utdelad till 1 person',
      zero: 'Inte utdelad än',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Ny badge';

  @override
  String get badgeEditorEditTitle => 'Redigera badge';

  @override
  String get badgeEditorNameLabel => 'Namn';

  @override
  String get badgeEditorNameHint => 'Scenstjälaren';

  @override
  String get badgeEditorIdentifierLabel => 'Identifierare';

  @override
  String get badgeEditorIdentifierHelp =>
      'Den ingår i badgens adress, så den ligger fast när badgen väl finns.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Du har redan en badge med den här identifieraren. Redigera den i stället — att publicera här skulle ersätta den.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Varje badge behöver en identifierare — skriv en själv om namnet inte fyllde i den.';

  @override
  String get badgeEditorDescriptionLabel => 'Beskrivning';

  @override
  String get badgeEditorDescriptionHint =>
      'Till den som stjäl showen med en enda loop.';

  @override
  String get badgeEditorArtworkLabel => 'Bild';

  @override
  String get badgeEditorArtworkAdd => 'Lägg till bild';

  @override
  String get badgeEditorArtworkReplace => 'Byt ut';

  @override
  String get badgeEditorArtworkError => 'Bilden kunde inte laddas upp';

  @override
  String get badgeEditorArtworkRequired => 'Varje badge behöver en bild.';

  @override
  String get badgeEditorArtworkRemove => 'Ta bort bilden';

  @override
  String get badgeEditorArtworkSheetTitle => 'Badgebild';

  @override
  String get badgeDetailDeleteAction => 'Ta bort badge';

  @override
  String get badgeDetailDeleteTitle => 'Ta bort den här badgen?';

  @override
  String get badgeDetailDeleteBody =>
      'Det här ber reläerna släppa badgen och alla utdelningar du gjort. Reläer kan neka, och den som fäst den behåller den på sin profil tills den tas bort.';

  @override
  String get badgeDetailDeleteConfirm => 'Ta bort';

  @override
  String get badgeEditorSaveAction => 'Publicera badge';

  @override
  String get badgeEditorSaveError => 'Badgen kunde inte publiceras';

  @override
  String get badgeEditorLoadError => 'Den här badgen kunde inte laddas';

  @override
  String get badgeDetailTitle => 'Badge';

  @override
  String get badgeDetailMadeBy => 'Skapad av';

  @override
  String get badgeDetailRecipientsTitle => 'Utdelad till';

  @override
  String get badgeDetailNoRecipients => 'Ingen har den här än.';

  @override
  String get badgeDetailAwardAction => 'Dela ut den här badgen';

  @override
  String get badgeDetailEditAction => 'Redigera badge';

  @override
  String get badgeDetailShareAction => 'Dela';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Kolla in den här badgen på Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Ta tillbaka badgen';

  @override
  String get badgeDetailRevokeTitle => 'Ta tillbaka den här badgen?';

  @override
  String get badgeDetailRevokeBody =>
      'Det här ber reläerna släppa utdelningen du gjorde till den här personen. Reläer kan neka, och om badgen redan är fäst ligger den kvar på profilen tills personen tar bort den. Hen får inget besked oavsett.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Det här ber reläerna släppa utdelningen du gjorde till dig själv och tar bort badgen från din profil. Nekar reläerna borttagningen händer ingenting.';

  @override
  String get badgeDetailRevokeConfirm => 'Ta tillbaka';

  @override
  String get badgeDetailRevokeSuccess => 'Badgen är tillbakatagen';

  @override
  String get badgeDetailBlockClaimantsAction =>
      'Blockera alla med den här badgen';

  @override
  String get badgeDetailBlockClaimantsTitle =>
      'Blockera alla med den här badgen';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Kunde inte ladda vilka som har den här badgen';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Ingen har den här badgen just nu';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Vi hittade ingen att blockera just nu.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blockera $count konton?',
      one: 'Blockera 1 konto?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Det här blockerar de $count konton som har den här badgen just nu. Deras inlägg visas inte i dina flöden och de meddelas inte.',
      one:
          'Det här blockerar kontot som har den här badgen just nu. Deras inlägg visas inte i dina flöden och de meddelas inte.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blockera $count konton',
      one: 'Blockera 1 konto',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Konton med badgen blockerade';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Kunde inte blockera kontona med badgen';

  @override
  String get badgeDetailLoadError => 'Den här badgen kunde inte laddas';

  @override
  String get badgeDetailMissing => 'Vi hittar inte badgen på något relä.';

  @override
  String get badgeDetailActionError => 'Det gick inte';

  @override
  String get badgeAwardTitle => 'Dela ut badge';

  @override
  String get badgeAwardPickAction => 'Välj personer';

  @override
  String get badgeAwardManualLabel => 'Eller klistra in nycklar';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Välj minst en person.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dela ut till $count personer',
      one: 'Dela ut till 1 person',
      zero: 'Dela ut badge',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Utdelad av';

  @override
  String get profileBadgeRecipients => 'Mottagare';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count till';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Märket $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Märke';

  @override
  String get profileBadgeFooterBody =>
      'Märken är små utmärkelser som vem som helst kan skapa på Nostr. Ge ett till en vän, en kreatör eller någon som gjorde din dag.';

  @override
  String get profileBadgeFooterLink => 'Gör din egen badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Familjeguide';

  @override
  String get minorAccountReviewWelcomeTitle => 'Inte 16 än? Det är okej.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Att du klickade dig vidare till den här sidan i stället för att bara välja svaret som släppte in dig – det betyder något. Det visar ärlighet, ryggrad och en genuin omtanke om människorna runt dig.\n\nReglerna för den som är under 16 skiljer sig åt beroende på var du bor. På Divine vill vi att familjer pratar igenom det tillsammans och bestämmer hur ett sunt användande av sociala medier ser ut.';

  @override
  String get minorAccountReviewModerationTitle => 'Vi behöver ett steg till';

  @override
  String get minorAccountReviewModerationBody =>
      'Vi ombads titta närmare på det här kontot eftersom det kan tillhöra någon under 16 år. Det här flödet håller nästa steg privata och pekar dig mot rätt väg för din ålder.';

  @override
  String get minorAccountReviewRulesTitle => 'Reglerna är inte lika överallt';

  @override
  String get minorAccountReviewRulesBody =>
      'Olika länder och regioner ser olika på tonåringars användning av sociala medier. Därför ber vi familjer att sakta ner, kolla fakta och välja nästa steg tillsammans.';

  @override
  String get minorAccountReviewApproachTitle => 'Så tänker Divine';

  @override
  String get minorAccountReviewApproachBody =>
      'Vi tror att sunda tekniska vanor kommer av att pausa, reflektera och rikta om uppmärksamheten mot bättre saker – inte av att spionera på barn eller göra föräldrar till vakter. Forskningen håller med.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Mer för familjer';

  @override
  String get minorAccountReviewKidsPolicyCta => 'Läs Divines barnpolicy';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Välj vägen som passar';

  @override
  String get minorAccountReviewUnder13Cta => 'Under 13';

  @override
  String get minorAccountReviewTeenCta => '13–15 år';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Besök Divines familjeguide för praktiska tips, samtalsverktyg och material som hjälper tonåringar att använda sociala medier tryggare.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Hämta familjeguider och tips';

  @override
  String get minorAccountReviewFooter =>
      'Om du är 16 eller äldre och hamnade här av misstag, kontakta Divines support så att en riktig människa kan titta på det.';

  @override
  String get minorAccountReviewTitle => 'Kontogranskning';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Kontrollerar kontostatus...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Vänta medan vi bekräftar kontots nuvarande granskningsstatus.';

  @override
  String get minorAccountReviewDefaultTitle => 'Kontogranskning krävs';

  @override
  String get minorAccountReviewDefaultBody =>
      'Vi behöver granska det här kontot innan det kan använda Divine som vanligt.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Ärende-ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Ärende-ID';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'Vad som är begränsat just nu';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Att posta och publicera är pausat';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Kommentarer, gillningar, reposter och följningar är pausade';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Att starta och svara på vanliga meddelanden är pausat';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Support och ditt modereringsmeddelande är fortfarande tillgängliga';

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
  String get minorAccountReviewOpenSupportCenter => 'Öppna supportcentret';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Öppna modereringsmeddelandet';

  @override
  String get minorAccountReviewOpenReviewPage => 'Öppna granskningssidan';

  @override
  String get minorAccountReviewCheckAgain => 'Kontrollera igen';

  @override
  String get minorAccountReviewLogOut => 'Logga ut';

  @override
  String get minorAccountReviewNextStepTitle => 'Nästa steg';

  @override
  String get minorAccountReviewNextStepBody =>
      'Öppna supportcentret eller ditt modereringsmeddelande om du behöver hjälp med granskningen.';

  @override
  String get minorAccountReviewInProgressTitle => 'Granskning pågår';

  @override
  String get minorAccountReviewInProgressBody =>
      'Vi har det vi behöver för tillfället. Vårt team går igenom ärendet innan kontot får tillbaka normal åtkomst.';

  @override
  String get minorAccountReviewUnder13Title => 'Konton under 13 år';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Om det här kontot tillhör någon under 13 måste en förälder eller vårdnadshavare mejla $supportEmail och ange ärende-ID.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Vi kan inte ge dig ett konto än';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine är inte byggt för barn under 13, och reglerna för sociala medier runt om i världen binder våra händer.\n\nMycket på internet pressar dig att ljuga för att få det du vill ha, och det avskyr vi. Det är fel läxa för livet, och den tänker vi inte lära ut här.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Vad din familj kan göra i stället';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'En förälder eller vårdnadshavare kan ha kontot och sköta postandet – och du får absolut vara med i videorna. Vi vill att familjer får njuta av Divine på det sätt som passar dem.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'När du fyller 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Beroende på reglerna där du bor kan du kanske komma tillbaka och ansöka om ett eget konto. Är du då mellan 13 och 15 behöver du samtycke från en förälder eller vårdnadshavare.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Varför vi inte säger åt dig att bara klicka tillbaka';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Mycket av internet är byggt för att belöna folk som säger vad som helst för att ta sig igenom grinden. Vi tycker inte att det är bra. Visst, du skulle kunna gå tillbaka och säga att du är äldre än du är, men det vore inte ärligt, och vi tänker inte lära dig att ljuga för att få som du vill.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Vi försöker hjälpa unga att använda Divine på sätt som är hälsosamma och positiva för dem och för människorna omkring dem. Vi måste också följa lagar som skiljer sig åt på olika platser. Så om du är under 13 är svaret att du inte kan ha ett eget konto i dag.';

  @override
  String get minorAccountReviewTeenBody =>
      'Om kontot tillhör någon mellan 13 och 15 år, använd modereringsmeddelandet eller supportvägen för att följa instruktionerna om föräldrasamtycke.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Om kontot ska tillhöra någon mellan 13 och 15 år';

  @override
  String get minorAccountReviewParentConsentBody =>
      'En förälder eller vårdnadshavare ska mejla Divines support med en kort privat video. Vårt team granskar den och hjälper till med nästa steg.\n\nOm det inte går att kontakta en förälder eller vårdnadshavare, eller om det skulle utsätta någon för risk, mejla Divines support och berätta det för oss.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Det här är en paus medan Divines supportteam granskar videon. Om den godkänns guidar de dig genom att sätta upp det nya kontot.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Varför vi ber en förälder eller vårdnadshavare att vara delaktig';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine måste följa åldersrelaterade lagar runt om i världen. Vi vet också att de flesta tekniska ålderskontroller är bristfälliga. I stället för att låtsas att reglerna inte finns eller att det är coolt att ljuga om sin ålder vill vi att tonåringar och familjer ska fatta genomtänkta beslut om hur Divine bäst används. Därför ber vi föräldrar att vara en del av kontoskapandet för 13–15-åringar.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Vi måste också följa lagen, och de reglerna skiljer sig åt beroende på var man bor. Så i stället för att låtsas att reglerna inte finns ber vi en förälder eller vårdnadshavare att vara en del av processen.';

  @override
  String get minorAccountReviewParentConsentChecklist => 'Vad videon ska visa';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Tonåringen i videon';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'En förälder eller vårdnadshavare som pratar i kameran';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Ett tydligt uttalande om att tonåringen är 13 till 15 år och har tillåtelse att använda Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Ett tydligt uttalande om att föräldern eller vårdnadshavaren känner till kontot och kommer att ha uppsikt över användningen';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Så skickar du den';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Bifoga videon när du mejlar Divines support';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Håll videon privat och posta den inte i appen';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Vårt team granskar den och svarar med nästa steg';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Mejla Divines support';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Hjälp med Divine Greenlight-granskning (13–15 år)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hej Divine-support,\n\njag hör av mig om Divine Greenlight för en tonåring som är 13–15 år.\n\nJag har bifogat en kort privat video som visar:\n- tonåringen\n- en förälder eller vårdnadshavare som pratar i kameran\n- att tonåringen har tillåtelse att använda Divine\n- att föräldern eller vårdnadshavaren känner till kontot och kommer att ha uppsikt över användningen\n\nBosättningsland:\n\nBra att veta:\n\nTack.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Supportinstruktioner för föräldrar';

  @override
  String get minorAccountReviewContinue => 'Fortsätt';

  @override
  String get minorAccountReviewErrorTitle =>
      'Vi kunde inte läsa in status för din kontogranskning.';

  @override
  String get minorAccountReviewErrorBody => 'Försök igen om en stund.';

  @override
  String get minorAccountReviewTryAgain => 'Försök igen';

  @override
  String get minorAccountReviewParentContactTitle => 'Föräldrakontakt';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Lägg till en förälders eller vårdnadshavares mejl';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Vi använder den här adressen för granskningen av föräldrasamtycke i ärende $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Förälderns eller vårdnadshavarens mejl';

  @override
  String get minorAccountReviewSubmitting => 'Skickar...';

  @override
  String get minorAccountReviewSubmitEmail => 'Skicka mejlet';

  @override
  String get minorAccountReviewBackToReview =>
      'Tillbaka till kontogranskningen';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Mejlet skickat';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Vi skickade $email för granskning. Vi mejlar den adressen för att bekräfta. När din förälder eller vårdnadshavare svarar går ditt ärende vidare. Använd Kontrollera igen på kontogranskningssidan för uppdateringar.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Vi har tagit emot förälderns eller vårdnadshavarens kontaktuppgift för det här kontot. Vårt team granskar den innan åtkomsten återställs.';

  @override
  String get minorAccountReviewMissingCase =>
      'Vi hittade inget aktivt granskningsärende för det här kontot.';

  @override
  String get minorAccountReviewParentContactError =>
      'Kunde inte skicka förälderns mejladress. Försök igen.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Föräldrasupport';

  @override
  String get minorAccountReviewUnder13Heading =>
      'En förälder eller vårdnadshavare måste kontakta Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'För konton som sannolikt tillhör någon under 13 är nästa steg att en förälder eller vårdnadshavare hör av sig via mejl.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Supportmejl';

  @override
  String get minorAccountReviewCopySupportEmail => 'Kopiera supportmejlen';

  @override
  String get minorAccountReviewSupportEmailCopied => 'Supportmejlen kopierad';

  @override
  String get minorAccountReviewCopyCaseId => 'Kopiera ärende-ID';

  @override
  String get minorAccountReviewCaseIdCopied => 'Ärende-ID kopierat';

  @override
  String get minorAccountReviewUnavailable => 'Otillgängligt';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Be föräldern eller vårdnadshavaren ange ärende-ID och förklara att de kontaktar Divine om den här kontogranskningen.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Kontogranskning för under 13 år, ärende $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Hej Divine-support,\n\njag är förälder eller vårdnadshavare till ett barn under 13 år och hör av mig om kontogranskningsärende $caseId.\n\nTack.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulering av kontogranskning för minderårig';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Nuvarande status';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Begränsat ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Aktivt';

  @override
  String get devOptionsMinorReviewStateLoading => 'Läser in...';

  @override
  String get devOptionsMinorReviewStateError => 'Fel vid inläsning av status';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Rensa simuleringsöverstyrningen';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Använd backend eller standardläget aktivt igen';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      'Simulera granskningsärende 13–15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Begränsat konto med väg för föräldrakontakt';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simulera supportärende under 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Begränsat konto med instruktioner enbart via förälderns mejl';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simuleringen av kontogranskning för minderårig rensad';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Simulerat supportärende under 13 aktiverat';

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
      'Simulering av skyddad minderårig';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Nuvarande status';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Skyddad minderårig (13–15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Inte skyddad';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Läser in…';

  @override
  String get devOptionsProtectedMinorStateError => 'Fel vid läsning av status';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Ingen överstyrning (verkligt kontoläge)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Överstyrning: tvingat skyddad';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Överstyrning: tvingat inte skyddad';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simulera skyddad minderårig (13–15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Tvinga läget skyddad minderårig för att testa skydden i #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simulera myndig person';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Tvinga inte skyddad (ett uttryckligt nej, till skillnad från ingen överstyrning)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Rensa överstyrningen';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Gå tillbaka till det verkliga kontoläget från Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Läget skyddad minderårig tvingat på';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Läget skyddad minderårig tvingat av';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Överstyrningen för skyddad minderårig rensad';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Registreringsinbjudningar';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Nuvarande status';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Servervärde: läser in';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => 'Servervärde: på';

  @override
  String get devOptionsInviteAvailabilityServerDisabled => 'Servervärde: av';

  @override
  String get devOptionsInviteAvailabilityServerUnknown => 'Servervärde: okänt';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Överstyrning: använd servervärdet';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Överstyrning: tvinga på';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Överstyrning: tvinga av';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Använd servervärdet';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Följ inbjudningstjänstens onboardingMode';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Tvinga på';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Visa registreringsinbjudningarnas grindar och hantering lokalt';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Tvinga av';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Dölj gränssnittet för registreringsinbjudningar lokalt utan att ändra servern';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Registreringsinbjudningar följer nu servern';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Registreringsinbjudningar tvingade på';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Registreringsinbjudningar tvingade av';

  @override
  String get commentsRecordVideoButtonLabel => 'Spela in videokommentar';

  @override
  String get commentsOpenVideoLabel => 'Öppna videokommentar';

  @override
  String get commentsMuteVideoReplyLabel => 'Tysta videosvar';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Slå på ljud för videosvar';

  @override
  String get commentsOpenReplyParentLabel => 'Öppna videon som detta svarar på';

  @override
  String get commentsReplyParentSectionTitle => 'Som svar på';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Svar på $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Svar på video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Verifierat $platform-konto: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Verifierade konton';

  @override
  String get profileEditGetVerifiedCta => 'Verifiera dig';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Koppla dina sociala medier-konton så folk vet att det är du.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Besök webbplatsen: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Kunde inte öppna webbplatsen';

  @override
  String get videoMetadataEditCoverTitle => 'Redigera omslag';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Ignorera omslagsändringar';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Använd vald bildruta som videoomslag';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Sök igenom videon för att välja omslagsbild';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Sök eller lägg till taggar';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Lägg till taggar så att andra hittar din video';

  @override
  String get videoMetadataTagsPickerNoResults => 'Inga matchande taggar';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Lägg till ”#$tag”';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Inte 16 än? Det är okej. ';

  @override
  String get authUnder16ChoicesCta => 'Här är dina alternativ.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Här är varför';

  @override
  String get generalSettingsHoldToRecord => 'Håll inne för att spela in';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Inspelning startar när du håller inne och stannar när du släpper';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videor publicerade till din profil',
      one: 'Videon publicerad till din profil',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Skicka meddelande';

  @override
  String get emojiPickerSearchHint => 'Sök';

  @override
  String get emojiCategoryRecent => 'Senaste';

  @override
  String get emojiCategorySmileys => 'Smileys och personer';

  @override
  String get emojiCategoryAnimals => 'Djur och natur';

  @override
  String get emojiCategoryFood => 'Mat och dryck';

  @override
  String get emojiCategoryActivities => 'Aktiviteter';

  @override
  String get emojiCategoryTravel => 'Resor och platser';

  @override
  String get emojiCategoryObjects => 'Objekt';

  @override
  String get emojiCategorySymbols => 'Symboler';

  @override
  String get emojiCategoryFlags => 'Flaggor';

  @override
  String get videoEditorMarkerLabel => 'Markör';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Lägg till tidslinjemarkör';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Ta bort tidslinjemarkör';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Ta bort markör vid spelhuvudet';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Radera markör?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Detta tar bort markören från tidslinjen. Din redigering behålls.';

  @override
  String get videoEditorVolumeLongPressHint => 'Tysta eller slå på alla spår';

  @override
  String get videoEditorSplitFailed => 'Delning misslyckades. Försök igen.';

  @override
  String get videoEditEditSubtitles => 'Redigera undertexter';

  @override
  String get subtitleEditorTitle => 'Redigera undertexter';

  @override
  String get subtitleEditorSave => 'Spara';

  @override
  String get subtitleEditorProcessing =>
      'Undertexter genereras fortfarande. Kom tillbaka om en stund.';

  @override
  String get subtitleEditorNoSpeech =>
      'Inget tal hittades i den här videon, så det finns inget att texta.';

  @override
  String get subtitleEditorWriteOwn => 'Skriv dem själv';

  @override
  String get subtitleEditorAddCue => 'Lägg till en rad';

  @override
  String get subtitleEditorRemoveCue => 'Ta bort den här raden';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Videon går inte att spela upp just nu, men du kan ändå fixa undertexterna.';

  @override
  String get subtitleEditorPlayPreview => 'Spela upp videon';

  @override
  String get subtitleEditorPausePreview => 'Pausa videon';

  @override
  String get subtitleEditorInvalidHint =>
      'Varje rad behöver text och ett slut efter sin start.';

  @override
  String get subtitleEditorLoadError =>
      'Kunde inte läsa in undertexter. Försök igen.';

  @override
  String get subtitleEditorSaveSuccess => 'Undertexter uppdaterade';

  @override
  String get subtitleEditorSaveError =>
      'Kunde inte spara undertexter. Försök igen.';

  @override
  String get subtitleEditorRetry => 'Försök igen';

  @override
  String get subtitleEditorCueHint => 'Textningstext';

  @override
  String get imageCropEditorRotateLabel => 'Rotera';

  @override
  String get imageCropEditorFlipLabel => 'Vänd';

  @override
  String get imageCropEditorResetLabel => 'Återställ';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Avbryt beskärning';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Använd beskärning';

  @override
  String get imageCropEditorProcessing => 'Tillämpar beskärning…';

  @override
  String get backgroundUploadNotificationTitle => 'Laddar upp video';

  @override
  String get monetizationSettingsTitle => 'Stöd till kreatörer';

  @override
  String get monetizationSettingsSubtitle =>
      'Lägg till länkar för dricks och prenumeration';

  @override
  String get monetizationSettingsIntroTitle => 'Bara externa länkar';

  @override
  String get monetizationSettingsIntroBody =>
      'Lägg till destinationer som du själv styr över. Divine hanterar aldrig betalningen och låser inte upp innehåll i appen via de här länkarna.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktiva länkar på din profil',
      one: '1 aktiv länk på din profil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Skicka dricks';

  @override
  String get monetizationSettingsSubscriptionSection => 'Prenumerera / stötta';

  @override
  String get monetizationSettingsSave => 'Spara stödlänkar';

  @override
  String get monetizationSettingsSaving => 'Sparar...';

  @override
  String get monetizationSettingsSaved => 'Stödlänkarna uppdaterade';

  @override
  String get monetizationSettingsSaveFailed =>
      'Kunde inte spara stödlänkarna. Kontrollera anslutningen och försök igen.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'Lägg till ett handtag eller en URL.';

  @override
  String get monetizationSettingsErrorInvalid => 'Den länken ser inte rätt ut.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Använd en länk för den här tjänsten.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag eller cash.app-länk';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me-handtag eller länk';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo-handtag eller länk';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon-handtag eller länk';

  @override
  String get monetizationSettingsHintSubstack => 'Substack-domän eller länk';

  @override
  String get monetizationSettingsHintMedium => 'Medium-handtag eller länk';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective-slug eller länk';

  @override
  String get profileSupportSheetTitle => 'Stötta den här kreatören';

  @override
  String get profileSupportSheetBody =>
      'De här länkarna öppnas utanför Divine. Inget här låser upp innehåll i appen.';

  @override
  String get profileSupportTipSection => 'Skicka dricks';

  @override
  String get profileSupportSubscriptionSection => 'Prenumerera / stötta';

  @override
  String get profileSupportButtonLabel => 'Stötta';

  @override
  String get monetizationTipsSettingsTitle => 'Dricks';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Lägg till valfria dricks-länkar';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Bara frivillig dricks';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Dricks är frivilliga gåvor mellan användare. De låser inte upp innehåll, prenumerationer, funktioner, ranking, synlighet eller åtkomst i Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktiva dricks-länkar på din profil',
      one: '1 aktiv dricks-länk på din profil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Spara dricks-länkar';

  @override
  String get monetizationTipsSettingsSaved => 'Dricks-länkarna uppdaterade';

  @override
  String get profileTipButtonLabel => 'Dricks';

  @override
  String get profileTipSheetTitle => 'Ge dricks till den här kreatören';

  @override
  String get profileTipSheetBody =>
      'Dricks-länkar öppnas utanför Divine. De är frivilliga och låser inte upp innehåll, prenumerationer, funktioner eller åtkomst i Divine.';

  @override
  String get settingsStorageTitle => 'Lagring';

  @override
  String get settingsStorageCacheSectionTitle => 'Cachad media';

  @override
  String get settingsStorageCacheDescription =>
      'Cachade flödesvideor, miniatyrer och tillfälliga renderingar. Att rensa dem är säkert – de laddas ner eller skapas igen vid behov.';

  @override
  String get settingsStorageMeasuring => 'Beräknar…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size används';
  }

  @override
  String get settingsStorageClearButton => 'Rensa cache';

  @override
  String get settingsStorageClearConfirmTitle => 'Rensa cachad media?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Detta frigör $size. Ditt klippbibliotek påverkas inte.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Rensa';

  @override
  String get settingsStorageCleared => 'Cache rensad';

  @override
  String get settingsStorageLibrarySectionTitle => 'Klippbibliotek';

  @override
  String get settingsStorageLibraryDescription =>
      'Sök efter trasiga klipp vars videofil saknas.';

  @override
  String get settingsStorageScanButton => 'Kontrollera bibliotek';

  @override
  String get settingsStorageLibraryHealthy => 'Inga trasiga klipp hittades';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Trasiga klipp hittade: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Ta bort trasiga klipp';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Trasiga klipp borttagna';

  @override
  String get settingsStorageError => 'Något gick fel';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Maximal videocache';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count videor';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Ta bort trasiga klipp?';

  @override
  String get settingsStorageRepairSectionTitle => 'Reparera installationen';

  @override
  String get settingsStorageRepairDescription =>
      'Om appen kraschar eller beter sig konstigt brukar en återställning av lokala data lösa det. Dina klipp och utkast finns kvar.';

  @override
  String get settingsStorageRepairButton => 'Återställ appdata';

  @override
  String get settingsStorageRepairConfirmTitle => 'Återställa appdata?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Det här raderar cachad flödesdata och tillfälliga filer. Dina klipp, utkast, inställningar och inloggning finns kvar, men du måste starta om appen efteråt.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size tas bort';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Återställ';

  @override
  String get settingsStorageRepairInProgress => 'Återställer…';

  @override
  String get settingsStorageRepairSuccess =>
      'Klart — starta om appen för att slutföra.';

  @override
  String get settingsStorageRepairFailure =>
      'Kunde inte återställa allt. Försök igen efter en omstart.';

  @override
  String get nostrSettingsSignatureVerification => 'Signaturverifiering';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Välj när Divine kontrollerar signaturer för relay-händelser. Händelse-ID:n valideras alltid först.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Alla relays';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Säkrast. Verifiera signaturen för varje relay-händelse.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Ej betrodda relays';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Hoppa över kontroller för relays som redan finns i din konfigurerade pool.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Icke-Divine-relays';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Lita på Divine-relays, verifiera resten.';

  @override
  String get settingsCrosspostingTitle => 'Korspostning';

  @override
  String get settingsCrosspostingSubtitle =>
      'Dela dina videor till andra plattformar';

  @override
  String get crosspostingSignInRequired =>
      'Logga in med Divine för att hantera korspostning';

  @override
  String get crosspostingLoadFailed =>
      'Det gick inte att läsa in dina korspostningsinställningar';

  @override
  String get crosspostingNoPlatforms =>
      'Inga korspostningsplattformar är tillgängliga just nu';

  @override
  String get crosspostingRetry => 'Försök igen';

  @override
  String get crosspostingNotConnected => 'Inte ansluten';

  @override
  String get crosspostingConnected => 'Ansluten';

  @override
  String get crosspostingNeedsReconnect => 'Behöver återanslutas';

  @override
  String get crosspostingConnect => 'Anslut';

  @override
  String get crosspostingReconnect => 'Återanslut';

  @override
  String get crosspostingDisconnect => 'Koppla från';

  @override
  String get crosspostingModeOff => 'Av';

  @override
  String get crosspostingModeManual => 'Manuellt';

  @override
  String get crosspostingModeManualSubtitle => 'Du väljer för varje video';

  @override
  String get crosspostingModeAutomatic => 'Automatiskt';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Framtida videor postas automatiskt — bara videor du publicerar efter att du slagit på det här';

  @override
  String get crosspostingNotConnectedError =>
      'Anslut den här plattformen först för att ändra hur den postar.';

  @override
  String get crosspostingGenericError => 'Något gick fel. Försök igen.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Vi hörde aldrig något från inloggningssidan. Om du blev klar där, uppdatera — ditt konto kan redan vara länkat.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform anslutet';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Det gick inte att ansluta $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Anslutningen avbröts på $platform';
  }

  @override
  String get supporterTitle => 'Divine-supportrar';

  @override
  String get supporterTileSubtitle =>
      'Stöd Divine med en valfri månadsprenumeration.';

  @override
  String get supporterHeroTitle => 'Håll Divine igång';

  @override
  String get supporterHeroBody =>
      'Divine är gratis och kommer alltid att vara det. Om du vill hjälpa oss att hålla looparna igång, bli månadssupporter. Inget är låst – det håller bara ljusen tända och ger dig vår tacksamhet.';

  @override
  String get supporterActiveBadge =>
      'Du är Divine-supporter. Tack för att du håller det här igång.';

  @override
  String get supporterPurchasePending => 'Ditt köp väntar på godkännande.';

  @override
  String get supporterPurchaseConfirming => 'Bekräftar ditt stöd…';

  @override
  String get supporterStoreChecking => 'Kollar butiken…';

  @override
  String get supporterUnavailable =>
      'Supporter-prenumerationer är inte tillgängliga här just nu.';

  @override
  String get supporterRestorePurchases => 'Återställ köp';

  @override
  String get supporterDismissError => 'Stäng felmeddelandet';

  @override
  String get supporterErrorStoreUnavailable =>
      'Butiken är inte tillgänglig på den här enheten.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Köpet slutfördes inte. Du har inte debiterats.';

  @override
  String get supporterErrorPurchasePending => 'Ditt köp väntar på godkännande.';

  @override
  String get supporterErrorRestoreFailed =>
      'Ingen supporter-prenumeration hittades att återställa.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Det här köpet tillhör ett annat Divine-konto.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine kunde inte bekräfta supporterstatus just nu.';

  @override
  String get supporterErrorUnknown => 'Något gick fel. Försök igen.';

  @override
  String get supporterDisclaimer =>
      'Divine bekräftar supporterstatus efter att butiken verifierat ditt köp. Erkännande är valfritt, och glorian är ingen verifiering.';

  @override
  String get profileNotifyBellOff => 'Meddela om nya vines';

  @override
  String get profileNotifyBellOn => 'Sluta meddela om nya vines';

  @override
  String get profileNotifyUpdateFailed => 'Kunde inte sparas. Försök igen?';

  @override
  String get savedSoundYourLabel => 'Din etikett';

  @override
  String get savedSoundAddHashtags => 'Lägg till hashtaggar';

  @override
  String get savedSoundDeviceOnly => 'Sparat på den här enheten';

  @override
  String get savedSoundDetailsRetry =>
      'Kunde inte spara de uppgifterna. Tryck för att försöka igen.';

  @override
  String get savedSoundFallbackTitle => 'Sparat ljud';

  @override
  String get savedSoundPreviewAction => 'Lyssna på ljudet';

  @override
  String get savedSoundEditAction => 'Redigera ljudets uppgifter';

  @override
  String get savedSoundRemoveAction => 'Ta bort sparat ljud';

  @override
  String get savedSoundClearHashtagFilter => 'Rensa hashtaggfiltret';

  @override
  String get soundAllowRemix => 'Låt andra remixa det här ljudet';

  @override
  String get soundReuseUnavailable =>
      'Det här ljudet går inte att remixa just nu.';

  @override
  String get soundPublicCredit => 'Offentlig ljudkreditering';

  @override
  String get soundCreditRequired =>
      'Lägg till offentlig ljudkreditering innan du postar.';

  @override
  String get soundSharedAs => 'Delat som';

  @override
  String get soundOwnWork => 'Jag gjorde det här ljudet';

  @override
  String soundCreatorBy(String creator) {
    return 'Av $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Delat av $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remixning tillåten';

  @override
  String get soundCreditOnly => 'Endast kreditering';

  @override
  String get soundCreditTitleLabel => 'Ljudets titel';

  @override
  String get soundCreditCreatorLabel => 'Skapare';

  @override
  String get soundCreditSourceUrlLabel => 'Käll-URL';

  @override
  String get soundCreditPublicHashtagsLabel => 'Offentliga hashtaggar';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel => 'Avbryt taggval';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Använd valda taggar';

  @override
  String get userPickerCancelSemanticLabel => 'Avbryt användarval';

  @override
  String get userPickerConfirmSemanticLabel => 'Bekräfta valda användare';

  @override
  String get userPickerClearSelectionSemanticLabel => 'Rensa användarval';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Avbryt val av innehållsvarningar';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Använd valda innehållsvarningar';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Stäng videoredigeraren';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Fortsätt till inläggsinformation';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Ignorera ändringar i $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Tillämpa ändringar i $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Ta bort ljud';

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
  String get verifyTitle => 'Verifierade konton';

  @override
  String get verifySignedOutMessage => 'Logga in för att länka dina konton.';

  @override
  String get verifyIntro =>
      'Länka konton du redan har, så syns det att det verkligen är du.';

  @override
  String get verifyLoadFailed => 'Kunde inte ladda dina länkar.';

  @override
  String get verifyRetry => 'Försök igen';

  @override
  String get verifyLinkedSectionTitle => 'Länkade';

  @override
  String get verifyVerifierUnreachable =>
      'Verifieraren gick inte att nå, så allt visas som okontrollerat.';

  @override
  String get verifyAddSectionTitle => 'Lägg till ett konto';

  @override
  String get verifyAllPlatformsLinked => 'Du har länkat allt vi stöder.';

  @override
  String get verifyStatusVerified => 'Verifierat';

  @override
  String get verifyStatusUnverified => 'Inte verifierat';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Ta bort länken till $platform-kontot $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Ta bort länken till $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity visas inte längre på din profil. Du kan länka kontot igen senare, men då behöver du logga in på nytt eller posta ett nytt bevis.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Ta bort länken';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Länka ditt $platform-konto';
  }

  @override
  String get verifyOneTapBadge => 'Ett tryck';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Logga in på $platform så sköter vi resten. Inget publiceras.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Fortsätt med $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Eller posta ett bevis';

  @override
  String get verifyConnectProofExplainer =>
      'Posta din npub på ditt konto och klistra sedan in länken till inlägget.';

  @override
  String get verifyNpubLabel => 'Din npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Kopiera din npub';

  @override
  String get verifyNpubCopied => 'npub kopierad';

  @override
  String get verifyIdentityLabel => 'Kontonamn';

  @override
  String get verifyProofLabel => 'Länk till ditt inlägg';

  @override
  String get verifyConnectProofCta => 'Kolla och länka';

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
      'Nådde inte verifieraren. Försök igen om en stund.';

  @override
  String get verifyErrorOauthFailed => 'Det gick inte igenom. Testa igen.';

  @override
  String get verifyErrorHandleRequired => 'Fyll i ditt handle först.';

  @override
  String get verifyErrorPublishFailed =>
      'Verifierat, men ingen relä tog emot uppdateringen. Försök igen.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Inloggning med ett tryck är inte uppsatt för den här än. Använd beviset nedan.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Skapa en publik gist med din npub i första filen och klistra in gist-länken.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Posta din npub i en Discord-kanal som vår bot kan läsa och klistra in meddelandelänken. En serverinbjudan bevisar ingenting.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tweeta din npub från det kontot och klistra in länken till tweeten.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Posta din npub från det kontot och klistra in länken. Kontonamnet behöver instansen — mastodon.social/@alice, inte bara alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Det är kanalen som länkas, inte ditt Telegram-konto. Den behöver först en publik länk (Telegram gör nya kanaler privata). Posta din npub där och klistra in meddelandelänken.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Loggade du in ovanför? Då behövs inget mer. Annars postar du din npub och klistrar in länken till inlägget.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Skriv din npub i en videotext och klistra in länken till videon.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Skriv din npub i en videobeskrivning och klistra in länken till videon.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform är länkat.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Det där är en privat kanal eller en inbjudan. Ge kanalen en publik länk och klistra sedan in meddelandelänken.';

  @override
  String get verifyErrorRemoveFailed =>
      'Kunde inte ta bort länken. Försök igen.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Vi kunde inte läsa dina nuvarande länkar, så inget ändrades. Kolla anslutningen och försök igen.';

  @override
  String get verifyChannelLabel => 'Kanalnamn';

  @override
  String get verifyHowItWorksTitle => 'Hur funkar det?';

  @override
  String get verifyHowItWorksIntro =>
      'Tänk på det som ett handslag mellan två konton:';

  @override
  String get verifyHowItWorksYourSide =>
      'Din Divine-profil säger: ”Jag är @alice på Twitter.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Ditt Twitter-konto bekräftar: ”Ja, den Divine-profilen är min.”';

  @override
  String get verifyHowItWorksBothSides =>
      'Vi kollar båda sidorna. Stämmer de är du verifierad. Ingen kan fejka det – namn och bild går att kopiera, att posta från ditt riktiga konto gör det inte.';

  @override
  String get verifyHowItWorksOwnership =>
      'Länkarna ligger på din egen Nostr-identitet, så du kan ta bort dem härifrån när du vill.';

  @override
  String get generalSettingsSectionIdentity => 'Identitet';

  @override
  String get libraryFilterAll => 'Alla';

  @override
  String get libraryFilterArchive => 'Arkiv';

  @override
  String get libraryFilterDeleted => 'Borttagna';

  @override
  String get libraryCategoryNewChipLabel => 'Ny';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Skapa en kategori';

  @override
  String get libraryCategoryCreateTitle => 'Ny kategori';

  @override
  String get libraryCategoryCreateAction => 'Skapa';

  @override
  String get libraryCategoryRenameTitle => 'Byt namn på kategorin';

  @override
  String get libraryCategoryRenameAction => 'Byt namn';

  @override
  String get libraryCategoryDeleteAction => 'Ta bort kategorin';

  @override
  String get libraryCategoryNameLabel => 'Kategorins namn';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Ta bort ”$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Dina klipp blir kvar. De flyttas bara tillbaka till Alla.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Byt namn på eller ta bort den här kategorin';

  @override
  String get libraryCategoryMoveTitle => 'Flytta till';

  @override
  String get libraryCategoryMoveNone => 'Ingen kategori';

  @override
  String get libraryCategoryMoveNewCategory => 'Ny kategori';

  @override
  String get libraryArchiveAction => 'Arkivera';

  @override
  String get libraryUnarchiveAction => 'Avarkivera';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Behåll i de här kategorierna?',
      one: 'Behåll i den här kategorin?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Behåll i $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'Behåll i kategorierna';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Ta bort från $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Ta bort från kategorierna';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Flytta valda klipp';

  @override
  String get libraryCategoryEmptyTitle => 'Inget här än';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Välj några klipp och flytta dem till den här kategorin.';

  @override
  String get libraryArchiveEmptyTitle => 'Inget arkiverat';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Arkiverade klipp väntar här, utanför ditt vanliga bibliotek.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp flyttade till $name',
      one: '1 klipp flyttat till $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp borta från sin kategori',
      one: '1 klipp borta från sin kategori',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp arkiverade',
      one: '1 klipp arkiverat',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp tillbaka i biblioteket',
      one: '1 klipp tillbaka i biblioteket',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Byt e-post';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Flytta kontot till en annan adress';

  @override
  String get accountSettingsChangePassword => 'Byt lösenord';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Välj ett nytt lösenord för inloggning';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Din session tog slut. Logga in igen för att göra ändringen.';

  @override
  String get accountCredentialsRateLimited =>
      'För många försök. Vänta några minuter.';

  @override
  String get accountCredentialsNetwork =>
      'Vi nådde inte Divine. Kolla din uppkoppling och försök igen.';

  @override
  String get accountCredentialsUnknown => 'Det gick inte. Försök igen.';

  @override
  String get changePasswordSubtitle =>
      'Skriv ditt nuvarande lösenord och välj sedan ett nytt.';

  @override
  String get changePasswordCurrentLabel => 'Nuvarande lösenord';

  @override
  String get changePasswordWrongCurrent =>
      'Det är inte ditt nuvarande lösenord.';

  @override
  String get changePasswordSuccess => 'Lösenordet är ändrat.';

  @override
  String get changeEmailSubtitle =>
      'Vi mejlar en bekräftelselänk till din nya adress och till den på kontot. E-postadressen byts när du bekräftat från båda.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'På ditt konto: $email';
  }

  @override
  String get changeEmailNewLabel => 'Ny e-post';

  @override
  String get changeEmailPasswordLabel => 'Ditt lösenord';

  @override
  String get changeEmailSameAsCurrent => 'Det är redan din e-postadress.';

  @override
  String get changeEmailWrongPassword => 'Det är inte ditt lösenord.';

  @override
  String get changeEmailSubmit => 'Skicka bekräftelselänkar';

  @override
  String get changeEmailSentTitle => 'Två länkar är på väg';

  @override
  String changeEmailSentMessage(String email) {
    return 'Bekräfta från $email och från adressen på ditt konto. E-posten byts när båda är klara.';
  }

  @override
  String get changeEmailSentExpiry =>
      'Länkarna slutar fungera efter 24 timmar.';

  @override
  String get changeEmailSentDone => 'Okej';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount videor',
      one: '$formattedCount video',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Ömsesidigt';

  @override
  String get socialProofFollowsYou => 'Följer dig';

  @override
  String get socialProofYouFollow => 'Du följer';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount följare',
      one: '$formattedCount följare',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Videor laddas inte just nu.\nDet är vårt fel, inte ditt – vi jobbar på det.';

  @override
  String get feedOfflineMessage =>
      'Du är offline.\nKolla din anslutning och försök igen.';

  @override
  String get dbFailureTitle => 'kunde inte låsa upp din lokala databas';

  @override
  String get dbFailureAdviceResettable =>
      'En omstart löser inte det här. Att återställa den lokala databasen nedan ger Divine en ren start — ditt konto finns kvar.';

  @override
  String get dbFailureAdviceRestart =>
      'Starta om Divine när du har låst upp din enhet. Om det fortsätter, uppdatera appen eller kontakta supporten.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Försök att starta om Divine en gång. Om det fortsätter, uppdatera appen eller kontakta supporten. Dina lokala data finns fortfarande kvar.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostik: $code';
  }

  @override
  String get dbFailureCloseApp => 'stäng Divine';

  @override
  String get dbFailureResetAction => 'återställ lokal databas';

  @override
  String get dbFailureConfirmTitle => 'återställa din lokala databas?';

  @override
  String get dbFailureConfirmBody =>
      'Ditt konto finns kvar. Utkast och klipp som sparats på den här enheten raderas — meddelanden och flöden hämtas tillbaka från nätverket.';

  @override
  String get dbFailureResetConfirm => 'återställ lokal databas nu';

  @override
  String get dbFailureCancel => 'avbryt';

  @override
  String get dbFailureResetFailed =>
      'Det fungerade inte. Stäng Divine och försök igen.';

  @override
  String get dbFailureResetDoneTitle => 'lokal databas återställd';

  @override
  String get dbFailureResetDoneBody =>
      'Stäng Divine och öppna det igen — nästa start skapar en ny lokal databas.';

  @override
  String get authSignInOptionsInfo => 'Om inloggningsalternativ';

  @override
  String get authShowPassword => 'Visa lösenord';

  @override
  String get authHidePassword => 'Dölj lösenord';

  @override
  String get followUserSemanticLabel => 'Följ användare';

  @override
  String get unfollowUserSemanticLabel => 'Sluta följa användare';

  @override
  String get commentsLoadingSemanticLabel => 'Läser in kommentarer';

  @override
  String get analyticsWindowAll => 'Alla';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Följ användare $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Sluta följa användare $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / månad';
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
      'En ny uppdatering har kommit. Kolla in den →';

  @override
  String get updateModerateTitle =>
      'Det finns en uppdatering sedan du kollade senast';

  @override
  String get updateUrgentTitle => 'Du saknar viktiga korrigeringar';

  @override
  String get updateNotNow => 'Inte nu';

  @override
  String get updateAction => 'Uppdatera';

  @override
  String updateNewIn(String version) {
    return 'Nytt i $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Uppdatering tillgänglig';
}

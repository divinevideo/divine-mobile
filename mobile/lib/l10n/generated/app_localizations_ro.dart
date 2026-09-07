// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Recuperare clipuri';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Găsește înregistrări stocate în alt cont și fișiere video la care nu mai face referire nicio intrare.';

  @override
  String get devOptionsClipRecoveryScan => 'Scanează';

  @override
  String get devOptionsClipRecoveryFailure => 'Recuperarea clipurilor a eșuat';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips de clipuri',
      few: '$clips clipuri',
      one: '$clips clip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts de ciorne',
      few: '$drafts ciorne',
      one: '$drafts ciornă',
    );
    return 'Vizibile acum: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Ascunse în alte conturi';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips de clipuri',
      few: '$clips clipuri',
      one: '$clips clip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts de ciorne',
      few: '$drafts ciorne',
      one: '$drafts ciornă',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Mută în acest cont';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Fișiere fără referință: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Reconstruiește în bibliotecă';

  @override
  String get devOptionsClipRecoveryEmpty => 'Nimic de recuperat';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de clipuri recuperate',
      few: '$count clipuri recuperate',
      one: '$count clip recuperat',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Raport de recuperare copiat';

  @override
  String get devOptionsStorageFootprint => 'Spațiu ocupat';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Fiecare director în care scrie aplicația. Golirea cache-ului eliberează doar o parte.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Măsoară';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Total: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Raport de stocare copiat';

  @override
  String get devOptionsStorageFootprintFailure =>
      'Spațiul nu a putut fi măsurat';

  @override
  String get feedTuningMoreLabel => 'Mai multe ca ăsta';

  @override
  String get feedTuningLessLabel => 'Mai puține ca ăsta';

  @override
  String get feedTuningUndo => 'Anulează';

  @override
  String get dmMessageBubbleVideoReplyHint =>
      'Deschide videoclipul referențiat';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Setări';

  @override
  String get settingsSecureAccount => 'Securizează-ți contul';

  @override
  String get settingsSessionExpired => 'Sesiune expirată';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Autentifică-te din nou ca să recapeți acces complet';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Statistici pentru creatori';

  @override
  String get settingsSupportCenter => 'Centru de asistență';

  @override
  String get settingsNotifications => 'Notificări';

  @override
  String get settingsBlueskyPublishing => 'Publicare pe Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gestionează postarea încrucișată pe Bluesky';

  @override
  String get settingsNostrSettings => 'Setări Nostr';

  @override
  String get settingsIntegratedApps => 'Aplicații integrate';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Aplicații terțe aprobate care rulează în Divine';

  @override
  String get settingsExperimentalFeatures => 'Funcții experimentale';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Chestii care s-ar putea să sughițe—încearcă-le dacă ești curios.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Permisiuni de integrare';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Verifică și revocă aprobările memorate pentru integrări';

  @override
  String settingsVersion(String version) {
    return 'Versiunea $version';
  }

  @override
  String get settingsVersionEmpty => 'Versiune';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Modul dezvoltator e deja activat';

  @override
  String get settingsDeveloperModeEnabled => 'Mod dezvoltator activat!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de atingeri',
      few: '$count atingeri',
      one: 'o atingere',
    );
    return 'Încă $_temp0 ca să activezi modul dezvoltator';
  }

  @override
  String get settingsShareDivine => 'Distribuie Divine prietenilor tăi';

  @override
  String get settingsSwitchAccount => 'Schimbă contul';

  @override
  String get settingsAddAnotherAccount => 'Adaugă alt cont';

  @override
  String get settingsAccountSwitchFailed =>
      'Nu s-a putut schimba contul. Încearcă din nou.';

  @override
  String get settingsUnsavedDraftsTitle => 'Ciorne nesalvate';

  @override
  String get settingsUploadInProgressTitle => 'Încărcare în curs';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'de videoclipuri',
      few: 'videoclipuri',
      one: 'videoclip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videoclipurile rămân ca schițe',
      one: 'videoclipul rămâne ca schiță',
    );
    return 'Mai ai $count $_temp0 în curs de încărcare. Schimbarea contului oprește încărcarea — $_temp1 în acest cont.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ciorne',
      one: 'ciornă',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ciornele',
      one: 'ciorna',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'le',
      one: 'o',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'le',
      one: 'o',
    );
    return 'Ai $count $_temp0 nesalvate. Schimbarea contului âți va păstra $_temp1, dar poate vrei să $_temp2 publici sau să $_temp3 revizuiîi întâi.';
  }

  @override
  String get settingsCancel => 'Anulează';

  @override
  String get settingsSwitchAnyway => 'Schimbă oricum';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Sesiunea acelui cont a expirat. Ca să intri din nou în el, ieși din contul pe care îl folosești acum.';

  @override
  String get settingsAppVersionLabel => 'Versiunea aplicației';

  @override
  String get settingsAppLanguage => 'Limba aplicației';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (implicit pe dispozitiv)';
  }

  @override
  String get settingsAppLanguageTitle => 'Limba aplicației';

  @override
  String get settingsAppLanguageDescription =>
      'Alege limba pentru interfața aplicației';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Folosește limba dispozitivului';

  @override
  String get settingsGeneralTitle => 'Setări generale';

  @override
  String get settingsContentSafetyTitle => 'Conținut și siguranță';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRĂRI';

  @override
  String get generalSettingsSectionViewing => 'VIZIONARE';

  @override
  String get generalSettingsSectionCreating => 'CREAȚIE';

  @override
  String get generalSettingsSectionApp => 'APLICAȚIE';

  @override
  String get appearanceSettingsTitle => 'Aspect';

  @override
  String get appearanceSettingsSubtitle =>
      'Alege cum arată Divine pe acest dispozitiv';

  @override
  String get appearanceSettingsSystem => 'Implicit de sistem';

  @override
  String get appearanceSettingsLight => 'Luminos';

  @override
  String get appearanceSettingsDark => 'Întunecat';

  @override
  String get generalSettingsClosedCaptions => 'Subtitrări';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Afișează subtitrările când videoclipurile le includ';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Doar videoclipuri pătrate';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Păstrează feedurile în formatul clasic pătrat';

  @override
  String get contentPreferencesTitle => 'Preferințe de conținut';

  @override
  String get contentPreferencesContentFilters => 'Filtre de conținut';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gestionează filtrele pentru atenționări de conținut';

  @override
  String get contentPreferencesContentLanguage => 'Limba conținutului';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (implicit pe dispozitiv)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Etichetează-ți videoclipurile cu o limbă, ca privitorii să poată filtra conținutul.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Folosește limba dispozitivului (implicit)';

  @override
  String get contentPreferencesAudioSharing =>
      'Fă audio-ul meu disponibil pentru refolosire';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Când e activat, alții pot folosi audio din videoclipurile tale';

  @override
  String get contentPreferencesMusicMode => 'Mod muzică';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Dezactivează reducerea zgomotului care turtește instrumentele. Mai bine pentru muzică, mai aspru pentru voci.';

  @override
  String get contentPreferencesAccountLabels => 'Etichete de cont';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Auto-etichetează-ți conținutul';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etichete de conținut pentru cont';

  @override
  String get contentPreferencesClearAll => 'Șterge tot';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Selectează tot ce se potrivește contului tău';

  @override
  String get contentPreferencesDoneNoLabels => 'Gata (fără etichete)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Gata ($count selectate)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Dispozitiv de intrare audio';

  @override
  String get contentPreferencesAutoRecommended => 'Automat (recomandat)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Alege automat cel mai bun microfon';

  @override
  String get contentPreferencesSelectAudioInput => 'Alege intrarea audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Microfon necunoscut';

  @override
  String get contentFiltersAdultContent => 'CONȚINUT PENTRU ADULȚI';

  @override
  String get contentFiltersViolenceGore => 'VIOLENȚĂ ȘI SÂNGE';

  @override
  String get contentFiltersSubstances => 'SUBSTANȚE';

  @override
  String get contentFiltersOther => 'ALTELE';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifică-ți vârsta în Setări de siguranță și confidențialitate ca să deblochezi filtrele pentru conținut adult';

  @override
  String get contentFiltersShow => 'Arată';

  @override
  String get contentFiltersWarn => 'Avertizează';

  @override
  String get contentFiltersFilterOut => 'Filtrează';

  @override
  String get profileBlockedAccountNotAvailable => 'Acest cont nu e disponibil';

  @override
  String get profileInvalidId => 'ID de profil invalid';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Aruncă o privire la $displayName pe Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName pe Divine';
  }

  @override
  String get profileShareFailed =>
      'Nu am putut partaja profilul. Încearcă din nou.';

  @override
  String get profileCopyPublicKey => 'Copiază cheia publică (npub)';

  @override
  String get profileGetEmbedCode => 'Obține codul de încorporare';

  @override
  String get profilePublicKeyCopied => 'Cheia publică a fost copiată';

  @override
  String get profileEmbedCodeCopied => 'Codul de încorporare a fost copiat';

  @override
  String get profileMoreTooltip => 'Mai multe';

  @override
  String get profileMoreSemanticLabel => 'Mai multe opțiuni';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Închide avatarul';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Închide previzualizarea avatarului';

  @override
  String get profileFollowingLabel => 'Urmărit';

  @override
  String get profileFollowLabel => 'Urmărește';

  @override
  String get profileBlockedLabel => 'Blocat';

  @override
  String get profileFollowersLabel => 'Urmăritori';

  @override
  String get profileFollowingStatLabel => 'Urmăriți';

  @override
  String get profileVideosLabel => 'Videoclipuri';

  @override
  String get profileCollabsLabel => 'Colaborări';

  @override
  String get profileLikedLabel => 'Apreciate';

  @override
  String get profileRepostsLabel => 'Redistribuiri';

  @override
  String get profileListsLabel => 'Liste';

  @override
  String get profileCommentsLabel => 'Comentarii';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de invitații de colaborator încă trebuie trimise',
      few: '$count invitații de colaborator încă trebuie trimise',
      one: '1 invitație de colaborator încă trebuie trimisă',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Am păstrat invitația în coadă. Reîncearcă aici.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Pentru „$title”. Reîncearcă aici.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Reîncearcă';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Se reîncearcă';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Reîncercarea invitației de colaborator nu e disponibilă acum.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de invitații de colaborator încă trebuie trimise.',
      few: '$count invitații de colaborator încă trebuie trimise.',
      one: '1 invitație de colaborator încă trebuie trimisă.',
      zero: 'Invitațiile de colaborator au fost trimise.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de colaboratori nu pot primi invitații.',
      few: '$count colaboratori nu pot primi invitații.',
      one: '1 colaborator nu poate primi invitații.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de utilizatori',
      few: '$count utilizatori',
      one: '1 utilizator',
    );
    return '$_temp0';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Blochezi pe $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Când blochezi un utilizator:';

  @override
  String get profileBlockBulletHidePosts =>
      'Postările lui nu vor mai apărea în feedurile tale.';

  @override
  String get profileBlockBulletCantView =>
      'Nu va putea să-ți vadă profilul, să te urmărească sau să-ți vadă postările.';

  @override
  String get profileBlockBulletNoNotify =>
      'Nu va fi notificat despre această schimbare.';

  @override
  String get profileBlockBulletYouCanView =>
      'Tu încă vei putea să-i vezi profilul.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Blochează pe $displayName';
  }

  @override
  String get profileCancelButton => 'Anulează';

  @override
  String get profileLearnMore => 'Află mai multe';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Deblochezi pe $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Când deblochezi acest utilizator:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Postările lui vor apărea în feedurile tale.';

  @override
  String get profileUnblockBulletCanView =>
      'Va putea să-ți vadă profilul, să te urmărească și să-ți vadă postările.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Nu va fi notificat despre această schimbare.';

  @override
  String get profileLearnMoreAt => 'Află mai multe la ';

  @override
  String get profileUnblockButton => 'Deblochează';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Nu mai urmări pe $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Blochează pe $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Deblochează pe $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Raportează-l pe $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Adaugă $displayName la o listă';
  }

  @override
  String get profileNoCollabsTitle => 'Încă nicio colaborare';

  @override
  String get profileCollabsOwnEmpty =>
      'Videoclipurile la care colaborezi vor apărea aici';

  @override
  String get profileCollabsOtherEmpty =>
      'Videoclipurile la care colaborează vor apărea aici';

  @override
  String get profileErrorLoadingCollabs => 'Eroare la încărcarea colaborărilor';

  @override
  String get profileNoSavedVideosTitle => 'Încă nimic salvat';

  @override
  String get profileSavedOwnEmpty =>
      'Salvează videoclipuri din meniul de partajare și vor apărea aici.';

  @override
  String get profileErrorLoadingSaved =>
      'Eroare la încărcarea videoclipurilor salvate';

  @override
  String get profileNoCommentsOwnTitle => 'Încă niciun comentariu';

  @override
  String get profileNoCommentsOtherTitle => 'Fără comentarii';

  @override
  String get profileCommentsOwnEmpty =>
      'Comentariile și răspunsurile tale vor apărea aici';

  @override
  String get profileCommentsOtherEmpty =>
      'Comentariile și răspunsurile lui vor apărea aici';

  @override
  String get profileErrorLoadingComments =>
      'Eroare la încărcarea comentariilor';

  @override
  String get profileVideoRepliesSection => 'Răspunsuri video';

  @override
  String get profileCommentsSection => 'Comentarii';

  @override
  String get profileEditLabel => 'Editează';

  @override
  String get profileLibraryLabel => 'Bibliotecă';

  @override
  String get profileNoLikedVideosTitle => 'Încă niciun videoclip apreciat';

  @override
  String get profileLikedOwnEmpty =>
      'Videoclipurile pe care le apreciezi vor apărea aici';

  @override
  String get profileLikedOtherEmpty =>
      'Videoclipurile pe care le apreciază vor apărea aici';

  @override
  String get profileErrorLoadingLiked =>
      'Eroare la încărcarea videoclipurilor apreciate';

  @override
  String get profileNoRepostsTitle => 'Încă nicio redistribuire';

  @override
  String get profileRepostsOwnEmpty =>
      'Videoclipurile pe care le redistribui vor apărea aici';

  @override
  String get profileRepostsOtherEmpty =>
      'Videoclipurile pe care le redistribuie vor apărea aici';

  @override
  String get profileErrorLoadingReposts =>
      'Eroare la încărcarea videoclipurilor redistribuite';

  @override
  String get profileNoVideosTitle => 'Încă niciun videoclip';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Distribuie primul tău videoclip ca să-l vezi aici';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Acest utilizator încă n-a distribuit niciun videoclip';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatură videoclip $number';
  }

  @override
  String get profileShowMore => 'Arată mai mult';

  @override
  String get profileShowLess => 'Arată mai puțin';

  @override
  String get dmMessageDisplayLimitReached =>
      'Restul acestui mesaj nu este afișat.';

  @override
  String get profileCompleteYourProfile => 'Completează-ți profilul';

  @override
  String get profileCompleteSubtitle =>
      'Adaugă numele, bio și poza ca să începi';

  @override
  String get profilePleaseTryAgain => 'Încearcă din nou';

  @override
  String get profileSecureYourAccount => 'Securizează-ți contul';

  @override
  String get profileSecureSubtitle =>
      'Adaugă email și parolă ca să-ți recuperezi contul pe orice dispozitiv';

  @override
  String get profileRetryButton => 'Reîncearcă';

  @override
  String get profileSessionExpired => 'Sesiune expirată';

  @override
  String get profileSignInToRestore =>
      'Autentifică-te din nou ca să recapeți acces complet';

  @override
  String get profileSignInButton => 'Autentificare';

  @override
  String get profileMaybeLaterLabel => 'Poate mai târziu';

  @override
  String get profileSecurePrimaryButton => 'Adaugă email și parolă';

  @override
  String get profileCompletePrimaryButton => 'Actualizează-ți profilul';

  @override
  String get profileLoopsLabel => 'Bucle';

  @override
  String get profileLikesLabel => 'Aprecieri';

  @override
  String get profileMyLibraryLabel => 'Biblioteca mea';

  @override
  String get profileMessageLabel => 'Mesaj';

  @override
  String get profileShareLabel => 'Partajează profilul';

  @override
  String get profileDeletedAccountName => 'Cont șters';

  @override
  String get inboxActionReportVanishedAccount => 'Raportează acest cont';

  @override
  String get inboxActionBlockVanishedAccount => 'Blochează acest cont';

  @override
  String get inboxActionUnblockVanishedAccount => 'Deblochează acest cont';

  @override
  String get inboxReportedVanishedAccount => 'Acest cont a fost raportat';

  @override
  String get inboxBlockedVanishedAccount => 'Acest cont a fost blocat';

  @override
  String get inboxUnblockedVanishedAccount => 'Acest cont a fost deblocat';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Astfel, conversația este eliminată din inbox. Dacă îți scrie din nou, începe o conversație nouă.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Acest cont a fost șters';

  @override
  String get profileUserFallback => 'utilizator';

  @override
  String get profileLinkCopied => 'Linkul profilului a fost copiat';

  @override
  String get profileSetupEditProfileTitle => 'Editează profilul';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Configurează-ți profilul înainte de a adăuga o adresă NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Creează profil';

  @override
  String get profileSetupBackLabel => 'Înapoi';

  @override
  String get profileSetupAboutNostr => 'Despre Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil publicat cu succes!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Salvezi modificările?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Salvează modificările înainte să pleci sau renunță la ele și mergi mai departe.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Salvează modificările';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Renunță la modificări';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Continuă editarea';

  @override
  String get profileSetupCreateNewProfile => 'Creezi un profil nou?';

  @override
  String get profileSetupNoExistingProfile =>
      'N-am găsit un profil existent pe relay-urile tale. Publicarea va crea un profil nou. Continuăm?';

  @override
  String get profileSetupPublishButton => 'Publică';

  @override
  String get profileSetupUsernameTaken =>
      'Numele tocmai a fost luat. Alege altul.';

  @override
  String get profileSetupClaimFailed =>
      'N-am putut revendica numele. Încearcă din nou.';

  @override
  String get profileSetupPublishFailed =>
      'N-am putut publica profilul. Încearcă din nou.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Nu s-a putut accesa rețeaua. Verifică conexiunea și încearcă din nou.';

  @override
  String get profileSetupDisplayNameLabel => 'Nume afișat';

  @override
  String get profileSetupDisplayNameRequired => 'Introdu un nume afișat';

  @override
  String get profileSetupBioLabel => 'Bio (opțional)';

  @override
  String get profileSetupWebsiteLabel => 'Site web (opțional)';

  @override
  String get profileSetupPublicKeyLabel => 'Cheie publică (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nume de utilizator (opțional)';

  @override
  String get profileSetupUsernameHelper =>
      'Folosește litere, cifre sau cratime. Numele tău devine o adresă divine.video. Folosește numele afișat pentru spații sau simboluri.';

  @override
  String get profileSetupSaveButton => 'Salvează';

  @override
  String get profileSetupSavingButton => 'Se salvează...';

  @override
  String get profileSetupImageUrlTitle => 'Adaugă URL de imagine';

  @override
  String get profileSetupImageSelectionFailed =>
      'Selectarea imaginii a eșuat. Lipește mai jos un URL de imagine.';

  @override
  String get profileSetupImagesTypeGroup => 'imagini';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Accesul la cameră este dezactivat. Activează-l din Setări ca să faci o poză.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Accesul la cameră nu este permis pe acest dispozitiv.';

  @override
  String get cameraPickErrorBusy =>
      'Selectorul este deja deschis. Închide-l și încearcă din nou.';

  @override
  String get cameraPickErrorGeneric =>
      'N-am putut deschide camera. Încearcă din nou.';

  @override
  String get profileSetupGotItButton => 'Am înțeles';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Încărcarea imaginii a eșuat. Încearcă din nou mai târziu.';

  @override
  String get profileSetupUploadNetworkError =>
      'Eroare de rețea: verifică conexiunea la internet și încearcă din nou.';

  @override
  String get profileSetupUploadAuthError =>
      'Eroare de autentificare: deconectează-te și autentifică-te din nou.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Fișier prea mare: alege o imagine mai mică (maxim 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Încărcarea imaginii a eșuat. Serverele noastre sunt temporar indisponibile. Încearcă din nou imediat.';

  @override
  String get profileSetupBannerClearButton => 'Șterge bannerul';

  @override
  String get profileSetupBannerChangeColor => 'Culoarea bannerului';

  @override
  String get profileSetupChangeBannerTitle => 'Schimbă bannerul';

  @override
  String get profileSetupBannerColorPickerTitle =>
      'Schimbă culoarea bannerului';

  @override
  String get profileSetupBannerColorCustom => 'Personalizată';

  @override
  String get profileSetupBannerColorNone => 'Fără culoare';

  @override
  String get profileSetupBannerColorLime => 'Verde lime';

  @override
  String get profileSetupBannerColorYellow => 'Galben';

  @override
  String get profileSetupBannerColorViolet => 'Violet deschis';

  @override
  String get profileSetupBannerColorPink => 'Roz';

  @override
  String get profileSetupBannerColorOrange => 'Portocaliu';

  @override
  String get profileSetupBannerColorPurple => 'Mov';

  @override
  String get profileSetupAvatarClearButton => 'Elimină fotografia';

  @override
  String get profileSetupImageTakePhoto => 'Fă o fotografie';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Încarcă din galerie';

  @override
  String get profileSetupImagePasteLink => 'Lipește un link de imagine';

  @override
  String get profileSetupEditAvatarLabel => 'Editează poza de profil';

  @override
  String get profileSetupEditBannerLabel => 'Editează bannerul';

  @override
  String get profileSetupUsernameChecking => 'Se verifică disponibilitatea...';

  @override
  String get profileSetupUsernameAvailable => 'Numele e disponibil!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Numele e deja luat';

  @override
  String get profileSetupUsernameReserved => 'Numele e rezervat';

  @override
  String get profileSetupContactSupport => 'Contactează asistența';

  @override
  String get profileSetupCheckAgain => 'Verifică din nou';

  @override
  String get profileSetupUsernameBurned => 'Acest nume nu mai e disponibil';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Sunt permise doar litere, cifre și cratime';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Numele nu poate începe sau termina cu o cratimă';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Numele trebuie să aibă 3-63 de caractere';

  @override
  String get profileSetupUsernameNetworkError =>
      'N-am putut verifica disponibilitatea. Încearcă din nou.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Format invalid de nume';

  @override
  String get profileSetupUsernameCheckFailed =>
      'N-am putut verifica disponibilitatea';

  @override
  String get profileSetupUsernameReservedTitle => 'Nume rezervat';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Numele $username e rezervat. Spune-ne de ce ar trebui să fie al tău.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'ex. E brandul meu, numele de scenă etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Ai contactat deja asistența? Apasă pe \"Verifică din nou\" ca să vezi dacă ți-a fost eliberat.';

  @override
  String get profileSetupSupportRequestSent =>
      'Cerere de asistență trimisă! Revenim la tine curând.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'N-am putut deschide emailul. Trimite la: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Trimite cererea';

  @override
  String get profileSetupUseOwnNip05 => 'Folosește propria ta adresă NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Adresă NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Format NIP-05 invalid (ex.: nume@domeniu.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Folosește câmpul de nume de utilizator de mai sus pentru divine.video';

  @override
  String get nostrSettingsNip05Address => 'Adresă NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Folosește numele tău de utilizator divine.video sau îndreaptă-ți identificatorul către o adresă NIP-05 de pe un domeniu pe care îl controlezi.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Salvează NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 salvat';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Nu am putut salva NIP-05. Încearcă din nou.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Folosești propriul NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 leagă un nume precum tu@domeniultau.ro de identitatea ta Nostr. Trebuie să controlezi domeniul și să găzduiești un fișier de verificare la calea corectă. Dacă e greșit, oamenii nu te mai găsesc, iar identificatorul verificat dispare. Continuă doar dacă ai configurat asta.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Continuă';

  @override
  String get profileSetupNip05ConfirmCancel => 'Anulează';

  @override
  String get profileSetupProfilePicturePreview =>
      'Previzualizare poză de profil';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine e construit pe Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' un protocol deschis și rezistent la cenzură care permite oamenilor să comunice online fără să depindă de o singură companie sau platformă. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Când te înscrii pe Divine, primești o identitate Nostr nouă.';

  @override
  String get nostrInfoOwnership =>
      'Nostr țiţi lasă în posesie conținutul, identitatea și graful social, pe care le poți folosi în multe aplicații. Rezultă mai multă alegere, mai puțină dependență și un internet social mai sănătos și mai rezilient.';

  @override
  String get nostrInfoLingo => 'Jargon Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Adresa ta publică Nostr. E sigur s-o distribui și le permite altora să te găsească, să te urmărească sau să-ți trimită mesaje pe aplicații Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Cheia ta privată și dovada de proprietate. Îți dă control total asupra identității tale Nostr, așa că ';

  @override
  String get nostrInfoNsecWarning => 'ține-o mereu secretă!';

  @override
  String get nostrInfoUsernameLabel => 'Nume de utilizator Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Un nume ușor de citit (gen @nume.divine.video) care duce la npub-ul tău. Face identitatea ta Nostr mai ușor de recunoscut și verificat, ca o adresă de email.';

  @override
  String get nostrInfoLearnMoreAt => 'Află mai multe la ';

  @override
  String get nostrInfoGotIt => 'Am înțeles!';

  @override
  String get videoGridRefreshLabel => 'Se caută mai multe videoclipuri';

  @override
  String get videoGridOptionsTitle => 'Opțiuni video';

  @override
  String get videoGridEditVideo => 'Editează videoclipul';

  @override
  String get videoGridEditVideoSubtitle =>
      'Actualizează titlul, descrierea și hashtagurile';

  @override
  String get videoGridDeleteVideo => 'Șterge videoclipul';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Elimină acest videoclip din Divine. Poate apărea în continuare în alți clienți Nostr.';

  @override
  String get videoGridDeletingContent => 'Se șterge conținutul...';

  @override
  String get exploreTabFeatured => 'Recomandate';

  @override
  String get exploreTabClassics => 'Clasice';

  @override
  String get exploreTabNew => 'Noi';

  @override
  String get exploreTabPopular => 'Populare';

  @override
  String get exploreTabCategories => 'Categorii';

  @override
  String get exploreTabForYou => 'Pentru tine';

  @override
  String get exploreTabLists => 'Liste';

  @override
  String get exploreTabIntegratedApps => 'Aplicații integrate';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Încă nu e nimic aici. Revino în curând.';

  @override
  String get featuredTabLoadFailed => 'Nu am putut încărca această colecție.';

  @override
  String get featuredTabRetry => 'Încearcă din nou';

  @override
  String get exploreNoVideosAvailable => 'Niciun videoclip disponibil';

  @override
  String get exploreDiscoverLists => 'Descoperă liste';

  @override
  String get exploreAboutLists => 'Despre liste';

  @override
  String get exploreAboutListsDescription =>
      'Listele te ajută să organizezi și să curaâezi conținutul Divine în două feluri:';

  @override
  String get explorePeopleLists => 'Liste de oameni';

  @override
  String get explorePeopleListsDescription =>
      'Urmărește grupuri de creatori și vezi cele mai noi videoclipuri ale lor';

  @override
  String get exploreVideoLists => 'Liste de videoclipuri';

  @override
  String get exploreVideoListsDescription =>
      'Creează playlisturi cu videoclipurile preferate ca să le vezi mai târziu';

  @override
  String get exploreMyLists => 'Listele mele';

  @override
  String get exploreSubscribedLists => 'Liste la care ești abonat';

  @override
  String get exploreErrorLoadingLists =>
      'Eroare la încărcarea listelor. Încearcă din nou.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videoclipuri noi',
      one: '1 videoclip nou',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videoclipuri noi',
      one: 'videoclip nou',
    );
    return 'Încarcă $count $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Redă videoclipul';

  @override
  String get videoPlayerMute => 'Dezactivează sunetul videoclipului';

  @override
  String get videoPlayerUnmute => 'Activează sunetul videoclipului';

  @override
  String get videoPlayerTapHint =>
      'Atinge pentru a reda sau întrerupe. Atinge de două ori pentru a aprecia.';

  @override
  String get videoSettingsMenuOpen => 'Deschide setările de redare';

  @override
  String get videoSettingsMenuClose => 'Închide setările de redare';

  @override
  String get videoSettingsCaptionsEnable => 'Activează subtitrările';

  @override
  String get videoSettingsCaptionsDisable => 'Dezactivează subtitrările';

  @override
  String get videoSettingsAutoAdvanceOn => 'Avansare automată activată';

  @override
  String get videoSettingsAutoAdvanceOff => 'Avansare automată dezactivată';

  @override
  String get videoSettingsCaptionsOn => 'Subtitrări activate';

  @override
  String get videoSettingsCaptionsOff => 'Subtitrări dezactivate';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Subtitrările sunt pornite pentru acest videoclip';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Subtitrările sunt oprite pentru acest videoclip';

  @override
  String get contentWarningLabel => 'Atenționare de conținut';

  @override
  String get contentWarningNudity => 'Nuditate';

  @override
  String get contentWarningSexualContent => 'Conținut sexual';

  @override
  String get contentWarningPornography => 'Pornografie';

  @override
  String get contentWarningGraphicMedia => 'Imagini explicite';

  @override
  String get contentWarningViolence => 'Violență';

  @override
  String get contentWarningSelfHarm => 'Auto-vătămare';

  @override
  String get contentWarningDrugUse => 'Consum de droguri';

  @override
  String get contentWarningAlcohol => 'Alcool';

  @override
  String get contentWarningTobacco => 'Tutun';

  @override
  String get contentWarningGambling => 'Jocuri de noroc';

  @override
  String get contentWarningProfanity => 'Limbaj vulgar';

  @override
  String get contentWarningFlashingLights => 'Lumini care clipesc';

  @override
  String get contentWarningAiGenerated => 'Generat de AI';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Conținut sensibil';

  @override
  String get contentWarningDescNudity =>
      'Conține nuditate sau nuditate parțială';

  @override
  String get contentWarningDescSexual => 'Conține conținut sexual';

  @override
  String get contentWarningDescPorn => 'Conține conținut pornografic explicit';

  @override
  String get contentWarningDescGraphicMedia =>
      'Conține imagini explicite sau tulburătoare';

  @override
  String get contentWarningDescViolence => 'Conține conținut violent';

  @override
  String get contentWarningDescSelfHarm => 'Conține referințe la auto-vătămare';

  @override
  String get contentWarningDescDrugs => 'Conține conținut legat de droguri';

  @override
  String get contentWarningDescAlcohol => 'Conține conținut legat de alcool';

  @override
  String get contentWarningDescTobacco => 'Conține conținut legat de tutun';

  @override
  String get contentWarningDescGambling =>
      'Conține conținut legat de jocuri de noroc';

  @override
  String get contentWarningDescProfanity => 'Conține limbaj vulgar';

  @override
  String get contentWarningDescFlashingLights =>
      'Conține lumini care clipesc (avertisment de fotosensibilitate)';

  @override
  String get contentWarningDescAiGenerated =>
      'Acest conținut a fost generat de AI';

  @override
  String get contentWarningDescSpoiler => 'Conține spoilere';

  @override
  String get contentWarningDescContentWarning =>
      'Creatorul a marcat asta ca sensibil';

  @override
  String get contentWarningDescDefault => 'Creatorul a semnalat acest conținut';

  @override
  String get contentWarningDetailsTitle => 'Atenționări de conținut';

  @override
  String get contentWarningDetailsSubtitle =>
      'Creatorul a aplicat aceste etichete:';

  @override
  String get contentWarningManageFilters => 'Gestionează filtrele de conținut';

  @override
  String get contentWarningViewAnyway => 'Vezi oricum';

  @override
  String get contentWarningReportContentTooltip => 'Raportează conținutul';

  @override
  String get contentWarningBlockUserTooltip => 'Blochează utilizatorul';

  @override
  String get contentWarningBlockedTitle => 'Conținut blocat';

  @override
  String get contentWarningBlockedPolicy =>
      'Acest conținut a fost blocat din cauza încălcărilor politicii.';

  @override
  String get contentWarningNoticeTitle => 'Atenționare de conținut';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Conținut potențial dăunător';

  @override
  String get contentWarningView => 'Vezi';

  @override
  String get contentWarningReportAction => 'Raportează';

  @override
  String get contentWarningHideAllLikeThis =>
      'Ascunde tot conținutul de genul ăsta';

  @override
  String get contentWarningNoFilterYet =>
      'Încă n-ai un filtru salvat pentru această atenționare.';

  @override
  String get contentWarningHiddenConfirmation =>
      'De acum înainte ascundem postările de genul ăsta.';

  @override
  String get communitySuggestTitle => 'Ajută la clasificarea asta';

  @override
  String get communitySuggestSubtitle =>
      'Lipsește o atenționare de conținut? Sugestia ta e publică, semnată și nu poate fi retrasă.';

  @override
  String get communitySuggestSubmit => 'Sugerează';

  @override
  String get communitySuggestSuccess => 'Mulțumim. Sugestia ta a fost trimisă.';

  @override
  String get communitySuggestFailure =>
      'Nu am putut trimite sugestia ta. Încearcă din nou.';

  @override
  String get communitySuggestAlready => 'Ai sugerat asta';

  @override
  String get communitySuggestActionLabel => 'Clasifică';

  @override
  String get videoErrorNotFound => 'Videoclipul n-a fost găsit';

  @override
  String get videoErrorPlayback => 'Eroare de redare video';

  @override
  String get videoErrorAgeRestricted => 'Conținut cu restricție de vârstă';

  @override
  String get videoErrorUnavailable => 'Videoclip indisponibil';

  @override
  String get videoErrorUnavailableBody =>
      'Acest videoclip nu este disponibil acum.';

  @override
  String get videoErrorRetry => 'Reîncearcă';

  @override
  String get videoErrorContentRestricted => 'Conținut restricționat';

  @override
  String get videoErrorContentRestrictedBody =>
      'Acest videoclip a fost eliminat pentru încălcarea regulilor noastre de conținut.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifică-ți vârsta ca să vezi acest videoclip.';

  @override
  String get videoErrorSkip => 'Sari peste';

  @override
  String get videoErrorVerifyAgeButton => 'Verifică vârsta';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Nu am putut verifica vârsta. Încearcă din nou.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Timpul de verificare a expirat. Verifică-ți conexiunea sau încearcă din nou în scurt timp.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Conținutul pentru adulți este dezactivat';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Activează-l în filtrele de conținut ca să vezi acest videoclip.';

  @override
  String get videoErrorAdultContentHiddenAction =>
      'Deschide filtrele de conținut';

  @override
  String get videoDetailLoadError => 'N-am putut încărca videoclipul';

  @override
  String get videoDetailLoadErrorBody =>
      'Ceva a mers prost pe drum. Mai încearcă o dată.';

  @override
  String get videoDetailNotFoundBody =>
      'Poate a fost șters, e în afara razei noastre sau ascuns de setările tale.';

  @override
  String get databaseCorruptionTitle => 'Datele tale locale s-au deteriorat';

  @override
  String get databaseCorruptionBody =>
      'Închide Divine și deschide-l din nou — reparăm automat. Salvăm ce putem din ciornele și clipurile tale, restul se reîncarcă.';

  @override
  String get databaseCorruptionCloseButton => 'Închide Divine';

  @override
  String get videoDetailContextTitle => 'Videoclip partajat';

  @override
  String get videoDetailCloseSemanticLabel => 'Închide playerul video';

  @override
  String get videoFollowButtonFollow => 'Urmărește';

  @override
  String get audioAttributionOriginalSound => 'Sunet original';

  @override
  String get audioAttributionUnavailableSound => 'Sunet indisponibil';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirat de @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirat de @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'cu @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'cu @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colaboratori',
      one: '1 colaborator',
    );
    return '$_temp0. Atinge pentru a vedea profilul.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'În așteptare';

  @override
  String get videoCollaboratorPendingSemanticLabel =>
      'Colaborator în așteptare';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending în așteptare)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Atinge pentru a vedea profilul.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Atinge ca să vezi videoclipuri cu acest hashtag.';
  }

  @override
  String get listAttributionFallback => 'Listă';

  @override
  String get shareVideoLabel => 'Partajează videoclipul';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Postare partajată cu $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Postare partajată cu $count de persoane',
      few: 'Postare partajată cu $count persoane',
      one: 'Postare partajată cu $count persoană',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'N-am putut trimite videoclipul';

  @override
  String get shareAddedToBookmarks => 'Adăugat la semne de carte';

  @override
  String get shareRemovedFromBookmarks => 'Eliminat din semne de carte';

  @override
  String get shareFailedToAddBookmark => 'N-am putut adăuga semnul de carte';

  @override
  String get shareFailedToRemoveBookmark =>
      'N-am putut elimina semnul de carte';

  @override
  String get shareActionFailed => 'Acțiunea a eșuat';

  @override
  String get shareWithTitle => 'Partajează cu';

  @override
  String get shareFindPeople => 'Găsește oameni';

  @override
  String get shareFindPeopleMultiline => 'Găsește\noameni';

  @override
  String get shareSent => 'Trimis';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name selectat';
  }

  @override
  String get shareMessageHint => 'Adaugă un mesaj opțional...';

  @override
  String get videoActionUnlike => 'Retrage aprecierea';

  @override
  String get videoActionLike => 'Apreciază videoclipul';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Apreciază';

  @override
  String get videoActionReplyLabel => 'Răspunde';

  @override
  String get videoActionRepostLabel => 'Redistribuie';

  @override
  String get videoActionShareLabel => 'Partajează';

  @override
  String get videoActionReportLabel => 'Raportează';

  @override
  String get videoActionReport => 'Raportează videoclipul';

  @override
  String get videoActionEditLabel => 'Editează';

  @override
  String get videoActionEdit => 'Editează videoclipul';

  @override
  String get videoActionAboutLabel => 'Despre';

  @override
  String get videoActionEnableAutoAdvance => 'Activează avansarea automată';

  @override
  String get videoActionDisableAutoAdvance => 'Dezactivează avansarea automată';

  @override
  String get videoActionRemoveRepost => 'Elimină redistribuirea';

  @override
  String get videoActionRepost => 'Redistribuie videoclipul';

  @override
  String get videoActionViewComments => 'Vezi comentariile';

  @override
  String get videoActionMoreOptions => 'Mai multe opțiuni';

  @override
  String get videoEngagementLikersTitle => 'Apreciat de';

  @override
  String get videoEngagementRepostersTitle => 'Repostat de';

  @override
  String get videoEngagementLikersEmpty => 'Niciun like încă';

  @override
  String get videoEngagementRepostersEmpty => 'Niciun repost încă';

  @override
  String get videoEngagementLoadFailed => 'Lista nu a putut fi încărcată';

  @override
  String get videoOverlayOpenMetadataFromTitle =>
      'Deschide detaliile videoclipului';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Deschide detaliile videoclipului';

  @override
  String get videoOverlayCommentBarHint => 'Adaugă un comentariu...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Adaugă un comentariu';

  @override
  String get videoOverlayCommentBarSendLabel => 'Trimite comentariul';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Comentariu publicat';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Nu am putut publica comentariul';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bucle',
      one: 'buclă',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Nu e Divine';

  @override
  String get metadataBadgeHumanMade => 'Făcut de om';

  @override
  String get metadataSoundsLabel => 'Sunete';

  @override
  String get metadataOriginalSound => 'Sunet original';

  @override
  String get metadataVerificationLabel => 'Verificare';

  @override
  String get metadataDeviceAttestation => 'Atestare de dispozitiv';

  @override
  String get metadataPgpSignature => 'Semnătură PGP';

  @override
  String get metadataC2paCredentials => 'Credentiale de conținut C2PA';

  @override
  String get metadataProofManifest => 'Manifest de dovezi';

  @override
  String get metadataVerificationInfoTooltip =>
      'Ce înseamnă aceste verificări?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Ce înseamnă aceste verificări';

  @override
  String get metadataVerificationInfoIntro =>
      'Aceste semnale vin de la cameră și din fișierul video în sine. Cu cât un videoclip are mai multe, cu atât putem dovedi mai multe despre proveniența lui.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Sistemul de operare al telefonului a garantat pentru aplicația care a filmat. Un indiciu puternic că vine de la o cameră, nu dintr-un fișier încărcat.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Videoclipul a fost semnat criptografic chiar în momentul filmării. Dacă se schimbă ulterior un singur cadru, semnătura se rupe.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'O înregistrare a provenienței, conform standardului din industrie, care călătorește în interiorul fișierului — așa că o pot verifica și alte aplicații decât Divine.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Înregistrarea ProofMode completă: amprenta fișierului, marcajul de timp și contextul filmării, împreună cu videoclipul.';

  @override
  String get metadataVerificationInfoFootnote =>
      'O verificare lipsă nu face videoclipul fals. Clipurile mai vechi și încărcările nu au avut niciodată una — înseamnă doar că nu putem dovedi acea parte.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Află mai multe pe $url';
  }

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Colaboratori';

  @override
  String get metadataInspiredByLabel => 'Inspirat de';

  @override
  String get metadataRepostedByLabel => 'Redistribuit de';

  @override
  String metadataMoreReposters(int count) {
    return 'încă $count';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Bucle';
  }

  @override
  String get metadataLikesLabel => 'Aprecieri';

  @override
  String get metadataCommentsLabel => 'Comentarii';

  @override
  String get metadataRepostsLabel => 'Redistribuiri';

  @override
  String get metadataVineStatsLabel => 'Pe Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops bucle · $likes aprecieri · $comments comentarii · $reposts redistribuiri';
  }

  @override
  String get metadataDivineStatsLabel => 'Pe Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views vizualizări · $likes aprecieri · $comments comentarii · $reposts redistribuiri';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publicat pe $date';
  }

  @override
  String get devOptionsTitle => 'Opțiuni dezvoltator';

  @override
  String get devOptionsDisableDeveloperMode => 'Dezactivează modul dezvoltator';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Ascunde opțiunile de dezvoltator din setări';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Modul dezvoltator a fost dezactivat';

  @override
  String get devOptionsShorebirdTitle => 'Patch-uri Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Patch activ';

  @override
  String get devOptionsShorebirdNoPatch => 'Niciun patch instalat';

  @override
  String get devOptionsShorebirdUnavailable =>
      'Indisponibil în această versiune';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Patch-urile funcționează doar într-o versiune creată cu shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Se citește starea patch-ului…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Canalul de testare nu a fost verificat încă.';

  @override
  String get devOptionsShorebirdCheck => 'Verifică canalul de testare';

  @override
  String get devOptionsShorebirdApply => 'Aplică patch-ul de testare';

  @override
  String get devOptionsShorebirdUseStable => 'Revino la actualizările stabile';

  @override
  String get devOptionsShorebirdChecking => 'Se verifică canalul de testare…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Un patch de testare este gata de aplicat.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Niciun patch de testare pentru această versiune.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Descărcat. Repornește aplicația pentru a-l încărca.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'O revenire este pregătită. Repornește pentru a reveni la versiunea de bază.';

  @override
  String get devOptionsShorebirdApplying => 'Se descarcă și se instalează…';

  @override
  String get devOptionsShorebirdApplied =>
      'Instalat. Repornește aplicația pentru a-l încărca.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Nu s-a instalat nimic. Verifică canalul de testare și încearcă din nou.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Se selectează canalul stabil…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Canal stabil selectat. Repornește aplicația pentru a verifica dacă există un patch stabil.';

  @override
  String get devOptionsShorebirdFailure =>
      'Nu a funcționat. Verifică jurnalele pentru detalii.';

  @override
  String get devOptionsPageLoadTimes => 'Timpi de încărcare a paginilor';

  @override
  String get devOptionsNoPageLoads =>
      'Nicio încărcare de pagină înregistrată încă.\nNavighează prin aplicație ca să vezi datele de timing.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Vizibil: ${visibleMs}ms  |  Date: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Cele mai lente ecrane';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format de redare video';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Schimbi mediul?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Schimbi la $envName?\n\nAsta va șterge datele video din cache și se va reconecta la noul relay.';
  }

  @override
  String get devOptionsCancel => 'Anulează';

  @override
  String get devOptionsSwitch => 'Schimbă';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Schimbat la $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Schimbat la $formatName — cache șters';
  }

  @override
  String get featureFlagTitle => 'Indicatoare de funcții';

  @override
  String get featureFlagResetAllTooltip =>
      'Resetează toate indicatoarele la valorile implicite';

  @override
  String get featureFlagError => 'Eroare';

  @override
  String get relaySettingsTitle => 'Relay-uri';

  @override
  String get relaySettingsInfoTitle =>
      'Divine e un sistem deschis - tu âți controlezi conexiunile';

  @override
  String get relaySettingsInfoDescription =>
      'Aceste relay-uri distribuie conținutul tău prin rețeaua descentralizată Nostr. Poți adăuga sau elimina relay-uri după cum vrei.';

  @override
  String get relaySettingsLearnMoreNostr => 'Află mai multe despre Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Găsește relay-uri publice la nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Aplicația nu e funcțională';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine are nevoie de cel puțin un relay ca să încarce videoclipuri, să publice conținut și să sincronizeze date.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Restabilește relay-ul implicit';

  @override
  String get relaySettingsAddCustomRelay => 'Adaugă relay personalizat';

  @override
  String get relaySettingsAddRelay => 'Adaugă relay';

  @override
  String get relaySettingsRetry => 'Reîncearcă';

  @override
  String get relaySettingsNoStats => 'Încă nicio statistică disponibilă';

  @override
  String get relaySettingsConnection => 'Conexiune';

  @override
  String get relaySettingsConnected => 'Conectat';

  @override
  String get relaySettingsDisconnected => 'Deconectat';

  @override
  String get relaySettingsSessionDuration => 'Durata sesiunii';

  @override
  String get relaySettingsLastConnected => 'Ultima conectare';

  @override
  String get relaySettingsDisconnectedLabel => 'Deconectat';

  @override
  String get relaySettingsReason => 'Motiv';

  @override
  String get relaySettingsActiveSubscriptions => 'Abonări active';

  @override
  String get relaySettingsTotalSubscriptions => 'Total abonări';

  @override
  String get relaySettingsEventsReceived => 'Evenimente primite';

  @override
  String get relaySettingsEventsSent => 'Evenimente trimise';

  @override
  String get relaySettingsRequestsThisSession => 'Cereri în această sesiune';

  @override
  String get relaySettingsFailedRequests => 'Cereri eșuate';

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Se încarcă informațiile despre relay...';

  @override
  String get relaySettingsAboutRelay => 'Despre relay';

  @override
  String get relaySettingsSupportedNips => 'NIP-uri suportate';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Vezi site-ul';

  @override
  String get relaySettingsRemoveRelayTitle => 'Elimini relay-ul?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Sigur vrei să elimini acest relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Elimini relay-ul Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Eliminarea relay-ului Divine va înrăutăți experiența în aplicație. Videoclipurile, publicarea și sincronizarea pot deveni mai puțin fiabile. Fă asta doar dacă ești un utilizator Nostr experimentat.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Elimină relay-ul';

  @override
  String get relaySettingsCancel => 'Anulează';

  @override
  String get relaySettingsRemove => 'Elimină';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay eliminat: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'N-am putut elimina relay-ul';

  @override
  String get relaySettingsForcingReconnection =>
      'Se forțează reconectarea la relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de relay-uri',
      few: '$count relay-uri',
      one: '1 relay',
    );
    return 'Conectat la $_temp0!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'N-am putut conecta la relay-uri. Verifică-ți conexiunea la rețea.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Salvat pe acest dispozitiv. Îl vom sincroniza cu contul tău când publicarea funcționează din nou.';

  @override
  String get relaySettingsAddRelayTitle => 'Adaugă relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Introdu URL-ul WebSocket al relay-ului pe care vrei să-l adaugi:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Răsfoiește relay-urile publice la nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Adaugă';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay adăugat: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'N-am putut adăuga relay-ul. Verifică URL-ul și încearcă din nou.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL-ul relay-ului trebuie să înceapă cu wss:// sau ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'URL-ul relay-ului trebuie să folosească wss:// (ws:// e permis doar pentru localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay-ul implicit a fost restabilit: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'N-am putut restabili relay-ul implicit. Verifică-ți conexiunea la rețea.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'N-am putut deschide browserul';

  @override
  String get relaySettingsFailedToOpenLink => 'N-am putut deschide linkul';

  @override
  String get relaySettingsExternalRelay => 'Relay extern';

  @override
  String get relaySettingsNotConnected => 'Neconectat';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Deconectat acum $duration';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de abonări',
      few: '$count abonări',
      one: '1 abonare',
    );
    return '$_temp0';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count evenimente';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'acum $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine folosește protocolul Nostr pentru publicare descentralizată. Conținutul tău trăiește pe relay-urile pe care le alegi, iar cheile tale sunt identitatea ta.';

  @override
  String get nostrSettingsSectionNetwork => 'Rețea';

  @override
  String get nostrSettingsSectionAccount => 'Cont';

  @override
  String get nostrSettingsSectionDangerZone => 'Zonă periculoasă';

  @override
  String get nostrSettingsRelays => 'Relay-uri';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Gestionează conexiunile cu relay-urile Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostic relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Depanează conectivitatea relay-ului și problemele de rețea';

  @override
  String get nostrSettingsMediaServers => 'Servere media';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configurează serverele de încărcare Blossom';

  @override
  String get settingsDeveloperOptions => 'Opțiuni dezvoltator';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Comutator de mediu și setări de depanare';

  @override
  String get nostrSettingsKeyManagement => 'Gestionare chei';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exportă, fă backup și restaurează cheile tale Nostr';

  @override
  String get nostrSettingsClientAttribution => 'Atribuirea clientului';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Include o etichetă de client Divine în evenimentele pe care le publici, ca alte aplicații Nostr să le poată atribui corect. Fără ea, raportările pe care le trimiți cântăresc mai puțin când moderatorii noștri le analizează.';

  @override
  String get nostrSettingsMoveAccount => 'Mută-ți contul';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Descarcă-ți arhiva și mută postările și videoclipurile pe alt relay sau server media.';

  @override
  String get nostrSettingsRemoveKeys => 'Elimină cheile de pe dispozitiv';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Șterge cheia ta privată doar de pe acest dispozitiv. Conținutul tău rămâne pe relay-uri, dar vei avea nevoie de backup-ul nsec ca să-ți accesezi din nou contul.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'N-am putut elimina acest cont de pe acest dispozitiv. Încearcă din nou.';

  @override
  String get nostrSettingsDeleteAccount => 'Șterge contul și datele';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Trimite cereri de ștergere pentru conținutul tău și te deconectează pe acest dispozitiv. Relay-urile, clienții, indexurile de căutare și alte dispozitive conectate pot păstra copii.';

  @override
  String get relayDiagnosticTitle => 'Diagnostice relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Reîncarcă diagnosticele';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Ultima reîncarcare: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Stare relay';

  @override
  String get relayDiagnosticInitialized => 'Inițializat';

  @override
  String get relayDiagnosticReady => 'Gata';

  @override
  String get relayDiagnosticNotInitialized => 'Neinițializat';

  @override
  String get relayDiagnosticDatabaseEvents => 'Evenimente din baza de date';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Abonări active';

  @override
  String get relayDiagnosticExternalRelays => 'Relay-uri externe';

  @override
  String get relayDiagnosticConfigured => 'Configurat';

  @override
  String relayDiagnosticRelayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de relay-uri',
      few: '$count relay-uri',
      one: '1 relay',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Conectat';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Evenimente video';

  @override
  String get relayDiagnosticHomeFeed => 'Feed principal';

  @override
  String relayDiagnosticVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticDiscovery => 'Descoperire';

  @override
  String get relayDiagnosticLoading => 'Se încarcă';

  @override
  String get relayDiagnosticYes => 'Da';

  @override
  String get relayDiagnosticNo => 'Nu';

  @override
  String get relayDiagnosticTestDirectQuery => 'Testează interogarea directă';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Conectivitate rețea';

  @override
  String get relayDiagnosticRunNetworkTest => 'Rulează testul de rețea';

  @override
  String get relayDiagnosticBlossomServer => 'Server Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testează toate endpoint-urile';

  @override
  String get relayDiagnosticStatus => 'Stare';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Eroare';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL de bază';

  @override
  String get relayDiagnosticSummary => 'Sumar';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (medie ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retestează tot';

  @override
  String get relayDiagnosticRetrying => 'Se reîncearcă...';

  @override
  String get relayDiagnosticRetryConnection => 'Reîncearcă conexiunea';

  @override
  String get relayDiagnosticTroubleshooting => 'Depanare';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Stare verde = Conectat și funcțional\n• Stare roșie = Conexiunea a eșuat\n• Dacă testul de rețea eșuează, verifică conexiunea la internet\n• Dacă relay-urile sunt configurate dar neconectate, apasă \"Reîncearcă conexiunea\"\n• Fă o captură de ecran pentru depanare';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Toate endpoint-urile REST sunt sănătoase!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Unele endpoint-uri REST au eșuat - vezi detaliile mai sus';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de evenimente video',
      few: '$count evenimente video',
      one: '1 eveniment video',
    );
    return 'Am găsit $_temp0 în baza de date';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'Interogarea a eșuat. Încearcă din nou.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de relay-uri',
      few: '$count relay-uri',
      one: '1 relay',
    );
    return 'Conectat la $_temp0!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'N-am putut conecta la niciun relay';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Reîncercarea conexiunii a eșuat. Încearcă din nou.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Conectat și autentificat';

  @override
  String get relayDiagnosticConnectedOnly => 'Conectat';

  @override
  String get relayDiagnosticNotConnected => 'Neconectat';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Niciun relay configurat';

  @override
  String get relayDiagnosticFailed => 'Eșuat';

  @override
  String get notificationSettingsTitle => 'Notificări';

  @override
  String get notificationSettingsResetTooltip =>
      'Resetează la valorile implicite';

  @override
  String get notificationSettingsTypes => 'Tipuri de notificări';

  @override
  String get notificationSettingsLikes => 'Aprecieri';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Când cineva âți apreciază videoclipurile';

  @override
  String get notificationSettingsComments => 'Comentarii';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Când cineva comentează la videoclipurile tale';

  @override
  String get notificationSettingsFollows => 'Urmăriri';

  @override
  String get notificationSettingsFollowsSubtitle => 'Când cineva te urmărește';

  @override
  String get notificationSettingsMentions => 'Menționări';

  @override
  String get notificationSettingsMentionsSubtitle => 'Când ești menționat';

  @override
  String get notificationSettingsReposts => 'Redistribuiri';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Când cineva âți redistribuie videoclipurile';

  @override
  String get notificationSettingsNewPosts => 'Videoclipuri noi';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Când cineva pe care îl urmărești postează';

  @override
  String get notificationSettingsActions => 'Acțiuni';

  @override
  String get notificationSettingsMarkAllAsRead => 'Marchează toate ca citite';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Marchează toate notificările ca citite';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Toate notificările au fost marcate ca citite';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Marcarea tuturor ca citite a eșuat';

  @override
  String get notificationSettingsResetToDefaults =>
      'Setările au fost resetate la valorile implicite';

  @override
  String get notificationSettingsAbout => 'Despre notificări';

  @override
  String get notificationSettingsAboutDescription =>
      'Notificările sunt alimentate de protocolul Nostr. Actualizările în timp real depind de conexiunea ta la relay-urile Nostr. Unele notificări pot avea întârzieri.';

  @override
  String get safetySettingsWhatYouSee => 'CE VEZI';

  @override
  String get safetySettingsWhatYouPublish => 'CE PUBLICI';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Arată doar videoclipurile găzduite de Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ascunde videoclipurile servite de alte găzduiri media';

  @override
  String get safetySettingsModeration => 'MODERARE';

  @override
  String get safetySettingsBlockedUsers => 'UTILIZATORI BLOCAȚI';

  @override
  String get safetySettingsAgeVerification => 'VERIFICARE VÂRSTĂ';

  @override
  String get safetySettingsAgeConfirmation =>
      'Confirm că am 18 ani sau mai mult';

  @override
  String get safetySettingsAgeRequired =>
      'Necesar pentru a vedea conținut pentru adulți';

  @override
  String get safetySettingsAgeLockedForMinor => 'Blocat pentru contul tău';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Serviciu oficial de moderare (activat implicit)';

  @override
  String get safetySettingsPeopleIFollow => 'Oameni pe care âi urmăresc';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Abonează-te la etichete de la oameni pe care âi urmărești';

  @override
  String get safetySettingsAddCustomLabeler =>
      'Adaugă etichetator personalizat';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Introdu npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Adaugă etichetator personalizat';

  @override
  String get safetySettingsRemoveLabeler => 'Elimină etichetatorul';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Introdu adresa npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Niciun utilizator blocat';

  @override
  String get safetySettingsUnblock => 'Deblochează';

  @override
  String get safetySettingsUserUnblocked => 'Utilizator deblocat';

  @override
  String get safetySettingsCancel => 'Anulează';

  @override
  String get safetySettingsAdd => 'Adaugă';

  @override
  String get analyticsTitle => 'Statistici creator';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostice';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Comută diagnosticele';

  @override
  String get analyticsRetry => 'Reîncearcă';

  @override
  String get analyticsUnableToLoad => 'Nu am putut încărca statisticile.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Autentifică-te ca să vezi statisticile pentru creatori.';

  @override
  String get analyticsViewDataUnavailable =>
      'Vizualizările nu sunt disponibile momentan de la relay pentru aceste postări. Metricile de aprecieri/comentarii/redistribuiri sunt totuși corecte.';

  @override
  String get analyticsViewDataTitle => 'Date vizualizări';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Actualizat $time • Scorurile folosesc aprecieri, comentarii, redistribuiri și vizualizări/bucle de la Funnelcake când sunt disponibile.';
  }

  @override
  String get analyticsVideos => 'Videoclipuri';

  @override
  String get analyticsViews => 'Vizualizări';

  @override
  String get analyticsInteractions => 'Interacțiuni';

  @override
  String get analyticsEngagement => 'Implicare';

  @override
  String get analyticsFollowers => 'Urmăritori';

  @override
  String get analyticsAvgPerPost => 'Medie/Postare';

  @override
  String get analyticsInteractionMix => 'Mixul interacțiunilor';

  @override
  String get analyticsLikes => 'Aprecieri';

  @override
  String get analyticsComments => 'Comentarii';

  @override
  String get analyticsReposts => 'Redistribuiri';

  @override
  String get analyticsPerformanceHighlights => 'Repere de performanță';

  @override
  String get analyticsMostViewed => 'Cele mai vizualizate';

  @override
  String get analyticsMostDiscussed => 'Cele mai discutate';

  @override
  String get analyticsMostReposted => 'Cele mai redistribuite';

  @override
  String get analyticsNoVideosYet => 'Încă niciun videoclip';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Date de vizualizare indisponibile';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count vizualizări';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count comentarii';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count redistribuiri';
  }

  @override
  String get analyticsTopContent => 'Conținut de top';

  @override
  String get analyticsPublishPrompt =>
      'Publică câteva videoclipuri ca să vezi clasamentele.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Procentul din dreapta = Rata de implicare (interacțiuni împărțite la vizualizări).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Rata de implicare are nevoie de date de vizualizare; valorile apar ca N/A până când sunt disponibile vizualizările.';

  @override
  String get analyticsEngagementLabel => 'Implicare';

  @override
  String get analyticsViewsUnavailable => 'vizualizări indisponibile';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interacțiuni';
  }

  @override
  String get analyticsPostAnalytics => 'Statistici postare';

  @override
  String get analyticsOpenPost => 'Deschide postarea';

  @override
  String get analyticsRecentDailyInteractions => 'Interacțiuni zilnice recente';

  @override
  String get analyticsNoActivityYet =>
      'Încă nicio activitate în acest interval.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interacțiuni = aprecieri + comentarii + redistribuiri după data postării.';

  @override
  String get analyticsDailyBarExplainer =>
      'Lungimea barei e relativă la cea mai bună zi a ta din această fereastră.';

  @override
  String get analyticsAudienceSnapshot => 'Instantaneu audiență';

  @override
  String analyticsFollowersCount(String count) {
    return 'Urmăritori: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Urmăriți: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Detaliile despre sursa/geografia/timpul audienței se vor popula pe măsură ce Funnelcake adaugă endpoint-uri de statistici de audiență.';

  @override
  String get analyticsRetention => 'Retenție';

  @override
  String get analyticsRetentionWithViews =>
      'Curba de retenție și defalcarea timpului de vizionare vor apărea odată ce retenția per secundă/bucketă ajunge de la Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Datele de retenție sunt indisponibile până când statisticile de vizualizări+timp de vizionare sunt returnate de Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostice';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total videoclipuri: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Cu vizualizări: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Fără vizualizări: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hidratate (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hidratate (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Surse: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Folosește date de test';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Creează un cont Divine nou';

  @override
  String get authCreateNewAccountShort => 'Creează cont nou';

  @override
  String get authSignInDifferentAccount => 'Autentifică-te cu un alt cont';

  @override
  String get authUseAnotherAccount => 'Folosește alt cont';

  @override
  String authContinueAs(String displayName) {
    return 'Continuă ca $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Ciornele și clipurile tale sunt salvate pentru acest cont';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Autentificarea aici le va ascunde';

  @override
  String get authTermsPrefix =>
      'Alegând o opțiune de mai jos, confirmi că ai cel puțin 16 ani (sau ai finalizat ';

  @override
  String get authTermsAgeAuthorizationCta => 'autorizarea de vârstă Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') și ești de acord cu ';

  @override
  String get authTermsOfService => 'Termenii serviciului';

  @override
  String get authPrivacyPolicy => 'Politica de confidențialitate';

  @override
  String get authTermsAnd => ', și ';

  @override
  String get authSafetyStandards => 'Standardele de siguranță';

  @override
  String get authAmberNotInstalled => 'Aplicația Amber nu e instalată';

  @override
  String get authAmberConnectionFailed => 'N-am putut conecta cu Amber';

  @override
  String get authPasswordResetSent =>
      'Dacă există un cont cu acel email, am trimis un link de resetare a parolei.';

  @override
  String get authSignInTitle => 'Autentificare';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Parolă';

  @override
  String get authConfirmPasswordLabel => 'Confirmă parola';

  @override
  String get authEmailRequired => 'Emailul este obligatoriu';

  @override
  String get authEmailInvalid => 'Introdu o adresă de email validă';

  @override
  String get authPasswordRequired => 'Parola este obligatorie';

  @override
  String get authConfirmPasswordRequired => 'Confirmă parola';

  @override
  String get authPasswordsDoNotMatch => 'Parolele nu se potrivesc';

  @override
  String get authForgotPassword => 'Ai uitat parola?';

  @override
  String get authImportNostrKey => 'Importă cheia Nostr';

  @override
  String get authConnectSignerApp => 'Conectează o aplicație de semnare';

  @override
  String get authSignInWithAmber => 'Autentifică-te cu Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Conectare cu extensia browserului';

  @override
  String get authNip07ConnectionFailed =>
      'Nu s-a putut conecta la extensia browserului.';

  @override
  String get authNip07ExtensionNotFound =>
      'Nu a fost găsită nicio extensie de browser. Instalează Alby, nos2x sau altă extensie compatibilă cu NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opțiuni de autentificare';

  @override
  String get authInfoEmailPasswordTitle => 'Email și parolă';

  @override
  String get authInfoEmailPasswordDescription =>
      'Autentifică-te cu contul tău Divine. Dacă te-ai înregistrat cu email și parolă, folosește-le aici.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Ai deja o identitate Nostr? Importă cheia ta privată nsec dintr-un alt client.';

  @override
  String get authInfoSignerAppTitle => 'Aplicație de semnare';

  @override
  String get authInfoSignerAppDescription =>
      'Conectează-te cu un semnatar la distanță compatibil NIP-46 cum ar fi nsecBunker pentru securitate sporită a cheilor.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Folosește aplicația de semnare Amber pe Android ca să gestionezi cheile tale Nostr în siguranță.';

  @override
  String get authInfoBrowserExtensionTitle => 'Extensie de Browser';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Conectează-te cu o extensie de browser NIP-07 precum Alby sau nos2x. Cheile tale rămân în extensie — Divine nu le vede niciodată.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'E-mail sau parolă greșite. Mai încearcă o dată.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Verifică-ți e-mailul înainte de a te conecta — caută linkul în inbox.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Nu pare o adresă de e-mail validă.';

  @override
  String get authSignInErrorNetwork =>
      'Serverul nu poate fi contactat. Verifică-ți conexiunea și încearcă din nou.';

  @override
  String get authSignInErrorGeneric => 'Ceva n-a mers bine. Încearcă din nou.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Nu știi sigur cum te-ai conectat data trecută? ';

  @override
  String get authSignInOptionsHintCta => 'Vezi toate opțiunile de conectare';

  @override
  String get authCreateAccountTitle => 'Creează cont';

  @override
  String get authBackToInviteCode => 'Înapoi la codul de invitație';

  @override
  String get authUseDivineNoBackup => 'Folosește Divine fără backup';

  @override
  String get authSkipConfirmTitle => 'Un ultim lucru...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Ești înăuntru! Creăm o cheie sigură care va alimenta contul tău Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Fără email, cheia ta e singurul mod prin care Divine știe că acest cont e al tău.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Poți accesa cheia în aplicație, dar, dacă nu ești tehnic, recomandăm să adaugi un email și o parolă acum. Face mai ușoară autentificarea și restabilirea contului dacă pierzi sau resetezi dispozitivul.';

  @override
  String get authAddEmailPassword => 'Adaugă email și parolă';

  @override
  String get authUseThisDeviceOnly => 'Folosește doar acest dispozitiv';

  @override
  String get authCompleteRegistration => 'Finalizează-ți înregistrarea';

  @override
  String get authVerifying => 'Se verifică...';

  @override
  String get authVerificationLinkSent => 'Am trimis un link de verificare la:';

  @override
  String get authClickVerificationLink =>
      'Apasă linkul din email ca\nsă finalizezi înregistrarea.';

  @override
  String get authPleaseWaitVerifying =>
      'Te rugăm să aștepți cât âți verificăm emailul...';

  @override
  String get authWaitingForVerification => 'Se așteaptă verificarea';

  @override
  String get authOpenEmailApp => 'Deschide aplicația de email';

  @override
  String get authVerificationPinPrompt =>
      'Sau introdu codul de 6 cifre din email';

  @override
  String get authVerificationPinFieldLabel => 'Cod de 6 cifre';

  @override
  String get authVerificationPinSubmit => 'Verifică codul';

  @override
  String get authVerificationResendPrompt => 'Nu l-ai primit?';

  @override
  String get authVerificationResend => 'Retrimite';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Retrimite în $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Nu am putut retrimite emailul. Încearcă din nou.';

  @override
  String get authVerificationResendExpired =>
      'Înregistrarea a expirat. Începe din nou ca să primești un cod proaspăt.';

  @override
  String get authVerificationResendUnavailable =>
      'Retrimiterea nu e disponibilă acum. Folosește codul din 6 cifre din e-mailul pe care ți l-am trimis deja.';

  @override
  String get authVerificationPollingStopped =>
      'Am oprit verificarea automată. Introdu codul din 6 cifre din e-mail ca să finalizezi autentificarea.';

  @override
  String get authWelcomeToDivine => 'Bun venit pe Divine!';

  @override
  String get authEmailVerified => 'Emailul tău a fost verificat.';

  @override
  String get authSigningYouIn => 'Te autentificăm';

  @override
  String get authErrorTitle => 'Ups.';

  @override
  String get authVerificationFailed =>
      'N-am reușit să-ți verificăm emailul.\nÎncearcă din nou.';

  @override
  String get authStartOver => 'Începe din nou';

  @override
  String get authEmailVerifiedLogin =>
      'Email verificat! Autentifică-te ca să continui.';

  @override
  String get authVerificationLinkExpired =>
      'Acest link de verificare nu mai e valid.';

  @override
  String get authVerificationConnectionError =>
      'Nu am putut verifica emailul. Verifică-ți conexiunea și încearcă din nou.';

  @override
  String get authWaitlistConfirmTitle => 'Ești înăuntru!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Vom da noutăți la $email.\nCând apar mai multe coduri de invitație, ți le trimitem.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Încearcă din nou';

  @override
  String get authContactSupport => 'Contactează asistența';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'N-am putut deschide $email';
  }

  @override
  String get authAddInviteCode => 'Adaugă codul de invitație';

  @override
  String get authInviteCodeLabel => 'Cod de invitație';

  @override
  String get authEnterYourCode => 'Introdu codul tău';

  @override
  String get authNext => 'Mai departe';

  @override
  String get authJoinWaitlist => 'Alătură-te listei de așteptare';

  @override
  String get authJoinWaitlistTitle => 'Alătură-te listei de așteptare';

  @override
  String get authJoinWaitlistDescription =>
      'Dă-ne emailul tău și âți vom trimite noutăți pe măsură ce se deschide accesul.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Trimiteți-mi inspirație de la Divine';

  @override
  String get authInviteAccessHelp => 'Ajutor pentru accesul prin invitație';

  @override
  String get authGeneratingConnection => 'Se generează conexiunea...';

  @override
  String get authConnectedAuthenticating => 'Conectat! Se autentifică...';

  @override
  String get authConnectionTimedOut => 'Conexiunea a expirat';

  @override
  String get authApproveConnection =>
      'Asigură-te că ai aprobat conexiunea în aplicația ta de semnare.';

  @override
  String get authConnectionCancelled => 'Conexiune anulată';

  @override
  String get authConnectionCancelledMessage => 'Conexiunea a fost anulată.';

  @override
  String get authConnectionFailed => 'Conexiunea a eșuat';

  @override
  String get authUnknownError => 'A apărut o eroare necunoscută.';

  @override
  String get authNostrConnectStartFailed =>
      'N-am putut contacta aplicația de semnare. Verifică-ți conexiunea și încearcă din nou.';

  @override
  String get authNostrConnectInvalidSession =>
      'Acest link de conexiune nu mai e valid. Începe unul nou.';

  @override
  String get authNostrConnectSetupFailed =>
      'Aproape gata — n-am putut finaliza autentificarea. Încearcă din nou.';

  @override
  String get authUrlCopied => 'URL copiat în clipboard';

  @override
  String get authConnectToDivine => 'Conectează-te la Divine';

  @override
  String get authPasteBunkerUrl => 'Lipește URL-ul bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker invalid. Ar trebui să înceapă cu bunker://';

  @override
  String get authScanSignerApp =>
      'Scanează cu aplicația ta\nde semnare ca să te conectezi.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Se așteaptă conexiunea... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copiază URL-ul';

  @override
  String get authShare => 'Partajează';

  @override
  String get authAddBunker => 'Adaugă bunker';

  @override
  String get authCompatibleSignerApps => 'Aplicații de semnare compatibile';

  @override
  String get authFailedToConnect => 'N-am putut conecta';

  @override
  String get authResetPasswordTitle => 'Resetează parola';

  @override
  String get authResetPasswordSubtitle =>
      'Introdu parola nouă. Trebuie să aibă cel puțin 8 caractere.';

  @override
  String get authNewPasswordLabel => 'Parolă nouă';

  @override
  String get authConfirmNewPasswordLabel => 'Confirmă noua parolă';

  @override
  String get authPasswordTooShort =>
      'Parola trebuie să aibă cel puțin 8 caractere';

  @override
  String get authPasswordResetSuccess =>
      'Parola a fost resetată cu succes. Autentifică-te.';

  @override
  String get authPasswordResetFailed => 'Resetarea parolei a eșuat';

  @override
  String get authUnexpectedError =>
      'A apărut o eroare neașteptată. Încearcă din nou.';

  @override
  String get authUpdatePassword => 'Actualizează parola';

  @override
  String get authSecureAccountTitle => 'Securizează contul';

  @override
  String get authUnableToAccessKeys =>
      'Nu am putut accesa cheile tale. Încearcă din nou.';

  @override
  String get authRegistrationFailed => 'Înscrierea a eșuat';

  @override
  String get authRegistrationComplete =>
      'Înscriere finalizată. Verifică-ți emailul.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'N-am putut trimite emailul de resetare.';

  @override
  String get authSending => 'Se trimite...';

  @override
  String get authSignInButton => 'Autentificare';

  @override
  String get authVerificationErrorTimeout =>
      'Verificarea a expirat. Încearcă să te înregistrezi din nou.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verificare eșuată — cod de autorizare lipsă.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verificare eșuată. Încearcă din nou.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Eroare de rețea la autentificare. Încearcă din nou.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verificare eșuată. Încearcă să te înregistrezi din nou.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Autentificarea a eșuat. Încearcă să te conectezi manual.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Acest e-mail este deja înregistrat. Conectează-te în schimb.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Codul nu se potrivește. Verifică-l din nou și încearcă iar.';

  @override
  String get authVerificationErrorPinExpired =>
      'Codul a expirat. Apasă Retrimite pentru a primi unul nou.';

  @override
  String get authVerificationErrorPinLocked =>
      'Prea multe încercări. Apasă Retrimite pentru a primi un cod nou.';

  @override
  String get authVerificationErrorPinFailed =>
      'Nu am putut verifica codul. Încearcă din nou.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Introducerea codului nu e disponibilă acum. Apasă linkul din email sau retrimite pentru a primi unul nou.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Introdu un cod de invitație de forma ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound => 'Codul de invitație nu pare valid.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Codul de invitație a fost deja folosit sau revocat.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Invitațiile acestui creator s-au epuizat';

  @override
  String get authInviteGateErrorUnavailable =>
      'Codul de invitație nu este disponibil. Înscrie-te pe lista de așteptare și îți trimitem o invitație când se eliberează un loc.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Nu am putut verifica acest cod. Încearcă din nou.';

  @override
  String get authInviteGateErrorUnknown =>
      'Ceva nu a mers bine. Încearcă din nou codul de invitație.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Acest cod de invitație nu mai e disponibil. Întoarce-te la codul tău, alătură-te listei de așteptare sau contactează asistența.';

  @override
  String get authInviteErrorInvalid =>
      'Acest cod de invitație nu poate fi folosit acum. Întoarce-te la codul tău, alătură-te listei de așteptare sau contactează asistența.';

  @override
  String get authInviteErrorTemporary =>
      'N-am putut confirma invitația ta acum. Întoarce-te la codul tău și încearcă din nou, sau contactează asistența.';

  @override
  String get authInviteErrorUnknown =>
      'N-am putut activa invitația ta. Întoarce-te la codul tău, alătură-te listei de așteptare sau contactează asistența.';

  @override
  String get shareSheetSave => 'Salvează';

  @override
  String get shareSheetRemoveFromSaved => 'Elimină din salvate';

  @override
  String get shareSheetSaveToGallery => 'Salvează în galerie';

  @override
  String get shareSheetSaveWithWatermark => 'Salvează cu filigran';

  @override
  String get shareSheetSaveVideo => 'Salvează videoclipul';

  @override
  String get shareSheetAddToClips => 'Adaugă la clipuri';

  @override
  String get shareSheetNameClipTitle => 'Denumește acest clip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Alege un nume pe care îl recunoști în biblioteca ta.';

  @override
  String get shareSheetClipTitleLabel => 'Titlul clipului';

  @override
  String get shareSheetSaveClip => 'Salvează clipul';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '„$title” a fost salvat în clipuri';
  }

  @override
  String get shareSheetUntitledClip => 'Clip fără titlu';

  @override
  String get shareSheetAddToClipsFailed => 'Nu s-a putut adăuga la clipuri';

  @override
  String get shareSheetAddToList => 'Adaugă la listă';

  @override
  String get shareSheetCopy => 'Copiază';

  @override
  String get shareSheetShareVia => 'Partajează prin';

  @override
  String get shareSheetEventJson => 'JSON eveniment';

  @override
  String get shareSheetEventId => 'ID eveniment';

  @override
  String get shareSheetMoreActions => 'Mai multe acțiuni';

  @override
  String get shareSheetCrosspost => 'Crosspostează';

  @override
  String get crosspostSheetTitle => 'Crosspostează acest videoclip';

  @override
  String get crosspostSheetSubtitle =>
      'Trimite-l pe platformele tale conectate. Postarea poate dura câteva minute.';

  @override
  String get crosspostSubmit => 'Crosspostează';

  @override
  String get crosspostStatusQueued => 'În coadă';

  @override
  String get crosspostStatusUploading => 'Se încarcă';

  @override
  String get crosspostStatusProcessing => 'Se procesează';

  @override
  String get crosspostStatusPosted => 'Postat';

  @override
  String get crosspostStatusFailed => 'Eșuat';

  @override
  String get crosspostStatusSkipped => 'Omis';

  @override
  String get crosspostStatusNeedsReauth => 'Necesită reconectare';

  @override
  String get crosspostViewPost => 'Vezi postarea';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Reconectează $platform în setările de crosspost ca să continui să postezi.';
  }

  @override
  String get crosspostReconnect => 'Reconectează';

  @override
  String get crosspostErrorNotOwner =>
      'Doar propriile videoclipuri pot fi crosspostate.';

  @override
  String get crosspostErrorNotEligible =>
      'Acest videoclip nu e eligibil pentru crosspost.';

  @override
  String get crosspostErrorNotConnected => 'Platforma asta nu e conectată.';

  @override
  String get crosspostErrorUnauthorized =>
      'Reconectează-ți contul, apoi încearcă din nou.';

  @override
  String get crosspostErrorNetwork =>
      'Nu am putut contacta serviciul de crosspost. Încearcă din nou într-o clipă.';

  @override
  String get crosspostFailedGeneric => 'Crosspostarea a eșuat.';

  @override
  String get crosspostStillWorking =>
      'Încă lucrăm. Poți închide fereastra asta — postarea continuă în fundal.';

  @override
  String get crosspostDone => 'Gata';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Salvat în galerie';

  @override
  String get watermarkDownloadShare => 'Partajează';

  @override
  String get watermarkDownloadDone => 'Gata';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'E nevoie de acces la Poze';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Pentru a salva videoclipuri, permite accesul la Poze în Setări.';

  @override
  String get watermarkDownloadOpenSettings => 'Deschide setările';

  @override
  String get watermarkDownloadNotNow => 'Nu acum';

  @override
  String get watermarkDownloadFailed => 'Descărcare eșuată';

  @override
  String get watermarkDownloadDismiss => 'Respinge';

  @override
  String get watermarkDownloadStageDownloading => 'Se descarcă videoclipul';

  @override
  String get watermarkDownloadStageWatermarking => 'Se adaugă filigranul';

  @override
  String get watermarkDownloadStageSaving => 'Se salvează în galerie';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Se aduce videoclipul din rețea...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Se aplică filigranul Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Se salvează videoclipul cu filigran în galeria ta...';

  @override
  String get shareMenuBookmarks => 'Semne de carte';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de seturi de urmărire disponibile',
      few: '$count seturi de urmărire disponibile',
      one: '1 set de urmărire disponibil',
    );
    return '$_temp0';
  }

  @override
  String get peopleListsAddToList => 'Adaugă la listă';

  @override
  String get peopleListsSheetTitle => 'Adaugă la listă';

  @override
  String get peopleListsEmptyTitle => 'Nicio listă încă';

  @override
  String get peopleListsEmptySubtitle =>
      'Creează o listă pentru a începe să grupezi persoane.';

  @override
  String get peopleListsCreateList => 'Creează listă';

  @override
  String get peopleListsNewListTitle => 'Listă nouă';

  @override
  String get peopleListsRouteTitle => 'Listă de persoane';

  @override
  String get peopleListsListNameLabel => 'Numele listei';

  @override
  String get peopleListsListNameHint => 'Prieteni apropiați';

  @override
  String get peopleListsCreateButton => 'Creează';

  @override
  String get peopleListsAddPeopleTitle => 'Adaugă persoane';

  @override
  String get peopleListsAddPeopleTooltip => 'Adaugă persoane';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Adaugă persoane la listă';

  @override
  String get peopleListsListNotFoundTitle => 'Lista nu a fost găsită';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lista nu a fost găsită. Poate a fost ștearsă.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Această listă poate a fost ștearsă.';

  @override
  String get peopleListsNoPeopleTitle => 'Nicio persoană în această listă';

  @override
  String get peopleListsNoPeopleSubtitle => 'Adaugă persoane pentru a începe';

  @override
  String get peopleListsNoVideosTitle => 'Niciun videoclip încă';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Videoclipurile membrilor listei vor apărea aici';

  @override
  String get peopleListsNoVideosAvailable => 'Niciun videoclip disponibil';

  @override
  String get peopleListsFailedToLoadVideos =>
      'Încărcarea videoclipurilor a eșuat';

  @override
  String get peopleListsVideoNotAvailable => 'Videoclip indisponibil';

  @override
  String get peopleListsBackToGridTooltip => 'Înapoi la grilă';

  @override
  String get peopleListsErrorLoadingVideos =>
      'Eroare la încărcarea videoclipurilor';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Nicio persoană disponibilă de adăugat.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Adaugă la $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Caută persoane';

  @override
  String get peopleListsAddPeopleError =>
      'Nu s-au putut încărca persoanele. Te rugăm să încerci din nou.';

  @override
  String get peopleListsAddPeopleRetry => 'Încearcă din nou';

  @override
  String get peopleListsAddButton => 'Adaugă';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Adaugă $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'În $count liste',
      few: 'În $count liste',
      one: 'Într-o listă',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Elimini $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Va fi eliminat/ă din această listă.';

  @override
  String get peopleListsRemove => 'Elimină';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name eliminat/ă din listă';
  }

  @override
  String get peopleListsUndo => 'Anulează';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profilul lui $name. Apasă lung pentru a elimina.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Vezi profilul lui $name';
  }

  @override
  String get shareMenuEditVideo => 'Editează videoclipul';

  @override
  String get shareMenuDeleteVideo => 'Șterge videoclipul';

  @override
  String shareMenuVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Asta va șterge definitiv acest videoclip din Divine. Poate apărea în continuare în clienți Nostr terți care folosesc alte relay-uri.';

  @override
  String get shareMenuCancel => 'Anulează';

  @override
  String get shareMenuDelete => 'Șterge';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Ștergerea nu e încă gata. Încearcă din nou peste un moment.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Poți șterge doar propriile videoclipuri.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Autentifică-te din nou, apoi încearcă să ștergi.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Nu am putut semna cererea de ștergere. Încearcă din nou.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Releul nu a acceptat această cerere de ștergere. Încearcă din nou în scurt timp.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Nu am putut contacta releul. Verifică conexiunea și încearcă din nou.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Șters. Nu toate releele au confirmat, așa că poate apărea în continuare în alte aplicații.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Nu am putut șterge acest videoclip. Încearcă din nou.';

  @override
  String get shareMenuUpdate => 'Actualizează';

  @override
  String get shareMenuChangeCover => 'Schimbă coperta';

  @override
  String get shareMenuVideoUpdated => 'Videoclip actualizat cu succes';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitații pentru colaboratori nu au fost trimise.',
      one: '1 invitație pentru colaborator nu a fost trimisă.',
    );
    return 'Videoclip actualizat, dar $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Conectează-te din nou, apoi încearcă iar.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Acest videoclip nu are o sursă redabilă, așa că nu poate fi editat.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'N-am putut semna modificarea. Încearcă din nou.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Releul nu a acceptat modificarea. Încearcă din nou în scurt timp.';

  @override
  String get videoUpdateErrorGeneric =>
      'N-am putut actualiza acest videoclip. Încearcă din nou.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Ștergi videoclipul?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Se elimină videoclipul…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Videoclip șters.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Videoclip eliminat. Poate dura puțin până dispare de peste tot.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Videoclip eliminat, dar nu am putut șterge fiecare copie. Contactează asistența.';

  @override
  String get authSessionExpired =>
      'Sesiunea ta a expirat. Autentifică-te din nou.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'N-am putut autentifica. Încearcă din nou.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Autentificarea web nu e suportată în modul sigur. Folosește aplicația mobilă pentru gestionarea sigură a cheilor.';

  @override
  String get webAuthEnterBunkerUri => 'Introdu un URI bunker';

  @override
  String get webAuthConnectTitle => 'Conectează-te la Divine';

  @override
  String get webAuthChooseMethod =>
      'Alege metoda ta preferată de autentificare Nostr';

  @override
  String get webAuthBrowserExtension => 'Extensie de browser';

  @override
  String get webAuthRecommended => 'RECOMANDAT';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner =>
      'Conectează-te la un semnatar la distanță';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Lipește din clipboard';

  @override
  String get webAuthConnectToBunker => 'Conectează-te la Bunker';

  @override
  String get webAuthNewToNostr => 'Ești nou pe Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Instalează o extensie de browser ca Alby sau nos2x pentru cea mai ușoară experiență, sau folosește nsec bunker pentru semnare la distanță sigură.';

  @override
  String get soundsTitle => 'Sunete';

  @override
  String get soundsSearchHint => 'Caută sunete...';

  @override
  String get soundsSearchResults => 'Rezultatele căutării';

  @override
  String get soundsNoSoundsFound => 'Niciun sunet găsit';

  @override
  String get soundsNoSoundsFoundDescription => 'Încearcă alt termen de căutare';

  @override
  String get soundsSavedToLibrary => 'Salvat în Sunete';

  @override
  String get soundsAlreadySavedToLibrary => 'Deja în Sunete';

  @override
  String get soundsSavedLibraryTitle => 'Sunetele mele';

  @override
  String get soundsSavedEmptyTitle => 'Niciun sunet salvat încă';

  @override
  String get soundsSavedEmptyDescription =>
      'Atinge Folosește sunetul pe un videoclip pentru a-l salva aici.';

  @override
  String get soundsRemoveSavedSound => 'Elimină sunetul';

  @override
  String get savedSoundSaveAction => 'Salvează';

  @override
  String get savedSoundPausePreviewAction => 'Pune pauză la previzualizare';

  @override
  String get savedSoundResumePreviewAction => 'Reia previzualizarea';

  @override
  String get savedSoundDetailsSheetTitle => 'Detalii despre sunet';

  @override
  String get savedSoundRemoveConfirmTitle => 'Elimini acest sunet?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Dispare din biblioteca ta, dar îl poți salva din nou din orice videoclip care îl folosește.';

  @override
  String get soundsRemovedFromLibrary => 'Eliminat din Sunete';

  @override
  String get soundsSaveFailed =>
      'Nu am putut salva acel sunet. Încearcă din nou.';

  @override
  String get soundsRemoveFailed =>
      'Nu am putut elimina acel sunet. Încearcă din nou.';

  @override
  String get soundSyncStatusSyncing => 'Se sincronizează sunetele tale…';

  @override
  String get soundSyncStatusSynced => 'Sunetele sunt la zi';

  @override
  String get soundSyncStatusFailed =>
      'Nu am putut sincroniza sunetele tale. Vom încerca din nou.';

  @override
  String get soundSyncStatusLocked =>
      'Nu putem debloca biblioteca ta sincronizată pe acest dispozitiv.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMoreOptions => 'Mai multe opțiuni';

  @override
  String profileBlockedUser(String name) {
    return 'L-ai blocat pe $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'L-ai deblocat pe $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Nu-l mai urmărești pe $name';
  }

  @override
  String get profileFeedError =>
      'Serverul nu poate fi contactat. Verifică-ți conexiunea și încearcă din nou.';

  @override
  String get profileFeedLoadMoreError =>
      'Nu am putut încărca mai multe videoclipuri. Trage în jos pentru reîmprospătare.';

  @override
  String get notificationsTabAll => 'Toate';

  @override
  String get notificationsTabLikes => 'Aprecieri';

  @override
  String get notificationsTabComments => 'Comentarii';

  @override
  String get notificationsTabFollows => 'Urmăriri';

  @override
  String get notificationsTabReposts => 'Redistribuiri';

  @override
  String get notificationsFailedToLoad => 'N-am putut încărca notificările';

  @override
  String get notificationsRetry => 'Reîncearcă';

  @override
  String get notificationsRefreshError =>
      'Actualizare eșuată — se afișează ce există';

  @override
  String get notificationsUnreadPrefix => 'Notificare necitită';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de notificări necitite',
      few: '$count notificări necitite',
      one: '1 notificare necitită',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Vezi profilul $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Vezi profilurile';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Miniatură video pentru $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Miniatură video';

  @override
  String get notificationsInviteSingular =>
      'Ai 1 invitație de împărțit cu un prieten!';

  @override
  String notificationsInvitePlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de invitații',
      few: '$count invitații',
      one: '1 invitație',
    );
    return 'Ai $_temp0 de împărțit cu prietenii!';
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
  String get notificationsVideoUnavailable => 'Videoclip indisponibil';

  @override
  String get feedFailedToLoadVideos => 'N-am putut încărca videoclipurile';

  @override
  String get feedRetry => 'Reîncearcă';

  @override
  String get feedNoFollowedUsers =>
      'Niciun utilizator urmărit.\nUrmărește pe cineva ca să-i vezi videoclipurile aici.';

  @override
  String get feedModeForYou => 'Pentru tine';

  @override
  String get feedModeNew => 'Nou';

  @override
  String get feedModeFollowing => 'Urmăresc';

  @override
  String get feedModeClassics => 'Clasice';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Mod flux: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Autor videoclip: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar autor';

  @override
  String get feedForYouEmpty =>
      'Feedul tău Pentru tine este gol.\nExplorează videoclipuri și urmărește creatori pentru a-l modela.';

  @override
  String get feedFollowingEmpty =>
      'Încă nu există videoclipuri de la persoanele pe care le urmărești.\nGăsește creatori care îți plac și urmărește-i.';

  @override
  String get feedLatestEmpty =>
      'Încă nu există videoclipuri noi.\nRevino curând.';

  @override
  String get feedClassicEmpty => 'Încă nu există clasice.\nRevino curând.';

  @override
  String get feedExploreVideos => 'Explorează videoclipuri';

  @override
  String get feedLoadingMore => 'Se încarcă mai multe videoclipuri…';

  @override
  String get feedRefreshed => 'Feedul a fost reîncărcat';

  @override
  String get uploadUploadingVideo => 'Se încarcă videoclipul';

  @override
  String get postPublishConfirmationTitle => 'Publicat pe profilul tău';

  @override
  String get postPublishConfirmationView => 'Vezi';

  @override
  String get postPublishConfirmationShare => 'Partajează';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Miniatura videoclipului pe care tocmai l-ai publicat';

  @override
  String get userSearchNoResults => 'Niciun utilizator găsit';

  @override
  String get userPickerFilterByNameHint => 'Filtrează după nume...';

  @override
  String get userPickerSearchByNameHint => 'Caută după nume...';

  @override
  String get userPickerClearSearchSemantics => 'Șterge căutarea';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name este deja adăugat';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Selectează $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Elimină $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Gașca ta e acolo';

  @override
  String get userPickerEmptyFollowListBody =>
      'Urmărește oameni cu care rezonezi. Când vă urmăriți reciproc, puteți colabora.';

  @override
  String get userPickerGoBack => 'Înapoi';

  @override
  String get userPickerTypeNameToSearch => 'Scrie un nume pentru a căuta';

  @override
  String get userPickerUnavailable =>
      'Căutarea utilizatorilor nu este disponibilă. Te rugăm să încerci din nou mai târziu.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Căutarea a eșuat. Încearcă din nou.';

  @override
  String get forgotPasswordTitle => 'Resetează parola';

  @override
  String get forgotPasswordDescription =>
      'Introdu adresa ta de email și âți trimitem un link de resetare a parolei.';

  @override
  String get forgotPasswordEmailLabel => 'Adresă de email';

  @override
  String get forgotPasswordCancel => 'Anulează';

  @override
  String get forgotPasswordSendLink => 'Trimite linkul de resetare';

  @override
  String get ageVerificationContentWarning => 'Atenționare de conținut';

  @override
  String get ageVerificationTitle => 'Verificare vârstă';

  @override
  String get ageVerificationAdultDescription =>
      'Acest conținut a fost marcat ca putând conține material pentru adulți. Trebuie să ai 18 ani sau mai mult ca să-l vezi.';

  @override
  String get ageVerificationCreationDescription =>
      'Ca să folosești camera și să creezi conținut, trebuie să ai cel puțin 16 ani.';

  @override
  String get ageVerificationAdultQuestion => 'Ai 18 ani sau mai mult?';

  @override
  String get ageVerificationCreationQuestion => 'Ai 16 ani sau mai mult?';

  @override
  String get ageVerificationNo => 'Nu';

  @override
  String get ageVerificationYes => 'Da';

  @override
  String get navHome => 'Acasă';

  @override
  String get navExplore => 'Explorează';

  @override
  String get navInbox => 'Mesaje';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Profilul meu';

  @override
  String get navNotifications => 'Notificări';

  @override
  String get navOpenCamera => 'Deschide camera';

  @override
  String get navExploreClassics => 'Clasice';

  @override
  String get navExploreNewVideos => 'Videoclipuri noi';

  @override
  String get navExploreTrending => 'În trend';

  @override
  String get navExploreForYou => 'Pentru tine';

  @override
  String get navExploreLists => 'Liste';

  @override
  String get routeErrorTitle => 'Eroare';

  @override
  String get routeInvalidHashtag => 'Hashtag invalid';

  @override
  String get routeInvalidConversationId => 'ID de conversație invalid';

  @override
  String get routeInvalidRequestId => 'ID de cerere invalid';

  @override
  String get routeInvalidListId => 'ID de listă invalid';

  @override
  String get routeInvalidUserId => 'ID de utilizator invalid';

  @override
  String get routeInvalidVideoId => 'ID de videoclip invalid';

  @override
  String get routeInvalidSoundId => 'ID de sunet invalid';

  @override
  String get routeInvalidCategory => 'Categorie invalidă';

  @override
  String get routeNoVideosToDisplay => 'Niciun videoclip de afișat';

  @override
  String get routeGoHome => 'Mergi acasă';

  @override
  String get routeInvalidProfileId => 'ID de profil invalid';

  @override
  String get routeUnknownPath => 'Această pagină nu e în aplicație.';

  @override
  String get routeDefaultListName => 'Listă';

  @override
  String get supportTitle => 'Centru de asistență';

  @override
  String get supportContactSupport => 'Contactează asistența';

  @override
  String get supportContactSupportSubtitle =>
      'Începe o conversație sau vezi mesajele trecute';

  @override
  String get supportReportBug => 'Raportează un bug';

  @override
  String get supportReportBugSubtitle => 'Probleme tehnice cu aplicația';

  @override
  String get supportRequestFeature => 'Cere o funcție';

  @override
  String get supportRequestFeatureSubtitle =>
      'Sugerează o îmbunătățire sau o funcție nouă';

  @override
  String get supportSaveLogs => 'Salvează jurnalele';

  @override
  String get supportSaveLogsSubtitle =>
      'Exportă jurnalele într-un fișier pentru trimitere manuală';

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
  String get supportFaq => 'Întrebări frecvente';

  @override
  String get supportFaqSubtitle => 'Întrebări și răspunsuri comune';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Îi ajutăm pe părinți și adolescenți să își formeze obiceiuri sănătoase online';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Cum gestionăm conturile în funcție de vârstă';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Află despre verificare și autenticitate';

  @override
  String get supportLoginRequired =>
      'Autentifică-te ca să contactezi asistența';

  @override
  String get supportExportingLogs => 'Se exportă jurnalele...';

  @override
  String get supportExportLogsFailed => 'N-am putut exporta jurnalele';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Jurnale salvate în $path';
  }

  @override
  String get supportRevealLogsAction => 'Arată în dosar';

  @override
  String get supportChatNotAvailable => 'Chatul de asistență nu e disponibil';

  @override
  String get supportCouldNotOpenMessages =>
      'N-am putut deschide mesajele de asistență';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'N-am putut deschide $pageName';
  }

  @override
  String get reportWhyReporting => 'De ce raportezi acest conținut?';

  @override
  String get reportPolicyNotice =>
      'Divine va acționa asupra rapoartelor de conținut în 24 de ore eliminând conținutul și excluțând utilizatorul care a furnizat conținutul ofensator.';

  @override
  String get reportBlockUser => 'Blochează acest utilizator';

  @override
  String get reportCancel => 'Anulează';

  @override
  String get reportSubmit => 'Raportează';

  @override
  String get reportSelectReason =>
      'Alege un motiv pentru raportarea acestui conținut';

  @override
  String get reportOtherRequiresDetails =>
      'Descrie problema când alegi „Altele”';

  @override
  String get reportDetailsRequired => 'Descrie problema';

  @override
  String get reportDetailsTextOnly =>
      'Doar text — fotografiile și GIF-urile nu pot fi atașate aici.';

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
  String get reportReasonSpam => 'Spam sau conținut nedorit';

  @override
  String get reportReasonSpamSubtitle => 'Conținut nedorit sau repetitiv';

  @override
  String get reportReasonHarassment => 'Hărțuire, bullying sau amenințări';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Răspunsuri sau mențiuni dăunătoare și nedorite';

  @override
  String get reportReasonViolence => 'Conținut violent sau extremist';

  @override
  String get reportReasonViolenceSubtitle =>
      'Conținut violent, extremist sau dăunător';

  @override
  String get reportReasonSexualContent => 'Conținut sexual sau pentru adulți';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nuditate, pornografie sau conținut explicit';

  @override
  String get reportReasonCopyright => 'Încălcarea dreptului de autor';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Utilizarea neautorizată a proprietății intelectuale';

  @override
  String get reportReasonFalseInfo => 'Informații false';

  @override
  String get reportReasonFalseInfoSubtitle => 'Afirmații înșelătoare sau false';

  @override
  String get reportReasonChildSafety => 'Încălcare privind siguranța copiilor';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Îngrijorări generale privind siguranța minorilor';

  @override
  String get reportReasonCsam => 'Abuz sexual asupra copiilor';

  @override
  String get reportReasonCsamSubtitle =>
      'Conținut care înfățișează abuzul sexual asupra minorilor';

  @override
  String get reportReasonUnderageUser => 'Utilizatorul pare să aibă sub 16 ani';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Titularul contului pare să fie minor';

  @override
  String get reportReasonAiGenerated => 'Conținut generat de AI';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Conținut suspectat că este generat de IA';

  @override
  String get reportReasonOther => 'Altă încălcare a politicii';

  @override
  String get reportReasonOtherSubtitle =>
      'Încălcări care nu sunt listate mai sus';

  @override
  String get reportFailed => 'N-am putut raporta conținutul. Încearcă din nou.';

  @override
  String get reportNotSent =>
      'Nu s-a putut trimite raportarea. Verifică conexiunea și încearcă din nou.';

  @override
  String get reportReceivedTitle => 'Raport primit';

  @override
  String get reportReceivedThankYou =>
      'Mersi că ne ajuți să păstrăm Divine în siguranță.';

  @override
  String get reportReceivedReviewNotice =>
      'Echipa noastră âți va revizui raportul și va lua măsuri corespunzătoare. S-ar putea să primești actualizări prin mesaj direct.';

  @override
  String get reportModerationDmDelayed =>
      'Nu am putut contacta direct echipa de moderare chiar acum, dar raportul tău a fost primit și va fi analizat.';

  @override
  String get reportContactModeration => 'Scrie echipei de moderare';

  @override
  String get reportLearnMoreAt => 'Află mai multe la';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Închide';

  @override
  String get listAddToList => 'Adaugă la listă';

  @override
  String listVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de persoane',
      few: '$count persoane',
      one: '1 persoană',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'De ';

  @override
  String get listNewList => 'Listă nouă';

  @override
  String get listDone => 'Gata';

  @override
  String get listErrorLoading => 'Eroare la încărcarea listelor';

  @override
  String listRemovedFrom(String name) {
    return 'Eliminat din $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Adăugat la $name';
  }

  @override
  String get listCreateNewList => 'Creează o listă nouă';

  @override
  String get listNewPeopleList => 'Listă nouă de persoane';

  @override
  String get listCollaboratorsNone => 'Niciunul';

  @override
  String get listAddCollaboratorTitle => 'Adaugă un colaborator';

  @override
  String get listCollaboratorSearchHint => 'Caută în Divine...';

  @override
  String get listNameLabel => 'Numele listei';

  @override
  String get listDescriptionLabel => 'Descriere (opțional)';

  @override
  String get listPublicList => 'Listă publică';

  @override
  String get listPublicListSubtitle =>
      'Alții pot urmări și vedea această listă';

  @override
  String get listPrivateListSubtitle =>
      'Videoclipurile rămân private. Numele, descrierea, etichetele și coperta rămân vizibile.';

  @override
  String get listVisibilityPublic => 'Publică';

  @override
  String get listVisibilityPrivate => 'Privată';

  @override
  String get profileListsEmpty =>
      'Încă n-ai liste. Fă una pentru buclele pe care vrei să le ții împreună.';

  @override
  String get listEditTitle => 'Editează lista';

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
  String get listShareAction => 'Distribuie lista';

  @override
  String get listShareFailed => 'N-am putut distribui lista. Mai încearcă.';

  @override
  String get listSave => 'Salvează';

  @override
  String get listContinue => 'Continuă';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => 'N-am putut actualiza lista. Mai încearcă.';

  @override
  String get listMakePrivateTitle => 'Faci lista privată?';

  @override
  String get listMakePrivateWarning =>
      'Videoclipurile sunt criptate, așa că doar tu le poți vedea. Numele, descrierea, etichetele și coperta rămân vizibile, iar copiile deja distribuite pot rămâne.';

  @override
  String get listMakePublicTitle => 'Faci lista publică?';

  @override
  String get listMakePublicWarning =>
      'Oricine are linkul poate vedea lista și videoclipurile din ea.';

  @override
  String listShareText(String name, String url) {
    return 'Vezi $name pe Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name pe Divine';
  }

  @override
  String get listCancel => 'Anulează';

  @override
  String get listCreate => 'Creează';

  @override
  String get listCreateFailed => 'N-am putut crea lista';

  @override
  String get keyManagementTitle => 'Chei Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Ce sunt cheile Nostr?';

  @override
  String get keyManagementExplanation =>
      'Identitatea ta Nostr e o pereche de chei criptografice:\n\n• Cheia publică (npub) e ca numele tău de utilizator - distribuie-o liber\n• Cheia privată (nsec) e ca parola ta - păstreaz-o secretă!\n\nNsec-ul âți permite să accesezi contul pe orice aplicație Nostr.';

  @override
  String get keyManagementImportTitle => 'Importă cheie existentă';

  @override
  String get keyManagementImportSubtitle =>
      'Ai deja un cont Nostr? Lipește cheia privată (nsec) ca să-l accesezi aici.';

  @override
  String get keyManagementImportButton => 'Importă cheia';

  @override
  String get keyManagementImportWarning => 'Asta âți va înlocui cheia curentă!';

  @override
  String get keyManagementBackupTitle => 'Fă backup la cheia ta';

  @override
  String get keyManagementBackupSubtitle =>
      'Salvează cheia privată (nsec) ca să-ți folosești contul în alte aplicații Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copiază cheia mea privată (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Nu împărți niciodată nsec-ul cu nimeni!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Cheia ta se află pe serviciul de autentificare Divine, nu pe acest dispozitiv. Confirmă parola și o aducem pentru tine.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Cheia ta este păstrată de serviciul de autentificare Divine. Introdu parola contului și o aducem.';

  @override
  String get keyManagementKeycastCopyKey => 'Copiază cheia';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Dispozitivul tău a blocat copierea, așa că cheia ta nu a ajuns în clipboard.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Parola nu se potrivește. Încearcă din nou.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Prea multe încercări. Închide și ia-o de la capăt.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Prea multe cereri pentru cheie. Așteaptă câteva minute și încearcă din nou.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Sesiunea ta a expirat. Autentifică-te din nou pentru a copia cheia.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Confirmă adresa de e-mail înainte de a copia cheia.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine administrează cheile acestui cont, așa că nu pot fi copiate aici.';

  @override
  String get keyManagementKeycastNoKey =>
      'Nu există nicio cheie înregistrată pentru acest cont.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Serviciul de autentificare nu a putut fi contactat. Încearcă din nou.';

  @override
  String get keyManagementRestrictedTitle =>
      'Cheile tale sunt gestionate de Divine';

  @override
  String get keyManagementRestrictedBody =>
      'Ca să îți păstrăm contul în siguranță, salvarea cheii și importul altei chei nu sunt disponibile aici.';

  @override
  String get keyManagementPasteKey => 'Lipește cheia ta privată';

  @override
  String get keyManagementInvalidFormat =>
      'Format de cheie invalid. Trebuie să înceapă cu \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importăm această cheie?';

  @override
  String get keyManagementConfirmImportBody =>
      'Asta âți va înlocui identitatea curentă cu cea importată.\n\nCheia ta curentă va fi pierdută dacă n-ai făcut backup mai întâi.';

  @override
  String get keyManagementImportConfirm => 'Importă';

  @override
  String get keyManagementImportSuccess => 'Cheie importată cu succes!';

  @override
  String get keyManagementImportFailed =>
      'N-am putut importa cheia. Încearcă din nou.';

  @override
  String get keyManagementExportSuccess =>
      'Cheia privată a fost copiată în clipboard!\n\nȚine-o într-un loc sigur.';

  @override
  String get keyManagementExportFailed =>
      'N-am putut exporta cheia. Încearcă din nou.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Cheia ta publică (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copiază cheia publică';

  @override
  String get keyManagementPublicKeyCopied => 'Cheia publică a fost copiată';

  @override
  String get saveOriginalSavedToCameraRoll => 'Salvat în galerie';

  @override
  String get saveOriginalShare => 'Partajează';

  @override
  String get saveOriginalDone => 'Gata';

  @override
  String get saveOriginalPhotosAccessNeeded => 'E nevoie de acces la Poze';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Pentru a salva videoclipuri, permite accesul la Poze în Setări.';

  @override
  String get saveOriginalOpenSettings => 'Deschide setările';

  @override
  String get saveOriginalNotNow => 'Nu acum';

  @override
  String get saveOriginalDownloadFailed => 'Descărcare eșuată';

  @override
  String get saveOriginalDismiss => 'Respinge';

  @override
  String get saveOriginalDownloadingVideo => 'Se descarcă videoclipul';

  @override
  String get saveOriginalSavingToCameraRoll => 'Se salvează în galerie';

  @override
  String get saveOriginalFetchingVideo => 'Se aduce videoclipul din rețea...';

  @override
  String get saveOriginalSavingVideo =>
      'Se salvează videoclipul original în galeria ta...';

  @override
  String get soundTitle => 'Sunet';

  @override
  String get soundOriginalSound => 'Sunet original';

  @override
  String get soundVideosUsingThisSound =>
      'Videoclipuri care folosesc acest sunet';

  @override
  String get soundSourceVideo => 'Videoclip sursă';

  @override
  String get soundNoVideosYet => 'Încă niciun videoclip';

  @override
  String get soundBeFirstToUse => 'Fii primul care folosește acest sunet!';

  @override
  String get soundFailedToLoadVideos => 'N-am putut încărca videoclipurile';

  @override
  String get soundRetry => 'Reîncearcă';

  @override
  String get soundVideosUnavailable => 'Videoclipuri indisponibile';

  @override
  String get soundCouldNotLoadDetails =>
      'N-am putut încărca detaliile videoclipului';

  @override
  String get soundPreview => 'Previzualizare';

  @override
  String get soundStop => 'Oprește';

  @override
  String get soundUseSound => 'Folosește sunetul';

  @override
  String get soundUntitled => 'Sunet fără titlu';

  @override
  String get soundStopPreview => 'Oprește previzualizarea';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Previzualizează $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Vezi detalii pentru $title';
  }

  @override
  String get soundNoVideoCount => 'Încă niciun videoclip';

  @override
  String get soundOneVideo => '1 videoclip';

  @override
  String soundVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
  }

  @override
  String get soundUnableToPreview =>
      'Nu pot previzualiza sunetul - niciun audio disponibil';

  @override
  String get soundPreviewFailed =>
      'N-am putut reda previzualizarea. Încearcă din nou.';

  @override
  String get soundViewSource => 'Vezi sursa';

  @override
  String get soundCloseTooltip => 'Închide';

  @override
  String get exploreNotExploreRoute => 'Nu e o rută de explorare';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Termenii serviciului';

  @override
  String get legalTermsOfServiceSubtitle => 'Termeni și condiții de utilizare';

  @override
  String get legalPrivacyPolicy => 'Politica de confidențialitate';

  @override
  String get legalPrivacyPolicySubtitle => 'Cum gestionăm datele tale';

  @override
  String get legalSafetyStandards => 'Standarde de siguranță';

  @override
  String get legalSafetyStandardsSubtitle => 'Ghiduri comunitare și siguranță';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle =>
      'Politica de drepturi de autor și de eliminare';

  @override
  String get legalOpenSourceLicenses => 'Licențe open source';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Atribuiri pentru pachetele terțe';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'N-am putut deschide $pageName';
  }

  @override
  String get categoryAction => 'Acțiune';

  @override
  String get categoryAdventure => 'Aventură';

  @override
  String get categoryAnimals => 'Animale';

  @override
  String get categoryAnimation => 'Animație';

  @override
  String get categoryArchitecture => 'Arhitectură';

  @override
  String get categoryArt => 'Artă';

  @override
  String get categoryAutomotive => 'Auto';

  @override
  String get categoryAwardShow => 'Gală de premii';

  @override
  String get categoryAwards => 'Premii';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Baschet';

  @override
  String get categoryBeauty => 'Frumusețe';

  @override
  String get categoryBeverage => 'Băuturi';

  @override
  String get categoryCars => 'Mașini';

  @override
  String get categoryCelebration => 'Sărbătoare';

  @override
  String get categoryCelebrities => 'Vedete';

  @override
  String get categoryCelebrity => 'Vedetă';

  @override
  String get categoryCityscape => 'Peisaj urban';

  @override
  String get categoryComedy => 'Comedie';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryCooking => 'Gătit';

  @override
  String get categoryCostume => 'Costum';

  @override
  String get categoryCrafts => 'Meșteșuguri';

  @override
  String get categoryCrime => 'Crimă';

  @override
  String get categoryCulture => 'Cultură';

  @override
  String get categoryDance => 'Dans';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Dramă';

  @override
  String get categoryEducation => 'Educație';

  @override
  String get categoryEmotional => 'Emoțional';

  @override
  String get categoryEmotions => 'Emoții';

  @override
  String get categoryEntertainment => 'Divertisment';

  @override
  String get categoryEvent => 'Eveniment';

  @override
  String get categoryFamily => 'Familie';

  @override
  String get categoryFans => 'Fani';

  @override
  String get categoryFantasy => 'Fantastic';

  @override
  String get categoryFashion => 'Modă';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Mâncare';

  @override
  String get categoryFootball => 'Fotbal american';

  @override
  String get categoryFurniture => 'Mobilier';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Îngrijire';

  @override
  String get categoryGuitar => 'Chitară';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Sănătate';

  @override
  String get categoryHockey => 'Hochei';

  @override
  String get categoryHoliday => 'Vacanță';

  @override
  String get categoryHome => 'Acasă';

  @override
  String get categoryHomeImprovement => 'Renovări';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Spital';

  @override
  String get categoryHumor => 'Umor';

  @override
  String get categoryInteriorDesign => 'Design interior';

  @override
  String get categoryInterview => 'Interviu';

  @override
  String get categoryKids => 'Copii';

  @override
  String get categoryLifestyle => 'Stil de viață';

  @override
  String get categoryMagic => 'Magie';

  @override
  String get categoryMakeup => 'Machiaj';

  @override
  String get categoryMedical => 'Medical';

  @override
  String get categoryMusic => 'Muzică';

  @override
  String get categoryMystery => 'Mister';

  @override
  String get categoryNature => 'Natură';

  @override
  String get categoryNews => 'Știri';

  @override
  String get categoryOutdoor => 'În aer liber';

  @override
  String get categoryParty => 'Petrecere';

  @override
  String get categoryPeople => 'Oameni';

  @override
  String get categoryPerformance => 'Spectacol';

  @override
  String get categoryPets => 'Animale de companie';

  @override
  String get categoryPolitics => 'Politică';

  @override
  String get categoryPrank => 'Farsă';

  @override
  String get categoryPranks => 'Farse';

  @override
  String get categoryRealityShow => 'Reality show';

  @override
  String get categoryRelationship => 'Relație';

  @override
  String get categoryRelationships => 'Relații';

  @override
  String get categoryRomance => 'Romantic';

  @override
  String get categorySchool => 'Școală';

  @override
  String get categoryScienceFiction => 'Science-fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Cumpărături';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Îngrijirea pielii';

  @override
  String get categorySoccer => 'Fotbal';

  @override
  String get categorySocialGathering => 'Reuniune';

  @override
  String get categorySocialMedia => 'Social media';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Tehnologie';

  @override
  String get categoryTelevision => 'Televiziune';

  @override
  String get categoryToys => 'Jucării';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Călătorii';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Violență';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadStaged =>
      'Încărcată — apasă pe Salvează pentru a aplica';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName a fost raportat(ă)';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName a fost blocat(ă)';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName a fost deblocat(ă)';
  }

  @override
  String get inboxRemovedConversation => 'Conversație eliminată';

  @override
  String get inboxRestorePausedTitle =>
      'Unele conversații nu s-au restaurat complet';

  @override
  String get conversationRestorePausedTitle =>
      'Această conversație nu s-a restaurat complet';

  @override
  String get inboxRestoreRetryAction => 'Reîncearcă';

  @override
  String get inboxRestoringMessages => 'Se restaurează mesajele tale…';

  @override
  String get inboxEmptyTitle => 'Încă niciun mesaj';

  @override
  String get inboxEmptySubtitle => 'Butonul + nu mușcă.';

  @override
  String get inboxLoadErrorTitle => 'Mesajele nu s-au încărcat';

  @override
  String get inboxLoadErrorSubtitle =>
      'Verifică conexiunea și încearcă din nou.';

  @override
  String get inboxFilterAll => 'Toate';

  @override
  String get inboxFilterUnread => 'Necitite';

  @override
  String get dmBlockedThreadTitle => 'Ai blocat acest cont';

  @override
  String get dmBlockedThreadBody =>
      'Mesajele rămân aici ca să le poți citi sau captura. Deblochează pentru a răspunde.';

  @override
  String get inboxFilterBlocked => 'Blocate';

  @override
  String get inboxBlockedEmptyTitle => 'Nicio conversație blocată';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Conturile pe care le blochezi apar aici.';

  @override
  String get inboxBlockedNoMessages => 'Niciun mesaj';

  @override
  String get inboxUnreadEmptyTitle => 'Ești la zi';

  @override
  String get inboxUnreadEmptySubtitle => 'Niciun mesaj necitit momentan.';

  @override
  String get inboxSearchHint => 'Caută mesaje';

  @override
  String get inboxSupportRowTitle => 'Moderare Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Buguri, moderare, chestiuni de cont — te ascultăm.';

  @override
  String get inboxSearchEmptyTitle => 'Nicio potrivire';

  @override
  String get inboxSearchEmptySubtitle => 'Încearcă alt nume sau alt cuvânt.';

  @override
  String get inboxActionMute => 'Dezactivează sunetul conversației';

  @override
  String inboxActionReport(String displayName) {
    return 'Raportează $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Blochează $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Deblochează $displayName';
  }

  @override
  String get inboxActionRemove => 'Elimină conversația';

  @override
  String get inboxRemoveConfirmTitle => 'Elimini conversația?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Astfel, conversația ta cu $displayName este eliminată din inbox. Dacă îți scrie din nou, începe o conversație nouă.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Astfel, conversația de grup este eliminată din inbox. Dacă cineva scrie din nou în grup, începe o conversație nouă.';

  @override
  String get inboxRemoveConfirmConfirm => 'Elimină';

  @override
  String get inboxConversationMuted => 'Conversație dezactivată';

  @override
  String get inboxConversationUnmuted => 'Conversație reactivată';

  @override
  String get inboxCollabInviteCardTitle => 'Invitație de colaborare';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Videoclip fără titlu';

  @override
  String get clickableTextViewVideoLink => 'Vezi videoclipul';

  @override
  String get messageExternalLinkDialogTitle => 'Deschizi linkul extern?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Acest link duce la un site extern și s-ar putea să nu fie sigur:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Deschide';

  @override
  String get inboxCollabInviteCoPostButton => 'Co-publică';

  @override
  String get inboxCollabInviteNotMineButton => 'Nu e al meu';

  @override
  String get inboxCollabInvitePreviewTitle => 'Invitație de co-publicare';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Invitație de co-publicare de la $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Co-publicarea adaugă acest videoclip în cronologia ta ca o colaborare.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Acceptată';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorată';

  @override
  String get inboxCollabInviteAcceptError =>
      'Nu s-a putut accepta. Încearcă din nou.';

  @override
  String get inboxCollabInviteSentStatus => 'Invitație trimisă';

  @override
  String get inboxConversationCollabInvitePreview => 'Invitație de colaborare';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Ai fost invitat(ă) să colaborezi la $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Ai fost invitat(ă) să colaborezi la un videoclip: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de invitații de colaborator nu au fost trimise.',
      few: '$count invitații de colaborator nu au fost trimise.',
      one: '1 invitație de colaborator nu a fost trimisă.',
    );
    return 'Videoclip publicat, dar $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Nu am putut afla cu cine e această conversație. Deschide-o din nou din inbox.';

  @override
  String get dmSendBlockedMessage =>
      'Poți trimite mesaje doar conturilor oficiale Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Nimeni nu citește această conversație. Scrie către Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage =>
      'Ștergerea pentru toată lumea nu a reușit.';

  @override
  String get dmDeleteRefusedDetails =>
      'Este posibil ca unele persoane să vadă în continuare acest mesaj.';

  @override
  String get dmRetiredThreadClosedTitle => 'Această conversație este închisă.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Această notificare de la Divine Moderation nu poate fi eliminată.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Am mutat Divine Moderation pe un cont nou. Acesta nu mai este citit de nimeni.';

  @override
  String get dmRetiredThreadOpenSupport => 'Scrie către Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Mesajul nu a putut fi trimis';

  @override
  String get dmResendFailedMessage => 'Tot nu a putut fi trimis';

  @override
  String get dmSendFailedSubtitle => 'Retrimite-l acum sau nu mai încerca.';

  @override
  String get dmSendFailedRetry => 'Reîncearcă';

  @override
  String get dmSendPartialMessage =>
      'Trimis, dar nu s-a sincronizat cu celelalte dispozitive';

  @override
  String get dmConversationLoadError => 'Mesajele nu au putut fi încărcate';

  @override
  String get dmMessageInputHint => 'Spune ceva…';

  @override
  String get dmMessageBubbleSentHint => 'Mesaj trimis';

  @override
  String get dmMessageBubbleReceivedHint => 'Mesaj primit';

  @override
  String get dmMessageBubbleLongPressHint => 'Acțiuni pentru mesaj';

  @override
  String get dmMessageBubbleFailedTapHint => 'Retrimite sau șterge acest mesaj';

  @override
  String get dmMessageActionCopyText => 'Copiază textul';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copiază URL-ul videoclipului';

  @override
  String get dmMessageActionDeleteForEveryone => 'Șterge pentru toți';

  @override
  String get dmMessageActionReport => 'Raportează';

  @override
  String get dmMessageActionRetrySend => 'Retrimite';

  @override
  String get dmMessageActionCancelSend => 'Nu mai încerca';

  @override
  String get dmReactionAddCustomA11yLabel =>
      'Adaugă o reacție emoji personalizată';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Mesaj pentru $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Răspunde-ți ție…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Răspunde la acest reel';

  @override
  String get dmReelReplyViewChat => 'Vezi conversația';

  @override
  String get dmReelReplySentAnnouncement => 'Răspuns trimis';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Ai reacționat $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Trimiterea a eșuat';

  @override
  String get dmReelReplyUnverified => 'Trimiterea nu a putut fi confirmată';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Reacția ta: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name a reacționat cu $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Se trimite reacția: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reacția a eșuat, atinge de două ori pentru a reîncerca';

  @override
  String get dmReactionChipRetryAnnouncement => 'Se reîncearcă reacția';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Finalizează eliminarea reacției anterioare înainte de a adăuga alta.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reacții';

  @override
  String get dmReactionsViewA11yLabel => 'Vezi cine a reacționat';

  @override
  String get dmReactionRemoveAction => 'Elimină';

  @override
  String get dmReactionRetryAction => 'Reîncearcă';

  @override
  String get dmFormatBold => 'Aldin';

  @override
  String get dmFormatItalic => 'Cursiv';

  @override
  String get dmFormatStrikethrough => 'Tăiat';

  @override
  String get dmFormatCode => 'Cod';

  @override
  String get dmStatusFailed => 'N-am putut trimite';

  @override
  String get inboxConversationActionsSheetLabel => 'Acțiuni pentru conversație';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Conversație cu $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Necitită, conversație cu $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'încă $count de persoane',
      few: 'încă $count persoane',
      one: 'încă $count persoană',
    );
    return '$name și $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Arată acțiunile pentru conversație';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Titlu: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Caută...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count videoclipuri';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Nu s-a putut actualiza abonamentul. Încearcă din nou.';

  @override
  String get discoverListsTitle => 'Descoperă liste';

  @override
  String get discoverListsFailedToLoad => 'N-am putut încărca listele';

  @override
  String get discoverListsLoading => 'Se descoperă liste publice...';

  @override
  String get discoverListsRelayTimeout =>
      'Releul nu a returnat liste la timp. Încearcă din nou.';

  @override
  String get discoverListsServiceUnavailable => 'Serviciul nu este disponibil.';

  @override
  String get discoverListsEmptyTitle => 'Nicio listă publică găsită';

  @override
  String get discoverListsEmptySubtitle => 'Revino mai târziu pentru liste noi';

  @override
  String get discoverListsByAuthorPrefix => 'de';

  @override
  String get curatedListEmptyTitle => 'Niciun videoclip în această listă';

  @override
  String get curatedListEmptySubtitle =>
      'Adaugă câteva videoclipuri ca să începi';

  @override
  String get curatedListLoadingVideos => 'Se încarcă videoclipurile...';

  @override
  String get curatedListFailedToLoad => 'N-am putut încărca lista';

  @override
  String get curatedListVideoNotAvailable => 'Videoclip indisponibil';

  @override
  String get curatedListActionsTooltip => 'Acțiuni pentru listă';

  @override
  String get curatedListDeleteConfirmTitle => 'Ștergi lista?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Asta elimină lista de pe relay-uri. Videoclipurile din listă nu vor fi șterse.';

  @override
  String get curatedListDeletedSnack => 'Listă ștearsă';

  @override
  String get curatedListDeleteFailed => 'Nu am putut șterge lista';

  @override
  String get peopleListsActionsTooltip => 'Acțiuni pentru listă';

  @override
  String get listDeleteAction => 'Șterge lista';

  @override
  String get peopleListsDeleteConfirmTitle => 'Ștergi lista?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Asta elimină lista pentru toți. Persoanele din ea nu vor fi eliminate din urmăriri.';

  @override
  String get peopleListsDeleteFailed => 'Nu am putut șterge lista';

  @override
  String get commonRetry => 'Reîncearcă';

  @override
  String get commonSomethingWentWrong => 'Ceva nu a mers bine';

  @override
  String get commonDelete => 'Șterge';

  @override
  String get commonCancel => 'Anulează';

  @override
  String get commonBack => 'Înapoi';

  @override
  String get commonClose => 'Închide';

  @override
  String get commonNotNow => 'Nu acum';

  @override
  String get commonLoading => 'Se încarcă';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Coperta nu a putut fi actualizată. Încearcă din nou.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement =>
      'Coperta a fost actualizată';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Publici fără verificarea autenticității?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Nu am putut adăuga acreditările de conținut, așa că acest videoclip nu va fi confirmat ca fiind făcut de om. Regenerează pentru a încerca din nou sau publică-l așa cum este.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Acreditările de conținut necesită o conexiune la internet.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Serviciul de acreditări de conținut nu a răspuns. Nu e vina conexiunii tale.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Regenerează';

  @override
  String get videoMetadataC2paMissingSkip => 'Omite';

  @override
  String get videoMetadataGenerationFailed => 'Generarea a eșuat';

  @override
  String get videoMetadataTags => 'Etichete';

  @override
  String get videoMetadataExpiration => 'Expirare';

  @override
  String get videoMetadataExpirationNotExpire => 'Nu expiră';

  @override
  String get videoMetadataExpirationOneDay => '1 zi';

  @override
  String get videoMetadataExpirationOneWeek => '1 săptămână';

  @override
  String get videoMetadataExpirationOneMonth => '1 lună';

  @override
  String get videoMetadataExpirationOneYear => '1 an';

  @override
  String get videoMetadataExpirationOneDecade => '1 deceniu';

  @override
  String get videoMetadataContentWarnings => 'Avertismente de conținut';

  @override
  String get videoEditorStickers => 'Stickere';

  @override
  String get trendingTitle => 'În tendințe';

  @override
  String get libraryDeleteConfirm => 'Șterge';

  @override
  String get libraryWebUnavailableHeadline =>
      'Biblioteca e în aplicația mobilă';

  @override
  String get libraryWebUnavailableDescription =>
      'Ciornele și clipurile sunt pe dispozitivul tău — deschide Divine pe telefon ca să le gestionezi.';

  @override
  String get libraryTabDrafts => 'Ciorne';

  @override
  String get libraryTabClips => 'Clipuri';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Șterge clipurile selectate';

  @override
  String get libraryCloseSemanticLabel => 'Închide biblioteca';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'Oprește selectarea clipurilor';

  @override
  String get librarySelectClipsSemanticLabel => 'Selectează clipuri';

  @override
  String get libraryGridSizeLabel => 'Dimensiunea grilei';

  @override
  String get libraryDisplayOptionsLabel => 'Sortare și dimensiunea grilei';

  @override
  String get libraryMoreActionsSemanticLabel =>
      'Mai multe acțiuni în bibliotecă';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de coloane',
      few: '$count coloane',
      one: '1 coloană',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Selectează';

  @override
  String get librarySortNewestCreation => 'Cele mai noi create';

  @override
  String get librarySortOldestCreation => 'Cele mai vechi create';

  @override
  String get librarySortLongestClip => 'Cel mai lung clip';

  @override
  String get librarySortShortestClip => 'Cel mai scurt clip';

  @override
  String get librarySortSquareFirst => 'Pătratele mai întâi';

  @override
  String get librarySortVerticalFirst => 'Verticalele mai întâi';

  @override
  String get libraryDeleteClipsWarning =>
      'Nu se poate anula. Fișierele video vor fi eliminate definitiv de pe dispozitiv.';

  @override
  String get libraryPreparingVideo => 'Se pregătește videoclipul...';

  @override
  String libraryCreateVideo(int count) {
    return 'Creează video ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipuri',
      one: '1 clip',
    );
    return '$_temp0 salvate în $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount salvate, $failureCount eșuate';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Nu s-a putut salva în $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permisiune refuzată pentru $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipuri șterse',
      one: '1 clip șters',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Anulează';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Se șterge automat în $daysLeft zile',
      one: 'Se șterge automat mâine',
      zero: 'Se șterge automat azi',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Nu s-au putut încărca ciornele';

  @override
  String get libraryCouldNotLoadClips => 'Nu s-au putut încărca clipurile';

  @override
  String get libraryOpenErrorDescription =>
      'Ceva nu a mers la deschiderea bibliotecii. Poți încerca din nou.';

  @override
  String get libraryNoDraftsYetTitle => 'Încă nu ai ciorne';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Videoclipurile salvate ca ciornă apar aici';

  @override
  String get libraryNoClipsYetTitle => 'Încă nu ai clipuri';

  @override
  String get libraryNoClipsYetSubtitle => 'Clipurile înregistrate apar aici';

  @override
  String get libraryDraftDeletedSnackbar => 'Ciornă ștearsă';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Nu s-a putut șterge ciorna';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Ciornă duplicată';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Nu s-a putut duplica ciorna';

  @override
  String get libraryDraftInProgressBadge => 'În lucru';

  @override
  String get libraryDraftActionPost => 'Publică';

  @override
  String get libraryDraftActionEdit => 'Editează';

  @override
  String get libraryDraftActionDuplicate => 'Duplică';

  @override
  String get libraryDraftActionDelete => 'Șterge ciorna';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (copie $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Șterge ciorna';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Ștergi „$title”?';
  }

  @override
  String get libraryDeleteClipTitle => 'Șterge clipul';

  @override
  String get libraryDeleteClipMessage => 'Ștergi acest clip?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds s';
  }

  @override
  String get libraryRecordVideo => 'Înregistrează un video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Clip video, $duration secunde';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Arhivat. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Clip stop-motion, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Selectat, numărul $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Selectat';

  @override
  String get videoClipSemanticValueNotSelected => 'Neselectat';

  @override
  String get videoClipSemanticHintDisabled => 'Dezactivat';

  @override
  String get videoClipSemanticHintSelect =>
      'Atinge pentru a selecta, ține apăsat pentru previzualizare';

  @override
  String get videoClipSemanticHintDeselect =>
      'Atinge pentru a deselecta, ține apăsat pentru previzualizare';

  @override
  String get routerInvalidCreator => 'Creator invalid';

  @override
  String get routerInvalidHashtagRoute => 'Rută hashtag invalidă';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Nu s-au putut încărca videoclipurile';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Niciun videoclip în această categorie';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Opțiuni de sortare a categoriei';

  @override
  String get categoryGallerySortHot => 'În tendințe';

  @override
  String get categoryGallerySortNew => 'Noi';

  @override
  String get categoryGallerySortClassic => 'Clasic';

  @override
  String get categoryGallerySortForYou => 'Pentru tine';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Nu s-au putut încărca categoriile';

  @override
  String get categoriesNoCategoriesAvailable => 'Nicio categorie disponibilă';

  @override
  String get notificationsEmptyTitle => 'Încă nicio activitate';

  @override
  String get notificationsEmptySubtitle =>
      'Când oamenii interacționează cu conținutul tău, vei vedea asta aici';

  @override
  String get appsPermissionsTitle => 'Permisiuni de integrare';

  @override
  String get appsPermissionsRevoke => 'Revocă';

  @override
  String get appsPermissionsEmptyTitle =>
      'Nicio permisiune de integrare salvată';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Integrările aprobate vor apărea aici după ce memorezi o aprobare de acces.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName cere aprobarea ta';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Această aplicație cere acces prin sandbox-ul verificat de Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Origine';

  @override
  String get nostrAppPermissionMethod => 'Metodă';

  @override
  String get nostrAppPermissionCapability => 'Capabilitate';

  @override
  String get nostrAppPermissionEventKind => 'Tip de eveniment';

  @override
  String get nostrAppPermissionAllow => 'Permite';

  @override
  String get appsDetailDefaultTitle => 'Aplicație integrată';

  @override
  String get appsDetailNotFoundTitle => 'Integrare negăsită';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Această integrare aprobată nu mai este disponibilă în Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Cum funcționează';

  @override
  String get appsDetailHowItWorksBody =>
      'Aceasta este o aplicație terță aprobată care rulează în Divine. Divine acordă doar capabilități verificate pentru această integrare și blochează navigarea în afara originilor aprobate.';

  @override
  String get appsDetailAboutTitle => 'Despre';

  @override
  String get appsDetailPrimaryOriginTitle => 'Origine principală';

  @override
  String get appsDetailApprovedOriginsTitle => 'Origini aprobate';

  @override
  String get appsDetailCapabilitiesTitle => 'Capabilități disponibile';

  @override
  String get appsDetailAskBeforeTitle => 'Întreabă înainte de';

  @override
  String get appsDetailOpenButton => 'Deschide integrarea';

  @override
  String get appsDetailNoneDeclared => 'Nimic declarat încă';

  @override
  String get appsDirectoryTitle => 'Aplicații integrate';

  @override
  String get appsDirectoryIntroTitle => 'Aplicații terțe aprobate';

  @override
  String get appsDirectoryIntroBody =>
      'Aplicații terțe aprobate care rulează în Divine';

  @override
  String get appsDirectoryErrorTitle =>
      'Nu am putut încărca aplicațiile integrate';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Trage ca să încerci din nou integrările aprobate.';

  @override
  String get appsDirectoryEmptyTitle => 'Încă nicio integrare aprobată';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Aplicațiile terțe aprobate vor apărea aici pe măsură ce Divine le adaugă.';

  @override
  String get appsDirectoryRefresh => 'Reîmprospătează';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Aplicațiile integrate rulează în Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Integrările aprobate sunt disponibile deocamdată doar pe mobil.';

  @override
  String get appsSandboxUnavailableTitle => 'Integrare indisponibilă';

  @override
  String get appsSandboxUnavailableBody =>
      'Deschide integrările aprobate din fila Aplicații integrate ca Divine să poată aplica politica de acces corectă.';

  @override
  String get appsSandboxLoadingTitle => 'Se încarcă integrarea';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Se verifică integrarea aprobată înainte de lansare.';

  @override
  String get appsSandboxBlockedTitle => 'Blocat pentru siguranță';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Această integrare a încercat să-și părăsească originea aprobată.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink =>
      'Linkul către postare a fost copiat în clipboard';

  @override
  String get shareCopiedEventJson =>
      'JSON-ul evenimentului Nostr a fost copiat în clipboard';

  @override
  String get shareCopiedEventId =>
      'ID-ul evenimentului Nostr a fost copiat în clipboard';

  @override
  String get authHeroTaglineAuthentic => 'Momente autentice.';

  @override
  String get authHeroTaglineHuman => 'Creativitate umană.';

  @override
  String get keyImportFailedToImport =>
      'Nu am putut importa cheia sau conecta bunkerul';

  @override
  String get keyImportInvalidBunkerUrl => 'URL de bunker invalid';

  @override
  String get keyImportInvalidFormat =>
      'Format invalid. Folosește nsec..., hex, ncryptsec1... sau bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Format nsec invalid. Trebuie să aibă 63 de caractere';

  @override
  String get keyImportKeyFieldLabel => 'Cheie privată sau URL de bunker';

  @override
  String get keyImportKeyRequired =>
      'Te rugăm să introduci cheia privată sau URL-ul de bunker';

  @override
  String get keyImportPasswordRequired =>
      'Te rugăm să introduci parola pentru această cheie criptată';

  @override
  String get keyImportSecurityWarningBody =>
      'Nu-ți împărtăși niciodată cheia privată cu nimeni. Această cheie oferă acces complet la identitatea ta Nostr.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Păstrează-ți cheia privată în siguranță!';

  @override
  String get keyImportSubtitle =>
      'Importă-ți identitatea Nostr existentă folosind cheia privată sau un URL de bunker.';

  @override
  String get keyImportTitle => 'Importă-ți\nidentitatea Nostr';

  @override
  String get commentAuthorYouIndicator => 'Tu';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Vezi profilul lui $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Șterge comentariul';

  @override
  String get commentOptionsEditSemanticLabel => 'Editează comentariul';

  @override
  String get commentOptionsFlagContentLabel => 'Semnalează conținutul';

  @override
  String get commentOptionsFlagContentSemanticLabel =>
      'Semnalează acest conținut';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Alege un motiv pentru semnalarea acestui comentariu';

  @override
  String get commentOptionsFlagSubmit => 'Trimite';

  @override
  String get commentOptionsTitle => 'Opțiuni';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Încă lucrăm la importarea comentariilor vechi din arhivă. Nu sunt gata încă.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Se editează';

  @override
  String get commentsInputSemanticHint => 'Adaugă un comentariu';

  @override
  String get commentsInputSemanticHintEdit => 'Editează comentariul';

  @override
  String get commentsInputSemanticHintReply => 'Adaugă un răspuns';

  @override
  String get commentsInputSemanticLabel => 'Câmp de comentariu';

  @override
  String get commentsInputSemanticLabelEdit => 'Câmp de editare';

  @override
  String get commentsInputSemanticLabelReply => 'Câmp de răspuns';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Vezi profilul lui $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Arhiva Clasice se încarcă';

  @override
  String get classicsEmptyTitle => 'Nu s-au găsit Clasice';

  @override
  String get classicsErrorTitle => 'Nu am putut încărca Clasicele';

  @override
  String get classicsUnavailableDescription =>
      'Clasicele sunt disponibile doar când ești conectat la relay-uri Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Comută la un relay cu Funnelcake activat în Setări ca să accesezi arhiva Clasice.';

  @override
  String get classicsUnavailableTitle => 'Clasice indisponibile';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Fii primul care postează un videoclip cu acest hashtag!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Niciun videoclip găsit pentru #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Poate dura câteva momente';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Se încarcă videoclipuri despre #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Adaugă hashtaguri... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Revino mai târziu pentru conținut nou';

  @override
  String get newVideosTabEmptyTitle => 'Niciun videoclip în Videoclipuri noi';

  @override
  String get popularVideosContextTitle => 'Videoclipuri populare';

  @override
  String get popularVideosEmptySubtitle =>
      'Revino mai târziu pentru conținut nou';

  @override
  String get popularVideosEmptyTitle =>
      'Niciun videoclip în Videoclipuri populare';

  @override
  String get popularVideosErrorTitle =>
      'Nu am putut încărca videoclipurile în trend';

  @override
  String get popularVideosFeedSourceLabel => 'Sursa feedului Populare';

  @override
  String get trendingHashtagsLoading => 'Se încarcă hashtagurile...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Vezi videoclipuri etichetate cu $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Autorul videoclipului: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Descrierea videoclipului: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Viziunea Divine este să-ți ofere o adevărată alegere algoritmică. În loc să fii blocat într-un singur algoritm de tip cutie neagră, vei putea alege dintre mai multe abordări de recomandare:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Cronologie în ordinea timpului de la creatorii pe care îi urmărești';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Asta îți dă ție controlul asupra atenției tale, în loc să-l lase pe seama platformei. Ar trebui să știi cum îți este curat feedul și să ai puterea de a-l schimba oricând vrei.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Feeduri personalizate create de comunitate pentru subiecte ca muzică, comedie sau artă';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Feed „Pentru tine” personalizat';

  @override
  String get forYouAlgorithmChoiceTitle => 'Algoritmul tău, alegerea ta';

  @override
  String get forYouAlgorithmChoiceTrending => 'Conținut în trend și popular';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Semnal puternic — ai fost destul de implicat cât să răspunzi';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine e atent la modul în care interacționezi cu conținutul ca să înțeleagă ce îți place. De fiecare dată când vizionezi un videoclip, îi dai o reacție, lași un comentariu sau îl redistribui, sistemul ia notă.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Cum funcționează';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Acțiuni diferite semnalează niveluri diferite de interes:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Dacă nu ți-ai construit încă un istoric de vizionare, îți arătăm un amestec de ce este popular și în trend acum, alături de încărcări recente. Asta îți oferă un punct de plecare grozav pentru explorare.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Pe măsură ce vizionezi, apreciezi și interacționezi cu conținut, recomandările devin treptat mai personalizate. În timp, feedul tău Pentru tine scoate la iveală videoclipuri de la creatori pe care poate nu i-ai fi descoperit niciodată de unul singur.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Nou pe Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Construim un sistem deschis în care dezvoltatorii își pot implementa propriii algoritmi, iar tu poți alege pe care să-i folosești — sau poți renunța complet.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open source și transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Semnal mediu — o modalitate rapidă de a arăta apreciere';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reacții';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Cel mai puternic semnal — partajarea cu urmăritorii tăi este o susținere puternică';

  @override
  String get forYouAlgorithmSubtitle =>
      'Susținut de Gorse, un motor de recomandare open source';

  @override
  String get forYouAlgorithmTitle => 'Algoritmul Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Semnal ușor — indică un interes de bază';

  @override
  String get forYouEmptyDescription =>
      'Vizionează și apreciază câteva videoclipuri ca să primești recomandări personalizate.';

  @override
  String get forYouEmptyTitle => 'Încă nicio recomandare';

  @override
  String get forYouErrorTitle => 'Nu am putut încărca recomandările';

  @override
  String get forYouUnavailableDescription =>
      'Recomandările personalizate necesită conexiune la Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Pentru tine indisponibil';

  @override
  String get inboxConversationOptionsLabel => 'Opțiuni';

  @override
  String get inboxConversationViewProfileButton => 'Vezi profilul';

  @override
  String get inboxMessageRequestsEmpty => 'Nicio cerere de mesaj';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Cereri de mesaj, $requestCount în așteptare';
  }

  @override
  String get inboxMessageRequestsTitle => 'Cereri de mesaj';

  @override
  String get inboxMessagesTab => 'Mesaje';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Cerere de mesaj de la $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'A trimis o cerere de mesaj';

  @override
  String get inboxRequestsMarkAllRead => 'Marchează toate cererile ca citite';

  @override
  String get inboxRequestsRemoveAll => 'Elimină toate cererile';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Refuză și elimină';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Cererea lui $displayName a fost refuzată';
  }

  @override
  String get messageRequestLoadFailed => 'Nu am putut încărca această cerere.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count urmăritori';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count videoclipuri';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de mesaje',
      few: '$count mesaje',
      one: '1 mesaj',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Vezi mesajele';

  @override
  String get messageRequestViewProfileButton => 'Vezi profilul';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName vrea să-ți trimită un mesaj, a trimis $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Ai schimbat contul, așa că nimic nu a fost șters. Redeschide ștergerea pentru contul pe care vrei să-l elimini.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Pentru a confirma, scrie:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Pentru a confirma, scrie numele tău de utilizator:';

  @override
  String get deleteAccountConfirmationHint => 'Scrie DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'Scrie numele tău de utilizator';

  @override
  String get deleteAccountDeleteAllContentButton => 'Șterge tot conținutul';

  @override
  String get accountDeletionRecoveryTitle =>
      'Contul tău este în curs de ștergere';

  @override
  String get accountDeletionRecoveryBody =>
      'Nu am putut finaliza ștergerea contului tău. Numele tău de utilizator îți este rezervat și încă poate fi recuperat.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername =>
      'Recuperează-mi numele de utilizator';

  @override
  String get accountDeletionFinishingBody =>
      'Cererea ta de ștergere este încă în curs de procesare. Poți folosi alt cont până terminăm.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Ștergerea altui cont este încă în curs de procesare pe acest dispozitiv. Așteaptă să se termine înainte de a șterge acest cont.';

  @override
  String get accountDeletionCancellingBody =>
      'Anulăm ștergerea ta. Verifică din nou înainte să părăsești acest ecran.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Nu am putut încă recupera numele tău de utilizator. Verifică conexiunea și încearcă din nou.';

  @override
  String get accountDeletionUsernameRestored =>
      'Numele tău de utilizator a fost recuperat. Contul tău nu a fost șters.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Nu am putut verifica starea ștergerii. Verifică conexiunea și încearcă din nou.';

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
      'Ștergerea contului nu este disponibilă momentan. Nu s-a șters nimic.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Nu am putut finaliza ștergerea contului tău. Încearcă din nou.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Confirmare finală';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Cereri de ștergere trimise, dar cheile tale s-ar putea să nu fi fost eliminate complet de pe acest dispozitiv. Mergi la Setări → Chei Nostr → Elimină cheile ca să reîncerci.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Cereri de ștergere trimise și ai fost deconectat, dar unele date locale nu au putut fi eliminate de pe acest dispozitiv.';

  @override
  String get deleteAccountPreparingDeletion => 'Se pregătește ștergerea...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total evenimente';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Asta elimină autentificarea locală pentru acest cont de pe acest dispozitiv. Nu îți va șterge contul Divine sau identitatea Nostr.\n\nCiornele și clipurile tale rămân salvate pe acest dispozitiv pentru acest cont. Dacă acesta este ultimul tău cont local, vei reveni la ecranul de autentificare.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Elimină de pe dispozitiv';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Elimini acest cont de pe acest dispozitiv?';

  @override
  String get deleteAccountReauthRequired =>
      'Conectează-te din nou ca să-ți ștergi contul. Nu a fost șters încă nimic.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Cererile de ștergere pentru postările tale au fost trimise, dar nu am putut finaliza ștergerea contului tău. Încearcă din nou în scurt timp.';

  @override
  String get deleteAccountSuccess =>
      'Contul tău Divine a fost șters. Au fost trimise cereri de ștergere pentru postările tale Nostr, dar unele relee, aplicații client sau memorii cache pot păstra copii.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Ștergerea contului a fost solicitată. Ștergerea unor postări existente nu a putut fi confirmată individual.';

  @override
  String get deleteAccountWarningBody =>
      'Aceasta trimite cereri de ștergere pentru contul și conținutul tău, șterge contul tău Divine când e posibil și te deconectează pe acest dispozitiv. Unele relay-uri, clienți și indexuri de căutare pot păstra copii. Alte dispozitive conectate rămân active până când elimini cheile de pe ele.';

  @override
  String get findPeopleNoContacts =>
      'Niciun contact găsit.\nÎncepe să urmărești oameni ca să-i vezi aici.';

  @override
  String get geoBlockedCityLabel => 'Oraș';

  @override
  String get geoBlockedCountryLabel => 'Țară';

  @override
  String get geoBlockedDefaultReason =>
      'Acest serviciu nu este disponibil în regiunea ta din cauza reglementărilor locale.';

  @override
  String get geoBlockedLegalNotice =>
      'Îți respectăm legile și reglementările locale. Această restricție se bazează pe locația adresei tale IP.';

  @override
  String get geoBlockedRegionLabel => 'Regiune';

  @override
  String get geoBlockedTitle => 'Serviciu indisponibil';

  @override
  String get likedVideosEmpty => 'Niciun videoclip apreciat';

  @override
  String get likedVideosInvalidRoute => 'Rută invalidă';

  @override
  String get likedVideosTitle => 'Videoclipuri apreciate';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Se reîncearcă încărcarea…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Salvează în ciorne';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Salvat în ciorne';

  @override
  String get uploadFailureSheetTitle => 'Încărcarea a eșuat';

  @override
  String get uploadFailureSheetTryAgainButton => 'Încearcă din nou';

  @override
  String get videoEditorAudioImportAudio => 'Importă audio';

  @override
  String get videoEditorAudioImportFailed => 'Importul audio a eșuat.';

  @override
  String get videoIconPlaceholderLabel => 'Videoclip';

  @override
  String get publishErrorNotSignedIn =>
      'Autentifică-te ca să publici videoclipuri.';

  @override
  String get publishErrorNoRetry => 'Nu există nicio încărcare de reîncercat.';

  @override
  String get publishErrorNoInternet =>
      'Nu există conexiune la internet. Verifică Wi-Fi-ul sau datele mobile și încearcă din nou.';

  @override
  String get publishErrorServerUnreachable =>
      'Nu am putut accesa serverul. Încearcă din nou într-o clipă.';

  @override
  String get publishErrorTimeout =>
      'Încărcarea a expirat. Încearcă o conexiune mai bună sau un videoclip mai mic.';

  @override
  String get publishErrorTls =>
      'Conexiunea securizată a eșuat. Verifică-ți rețeaua — Wi-Fi-ul public poate bloca încărcările.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Serverul media ($serverName) nu este disponibil. Poți alege altul în setări.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Fișierul video este prea mare pentru server. Încearcă să-l scurtezi sau să reduci calitatea.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Serverul media ($serverName) a avut o eroare internă. Poți alege altul în setări.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Serverul media ($serverName) este temporar indisponibil. Încearcă din nou în scurt timp sau alege altul în setări.';
  }

  @override
  String get publishErrorForbidden =>
      'Nu ai permisiunea de a încărca pe acest server.';

  @override
  String get publishErrorFileNotFound =>
      'Fișierul video nu a putut fi găsit. Poate a fost șters. Înregistrează din nou și încearcă iar.';

  @override
  String get publishErrorLowStorage =>
      'Nu ai destul spațiu de stocare pe dispozitiv. Eliberează niște spațiu și încearcă din nou.';

  @override
  String get publishErrorThumbnailFailed =>
      'Videoclipul s-a încărcat, dar miniatura nu a putut fi pregătită. Încearcă din nou.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Videoclipul s-a încărcat, dar postarea nu a putut fi publicată. Verifică-ți setările relay-urilor și încearcă din nou.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Videoclipul s-a încărcat, dar sunetul lui nu este permis pentru reutilizare. Alege alt sunet ca să postezi.';

  @override
  String get publishErrorInterrupted =>
      'Această încărcare a fost întreruptă. Vrei să încerci din nou?';

  @override
  String get publishErrorAccountChanged =>
      'Acest videoclip aparține altui cont. Comută înapoi la acel cont ca să îl postezi.';

  @override
  String get publishErrorGeneric => 'Ceva nu a mers bine. Încearcă din nou.';

  @override
  String get publishErrorRateLimited =>
      'Prea multe încărcări chiar acum. Așteaptă o clipă și încearcă din nou.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Sesiunea de încărcare a expirat. Încearcă din nou.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine nu are permisiunea de a încărca. Verifică permisiunile aplicației în setări și încearcă din nou.';

  @override
  String get publishErrorOutOfMemory =>
      'Dispozitivul are puțină memorie disponibilă. Închide câteva aplicații și încearcă din nou.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Textul și stickerele din această schiță nu au putut fi pregătite. Deschide-o în editor, apoi postează din nou.';

  @override
  String get publishErrorUnknownServer => 'Server necunoscut';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filtru: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Niciun rezultat găsit pentru „$query”';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Vezi videoclipuri etichetate cu $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Sunet: $soundName de $creatorName. Atinge ca să vezi detaliile sunetului.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Sunet original de $creatorName. Atinge ca să folosești acest sunet.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Sunet: $soundName de $creatorName. Atinge ca să vezi detaliile.';
  }

  @override
  String get soundDetailLoadError =>
      'Nu am putut încărca sunetul. Încearcă din nou.';

  @override
  String get soundDetailNotFoundMessage => 'Acest sunet nu a putut fi găsit';

  @override
  String get soundDetailNotFoundTitle => 'Sunet negăsit';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count bucle';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Sunetul din acest videoclip nu este disponibil separat.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Sunet original - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Persoana asta a postat un Vine original pe care Divine l-a găsit în arhivă. Nu e o insignă de verificare a contului.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Bifa de profil';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine dă bifa asta conturilor echipei. E separat de NIP-05, de linkurile de cont verificate și de statutul OG Viner.';

  @override
  String get unfollowConfirmButton => 'Nu mai urmări';

  @override
  String get videoClipSaveFailed => 'Nu am putut salva clipul';

  @override
  String videoClipSaveTo(String destination) {
    return 'Salvează în $destination';
  }

  @override
  String get videoClipDelete => 'Șterge clipul';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirat de $creatorName +$additionalCreatorCount. Atinge ca să-i vezi profilul.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspirat de $creatorName. Atinge ca să-i vezi profilul.';
  }

  @override
  String get bugReportSendReport => 'Trimite raportul';

  @override
  String get supportSubjectRequiredLabel => 'Subiect *';

  @override
  String get supportPublicSubmissionTitle => 'Postare publică pe GitHub';

  @override
  String get supportPublicSubmissionMessage =>
      'Tot ce trimiți aici va fi publicat în depozitul nostru open-source de pe GitHub, pentru ca dezvoltatorii să se poată ocupa. Postarea și contul cu care ești conectat vor fi vizibile public pentru toată lumea.';

  @override
  String get supportRequiredHelper => 'Obligatoriu';

  @override
  String get supportFieldLimitReached =>
      'Aceasta e lungimea maximă. Ce depășește nu a fost adăugat.';

  @override
  String get bugReportSubjectHint => 'Scurt rezumat al problemei';

  @override
  String get bugReportDescriptionRequiredLabel => 'Ce s-a întâmplat? *';

  @override
  String get bugReportDescriptionHint =>
      'Descrie problema pe care ai întâlnit-o';

  @override
  String get bugReportStepsLabel => 'Pași pentru reproducere';

  @override
  String get bugReportStepsHint =>
      '1. Mergi la...\n2. Apasă pe...\n3. Vezi eroarea';

  @override
  String get bugReportExpectedBehaviorLabel => 'Comportament așteptat';

  @override
  String get bugReportExpectedBehaviorHint =>
      'Ce ar fi trebuit să se întâmple în schimb?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Informațiile despre dispozitiv și jurnalele vor fi incluse automat.';

  @override
  String get bugReportSuccessMessage =>
      'Mulțumim! Am primit raportul tău și îl vom folosi ca să facem Divine mai bun.';

  @override
  String get bugReportAttachImages => 'Atașează imagini';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count din $max imagini selectate';
  }

  @override
  String get bugReportRemoveImage => 'Elimină imaginea';

  @override
  String get bugReportUploadFailed =>
      'Nu am putut încărca imaginea selectată. Încearcă din nou sau trimite raportul fără ea.';

  @override
  String get bugReportSendFailed =>
      'Trimiterea raportului de bug a eșuat. Încearcă din nou mai târziu.';

  @override
  String get featureRequestSendRequest => 'Trimite cererea';

  @override
  String get featureRequestSubjectHint => 'Scurt rezumat al ideii tale';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Ce ți-ar plăcea? *';

  @override
  String get featureRequestDescriptionHint => 'Descrie funcția pe care o vrei';

  @override
  String get featureRequestUsefulnessLabel => 'Cum ar fi utilă?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explică beneficiul pe care l-ar aduce această funcție';

  @override
  String get featureRequestWhenLabel => 'Când ai folosi-o?';

  @override
  String get featureRequestWhenHint => 'Descrie situațiile în care te-ar ajuta';

  @override
  String get featureRequestSuccessMessage =>
      'Mulțumim! Am primit cererea ta de funcție și o vom analiza.';

  @override
  String get featureRequestSendFailed =>
      'Trimiterea cererii de funcție a eșuat. Încearcă din nou mai târziu.';

  @override
  String get notificationFollowBack => 'Urmărește înapoi';

  @override
  String get followingTitle => 'Urmăriți';

  @override
  String followingTitleForName(String displayName) {
    return 'Urmăriții lui $displayName';
  }

  @override
  String get followingFailedToLoadList =>
      'Nu s-a putut încărca lista de urmăriți';

  @override
  String get followingEmptyTitle => 'Încă nu urmărești pe nimeni';

  @override
  String get followersTitle => 'Urmăritori';

  @override
  String followersTitleForName(String displayName) {
    return 'Urmăritorii lui $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Nu s-a putut încărca lista de urmăritori';

  @override
  String get followersEmptyTitle => 'Încă niciun urmăritor';

  @override
  String get followersUpdateFollowFailed =>
      'Actualizarea stării de urmărire a eșuat. Încearcă din nou.';

  @override
  String get followersSortSemanticLabel => 'Sortează urmăritorii';

  @override
  String get followingSortSemanticLabel => 'Sortează urmăriții';

  @override
  String get followSortTitle => 'Sortează după';

  @override
  String get followSortNewest => 'Cei mai noi primii';

  @override
  String get followSortOldest => 'Cei mai vechi primii';

  @override
  String get newMessageTitle => 'Mesaj nou';

  @override
  String get newMessageFindPeople => 'Găsește oameni';

  @override
  String get newMessageNoContacts =>
      'Niciun contact găsit.\nUrmărește oameni ca să-i vezi aici.';

  @override
  String get newMessageNoUsersFound => 'Niciun utilizator găsit';

  @override
  String get hashtagSearchTitle => 'Caută hashtaguri';

  @override
  String get hashtagSearchSubtitle =>
      'Descoperă subiecte și conținut în tendințe';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Niciun hashtag găsit pentru „$query”';
  }

  @override
  String get hashtagSearchFailed => 'Căutarea a eșuat';

  @override
  String get userNotAvailableTitle => 'Cont indisponibil';

  @override
  String get userNotAvailableBody => 'Acest cont nu e disponibil acum.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Nu s-au putut salva setările. Încearcă din nou.';

  @override
  String get blossomValidServerUrl =>
      'Introdu un URL valid de server (ex.: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Setările Blossom au fost salvate';

  @override
  String get blossomSaveTooltip => 'Salvează';

  @override
  String get blossomAboutTitle => 'Despre Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom e un protocol descentralizat de stocare media care îți permite să încarci videoclipuri pe orice server compatibil. Implicit, videoclipurile se încarcă pe serverul Blossom al Divine. Activează opțiunea de mai jos ca să folosești în schimb un server personalizat.';

  @override
  String get blossomUseCustomServer =>
      'Folosește un server Blossom personalizat';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Videoclipurile vor fi încărcate pe serverul tău Blossom personalizat';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Videoclipurile tale se încarcă în prezent pe serverul Blossom al Divine';

  @override
  String get blossomCustomServerUrl => 'URL server Blossom personalizat';

  @override
  String get blossomCustomServerHelper =>
      'Introdu URL-ul serverului tău Blossom personalizat';

  @override
  String get blossomPopularServers => 'Servere Blossom populare';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL-ul serverului Blossom trebuie să folosească https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Nu s-a putut actualiza setarea de crosspost';

  @override
  String get blueskySignInRequired =>
      'Autentifică-te ca să gestionezi setările Bluesky';

  @override
  String get blueskyPublishVideos => 'Publică videoclipuri pe Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Videoclipurile tale vor fi publicate pe Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Videoclipurile tale nu vor fi publicate pe Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Și videoclipurile tale vechi vor fi postate';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Când activezi asta, Divine va începe să trimită videoclipurile tale mai vechi pe Bluesky, începând cu cele mai vechi, fără să grăbească limita zilnică.';

  @override
  String get blueskyHandle => 'Handle Bluesky';

  @override
  String get blueskyDid => 'DID Bluesky';

  @override
  String get blueskyStatus => 'Stare';

  @override
  String get blueskyStatusReady => 'Cont creat și gata';

  @override
  String get blueskyStatusPending => 'Crearea contului e în curs...';

  @override
  String get blueskyStatusFailed => 'Crearea contului a eșuat';

  @override
  String get blueskyStatusDisabled => 'Cont dezactivat';

  @override
  String get blueskyStatusNotLinked => 'Niciun cont Bluesky conectat';

  @override
  String get blueskyUsernameRequired =>
      'Configurează un identificator divine.video înainte să publici pe Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Publicarea pe Bluesky necesită un identificator revendicat nume.divine.video.';

  @override
  String get blueskyUsernameSyncPending =>
      'Identificatorul tău Divine e revendicat. Îl legăm de Bluesky – încearcă din nou în scurt timp.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Nu am putut verifica identificatorul tău Divine. Încearcă din nou.';

  @override
  String get blueskySetUpHandle => 'Configurează';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Publicarea pe Bluesky e temporar indisponibilă. Încearcă din nou.';

  @override
  String get invitesTitle => 'Invită prieteni';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de invitații gata de generat',
      few: '$count invitații gata de generat',
      one: '1 invitație gata de generat',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Generează un cod când ești gata să îl împarți.';

  @override
  String get invitesGenerateButtonLabel => 'Generează invitație';

  @override
  String get invitesNoneAvailable => 'Nicio invitație disponibilă acum';

  @override
  String get invitesShareWithPeople =>
      'Partajează Divine cu oameni pe care îi cunoști';

  @override
  String get invitesUsedInvites => 'Invitații folosite';

  @override
  String invitesShareMessage(String code) {
    return 'Vino cu mine pe Divine! Folosește codul de invitație $code ca să începi:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copiază invitația';

  @override
  String get invitesCopied => 'Invitație copiată!';

  @override
  String get invitesShareInvite => 'Partajează invitația';

  @override
  String get invitesShareSubject => 'Vino cu mine pe Divine';

  @override
  String get invitesClaimed => 'Revendicată';

  @override
  String get invitesCouldNotLoad => 'N-am putut încărca invitațiile';

  @override
  String get invitesRetry => 'Reîncearcă';

  @override
  String get searchSomethingWentWrong => 'Ceva nu a mers bine';

  @override
  String get searchTryAgain => 'Încearcă din nou';

  @override
  String get searchForLists => 'Caută liste';

  @override
  String get searchFindCuratedVideoLists =>
      'Găsește liste de videoclipuri selectate';

  @override
  String get searchEnterQuery => 'Introdu un termen de căutare';

  @override
  String get searchDiscoverSomethingInteresting => 'Descoperă ceva interesant';

  @override
  String get searchPeopleSectionHeader => 'Persoane';

  @override
  String get searchPeopleLoadingLabel =>
      'Se încarcă rezultatele pentru persoane';

  @override
  String get searchTagsSectionHeader => 'Etichete';

  @override
  String get searchTagsLoadingLabel => 'Se încarcă rezultatele pentru etichete';

  @override
  String get searchVideosSectionHeader => 'Videoclipuri';

  @override
  String get searchVideosLoadingLabel =>
      'Se încarcă rezultatele pentru videoclipuri';

  @override
  String get searchVideosSortOptionsLabel => 'Sortează rezultatele video';

  @override
  String get searchVideosSortTrending => 'În trend';

  @override
  String get searchVideosSortLoops => 'Cele mai multe bucle';

  @override
  String get searchVideosSortEngagement => 'Cea mai mare implicare';

  @override
  String get searchVideosSortRecent => 'Recente';

  @override
  String get searchListsSectionHeader => 'Liste';

  @override
  String get searchListsLoadingLabel => 'Se încarcă rezultatele listelor';

  @override
  String get cameraAgeRestriction =>
      'Trebuie să ai cel puțin 16 ani pentru a crea conținut';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Relay-ul bunker trebuie să folosească wss:// (ws:// e permis doar pentru localhost)';

  @override
  String get timeNow => 'acum';

  @override
  String timeShortMinutes(int count) {
    return '${count}min';
  }

  @override
  String timeShortHours(int count) {
    return '${count}h';
  }

  @override
  String timeShortDays(int count) {
    return '${count}z';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}săpt';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}lu';
  }

  @override
  String timeShortYears(int count) {
    return '${count}a';
  }

  @override
  String get timeVerboseNow => 'Acum';

  @override
  String timeAgo(String time) {
    return 'acum $time';
  }

  @override
  String get timeToday => 'Astăzi';

  @override
  String get timeYesterday => 'Ieri';

  @override
  String get timeJustNow => 'chiar acum';

  @override
  String timeMinutesAgo(int count) {
    return 'acum ${count}min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'acum ${count}h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'acum ${count}z';
  }

  @override
  String get draftTimeJustNow => 'Chiar acum';

  @override
  String get contentLabelNudity => 'Nuditate';

  @override
  String get contentLabelSexualContent => 'Conținut sexual';

  @override
  String get contentLabelPornography => 'Pornografie';

  @override
  String get contentLabelGraphicMedia => 'Conținut grafic';

  @override
  String get contentLabelViolence => 'Violență';

  @override
  String get contentLabelSelfHarm => 'Automutilare/Suicid';

  @override
  String get contentLabelDrugUse => 'Consum de droguri';

  @override
  String get contentLabelAlcohol => 'Alcool';

  @override
  String get contentLabelTobacco => 'Tutun/Fumat';

  @override
  String get contentLabelGambling => 'Jocuri de noroc';

  @override
  String get contentLabelProfanity => 'Limbaj vulgar';

  @override
  String get contentLabelHateSpeech => 'Discurs instigator la ură';

  @override
  String get contentLabelHarassment => 'Hărțuire';

  @override
  String get contentLabelFlashingLights => 'Lumini intermitente';

  @override
  String get contentLabelAiGenerated => 'Generat de AI';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Înșelăciune/Fraudă';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Înșelător';

  @override
  String get contentLabelSensitiveContent => 'Conținut sensibil';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName a apreciat videoclipul tău';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName a apreciat comentariul tău';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName a comentat la videoclipul tău';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName a început să te urmărească';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName te-a menționat';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName a redistribuit videoclipul tău';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName a postat un videoclip nou';
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
      other: '$count de vine-uri ale tale',
      few: '$count vine-uri ale tale',
      one: 'vine-ul tău',
    );
    return '$actorName a adăugat $_temp0 în $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName a răspuns la comentariul tău';
  }

  @override
  String get notificationAndConnector => 'și';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'încă $count persoane',
      one: 'încă 1 persoană',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Ai o actualizare nouă';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Ascunde tastatura';

  @override
  String get commentsErrorLoadFailed => 'Nu am putut încărca comentariile';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Autentifică-te ca să comentezi';

  @override
  String get commentsErrorPostCommentFailed =>
      'Nu am putut publica comentariul';

  @override
  String get commentsErrorPostReplyFailed => 'Nu am putut publica răspunsul';

  @override
  String get commentsErrorEditFailed => 'Nu am putut edita comentariul';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Autentifică-te ca să interacționezi';

  @override
  String get commentsErrorVoteFailed => 'Nu am putut vota comentariul';

  @override
  String get commentsErrorReportFailed => 'Nu am putut raporta comentariul';

  @override
  String get commentsErrorBlockFailed => 'Nu am putut bloca utilizatorul';

  @override
  String get commentsErrorDeleteFailed => 'Nu am putut șterge comentariul';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de comentarii',
      few: '$count comentarii',
      one: '$count comentariu',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Se publică…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Răspunsul tău video se publică';

  @override
  String get commentsSortNew => 'Noi';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get commentsSortOld => 'Vechi';

  @override
  String get commentsSortSemanticLabel => 'Sortarea comentariilor';

  @override
  String get commentReply => 'Răspunde';

  @override
  String get commentReplySemanticLabel => 'Răspunde la comentariu';

  @override
  String get commentUpvoteLabel => 'Votează pozitiv comentariul';

  @override
  String get commentRemoveUpvoteLabel => 'Retrage votul pozitiv';

  @override
  String get commentDownvoteLabel => 'Votează negativ comentariul';

  @override
  String get commentRemoveDownvoteLabel => 'Retrage votul negativ';

  @override
  String get commentsInputHint => 'Adaugă un comentariu...';

  @override
  String get commentsInputHintEdit => 'Editează comentariul...';

  @override
  String get commentsEmptyTitle => 'Încă nu sunt comentarii';

  @override
  String get commentsEmptySubtitle => 'Dă tu startul!';

  @override
  String get draftUntitled => 'Fără titlu';

  @override
  String get contentWarningNone => 'Niciunul';

  @override
  String get textBackgroundNone => 'Niciunul';

  @override
  String get textBackgroundSolid => 'Opac';

  @override
  String get textBackgroundHighlight => 'Evidențiere';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Stânga';

  @override
  String get textAlignRight => 'Dreapta';

  @override
  String get textAlignCenter => 'Centru';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Camera nu este încă acceptată pe web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Captura și înregistrarea cu camera nu sunt încă disponibile în versiunea web.';

  @override
  String get cameraPermissionBackToFeed => 'Înapoi la feed';

  @override
  String get cameraCouldNotStart => 'Nu s-a putut porni camera';

  @override
  String get cameraUnsupportedPlatform =>
      'Camera nu este încă disponibilă pe această platformă.\nPoți totuși să explorezi și să vizionezi videoclipuri.';

  @override
  String get cameraPermissionErrorTitle => 'Eroare de permisiuni';

  @override
  String get cameraPermissionErrorDescription =>
      'A apărut o eroare la verificarea permisiunilor.';

  @override
  String get cameraPermissionRetry => 'Încearcă din nou';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Permite accesul la cameră și microfon';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Aceasta îți permite să capturezi și să editezi videoclipuri direct în aplicație, nimic mai mult.';

  @override
  String get cameraPermissionGoToSettings => 'Mergi la setări';

  @override
  String get videoRecorderWhySixSecondsTitle => 'De ce șase secunde?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Clipurile scurte lasă loc pentru spontaneitate. Formatul de 6 secunde te ajută să surprinzi momente autentice exact când se întâmplă.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Am înțeles!';

  @override
  String get videoRecorderUploadTitle => 'De ce fără upload?';

  @override
  String get videoRecorderUploadBody =>
      'Ceea ce vezi pe Divine este făcut de oameni: brut și capturat în moment. Spre deosebire de platformele care permit upload-uri puternic produse sau generate de IA, prioritizăm autenticitatea experienței directe din cameră.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Păstrând crearea în aplicație, putem garanta mai bine că conținutul este real și needitat. Nu deschidem upload-uri din galeria externă în acest moment pentru a proteja acea autenticitate și a menține comunitatea noastră liberă de conținut sintetic pe cât posibil.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Treci la Capture sau Classic ca să filmezi ceva real.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Află cum funcționează verificarea';

  @override
  String get videoRecorderAutosaveFoundTitle => 'Am găsit lucru în desfășurare';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Vrei să continui de unde ai rămas?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Da, continuă';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Nu, începe un videoclip nou';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Nu am putut restaura schița ta';

  @override
  String get videoRecorderStopRecordingTooltip => 'Oprește înregistrarea';

  @override
  String get videoRecorderStartRecordingTooltip => 'Începe înregistrarea';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Înregistrare în curs. Atinge oriunde pentru a opri';

  @override
  String get videoRecorderTapToStartLabel =>
      'Atinge oriunde pentru a începe înregistrarea';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Șterge ultimul clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Schimbă camera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoom la $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Activează/dezactivează grila';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Activează/dezactivează cadrul fantomă';

  @override
  String get videoRecorderGhostFrameEnabled => 'Cadru fantomă activat';

  @override
  String get videoRecorderGhostFrameDisabled => 'Cadru fantomă dezactivat';

  @override
  String get videoRecorderClipDeletedMessage => 'Clipul a fost mutat în coș';

  @override
  String get videoRecorderClipUndoLabel => 'Anulează';

  @override
  String get libraryTrashEmptyTitle => 'Coșul de gunoi este gol';

  @override
  String get libraryTrashEmptySubtitle =>
      'Clipurile șterse rămân aici timp de 30 de zile înainte de a fi eliminate definitiv.';

  @override
  String get libraryTrashRestoreLabel => 'Restaurează';

  @override
  String get libraryTrashDeleteNowLabel => 'Șterge acum';

  @override
  String get libraryTrashEmptyAllLabel => 'Golește coșul';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Ștergi clipul acum?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Asta scoate clipul din coș imediat.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Golești coșul?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipuri',
      one: '1 clip',
    );
    return 'Asta șterge definitiv din coș $_temp0 imediat.';
  }

  @override
  String get videoRecorderCloseLabel => 'Închide înregistratorul video';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Continuă către editorul video';

  @override
  String get videoRecorderCameraPreviewLabel => 'Previzualizare cameră';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Focalizează camera';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Comută la modul $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Adaugă audio înainte de înregistrare';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Videoclipul nu a putut fi creat. Încearcă din nou.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Au mai rămas $count de cadre',
      few: 'Au mai rămas $count cadre',
      one: 'A mai rămas 1 cadru',
      zero: 'Nu mai sunt cadre',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Activează/dezactivează blițul';

  @override
  String get videoRecorderCycleTimerLabel => 'Schimbă temporizatorul';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Schimbă raportul de aspect';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilizare';

  @override
  String get videoRecorderStabilizationModeOff => 'Dezactivată';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinematică';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematică extinsă';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Optimizată pentru previzualizare';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Latență redusă';

  @override
  String get videoRecorderStabilizationModeAuto => 'Automată';

  @override
  String get videoRecorderFlashValueOff => 'Dezactivat';

  @override
  String get videoRecorderFlashValueOn => 'Activat';

  @override
  String get videoRecorderFlashValueAuto => 'Automat';

  @override
  String get videoRecorderTimerValueOff => 'Dezactivat';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 secunde';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 secunde';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Pătrat';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Vertical';

  @override
  String get videoRecorderCameraValueFront => 'Cameră frontală';

  @override
  String get videoRecorderCameraValueBack => 'Cameră posterioară';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Bibliotecă de clipuri, fără clipuri';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Deschide biblioteca de clipuri, $clipCount clipuri',
      one: 'Deschide biblioteca de clipuri, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Deschide biblioteca stop-motion, $frameCount de cadre',
      few: 'Deschide biblioteca stop-motion, $frameCount cadre',
      one: 'Deschide biblioteca stop-motion, 1 cadru',
      zero: 'Deschide biblioteca stop-motion',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Cameră';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Deschide camera';

  @override
  String get videoEditorLibraryLabel => 'Bibliotecă';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Desen';

  @override
  String get videoEditorFilterLabel => 'Filtru';

  @override
  String get videoEditorTuneLabel => 'Ajustează';

  @override
  String get videoEditorOpenTuneSemanticLabel =>
      'Deschide editorul de ajustări';

  @override
  String get videoEditorTuneBrightness => 'Luminozitate';

  @override
  String get videoEditorTuneContrast => 'Contrast';

  @override
  String get videoEditorTuneSaturation => 'Saturație';

  @override
  String get videoEditorTuneExposure => 'Expunere';

  @override
  String get videoEditorTuneHue => 'Nuanță';

  @override
  String get videoEditorTuneTemperature => 'Temperatură';

  @override
  String get videoEditorTuneTint => 'Tentă';

  @override
  String get videoEditorTuneFade => 'Estompare';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Adaugă';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Deschide biblioteca';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Deschide editorul audio';

  @override
  String get videoEditorCaptionsLabel => 'Subtitrări';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Deschide editorul de subtitrări';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Încorporează în videoclip';

  @override
  String get videoEditorCaptionsPresetCustom => 'Person.';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Stil personalizat';

  @override
  String get videoEditorCaptionsCustomApply => 'Aplică';

  @override
  String get videoEditorCaptionsCustomFont => 'Font';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Culoare text';

  @override
  String get videoEditorCaptionsCustomBackground => 'Fundal';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Culoare fundal';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animație';

  @override
  String get videoEditorCaptionsAnimationNone => 'Niciuna';

  @override
  String get videoEditorCaptionsAnimationFade => 'Estompare';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Arc';

  @override
  String get videoEditorCaptionsEditTitle => 'Subtitrări';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Ascultăm…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Transformăm audio-ul tău în sugestii de subtitrare.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Nu am auzit nicio voce. Poți totuși să scrii subtitrările singur.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Recunoașterea vocală nu este disponibilă pe acest dispozitiv. Poți scrie subtitrările singur.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Recunoașterea vocală nu este permisă. Activeaz-o din Setări sau scrie subtitrările singur.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Transcrierea nu a funcționat de data asta. Poți scrie subtitrările singur.';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'Scriu subtitrările singur';

  @override
  String get videoEditorCaptionsAddCue => 'Adaugă subtitrare';

  @override
  String get videoEditorCaptionsCueTextHint => 'Textul subtitrării';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Șterge subtitrarea';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Elimină toate subtitrările';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Elimini subtitrările?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Tot textul și timpii se vor pierde.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Închide editorul de subtitrări';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Confirmă subtitrările';

  @override
  String get videoEditorCaptionsPresetTitle => 'Stilul subtitrărilor';

  @override
  String get videoEditorCaptionsPresetClassic => 'Clasic';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Titlu';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Mașină de scris';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marker';

  @override
  String get videoEditorCaptionsPresetScript => 'Caligrafie';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegant';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bulă';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Aldin';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Visător';

  @override
  String get videoEditorCaptionsPresetOcean => 'Ocean';

  @override
  String get videoEditorCaptionsPresetSunny => 'Însorit';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Scris de mână';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Ștampilă';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Deschide editorul de text';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Deschide editorul de desen';

  @override
  String get videoEditorOpenFilterSemanticLabel =>
      'Deschide editorul de filtre';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Deschide editorul de stickere';

  @override
  String get videoEditorSaveDraftTitle => 'Salvezi schița?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Păstrează editările pentru mai târziu sau renunță la ele și părăsește editorul.';

  @override
  String get videoEditorSaveDraftButton => 'Salvează schița';

  @override
  String get videoEditorDiscardChangesButton => 'Renunță la modificări';

  @override
  String get videoEditorKeepEditingButton => 'Continuă editarea';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Zonă de plasare pentru ștergerea stratului';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Eliberează pentru a șterge stratul';

  @override
  String get videoEditorDoneLabel => 'Gata';

  @override
  String get videoEditorPlayPauseSemanticLabel =>
      'Redă sau pune pe pauză videoclipul';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Poziție de împărțire invalidă. Ambele clipuri trebuie să aibă cel puțin $minDurationMs ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Salvează clipul selectat';

  @override
  String get videoEditorSaveClip => 'Salvează clipul';

  @override
  String get videoEditorClipSavedSuccess => 'Clip salvat în bibliotecă';

  @override
  String get videoEditorClipSaveFailed => 'Nu s-a putut salva clipul';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Selector de culoare';

  @override
  String get videoEditorUndoSemanticLabel => 'Anulează';

  @override
  String get videoEditorRedoSemanticLabel => 'Refă';

  @override
  String get videoEditorTextColorSemanticLabel => 'Culoare text';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Aliniere text';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Fundal text';

  @override
  String get videoEditorFontSemanticLabel => 'Font';

  @override
  String get videoEditorNoStickersFound => 'Nu au fost găsite stickere';

  @override
  String get videoEditorNoStickersAvailable => 'Nu sunt disponibile stickere';

  @override
  String get videoEditorFailedLoadStickers =>
      'Nu s-au putut încărca stickerele';

  @override
  String get videoEditorVoiceOverLabel => 'Voce off';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Înregistrarea $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel =>
      'Înregistrează o voce off';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel =>
      'Pornește înregistrarea';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Oprește înregistrarea';

  @override
  String get videoEditorVoiceOverHint =>
      'Atinge pentru a înregistra. Adaugă câte cadre vrei.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count înregistrări',
      one: '1 înregistrare',
      zero: 'Nicio înregistrare încă',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Șterge ultima înregistrare';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Este necesar accesul la microfon';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Permite accesul la microfon pentru a înregistra o voce off.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Deschide setările';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Înregistrare pornită';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Înregistrare salvată';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Înregistrarea este mai lungă decât videoclipul tău';

  @override
  String get videoEditorPlaySemanticLabel => 'Redă';

  @override
  String get videoEditorPauseSemanticLabel => 'Pauză';

  @override
  String get videoEditorVolumeSemanticLabel => 'Reglare volum';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volum $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Glisează pentru ajustare';

  @override
  String get videoEditorChromaKeyLabel => 'Ecran verde';

  @override
  String get videoEditorChromaKeyTitle => 'Ecran verde';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Configurează ecranul verde pentru acest clip';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Renunță la modificările ecranului verde';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Aplică ecranul verde';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Detectare automată';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Verde';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Albastru';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Culoarea fundalului';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Intensitate';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Cât din culoarea fundalului dispare';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Margine';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Înmoaie decupajul ca părul să nu iasă zimțat';

  @override
  String get videoEditorChromaKeySpillLabel => 'Reflexie';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Scoate nuanța fundalului de pe subiect';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Înlocuiește cu';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Nimic';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Culoare';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Imagine';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Videoclipul nu poate păstra transparența, așa că la export iese negru.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Nu am găsit niciun fundal. Trebuie să ajungă la marginile cadrului — altfel alege culoarea manual.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Alege un clip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Biblioteca ta e goală. Salvează întâi un clip, apoi folosește-l ca fundal.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Imaginea nu a putut fi încărcată.';

  @override
  String get videoEditorChromaKeyRemove => 'Elimină ecranul verde';

  @override
  String get videoEditorChromaKeyFailed =>
      'Ecranul verde nu a putut fi aplicat. Clipul tău rămâne neschimbat.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Ecranul verde nu a putut fi eliminat. Clipul tău rămâne neschimbat.';

  @override
  String get videoEditorChromaKeyApplying => 'Se aplică ecranul verde…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Acest dispozitiv nu poate afișa previzualizarea live. Setările tale se aplică oricum la export.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Șterge';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Șterge elementul selectat';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Cadre pe imagine';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cadre',
      one: '1 cadru',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Cadre';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count cadre pe imagine';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Cadru stop-motion $position din $total';
  }

  @override
  String get videoEditorEditLabel => 'Editează';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Editează elementul selectat';

  @override
  String get videoEditorDuplicateLabel => 'Duplichează';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplichează elementul selectat';

  @override
  String get videoEditorCombineLabel => 'Combină';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Combină desenele selectate într-un singur strat';

  @override
  String get videoEditorSplitLabel => 'Împarte';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Împarte clipul selectat';

  @override
  String get videoEditorExtractAudioLabel => 'Extrage audio';

  @override
  String get videoEditorClipAudioTitle => 'Audio clip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Extrage audio din clip și dezactivează sunetul originalului';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Nu se poate extrage audio: clipul nu este disponibil local.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Nu s-a putut extrage audio. Vă rugăm să încercați din nou.';

  @override
  String get videoEditorSpeedLabel => 'Viteză';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Setați viteza de redare pentru clipul selectat';

  @override
  String get videoEditorReverseLabel => 'Invers';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Activați sau dezactivați redarea inversă pentru clipul selectat';

  @override
  String get videoEditorReverseProgressLabel => 'O clipă, inversăm clipul tău';

  @override
  String get videoEditorTransformLabel => 'Transformă';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Decupează, rotește sau întoarce clipul selectat';

  @override
  String get videoEditorTransformProgressLabel =>
      'O clipă, transformăm clipul tău';

  @override
  String get videoEditorTransformFailed =>
      'Clipul nu a putut fi transformat. Încearcă din nou.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Transformare imposibilă: clipul nu este disponibil local.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Decupează, rotește sau oglindește cadrul selectat';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'O clipă, îți transformăm cadrul';

  @override
  String get videoEditorTransformFrameFailed =>
      'Cadrul nu a putut fi transformat. Încearcă din nou.';

  @override
  String get videoEditorTransformRotateLabel => 'Rotește';

  @override
  String get videoEditorTransformFlipLabel => 'Întoarce';

  @override
  String get videoEditorTransformResetLabel => 'Resetează';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Aplică transformarea';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Anulează transformarea';

  @override
  String get videoEditorTransformPlayLabel => 'Redă';

  @override
  String get videoEditorTransformPauseLabel => 'Pauză';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Nu se poate inversa: clipul nu este disponibil local.';

  @override
  String get videoEditorReverseFailed =>
      'Nu s-a putut inversa clipul. Vă rugăm să încercați din nou.';

  @override
  String get videoEditorSpeedSheetTitle => 'Viteza clipului';

  @override
  String get videoEditorTransitionSheetTitle => 'Tranziție';

  @override
  String get videoEditorTransitionNone => 'Niciuna';

  @override
  String get videoEditorTransitionDissolve => 'Disolvare';

  @override
  String get videoEditorTransitionFadeToBlack => 'Estompare spre negru';

  @override
  String get videoEditorTransitionFadeToWhite => 'Estompare spre alb';

  @override
  String get videoEditorTransitionSlide => 'Glisare';

  @override
  String get videoEditorTransitionPush => 'Împingere';

  @override
  String get videoEditorTransitionWipe => 'Ștergere';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Editează tranziția';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Tranziție în buclă';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Editează tranziția în buclă';

  @override
  String get videoEditorTransitionDuration => 'Durată';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Scurtată pentru a nu se suprapune cu tranziția alăturată.';

  @override
  String get videoEditorTransitionCurve => 'Curbă';

  @override
  String get videoEditorTransitionDirection => 'Direcție';

  @override
  String get videoEditorTransitionDirectionLeft => 'Stânga';

  @override
  String get videoEditorTransitionDirectionRight => 'Dreapta';

  @override
  String get videoEditorTransitionDirectionUp => 'Sus';

  @override
  String get videoEditorTransitionDirectionDown => 'Jos';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Curbă de animație $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animație';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Editează animația stratului';

  @override
  String get videoEditorLayerAnimationEnter => 'Intrare';

  @override
  String get videoEditorLayerAnimationLeave => 'Ieșire';

  @override
  String get videoEditorLayerAnimationFade => 'Estompare';

  @override
  String get videoEditorLayerAnimationScale => 'Scalare';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Scalare de la';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Finalizează editarea cronologiei';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Redă previzualizarea';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'Pune previzualizarea pe pauză';

  @override
  String get videoEditorAudioUntitledSound => 'Sunet fără titlu';

  @override
  String get videoEditorAudioUntitled => 'Fără titlu';

  @override
  String get videoEditorAudioAddAudio => 'Adaugă audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Nu sunt sunete disponibile';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Sunetele vor apărea aici când creatorii vor partaja audio';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Nu s-au putut încărca sunetele';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Alege segmentul audio pentru videoclipul tău';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Comunitate';

  @override
  String get videoEditorAudioCategoryFeatured => 'Recomandate';

  @override
  String get videoEditorAudioCategoryMySounds => 'Sunetele mele';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Instrument săgeată';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Instrument radieră';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Instrument marker';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Instrument creion';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Afișează cronologia';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ascunde cronologia';

  @override
  String get videoEditorFeedPreviewContent =>
      'Evită să plasezi conținut în spatele acestor zone.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originale';

  @override
  String get videoEditorStickerSearchHint => 'Caută stickere...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Selectează fontul';

  @override
  String get videoEditorFontUnknown => 'Necunoscut';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Capul de redare trebuie să fie în clipul selectat pentru a împărți.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Taie începutul';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Taie finalul';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Taie clipul';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Trage mânerele pentru a ajusta durata clipului';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Se trage clipul $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clipul $index din $total, $duration secunde';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Apăsare lungă pentru reordonare';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Mută la stânga';

  @override
  String get videoEditorTimelineClipMoveRight => 'Mută la dreapta';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index din $total, selectat';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index din $total, neselectat';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Selectează';

  @override
  String get videoEditorMultiSelectSemanticLabel =>
      'Selectează mai multe clipuri';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Finalizează selecția';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipuri selectate',
      one: '1 clip selectat',
      zero: 'Niciun clip selectat',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Selectează mai multe desene';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Termină selectarea desenelor';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Șterge desenele selectate';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count desene selectate',
      one: '1 desen selectat',
      zero: 'Niciun desen selectat',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Îmbină';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Îmbină clipurile selectate';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Șterge clipurile selectate';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Șterge cadrele selectate';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Inversează cadrele selectate';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplichează cadrele selectate';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Videoclipul tău trebuie să dureze cel puțin ${seconds}s — capturează încă câteva cadre.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Un moment, îți îmbinăm clipurile';

  @override
  String get videoEditorMergeFailed =>
      'Clipurile nu au putut fi îmbinate. Încearcă din nou.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Apasă lung pentru a trage';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Cronologie video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, selectat';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Închide selectorul de culoare';

  @override
  String get videoEditorPickColorTitle => 'Alege culoarea';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirmă culoarea';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturație și luminozitate';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturație $saturation%, Luminozitate $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Nuanță';

  @override
  String get videoEditorAddElementSemanticLabel => 'Adaugă element';

  @override
  String get videoEditorDoneSemanticLabel => 'Gata';

  @override
  String get videoEditorLevelSemanticLabel => 'Nivel';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Închide detaliile postării';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Închide dialogul de ajutor';

  @override
  String get videoMetadataGotItButton => 'Am înțeles!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limita de 64KB a fost atinsă. Elimină conținut pentru a continua.';

  @override
  String get videoMetadataExpirationLabel => 'Expirare';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Selectează timpul de expirare';

  @override
  String get videoMetadataTitleLabel => 'Titlu';

  @override
  String get videoMetadataDescriptionLabel => 'Descriere';

  @override
  String get videoMetadataTagsLabel => 'Etichete';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Șterge eticheta $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Avertisment de conținut';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Selectează avertismente de conținut';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Selectează tot ce se aplică conținutului tău';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Permite altora să salveze și să reutilizeze audio-ul acestui videoclip.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Videoclipul tău e publicat, dar sunetul nu. Editează videoclipul ca să îl împarți.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Colaboratori';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Adaugă colaborator';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Urmăritori reciproci';

  @override
  String get videoMetadataInspiredByLabel => 'Inspirat de';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Setează inspirat de';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Nu se poate face referire la acest creator.';

  @override
  String get videoMetadataPostDetailsTitle => 'Detalii postare';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Salvat în bibliotecă';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Salvare eșuată';

  @override
  String get videoMetadataGoToLibraryButton => 'Mergi la bibliotecă';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Buton salvează pentru mai târziu';

  @override
  String get videoMetadataSavingVideoHint => 'Se salvează videoclipul...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Salvează videoclipul în schițe și $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Salvează videoclipul în schițe. Încă nu există un videoclip randat, deci nicio copie în $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Salvează pentru mai târziu';

  @override
  String get videoMetadataPostSemanticLabel => 'Buton publică';

  @override
  String get videoMetadataPublishVideoHint => 'Publică videoclipul în feed';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Distribuie și în feedul meu';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Oprit păstrează acest videoclip doar în firul de comentarii.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Completează formularul pentru a activa';

  @override
  String get videoMetadataPostButton => 'Publică';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Deschide ecranul de previzualizare a postării';

  @override
  String get videoMetadataShareTitle => 'Distribuie';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Detalii videoclip';

  @override
  String get videoMetadataClassicDoneButton => 'Gata';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Redă previzualizarea';

  @override
  String get videoMetadataPausePreviewSemanticLabel =>
      'Pune previzualizarea pe pauză';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Închide previzualizarea videoclipului';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Elimină';

  @override
  String get fullscreenFeedRemovedMessage => 'Videoclip eliminat';

  @override
  String get fullscreenFeedEmptyMessage => 'Nu mai e nimic de redat aici';

  @override
  String get settingsBadgesTitle => 'Insigne';

  @override
  String get settingsBadgesSubtitle =>
      'Acceptă premii și verifică starea insignelor emise.';

  @override
  String get badgesTitle => 'Insigne';

  @override
  String get badgesLoadError => 'N-am putut încărca insignele';

  @override
  String get badgesUpdateError => 'N-am putut actualiza insigna';

  @override
  String get badgesAwardedEmptyTitle => 'Încă niciun premiu cu insignă';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Când cineva îți acordă o insignă Nostr, va ajunge aici.';

  @override
  String get badgesStatusAccepted => 'Acceptată';

  @override
  String get badgesStatusNotAccepted => 'Neacceptată';

  @override
  String get badgesActionRemove => 'Elimină';

  @override
  String get badgesActionAccept => 'Acceptă';

  @override
  String get badgesActionReject => 'Respinge';

  @override
  String get badgesIssuedEmptyTitle => 'Încă nicio insignă emisă';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Insignele pe care le emiți vor afișa aici starea de acceptare.';

  @override
  String get badgesIssuedNoRecipients =>
      'Niciun destinatar găsit pentru acest premiu.';

  @override
  String get badgesRecipientAcceptedStatus => 'Acceptată de destinatar';

  @override
  String get badgesRecipientWaitingStatus => 'Se așteaptă destinatarul';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ascunse ($count)',
      one: 'Ascunsă (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Restaurează';

  @override
  String get badgesHiddenSnackbar => 'Insignă ascunsă';

  @override
  String get badgesHiddenSnackbarUndo => 'Anulează';

  @override
  String get badgesTabAwarded => 'Primite';

  @override
  String get badgesTabCreated => 'Create';

  @override
  String get badgesTabIssued => 'Acordate';

  @override
  String get badgesCreateAction => 'Insignă nouă';

  @override
  String get badgesCreatedEmptyTitle => 'Nicio insignă creată încă';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Creează una și dă-i-o cuiva care o merită.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Acordată la $count persoane',
      one: 'Acordată unei persoane',
      zero: 'Încă neacordată',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Insignă nouă';

  @override
  String get badgeEditorEditTitle => 'Editează insigna';

  @override
  String get badgeEditorNameLabel => 'Nume';

  @override
  String get badgeEditorNameHint => 'Fură scena';

  @override
  String get badgeEditorIdentifierLabel => 'Identificator';

  @override
  String get badgeEditorIdentifierHelp =>
      'Face parte din adresa insignei, deci rămâne fix după ce insigna există.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Ai deja o insignă cu acest identificator. Editeaz-o pe aceea — publicarea aici ar înlocui-o.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Fiecare insignă are nevoie de un identificator — scrie-l tu dacă numele nu l-a completat.';

  @override
  String get badgeEditorDescriptionLabel => 'Descriere';

  @override
  String get badgeEditorDescriptionHint =>
      'Pentru cine fură scena cu un singur loop.';

  @override
  String get badgeEditorArtworkLabel => 'Grafică';

  @override
  String get badgeEditorArtworkAdd => 'Adaugă grafică';

  @override
  String get badgeEditorArtworkReplace => 'Înlocuiește';

  @override
  String get badgeEditorArtworkError => 'Imaginea nu a putut fi încărcată';

  @override
  String get badgeEditorArtworkRequired =>
      'Fiecare insignă are nevoie de o grafică.';

  @override
  String get badgeEditorArtworkRemove => 'Elimină grafica';

  @override
  String get badgeEditorArtworkSheetTitle => 'Grafica insignei';

  @override
  String get badgeDetailDeleteAction => 'Șterge insigna';

  @override
  String get badgeDetailDeleteTitle => 'Ștergi această insignă?';

  @override
  String get badgeDetailDeleteBody =>
      'Asta cere releelor să renunțe la insignă și la toate acordările făcute de tine. Releele pot refuza, iar cine a fixat-o o păstrează pe profil până o scoate singur.';

  @override
  String get badgeDetailDeleteConfirm => 'Șterge';

  @override
  String get badgeEditorSaveAction => 'Publică insigna';

  @override
  String get badgeEditorSaveError => 'Insigna nu a putut fi publicată';

  @override
  String get badgeEditorLoadError => 'Această insignă nu a putut fi încărcată';

  @override
  String get badgeDetailTitle => 'Insignă';

  @override
  String get badgeDetailMadeBy => 'Creată de';

  @override
  String get badgeDetailRecipientsTitle => 'Acordată';

  @override
  String get badgeDetailNoRecipients => 'Încă nu o are nimeni.';

  @override
  String get badgeDetailAwardAction => 'Acordă această insignă';

  @override
  String get badgeDetailEditAction => 'Editează insigna';

  @override
  String get badgeDetailShareAction => 'Distribuie';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Vezi insigna asta pe Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Retrage insigna';

  @override
  String get badgeDetailRevokeTitle => 'Retragi această insignă?';

  @override
  String get badgeDetailRevokeBody =>
      'Asta cere releelor să renunțe la acordarea făcută acestei persoane. Releele pot refuza, iar dacă a fixat deja insigna, ea rămâne pe profil până o scoate singură. Oricum ar fi, nu primește nicio notificare.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Asta cere releelor să renunțe la acordarea pe care ți-ai făcut-o și scoate insigna de pe profilul tău. Dacă releele refuză ștergerea, nu se schimbă nimic.';

  @override
  String get badgeDetailRevokeConfirm => 'Retrage';

  @override
  String get badgeDetailRevokeSuccess => 'Insignă retrasă';

  @override
  String get badgeDetailBlockClaimantsAction => 'Blochează cine poartă insigna';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Blochează cine poartă insigna';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Nu am putut încărca cine poartă această insignă';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Nimeni nu poartă această insignă acum';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Nu am găsit pe nimeni de blocat acum.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blochezi $count de conturi?',
      few: 'Blochezi $count conturi?',
      one: 'Blochezi 1 cont?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Asta blochează cele $count de conturi care poartă acum această insignă. Postările lor nu vor mai apărea în feedurile tale și nu vor fi notificate.',
      few:
          'Asta blochează cele $count conturi care poartă acum această insignă. Postările lor nu vor mai apărea în feedurile tale și nu vor fi notificate.',
      one:
          'Asta blochează contul care poartă acum această insignă. Postările lui nu vor mai apărea în feedurile tale și nu va fi notificat.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blochează $count de conturi',
      few: 'Blochează $count conturi',
      one: 'Blochează 1 cont',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'Am blocat cine poartă insigna';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Nu am putut bloca cine poartă insigna';

  @override
  String get badgeDetailLoadError => 'Această insignă nu a putut fi încărcată';

  @override
  String get badgeDetailMissing => 'Nu găsim insigna pe niciun releu.';

  @override
  String get badgeDetailActionError => 'Nu a mers';

  @override
  String get badgeAwardTitle => 'Acordă insigna';

  @override
  String get badgeAwardPickAction => 'Alege persoane';

  @override
  String get badgeAwardManualLabel => 'Sau lipește chei';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Alege cel puțin o persoană.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Acordă la $count persoane',
      one: 'Acordă unei persoane',
      zero: 'Acordă insigna',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Acordată de';

  @override
  String get profileBadgeRecipients => 'Destinatari';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+încă $count';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Insigna $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Insignă';

  @override
  String get profileBadgeFooterBody =>
      'Insignele sunt mici recompense pe care oricine le poate crea pe Nostr. Dăruiește una unui prieten, unui creator sau cuiva care ți-a făcut ziua mai bună.';

  @override
  String get profileBadgeFooterLink => 'Fă-ți propria insignă';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Ghid pentru familii';

  @override
  String get minorAccountReviewWelcomeTitle =>
      'Încă nu ai 16 ani? E în regulă.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Faptul că ai intrat pe această pagină în loc să alegi pur și simplu răspunsul care te lăsa să intri contează. Arată onestitate, caracter și grijă adevărată față de oamenii din jurul tău.\n\nRegulile pentru persoanele sub 16 ani diferă în funcție de locul unde trăiești. La Divine vrem ca familiile să discute împreună și să decidă cum arată o folosire sănătoasă a rețelelor sociale.';

  @override
  String get minorAccountReviewModerationTitle => 'Mai avem nevoie de un pas';

  @override
  String get minorAccountReviewModerationBody =>
      'Ni s-a cerut să ne uităm mai atent la acest cont fiindcă ar putea aparține unei persoane sub 16 ani. Acest flux păstrează pașii următori privați și îți arată drumul potrivit pentru vârsta ta.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Regulile nu sunt aceleași peste tot';

  @override
  String get minorAccountReviewRulesBody =>
      'Țările și regiunile tratează diferit folosirea rețelelor sociale de către adolescenți. De aceea le cerem familiilor să încetinească, să verifice faptele și să aleagă împreună pasul următor.';

  @override
  String get minorAccountReviewApproachTitle => 'Cum vede Divine lucrurile';

  @override
  String get minorAccountReviewApproachBody =>
      'Credem că obiceiurile sănătoase cu tehnologia vin din a te opri, a reflecta și a-ți muta atenția spre lucruri mai bune, nu din a-i spiona pe copii sau a-i transforma pe părinți în supraveghetori. Și cercetările susțin asta.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Mai multe pentru familii';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Citește politica Divine pentru copii';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Alege drumul potrivit';

  @override
  String get minorAccountReviewUnder13Cta => 'Sub 13 ani';

  @override
  String get minorAccountReviewTeenCta => '13-15 ani';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Vezi ghidul Divine pentru familii, cu sfaturi practice, instrumente de discuție și resurse care îi ajută pe adolescenți să folosească rețelele sociale mai în siguranță.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Obține ghiduri și sfaturi pentru familii';

  @override
  String get minorAccountReviewFooter =>
      'Dacă ai 16 ani sau mai mult și ai ajuns aici din greșeală, contactează asistența Divine ca să verifice un om real.';

  @override
  String get minorAccountReviewTitle => 'Verificarea contului';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Se verifică starea contului...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Așteaptă puțin cât confirmăm starea actuală a verificării acestui cont.';

  @override
  String get minorAccountReviewDefaultTitle =>
      'E necesară verificarea contului';

  @override
  String get minorAccountReviewDefaultBody =>
      'Trebuie să verificăm acest cont înainte să poată folosi Divine normal.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'ID caz: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'ID caz';

  @override
  String get minorAccountReviewRestrictionsTitle => 'Ce e restricționat acum';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Postarea și publicarea sunt oprite';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Comentariile, aprecierile, repostările și urmăririle sunt oprite';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Începerea și răspunsul la mesajele obișnuite sunt oprite';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Asistența și mesajul de la moderare rămân disponibile';

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
      'Deschide centrul de asistență';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Deschide mesajul de la moderare';

  @override
  String get minorAccountReviewOpenReviewPage =>
      'Deschide pagina de verificare';

  @override
  String get minorAccountReviewCheckAgain => 'Verifică din nou';

  @override
  String get minorAccountReviewLogOut => 'Deconectează-te';

  @override
  String get minorAccountReviewNextStepTitle => 'Pasul următor';

  @override
  String get minorAccountReviewNextStepBody =>
      'Deschide centrul de asistență sau mesajul de la moderare dacă ai nevoie de ajutor cu această verificare.';

  @override
  String get minorAccountReviewInProgressTitle => 'Verificare în curs';

  @override
  String get minorAccountReviewInProgressBody =>
      'Deocamdată avem ce ne trebuie. Echipa noastră analizează acest caz înainte de a reda accesul normal la cont.';

  @override
  String get minorAccountReviewUnder13Title => 'Conturi sub 13 ani';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Dacă acest cont aparține unei persoane sub 13 ani, un părinte sau tutore trebuie să scrie la $supportEmail și să includă ID-ul cazului.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Încă nu îți putem da un cont';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine nu e construit pentru copii sub 13 ani, iar regulile rețelelor sociale din întreaga lume ne leagă mâinile.\n\nMulte lucruri de pe internet te împing să minți ca să obții ce vrei, iar noi detestăm asta. E lecția greșită pentru viață și nu ți-o vom preda aici.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Ce poate face familia ta în schimb';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Un părinte sau tutore poate deține contul și poate posta, iar tu poți apărea liniștit în videoclipuri alături de ei. Vrem ca familiile să se bucure de Divine așa cum le e lor bine.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Când împlinești 13 ani';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'În funcție de regulile din locul unde trăiești, s-ar putea să poți reveni și să ceri propriul cont. În acel caz, dacă ai între 13 și 15 ani, îți va trebui acordul unui părinte sau tutore.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'De ce nu îți spunem doar să dai înapoi';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'O mare parte din internet este construită ca să răsplătească oamenii pentru că spun orice îi trece de poartă. Noi nu credem că e grozav așa. Da, ai putea da înapoi și spune că ești mai mare decât ești, dar asta nu ar fi cinstit, iar noi n-o să te învățăm să minți ca să obții ce vrei.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Încercăm să ajutăm tinerii să folosească Divine în moduri sănătoase și pozitive pentru ei și pentru cei din jurul lor. De asemenea, trebuie să respectăm legi care sunt diferite în locuri diferite. Așa că, dacă ai sub 13 ani, răspunsul este că nu poți avea propriul cont astăzi.';

  @override
  String get minorAccountReviewTeenBody =>
      'Dacă acest cont aparține unei persoane între 13 și 15 ani, folosește mesajul de la moderare sau calea de asistență pentru instrucțiunile privind acordul părintesc.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Dacă contul va aparține unei persoane între 13 și 15 ani';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Un părinte sau tutore ar trebui să scrie asistenței Divine și să atașeze un scurt videoclip privat. Echipa noastră îl va analiza și te va ajuta cu pașii următori.\n\nDacă nu poți contacta un părinte sau tutore ori dacă asta ar pune pe cineva în pericol, scrie asistenței Divine și spune-ne.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Este o pauză cât timp echipa de asistență Divine analizează videoclipul. Dacă este aprobat, te vor ghida în configurarea noului cont.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'De ce cerem implicarea unui părinte sau tutore';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine trebuie să respecte legi legate de vârstă din întreaga lume. Știm și că majoritatea barierelor tehnice de vârstă sunt imperfecte. În loc să pretindem că regulile nu există sau că e cool să minți despre vârsta ta, vrem ca adolescenții și familiile să ia decizii bine gândite despre cum să folosească Divine cel mai bine. De aceea, pentru cei între 13 și 15 ani, le cerem părinților să facă parte din procesul de creare a contului.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Trebuie și să respectăm legea, iar acele reguli sunt diferite în funcție de locul unde trăiește cineva. Așa că, în loc să pretindem că regulile nu există, cerem ca un părinte sau tutore să facă parte din proces.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Ce trebuie să arate videoclipul';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Adolescentul din videoclip';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Un părinte sau tutore vorbind în fața camerei';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'O declarație clară că adolescentul are între 13 și 15 ani și are permisiunea de a folosi Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'O declarație clară că părintele sau tutorele știe de cont și îi va supraveghea folosirea';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Cum îl trimiți';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Atașează videoclipul când scrii asistenței Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Păstrează videoclipul privat și nu îl posta în aplicație';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Echipa noastră îl va analiza și va răspunde cu pașii următori';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Scrie asistenței Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Ajutor pentru verificarea Divine Greenlight (13-15 ani)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Bună ziua, echipă de asistență Divine,\n\nvă scriu despre Divine Greenlight pentru un adolescent între 13 și 15 ani.\n\nAm atașat un scurt videoclip privat care arată:\n- adolescentul\n- un părinte sau tutore vorbind în fața camerei\n- că adolescentul are permisiunea de a folosi Divine\n- că părintele sau tutorele știe de cont și îi va supraveghea folosirea\n\nȚara/țările de reședință:\n\nContext util:\n\nMulțumesc.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Instrucțiuni de asistență pentru părinți';

  @override
  String get minorAccountReviewContinue => 'Continuă';

  @override
  String get minorAccountReviewErrorTitle =>
      'Nu am putut încărca starea verificării contului tău.';

  @override
  String get minorAccountReviewErrorBody => 'Încearcă din nou în scurt timp.';

  @override
  String get minorAccountReviewTryAgain => 'Încearcă din nou';

  @override
  String get minorAccountReviewParentContactTitle => 'Contact părinte';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Adaugă e-mailul unui părinte sau tutore';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Vom folosi această adresă pentru verificarea acordului părintesc în cazul $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'E-mailul părintelui sau tutorelui';

  @override
  String get minorAccountReviewSubmitting => 'Se trimite...';

  @override
  String get minorAccountReviewSubmitEmail => 'Trimite e-mailul';

  @override
  String get minorAccountReviewBackToReview => 'Înapoi la verificarea contului';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'E-mail trimis';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Am trimis $email spre verificare. Vom scrie la această adresă pentru confirmare. După ce părintele sau tutorele răspunde, cazul tău merge mai departe. Folosește „Verifică din nou” din ecranul de verificare a contului pentru noutăți.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Am primit datele de contact ale părintelui sau tutorelui pentru acest cont. Echipa noastră le va verifica înainte de a reda accesul.';

  @override
  String get minorAccountReviewMissingCase =>
      'Nu am găsit un caz de verificare activ pentru acest cont.';

  @override
  String get minorAccountReviewParentContactError =>
      'Nu am putut trimite e-mailul părintelui. Încearcă din nou.';

  @override
  String get minorAccountReviewUnder13SupportTitle =>
      'Asistență pentru părinți';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Un părinte sau tutore trebuie să contacteze Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Pentru conturile care par să aparțină unor persoane sub 13 ani, pasul următor e contactul prin e-mail al părintelui sau tutorelui.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'E-mail asistență';

  @override
  String get minorAccountReviewCopySupportEmail =>
      'Copiază e-mailul de asistență';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'E-mailul de asistență a fost copiat';

  @override
  String get minorAccountReviewCopyCaseId => 'Copiază ID-ul cazului';

  @override
  String get minorAccountReviewCaseIdCopied => 'ID-ul cazului a fost copiat';

  @override
  String get minorAccountReviewUnavailable => 'Indisponibil';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Roagă părintele sau tutorele să includă ID-ul cazului și să explice că ia legătura cu Divine în legătură cu această verificare a contului.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Verificare cont sub 13 ani pentru cazul $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Bună ziua, echipă de asistență Divine,\n\nsunt părintele sau tutorele unui copil sub 13 ani și vă scriu despre cazul de verificare a contului $caseId.\n\nMulțumesc.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulare verificare cont de minor';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Starea curentă';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Restricționat ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Activ';

  @override
  String get devOptionsMinorReviewStateLoading => 'Se încarcă...';

  @override
  String get devOptionsMinorReviewStateError => 'Eroare la încărcarea stării';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Șterge suprascrierea simulării';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Folosește din nou backendul sau starea activă implicită';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      'Simulează cazul de verificare 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Cont restricționat cu traseu de contact al părintelui';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simulează cazul de asistență sub 13 ani';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Cont restricționat cu instrucțiuni doar prin e-mailul părintelui';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simularea verificării contului de minor a fost ștearsă';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Cazul simulat de asistență sub 13 ani a fost activat';

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
      'Simulare minor protejat';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Starea curentă';

  @override
  String get devOptionsProtectedMinorStateProtected => 'Minor protejat (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Neprotejat';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Se încarcă…';

  @override
  String get devOptionsProtectedMinorStateError => 'Eroare la citirea stării';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Fără suprascriere (starea reală a contului)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Suprascriere: protejat forțat';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Suprascriere: neprotejat forțat';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simulează minor protejat (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Forțează starea de minor protejat ca să testezi protecțiile #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simulează persoană majoră';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Forțează neprotejat (un „nu” explicit, diferit de lipsa suprascrierii)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Șterge suprascrierea';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Revino la starea reală a contului dată de Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Starea de minor protejat a fost forțată';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Starea de minor protejat a fost dezactivată';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Suprascrierea de minor protejat a fost ștearsă';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Invitații de înregistrare';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Starea curentă';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Valoare server: se încarcă';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Valoare server: activat';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Valoare server: dezactivat';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Valoare server: necunoscută';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Suprascriere: folosește valoarea serverului';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Suprascriere: forțează activarea';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Suprascriere: forțează dezactivarea';

  @override
  String get devOptionsInviteAvailabilityUseServer =>
      'Folosește valoarea serverului';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Urmează onboardingMode al serviciului de invitații';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Forțează activarea';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Afișează local porțile de invitații și administrarea lor';

  @override
  String get devOptionsInviteAvailabilityForceDisabled =>
      'Forțează dezactivarea';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Ascunde local interfața invitațiilor fără a modifica serverul';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Invitațiile de înregistrare urmează acum serverul';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Invitațiile de înregistrare au fost forțate activate';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Invitațiile de înregistrare au fost forțate dezactivate';

  @override
  String get commentsRecordVideoButtonLabel => 'Înregistrează comentariu video';

  @override
  String get commentsOpenVideoLabel => 'Deschide comentariul video';

  @override
  String get commentsMuteVideoReplyLabel =>
      'Dezactivează sunetul răspunsului video';

  @override
  String get commentsUnmuteVideoReplyLabel =>
      'Activează sunetul răspunsului video';

  @override
  String get commentsOpenReplyParentLabel =>
      'Deschide videoclipul la care răspunde';

  @override
  String get commentsReplyParentSectionTitle => 'Ca răspuns la';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Răspuns la $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Răspuns la videoclip';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Cont $platform verificat: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Conturi verificate';

  @override
  String get profileEditGetVerifiedCta => 'Verifică-te';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Conectează-ți conturile de social media ca lumea să știe că ești tu.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Vizitează site-ul: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Nu am putut deschide site-ul';

  @override
  String get videoMetadataEditCoverTitle => 'Editează coperta';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Renunță la modificările copertei';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Folosește cadrul selectat drept copertă video';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Parcurge videoclipul pentru a selecta cadrul copertei';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Caută sau adaugă etichete';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Adaugă etichete pentru ca alții să-ți descopere videoclipul';

  @override
  String get videoMetadataTagsPickerNoResults => 'Nicio etichetă potrivită';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Adaugă „#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Încă n-ai 16 ani? E în regulă. ';

  @override
  String get authUnder16ChoicesCta => 'Iată opțiunile tale.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Iată de ce';

  @override
  String get generalSettingsHoldToRecord => 'Ține apăsat pentru a înregistra';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Înregistrarea începe când ții apăsat și se oprește când eliberezi';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri publicate pe profilul tău',
      few: '$count videoclipuri publicate pe profilul tău',
      one: 'Videoclip publicat pe profilul tău',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Trimite mesajul';

  @override
  String get emojiPickerSearchHint => 'Căutare';

  @override
  String get emojiCategoryRecent => 'Recente';

  @override
  String get emojiCategorySmileys => 'Emoticoane și persoane';

  @override
  String get emojiCategoryAnimals => 'Animale și natură';

  @override
  String get emojiCategoryFood => 'Mâncare și băutură';

  @override
  String get emojiCategoryActivities => 'Activități';

  @override
  String get emojiCategoryTravel => 'Călătorii și locuri';

  @override
  String get emojiCategoryObjects => 'Obiecte';

  @override
  String get emojiCategorySymbols => 'Simboluri';

  @override
  String get emojiCategoryFlags => 'Steaguri';

  @override
  String get videoEditorMarkerLabel => 'Marcator';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Adaugă marcator pe cronologie';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Elimină marcatorul de pe cronologie';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Elimină marcatorul de la capul de redare';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Ștergi marcatorul?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Aceasta elimină marcatorul de pe cronologie. Editarea rămâne intactă.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Dezactivați sau activați sunetul tuturor pistelor';

  @override
  String get videoEditorSplitFailed =>
      'Împărțire eșuată. Vă rugăm să încercați din nou.';

  @override
  String get videoEditEditSubtitles => 'Editează subtitrările';

  @override
  String get subtitleEditorTitle => 'Editează subtitrările';

  @override
  String get subtitleEditorSave => 'Salvează';

  @override
  String get subtitleEditorProcessing =>
      'Subtitrările sunt încă în curs de generare. Revino într-o clipă.';

  @override
  String get subtitleEditorNoSpeech =>
      'Nu s-a detectat vorbire în acest videoclip, deci nu e nimic de subtitrat.';

  @override
  String get subtitleEditorWriteOwn => 'Scrie-le tu';

  @override
  String get subtitleEditorAddCue => 'Adaugă o linie';

  @override
  String get subtitleEditorRemoveCue => 'Șterge această linie';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Videoclipul nu poate fi redat acum, dar tot poți corecta subtitrările.';

  @override
  String get subtitleEditorPlayPreview => 'Redă videoclipul';

  @override
  String get subtitleEditorPausePreview => 'Pune videoclipul pe pauză';

  @override
  String get subtitleEditorInvalidHint =>
      'Fiecare linie are nevoie de text și de un sfârșit după început.';

  @override
  String get subtitleEditorLoadError =>
      'Nu am putut încărca subtitrările. Încearcă din nou.';

  @override
  String get subtitleEditorSaveSuccess => 'Subtitrări actualizate';

  @override
  String get subtitleEditorSaveError =>
      'Nu am putut salva subtitrările. Încearcă din nou.';

  @override
  String get subtitleEditorRetry => 'Reîncearcă';

  @override
  String get subtitleEditorCueHint => 'Text de subtitrare';

  @override
  String get imageCropEditorRotateLabel => 'Rotește';

  @override
  String get imageCropEditorFlipLabel => 'Întoarce';

  @override
  String get imageCropEditorResetLabel => 'Resetează';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Anulează decuparea';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Aplică decuparea';

  @override
  String get imageCropEditorProcessing => 'Se aplică decuparea…';

  @override
  String get backgroundUploadNotificationTitle => 'Se încarcă videoclipul';

  @override
  String get monetizationSettingsTitle => 'Sprijin pentru creatori';

  @override
  String get monetizationSettingsSubtitle =>
      'Adaugă linkuri pentru bacșiș și abonament';

  @override
  String get monetizationSettingsIntroTitle => 'Doar linkuri externe';

  @override
  String get monetizationSettingsIntroBody =>
      'Adaugă destinații pe care le controlezi tu. Divine nu gestionează niciodată plata și nu deblochează conținut în aplicație prin aceste linkuri.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de linkuri active în profilul tău',
      few: '$count linkuri active în profilul tău',
      one: '1 link activ în profilul tău',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Trimite un bacșiș';

  @override
  String get monetizationSettingsSubscriptionSection => 'Abonează-te / susține';

  @override
  String get monetizationSettingsSave => 'Salvează linkurile de sprijin';

  @override
  String get monetizationSettingsSaving => 'Se salvează...';

  @override
  String get monetizationSettingsSaved =>
      'Linkurile de sprijin au fost actualizate';

  @override
  String get monetizationSettingsSaveFailed =>
      'Nu am putut salva linkurile de sprijin. Verifică conexiunea și încearcă din nou.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'Adaugă un identificator sau un URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Linkul acesta nu pare corect.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Folosește un link pentru acest furnizor.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag sau link cash.app';

  @override
  String get monetizationSettingsHintPayPal =>
      'Identificator sau link PayPal.me';

  @override
  String get monetizationSettingsHintVenmo => 'Identificator sau link Venmo';

  @override
  String get monetizationSettingsHintPatreon =>
      'Identificator sau link Patreon';

  @override
  String get monetizationSettingsHintSubstack => 'Domeniu sau link Substack';

  @override
  String get monetizationSettingsHintMedium => 'Identificator sau link Medium';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Identificator sau link Open Collective';

  @override
  String get profileSupportSheetTitle => 'Susține acest creator';

  @override
  String get profileSupportSheetBody =>
      'Aceste linkuri se deschid în afara Divine. Nimic de aici nu deblochează conținut în aplicație.';

  @override
  String get profileSupportTipSection => 'Trimite un bacșiș';

  @override
  String get profileSupportSubscriptionSection => 'Abonează-te / susține';

  @override
  String get profileSupportButtonLabel => 'Susține';

  @override
  String get monetizationTipsSettingsTitle => 'Bacșișuri';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Adaugă linkuri opționale pentru bacșiș';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Doar bacșișuri opționale';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Bacșișurile sunt cadouri opționale între utilizatori. Ele nu deblochează conținut, abonamente, funcții, clasare, vizibilitate sau acces în Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de linkuri active pentru bacșiș în profilul tău',
      few: '$count linkuri active pentru bacșiș în profilul tău',
      one: '1 link activ pentru bacșiș în profilul tău',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Salvează linkurile pentru bacșiș';

  @override
  String get monetizationTipsSettingsSaved =>
      'Linkurile pentru bacșiș au fost actualizate';

  @override
  String get profileTipButtonLabel => 'Bacșiș';

  @override
  String get profileTipSheetTitle => 'Dă bacșiș acestui creator';

  @override
  String get profileTipSheetBody =>
      'Linkurile pentru bacșiș se deschid în afara Divine. Sunt opționale și nu deblochează conținut, abonamente, funcții sau acces în Divine.';

  @override
  String get settingsStorageTitle => 'Stocare';

  @override
  String get settingsStorageCacheSectionTitle => 'Media din cache';

  @override
  String get settingsStorageCacheDescription =>
      'Videoclipuri din feed, miniaturi și randări temporare din cache. Ștergerea lor este sigură – sunt descărcate sau regenerate din nou când e nevoie.';

  @override
  String get settingsStorageMeasuring => 'Se calculează…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size utilizați';
  }

  @override
  String get settingsStorageClearButton => 'Golește cache-ul';

  @override
  String get settingsStorageClearConfirmTitle => 'Golești media din cache?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Astfel eliberezi $size. Biblioteca ta de clipuri nu este afectată.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Golește';

  @override
  String get settingsStorageCleared => 'Cache golit';

  @override
  String get settingsStorageLibrarySectionTitle => 'Bibliotecă de clipuri';

  @override
  String get settingsStorageLibraryDescription =>
      'Caută clipuri deteriorate al căror fișier video lipsește.';

  @override
  String get settingsStorageScanButton => 'Verifică biblioteca';

  @override
  String get settingsStorageLibraryHealthy =>
      'Nu s-au găsit clipuri deteriorate';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Clipuri deteriorate găsite: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton =>
      'Elimină clipurile deteriorate';

  @override
  String get settingsStorageBrokenClipsRemoved =>
      'Clipuri deteriorate eliminate';

  @override
  String get settingsStorageError => 'Ceva n-a mers bine';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Cache video maxim';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count videoclipuri';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Elimini clipurile deteriorate?';

  @override
  String get settingsStorageRepairSectionTitle => 'Repară instalarea';

  @override
  String get settingsStorageRepairDescription =>
      'Dacă aplicația se blochează sau se comportă ciudat, resetarea datelor locale rezolvă de obicei. Clipurile și schițele tale rămân.';

  @override
  String get settingsStorageRepairButton => 'Resetează datele aplicației';

  @override
  String get settingsStorageRepairConfirmTitle => 'Resetezi datele aplicației?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Asta șterge datele din feed salvate în cache și fișierele temporare. Clipurile, schițele, setările și contul tău conectat rămân, dar va trebui să repornești aplicația după.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return 'Se vor șterge $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Resetează';

  @override
  String get settingsStorageRepairInProgress => 'Se resetează…';

  @override
  String get settingsStorageRepairSuccess =>
      'Gata — repornește aplicația ca să finalizezi.';

  @override
  String get settingsStorageRepairFailure =>
      'Nu s-a putut reseta tot. Încearcă din nou după o repornire.';

  @override
  String get nostrSettingsSignatureVerification => 'Verificarea semnăturii';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Alege când Divine verifică semnăturile evenimentelor de pe relee. ID-urile evenimentelor sunt validate întotdeauna primele.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Toate releele';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Cel mai sigur. Verifică semnătura fiecărui eveniment de pe releu.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => 'Relee nesigure';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Sari peste verificări pentru releele deja aflate în pool-ul tău configurat.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Relee non-Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Ai încredere în releele Divine, verifică restul.';

  @override
  String get settingsCrosspostingTitle => 'Crosspostare';

  @override
  String get settingsCrosspostingSubtitle =>
      'Partajează-ți videoclipurile pe alte platforme';

  @override
  String get crosspostingSignInRequired =>
      'Conectează-te cu Divine ca să gestionezi crosspostarea';

  @override
  String get crosspostingLoadFailed =>
      'Nu am putut încărca setările tale de crosspostare';

  @override
  String get crosspostingNoPlatforms =>
      'Momentan nu e disponibilă nicio platformă de crosspostare';

  @override
  String get crosspostingRetry => 'Reîncearcă';

  @override
  String get crosspostingNotConnected => 'Neconectat';

  @override
  String get crosspostingConnected => 'Conectat';

  @override
  String get crosspostingNeedsReconnect => 'Necesită reconectare';

  @override
  String get crosspostingConnect => 'Conectează';

  @override
  String get crosspostingReconnect => 'Reconectează';

  @override
  String get crosspostingDisconnect => 'Deconectează';

  @override
  String get crosspostingModeOff => 'Dezactivat';

  @override
  String get crosspostingModeManual => 'Manual';

  @override
  String get crosspostingModeManualSubtitle =>
      'Alegi tu pentru fiecare videoclip';

  @override
  String get crosspostingModeAutomatic => 'Automat';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Videoclipurile viitoare se publică singure — doar cele publicate după ce activezi asta';

  @override
  String get crosspostingNotConnectedError =>
      'Conectează întâi platforma asta ca să schimbi felul în care postează.';

  @override
  String get crosspostingGenericError => 'Ceva n-a mers. Mai încearcă.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Pagina de conectare nu ne-a mai răspuns. Dacă ai terminat acolo, reîmprospătează — s-ar putea ca deja contul tău să fie conectat.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform conectat';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Nu am putut conecta $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Conexiunea a fost anulată pe $platform';
  }

  @override
  String get supporterTitle => 'Susținătorii Divine';

  @override
  String get supporterTileSubtitle =>
      'Susține Divine cu un abonament lunar opțional.';

  @override
  String get supporterHeroTitle => 'Ține Divine pe picioare';

  @override
  String get supporterHeroBody =>
      'Divine e gratuit și așa va rămâne. Dacă vrei să ne ajuți să menținem buclele în mișcare, devino susținător lunar. Nimic nu e blocat — pur și simplu ține luminile aprinse și îți câștigă mulțumirile noastre.';

  @override
  String get supporterActiveBadge =>
      'Ești Susținător Divine. Mulțumim că ții asta în mișcare.';

  @override
  String get supporterPurchasePending => 'Cumpărătura ta așteaptă aprobare.';

  @override
  String get supporterPurchaseConfirming => 'Se confirmă sprijinul tău…';

  @override
  String get supporterStoreChecking => 'Se verifică magazinul…';

  @override
  String get supporterUnavailable =>
      'Abonamentele de susținător nu sunt disponibile aici momentan.';

  @override
  String get supporterRestorePurchases => 'Restaurează cumpărăturile';

  @override
  String get supporterDismissError => 'Închide eroarea';

  @override
  String get supporterErrorStoreUnavailable =>
      'Magazinul nu e disponibil pe acest dispozitiv.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Cumpărătura nu s-a finalizat. Nu ți s-a perceput nicio sumă.';

  @override
  String get supporterErrorPurchasePending =>
      'Cumpărătura ta așteaptă aprobare.';

  @override
  String get supporterErrorRestoreFailed =>
      'Nu s-a găsit niciun abonament de susținător de restaurat.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Această cumpărătură aparține altui cont Divine.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine nu a putut confirma statutul de susținător momentan.';

  @override
  String get supporterErrorUnknown => 'Ceva nu a mers bine. Încearcă din nou.';

  @override
  String get supporterDisclaimer =>
      'Divine confirmă statutul de susținător după ce magazinul îți verifică cumpărătura. Recunoașterea e opțională, iar haloul nu e o verificare.';

  @override
  String get profileNotifyBellOff => 'Anunță-mă despre videoclipuri noi';

  @override
  String get profileNotifyBellOn => 'Nu mă mai anunța despre videoclipuri noi';

  @override
  String get profileNotifyUpdateFailed => 'Nu s-a salvat. Reîncerci?';

  @override
  String get savedSoundYourLabel => 'Eticheta ta';

  @override
  String get savedSoundAddHashtags => 'Adaugă hashtaguri';

  @override
  String get savedSoundDeviceOnly => 'Salvat pe acest dispozitiv';

  @override
  String get savedSoundDetailsRetry =>
      'Nu am putut salva aceste detalii. Atinge pentru a reîncerca.';

  @override
  String get savedSoundFallbackTitle => 'Sunet salvat';

  @override
  String get savedSoundPreviewAction => 'Ascultă sunetul';

  @override
  String get savedSoundEditAction => 'Editează detaliile sunetului';

  @override
  String get savedSoundRemoveAction => 'Elimină sunetul salvat';

  @override
  String get savedSoundClearHashtagFilter => 'Șterge filtrul de hashtaguri';

  @override
  String get soundAllowRemix => 'Permite altora să remixeze acest sunet';

  @override
  String get soundReuseUnavailable => 'Acest sunet nu poate fi remixat acum.';

  @override
  String get soundPublicCredit => 'Credit public pentru sunet';

  @override
  String get soundCreditRequired =>
      'Adaugă credit public pentru sunet înainte de a posta.';

  @override
  String get soundSharedAs => 'Partajat ca';

  @override
  String get soundOwnWork => 'Eu am creat acest sunet';

  @override
  String soundCreatorBy(String creator) {
    return 'De $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Partajat de $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remixarea e permisă';

  @override
  String get soundCreditOnly => 'Doar credit';

  @override
  String get soundCreditTitleLabel => 'Titlul sunetului';

  @override
  String get soundCreditCreatorLabel => 'Creator';

  @override
  String get soundCreditSourceUrlLabel => 'URL sursă';

  @override
  String get soundCreditPublicHashtagsLabel => 'Hashtaguri publice';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Anulează selectarea etichetelor';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Aplică etichetele selectate';

  @override
  String get userPickerCancelSemanticLabel =>
      'Anulează selectarea utilizatorilor';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Confirmă utilizatorii selectați';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Șterge selecția utilizatorilor';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Anulează selectarea avertismentelor de conținut';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Aplică avertismentele de conținut selectate';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Închide editorul video';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Continuă la detaliile postării';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Renunță la modificările din $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Aplică modificările din $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Elimină sunetul';

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
  String get verifyTitle => 'Conturi verificate';

  @override
  String get verifySignedOutMessage =>
      'Conectează-te ca să îți legi conturile.';

  @override
  String get verifyIntro =>
      'Leagă conturile pe care le ai deja, ca lumea să vadă că ești chiar tu.';

  @override
  String get verifyLoadFailed => 'Nu am putut încărca legăturile tale.';

  @override
  String get verifyRetry => 'Încearcă din nou';

  @override
  String get verifyLinkedSectionTitle => 'Legate';

  @override
  String get verifyVerifierUnreachable =>
      'Verificatorul nu a răspuns, așa că toate apar ca neverificate.';

  @override
  String get verifyAddSectionTitle => 'Adaugă un cont';

  @override
  String get verifyAllPlatformsLinked => 'Ai legat tot ce acceptăm.';

  @override
  String get verifyStatusVerified => 'Verificat';

  @override
  String get verifyStatusUnverified => 'Neverificat';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Dezleagă contul $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Dezlegi $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity nu va mai apărea pe profilul tău. Îl poți lega din nou mai târziu, dar va trebui să te autentifici sau să postezi o dovadă nouă.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Dezleagă';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Leagă contul tău de $platform';
  }

  @override
  String get verifyOneTapBadge => 'Un tap';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Conectează-te la $platform și ne ocupăm noi de rest. Nu se postează nimic.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Continuă cu $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Sau postează o dovadă';

  @override
  String get verifyConnectProofExplainer =>
      'Postează-ți npub-ul pe cont, apoi lipește linkul către acea postare.';

  @override
  String get verifyNpubLabel => 'npub-ul tău';

  @override
  String get verifyCopyNpubSemanticLabel => 'Copiază npub-ul tău';

  @override
  String get verifyNpubCopied => 'npub copiat';

  @override
  String get verifyIdentityLabel => 'Numele contului';

  @override
  String get verifyProofLabel => 'Linkul postării tale';

  @override
  String get verifyConnectProofCta => 'Verifică și leagă';

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
      'Verificatorul nu răspunde. Mai încearcă într-o clipă.';

  @override
  String get verifyErrorOauthFailed => 'N-a mers. Mai încearcă o dată.';

  @override
  String get verifyErrorHandleRequired => 'Scrie mai întâi handle-ul tău.';

  @override
  String get verifyErrorPublishFailed =>
      'Verificat, dar niciun releu nu a acceptat actualizarea. Mai încearcă.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Conectarea dintr-un tap nu e încă pregătită aici. Folosește dovada de mai jos.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Fă un gist public cu npub-ul tău în primul fișier și lipește linkul gist-ului.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Postează-ți npub-ul într-un canal Discord pe care botul nostru îl poate citi și lipește linkul mesajului. O invitație de server nu dovedește nimic.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Postează-ți npub-ul de pe acel cont și lipește linkul tweetului.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Postează-ți npub-ul de pe acel cont și lipește linkul. Numele contului are nevoie de instanță — mastodon.social/@alice, nu doar alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Se leagă canalul, nu contul tău de Telegram. Are nevoie întâi de un link public (Telegram le creează private). Postează-ți acolo npub-ul și lipește linkul mesajului.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Te-ai conectat mai sus? Nu mai e nevoie de nimic. Altfel postează-ți npub-ul și lipește linkul postării.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Pune-ți npub-ul în descrierea unui video și lipește linkul acelui video.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Pune-ți npub-ul în descrierea unui video și lipește linkul acelui video.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform este legat.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Acela e un canal privat sau o invitație. Dă-i canalului un link public, apoi lipește linkul mesajului.';

  @override
  String get verifyErrorRemoveFailed => 'Nu am putut dezlega. Mai încearcă.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Nu am putut citi legăturile tale actuale, așa că nu s-a schimbat nimic. Verifică-ți conexiunea și mai încearcă.';

  @override
  String get verifyChannelLabel => 'Numele canalului';

  @override
  String get verifyHowItWorksTitle => 'Cum funcționează?';

  @override
  String get verifyHowItWorksIntro =>
      'Gândește-te la asta ca la o strângere de mână între două conturi:';

  @override
  String get verifyHowItWorksYourSide =>
      'Profilul tău Divine spune: „Sunt @alice pe Twitter”.';

  @override
  String get verifyHowItWorksOtherSide =>
      'Contul tău de Twitter confirmă: „Da, acel profil Divine e al meu”.';

  @override
  String get verifyHowItWorksBothSides =>
      'Verificăm ambele părți. Dacă se potrivesc, ești verificat. Nu se poate falsifica: numele și poza se copiază, postarea de pe contul tău real nu.';

  @override
  String get verifyHowItWorksOwnership =>
      'Legăturile stau pe propria ta identitate Nostr, așa că le poți șterge de aici oricând.';

  @override
  String get generalSettingsSectionIdentity => 'Identitate';

  @override
  String get libraryFilterAll => 'Toate';

  @override
  String get libraryFilterArchive => 'Arhivă';

  @override
  String get libraryFilterDeleted => 'Șterse';

  @override
  String get libraryCategoryNewChipLabel => 'Nouă';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Creează o categorie';

  @override
  String get libraryCategoryCreateTitle => 'Categorie nouă';

  @override
  String get libraryCategoryCreateAction => 'Creează';

  @override
  String get libraryCategoryRenameTitle => 'Redenumește categoria';

  @override
  String get libraryCategoryRenameAction => 'Redenumește';

  @override
  String get libraryCategoryDeleteAction => 'Șterge categoria';

  @override
  String get libraryCategoryNameLabel => 'Numele categoriei';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Ștergi „$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Clipurile tale rămân. Se întorc doar în Toate.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Redenumește sau șterge această categorie';

  @override
  String get libraryCategoryMoveTitle => 'Mută în';

  @override
  String get libraryCategoryMoveNone => 'Fără categorie';

  @override
  String get libraryCategoryMoveNewCategory => 'Categorie nouă';

  @override
  String get libraryArchiveAction => 'Arhivează';

  @override
  String get libraryUnarchiveAction => 'Dezarhivează';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Păstrezi în aceste categorii?',
      one: 'Păstrezi în această categorie?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Păstrează în $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'Păstrează în categoriile lor';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Scoate din $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Scoate din categoriile lor';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Mută clipurile selectate';

  @override
  String get libraryCategoryEmptyTitle => 'Încă nu e nimic aici';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Alege câteva clipuri și mută-le în această categorie.';

  @override
  String get libraryArchiveEmptyTitle => 'Nimic arhivat';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Clipurile arhivate așteaptă aici, în afara bibliotecii principale.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de clipuri mutate în $name',
      few: '$count clipuri mutate în $name',
      one: '1 clip mutat în $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de clipuri scoase din categorie',
      few: '$count clipuri scoase din categorie',
      one: '1 clip scos din categorie',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de clipuri arhivate',
      few: '$count clipuri arhivate',
      one: '1 clip arhivat',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de clipuri înapoi în bibliotecă',
      few: '$count clipuri înapoi în bibliotecă',
      one: '1 clip înapoi în bibliotecă',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Schimbă e-mailul';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Mută-ți contul pe altă adresă';

  @override
  String get accountSettingsChangePassword => 'Schimbă parola';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Alege o parolă nouă pentru autentificare';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Sesiunea a expirat. Autentifică-te din nou ca să faci schimbarea.';

  @override
  String get accountCredentialsRateLimited =>
      'Prea multe încercări. Așteaptă câteva minute.';

  @override
  String get accountCredentialsNetwork =>
      'Nu am putut ajunge la Divine. Verifică-ți conexiunea și încearcă din nou.';

  @override
  String get accountCredentialsUnknown => 'N-a mers. Încearcă din nou.';

  @override
  String get changePasswordSubtitle =>
      'Scrie parola actuală, apoi alege una nouă.';

  @override
  String get changePasswordCurrentLabel => 'Parola actuală';

  @override
  String get changePasswordWrongCurrent => 'Asta nu e parola ta actuală.';

  @override
  String get changePasswordSuccess => 'Parolă schimbată.';

  @override
  String get changeEmailSubtitle =>
      'Trimitem un link de confirmare la noua adresă și la cea din contul tău. E-mailul se schimbă după ce confirmi din ambele.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'În contul tău: $email';
  }

  @override
  String get changeEmailNewLabel => 'E-mail nou';

  @override
  String get changeEmailPasswordLabel => 'Parola ta';

  @override
  String get changeEmailSameAsCurrent => 'Asta e deja adresa ta de e-mail.';

  @override
  String get changeEmailWrongPassword => 'Asta nu e parola ta.';

  @override
  String get changeEmailSubmit => 'Trimite linkurile de confirmare';

  @override
  String get changeEmailSentTitle => 'Două linkuri sunt pe drum';

  @override
  String changeEmailSentMessage(String email) {
    return 'Confirmă din $email și din adresa contului tău. E-mailul se schimbă după ce le faci pe amândouă.';
  }

  @override
  String get changeEmailSentExpiry => 'Linkurile expiră după 24 de ore.';

  @override
  String get changeEmailSentDone => 'Am înțeles';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount videoclipuri',
      one: '$formattedCount videoclip',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Reciproc';

  @override
  String get socialProofFollowsYou => 'Te urmărește';

  @override
  String get socialProofYouFollow => 'Urmărești';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount urmăritori',
      one: '$formattedCount urmăritor',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Videoclipurile nu se încarcă acum.\nE de la noi, nu de la tine — lucrăm la asta.';

  @override
  String get feedOfflineMessage =>
      'Ești offline.\nVerifică-ți conexiunea și încearcă din nou.';

  @override
  String get dbFailureTitle => 'nu am putut debloca baza de date locală';

  @override
  String get dbFailureAdviceResettable =>
      'O repornire nu rezolvă asta. Resetarea bazei de date locale de mai jos îi oferă lui Divine un start curat — contul tău rămâne.';

  @override
  String get dbFailureAdviceRestart =>
      'Repornește Divine după ce îți deblochezi dispozitivul. Dacă se repetă, actualizează aplicația sau contactează asistența.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Încearcă să repornești Divine o dată. Dacă problema continuă, actualizează aplicația sau contactează asistența. Datele tale locale sunt încă aici.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostic: $code';
  }

  @override
  String get dbFailureCloseApp => 'închide Divine';

  @override
  String get dbFailureResetAction => 'resetează baza de date locală';

  @override
  String get dbFailureConfirmTitle => 'resetezi baza de date locală?';

  @override
  String get dbFailureConfirmBody =>
      'Contul tău rămâne. Ciornele și clipurile salvate pe acest dispozitiv sunt șterse — mesajele și fluxurile revin din rețea.';

  @override
  String get dbFailureResetConfirm => 'resetează acum baza de date locală';

  @override
  String get dbFailureCancel => 'anulează';

  @override
  String get dbFailureResetFailed =>
      'Nu a funcționat. Închide Divine și încearcă din nou.';

  @override
  String get dbFailureResetDoneTitle => 'baza de date locală a fost resetată';

  @override
  String get dbFailureResetDoneBody =>
      'Închide Divine și deschide-l din nou — următoarea pornire creează o bază de date locală nouă.';

  @override
  String get authSignInOptionsInfo => 'Despre opțiunile de conectare';

  @override
  String get authShowPassword => 'Afișați parola';

  @override
  String get authHidePassword => 'Ascundeți parola';

  @override
  String get followUserSemanticLabel => 'Urmărește utilizatorul';

  @override
  String get unfollowUserSemanticLabel => 'Nu mai urmări utilizatorul';

  @override
  String get commentsLoadingSemanticLabel => 'Se încarcă comentariile';

  @override
  String get analyticsWindowAll => 'Tot';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Urmărește utilizatorul $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Nu mai urmări utilizatorul $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / lună';
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
  String get updateGentleBanner => 'A apărut o actualizare nouă. Descoper-o →';

  @override
  String get updateModerateTitle =>
      'Există o actualizare de la ultima verificare';

  @override
  String get updateUrgentTitle => 'Îți lipsesc remedieri importante';

  @override
  String get updateNotNow => 'Nu acum';

  @override
  String get updateAction => 'Actualizează';

  @override
  String updateNewIn(String version) {
    return 'Noutăți în $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Actualizare disponibilă';
}

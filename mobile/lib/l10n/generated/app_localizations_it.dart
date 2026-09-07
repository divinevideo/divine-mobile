// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Recupero clip';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Trova registrazioni salvate con un altro account e file video a cui nessuna voce fa più riferimento.';

  @override
  String get devOptionsClipRecoveryScan => 'Analizza';

  @override
  String get devOptionsClipRecoveryFailure =>
      'Ripristino delle clip non riuscito';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips clip',
      one: '$clips clip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts bozze',
      one: '$drafts bozza',
    );
    return 'Visibili ora: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts =>
      'Nascosti sotto altri account';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips clip',
      one: '$clips clip',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts bozze',
      one: '$drafts bozza',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Sposta in questo account';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'File non referenziati: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Ricostruisci nella libreria';

  @override
  String get devOptionsClipRecoveryEmpty => 'Nulla da recuperare';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip recuperate',
      one: '$count clip recuperata',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Rapporto di recupero copiato';

  @override
  String get devOptionsStorageFootprint => 'Spazio occupato';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Ogni cartella in cui l\'app scrive. Svuotare la cache ne libera solo una parte.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Misura';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Totale: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied =>
      'Report di archiviazione copiato';

  @override
  String get devOptionsStorageFootprintFailure =>
      'Impossibile misurare lo spazio';

  @override
  String get feedTuningMoreLabel => 'Più contenuti così';

  @override
  String get feedTuningLessLabel => 'Meno contenuti così';

  @override
  String get feedTuningUndo => 'Annulla';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Apri il video di riferimento';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsSecureAccount => 'Metti al sicuro il tuo account';

  @override
  String get settingsSessionExpired => 'Sessione scaduta';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Accedi di nuovo per ripristinare l\'accesso completo';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Statistiche creator';

  @override
  String get settingsSupportCenter => 'Centro assistenza';

  @override
  String get settingsNotifications => 'Notifiche';

  @override
  String get settingsBlueskyPublishing => 'Pubblicazione su Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gestisci il crosspost su Bluesky';

  @override
  String get settingsNostrSettings => 'Impostazioni Nostr';

  @override
  String get settingsIntegratedApps => 'App integrate';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'App di terze parti approvate che girano dentro Divine';

  @override
  String get settingsExperimentalFeatures => 'Funzionalità sperimentali';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Chicche che potrebbero fare le bizze—provale se sei curioso.';

  @override
  String get settingsLegal => 'Legale';

  @override
  String get settingsIntegrationPermissions => 'Permessi di integrazione';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Controlla e revoca le approvazioni di integrazione salvate';

  @override
  String settingsVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get settingsVersionEmpty => 'Versione';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'La modalità sviluppatore è già attiva';

  @override
  String get settingsDeveloperModeEnabled => 'Modalità sviluppatore attivata!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Altri $count tap per attivare la modalità sviluppatore';
  }

  @override
  String get settingsShareDivine => 'Condividi Divine con i tuoi amici';

  @override
  String get settingsSwitchAccount => 'Cambia account';

  @override
  String get settingsAddAnotherAccount => 'Aggiungi un altro account';

  @override
  String get settingsAccountSwitchFailed =>
      'Impossibile cambiare account. Riprova.';

  @override
  String get settingsUnsavedDraftsTitle => 'Bozze non salvate';

  @override
  String get settingsUploadInProgressTitle => 'Caricamento in corso';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'video',
      one: 'video',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'i tuoi video restano come bozze',
      one: 'il tuo video resta come bozza',
    );
    return 'Hai ancora $count $_temp0 in caricamento. Cambiare account interrompe il caricamento: $_temp1 in questo account.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bozze non salvate',
      one: 'bozza non salvata',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'le tue bozze verranno mantenute',
      one: 'la tua bozza verrà mantenuta',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pubblicarle o rivederle',
      one: 'pubblicarla o rivederla',
    );
    return 'Hai $count $_temp0. Cambiando account $_temp1, ma potresti voler $_temp2 prima.';
  }

  @override
  String get settingsCancel => 'Annulla';

  @override
  String get settingsSwitchAnyway => 'Cambia comunque';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'La sessione di quell\'account è scaduta. Accedere di nuovo significa uscire da quello che stai usando ora.';

  @override
  String get settingsAppVersionLabel => 'Versione dell\'app';

  @override
  String get settingsAppLanguage => 'Lingua dell\'app';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (predefinita del dispositivo)';
  }

  @override
  String get settingsAppLanguageTitle => 'Lingua dell\'app';

  @override
  String get settingsAppLanguageDescription =>
      'Scegli la lingua dell\'interfaccia dell\'app';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Usa la lingua del dispositivo';

  @override
  String get settingsGeneralTitle => 'Impostazioni generali';

  @override
  String get settingsContentSafetyTitle => 'Contenuti e sicurezza';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRAZIONI';

  @override
  String get generalSettingsSectionViewing => 'VISUALIZZAZIONE';

  @override
  String get generalSettingsSectionCreating => 'CREAZIONE';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get appearanceSettingsTitle => 'Aspetto';

  @override
  String get appearanceSettingsSubtitle =>
      'Scegli come appare Divine su questo dispositivo';

  @override
  String get appearanceSettingsSystem => 'Predefinito di sistema';

  @override
  String get appearanceSettingsLight => 'Chiaro';

  @override
  String get appearanceSettingsDark => 'Scuro';

  @override
  String get generalSettingsClosedCaptions => 'Sottotitoli';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Mostra i sottotitoli quando i video li includono';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Solo video quadrati';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Mantieni i feed nel classico formato quadrato';

  @override
  String get contentPreferencesTitle => 'Preferenze contenuti';

  @override
  String get contentPreferencesContentFilters => 'Filtri contenuti';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gestisci i filtri per gli avvisi sui contenuti';

  @override
  String get contentPreferencesContentLanguage => 'Lingua dei contenuti';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (predefinita del dispositivo)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Etichetta i tuoi video con una lingua così chi guarda può filtrare i contenuti.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Usa la lingua del dispositivo (predefinita)';

  @override
  String get contentPreferencesAudioSharing =>
      'Rendi disponibile il mio audio per il riutilizzo';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Quando attivo, altri possono usare l\'audio dei tuoi video';

  @override
  String get contentPreferencesMusicMode => 'Modalità musica';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Disattiva la pulizia del rumore che schiaccia gli strumenti. Meglio per la musica, più ruvido sulle voci.';

  @override
  String get contentPreferencesAccountLabels => 'Etichette account';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Auto-etichetta i tuoi contenuti';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etichette contenuti dell\'account';

  @override
  String get contentPreferencesClearAll => 'Cancella tutto';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Seleziona tutto ciò che vale per il tuo account';

  @override
  String get contentPreferencesDoneNoLabels => 'Fatto (nessuna etichetta)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Fatto ($count selezionate)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Dispositivo di ingresso audio';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (consigliato)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Seleziona automaticamente il microfono migliore';

  @override
  String get contentPreferencesSelectAudioInput => 'Seleziona ingresso audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Microfono sconosciuto';

  @override
  String get contentFiltersAdultContent => 'CONTENUTI PER ADULTI';

  @override
  String get contentFiltersViolenceGore => 'VIOLENZA E SCENE CRUENTE';

  @override
  String get contentFiltersSubstances => 'SOSTANZE';

  @override
  String get contentFiltersOther => 'ALTRO';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifica la tua età in Sicurezza e privacy per sbloccare i filtri sui contenuti per adulti';

  @override
  String get contentFiltersShow => 'Mostra';

  @override
  String get contentFiltersWarn => 'Avvisa';

  @override
  String get contentFiltersFilterOut => 'Filtra';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Questo account non è disponibile';

  @override
  String get profileInvalidId => 'ID profilo non valido';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Dai un\'occhiata a $displayName su Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName su Divine';
  }

  @override
  String get profileShareFailed =>
      'Impossibile condividere il profilo. Riprova.';

  @override
  String get profileCopyPublicKey => 'Copia chiave pubblica (npub)';

  @override
  String get profileGetEmbedCode => 'Ottieni codice embed';

  @override
  String get profilePublicKeyCopied => 'Chiave pubblica copiata negli appunti';

  @override
  String get profileEmbedCodeCopied => 'Codice embed copiato negli appunti';

  @override
  String get profileMoreTooltip => 'Altro';

  @override
  String get profileMoreSemanticLabel => 'Altre opzioni';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Chiudi avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Chiudi anteprima avatar';

  @override
  String get profileFollowingLabel => 'Segui già';

  @override
  String get profileFollowLabel => 'Segui';

  @override
  String get profileBlockedLabel => 'Bloccato';

  @override
  String get profileFollowersLabel => 'Follower';

  @override
  String get profileFollowingStatLabel => 'Seguiti';

  @override
  String get profileVideosLabel => 'Video';

  @override
  String get profileCollabsLabel => 'Collab';

  @override
  String get profileLikedLabel => 'Piaciuti';

  @override
  String get profileRepostsLabel => 'Repost';

  @override
  String get profileListsLabel => 'Liste';

  @override
  String get profileCommentsLabel => 'Commenti';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inviti a collaborare devono ancora essere inviati',
      one: '1 invito a collaborare deve ancora essere inviato',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Abbiamo messo l\'invito in coda. Riprova qui.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Per \"$title\". Riprova qui.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Riprova';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Nuovo tentativo';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Il nuovo invio degli inviti a collaborare non è disponibile al momento.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inviti a collaborare devono ancora essere inviati.',
      one: '1 invito a collaborare deve ancora essere inviato.',
      zero: 'Inviti a collaborare inviati.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaboratori non possono ricevere inviti.',
      one: '1 collaboratore non può ricevere inviti.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count utenti';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Bloccare $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Quando blocchi un utente:';

  @override
  String get profileBlockBulletHidePosts =>
      'I suoi post non appariranno nei tuoi feed.';

  @override
  String get profileBlockBulletCantView =>
      'Non potrà vedere il tuo profilo, seguirti o vedere i tuoi post.';

  @override
  String get profileBlockBulletNoNotify =>
      'Non verrà avvisato di questo cambiamento.';

  @override
  String get profileBlockBulletYouCanView =>
      'Tu potrai comunque vedere il suo profilo.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Blocca $displayName';
  }

  @override
  String get profileCancelButton => 'Annulla';

  @override
  String get profileLearnMore => 'Scopri di più';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Sbloccare $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Quando sblocchi questo utente:';

  @override
  String get profileUnblockBulletShowPosts =>
      'I suoi post appariranno nei tuoi feed.';

  @override
  String get profileUnblockBulletCanView =>
      'Potrà vedere il tuo profilo, seguirti e vedere i tuoi post.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Non verrà avvisato di questo cambiamento.';

  @override
  String get profileLearnMoreAt => 'Scopri di più su ';

  @override
  String get profileUnblockButton => 'Sblocca';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Smetti di seguire $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Blocca $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Sblocca $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Segnala $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Aggiungi $displayName a una lista';
  }

  @override
  String get profileNoCollabsTitle => 'Ancora nessuna collab';

  @override
  String get profileCollabsOwnEmpty =>
      'I video a cui collabori appariranno qui';

  @override
  String get profileCollabsOtherEmpty =>
      'I video a cui collabora appariranno qui';

  @override
  String get profileErrorLoadingCollabs =>
      'Errore nel caricamento dei video collab';

  @override
  String get profileNoSavedVideosTitle => 'Ancora niente di salvato';

  @override
  String get profileSavedOwnEmpty =>
      'Aggiungi i video ai segnalibri dal menu di condivisione e li troverai qui.';

  @override
  String get profileErrorLoadingSaved =>
      'Errore nel caricamento dei video salvati';

  @override
  String get profileNoCommentsOwnTitle => 'Ancora nessun commento';

  @override
  String get profileNoCommentsOtherTitle => 'Nessun commento';

  @override
  String get profileCommentsOwnEmpty =>
      'I tuoi commenti e le tue risposte appariranno qui';

  @override
  String get profileCommentsOtherEmpty =>
      'I suoi commenti e le sue risposte appariranno qui';

  @override
  String get profileErrorLoadingComments =>
      'Errore nel caricamento dei commenti';

  @override
  String get profileVideoRepliesSection => 'Video risposte';

  @override
  String get profileCommentsSection => 'Commenti';

  @override
  String get profileEditLabel => 'Modifica';

  @override
  String get profileLibraryLabel => 'Libreria';

  @override
  String get profileNoLikedVideosTitle => 'Ancora nessun video piaciuto';

  @override
  String get profileLikedOwnEmpty => 'I video che ti piacciono appariranno qui';

  @override
  String get profileLikedOtherEmpty =>
      'I video che gli piacciono appariranno qui';

  @override
  String get profileErrorLoadingLiked =>
      'Errore nel caricamento dei video piaciuti';

  @override
  String get profileNoRepostsTitle => 'Ancora nessun repost';

  @override
  String get profileRepostsOwnEmpty =>
      'I video che ripubblichi appariranno qui';

  @override
  String get profileRepostsOtherEmpty =>
      'I video che ripubblica appariranno qui';

  @override
  String get profileErrorLoadingReposts =>
      'Errore nel caricamento dei video ripubblicati';

  @override
  String get profileNoVideosTitle => 'Ancora nessun video';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Condividi il tuo primo video per vederlo qui';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Questo utente non ha ancora condiviso video';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatura video $number';
  }

  @override
  String get profileShowMore => 'Mostra di più';

  @override
  String get profileShowLess => 'Mostra di meno';

  @override
  String get dmMessageDisplayLimitReached =>
      'Il resto di questo messaggio non viene mostrato.';

  @override
  String get profileCompleteYourProfile => 'Completa il tuo profilo';

  @override
  String get profileCompleteSubtitle =>
      'Aggiungi nome, bio e foto per iniziare';

  @override
  String get profilePleaseTryAgain => 'Riprova';

  @override
  String get profileSecureYourAccount => 'Metti al sicuro il tuo account';

  @override
  String get profileSecureSubtitle =>
      'Aggiungi email e password per recuperare il tuo account su qualsiasi dispositivo';

  @override
  String get profileRetryButton => 'Riprova';

  @override
  String get profileSessionExpired => 'Sessione scaduta';

  @override
  String get profileSignInToRestore =>
      'Accedi di nuovo per ripristinare l\'accesso completo';

  @override
  String get profileSignInButton => 'Accedi';

  @override
  String get profileMaybeLaterLabel => 'Forse più tardi';

  @override
  String get profileSecurePrimaryButton => 'Aggiungi email e password';

  @override
  String get profileCompletePrimaryButton => 'Aggiorna il tuo profilo';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Mi piace';

  @override
  String get profileMyLibraryLabel => 'La mia libreria';

  @override
  String get profileMessageLabel => 'Messaggio';

  @override
  String get profileShareLabel => 'Condividi profilo';

  @override
  String get profileDeletedAccountName => 'Account eliminato';

  @override
  String get inboxActionReportVanishedAccount => 'Segnala questo account';

  @override
  String get inboxActionBlockVanishedAccount => 'Blocca questo account';

  @override
  String get inboxActionUnblockVanishedAccount => 'Sblocca questo account';

  @override
  String get inboxReportedVanishedAccount => 'Questo account è stato segnalato';

  @override
  String get inboxBlockedVanishedAccount => 'Questo account è stato bloccato';

  @override
  String get inboxUnblockedVanishedAccount =>
      'Questo account è stato sbloccato';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Questo rimuove la conversazione dalla tua posta in arrivo. Se ti scrive di nuovo, inizia una nuova conversazione.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Questo account è stato eliminato';

  @override
  String get profileUserFallback => 'utente';

  @override
  String get profileLinkCopied => 'Link del profilo copiato';

  @override
  String get profileSetupEditProfileTitle => 'Modifica profilo';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Configura il tuo profilo prima di aggiungere un indirizzo NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Crea profilo';

  @override
  String get profileSetupBackLabel => 'Indietro';

  @override
  String get profileSetupAboutNostr => 'Info su Nostr';

  @override
  String get profileSetupProfilePublished => 'Profilo pubblicato con successo!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Salvare le modifiche?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Salva le modifiche prima di uscire, oppure scartale e vai avanti.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Salva le modifiche';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Scarta le modifiche';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Continua a modificare';

  @override
  String get profileSetupCreateNewProfile => 'Creare un nuovo profilo?';

  @override
  String get profileSetupNoExistingProfile =>
      'Non abbiamo trovato un profilo esistente sui tuoi relay. Pubblicando ne creerai uno nuovo. Continuare?';

  @override
  String get profileSetupPublishButton => 'Pubblica';

  @override
  String get profileSetupUsernameTaken =>
      'Il nome utente è appena stato preso. Scegline un altro.';

  @override
  String get profileSetupClaimFailed =>
      'Impossibile rivendicare il nome utente. Riprova.';

  @override
  String get profileSetupPublishFailed =>
      'Impossibile pubblicare il profilo. Riprova.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Impossibile raggiungere la rete. Controlla la connessione e riprova.';

  @override
  String get profileSetupDisplayNameLabel => 'Nome visualizzato';

  @override
  String get profileSetupDisplayNameRequired =>
      'Inserisci un nome visualizzato';

  @override
  String get profileSetupBioLabel => 'Bio (opzionale)';

  @override
  String get profileSetupWebsiteLabel => 'Sito web (facoltativo)';

  @override
  String get profileSetupPublicKeyLabel => 'Chiave pubblica (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nome utente (opzionale)';

  @override
  String get profileSetupUsernameHelper =>
      'Usa lettere, numeri o trattini. Il tuo nome utente diventa un indirizzo divine.video. Usa il nome visualizzato per spazi o simboli.';

  @override
  String get profileSetupSaveButton => 'Salva';

  @override
  String get profileSetupSavingButton => 'Salvataggio...';

  @override
  String get profileSetupImageUrlTitle => 'Aggiungi URL immagine';

  @override
  String get profileSetupImageSelectionFailed =>
      'Selezione immagine fallita. Incolla qui sotto l\'URL di un\'immagine.';

  @override
  String get profileSetupImagesTypeGroup => 'immagini';

  @override
  String get cameraPickErrorPermissionDenied =>
      'L\'accesso alla fotocamera è disattivato. Attivalo nelle Impostazioni per scattare una foto.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'L\'accesso alla fotocamera non è consentito su questo dispositivo.';

  @override
  String get cameraPickErrorBusy =>
      'Il selettore è già aperto. Chiudilo e riprova.';

  @override
  String get cameraPickErrorGeneric =>
      'Impossibile aprire la fotocamera. Riprova.';

  @override
  String get profileSetupGotItButton => 'Capito';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Impossibile caricare l\'immagine. Riprova più tardi.';

  @override
  String get profileSetupUploadNetworkError =>
      'Errore di rete: controlla la connessione a internet e riprova.';

  @override
  String get profileSetupUploadAuthError =>
      'Errore di autenticazione: prova a uscire e a rientrare.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'File troppo grande: scegli un\'immagine più piccola (max 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Impossibile caricare l\'immagine. I nostri server sono temporaneamente non disponibili. Riprova tra un attimo.';

  @override
  String get profileSetupBannerClearButton => 'Rimuovi banner';

  @override
  String get profileSetupBannerChangeColor => 'Colore del banner';

  @override
  String get profileSetupChangeBannerTitle => 'Cambia banner';

  @override
  String get profileSetupBannerColorPickerTitle =>
      'Cambia il colore del banner';

  @override
  String get profileSetupBannerColorCustom => 'Personalizzato';

  @override
  String get profileSetupBannerColorNone => 'Nessun colore';

  @override
  String get profileSetupBannerColorLime => 'Lime';

  @override
  String get profileSetupBannerColorYellow => 'Giallo';

  @override
  String get profileSetupBannerColorViolet => 'Violetto';

  @override
  String get profileSetupBannerColorPink => 'Rosa';

  @override
  String get profileSetupBannerColorOrange => 'Arancione';

  @override
  String get profileSetupBannerColorPurple => 'Viola';

  @override
  String get profileSetupAvatarClearButton => 'Rimuovi la foto';

  @override
  String get profileSetupImageTakePhoto => 'Scatta una foto';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Carica dalla galleria';

  @override
  String get profileSetupImagePasteLink => 'Incolla un link immagine';

  @override
  String get profileSetupEditAvatarLabel => 'Modifica foto profilo';

  @override
  String get profileSetupEditBannerLabel => 'Modifica banner';

  @override
  String get profileSetupUsernameChecking => 'Controllo disponibilità...';

  @override
  String get profileSetupUsernameAvailable => 'Nome utente disponibile!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Nome utente già preso';

  @override
  String get profileSetupUsernameReserved => 'Nome utente riservato';

  @override
  String get profileSetupContactSupport => 'Contatta l\'assistenza';

  @override
  String get profileSetupCheckAgain => 'Controlla di nuovo';

  @override
  String get profileSetupUsernameBurned =>
      'Questo nome utente non è più disponibile';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Sono ammessi solo lettere, numeri e trattini';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Il nome utente non può iniziare o terminare con un trattino';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Il nome utente deve avere da 3 a 63 caratteri';

  @override
  String get profileSetupUsernameNetworkError =>
      'Impossibile verificare la disponibilità. Riprova.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Formato nome utente non valido';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Verifica disponibilità fallita';

  @override
  String get profileSetupUsernameReservedTitle => 'Nome utente riservato';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Il nome $username è riservato. Dicci perché dovrebbe essere tuo.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'es. È il mio brand, nome d\'arte, ecc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Hai già contattato l\'assistenza? Tocca \"Controlla di nuovo\" per vedere se è stato rilasciato per te.';

  @override
  String get profileSetupSupportRequestSent =>
      'Richiesta di assistenza inviata! Ti risponderemo presto.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Impossibile aprire l\'email. Invia a: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Invia richiesta';

  @override
  String get profileSetupUseOwnNip05 => 'Usa il tuo indirizzo NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Indirizzo NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Formato NIP-05 non valido (es. nome@dominio.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Usa il campo nome utente qui sopra per divine.video';

  @override
  String get nostrSettingsNip05Address => 'Indirizzo NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Usa il tuo nome utente divine.video, oppure punta il tuo handle a un indirizzo NIP-05 su un dominio che controlli.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Salva NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 salvato';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Non è stato possibile salvare il NIP-05. Riprova.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Vuoi usare un NIP-05 tuo?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'Il NIP-05 collega un nome tipo tu@tuodominio.it alla tua identità Nostr. Devi controllare il dominio e ospitare un file di verifica nel percorso giusto. Se è sbagliato, le persone non ti trovano e il tuo handle verificato sparisce. Vai avanti solo se hai già configurato tutto.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Continua';

  @override
  String get profileSetupNip05ConfirmCancel => 'Annulla';

  @override
  String get profileSetupProfilePicturePreview => 'Anteprima foto profilo';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine è costruito su Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' un protocollo aperto resistente alla censura che permette alle persone di comunicare online senza dipendere da una singola azienda o piattaforma. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Quando ti iscrivi a Divine, ottieni una nuova identità Nostr.';

  @override
  String get nostrInfoOwnership =>
      'Nostr ti permette di possedere i tuoi contenuti, la tua identità e il tuo grafo sociale, che puoi usare in molte app. Il risultato è più scelta, meno lock-in e un internet sociale più sano e resiliente.';

  @override
  String get nostrInfoLingo => 'Il lessico di Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Il tuo indirizzo Nostr pubblico. È sicuro da condividere e permette ad altri di trovarti, seguirti o scriverti nelle app Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' La tua chiave privata e prova di proprietà. Ti dà il pieno controllo della tua identità Nostr, quindi ';

  @override
  String get nostrInfoNsecWarning => 'tienila sempre segreta!';

  @override
  String get nostrInfoUsernameLabel => 'Nome utente Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Un nome leggibile (tipo @name.divine.video) che è collegato al tuo npub. Rende la tua identità Nostr più facile da riconoscere e verificare, come un indirizzo email.';

  @override
  String get nostrInfoLearnMoreAt => 'Scopri di più su ';

  @override
  String get nostrInfoGotIt => 'Capito!';

  @override
  String get videoGridRefreshLabel => 'Ricerca di altri video in corso';

  @override
  String get videoGridOptionsTitle => 'Opzioni video';

  @override
  String get videoGridEditVideo => 'Modifica video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Aggiorna titolo, descrizione e hashtag';

  @override
  String get videoGridDeleteVideo => 'Elimina video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Rimuovi questo video da Divine. Potrebbe ancora comparire su altri client Nostr.';

  @override
  String get videoGridDeletingContent => 'Eliminazione contenuto...';

  @override
  String get exploreTabFeatured => 'In evidenza';

  @override
  String get exploreTabClassics => 'Classici';

  @override
  String get exploreTabNew => 'Nuovi';

  @override
  String get exploreTabPopular => 'Popolari';

  @override
  String get exploreTabCategories => 'Categorie';

  @override
  String get exploreTabForYou => 'Per te';

  @override
  String get exploreTabLists => 'Liste';

  @override
  String get exploreTabIntegratedApps => 'App integrate';

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
      'Qui non c\'è ancora niente. Torna a dare un\'occhiata presto.';

  @override
  String get featuredTabLoadFailed =>
      'Non è stato possibile caricare questa raccolta.';

  @override
  String get featuredTabRetry => 'Riprova';

  @override
  String get exploreNoVideosAvailable => 'Nessun video disponibile';

  @override
  String get exploreDiscoverLists => 'Scopri liste';

  @override
  String get exploreAboutLists => 'Info sulle liste';

  @override
  String get exploreAboutListsDescription =>
      'Le liste ti aiutano a organizzare e curare i contenuti di Divine in due modi:';

  @override
  String get explorePeopleLists => 'Liste di persone';

  @override
  String get explorePeopleListsDescription =>
      'Segui gruppi di creator e vedi i loro ultimi video';

  @override
  String get exploreVideoLists => 'Liste di video';

  @override
  String get exploreVideoListsDescription =>
      'Crea playlist dei tuoi video preferiti da guardare dopo';

  @override
  String get exploreMyLists => 'Le mie liste';

  @override
  String get exploreSubscribedLists => 'Liste iscritte';

  @override
  String get exploreErrorLoadingLists =>
      'Errore nel caricamento delle liste. Riprova.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi video',
      one: '1 nuovo video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nuovi video',
      one: 'nuovo video',
    );
    return 'Carica $count $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Riproduci video';

  @override
  String get videoPlayerMute => 'Disattiva audio video';

  @override
  String get videoPlayerUnmute => 'Riattiva audio video';

  @override
  String get videoPlayerTapHint =>
      'Tocca per riprodurre o mettere in pausa. Doppio tocco per mettere mi piace.';

  @override
  String get videoSettingsMenuOpen => 'Apri impostazioni di riproduzione';

  @override
  String get videoSettingsMenuClose => 'Chiudi impostazioni di riproduzione';

  @override
  String get videoSettingsCaptionsEnable => 'Attiva sottotitoli';

  @override
  String get videoSettingsCaptionsDisable => 'Disattiva sottotitoli';

  @override
  String get videoSettingsAutoAdvanceOn => 'Avanzamento automatico attivo';

  @override
  String get videoSettingsAutoAdvanceOff =>
      'Avanzamento automatico disattivato';

  @override
  String get videoSettingsCaptionsOn => 'Sottotitoli attivi';

  @override
  String get videoSettingsCaptionsOff => 'Sottotitoli disattivati';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Sottotitoli attivi per questo video';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Sottotitoli disattivati per questo video';

  @override
  String get contentWarningLabel => 'Avviso sui contenuti';

  @override
  String get contentWarningNudity => 'Nudità';

  @override
  String get contentWarningSexualContent => 'Contenuto sessuale';

  @override
  String get contentWarningPornography => 'Pornografia';

  @override
  String get contentWarningGraphicMedia => 'Immagini esplicite';

  @override
  String get contentWarningViolence => 'Violenza';

  @override
  String get contentWarningSelfHarm => 'Autolesionismo';

  @override
  String get contentWarningDrugUse => 'Uso di droghe';

  @override
  String get contentWarningAlcohol => 'Alcol';

  @override
  String get contentWarningTobacco => 'Tabacco';

  @override
  String get contentWarningGambling => 'Gioco d\'azzardo';

  @override
  String get contentWarningProfanity => 'Volgarità';

  @override
  String get contentWarningFlashingLights => 'Luci lampeggianti';

  @override
  String get contentWarningAiGenerated => 'Generato da IA';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Contenuto sensibile';

  @override
  String get contentWarningDescNudity => 'Contiene nudità o nudità parziale';

  @override
  String get contentWarningDescSexual => 'Contiene contenuto sessuale';

  @override
  String get contentWarningDescPorn =>
      'Contiene contenuto pornografico esplicito';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contiene immagini esplicite o disturbanti';

  @override
  String get contentWarningDescViolence => 'Contiene contenuto violento';

  @override
  String get contentWarningDescSelfHarm =>
      'Contiene riferimenti all\'autolesionismo';

  @override
  String get contentWarningDescDrugs => 'Contiene contenuto legato alle droghe';

  @override
  String get contentWarningDescAlcohol =>
      'Contiene contenuto legato all\'alcol';

  @override
  String get contentWarningDescTobacco =>
      'Contiene contenuto legato al tabacco';

  @override
  String get contentWarningDescGambling =>
      'Contiene contenuto legato al gioco d\'azzardo';

  @override
  String get contentWarningDescProfanity => 'Contiene linguaggio forte';

  @override
  String get contentWarningDescFlashingLights =>
      'Contiene luci lampeggianti (avviso per fotosensibilità)';

  @override
  String get contentWarningDescAiGenerated =>
      'Questo contenuto è stato generato da un\'IA';

  @override
  String get contentWarningDescSpoiler => 'Contiene spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Il creator lo ha segnalato come sensibile';

  @override
  String get contentWarningDescDefault =>
      'Il creator ha segnalato questo contenuto';

  @override
  String get contentWarningDetailsTitle => 'Avvisi sui contenuti';

  @override
  String get contentWarningDetailsSubtitle =>
      'Il creator ha applicato queste etichette:';

  @override
  String get contentWarningManageFilters => 'Gestisci filtri contenuti';

  @override
  String get contentWarningViewAnyway => 'Guarda comunque';

  @override
  String get contentWarningReportContentTooltip => 'Segnala contenuto';

  @override
  String get contentWarningBlockUserTooltip => 'Blocca utente';

  @override
  String get contentWarningBlockedTitle => 'Contenuto bloccato';

  @override
  String get contentWarningBlockedPolicy =>
      'Questo contenuto è stato bloccato per violazione delle policy.';

  @override
  String get contentWarningNoticeTitle => 'Avviso sul contenuto';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Contenuto potenzialmente dannoso';

  @override
  String get contentWarningView => 'Guarda';

  @override
  String get contentWarningReportAction => 'Segnala';

  @override
  String get contentWarningHideAllLikeThis =>
      'Nascondi tutti i contenuti come questo';

  @override
  String get contentWarningNoFilterYet =>
      'Ancora nessun filtro salvato per questo avviso.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Da ora in poi nasconderemo i post come questo.';

  @override
  String get communitySuggestTitle => 'Aiuta a classificare questo video';

  @override
  String get communitySuggestSubtitle =>
      'Manca un avviso sui contenuti? Il tuo suggerimento è pubblico, firmato e non si può ritirare.';

  @override
  String get communitySuggestSubmit => 'Suggerisci';

  @override
  String get communitySuggestSuccess =>
      'Grazie. Il tuo suggerimento è stato inviato.';

  @override
  String get communitySuggestFailure =>
      'Impossibile inviare il tuo suggerimento. Riprova.';

  @override
  String get communitySuggestAlready => 'L\'hai già suggerito';

  @override
  String get communitySuggestActionLabel => 'Classifica';

  @override
  String get videoErrorNotFound => 'Video non trovato';

  @override
  String get videoErrorPlayback => 'Errore di riproduzione video';

  @override
  String get videoErrorAgeRestricted => 'Contenuto con limite d\'età';

  @override
  String get videoErrorUnavailable => 'Video non disponibile';

  @override
  String get videoErrorUnavailableBody =>
      'Questo video non è disponibile al momento.';

  @override
  String get videoErrorRetry => 'Riprova';

  @override
  String get videoErrorContentRestricted => 'Contenuto con restrizioni';

  @override
  String get videoErrorContentRestrictedBody =>
      'Questo video è stato rimosso perché violava le nostre regole sui contenuti.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifica la tua età per vedere questo video.';

  @override
  String get videoErrorSkip => 'Salta';

  @override
  String get videoErrorVerifyAgeButton => 'Verifica età';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Non è stato possibile verificare la tua età. Riprova.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Verifica scaduta. Controlla la connessione o riprova tra poco.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'I contenuti per adulti sono disattivati';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Attivali nei tuoi filtri contenuti per guardare questo video.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Apri filtri contenuti';

  @override
  String get videoDetailLoadError => 'Impossibile caricare il video';

  @override
  String get videoDetailLoadErrorBody =>
      'Qualcosa è andato storto lungo la strada. Riprova.';

  @override
  String get videoDetailNotFoundBody =>
      'Forse è stato eliminato, non è raggiungibile o è nascosto dalle tue impostazioni.';

  @override
  String get databaseCorruptionTitle => 'I tuoi dati locali si sono rovinati';

  @override
  String get databaseCorruptionBody =>
      'Chiudi Divine e riaprila: sistemiamo tutto in automatico. Salviamo quello che possiamo delle tue bozze e clip, il resto si ricarica.';

  @override
  String get databaseCorruptionCloseButton => 'Chiudi Divine';

  @override
  String get videoDetailContextTitle => 'Video condiviso';

  @override
  String get videoDetailCloseSemanticLabel => 'Chiudi lettore video';

  @override
  String get videoFollowButtonFollow => 'Segui';

  @override
  String get audioAttributionOriginalSound => 'Audio originale';

  @override
  String get audioAttributionUnavailableSound => 'Audio non disponibile';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Ispirato da @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Ispirato da @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'con @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'con @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaboratori',
      one: '1 collaboratore',
    );
    return '$_temp0. Tocca per vedere il profilo.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'In attesa';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Collaboratore in attesa';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending in attesa)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Tocca per vedere il profilo.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Tocca per vedere i video con questo hashtag.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Condividi video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post condiviso con $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Post condiviso con $count persone',
      one: 'Post condiviso con $count persona',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Impossibile inviare il video';

  @override
  String get shareAddedToBookmarks => 'Aggiunto ai segnalibri';

  @override
  String get shareRemovedFromBookmarks => 'Rimosso dai segnalibri';

  @override
  String get shareFailedToAddBookmark => 'Impossibile aggiungere ai segnalibri';

  @override
  String get shareFailedToRemoveBookmark =>
      'Impossibile rimuovere dai segnalibri';

  @override
  String get shareActionFailed => 'Azione fallita';

  @override
  String get shareWithTitle => 'Condividi con';

  @override
  String get shareFindPeople => 'Trova persone';

  @override
  String get shareFindPeopleMultiline => 'Trova\npersone';

  @override
  String get shareSent => 'Inviato';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name selezionato';
  }

  @override
  String get shareMessageHint => 'Aggiungi un messaggio opzionale...';

  @override
  String get videoActionUnlike => 'Togli il mi piace al video';

  @override
  String get videoActionLike => 'Metti mi piace al video';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Mi piace';

  @override
  String get videoActionReplyLabel => 'Rispondi';

  @override
  String get videoActionRepostLabel => 'Repost';

  @override
  String get videoActionShareLabel => 'Condividi';

  @override
  String get videoActionReportLabel => 'Segnala';

  @override
  String get videoActionReport => 'Segnala video';

  @override
  String get videoActionEditLabel => 'Modifica';

  @override
  String get videoActionEdit => 'Modifica video';

  @override
  String get videoActionAboutLabel => 'Info';

  @override
  String get videoActionEnableAutoAdvance => 'Attiva avanzamento automatico';

  @override
  String get videoActionDisableAutoAdvance =>
      'Disattiva avanzamento automatico';

  @override
  String get videoActionRemoveRepost => 'Rimuovi repost';

  @override
  String get videoActionRepost => 'Ripubblica video';

  @override
  String get videoActionViewComments => 'Vedi commenti';

  @override
  String get videoActionMoreOptions => 'Altre opzioni';

  @override
  String get videoEngagementLikersTitle => 'Piaciuto a';

  @override
  String get videoEngagementRepostersTitle => 'Repostato da';

  @override
  String get videoEngagementLikersEmpty => 'Ancora nessun mi piace';

  @override
  String get videoEngagementRepostersEmpty => 'Ancora nessun repost';

  @override
  String get videoEngagementLoadFailed => 'Impossibile caricare l\'elenco';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Apri dettagli video';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Apri dettagli video';

  @override
  String get videoOverlayCommentBarHint => 'Aggiungi un commento...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Aggiungi un commento';

  @override
  String get videoOverlayCommentBarSendLabel => 'Invia commento';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Commento pubblicato';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Impossibile pubblicare il commento';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loop',
      one: 'loop',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Non Divine';

  @override
  String get metadataBadgeHumanMade => 'Fatto da umani';

  @override
  String get metadataSoundsLabel => 'Suoni';

  @override
  String get metadataOriginalSound => 'Audio originale';

  @override
  String get metadataVerificationLabel => 'Verifica';

  @override
  String get metadataDeviceAttestation => 'Attestazione del dispositivo';

  @override
  String get metadataPgpSignature => 'Firma PGP';

  @override
  String get metadataC2paCredentials => 'C2PA Content Credentials';

  @override
  String get metadataProofManifest => 'Manifesto di prova';

  @override
  String get metadataVerificationInfoTooltip =>
      'Cosa significano questi controlli?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle =>
      'Cosa significano questi controlli';

  @override
  String get metadataVerificationInfoIntro =>
      'Questi segnali arrivano dalla fotocamera e dal file video stesso. Più ne ha un video, più possiamo dimostrare della sua origine.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Il sistema operativo del telefono ha garantito per l\'app che ha registrato. Una prova solida che arriva da una fotocamera, non da un file caricato.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Il video è stato firmato crittograficamente nel momento della ripresa. Se dopo cambia anche un solo fotogramma, la firma si rompe.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Un certificato di provenienza secondo lo standard del settore, che viaggia dentro il file: così può verificarlo anche un\'app diversa da Divine.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Il record ProofMode completo: impronta del file, marca temporale e contesto di ripresa, insieme al video.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Un controllo mancante non rende falso un video. I clip più vecchi e i caricamenti non l\'hanno mai avuto: significa solo che non possiamo dimostrare quella parte.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Scopri di più su $url';
  }

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Collaboratori';

  @override
  String get metadataInspiredByLabel => 'Ispirato da';

  @override
  String get metadataRepostedByLabel => 'Ripubblicato da';

  @override
  String metadataMoreReposters(int count) {
    return '+$count altri';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Loop';
  }

  @override
  String get metadataLikesLabel => 'Mi piace';

  @override
  String get metadataCommentsLabel => 'Commenti';

  @override
  String get metadataRepostsLabel => 'Repost';

  @override
  String get metadataVineStatsLabel => 'Su Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loop · $likes mi piace · $comments commenti · $reposts repost';
  }

  @override
  String get metadataDivineStatsLabel => 'Su Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views visualizzazioni · $likes mi piace · $comments commenti · $reposts repost';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Pubblicato il $date';
  }

  @override
  String get devOptionsTitle => 'Opzioni sviluppatore';

  @override
  String get devOptionsDisableDeveloperMode =>
      'Disattiva modalità sviluppatore';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Nascondi le opzioni sviluppatore dalle impostazioni';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Modalità sviluppatore disattivata';

  @override
  String get devOptionsShorebirdTitle => 'Patch Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Patch attiva';

  @override
  String get devOptionsShorebirdNoPatch => 'Nessuna patch installata';

  @override
  String get devOptionsShorebirdUnavailable =>
      'Non disponibile in questa build';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Le patch funzionano solo in una build creata con shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Lettura dello stato della patch…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Canale di staging non ancora controllato.';

  @override
  String get devOptionsShorebirdCheck => 'Controlla il canale di staging';

  @override
  String get devOptionsShorebirdApply => 'Applica la patch di staging';

  @override
  String get devOptionsShorebirdUseStable => 'Torna agli aggiornamenti stabili';

  @override
  String get devOptionsShorebirdChecking => 'Controllo del canale di staging…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Una patch di staging è pronta per essere applicata.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Nessuna patch di staging per questa versione.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Scaricata. Riavvia l’app per caricarla.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'È pronto un rollback. Riavvia per tornare alla versione base.';

  @override
  String get devOptionsShorebirdApplying => 'Download e installazione…';

  @override
  String get devOptionsShorebirdApplied =>
      'Installata. Riavvia l’app per caricarla.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Non è stato installato nulla. Controlla il canale di staging e riprova.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Selezione del canale stabile…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Canale stabile selezionato. Riavvia l’app per cercare una patch stabile.';

  @override
  String get devOptionsShorebirdFailure =>
      'Non ha funzionato. Controlla i log per i dettagli.';

  @override
  String get devOptionsPageLoadTimes => 'Tempi di caricamento pagina';

  @override
  String get devOptionsNoPageLoads =>
      'Ancora nessun caricamento di pagina registrato.\nNaviga nell\'app per vedere i dati sui tempi.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visibile: ${visibleMs}ms  |  Dati: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Schermate più lente';

  @override
  String get devOptionsVideoPlaybackFormat => 'Formato riproduzione video';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Cambiare ambiente?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Passare a $envName?\n\nQuesto cancellerà i dati video in cache e si riconnetterà al nuovo relay.';
  }

  @override
  String get devOptionsCancel => 'Annulla';

  @override
  String get devOptionsSwitch => 'Cambia';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Passato a $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Passato a $formatName — cache svuotata';
  }

  @override
  String get featureFlagTitle => 'Feature flag';

  @override
  String get featureFlagResetAllTooltip =>
      'Ripristina tutti i flag ai valori predefiniti';

  @override
  String get featureFlagError => 'Errore';

  @override
  String get relaySettingsTitle => 'Relay';

  @override
  String get relaySettingsInfoTitle =>
      'Divine è un sistema aperto - tu controlli le tue connessioni';

  @override
  String get relaySettingsInfoDescription =>
      'Questi relay distribuiscono i tuoi contenuti sulla rete Nostr decentralizzata. Puoi aggiungere o rimuovere relay come preferisci.';

  @override
  String get relaySettingsLearnMoreNostr => 'Scopri di più su Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Trova relay pubblici su nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App non funzionante';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine richiede almeno un relay per caricare video, pubblicare contenuti e sincronizzare i dati.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Ripristina relay predefinito';

  @override
  String get relaySettingsAddCustomRelay => 'Aggiungi relay personalizzato';

  @override
  String get relaySettingsAddRelay => 'Aggiungi relay';

  @override
  String get relaySettingsRetry => 'Riprova';

  @override
  String get relaySettingsNoStats => 'Nessuna statistica ancora disponibile';

  @override
  String get relaySettingsConnection => 'Connessione';

  @override
  String get relaySettingsConnected => 'Connesso';

  @override
  String get relaySettingsDisconnected => 'Disconnesso';

  @override
  String get relaySettingsSessionDuration => 'Durata sessione';

  @override
  String get relaySettingsLastConnected => 'Ultima connessione';

  @override
  String get relaySettingsDisconnectedLabel => 'Disconnesso';

  @override
  String get relaySettingsReason => 'Motivo';

  @override
  String get relaySettingsActiveSubscriptions => 'Sottoscrizioni attive';

  @override
  String get relaySettingsTotalSubscriptions => 'Sottoscrizioni totali';

  @override
  String get relaySettingsEventsReceived => 'Eventi ricevuti';

  @override
  String get relaySettingsEventsSent => 'Eventi inviati';

  @override
  String get relaySettingsRequestsThisSession => 'Richieste in questa sessione';

  @override
  String get relaySettingsFailedRequests => 'Richieste fallite';

  @override
  String get relaySettingsLoadingRelayInfo => 'Caricamento info relay...';

  @override
  String get relaySettingsAboutRelay => 'Info sul relay';

  @override
  String get relaySettingsSupportedNips => 'NIP supportati';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Visita il sito';

  @override
  String get relaySettingsRemoveRelayTitle => 'Rimuovere il relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Sei sicuro di voler rimuovere questo relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Rimuovere il relay di Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Rimuovere il relay di Divine peggiorerà l\'esperienza nell\'app. Video, pubblicazione e sincronizzazione potrebbero essere meno affidabili. Fallo solo se sei un utente Nostr esperto.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Rimuovi relay';

  @override
  String get relaySettingsCancel => 'Annulla';

  @override
  String get relaySettingsRemove => 'Rimuovi';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay rimosso: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay =>
      'Impossibile rimuovere il relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forzatura riconnessione relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Connesso a $count relay!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Impossibile connettersi ai relay. Controlla la connessione di rete.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Salvato su questo dispositivo. Lo sincronizzeremo con il tuo account quando la pubblicazione tornerà a funzionare.';

  @override
  String get relaySettingsAddRelayTitle => 'Aggiungi relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Inserisci l\'URL WebSocket del relay che vuoi aggiungere:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Sfoglia relay pubblici su nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Aggiungi';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay aggiunto: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Impossibile aggiungere il relay. Controlla l\'URL e riprova.';

  @override
  String get relaySettingsInvalidUrl =>
      'L\'URL del relay deve iniziare con wss:// o ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'L\'URL del relay deve usare wss:// (ws:// è ammesso solo per localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay predefinito ripristinato: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Impossibile ripristinare il relay predefinito. Controlla la connessione di rete.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Impossibile aprire il browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Impossibile aprire il link';

  @override
  String get relaySettingsExternalRelay => 'Relay esterno';

  @override
  String get relaySettingsNotConnected => 'Non connesso';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Disconnesso $duration fa';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count sub';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count eventi';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration fa';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine usa il protocollo Nostr per la pubblicazione decentralizzata. I tuoi contenuti vivono sui relay che scegli e le tue chiavi sono la tua identità.';

  @override
  String get nostrSettingsSectionNetwork => 'Rete';

  @override
  String get nostrSettingsSectionAccount => 'Account';

  @override
  String get nostrSettingsSectionDangerZone => 'Zona pericolosa';

  @override
  String get nostrSettingsRelays => 'Relay';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Gestisci le connessioni ai relay Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostica relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Controlla la connettività dei relay e i problemi di rete';

  @override
  String get nostrSettingsMediaServers => 'Server multimediali';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configura i server di upload Blossom';

  @override
  String get settingsDeveloperOptions => 'Opzioni sviluppatore';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Selettore ambiente e impostazioni di debug';

  @override
  String get nostrSettingsKeyManagement => 'Gestione chiavi';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Esporta, fai il backup e ripristina le tue chiavi Nostr';

  @override
  String get nostrSettingsClientAttribution => 'Attribuzione del client';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Includi un tag client Divine negli eventi che pubblichi, così le altre app Nostr possono attribuirli correttamente. Senza, le segnalazioni che invii pesano meno quando i nostri moderatori le esaminano.';

  @override
  String get nostrSettingsMoveAccount => 'Sposta il tuo account';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Scarica il tuo archivio e sposta post e video su un altro relay o server multimediale.';

  @override
  String get nostrSettingsRemoveKeys => 'Rimuovi le chiavi dal dispositivo';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Elimina la tua chiave privata solo da questo dispositivo. I tuoi contenuti restano sui relay, ma ti servirà il backup della nsec per accedere di nuovo al tuo account.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Impossibile rimuovere questo account da questo dispositivo. Riprova.';

  @override
  String get nostrSettingsDeleteAccount => 'Elimina account e dati';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Invia richieste di eliminazione per i tuoi contenuti e ti disconnette su questo dispositivo. Relay, client, indici di ricerca e altri dispositivi con l\'accesso effettuato potrebbero conservare copie.';

  @override
  String get relayDiagnosticTitle => 'Diagnostica relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Aggiorna diagnostica';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Ultimo aggiornamento: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Stato relay';

  @override
  String get relayDiagnosticInitialized => 'Inizializzato';

  @override
  String get relayDiagnosticReady => 'Pronto';

  @override
  String get relayDiagnosticNotInitialized => 'Non inizializzato';

  @override
  String get relayDiagnosticDatabaseEvents => 'Eventi del database';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Sottoscrizioni attive';

  @override
  String get relayDiagnosticExternalRelays => 'Relay esterni';

  @override
  String get relayDiagnosticConfigured => 'Configurato';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Connesso';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Eventi video';

  @override
  String get relayDiagnosticHomeFeed => 'Feed home';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Scoperta';

  @override
  String get relayDiagnosticLoading => 'Caricamento';

  @override
  String get relayDiagnosticYes => 'Sì';

  @override
  String get relayDiagnosticNo => 'No';

  @override
  String get relayDiagnosticTestDirectQuery => 'Test query diretta';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Connettività di rete';

  @override
  String get relayDiagnosticRunNetworkTest => 'Esegui test di rete';

  @override
  String get relayDiagnosticBlossomServer => 'Server Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testa tutti gli endpoint';

  @override
  String get relayDiagnosticStatus => 'Stato';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Errore';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL base';

  @override
  String get relayDiagnosticSummary => 'Riepilogo';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (media ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Ritesta tutto';

  @override
  String get relayDiagnosticRetrying => 'Nuovo tentativo...';

  @override
  String get relayDiagnosticRetryConnection => 'Riprova connessione';

  @override
  String get relayDiagnosticTroubleshooting => 'Risoluzione problemi';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Stato verde = connesso e funzionante\n• Stato rosso = connessione fallita\n• Se il test di rete fallisce, controlla la connessione internet\n• Se i relay sono configurati ma non connessi, tocca \"Riprova connessione\"\n• Fai uno screenshot di questa schermata per il debug';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Tutti gli endpoint REST sono in salute!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Alcuni endpoint REST hanno fallito - vedi i dettagli sopra';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Trovati $count eventi video nel database';
  }

  @override
  String get relayDiagnosticQueryFailed => 'Query fallita. Riprova.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Connesso a $count relay!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Impossibile connettersi ad alcun relay';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Nuovo tentativo di connessione fallito. Riprova.';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Connesso e autenticato';

  @override
  String get relayDiagnosticConnectedOnly => 'Connesso';

  @override
  String get relayDiagnosticNotConnected => 'Non connesso';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Nessun relay configurato';

  @override
  String get relayDiagnosticFailed => 'Fallito';

  @override
  String get notificationSettingsTitle => 'Notifiche';

  @override
  String get notificationSettingsResetTooltip => 'Ripristina predefiniti';

  @override
  String get notificationSettingsTypes => 'Tipi di notifica';

  @override
  String get notificationSettingsLikes => 'Mi piace';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Quando qualcuno mette mi piace ai tuoi video';

  @override
  String get notificationSettingsComments => 'Commenti';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Quando qualcuno commenta i tuoi video';

  @override
  String get notificationSettingsFollows => 'Follow';

  @override
  String get notificationSettingsFollowsSubtitle => 'Quando qualcuno ti segue';

  @override
  String get notificationSettingsMentions => 'Menzioni';

  @override
  String get notificationSettingsMentionsSubtitle => 'Quando vieni menzionato';

  @override
  String get notificationSettingsReposts => 'Repost';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Quando qualcuno ripubblica i tuoi video';

  @override
  String get notificationSettingsNewPosts => 'Nuovi vine';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Quando qualcuno che segui pubblica';

  @override
  String get notificationSettingsActions => 'Azioni';

  @override
  String get notificationSettingsMarkAllAsRead => 'Segna tutto come letto';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Segna tutte le notifiche come lette';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Tutte le notifiche segnate come lette';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Impossibile segnare tutte come lette';

  @override
  String get notificationSettingsResetToDefaults =>
      'Impostazioni ripristinate ai valori predefiniti';

  @override
  String get notificationSettingsAbout => 'Info sulle notifiche';

  @override
  String get notificationSettingsAboutDescription =>
      'Le notifiche sono alimentate dal protocollo Nostr. Gli aggiornamenti in tempo reale dipendono dalla tua connessione ai relay Nostr. Alcune notifiche potrebbero subire ritardi.';

  @override
  String get safetySettingsWhatYouSee => 'COSA VEDI';

  @override
  String get safetySettingsWhatYouPublish => 'COSA PUBBLICHI';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Mostra solo video ospitati su Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Nascondi i video serviti da altri host multimediali';

  @override
  String get safetySettingsModeration => 'MODERAZIONE';

  @override
  String get safetySettingsBlockedUsers => 'UTENTI BLOCCATI';

  @override
  String get safetySettingsAgeVerification => 'VERIFICA ETÀ';

  @override
  String get safetySettingsAgeConfirmation => 'Confermo di avere 18 anni o più';

  @override
  String get safetySettingsAgeRequired =>
      'Richiesto per vedere contenuti per adulti';

  @override
  String get safetySettingsAgeLockedForMinor => 'Bloccato per il tuo account';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Servizio di moderazione ufficiale (attivo di default)';

  @override
  String get safetySettingsPeopleIFollow => 'Persone che seguo';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Iscriviti alle etichette delle persone che segui';

  @override
  String get safetySettingsAddCustomLabeler =>
      'Aggiungi labeler personalizzato';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Inserisci npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Aggiungi labeler personalizzato';

  @override
  String get safetySettingsRemoveLabeler => 'Rimuovi labeler';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Inserisci indirizzo npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Nessun utente bloccato';

  @override
  String get safetySettingsUnblock => 'Sblocca';

  @override
  String get safetySettingsUserUnblocked => 'Utente sbloccato';

  @override
  String get safetySettingsCancel => 'Annulla';

  @override
  String get safetySettingsAdd => 'Aggiungi';

  @override
  String get analyticsTitle => 'Statistiche creator';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostica';

  @override
  String get analyticsDiagnosticsSemanticLabel =>
      'Attiva/disattiva diagnostica';

  @override
  String get analyticsRetry => 'Riprova';

  @override
  String get analyticsUnableToLoad => 'Impossibile caricare le statistiche.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Accedi per vedere le statistiche creator.';

  @override
  String get analyticsViewDataUnavailable =>
      'Le visualizzazioni al momento non sono disponibili dal relay per questi post. Mi piace/commenti/repost sono comunque accurati.';

  @override
  String get analyticsViewDataTitle => 'Dati visualizzazioni';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Aggiornato $time • I punteggi usano mi piace, commenti, repost e visualizzazioni/loop da Funnelcake quando disponibili.';
  }

  @override
  String get analyticsVideos => 'Video';

  @override
  String get analyticsViews => 'Visualizzazioni';

  @override
  String get analyticsInteractions => 'Interazioni';

  @override
  String get analyticsEngagement => 'Coinvolgimento';

  @override
  String get analyticsFollowers => 'Follower';

  @override
  String get analyticsAvgPerPost => 'Media/post';

  @override
  String get analyticsInteractionMix => 'Mix interazioni';

  @override
  String get analyticsLikes => 'Mi piace';

  @override
  String get analyticsComments => 'Commenti';

  @override
  String get analyticsReposts => 'Repost';

  @override
  String get analyticsPerformanceHighlights => 'Highlight performance';

  @override
  String get analyticsMostViewed => 'Più visto';

  @override
  String get analyticsMostDiscussed => 'Più commentato';

  @override
  String get analyticsMostReposted => 'Più ripubblicato';

  @override
  String get analyticsNoVideosYet => 'Ancora nessun video';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Dati visualizzazioni non disponibili';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count visualizzazioni';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count commenti';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count repost';
  }

  @override
  String get analyticsTopContent => 'Contenuti top';

  @override
  String get analyticsPublishPrompt =>
      'Pubblica qualche video per vedere le classifiche.';

  @override
  String get analyticsEngagementRateExplainer =>
      'La % a destra = tasso di coinvolgimento (interazioni divise per visualizzazioni).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Il tasso di coinvolgimento richiede dati sulle visualizzazioni; i valori sono N/D finché non sono disponibili.';

  @override
  String get analyticsEngagementLabel => 'Coinvolgimento';

  @override
  String get analyticsViewsUnavailable => 'visualizzazioni non disponibili';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interazioni';
  }

  @override
  String get analyticsPostAnalytics => 'Statistiche post';

  @override
  String get analyticsOpenPost => 'Apri post';

  @override
  String get analyticsRecentDailyInteractions =>
      'Interazioni giornaliere recenti';

  @override
  String get analyticsNoActivityYet =>
      'Ancora nessuna attività in questo intervallo.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interazioni = mi piace + commenti + repost per data di post.';

  @override
  String get analyticsDailyBarExplainer =>
      'La lunghezza della barra è relativa al tuo giorno migliore in questo periodo.';

  @override
  String get analyticsAudienceSnapshot => 'Istantanea audience';

  @override
  String analyticsFollowersCount(String count) {
    return 'Follower: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Seguiti: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'I dettagli su sorgente/area geografica/tempo dell\'audience arriveranno quando Funnelcake aggiungerà gli endpoint di analytics dell\'audience.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'La curva di retention e la ripartizione del tempo di visione appariranno quando arriverà la retention per secondo/per bucket da Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Dati di retention non disponibili finché Funnelcake non restituirà le analytics di visualizzazioni+tempo di visione.';

  @override
  String get analyticsDiagnostics => 'Diagnostica';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Video totali: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Con visualizzazioni: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Senza visualizzazioni: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Idratati (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Idratati (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sorgenti: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Usa dati fixture';

  @override
  String get analyticsNa => 'N/D';

  @override
  String get authCreateNewAccount => 'Crea un nuovo account Divine';

  @override
  String get authCreateNewAccountShort => 'Crea un nuovo account';

  @override
  String get authSignInDifferentAccount => 'Accedi con un account diverso';

  @override
  String get authUseAnotherAccount => 'Usa un altro account';

  @override
  String authContinueAs(String displayName) {
    return 'Continua come $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Le tue bozze e i tuoi clip sono salvati per questo account';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Accedere qui nasconderà quelle bozze e quei clip';

  @override
  String get authTermsPrefix =>
      'Scegliendo un\'opzione qui sotto, confermi di avere almeno 16 anni (o di aver completato l\'';

  @override
  String get authTermsAgeAuthorizationCta =>
      'autorizzazione all\'età di Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') e accetti i ';

  @override
  String get authTermsOfService => 'Termini di servizio';

  @override
  String get authPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get authTermsAnd => ' e gli ';

  @override
  String get authSafetyStandards => 'Standard di sicurezza';

  @override
  String get authAmberNotInstalled => 'L\'app Amber non è installata';

  @override
  String get authAmberConnectionFailed => 'Impossibile connettersi con Amber';

  @override
  String get authPasswordResetSent =>
      'Se esiste un account con quell\'email, abbiamo inviato un link per reimpostare la password.';

  @override
  String get authSignInTitle => 'Accedi';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authConfirmPasswordLabel => 'Conferma password';

  @override
  String get authEmailRequired => 'L\'email è obbligatoria';

  @override
  String get authEmailInvalid => 'Inserisci un\'email valida';

  @override
  String get authPasswordRequired => 'La password è obbligatoria';

  @override
  String get authConfirmPasswordRequired => 'Conferma la tua password';

  @override
  String get authPasswordsDoNotMatch => 'Le password non corrispondono';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authImportNostrKey => 'Importa chiave Nostr';

  @override
  String get authConnectSignerApp => 'Connettiti con un\'app signer';

  @override
  String get authSignInWithAmber => 'Accedi con Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Accedi con estensione del browser';

  @override
  String get authNip07ConnectionFailed =>
      'Impossibile connettersi alla tua estensione del browser.';

  @override
  String get authNip07ExtensionNotFound =>
      'Nessuna estensione del browser trovata. Installa Alby, nos2x o un\'altra estensione compatibile con NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opzioni di accesso';

  @override
  String get authInfoEmailPasswordTitle => 'Email e password';

  @override
  String get authInfoEmailPasswordDescription =>
      'Accedi con il tuo account Divine. Se ti sei registrato con email e password, usale qui.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Hai già un\'identità Nostr? Importa la tua chiave privata nsec da un altro client.';

  @override
  String get authInfoSignerAppTitle => 'App signer';

  @override
  String get authInfoSignerAppDescription =>
      'Connettiti usando un signer remoto compatibile NIP-46 come nsecBunker per una maggiore sicurezza della chiave.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Usa l\'app signer Amber su Android per gestire le tue chiavi Nostr in modo sicuro.';

  @override
  String get authInfoBrowserExtensionTitle => 'Estensione del Browser';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Accedi con un\'estensione del browser NIP-07 come Alby o nos2x. Le tue chiavi restano nell\'estensione — Divine non le vede mai.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Email o password errati. Riprova.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Verifica la tua email prima di accedere: controlla la posta in arrivo per il link.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Non sembra un indirizzo email valido.';

  @override
  String get authSignInErrorNetwork =>
      'Impossibile raggiungere il server. Controlla la connessione e riprova.';

  @override
  String get authSignInErrorGeneric => 'Qualcosa è andato storto. Riprova.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Non sai come hai effettuato l\'accesso l\'ultima volta? ';

  @override
  String get authSignInOptionsHintCta => 'Vedi tutte le opzioni di accesso';

  @override
  String get authCreateAccountTitle => 'Crea account';

  @override
  String get authBackToInviteCode => 'Torna al codice invito';

  @override
  String get authUseDivineNoBackup => 'Usa Divine senza backup';

  @override
  String get authSkipConfirmTitle => 'Un\'ultima cosa...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Sei dentro! Creeremo una chiave sicura che alimenterà il tuo account Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Senza un\'email, la tua chiave è l\'unico modo in cui Divine sa che questo account è tuo.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Puoi accedere alla tua chiave nell\'app, ma, se non sei un tipo tecnico, ti consigliamo di aggiungere un\'email e una password adesso. Rende più facile accedere e ripristinare il tuo account se perdi o resetti questo dispositivo.';

  @override
  String get authAddEmailPassword => 'Aggiungi email e password';

  @override
  String get authUseThisDeviceOnly => 'Usa solo questo dispositivo';

  @override
  String get authCompleteRegistration => 'Completa la registrazione';

  @override
  String get authVerifying => 'Verifica in corso...';

  @override
  String get authVerificationLinkSent =>
      'Abbiamo inviato un link di verifica a:';

  @override
  String get authClickVerificationLink =>
      'Clicca sul link nella tua email per\ncompletare la registrazione.';

  @override
  String get authPleaseWaitVerifying =>
      'Aspetta mentre verifichiamo la tua email...';

  @override
  String get authWaitingForVerification => 'In attesa di verifica';

  @override
  String get authOpenEmailApp => 'Apri app email';

  @override
  String get authVerificationPinPrompt =>
      'Oppure inserisci il codice a 6 cifre dalla tua email';

  @override
  String get authVerificationPinFieldLabel => 'Codice a 6 cifre';

  @override
  String get authVerificationPinSubmit => 'Verifica codice';

  @override
  String get authVerificationResendPrompt => 'Non ti è arrivato?';

  @override
  String get authVerificationResend => 'Invia di nuovo';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Invia di nuovo tra $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Non siamo riusciti a reinviare l\'email. Riprova.';

  @override
  String get authVerificationResendExpired =>
      'Quella registrazione è scaduta. Ricomincia per ricevere un codice nuovo.';

  @override
  String get authVerificationResendUnavailable =>
      'Ora non è possibile inviare di nuovo. Usa il codice a 6 cifre dell\'email che ti abbiamo già mandato.';

  @override
  String get authVerificationPollingStopped =>
      'Abbiamo smesso di controllare per te. Inserisci il codice a 6 cifre della tua email per completare l\'accesso.';

  @override
  String get authWelcomeToDivine => 'Benvenuto su Divine!';

  @override
  String get authEmailVerified => 'La tua email è stata verificata.';

  @override
  String get authSigningYouIn => 'Accesso in corso';

  @override
  String get authErrorTitle => 'Ops.';

  @override
  String get authVerificationFailed =>
      'Non siamo riusciti a verificare la tua email.\nRiprova.';

  @override
  String get authStartOver => 'Ricomincia';

  @override
  String get authEmailVerifiedLogin =>
      'Email verificata! Accedi per continuare.';

  @override
  String get authVerificationLinkExpired =>
      'Questo link di verifica non è più valido.';

  @override
  String get authVerificationConnectionError =>
      'Impossibile verificare l\'email. Controlla la connessione e riprova.';

  @override
  String get authWaitlistConfirmTitle => 'Sei dentro!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Ti manderemo aggiornamenti a $email.\nQuando saranno disponibili altri codici invito, te li invieremo.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Riprova';

  @override
  String get authContactSupport => 'Contatta l\'assistenza';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Impossibile aprire $email';
  }

  @override
  String get authAddInviteCode => 'Aggiungi il tuo codice invito';

  @override
  String get authInviteCodeLabel => 'Codice invito';

  @override
  String get authEnterYourCode => 'Inserisci il tuo codice';

  @override
  String get authNext => 'Avanti';

  @override
  String get authJoinWaitlist => 'Entra in lista d\'attesa';

  @override
  String get authJoinWaitlistTitle => 'Entra nella lista d\'attesa';

  @override
  String get authJoinWaitlistDescription =>
      'Condividi la tua email e ti manderemo aggiornamenti quando si aprirà l\'accesso.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Mandatemi ispirazione da Divine';

  @override
  String get authInviteAccessHelp => 'Aiuto accesso tramite invito';

  @override
  String get authGeneratingConnection => 'Generazione connessione...';

  @override
  String get authConnectedAuthenticating => 'Connesso! Autenticazione...';

  @override
  String get authConnectionTimedOut => 'Connessione scaduta';

  @override
  String get authApproveConnection =>
      'Assicurati di aver approvato la connessione nella tua app signer.';

  @override
  String get authConnectionCancelled => 'Connessione annullata';

  @override
  String get authConnectionCancelledMessage =>
      'La connessione è stata annullata.';

  @override
  String get authConnectionFailed => 'Connessione fallita';

  @override
  String get authUnknownError => 'Si è verificato un errore sconosciuto.';

  @override
  String get authNostrConnectStartFailed =>
      'Impossibile raggiungere il signer. Controlla la connessione e riprova.';

  @override
  String get authNostrConnectInvalidSession =>
      'Questo link di connessione non è più valido. Avviane uno nuovo.';

  @override
  String get authNostrConnectSetupFailed =>
      'Ci siamo quasi — non siamo riusciti a completare l\'accesso. Riprova.';

  @override
  String get authUrlCopied => 'URL copiato negli appunti';

  @override
  String get authConnectToDivine => 'Connettiti a Divine';

  @override
  String get authPasteBunkerUrl => 'Incolla URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker non valido. Deve iniziare con bunker://';

  @override
  String get authScanSignerApp =>
      'Scansiona con la tua\napp signer per connetterti.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'In attesa di connessione... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copia URL';

  @override
  String get authShare => 'Condividi';

  @override
  String get authAddBunker => 'Aggiungi bunker';

  @override
  String get authCompatibleSignerApps => 'App signer compatibili';

  @override
  String get authFailedToConnect => 'Connessione fallita';

  @override
  String get authResetPasswordTitle => 'Reimposta password';

  @override
  String get authResetPasswordSubtitle =>
      'Inserisci la tua nuova password. Deve essere di almeno 8 caratteri.';

  @override
  String get authNewPasswordLabel => 'Nuova password';

  @override
  String get authConfirmNewPasswordLabel => 'Conferma nuova password';

  @override
  String get authPasswordTooShort =>
      'La password deve avere almeno 8 caratteri';

  @override
  String get authPasswordResetSuccess => 'Password reimpostata. Accedi.';

  @override
  String get authPasswordResetFailed => 'Reimpostazione password fallita';

  @override
  String get authUnexpectedError =>
      'Si è verificato un errore imprevisto. Riprova.';

  @override
  String get authUpdatePassword => 'Aggiorna password';

  @override
  String get authSecureAccountTitle => 'Metti al sicuro l\'account';

  @override
  String get authUnableToAccessKeys =>
      'Impossibile accedere alle tue chiavi. Riprova.';

  @override
  String get authRegistrationFailed => 'Registrazione fallita';

  @override
  String get authRegistrationComplete =>
      'Registrazione completata. Controlla la tua email.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'Impossibile inviare l\'email di reimpostazione.';

  @override
  String get authSending => 'Invio...';

  @override
  String get authSignInButton => 'Accedi';

  @override
  String get authVerificationErrorTimeout =>
      'Verifica scaduta. Prova a registrarti di nuovo.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verifica fallita — codice di autorizzazione mancante.';

  @override
  String get authVerificationErrorPollFailed => 'Verifica fallita. Riprova.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Errore di rete durante l\'accesso. Riprova.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verifica fallita. Prova a registrarti di nuovo.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Accesso fallito. Prova ad accedere manualmente.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Questa email è già registrata. Accedi invece.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Il codice non corrisponde. Ricontrollalo e riprova.';

  @override
  String get authVerificationErrorPinExpired =>
      'Il codice è scaduto. Tocca Invia di nuovo per riceverne uno nuovo.';

  @override
  String get authVerificationErrorPinLocked =>
      'Troppi tentativi. Tocca Invia di nuovo per ricevere un nuovo codice.';

  @override
  String get authVerificationErrorPinFailed =>
      'Non siamo riusciti a verificare il codice. Riprova.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'L\'inserimento del codice non è disponibile al momento. Tocca il link nella tua email, o invia di nuovo per riceverne uno nuovo.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Inserisci un codice di invito come ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Questo codice di invito non sembra valido.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Questo codice di invito è già stato usato o revocato.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Gli inviti di questo creator sono esauriti';

  @override
  String get authInviteGateErrorUnavailable =>
      'Questo codice di invito non è disponibile. Iscriviti alla lista d\'attesa e ti manderemo un invito appena si libera un posto.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Non siamo riusciti a verificare il codice. Riprova.';

  @override
  String get authInviteGateErrorUnknown =>
      'Qualcosa è andato storto. Riprova con il tuo codice di invito.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Quel codice invito non è più disponibile. Torna al tuo codice invito, entra nella lista d\'attesa o contatta l\'assistenza.';

  @override
  String get authInviteErrorInvalid =>
      'Quel codice invito non può essere usato adesso. Torna al tuo codice invito, entra nella lista d\'attesa o contatta l\'assistenza.';

  @override
  String get authInviteErrorTemporary =>
      'Non siamo riusciti a confermare il tuo invito in questo momento. Torna al tuo codice invito e riprova, oppure contatta l\'assistenza.';

  @override
  String get authInviteErrorUnknown =>
      'Non siamo riusciti ad attivare il tuo invito. Torna al tuo codice invito, entra nella lista d\'attesa o contatta l\'assistenza.';

  @override
  String get shareSheetSave => 'Salva';

  @override
  String get shareSheetRemoveFromSaved => 'Rimuovi dai salvati';

  @override
  String get shareSheetSaveToGallery => 'Salva in galleria';

  @override
  String get shareSheetSaveWithWatermark => 'Salva con filigrana';

  @override
  String get shareSheetSaveVideo => 'Salva video';

  @override
  String get shareSheetAddToClips => 'Aggiungi ai clip';

  @override
  String get shareSheetNameClipTitle => 'Dai un nome a questo clip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Scegli un nome che riconoscerai nella tua libreria.';

  @override
  String get shareSheetClipTitleLabel => 'Titolo del clip';

  @override
  String get shareSheetSaveClip => 'Salva clip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\" salvato nei clip';
  }

  @override
  String get shareSheetUntitledClip => 'Clip senza titolo';

  @override
  String get shareSheetAddToClipsFailed => 'Impossibile aggiungere ai clip';

  @override
  String get shareSheetAddToList => 'Aggiungi a lista';

  @override
  String get shareSheetCopy => 'Copia';

  @override
  String get shareSheetShareVia => 'Condividi tramite';

  @override
  String get shareSheetEventJson => 'JSON evento';

  @override
  String get shareSheetEventId => 'ID evento';

  @override
  String get shareSheetMoreActions => 'Altre azioni';

  @override
  String get shareSheetCrosspost => 'Crosspost';

  @override
  String get crosspostSheetTitle => 'Fai crosspost di questo video';

  @override
  String get crosspostSheetSubtitle =>
      'Invialo alle tue piattaforme collegate. La pubblicazione può richiedere qualche minuto.';

  @override
  String get crosspostSubmit => 'Crosspost';

  @override
  String get crosspostStatusQueued => 'In coda';

  @override
  String get crosspostStatusUploading => 'Caricamento';

  @override
  String get crosspostStatusProcessing => 'Elaborazione';

  @override
  String get crosspostStatusPosted => 'Pubblicato';

  @override
  String get crosspostStatusFailed => 'Fallito';

  @override
  String get crosspostStatusSkipped => 'Saltato';

  @override
  String get crosspostStatusNeedsReauth => 'Riconnessione necessaria';

  @override
  String get crosspostViewPost => 'Vedi post';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Ricollega $platform nelle impostazioni di crosspost per continuare a pubblicare.';
  }

  @override
  String get crosspostReconnect => 'Ricollega';

  @override
  String get crosspostErrorNotOwner =>
      'Puoi fare crosspost solo dei tuoi video.';

  @override
  String get crosspostErrorNotEligible =>
      'Questo video non è idoneo per il crosspost.';

  @override
  String get crosspostErrorNotConnected =>
      'Quella piattaforma non è collegata.';

  @override
  String get crosspostErrorUnauthorized =>
      'Ricollega il tuo account, poi riprova.';

  @override
  String get crosspostErrorNetwork =>
      'Impossibile raggiungere il crossposter. Riprova tra un attimo.';

  @override
  String get crosspostFailedGeneric => 'Crosspost non riuscito.';

  @override
  String get crosspostStillWorking =>
      'Ancora in corso. Puoi chiudere — la pubblicazione continua in background.';

  @override
  String get crosspostDone => 'Fatto';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Salvato nel rullino';

  @override
  String get watermarkDownloadShare => 'Condividi';

  @override
  String get watermarkDownloadDone => 'Fatto';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Accesso a Foto necessario';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Per salvare i video, consenti l\'accesso a Foto nelle Impostazioni.';

  @override
  String get watermarkDownloadOpenSettings => 'Apri impostazioni';

  @override
  String get watermarkDownloadNotNow => 'Non ora';

  @override
  String get watermarkDownloadFailed => 'Download fallito';

  @override
  String get watermarkDownloadDismiss => 'Ignora';

  @override
  String get watermarkDownloadStageDownloading => 'Download video';

  @override
  String get watermarkDownloadStageWatermarking => 'Aggiunta filigrana';

  @override
  String get watermarkDownloadStageSaving => 'Salvataggio nel rullino';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Recupero del video dalla rete...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Applicazione della filigrana Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Salvataggio del video con filigrana nel tuo rullino...';

  @override
  String get shareMenuBookmarks => 'Segnalibri';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count set di follow disponibili';
  }

  @override
  String get peopleListsAddToList => 'Aggiungi alla lista';

  @override
  String get peopleListsSheetTitle => 'Aggiungi alla lista';

  @override
  String get peopleListsEmptyTitle => 'Ancora nessuna lista';

  @override
  String get peopleListsEmptySubtitle =>
      'Crea una lista per iniziare a raggruppare le persone.';

  @override
  String get peopleListsCreateList => 'Crea lista';

  @override
  String get peopleListsNewListTitle => 'Nuova lista';

  @override
  String get peopleListsRouteTitle => 'Lista persone';

  @override
  String get peopleListsListNameLabel => 'Nome lista';

  @override
  String get peopleListsListNameHint => 'Amici stretti';

  @override
  String get peopleListsCreateButton => 'Crea';

  @override
  String get peopleListsAddPeopleTitle => 'Aggiungi persone';

  @override
  String get peopleListsAddPeopleTooltip => 'Aggiungi persone';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Aggiungi persone alla lista';

  @override
  String get peopleListsListNotFoundTitle => 'Lista non trovata';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lista non trovata. Potrebbe essere stata eliminata.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Questa lista potrebbe essere stata eliminata.';

  @override
  String get peopleListsNoPeopleTitle => 'Nessuna persona in questa lista';

  @override
  String get peopleListsNoPeopleSubtitle => 'Aggiungi persone per iniziare';

  @override
  String get peopleListsNoVideosTitle => 'Ancora nessun video';

  @override
  String get peopleListsNoVideosSubtitle =>
      'I video dei membri della lista appariranno qui';

  @override
  String get peopleListsNoVideosAvailable => 'Nessun video disponibile';

  @override
  String get peopleListsFailedToLoadVideos => 'Impossibile caricare i video';

  @override
  String get peopleListsVideoNotAvailable => 'Video non disponibile';

  @override
  String get peopleListsBackToGridTooltip => 'Torna alla griglia';

  @override
  String get peopleListsErrorLoadingVideos =>
      'Errore nel caricamento dei video';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Nessuna persona disponibile da aggiungere.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Aggiungi a $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Cerca persone';

  @override
  String get peopleListsAddPeopleError =>
      'Impossibile caricare le persone. Riprova.';

  @override
  String get peopleListsAddPeopleRetry => 'Riprova';

  @override
  String get peopleListsAddButton => 'Aggiungi';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Aggiungi $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count liste',
      one: 'In 1 lista',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'Verrà rimosso/a da questa lista.';

  @override
  String get peopleListsRemove => 'Rimuovi';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name rimosso/a dalla lista';
  }

  @override
  String get peopleListsUndo => 'Annulla';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profilo di $name. Tieni premuto per rimuovere.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Visualizza profilo di $name';
  }

  @override
  String get shareMenuEditVideo => 'Modifica video';

  @override
  String get shareMenuDeleteVideo => 'Elimina video';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Questo eliminerà definitivamente questo video da Divine. Potrebbe ancora comparire su client Nostr di terze parti che usano altri relay.';

  @override
  String get shareMenuCancel => 'Annulla';

  @override
  String get shareMenuDelete => 'Elimina';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'L\'eliminazione non è ancora pronta. Riprova tra un attimo.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Puoi eliminare solo i tuoi video.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Accedi di nuovo, poi riprova a eliminare.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Non è stato possibile firmare la richiesta di eliminazione. Riprova.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Il relay non ha accettato questa richiesta di eliminazione. Riprova tra poco.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Non è stato possibile raggiungere il relay. Controlla la connessione e riprova.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Eliminato. Non tutti i relay hanno confermato, quindi potrebbe comparire ancora in altre app.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Non è stato possibile eliminare questo video. Riprova.';

  @override
  String get shareMenuUpdate => 'Aggiorna';

  @override
  String get shareMenuChangeCover => 'Cambia copertina';

  @override
  String get shareMenuVideoUpdated => 'Video aggiornato con successo';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inviti ai collaboratori non sono stati inviati.',
      one: '1 invito ai collaboratori non è stato inviato.',
    );
    return 'Video aggiornato, ma $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Accedi di nuovo, poi riprova.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Questo video non ha una sorgente riproducibile, quindi non può essere modificato.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Impossibile firmare la modifica. Riprova.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Il relay non ha accettato la modifica. Riprova tra poco.';

  @override
  String get videoUpdateErrorGeneric =>
      'Impossibile aggiornare questo video. Riprova.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Eliminare il video?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Rimozione del video…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Video eliminato.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Video eliminato. Potrebbe volerci un po’ prima che scompaia ovunque.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Video eliminato, ma non siamo riusciti a rimuovere tutte le copie. Contatta l’assistenza.';

  @override
  String get authSessionExpired =>
      'La tua sessione è scaduta. Accedi di nuovo.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Accesso fallito. Riprova.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Autenticazione web non supportata in modalità sicura. Usa l\'app mobile per una gestione sicura delle chiavi.';

  @override
  String get webAuthEnterBunkerUri => 'Inserisci un URI bunker';

  @override
  String get webAuthConnectTitle => 'Connettiti a Divine';

  @override
  String get webAuthChooseMethod =>
      'Scegli il tuo metodo di autenticazione Nostr preferito';

  @override
  String get webAuthBrowserExtension => 'Estensione browser';

  @override
  String get webAuthRecommended => 'CONSIGLIATO';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Connettiti a un signer remoto';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Incolla dagli appunti';

  @override
  String get webAuthConnectToBunker => 'Connettiti al bunker';

  @override
  String get webAuthNewToNostr => 'Nuovo su Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Installa un\'estensione browser come Alby o nos2x per l\'esperienza più semplice, o usa nsec bunker per la firma remota sicura.';

  @override
  String get soundsTitle => 'Suoni';

  @override
  String get soundsSearchHint => 'Cerca suoni...';

  @override
  String get soundsSearchResults => 'Risultati ricerca';

  @override
  String get soundsNoSoundsFound => 'Nessun suono trovato';

  @override
  String get soundsNoSoundsFoundDescription =>
      'Prova un termine di ricerca diverso';

  @override
  String get soundsSavedToLibrary => 'Salvato in Suoni';

  @override
  String get soundsAlreadySavedToLibrary => 'Già in Suoni';

  @override
  String get soundsSavedLibraryTitle => 'I miei suoni';

  @override
  String get soundsSavedEmptyTitle => 'Nessun suono salvato';

  @override
  String get soundsSavedEmptyDescription =>
      'Tocca Usa suono su un video per salvarlo qui.';

  @override
  String get soundsRemoveSavedSound => 'Rimuovi suono';

  @override
  String get savedSoundSaveAction => 'Salva';

  @override
  String get savedSoundPausePreviewAction => 'Metti in pausa l\'anteprima';

  @override
  String get savedSoundResumePreviewAction => 'Riprendi anteprima';

  @override
  String get savedSoundDetailsSheetTitle => 'Dettagli del suono';

  @override
  String get savedSoundRemoveConfirmTitle => 'Vuoi rimuovere questo suono?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Sparisce dalla tua libreria, ma puoi salvarlo di nuovo da qualsiasi video che lo usa.';

  @override
  String get soundsRemovedFromLibrary => 'Rimosso da Suoni';

  @override
  String get soundsSaveFailed =>
      'Non è stato possibile salvare quel suono. Riprova.';

  @override
  String get soundsRemoveFailed =>
      'Non è stato possibile rimuovere quel suono. Riprova.';

  @override
  String get soundSyncStatusSyncing => 'Sincronizzazione dei tuoi suoni…';

  @override
  String get soundSyncStatusSynced => 'Suoni aggiornati';

  @override
  String get soundSyncStatusFailed =>
      'Non siamo riusciti a sincronizzare i tuoi suoni. Riproveremo.';

  @override
  String get soundSyncStatusLocked =>
      'Impossibile sbloccare la tua libreria sincronizzata su questo dispositivo.';

  @override
  String get profileTitle => 'Profilo';

  @override
  String get profileMoreOptions => 'Altre opzioni';

  @override
  String profileBlockedUser(String name) {
    return '$name bloccato';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name sbloccato';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Hai smesso di seguire $name';
  }

  @override
  String get profileFeedError =>
      'Impossibile raggiungere il server. Controlla la connessione e riprova.';

  @override
  String get profileFeedLoadMoreError =>
      'Non è stato possibile caricare altri video. Trascina per aggiornare.';

  @override
  String get notificationsTabAll => 'Tutte';

  @override
  String get notificationsTabLikes => 'Mi piace';

  @override
  String get notificationsTabComments => 'Commenti';

  @override
  String get notificationsTabFollows => 'Follow';

  @override
  String get notificationsTabReposts => 'Repost';

  @override
  String get notificationsFailedToLoad => 'Impossibile caricare le notifiche';

  @override
  String get notificationsRetry => 'Riprova';

  @override
  String get notificationsRefreshError =>
      'Aggiornamento non riuscito — mostro ciò che hai';

  @override
  String get notificationsUnreadPrefix => 'Notifica non letta';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifiche non lette',
      one: '1 notifica non letta',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Vedi il profilo di $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Vedi profili';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Anteprima del video $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Anteprima del video';

  @override
  String get notificationsInviteSingular =>
      'Hai 1 invito da condividere con un amico!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Hai $count inviti da condividere con gli amici!';
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
  String get notificationsVideoUnavailable => 'Video non disponibile';

  @override
  String get feedFailedToLoadVideos => 'Impossibile caricare i video';

  @override
  String get feedRetry => 'Riprova';

  @override
  String get feedNoFollowedUsers =>
      'Nessun utente seguito.\nSegui qualcuno per vedere i suoi video qui.';

  @override
  String get feedModeForYou => 'Per te';

  @override
  String get feedModeNew => 'Nuovo';

  @override
  String get feedModeFollowing => 'Seguiti';

  @override
  String get feedModeClassics => 'Classici';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Modalità feed: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Autore del video: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar dell\'autore';

  @override
  String get feedForYouEmpty =>
      'Il tuo feed Per te è vuoto.\nEsplora i video e segui i creator per personalizzarlo.';

  @override
  String get feedFollowingEmpty =>
      'Ancora nessun video dalle persone che segui.\nTrova creator che ti piacciono e seguili.';

  @override
  String get feedLatestEmpty =>
      'Ancora nessun nuovo video.\nTorna a controllare a breve.';

  @override
  String get feedClassicEmpty =>
      'Ancora nessun classico.\nTorna a controllare a breve.';

  @override
  String get feedExploreVideos => 'Esplora video';

  @override
  String get feedLoadingMore => 'Caricamento di altri video…';

  @override
  String get feedRefreshed => 'Feed aggiornato';

  @override
  String get uploadUploadingVideo => 'Caricamento video';

  @override
  String get postPublishConfirmationTitle => 'Pubblicato sul tuo profilo';

  @override
  String get postPublishConfirmationView => 'Guarda';

  @override
  String get postPublishConfirmationShare => 'Condividi';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Anteprima del video che hai appena pubblicato';

  @override
  String get userSearchNoResults => 'Nessun utente trovato';

  @override
  String get userPickerFilterByNameHint => 'Filtra per nome...';

  @override
  String get userPickerSearchByNameHint => 'Cerca per nome...';

  @override
  String get userPickerClearSearchSemantics => 'Cancella ricerca';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name già aggiunto';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Seleziona $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Rimuovi $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'La tua crew è là fuori';

  @override
  String get userPickerEmptyFollowListBody =>
      'Segui persone con cui vai d\'accordo. Quando ti seguono a loro volta, potete collaborare.';

  @override
  String get userPickerGoBack => 'Indietro';

  @override
  String get userPickerTypeNameToSearch => 'Digita un nome per cercare';

  @override
  String get userPickerUnavailable =>
      'La ricerca utenti non è disponibile. Riprova più tardi.';

  @override
  String get userPickerSearchFailedTryAgain => 'Ricerca non riuscita. Riprova.';

  @override
  String get forgotPasswordTitle => 'Reimposta password';

  @override
  String get forgotPasswordDescription =>
      'Inserisci il tuo indirizzo email e ti manderemo un link per reimpostare la password.';

  @override
  String get forgotPasswordEmailLabel => 'Indirizzo email';

  @override
  String get forgotPasswordCancel => 'Annulla';

  @override
  String get forgotPasswordSendLink => 'Invia link via email';

  @override
  String get ageVerificationContentWarning => 'Avviso sui contenuti';

  @override
  String get ageVerificationTitle => 'Verifica età';

  @override
  String get ageVerificationAdultDescription =>
      'Questo contenuto è stato segnalato come potenzialmente contenente materiale per adulti. Devi avere 18 anni o più per vederlo.';

  @override
  String get ageVerificationCreationDescription =>
      'Per usare la fotocamera e creare contenuti, devi avere almeno 16 anni.';

  @override
  String get ageVerificationAdultQuestion => 'Hai 18 anni o più?';

  @override
  String get ageVerificationCreationQuestion => 'Hai 16 anni o più?';

  @override
  String get ageVerificationNo => 'No';

  @override
  String get ageVerificationYes => 'Sì';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Esplora';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profilo';

  @override
  String get navMyProfile => 'Il mio profilo';

  @override
  String get navNotifications => 'Notifiche';

  @override
  String get navOpenCamera => 'Apri fotocamera';

  @override
  String get navExploreClassics => 'Classici';

  @override
  String get navExploreNewVideos => 'Nuovi video';

  @override
  String get navExploreTrending => 'Di tendenza';

  @override
  String get navExploreForYou => 'Per te';

  @override
  String get navExploreLists => 'Liste';

  @override
  String get routeErrorTitle => 'Errore';

  @override
  String get routeInvalidHashtag => 'Hashtag non valido';

  @override
  String get routeInvalidConversationId => 'ID conversazione non valido';

  @override
  String get routeInvalidRequestId => 'ID richiesta non valido';

  @override
  String get routeInvalidListId => 'ID lista non valido';

  @override
  String get routeInvalidUserId => 'ID utente non valido';

  @override
  String get routeInvalidVideoId => 'ID video non valido';

  @override
  String get routeInvalidSoundId => 'ID audio non valido';

  @override
  String get routeInvalidCategory => 'Categoria non valida';

  @override
  String get routeNoVideosToDisplay => 'Nessun video da mostrare';

  @override
  String get routeGoHome => 'Vai alla home';

  @override
  String get routeInvalidProfileId => 'ID profilo non valido';

  @override
  String get routeUnknownPath => 'Quella pagina non è nell’app.';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Centro assistenza';

  @override
  String get supportContactSupport => 'Contatta l\'assistenza';

  @override
  String get supportContactSupportSubtitle =>
      'Inizia una conversazione o vedi i messaggi passati';

  @override
  String get supportReportBug => 'Segnala un bug';

  @override
  String get supportReportBugSubtitle => 'Problemi tecnici con l\'app';

  @override
  String get supportRequestFeature => 'Richiedi una funzionalità';

  @override
  String get supportRequestFeatureSubtitle =>
      'Suggerisci un miglioramento o una nuova funzionalità';

  @override
  String get supportSaveLogs => 'Salva log';

  @override
  String get supportSaveLogsSubtitle =>
      'Esporta i log in un file per l\'invio manuale';

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
  String get supportFaqSubtitle => 'Domande frequenti e risposte';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Aiutiamo genitori e adolescenti a costruire abitudini sane online';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Come gestiamo gli account in base all\'età';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Scopri di più su verifica e autenticità';

  @override
  String get supportLoginRequired => 'Accedi per contattare l\'assistenza';

  @override
  String get supportExportingLogs => 'Esportazione log...';

  @override
  String get supportExportLogsFailed => 'Esportazione log fallita';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Log salvati in $path';
  }

  @override
  String get supportRevealLogsAction => 'Mostra nella cartella';

  @override
  String get supportChatNotAvailable => 'Chat di assistenza non disponibile';

  @override
  String get supportCouldNotOpenMessages =>
      'Impossibile aprire i messaggi di assistenza';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Impossibile aprire $pageName';
  }

  @override
  String get reportWhyReporting => 'Perché stai segnalando questo contenuto?';

  @override
  String get reportPolicyNotice =>
      'Divine agirà sulle segnalazioni di contenuti entro 24 ore rimuovendo il contenuto ed espellendo l\'utente che ha fornito il contenuto offensivo.';

  @override
  String get reportBlockUser => 'Blocca questo utente';

  @override
  String get reportCancel => 'Annulla';

  @override
  String get reportSubmit => 'Segnala';

  @override
  String get reportSelectReason =>
      'Seleziona un motivo per segnalare questo contenuto';

  @override
  String get reportOtherRequiresDetails =>
      'Descrivi il problema quando selezioni Altro';

  @override
  String get reportDetailsRequired => 'Descrivi il problema';

  @override
  String get reportDetailsTextOnly =>
      'Solo testo: qui non puoi allegare foto o GIF.';

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
  String get reportReasonSpam => 'Spam o contenuto indesiderato';

  @override
  String get reportReasonSpamSubtitle => 'Contenuto indesiderato o ripetitivo';

  @override
  String get reportReasonHarassment => 'Molestie, bullismo o minacce';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Risposte o menzioni dannose e indesiderate';

  @override
  String get reportReasonViolence => 'Contenuto violento o estremista';

  @override
  String get reportReasonViolenceSubtitle =>
      'Contenuto violento, estremista o dannoso';

  @override
  String get reportReasonSexualContent => 'Contenuto sessuale o per adulti';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nudità, pornografia o contenuto esplicito';

  @override
  String get reportReasonCopyright => 'Violazione del copyright';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Uso non autorizzato di proprietà intellettuale';

  @override
  String get reportReasonFalseInfo => 'Informazioni false';

  @override
  String get reportReasonFalseInfoSubtitle => 'Affermazioni fuorvianti o false';

  @override
  String get reportReasonChildSafety => 'Violazione della sicurezza dei minori';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Preoccupazioni generali sulla sicurezza dei minori';

  @override
  String get reportReasonCsam => 'Abuso sessuale su minori';

  @override
  String get reportReasonCsamSubtitle =>
      'Contenuti che raffigurano abusi sessuali su minori';

  @override
  String get reportReasonUnderageUser =>
      'L\'utente sembra avere meno di 16 anni';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Il titolare dell\'account sembra essere minorenne';

  @override
  String get reportReasonAiGenerated => 'Contenuto generato da IA';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Contenuto sospettato di essere generato dall\'IA';

  @override
  String get reportReasonOther => 'Altra violazione delle policy';

  @override
  String get reportReasonOtherSubtitle => 'Violazioni non elencate sopra';

  @override
  String get reportFailed => 'Impossibile segnalare il contenuto. Riprova.';

  @override
  String get reportNotSent =>
      'Impossibile inviare la segnalazione. Controlla la connessione e riprova.';

  @override
  String get reportReceivedTitle => 'Segnalazione ricevuta';

  @override
  String get reportReceivedThankYou =>
      'Grazie per aiutarci a mantenere Divine sicuro.';

  @override
  String get reportReceivedReviewNotice =>
      'Il nostro team esaminerà la tua segnalazione e prenderà i provvedimenti del caso. Potresti ricevere aggiornamenti tramite messaggio diretto.';

  @override
  String get reportModerationDmDelayed =>
      'Non siamo riusciti a contattare direttamente il team di moderazione in questo momento, ma la tua segnalazione è stata ricevuta e sarà esaminata.';

  @override
  String get reportContactModeration => 'Scrivi al team di moderazione';

  @override
  String get reportLearnMoreAt => 'Scopri di più su';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Chiudi';

  @override
  String get listAddToList => 'Aggiungi a lista';

  @override
  String listVideoCount(int count) {
    return '$count video';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count persone',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Di ';

  @override
  String get listNewList => 'Nuova lista';

  @override
  String get listDone => 'Fatto';

  @override
  String get listErrorLoading => 'Errore nel caricamento delle liste';

  @override
  String listRemovedFrom(String name) {
    return 'Rimosso da $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Aggiunto a $name';
  }

  @override
  String get listCreateNewList => 'Crea nuova lista';

  @override
  String get listNewPeopleList => 'Nuova lista persone';

  @override
  String get listCollaboratorsNone => 'Nessuno';

  @override
  String get listAddCollaboratorTitle => 'Aggiungi un collaboratore';

  @override
  String get listCollaboratorSearchHint => 'Cerca su Divine...';

  @override
  String get listNameLabel => 'Nome lista';

  @override
  String get listDescriptionLabel => 'Descrizione (opzionale)';

  @override
  String get listPublicList => 'Lista pubblica';

  @override
  String get listPublicListSubtitle =>
      'Altri possono seguire e vedere questa lista';

  @override
  String get listPrivateListSubtitle =>
      'I video restano privati. Nome, descrizione, tag e copertina restano visibili.';

  @override
  String get listVisibilityPublic => 'Pubblica';

  @override
  String get listVisibilityPrivate => 'Privata';

  @override
  String get profileListsEmpty =>
      'Ancora nessuna lista. Creane una per i loop che vuoi tenere insieme.';

  @override
  String get listEditTitle => 'Modifica lista';

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
  String get listShareAction => 'Condividi lista';

  @override
  String get listShareFailed =>
      'Impossibile condividere questa lista. Riprova.';

  @override
  String get listSave => 'Salva';

  @override
  String get listContinue => 'Continua';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Impossibile aggiornare questa lista. Riprova.';

  @override
  String get listMakePrivateTitle => 'Rendere privata questa lista?';

  @override
  String get listMakePrivateWarning =>
      'I video vengono cifrati, così puoi vederli solo tu. Nome, descrizione, tag e copertina restano visibili, e le copie già condivise possono rimanere.';

  @override
  String get listMakePublicTitle => 'Rendere pubblica questa lista?';

  @override
  String get listMakePublicWarning =>
      'Chiunque abbia il link può vedere questa lista e i suoi video.';

  @override
  String listShareText(String name, String url) {
    return 'Guarda $name su Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name su Divine';
  }

  @override
  String get listCancel => 'Annulla';

  @override
  String get listCreate => 'Crea';

  @override
  String get listCreateFailed => 'Impossibile creare la lista';

  @override
  String get keyManagementTitle => 'Chiavi Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Cosa sono le chiavi Nostr?';

  @override
  String get keyManagementExplanation =>
      'La tua identità Nostr è una coppia di chiavi crittografiche:\n\n• La tua chiave pubblica (npub) è come il tuo nome utente - condividila liberamente\n• La tua chiave privata (nsec) è come la tua password - tienila segreta!\n\nLa tua nsec ti permette di accedere al tuo account su qualsiasi app Nostr.';

  @override
  String get keyManagementImportTitle => 'Importa chiave esistente';

  @override
  String get keyManagementImportSubtitle =>
      'Hai già un account Nostr? Incolla la tua chiave privata (nsec) per accedervi qui.';

  @override
  String get keyManagementImportButton => 'Importa chiave';

  @override
  String get keyManagementImportWarning =>
      'Questo sostituirà la tua chiave attuale!';

  @override
  String get keyManagementBackupTitle => 'Fai il backup della tua chiave';

  @override
  String get keyManagementBackupSubtitle =>
      'Salva la tua chiave privata (nsec) per usare il tuo account in altre app Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copia la mia chiave privata (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Non condividere mai la tua nsec con nessuno!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'La tua chiave è sul servizio di accesso di Divine, non su questo dispositivo. Conferma la password e la recuperiamo per te.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'La tua chiave è conservata dal servizio di accesso di Divine. Inserisci la password del tuo account e la recuperiamo.';

  @override
  String get keyManagementKeycastCopyKey => 'Copia la chiave';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Il tuo dispositivo ha bloccato la copia, quindi la tua chiave non è arrivata negli appunti.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'La password non corrisponde. Riprova.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Troppi tentativi. Chiudi e ricomincia.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Troppe richieste della chiave. Aspetta qualche minuto e riprova.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'La tua sessione è scaduta. Accedi di nuovo per copiare la chiave.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Verifica il tuo indirizzo email prima di copiare la chiave.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine gestisce le chiavi di questo account, quindi non possono essere copiate qui.';

  @override
  String get keyManagementKeycastNoKey =>
      'Non c\'è nessuna chiave registrata per questo account.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Non è stato possibile raggiungere il servizio di accesso. Riprova.';

  @override
  String get keyManagementRestrictedTitle =>
      'Le tue chiavi sono gestite da Divine';

  @override
  String get keyManagementRestrictedBody =>
      'Per tenere al sicuro il tuo account, il backup della chiave e l\'importazione di un\'altra chiave non sono disponibili qui.';

  @override
  String get keyManagementPasteKey => 'Incolla la tua chiave privata';

  @override
  String get keyManagementInvalidFormat =>
      'Formato chiave non valido. Deve iniziare con \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importare questa chiave?';

  @override
  String get keyManagementConfirmImportBody =>
      'Questo sostituirà la tua identità attuale con quella importata.\n\nLa tua chiave attuale andrà persa a meno che tu non ne abbia fatto prima il backup.';

  @override
  String get keyManagementImportConfirm => 'Importa';

  @override
  String get keyManagementImportSuccess => 'Chiave importata con successo!';

  @override
  String get keyManagementImportFailed =>
      'Impossibile importare la chiave. Riprova.';

  @override
  String get keyManagementExportSuccess =>
      'Chiave privata copiata negli appunti!\n\nConservala in un posto sicuro.';

  @override
  String get keyManagementExportFailed =>
      'Impossibile esportare la chiave. Riprova.';

  @override
  String get keyManagementYourPublicKeyLabel => 'La tua chiave pubblica (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copia chiave pubblica';

  @override
  String get keyManagementPublicKeyCopied => 'Chiave pubblica copiata';

  @override
  String get saveOriginalSavedToCameraRoll => 'Salvato nel rullino';

  @override
  String get saveOriginalShare => 'Condividi';

  @override
  String get saveOriginalDone => 'Fatto';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Accesso a Foto necessario';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Per salvare i video, consenti l\'accesso a Foto nelle Impostazioni.';

  @override
  String get saveOriginalOpenSettings => 'Apri impostazioni';

  @override
  String get saveOriginalNotNow => 'Non ora';

  @override
  String get saveOriginalDownloadFailed => 'Download fallito';

  @override
  String get saveOriginalDismiss => 'Ignora';

  @override
  String get saveOriginalDownloadingVideo => 'Download video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Salvataggio nel rullino';

  @override
  String get saveOriginalFetchingVideo => 'Recupero del video dalla rete...';

  @override
  String get saveOriginalSavingVideo =>
      'Salvataggio del video originale nel tuo rullino...';

  @override
  String get soundTitle => 'Audio';

  @override
  String get soundOriginalSound => 'Audio originale';

  @override
  String get soundVideosUsingThisSound => 'Video che usano questo audio';

  @override
  String get soundSourceVideo => 'Video sorgente';

  @override
  String get soundNoVideosYet => 'Ancora nessun video';

  @override
  String get soundBeFirstToUse => 'Sii il primo a usare questo audio!';

  @override
  String get soundFailedToLoadVideos => 'Impossibile caricare i video';

  @override
  String get soundRetry => 'Riprova';

  @override
  String get soundVideosUnavailable => 'Video non disponibili';

  @override
  String get soundCouldNotLoadDetails =>
      'Impossibile caricare i dettagli del video';

  @override
  String get soundPreview => 'Anteprima';

  @override
  String get soundStop => 'Stop';

  @override
  String get soundUseSound => 'Usa audio';

  @override
  String get soundUntitled => 'Audio senza titolo';

  @override
  String get soundStopPreview => 'Ferma anteprima';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Anteprima di $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Vedi dettagli di $title';
  }

  @override
  String get soundNoVideoCount => 'Ancora nessun video';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video';
  }

  @override
  String get soundUnableToPreview =>
      'Impossibile ascoltare l\'anteprima - nessun audio disponibile';

  @override
  String get soundPreviewFailed =>
      'Impossibile riprodurre l\'anteprima. Riprova.';

  @override
  String get soundViewSource => 'Vedi sorgente';

  @override
  String get soundCloseTooltip => 'Chiudi';

  @override
  String get exploreNotExploreRoute => 'Non è un percorso di esplorazione';

  @override
  String get legalTitle => 'Legale';

  @override
  String get legalTermsOfService => 'Termini di servizio';

  @override
  String get legalTermsOfServiceSubtitle => 'Termini e condizioni d\'uso';

  @override
  String get legalPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get legalPrivacyPolicySubtitle => 'Come gestiamo i tuoi dati';

  @override
  String get legalSafetyStandards => 'Standard di sicurezza';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Linee guida della community e sicurezza';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Politica su copyright e rimozioni';

  @override
  String get legalOpenSourceLicenses => 'Licenze open source';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Attribuzioni pacchetti di terze parti';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Impossibile aprire $pageName';
  }

  @override
  String get categoryAction => 'Azione';

  @override
  String get categoryAdventure => 'Avventura';

  @override
  String get categoryAnimals => 'Animali';

  @override
  String get categoryAnimation => 'Animazione';

  @override
  String get categoryArchitecture => 'Architettura';

  @override
  String get categoryArt => 'Arte';

  @override
  String get categoryAutomotive => 'Auto';

  @override
  String get categoryAwardShow => 'Premiazione';

  @override
  String get categoryAwards => 'Premi';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basket';

  @override
  String get categoryBeauty => 'Bellezza';

  @override
  String get categoryBeverage => 'Bevande';

  @override
  String get categoryCars => 'Auto';

  @override
  String get categoryCelebration => 'Festa';

  @override
  String get categoryCelebrities => 'Celebrità';

  @override
  String get categoryCelebrity => 'Celebrità';

  @override
  String get categoryCityscape => 'Panorama urbano';

  @override
  String get categoryComedy => 'Commedia';

  @override
  String get categoryConcert => 'Concerto';

  @override
  String get categoryCooking => 'Cucina';

  @override
  String get categoryCostume => 'Costume';

  @override
  String get categoryCrafts => 'Fai da te';

  @override
  String get categoryCrime => 'Crimine';

  @override
  String get categoryCulture => 'Cultura';

  @override
  String get categoryDance => 'Danza';

  @override
  String get categoryDiy => 'Fai da te';

  @override
  String get categoryDrama => 'Drammatico';

  @override
  String get categoryEducation => 'Educazione';

  @override
  String get categoryEmotional => 'Emotivo';

  @override
  String get categoryEmotions => 'Emozioni';

  @override
  String get categoryEntertainment => 'Intrattenimento';

  @override
  String get categoryEvent => 'Evento';

  @override
  String get categoryFamily => 'Famiglia';

  @override
  String get categoryFans => 'Fan';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Cibo';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Arredamento';

  @override
  String get categoryGaming => 'Videogiochi';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Cura personale';

  @override
  String get categoryGuitar => 'Chitarra';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Salute';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Vacanze';

  @override
  String get categoryHome => 'Casa';

  @override
  String get categoryHomeImprovement => 'Ristrutturazione';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Ospedale';

  @override
  String get categoryHumor => 'Umorismo';

  @override
  String get categoryInteriorDesign => 'Interior design';

  @override
  String get categoryInterview => 'Intervista';

  @override
  String get categoryKids => 'Bambini';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magia';

  @override
  String get categoryMakeup => 'Trucco';

  @override
  String get categoryMedical => 'Medico';

  @override
  String get categoryMusic => 'Musica';

  @override
  String get categoryMystery => 'Mistero';

  @override
  String get categoryNature => 'Natura';

  @override
  String get categoryNews => 'Notizie';

  @override
  String get categoryOutdoor => 'Outdoor';

  @override
  String get categoryParty => 'Festa';

  @override
  String get categoryPeople => 'Persone';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Animali domestici';

  @override
  String get categoryPolitics => 'Politica';

  @override
  String get categoryPrank => 'Scherzo';

  @override
  String get categoryPranks => 'Scherzi';

  @override
  String get categoryRealityShow => 'Reality';

  @override
  String get categoryRelationship => 'Relazione';

  @override
  String get categoryRelationships => 'Relazioni';

  @override
  String get categoryRomance => 'Romantico';

  @override
  String get categorySchool => 'Scuola';

  @override
  String get categoryScienceFiction => 'Fantascienza';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboard';

  @override
  String get categorySkincare => 'Cura della pelle';

  @override
  String get categorySoccer => 'Calcio';

  @override
  String get categorySocialGathering => 'Ritrovo';

  @override
  String get categorySocialMedia => 'Social media';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Tecnologia';

  @override
  String get categoryTelevision => 'Televisione';

  @override
  String get categoryToys => 'Giocattoli';

  @override
  String get categoryTransportation => 'Trasporti';

  @override
  String get categoryTravel => 'Viaggi';

  @override
  String get categoryUrban => 'Urbano';

  @override
  String get categoryViolence => 'Violenza';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadStaged => 'Caricata — tocca Salva per applicare';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName segnalato/a';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName bloccato/a';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName sbloccato/a';
  }

  @override
  String get inboxRemovedConversation => 'Conversazione rimossa';

  @override
  String get inboxRestorePausedTitle =>
      'Alcune chat non sono state ripristinate del tutto';

  @override
  String get conversationRestorePausedTitle =>
      'Questa chat non è stata ripristinata del tutto';

  @override
  String get inboxRestoreRetryAction => 'Riprova';

  @override
  String get inboxRestoringMessages => 'Ripristino dei messaggi…';

  @override
  String get inboxEmptyTitle => 'Ancora nessun messaggio';

  @override
  String get inboxEmptySubtitle => 'Il pulsante + non morde.';

  @override
  String get inboxLoadErrorTitle => 'I messaggi non si sono caricati';

  @override
  String get inboxLoadErrorSubtitle => 'Controlla la connessione e riprova.';

  @override
  String get inboxFilterAll => 'Tutti';

  @override
  String get inboxFilterUnread => 'Non letti';

  @override
  String get dmBlockedThreadTitle => 'Hai bloccato questo account';

  @override
  String get dmBlockedThreadBody =>
      'I messaggi restano qui così puoi leggerli o farne uno screenshot. Sblocca per rispondere.';

  @override
  String get inboxFilterBlocked => 'Bloccati';

  @override
  String get inboxBlockedEmptyTitle => 'Nessuna chat bloccata';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Gli account che blocchi compaiono qui.';

  @override
  String get inboxBlockedNoMessages => 'Nessun messaggio';

  @override
  String get inboxUnreadEmptyTitle => 'Sei in pari';

  @override
  String get inboxUnreadEmptySubtitle =>
      'Nessun messaggio non letto al momento.';

  @override
  String get inboxSearchHint => 'Cerca nei messaggi';

  @override
  String get inboxSupportRowTitle => 'Moderazione Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Bug, moderazione, questioni sull\'account: ti ascoltiamo.';

  @override
  String get inboxSearchEmptyTitle => 'Nessun risultato';

  @override
  String get inboxSearchEmptySubtitle =>
      'Prova con un altro nome o un\'altra parola.';

  @override
  String get inboxActionMute => 'Silenzia conversazione';

  @override
  String inboxActionReport(String displayName) {
    return 'Segnala $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Blocca $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Sblocca $displayName';
  }

  @override
  String get inboxActionRemove => 'Rimuovi conversazione';

  @override
  String get inboxRemoveConfirmTitle => 'Rimuovere la conversazione?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Questo rimuove la tua conversazione con $displayName dalla tua posta in arrivo. Se ti scrive di nuovo, inizia una nuova conversazione.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Questo rimuove la conversazione di gruppo dalla tua posta in arrivo. Se qualcuno scrive di nuovo nel gruppo, inizia una nuova conversazione.';

  @override
  String get inboxRemoveConfirmConfirm => 'Rimuovi';

  @override
  String get inboxConversationMuted => 'Conversazione silenziata';

  @override
  String get inboxConversationUnmuted => 'Conversazione riattivata';

  @override
  String get inboxCollabInviteCardTitle => 'Invito a collaborare';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video senza titolo';

  @override
  String get clickableTextViewVideoLink => 'Guarda il video';

  @override
  String get messageExternalLinkDialogTitle => 'Aprire il link esterno?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Questo link porta a un sito esterno e potrebbe non essere sicuro:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Apri';

  @override
  String get inboxCollabInviteCoPostButton => 'Co-pubblica';

  @override
  String get inboxCollabInviteNotMineButton => 'Non è mio';

  @override
  String get inboxCollabInvitePreviewTitle => 'Invito a co-pubblicare';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Invito a co-pubblicare da $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'La co-pubblicazione aggiunge questo video alla tua timeline come collaborazione.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Accettato';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorato';

  @override
  String get inboxCollabInviteAcceptError => 'Impossibile accettare. Riprova.';

  @override
  String get inboxCollabInviteSentStatus => 'Invito inviato';

  @override
  String get inboxConversationCollabInvitePreview => 'Invito a collaborare';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Sei stato invitato a collaborare a $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Sei stato invitato a collaborare a un video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inviti a collaborare non sono stati inviati.',
      one: '1 invito a collaborare non è stato inviato.',
    );
    return 'Video pubblicato, ma $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Non siamo riusciti a capire con chi è questa conversazione. Riaprila dalla posta in arrivo.';

  @override
  String get dmSendBlockedMessage =>
      'Puoi scrivere solo agli account ufficiali Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Nessuno legge questa conversazione. Scrivi a Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage =>
      'Non è stato possibile eliminare per tutti.';

  @override
  String get dmDeleteRefusedDetails =>
      'Alcune persone potrebbero ancora vedere questo messaggio.';

  @override
  String get dmRetiredThreadClosedTitle => 'Questa conversazione è chiusa.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Questo avviso di Divine Moderation non può essere rimosso.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Abbiamo spostato Divine Moderation su un nuovo account. Questo non lo legge più nessuno.';

  @override
  String get dmRetiredThreadOpenSupport => 'Scrivi a Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Impossibile inviare il messaggio';

  @override
  String get dmResendFailedMessage => 'Ancora impossibile inviare';

  @override
  String get dmSendFailedSubtitle =>
      'Invialo di nuovo ora, oppure smetti di provare.';

  @override
  String get dmSendFailedRetry => 'Riprova';

  @override
  String get dmSendPartialMessage =>
      'Inviato, ma non sincronizzato con gli altri tuoi dispositivi';

  @override
  String get dmConversationLoadError => 'Impossibile caricare i messaggi';

  @override
  String get dmMessageInputHint => 'Scrivi qualcosa…';

  @override
  String get dmMessageBubbleSentHint => 'Messaggio inviato';

  @override
  String get dmMessageBubbleReceivedHint => 'Messaggio ricevuto';

  @override
  String get dmMessageBubbleLongPressHint => 'Azioni messaggio';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Invia di nuovo o elimina questo messaggio';

  @override
  String get dmMessageActionCopyText => 'Copia testo';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copia URL del video';

  @override
  String get dmMessageActionDeleteForEveryone => 'Elimina per tutti';

  @override
  String get dmMessageActionReport => 'Segnala';

  @override
  String get dmMessageActionRetrySend => 'Invia di nuovo';

  @override
  String get dmMessageActionCancelSend => 'Smetti di provare';

  @override
  String get dmReactionAddCustomA11yLabel =>
      'Aggiungi una reazione emoji personalizzata';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Messaggio a $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Rispondi a te stesso…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Rispondi a questo reel';

  @override
  String get dmReelReplyViewChat => 'Vedi chat';

  @override
  String get dmReelReplySentAnnouncement => 'Risposta inviata';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Hai reagito $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Invio non riuscito';

  @override
  String get dmReelReplyUnverified => 'Invio non confermato';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'La tua reazione: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name ha reagito con $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Invio della reazione: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reazione non riuscita, tocca due volte per riprovare';

  @override
  String get dmReactionChipRetryAnnouncement =>
      'Nuovo tentativo per la reazione';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Completa la rimozione della reazione precedente prima di aggiungerne un\'altra.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reazioni';

  @override
  String get dmReactionsViewA11yLabel => 'Vedi chi ha reagito';

  @override
  String get dmReactionRemoveAction => 'Rimuovi';

  @override
  String get dmReactionRetryAction => 'Riprova';

  @override
  String get dmFormatBold => 'Grassetto';

  @override
  String get dmFormatItalic => 'Corsivo';

  @override
  String get dmFormatStrikethrough => 'Barrato';

  @override
  String get dmFormatCode => 'Codice';

  @override
  String get dmStatusFailed => 'Invio non riuscito';

  @override
  String get inboxConversationActionsSheetLabel => 'Azioni conversazione';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Conversazione con $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Non letta, conversazione con $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count altre persone',
      one: '$count altra persona',
    );
    return '$name e $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Mostra le azioni della conversazione';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Titolo: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Cerca...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count video';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Impossibile aggiornare l\'abbonamento. Riprova.';

  @override
  String get discoverListsTitle => 'Scopri liste';

  @override
  String get discoverListsFailedToLoad => 'Impossibile caricare le liste';

  @override
  String get discoverListsLoading => 'Cercando liste pubbliche...';

  @override
  String get discoverListsRelayTimeout =>
      'Il relay non ha restituito liste in tempo. Riprova.';

  @override
  String get discoverListsServiceUnavailable => 'Servizio non disponibile.';

  @override
  String get discoverListsEmptyTitle => 'Nessuna lista pubblica trovata';

  @override
  String get discoverListsEmptySubtitle => 'Torna più tardi per nuove liste';

  @override
  String get discoverListsByAuthorPrefix => 'di';

  @override
  String get curatedListEmptyTitle => 'Nessun video in questa lista';

  @override
  String get curatedListEmptySubtitle => 'Aggiungi qualche video per iniziare';

  @override
  String get curatedListLoadingVideos => 'Caricamento video...';

  @override
  String get curatedListFailedToLoad => 'Impossibile caricare la lista';

  @override
  String get curatedListVideoNotAvailable => 'Video non disponibile';

  @override
  String get curatedListActionsTooltip => 'Azioni lista';

  @override
  String get curatedListDeleteConfirmTitle => 'Eliminare la lista?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Questo rimuove la lista dai relay. I video nella lista non verranno eliminati.';

  @override
  String get curatedListDeletedSnack => 'Lista eliminata';

  @override
  String get curatedListDeleteFailed => 'Impossibile eliminare la lista';

  @override
  String get peopleListsActionsTooltip => 'Azioni lista';

  @override
  String get listDeleteAction => 'Elimina lista';

  @override
  String get peopleListsDeleteConfirmTitle => 'Eliminare la lista?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Questo rimuove la lista per tutti. Le persone al suo interno non verranno rimosse dai tuoi seguiti.';

  @override
  String get peopleListsDeleteFailed => 'Impossibile eliminare la lista';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonSomethingWentWrong => 'Qualcosa è andato storto';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonBack => 'Indietro';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonNotNow => 'Non ora';

  @override
  String get commonLoading => 'Caricamento';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Impossibile aggiornare la copertina. Riprova.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement =>
      'Copertina aggiornata';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Pubblicare senza la verifica di autenticità?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Non è stato possibile aggiungere le credenziali di contenuto, quindi questo video non sarà confermato come fatto da un umano. Rigenera per riprovare oppure pubblicalo così com’è.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Le credenziali di contenuto richiedono una connessione a internet.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Il servizio delle credenziali di contenuto non ha risposto. Non dipende dalla tua connessione.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Rigenera';

  @override
  String get videoMetadataC2paMissingSkip => 'Salta';

  @override
  String get videoMetadataGenerationFailed => 'Generazione non riuscita';

  @override
  String get videoMetadataTags => 'Tag';

  @override
  String get videoMetadataExpiration => 'Scadenza';

  @override
  String get videoMetadataExpirationNotExpire => 'Non scade';

  @override
  String get videoMetadataExpirationOneDay => '1 giorno';

  @override
  String get videoMetadataExpirationOneWeek => '1 settimana';

  @override
  String get videoMetadataExpirationOneMonth => '1 mese';

  @override
  String get videoMetadataExpirationOneYear => '1 anno';

  @override
  String get videoMetadataExpirationOneDecade => '1 decennio';

  @override
  String get videoMetadataContentWarnings => 'Avvisi sui contenuti';

  @override
  String get videoEditorStickers => 'Sticker';

  @override
  String get trendingTitle => 'Di tendenza';

  @override
  String get libraryDeleteConfirm => 'Elimina';

  @override
  String get libraryWebUnavailableHeadline => 'La libreria è nell’app mobile';

  @override
  String get libraryWebUnavailableDescription =>
      'Bozze e clip sono salvate sul dispositivo: apri Divine sul telefono per gestirle.';

  @override
  String get libraryTabDrafts => 'Bozze';

  @override
  String get libraryTabClips => 'Clip';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Elimina clip selezionate';

  @override
  String get libraryCloseSemanticLabel => 'Chiudi libreria';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Termina selezione clip';

  @override
  String get librarySelectClipsSemanticLabel => 'Seleziona clip';

  @override
  String get libraryGridSizeLabel => 'Dimensioni della griglia';

  @override
  String get libraryDisplayOptionsLabel => 'Ordinamento e dimensione griglia';

  @override
  String get libraryMoreActionsSemanticLabel => 'Altre azioni della libreria';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colonne',
      one: '1 colonna',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Seleziona';

  @override
  String get librarySortNewestCreation => 'Creazione più recente';

  @override
  String get librarySortOldestCreation => 'Creazione più vecchia';

  @override
  String get librarySortLongestClip => 'Clip più lungo';

  @override
  String get librarySortShortestClip => 'Clip più corto';

  @override
  String get librarySortSquareFirst => 'Prima i quadrati';

  @override
  String get librarySortVerticalFirst => 'Prima i verticali';

  @override
  String get libraryDeleteClipsWarning =>
      'Azione irreversibile. I file video verranno rimossi definitivamente dal dispositivo.';

  @override
  String get libraryPreparingVideo => 'Preparazione video...';

  @override
  String libraryCreateVideo(int count) {
    return 'Crea video ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip',
      one: '1 clip',
    );
    return '$_temp0 salvati in $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount salvati, $failureCount non riusciti';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Impossibile salvare in $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permesso negato per $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip eliminati',
      one: '1 clip eliminato',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Annulla';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Eliminazione automatica tra $daysLeft giorni',
      one: 'Eliminazione automatica domani',
      zero: 'Eliminazione automatica oggi',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Impossibile caricare le bozze';

  @override
  String get libraryCouldNotLoadClips => 'Impossibile caricare le clip';

  @override
  String get libraryOpenErrorDescription =>
      'Qualcosa è andato storto aprendo la libreria. Riprova.';

  @override
  String get libraryNoDraftsYetTitle => 'Ancora nessuna bozza';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'I video salvati come bozza appariranno qui';

  @override
  String get libraryNoClipsYetTitle => 'Ancora nessuna clip';

  @override
  String get libraryNoClipsYetSubtitle => 'Le clip registrate appariranno qui';

  @override
  String get libraryDraftDeletedSnackbar => 'Bozza eliminata';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Eliminazione bozza non riuscita';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Bozza duplicata';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Duplicazione bozza non riuscita';

  @override
  String get libraryDraftInProgressBadge => 'In corso';

  @override
  String get libraryDraftActionPost => 'Pubblica';

  @override
  String get libraryDraftActionEdit => 'Modifica';

  @override
  String get libraryDraftActionDuplicate => 'Duplica';

  @override
  String get libraryDraftActionDelete => 'Elimina bozza';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (copia $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Elimina bozza';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Vuoi eliminare \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Elimina clip';

  @override
  String get libraryDeleteClipMessage => 'Eliminare questa clip?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds s';
  }

  @override
  String get libraryRecordVideo => 'Registra un video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Clip video, $duration secondi';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Archiviato. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Clip in stop-motion, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Selezionato, numero $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Selezionato';

  @override
  String get videoClipSemanticValueNotSelected => 'Non selezionato';

  @override
  String get videoClipSemanticHintDisabled => 'Disabilitato';

  @override
  String get videoClipSemanticHintSelect =>
      'Tocca per selezionare, tieni premuto per anteprima';

  @override
  String get videoClipSemanticHintDeselect =>
      'Tocca per deselezionare, tieni premuto per anteprima';

  @override
  String get routerInvalidCreator => 'Creatore non valido';

  @override
  String get routerInvalidHashtagRoute => 'Percorso hashtag non valido';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Impossibile caricare i video';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Nessun video in questa categoria';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Opzioni di ordinamento categoria';

  @override
  String get categoryGallerySortHot => 'Popolari';

  @override
  String get categoryGallerySortNew => 'Nuovi';

  @override
  String get categoryGallerySortClassic => 'Classici';

  @override
  String get categoryGallerySortForYou => 'Per te';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Impossibile caricare le categorie';

  @override
  String get categoriesNoCategoriesAvailable => 'Nessuna categoria disponibile';

  @override
  String get notificationsEmptyTitle => 'Ancora nessuna attività';

  @override
  String get notificationsEmptySubtitle =>
      'Quando le persone interagiranno con i tuoi contenuti, lo vedrai qui';

  @override
  String get appsPermissionsTitle => 'Permessi delle integrazioni';

  @override
  String get appsPermissionsRevoke => 'Revoca';

  @override
  String get appsPermissionsEmptyTitle =>
      'Nessun permesso di integrazione salvato';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Le integrazioni approvate appariranno qui dopo che ricorderai un\'autorizzazione di accesso.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName chiede la tua approvazione';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Questa app sta chiedendo accesso tramite la sandbox verificata di Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Origine';

  @override
  String get nostrAppPermissionMethod => 'Metodo';

  @override
  String get nostrAppPermissionCapability => 'Capacità';

  @override
  String get nostrAppPermissionEventKind => 'Tipo di evento';

  @override
  String get nostrAppPermissionAllow => 'Consenti';

  @override
  String get appsDetailDefaultTitle => 'App integrata';

  @override
  String get appsDetailNotFoundTitle => 'Integrazione non trovata';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Questa integrazione approvata non è più disponibile in Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Come funziona';

  @override
  String get appsDetailHowItWorksBody =>
      'Questa è un\'app di terze parti approvata che funziona all\'interno di Divine. Divine concede solo funzionalità verificate per questa integrazione e blocca la navigazione al di fuori delle sue origini approvate.';

  @override
  String get appsDetailAboutTitle => 'Informazioni';

  @override
  String get appsDetailPrimaryOriginTitle => 'Origine primaria';

  @override
  String get appsDetailApprovedOriginsTitle => 'Origini approvate';

  @override
  String get appsDetailCapabilitiesTitle => 'Funzionalità disponibili';

  @override
  String get appsDetailAskBeforeTitle => 'Chiedi prima';

  @override
  String get appsDetailOpenButton => 'Apri integrazione';

  @override
  String get appsDetailNoneDeclared => 'Nessuna dichiarata ancora';

  @override
  String get appsDirectoryTitle => 'App integrate';

  @override
  String get appsDirectoryIntroTitle => 'App di terze parti approvate';

  @override
  String get appsDirectoryIntroBody =>
      'App di terze parti approvate che funzionano all\'interno di Divine';

  @override
  String get appsDirectoryErrorTitle => 'Impossibile caricare le app integrate';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Tira per riprovare a caricare le integrazioni approvate.';

  @override
  String get appsDirectoryEmptyTitle => 'Ancora nessuna integrazione approvata';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Le app di terze parti approvate appariranno qui man mano che Divine le aggiunge.';

  @override
  String get appsDirectoryRefresh => 'Aggiorna';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Le app integrate funzionano su Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Per ora le integrazioni approvate sono disponibili solo su mobile.';

  @override
  String get appsSandboxUnavailableTitle => 'Integrazione non disponibile';

  @override
  String get appsSandboxUnavailableBody =>
      'Apri le integrazioni approvate dalla scheda App integrate così Divine può applicare la giusta policy di accesso.';

  @override
  String get appsSandboxLoadingTitle => 'Caricamento integrazione';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Verifica dell\'integrazione approvata prima dell\'avvio.';

  @override
  String get appsSandboxBlockedTitle => 'Bloccato per sicurezza';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Questa integrazione ha tentato di uscire dalla sua origine approvata.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Link al post copiato negli appunti';

  @override
  String get shareCopiedEventJson =>
      'JSON dell\'evento Nostr copiato negli appunti';

  @override
  String get shareCopiedEventId =>
      'ID dell\'evento Nostr copiato negli appunti';

  @override
  String get authHeroTaglineAuthentic => 'Momenti autentici.';

  @override
  String get authHeroTaglineHuman => 'Creatività umana.';

  @override
  String get keyImportFailedToImport =>
      'Impossibile importare la chiave o connettersi al bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'URL bunker non valido';

  @override
  String get keyImportInvalidFormat =>
      'Formato non valido. Usa nsec..., hex, ncryptsec1... o bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Formato nsec non valido. Deve avere 63 caratteri';

  @override
  String get keyImportKeyFieldLabel => 'Chiave privata o URL bunker';

  @override
  String get keyImportKeyRequired =>
      'Inserisci la tua chiave privata o l\'URL bunker';

  @override
  String get keyImportPasswordRequired =>
      'Inserisci la password per questa chiave crittografata';

  @override
  String get keyImportSecurityWarningBody =>
      'Non condividere mai la tua chiave privata con nessuno. Questa chiave dà pieno accesso alla tua identità Nostr.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Tieni al sicuro la tua chiave privata!';

  @override
  String get keyImportSubtitle =>
      'Importa la tua identità Nostr esistente usando la tua chiave privata o un URL bunker.';

  @override
  String get keyImportTitle => 'Importa la tua\nidentità Nostr';

  @override
  String get commentAuthorYouIndicator => 'Tu';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Visualizza il profilo di $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Elimina commento';

  @override
  String get commentOptionsEditSemanticLabel => 'Modifica commento';

  @override
  String get commentOptionsFlagContentLabel => 'Segnala contenuto';

  @override
  String get commentOptionsFlagContentSemanticLabel =>
      'Segnala questo contenuto';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Seleziona un motivo per segnalare questo commento';

  @override
  String get commentOptionsFlagSubmit => 'Invia';

  @override
  String get commentOptionsTitle => 'Opzioni';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Stiamo ancora importando i vecchi commenti dall\'archivio. Non sono ancora pronti.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Modifica in corso';

  @override
  String get commentsInputSemanticHint => 'Aggiungi un commento';

  @override
  String get commentsInputSemanticHintEdit => 'Modifica commento';

  @override
  String get commentsInputSemanticHintReply => 'Aggiungi una risposta';

  @override
  String get commentsInputSemanticLabel => 'Campo commento';

  @override
  String get commentsInputSemanticLabelEdit => 'Campo di modifica';

  @override
  String get commentsInputSemanticLabelReply => 'Campo risposta';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Visualizza il profilo di $displayName';
  }

  @override
  String get classicsEmptyDescription =>
      'L\'archivio dei Classici è in caricamento';

  @override
  String get classicsEmptyTitle => 'Nessun Classico trovato';

  @override
  String get classicsErrorTitle => 'Impossibile caricare i Classici';

  @override
  String get classicsUnavailableDescription =>
      'I Classici sono disponibili solo quando sei connesso ai relay Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Passa a un relay abilitato per Funnelcake nelle Impostazioni per accedere all\'archivio dei Classici.';

  @override
  String get classicsUnavailableTitle => 'Classici non disponibili';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Sii il primo a pubblicare un video con questo hashtag!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Nessun video trovato per #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle =>
      'Potrebbe richiedere qualche istante';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Caricamento dei video su #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Aggiungi hashtag... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'Torna più tardi per nuovi contenuti';

  @override
  String get newVideosTabEmptyTitle => 'Nessun video in Nuovi video';

  @override
  String get popularVideosContextTitle => 'Video popolari';

  @override
  String get popularVideosEmptySubtitle =>
      'Torna più tardi per nuovi contenuti';

  @override
  String get popularVideosEmptyTitle => 'Nessun video in Video popolari';

  @override
  String get popularVideosErrorTitle =>
      'Impossibile caricare i video di tendenza';

  @override
  String get popularVideosFeedSourceLabel => 'Fonte del feed popolare';

  @override
  String get trendingHashtagsLoading => 'Caricamento hashtag...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Visualizza i video con il tag $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Autore del video: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Descrizione del video: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'La visione di Divine è offrirti una vera scelta algoritmica. Invece di essere vincolato a un unico algoritmo a scatola nera, potrai scegliere tra diversi approcci di raccomandazione:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Timeline cronologica dai creator che segui';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Questo ti mette al controllo della tua attenzione invece di lasciarla alla piattaforma. Dovresti sapere come viene curato il tuo feed e avere il potere di cambiarlo quando vuoi.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Feed personalizzati creati dalla community per temi come musica, comicità o arte';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Feed \"Per te\" personalizzato';

  @override
  String get forYouAlgorithmChoiceTitle => 'Il tuo algoritmo, la tua scelta';

  @override
  String get forYouAlgorithmChoiceTrending =>
      'Contenuti di tendenza e popolari';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Segnale forte: eri abbastanza coinvolto da rispondere';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine presta attenzione a come interagisci con i contenuti per capire cosa ti piace. Ogni volta che guardi un video, gli dai una reazione, lasci un commento o lo ripubblichi, il sistema ne prende nota.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Come funziona';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Azioni diverse segnalano diversi livelli di interesse:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Se non hai ancora costruito una cronologia di visualizzazione, ti mostriamo un mix di ciò che è attualmente popolare e di tendenza insieme ai caricamenti recenti. Questo ti offre un ottimo punto di partenza per esplorare.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Man mano che guardi, metti mi piace e interagisci con i contenuti, le raccomandazioni diventano gradualmente più personalizzate. Col tempo, il tuo feed Per te fa emergere video di creator che forse non avresti mai scoperto da solo.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Nuovo su Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Stiamo costruendo un sistema aperto in cui gli sviluppatori possono implementare i propri algoritmi e tu puoi scegliere quali usare, o rinunciare del tutto.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open source e trasparente';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Segnale medio: un modo rapido per mostrare apprezzamento';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reazioni';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Segnale più forte: condividere con i tuoi follower è un endorsement potente';

  @override
  String get forYouAlgorithmSubtitle =>
      'Basato su Gorse, un motore di raccomandazione open source';

  @override
  String get forYouAlgorithmTitle => 'L\'algoritmo di Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Segnale leggero: indica un interesse di base';

  @override
  String get forYouEmptyDescription =>
      'Guarda e metti mi piace ad alcuni video per ricevere raccomandazioni personalizzate.';

  @override
  String get forYouEmptyTitle => 'Ancora nessuna raccomandazione';

  @override
  String get forYouErrorTitle => 'Impossibile caricare le raccomandazioni';

  @override
  String get forYouUnavailableDescription =>
      'Le raccomandazioni personalizzate richiedono la connessione a Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Per te non disponibile';

  @override
  String get inboxConversationOptionsLabel => 'Opzioni';

  @override
  String get inboxConversationViewProfileButton => 'Visualizza profilo';

  @override
  String get inboxMessageRequestsEmpty => 'Nessuna richiesta di messaggio';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Richieste di messaggio, $requestCount in sospeso';
  }

  @override
  String get inboxMessageRequestsTitle => 'Richieste di messaggio';

  @override
  String get inboxMessagesTab => 'Messaggi';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Richiesta di messaggio di $displayName';
  }

  @override
  String get inboxRequestTileSubtitle =>
      'Ha inviato una richiesta di messaggio';

  @override
  String get inboxRequestsMarkAllRead => 'Segna tutte le richieste come lette';

  @override
  String get inboxRequestsRemoveAll => 'Rimuovi tutte le richieste';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Rifiuta e rimuovi';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Richiesta di $displayName rifiutata';
  }

  @override
  String get messageRequestLoadFailed =>
      'Non è stato possibile caricare questa richiesta.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count follower';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count video';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messaggi',
      one: '1 messaggio',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Visualizza messaggi';

  @override
  String get messageRequestViewProfileButton => 'Visualizza profilo';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName vuole scriverti, ha inviato $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Hai cambiato account, quindi non è stato eliminato nulla. Riapri l\'eliminazione per l\'account che vuoi rimuovere.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Per confermare, digita:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Per confermare, digita il tuo nome utente:';

  @override
  String get deleteAccountConfirmationHint => 'Digita DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'Digita il tuo nome utente';

  @override
  String get deleteAccountDeleteAllContentButton => 'Elimina tutti i contenuti';

  @override
  String get accountDeletionRecoveryTitle => 'Eliminazione del tuo account';

  @override
  String get accountDeletionRecoveryBody =>
      'Non siamo riusciti a completare l\'eliminazione del tuo account. Il tuo nome utente è riservato a te e può ancora essere ripristinato.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Ripristina il mio nome utente';

  @override
  String get accountDeletionFinishingBody =>
      'La tua richiesta di eliminazione è ancora in fase di elaborazione. Puoi usare un altro account mentre terminiamo.';

  @override
  String get accountDeletionOtherAccountPending =>
      'L\'eliminazione di un altro account è ancora in corso su questo dispositivo. Attendi che termini prima di eliminare questo account.';

  @override
  String get accountDeletionCancellingBody =>
      'Stiamo annullando la tua eliminazione. Controlla di nuovo prima di uscire da questa schermata.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Non siamo ancora riusciti a ripristinare il tuo nome utente. Controlla la connessione e riprova.';

  @override
  String get accountDeletionUsernameRestored =>
      'Il tuo nome utente è stato ripristinato. Il tuo account non è stato eliminato.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Non siamo riusciti a controllare lo stato dell\'eliminazione. Controlla la connessione e riprova.';

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
      'L\'eliminazione dell\'account non è disponibile al momento. Non è stato eliminato nulla.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Non siamo riusciti a completare l\'eliminazione del tuo account. Riprova.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Conferma finale';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Richieste di eliminazione inviate, ma le tue chiavi potrebbero non essere state rimosse completamente da questo dispositivo. Vai su Impostazioni → Chiavi Nostr → Rimuovi chiavi per riprovare.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Richieste di eliminazione inviate e sei disconnesso, ma non è stato possibile rimuovere alcuni dati locali da questo dispositivo.';

  @override
  String get deleteAccountPreparingDeletion =>
      'Preparazione dell\'eliminazione...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total eventi';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Questo rimuove l\'accesso locale per questo account da questo dispositivo. Non eliminerà il tuo account Divine né la tua identità Nostr.\n\nLe tue bozze e i tuoi clip restano salvati su questo dispositivo per questo account. Se questo è il tuo ultimo account locale, tornerai alla schermata di accesso.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Rimuovi dal dispositivo';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Rimuovere questo account da questo dispositivo?';

  @override
  String get deleteAccountReauthRequired =>
      'Accedi di nuovo per eliminare il tuo account. Non è stato ancora eliminato nulla.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Le richieste di eliminazione dei tuoi post sono state inviate, ma non siamo riusciti a completare l\'eliminazione del tuo account. Riprova tra poco.';

  @override
  String get deleteAccountSuccess =>
      'Il tuo account Divine è stato eliminato. Sono state inviate richieste di eliminazione per i tuoi post su Nostr, ma alcuni relay, client o cache potrebbero conservarne delle copie.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Eliminazione dell\'account richiesta. Per alcuni post esistenti non è stato possibile confermare l\'eliminazione singolarmente.';

  @override
  String get deleteAccountWarningBody =>
      'Questo invia richieste di eliminazione per il tuo account e i tuoi contenuti, elimina il tuo account Divine quando possibile e ti disconnette su questo dispositivo. Alcuni relay, client e indici di ricerca potrebbero conservare copie. Gli altri dispositivi con l\'accesso effettuato restano attivi finché non rimuovi le chiavi lì.';

  @override
  String get findPeopleNoContacts =>
      'Nessun contatto trovato.\nInizia a seguire persone per vederle qui.';

  @override
  String get geoBlockedCityLabel => 'Città';

  @override
  String get geoBlockedCountryLabel => 'Paese';

  @override
  String get geoBlockedDefaultReason =>
      'Questo servizio non è disponibile nella tua regione a causa delle normative locali.';

  @override
  String get geoBlockedLegalNotice =>
      'Rispettiamo le tue leggi e normative locali. Questa restrizione si basa sulla posizione del tuo indirizzo IP.';

  @override
  String get geoBlockedRegionLabel => 'Regione';

  @override
  String get geoBlockedTitle => 'Servizio non disponibile';

  @override
  String get likedVideosEmpty => 'Nessun video piaciuto';

  @override
  String get likedVideosInvalidRoute => 'Percorso non valido';

  @override
  String get likedVideosTitle => 'Video piaciuti';

  @override
  String get uploadFailureSheetRetryingSnackbar =>
      'Nuovo tentativo di caricamento…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Salva nelle bozze';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Salvato nelle bozze';

  @override
  String get uploadFailureSheetTitle => 'Caricamento fallito';

  @override
  String get uploadFailureSheetTryAgainButton => 'Riprova';

  @override
  String get videoEditorAudioImportAudio => 'Importa audio';

  @override
  String get videoEditorAudioImportFailed => 'Importazione audio fallita.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn => 'Accedi per pubblicare i video.';

  @override
  String get publishErrorNoRetry => 'Nessun caricamento da riprovare.';

  @override
  String get publishErrorNoInternet =>
      'Nessuna connessione a internet. Controlla il Wi-Fi o i dati mobili e riprova.';

  @override
  String get publishErrorServerUnreachable =>
      'Impossibile raggiungere il server. Riprova tra un attimo.';

  @override
  String get publishErrorTimeout =>
      'Il caricamento è scaduto. Prova con una connessione più stabile o un video più piccolo.';

  @override
  String get publishErrorTls =>
      'Connessione sicura non riuscita. Controlla la rete: il Wi-Fi pubblico può bloccare i caricamenti.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Il server multimediale ($serverName) non è disponibile. Puoi sceglierne un altro nelle impostazioni.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Il file video è troppo grande per il server. Prova a tagliarlo o ad abbassare la qualità.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Il server multimediale ($serverName) ha avuto un errore interno. Puoi sceglierne un altro nelle impostazioni.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Il server multimediale ($serverName) è temporaneamente fuori uso. Riprova tra poco o scegline un altro nelle impostazioni.';
  }

  @override
  String get publishErrorForbidden =>
      'Non hai i permessi per caricare su questo server.';

  @override
  String get publishErrorFileNotFound =>
      'Impossibile trovare il file video. Potrebbe essere stato eliminato. Registra di nuovo e riprova.';

  @override
  String get publishErrorLowStorage =>
      'Spazio insufficiente sul dispositivo. Libera un po\' di spazio e riprova.';

  @override
  String get publishErrorThumbnailFailed =>
      'Il video è stato caricato, ma non è stato possibile preparare la miniatura. Riprova.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Il video è stato caricato, ma non è stato possibile pubblicare il post. Controlla le impostazioni dei relay e riprova.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Il video è stato caricato, ma il suo audio non è autorizzato al riutilizzo. Scegli un altro audio per pubblicare.';

  @override
  String get publishErrorInterrupted =>
      'Questo caricamento è stato interrotto. Vuoi riprovare?';

  @override
  String get publishErrorAccountChanged =>
      'Questo video appartiene a un altro account. Torna su quell\'account per pubblicarlo.';

  @override
  String get publishErrorGeneric => 'Qualcosa è andato storto. Riprova.';

  @override
  String get publishErrorRateLimited =>
      'Troppi caricamenti in questo momento. Aspetta un attimo e riprova.';

  @override
  String get publishErrorUploadSessionExpired =>
      'La sessione di caricamento è scaduta. Riprova.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine non ha il permesso di caricare. Controlla i permessi dell\'app nelle impostazioni e riprova.';

  @override
  String get publishErrorOutOfMemory =>
      'Memoria insufficiente sul dispositivo. Chiudi alcune app e riprova.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Non è stato possibile preparare testo e sticker di questa bozza. Aprila nell’editor e ripubblica.';

  @override
  String get publishErrorUnknownServer => 'Server sconosciuto';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filtro: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Nessun risultato trovato per \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Visualizza i video con il tag $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Audio: $soundName di $creatorName. Tocca per vedere i dettagli dell\'audio.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Audio originale di $creatorName. Tocca per usare questo audio.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Audio: $soundName di $creatorName. Tocca per vedere i dettagli.';
  }

  @override
  String get soundDetailLoadError => 'Impossibile caricare l\'audio. Riprova.';

  @override
  String get soundDetailNotFoundMessage => 'Impossibile trovare questo audio';

  @override
  String get soundDetailNotFoundTitle => 'Audio non trovato';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loop';
  }

  @override
  String get originalSoundUnavailableBody =>
      'L\'audio di questo video non è disponibile separatamente.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Audio originale - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Questa persona ha pubblicato un Vine originale che Divine ha trovato nell\'archivio. Non è un badge di verifica dell\'account.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Spunta del profilo';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine assegna questa spunta agli account del team. È separato da NIP-05, dai link di account verificati e dallo status OG Viner.';

  @override
  String get unfollowConfirmButton => 'Smetti di seguire';

  @override
  String get videoClipSaveFailed => 'Impossibile salvare il clip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Salva in $destination';
  }

  @override
  String get videoClipDelete => 'Elimina clip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Ispirato da $creatorName +$additionalCreatorCount. Tocca per vedere il suo profilo.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Ispirato da $creatorName. Tocca per vedere il suo profilo.';
  }

  @override
  String get bugReportSendReport => 'Invia segnalazione';

  @override
  String get supportSubjectRequiredLabel => 'Oggetto *';

  @override
  String get supportPublicSubmissionTitle => 'Post pubblico su GitHub';

  @override
  String get supportPublicSubmissionMessage =>
      'Tutto ciò che invii qui verrà pubblicato nel nostro repository open source su GitHub, così gli sviluppatori potranno occuparsene. Il post e l\'account con cui hai effettuato l\'accesso saranno visibili pubblicamente a tutti.';

  @override
  String get supportRequiredHelper => 'Obbligatorio';

  @override
  String get supportFieldLimitReached =>
      'Questa è la lunghezza massima. Tutto ciò che va oltre non è stato aggiunto.';

  @override
  String get bugReportSubjectHint => 'Breve riassunto del problema';

  @override
  String get bugReportDescriptionRequiredLabel => 'Cos\'è successo? *';

  @override
  String get bugReportDescriptionHint =>
      'Descrivi il problema che hai riscontrato';

  @override
  String get bugReportStepsLabel => 'Passi per riprodurlo';

  @override
  String get bugReportStepsHint =>
      '1. Vai a...\n2. Tocca su...\n3. Vedi l\'errore';

  @override
  String get bugReportExpectedBehaviorLabel => 'Comportamento atteso';

  @override
  String get bugReportExpectedBehaviorHint => 'Cosa sarebbe dovuto succedere?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Le info sul dispositivo e i log saranno inclusi automaticamente.';

  @override
  String get bugReportSuccessMessage =>
      'Grazie! Abbiamo ricevuto la tua segnalazione e la useremo per migliorare Divine.';

  @override
  String get bugReportAttachImages => 'Allega immagini';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count di $max immagini selezionate';
  }

  @override
  String get bugReportRemoveImage => 'Rimuovi immagine';

  @override
  String get bugReportUploadFailed =>
      'Non siamo riusciti a caricare l\'immagine scelta. Riprova o manda la segnalazione senza.';

  @override
  String get bugReportSendFailed =>
      'Impossibile inviare la segnalazione. Riprova più tardi.';

  @override
  String get featureRequestSendRequest => 'Invia richiesta';

  @override
  String get featureRequestSubjectHint => 'Breve riassunto della tua idea';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Cosa vorresti? *';

  @override
  String get featureRequestDescriptionHint =>
      'Descrivi la funzionalità che desideri';

  @override
  String get featureRequestUsefulnessLabel => 'In che modo sarebbe utile?';

  @override
  String get featureRequestUsefulnessHint =>
      'Spiega il vantaggio che porterebbe questa funzionalità';

  @override
  String get featureRequestWhenLabel => 'Quando la useresti?';

  @override
  String get featureRequestWhenHint =>
      'Descrivi le situazioni in cui ti aiuterebbe';

  @override
  String get featureRequestSuccessMessage =>
      'Grazie! Abbiamo ricevuto la tua richiesta e la valuteremo.';

  @override
  String get featureRequestSendFailed =>
      'Impossibile inviare la richiesta. Riprova più tardi.';

  @override
  String get notificationFollowBack => 'Segui a tua volta';

  @override
  String get followingTitle => 'Seguiti';

  @override
  String followingTitleForName(String displayName) {
    return 'Seguiti da $displayName';
  }

  @override
  String get followingFailedToLoadList =>
      'Impossibile caricare la lista dei seguiti';

  @override
  String get followingEmptyTitle => 'Non segui ancora nessuno';

  @override
  String get followersTitle => 'Follower';

  @override
  String followersTitleForName(String displayName) {
    return 'Follower di $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Impossibile caricare la lista dei follower';

  @override
  String get followersEmptyTitle => 'Ancora nessun follower';

  @override
  String get followersUpdateFollowFailed =>
      'Impossibile aggiornare lo stato del follow. Riprova.';

  @override
  String get followersSortSemanticLabel => 'Ordina follower';

  @override
  String get followingSortSemanticLabel => 'Ordina seguiti';

  @override
  String get followSortTitle => 'Ordina per';

  @override
  String get followSortNewest => 'Prima i più recenti';

  @override
  String get followSortOldest => 'Prima i meno recenti';

  @override
  String get newMessageTitle => 'Nuovo messaggio';

  @override
  String get newMessageFindPeople => 'Trova persone';

  @override
  String get newMessageNoContacts =>
      'Nessun contatto trovato.\nSegui delle persone per vederle qui.';

  @override
  String get newMessageNoUsersFound => 'Nessun utente trovato';

  @override
  String get hashtagSearchTitle => 'Cerca hashtag';

  @override
  String get hashtagSearchSubtitle =>
      'Scopri argomenti e contenuti di tendenza';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Nessun hashtag trovato per \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Ricerca non riuscita';

  @override
  String get userNotAvailableTitle => 'Account non disponibile';

  @override
  String get userNotAvailableBody =>
      'Questo account non è disponibile al momento.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Impossibile salvare le impostazioni. Riprova.';

  @override
  String get blossomValidServerUrl =>
      'Inserisci un URL server valido (es. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Impostazioni Blossom salvate';

  @override
  String get blossomSaveTooltip => 'Salva';

  @override
  String get blossomAboutTitle => 'Info su Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom è un protocollo decentralizzato di archiviazione multimediale che ti permette di caricare video su qualsiasi server compatibile. Di default, i video vengono caricati sul server Blossom di Divine. Attiva l\'opzione qui sotto per usare un server personalizzato.';

  @override
  String get blossomUseCustomServer => 'Usa un server Blossom personalizzato';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'I tuoi video saranno caricati sul tuo server Blossom personalizzato';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'I tuoi video vengono attualmente caricati sul server Blossom di Divine';

  @override
  String get blossomCustomServerUrl => 'URL server Blossom personalizzato';

  @override
  String get blossomCustomServerHelper =>
      'Inserisci l\'URL del tuo server Blossom personalizzato';

  @override
  String get blossomPopularServers => 'Server Blossom popolari';

  @override
  String get blossomServerUrlMustUseHttps =>
      'L\'URL del server Blossom deve usare https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Impossibile aggiornare l\'impostazione di crosspost';

  @override
  String get blueskySignInRequired =>
      'Accedi per gestire le impostazioni di Bluesky';

  @override
  String get blueskyPublishVideos => 'Pubblica i video su Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'I tuoi video saranno pubblicati su Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'I tuoi video non saranno pubblicati su Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Anche i tuoi video passati verranno pubblicati';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Quando lo attivi, Divine inizierà a inviare i tuoi video più vecchi su Bluesky, dal più vecchio, senza forzare il limite giornaliero.';

  @override
  String get blueskyHandle => 'Handle Bluesky';

  @override
  String get blueskyDid => 'DID Bluesky';

  @override
  String get blueskyStatus => 'Stato';

  @override
  String get blueskyStatusReady => 'Account creato e pronto';

  @override
  String get blueskyStatusPending => 'Creazione account in corso...';

  @override
  String get blueskyStatusFailed => 'Creazione account non riuscita';

  @override
  String get blueskyStatusDisabled => 'Account disattivato';

  @override
  String get blueskyStatusNotLinked => 'Nessun account Bluesky collegato';

  @override
  String get blueskyUsernameRequired =>
      'Configura un handle divine.video prima di pubblicare su Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Per pubblicare su Bluesky serve un handle nomeutente.divine.video già registrato.';

  @override
  String get blueskyUsernameSyncPending =>
      'Il tuo handle Divine è registrato. Lo stiamo collegando a Bluesky: riprova tra poco.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Non siamo riusciti a verificare il tuo handle Divine. Riprova.';

  @override
  String get blueskySetUpHandle => 'Configura';

  @override
  String get blueskyTemporarilyUnavailable =>
      'La pubblicazione su Bluesky non è momentaneamente disponibile. Riprova.';

  @override
  String get invitesTitle => 'Invita amici';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inviti pronti da generare',
      one: '1 invito pronto da generare',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Genera un codice quando sei pronto a condividerlo.';

  @override
  String get invitesGenerateButtonLabel => 'Genera invito';

  @override
  String get invitesNoneAvailable => 'Nessun invito disponibile al momento';

  @override
  String get invitesShareWithPeople =>
      'Condividi Divine con le persone che conosci';

  @override
  String get invitesUsedInvites => 'Inviti usati';

  @override
  String invitesShareMessage(String code) {
    return 'Unisciti a me su Divine! Usa il codice invito $code per iniziare:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copia invito';

  @override
  String get invitesCopied => 'Invito copiato!';

  @override
  String get invitesShareInvite => 'Condividi invito';

  @override
  String get invitesShareSubject => 'Unisciti a me su Divine';

  @override
  String get invitesClaimed => 'Riscattato';

  @override
  String get invitesCouldNotLoad => 'Impossibile caricare gli inviti';

  @override
  String get invitesRetry => 'Riprova';

  @override
  String get searchSomethingWentWrong => 'Qualcosa è andato storto';

  @override
  String get searchTryAgain => 'Riprova';

  @override
  String get searchForLists => 'Cerca liste';

  @override
  String get searchFindCuratedVideoLists => 'Trova liste di video curate';

  @override
  String get searchEnterQuery => 'Inserisci una ricerca';

  @override
  String get searchDiscoverSomethingInteresting =>
      'Scopri qualcosa di interessante';

  @override
  String get searchPeopleSectionHeader => 'Persone';

  @override
  String get searchPeopleLoadingLabel =>
      'Caricamento dei risultati sulle persone';

  @override
  String get searchTagsSectionHeader => 'Tag';

  @override
  String get searchTagsLoadingLabel => 'Caricamento dei risultati sui tag';

  @override
  String get searchVideosSectionHeader => 'Video';

  @override
  String get searchVideosLoadingLabel => 'Caricamento dei risultati sui video';

  @override
  String get searchVideosSortOptionsLabel => 'Ordina i risultati video';

  @override
  String get searchVideosSortTrending => 'Di tendenza';

  @override
  String get searchVideosSortLoops => 'Più loop';

  @override
  String get searchVideosSortEngagement => 'Più coinvolgenti';

  @override
  String get searchVideosSortRecent => 'Recenti';

  @override
  String get searchListsSectionHeader => 'Liste';

  @override
  String get searchListsLoadingLabel => 'Caricamento risultati liste';

  @override
  String get cameraAgeRestriction =>
      'Devi avere almeno 16 anni per creare contenuti';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Il relay bunker deve usare wss:// (ws:// è ammesso solo per localhost)';

  @override
  String get timeNow => 'ora';

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
    return '${count}g';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}set';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}me';
  }

  @override
  String timeShortYears(int count) {
    return '${count}a';
  }

  @override
  String get timeVerboseNow => 'Ora';

  @override
  String timeAgo(String time) {
    return '$time fa';
  }

  @override
  String get timeToday => 'Oggi';

  @override
  String get timeYesterday => 'Ieri';

  @override
  String get timeJustNow => 'adesso';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min fa';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h fa';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}g fa';
  }

  @override
  String get draftTimeJustNow => 'Adesso';

  @override
  String get contentLabelNudity => 'Nudità';

  @override
  String get contentLabelSexualContent => 'Contenuto sessuale';

  @override
  String get contentLabelPornography => 'Pornografia';

  @override
  String get contentLabelGraphicMedia => 'Contenuto esplicito';

  @override
  String get contentLabelViolence => 'Violenza';

  @override
  String get contentLabelSelfHarm => 'Autolesionismo/Suicidio';

  @override
  String get contentLabelDrugUse => 'Uso di droghe';

  @override
  String get contentLabelAlcohol => 'Alcol';

  @override
  String get contentLabelTobacco => 'Tabacco/Fumo';

  @override
  String get contentLabelGambling => 'Gioco d\'azzardo';

  @override
  String get contentLabelProfanity => 'Linguaggio volgare';

  @override
  String get contentLabelHateSpeech => 'Incitamento all\'odio';

  @override
  String get contentLabelHarassment => 'Molestie';

  @override
  String get contentLabelFlashingLights => 'Luci lampeggianti';

  @override
  String get contentLabelAiGenerated => 'Generato dall\'IA';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Truffa/Frode';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Fuorviante';

  @override
  String get contentLabelSensitiveContent => 'Contenuto sensibile';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName ha messo like al tuo video';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName ha messo like al tuo commento';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName ha commentato il tuo video';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName ha iniziato a seguirti';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName ti ha menzionato';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName ha ricondiviso il tuo video';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName ha pubblicato un nuovo vine';
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
      other: '$count dei tuoi vine',
      one: 'il tuo vine',
    );
    return '$actorName ha aggiunto $_temp0 a $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName ha risposto al tuo commento';
  }

  @override
  String get notificationAndConnector => 'e';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count altri',
      one: '1 altro',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Hai un nuovo aggiornamento';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Nascondi la tastiera';

  @override
  String get commentsErrorLoadFailed =>
      'Non è stato possibile caricare i commenti';

  @override
  String get commentsErrorNotAuthenticatedComment => 'Accedi per commentare';

  @override
  String get commentsErrorPostCommentFailed =>
      'Non è stato possibile pubblicare il commento';

  @override
  String get commentsErrorPostReplyFailed =>
      'Non è stato possibile pubblicare la risposta';

  @override
  String get commentsErrorEditFailed =>
      'Non è stato possibile modificare il commento';

  @override
  String get commentsErrorNotAuthenticatedInteract => 'Accedi per interagire';

  @override
  String get commentsErrorVoteFailed =>
      'Non è stato possibile votare il commento';

  @override
  String get commentsErrorReportFailed =>
      'Non è stato possibile segnalare il commento';

  @override
  String get commentsErrorBlockFailed =>
      'Non è stato possibile bloccare l\'utente';

  @override
  String get commentsErrorDeleteFailed =>
      'Non è stato possibile eliminare il commento';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commenti',
      one: '$count commento',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Pubblicazione…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'La tua risposta video è in pubblicazione';

  @override
  String get commentsSortNew => 'Nuovi';

  @override
  String get commentsSortTop => 'Migliori';

  @override
  String get commentsSortOld => 'Vecchi';

  @override
  String get commentsSortSemanticLabel => 'Ordinamento dei commenti';

  @override
  String get commentReply => 'Rispondi';

  @override
  String get commentReplySemanticLabel => 'Rispondi al commento';

  @override
  String get commentUpvoteLabel => 'Vota a favore del commento';

  @override
  String get commentRemoveUpvoteLabel => 'Togli il voto a favore';

  @override
  String get commentDownvoteLabel => 'Vota contro il commento';

  @override
  String get commentRemoveDownvoteLabel => 'Togli il voto contrario';

  @override
  String get commentsInputHint => 'Aggiungi un commento...';

  @override
  String get commentsInputHintEdit => 'Modifica il commento...';

  @override
  String get commentsEmptyTitle => 'Ancora nessun commento';

  @override
  String get commentsEmptySubtitle => 'Rompi il ghiaccio!';

  @override
  String get draftUntitled => 'Senza titolo';

  @override
  String get contentWarningNone => 'Nessuno';

  @override
  String get textBackgroundNone => 'Nessuno';

  @override
  String get textBackgroundSolid => 'Pieno';

  @override
  String get textBackgroundHighlight => 'Evidenziato';

  @override
  String get textBackgroundTransparent => 'Trasparente';

  @override
  String get textAlignLeft => 'Sinistra';

  @override
  String get textAlignRight => 'Destra';

  @override
  String get textAlignCenter => 'Centro';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'La fotocamera non è ancora supportata sul web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'L\'acquisizione e la registrazione con fotocamera non sono ancora disponibili nella versione web.';

  @override
  String get cameraPermissionBackToFeed => 'Torna al feed';

  @override
  String get cameraCouldNotStart => 'Impossibile avviare la fotocamera';

  @override
  String get cameraUnsupportedPlatform =>
      'La fotocamera non è ancora disponibile su questa piattaforma.\nPuoi comunque sfogliare e guardare i video.';

  @override
  String get cameraPermissionErrorTitle => 'Errore di autorizzazione';

  @override
  String get cameraPermissionErrorDescription =>
      'Si è verificato un errore durante il controllo delle autorizzazioni.';

  @override
  String get cameraPermissionRetry => 'Riprova';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Consenti accesso a fotocamera e microfono';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Questo ti consente di registrare e modificare video direttamente nell\'app, niente di più.';

  @override
  String get cameraPermissionGoToSettings => 'Vai alle impostazioni';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Perché sei secondi?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'I clip brevi lasciano spazio alla spontaneità. Il formato da 6 secondi ti aiuta a catturare momenti autentici mentre accadono.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Capito!';

  @override
  String get videoRecorderUploadTitle => 'Perché niente upload?';

  @override
  String get videoRecorderUploadBody =>
      'Quello che vedi su Divine è fatto dagli umani: grezzo e catturato nel momento. A differenza delle piattaforme che permettono upload molto prodotti o generati dall\'IA, diamo la priorità all\'autenticità dell\'esperienza fotocamera-diretta.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Mantenendo la creazione all\'interno dell\'app, possiamo garantire meglio che i contenuti siano reali e non modificati. Per ora non stiamo aprendo gli upload dalla galleria esterna, per proteggere quella autenticità e mantenere la nostra community libera da contenuti sintetici per quanto possibile.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Passa a Capture o Classic per girare qualcosa di reale.';

  @override
  String get videoRecorderUploadLearnMore => 'Scopri come funziona la verifica';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Abbiamo trovato un lavoro in corso';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Vuoi continuare da dove avevi interrotto?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Sì, continua';

  @override
  String get videoRecorderAutosaveDiscardButton => 'No, inizia un nuovo video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Impossibile ripristinare la tua bozza';

  @override
  String get videoRecorderStopRecordingTooltip => 'Interrompi registrazione';

  @override
  String get videoRecorderStartRecordingTooltip => 'Avvia registrazione';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Registrazione in corso. Tocca ovunque per fermare';

  @override
  String get videoRecorderTapToStartLabel =>
      'Tocca ovunque per avviare la registrazione';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Elimina ultimo clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Cambia fotocamera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoom a $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Mostra/nascondi griglia';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Mostra/nascondi fotogramma fantasma';

  @override
  String get videoRecorderGhostFrameEnabled => 'Fotogramma fantasma attivato';

  @override
  String get videoRecorderGhostFrameDisabled =>
      'Fotogramma fantasma disattivato';

  @override
  String get videoRecorderClipDeletedMessage => 'Clip spostato nel cestino';

  @override
  String get videoRecorderClipUndoLabel => 'Annulla';

  @override
  String get libraryTrashEmptyTitle => 'Il cestino è vuoto';

  @override
  String get libraryTrashEmptySubtitle =>
      'I clip eliminati restano qui per 30 giorni prima di essere rimossi definitivamente.';

  @override
  String get libraryTrashRestoreLabel => 'Ripristina';

  @override
  String get libraryTrashDeleteNowLabel => 'Elimina ora';

  @override
  String get libraryTrashEmptyAllLabel => 'Svuota il cestino';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Eliminare subito la clip?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Questo rimuove subito la clip dal cestino.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Svuotare il cestino?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip',
      one: '1 clip',
    );
    return 'Questo elimina definitivamente dal cestino $_temp0 subito.';
  }

  @override
  String get videoRecorderCloseLabel => 'Chiudi registratore video';

  @override
  String get videoRecorderContinueToEditorLabel => 'Continua all\'editor video';

  @override
  String get videoRecorderCameraPreviewLabel => 'Anteprima fotocamera';

  @override
  String get videoRecorderCameraPreviewFocusHint =>
      'Metti a fuoco la fotocamera';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Passa alla modalità $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Aggiungi audio prima di registrare';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Impossibile creare il video. Riprova.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scatti rimasti',
      one: '1 scatto rimasto',
      zero: 'Nessuno scatto rimasto',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Attiva/disattiva flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Cambia timer';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Cambia rapporto d\'aspetto';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilizzazione';

  @override
  String get videoRecorderStabilizationModeOff => 'Disattivata';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinematografica';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematografica estesa';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Ottimizzata per l\'anteprima';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Bassa latenza';

  @override
  String get videoRecorderStabilizationModeAuto => 'Automatica';

  @override
  String get videoRecorderFlashValueOff => 'Disattivato';

  @override
  String get videoRecorderFlashValueOn => 'Attivato';

  @override
  String get videoRecorderFlashValueAuto => 'Automatico';

  @override
  String get videoRecorderTimerValueOff => 'Disattivato';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 secondi';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 secondi';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Quadrato';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Verticale';

  @override
  String get videoRecorderCameraValueFront => 'Fotocamera anteriore';

  @override
  String get videoRecorderCameraValueBack => 'Fotocamera posteriore';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Libreria clip, nessun clip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Apri libreria clip, $clipCount clip',
      one: 'Apri libreria clip, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Apri libreria stop-motion, $frameCount fotogrammi',
      one: 'Apri libreria stop-motion, 1 fotogramma',
      zero: 'Apri libreria stop-motion',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Fotocamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Apri fotocamera';

  @override
  String get videoEditorLibraryLabel => 'Libreria';

  @override
  String get videoEditorTextLabel => 'Testo';

  @override
  String get videoEditorDrawLabel => 'Disegna';

  @override
  String get videoEditorFilterLabel => 'Filtro';

  @override
  String get videoEditorTuneLabel => 'Regola';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Apri editor regolazioni';

  @override
  String get videoEditorTuneBrightness => 'Luminosità';

  @override
  String get videoEditorTuneContrast => 'Contrasto';

  @override
  String get videoEditorTuneSaturation => 'Saturazione';

  @override
  String get videoEditorTuneExposure => 'Esposizione';

  @override
  String get videoEditorTuneHue => 'Tonalità';

  @override
  String get videoEditorTuneTemperature => 'Temperatura';

  @override
  String get videoEditorTuneTint => 'Tinta';

  @override
  String get videoEditorTuneFade => 'Dissolvenza';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Aggiungi';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Apri libreria';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Apri editor audio';

  @override
  String get videoEditorCaptionsLabel => 'Sottotitoli';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Apri l\'editor dei sottotitoli';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Incorpora nel video';

  @override
  String get videoEditorCaptionsPresetCustom => 'Person.';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Stile personalizzato';

  @override
  String get videoEditorCaptionsCustomApply => 'Applica';

  @override
  String get videoEditorCaptionsCustomFont => 'Font';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Colore testo';

  @override
  String get videoEditorCaptionsCustomBackground => 'Sfondo';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Colore sfondo';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animazione';

  @override
  String get videoEditorCaptionsAnimationNone => 'Nessuna';

  @override
  String get videoEditorCaptionsAnimationFade => 'Dissolvenza';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Molla';

  @override
  String get videoEditorCaptionsEditTitle => 'Sottotitoli';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'In ascolto…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Trasformiamo il tuo audio in suggerimenti per i sottotitoli.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Non abbiamo sentito alcuna voce. Puoi comunque scrivere i sottotitoli tu stesso.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Il riconoscimento vocale non è disponibile su questo dispositivo. Puoi scrivere i sottotitoli tu stesso.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Il riconoscimento vocale non è consentito. Attivalo nelle Impostazioni o scrivi i sottotitoli tu stesso.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'La trascrizione non ha funzionato questa volta. Puoi scrivere i sottotitoli tu stesso.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Scrivo i sottotitoli da solo';

  @override
  String get videoEditorCaptionsAddCue => 'Aggiungi sottotitolo';

  @override
  String get videoEditorCaptionsCueTextHint => 'Testo del sottotitolo';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Elimina sottotitolo';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Rimuovi tutti i sottotitoli';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Rimuovere i sottotitoli?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Tutto il testo e i tempi andranno persi.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Chiudi l\'editor dei sottotitoli';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Conferma i sottotitoli';

  @override
  String get videoEditorCaptionsPresetTitle => 'Stile dei sottotitoli';

  @override
  String get videoEditorCaptionsPresetClassic => 'Classico';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Titolo';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Macchina da scrivere';

  @override
  String get videoEditorCaptionsPresetMarker => 'Pennarello';

  @override
  String get videoEditorCaptionsPresetScript => 'Calligrafia';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retrò';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegante';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bolla';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Grassetto';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Sognante';

  @override
  String get videoEditorCaptionsPresetOcean => 'Oceano';

  @override
  String get videoEditorCaptionsPresetSunny => 'Soleggiato';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Scritto a mano';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Timbro';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Apri editor testo';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Apri editor disegno';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Apri editor filtri';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Apri editor sticker';

  @override
  String get videoEditorSaveDraftTitle => 'Salvare la bozza?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Conserva le modifiche per dopo, oppure scartale e lascia l\'editor.';

  @override
  String get videoEditorSaveDraftButton => 'Salva bozza';

  @override
  String get videoEditorDiscardChangesButton => 'Scarta modifiche';

  @override
  String get videoEditorKeepEditingButton => 'Continua a modificare';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Area di rilascio per eliminare livello';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Rilascia per eliminare il livello';

  @override
  String get videoEditorDoneLabel => 'Fatto';

  @override
  String get videoEditorPlayPauseSemanticLabel =>
      'Riproduci o metti in pausa il video';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Posizione di divisione non valida. Entrambi i clip devono durare almeno $minDurationMs ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Salva clip selezionato';

  @override
  String get videoEditorSaveClip => 'Salva clip';

  @override
  String get videoEditorClipSavedSuccess => 'Clip salvato nella libreria';

  @override
  String get videoEditorClipSaveFailed => 'Impossibile salvare il clip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Selettore colore';

  @override
  String get videoEditorUndoSemanticLabel => 'Annulla';

  @override
  String get videoEditorRedoSemanticLabel => 'Ripristina';

  @override
  String get videoEditorTextColorSemanticLabel => 'Colore testo';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Allineamento testo';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Sfondo testo';

  @override
  String get videoEditorFontSemanticLabel => 'Carattere';

  @override
  String get videoEditorNoStickersFound => 'Nessuno sticker trovato';

  @override
  String get videoEditorNoStickersAvailable => 'Nessuno sticker disponibile';

  @override
  String get videoEditorFailedLoadStickers =>
      'Impossibile caricare gli sticker';

  @override
  String get videoEditorVoiceOverLabel => 'Voce fuori campo';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Registrazione $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel =>
      'Registra una voce fuori campo';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Avvia registrazione';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Ferma registrazione';

  @override
  String get videoEditorVoiceOverHint =>
      'Tocca per registrare. Aggiungi tutte le riprese che vuoi.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registrazioni',
      one: '1 registrazione',
      zero: 'Ancora nessuna registrazione',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Elimina l’ultima registrazione';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Serve l’accesso al microfono';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Consenti l’accesso al microfono per registrare una voce fuori campo.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Apri impostazioni';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Registrazione avviata';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Registrazione salvata';

  @override
  String get videoEditorVoiceOverTooLong =>
      'La registrazione è più lunga del tuo video';

  @override
  String get videoEditorPlaySemanticLabel => 'Riproduci';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausa';

  @override
  String get videoEditorVolumeSemanticLabel => 'Regola volume';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Scorri per regolare';

  @override
  String get videoEditorChromaKeyLabel => 'Green screen';

  @override
  String get videoEditorChromaKeyTitle => 'Green screen';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Imposta il green screen di questa clip';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Annulla le modifiche al green screen';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Applica il green screen';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Rilevamento automatico';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Verde';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Blu';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Colore dello sfondo';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Intensità';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Quanto colore dello sfondo sparisce';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Bordo';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Ammorbidisce il ritaglio così i capelli non si frastagliano';

  @override
  String get videoEditorChromaKeySpillLabel => 'Alone';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Toglie la tinta dello sfondo dal soggetto';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Sostituisci con';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Niente';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Colore';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Immagine';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Il video non supporta la trasparenza, quindi in esportazione diventa nero.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Nessuno sfondo trovato. Deve arrivare ai bordi dell\'inquadratura, altrimenti scegli il colore a mano.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Scegli una clip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'La tua libreria è vuota. Salva prima una clip, poi usala come sfondo.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Impossibile caricare quell\'immagine.';

  @override
  String get videoEditorChromaKeyRemove => 'Rimuovi il green screen';

  @override
  String get videoEditorChromaKeyFailed =>
      'Non è stato possibile applicare il green screen. La clip resta invariata.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Non è stato possibile rimuovere il green screen. La clip resta invariata.';

  @override
  String get videoEditorChromaKeyApplying => 'Applico il green screen…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Questo dispositivo non può mostrare l\'anteprima dal vivo. Le tue impostazioni valgono comunque in esportazione.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Elimina';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Elimina elemento selezionato';

  @override
  String get videoEditorStopMotionFramesPerImageLabel =>
      'Fotogrammi per immagine';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotogrammi',
      one: '1 fotogramma',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Fotogrammi';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count fotogrammi per immagine';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Fotogramma stop-motion $position di $total';
  }

  @override
  String get videoEditorEditLabel => 'Modifica';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Modifica elemento selezionato';

  @override
  String get videoEditorDuplicateLabel => 'Duplica';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplica elemento selezionato';

  @override
  String get videoEditorCombineLabel => 'Unisci';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Unisci i disegni selezionati in un unico livello';

  @override
  String get videoEditorSplitLabel => 'Dividi';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Dividi clip selezionato';

  @override
  String get videoEditorExtractAudioLabel => 'Estrai audio';

  @override
  String get videoEditorClipAudioTitle => 'Audio clip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Estrai audio dal clip e silenzia l\'originale';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Impossibile estrarre l\'audio: il clip non è disponibile localmente.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Impossibile estrarre l\'audio. Riprova.';

  @override
  String get videoEditorSpeedLabel => 'Velocità';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Imposta la velocità di riproduzione per il clip selezionato';

  @override
  String get videoEditorReverseLabel => 'Inverti';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Attiva o disattiva la riproduzione inversa per il clip selezionato';

  @override
  String get videoEditorReverseProgressLabel =>
      'Un momento, stiamo invertendo la clip';

  @override
  String get videoEditorTransformLabel => 'Trasforma';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Ritaglia, ruota o capovolgi il clip selezionato';

  @override
  String get videoEditorTransformProgressLabel =>
      'Un momento, stiamo trasformando il tuo clip';

  @override
  String get videoEditorTransformFailed =>
      'Impossibile trasformare il clip. Riprova.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Impossibile trasformare: il clip non è disponibile localmente.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Ritaglia, ruota o capovolgi il fotogramma selezionato';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Un attimo, stiamo trasformando il tuo fotogramma';

  @override
  String get videoEditorTransformFrameFailed =>
      'Impossibile trasformare il fotogramma. Riprova.';

  @override
  String get videoEditorTransformRotateLabel => 'Ruota';

  @override
  String get videoEditorTransformFlipLabel => 'Capovolgi';

  @override
  String get videoEditorTransformResetLabel => 'Reimposta';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Applica trasformazione';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Annulla trasformazione';

  @override
  String get videoEditorTransformPlayLabel => 'Riproduci';

  @override
  String get videoEditorTransformPauseLabel => 'Pausa';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Impossibile invertire: il clip non è disponibile localmente.';

  @override
  String get videoEditorReverseFailed =>
      'Impossibile invertire il clip. Riprova.';

  @override
  String get videoEditorSpeedSheetTitle => 'Velocità del clip';

  @override
  String get videoEditorTransitionSheetTitle => 'Transizione';

  @override
  String get videoEditorTransitionNone => 'Nessuna';

  @override
  String get videoEditorTransitionDissolve => 'Dissolvenza incrociata';

  @override
  String get videoEditorTransitionFadeToBlack => 'Dissolvenza in nero';

  @override
  String get videoEditorTransitionFadeToWhite => 'Dissolvenza in bianco';

  @override
  String get videoEditorTransitionSlide => 'Scorrimento';

  @override
  String get videoEditorTransitionPush => 'Spinta';

  @override
  String get videoEditorTransitionWipe => 'Tendina';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Modifica transizione';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Transizione in loop';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Modifica transizione in loop';

  @override
  String get videoEditorTransitionDuration => 'Durata';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Ridotta per non sovrapporsi alla transizione adiacente.';

  @override
  String get videoEditorTransitionCurve => 'Curva';

  @override
  String get videoEditorTransitionDirection => 'Direzione';

  @override
  String get videoEditorTransitionDirectionLeft => 'Sinistra';

  @override
  String get videoEditorTransitionDirectionRight => 'Destra';

  @override
  String get videoEditorTransitionDirectionUp => 'Su';

  @override
  String get videoEditorTransitionDirectionDown => 'Giù';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Curva di animazione $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animazione';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Modifica animazione livello';

  @override
  String get videoEditorLayerAnimationEnter => 'Entrata';

  @override
  String get videoEditorLayerAnimationLeave => 'Uscita';

  @override
  String get videoEditorLayerAnimationFade => 'Dissolvenza';

  @override
  String get videoEditorLayerAnimationScale => 'Scala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Scala da';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Termina modifica timeline';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Riproduci anteprima';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'Metti in pausa anteprima';

  @override
  String get videoEditorAudioUntitledSound => 'Suono senza titolo';

  @override
  String get videoEditorAudioUntitled => 'Senza titolo';

  @override
  String get videoEditorAudioAddAudio => 'Aggiungi audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Nessun suono disponibile';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'I suoni appariranno qui quando i creator condivideranno audio';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Impossibile caricare i suoni';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Seleziona il segmento audio per il tuo video';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Comunità';

  @override
  String get videoEditorAudioCategoryFeatured => 'In primo piano';

  @override
  String get videoEditorAudioCategoryMySounds => 'I miei suoni';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Strumento freccia';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Strumento gomma';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel =>
      'Strumento evidenziatore';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Strumento matita';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Mostra timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Nascondi timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Evita di posizionare contenuti dietro queste aree.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originali';

  @override
  String get videoEditorStickerSearchHint => 'Cerca sticker...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Seleziona carattere';

  @override
  String get videoEditorFontUnknown => 'Sconosciuto';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'La testina di riproduzione deve essere all\'interno del clip selezionato per dividerlo.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Rifila inizio';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Rifila fine';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Rifila clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Trascina le maniglie per regolare la durata del clip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Trascinamento clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index di $total, $duration secondi';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Tieni premuto per riordinare';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Sposta a sinistra';

  @override
  String get videoEditorTimelineClipMoveRight => 'Sposta a destra';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index di $total, selezionata';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index di $total, non selezionata';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Seleziona';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Seleziona più clip';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Termina selezione';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip selezionate',
      one: '1 clip selezionata',
      zero: 'Nessuna clip selezionata',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Seleziona più disegni';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Termina la selezione dei disegni';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Elimina i disegni selezionati';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count disegni selezionati',
      one: '1 disegno selezionato',
      zero: 'Nessun disegno selezionato',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Unisci';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Unisci le clip selezionate';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Elimina le clip selezionate';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Elimina i fotogrammi selezionati';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Inverti i fotogrammi selezionati';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplica i fotogrammi selezionati';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Il tuo video deve durare almeno ${seconds}s: scatta ancora qualche fotogramma.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Un momento, stiamo unendo le tue clip';

  @override
  String get videoEditorMergeFailed => 'Impossibile unire le clip. Riprova.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Tieni premuto per trascinare';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Timeline video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, selezionato';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Chiudi selettore colore';

  @override
  String get videoEditorPickColorTitle => 'Scegli colore';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Conferma colore';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturazione e luminosità';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturazione $saturation %, luminosità $brightness %';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Tonalità';

  @override
  String get videoEditorAddElementSemanticLabel => 'Aggiungi elemento';

  @override
  String get videoEditorDoneSemanticLabel => 'Fatto';

  @override
  String get videoEditorLevelSemanticLabel => 'Livello';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Chiudi dettagli del post';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Chiudi finestra di aiuto';

  @override
  String get videoMetadataGotItButton => 'Capito!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limite di 64 KB raggiunto. Rimuovi alcuni contenuti per continuare.';

  @override
  String get videoMetadataExpirationLabel => 'Scadenza';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Seleziona tempo di scadenza';

  @override
  String get videoMetadataTitleLabel => 'Titolo';

  @override
  String get videoMetadataDescriptionLabel => 'Descrizione';

  @override
  String get videoMetadataTagsLabel => 'Tag';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Elimina tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Avviso contenuto';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Seleziona avvisi contenuto';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Seleziona tutto ciò che si applica ai tuoi contenuti';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Lascia che altri salvino e riutilizzino l\'audio di questo video.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Il tuo video è online, ma il suono non è stato pubblicato. Modifica il video per condividerlo.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Collaboratori';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Aggiungi collaboratore';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Follower reciproci';

  @override
  String get videoMetadataInspiredByLabel => 'Ispirato da';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Imposta ispirato da';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Non è possibile fare riferimento a questo creator.';

  @override
  String get videoMetadataPostDetailsTitle => 'Dettagli del post';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Salvato in libreria';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Salvataggio non riuscito';

  @override
  String get videoMetadataGoToLibraryButton => 'Vai alla libreria';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Pulsante salva per dopo';

  @override
  String get videoMetadataSavingVideoHint => 'Salvataggio video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Salva video nelle bozze e $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Salva il video nelle bozze. Nessun video renderizzato per ora, quindi nessuna copia in $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Salva per dopo';

  @override
  String get videoMetadataPostSemanticLabel => 'Pulsante pubblica';

  @override
  String get videoMetadataPublishVideoHint => 'Pubblica video nel feed';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Condividi anche nel mio feed';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Se disattivato, questo video resta solo nel thread dei commenti.';

  @override
  String get videoMetadataFormNotReadyHint => 'Compila il modulo per abilitare';

  @override
  String get videoMetadataPostButton => 'Pubblica';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Apri schermata anteprima del post';

  @override
  String get videoMetadataShareTitle => 'Condividi';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Dettagli video';

  @override
  String get videoMetadataClassicDoneButton => 'Fatto';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Riproduci anteprima';

  @override
  String get videoMetadataPausePreviewSemanticLabel =>
      'Metti in pausa anteprima';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Chiudi anteprima video';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Rimuovi';

  @override
  String get fullscreenFeedRemovedMessage => 'Video rimosso';

  @override
  String get fullscreenFeedEmptyMessage =>
      'Qui non c’è più niente da riprodurre';

  @override
  String get settingsBadgesTitle => 'Badge';

  @override
  String get settingsBadgesSubtitle =>
      'Accetta i premi e controlla lo stato dei badge che hai assegnato.';

  @override
  String get badgesTitle => 'Badge';

  @override
  String get badgesLoadError => 'Impossibile caricare i badge';

  @override
  String get badgesUpdateError => 'Impossibile aggiornare il badge';

  @override
  String get badgesAwardedEmptyTitle => 'Ancora nessun badge ricevuto';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Quando qualcuno ti assegnerà un badge Nostr, atterrerà qui.';

  @override
  String get badgesStatusAccepted => 'Accettato';

  @override
  String get badgesStatusNotAccepted => 'Non accettato';

  @override
  String get badgesActionRemove => 'Rimuovi';

  @override
  String get badgesActionAccept => 'Accetta';

  @override
  String get badgesActionReject => 'Rifiuta';

  @override
  String get badgesIssuedEmptyTitle => 'Ancora nessun badge rilasciato';

  @override
  String get badgesIssuedEmptySubtitle =>
      'I badge che rilasci mostreranno qui lo stato di accettazione.';

  @override
  String get badgesIssuedNoRecipients =>
      'Nessun destinatario trovato per questo premio.';

  @override
  String get badgesRecipientAcceptedStatus => 'Accettato dal destinatario';

  @override
  String get badgesRecipientWaitingStatus => 'In attesa del destinatario';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nascosti ($count)',
      one: 'Nascosto (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Ripristina';

  @override
  String get badgesHiddenSnackbar => 'Badge nascosto';

  @override
  String get badgesHiddenSnackbarUndo => 'Annulla';

  @override
  String get badgesTabAwarded => 'Ricevuti';

  @override
  String get badgesTabCreated => 'Creati';

  @override
  String get badgesTabIssued => 'Assegnati';

  @override
  String get badgesCreateAction => 'Nuovo badge';

  @override
  String get badgesCreatedEmptyTitle => 'Nessun badge creato';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Creane uno e dallo a chi se lo merita.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assegnato a $count persone',
      one: 'Assegnato a 1 persona',
      zero: 'Non ancora assegnato',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Nuovo badge';

  @override
  String get badgeEditorEditTitle => 'Modifica badge';

  @override
  String get badgeEditorNameLabel => 'Nome';

  @override
  String get badgeEditorNameHint => 'Ruba la scena';

  @override
  String get badgeEditorIdentifierLabel => 'Identificatore';

  @override
  String get badgeEditorIdentifierHelp =>
      'Fa parte dell\'indirizzo del badge, quindi resta fisso una volta creato.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Hai già un badge con questo identificatore. Modifica quello: pubblicare qui lo sostituirebbe.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Ogni badge ha bisogno di un identificatore: scrivilo tu se il nome non l\'ha riempito.';

  @override
  String get badgeEditorDescriptionLabel => 'Descrizione';

  @override
  String get badgeEditorDescriptionHint =>
      'Per chi ruba la scena con un solo loop.';

  @override
  String get badgeEditorArtworkLabel => 'Grafica';

  @override
  String get badgeEditorArtworkAdd => 'Aggiungi grafica';

  @override
  String get badgeEditorArtworkReplace => 'Sostituisci';

  @override
  String get badgeEditorArtworkError =>
      'Non è stato possibile caricare l\'immagine';

  @override
  String get badgeEditorArtworkRequired =>
      'Ogni badge ha bisogno di una grafica.';

  @override
  String get badgeEditorArtworkRemove => 'Rimuovi la grafica';

  @override
  String get badgeEditorArtworkSheetTitle => 'Grafica del badge';

  @override
  String get badgeDetailDeleteAction => 'Elimina badge';

  @override
  String get badgeDetailDeleteTitle => 'Eliminare questo badge?';

  @override
  String get badgeDetailDeleteBody =>
      'Questo chiede ai relay di rimuovere il badge e tutte le assegnazioni che hai fatto. I relay possono rifiutare, e chi lo ha messo sul profilo lo tiene finché non lo toglie.';

  @override
  String get badgeDetailDeleteConfirm => 'Elimina';

  @override
  String get badgeEditorSaveAction => 'Pubblica badge';

  @override
  String get badgeEditorSaveError =>
      'Non è stato possibile pubblicare il badge';

  @override
  String get badgeEditorLoadError =>
      'Non è stato possibile caricare questo badge';

  @override
  String get badgeDetailTitle => 'Badge';

  @override
  String get badgeDetailMadeBy => 'Creato da';

  @override
  String get badgeDetailRecipientsTitle => 'Assegnato a';

  @override
  String get badgeDetailNoRecipients => 'Non ce l\'ha ancora nessuno.';

  @override
  String get badgeDetailAwardAction => 'Assegna questo badge';

  @override
  String get badgeDetailEditAction => 'Modifica badge';

  @override
  String get badgeDetailShareAction => 'Condividi';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Guarda questo badge su Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Riprendi il badge';

  @override
  String get badgeDetailRevokeTitle => 'Riprendere questo badge?';

  @override
  String get badgeDetailRevokeBody =>
      'Questo chiede ai relay di rimuovere l\'assegnazione fatta a questa persona. I relay possono rifiutare, e se ha già messo il badge sul profilo lo tiene finché non lo toglie. In ogni caso non riceve alcun avviso.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Questo chiede ai relay di rimuovere l\'assegnazione che ti sei fatto e toglie il badge dal tuo profilo. Se i relay rifiutano la cancellazione, non cambia nulla.';

  @override
  String get badgeDetailRevokeConfirm => 'Riprendi';

  @override
  String get badgeDetailRevokeSuccess => 'Badge ripreso';

  @override
  String get badgeDetailBlockClaimantsAction => 'Blocca chi ha questo badge';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Blocca chi ha questo badge';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Impossibile caricare chi ha questo badge';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Ora nessuno ha questo badge';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Non abbiamo trovato nessuno da bloccare al momento.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bloccare $count account?',
      one: 'Bloccare 1 account?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Questo blocca i $count account che ora tengono questo badge sul profilo. I loro post non appariranno nei tuoi feed e non verranno avvisati.',
      one:
          'Questo blocca l\'account che ora tiene questo badge sul profilo. I suoi post non appariranno nei tuoi feed e non verrà avvisato.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blocca $count account',
      one: 'Blocca 1 account',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'Account con il badge bloccati';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Impossibile bloccare chi ha il badge';

  @override
  String get badgeDetailLoadError =>
      'Non è stato possibile caricare questo badge';

  @override
  String get badgeDetailMissing => 'Non troviamo questo badge su nessun relay.';

  @override
  String get badgeDetailActionError => 'Non ha funzionato';

  @override
  String get badgeAwardTitle => 'Assegna badge';

  @override
  String get badgeAwardPickAction => 'Scegli persone';

  @override
  String get badgeAwardManualLabel => 'Oppure incolla le chiavi';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Scegli almeno una persona.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assegna a $count persone',
      one: 'Assegna a 1 persona',
      zero: 'Assegna il badge',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Assegnato da';

  @override
  String get profileBadgeRecipients => 'Destinatari';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count altri';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Badge $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Badge';

  @override
  String get profileBadgeFooterBody =>
      'I badge sono piccoli riconoscimenti che chiunque può creare su Nostr. Regalane uno a un amico, a un creator o a chi ti ha svoltato la giornata.';

  @override
  String get profileBadgeFooterLink => 'Crea il tuo badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Guida per le famiglie';

  @override
  String get minorAccountReviewWelcomeTitle =>
      'Non hai ancora 16 anni? Va bene così.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Il fatto che tu sia arrivato fino a questa pagina invece di scegliere semplicemente la risposta che ti faceva entrare conta. Dimostra onestà, carattere e una cura vera per le persone intorno a te.\n\nLe regole per chi ha meno di 16 anni cambiano a seconda di dove vivi. Da Divine vogliamo che le famiglie ne parlino insieme e decidano che aspetto ha un uso sano dei social.';

  @override
  String get minorAccountReviewModerationTitle =>
      'Ci serve ancora un passaggio';

  @override
  String get minorAccountReviewModerationBody =>
      'Ci è stato chiesto di guardare più da vicino questo account perché potrebbe appartenere a una persona sotto i 16 anni. Questo percorso mantiene privati i passaggi successivi e ti indica la strada giusta per la tua età.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Le regole non sono uguali ovunque';

  @override
  String get minorAccountReviewRulesBody =>
      'Paesi e regioni trattano in modo diverso l\'uso dei social da parte degli adolescenti. Per questo chiediamo alle famiglie di rallentare, verificare i fatti e scegliere insieme il passo successivo.';

  @override
  String get minorAccountReviewApproachTitle => 'Come la vede Divine';

  @override
  String get minorAccountReviewApproachBody =>
      'Crediamo che le abitudini digitali sane nascano dal fermarsi, riflettere e spostare l\'attenzione verso cose migliori, non dallo spiare i ragazzi o dal trasformare i genitori in sorveglianti. Anche la ricerca lo conferma.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Altro per le famiglie';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Leggi la policy di Divine per i minori';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'Scegli il percorso adatto';

  @override
  String get minorAccountReviewUnder13Cta => 'Sotto i 13 anni';

  @override
  String get minorAccountReviewTeenCta => '13-15 anni';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Visita la guida Divine per le famiglie: consigli pratici, strumenti per parlarne e materiali per aiutare i ragazzi a usare i social in modo più sicuro.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Scopri guide e consigli per le famiglie';

  @override
  String get minorAccountReviewFooter =>
      'Se hai 16 anni o più e sei finito qui per sbaglio, contatta l\'assistenza Divine così che una persona vera possa controllare.';

  @override
  String get minorAccountReviewTitle => 'Revisione dell\'account';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Controllo dello stato dell\'account...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Aspetta mentre confermiamo lo stato attuale della revisione di questo account.';

  @override
  String get minorAccountReviewDefaultTitle =>
      'Serve una revisione dell\'account';

  @override
  String get minorAccountReviewDefaultBody =>
      'Dobbiamo esaminare questo account prima che possa usare Divine normalmente.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'ID caso: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'ID caso';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'Cosa è limitato in questo momento';

  @override
  String get minorAccountReviewRestrictionPosting => 'Pubblicare è sospeso';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Commenti, mi piace, repost e follow sono sospesi';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Iniziare o rispondere ai messaggi normali è sospeso';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'L\'assistenza e il tuo messaggio della moderazione restano disponibili';

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
  String get minorAccountReviewOpenSupportCenter => 'Apri il centro assistenza';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Apri il messaggio della moderazione';

  @override
  String get minorAccountReviewOpenReviewPage => 'Apri la pagina di revisione';

  @override
  String get minorAccountReviewCheckAgain => 'Controlla di nuovo';

  @override
  String get minorAccountReviewLogOut => 'Esci';

  @override
  String get minorAccountReviewNextStepTitle => 'Prossimo passo';

  @override
  String get minorAccountReviewNextStepBody =>
      'Apri il centro assistenza o il messaggio della moderazione se ti serve aiuto con questa revisione.';

  @override
  String get minorAccountReviewInProgressTitle => 'Revisione in corso';

  @override
  String get minorAccountReviewInProgressBody =>
      'Per ora abbiamo quello che ci serve. Il nostro team sta esaminando il caso prima di ripristinare il normale accesso all\'account.';

  @override
  String get minorAccountReviewUnder13Title => 'Account sotto i 13 anni';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Se questo account appartiene a una persona sotto i 13 anni, un genitore o tutore deve scrivere a $supportEmail indicando l\'ID del caso.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Non possiamo ancora darti un account';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine non è pensato per bambini sotto i 13 anni e le regole sui social nel mondo ci legano le mani.\n\nSu internet tante cose ti spingono a mentire per ottenere quello che vuoi, e questo lo detestiamo. È la lezione sbagliata per la vita, e qui non te la insegneremo.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Cosa può fare la tua famiglia invece';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Un genitore o tutore può tenere l\'account e pubblicare, e tu puoi tranquillamente comparire nei video insieme a loro. Vogliamo che le famiglie si godano Divine nel modo che funziona per loro.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Quando compi 13 anni';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'A seconda delle regole di dove vivi, potresti tornare e chiedere un account tuo. In quel caso, se hai tra i 13 e i 15 anni, servirà il consenso di un genitore o tutore.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Perché non ti diremo semplicemente di tornare indietro';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Gran parte di internet è costruita per premiare chi dice qualsiasi cosa pur di superare il controllo. Non pensiamo sia una bella cosa. Sì, potresti tornare indietro e dire di essere più grande di quanto sei, ma non sarebbe onesto, e non ti spingeremo a mentire per ottenere ciò che vuoi.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Stiamo cercando di aiutare i giovani a usare Divine in modi che siano sani e positivi per loro e per le persone intorno a loro. Dobbiamo anche rispettare leggi che sono diverse da luogo a luogo. Quindi, se hai meno di 13 anni, la risposta è che oggi non puoi avere un tuo account.';

  @override
  String get minorAccountReviewTeenBody =>
      'Se questo account appartiene a una persona tra i 13 e i 15 anni, usa il messaggio della moderazione o l\'assistenza per seguire le istruzioni sul consenso dei genitori.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Se l\'account sarà di una persona tra i 13 e i 15 anni';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Un genitore o tutore dovrebbe scrivere all\'assistenza Divine allegando un breve video privato. Il nostro team lo esaminerà e ti aiuterà con i passi successivi.\n\nSe contattare un genitore o tutore non è possibile o metterebbe qualcuno a rischio, scrivi all\'assistenza Divine e faccelo sapere.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'È una pausa mentre il team di assistenza Divine esamina il video. Se viene approvato, ti guideranno nella configurazione del nuovo account.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Perché chiediamo il coinvolgimento di un genitore o tutore';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine deve rispettare le leggi sull\'età in tutto il mondo. Sappiamo anche che la maggior parte dei controlli tecnici sull\'età è imperfetta. Invece di fingere che le regole non esistano o che sia cool mentire sulla propria età, vogliamo che gli adolescenti e le famiglie prendano decisioni ponderate su come usare al meglio Divine. Ecco perché, per i ragazzi dai 13 ai 15 anni, chiediamo ai genitori di far parte del processo di creazione dell\'account.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Dobbiamo anche rispettare la legge, e queste regole variano a seconda di dove vive una persona. Quindi, invece di fingere che le regole non esistano, chiediamo che un genitore o un tutore faccia parte del processo.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Cosa deve mostrare il video';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Il ragazzo o la ragazza nel video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Un genitore o tutore che parla davanti alla telecamera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Una dichiarazione chiara che il ragazzo o la ragazza ha tra 13 e 15 anni e ha il permesso di usare Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Una dichiarazione chiara che il genitore o tutore è a conoscenza dell\'account e ne sorveglierà l\'uso';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Come inviarlo';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Allega il video quando scrivi all\'assistenza Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Tieni il video privato e non pubblicarlo nell\'app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Il nostro team lo esaminerà e risponderà con i passi successivi';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Scrivi all\'assistenza Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Aiuto per la revisione Divine Greenlight (13-15 anni)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Ciao assistenza Divine,\n\nvi scrivo riguardo a Divine Greenlight per un ragazzo o una ragazza tra i 13 e i 15 anni.\n\nHo allegato un breve video privato che mostra:\n- il ragazzo o la ragazza\n- un genitore o tutore che parla davanti alla telecamera\n- che ha il permesso di usare Divine\n- che il genitore o tutore è a conoscenza dell\'account e ne sorveglierà l\'uso\n\nPaese/i di residenza:\n\nContesto utile:\n\nGrazie.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Istruzioni di assistenza per i genitori';

  @override
  String get minorAccountReviewContinue => 'Continua';

  @override
  String get minorAccountReviewErrorTitle =>
      'Non siamo riusciti a caricare lo stato della revisione del tuo account.';

  @override
  String get minorAccountReviewErrorBody => 'Riprova tra poco.';

  @override
  String get minorAccountReviewTryAgain => 'Riprova';

  @override
  String get minorAccountReviewParentContactTitle => 'Contatto del genitore';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Aggiungi l\'email di un genitore o tutore';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Useremo questo indirizzo per la revisione del consenso dei genitori sul caso $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Email del genitore o tutore';

  @override
  String get minorAccountReviewSubmitting => 'Invio in corso...';

  @override
  String get minorAccountReviewSubmitEmail => 'Invia l\'email';

  @override
  String get minorAccountReviewBackToReview =>
      'Torna alla revisione dell\'account';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Email inviata';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Abbiamo inviato $email per la revisione. Scriveremo a questo indirizzo per confermare. Appena il genitore o tutore risponde, il tuo caso va avanti. Usa Controlla di nuovo dalla schermata di revisione dell\'account per gli aggiornamenti.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Abbiamo ricevuto il contatto del genitore o tutore per questo account. Il nostro team lo esaminerà prima di ripristinare l\'accesso.';

  @override
  String get minorAccountReviewMissingCase =>
      'Non abbiamo trovato un caso di revisione attivo per questo account.';

  @override
  String get minorAccountReviewParentContactError =>
      'Non è stato possibile inviare l\'email del genitore. Riprova.';

  @override
  String get minorAccountReviewUnder13SupportTitle =>
      'Assistenza per i genitori';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Un genitore o tutore deve contattare Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Per gli account che sembrano di persone sotto i 13 anni, il passo successivo è il contatto via email di un genitore o tutore.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Email dell\'assistenza';

  @override
  String get minorAccountReviewCopySupportEmail =>
      'Copia l\'email dell\'assistenza';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'Email dell\'assistenza copiata';

  @override
  String get minorAccountReviewCopyCaseId => 'Copia l\'ID del caso';

  @override
  String get minorAccountReviewCaseIdCopied => 'ID del caso copiato';

  @override
  String get minorAccountReviewUnavailable => 'Non disponibile';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Chiedi al genitore o tutore di indicare l\'ID del caso e di spiegare che sta contattando Divine per questa revisione dell\'account.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Revisione account sotto i 13 anni per il caso $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Ciao assistenza Divine,\n\nsono il genitore o tutore di un bambino sotto i 13 anni e vi scrivo per il caso di revisione dell\'account $caseId.\n\nGrazie.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulazione revisione account di minore';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Stato attuale';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Limitato ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Attivo';

  @override
  String get devOptionsMinorReviewStateLoading => 'Caricamento...';

  @override
  String get devOptionsMinorReviewStateError =>
      'Errore nel caricamento dello stato';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Azzera la forzatura della simulazione';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Torna a usare il backend o lo stato attivo predefinito';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Simula caso di revisione 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Account limitato con percorso di contatto del genitore';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simula caso di assistenza sotto i 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Account limitato con istruzioni solo via email del genitore';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simulazione revisione account di minore azzerata';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Caso di assistenza simulato sotto i 13 attivato';

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
      'Simulazione minore protetto';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Stato attuale';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Minore protetto (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Non protetto';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Caricamento…';

  @override
  String get devOptionsProtectedMinorStateError =>
      'Errore nella lettura dello stato';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Nessuna forzatura (stato reale dell\'account)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Forzatura: protetto imposto';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Forzatura: non protetto imposto';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simula minore protetto (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Forza lo stato di minore protetto per testare le protezioni #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simula una persona maggiorenne';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Forza non protetto (un no esplicito, diverso dall\'assenza di forzatura)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Azzera la forzatura';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Torna allo stato reale dell\'account gestito da Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Stato di minore protetto forzato';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Stato di minore protetto disattivato';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Forzatura minore protetto azzerata';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Inviti di registrazione';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Stato attuale';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Valore del server: caricamento';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Valore del server: attivo';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Valore del server: disattivo';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Valore del server: sconosciuto';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Forzatura: usa il valore del server';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Forzatura: imponi attivo';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Forzatura: imponi disattivo';

  @override
  String get devOptionsInviteAvailabilityUseServer =>
      'Usa il valore del server';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Segui l\'onboardingMode del servizio inviti';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Imponi attivo';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Mostra in locale i blocchi e la gestione degli inviti di registrazione';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Imponi disattivo';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Nascondi in locale l\'interfaccia degli inviti senza toccare il server';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Gli inviti di registrazione ora seguono il server';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Inviti di registrazione forzati come attivi';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Inviti di registrazione forzati come disattivi';

  @override
  String get commentsRecordVideoButtonLabel => 'Registra un commento video';

  @override
  String get commentsOpenVideoLabel => 'Apri il commento video';

  @override
  String get commentsMuteVideoReplyLabel =>
      'Disattiva audio della risposta video';

  @override
  String get commentsUnmuteVideoReplyLabel =>
      'Riattiva audio della risposta video';

  @override
  String get commentsOpenReplyParentLabel => 'Apri il video a cui risponde';

  @override
  String get commentsReplyParentSectionTitle => 'In risposta a';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Risposta a $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Risposta al video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Account $platform verificato: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Account verificati';

  @override
  String get profileEditGetVerifiedCta => 'Fatti verificare';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Collega i tuoi profili social così tutti sanno che sei davvero tu.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Vai al sito: $url';
  }

  @override
  String get profileCouldNotOpenWebsite =>
      'Non è stato possibile aprire il sito';

  @override
  String get videoMetadataEditCoverTitle => 'Modifica copertina';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Annulla le modifiche alla copertina';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Usa il fotogramma selezionato come copertina del video';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Scorri il video per selezionare il fotogramma di copertina';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Cerca o aggiungi tag';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Aggiungi tag per far scoprire il tuo video';

  @override
  String get videoMetadataTagsPickerNoResults => 'Nessun tag corrispondente';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Aggiungi «#$tag»';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Non hai ancora 16 anni? Va bene così. ';

  @override
  String get authUnder16ChoicesCta => 'Ecco le tue opzioni.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Ecco perché';

  @override
  String get generalSettingsHoldToRecord => 'Tieni premuto per registrare';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'La registrazione inizia tenendo premuto e si ferma al rilascio';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video pubblicati sul tuo profilo',
      one: 'Video pubblicato sul tuo profilo',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Invia il messaggio';

  @override
  String get emojiPickerSearchHint => 'Cerca';

  @override
  String get emojiCategoryRecent => 'Recenti';

  @override
  String get emojiCategorySmileys => 'Faccine e persone';

  @override
  String get emojiCategoryAnimals => 'Animali e natura';

  @override
  String get emojiCategoryFood => 'Cibo e bevande';

  @override
  String get emojiCategoryActivities => 'Attività';

  @override
  String get emojiCategoryTravel => 'Viaggi e luoghi';

  @override
  String get emojiCategoryObjects => 'Oggetti';

  @override
  String get emojiCategorySymbols => 'Simboli';

  @override
  String get emojiCategoryFlags => 'Bandiere';

  @override
  String get videoEditorMarkerLabel => 'Marcatore';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Aggiungi marcatore alla timeline';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Rimuovi marcatore dalla timeline';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Rimuovi marcatore alla testina di riproduzione';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Eliminare il marcatore?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Questo rimuove il marcatore dalla timeline. La tua modifica resta intatta.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Silenzia o riattiva tutte le tracce';

  @override
  String get videoEditorSplitFailed => 'Divisione non riuscita. Riprovare.';

  @override
  String get videoEditEditSubtitles => 'Modifica sottotitoli';

  @override
  String get subtitleEditorTitle => 'Modifica sottotitoli';

  @override
  String get subtitleEditorSave => 'Salva';

  @override
  String get subtitleEditorProcessing =>
      'I sottotitoli sono ancora in fase di generazione. Riprova tra poco.';

  @override
  String get subtitleEditorNoSpeech =>
      'Non è stato rilevato alcun parlato in questo video, quindi non c\'è niente da sottotitolare.';

  @override
  String get subtitleEditorWriteOwn => 'Scrivili tu';

  @override
  String get subtitleEditorAddCue => 'Aggiungi una riga';

  @override
  String get subtitleEditorRemoveCue => 'Rimuovi questa riga';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Il video non si riproduce al momento, ma puoi comunque correggere i sottotitoli.';

  @override
  String get subtitleEditorPlayPreview => 'Riproduci il video';

  @override
  String get subtitleEditorPausePreview => 'Metti in pausa il video';

  @override
  String get subtitleEditorInvalidHint =>
      'Ogni riga ha bisogno di testo e di una fine dopo il suo inizio.';

  @override
  String get subtitleEditorLoadError =>
      'Impossibile caricare i sottotitoli. Riprova.';

  @override
  String get subtitleEditorSaveSuccess => 'Sottotitoli aggiornati';

  @override
  String get subtitleEditorSaveError =>
      'Impossibile salvare i sottotitoli. Riprova.';

  @override
  String get subtitleEditorRetry => 'Riprova';

  @override
  String get subtitleEditorCueHint => 'Testo della didascalia';

  @override
  String get imageCropEditorRotateLabel => 'Ruota';

  @override
  String get imageCropEditorFlipLabel => 'Capovolgi';

  @override
  String get imageCropEditorResetLabel => 'Reimposta';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Annulla ritaglio';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Applica ritaglio';

  @override
  String get imageCropEditorProcessing => 'Applicazione del ritaglio…';

  @override
  String get backgroundUploadNotificationTitle => 'Caricamento del video';

  @override
  String get monetizationSettingsTitle => 'Sostegno ai creator';

  @override
  String get monetizationSettingsSubtitle =>
      'Aggiungi link per mance e abbonamenti';

  @override
  String get monetizationSettingsIntroTitle => 'Solo link esterni';

  @override
  String get monetizationSettingsIntroBody =>
      'Aggiungi destinazioni che gestisci tu. Divine non gestisce mai il pagamento e non sblocca contenuti nell\'app tramite questi link.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count link attivi sul tuo profilo',
      one: '1 link attivo sul tuo profilo',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Manda una mancia';

  @override
  String get monetizationSettingsSubscriptionSection => 'Abbonati / sostieni';

  @override
  String get monetizationSettingsSave => 'Salva i link di sostegno';

  @override
  String get monetizationSettingsSaving => 'Salvataggio...';

  @override
  String get monetizationSettingsSaved => 'Link di sostegno aggiornati';

  @override
  String get monetizationSettingsSaveFailed =>
      'Non è stato possibile salvare i link di sostegno. Controlla la connessione e riprova.';

  @override
  String get monetizationSettingsErrorEmpty => 'Aggiungi un handle o un URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Questo link non sembra corretto.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Usa un link di questo servizio.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag o link cash.app';

  @override
  String get monetizationSettingsHintPayPal => 'Handle o link PayPal.me';

  @override
  String get monetizationSettingsHintVenmo => 'Handle o link Venmo';

  @override
  String get monetizationSettingsHintPatreon => 'Handle o link Patreon';

  @override
  String get monetizationSettingsHintSubstack => 'Dominio o link Substack';

  @override
  String get monetizationSettingsHintMedium => 'Handle o link Medium';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Slug o link Open Collective';

  @override
  String get profileSupportSheetTitle => 'Sostieni questo creator';

  @override
  String get profileSupportSheetBody =>
      'Questi link si aprono fuori da Divine. Niente qui sblocca contenuti nell\'app.';

  @override
  String get profileSupportTipSection => 'Manda una mancia';

  @override
  String get profileSupportSubscriptionSection => 'Abbonati / sostieni';

  @override
  String get profileSupportButtonLabel => 'Sostieni';

  @override
  String get monetizationTipsSettingsTitle => 'Mance';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Aggiungi link facoltativi per le mance';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Solo mance facoltative';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Le mance sono regali facoltativi tra persone. Non sbloccano contenuti, abbonamenti, funzioni, posizionamento, visibilità o accessi su Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count link per le mance attivi sul tuo profilo',
      one: '1 link per le mance attivo sul tuo profilo',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Salva i link per le mance';

  @override
  String get monetizationTipsSettingsSaved => 'Link per le mance aggiornati';

  @override
  String get profileTipButtonLabel => 'Mancia';

  @override
  String get profileTipSheetTitle => 'Lascia una mancia a questo creator';

  @override
  String get profileTipSheetBody =>
      'I link per le mance si aprono fuori da Divine. Sono facoltativi e non sbloccano contenuti, abbonamenti, funzioni o accessi su Divine.';

  @override
  String get settingsStorageTitle => 'Archiviazione';

  @override
  String get settingsStorageCacheSectionTitle => 'Media in cache';

  @override
  String get settingsStorageCacheDescription =>
      'Video del feed, miniature e render temporanei in cache. Eliminarli è sicuro: vengono riscaricati o rigenerati quando servono.';

  @override
  String get settingsStorageMeasuring => 'Calcolo in corso…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size in uso';
  }

  @override
  String get settingsStorageClearButton => 'Svuota cache';

  @override
  String get settingsStorageClearConfirmTitle => 'Svuotare i media in cache?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Libera $size. La tua libreria di clip non viene toccata.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Svuota';

  @override
  String get settingsStorageCleared => 'Cache svuotata';

  @override
  String get settingsStorageLibrarySectionTitle => 'Libreria di clip';

  @override
  String get settingsStorageLibraryDescription =>
      'Cerca clip danneggiate il cui file video è mancante.';

  @override
  String get settingsStorageScanButton => 'Controlla libreria';

  @override
  String get settingsStorageLibraryHealthy =>
      'Nessuna clip danneggiata trovata';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Clip danneggiate trovate: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Rimuovi clip danneggiate';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Clip danneggiate rimosse';

  @override
  String get settingsStorageError => 'Qualcosa è andato storto';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Cache video massima';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count video';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Rimuovere le clip danneggiate?';

  @override
  String get settingsStorageRepairSectionTitle => 'Ripara l\'installazione';

  @override
  String get settingsStorageRepairDescription =>
      'Se l\'app continua a crashare o si comporta in modo strano, azzerare i dati locali di solito risolve. I tuoi clip e le bozze restano.';

  @override
  String get settingsStorageRepairButton => 'Azzera i dati dell\'app';

  @override
  String get settingsStorageRepairConfirmTitle => 'Azzerare i dati dell\'app?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Questo cancella i dati del feed in cache e i file temporanei. I tuoi clip, le bozze, le impostazioni e l\'accesso restano, ma dopo dovrai riavviare l\'app.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return 'Verranno rimossi $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Azzera';

  @override
  String get settingsStorageRepairInProgress => 'Azzeramento…';

  @override
  String get settingsStorageRepairSuccess =>
      'Fatto — riavvia l\'app per completare.';

  @override
  String get settingsStorageRepairFailure =>
      'Non è stato possibile azzerare tutto. Riprova dopo un riavvio.';

  @override
  String get nostrSettingsSignatureVerification => 'Verifica della firma';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Scegli quando Divine controlla le firme degli eventi dei relay. Gli ID evento vengono sempre validati per primi.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Tutti i relay';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Più sicuro. Verifica la firma di ogni evento relay.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Relay non attendibili';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Salta i controlli per i relay già nel tuo pool configurato.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Relay non Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Fidati dei relay Divine, verifica il resto.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle =>
      'Condividi i tuoi video su altre piattaforme';

  @override
  String get crosspostingSignInRequired =>
      'Accedi con Divine per gestire il crossposting';

  @override
  String get crosspostingLoadFailed =>
      'Non è stato possibile caricare le tue impostazioni di crossposting';

  @override
  String get crosspostingNoPlatforms =>
      'Al momento non c’è nessuna piattaforma di crossposting disponibile';

  @override
  String get crosspostingRetry => 'Riprova';

  @override
  String get crosspostingNotConnected => 'Non connesso';

  @override
  String get crosspostingConnected => 'Connesso';

  @override
  String get crosspostingNeedsReconnect => 'Da ricollegare';

  @override
  String get crosspostingConnect => 'Collega';

  @override
  String get crosspostingReconnect => 'Ricollega';

  @override
  String get crosspostingDisconnect => 'Scollega';

  @override
  String get crosspostingModeOff => 'Disattivato';

  @override
  String get crosspostingModeManual => 'Manuale';

  @override
  String get crosspostingModeManualSubtitle => 'Scegli tu per ogni video';

  @override
  String get crosspostingModeAutomatic => 'Automatico';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'I prossimi video vengono pubblicati da soli — solo quelli pubblicati dopo aver attivato questa opzione';

  @override
  String get crosspostingNotConnectedError =>
      'Collega prima questa piattaforma per cambiare come pubblica.';

  @override
  String get crosspostingGenericError => 'Qualcosa è andato storto. Riprova.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'La pagina di accesso non ha mai risposto. Se hai finito lì, aggiorna — il tuo account potrebbe essere già collegato.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform collegato';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Non è stato possibile collegare $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'La connessione è stata annullata su $platform';
  }

  @override
  String get supporterTitle => 'Sostenitori Divine';

  @override
  String get supporterTileSubtitle =>
      'Sostieni Divine con un abbonamento mensile facoltativo.';

  @override
  String get supporterHeroTitle => 'Mantieni Divine in funzione';

  @override
  String get supporterHeroBody =>
      'Divine è gratis e lo sarà sempre. Se vuoi aiutarci a tenere in vita i loop, diventa un sostenitore mensile. Niente è bloccato — serve solo a tenere accese le luci e a guadagnarti i nostri ringraziamenti.';

  @override
  String get supporterActiveBadge =>
      'Sei un Sostenitore Divine. Grazie per mantenere vivo tutto questo.';

  @override
  String get supporterPurchasePending =>
      'Il tuo acquisto è in attesa di approvazione.';

  @override
  String get supporterPurchaseConfirming =>
      'Conferma del tuo sostegno in corso…';

  @override
  String get supporterStoreChecking => 'Controllo dello store in corso…';

  @override
  String get supporterUnavailable =>
      'Gli abbonamenti da sostenitore non sono disponibili qui al momento.';

  @override
  String get supporterRestorePurchases => 'Ripristina gli acquisti';

  @override
  String get supporterDismissError => 'Ignora l\'errore';

  @override
  String get supporterErrorStoreUnavailable =>
      'Lo store non è disponibile su questo dispositivo.';

  @override
  String get supporterErrorPurchaseFailed =>
      'L\'acquisto non è stato completato. Non ti è stato addebitato nulla.';

  @override
  String get supporterErrorPurchasePending =>
      'Il tuo acquisto è in attesa di approvazione.';

  @override
  String get supporterErrorRestoreFailed =>
      'Nessun abbonamento da sostenitore trovato da ripristinare.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Questo acquisto appartiene a un altro account Divine.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine non ha potuto confermare il tuo stato di sostenitore al momento.';

  @override
  String get supporterErrorUnknown => 'Qualcosa è andato storto. Riprova.';

  @override
  String get supporterDisclaimer =>
      'Divine conferma lo stato di sostenitore dopo che lo store ha verificato il tuo acquisto. Il riconoscimento è facoltativo, e l\'aureola non è una verifica.';

  @override
  String get profileNotifyBellOff => 'Avvisami dei nuovi vine';

  @override
  String get profileNotifyBellOn => 'Non avvisarmi più dei nuovi vine';

  @override
  String get profileNotifyUpdateFailed =>
      'Salvataggio non riuscito. Riprovare?';

  @override
  String get savedSoundYourLabel => 'La tua etichetta';

  @override
  String get savedSoundAddHashtags => 'Aggiungi hashtag';

  @override
  String get savedSoundDeviceOnly => 'Salvato su questo dispositivo';

  @override
  String get savedSoundDetailsRetry =>
      'Non è stato possibile salvare questi dati. Tocca per riprovare.';

  @override
  String get savedSoundFallbackTitle => 'Suono salvato';

  @override
  String get savedSoundPreviewAction => 'Ascolta il suono';

  @override
  String get savedSoundEditAction => 'Modifica i dati del suono';

  @override
  String get savedSoundRemoveAction => 'Rimuovi il suono salvato';

  @override
  String get savedSoundClearHashtagFilter => 'Azzera il filtro per hashtag';

  @override
  String get soundAllowRemix => 'Permetti ad altri di remixare questo suono';

  @override
  String get soundReuseUnavailable =>
      'Questo suono non si può remixare al momento.';

  @override
  String get soundPublicCredit => 'Credito pubblico del suono';

  @override
  String get soundCreditRequired =>
      'Aggiungi il credito pubblico del suono prima di pubblicare.';

  @override
  String get soundSharedAs => 'Condiviso come';

  @override
  String get soundOwnWork => 'Questo suono l\'ho fatto io';

  @override
  String soundCreatorBy(String creator) {
    return 'Di $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Condiviso da $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remix consentito';

  @override
  String get soundCreditOnly => 'Solo credito';

  @override
  String get soundCreditTitleLabel => 'Titolo del suono';

  @override
  String get soundCreditCreatorLabel => 'Creator';

  @override
  String get soundCreditSourceUrlLabel => 'URL della fonte';

  @override
  String get soundCreditPublicHashtagsLabel => 'Hashtag pubblici';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Annulla selezione tag';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Applica i tag selezionati';

  @override
  String get userPickerCancelSemanticLabel => 'Annulla selezione utenti';

  @override
  String get userPickerConfirmSemanticLabel => 'Conferma utenti selezionati';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Cancella selezione utenti';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Annulla selezione avvisi sui contenuti';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Applica gli avvisi sui contenuti selezionati';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Chiudi l’editor video';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Continua ai dettagli del post';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Annulla le modifiche in $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Applica le modifiche in $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Rimuovi audio';

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
  String get verifyTitle => 'Account verificati';

  @override
  String get verifySignedOutMessage => 'Accedi per collegare i tuoi account.';

  @override
  String get verifyIntro =>
      'Collega gli account che hai già, così si vede che sei davvero tu.';

  @override
  String get verifyLoadFailed =>
      'Non siamo riusciti a caricare i tuoi collegamenti.';

  @override
  String get verifyRetry => 'Riprova';

  @override
  String get verifyLinkedSectionTitle => 'Collegati';

  @override
  String get verifyVerifierUnreachable =>
      'Il verificatore non era raggiungibile, quindi risultano non controllati.';

  @override
  String get verifyAddSectionTitle => 'Aggiungi un account';

  @override
  String get verifyAllPlatformsLinked =>
      'Hai collegato tutto quello che supportiamo.';

  @override
  String get verifyStatusVerified => 'Verificato';

  @override
  String get verifyStatusUnverified => 'Non verificato';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Scollega l\'account $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Scollegare $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity non comparirà più sul tuo profilo. Puoi ricollegarlo più avanti, ma dovrai accedere di nuovo o pubblicare una nuova prova.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Scollega';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Collega il tuo account $platform';
  }

  @override
  String get verifyOneTapBadge => 'Un tap';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Accedi a $platform e al resto pensiamo noi. Non viene pubblicato niente.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Continua con $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Oppure pubblica una prova';

  @override
  String get verifyConnectProofExplainer =>
      'Pubblica il tuo npub sul tuo account, poi incolla il link a quel post.';

  @override
  String get verifyNpubLabel => 'Il tuo npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Copia il tuo npub';

  @override
  String get verifyNpubCopied => 'npub copiato';

  @override
  String get verifyIdentityLabel => 'Nome dell\'account';

  @override
  String get verifyProofLabel => 'Link al tuo post';

  @override
  String get verifyConnectProofCta => 'Controlla e collega';

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
      'Verificatore non raggiungibile. Riprova tra poco.';

  @override
  String get verifyErrorOauthFailed => 'Non è andata. Riprova.';

  @override
  String get verifyErrorHandleRequired => 'Inserisci prima il tuo handle.';

  @override
  String get verifyErrorPublishFailed =>
      'Verificato, ma nessun relay ha accettato l\'aggiornamento. Riprova.';

  @override
  String get verifyErrorOauthUnavailable =>
      'L\'accesso con un tap non è ancora configurato per questa. Usa la prova qui sotto.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Crea un gist pubblico con il tuo npub nel primo file, poi incolla il link del gist.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Pubblica il tuo npub in un canale Discord che il nostro bot può leggere, poi incolla il link del messaggio. Un invito al server non prova niente.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Twitta il tuo npub da quell\'account, poi incolla il link del tweet.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Pubblica il tuo npub da quell\'account, poi incolla il link. Il nome account deve avere l\'istanza — mastodon.social/@alice, non solo alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Viene collegato il canale, non il tuo account Telegram. Serve prima un link pubblico (Telegram crea i nuovi come privati). Pubblica lì il tuo npub e incolla il link del messaggio.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Hai fatto l\'accesso qui sopra? Non serve altro. Altrimenti pubblica il tuo npub e incolla il link del post.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Metti il tuo npub nella didascalia di un video, poi incolla il link di quel video.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Metti il tuo npub nella descrizione di un video, poi incolla il link di quel video.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform è collegato.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Quello è un canale privato o un invito. Dai al canale un link pubblico, poi incolla il link del messaggio.';

  @override
  String get verifyErrorRemoveFailed =>
      'Non siamo riusciti a scollegarlo. Riprova.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Non siamo riusciti a leggere i tuoi collegamenti attuali, quindi non è stato cambiato niente. Controlla la connessione e riprova.';

  @override
  String get verifyChannelLabel => 'Nome del canale';

  @override
  String get verifyHowItWorksTitle => 'Come funziona?';

  @override
  String get verifyHowItWorksIntro =>
      'Pensalo come una stretta di mano tra due account:';

  @override
  String get verifyHowItWorksYourSide =>
      'Il tuo profilo Divine dice: «Sono @alice su Twitter».';

  @override
  String get verifyHowItWorksOtherSide =>
      'Il tuo account Twitter conferma: «Sì, quel profilo Divine è mio».';

  @override
  String get verifyHowItWorksBothSides =>
      'Controlliamo entrambi i lati. Se combaciano, sei verificato. Falsificarlo non si può: nome e foto si copiano, postare dal tuo account vero no.';

  @override
  String get verifyHowItWorksOwnership =>
      'I collegamenti stanno sulla tua identità Nostr, quindi puoi rimuoverli da qui quando vuoi.';

  @override
  String get generalSettingsSectionIdentity => 'Identità';

  @override
  String get libraryFilterAll => 'Tutti';

  @override
  String get libraryFilterArchive => 'Archivio';

  @override
  String get libraryFilterDeleted => 'Eliminati';

  @override
  String get libraryCategoryNewChipLabel => 'Nuova';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Crea una categoria';

  @override
  String get libraryCategoryCreateTitle => 'Nuova categoria';

  @override
  String get libraryCategoryCreateAction => 'Crea';

  @override
  String get libraryCategoryRenameTitle => 'Rinomina categoria';

  @override
  String get libraryCategoryRenameAction => 'Rinomina';

  @override
  String get libraryCategoryDeleteAction => 'Elimina categoria';

  @override
  String get libraryCategoryNameLabel => 'Nome della categoria';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Eliminare «$name»?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'I tuoi clip restano. Tornano semplicemente in Tutti.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Rinomina o elimina questa categoria';

  @override
  String get libraryCategoryMoveTitle => 'Sposta in';

  @override
  String get libraryCategoryMoveNone => 'Nessuna categoria';

  @override
  String get libraryCategoryMoveNewCategory => 'Nuova categoria';

  @override
  String get libraryArchiveAction => 'Archivia';

  @override
  String get libraryUnarchiveAction => 'Rimuovi dall’archivio';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tenere in queste categorie?',
      one: 'Tenere in questa categoria?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Tieni in $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'Tieni nelle loro categorie';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Rimuovi da $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Rimuovi dalle loro categorie';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Sposta i clip selezionati';

  @override
  String get libraryCategoryEmptyTitle => 'Qui non c\'è ancora niente';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Seleziona qualche clip e spostalo in questa categoria.';

  @override
  String get libraryArchiveEmptyTitle => 'Niente in archivio';

  @override
  String get libraryArchiveEmptySubtitle =>
      'I clip archiviati aspettano qui, fuori dalla libreria principale.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip spostati in $name',
      one: '1 clip spostato in $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip rimossi dalla loro categoria',
      one: '1 clip rimosso dalla sua categoria',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip archiviati',
      one: '1 clip archiviato',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip di nuovo nella libreria',
      one: '1 clip di nuovo nella libreria',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Cambia e-mail';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Sposta il tuo account su un altro indirizzo';

  @override
  String get accountSettingsChangePassword => 'Cambia password';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Scegli una nuova password per accedere';

  @override
  String get accountCredentialsNeedsSignIn =>
      'La sessione è scaduta. Accedi di nuovo per fare questa modifica.';

  @override
  String get accountCredentialsRateLimited =>
      'Troppi tentativi. Aspetta qualche minuto.';

  @override
  String get accountCredentialsNetwork =>
      'Non riusciamo a raggiungere Divine. Controlla la connessione e riprova.';

  @override
  String get accountCredentialsUnknown => 'Non ha funzionato. Riprova.';

  @override
  String get changePasswordSubtitle =>
      'Scrivi la password attuale, poi scegline una nuova.';

  @override
  String get changePasswordCurrentLabel => 'Password attuale';

  @override
  String get changePasswordWrongCurrent =>
      'Questa non è la tua password attuale.';

  @override
  String get changePasswordSuccess => 'Password cambiata.';

  @override
  String get changeEmailSubtitle =>
      'Mandiamo un link di conferma al nuovo indirizzo e a quello del tuo account. L\'e-mail cambia quando confermi da entrambi.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Sul tuo account: $email';
  }

  @override
  String get changeEmailNewLabel => 'Nuova e-mail';

  @override
  String get changeEmailPasswordLabel => 'La tua password';

  @override
  String get changeEmailSameAsCurrent => 'È già il tuo indirizzo e-mail.';

  @override
  String get changeEmailWrongPassword => 'Questa non è la tua password.';

  @override
  String get changeEmailSubmit => 'Invia i link di conferma';

  @override
  String get changeEmailSentTitle => 'Due link sono in arrivo';

  @override
  String changeEmailSentMessage(String email) {
    return 'Conferma da $email e dall\'indirizzo del tuo account. L\'e-mail cambia quando hai fatto entrambi.';
  }

  @override
  String get changeEmailSentExpiry => 'I link scadono dopo 24 ore.';

  @override
  String get changeEmailSentDone => 'Ok, capito';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount video',
      one: '$formattedCount video',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Reciproco';

  @override
  String get socialProofFollowsYou => 'Ti segue';

  @override
  String get socialProofYouFollow => 'Segui già';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount follower',
      one: '$formattedCount follower',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'I video non si caricano al momento.\nDipende da noi, non da te — ci stiamo lavorando.';

  @override
  String get feedOfflineMessage =>
      'Sei offline.\nControlla la connessione e riprova.';

  @override
  String get dbFailureTitle => 'impossibile sbloccare il database locale';

  @override
  String get dbFailureAdviceResettable =>
      'Riavviare non risolverà il problema. Reimpostare il database locale qui sotto dà a Divine un nuovo inizio — il tuo account resta.';

  @override
  String get dbFailureAdviceRestart =>
      'Riavvia Divine dopo aver sbloccato il dispositivo. Se continua a succedere, aggiorna l\'app o contatta l\'assistenza.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Prova a riavviare Divine una volta. Se continua a succedere, aggiorna l’app o contatta l’assistenza. I tuoi dati locali sono ancora presenti.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostica: $code';
  }

  @override
  String get dbFailureCloseApp => 'chiudi Divine';

  @override
  String get dbFailureResetAction => 'reimposta database locale';

  @override
  String get dbFailureConfirmTitle => 'reimpostare il database locale?';

  @override
  String get dbFailureConfirmBody =>
      'Il tuo account resta. Le bozze e le clip salvate su questo dispositivo vengono eliminate — messaggi e feed tornano dalla rete.';

  @override
  String get dbFailureResetConfirm => 'reimposta ora il database locale';

  @override
  String get dbFailureCancel => 'annulla';

  @override
  String get dbFailureResetFailed =>
      'Non ha funzionato. Chiudi Divine e riprova.';

  @override
  String get dbFailureResetDoneTitle => 'database locale reimpostato';

  @override
  String get dbFailureResetDoneBody =>
      'Chiudi Divine e riaprilo — al prossimo avvio verrà creato un nuovo database locale.';

  @override
  String get authSignInOptionsInfo => 'Informazioni sulle opzioni di accesso';

  @override
  String get authShowPassword => 'Mostra password';

  @override
  String get authHidePassword => 'Nascondi password';

  @override
  String get followUserSemanticLabel => 'Segui utente';

  @override
  String get unfollowUserSemanticLabel => 'Smetti di seguire l\'utente';

  @override
  String get commentsLoadingSemanticLabel => 'Caricamento commenti';

  @override
  String get analyticsWindowAll => 'Tutto';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Segui utente $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Smetti di seguire l\'utente $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / mese';
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
      'È appena uscito un nuovo aggiornamento. Scoprilo →';

  @override
  String get updateModerateTitle =>
      'C\'è un aggiornamento dall\'ultima volta che hai controllato';

  @override
  String get updateUrgentTitle => 'Ti mancano correzioni importanti';

  @override
  String get updateNotNow => 'Non ora';

  @override
  String get updateAction => 'Aggiorna';

  @override
  String updateNewIn(String version) {
    return 'Novità nella versione $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Aggiornamento disponibile';
}

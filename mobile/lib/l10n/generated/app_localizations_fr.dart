// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Récupération de clips';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Trouve les enregistrements stockés sous un autre compte et les fichiers vidéo qu\'aucune entrée ne référence plus.';

  @override
  String get devOptionsClipRecoveryScan => 'Analyser';

  @override
  String get devOptionsClipRecoveryFailure =>
      'La récupération des clips a échoué';

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
      other: '$drafts brouillons',
      one: '$drafts brouillon',
    );
    return 'Visible actuellement : $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts =>
      'Masqués sous d\'autres comptes';

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
      other: '$drafts brouillons',
      one: '$drafts brouillon',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Déplacer vers ce compte';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Fichiers non référencés : $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport =>
      'Reconstruire dans la bibliothèque';

  @override
  String get devOptionsClipRecoveryEmpty => 'Rien à récupérer';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips récupérés',
      one: '$count clip récupéré',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Rapport de récupération copié';

  @override
  String get devOptionsStorageFootprint => 'Empreinte de stockage';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Tous les dossiers dans lesquels l\'app écrit. Vider le cache n\'en libère qu\'une partie.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Mesurer';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Total : $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Rapport de stockage copié';

  @override
  String get devOptionsStorageFootprintFailure =>
      'Impossible de mesurer le stockage';

  @override
  String get feedTuningMoreLabel => 'Plus comme ça';

  @override
  String get feedTuningLessLabel => 'Moins comme ça';

  @override
  String get feedTuningUndo => 'Annuler';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Ouvrir la vidéo référencée';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsSecureAccount => 'Sécurise ton compte';

  @override
  String get settingsSessionExpired => 'Session expirée';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Reconnecte-toi pour récupérer l\'accès complet';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Stats créateur';

  @override
  String get settingsSupportCenter => 'Centre d\'aide';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsBlueskyPublishing => 'Publication Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gère la diffusion croisée vers Bluesky';

  @override
  String get settingsNostrSettings => 'Réglages Nostr';

  @override
  String get settingsIntegratedApps => 'Apps intégrées';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Apps tierces approuvées qui tournent dans Divine';

  @override
  String get settingsExperimentalFeatures => 'Fonctionnalités expérimentales';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Des réglages qui peuvent avoir des ratés—essaie-les si tu es curieux.';

  @override
  String get settingsLegal => 'Mentions légales';

  @override
  String get settingsIntegrationPermissions => 'Permissions d\'intégration';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Vérifie et révoque les approbations d\'intégration enregistrées';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Le mode développeur est déjà activé';

  @override
  String get settingsDeveloperModeEnabled => 'Mode développeur activé !';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Encore $count appuis pour activer le mode développeur';
  }

  @override
  String get settingsShareDivine => 'Partage Divine avec tes amis';

  @override
  String get settingsSwitchAccount => 'Changer de compte';

  @override
  String get settingsAddAnotherAccount => 'Ajouter un autre compte';

  @override
  String get settingsAccountSwitchFailed =>
      'Impossible de changer de compte. Réessaie.';

  @override
  String get settingsUnsavedDraftsTitle => 'Brouillons non enregistrés';

  @override
  String get settingsUploadInProgressTitle => 'Envoi en cours';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vidéos',
      one: 'vidéo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tes vidéos restent en brouillons',
      one: 'ta vidéo reste en brouillon',
    );
    return 'Tu as encore $count $_temp0 en cours d\'envoi. Changer de compte arrête l\'envoi — $_temp1 dans ce compte.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'brouillons',
      one: 'brouillon',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tes brouillons',
      one: 'ton brouillon',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les',
      one: 'le',
    );
    return 'Tu as $count $_temp0 non enregistré$_temp1. Changer de compte va garder $_temp2, mais tu voudras peut-être $_temp3 publier ou relire d\'\'abord.';
  }

  @override
  String get settingsCancel => 'Annuler';

  @override
  String get settingsSwitchAnyway => 'Changer quand même';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'La session de ce compte a expiré. Y revenir signifie te déconnecter de celui que tu utilises maintenant.';

  @override
  String get settingsAppVersionLabel => 'Version de l\'app';

  @override
  String get settingsAppLanguage => 'Langue de l\'app';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (par défaut)';
  }

  @override
  String get settingsAppLanguageTitle => 'Langue de l\'app';

  @override
  String get settingsAppLanguageDescription =>
      'Choisis la langue de l\'interface';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Utiliser la langue de l\'appareil';

  @override
  String get settingsGeneralTitle => 'Réglages généraux';

  @override
  String get settingsContentSafetyTitle => 'Contenu et sécurité';

  @override
  String get generalSettingsSectionIntegrations => 'INTÉGRATIONS';

  @override
  String get generalSettingsSectionViewing => 'VISIONNAGE';

  @override
  String get generalSettingsSectionCreating => 'CRÉATION';

  @override
  String get generalSettingsSectionApp => 'APPLICATION';

  @override
  String get appearanceSettingsTitle => 'Apparence';

  @override
  String get appearanceSettingsSubtitle =>
      'Choisis l\'apparence de Divine sur cet appareil';

  @override
  String get appearanceSettingsSystem => 'Paramètre du système';

  @override
  String get appearanceSettingsLight => 'Clair';

  @override
  String get appearanceSettingsDark => 'Sombre';

  @override
  String get generalSettingsClosedCaptions => 'Sous-titres';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Affiche les sous-titres quand les vidéos en proposent';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Vidéos carrées uniquement';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Garde les fils dans le format carré classique';

  @override
  String get contentPreferencesTitle => 'Préférences de contenu';

  @override
  String get contentPreferencesContentFilters => 'Filtres de contenu';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gère les filtres d\'avertissement';

  @override
  String get contentPreferencesContentLanguage => 'Langue du contenu';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (par défaut)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Étiquette tes vidéos avec une langue pour que les spectateurs puissent filtrer le contenu.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Utiliser la langue de l\'appareil (par défaut)';

  @override
  String get contentPreferencesAudioSharing => 'Rendre mon audio réutilisable';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Quand c\'est activé, les autres peuvent utiliser l\'audio de tes vidéos';

  @override
  String get contentPreferencesMusicMode => 'Mode musique';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Désactive le nettoyage du bruit qui écrase les instruments. Mieux pour la musique, plus rugueux pour les voix.';

  @override
  String get contentPreferencesAccountLabels => 'Étiquettes de compte';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Auto-étiquette ton contenu';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Étiquettes de contenu du compte';

  @override
  String get contentPreferencesClearAll => 'Tout effacer';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Sélectionne tout ce qui s\'applique à ton compte';

  @override
  String get contentPreferencesDoneNoLabels => 'Terminé (aucune étiquette)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Terminé ($count sélectionnées)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Périphérique d\'entrée audio';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (recommandé)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Sélectionne automatiquement le meilleur micro';

  @override
  String get contentPreferencesSelectAudioInput =>
      'Sélectionner l\'entrée audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Micro inconnu';

  @override
  String get contentFiltersAdultContent => 'CONTENU POUR ADULTES';

  @override
  String get contentFiltersViolenceGore => 'VIOLENCE ET HORREUR';

  @override
  String get contentFiltersSubstances => 'SUBSTANCES';

  @override
  String get contentFiltersOther => 'AUTRE';

  @override
  String get contentFiltersAgeGateMessage =>
      'Vérifie ton âge dans Sécurité et confidentialité pour débloquer les filtres de contenu pour adultes';

  @override
  String get contentFiltersShow => 'Afficher';

  @override
  String get contentFiltersWarn => 'Avertir';

  @override
  String get contentFiltersFilterOut => 'Filtrer';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Ce compte n\'est pas disponible';

  @override
  String get profileInvalidId => 'ID de profil invalide';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Découvre $displayName sur Divine !\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName sur Divine';
  }

  @override
  String get profileShareFailed => 'Échec du partage du profil. Réessaie.';

  @override
  String get profileCopyPublicKey => 'Copier la clé publique (npub)';

  @override
  String get profileGetEmbedCode => 'Obtenir le code d\'intégration';

  @override
  String get profilePublicKeyCopied => 'Clé publique copiée';

  @override
  String get profileEmbedCodeCopied => 'Code d\'intégration copié';

  @override
  String get profileMoreTooltip => 'Plus';

  @override
  String get profileMoreSemanticLabel => 'Plus d\'options';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Fermer l\'avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Fermer l\'aperçu de l\'avatar';

  @override
  String get profileFollowingLabel => 'Abonné';

  @override
  String get profileFollowLabel => 'Suivre';

  @override
  String get profileBlockedLabel => 'Bloqué';

  @override
  String get profileFollowersLabel => 'Abonnés';

  @override
  String get profileFollowingStatLabel => 'Abonnements';

  @override
  String get profileVideosLabel => 'Vidéos';

  @override
  String get profileCollabsLabel => 'Collabs';

  @override
  String get profileLikedLabel => 'J\'aime';

  @override
  String get profileRepostsLabel => 'Reposts';

  @override
  String get profileListsLabel => 'Listes';

  @override
  String get profileCommentsLabel => 'Commentaires';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations de collaborateur restent à envoyer',
      one: '$count invitation de collaborateur reste à envoyer',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'On a gardé l\'invitation en file d\'attente. Réessaie ici.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Pour « $title ». Réessaie ici.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Réessayer';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Nouvel essai';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Le renvoi des invitations de collaborateur est indisponible pour le moment.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations de collaborateur restent à envoyer.',
      one: '$count invitation de collaborateur reste à envoyer.',
      zero: 'Invitations de collaborateur envoyées.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborateurs ne peuvent pas être invités.',
      one: '$count collaborateur ne peut pas être invité.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count utilisateurs';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Bloquer $displayName ?';
  }

  @override
  String get profileBlockExplanation => 'Quand tu bloques quelqu\'un :';

  @override
  String get profileBlockBulletHidePosts =>
      'Ses posts n\'apparaîtront plus dans tes fils.';

  @override
  String get profileBlockBulletCantView =>
      'Il ne pourra plus voir ton profil, te suivre, ou voir tes posts.';

  @override
  String get profileBlockBulletNoNotify =>
      'Il ne sera pas prévenu du changement.';

  @override
  String get profileBlockBulletYouCanView =>
      'Tu pourras toujours voir son profil.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Bloquer $displayName';
  }

  @override
  String get profileCancelButton => 'Annuler';

  @override
  String get profileLearnMore => 'En savoir plus';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Débloquer $displayName ?';
  }

  @override
  String get profileUnblockExplanation =>
      'Quand tu débloques cet utilisateur :';

  @override
  String get profileUnblockBulletShowPosts =>
      'Ses posts réapparaîtront dans tes fils.';

  @override
  String get profileUnblockBulletCanView =>
      'Il pourra voir ton profil, te suivre, et voir tes posts.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Il ne sera pas prévenu du changement.';

  @override
  String get profileLearnMoreAt => 'En savoir plus sur ';

  @override
  String get profileUnblockButton => 'Débloquer';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Ne plus suivre $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Bloquer $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Débloquer $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Signaler $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Ajouter $displayName à une liste';
  }

  @override
  String get profileNoCollabsTitle => 'Pas encore de collabs';

  @override
  String get profileCollabsOwnEmpty =>
      'Les vidéos que tu co-réalises apparaîtront ici';

  @override
  String get profileCollabsOtherEmpty =>
      'Les vidéos qu\'il co-réalise apparaîtront ici';

  @override
  String get profileErrorLoadingCollabs => 'Erreur de chargement des collabs';

  @override
  String get profileNoSavedVideosTitle => 'Rien d\'enregistré pour l\'instant';

  @override
  String get profileSavedOwnEmpty =>
      'Mets des vidéos en favoris depuis le menu de partage et elles apparaîtront ici.';

  @override
  String get profileErrorLoadingSaved =>
      'Erreur de chargement des vidéos enregistrées';

  @override
  String get profileNoCommentsOwnTitle => 'Pas encore de commentaires';

  @override
  String get profileNoCommentsOtherTitle => 'Aucun commentaire';

  @override
  String get profileCommentsOwnEmpty =>
      'Tes commentaires et réponses apparaîtront ici';

  @override
  String get profileCommentsOtherEmpty =>
      'Ses commentaires et réponses apparaîtront ici';

  @override
  String get profileErrorLoadingComments =>
      'Erreur de chargement des commentaires';

  @override
  String get profileVideoRepliesSection => 'Réponses vidéo';

  @override
  String get profileCommentsSection => 'Commentaires';

  @override
  String get profileEditLabel => 'Modifier';

  @override
  String get profileLibraryLabel => 'Bibliothèque';

  @override
  String get profileNoLikedVideosTitle => 'Pas encore de vidéos aimées';

  @override
  String get profileLikedOwnEmpty => 'Les vidéos que tu aimes apparaîtront ici';

  @override
  String get profileLikedOtherEmpty =>
      'Les vidéos qu\'il aime apparaîtront ici';

  @override
  String get profileErrorLoadingLiked =>
      'Erreur de chargement des vidéos aimées';

  @override
  String get profileNoRepostsTitle => 'Pas encore de reposts';

  @override
  String get profileRepostsOwnEmpty =>
      'Les vidéos que tu reposte apparaîtront ici';

  @override
  String get profileRepostsOtherEmpty =>
      'Les vidéos qu\'il reposte apparaîtront ici';

  @override
  String get profileErrorLoadingReposts =>
      'Erreur de chargement des vidéos repostées';

  @override
  String get profileNoVideosTitle => 'Pas encore de vidéos';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Partage ta première vidéo pour la voir ici';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Cet utilisateur n\'a pas encore partagé de vidéos';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniature vidéo $number';
  }

  @override
  String get profileShowMore => 'Afficher plus';

  @override
  String get profileShowLess => 'Afficher moins';

  @override
  String get dmMessageDisplayLimitReached =>
      'Le reste de ce message n’est pas affiché.';

  @override
  String get profileCompleteYourProfile => 'Complète ton profil';

  @override
  String get profileCompleteSubtitle =>
      'Ajoute ton nom, ta bio et ta photo pour commencer';

  @override
  String get profilePleaseTryAgain => 'Réessaie';

  @override
  String get profileSecureYourAccount => 'Sécurise ton compte';

  @override
  String get profileSecureSubtitle =>
      'Ajoute un e-mail et un mot de passe pour récupérer ton compte sur n\'importe quel appareil';

  @override
  String get profileRetryButton => 'Réessayer';

  @override
  String get profileSessionExpired => 'Session expirée';

  @override
  String get profileSignInToRestore =>
      'Reconnecte-toi pour récupérer l\'accès complet';

  @override
  String get profileSignInButton => 'Se connecter';

  @override
  String get profileMaybeLaterLabel => 'Plus tard';

  @override
  String get profileSecurePrimaryButton => 'Ajouter e-mail et mot de passe';

  @override
  String get profileCompletePrimaryButton => 'Mettre à jour ton profil';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'J\'aime';

  @override
  String get profileMyLibraryLabel => 'Ma bibliothèque';

  @override
  String get profileMessageLabel => 'Message';

  @override
  String get profileShareLabel => 'Partager le profil';

  @override
  String get profileDeletedAccountName => 'Compte supprimé';

  @override
  String get inboxActionReportVanishedAccount => 'Signaler ce compte';

  @override
  String get inboxActionBlockVanishedAccount => 'Bloquer ce compte';

  @override
  String get inboxActionUnblockVanishedAccount => 'Débloquer ce compte';

  @override
  String get inboxReportedVanishedAccount => 'Ce compte a été signalé';

  @override
  String get inboxBlockedVanishedAccount => 'Ce compte a été bloqué';

  @override
  String get inboxUnblockedVanishedAccount => 'Ce compte a été débloqué';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Cela retire la conversation de votre boîte de réception. Si cette personne vous réécrit, une nouvelle conversation commence.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Ce compte a été supprimé';

  @override
  String get profileUserFallback => 'utilisateur';

  @override
  String get profileLinkCopied => 'Lien du profil copié';

  @override
  String get profileSetupEditProfileTitle => 'Modifier le profil';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Configure ton profil avant d’ajouter une adresse NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Créer un profil';

  @override
  String get profileSetupBackLabel => 'Retour';

  @override
  String get profileSetupAboutNostr => 'À propos de Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil publié avec succès !';

  @override
  String get profileSetupUnsavedChangesTitle =>
      'Enregistrer les modifications ?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Enregistre tes modifications avant de partir, ou abandonne-les et continue.';

  @override
  String get profileSetupUnsavedChangesSaveButton =>
      'Enregistrer les modifications';

  @override
  String get profileSetupUnsavedChangesDiscardButton =>
      'Abandonner les modifications';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Continuer à modifier';

  @override
  String get profileSetupCreateNewProfile => 'Créer un nouveau profil ?';

  @override
  String get profileSetupNoExistingProfile =>
      'On n\'a pas trouvé de profil existant sur tes relays. Publier va créer un nouveau profil. Continuer ?';

  @override
  String get profileSetupPublishButton => 'Publier';

  @override
  String get profileSetupUsernameTaken =>
      'Ce nom d\'utilisateur vient d\'être pris. Choisis-en un autre.';

  @override
  String get profileSetupClaimFailed =>
      'Échec de la réservation du nom d\'utilisateur. Réessaie.';

  @override
  String get profileSetupPublishFailed =>
      'Échec de la publication du profil. Réessaie.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Impossible d\'accéder au réseau. Vérifie ta connexion et réessaie.';

  @override
  String get profileSetupDisplayNameLabel => 'Nom affiché';

  @override
  String get profileSetupDisplayNameRequired => 'Entre un nom affiché';

  @override
  String get profileSetupBioLabel => 'Bio (facultatif)';

  @override
  String get profileSetupWebsiteLabel => 'Site web (facultatif)';

  @override
  String get profileSetupPublicKeyLabel => 'Clé publique (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nom d\'utilisateur (facultatif)';

  @override
  String get profileSetupUsernameHelper =>
      'Utilise des lettres, des chiffres ou des tirets. Ton nom d\'utilisateur devient une adresse divine.video. Utilise ton nom d\'affichage pour les espaces ou les symboles.';

  @override
  String get profileSetupSaveButton => 'Enregistrer';

  @override
  String get profileSetupSavingButton => 'Enregistrement...';

  @override
  String get profileSetupImageUrlTitle => 'Ajouter une URL d\'image';

  @override
  String get profileSetupImageSelectionFailed =>
      'Échec de la sélection d\'image. Colle plutôt une URL d\'image ci-dessous.';

  @override
  String get profileSetupImagesTypeGroup => 'images';

  @override
  String get cameraPickErrorPermissionDenied =>
      'L\'accès à la caméra est désactivé. Active-le dans les Réglages pour prendre une photo.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'L\'accès à la caméra n\'est pas autorisé sur cet appareil.';

  @override
  String get cameraPickErrorBusy =>
      'Le sélecteur est déjà ouvert. Ferme-le et réessaie.';

  @override
  String get cameraPickErrorGeneric =>
      'Impossible d\'ouvrir la caméra. Réessaie.';

  @override
  String get profileSetupGotItButton => 'Compris';

  @override
  String get profileSetupUploadFailedGeneric =>
      'L\'envoi de l\'image a échoué. Réessaie plus tard.';

  @override
  String get profileSetupUploadNetworkError =>
      'Erreur réseau : vérifie ta connexion internet et réessaie.';

  @override
  String get profileSetupUploadAuthError =>
      'Erreur d\'authentification : déconnecte-toi et reconnecte-toi.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Fichier trop gros : choisis une image plus petite (10 Mo max).';

  @override
  String get profileSetupUploadServerError =>
      'L\'envoi de l\'image a échoué. Nos serveurs sont temporairement indisponibles. Réessaie dans un instant.';

  @override
  String get profileSetupBannerClearButton => 'Supprimer la bannière';

  @override
  String get profileSetupBannerChangeColor => 'Couleur de la bannière';

  @override
  String get profileSetupChangeBannerTitle => 'Changer la bannière';

  @override
  String get profileSetupBannerColorPickerTitle =>
      'Modifier la couleur de la bannière';

  @override
  String get profileSetupBannerColorCustom => 'Personnalisée';

  @override
  String get profileSetupBannerColorNone => 'Aucune couleur';

  @override
  String get profileSetupBannerColorLime => 'Citron vert';

  @override
  String get profileSetupBannerColorYellow => 'Jaune';

  @override
  String get profileSetupBannerColorViolet => 'Violet clair';

  @override
  String get profileSetupBannerColorPink => 'Rose';

  @override
  String get profileSetupBannerColorOrange => 'Orange';

  @override
  String get profileSetupBannerColorPurple => 'Violet';

  @override
  String get profileSetupAvatarClearButton => 'Supprimer la photo';

  @override
  String get profileSetupImageTakePhoto => 'Prendre une photo';

  @override
  String get profileSetupImageUploadFromCameraRoll =>
      'Importer depuis la galerie';

  @override
  String get profileSetupImagePasteLink => 'Coller un lien d\'image';

  @override
  String get profileSetupEditAvatarLabel => 'Modifier la photo de profil';

  @override
  String get profileSetupEditBannerLabel => 'Modifier la bannière';

  @override
  String get profileSetupUsernameChecking =>
      'Vérification de la disponibilité...';

  @override
  String get profileSetupUsernameAvailable => 'Nom d\'utilisateur disponible !';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Nom d\'utilisateur déjà pris';

  @override
  String get profileSetupUsernameReserved => 'Nom d\'utilisateur réservé';

  @override
  String get profileSetupContactSupport => 'Contacter le support';

  @override
  String get profileSetupCheckAgain => 'Vérifier à nouveau';

  @override
  String get profileSetupUsernameBurned =>
      'Ce nom d\'utilisateur n\'est plus disponible';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Seuls les lettres, chiffres et tirets sont autorisés';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Le nom d\'utilisateur ne peut pas commencer ni finir par un tiret';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Le nom d\'utilisateur doit faire 3 à 63 caractères';

  @override
  String get profileSetupUsernameNetworkError =>
      'Impossible de vérifier la disponibilité. Réessaie.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Format de nom d\'utilisateur invalide';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Échec de la vérification de disponibilité';

  @override
  String get profileSetupUsernameReservedTitle => 'Nom d\'utilisateur réservé';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Le nom $username est réservé. Dis-nous pourquoi il devrait être à toi.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'ex. c\'est mon nom de marque, mon nom de scène, etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Déjà contacté le support ? Appuie sur « Vérifier à nouveau » pour voir s\'il t\'a été libéré.';

  @override
  String get profileSetupSupportRequestSent =>
      'Demande envoyée au support ! On te répondra bientôt.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Impossible d\'ouvrir l\'e-mail. Envoie à : names@divine.video';

  @override
  String get profileSetupSendRequest => 'Envoyer la demande';

  @override
  String get profileSetupUseOwnNip05 => 'Utiliser ta propre adresse NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Adresse NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Format NIP-05 invalide (ex. : nom@domaine.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Utilise le champ nom d\'utilisateur ci-dessus pour divine.video';

  @override
  String get nostrSettingsNip05Address => 'Adresse NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Utilise ton nom d\'utilisateur divine.video, ou fais pointer ton identifiant vers une adresse NIP-05 sur un domaine que tu contrôles.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Enregistrer le NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 enregistré';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Impossible d\'enregistrer le NIP-05. Réessaie.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Utiliser ton propre NIP-05 ?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'Le NIP-05 relie un nom comme toi@tondomaine.fr à ton identité Nostr. Tu dois contrôler le domaine et héberger un fichier de vérification au bon chemin. Si c\'est mal réglé, on ne te trouve plus et ton identifiant vérifié disparaît. Continue seulement si tu as déjà tout configuré.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Continuer';

  @override
  String get profileSetupNip05ConfirmCancel => 'Annuler';

  @override
  String get profileSetupProfilePicturePreview =>
      'Aperçu de la photo de profil';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine tourne sur Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' un protocole ouvert résistant à la censure qui permet aux gens de communiquer en ligne sans dépendre d\'une seule entreprise ou plateforme. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Quand tu t\'inscris sur Divine, tu reçois une nouvelle identité Nostr.';

  @override
  String get nostrInfoOwnership =>
      'Nostr te permet de posséder ton contenu, ton identité et ton graphe social, que tu peux utiliser dans plein d\'apps. Résultat : plus de choix, moins de dépendance, et un internet social plus sain et résilient.';

  @override
  String get nostrInfoLingo => 'Le jargon Nostr :';

  @override
  String get nostrInfoNpubLabel => 'npub :';

  @override
  String get nostrInfoNpubDescription =>
      ' Ton adresse Nostr publique. Tu peux la partager sans risque et les autres pourront te trouver, te suivre ou t\'envoyer des messages dans toutes les apps Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec :';

  @override
  String get nostrInfoNsecDescription =>
      ' Ta clé privée et preuve de propriété. Elle donne le contrôle complet de ton identité Nostr, donc ';

  @override
  String get nostrInfoNsecWarning => 'garde-la toujours secrète !';

  @override
  String get nostrInfoUsernameLabel => 'Nom d\'utilisateur Nostr :';

  @override
  String get nostrInfoUsernameDescription =>
      ' Un nom lisible (comme @nom.divine.video) qui pointe vers ton npub. Ça rend ton identité Nostr plus facile à reconnaître et vérifier, un peu comme une adresse e-mail.';

  @override
  String get nostrInfoLearnMoreAt => 'En savoir plus sur ';

  @override
  String get nostrInfoGotIt => 'Compris !';

  @override
  String get videoGridRefreshLabel => 'Recherche de plus de vidéos';

  @override
  String get videoGridOptionsTitle => 'Options de la vidéo';

  @override
  String get videoGridEditVideo => 'Modifier la vidéo';

  @override
  String get videoGridEditVideoSubtitle =>
      'Mettre à jour titre, description et hashtags';

  @override
  String get videoGridDeleteVideo => 'Supprimer la vidéo';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Retirer cette vidéo de Divine. Elle peut encore apparaître dans d\'autres clients Nostr.';

  @override
  String get videoGridDeletingContent => 'Suppression du contenu...';

  @override
  String get exploreTabFeatured => 'À la une';

  @override
  String get exploreTabClassics => 'Classiques';

  @override
  String get exploreTabNew => 'Nouveautés';

  @override
  String get exploreTabPopular => 'Populaire';

  @override
  String get exploreTabCategories => 'Catégories';

  @override
  String get exploreTabForYou => 'Pour toi';

  @override
  String get exploreTabLists => 'Listes';

  @override
  String get exploreTabIntegratedApps => 'Apps intégrées';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Rien ici pour l\'instant. Repasse bientôt.';

  @override
  String get featuredTabLoadFailed => 'Impossible de charger cette collection.';

  @override
  String get featuredTabRetry => 'Réessayer';

  @override
  String get exploreNoVideosAvailable => 'Aucune vidéo disponible';

  @override
  String get exploreDiscoverLists => 'Découvrir les listes';

  @override
  String get exploreAboutLists => 'À propos des listes';

  @override
  String get exploreAboutListsDescription =>
      'Les listes t\'aident à organiser et curater le contenu Divine de deux façons :';

  @override
  String get explorePeopleLists => 'Listes de personnes';

  @override
  String get explorePeopleListsDescription =>
      'Suis des groupes de créateurs et vois leurs dernières vidéos';

  @override
  String get exploreVideoLists => 'Listes de vidéos';

  @override
  String get exploreVideoListsDescription =>
      'Crée des playlists de tes vidéos préférées à regarder plus tard';

  @override
  String get exploreMyLists => 'Mes listes';

  @override
  String get exploreSubscribedLists => 'Listes abonnées';

  @override
  String get exploreErrorLoadingLists =>
      'Erreur de chargement des listes. Réessaie.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles vidéos',
      one: '$count nouvelle vidéo',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nouvelles vidéos',
      one: 'nouvelle vidéo',
    );
    return 'Charger $count $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Lire la vidéo';

  @override
  String get videoPlayerMute => 'Couper le son de la vidéo';

  @override
  String get videoPlayerUnmute => 'Réactiver le son de la vidéo';

  @override
  String get videoPlayerTapHint =>
      'Appuyez pour lire ou mettre en pause. Double appui pour aimer.';

  @override
  String get videoSettingsMenuOpen => 'Ouvrir les paramètres de lecture';

  @override
  String get videoSettingsMenuClose => 'Fermer les paramètres de lecture';

  @override
  String get videoSettingsCaptionsEnable => 'Activer les sous-titres';

  @override
  String get videoSettingsCaptionsDisable => 'Désactiver les sous-titres';

  @override
  String get videoSettingsAutoAdvanceOn => 'Passage automatique activé';

  @override
  String get videoSettingsAutoAdvanceOff => 'Passage automatique désactivé';

  @override
  String get videoSettingsCaptionsOn => 'Sous-titres activés';

  @override
  String get videoSettingsCaptionsOff => 'Sous-titres désactivés';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Sous-titres activés pour cette vidéo';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Sous-titres désactivés pour cette vidéo';

  @override
  String get contentWarningLabel => 'Avertissement de contenu';

  @override
  String get contentWarningNudity => 'Nudité';

  @override
  String get contentWarningSexualContent => 'Contenu sexuel';

  @override
  String get contentWarningPornography => 'Pornographie';

  @override
  String get contentWarningGraphicMedia => 'Médias choquants';

  @override
  String get contentWarningViolence => 'Violence';

  @override
  String get contentWarningSelfHarm => 'Automutilation';

  @override
  String get contentWarningDrugUse => 'Usage de drogues';

  @override
  String get contentWarningAlcohol => 'Alcool';

  @override
  String get contentWarningTobacco => 'Tabac';

  @override
  String get contentWarningGambling => 'Jeux d\'argent';

  @override
  String get contentWarningProfanity => 'Langage grossier';

  @override
  String get contentWarningFlashingLights => 'Lumières clignotantes';

  @override
  String get contentWarningAiGenerated => 'Généré par IA';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Contenu sensible';

  @override
  String get contentWarningDescNudity =>
      'Contient de la nudité ou de la nudité partielle';

  @override
  String get contentWarningDescSexual => 'Contient du contenu sexuel';

  @override
  String get contentWarningDescPorn =>
      'Contient du contenu pornographique explicite';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contient des images choquantes ou dérangeantes';

  @override
  String get contentWarningDescViolence => 'Contient du contenu violent';

  @override
  String get contentWarningDescSelfHarm =>
      'Contient des références à l\'automutilation';

  @override
  String get contentWarningDescDrugs => 'Contient du contenu lié aux drogues';

  @override
  String get contentWarningDescAlcohol => 'Contient du contenu lié à l\'alcool';

  @override
  String get contentWarningDescTobacco => 'Contient du contenu lié au tabac';

  @override
  String get contentWarningDescGambling =>
      'Contient du contenu lié aux jeux d\'argent';

  @override
  String get contentWarningDescProfanity => 'Contient un langage fort';

  @override
  String get contentWarningDescFlashingLights =>
      'Contient des lumières clignotantes (avertissement photosensibilité)';

  @override
  String get contentWarningDescAiGenerated => 'Ce contenu a été généré par IA';

  @override
  String get contentWarningDescSpoiler => 'Contient des spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'Le créateur a marqué ça comme sensible';

  @override
  String get contentWarningDescDefault => 'Le créateur a signalé ce contenu';

  @override
  String get contentWarningDetailsTitle => 'Avertissements de contenu';

  @override
  String get contentWarningDetailsSubtitle =>
      'Le créateur a appliqué ces étiquettes :';

  @override
  String get contentWarningManageFilters => 'Gérer les filtres de contenu';

  @override
  String get contentWarningViewAnyway => 'Voir quand même';

  @override
  String get contentWarningReportContentTooltip => 'Signaler le contenu';

  @override
  String get contentWarningBlockUserTooltip => 'Bloquer l\'utilisateur';

  @override
  String get contentWarningBlockedTitle => 'Contenu bloqué';

  @override
  String get contentWarningBlockedPolicy =>
      'Ce contenu a été bloqué pour violation des règles.';

  @override
  String get contentWarningNoticeTitle => 'Avertissement de contenu';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Contenu potentiellement choquant';

  @override
  String get contentWarningView => 'Voir';

  @override
  String get contentWarningReportAction => 'Signaler';

  @override
  String get contentWarningHideAllLikeThis => 'Masquer tout contenu de ce type';

  @override
  String get contentWarningNoFilterYet =>
      'Pas encore de filtre enregistré pour cet avertissement.';

  @override
  String get contentWarningHiddenConfirmation =>
      'On masquera les posts comme ça désormais.';

  @override
  String get communitySuggestTitle => 'Aide à classifier ça';

  @override
  String get communitySuggestSubtitle =>
      'Il manque un avertissement de contenu ? Ta suggestion est publique, signée et ne peut pas être retirée.';

  @override
  String get communitySuggestSubmit => 'Suggérer';

  @override
  String get communitySuggestSuccess => 'Merci. Ta suggestion a été envoyée.';

  @override
  String get communitySuggestFailure =>
      'Impossible d\'envoyer ta suggestion. Réessaie.';

  @override
  String get communitySuggestAlready => 'Tu l\'as suggéré';

  @override
  String get communitySuggestActionLabel => 'Classifier';

  @override
  String get videoErrorNotFound => 'Vidéo introuvable';

  @override
  String get videoErrorPlayback => 'Erreur de lecture vidéo';

  @override
  String get videoErrorAgeRestricted => 'Contenu réservé aux adultes';

  @override
  String get videoErrorUnavailable => 'Vidéo indisponible';

  @override
  String get videoErrorUnavailableBody =>
      'Cette vidéo n\'est pas disponible pour le moment.';

  @override
  String get videoErrorRetry => 'Réessayer';

  @override
  String get videoErrorContentRestricted => 'Contenu restreint';

  @override
  String get videoErrorContentRestrictedBody =>
      'Cette vidéo a été retirée car elle enfreignait nos règles de contenu.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Vérifie ton âge pour voir cette vidéo.';

  @override
  String get videoErrorSkip => 'Passer';

  @override
  String get videoErrorVerifyAgeButton => 'Vérifier l\'âge';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Impossible de vérifier ton âge. Réessaie.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Délai de vérification dépassé. Vérifie ta connexion ou réessaie dans un instant.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Le contenu pour adultes est désactivé';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Active-le dans tes filtres de contenu pour regarder cette vidéo.';

  @override
  String get videoErrorAdultContentHiddenAction =>
      'Ouvrir les filtres de contenu';

  @override
  String get videoDetailLoadError => 'Échec du chargement de la vidéo';

  @override
  String get videoDetailLoadErrorBody =>
      'Quelque chose a déraillé en chemin. Réessaie.';

  @override
  String get videoDetailNotFoundBody =>
      'Elle a peut-être été supprimée, elle est hors de portée, ou tes réglages la masquent.';

  @override
  String get databaseCorruptionTitle => 'Tes données locales sont abîmées';

  @override
  String get databaseCorruptionBody =>
      'Ferme Divine et rouvre-la : on répare ça automatiquement. On sauve ce qu\'on peut de tes brouillons et clips, le reste se recharge.';

  @override
  String get databaseCorruptionCloseButton => 'Fermer Divine';

  @override
  String get videoDetailContextTitle => 'Vidéo partagée';

  @override
  String get videoDetailCloseSemanticLabel => 'Fermer le lecteur vidéo';

  @override
  String get videoFollowButtonFollow => 'Suivre';

  @override
  String get audioAttributionOriginalSound => 'Son original';

  @override
  String get audioAttributionUnavailableSound => 'Son indisponible';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspiré par @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspiré par @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'avec @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'avec @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborateurs',
      one: '$count collaborateur',
    );
    return '$_temp0. Appuie pour voir le profil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'En attente';

  @override
  String get videoCollaboratorPendingSemanticLabel =>
      'Collaborateur en attente';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending en attente)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Appuie pour voir le profil.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Touche pour voir les vidéos avec ce hashtag.';
  }

  @override
  String get listAttributionFallback => 'Liste';

  @override
  String get shareVideoLabel => 'Partager la vidéo';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post partagé avec $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Post partagé avec $count personnes',
      one: 'Post partagé avec $count personne',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Échec de l\'envoi de la vidéo';

  @override
  String get shareAddedToBookmarks => 'Ajouté aux favoris';

  @override
  String get shareRemovedFromBookmarks => 'Retiré des favoris';

  @override
  String get shareFailedToAddBookmark => 'Échec de l\'ajout aux favoris';

  @override
  String get shareFailedToRemoveBookmark => 'Échec du retrait des favoris';

  @override
  String get shareActionFailed => 'Action échouée';

  @override
  String get shareWithTitle => 'Partager avec';

  @override
  String get shareFindPeople => 'Trouver des gens';

  @override
  String get shareFindPeopleMultiline => 'Trouver\ndes gens';

  @override
  String get shareSent => 'Envoyé';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name sélectionné';
  }

  @override
  String get shareMessageHint => 'Ajouter un message (facultatif)...';

  @override
  String get videoActionUnlike => 'Ne plus aimer la vidéo';

  @override
  String get videoActionLike => 'Aimer la vidéo';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'J\'aime';

  @override
  String get videoActionReplyLabel => 'Répondre';

  @override
  String get videoActionRepostLabel => 'Reposter';

  @override
  String get videoActionShareLabel => 'Partager';

  @override
  String get videoActionReportLabel => 'Signaler';

  @override
  String get videoActionReport => 'Signaler la vidéo';

  @override
  String get videoActionEditLabel => 'Modifier';

  @override
  String get videoActionEdit => 'Modifier la vidéo';

  @override
  String get videoActionAboutLabel => 'À propos';

  @override
  String get videoActionEnableAutoAdvance => 'Activer le passage automatique';

  @override
  String get videoActionDisableAutoAdvance =>
      'Désactiver le passage automatique';

  @override
  String get videoActionRemoveRepost => 'Supprimer le repost';

  @override
  String get videoActionRepost => 'Reposter la vidéo';

  @override
  String get videoActionViewComments => 'Voir les commentaires';

  @override
  String get videoActionMoreOptions => 'Plus d\'options';

  @override
  String get videoEngagementLikersTitle => 'Aimé par';

  @override
  String get videoEngagementRepostersTitle => 'Reposté par';

  @override
  String get videoEngagementLikersEmpty => 'Aucun j\'aime pour l\'instant';

  @override
  String get videoEngagementRepostersEmpty => 'Aucun repost pour l\'instant';

  @override
  String get videoEngagementLoadFailed => 'Impossible de charger la liste';

  @override
  String get videoOverlayOpenMetadataFromTitle =>
      'Ouvrir les détails de la vidéo';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Ouvrir les détails de la vidéo';

  @override
  String get videoOverlayCommentBarHint => 'Ajouter un commentaire...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Ajouter un commentaire';

  @override
  String get videoOverlayCommentBarSendLabel => 'Envoyer le commentaire';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Commentaire publié';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Impossible de publier le commentaire';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'boucles',
      one: 'boucle',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Pas Divine';

  @override
  String get metadataBadgeHumanMade => 'Fait main';

  @override
  String get metadataSoundsLabel => 'Sons';

  @override
  String get metadataOriginalSound => 'Son original';

  @override
  String get metadataVerificationLabel => 'Vérification';

  @override
  String get metadataDeviceAttestation => 'Attestation d\'appareil';

  @override
  String get metadataPgpSignature => 'Signature PGP';

  @override
  String get metadataC2paCredentials => 'Content Credentials C2PA';

  @override
  String get metadataProofManifest => 'Manifeste de preuve';

  @override
  String get metadataVerificationInfoTooltip =>
      'Que signifient ces vérifications ?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle =>
      'Ce que signifient ces vérifications';

  @override
  String get metadataVerificationInfoIntro =>
      'Ces signaux proviennent de la caméra et du fichier vidéo lui-même. Plus une vidéo en réunit, plus nous pouvons prouver son origine.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Le système d\'exploitation du téléphone s\'est porté garant de l\'app qui a filmé. Une bonne preuve que ça vient d\'une caméra, pas d\'un fichier importé.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'La vidéo a été signée cryptographiquement au moment de la prise. Changez une seule image ensuite et la signature se brise.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Un certificat d\'origine aux normes du secteur, transporté dans le fichier — d\'autres apps que Divine peuvent donc le vérifier.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'L\'enregistrement ProofMode complet : empreinte du fichier, horodatage et contexte de prise de vue, joints à la vidéo.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Une vérification manquante ne rend pas une vidéo fausse. Les clips anciens et les imports n\'en ont jamais eu — cela veut seulement dire que nous ne pouvons pas prouver cette partie.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'En savoir plus sur $url';
  }

  @override
  String get metadataCreatorLabel => 'Créateur';

  @override
  String get metadataCollaboratorsLabel => 'Collaborateurs';

  @override
  String get metadataInspiredByLabel => 'Inspiré par';

  @override
  String get metadataRepostedByLabel => 'Reposté par';

  @override
  String metadataMoreReposters(int count) {
    return '+$count autres';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'J\'aime';

  @override
  String get metadataCommentsLabel => 'Commentaires';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get metadataVineStatsLabel => 'Sur Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loops · $likes J\'aime · $comments commentaires · $reposts reposts';
  }

  @override
  String get metadataDivineStatsLabel => 'Sur Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views vues · $likes J\'aime · $comments commentaires · $reposts reposts';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publié le $date';
  }

  @override
  String get devOptionsTitle => 'Options développeur';

  @override
  String get devOptionsDisableDeveloperMode => 'Désactiver le mode développeur';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Masquer les options développeur des réglages';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Mode développeur désactivé';

  @override
  String get devOptionsShorebirdTitle => 'Correctifs Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Correctif actif';

  @override
  String get devOptionsShorebirdNoPatch => 'Aucun correctif installé';

  @override
  String get devOptionsShorebirdUnavailable =>
      'Indisponible dans cette version';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Les correctifs fonctionnent uniquement dans une version créée avec shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Lecture de l’état du correctif…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Canal de test pas encore vérifié.';

  @override
  String get devOptionsShorebirdCheck => 'Vérifier le canal de test';

  @override
  String get devOptionsShorebirdApply => 'Appliquer le correctif de test';

  @override
  String get devOptionsShorebirdUseStable => 'Revenir aux mises à jour stables';

  @override
  String get devOptionsShorebirdChecking => 'Vérification du canal de test…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Un correctif de test est prêt à être appliqué.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Aucun correctif de test pour cette version.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Téléchargé. Redémarrez l’app pour le charger.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Un retour arrière est prêt. Redémarrez pour revenir à la version de base.';

  @override
  String get devOptionsShorebirdApplying => 'Téléchargement et installation…';

  @override
  String get devOptionsShorebirdApplied =>
      'Installé. Redémarrez l’app pour le charger.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Rien n’a été installé. Vérifiez le canal de test et réessayez.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Sélection du canal stable…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Canal stable sélectionné. Redémarrez l’app pour rechercher un patch stable.';

  @override
  String get devOptionsShorebirdFailure =>
      'Ça n’a pas fonctionné. Consultez les journaux pour plus de détails.';

  @override
  String get devOptionsPageLoadTimes => 'Temps de chargement';

  @override
  String get devOptionsNoPageLoads =>
      'Aucun chargement de page enregistré pour le moment.\nNavigue dans l\'app pour voir les données de temps.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visible : ${visibleMs}ms  |  Données : ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Écrans les plus lents';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format de lecture vidéo';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Changer d\'environnement ?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Passer à $envName ?\n\nCette action va effacer les données vidéo en cache et se reconnecter au nouveau relay.';
  }

  @override
  String get devOptionsCancel => 'Annuler';

  @override
  String get devOptionsSwitch => 'Changer';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Passé à $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Passé à $formatName — cache effacé';
  }

  @override
  String get featureFlagTitle => 'Indicateurs de fonctionnalité';

  @override
  String get featureFlagResetAllTooltip => 'Réinitialiser tous les indicateurs';

  @override
  String get featureFlagError => 'Erreur';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine est un système ouvert - tu contrôles tes connexions';

  @override
  String get relaySettingsInfoDescription =>
      'Ces relays distribuent ton contenu sur le réseau Nostr décentralisé. Tu peux en ajouter ou en retirer comme tu veux.';

  @override
  String get relaySettingsLearnMoreNostr => 'En savoir plus sur Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Trouve des relays publics sur nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App non fonctionnelle';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine a besoin d\'au moins un relay pour charger des vidéos, publier du contenu et synchroniser les données.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Restaurer le relay par défaut';

  @override
  String get relaySettingsAddCustomRelay => 'Ajouter un relay personnalisé';

  @override
  String get relaySettingsAddRelay => 'Ajouter un relay';

  @override
  String get relaySettingsRetry => 'Réessayer';

  @override
  String get relaySettingsNoStats =>
      'Aucune statistique disponible pour le moment';

  @override
  String get relaySettingsConnection => 'Connexion';

  @override
  String get relaySettingsConnected => 'Connecté';

  @override
  String get relaySettingsDisconnected => 'Déconnecté';

  @override
  String get relaySettingsSessionDuration => 'Durée de session';

  @override
  String get relaySettingsLastConnected => 'Dernière connexion';

  @override
  String get relaySettingsDisconnectedLabel => 'Déconnecté';

  @override
  String get relaySettingsReason => 'Raison';

  @override
  String get relaySettingsActiveSubscriptions => 'Abonnements actifs';

  @override
  String get relaySettingsTotalSubscriptions => 'Total des abonnements';

  @override
  String get relaySettingsEventsReceived => 'Événements reçus';

  @override
  String get relaySettingsEventsSent => 'Événements envoyés';

  @override
  String get relaySettingsRequestsThisSession => 'Requêtes cette session';

  @override
  String get relaySettingsFailedRequests => 'Requêtes échouées';

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Chargement des infos du relay...';

  @override
  String get relaySettingsAboutRelay => 'À propos du relay';

  @override
  String get relaySettingsSupportedNips => 'NIPs supportés';

  @override
  String get relaySettingsSoftware => 'Logiciel';

  @override
  String get relaySettingsViewWebsite => 'Voir le site web';

  @override
  String get relaySettingsRemoveRelayTitle => 'Retirer le relay ?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Tu es sûr de vouloir retirer ce relay ?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Retirer le relay Divine ?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Retirer le relay de Divine dégradera l\'expérience dans l\'app. Les vidéos, la publication et la synchronisation risquent d\'être moins fiables. À réserver aux utilisateurs Nostr expérimentés.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Retirer le relay';

  @override
  String get relaySettingsCancel => 'Annuler';

  @override
  String get relaySettingsRemove => 'Retirer';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay retiré : $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Échec du retrait du relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Reconnexion forcée au relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Connecté à $count relay(s) !';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Échec de la connexion aux relays. Vérifie ta connexion réseau.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Enregistré sur cet appareil. On le synchronisera avec ton compte quand la publication refonctionnera.';

  @override
  String get relaySettingsAddRelayTitle => 'Ajouter un relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Entre l\'URL WebSocket du relay que tu veux ajouter :';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Parcours les relays publics sur nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Ajouter';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay ajouté : $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Échec de l\'ajout du relay. Vérifie l\'URL et réessaie.';

  @override
  String get relaySettingsInvalidUrl =>
      'L\'URL du relay doit commencer par wss:// ou ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'L\'URL du relay doit utiliser wss:// (ws:// est autorisé seulement pour localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay par défaut restauré : $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Échec de la restauration du relay par défaut. Vérifie ta connexion réseau.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Impossible d\'ouvrir le navigateur';

  @override
  String get relaySettingsFailedToOpenLink => 'Échec de l\'ouverture du lien';

  @override
  String get relaySettingsExternalRelay => 'Relay externe';

  @override
  String get relaySettingsNotConnected => 'Non connecté';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Déconnecté il y a $duration';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count abos';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count événements';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'il y a $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine utilise le protocole Nostr pour la publication décentralisée. Ton contenu vit sur les relays que tu choisis, et tes clés sont ton identité.';

  @override
  String get nostrSettingsSectionNetwork => 'Réseau';

  @override
  String get nostrSettingsSectionAccount => 'Compte';

  @override
  String get nostrSettingsSectionDangerZone => 'Zone de danger';

  @override
  String get nostrSettingsRelays => 'Relais';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Gère les connexions aux relays Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostics relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Débogue la connectivité des relays et les soucis réseau';

  @override
  String get nostrSettingsMediaServers => 'Serveurs média';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configure les serveurs d\'upload Blossom';

  @override
  String get settingsDeveloperOptions => 'Options développeur';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Sélecteur d\'environnement et réglages de débogage';

  @override
  String get nostrSettingsKeyManagement => 'Gestion des clés';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exporte, sauvegarde et restaure tes clés Nostr';

  @override
  String get nostrSettingsClientAttribution => 'Attribution du client';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Ajoute un tag client Divine aux événements que tu publies pour que les autres apps Nostr puissent les attribuer correctement. Sans lui, les signalements que tu envoies pèsent moins lourd quand nos modérateurs les examinent.';

  @override
  String get nostrSettingsMoveAccount => 'Déplacer ton compte';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Télécharge ton archive et déplace tes publications et vidéos vers un autre relais ou serveur média.';

  @override
  String get nostrSettingsRemoveKeys => 'Retirer les clés de l\'appareil';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Supprime ta clé privée de cet appareil uniquement. Ton contenu reste sur les relays, mais tu auras besoin de ta sauvegarde nsec pour accéder à nouveau à ton compte.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Impossible de retirer ce compte de cet appareil. Réessaie.';

  @override
  String get nostrSettingsDeleteAccount => 'Supprimer le compte et les données';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Envoie des demandes de suppression pour ton contenu et te déconnecte sur cet appareil. Les relays, clients, index de recherche et autres appareils connectés peuvent garder des copies.';

  @override
  String get relayDiagnosticTitle => 'Diagnostics relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Actualiser les diagnostics';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Dernière actualisation : $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'État du relay';

  @override
  String get relayDiagnosticInitialized => 'Initialisé';

  @override
  String get relayDiagnosticReady => 'Prêt';

  @override
  String get relayDiagnosticNotInitialized => 'Non initialisé';

  @override
  String get relayDiagnosticDatabaseEvents => 'Événements en base';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Abonnements actifs';

  @override
  String get relayDiagnosticExternalRelays => 'Relays externes';

  @override
  String get relayDiagnosticConfigured => 'Configuré';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Connecté';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Événements vidéo';

  @override
  String get relayDiagnosticHomeFeed => 'Fil d\'accueil';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count vidéos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Découverte';

  @override
  String get relayDiagnosticLoading => 'Chargement';

  @override
  String get relayDiagnosticYes => 'Oui';

  @override
  String get relayDiagnosticNo => 'Non';

  @override
  String get relayDiagnosticTestDirectQuery => 'Tester une requête directe';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Connectivité réseau';

  @override
  String get relayDiagnosticRunNetworkTest => 'Lancer un test réseau';

  @override
  String get relayDiagnosticBlossomServer => 'Serveur Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Tester tous les endpoints';

  @override
  String get relayDiagnosticStatus => 'État';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Erreur';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL de base';

  @override
  String get relayDiagnosticSummary => 'Résumé';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (moy. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retester tout';

  @override
  String get relayDiagnosticRetrying => 'Nouvelle tentative...';

  @override
  String get relayDiagnosticRetryConnection => 'Réessayer la connexion';

  @override
  String get relayDiagnosticTroubleshooting => 'Dépannage';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Vert = Connecté et fonctionnel\n• Rouge = Connexion échouée\n• Si le test réseau échoue, vérifie ta connexion internet\n• Si les relays sont configurés mais non connectés, appuie sur « Réessayer la connexion »\n• Fais une capture d\'écran pour le débogage';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Tous les endpoints REST sont sains !';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Certains endpoints REST ont échoué - voir les détails ci-dessus';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '$count événements vidéo trouvés en base';
  }

  @override
  String get relayDiagnosticQueryFailed => 'Requête échouée. Réessaie.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Connecté à $count relay(s) !';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Échec de la connexion aux relays';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Nouvelle tentative de connexion échouée. Réessaie.';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Connecté et authentifié';

  @override
  String get relayDiagnosticConnectedOnly => 'Connecté';

  @override
  String get relayDiagnosticNotConnected => 'Non connecté';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Aucun relay configuré';

  @override
  String get relayDiagnosticFailed => 'Échec';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSettingsResetTooltip => 'Réinitialiser par défaut';

  @override
  String get notificationSettingsTypes => 'Types de notifications';

  @override
  String get notificationSettingsLikes => 'J\'aime';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Quand quelqu\'un aime tes vidéos';

  @override
  String get notificationSettingsComments => 'Commentaires';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Quand quelqu\'un commente tes vidéos';

  @override
  String get notificationSettingsFollows => 'Abonnements';

  @override
  String get notificationSettingsFollowsSubtitle => 'Quand quelqu\'un te suit';

  @override
  String get notificationSettingsMentions => 'Mentions';

  @override
  String get notificationSettingsMentionsSubtitle => 'Quand tu es mentionné';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Quand quelqu\'un reposte tes vidéos';

  @override
  String get notificationSettingsNewPosts => 'Nouvelles vines';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Quand quelqu\'un que tu suis publie';

  @override
  String get notificationSettingsActions => 'Actions';

  @override
  String get notificationSettingsMarkAllAsRead => 'Tout marquer comme lu';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Marquer toutes les notifications comme lues';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Toutes les notifications marquées comme lues';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Échec du marquage de toutes comme lues';

  @override
  String get notificationSettingsResetToDefaults =>
      'Réglages réinitialisés par défaut';

  @override
  String get notificationSettingsAbout => 'À propos des notifications';

  @override
  String get notificationSettingsAboutDescription =>
      'Les notifications fonctionnent grâce au protocole Nostr. Les mises à jour en temps réel dépendent de ta connexion aux relays Nostr. Certaines notifications peuvent avoir du retard.';

  @override
  String get safetySettingsWhatYouSee => 'CE QUE TU VOIS';

  @override
  String get safetySettingsWhatYouPublish => 'CE QUE TU PUBLIES';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Afficher uniquement les vidéos hébergées par Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Masquer les vidéos servies par d\'autres hébergeurs média';

  @override
  String get safetySettingsModeration => 'MODÉRATION';

  @override
  String get safetySettingsBlockedUsers => 'UTILISATEURS BLOQUÉS';

  @override
  String get safetySettingsAgeVerification => 'VÉRIFICATION D\'ÂGE';

  @override
  String get safetySettingsAgeConfirmation =>
      'Je confirme avoir 18 ans ou plus';

  @override
  String get safetySettingsAgeRequired =>
      'Requis pour voir du contenu pour adultes';

  @override
  String get safetySettingsAgeLockedForMinor => 'Verrouillé pour ton compte';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Service de modération officiel (activé par défaut)';

  @override
  String get safetySettingsPeopleIFollow => 'Les gens que je suis';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'S\'abonner aux étiquettes des gens que tu suis';

  @override
  String get safetySettingsAddCustomLabeler =>
      'Ajouter un étiqueteur personnalisé';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Entre le npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Ajouter un étiqueteur personnalisé';

  @override
  String get safetySettingsRemoveLabeler => 'Supprimer l\'étiqueteur';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Entre l\'adresse npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Aucun utilisateur bloqué';

  @override
  String get safetySettingsUnblock => 'Débloquer';

  @override
  String get safetySettingsUserUnblocked => 'Utilisateur débloqué';

  @override
  String get safetySettingsCancel => 'Annuler';

  @override
  String get safetySettingsAdd => 'Ajouter';

  @override
  String get analyticsTitle => 'Stats créateur';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostics';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Basculer les diagnostics';

  @override
  String get analyticsRetry => 'Réessayer';

  @override
  String get analyticsUnableToLoad => 'Impossible de charger les stats.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Connecte-toi pour voir les stats créateur.';

  @override
  String get analyticsViewDataUnavailable =>
      'Les vues ne sont actuellement pas disponibles depuis le relay pour ces posts. Les métriques de j\'aime/commentaires/reposts sont toujours précises.';

  @override
  String get analyticsViewDataTitle => 'Données de vues';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Mis à jour $time • Les scores utilisent j\'aime, commentaires, reposts et vues/loops depuis Funnelcake quand c\'est disponible.';
  }

  @override
  String get analyticsVideos => 'Vidéos';

  @override
  String get analyticsViews => 'Vues';

  @override
  String get analyticsInteractions => 'Interactions';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Abonnés';

  @override
  String get analyticsAvgPerPost => 'Moy./Post';

  @override
  String get analyticsInteractionMix => 'Mix d\'interactions';

  @override
  String get analyticsLikes => 'J\'aime';

  @override
  String get analyticsComments => 'Commentaires';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Points forts de performance';

  @override
  String get analyticsMostViewed => 'Plus vue';

  @override
  String get analyticsMostDiscussed => 'Plus commentée';

  @override
  String get analyticsMostReposted => 'Plus repostée';

  @override
  String get analyticsNoVideosYet => 'Pas encore de vidéos';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Données de vues indisponibles';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count vues';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count commentaires';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Top contenu';

  @override
  String get analyticsPublishPrompt =>
      'Publie quelques vidéos pour voir les classements.';

  @override
  String get analyticsEngagementRateExplainer =>
      '% à droite = taux d\'engagement (interactions divisées par vues).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Le taux d\'engagement a besoin des données de vues ; les valeurs s\'affichent en N/D tant que les vues ne sont pas disponibles.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'vues indisponibles';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interactions';
  }

  @override
  String get analyticsPostAnalytics => 'Stats du post';

  @override
  String get analyticsOpenPost => 'Ouvrir le post';

  @override
  String get analyticsRecentDailyInteractions =>
      'Interactions quotidiennes récentes';

  @override
  String get analyticsNoActivityYet =>
      'Pas encore d\'activité sur cette période.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interactions = j\'aime + commentaires + reposts par date de post.';

  @override
  String get analyticsDailyBarExplainer =>
      'La longueur des barres est relative à ton meilleur jour sur cette fenêtre.';

  @override
  String get analyticsAudienceSnapshot => 'Aperçu de l\'audience';

  @override
  String analyticsFollowersCount(String count) {
    return 'Abonnés : $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Abonnements : $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Les répartitions source/géo/temps de l\'audience se rempliront quand Funnelcake ajoutera les endpoints d\'analytics d\'audience.';

  @override
  String get analyticsRetention => 'Rétention';

  @override
  String get analyticsRetentionWithViews =>
      'La courbe de rétention et la répartition du temps de visionnage apparaîtront quand la rétention par seconde/par tranche arrivera de Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Données de rétention indisponibles tant que les analytics vues+temps de visionnage ne sont pas retournées par Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostics';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Vidéos totales : $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Avec vues : $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Vues manquantes : $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydraté (bulk) : $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydraté (/views) : $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sources : $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Utiliser des données fixtures';

  @override
  String get analyticsNa => 'N/D';

  @override
  String get authCreateNewAccount => 'Créer un nouveau compte Divine';

  @override
  String get authCreateNewAccountShort => 'Créer un compte';

  @override
  String get authSignInDifferentAccount => 'Se connecter avec un autre compte';

  @override
  String get authUseAnotherAccount => 'Utiliser un autre compte';

  @override
  String authContinueAs(String displayName) {
    return 'Continuer en tant que $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Tes brouillons et clips sont enregistrés pour ce compte';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Se connecter ici masquera ces brouillons et clips';

  @override
  String get authTermsPrefix =>
      'En choisissant une option ci-dessous, tu confirmes avoir au moins 16 ans (ou avoir effectué l\'';

  @override
  String get authTermsAgeAuthorizationCta => 'autorisation d\'âge Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') et tu acceptes les ';

  @override
  String get authTermsOfService => 'Conditions d\'utilisation';

  @override
  String get authPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get authTermsAnd => ', et les ';

  @override
  String get authSafetyStandards => 'Normes de sécurité';

  @override
  String get authAmberNotInstalled => 'L\'app Amber n\'est pas installée';

  @override
  String get authAmberConnectionFailed => 'Échec de la connexion avec Amber';

  @override
  String get authPasswordResetSent =>
      'Si un compte existe avec cet e-mail, un lien de réinitialisation du mot de passe a été envoyé.';

  @override
  String get authSignInTitle => 'Se connecter';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authConfirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get authEmailRequired => 'L\'e-mail est obligatoire';

  @override
  String get authEmailInvalid => 'Veuillez saisir un e-mail valide';

  @override
  String get authPasswordRequired => 'Le mot de passe est obligatoire';

  @override
  String get authConfirmPasswordRequired =>
      'Veuillez confirmer votre mot de passe';

  @override
  String get authPasswordsDoNotMatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authImportNostrKey => 'Importer une clé Nostr';

  @override
  String get authConnectSignerApp => 'Se connecter avec une app de signature';

  @override
  String get authSignInWithAmber => 'Se connecter avec Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Se connecter avec une extension de navigateur';

  @override
  String get authNip07ConnectionFailed =>
      'Impossible de se connecter à votre extension de navigateur.';

  @override
  String get authNip07ExtensionNotFound =>
      'Aucune extension de navigateur trouvée. Installez Alby, nos2x ou une autre extension compatible NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Options de connexion';

  @override
  String get authInfoEmailPasswordTitle => 'E-mail et mot de passe';

  @override
  String get authInfoEmailPasswordDescription =>
      'Connecte-toi avec ton compte Divine. Si tu t\'es inscrit avec un e-mail et un mot de passe, utilise-les ici.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Tu as déjà une identité Nostr ? Importe ta clé privée nsec depuis un autre client.';

  @override
  String get authInfoSignerAppTitle => 'App de signature';

  @override
  String get authInfoSignerAppDescription =>
      'Connecte-toi avec un signataire distant compatible NIP-46 comme nsecBunker pour une sécurité de clé renforcée.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Utilise l\'app de signature Amber sur Android pour gérer tes clés Nostr en toute sécurité.';

  @override
  String get authInfoBrowserExtensionTitle => 'Extension de navigateur';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Connectez-vous avec une extension de navigateur NIP-07 comme Alby ou nos2x. Vos clés restent dans l\'extension — Divine ne les voit jamais.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'E-mail ou mot de passe incorrect. Réessaie.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Vérifie ton e-mail avant de te connecter — consulte ta boîte de réception pour le lien.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Cette adresse e-mail ne semble pas valide.';

  @override
  String get authSignInErrorNetwork =>
      'Impossible de joindre le serveur. Vérifie ta connexion et réessaie.';

  @override
  String get authSignInErrorGeneric => 'Une erreur s\'est produite. Réessaie.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Tu ne sais plus comment tu t\'es connecté la dernière fois ? ';

  @override
  String get authSignInOptionsHintCta => 'Voir toutes les options de connexion';

  @override
  String get authCreateAccountTitle => 'Créer un compte';

  @override
  String get authBackToInviteCode => 'Retour au code d\'invitation';

  @override
  String get authUseDivineNoBackup => 'Utiliser Divine sans sauvegarde';

  @override
  String get authSkipConfirmTitle => 'Une dernière chose...';

  @override
  String get authSkipConfirmKeyCreated =>
      'C\'est bon ! On va créer une clé sécurisée qui anime ton compte Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Sans e-mail, ta clé est le seul moyen pour Divine de savoir que ce compte est à toi.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Tu peux accéder à ta clé dans l\'app, mais si tu n\'es pas tech, on recommande d\'ajouter un e-mail et un mot de passe maintenant. Ça rend plus simple la connexion et la récupération de ton compte si tu perds ou réinitialises cet appareil.';

  @override
  String get authAddEmailPassword => 'Ajouter e-mail et mot de passe';

  @override
  String get authUseThisDeviceOnly => 'Utiliser uniquement cet appareil';

  @override
  String get authCompleteRegistration => 'Termine ton inscription';

  @override
  String get authVerifying => 'Vérification...';

  @override
  String get authVerificationLinkSent =>
      'On a envoyé un lien de vérification à :';

  @override
  String get authClickVerificationLink =>
      'Clique sur le lien dans ton e-mail pour\nterminer ton inscription.';

  @override
  String get authPleaseWaitVerifying =>
      'Patiente pendant qu\'on vérifie ton e-mail...';

  @override
  String get authWaitingForVerification => 'En attente de vérification';

  @override
  String get authOpenEmailApp => 'Ouvrir l\'app e-mail';

  @override
  String get authVerificationPinPrompt =>
      'Ou entre le code à 6 chiffres de ton e-mail';

  @override
  String get authVerificationPinFieldLabel => 'Code à 6 chiffres';

  @override
  String get authVerificationPinSubmit => 'Vérifier le code';

  @override
  String get authVerificationResendPrompt => 'Rien reçu ?';

  @override
  String get authVerificationResend => 'Renvoyer';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Renvoyer dans $time';
  }

  @override
  String get authVerificationResendFailed =>
      'On n\'a pas pu renvoyer l\'e-mail. Réessaie.';

  @override
  String get authVerificationResendExpired =>
      'Cette inscription a expiré. Recommence pour recevoir un nouveau code.';

  @override
  String get authVerificationResendUnavailable =>
      'Le renvoi n\'est pas possible pour le moment. Utilise le code à 6 chiffres de l\'e-mail qu\'on t\'a déjà envoyé.';

  @override
  String get authVerificationPollingStopped =>
      'On a arrêté de vérifier à ta place. Saisis le code à 6 chiffres reçu par e-mail pour terminer la connexion.';

  @override
  String get authWelcomeToDivine => 'Bienvenue sur Divine !';

  @override
  String get authEmailVerified => 'Ton e-mail a été vérifié.';

  @override
  String get authSigningYouIn => 'On te connecte';

  @override
  String get authErrorTitle => 'Aïe.';

  @override
  String get authVerificationFailed =>
      'On n\'a pas pu vérifier ton e-mail.\nRéessaie.';

  @override
  String get authStartOver => 'Recommencer';

  @override
  String get authEmailVerifiedLogin =>
      'E-mail vérifié ! Connecte-toi pour continuer.';

  @override
  String get authVerificationLinkExpired =>
      'Ce lien de vérification n\'est plus valide.';

  @override
  String get authVerificationConnectionError =>
      'Impossible de vérifier l\'e-mail. Vérifie ta connexion et réessaie.';

  @override
  String get authWaitlistConfirmTitle => 'C\'est bon !';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'On partagera les mises à jour à $email.\nQuand plus de codes d\'invitation seront disponibles, on t\'en enverra.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Réessayer';

  @override
  String get authContactSupport => 'Contacter le support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Impossible d\'ouvrir $email';
  }

  @override
  String get authAddInviteCode => 'Ajoute ton code d\'invitation';

  @override
  String get authInviteCodeLabel => 'Code d\'invitation';

  @override
  String get authEnterYourCode => 'Entre ton code';

  @override
  String get authNext => 'Suivant';

  @override
  String get authJoinWaitlist => 'Rejoindre la liste d\'attente';

  @override
  String get authJoinWaitlistTitle => 'Rejoindre la liste d\'attente';

  @override
  String get authJoinWaitlistDescription =>
      'Partage ton e-mail et on t\'enverra des mises à jour dès que l\'accès s\'ouvre.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Envoyez-moi de l\'inspiration Divine';

  @override
  String get authInviteAccessHelp => 'Aide pour l\'accès par invitation';

  @override
  String get authGeneratingConnection => 'Génération de la connexion...';

  @override
  String get authConnectedAuthenticating => 'Connecté ! Authentification...';

  @override
  String get authConnectionTimedOut => 'Délai de connexion dépassé';

  @override
  String get authApproveConnection =>
      'Assure-toi d\'avoir approuvé la connexion dans ton app de signature.';

  @override
  String get authConnectionCancelled => 'Connexion annulée';

  @override
  String get authConnectionCancelledMessage => 'La connexion a été annulée.';

  @override
  String get authConnectionFailed => 'Échec de la connexion';

  @override
  String get authUnknownError => 'Une erreur inconnue est survenue.';

  @override
  String get authNostrConnectStartFailed =>
      'Impossible de joindre l\'app de signature. Vérifie ta connexion et réessaie.';

  @override
  String get authNostrConnectInvalidSession =>
      'Ce lien de connexion n\'est plus valide. Génères-en un nouveau.';

  @override
  String get authNostrConnectSetupFailed =>
      'On y est presque — impossible de finaliser ta connexion. Réessaie.';

  @override
  String get authUrlCopied => 'URL copiée dans le presse-papiers';

  @override
  String get authConnectToDivine => 'Se connecter à Divine';

  @override
  String get authPasteBunkerUrl => 'Colle l\'URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker invalide. Elle doit commencer par bunker://';

  @override
  String get authScanSignerApp =>
      'Scanne avec ton\napp de signature pour te connecter.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'En attente de connexion... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copier l\'URL';

  @override
  String get authShare => 'Partager';

  @override
  String get authAddBunker => 'Ajouter bunker';

  @override
  String get authCompatibleSignerApps => 'Apps de signature compatibles';

  @override
  String get authFailedToConnect => 'Échec de la connexion';

  @override
  String get authResetPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get authResetPasswordSubtitle =>
      'Entre ton nouveau mot de passe. Il doit faire au moins 8 caractères.';

  @override
  String get authNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get authConfirmNewPasswordLabel => 'Confirmer le nouveau mot de passe';

  @override
  String get authPasswordTooShort =>
      'Le mot de passe doit faire au moins 8 caractères';

  @override
  String get authPasswordResetSuccess =>
      'Mot de passe réinitialisé avec succès. Connecte-toi.';

  @override
  String get authPasswordResetFailed =>
      'Échec de la réinitialisation du mot de passe';

  @override
  String get authUnexpectedError =>
      'Une erreur inattendue est survenue. Réessaie.';

  @override
  String get authUpdatePassword => 'Mettre à jour le mot de passe';

  @override
  String get authSecureAccountTitle => 'Sécuriser le compte';

  @override
  String get authUnableToAccessKeys =>
      'Impossible d\'accéder à tes clés. Réessaie.';

  @override
  String get authRegistrationFailed => 'Échec de l\'inscription';

  @override
  String get authRegistrationComplete =>
      'Inscription terminée. Vérifie ton e-mail.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'Échec de l\'envoi de l\'e-mail de réinitialisation.';

  @override
  String get authSending => 'Envoi...';

  @override
  String get authSignInButton => 'Se connecter';

  @override
  String get authVerificationErrorTimeout =>
      'Délai de vérification dépassé. Essaie de t\'inscrire à nouveau.';

  @override
  String get authVerificationErrorMissingCode =>
      'Vérification échouée — code d\'autorisation manquant.';

  @override
  String get authVerificationErrorPollFailed =>
      'Vérification échouée. Réessaie.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Erreur réseau pendant la connexion. Réessaie.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Vérification échouée. Essaie de t\'inscrire à nouveau.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Connexion échouée. Essaie de te connecter manuellement.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Cet e-mail est déjà inscrit. Connecte-toi plutôt.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Ce code ne correspond pas. Vérifie-le et réessaie.';

  @override
  String get authVerificationErrorPinExpired =>
      'Ce code a expiré. Appuie sur Renvoyer pour en recevoir un nouveau.';

  @override
  String get authVerificationErrorPinLocked =>
      'Trop de tentatives. Appuie sur Renvoyer pour obtenir un nouveau code.';

  @override
  String get authVerificationErrorPinFailed =>
      'On n\'a pas pu vérifier ce code. Réessaie.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'La saisie du code n\'est pas disponible pour l\'instant. Appuie sur le lien dans ton e-mail, ou renvoie pour en recevoir un nouveau.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Saisis un code d\'invitation comme ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Ce code d\'invitation ne semble pas valide.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Ce code d\'invitation a déjà été utilisé ou révoqué.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Les invitations de ce créateur sont épuisées';

  @override
  String get authInviteGateErrorUnavailable =>
      'Ce code d\'invitation n\'est pas disponible. Inscris-toi sur la liste d\'attente et on t\'enverra une invitation dès qu\'il y aura de la place.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Impossible de vérifier ce code. Réessaie.';

  @override
  String get authInviteGateErrorUnknown =>
      'Un problème est survenu. Réessaie avec ton code d\'invitation.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Ce code d\'invitation n\'est plus disponible. Retourne à ton code d\'invitation, rejoins la liste d\'attente, ou contacte le support.';

  @override
  String get authInviteErrorInvalid =>
      'Ce code d\'invitation ne peut pas être utilisé pour l\'instant. Retourne à ton code d\'invitation, rejoins la liste d\'attente, ou contacte le support.';

  @override
  String get authInviteErrorTemporary =>
      'On n\'a pas pu confirmer ton invitation pour l\'instant. Retourne à ton code d\'invitation et réessaie, ou contacte le support.';

  @override
  String get authInviteErrorUnknown =>
      'On n\'a pas pu activer ton invitation. Retourne à ton code d\'invitation, rejoins la liste d\'attente, ou contacte le support.';

  @override
  String get shareSheetSave => 'Enregistrer';

  @override
  String get shareSheetRemoveFromSaved => 'Retirer des favoris';

  @override
  String get shareSheetSaveToGallery => 'Enregistrer dans la galerie';

  @override
  String get shareSheetSaveWithWatermark => 'Enregistrer avec filigrane';

  @override
  String get shareSheetSaveVideo => 'Enregistrer la vidéo';

  @override
  String get shareSheetAddToClips => 'Ajouter aux clips';

  @override
  String get shareSheetNameClipTitle => 'Nomme ce clip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Choisis un nom que tu reconnaîtras dans ta bibliothèque.';

  @override
  String get shareSheetClipTitleLabel => 'Titre du clip';

  @override
  String get shareSheetSaveClip => 'Enregistrer le clip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '« $title » enregistré dans les clips';
  }

  @override
  String get shareSheetUntitledClip => 'Clip sans titre';

  @override
  String get shareSheetAddToClipsFailed => 'Impossible d\'ajouter aux clips';

  @override
  String get shareSheetAddToList => 'Ajouter à une liste';

  @override
  String get shareSheetCopy => 'Copier';

  @override
  String get shareSheetShareVia => 'Partager via';

  @override
  String get shareSheetEventJson => 'JSON de l\'événement';

  @override
  String get shareSheetEventId => 'ID de l\'événement';

  @override
  String get shareSheetMoreActions => 'Plus d\'actions';

  @override
  String get shareSheetCrosspost => 'Crossposter';

  @override
  String get crosspostSheetTitle => 'Crossposter cette vidéo';

  @override
  String get crosspostSheetSubtitle =>
      'Envoie-la sur tes plateformes connectées. La publication peut prendre quelques minutes.';

  @override
  String get crosspostSubmit => 'Crossposter';

  @override
  String get crosspostStatusQueued => 'En file d\'attente';

  @override
  String get crosspostStatusUploading => 'Envoi en cours';

  @override
  String get crosspostStatusProcessing => 'Traitement en cours';

  @override
  String get crosspostStatusPosted => 'Publié';

  @override
  String get crosspostStatusFailed => 'Échec';

  @override
  String get crosspostStatusSkipped => 'Ignoré';

  @override
  String get crosspostStatusNeedsReauth => 'Reconnexion nécessaire';

  @override
  String get crosspostViewPost => 'Voir la publication';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Reconnecte $platform dans les réglages de crosspost pour continuer à publier.';
  }

  @override
  String get crosspostReconnect => 'Reconnecter';

  @override
  String get crosspostErrorNotOwner =>
      'Seules tes propres vidéos peuvent être crosspostées.';

  @override
  String get crosspostErrorNotEligible =>
      'Cette vidéo n\'est pas éligible au crosspost.';

  @override
  String get crosspostErrorNotConnected =>
      'Cette plateforme n\'est pas connectée.';

  @override
  String get crosspostErrorUnauthorized =>
      'Reconnecte ton compte, puis réessaie.';

  @override
  String get crosspostErrorNetwork =>
      'Impossible de joindre le crossposter. Réessaie dans un instant.';

  @override
  String get crosspostFailedGeneric => 'Échec du crosspost.';

  @override
  String get crosspostStillWorking =>
      'C\'est encore en cours. Tu peux fermer ça — la publication continue en arrière-plan.';

  @override
  String get crosspostDone => 'Terminé';

  @override
  String get watermarkDownloadSavedToCameraRoll =>
      'Enregistré dans la pellicule';

  @override
  String get watermarkDownloadShare => 'Partager';

  @override
  String get watermarkDownloadDone => 'Terminé';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Accès aux Photos requis';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Pour enregistrer les vidéos, autorise l\'accès aux Photos dans les Réglages.';

  @override
  String get watermarkDownloadOpenSettings => 'Ouvrir les Réglages';

  @override
  String get watermarkDownloadNotNow => 'Pas maintenant';

  @override
  String get watermarkDownloadFailed => 'Téléchargement échoué';

  @override
  String get watermarkDownloadDismiss => 'Ignorer';

  @override
  String get watermarkDownloadStageDownloading => 'Téléchargement de la vidéo';

  @override
  String get watermarkDownloadStageWatermarking => 'Ajout du filigrane';

  @override
  String get watermarkDownloadStageSaving => 'Enregistrement dans la pellicule';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Récupération de la vidéo depuis le réseau...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Application du filigrane Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Enregistrement de la vidéo avec filigrane dans ta pellicule...';

  @override
  String get shareMenuBookmarks => 'Favoris';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count ensembles d\'abonnements disponibles';
  }

  @override
  String get peopleListsAddToList => 'Ajouter à la liste';

  @override
  String get peopleListsSheetTitle => 'Ajouter à la liste';

  @override
  String get peopleListsEmptyTitle => 'Aucune liste pour l\'instant';

  @override
  String get peopleListsEmptySubtitle =>
      'Crée une liste pour commencer à regrouper des personnes.';

  @override
  String get peopleListsCreateList => 'Créer une liste';

  @override
  String get peopleListsNewListTitle => 'Nouvelle liste';

  @override
  String get peopleListsRouteTitle => 'Liste de personnes';

  @override
  String get peopleListsListNameLabel => 'Nom de la liste';

  @override
  String get peopleListsListNameHint => 'Amis proches';

  @override
  String get peopleListsCreateButton => 'Créer';

  @override
  String get peopleListsAddPeopleTitle => 'Ajouter des personnes';

  @override
  String get peopleListsAddPeopleTooltip => 'Ajouter des personnes';

  @override
  String get peopleListsAddPeopleSemanticLabel =>
      'Ajouter des personnes à la liste';

  @override
  String get peopleListsListNotFoundTitle => 'Liste introuvable';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Liste introuvable. Elle a peut-être été supprimée.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Cette liste a peut-être été supprimée.';

  @override
  String get peopleListsNoPeopleTitle => 'Aucune personne dans cette liste';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'Ajoute des personnes pour commencer';

  @override
  String get peopleListsNoVideosTitle => 'Pas encore de vidéos';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Les vidéos des membres de la liste apparaîtront ici';

  @override
  String get peopleListsNoVideosAvailable => 'Aucune vidéo disponible';

  @override
  String get peopleListsFailedToLoadVideos =>
      'Impossible de charger les vidéos';

  @override
  String get peopleListsVideoNotAvailable => 'Vidéo non disponible';

  @override
  String get peopleListsBackToGridTooltip => 'Retour à la grille';

  @override
  String get peopleListsErrorLoadingVideos =>
      'Erreur lors du chargement des vidéos';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Aucune personne disponible à ajouter.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Ajouter à $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Rechercher des personnes';

  @override
  String get peopleListsAddPeopleError =>
      'Impossible de charger les personnes. Veuillez réessayer.';

  @override
  String get peopleListsAddPeopleRetry => 'Réessayer';

  @override
  String get peopleListsAddButton => 'Ajouter';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Ajouter $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dans $count listes',
      one: 'Dans $count liste',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Cette personne sera retirée de cette liste.';

  @override
  String get peopleListsRemove => 'Retirer';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name retiré(e) de la liste';
  }

  @override
  String get peopleListsUndo => 'Annuler';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil de $name. Appui long pour retirer.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Voir le profil de $name';
  }

  @override
  String get shareMenuEditVideo => 'Modifier la vidéo';

  @override
  String get shareMenuDeleteVideo => 'Supprimer la vidéo';

  @override
  String shareMenuVideoCount(int count) {
    return '$count vidéos';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Cela supprimera définitivement cette vidéo de Divine. Elle peut encore apparaître dans des clients Nostr tiers qui utilisent d\'autres relays.';

  @override
  String get shareMenuCancel => 'Annuler';

  @override
  String get shareMenuDelete => 'Supprimer';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'La suppression n\'est pas prête. Réessaie dans un instant.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Tu peux supprimer uniquement tes propres vidéos.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Reconnecte-toi, puis réessaie de supprimer.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Impossible de signer la demande de suppression. Réessaie.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Le relais n\'a pas accepté cette demande de suppression. Réessaie dans un instant.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Impossible de joindre le relais. Vérifie ta connexion et réessaie.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Supprimée. Tous les relais n\'ont pas confirmé, elle peut donc encore apparaître dans d\'autres apps.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Impossible de supprimer cette vidéo. Réessaie.';

  @override
  String get shareMenuUpdate => 'Mettre à jour';

  @override
  String get shareMenuChangeCover => 'Changer la couverture';

  @override
  String get shareMenuVideoUpdated => 'Vidéo mise à jour avec succès';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations de collaborateur n\'\'ont pas été envoyées.',
      one: '$count invitation de collaborateur n\'\'a pas été envoyée.',
    );
    return 'Vidéo mise à jour, mais $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Reconnecte-toi, puis réessaie.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Cette vidéo n\'a pas de source lisible, elle ne peut pas être modifiée.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Impossible de signer la modification. Réessaie.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Le relais n\'a pas accepté la modification. Réessaie dans un instant.';

  @override
  String get videoUpdateErrorGeneric =>
      'Impossible de mettre à jour cette vidéo. Réessaie.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Supprimer la vidéo ?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Suppression de la vidéo…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Vidéo supprimée.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Vidéo supprimée. Elle peut mettre un peu de temps à disparaître partout.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Vidéo supprimée, mais nous n’avons pas pu retirer toutes les copies. Contacte l’assistance.';

  @override
  String get authSessionExpired => 'Ta session a expiré. Reconnecte-toi.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Échec de la connexion. Réessaie.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Authentification web non supportée en mode sécurisé. Utilise l\'app mobile pour une gestion sécurisée des clés.';

  @override
  String get webAuthEnterBunkerUri => 'Entre une URI bunker';

  @override
  String get webAuthConnectTitle => 'Se connecter à Divine';

  @override
  String get webAuthChooseMethod =>
      'Choisis ta méthode d\'authentification Nostr préférée';

  @override
  String get webAuthBrowserExtension => 'Extension de navigateur';

  @override
  String get webAuthRecommended => 'RECOMMANDÉ';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner =>
      'Se connecter à un signataire distant';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Coller depuis le presse-papiers';

  @override
  String get webAuthConnectToBunker => 'Se connecter au Bunker';

  @override
  String get webAuthNewToNostr => 'Nouveau sur Nostr ?';

  @override
  String get webAuthNostrHelp =>
      'Installe une extension de navigateur comme Alby ou nos2x pour la plus simple expérience, ou utilise nsec bunker pour la signature distante sécurisée.';

  @override
  String get soundsTitle => 'Sons';

  @override
  String get soundsSearchHint => 'Rechercher des sons...';

  @override
  String get soundsSearchResults => 'Résultats de recherche';

  @override
  String get soundsNoSoundsFound => 'Aucun son trouvé';

  @override
  String get soundsNoSoundsFoundDescription =>
      'Essaie un autre terme de recherche';

  @override
  String get soundsSavedToLibrary => 'Enregistré dans Sons';

  @override
  String get soundsAlreadySavedToLibrary => 'Déjà dans Sons';

  @override
  String get soundsSavedLibraryTitle => 'Mes sons';

  @override
  String get soundsSavedEmptyTitle => 'Aucun son enregistré pour le moment';

  @override
  String get soundsSavedEmptyDescription =>
      'Touche Utiliser le son sur une vidéo pour l\'enregistrer ici.';

  @override
  String get soundsRemoveSavedSound => 'Supprimer le son';

  @override
  String get savedSoundSaveAction => 'Enregistrer';

  @override
  String get savedSoundPausePreviewAction => 'Mettre l\'aperçu en pause';

  @override
  String get savedSoundResumePreviewAction => 'Reprendre l\'aperçu';

  @override
  String get savedSoundDetailsSheetTitle => 'Détails du son';

  @override
  String get savedSoundRemoveConfirmTitle => 'Retirer ce son ?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Il disparaîtra de ta bibliothèque, mais tu peux le réenregistrer depuis n\'importe quelle vidéo qui l\'utilise.';

  @override
  String get soundsRemovedFromLibrary => 'Supprimé de Sons';

  @override
  String get soundsSaveFailed => 'Impossible d\'enregistrer ce son. Réessaie.';

  @override
  String get soundsRemoveFailed => 'Impossible de retirer ce son. Réessaie.';

  @override
  String get soundSyncStatusSyncing => 'Synchronisation de tes sons…';

  @override
  String get soundSyncStatusSynced => 'Sons à jour';

  @override
  String get soundSyncStatusFailed =>
      'Impossible de synchroniser tes sons. On réessaiera.';

  @override
  String get soundSyncStatusLocked =>
      'Impossible de déverrouiller ta bibliothèque synchronisée sur cet appareil.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMoreOptions => 'Plus d\'options';

  @override
  String profileBlockedUser(String name) {
    return '$name bloqué';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name débloqué';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Tu ne suis plus $name';
  }

  @override
  String get profileFeedError =>
      'Impossible de joindre le serveur. Vérifie ta connexion et réessaie.';

  @override
  String get profileFeedLoadMoreError =>
      'Impossible de charger d\'autres vidéos. Tire pour actualiser.';

  @override
  String get notificationsTabAll => 'Tout';

  @override
  String get notificationsTabLikes => 'J\'aime';

  @override
  String get notificationsTabComments => 'Commentaires';

  @override
  String get notificationsTabFollows => 'Abonnements';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad =>
      'Échec du chargement des notifications';

  @override
  String get notificationsRetry => 'Réessayer';

  @override
  String get notificationsRefreshError =>
      'Échec de l\'actualisation — affichage des éléments disponibles';

  @override
  String get notificationsUnreadPrefix => 'Notification non lue';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications non lues',
      one: '$count notification non lue',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Voir le profil de $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Voir les profils';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Miniature de la vidéo $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Miniature de la vidéo';

  @override
  String get notificationsInviteSingular =>
      'Tu as 1 invitation à partager avec un ami !';

  @override
  String notificationsInvitePlural(int count) {
    return 'Tu as $count invitations à partager avec des amis !';
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
  String get notificationsVideoUnavailable => 'Vidéo indisponible';

  @override
  String get feedFailedToLoadVideos => 'Échec du chargement des vidéos';

  @override
  String get feedRetry => 'Réessayer';

  @override
  String get feedNoFollowedUsers =>
      'Personne suivie.\nSuis quelqu\'un pour voir ses vidéos ici.';

  @override
  String get feedModeForYou => 'Pour toi';

  @override
  String get feedModeNew => 'Nouveau';

  @override
  String get feedModeFollowing => 'Abonnements';

  @override
  String get feedModeClassics => 'Classiques';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Fil d\'actualité : $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Auteur de la vidéo : $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar de l\'auteur';

  @override
  String get feedForYouEmpty =>
      'Ton fil Pour toi est vide.\nExplore des vidéos et abonne-toi à des créateurs pour le personnaliser.';

  @override
  String get feedFollowingEmpty =>
      'Aucune vidéo des personnes que tu suis pour le moment.\nTrouve des créateurs que tu aimes et abonne-toi à eux.';

  @override
  String get feedLatestEmpty =>
      'Aucune nouvelle vidéo pour le moment.\nReviens bientôt.';

  @override
  String get feedClassicEmpty =>
      'Aucun classique pour le moment.\nReviens bientôt.';

  @override
  String get feedExploreVideos => 'Explorer les vidéos';

  @override
  String get feedLoadingMore => 'Chargement d\'autres vidéos…';

  @override
  String get feedRefreshed => 'Fil actualisé';

  @override
  String get uploadUploadingVideo => 'Envoi de la vidéo';

  @override
  String get postPublishConfirmationTitle => 'Publiée sur ton profil';

  @override
  String get postPublishConfirmationView => 'Voir';

  @override
  String get postPublishConfirmationShare => 'Partager';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Miniature de la vidéo que tu viens de publier';

  @override
  String get userSearchNoResults => 'Aucun utilisateur trouvé';

  @override
  String get userPickerFilterByNameHint => 'Filtrer par nom...';

  @override
  String get userPickerSearchByNameHint => 'Rechercher par nom...';

  @override
  String get userPickerClearSearchSemantics => 'Effacer la recherche';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name déjà ajouté';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Sélectionner $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Retirer $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Ton crew est là dehors';

  @override
  String get userPickerEmptyFollowListBody =>
      'Suis des personnes avec qui tu vibes. Quand elles te suivent aussi, vous pouvez collaborer.';

  @override
  String get userPickerGoBack => 'Retour';

  @override
  String get userPickerTypeNameToSearch => 'Saisis un nom pour rechercher';

  @override
  String get userPickerUnavailable =>
      'La recherche d\'utilisateurs est indisponible. Réessaie plus tard.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'La recherche a échoué. Réessaie.';

  @override
  String get forgotPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get forgotPasswordDescription =>
      'Entre ton adresse e-mail et on t\'enverra un lien pour réinitialiser ton mot de passe.';

  @override
  String get forgotPasswordEmailLabel => 'Adresse e-mail';

  @override
  String get forgotPasswordCancel => 'Annuler';

  @override
  String get forgotPasswordSendLink => 'Envoyer le lien par e-mail';

  @override
  String get ageVerificationContentWarning => 'Avertissement de contenu';

  @override
  String get ageVerificationTitle => 'Vérification d\'âge';

  @override
  String get ageVerificationAdultDescription =>
      'Ce contenu a été signalé comme pouvant contenir du matériel pour adultes. Tu dois avoir 18 ans ou plus pour le voir.';

  @override
  String get ageVerificationCreationDescription =>
      'Pour utiliser la caméra et créer du contenu, tu dois avoir au moins 16 ans.';

  @override
  String get ageVerificationAdultQuestion => 'As-tu 18 ans ou plus ?';

  @override
  String get ageVerificationCreationQuestion => 'As-tu 16 ans ou plus ?';

  @override
  String get ageVerificationNo => 'Non';

  @override
  String get ageVerificationYes => 'Oui';

  @override
  String get navHome => 'Accueil';

  @override
  String get navExplore => 'Explorer';

  @override
  String get navInbox => 'Boîte';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Mon profil';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navOpenCamera => 'Ouvrir la caméra';

  @override
  String get navExploreClassics => 'Classiques';

  @override
  String get navExploreNewVideos => 'Nouvelles vidéos';

  @override
  String get navExploreTrending => 'Tendance';

  @override
  String get navExploreForYou => 'Pour toi';

  @override
  String get navExploreLists => 'Listes';

  @override
  String get routeErrorTitle => 'Erreur';

  @override
  String get routeInvalidHashtag => 'Hashtag invalide';

  @override
  String get routeInvalidConversationId => 'ID de conversation invalide';

  @override
  String get routeInvalidRequestId => 'ID de requête invalide';

  @override
  String get routeInvalidListId => 'ID de liste invalide';

  @override
  String get routeInvalidUserId => 'ID d\'utilisateur invalide';

  @override
  String get routeInvalidVideoId => 'ID de vidéo invalide';

  @override
  String get routeInvalidSoundId => 'ID de son invalide';

  @override
  String get routeInvalidCategory => 'Catégorie invalide';

  @override
  String get routeNoVideosToDisplay => 'Aucune vidéo à afficher';

  @override
  String get routeGoHome => 'Aller à l\'accueil';

  @override
  String get routeInvalidProfileId => 'ID de profil invalide';

  @override
  String get routeUnknownPath => 'Cette page n’est pas dans l’app.';

  @override
  String get routeDefaultListName => 'Liste';

  @override
  String get supportTitle => 'Centre d\'aide';

  @override
  String get supportContactSupport => 'Contacter le support';

  @override
  String get supportContactSupportSubtitle =>
      'Démarre une conversation ou consulte les messages passés';

  @override
  String get supportReportBug => 'Signaler un bug';

  @override
  String get supportReportBugSubtitle => 'Problèmes techniques avec l\'app';

  @override
  String get supportRequestFeature => 'Demander une fonctionnalité';

  @override
  String get supportRequestFeatureSubtitle =>
      'Suggérer une amélioration ou une nouvelle fonctionnalité';

  @override
  String get supportSaveLogs => 'Sauvegarder les logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Exporter les logs vers un fichier pour envoi manuel';

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
  String get supportFaqSubtitle => 'Questions et réponses courantes';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Aider parents et ados à adopter des habitudes saines en ligne';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Comment nous gérons les comptes selon l\'âge';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'En savoir plus sur la vérification et l\'authenticité';

  @override
  String get supportLoginRequired => 'Connecte-toi pour contacter le support';

  @override
  String get supportExportingLogs => 'Exportation des logs...';

  @override
  String get supportExportLogsFailed => 'Échec de l\'exportation des logs';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Journaux enregistrés dans $path';
  }

  @override
  String get supportRevealLogsAction => 'Afficher dans le dossier';

  @override
  String get supportChatNotAvailable => 'Chat du support indisponible';

  @override
  String get supportCouldNotOpenMessages =>
      'Impossible d\'ouvrir les messages du support';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Impossible d\'ouvrir $pageName';
  }

  @override
  String get reportWhyReporting => 'Pourquoi signales-tu ce contenu ?';

  @override
  String get reportPolicyNotice =>
      'Divine agira sur les signalements de contenu dans les 24 heures en retirant le contenu et en excluant l\'utilisateur qui a fourni le contenu en infraction.';

  @override
  String get reportBlockUser => 'Bloquer cet utilisateur';

  @override
  String get reportCancel => 'Annuler';

  @override
  String get reportSubmit => 'Signaler';

  @override
  String get reportSelectReason =>
      'Sélectionne une raison pour signaler ce contenu';

  @override
  String get reportOtherRequiresDetails =>
      'Décris le problème quand tu choisis Autre';

  @override
  String get reportDetailsRequired => 'Décris le problème';

  @override
  String get reportDetailsTextOnly =>
      'Texte uniquement — impossible de joindre des photos ou des GIF ici.';

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
  String get reportReasonSpam => 'Spam ou contenu indésirable';

  @override
  String get reportReasonSpamSubtitle => 'Contenu indésirable ou répétitif';

  @override
  String get reportReasonHarassment => 'Harcèlement, intimidation ou menaces';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Réponses ou mentions nuisibles et indésirables';

  @override
  String get reportReasonViolence => 'Contenu violent ou extrémiste';

  @override
  String get reportReasonViolenceSubtitle =>
      'Contenu violent, extrémiste ou nuisible';

  @override
  String get reportReasonSexualContent => 'Contenu sexuel ou pour adultes';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nudité, pornographie ou contenu explicite';

  @override
  String get reportReasonCopyright => 'Violation de droits d\'auteur';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Utilisation non autorisée de propriété intellectuelle';

  @override
  String get reportReasonFalseInfo => 'Fausses informations';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Affirmations trompeuses ou fausses';

  @override
  String get reportReasonChildSafety => 'Atteinte à la sécurité des enfants';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Préoccupations générales sur la sécurité des mineurs';

  @override
  String get reportReasonCsam => 'Abus sexuels sur mineurs';

  @override
  String get reportReasonCsamSubtitle =>
      'Contenu représentant des abus sexuels sur mineurs';

  @override
  String get reportReasonUnderageUser =>
      'L\'utilisateur semble avoir moins de 16 ans';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Le titulaire du compte semble être mineur';

  @override
  String get reportReasonAiGenerated => 'Contenu généré par IA';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Contenu suspecté d\'être généré par IA';

  @override
  String get reportReasonOther => 'Autre violation des règles';

  @override
  String get reportReasonOtherSubtitle => 'Infractions non listées ci-dessus';

  @override
  String get reportFailed => 'Échec du signalement du contenu. Réessaie.';

  @override
  String get reportNotSent =>
      'Impossible d\'envoyer ton signalement. Vérifie ta connexion et réessaie.';

  @override
  String get reportReceivedTitle => 'Signalement reçu';

  @override
  String get reportReceivedThankYou =>
      'Merci de nous aider à garder Divine sûr.';

  @override
  String get reportReceivedReviewNotice =>
      'Notre équipe va examiner ton signalement et prendre les mesures appropriées. Tu pourras recevoir des mises à jour par message direct.';

  @override
  String get reportModerationDmDelayed =>
      'On n\'a pas pu joindre l\'équipe de modération directement à l\'instant, mais ton signalement a bien été reçu et sera examiné.';

  @override
  String get reportContactModeration => 'Contacter l\'équipe de modération';

  @override
  String get reportLearnMoreAt => 'En savoir plus sur';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Fermer';

  @override
  String get listAddToList => 'Ajouter à une liste';

  @override
  String listVideoCount(int count) {
    return '$count vidéos';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '$count personne',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Par ';

  @override
  String get listNewList => 'Nouvelle liste';

  @override
  String get listDone => 'Terminé';

  @override
  String get listErrorLoading => 'Erreur de chargement des listes';

  @override
  String listRemovedFrom(String name) {
    return 'Retiré de $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Ajouté à $name';
  }

  @override
  String get listCreateNewList => 'Créer une nouvelle liste';

  @override
  String get listNewPeopleList => 'Nouvelle liste de personnes';

  @override
  String get listCollaboratorsNone => 'Aucun';

  @override
  String get listAddCollaboratorTitle => 'Ajouter un collaborateur';

  @override
  String get listCollaboratorSearchHint => 'Rechercher dans Divine...';

  @override
  String get listNameLabel => 'Nom de la liste';

  @override
  String get listDescriptionLabel => 'Description (facultatif)';

  @override
  String get listPublicList => 'Liste publique';

  @override
  String get listPublicListSubtitle =>
      'Les autres peuvent suivre et voir cette liste';

  @override
  String get listPrivateListSubtitle =>
      'Les vidéos restent privées. Le nom, la description, les tags et la couverture restent visibles.';

  @override
  String get listVisibilityPublic => 'Publique';

  @override
  String get listVisibilityPrivate => 'Privée';

  @override
  String get profileListsEmpty =>
      'Pas encore de liste. Crée-en une pour les loops que tu veux garder ensemble.';

  @override
  String get listEditTitle => 'Modifier la liste';

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
  String get listShareAction => 'Partager la liste';

  @override
  String get listShareFailed => 'Impossible de partager cette liste. Réessaie.';

  @override
  String get listSave => 'Enregistrer';

  @override
  String get listContinue => 'Continuer';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Impossible de mettre à jour cette liste. Réessaie.';

  @override
  String get listMakePrivateTitle => 'Rendre cette liste privée ?';

  @override
  String get listMakePrivateWarning =>
      'Les vidéos sont chiffrées, donc vous seul pouvez les voir. Le nom, la description, les tags et la couverture restent visibles, et les copies déjà partagées peuvent subsister.';

  @override
  String get listMakePublicTitle => 'Rendre cette liste publique ?';

  @override
  String get listMakePublicWarning =>
      'Toute personne disposant du lien peut voir cette liste et ses vidéos.';

  @override
  String listShareText(String name, String url) {
    return 'Découvre $name sur Divine : $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name sur Divine';
  }

  @override
  String get listCancel => 'Annuler';

  @override
  String get listCreate => 'Créer';

  @override
  String get listCreateFailed => 'Échec de la création de la liste';

  @override
  String get keyManagementTitle => 'Clés Nostr';

  @override
  String get keyManagementWhatAreKeys => 'C\'est quoi les clés Nostr ?';

  @override
  String get keyManagementExplanation =>
      'Ton identité Nostr est une paire de clés cryptographiques :\n\n• Ta clé publique (npub) est comme ton nom d\'utilisateur - partage-la librement\n• Ta clé privée (nsec) est comme ton mot de passe - garde-la secrète !\n\nTa nsec te permet d\'accéder à ton compte sur n\'importe quelle app Nostr.';

  @override
  String get keyManagementImportTitle => 'Importer une clé existante';

  @override
  String get keyManagementImportSubtitle =>
      'Tu as déjà un compte Nostr ? Colle ta clé privée (nsec) pour y accéder ici.';

  @override
  String get keyManagementImportButton => 'Importer la clé';

  @override
  String get keyManagementImportWarning => 'Ça va remplacer ta clé actuelle !';

  @override
  String get keyManagementBackupTitle => 'Sauvegarder ta clé';

  @override
  String get keyManagementBackupSubtitle =>
      'Enregistre ta clé privée (nsec) pour utiliser ton compte dans d\'autres apps Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copier ma clé privée (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Ne partage jamais ta nsec avec qui que ce soit !';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Ta clé est conservée par le service de connexion de Divine, pas sur cet appareil. Confirme ton mot de passe et on va la chercher.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Ta clé est conservée par le service de connexion de Divine. Saisis le mot de passe de ton compte et on va la chercher.';

  @override
  String get keyManagementKeycastCopyKey => 'Copier la clé';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Ton appareil a bloqué la copie, ta clé n\'est donc pas arrivée dans le presse-papiers.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Ce mot de passe ne correspond pas. Réessaie.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Trop d\'essais. Ferme ça et recommence.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Trop de demandes de clé. Attends quelques minutes et réessaie.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Ta session a expiré. Reconnecte-toi pour copier ta clé.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Vérifie ton adresse e-mail avant de copier ta clé.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine gère les clés de ce compte, elles ne peuvent donc pas être copiées ici.';

  @override
  String get keyManagementKeycastNoKey =>
      'Aucune clé n\'est enregistrée pour ce compte.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Le service de connexion est injoignable. Réessaie.';

  @override
  String get keyManagementRestrictedTitle => 'Tes clés sont gérées par Divine';

  @override
  String get keyManagementRestrictedBody =>
      'Pour la sécurité de ton compte, la sauvegarde de la clé et l\'import d\'une autre clé ne sont pas disponibles ici.';

  @override
  String get keyManagementPasteKey => 'Colle ta clé privée';

  @override
  String get keyManagementInvalidFormat =>
      'Format de clé invalide. Doit commencer par « nsec1 »';

  @override
  String get keyManagementConfirmImportTitle => 'Importer cette clé ?';

  @override
  String get keyManagementConfirmImportBody =>
      'Ça va remplacer ton identité actuelle par celle importée.\n\nTa clé actuelle sera perdue si tu ne l\'as pas sauvegardée avant.';

  @override
  String get keyManagementImportConfirm => 'Importer';

  @override
  String get keyManagementImportSuccess => 'Clé importée avec succès !';

  @override
  String get keyManagementImportFailed =>
      'Échec de l\'importation de la clé. Réessaie.';

  @override
  String get keyManagementExportSuccess =>
      'Clé privée copiée dans le presse-papiers !\n\nRange-la dans un endroit sûr.';

  @override
  String get keyManagementExportFailed =>
      'Échec de l\'exportation de la clé. Réessaie.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Ta clé publique (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copier la clé publique';

  @override
  String get keyManagementPublicKeyCopied => 'Clé publique copiée';

  @override
  String get saveOriginalSavedToCameraRoll => 'Enregistré dans la pellicule';

  @override
  String get saveOriginalShare => 'Partager';

  @override
  String get saveOriginalDone => 'Terminé';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Accès aux Photos requis';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Pour enregistrer les vidéos, autorise l\'accès aux Photos dans les Réglages.';

  @override
  String get saveOriginalOpenSettings => 'Ouvrir les Réglages';

  @override
  String get saveOriginalNotNow => 'Pas maintenant';

  @override
  String get saveOriginalDownloadFailed => 'Téléchargement échoué';

  @override
  String get saveOriginalDismiss => 'Ignorer';

  @override
  String get saveOriginalDownloadingVideo => 'Téléchargement de la vidéo';

  @override
  String get saveOriginalSavingToCameraRoll =>
      'Enregistrement dans la pellicule';

  @override
  String get saveOriginalFetchingVideo =>
      'Récupération de la vidéo depuis le réseau...';

  @override
  String get saveOriginalSavingVideo =>
      'Enregistrement de la vidéo originale dans ta pellicule...';

  @override
  String get soundTitle => 'Son';

  @override
  String get soundOriginalSound => 'Son original';

  @override
  String get soundVideosUsingThisSound => 'Vidéos utilisant ce son';

  @override
  String get soundSourceVideo => 'Vidéo source';

  @override
  String get soundNoVideosYet => 'Pas encore de vidéos';

  @override
  String get soundBeFirstToUse => 'Sois le premier à utiliser ce son !';

  @override
  String get soundFailedToLoadVideos => 'Échec du chargement des vidéos';

  @override
  String get soundRetry => 'Réessayer';

  @override
  String get soundVideosUnavailable => 'Vidéos indisponibles';

  @override
  String get soundCouldNotLoadDetails =>
      'Impossible de charger les détails de la vidéo';

  @override
  String get soundPreview => 'Aperçu';

  @override
  String get soundStop => 'Arrêter';

  @override
  String get soundUseSound => 'Utiliser ce son';

  @override
  String get soundUntitled => 'Son sans titre';

  @override
  String get soundStopPreview => 'Arrêter l\'aperçu';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Aperçu de $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Voir les détails de $title';
  }

  @override
  String get soundNoVideoCount => 'Pas encore de vidéos';

  @override
  String get soundOneVideo => '1 vidéo';

  @override
  String soundVideoCount(int count) {
    return '$count vidéos';
  }

  @override
  String get soundUnableToPreview =>
      'Impossible d\'écouter l\'aperçu - aucun audio disponible';

  @override
  String get soundPreviewFailed =>
      'Échec de la lecture de l\'aperçu. Réessaie.';

  @override
  String get soundViewSource => 'Voir la source';

  @override
  String get soundCloseTooltip => 'Fermer';

  @override
  String get exploreNotExploreRoute => 'Pas une route d\'exploration';

  @override
  String get legalTitle => 'Mentions légales';

  @override
  String get legalTermsOfService => 'Conditions d\'utilisation';

  @override
  String get legalTermsOfServiceSubtitle =>
      'Termes et conditions d\'utilisation';

  @override
  String get legalPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get legalPrivacyPolicySubtitle => 'Comment on traite tes données';

  @override
  String get legalSafetyStandards => 'Normes de sécurité';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Directives communautaires et sécurité';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Politique de droits d\'auteur et de retrait';

  @override
  String get legalOpenSourceLicenses => 'Licences open source';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Attributions des paquets tiers';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Impossible d\'ouvrir $pageName';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Aventure';

  @override
  String get categoryAnimals => 'Animaux';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Architecture';

  @override
  String get categoryArt => 'Art';

  @override
  String get categoryAutomotive => 'Automobile';

  @override
  String get categoryAwardShow => 'Cérémonie';

  @override
  String get categoryAwards => 'Récompenses';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basket';

  @override
  String get categoryBeauty => 'Beauté';

  @override
  String get categoryBeverage => 'Boissons';

  @override
  String get categoryCars => 'Voitures';

  @override
  String get categoryCelebration => 'Fête';

  @override
  String get categoryCelebrities => 'Célébrités';

  @override
  String get categoryCelebrity => 'Célébrité';

  @override
  String get categoryCityscape => 'Paysage urbain';

  @override
  String get categoryComedy => 'Comédie';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryCooking => 'Cuisine';

  @override
  String get categoryCostume => 'Costume';

  @override
  String get categoryCrafts => 'Loisirs créatifs';

  @override
  String get categoryCrime => 'Crime';

  @override
  String get categoryCulture => 'Culture';

  @override
  String get categoryDance => 'Danse';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drame';

  @override
  String get categoryEducation => 'Éducation';

  @override
  String get categoryEmotional => 'Émouvant';

  @override
  String get categoryEmotions => 'Émotions';

  @override
  String get categoryEntertainment => 'Divertissement';

  @override
  String get categoryEvent => 'Événement';

  @override
  String get categoryFamily => 'Famille';

  @override
  String get categoryFans => 'Fans';

  @override
  String get categoryFantasy => 'Fantastique';

  @override
  String get categoryFashion => 'Mode';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Cuisine';

  @override
  String get categoryFootball => 'Football américain';

  @override
  String get categoryFurniture => 'Mobilier';

  @override
  String get categoryGaming => 'Jeux vidéo';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Soins';

  @override
  String get categoryGuitar => 'Guitare';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Santé';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Vacances';

  @override
  String get categoryHome => 'Maison';

  @override
  String get categoryHomeImprovement => 'Bricolage';

  @override
  String get categoryHorror => 'Horreur';

  @override
  String get categoryHospital => 'Hôpital';

  @override
  String get categoryHumor => 'Humour';

  @override
  String get categoryInteriorDesign => 'Déco d\'intérieur';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Enfants';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magie';

  @override
  String get categoryMakeup => 'Maquillage';

  @override
  String get categoryMedical => 'Médical';

  @override
  String get categoryMusic => 'Musique';

  @override
  String get categoryMystery => 'Mystère';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryNews => 'Actus';

  @override
  String get categoryOutdoor => 'Plein air';

  @override
  String get categoryParty => 'Fête';

  @override
  String get categoryPeople => 'Gens';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Animaux';

  @override
  String get categoryPolitics => 'Politique';

  @override
  String get categoryPrank => 'Blague';

  @override
  String get categoryPranks => 'Blagues';

  @override
  String get categoryRealityShow => 'Téléréalité';

  @override
  String get categoryRelationship => 'Relation';

  @override
  String get categoryRelationships => 'Relations';

  @override
  String get categoryRomance => 'Romance';

  @override
  String get categorySchool => 'École';

  @override
  String get categoryScienceFiction => 'Science-fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skate';

  @override
  String get categorySkincare => 'Soins de la peau';

  @override
  String get categorySoccer => 'Foot';

  @override
  String get categorySocialGathering => 'Rassemblement';

  @override
  String get categorySocialMedia => 'Réseaux sociaux';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talk-show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryTelevision => 'Télévision';

  @override
  String get categoryToys => 'Jouets';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Voyage';

  @override
  String get categoryUrban => 'Urbain';

  @override
  String get categoryViolence => 'Violence';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Catch';

  @override
  String get profileSetupUploadStaged =>
      'Importée — touchez Enregistrer pour appliquer';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName signalé(e)';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName bloqué(e)';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName débloqué(e)';
  }

  @override
  String get inboxRemovedConversation => 'Conversation supprimée';

  @override
  String get inboxRestorePausedTitle =>
      'Certaines conversations ne sont pas encore restaurées';

  @override
  String get conversationRestorePausedTitle =>
      'Cette conversation n\'est pas encore restaurée';

  @override
  String get inboxRestoreRetryAction => 'Réessayer';

  @override
  String get inboxRestoringMessages => 'Restauration de vos messages…';

  @override
  String get inboxEmptyTitle => 'Aucun message pour le moment';

  @override
  String get inboxEmptySubtitle => 'Le bouton + ne mord pas.';

  @override
  String get inboxLoadErrorTitle => 'Les messages n\'ont pas chargé';

  @override
  String get inboxLoadErrorSubtitle => 'Vérifie ta connexion et réessaie.';

  @override
  String get inboxFilterAll => 'Tout';

  @override
  String get inboxFilterUnread => 'Non lus';

  @override
  String get dmBlockedThreadTitle => 'Vous avez bloqué ce compte';

  @override
  String get dmBlockedThreadBody =>
      'Les messages restent ici pour que vous puissiez les lire ou les capturer. Débloquez pour répondre.';

  @override
  String get inboxFilterBlocked => 'Bloqués';

  @override
  String get inboxBlockedEmptyTitle => 'Aucune conversation bloquée';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Les comptes que vous bloquez apparaissent ici.';

  @override
  String get inboxBlockedNoMessages => 'Aucun message';

  @override
  String get inboxUnreadEmptyTitle => 'Tu es à jour';

  @override
  String get inboxUnreadEmptySubtitle => 'Aucun message non lu pour le moment.';

  @override
  String get inboxSearchHint => 'Rechercher des messages';

  @override
  String get inboxSupportRowTitle => 'Modération Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Bugs, modération, questions de compte — on vous écoute.';

  @override
  String get inboxSearchEmptyTitle => 'Aucun résultat';

  @override
  String get inboxSearchEmptySubtitle => 'Essaie un autre nom ou un autre mot.';

  @override
  String get inboxActionMute => 'Mettre la conversation en sourdine';

  @override
  String inboxActionReport(String displayName) {
    return 'Signaler $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Bloquer $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Débloquer $displayName';
  }

  @override
  String get inboxActionRemove => 'Supprimer la conversation';

  @override
  String get inboxRemoveConfirmTitle => 'Supprimer la conversation ?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Cela retire de votre boîte de réception votre conversation avec $displayName. Si cette personne vous réécrit, une nouvelle conversation commence.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Cela retire la conversation de groupe de ta boîte de réception. Si quelqu\'un écrit à nouveau dans le groupe, une nouvelle conversation commence.';

  @override
  String get inboxRemoveConfirmConfirm => 'Supprimer';

  @override
  String get inboxConversationMuted => 'Conversation mise en sourdine';

  @override
  String get inboxConversationUnmuted => 'Conversation réactivée';

  @override
  String get inboxCollabInviteCardTitle => 'Invitation à collaborer';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Vidéo sans titre';

  @override
  String get clickableTextViewVideoLink => 'Voir la vidéo';

  @override
  String get messageExternalLinkDialogTitle => 'Ouvrir le lien externe ?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Ce lien mène vers un site externe et peut ne pas être sûr :\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Ouvrir';

  @override
  String get inboxCollabInviteCoPostButton => 'Co-publier';

  @override
  String get inboxCollabInviteNotMineButton => 'Pas à moi';

  @override
  String get inboxCollabInvitePreviewTitle => 'Invitation à co-publier';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Invitation à co-publier de $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Co-publier ajoute cette vidéo à votre timeline comme collaboration.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Acceptée';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorée';

  @override
  String get inboxCollabInviteAcceptError =>
      'Impossible d\'accepter. Réessayez.';

  @override
  String get inboxCollabInviteSentStatus => 'Invitation envoyée';

  @override
  String get inboxConversationCollabInvitePreview => 'Invitation à collaborer';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Tu as été invité(e) à collaborer sur $title : $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Tu as été invité(e) à collaborer sur une vidéo : $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations de collaborateur n\'ont pas été envoyées.',
      one: '$count invitation de collaborateur n\'a pas été envoyée.',
    );
    return 'Vidéo publiée, mais $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Impossible de savoir avec qui est cette conversation. Rouvre-la depuis ta boîte de réception.';

  @override
  String get dmSendBlockedMessage =>
      'Tu ne peux écrire qu\'aux comptes officiels Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Personne ne lit cette conversation. Écris plutôt à Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage =>
      'La suppression pour tout le monde a échoué.';

  @override
  String get dmDeleteRefusedDetails =>
      'Certaines personnes peuvent encore voir ce message.';

  @override
  String get dmRetiredThreadClosedTitle => 'Cette conversation est fermée.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Cet avis de Divine Moderation ne peut pas être supprimé.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Nous avons déplacé Divine Moderation vers un nouveau compte. Personne ne lit plus celui-ci.';

  @override
  String get dmRetiredThreadOpenSupport => 'Écrire à Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Impossible d\'envoyer le message';

  @override
  String get dmResendFailedMessage => 'Toujours impossible d\'envoyer';

  @override
  String get dmSendFailedSubtitle =>
      'Renvoie-le maintenant, ou arrête d\'essayer.';

  @override
  String get dmSendFailedRetry => 'Réessayer';

  @override
  String get dmSendPartialMessage =>
      'Envoyé, mais pas synchronisé avec tes autres appareils';

  @override
  String get dmConversationLoadError => 'Impossible de charger les messages';

  @override
  String get dmMessageInputHint => 'Dis quelque chose…';

  @override
  String get dmMessageBubbleSentHint => 'Message envoyé';

  @override
  String get dmMessageBubbleReceivedHint => 'Message reçu';

  @override
  String get dmMessageBubbleLongPressHint => 'Actions du message';

  @override
  String get dmMessageBubbleFailedTapHint => 'Renvoyer ou supprimer ce message';

  @override
  String get dmMessageActionCopyText => 'Copier le texte';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copier l\'URL de la vidéo';

  @override
  String get dmMessageActionDeleteForEveryone => 'Supprimer pour tout le monde';

  @override
  String get dmMessageActionReport => 'Signaler';

  @override
  String get dmMessageActionRetrySend => 'Renvoyer';

  @override
  String get dmMessageActionCancelSend => 'Arrêter d\'essayer';

  @override
  String get dmReactionAddCustomA11yLabel =>
      'Ajouter une réaction emoji personnalisée';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Envoyer un message à $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Te répondre à toi-même…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Répondre à ce reel';

  @override
  String get dmReelReplyViewChat => 'Voir la discussion';

  @override
  String get dmReelReplySentAnnouncement => 'Réponse envoyée';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Réaction $emoji envoyée';
  }

  @override
  String get dmReelReplyFailed => 'Échec de l\'envoi';

  @override
  String get dmReelReplyUnverified => 'Envoi non confirmé';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Ta réaction : $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name a réagi avec $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Envoi de la réaction : $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'La réaction a échoué, appuie deux fois pour réessayer';

  @override
  String get dmReactionChipRetryAnnouncement => 'Nouvel essai pour la réaction';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Terminez de supprimer votre réaction précédente avant d’en ajouter une autre.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Réactions';

  @override
  String get dmReactionsViewA11yLabel => 'Voir qui a réagi';

  @override
  String get dmReactionRemoveAction => 'Supprimer';

  @override
  String get dmReactionRetryAction => 'Réessayer';

  @override
  String get dmFormatBold => 'Gras';

  @override
  String get dmFormatItalic => 'Italique';

  @override
  String get dmFormatStrikethrough => 'Barré';

  @override
  String get dmFormatCode => 'Code';

  @override
  String get dmStatusFailed => 'Échec de l’envoi';

  @override
  String get inboxConversationActionsSheetLabel => 'Actions de la conversation';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Conversation avec $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Non lue, conversation avec $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres personnes',
      one: '$count autre personne',
    );
    return '$name et $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Afficher les actions de la conversation';

  @override
  String exploreVideoId(String id) {
    return 'ID : $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Titre : $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Vidéo $current/$total';
  }

  @override
  String get exploreSearchHint => 'Rechercher...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count vidéos';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Impossible de mettre à jour l\'abonnement. Réessaie.';

  @override
  String get discoverListsTitle => 'Découvrir des listes';

  @override
  String get discoverListsFailedToLoad => 'Échec du chargement des listes';

  @override
  String get discoverListsLoading => 'Recherche de listes publiques...';

  @override
  String get discoverListsRelayTimeout =>
      'Le relais n\'a pas renvoyé de listes à temps. Réessaie.';

  @override
  String get discoverListsServiceUnavailable => 'Service indisponible.';

  @override
  String get discoverListsEmptyTitle => 'Aucune liste publique trouvée';

  @override
  String get discoverListsEmptySubtitle =>
      'Reviens plus tard pour de nouvelles listes';

  @override
  String get discoverListsByAuthorPrefix => 'par';

  @override
  String get curatedListEmptyTitle => 'Aucune vidéo dans cette liste';

  @override
  String get curatedListEmptySubtitle => 'Ajoute des vidéos pour démarrer';

  @override
  String get curatedListLoadingVideos => 'Chargement des vidéos...';

  @override
  String get curatedListFailedToLoad => 'Échec du chargement de la liste';

  @override
  String get curatedListVideoNotAvailable => 'Vidéo indisponible';

  @override
  String get curatedListActionsTooltip => 'Actions de la liste';

  @override
  String get curatedListDeleteConfirmTitle => 'Supprimer la liste ?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Ça retire la liste des relays. Les vidéos de la liste ne seront pas supprimées.';

  @override
  String get curatedListDeletedSnack => 'Liste supprimée';

  @override
  String get curatedListDeleteFailed => 'Impossible de supprimer la liste';

  @override
  String get peopleListsActionsTooltip => 'Actions de la liste';

  @override
  String get listDeleteAction => 'Supprimer la liste';

  @override
  String get peopleListsDeleteConfirmTitle => 'Supprimer la liste ?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Ça supprime la liste pour tout le monde. Les personnes qu\'elle contient ne seront pas retirées de tes abonnements.';

  @override
  String get peopleListsDeleteFailed => 'Impossible de supprimer la liste';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonSomethingWentWrong => 'Un problème est survenu';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonNotNow => 'Pas maintenant';

  @override
  String get commonLoading => 'Chargement';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Impossible de mettre à jour la couverture. Réessayez.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement =>
      'Couverture mise à jour';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Publier sans la vérification d’authenticité ?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Nous n’avons pas pu ajouter les informations d’authenticité, cette vidéo ne sera donc pas confirmée comme faite par un humain. Régénérez pour réessayer, ou publiez-la telle quelle.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Les informations d’authenticité nécessitent une connexion internet.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Le service de justificatifs de contenu n\'a pas répondu. Ça ne vient pas de ta connexion.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Régénérer';

  @override
  String get videoMetadataC2paMissingSkip => 'Ignorer';

  @override
  String get videoMetadataGenerationFailed => 'Échec de la génération';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Expiration';

  @override
  String get videoMetadataExpirationNotExpire => 'N\'expire pas';

  @override
  String get videoMetadataExpirationOneDay => '1 jour';

  @override
  String get videoMetadataExpirationOneWeek => '1 semaine';

  @override
  String get videoMetadataExpirationOneMonth => '1 mois';

  @override
  String get videoMetadataExpirationOneYear => '1 an';

  @override
  String get videoMetadataExpirationOneDecade => '1 décennie';

  @override
  String get videoMetadataContentWarnings => 'Avertissements de contenu';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Tendances';

  @override
  String get libraryDeleteConfirm => 'Supprimer';

  @override
  String get libraryWebUnavailableHeadline =>
      'La bibliothèque est dans l’appli mobile';

  @override
  String get libraryWebUnavailableDescription =>
      'Les brouillons et clips sont enregistrés sur ton appareil : ouvre Divine sur ton téléphone pour les gérer.';

  @override
  String get libraryTabDrafts => 'Brouillons';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'Supprimer les clips sélectionnés';

  @override
  String get libraryCloseSemanticLabel => 'Fermer la bibliothèque';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'Arrêter de sélectionner des clips';

  @override
  String get librarySelectClipsSemanticLabel => 'Sélectionner des clips';

  @override
  String get libraryGridSizeLabel => 'Taille de la grille';

  @override
  String get libraryDisplayOptionsLabel => 'Tri et taille de grille';

  @override
  String get libraryMoreActionsSemanticLabel =>
      'Plus d\'actions de la bibliothèque';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colonnes',
      one: '$count colonne',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Sélectionner';

  @override
  String get librarySortNewestCreation => 'Création la plus récente';

  @override
  String get librarySortOldestCreation => 'Création la plus ancienne';

  @override
  String get librarySortLongestClip => 'Clip le plus long';

  @override
  String get librarySortShortestClip => 'Clip le plus court';

  @override
  String get librarySortSquareFirst => 'Carrés d\'abord';

  @override
  String get librarySortVerticalFirst => 'Verticaux d\'abord';

  @override
  String get libraryDeleteClipsWarning =>
      'Action irréversible. Les fichiers vidéo seront définitivement supprimés de ton appareil.';

  @override
  String get libraryPreparingVideo => 'Préparation de la vidéo...';

  @override
  String libraryCreateVideo(int count) {
    return 'Créer une vidéo ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '$count clip',
    );
    return '$_temp0 enregistré(s) dans $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount enregistrés, $failureCount échecs';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Impossible d\'enregistrer dans $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permission refusée pour $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips supprimés',
      one: '$count clip supprimé',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Annuler';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Suppression automatique dans $daysLeft jours',
      one: 'Suppression automatique demain',
      zero: 'Suppression automatique aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Impossible de charger les brouillons';

  @override
  String get libraryCouldNotLoadClips => 'Impossible de charger les clips';

  @override
  String get libraryOpenErrorDescription =>
      'Un problème est survenu en ouvrant ta bibliothèque. Réessaie.';

  @override
  String get libraryNoDraftsYetTitle => 'Pas encore de brouillons';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Les vidéos enregistrées en brouillon apparaîtront ici';

  @override
  String get libraryNoClipsYetTitle => 'Pas encore de clips';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Tes clips enregistrés apparaîtront ici';

  @override
  String get libraryDraftDeletedSnackbar => 'Brouillon supprimé';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Échec de la suppression du brouillon';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Brouillon dupliqué';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Échec de la duplication du brouillon';

  @override
  String get libraryDraftInProgressBadge => 'En cours';

  @override
  String get libraryDraftActionPost => 'Publier';

  @override
  String get libraryDraftActionEdit => 'Modifier';

  @override
  String get libraryDraftActionDuplicate => 'Dupliquer';

  @override
  String get libraryDraftActionDelete => 'Supprimer le brouillon';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (copie $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Supprimer le brouillon';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get libraryDeleteClipTitle => 'Supprimer le clip';

  @override
  String get libraryDeleteClipMessage => 'Supprimer ce clip ?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds s';
  }

  @override
  String get libraryRecordVideo => 'Enregistrer une vidéo';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Clip vidéo, $duration secondes';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Archivé. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Clip en stop-motion, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Sélectionné, numéro $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Sélectionné';

  @override
  String get videoClipSemanticValueNotSelected => 'Non sélectionné';

  @override
  String get videoClipSemanticHintDisabled => 'Désactivé';

  @override
  String get videoClipSemanticHintSelect =>
      'Appuyer pour sélectionner, appui long pour aperçu';

  @override
  String get videoClipSemanticHintDeselect =>
      'Appuyer pour désélectionner, appui long pour aperçu';

  @override
  String get routerInvalidCreator => 'Créateur non valide';

  @override
  String get routerInvalidHashtagRoute => 'Route de hashtag non valide';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Impossible de charger les vidéos';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Aucune vidéo dans cette catégorie';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Options de tri de la catégorie';

  @override
  String get categoryGallerySortHot => 'Tendance';

  @override
  String get categoryGallerySortNew => 'Nouveautés';

  @override
  String get categoryGallerySortClassic => 'Classiques';

  @override
  String get categoryGallerySortForYou => 'Pour toi';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Impossible de charger les catégories';

  @override
  String get categoriesNoCategoriesAvailable => 'Aucune catégorie disponible';

  @override
  String get notificationsEmptyTitle => 'Aucune activité pour l\'instant';

  @override
  String get notificationsEmptySubtitle =>
      'Quand les gens interagissent avec ton contenu, tu le verras ici';

  @override
  String get appsPermissionsTitle => 'Permissions d\'intégration';

  @override
  String get appsPermissionsRevoke => 'Révoquer';

  @override
  String get appsPermissionsEmptyTitle =>
      'Aucune permission d\'intégration enregistrée';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Les intégrations approuvées apparaîtront ici après que tu auras mémorisé une approbation d\'accès.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName demande ton approbation';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Cette app demande l\'accès via le sandbox vérifié de Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Origine';

  @override
  String get nostrAppPermissionMethod => 'Méthode';

  @override
  String get nostrAppPermissionCapability => 'Capacité';

  @override
  String get nostrAppPermissionEventKind => 'Type d\'événement';

  @override
  String get nostrAppPermissionAllow => 'Autoriser';

  @override
  String get appsDetailDefaultTitle => 'App intégrée';

  @override
  String get appsDetailNotFoundTitle => 'Intégration introuvable';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Cette intégration approuvée n\'est plus disponible dans Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Comment ça marche';

  @override
  String get appsDetailHowItWorksBody =>
      'C\'est une app tierce approuvée qui fonctionne à l\'intérieur de Divine. Divine n\'accorde que des capacités vérifiées pour cette intégration, et bloque la navigation en dehors de ses origines approuvées.';

  @override
  String get appsDetailAboutTitle => 'À propos';

  @override
  String get appsDetailPrimaryOriginTitle => 'Origine principale';

  @override
  String get appsDetailApprovedOriginsTitle => 'Origines approuvées';

  @override
  String get appsDetailCapabilitiesTitle => 'Capacités disponibles';

  @override
  String get appsDetailAskBeforeTitle => 'Demander avant';

  @override
  String get appsDetailOpenButton => 'Ouvrir l\'intégration';

  @override
  String get appsDetailNoneDeclared => 'Aucune déclarée pour le moment';

  @override
  String get appsDirectoryTitle => 'Apps intégrées';

  @override
  String get appsDirectoryIntroTitle => 'Apps tierces approuvées';

  @override
  String get appsDirectoryIntroBody =>
      'Des apps tierces approuvées qui fonctionnent à l\'intérieur de Divine';

  @override
  String get appsDirectoryErrorTitle =>
      'Impossible de charger les apps intégrées';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Tire pour réessayer de charger les intégrations approuvées.';

  @override
  String get appsDirectoryEmptyTitle =>
      'Aucune intégration approuvée pour le moment';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Les apps tierces approuvées apparaîtront ici à mesure que Divine les ajoute.';

  @override
  String get appsDirectoryRefresh => 'Actualiser';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Les apps intégrées fonctionnent dans Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Les intégrations approuvées ne sont disponibles que sur mobile pour l\'instant.';

  @override
  String get appsSandboxUnavailableTitle => 'Intégration indisponible';

  @override
  String get appsSandboxUnavailableBody =>
      'Ouvre les intégrations approuvées depuis l\'onglet Apps intégrées pour que Divine puisse appliquer la bonne politique d\'accès.';

  @override
  String get appsSandboxLoadingTitle => 'Chargement de l\'intégration';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Vérification de l\'intégration approuvée avant le lancement.';

  @override
  String get appsSandboxBlockedTitle => 'Bloqué par sécurité';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Cette intégration a essayé de quitter son origine approuvée.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink =>
      'Lien vers le post copié dans le presse-papiers';

  @override
  String get shareCopiedEventJson =>
      'JSON de l\'événement Nostr copié dans le presse-papiers';

  @override
  String get shareCopiedEventId =>
      'ID de l\'événement Nostr copié dans le presse-papiers';

  @override
  String get authHeroTaglineAuthentic => 'Des moments authentiques.';

  @override
  String get authHeroTaglineHuman => 'La créativité humaine.';

  @override
  String get keyImportFailedToImport =>
      'Échec de l\'import de la clé ou de la connexion au bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'URL bunker invalide';

  @override
  String get keyImportInvalidFormat =>
      'Format invalide. Utilise nsec..., hex, ncryptsec1... ou bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Format nsec invalide. Doit comporter 63 caractères';

  @override
  String get keyImportKeyFieldLabel => 'Clé privée ou URL bunker';

  @override
  String get keyImportKeyRequired => 'Saisis ta clé privée ou ton URL bunker';

  @override
  String get keyImportPasswordRequired =>
      'Saisis le mot de passe de cette clé chiffrée';

  @override
  String get keyImportSecurityWarningBody =>
      'Ne partage jamais ta clé privée avec qui que ce soit. Cette clé donne un accès total à ton identité Nostr.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Garde ta clé privée en sécurité !';

  @override
  String get keyImportSubtitle =>
      'Importe ton identité Nostr existante avec ta clé privée ou une URL bunker.';

  @override
  String get keyImportTitle => 'Importe ton\nidentité Nostr';

  @override
  String get commentAuthorYouIndicator => 'Toi';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Voir le profil de $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Supprimer le commentaire';

  @override
  String get commentOptionsEditSemanticLabel => 'Modifier le commentaire';

  @override
  String get commentOptionsFlagContentLabel => 'Signaler le contenu';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Signaler ce contenu';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Choisis une raison pour signaler ce commentaire';

  @override
  String get commentOptionsFlagSubmit => 'Envoyer';

  @override
  String get commentOptionsTitle => 'Options';

  @override
  String get commentsEmptyClassicVineMessage =>
      'On travaille encore à l\'import des anciens commentaires depuis l\'archive. Ils ne sont pas encore prêts.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Modification';

  @override
  String get commentsInputSemanticHint => 'Ajouter un commentaire';

  @override
  String get commentsInputSemanticHintEdit => 'Modifier le commentaire';

  @override
  String get commentsInputSemanticHintReply => 'Ajouter une réponse';

  @override
  String get commentsInputSemanticLabel => 'Champ de commentaire';

  @override
  String get commentsInputSemanticLabelEdit => 'Champ de modification';

  @override
  String get commentsInputSemanticLabelReply => 'Champ de réponse';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Voir le profil de $displayName';
  }

  @override
  String get classicsEmptyDescription =>
      'L\'archive des Classiques est en cours de chargement';

  @override
  String get classicsEmptyTitle => 'Aucun Classique trouvé';

  @override
  String get classicsErrorTitle => 'Échec du chargement des Classiques';

  @override
  String get classicsUnavailableDescription =>
      'Les Classiques ne sont disponibles que lorsque tu es connecté aux relays Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Passe à un relay compatible Funnelcake dans les Réglages pour accéder à l\'archive des Classiques.';

  @override
  String get classicsUnavailableTitle => 'Classiques indisponibles';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Sois le premier à publier une vidéo avec ce hashtag !';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Aucune vidéo trouvée pour #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Ça peut prendre quelques instants';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Chargement des vidéos sur #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Ajoute des hashtags... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Reviens plus tard pour du nouveau contenu';

  @override
  String get newVideosTabEmptyTitle => 'Aucune vidéo dans Nouvelles vidéos';

  @override
  String get popularVideosContextTitle => 'Vidéos populaires';

  @override
  String get popularVideosEmptySubtitle =>
      'Reviens plus tard pour du nouveau contenu';

  @override
  String get popularVideosEmptyTitle => 'Aucune vidéo dans Vidéos populaires';

  @override
  String get popularVideosErrorTitle =>
      'Échec du chargement des vidéos tendance';

  @override
  String get popularVideosFeedSourceLabel => 'Source du fil populaire';

  @override
  String get trendingHashtagsLoading => 'Chargement des hashtags...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Voir les vidéos taguées $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Auteur de la vidéo : $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Description de la vidéo : $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'La vision de Divine, c\'est de te donner un vrai choix algorithmique. Au lieu d\'être enfermé dans un seul algorithme opaque, tu pourras choisir parmi plusieurs approches de recommandation :';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Fil chronologique des créateurs que tu suis';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Ça te met aux commandes de ton attention plutôt que de la laisser à la plateforme. Tu devrais savoir comment ton fil est composé et avoir le pouvoir de le changer quand tu veux.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Des fils personnalisés créés par la communauté pour des thèmes comme la musique, l\'humour ou l\'art';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Fil « Pour toi » personnalisé';

  @override
  String get forYouAlgorithmChoiceTitle => 'Ton algorithme, ton choix';

  @override
  String get forYouAlgorithmChoiceTrending => 'Contenu tendance et populaire';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Signal fort — tu étais assez impliqué pour répondre';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine prête attention à la façon dont tu interagis avec le contenu pour comprendre ce que tu aimes. Chaque fois que tu regardes une vidéo, y réagis, laisses un commentaire ou la repostes, le système en prend note.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Comment ça marche';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Différentes actions signalent différents niveaux d\'intérêt :';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Si tu n\'as pas encore construit d\'historique de visionnage, on te montre un mélange de ce qui est actuellement populaire et tendance, avec les uploads récents. Ça te donne un super point de départ pour explorer.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'À mesure que tu regardes, aimes et interagis avec le contenu, les recommandations deviennent peu à peu plus personnalisées. Avec le temps, ton fil Pour toi fait remonter des vidéos de créateurs que tu n\'aurais peut-être jamais découverts par toi-même.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Nouveau sur Divine ?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'On construit un système ouvert où les développeurs peuvent implémenter leurs propres algorithmes, et où tu peux choisir lesquels utiliser — ou tout refuser.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open source et transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Signal moyen — une façon rapide de montrer ton appréciation';

  @override
  String get forYouAlgorithmReactionsTitle => 'Réactions';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Signal le plus fort — partager avec tes abonnés est une recommandation puissante';

  @override
  String get forYouAlgorithmSubtitle =>
      'Propulsé par Gorse, un moteur de recommandation open source';

  @override
  String get forYouAlgorithmTitle => 'L\'algorithme de Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Signal léger — indique un intérêt de base';

  @override
  String get forYouEmptyDescription =>
      'Regarde et aime quelques vidéos pour obtenir des recommandations personnalisées.';

  @override
  String get forYouEmptyTitle => 'Pas encore de recommandations';

  @override
  String get forYouErrorTitle => 'Échec du chargement des recommandations';

  @override
  String get forYouUnavailableDescription =>
      'Les recommandations personnalisées nécessitent une connexion à Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Pour toi indisponible';

  @override
  String get inboxConversationOptionsLabel => 'Options';

  @override
  String get inboxConversationViewProfileButton => 'Voir le profil';

  @override
  String get inboxMessageRequestsEmpty => 'Aucune demande de message';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Demandes de message, $requestCount en attente';
  }

  @override
  String get inboxMessageRequestsTitle => 'Demandes de message';

  @override
  String get inboxMessagesTab => 'Messages';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Demande de message de $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'A envoyé une demande de message';

  @override
  String get inboxRequestsMarkAllRead =>
      'Marquer toutes les demandes comme lues';

  @override
  String get inboxRequestsRemoveAll => 'Supprimer toutes les demandes';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Refuser et supprimer';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Demande de $displayName refusée';
  }

  @override
  String get messageRequestLoadFailed => 'Impossible de charger cette demande.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count abonnés';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count vidéos';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '$count message',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Voir les messages';

  @override
  String get messageRequestViewProfileButton => 'Voir le profil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName veut t\'envoyer un message, il a envoyé $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Tu as changé de compte, donc rien n\'a été supprimé. Rouvre la suppression pour le compte que tu veux retirer.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Pour confirmer, tape :';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Pour confirmer, tape ton nom d\'utilisateur :';

  @override
  String get deleteAccountConfirmationHint => 'Tape DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'Tape ton nom d\'utilisateur';

  @override
  String get deleteAccountDeleteAllContentButton => 'Supprimer tout le contenu';

  @override
  String get accountDeletionRecoveryTitle => 'Suppression de ton compte';

  @override
  String get accountDeletionRecoveryBody =>
      'On n\'a pas pu terminer la suppression de ton compte. Ton nom d\'utilisateur t\'est réservé et peut encore être récupéré.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername =>
      'Récupérer mon nom d\'utilisateur';

  @override
  String get accountDeletionFinishingBody =>
      'Ta demande de suppression est toujours en cours de traitement. Tu peux utiliser un autre compte pendant que nous terminons.';

  @override
  String get accountDeletionOtherAccountPending =>
      'La suppression d’un autre compte est toujours en cours sur cet appareil. Attends qu’elle soit terminée avant de supprimer ce compte.';

  @override
  String get accountDeletionCancellingBody =>
      'On annule ta suppression. Vérifie à nouveau avant de quitter cet écran.';

  @override
  String get accountDeletionRecoveryFailed =>
      'On n\'a pas encore pu récupérer ton nom d\'utilisateur. Vérifie ta connexion et réessaie.';

  @override
  String get accountDeletionUsernameRestored =>
      'Ton nom d\'utilisateur est récupéré. Ton compte n\'a pas été supprimé.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'On n\'a pas pu vérifier l\'état de ta suppression. Vérifie ta connexion et réessaie.';

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
      'La suppression de compte n’est pas disponible pour le moment. Rien n’a été supprimé.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'On n\'a pas pu terminer la suppression de ton compte. Réessaie.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Confirmation finale';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Demandes de suppression envoyées, mais tes clés n\'ont peut-être pas été entièrement retirées de cet appareil. Va dans Réglages → Clés Nostr → Retirer les clés pour réessayer.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Demandes de suppression envoyées et tu es déconnecté, mais certaines données locales n\'ont pas pu être retirées de cet appareil.';

  @override
  String get deleteAccountPreparingDeletion =>
      'Préparation de la suppression...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total événements';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Ça retire la connexion locale de ce compte de cet appareil. Ça ne supprimera pas ton compte Divine ni ton identité Nostr.\n\nTes brouillons et clips restent enregistrés sur cet appareil pour ce compte. Si c\'est ton dernier compte local, tu reviendras à l\'écran de connexion.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Retirer de l\'appareil';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Retirer ce compte de cet appareil ?';

  @override
  String get deleteAccountReauthRequired =>
      'Reconnecte-toi pour supprimer ton compte. Rien n\'a encore été supprimé.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Les demandes de suppression de tes publications ont été envoyées, mais on n\'a pas pu terminer la suppression de ton compte. Réessaie dans un moment.';

  @override
  String get deleteAccountSuccess =>
      'Ton compte Divine a été supprimé. Des demandes de suppression ont été envoyées pour tes publications Nostr, mais certains relais, clients ou caches peuvent en conserver des copies.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Suppression du compte demandée. La suppression de certaines publications existantes n\'a pas pu être confirmée individuellement.';

  @override
  String get deleteAccountWarningBody =>
      'Ça envoie des demandes de suppression pour ton compte et ton contenu, supprime ton compte Divine quand c\'est possible et te déconnecte sur cet appareil. Certains relays, clients et index de recherche peuvent garder des copies. Les autres appareils connectés restent actifs jusqu\'à ce que tu y retires les clés.';

  @override
  String get findPeopleNoContacts =>
      'Aucun contact trouvé.\nCommence à suivre des gens pour les voir ici.';

  @override
  String get geoBlockedCityLabel => 'Ville';

  @override
  String get geoBlockedCountryLabel => 'Pays';

  @override
  String get geoBlockedDefaultReason =>
      'Ce service n\'est pas disponible dans ta région en raison de la réglementation locale.';

  @override
  String get geoBlockedLegalNotice =>
      'On respecte tes lois et réglementations locales. Cette restriction est basée sur la localisation de ton adresse IP.';

  @override
  String get geoBlockedRegionLabel => 'Région';

  @override
  String get geoBlockedTitle => 'Service indisponible';

  @override
  String get likedVideosEmpty => 'Aucune vidéo aimée';

  @override
  String get likedVideosInvalidRoute => 'Route invalide';

  @override
  String get likedVideosTitle => 'Vidéos aimées';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Nouvel essai d\'envoi…';

  @override
  String get uploadFailureSheetSaveToDraftsButton =>
      'Enregistrer dans les brouillons';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar =>
      'Enregistré dans les brouillons';

  @override
  String get uploadFailureSheetTitle => 'Échec de l\'envoi';

  @override
  String get uploadFailureSheetTryAgainButton => 'Réessayer';

  @override
  String get videoEditorAudioImportAudio => 'Importer un audio';

  @override
  String get videoEditorAudioImportFailed => 'Échec de l\'import audio.';

  @override
  String get videoIconPlaceholderLabel => 'Vidéo';

  @override
  String get publishErrorNotSignedIn => 'Connecte-toi pour publier des vidéos.';

  @override
  String get publishErrorNoRetry => 'Aucun envoi à relancer.';

  @override
  String get publishErrorNoInternet =>
      'Pas de connexion internet. Vérifie ton Wi-Fi ou tes données mobiles et réessaie.';

  @override
  String get publishErrorServerUnreachable =>
      'Impossible de joindre le serveur. Réessaie dans un instant.';

  @override
  String get publishErrorTimeout =>
      'L\'envoi a expiré. Essaie avec une meilleure connexion ou une vidéo plus légère.';

  @override
  String get publishErrorTls =>
      'La connexion sécurisée a échoué. Vérifie ton réseau — le Wi-Fi public peut bloquer les envois.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Le serveur multimédia ($serverName) n\'est pas disponible. Tu peux en choisir un autre dans tes réglages.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Le fichier vidéo est trop volumineux pour le serveur. Essaie de le raccourcir ou de baisser la qualité.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Le serveur multimédia ($serverName) a rencontré une erreur interne. Tu peux en choisir un autre dans tes réglages.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Le serveur multimédia ($serverName) est temporairement hors service. Réessaie bientôt ou choisis-en un autre dans tes réglages.';
  }

  @override
  String get publishErrorForbidden =>
      'Tu n\'as pas l\'autorisation d\'envoyer sur ce serveur.';

  @override
  String get publishErrorFileNotFound =>
      'Impossible de trouver le fichier vidéo. Il a peut-être été supprimé. Refilme et réessaie.';

  @override
  String get publishErrorLowStorage =>
      'Pas assez de stockage sur ton appareil. Libère de l\'espace et réessaie.';

  @override
  String get publishErrorThumbnailFailed =>
      'La vidéo a été envoyée, mais la miniature n\'a pas pu être préparée. Réessaie.';

  @override
  String get publishErrorNostrPublishFailed =>
      'La vidéo a été envoyée, mais la publication n\'a pas pu être diffusée. Vérifie tes réglages de relais et réessaie.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'La vidéo a été envoyée, mais cet audio n\'est pas autorisé à la réutilisation. Choisis un autre son pour publier.';

  @override
  String get publishErrorInterrupted =>
      'Cet envoi a été interrompu. Tu veux réessayer ?';

  @override
  String get publishErrorAccountChanged =>
      'Cette vidéo appartient à un autre compte. Reviens sur ce compte pour la publier.';

  @override
  String get publishErrorGeneric => 'Un problème est survenu. Réessaie.';

  @override
  String get publishErrorRateLimited =>
      'Trop d\'envois en ce moment. Réessaie dans un instant.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Ta session d\'envoi a expiré. Réessaie.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine n\'a pas l\'autorisation d\'envoyer. Vérifie les autorisations de l\'application dans tes réglages et réessaie.';

  @override
  String get publishErrorOutOfMemory =>
      'Ton appareil manque de mémoire. Ferme quelques applications et réessaie.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Le texte et les stickers de ce brouillon n’ont pas pu être préparés. Ouvre-le dans l’éditeur, puis publie à nouveau.';

  @override
  String get publishErrorUnknownServer => 'Serveur inconnu';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filtre : $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Voir les vidéos taguées $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Son : $soundName par $creatorName. Touche pour voir les détails du son.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Son original par $creatorName. Touche pour utiliser ce son.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Son : $soundName par $creatorName. Touche pour voir les détails.';
  }

  @override
  String get soundDetailLoadError => 'Échec du chargement du son. Réessaie.';

  @override
  String get soundDetailNotFoundMessage => 'Ce son est introuvable';

  @override
  String get soundDetailNotFoundTitle => 'Son introuvable';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loops';
  }

  @override
  String get originalSoundUnavailableBody =>
      'L\'audio de cette vidéo n\'est pas disponible séparément.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Son original - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Cette personne a publié un Vine original que Divine a retrouvé dans les archives. Ce n\'est pas un badge de vérification de compte.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Coche de profil';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine attribue cette coche aux comptes de l\'équipe. C\'est indépendant de NIP-05, des liens de compte vérifiés et du statut OG Viner.';

  @override
  String get unfollowConfirmButton => 'Ne plus suivre';

  @override
  String get videoClipSaveFailed => 'Échec de l\'enregistrement du clip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Enregistrer dans $destination';
  }

  @override
  String get videoClipDelete => 'Supprimer le clip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspiré par $creatorName +$additionalCreatorCount. Touche pour voir son profil.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspiré par $creatorName. Touche pour voir son profil.';
  }

  @override
  String get bugReportSendReport => 'Envoyer le rapport';

  @override
  String get supportSubjectRequiredLabel => 'Sujet *';

  @override
  String get supportPublicSubmissionTitle => 'Publication GitHub publique';

  @override
  String get supportPublicSubmissionMessage =>
      'Tout ce que tu envoies ici sera publié dans notre dépôt open source sur GitHub afin que les développeurs puissent s\'en charger. La publication et le compte avec lequel tu es connecté seront visibles par tout le monde.';

  @override
  String get supportRequiredHelper => 'Requis';

  @override
  String get supportFieldLimitReached =>
      'C\'est la longueur maximale. Tout ce qui dépasse n\'a pas été ajouté.';

  @override
  String get bugReportSubjectHint => 'Bref résumé du problème';

  @override
  String get bugReportDescriptionRequiredLabel => 'Que s\'est-il passé ? *';

  @override
  String get bugReportDescriptionHint =>
      'Décris le problème que tu as rencontré';

  @override
  String get bugReportStepsLabel => 'Étapes pour reproduire';

  @override
  String get bugReportStepsHint =>
      '1. Aller à...\n2. Appuyer sur...\n3. Voir l\'erreur';

  @override
  String get bugReportExpectedBehaviorLabel => 'Comportement attendu';

  @override
  String get bugReportExpectedBehaviorHint =>
      'Que devait-il se passer à la place ?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Les infos de l\'appareil et les logs seront inclus automatiquement.';

  @override
  String get bugReportSuccessMessage =>
      'Merci ! On a bien reçu ton rapport et on s\'en servira pour améliorer Divine.';

  @override
  String get bugReportAttachImages => 'Joindre des images';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count images sur $max sélectionnées';
  }

  @override
  String get bugReportRemoveImage => 'Retirer l\'image';

  @override
  String get bugReportUploadFailed =>
      'On n\'a pas pu envoyer l\'image choisie. Réessaie ou envoie le signalement sans elle.';

  @override
  String get bugReportSendFailed =>
      'Échec de l\'envoi du rapport de bug. Réessaie plus tard.';

  @override
  String get featureRequestSendRequest => 'Envoyer la demande';

  @override
  String get featureRequestSubjectHint => 'Bref résumé de ton idée';

  @override
  String get featureRequestDescriptionRequiredLabel =>
      'Qu\'est-ce que tu aimerais ? *';

  @override
  String get featureRequestDescriptionHint =>
      'Décris la fonctionnalité que tu veux';

  @override
  String get featureRequestUsefulnessLabel => 'En quoi ce serait utile ?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explique le bénéfice que cette fonctionnalité apporterait';

  @override
  String get featureRequestWhenLabel => 'Quand l\'utiliserais-tu ?';

  @override
  String get featureRequestWhenHint => 'Décris les situations où ça aiderait';

  @override
  String get featureRequestSuccessMessage =>
      'Merci ! On a bien reçu ta demande de fonctionnalité et on va l\'examiner.';

  @override
  String get featureRequestSendFailed =>
      'Échec de l\'envoi de la demande de fonctionnalité. Réessaie plus tard.';

  @override
  String get notificationFollowBack => 'Suivre en retour';

  @override
  String get followingTitle => 'Abonnements';

  @override
  String followingTitleForName(String displayName) {
    return 'Abonnements de $displayName';
  }

  @override
  String get followingFailedToLoadList =>
      'Impossible de charger la liste des abonnements';

  @override
  String get followingEmptyTitle => 'Aucun abonnement pour l\'instant';

  @override
  String get followersTitle => 'Abonnés';

  @override
  String followersTitleForName(String displayName) {
    return 'Abonnés de $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Impossible de charger la liste des abonnés';

  @override
  String get followersEmptyTitle => 'Aucun abonné pour l\'instant';

  @override
  String get followersUpdateFollowFailed =>
      'Échec de la mise à jour du suivi. Réessaie.';

  @override
  String get followersSortSemanticLabel => 'Trier les abonnés';

  @override
  String get followingSortSemanticLabel => 'Trier les abonnements';

  @override
  String get followSortTitle => 'Trier par';

  @override
  String get followSortNewest => 'Plus récents d\'abord';

  @override
  String get followSortOldest => 'Plus anciens d\'abord';

  @override
  String get newMessageTitle => 'Nouveau message';

  @override
  String get newMessageFindPeople => 'Trouver des gens';

  @override
  String get newMessageNoContacts =>
      'Aucun contact trouvé.\nSuis des gens pour les voir ici.';

  @override
  String get newMessageNoUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get hashtagSearchTitle => 'Rechercher des hashtags';

  @override
  String get hashtagSearchSubtitle =>
      'Découvre les sujets et contenus tendance';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Aucun hashtag trouvé pour « $query »';
  }

  @override
  String get hashtagSearchFailed => 'Échec de la recherche';

  @override
  String get userNotAvailableTitle => 'Compte indisponible';

  @override
  String get userNotAvailableBody =>
      'Ce compte n\'est pas disponible pour le moment.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Impossible de sauvegarder les paramètres. Réessaie.';

  @override
  String get blossomValidServerUrl =>
      'Entre une URL de serveur valide (ex. : https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Réglages Blossom enregistrés';

  @override
  String get blossomSaveTooltip => 'Enregistrer';

  @override
  String get blossomAboutTitle => 'À propos de Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom est un protocole décentralisé de stockage média qui te permet d\'uploader des vidéos sur n\'importe quel serveur compatible. Par défaut, les vidéos sont uploadées sur le serveur Blossom de Divine. Active l\'option ci-dessous pour utiliser un serveur personnalisé à la place.';

  @override
  String get blossomUseCustomServer =>
      'Utiliser un serveur Blossom personnalisé';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Les vidéos seront uploadées sur ton serveur Blossom personnalisé';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Tes vidéos sont actuellement uploadées sur le serveur Blossom de Divine';

  @override
  String get blossomCustomServerUrl => 'URL du serveur Blossom personnalisé';

  @override
  String get blossomCustomServerHelper =>
      'Entre l\'URL de ton serveur Blossom personnalisé';

  @override
  String get blossomPopularServers => 'Serveurs Blossom populaires';

  @override
  String get blossomServerUrlMustUseHttps =>
      'L\'URL du serveur Blossom doit utiliser https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Impossible de mettre à jour le paramètre de crosspost';

  @override
  String get blueskySignInRequired =>
      'Connecte-toi pour gérer les réglages Bluesky';

  @override
  String get blueskyPublishVideos => 'Publier les vidéos sur Bluesky';

  @override
  String get blueskyEnabledSubtitle => 'Tes vidéos seront publiées sur Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Tes vidéos ne seront pas publiées sur Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Tes anciennes vidéos seront aussi publiées';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Quand tu actives ça, Divine commence à envoyer tes anciennes vidéos vers Bluesky, des plus anciennes aux plus récentes, sans brusquer la limite quotidienne.';

  @override
  String get blueskyHandle => 'Identifiant Bluesky';

  @override
  String get blueskyDid => 'DID Bluesky';

  @override
  String get blueskyStatus => 'Statut';

  @override
  String get blueskyStatusReady => 'Compte provisionné et prêt';

  @override
  String get blueskyStatusPending => 'Provisionnement du compte en cours...';

  @override
  String get blueskyStatusFailed => 'Échec du provisionnement du compte';

  @override
  String get blueskyStatusDisabled => 'Compte désactivé';

  @override
  String get blueskyStatusNotLinked => 'Aucun compte Bluesky lié';

  @override
  String get blueskyUsernameRequired =>
      'Configure un identifiant divine.video avant de publier sur Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Publier sur Bluesky demande un identifiant nomdutilisateur.divine.video déjà réservé.';

  @override
  String get blueskyUsernameSyncPending =>
      'Ton identifiant Divine est réservé. On le relie à Bluesky – réessaie dans un instant.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'On n\'a pas pu vérifier ton identifiant Divine. Réessaie.';

  @override
  String get blueskySetUpHandle => 'Configurer';

  @override
  String get blueskyTemporarilyUnavailable =>
      'La publication sur Bluesky est temporairement indisponible. Réessaie.';

  @override
  String get invitesTitle => 'Inviter des amis';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations prêtes à générer',
      one: '$count invitation prête à générer',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Génère un code quand tu es prêt à le partager.';

  @override
  String get invitesGenerateButtonLabel => 'Générer une invitation';

  @override
  String get invitesNoneAvailable =>
      'Aucune invitation disponible pour l\'instant';

  @override
  String get invitesShareWithPeople =>
      'Partage Divine avec les gens que tu connais';

  @override
  String get invitesUsedInvites => 'Invitations utilisées';

  @override
  String invitesShareMessage(String code) {
    return 'Rejoins-moi sur Divine ! Utilise le code d\'invitation $code pour démarrer :\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copier l\'invitation';

  @override
  String get invitesCopied => 'Invitation copiée !';

  @override
  String get invitesShareInvite => 'Partager l\'invitation';

  @override
  String get invitesShareSubject => 'Rejoins-moi sur Divine';

  @override
  String get invitesClaimed => 'Utilisée';

  @override
  String get invitesCouldNotLoad => 'Impossible de charger les invitations';

  @override
  String get invitesRetry => 'Réessayer';

  @override
  String get searchSomethingWentWrong => 'Quelque chose s\'est mal passé';

  @override
  String get searchTryAgain => 'Réessayer';

  @override
  String get searchForLists => 'Rechercher des listes';

  @override
  String get searchFindCuratedVideoLists =>
      'Trouve des listes de vidéos sélectionnées';

  @override
  String get searchEnterQuery => 'Saisis une recherche';

  @override
  String get searchDiscoverSomethingInteresting =>
      'Découvre quelque chose d\'intéressant';

  @override
  String get searchPeopleSectionHeader => 'Personnes';

  @override
  String get searchPeopleLoadingLabel =>
      'Chargement des résultats de personnes';

  @override
  String get searchTagsSectionHeader => 'Tags';

  @override
  String get searchTagsLoadingLabel => 'Chargement des résultats de tags';

  @override
  String get searchVideosSectionHeader => 'Vidéos';

  @override
  String get searchVideosLoadingLabel => 'Chargement des résultats de vidéos';

  @override
  String get searchVideosSortOptionsLabel => 'Trier les résultats vidéo';

  @override
  String get searchVideosSortTrending => 'Tendance';

  @override
  String get searchVideosSortLoops => 'Plus de loops';

  @override
  String get searchVideosSortEngagement => 'Plus d\'engagement';

  @override
  String get searchVideosSortRecent => 'Récent';

  @override
  String get searchListsSectionHeader => 'Listes';

  @override
  String get searchListsLoadingLabel => 'Chargement des résultats de listes';

  @override
  String get cameraAgeRestriction =>
      'Tu dois avoir 16 ans ou plus pour créer du contenu';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Le relay bunker doit utiliser wss:// (ws:// est autorisé seulement pour localhost)';

  @override
  String get timeNow => 'maintenant';

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
    return '${count}j';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}sem';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}mo';
  }

  @override
  String timeShortYears(int count) {
    return '${count}a';
  }

  @override
  String get timeVerboseNow => 'Maintenant';

  @override
  String timeAgo(String time) {
    return 'il y a $time';
  }

  @override
  String get timeToday => 'Aujourd\'hui';

  @override
  String get timeYesterday => 'Hier';

  @override
  String get timeJustNow => 'à l\'instant';

  @override
  String timeMinutesAgo(int count) {
    return 'il y a ${count}min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'il y a ${count}h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'il y a ${count}j';
  }

  @override
  String get draftTimeJustNow => 'À l\'instant';

  @override
  String get contentLabelNudity => 'Nudité';

  @override
  String get contentLabelSexualContent => 'Contenu sexuel';

  @override
  String get contentLabelPornography => 'Pornographie';

  @override
  String get contentLabelGraphicMedia => 'Contenu choquant';

  @override
  String get contentLabelViolence => 'Violence';

  @override
  String get contentLabelSelfHarm => 'Automutilation/Suicide';

  @override
  String get contentLabelDrugUse => 'Consommation de drogues';

  @override
  String get contentLabelAlcohol => 'Alcool';

  @override
  String get contentLabelTobacco => 'Tabac/Tabagisme';

  @override
  String get contentLabelGambling => 'Jeux d\'argent';

  @override
  String get contentLabelProfanity => 'Langage vulgaire';

  @override
  String get contentLabelHateSpeech => 'Discours haineux';

  @override
  String get contentLabelHarassment => 'Harcèlement';

  @override
  String get contentLabelFlashingLights => 'Lumières clignotantes';

  @override
  String get contentLabelAiGenerated => 'Généré par IA';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Arnaque/Fraude';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Trompeur';

  @override
  String get contentLabelSensitiveContent => 'Contenu sensible';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName a aimé ta vidéo';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName a aimé ton commentaire';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName a commenté ta vidéo';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName a commencé à te suivre';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName t\'a mentionné';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName a repartagé ta vidéo';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName a publié une nouvelle vine';
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
      other: '$count de tes vines',
      one: 'ta vine',
    );
    return '$actorName a ajouté $_temp0 à $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName a répondu à ton commentaire';
  }

  @override
  String get notificationAndConnector => 'et';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres',
      one: '$count autre',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Tu as une nouvelle mise à jour';

  @override
  String get commentReplyToPrefix => 'Re :';

  @override
  String get commentHideKeyboard => 'Masquer le clavier';

  @override
  String get commentsErrorLoadFailed =>
      'Impossible de charger les commentaires';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Connecte-toi pour commenter';

  @override
  String get commentsErrorPostCommentFailed =>
      'Impossible de publier le commentaire';

  @override
  String get commentsErrorPostReplyFailed => 'Impossible de publier la réponse';

  @override
  String get commentsErrorEditFailed => 'Impossible de modifier le commentaire';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Connecte-toi pour participer';

  @override
  String get commentsErrorVoteFailed =>
      'Impossible de voter pour le commentaire';

  @override
  String get commentsErrorReportFailed =>
      'Impossible de signaler le commentaire';

  @override
  String get commentsErrorBlockFailed => 'Impossible de bloquer l\'utilisateur';

  @override
  String get commentsErrorDeleteFailed =>
      'Impossible de supprimer le commentaire';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commentaires',
      one: '$count commentaire',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Publication…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Votre réponse vidéo est en cours de publication';

  @override
  String get commentsSortNew => 'Récents';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get commentsSortOld => 'Anciens';

  @override
  String get commentsSortSemanticLabel => 'Tri des commentaires';

  @override
  String get commentReply => 'Répondre';

  @override
  String get commentReplySemanticLabel => 'Répondre au commentaire';

  @override
  String get commentUpvoteLabel => 'Voter pour le commentaire';

  @override
  String get commentRemoveUpvoteLabel => 'Retirer le vote positif';

  @override
  String get commentDownvoteLabel => 'Voter contre le commentaire';

  @override
  String get commentRemoveDownvoteLabel => 'Retirer le vote négatif';

  @override
  String get commentsInputHint => 'Ajouter un commentaire...';

  @override
  String get commentsInputHintEdit => 'Modifier le commentaire...';

  @override
  String get commentsEmptyTitle => 'Pas encore de commentaires';

  @override
  String get commentsEmptySubtitle => 'Lance la discussion !';

  @override
  String get draftUntitled => 'Sans titre';

  @override
  String get contentWarningNone => 'Aucun';

  @override
  String get textBackgroundNone => 'Aucun';

  @override
  String get textBackgroundSolid => 'Opaque';

  @override
  String get textBackgroundHighlight => 'Surbrillance';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Gauche';

  @override
  String get textAlignRight => 'Droite';

  @override
  String get textAlignCenter => 'Centré';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'La caméra n\'est pas encore prise en charge sur le web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'La capture et l\'enregistrement vidéo avec la caméra ne sont pas encore disponibles dans la version web.';

  @override
  String get cameraPermissionBackToFeed => 'Retour au fil';

  @override
  String get cameraCouldNotStart => 'Impossible de démarrer la caméra';

  @override
  String get cameraUnsupportedPlatform =>
      'La caméra n\'est pas encore disponible sur cette plateforme.\nTu peux quand même parcourir et regarder des vidéos.';

  @override
  String get cameraPermissionErrorTitle => 'Erreur d\'autorisation';

  @override
  String get cameraPermissionErrorDescription =>
      'Une erreur s\'est produite lors de la vérification des autorisations.';

  @override
  String get cameraPermissionRetry => 'Réessayer';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Autoriser l\'accès à la caméra et au micro';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Cela vous permet de capturer et de modifier des vidéos directement dans l\'application, rien de plus.';

  @override
  String get cameraPermissionGoToSettings => 'Aller aux paramètres';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Pourquoi six secondes ?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Les clips courts laissent place à la spontanéité. Le format de 6 secondes vous aide à capturer des moments authentiques au moment où ils se produisent.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Compris !';

  @override
  String get videoRecorderUploadTitle => 'Pourquoi pas d\'envoi ?';

  @override
  String get videoRecorderUploadBody =>
      'Ce que tu vois sur Divine est fait par des humains : brut et capturé sur le moment. Contrairement aux plateformes qui autorisent les envois très produits ou générés par IA, nous donnons la priorité à l\'authenticité de l\'expérience caméra-directe.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'En gardant la création à l\'intérieur de l\'app, nous pouvons mieux garantir que le contenu est réel et non édité. Nous n\'ouvrons pas les envois depuis la galerie externe pour le moment, afin de protéger cette authenticité et garder notre communauté libre de contenu synthétique autant que possible.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Passe à Capture ou Classic pour filmer quelque chose de réel.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Découvre comment fonctionne la vérification';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Nous avons trouvé un travail en cours';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Voulez-vous reprendre là où vous vous êtes arrêté ?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Oui, continuer';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Non, démarrer une nouvelle vidéo';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Impossible de restaurer votre brouillon';

  @override
  String get videoRecorderStopRecordingTooltip => 'Arrêter l\'enregistrement';

  @override
  String get videoRecorderStartRecordingTooltip => 'Démarrer l\'enregistrement';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Enregistrement en cours. Appuyez n\'importe où pour arrêter';

  @override
  String get videoRecorderTapToStartLabel =>
      'Appuyez n\'importe où pour démarrer l\'enregistrement';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Supprimer le dernier clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Changer de caméra';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoomer à $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Afficher/masquer la grille';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Afficher/masquer le cadre fantôme';

  @override
  String get videoRecorderGhostFrameEnabled => 'Cadre fantôme activé';

  @override
  String get videoRecorderGhostFrameDisabled => 'Cadre fantôme désactivé';

  @override
  String get videoRecorderClipDeletedMessage =>
      'Clip déplacé vers la corbeille';

  @override
  String get videoRecorderClipUndoLabel => 'Annuler';

  @override
  String get libraryTrashEmptyTitle => 'La corbeille est vide';

  @override
  String get libraryTrashEmptySubtitle =>
      'Les clips supprimés restent ici pendant 30 jours avant d\'être supprimés définitivement.';

  @override
  String get libraryTrashRestoreLabel => 'Restaurer';

  @override
  String get libraryTrashDeleteNowLabel => 'Supprimer maintenant';

  @override
  String get libraryTrashEmptyAllLabel => 'Vider la corbeille';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Supprimer le clip maintenant ?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Cela retire le clip de la corbeille tout de suite.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Vider la corbeille ?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '$count clip',
    );
    return 'Cela supprime définitivement de la corbeille $_temp0 tout de suite.';
  }

  @override
  String get videoRecorderCloseLabel => 'Fermer l\'enregistreur vidéo';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Continuer vers l\'éditeur vidéo';

  @override
  String get videoRecorderCameraPreviewLabel => 'Aperçu de la caméra';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Faire la mise au point';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Passer au mode $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Ajoutez de l\'audio avant d\'enregistrer';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Impossible de créer la vidéo. Réessayez.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prises restantes',
      one: '$count prise restante',
      zero: 'Aucune prise restante',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Activer/désactiver le flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Changer le minuteur';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Changer le format d\'image';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilisation';

  @override
  String get videoRecorderStabilizationModeOff => 'Désactivée';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinématique';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinématique étendue';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Optimisée pour l\'aperçu';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Faible latence';

  @override
  String get videoRecorderStabilizationModeAuto => 'Auto';

  @override
  String get videoRecorderFlashValueOff => 'Désactivé';

  @override
  String get videoRecorderFlashValueOn => 'Activé';

  @override
  String get videoRecorderFlashValueAuto => 'Auto';

  @override
  String get videoRecorderTimerValueOff => 'Désactivé';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 secondes';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 secondes';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Carré';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Vertical';

  @override
  String get videoRecorderCameraValueFront => 'Caméra avant';

  @override
  String get videoRecorderCameraValueBack => 'Caméra arrière';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Bibliothèque de clips, aucun clip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Ouvrir la bibliothèque de clips, $clipCount clips',
      one: 'Ouvrir la bibliothèque de clips, $clipCount clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Ouvrir la bibliothèque stop-motion, $frameCount images',
      one: 'Ouvrir la bibliothèque stop-motion, $frameCount image',
      zero: 'Ouvrir la bibliothèque stop-motion',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Caméra';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Ouvrir la caméra';

  @override
  String get videoEditorLibraryLabel => 'Bibliothèque';

  @override
  String get videoEditorTextLabel => 'Texte';

  @override
  String get videoEditorDrawLabel => 'Dessiner';

  @override
  String get videoEditorFilterLabel => 'Filtre';

  @override
  String get videoEditorTuneLabel => 'Ajuster';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Ouvrir l’éditeur de réglages';

  @override
  String get videoEditorTuneBrightness => 'Luminosité';

  @override
  String get videoEditorTuneContrast => 'Contraste';

  @override
  String get videoEditorTuneSaturation => 'Saturation';

  @override
  String get videoEditorTuneExposure => 'Exposition';

  @override
  String get videoEditorTuneHue => 'Teinte';

  @override
  String get videoEditorTuneTemperature => 'Température';

  @override
  String get videoEditorTuneTint => 'Nuance';

  @override
  String get videoEditorTuneFade => 'Fondu';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Ajouter';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Ouvrir la bibliothèque';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Ouvrir l\'éditeur audio';

  @override
  String get videoEditorCaptionsLabel => 'Sous-titres';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Ouvrir l\'éditeur de sous-titres';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Incruster dans la vidéo';

  @override
  String get videoEditorCaptionsPresetCustom => 'Perso';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Style personnalisé';

  @override
  String get videoEditorCaptionsCustomApply => 'Appliquer';

  @override
  String get videoEditorCaptionsCustomFont => 'Police';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Couleur du texte';

  @override
  String get videoEditorCaptionsCustomBackground => 'Arrière-plan';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Couleur de fond';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animation';

  @override
  String get videoEditorCaptionsAnimationNone => 'Aucune';

  @override
  String get videoEditorCaptionsAnimationFade => 'Fondu';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Ressort';

  @override
  String get videoEditorCaptionsEditTitle => 'Sous-titres';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Écoute en cours…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Nous transformons votre audio en suggestions de sous-titres.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Nous n\'avons entendu aucune voix. Vous pouvez quand même écrire les sous-titres vous-même.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'La reconnaissance vocale n\'est pas disponible sur cet appareil. Vous pouvez écrire les sous-titres vous-même.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'La reconnaissance vocale n\'est pas autorisée. Activez-la dans les Réglages ou écrivez les sous-titres vous-même.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'La transcription n\'a pas fonctionné cette fois. Vous pouvez écrire les sous-titres vous-même.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Écrire les sous-titres moi-même';

  @override
  String get videoEditorCaptionsAddCue => 'Ajouter un sous-titre';

  @override
  String get videoEditorCaptionsCueTextHint => 'Texte du sous-titre';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel =>
      'Supprimer le sous-titre';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Supprimer tous les sous-titres';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Supprimer les sous-titres ?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Tout le texte et les réglages de temps seront perdus.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Fermer l\'éditeur de sous-titres';

  @override
  String get videoEditorCaptionsDoneSemanticLabel =>
      'Confirmer les sous-titres';

  @override
  String get videoEditorCaptionsPresetTitle => 'Style des sous-titres';

  @override
  String get videoEditorCaptionsPresetClassic => 'Classique';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Gros titre';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Machine à écrire';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marqueur';

  @override
  String get videoEditorCaptionsPresetScript => 'Calligraphie';

  @override
  String get videoEditorCaptionsPresetRetro => 'Rétro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Élégant';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bulle';

  @override
  String get videoEditorCaptionsPresetNeon => 'Néon';

  @override
  String get videoEditorCaptionsPresetBold => 'Gras';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Rêveur';

  @override
  String get videoEditorCaptionsPresetOcean => 'Océan';

  @override
  String get videoEditorCaptionsPresetSunny => 'Ensoleillé';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Manuscrit';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Tampon';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Ouvrir l\'éditeur de texte';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Ouvrir l\'éditeur de dessin';

  @override
  String get videoEditorOpenFilterSemanticLabel =>
      'Ouvrir l\'éditeur de filtres';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Ouvrir l\'éditeur de stickers';

  @override
  String get videoEditorSaveDraftTitle => 'Enregistrer votre brouillon ?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Conservez vos modifications pour plus tard, ou abandonnez-les et quittez l\'éditeur.';

  @override
  String get videoEditorSaveDraftButton => 'Enregistrer le brouillon';

  @override
  String get videoEditorDiscardChangesButton => 'Ignorer les modifications';

  @override
  String get videoEditorKeepEditingButton => 'Continuer la modification';

  @override
  String get videoEditorDeleteLayerDropZone => 'Zone de suppression de calque';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Relâchez pour supprimer le calque';

  @override
  String get videoEditorDoneLabel => 'Terminé';

  @override
  String get videoEditorPlayPauseSemanticLabel =>
      'Lire ou mettre en pause la vidéo';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Position de découpe invalide. Les deux clips doivent durer au moins $minDurationMs ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Enregistrer le clip sélectionné';

  @override
  String get videoEditorSaveClip => 'Enregistrer le clip';

  @override
  String get videoEditorClipSavedSuccess =>
      'Clip enregistré dans la bibliothèque';

  @override
  String get videoEditorClipSaveFailed => 'Échec de l\'enregistrement du clip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Sélecteur de couleur';

  @override
  String get videoEditorUndoSemanticLabel => 'Annuler';

  @override
  String get videoEditorRedoSemanticLabel => 'Rétablir';

  @override
  String get videoEditorTextColorSemanticLabel => 'Couleur du texte';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Alignement du texte';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Arrière-plan du texte';

  @override
  String get videoEditorFontSemanticLabel => 'Police';

  @override
  String get videoEditorNoStickersFound => 'Aucun sticker trouvé';

  @override
  String get videoEditorNoStickersAvailable => 'Aucun sticker disponible';

  @override
  String get videoEditorFailedLoadStickers =>
      'Échec du chargement des stickers';

  @override
  String get videoEditorVoiceOverLabel => 'Voix off';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Enregistrement $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel =>
      'Enregistrer une voix off';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel =>
      'Démarrer l’enregistrement';

  @override
  String get videoEditorVoiceOverStopSemanticLabel =>
      'Arrêter l’enregistrement';

  @override
  String get videoEditorVoiceOverHint =>
      'Appuie pour enregistrer. Ajoute autant de prises que tu veux.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements',
      one: '$count enregistrement',
      zero: 'Aucun enregistrement',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast =>
      'Supprimer le dernier enregistrement';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Accès au micro requis';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Autorise l’accès au micro pour enregistrer une voix off.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Ouvrir les réglages';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Enregistrement démarré';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Enregistrement sauvegardé';

  @override
  String get videoEditorVoiceOverTooLong =>
      'L\'enregistrement est plus long que votre vidéo';

  @override
  String get videoEditorPlaySemanticLabel => 'Lire';

  @override
  String get videoEditorPauseSemanticLabel => 'Pause';

  @override
  String get videoEditorVolumeSemanticLabel => 'Régler le volume';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Faites glisser pour ajuster';

  @override
  String get videoEditorChromaKeyLabel => 'Fond vert';

  @override
  String get videoEditorChromaKeyTitle => 'Fond vert';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Configurer le fond vert de ce clip';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Annuler les modifications du fond vert';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Appliquer le fond vert';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Détection auto';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Vert';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Bleu';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Couleur du fond';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Intensité';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Quelle part de la couleur de fond disparaît';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Contour';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Adoucit la découpe pour que les cheveux ne soient pas crénelés';

  @override
  String get videoEditorChromaKeySpillLabel => 'Débordement';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Retire la teinte du fond sur ton sujet';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Remplacer par';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Rien';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Couleur';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Image';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'La vidéo ne gère pas la transparence : à l\'export, ce sera du noir.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Aucun fond détecté. Il doit toucher les bords de l\'image — sinon, choisis la couleur à la main.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Choisir un clip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Ta bibliothèque est vide. Enregistre d\'abord un clip, puis utilise-le comme fond.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Impossible de charger cette image.';

  @override
  String get videoEditorChromaKeyRemove => 'Retirer le fond vert';

  @override
  String get videoEditorChromaKeyFailed =>
      'Impossible d\'appliquer le fond vert. Ton clip est inchangé.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Impossible de retirer le fond vert. Ton clip est inchangé.';

  @override
  String get videoEditorChromaKeyApplying => 'Application du fond vert…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Cet appareil ne peut pas afficher l\'aperçu en direct. Tes réglages s\'appliquent quand même à l\'export.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Supprimer';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Supprimer l\'élément sélectionné';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Images par photo';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '$count image',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Images';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count images par photo';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Image stop-motion $position sur $total';
  }

  @override
  String get videoEditorEditLabel => 'Modifier';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Modifier l\'élément sélectionné';

  @override
  String get videoEditorDuplicateLabel => 'Dupliquer';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Dupliquer l\'élément sélectionné';

  @override
  String get videoEditorCombineLabel => 'Combiner';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Combiner les dessins sélectionnés en un seul calque';

  @override
  String get videoEditorSplitLabel => 'Scinder';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Scinder le clip sélectionné';

  @override
  String get videoEditorExtractAudioLabel => 'Extraire l\'audio';

  @override
  String get videoEditorClipAudioTitle => 'Audio du clip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Extraire l\'audio du clip et couper le son de l\'original';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Impossible d\'extraire l\'audio : le clip n\'est pas disponible localement.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Impossible d\'extraire l\'audio. Veuillez réessayer.';

  @override
  String get videoEditorSpeedLabel => 'Vitesse';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Définir la vitesse de lecture du clip sélectionné';

  @override
  String get videoEditorReverseLabel => 'Inverser';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Activer ou désactiver la lecture inversée du clip sélectionné';

  @override
  String get videoEditorReverseProgressLabel =>
      'Un instant, nous inversons votre clip';

  @override
  String get videoEditorTransformLabel => 'Transformer';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Rogner, pivoter ou retourner le clip sélectionné';

  @override
  String get videoEditorTransformProgressLabel =>
      'Un instant, nous transformons votre clip';

  @override
  String get videoEditorTransformFailed =>
      'Impossible de transformer le clip. Veuillez réessayer.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Transformation impossible : le clip n\'est pas disponible localement.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Rogner, faire pivoter ou retourner l\'image sélectionnée';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Un instant, on transforme ton image';

  @override
  String get videoEditorTransformFrameFailed =>
      'Impossible de transformer l\'image. Réessaie.';

  @override
  String get videoEditorTransformRotateLabel => 'Pivoter';

  @override
  String get videoEditorTransformFlipLabel => 'Retourner';

  @override
  String get videoEditorTransformResetLabel => 'Réinitialiser';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'Appliquer la transformation';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Annuler la transformation';

  @override
  String get videoEditorTransformPlayLabel => 'Lire';

  @override
  String get videoEditorTransformPauseLabel => 'Pause';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Impossible d\'inverser : le clip n\'est pas disponible localement.';

  @override
  String get videoEditorReverseFailed =>
      'Impossible d\'inverser le clip. Veuillez réessayer.';

  @override
  String get videoEditorSpeedSheetTitle => 'Vitesse du clip';

  @override
  String get videoEditorTransitionSheetTitle => 'Transition';

  @override
  String get videoEditorTransitionNone => 'Aucune';

  @override
  String get videoEditorTransitionDissolve => 'Fondu enchaîné';

  @override
  String get videoEditorTransitionFadeToBlack => 'Fondu au noir';

  @override
  String get videoEditorTransitionFadeToWhite => 'Fondu au blanc';

  @override
  String get videoEditorTransitionSlide => 'Glissement';

  @override
  String get videoEditorTransitionPush => 'Poussée';

  @override
  String get videoEditorTransitionWipe => 'Balayage';

  @override
  String get videoEditorTransitionButtonSemanticLabel =>
      'Modifier la transition';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Transition en boucle';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Modifier la transition en boucle';

  @override
  String get videoEditorTransitionDuration => 'Durée';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Raccourcie pour ne pas chevaucher la transition voisine.';

  @override
  String get videoEditorTransitionCurve => 'Courbe';

  @override
  String get videoEditorTransitionDirection => 'Direction';

  @override
  String get videoEditorTransitionDirectionLeft => 'Gauche';

  @override
  String get videoEditorTransitionDirectionRight => 'Droite';

  @override
  String get videoEditorTransitionDirectionUp => 'Haut';

  @override
  String get videoEditorTransitionDirectionDown => 'Bas';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Courbe d\'animation $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animation';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Modifier l\'animation du calque';

  @override
  String get videoEditorLayerAnimationEnter => 'Entrée';

  @override
  String get videoEditorLayerAnimationLeave => 'Sortie';

  @override
  String get videoEditorLayerAnimationFade => 'Fondu';

  @override
  String get videoEditorLayerAnimationScale => 'Échelle';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Échelle depuis';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Terminer l\'édition de la timeline';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Lire l\'aperçu';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'Mettre l\'aperçu en pause';

  @override
  String get videoEditorAudioUntitledSound => 'Son sans titre';

  @override
  String get videoEditorAudioUntitled => 'Sans titre';

  @override
  String get videoEditorAudioAddAudio => 'Ajouter de l\'audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Aucun son disponible';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Les sons apparaîtront ici lorsque des créateurs partageront de l\'audio';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Échec du chargement des sons';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Sélectionne le segment audio de ta vidéo';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Communauté';

  @override
  String get videoEditorAudioCategoryFeatured => 'À la une';

  @override
  String get videoEditorAudioCategoryMySounds => 'Mes sons';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Outil flèche';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Outil gomme';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Outil marqueur';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Outil crayon';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Afficher la timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Masquer la timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Évitez de placer du contenu derrière ces zones.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originaux';

  @override
  String get videoEditorStickerSearchHint => 'Rechercher des stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Sélectionner une police';

  @override
  String get videoEditorFontUnknown => 'Inconnue';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'La tête de lecture doit se trouver dans le clip sélectionné pour pouvoir le scinder.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Rogner le début';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Rogner la fin';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Rogner le clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Faites glisser les poignées pour ajuster la durée du clip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Déplacement du clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index sur $total, $duration secondes';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'Appui long pour déplacer';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Déplacer vers la gauche';

  @override
  String get videoEditorTimelineClipMoveRight => 'Déplacer vers la droite';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index sur $total, sélectionné';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index sur $total, non sélectionné';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Sélectionner';

  @override
  String get videoEditorMultiSelectSemanticLabel =>
      'Sélectionner plusieurs clips';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Terminer la sélection';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips sélectionnés',
      one: '$count clip sélectionné',
      zero: 'Aucun clip sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Sélectionner plusieurs dessins';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Terminer la sélection des dessins';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Supprimer les dessins sélectionnés';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dessins sélectionnés',
      one: '$count dessin sélectionné',
      zero: 'Aucun dessin sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Fusionner';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Fusionner les clips sélectionnés';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Supprimer les clips sélectionnés';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Supprimer les images sélectionnées';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Inverser les images sélectionnées';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Dupliquer les images sélectionnées';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Ta vidéo doit durer au moins ${seconds}s — capture encore quelques images.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Un instant, nous fusionnons vos clips';

  @override
  String get videoEditorMergeFailed =>
      'Impossible de fusionner les clips. Veuillez réessayer.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Appui long pour glisser';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Timeline vidéo';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, sélectionnée';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Fermer le sélecteur de couleur';

  @override
  String get videoEditorPickColorTitle => 'Choisir une couleur';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirmer la couleur';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturation et luminosité';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturation $saturation %, luminosité $brightness %';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Teinte';

  @override
  String get videoEditorAddElementSemanticLabel => 'Ajouter un élément';

  @override
  String get videoEditorDoneSemanticLabel => 'Terminé';

  @override
  String get videoEditorLevelSemanticLabel => 'Niveau';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Fermer les détails de la publication';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Fermer la fenêtre d\'aide';

  @override
  String get videoMetadataGotItButton => 'Compris !';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limite de 64 Ko atteinte. Supprimez du contenu pour continuer.';

  @override
  String get videoMetadataExpirationLabel => 'Expiration';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Sélectionner la durée d\'expiration';

  @override
  String get videoMetadataTitleLabel => 'Titre';

  @override
  String get videoMetadataDescriptionLabel => 'Description';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Supprimer le tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Avertissement de contenu';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Sélectionner des avertissements de contenu';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Sélectionnez tout ce qui s\'applique à votre contenu';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Permets aux autres de sauvegarder et réutiliser l\'audio de cette vidéo.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Ta vidéo est en ligne, mais le son n\'a pas été publié. Modifie la vidéo pour le partager.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Collaborateurs';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Ajouter un collaborateur';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Abonnés mutuels';

  @override
  String get videoMetadataInspiredByLabel => 'Inspiré par';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Définir inspiré par';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Ce créateur ne peut pas être référencé.';

  @override
  String get videoMetadataPostDetailsTitle => 'Détails de la publication';

  @override
  String get videoMetadataSavedToLibrarySnackbar =>
      'Enregistré dans la bibliothèque';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Échec de l\'enregistrement';

  @override
  String get videoMetadataGoToLibraryButton => 'Aller à la bibliothèque';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Bouton enregistrer pour plus tard';

  @override
  String get videoMetadataSavingVideoHint => 'Enregistrement de la vidéo...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Enregistrer la vidéo dans les brouillons et $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Enregistrer la vidéo dans les brouillons. Pas encore de vidéo rendue, donc aucune copie n\'est ajoutée à $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Enregistrer pour plus tard';

  @override
  String get videoMetadataPostSemanticLabel => 'Bouton publier';

  @override
  String get videoMetadataPublishVideoHint => 'Publier la vidéo dans le fil';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Partager aussi dans mon fil';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Désactivé, cette vidéo reste seulement dans le fil de commentaires.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Remplissez le formulaire pour activer';

  @override
  String get videoMetadataPostButton => 'Publier';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Ouvrir l\'écran d\'aperçu de la publication';

  @override
  String get videoMetadataShareTitle => 'Partager';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Détails de la vidéo';

  @override
  String get videoMetadataClassicDoneButton => 'Terminé';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Lire l\'aperçu';

  @override
  String get videoMetadataPausePreviewSemanticLabel =>
      'Mettre l\'aperçu en pause';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Fermer l\'aperçu vidéo';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Supprimer';

  @override
  String get fullscreenFeedRemovedMessage => 'Vidéo supprimée';

  @override
  String get fullscreenFeedEmptyMessage => 'Il n’y a plus rien à lire ici';

  @override
  String get settingsBadgesTitle => 'Insignes';

  @override
  String get settingsBadgesSubtitle =>
      'Accepte les récompenses et vérifie le statut des badges délivrés.';

  @override
  String get badgesTitle => 'Insignes';

  @override
  String get badgesLoadError => 'Impossible de charger les badges';

  @override
  String get badgesUpdateError => 'Impossible de mettre à jour le badge';

  @override
  String get badgesAwardedEmptyTitle =>
      'Aucune récompense de badge pour l\'instant';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Quand quelqu\'un te décerne un badge Nostr, il atterrira ici.';

  @override
  String get badgesStatusAccepted => 'Accepté';

  @override
  String get badgesStatusNotAccepted => 'Non accepté';

  @override
  String get badgesActionRemove => 'Retirer';

  @override
  String get badgesActionAccept => 'Accepter';

  @override
  String get badgesActionReject => 'Refuser';

  @override
  String get badgesIssuedEmptyTitle => 'Aucun badge délivré pour l\'instant';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Les badges que tu délivres afficheront leur statut d\'acceptation ici.';

  @override
  String get badgesIssuedNoRecipients =>
      'Aucun destinataire trouvé pour cette récompense.';

  @override
  String get badgesRecipientAcceptedStatus => 'Accepté par le destinataire';

  @override
  String get badgesRecipientWaitingStatus => 'En attente du destinataire';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Masqués ($count)',
      one: 'Masqué ($count)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Restaurer';

  @override
  String get badgesHiddenSnackbar => 'Badge masqué';

  @override
  String get badgesHiddenSnackbarUndo => 'Annuler';

  @override
  String get badgesTabAwarded => 'Reçus';

  @override
  String get badgesTabCreated => 'Créés';

  @override
  String get badgesTabIssued => 'Décernés';

  @override
  String get badgesCreateAction => 'Nouveau badge';

  @override
  String get badgesCreatedEmptyTitle => 'Aucun badge créé';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Crées-en un et offre-le à quelqu\'un qui le mérite.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Décerné à $count personnes',
      one: 'Décerné à $count personne',
      zero: 'Pas encore décerné',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Nouveau badge';

  @override
  String get badgeEditorEditTitle => 'Modifier le badge';

  @override
  String get badgeEditorNameLabel => 'Nom';

  @override
  String get badgeEditorNameHint => 'Voleur de scène';

  @override
  String get badgeEditorIdentifierLabel => 'Identifiant';

  @override
  String get badgeEditorIdentifierHelp =>
      'Il fait partie de l\'adresse du badge : il ne bouge plus une fois le badge créé.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Tu as déjà un badge avec cet identifiant. Modifie plutôt celui-là : publier ici le remplacerait.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Chaque badge a besoin d\'un identifiant : saisis-en un si le nom ne l\'a pas rempli.';

  @override
  String get badgeEditorDescriptionLabel => 'Description';

  @override
  String get badgeEditorDescriptionHint =>
      'Pour celle ou celui qui vole la vedette en une seule boucle.';

  @override
  String get badgeEditorArtworkLabel => 'Visuel';

  @override
  String get badgeEditorArtworkAdd => 'Ajouter un visuel';

  @override
  String get badgeEditorArtworkReplace => 'Remplacer';

  @override
  String get badgeEditorArtworkError => 'Impossible d\'envoyer cette image';

  @override
  String get badgeEditorArtworkRequired =>
      'Chaque badge a besoin d\'un visuel.';

  @override
  String get badgeEditorArtworkRemove => 'Retirer le visuel';

  @override
  String get badgeEditorArtworkSheetTitle => 'Visuel du badge';

  @override
  String get badgeDetailDeleteAction => 'Supprimer le badge';

  @override
  String get badgeDetailDeleteTitle => 'Supprimer ce badge ?';

  @override
  String get badgeDetailDeleteBody =>
      'Cela demande aux relais de retirer le badge et toutes les attributions que tu as faites. Les relais peuvent refuser, et celles et ceux qui l\'ont épinglé le gardent sur leur profil jusqu\'à ce qu\'ils l\'enlèvent.';

  @override
  String get badgeDetailDeleteConfirm => 'Supprimer';

  @override
  String get badgeEditorSaveAction => 'Publier le badge';

  @override
  String get badgeEditorSaveError => 'Impossible de publier le badge';

  @override
  String get badgeEditorLoadError => 'Impossible de charger ce badge';

  @override
  String get badgeDetailTitle => 'Badge';

  @override
  String get badgeDetailMadeBy => 'Créé par';

  @override
  String get badgeDetailRecipientsTitle => 'Décerné à';

  @override
  String get badgeDetailNoRecipients => 'Personne ne l\'a encore.';

  @override
  String get badgeDetailAwardAction => 'Décerner ce badge';

  @override
  String get badgeDetailEditAction => 'Modifier le badge';

  @override
  String get badgeDetailShareAction => 'Partager';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Regarde ce badge sur Divine : $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Reprendre le badge';

  @override
  String get badgeDetailRevokeTitle => 'Reprendre ce badge ?';

  @override
  String get badgeDetailRevokeBody =>
      'Cela demande aux relais de retirer l\'attribution faite à cette personne. Les relais peuvent refuser, et si elle a déjà épinglé le badge, il reste sur son profil jusqu\'à ce qu\'elle l\'enlève. Dans tous les cas, elle n\'en est pas informée.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Cela demande aux relais de retirer l\'attribution que tu t\'es faite, et enlève le badge de ton profil. Si les relais refusent la suppression, rien ne change.';

  @override
  String get badgeDetailRevokeConfirm => 'Reprendre';

  @override
  String get badgeDetailRevokeSuccess => 'Badge repris';

  @override
  String get badgeDetailBlockClaimantsAction =>
      'Bloquer les porteurs de ce badge';

  @override
  String get badgeDetailBlockClaimantsTitle =>
      'Bloquer les porteurs de ce badge';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Impossible de charger les porteurs de ce badge';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Personne ne porte ce badge pour l\'instant';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Nous n\'avons trouvé personne à bloquer pour l\'instant.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bloquer $count comptes ?',
      one: 'Bloquer $count compte ?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cela bloque les $count comptes qui portent ce badge en ce moment. Leurs posts n\'apparaîtront plus dans tes fils, et ils ne seront pas prévenus.',
      one:
          'Cela bloque le compte qui porte ce badge en ce moment. Ses posts n\'apparaîtront plus dans tes fils, et il ne sera pas prévenu.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bloquer $count comptes',
      one: 'Bloquer $count compte',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Porteurs du badge bloqués';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Impossible de bloquer les porteurs du badge';

  @override
  String get badgeDetailLoadError => 'Impossible de charger ce badge';

  @override
  String get badgeDetailMissing => 'Ce badge est introuvable sur les relais.';

  @override
  String get badgeDetailActionError => 'Ça n\'a pas marché';

  @override
  String get badgeAwardTitle => 'Décerner un badge';

  @override
  String get badgeAwardPickAction => 'Choisir des personnes';

  @override
  String get badgeAwardManualLabel => 'Ou colle des clés';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Choisis au moins une personne.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Décerner à $count personnes',
      one: 'Décerner à $count personne',
      zero: 'Décerner le badge',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Décerné par';

  @override
  String get profileBadgeRecipients => 'Destinataires';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count autres';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Badge $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Badge';

  @override
  String get profileBadgeFooterBody =>
      'Les badges sont de petites récompenses que n\'importe qui peut créer sur Nostr. Offres-en un à un ami, à un créateur ou à quelqu\'un qui a illuminé ta journée.';

  @override
  String get profileBadgeFooterLink => 'Crée ton propre badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Guide famille';

  @override
  String get minorAccountReviewWelcomeTitle =>
      'Pas encore 16 ans ? Aucun souci.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Le fait que tu sois venu jusqu\'à cette page au lieu de simplement cocher la réponse qui te faisait entrer, ça compte. Ça montre de l\'honnêteté, du caractère et une vraie attention aux gens autour de toi.\n\nLes règles pour les moins de 16 ans varient selon l\'endroit où tu vis. Chez Divine, on veut que les familles en discutent ensemble et décident à quoi ressemble un usage sain des réseaux sociaux.';

  @override
  String get minorAccountReviewModerationTitle => 'Il nous manque une étape';

  @override
  String get minorAccountReviewModerationBody =>
      'On nous a demandé de regarder ce compte de plus près, car il pourrait appartenir à une personne de moins de 16 ans. Ce parcours garde les étapes suivantes privées et t\'oriente vers la voie adaptée à ton âge.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Les règles ne sont pas les mêmes partout';

  @override
  String get minorAccountReviewRulesBody =>
      'Les pays et les régions traitent différemment l\'usage des réseaux sociaux par les ados. C\'est pour ça qu\'on demande aux familles de ralentir, de vérifier les faits et de choisir la suite ensemble.';

  @override
  String get minorAccountReviewApproachTitle =>
      'Comment Divine voit les choses';

  @override
  String get minorAccountReviewApproachBody =>
      'On pense que des habitudes numériques saines viennent du fait de faire une pause, de réfléchir et de rediriger son attention vers de meilleures choses – pas d\'espionner les enfants ni de transformer les parents en surveillants. La recherche va dans ce sens aussi.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Plus pour les familles';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Lire la politique enfants de Divine';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'Choisis la voie qui correspond';

  @override
  String get minorAccountReviewUnder13Cta => 'Moins de 13 ans';

  @override
  String get minorAccountReviewTeenCta => '13-15 ans';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Consulte le guide famille de Divine : conseils pratiques, outils de discussion et ressources pour aider les ados à utiliser les réseaux sociaux plus sereinement.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Voir les guides et conseils famille';

  @override
  String get minorAccountReviewFooter =>
      'Si tu as 16 ans ou plus et que tu es arrivé ici par erreur, contacte le support Divine pour qu\'une vraie personne vérifie.';

  @override
  String get minorAccountReviewTitle => 'Examen du compte';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Vérification de l\'état du compte...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Patiente pendant qu\'on confirme l\'état actuel de l\'examen de ce compte.';

  @override
  String get minorAccountReviewDefaultTitle => 'Examen du compte nécessaire';

  @override
  String get minorAccountReviewDefaultBody =>
      'On doit examiner ce compte avant qu\'il puisse utiliser Divine normalement.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'N° de dossier : $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'N° de dossier';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'Ce qui est limité en ce moment';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'La publication est en pause';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Commentaires, j\'aime, reposts et abonnements sont en pause';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Démarrer ou répondre à des messages classiques est en pause';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Le support et ton message de modération restent accessibles';

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
  String get minorAccountReviewOpenSupportCenter => 'Ouvrir le centre d\'aide';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Ouvrir le message de modération';

  @override
  String get minorAccountReviewOpenReviewPage => 'Ouvrir la page d\'examen';

  @override
  String get minorAccountReviewCheckAgain => 'Vérifier à nouveau';

  @override
  String get minorAccountReviewLogOut => 'Se déconnecter';

  @override
  String get minorAccountReviewNextStepTitle => 'Étape suivante';

  @override
  String get minorAccountReviewNextStepBody =>
      'Ouvre le centre d\'aide ou ton message de modération si tu as besoin d\'aide pour cet examen.';

  @override
  String get minorAccountReviewInProgressTitle => 'Examen en cours';

  @override
  String get minorAccountReviewInProgressBody =>
      'On a ce qu\'il faut pour l\'instant. Notre équipe examine ce dossier avant de rétablir l\'accès normal au compte.';

  @override
  String get minorAccountReviewUnder13Title => 'Comptes de moins de 13 ans';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Si ce compte appartient à une personne de moins de 13 ans, un parent ou tuteur doit écrire à $supportEmail en indiquant le numéro de dossier.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'On ne peut pas encore te donner de compte';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine n\'est pas conçu pour les enfants de moins de 13 ans, et les règles des réseaux sociaux à travers le monde nous lient les mains.\n\nBeaucoup de choses sur internet te poussent à mentir pour obtenir ce que tu veux, et on déteste ça. C\'est la mauvaise leçon pour la vie, et on ne va pas te l\'apprendre ici.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Ce que ta famille peut faire à la place';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Un parent ou tuteur peut tenir le compte et publier, et tu peux tout à fait apparaître dans les vidéos avec eux. On veut que les familles profitent de Divine de la façon qui leur convient.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Quand tu auras 13 ans';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Selon les règles là où tu vis, tu pourras peut-être revenir et demander ton propre compte. Dans ce cas, si tu as entre 13 et 15 ans, il te faudra l\'accord d\'un parent ou tuteur.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Pourquoi on ne va pas te dire de juste revenir en arrière';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Une grande partie d\'internet est conçue pour récompenser les gens qui disent ce qu\'il faut pour passer la porte. On ne trouve pas ça génial. Oui, tu pourrais revenir en arrière et dire que tu es plus âgé que tu ne l\'es, mais ce ne serait pas honnête, et on ne va pas t\'apprendre à mentir pour obtenir ce que tu veux.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'On essaie d\'aider les jeunes à utiliser Divine d\'une manière saine et positive pour eux et pour leur entourage. On doit aussi respecter des lois qui diffèrent selon les endroits. Donc, si tu as moins de 13 ans, la réponse est que tu ne peux pas avoir ton propre compte aujourd\'hui.';

  @override
  String get minorAccountReviewTeenBody =>
      'Si ce compte appartient à une personne de 13 à 15 ans, utilise le message de modération ou le support pour suivre les instructions sur l\'accord parental.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Si le compte sera celui d\'une personne de 13 à 15 ans';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Un parent ou tuteur doit écrire au support Divine avec une courte vidéo privée. Notre équipe l\'examinera et t\'aidera pour les étapes suivantes.\n\nSi contacter un parent ou tuteur n\'est pas possible ou mettrait quelqu\'un en danger, écris au support Divine et dis-le-nous.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'C\'est une pause le temps que l\'équipe du support Divine examine la vidéo. Si elle est approuvée, elle te guidera pour créer le nouveau compte.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Pourquoi on demande qu\'un parent ou tuteur soit impliqué';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine doit respecter les lois liées à l\'âge partout dans le monde. On sait aussi que la plupart des contrôles d\'âge techniques sont imparfaits. Plutôt que de faire comme si les règles n\'existaient pas ou que c\'est cool de mentir sur son âge, on veut que les ados et les familles prennent des décisions réfléchies sur la meilleure façon d\'utiliser Divine. C\'est pourquoi, pour les 13-15 ans, on demande aux parents de faire partie du processus de création du compte.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'On doit aussi respecter la loi, et ces règles diffèrent selon l\'endroit où quelqu\'un vit. Donc, au lieu de faire comme si les règles n\'existaient pas, on demande qu\'un parent ou tuteur fasse partie du processus.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Ce que la vidéo doit montrer';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'L\'ado dans la vidéo';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Un parent ou tuteur qui parle face caméra';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Une déclaration claire indiquant que l\'ado a entre 13 et 15 ans et a l\'autorisation d\'utiliser Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Une déclaration claire indiquant que le parent ou tuteur connaît le compte et en surveillera l\'usage';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Comment l\'envoyer';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Joins la vidéo à ton e-mail au support Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Garde la vidéo privée et ne la publie pas dans l\'app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Notre équipe l\'examinera et répondra avec les étapes suivantes';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Écrire au support Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Aide pour l\'examen Divine Greenlight (13-15 ans)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Bonjour l\'équipe support Divine,\n\nje vous écris au sujet de Divine Greenlight pour un ado de 13 à 15 ans.\n\nJ\'ai joint une courte vidéo privée qui montre :\n- l\'ado\n- un parent ou tuteur qui parle face caméra\n- que l\'ado a l\'autorisation d\'utiliser Divine\n- que le parent ou tuteur connaît le compte et en surveillera l\'usage\n\nPays de résidence :\n\nContexte utile :\n\nMerci.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Instructions du support pour les parents';

  @override
  String get minorAccountReviewContinue => 'Continuer';

  @override
  String get minorAccountReviewErrorTitle =>
      'On n\'a pas pu charger l\'état de l\'examen de ton compte.';

  @override
  String get minorAccountReviewErrorBody => 'Réessaie dans un instant.';

  @override
  String get minorAccountReviewTryAgain => 'Réessayer';

  @override
  String get minorAccountReviewParentContactTitle => 'Contact du parent';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Ajoute l\'e-mail d\'un parent ou tuteur';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'On utilisera cette adresse pour l\'examen de l\'accord parental sur le dossier $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'E-mail du parent ou tuteur';

  @override
  String get minorAccountReviewSubmitting => 'Envoi...';

  @override
  String get minorAccountReviewSubmitEmail => 'Envoyer l\'e-mail';

  @override
  String get minorAccountReviewBackToReview => 'Retour à l\'examen du compte';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'E-mail envoyé';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'On a transmis $email pour examen. On écrira à cette adresse pour confirmer. Dès que ton parent ou tuteur répond, ton dossier avance. Utilise Vérifier à nouveau sur l\'écran d\'examen du compte pour suivre.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'On a reçu le contact du parent ou tuteur pour ce compte. Notre équipe l\'examinera avant de rétablir l\'accès.';

  @override
  String get minorAccountReviewMissingCase =>
      'On n\'a pas trouvé de dossier d\'examen actif pour ce compte.';

  @override
  String get minorAccountReviewParentContactError =>
      'Impossible d\'envoyer l\'e-mail du parent. Réessaie.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Support parents';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Un parent ou tuteur doit contacter Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Pour les comptes qui semblent appartenir à des moins de 13 ans, l\'étape suivante est un e-mail d\'un parent ou tuteur.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'E-mail du support';

  @override
  String get minorAccountReviewCopySupportEmail =>
      'Copier l\'e-mail du support';

  @override
  String get minorAccountReviewSupportEmailCopied => 'E-mail du support copié';

  @override
  String get minorAccountReviewCopyCaseId => 'Copier le n° de dossier';

  @override
  String get minorAccountReviewCaseIdCopied => 'N° de dossier copié';

  @override
  String get minorAccountReviewUnavailable => 'Indisponible';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Demande au parent ou tuteur d\'indiquer le numéro de dossier et d\'expliquer qu\'il contacte Divine au sujet de cet examen de compte.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Examen de compte moins de 13 ans pour le dossier $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Bonjour l\'équipe support Divine,\n\nje suis le parent ou tuteur d\'un enfant de moins de 13 ans et je vous écris au sujet du dossier d\'examen de compte $caseId.\n\nMerci.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulation d\'examen de compte de mineur';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'État actuel';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Restreint ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Actif';

  @override
  String get devOptionsMinorReviewStateLoading => 'Chargement...';

  @override
  String get devOptionsMinorReviewStateError =>
      'Erreur au chargement de l\'état';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Effacer la surcharge de simulation';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Réutiliser le backend ou l\'état actif par défaut';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      'Simuler un dossier d\'examen 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Compte restreint avec parcours de contact parental';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simuler un dossier support moins de 13 ans';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Compte restreint avec instructions uniquement par e-mail du parent';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simulation d\'examen de compte de mineur effacée';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Dossier support simulé moins de 13 ans activé';

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
      'Simulation de mineur protégé';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'État actuel';

  @override
  String get devOptionsProtectedMinorStateProtected => 'Mineur protégé (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Non protégé';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Chargement…';

  @override
  String get devOptionsProtectedMinorStateError =>
      'Erreur à la lecture de l\'état';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Aucune surcharge (état réel du compte)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Surcharge : protégé forcé';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Surcharge : non protégé forcé';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simuler un mineur protégé (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Force l\'état mineur protégé pour tester les protections #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simuler une personne majeure';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Force non protégé (un non explicite, différent de l\'absence de surcharge)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Effacer la surcharge';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Revenir à l\'état réel du compte donné par Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'État mineur protégé forcé';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'État mineur protégé désactivé';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Surcharge mineur protégé effacée';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Invitations d\'inscription';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'État actuel';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Valeur serveur : chargement';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Valeur serveur : activé';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Valeur serveur : désactivé';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Valeur serveur : inconnue';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Surcharge : utiliser la valeur serveur';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Surcharge : forcer activé';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Surcharge : forcer désactivé';

  @override
  String get devOptionsInviteAvailabilityUseServer =>
      'Utiliser la valeur serveur';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Suivre l\'onboardingMode du service d\'invitations';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Forcer activé';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Afficher en local les blocages et la gestion des invitations';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Forcer désactivé';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Masquer en local l\'interface des invitations sans toucher au serveur';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Les invitations d\'inscription suivent maintenant le serveur';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Invitations d\'inscription forcées comme activées';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Invitations d\'inscription forcées comme désactivées';

  @override
  String get commentsRecordVideoButtonLabel =>
      'Enregistrer un commentaire vidéo';

  @override
  String get commentsOpenVideoLabel => 'Ouvrir le commentaire vidéo';

  @override
  String get commentsMuteVideoReplyLabel => 'Couper le son de la réponse vidéo';

  @override
  String get commentsUnmuteVideoReplyLabel =>
      'Remettre le son de la réponse vidéo';

  @override
  String get commentsOpenReplyParentLabel =>
      'Ouvrir la vidéo à laquelle ceci répond';

  @override
  String get commentsReplyParentSectionTitle => 'En réponse à';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Réponse à $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Réponse à la vidéo';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Compte $platform vérifié : $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Comptes vérifiés';

  @override
  String get profileEditGetVerifiedCta => 'Vérifie-toi';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Connecte tes réseaux sociaux pour que les gens sachent que c\'est vraiment toi.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Ouvrir le site web : $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Impossible d\'ouvrir le site web';

  @override
  String get videoMetadataEditCoverTitle => 'Modifier la couverture';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Ignorer les modifications de la couverture';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Utiliser l’image sélectionnée comme couverture vidéo';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Faire défiler la vidéo pour sélectionner l\'image de couverture';

  @override
  String get videoMetadataTagsPickerSearchHint =>
      'Rechercher ou ajouter des tags';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Ajoute des tags pour que d\'autres découvrent ta vidéo';

  @override
  String get videoMetadataTagsPickerNoResults => 'Aucun tag correspondant';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Ajouter «#$tag»';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Pas encore 16 ans ? Pas de souci. ';

  @override
  String get authUnder16ChoicesCta => 'Voici tes choix.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Voilà pourquoi';

  @override
  String get generalSettingsHoldToRecord => 'Appuyer pour enregistrer';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'L\'enregistrement démarre en maintenant appuyé et s\'arrête en relâchant';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vidéos publiées sur ton profil',
      one: 'Vidéo publiée sur ton profil',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Envoyer le message';

  @override
  String get emojiPickerSearchHint => 'Rechercher';

  @override
  String get emojiCategoryRecent => 'Récents';

  @override
  String get emojiCategorySmileys => 'Smileys et personnes';

  @override
  String get emojiCategoryAnimals => 'Animaux et nature';

  @override
  String get emojiCategoryFood => 'Nourriture et boissons';

  @override
  String get emojiCategoryActivities => 'Activités';

  @override
  String get emojiCategoryTravel => 'Voyages et lieux';

  @override
  String get emojiCategoryObjects => 'Objets';

  @override
  String get emojiCategorySymbols => 'Symboles';

  @override
  String get emojiCategoryFlags => 'Drapeaux';

  @override
  String get videoEditorMarkerLabel => 'Marqueur';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Ajouter un marqueur à la chronologie';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Supprimer le marqueur de la chronologie';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Supprimer le marqueur à la tête de lecture';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Supprimer le marqueur ?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Cela retire le marqueur de la chronologie. Votre montage reste intact.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Couper ou rétablir le son de toutes les pistes';

  @override
  String get videoEditorSplitFailed =>
      'Échec de la division. Veuillez réessayer.';

  @override
  String get videoEditEditSubtitles => 'Modifier les sous-titres';

  @override
  String get subtitleEditorTitle => 'Modifier les sous-titres';

  @override
  String get subtitleEditorSave => 'Enregistrer';

  @override
  String get subtitleEditorProcessing =>
      'Les sous-titres sont encore en cours de génération. Reviens dans un instant.';

  @override
  String get subtitleEditorNoSpeech =>
      'Aucune parole n\'a été détectée dans cette vidéo, il n\'y a donc rien à sous-titrer.';

  @override
  String get subtitleEditorWriteOwn => 'Écris-les toi-même';

  @override
  String get subtitleEditorAddCue => 'Ajouter une ligne';

  @override
  String get subtitleEditorRemoveCue => 'Supprimer cette ligne';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'La vidéo ne peut pas être lue pour l\'instant, mais tu peux quand même corriger les sous-titres.';

  @override
  String get subtitleEditorPlayPreview => 'Lire la vidéo';

  @override
  String get subtitleEditorPausePreview => 'Mettre la vidéo en pause';

  @override
  String get subtitleEditorInvalidHint =>
      'Chaque ligne a besoin de texte et d\'une fin après son début.';

  @override
  String get subtitleEditorLoadError =>
      'Impossible de charger les sous-titres. Réessaie.';

  @override
  String get subtitleEditorSaveSuccess => 'Sous-titres mis à jour';

  @override
  String get subtitleEditorSaveError =>
      'Impossible d\'enregistrer les sous-titres. Réessaie.';

  @override
  String get subtitleEditorRetry => 'Réessayer';

  @override
  String get subtitleEditorCueHint => 'Texte du sous-titre';

  @override
  String get imageCropEditorRotateLabel => 'Pivoter';

  @override
  String get imageCropEditorFlipLabel => 'Retourner';

  @override
  String get imageCropEditorResetLabel => 'Réinitialiser';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Annuler le recadrage';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Appliquer le recadrage';

  @override
  String get imageCropEditorProcessing => 'Application du recadrage…';

  @override
  String get backgroundUploadNotificationTitle => 'Envoi de la vidéo';

  @override
  String get monetizationSettingsTitle => 'Soutien aux créateurs';

  @override
  String get monetizationSettingsSubtitle =>
      'Ajoute des liens de pourboire et d\'abonnement';

  @override
  String get monetizationSettingsIntroTitle => 'Uniquement des liens externes';

  @override
  String get monetizationSettingsIntroBody =>
      'Ajoute des destinations que tu contrôles toi-même. Divine ne gère jamais le paiement et ne débloque aucun contenu dans l\'app via ces liens.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liens actifs sur ton profil',
      one: '$count lien actif sur ton profil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Envoyer un pourboire';

  @override
  String get monetizationSettingsSubscriptionSection => 'S\'abonner / soutenir';

  @override
  String get monetizationSettingsSave => 'Enregistrer les liens de soutien';

  @override
  String get monetizationSettingsSaving => 'Enregistrement...';

  @override
  String get monetizationSettingsSaved => 'Liens de soutien mis à jour';

  @override
  String get monetizationSettingsSaveFailed =>
      'Impossible d\'enregistrer les liens de soutien. Vérifie ta connexion et réessaie.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'Ajoute un identifiant ou une URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Ce lien n\'a pas l\'air correct.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Utilise un lien de ce service.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag ou lien cash.app';

  @override
  String get monetizationSettingsHintPayPal => 'Identifiant ou lien PayPal.me';

  @override
  String get monetizationSettingsHintVenmo => 'Identifiant ou lien Venmo';

  @override
  String get monetizationSettingsHintPatreon => 'Identifiant ou lien Patreon';

  @override
  String get monetizationSettingsHintSubstack => 'Domaine ou lien Substack';

  @override
  String get monetizationSettingsHintMedium => 'Identifiant ou lien Medium';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Identifiant ou lien Open Collective';

  @override
  String get profileSupportSheetTitle => 'Soutenir ce créateur';

  @override
  String get profileSupportSheetBody =>
      'Ces liens s\'ouvrent en dehors de Divine. Rien ici ne débloque de contenu dans l\'app.';

  @override
  String get profileSupportTipSection => 'Envoyer un pourboire';

  @override
  String get profileSupportSubscriptionSection => 'S\'abonner / soutenir';

  @override
  String get profileSupportButtonLabel => 'Soutenir';

  @override
  String get monetizationTipsSettingsTitle => 'Pourboires';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Ajoute des liens de pourboire facultatifs';

  @override
  String get monetizationTipsSettingsIntroTitle =>
      'Uniquement des pourboires facultatifs';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Les pourboires sont des cadeaux facultatifs entre personnes. Ils ne débloquent ni contenu, ni abonnement, ni fonctionnalité, ni classement, ni visibilité, ni accès sur Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liens de pourboire actifs sur ton profil',
      one: '$count lien de pourboire actif sur ton profil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave =>
      'Enregistrer les liens de pourboire';

  @override
  String get monetizationTipsSettingsSaved => 'Liens de pourboire mis à jour';

  @override
  String get profileTipButtonLabel => 'Pourboire';

  @override
  String get profileTipSheetTitle => 'Laisser un pourboire à ce créateur';

  @override
  String get profileTipSheetBody =>
      'Les liens de pourboire s\'ouvrent en dehors de Divine. Ils sont facultatifs et ne débloquent ni contenu, ni abonnement, ni fonctionnalité, ni accès sur Divine.';

  @override
  String get settingsStorageTitle => 'Stockage';

  @override
  String get settingsStorageCacheSectionTitle => 'Médias en cache';

  @override
  String get settingsStorageCacheDescription =>
      'Vidéos du fil, miniatures et rendus temporaires en cache. Les effacer est sans risque : ils sont retéléchargés ou régénérés si nécessaire.';

  @override
  String get settingsStorageMeasuring => 'Calcul en cours…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size utilisés';
  }

  @override
  String get settingsStorageClearButton => 'Vider le cache';

  @override
  String get settingsStorageClearConfirmTitle => 'Vider les médias en cache ?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Cela libère $size. Votre bibliothèque de clips n\'est pas affectée.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Vider';

  @override
  String get settingsStorageCleared => 'Cache vidé';

  @override
  String get settingsStorageLibrarySectionTitle => 'Bibliothèque de clips';

  @override
  String get settingsStorageLibraryDescription =>
      'Rechercher les clips défectueux dont le fichier vidéo est manquant.';

  @override
  String get settingsStorageScanButton => 'Vérifier la bibliothèque';

  @override
  String get settingsStorageLibraryHealthy => 'Aucun clip défectueux trouvé';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Clips défectueux trouvés : $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton =>
      'Supprimer les clips défectueux';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Clips défectueux supprimés';

  @override
  String get settingsStorageError => 'Une erreur s\'est produite';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Cache vidéo maximal';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count vidéos';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Supprimer les clips défectueux ?';

  @override
  String get settingsStorageRepairSectionTitle => 'Réparer l\'installation';

  @override
  String get settingsStorageRepairDescription =>
      'Si l\'appli plante ou se comporte bizarrement, réinitialiser ses données locales règle souvent le problème. Tes clips et brouillons restent.';

  @override
  String get settingsStorageRepairButton => 'Réinitialiser les données';

  @override
  String get settingsStorageRepairConfirmTitle => 'Réinitialiser les données ?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Ça efface les données de fil en cache et les fichiers temporaires. Tes clips, brouillons, réglages et ta connexion restent, mais tu devras redémarrer l\'appli après.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size seront supprimés';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Réinitialiser';

  @override
  String get settingsStorageRepairInProgress => 'Réinitialisation…';

  @override
  String get settingsStorageRepairSuccess =>
      'C\'est fait — redémarre l\'appli pour terminer.';

  @override
  String get settingsStorageRepairFailure =>
      'Impossible de tout réinitialiser. Réessaie après un redémarrage.';

  @override
  String get nostrSettingsSignatureVerification => 'Vérification de signature';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Choisis quand Divine vérifie les signatures des événements de relais. Les ID d’événement sont toujours validés d’abord.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Tous les relais';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Le plus sûr. Vérifie la signature de chaque événement de relais.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Relais non fiables';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Ignore les vérifications pour les relais déjà dans ton pool configuré.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Relais non Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Fais confiance aux relais Divine, vérifie le reste.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle =>
      'Partage tes vidéos sur d’autres plateformes';

  @override
  String get crosspostingSignInRequired =>
      'Connecte-toi avec Divine pour gérer le crossposting';

  @override
  String get crosspostingLoadFailed =>
      'Impossible de charger tes réglages de crossposting';

  @override
  String get crosspostingNoPlatforms =>
      'Aucune plateforme de crossposting n’est disponible pour le moment';

  @override
  String get crosspostingRetry => 'Réessayer';

  @override
  String get crosspostingNotConnected => 'Non connecté';

  @override
  String get crosspostingConnected => 'Connecté';

  @override
  String get crosspostingNeedsReconnect => 'À reconnecter';

  @override
  String get crosspostingConnect => 'Connecter';

  @override
  String get crosspostingReconnect => 'Reconnecter';

  @override
  String get crosspostingDisconnect => 'Déconnecter';

  @override
  String get crosspostingModeOff => 'Désactivé';

  @override
  String get crosspostingModeManual => 'Manuel';

  @override
  String get crosspostingModeManualSubtitle => 'Tu choisis pour chaque vidéo';

  @override
  String get crosspostingModeAutomatic => 'Automatique';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Les prochaines vidéos sont publiées automatiquement — seulement celles publiées après avoir activé ça';

  @override
  String get crosspostingNotConnectedError =>
      'Connecte d’abord cette plateforme pour changer sa façon de publier.';

  @override
  String get crosspostingGenericError => 'Un truc a mal tourné. Réessaie.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'La page de connexion n’a jamais répondu. Si tu as terminé là-bas, actualise — ton compte est peut-être déjà lié.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform connecté';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Impossible de connecter $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'La connexion a été annulée sur $platform';
  }

  @override
  String get supporterTitle => 'Supporters Divine';

  @override
  String get supporterTileSubtitle =>
      'Soutiens Divine avec un abonnement mensuel optionnel.';

  @override
  String get supporterHeroTitle => 'Fais tourner Divine';

  @override
  String get supporterHeroBody =>
      'Divine est gratuit et le sera toujours. Si tu veux nous aider à faire tourner les loops, deviens supporter mensuel. Rien n\'est verrouillé — ça garde juste les lumières allumées et ça te vaut notre gratitude.';

  @override
  String get supporterActiveBadge =>
      'Tu es supporter Divine. Merci de faire tourner tout ça.';

  @override
  String get supporterPurchasePending =>
      'Ton achat est en attente d\'approbation.';

  @override
  String get supporterPurchaseConfirming => 'Confirmation de ton soutien…';

  @override
  String get supporterStoreChecking => 'Vérification de la boutique…';

  @override
  String get supporterUnavailable =>
      'Les abonnements supporter ne sont pas disponibles ici pour l\'instant.';

  @override
  String get supporterRestorePurchases => 'Restaurer les achats';

  @override
  String get supporterDismissError => 'Masquer l\'erreur';

  @override
  String get supporterErrorStoreUnavailable =>
      'La boutique n\'est pas disponible sur cet appareil.';

  @override
  String get supporterErrorPurchaseFailed =>
      'L\'achat n\'a pas abouti. Tu n\'as pas été débité.';

  @override
  String get supporterErrorPurchasePending =>
      'Ton achat est en attente d\'approbation.';

  @override
  String get supporterErrorRestoreFailed =>
      'Aucun abonnement supporter à restaurer n\'a été trouvé.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Cet achat appartient à un autre compte Divine.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine n\'a pas pu confirmer le statut de supporter pour l\'instant.';

  @override
  String get supporterErrorUnknown => 'Un problème est survenu. Réessaie.';

  @override
  String get supporterDisclaimer =>
      'Divine confirme le statut de supporter après que la boutique a vérifié ton achat. La reconnaissance est optionnelle, et l\'auréole n\'est pas une vérification.';

  @override
  String get profileNotifyBellOff => 'M\'avertir des nouvelles vines';

  @override
  String get profileNotifyBellOn => 'Ne plus m\'avertir des nouvelles vines';

  @override
  String get profileNotifyUpdateFailed =>
      'Échec de l\'enregistrement. Réessayer ?';

  @override
  String get savedSoundYourLabel => 'Ton étiquette';

  @override
  String get savedSoundAddHashtags => 'Ajouter des hashtags';

  @override
  String get savedSoundDeviceOnly => 'Enregistré sur cet appareil';

  @override
  String get savedSoundDetailsRetry =>
      'Impossible d\'enregistrer ces infos. Appuie pour réessayer.';

  @override
  String get savedSoundFallbackTitle => 'Son enregistré';

  @override
  String get savedSoundPreviewAction => 'Écouter le son';

  @override
  String get savedSoundEditAction => 'Modifier les infos du son';

  @override
  String get savedSoundRemoveAction => 'Retirer le son enregistré';

  @override
  String get savedSoundClearHashtagFilter => 'Effacer le filtre de hashtags';

  @override
  String get soundAllowRemix => 'Autoriser les autres à remixer ce son';

  @override
  String get soundReuseUnavailable =>
      'Ce son ne peut pas être remixé pour le moment.';

  @override
  String get soundPublicCredit => 'Crédit public du son';

  @override
  String get soundCreditRequired =>
      'Ajoute le crédit public du son avant de publier.';

  @override
  String get soundSharedAs => 'Partagé sous';

  @override
  String get soundOwnWork => 'C\'est moi qui ai fait ce son';

  @override
  String soundCreatorBy(String creator) {
    return 'Par $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Partagé par $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remix autorisé';

  @override
  String get soundCreditOnly => 'Crédit uniquement';

  @override
  String get soundCreditTitleLabel => 'Titre du son';

  @override
  String get soundCreditCreatorLabel => 'Créateur';

  @override
  String get soundCreditSourceUrlLabel => 'URL source';

  @override
  String get soundCreditPublicHashtagsLabel => 'Hashtags publics';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Annuler la sélection des tags';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Appliquer les tags sélectionnés';

  @override
  String get userPickerCancelSemanticLabel =>
      'Annuler la sélection des utilisateurs';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Confirmer les utilisateurs sélectionnés';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Effacer la sélection des utilisateurs';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Annuler la sélection des avertissements de contenu';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Appliquer les avertissements de contenu sélectionnés';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Fermer l’éditeur vidéo';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Continuer vers les détails de la publication';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Ignorer les modifications dans $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Appliquer les modifications dans $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Supprimer l’audio';

  @override
  String rgbColorSemanticLabel(int red, int green, int blue) {
    return 'RVB $red, $green, $blue';
  }

  @override
  String videoEditorColorPickerSwatchSemanticLabel(
    String picker,
    String color,
  ) {
    return '$picker, $color';
  }

  @override
  String get verifyTitle => 'Comptes vérifiés';

  @override
  String get verifySignedOutMessage => 'Connecte-toi pour lier tes comptes.';

  @override
  String get verifyIntro =>
      'Lie les comptes que tu as déjà, comme ça tout le monde sait que c\'est bien toi.';

  @override
  String get verifyLoadFailed => 'Impossible de charger tes liens.';

  @override
  String get verifyRetry => 'Réessayer';

  @override
  String get verifyLinkedSectionTitle => 'Liés';

  @override
  String get verifyVerifierUnreachable =>
      'Le vérificateur était injoignable, donc tout s\'affiche comme non vérifié.';

  @override
  String get verifyAddSectionTitle => 'Ajouter un compte';

  @override
  String get verifyAllPlatformsLinked =>
      'Tu as lié tout ce qu\'on prend en charge.';

  @override
  String get verifyStatusVerified => 'Vérifié';

  @override
  String get verifyStatusUnverified => 'Non vérifié';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Délier le compte $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Délier $platform ?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity n\'apparaîtra plus sur ton profil. Tu pourras le relier plus tard, mais il faudra te reconnecter ou publier une nouvelle preuve.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Délier';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Lier ton compte $platform';
  }

  @override
  String get verifyOneTapBadge => 'Un tap';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Connecte-toi à $platform, on s\'occupe du reste. Rien n\'est publié.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Continuer avec $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Ou publie une preuve';

  @override
  String get verifyConnectProofExplainer =>
      'Publie ton npub sur ton compte, puis colle le lien vers ce post.';

  @override
  String get verifyNpubLabel => 'Ton npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Copier ton npub';

  @override
  String get verifyNpubCopied => 'npub copié';

  @override
  String get verifyIdentityLabel => 'Nom du compte';

  @override
  String get verifyProofLabel => 'Lien vers ton post';

  @override
  String get verifyConnectProofCta => 'Vérifier et lier';

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
      'Vérificateur injoignable. Réessaie dans un instant.';

  @override
  String get verifyErrorOauthFailed => 'Ça n\'a pas marché. Retente le coup.';

  @override
  String get verifyErrorHandleRequired => 'Saisis d\'abord ton identifiant.';

  @override
  String get verifyErrorPublishFailed =>
      'Vérifié, mais aucun relais n\'a accepté la mise à jour. Réessaie.';

  @override
  String get verifyErrorOauthUnavailable =>
      'La connexion en un tap n\'est pas encore configurée pour celui-ci. Utilise la preuve ci-dessous.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Crée un gist public avec ton npub dans le premier fichier, puis colle le lien du gist.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Publie ton npub dans un salon Discord que notre bot peut lire, puis colle le lien du message. Une invitation de serveur ne prouve rien.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tweete ton npub depuis ce compte, puis colle le lien du tweet.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Publie ton npub depuis ce compte, puis colle le lien. Le nom du compte doit inclure l\'instance — mastodon.social/@alice, pas juste alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'C\'est le canal qui est lié, pas ton compte Telegram. Il lui faut d\'abord un lien public (Telegram crée les nouveaux en privé). Publie ton npub et colle le lien du message.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Connecté ci-dessus ? Rien d\'autre à faire. Sinon publie ton npub et colle le lien de ce post.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Mets ton npub dans la légende d\'une vidéo, puis colle le lien de cette vidéo.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Mets ton npub dans la description d\'une vidéo, puis colle le lien de cette vidéo.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform est lié.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'C\'est un canal privé ou une invitation. Donne un lien public au canal, puis colle le lien du message.';

  @override
  String get verifyErrorRemoveFailed => 'Impossible de délier. Réessaie.';

  @override
  String get verifyErrorLinksUnreadable =>
      'On n\'a pas pu lire tes liens actuels, donc rien n\'a été modifié. Vérifie ta connexion et réessaie.';

  @override
  String get verifyChannelLabel => 'Nom du canal';

  @override
  String get verifyHowItWorksTitle => 'Comment ça marche ?';

  @override
  String get verifyHowItWorksIntro =>
      'Vois ça comme une poignée de main entre deux comptes :';

  @override
  String get verifyHowItWorksYourSide =>
      'Ton profil Divine dit : « Je suis @alice sur Twitter. »';

  @override
  String get verifyHowItWorksOtherSide =>
      'Ton compte Twitter confirme : « Oui, ce profil Divine est le mien. »';

  @override
  String get verifyHowItWorksBothSides =>
      'On vérifie les deux côtés. Si ça correspond, tu es vérifié. Impossible à falsifier : on peut copier ton nom et ta photo, pas publier depuis ton vrai compte.';

  @override
  String get verifyHowItWorksOwnership =>
      'Les liens vivent sur ta propre identité Nostr, tu peux donc les retirer ici quand tu veux.';

  @override
  String get generalSettingsSectionIdentity => 'Identité';

  @override
  String get libraryFilterAll => 'Tout';

  @override
  String get libraryFilterArchive => 'Archives';

  @override
  String get libraryFilterDeleted => 'Supprimés';

  @override
  String get libraryCategoryNewChipLabel => 'Nouvelle';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Créer une catégorie';

  @override
  String get libraryCategoryCreateTitle => 'Nouvelle catégorie';

  @override
  String get libraryCategoryCreateAction => 'Créer';

  @override
  String get libraryCategoryRenameTitle => 'Renommer la catégorie';

  @override
  String get libraryCategoryRenameAction => 'Renommer';

  @override
  String get libraryCategoryDeleteAction => 'Supprimer la catégorie';

  @override
  String get libraryCategoryNameLabel => 'Nom de la catégorie';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Tes clips restent. Ils repartent simplement dans Tout.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Renommer ou supprimer cette catégorie';

  @override
  String get libraryCategoryMoveTitle => 'Déplacer vers';

  @override
  String get libraryCategoryMoveNone => 'Aucune catégorie';

  @override
  String get libraryCategoryMoveNewCategory => 'Nouvelle catégorie';

  @override
  String get libraryArchiveAction => 'Archiver';

  @override
  String get libraryUnarchiveAction => 'Désarchiver';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Garder dans ces catégories ?',
      one: 'Garder dans cette catégorie ?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Garder dans $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'Garder dans leurs catégories';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Retirer de $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Retirer de leurs catégories';

  @override
  String get libraryMoveSelectedClipsTooltip =>
      'Déplacer les clips sélectionnés';

  @override
  String get libraryCategoryEmptyTitle => 'Rien ici pour l\'instant';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Sélectionne quelques clips et déplace-les dans cette catégorie.';

  @override
  String get libraryArchiveEmptyTitle => 'Rien d\'archivé';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Les clips archivés patientent ici, à l\'écart de ta bibliothèque principale.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips déplacés vers $name',
      one: '$count clip déplacé vers $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips retirés de leur catégorie',
      one: '$count clip retiré de sa catégorie',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips archivés',
      one: '$count clip archivé',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips de retour dans ta bibliothèque',
      one: '$count clip de retour dans ta bibliothèque',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Changer d\'e-mail';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Déplace ton compte vers une autre adresse';

  @override
  String get accountSettingsChangePassword => 'Changer de mot de passe';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Choisis un nouveau mot de passe pour te connecter';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Ta session a expiré. Reconnecte-toi pour faire ce changement.';

  @override
  String get accountCredentialsRateLimited =>
      'Trop de tentatives. Attends quelques minutes.';

  @override
  String get accountCredentialsNetwork =>
      'Impossible de joindre Divine. Vérifie ta connexion et réessaie.';

  @override
  String get accountCredentialsUnknown => 'Ça n\'a pas marché. Réessaie.';

  @override
  String get changePasswordSubtitle =>
      'Saisis ton mot de passe actuel, puis choisis-en un nouveau.';

  @override
  String get changePasswordCurrentLabel => 'Mot de passe actuel';

  @override
  String get changePasswordWrongCurrent =>
      'Ce n\'est pas ton mot de passe actuel.';

  @override
  String get changePasswordSuccess => 'Mot de passe changé.';

  @override
  String get changeEmailSubtitle =>
      'On envoie un lien de confirmation à ta nouvelle adresse et à celle de ton compte. Ton e-mail change une fois les deux confirmés.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Sur ton compte : $email';
  }

  @override
  String get changeEmailNewLabel => 'Nouvel e-mail';

  @override
  String get changeEmailPasswordLabel => 'Ton mot de passe';

  @override
  String get changeEmailSameAsCurrent => 'C\'est déjà ton adresse e-mail.';

  @override
  String get changeEmailWrongPassword => 'Ce n\'est pas ton mot de passe.';

  @override
  String get changeEmailSubmit => 'Envoyer les liens de confirmation';

  @override
  String get changeEmailSentTitle => 'Deux liens sont en route';

  @override
  String changeEmailSentMessage(String email) {
    return 'Confirme depuis $email et depuis l\'adresse de ton compte. Ton e-mail change une fois les deux faits.';
  }

  @override
  String get changeEmailSentExpiry =>
      'Les liens expirent au bout de 24 heures.';

  @override
  String get changeEmailSentDone => 'Compris';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount vidéos',
      one: '$formattedCount vidéo',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Mutuel';

  @override
  String get socialProofFollowsYou => 'Te suit';

  @override
  String get socialProofYouFollow => 'Tu suis';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount abonnés',
      one: '$formattedCount abonné',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Les vidéos ne se chargent pas pour le moment.\nÇa vient de nous, pas de vous — on s\'en occupe.';

  @override
  String get feedOfflineMessage =>
      'Vous êtes hors ligne.\nVérifiez votre connexion et réessayez.';

  @override
  String get dbFailureTitle =>
      'impossible de déverrouiller votre base de données locale';

  @override
  String get dbFailureAdviceResettable =>
      'Un redémarrage ne réglera pas ça. Réinitialiser la base de données locale ci-dessous donne à Divine un nouveau départ — votre compte est conservé.';

  @override
  String get dbFailureAdviceRestart =>
      'Redémarrez Divine après avoir déverrouillé votre appareil. Si cela persiste, mettez l\'application à jour ou contactez l\'assistance.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Essayez de redémarrer Divine une fois. Si le problème persiste, mettez l’application à jour ou contactez l’assistance. Vos données locales sont toujours là.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostic : $code';
  }

  @override
  String get dbFailureCloseApp => 'fermer Divine';

  @override
  String get dbFailureResetAction => 'réinitialiser la base de données locale';

  @override
  String get dbFailureConfirmTitle =>
      'réinitialiser votre base de données locale ?';

  @override
  String get dbFailureConfirmBody =>
      'Votre compte est conservé. Les brouillons et clips enregistrés sur cet appareil sont supprimés — les messages et fils reviennent du réseau.';

  @override
  String get dbFailureResetConfirm =>
      'réinitialiser la base de données locale maintenant';

  @override
  String get dbFailureCancel => 'annuler';

  @override
  String get dbFailureResetFailed =>
      'Ça n\'a pas fonctionné. Fermez Divine et réessayez.';

  @override
  String get dbFailureResetDoneTitle => 'base de données locale réinitialisée';

  @override
  String get dbFailureResetDoneBody =>
      'Fermez Divine et rouvrez-le — le prochain lancement crée une nouvelle base de données locale.';

  @override
  String get authSignInOptionsInfo => 'À propos des options de connexion';

  @override
  String get authShowPassword => 'Afficher le mot de passe';

  @override
  String get authHidePassword => 'Masquer le mot de passe';

  @override
  String get followUserSemanticLabel => 'Suivre l\'utilisateur';

  @override
  String get unfollowUserSemanticLabel => 'Ne plus suivre l\'utilisateur';

  @override
  String get commentsLoadingSemanticLabel => 'Chargement des commentaires';

  @override
  String get analyticsWindowAll => 'Tout';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Suivre l\'utilisateur $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Ne plus suivre l\'utilisateur $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / mois';
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
      'Une nouvelle mise à jour vient de sortir. Découvrez-la →';

  @override
  String get updateModerateTitle =>
      'Une mise à jour est disponible depuis votre dernière visite';

  @override
  String get updateUrgentTitle => 'Il vous manque des correctifs importants';

  @override
  String get updateNotNow => 'Pas maintenant';

  @override
  String get updateAction => 'Mettre à jour';

  @override
  String updateNewIn(String version) {
    return 'Nouveautés de la version $version :';
  }

  @override
  String get settingsUpdateAvailable => 'Mise à jour disponible';
}

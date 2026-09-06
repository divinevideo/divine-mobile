// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Recuperación de clips';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Encuentra grabaciones guardadas en otra cuenta y archivos de vídeo a los que ya no hace referencia ningún registro.';

  @override
  String get devOptionsClipRecoveryScan => 'Analizar';

  @override
  String get devOptionsClipRecoveryFailure => 'La recuperación de clips falló';

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
      other: '$drafts borradores',
      one: '$drafts borrador',
    );
    return 'Visible ahora: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Ocultos en otras cuentas';

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
      other: '$drafts borradores',
      one: '$drafts borrador',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Mover a esta cuenta';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Archivos sin referencia: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Reconstruir en la biblioteca';

  @override
  String get devOptionsClipRecoveryEmpty => 'Nada que recuperar';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips recuperados',
      one: '$count clip recuperado',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Informe de recuperación copiado';

  @override
  String get devOptionsStorageFootprint => 'Uso de almacenamiento';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Todos los directorios en los que escribe la app. Borrar la caché solo libera una parte.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Medir';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Total: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied =>
      'Informe de almacenamiento copiado';

  @override
  String get devOptionsStorageFootprintFailure =>
      'No se pudo medir el almacenamiento';

  @override
  String get feedTuningMoreLabel => 'Más como esto';

  @override
  String get feedTuningLessLabel => 'Menos como esto';

  @override
  String get feedTuningUndo => 'Deshacer';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Abrir el vídeo referenciado';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSecureAccount => 'Asegurá tu cuenta';

  @override
  String get settingsSessionExpired => 'Sesión vencida';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Iniciá sesión de nuevo para recuperar el acceso total';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Analíticas del creador';

  @override
  String get settingsSupportCenter => 'Centro de soporte';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsBlueskyPublishing => 'Publicación en Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gestioná las publicaciones cruzadas a Bluesky';

  @override
  String get settingsNostrSettings => 'Ajustes de Nostr';

  @override
  String get settingsIntegratedApps => 'Apps integradas';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Apps de terceros aprobadas que funcionan dentro de Divine';

  @override
  String get settingsExperimentalFeatures => 'Funciones experimentales';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Novedades que pueden fallar—probalas si te pica la curiosidad.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Permisos de integración';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Revisá y revocá las integraciones que autorizaste';

  @override
  String settingsVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get settingsVersionEmpty => 'Versión';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'El modo desarrollador ya está activado';

  @override
  String get settingsDeveloperModeEnabled => '¡Modo desarrollador activado!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Te faltan $count toques para activar el modo desarrollador';
  }

  @override
  String get settingsShareDivine => 'Compartí Divine con tus amigos';

  @override
  String get settingsSwitchAccount => 'Cambiar de cuenta';

  @override
  String get settingsAddAnotherAccount => 'Agregar otra cuenta';

  @override
  String get settingsAccountSwitchFailed =>
      'No se pudieron cambiar las cuentas. Inténtalo de nuevo.';

  @override
  String get settingsUnsavedDraftsTitle => 'Borradores sin guardar';

  @override
  String get settingsUploadInProgressTitle => 'Subida en curso';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos',
      one: 'video',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tus videos quedan como borradores',
      one: 'tu video queda como borrador',
    );
    return 'Todavía tenés $count $_temp0 subiendo. Cambiar de cuenta detiene la subida: $_temp1 en esta cuenta.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'borradores sin guardar',
      one: 'borrador sin guardar',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tus borradores',
      one: 'tu borrador',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'los',
      one: 'lo',
    );
    return 'Tenés $count $_temp0. Cambiar de cuenta va a mantener $_temp1, pero quizás quieras publicar o revisar$_temp2 primero.';
  }

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsSwitchAnyway => 'Cambiar igual';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'La sesión de esa cuenta caducó. Volver a entrar en ella significa cerrar la sesión de la que estás usando ahora.';

  @override
  String get settingsAppVersionLabel => 'Versión de la app';

  @override
  String get settingsAppLanguage => 'Idioma de la app';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (predeterminado del dispositivo)';
  }

  @override
  String get settingsAppLanguageTitle => 'Idioma de la app';

  @override
  String get settingsAppLanguageDescription =>
      'Elegí el idioma para la interfaz de la app';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Usar el idioma del dispositivo';

  @override
  String get settingsGeneralTitle => 'Ajustes generales';

  @override
  String get settingsContentSafetyTitle => 'Contenido y seguridad';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRACIONES';

  @override
  String get generalSettingsSectionViewing => 'VISUALIZACIÓN';

  @override
  String get generalSettingsSectionCreating => 'CREACIÓN';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get appearanceSettingsTitle => 'Apariencia';

  @override
  String get appearanceSettingsSubtitle =>
      'Elige cómo se ve Divine en este dispositivo';

  @override
  String get appearanceSettingsSystem => 'Predeterminado del sistema';

  @override
  String get appearanceSettingsLight => 'Claro';

  @override
  String get appearanceSettingsDark => 'Oscuro';

  @override
  String get generalSettingsClosedCaptions => 'Subtítulos';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Mostrar los subtítulos cuando los videos los incluyan';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Solo videos cuadrados';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Mantené los feeds en el formato cuadrado clásico';

  @override
  String get contentPreferencesTitle => 'Preferencias de contenido';

  @override
  String get contentPreferencesContentFilters => 'Filtros de contenido';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gestioná los filtros de advertencia de contenido';

  @override
  String get contentPreferencesContentLanguage => 'Idioma del contenido';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (predeterminado del dispositivo)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Etiquetá tus videos con un idioma para que quien mire pueda filtrar el contenido.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Usar el idioma del dispositivo (predeterminado)';

  @override
  String get contentPreferencesAudioSharing =>
      'Permitir que reutilicen mi audio';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Si lo activás, otros pueden usar el audio de tus videos';

  @override
  String get contentPreferencesMusicMode => 'Modo música';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Desactiva la limpieza de ruido que aplasta los instrumentos. Mejor para la música, más áspero para las voces.';

  @override
  String get contentPreferencesAccountLabels => 'Etiquetas de la cuenta';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Auto-etiquetá tu contenido';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etiquetas de contenido de la cuenta';

  @override
  String get contentPreferencesClearAll => 'Limpiar todo';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Seleccioná todas las que apliquen a tu cuenta';

  @override
  String get contentPreferencesDoneNoLabels => 'Listo (sin etiquetas)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Listo ($count seleccionadas)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Dispositivo de entrada de audio';

  @override
  String get contentPreferencesAutoRecommended => 'Automático (recomendado)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Elige automáticamente el mejor micrófono';

  @override
  String get contentPreferencesSelectAudioInput => 'Elegí la entrada de audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Micrófono desconocido';

  @override
  String get contentFiltersAdultContent => 'CONTENIDO ADULTO';

  @override
  String get contentFiltersViolenceGore => 'VIOLENCIA Y GORE';

  @override
  String get contentFiltersSubstances => 'SUSTANCIAS';

  @override
  String get contentFiltersOther => 'OTROS';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verificá tu edad en Seguridad y privacidad para desbloquear los filtros de contenido adulto';

  @override
  String get contentFiltersShow => 'Mostrar';

  @override
  String get contentFiltersWarn => 'Advertir';

  @override
  String get contentFiltersFilterOut => 'Filtrar';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Esta cuenta no está disponible';

  @override
  String get profileInvalidId => 'ID de perfil inválido';

  @override
  String profileShareText(String displayName, String npub) {
    return '¡Mirá a $displayName en Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName en Divine';
  }

  @override
  String get profileShareFailed =>
      'No se pudo compartir el perfil. Probá de nuevo.';

  @override
  String get profileCopyPublicKey => 'Copiar clave pública (npub)';

  @override
  String get profileGetEmbedCode => 'Obtener código de inserción';

  @override
  String get profilePublicKeyCopied => 'Clave pública copiada al portapapeles';

  @override
  String get profileEmbedCodeCopied =>
      'Código de inserción copiado al portapapeles';

  @override
  String get profileMoreTooltip => 'Más';

  @override
  String get profileMoreSemanticLabel => 'Más opciones';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Cerrar avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Cerrar vista previa del avatar';

  @override
  String get profileFollowingLabel => 'Siguiendo';

  @override
  String get profileFollowLabel => 'Seguir';

  @override
  String get profileBlockedLabel => 'Bloqueado';

  @override
  String get profileFollowersLabel => 'Seguidores';

  @override
  String get profileFollowingStatLabel => 'Siguiendo';

  @override
  String get profileVideosLabel => 'Videos';

  @override
  String get profileCollabsLabel => 'Colaboraciones';

  @override
  String get profileLikedLabel => 'Me gusta';

  @override
  String get profileRepostsLabel => 'Reposts';

  @override
  String get profileListsLabel => 'Listas';

  @override
  String get profileCommentsLabel => 'Comentarios';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan enviar $count invitaciones de colaborador',
      one: 'Falta enviar 1 invitación de colaborador',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Dejamos la invitación en cola. Reintentala acá.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Para \"$title\". Reintentala acá.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Reintentar';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Reintentando';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'El reintento de invitaciones de colaborador no está disponible ahora mismo.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan enviar $count invitaciones de colaborador.',
      one: 'Falta enviar 1 invitación de colaborador.',
      zero: 'Invitaciones de colaborador enviadas.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colaboradores no pueden recibir invitaciones.',
      one: '1 colaborador no puede recibir invitaciones.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count usuarios';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '¿Bloquear a $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Cuando bloqueás a alguien:';

  @override
  String get profileBlockBulletHidePosts =>
      'Sus publicaciones no van a aparecer en tus feeds.';

  @override
  String get profileBlockBulletCantView =>
      'No va a poder ver tu perfil, seguirte, ni ver tus publicaciones.';

  @override
  String get profileBlockBulletNoNotify => 'No le vamos a avisar del bloqueo.';

  @override
  String get profileBlockBulletYouCanView =>
      'Vos vas a poder seguir viendo su perfil.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Bloquear a $displayName';
  }

  @override
  String get profileCancelButton => 'Cancelar';

  @override
  String get profileLearnMore => 'Conocé más';

  @override
  String profileUnblockTitle(String displayName) {
    return '¿Desbloquear a $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Cuando desbloqueás a alguien:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Sus publicaciones van a aparecer en tus feeds.';

  @override
  String get profileUnblockBulletCanView =>
      'Va a poder ver tu perfil, seguirte y ver tus publicaciones.';

  @override
  String get profileUnblockBulletNoNotify => 'No le vamos a avisar del cambio.';

  @override
  String get profileLearnMoreAt => 'Conocé más en ';

  @override
  String get profileUnblockButton => 'Desbloquear';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Dejar de seguir a $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Bloquear a $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Desbloquear a $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Reportar a $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Añadir $displayName a una lista';
  }

  @override
  String get profileNoCollabsTitle => 'Todavía no hay colabs';

  @override
  String get profileCollabsOwnEmpty =>
      'Los videos en los que colabores van a aparecer acá';

  @override
  String get profileCollabsOtherEmpty =>
      'Los videos en los que colabore van a aparecer acá';

  @override
  String get profileErrorLoadingCollabs =>
      'Error al cargar los videos en colab';

  @override
  String get profileNoSavedVideosTitle => 'Todavía no guardaste nada';

  @override
  String get profileSavedOwnEmpty =>
      'Marcá videos como favoritos desde el menú de compartir y van a aparecer acá.';

  @override
  String get profileErrorLoadingSaved => 'Error al cargar los videos guardados';

  @override
  String get profileNoCommentsOwnTitle => 'Todavía no hay comentarios';

  @override
  String get profileNoCommentsOtherTitle => 'Sin comentarios';

  @override
  String get profileCommentsOwnEmpty =>
      'Tus comentarios y respuestas van a aparecer acá';

  @override
  String get profileCommentsOtherEmpty =>
      'Sus comentarios y respuestas van a aparecer acá';

  @override
  String get profileErrorLoadingComments => 'Error al cargar los comentarios';

  @override
  String get profileVideoRepliesSection => 'Respuestas en video';

  @override
  String get profileCommentsSection => 'Comentarios';

  @override
  String get profileEditLabel => 'Editar';

  @override
  String get profileLibraryLabel => 'Biblioteca';

  @override
  String get profileNoLikedVideosTitle => 'Todavía no hay videos que te gusten';

  @override
  String get profileLikedOwnEmpty =>
      'Los videos que te gusten van a aparecer acá';

  @override
  String get profileLikedOtherEmpty =>
      'Los videos que le gusten van a aparecer acá';

  @override
  String get profileErrorLoadingLiked =>
      'Error al cargar los videos con me gusta';

  @override
  String get profileNoRepostsTitle => 'Todavía no hay reposts';

  @override
  String get profileRepostsOwnEmpty =>
      'Los videos que republiques van a aparecer acá';

  @override
  String get profileRepostsOtherEmpty =>
      'Los videos que republique van a aparecer acá';

  @override
  String get profileErrorLoadingReposts =>
      'Error al cargar los videos reposteados';

  @override
  String get profileNoVideosTitle => 'Todavía no hay videos';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Compartí tu primer video para verlo acá';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Este usuario todavía no compartió ningún video';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatura de video $number';
  }

  @override
  String get profileShowMore => 'Ver más';

  @override
  String get profileShowLess => 'Ver menos';

  @override
  String get dmMessageDisplayLimitReached =>
      'El resto de este mensaje no se muestra.';

  @override
  String get profileCompleteYourProfile => 'Completá tu perfil';

  @override
  String get profileCompleteSubtitle =>
      'Agregá tu nombre, bio y foto para arrancar';

  @override
  String get profilePleaseTryAgain => 'Probá de nuevo';

  @override
  String get profileSecureYourAccount => 'Asegurá tu cuenta';

  @override
  String get profileSecureSubtitle =>
      'Agregá email y contraseña para recuperar tu cuenta en cualquier dispositivo';

  @override
  String get profileRetryButton => 'Reintentar';

  @override
  String get profileSessionExpired => 'Sesión vencida';

  @override
  String get profileSignInToRestore =>
      'Iniciá sesión de nuevo para recuperar el acceso total';

  @override
  String get profileSignInButton => 'Iniciar sesión';

  @override
  String get profileMaybeLaterLabel => 'Quizás más tarde';

  @override
  String get profileSecurePrimaryButton => 'Agregar email y contraseña';

  @override
  String get profileCompletePrimaryButton => 'Actualizar tu perfil';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Me gusta';

  @override
  String get profileMyLibraryLabel => 'Mi biblioteca';

  @override
  String get profileMessageLabel => 'Mensaje';

  @override
  String get profileShareLabel => 'Compartir perfil';

  @override
  String get profileDeletedAccountName => 'Cuenta eliminada';

  @override
  String get inboxActionReportVanishedAccount => 'Reportar esta cuenta';

  @override
  String get inboxActionBlockVanishedAccount => 'Bloquear esta cuenta';

  @override
  String get inboxActionUnblockVanishedAccount => 'Desbloquear esta cuenta';

  @override
  String get inboxReportedVanishedAccount => 'Reportaste esta cuenta';

  @override
  String get inboxBlockedVanishedAccount => 'Bloqueaste esta cuenta';

  @override
  String get inboxUnblockedVanishedAccount => 'Desbloqueaste esta cuenta';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Esto quita la conversación de tu bandeja de entrada. Si te vuelve a escribir, se inicia una conversación nueva.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Esta cuenta fue eliminada';

  @override
  String get profileUserFallback => 'usuario';

  @override
  String get profileLinkCopied => 'Link del perfil copiado';

  @override
  String get profileSetupEditProfileTitle => 'Editar perfil';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Configura tu perfil antes de añadir una dirección NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Crear perfil';

  @override
  String get profileSetupBackLabel => 'Atrás';

  @override
  String get profileSetupAboutNostr => 'Sobre Nostr';

  @override
  String get profileSetupProfilePublished => '¡Perfil publicado con éxito!';

  @override
  String get profileSetupUnsavedChangesTitle => '¿Guardar los cambios?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Guarda tus cambios antes de salir, o descártalos y sigue.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Guardar cambios';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Descartar cambios';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Seguir editando';

  @override
  String get profileSetupCreateNewProfile => '¿Crear un perfil nuevo?';

  @override
  String get profileSetupNoExistingProfile =>
      'No encontramos un perfil existente en tus relays. Al publicar vas a crear un perfil nuevo. ¿Continuamos?';

  @override
  String get profileSetupPublishButton => 'Publicar';

  @override
  String get profileSetupUsernameTaken =>
      'Ese nombre de usuario se acaba de ocupar. Elegí otro.';

  @override
  String get profileSetupClaimFailed =>
      'No se pudo reservar el nombre de usuario. Probá de nuevo.';

  @override
  String get profileSetupPublishFailed =>
      'No se pudo publicar el perfil. Probá de nuevo.';

  @override
  String get profileSetupNoRelaysConnected =>
      'No se pudo conectar a la red. Verificá tu conexión e intentá de nuevo.';

  @override
  String get profileSetupDisplayNameLabel => 'Nombre a mostrar';

  @override
  String get profileSetupDisplayNameRequired => 'Ingresá un nombre a mostrar';

  @override
  String get profileSetupBioLabel => 'Bio (opcional)';

  @override
  String get profileSetupWebsiteLabel => 'Sitio web (opcional)';

  @override
  String get profileSetupPublicKeyLabel => 'Clave pública (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nombre de usuario (opcional)';

  @override
  String get profileSetupUsernameHelper =>
      'Usa letras, números o guiones. Tu nombre de usuario se convierte en una dirección de divine.video. Usa el nombre visible para espacios o símbolos.';

  @override
  String get profileSetupSaveButton => 'Guardar';

  @override
  String get profileSetupSavingButton => 'Guardando...';

  @override
  String get profileSetupImageUrlTitle => 'Agregar URL de imagen';

  @override
  String get profileSetupImageSelectionFailed =>
      'Falló la selección de imagen. Pegá una URL de imagen abajo.';

  @override
  String get profileSetupImagesTypeGroup => 'imágenes';

  @override
  String get cameraPickErrorPermissionDenied =>
      'El acceso a la cámara está desactivado. Activalo en Ajustes para sacar una foto.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'El acceso a la cámara no está permitido en este dispositivo.';

  @override
  String get cameraPickErrorBusy =>
      'El selector ya está abierto. Cerralo y probá de nuevo.';

  @override
  String get cameraPickErrorGeneric =>
      'No se pudo abrir la cámara. Probá de nuevo.';

  @override
  String get profileSetupGotItButton => 'Entendido';

  @override
  String get profileSetupUploadFailedGeneric =>
      'No se pudo subir la imagen. Probá de nuevo más tarde.';

  @override
  String get profileSetupUploadNetworkError =>
      'Error de red: revisá tu conexión a internet y probá de nuevo.';

  @override
  String get profileSetupUploadAuthError =>
      'Error de autenticación: cerrá sesión y volvé a iniciarla.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Archivo demasiado grande: elegí una imagen más chica (máx 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'No se pudo subir la imagen. Nuestros servidores están temporalmente fuera de servicio. Probá de nuevo en un momento.';

  @override
  String get profileSetupBannerClearButton => 'Quitar banner';

  @override
  String get profileSetupBannerChangeColor => 'Color del banner';

  @override
  String get profileSetupChangeBannerTitle => 'Cambiar banner';

  @override
  String get profileSetupBannerColorPickerTitle =>
      'Cambiar el color del banner';

  @override
  String get profileSetupBannerColorCustom => 'Personalizado';

  @override
  String get profileSetupBannerColorNone => 'Sin color';

  @override
  String get profileSetupBannerColorLime => 'Lima';

  @override
  String get profileSetupBannerColorYellow => 'Amarillo';

  @override
  String get profileSetupBannerColorViolet => 'Violeta';

  @override
  String get profileSetupBannerColorPink => 'Rosa';

  @override
  String get profileSetupBannerColorOrange => 'Naranja';

  @override
  String get profileSetupBannerColorPurple => 'Morado';

  @override
  String get profileSetupAvatarClearButton => 'Quitar la foto';

  @override
  String get profileSetupImageTakePhoto => 'Hacer una foto';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Subir desde el carrete';

  @override
  String get profileSetupImagePasteLink => 'Pegar un enlace de imagen';

  @override
  String get profileSetupEditAvatarLabel => 'Editar foto de perfil';

  @override
  String get profileSetupEditBannerLabel => 'Editar banner';

  @override
  String get profileSetupUsernameChecking => 'Verificando disponibilidad...';

  @override
  String get profileSetupUsernameAvailable => '¡Nombre de usuario disponible!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Ese nombre de usuario ya está ocupado';

  @override
  String get profileSetupUsernameReserved =>
      'Ese nombre de usuario está reservado';

  @override
  String get profileSetupContactSupport => 'Contactar a soporte';

  @override
  String get profileSetupCheckAgain => 'Verificar de nuevo';

  @override
  String get profileSetupUsernameBurned =>
      'Este nombre de usuario ya no está disponible';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Solo se permiten letras, números y guiones';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'El nombre de usuario no puede empezar ni terminar con un guion';

  @override
  String get profileSetupUsernameInvalidLength =>
      'El nombre de usuario tiene que tener entre 3 y 63 caracteres';

  @override
  String get profileSetupUsernameNetworkError =>
      'No pudimos verificar la disponibilidad. Probá de nuevo.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Formato de nombre de usuario inválido';

  @override
  String get profileSetupUsernameCheckFailed =>
      'No se pudo verificar la disponibilidad';

  @override
  String get profileSetupUsernameReservedTitle => 'Nombre de usuario reservado';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'El nombre $username está reservado. Contanos por qué debería ser tuyo.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'Ej: es mi marca, nombre artístico, etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      '¿Ya hablaste con soporte? Tocá \"Verificar de nuevo\" para ver si te lo liberaron.';

  @override
  String get profileSetupSupportRequestSent =>
      '¡Pedido enviado! Te vamos a responder pronto.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'No se pudo abrir el email. Escribinos a: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Enviar pedido';

  @override
  String get profileSetupUseOwnNip05 => 'Usá tu propia dirección NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Dirección NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Formato NIP-05 inválido (ej., nombre@dominio.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Usá el campo de nombre de usuario de arriba para divine.video';

  @override
  String get nostrSettingsNip05Address => 'Dirección NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Usa tu nombre de usuario de divine.video, o apunta tu identificador a una dirección NIP-05 en un dominio que controles.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Guardar NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 guardado';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'No se pudo guardar el NIP-05. Inténtalo de nuevo.';

  @override
  String get profileSetupNip05ConfirmTitle => '¿Usar tu propio NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'El NIP-05 conecta un nombre como tu@tudominio.com con tu identidad en Nostr. Tienes que controlar el dominio y alojar un archivo de verificación en la ruta correcta. Si algo falla, la gente no te encuentra y tu identificador verificado desaparece. Continúa solo si ya lo tienes configurado.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Continuar';

  @override
  String get profileSetupNip05ConfirmCancel => 'Cancelar';

  @override
  String get profileSetupProfilePicturePreview =>
      'Vista previa de la foto de perfil';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine está construida sobre Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' un protocolo abierto y resistente a la censura que permite comunicarse online sin depender de una sola empresa o plataforma. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Cuando te registrás en Divine, obtenés una nueva identidad en Nostr.';

  @override
  String get nostrInfoOwnership =>
      'Nostr te permite ser dueño de tu contenido, tu identidad y tu red social, y usarlos en muchas apps. El resultado: más opciones, menos lock-in, y un internet social más sano y resiliente.';

  @override
  String get nostrInfoLingo => 'Jerga de Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Tu dirección pública en Nostr. Es seguro compartirla y permite que otras personas te encuentren, te sigan o te manden mensajes en cualquier app de Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Tu clave privada y prueba de propiedad. Te da el control total de tu identidad en Nostr, así que ';

  @override
  String get nostrInfoNsecWarning => '¡siempre mantenela en secreto!';

  @override
  String get nostrInfoUsernameLabel => 'Nombre de usuario de Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Un nombre fácil de leer (como @nombre.divine.video) que apunta a tu npub. Hace que tu identidad en Nostr sea más fácil de reconocer y verificar, parecido a una dirección de email.';

  @override
  String get nostrInfoLearnMoreAt => 'Conocé más en ';

  @override
  String get nostrInfoGotIt => '¡Entendido!';

  @override
  String get videoGridRefreshLabel => 'Buscando más videos';

  @override
  String get videoGridOptionsTitle => 'Opciones del video';

  @override
  String get videoGridEditVideo => 'Editar video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Actualizá título, descripción y hashtags';

  @override
  String get videoGridDeleteVideo => 'Eliminar video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Sacá este video de Divine. Es posible que siga apareciendo en otros clientes Nostr.';

  @override
  String get videoGridDeletingContent => 'Eliminando contenido...';

  @override
  String get exploreTabFeatured => 'Destacados';

  @override
  String get exploreTabClassics => 'Clásicos';

  @override
  String get exploreTabNew => 'Nuevos';

  @override
  String get exploreTabPopular => 'Populares';

  @override
  String get exploreTabCategories => 'Categorías';

  @override
  String get exploreTabForYou => 'Para vos';

  @override
  String get exploreTabLists => 'Listas';

  @override
  String get exploreTabIntegratedApps => 'Apps integradas';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Aquí todavía no hay nada. Vuelve pronto.';

  @override
  String get featuredTabLoadFailed => 'No se pudo cargar esta colección.';

  @override
  String get featuredTabRetry => 'Inténtalo de nuevo';

  @override
  String get exploreNoVideosAvailable => 'No hay videos disponibles';

  @override
  String get exploreDiscoverLists => 'Descubrir listas';

  @override
  String get exploreAboutLists => 'Sobre las listas';

  @override
  String get exploreAboutListsDescription =>
      'Las listas te ayudan a organizar y curar contenido en Divine de dos formas:';

  @override
  String get explorePeopleLists => 'Listas de personas';

  @override
  String get explorePeopleListsDescription =>
      'Seguí grupos de creadores y mirá sus últimos videos';

  @override
  String get exploreVideoLists => 'Listas de videos';

  @override
  String get exploreVideoListsDescription =>
      'Armá playlists de tus videos favoritos para verlos después';

  @override
  String get exploreMyLists => 'Mis listas';

  @override
  String get exploreSubscribedLists => 'Listas suscritas';

  @override
  String get exploreErrorLoadingLists =>
      'Error al cargar las listas. Probá de nuevo.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos nuevos',
      one: '1 video nuevo',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos nuevos',
      one: 'video nuevo',
    );
    return 'Cargar $count $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Reproducir video';

  @override
  String get videoPlayerMute => 'Silenciar video';

  @override
  String get videoPlayerUnmute => 'Activar sonido del video';

  @override
  String get videoPlayerTapHint =>
      'Toca para reproducir o pausar. Toca dos veces para dar me gusta.';

  @override
  String get videoSettingsMenuOpen => 'Abrir configuración de reproducción';

  @override
  String get videoSettingsMenuClose => 'Cerrar configuración de reproducción';

  @override
  String get videoSettingsCaptionsEnable => 'Activar subtítulos';

  @override
  String get videoSettingsCaptionsDisable => 'Desactivar subtítulos';

  @override
  String get videoSettingsAutoAdvanceOn => 'Avance automático activado';

  @override
  String get videoSettingsAutoAdvanceOff => 'Avance automático desactivado';

  @override
  String get videoSettingsCaptionsOn => 'Subtítulos activados';

  @override
  String get videoSettingsCaptionsOff => 'Subtítulos desactivados';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Subtítulos activados para este video';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Subtítulos desactivados para este video';

  @override
  String get contentWarningLabel => 'Advertencia de contenido';

  @override
  String get contentWarningNudity => 'Desnudez';

  @override
  String get contentWarningSexualContent => 'Contenido sexual';

  @override
  String get contentWarningPornography => 'Pornografía';

  @override
  String get contentWarningGraphicMedia => 'Contenido gráfico';

  @override
  String get contentWarningViolence => 'Violencia';

  @override
  String get contentWarningSelfHarm => 'Autolesiones';

  @override
  String get contentWarningDrugUse => 'Uso de drogas';

  @override
  String get contentWarningAlcohol => 'Alcohol';

  @override
  String get contentWarningTobacco => 'Tabaco';

  @override
  String get contentWarningGambling => 'Apuestas';

  @override
  String get contentWarningProfanity => 'Lenguaje fuerte';

  @override
  String get contentWarningFlashingLights => 'Luces intermitentes';

  @override
  String get contentWarningAiGenerated => 'Generado por IA';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Contenido sensible';

  @override
  String get contentWarningDescNudity => 'Contiene desnudez o desnudez parcial';

  @override
  String get contentWarningDescSexual => 'Contiene contenido sexual';

  @override
  String get contentWarningDescPorn =>
      'Contiene contenido pornográfico explícito';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contiene imágenes gráficas o perturbadoras';

  @override
  String get contentWarningDescViolence => 'Contiene contenido violento';

  @override
  String get contentWarningDescSelfHarm =>
      'Contiene referencias a autolesiones';

  @override
  String get contentWarningDescDrugs =>
      'Contiene contenido relacionado con drogas';

  @override
  String get contentWarningDescAlcohol =>
      'Contiene contenido relacionado con el alcohol';

  @override
  String get contentWarningDescTobacco =>
      'Contiene contenido relacionado con el tabaco';

  @override
  String get contentWarningDescGambling =>
      'Contiene contenido relacionado con apuestas';

  @override
  String get contentWarningDescProfanity => 'Contiene lenguaje fuerte';

  @override
  String get contentWarningDescFlashingLights =>
      'Contiene luces intermitentes (advertencia de fotosensibilidad)';

  @override
  String get contentWarningDescAiGenerated =>
      'Este contenido fue generado por IA';

  @override
  String get contentWarningDescSpoiler => 'Contiene spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'El creador lo marcó como sensible';

  @override
  String get contentWarningDescDefault => 'El creador marcó este contenido';

  @override
  String get contentWarningDetailsTitle => 'Advertencias de contenido';

  @override
  String get contentWarningDetailsSubtitle =>
      'El creador aplicó estas etiquetas:';

  @override
  String get contentWarningManageFilters => 'Gestionar filtros de contenido';

  @override
  String get contentWarningViewAnyway => 'Ver igual';

  @override
  String get contentWarningReportContentTooltip => 'Reportar contenido';

  @override
  String get contentWarningBlockUserTooltip => 'Bloquear usuario';

  @override
  String get contentWarningBlockedTitle => 'Contenido bloqueado';

  @override
  String get contentWarningBlockedPolicy =>
      'Este contenido fue bloqueado por violar las políticas.';

  @override
  String get contentWarningNoticeTitle => 'Aviso de contenido';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Contenido potencialmente dañino';

  @override
  String get contentWarningView => 'Ver';

  @override
  String get contentWarningReportAction => 'Reportar';

  @override
  String get contentWarningHideAllLikeThis =>
      'Ocultar todo el contenido como este';

  @override
  String get contentWarningNoFilterYet =>
      'Todavía no hay un filtro guardado para esta advertencia.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Vamos a ocultar publicaciones como esta de ahora en más.';

  @override
  String get communitySuggestTitle => 'Ayudá a clasificar esto';

  @override
  String get communitySuggestSubtitle =>
      '¿Falta una advertencia de contenido? Tu sugerencia es pública, está firmada y no se puede retirar.';

  @override
  String get communitySuggestSubmit => 'Sugerir';

  @override
  String get communitySuggestSuccess => 'Gracias. Tu sugerencia fue enviada.';

  @override
  String get communitySuggestFailure =>
      'No se pudo enviar tu sugerencia. Probá de nuevo.';

  @override
  String get communitySuggestAlready => 'Ya sugeriste esto';

  @override
  String get communitySuggestActionLabel => 'Clasificar';

  @override
  String get videoErrorNotFound => 'Video no encontrado';

  @override
  String get videoErrorPlayback => 'Error de reproducción';

  @override
  String get videoErrorAgeRestricted => 'Contenido con restricción de edad';

  @override
  String get videoErrorUnavailable => 'Video no disponible';

  @override
  String get videoErrorUnavailableBody =>
      'Este video no está disponible ahora mismo.';

  @override
  String get videoErrorRetry => 'Reintentar';

  @override
  String get videoErrorContentRestricted => 'Contenido restringido';

  @override
  String get videoErrorContentRestrictedBody =>
      'Este video se eliminó por incumplir nuestras reglas de contenido.';

  @override
  String get videoErrorVerifyAgeBody => 'Verificá tu edad para ver este video.';

  @override
  String get videoErrorSkip => 'Saltar';

  @override
  String get videoErrorVerifyAgeButton => 'Verificar edad';

  @override
  String get videoErrorVerifyAgeFailed =>
      'No pudimos verificar tu edad. Inténtalo de nuevo.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Se agotó el tiempo de verificación. Revisa tu conexión o vuelve a intentarlo en un momento.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'El contenido para adultos está desactivado';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Activalo en tus filtros de contenido para ver este video.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Abrir filtros de contenido';

  @override
  String get videoDetailLoadError => 'Error al cargar el video';

  @override
  String get videoDetailLoadErrorBody =>
      'Algo se torció por el camino. Inténtalo otra vez.';

  @override
  String get videoDetailNotFoundBody =>
      'Puede que se haya borrado, que esté fuera de nuestro alcance o que lo oculten tus ajustes.';

  @override
  String get databaseCorruptionTitle => 'Tus datos locales se estropearon';

  @override
  String get databaseCorruptionBody =>
      'Cierra Divine y ábrelo de nuevo: lo arreglamos automáticamente. Guardamos los borradores y clips que podamos, lo demás se recarga.';

  @override
  String get databaseCorruptionCloseButton => 'Cerrar Divine';

  @override
  String get videoDetailContextTitle => 'Video compartido';

  @override
  String get videoDetailCloseSemanticLabel => 'Cerrar reproductor de video';

  @override
  String get videoFollowButtonFollow => 'Seguir';

  @override
  String get audioAttributionOriginalSound => 'Sonido original';

  @override
  String get audioAttributionUnavailableSound => 'Sonido no disponible';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirado en @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirado en @$creatorName';
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
      other: '$count colaboradores',
      one: '1 colaborador',
    );
    return '$_temp0. Tocá para ver el perfil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Pendiente';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Colaborador pendiente';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending pendiente(s))';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Toca para ver el perfil.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Tocá para ver videos con este hashtag.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Compartir video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Publicación compartida con $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Publicación compartida con $count personas',
      one: 'Publicación compartida con $count persona',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'No se pudo enviar el video';

  @override
  String get shareAddedToBookmarks => 'Agregado a marcadores';

  @override
  String get shareRemovedFromBookmarks => 'Quitado de marcadores';

  @override
  String get shareFailedToAddBookmark => 'No se pudo agregar el marcador';

  @override
  String get shareFailedToRemoveBookmark => 'No se pudo quitar el marcador';

  @override
  String get shareActionFailed => 'Falló la acción';

  @override
  String get shareWithTitle => 'Compartir con';

  @override
  String get shareFindPeople => 'Buscar personas';

  @override
  String get shareFindPeopleMultiline => 'Buscar\npersonas';

  @override
  String get shareSent => 'Enviado';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name seleccionado';
  }

  @override
  String get shareMessageHint => 'Agregá un mensaje (opcional)...';

  @override
  String get videoActionUnlike => 'Sacar me gusta';

  @override
  String get videoActionLike => 'Dar me gusta';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Me gusta';

  @override
  String get videoActionReplyLabel => 'Responder';

  @override
  String get videoActionRepostLabel => 'Repost';

  @override
  String get videoActionShareLabel => 'Compartir';

  @override
  String get videoActionReportLabel => 'Reportar';

  @override
  String get videoActionReport => 'Reportar video';

  @override
  String get videoActionEditLabel => 'Editar';

  @override
  String get videoActionEdit => 'Editar video';

  @override
  String get videoActionAboutLabel => 'Acerca de';

  @override
  String get videoActionEnableAutoAdvance => 'Activar avance automático';

  @override
  String get videoActionDisableAutoAdvance => 'Desactivar avance automático';

  @override
  String get videoActionRemoveRepost => 'Quitar repost';

  @override
  String get videoActionRepost => 'Repostear video';

  @override
  String get videoActionViewComments => 'Ver comentarios';

  @override
  String get videoActionMoreOptions => 'Más opciones';

  @override
  String get videoEngagementLikersTitle => 'Le gustó a';

  @override
  String get videoEngagementRepostersTitle => 'Reposteado por';

  @override
  String get videoEngagementLikersEmpty => 'Aún no hay me gusta';

  @override
  String get videoEngagementRepostersEmpty => 'Aún no hay reposts';

  @override
  String get videoEngagementLoadFailed => 'No se pudo cargar la lista';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Abrir detalles del video';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Abrir detalles del video';

  @override
  String get videoOverlayCommentBarHint => 'Agregar comentario...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Agregar un comentario';

  @override
  String get videoOverlayCommentBarSendLabel => 'Enviar comentario';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Comentario publicado';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'No se pudo publicar el comentario';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bucles',
      one: 'bucle',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'No es de Divine';

  @override
  String get metadataBadgeHumanMade => 'Hecho por humanos';

  @override
  String get metadataSoundsLabel => 'Sonidos';

  @override
  String get metadataOriginalSound => 'Sonido original';

  @override
  String get metadataVerificationLabel => 'Verificación';

  @override
  String get metadataDeviceAttestation => 'Atestación de dispositivo';

  @override
  String get metadataPgpSignature => 'Firma PGP';

  @override
  String get metadataC2paCredentials => 'Credenciales de contenido C2PA';

  @override
  String get metadataProofManifest => 'Manifiesto de prueba';

  @override
  String get metadataVerificationInfoTooltip =>
      '¿Qué significan estas comprobaciones?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle =>
      'Qué significan estas comprobaciones';

  @override
  String get metadataVerificationInfoIntro =>
      'Estas señales vienen de la cámara y del propio archivo de vídeo. Cuantas más tenga un vídeo, más podemos demostrar sobre su origen.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'El sistema operativo del teléfono respondió por la app que grabó esto. Buena prueba de que salió de una cámara y no de un archivo que alguien subió.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'El vídeo se firmó criptográficamente en el momento de la captura. Si después cambia un solo fotograma, la firma se rompe.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Un registro de procedencia con estándar del sector que viaja dentro del archivo, para que también puedan comprobarlo apps distintas de Divine.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'El registro completo de ProofMode: huella del archivo, marca de tiempo y contexto de captura, junto al vídeo.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Que falte una comprobación no hace falso un vídeo. Los clips antiguos y las subidas nunca la tuvieron: solo significa que no podemos demostrar esa parte.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Más información en $url';
  }

  @override
  String get metadataCreatorLabel => 'Creador';

  @override
  String get metadataCollaboratorsLabel => 'Colaboradores';

  @override
  String get metadataInspiredByLabel => 'Inspirado en';

  @override
  String get metadataRepostedByLabel => 'Reposteado por';

  @override
  String metadataMoreReposters(int count) {
    return '+$count más';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'Me gusta';

  @override
  String get metadataCommentsLabel => 'Comentarios';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get metadataVineStatsLabel => 'En Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loops · $likes me gusta · $comments comentarios · $reposts reposts';
  }

  @override
  String get metadataDivineStatsLabel => 'En Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views vistas · $likes me gusta · $comments comentarios · $reposts reposts';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publicado el $date';
  }

  @override
  String get devOptionsTitle => 'Opciones de desarrollador';

  @override
  String get devOptionsDisableDeveloperMode =>
      'Desactivar modo de desarrollador';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Ocultar opciones de desarrollador de los ajustes';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Modo de desarrollador desactivado';

  @override
  String get devOptionsShorebirdTitle => 'Parches de Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Parche activo';

  @override
  String get devOptionsShorebirdNoPatch => 'No hay ningún parche instalado';

  @override
  String get devOptionsShorebirdUnavailable =>
      'No disponible en esta compilación';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Los parches solo funcionan en una compilación creada con shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Leyendo el estado del parche…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Aún no se comprobó el canal de pruebas.';

  @override
  String get devOptionsShorebirdCheck => 'Comprobar el canal de pruebas';

  @override
  String get devOptionsShorebirdApply => 'Aplicar parche de pruebas';

  @override
  String get devOptionsShorebirdUseStable =>
      'Volver a las actualizaciones estables';

  @override
  String get devOptionsShorebirdChecking => 'Comprobando el canal de pruebas…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Hay un parche de pruebas listo para aplicar.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'No hay ningún parche de pruebas para esta versión.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Descargado. Reinicia la app para cargarlo.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Hay una reversión lista. Reinicia para volver a la versión base.';

  @override
  String get devOptionsShorebirdApplying => 'Descargando e instalando…';

  @override
  String get devOptionsShorebirdApplied =>
      'Instalado. Reinicia la app para cargarlo.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'No se instaló nada. Comprueba el canal de pruebas e inténtalo de nuevo.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Seleccionando el canal estable…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Canal estable seleccionado. Reinicia la app para buscar un parche estable.';

  @override
  String get devOptionsShorebirdFailure =>
      'No funcionó. Consulta los registros para ver los detalles.';

  @override
  String get devOptionsPageLoadTimes => 'Tiempos de carga de pantallas';

  @override
  String get devOptionsNoPageLoads =>
      'Todavía no se registraron cargas de pantalla.\nNavegá por la app para ver los tiempos.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visible: ${visibleMs}ms  |  Datos: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Pantallas más lentas';

  @override
  String get devOptionsVideoPlaybackFormat =>
      'Formato de reproducción de video';

  @override
  String get devOptionsSwitchEnvironmentTitle => '¿Cambiar de entorno?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '¿Cambiar a $envName?\n\nEsto va a limpiar la caché de videos y a reconectarse al nuevo relay.';
  }

  @override
  String get devOptionsCancel => 'Cancelar';

  @override
  String get devOptionsSwitch => 'Cambiar';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Cambiado a $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Cambiado a $formatName — caché limpiada';
  }

  @override
  String get featureFlagTitle => 'Feature flags';

  @override
  String get featureFlagResetAllTooltip =>
      'Restablecer todas las flags a los valores predeterminados';

  @override
  String get featureFlagError => 'Error';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine es un sistema abierto: vos controlás tus conexiones';

  @override
  String get relaySettingsInfoDescription =>
      'Estos relays distribuyen tu contenido por la red descentralizada de Nostr. Podés agregar o quitar relays cuando quieras.';

  @override
  String get relaySettingsLearnMoreNostr => 'Conocé más sobre Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Buscá relays públicos en nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'La app no funciona';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine necesita al menos un relay para cargar videos, publicar contenido y sincronizar datos.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Restaurar el relay predeterminado';

  @override
  String get relaySettingsAddCustomRelay => 'Agregar relay personalizado';

  @override
  String get relaySettingsAddRelay => 'Agregar relay';

  @override
  String get relaySettingsRetry => 'Reintentar';

  @override
  String get relaySettingsNoStats => 'Todavía no hay estadísticas disponibles';

  @override
  String get relaySettingsConnection => 'Conexión';

  @override
  String get relaySettingsConnected => 'Conectado';

  @override
  String get relaySettingsDisconnected => 'Desconectado';

  @override
  String get relaySettingsSessionDuration => 'Duración de la sesión';

  @override
  String get relaySettingsLastConnected => 'Última conexión';

  @override
  String get relaySettingsDisconnectedLabel => 'Desconectado';

  @override
  String get relaySettingsReason => 'Motivo';

  @override
  String get relaySettingsActiveSubscriptions => 'Suscripciones activas';

  @override
  String get relaySettingsTotalSubscriptions => 'Suscripciones totales';

  @override
  String get relaySettingsEventsReceived => 'Eventos recibidos';

  @override
  String get relaySettingsEventsSent => 'Eventos enviados';

  @override
  String get relaySettingsRequestsThisSession => 'Pedidos en esta sesión';

  @override
  String get relaySettingsFailedRequests => 'Pedidos fallidos';

  @override
  String get relaySettingsLoadingRelayInfo => 'Cargando info del relay...';

  @override
  String get relaySettingsAboutRelay => 'Sobre el relay';

  @override
  String get relaySettingsSupportedNips => 'NIPs soportados';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Ver sitio web';

  @override
  String get relaySettingsRemoveRelayTitle => '¿Quitar relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return '¿Seguro que querés quitar este relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      '¿Quitar el relay de Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Quitar el relay de Divine empeorará la experiencia en la app. Los videos, las publicaciones y la sincronización pueden ser menos fiables. Esto solo deberían hacerlo usuarios con experiencia en Nostr.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Quitar relay';

  @override
  String get relaySettingsCancel => 'Cancelar';

  @override
  String get relaySettingsRemove => 'Quitar';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay quitado: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'No se pudo quitar el relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forzando la reconexión al relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '¡Conectado a $count relay(s)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'No se pudo conectar a los relays. Revisá tu conexión de red.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Guardado en este dispositivo. Lo sincronizaremos con tu cuenta cuando la publicación vuelva a funcionar.';

  @override
  String get relaySettingsAddRelayTitle => 'Agregar relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Ingresá la URL WebSocket del relay que querés agregar:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Mirá relays públicos en nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Agregar';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay agregado: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'No se pudo agregar el relay. Revisá la URL y probá de nuevo.';

  @override
  String get relaySettingsInvalidUrl =>
      'La URL del relay tiene que empezar con wss:// o ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'La URL del relay tiene que usar wss:// (ws:// solo se permite para localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay predeterminado restaurado: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'No se pudo restaurar el relay predeterminado. Revisá tu conexión de red.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'No se pudo abrir el navegador';

  @override
  String get relaySettingsFailedToOpenLink => 'No se pudo abrir el link';

  @override
  String get relaySettingsExternalRelay => 'Relay externo';

  @override
  String get relaySettingsNotConnected => 'Sin conexión';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Desconectado hace $duration';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count suscripciones';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count eventos';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'hace $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine usa el protocolo Nostr para publicar de forma descentralizada. Tu contenido vive en los relays que vos elegís, y tus claves son tu identidad.';

  @override
  String get nostrSettingsSectionNetwork => 'Red';

  @override
  String get nostrSettingsSectionAccount => 'Cuenta';

  @override
  String get nostrSettingsSectionDangerZone => 'Zona de peligro';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Gestioná las conexiones a relays de Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnóstico de relays';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Depurá la conectividad de los relays y problemas de red';

  @override
  String get nostrSettingsMediaServers => 'Servidores de medios';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configurá los servidores de subida de Blossom';

  @override
  String get settingsDeveloperOptions => 'Opciones de desarrollador';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Selector de entorno y ajustes de depuración';

  @override
  String get nostrSettingsKeyManagement => 'Gestión de claves';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exportá, respaldá y restaurá tus claves de Nostr';

  @override
  String get nostrSettingsClientAttribution => 'Atribución del cliente';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Incluí una etiqueta de cliente Divine en los eventos que publicás para que otras apps de Nostr puedan atribuirlos correctamente. Sin eso, los reportes que enviás pesan menos cuando nuestros moderadores los revisan.';

  @override
  String get nostrSettingsMoveAccount => 'Mover tu cuenta';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Descarga tu archivo y mueve tus publicaciones y videos a otro relay o servidor de medios.';

  @override
  String get nostrSettingsRemoveKeys => 'Quitar claves del dispositivo';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Eliminá tu clave privada solo de este dispositivo. Tu contenido sigue en los relays, pero vas a necesitar tu respaldo de nsec para volver a entrar a tu cuenta.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'No se pudo quitar esta cuenta de este dispositivo. Probá de nuevo.';

  @override
  String get nostrSettingsDeleteAccount => 'Eliminar cuenta y datos';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Envía solicitudes de eliminación de tu contenido y cierra tu sesión en este dispositivo. Los relays, clientes, índices de búsqueda y otros dispositivos con la sesión iniciada pueden conservar copias.';

  @override
  String get relayDiagnosticTitle => 'Diagnóstico de relays';

  @override
  String get relayDiagnosticRefreshTooltip => 'Actualizar diagnóstico';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Última actualización: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Estado del relay';

  @override
  String get relayDiagnosticInitialized => 'Inicializado';

  @override
  String get relayDiagnosticReady => 'Listo';

  @override
  String get relayDiagnosticNotInitialized => 'No inicializado';

  @override
  String get relayDiagnosticDatabaseEvents => 'Eventos en la base de datos';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Suscripciones activas';

  @override
  String get relayDiagnosticExternalRelays => 'Relays externos';

  @override
  String get relayDiagnosticConfigured => 'Configurados';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Conectados';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Eventos de video';

  @override
  String get relayDiagnosticHomeFeed => 'Feed principal';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count videos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Descubrimiento';

  @override
  String get relayDiagnosticLoading => 'Cargando';

  @override
  String get relayDiagnosticYes => 'Sí';

  @override
  String get relayDiagnosticNo => 'No';

  @override
  String get relayDiagnosticTestDirectQuery => 'Probar consulta directa';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Conectividad de red';

  @override
  String get relayDiagnosticRunNetworkTest => 'Ejecutar test de red';

  @override
  String get relayDiagnosticBlossomServer => 'Servidor Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Probar todos los endpoints';

  @override
  String get relayDiagnosticStatus => 'Estado';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Error';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL base';

  @override
  String get relayDiagnosticSummary => 'Resumen';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (promedio ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Volver a probar todo';

  @override
  String get relayDiagnosticRetrying => 'Reintentando...';

  @override
  String get relayDiagnosticRetryConnection => 'Reintentar conexión';

  @override
  String get relayDiagnosticTroubleshooting => 'Solución de problemas';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Estado verde = conectado y funcionando\n• Estado rojo = falló la conexión\n• Si falla el test de red, revisá la conexión a internet\n• Si los relays están configurados pero no conectados, tocá \"Reintentar conexión\"\n• Sacá una captura de esta pantalla para debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      '¡Todos los endpoints REST están bien!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Algunos endpoints REST fallaron: ver los detalles arriba';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Se encontraron $count eventos de video en la base de datos';
  }

  @override
  String get relayDiagnosticQueryFailed => 'Falló la consulta. Probá de nuevo.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '¡Conectado a $count relay(s)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'No se pudo conectar a ningún relay';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Falló el reintento de conexión. Probá de nuevo.';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Conectado y autenticado';

  @override
  String get relayDiagnosticConnectedOnly => 'Conectado';

  @override
  String get relayDiagnosticNotConnected => 'No conectado';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'No hay relays configurados';

  @override
  String get relayDiagnosticFailed => 'Falló';

  @override
  String get notificationSettingsTitle => 'Notificaciones';

  @override
  String get notificationSettingsResetTooltip =>
      'Restablecer a valores predeterminados';

  @override
  String get notificationSettingsTypes => 'Tipos de notificación';

  @override
  String get notificationSettingsLikes => 'Me gusta';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Cuando alguien le da me gusta a tus videos';

  @override
  String get notificationSettingsComments => 'Comentarios';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Cuando alguien comenta tus videos';

  @override
  String get notificationSettingsFollows => 'Seguidores';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Cuando alguien empieza a seguirte';

  @override
  String get notificationSettingsMentions => 'Menciones';

  @override
  String get notificationSettingsMentionsSubtitle => 'Cuando te mencionan';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Cuando alguien repostea tus videos';

  @override
  String get notificationSettingsNewPosts => 'Nuevos vines';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Cuando alguien que sigues publica';

  @override
  String get notificationSettingsActions => 'Acciones';

  @override
  String get notificationSettingsMarkAllAsRead => 'Marcar todas como leídas';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Marcá todas las notificaciones como leídas';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Todas las notificaciones marcadas como leídas';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'No se pudieron marcar todas como leídas';

  @override
  String get notificationSettingsResetToDefaults =>
      'Ajustes restablecidos a los valores predeterminados';

  @override
  String get notificationSettingsAbout => 'Sobre las notificaciones';

  @override
  String get notificationSettingsAboutDescription =>
      'Las notificaciones funcionan con el protocolo Nostr. Las actualizaciones en tiempo real dependen de tu conexión con los relays de Nostr. Algunas notificaciones pueden demorarse.';

  @override
  String get safetySettingsWhatYouSee => 'LO QUE VES';

  @override
  String get safetySettingsWhatYouPublish => 'LO QUE PUBLICÁS';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Mostrar solo videos alojados en Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ocultá videos alojados en otros hosts de medios';

  @override
  String get safetySettingsModeration => 'MODERACIÓN';

  @override
  String get safetySettingsBlockedUsers => 'USUARIOS BLOQUEADOS';

  @override
  String get safetySettingsAgeVerification => 'VERIFICACIÓN DE EDAD';

  @override
  String get safetySettingsAgeConfirmation =>
      'Confirmo que tengo 18 años o más';

  @override
  String get safetySettingsAgeRequired =>
      'Necesario para ver contenido para adultos';

  @override
  String get safetySettingsAgeLockedForMinor => 'Bloqueado para tu cuenta';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Servicio oficial de moderación (activado por defecto)';

  @override
  String get safetySettingsPeopleIFollow => 'Personas que sigo';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Suscribite a las etiquetas de las personas que seguís';

  @override
  String get safetySettingsAddCustomLabeler =>
      'Agregar etiquetador personalizado';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Ingresá un npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Agregar etiquetador personalizado';

  @override
  String get safetySettingsRemoveLabeler => 'Quitar etiquetador';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Ingresá una dirección npub';

  @override
  String get safetySettingsNoBlockedUsers => 'No hay usuarios bloqueados';

  @override
  String get safetySettingsUnblock => 'Desbloquear';

  @override
  String get safetySettingsUserUnblocked => 'Usuario desbloqueado';

  @override
  String get safetySettingsCancel => 'Cancelar';

  @override
  String get safetySettingsAdd => 'Agregar';

  @override
  String get analyticsTitle => 'Analíticas del creador';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnóstico';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Alternar diagnóstico';

  @override
  String get analyticsRetry => 'Reintentar';

  @override
  String get analyticsUnableToLoad => 'No se pueden cargar las analíticas.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Iniciá sesión para ver las analíticas del creador.';

  @override
  String get analyticsViewDataUnavailable =>
      'Las visualizaciones no están disponibles en el relay para estas publicaciones. Los me gusta, comentarios y reposts siguen siendo precisos.';

  @override
  String get analyticsViewDataTitle => 'Datos de visualizaciones';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Actualizado $time • Los puntajes usan me gusta, comentarios, reposts y visualizaciones/loops de Funnelcake cuando están disponibles.';
  }

  @override
  String get analyticsVideos => 'Videos';

  @override
  String get analyticsViews => 'Visualizaciones';

  @override
  String get analyticsInteractions => 'Interacciones';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Seguidores';

  @override
  String get analyticsAvgPerPost => 'Prom/post';

  @override
  String get analyticsInteractionMix => 'Mezcla de interacciones';

  @override
  String get analyticsLikes => 'Me gusta';

  @override
  String get analyticsComments => 'Comentarios';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Destacados de rendimiento';

  @override
  String get analyticsMostViewed => 'Más visto';

  @override
  String get analyticsMostDiscussed => 'Más comentado';

  @override
  String get analyticsMostReposted => 'Más reposteado';

  @override
  String get analyticsNoVideosYet => 'Todavía no hay videos';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Datos de visualizaciones no disponibles';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count visualizaciones';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count comentarios';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Contenido top';

  @override
  String get analyticsPublishPrompt =>
      'Publicá algunos videos para ver los rankings.';

  @override
  String get analyticsEngagementRateExplainer =>
      'El % del lado derecho = tasa de engagement (interacciones dividido visualizaciones).';

  @override
  String get analyticsEngagementRateNoViews =>
      'La tasa de engagement necesita datos de visualizaciones; los valores aparecen como N/A hasta que haya datos.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'visualizaciones no disponibles';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interacciones';
  }

  @override
  String get analyticsPostAnalytics => 'Analíticas de la publicación';

  @override
  String get analyticsOpenPost => 'Abrir publicación';

  @override
  String get analyticsRecentDailyInteractions =>
      'Interacciones diarias recientes';

  @override
  String get analyticsNoActivityYet =>
      'Todavía no hay actividad en este rango.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interacciones = me gusta + comentarios + reposts por fecha de publicación.';

  @override
  String get analyticsDailyBarExplainer =>
      'El largo de la barra es relativo a tu mejor día en esta ventana.';

  @override
  String get analyticsAudienceSnapshot => 'Instantánea de audiencia';

  @override
  String analyticsFollowersCount(String count) {
    return 'Seguidores: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Siguiendo: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Los desgloses de fuente/geografía/horario de audiencia van a aparecer cuando Funnelcake sume esos endpoints.';

  @override
  String get analyticsRetention => 'Retención';

  @override
  String get analyticsRetentionWithViews =>
      'La curva de retención y el desglose de tiempo de visualización van a aparecer cuando Funnelcake devuelva datos por segundo/intervalo.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Los datos de retención no están disponibles hasta que Funnelcake devuelva analíticas de visualizaciones y tiempo de visualización.';

  @override
  String get analyticsDiagnostics => 'Diagnóstico';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Videos totales: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Con visualizaciones: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Sin visualizaciones: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hidratado (masivo): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hidratado (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Fuentes: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Usar datos de prueba';

  @override
  String get analyticsNa => 'N/D';

  @override
  String get authCreateNewAccount => 'Crear una cuenta nueva en Divine';

  @override
  String get authCreateNewAccountShort => 'Crear cuenta nueva';

  @override
  String get authSignInDifferentAccount => 'Iniciar sesión con otra cuenta';

  @override
  String get authUseAnotherAccount => 'Usar otra cuenta';

  @override
  String authContinueAs(String displayName) {
    return 'Continuar como $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Tus borradores y clips están guardados en esta cuenta';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Iniciar sesión aquí ocultará esos borradores y clips';

  @override
  String get authTermsPrefix =>
      'Al elegir una opción abajo, confirmas que tienes al menos 16 años (o que completaste la ';

  @override
  String get authTermsAgeAuthorizationCta => 'autorización de edad de Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') y aceptas los ';

  @override
  String get authTermsOfService => 'Términos del Servicio';

  @override
  String get authPrivacyPolicy => 'Política de Privacidad';

  @override
  String get authTermsAnd => ', y los ';

  @override
  String get authSafetyStandards => 'Estándares de Seguridad';

  @override
  String get authAmberNotInstalled => 'La app Amber no está instalada';

  @override
  String get authAmberConnectionFailed => 'No se pudo conectar con Amber';

  @override
  String get authPasswordResetSent =>
      'Si existe una cuenta con ese email, te enviamos un link para restablecer la contraseña.';

  @override
  String get authSignInTitle => 'Iniciar sesión';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authConfirmPasswordLabel => 'Confirmar contraseña';

  @override
  String get authEmailRequired => 'El email es obligatorio';

  @override
  String get authEmailInvalid => 'Introduce un email válido';

  @override
  String get authPasswordRequired => 'La contraseña es obligatoria';

  @override
  String get authConfirmPasswordRequired => 'Confirma tu contraseña';

  @override
  String get authPasswordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authImportNostrKey => 'Importar clave de Nostr';

  @override
  String get authConnectSignerApp => 'Conectar con una app firmante';

  @override
  String get authSignInWithAmber => 'Iniciar sesión con Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Iniciar sesión con extensión del navegador';

  @override
  String get authNip07ConnectionFailed =>
      'No se pudo conectar con tu extensión del navegador.';

  @override
  String get authNip07ExtensionNotFound =>
      'No se encontró ninguna extensión del navegador. Instalá Alby, nos2x u otra extensión compatible con NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opciones para iniciar sesión';

  @override
  String get authInfoEmailPasswordTitle => 'Email y contraseña';

  @override
  String get authInfoEmailPasswordDescription =>
      'Iniciá sesión con tu cuenta de Divine. Si te registraste con email y contraseña, usalos acá.';

  @override
  String get authInfoImportNostrKeyDescription =>
      '¿Ya tenés una identidad en Nostr? Importá tu clave privada nsec desde otro cliente.';

  @override
  String get authInfoSignerAppTitle => 'App firmante';

  @override
  String get authInfoSignerAppDescription =>
      'Conectate usando un firmante remoto compatible con NIP-46 como nsecBunker para mayor seguridad de tus claves.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Usá la app firmante Amber en Android para manejar tus claves de Nostr de forma segura.';

  @override
  String get authInfoBrowserExtensionTitle => 'Extensión del navegador';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Iniciá sesión con una extensión del navegador NIP-07 como Alby o nos2x. Tus claves se quedan en la extensión — Divine nunca las ve.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Correo o contraseña incorrectos. Inténtalo de nuevo.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Verifica tu correo antes de iniciar sesión: revisa tu bandeja de entrada para ver el enlace.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Eso no parece una dirección de correo válida.';

  @override
  String get authSignInErrorNetwork =>
      'No se puede conectar con el servidor. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get authSignInErrorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get authSignInOptionsHintPrefix =>
      '¿No sabes cómo entraste la última vez? ';

  @override
  String get authSignInOptionsHintCta =>
      'Ver todas las opciones de inicio de sesión';

  @override
  String get authCreateAccountTitle => 'Crear cuenta';

  @override
  String get authBackToInviteCode => 'Volver al código de invitación';

  @override
  String get authUseDivineNoBackup => 'Usar Divine sin respaldo';

  @override
  String get authSkipConfirmTitle => 'Una última cosa...';

  @override
  String get authSkipConfirmKeyCreated =>
      '¡Estás adentro! Vamos a crear una clave segura para tu cuenta de Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Sin un email, tu clave es la única forma que tiene Divine de saber que esta cuenta es tuya.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Podés acceder a tu clave dentro de la app, pero si no sos muy técnico, te recomendamos agregar un email y contraseña ahora. Eso hace más fácil iniciar sesión y recuperar tu cuenta si perdés o reseteás este dispositivo.';

  @override
  String get authAddEmailPassword => 'Agregar email y contraseña';

  @override
  String get authUseThisDeviceOnly => 'Usar solo este dispositivo';

  @override
  String get authCompleteRegistration => 'Completá tu registro';

  @override
  String get authVerifying => 'Verificando...';

  @override
  String get authVerificationLinkSent =>
      'Te mandamos un link de verificación a:';

  @override
  String get authClickVerificationLink =>
      'Tocá el link en tu email para\ncompletar el registro.';

  @override
  String get authPleaseWaitVerifying =>
      'Esperá mientras verificamos tu email...';

  @override
  String get authWaitingForVerification => 'Esperando la verificación';

  @override
  String get authOpenEmailApp => 'Abrir la app de email';

  @override
  String get authVerificationPinPrompt =>
      'O ingresá el código de 6 dígitos de tu email';

  @override
  String get authVerificationPinFieldLabel => 'Código de 6 dígitos';

  @override
  String get authVerificationPinSubmit => 'Verificar código';

  @override
  String get authVerificationResendPrompt => '¿No te llegó?';

  @override
  String get authVerificationResend => 'Reenviar';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Reenviar en $time';
  }

  @override
  String get authVerificationResendFailed =>
      'No pudimos reenviar el email. Probá de nuevo.';

  @override
  String get authVerificationResendExpired =>
      'Ese registro caducó. Empieza de nuevo para conseguir un código fresco.';

  @override
  String get authVerificationResendUnavailable =>
      'Ahora mismo no se puede reenviar. Usa el código de 6 dígitos del correo que ya te enviamos.';

  @override
  String get authVerificationPollingStopped =>
      'Dejamos de comprobarlo por ti. Escribe el código de 6 dígitos de tu correo para terminar de entrar.';

  @override
  String get authWelcomeToDivine => '¡Bienvenido a Divine!';

  @override
  String get authEmailVerified => 'Tu email fue verificado.';

  @override
  String get authSigningYouIn => 'Iniciando sesión';

  @override
  String get authErrorTitle => 'Uy.';

  @override
  String get authVerificationFailed =>
      'No pudimos verificar tu email.\nProbá de nuevo.';

  @override
  String get authStartOver => 'Empezar de nuevo';

  @override
  String get authEmailVerifiedLogin =>
      '¡Email verificado! Iniciá sesión para continuar.';

  @override
  String get authVerificationLinkExpired =>
      'Este link de verificación ya no es válido.';

  @override
  String get authVerificationConnectionError =>
      'No se pudo verificar el email. Revisá tu conexión y probá de nuevo.';

  @override
  String get authWaitlistConfirmTitle => '¡Estás adentro!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Te vamos a mandar novedades a $email.\nCuando haya más códigos de invitación disponibles, te los mandamos.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Probar de nuevo';

  @override
  String get authContactSupport => 'Contactar a soporte';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'No se pudo abrir $email';
  }

  @override
  String get authAddInviteCode => 'Agregá tu código de invitación';

  @override
  String get authInviteCodeLabel => 'Código de invitación';

  @override
  String get authEnterYourCode => 'Ingresá tu código';

  @override
  String get authNext => 'Siguiente';

  @override
  String get authJoinWaitlist => 'Unirme a la lista de espera';

  @override
  String get authJoinWaitlistTitle => 'Unite a la lista de espera';

  @override
  String get authJoinWaitlistDescription =>
      'Dejanos tu email y te mandamos novedades cuando haya cupos.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Mándenme inspiración de Divine';

  @override
  String get authInviteAccessHelp => 'Ayuda con el acceso por invitación';

  @override
  String get authGeneratingConnection => 'Generando conexión...';

  @override
  String get authConnectedAuthenticating => '¡Conectado! Autenticando...';

  @override
  String get authConnectionTimedOut => 'Se agotó el tiempo de conexión';

  @override
  String get authApproveConnection =>
      'Asegurate de haber aprobado la conexión en tu app firmante.';

  @override
  String get authConnectionCancelled => 'Conexión cancelada';

  @override
  String get authConnectionCancelledMessage => 'La conexión fue cancelada.';

  @override
  String get authConnectionFailed => 'Falló la conexión';

  @override
  String get authUnknownError => 'Ocurrió un error desconocido.';

  @override
  String get authNostrConnectStartFailed =>
      'No pudimos contactar con la app firmante. Revisá tu conexión y probá de nuevo.';

  @override
  String get authNostrConnectInvalidSession =>
      'Este enlace de conexión ya no es válido. Iniciá uno nuevo.';

  @override
  String get authNostrConnectSetupFailed =>
      'Ya casi — no pudimos completar tu inicio de sesión. Probá de nuevo.';

  @override
  String get authUrlCopied => 'URL copiada al portapapeles';

  @override
  String get authConnectToDivine => 'Conectar con Divine';

  @override
  String get authPasteBunkerUrl => 'Pegá la URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker inválida. Tiene que empezar con bunker://';

  @override
  String get authScanSignerApp =>
      'Escaneá con tu\napp firmante para conectarte.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Esperando conexión... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copiar URL';

  @override
  String get authShare => 'Compartir';

  @override
  String get authAddBunker => 'Agregar bunker';

  @override
  String get authCompatibleSignerApps => 'Apps firmantes compatibles';

  @override
  String get authFailedToConnect => 'No se pudo conectar';

  @override
  String get authResetPasswordTitle => 'Restablecer contraseña';

  @override
  String get authResetPasswordSubtitle =>
      'Ingresá tu nueva contraseña. Tiene que tener al menos 8 caracteres.';

  @override
  String get authNewPasswordLabel => 'Nueva contraseña';

  @override
  String get authConfirmNewPasswordLabel => 'Confirmar nueva contraseña';

  @override
  String get authPasswordTooShort =>
      'La contraseña tiene que tener al menos 8 caracteres';

  @override
  String get authPasswordResetSuccess =>
      'Contraseña restablecida. Iniciá sesión.';

  @override
  String get authPasswordResetFailed =>
      'Falló el restablecimiento de la contraseña';

  @override
  String get authUnexpectedError =>
      'Ocurrió un error inesperado. Probá de nuevo.';

  @override
  String get authUpdatePassword => 'Actualizar contraseña';

  @override
  String get authSecureAccountTitle => 'Asegurá tu cuenta';

  @override
  String get authUnableToAccessKeys =>
      'No se pudo acceder a tus claves. Probá de nuevo.';

  @override
  String get authRegistrationFailed => 'Falló el registro';

  @override
  String get authRegistrationComplete => 'Registro completo. Revisá tu email.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'No se pudo enviar el email de restablecimiento.';

  @override
  String get authSending => 'Enviando...';

  @override
  String get authSignInButton => 'Iniciar sesión';

  @override
  String get authVerificationErrorTimeout =>
      'Se agotó el tiempo de verificación. Registrate de nuevo.';

  @override
  String get authVerificationErrorMissingCode =>
      'Falló la verificación — falta el código de autorización.';

  @override
  String get authVerificationErrorPollFailed =>
      'Falló la verificación. Probá de nuevo.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Error de red al iniciar sesión. Probá de nuevo.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Falló la verificación. Registrate de nuevo.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Falló el inicio de sesión. Iniciá sesión manualmente.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Este email ya está registrado. Iniciá sesión en su lugar.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Ese código no coincide. Revisalo y probá de nuevo.';

  @override
  String get authVerificationErrorPinExpired =>
      'Ese código expiró. Tocá Reenviar para conseguir uno nuevo.';

  @override
  String get authVerificationErrorPinLocked =>
      'Demasiados intentos. Tocá Reenviar para conseguir un código nuevo.';

  @override
  String get authVerificationErrorPinFailed =>
      'No pudimos verificar ese código. Probá de nuevo.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'El ingreso del código no está disponible ahora mismo. Tocá el link en tu email o reenviá para conseguir uno nuevo.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Ingresá un código de invitación como ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Ese código de invitación no parece válido.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Ese código de invitación ya se usó o fue revocado.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Las invitaciones de este creador se agotaron';

  @override
  String get authInviteGateErrorUnavailable =>
      'Ese código de invitación no está disponible. Sumate a la lista de espera y te enviamos una invitación cuando haya lugar.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'No pudimos verificar ese código. Probá de nuevo.';

  @override
  String get authInviteGateErrorUnknown =>
      'Algo salió mal. Probá de nuevo con tu código de invitación.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Ese código de invitación ya no está disponible. Volvé a tu código, unite a la lista de espera o contactá a soporte.';

  @override
  String get authInviteErrorInvalid =>
      'Ese código de invitación no se puede usar ahora. Volvé a tu código, unite a la lista de espera o contactá a soporte.';

  @override
  String get authInviteErrorTemporary =>
      'No pudimos confirmar tu invitación ahora. Volvé a tu código y probá de nuevo, o contactá a soporte.';

  @override
  String get authInviteErrorUnknown =>
      'No pudimos activar tu invitación. Volvé a tu código, unite a la lista de espera o contactá a soporte.';

  @override
  String get shareSheetSave => 'Guardar';

  @override
  String get shareSheetRemoveFromSaved => 'Quitar de guardados';

  @override
  String get shareSheetSaveToGallery => 'Guardar en la galería';

  @override
  String get shareSheetSaveWithWatermark => 'Guardar con marca de agua';

  @override
  String get shareSheetSaveVideo => 'Guardar video';

  @override
  String get shareSheetAddToClips => 'Agregar a clips';

  @override
  String get shareSheetNameClipTitle => 'Nombrá este clip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Elegí un nombre que vayas a reconocer en tu biblioteca.';

  @override
  String get shareSheetClipTitleLabel => 'Título del clip';

  @override
  String get shareSheetSaveClip => 'Guardar clip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Se guardó \"$title\" en los clips';
  }

  @override
  String get shareSheetUntitledClip => 'Clip sin título';

  @override
  String get shareSheetAddToClipsFailed => 'No se pudo agregar a clips';

  @override
  String get shareSheetAddToList => 'Agregar a lista';

  @override
  String get shareSheetCopy => 'Copiar';

  @override
  String get shareSheetShareVia => 'Compartir vía';

  @override
  String get shareSheetEventJson => 'JSON del evento';

  @override
  String get shareSheetEventId => 'ID del evento';

  @override
  String get shareSheetMoreActions => 'Más acciones';

  @override
  String get shareSheetCrosspost => 'Crosspostear';

  @override
  String get crosspostSheetTitle => 'Crosspostear este video';

  @override
  String get crosspostSheetSubtitle =>
      'Mandalo a tus plataformas conectadas. Publicar puede tardar unos minutos.';

  @override
  String get crosspostSubmit => 'Crosspostear';

  @override
  String get crosspostStatusQueued => 'En cola';

  @override
  String get crosspostStatusUploading => 'Subiendo';

  @override
  String get crosspostStatusProcessing => 'Procesando';

  @override
  String get crosspostStatusPosted => 'Publicado';

  @override
  String get crosspostStatusFailed => 'Falló';

  @override
  String get crosspostStatusSkipped => 'Omitido';

  @override
  String get crosspostStatusNeedsReauth => 'Reconexión necesaria';

  @override
  String get crosspostViewPost => 'Ver publicación';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Reconectá $platform en los ajustes de crosspost para seguir publicando.';
  }

  @override
  String get crosspostReconnect => 'Reconectar';

  @override
  String get crosspostErrorNotOwner =>
      'Solo tus propios videos se pueden crosspostear.';

  @override
  String get crosspostErrorNotEligible =>
      'Este video no es elegible para crosspostear.';

  @override
  String get crosspostErrorNotConnected => 'Esa plataforma no está conectada.';

  @override
  String get crosspostErrorUnauthorized =>
      'Reconectá tu cuenta y probá de nuevo.';

  @override
  String get crosspostErrorNetwork =>
      'No pudimos conectar con el crossposter. Probá de nuevo en un momento.';

  @override
  String get crosspostFailedGeneric => 'Falló el crosspost.';

  @override
  String get crosspostStillWorking =>
      'Todavía está en proceso. Podés cerrar esto — la publicación sigue en segundo plano.';

  @override
  String get crosspostDone => 'Listo';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Guardado en el carrete';

  @override
  String get watermarkDownloadShare => 'Compartir';

  @override
  String get watermarkDownloadDone => 'Listo';

  @override
  String get watermarkDownloadPhotosAccessNeeded =>
      'Se necesita acceso a Fotos';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Para guardar videos, permití el acceso a Fotos en Ajustes.';

  @override
  String get watermarkDownloadOpenSettings => 'Abrir Ajustes';

  @override
  String get watermarkDownloadNotNow => 'Ahora no';

  @override
  String get watermarkDownloadFailed => 'Falló la descarga';

  @override
  String get watermarkDownloadDismiss => 'Descartar';

  @override
  String get watermarkDownloadStageDownloading => 'Descargando video';

  @override
  String get watermarkDownloadStageWatermarking => 'Aplicando marca de agua';

  @override
  String get watermarkDownloadStageSaving => 'Guardando en el carrete';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Obteniendo el video de la red...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Aplicando la marca de agua de Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Guardando el video con marca de agua en tu carrete...';

  @override
  String get shareMenuBookmarks => 'Marcadores';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count sets de seguidos disponibles';
  }

  @override
  String get peopleListsAddToList => 'Añadir a la lista';

  @override
  String get peopleListsSheetTitle => 'Añadir a la lista';

  @override
  String get peopleListsEmptyTitle => 'Aún no hay listas';

  @override
  String get peopleListsEmptySubtitle =>
      'Crea una lista para empezar a agrupar personas.';

  @override
  String get peopleListsCreateList => 'Crear lista';

  @override
  String get peopleListsNewListTitle => 'Nueva lista';

  @override
  String get peopleListsRouteTitle => 'Lista de personas';

  @override
  String get peopleListsListNameLabel => 'Nombre de la lista';

  @override
  String get peopleListsListNameHint => 'Amigos cercanos';

  @override
  String get peopleListsCreateButton => 'Crear';

  @override
  String get peopleListsAddPeopleTitle => 'Añadir personas';

  @override
  String get peopleListsAddPeopleTooltip => 'Añadir personas';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Añadir personas a la lista';

  @override
  String get peopleListsListNotFoundTitle => 'Lista no encontrada';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lista no encontrada. Puede que haya sido eliminada.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Esta lista puede que haya sido eliminada.';

  @override
  String get peopleListsNoPeopleTitle => 'No hay personas en esta lista';

  @override
  String get peopleListsNoPeopleSubtitle => 'Añade personas para empezar';

  @override
  String get peopleListsNoVideosTitle => 'Aún no hay videos';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Los videos de los miembros de la lista aparecerán aquí';

  @override
  String get peopleListsNoVideosAvailable => 'No hay videos disponibles';

  @override
  String get peopleListsFailedToLoadVideos => 'Error al cargar los videos';

  @override
  String get peopleListsVideoNotAvailable => 'Video no disponible';

  @override
  String get peopleListsBackToGridTooltip => 'Volver a la cuadrícula';

  @override
  String get peopleListsErrorLoadingVideos => 'Error al cargar los videos';

  @override
  String get peopleListsNoPeopleToAdd =>
      'No hay personas disponibles para añadir.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Añadir a $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Buscar personas';

  @override
  String get peopleListsAddPeopleError =>
      'No se pudo cargar la lista de personas. Inténtalo de nuevo.';

  @override
  String get peopleListsAddPeopleRetry => 'Intentar de nuevo';

  @override
  String get peopleListsAddButton => 'Añadir';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Añadir $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En $count listas',
      one: 'En 1 lista',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '¿Eliminar a $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Esta persona será eliminada de esta lista.';

  @override
  String get peopleListsRemove => 'Eliminar';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name eliminado/a de la lista';
  }

  @override
  String get peopleListsUndo => 'Deshacer';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Perfil de $name. Mantén pulsado para eliminar.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Ver perfil de $name';
  }

  @override
  String get shareMenuEditVideo => 'Editar video';

  @override
  String get shareMenuDeleteVideo => 'Eliminar video';

  @override
  String shareMenuVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Esto eliminará permanentemente este video de Divine. Es posible que siga apareciendo en clientes Nostr de terceros que usan otros relays.';

  @override
  String get shareMenuCancel => 'Cancelar';

  @override
  String get shareMenuDelete => 'Eliminar';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'El borrado no está listo todavía. Probá de nuevo en un momento.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Solo podés borrar tus propios videos.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Volvé a iniciar sesión y probá borrar de nuevo.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'No pudimos firmar el pedido de borrado. Probá de nuevo.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'El relay no aceptó esta solicitud de borrado. Inténtalo de nuevo en un momento.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'No se pudo contactar con el relay. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Borrado. No todos los relays lo confirmaron, así que puede seguir apareciendo en otras apps.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'No pudimos borrar este video. Probá de nuevo.';

  @override
  String get shareMenuUpdate => 'Actualizar';

  @override
  String get shareMenuChangeCover => 'Cambiar portada';

  @override
  String get shareMenuVideoUpdated => 'Video actualizado con éxito';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'no se enviaron $count invitaciones de colaborador.',
      one: 'no se envió 1 invitación de colaborador.',
    );
    return 'Video actualizado, pero $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Iniciá sesión de nuevo y volvé a intentarlo.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Este video no tiene una fuente reproducible, así que no se puede editar.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'No se pudo firmar la actualización. Probá de nuevo.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'El relay no aceptó la actualización. Probá de nuevo en un momento.';

  @override
  String get videoUpdateErrorGeneric =>
      'No se pudo actualizar este video. Probá de nuevo.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => '¿Eliminar video?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Eliminando video…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Video eliminado.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Video eliminado. Puede tardar un poco en desaparecer de todas partes.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Video eliminado, pero no pudimos borrar todas las copias. Contactá a soporte.';

  @override
  String get authSessionExpired => 'Tu sesión expiró. Iniciá sesión de nuevo.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'No se pudo iniciar sesión. Probá de nuevo.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'La autenticación web no está soportada en modo seguro. Usá la app móvil para gestionar claves de forma segura.';

  @override
  String get webAuthEnterBunkerUri => 'Ingresá una URI de bunker';

  @override
  String get webAuthConnectTitle => 'Conectar con Divine';

  @override
  String get webAuthChooseMethod =>
      'Elegí tu método preferido de autenticación de Nostr';

  @override
  String get webAuthBrowserExtension => 'Extensión del navegador';

  @override
  String get webAuthRecommended => 'RECOMENDADO';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Conectar con un firmante remoto';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Pegar desde el portapapeles';

  @override
  String get webAuthConnectToBunker => 'Conectar al bunker';

  @override
  String get webAuthNewToNostr => '¿Sos nuevo en Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Instalá una extensión como Alby o nos2x para la experiencia más fácil, o usá nsec bunker para firma remota segura.';

  @override
  String get soundsTitle => 'Sonidos';

  @override
  String get soundsSearchHint => 'Buscar sonidos...';

  @override
  String get soundsSearchResults => 'Resultados de búsqueda';

  @override
  String get soundsNoSoundsFound => 'No se encontraron sonidos';

  @override
  String get soundsNoSoundsFoundDescription =>
      'Probá con otro término de búsqueda';

  @override
  String get soundsSavedToLibrary => 'Guardado en Sonidos';

  @override
  String get soundsAlreadySavedToLibrary => 'Ya está en Sonidos';

  @override
  String get soundsSavedLibraryTitle => 'Mis sonidos';

  @override
  String get soundsSavedEmptyTitle => 'Aún no hay sonidos guardados';

  @override
  String get soundsSavedEmptyDescription =>
      'Toca Usar sonido en un video para guardarlo aquí.';

  @override
  String get soundsRemoveSavedSound => 'Eliminar sonido';

  @override
  String get savedSoundSaveAction => 'Guardar';

  @override
  String get savedSoundPausePreviewAction => 'Pausar la vista previa';

  @override
  String get savedSoundResumePreviewAction => 'Reanudar vista previa';

  @override
  String get savedSoundDetailsSheetTitle => 'Detalles del sonido';

  @override
  String get savedSoundRemoveConfirmTitle => '¿Quitar este sonido?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Desaparecerá de tu biblioteca, pero puedes volver a guardarlo desde cualquier video que lo use.';

  @override
  String get soundsRemovedFromLibrary => 'Eliminado de Sonidos';

  @override
  String get soundsSaveFailed =>
      'No se pudo guardar ese sonido. Inténtalo de nuevo.';

  @override
  String get soundsRemoveFailed =>
      'No se pudo quitar ese sonido. Inténtalo de nuevo.';

  @override
  String get soundSyncStatusSyncing => 'Sincronizando tus sonidos…';

  @override
  String get soundSyncStatusSynced => 'Sonidos actualizados';

  @override
  String get soundSyncStatusFailed =>
      'No pudimos sincronizar tus sonidos. Lo intentaremos de nuevo.';

  @override
  String get soundSyncStatusLocked =>
      'No se puede desbloquear tu biblioteca sincronizada en este dispositivo.';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileMoreOptions => 'Más opciones';

  @override
  String profileBlockedUser(String name) {
    return 'Bloqueaste a $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Desbloqueaste a $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Dejaste de seguir a $name';
  }

  @override
  String get profileFeedError =>
      'No se puede conectar con el servidor. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get profileFeedLoadMoreError =>
      'No se pudieron cargar más videos. Desliza para actualizar.';

  @override
  String get notificationsTabAll => 'Todas';

  @override
  String get notificationsTabLikes => 'Me gusta';

  @override
  String get notificationsTabComments => 'Comentarios';

  @override
  String get notificationsTabFollows => 'Seguidores';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad =>
      'No se pudieron cargar las notificaciones';

  @override
  String get notificationsRetry => 'Reintentar';

  @override
  String get notificationsRefreshError =>
      'No se pudo actualizar — se muestra lo disponible';

  @override
  String get notificationsUnreadPrefix => 'Notificación no leída';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notificaciones sin leer',
      one: '1 notificación sin leer',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Ver perfil de $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Ver perfiles';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Miniatura del video $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Miniatura del video';

  @override
  String get notificationsInviteSingular =>
      '¡Tenés 1 invitación para compartir con un amigo!';

  @override
  String notificationsInvitePlural(int count) {
    return '¡Tenés $count invitaciones para compartir con amigos!';
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
  String get notificationsVideoUnavailable => 'Video no disponible';

  @override
  String get feedFailedToLoadVideos => 'No se pudieron cargar los videos';

  @override
  String get feedRetry => 'Reintentar';

  @override
  String get feedNoFollowedUsers =>
      'Todavía no seguís a nadie.\nSeguí a alguien para ver sus videos acá.';

  @override
  String get feedModeForYou => 'Para ti';

  @override
  String get feedModeNew => 'Nuevo';

  @override
  String get feedModeFollowing => 'Siguiendo';

  @override
  String get feedModeClassics => 'Clásicos';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Modo del feed: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Autor del video: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar del autor';

  @override
  String get feedForYouEmpty =>
      'Tu feed Para ti está vacío.\nExplora videos y sigue a creadores para personalizarlo.';

  @override
  String get feedFollowingEmpty =>
      'Aún no hay videos de personas que sigues.\nEncuentra creadores que te gusten y síguelos.';

  @override
  String get feedLatestEmpty => 'Aún no hay videos nuevos.\nVuelve pronto.';

  @override
  String get feedClassicEmpty => 'Aún no hay clásicos.\nVuelve pronto.';

  @override
  String get feedExploreVideos => 'Explorar videos';

  @override
  String get feedLoadingMore => 'Cargando más videos…';

  @override
  String get feedRefreshed => 'Feed actualizado';

  @override
  String get uploadUploadingVideo => 'Subiendo video';

  @override
  String get postPublishConfirmationTitle => 'Publicado en tu perfil';

  @override
  String get postPublishConfirmationView => 'Ver';

  @override
  String get postPublishConfirmationShare => 'Compartir';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Miniatura del video que acabas de publicar';

  @override
  String get userSearchNoResults => 'No se encontraron usuarios';

  @override
  String get userPickerFilterByNameHint => 'Filtrar por nombre...';

  @override
  String get userPickerSearchByNameHint => 'Buscar por nombre...';

  @override
  String get userPickerClearSearchSemantics => 'Borrar búsqueda';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name ya fue agregado';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Seleccionar $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Eliminar a $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Tu gente está ahí fuera';

  @override
  String get userPickerEmptyFollowListBody =>
      'Sigue a personas con las que conectas. Cuando te sigan de vuelta, pueden colaborar.';

  @override
  String get userPickerGoBack => 'Volver';

  @override
  String get userPickerTypeNameToSearch => 'Escribe un nombre para buscar';

  @override
  String get userPickerUnavailable =>
      'La búsqueda de usuarios no está disponible. Inténtalo de nuevo más tarde.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'La búsqueda falló. Inténtalo de nuevo.';

  @override
  String get forgotPasswordTitle => 'Restablecer contraseña';

  @override
  String get forgotPasswordDescription =>
      'Ingresá tu email y te mandamos un link para restablecer la contraseña.';

  @override
  String get forgotPasswordEmailLabel => 'Dirección de email';

  @override
  String get forgotPasswordCancel => 'Cancelar';

  @override
  String get forgotPasswordSendLink => 'Enviar link por email';

  @override
  String get ageVerificationContentWarning => 'Advertencia de contenido';

  @override
  String get ageVerificationTitle => 'Verificación de edad';

  @override
  String get ageVerificationAdultDescription =>
      'Este contenido fue marcado como potencialmente adulto. Tenés que tener 18 años o más para verlo.';

  @override
  String get ageVerificationCreationDescription =>
      'Para usar la cámara y crear contenido, tenés que tener al menos 16 años.';

  @override
  String get ageVerificationAdultQuestion => '¿Tenés 18 años o más?';

  @override
  String get ageVerificationCreationQuestion => '¿Tenés 16 años o más?';

  @override
  String get ageVerificationNo => 'No';

  @override
  String get ageVerificationYes => 'Sí';

  @override
  String get navHome => 'Inicio';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navInbox => 'Bandeja';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navMyProfile => 'Mi perfil';

  @override
  String get navNotifications => 'Notificaciones';

  @override
  String get navOpenCamera => 'Abrir cámara';

  @override
  String get navExploreClassics => 'Clásicos';

  @override
  String get navExploreNewVideos => 'Videos nuevos';

  @override
  String get navExploreTrending => 'En tendencia';

  @override
  String get navExploreForYou => 'Para vos';

  @override
  String get navExploreLists => 'Listas';

  @override
  String get routeErrorTitle => 'Error';

  @override
  String get routeInvalidHashtag => 'Hashtag inválido';

  @override
  String get routeInvalidConversationId => 'ID de conversación inválido';

  @override
  String get routeInvalidRequestId => 'ID de pedido inválido';

  @override
  String get routeInvalidListId => 'ID de lista inválido';

  @override
  String get routeInvalidUserId => 'ID de usuario inválido';

  @override
  String get routeInvalidVideoId => 'ID de video inválido';

  @override
  String get routeInvalidSoundId => 'ID de sonido inválido';

  @override
  String get routeInvalidCategory => 'Categoría inválida';

  @override
  String get routeNoVideosToDisplay => 'No hay videos para mostrar';

  @override
  String get routeGoHome => 'Ir al inicio';

  @override
  String get routeInvalidProfileId => 'ID de perfil inválido';

  @override
  String get routeUnknownPath => 'Esa página no está en la app.';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Centro de soporte';

  @override
  String get supportContactSupport => 'Contactar a soporte';

  @override
  String get supportContactSupportSubtitle =>
      'Empezá una conversación o mirá los mensajes anteriores';

  @override
  String get supportReportBug => 'Reportar un bug';

  @override
  String get supportReportBugSubtitle => 'Problemas técnicos con la app';

  @override
  String get supportRequestFeature => 'Pedir una función';

  @override
  String get supportRequestFeatureSubtitle =>
      'Sugerí una mejora o una función nueva';

  @override
  String get supportSaveLogs => 'Guardar logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Exportá los logs a un archivo para enviarlos manualmente';

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
  String get supportFaq => 'Preguntas frecuentes';

  @override
  String get supportFaqSubtitle => 'Preguntas y respuestas comunes';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Ayudamos a padres y adolescentes a crear hábitos saludables en línea';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Cómo gestionamos las cuentas según la edad';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Conocé sobre verificación y autenticidad';

  @override
  String get supportLoginRequired => 'Iniciá sesión para contactar a soporte';

  @override
  String get supportExportingLogs => 'Exportando logs...';

  @override
  String get supportExportLogsFailed => 'No se pudieron exportar los logs';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Registros guardados en $path';
  }

  @override
  String get supportRevealLogsAction => 'Mostrar en carpeta';

  @override
  String get supportChatNotAvailable => 'El chat de soporte no está disponible';

  @override
  String get supportCouldNotOpenMessages =>
      'No se pudieron abrir los mensajes de soporte';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'No se pudo abrir $pageName';
  }

  @override
  String get reportWhyReporting => '¿Por qué estás reportando este contenido?';

  @override
  String get reportPolicyNotice =>
      'Divine va a actuar sobre los reportes de contenido dentro de las 24 horas, removiendo el contenido y expulsando al usuario que lo publicó.';

  @override
  String get reportBlockUser => 'Bloquear a este usuario';

  @override
  String get reportCancel => 'Cancelar';

  @override
  String get reportSubmit => 'Reportar';

  @override
  String get reportSelectReason =>
      'Elegí un motivo para reportar este contenido';

  @override
  String get reportOtherRequiresDetails =>
      'Describe el problema cuando elijas Otro';

  @override
  String get reportDetailsRequired => 'Describe el problema';

  @override
  String get reportDetailsTextOnly =>
      'Solo texto: aquí no se pueden adjuntar fotos ni GIF.';

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
  String get reportReasonSpam => 'Spam o contenido no deseado';

  @override
  String get reportReasonSpamSubtitle => 'Contenido no deseado o repetitivo';

  @override
  String get reportReasonHarassment => 'Acoso, bullying o amenazas';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Respuestas o menciones dañinas y no deseadas';

  @override
  String get reportReasonViolence => 'Contenido violento o extremista';

  @override
  String get reportReasonViolenceSubtitle =>
      'Contenido violento, extremista o dañino';

  @override
  String get reportReasonSexualContent => 'Contenido sexual o adulto';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Desnudez, pornografía o contenido explícito';

  @override
  String get reportReasonCopyright => 'Infracción de derechos de autor';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Uso no autorizado de propiedad intelectual';

  @override
  String get reportReasonFalseInfo => 'Información falsa';

  @override
  String get reportReasonFalseInfoSubtitle => 'Afirmaciones engañosas o falsas';

  @override
  String get reportReasonChildSafety => 'Violación de la seguridad infantil';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Inquietudes generales sobre la seguridad de menores';

  @override
  String get reportReasonCsam => 'Abuso sexual infantil';

  @override
  String get reportReasonCsamSubtitle =>
      'Contenido que muestra abuso sexual de menores';

  @override
  String get reportReasonUnderageUser => 'El usuario parece ser menor de 16';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'El titular de la cuenta parece ser menor de edad';

  @override
  String get reportReasonAiGenerated => 'Contenido generado por IA';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Contenido sospechoso de ser generado por IA';

  @override
  String get reportReasonOther => 'Otra violación de políticas';

  @override
  String get reportReasonOtherSubtitle => 'Infracciones no listadas arriba';

  @override
  String get reportFailed =>
      'No se pudo reportar el contenido. Probá de nuevo.';

  @override
  String get reportNotSent =>
      'No se pudo enviar tu reporte. Verificá tu conexión e intentá de nuevo.';

  @override
  String get reportReceivedTitle => 'Reporte recibido';

  @override
  String get reportReceivedThankYou =>
      'Gracias por ayudar a mantener Divine seguro.';

  @override
  String get reportReceivedReviewNotice =>
      'Nuestro equipo va a revisar tu reporte y tomar las medidas necesarias. Quizás recibas novedades por mensaje directo.';

  @override
  String get reportModerationDmDelayed =>
      'No pudimos contactar directamente al equipo de moderación ahora mismo, pero recibimos tu reporte y lo vamos a revisar.';

  @override
  String get reportContactModeration => 'Escribile al equipo de moderación';

  @override
  String get reportLearnMoreAt => 'Más información en';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Cerrar';

  @override
  String get listAddToList => 'Agregar a lista';

  @override
  String listVideoCount(int count) {
    return '$count videos';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Por ';

  @override
  String get listNewList => 'Lista nueva';

  @override
  String get listDone => 'Listo';

  @override
  String get listErrorLoading => 'Error al cargar las listas';

  @override
  String listRemovedFrom(String name) {
    return 'Quitado de $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Agregado a $name';
  }

  @override
  String get listCreateNewList => 'Crear lista nueva';

  @override
  String get listNewPeopleList => 'Nueva lista de personas';

  @override
  String get listCollaboratorsNone => 'Ninguno';

  @override
  String get listAddCollaboratorTitle => 'Añadir colaborador';

  @override
  String get listCollaboratorSearchHint => 'Buscar en Divine...';

  @override
  String get listNameLabel => 'Nombre de la lista';

  @override
  String get listDescriptionLabel => 'Descripción (opcional)';

  @override
  String get listPublicList => 'Lista pública';

  @override
  String get listPublicListSubtitle => 'Otros pueden seguir y ver esta lista';

  @override
  String get listPrivateListSubtitle =>
      'Los videos quedan privados. El nombre, la descripción, las etiquetas y la portada siguen visibles.';

  @override
  String get listVisibilityPublic => 'Pública';

  @override
  String get listVisibilityPrivate => 'Privada';

  @override
  String get profileListsEmpty =>
      'Todavía no tenés listas. Armá una con los loops que querés tener juntos.';

  @override
  String get listEditTitle => 'Editar lista';

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
  String get listShareAction => 'Compartir lista';

  @override
  String get listShareFailed =>
      'No se pudo compartir esta lista. Probá de nuevo.';

  @override
  String get listSave => 'Guardar';

  @override
  String get listContinue => 'Continuar';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'No se pudo actualizar esta lista. Probá de nuevo.';

  @override
  String get listMakePrivateTitle => '¿Hacer privada esta lista?';

  @override
  String get listMakePrivateWarning =>
      'Los videos se cifran para que solo vos los veas. El nombre, la descripción, las etiquetas y la portada siguen visibles, y las copias ya compartidas pueden persistir.';

  @override
  String get listMakePublicTitle => '¿Hacer pública esta lista?';

  @override
  String get listMakePublicWarning =>
      'Cualquiera con el enlace puede ver esta lista y sus videos.';

  @override
  String listShareText(String name, String url) {
    return 'Mirá $name en Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name en Divine';
  }

  @override
  String get listCancel => 'Cancelar';

  @override
  String get listCreate => 'Crear';

  @override
  String get listCreateFailed => 'No se pudo crear la lista';

  @override
  String get keyManagementTitle => 'Claves de Nostr';

  @override
  String get keyManagementWhatAreKeys => '¿Qué son las claves de Nostr?';

  @override
  String get keyManagementExplanation =>
      'Tu identidad en Nostr es un par de claves criptográficas:\n\n• Tu clave pública (npub) es como tu nombre de usuario — compartila tranqui\n• Tu clave privada (nsec) es como tu contraseña — ¡mantenela en secreto!\n\nTu nsec te permite acceder a tu cuenta en cualquier app de Nostr.';

  @override
  String get keyManagementImportTitle => 'Importar clave existente';

  @override
  String get keyManagementImportSubtitle =>
      '¿Ya tenés una cuenta en Nostr? Pegá tu clave privada (nsec) para acceder acá.';

  @override
  String get keyManagementImportButton => 'Importar clave';

  @override
  String get keyManagementImportWarning =>
      '¡Esto va a reemplazar tu clave actual!';

  @override
  String get keyManagementBackupTitle => 'Respaldá tu clave';

  @override
  String get keyManagementBackupSubtitle =>
      'Guardá tu clave privada (nsec) para usar tu cuenta en otras apps de Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copiar mi clave privada (nsec)';

  @override
  String get keyManagementNeverShare => '¡Nunca compartas tu nsec con nadie!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Tu clave está en el servicio de inicio de sesión de Divine, no en este dispositivo. Confirma tu contraseña y la traemos por ti.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Tu clave la guarda el servicio de inicio de sesión de Divine. Introduce la contraseña de tu cuenta y la traemos.';

  @override
  String get keyManagementKeycastCopyKey => 'Copiar clave';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Tu dispositivo bloqueó la copia, así que tu clave no llegó al portapapeles.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Esa contraseña no coincide. Vuelve a intentarlo.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Demasiados intentos. Cierra esto y empieza de nuevo.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Demasiadas solicitudes de la clave. Espera unos minutos y vuelve a intentarlo.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Tu sesión ha caducado. Inicia sesión de nuevo para copiar tu clave.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Verifica tu dirección de correo electrónico antes de copiar tu clave.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine gestiona las claves de esta cuenta, así que no se pueden copiar aquí.';

  @override
  String get keyManagementKeycastNoKey =>
      'No hay ninguna clave registrada para esta cuenta.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'No se pudo conectar con el servicio de inicio de sesión. Probá de nuevo.';

  @override
  String get keyManagementRestrictedTitle => 'Divine gestiona tus claves';

  @override
  String get keyManagementRestrictedBody =>
      'Para mantener tu cuenta segura, aquí no están disponibles la copia de seguridad de la clave ni la importación de otra clave.';

  @override
  String get keyManagementPasteKey => 'Pegá tu clave privada';

  @override
  String get keyManagementInvalidFormat =>
      'Formato de clave inválido. Tiene que empezar con \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => '¿Importar esta clave?';

  @override
  String get keyManagementConfirmImportBody =>
      'Esto va a reemplazar tu identidad actual con la importada.\n\nTu clave actual se va a perder salvo que la hayas respaldado antes.';

  @override
  String get keyManagementImportConfirm => 'Importar';

  @override
  String get keyManagementImportSuccess => '¡Clave importada con éxito!';

  @override
  String get keyManagementImportFailed =>
      'No se pudo importar la clave. Probá de nuevo.';

  @override
  String get keyManagementExportSuccess =>
      '¡Clave privada copiada al portapapeles!\n\nGuardala en un lugar seguro.';

  @override
  String get keyManagementExportFailed =>
      'No se pudo exportar la clave. Probá de nuevo.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Tu clave pública (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copiar clave pública';

  @override
  String get keyManagementPublicKeyCopied => 'Clave pública copiada';

  @override
  String get saveOriginalSavedToCameraRoll => 'Guardado en el carrete';

  @override
  String get saveOriginalShare => 'Compartir';

  @override
  String get saveOriginalDone => 'Listo';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Se necesita acceso a Fotos';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Para guardar videos, permití el acceso a Fotos en Ajustes.';

  @override
  String get saveOriginalOpenSettings => 'Abrir Ajustes';

  @override
  String get saveOriginalNotNow => 'Ahora no';

  @override
  String get saveOriginalDownloadFailed => 'Falló la descarga';

  @override
  String get saveOriginalDismiss => 'Descartar';

  @override
  String get saveOriginalDownloadingVideo => 'Descargando video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Guardando en el carrete';

  @override
  String get saveOriginalFetchingVideo => 'Obteniendo el video de la red...';

  @override
  String get saveOriginalSavingVideo =>
      'Guardando el video original en tu carrete...';

  @override
  String get soundTitle => 'Sonido';

  @override
  String get soundOriginalSound => 'Sonido original';

  @override
  String get soundVideosUsingThisSound => 'Videos que usan este sonido';

  @override
  String get soundSourceVideo => 'Video de origen';

  @override
  String get soundNoVideosYet => 'Todavía no hay videos';

  @override
  String get soundBeFirstToUse => '¡Sé el primero en usar este sonido!';

  @override
  String get soundFailedToLoadVideos => 'No se pudieron cargar los videos';

  @override
  String get soundRetry => 'Reintentar';

  @override
  String get soundVideosUnavailable => 'Videos no disponibles';

  @override
  String get soundCouldNotLoadDetails =>
      'No se pudieron cargar los detalles del video';

  @override
  String get soundPreview => 'Previsualizar';

  @override
  String get soundStop => 'Parar';

  @override
  String get soundUseSound => 'Usar sonido';

  @override
  String get soundUntitled => 'Sonido sin título';

  @override
  String get soundStopPreview => 'Parar la vista previa';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Vista previa de $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Ver detalles de $title';
  }

  @override
  String get soundNoVideoCount => 'Todavía no hay videos';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get soundUnableToPreview =>
      'No se puede previsualizar el sonido: no hay audio disponible';

  @override
  String get soundPreviewFailed =>
      'No se pudo reproducir la previsualización. Probá de nuevo.';

  @override
  String get soundViewSource => 'Ver origen';

  @override
  String get soundCloseTooltip => 'Cerrar';

  @override
  String get exploreNotExploreRoute => 'No es una ruta de explorar';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Términos del Servicio';

  @override
  String get legalTermsOfServiceSubtitle => 'Términos y condiciones de uso';

  @override
  String get legalPrivacyPolicy => 'Política de Privacidad';

  @override
  String get legalPrivacyPolicySubtitle => 'Cómo manejamos tus datos';

  @override
  String get legalSafetyStandards => 'Estándares de Seguridad';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Pautas de la comunidad y seguridad';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Política de derechos de autor y de remoción';

  @override
  String get legalOpenSourceLicenses => 'Licencias de código abierto';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Atribuciones de paquetes de terceros';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'No se pudo abrir $pageName';
  }

  @override
  String get categoryAction => 'Acción';

  @override
  String get categoryAdventure => 'Aventura';

  @override
  String get categoryAnimals => 'Animales';

  @override
  String get categoryAnimation => 'Animación';

  @override
  String get categoryArchitecture => 'Arquitectura';

  @override
  String get categoryArt => 'Arte';

  @override
  String get categoryAutomotive => 'Autos';

  @override
  String get categoryAwardShow => 'Entrega de premios';

  @override
  String get categoryAwards => 'Premios';

  @override
  String get categoryBaseball => 'Béisbol';

  @override
  String get categoryBasketball => 'Básquet';

  @override
  String get categoryBeauty => 'Belleza';

  @override
  String get categoryBeverage => 'Bebidas';

  @override
  String get categoryCars => 'Autos';

  @override
  String get categoryCelebration => 'Celebración';

  @override
  String get categoryCelebrities => 'Famosos';

  @override
  String get categoryCelebrity => 'Famoso';

  @override
  String get categoryCityscape => 'Paisaje urbano';

  @override
  String get categoryComedy => 'Comedia';

  @override
  String get categoryConcert => 'Concierto';

  @override
  String get categoryCooking => 'Cocina';

  @override
  String get categoryCostume => 'Disfraz';

  @override
  String get categoryCrafts => 'Manualidades';

  @override
  String get categoryCrime => 'Crimen';

  @override
  String get categoryCulture => 'Cultura';

  @override
  String get categoryDance => 'Baile';

  @override
  String get categoryDiy => 'Hazlo vos mismo';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Educación';

  @override
  String get categoryEmotional => 'Emotivo';

  @override
  String get categoryEmotions => 'Emociones';

  @override
  String get categoryEntertainment => 'Entretenimiento';

  @override
  String get categoryEvent => 'Evento';

  @override
  String get categoryFamily => 'Familia';

  @override
  String get categoryFans => 'Fans';

  @override
  String get categoryFantasy => 'Fantasía';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Cine';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryFootball => 'Fútbol americano';

  @override
  String get categoryFurniture => 'Muebles';

  @override
  String get categoryGaming => 'Videojuegos';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Cuidado personal';

  @override
  String get categoryGuitar => 'Guitarra';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Salud';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Feriado';

  @override
  String get categoryHome => 'Hogar';

  @override
  String get categoryHomeImprovement => 'Reformas del hogar';

  @override
  String get categoryHorror => 'Terror';

  @override
  String get categoryHospital => 'Hospital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Diseño de interiores';

  @override
  String get categoryInterview => 'Entrevista';

  @override
  String get categoryKids => 'Chicos';

  @override
  String get categoryLifestyle => 'Estilo de vida';

  @override
  String get categoryMagic => 'Magia';

  @override
  String get categoryMakeup => 'Maquillaje';

  @override
  String get categoryMedical => 'Medicina';

  @override
  String get categoryMusic => 'Música';

  @override
  String get categoryMystery => 'Misterio';

  @override
  String get categoryNature => 'Naturaleza';

  @override
  String get categoryNews => 'Noticias';

  @override
  String get categoryOutdoor => 'Al aire libre';

  @override
  String get categoryParty => 'Fiesta';

  @override
  String get categoryPeople => 'Gente';

  @override
  String get categoryPerformance => 'Espectáculo';

  @override
  String get categoryPets => 'Mascotas';

  @override
  String get categoryPolitics => 'Política';

  @override
  String get categoryPrank => 'Broma';

  @override
  String get categoryPranks => 'Bromas';

  @override
  String get categoryRealityShow => 'Reality';

  @override
  String get categoryRelationship => 'Relación';

  @override
  String get categoryRelationships => 'Relaciones';

  @override
  String get categoryRomance => 'Romance';

  @override
  String get categorySchool => 'Escuela';

  @override
  String get categoryScienceFiction => 'Ciencia ficción';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Compras';

  @override
  String get categorySkateboarding => 'Skate';

  @override
  String get categorySkincare => 'Cuidado de la piel';

  @override
  String get categorySoccer => 'Fútbol';

  @override
  String get categorySocialGathering => 'Encuentro social';

  @override
  String get categorySocialMedia => 'Redes sociales';

  @override
  String get categorySports => 'Deportes';

  @override
  String get categoryTalkShow => 'Programa de entrevistas';

  @override
  String get categoryTech => 'Tecno';

  @override
  String get categoryTechnology => 'Tecnología';

  @override
  String get categoryTelevision => 'Televisión';

  @override
  String get categoryToys => 'Juguetes';

  @override
  String get categoryTransportation => 'Transporte';

  @override
  String get categoryTravel => 'Viajes';

  @override
  String get categoryUrban => 'Urbano';

  @override
  String get categoryViolence => 'Violencia';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Lucha libre';

  @override
  String get profileSetupUploadStaged => 'Subida — toca Guardar para aplicar';

  @override
  String inboxReportedUser(String displayName) {
    return 'Reportaste a $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Bloqueaste a $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Desbloqueaste a $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Conversación eliminada';

  @override
  String get inboxRestorePausedTitle =>
      'Algunos chats no terminaron de restaurarse';

  @override
  String get conversationRestorePausedTitle =>
      'Este chat no terminó de restaurarse';

  @override
  String get inboxRestoreRetryAction => 'Reintentar';

  @override
  String get inboxRestoringMessages => 'Restaurando tus mensajes…';

  @override
  String get inboxEmptyTitle => 'Aún no hay mensajes';

  @override
  String get inboxEmptySubtitle => 'El botón + no muerde.';

  @override
  String get inboxLoadErrorTitle => 'Los mensajes no cargaron';

  @override
  String get inboxLoadErrorSubtitle => 'Revisá tu conexión y probá de nuevo.';

  @override
  String get inboxFilterAll => 'Todos';

  @override
  String get inboxFilterUnread => 'No leídos';

  @override
  String get dmBlockedThreadTitle => 'Bloqueaste esta cuenta';

  @override
  String get dmBlockedThreadBody =>
      'Los mensajes se quedan aquí para que puedas leerlos o capturarlos. Desbloquea para responder.';

  @override
  String get inboxFilterBlocked => 'Bloqueados';

  @override
  String get inboxBlockedEmptyTitle => 'No hay chats bloqueados';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Las cuentas que bloquees aparecerán aquí.';

  @override
  String get inboxBlockedNoMessages => 'Sin mensajes';

  @override
  String get inboxUnreadEmptyTitle => 'Estás al día';

  @override
  String get inboxUnreadEmptySubtitle =>
      'No tenés mensajes sin leer ahora mismo.';

  @override
  String get inboxSearchHint => 'Buscar mensajes';

  @override
  String get inboxSupportRowTitle => 'Moderación de Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Errores, moderación, temas de cuenta: te escuchamos.';

  @override
  String get inboxSearchEmptyTitle => 'Sin coincidencias';

  @override
  String get inboxSearchEmptySubtitle =>
      'Probá con otro nombre u otra palabra.';

  @override
  String get inboxActionMute => 'Silenciar conversación';

  @override
  String inboxActionReport(String displayName) {
    return 'Reportar a $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Bloquear a $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Desbloquear a $displayName';
  }

  @override
  String get inboxActionRemove => 'Eliminar conversación';

  @override
  String get inboxRemoveConfirmTitle => '¿Eliminar conversación?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Esto quita de tu bandeja de entrada tu conversación con $displayName. Si te vuelve a escribir, se inicia una conversación nueva.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Esto quita la conversación grupal de tu bandeja de entrada. Si alguien vuelve a escribir en el grupo, se inicia una conversación nueva.';

  @override
  String get inboxRemoveConfirmConfirm => 'Eliminar';

  @override
  String get inboxConversationMuted => 'Conversación silenciada';

  @override
  String get inboxConversationUnmuted => 'Conversación sin silenciar';

  @override
  String get inboxCollabInviteCardTitle => 'Invitación a colaborar';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video sin título';

  @override
  String get clickableTextViewVideoLink => 'Ver video';

  @override
  String get messageExternalLinkDialogTitle => '¿Abrir enlace externo?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Este enlace lleva a un sitio externo y puede no ser seguro:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Abrir';

  @override
  String get inboxCollabInviteCoPostButton => 'Co-publicar';

  @override
  String get inboxCollabInviteNotMineButton => 'No es mío';

  @override
  String get inboxCollabInvitePreviewTitle => 'Invitación para co-publicar';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Invitación para co-publicar de $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Co-publicar añade este video a tu línea de tiempo como colaboración.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Aceptada';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorada';

  @override
  String get inboxCollabInviteAcceptError =>
      'No se pudo aceptar. Inténtalo de nuevo.';

  @override
  String get inboxCollabInviteSentStatus => 'Invitación enviada';

  @override
  String get inboxConversationCollabInvitePreview => 'Invitación a colaborar';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Te invitaron a colaborar en $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Te invitaron a colaborar en un video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'no se enviaron $count invitaciones de colaborador.',
      one: 'no se envió 1 invitación de colaborador.',
    );
    return 'Video publicado, pero $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'No pudimos saber con quién es esta conversación. Ábrela de nuevo desde tu bandeja.';

  @override
  String get dmSendBlockedMessage =>
      'Solo puedes escribir a cuentas oficiales de Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Nadie lee esta conversación. Escribe a Divine Moderation en su lugar.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'No se pudo eliminar para todos.';

  @override
  String get dmDeleteRefusedDetails =>
      'Es posible que algunas personas todavía puedan ver este mensaje.';

  @override
  String get dmRetiredThreadClosedTitle => 'Esta conversación está cerrada.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Este aviso de Divine Moderation no se puede eliminar.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Movimos Divine Moderation a una cuenta nueva. Ya nadie lee esta.';

  @override
  String get dmRetiredThreadOpenSupport => 'Enviar mensaje a Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'No se pudo enviar el mensaje';

  @override
  String get dmResendFailedMessage => 'Sigue sin poder enviarse';

  @override
  String get dmSendFailedSubtitle => 'Reenvíalo ahora o deja de intentarlo.';

  @override
  String get dmSendFailedRetry => 'Reintentar';

  @override
  String get dmSendPartialMessage =>
      'Enviado, pero no se sincronizó con tus otros dispositivos';

  @override
  String get dmConversationLoadError => 'No se pudieron cargar los mensajes';

  @override
  String get dmMessageInputHint => 'Di algo…';

  @override
  String get dmMessageBubbleSentHint => 'Mensaje enviado';

  @override
  String get dmMessageBubbleReceivedHint => 'Mensaje recibido';

  @override
  String get dmMessageBubbleLongPressHint => 'Acciones del mensaje';

  @override
  String get dmMessageBubbleFailedTapHint => 'Reenviar o eliminar este mensaje';

  @override
  String get dmMessageActionCopyText => 'Copiar texto';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copiar URL del video';

  @override
  String get dmMessageActionDeleteForEveryone => 'Eliminar para todos';

  @override
  String get dmMessageActionReport => 'Reportar';

  @override
  String get dmMessageActionRetrySend => 'Reenviar';

  @override
  String get dmMessageActionCancelSend => 'Dejar de intentar';

  @override
  String get dmReactionAddCustomA11yLabel =>
      'Añadir reacción con emoji personalizado';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Mensaje a $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Respóndete a ti mismo…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Responder a este reel';

  @override
  String get dmReelReplyViewChat => 'Ver chat';

  @override
  String get dmReelReplySentAnnouncement => 'Respuesta enviada';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Reaccionaste $emoji';
  }

  @override
  String get dmReelReplyFailed => 'No se pudo enviar';

  @override
  String get dmReelReplyUnverified => 'No se pudo confirmar el envío';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Tu reacción: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name reaccionó con $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Enviando reacción: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'La reacción falló, toca dos veces para reintentar';

  @override
  String get dmReactionChipRetryAnnouncement => 'Reintentando la reacción';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Termina de eliminar tu reacción anterior antes de añadir otra.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reacciones';

  @override
  String get dmReactionsViewA11yLabel => 'Ver quién reaccionó';

  @override
  String get dmReactionRemoveAction => 'Quitar';

  @override
  String get dmReactionRetryAction => 'Reintentar';

  @override
  String get dmFormatBold => 'Negrita';

  @override
  String get dmFormatItalic => 'Cursiva';

  @override
  String get dmFormatStrikethrough => 'Tachado';

  @override
  String get dmFormatCode => 'Código';

  @override
  String get dmStatusFailed => 'No se pudo enviar';

  @override
  String get inboxConversationActionsSheetLabel =>
      'Acciones de la conversación';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Conversación con $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'No leída, conversación con $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas más',
      one: '$count persona más',
    );
    return '$name y $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Mostrar acciones de la conversación';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Título: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Buscar...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count videos';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'No se pudo actualizar la suscripción. Probá de nuevo.';

  @override
  String get discoverListsTitle => 'Descubrir listas';

  @override
  String get discoverListsFailedToLoad => 'No se pudieron cargar las listas';

  @override
  String get discoverListsLoading => 'Descubriendo listas públicas...';

  @override
  String get discoverListsRelayTimeout =>
      'El relay no devolvió listas a tiempo. Inténtalo de nuevo.';

  @override
  String get discoverListsServiceUnavailable => 'Servicio no disponible.';

  @override
  String get discoverListsEmptyTitle => 'No se encontraron listas públicas';

  @override
  String get discoverListsEmptySubtitle =>
      'Volvé más tarde para ver listas nuevas';

  @override
  String get discoverListsByAuthorPrefix => 'por';

  @override
  String get curatedListEmptyTitle => 'No hay videos en esta lista';

  @override
  String get curatedListEmptySubtitle => 'Agregá algunos videos para arrancar';

  @override
  String get curatedListLoadingVideos => 'Cargando videos...';

  @override
  String get curatedListFailedToLoad => 'No se pudo cargar la lista';

  @override
  String get curatedListVideoNotAvailable => 'Video no disponible';

  @override
  String get curatedListActionsTooltip => 'Acciones de la lista';

  @override
  String get curatedListDeleteConfirmTitle => '¿Eliminar la lista?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Esto quita la lista de los relays. Los videos de la lista no se van a eliminar.';

  @override
  String get curatedListDeletedSnack => 'Lista eliminada';

  @override
  String get curatedListDeleteFailed => 'No se pudo eliminar la lista';

  @override
  String get peopleListsActionsTooltip => 'Acciones de la lista';

  @override
  String get listDeleteAction => 'Eliminar lista';

  @override
  String get peopleListsDeleteConfirmTitle => '¿Eliminar la lista?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Esto elimina la lista para todos. No vas a dejar de seguir a las personas que están en ella.';

  @override
  String get peopleListsDeleteFailed => 'No se pudo eliminar la lista';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonSomethingWentWrong => 'Algo salió mal';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonBack => 'Volver';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonNotNow => 'Ahora no';

  @override
  String get commonLoading => 'Cargando';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'No se pudo actualizar la portada. Inténtalo de nuevo.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Portada actualizada';

  @override
  String get videoMetadataC2paMissingTitle =>
      '¿Publicar sin la verificación de autenticidad?';

  @override
  String get videoMetadataC2paMissingBody =>
      'No pudimos añadir las credenciales de contenido, así que este vídeo no se confirmará como hecho por humanos. Vuelve a generarlo para intentarlo de nuevo o publícalo tal cual.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Las credenciales de contenido necesitan conexión a internet.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'El servicio de credenciales de contenido no respondió. No es cosa de tu conexión.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Volver a generar';

  @override
  String get videoMetadataC2paMissingSkip => 'Omitir';

  @override
  String get videoMetadataGenerationFailed => 'Generación fallida';

  @override
  String get videoMetadataTags => 'Etiquetas';

  @override
  String get videoMetadataExpiration => 'Vencimiento';

  @override
  String get videoMetadataExpirationNotExpire => 'No caduca';

  @override
  String get videoMetadataExpirationOneDay => '1 día';

  @override
  String get videoMetadataExpirationOneWeek => '1 semana';

  @override
  String get videoMetadataExpirationOneMonth => '1 mes';

  @override
  String get videoMetadataExpirationOneYear => '1 año';

  @override
  String get videoMetadataExpirationOneDecade => '1 década';

  @override
  String get videoMetadataContentWarnings => 'Advertencias de contenido';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Tendencias';

  @override
  String get libraryDeleteConfirm => 'Eliminar';

  @override
  String get libraryWebUnavailableHeadline =>
      'La biblioteca está en la app móvil';

  @override
  String get libraryWebUnavailableDescription =>
      'Los borradores y clips se guardan en tu dispositivo; abre Divine en el teléfono para gestionarlos.';

  @override
  String get libraryTabDrafts => 'Borradores';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'Eliminar clips seleccionados';

  @override
  String get libraryCloseSemanticLabel => 'Cerrar biblioteca';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'Dejar de seleccionar clips';

  @override
  String get librarySelectClipsSemanticLabel => 'Seleccionar clips';

  @override
  String get libraryGridSizeLabel => 'Tamaño de la cuadrícula';

  @override
  String get libraryDisplayOptionsLabel => 'Orden y tamaño de cuadrícula';

  @override
  String get libraryMoreActionsSemanticLabel => 'Más acciones de la biblioteca';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count columnas',
      one: '1 columna',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Seleccionar';

  @override
  String get librarySortNewestCreation => 'Creación más reciente';

  @override
  String get librarySortOldestCreation => 'Creación más antigua';

  @override
  String get librarySortLongestClip => 'Clip más largo';

  @override
  String get librarySortShortestClip => 'Clip más corto';

  @override
  String get librarySortSquareFirst => 'Cuadrados primero';

  @override
  String get librarySortVerticalFirst => 'Verticales primero';

  @override
  String get libraryDeleteClipsWarning =>
      'No se puede deshacer. Los archivos de video se eliminarán permanentemente de tu dispositivo.';

  @override
  String get libraryPreparingVideo => 'Preparando video...';

  @override
  String libraryCreateVideo(int count) {
    return 'Crear video ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return '$_temp0 guardados en $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount guardados, $failureCount fallidos';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'No se pudo guardar en $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permiso denegado para $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminaron $count clips',
      one: 'Se eliminó 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Deshacer';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Se elimina automáticamente en $daysLeft días',
      one: 'Se elimina automáticamente mañana',
      zero: 'Se elimina automáticamente hoy',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'No se pudieron cargar los borradores';

  @override
  String get libraryCouldNotLoadClips => 'No se pudieron cargar los clips';

  @override
  String get libraryOpenErrorDescription =>
      'Algo salió mal al abrir tu biblioteca. Puedes intentarlo de nuevo.';

  @override
  String get libraryNoDraftsYetTitle => 'Aún no hay borradores';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Los videos que guardes como borrador aparecerán aquí';

  @override
  String get libraryNoClipsYetTitle => 'Aún no hay clips';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Tus clips de video grabados aparecerán aquí';

  @override
  String get libraryDraftDeletedSnackbar => 'Borrador eliminado';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'No se pudo eliminar el borrador';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Borrador duplicado';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'No se pudo duplicar el borrador';

  @override
  String get libraryDraftInProgressBadge => 'En curso';

  @override
  String get libraryDraftActionPost => 'Publicar';

  @override
  String get libraryDraftActionEdit => 'Editar';

  @override
  String get libraryDraftActionDuplicate => 'Duplicar';

  @override
  String get libraryDraftActionDelete => 'Eliminar borrador';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (copia $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Eliminar borrador';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '¿Seguro que quieres eliminar \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Eliminar clip';

  @override
  String get libraryDeleteClipMessage =>
      '¿Seguro que quieres eliminar este clip?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds s';
  }

  @override
  String get libraryRecordVideo => 'Grabar un video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Clip de vídeo, $duration segundos';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Archivado. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Clip de stop motion, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Seleccionado, número $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Seleccionado';

  @override
  String get videoClipSemanticValueNotSelected => 'No seleccionado';

  @override
  String get videoClipSemanticHintDisabled => 'Deshabilitado';

  @override
  String get videoClipSemanticHintSelect =>
      'Toca para seleccionar, mantén para previsualizar';

  @override
  String get videoClipSemanticHintDeselect =>
      'Toca para deseleccionar, mantén para previsualizar';

  @override
  String get routerInvalidCreator => 'Creador no válido';

  @override
  String get routerInvalidHashtagRoute => 'Ruta de hashtag no válida';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'No se pudieron cargar los videos';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'No hay videos en esta categoría';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Opciones de orden de la categoría';

  @override
  String get categoryGallerySortHot => 'Populares';

  @override
  String get categoryGallerySortNew => 'Nuevos';

  @override
  String get categoryGallerySortClassic => 'Clásicos';

  @override
  String get categoryGallerySortForYou => 'Para vos';

  @override
  String get categoriesCouldNotLoadCategories =>
      'No se pudieron cargar las categorías';

  @override
  String get categoriesNoCategoriesAvailable => 'No hay categorías disponibles';

  @override
  String get notificationsEmptyTitle => 'Todavía no hay actividad';

  @override
  String get notificationsEmptySubtitle =>
      'Cuando alguien interactúe con tu contenido, lo vas a ver acá';

  @override
  String get appsPermissionsTitle => 'Permisos de integración';

  @override
  String get appsPermissionsRevoke => 'Revocar';

  @override
  String get appsPermissionsEmptyTitle =>
      'No hay permisos de integración guardados';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Las integraciones aprobadas van a aparecer acá después de que recuerdes una autorización de acceso.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName pide tu autorización';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Esta app está pidiendo acceso a través del sandbox aprobado de Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Origen';

  @override
  String get nostrAppPermissionMethod => 'Método';

  @override
  String get nostrAppPermissionCapability => 'Capacidad';

  @override
  String get nostrAppPermissionEventKind => 'Tipo de evento';

  @override
  String get nostrAppPermissionAllow => 'Permitir';

  @override
  String get appsDetailDefaultTitle => 'App integrada';

  @override
  String get appsDetailNotFoundTitle => 'Integración no encontrada';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Esta integración aprobada ya no está disponible en Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Cómo funciona';

  @override
  String get appsDetailHowItWorksBody =>
      'Esta es una app de terceros aprobada que funciona dentro de Divine. Divine solo otorga capacidades revisadas para esta integración y bloquea la navegación fuera de sus orígenes aprobados.';

  @override
  String get appsDetailAboutTitle => 'Acerca de';

  @override
  String get appsDetailPrimaryOriginTitle => 'Origen principal';

  @override
  String get appsDetailApprovedOriginsTitle => 'Orígenes aprobados';

  @override
  String get appsDetailCapabilitiesTitle => 'Capacidades disponibles';

  @override
  String get appsDetailAskBeforeTitle => 'Preguntar antes de';

  @override
  String get appsDetailOpenButton => 'Abrir integración';

  @override
  String get appsDetailNoneDeclared => 'Todavía no se declaró ninguna';

  @override
  String get appsDirectoryTitle => 'Apps integradas';

  @override
  String get appsDirectoryIntroTitle => 'Apps de terceros aprobadas';

  @override
  String get appsDirectoryIntroBody =>
      'Apps de terceros aprobadas que funcionan dentro de Divine';

  @override
  String get appsDirectoryErrorTitle =>
      'No se pudieron cargar las apps integradas';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Deslizá para volver a intentar con las integraciones aprobadas.';

  @override
  String get appsDirectoryEmptyTitle =>
      'Todavía no hay integraciones aprobadas';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Las apps de terceros aprobadas van a aparecer acá a medida que Divine las agregue.';

  @override
  String get appsDirectoryRefresh => 'Actualizar';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Las apps integradas funcionan en Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Por ahora, las integraciones aprobadas solo están disponibles en el móvil.';

  @override
  String get appsSandboxUnavailableTitle => 'Integración no disponible';

  @override
  String get appsSandboxUnavailableBody =>
      'Abrí las integraciones aprobadas desde la pestaña Apps integradas para que Divine pueda aplicar la política de acceso correcta.';

  @override
  String get appsSandboxLoadingTitle => 'Cargando integración';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Verificando la integración aprobada antes de abrirla.';

  @override
  String get appsSandboxBlockedTitle => 'Bloqueado por seguridad';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Esta integración intentó salir de su origen aprobado.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink =>
      'Enlace a la publicación copiado al portapapeles';

  @override
  String get shareCopiedEventJson =>
      'JSON del evento de Nostr copiado al portapapeles';

  @override
  String get shareCopiedEventId =>
      'ID del evento de Nostr copiado al portapapeles';

  @override
  String get authHeroTaglineAuthentic => 'Momentos auténticos.';

  @override
  String get authHeroTaglineHuman => 'Creatividad humana.';

  @override
  String get keyImportFailedToImport =>
      'No se pudo importar la clave o conectar el bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'URL de bunker inválida';

  @override
  String get keyImportInvalidFormat =>
      'Formato inválido. Usá nsec..., hex, ncryptsec1... o bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Formato de nsec inválido. Debe tener 63 caracteres';

  @override
  String get keyImportKeyFieldLabel => 'Clave privada o URL de bunker';

  @override
  String get keyImportKeyRequired => 'Ingresá tu clave privada o URL de bunker';

  @override
  String get keyImportPasswordRequired =>
      'Ingresá la contraseña de esta clave cifrada';

  @override
  String get keyImportSecurityWarningBody =>
      'Nunca compartas tu clave privada con nadie. Esta clave da acceso total a tu identidad de Nostr.';

  @override
  String get keyImportSecurityWarningTitle =>
      '¡Mantené tu clave privada segura!';

  @override
  String get keyImportSubtitle =>
      'Importá tu identidad de Nostr existente usando tu clave privada o una URL de bunker.';

  @override
  String get keyImportTitle => 'Importá tu\nidentidad de Nostr';

  @override
  String get commentAuthorYouIndicator => 'Vos';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Ver el perfil de $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Eliminar comentario';

  @override
  String get commentOptionsEditSemanticLabel => 'Editar comentario';

  @override
  String get commentOptionsFlagContentLabel => 'Marcar contenido';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Marcar este contenido';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Elegí un motivo para marcar este comentario';

  @override
  String get commentOptionsFlagSubmit => 'Enviar';

  @override
  String get commentOptionsTitle => 'Opciones';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Todavía estamos importando los comentarios viejos del archivo. Aún no están listos.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Editando';

  @override
  String get commentsInputSemanticHint => 'Agregar un comentario';

  @override
  String get commentsInputSemanticHintEdit => 'Editar comentario';

  @override
  String get commentsInputSemanticHintReply => 'Agregar una respuesta';

  @override
  String get commentsInputSemanticLabel => 'Campo de comentario';

  @override
  String get commentsInputSemanticLabelEdit => 'Campo de edición';

  @override
  String get commentsInputSemanticLabelReply => 'Campo de respuesta';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Ver el perfil de $displayName';
  }

  @override
  String get classicsEmptyDescription =>
      'El archivo de Clásicos se está cargando';

  @override
  String get classicsEmptyTitle => 'No se encontraron Clásicos';

  @override
  String get classicsErrorTitle => 'Error al cargar los Clásicos';

  @override
  String get classicsUnavailableDescription =>
      'Los Clásicos solo están disponibles cuando estás conectado a relays de Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Cambiá a un relay con Funnelcake en Ajustes para acceder al archivo de Clásicos.';

  @override
  String get classicsUnavailableTitle => 'Clásicos no disponibles';

  @override
  String get hashtagFeedEmptySubtitle =>
      '¡Sé el primero en publicar un video con este hashtag!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'No se encontraron videos para #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Esto puede tardar unos momentos';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Cargando videos sobre #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Agregá hashtags... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Volvé más tarde para ver contenido nuevo';

  @override
  String get newVideosTabEmptyTitle => 'No hay videos en Videos nuevos';

  @override
  String get popularVideosContextTitle => 'Videos populares';

  @override
  String get popularVideosEmptySubtitle =>
      'Volvé más tarde para ver contenido nuevo';

  @override
  String get popularVideosEmptyTitle => 'No hay videos en Videos populares';

  @override
  String get popularVideosErrorTitle =>
      'Error al cargar los videos en tendencia';

  @override
  String get popularVideosFeedSourceLabel => 'Fuente del feed popular';

  @override
  String get trendingHashtagsLoading => 'Cargando hashtags...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Ver videos etiquetados con $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Autor del video: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Descripción del video: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'La visión de Divine es darte una verdadera elección algorítmica. En lugar de quedar atado a un único algoritmo de caja negra, vas a poder elegir entre varios enfoques de recomendación:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Línea de tiempo cronológica de los creadores que seguís';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Esto te pone a vos al control de tu atención en lugar de dejársela a la plataforma. Deberías saber cómo se cura tu feed y tener el poder de cambiarlo cuando quieras.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Feeds personalizados creados por la comunidad para temas como música, comedia o arte';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Feed \"Para ti\" personalizado';

  @override
  String get forYouAlgorithmChoiceTitle => 'Tu algoritmo, tu elección';

  @override
  String get forYouAlgorithmChoiceTrending =>
      'Contenido en tendencia y popular';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Señal fuerte — te interesó lo suficiente como para responder';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine presta atención a cómo interactuás con el contenido para entender qué disfrutás. Cada vez que mirás un video, le das una reacción, dejás un comentario o lo reposteás, el sistema toma nota.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Cómo funciona';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Las distintas acciones indican distintos niveles de interés:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Si todavía no tenés un historial de visualización, te mostramos una mezcla de lo que es popular y está en tendencia junto con subidas recientes. Esto te da un gran punto de partida para explorar.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'A medida que mirás, das me gusta e interactuás con el contenido, las recomendaciones se vuelven cada vez más personalizadas. Con el tiempo, tu feed Para ti muestra videos de creadores que quizás nunca habrías descubierto por tu cuenta.';

  @override
  String get forYouAlgorithmNewToDivineTitle => '¿Nuevo en Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Estamos construyendo un sistema abierto donde los desarrolladores pueden implementar sus propios algoritmos, y vos podés elegir cuáles usar — o no usar ninguno.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Código abierto y transparente';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Señal media — una forma rápida de mostrar aprecio';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reacciones';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'La señal más fuerte — compartir con tus seguidores es un respaldo poderoso';

  @override
  String get forYouAlgorithmSubtitle =>
      'Con la tecnología de Gorse, un motor de recomendación de código abierto';

  @override
  String get forYouAlgorithmTitle => 'El algoritmo de Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Señal leve — indica interés básico';

  @override
  String get forYouEmptyDescription =>
      'Mirá y dale me gusta a algunos videos para recibir recomendaciones personalizadas.';

  @override
  String get forYouEmptyTitle => 'Todavía no hay recomendaciones';

  @override
  String get forYouErrorTitle => 'Error al cargar las recomendaciones';

  @override
  String get forYouUnavailableDescription =>
      'Las recomendaciones personalizadas requieren conexión con Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Para ti no disponible';

  @override
  String get inboxConversationOptionsLabel => 'Opciones';

  @override
  String get inboxConversationViewProfileButton => 'Ver perfil';

  @override
  String get inboxMessageRequestsEmpty => 'No hay solicitudes de mensaje';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Solicitudes de mensaje, $requestCount pendientes';
  }

  @override
  String get inboxMessageRequestsTitle => 'Solicitudes de mensaje';

  @override
  String get inboxMessagesTab => 'Mensajes';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Solicitud de mensaje de $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Envió una solicitud de mensaje';

  @override
  String get inboxRequestsMarkAllRead =>
      'Marcar todas las solicitudes como leídas';

  @override
  String get inboxRequestsRemoveAll => 'Eliminar todas las solicitudes';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Rechazar y eliminar';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Rechazaste la solicitud de $displayName';
  }

  @override
  String get messageRequestLoadFailed => 'No se pudo cargar esta solicitud.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count seguidores';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count videos';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes',
      one: '1 mensaje',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Ver mensajes';

  @override
  String get messageRequestViewProfileButton => 'Ver perfil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName quiere escribirte, envió $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Cambiaste de cuenta, así que no se eliminó nada. Volvé a abrir la eliminación para la cuenta que querés borrar.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Para confirmar, escribí:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Para confirmar, escribí tu nombre de usuario:';

  @override
  String get deleteAccountConfirmationHint => 'Escribí DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'Escribí tu nombre de usuario';

  @override
  String get deleteAccountDeleteAllContentButton =>
      'Eliminar todo el contenido';

  @override
  String get accountDeletionRecoveryTitle => 'Eliminando tu cuenta';

  @override
  String get accountDeletionRecoveryBody =>
      'No pudimos terminar de eliminar tu cuenta. Tu nombre de usuario está reservado para vos y todavía se puede recuperar.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Recuperar mi nombre de usuario';

  @override
  String get accountDeletionFinishingBody =>
      'Tu solicitud de eliminación todavía se está procesando. Podés usar otra cuenta mientras terminamos.';

  @override
  String get accountDeletionOtherAccountPending =>
      'En este dispositivo todavía se está procesando la eliminación de otra cuenta. Esperá a que termine antes de eliminar esta cuenta.';

  @override
  String get accountDeletionCancellingBody =>
      'Estamos cancelando tu eliminación. Revisá de nuevo antes de salir de esta pantalla.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Todavía no pudimos recuperar tu nombre de usuario. Revisá tu conexión y probá de nuevo.';

  @override
  String get accountDeletionUsernameRestored =>
      'Tu nombre de usuario está recuperado. Tu cuenta no fue eliminada.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'No pudimos consultar el estado de tu eliminación. Revisá tu conexión y probá de nuevo.';

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
      'La eliminación de cuentas no está disponible en este momento. No se eliminó nada.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'No pudimos terminar de eliminar tu cuenta. Probá de nuevo.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Confirmación final';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Solicitudes de eliminación enviadas, pero es posible que tus claves no se hayan quitado por completo de este dispositivo. Andá a Ajustes → Claves de Nostr → Quitar claves para reintentar.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Solicitudes de eliminación enviadas y se cerró tu sesión, pero no se pudieron quitar algunos datos locales de este dispositivo.';

  @override
  String get deleteAccountPreparingDeletion => 'Preparando la eliminación...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total eventos';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Esto quita el inicio de sesión local de esta cuenta de este dispositivo. No va a eliminar tu cuenta de Divine ni tu identidad de Nostr.\n\nTus borradores y clips quedan guardados en este dispositivo para esta cuenta. Si esta es tu última cuenta local, vas a volver a la pantalla de inicio de sesión.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Quitar del dispositivo';

  @override
  String get deleteAccountRemoveKeysTitle =>
      '¿Quitar esta cuenta de este dispositivo?';

  @override
  String get deleteAccountReauthRequired =>
      'Inicia sesión de nuevo para eliminar tu cuenta. Todavía no se ha eliminado nada.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Se enviaron las solicitudes de eliminación de tus publicaciones, pero no pudimos terminar de eliminar tu cuenta. Probá de nuevo en un rato.';

  @override
  String get deleteAccountSuccess =>
      'Tu cuenta de Divine fue eliminada. Se enviaron solicitudes para eliminar tus publicaciones de Nostr, pero algunos relays, clientes o cachés pueden conservar copias.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Eliminación de cuenta solicitada. No se pudo confirmar de forma individual la eliminación de algunas publicaciones existentes.';

  @override
  String get deleteAccountWarningBody =>
      'Esto envía solicitudes de eliminación de tu cuenta y contenido, elimina tu cuenta de Divine cuando es posible y cierra tu sesión en este dispositivo. Algunos relays, clientes e índices de búsqueda pueden conservar copias. Otros dispositivos con la sesión iniciada siguen activos hasta que quites las claves ahí.';

  @override
  String get findPeopleNoContacts =>
      'No se encontraron contactos.\nEmpezá a seguir personas para verlas acá.';

  @override
  String get geoBlockedCityLabel => 'Ciudad';

  @override
  String get geoBlockedCountryLabel => 'País';

  @override
  String get geoBlockedDefaultReason =>
      'Este servicio no está disponible en tu región debido a regulaciones locales.';

  @override
  String get geoBlockedLegalNotice =>
      'Respetamos las leyes y regulaciones de tu zona. Esta restricción se basa en la ubicación de tu dirección IP.';

  @override
  String get geoBlockedRegionLabel => 'Región';

  @override
  String get geoBlockedTitle => 'Servicio no disponible';

  @override
  String get likedVideosEmpty => 'No hay videos con me gusta';

  @override
  String get likedVideosInvalidRoute => 'Ruta inválida';

  @override
  String get likedVideosTitle => 'Videos con me gusta';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Reintentando la subida…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Guardar en borradores';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar =>
      'Guardado en borradores';

  @override
  String get uploadFailureSheetTitle => 'Error en la subida';

  @override
  String get uploadFailureSheetTryAgainButton => 'Intentar de nuevo';

  @override
  String get videoEditorAudioImportAudio => 'Importar audio';

  @override
  String get videoEditorAudioImportFailed => 'Falló la importación del audio.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn => 'Iniciá sesión para publicar vídeos.';

  @override
  String get publishErrorNoRetry => 'No hay ninguna subida para reintentar.';

  @override
  String get publishErrorNoInternet =>
      'Sin conexión a internet. Revisá tu Wi-Fi o los datos móviles e intentá de nuevo.';

  @override
  String get publishErrorServerUnreachable =>
      'No pudimos conectar con el servidor. Intentá de nuevo en un momento.';

  @override
  String get publishErrorTimeout =>
      'Se agotó el tiempo de la subida. Probá con una conexión más estable o un vídeo más liviano.';

  @override
  String get publishErrorTls =>
      'Falló la conexión segura. Revisá tu red—las redes Wi-Fi públicas pueden bloquear las subidas.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'El servidor de medios ($serverName) no está disponible. Podés elegir otro en tus ajustes.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'El archivo de vídeo es demasiado grande para el servidor. Probá recortándolo o bajando la calidad.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'El servidor de medios ($serverName) tuvo un error interno. Podés elegir otro en tus ajustes.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'El servidor de medios ($serverName) está caído temporalmente. Intentá de nuevo en un rato o elegí otro en tus ajustes.';
  }

  @override
  String get publishErrorForbidden =>
      'No tenés permiso para subir a este servidor.';

  @override
  String get publishErrorFileNotFound =>
      'No se encontró el archivo de vídeo. Puede que se haya eliminado. Grabá de nuevo e intentá otra vez.';

  @override
  String get publishErrorLowStorage =>
      'No hay suficiente almacenamiento en tu dispositivo. Liberá espacio e intentá de nuevo.';

  @override
  String get publishErrorThumbnailFailed =>
      'El vídeo se subió, pero no se pudo preparar la miniatura. Intentá de nuevo.';

  @override
  String get publishErrorNostrPublishFailed =>
      'El vídeo se subió, pero no se pudo completar la publicación. Revisá tus ajustes de relays e intentá de nuevo.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'El vídeo se subió, pero su sonido no está habilitado para reutilizarse. Elegí otro sonido para publicarlo.';

  @override
  String get publishErrorInterrupted =>
      'Esta subida se interrumpió. ¿Querés intentar de nuevo?';

  @override
  String get publishErrorAccountChanged =>
      'Este video es de otra cuenta. Volvé a esa cuenta para publicarlo.';

  @override
  String get publishErrorGeneric => 'Algo salió mal. Intentá de nuevo.';

  @override
  String get publishErrorRateLimited =>
      'Demasiadas subidas ahora mismo. Esperá un momento e intentá de nuevo.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Tu sesión de subida expiró. Intentá de nuevo.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine no tiene permiso para subir. Revisá los permisos de la app en tus ajustes e intentá de nuevo.';

  @override
  String get publishErrorOutOfMemory =>
      'Tu dispositivo se está quedando sin memoria. Cerrá algunas apps e intentá de nuevo.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'No se pudieron preparar el texto y los stickers de este borrador. Abrilo en el editor y publicá de nuevo.';

  @override
  String get publishErrorUnknownServer => 'Servidor desconocido';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filtro: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'No se encontraron resultados para \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Ver videos etiquetados con $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Sonido: $soundName de $creatorName. Tocá para ver los detalles del sonido.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Sonido original de $creatorName. Tocá para usar este sonido.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Sonido: $soundName de $creatorName. Tocá para ver los detalles.';
  }

  @override
  String get soundDetailLoadError =>
      'Error al cargar el sonido. Probá de nuevo.';

  @override
  String get soundDetailNotFoundMessage => 'No se pudo encontrar este sonido';

  @override
  String get soundDetailNotFoundTitle => 'Sonido no encontrado';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loops';
  }

  @override
  String get originalSoundUnavailableBody =>
      'El audio de este video no está disponible por separado.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Sonido original - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Esta persona publicó un Vine original que Divine encontró en el archivo. No es una insignia de verificación de cuenta.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Tilde de perfil';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine da esta tilde a las cuentas del equipo. Es independiente de NIP-05, de los enlaces de cuenta verificados y del estado OG Viner.';

  @override
  String get unfollowConfirmButton => 'Dejar de seguir';

  @override
  String get videoClipSaveFailed => 'No se pudo guardar el clip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Guardar en $destination';
  }

  @override
  String get videoClipDelete => 'Eliminar clip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirado en $creatorName +$additionalCreatorCount. Tocá para ver su perfil.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspirado en $creatorName. Tocá para ver su perfil.';
  }

  @override
  String get bugReportSendReport => 'Enviar reporte';

  @override
  String get supportSubjectRequiredLabel => 'Asunto *';

  @override
  String get supportPublicSubmissionTitle => 'Publicación pública en GitHub';

  @override
  String get supportPublicSubmissionMessage =>
      'Todo lo que envíes aquí se publicará en nuestro repositorio de código abierto en GitHub para que los desarrolladores puedan encargarse. La publicación y la cuenta con la que has iniciado sesión serán visibles para todo el mundo.';

  @override
  String get supportRequiredHelper => 'Obligatorio';

  @override
  String get supportFieldLimitReached =>
      'Esa es la longitud máxima. Lo que pasa de ahí no se añadió.';

  @override
  String get bugReportSubjectHint => 'Resumen breve del problema';

  @override
  String get bugReportDescriptionRequiredLabel => '¿Qué pasó? *';

  @override
  String get bugReportDescriptionHint => 'Describí el problema que tuviste';

  @override
  String get bugReportStepsLabel => 'Pasos para reproducirlo';

  @override
  String get bugReportStepsHint =>
      '1. Ir a...\n2. Tocar en...\n3. Ver el error';

  @override
  String get bugReportExpectedBehaviorLabel => 'Comportamiento esperado';

  @override
  String get bugReportExpectedBehaviorHint =>
      '¿Qué tendría que haber pasado en su lugar?';

  @override
  String get bugReportDiagnosticsNotice =>
      'La info del dispositivo y los logs se incluyen automáticamente.';

  @override
  String get bugReportSuccessMessage =>
      '¡Gracias! Recibimos tu reporte y lo vamos a usar para hacer Divine mejor.';

  @override
  String get bugReportAttachImages => 'Adjuntar imágenes';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count de $max imágenes seleccionadas';
  }

  @override
  String get bugReportRemoveImage => 'Quitar imagen';

  @override
  String get bugReportUploadFailed =>
      'No pudimos subir la imagen elegida. Inténtalo de nuevo o manda el informe sin ella.';

  @override
  String get bugReportSendFailed =>
      'No se pudo enviar el reporte de bug. Probá de nuevo más tarde.';

  @override
  String get featureRequestSendRequest => 'Enviar pedido';

  @override
  String get featureRequestSubjectHint => 'Resumen breve de tu idea';

  @override
  String get featureRequestDescriptionRequiredLabel => '¿Qué te gustaría? *';

  @override
  String get featureRequestDescriptionHint => 'Describí la función que querés';

  @override
  String get featureRequestUsefulnessLabel => '¿En qué te resultaría útil?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explicá qué beneficio traería esta función';

  @override
  String get featureRequestWhenLabel => '¿Cuándo la usarías?';

  @override
  String get featureRequestWhenHint =>
      'Describí las situaciones en las que ayudaría';

  @override
  String get featureRequestSuccessMessage =>
      '¡Gracias! Recibimos tu pedido y lo vamos a revisar.';

  @override
  String get featureRequestSendFailed =>
      'No se pudo enviar el pedido. Probá de nuevo más tarde.';

  @override
  String get notificationFollowBack => 'Seguir de vuelta';

  @override
  String get followingTitle => 'Siguiendo';

  @override
  String followingTitleForName(String displayName) {
    return 'Cuentas que sigue $displayName';
  }

  @override
  String get followingFailedToLoadList =>
      'No se pudo cargar la lista de seguidos';

  @override
  String get followingEmptyTitle => 'Todavía no seguís a nadie';

  @override
  String get followersTitle => 'Seguidores';

  @override
  String followersTitleForName(String displayName) {
    return 'Seguidores de $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'No se pudo cargar la lista de seguidores';

  @override
  String get followersEmptyTitle => 'Todavía no hay seguidores';

  @override
  String get followersUpdateFollowFailed =>
      'No se pudo actualizar el estado de seguimiento. Probá de nuevo.';

  @override
  String get followersSortSemanticLabel => 'Ordenar seguidores';

  @override
  String get followingSortSemanticLabel => 'Ordenar seguidos';

  @override
  String get followSortTitle => 'Ordenar por';

  @override
  String get followSortNewest => 'Más recientes primero';

  @override
  String get followSortOldest => 'Más antiguos primero';

  @override
  String get newMessageTitle => 'Mensaje nuevo';

  @override
  String get newMessageFindPeople => 'Buscar personas';

  @override
  String get newMessageNoContacts =>
      'No se encontraron contactos.\nSeguí a personas para verlas acá.';

  @override
  String get newMessageNoUsersFound => 'No se encontraron usuarios';

  @override
  String get hashtagSearchTitle => 'Buscá hashtags';

  @override
  String get hashtagSearchSubtitle => 'Descubrí temas y contenido en tendencia';

  @override
  String hashtagSearchNoResults(String query) {
    return 'No se encontraron hashtags para \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Falló la búsqueda';

  @override
  String get userNotAvailableTitle => 'Cuenta no disponible';

  @override
  String get userNotAvailableBody =>
      'Esta cuenta no está disponible en este momento.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'No se pudieron guardar los ajustes. Probá de nuevo.';

  @override
  String get blossomValidServerUrl =>
      'Ingresá una URL de servidor válida (ej., https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Ajustes de Blossom guardados';

  @override
  String get blossomSaveTooltip => 'Guardar';

  @override
  String get blossomAboutTitle => 'Acerca de Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom es un protocolo descentralizado de almacenamiento de medios que te permite subir videos a cualquier servidor compatible. Por defecto, los videos se suben al servidor Blossom de Divine. Activá la opción de abajo para usar un servidor propio.';

  @override
  String get blossomUseCustomServer => 'Usar un servidor Blossom propio';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Tus videos se van a subir a tu servidor Blossom propio';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Tus videos se están subiendo al servidor Blossom de Divine';

  @override
  String get blossomCustomServerUrl => 'URL del servidor Blossom propio';

  @override
  String get blossomCustomServerHelper =>
      'Ingresá la URL de tu servidor Blossom propio';

  @override
  String get blossomPopularServers => 'Servidores Blossom populares';

  @override
  String get blossomServerUrlMustUseHttps =>
      'La URL del servidor Blossom tiene que usar https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'No se pudo actualizar la configuración de crosspost';

  @override
  String get blueskySignInRequired =>
      'Iniciá sesión para gestionar los ajustes de Bluesky';

  @override
  String get blueskyPublishVideos => 'Publicar videos en Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Tus videos se van a publicar en Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Tus videos no se van a publicar en Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Tus videos anteriores también se publicarán';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Cuando actives esto, Divine empezará a enviar tus videos antiguos a Bluesky, primero los más viejos, sin apurar el límite diario.';

  @override
  String get blueskyHandle => 'Handle de Bluesky';

  @override
  String get blueskyDid => 'DID de Bluesky';

  @override
  String get blueskyStatus => 'Estado';

  @override
  String get blueskyStatusReady => 'Cuenta lista y aprovisionada';

  @override
  String get blueskyStatusPending => 'Aprovisionando la cuenta...';

  @override
  String get blueskyStatusFailed => 'Falló el aprovisionamiento de la cuenta';

  @override
  String get blueskyStatusDisabled => 'Cuenta deshabilitada';

  @override
  String get blueskyStatusNotLinked =>
      'No hay ninguna cuenta de Bluesky vinculada';

  @override
  String get blueskyUsernameRequired =>
      'Configura un identificador divine.video antes de publicar en Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Publicar en Bluesky necesita un identificador usuario.divine.video ya reservado.';

  @override
  String get blueskyUsernameSyncPending =>
      'Tu identificador de Divine está reservado. Lo estamos vinculando con Bluesky: inténtalo de nuevo en un momento.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'No pudimos comprobar tu identificador de Divine. Inténtalo de nuevo.';

  @override
  String get blueskySetUpHandle => 'Configurar';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Publicar en Bluesky no está disponible por ahora. Inténtalo de nuevo.';

  @override
  String get invitesTitle => 'Invitar amigos';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitaciones listas para generar',
      one: '1 invitación lista para generar',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Genera un código cuando estés listo para compartirlo.';

  @override
  String get invitesGenerateButtonLabel => 'Generar invitación';

  @override
  String get invitesNoneAvailable => 'No hay invitaciones disponibles ahora';

  @override
  String get invitesShareWithPeople =>
      'Compartí Divine con la gente que conocés';

  @override
  String get invitesUsedInvites => 'Invitaciones usadas';

  @override
  String invitesShareMessage(String code) {
    return '¡Sumate a Divine! Usá el código de invitación $code para arrancar:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copiar invitación';

  @override
  String get invitesCopied => '¡Invitación copiada!';

  @override
  String get invitesShareInvite => 'Compartir invitación';

  @override
  String get invitesShareSubject => 'Sumate a Divine';

  @override
  String get invitesClaimed => 'Reclamada';

  @override
  String get invitesCouldNotLoad => 'No se pudieron cargar las invitaciones';

  @override
  String get invitesRetry => 'Reintentar';

  @override
  String get searchSomethingWentWrong => 'Algo salió mal';

  @override
  String get searchTryAgain => 'Reintentar';

  @override
  String get searchForLists => 'Buscar listas';

  @override
  String get searchFindCuratedVideoLists => 'Encontrá listas de videos curadas';

  @override
  String get searchEnterQuery => 'Ingresá una búsqueda';

  @override
  String get searchDiscoverSomethingInteresting => 'Descubrí algo interesante';

  @override
  String get searchPeopleSectionHeader => 'Personas';

  @override
  String get searchPeopleLoadingLabel => 'Cargando resultados de personas';

  @override
  String get searchTagsSectionHeader => 'Etiquetas';

  @override
  String get searchTagsLoadingLabel => 'Cargando resultados de etiquetas';

  @override
  String get searchVideosSectionHeader => 'Videos';

  @override
  String get searchVideosLoadingLabel => 'Cargando resultados de videos';

  @override
  String get searchVideosSortOptionsLabel => 'Ordenar los resultados de video';

  @override
  String get searchVideosSortTrending => 'Popular';

  @override
  String get searchVideosSortLoops => 'Más loops';

  @override
  String get searchVideosSortEngagement => 'Más interacción';

  @override
  String get searchVideosSortRecent => 'Reciente';

  @override
  String get searchListsSectionHeader => 'Listas';

  @override
  String get searchListsLoadingLabel => 'Cargando resultados de listas';

  @override
  String get cameraAgeRestriction =>
      'Tenés que tener 16 años o más para crear contenido';

  @override
  String get keyImportInsecureBunkerRelay =>
      'El relay del bunker tiene que usar wss:// (ws:// solo se permite para localhost)';

  @override
  String get timeNow => 'ahora';

  @override
  String timeShortMinutes(int count) {
    return '${count}m';
  }

  @override
  String timeShortHours(int count) {
    return '${count}h';
  }

  @override
  String timeShortDays(int count) {
    return '${count}d';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}sem';
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
  String get timeVerboseNow => 'Ahora';

  @override
  String timeAgo(String time) {
    return 'hace $time';
  }

  @override
  String get timeToday => 'Hoy';

  @override
  String get timeYesterday => 'Ayer';

  @override
  String get timeJustNow => 'recién';

  @override
  String timeMinutesAgo(int count) {
    return 'hace ${count}m';
  }

  @override
  String timeHoursAgo(int count) {
    return 'hace ${count}h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'hace ${count}d';
  }

  @override
  String get draftTimeJustNow => 'Recién';

  @override
  String get contentLabelNudity => 'Desnudez';

  @override
  String get contentLabelSexualContent => 'Contenido sexual';

  @override
  String get contentLabelPornography => 'Pornografía';

  @override
  String get contentLabelGraphicMedia => 'Contenido explícito';

  @override
  String get contentLabelViolence => 'Violencia';

  @override
  String get contentLabelSelfHarm => 'Autolesión/Suicidio';

  @override
  String get contentLabelDrugUse => 'Consumo de drogas';

  @override
  String get contentLabelAlcohol => 'Alcohol';

  @override
  String get contentLabelTobacco => 'Tabaco/Fumar';

  @override
  String get contentLabelGambling => 'Apuestas';

  @override
  String get contentLabelProfanity => 'Lenguaje soez';

  @override
  String get contentLabelHateSpeech => 'Discurso de odio';

  @override
  String get contentLabelHarassment => 'Acoso';

  @override
  String get contentLabelFlashingLights => 'Luces intermitentes';

  @override
  String get contentLabelAiGenerated => 'Generado por IA';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Estafa/Fraude';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Engañoso';

  @override
  String get contentLabelSensitiveContent => 'Contenido sensible';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName le dio like a tu video';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName le dio like a tu comentario';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName comentó tu video';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName empezó a seguirte';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName te mencionó';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName compartió tu video';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName publicó un nuevo vine';
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
      other: '$count de tus vines',
      one: 'tu vine',
    );
    return '$actorName añadió $_temp0 a $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName respondió a tu comentario';
  }

  @override
  String get notificationAndConnector => 'y';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas más',
      one: '1 persona más',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Tienes una nueva actualización';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Ocultar el teclado';

  @override
  String get commentsErrorLoadFailed => 'No se pudieron cargar los comentarios';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Inicia sesión para comentar';

  @override
  String get commentsErrorPostCommentFailed =>
      'No se pudo publicar el comentario';

  @override
  String get commentsErrorPostReplyFailed => 'No se pudo publicar la respuesta';

  @override
  String get commentsErrorEditFailed => 'No se pudo editar el comentario';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Inicia sesión para participar';

  @override
  String get commentsErrorVoteFailed => 'No se pudo votar el comentario';

  @override
  String get commentsErrorReportFailed => 'No se pudo denunciar el comentario';

  @override
  String get commentsErrorBlockFailed => 'No se pudo bloquear a la persona';

  @override
  String get commentsErrorDeleteFailed => 'No se pudo borrar el comentario';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentarios',
      one: '$count comentario',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Publicando…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Tu respuesta en vídeo se está publicando';

  @override
  String get commentsSortNew => 'Nuevos';

  @override
  String get commentsSortTop => 'Mejores';

  @override
  String get commentsSortOld => 'Antiguos';

  @override
  String get commentsSortSemanticLabel => 'Orden de los comentarios';

  @override
  String get commentReply => 'Responder';

  @override
  String get commentReplySemanticLabel => 'Responder al comentario';

  @override
  String get commentUpvoteLabel => 'Votar a favor del comentario';

  @override
  String get commentRemoveUpvoteLabel => 'Quitar el voto a favor';

  @override
  String get commentDownvoteLabel => 'Votar en contra del comentario';

  @override
  String get commentRemoveDownvoteLabel => 'Quitar el voto en contra';

  @override
  String get commentsInputHint => 'Añadir comentario...';

  @override
  String get commentsInputHintEdit => 'Editar comentario...';

  @override
  String get commentsEmptyTitle => 'Todavía no hay comentarios';

  @override
  String get commentsEmptySubtitle => '¡Arranca tú la fiesta!';

  @override
  String get draftUntitled => 'Sin título';

  @override
  String get contentWarningNone => 'Ninguna';

  @override
  String get textBackgroundNone => 'Ninguno';

  @override
  String get textBackgroundSolid => 'Sólido';

  @override
  String get textBackgroundHighlight => 'Resaltado';

  @override
  String get textBackgroundTransparent => 'Transparente';

  @override
  String get textAlignLeft => 'Izquierda';

  @override
  String get textAlignRight => 'Derecha';

  @override
  String get textAlignCenter => 'Centro';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'La cámara todavía no es compatible en la web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'La captura y grabación con cámara todavía no están disponibles en la versión web.';

  @override
  String get cameraPermissionBackToFeed => 'Volver al feed';

  @override
  String get cameraCouldNotStart => 'No se pudo iniciar la cámara';

  @override
  String get cameraUnsupportedPlatform =>
      'La cámara todavía no está disponible en esta plataforma.\nIgual podés explorar y ver videos.';

  @override
  String get cameraPermissionErrorTitle => 'Error de permisos';

  @override
  String get cameraPermissionErrorDescription =>
      'Algo salió mal al verificar los permisos.';

  @override
  String get cameraPermissionRetry => 'Reintentar';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Permitir acceso a cámara y micrófono';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Esto te permite capturar y editar videos aquí mismo en la app, nada más.';

  @override
  String get cameraPermissionGoToSettings => 'Ir a ajustes';

  @override
  String get videoRecorderWhySixSecondsTitle => '¿Por qué seis segundos?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Los clips cortos dejan espacio para la espontaneidad. El formato de 6 segundos te ayuda a capturar momentos auténticos tal como ocurren.';

  @override
  String get videoRecorderWhySixSecondsButton => '¡Entendido!';

  @override
  String get videoRecorderUploadTitle => '¿Por qué no hay subida?';

  @override
  String get videoRecorderUploadBody =>
      'Lo que ves en Divine está hecho por humanos: en bruto y capturado en el momento. A diferencia de las plataformas que permiten subidas muy producidas o generadas por IA, priorizamos la autenticidad de la experiencia directa de cámara.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Al mantener la creación dentro de la app, podemos garantizar mejor que el contenido es real y sin editar. No estamos abriendo subidas desde la galería externa por ahora para proteger esa autenticidad y mantener nuestra comunidad libre de contenido sintético en la medida de lo posible.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Cambia a Capture o Classic para grabar algo real.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Aprende cómo funciona la verificación';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Encontramos trabajo en progreso';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      '¿Quieres continuar donde lo dejaste?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Sí, continuar';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'No, comenzar un video nuevo';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'No se pudo restaurar tu borrador';

  @override
  String get videoRecorderStopRecordingTooltip => 'Detener grabación';

  @override
  String get videoRecorderStartRecordingTooltip => 'Iniciar grabación';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Grabando. Toca en cualquier lugar para detener';

  @override
  String get videoRecorderTapToStartLabel =>
      'Toca en cualquier lugar para iniciar la grabación';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Eliminar último clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Cambiar cámara';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoom a $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Mostrar u ocultar cuadrícula';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Mostrar u ocultar fotograma fantasma';

  @override
  String get videoRecorderGhostFrameEnabled => 'Fotograma fantasma activado';

  @override
  String get videoRecorderGhostFrameDisabled =>
      'Fotograma fantasma desactivado';

  @override
  String get videoRecorderClipDeletedMessage => 'Clip movido a la papelera';

  @override
  String get videoRecorderClipUndoLabel => 'Deshacer';

  @override
  String get libraryTrashEmptyTitle => 'La papelera está vacía';

  @override
  String get libraryTrashEmptySubtitle =>
      'Los clips eliminados permanecen aquí durante 30 días antes de eliminarse de forma permanente.';

  @override
  String get libraryTrashRestoreLabel => 'Restaurar';

  @override
  String get libraryTrashDeleteNowLabel => 'Eliminar ahora';

  @override
  String get libraryTrashEmptyAllLabel => 'Vaciar papelera';

  @override
  String get libraryTrashDeleteConfirmTitle => '¿Eliminar clip ahora?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Esto elimina el clip de la papelera de inmediato.';

  @override
  String get libraryTrashEmptyConfirmTitle => '¿Vaciar papelera?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return 'Esto elimina permanentemente de la papelera $_temp0 ahora mismo.';
  }

  @override
  String get videoRecorderCloseLabel => 'Cerrar grabador de video';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Continuar al editor de video';

  @override
  String get videoRecorderCameraPreviewLabel => 'Vista previa de la cámara';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Enfocar la cámara';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Cambiar al modo $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Agrega audio antes de grabar';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'No se pudo crear el vídeo. Inténtalo de nuevo.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count tomas',
      one: 'Queda 1 toma',
      zero: 'No quedan tomas',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Activar o desactivar flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Cambiar temporizador';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Cambiar relación de aspecto';

  @override
  String get videoRecorderStabilizationLabel => 'Estabilización';

  @override
  String get videoRecorderStabilizationModeOff => 'Desactivada';

  @override
  String get videoRecorderStabilizationModeStandard => 'Estándar';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinematográfica';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematográfica ampliada';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Optimizada para vista previa';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Baja latencia';

  @override
  String get videoRecorderStabilizationModeAuto => 'Automática';

  @override
  String get videoRecorderFlashValueOff => 'Desactivado';

  @override
  String get videoRecorderFlashValueOn => 'Activado';

  @override
  String get videoRecorderFlashValueAuto => 'Automático';

  @override
  String get videoRecorderTimerValueOff => 'Desactivado';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 segundos';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 segundos';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Cuadrado';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Vertical';

  @override
  String get videoRecorderCameraValueFront => 'Cámara frontal';

  @override
  String get videoRecorderCameraValueBack => 'Cámara trasera';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Biblioteca de clips, sin clips';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Abrir biblioteca de clips, $clipCount clips',
      one: 'Abrir biblioteca de clips, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Abrir biblioteca de stop motion, $frameCount fotogramas',
      one: 'Abrir biblioteca de stop motion, 1 fotograma',
      zero: 'Abrir biblioteca de stop motion',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Cámara';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Abrir cámara';

  @override
  String get videoEditorLibraryLabel => 'Biblioteca';

  @override
  String get videoEditorTextLabel => 'Texto';

  @override
  String get videoEditorDrawLabel => 'Dibujar';

  @override
  String get videoEditorFilterLabel => 'Filtro';

  @override
  String get videoEditorTuneLabel => 'Ajustar';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Abrir editor de ajustes';

  @override
  String get videoEditorTuneBrightness => 'Brillo';

  @override
  String get videoEditorTuneContrast => 'Contraste';

  @override
  String get videoEditorTuneSaturation => 'Saturación';

  @override
  String get videoEditorTuneExposure => 'Exposición';

  @override
  String get videoEditorTuneHue => 'Tono';

  @override
  String get videoEditorTuneTemperature => 'Temperatura';

  @override
  String get videoEditorTuneTint => 'Matiz';

  @override
  String get videoEditorTuneFade => 'Desvanecer';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Agregar';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Abrir biblioteca';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Abrir editor de audio';

  @override
  String get videoEditorCaptionsLabel => 'Subtítulos';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Abrir el editor de subtítulos';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Grabar en el video';

  @override
  String get videoEditorCaptionsPresetCustom => 'Personal';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Estilo personalizado';

  @override
  String get videoEditorCaptionsCustomApply => 'Aplicar';

  @override
  String get videoEditorCaptionsCustomFont => 'Fuente';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Color de texto';

  @override
  String get videoEditorCaptionsCustomBackground => 'Fondo';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Color de fondo';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animación';

  @override
  String get videoEditorCaptionsAnimationNone => 'Ninguna';

  @override
  String get videoEditorCaptionsAnimationFade => 'Fundido';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Resorte';

  @override
  String get videoEditorCaptionsEditTitle => 'Subtítulos';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Escuchando…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Convertimos tu audio en sugerencias de subtítulos.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'No hemos oído ninguna voz. Aun así puedes escribir los subtítulos tú mismo.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'El reconocimiento de voz no está disponible en este dispositivo. Puedes escribir los subtítulos tú mismo.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'El reconocimiento de voz no está permitido. Actívalo en Ajustes o escribe los subtítulos tú mismo.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'La transcripción no ha funcionado esta vez. Puedes escribir los subtítulos tú mismo.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Escribir los subtítulos yo mismo';

  @override
  String get videoEditorCaptionsAddCue => 'Añadir subtítulo';

  @override
  String get videoEditorCaptionsCueTextHint => 'Texto del subtítulo';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Eliminar subtítulo';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Eliminar todos los subtítulos';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      '¿Eliminar los subtítulos?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Se perderán todo el texto y los tiempos.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Cerrar el editor de subtítulos';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Confirmar subtítulos';

  @override
  String get videoEditorCaptionsPresetTitle => 'Estilo de subtítulos';

  @override
  String get videoEditorCaptionsPresetClassic => 'Clásico';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Titular';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Máquina de escribir';

  @override
  String get videoEditorCaptionsPresetMarker => 'Rotulador';

  @override
  String get videoEditorCaptionsPresetScript => 'Caligrafía';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegante';

  @override
  String get videoEditorCaptionsPresetBubble => 'Burbuja';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neón';

  @override
  String get videoEditorCaptionsPresetBold => 'Negrita';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Soñador';

  @override
  String get videoEditorCaptionsPresetOcean => 'Océano';

  @override
  String get videoEditorCaptionsPresetSunny => 'Soleado';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Manuscrita';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Sello';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Abrir editor de texto';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Abrir editor de dibujo';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Abrir editor de filtros';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Abrir editor de stickers';

  @override
  String get videoEditorSaveDraftTitle => '¿Guardar tu borrador?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Guarda tus ediciones para más tarde o descártalas y sal del editor.';

  @override
  String get videoEditorSaveDraftButton => 'Guardar borrador';

  @override
  String get videoEditorDiscardChangesButton => 'Descartar cambios';

  @override
  String get videoEditorKeepEditingButton => 'Seguir editando';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Zona para soltar y eliminar capa';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Suelta para eliminar la capa';

  @override
  String get videoEditorDoneLabel => 'Listo';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Reproducir o pausar video';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Posición de división no válida. Ambos clips deben durar al menos $minDurationMs ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Guardar clip seleccionado';

  @override
  String get videoEditorSaveClip => 'Guardar clip';

  @override
  String get videoEditorClipSavedSuccess => 'Clip guardado en la biblioteca';

  @override
  String get videoEditorClipSaveFailed => 'No se pudo guardar el clip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Selector de color';

  @override
  String get videoEditorUndoSemanticLabel => 'Deshacer';

  @override
  String get videoEditorRedoSemanticLabel => 'Rehacer';

  @override
  String get videoEditorTextColorSemanticLabel => 'Color de texto';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Alineación de texto';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Fondo de texto';

  @override
  String get videoEditorFontSemanticLabel => 'Fuente';

  @override
  String get videoEditorNoStickersFound => 'No se encontraron stickers';

  @override
  String get videoEditorNoStickersAvailable => 'No hay stickers disponibles';

  @override
  String get videoEditorFailedLoadStickers =>
      'No se pudieron cargar los stickers';

  @override
  String get videoEditorVoiceOverLabel => 'Voz en off';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Grabación $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Grabar una voz en off';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Iniciar grabación';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Detener grabación';

  @override
  String get videoEditorVoiceOverHint =>
      'Toca para grabar. Añade todas las tomas que quieras.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grabaciones',
      one: '1 grabación',
      zero: 'Aún no hay grabaciones',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Eliminar última grabación';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Se necesita acceso al micrófono';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Permite el acceso al micrófono para grabar una voz en off.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Abrir ajustes';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Grabación iniciada';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Grabación guardada';

  @override
  String get videoEditorVoiceOverTooLong =>
      'La grabación es más larga que tu video';

  @override
  String get videoEditorPlaySemanticLabel => 'Reproducir';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausar';

  @override
  String get videoEditorVolumeSemanticLabel => 'Ajustar volumen';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volumen $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Desliza para ajustar';

  @override
  String get videoEditorChromaKeyLabel => 'Croma';

  @override
  String get videoEditorChromaKeyTitle => 'Croma';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Configura el croma de este clip';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Descartar los cambios del croma';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Aplicar el croma';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Detectar automáticamente';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Verde';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Azul';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Color del fondo';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Cantidad';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Cuánto color de fondo desaparece';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Borde';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Suaviza el recorte para que el pelo no quede dentado';

  @override
  String get videoEditorChromaKeySpillLabel => 'Derrame';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Quita el tono del fondo de tu sujeto';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Sustituir por';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Nada';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Color';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Imagen';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'El vídeo no admite transparencia, así que esto se exporta en negro.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'No se encontró ningún fondo. Tiene que llegar a los bordes del cuadro; si no, elige el color a mano.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Elegir un clip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Tu biblioteca está vacía. Guarda un clip primero y luego úsalo de fondo.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'No se pudo cargar esa imagen.';

  @override
  String get videoEditorChromaKeyRemove => 'Quitar el croma';

  @override
  String get videoEditorChromaKeyFailed =>
      'No se pudo aplicar el croma. Tu clip queda igual.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'No se pudo quitar el croma. Tu clip queda igual.';

  @override
  String get videoEditorChromaKeyApplying => 'Aplicando el croma…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Este dispositivo no puede mostrar la vista previa en vivo. Tus ajustes se aplican igualmente al exportar.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Eliminar';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Eliminar elemento seleccionado';

  @override
  String get videoEditorStopMotionFramesPerImageLabel =>
      'Fotogramas por imagen';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotogramas',
      one: '1 fotograma',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Fotogramas';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count fotogramas por imagen';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Fotograma de stop motion $position de $total';
  }

  @override
  String get videoEditorEditLabel => 'Editar';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Editar elemento seleccionado';

  @override
  String get videoEditorDuplicateLabel => 'Duplicar';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplicar elemento seleccionado';

  @override
  String get videoEditorCombineLabel => 'Combinar';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Combina los dibujos seleccionados en una capa';

  @override
  String get videoEditorSplitLabel => 'Dividir';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Dividir clip seleccionado';

  @override
  String get videoEditorExtractAudioLabel => 'Extraer audio';

  @override
  String get videoEditorClipAudioTitle => 'Audio del clip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Extraer audio del clip y silenciar el original';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'No se puede extraer el audio: el clip no está disponible localmente.';

  @override
  String get videoEditorExtractAudioFailed =>
      'No se pudo extraer el audio. Por favor, inténtalo de nuevo.';

  @override
  String get videoEditorSpeedLabel => 'Velocidad';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Establecer la velocidad de reproducción del clip seleccionado';

  @override
  String get videoEditorReverseLabel => 'Invertir';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Activar o desactivar la reproducción inversa del clip seleccionado';

  @override
  String get videoEditorReverseProgressLabel =>
      'Un momento, estamos invirtiendo tu clip';

  @override
  String get videoEditorTransformLabel => 'Transformar';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Recortar, girar o voltear el clip seleccionado';

  @override
  String get videoEditorTransformProgressLabel =>
      'Un momento, estamos transformando tu clip';

  @override
  String get videoEditorTransformFailed =>
      'No se pudo transformar el clip. Inténtalo de nuevo.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'No se puede transformar: el clip no está disponible localmente.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Recortar, girar o voltear el fotograma seleccionado';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Un momento, estamos transformando tu fotograma';

  @override
  String get videoEditorTransformFrameFailed =>
      'No se pudo transformar el fotograma. Inténtalo de nuevo.';

  @override
  String get videoEditorTransformRotateLabel => 'Girar';

  @override
  String get videoEditorTransformFlipLabel => 'Voltear';

  @override
  String get videoEditorTransformResetLabel => 'Restablecer';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Aplicar transformación';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Cancelar transformación';

  @override
  String get videoEditorTransformPlayLabel => 'Reproducir';

  @override
  String get videoEditorTransformPauseLabel => 'Pausar';

  @override
  String get videoEditorReverseNoLocalFile =>
      'No se puede invertir: el clip no está disponible localmente.';

  @override
  String get videoEditorReverseFailed =>
      'No se pudo invertir el clip. Por favor, inténtalo de nuevo.';

  @override
  String get videoEditorSpeedSheetTitle => 'Velocidad del clip';

  @override
  String get videoEditorTransitionSheetTitle => 'Transición';

  @override
  String get videoEditorTransitionNone => 'Ninguna';

  @override
  String get videoEditorTransitionDissolve => 'Disolvencia';

  @override
  String get videoEditorTransitionFadeToBlack => 'Fundido a negro';

  @override
  String get videoEditorTransitionFadeToWhite => 'Fundido a blanco';

  @override
  String get videoEditorTransitionSlide => 'Deslizar';

  @override
  String get videoEditorTransitionPush => 'Empujar';

  @override
  String get videoEditorTransitionWipe => 'Barrido';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Editar transición';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Transición de bucle';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Editar transición de bucle';

  @override
  String get videoEditorTransitionDuration => 'Duración';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Acortada para no superponerse con la transición adyacente.';

  @override
  String get videoEditorTransitionCurve => 'Curva';

  @override
  String get videoEditorTransitionDirection => 'Dirección';

  @override
  String get videoEditorTransitionDirectionLeft => 'Izquierda';

  @override
  String get videoEditorTransitionDirectionRight => 'Derecha';

  @override
  String get videoEditorTransitionDirectionUp => 'Arriba';

  @override
  String get videoEditorTransitionDirectionDown => 'Abajo';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Curva de animación $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animación';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Editar animación de capa';

  @override
  String get videoEditorLayerAnimationEnter => 'Entrada';

  @override
  String get videoEditorLayerAnimationLeave => 'Salida';

  @override
  String get videoEditorLayerAnimationFade => 'Fundido';

  @override
  String get videoEditorLayerAnimationScale => 'Escala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Escalar desde';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Terminar edición de la línea de tiempo';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel =>
      'Reproducir vista previa';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Pausar vista previa';

  @override
  String get videoEditorAudioUntitledSound => 'Sonido sin título';

  @override
  String get videoEditorAudioUntitled => 'Sin título';

  @override
  String get videoEditorAudioAddAudio => 'Agregar audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'No hay sonidos disponibles';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Los sonidos aparecerán aquí cuando los creadores compartan audio';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'No se pudieron cargar los sonidos';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Selecciona el segmento de audio para tu video';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Comunidad';

  @override
  String get videoEditorAudioCategoryFeatured => 'Destacados';

  @override
  String get videoEditorAudioCategoryMySounds => 'Mis sonidos';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Herramienta flecha';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Herramienta borrador';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Herramienta marcador';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Herramienta lápiz';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Mostrar línea de tiempo';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ocultar línea de tiempo';

  @override
  String get videoEditorFeedPreviewContent =>
      'Evita colocar contenido detrás de estas áreas.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originales';

  @override
  String get videoEditorStickerSearchHint => 'Buscar stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Seleccionar fuente';

  @override
  String get videoEditorFontUnknown => 'Desconocida';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'El cabezal de reproducción debe estar dentro del clip seleccionado para dividir.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Recortar inicio';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Recortar fin';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Recortar clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Arrastra los controles para ajustar la duración del clip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Arrastrando clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index de $total, $duration segundos';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Mantén presionado para reordenar';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Mover a la izquierda';

  @override
  String get videoEditorTimelineClipMoveRight => 'Mover a la derecha';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index de $total, seleccionado';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index de $total, no seleccionado';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Seleccionar';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Seleccionar varios clips';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Finalizar selección';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips seleccionados',
      one: '1 clip seleccionado',
      zero: 'Ningún clip seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Seleccionar varios dibujos';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Terminar de seleccionar dibujos';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Eliminar los dibujos seleccionados';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dibujos seleccionados',
      one: '1 dibujo seleccionado',
      zero: 'No hay dibujos seleccionados',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Combinar';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Combinar clips seleccionados';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Eliminar clips seleccionados';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Eliminar fotogramas seleccionados';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Invertir fotogramas seleccionados';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplicar fotogramas seleccionados';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Tu video necesita al menos ${seconds}s: captura algunos fotogramas más.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Un momento, estamos combinando tus clips';

  @override
  String get videoEditorMergeFailed =>
      'No se pudieron combinar los clips. Inténtalo de nuevo.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Mantén presionado para arrastrar';

  @override
  String get videoEditorVideoTimelineSemanticLabel =>
      'Línea de tiempo de video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes m $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, seleccionado';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Cerrar selector de color';

  @override
  String get videoEditorPickColorTitle => 'Elegir color';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirmar color';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturación y brillo';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturación $saturation %, brillo $brightness %';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Tono';

  @override
  String get videoEditorAddElementSemanticLabel => 'Agregar elemento';

  @override
  String get videoEditorDoneSemanticLabel => 'Listo';

  @override
  String get videoEditorLevelSemanticLabel => 'Nivel';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Cerrar detalles de la publicación';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Cerrar diálogo de ayuda';

  @override
  String get videoMetadataGotItButton => '¡Entendido!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Se alcanzó el límite de 64 KB. Elimina parte del contenido para continuar.';

  @override
  String get videoMetadataExpirationLabel => 'Expiración';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Seleccionar tiempo de expiración';

  @override
  String get videoMetadataTitleLabel => 'Título';

  @override
  String get videoMetadataDescriptionLabel => 'Descripción';

  @override
  String get videoMetadataTagsLabel => 'Etiquetas';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Eliminar etiqueta $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Advertencia de contenido';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Seleccionar advertencias de contenido';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Selecciona todo lo que aplique a tu contenido';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Permite que otros guarden y reutilicen el audio de este video.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Tu video ya está publicado, pero el sonido no. Edita el video para compartirlo.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Colaboradores';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Agregar colaborador';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Seguidores mutuos';

  @override
  String get videoMetadataInspiredByLabel => 'Inspirado en';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Establecer inspirado en';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'No se puede hacer referencia a este creador.';

  @override
  String get videoMetadataPostDetailsTitle => 'Detalles de la publicación';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Guardado en la biblioteca';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'No se pudo guardar';

  @override
  String get videoMetadataGoToLibraryButton => 'Ir a la biblioteca';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Botón guardar para más tarde';

  @override
  String get videoMetadataSavingVideoHint => 'Guardando video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Guardar video en borradores y $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Guardar video en borradores. Aún no hay video procesado, así que no se añade copia a $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Guardar para más tarde';

  @override
  String get videoMetadataPostSemanticLabel => 'Botón publicar';

  @override
  String get videoMetadataPublishVideoHint => 'Publicar video en el feed';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Compartir también en mi feed';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Desactivado mantiene este video solo en el hilo de comentarios.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Completa el formulario para habilitar';

  @override
  String get videoMetadataPostButton => 'Publicar';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Abrir pantalla de vista previa de la publicación';

  @override
  String get videoMetadataShareTitle => 'Compartir';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Detalles del video';

  @override
  String get videoMetadataClassicDoneButton => 'Listo';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Reproducir vista previa';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Pausar vista previa';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Cerrar vista previa de video';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Eliminar';

  @override
  String get fullscreenFeedRemovedMessage => 'Video eliminado';

  @override
  String get fullscreenFeedEmptyMessage =>
      'Aquí ya no queda nada que reproducir';

  @override
  String get settingsBadgesTitle => 'Insignias';

  @override
  String get settingsBadgesSubtitle =>
      'Aceptá premios y revisá el estado de las insignias que emitiste.';

  @override
  String get badgesTitle => 'Insignias';

  @override
  String get badgesLoadError => 'No se pudieron cargar las insignias';

  @override
  String get badgesUpdateError => 'No se pudo actualizar la insignia';

  @override
  String get badgesAwardedEmptyTitle => 'Todavía no hay insignias otorgadas';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Cuando alguien te otorgue una insignia de Nostr, va a aparecer acá.';

  @override
  String get badgesStatusAccepted => 'Aceptada';

  @override
  String get badgesStatusNotAccepted => 'Sin aceptar';

  @override
  String get badgesActionRemove => 'Quitar';

  @override
  String get badgesActionAccept => 'Aceptar';

  @override
  String get badgesActionReject => 'Rechazar';

  @override
  String get badgesIssuedEmptyTitle => 'Todavía no emitiste ninguna insignia';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Las insignias que emitas van a mostrar el estado de aceptación acá.';

  @override
  String get badgesIssuedNoRecipients =>
      'No se encontraron destinatarios para este premio.';

  @override
  String get badgesRecipientAcceptedStatus => 'Aceptada por el destinatario';

  @override
  String get badgesRecipientWaitingStatus => 'Esperando al destinatario';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ocultas ($count)',
      one: 'Oculta (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Restaurar';

  @override
  String get badgesHiddenSnackbar => 'Insignia oculta';

  @override
  String get badgesHiddenSnackbarUndo => 'Deshacer';

  @override
  String get badgesTabAwarded => 'Recibidas';

  @override
  String get badgesTabCreated => 'Creadas';

  @override
  String get badgesTabIssued => 'Entregadas';

  @override
  String get badgesCreateAction => 'Nueva insignia';

  @override
  String get badgesCreatedEmptyTitle => 'Todavía no creaste ninguna';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Creá una y dásela a alguien que se la ganó.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entregada a $count personas',
      one: 'Entregada a 1 persona',
      zero: 'Sin entregar todavía',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Nueva insignia';

  @override
  String get badgeEditorEditTitle => 'Editar insignia';

  @override
  String get badgeEditorNameLabel => 'Nombre';

  @override
  String get badgeEditorNameHint => 'Roba escenas';

  @override
  String get badgeEditorIdentifierLabel => 'Identificador';

  @override
  String get badgeEditorIdentifierHelp =>
      'Es parte de la dirección de la insignia, así que queda fijo una vez creada.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Ya tenés una insignia con este identificador. Editá esa: publicar acá la reemplazaría.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Cada insignia necesita un identificador: escribí uno si el nombre no lo completó.';

  @override
  String get badgeEditorDescriptionLabel => 'Descripción';

  @override
  String get badgeEditorDescriptionHint =>
      'Para quien se roba el scroll con un solo loop.';

  @override
  String get badgeEditorArtworkLabel => 'Arte';

  @override
  String get badgeEditorArtworkAdd => 'Agregar arte';

  @override
  String get badgeEditorArtworkReplace => 'Reemplazar';

  @override
  String get badgeEditorArtworkError => 'No se pudo subir esa imagen';

  @override
  String get badgeEditorArtworkRequired => 'Toda insignia necesita un arte.';

  @override
  String get badgeEditorArtworkRemove => 'Quitar el arte';

  @override
  String get badgeEditorArtworkSheetTitle => 'Arte de la insignia';

  @override
  String get badgeDetailDeleteAction => 'Borrar insignia';

  @override
  String get badgeDetailDeleteTitle => '¿Borrar esta insignia?';

  @override
  String get badgeDetailDeleteBody =>
      'Esto les pide a los relés que saquen la insignia y todas las entregas que hiciste. Los relés pueden negarse, y quien la fijó la mantiene en su perfil hasta que la saque.';

  @override
  String get badgeDetailDeleteConfirm => 'Borrar';

  @override
  String get badgeEditorSaveAction => 'Publicar insignia';

  @override
  String get badgeEditorSaveError => 'No se pudo publicar la insignia';

  @override
  String get badgeEditorLoadError => 'No se pudo cargar esta insignia';

  @override
  String get badgeDetailTitle => 'Insignia';

  @override
  String get badgeDetailMadeBy => 'Creada por';

  @override
  String get badgeDetailRecipientsTitle => 'Entregada a';

  @override
  String get badgeDetailNoRecipients => 'Todavía no la tiene nadie.';

  @override
  String get badgeDetailAwardAction => 'Entregar esta insignia';

  @override
  String get badgeDetailEditAction => 'Editar insignia';

  @override
  String get badgeDetailShareAction => 'Compartir';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Mirá esta insignia en Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Quitar la insignia';

  @override
  String get badgeDetailRevokeTitle => '¿Quitarle esta insignia?';

  @override
  String get badgeDetailRevokeBody =>
      'Esto les pide a los relés que saquen la entrega que le hiciste a esta persona. Los relés pueden negarse, y si ya fijó la insignia, la mantiene en su perfil hasta que la saque. En cualquier caso, no se le avisa.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Esto les pide a los relés que saquen la entrega que te hiciste a vos mismo, y quita la insignia de tu perfil. Si los relés se niegan a borrarla, no cambia nada.';

  @override
  String get badgeDetailRevokeConfirm => 'Quitar';

  @override
  String get badgeDetailRevokeSuccess => 'Insignia retirada';

  @override
  String get badgeDetailBlockClaimantsAction =>
      'Bloquear a quienes llevan la insignia';

  @override
  String get badgeDetailBlockClaimantsTitle =>
      'Bloquear a quienes llevan la insignia';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'No pudimos cargar a quienes llevan esta insignia';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Ahora mismo nadie lleva esta insignia';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'No encontramos a nadie a quien bloquear ahora mismo.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Bloquear $count cuentas?',
      one: '¿Bloquear 1 cuenta?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Esto bloquea las $count cuentas que llevan esta insignia ahora mismo. Sus publicaciones no van a aparecer en tus feeds y no les vamos a avisar.',
      one:
          'Esto bloquea la cuenta que lleva esta insignia ahora mismo. Sus publicaciones no van a aparecer en tus feeds y no le vamos a avisar.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bloquear $count cuentas',
      one: 'Bloquear 1 cuenta',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'Cuentas con la insignia bloqueadas';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'No pudimos bloquear a quienes llevan la insignia';

  @override
  String get badgeDetailLoadError => 'No se pudo cargar esta insignia';

  @override
  String get badgeDetailMissing =>
      'No encontramos esta insignia en ningún relé.';

  @override
  String get badgeDetailActionError => 'Eso no salió';

  @override
  String get badgeAwardTitle => 'Entregar insignia';

  @override
  String get badgeAwardPickAction => 'Elegir personas';

  @override
  String get badgeAwardManualLabel => 'O pegá claves';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Elegí al menos a una persona.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entregar a $count personas',
      one: 'Entregar a 1 persona',
      zero: 'Entregar insignia',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Entregada por';

  @override
  String get profileBadgeRecipients => 'Destinatarios';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count más';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Insignia $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Insignia';

  @override
  String get profileBadgeFooterBody =>
      'Las insignias son pequeños premios que cualquiera puede crear en Nostr. Regalale una a un amigo, a un creador o a alguien que te alegró el día.';

  @override
  String get profileBadgeFooterLink => 'Crea tu propia insignia';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Guía para familias';

  @override
  String get minorAccountReviewWelcomeTitle =>
      '¿Todavía no tienes 16? No pasa nada.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Que hayas entrado en esta página en lugar de elegir sin más la respuesta que te dejaba pasar dice mucho. Demuestra honestidad, carácter y una preocupación real por la gente que te rodea.\n\nLas reglas para menores de 16 años varían según dónde vivas. En Divine queremos que las familias lo hablen juntas y decidan cómo es un uso sano de las redes sociales.';

  @override
  String get minorAccountReviewModerationTitle => 'Nos falta un paso más';

  @override
  String get minorAccountReviewModerationBody =>
      'Nos pidieron mirar esta cuenta con más detalle porque podría ser de alguien menor de 16 años. Este proceso mantiene privados los siguientes pasos y te señala el camino adecuado para tu edad.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Las reglas no son iguales en todas partes';

  @override
  String get minorAccountReviewRulesBody =>
      'Cada país y región trata de forma distinta el uso de redes sociales por parte de adolescentes. Por eso pedimos a las familias que vayan despacio, comprueben los datos y elijan juntas el siguiente paso.';

  @override
  String get minorAccountReviewApproachTitle => 'Cómo lo ve Divine';

  @override
  String get minorAccountReviewApproachBody =>
      'Creemos que los hábitos digitales sanos vienen de parar, reflexionar y llevar la atención hacia cosas mejores, no de espiar a los hijos ni de convertir a los padres en vigilantes. La investigación también lo respalda.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Más para familias';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Lee la política de Divine para menores';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'Elige el camino que encaja';

  @override
  String get minorAccountReviewUnder13Cta => 'Menores de 13';

  @override
  String get minorAccountReviewTeenCta => 'De 13 a 15 años';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Visita la guía de Divine para familias: consejos prácticos, herramientas de conversación y recursos para que los adolescentes usen las redes con más seguridad.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Ver guías y consejos para familias';

  @override
  String get minorAccountReviewFooter =>
      'Si tienes 16 años o más y llegaste aquí por error, escribe al soporte de Divine para que lo revise una persona de verdad.';

  @override
  String get minorAccountReviewTitle => 'Revisión de la cuenta';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Comprobando el estado de la cuenta...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Espera mientras confirmamos el estado actual de la revisión de esta cuenta.';

  @override
  String get minorAccountReviewDefaultTitle => 'Hace falta revisar la cuenta';

  @override
  String get minorAccountReviewDefaultBody =>
      'Tenemos que revisar esta cuenta antes de que pueda usar Divine con normalidad.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'ID del caso: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'ID del caso';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'Qué está limitado ahora mismo';

  @override
  String get minorAccountReviewRestrictionPosting => 'Publicar está en pausa';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Comentarios, me gusta, reposts y seguimientos están en pausa';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Empezar o responder mensajes normales está en pausa';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'El soporte y tu mensaje de moderación siguen disponibles';

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
      'Abrir el centro de soporte';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Abrir el mensaje de moderación';

  @override
  String get minorAccountReviewOpenReviewPage => 'Abrir la página de revisión';

  @override
  String get minorAccountReviewCheckAgain => 'Comprobar otra vez';

  @override
  String get minorAccountReviewLogOut => 'Cerrar sesión';

  @override
  String get minorAccountReviewNextStepTitle => 'Siguiente paso';

  @override
  String get minorAccountReviewNextStepBody =>
      'Abre el centro de soporte o tu mensaje de moderación si necesitas ayuda con esta revisión.';

  @override
  String get minorAccountReviewInProgressTitle => 'Revisión en curso';

  @override
  String get minorAccountReviewInProgressBody =>
      'Por ahora tenemos lo que necesitamos. Nuestro equipo está revisando este caso antes de devolver el acceso normal a la cuenta.';

  @override
  String get minorAccountReviewUnder13Title => 'Cuentas de menores de 13';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Si esta cuenta es de alguien menor de 13 años, un padre, madre o tutor tiene que escribir a $supportEmail e incluir el ID del caso.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Todavía no podemos darte una cuenta';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine no está hecho para menores de 13 años, y las reglas de redes sociales de todo el mundo nos atan las manos.\n\nEn internet muchas cosas te empujan a mentir para conseguir lo que quieres, y eso lo detestamos. Es la lección equivocada para la vida, y aquí no te la vamos a enseñar.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Lo que puede hacer tu familia en su lugar';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Un padre, madre o tutor puede llevar la cuenta y publicar, y tú puedes salir en los videos con ellos sin problema. Queremos que las familias disfruten Divine de la forma que les funcione.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Cuando cumplas 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Según las reglas de donde vives, quizá puedas volver y pedir tu propia cuenta. En ese caso, si tienes entre 13 y 15 años, necesitarás el permiso de un padre, madre o tutor.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Por qué no te vamos a decir que simplemente vuelvas atrás';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Gran parte de internet está armada para premiar a la gente por decir lo que sea que les permita pasar la barrera. No nos parece bien. Sí, podrías volver atrás y decir que tenés más edad de la que tenés, pero eso no sería honesto, y no te vamos a enseñar a mentir para conseguir lo que querés.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Estamos tratando de ayudar a los jóvenes a usar Divine de maneras que sean saludables y positivas para ellos y para quienes los rodean. También tenemos que cumplir leyes que son distintas en cada lugar. Así que, si sos menor de 13, la respuesta es que hoy no podés tener tu propia cuenta.';

  @override
  String get minorAccountReviewTeenBody =>
      'Si esta cuenta es de alguien de 13 a 15 años, usa el mensaje de moderación o la vía de soporte para seguir las instrucciones del consentimiento parental.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Si la cuenta va a ser de alguien de 13 a 15 años';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Un padre, madre o tutor debe escribir al soporte de Divine con un video privado corto. Nuestro equipo lo revisará y ayudará con los siguientes pasos.\n\nSi no es posible contactar a un padre, madre o tutor, o si hacerlo pondría a alguien en riesgo, escribe al soporte de Divine y cuéntanos.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Es una pausa mientras el equipo de soporte de Divine revisa el video. Si lo aprueban, te guiarán para configurar la cuenta nueva.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Por qué pedimos que un padre, madre o tutor participe';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine tiene que cumplir leyes relacionadas con la edad en todo el mundo. También sabemos que la mayoría de las barreras técnicas de edad son imperfectas. En lugar de pretender que las reglas no existen o que está bueno mentir sobre tu edad, queremos que los adolescentes y las familias tomen decisiones reflexivas sobre la mejor manera de usar Divine. Por eso, para los jóvenes de 13 a 15 años, pedimos que los padres formen parte del proceso de creación de la cuenta.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'También tenemos que cumplir la ley, y esas reglas son distintas según dónde viva cada persona. Así que, en lugar de pretender que las reglas no existen, pedimos que un padre, madre o tutor forme parte del proceso.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Qué debe mostrar el video';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Al adolescente en el video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'A un padre, madre o tutor hablando a cámara';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Una declaración clara de que el adolescente tiene entre 13 y 15 años y tiene permiso para usar Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Una declaración clara de que el padre, madre o tutor conoce la cuenta y supervisará su uso';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Cómo enviarlo';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Adjunta el video cuando escribas al soporte de Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Mantén el video privado y no lo publiques en la app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Nuestro equipo lo revisará y responderá con los siguientes pasos';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Escribir al soporte de Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Ayuda con la revisión de Divine Greenlight (13-15 años)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hola, soporte de Divine:\n\nescribo sobre Divine Greenlight para un adolescente de 13 a 15 años.\n\nAdjunto un video breve y privado que muestra:\n- al adolescente\n- a un padre, madre o tutor hablando a cámara\n- que el adolescente tiene permiso para usar Divine\n- que el padre, madre o tutor conoce la cuenta y supervisará su uso\n\nPaís o países de residencia:\n\nContexto útil:\n\nGracias.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Instrucciones de soporte para familias';

  @override
  String get minorAccountReviewContinue => 'Continuar';

  @override
  String get minorAccountReviewErrorTitle =>
      'No pudimos cargar el estado de revisión de tu cuenta.';

  @override
  String get minorAccountReviewErrorBody => 'Inténtalo de nuevo en un momento.';

  @override
  String get minorAccountReviewTryAgain => 'Inténtalo de nuevo';

  @override
  String get minorAccountReviewParentContactTitle => 'Contacto del tutor';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Añade el correo de un padre, madre o tutor';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Usaremos esta dirección para la revisión del consentimiento parental en el caso $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Correo del padre, madre o tutor';

  @override
  String get minorAccountReviewSubmitting => 'Enviando...';

  @override
  String get minorAccountReviewSubmitEmail => 'Enviar el correo';

  @override
  String get minorAccountReviewBackToReview =>
      'Volver a la revisión de la cuenta';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Correo enviado';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Enviamos $email a revisión. Escribiremos a esa dirección para confirmarlo. En cuanto responda tu padre, madre o tutor, tu caso avanzará. Usa Comprobar otra vez en la pantalla de revisión de la cuenta para ver novedades.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Recibimos el contacto del padre, madre o tutor de esta cuenta. Nuestro equipo lo revisará antes de devolver el acceso.';

  @override
  String get minorAccountReviewMissingCase =>
      'No encontramos un caso de revisión activo para esta cuenta.';

  @override
  String get minorAccountReviewParentContactError =>
      'No se pudo enviar el correo del tutor. Inténtalo de nuevo.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Soporte para familias';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Un padre, madre o tutor tiene que contactar con Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Para las cuentas que probablemente sean de menores de 13 años, el siguiente paso es que un padre, madre o tutor escriba un correo.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Correo de soporte';

  @override
  String get minorAccountReviewCopySupportEmail =>
      'Copiar el correo de soporte';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'Correo de soporte copiado';

  @override
  String get minorAccountReviewCopyCaseId => 'Copiar el ID del caso';

  @override
  String get minorAccountReviewCaseIdCopied => 'ID del caso copiado';

  @override
  String get minorAccountReviewUnavailable => 'No disponible';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Pide al padre, madre o tutor que incluya el ID del caso y explique que contacta con Divine por esta revisión de cuenta.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Revisión de cuenta de menor de 13 para el caso $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Hola, soporte de Divine:\n\nsoy el padre, madre o tutor de un menor de 13 años y escribo por el caso de revisión de cuenta $caseId.\n\nGracias.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulación de revisión de cuenta de menor';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Estado actual';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Restringida ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Activa';

  @override
  String get devOptionsMinorReviewStateLoading => 'Cargando...';

  @override
  String get devOptionsMinorReviewStateError => 'Error al cargar el estado';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Borrar la anulación de la simulación';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Volver a usar el backend o el estado activo por defecto';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Simular caso de revisión 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Cuenta restringida con vía de contacto del tutor';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simular caso de soporte de menor de 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Cuenta restringida con instrucciones solo por correo del tutor';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simulación de revisión de cuenta de menor borrada';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Caso simulado de soporte de menor de 13 activado';

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
      'Simulación de menor protegido';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Estado actual';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Menor protegido (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'No protegido';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Cargando…';

  @override
  String get devOptionsProtectedMinorStateError => 'Error al leer el estado';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Sin anulación (estado real de la cuenta)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Anulación: protegido forzado';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Anulación: no protegido forzado';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simular menor protegido (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Fuerza el estado de menor protegido para probar las protecciones #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simular persona adulta';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Fuerza no protegido (un no explícito, distinto de no tener anulación)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Borrar la anulación';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Volver al estado real de la cuenta que da Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Estado de menor protegido forzado';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Estado de menor protegido desactivado';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Anulación de menor protegido borrada';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Invitaciones de registro';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Estado actual';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Valor del servidor: cargando';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Valor del servidor: activado';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Valor del servidor: desactivado';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Valor del servidor: desconocido';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Anulación: usar el valor del servidor';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Anulación: forzar activado';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Anulación: forzar desactivado';

  @override
  String get devOptionsInviteAvailabilityUseServer =>
      'Usar el valor del servidor';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Seguir el onboardingMode del servicio de invitaciones';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Forzar activado';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Mostrar en local los bloqueos y la gestión de invitaciones';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Forzar desactivado';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Ocultar en local la interfaz de invitaciones sin tocar el servidor';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Las invitaciones de registro ya siguen al servidor';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Invitaciones de registro forzadas como activadas';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Invitaciones de registro forzadas como desactivadas';

  @override
  String get commentsRecordVideoButtonLabel => 'Grabar comentario en video';

  @override
  String get commentsOpenVideoLabel => 'Abrir comentario en video';

  @override
  String get commentsMuteVideoReplyLabel => 'Silenciar respuesta en video';

  @override
  String get commentsUnmuteVideoReplyLabel =>
      'Activar sonido de la respuesta en video';

  @override
  String get commentsOpenReplyParentLabel =>
      'Abrir el video al que responde esto';

  @override
  String get commentsReplyParentSectionTitle => 'En respuesta a';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Responder a $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Responder al video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Cuenta $platform verificada: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Cuentas verificadas';

  @override
  String get profileEditGetVerifiedCta => 'Verifícate';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Conecta tus redes sociales para que sepan que eres tú.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Visitar el sitio web: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'No se pudo abrir el sitio web';

  @override
  String get videoMetadataEditCoverTitle => 'Editar portada';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Descartar cambios de portada';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Usar el fotograma seleccionado como portada del vídeo';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Desliza el video para seleccionar el fotograma de portada';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Buscar o añadir etiquetas';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Añade etiquetas para que otros descubran tu vídeo';

  @override
  String get videoMetadataTagsPickerNoResults => 'Sin etiquetas coincidentes';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Añadir «#$tag»';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => '¿Todavía no tenés 16? No hay problema. ';

  @override
  String get authUnder16ChoicesCta => 'Estas son tus opciones.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Por esto';

  @override
  String get generalSettingsHoldToRecord => 'Mantener para grabar';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'La grabación empieza al mantener pulsado y se detiene al soltar';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos publicados en tu perfil',
      one: 'Video publicado en tu perfil',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Enviar mensaje';

  @override
  String get emojiPickerSearchHint => 'Buscar';

  @override
  String get emojiCategoryRecent => 'Recientes';

  @override
  String get emojiCategorySmileys => 'Emoticonos y personas';

  @override
  String get emojiCategoryAnimals => 'Animales y naturaleza';

  @override
  String get emojiCategoryFood => 'Comida y bebida';

  @override
  String get emojiCategoryActivities => 'Actividades';

  @override
  String get emojiCategoryTravel => 'Viajes y lugares';

  @override
  String get emojiCategoryObjects => 'Objetos';

  @override
  String get emojiCategorySymbols => 'Símbolos';

  @override
  String get emojiCategoryFlags => 'Banderas';

  @override
  String get videoEditorMarkerLabel => 'Marcador';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Añadir marcador a la línea de tiempo';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Quitar marcador de la línea de tiempo';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Quitar marcador en la posición de reproducción';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => '¿Eliminar marcador?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Esto quita el marcador de la línea de tiempo. Tu edición permanece intacta.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Silenciar o activar todas las pistas';

  @override
  String get videoEditorSplitFailed =>
      'Error al dividir. Por favor, inténtalo de nuevo.';

  @override
  String get videoEditEditSubtitles => 'Editar subtítulos';

  @override
  String get subtitleEditorTitle => 'Editar subtítulos';

  @override
  String get subtitleEditorSave => 'Guardar';

  @override
  String get subtitleEditorProcessing =>
      'Los subtítulos todavía se están generando. Volvé en un momento.';

  @override
  String get subtitleEditorNoSpeech =>
      'No se detectó habla en este video, así que no hay nada para subtitular.';

  @override
  String get subtitleEditorWriteOwn => 'Escribilos vos';

  @override
  String get subtitleEditorAddCue => 'Agregar una línea';

  @override
  String get subtitleEditorRemoveCue => 'Quitar esta línea';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Ahora mismo el vídeo no se puede reproducir, pero aún puedes corregir los subtítulos.';

  @override
  String get subtitleEditorPlayPreview => 'Reproducir el vídeo';

  @override
  String get subtitleEditorPausePreview => 'Pausar el vídeo';

  @override
  String get subtitleEditorInvalidHint =>
      'Cada línea necesita texto y un fin posterior a su inicio.';

  @override
  String get subtitleEditorLoadError =>
      'No se pudieron cargar los subtítulos. Intentá de nuevo.';

  @override
  String get subtitleEditorSaveSuccess => 'Subtítulos actualizados';

  @override
  String get subtitleEditorSaveError =>
      'No se pudieron guardar los subtítulos. Intentá de nuevo.';

  @override
  String get subtitleEditorRetry => 'Reintentar';

  @override
  String get subtitleEditorCueHint => 'Texto del subtítulo';

  @override
  String get imageCropEditorRotateLabel => 'Girar';

  @override
  String get imageCropEditorFlipLabel => 'Voltear';

  @override
  String get imageCropEditorResetLabel => 'Restablecer';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Cancelar recorte';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Aplicar recorte';

  @override
  String get imageCropEditorProcessing => 'Aplicando recorte…';

  @override
  String get backgroundUploadNotificationTitle => 'Subiendo video';

  @override
  String get monetizationSettingsTitle => 'Apoyo a creadores';

  @override
  String get monetizationSettingsSubtitle =>
      'Añade enlaces de propina y suscripción';

  @override
  String get monetizationSettingsIntroTitle => 'Solo enlaces externos';

  @override
  String get monetizationSettingsIntroBody =>
      'Añade destinos que controles tú. Divine nunca gestiona el pago ni desbloquea contenido en la app con estos enlaces.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces activos en tu perfil',
      one: '1 enlace activo en tu perfil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Enviar una propina';

  @override
  String get monetizationSettingsSubscriptionSection => 'Suscribirse / apoyar';

  @override
  String get monetizationSettingsSave => 'Guardar los enlaces de apoyo';

  @override
  String get monetizationSettingsSaving => 'Guardando...';

  @override
  String get monetizationSettingsSaved => 'Enlaces de apoyo actualizados';

  @override
  String get monetizationSettingsSaveFailed =>
      'No se pudieron guardar los enlaces de apoyo. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'Añade un identificador o una URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Ese enlace no tiene buena pinta.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Usa un enlace de este servicio.';

  @override
  String get monetizationSettingsHintCashApp =>
      '\$cashtag o enlace de cash.app';

  @override
  String get monetizationSettingsHintPayPal =>
      'Identificador o enlace de PayPal.me';

  @override
  String get monetizationSettingsHintVenmo => 'Identificador o enlace de Venmo';

  @override
  String get monetizationSettingsHintPatreon =>
      'Identificador o enlace de Patreon';

  @override
  String get monetizationSettingsHintSubstack => 'Dominio o enlace de Substack';

  @override
  String get monetizationSettingsHintMedium =>
      'Identificador o enlace de Medium';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Identificador o enlace de Open Collective';

  @override
  String get profileSupportSheetTitle => 'Apoyar a este creador';

  @override
  String get profileSupportSheetBody =>
      'Estos enlaces se abren fuera de Divine. Nada de esto desbloquea contenido en la app.';

  @override
  String get profileSupportTipSection => 'Enviar una propina';

  @override
  String get profileSupportSubscriptionSection => 'Suscribirse / apoyar';

  @override
  String get profileSupportButtonLabel => 'Apoyar';

  @override
  String get monetizationTipsSettingsTitle => 'Propinas';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Añade enlaces opcionales de propina';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Solo propinas opcionales';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Las propinas son regalos opcionales entre personas. No desbloquean contenido, suscripciones, funciones, posición, visibilidad ni acceso en Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces de propina activos en tu perfil',
      one: '1 enlace de propina activo en tu perfil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Guardar los enlaces de propina';

  @override
  String get monetizationTipsSettingsSaved => 'Enlaces de propina actualizados';

  @override
  String get profileTipButtonLabel => 'Propina';

  @override
  String get profileTipSheetTitle => 'Dar propina a este creador';

  @override
  String get profileTipSheetBody =>
      'Los enlaces de propina se abren fuera de Divine. Son opcionales y no desbloquean contenido, suscripciones, funciones ni acceso en Divine.';

  @override
  String get settingsStorageTitle => 'Almacenamiento';

  @override
  String get settingsStorageCacheSectionTitle => 'Contenido en caché';

  @override
  String get settingsStorageCacheDescription =>
      'Videos del feed, miniaturas y renders temporales en caché. Borrarlos es seguro: se vuelven a descargar o regenerar cuando se necesitan.';

  @override
  String get settingsStorageMeasuring => 'Calculando…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size en uso';
  }

  @override
  String get settingsStorageClearButton => 'Borrar caché';

  @override
  String get settingsStorageClearConfirmTitle =>
      '¿Borrar el contenido en caché?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Esto libera $size. Tu biblioteca de clips no se ve afectada.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Borrar';

  @override
  String get settingsStorageCleared => 'Caché borrada';

  @override
  String get settingsStorageLibrarySectionTitle => 'Biblioteca de clips';

  @override
  String get settingsStorageLibraryDescription =>
      'Busca clips dañados cuyo archivo de video falta.';

  @override
  String get settingsStorageScanButton => 'Comprobar biblioteca';

  @override
  String get settingsStorageLibraryHealthy => 'No se encontraron clips dañados';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Clips dañados encontrados: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Eliminar clips dañados';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Clips dañados eliminados';

  @override
  String get settingsStorageError => 'Algo salió mal';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Caché máxima de videos';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count videos';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      '¿Eliminar clips dañados?';

  @override
  String get settingsStorageRepairSectionTitle => 'Reparar instalación';

  @override
  String get settingsStorageRepairDescription =>
      'Si la app se cierra o se comporta raro, restablecer sus datos locales suele arreglarlo. Tus clips y borradores se quedan.';

  @override
  String get settingsStorageRepairButton => 'Restablecer datos de la app';

  @override
  String get settingsStorageRepairConfirmTitle =>
      '¿Restablecer datos de la app?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Esto borra los datos del feed en caché y los archivos temporales. Tus clips, borradores, ajustes y sesión se quedan, pero tendrás que reiniciar la app después.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return 'Se borrarán $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Restablecer';

  @override
  String get settingsStorageRepairInProgress => 'Restableciendo…';

  @override
  String get settingsStorageRepairSuccess =>
      'Listo: reinicia la app para terminar.';

  @override
  String get settingsStorageRepairFailure =>
      'No se pudo restablecer todo. Inténtalo de nuevo tras reiniciar.';

  @override
  String get nostrSettingsSignatureVerification => 'Verificación de firma';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Elige cuándo Divine comprueba las firmas de eventos de los relays. Los ID de evento siempre se validan primero.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Todos los relays';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Lo más seguro. Verifica la firma de cada evento de relay.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Relays no confiables';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Omite las comprobaciones de relays que ya estén en tu conjunto configurado.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Relays que no son de Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Confía en los relays de Divine y verifica el resto.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle =>
      'Comparte tus videos en otras plataformas';

  @override
  String get crosspostingSignInRequired =>
      'Inicia sesión con Divine para gestionar el crossposting';

  @override
  String get crosspostingLoadFailed =>
      'No se pudieron cargar tus ajustes de crossposting';

  @override
  String get crosspostingNoPlatforms =>
      'Ahora mismo no hay plataformas de crossposting disponibles';

  @override
  String get crosspostingRetry => 'Reintentar';

  @override
  String get crosspostingNotConnected => 'Sin conexión';

  @override
  String get crosspostingConnected => 'Conectado';

  @override
  String get crosspostingNeedsReconnect => 'Necesita reconectarse';

  @override
  String get crosspostingConnect => 'Conectar';

  @override
  String get crosspostingReconnect => 'Reconectar';

  @override
  String get crosspostingDisconnect => 'Desconectar';

  @override
  String get crosspostingModeOff => 'Desactivado';

  @override
  String get crosspostingModeManual => 'Manual';

  @override
  String get crosspostingModeManualSubtitle => 'Eliges tú en cada video';

  @override
  String get crosspostingModeAutomatic => 'Automático';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Los videos futuros se publican solos — solo los que publiques después de activar esto';

  @override
  String get crosspostingNotConnectedError =>
      'Conecta esta plataforma primero para cambiar cómo publica.';

  @override
  String get crosspostingGenericError => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'La página de inicio de sesión nunca respondió. Si terminaste de conectar ahí, actualiza — puede que tu cuenta ya esté vinculada.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform conectado';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'No se pudo conectar $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'La conexión se canceló en $platform';
  }

  @override
  String get supporterTitle => 'Supporters de Divine';

  @override
  String get supporterTileSubtitle =>
      'Apoyá Divine con una suscripción mensual opcional.';

  @override
  String get supporterHeroTitle => 'Mantené Divine en marcha';

  @override
  String get supporterHeroBody =>
      'Divine es gratis y siempre lo será. Si querés ayudarnos a que los loops sigan girando, hacete supporter mensual. Nada se bloquea — solo mantiene las luces prendidas y te ganás nuestro agradecimiento.';

  @override
  String get supporterActiveBadge =>
      'Sos supporter de Divine. Gracias por mantener esto en marcha.';

  @override
  String get supporterPurchasePending =>
      'Tu compra está pendiente de aprobación.';

  @override
  String get supporterPurchaseConfirming => 'Confirmando tu apoyo…';

  @override
  String get supporterStoreChecking => 'Revisando la tienda…';

  @override
  String get supporterUnavailable =>
      'Las suscripciones de supporter no están disponibles acá por ahora.';

  @override
  String get supporterRestorePurchases => 'Restaurar compras';

  @override
  String get supporterDismissError => 'Descartar error';

  @override
  String get supporterErrorStoreUnavailable =>
      'La tienda no está disponible en este dispositivo.';

  @override
  String get supporterErrorPurchaseFailed =>
      'La compra no se completó. No se te cobró nada.';

  @override
  String get supporterErrorPurchasePending =>
      'Tu compra está pendiente de aprobación.';

  @override
  String get supporterErrorRestoreFailed =>
      'No se encontró ninguna suscripción de supporter para restaurar.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Esta compra pertenece a otra cuenta de Divine.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine no pudo confirmar tu estado de supporter ahora mismo.';

  @override
  String get supporterErrorUnknown => 'Algo salió mal. Intentá de nuevo.';

  @override
  String get supporterDisclaimer =>
      'Divine confirma el estado de supporter después de que la tienda verifica tu compra. El reconocimiento es opcional, y el halo no es una verificación.';

  @override
  String get profileNotifyBellOff => 'Avisarme de nuevos vines';

  @override
  String get profileNotifyBellOn => 'Dejar de avisarme de nuevos vines';

  @override
  String get profileNotifyUpdateFailed => 'No se pudo guardar. ¿Reintentar?';

  @override
  String get savedSoundYourLabel => 'Tu etiqueta';

  @override
  String get savedSoundAddHashtags => 'Añadir hashtags';

  @override
  String get savedSoundDeviceOnly => 'Guardado en este dispositivo';

  @override
  String get savedSoundDetailsRetry =>
      'No se pudieron guardar esos datos. Toca para reintentar.';

  @override
  String get savedSoundFallbackTitle => 'Sonido guardado';

  @override
  String get savedSoundPreviewAction => 'Escuchar el sonido';

  @override
  String get savedSoundEditAction => 'Editar los datos del sonido';

  @override
  String get savedSoundRemoveAction => 'Quitar el sonido guardado';

  @override
  String get savedSoundClearHashtagFilter => 'Borrar el filtro de hashtags';

  @override
  String get soundAllowRemix =>
      'Permitir que otras personas remezclen este sonido';

  @override
  String get soundReuseUnavailable =>
      'Este sonido no se puede remezclar ahora mismo.';

  @override
  String get soundPublicCredit => 'Crédito público del sonido';

  @override
  String get soundCreditRequired =>
      'Añade el crédito público del sonido antes de publicar.';

  @override
  String get soundSharedAs => 'Compartido como';

  @override
  String get soundOwnWork => 'Este sonido lo hice yo';

  @override
  String soundCreatorBy(String creator) {
    return 'De $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Compartido por $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Se permite remezclar';

  @override
  String get soundCreditOnly => 'Solo crédito';

  @override
  String get soundCreditTitleLabel => 'Título del sonido';

  @override
  String get soundCreditCreatorLabel => 'Creador';

  @override
  String get soundCreditSourceUrlLabel => 'URL de origen';

  @override
  String get soundCreditPublicHashtagsLabel => 'Hashtags públicos';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Cancelar selección de etiquetas';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Aplicar etiquetas seleccionadas';

  @override
  String get userPickerCancelSemanticLabel => 'Cancelar selección de usuarios';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Confirmar usuarios seleccionados';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Borrar selección de usuarios';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Cancelar selección de advertencias de contenido';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Aplicar advertencias de contenido seleccionadas';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Cerrar el editor de vídeo';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Continuar a los detalles de la publicación';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Descartar cambios en $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Aplicar cambios en $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Eliminar audio';

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
  String get verifyTitle => 'Cuentas verificadas';

  @override
  String get verifySignedOutMessage =>
      'Iniciá sesión para vincular tus cuentas.';

  @override
  String get verifyIntro =>
      'Vinculá las cuentas que ya tenés, así saben que sos vos.';

  @override
  String get verifyLoadFailed => 'No se pudieron cargar tus vínculos.';

  @override
  String get verifyRetry => 'Reintentar';

  @override
  String get verifyLinkedSectionTitle => 'Vinculadas';

  @override
  String get verifyVerifierUnreachable =>
      'No pudimos contactar al verificador, así que aparecen sin comprobar.';

  @override
  String get verifyAddSectionTitle => 'Agregar una cuenta';

  @override
  String get verifyAllPlatformsLinked => 'Ya vinculaste todo lo que admitimos.';

  @override
  String get verifyStatusVerified => 'Verificada';

  @override
  String get verifyStatusUnverified => 'Sin verificar';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Desvincular la cuenta de $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return '¿Desvincular $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity deja de aparecer en tu perfil. Podés vincularla de nuevo más adelante, pero vas a tener que iniciar sesión o publicar una prueba nueva.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Desvincular';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Vincular tu cuenta de $platform';
  }

  @override
  String get verifyOneTapBadge => 'Un toque';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Iniciá sesión en $platform y nosotros hacemos el resto. No se publica nada.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Continuar con $platform';
  }

  @override
  String get verifyConnectProofTitle => 'O publicá una prueba';

  @override
  String get verifyConnectProofExplainer =>
      'Publicá tu npub en tu cuenta y después pegá el enlace a esa publicación.';

  @override
  String get verifyNpubLabel => 'Tu npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Copiar tu npub';

  @override
  String get verifyNpubCopied => 'npub copiado';

  @override
  String get verifyIdentityLabel => 'Nombre de la cuenta';

  @override
  String get verifyProofLabel => 'Enlace a tu publicación';

  @override
  String get verifyConnectProofCta => 'Comprobar y vincular';

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
      'No pudimos contactar al verificador. Probá de nuevo en un momento.';

  @override
  String get verifyErrorOauthFailed => 'No salió. Probá otra vez.';

  @override
  String get verifyErrorHandleRequired => 'Escribí tu handle primero.';

  @override
  String get verifyErrorPublishFailed =>
      'Verificada, pero ningún relay aceptó la actualización. Probá de nuevo.';

  @override
  String get verifyErrorOauthUnavailable =>
      'El inicio de sesión de un toque todavía no está configurado acá. Usá la prueba de abajo.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Creá un gist público con tu npub en el primer archivo y pegá el enlace del gist.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Publicá tu npub en un canal de Discord que nuestro bot pueda leer y pegá el enlace del mensaje. Una invitación al servidor no prueba nada.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tuiteá tu npub desde esa cuenta y pegá el enlace del tuit.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Publicá tu npub desde esa cuenta y pegá el enlace. El nombre de la cuenta necesita la instancia — mastodon.social/@alice, no solo alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Se vincula el canal, no tu cuenta de Telegram. Primero necesita un enlace público (Telegram crea los nuevos como privados). Publicá tu npub ahí y pegá el enlace del mensaje.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      '¿Iniciaste sesión arriba? No hace falta nada más. Si no, publicá tu npub y pegá el enlace de esa publicación.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Poné tu npub en la descripción de un video y pegá el enlace de ese video.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Poné tu npub en la descripción de un video y pegá el enlace de ese video.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform quedó vinculada.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Eso es un canal privado o una invitación. Dale al canal un enlace público y después pegá el enlace del mensaje.';

  @override
  String get verifyErrorRemoveFailed =>
      'No se pudo desvincular. Probá de nuevo.';

  @override
  String get verifyErrorLinksUnreadable =>
      'No pudimos leer tus vínculos actuales, así que no se cambió nada. Revisá tu conexión y probá de nuevo.';

  @override
  String get verifyChannelLabel => 'Nombre del canal';

  @override
  String get verifyHowItWorksTitle => '¿Cómo funciona?';

  @override
  String get verifyHowItWorksIntro =>
      'Pensalo como un apretón de manos entre dos cuentas:';

  @override
  String get verifyHowItWorksYourSide =>
      'Tu perfil de Divine dice: «Soy @alice en Twitter».';

  @override
  String get verifyHowItWorksOtherSide =>
      'Tu cuenta de Twitter confirma: «Sí, ese perfil de Divine es mío».';

  @override
  String get verifyHowItWorksBothSides =>
      'Revisamos los dos lados. Si coinciden, quedás verificado. Nadie puede falsearlo: alguien puede copiar tu nombre y tu foto, pero no puede publicar desde tu cuenta real.';

  @override
  String get verifyHowItWorksOwnership =>
      'Los vínculos viven en tu propia identidad Nostr, así que podés quitarlos desde acá cuando quieras.';

  @override
  String get generalSettingsSectionIdentity => 'Identidad';

  @override
  String get libraryFilterAll => 'Todos';

  @override
  String get libraryFilterArchive => 'Archivo';

  @override
  String get libraryFilterDeleted => 'Eliminados';

  @override
  String get libraryCategoryNewChipLabel => 'Nueva';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Crear una categoría';

  @override
  String get libraryCategoryCreateTitle => 'Nueva categoría';

  @override
  String get libraryCategoryCreateAction => 'Crear';

  @override
  String get libraryCategoryRenameTitle => 'Cambiar el nombre de la categoría';

  @override
  String get libraryCategoryRenameAction => 'Cambiar nombre';

  @override
  String get libraryCategoryDeleteAction => 'Eliminar categoría';

  @override
  String get libraryCategoryNameLabel => 'Nombre de la categoría';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Tus clips se quedan. Solo vuelven a Todos.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Cambiar el nombre o eliminar esta categoría';

  @override
  String get libraryCategoryMoveTitle => 'Mover a';

  @override
  String get libraryCategoryMoveNone => 'Sin categoría';

  @override
  String get libraryCategoryMoveNewCategory => 'Nueva categoría';

  @override
  String get libraryArchiveAction => 'Archivar';

  @override
  String get libraryUnarchiveAction => 'Desarchivar';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Mantener en estas categorías?',
      one: '¿Mantener en esta categoría?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Mantener en $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'Mantener en sus categorías';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Quitar de $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Quitar de sus categorías';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Mover los clips seleccionados';

  @override
  String get libraryCategoryEmptyTitle => 'Aquí todavía no hay nada';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Selecciona algunos clips y muévelos a esta categoría.';

  @override
  String get libraryArchiveEmptyTitle => 'Nada archivado';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Los clips archivados esperan aquí, fuera de tu biblioteca principal.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips movidos a $name',
      one: '1 clip movido a $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips fuera de su categoría',
      one: '1 clip fuera de su categoría',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips archivados',
      one: '1 clip archivado',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips de vuelta en tu biblioteca',
      one: '1 clip de vuelta en tu biblioteca',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Cambiar correo';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Lleva tu cuenta a otra dirección';

  @override
  String get accountSettingsChangePassword => 'Cambiar contraseña';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Elige una nueva contraseña para iniciar sesión';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Tu sesión caducó. Inicia sesión otra vez para hacer este cambio.';

  @override
  String get accountCredentialsRateLimited =>
      'Demasiados intentos. Espera unos minutos.';

  @override
  String get accountCredentialsNetwork =>
      'No pudimos conectar con Divine. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get accountCredentialsUnknown => 'No funcionó. Inténtalo de nuevo.';

  @override
  String get changePasswordSubtitle =>
      'Escribe tu contraseña actual y luego elige una nueva.';

  @override
  String get changePasswordCurrentLabel => 'Contraseña actual';

  @override
  String get changePasswordWrongCurrent => 'Esa no es tu contraseña actual.';

  @override
  String get changePasswordSuccess => 'Contraseña cambiada.';

  @override
  String get changeEmailSubtitle =>
      'Enviaremos un enlace de confirmación a tu nueva dirección y a la de tu cuenta. Tu correo cambia cuando confirmes en ambas.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'En tu cuenta: $email';
  }

  @override
  String get changeEmailNewLabel => 'Nuevo correo';

  @override
  String get changeEmailPasswordLabel => 'Tu contraseña';

  @override
  String get changeEmailSameAsCurrent => 'Esa ya es tu dirección de correo.';

  @override
  String get changeEmailWrongPassword => 'Esa no es tu contraseña.';

  @override
  String get changeEmailSubmit => 'Enviar enlaces de confirmación';

  @override
  String get changeEmailSentTitle => 'Dos enlaces van en camino';

  @override
  String changeEmailSentMessage(String email) {
    return 'Confirma desde $email y desde la dirección de tu cuenta. Tu correo cambia cuando hagas las dos.';
  }

  @override
  String get changeEmailSentExpiry => 'Los enlaces caducan a las 24 horas.';

  @override
  String get changeEmailSentDone => 'Entendido';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount videos',
      one: '$formattedCount video',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Mutuo';

  @override
  String get socialProofFollowsYou => 'Te sigue';

  @override
  String get socialProofYouFollow => 'Siguiendo';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount seguidores',
      one: '$formattedCount seguidor',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Los videos no se están cargando.\nEs cosa nuestra, no tuya: ya estamos en ello.';

  @override
  String get feedOfflineMessage =>
      'Estás sin conexión.\nRevisa tu conexión e inténtalo de nuevo.';

  @override
  String get dbFailureTitle => 'no se pudo desbloquear tu base de datos local';

  @override
  String get dbFailureAdviceResettable =>
      'Reiniciar no va a arreglar esto. Restablecer la base de datos local de abajo le da a Divine un comienzo limpio — tu cuenta se mantiene.';

  @override
  String get dbFailureAdviceRestart =>
      'Reiniciá Divine después de desbloquear tu dispositivo. Si esto sigue pasando, actualizá la app o contactá con soporte.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Probá reiniciar Divine una vez. Si esto sigue pasando, actualizá la app o contactá con soporte. Tus datos locales siguen acá.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnóstico: $code';
  }

  @override
  String get dbFailureCloseApp => 'cerrar Divine';

  @override
  String get dbFailureResetAction => 'restablecer base de datos local';

  @override
  String get dbFailureConfirmTitle => '¿restablecer tu base de datos local?';

  @override
  String get dbFailureConfirmBody =>
      'Tu cuenta se mantiene. Los borradores y clips guardados en este dispositivo se eliminan — los mensajes y feeds vuelven desde la red.';

  @override
  String get dbFailureResetConfirm => 'restablecer base de datos local ahora';

  @override
  String get dbFailureCancel => 'cancelar';

  @override
  String get dbFailureResetFailed =>
      'Eso no funcionó. Cerrá Divine y probá de nuevo.';

  @override
  String get dbFailureResetDoneTitle => 'base de datos local restablecida';

  @override
  String get dbFailureResetDoneBody =>
      'Cerrá Divine y volvé a abrirlo — el próximo inicio crea una base de datos local nueva.';

  @override
  String get authSignInOptionsInfo =>
      'Acerca de las opciones de inicio de sesión';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get followUserSemanticLabel => 'Seguir usuario';

  @override
  String get unfollowUserSemanticLabel => 'Dejar de seguir al usuario';

  @override
  String get commentsLoadingSemanticLabel => 'Cargando comentarios';

  @override
  String get analyticsWindowAll => 'Todo';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Seguir usuario $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Dejar de seguir al usuario $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / mes';
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
      'Acaba de salir una actualización. Échale un vistazo →';

  @override
  String get updateModerateTitle =>
      'Hay una actualización desde la última vez que miraste';

  @override
  String get updateUrgentTitle => 'Te faltan correcciones importantes';

  @override
  String get updateNotNow => 'Ahora no';

  @override
  String get updateAction => 'Actualizar';

  @override
  String updateNewIn(String version) {
    return 'Novedades de $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Actualización disponible';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Recuperação de clipes';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Encontra gravações salvas em outra conta e arquivos de vídeo que nenhum registro referencia mais.';

  @override
  String get devOptionsClipRecoveryScan => 'Verificar';

  @override
  String get devOptionsClipRecoveryFailure => 'A recuperação de clipes falhou';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips clipes',
      one: '$clips clipe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts rascunhos',
      one: '$drafts rascunho',
    );
    return 'Visíveis agora: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Ocultos em outras contas';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clips clipes',
      one: '$clips clipe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts rascunhos',
      one: '$drafts rascunho',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Mover para esta conta';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Arquivos sem referência: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Reconstruir na biblioteca';

  @override
  String get devOptionsClipRecoveryEmpty => 'Nada para recuperar';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes recuperados',
      one: '$count clipe recuperado',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Relatório de recuperação copiado';

  @override
  String get devOptionsStorageFootprint => 'Uso de armazenamento';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Todas as pastas em que o app escreve. Limpar o cache libera apenas uma parte.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Medir';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Total: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied =>
      'Relatório de armazenamento copiado';

  @override
  String get devOptionsStorageFootprintFailure =>
      'Não foi possível medir o armazenamento';

  @override
  String get feedTuningMoreLabel => 'Mais como este';

  @override
  String get feedTuningLessLabel => 'Menos como este';

  @override
  String get feedTuningUndo => 'Desfazer';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Abrir o vídeo referenciado';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSecureAccount => 'Proteja sua conta';

  @override
  String get settingsSessionExpired => 'Sessão expirada';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Entre novamente para recuperar o acesso completo';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Estatísticas de criador';

  @override
  String get settingsSupportCenter => 'Central de suporte';

  @override
  String get settingsNotifications => 'Notificações';

  @override
  String get settingsBlueskyPublishing => 'Publicação no Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gerencie o crosspost para o Bluesky';

  @override
  String get settingsNostrSettings => 'Configurações do Nostr';

  @override
  String get settingsIntegratedApps => 'Apps integrados';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Apps de terceiros aprovados que rodam dentro do Divine';

  @override
  String get settingsExperimentalFeatures => 'Recursos experimentais';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Ajustes que podem dar chilique—experimente se estiver curioso.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Permissões de integração';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Revise e revogue as aprovações de integração lembradas';

  @override
  String settingsVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get settingsVersionEmpty => 'Versão';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'O modo desenvolvedor já está ativado';

  @override
  String get settingsDeveloperModeEnabled => 'Modo desenvolvedor ativado!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Mais $count toques para ativar o modo desenvolvedor';
  }

  @override
  String get settingsShareDivine => 'Compartilhe Divine com seus amigos';

  @override
  String get settingsSwitchAccount => 'Trocar de conta';

  @override
  String get settingsAddAnotherAccount => 'Adicionar outra conta';

  @override
  String get settingsAccountSwitchFailed =>
      'Não foi possível trocar de conta. Tente novamente.';

  @override
  String get settingsUnsavedDraftsTitle => 'Rascunhos não salvos';

  @override
  String get settingsUploadInProgressTitle => 'Envio em andamento';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vídeos',
      one: 'vídeo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seus vídeos ficam como rascunhos',
      one: 'seu vídeo fica como rascunho',
    );
    return 'Você ainda tem $count $_temp0 enviando. Trocar de conta interrompe o envio — $_temp1 nesta conta.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'rascunhos não salvos',
      one: 'rascunho não salvo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seus rascunhos',
      one: 'seu rascunho',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'eles',
      one: 'ele',
    );
    return 'Você tem $count $_temp0. Trocar de conta vai manter $_temp1, mas talvez você queira publicar ou revisar $_temp2 antes.';
  }

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsSwitchAnyway => 'Trocar mesmo assim';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'A sessão dessa conta expirou. Entrar nela de novo significa sair da conta que você está usando agora.';

  @override
  String get settingsAppVersionLabel => 'Versão do app';

  @override
  String get settingsAppLanguage => 'Idioma do app';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (padrão do dispositivo)';
  }

  @override
  String get settingsAppLanguageTitle => 'Idioma do app';

  @override
  String get settingsAppLanguageDescription =>
      'Escolha o idioma da interface do app';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Usar idioma do dispositivo';

  @override
  String get settingsGeneralTitle => 'Configurações gerais';

  @override
  String get settingsContentSafetyTitle => 'Conteúdo e segurança';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRAÇÕES';

  @override
  String get generalSettingsSectionViewing => 'VISUALIZAÇÃO';

  @override
  String get generalSettingsSectionCreating => 'CRIAÇÃO';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get appearanceSettingsTitle => 'Aparência';

  @override
  String get appearanceSettingsSubtitle =>
      'Escolhe como o Divine aparece neste dispositivo';

  @override
  String get appearanceSettingsSystem => 'Padrão do sistema';

  @override
  String get appearanceSettingsLight => 'Claro';

  @override
  String get appearanceSettingsDark => 'Escuro';

  @override
  String get generalSettingsClosedCaptions => 'Legendas';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Mostrar legendas quando os vídeos tiverem';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Só vídeos quadrados';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Mantenha os feeds no formato quadrado clássico';

  @override
  String get contentPreferencesTitle => 'Preferências de conteúdo';

  @override
  String get contentPreferencesContentFilters => 'Filtros de conteúdo';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gerencie os filtros de aviso de conteúdo';

  @override
  String get contentPreferencesContentLanguage => 'Idioma do conteúdo';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (padrão do dispositivo)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Marque seus vídeos com um idioma para que os espectadores possam filtrar o conteúdo.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Usar idioma do dispositivo (padrão)';

  @override
  String get contentPreferencesAudioSharing =>
      'Liberar meu áudio para reutilização';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Quando ativado, outras pessoas podem usar o áudio dos seus vídeos';

  @override
  String get contentPreferencesMusicMode => 'Modo música';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Desliga a limpeza de ruído que achata os instrumentos. Melhor para música, mais bruto nas vozes.';

  @override
  String get contentPreferencesAccountLabels => 'Rótulos da conta';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Rótulos próprios para seu conteúdo';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Rótulos de conteúdo da conta';

  @override
  String get contentPreferencesClearAll => 'Limpar tudo';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Selecione tudo que se aplica à sua conta';

  @override
  String get contentPreferencesDoneNoLabels => 'Concluído (sem rótulos)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Concluído ($count selecionados)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Dispositivo de entrada de áudio';

  @override
  String get contentPreferencesAutoRecommended => 'Automático (recomendado)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Seleciona automaticamente o melhor microfone';

  @override
  String get contentPreferencesSelectAudioInput =>
      'Selecionar entrada de áudio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Microfone desconhecido';

  @override
  String get contentFiltersAdultContent => 'CONTEÚDO ADULTO';

  @override
  String get contentFiltersViolenceGore => 'VIOLÊNCIA E SANGUE';

  @override
  String get contentFiltersSubstances => 'SUBSTÂNCIAS';

  @override
  String get contentFiltersOther => 'OUTROS';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifique sua idade em Segurança e privacidade para liberar os filtros de conteúdo adulto';

  @override
  String get contentFiltersShow => 'Mostrar';

  @override
  String get contentFiltersWarn => 'Avisar';

  @override
  String get contentFiltersFilterOut => 'Filtrar';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Esta conta não está disponível';

  @override
  String get profileInvalidId => 'ID de perfil inválido';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Confira $displayName no Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName no Divine';
  }

  @override
  String get profileShareFailed =>
      'Falha ao compartilhar perfil. Por favor, tente novamente.';

  @override
  String get profileCopyPublicKey => 'Copiar chave pública (npub)';

  @override
  String get profileGetEmbedCode => 'Obter código de incorporação';

  @override
  String get profilePublicKeyCopied =>
      'Chave pública copiada para a área de transferência';

  @override
  String get profileEmbedCodeCopied =>
      'Código de incorporação copiado para a área de transferência';

  @override
  String get profileMoreTooltip => 'Mais';

  @override
  String get profileMoreSemanticLabel => 'Mais opções';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Fechar avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Fechar pré-visualização do avatar';

  @override
  String get profileFollowingLabel => 'Seguindo';

  @override
  String get profileFollowLabel => 'Seguir';

  @override
  String get profileBlockedLabel => 'Bloqueado';

  @override
  String get profileFollowersLabel => 'Seguidores';

  @override
  String get profileFollowingStatLabel => 'Seguindo';

  @override
  String get profileVideosLabel => 'Vídeos';

  @override
  String get profileCollabsLabel => 'Colaborações';

  @override
  String get profileLikedLabel => 'Curtidos';

  @override
  String get profileRepostsLabel => 'Reposts';

  @override
  String get profileListsLabel => 'Listas';

  @override
  String get profileCommentsLabel => 'Comentários';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites de colaborador ainda precisam ser enviados',
      one: '$count convite de colaborador ainda precisa ser enviado',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Mantivemos o convite na fila. Tente reenviá-lo aqui.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Para \"$title\". Tente reenviá-lo aqui.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Tentar novamente';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Tentando novamente';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Não é possível reenviar o convite de colaborador agora.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites de colaborador ainda precisam ser enviados.',
      one: '$count convite de colaborador ainda precisa ser enviado.',
      zero: 'Convites de colaborador enviados.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colaboradores não podem receber convites.',
      one: '$count colaborador não pode receber convites.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count usuários';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Bloquear $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Quando você bloqueia alguém:';

  @override
  String get profileBlockBulletHidePosts =>
      'Os posts dessa pessoa não vão aparecer no seu feed.';

  @override
  String get profileBlockBulletCantView =>
      'Ela não poderá ver seu perfil, te seguir ou ver seus posts.';

  @override
  String get profileBlockBulletNoNotify =>
      'Ela não será notificada sobre essa mudança.';

  @override
  String get profileBlockBulletYouCanView =>
      'Você ainda poderá ver o perfil dela.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Bloquear $displayName';
  }

  @override
  String get profileCancelButton => 'Cancelar';

  @override
  String get profileLearnMore => 'Saiba mais';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Desbloquear $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'Quando você desbloqueia essa pessoa:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Os posts dela vão voltar a aparecer no seu feed.';

  @override
  String get profileUnblockBulletCanView =>
      'Ela poderá ver seu perfil, te seguir e ver seus posts.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Ela não será notificada sobre essa mudança.';

  @override
  String get profileLearnMoreAt => 'Saiba mais em ';

  @override
  String get profileUnblockButton => 'Desbloquear';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Deixar de seguir $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Bloquear $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Desbloquear $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Denunciar $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Adicionar $displayName a uma lista';
  }

  @override
  String get profileNoCollabsTitle => 'Sem colabs ainda';

  @override
  String get profileCollabsOwnEmpty =>
      'Vídeos em que você colabora vão aparecer aqui';

  @override
  String get profileCollabsOtherEmpty =>
      'Vídeos em que essa pessoa colabora vão aparecer aqui';

  @override
  String get profileErrorLoadingCollabs => 'Erro ao carregar vídeos de colab';

  @override
  String get profileNoSavedVideosTitle => 'Nada salvo ainda';

  @override
  String get profileSavedOwnEmpty =>
      'Salve vídeos pelo menu de compartilhamento e eles aparecem aqui.';

  @override
  String get profileErrorLoadingSaved => 'Erro ao carregar vídeos salvos';

  @override
  String get profileNoCommentsOwnTitle => 'Nenhum comentário ainda';

  @override
  String get profileNoCommentsOtherTitle => 'Sem comentários';

  @override
  String get profileCommentsOwnEmpty =>
      'Seus comentários e respostas vão aparecer aqui';

  @override
  String get profileCommentsOtherEmpty =>
      'Os comentários e respostas dessa pessoa vão aparecer aqui';

  @override
  String get profileErrorLoadingComments => 'Erro ao carregar comentários';

  @override
  String get profileVideoRepliesSection => 'Respostas em vídeo';

  @override
  String get profileCommentsSection => 'Comentários';

  @override
  String get profileEditLabel => 'Editar';

  @override
  String get profileLibraryLabel => 'Biblioteca';

  @override
  String get profileNoLikedVideosTitle => 'Sem vídeos curtidos ainda';

  @override
  String get profileLikedOwnEmpty => 'Vídeos que você curtir vão aparecer aqui';

  @override
  String get profileLikedOtherEmpty =>
      'Vídeos que essa pessoa curtir vão aparecer aqui';

  @override
  String get profileErrorLoadingLiked => 'Erro ao carregar vídeos curtidos';

  @override
  String get profileNoRepostsTitle => 'Sem reposts ainda';

  @override
  String get profileRepostsOwnEmpty =>
      'Vídeos que você repostar vão aparecer aqui';

  @override
  String get profileRepostsOtherEmpty =>
      'Vídeos que essa pessoa repostar vão aparecer aqui';

  @override
  String get profileErrorLoadingReposts => 'Erro ao carregar vídeos repostados';

  @override
  String get profileNoVideosTitle => 'Sem vídeos ainda';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Compartilhe seu primeiro vídeo para vê-lo aqui';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Este usuário ainda não compartilhou nenhum vídeo';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatura do vídeo $number';
  }

  @override
  String get profileShowMore => 'Mostrar mais';

  @override
  String get profileShowLess => 'Mostrar menos';

  @override
  String get dmMessageDisplayLimitReached =>
      'O restante desta mensagem não é apresentado.';

  @override
  String get profileCompleteYourProfile => 'Complete seu perfil';

  @override
  String get profileCompleteSubtitle =>
      'Adicione seu nome, bio e foto para começar';

  @override
  String get profilePleaseTryAgain => 'Por favor, tente novamente';

  @override
  String get profileSecureYourAccount => 'Proteja sua conta';

  @override
  String get profileSecureSubtitle =>
      'Adicione e-mail e senha para recuperar sua conta em qualquer dispositivo';

  @override
  String get profileRetryButton => 'Tentar novamente';

  @override
  String get profileSessionExpired => 'Sessão expirada';

  @override
  String get profileSignInToRestore =>
      'Entre novamente para recuperar o acesso completo';

  @override
  String get profileSignInButton => 'Entrar';

  @override
  String get profileMaybeLaterLabel => 'Talvez depois';

  @override
  String get profileSecurePrimaryButton => 'Adicionar e-mail e senha';

  @override
  String get profileCompletePrimaryButton => 'Atualizar seu perfil';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Curtidas';

  @override
  String get profileMyLibraryLabel => 'Minha biblioteca';

  @override
  String get profileMessageLabel => 'Mensagem';

  @override
  String get profileShareLabel => 'Compartilhar perfil';

  @override
  String get profileDeletedAccountName => 'Conta excluída';

  @override
  String get inboxActionReportVanishedAccount => 'Denunciar esta conta';

  @override
  String get inboxActionBlockVanishedAccount => 'Bloquear esta conta';

  @override
  String get inboxActionUnblockVanishedAccount => 'Desbloquear esta conta';

  @override
  String get inboxReportedVanishedAccount => 'Esta conta foi denunciada';

  @override
  String get inboxBlockedVanishedAccount => 'Esta conta foi bloqueada';

  @override
  String get inboxUnblockedVanishedAccount => 'Esta conta foi desbloqueada';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Isso remove a conversa da sua caixa de entrada. Se essa pessoa te enviar mensagem de novo, uma nova conversa começa.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Esta conta foi excluída';

  @override
  String get profileUserFallback => 'usuário';

  @override
  String get profileLinkCopied => 'Link do perfil copiado';

  @override
  String get profileSetupEditProfileTitle => 'Editar perfil';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Configura o teu perfil antes de adicionares um endereço NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Criar perfil';

  @override
  String get profileSetupBackLabel => 'Voltar';

  @override
  String get profileSetupAboutNostr => 'Sobre o Nostr';

  @override
  String get profileSetupProfilePublished => 'Perfil publicado com sucesso!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Salvar alterações?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Salve suas edições antes de sair, ou descarte e siga em frente.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Salvar alterações';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Descartar alterações';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Continuar editando';

  @override
  String get profileSetupCreateNewProfile => 'Criar novo perfil?';

  @override
  String get profileSetupNoExistingProfile =>
      'Não encontramos um perfil existente nos seus relays. Publicar vai criar um novo perfil. Continuar?';

  @override
  String get profileSetupPublishButton => 'Publicar';

  @override
  String get profileSetupUsernameTaken =>
      'Esse nome de usuário acabou de ser pego. Escolha outro.';

  @override
  String get profileSetupClaimFailed =>
      'Falha ao reivindicar o nome de usuário. Tente novamente.';

  @override
  String get profileSetupPublishFailed =>
      'Falha ao publicar perfil. Tente novamente.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Não foi possível acessar a rede. Verifique sua conexão e tente novamente.';

  @override
  String get profileSetupDisplayNameLabel => 'Nome de exibição';

  @override
  String get profileSetupDisplayNameRequired =>
      'Por favor, insira um nome de exibição';

  @override
  String get profileSetupBioLabel => 'Bio (opcional)';

  @override
  String get profileSetupWebsiteLabel => 'Site (opcional)';

  @override
  String get profileSetupPublicKeyLabel => 'Chave pública (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nome de usuário (opcional)';

  @override
  String get profileSetupUsernameHelper =>
      'Use letras, números ou hífens. Seu nome de usuário vira um endereço divine.video. Use o nome de exibição para espaços ou símbolos.';

  @override
  String get profileSetupSaveButton => 'Salvar';

  @override
  String get profileSetupSavingButton => 'Salvando...';

  @override
  String get profileSetupImageUrlTitle => 'Adicionar URL da imagem';

  @override
  String get profileSetupImageSelectionFailed =>
      'Falha ao selecionar a imagem. Cole uma URL de imagem abaixo.';

  @override
  String get profileSetupImagesTypeGroup => 'imagens';

  @override
  String get cameraPickErrorPermissionDenied =>
      'O acesso à câmera está desligado. Ative nas Configurações para tirar uma foto.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'O acesso à câmera não é permitido neste dispositivo.';

  @override
  String get cameraPickErrorBusy =>
      'O seletor já está aberto. Feche e tente novamente.';

  @override
  String get cameraPickErrorGeneric =>
      'Não foi possível abrir a câmera. Tente novamente.';

  @override
  String get profileSetupGotItButton => 'Entendi';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Não foi possível enviar a imagem. Tente novamente mais tarde.';

  @override
  String get profileSetupUploadNetworkError =>
      'Erro de rede: verifique sua conexão com a internet e tente novamente.';

  @override
  String get profileSetupUploadAuthError =>
      'Erro de autenticação: tente sair e entrar novamente.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Arquivo muito grande: escolha uma imagem menor (máx. 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Não foi possível enviar a imagem. Nossos servidores estão temporariamente indisponíveis. Tente novamente em instantes.';

  @override
  String get profileSetupBannerClearButton => 'Remover banner';

  @override
  String get profileSetupBannerChangeColor => 'Cor do banner';

  @override
  String get profileSetupChangeBannerTitle => 'Mudar banner';

  @override
  String get profileSetupBannerColorPickerTitle => 'Alterar a cor do banner';

  @override
  String get profileSetupBannerColorCustom => 'Personalizada';

  @override
  String get profileSetupBannerColorNone => 'Sem cor';

  @override
  String get profileSetupBannerColorLime => 'Lima';

  @override
  String get profileSetupBannerColorYellow => 'Amarelo';

  @override
  String get profileSetupBannerColorViolet => 'Violeta';

  @override
  String get profileSetupBannerColorPink => 'Rosa';

  @override
  String get profileSetupBannerColorOrange => 'Laranja';

  @override
  String get profileSetupBannerColorPurple => 'Roxo';

  @override
  String get profileSetupAvatarClearButton => 'Remover a foto';

  @override
  String get profileSetupImageTakePhoto => 'Tirar foto';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Carregar da galeria';

  @override
  String get profileSetupImagePasteLink => 'Colar um link de imagem';

  @override
  String get profileSetupEditAvatarLabel => 'Editar foto de perfil';

  @override
  String get profileSetupEditBannerLabel => 'Editar banner';

  @override
  String get profileSetupUsernameChecking => 'Verificando disponibilidade...';

  @override
  String get profileSetupUsernameAvailable => 'Nome de usuário disponível!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Nome de usuário já em uso';

  @override
  String get profileSetupUsernameReserved => 'Nome de usuário reservado';

  @override
  String get profileSetupContactSupport => 'Contatar suporte';

  @override
  String get profileSetupCheckAgain => 'Verificar novamente';

  @override
  String get profileSetupUsernameBurned =>
      'Este nome de usuário não está mais disponível';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'São permitidos apenas letras, números e hífens';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'O nome de usuário não pode começar nem terminar com hífen';

  @override
  String get profileSetupUsernameInvalidLength =>
      'O nome de usuário deve ter de 3 a 63 caracteres';

  @override
  String get profileSetupUsernameNetworkError =>
      'Não foi possível verificar a disponibilidade. Tente novamente.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Formato de nome de usuário inválido';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Falha ao verificar a disponibilidade';

  @override
  String get profileSetupUsernameReservedTitle => 'Nome de usuário reservado';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'O nome $username está reservado. Diga por que ele deveria ser seu.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'Ex.: é minha marca, nome artístico, etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Já entrou em contato com o suporte? Toque em \"Verificar novamente\" para ver se foi liberado pra você.';

  @override
  String get profileSetupSupportRequestSent =>
      'Solicitação de suporte enviada! Retornaremos em breve.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Não foi possível abrir o e-mail. Envie para: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Enviar solicitação';

  @override
  String get profileSetupUseOwnNip05 => 'Usar seu próprio endereço NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Endereço NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Formato NIP-05 inválido (ex.: nome@dominio.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Use o campo de nome de usuário acima para divine.video';

  @override
  String get nostrSettingsNip05Address => 'Endereço NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Use seu nome de usuário do divine.video ou aponte seu identificador para um endereço NIP-05 em um domínio que você controla.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Salvar NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 salvo';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Não foi possível salvar o NIP-05. Tente de novo.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Usar seu próprio NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'O NIP-05 liga um nome como voce@seudominio.com à sua identidade no Nostr. Você precisa controlar o domínio e hospedar um arquivo de verificação no caminho certo. Se estiver errado, as pessoas não te encontram e seu identificador verificado some. Continue só se já tiver configurado isso.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Continuar';

  @override
  String get profileSetupNip05ConfirmCancel => 'Cancelar';

  @override
  String get profileSetupProfilePicturePreview =>
      'Pré-visualização da foto de perfil';

  @override
  String get nostrInfoIntroBuiltOn => 'O Divine é construído sobre o Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' um protocolo aberto e resistente à censura que permite que as pessoas se comuniquem online sem depender de uma única empresa ou plataforma. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Quando você se cadastra no Divine, ganha uma nova identidade Nostr.';

  @override
  String get nostrInfoOwnership =>
      'O Nostr permite que você seja dono do seu conteúdo, identidade e grafo social, que podem ser usados em vários apps. O resultado é mais escolha, menos aprisionamento e uma internet social mais saudável e resiliente.';

  @override
  String get nostrInfoLingo => 'Termos do Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Seu endereço público no Nostr. É seguro compartilhar e permite que outras pessoas te encontrem, sigam ou te enviem mensagens pelos apps Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Sua chave privada e prova de propriedade. Ela dá controle total da sua identidade Nostr, então ';

  @override
  String get nostrInfoNsecWarning => 'mantenha sempre em segredo!';

  @override
  String get nostrInfoUsernameLabel => 'Nome de usuário Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Um nome legível (como @nome.divine.video) que aponta para sua npub. Ele torna sua identidade Nostr mais fácil de reconhecer e verificar, parecido com um endereço de e-mail.';

  @override
  String get nostrInfoLearnMoreAt => 'Saiba mais em ';

  @override
  String get nostrInfoGotIt => 'Entendi!';

  @override
  String get videoGridRefreshLabel => 'Procurando mais vídeos';

  @override
  String get videoGridOptionsTitle => 'Opções do vídeo';

  @override
  String get videoGridEditVideo => 'Editar vídeo';

  @override
  String get videoGridEditVideoSubtitle =>
      'Atualize título, descrição e hashtags';

  @override
  String get videoGridDeleteVideo => 'Excluir vídeo';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Remover este vídeo do Divine. Ele ainda pode aparecer em outros clientes Nostr.';

  @override
  String get videoGridDeletingContent => 'Excluindo conteúdo...';

  @override
  String get exploreTabFeatured => 'Destaques';

  @override
  String get exploreTabClassics => 'Clássicos';

  @override
  String get exploreTabNew => 'Novos';

  @override
  String get exploreTabPopular => 'Populares';

  @override
  String get exploreTabCategories => 'Categorias';

  @override
  String get exploreTabForYou => 'Para você';

  @override
  String get exploreTabLists => 'Listas';

  @override
  String get exploreTabIntegratedApps => 'Apps integrados';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Ainda não tem nada aqui. Volte em breve.';

  @override
  String get featuredTabLoadFailed => 'Não foi possível carregar esta coleção.';

  @override
  String get featuredTabRetry => 'Tentar de novo';

  @override
  String get exploreNoVideosAvailable => 'Nenhum vídeo disponível';

  @override
  String get exploreDiscoverLists => 'Descobrir listas';

  @override
  String get exploreAboutLists => 'Sobre listas';

  @override
  String get exploreAboutListsDescription =>
      'Listas te ajudam a organizar e curar conteúdo do Divine de duas formas:';

  @override
  String get explorePeopleLists => 'Listas de pessoas';

  @override
  String get explorePeopleListsDescription =>
      'Siga grupos de criadores e veja os últimos vídeos deles';

  @override
  String get exploreVideoLists => 'Listas de vídeos';

  @override
  String get exploreVideoListsDescription =>
      'Crie playlists dos seus vídeos favoritos para assistir depois';

  @override
  String get exploreMyLists => 'Minhas listas';

  @override
  String get exploreSubscribedLists => 'Listas inscritas';

  @override
  String get exploreErrorLoadingLists =>
      'Erro ao carregar listas. Por favor, tente novamente.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos novos',
      one: '$count vídeo novo',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vídeos novos',
      one: 'vídeo novo',
    );
    return 'Carregar $count $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'Reproduzir vídeo';

  @override
  String get videoPlayerMute => 'Silenciar vídeo';

  @override
  String get videoPlayerUnmute => 'Ativar som do vídeo';

  @override
  String get videoPlayerTapHint =>
      'Toque para reproduzir ou pausar. Toque duplo para curtir.';

  @override
  String get videoSettingsMenuOpen => 'Abrir configurações de reprodução';

  @override
  String get videoSettingsMenuClose => 'Fechar configurações de reprodução';

  @override
  String get videoSettingsCaptionsEnable => 'Ativar legendas';

  @override
  String get videoSettingsCaptionsDisable => 'Desativar legendas';

  @override
  String get videoSettingsAutoAdvanceOn => 'Avanço automático ativado';

  @override
  String get videoSettingsAutoAdvanceOff => 'Avanço automático desativado';

  @override
  String get videoSettingsCaptionsOn => 'Legendas ativadas';

  @override
  String get videoSettingsCaptionsOff => 'Legendas desativadas';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Legendas ativadas para este vídeo';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Legendas desativadas para este vídeo';

  @override
  String get contentWarningLabel => 'Aviso de conteúdo';

  @override
  String get contentWarningNudity => 'Nudez';

  @override
  String get contentWarningSexualContent => 'Conteúdo sexual';

  @override
  String get contentWarningPornography => 'Pornografia';

  @override
  String get contentWarningGraphicMedia => 'Mídia gráfica';

  @override
  String get contentWarningViolence => 'Violência';

  @override
  String get contentWarningSelfHarm => 'Automutilação';

  @override
  String get contentWarningDrugUse => 'Uso de drogas';

  @override
  String get contentWarningAlcohol => 'Álcool';

  @override
  String get contentWarningTobacco => 'Tabaco';

  @override
  String get contentWarningGambling => 'Jogos de azar';

  @override
  String get contentWarningProfanity => 'Palavrões';

  @override
  String get contentWarningFlashingLights => 'Luzes piscantes';

  @override
  String get contentWarningAiGenerated => 'Gerado por IA';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Conteúdo sensível';

  @override
  String get contentWarningDescNudity => 'Contém nudez ou nudez parcial';

  @override
  String get contentWarningDescSexual => 'Contém conteúdo sexual';

  @override
  String get contentWarningDescPorn => 'Contém conteúdo pornográfico explícito';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contém imagens gráficas ou perturbadoras';

  @override
  String get contentWarningDescViolence => 'Contém conteúdo violento';

  @override
  String get contentWarningDescSelfHarm => 'Contém referências à automutilação';

  @override
  String get contentWarningDescDrugs => 'Contém conteúdo relacionado a drogas';

  @override
  String get contentWarningDescAlcohol =>
      'Contém conteúdo relacionado a álcool';

  @override
  String get contentWarningDescTobacco =>
      'Contém conteúdo relacionado a tabaco';

  @override
  String get contentWarningDescGambling =>
      'Contém conteúdo relacionado a jogos de azar';

  @override
  String get contentWarningDescProfanity => 'Contém linguagem forte';

  @override
  String get contentWarningDescFlashingLights =>
      'Contém luzes piscantes (aviso de fotossensibilidade)';

  @override
  String get contentWarningDescAiGenerated => 'Este conteúdo foi gerado por IA';

  @override
  String get contentWarningDescSpoiler => 'Contém spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'O criador marcou isso como sensível';

  @override
  String get contentWarningDescDefault => 'O criador sinalizou este conteúdo';

  @override
  String get contentWarningDetailsTitle => 'Avisos de conteúdo';

  @override
  String get contentWarningDetailsSubtitle =>
      'O criador aplicou os seguintes rótulos:';

  @override
  String get contentWarningManageFilters => 'Gerenciar filtros de conteúdo';

  @override
  String get contentWarningViewAnyway => 'Ver mesmo assim';

  @override
  String get contentWarningReportContentTooltip => 'Denunciar conteúdo';

  @override
  String get contentWarningBlockUserTooltip => 'Bloquear usuário';

  @override
  String get contentWarningBlockedTitle => 'Conteúdo bloqueado';

  @override
  String get contentWarningBlockedPolicy =>
      'Este conteúdo foi bloqueado por violar as políticas.';

  @override
  String get contentWarningNoticeTitle => 'Aviso de conteúdo';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Conteúdo potencialmente nocivo';

  @override
  String get contentWarningView => 'Ver';

  @override
  String get contentWarningReportAction => 'Denunciar';

  @override
  String get contentWarningHideAllLikeThis => 'Ocultar todo conteúdo parecido';

  @override
  String get contentWarningNoFilterYet =>
      'Ainda não há filtro salvo para este aviso.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Vamos ocultar posts assim a partir de agora.';

  @override
  String get communitySuggestTitle => 'Ajude a classificar este vídeo';

  @override
  String get communitySuggestSubtitle =>
      'Faltando um aviso de conteúdo? Sua sugestão é pública, assinada e não pode ser retirada.';

  @override
  String get communitySuggestSubmit => 'Sugerir';

  @override
  String get communitySuggestSuccess => 'Obrigado. Sua sugestão foi enviada.';

  @override
  String get communitySuggestFailure =>
      'Não foi possível enviar sua sugestão. Tente novamente.';

  @override
  String get communitySuggestAlready => 'Você já sugeriu';

  @override
  String get communitySuggestActionLabel => 'Classificar';

  @override
  String get videoErrorNotFound => 'Vídeo não encontrado';

  @override
  String get videoErrorPlayback => 'Erro na reprodução do vídeo';

  @override
  String get videoErrorAgeRestricted => 'Conteúdo com restrição de idade';

  @override
  String get videoErrorUnavailable => 'Vídeo indisponível';

  @override
  String get videoErrorUnavailableBody =>
      'Este vídeo não está disponível no momento.';

  @override
  String get videoErrorRetry => 'Tentar novamente';

  @override
  String get videoErrorContentRestricted => 'Conteúdo restrito';

  @override
  String get videoErrorContentRestrictedBody =>
      'Este vídeo foi removido por violar nossas regras de conteúdo.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifique sua idade para ver este vídeo.';

  @override
  String get videoErrorSkip => 'Pular';

  @override
  String get videoErrorVerifyAgeButton => 'Verificar idade';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Não foi possível verificar sua idade. Por favor, tente novamente.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Tempo de verificação esgotado. Verifique sua conexão ou tente novamente em breve.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'O conteúdo adulto está desativado';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Ative nos seus filtros de conteúdo para assistir a este vídeo.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Abrir filtros de conteúdo';

  @override
  String get videoDetailLoadError => 'Falha ao carregar o vídeo';

  @override
  String get videoDetailLoadErrorBody =>
      'Alguma coisa deu errado no caminho. Tenta de novo.';

  @override
  String get videoDetailNotFoundBody =>
      'Pode ter sido apagado, estar fora de alcance ou escondido pelas tuas definições.';

  @override
  String get databaseCorruptionTitle => 'Seus dados locais foram corrompidos';

  @override
  String get databaseCorruptionBody =>
      'Feche o Divine e abra de novo — a gente conserta automaticamente. A gente salva o que der dos seus rascunhos e clipes, o resto recarrega.';

  @override
  String get databaseCorruptionCloseButton => 'Fechar o Divine';

  @override
  String get videoDetailContextTitle => 'Vídeo compartilhado';

  @override
  String get videoDetailCloseSemanticLabel => 'Fechar reprodutor de vídeo';

  @override
  String get videoFollowButtonFollow => 'Seguir';

  @override
  String get audioAttributionOriginalSound => 'Som original';

  @override
  String get audioAttributionUnavailableSound => 'Som indisponível';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirado em @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirado em @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'com @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'com @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colaboradores',
      one: '$count colaborador',
    );
    return '$_temp0. Toque para ver o perfil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Pendente';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Colaborador pendente';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending pendente(s))';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Toque para ver o perfil.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Toque para ver vídeos com esta hashtag.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Compartilhar vídeo';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post compartilhado com $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Post compartilhado com $count pessoas',
      one: 'Post compartilhado com $count pessoa',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Falha ao enviar vídeo';

  @override
  String get shareAddedToBookmarks => 'Adicionado aos favoritos';

  @override
  String get shareRemovedFromBookmarks => 'Removido dos favoritos';

  @override
  String get shareFailedToAddBookmark => 'Falha ao adicionar aos favoritos';

  @override
  String get shareFailedToRemoveBookmark => 'Falha ao remover dos favoritos';

  @override
  String get shareActionFailed => 'A ação falhou';

  @override
  String get shareWithTitle => 'Compartilhar com';

  @override
  String get shareFindPeople => 'Encontrar pessoas';

  @override
  String get shareFindPeopleMultiline => 'Encontrar\npessoas';

  @override
  String get shareSent => 'Enviado';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name selecionado';
  }

  @override
  String get shareMessageHint => 'Adicione uma mensagem opcional...';

  @override
  String get videoActionUnlike => 'Descurtir vídeo';

  @override
  String get videoActionLike => 'Curtir vídeo';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Curtir';

  @override
  String get videoActionReplyLabel => 'Responder';

  @override
  String get videoActionRepostLabel => 'Repostar';

  @override
  String get videoActionShareLabel => 'Compartilhar';

  @override
  String get videoActionReportLabel => 'Denunciar';

  @override
  String get videoActionReport => 'Denunciar vídeo';

  @override
  String get videoActionEditLabel => 'Editar';

  @override
  String get videoActionEdit => 'Editar vídeo';

  @override
  String get videoActionAboutLabel => 'Sobre';

  @override
  String get videoActionEnableAutoAdvance => 'Ativar avanço automático';

  @override
  String get videoActionDisableAutoAdvance => 'Desativar avanço automático';

  @override
  String get videoActionRemoveRepost => 'Remover repost';

  @override
  String get videoActionRepost => 'Repostar vídeo';

  @override
  String get videoActionViewComments => 'Ver comentários';

  @override
  String get videoActionMoreOptions => 'Mais opções';

  @override
  String get videoEngagementLikersTitle => 'Curtido por';

  @override
  String get videoEngagementRepostersTitle => 'Repostado por';

  @override
  String get videoEngagementLikersEmpty => 'Ainda sem curtidas';

  @override
  String get videoEngagementRepostersEmpty => 'Ainda sem reposts';

  @override
  String get videoEngagementLoadFailed => 'Não foi possível carregar a lista';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Abrir detalhes do vídeo';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Abrir detalhes do vídeo';

  @override
  String get videoOverlayCommentBarHint => 'Adicionar comentário...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Adicionar um comentário';

  @override
  String get videoOverlayCommentBarSendLabel => 'Enviar comentário';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Comentário publicado';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Não foi possível publicar o comentário';

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
  String get metadataBadgeNotDivine => 'Não-Divine';

  @override
  String get metadataBadgeHumanMade => 'Feito por humano';

  @override
  String get metadataSoundsLabel => 'Sons';

  @override
  String get metadataOriginalSound => 'Som original';

  @override
  String get metadataVerificationLabel => 'Verificação';

  @override
  String get metadataDeviceAttestation => 'Atestação do dispositivo';

  @override
  String get metadataPgpSignature => 'Assinatura PGP';

  @override
  String get metadataC2paCredentials => 'Credenciais de conteúdo C2PA';

  @override
  String get metadataProofManifest => 'Manifesto de prova';

  @override
  String get metadataVerificationInfoTooltip =>
      'O que significam essas verificações?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle =>
      'O que significam essas verificações';

  @override
  String get metadataVerificationInfoIntro =>
      'Esses sinais vêm da câmera e do próprio arquivo de vídeo. Quanto mais um vídeo carrega, mais conseguimos provar sobre a origem dele.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'O sistema operacional do celular garantiu o app que gravou isso. Forte indício de que veio de uma câmera, não de um arquivo que alguém enviou.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'O vídeo foi assinado criptograficamente no momento da captura. Se um único quadro mudar depois, a assinatura quebra.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Um registro de origem no padrão do setor, que viaja dentro do arquivo — então apps além do Divine também conseguem verificar.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'O registro completo do ProofMode: impressão digital do arquivo, marca de tempo e contexto da captura, junto com o vídeo.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Uma verificação ausente não torna o vídeo falso. Clipes antigos e uploads nunca tiveram uma — só significa que não podemos provar essa parte.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Saiba mais em $url';
  }

  @override
  String get metadataCreatorLabel => 'Criador';

  @override
  String get metadataCollaboratorsLabel => 'Colaboradores';

  @override
  String get metadataInspiredByLabel => 'Inspirado em';

  @override
  String get metadataRepostedByLabel => 'Repostado por';

  @override
  String metadataMoreReposters(int count) {
    return '+$count mais';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'Curtidas';

  @override
  String get metadataCommentsLabel => 'Comentários';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get metadataVineStatsLabel => 'No Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loops · $likes curtidas · $comments comentários · $reposts reposts';
  }

  @override
  String get metadataDivineStatsLabel => 'No Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views visualizações · $likes curtidas · $comments comentários · $reposts reposts';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publicado em $date';
  }

  @override
  String get devOptionsTitle => 'Opções do desenvolvedor';

  @override
  String get devOptionsDisableDeveloperMode =>
      'Desativar modo de desenvolvedor';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Ocultar opções de desenvolvedor das configurações';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Modo de desenvolvedor desativado';

  @override
  String get devOptionsShorebirdTitle => 'Patches do Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Patch em execução';

  @override
  String get devOptionsShorebirdNoPatch => 'Nenhum patch instalado';

  @override
  String get devOptionsShorebirdUnavailable => 'Indisponível nesta compilação';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Os patches só funcionam em uma compilação criada com shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Lendo o estado do patch…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Canal de testes ainda não verificado.';

  @override
  String get devOptionsShorebirdCheck => 'Verificar canal de testes';

  @override
  String get devOptionsShorebirdApply => 'Aplicar patch de testes';

  @override
  String get devOptionsShorebirdUseStable => 'Voltar às atualizações estáveis';

  @override
  String get devOptionsShorebirdChecking => 'Verificando o canal de testes…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Há um patch de testes pronto para aplicar.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Nenhum patch de testes para esta versão.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Baixado. Reinicie o app para carregá-lo.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Há uma reversão pronta. Reinicie para voltar à versão base.';

  @override
  String get devOptionsShorebirdApplying => 'Baixando e instalando…';

  @override
  String get devOptionsShorebirdApplied =>
      'Instalado. Reinicie o app para carregá-lo.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Nada foi instalado. Verifique o canal de testes e tente novamente.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Selecionando o canal estável…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Canal estável selecionado. Reinicie o app para verificar se há um patch estável.';

  @override
  String get devOptionsShorebirdFailure =>
      'Não funcionou. Verifique os registros para mais detalhes.';

  @override
  String get devOptionsPageLoadTimes => 'Tempos de carregamento de página';

  @override
  String get devOptionsNoPageLoads =>
      'Nenhum carregamento de página registrado ainda.\nNavegue pelo app para ver os dados de tempo.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visível: ${visibleMs}ms  |  Dados: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Telas mais lentas';

  @override
  String get devOptionsVideoPlaybackFormat => 'Formato de reprodução de vídeo';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Trocar ambiente?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Trocar para $envName?\n\nIsso vai limpar o cache de vídeos e reconectar ao novo relay.';
  }

  @override
  String get devOptionsCancel => 'Cancelar';

  @override
  String get devOptionsSwitch => 'Trocar';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Trocado para $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Trocado para $formatName — cache limpo';
  }

  @override
  String get featureFlagTitle => 'Feature flags';

  @override
  String get featureFlagResetAllTooltip =>
      'Redefinir todas as flags para o padrão';

  @override
  String get featureFlagError => 'Erro';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'O Divine é um sistema aberto - você controla suas conexões';

  @override
  String get relaySettingsInfoDescription =>
      'Estes relays distribuem seu conteúdo pela rede descentralizada Nostr. Você pode adicionar ou remover relays como quiser.';

  @override
  String get relaySettingsLearnMoreNostr => 'Saiba mais sobre o Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Encontre relays públicos em nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App não funcional';

  @override
  String get relaySettingsRequiresRelay =>
      'O Divine precisa de pelo menos um relay para carregar vídeos, publicar conteúdo e sincronizar dados.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Restaurar relay padrão';

  @override
  String get relaySettingsAddCustomRelay => 'Adicionar relay personalizado';

  @override
  String get relaySettingsAddRelay => 'Adicionar relay';

  @override
  String get relaySettingsRetry => 'Tentar novamente';

  @override
  String get relaySettingsNoStats => 'Ainda não há estatísticas disponíveis';

  @override
  String get relaySettingsConnection => 'Conexão';

  @override
  String get relaySettingsConnected => 'Conectado';

  @override
  String get relaySettingsDisconnected => 'Desconectado';

  @override
  String get relaySettingsSessionDuration => 'Duração da sessão';

  @override
  String get relaySettingsLastConnected => 'Última conexão';

  @override
  String get relaySettingsDisconnectedLabel => 'Desconectado';

  @override
  String get relaySettingsReason => 'Motivo';

  @override
  String get relaySettingsActiveSubscriptions => 'Assinaturas ativas';

  @override
  String get relaySettingsTotalSubscriptions => 'Total de assinaturas';

  @override
  String get relaySettingsEventsReceived => 'Eventos recebidos';

  @override
  String get relaySettingsEventsSent => 'Eventos enviados';

  @override
  String get relaySettingsRequestsThisSession => 'Solicitações nesta sessão';

  @override
  String get relaySettingsFailedRequests => 'Solicitações falhas';

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Carregando informações do relay...';

  @override
  String get relaySettingsAboutRelay => 'Sobre o relay';

  @override
  String get relaySettingsSupportedNips => 'NIPs suportados';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Ver site';

  @override
  String get relaySettingsRemoveRelayTitle => 'Remover relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Tem certeza que quer remover este relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Remover o relay do Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Remover o relay do Divine vai piorar a experiência no app. Vídeos, publicações e sincronização podem ficar menos confiáveis. Isso só deve ser feito por usuários experientes em Nostr.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Remover relay';

  @override
  String get relaySettingsCancel => 'Cancelar';

  @override
  String get relaySettingsRemove => 'Remover';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay removido: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Falha ao remover o relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forçando reconexão do relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Conectado a $count relay(s)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Falha ao conectar aos relays. Verifique sua conexão de rede.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Salvo neste dispositivo. Vamos sincronizar com sua conta quando a publicação voltar a funcionar.';

  @override
  String get relaySettingsAddRelayTitle => 'Adicionar relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Digite a URL WebSocket do relay que você quer adicionar:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Navegue por relays públicos em nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Adicionar';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay adicionado: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Falha ao adicionar o relay. Verifique a URL e tente novamente.';

  @override
  String get relaySettingsInvalidUrl =>
      'A URL do relay deve começar com wss:// ou ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'A URL do relay precisa usar wss:// (ws:// só é permitido em localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay padrão restaurado: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Falha ao restaurar o relay padrão. Verifique sua conexão de rede.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Não foi possível abrir o navegador';

  @override
  String get relaySettingsFailedToOpenLink => 'Falha ao abrir o link';

  @override
  String get relaySettingsExternalRelay => 'Relay externo';

  @override
  String get relaySettingsNotConnected => 'Não conectado';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Desconectado há $duration';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count inscrições';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count eventos';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'há $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'O Divine usa o protocolo Nostr para publicação descentralizada. Seu conteúdo vive nos relays que você escolher, e suas chaves são sua identidade.';

  @override
  String get nostrSettingsSectionNetwork => 'Rede';

  @override
  String get nostrSettingsSectionAccount => 'Conta';

  @override
  String get nostrSettingsSectionDangerZone => 'Zona de perigo';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle => 'Gerenciar conexões de relay Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnóstico de relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Depure conectividade de relay e problemas de rede';

  @override
  String get nostrSettingsMediaServers => 'Servidores de mídia';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configurar servidores de upload Blossom';

  @override
  String get settingsDeveloperOptions => 'Opções de desenvolvedor';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Seletor de ambiente e opções de depuração';

  @override
  String get nostrSettingsKeyManagement => 'Gerenciamento de chaves';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exporte, faça backup e restaure suas chaves Nostr';

  @override
  String get nostrSettingsClientAttribution => 'Atribuição do cliente';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Inclua uma tag de cliente Divine nos eventos que você publica para que outros apps Nostr possam atribuí-los corretamente. Sem ela, as denúncias que você envia têm menos peso quando nossos moderadores as analisam.';

  @override
  String get nostrSettingsMoveAccount => 'Mover sua conta';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Baixe seu arquivo e mova suas publicações e vídeos para outro relay ou servidor de mídia.';

  @override
  String get nostrSettingsRemoveKeys => 'Remover chaves do dispositivo';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Apague sua chave privada apenas deste dispositivo. Seu conteúdo continua nos relays, mas você vai precisar do backup da nsec para acessar sua conta de novo.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Não foi possível remover esta conta deste dispositivo. Tente novamente.';

  @override
  String get nostrSettingsDeleteAccount => 'Excluir conta e dados';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Envia solicitações de exclusão do seu conteúdo e desconecta você neste dispositivo. Relays, clientes, índices de busca e outros dispositivos conectados podem manter cópias.';

  @override
  String get relayDiagnosticTitle => 'Diagnósticos de relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Atualizar diagnósticos';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Última atualização: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status do relay';

  @override
  String get relayDiagnosticInitialized => 'Inicializado';

  @override
  String get relayDiagnosticReady => 'Pronto';

  @override
  String get relayDiagnosticNotInitialized => 'Não inicializado';

  @override
  String get relayDiagnosticDatabaseEvents => 'Eventos do banco de dados';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Assinaturas ativas';

  @override
  String get relayDiagnosticExternalRelays => 'Relays externos';

  @override
  String get relayDiagnosticConfigured => 'Configurado';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Conectado';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Eventos de vídeo';

  @override
  String get relayDiagnosticHomeFeed => 'Feed principal';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count vídeos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Descoberta';

  @override
  String get relayDiagnosticLoading => 'Carregando';

  @override
  String get relayDiagnosticYes => 'Sim';

  @override
  String get relayDiagnosticNo => 'Não';

  @override
  String get relayDiagnosticTestDirectQuery => 'Testar consulta direta';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Conectividade de rede';

  @override
  String get relayDiagnosticRunNetworkTest => 'Executar teste de rede';

  @override
  String get relayDiagnosticBlossomServer => 'Servidor Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testar todos os endpoints';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Erro';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL base';

  @override
  String get relayDiagnosticSummary => 'Resumo';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (média ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retestar tudo';

  @override
  String get relayDiagnosticRetrying => 'Tentando novamente...';

  @override
  String get relayDiagnosticRetryConnection => 'Tentar reconectar';

  @override
  String get relayDiagnosticTroubleshooting => 'Solução de problemas';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Status verde = Conectado e funcionando\n• Status vermelho = Falha na conexão\n• Se o teste de rede falhar, verifique a conexão com a internet\n• Se os relays estiverem configurados mas não conectados, toque em \"Tentar reconectar\"\n• Tire uma captura desta tela para debug';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Todos os endpoints REST estão saudáveis!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Alguns endpoints REST falharam - veja os detalhes acima';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Encontrados $count eventos de vídeo no banco de dados';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'Consulta falhou. Por favor, tente novamente.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Conectado a $count relay(s)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Falha ao conectar a qualquer relay';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Tentativa de reconexão falhou. Por favor, tente novamente.';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Conectado e autenticado';

  @override
  String get relayDiagnosticConnectedOnly => 'Conectado';

  @override
  String get relayDiagnosticNotConnected => 'Não conectado';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Nenhum relay configurado';

  @override
  String get relayDiagnosticFailed => 'Falhou';

  @override
  String get notificationSettingsTitle => 'Notificações';

  @override
  String get notificationSettingsResetTooltip => 'Redefinir para o padrão';

  @override
  String get notificationSettingsTypes => 'Tipos de notificação';

  @override
  String get notificationSettingsLikes => 'Curtidas';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Quando alguém curte seus vídeos';

  @override
  String get notificationSettingsComments => 'Comentários';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Quando alguém comenta nos seus vídeos';

  @override
  String get notificationSettingsFollows => 'Seguidores';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Quando alguém começa a te seguir';

  @override
  String get notificationSettingsMentions => 'Menções';

  @override
  String get notificationSettingsMentionsSubtitle => 'Quando você é mencionado';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Quando alguém reposta seus vídeos';

  @override
  String get notificationSettingsNewPosts => 'Novos vines';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Quando alguém que você acompanha posta';

  @override
  String get notificationSettingsActions => 'Ações';

  @override
  String get notificationSettingsMarkAllAsRead => 'Marcar tudo como lido';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Marcar todas as notificações como lidas';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Todas as notificações marcadas como lidas';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Falha ao marcar todas como lidas';

  @override
  String get notificationSettingsResetToDefaults =>
      'Configurações redefinidas para o padrão';

  @override
  String get notificationSettingsAbout => 'Sobre as notificações';

  @override
  String get notificationSettingsAboutDescription =>
      'As notificações são alimentadas pelo protocolo Nostr. Atualizações em tempo real dependem da sua conexão com os relays Nostr. Algumas notificações podem ter atrasos.';

  @override
  String get safetySettingsWhatYouSee => 'O QUE VOCÊ VÊ';

  @override
  String get safetySettingsWhatYouPublish => 'O QUE VOCÊ PUBLICA';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Mostrar apenas vídeos hospedados pelo Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ocultar vídeos servidos de outros hosts de mídia';

  @override
  String get safetySettingsModeration => 'MODERAÇÃO';

  @override
  String get safetySettingsBlockedUsers => 'USUÁRIOS BLOQUEADOS';

  @override
  String get safetySettingsAgeVerification => 'VERIFICAÇÃO DE IDADE';

  @override
  String get safetySettingsAgeConfirmation =>
      'Confirmo que tenho 18 anos ou mais';

  @override
  String get safetySettingsAgeRequired => 'Necessário para ver conteúdo adulto';

  @override
  String get safetySettingsAgeLockedForMinor => 'Bloqueado para a sua conta';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Serviço oficial de moderação (ativado por padrão)';

  @override
  String get safetySettingsPeopleIFollow => 'Pessoas que eu sigo';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Assinar rótulos de pessoas que você segue';

  @override
  String get safetySettingsAddCustomLabeler => 'Adicionar rótulo personalizado';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Digite a npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Adicionar rótulo personalizado';

  @override
  String get safetySettingsRemoveLabeler => 'Remover rótulo';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Digite o endereço npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Nenhum usuário bloqueado';

  @override
  String get safetySettingsUnblock => 'Desbloquear';

  @override
  String get safetySettingsUserUnblocked => 'Usuário desbloqueado';

  @override
  String get safetySettingsCancel => 'Cancelar';

  @override
  String get safetySettingsAdd => 'Adicionar';

  @override
  String get analyticsTitle => 'Estatísticas de criador';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnósticos';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Alternar diagnósticos';

  @override
  String get analyticsRetry => 'Tentar novamente';

  @override
  String get analyticsUnableToLoad =>
      'Não foi possível carregar as estatísticas.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Entre para ver as estatísticas de criador.';

  @override
  String get analyticsViewDataUnavailable =>
      'As visualizações estão indisponíveis no relay para esses posts. As métricas de curtidas/comentários/reposts continuam precisas.';

  @override
  String get analyticsViewDataTitle => 'Dados de visualização';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Atualizado $time • Os scores usam curtidas, comentários, reposts e views/loops do Funnelcake quando disponíveis.';
  }

  @override
  String get analyticsVideos => 'Vídeos';

  @override
  String get analyticsViews => 'Visualizações';

  @override
  String get analyticsInteractions => 'Interações';

  @override
  String get analyticsEngagement => 'Engajamento';

  @override
  String get analyticsFollowers => 'Seguidores';

  @override
  String get analyticsAvgPerPost => 'Média/Post';

  @override
  String get analyticsInteractionMix => 'Mix de interações';

  @override
  String get analyticsLikes => 'Curtidas';

  @override
  String get analyticsComments => 'Comentários';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Destaques de desempenho';

  @override
  String get analyticsMostViewed => 'Mais visto';

  @override
  String get analyticsMostDiscussed => 'Mais comentado';

  @override
  String get analyticsMostReposted => 'Mais repostado';

  @override
  String get analyticsNoVideosYet => 'Sem vídeos ainda';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Dados de visualização indisponíveis';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count visualizações';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count comentários';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Conteúdo em destaque';

  @override
  String get analyticsPublishPrompt =>
      'Publique alguns vídeos para ver o ranking.';

  @override
  String get analyticsEngagementRateExplainer =>
      '% à direita = taxa de engajamento (interações divididas por visualizações).';

  @override
  String get analyticsEngagementRateNoViews =>
      'A taxa de engajamento precisa de dados de visualização; os valores aparecem como N/A até as visualizações estarem disponíveis.';

  @override
  String get analyticsEngagementLabel => 'Engajamento';

  @override
  String get analyticsViewsUnavailable => 'visualizações indisponíveis';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interações';
  }

  @override
  String get analyticsPostAnalytics => 'Estatísticas do post';

  @override
  String get analyticsOpenPost => 'Abrir post';

  @override
  String get analyticsRecentDailyInteractions => 'Interações diárias recentes';

  @override
  String get analyticsNoActivityYet => 'Ainda sem atividade neste período.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interações = curtidas + comentários + reposts por data do post.';

  @override
  String get analyticsDailyBarExplainer =>
      'O tamanho da barra é relativo ao seu dia de maior engajamento nesta janela.';

  @override
  String get analyticsAudienceSnapshot => 'Resumo do público';

  @override
  String analyticsFollowersCount(String count) {
    return 'Seguidores: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Seguindo: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Detalhes do público por fonte/geografia/hora vão aparecer conforme o Funnelcake adicionar endpoints de estatísticas de público.';

  @override
  String get analyticsRetention => 'Retenção';

  @override
  String get analyticsRetentionWithViews =>
      'A curva de retenção e o detalhamento de tempo de visualização vão aparecer assim que os dados de retenção por segundo/faixa chegarem do Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Dados de retenção indisponíveis até que as estatísticas de visualização + tempo de reprodução sejam retornadas pelo Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnósticos';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total de vídeos: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Com visualizações: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Sem visualizações: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hidratado (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hidratado (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Fontes: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Usar dados de fixture';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Criar uma nova conta Divine';

  @override
  String get authCreateNewAccountShort => 'Criar nova conta';

  @override
  String get authSignInDifferentAccount => 'Entrar com outra conta';

  @override
  String get authUseAnotherAccount => 'Usar outra conta';

  @override
  String authContinueAs(String displayName) {
    return 'Continuar como $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Seus rascunhos e clipes estão salvos nesta conta';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Entrar aqui vai esconder esses rascunhos e clipes';

  @override
  String get authTermsPrefix =>
      'Ao escolher uma opção abaixo, você confirma que tem pelo menos 16 anos (ou concluiu a ';

  @override
  String get authTermsAgeAuthorizationCta => 'autorização de idade da Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') e concorda com os ';

  @override
  String get authTermsOfService => 'Termos de Serviço';

  @override
  String get authPrivacyPolicy => 'Política de Privacidade';

  @override
  String get authTermsAnd => ', e ';

  @override
  String get authSafetyStandards => 'Padrões de Segurança';

  @override
  String get authAmberNotInstalled => 'O app Amber não está instalado';

  @override
  String get authAmberConnectionFailed => 'Falha ao conectar com o Amber';

  @override
  String get authPasswordResetSent =>
      'Se existir uma conta com esse e-mail, um link de redefinição de senha foi enviado.';

  @override
  String get authSignInTitle => 'Entrar';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Senha';

  @override
  String get authConfirmPasswordLabel => 'Confirmar senha';

  @override
  String get authEmailRequired => 'O e-mail é obrigatório';

  @override
  String get authEmailInvalid => 'Insira um e-mail válido';

  @override
  String get authPasswordRequired => 'A senha é obrigatória';

  @override
  String get authConfirmPasswordRequired => 'Confirme sua senha';

  @override
  String get authPasswordsDoNotMatch => 'As senhas não coincidem';

  @override
  String get authForgotPassword => 'Esqueceu a senha?';

  @override
  String get authImportNostrKey => 'Importar chave Nostr';

  @override
  String get authConnectSignerApp => 'Conectar com um app signer';

  @override
  String get authSignInWithAmber => 'Entrar com Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Entrar com extensão do navegador';

  @override
  String get authNip07ConnectionFailed =>
      'Não foi possível conectar à sua extensão do navegador.';

  @override
  String get authNip07ExtensionNotFound =>
      'Nenhuma extensão do navegador encontrada. Instale Alby, nos2x ou outra extensão compatível com NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opções de login';

  @override
  String get authInfoEmailPasswordTitle => 'E-mail e senha';

  @override
  String get authInfoEmailPasswordDescription =>
      'Entre com sua conta Divine. Se você se registrou com e-mail e senha, use-os aqui.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Já tem uma identidade Nostr? Importe sua chave privada nsec de outro cliente.';

  @override
  String get authInfoSignerAppTitle => 'App Signer';

  @override
  String get authInfoSignerAppDescription =>
      'Conecte-se usando um signer remoto compatível com NIP-46, como o nsecBunker, para maior segurança da chave.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Use o app signer Amber no Android para gerenciar suas chaves Nostr com segurança.';

  @override
  String get authInfoBrowserExtensionTitle => 'Extensão do Navegador';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Entre com uma extensão do navegador NIP-07 como Alby ou nos2x. Suas chaves ficam na extensão — Divine nunca as vê.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'E-mail ou senha incorretos. Tente de novo.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Verifique seu e-mail antes de entrar — confira o link na sua caixa de entrada.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Isso não parece um endereço de e-mail válido.';

  @override
  String get authSignInErrorNetwork =>
      'Não foi possível conectar ao servidor. Verifique sua conexão e tente de novo.';

  @override
  String get authSignInErrorGeneric => 'Algo deu errado. Tente de novo.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Não sabe como entrou da última vez? ';

  @override
  String get authSignInOptionsHintCta => 'Ver todas as opções de login';

  @override
  String get authCreateAccountTitle => 'Criar conta';

  @override
  String get authBackToInviteCode => 'Voltar para o código de convite';

  @override
  String get authUseDivineNoBackup => 'Usar o Divine sem backup';

  @override
  String get authSkipConfirmTitle => 'Só mais uma coisa...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Você entrou! Vamos criar uma chave segura que alimenta sua conta Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Sem um e-mail, sua chave é a única forma do Divine saber que esta conta é sua.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Você pode acessar sua chave no app, mas, se você não for técnico, recomendamos adicionar um e-mail e senha agora. Isso facilita entrar e recuperar sua conta se você perder ou resetar este dispositivo.';

  @override
  String get authAddEmailPassword => 'Adicionar e-mail e senha';

  @override
  String get authUseThisDeviceOnly => 'Usar apenas este dispositivo';

  @override
  String get authCompleteRegistration => 'Complete seu registro';

  @override
  String get authVerifying => 'Verificando...';

  @override
  String get authVerificationLinkSent =>
      'Enviamos um link de verificação para:';

  @override
  String get authClickVerificationLink =>
      'Clique no link no seu e-mail para\ncompletar o registro.';

  @override
  String get authPleaseWaitVerifying =>
      'Aguarde enquanto verificamos seu e-mail...';

  @override
  String get authWaitingForVerification => 'Aguardando verificação';

  @override
  String get authOpenEmailApp => 'Abrir app de e-mail';

  @override
  String get authVerificationPinPrompt =>
      'Ou digite o código de 6 dígitos do seu e-mail';

  @override
  String get authVerificationPinFieldLabel => 'Código de 6 dígitos';

  @override
  String get authVerificationPinSubmit => 'Verificar código';

  @override
  String get authVerificationResendPrompt => 'Não recebeu?';

  @override
  String get authVerificationResend => 'Reenviar';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Reenviar em $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Não conseguimos reenviar o e-mail. Tente novamente.';

  @override
  String get authVerificationResendExpired =>
      'Esse cadastro expirou. Comece de novo para receber um código novo.';

  @override
  String get authVerificationResendUnavailable =>
      'Não dá para reenviar agora. Use o código de 6 dígitos do e-mail que já enviamos.';

  @override
  String get authVerificationPollingStopped =>
      'Paramos de verificar por você. Digite o código de 6 dígitos do seu e-mail para concluir o login.';

  @override
  String get authWelcomeToDivine => 'Bem-vindo ao Divine!';

  @override
  String get authEmailVerified => 'Seu e-mail foi verificado.';

  @override
  String get authSigningYouIn => 'Entrando';

  @override
  String get authErrorTitle => 'Opa.';

  @override
  String get authVerificationFailed =>
      'Falhamos ao verificar seu e-mail.\nTente novamente.';

  @override
  String get authStartOver => 'Começar de novo';

  @override
  String get authEmailVerifiedLogin =>
      'E-mail verificado! Faça login para continuar.';

  @override
  String get authVerificationLinkExpired =>
      'Este link de verificação não é mais válido.';

  @override
  String get authVerificationConnectionError =>
      'Não foi possível verificar o e-mail. Verifique sua conexão e tente novamente.';

  @override
  String get authWaitlistConfirmTitle => 'Você entrou!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Vamos mandar novidades para $email.\nQuando houver mais códigos de convite, enviaremos pra você.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Tentar novamente';

  @override
  String get authContactSupport => 'Contatar suporte';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Não foi possível abrir $email';
  }

  @override
  String get authAddInviteCode => 'Adicione seu código de convite';

  @override
  String get authInviteCodeLabel => 'Código de convite';

  @override
  String get authEnterYourCode => 'Digite seu código';

  @override
  String get authNext => 'Próximo';

  @override
  String get authJoinWaitlist => 'Entrar na lista de espera';

  @override
  String get authJoinWaitlistTitle => 'Entre na lista de espera';

  @override
  String get authJoinWaitlistDescription =>
      'Compartilhe seu e-mail e enviaremos novidades conforme o acesso for liberado.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Me mandem inspiração da Divine';

  @override
  String get authInviteAccessHelp => 'Ajuda com acesso por convite';

  @override
  String get authGeneratingConnection => 'Gerando conexão...';

  @override
  String get authConnectedAuthenticating => 'Conectado! Autenticando...';

  @override
  String get authConnectionTimedOut => 'Conexão expirou';

  @override
  String get authApproveConnection =>
      'Certifique-se de ter aprovado a conexão no seu app signer.';

  @override
  String get authConnectionCancelled => 'Conexão cancelada';

  @override
  String get authConnectionCancelledMessage => 'A conexão foi cancelada.';

  @override
  String get authConnectionFailed => 'Falha na conexão';

  @override
  String get authUnknownError => 'Ocorreu um erro desconhecido.';

  @override
  String get authNostrConnectStartFailed =>
      'Não foi possível alcançar o app signer. Verifique sua conexão e tente novamente.';

  @override
  String get authNostrConnectInvalidSession =>
      'Este link de conexão não é mais válido. Inicie um novo.';

  @override
  String get authNostrConnectSetupFailed =>
      'Quase lá — não conseguimos concluir seu acesso. Tente novamente.';

  @override
  String get authUrlCopied => 'URL copiada para a área de transferência';

  @override
  String get authConnectToDivine => 'Conectar ao Divine';

  @override
  String get authPasteBunkerUrl => 'Colar URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker inválida. Ela deve começar com bunker://';

  @override
  String get authScanSignerApp => 'Escaneie com seu\napp signer para conectar.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Aguardando conexão... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copiar URL';

  @override
  String get authShare => 'Compartilhar';

  @override
  String get authAddBunker => 'Adicionar bunker';

  @override
  String get authCompatibleSignerApps => 'Apps signer compatíveis';

  @override
  String get authFailedToConnect => 'Falha ao conectar';

  @override
  String get authResetPasswordTitle => 'Redefinir senha';

  @override
  String get authResetPasswordSubtitle =>
      'Digite sua nova senha. Ela deve ter pelo menos 8 caracteres.';

  @override
  String get authNewPasswordLabel => 'Nova senha';

  @override
  String get authConfirmNewPasswordLabel => 'Confirmar nova senha';

  @override
  String get authPasswordTooShort => 'A senha deve ter pelo menos 8 caracteres';

  @override
  String get authPasswordResetSuccess =>
      'Senha redefinida com sucesso. Faça login.';

  @override
  String get authPasswordResetFailed => 'Falha ao redefinir a senha';

  @override
  String get authUnexpectedError =>
      'Ocorreu um erro inesperado. Tente novamente.';

  @override
  String get authUpdatePassword => 'Atualizar senha';

  @override
  String get authSecureAccountTitle => 'Proteger conta';

  @override
  String get authUnableToAccessKeys =>
      'Não foi possível acessar suas chaves. Tente novamente.';

  @override
  String get authRegistrationFailed => 'Falha no registro';

  @override
  String get authRegistrationComplete =>
      'Registro completo. Verifique seu e-mail.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'Falha ao enviar o e-mail de redefinição.';

  @override
  String get authSending => 'Enviando...';

  @override
  String get authSignInButton => 'Entrar';

  @override
  String get authVerificationErrorTimeout =>
      'A verificação expirou. Tente se registrar novamente.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verificação falhou — código de autorização ausente.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verificação falhou. Tente novamente.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Erro de rede durante o login. Tente novamente.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verificação falhou. Tente se registrar novamente.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Falha no login. Tente entrar manualmente.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Este email já está registrado. Entre em vez disso.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Esse código não confere. Confira e tente novamente.';

  @override
  String get authVerificationErrorPinExpired =>
      'Esse código expirou. Toque em Reenviar para receber um novo.';

  @override
  String get authVerificationErrorPinLocked =>
      'Muitas tentativas. Toque em Reenviar para receber um novo código.';

  @override
  String get authVerificationErrorPinFailed =>
      'Não conseguimos verificar esse código. Tente novamente.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'A entrada de código não está disponível no momento. Toque no link do seu e-mail ou reenvie para receber um novo.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Digite um código de convite como ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Esse código de convite não parece válido.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Esse código de convite já foi usado ou revogado.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Os convites deste criador acabaram';

  @override
  String get authInviteGateErrorUnavailable =>
      'Esse código de convite não está disponível. Entre na lista de espera e enviaremos um convite quando abrir uma vaga.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Não conseguimos verificar esse código. Tente de novo.';

  @override
  String get authInviteGateErrorUnknown =>
      'Algo deu errado. Tente seu código de convite de novo.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Esse código de convite não está mais disponível. Volte para o seu código de convite, entre na lista de espera ou contate o suporte.';

  @override
  String get authInviteErrorInvalid =>
      'Esse código de convite não pode ser usado agora. Volte para o seu código de convite, entre na lista de espera ou contate o suporte.';

  @override
  String get authInviteErrorTemporary =>
      'Não conseguimos confirmar seu convite agora. Volte para o seu código de convite e tente novamente ou contate o suporte.';

  @override
  String get authInviteErrorUnknown =>
      'Não conseguimos ativar seu convite. Volte para o seu código de convite, entre na lista de espera ou contate o suporte.';

  @override
  String get shareSheetSave => 'Salvar';

  @override
  String get shareSheetRemoveFromSaved => 'Remover dos salvos';

  @override
  String get shareSheetSaveToGallery => 'Salvar na galeria';

  @override
  String get shareSheetSaveWithWatermark => 'Salvar com marca d\'água';

  @override
  String get shareSheetSaveVideo => 'Salvar vídeo';

  @override
  String get shareSheetAddToClips => 'Adicionar aos clipes';

  @override
  String get shareSheetNameClipTitle => 'Dê um nome a este clipe';

  @override
  String get shareSheetNameClipSubtitle =>
      'Escolha um nome que você vai reconhecer na sua biblioteca.';

  @override
  String get shareSheetClipTitleLabel => 'Título do clipe';

  @override
  String get shareSheetSaveClip => 'Salvar clipe';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\" salvo nos clipes';
  }

  @override
  String get shareSheetUntitledClip => 'Clipe sem título';

  @override
  String get shareSheetAddToClipsFailed =>
      'Não foi possível adicionar aos clipes';

  @override
  String get shareSheetAddToList => 'Adicionar à lista';

  @override
  String get shareSheetCopy => 'Copiar';

  @override
  String get shareSheetShareVia => 'Compartilhar via';

  @override
  String get shareSheetEventJson => 'JSON do evento';

  @override
  String get shareSheetEventId => 'ID do evento';

  @override
  String get shareSheetMoreActions => 'Mais ações';

  @override
  String get shareSheetCrosspost => 'Fazer crosspost';

  @override
  String get crosspostSheetTitle => 'Fazer crosspost deste vídeo';

  @override
  String get crosspostSheetSubtitle =>
      'Mande para suas plataformas conectadas. A publicação pode levar alguns minutos.';

  @override
  String get crosspostSubmit => 'Fazer crosspost';

  @override
  String get crosspostStatusQueued => 'Na fila';

  @override
  String get crosspostStatusUploading => 'Enviando';

  @override
  String get crosspostStatusProcessing => 'Processando';

  @override
  String get crosspostStatusPosted => 'Publicado';

  @override
  String get crosspostStatusFailed => 'Falhou';

  @override
  String get crosspostStatusSkipped => 'Ignorado';

  @override
  String get crosspostStatusNeedsReauth => 'Reconexão necessária';

  @override
  String get crosspostViewPost => 'Ver publicação';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Reconecte o $platform nas configurações de crosspost para continuar publicando.';
  }

  @override
  String get crosspostReconnect => 'Reconectar';

  @override
  String get crosspostErrorNotOwner =>
      'Só é possível fazer crosspost dos seus próprios vídeos.';

  @override
  String get crosspostErrorNotEligible =>
      'Este vídeo não é elegível para crosspost.';

  @override
  String get crosspostErrorNotConnected =>
      'Essa plataforma não está conectada.';

  @override
  String get crosspostErrorUnauthorized =>
      'Reconecte sua conta e tente novamente.';

  @override
  String get crosspostErrorNetwork =>
      'Não foi possível acessar o crossposter. Tente novamente em instantes.';

  @override
  String get crosspostFailedGeneric => 'Falha no crosspost.';

  @override
  String get crosspostStillWorking =>
      'Ainda em andamento. Você pode fechar isso — a publicação continua em segundo plano.';

  @override
  String get crosspostDone => 'Concluído';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Salvo no rolo da câmera';

  @override
  String get watermarkDownloadShare => 'Compartilhar';

  @override
  String get watermarkDownloadDone => 'Concluído';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Acesso a fotos necessário';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Para salvar vídeos, permita o acesso a Fotos nas Configurações.';

  @override
  String get watermarkDownloadOpenSettings => 'Abrir Configurações';

  @override
  String get watermarkDownloadNotNow => 'Agora não';

  @override
  String get watermarkDownloadFailed => 'Download falhou';

  @override
  String get watermarkDownloadDismiss => 'Dispensar';

  @override
  String get watermarkDownloadStageDownloading => 'Baixando vídeo';

  @override
  String get watermarkDownloadStageWatermarking => 'Adicionando marca d\'água';

  @override
  String get watermarkDownloadStageSaving => 'Salvando no rolo da câmera';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Buscando o vídeo na rede...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Aplicando a marca d\'água do Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Salvando o vídeo com marca d\'água no seu rolo da câmera...';

  @override
  String get shareMenuBookmarks => 'Favoritos';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count coleções de seguidos disponíveis';
  }

  @override
  String get peopleListsAddToList => 'Adicionar à lista';

  @override
  String get peopleListsSheetTitle => 'Adicionar à lista';

  @override
  String get peopleListsEmptyTitle => 'Ainda sem listas';

  @override
  String get peopleListsEmptySubtitle =>
      'Cria uma lista para começar a agrupar pessoas.';

  @override
  String get peopleListsCreateList => 'Criar lista';

  @override
  String get peopleListsNewListTitle => 'Nova lista';

  @override
  String get peopleListsRouteTitle => 'Lista de pessoas';

  @override
  String get peopleListsListNameLabel => 'Nome da lista';

  @override
  String get peopleListsListNameHint => 'Amigos próximos';

  @override
  String get peopleListsCreateButton => 'Criar';

  @override
  String get peopleListsAddPeopleTitle => 'Adicionar pessoas';

  @override
  String get peopleListsAddPeopleTooltip => 'Adicionar pessoas';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Adicionar pessoas à lista';

  @override
  String get peopleListsListNotFoundTitle => 'Lista não encontrada';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lista não encontrada. Pode ter sido eliminada.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Esta lista pode ter sido eliminada.';

  @override
  String get peopleListsNoPeopleTitle => 'Nenhuma pessoa nesta lista';

  @override
  String get peopleListsNoPeopleSubtitle => 'Adiciona pessoas para começar';

  @override
  String get peopleListsNoVideosTitle => 'Ainda sem vídeos';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Os vídeos dos membros da lista aparecerão aqui';

  @override
  String get peopleListsNoVideosAvailable => 'Nenhum vídeo disponível';

  @override
  String get peopleListsFailedToLoadVideos => 'Falha ao carregar vídeos';

  @override
  String get peopleListsVideoNotAvailable => 'Vídeo não disponível';

  @override
  String get peopleListsBackToGridTooltip => 'Voltar à grelha';

  @override
  String get peopleListsErrorLoadingVideos => 'Erro ao carregar vídeos';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Nenhuma pessoa disponível para adicionar.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Adicionar a $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Pesquisar pessoas';

  @override
  String get peopleListsAddPeopleError =>
      'Não foi possível carregar as pessoas. Tente novamente.';

  @override
  String get peopleListsAddPeopleRetry => 'Tentar novamente';

  @override
  String get peopleListsAddButton => 'Adicionar';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Adicionar $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Em $count listas',
      one: 'Em $count lista',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'Será removido/a desta lista.';

  @override
  String get peopleListsRemove => 'Remover';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name removido/a da lista';
  }

  @override
  String get peopleListsUndo => 'Desfazer';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Perfil de $name. Pressão longa para remover.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Ver perfil de $name';
  }

  @override
  String get shareMenuEditVideo => 'Editar vídeo';

  @override
  String get shareMenuDeleteVideo => 'Excluir vídeo';

  @override
  String shareMenuVideoCount(int count) {
    return '$count vídeos';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Isso excluirá permanentemente este vídeo do Divine. Ele ainda pode aparecer em clientes Nostr de terceiros que usam outros relays.';

  @override
  String get shareMenuCancel => 'Cancelar';

  @override
  String get shareMenuDelete => 'Excluir';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'A exclusão ainda não está pronta. Tenta de novo daqui a pouco.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Só podes apagar os teus próprios vídeos.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Inicia sessão outra vez e tenta apagar.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Não foi possível assinar o pedido de exclusão. Tenta de novo.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'O relay não aceitou este pedido de exclusão. Tente de novo daqui a pouco.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Não foi possível falar com o relay. Verifique sua conexão e tente de novo.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Apagado. Nem todos os relays confirmaram, por isso ainda pode aparecer noutras apps.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Não foi possível apagar este vídeo. Tenta de novo.';

  @override
  String get shareMenuUpdate => 'Atualizar';

  @override
  String get shareMenuChangeCover => 'Alterar capa';

  @override
  String get shareMenuVideoUpdated => 'Vídeo atualizado com sucesso';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites de colaboradores não foram enviados.',
      one: '$count convite de colaborador não foi enviado.',
    );
    return 'Vídeo atualizado, mas $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Entre novamente e tente de novo.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Este vídeo não tem uma fonte reproduzível, então não pode ser editado.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Não foi possível assinar a atualização. Tente novamente.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'O relay não aceitou a atualização. Tente de novo em instantes.';

  @override
  String get videoUpdateErrorGeneric =>
      'Não foi possível atualizar este vídeo. Tente novamente.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Excluir vídeo?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Removendo vídeo…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Vídeo excluído.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Vídeo excluído. Pode demorar um pouco até desaparecer de todos os lugares.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Vídeo excluído, mas não conseguimos remover todas as cópias. Entre em contato com o suporte.';

  @override
  String get authSessionExpired => 'Sua sessão expirou. Entre novamente.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Falha ao entrar. Tente novamente.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Autenticação web não suportada no modo seguro. Use o app para celular para gerenciamento seguro de chaves.';

  @override
  String get webAuthEnterBunkerUri => 'Digite uma URI bunker';

  @override
  String get webAuthConnectTitle => 'Conectar ao Divine';

  @override
  String get webAuthChooseMethod =>
      'Escolha seu método preferido de autenticação Nostr';

  @override
  String get webAuthBrowserExtension => 'Extensão do navegador';

  @override
  String get webAuthRecommended => 'RECOMENDADO';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Conectar a um signer remoto';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Colar da área de transferência';

  @override
  String get webAuthConnectToBunker => 'Conectar ao bunker';

  @override
  String get webAuthNewToNostr => 'Novo no Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Instale uma extensão de navegador como Alby ou nos2x para a experiência mais fácil, ou use nsec bunker para assinatura remota segura.';

  @override
  String get soundsTitle => 'Sons';

  @override
  String get soundsSearchHint => 'Buscar sons...';

  @override
  String get soundsSearchResults => 'Resultados da busca';

  @override
  String get soundsNoSoundsFound => 'Nenhum som encontrado';

  @override
  String get soundsNoSoundsFoundDescription => 'Tente outro termo de busca';

  @override
  String get soundsSavedToLibrary => 'Salvo em Sons';

  @override
  String get soundsAlreadySavedToLibrary => 'Já está em Sons';

  @override
  String get soundsSavedLibraryTitle => 'Meus sons';

  @override
  String get soundsSavedEmptyTitle => 'Nenhum som salvo ainda';

  @override
  String get soundsSavedEmptyDescription =>
      'Toque em Usar som em um vídeo para salvá-lo aqui.';

  @override
  String get soundsRemoveSavedSound => 'Remover som';

  @override
  String get savedSoundSaveAction => 'Salvar';

  @override
  String get savedSoundPausePreviewAction => 'Pausar prévia';

  @override
  String get savedSoundResumePreviewAction => 'Retomar prévia';

  @override
  String get savedSoundDetailsSheetTitle => 'Detalhes do som';

  @override
  String get savedSoundRemoveConfirmTitle => 'Remover este som?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Ele sai da sua biblioteca, mas você pode salvá-lo de novo em qualquer vídeo que o use.';

  @override
  String get soundsRemovedFromLibrary => 'Removido de Sons';

  @override
  String get soundsSaveFailed =>
      'Não foi possível salvar esse som. Tente de novo.';

  @override
  String get soundsRemoveFailed =>
      'Não foi possível remover esse som. Tente de novo.';

  @override
  String get soundSyncStatusSyncing => 'Sincronizando seus sons…';

  @override
  String get soundSyncStatusSynced => 'Sons atualizados';

  @override
  String get soundSyncStatusFailed =>
      'Não foi possível sincronizar seus sons. Vamos tentar de novo.';

  @override
  String get soundSyncStatusLocked =>
      'Não dá para desbloquear sua biblioteca sincronizada neste dispositivo.';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileMoreOptions => 'Mais opções';

  @override
  String profileBlockedUser(String name) {
    return '$name bloqueado';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name desbloqueado';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Deixou de seguir $name';
  }

  @override
  String get profileFeedError =>
      'Não foi possível conectar ao servidor. Verifique sua conexão e tente de novo.';

  @override
  String get profileFeedLoadMoreError =>
      'Não foi possível carregar mais vídeos. Puxe para atualizar.';

  @override
  String get notificationsTabAll => 'Todas';

  @override
  String get notificationsTabLikes => 'Curtidas';

  @override
  String get notificationsTabComments => 'Comentários';

  @override
  String get notificationsTabFollows => 'Seguidores';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Falha ao carregar notificações';

  @override
  String get notificationsRetry => 'Tentar novamente';

  @override
  String get notificationsRefreshError =>
      'Falha ao atualizar — mostrando o disponível';

  @override
  String get notificationsUnreadPrefix => 'Notificação não lida';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notificações não lidas',
      one: '$count notificação não lida',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Ver o perfil de $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Ver perfis';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Miniatura do vídeo $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Miniatura do vídeo';

  @override
  String get notificationsInviteSingular =>
      'Você tem 1 convite para compartilhar com um amigo!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Você tem $count convites para compartilhar com amigos!';
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
  String get notificationsVideoUnavailable => 'Vídeo indisponível';

  @override
  String get feedFailedToLoadVideos => 'Falha ao carregar vídeos';

  @override
  String get feedRetry => 'Tentar novamente';

  @override
  String get feedNoFollowedUsers =>
      'Nenhum usuário seguido.\nSiga alguém para ver os vídeos dessa pessoa aqui.';

  @override
  String get feedModeForYou => 'Para você';

  @override
  String get feedModeNew => 'Novo';

  @override
  String get feedModeFollowing => 'Seguindo';

  @override
  String get feedModeClassics => 'Clássicos';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Modo do feed: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Autor do vídeo: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar do autor';

  @override
  String get feedForYouEmpty =>
      'Seu feed Para você está vazio.\nExplore vídeos e siga criadores para personalizá-lo.';

  @override
  String get feedFollowingEmpty =>
      'Ainda não há vídeos das pessoas que você segue.\nEncontre criadores de que goste e siga-os.';

  @override
  String get feedLatestEmpty => 'Ainda não há vídeos novos.\nVolte em breve.';

  @override
  String get feedClassicEmpty => 'Ainda não há clássicos.\nVolte em breve.';

  @override
  String get feedExploreVideos => 'Explorar vídeos';

  @override
  String get feedLoadingMore => 'Carregando mais vídeos…';

  @override
  String get feedRefreshed => 'Feed atualizado';

  @override
  String get uploadUploadingVideo => 'Enviando vídeo';

  @override
  String get postPublishConfirmationTitle => 'Publicado no seu perfil';

  @override
  String get postPublishConfirmationView => 'Ver';

  @override
  String get postPublishConfirmationShare => 'Compartilhar';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Miniatura do vídeo que você acabou de publicar';

  @override
  String get userSearchNoResults => 'Nenhum usuário encontrado';

  @override
  String get userPickerFilterByNameHint => 'Filtrar por nome...';

  @override
  String get userPickerSearchByNameHint => 'Pesquisar por nome...';

  @override
  String get userPickerClearSearchSemantics => 'Limpar pesquisa';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name já adicionado';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Selecionar $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Remover $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Sua turma está por aí';

  @override
  String get userPickerEmptyFollowListBody =>
      'Siga pessoas com quem você combina. Quando elas seguirem você de volta, vocês podem colaborar.';

  @override
  String get userPickerGoBack => 'Voltar';

  @override
  String get userPickerTypeNameToSearch => 'Digite um nome para pesquisar';

  @override
  String get userPickerUnavailable =>
      'A busca de usuários está indisponível. Tente novamente mais tarde.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'A busca falhou. Tente novamente.';

  @override
  String get forgotPasswordTitle => 'Redefinir senha';

  @override
  String get forgotPasswordDescription =>
      'Digite seu endereço de e-mail e enviaremos um link para redefinir sua senha.';

  @override
  String get forgotPasswordEmailLabel => 'Endereço de e-mail';

  @override
  String get forgotPasswordCancel => 'Cancelar';

  @override
  String get forgotPasswordSendLink => 'Enviar link por e-mail';

  @override
  String get ageVerificationContentWarning => 'Aviso de conteúdo';

  @override
  String get ageVerificationTitle => 'Verificação de idade';

  @override
  String get ageVerificationAdultDescription =>
      'Este conteúdo foi sinalizado como podendo conter material adulto. Você precisa ter 18 anos ou mais para vê-lo.';

  @override
  String get ageVerificationCreationDescription =>
      'Para usar a câmera e criar conteúdo, você precisa ter pelo menos 16 anos.';

  @override
  String get ageVerificationAdultQuestion => 'Você tem 18 anos ou mais?';

  @override
  String get ageVerificationCreationQuestion => 'Você tem 16 anos ou mais?';

  @override
  String get ageVerificationNo => 'Não';

  @override
  String get ageVerificationYes => 'Sim';

  @override
  String get navHome => 'Início';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navInbox => 'Caixa de entrada';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navMyProfile => 'Meu perfil';

  @override
  String get navNotifications => 'Notificações';

  @override
  String get navOpenCamera => 'Abrir câmera';

  @override
  String get navExploreClassics => 'Clássicos';

  @override
  String get navExploreNewVideos => 'Novos vídeos';

  @override
  String get navExploreTrending => 'Em alta';

  @override
  String get navExploreForYou => 'Para você';

  @override
  String get navExploreLists => 'Listas';

  @override
  String get routeErrorTitle => 'Erro';

  @override
  String get routeInvalidHashtag => 'Hashtag inválida';

  @override
  String get routeInvalidConversationId => 'ID de conversa inválido';

  @override
  String get routeInvalidRequestId => 'ID de solicitação inválido';

  @override
  String get routeInvalidListId => 'ID de lista inválido';

  @override
  String get routeInvalidUserId => 'ID de usuário inválido';

  @override
  String get routeInvalidVideoId => 'ID de vídeo inválido';

  @override
  String get routeInvalidSoundId => 'ID de som inválido';

  @override
  String get routeInvalidCategory => 'Categoria inválida';

  @override
  String get routeNoVideosToDisplay => 'Nenhum vídeo para exibir';

  @override
  String get routeGoHome => 'Ir para o início';

  @override
  String get routeInvalidProfileId => 'ID de perfil inválido';

  @override
  String get routeUnknownPath => 'Essa página não existe no app.';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Central de suporte';

  @override
  String get supportContactSupport => 'Contatar o suporte';

  @override
  String get supportContactSupportSubtitle =>
      'Inicie uma conversa ou veja mensagens anteriores';

  @override
  String get supportReportBug => 'Reportar um bug';

  @override
  String get supportReportBugSubtitle => 'Problemas técnicos com o app';

  @override
  String get supportRequestFeature => 'Pedir uma funcionalidade';

  @override
  String get supportRequestFeatureSubtitle =>
      'Sugira uma melhoria ou nova funcionalidade';

  @override
  String get supportSaveLogs => 'Salvar logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Exportar logs para um arquivo para envio manual';

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
  String get supportFaqSubtitle => 'Perguntas e respostas comuns';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Ajudamos pais e adolescentes a criar hábitos saudáveis online';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'Como lidamos com contas por faixa etária';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Saiba mais sobre verificação e autenticidade';

  @override
  String get supportLoginRequired => 'Entre para contatar o suporte';

  @override
  String get supportExportingLogs => 'Exportando logs...';

  @override
  String get supportExportLogsFailed => 'Falha ao exportar logs';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Logs salvos em $path';
  }

  @override
  String get supportRevealLogsAction => 'Mostrar na pasta';

  @override
  String get supportChatNotAvailable => 'Chat de suporte indisponível';

  @override
  String get supportCouldNotOpenMessages =>
      'Não foi possível abrir as mensagens de suporte';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Não foi possível abrir $pageName';
  }

  @override
  String get reportWhyReporting =>
      'Por que você está denunciando este conteúdo?';

  @override
  String get reportPolicyNotice =>
      'O Divine vai agir sobre denúncias de conteúdo em até 24 horas, removendo o conteúdo e expulsando o usuário que o publicou.';

  @override
  String get reportBlockUser => 'Bloquear este usuário';

  @override
  String get reportCancel => 'Cancelar';

  @override
  String get reportSubmit => 'Denunciar';

  @override
  String get reportSelectReason =>
      'Selecione um motivo para denunciar este conteúdo';

  @override
  String get reportOtherRequiresDetails =>
      'Descreva o problema ao escolher Outro';

  @override
  String get reportDetailsRequired => 'Descreva o problema';

  @override
  String get reportDetailsTextOnly =>
      'Apenas texto — não é possível anexar fotos ou GIFs aqui.';

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
  String get reportReasonSpam => 'Spam ou conteúdo indesejado';

  @override
  String get reportReasonSpamSubtitle => 'Conteúdo indesejado ou repetitivo';

  @override
  String get reportReasonHarassment => 'Assédio, bullying ou ameaças';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Respostas ou menções prejudiciais e indesejadas';

  @override
  String get reportReasonViolence => 'Conteúdo violento ou extremista';

  @override
  String get reportReasonViolenceSubtitle =>
      'Conteúdo violento, extremista ou prejudicial';

  @override
  String get reportReasonSexualContent => 'Conteúdo sexual ou adulto';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nudez, pornografia ou conteúdo explícito';

  @override
  String get reportReasonCopyright => 'Violação de direitos autorais';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Uso não autorizado de propriedade intelectual';

  @override
  String get reportReasonFalseInfo => 'Informações falsas';

  @override
  String get reportReasonFalseInfoSubtitle => 'Alegações enganosas ou falsas';

  @override
  String get reportReasonChildSafety => 'Violação da segurança de menores';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Preocupações gerais com a segurança de menores';

  @override
  String get reportReasonCsam => 'Abuso sexual infantil';

  @override
  String get reportReasonCsamSubtitle =>
      'Conteúdo que retrata abuso sexual de menores';

  @override
  String get reportReasonUnderageUser =>
      'Usuário aparenta ter menos de 16 anos';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'O titular da conta aparenta ser menor de idade';

  @override
  String get reportReasonAiGenerated => 'Conteúdo gerado por IA';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Conteúdo suspeito de ser gerado por IA';

  @override
  String get reportReasonOther => 'Outra violação de política';

  @override
  String get reportReasonOtherSubtitle => 'Violações não listadas acima';

  @override
  String get reportFailed =>
      'Falha ao denunciar conteúdo. Por favor, tente novamente.';

  @override
  String get reportNotSent =>
      'Não foi possível enviar sua denúncia. Verifique sua conexão e tente novamente.';

  @override
  String get reportReceivedTitle => 'Denúncia recebida';

  @override
  String get reportReceivedThankYou =>
      'Obrigado por ajudar a manter o Divine seguro.';

  @override
  String get reportReceivedReviewNotice =>
      'Nossa equipe vai revisar sua denúncia e tomar as medidas adequadas. Você pode receber atualizações por mensagem direta.';

  @override
  String get reportModerationDmDelayed =>
      'Não conseguimos falar com a equipe de moderação diretamente agora, mas sua denúncia foi recebida e será revisada.';

  @override
  String get reportContactModeration =>
      'Mandar mensagem para a equipe de moderação';

  @override
  String get reportLearnMoreAt => 'Saiba mais em';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Fechar';

  @override
  String get listAddToList => 'Adicionar à lista';

  @override
  String listVideoCount(int count) {
    return '$count vídeos';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '$count pessoa',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Por ';

  @override
  String get listNewList => 'Nova lista';

  @override
  String get listDone => 'Concluído';

  @override
  String get listErrorLoading => 'Erro ao carregar listas';

  @override
  String listRemovedFrom(String name) {
    return 'Removido de $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Adicionado a $name';
  }

  @override
  String get listCreateNewList => 'Criar nova lista';

  @override
  String get listNewPeopleList => 'Nova lista de pessoas';

  @override
  String get listCollaboratorsNone => 'Nenhum';

  @override
  String get listAddCollaboratorTitle => 'Adicionar colaborador';

  @override
  String get listCollaboratorSearchHint => 'Pesquisar no Divine...';

  @override
  String get listNameLabel => 'Nome da lista';

  @override
  String get listDescriptionLabel => 'Descrição (opcional)';

  @override
  String get listPublicList => 'Lista pública';

  @override
  String get listPublicListSubtitle =>
      'Outras pessoas podem seguir e ver esta lista';

  @override
  String get listPrivateListSubtitle =>
      'Os vídeos ficam privados. Nome, descrição, tags e capa continuam visíveis.';

  @override
  String get listVisibilityPublic => 'Pública';

  @override
  String get listVisibilityPrivate => 'Privada';

  @override
  String get profileListsEmpty =>
      'Nenhuma lista ainda. Crie uma para os loops que você quer manter juntos.';

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
  String get listShareAction => 'Compartilhar lista';

  @override
  String get listShareFailed =>
      'Não foi possível compartilhar esta lista. Tente de novo.';

  @override
  String get listSave => 'Salvar';

  @override
  String get listContinue => 'Continuar';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Não foi possível atualizar esta lista. Tente de novo.';

  @override
  String get listMakePrivateTitle => 'Tornar esta lista privada?';

  @override
  String get listMakePrivateWarning =>
      'Os vídeos são criptografados, então só você vai ver. Nome, descrição, tags e capa continuam visíveis, e cópias já compartilhadas podem persistir.';

  @override
  String get listMakePublicTitle => 'Tornar esta lista pública?';

  @override
  String get listMakePublicWarning =>
      'Qualquer pessoa com o link pode ver esta lista e os vídeos dela.';

  @override
  String listShareText(String name, String url) {
    return 'Dá uma olhada em $name no Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name no Divine';
  }

  @override
  String get listCancel => 'Cancelar';

  @override
  String get listCreate => 'Criar';

  @override
  String get listCreateFailed => 'Falha ao criar a lista';

  @override
  String get keyManagementTitle => 'Chaves Nostr';

  @override
  String get keyManagementWhatAreKeys => 'O que são chaves Nostr?';

  @override
  String get keyManagementExplanation =>
      'Sua identidade Nostr é um par de chaves criptográficas:\n\n• Sua chave pública (npub) é como seu nome de usuário - compartilhe à vontade\n• Sua chave privada (nsec) é como sua senha - mantenha em segredo!\n\nSua nsec permite acessar sua conta em qualquer app Nostr.';

  @override
  String get keyManagementImportTitle => 'Importar chave existente';

  @override
  String get keyManagementImportSubtitle =>
      'Já tem uma conta Nostr? Cole sua chave privada (nsec) para acessá-la aqui.';

  @override
  String get keyManagementImportButton => 'Importar chave';

  @override
  String get keyManagementImportWarning =>
      'Isso vai substituir sua chave atual!';

  @override
  String get keyManagementBackupTitle => 'Faça backup da sua chave';

  @override
  String get keyManagementBackupSubtitle =>
      'Salve sua chave privada (nsec) para usar sua conta em outros apps Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copiar minha chave privada (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Nunca compartilhe sua nsec com ninguém!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Sua chave fica no serviço de login da Divine, não neste dispositivo. Confirme sua senha e nós a buscamos para você.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Sua chave é guardada pelo serviço de login da Divine. Digite a senha da sua conta e nós a buscamos.';

  @override
  String get keyManagementKeycastCopyKey => 'Copiar chave';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Seu dispositivo bloqueou a cópia, então sua chave não chegou à área de transferência.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Essa senha não confere. Tente novamente.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Tentativas demais. Fecha isto e começa de novo.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Pedidos de chave demais. Espera uns minutos e tenta de novo.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Sua sessão expirou. Entre novamente para copiar sua chave.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Verifique seu endereço de e-mail antes de copiar sua chave.';

  @override
  String get keyManagementKeycastDenied =>
      'A Divine cuida das chaves desta conta, então elas não podem ser copiadas aqui.';

  @override
  String get keyManagementKeycastNoKey =>
      'Não há nenhuma chave registrada para esta conta.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Não foi possível acessar o serviço de login. Tente novamente.';

  @override
  String get keyManagementRestrictedTitle =>
      'Suas chaves são gerenciadas pela Divine';

  @override
  String get keyManagementRestrictedBody =>
      'Para manter sua conta segura, backup da chave e importação de outra chave não estão disponíveis aqui.';

  @override
  String get keyManagementPasteKey => 'Por favor, cole sua chave privada';

  @override
  String get keyManagementInvalidFormat =>
      'Formato de chave inválido. Deve começar com \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importar esta chave?';

  @override
  String get keyManagementConfirmImportBody =>
      'Isso vai substituir sua identidade atual pela importada.\n\nSua chave atual será perdida a menos que você tenha feito backup antes.';

  @override
  String get keyManagementImportConfirm => 'Importar';

  @override
  String get keyManagementImportSuccess => 'Chave importada com sucesso!';

  @override
  String get keyManagementImportFailed =>
      'Falha ao importar chave. Por favor, tente novamente.';

  @override
  String get keyManagementExportSuccess =>
      'Chave privada copiada para a área de transferência!\n\nGuarde em um lugar seguro.';

  @override
  String get keyManagementExportFailed =>
      'Falha ao exportar chave. Por favor, tente novamente.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Sua chave pública (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copiar chave pública';

  @override
  String get keyManagementPublicKeyCopied => 'Chave pública copiada';

  @override
  String get saveOriginalSavedToCameraRoll => 'Salvo no rolo da câmera';

  @override
  String get saveOriginalShare => 'Compartilhar';

  @override
  String get saveOriginalDone => 'Concluído';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Acesso a fotos necessário';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Para salvar vídeos, permita o acesso a Fotos nas Configurações.';

  @override
  String get saveOriginalOpenSettings => 'Abrir Configurações';

  @override
  String get saveOriginalNotNow => 'Agora não';

  @override
  String get saveOriginalDownloadFailed => 'Download falhou';

  @override
  String get saveOriginalDismiss => 'Dispensar';

  @override
  String get saveOriginalDownloadingVideo => 'Baixando vídeo';

  @override
  String get saveOriginalSavingToCameraRoll => 'Salvando no rolo da câmera';

  @override
  String get saveOriginalFetchingVideo => 'Buscando o vídeo na rede...';

  @override
  String get saveOriginalSavingVideo =>
      'Salvando o vídeo original no seu rolo da câmera...';

  @override
  String get soundTitle => 'Som';

  @override
  String get soundOriginalSound => 'Som original';

  @override
  String get soundVideosUsingThisSound => 'Vídeos que usam este som';

  @override
  String get soundSourceVideo => 'Vídeo de origem';

  @override
  String get soundNoVideosYet => 'Sem vídeos ainda';

  @override
  String get soundBeFirstToUse => 'Seja o primeiro a usar este som!';

  @override
  String get soundFailedToLoadVideos => 'Falha ao carregar vídeos';

  @override
  String get soundRetry => 'Tentar novamente';

  @override
  String get soundVideosUnavailable => 'Vídeos indisponíveis';

  @override
  String get soundCouldNotLoadDetails =>
      'Não foi possível carregar os detalhes do vídeo';

  @override
  String get soundPreview => 'Pré-visualizar';

  @override
  String get soundStop => 'Parar';

  @override
  String get soundUseSound => 'Usar som';

  @override
  String get soundUntitled => 'Som sem título';

  @override
  String get soundStopPreview => 'Parar pré-visualização';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Pré-visualizar $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Ver detalhes de $title';
  }

  @override
  String get soundNoVideoCount => 'Sem vídeos ainda';

  @override
  String get soundOneVideo => '1 vídeo';

  @override
  String soundVideoCount(int count) {
    return '$count vídeos';
  }

  @override
  String get soundUnableToPreview =>
      'Não é possível pré-visualizar o som - sem áudio disponível';

  @override
  String get soundPreviewFailed =>
      'Falha ao reproduzir pré-visualização. Tente novamente.';

  @override
  String get soundViewSource => 'Ver origem';

  @override
  String get soundCloseTooltip => 'Fechar';

  @override
  String get exploreNotExploreRoute => 'Não é uma rota de explorar';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Termos de Serviço';

  @override
  String get legalTermsOfServiceSubtitle => 'Termos e condições de uso';

  @override
  String get legalPrivacyPolicy => 'Política de Privacidade';

  @override
  String get legalPrivacyPolicySubtitle => 'Como lidamos com seus dados';

  @override
  String get legalSafetyStandards => 'Padrões de Segurança';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Diretrizes da comunidade e segurança';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Política de direitos autorais e remoção';

  @override
  String get legalOpenSourceLicenses => 'Licenças de código aberto';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Atribuições de pacotes de terceiros';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Não foi possível abrir $pageName';
  }

  @override
  String get categoryAction => 'Ação';

  @override
  String get categoryAdventure => 'Aventura';

  @override
  String get categoryAnimals => 'Animais';

  @override
  String get categoryAnimation => 'Animação';

  @override
  String get categoryArchitecture => 'Arquitetura';

  @override
  String get categoryArt => 'Arte';

  @override
  String get categoryAutomotive => 'Carros';

  @override
  String get categoryAwardShow => 'Premiação';

  @override
  String get categoryAwards => 'Prêmios';

  @override
  String get categoryBaseball => 'Beisebol';

  @override
  String get categoryBasketball => 'Basquete';

  @override
  String get categoryBeauty => 'Beleza';

  @override
  String get categoryBeverage => 'Bebidas';

  @override
  String get categoryCars => 'Carros';

  @override
  String get categoryCelebration => 'Comemoração';

  @override
  String get categoryCelebrities => 'Celebridades';

  @override
  String get categoryCelebrity => 'Celebridade';

  @override
  String get categoryCityscape => 'Paisagem urbana';

  @override
  String get categoryComedy => 'Comédia';

  @override
  String get categoryConcert => 'Show';

  @override
  String get categoryCooking => 'Culinária';

  @override
  String get categoryCostume => 'Fantasia';

  @override
  String get categoryCrafts => 'Artesanato';

  @override
  String get categoryCrime => 'Crime';

  @override
  String get categoryCulture => 'Cultura';

  @override
  String get categoryDance => 'Dança';

  @override
  String get categoryDiy => 'Faça você mesmo';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Educação';

  @override
  String get categoryEmotional => 'Emocionante';

  @override
  String get categoryEmotions => 'Emoções';

  @override
  String get categoryEntertainment => 'Entretenimento';

  @override
  String get categoryEvent => 'Evento';

  @override
  String get categoryFamily => 'Família';

  @override
  String get categoryFans => 'Fãs';

  @override
  String get categoryFantasy => 'Fantasia';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Cinema';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryFootball => 'Futebol americano';

  @override
  String get categoryFurniture => 'Móveis';

  @override
  String get categoryGaming => 'Games';

  @override
  String get categoryGolf => 'Golfe';

  @override
  String get categoryGrooming => 'Cuidados pessoais';

  @override
  String get categoryGuitar => 'Guitarra';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Saúde';

  @override
  String get categoryHockey => 'Hóquei';

  @override
  String get categoryHoliday => 'Feriado';

  @override
  String get categoryHome => 'Casa';

  @override
  String get categoryHomeImprovement => 'Reforma';

  @override
  String get categoryHorror => 'Terror';

  @override
  String get categoryHospital => 'Hospital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Design de interiores';

  @override
  String get categoryInterview => 'Entrevista';

  @override
  String get categoryKids => 'Crianças';

  @override
  String get categoryLifestyle => 'Estilo de vida';

  @override
  String get categoryMagic => 'Mágica';

  @override
  String get categoryMakeup => 'Maquiagem';

  @override
  String get categoryMedical => 'Medicina';

  @override
  String get categoryMusic => 'Música';

  @override
  String get categoryMystery => 'Mistério';

  @override
  String get categoryNature => 'Natureza';

  @override
  String get categoryNews => 'Notícias';

  @override
  String get categoryOutdoor => 'Ar livre';

  @override
  String get categoryParty => 'Festa';

  @override
  String get categoryPeople => 'Pessoas';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Pets';

  @override
  String get categoryPolitics => 'Política';

  @override
  String get categoryPrank => 'Pegadinha';

  @override
  String get categoryPranks => 'Pegadinhas';

  @override
  String get categoryRealityShow => 'Reality show';

  @override
  String get categoryRelationship => 'Relacionamento';

  @override
  String get categoryRelationships => 'Relacionamentos';

  @override
  String get categoryRomance => 'Romance';

  @override
  String get categorySchool => 'Escola';

  @override
  String get categoryScienceFiction => 'Ficção científica';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Compras';

  @override
  String get categorySkateboarding => 'Skate';

  @override
  String get categorySkincare => 'Cuidados com a pele';

  @override
  String get categorySoccer => 'Futebol';

  @override
  String get categorySocialGathering => 'Encontro';

  @override
  String get categorySocialMedia => 'Redes sociais';

  @override
  String get categorySports => 'Esportes';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Tecnologia';

  @override
  String get categoryTelevision => 'Televisão';

  @override
  String get categoryToys => 'Brinquedos';

  @override
  String get categoryTransportation => 'Transporte';

  @override
  String get categoryTravel => 'Viagem';

  @override
  String get categoryUrban => 'Urbano';

  @override
  String get categoryViolence => 'Violência';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Luta livre';

  @override
  String get profileSetupUploadStaged =>
      'Enviada — toque em Salvar para aplicar';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName denunciado(a)';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName bloqueado(a)';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName desbloqueado(a)';
  }

  @override
  String get inboxRemovedConversation => 'Conversa removida';

  @override
  String get inboxRestorePausedTitle =>
      'Algumas conversas não terminaram de restaurar';

  @override
  String get conversationRestorePausedTitle =>
      'Esta conversa ainda não terminou de restaurar';

  @override
  String get inboxRestoreRetryAction => 'Tentar de novo';

  @override
  String get inboxRestoringMessages => 'Restaurando suas mensagens…';

  @override
  String get inboxEmptyTitle => 'Ainda sem mensagens';

  @override
  String get inboxEmptySubtitle => 'O botão + não morde.';

  @override
  String get inboxLoadErrorTitle => 'As mensagens não carregaram';

  @override
  String get inboxLoadErrorSubtitle => 'Verifique sua conexão e tente de novo.';

  @override
  String get inboxFilterAll => 'Todas';

  @override
  String get inboxFilterUnread => 'Não lidas';

  @override
  String get dmBlockedThreadTitle => 'Você bloqueou esta conta';

  @override
  String get dmBlockedThreadBody =>
      'As mensagens ficam aqui para você ler ou capturar a tela. Desbloqueie para responder.';

  @override
  String get inboxFilterBlocked => 'Bloqueados';

  @override
  String get inboxBlockedEmptyTitle => 'Nenhuma conversa bloqueada';

  @override
  String get inboxBlockedEmptySubtitle =>
      'As contas que você bloquear aparecem aqui.';

  @override
  String get inboxBlockedNoMessages => 'Sem mensagens';

  @override
  String get inboxUnreadEmptyTitle => 'Você está em dia';

  @override
  String get inboxUnreadEmptySubtitle => 'Sem mensagens não lidas no momento.';

  @override
  String get inboxSearchHint => 'Pesquisar mensagens';

  @override
  String get inboxSupportRowTitle => 'Moderação da Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Bugs, moderação, questões de conta — estamos ouvindo.';

  @override
  String get inboxSearchEmptyTitle => 'Sem resultados';

  @override
  String get inboxSearchEmptySubtitle => 'Tente outro nome ou outra palavra.';

  @override
  String get inboxActionMute => 'Silenciar conversa';

  @override
  String inboxActionReport(String displayName) {
    return 'Denunciar $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Bloquear $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Desbloquear $displayName';
  }

  @override
  String get inboxActionRemove => 'Remover conversa';

  @override
  String get inboxRemoveConfirmTitle => 'Remover conversa?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Isso remove sua conversa com $displayName da sua caixa de entrada. Se essa pessoa te enviar mensagem de novo, uma nova conversa começa.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Isso remove a conversa em grupo da sua caixa de entrada. Se alguém enviar mensagem no grupo de novo, uma nova conversa começa.';

  @override
  String get inboxRemoveConfirmConfirm => 'Remover';

  @override
  String get inboxConversationMuted => 'Conversa silenciada';

  @override
  String get inboxConversationUnmuted => 'Conversa com som ativado';

  @override
  String get inboxCollabInviteCardTitle => 'Convite para colaborar';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Vídeo sem título';

  @override
  String get clickableTextViewVideoLink => 'Ver vídeo';

  @override
  String get messageExternalLinkDialogTitle => 'Abrir link externo?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Este link leva a um site externo e pode não ser seguro:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Abrir';

  @override
  String get inboxCollabInviteCoPostButton => 'Co-publicar';

  @override
  String get inboxCollabInviteNotMineButton => 'Não é meu';

  @override
  String get inboxCollabInvitePreviewTitle => 'Convite para co-publicar';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Convite para co-publicar de $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Co-publicar adiciona este vídeo à sua linha do tempo como uma colaboração.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Aceito';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorado';

  @override
  String get inboxCollabInviteAcceptError =>
      'Não foi possível aceitar. Tente novamente.';

  @override
  String get inboxCollabInviteSentStatus => 'Convite enviado';

  @override
  String get inboxConversationCollabInvitePreview => 'Convite para colaborar';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Você foi convidado(a) para colaborar em $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Você foi convidado(a) para colaborar em um vídeo: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites de colaborador não foram enviados.',
      one: '$count convite de colaborador não foi enviado.',
    );
    return 'Vídeo publicado, mas $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Não conseguimos identificar com quem é esta conversa. Abra-a de novo pela caixa de entrada.';

  @override
  String get dmSendBlockedMessage =>
      'Você só pode mandar mensagem para contas oficiais da Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Ninguém está lendo esta conversa. Envie uma mensagem para a Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Não foi possível excluir para todos.';

  @override
  String get dmDeleteRefusedDetails =>
      'Algumas pessoas talvez ainda consigam ver esta mensagem.';

  @override
  String get dmRetiredThreadClosedTitle => 'Esta conversa está encerrada.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Este aviso da Divine Moderation não pode ser removido.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Movemos a Divine Moderation para uma nova conta. Ninguém lê mais esta.';

  @override
  String get dmRetiredThreadOpenSupport =>
      'Enviar mensagem para a Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Falha ao enviar a mensagem';

  @override
  String get dmResendFailedMessage => 'Ainda não foi possível enviar';

  @override
  String get dmSendFailedSubtitle => 'Reenvie agora, ou pare de tentar.';

  @override
  String get dmSendFailedRetry => 'Tentar novamente';

  @override
  String get dmSendPartialMessage =>
      'Enviado, mas não sincronizou com seus outros dispositivos';

  @override
  String get dmConversationLoadError =>
      'Não foi possível carregar as mensagens';

  @override
  String get dmMessageInputHint => 'Diga alguma coisa…';

  @override
  String get dmMessageBubbleSentHint => 'Mensagem enviada';

  @override
  String get dmMessageBubbleReceivedHint => 'Mensagem recebida';

  @override
  String get dmMessageBubbleLongPressHint => 'Ações da mensagem';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Reenviar ou excluir esta mensagem';

  @override
  String get dmMessageActionCopyText => 'Copiar texto';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copiar URL do vídeo';

  @override
  String get dmMessageActionDeleteForEveryone => 'Excluir para todos';

  @override
  String get dmMessageActionReport => 'Denunciar';

  @override
  String get dmMessageActionRetrySend => 'Reenviar';

  @override
  String get dmMessageActionCancelSend => 'Parar de tentar';

  @override
  String get dmReactionAddCustomA11yLabel =>
      'Adicionar reação com emoji personalizado';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Mensagem para $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Responder a si mesmo…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Responder a este reel';

  @override
  String get dmReelReplyViewChat => 'Ver conversa';

  @override
  String get dmReelReplySentAnnouncement => 'Resposta enviada';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Você reagiu $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Não foi possível enviar';

  @override
  String get dmReelReplyUnverified => 'Não foi possível confirmar o envio';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Sua reação: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name reagiu com $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Enviando reação: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'A reação falhou, toque duas vezes para tentar de novo';

  @override
  String get dmReactionChipRetryAnnouncement => 'Tentando a reação de novo';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Conclua a remoção da reação anterior antes de adicionar outra.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reações';

  @override
  String get dmReactionsViewA11yLabel => 'Ver quem reagiu';

  @override
  String get dmReactionRemoveAction => 'Remover';

  @override
  String get dmReactionRetryAction => 'Tentar novamente';

  @override
  String get dmFormatBold => 'Negrito';

  @override
  String get dmFormatItalic => 'Itálico';

  @override
  String get dmFormatStrikethrough => 'Tachado';

  @override
  String get dmFormatCode => 'Código';

  @override
  String get dmStatusFailed => 'Falha ao enviar';

  @override
  String get inboxConversationActionsSheetLabel => 'Ações da conversa';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Conversa com $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Não lida, conversa com $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '$count pessoa',
    );
    return '$name e mais $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Mostrar ações da conversa';

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
    return 'Vídeo $current/$total';
  }

  @override
  String get exploreSearchHint => 'Buscar...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count vídeos';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Falha ao atualizar assinatura. Por favor, tente novamente.';

  @override
  String get discoverListsTitle => 'Descobrir listas';

  @override
  String get discoverListsFailedToLoad => 'Falha ao carregar listas';

  @override
  String get discoverListsLoading => 'Descobrindo listas públicas...';

  @override
  String get discoverListsRelayTimeout =>
      'O relay não devolveu listas a tempo. Tente de novo.';

  @override
  String get discoverListsServiceUnavailable => 'Serviço indisponível.';

  @override
  String get discoverListsEmptyTitle => 'Nenhuma lista pública encontrada';

  @override
  String get discoverListsEmptySubtitle =>
      'Volte mais tarde para ver novas listas';

  @override
  String get discoverListsByAuthorPrefix => 'por';

  @override
  String get curatedListEmptyTitle => 'Sem vídeos nesta lista';

  @override
  String get curatedListEmptySubtitle => 'Adicione alguns vídeos pra começar';

  @override
  String get curatedListLoadingVideos => 'Carregando vídeos...';

  @override
  String get curatedListFailedToLoad => 'Falha ao carregar lista';

  @override
  String get curatedListVideoNotAvailable => 'Vídeo indisponível';

  @override
  String get curatedListActionsTooltip => 'Ações da lista';

  @override
  String get curatedListDeleteConfirmTitle => 'Excluir lista?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Isso remove a lista dos relays. Os vídeos na lista não serão excluídos.';

  @override
  String get curatedListDeletedSnack => 'Lista excluída';

  @override
  String get curatedListDeleteFailed => 'Não foi possível excluir a lista';

  @override
  String get peopleListsActionsTooltip => 'Ações da lista';

  @override
  String get listDeleteAction => 'Excluir lista';

  @override
  String get peopleListsDeleteConfirmTitle => 'Excluir lista?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Isso remove a lista para todos. As pessoas nela não deixarão de ser seguidas.';

  @override
  String get peopleListsDeleteFailed => 'Não foi possível excluir a lista';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonSomethingWentWrong => 'Algo deu errado';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonNotNow => 'Agora não';

  @override
  String get commonLoading => 'Carregando';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Não foi possível atualizar a capa. Tente novamente.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Capa atualizada';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Publicar sem a verificação de autenticidade?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Não foi possível adicionar as credenciais de conteúdo, por isso este vídeo não será confirmado como feito por humano. Gere novamente para tentar outra vez ou publique como está.';

  @override
  String get videoMetadataC2paMissingNote =>
      'As credenciais de conteúdo precisam de conexão com a internet.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'O serviço de credenciais de conteúdo não respondeu. Não é problema da sua conexão.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Gerar novamente';

  @override
  String get videoMetadataC2paMissingSkip => 'Ignorar';

  @override
  String get videoMetadataGenerationFailed => 'Falha na geração';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Validade';

  @override
  String get videoMetadataExpirationNotExpire => 'Não expira';

  @override
  String get videoMetadataExpirationOneDay => '1 dia';

  @override
  String get videoMetadataExpirationOneWeek => '1 semana';

  @override
  String get videoMetadataExpirationOneMonth => '1 mês';

  @override
  String get videoMetadataExpirationOneYear => '1 ano';

  @override
  String get videoMetadataExpirationOneDecade => '1 década';

  @override
  String get videoMetadataContentWarnings => 'Avisos de conteúdo';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Em alta';

  @override
  String get libraryDeleteConfirm => 'Excluir';

  @override
  String get libraryWebUnavailableHeadline => 'A biblioteca fica no app móvel';

  @override
  String get libraryWebUnavailableDescription =>
      'Rascunhos e clipes ficam no seu dispositivo — abra o Divine no celular para gerenciá-los.';

  @override
  String get libraryTabDrafts => 'Rascunhos';

  @override
  String get libraryTabClips => 'Clipes';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Excluir clipes selecionados';

  @override
  String get libraryCloseSemanticLabel => 'Fechar biblioteca';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'Parar de selecionar clipes';

  @override
  String get librarySelectClipsSemanticLabel => 'Selecionar clipes';

  @override
  String get libraryGridSizeLabel => 'Tamanho da grade';

  @override
  String get libraryDisplayOptionsLabel => 'Ordenação e tamanho da grade';

  @override
  String get libraryMoreActionsSemanticLabel => 'Mais ações da biblioteca';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colunas',
      one: '$count coluna',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Selecionar';

  @override
  String get librarySortNewestCreation => 'Criação mais recente';

  @override
  String get librarySortOldestCreation => 'Criação mais antiga';

  @override
  String get librarySortLongestClip => 'Clipe mais longo';

  @override
  String get librarySortShortestClip => 'Clipe mais curto';

  @override
  String get librarySortSquareFirst => 'Quadrados primeiro';

  @override
  String get librarySortVerticalFirst => 'Verticais primeiro';

  @override
  String get libraryDeleteClipsWarning =>
      'Não dá para desfazer. Os arquivos de vídeo serão removidos permanentemente do dispositivo.';

  @override
  String get libraryPreparingVideo => 'Preparando vídeo...';

  @override
  String libraryCreateVideo(int count) {
    return 'Criar vídeo ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes',
      one: '$count clipe',
    );
    return '$_temp0 salvos em $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount salvos, $failureCount falharam';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Não foi possível salvar em $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permissão negada para $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes excluídos',
      one: '$count clipe excluído',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Desfazer';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Será excluído automaticamente em $daysLeft dias',
      one: 'Será excluído automaticamente amanhã',
      zero: 'Será excluído automaticamente hoje',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Não foi possível carregar os rascunhos';

  @override
  String get libraryCouldNotLoadClips => 'Não foi possível carregar os clipes';

  @override
  String get libraryOpenErrorDescription =>
      'Algo deu errado ao abrir a biblioteca. Tente de novo.';

  @override
  String get libraryNoDraftsYetTitle => 'Ainda não há rascunhos';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Vídeos salvos como rascunho aparecerão aqui';

  @override
  String get libraryNoClipsYetTitle => 'Ainda não há clipes';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Seus clipes gravados aparecerão aqui';

  @override
  String get libraryDraftDeletedSnackbar => 'Rascunho excluído';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Falha ao excluir rascunho';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Rascunho duplicado';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Falha ao duplicar rascunho';

  @override
  String get libraryDraftInProgressBadge => 'Em andamento';

  @override
  String get libraryDraftActionPost => 'Publicar';

  @override
  String get libraryDraftActionEdit => 'Editar';

  @override
  String get libraryDraftActionDuplicate => 'Duplicar';

  @override
  String get libraryDraftActionDelete => 'Excluir rascunho';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (cópia $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Excluir rascunho';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Excluir \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Excluir clipe';

  @override
  String get libraryDeleteClipMessage => 'Excluir este clipe?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds s';
  }

  @override
  String get libraryRecordVideo => 'Gravar um vídeo';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Clipe de vídeo, $duration segundos';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Arquivado. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Clipe em stop motion, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Selecionado, número $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Selecionado';

  @override
  String get videoClipSemanticValueNotSelected => 'Não selecionado';

  @override
  String get videoClipSemanticHintDisabled => 'Desabilitado';

  @override
  String get videoClipSemanticHintSelect =>
      'Toque para selecionar, pressione por mais tempo para visualizar';

  @override
  String get videoClipSemanticHintDeselect =>
      'Toque para desmarcar, pressione por mais tempo para visualizar';

  @override
  String get routerInvalidCreator => 'Criador inválido';

  @override
  String get routerInvalidHashtagRoute => 'Rota de hashtag inválida';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Não foi possível carregar os vídeos';

  @override
  String get categoryGalleryNoVideosInCategory => 'Sem vídeos nesta categoria';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Opções de ordenação da categoria';

  @override
  String get categoryGallerySortHot => 'Em alta';

  @override
  String get categoryGallerySortNew => 'Novos';

  @override
  String get categoryGallerySortClassic => 'Clássicos';

  @override
  String get categoryGallerySortForYou => 'Pra você';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Não foi possível carregar as categorias';

  @override
  String get categoriesNoCategoriesAvailable => 'Nenhuma categoria disponível';

  @override
  String get notificationsEmptyTitle => 'Sem atividade ainda';

  @override
  String get notificationsEmptySubtitle =>
      'Quando alguém interagir com seu conteúdo, você vê aqui';

  @override
  String get appsPermissionsTitle => 'Permissões de integração';

  @override
  String get appsPermissionsRevoke => 'Revogar';

  @override
  String get appsPermissionsEmptyTitle =>
      'Nenhuma permissão de integração salva';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Integrações aprovadas aparecem aqui depois que você lembra uma aprovação de acesso.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName quer sua aprovação';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Este app está pedindo acesso pelo sandbox aprovado do Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Origem';

  @override
  String get nostrAppPermissionMethod => 'Método';

  @override
  String get nostrAppPermissionCapability => 'Capacidade';

  @override
  String get nostrAppPermissionEventKind => 'Tipo de evento';

  @override
  String get nostrAppPermissionAllow => 'Permitir';

  @override
  String get appsDetailDefaultTitle => 'App integrado';

  @override
  String get appsDetailNotFoundTitle => 'Integração não encontrada';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Esta integração aprovada não está mais disponível no Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Como funciona';

  @override
  String get appsDetailHowItWorksBody =>
      'Este é um app de terceiros aprovado que roda dentro do Divine. O Divine só concede recursos revisados para esta integração e bloqueia a navegação para fora das origens aprovadas.';

  @override
  String get appsDetailAboutTitle => 'Sobre';

  @override
  String get appsDetailPrimaryOriginTitle => 'Origem principal';

  @override
  String get appsDetailApprovedOriginsTitle => 'Origens aprovadas';

  @override
  String get appsDetailCapabilitiesTitle => 'Recursos disponíveis';

  @override
  String get appsDetailAskBeforeTitle => 'Perguntar antes';

  @override
  String get appsDetailOpenButton => 'Abrir integração';

  @override
  String get appsDetailNoneDeclared => 'Nada declarado ainda';

  @override
  String get appsDirectoryTitle => 'Apps integrados';

  @override
  String get appsDirectoryIntroTitle => 'Apps de terceiros aprovados';

  @override
  String get appsDirectoryIntroBody =>
      'Apps de terceiros aprovados que rodam dentro do Divine';

  @override
  String get appsDirectoryErrorTitle =>
      'Não foi possível carregar os apps integrados';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Puxe para tentar as integrações aprovadas de novo.';

  @override
  String get appsDirectoryEmptyTitle => 'Nenhuma integração aprovada ainda';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Apps de terceiros aprovados vão aparecer aqui conforme o Divine adicioná-los.';

  @override
  String get appsDirectoryRefresh => 'Atualizar';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Os apps integrados rodam no Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'As integrações aprovadas só estão disponíveis no celular por enquanto.';

  @override
  String get appsSandboxUnavailableTitle => 'Integração indisponível';

  @override
  String get appsSandboxUnavailableBody =>
      'Abra as integrações aprovadas pela aba Apps integrados para que o Divine possa aplicar a política de acesso correta.';

  @override
  String get appsSandboxLoadingTitle => 'Carregando integração';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Verificando a integração aprovada antes de abrir.';

  @override
  String get appsSandboxBlockedTitle => 'Bloqueado por segurança';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Esta integração tentou sair da origem aprovada.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink =>
      'Link do post copiado para a área de transferência';

  @override
  String get shareCopiedEventJson =>
      'JSON do evento Nostr copiado para a área de transferência';

  @override
  String get shareCopiedEventId =>
      'ID do evento Nostr copiado para a área de transferência';

  @override
  String get authHeroTaglineAuthentic => 'Momentos autênticos.';

  @override
  String get authHeroTaglineHuman => 'Criatividade humana.';

  @override
  String get keyImportFailedToImport =>
      'Falha ao importar a chave ou conectar o bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'URL de bunker inválida';

  @override
  String get keyImportInvalidFormat =>
      'Formato inválido. Use nsec..., hex, ncryptsec1... ou bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Formato de nsec inválido. Deve ter 63 caracteres';

  @override
  String get keyImportKeyFieldLabel => 'Chave privada ou URL de bunker';

  @override
  String get keyImportKeyRequired =>
      'Digite sua chave privada ou URL de bunker';

  @override
  String get keyImportPasswordRequired =>
      'Digite a senha desta chave criptografada';

  @override
  String get keyImportSecurityWarningBody =>
      'Nunca compartilhe sua chave privada com ninguém. Esta chave dá acesso total à sua identidade Nostr.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Mantenha sua chave privada em segurança!';

  @override
  String get keyImportSubtitle =>
      'Importe sua identidade Nostr existente usando sua chave privada ou uma URL de bunker.';

  @override
  String get keyImportTitle => 'Importe sua\nidentidade Nostr';

  @override
  String get commentAuthorYouIndicator => 'Você';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Ver o perfil de $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Excluir comentário';

  @override
  String get commentOptionsEditSemanticLabel => 'Editar comentário';

  @override
  String get commentOptionsFlagContentLabel => 'Sinalizar conteúdo';

  @override
  String get commentOptionsFlagContentSemanticLabel =>
      'Sinalizar este conteúdo';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Selecione um motivo para sinalizar este comentário';

  @override
  String get commentOptionsFlagSubmit => 'Enviar';

  @override
  String get commentOptionsTitle => 'Opções';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Ainda estamos importando os comentários antigos do arquivo. Eles não estão prontos ainda.';

  @override
  String get commentsEmptyClassicVineTitle => 'Vine clássico';

  @override
  String get commentsInputEditingLabel => 'Editando';

  @override
  String get commentsInputSemanticHint => 'Adicionar um comentário';

  @override
  String get commentsInputSemanticHintEdit => 'Editar comentário';

  @override
  String get commentsInputSemanticHintReply => 'Adicionar uma resposta';

  @override
  String get commentsInputSemanticLabel => 'Campo de comentário';

  @override
  String get commentsInputSemanticLabelEdit => 'Campo de edição';

  @override
  String get commentsInputSemanticLabelReply => 'Campo de resposta';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Ver o perfil de $displayName';
  }

  @override
  String get classicsEmptyDescription =>
      'O arquivo Clássicos está sendo carregado';

  @override
  String get classicsEmptyTitle => 'Nenhum clássico encontrado';

  @override
  String get classicsErrorTitle => 'Falha ao carregar os Clássicos';

  @override
  String get classicsUnavailableDescription =>
      'Os Clássicos só estão disponíveis quando conectado aos relays Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Mude para um relay com Funnelcake nas Configurações para acessar o arquivo Clássicos.';

  @override
  String get classicsUnavailableTitle => 'Clássicos indisponíveis';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Seja o primeiro a postar um vídeo com esta hashtag!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Nenhum vídeo encontrado para #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Isso pode levar alguns instantes';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Carregando vídeos sobre #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Adicione hashtags... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Volte mais tarde para ver conteúdo novo';

  @override
  String get newVideosTabEmptyTitle => 'Nenhum vídeo em Novos vídeos';

  @override
  String get popularVideosContextTitle => 'Vídeos populares';

  @override
  String get popularVideosEmptySubtitle =>
      'Volte mais tarde para ver conteúdo novo';

  @override
  String get popularVideosEmptyTitle => 'Nenhum vídeo em Vídeos populares';

  @override
  String get popularVideosErrorTitle => 'Falha ao carregar os vídeos em alta';

  @override
  String get popularVideosFeedSourceLabel => 'Fonte do feed popular';

  @override
  String get trendingHashtagsLoading => 'Carregando hashtags...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Ver vídeos marcados com $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Autor do vídeo: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Descrição do vídeo: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'A visão do Divine é dar a você uma verdadeira escolha algorítmica. Em vez de ficar preso a um único algoritmo de caixa-preta, você poderá escolher entre várias abordagens de recomendação:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Linha do tempo cronológica dos criadores que você segue';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Isso coloca você no controle da sua atenção, em vez de deixá-la nas mãos da plataforma. Você deve saber como seu feed é organizado e ter o poder de mudá-lo quando quiser.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Feeds personalizados criados pela comunidade para temas como música, comédia ou arte';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Feed \"Para você\" personalizado';

  @override
  String get forYouAlgorithmChoiceTitle => 'Seu algoritmo, sua escolha';

  @override
  String get forYouAlgorithmChoiceTrending => 'Conteúdo em alta e popular';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Sinal forte — você se engajou o suficiente para responder';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'O Divine presta atenção em como você interage com o conteúdo para entender o que você curte. Toda vez que você assiste a um vídeo, reage a ele, deixa um comentário ou o reposta, o sistema anota.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Como funciona';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Ações diferentes sinalizam níveis diferentes de interesse:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Se você ainda não construiu um histórico de visualização, mostramos uma mistura do que está popular e em alta no momento junto com envios recentes. Isso te dá um ótimo ponto de partida para explorar.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Conforme você assiste, curte e se engaja com o conteúdo, as recomendações vão ficando cada vez mais personalizadas. Com o tempo, seu feed Para você revela vídeos de criadores que você talvez nunca tivesse descoberto por conta própria.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Novo no Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Estamos construindo um sistema aberto em que desenvolvedores podem implementar os próprios algoritmos, e você pode escolher quais usar — ou não usar nenhum.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Código aberto e transparente';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Sinal médio — um jeito rápido de demonstrar apreço';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reações';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Sinal mais forte — compartilhar com seus seguidores é um endosso poderoso';

  @override
  String get forYouAlgorithmSubtitle =>
      'Movido pelo Gorse, um motor de recomendação de código aberto';

  @override
  String get forYouAlgorithmTitle => 'O algoritmo do Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Sinal leve — indica interesse básico';

  @override
  String get forYouEmptyDescription =>
      'Assista e curta alguns vídeos para receber recomendações personalizadas.';

  @override
  String get forYouEmptyTitle => 'Nenhuma recomendação ainda';

  @override
  String get forYouErrorTitle => 'Falha ao carregar as recomendações';

  @override
  String get forYouUnavailableDescription =>
      'As recomendações personalizadas exigem conexão com o Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Para você indisponível';

  @override
  String get inboxConversationOptionsLabel => 'Opções';

  @override
  String get inboxConversationViewProfileButton => 'Ver perfil';

  @override
  String get inboxMessageRequestsEmpty => 'Nenhuma solicitação de mensagem';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Solicitações de mensagem, $requestCount pendentes';
  }

  @override
  String get inboxMessageRequestsTitle => 'Solicitações de mensagem';

  @override
  String get inboxMessagesTab => 'Mensagens';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Solicitação de mensagem de $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Enviou uma solicitação de mensagem';

  @override
  String get inboxRequestsMarkAllRead =>
      'Marcar todas as solicitações como lidas';

  @override
  String get inboxRequestsRemoveAll => 'Remover todas as solicitações';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Recusar e remover';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Solicitação de $displayName recusada';
  }

  @override
  String get messageRequestLoadFailed =>
      'Não foi possível carregar esta solicitação.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count seguidores';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count vídeos';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens',
      one: '$count mensagem',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Ver mensagens';

  @override
  String get messageRequestViewProfileButton => 'Ver perfil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName quer te enviar mensagem, e enviou $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Você trocou de conta, então nada foi excluído. Abra a exclusão de novo para a conta que você quer remover.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Para confirmar, digite:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Para confirmar, digite seu nome de usuário:';

  @override
  String get deleteAccountConfirmationHint => 'Digite DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'Digite seu nome de usuário';

  @override
  String get deleteAccountDeleteAllContentButton => 'Excluir todo o conteúdo';

  @override
  String get accountDeletionRecoveryTitle => 'Excluindo sua conta';

  @override
  String get accountDeletionRecoveryBody =>
      'Não conseguimos concluir a exclusão da sua conta. Seu nome de usuário está reservado para você e ainda pode ser recuperado.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Recuperar meu nome de usuário';

  @override
  String get accountDeletionFinishingBody =>
      'Seu pedido de exclusão ainda está sendo processado. Você pode usar outra conta enquanto concluímos.';

  @override
  String get accountDeletionOtherAccountPending =>
      'A exclusão de outra conta ainda está sendo processada neste dispositivo. Aguarde a conclusão antes de excluir esta conta.';

  @override
  String get accountDeletionCancellingBody =>
      'Estamos cancelando sua exclusão. Confira de novo antes de sair desta tela.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Ainda não conseguimos recuperar seu nome de usuário. Verifique sua conexão e tente de novo.';

  @override
  String get accountDeletionUsernameRestored =>
      'Seu nome de usuário foi recuperado. Sua conta não foi excluída.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Não conseguimos verificar o status da sua exclusão. Verifique sua conexão e tente de novo.';

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
      'A exclusão de conta não está disponível no momento. Nada foi excluído.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Não conseguimos concluir a exclusão da sua conta. Tente novamente.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Confirmação final';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Solicitações de exclusão enviadas, mas suas chaves podem não ter sido totalmente removidas deste dispositivo. Vá em Configurações → Chaves Nostr → Remover chaves para tentar de novo.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Solicitações de exclusão enviadas e você foi desconectado, mas alguns dados locais não puderam ser removidos deste dispositivo.';

  @override
  String get deleteAccountPreparingDeletion => 'Preparando a exclusão...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total eventos';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Isso remove o login local desta conta deste dispositivo. Não vai excluir sua conta Divine nem sua identidade Nostr.\n\nSeus rascunhos e clipes continuam salvos neste dispositivo para esta conta. Se esta for sua última conta local, você voltará para a tela de login.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Remover do dispositivo';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Remover esta conta deste dispositivo?';

  @override
  String get deleteAccountReauthRequired =>
      'Entre novamente para excluir sua conta. Nada foi excluído ainda.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'As solicitações de exclusão das suas publicações foram enviadas, mas não conseguimos concluir a exclusão da sua conta. Tente de novo daqui a pouco.';

  @override
  String get deleteAccountSuccess =>
      'Sua conta Divine foi excluída. Foram enviadas solicitações de exclusão para suas publicações no Nostr, mas alguns relays, clientes ou caches podem manter cópias.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Exclusão da conta solicitada. Não foi possível confirmar individualmente a exclusão de algumas publicações existentes.';

  @override
  String get deleteAccountWarningBody =>
      'Isso envia solicitações de exclusão da sua conta e do seu conteúdo, exclui sua conta Divine quando possível e desconecta você neste dispositivo. Alguns relays, clientes e índices de busca podem manter cópias. Outros dispositivos conectados continuam ativos até você remover as chaves lá.';

  @override
  String get findPeopleNoContacts =>
      'Nenhum contato encontrado.\nComece a seguir pessoas para vê-las aqui.';

  @override
  String get geoBlockedCityLabel => 'Cidade';

  @override
  String get geoBlockedCountryLabel => 'País';

  @override
  String get geoBlockedDefaultReason =>
      'Este serviço não está disponível na sua região por causa de regulamentações locais.';

  @override
  String get geoBlockedLegalNotice =>
      'Respeitamos as leis e regulamentações locais. Esta restrição é baseada na localização do seu endereço IP.';

  @override
  String get geoBlockedRegionLabel => 'Região';

  @override
  String get geoBlockedTitle => 'Serviço indisponível';

  @override
  String get likedVideosEmpty => 'Nenhum vídeo curtido';

  @override
  String get likedVideosInvalidRoute => 'Rota inválida';

  @override
  String get likedVideosTitle => 'Vídeos curtidos';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Tentando enviar de novo…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Salvar nos rascunhos';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Salvo nos rascunhos';

  @override
  String get uploadFailureSheetTitle => 'Falha no envio';

  @override
  String get uploadFailureSheetTryAgainButton => 'Tentar novamente';

  @override
  String get videoEditorAudioImportAudio => 'Importar áudio';

  @override
  String get videoEditorAudioImportFailed => 'Falha ao importar o áudio.';

  @override
  String get videoIconPlaceholderLabel => 'Vídeo';

  @override
  String get publishErrorNotSignedIn =>
      'Entre na sua conta para publicar vídeos.';

  @override
  String get publishErrorNoRetry => 'Nenhum envio para tentar novamente.';

  @override
  String get publishErrorNoInternet =>
      'Sem conexão com a internet. Verifique seu Wi-Fi ou dados móveis e tente novamente.';

  @override
  String get publishErrorServerUnreachable =>
      'Não foi possível acessar o servidor. Tente novamente em instantes.';

  @override
  String get publishErrorTimeout =>
      'O tempo de envio esgotou. Tente uma conexão melhor ou um vídeo menor.';

  @override
  String get publishErrorTls =>
      'Falha na conexão segura. Verifique sua rede — Wi-Fi público pode bloquear envios.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'O servidor de mídia ($serverName) não está disponível. Você pode escolher outro nas configurações.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'O arquivo de vídeo é grande demais para o servidor. Tente cortá-lo ou reduzir a qualidade.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'O servidor de mídia ($serverName) teve um erro interno. Você pode escolher outro nas configurações.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'O servidor de mídia ($serverName) está temporariamente fora do ar. Tente novamente em breve ou escolha outro nas configurações.';
  }

  @override
  String get publishErrorForbidden =>
      'Você não tem permissão para enviar para este servidor.';

  @override
  String get publishErrorFileNotFound =>
      'Não foi possível encontrar o arquivo de vídeo. Ele pode ter sido excluído. Grave de novo e tente novamente.';

  @override
  String get publishErrorLowStorage =>
      'Não há espaço suficiente no seu dispositivo. Libere espaço e tente novamente.';

  @override
  String get publishErrorThumbnailFailed =>
      'O vídeo foi enviado, mas não foi possível preparar a miniatura. Tente novamente.';

  @override
  String get publishErrorNostrPublishFailed =>
      'O vídeo foi enviado, mas não foi possível publicar o post. Verifique suas configurações de relay e tente novamente.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'O vídeo foi enviado, mas o áudio dele não está liberado para reutilização. Escolha outro áudio para publicar.';

  @override
  String get publishErrorInterrupted =>
      'Este envio foi interrompido. Quer tentar de novo?';

  @override
  String get publishErrorAccountChanged =>
      'Este vídeo é de outra conta. Volte para essa conta para publicá-lo.';

  @override
  String get publishErrorGeneric => 'Algo deu errado. Tente novamente.';

  @override
  String get publishErrorRateLimited =>
      'Muitos envios agora. Espere um momento e tente novamente.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Sua sessão de envio expirou. Tente novamente.';

  @override
  String get publishErrorPermissionDenied =>
      'O Divine não tem permissão para enviar. Verifique as permissões do app nas suas configurações e tente novamente.';

  @override
  String get publishErrorOutOfMemory =>
      'Seu dispositivo está com pouca memória. Feche alguns apps e tente novamente.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Não foi possível preparar o texto e os stickers deste rascunho. Abra no editor e poste de novo.';

  @override
  String get publishErrorUnknownServer => 'Servidor desconhecido';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filtro: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Nenhum resultado encontrado para \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Ver vídeos marcados com $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Som: $soundName de $creatorName. Toque para ver os detalhes do som.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Som original de $creatorName. Toque para usar este som.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Som: $soundName de $creatorName. Toque para ver os detalhes.';
  }

  @override
  String get soundDetailLoadError =>
      'Falha ao carregar o som. Por favor, tente novamente.';

  @override
  String get soundDetailNotFoundMessage =>
      'Não foi possível encontrar este som';

  @override
  String get soundDetailNotFoundTitle => 'Som não encontrado';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loops';
  }

  @override
  String get originalSoundUnavailableBody =>
      'O áudio deste vídeo não está disponível separadamente.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Som original - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'Viner OG';

  @override
  String get profileBadgeOgVinerBody =>
      'Essa pessoa postou um Vine original que a Divine encontrou no arquivo. Não é um selo de verificação de conta.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Marca de verificação do perfil';

  @override
  String get profileBadgeCheckmarkBody =>
      'A Divine dá essa marca às contas da equipe. É separado do NIP-05, dos links de conta verificados e do status de Viner OG.';

  @override
  String get unfollowConfirmButton => 'Deixar de seguir';

  @override
  String get videoClipSaveFailed => 'Falha ao salvar o clipe';

  @override
  String videoClipSaveTo(String destination) {
    return 'Salvar em $destination';
  }

  @override
  String get videoClipDelete => 'Excluir clipe';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirado por $creatorName +$additionalCreatorCount. Toque para ver o perfil dele.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspirado por $creatorName. Toque para ver o perfil dele.';
  }

  @override
  String get bugReportSendReport => 'Enviar relatório';

  @override
  String get supportSubjectRequiredLabel => 'Assunto *';

  @override
  String get supportPublicSubmissionTitle => 'Publicação pública no GitHub';

  @override
  String get supportPublicSubmissionMessage =>
      'Tudo o que você enviar aqui será publicado no nosso repositório de código aberto no GitHub para que os desenvolvedores possam cuidar disso. A publicação e a conta com que você entrou ficarão visíveis para todos.';

  @override
  String get supportRequiredHelper => 'Obrigatório';

  @override
  String get supportFieldLimitReached =>
      'Esse é o tamanho máximo. O que passou disso não foi adicionado.';

  @override
  String get bugReportSubjectHint => 'Resumo curto do problema';

  @override
  String get bugReportDescriptionRequiredLabel => 'O que aconteceu? *';

  @override
  String get bugReportDescriptionHint =>
      'Descreva o problema que você encontrou';

  @override
  String get bugReportStepsLabel => 'Passos para reproduzir';

  @override
  String get bugReportStepsHint =>
      '1. Vá para...\n2. Toque em...\n3. Veja o erro';

  @override
  String get bugReportExpectedBehaviorLabel => 'Comportamento esperado';

  @override
  String get bugReportExpectedBehaviorHint => 'O que deveria ter acontecido?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Informações do dispositivo e logs serão incluídos automaticamente.';

  @override
  String get bugReportSuccessMessage =>
      'Valeu! Recebemos seu relatório e vamos usar pra deixar o Divine melhor.';

  @override
  String get bugReportAttachImages => 'Anexar imagens';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count de $max imagens selecionadas';
  }

  @override
  String get bugReportRemoveImage => 'Remover imagem';

  @override
  String get bugReportUploadFailed =>
      'Não conseguimos enviar a imagem escolhida. Tente de novo ou mande o relato sem ela.';

  @override
  String get bugReportSendFailed =>
      'Falha ao enviar relatório de bug. Tente novamente mais tarde.';

  @override
  String get featureRequestSendRequest => 'Enviar pedido';

  @override
  String get featureRequestSubjectHint => 'Resumo curto da sua ideia';

  @override
  String get featureRequestDescriptionRequiredLabel => 'O que você quer? *';

  @override
  String get featureRequestDescriptionHint =>
      'Descreva o recurso que você quer';

  @override
  String get featureRequestUsefulnessLabel => 'Como isso seria útil?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explique o benefício que esse recurso traria';

  @override
  String get featureRequestWhenLabel => 'Quando você usaria isso?';

  @override
  String get featureRequestWhenHint =>
      'Descreva as situações em que isso ajudaria';

  @override
  String get featureRequestSuccessMessage =>
      'Valeu! Recebemos seu pedido de recurso e vamos avaliar.';

  @override
  String get featureRequestSendFailed =>
      'Falha ao enviar pedido de recurso. Tente novamente mais tarde.';

  @override
  String get notificationFollowBack => 'Seguir de volta';

  @override
  String get followingTitle => 'Seguindo';

  @override
  String followingTitleForName(String displayName) {
    return 'Quem $displayName segue';
  }

  @override
  String get followingFailedToLoadList => 'Falha ao carregar lista de seguindo';

  @override
  String get followingEmptyTitle => 'Ainda não segue ninguém';

  @override
  String get followersTitle => 'Seguidores';

  @override
  String followersTitleForName(String displayName) {
    return 'Seguidores de $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Falha ao carregar lista de seguidores';

  @override
  String get followersEmptyTitle => 'Sem seguidores ainda';

  @override
  String get followersUpdateFollowFailed =>
      'Falha ao atualizar status de seguir. Tente novamente.';

  @override
  String get followersSortSemanticLabel => 'Ordenar seguidores';

  @override
  String get followingSortSemanticLabel => 'Ordenar seguidos';

  @override
  String get followSortTitle => 'Ordenar por';

  @override
  String get followSortNewest => 'Mais recentes primeiro';

  @override
  String get followSortOldest => 'Mais antigos primeiro';

  @override
  String get newMessageTitle => 'Nova mensagem';

  @override
  String get newMessageFindPeople => 'Encontrar pessoas';

  @override
  String get newMessageNoContacts =>
      'Nenhum contato encontrado.\nSiga pessoas para vê-las aqui.';

  @override
  String get newMessageNoUsersFound => 'Nenhum usuário encontrado';

  @override
  String get hashtagSearchTitle => 'Buscar hashtags';

  @override
  String get hashtagSearchSubtitle => 'Descubra tópicos em alta e conteúdo';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Nenhuma hashtag encontrada para \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Busca falhou';

  @override
  String get userNotAvailableTitle => 'Conta indisponível';

  @override
  String get userNotAvailableBody => 'Esta conta não está disponível agora.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Falha ao salvar configurações. Tente novamente.';

  @override
  String get blossomValidServerUrl =>
      'Insira uma URL de servidor válida (ex.: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Configurações do Blossom salvas';

  @override
  String get blossomSaveTooltip => 'Salvar';

  @override
  String get blossomAboutTitle => 'Sobre o Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom é um protocolo descentralizado de armazenamento de mídia que permite enviar vídeos para qualquer servidor compatível. Por padrão, os vídeos são enviados para o servidor Blossom do Divine. Ative a opção abaixo para usar um servidor personalizado.';

  @override
  String get blossomUseCustomServer => 'Usar servidor Blossom personalizado';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Os vídeos serão enviados para seu servidor Blossom personalizado';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Seus vídeos estão sendo enviados para o servidor Blossom do Divine';

  @override
  String get blossomCustomServerUrl => 'URL do servidor Blossom personalizado';

  @override
  String get blossomCustomServerHelper =>
      'Insira a URL do seu servidor Blossom personalizado';

  @override
  String get blossomPopularServers => 'Servidores Blossom populares';

  @override
  String get blossomServerUrlMustUseHttps =>
      'A URL do servidor Blossom precisa usar https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Falha ao atualizar configuração de crosspost';

  @override
  String get blueskySignInRequired =>
      'Entre para gerenciar as configurações do Bluesky';

  @override
  String get blueskyPublishVideos => 'Publicar vídeos no Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Seus vídeos serão publicados no Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Seus vídeos não serão publicados no Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Seus vídeos antigos também serão publicados';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Quando você ativar isso, o Divine começará a enviar seus vídeos antigos para o Bluesky, dos mais antigos primeiro, sem correr com o limite diário.';

  @override
  String get blueskyHandle => 'Handle do Bluesky';

  @override
  String get blueskyDid => 'DID do Bluesky';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Conta provisionada e pronta';

  @override
  String get blueskyStatusPending => 'Provisionando conta...';

  @override
  String get blueskyStatusFailed => 'Falha ao provisionar conta';

  @override
  String get blueskyStatusDisabled => 'Conta desativada';

  @override
  String get blueskyStatusNotLinked => 'Nenhuma conta do Bluesky vinculada';

  @override
  String get blueskyUsernameRequired =>
      'Configure um identificador divine.video antes de publicar no Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Publicar no Bluesky exige um identificador usuario.divine.video já reservado.';

  @override
  String get blueskyUsernameSyncPending =>
      'Seu identificador Divine foi reservado. Estamos ligando ele ao Bluesky – tente de novo daqui a pouco.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Não conseguimos verificar seu identificador Divine. Tente de novo.';

  @override
  String get blueskySetUpHandle => 'Configurar';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Publicar no Bluesky está temporariamente indisponível. Tente de novo.';

  @override
  String get invitesTitle => 'Convidar amigos';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites prontos para gerar',
      one: '$count convite pronto para gerar',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Gere um código quando estiver pronto para compartilhar.';

  @override
  String get invitesGenerateButtonLabel => 'Gerar convite';

  @override
  String get invitesNoneAvailable => 'Sem convites disponíveis no momento';

  @override
  String get invitesShareWithPeople =>
      'Compartilhe o Divine com quem você conhece';

  @override
  String get invitesUsedInvites => 'Convites usados';

  @override
  String invitesShareMessage(String code) {
    return 'Vem pro Divine comigo! Use o código $code pra começar:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copiar convite';

  @override
  String get invitesCopied => 'Convite copiado!';

  @override
  String get invitesShareInvite => 'Compartilhar convite';

  @override
  String get invitesShareSubject => 'Vem pro Divine comigo';

  @override
  String get invitesClaimed => 'Resgatado';

  @override
  String get invitesCouldNotLoad => 'Não foi possível carregar os convites';

  @override
  String get invitesRetry => 'Tentar novamente';

  @override
  String get searchSomethingWentWrong => 'Algo deu errado';

  @override
  String get searchTryAgain => 'Tentar novamente';

  @override
  String get searchForLists => 'Buscar listas';

  @override
  String get searchFindCuratedVideoLists =>
      'Encontre listas de vídeos selecionados';

  @override
  String get searchEnterQuery => 'Digite uma busca';

  @override
  String get searchDiscoverSomethingInteresting => 'Descubra algo interessante';

  @override
  String get searchPeopleSectionHeader => 'Pessoas';

  @override
  String get searchPeopleLoadingLabel => 'Carregando resultados de pessoas';

  @override
  String get searchTagsSectionHeader => 'Tags';

  @override
  String get searchTagsLoadingLabel => 'Carregando resultados de tags';

  @override
  String get searchVideosSectionHeader => 'Vídeos';

  @override
  String get searchVideosLoadingLabel => 'Carregando resultados de vídeos';

  @override
  String get searchVideosSortOptionsLabel => 'Ordenar resultados de vídeo';

  @override
  String get searchVideosSortTrending => 'Em alta';

  @override
  String get searchVideosSortLoops => 'Mais loops';

  @override
  String get searchVideosSortEngagement => 'Mais engajamento';

  @override
  String get searchVideosSortRecent => 'Recentes';

  @override
  String get searchListsSectionHeader => 'Listas';

  @override
  String get searchListsLoadingLabel => 'Carregando resultados de listas';

  @override
  String get cameraAgeRestriction =>
      'Você precisa ter 16 anos ou mais para criar conteúdo';

  @override
  String get keyImportInsecureBunkerRelay =>
      'O relay do bunker precisa usar wss:// (ws:// só é permitido em localhost)';

  @override
  String get timeNow => 'agora';

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
  String get timeVerboseNow => 'Agora';

  @override
  String timeAgo(String time) {
    return '$time atrás';
  }

  @override
  String get timeToday => 'Hoje';

  @override
  String get timeYesterday => 'Ontem';

  @override
  String get timeJustNow => 'agora mesmo';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min atrás';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String get draftTimeJustNow => 'Agora mesmo';

  @override
  String get contentLabelNudity => 'Nudez';

  @override
  String get contentLabelSexualContent => 'Conteúdo sexual';

  @override
  String get contentLabelPornography => 'Pornografia';

  @override
  String get contentLabelGraphicMedia => 'Conteúdo gráfico';

  @override
  String get contentLabelViolence => 'Violência';

  @override
  String get contentLabelSelfHarm => 'Automutilação/Suicídio';

  @override
  String get contentLabelDrugUse => 'Uso de drogas';

  @override
  String get contentLabelAlcohol => 'Álcool';

  @override
  String get contentLabelTobacco => 'Tabaco/Tabagismo';

  @override
  String get contentLabelGambling => 'Jogos de azar';

  @override
  String get contentLabelProfanity => 'Linguagem obscena';

  @override
  String get contentLabelHateSpeech => 'Discurso de ódio';

  @override
  String get contentLabelHarassment => 'Assédio';

  @override
  String get contentLabelFlashingLights => 'Luzes piscantes';

  @override
  String get contentLabelAiGenerated => 'Gerado por IA';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Golpe/Fraude';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Enganoso';

  @override
  String get contentLabelSensitiveContent => 'Conteúdo sensível';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName curtiu seu vídeo';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName curtiu seu comentário';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName comentou no seu vídeo';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName começou a seguir você';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName mencionou você';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName repostou seu vídeo';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName postou um novo vine';
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
      other: '$count dos seus vines',
      one: 'seu vine',
    );
    return '$actorName adicionou $_temp0 em $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName respondeu ao teu comentário';
  }

  @override
  String get notificationAndConnector => 'e';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count pessoas',
      one: 'mais $count pessoa',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Você tem uma nova atualização';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Ocultar teclado';

  @override
  String get commentsErrorLoadFailed =>
      'Não foi possível carregar os comentários';

  @override
  String get commentsErrorNotAuthenticatedComment => 'Entre para comentar';

  @override
  String get commentsErrorPostCommentFailed =>
      'Não foi possível publicar o comentário';

  @override
  String get commentsErrorPostReplyFailed =>
      'Não foi possível publicar a resposta';

  @override
  String get commentsErrorEditFailed => 'Não foi possível editar o comentário';

  @override
  String get commentsErrorNotAuthenticatedInteract => 'Entre para interagir';

  @override
  String get commentsErrorVoteFailed => 'Não foi possível votar no comentário';

  @override
  String get commentsErrorReportFailed =>
      'Não foi possível denunciar o comentário';

  @override
  String get commentsErrorBlockFailed => 'Não foi possível bloquear a pessoa';

  @override
  String get commentsErrorDeleteFailed =>
      'Não foi possível excluir o comentário';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentários',
      one: '$count comentário',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Publicando…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'A tua resposta em vídeo está a ser publicada';

  @override
  String get commentsSortNew => 'Recentes';

  @override
  String get commentsSortTop => 'Melhores';

  @override
  String get commentsSortOld => 'Antigos';

  @override
  String get commentsSortSemanticLabel => 'Ordenação dos comentários';

  @override
  String get commentReply => 'Responder';

  @override
  String get commentReplySemanticLabel => 'Responder ao comentário';

  @override
  String get commentUpvoteLabel => 'Votar a favor do comentário';

  @override
  String get commentRemoveUpvoteLabel => 'Remover voto a favor';

  @override
  String get commentDownvoteLabel => 'Votar contra o comentário';

  @override
  String get commentRemoveDownvoteLabel => 'Remover voto contra';

  @override
  String get commentsInputHint => 'Adicionar comentário...';

  @override
  String get commentsInputHintEdit => 'Editar comentário...';

  @override
  String get commentsEmptyTitle => 'Ainda não há comentários';

  @override
  String get commentsEmptySubtitle => 'Comece a festa!';

  @override
  String get draftUntitled => 'Sem título';

  @override
  String get contentWarningNone => 'Nenhum';

  @override
  String get textBackgroundNone => 'Nenhum';

  @override
  String get textBackgroundSolid => 'Sólido';

  @override
  String get textBackgroundHighlight => 'Destaque';

  @override
  String get textBackgroundTransparent => 'Transparente';

  @override
  String get textAlignLeft => 'Esquerda';

  @override
  String get textAlignRight => 'Direita';

  @override
  String get textAlignCenter => 'Centro';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'A câmera ainda não é compatível na web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'A captura e a gravação com câmera ainda não estão disponíveis na versão web.';

  @override
  String get cameraPermissionBackToFeed => 'Voltar ao feed';

  @override
  String get cameraCouldNotStart => 'Não foi possível iniciar a câmera';

  @override
  String get cameraUnsupportedPlatform =>
      'A câmera ainda não está disponível nesta plataforma.\nVocê ainda pode navegar e assistir aos vídeos.';

  @override
  String get cameraPermissionErrorTitle => 'Erro de permissão';

  @override
  String get cameraPermissionErrorDescription =>
      'Ocorreu um erro ao verificar as permissões.';

  @override
  String get cameraPermissionRetry => 'Tentar novamente';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Permitir acesso à câmera e ao microfone';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Isso permite capturar e editar vídeos direto no app, nada além disso.';

  @override
  String get cameraPermissionGoToSettings => 'Ir para configurações';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Por que seis segundos?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Clipes curtos abrem espaço para a espontaneidade. O formato de 6 segundos ajuda você a capturar momentos autênticos enquanto acontecem.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Entendi!';

  @override
  String get videoRecorderUploadTitle => 'Por que sem upload?';

  @override
  String get videoRecorderUploadBody =>
      'O que você vê no Divine é feito por humanos: cru e capturado no momento. Diferente das plataformas que permitem uploads muito produzidos ou gerados por IA, priorizamos a autenticidade da experiência câmera-direta.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Ao manter a criação dentro do app, podemos garantir melhor que o conteúdo é real e sem edição. Não estamos abrindo uploads da galeria externa neste momento para proteger essa autenticidade e manter nossa comunidade livre de conteúdo sintético tanto quanto possível.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Mude para Capture ou Classic para gravar algo real.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Saiba como a verificação funciona';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Encontramos trabalho em andamento';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Você gostaria de continuar de onde parou?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Sim, continuar';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Não, iniciar um novo vídeo';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Não foi possível restaurar seu rascunho';

  @override
  String get videoRecorderStopRecordingTooltip => 'Parar gravação';

  @override
  String get videoRecorderStartRecordingTooltip => 'Iniciar gravação';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Gravando. Toque em qualquer lugar para parar';

  @override
  String get videoRecorderTapToStartLabel =>
      'Toque em qualquer lugar para iniciar a gravação';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Excluir último clipe';

  @override
  String get videoRecorderSwitchCameraLabel => 'Trocar câmera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoom para $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Alternar grade';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Alternar quadro fantasma';

  @override
  String get videoRecorderGhostFrameEnabled => 'Quadro fantasma ativado';

  @override
  String get videoRecorderGhostFrameDisabled => 'Quadro fantasma desativado';

  @override
  String get videoRecorderClipDeletedMessage => 'Clipe movido para a lixeira';

  @override
  String get videoRecorderClipUndoLabel => 'Desfazer';

  @override
  String get libraryTrashEmptyTitle => 'A lixeira está vazia';

  @override
  String get libraryTrashEmptySubtitle =>
      'Os clipes excluídos ficam aqui por 30 dias antes de serem removidos permanentemente.';

  @override
  String get libraryTrashRestoreLabel => 'Restaurar';

  @override
  String get libraryTrashDeleteNowLabel => 'Excluir agora';

  @override
  String get libraryTrashEmptyAllLabel => 'Esvaziar lixeira';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Excluir clipe agora?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Isso remove o clipe da lixeira imediatamente.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Esvaziar lixeira?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes',
      one: '$count clipe',
    );
    return 'Isso exclui permanentemente da lixeira $_temp0 agora mesmo.';
  }

  @override
  String get videoRecorderCloseLabel => 'Fechar gravador de vídeo';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Continuar para o editor de vídeo';

  @override
  String get videoRecorderCameraPreviewLabel => 'Pré-visualização da câmara';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Focar a câmara';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Mudar para o modo $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Adicione áudio antes de gravar';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Não foi possível criar o vídeo. Tente novamente.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restam $count fotos',
      one: 'Resta $count foto',
      zero: 'Nenhuma foto restante',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Alternar flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Alternar temporizador';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Alternar proporção';

  @override
  String get videoRecorderStabilizationLabel => 'Estabilização';

  @override
  String get videoRecorderStabilizationModeOff => 'Desativada';

  @override
  String get videoRecorderStabilizationModeStandard => 'Padrão';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinematográfica';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematográfica ampliada';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Otimizada para visualização';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Baixa latência';

  @override
  String get videoRecorderStabilizationModeAuto => 'Automática';

  @override
  String get videoRecorderFlashValueOff => 'Desativado';

  @override
  String get videoRecorderFlashValueOn => 'Ativado';

  @override
  String get videoRecorderFlashValueAuto => 'Automático';

  @override
  String get videoRecorderTimerValueOff => 'Desativado';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 segundos';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 segundos';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Quadrado';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Vertical';

  @override
  String get videoRecorderCameraValueFront => 'Câmera frontal';

  @override
  String get videoRecorderCameraValueBack => 'Câmera traseira';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Biblioteca de clipes, sem clipes';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Abrir biblioteca de clipes, $clipCount clipes',
      one: 'Abrir biblioteca de clipes, $clipCount clipe',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Abrir biblioteca de stop motion, $frameCount quadros',
      one: 'Abrir biblioteca de stop motion, $frameCount quadro',
      zero: 'Abrir biblioteca de stop motion',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Câmera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Abrir câmera';

  @override
  String get videoEditorLibraryLabel => 'Biblioteca';

  @override
  String get videoEditorTextLabel => 'Texto';

  @override
  String get videoEditorDrawLabel => 'Desenhar';

  @override
  String get videoEditorFilterLabel => 'Filtro';

  @override
  String get videoEditorTuneLabel => 'Ajustar';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Abrir editor de ajustes';

  @override
  String get videoEditorTuneBrightness => 'Brilho';

  @override
  String get videoEditorTuneContrast => 'Contraste';

  @override
  String get videoEditorTuneSaturation => 'Saturação';

  @override
  String get videoEditorTuneExposure => 'Exposição';

  @override
  String get videoEditorTuneHue => 'Matiz';

  @override
  String get videoEditorTuneTemperature => 'Temperatura';

  @override
  String get videoEditorTuneTint => 'Tonalidade';

  @override
  String get videoEditorTuneFade => 'Esmaecer';

  @override
  String get videoEditorAudioLabel => 'Áudio';

  @override
  String get videoEditorAddTitle => 'Adicionar';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Abrir biblioteca';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Abrir editor de áudio';

  @override
  String get videoEditorCaptionsLabel => 'Legendas';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Abrir o editor de legendas';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Gravar no vídeo';

  @override
  String get videoEditorCaptionsPresetCustom => 'Person.';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Estilo personalizado';

  @override
  String get videoEditorCaptionsCustomApply => 'Aplicar';

  @override
  String get videoEditorCaptionsCustomFont => 'Fonte';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Cor do texto';

  @override
  String get videoEditorCaptionsCustomBackground => 'Fundo';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Cor do fundo';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animação';

  @override
  String get videoEditorCaptionsAnimationNone => 'Nenhuma';

  @override
  String get videoEditorCaptionsAnimationFade => 'Fade';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Mola';

  @override
  String get videoEditorCaptionsEditTitle => 'Legendas';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Ouvindo…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Transformamos seu áudio em sugestões de legenda.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Não ouvimos nenhuma fala. Você ainda pode escrever as legendas.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'O reconhecimento de voz não está disponível neste aparelho. Você pode escrever as legendas.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'O reconhecimento de voz não está permitido. Ative-o nos Ajustes ou escreva as legendas.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'A transcrição não funcionou desta vez. Você pode escrever as legendas.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Escrever as legendas eu mesmo';

  @override
  String get videoEditorCaptionsAddCue => 'Adicionar legenda';

  @override
  String get videoEditorCaptionsCueTextHint => 'Texto da legenda';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Excluir legenda';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Remover todas as legendas';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Remover as legendas?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Todo o texto e os tempos serão perdidos.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Fechar o editor de legendas';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Confirmar legendas';

  @override
  String get videoEditorCaptionsPresetTitle => 'Estilo das legendas';

  @override
  String get videoEditorCaptionsPresetClassic => 'Clássico';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Manchete';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Máquina de escrever';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marcador';

  @override
  String get videoEditorCaptionsPresetScript => 'Caligrafia';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retrô';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegante';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bolha';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Negrito';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Sonhador';

  @override
  String get videoEditorCaptionsPresetOcean => 'Oceano';

  @override
  String get videoEditorCaptionsPresetSunny => 'Ensolarado';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Manuscrito';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serifa';

  @override
  String get videoEditorCaptionsPresetStamp => 'Carimbo';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Abrir editor de texto';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Abrir editor de desenho';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Abrir editor de filtros';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Abrir editor de stickers';

  @override
  String get videoEditorSaveDraftTitle => 'Salvar seu rascunho?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Guarde suas edições para depois ou descarte-as e saia do editor.';

  @override
  String get videoEditorSaveDraftButton => 'Salvar rascunho';

  @override
  String get videoEditorDiscardChangesButton => 'Descartar alterações';

  @override
  String get videoEditorKeepEditingButton => 'Continuar editando';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Área para soltar e excluir camada';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Solte para excluir a camada';

  @override
  String get videoEditorDoneLabel => 'Concluído';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Reproduzir ou pausar vídeo';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Posição de divisão inválida. Ambos os clipes devem ter pelo menos $minDurationMs ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Salvar clipe selecionado';

  @override
  String get videoEditorSaveClip => 'Salvar clipe';

  @override
  String get videoEditorClipSavedSuccess => 'Clipe salvo na biblioteca';

  @override
  String get videoEditorClipSaveFailed => 'Falha ao salvar clipe';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Seletor de cor';

  @override
  String get videoEditorUndoSemanticLabel => 'Desfazer';

  @override
  String get videoEditorRedoSemanticLabel => 'Refazer';

  @override
  String get videoEditorTextColorSemanticLabel => 'Cor do texto';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Alinhamento do texto';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Fundo do texto';

  @override
  String get videoEditorFontSemanticLabel => 'Fonte';

  @override
  String get videoEditorNoStickersFound => 'Nenhum sticker encontrado';

  @override
  String get videoEditorNoStickersAvailable => 'Nenhum sticker disponível';

  @override
  String get videoEditorFailedLoadStickers => 'Falha ao carregar stickers';

  @override
  String get videoEditorVoiceOverLabel => 'Narração';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Gravação $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Gravar uma narração';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Iniciar gravação';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Parar gravação';

  @override
  String get videoEditorVoiceOverHint =>
      'Toque para gravar. Adicione quantas tomadas quiser.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gravações',
      one: '$count gravação',
      zero: 'Ainda sem gravações',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Excluir última gravação';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Acesso ao microfone necessário';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Permita o acesso ao microfone para gravar uma narração.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Abrir configurações';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Gravação iniciada';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Gravação salva';

  @override
  String get videoEditorVoiceOverTooLong =>
      'A gravação é mais longa que o seu vídeo';

  @override
  String get videoEditorPlaySemanticLabel => 'Reproduzir';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausar';

  @override
  String get videoEditorVolumeSemanticLabel => 'Ajustar volume';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Deslize para ajustar';

  @override
  String get videoEditorChromaKeyLabel => 'Fundo verde';

  @override
  String get videoEditorChromaKeyTitle => 'Fundo verde';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Configurar o fundo verde deste clipe';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Descartar as alterações do fundo verde';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Aplicar o fundo verde';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Detetar automaticamente';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Verde';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Azul';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Cor do fundo';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Intensidade';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Quanto da cor do fundo desaparece';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Contorno';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Suaviza o recorte para o cabelo não ficar serrilhado';

  @override
  String get videoEditorChromaKeySpillLabel => 'Derrame';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Tira o tom do fundo do teu motivo';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Substituir por';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Nada';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Cor';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Imagem';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clipe';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'O vídeo não guarda transparência, por isso isto é exportado a preto.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Não encontrámos nenhum fundo. Tem de chegar às margens da imagem — caso contrário, escolhe a cor à mão.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Escolher um clipe';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'A tua biblioteca está vazia. Guarda primeiro um clipe e depois usa-o como fundo.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Não foi possível carregar essa imagem.';

  @override
  String get videoEditorChromaKeyRemove => 'Remover o fundo verde';

  @override
  String get videoEditorChromaKeyFailed =>
      'Não foi possível aplicar o fundo verde. O teu clipe fica igual.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Não foi possível remover o fundo verde. O teu clipe fica igual.';

  @override
  String get videoEditorChromaKeyApplying => 'A aplicar o fundo verde…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Este dispositivo não consegue mostrar a pré-visualização ao vivo. As tuas definições aplicam-se na mesma ao exportar.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clipe $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Excluir';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Excluir item selecionado';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Quadros por imagem';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quadros',
      one: '$count quadro',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Quadros';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count quadros por imagem';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Quadro de stop motion $position de $total';
  }

  @override
  String get videoEditorEditLabel => 'Editar';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Editar item selecionado';

  @override
  String get videoEditorDuplicateLabel => 'Duplicar';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplicar item selecionado';

  @override
  String get videoEditorCombineLabel => 'Combinar';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Combinar os desenhos selecionados numa camada';

  @override
  String get videoEditorSplitLabel => 'Dividir';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Dividir clipe selecionado';

  @override
  String get videoEditorExtractAudioLabel => 'Extrair áudio';

  @override
  String get videoEditorClipAudioTitle => 'Áudio do clip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Extrair áudio do clipe e silenciar o original';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Não é possível extrair o áudio: o clipe não está disponível localmente.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Não foi possível extrair o áudio. Por favor, tente novamente.';

  @override
  String get videoEditorSpeedLabel => 'Velocidade';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Definir a velocidade de reprodução do clipe selecionado';

  @override
  String get videoEditorReverseLabel => 'Inverter';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Ativar ou desativar a reprodução inversa para o clipe selecionado';

  @override
  String get videoEditorReverseProgressLabel =>
      'Um momento, estamos invertendo seu clipe';

  @override
  String get videoEditorTransformLabel => 'Transformar';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Cortar, girar ou inverter o clipe selecionado';

  @override
  String get videoEditorTransformProgressLabel =>
      'Um momento, estamos transformando seu clipe';

  @override
  String get videoEditorTransformFailed =>
      'Não foi possível transformar o clipe. Tente novamente.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Não é possível transformar: o clipe não está disponível localmente.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Cortar, girar ou espelhar o quadro selecionado';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Um momento, estamos transformando seu quadro';

  @override
  String get videoEditorTransformFrameFailed =>
      'Não foi possível transformar o quadro. Tente novamente.';

  @override
  String get videoEditorTransformRotateLabel => 'Girar';

  @override
  String get videoEditorTransformFlipLabel => 'Inverter';

  @override
  String get videoEditorTransformResetLabel => 'Redefinir';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Aplicar transformação';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Cancelar transformação';

  @override
  String get videoEditorTransformPlayLabel => 'Reproduzir';

  @override
  String get videoEditorTransformPauseLabel => 'Pausar';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Não é possível inverter: o clipe não está disponível localmente.';

  @override
  String get videoEditorReverseFailed =>
      'Não foi possível inverter o clipe. Por favor, tente novamente.';

  @override
  String get videoEditorSpeedSheetTitle => 'Velocidade do clipe';

  @override
  String get videoEditorTransitionSheetTitle => 'Transição';

  @override
  String get videoEditorTransitionNone => 'Nenhuma';

  @override
  String get videoEditorTransitionDissolve => 'Dissolução';

  @override
  String get videoEditorTransitionFadeToBlack => 'Esmaecer para preto';

  @override
  String get videoEditorTransitionFadeToWhite => 'Esmaecer para branco';

  @override
  String get videoEditorTransitionSlide => 'Deslizar';

  @override
  String get videoEditorTransitionPush => 'Empurrar';

  @override
  String get videoEditorTransitionWipe => 'Varredura';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Editar transição';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Transição de loop';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Editar transição de loop';

  @override
  String get videoEditorTransitionDuration => 'Duração';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Encurtada para não se sobrepor à transição adjacente.';

  @override
  String get videoEditorTransitionCurve => 'Curva';

  @override
  String get videoEditorTransitionDirection => 'Direção';

  @override
  String get videoEditorTransitionDirectionLeft => 'Esquerda';

  @override
  String get videoEditorTransitionDirectionRight => 'Direita';

  @override
  String get videoEditorTransitionDirectionUp => 'Cima';

  @override
  String get videoEditorTransitionDirectionDown => 'Baixo';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Curva de animação $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animação';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Editar animação da camada';

  @override
  String get videoEditorLayerAnimationEnter => 'Entrada';

  @override
  String get videoEditorLayerAnimationLeave => 'Saída';

  @override
  String get videoEditorLayerAnimationFade => 'Fundido';

  @override
  String get videoEditorLayerAnimationScale => 'Escala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Escalar de';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Finalizar edição da linha do tempo';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Reproduzir prévia';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Pausar prévia';

  @override
  String get videoEditorAudioUntitledSound => 'Som sem título';

  @override
  String get videoEditorAudioUntitled => 'Sem título';

  @override
  String get videoEditorAudioAddAudio => 'Adicionar áudio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Nenhum som disponível';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Os sons aparecerão aqui quando criadores compartilharem áudio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Falha ao carregar sons';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Selecione o trecho de áudio para seu vídeo';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Comunidade';

  @override
  String get videoEditorAudioCategoryFeatured => 'Destaques';

  @override
  String get videoEditorAudioCategoryMySounds => 'Meus sons';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Ferramenta seta';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Ferramenta borracha';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Ferramenta marcador';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Ferramenta lápis';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Mostrar linha do tempo';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ocultar linha do tempo';

  @override
  String get videoEditorFeedPreviewContent =>
      'Evite posicionar conteúdo atrás dessas áreas.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originais';

  @override
  String get videoEditorStickerSearchHint => 'Buscar stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Selecionar fonte';

  @override
  String get videoEditorFontUnknown => 'Desconhecida';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'A cabeça de reprodução deve estar dentro do clipe selecionado para dividir.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Aparar início';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Aparar fim';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Aparar clipe';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Arraste as alças para ajustar a duração do clipe';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Arrastando clipe $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clipe $index de $total, $duration segundos';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Pressione e segure para reordenar';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Mover para a esquerda';

  @override
  String get videoEditorTimelineClipMoveRight => 'Mover para a direita';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clipe $index de $total, selecionado';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clipe $index de $total, não selecionado';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Selecionar';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Selecionar vários clipes';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Concluir seleção';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes selecionados',
      one: '$count clipe selecionado',
      zero: 'Nenhum clipe selecionado',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Selecionar vários desenhos';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Concluir a seleção de desenhos';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Eliminar os desenhos selecionados';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count desenhos selecionados',
      one: '$count desenho selecionado',
      zero: 'Nenhum desenho selecionado',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Mesclar';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Mesclar clipes selecionados';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Excluir clipes selecionados';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Excluir quadros selecionados';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Inverter quadros selecionados';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplicar quadros selecionados';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Seu vídeo precisa de pelo menos ${seconds}s — capture mais alguns quadros.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Um momento, estamos mesclando seus clipes';

  @override
  String get videoEditorMergeFailed =>
      'Não foi possível mesclar os clipes. Tente novamente.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Pressione e segure para arrastar';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Linha do tempo do vídeo';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, selecionada';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Fechar seletor de cor';

  @override
  String get videoEditorPickColorTitle => 'Escolher cor';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirmar cor';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturação e brilho';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturação $saturation%, Brilho $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Matiz';

  @override
  String get videoEditorAddElementSemanticLabel => 'Adicionar elemento';

  @override
  String get videoEditorDoneSemanticLabel => 'Concluído';

  @override
  String get videoEditorLevelSemanticLabel => 'Nível';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Fechar detalhes da publicação';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Fechar diálogo de ajuda';

  @override
  String get videoMetadataGotItButton => 'Entendi!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limite de 64 KB atingido. Remova parte do conteúdo para continuar.';

  @override
  String get videoMetadataExpirationLabel => 'Expiração';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Selecionar tempo de expiração';

  @override
  String get videoMetadataTitleLabel => 'Título';

  @override
  String get videoMetadataDescriptionLabel => 'Descrição';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Excluir tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Aviso de conteúdo';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Selecionar avisos de conteúdo';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Selecione tudo que se aplica ao seu conteúdo';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Permita que outros salvem e reutilizem o áudio deste vídeo.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Seu vídeo está no ar, mas o som não foi publicado. Edite o vídeo para compartilhar o som.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Colaboradores';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Adicionar colaborador';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Seguidores mútuos';

  @override
  String get videoMetadataInspiredByLabel => 'Inspirado por';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Definir inspirado por';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Este criador não pode ser referenciado.';

  @override
  String get videoMetadataPostDetailsTitle => 'Detalhes da postagem';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Salvo na biblioteca';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Falha ao salvar';

  @override
  String get videoMetadataGoToLibraryButton => 'Ir para a biblioteca';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Botão salvar para depois';

  @override
  String get videoMetadataSavingVideoHint => 'Salvando vídeo...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Salvar vídeo nos rascunhos e $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Salvar vídeo nos rascunhos. Ainda não há vídeo renderizado, então nenhuma cópia é adicionada a $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Salvar para depois';

  @override
  String get videoMetadataPostSemanticLabel => 'Botão publicar';

  @override
  String get videoMetadataPublishVideoHint => 'Publicar vídeo no feed';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Compartilhar também no meu feed';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Desligado mantém este vídeo apenas na conversa de comentários.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Preencha o formulário para habilitar';

  @override
  String get videoMetadataPostButton => 'Publicar';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Abrir tela de pré-visualização da postagem';

  @override
  String get videoMetadataShareTitle => 'Compartilhar';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Detalhes do vídeo';

  @override
  String get videoMetadataClassicDoneButton => 'Concluído';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Reproduzir prévia';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Pausar prévia';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Fechar prévia do vídeo';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Remover';

  @override
  String get fullscreenFeedRemovedMessage => 'Vídeo removido';

  @override
  String get fullscreenFeedEmptyMessage =>
      'Não há mais nada para reproduzir aqui';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle =>
      'Aceite premiações e veja o status das badges emitidas.';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesLoadError => 'Não foi possível carregar as badges';

  @override
  String get badgesUpdateError => 'Não foi possível atualizar a badge';

  @override
  String get badgesAwardedEmptyTitle => 'Nenhuma badge recebida ainda';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Quando alguém te der uma badge Nostr, ela aparece aqui.';

  @override
  String get badgesStatusAccepted => 'Aceita';

  @override
  String get badgesStatusNotAccepted => 'Não aceita';

  @override
  String get badgesActionRemove => 'Remover';

  @override
  String get badgesActionAccept => 'Aceitar';

  @override
  String get badgesActionReject => 'Recusar';

  @override
  String get badgesIssuedEmptyTitle => 'Nenhuma badge emitida ainda';

  @override
  String get badgesIssuedEmptySubtitle =>
      'As badges que você emitir vão mostrar o status de aceitação aqui.';

  @override
  String get badgesIssuedNoRecipients =>
      'Nenhum destinatário encontrado para esta premiação.';

  @override
  String get badgesRecipientAcceptedStatus => 'Aceita pelo destinatário';

  @override
  String get badgesRecipientWaitingStatus => 'Aguardando destinatário';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ocultos ($count)',
      one: 'Oculto ($count)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Restaurar';

  @override
  String get badgesHiddenSnackbar => 'Selo oculto';

  @override
  String get badgesHiddenSnackbarUndo => 'Desfazer';

  @override
  String get badgesTabAwarded => 'Recebidos';

  @override
  String get badgesTabCreated => 'Criados';

  @override
  String get badgesTabIssued => 'Entregues';

  @override
  String get badgesCreateAction => 'Novo selo';

  @override
  String get badgesCreatedEmptyTitle => 'Nenhum selo criado ainda';

  @override
  String get badgesCreatedEmptySubtitle => 'Crie um e entregue a quem merece.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entregue a $count pessoas',
      one: 'Entregue a $count pessoa',
      zero: 'Ainda não entregue',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Novo selo';

  @override
  String get badgeEditorEditTitle => 'Editar selo';

  @override
  String get badgeEditorNameLabel => 'Nome';

  @override
  String get badgeEditorNameHint => 'Rouba a cena';

  @override
  String get badgeEditorIdentifierLabel => 'Identificador';

  @override
  String get badgeEditorIdentifierHelp =>
      'Faz parte do endereço do selo, então fica fixo depois que ele existe.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Você já tem um selo com este identificador. Edite aquele — publicar aqui iria substituí-lo.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Todo selo precisa de um identificador — digite um se o nome não preencheu.';

  @override
  String get badgeEditorDescriptionLabel => 'Descrição';

  @override
  String get badgeEditorDescriptionHint =>
      'Para quem rouba a cena com um único loop.';

  @override
  String get badgeEditorArtworkLabel => 'Arte';

  @override
  String get badgeEditorArtworkAdd => 'Adicionar arte';

  @override
  String get badgeEditorArtworkReplace => 'Substituir';

  @override
  String get badgeEditorArtworkError => 'Não foi possível enviar essa imagem';

  @override
  String get badgeEditorArtworkRequired => 'Todo selo precisa de uma arte.';

  @override
  String get badgeEditorArtworkRemove => 'Remover a arte';

  @override
  String get badgeEditorArtworkSheetTitle => 'Arte do selo';

  @override
  String get badgeDetailDeleteAction => 'Excluir selo';

  @override
  String get badgeDetailDeleteTitle => 'Excluir este selo?';

  @override
  String get badgeDetailDeleteBody =>
      'Isso pede aos relays que removam o selo e todas as entregas que você fez. Os relays podem recusar, e quem fixou continua com ele no perfil até tirar.';

  @override
  String get badgeDetailDeleteConfirm => 'Excluir';

  @override
  String get badgeEditorSaveAction => 'Publicar selo';

  @override
  String get badgeEditorSaveError => 'Não foi possível publicar o selo';

  @override
  String get badgeEditorLoadError => 'Não foi possível carregar este selo';

  @override
  String get badgeDetailTitle => 'Selo';

  @override
  String get badgeDetailMadeBy => 'Criado por';

  @override
  String get badgeDetailRecipientsTitle => 'Entregue a';

  @override
  String get badgeDetailNoRecipients => 'Ninguém tem este ainda.';

  @override
  String get badgeDetailAwardAction => 'Entregar este selo';

  @override
  String get badgeDetailEditAction => 'Editar selo';

  @override
  String get badgeDetailShareAction => 'Compartilhar';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Olha este selo no Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Retirar o selo';

  @override
  String get badgeDetailRevokeTitle => 'Retirar este selo?';

  @override
  String get badgeDetailRevokeBody =>
      'Isso pede aos relays que removam a entrega que você fez a esta pessoa. Os relays podem recusar, e se ela já fixou o selo, ele continua no perfil até que o tire. De qualquer forma, ela não é avisada.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Isso pede aos relays que removam a entrega que você fez a si mesmo e tira o selo do seu perfil. Se os relays recusarem a exclusão, nada muda.';

  @override
  String get badgeDetailRevokeConfirm => 'Retirar';

  @override
  String get badgeDetailRevokeSuccess => 'Selo retirado';

  @override
  String get badgeDetailBlockClaimantsAction => 'Bloquear quem usa o selo';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Bloquear quem usa o selo';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Não foi possível carregar quem usa este selo';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Ninguém está usando este selo agora';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Não encontramos ninguém para bloquear agora.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bloquear $count contas?',
      one: 'Bloquear $count conta?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Isso bloqueia as $count contas que estão usando este selo agora. Os posts delas não vão aparecer no seu feed e elas não serão notificadas.',
      one:
          'Isso bloqueia a conta que está usando este selo agora. Os posts dessa pessoa não vão aparecer no seu feed e ela não será notificada.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bloquear $count contas',
      one: 'Bloquear $count conta',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Contas com o selo bloqueadas';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Não foi possível bloquear quem usa o selo';

  @override
  String get badgeDetailLoadError => 'Não foi possível carregar este selo';

  @override
  String get badgeDetailMissing => 'Não achamos este selo em nenhum relay.';

  @override
  String get badgeDetailActionError => 'Isso não deu certo';

  @override
  String get badgeAwardTitle => 'Entregar selo';

  @override
  String get badgeAwardPickAction => 'Escolher pessoas';

  @override
  String get badgeAwardManualLabel => 'Ou cole chaves';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Escolha pelo menos uma pessoa.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entregar a $count pessoas',
      one: 'Entregar a $count pessoa',
      zero: 'Entregar selo',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Entregue por';

  @override
  String get profileBadgeRecipients => 'Destinatários';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count mais';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Selo $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Selo';

  @override
  String get profileBadgeFooterBody =>
      'Badges são pequenos prêmios que qualquer pessoa pode criar no Nostr. Dê uma para um amigo, um criador ou alguém que alegrou o seu dia.';

  @override
  String get profileBadgeFooterLink => 'Crie o seu próprio selo';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Guia para famílias';

  @override
  String get minorAccountReviewWelcomeTitle => 'Ainda não tem 16? Tudo bem.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Você ter entrado nesta página em vez de simplesmente escolher a resposta que te deixava passar diz muito. Mostra honestidade, caráter e cuidado de verdade com as pessoas ao seu redor.\n\nAs regras para quem tem menos de 16 anos variam dependendo de onde você mora. Na Divine, queremos que as famílias conversem sobre isso juntas e decidam como é um uso saudável das redes sociais.';

  @override
  String get minorAccountReviewModerationTitle => 'Falta mais um passo';

  @override
  String get minorAccountReviewModerationBody =>
      'Pediram que a gente olhasse esta conta com mais atenção, porque ela pode ser de alguém com menos de 16 anos. Este fluxo mantém os próximos passos privados e mostra o caminho certo para a sua idade.';

  @override
  String get minorAccountReviewRulesTitle =>
      'As regras não são iguais em todo lugar';

  @override
  String get minorAccountReviewRulesBody =>
      'Países e regiões tratam de formas diferentes o uso de redes sociais por adolescentes. Por isso pedimos que as famílias parem um pouco, confiram os fatos e escolham o próximo passo juntas.';

  @override
  String get minorAccountReviewApproachTitle => 'Como a Divine enxerga isso';

  @override
  String get minorAccountReviewApproachBody =>
      'Acreditamos que hábitos saudáveis com tecnologia vêm de pausar, refletir e redirecionar a atenção para coisas melhores — não de vigiar crianças ou transformar pais em fiscais. As pesquisas também apontam nessa direção.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Mais para famílias';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Leia a política da Divine para crianças';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'Escolha o caminho que combina';

  @override
  String get minorAccountReviewUnder13Cta => 'Menos de 13';

  @override
  String get minorAccountReviewTeenCta => '13 a 15 anos';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Veja o guia da Divine para famílias com dicas práticas, ferramentas de conversa e materiais que ajudam adolescentes a usar redes sociais com mais segurança.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Acesse guias e dicas para famílias';

  @override
  String get minorAccountReviewFooter =>
      'Se você tem 16 anos ou mais e chegou aqui por engano, fale com o suporte da Divine para que uma pessoa de verdade analise.';

  @override
  String get minorAccountReviewTitle => 'Análise da conta';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Verificando o status da conta...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Aguarde enquanto confirmamos o status atual da análise desta conta.';

  @override
  String get minorAccountReviewDefaultTitle => 'Análise da conta necessária';

  @override
  String get minorAccountReviewDefaultBody =>
      'Precisamos analisar esta conta antes que ela possa usar a Divine normalmente.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'ID do caso: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'ID do caso';

  @override
  String get minorAccountReviewRestrictionsTitle => 'O que está restrito agora';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Postar e publicar estão pausados';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Comentários, curtidas, reposts e seguidas estão pausados';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Iniciar e responder mensagens comuns está pausado';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'O suporte e sua mensagem da moderação continuam disponíveis';

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
      'Abrir a central de suporte';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Abrir a mensagem da moderação';

  @override
  String get minorAccountReviewOpenReviewPage => 'Abrir a página de análise';

  @override
  String get minorAccountReviewCheckAgain => 'Verificar de novo';

  @override
  String get minorAccountReviewLogOut => 'Sair';

  @override
  String get minorAccountReviewNextStepTitle => 'Próximo passo';

  @override
  String get minorAccountReviewNextStepBody =>
      'Abra a central de suporte ou sua mensagem da moderação se precisar de ajuda com esta análise.';

  @override
  String get minorAccountReviewInProgressTitle => 'Análise em andamento';

  @override
  String get minorAccountReviewInProgressBody =>
      'Por enquanto temos o que precisamos. Nossa equipe está analisando este caso antes de devolver o acesso normal à conta.';

  @override
  String get minorAccountReviewUnder13Title => 'Contas de menores de 13';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Se esta conta for de alguém com menos de 13 anos, um pai, mãe ou responsável precisa escrever para $supportEmail informando o ID do caso.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Ainda não podemos te dar uma conta';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'A Divine não foi feita para crianças com menos de 13 anos, e as regras de redes sociais pelo mundo amarram nossas mãos.\n\nMuita coisa na internet empurra você a mentir para conseguir o que quer, e a gente detesta isso. É a lição errada para a vida, e não vamos ensiná-la aqui.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'O que sua família pode fazer no lugar';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Um pai, mãe ou responsável pode ficar com a conta e fazer as postagens — e você pode, sim, aparecer nos vídeos com eles. Queremos que as famílias curtam a Divine do jeito que faz sentido para elas.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Quando você fizer 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Dependendo das regras de onde você mora, talvez dê para voltar e pedir sua própria conta. Nesse caso, se você tiver entre 13 e 15 anos, vai precisar do consentimento de um pai, mãe ou responsável.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Por que a gente não vai só te mandar voltar';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Boa parte da internet é feita para recompensar quem diz o que for preciso para passar pela porteira. A gente não acha isso legal. Sim, você poderia voltar e dizer que é mais velho do que é, mas isso não seria honesto, e a gente não vai te ensinar a mentir para conseguir o que quer.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'A gente quer ajudar os jovens a usar o Divine de formas que sejam saudáveis e positivas para eles e para quem está ao redor. Também precisamos seguir leis que são diferentes em cada lugar. Então, se você tem menos de 13 anos, a resposta é que você não pode ter sua própria conta hoje.';

  @override
  String get minorAccountReviewTeenBody =>
      'Se esta conta for de alguém de 13 a 15 anos, use a mensagem da moderação ou o suporte para seguir as instruções de consentimento dos responsáveis.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Se a conta for de alguém de 13 a 15 anos';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Um pai, mãe ou responsável deve escrever para o suporte da Divine com um vídeo privado curto. Nossa equipe vai analisar e ajudar com os próximos passos.\n\nSe não for possível contatar um pai, mãe ou responsável, ou se isso colocar alguém em risco, escreva para o suporte da Divine e nos conte.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'É uma pausa enquanto a equipe de suporte da Divine analisa o vídeo. Se for aprovado, eles vão te orientar na configuração da nova conta.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Por que pedimos que um pai, mãe ou responsável participe';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'O Divine precisa seguir leis relacionadas à idade em todo o mundo. Também sabemos que a maioria das verificações técnicas de idade é imperfeita. Em vez de fingir que as regras não existem ou que é bacana mentir sobre a idade, queremos que adolescentes e famílias tomem decisões conscientes sobre a melhor forma de usar o Divine. Por isso, para adolescentes de 13 a 15 anos, pedimos que os pais façam parte do processo de criação da conta.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Também precisamos seguir a lei, e essas regras são diferentes dependendo de onde a pessoa mora. Então, em vez de fingir que as regras não existem, pedimos que um pai, mãe ou responsável participe do processo.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'O que o vídeo deve mostrar';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'O adolescente no vídeo';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Um pai, mãe ou responsável falando na câmera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Uma declaração clara de que o adolescente tem entre 13 e 15 anos e tem permissão para usar a Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Uma declaração clara de que o responsável sabe da conta e vai acompanhar o uso';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Como enviar';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Anexe o vídeo ao e-mail para o suporte da Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Mantenha o vídeo privado e não publique no app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Nossa equipe vai analisar e responder com os próximos passos';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Escrever para o suporte da Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Ajuda com a análise do Divine Greenlight (13 a 15 anos)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Olá, suporte da Divine,\n\nestou entrando em contato sobre o Divine Greenlight para um adolescente de 13 a 15 anos.\n\nAnexei um vídeo curto e privado que mostra:\n- o adolescente\n- um pai, mãe ou responsável falando na câmera\n- que o adolescente tem permissão para usar a Divine\n- que o responsável sabe da conta e vai acompanhar o uso\n\nPaís(es) de residência:\n\nContexto útil:\n\nObrigado.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Instruções de suporte para responsáveis';

  @override
  String get minorAccountReviewContinue => 'Continuar';

  @override
  String get minorAccountReviewErrorTitle =>
      'Não conseguimos carregar o status da análise da sua conta.';

  @override
  String get minorAccountReviewErrorBody => 'Tente de novo daqui a pouco.';

  @override
  String get minorAccountReviewTryAgain => 'Tentar de novo';

  @override
  String get minorAccountReviewParentContactTitle => 'Contato do responsável';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Adicione o e-mail de um pai, mãe ou responsável';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Vamos usar este endereço para a análise do consentimento dos responsáveis no caso $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'E-mail do pai, mãe ou responsável';

  @override
  String get minorAccountReviewSubmitting => 'Enviando...';

  @override
  String get minorAccountReviewSubmitEmail => 'Enviar e-mail';

  @override
  String get minorAccountReviewBackToReview => 'Voltar para a análise da conta';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'E-mail enviado';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Enviamos $email para análise. Vamos escrever para esse endereço confirmando. Assim que o responsável responder, seu caso segue em frente. Use Verificar de novo na tela de análise da conta para acompanhar.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Recebemos o contato do responsável por esta conta. Nossa equipe vai analisar antes de devolver o acesso.';

  @override
  String get minorAccountReviewMissingCase =>
      'Não encontramos um caso de análise ativo para esta conta.';

  @override
  String get minorAccountReviewParentContactError =>
      'Não foi possível enviar o e-mail do responsável. Tente de novo.';

  @override
  String get minorAccountReviewUnder13SupportTitle =>
      'Suporte para responsáveis';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Um pai, mãe ou responsável precisa falar com a Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Para contas que provavelmente são de menores de 13 anos, o próximo passo é o contato do responsável por e-mail.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'E-mail do suporte';

  @override
  String get minorAccountReviewCopySupportEmail => 'Copiar e-mail do suporte';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'E-mail do suporte copiado';

  @override
  String get minorAccountReviewCopyCaseId => 'Copiar ID do caso';

  @override
  String get minorAccountReviewCaseIdCopied => 'ID do caso copiado';

  @override
  String get minorAccountReviewUnavailable => 'Indisponível';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Peça ao responsável que inclua o ID do caso e explique que está falando com a Divine sobre esta análise de conta.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Análise de conta de menor de 13 para o caso $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Olá, suporte da Divine,\n\nsou o responsável por uma criança com menos de 13 anos e estou entrando em contato sobre o caso de análise de conta $caseId.\n\nObrigado.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulação de análise de conta de menor';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Estado atual';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Restrito ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Ativo';

  @override
  String get devOptionsMinorReviewStateLoading => 'Carregando...';

  @override
  String get devOptionsMinorReviewStateError => 'Erro ao carregar o estado';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Limpar a substituição da simulação';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Voltar a usar o backend ou o estado ativo padrão';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Simular caso de análise 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Conta restrita com caminho de contato do responsável';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simular caso de suporte de menor de 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Conta restrita com instruções só por e-mail do responsável';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simulação de análise de conta de menor limpa';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Caso simulado de suporte de menor de 13 ativado';

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
      'Simulação de menor protegido';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Estado atual';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Menor protegido (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Não protegido';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Carregando…';

  @override
  String get devOptionsProtectedMinorStateError => 'Erro ao ler o estado';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Sem substituição (estado real da conta)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Substituição: protegido forçado';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Substituição: não protegido forçado';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simular menor protegido (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Force o estado de menor protegido para testar as proteções #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simular pessoa adulta';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Force não protegido (um não explícito, diferente de não ter substituição)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Limpar substituição';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Voltar ao estado real da conta vindo do Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Estado de menor protegido forçado';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Estado de menor protegido desativado';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Substituição de menor protegido limpa';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Convites de cadastro';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Estado atual';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Valor do servidor: carregando';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Valor do servidor: ativado';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Valor do servidor: desativado';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Valor do servidor: desconhecido';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Substituição: usar o valor do servidor';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Substituição: forçar ativado';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Substituição: forçar desativado';

  @override
  String get devOptionsInviteAvailabilityUseServer =>
      'Usar o valor do servidor';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Seguir o onboardingMode do serviço de convites';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Forçar ativado';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Mostrar localmente as travas e a gestão de convites de cadastro';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Forçar desativado';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Ocultar localmente a interface de convites sem mexer no servidor';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Os convites de cadastro agora seguem o servidor';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Convites de cadastro forçados como ativados';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Convites de cadastro forçados como desativados';

  @override
  String get commentsRecordVideoButtonLabel => 'Gravar comentário em vídeo';

  @override
  String get commentsOpenVideoLabel => 'Abrir comentário em vídeo';

  @override
  String get commentsMuteVideoReplyLabel => 'Silenciar resposta em vídeo';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Ativar som da resposta em vídeo';

  @override
  String get commentsOpenReplyParentLabel =>
      'Abrir o vídeo ao qual isto responde';

  @override
  String get commentsReplyParentSectionTitle => 'Em resposta a';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Responder a $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Responder ao vídeo';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Conta $platform verificada: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Contas verificadas';

  @override
  String get profileEditGetVerifiedCta => 'Verifique-se';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Conecte suas redes sociais para que as pessoas saibam que é você mesmo.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Abrir site: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Não foi possível abrir o site';

  @override
  String get videoMetadataEditCoverTitle => 'Editar capa';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Descartar alterações da capa';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Usar o fotograma selecionado como capa do vídeo';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Percorra o vídeo para selecionar o quadro de capa';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Pesquisar ou adicionar tags';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Adiciona tags para que outros descubram o teu vídeo';

  @override
  String get videoMetadataTagsPickerNoResults => 'Sem tags correspondentes';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Adicionar «#$tag»';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Ainda não tem 16 anos? Tudo bem. ';

  @override
  String get authUnder16ChoicesCta => 'Veja suas opções aqui.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'É por isso';

  @override
  String get generalSettingsHoldToRecord => 'Segurar para gravar';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'A gravação começa ao manter pressionado e para ao soltar';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos publicados no seu perfil',
      one: 'Vídeo publicado no seu perfil',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Enviar mensagem';

  @override
  String get emojiPickerSearchHint => 'Pesquisar';

  @override
  String get emojiCategoryRecent => 'Recentes';

  @override
  String get emojiCategorySmileys => 'Smileys e pessoas';

  @override
  String get emojiCategoryAnimals => 'Animais e natureza';

  @override
  String get emojiCategoryFood => 'Comida e bebida';

  @override
  String get emojiCategoryActivities => 'Atividades';

  @override
  String get emojiCategoryTravel => 'Viagens e lugares';

  @override
  String get emojiCategoryObjects => 'Objetos';

  @override
  String get emojiCategorySymbols => 'Símbolos';

  @override
  String get emojiCategoryFlags => 'Bandeiras';

  @override
  String get videoEditorMarkerLabel => 'Marcador';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Adicionar marcador à linha do tempo';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Remover marcador da linha do tempo';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Remover marcador no cursor de reprodução';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Excluir marcador?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Isso remove o marcador da linha do tempo. Sua edição permanece intacta.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Silenciar ou ativar todas as faixas';

  @override
  String get videoEditorSplitFailed => 'Falha na divisão. Tente novamente.';

  @override
  String get videoEditEditSubtitles => 'Editar legendas';

  @override
  String get subtitleEditorTitle => 'Editar legendas';

  @override
  String get subtitleEditorSave => 'Salvar';

  @override
  String get subtitleEditorProcessing =>
      'As legendas ainda estão sendo geradas. Volte daqui a pouco.';

  @override
  String get subtitleEditorNoSpeech =>
      'Nenhuma fala foi detectada neste vídeo, então não há nada para legendar.';

  @override
  String get subtitleEditorWriteOwn => 'Escreva você mesmo';

  @override
  String get subtitleEditorAddCue => 'Adicionar uma linha';

  @override
  String get subtitleEditorRemoveCue => 'Remover esta linha';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'O vídeo não dá para reproduzir agora, mas ainda podes corrigir as legendas.';

  @override
  String get subtitleEditorPlayPreview => 'Reproduzir o vídeo';

  @override
  String get subtitleEditorPausePreview => 'Pausar o vídeo';

  @override
  String get subtitleEditorInvalidHint =>
      'Cada linha precisa de texto e de um fim depois do início.';

  @override
  String get subtitleEditorLoadError =>
      'Não foi possível carregar as legendas. Tente novamente.';

  @override
  String get subtitleEditorSaveSuccess => 'Legendas atualizadas';

  @override
  String get subtitleEditorSaveError =>
      'Não foi possível salvar as legendas. Tente novamente.';

  @override
  String get subtitleEditorRetry => 'Tentar novamente';

  @override
  String get subtitleEditorCueHint => 'Texto da legenda';

  @override
  String get imageCropEditorRotateLabel => 'Girar';

  @override
  String get imageCropEditorFlipLabel => 'Inverter';

  @override
  String get imageCropEditorResetLabel => 'Redefinir';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Cancelar recorte';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Aplicar recorte';

  @override
  String get imageCropEditorProcessing => 'Aplicando recorte…';

  @override
  String get backgroundUploadNotificationTitle => 'Enviando vídeo';

  @override
  String get monetizationSettingsTitle => 'Apoio a criadores';

  @override
  String get monetizationSettingsSubtitle =>
      'Adicione links de gorjeta e assinatura';

  @override
  String get monetizationSettingsIntroTitle => 'Só links externos';

  @override
  String get monetizationSettingsIntroBody =>
      'Adicione destinos que você mesmo controla. A Divine nunca processa o pagamento nem libera conteúdo no app por esses links.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links ativos no seu perfil',
      one: '$count link ativo no seu perfil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Mandar gorjeta';

  @override
  String get monetizationSettingsSubscriptionSection => 'Assinar / apoiar';

  @override
  String get monetizationSettingsSave => 'Salvar links de apoio';

  @override
  String get monetizationSettingsSaving => 'Salvando...';

  @override
  String get monetizationSettingsSaved => 'Links de apoio atualizados';

  @override
  String get monetizationSettingsSaveFailed =>
      'Não foi possível salvar os links de apoio. Verifique sua conexão e tente de novo.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'Adicione um identificador ou URL.';

  @override
  String get monetizationSettingsErrorInvalid => 'Esse link não parece certo.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Use um link deste serviço.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag ou link do cash.app';

  @override
  String get monetizationSettingsHintPayPal =>
      'Identificador ou link do PayPal.me';

  @override
  String get monetizationSettingsHintVenmo => 'Identificador ou link do Venmo';

  @override
  String get monetizationSettingsHintPatreon =>
      'Identificador ou link do Patreon';

  @override
  String get monetizationSettingsHintSubstack => 'Domínio ou link do Substack';

  @override
  String get monetizationSettingsHintMedium =>
      'Identificador ou link do Medium';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Identificador ou link do Open Collective';

  @override
  String get profileSupportSheetTitle => 'Apoiar este criador';

  @override
  String get profileSupportSheetBody =>
      'Estes links abrem fora da Divine. Nada aqui libera conteúdo no app.';

  @override
  String get profileSupportTipSection => 'Mandar gorjeta';

  @override
  String get profileSupportSubscriptionSection => 'Assinar / apoiar';

  @override
  String get profileSupportButtonLabel => 'Apoiar';

  @override
  String get monetizationTipsSettingsTitle => 'Gorjetas';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Adicione links opcionais de gorjeta';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Só gorjetas opcionais';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Gorjetas são presentes opcionais entre pessoas. Elas não liberam conteúdo, assinaturas, recursos, ranking, visibilidade nem acesso na Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links de gorjeta ativos no seu perfil',
      one: '$count link de gorjeta ativo no seu perfil',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Salvar links de gorjeta';

  @override
  String get monetizationTipsSettingsSaved => 'Links de gorjeta atualizados';

  @override
  String get profileTipButtonLabel => 'Gorjeta';

  @override
  String get profileTipSheetTitle => 'Dar gorjeta a este criador';

  @override
  String get profileTipSheetBody =>
      'Os links de gorjeta abrem fora da Divine. São opcionais e não liberam conteúdo, assinaturas, recursos nem acesso na Divine.';

  @override
  String get settingsStorageTitle => 'Armazenamento';

  @override
  String get settingsStorageCacheSectionTitle => 'Mídia em cache';

  @override
  String get settingsStorageCacheDescription =>
      'Vídeos do feed, miniaturas e renderizações temporárias em cache. Limpá-los é seguro: são baixados ou gerados novamente quando necessário.';

  @override
  String get settingsStorageMeasuring => 'Calculando…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size em uso';
  }

  @override
  String get settingsStorageClearButton => 'Limpar cache';

  @override
  String get settingsStorageClearConfirmTitle => 'Limpar mídia em cache?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Isso libera $size. Sua biblioteca de clipes não é afetada.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Limpar';

  @override
  String get settingsStorageCleared => 'Cache limpo';

  @override
  String get settingsStorageLibrarySectionTitle => 'Biblioteca de clipes';

  @override
  String get settingsStorageLibraryDescription =>
      'Verificar clipes quebrados cujo arquivo de vídeo está faltando.';

  @override
  String get settingsStorageScanButton => 'Verificar biblioteca';

  @override
  String get settingsStorageLibraryHealthy =>
      'Nenhum clipe quebrado encontrado';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Clipes quebrados encontrados: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Remover clipes quebrados';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Clipes quebrados removidos';

  @override
  String get settingsStorageError => 'Algo deu errado';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Cache de vídeos máximo';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count vídeos';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Remover clipes quebrados?';

  @override
  String get settingsStorageRepairSectionTitle => 'Reparar instalação';

  @override
  String get settingsStorageRepairDescription =>
      'Se o app trava ou age de forma estranha, redefinir os dados locais costuma resolver. Seus clipes e rascunhos ficam.';

  @override
  String get settingsStorageRepairButton => 'Redefinir dados do app';

  @override
  String get settingsStorageRepairConfirmTitle => 'Redefinir dados do app?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Isso apaga os dados do feed em cache e os arquivos temporários. Seus clipes, rascunhos, configurações e login ficam, mas você terá que reiniciar o app depois.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size serão removidos';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Redefinir';

  @override
  String get settingsStorageRepairInProgress => 'Redefinindo…';

  @override
  String get settingsStorageRepairSuccess =>
      'Pronto — reinicie o app para concluir.';

  @override
  String get settingsStorageRepairFailure =>
      'Não foi possível redefinir tudo. Tente de novo após reiniciar.';

  @override
  String get nostrSettingsSignatureVerification => 'Verificação de assinatura';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Escolha quando o Divine verifica as assinaturas de eventos dos relays. Os IDs de evento são sempre validados primeiro.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Todos os relays';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Mais seguro. Verifique a assinatura de cada evento de relay.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Relays não confiáveis';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Pule as verificações para relays que já estão no seu pool configurado.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Relays que não são Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Confie nos relays Divine, verifique o restante.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle =>
      'Compartilhe seus vídeos em outras plataformas';

  @override
  String get crosspostingSignInRequired =>
      'Entre com o Divine para gerenciar o crossposting';

  @override
  String get crosspostingLoadFailed =>
      'Não deu para carregar suas configurações de crossposting';

  @override
  String get crosspostingNoPlatforms =>
      'Nenhuma plataforma de crossposting está disponível agora';

  @override
  String get crosspostingRetry => 'Tentar novamente';

  @override
  String get crosspostingNotConnected => 'Não conectado';

  @override
  String get crosspostingConnected => 'Conectado';

  @override
  String get crosspostingNeedsReconnect => 'Precisa reconectar';

  @override
  String get crosspostingConnect => 'Conectar';

  @override
  String get crosspostingReconnect => 'Reconectar';

  @override
  String get crosspostingDisconnect => 'Desconectar';

  @override
  String get crosspostingModeOff => 'Desativado';

  @override
  String get crosspostingModeManual => 'Manual';

  @override
  String get crosspostingModeManualSubtitle => 'Você escolhe em cada vídeo';

  @override
  String get crosspostingModeAutomatic => 'Automático';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Os próximos vídeos são publicados sozinhos — só os publicados depois que você ativar isso';

  @override
  String get crosspostingNotConnectedError =>
      'Conecte esta plataforma primeiro para mudar como ela publica.';

  @override
  String get crosspostingGenericError => 'Algo deu errado. Tente de novo.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'A página de login nunca respondeu. Se você terminou de conectar lá, atualize — sua conta pode já estar vinculada.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform conectado';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Não deu para conectar $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'A conexão foi cancelada no $platform';
  }

  @override
  String get supporterTitle => 'Apoiadores do Divine';

  @override
  String get supporterTileSubtitle =>
      'Apoie o Divine com uma assinatura mensal opcional.';

  @override
  String get supporterHeroTitle => 'Mantenha o Divine rodando';

  @override
  String get supporterHeroBody =>
      'O Divine é grátis e sempre será. Se você quiser nos ajudar a manter os loops girando, vire um apoiador mensal. Nada é bloqueado — só mantém as luzes acesas e garante nosso agradecimento.';

  @override
  String get supporterActiveBadge =>
      'Você é um apoiador do Divine. Obrigado por manter isso no ar.';

  @override
  String get supporterPurchasePending =>
      'Sua compra está aguardando aprovação.';

  @override
  String get supporterPurchaseConfirming => 'Confirmando seu apoio…';

  @override
  String get supporterStoreChecking => 'Verificando a loja…';

  @override
  String get supporterUnavailable =>
      'As assinaturas de apoiador não estão disponíveis aqui no momento.';

  @override
  String get supporterRestorePurchases => 'Restaurar compras';

  @override
  String get supporterDismissError => 'Dispensar erro';

  @override
  String get supporterErrorStoreUnavailable =>
      'A loja não está disponível neste dispositivo.';

  @override
  String get supporterErrorPurchaseFailed =>
      'A compra não foi concluída. Você não foi cobrado.';

  @override
  String get supporterErrorPurchasePending =>
      'Sua compra está aguardando aprovação.';

  @override
  String get supporterErrorRestoreFailed =>
      'Nenhuma assinatura de apoiador foi encontrada para restaurar.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Esta compra pertence a outra conta Divine.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'O Divine não conseguiu confirmar o status de apoiador no momento.';

  @override
  String get supporterErrorUnknown => 'Algo deu errado. Tente novamente.';

  @override
  String get supporterDisclaimer =>
      'O Divine confirma o status de apoiador depois que a loja verifica sua compra. O reconhecimento é opcional, e a auréola não é uma verificação.';

  @override
  String get profileNotifyBellOff => 'Avisar sobre novos vines';

  @override
  String get profileNotifyBellOn => 'Parar de avisar sobre novos vines';

  @override
  String get profileNotifyUpdateFailed =>
      'Não foi possível salvar. Tentar de novo?';

  @override
  String get savedSoundYourLabel => 'Sua etiqueta';

  @override
  String get savedSoundAddHashtags => 'Adicionar hashtags';

  @override
  String get savedSoundDeviceOnly => 'Salvo neste aparelho';

  @override
  String get savedSoundDetailsRetry =>
      'Não foi possível salvar esses dados. Toque para tentar de novo.';

  @override
  String get savedSoundFallbackTitle => 'Som salvo';

  @override
  String get savedSoundPreviewAction => 'Ouvir o som';

  @override
  String get savedSoundEditAction => 'Editar dados do som';

  @override
  String get savedSoundRemoveAction => 'Remover som salvo';

  @override
  String get savedSoundClearHashtagFilter => 'Limpar filtro de hashtag';

  @override
  String get soundAllowRemix => 'Permitir que outras pessoas remixem este som';

  @override
  String get soundReuseUnavailable => 'Este som não pode ser remixado agora.';

  @override
  String get soundPublicCredit => 'Crédito público do som';

  @override
  String get soundCreditRequired =>
      'Adicione o crédito público do som antes de publicar.';

  @override
  String get soundSharedAs => 'Compartilhado como';

  @override
  String get soundOwnWork => 'Fui eu que fiz este som';

  @override
  String soundCreatorBy(String creator) {
    return 'Por $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Compartilhado por $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remix permitido';

  @override
  String get soundCreditOnly => 'Só crédito';

  @override
  String get soundCreditTitleLabel => 'Título do som';

  @override
  String get soundCreditCreatorLabel => 'Criador';

  @override
  String get soundCreditSourceUrlLabel => 'URL de origem';

  @override
  String get soundCreditPublicHashtagsLabel => 'Hashtags públicas';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Cancelar seleção de tags';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Aplicar tags selecionadas';

  @override
  String get userPickerCancelSemanticLabel =>
      'Cancelar seleção de utilizadores';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Confirmar utilizadores selecionados';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Limpar seleção de utilizadores';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Cancelar seleção de avisos de conteúdo';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Aplicar avisos de conteúdo selecionados';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Fechar o editor de vídeo';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Continuar para os detalhes da publicação';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Descartar alterações em $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Aplicar alterações em $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Remover áudio';

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
  String get verifyTitle => 'Contas verificadas';

  @override
  String get verifySignedOutMessage => 'Entre para vincular suas contas.';

  @override
  String get verifyIntro =>
      'Vincule as contas que você já tem, assim todo mundo sabe que é você mesmo.';

  @override
  String get verifyLoadFailed => 'Não deu para carregar seus vínculos.';

  @override
  String get verifyRetry => 'Tentar de novo';

  @override
  String get verifyLinkedSectionTitle => 'Vinculadas';

  @override
  String get verifyVerifierUnreachable =>
      'Não conseguimos falar com o verificador, então tudo aparece como não checado.';

  @override
  String get verifyAddSectionTitle => 'Adicionar uma conta';

  @override
  String get verifyAllPlatformsLinked =>
      'Você já vinculou tudo o que a gente suporta.';

  @override
  String get verifyStatusVerified => 'Verificada';

  @override
  String get verifyStatusUnverified => 'Não verificada';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Desvincular a conta $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Desvincular $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity deixa de aparecer no seu perfil. Você pode vincular de novo depois, mas vai precisar entrar na conta ou publicar uma prova nova.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Desvincular';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Vincular sua conta do $platform';
  }

  @override
  String get verifyOneTapBadge => 'Um toque';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Entre no $platform que a gente cuida do resto. Nada é publicado.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Continuar com $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Ou publique uma prova';

  @override
  String get verifyConnectProofExplainer =>
      'Publique seu npub na sua conta e depois cole o link desse post.';

  @override
  String get verifyNpubLabel => 'Seu npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'Copiar seu npub';

  @override
  String get verifyNpubCopied => 'npub copiado';

  @override
  String get verifyIdentityLabel => 'Nome da conta';

  @override
  String get verifyProofLabel => 'Link do seu post';

  @override
  String get verifyConnectProofCta => 'Checar e vincular';

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
      'Verificador fora do ar. Tente de novo daqui a pouco.';

  @override
  String get verifyErrorOauthFailed => 'Não rolou. Tenta mais uma vez.';

  @override
  String get verifyErrorHandleRequired => 'Digite seu handle primeiro.';

  @override
  String get verifyErrorPublishFailed =>
      'Verificada, mas nenhum relay aceitou a atualização. Tente de novo.';

  @override
  String get verifyErrorOauthUnavailable =>
      'O login de um toque ainda não está configurado aqui. Use a prova abaixo.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Crie um gist público com seu npub no primeiro arquivo e cole o link do gist.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Publique seu npub num canal do Discord que nosso bot consiga ler e cole o link da mensagem. Um convite de servidor não prova nada.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tuíte seu npub dessa conta e cole o link do tweet.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Publique seu npub dessa conta e cole o link. O nome da conta precisa da instância — mastodon.social/@alice, não só alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'O canal é que fica vinculado, não sua conta do Telegram. Ele precisa primeiro de um link público (o Telegram cria os novos como privados). Publique seu npub lá e cole o link da mensagem.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Entrou lá em cima? Não precisa de mais nada. Senão publique seu npub e cole o link do post.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Coloque seu npub na legenda de um vídeo e cole o link desse vídeo.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Coloque seu npub na descrição de um vídeo e cole o link desse vídeo.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform está vinculada.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Isso é um canal privado ou um convite. Dê ao canal um link público e depois cole o link da mensagem.';

  @override
  String get verifyErrorRemoveFailed =>
      'Não deu para desvincular. Tente de novo.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Não conseguimos ler seus vínculos atuais, então nada foi alterado. Verifique sua conexão e tente de novo.';

  @override
  String get verifyChannelLabel => 'Nome do canal';

  @override
  String get verifyHowItWorksTitle => 'Como funciona?';

  @override
  String get verifyHowItWorksIntro =>
      'Pense nisso como um aperto de mão entre duas contas:';

  @override
  String get verifyHowItWorksYourSide =>
      'Seu perfil Divine diz: “Sou @alice no Twitter.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Sua conta do Twitter confirma: “Sim, esse perfil Divine é meu.”';

  @override
  String get verifyHowItWorksBothSides =>
      'Verificamos os dois lados. Se baterem, você está verificado. Ninguém consegue forjar: dá para copiar seu nome e sua foto, mas não para postar da sua conta real.';

  @override
  String get verifyHowItWorksOwnership =>
      'Os vínculos ficam na sua própria identidade Nostr, então você pode removê-los aqui quando quiser.';

  @override
  String get generalSettingsSectionIdentity => 'Identidade';

  @override
  String get libraryFilterAll => 'Todos';

  @override
  String get libraryFilterArchive => 'Arquivo';

  @override
  String get libraryFilterDeleted => 'Excluídos';

  @override
  String get libraryCategoryNewChipLabel => 'Nova';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Criar uma categoria';

  @override
  String get libraryCategoryCreateTitle => 'Nova categoria';

  @override
  String get libraryCategoryCreateAction => 'Criar';

  @override
  String get libraryCategoryRenameTitle => 'Renomear categoria';

  @override
  String get libraryCategoryRenameAction => 'Renomear';

  @override
  String get libraryCategoryDeleteAction => 'Excluir categoria';

  @override
  String get libraryCategoryNameLabel => 'Nome da categoria';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Excluir “$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Seus clipes continuam aqui. Eles só voltam para Todos.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Renomear ou excluir esta categoria';

  @override
  String get libraryCategoryMoveTitle => 'Mover para';

  @override
  String get libraryCategoryMoveNone => 'Sem categoria';

  @override
  String get libraryCategoryMoveNewCategory => 'Nova categoria';

  @override
  String get libraryArchiveAction => 'Arquivar';

  @override
  String get libraryUnarchiveAction => 'Desarquivar';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Manter nestas categorias?',
      one: 'Manter nesta categoria?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Manter em $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'Manter nas suas categorias';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Remover de $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Remover das suas categorias';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Mover os clipes selecionados';

  @override
  String get libraryCategoryEmptyTitle => 'Ainda não tem nada aqui';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Escolha alguns clipes e mova para esta categoria.';

  @override
  String get libraryArchiveEmptyTitle => 'Nada arquivado';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Os clipes arquivados ficam aqui, fora da sua biblioteca principal.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes movidos para $name',
      one: '$count clipe movido para $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes fora da categoria',
      one: '$count clipe fora da categoria',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes arquivados',
      one: '$count clipe arquivado',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes de volta na biblioteca',
      one: '$count clipe de volta na biblioteca',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Alterar e-mail';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Leve sua conta para outro endereço';

  @override
  String get accountSettingsChangePassword => 'Alterar senha';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Escolha uma nova senha para entrar';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Sua sessão expirou. Entre de novo para fazer essa alteração.';

  @override
  String get accountCredentialsRateLimited =>
      'Tentativas demais. Espere alguns minutos.';

  @override
  String get accountCredentialsNetwork =>
      'Não deu para falar com a Divine. Confira sua conexão e tente de novo.';

  @override
  String get accountCredentialsUnknown => 'Não funcionou. Tente de novo.';

  @override
  String get changePasswordSubtitle =>
      'Digite sua senha atual e escolha uma nova.';

  @override
  String get changePasswordCurrentLabel => 'Senha atual';

  @override
  String get changePasswordWrongCurrent => 'Essa não é a sua senha atual.';

  @override
  String get changePasswordSuccess => 'Senha alterada.';

  @override
  String get changeEmailSubtitle =>
      'Vamos enviar um link de confirmação para o novo endereço e para o da sua conta. Seu e-mail muda quando você confirmar nos dois.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Na sua conta: $email';
  }

  @override
  String get changeEmailNewLabel => 'Novo e-mail';

  @override
  String get changeEmailPasswordLabel => 'Sua senha';

  @override
  String get changeEmailSameAsCurrent => 'Esse já é o seu endereço de e-mail.';

  @override
  String get changeEmailWrongPassword => 'Essa não é a sua senha.';

  @override
  String get changeEmailSubmit => 'Enviar links de confirmação';

  @override
  String get changeEmailSentTitle => 'Dois links estão a caminho';

  @override
  String changeEmailSentMessage(String email) {
    return 'Confirme em $email e no endereço da sua conta. Seu e-mail muda quando os dois estiverem prontos.';
  }

  @override
  String get changeEmailSentExpiry => 'Os links expiram em 24 horas.';

  @override
  String get changeEmailSentDone => 'Entendi';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount vídeos',
      one: '$formattedCount vídeo',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Mútuo';

  @override
  String get socialProofFollowsYou => 'Segue você';

  @override
  String get socialProofYouFollow => 'Você segue';

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
      'Os vídeos não estão carregando.\nO problema é nosso, não seu — já estamos resolvendo.';

  @override
  String get feedOfflineMessage =>
      'Você está offline.\nVerifique sua conexão e tente de novo.';

  @override
  String get dbFailureTitle =>
      'não foi possível desbloquear seu banco de dados local';

  @override
  String get dbFailureAdviceResettable =>
      'Reiniciar não vai resolver. Redefinir o banco de dados local abaixo dá ao Divine um começo limpo — sua conta permanece.';

  @override
  String get dbFailureAdviceRestart =>
      'Reinicie o Divine depois de desbloquear seu dispositivo. Se continuar acontecendo, atualize o app ou fale com o suporte.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Tente reiniciar o Divine uma vez. Se isso continuar acontecendo, atualize o app ou entre em contato com o suporte. Seus dados locais continuam aqui.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnóstico: $code';
  }

  @override
  String get dbFailureCloseApp => 'fechar o Divine';

  @override
  String get dbFailureResetAction => 'redefinir banco de dados local';

  @override
  String get dbFailureConfirmTitle => 'redefinir seu banco de dados local?';

  @override
  String get dbFailureConfirmBody =>
      'Sua conta permanece. Rascunhos e clipes salvos neste dispositivo são excluídos — mensagens e feeds voltam da rede.';

  @override
  String get dbFailureResetConfirm => 'redefinir banco de dados local agora';

  @override
  String get dbFailureCancel => 'cancelar';

  @override
  String get dbFailureResetFailed =>
      'Isso não funcionou. Feche o Divine e tente de novo.';

  @override
  String get dbFailureResetDoneTitle => 'banco de dados local redefinido';

  @override
  String get dbFailureResetDoneBody =>
      'Feche o Divine e abra de novo — a próxima inicialização cria um banco de dados local novo.';

  @override
  String get authSignInOptionsInfo => 'Sobre as opções de login';

  @override
  String get authShowPassword => 'Mostrar senha';

  @override
  String get authHidePassword => 'Ocultar senha';

  @override
  String get followUserSemanticLabel => 'Seguir usuário';

  @override
  String get unfollowUserSemanticLabel => 'Deixar de seguir usuário';

  @override
  String get commentsLoadingSemanticLabel => 'Carregando comentários';

  @override
  String get analyticsWindowAll => 'Tudo';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Seguir usuário $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Deixar de seguir usuário $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / mês';
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
      'Uma nova atualização acabou de chegar. Confira →';

  @override
  String get updateModerateTitle =>
      'Há uma atualização desde a última vez que você verificou';

  @override
  String get updateUrgentTitle => 'Você está sem correções importantes';

  @override
  String get updateNotNow => 'Agora não';

  @override
  String get updateAction => 'Atualizar';

  @override
  String updateNewIn(String version) {
    return 'Novidades na versão $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Atualização disponível';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get devOptionsClipRecovery => '片段恢复';

  @override
  String get devOptionsClipRecoveryDescription =>
      '查找存储在其他账号下的录制内容，以及已无任何记录引用的视频文件。';

  @override
  String get devOptionsClipRecoveryScan => '扫描';

  @override
  String get devOptionsClipRecoveryFailure => '片段恢复失败';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    return '当前可见：$clips 个片段，$drafts 个草稿';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => '隐藏在其他账号下';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    return '$clips 个片段，$drafts 个草稿';
  }

  @override
  String get devOptionsClipRecoveryClaim => '移至此账号';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return '无引用的文件：$count 个（$size）';
  }

  @override
  String get devOptionsClipRecoveryImport => '在库中重建';

  @override
  String get devOptionsClipRecoveryEmpty => '没有可恢复的内容';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    return '已恢复 $count 个片段';
  }

  @override
  String get devOptionsClipRecoveryCopied => '已复制恢复报告';

  @override
  String get devOptionsStorageFootprint => '存储占用';

  @override
  String get devOptionsStorageFootprintDescription =>
      '应用写入的所有目录。清除缓存只能释放其中一部分。';

  @override
  String get devOptionsStorageFootprintMeasure => '测量';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return '共计：$size';
  }

  @override
  String get devOptionsStorageFootprintCopied => '已复制存储报告';

  @override
  String get devOptionsStorageFootprintFailure => '无法测量存储占用';

  @override
  String get feedTuningMoreLabel => '更多这类内容';

  @override
  String get feedTuningLessLabel => '少看这类内容';

  @override
  String get feedTuningUndo => '撤销';

  @override
  String get dmMessageBubbleVideoReplyHint => '打开引用的视频';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSecureAccount => '保护你的账号';

  @override
  String get settingsSessionExpired => '登录已过期';

  @override
  String get settingsSessionExpiredSubtitle => '重新登录即可恢复完整访问权限';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => '创作者数据';

  @override
  String get settingsSupportCenter => '帮助中心';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsBlueskyPublishing => 'Bluesky 发布';

  @override
  String get settingsBlueskyPublishingSubtitle => '管理同步到 Bluesky 的跨平台发布';

  @override
  String get settingsNostrSettings => 'Nostr 设置';

  @override
  String get settingsIntegratedApps => '集成应用';

  @override
  String get settingsIntegratedAppsSubtitle => '获准在 Divine 内运行的第三方应用';

  @override
  String get settingsExperimentalFeatures => '实验性功能';

  @override
  String get settingsExperimentalFeaturesSubtitle => '可能会偶尔抽风的小调整，好奇就试试看。';

  @override
  String get settingsLegal => '法律信息';

  @override
  String get settingsIntegrationPermissions => '集成权限';

  @override
  String get settingsIntegrationPermissionsSubtitle => '查看并撤销已记住的集成授权';

  @override
  String settingsVersion(String version) {
    return '版本 $version';
  }

  @override
  String get settingsVersionEmpty => '版本';

  @override
  String get settingsDeveloperModeAlreadyEnabled => '开发者模式已开启';

  @override
  String get settingsDeveloperModeEnabled => '开发者模式开启啦！';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '再点 $count 次即可开启开发者模式';
  }

  @override
  String get settingsShareDivine => '与朋友分享 Divine';

  @override
  String get settingsSwitchAccount => '切换账号';

  @override
  String get settingsAddAnotherAccount => '添加其他账号';

  @override
  String get settingsAccountSwitchFailed => '切换账号失败，请重试。';

  @override
  String get settingsUnsavedDraftsTitle => '未保存的草稿';

  @override
  String get settingsUploadInProgressTitle => '正在上传';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '视频',
      one: '视频',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '视频会作为草稿留在这个账号里',
      one: '视频会作为草稿留在这个账号里',
    );
    return '你还有 $count 个$_temp0正在上传。切换账号会中断上传——$_temp1。';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '草稿',
      one: '草稿',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '草稿',
      one: '草稿',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '它们',
      one: '它',
    );
    return '你有 $count 条未保存的$_temp0。切换账号会保留你的$_temp1，但建议先把$_temp2发布或检查一下。';
  }

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsSwitchAnyway => '仍然切换';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      '该账号的登录状态已过期。重新登录它意味着要退出你现在使用的账号。';

  @override
  String get settingsAppVersionLabel => '应用版本';

  @override
  String get settingsAppLanguage => '应用语言';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language（系统默认）';
  }

  @override
  String get settingsAppLanguageTitle => '应用语言';

  @override
  String get settingsAppLanguageDescription => '选择应用界面使用的语言';

  @override
  String get settingsAppLanguageUseDeviceLanguage => '跟随系统语言';

  @override
  String get settingsGeneralTitle => '通用设置';

  @override
  String get settingsContentSafetyTitle => '内容与安全';

  @override
  String get generalSettingsSectionIntegrations => '集成';

  @override
  String get generalSettingsSectionViewing => '观看';

  @override
  String get generalSettingsSectionCreating => '创作';

  @override
  String get generalSettingsSectionApp => '应用';

  @override
  String get appearanceSettingsTitle => '外观';

  @override
  String get appearanceSettingsSubtitle => '选择 Divine 在这台设备上的样子';

  @override
  String get appearanceSettingsSystem => '跟随系统';

  @override
  String get appearanceSettingsLight => '浅色';

  @override
  String get appearanceSettingsDark => '深色';

  @override
  String get generalSettingsClosedCaptions => '隐藏字幕';

  @override
  String get generalSettingsClosedCaptionsSubtitle => '视频带字幕时自动显示';

  @override
  String get generalSettingsVideoShapeSquareOnly => '仅方形视频';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle => '让信息流保持经典方形格式';

  @override
  String get contentPreferencesTitle => '内容偏好';

  @override
  String get contentPreferencesContentFilters => '内容过滤';

  @override
  String get contentPreferencesContentFiltersSubtitle => '管理内容警告过滤';

  @override
  String get contentPreferencesContentLanguage => '内容语言';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language（系统默认）';
  }

  @override
  String get contentPreferencesTagYourVideos => '给你的视频标上语言，方便观众筛选内容。';

  @override
  String get contentPreferencesUseDeviceLanguage => '跟随系统语言（默认）';

  @override
  String get contentPreferencesAudioSharing => '允许他人二次使用我的音频';

  @override
  String get contentPreferencesAudioSharingSubtitle => '开启后，其他人可以使用你视频中的音频';

  @override
  String get contentPreferencesMusicMode => '音乐模式';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      '关掉会压扁乐器声的降噪处理。更适合音乐，人声会糙一点。';

  @override
  String get contentPreferencesAccountLabels => '账号标签';

  @override
  String get contentPreferencesAccountLabelsEmpty => '为自己的内容打标签';

  @override
  String get contentPreferencesAccountContentLabels => '账号内容标签';

  @override
  String get contentPreferencesClearAll => '全部清除';

  @override
  String get contentPreferencesSelectAllThatApply => '选择所有适用于你账号的标签';

  @override
  String get contentPreferencesDoneNoLabels => '完成（未选标签）';

  @override
  String contentPreferencesDoneCount(int count) {
    return '完成（已选 $count 个）';
  }

  @override
  String get contentPreferencesAudioInputDevice => '音频输入设备';

  @override
  String get contentPreferencesAutoRecommended => '自动（推荐）';

  @override
  String get contentPreferencesAutoSelectsBest => '自动选择最佳麦克风';

  @override
  String get contentPreferencesSelectAudioInput => '选择音频输入';

  @override
  String get contentPreferencesUnknownMicrophone => '未知麦克风';

  @override
  String get contentFiltersAdultContent => '成人内容';

  @override
  String get contentFiltersViolenceGore => '暴力与血腥';

  @override
  String get contentFiltersSubstances => '酒精与药物';

  @override
  String get contentFiltersOther => '其他';

  @override
  String get contentFiltersAgeGateMessage => '在“安全与隐私”设置中完成年龄验证，即可解锁成人内容过滤';

  @override
  String get contentFiltersShow => '显示';

  @override
  String get contentFiltersWarn => '提醒';

  @override
  String get contentFiltersFilterOut => '过滤';

  @override
  String get profileBlockedAccountNotAvailable => '该账号不可用';

  @override
  String get profileInvalidId => '无效的个人资料 ID';

  @override
  String profileShareText(String displayName, String npub) {
    return '快来 Divine 看看 $displayName！\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine 上的 $displayName';
  }

  @override
  String get profileShareFailed => '分享主页失败，请重试。';

  @override
  String get profileCopyPublicKey => '复制公钥（npub）';

  @override
  String get profileGetEmbedCode => '获取嵌入代码';

  @override
  String get profilePublicKeyCopied => '公钥已复制到剪贴板';

  @override
  String get profileEmbedCodeCopied => '嵌入代码已复制到剪贴板';

  @override
  String get profileMoreTooltip => '更多';

  @override
  String get profileMoreSemanticLabel => '更多选项';

  @override
  String get profileAvatarLightboxBarrierLabel => '关闭头像';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => '关闭头像预览';

  @override
  String get profileFollowingLabel => '已关注';

  @override
  String get profileFollowLabel => '关注';

  @override
  String get profileBlockedLabel => '已屏蔽';

  @override
  String get profileFollowersLabel => '粉丝';

  @override
  String get profileFollowingStatLabel => '关注';

  @override
  String get profileVideosLabel => '视频';

  @override
  String get profileCollabsLabel => '合作';

  @override
  String get profileLikedLabel => '已点赞';

  @override
  String get profileRepostsLabel => '转发';

  @override
  String get profileListsLabel => '列表';

  @override
  String get profileCommentsLabel => '评论';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 个合作邀请待发送',
      one: '还有 1 个合作邀请待发送',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail => '邀请还在队列里，点这里重试。';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return '《$title》。点这里重试。';
  }

  @override
  String get profileCollaboratorInviteRetryAction => '重试';

  @override
  String get profileCollaboratorInviteRetryingAction => '重试中';

  @override
  String get profileCollaboratorInviteRetryUnavailable => '暂时无法重试合作邀请。';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 个合作邀请待发送。',
      one: '还有 1 个合作邀请待发送。',
      zero: '合作邀请已全部发送。',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位协作者无法接收邀请。',
      one: '1 位协作者无法接收邀请。',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count 位用户';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '屏蔽 $displayName？';
  }

  @override
  String get profileBlockExplanation => '屏蔽用户后：';

  @override
  String get profileBlockBulletHidePosts => '对方的帖子不会出现在你的信息流中。';

  @override
  String get profileBlockBulletCantView => '对方将无法查看你的主页、关注你或查看你的帖子。';

  @override
  String get profileBlockBulletNoNotify => '对方不会收到此操作的通知。';

  @override
  String get profileBlockBulletYouCanView => '你仍可查看对方的主页。';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '屏蔽 $displayName';
  }

  @override
  String get profileCancelButton => '取消';

  @override
  String get profileLearnMore => '了解更多';

  @override
  String profileUnblockTitle(String displayName) {
    return '取消屏蔽 $displayName？';
  }

  @override
  String get profileUnblockExplanation => '取消屏蔽该用户后：';

  @override
  String get profileUnblockBulletShowPosts => '对方的帖子会重新出现在你的信息流中。';

  @override
  String get profileUnblockBulletCanView => '对方将能够查看你的主页、关注你并查看你的帖子。';

  @override
  String get profileUnblockBulletNoNotify => '对方不会收到此操作的通知。';

  @override
  String get profileLearnMoreAt => '了解更多：';

  @override
  String get profileUnblockButton => '取消屏蔽';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '取消关注 $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '屏蔽 $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '取消屏蔽 $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '举报 $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '把 $displayName 加入列表';
  }

  @override
  String get profileNoCollabsTitle => '还没有合作';

  @override
  String get profileCollabsOwnEmpty => '你参与合作的视频会显示在这里。';

  @override
  String get profileCollabsOtherEmpty => 'TA 参与合作的视频会显示在这里。';

  @override
  String get profileErrorLoadingCollabs => '加载合作视频出错';

  @override
  String get profileNoSavedVideosTitle => '还没有收藏';

  @override
  String get profileSavedOwnEmpty => '在分享面板里收藏视频，就会显示在这里。';

  @override
  String get profileErrorLoadingSaved => '加载收藏视频出错';

  @override
  String get profileNoCommentsOwnTitle => '还没有评论';

  @override
  String get profileNoCommentsOtherTitle => '还没有评论';

  @override
  String get profileCommentsOwnEmpty => '你的评论和回复会显示在这里。';

  @override
  String get profileCommentsOtherEmpty => 'TA 的评论和回复会显示在这里。';

  @override
  String get profileErrorLoadingComments => '加载评论出错';

  @override
  String get profileVideoRepliesSection => '视频回复';

  @override
  String get profileCommentsSection => '评论';

  @override
  String get profileEditLabel => '编辑';

  @override
  String get profileLibraryLabel => '作品库';

  @override
  String get profileNoLikedVideosTitle => '还没有点赞';

  @override
  String get profileLikedOwnEmpty => '看到心动的内容就点个爱心，你的点赞会显示在这里。';

  @override
  String get profileLikedOtherEmpty => '还没有内容打动 TA，再等等吧。';

  @override
  String get profileErrorLoadingLiked => '加载点赞视频出错';

  @override
  String get profileNoRepostsTitle => '还没有转发';

  @override
  String get profileRepostsOwnEmpty => '看到值得分享的内容？转发一下，它就会出现在这里。';

  @override
  String get profileRepostsOtherEmpty => 'TA 还没有转发过内容，转发后会显示在这里。';

  @override
  String get profileErrorLoadingReposts => '加载转发视频出错';

  @override
  String get profileNoVideosTitle => '还没有视频';

  @override
  String get profileNoVideosOwnSubtitle => '舞台已经搭好，开始发布吧，你的视频会在这里安家。';

  @override
  String get profileNoVideosOtherSubtitle => '全世界都在等。关注 TA，就不会错过。';

  @override
  String profileVideoThumbnailLabel(int number) {
    return '视频缩略图 $number';
  }

  @override
  String get profileShowMore => '显示更多';

  @override
  String get profileShowLess => '收起';

  @override
  String get dmMessageDisplayLimitReached => '此消息的其余部分不会显示。';

  @override
  String get profileCompleteYourProfile => '完善你的资料';

  @override
  String get profileCompleteSubtitle => '添加名字、简介和头像，马上开始';

  @override
  String get profilePleaseTryAgain => '请重试';

  @override
  String get profileSecureYourAccount => '保护你的账号';

  @override
  String get profileSecureSubtitle => '添加邮箱和密码，即可在任意设备上找回账号';

  @override
  String get profileRetryButton => '重试';

  @override
  String get profileSessionExpired => '登录已过期';

  @override
  String get profileSignInToRestore => '重新登录即可恢复完整访问权限';

  @override
  String get profileSignInButton => '登录';

  @override
  String get profileMaybeLaterLabel => '以后再说';

  @override
  String get profileSecurePrimaryButton => '添加邮箱和密码';

  @override
  String get profileCompletePrimaryButton => '更新你的资料';

  @override
  String get profileLoopsLabel => '循环';

  @override
  String get profileLikesLabel => '点赞';

  @override
  String get profileMyLibraryLabel => '我的作品库';

  @override
  String get profileMessageLabel => '私信';

  @override
  String get profileShareLabel => '分享主页';

  @override
  String get profileDeletedAccountName => '已注销账号';

  @override
  String get inboxActionReportVanishedAccount => '举报此账号';

  @override
  String get inboxActionBlockVanishedAccount => '屏蔽此账号';

  @override
  String get inboxActionUnblockVanishedAccount => '取消屏蔽此账号';

  @override
  String get inboxReportedVanishedAccount => '已举报此账号';

  @override
  String get inboxBlockedVanishedAccount => '已屏蔽此账号';

  @override
  String get inboxUnblockedVanishedAccount => '已取消屏蔽此账号';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      '这会从你的收件箱中移除这段会话。如果对方再次给你发消息，会开始一个新会话。';

  @override
  String get inboxConversationDeletedAccountSubtitle => '该账号已注销';

  @override
  String get profileUserFallback => '用户';

  @override
  String get profileLinkCopied => '主页链接已复制';

  @override
  String get profileSetupEditProfileTitle => '编辑资料';

  @override
  String get nostrSettingsNip05ProfileRequired => '添加 NIP-05 地址前，请先设置个人资料。';

  @override
  String get nostrSettingsNip05CreateProfileAction => '创建个人资料';

  @override
  String get profileSetupBackLabel => '返回';

  @override
  String get profileSetupAboutNostr => '关于 Nostr';

  @override
  String get profileSetupProfilePublished => '资料发布成功！';

  @override
  String get profileSetupUnsavedChangesTitle => '保存更改？';

  @override
  String get profileSetupUnsavedChangesSubtitle => '离开前保存你的修改，或者放弃它们继续。';

  @override
  String get profileSetupUnsavedChangesSaveButton => '保存更改';

  @override
  String get profileSetupUnsavedChangesDiscardButton => '放弃更改';

  @override
  String get profileSetupUnsavedChangesKeepButton => '继续编辑';

  @override
  String get profileSetupCreateNewProfile => '创建新资料？';

  @override
  String get profileSetupNoExistingProfile =>
      '我们没有在你的中继上找到已有资料。发布会创建一份新资料，继续吗？';

  @override
  String get profileSetupPublishButton => '发布';

  @override
  String get profileSetupUsernameTaken => '用户名刚被抢注了，请换一个。';

  @override
  String get profileSetupClaimFailed => '注册用户名失败，请重试。';

  @override
  String get profileSetupPublishFailed => '发布资料失败，请重试。';

  @override
  String get profileSetupNoRelaysConnected => '无法连接网络。请检查连接后重试。';

  @override
  String get profileSetupDisplayNameLabel => '昵称';

  @override
  String get profileSetupDisplayNameRequired => '请输入昵称';

  @override
  String get profileSetupBioLabel => '简介（可选）';

  @override
  String get profileSetupWebsiteLabel => '网站（可选）';

  @override
  String get profileSetupPublicKeyLabel => '公钥（npub）';

  @override
  String get profileSetupUsernameLabel => '用户名（可选）';

  @override
  String get profileSetupUsernameHelper =>
      '请使用字母、数字或连字符。你的用户名会成为 divine.video 地址。空格或符号请用在显示名称中。';

  @override
  String get profileSetupSaveButton => '保存';

  @override
  String get profileSetupSavingButton => '保存中...';

  @override
  String get profileSetupImageUrlTitle => '添加图片链接';

  @override
  String get profileSetupImageSelectionFailed => '选择图片失败，请在下方粘贴图片链接。';

  @override
  String get profileSetupImagesTypeGroup => '图片';

  @override
  String get cameraPickErrorPermissionDenied => '相机权限已关闭，请在设置中开启后拍照。';

  @override
  String get cameraPickErrorPermissionRestricted => '此设备不允许访问相机。';

  @override
  String get cameraPickErrorBusy => '选择器已经打开，请关闭后重试。';

  @override
  String get cameraPickErrorGeneric => '无法打开相机，请重试。';

  @override
  String get profileSetupGotItButton => '知道了';

  @override
  String get profileSetupUploadFailedGeneric => '上传失败，请稍后重试。';

  @override
  String get profileSetupUploadNetworkError => '网络错误：请检查网络连接后重试。';

  @override
  String get profileSetupUploadAuthError => '认证错误：请退出登录后重新登录。';

  @override
  String get profileSetupUploadFileTooLarge => '文件过大：请选择更小的图片（最大 10MB）。';

  @override
  String get profileSetupUploadServerError => '上传失败。我们的服务器暂时开小差了，请稍后再试。';

  @override
  String get profileSetupBannerClearButton => '清除头图';

  @override
  String get profileSetupBannerChangeColor => '横幅颜色';

  @override
  String get profileSetupChangeBannerTitle => '更改横幅';

  @override
  String get profileSetupBannerColorPickerTitle => '更改横幅颜色';

  @override
  String get profileSetupBannerColorCustom => '自定义';

  @override
  String get profileSetupBannerColorNone => '无颜色';

  @override
  String get profileSetupBannerColorLime => '青柠色';

  @override
  String get profileSetupBannerColorYellow => '黄色';

  @override
  String get profileSetupBannerColorViolet => '紫罗兰色';

  @override
  String get profileSetupBannerColorPink => '粉色';

  @override
  String get profileSetupBannerColorOrange => '橙色';

  @override
  String get profileSetupBannerColorPurple => '紫色';

  @override
  String get profileSetupAvatarClearButton => '移除照片';

  @override
  String get profileSetupImageTakePhoto => '拍照';

  @override
  String get profileSetupImageUploadFromCameraRoll => '从相册上传';

  @override
  String get profileSetupImagePasteLink => '粘贴图片链接';

  @override
  String get profileSetupEditAvatarLabel => '编辑头像';

  @override
  String get profileSetupEditBannerLabel => '编辑横幅';

  @override
  String get profileSetupUsernameChecking => '正在检查可用性...';

  @override
  String get profileSetupUsernameAvailable => '用户名可用！';

  @override
  String get profileSetupUsernameTakenIndicator => '用户名已被占用';

  @override
  String get profileSetupUsernameReserved => '该用户名已被保留';

  @override
  String get profileSetupContactSupport => '联系客服';

  @override
  String get profileSetupCheckAgain => '再查一次';

  @override
  String get profileSetupUsernameBurned => '该用户名已不可用';

  @override
  String get profileSetupUsernameInvalidFormat => '仅允许字母、数字和连字符';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement => '用户名不能以连字符开头或结尾';

  @override
  String get profileSetupUsernameInvalidLength => '用户名长度须为 3-63 个字符';

  @override
  String get profileSetupUsernameNetworkError => '无法检查可用性，请重试。';

  @override
  String get profileSetupUsernameInvalidFormatGeneric => '用户名格式无效';

  @override
  String get profileSetupUsernameCheckFailed => '检查可用性失败';

  @override
  String get profileSetupUsernameReservedTitle => '用户名已被保留';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return '$username 这个名称已被保留。告诉我们它为什么应该属于你。';
  }

  @override
  String get profileSetupUsernameReservedHint => '例如：这是我的品牌名、艺名等。';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      '已经联系过客服？点“再查一次”看看是否已经释放给你。';

  @override
  String get profileSetupSupportRequestSent => '请求已发送！我们会尽快回复你。';

  @override
  String get profileSetupCouldntOpenEmail => '无法打开邮箱。请发送至：names@divine.video';

  @override
  String get profileSetupSendRequest => '发送请求';

  @override
  String get profileSetupUseOwnNip05 => '使用你自己的 NIP-05 地址';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 地址';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'NIP-05 格式无效（例如 name@domain.com）';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'divine.video 请使用上方的用户名输入框';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 地址';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      '使用你的 divine.video 用户名，或将你的昵称指向你自己控制的域名上的 NIP-05 地址。';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => '保存 NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 已保存';

  @override
  String get nostrSettingsNip05SaveFailed => '无法保存 NIP-05，请重试。';

  @override
  String get profileSetupNip05ConfirmTitle => '使用自己的 NIP-05？';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 会把 you@yourdomain.com 这样的名称映射到你的 Nostr 身份。你需要控制该域名，并在正确的路径托管验证文件。如果配置有误，别人会找不到你，你的认证昵称也会消失。请确认已设置好再继续。';

  @override
  String get profileSetupNip05ConfirmContinue => '继续';

  @override
  String get profileSetupNip05ConfirmCancel => '取消';

  @override
  String get profileSetupProfilePicturePreview => '头像预览';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine 构建于 Nostr 之上，';

  @override
  String get nostrInfoIntroDescription => ' 一个抗审查的开放协议，让人们在网上交流时不必依赖某一家公司或平台。';

  @override
  String get nostrInfoIntroIdentity => '注册 Divine 时，你会获得一个全新的 Nostr 身份。';

  @override
  String get nostrInfoOwnership =>
      'Nostr 让你拥有自己的内容、身份和社交图谱，可以跨多个应用使用。这意味着更多选择、更少锁定，以及一个更健康、更有韧性的社交互联网。';

  @override
  String get nostrInfoLingo => 'Nostr 黑话：';

  @override
  String get nostrInfoNpubLabel => 'npub：';

  @override
  String get nostrInfoNpubDescription =>
      ' 你的 Nostr 公开地址。可以放心分享，别人可以通过它在各个 Nostr 应用里找到你、关注你或给你发消息。';

  @override
  String get nostrInfoNsecLabel => 'nsec：';

  @override
  String get nostrInfoNsecDescription => ' 你的私钥，也是所有权证明。它能完全控制你的 Nostr 身份，所以';

  @override
  String get nostrInfoNsecWarning => '一定要保密！';

  @override
  String get nostrInfoUsernameLabel => 'Nostr 用户名：';

  @override
  String get nostrInfoUsernameDescription =>
      ' 一个可读的名字（比如 @name.divine.video），指向你的 npub。它让你的 Nostr 身份更容易识别和验证，类似邮箱地址。';

  @override
  String get nostrInfoLearnMoreAt => '了解更多：';

  @override
  String get nostrInfoGotIt => '知道了！';

  @override
  String get videoGridRefreshLabel => '正在寻找更多视频';

  @override
  String get videoGridOptionsTitle => '视频选项';

  @override
  String get videoGridEditVideo => '编辑视频';

  @override
  String get videoGridEditVideoSubtitle => '更新标题、简介和话题标签';

  @override
  String get videoGridDeleteVideo => '删除视频';

  @override
  String get videoGridDeleteVideoSubtitle =>
      '从 Divine 删除此视频。它可能仍会出现在其他 Nostr 客户端上。';

  @override
  String get videoGridDeletingContent => '正在删除内容...';

  @override
  String get exploreTabFeatured => '精选';

  @override
  String get exploreTabClassics => '经典';

  @override
  String get exploreTabNew => '最新';

  @override
  String get exploreTabPopular => '热门';

  @override
  String get exploreTabCategories => '分类';

  @override
  String get exploreTabForYou => '为你推荐';

  @override
  String get exploreTabLists => '列表';

  @override
  String get exploreTabIntegratedApps => '集成应用';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => '这里还没有内容。稍后再来看看。';

  @override
  String get featuredTabLoadFailed => '无法加载此合集。';

  @override
  String get featuredTabRetry => '重试';

  @override
  String get exploreNoVideosAvailable => '暂无视频';

  @override
  String get exploreDiscoverLists => '发现列表';

  @override
  String get exploreAboutLists => '关于列表';

  @override
  String get exploreAboutListsDescription => '列表帮你用两种方式整理和策划 Divine 内容：';

  @override
  String get explorePeopleLists => '人物列表';

  @override
  String get explorePeopleListsDescription => '关注一群创作者，查看他们的最新视频';

  @override
  String get exploreVideoLists => '视频列表';

  @override
  String get exploreVideoListsDescription => '把喜欢的视频做成播放列表，稍后观看';

  @override
  String get exploreMyLists => '我的列表';

  @override
  String get exploreSubscribedLists => '订阅的列表';

  @override
  String get exploreErrorLoadingLists => '加载列表出错，请重试。';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条新视频',
      one: '1 条新视频',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '视频',
      one: '视频',
    );
    return '加载 $count 条新$_temp0';
  }

  @override
  String get videoPlayerPlayVideo => '播放视频';

  @override
  String get videoPlayerMute => '视频静音';

  @override
  String get videoPlayerUnmute => '取消静音';

  @override
  String get videoPlayerTapHint => '点按播放或暂停，双击点赞。';

  @override
  String get videoSettingsMenuOpen => '打开播放设置';

  @override
  String get videoSettingsMenuClose => '关闭播放设置';

  @override
  String get videoSettingsCaptionsEnable => '开启字幕';

  @override
  String get videoSettingsCaptionsDisable => '关闭字幕';

  @override
  String get videoSettingsAutoAdvanceOn => '自动连播已开启';

  @override
  String get videoSettingsAutoAdvanceOff => '自动连播已关闭';

  @override
  String get videoSettingsCaptionsOn => '字幕已开启';

  @override
  String get videoSettingsCaptionsOff => '字幕已关闭';

  @override
  String get videoSettingsCaptionsOnForVideo => '已为此视频开启字幕';

  @override
  String get videoSettingsCaptionsOffForVideo => '已为此视频关闭字幕';

  @override
  String get contentWarningLabel => '内容警告';

  @override
  String get contentWarningNudity => '裸露';

  @override
  String get contentWarningSexualContent => '性内容';

  @override
  String get contentWarningPornography => '色情内容';

  @override
  String get contentWarningGraphicMedia => '引人不适画面';

  @override
  String get contentWarningViolence => '暴力';

  @override
  String get contentWarningSelfHarm => '自残';

  @override
  String get contentWarningDrugUse => '药物滥用';

  @override
  String get contentWarningAlcohol => '酒精';

  @override
  String get contentWarningTobacco => '烟草';

  @override
  String get contentWarningGambling => '赌博';

  @override
  String get contentWarningProfanity => '粗口';

  @override
  String get contentWarningFlashingLights => '闪烁灯光';

  @override
  String get contentWarningAiGenerated => 'AI 生成';

  @override
  String get contentWarningSpoiler => '剧透';

  @override
  String get contentWarningSensitiveContent => '敏感内容';

  @override
  String get contentWarningDescNudity => '包含裸露或半裸内容';

  @override
  String get contentWarningDescSexual => '包含性内容';

  @override
  String get contentWarningDescPorn => '包含露骨色情内容';

  @override
  String get contentWarningDescGraphicMedia => '包含血腥或令人不安的画面';

  @override
  String get contentWarningDescViolence => '包含暴力内容';

  @override
  String get contentWarningDescSelfHarm => '提及自残内容';

  @override
  String get contentWarningDescDrugs => '包含毒品相关内容';

  @override
  String get contentWarningDescAlcohol => '包含酒精相关内容';

  @override
  String get contentWarningDescTobacco => '包含烟草相关内容';

  @override
  String get contentWarningDescGambling => '包含赌博相关内容';

  @override
  String get contentWarningDescProfanity => '包含粗俗语言';

  @override
  String get contentWarningDescFlashingLights => '包含闪烁灯光（光敏性警告）';

  @override
  String get contentWarningDescAiGenerated => '该内容由 AI 生成';

  @override
  String get contentWarningDescSpoiler => '包含剧透';

  @override
  String get contentWarningDescContentWarning => '创作者将其标记为敏感内容';

  @override
  String get contentWarningDescDefault => '创作者标记了该内容';

  @override
  String get contentWarningDetailsTitle => '内容警告';

  @override
  String get contentWarningDetailsSubtitle => '创作者添加了以下标签：';

  @override
  String get contentWarningManageFilters => '管理内容过滤';

  @override
  String get contentWarningViewAnyway => '仍然查看';

  @override
  String get contentWarningReportContentTooltip => '举报内容';

  @override
  String get contentWarningBlockUserTooltip => '屏蔽用户';

  @override
  String get contentWarningBlockedTitle => '内容已屏蔽';

  @override
  String get contentWarningBlockedPolicy => '该内容因违反平台政策已被屏蔽。';

  @override
  String get contentWarningNoticeTitle => '内容提示';

  @override
  String get contentWarningPotentiallyHarmfulTitle => '潜在有害内容';

  @override
  String get contentWarningView => '查看';

  @override
  String get contentWarningReportAction => '举报';

  @override
  String get contentWarningHideAllLikeThis => '隐藏所有类似内容';

  @override
  String get contentWarningNoFilterYet => '此警告还没有已保存的过滤设置。';

  @override
  String get contentWarningHiddenConfirmation => '从现在开始，我们会隐藏这类帖子。';

  @override
  String get communitySuggestTitle => '帮忙分类一下';

  @override
  String get communitySuggestSubtitle => '缺少内容警告？你的建议会公开并签名，且无法撤回。';

  @override
  String get communitySuggestSubmit => '提交建议';

  @override
  String get communitySuggestSuccess => '谢谢，你的建议已发送。';

  @override
  String get communitySuggestFailure => '建议发送失败，请重试。';

  @override
  String get communitySuggestAlready => '你已建议过此项';

  @override
  String get communitySuggestActionLabel => '分类';

  @override
  String get videoErrorNotFound => '找不到视频';

  @override
  String get videoErrorPlayback => '视频播放出错';

  @override
  String get videoErrorAgeRestricted => '年龄限制内容';

  @override
  String get videoErrorUnavailable => '视频不可用';

  @override
  String get videoErrorUnavailableBody => '此视频目前不可用。';

  @override
  String get videoErrorRetry => '重试';

  @override
  String get videoErrorContentRestricted => '内容受限';

  @override
  String get videoErrorContentRestrictedBody => '该视频因违反我们的内容规则已被移除。';

  @override
  String get videoErrorVerifyAgeBody => '验证年龄后即可观看此视频。';

  @override
  String get videoErrorSkip => '跳过';

  @override
  String get videoErrorVerifyAgeButton => '验证年龄';

  @override
  String get videoErrorVerifyAgeFailed => '无法验证你的年龄，请重试。';

  @override
  String get videoErrorVerifyAgeSignerUnreachable => '验证超时。请检查网络连接，或稍后再试。';

  @override
  String get videoErrorAdultContentHiddenTitle => '成人内容已关闭';

  @override
  String get videoErrorAdultContentHiddenBody => '在内容过滤中开启后就能看这个视频了。';

  @override
  String get videoErrorAdultContentHiddenAction => '打开内容过滤';

  @override
  String get videoDetailLoadError => '视频加载失败';

  @override
  String get videoDetailLoadErrorBody => '路上出了点岔子，再试一次吧。';

  @override
  String get videoDetailNotFoundBody => '可能被删了，可能够不到，也可能被你的设置隐藏了。';

  @override
  String get databaseCorruptionTitle => '你的本地数据乱套了';

  @override
  String get databaseCorruptionBody =>
      '关掉 Divine 再重新打开——我们会自动修补。草稿和片段能救多少救多少，其他内容都会重新加载。';

  @override
  String get databaseCorruptionCloseButton => '关闭 Divine';

  @override
  String get videoDetailContextTitle => '分享的视频';

  @override
  String get videoDetailCloseSemanticLabel => '关闭视频播放器';

  @override
  String get videoFollowButtonFollow => '关注';

  @override
  String get audioAttributionOriginalSound => '原声';

  @override
  String get audioAttributionUnavailableSound => '声音不可用';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '灵感来自 @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '灵感来自 @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '与 @$name 合作';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '与 @$name +$count 人合作';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位协作者',
      one: '1 位协作者',
    );
    return '$_temp0。点按查看主页。';
  }

  @override
  String get videoCollaboratorPendingDecoration => '待确认';

  @override
  String get videoCollaboratorPendingSemanticLabel => '待确认的协作者';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label（$pending 位待确认）';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name。点按查看主页。';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag。点按查看该话题标签下的视频。';
  }

  @override
  String get listAttributionFallback => '列表';

  @override
  String get shareVideoLabel => '分享视频';

  @override
  String sharePostSharedWith(String recipientName) {
    return '已分享给 $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已分享给 $count 个人',
      one: '已分享给 $count 个人',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => '视频发送失败';

  @override
  String get shareAddedToBookmarks => '已加入收藏';

  @override
  String get shareRemovedFromBookmarks => '已从收藏移除';

  @override
  String get shareFailedToAddBookmark => '加入收藏失败';

  @override
  String get shareFailedToRemoveBookmark => '移除收藏失败';

  @override
  String get shareActionFailed => '操作失败';

  @override
  String get shareWithTitle => '分享给';

  @override
  String get shareFindPeople => '找人';

  @override
  String get shareFindPeopleMultiline => '寻找\n朋友';

  @override
  String get shareSent => '已发送';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '已选择 $name';
  }

  @override
  String get shareMessageHint => '附上一句话（可选）...';

  @override
  String get videoActionUnlike => '取消点赞视频';

  @override
  String get videoActionLike => '点赞视频';

  @override
  String get videoActionAutoLabel => '合集';

  @override
  String get videoActionLikeLabel => '点赞';

  @override
  String get videoActionReplyLabel => '回复';

  @override
  String get videoActionRepostLabel => 'Revine';

  @override
  String get videoActionShareLabel => '分享';

  @override
  String get videoActionReportLabel => '举报';

  @override
  String get videoActionReport => '举报视频';

  @override
  String get videoActionEditLabel => '编辑';

  @override
  String get videoActionEdit => '编辑视频';

  @override
  String get videoActionAboutLabel => '关于';

  @override
  String get videoActionEnableAutoAdvance => '开启自动连播';

  @override
  String get videoActionDisableAutoAdvance => '关闭自动连播';

  @override
  String get videoActionRemoveRepost => '取消转发';

  @override
  String get videoActionRepost => '转发视频';

  @override
  String get videoActionViewComments => '查看评论';

  @override
  String get videoActionMoreOptions => '更多选项';

  @override
  String get videoEngagementLikersTitle => '点赞的人';

  @override
  String get videoEngagementRepostersTitle => '转发的人';

  @override
  String get videoEngagementLikersEmpty => '还没有点赞';

  @override
  String get videoEngagementRepostersEmpty => '还没有转发';

  @override
  String get videoEngagementLoadFailed => '列表加载失败';

  @override
  String get videoOverlayOpenMetadataFromTitle => '打开视频详情';

  @override
  String get videoOverlayOpenMetadataFromDescription => '打开视频详情';

  @override
  String get videoOverlayCommentBarHint => '说点什么...';

  @override
  String get videoOverlayCommentBarSemanticLabel => '添加评论';

  @override
  String get videoOverlayCommentBarSendLabel => '发送评论';

  @override
  String get videoOverlayCommentPostedSnackbar => '评论已发布';

  @override
  String get videoOverlayCommentPostFailedSnackbar => '评论发布失败';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次循环',
      one: '次循环',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => '非 Divine';

  @override
  String get metadataBadgeHumanMade => '人类创作';

  @override
  String get metadataSoundsLabel => '声音';

  @override
  String get metadataOriginalSound => '原声';

  @override
  String get metadataVerificationLabel => '验证';

  @override
  String get metadataDeviceAttestation => '设备证明';

  @override
  String get metadataPgpSignature => 'PGP 签名';

  @override
  String get metadataC2paCredentials => 'C2PA 内容凭证';

  @override
  String get metadataProofManifest => '证明清单';

  @override
  String get metadataVerificationInfoTooltip => '这些检查是什么意思？';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section。$question';
  }

  @override
  String get metadataVerificationInfoTitle => '这些检查的含义';

  @override
  String get metadataVerificationInfoIntro =>
      '这些信号来自摄像头和视频文件本身。一个视频带的信号越多，我们能证明的来源信息就越多。';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      '手机操作系统为录制这段视频的应用作了担保。这有力地表明它来自摄像头，而不是别人上传的文件。';

  @override
  String get metadataVerificationInfoPgpSignature =>
      '视频在拍摄的那一刻就完成了加密签名。之后哪怕只改动一帧，签名就会失效。';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      '随文件一同携带的行业标准来源记录——所以 Divine 之外的应用也能验证。';

  @override
  String get metadataVerificationInfoProofManifest =>
      '完整的 ProofMode 记录：文件指纹、时间戳和拍摄环境信息，与视频打包在一起。';

  @override
  String get metadataVerificationInfoFootnote =>
      '缺少某项检查并不代表视频是假的。较早的片段和上传的视频本来就没有——这只说明我们无法证明那一部分。';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return '了解更多：$url';
  }

  @override
  String get metadataCreatorLabel => '创作者';

  @override
  String get metadataCollaboratorsLabel => '协作者';

  @override
  String get metadataInspiredByLabel => '灵感来自';

  @override
  String get metadataRepostedByLabel => '转发自';

  @override
  String metadataMoreReposters(int count) {
    return '还有 $count 人';
  }

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '次循环',
      one: '次循环',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => '点赞';

  @override
  String get metadataCommentsLabel => '评论';

  @override
  String get metadataRepostsLabel => '转发';

  @override
  String get metadataVineStatsLabel => 'Vine 上';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops 次循环 · $likes 次点赞 · $comments 条评论 · $reposts 次转发';
  }

  @override
  String get metadataDivineStatsLabel => 'Divine 上';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views 次观看 · $likes 次点赞 · $comments 条评论 · $reposts 次转发';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return '发布于 $date';
  }

  @override
  String get devOptionsTitle => '开发者选项';

  @override
  String get devOptionsDisableDeveloperMode => '关闭开发者模式';

  @override
  String get devOptionsDisableDeveloperModeSubtitle => '在设置中隐藏开发者选项';

  @override
  String get devOptionsDisableDeveloperModeToast => '开发者模式已关闭';

  @override
  String get devOptionsShorebirdTitle => 'Shorebird 补丁';

  @override
  String get devOptionsShorebirdPatchLabel => '当前补丁';

  @override
  String get devOptionsShorebirdNoPatch => '未安装补丁';

  @override
  String get devOptionsShorebirdUnavailable => '此构建版本不可用';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      '补丁仅适用于通过 shorebird release 创建的构建版本。';

  @override
  String get devOptionsShorebirdLoading => '正在读取补丁状态…';

  @override
  String get devOptionsShorebirdNotChecked => '尚未检查预发布通道。';

  @override
  String get devOptionsShorebirdCheck => '检查预发布通道';

  @override
  String get devOptionsShorebirdApply => '应用预发布补丁';

  @override
  String get devOptionsShorebirdUseStable => '恢复稳定版更新';

  @override
  String get devOptionsShorebirdChecking => '正在检查预发布通道…';

  @override
  String get devOptionsShorebirdUpdateAvailable => '有预发布补丁可供应用。';

  @override
  String get devOptionsShorebirdUpToDate => '此版本没有预发布补丁。';

  @override
  String get devOptionsShorebirdRestartRequired => '已下载。请重启应用以加载补丁。';

  @override
  String get devOptionsShorebirdRollbackRequired => '回滚已准备就绪。请重启以返回基础版本。';

  @override
  String get devOptionsShorebirdApplying => '正在下载并安装…';

  @override
  String get devOptionsShorebirdApplied => '已安装。请重启应用以加载补丁。';

  @override
  String get devOptionsShorebirdUnchanged => '未安装任何内容。请检查预发布通道后重试。';

  @override
  String get devOptionsShorebirdSelectingStableTrack => '正在选择稳定版通道…';

  @override
  String get devOptionsShorebirdStableRestored => '已选择稳定版通道。请重启应用以检查稳定版补丁。';

  @override
  String get devOptionsShorebirdFailure => '操作失败。请查看日志了解详情。';

  @override
  String get devOptionsPageLoadTimes => '页面加载时间';

  @override
  String get devOptionsNoPageLoads => '还没有记录到页面加载。\n在应用里逛逛，就能看到计时数据。';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return '可见：${visibleMs}ms  |  数据：${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => '最慢的页面';

  @override
  String get devOptionsVideoPlaybackFormat => '视频播放格式';

  @override
  String get devOptionsSwitchEnvironmentTitle => '切换环境？';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '切换到 $envName？\n\n这会清除已缓存的视频数据，并重新连接到新的中继。';
  }

  @override
  String get devOptionsCancel => '取消';

  @override
  String get devOptionsSwitch => '切换';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '已切换到 $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '已切换到 $formatName——缓存已清除';
  }

  @override
  String get featureFlagTitle => '功能开关';

  @override
  String get featureFlagResetAllTooltip => '将所有开关重置为默认值';

  @override
  String get featureFlagError => '错误';

  @override
  String get relaySettingsTitle => '中继';

  @override
  String get relaySettingsInfoTitle => 'Divine 是开放系统——连接由你掌控';

  @override
  String get relaySettingsInfoDescription =>
      '这些中继在去中心化的 Nostr 网络上分发你的内容。你可以随意添加或移除中继。';

  @override
  String get relaySettingsLearnMoreNostr => '了解 Nostr 的更多信息 →';

  @override
  String get relaySettingsFindPublicRelays => '在 nostr.co.uk 上寻找公共中继 →';

  @override
  String get relaySettingsAppNotFunctional => '应用无法运行';

  @override
  String get relaySettingsRequiresRelay => 'Divine 至少需要一个中继才能加载视频、发布内容和同步数据。';

  @override
  String get relaySettingsRestoreDefaultRelay => '恢复默认中继';

  @override
  String get relaySettingsAddCustomRelay => '添加自定义中继';

  @override
  String get relaySettingsAddRelay => '添加中继';

  @override
  String get relaySettingsRetry => '重试';

  @override
  String get relaySettingsNoStats => '暂无统计数据';

  @override
  String get relaySettingsConnection => '连接';

  @override
  String get relaySettingsConnected => '已连接';

  @override
  String get relaySettingsDisconnected => '已断开';

  @override
  String get relaySettingsSessionDuration => '会话时长';

  @override
  String get relaySettingsLastConnected => '上次连接';

  @override
  String get relaySettingsDisconnectedLabel => '已断开';

  @override
  String get relaySettingsReason => '原因';

  @override
  String get relaySettingsActiveSubscriptions => '活跃订阅';

  @override
  String get relaySettingsTotalSubscriptions => '订阅总数';

  @override
  String get relaySettingsEventsReceived => '已接收事件';

  @override
  String get relaySettingsEventsSent => '已发送事件';

  @override
  String get relaySettingsRequestsThisSession => '本次会话请求数';

  @override
  String get relaySettingsFailedRequests => '失败请求';

  @override
  String get relaySettingsLoadingRelayInfo => '正在加载中继信息...';

  @override
  String get relaySettingsAboutRelay => '关于中继';

  @override
  String get relaySettingsSupportedNips => '支持的 NIP';

  @override
  String get relaySettingsSoftware => '软件';

  @override
  String get relaySettingsViewWebsite => '查看网站';

  @override
  String get relaySettingsRemoveRelayTitle => '移除中继？';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return '确定要移除此中继吗？\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => '移除 Divine 中继？';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return '移除 Divine 的中继会让应用体验变差。视频、发布和同步可能变得不太可靠。建议只有熟悉 Nostr 的用户才这么做。\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => '移除中继';

  @override
  String get relaySettingsCancel => '取消';

  @override
  String get relaySettingsRemove => '移除';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return '已移除中继：$relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => '移除中继失败';

  @override
  String get relaySettingsForcingReconnection => '正在强制重新连接中继...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '已连接 $count 个中继！';
  }

  @override
  String get relaySettingsFailedToConnectCheck => '连接中继失败。请检查网络连接。';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      '已保存在此设备上。发布恢复正常后，我们会将它同步到你的账号。';

  @override
  String get relaySettingsAddRelayTitle => '添加中继';

  @override
  String get relaySettingsAddRelayPrompt => '输入要添加的中继 WebSocket URL：';

  @override
  String get relaySettingsBrowsePublicRelays => '在 nostr.co.uk 浏览公共中继';

  @override
  String get relaySettingsAdd => '添加';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return '已添加中继：$relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay => '添加中继失败。请检查 URL 后重试。';

  @override
  String get relaySettingsInvalidUrl => '中继 URL 必须以 wss:// 或 ws:// 开头';

  @override
  String get relaySettingsInsecureUrl =>
      '中继 URL 必须使用 wss://（仅 localhost 允许 ws://）';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return '已恢复默认中继：$defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault => '恢复默认中继失败。请检查网络连接。';

  @override
  String get relaySettingsCouldNotOpenBrowser => '无法打开浏览器';

  @override
  String get relaySettingsFailedToOpenLink => '打开链接失败';

  @override
  String get relaySettingsExternalRelay => '外部中继';

  @override
  String get relaySettingsNotConnected => '未连接';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return '已在 $duration 前断开';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count 个订阅';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count 个事件';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration 前';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine 使用 Nostr 协议进行去中心化发布。你的内容存放在你自己选择的中继上，你的密钥就是你的身份。';

  @override
  String get nostrSettingsSectionNetwork => '网络';

  @override
  String get nostrSettingsSectionAccount => '账号';

  @override
  String get nostrSettingsSectionDangerZone => '危险区';

  @override
  String get nostrSettingsRelays => '中继';

  @override
  String get nostrSettingsRelaysSubtitle => '管理 Nostr 中继连接';

  @override
  String get nostrSettingsRelayDiagnostics => '中继诊断';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle => '排查中继连接和网络问题';

  @override
  String get nostrSettingsMediaServers => '媒体服务器';

  @override
  String get nostrSettingsMediaServersSubtitle => '配置 Blossom 上传服务器';

  @override
  String get settingsDeveloperOptions => '开发者选项';

  @override
  String get settingsDeveloperOptionsSubtitle => '环境切换和调试设置';

  @override
  String get nostrSettingsKeyManagement => '密钥管理';

  @override
  String get nostrSettingsKeyManagementSubtitle => '导出、备份和恢复你的 Nostr 密钥';

  @override
  String get nostrSettingsClientAttribution => '客户端署名';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      '在你发布的事件上附带 Divine 客户端标记，方便其他 Nostr 应用正确识别来源。没有它，你提交的举报在我们审核时的权重会更低。';

  @override
  String get nostrSettingsMoveAccount => '迁移你的账号';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      '下载你的归档，并将帖子和视频迁移到另一个中继或媒体服务器。';

  @override
  String get nostrSettingsRemoveKeys => '从此设备移除此账号';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      '从此设备移除此账号的本地登录。此账号的本地草稿和片段仍会保留。';

  @override
  String get nostrSettingsCouldNotRemoveKeys => '无法从此设备移除此账号，请重试。';

  @override
  String get nostrSettingsDeleteAccount => '删除账号和数据';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      '为你的内容发送删除请求，并在此设备上退出登录。中继、客户端、搜索索引和其他已登录设备可能仍会保留副本。';

  @override
  String get relayDiagnosticTitle => '中继诊断';

  @override
  String get relayDiagnosticRefreshTooltip => '刷新诊断';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return '上次刷新：$time';
  }

  @override
  String get relayDiagnosticRelayStatus => '中继状态';

  @override
  String get relayDiagnosticInitialized => '已初始化';

  @override
  String get relayDiagnosticReady => '就绪';

  @override
  String get relayDiagnosticNotInitialized => '未初始化';

  @override
  String get relayDiagnosticDatabaseEvents => '数据库事件';

  @override
  String get relayDiagnosticActiveSubscriptions => '活跃订阅';

  @override
  String get relayDiagnosticExternalRelays => '外部中继';

  @override
  String get relayDiagnosticConfigured => '已配置';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count 个中继';
  }

  @override
  String get relayDiagnosticConnectedLabel => '已连接';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => '视频事件';

  @override
  String get relayDiagnosticHomeFeed => '首页信息流';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count 个视频';
  }

  @override
  String get relayDiagnosticDiscovery => '发现';

  @override
  String get relayDiagnosticLoading => '加载中';

  @override
  String get relayDiagnosticYes => '是';

  @override
  String get relayDiagnosticNo => '否';

  @override
  String get relayDiagnosticTestDirectQuery => '测试直接查询';

  @override
  String get relayDiagnosticNetworkConnectivity => '网络连接';

  @override
  String get relayDiagnosticRunNetworkTest => '运行网络测试';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom 服务器';

  @override
  String get relayDiagnosticTestAllEndpoints => '测试所有端点';

  @override
  String get relayDiagnosticStatus => '状态';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => '错误';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => '基础 URL';

  @override
  String get relayDiagnosticSummary => '摘要';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount 正常（平均 ${avgMs}ms）';
  }

  @override
  String get relayDiagnosticRetestAll => '全部重测';

  @override
  String get relayDiagnosticRetrying => '重试中...';

  @override
  String get relayDiagnosticRetryConnection => '重试连接';

  @override
  String get relayDiagnosticTroubleshooting => '故障排查';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• 绿色状态 = 已连接且正常\n• 红色状态 = 连接失败\n• 如果网络测试失败，请检查网络连接\n• 如果中继已配置但未连接，点“重试连接”\n• 截图此页面以便调试';

  @override
  String get relayDiagnosticAllEndpointsHealthy => '所有 REST 端点都健康！';

  @override
  String get relayDiagnosticSomeEndpointsFailed => '部分 REST 端点失败——详见上文';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '在数据库中找到 $count 个视频事件';
  }

  @override
  String get relayDiagnosticQueryFailed => '查询失败，请重试。';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '已连接 $count 个中继！';
  }

  @override
  String get relayDiagnosticFailedToConnect => '无法连接到任何中继';

  @override
  String get relayDiagnosticConnectionRetryFailed => '连接重试失败，请重试。';

  @override
  String get relayDiagnosticConnectedAuthenticated => '已连接并完成认证';

  @override
  String get relayDiagnosticConnectedOnly => '已连接';

  @override
  String get relayDiagnosticNotConnected => '未连接';

  @override
  String get relayDiagnosticNoRelaysConfigured => '未配置中继';

  @override
  String get relayDiagnosticFailed => '失败';

  @override
  String get notificationSettingsTitle => '通知';

  @override
  String get notificationSettingsResetTooltip => '重置为默认';

  @override
  String get notificationSettingsTypes => '通知类型';

  @override
  String get notificationSettingsLikes => '点赞';

  @override
  String get notificationSettingsLikesSubtitle => '当有人点赞你的视频时';

  @override
  String get notificationSettingsComments => '评论';

  @override
  String get notificationSettingsCommentsSubtitle => '当有人评论你的视频时';

  @override
  String get notificationSettingsFollows => '关注';

  @override
  String get notificationSettingsFollowsSubtitle => '当有人关注你时';

  @override
  String get notificationSettingsMentions => '提及';

  @override
  String get notificationSettingsMentionsSubtitle => '当有人提到你时';

  @override
  String get notificationSettingsReposts => '转发';

  @override
  String get notificationSettingsRepostsSubtitle => '当有人转发你的视频时';

  @override
  String get notificationSettingsNewPosts => '新视频';

  @override
  String get notificationSettingsNewPostsSubtitle => '当你关注的人发布内容时';

  @override
  String get notificationSettingsActions => '操作';

  @override
  String get notificationSettingsMarkAllAsRead => '全部标为已读';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle => '将所有通知标记为已读';

  @override
  String get notificationSettingsAllMarkedAsRead => '所有通知已标为已读';

  @override
  String get notificationSettingsMarkAllAsReadFailed => '全部标为已读失败';

  @override
  String get notificationSettingsResetToDefaults => '设置已重置为默认值';

  @override
  String get notificationSettingsAbout => '关于通知';

  @override
  String get notificationSettingsAboutDescription =>
      '通知由 Nostr 协议驱动。实时更新取决于你与 Nostr 中继的连接，部分通知可能会有延迟。';

  @override
  String get safetySettingsWhatYouSee => '你看到的内容';

  @override
  String get safetySettingsWhatYouPublish => '你发布的内容';

  @override
  String get safetySettingsShowDivineHostedOnly => '只显示 Divine 托管的视频';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle => '隐藏来自其他媒体托管的视频';

  @override
  String get safetySettingsModeration => '内容管理';

  @override
  String get safetySettingsBlockedUsers => '已屏蔽用户';

  @override
  String get safetySettingsAgeVerification => '年龄验证';

  @override
  String get safetySettingsAgeConfirmation => '我确认我已年满 18 岁';

  @override
  String get safetySettingsAgeRequired => '查看成人内容前必须完成验证';

  @override
  String get safetySettingsAgeLockedForMinor => '你的账号已锁定此项';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle => '官方内容管理服务（默认开启）';

  @override
  String get safetySettingsPeopleIFollow => '我关注的人';

  @override
  String get safetySettingsPeopleIFollowSubtitle => '订阅你关注的人给出的标签';

  @override
  String get safetySettingsAddCustomLabeler => '添加自定义标记服务';

  @override
  String get safetySettingsAddCustomLabelerHint => '输入 npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => '添加自定义标记服务';

  @override
  String get safetySettingsRemoveLabeler => '移除标记服务';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => '输入 npub 地址';

  @override
  String get safetySettingsNoBlockedUsers => '没有已屏蔽的用户';

  @override
  String get safetySettingsUnblock => '取消屏蔽';

  @override
  String get safetySettingsUserUnblocked => '已取消屏蔽';

  @override
  String get safetySettingsCancel => '取消';

  @override
  String get safetySettingsAdd => '添加';

  @override
  String get analyticsTitle => '创作者数据';

  @override
  String get analyticsDiagnosticsTooltip => '诊断';

  @override
  String get analyticsDiagnosticsSemanticLabel => '切换诊断显示';

  @override
  String get analyticsRetry => '重试';

  @override
  String get analyticsUnableToLoad => '无法加载数据。';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired => '登录后即可查看创作者数据。';

  @override
  String get analyticsViewDataUnavailable =>
      '这些帖子的观看数据暂时无法从中继获取。点赞/评论/转发数据仍然准确。';

  @override
  String get analyticsViewDataTitle => '观看数据';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return '更新于 $time • 分数使用点赞、评论、转发以及 Funnelcake 提供的观看/循环数据（如有）。';
  }

  @override
  String get analyticsVideos => '视频';

  @override
  String get analyticsViews => '观看';

  @override
  String get analyticsInteractions => '互动';

  @override
  String get analyticsEngagement => '互动';

  @override
  String get analyticsFollowers => '粉丝';

  @override
  String get analyticsAvgPerPost => '平均每帖';

  @override
  String get analyticsInteractionMix => '互动构成';

  @override
  String get analyticsLikes => '点赞';

  @override
  String get analyticsComments => '评论';

  @override
  String get analyticsReposts => '转发';

  @override
  String get analyticsPerformanceHighlights => '表现亮点';

  @override
  String get analyticsMostViewed => '观看最多';

  @override
  String get analyticsMostDiscussed => '讨论最多';

  @override
  String get analyticsMostReposted => '转发最多';

  @override
  String get analyticsNoVideosYet => '还没有视频';

  @override
  String get analyticsViewDataUnavailableShort => '观看数据不可用';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count 次观看';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count 条评论';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count 次转发';
  }

  @override
  String get analyticsTopContent => '热门内容';

  @override
  String get analyticsPublishPrompt => '发布几条视频后就能看到排名。';

  @override
  String get analyticsEngagementRateExplainer => '右侧百分比 = 互动率（互动数除以观看数）。';

  @override
  String get analyticsEngagementRateNoViews => '互动率需要观看数据；在拿到观看数据前会显示为 N/A。';

  @override
  String get analyticsEngagementLabel => '互动';

  @override
  String get analyticsViewsUnavailable => '观看数据不可用';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count 次互动';
  }

  @override
  String get analyticsPostAnalytics => '帖子数据';

  @override
  String get analyticsOpenPost => '打开帖子';

  @override
  String get analyticsRecentDailyInteractions => '近期每日互动';

  @override
  String get analyticsNoActivityYet => '该时间段内还没有活动。';

  @override
  String get analyticsDailyInteractionsExplainer =>
      '互动 = 按发布日期统计的点赞 + 评论 + 转发。';

  @override
  String get analyticsDailyBarExplainer => '条形长度相对于该时间段内你最高的一天。';

  @override
  String get analyticsAudienceSnapshot => '受众概览';

  @override
  String analyticsFollowersCount(String count) {
    return '粉丝：$count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return '关注：$count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      '等 Funnelcake 增加受众分析端点后，这里会显示受众来源/地区/时间分布。';

  @override
  String get analyticsRetention => '留存';

  @override
  String get analyticsRetentionWithViews =>
      '等 Funnelcake 提供按秒/按分段的留存数据后，这里会显示留存曲线和观看时长分布。';

  @override
  String get analyticsRetentionWithoutViews =>
      '在 Funnelcake 返回观看+观看时长数据前，留存数据不可用。';

  @override
  String get analyticsDiagnostics => '诊断';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return '视频总数：$count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return '有观看数据：$count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return '缺观看数据：$count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return '已补全（批量）：$count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return '已补全（/views）：$count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return '来源：$sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => '使用示例数据';

  @override
  String get analyticsNa => '不适用';

  @override
  String get authCreateNewAccount => '创建新的 Divine 账号';

  @override
  String get authCreateNewAccountShort => '创建新账号';

  @override
  String get authSignInDifferentAccount => '使用已有账号登录';

  @override
  String get authUseAnotherAccount => '使用其他账号';

  @override
  String authContinueAs(String displayName) {
    return '以 $displayName 的身份继续';
  }

  @override
  String get authRecoveryDraftsOwner => '你的草稿和片段都保存在此账号下';

  @override
  String get authRecoveryOtherAccountWarning => '在这里登录会隐藏那些草稿和片段';

  @override
  String get authTermsPrefix => '选择下方任一选项，即表示你确认自己已满 16 周岁（或已完成 ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine 年龄授权';

  @override
  String get authTermsAfterAgeAuthorization => '），并同意';

  @override
  String get authTermsOfService => '服务条款';

  @override
  String get authPrivacyPolicy => '隐私政策';

  @override
  String get authTermsAnd => '，以及';

  @override
  String get authSafetyStandards => '安全准则';

  @override
  String get authAmberNotInstalled => '未安装 Amber 应用';

  @override
  String get authAmberConnectionFailed => '连接 Amber 失败';

  @override
  String get authPasswordResetSent => '如果该邮箱已注册账号，密码重置链接已发送。';

  @override
  String get authSignInTitle => '登录';

  @override
  String get authEmailLabel => '邮箱';

  @override
  String get authPasswordLabel => '密码';

  @override
  String get authConfirmPasswordLabel => '确认密码';

  @override
  String get authEmailRequired => '请输入邮箱';

  @override
  String get authEmailInvalid => '请输入有效的邮箱地址';

  @override
  String get authPasswordRequired => '请输入密码';

  @override
  String get authConfirmPasswordRequired => '请确认你的密码';

  @override
  String get authPasswordsDoNotMatch => '两次输入的密码不一致';

  @override
  String get authForgotPassword => '忘记密码？';

  @override
  String get authImportNostrKey => '导入 Nostr 密钥';

  @override
  String get authConnectSignerApp => '连接签名应用';

  @override
  String get authSignInWithAmber => '使用 Amber 登录';

  @override
  String get authSignInWithBrowserExtension => '使用浏览器扩展登录';

  @override
  String get authNip07ConnectionFailed => '无法连接你的浏览器扩展。';

  @override
  String get authNip07ExtensionNotFound =>
      '未找到浏览器扩展。请安装 Alby、nos2x 或其他兼容 NIP-07 的扩展。';

  @override
  String get authSignInOptionsTitle => '登录选项';

  @override
  String get authInfoEmailPasswordTitle => '邮箱和密码';

  @override
  String get authInfoEmailPasswordDescription =>
      '使用你的 Divine 账号登录。如果你注册时用了邮箱和密码，在这里输入。';

  @override
  String get authInfoImportNostrKeyDescription =>
      '已经有 Nostr 身份了？从其他客户端导入你的 nsec 私钥。';

  @override
  String get authInfoSignerAppTitle => '签名应用';

  @override
  String get authInfoSignerAppDescription =>
      '通过 nsecBunker 等兼容 NIP-46 的远程签名器连接，密钥更安全。';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      '使用 Android 上的 Amber 签名应用安全管理你的 Nostr 密钥。';

  @override
  String get authInfoBrowserExtensionTitle => '浏览器扩展';

  @override
  String get authInfoBrowserExtensionDescription =>
      '通过 Alby 或 nos2x 等 NIP-07 浏览器扩展登录。密钥留在扩展里——Divine 永远看不到。';

  @override
  String get authSignInErrorInvalidCredentials => '邮箱或密码不对，再试一次。';

  @override
  String get authSignInErrorEmailNotVerified => '登录前请先验证邮箱——去收件箱找验证链接。';

  @override
  String get authSignInErrorInvalidEmail => '这看起来不是一个有效的邮箱地址。';

  @override
  String get authSignInErrorNetwork => '连不上服务器。请检查网络连接后重试。';

  @override
  String get authSignInErrorGeneric => '出了点问题，请重试。';

  @override
  String get authSignInOptionsHintPrefix => '不记得上次是怎么登录的？';

  @override
  String get authSignInOptionsHintCta => '查看所有登录方式';

  @override
  String get authCreateAccountTitle => '创建账号';

  @override
  String get authBackToInviteCode => '返回邀请码';

  @override
  String get authUseDivineNoBackup => '不备份，直接用 Divine';

  @override
  String get authSkipConfirmTitle => '最后一件事...';

  @override
  String get authSkipConfirmKeyCreated => '你进来了！我们会生成一把安全密钥，为你的 Divine 账号保驾护航。';

  @override
  String get authSkipConfirmKeyOnly => '没有邮箱，密钥就是 Divine 识别这个账号的唯一方式。';

  @override
  String get authSkipConfirmRecommendEmail =>
      '你可以在应用里查看你的密钥，但如果你不是技术玩家，我们建议现在添加邮箱和密码。这样登录更方便，设备丢失或重置后也能找回账号。';

  @override
  String get authAddEmailPassword => '添加邮箱和密码';

  @override
  String get authUseThisDeviceOnly => '仅此设备使用';

  @override
  String get authCompleteRegistration => '完成注册';

  @override
  String get authVerifying => '验证中...';

  @override
  String get authVerificationLinkSent => '我们已将验证链接发送至：';

  @override
  String get authClickVerificationLink => '请点击邮箱中的链接\n以完成注册。';

  @override
  String get authPleaseWaitVerifying => '请稍候，我们正在验证你的邮箱...';

  @override
  String get authWaitingForVerification => '等待验证';

  @override
  String get authOpenEmailApp => '打开邮箱应用';

  @override
  String get authVerificationPinPrompt => '或输入邮件中的 6 位验证码';

  @override
  String get authVerificationPinFieldLabel => '6 位验证码';

  @override
  String get authVerificationPinSubmit => '验证';

  @override
  String get authVerificationResendPrompt => '没收到？';

  @override
  String get authVerificationResend => '重新发送';

  @override
  String authVerificationResendCooldown(String time) {
    return '$time 后可重发';
  }

  @override
  String get authVerificationResendFailed => '邮件重发失败，请重试。';

  @override
  String get authVerificationResendExpired => '该注册已过期。请重新开始以获取新验证码。';

  @override
  String get authVerificationResendUnavailable =>
      '目前无法重新发送。请使用我们已发送到你邮箱的 6 位验证码。';

  @override
  String get authVerificationPollingStopped => '我们已停止为你检查。请输入邮件中的 6 位验证码完成登录。';

  @override
  String get authWelcomeToDivine => '欢迎来到 Divine！';

  @override
  String get authEmailVerified => '你的邮箱已通过验证。';

  @override
  String get authSigningYouIn => '正在为你登录';

  @override
  String get authErrorTitle => '哎呀。';

  @override
  String get authVerificationFailed => '邮箱验证失败。\n请重试。';

  @override
  String get authStartOver => '重新开始';

  @override
  String get authEmailVerifiedLogin => '邮箱已验证！请登录继续。';

  @override
  String get authVerificationLinkExpired => '该验证链接已失效。';

  @override
  String get authVerificationConnectionError => '无法验证邮箱。请检查网络连接后重试。';

  @override
  String get authWaitlistConfirmTitle => '你进来了！';

  @override
  String authWaitlistUpdatesAt(String email) {
    return '我们会通过 $email 分享动态。\n有更多邀请码时，会第一时间发给你。';
  }

  @override
  String get authOk => '好';

  @override
  String get authTryAgain => '再试一次';

  @override
  String get authContactSupport => '联系客服';

  @override
  String authCouldNotOpenEmail(String email) {
    return '无法打开 $email';
  }

  @override
  String get authAddInviteCode => '输入你的邀请码';

  @override
  String get authInviteCodeLabel => '邀请码';

  @override
  String get authEnterYourCode => '输入邀请码';

  @override
  String get authNext => '下一步';

  @override
  String get authJoinWaitlist => '加入等候名单';

  @override
  String get authJoinWaitlistTitle => '加入等候名单';

  @override
  String get authJoinWaitlistDescription => '留下你的邮箱，开放注册时我们会发送邀请码。';

  @override
  String get authJoinWaitlistNewsletterOptIn => '给我发 Divine 灵感';

  @override
  String get authInviteAccessHelp => '邀请功能帮助';

  @override
  String get authGeneratingConnection => '正在生成连接...';

  @override
  String get authConnectedAuthenticating => '已连接！正在认证...';

  @override
  String get authConnectionTimedOut => '连接超时';

  @override
  String get authApproveConnection => '请确保已在你的签名应用中批准该连接。';

  @override
  String get authConnectionCancelled => '连接已取消';

  @override
  String get authConnectionCancelledMessage => '连接已被取消。';

  @override
  String get authConnectionFailed => '连接失败';

  @override
  String get authUnknownError => '发生未知错误。';

  @override
  String get authNostrConnectStartFailed => '连不上签名器。请检查网络连接后重试。';

  @override
  String get authNostrConnectInvalidSession => '该连接链接已失效，请重新生成一个。';

  @override
  String get authNostrConnectSetupFailed => '就差一点——登录没能完成，请重试。';

  @override
  String get authUrlCopied => 'URL 已复制到剪贴板';

  @override
  String get authConnectToDivine => '连接到 Divine';

  @override
  String get authPasteBunkerUrl => '粘贴 bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl => '无效的 bunker URL，应以 bunker:// 开头';

  @override
  String get authScanSignerApp => '用你的签名应用\n扫码连接。';

  @override
  String authWaitingForConnection(int seconds) {
    return '等待连接中... $seconds秒';
  }

  @override
  String get authCopyUrl => '复制 URL';

  @override
  String get authShare => '分享';

  @override
  String get authAddBunker => '添加 bunker';

  @override
  String get authCompatibleSignerApps => '兼容的签名应用';

  @override
  String get authFailedToConnect => '连接失败';

  @override
  String get authResetPasswordTitle => '重置密码';

  @override
  String get authResetPasswordSubtitle => '请输入你的新密码，长度至少 8 个字符。';

  @override
  String get authNewPasswordLabel => '新密码';

  @override
  String get authConfirmNewPasswordLabel => '确认新密码';

  @override
  String get authPasswordTooShort => '密码至少 8 个字符';

  @override
  String get authPasswordResetSuccess => '密码重置成功，请登录。';

  @override
  String get authPasswordResetFailed => '密码重置失败';

  @override
  String get authUnexpectedError => '发生意外错误，请重试。';

  @override
  String get authUpdatePassword => '更新密码';

  @override
  String get authSecureAccountTitle => '保护账号';

  @override
  String get authUnableToAccessKeys => '无法访问你的密钥，请重试。';

  @override
  String get authRegistrationFailed => '注册失败';

  @override
  String get authRegistrationComplete => '注册完成。请查收你的邮箱。';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => '重置邮件发送失败。';

  @override
  String get authSending => '发送中...';

  @override
  String get authSignInButton => '登录';

  @override
  String get authVerificationErrorTimeout => '验证超时。请重新注册。';

  @override
  String get authVerificationErrorMissingCode => '验证失败——缺少授权码。';

  @override
  String get authVerificationErrorPollFailed => '验证失败，请重试。';

  @override
  String get authVerificationErrorNetworkExchange => '登录过程中网络出错，请重试。';

  @override
  String get authVerificationErrorOAuthExchange => '验证失败。请重新注册。';

  @override
  String get authVerificationErrorSignInFailed => '登录失败。请尝试手动登录。';

  @override
  String get authVerificationEmailAlreadyRegistered => '该邮箱已注册，请直接登录。';

  @override
  String get authVerificationErrorPinInvalid => '验证码不对，请核对后再试。';

  @override
  String get authVerificationErrorPinExpired => '验证码已过期。点重新发送获取新码。';

  @override
  String get authVerificationErrorPinLocked => '尝试次数过多。点重新发送获取新码。';

  @override
  String get authVerificationErrorPinFailed => '无法验证该验证码，请重试。';

  @override
  String get authVerificationErrorPinUnavailable =>
      '暂时无法输入验证码。请点击邮件中的链接，或重新发送获取新码。';

  @override
  String get authInviteCodeErrorMalformed => '请输入 ABCD-EFGH 格式的邀请码。';

  @override
  String get authInviteCodeErrorNotFound => '这个邀请码看起来无效。';

  @override
  String get authInviteCodeErrorAlreadyUsed => '这个邀请码已被使用或已撤销。';

  @override
  String get authInviteGateErrorCreatorFull => '这位创作者的邀请名额已满';

  @override
  String get authInviteGateErrorUnavailable => '这个邀请码不可用。加入候补名单，有名额时我们会给你发送邀请。';

  @override
  String get authInviteGateErrorCheckFailed => '无法验证这个邀请码。请重试。';

  @override
  String get authInviteGateErrorUnknown => '出了点问题。请重新输入你的邀请码。';

  @override
  String get authInviteErrorAlreadyUsed => '该邀请码已不可用。返回你的邀请码页面、加入等候名单，或联系客服。';

  @override
  String get authInviteErrorInvalid => '该邀请码暂时无法使用。返回你的邀请码页面、加入等候名单，或联系客服。';

  @override
  String get authInviteErrorTemporary => '暂时无法确认你的邀请。返回你的邀请码页面重试，或联系客服。';

  @override
  String get authInviteErrorUnknown => '无法激活你的邀请。返回你的邀请码页面、加入等候名单，或联系客服。';

  @override
  String get shareSheetSave => '保存';

  @override
  String get shareSheetRemoveFromSaved => '移除收藏';

  @override
  String get shareSheetSaveToGallery => '保存到相册';

  @override
  String get shareSheetSaveWithWatermark => '保存（带水印）';

  @override
  String get shareSheetSaveVideo => '保存视频';

  @override
  String get shareSheetAddToClips => '加入片段库';

  @override
  String get shareSheetNameClipTitle => '给这个片段起个名';

  @override
  String get shareSheetNameClipSubtitle => '起个你在片段库里一眼能认出的名字。';

  @override
  String get shareSheetClipTitleLabel => '片段标题';

  @override
  String get shareSheetSaveClip => '保存片段';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '已将“$title”存入片段库';
  }

  @override
  String get shareSheetUntitledClip => '未命名片段';

  @override
  String get shareSheetAddToClipsFailed => '无法加入片段库';

  @override
  String get shareSheetAddToList => '加入列表';

  @override
  String get shareSheetCopy => '复制';

  @override
  String get shareSheetShareVia => '分享方式';

  @override
  String get shareSheetEventJson => '事件 JSON';

  @override
  String get shareSheetEventId => '事件 ID';

  @override
  String get shareSheetMoreActions => '更多操作';

  @override
  String get shareSheetCrosspost => '跨平台发布';

  @override
  String get crosspostSheetTitle => '跨平台发布此视频';

  @override
  String get crosspostSheetSubtitle => '发送到你已连接的平台。发布可能需要几分钟。';

  @override
  String get crosspostSubmit => '跨平台发布';

  @override
  String get crosspostStatusQueued => '排队中';

  @override
  String get crosspostStatusUploading => '上传中';

  @override
  String get crosspostStatusProcessing => '处理中';

  @override
  String get crosspostStatusPosted => '已发布';

  @override
  String get crosspostStatusFailed => '失败';

  @override
  String get crosspostStatusSkipped => '已跳过';

  @override
  String get crosspostStatusNeedsReauth => '需要重新连接';

  @override
  String get crosspostViewPost => '查看帖子';

  @override
  String crosspostReconnectPrompt(String platform) {
    return '在跨平台发布设置中重新连接 $platform，才能继续发布。';
  }

  @override
  String get crosspostReconnect => '重新连接';

  @override
  String get crosspostErrorNotOwner => '只有自己的视频才能跨平台发布。';

  @override
  String get crosspostErrorNotEligible => '此视频不符合跨平台发布条件。';

  @override
  String get crosspostErrorNotConnected => '该平台尚未连接。';

  @override
  String get crosspostErrorUnauthorized => '请重新连接你的账号，然后再试。';

  @override
  String get crosspostErrorNetwork => '连不上跨平台发布服务，请稍后再试。';

  @override
  String get crosspostFailedGeneric => '跨平台发布失败。';

  @override
  String get crosspostStillWorking => '仍在处理中。你可以关掉这个页面——发布会在后台继续。';

  @override
  String get crosspostDone => '完成';

  @override
  String get watermarkDownloadSavedToCameraRoll => '已保存到相册';

  @override
  String get watermarkDownloadShare => '分享';

  @override
  String get watermarkDownloadDone => '完成';

  @override
  String get watermarkDownloadPhotosAccessNeeded => '需要照片访问权限';

  @override
  String get watermarkDownloadPhotosAccessDescription => '要保存视频，请在设置中允许访问照片。';

  @override
  String get watermarkDownloadOpenSettings => '打开设置';

  @override
  String get watermarkDownloadNotNow => '暂不';

  @override
  String get watermarkDownloadFailed => '下载失败';

  @override
  String get watermarkDownloadDismiss => '忽略';

  @override
  String get watermarkDownloadStageDownloading => '正在下载视频';

  @override
  String get watermarkDownloadStageWatermarking => '正在添加水印';

  @override
  String get watermarkDownloadStageSaving => '正在保存到相册';

  @override
  String get watermarkDownloadStageDownloadingDesc => '正在从网络获取视频...';

  @override
  String get watermarkDownloadStageWatermarkingDesc => '正在盖上 Divine 水印...';

  @override
  String get watermarkDownloadStageSavingDesc => '正在把带水印的视频保存到你的相册...';

  @override
  String get shareMenuBookmarks => '收藏';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '有 $count 个关注集合可用';
  }

  @override
  String get peopleListsAddToList => '加入列表';

  @override
  String get peopleListsSheetTitle => '加入列表';

  @override
  String get peopleListsEmptyTitle => '还没有列表';

  @override
  String get peopleListsEmptySubtitle => '创建一个列表，开始给人们分组。';

  @override
  String get peopleListsCreateList => '创建列表';

  @override
  String get peopleListsNewListTitle => '新列表';

  @override
  String get peopleListsRouteTitle => '人物列表';

  @override
  String get peopleListsListNameLabel => '列表名称';

  @override
  String get peopleListsListNameHint => '亲密好友';

  @override
  String get peopleListsCreateButton => '创建';

  @override
  String get peopleListsAddPeopleTitle => '添加成员';

  @override
  String get peopleListsAddPeopleTooltip => '添加成员';

  @override
  String get peopleListsAddPeopleSemanticLabel => '把成员加入列表';

  @override
  String get peopleListsListNotFoundTitle => '找不到列表';

  @override
  String get peopleListsListNotFoundSubtitle => '找不到该列表，可能已被删除。';

  @override
  String get peopleListsListDeletedSubtitle => '该列表可能已被删除。';

  @override
  String get peopleListsNoPeopleTitle => '列表里还没有人';

  @override
  String get peopleListsNoPeopleSubtitle => '加一些人进来吧';

  @override
  String get peopleListsNoVideosTitle => '还没有视频';

  @override
  String get peopleListsNoVideosSubtitle => '列表成员的视频会显示在这里';

  @override
  String get peopleListsNoVideosAvailable => '暂无视频';

  @override
  String get peopleListsFailedToLoadVideos => '视频加载失败';

  @override
  String get peopleListsVideoNotAvailable => '视频不可用';

  @override
  String get peopleListsBackToGridTooltip => '返回网格';

  @override
  String get peopleListsErrorLoadingVideos => '加载视频出错';

  @override
  String get peopleListsNoPeopleToAdd => '没有可添加的人。';

  @override
  String peopleListsAddToListName(String name) {
    return '加入$name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => '搜索用户';

  @override
  String get peopleListsAddPeopleError => '加载用户失败，请重试。';

  @override
  String get peopleListsAddPeopleRetry => '再试一次';

  @override
  String get peopleListsAddButton => '添加';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '添加 $count 人';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已在 $count 个列表中',
      one: '已在 1 个列表中',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '移除 $name？';
  }

  @override
  String get peopleListsRemoveConfirmBody => '对方将从该列表中移除。';

  @override
  String get peopleListsRemove => '移除';

  @override
  String peopleListsRemovedFromList(String name) {
    return '已将 $name 从列表移除';
  }

  @override
  String get peopleListsUndo => '撤销';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return '$name 的主页。长按可移除。';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return '查看 $name 的主页';
  }

  @override
  String get shareMenuEditVideo => '编辑视频';

  @override
  String get shareMenuDeleteVideo => '删除视频';

  @override
  String shareMenuVideoCount(int count) {
    return '$count 个视频';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      '这会从 Divine 永久删除该视频。使用其他中继的第三方 Nostr 客户端上可能仍会显示。';

  @override
  String get shareMenuCancel => '取消';

  @override
  String get shareMenuDelete => '删除';

  @override
  String get shareMenuDeleteFailedNotInitialized => '删除功能还没准备好，请稍后再试。';

  @override
  String get shareMenuDeleteFailedNotOwner => '你只能删除自己的视频。';

  @override
  String get shareMenuDeleteFailedNotAuthenticated => '请重新登录后再删除。';

  @override
  String get shareMenuDeleteFailedCouldNotSign => '无法为删除请求签名，请重试。';

  @override
  String get shareMenuDeleteFailedRelayRejected => '中继拒绝了该删除请求，请稍后再试。';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse => '连不上中继。请检查网络连接后重试。';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      '已删除。不是所有中继都确认了，所以它可能还会出现在其他应用里。';

  @override
  String get shareMenuDeleteFailedGeneric => '无法删除此视频，请重试。';

  @override
  String get shareMenuUpdate => '更新';

  @override
  String get shareMenuChangeCover => '更换封面';

  @override
  String get shareMenuVideoUpdated => '视频更新成功';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 个合作邀请未能发送。',
      one: '有 1 个合作邀请未能发送。',
    );
    return '视频已更新，但$_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated => '请重新登录后再试。';

  @override
  String get videoUpdateErrorNoPlayableVideo => '这个视频没有可播放的源，无法编辑。';

  @override
  String get videoUpdateErrorCouldNotSign => '更新签名失败，请重试。';

  @override
  String get videoUpdateErrorPublishRejected => '中继未接受此次更新，请稍后重试。';

  @override
  String get videoUpdateErrorGeneric => '无法更新这个视频，请重试。';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => '删除视频？';

  @override
  String get shareMenuDeleteCleanupInProgress => '正在移除视频…';

  @override
  String get shareMenuDeleteCleanupConfirmed => '视频已删除。';

  @override
  String get shareMenuDeleteCleanupDelayed => '视频已删除。它可能需要一点时间才能从所有地方消失。';

  @override
  String get shareMenuDeleteCleanupFailed => '视频已删除，但我们无法移除每个副本。请联系支持团队。';

  @override
  String get authSessionExpired => '你的登录已过期，请重新登录。';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => '登录失败，请重试。';

  @override
  String get webAuthNotSupportedSecureMode => '安全模式下不支持网页认证。请使用移动应用进行安全的密钥管理。';

  @override
  String get webAuthEnterBunkerUri => '请输入 bunker URI';

  @override
  String get webAuthConnectTitle => '连接到 Divine';

  @override
  String get webAuthChooseMethod => '选择你偏好的 Nostr 认证方式';

  @override
  String get webAuthBrowserExtension => '浏览器扩展';

  @override
  String get webAuthRecommended => '推荐';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => '连接远程签名器';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => '从剪贴板粘贴';

  @override
  String get webAuthConnectToBunker => '连接到 Bunker';

  @override
  String get webAuthNewToNostr => 'Nostr 新手？';

  @override
  String get webAuthNostrHelp =>
      '安装 Alby 或 nos2x 等浏览器扩展体验最省事，也可以用 nsec bunker 进行安全的远程签名。';

  @override
  String get soundsTitle => '声音';

  @override
  String get soundsSearchHint => '搜索声音...';

  @override
  String get soundsSearchResults => '搜索结果';

  @override
  String get soundsNoSoundsFound => '没有找到声音';

  @override
  String get soundsNoSoundsFoundDescription => '换个搜索词试试';

  @override
  String get soundsSavedToLibrary => '已存入声音库';

  @override
  String get soundsAlreadySavedToLibrary => '已在声音库中';

  @override
  String get soundsSavedLibraryTitle => '我的声音';

  @override
  String get soundsSavedEmptyTitle => '还没有保存的声音';

  @override
  String get soundsSavedEmptyDescription => '在视频上点“使用这个声音”，就会保存在这里。';

  @override
  String get soundsRemoveSavedSound => '移除声音';

  @override
  String get savedSoundSaveAction => '保存';

  @override
  String get savedSoundPausePreviewAction => '暂停试听';

  @override
  String get savedSoundResumePreviewAction => '继续试听';

  @override
  String get savedSoundDetailsSheetTitle => '声音详情';

  @override
  String get savedSoundRemoveConfirmTitle => '要移除这个声音吗？';

  @override
  String get savedSoundRemoveConfirmMessage => '它会从你的音库中消失，但你可以从任何用到它的视频里重新保存。';

  @override
  String get soundsRemovedFromLibrary => '已从声音库移除';

  @override
  String get soundsSaveFailed => '无法保存该声音。请重试。';

  @override
  String get soundsRemoveFailed => '无法移除该声音。请重试。';

  @override
  String get soundSyncStatusSyncing => '正在同步你的声音…';

  @override
  String get soundSyncStatusSynced => '声音已是最新';

  @override
  String get soundSyncStatusFailed => '无法同步你的声音，我们会再试一次。';

  @override
  String get soundSyncStatusLocked => '无法在此设备上解锁你的同步音库。';

  @override
  String get profileTitle => '主页';

  @override
  String get profileMoreOptions => '更多选项';

  @override
  String profileBlockedUser(String name) {
    return '已屏蔽 $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return '已取消屏蔽 $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '已取消关注 $name';
  }

  @override
  String get profileFeedError => '连不上服务器。请检查网络连接后重试。';

  @override
  String get profileFeedLoadMoreError => '无法加载更多视频。下拉刷新试试。';

  @override
  String get notificationsTabAll => '全部';

  @override
  String get notificationsTabLikes => '点赞';

  @override
  String get notificationsTabComments => '评论';

  @override
  String get notificationsTabFollows => '关注';

  @override
  String get notificationsTabReposts => '转发';

  @override
  String get notificationsFailedToLoad => '通知加载失败';

  @override
  String get notificationsRetry => '重试';

  @override
  String get notificationsRefreshError => '刷新失败——先看你已有的';

  @override
  String get notificationsUnreadPrefix => '未读通知';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条未读通知',
      one: '1 条未读通知',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return '查看 $displayName 的主页';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => '查看主页';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return '$title 的视频缩略图';
  }

  @override
  String get notificationsVideoThumbnail => '视频缩略图';

  @override
  String get notificationsInviteSingular => '你有 1 个邀请名额，可以分享给朋友！';

  @override
  String notificationsInvitePlural(int count) {
    return '你有 $count 个邀请名额，可以分享给朋友！';
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
  String get notificationsVideoUnavailable => '视频不可用';

  @override
  String get feedFailedToLoadVideos => '视频加载失败';

  @override
  String get feedRetry => '重试';

  @override
  String get feedNoFollowedUsers => '你还没有关注任何人。\n关注一些人，就能在这里看到他们的视频。';

  @override
  String get feedModeForYou => '为你推荐';

  @override
  String get feedModeNew => '最新';

  @override
  String get feedModeFollowing => '关注';

  @override
  String get feedModeClassics => '经典';

  @override
  String feedModeSemanticLabel(String label) {
    return '信息流模式：$label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return '视频作者：$displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => '作者头像';

  @override
  String get feedForYouEmpty => '你的“为你推荐”还是空的。\n去逛逛视频、关注些创作者，它就会越来越懂你。';

  @override
  String get feedFollowingEmpty => '你关注的人还没有发视频。\n去找找喜欢的创作者，关注他们吧。';

  @override
  String get feedLatestEmpty => '还没有新视频。\n过会儿再来看看。';

  @override
  String get feedClassicEmpty => '还没有经典 Vine。\n过会儿再来看看。';

  @override
  String get feedExploreVideos => '去探索视频';

  @override
  String get feedLoadingMore => '正在加载更多视频…';

  @override
  String get feedRefreshed => '信息流已刷新';

  @override
  String get uploadUploadingVideo => '正在上传视频';

  @override
  String get postPublishConfirmationTitle => '已发布到你的主页';

  @override
  String get postPublishConfirmationView => '查看';

  @override
  String get postPublishConfirmationShare => '分享';

  @override
  String get postPublishConfirmationThumbnailLabel => '你刚发布的视频缩略图';

  @override
  String get userSearchNoResults => '没有找到用户';

  @override
  String get userPickerFilterByNameHint => '按名字筛选...';

  @override
  String get userPickerSearchByNameHint => '按名字搜索...';

  @override
  String get userPickerClearSearchSemantics => '清除搜索';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name 已添加';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '选择 $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return '移除 $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => '你的同好就在外面';

  @override
  String get userPickerEmptyFollowListBody => '关注和你对味的人。等他们回关，你们就能合作了。';

  @override
  String get userPickerGoBack => '返回';

  @override
  String get userPickerTypeNameToSearch => '输入名字开始搜索';

  @override
  String get userPickerUnavailable => '用户搜索暂不可用，请稍后再试。';

  @override
  String get userPickerSearchFailedTryAgain => '搜索失败，请重试。';

  @override
  String get forgotPasswordTitle => '重置密码';

  @override
  String get forgotPasswordDescription => '输入你的邮箱地址，我们会发送密码重置链接。';

  @override
  String get forgotPasswordEmailLabel => '邮箱地址';

  @override
  String get forgotPasswordCancel => '取消';

  @override
  String get forgotPasswordSendLink => '发送重置链接';

  @override
  String get ageVerificationContentWarning => '内容警告';

  @override
  String get ageVerificationTitle => '年龄验证';

  @override
  String get ageVerificationAdultDescription =>
      '该内容被标记为可能包含成人内容。你必须年满 18 岁才能查看。';

  @override
  String get ageVerificationCreationDescription => '要使用相机创作内容，你必须年满 16 岁。';

  @override
  String get ageVerificationAdultQuestion => '你年满 18 岁吗？';

  @override
  String get ageVerificationCreationQuestion => '你年满 16 岁吗？';

  @override
  String get ageVerificationNo => '否';

  @override
  String get ageVerificationYes => '是';

  @override
  String get navHome => '首页';

  @override
  String get navExplore => '探索';

  @override
  String get navInbox => '私信';

  @override
  String get navProfile => '我的';

  @override
  String get navMyProfile => '我的主页';

  @override
  String get navNotifications => '通知';

  @override
  String get navOpenCamera => '打开相机';

  @override
  String get navExploreClassics => '经典';

  @override
  String get navExploreNewVideos => '新视频';

  @override
  String get navExploreTrending => '热门';

  @override
  String get navExploreForYou => '为你推荐';

  @override
  String get navExploreLists => '列表';

  @override
  String get routeErrorTitle => '错误';

  @override
  String get routeInvalidHashtag => '无效的话题标签';

  @override
  String get routeInvalidConversationId => '无效的会话 ID';

  @override
  String get routeInvalidRequestId => '无效的请求 ID';

  @override
  String get routeInvalidListId => '无效的列表 ID';

  @override
  String get routeInvalidUserId => '无效的用户 ID';

  @override
  String get routeInvalidVideoId => '无效的视频 ID';

  @override
  String get routeInvalidSoundId => '无效的声音 ID';

  @override
  String get routeInvalidCategory => '无效的分类';

  @override
  String get routeNoVideosToDisplay => '没有可显示的视频';

  @override
  String get routeGoHome => '回到首页';

  @override
  String get routeInvalidProfileId => '无效的主页 ID';

  @override
  String get routeUnknownPath => '这个页面不在应用里。';

  @override
  String get routeDefaultListName => '列表';

  @override
  String get supportTitle => '帮助中心';

  @override
  String get supportContactSupport => '联系客服';

  @override
  String get supportContactSupportSubtitle => '开始咨询或查看历史消息';

  @override
  String get supportReportBug => '报告 Bug';

  @override
  String get supportReportBugSubtitle => '应用的技术问题';

  @override
  String get supportRequestFeature => '功能建议';

  @override
  String get supportRequestFeatureSubtitle => '提出改进建议或新功能想法';

  @override
  String get supportSaveLogs => '保存日志';

  @override
  String get supportSaveLogsSubtitle => '导出日志到文件，手动发送';

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
  String get supportFaq => '常见问题';

  @override
  String get supportFaqSubtitle => '常见问题与解答';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle => '帮助家长和青少年养成健康的上网习惯';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => '我们如何按年龄区分处理账户';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => '了解验证与真实性';

  @override
  String get supportLoginRequired => '登录后才能联系客服';

  @override
  String get supportExportingLogs => '正在导出日志...';

  @override
  String get supportExportLogsFailed => '日志导出失败';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return '日志已保存到 $path';
  }

  @override
  String get supportRevealLogsAction => '在文件夹中显示';

  @override
  String get supportChatNotAvailable => '客服聊天不可用';

  @override
  String get supportCouldNotOpenMessages => '无法打开客服消息';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '无法打开$pageName';
  }

  @override
  String get reportWhyReporting => '你为什么要举报该内容？';

  @override
  String get reportPolicyNotice =>
      'Divine 会在 24 小时内处理内容举报：移除违规内容，并将发布违规内容的用户清出平台。';

  @override
  String get reportBlockUser => '屏蔽该用户';

  @override
  String get reportCancel => '取消';

  @override
  String get reportSubmit => '举报';

  @override
  String get reportSelectReason => '请选择举报该内容的原因';

  @override
  String get reportOtherRequiresDetails => '选择“其他”时请描述问题';

  @override
  String get reportDetailsRequired => '请描述问题';

  @override
  String get reportDetailsTextOnly => '仅限文字——无法在此附加照片或 GIF。';

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
  String get reportReasonSpam => '垃圾或不受欢迎的内容';

  @override
  String get reportReasonSpamSubtitle => '不受欢迎或重复的内容';

  @override
  String get reportReasonHarassment => '骚扰、霸凌或威胁';

  @override
  String get reportReasonHarassmentSubtitle => '有害且不受欢迎的回复或提及';

  @override
  String get reportReasonViolence => '暴力或极端主义内容';

  @override
  String get reportReasonViolenceSubtitle => '暴力、极端或有害的内容';

  @override
  String get reportReasonSexualContent => '色情或成人内容';

  @override
  String get reportReasonSexualContentSubtitle => '裸露、色情或露骨内容';

  @override
  String get reportReasonCopyright => '侵犯版权';

  @override
  String get reportReasonCopyrightSubtitle => '未经授权使用知识产权';

  @override
  String get reportReasonFalseInfo => '虚假信息';

  @override
  String get reportReasonFalseInfoSubtitle => '误导性或虚假言论';

  @override
  String get reportReasonChildSafety => '儿童安全违规';

  @override
  String get reportReasonChildSafetySubtitle => '关于未成年人安全的一般性担忧';

  @override
  String get reportReasonCsam => '儿童性虐待';

  @override
  String get reportReasonCsamSubtitle => '描绘对未成年人实施性虐待的内容';

  @override
  String get reportReasonUnderageUser => '用户疑似未满 16 岁';

  @override
  String get reportReasonUnderageUserSubtitle => '账号持有者疑似未成年';

  @override
  String get reportReasonAiGenerated => 'AI 生成内容';

  @override
  String get reportReasonAiGeneratedSubtitle => '疑似 AI 生成的内容';

  @override
  String get reportReasonOther => '其他违规';

  @override
  String get reportReasonOtherSubtitle => '以上未列出的违规行为';

  @override
  String get reportFailed => '举报内容失败，请重试。';

  @override
  String get reportNotSent => '举报发送失败。请检查连接后重试。';

  @override
  String get reportReceivedTitle => '举报已收到';

  @override
  String get reportReceivedThankYou => '谢谢你帮助维护 Divine 的安全。';

  @override
  String get reportReceivedReviewNotice =>
      '我们的团队会审核你的举报并采取适当措施。你可能会通过私信收到进展通知。';

  @override
  String get reportModerationDmDelayed => '暂时没能直接联系上管理团队，但你的举报已收到，我们会审核的。';

  @override
  String get reportContactModeration => '给管理团队发消息';

  @override
  String get reportLearnMoreAt => '了解更多：';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => '关闭';

  @override
  String get listAddToList => '加入列表';

  @override
  String listVideoCount(int count) {
    return '$count 个视频';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
      one: '1 人',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => '来自 ';

  @override
  String get listNewList => '新列表';

  @override
  String get listDone => '完成';

  @override
  String get listErrorLoading => '加载列表出错';

  @override
  String listRemovedFrom(String name) {
    return '已从 $name 移除';
  }

  @override
  String listAddedTo(String name) {
    return '已加入 $name';
  }

  @override
  String get listCreateNewList => '创建新列表';

  @override
  String get listNewPeopleList => '新人物列表';

  @override
  String get listCollaboratorsNone => '无';

  @override
  String get listAddCollaboratorTitle => '添加协作者';

  @override
  String get listCollaboratorSearchHint => '搜索 Divine...';

  @override
  String get listNameLabel => '列表名称';

  @override
  String get listDescriptionLabel => '描述（可选）';

  @override
  String get listPublicList => '公开列表';

  @override
  String get listPublicListSubtitle => '其他人可以关注并查看此列表';

  @override
  String get listPrivateListSubtitle => '视频保持私密。名称、描述、标签和封面仍会显示。';

  @override
  String get listVisibilityPublic => '公开';

  @override
  String get listVisibilityPrivate => '私密';

  @override
  String get profileListsEmpty => '还没有列表。为想放在一起的循环建一个吧。';

  @override
  String get listEditTitle => '编辑列表';

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
  String get listShareAction => '分享列表';

  @override
  String get listShareFailed => '无法分享此列表，请重试。';

  @override
  String get listSave => '保存';

  @override
  String get listContinue => '继续';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => '无法更新此列表，请重试。';

  @override
  String get listMakePrivateTitle => '将此列表设为私密？';

  @override
  String get listMakePrivateWarning =>
      '视频会被加密，只有你能看到。名称、描述、标签和封面仍然可见，之前分享出去的副本可能仍会留存。';

  @override
  String get listMakePublicTitle => '将此列表设为公开？';

  @override
  String get listMakePublicWarning => '任何拿到链接的人都能看到此列表及其视频。';

  @override
  String listShareText(String name, String url) {
    return '来 Divine 看看 $name：$url';
  }

  @override
  String listShareSubject(String name) {
    return 'Divine 上的 $name';
  }

  @override
  String get listCancel => '取消';

  @override
  String get listCreate => '创建';

  @override
  String get listCreateFailed => '创建列表失败';

  @override
  String get keyManagementTitle => 'Nostr 密钥';

  @override
  String get keyManagementWhatAreKeys => '什么是 Nostr 密钥？';

  @override
  String get keyManagementExplanation =>
      '你的 Nostr 身份是一对加密密钥：\n\n• 公钥（npub）就像你的用户名——可以随意分享\n• 私钥（nsec）就像你的密码——必须保密！\n\n有了 nsec，你可以在任何 Nostr 应用上访问你的账号。';

  @override
  String get keyManagementImportTitle => '导入已有密钥';

  @override
  String get keyManagementImportSubtitle =>
      '已经有 Nostr 账号了？粘贴你的私钥（nsec）即可在这里访问。';

  @override
  String get keyManagementImportButton => '导入密钥';

  @override
  String get keyManagementImportWarning => '这会替换你当前的密钥！';

  @override
  String get keyManagementBackupTitle => '备份你的密钥';

  @override
  String get keyManagementBackupSubtitle =>
      '保存你的私钥（nsec），即可在其他 Nostr 应用中使用你的账号。';

  @override
  String get keyManagementCopyNsec => '复制我的私钥（nsec）';

  @override
  String get keyManagementNeverShare => '千万不要把 nsec 分享给任何人！';

  @override
  String get keyManagementKeycastRemoteSigning =>
      '你的私钥保存在 Divine 的登录服务上，不在这台设备里。确认一下密码，我们就帮你取回来。';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      '你的私钥由 Divine 的登录服务保管。输入你的账号密码，我们这就帮你取来。';

  @override
  String get keyManagementKeycastCopyKey => '复制私钥';

  @override
  String get keyManagementKeycastCopyBlocked => '你的设备阻止了这次复制，私钥没能进入剪贴板。';

  @override
  String get keyManagementKeycastWrongPassword => '密码不对，再试一次。';

  @override
  String get keyManagementKeycastTooManyAttempts => '尝试次数过多。关掉这个窗口，重新来过。';

  @override
  String get keyManagementKeycastRateLimited => '请求私钥太频繁了。等几分钟再试。';

  @override
  String get keyManagementKeycastSignInAgain => '你的登录已过期。重新登录后再复制私钥。';

  @override
  String get keyManagementKeycastEmailUnverified => '复制私钥前请先验证你的邮箱地址。';

  @override
  String get keyManagementKeycastDenied => '这个账号的密钥由 Divine 托管，所以这里无法复制。';

  @override
  String get keyManagementKeycastNoKey => '这个账号没有任何密钥记录。';

  @override
  String get keyManagementKeycastGenericFailure => '连不上登录服务，请重试。';

  @override
  String get keyManagementRestrictedTitle => '你的密钥由 Divine 托管';

  @override
  String get keyManagementRestrictedBody => '为了保护你的账号安全，这里不提供密钥备份和导入其他密钥。';

  @override
  String get keyManagementPasteKey => '请粘贴你的私钥';

  @override
  String get keyManagementInvalidFormat => '密钥格式无效，必须以“nsec1”开头';

  @override
  String get keyManagementConfirmImportTitle => '导入该密钥？';

  @override
  String get keyManagementConfirmImportBody =>
      '这会用导入的身份替换你当前的身份。\n\n如果事先没有备份，你当前的密钥将会丢失。';

  @override
  String get keyManagementImportConfirm => '导入';

  @override
  String get keyManagementImportSuccess => '密钥导入成功！';

  @override
  String get keyManagementImportFailed => '导入密钥失败，请重试。';

  @override
  String get keyManagementExportSuccess => '私钥已复制到剪贴板！\n\n请妥善保管。';

  @override
  String get keyManagementExportFailed => '导出密钥失败，请重试。';

  @override
  String get keyManagementYourPublicKeyLabel => '你的公钥（npub）';

  @override
  String get keyManagementCopyPublicKeyTooltip => '复制公钥';

  @override
  String get keyManagementPublicKeyCopied => '公钥已复制';

  @override
  String get saveOriginalSavedToCameraRoll => '已保存到相册';

  @override
  String get saveOriginalShare => '分享';

  @override
  String get saveOriginalDone => '完成';

  @override
  String get saveOriginalPhotosAccessNeeded => '需要照片访问权限';

  @override
  String get saveOriginalPhotosAccessMessage => '要保存视频，请在设置中允许访问照片。';

  @override
  String get saveOriginalOpenSettings => '打开设置';

  @override
  String get saveOriginalNotNow => '暂不';

  @override
  String get saveOriginalDownloadFailed => '下载失败';

  @override
  String get saveOriginalDismiss => '忽略';

  @override
  String get saveOriginalDownloadingVideo => '正在下载视频';

  @override
  String get saveOriginalSavingToCameraRoll => '正在保存到相册';

  @override
  String get saveOriginalFetchingVideo => '正在从网络获取视频...';

  @override
  String get saveOriginalSavingVideo => '正在把原始视频保存到你的相册...';

  @override
  String get soundTitle => '声音';

  @override
  String get soundOriginalSound => '原声';

  @override
  String get soundVideosUsingThisSound => '使用这个声音的视频';

  @override
  String get soundSourceVideo => '来源视频';

  @override
  String get soundNoVideosYet => '还没有视频';

  @override
  String get soundBeFirstToUse => '做第一个用这个声音的人！';

  @override
  String get soundFailedToLoadVideos => '视频加载失败';

  @override
  String get soundRetry => '重试';

  @override
  String get soundVideosUnavailable => '视频不可用';

  @override
  String get soundCouldNotLoadDetails => '无法加载视频详情';

  @override
  String get soundPreview => '预览';

  @override
  String get soundStop => '停止';

  @override
  String get soundUseSound => '使用声音';

  @override
  String get soundUntitled => '未命名声音';

  @override
  String get soundStopPreview => '停止预览';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '预览 $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return '查看 $title 的详情';
  }

  @override
  String get soundNoVideoCount => '还没有视频';

  @override
  String get soundOneVideo => '1 个视频';

  @override
  String soundVideoCount(int count) {
    return '$count 个视频';
  }

  @override
  String get soundUnableToPreview => '无法预览声音——没有可用音频';

  @override
  String get soundPreviewFailed => '预览播放失败，请重试。';

  @override
  String get soundViewSource => '查看来源';

  @override
  String get soundCloseTooltip => '关闭';

  @override
  String get exploreNotExploreRoute => '不是探索路由';

  @override
  String get legalTitle => '法律信息';

  @override
  String get legalTermsOfService => '服务条款';

  @override
  String get legalTermsOfServiceSubtitle => '使用条款与条件';

  @override
  String get legalPrivacyPolicy => '隐私政策';

  @override
  String get legalPrivacyPolicySubtitle => '我们如何处理你的数据';

  @override
  String get legalSafetyStandards => '安全准则';

  @override
  String get legalSafetyStandardsSubtitle => '社区规范与安全';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => '版权与下架政策';

  @override
  String get legalOpenSourceLicenses => '开源许可证';

  @override
  String get legalOpenSourceLicensesSubtitle => '第三方软件包声明';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '无法打开$pageName';
  }

  @override
  String get categoryAction => '动作';

  @override
  String get categoryAdventure => '冒险';

  @override
  String get categoryAnimals => '动物';

  @override
  String get categoryAnimation => '动画';

  @override
  String get categoryArchitecture => '建筑';

  @override
  String get categoryArt => '艺术';

  @override
  String get categoryAutomotive => '汽车';

  @override
  String get categoryAwardShow => '颁奖典礼';

  @override
  String get categoryAwards => '奖项';

  @override
  String get categoryBaseball => '棒球';

  @override
  String get categoryBasketball => '篮球';

  @override
  String get categoryBeauty => '美妆';

  @override
  String get categoryBeverage => '饮品';

  @override
  String get categoryCars => '汽车';

  @override
  String get categoryCelebration => '庆祝';

  @override
  String get categoryCelebrities => '名人';

  @override
  String get categoryCelebrity => '明星';

  @override
  String get categoryCityscape => '城市风光';

  @override
  String get categoryComedy => '喜剧';

  @override
  String get categoryConcert => '演唱会';

  @override
  String get categoryCooking => '烹饪';

  @override
  String get categoryCostume => '服装';

  @override
  String get categoryCrafts => '手工';

  @override
  String get categoryCrime => '犯罪';

  @override
  String get categoryCulture => '文化';

  @override
  String get categoryDance => '舞蹈';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => '剧情';

  @override
  String get categoryEducation => '教育';

  @override
  String get categoryEmotional => '情感';

  @override
  String get categoryEmotions => '情绪';

  @override
  String get categoryEntertainment => '娱乐';

  @override
  String get categoryEvent => '活动';

  @override
  String get categoryFamily => '家庭';

  @override
  String get categoryFans => '粉丝';

  @override
  String get categoryFantasy => '奇幻';

  @override
  String get categoryFashion => '时尚';

  @override
  String get categoryFestival => '节日';

  @override
  String get categoryFilm => '电影';

  @override
  String get categoryFitness => '健身';

  @override
  String get categoryFood => '美食';

  @override
  String get categoryFootball => '橄榄球';

  @override
  String get categoryFurniture => '家具';

  @override
  String get categoryGaming => '游戏';

  @override
  String get categoryGolf => '高尔夫';

  @override
  String get categoryGrooming => '理容';

  @override
  String get categoryGuitar => '吉他';

  @override
  String get categoryHalloween => '万圣节';

  @override
  String get categoryHealth => '健康';

  @override
  String get categoryHockey => '冰球';

  @override
  String get categoryHoliday => '假日';

  @override
  String get categoryHome => '居家';

  @override
  String get categoryHomeImprovement => '家装';

  @override
  String get categoryHorror => '恐怖';

  @override
  String get categoryHospital => '医院';

  @override
  String get categoryHumor => '幽默';

  @override
  String get categoryInteriorDesign => '室内设计';

  @override
  String get categoryInterview => '访谈';

  @override
  String get categoryKids => '儿童';

  @override
  String get categoryLifestyle => '生活方式';

  @override
  String get categoryMagic => '魔术';

  @override
  String get categoryMakeup => '化妆';

  @override
  String get categoryMedical => '医疗';

  @override
  String get categoryMusic => '音乐';

  @override
  String get categoryMystery => '悬疑';

  @override
  String get categoryNature => '自然';

  @override
  String get categoryNews => '新闻';

  @override
  String get categoryOutdoor => '户外';

  @override
  String get categoryParty => '派对';

  @override
  String get categoryPeople => '人物';

  @override
  String get categoryPerformance => '表演';

  @override
  String get categoryPets => '宠物';

  @override
  String get categoryPolitics => '政治';

  @override
  String get categoryPrank => '恶作剧';

  @override
  String get categoryPranks => '整蛊';

  @override
  String get categoryRealityShow => '真人秀';

  @override
  String get categoryRelationship => '情感关系';

  @override
  String get categoryRelationships => '人际关系';

  @override
  String get categoryRomance => '浪漫';

  @override
  String get categorySchool => '校园';

  @override
  String get categoryScienceFiction => '科幻';

  @override
  String get categorySelfie => '自拍';

  @override
  String get categoryShopping => '购物';

  @override
  String get categorySkateboarding => '滑板';

  @override
  String get categorySkincare => '护肤';

  @override
  String get categorySoccer => '足球';

  @override
  String get categorySocialGathering => '聚会';

  @override
  String get categorySocialMedia => '社交媒体';

  @override
  String get categorySports => '运动';

  @override
  String get categoryTalkShow => '脱口秀';

  @override
  String get categoryTech => '科技';

  @override
  String get categoryTechnology => '技术';

  @override
  String get categoryTelevision => '电视';

  @override
  String get categoryToys => '玩具';

  @override
  String get categoryTransportation => '交通';

  @override
  String get categoryTravel => '旅行';

  @override
  String get categoryUrban => '都市';

  @override
  String get categoryViolence => '暴力';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => '拍Vlog';

  @override
  String get categoryWrestling => '摔角';

  @override
  String get profileSetupUploadStaged => '已上传——点保存生效';

  @override
  String inboxReportedUser(String displayName) {
    return '已举报 $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '已屏蔽 $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '已取消屏蔽 $displayName';
  }

  @override
  String get inboxRemovedConversation => '已删除会话';

  @override
  String get inboxRestorePausedTitle => '部分聊天还没恢复完';

  @override
  String get conversationRestorePausedTitle => '这个聊天还没恢复完';

  @override
  String get inboxRestoreRetryAction => '重试';

  @override
  String get inboxRestoringMessages => '正在恢复你的消息…';

  @override
  String get inboxEmptyTitle => '还没有消息';

  @override
  String get inboxEmptySubtitle => '那个 + 按钮又不会咬人。';

  @override
  String get inboxLoadErrorTitle => '消息加载失败';

  @override
  String get inboxLoadErrorSubtitle => '检查网络连接，再试一次。';

  @override
  String get inboxFilterAll => '全部';

  @override
  String get inboxFilterUnread => '未读';

  @override
  String get dmBlockedThreadTitle => '你已屏蔽此账号';

  @override
  String get dmBlockedThreadBody => '消息会保留在这里，方便你查看或截图。解除屏蔽后即可回复。';

  @override
  String get inboxFilterBlocked => '已屏蔽';

  @override
  String get inboxBlockedEmptyTitle => '没有已屏蔽的聊天';

  @override
  String get inboxBlockedEmptySubtitle => '你屏蔽的账号会显示在这里。';

  @override
  String get inboxBlockedNoMessages => '暂无消息';

  @override
  String get inboxUnreadEmptyTitle => '都看完啦';

  @override
  String get inboxUnreadEmptySubtitle => '现在没有未读消息。';

  @override
  String get inboxSearchHint => '搜索消息';

  @override
  String get inboxSupportRowTitle => 'Divine 审核';

  @override
  String get inboxSupportRowSubtitle => 'Bug、内容管理、账号问题——我们都在听。';

  @override
  String get inboxSearchEmptyTitle => '没有匹配结果';

  @override
  String get inboxSearchEmptySubtitle => '换个名字或词试试。';

  @override
  String get inboxActionMute => '静音会话';

  @override
  String inboxActionReport(String displayName) {
    return '举报 $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '屏蔽 $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '取消屏蔽 $displayName';
  }

  @override
  String get inboxActionRemove => '删除会话';

  @override
  String get inboxRemoveConfirmTitle => '删除会话？';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return '这会从你的收件箱中移除你与 $displayName 的会话。如果对方再次给你发消息，会开始一个新会话。';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      '这会从你的收件箱中移除这个群聊会话。如果有人再次在群里发消息，会开始一个新会话。';

  @override
  String get inboxRemoveConfirmConfirm => '删除';

  @override
  String get inboxConversationMuted => '会话已静音';

  @override
  String get inboxConversationUnmuted => '会话已取消静音';

  @override
  String get inboxCollabInviteCardTitle => '合作邀请';

  @override
  String get inboxCollabInviteCardUntitledVideo => '未命名视频';

  @override
  String get clickableTextViewVideoLink => '查看视频';

  @override
  String get messageExternalLinkDialogTitle => '打开外部链接？';

  @override
  String messageExternalLinkDialogBody(String url) {
    return '该链接指向外部网站，可能不安全：\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => '打开';

  @override
  String get inboxCollabInviteCoPostButton => '共同发布';

  @override
  String get inboxCollabInviteNotMineButton => '不是我的';

  @override
  String get inboxCollabInvitePreviewTitle => '共同发布邀请';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return '来自 $displayName 的共同发布邀请';
  }

  @override
  String get inboxCollabInviteTimelineConsequence => '共同发布会把该视频作为合作内容添加到你的时间线。';

  @override
  String get inboxCollabInviteAcceptedStatus => '已接受';

  @override
  String get inboxCollabInviteIgnoredStatus => '已忽略';

  @override
  String get inboxCollabInviteAcceptError => '无法接受，请重试。';

  @override
  String get inboxCollabInviteSentStatus => '邀请已发送';

  @override
  String get inboxConversationCollabInvitePreview => '合作邀请';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return '你受邀参与合作制作 $title：$url\n\n打开 Divine 查看并接受。';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return '你受邀参与合作制作一个视频：$url\n\n打开 Divine 查看并接受。';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 个合作邀请未能发送。',
      one: '有 1 个合作邀请未能发送。',
    );
    return '视频已发布，但$_temp0';
  }

  @override
  String get dmSendNoRecipientMessage => '无法确定这个会话的对象。请从收件箱重新打开。';

  @override
  String get dmSendBlockedMessage => '你只能给 Divine 官方账号发私信';

  @override
  String get dmSendBlockedRetiredMessage =>
      '没有人会看到这个对话。请改为给 Divine Moderation 发私信。';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => '无法对所有人删除。';

  @override
  String get dmDeleteRefusedDetails => '有些人可能仍然能看到这条消息。';

  @override
  String get dmRetiredThreadClosedTitle => '此对话已关闭。';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      '无法移除此 Divine Moderation 通知。';

  @override
  String get dmRetiredThreadClosedBody =>
      '我们已把 Divine Moderation 迁移到新账号。这个账号已经没人看了。';

  @override
  String get dmRetiredThreadOpenSupport => '给 Divine Moderation 发私信';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => '消息发送失败';

  @override
  String get dmResendFailedMessage => '仍然发送失败';

  @override
  String get dmSendFailedSubtitle => '立即重发，或放弃发送。';

  @override
  String get dmSendFailedRetry => '重试';

  @override
  String get dmSendPartialMessage => '已发送，但未能同步到你的其他设备';

  @override
  String get dmConversationLoadError => '无法加载消息';

  @override
  String get dmMessageInputHint => '说点什么…';

  @override
  String get dmMessageBubbleSentHint => '已发送的消息';

  @override
  String get dmMessageBubbleReceivedHint => '收到的消息';

  @override
  String get dmMessageBubbleLongPressHint => '消息操作';

  @override
  String get dmMessageBubbleFailedTapHint => '重发或删除此消息';

  @override
  String get dmMessageActionCopyText => '复制文本';

  @override
  String get dmMessageActionCopyVideoUrl => '复制视频 URL';

  @override
  String get dmMessageActionDeleteForEveryone => '为所有人删除';

  @override
  String get dmMessageActionReport => '举报';

  @override
  String get dmMessageActionRetrySend => '重发';

  @override
  String get dmMessageActionCancelSend => '放弃发送';

  @override
  String get dmReactionAddCustomA11yLabel => '添加自定义表情回应';

  @override
  String dmReelReplyComposerHint(String name) {
    return '回复 $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => '回复自己…';

  @override
  String get dmReelReplyComposerSemanticLabel => '回复此视频';

  @override
  String get dmReelReplyViewChat => '查看聊天';

  @override
  String get dmReelReplySentAnnouncement => '回复已发送';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return '已回应 $emoji';
  }

  @override
  String get dmReelReplyFailed => '发送失败';

  @override
  String get dmReelReplyUnverified => '无法确认是否已发送';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return '你的回应：$emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name 回应了 $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return '正在发送回应：$emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel => '回应失败，双击重试';

  @override
  String get dmReactionChipRetryAnnouncement => '正在重试回应';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval => '请先完成移除之前的回应，再添加其他回应。';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => '回应';

  @override
  String get dmReactionsViewA11yLabel => '查看谁回应了';

  @override
  String get dmReactionRemoveAction => '移除';

  @override
  String get dmReactionRetryAction => '重试';

  @override
  String get dmFormatBold => '加粗';

  @override
  String get dmFormatItalic => '斜体';

  @override
  String get dmFormatStrikethrough => '删除线';

  @override
  String get dmFormatCode => '代码';

  @override
  String get dmStatusFailed => '发送失败';

  @override
  String get inboxConversationActionsSheetLabel => '会话操作';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '与 $displayName 的会话';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return '未读，与 $displayName 的会话';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$name 和其他 $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => '显示会话操作';

  @override
  String exploreVideoId(String id) {
    return 'ID：$id';
  }

  @override
  String exploreVideoTitle(String title) {
    return '标题：$title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return '视频 $current/$total';
  }

  @override
  String get exploreSearchHint => '搜索...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count 个视频';
  }

  @override
  String get discoverListsFailedToUpdateSubscription => '更新订阅失败，请重试。';

  @override
  String get discoverListsTitle => '发现列表';

  @override
  String get discoverListsFailedToLoad => '列表加载失败';

  @override
  String get discoverListsLoading => '正在发现公开列表...';

  @override
  String get discoverListsRelayTimeout => '中继没有及时返回列表。再试一次。';

  @override
  String get discoverListsServiceUnavailable => '服务不可用。';

  @override
  String get discoverListsEmptyTitle => '没有找到公开列表';

  @override
  String get discoverListsEmptySubtitle => '过会儿再来看看新列表';

  @override
  String get discoverListsByAuthorPrefix => '来自';

  @override
  String get curatedListEmptyTitle => '该列表还没有视频';

  @override
  String get curatedListEmptySubtitle => '加一些视频开始吧';

  @override
  String get curatedListLoadingVideos => '视频加载中...';

  @override
  String get curatedListFailedToLoad => '列表加载失败';

  @override
  String get curatedListVideoNotAvailable => '视频不可用';

  @override
  String get curatedListActionsTooltip => '列表操作';

  @override
  String get curatedListDeleteConfirmTitle => '删除列表？';

  @override
  String get curatedListDeleteConfirmBody => '这会从中继移除该列表。列表中的视频不会被删除。';

  @override
  String get curatedListDeletedSnack => '已删除列表';

  @override
  String get curatedListDeleteFailed => '删除列表失败';

  @override
  String get peopleListsActionsTooltip => '列表操作';

  @override
  String get listDeleteAction => '删除列表';

  @override
  String get peopleListsDeleteConfirmTitle => '删除列表？';

  @override
  String get peopleListsDeleteConfirmBody => '这会为所有人移除该列表。列表中的人不会被取消关注。';

  @override
  String get peopleListsDeleteFailed => '删除列表失败';

  @override
  String get commonRetry => '重试';

  @override
  String get commonSomethingWentWrong => '出了点问题';

  @override
  String get commonDelete => '删除';

  @override
  String get commonCancel => '取消';

  @override
  String get commonBack => '返回';

  @override
  String get commonClose => '关闭';

  @override
  String get commonNotNow => '暂不';

  @override
  String get commonLoading => '加载中';

  @override
  String get videoMetadataEditCoverFailedSnackbar => '封面更新失败，请重试。';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => '封面已更新';

  @override
  String get videoMetadataC2paMissingTitle => '不做“人类创作”验证就发布？';

  @override
  String get videoMetadataC2paMissingBody =>
      '我们没能添加内容凭证，该视频将无法被确认为“人类创作”。重新生成再试一次，或者就这样发布。';

  @override
  String get videoMetadataC2paMissingNote => '添加内容凭证需要网络连接。';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      '内容凭证服务没有响应。这不是你的网络问题。';

  @override
  String get videoMetadataC2paMissingRegenerate => '重新生成';

  @override
  String get videoMetadataC2paMissingSkip => '跳过';

  @override
  String get videoMetadataGenerationFailed => '生成失败';

  @override
  String get videoMetadataTags => '标签';

  @override
  String get videoMetadataExpiration => '有效期';

  @override
  String get videoMetadataExpirationNotExpire => '不过期';

  @override
  String get videoMetadataExpirationOneDay => '1 天';

  @override
  String get videoMetadataExpirationOneWeek => '1 周';

  @override
  String get videoMetadataExpirationOneMonth => '1 个月';

  @override
  String get videoMetadataExpirationOneYear => '1 年';

  @override
  String get videoMetadataExpirationOneDecade => '10 年';

  @override
  String get videoMetadataContentWarnings => '内容警告';

  @override
  String get videoEditorStickers => '贴纸';

  @override
  String get trendingTitle => '热门';

  @override
  String get libraryDeleteConfirm => '删除';

  @override
  String get libraryWebUnavailableHeadline => '请在移动应用中使用作品库';

  @override
  String get libraryWebUnavailableDescription =>
      '草稿和片段都保存在你的设备上，打开手机上的 Divine 就能管理它们。';

  @override
  String get libraryTabDrafts => '草稿';

  @override
  String get libraryTabClips => '片段';

  @override
  String get libraryDeleteSelectedClipsTooltip => '删除选中片段';

  @override
  String get libraryCloseSemanticLabel => '关闭素材库';

  @override
  String get libraryStopSelectingClipsSemanticLabel => '停止选择片段';

  @override
  String get librarySelectClipsSemanticLabel => '选择片段';

  @override
  String get libraryGridSizeLabel => '网格大小';

  @override
  String get libraryDisplayOptionsLabel => '排序和网格大小';

  @override
  String get libraryMoreActionsSemanticLabel => '更多作品库操作';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count列',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => '选择';

  @override
  String get librarySortNewestCreation => '最新创建';

  @override
  String get librarySortOldestCreation => '最早创建';

  @override
  String get librarySortLongestClip => '最长片段';

  @override
  String get librarySortShortestClip => '最短片段';

  @override
  String get librarySortSquareFirst => '方形优先';

  @override
  String get librarySortVerticalFirst => '竖屏优先';

  @override
  String get libraryDeleteClipsWarning => '此操作无法撤销。视频文件将从你的设备上永久删除。';

  @override
  String get libraryPreparingVideo => '正在准备视频...';

  @override
  String libraryCreateVideo(int count) {
    return '创作视频 ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个片段',
      one: '1 个片段',
    );
    return '$_temp0已保存到$destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount 个已保存，$failureCount 个失败';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return '保存到$destination失败';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination权限被拒绝';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已删除 $count 个片段',
      one: '已删除 1 个片段',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => '撤销';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: '$daysLeft 天后自动删除',
      one: '明天自动删除。',
      zero: '今天自动删除。',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => '草稿加载失败';

  @override
  String get libraryCouldNotLoadClips => '片段加载失败';

  @override
  String get libraryOpenErrorDescription => '打开作品库时出了点问题，你可以重试。';

  @override
  String get libraryNoDraftsYetTitle => '还没有草稿';

  @override
  String get libraryNoDraftsYetSubtitle => '存为草稿的视频会显示在这里';

  @override
  String get libraryNoClipsYetTitle => '还没有片段';

  @override
  String get libraryNoClipsYetSubtitle => '你录制的视频片段会显示在这里';

  @override
  String get libraryDraftDeletedSnackbar => '草稿已删除';

  @override
  String get libraryDraftDeleteFailedSnackbar => '删除草稿失败';

  @override
  String get libraryDraftDuplicatedSnackbar => '草稿已复制';

  @override
  String get libraryDraftDuplicateFailedSnackbar => '复制草稿失败';

  @override
  String get libraryDraftInProgressBadge => '进行中';

  @override
  String get libraryDraftActionPost => '发布';

  @override
  String get libraryDraftActionEdit => '编辑';

  @override
  String get libraryDraftActionDuplicate => '创建副本';

  @override
  String get libraryDraftActionDelete => '删除草稿';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title（副本 $number）';
  }

  @override
  String get libraryDeleteDraftTitle => '删除草稿';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '确定要删除“$title”吗？';
  }

  @override
  String get libraryDeleteClipTitle => '删除片段';

  @override
  String get libraryDeleteClipMessage => '确定要删除这个片段吗？';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds 秒';
  }

  @override
  String get libraryRecordVideo => '录制视频';

  @override
  String videoClipSemanticLabel(String duration) {
    return '视频片段，$duration 秒';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return '已归档。$label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return '定格动画片段，$frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return '已选中，第 $position 个';
  }

  @override
  String get videoClipSemanticValueSelected => '已选中';

  @override
  String get videoClipSemanticValueNotSelected => '未选中';

  @override
  String get videoClipSemanticHintDisabled => '已禁用';

  @override
  String get videoClipSemanticHintSelect => '点按选择，长按预览';

  @override
  String get videoClipSemanticHintDeselect => '点按取消选择，长按预览';

  @override
  String get routerInvalidCreator => '无效的创作者';

  @override
  String get routerInvalidHashtagRoute => '无效的话题标签路由';

  @override
  String get categoryGalleryCouldNotLoadVideos => '视频加载失败';

  @override
  String get categoryGalleryNoVideosInCategory => '该分类下还没有视频';

  @override
  String get categoryGallerySortOptionsLabel => '分类排序选项';

  @override
  String get categoryGallerySortHot => '最热';

  @override
  String get categoryGallerySortNew => '最新';

  @override
  String get categoryGallerySortClassic => '经典';

  @override
  String get categoryGallerySortForYou => '为你推荐';

  @override
  String get categoriesCouldNotLoadCategories => '分类加载失败';

  @override
  String get categoriesNoCategoriesAvailable => '暂无分类';

  @override
  String get notificationsEmptyTitle => '还没有动态';

  @override
  String get notificationsEmptySubtitle => '当有人与你的内容互动时，会显示在这里';

  @override
  String get appsPermissionsTitle => '集成权限';

  @override
  String get appsPermissionsRevoke => '撤销';

  @override
  String get appsPermissionsEmptyTitle => '没有已保存的集成权限';

  @override
  String get appsPermissionsEmptySubtitle => '当你记住某个访问授权后，已批准的集成会显示在这里。';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName 请求你的批准';
  }

  @override
  String get nostrAppPermissionDescription => '该应用正在通过 Divine 的审核沙箱请求访问权限。';

  @override
  String get nostrAppPermissionOrigin => '来源';

  @override
  String get nostrAppPermissionMethod => '方法';

  @override
  String get nostrAppPermissionCapability => '能力';

  @override
  String get nostrAppPermissionEventKind => '事件类型';

  @override
  String get nostrAppPermissionAllow => '允许';

  @override
  String get appsDetailDefaultTitle => '集成应用';

  @override
  String get appsDetailNotFoundTitle => '找不到集成';

  @override
  String get appsDetailNotFoundSubtitle => '该已批准的集成在 Divine 中已不可用。';

  @override
  String get appsDetailHowItWorksTitle => '工作原理';

  @override
  String get appsDetailHowItWorksBody =>
      '这是一个获准在 Divine 内运行的第三方应用。Divine 只授予经过审核的能力，并阻止其跳出已批准的来源。';

  @override
  String get appsDetailAboutTitle => '关于';

  @override
  String get appsDetailPrimaryOriginTitle => '主要来源';

  @override
  String get appsDetailApprovedOriginsTitle => '已批准的来源';

  @override
  String get appsDetailCapabilitiesTitle => '可用能力';

  @override
  String get appsDetailAskBeforeTitle => '使用前询问';

  @override
  String get appsDetailOpenButton => '打开集成';

  @override
  String get appsDetailNoneDeclared => '尚未声明';

  @override
  String get appsDirectoryTitle => '集成应用';

  @override
  String get appsDirectoryIntroTitle => '已批准的第三方应用';

  @override
  String get appsDirectoryIntroBody => '获准在 Divine 内运行的第三方应用';

  @override
  String get appsDirectoryErrorTitle => '集成应用加载失败';

  @override
  String get appsDirectoryErrorSubtitle => '下拉重试已批准的集成。';

  @override
  String get appsDirectoryEmptyTitle => '还没有已批准的集成';

  @override
  String get appsDirectoryEmptySubtitle => '随着 Divine 引入更多第三方应用，已批准的应用会显示在这里。';

  @override
  String get appsDirectoryRefresh => '刷新';

  @override
  String get appsDirectoryUnsupportedTitle => '集成应用在 Divine 移动版中运行';

  @override
  String get appsDirectoryUnsupportedSubtitle => '已批准的集成目前仅在移动端可用。';

  @override
  String get appsSandboxUnavailableTitle => '集成不可用';

  @override
  String get appsSandboxUnavailableBody =>
      '请从“集成应用”标签页打开已批准的集成，Divine 才能应用正确的访问策略。';

  @override
  String get appsSandboxLoadingTitle => '正在加载集成';

  @override
  String get appsSandboxLoadingSubtitle => '启动前正在检查该集成是否已获批准。';

  @override
  String get appsSandboxBlockedTitle => '为安全起见已阻止';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return '该集成试图跳出其已批准的来源。\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => '帖子链接已复制到剪贴板';

  @override
  String get shareCopiedEventJson => 'Nostr 事件 JSON 已复制到剪贴板';

  @override
  String get shareCopiedEventId => 'Nostr 事件 ID 已复制到剪贴板';

  @override
  String get authHeroTaglineAuthentic => '真实的瞬间。';

  @override
  String get authHeroTaglineHuman => '人类的创造力。';

  @override
  String get keyImportFailedToImport => '导入密钥或连接 bunker 失败';

  @override
  String get keyImportInvalidBunkerUrl => '无效的 bunker URL';

  @override
  String get keyImportInvalidFormat =>
      '格式无效。请使用 nsec...、hex、ncryptsec1... 或 bunker://...';

  @override
  String get keyImportInvalidNsecFormat => 'nsec 格式无效，应为 63 个字符';

  @override
  String get keyImportKeyFieldLabel => '私钥或 bunker URL';

  @override
  String get keyImportKeyRequired => '请输入你的私钥或 bunker URL';

  @override
  String get keyImportPasswordRequired => '请输入该加密密钥的密码';

  @override
  String get keyImportSecurityWarningBody => '千万不要把私钥分享给任何人。它能完全控制你的 Nostr 身份。';

  @override
  String get keyImportSecurityWarningTitle => '保管好你的私钥！';

  @override
  String get keyImportSubtitle => '用你的私钥或 bunker URL 导入已有的 Nostr 身份。';

  @override
  String get keyImportTitle => '导入你的\nNostr 身份';

  @override
  String get commentAuthorYouIndicator => '你';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return '查看 $name 的主页';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => '删除评论';

  @override
  String get commentOptionsEditSemanticLabel => '编辑评论';

  @override
  String get commentOptionsFlagContentLabel => '标记内容';

  @override
  String get commentOptionsFlagContentSemanticLabel => '标记此内容';

  @override
  String get commentOptionsFlagReasonPrompt => '选择标记该评论的原因';

  @override
  String get commentOptionsFlagSubmit => '提交';

  @override
  String get commentOptionsTitle => '选项';

  @override
  String get commentsEmptyClassicVineMessage => '我们还在从存档中导入旧评论，还没准备好。';

  @override
  String get commentsEmptyClassicVineTitle => '经典 Vine';

  @override
  String get commentsInputEditingLabel => '编辑中';

  @override
  String get commentsInputSemanticHint => '添加评论';

  @override
  String get commentsInputSemanticHintEdit => '编辑评论';

  @override
  String get commentsInputSemanticHintReply => '添加回复';

  @override
  String get commentsInputSemanticLabel => '评论输入框';

  @override
  String get commentsInputSemanticLabelEdit => '编辑输入框';

  @override
  String get commentsInputSemanticLabelReply => '回复输入框';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return '查看 $displayName 的主页';
  }

  @override
  String get classicsEmptyDescription => '经典存档正在加载';

  @override
  String get classicsEmptyTitle => '没有找到经典内容';

  @override
  String get classicsErrorTitle => '经典内容加载失败';

  @override
  String get classicsUnavailableDescription => '只有连接 Funnelcake 中继时才能查看经典内容。';

  @override
  String get classicsUnavailableSettingsHint =>
      '在设置中切换到支持 Funnelcake 的中继，即可访问经典存档。';

  @override
  String get classicsUnavailableTitle => '经典内容不可用';

  @override
  String get hashtagFeedEmptySubtitle => '做第一个用这个话题标签发视频的人！';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return '没有找到 #$hashtag 的视频';
  }

  @override
  String get hashtagFeedLoadingSubtitle => '可能需要一会儿';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return '正在加载 #$hashtag 的视频...';
  }

  @override
  String get hashtagInputHint => '添加话题标签... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => '过会儿再来看看新内容';

  @override
  String get newVideosTabEmptyTitle => '“新视频”里还没有内容';

  @override
  String get popularVideosContextTitle => '热门视频';

  @override
  String get popularVideosEmptySubtitle => '过会儿再来看看新内容';

  @override
  String get popularVideosEmptyTitle => '“热门视频”里还没有内容';

  @override
  String get popularVideosErrorTitle => '热门视频加载失败';

  @override
  String get popularVideosFeedSourceLabel => '热门信息流来源';

  @override
  String get trendingHashtagsLoading => '话题标签加载中...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return '查看标记了 $hashtag 的视频';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return '视频作者：$name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return '视频简介：$description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine 的愿景是给你真正的算法选择权。你不必被困在单一的黑盒算法里，而是可以在多种推荐方式中自由选择：';

  @override
  String get forYouAlgorithmChoiceChronological => '你关注的创作者按时间排序的时间线';

  @override
  String get forYouAlgorithmChoiceClosing =>
      '这把注意力的控制权交还给你，而不是交给平台。你应该知道你的信息流是怎么来的，并且随时可以换。';

  @override
  String get forYouAlgorithmChoiceCustomFeeds => '社区创建的主题自定义信息流，比如音乐、喜剧或艺术';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed => '个性化“为你推荐”信息流';

  @override
  String get forYouAlgorithmChoiceTitle => '你的算法，你做主';

  @override
  String get forYouAlgorithmChoiceTrending => '热门和流行内容';

  @override
  String get forYouAlgorithmCommentsDescription => '强信号——你愿意花心思回应';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine 会留意你与内容的互动方式，以此了解你的喜好。你每看一个视频、点一个回应、留一条评论、转发一次，系统都会记下来。';

  @override
  String get forYouAlgorithmHowItWorksTitle => '工作原理';

  @override
  String get forYouAlgorithmInteractionsIntro => '不同的行为代表不同程度的兴趣：';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      '如果你还没有积累观看历史，我们会混合展示当前热门和最新上传的内容，给你一个很好的探索起点。';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      '随着你观看、点赞和互动，推荐会逐渐变得更懂你。慢慢地，你的“为你推荐”会出现一些你自己可能永远发现不了的创作者。';

  @override
  String get forYouAlgorithmNewToDivineTitle => '刚来 Divine？';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      '我们正在构建一个开放系统：开发者可以实现自己的算法，你可以选择用哪一个——或者干脆不用。';

  @override
  String get forYouAlgorithmOpenSourceTitle => '开源且透明';

  @override
  String get forYouAlgorithmReactionsDescription => '中等信号——快速表达喜欢';

  @override
  String get forYouAlgorithmReactionsTitle => '回应';

  @override
  String get forYouAlgorithmRepostsDescription => '最强信号——分享给你的粉丝是最有力的推荐';

  @override
  String get forYouAlgorithmSubtitle => '由开源推荐引擎 Gorse 驱动';

  @override
  String get forYouAlgorithmTitle => 'Divine 算法';

  @override
  String get forYouAlgorithmViewsDescription => '弱信号——表示基本兴趣';

  @override
  String get forYouEmptyDescription => '多看多点赞一些视频，就能获得个性化推荐。';

  @override
  String get forYouEmptyTitle => '还没有推荐';

  @override
  String get forYouErrorTitle => '推荐加载失败';

  @override
  String get forYouUnavailableDescription => '个性化推荐需要连接 Funnelcake。';

  @override
  String get forYouUnavailableTitle => '“为你推荐”不可用';

  @override
  String get inboxConversationOptionsLabel => '选项';

  @override
  String get inboxConversationViewProfileButton => '查看主页';

  @override
  String get inboxMessageRequestsEmpty => '没有消息请求';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return '消息请求，$requestCount 条待处理';
  }

  @override
  String get inboxMessageRequestsTitle => '消息请求';

  @override
  String get inboxMessagesTab => '消息';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayName 的消息请求';
  }

  @override
  String get inboxRequestTileSubtitle => '发来了消息请求';

  @override
  String get inboxRequestsMarkAllRead => '将所有请求标为已读';

  @override
  String get inboxRequestsRemoveAll => '移除所有请求';

  @override
  String get messageRequestDeclineAndRemoveButton => '拒绝并移除';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return '已拒绝 $displayName 的请求';
  }

  @override
  String get messageRequestLoadFailed => '无法加载此请求。';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count 位粉丝';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count 个视频';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条消息',
      one: '1 条消息',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => '查看消息';

  @override
  String get messageRequestViewProfileButton => '查看主页';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName 想给你发消息，TA 发送了$messageText。';
  }

  @override
  String get deleteAccountAccountChanged =>
      '你切换了账号，因此没有删除任何内容。请为要删除的账号重新打开删除流程。';

  @override
  String get deleteAccountConfirmDeletePrompt => '请输入以下内容确认：';

  @override
  String get deleteAccountConfirmUsernamePrompt => '请输入你的用户名确认：';

  @override
  String get deleteAccountConfirmationHint => '输入 DELETE';

  @override
  String get deleteAccountConfirmationHintUsername => '输入你的用户名';

  @override
  String get deleteAccountDeleteAllContentButton => '删除所有内容';

  @override
  String get accountDeletionRecoveryTitle => '正在删除你的账号';

  @override
  String get accountDeletionRecoveryBody => '我们没能完成账号删除。你的用户名仍为你保留，还可以找回。';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => '找回我的用户名';

  @override
  String get accountDeletionFinishingBody => '你的账号删除请求仍在处理中。处理完成前，你可以使用其他账号。';

  @override
  String get accountDeletionOtherAccountPending =>
      '此设备上另一个账号的删除仍在处理中。请等待处理完成后再删除此账号。';

  @override
  String get accountDeletionCancellingBody => '我们正在取消你的删除请求。离开此页面前请再确认一次。';

  @override
  String get accountDeletionRecoveryFailed => '我们还没能找回你的用户名。请检查网络连接后重试。';

  @override
  String get accountDeletionUsernameRestored => '你的用户名已找回，你的账号未被删除。';

  @override
  String get accountDeletionRecoveryStatusFailed => '我们无法查询你的删除状态。请检查网络连接后重试。';

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
  String get deleteAccountDeletionUnavailable => '账号删除功能目前不可用。未删除任何内容。';

  @override
  String get deleteAccountDeletionIncomplete => '我们没能完成账号删除，请重试。';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ 最终确认';

  @override
  String get deleteAccountKeyDeletionWarning =>
      '删除请求已发送，但你的密钥可能未从此设备完全移除。前往“设置 → Nostr 密钥 → 移除密钥”重试。';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      '删除请求已发送且你已退出登录，但部分本地数据无法从此设备移除。';

  @override
  String get deleteAccountPreparingDeletion => '正在准备删除...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total 个事件';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      '这会从此设备移除此账号的本地登录，不会删除你的 Divine 账号或 Nostr 身份。\n\n你的草稿和片段仍会为此账号保存在此设备上。如果这是最后一个本地账号，你将回到登录页。';

  @override
  String get deleteAccountRemoveKeysConfirm => '从设备移除';

  @override
  String get deleteAccountRemoveKeysTitle => '从此设备移除此账号？';

  @override
  String get deleteAccountReauthRequired => '请重新登录后再删除账号。目前还没有删除任何内容。';

  @override
  String get deleteAccountServerDeletionFailed =>
      '你的帖子删除请求已发送，但我们没能完成账号删除。请稍后再试。';

  @override
  String get deleteAccountSuccess =>
      '你的 Divine 账号已删除。我们已为你的 Nostr 帖子发送删除请求，但部分中继、客户端或缓存可能仍会保留副本。';

  @override
  String get deleteAccountSuccessContentUnverified => '账号删除已请求。部分已有帖子无法逐一确认删除。';

  @override
  String get deleteAccountWarningBody =>
      '这会为你的账号和内容发送删除请求，尽可能删除你的 Divine 账号，并在此设备上退出登录。部分中继、客户端和搜索索引可能保留副本。其他已登录设备会保持登录，直到你在那些设备上移除密钥。';

  @override
  String get findPeopleNoContacts => '没有找到联系人。\n开始关注一些人，他们就会出现在这里。';

  @override
  String get geoBlockedCityLabel => '城市';

  @override
  String get geoBlockedCountryLabel => '国家/地区';

  @override
  String get geoBlockedDefaultReason => '受当地法规限制，该服务在你所在地区不可用。';

  @override
  String get geoBlockedLegalNotice => '我们尊重你当地的法律法规。此限制基于你的 IP 地址所在地。';

  @override
  String get geoBlockedRegionLabel => '地区';

  @override
  String get geoBlockedTitle => '服务不可用';

  @override
  String get likedVideosEmpty => '没有点赞的视频';

  @override
  String get likedVideosInvalidRoute => '无效的路由';

  @override
  String get likedVideosTitle => '点赞的视频';

  @override
  String get uploadFailureSheetRetryingSnackbar => '正在重试上传…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => '存为草稿';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => '已存为草稿';

  @override
  String get uploadFailureSheetTitle => '上传失败';

  @override
  String get uploadFailureSheetTryAgainButton => '再试一次';

  @override
  String get videoEditorAudioImportAudio => '导入音频';

  @override
  String get videoEditorAudioImportFailed => '音频导入失败。';

  @override
  String get videoIconPlaceholderLabel => '视频';

  @override
  String get publishErrorNotSignedIn => '请登录后再发布视频。';

  @override
  String get publishErrorNoRetry => '没有可重试的上传。';

  @override
  String get publishErrorNoInternet => '没有网络连接。请检查 Wi-Fi 或移动数据后重试。';

  @override
  String get publishErrorServerUnreachable => '连不上服务器，请稍后再试。';

  @override
  String get publishErrorTimeout => '上传超时。试试更好的网络，或更小一点的视频。';

  @override
  String get publishErrorTls => '安全连接失败。检查你的网络——公共 Wi-Fi 可能会阻止上传。';

  @override
  String publishErrorServerNotFound(String serverName) {
    return '媒体服务器（$serverName）不可用。你可以在设置中换一个。';
  }

  @override
  String get publishErrorFileTooLarge => '视频文件对服务器来说太大了。试试剪辑一下或降低画质。';

  @override
  String publishErrorServerInternalError(String serverName) {
    return '媒体服务器（$serverName）内部出错。你可以在设置中换一个。';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return '媒体服务器（$serverName）暂时宕机。请稍后再试，或在设置中换一个。';
  }

  @override
  String get publishErrorForbidden => '你没有权限上传到该服务器。';

  @override
  String get publishErrorFileNotFound => '找不到视频文件，可能已被删除。请重新录制后再试。';

  @override
  String get publishErrorLowStorage => '设备存储空间不足。清理一些空间后再试。';

  @override
  String get publishErrorThumbnailFailed => '视频已上传，但缩略图没能准备好。请重试。';

  @override
  String get publishErrorNostrPublishFailed => '视频已上传，但帖子没能发布。请检查你的中继设置后重试。';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      '视频已上传，但这段音频未开放二次使用。换一段音频再发布吧。';

  @override
  String get publishErrorInterrupted => '上传被中断。要重试吗？';

  @override
  String get publishErrorAccountChanged => '这个视频属于另一个账号。切回那个账号才能发布。';

  @override
  String get publishErrorGeneric => '出了点问题，请重试。';

  @override
  String get publishErrorRateLimited => '现在上传太多了。等一会儿再试。';

  @override
  String get publishErrorUploadSessionExpired => '你的上传会话已过期，请重试。';

  @override
  String get publishErrorPermissionDenied => 'Divine 没有上传权限。请在设置中检查应用权限后重试。';

  @override
  String get publishErrorOutOfMemory => '设备内存不足。关掉一些应用后再试。';

  @override
  String get publishErrorOverlaysUnavailable =>
      '这份草稿上的文字和贴纸没能准备好。到编辑器里打开，然后重新发布。';

  @override
  String get publishErrorUnknownServer => '未知服务器';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return '筛选：$filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return '没有找到“$query”的结果';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return '查看标记了 $tag 的视频';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return '声音：$soundName，来自 $creatorName。点按查看声音详情。';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return '$creatorName 的原声。点按使用这个声音。';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return '声音：$soundName，来自 $creatorName。点按查看详情。';
  }

  @override
  String get soundDetailLoadError => '声音加载失败，请重试。';

  @override
  String get soundDetailNotFoundMessage => '找不到这个声音';

  @override
  String get soundDetailNotFoundTitle => '找不到声音';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 循环 $count 次';
  }

  @override
  String get originalSoundUnavailableBody => '该视频的音频不可单独使用。';

  @override
  String originalSoundByCreator(String creatorName) {
    return '原声 - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      '这个人发过一条原版 Vine，被 Divine 在存档里找到了。这不是账号认证徽章。';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => '个人资料对勾';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine 把这个对勾给团队账号。它与 NIP-05、已验证的账号链接和 OG Viner 状态无关。';

  @override
  String get unfollowConfirmButton => '取消关注';

  @override
  String get videoClipSaveFailed => '片段保存失败';

  @override
  String videoClipSaveTo(String destination) {
    return '保存到$destination';
  }

  @override
  String get videoClipDelete => '删除片段';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '灵感来自 $creatorName +$additionalCreatorCount。点按查看 TA 的主页。';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return '灵感来自 $creatorName。点按查看 TA 的主页。';
  }

  @override
  String get bugReportSendReport => '发送报告';

  @override
  String get supportSubjectRequiredLabel => '主题 *';

  @override
  String get supportPublicSubmissionTitle => '公开的 GitHub 帖子';

  @override
  String get supportPublicSubmissionMessage =>
      '你在这里提交的所有内容都会发布到我们在 GitHub 上的开源仓库中，以便开发者处理。该帖子和你登录使用的账号都会被所有人公开查看。';

  @override
  String get supportRequiredHelper => '必填';

  @override
  String get supportFieldLimitReached => '已达到最大长度。超出的部分未被添加。';

  @override
  String get bugReportSubjectHint => '简要概括问题';

  @override
  String get bugReportDescriptionRequiredLabel => '发生了什么？*';

  @override
  String get bugReportDescriptionHint => '描述你遇到的问题';

  @override
  String get bugReportStepsLabel => '复现步骤';

  @override
  String get bugReportStepsHint => '1. 打开...\n2. 点击...\n3. 出现错误';

  @override
  String get bugReportExpectedBehaviorLabel => '预期行为';

  @override
  String get bugReportExpectedBehaviorHint => '本来应该发生什么？';

  @override
  String get bugReportDiagnosticsNotice => '设备信息和日志会自动附上。';

  @override
  String get bugReportSuccessMessage => '谢谢！我们已收到你的报告，会用它来把 Divine 做得更好。';

  @override
  String get bugReportAttachImages => '附加图片';

  @override
  String bugReportImagesCount(int count, int max) {
    return '已选 $count/$max 张图片';
  }

  @override
  String get bugReportRemoveImage => '移除图片';

  @override
  String get bugReportUploadFailed => '所选图片上传失败。重试，或不带图片发送报告。';

  @override
  String get bugReportSendFailed => 'Bug 报告发送失败，请稍后再试。';

  @override
  String get featureRequestSendRequest => '发送请求';

  @override
  String get featureRequestSubjectHint => '简要概括你的想法';

  @override
  String get featureRequestDescriptionRequiredLabel => '你想要什么功能？*';

  @override
  String get featureRequestDescriptionHint => '描述你想要的功能';

  @override
  String get featureRequestUsefulnessLabel => '它会有什么用？';

  @override
  String get featureRequestUsefulnessHint => '说明这个功能会带来什么好处';

  @override
  String get featureRequestWhenLabel => '你会在什么时候用到它？';

  @override
  String get featureRequestWhenHint => '描述一下它会帮上忙的场景';

  @override
  String get featureRequestSuccessMessage => '谢谢！我们已收到你的功能建议，会认真评估。';

  @override
  String get featureRequestSendFailed => '功能建议发送失败，请稍后再试。';

  @override
  String get notificationFollowBack => '回关';

  @override
  String get followingTitle => '关注';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName 的关注';
  }

  @override
  String get followingFailedToLoadList => '关注列表加载失败';

  @override
  String get followingEmptyTitle => '还没有关注任何人';

  @override
  String get followersTitle => '粉丝';

  @override
  String followersTitleForName(String displayName) {
    return '$displayName 的粉丝';
  }

  @override
  String get followersFailedToLoadList => '粉丝列表加载失败';

  @override
  String get followersEmptyTitle => '还没有粉丝';

  @override
  String get followersUpdateFollowFailed => '更新关注状态失败，请重试。';

  @override
  String get followersSortSemanticLabel => '排序粉丝';

  @override
  String get followingSortSemanticLabel => '排序关注';

  @override
  String get followSortTitle => '排序方式';

  @override
  String get followSortNewest => '最新优先';

  @override
  String get followSortOldest => '最早优先';

  @override
  String get newMessageTitle => '新消息';

  @override
  String get newMessageFindPeople => '找人';

  @override
  String get newMessageNoContacts => '没有找到联系人。\n关注一些人，他们就会出现在这里。';

  @override
  String get newMessageNoUsersFound => '没有找到用户';

  @override
  String get hashtagSearchTitle => '搜索话题标签';

  @override
  String get hashtagSearchSubtitle => '发现热门话题和内容';

  @override
  String hashtagSearchNoResults(String query) {
    return '没有找到“$query”相关的话题标签';
  }

  @override
  String get hashtagSearchFailed => '搜索失败';

  @override
  String get userNotAvailableTitle => '账号不可用';

  @override
  String get userNotAvailableBody => '该账号暂时不可用。';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings => '设置保存失败，请重试。';

  @override
  String get blossomValidServerUrl => '请输入有效的服务器 URL（如 https://blossom.band）';

  @override
  String get blossomSettingsSaved => 'Blossom 设置已保存';

  @override
  String get blossomSaveTooltip => '保存';

  @override
  String get blossomAboutTitle => '关于 Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom 是一个去中心化的媒体存储协议，你可以把视频上传到任何兼容的服务器。默认情况下，视频会上传到 Divine 的 Blossom 服务器。开启下方选项即可改用自定义服务器。';

  @override
  String get blossomUseCustomServer => '使用自定义 Blossom 服务器';

  @override
  String get blossomCustomServerEnabledSubtitle => '视频将上传到你的自定义 Blossom 服务器';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      '你的视频当前上传到 Divine 的 Blossom 服务器';

  @override
  String get blossomCustomServerUrl => '自定义 Blossom 服务器 URL';

  @override
  String get blossomCustomServerHelper => '输入你的自定义 Blossom 服务器 URL';

  @override
  String get blossomPopularServers => '热门 Blossom 服务器';

  @override
  String get blossomServerUrlMustUseHttps => 'Blossom 服务器 URL 必须使用 https://';

  @override
  String get blueskyFailedToUpdateCrosspost => '跨平台发布设置更新失败';

  @override
  String get blueskySignInRequired => '登录后即可管理 Bluesky 设置';

  @override
  String get blueskyPublishVideos => '发布视频到 Bluesky';

  @override
  String get blueskyEnabledSubtitle => '你的视频将发布到 Bluesky';

  @override
  String get blueskyDisabledSubtitle => '你的视频不会发布到 Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle => '你以前的视频也会发布';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      '开启后，Divine 会开始把你的旧视频发送到 Bluesky，从最早的视频开始，不会急着用完每日限额。';

  @override
  String get blueskyHandle => 'Bluesky 用户名';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => '状态';

  @override
  String get blueskyStatusReady => '账号已就绪';

  @override
  String get blueskyStatusPending => '账号配置中...';

  @override
  String get blueskyStatusFailed => '账号配置失败';

  @override
  String get blueskyStatusDisabled => '账号已禁用';

  @override
  String get blueskyStatusNotLinked => '未关联 Bluesky 账号';

  @override
  String get blueskyUsernameRequired => '发布到 Bluesky 前，请先设置 divine.video 用户名';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      '发布到 Bluesky 需要一个已注册的 username.divine.video 用户名。';

  @override
  String get blueskyUsernameSyncPending =>
      '你的 Divine 用户名已注册。我们正在将其关联到 Bluesky——请稍后再试。';

  @override
  String get blueskyStatusUnavailableRetry => '无法检查你的 Divine 用户名，请重试。';

  @override
  String get blueskySetUpHandle => '去设置';

  @override
  String get blueskyTemporarilyUnavailable => 'Bluesky 发布暂时不可用，请稍后再试。';

  @override
  String get invitesTitle => '邀请朋友';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个邀请名额可生成',
      one: '1 个邀请名额可生成',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle => '准备好分享时，就生成一个邀请码。';

  @override
  String get invitesGenerateButtonLabel => '生成邀请码';

  @override
  String get invitesNoneAvailable => '暂时没有可用邀请';

  @override
  String get invitesShareWithPeople => '把 Divine 分享给你认识的人';

  @override
  String get invitesUsedInvites => '已使用的邀请';

  @override
  String invitesShareMessage(String code) {
    return '来 Divine 找我玩！使用邀请码 $code 即可开始：\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => '复制邀请';

  @override
  String get invitesCopied => '邀请已复制！';

  @override
  String get invitesShareInvite => '分享邀请';

  @override
  String get invitesShareSubject => '来 Divine 找我玩';

  @override
  String get invitesClaimed => '已使用';

  @override
  String get invitesCouldNotLoad => '邀请加载失败';

  @override
  String get invitesRetry => '重试';

  @override
  String get searchSomethingWentWrong => '出了点问题';

  @override
  String get searchTryAgain => '再试一次';

  @override
  String get searchForLists => '搜索列表';

  @override
  String get searchFindCuratedVideoLists => '寻找策划的视频列表';

  @override
  String get searchEnterQuery => '输入搜索内容';

  @override
  String get searchDiscoverSomethingInteresting => '发现点有意思的东西';

  @override
  String get searchPeopleSectionHeader => '用户';

  @override
  String get searchPeopleLoadingLabel => '正在加载用户结果';

  @override
  String get searchTagsSectionHeader => '标签';

  @override
  String get searchTagsLoadingLabel => '正在加载标签结果';

  @override
  String get searchVideosSectionHeader => '视频';

  @override
  String get searchVideosLoadingLabel => '正在加载视频结果';

  @override
  String get searchVideosSortOptionsLabel => '视频结果排序';

  @override
  String get searchVideosSortTrending => '最热';

  @override
  String get searchVideosSortLoops => '循环最多';

  @override
  String get searchVideosSortEngagement => '互动最多';

  @override
  String get searchVideosSortRecent => '最新';

  @override
  String get searchListsSectionHeader => '列表';

  @override
  String get searchListsLoadingLabel => '正在加载列表结果';

  @override
  String get cameraAgeRestriction => '你必须年满 16 岁才能创作内容';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker 中继必须使用 wss://（仅 localhost 允许 ws://）';

  @override
  String get timeNow => '刚刚';

  @override
  String timeShortMinutes(int count) {
    return '$count分钟';
  }

  @override
  String timeShortHours(int count) {
    return '$count小时';
  }

  @override
  String timeShortDays(int count) {
    return '$count天';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count周';
  }

  @override
  String timeShortMonths(int count) {
    return '$count个月';
  }

  @override
  String timeShortYears(int count) {
    return '$count年';
  }

  @override
  String get timeVerboseNow => '刚刚';

  @override
  String timeAgo(String time) {
    return '$time前';
  }

  @override
  String get timeToday => '今天';

  @override
  String get timeYesterday => '昨天';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get draftTimeJustNow => '刚刚';

  @override
  String get contentLabelNudity => '裸露';

  @override
  String get contentLabelSexualContent => '性内容';

  @override
  String get contentLabelPornography => '色情内容';

  @override
  String get contentLabelGraphicMedia => '引人不适画面';

  @override
  String get contentLabelViolence => '暴力';

  @override
  String get contentLabelSelfHarm => '自残/自杀';

  @override
  String get contentLabelDrugUse => '药物滥用';

  @override
  String get contentLabelAlcohol => '酒精';

  @override
  String get contentLabelTobacco => '烟草/吸烟';

  @override
  String get contentLabelGambling => '赌博';

  @override
  String get contentLabelProfanity => '粗口';

  @override
  String get contentLabelHateSpeech => '仇恨言论';

  @override
  String get contentLabelHarassment => '骚扰';

  @override
  String get contentLabelFlashingLights => '闪烁灯光';

  @override
  String get contentLabelAiGenerated => 'AI 生成';

  @override
  String get contentLabelDeepfake => '深度伪造';

  @override
  String get contentLabelSpam => '垃圾信息';

  @override
  String get contentLabelScam => '诈骗/欺诈';

  @override
  String get contentLabelSpoiler => '剧透';

  @override
  String get contentLabelMisleading => '误导性内容';

  @override
  String get contentLabelSensitiveContent => '敏感内容';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName 点赞了你的视频';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName 点赞了你的评论';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName 评论了你的视频';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName 开始关注你';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName 提到了你';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName 转发了你的视频';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName 发布了新视频';
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
      other: '你的 $count 个 vine',
      one: '你的 vine',
    );
    return '$actorName 将$_temp0添加到了 $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName 回复了你的评论';
  }

  @override
  String get notificationAndConnector => '和';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '另外 $count 人',
      one: '另外 1 人',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => '你有一个新的更新';

  @override
  String get commentReplyToPrefix => '回复:';

  @override
  String get commentHideKeyboard => '收起键盘';

  @override
  String get commentsErrorLoadFailed => '评论加载失败';

  @override
  String get commentsErrorNotAuthenticatedComment => '请登录后再评论';

  @override
  String get commentsErrorPostCommentFailed => '评论发布失败';

  @override
  String get commentsErrorPostReplyFailed => '回复发布失败';

  @override
  String get commentsErrorEditFailed => '评论编辑失败';

  @override
  String get commentsErrorNotAuthenticatedInteract => '请登录后再互动';

  @override
  String get commentsErrorVoteFailed => '评论投票失败';

  @override
  String get commentsErrorReportFailed => '评论举报失败';

  @override
  String get commentsErrorBlockFailed => '屏蔽用户失败';

  @override
  String get commentsErrorDeleteFailed => '评论删除失败';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条评论',
      one: '$count 条评论',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => '发布中…';

  @override
  String get commentsVideoReplyPendingSemanticLabel => '正在发布你的视频回复';

  @override
  String get commentsSortNew => '最新';

  @override
  String get commentsSortTop => '最热';

  @override
  String get commentsSortOld => '最早';

  @override
  String get commentsSortSemanticLabel => '评论排序';

  @override
  String get commentReply => '回复';

  @override
  String get commentReplySemanticLabel => '回复评论';

  @override
  String get commentUpvoteLabel => '顶这条评论';

  @override
  String get commentRemoveUpvoteLabel => '取消顶';

  @override
  String get commentDownvoteLabel => '踩这条评论';

  @override
  String get commentRemoveDownvoteLabel => '取消踩';

  @override
  String get commentsInputHint => '说点什么...';

  @override
  String get commentsInputHintEdit => '编辑评论...';

  @override
  String get commentsEmptyTitle => '还没有评论';

  @override
  String get commentsEmptySubtitle => '来开个头吧！';

  @override
  String get draftUntitled => '未命名';

  @override
  String get contentWarningNone => '无';

  @override
  String get textBackgroundNone => '无';

  @override
  String get textBackgroundSolid => '纯色';

  @override
  String get textBackgroundHighlight => '高亮';

  @override
  String get textBackgroundTransparent => '透明';

  @override
  String get textAlignLeft => '左对齐';

  @override
  String get textAlignRight => '右对齐';

  @override
  String get textAlignCenter => '居中';

  @override
  String get cameraPermissionWebUnsupportedTitle => '网页版暂不支持相机';

  @override
  String get cameraPermissionWebUnsupportedDescription => '网页版暂时无法拍摄和录制视频。';

  @override
  String get cameraPermissionBackToFeed => '返回信息流';

  @override
  String get cameraCouldNotStart => '无法启动相机';

  @override
  String get cameraUnsupportedPlatform => '此平台暂不支持相机。\n你仍然可以浏览和观看视频。';

  @override
  String get cameraPermissionErrorTitle => '权限错误';

  @override
  String get cameraPermissionErrorDescription => '检查权限时出了点问题。';

  @override
  String get cameraPermissionRetry => '重试';

  @override
  String get cameraPermissionAllowAccessTitle => '允许访问相机和麦克风';

  @override
  String get cameraPermissionAllowAccessDescription =>
      '这样你就能在应用里直接拍摄和剪辑视频，仅此而已。';

  @override
  String get cameraPermissionGoToSettings => '去设置';

  @override
  String get videoRecorderWhySixSecondsTitle => '为什么是六秒？';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      '短片段给即兴发挥留了空间。6 秒的格式帮你捕捉当下真实发生的瞬间。';

  @override
  String get videoRecorderWhySixSecondsButton => '懂了！';

  @override
  String get videoRecorderUploadTitle => '为什么不能上传？';

  @override
  String get videoRecorderUploadBody =>
      '你在 Divine 上看到的一切都是人类创作的：原汁原味、当下捕捉。不像那些允许精修制作或 AI 生成上传的平台，我们把相机直出的真实感放在第一位。';

  @override
  String get videoRecorderUploadBodyDetail =>
      '把创作留在应用内，我们能更好地保证内容是真实、未经剪辑的。为了守护这份真实，尽最大努力让社区远离合成内容，我们目前不会开放外部相册上传。';

  @override
  String get videoRecorderUploadBodyCta => '切换到“拍摄”或“经典”模式，拍点真东西。';

  @override
  String get videoRecorderUploadLearnMore => '了解验证的工作原理';

  @override
  String get videoRecorderAutosaveFoundTitle => '发现有未完成的作品';

  @override
  String get videoRecorderAutosaveFoundSubtitle => '要从上次停下的地方继续吗？';

  @override
  String get videoRecorderAutosaveContinueButton => '好，继续';

  @override
  String get videoRecorderAutosaveDiscardButton => '不了，拍个新的';

  @override
  String get videoRecorderAutosaveRestoreFailure => '无法恢复你的草稿';

  @override
  String get videoRecorderStopRecordingTooltip => '停止录制';

  @override
  String get videoRecorderStartRecordingTooltip => '开始录制';

  @override
  String get videoRecorderRecordingTapToStopLabel => '录制中。点按任意处停止';

  @override
  String get videoRecorderTapToStartLabel => '点按任意处开始录制';

  @override
  String get videoRecorderDeleteLastClipLabel => '删除最后一段';

  @override
  String get videoRecorderSwitchCameraLabel => '切换摄像头';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return '变焦到 $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => '切换网格';

  @override
  String get videoRecorderToggleGhostFrameLabel => '切换洋葱皮';

  @override
  String get videoRecorderGhostFrameEnabled => '洋葱皮已开启';

  @override
  String get videoRecorderGhostFrameDisabled => '洋葱皮已关闭';

  @override
  String get videoRecorderClipDeletedMessage => '片段已移入回收站';

  @override
  String get videoRecorderClipUndoLabel => '撤销';

  @override
  String get libraryTrashEmptyTitle => '回收站是空的';

  @override
  String get libraryTrashEmptySubtitle => '删除的片段会在这里保留 30 天，之后彻底删除。';

  @override
  String get libraryTrashRestoreLabel => '恢复';

  @override
  String get libraryTrashDeleteNowLabel => '立即删除';

  @override
  String get libraryTrashEmptyAllLabel => '清空回收站';

  @override
  String get libraryTrashDeleteConfirmTitle => '立即删除片段？';

  @override
  String get libraryTrashDeleteConfirmMessage => '这会立刻把片段从回收站移除。';

  @override
  String get libraryTrashEmptyConfirmTitle => '清空回收站？';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个片段',
      one: '1 个片段',
    );
    return '这会立刻从回收站永久删除$_temp0。';
  }

  @override
  String get videoRecorderCloseLabel => '关闭录像机';

  @override
  String get videoRecorderContinueToEditorLabel => '进入视频编辑器';

  @override
  String get videoRecorderCameraPreviewLabel => '相机预览';

  @override
  String get videoRecorderCameraPreviewFocusHint => '相机对焦';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return '切换到$mode模式';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => '录制前请先添加音频';

  @override
  String get videoRecorderStopMotionAssembleFailed => '无法生成视频，请重试。';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还剩 $count 张',
      zero: '没有剩余张数',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => '切换闪光灯';

  @override
  String get videoRecorderCycleTimerLabel => '切换倒计时';

  @override
  String get videoRecorderToggleAspectRatioLabel => '切换宽高比';

  @override
  String get videoRecorderStabilizationLabel => '防抖';

  @override
  String get videoRecorderStabilizationModeOff => '关闭';

  @override
  String get videoRecorderStabilizationModeStandard => '标准';

  @override
  String get videoRecorderStabilizationModeCinematic => '电影感';

  @override
  String get videoRecorderStabilizationModeCinematicExtended => '增强电影感';

  @override
  String get videoRecorderStabilizationModePreviewOptimized => '预览优化';

  @override
  String get videoRecorderStabilizationModeLowLatency => '低延迟';

  @override
  String get videoRecorderStabilizationModeAuto => '自动';

  @override
  String get videoRecorderFlashValueOff => '关闭';

  @override
  String get videoRecorderFlashValueOn => '开启';

  @override
  String get videoRecorderFlashValueAuto => '自动';

  @override
  String get videoRecorderTimerValueOff => '关闭';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3秒';

  @override
  String get videoRecorderTimerValueTenSeconds => '10秒';

  @override
  String get videoRecorderAspectRatioValueSquare => '正方形';

  @override
  String get videoRecorderAspectRatioValueVertical => '竖屏';

  @override
  String get videoRecorderCameraValueFront => '前置摄像头';

  @override
  String get videoRecorderCameraValueBack => '后置摄像头';

  @override
  String get videoRecorderLibraryEmptyLabel => '片段库，没有片段';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: '打开片段库，$clipCount 个片段',
      one: '打开片段库，1 个片段',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: '打开定格动画库，$frameCount 帧',
      one: '打开定格动画库，1 帧',
      zero: '打开定格动画库，0 帧',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => '相机';

  @override
  String get videoEditorOpenCameraSemanticLabel => '打开相机';

  @override
  String get videoEditorLibraryLabel => '作品库';

  @override
  String get videoEditorTextLabel => '文字';

  @override
  String get videoEditorDrawLabel => '涂鸦';

  @override
  String get videoEditorFilterLabel => '滤镜';

  @override
  String get videoEditorTuneLabel => '调节';

  @override
  String get videoEditorOpenTuneSemanticLabel => '打开调节编辑器';

  @override
  String get videoEditorTuneBrightness => '亮度';

  @override
  String get videoEditorTuneContrast => '对比度';

  @override
  String get videoEditorTuneSaturation => '饱和度';

  @override
  String get videoEditorTuneExposure => '曝光';

  @override
  String get videoEditorTuneHue => '色相';

  @override
  String get videoEditorTuneTemperature => '色温';

  @override
  String get videoEditorTuneTint => '色调';

  @override
  String get videoEditorTuneFade => '褪色';

  @override
  String get videoEditorAudioLabel => '音频';

  @override
  String get videoEditorAddTitle => '添加';

  @override
  String get videoEditorOpenLibrarySemanticLabel => '打开作品库';

  @override
  String get videoEditorOpenAudioSemanticLabel => '打开音频编辑器';

  @override
  String get videoEditorCaptionsLabel => '字幕';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => '打开字幕编辑器';

  @override
  String get videoEditorCaptionsBurnInLabel => '烧录进视频';

  @override
  String get videoEditorCaptionsPresetCustom => '自定义';

  @override
  String get videoEditorCaptionsCustomStyleTitle => '自定义样式';

  @override
  String get videoEditorCaptionsCustomApply => '应用';

  @override
  String get videoEditorCaptionsCustomFont => '字体';

  @override
  String get videoEditorCaptionsCustomTextColor => '文字颜色';

  @override
  String get videoEditorCaptionsCustomBackground => '背景';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => '背景颜色';

  @override
  String get videoEditorCaptionsCustomAnimation => '动画';

  @override
  String get videoEditorCaptionsAnimationNone => '无';

  @override
  String get videoEditorCaptionsAnimationFade => '淡入淡出';

  @override
  String get videoEditorCaptionsAnimationPop => '弹出';

  @override
  String get videoEditorCaptionsAnimationSpring => '弹跳';

  @override
  String get videoEditorCaptionsEditTitle => '字幕';

  @override
  String get videoEditorCaptionsGeneratingTitle => '正在识别语音…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle => '正在把你的音频转成字幕建议。';

  @override
  String get videoEditorCaptionsNoSpeechMessage => '我们没有听到任何语音。你仍然可以手动写字幕。';

  @override
  String get videoEditorCaptionsUnavailableMessage => '此设备不支持语音识别。你可以手动写字幕。';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      '语音识别未获授权。在设置中开启，或手动写字幕。';

  @override
  String get videoEditorCaptionsFailedMessage => '这次转写没成功。你可以手动写字幕。';

  @override
  String get videoEditorCaptionsStartEmptyButton => '自己写字幕';

  @override
  String get videoEditorCaptionsAddCue => '添加字幕';

  @override
  String get videoEditorCaptionsCueTextHint => '字幕文本';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => '删除字幕';

  @override
  String get videoEditorCaptionsDeleteTrack => '移除所有字幕';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => '移除字幕？';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle => '所有字幕文本和时间轴都会消失。';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => '关闭字幕编辑器';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => '确认字幕';

  @override
  String get videoEditorCaptionsPresetTitle => '字幕样式';

  @override
  String get videoEditorCaptionsPresetClassic => '经典';

  @override
  String get videoEditorCaptionsPresetPop => '波普';

  @override
  String get videoEditorCaptionsPresetZoom => '缩放';

  @override
  String get videoEditorCaptionsPresetSpring => '弹跳';

  @override
  String get videoEditorCaptionsPresetMono => '等宽';

  @override
  String get videoEditorCaptionsPresetHeadline => '标题';

  @override
  String get videoEditorCaptionsPresetTypewriter => '打字机';

  @override
  String get videoEditorCaptionsPresetMarker => '马克笔';

  @override
  String get videoEditorCaptionsPresetScript => '手写体';

  @override
  String get videoEditorCaptionsPresetRetro => '复古';

  @override
  String get videoEditorCaptionsPresetElegant => '优雅';

  @override
  String get videoEditorCaptionsPresetBubble => '泡泡';

  @override
  String get videoEditorCaptionsPresetNeon => '霓虹';

  @override
  String get videoEditorCaptionsPresetBold => '粗体';

  @override
  String get videoEditorCaptionsPresetDreamy => '梦幻';

  @override
  String get videoEditorCaptionsPresetOcean => '海洋';

  @override
  String get videoEditorCaptionsPresetSunny => '阳光';

  @override
  String get videoEditorCaptionsPresetHandwritten => '手写';

  @override
  String get videoEditorCaptionsPresetSerif => '衬线';

  @override
  String get videoEditorCaptionsPresetStamp => '印章';

  @override
  String get videoEditorOpenTextSemanticLabel => '打开文字编辑器';

  @override
  String get videoEditorOpenDrawSemanticLabel => '打开涂鸦编辑器';

  @override
  String get videoEditorOpenFilterSemanticLabel => '打开滤镜编辑器';

  @override
  String get videoEditorOpenStickerSemanticLabel => '打开贴纸编辑器';

  @override
  String get videoEditorSaveDraftTitle => '保存草稿？';

  @override
  String get videoEditorSaveDraftSubtitle => '把编辑内容留到以后，或丢弃并离开编辑器。';

  @override
  String get videoEditorSaveDraftButton => '保存草稿';

  @override
  String get videoEditorDiscardChangesButton => '丢弃修改';

  @override
  String get videoEditorKeepEditingButton => '继续编辑';

  @override
  String get videoEditorDeleteLayerDropZone => '删除图层放置区';

  @override
  String get videoEditorReleaseToDeleteLayer => '松开删除图层';

  @override
  String get videoEditorDoneLabel => '完成';

  @override
  String get videoEditorPlayPauseSemanticLabel => '播放或暂停视频';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return '分割位置无效。两段都必须至少 ${minDurationMs}ms 长。';
  }

  @override
  String get videoEditorSaveSelectedClip => '保存选中片段';

  @override
  String get videoEditorSaveClip => '保存片段';

  @override
  String get videoEditorClipSavedSuccess => '片段已保存到作品库';

  @override
  String get videoEditorClipSaveFailed => '片段保存失败';

  @override
  String get videoEditorColorPickerSemanticLabel => '取色器';

  @override
  String get videoEditorUndoSemanticLabel => '撤销';

  @override
  String get videoEditorRedoSemanticLabel => '重做';

  @override
  String get videoEditorTextColorSemanticLabel => '文字颜色';

  @override
  String get videoEditorTextAlignmentSemanticLabel => '文字对齐';

  @override
  String get videoEditorTextBackgroundSemanticLabel => '文字背景';

  @override
  String get videoEditorFontSemanticLabel => '字体';

  @override
  String get videoEditorNoStickersFound => '没有找到贴纸';

  @override
  String get videoEditorNoStickersAvailable => '暂无贴纸';

  @override
  String get videoEditorFailedLoadStickers => '贴纸加载失败';

  @override
  String get videoEditorVoiceOverLabel => '配音';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return '录音 $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => '录制配音';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => '开始录制';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => '停止录制';

  @override
  String get videoEditorVoiceOverHint => '点按录制。想录几条就录几条。';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条录音',
      one: '1 条录音',
      zero: '0 条录音',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => '删除最后一条录音';

  @override
  String get videoEditorVoiceOverPermissionTitle => '需要麦克风权限';

  @override
  String get videoEditorVoiceOverPermissionBody => '允许访问麦克风才能录制配音。';

  @override
  String get videoEditorVoiceOverOpenSettings => '打开设置';

  @override
  String get videoEditorVoiceOverRecordingStarted => '录制已开始';

  @override
  String get videoEditorVoiceOverRecordingSaved => '录音已保存';

  @override
  String get videoEditorVoiceOverTooLong => '录音比你的视频还长';

  @override
  String get videoEditorPlaySemanticLabel => '播放';

  @override
  String get videoEditorPauseSemanticLabel => '暂停';

  @override
  String get videoEditorVolumeSemanticLabel => '调节音量';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return '音量 $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => '滑动调节';

  @override
  String get videoEditorChromaKeyLabel => '绿幕';

  @override
  String get videoEditorChromaKeyTitle => '绿幕';

  @override
  String get videoEditorChromaKeySemanticLabel => '为这个片段设置绿幕';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel => '放弃绿幕改动';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => '应用绿幕';

  @override
  String get videoEditorChromaKeyAutoDetect => '自动识别';

  @override
  String get videoEditorChromaKeyPresetGreen => '绿色';

  @override
  String get videoEditorChromaKeyPresetBlue => '蓝色';

  @override
  String get videoEditorChromaKeyScreenColorLabel => '幕布颜色';

  @override
  String get videoEditorChromaKeyAmountLabel => '强度';

  @override
  String get videoEditorChromaKeyAmountHint => '幕布颜色被抠掉多少';

  @override
  String get videoEditorChromaKeyEdgeLabel => '边缘';

  @override
  String get videoEditorChromaKeyEdgeHint => '让抠像边缘更柔和，头发不会毛刺';

  @override
  String get videoEditorChromaKeySpillLabel => '溢色';

  @override
  String get videoEditorChromaKeySpillHint => '把幕布的颜色从主体上去掉';

  @override
  String get videoEditorChromaKeyBackgroundLabel => '替换为';

  @override
  String get videoEditorChromaKeyBackgroundNone => '无';

  @override
  String get videoEditorChromaKeyBackgroundColor => '颜色';

  @override
  String get videoEditorChromaKeyBackgroundImage => '图片';

  @override
  String get videoEditorChromaKeyBackgroundVideo => '片段';

  @override
  String get videoEditorChromaKeyTransparentHint => '视频存不了透明，所以导出会是黑色。';

  @override
  String get videoEditorChromaKeyDetectFailed => '没找到幕布。幕布得铺到画面边缘——不然就手动选颜色吧。';

  @override
  String get videoEditorChromaKeyPickClipTitle => '选个片段';

  @override
  String get videoEditorChromaKeyNoLibraryClips => '作品库是空的。先存一个片段，就能拿它当背景了。';

  @override
  String get videoEditorChromaKeyImagePickFailed => '这张图片加载不了。';

  @override
  String get videoEditorChromaKeyRemove => '移除绿幕';

  @override
  String get videoEditorChromaKeyFailed => '绿幕没能应用。你的片段没有改动。';

  @override
  String get videoEditorChromaKeyRemoveFailed => '绿幕没能移除。你的片段没有改动。';

  @override
  String get videoEditorChromaKeyApplying => '正在应用绿幕…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      '这台设备无法显示实时预览。导出时你的设置仍然生效。';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return '片段 $index';
  }

  @override
  String get videoEditorDeleteLabel => '删除';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => '删除选中项';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => '每图帧数';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 帧',
      one: '1 帧',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => '帧数';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '每图 $count 帧';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return '定格动画第 $position 帧，共 $total 帧';
  }

  @override
  String get videoEditorEditLabel => '编辑';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => '编辑选中项';

  @override
  String get videoEditorDuplicateLabel => '创建副本';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel => '复制选中项';

  @override
  String get videoEditorCombineLabel => '合并';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel => '把选中的涂鸦合并为一个图层';

  @override
  String get videoEditorSplitLabel => '分割';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => '分割选中片段';

  @override
  String get videoEditorExtractAudioLabel => '提取音频';

  @override
  String get videoEditorClipAudioTitle => '片段音频';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel => '从片段提取音频并静音原声';

  @override
  String get videoEditorExtractAudioNoLocalFile => '无法提取音频：片段不在本地。';

  @override
  String get videoEditorExtractAudioFailed => '无法提取音频，请重试。';

  @override
  String get videoEditorSpeedLabel => '速度';

  @override
  String get videoEditorSetClipSpeedSemanticLabel => '设置选中片段的播放速度';

  @override
  String get videoEditorReverseLabel => '倒放';

  @override
  String get videoEditorReverseClipSemanticLabel => '切换选中片段的倒放';

  @override
  String get videoEditorReverseProgressLabel => '稍等，正在倒放你的片段';

  @override
  String get videoEditorTransformLabel => '变换';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel => '裁剪、旋转或翻转选中片段';

  @override
  String get videoEditorTransformProgressLabel => '稍等，正在变换你的片段';

  @override
  String get videoEditorTransformFailed => '无法变换片段，请重试。';

  @override
  String get videoEditorTransformNoLocalFile => '无法变换：片段不在本地。';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel => '裁剪、旋转或翻转选中帧';

  @override
  String get videoEditorTransformFrameProgressLabel => '稍等，正在处理你的帧';

  @override
  String get videoEditorTransformFrameFailed => '无法处理该帧，请重试。';

  @override
  String get videoEditorTransformRotateLabel => '旋转';

  @override
  String get videoEditorTransformFlipLabel => '翻转';

  @override
  String get videoEditorTransformResetLabel => '重置';

  @override
  String get videoEditorTransformApplySemanticLabel => '应用变换';

  @override
  String get videoEditorTransformCancelSemanticLabel => '取消变换';

  @override
  String get videoEditorTransformPlayLabel => '播放';

  @override
  String get videoEditorTransformPauseLabel => '暂停';

  @override
  String get videoEditorReverseNoLocalFile => '无法倒放：片段不在本地。';

  @override
  String get videoEditorReverseFailed => '无法倒放片段，请重试。';

  @override
  String get videoEditorSpeedSheetTitle => '片段速度';

  @override
  String get videoEditorTransitionSheetTitle => '转场';

  @override
  String get videoEditorTransitionNone => '无';

  @override
  String get videoEditorTransitionDissolve => '叠化';

  @override
  String get videoEditorTransitionFadeToBlack => '淡入黑场';

  @override
  String get videoEditorTransitionFadeToWhite => '淡入白场';

  @override
  String get videoEditorTransitionSlide => '滑动';

  @override
  String get videoEditorTransitionPush => '推入';

  @override
  String get videoEditorTransitionWipe => '擦除';

  @override
  String get videoEditorTransitionButtonSemanticLabel => '编辑转场';

  @override
  String get videoEditorLoopTransitionSheetTitle => '循环转场';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel => '编辑循环转场';

  @override
  String get videoEditorTransitionDuration => '时长';

  @override
  String get videoEditorTransitionDurationLimitedHint => '已缩短，避免与相邻转场重叠。';

  @override
  String get videoEditorTransitionCurve => '曲线';

  @override
  String get videoEditorTransitionDirection => '方向';

  @override
  String get videoEditorTransitionDirectionLeft => '向左';

  @override
  String get videoEditorTransitionDirectionRight => '向右';

  @override
  String get videoEditorTransitionDirectionUp => '向上';

  @override
  String get videoEditorTransitionDirectionDown => '向下';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return '缓动曲线 $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => '动画';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel => '编辑图层动画';

  @override
  String get videoEditorLayerAnimationEnter => '入场';

  @override
  String get videoEditorLayerAnimationLeave => '出场';

  @override
  String get videoEditorLayerAnimationFade => '淡入淡出';

  @override
  String get videoEditorLayerAnimationScale => '缩放';

  @override
  String get videoEditorLayerAnimationScaleFrom => '起始缩放';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel => '完成时间线编辑';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => '播放预览';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => '暂停预览';

  @override
  String get videoEditorAudioUntitledSound => '未命名声音';

  @override
  String get videoEditorAudioUntitled => '未命名';

  @override
  String get videoEditorAudioAddAudio => '添加音频';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => '暂无声音';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle => '创作者分享音频后，声音会显示在这里';

  @override
  String get videoEditorAudioFailedToLoadTitle => '声音加载失败';

  @override
  String get videoEditorAudioSegmentInstruction => '为你的视频选择音频片段';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => '社区';

  @override
  String get videoEditorAudioCategoryFeatured => '精选';

  @override
  String get videoEditorAudioCategoryMySounds => '我的声音';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => '箭头工具';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => '橡皮擦工具';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => '马克笔工具';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => '铅笔工具';

  @override
  String get videoEditorShowTimelineSemanticLabel => '显示时间线';

  @override
  String get videoEditorHideTimelineSemanticLabel => '隐藏时间线';

  @override
  String get videoEditorFeedPreviewContent => '避免把内容放在这些区域后面。';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine 原创';

  @override
  String get videoEditorStickerSearchHint => '搜索贴纸...';

  @override
  String get videoEditorSelectFontSemanticLabel => '选择字体';

  @override
  String get videoEditorFontUnknown => '未知';

  @override
  String get videoEditorSplitPlayheadOutsideClip => '播放头必须在选中的片段内才能分割。';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => '修剪开头';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => '修剪结尾';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => '修剪片段';

  @override
  String get videoEditorTimelineTrimClipHint => '拖动手柄调整片段时长';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return '正在拖动片段 $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return '片段 $index/$total，$duration 秒';
  }

  @override
  String get videoEditorTimelineClipReorderHint => '长按重新排序';

  @override
  String get videoEditorTimelineClipMoveLeft => '左移';

  @override
  String get videoEditorTimelineClipMoveRight => '右移';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return '片段 $index/$total，已选中';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return '片段 $index/$total，未选中';
  }

  @override
  String get videoEditorMultiSelectLabel => '选择';

  @override
  String get videoEditorMultiSelectSemanticLabel => '选择多个片段';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => '完成片段选择';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选中 $count 个片段',
      one: '已选中 1 个片段',
      zero: '已选中 0 个片段',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel => '选择多个涂鸦';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel => '完成涂鸦选择';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel => '删除选中涂鸦';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选中 $count 个涂鸦',
      one: '已选中 1 个涂鸦',
      zero: '已选中 0 个涂鸦',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => '合并';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel => '合并选中片段';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel => '删除选中片段';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel => '删除选中帧';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel => '倒放选中帧';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel => '复制选中帧';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return '视频至少需要 $seconds 秒——再多拍几帧吧。';
  }

  @override
  String get videoEditorMergeProgressLabel => '稍等，正在合并你的片段';

  @override
  String get videoEditorMergeFailed => '无法合并片段，请重试。';

  @override
  String get videoEditorTimelineLongPressToDragHint => '长按拖动';

  @override
  String get videoEditorVideoTimelineSemanticLabel => '视频时间线';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes分 $seconds秒';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName，已选中';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => '关闭取色器';

  @override
  String get videoEditorPickColorTitle => '选取颜色';

  @override
  String get videoEditorConfirmColorSemanticLabel => '确认颜色';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => '饱和度和亮度';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return '饱和度 $saturation%，亮度 $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => '色相';

  @override
  String get videoEditorAddElementSemanticLabel => '添加元素';

  @override
  String get videoEditorDoneSemanticLabel => '完成';

  @override
  String get videoEditorLevelSemanticLabel => '层级';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel => '关闭帖子详情';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => '关闭帮助对话框';

  @override
  String get videoMetadataGotItButton => '懂了！';

  @override
  String get videoMetadataLimitReachedWarning => '已达 64KB 上限。请删减一些内容再继续。';

  @override
  String get videoMetadataExpirationLabel => '有效期';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => '选择有效期';

  @override
  String get videoMetadataTitleLabel => '标题';

  @override
  String get videoMetadataDescriptionLabel => '简介';

  @override
  String get videoMetadataTagsLabel => '标签';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return '删除标签 $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => '添加内容警告';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel => '选择内容警告';

  @override
  String get videoMetadataContentWarningSelectAllThatApply => '选择所有适用项';

  @override
  String get videoMetadataAudioReuseSubtitle => '让其他人保存并二次使用这个视频的音频。';

  @override
  String get publishAudioReuseDegradedWarning => '你的视频已发布，但声音未能发布。编辑视频以分享声音。';

  @override
  String get videoMetadataCollaboratorsLabel => '添加协作者';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => '邀请协作者';

  @override
  String get videoMetadataMutualFollowersSearchText => '互相关注的人';

  @override
  String get videoMetadataInspiredByLabel => '添加灵感来源';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => '设置灵感来源';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar => '无法引用该创作者。';

  @override
  String get videoMetadataPostDetailsTitle => '帖子详情';

  @override
  String get videoMetadataSavedToLibrarySnackbar => '已保存到作品库';

  @override
  String get videoMetadataFailedToSaveSnackbar => '保存失败';

  @override
  String get videoMetadataGoToLibraryButton => '前往作品库';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => '稍后发布按钮';

  @override
  String get videoMetadataSavingVideoHint => '正在保存视频...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return '把视频保存到草稿和$destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return '把视频保存到草稿。还没有渲染好的视频，因此不会保存到$destination。';
  }

  @override
  String get videoMetadataSaveForLaterButton => '稍后发布';

  @override
  String get videoMetadataPostSemanticLabel => '发布按钮';

  @override
  String get videoMetadataPublishVideoHint => '发布视频到信息流';

  @override
  String get videoMetadataShareReplyToFeedTitle => '同时分享到我的信息流';

  @override
  String get videoMetadataShareReplyToFeedSubtitle => '关闭后，该视频只出现在评论区内。';

  @override
  String get videoMetadataFormNotReadyHint => '填写表单后即可启用';

  @override
  String get videoMetadataPostButton => '发布';

  @override
  String get videoMetadataOpenPreviewSemanticLabel => '打开帖子预览页';

  @override
  String get videoMetadataShareTitle => '分享';

  @override
  String get videoMetadataVideoDetailsSubtitle => '视频详情';

  @override
  String get videoMetadataClassicDoneButton => '完成';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => '播放预览';

  @override
  String get videoMetadataPausePreviewSemanticLabel => '暂停预览';

  @override
  String get videoMetadataClosePreviewSemanticLabel => '关闭视频预览';

  @override
  String get videoMetadataRemoveSemanticLabel => '移除';

  @override
  String get fullscreenFeedRemovedMessage => '视频已移除';

  @override
  String get fullscreenFeedEmptyMessage => '这里没有可播放的内容了';

  @override
  String get settingsBadgesTitle => '徽章';

  @override
  String get settingsBadgesSubtitle => '接受奖项，查看已发徽章的状态。';

  @override
  String get badgesTitle => '徽章';

  @override
  String get badgesLoadError => '徽章加载失败';

  @override
  String get badgesUpdateError => '徽章更新失败';

  @override
  String get badgesAwardedEmptyTitle => '还没有徽章';

  @override
  String get badgesAwardedEmptySubtitle => '当有人给你颁发 Nostr 徽章时，它会出现在这里。';

  @override
  String get badgesStatusAccepted => '已接受';

  @override
  String get badgesStatusNotAccepted => '未接受';

  @override
  String get badgesActionRemove => '移除';

  @override
  String get badgesActionAccept => '接受';

  @override
  String get badgesActionReject => '拒绝';

  @override
  String get badgesIssuedEmptyTitle => '还没有发出徽章';

  @override
  String get badgesIssuedEmptySubtitle => '你发出的徽章会在这里显示接受状态。';

  @override
  String get badgesIssuedNoRecipients => '没有找到该奖项的获得者。';

  @override
  String get badgesRecipientAcceptedStatus => '对方已接受';

  @override
  String get badgesRecipientWaitingStatus => '等待对方接受';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已隐藏（$count）',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => '恢复';

  @override
  String get badgesHiddenSnackbar => '已隐藏徽章';

  @override
  String get badgesHiddenSnackbarUndo => '撤销';

  @override
  String get badgesTabAwarded => '收到的';

  @override
  String get badgesTabCreated => '创建的';

  @override
  String get badgesTabIssued => '发出的';

  @override
  String get badgesCreateAction => '新徽章';

  @override
  String get badgesCreatedEmptyTitle => '还没做过徽章';

  @override
  String get badgesCreatedEmptySubtitle => '做一个，送给值得的人。';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已颁发给 $count 人',
      zero: '还没颁发',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => '新徽章';

  @override
  String get badgeEditorEditTitle => '编辑徽章';

  @override
  String get badgeEditorNameLabel => '名称';

  @override
  String get badgeEditorNameHint => '抢镜王';

  @override
  String get badgeEditorIdentifierLabel => '标识符';

  @override
  String get badgeEditorIdentifierHelp => '它是徽章地址的一部分，徽章创建后就不能再改。';

  @override
  String get badgeEditorIdentifierTaken =>
      '你已经有使用这个标识符的徽章了。请去编辑那一个——在这里发布会把它替换掉。';

  @override
  String get badgeEditorIdentifierRequired => '每个徽章都需要一个标识符——名称没填上的话，自己输入一个。';

  @override
  String get badgeEditorDescriptionLabel => '描述';

  @override
  String get badgeEditorDescriptionHint => '献给用一段循环就抢走全场的人。';

  @override
  String get badgeEditorArtworkLabel => '图案';

  @override
  String get badgeEditorArtworkAdd => '添加图案';

  @override
  String get badgeEditorArtworkReplace => '替换';

  @override
  String get badgeEditorArtworkError => '这张图片上传失败';

  @override
  String get badgeEditorArtworkRequired => '每个徽章都需要图案。';

  @override
  String get badgeEditorArtworkRemove => '移除图案';

  @override
  String get badgeEditorArtworkSheetTitle => '徽章图案';

  @override
  String get badgeDetailDeleteAction => '删除徽章';

  @override
  String get badgeDetailDeleteTitle => '删除这个徽章？';

  @override
  String get badgeDetailDeleteBody =>
      '这会请求中继删除该徽章以及你颁发过的所有记录。中继可以拒绝，已把它固定在资料页的人也会一直保留，直到自己移除。';

  @override
  String get badgeDetailDeleteConfirm => '删除';

  @override
  String get badgeEditorSaveAction => '发布徽章';

  @override
  String get badgeEditorSaveError => '徽章发布失败';

  @override
  String get badgeEditorLoadError => '无法加载这个徽章';

  @override
  String get badgeDetailTitle => '徽章';

  @override
  String get badgeDetailMadeBy => '创建者';

  @override
  String get badgeDetailRecipientsTitle => '已颁发给';

  @override
  String get badgeDetailNoRecipients => '还没有人拿到。';

  @override
  String get badgeDetailAwardAction => '颁发这个徽章';

  @override
  String get badgeDetailEditAction => '编辑徽章';

  @override
  String get badgeDetailShareAction => '分享';

  @override
  String badgeDetailShareMessage(String link) {
    return '来看看 Divine 上的这个徽章：$link';
  }

  @override
  String get badgeDetailRevokeAction => '收回徽章';

  @override
  String get badgeDetailRevokeTitle => '收回这枚徽章？';

  @override
  String get badgeDetailRevokeBody =>
      '这会请求中继删除你颁发给这个人的记录。中继可以拒绝，如果对方已经把徽章固定在资料页，它会一直留在那里，直到本人移除。无论哪种情况，对方都不会收到通知。';

  @override
  String get badgeDetailRevokeSelfBody =>
      '这会请求中继删除你颁发给自己的记录，并把徽章从你的资料页移除。如果中继拒绝删除，则不会有任何改变。';

  @override
  String get badgeDetailRevokeConfirm => '收回';

  @override
  String get badgeDetailRevokeSuccess => '已收回徽章';

  @override
  String get badgeDetailBlockClaimantsAction => '屏蔽佩戴该徽章的人';

  @override
  String get badgeDetailBlockClaimantsTitle => '屏蔽佩戴该徽章的人';

  @override
  String get badgeDetailBlockClaimantsLoadError => '无法加载佩戴该徽章的人';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle => '目前没有人佩戴这个徽章';

  @override
  String get badgeDetailBlockClaimantsEmptyBody => '我们没有找到可以屏蔽的人。';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '屏蔽 $count 个账号？',
      one: '屏蔽 1 个账号？',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '这会屏蔽目前佩戴该徽章的 $count 个账号。对方的帖子不会出现在你的信息流中，也不会收到此操作的通知。',
      one: '这会屏蔽目前佩戴该徽章的账号。对方的帖子不会出现在你的信息流中，也不会收到此操作的通知。',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '屏蔽 $count 个账号',
      one: '屏蔽 1 个账号',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => '已屏蔽佩戴该徽章的人';

  @override
  String get badgeDetailBlockClaimantsFailure => '无法屏蔽佩戴该徽章的人';

  @override
  String get badgeDetailLoadError => '无法加载这个徽章';

  @override
  String get badgeDetailMissing => '我们在任何中继上都找不到这个徽章。';

  @override
  String get badgeDetailActionError => '这次没成功';

  @override
  String get badgeAwardTitle => '颁发徽章';

  @override
  String get badgeAwardPickAction => '选择用户';

  @override
  String get badgeAwardManualLabel => '或粘贴密钥';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => '至少选一个人。';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '颁发给 $count 人',
      zero: '颁发徽章',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => '颁发者';

  @override
  String get profileBadgeRecipients => '获得者';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '还有 $count 人';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name 徽章';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => '徽章';

  @override
  String get profileBadgeFooterBody =>
      '徽章是任何人都可以在 Nostr 上制作的小奖励。送一个给朋友、创作者,或那个让你今天很开心的人。';

  @override
  String get profileBadgeFooterLink => '做一个自己的徽章';

  @override
  String get minorAccountReviewWelcomePageTitle => '家庭指南';

  @override
  String get minorAccountReviewWelcomeTitle => '还没满 16 岁？没关系。';

  @override
  String get minorAccountReviewWelcomeBody =>
      '如果你点进了这个页面，而不是随便选一个能混进去的答案，这很重要。这说明你诚实、有骨气，也真的在乎身边的人。\n\n各地对 16 岁以下人群的规定不一样。在 Divine，我们希望家人们一起聊一聊，共同决定什么样的社交媒体使用方式才是健康的。';

  @override
  String get minorAccountReviewModerationTitle => '我们还需要一步';

  @override
  String get minorAccountReviewModerationBody =>
      '我们被要求更仔细地审核这个账号，因为它可能属于 16 岁以下的人。这个流程会保护接下来步骤的隐私，并指引你走上适合你年龄的路径。';

  @override
  String get minorAccountReviewRulesTitle => '各地规则不一样';

  @override
  String get minorAccountReviewRulesBody =>
      '不同国家和地区对青少年使用社交媒体的规定不同。所以我们希望家庭放慢脚步，核实情况，一起选择下一步。';

  @override
  String get minorAccountReviewApproachTitle => 'Divine 怎么想';

  @override
  String get minorAccountReviewApproachBody =>
      '我们认为，健康的科技使用习惯来自停下来、想一想、把注意力转向更好的事情，而不是监视孩子，或把家长变成走廊监工。研究也支持这一点。';

  @override
  String get minorAccountReviewLearnMoreTitle => '给家庭的更多内容';

  @override
  String get minorAccountReviewKidsPolicyCta => '阅读 Divine 儿童政策';

  @override
  String get minorAccountReviewChooseAgeBandTitle => '选择适合你的路径';

  @override
  String get minorAccountReviewUnder13Cta => '13 岁以下';

  @override
  String get minorAccountReviewTeenCta => '13-15 岁';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      '访问 Divine 家庭指南，获取实用建议、沟通工具和资源，帮助青少年更安全地使用社交媒体。';

  @override
  String get minorAccountReviewFamilyResourcesCta => '获取家庭指南和建议';

  @override
  String get minorAccountReviewFooter =>
      '如果你已满 16 岁却被误送到这里，请联系 Divine 客服，会有真人为你审核。';

  @override
  String get minorAccountReviewTitle => '账号审核';

  @override
  String get minorAccountReviewCheckingStatusTitle => '正在检查账号状态...';

  @override
  String get minorAccountReviewCheckingStatusBody => '请稍候，我们正在确认该账号当前的审核状态。';

  @override
  String get minorAccountReviewDefaultTitle => '需要审核账号';

  @override
  String get minorAccountReviewDefaultBody => '我们需要先审核该账号，它才能正常使用 Divine。';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return '案件编号:$caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => '案件编号';

  @override
  String get minorAccountReviewRestrictionsTitle => '目前受限的功能';

  @override
  String get minorAccountReviewRestrictionPosting => '发帖和发布已暂停';

  @override
  String get minorAccountReviewRestrictionEngagement => '评论、点赞、转发和关注已暂停';

  @override
  String get minorAccountReviewRestrictionMessaging => '发起或回复普通消息已暂停';

  @override
  String get minorAccountReviewRestrictionSupport => '客服和管理消息仍然可用';

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
  String get minorAccountReviewOpenSupportCenter => '打开帮助中心';

  @override
  String get minorAccountReviewOpenModerationMessage => '打开管理消息';

  @override
  String get minorAccountReviewOpenReviewPage => '打开审核页面';

  @override
  String get minorAccountReviewCheckAgain => '再查一次';

  @override
  String get minorAccountReviewLogOut => '退出登录';

  @override
  String get minorAccountReviewNextStepTitle => '下一步';

  @override
  String get minorAccountReviewNextStepBody => '如果你需要此次审核方面的帮助，请打开帮助中心或你的管理消息。';

  @override
  String get minorAccountReviewInProgressTitle => '审核进行中';

  @override
  String get minorAccountReviewInProgressBody =>
      '我们目前已有所需的材料。我们的团队正在审核这个案件，之后才会恢复账号的正常使用。';

  @override
  String get minorAccountReviewUnder13Title => '13 岁以下账号';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return '如果该账号属于 13 岁以下的人，家长或监护人必须发送邮件至 $supportEmail，并附上案件编号。';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle => '我们暂时还不能给你账号';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine 不是为 13 岁以下的孩子打造的，世界各地的社交媒体法规也让我们没有办法。\n\n互联网上很多东西都在鼓励你撒谎来得到想要的，我们对此深恶痛绝。这是错误的人生一课，我们不会在这里教给你。';

  @override
  String get minorAccountReviewUnder13FamilyTitle => '你的家人可以怎么做';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      '家长或监护人可以持有账号并负责发布，而你完全可以出现在视频里。我们希望每个家庭都能以适合自己的方式享受 Divine。';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => '等你满 13 岁';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      '根据你所在地的规定，你也许可以回来申请自己的账号。届时，如果你年龄在 13 到 15 岁之间，需要得到家长或监护人的同意。';

  @override
  String get minorAccountReviewUnder13HonestyTitle => '为什么我们不会叫你直接点返回';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      '互联网上的很多东西，都在奖励那些说什么能混过门槛就说什么的人。我们不认为这是好事。没错，你可以回去谎称自己的年龄，但那不诚实，我们也不会教你靠撒谎来得到想要的东西。';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      '我们希望帮助年轻人以健康、积极的方式使用 Divine，对自己和身边的人都有益。我们也必须遵守各地不同的法律。所以，如果你未满 13 岁，答案就是：今天你还不能拥有自己的账号。';

  @override
  String get minorAccountReviewTeenBody =>
      '如果该账号属于 13 到 15 岁的人，请通过管理消息或客服渠道，按照家长同意流程的指引操作。';

  @override
  String get minorAccountReviewParentConsentTitle => '如果账号将属于 13 到 15 岁的人';

  @override
  String get minorAccountReviewParentConsentBody =>
      '家长或监护人应向 Divine 客服发送邮件，附上一段简短的私密视频。我们的团队会审核并协助后续步骤。\n\n如果无法联系到家长或监护人，或这样做会让某人陷入危险，请发邮件告知 Divine 客服。';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      '在 Divine 客服团队审核视频期间，账号会处于暂停状态。如果审核通过，他们会指导你完成新账号的设置。';

  @override
  String get minorAccountReviewParentConsentHonestyTitle => '为什么我们要求家长或监护人参与';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine 必须遵守世界各地与年龄相关的法律。我们也知道，大多数技术上的年龄门槛并不完美。与其假装规则不存在，或者觉得谎报年龄很酷，我们更希望青少年和家庭认真考虑如何更好地使用 Divine。所以对于 13-15 岁的用户，我们要求家长参与账号创建过程。';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      '我们也必须遵守法律，而这些规则因居住地不同而不同。所以，与其假装规则不存在，我们请家长或监护人参与到这个流程中来。';

  @override
  String get minorAccountReviewParentConsentChecklist => '视频需要包含的内容';

  @override
  String get minorAccountReviewParentConsentChecklistKid => '青少年本人出现在视频中';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      '家长或监护人在镜头前讲话';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      '明确说明该青少年年龄在 13 到 15 岁之间，并获准使用 Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      '明确说明家长或监护人知晓该账号，并将监督其使用';

  @override
  String get minorAccountReviewParentConsentPrivacy => '如何发送';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      '在给 Divine 客服的邮件中附上该视频';

  @override
  String get minorAccountReviewParentConsentDoNotSave => '请保持视频私密，不要发布到应用里';

  @override
  String get minorAccountReviewParentConsentOneMove => '我们的团队会审核并回复后续步骤';

  @override
  String get minorAccountReviewParentConsentEmailCta => '发邮件给 Divine 客服';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine Greenlight 审核协助（13-15 岁）';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Divine 客服团队，你们好：\n\n我就 Divine Greenlight 联系你们，对象是一位 13-15 岁的青少年。\n\n我附上了一段简短的私密视频，视频中包含：\n- 青少年本人\n- 家长或监护人在镜头前讲话\n- 该青少年获准使用 Divine\n- 家长或监护人知晓该账号，并将监督其使用\n\n居住国家/地区：\n\n其他有帮助的背景信息：\n\n谢谢。';

  @override
  String get minorAccountReviewParentSupportInstructions => '家长协助指引';

  @override
  String get minorAccountReviewContinue => '继续';

  @override
  String get minorAccountReviewErrorTitle => '无法加载你的账号审核状态。';

  @override
  String get minorAccountReviewErrorBody => '请稍后再试。';

  @override
  String get minorAccountReviewTryAgain => '再试一次';

  @override
  String get minorAccountReviewParentContactTitle => '家长联系方式';

  @override
  String get minorAccountReviewParentContactHeading => '添加家长或监护人邮箱';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return '我们会用这个邮箱进行案件 $caseId 的家长同意审核。';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel => '家长或监护人邮箱';

  @override
  String get minorAccountReviewSubmitting => '提交中...';

  @override
  String get minorAccountReviewSubmitEmail => '提交邮箱';

  @override
  String get minorAccountReviewBackToReview => '返回账号审核';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => '邮箱已提交';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return '我们已提交 $email 进行审核。我们会向该邮箱发送确认邮件。等你的家长或监护人回复后，你的案件就会推进。可以在账号审核页面点“再查一次”查看最新进展。';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      '我们已收到该账号的家长或监护人联系方式。我们的团队会先审核，再恢复访问。';

  @override
  String get minorAccountReviewMissingCase => '我们找不到该账号的进行中的审核案件。';

  @override
  String get minorAccountReviewParentContactError => '无法提交家长邮箱，请重试。';

  @override
  String get minorAccountReviewUnder13SupportTitle => '家长协助';

  @override
  String get minorAccountReviewUnder13Heading => '家长或监护人必须联系 Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      '对于疑似 13 岁以下的账号，下一步需要家长或监护人通过邮件联系我们。';

  @override
  String get minorAccountReviewSupportEmailLabel => '客服邮箱';

  @override
  String get minorAccountReviewCopySupportEmail => '复制客服邮箱';

  @override
  String get minorAccountReviewSupportEmailCopied => '客服邮箱已复制';

  @override
  String get minorAccountReviewCopyCaseId => '复制案件编号';

  @override
  String get minorAccountReviewCaseIdCopied => '案件编号已复制';

  @override
  String get minorAccountReviewUnavailable => '不可用';

  @override
  String get minorAccountReviewUnder13Instructions =>
      '请家长或监护人在邮件中附上案件编号，并说明他们就此次账号审核联系 Divine。';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return '13 岁以下账号审核，案件编号 $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Divine 客服团队，你们好：\n\n我是一名 13 岁以下儿童的家长或监护人，就账号审核案件 $caseId 与你们联系。\n\n谢谢。';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle => '未成年账号审核模拟';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => '当前状态';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return '受限（$state）';
  }

  @override
  String get devOptionsMinorReviewStateActive => '正常';

  @override
  String get devOptionsMinorReviewStateLoading => '加载中...';

  @override
  String get devOptionsMinorReviewStateError => '状态加载出错';

  @override
  String get devOptionsMinorReviewClearTitle => '清除模拟覆盖';

  @override
  String get devOptionsMinorReviewClearSubtitle => '重新使用后端或默认的正常状态';

  @override
  String get devOptionsMinorReviewTeenTitle => '模拟 13-15 岁审核案件';

  @override
  String get devOptionsMinorReviewTeenSubtitle => '受限账号，走家长联系路径';

  @override
  String get devOptionsMinorReviewUnder13Title => '模拟 13 岁以下协助案件';

  @override
  String get devOptionsMinorReviewUnder13Subtitle => '受限账号，仅有家长邮件指引';

  @override
  String get devOptionsMinorReviewClearedToast => '未成年账号审核模拟已清除';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast => '已启用 13 岁以下协助案件模拟';

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
  String get devOptionsProtectedMinorSimulationTitle => '未成年保护模拟';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => '当前状态';

  @override
  String get devOptionsProtectedMinorStateProtected => '未成年保护（13-15 岁）';

  @override
  String get devOptionsProtectedMinorStateNotProtected => '未保护';

  @override
  String get devOptionsProtectedMinorStateLoading => '加载中…';

  @override
  String get devOptionsProtectedMinorStateError => '状态读取出错';

  @override
  String get devOptionsProtectedMinorOverrideNone => '不覆盖（真实账号状态）';

  @override
  String get devOptionsProtectedMinorOverrideProtected => '覆盖：强制保护';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected => '覆盖：强制不保护';

  @override
  String get devOptionsProtectedMinorSimulateTitle => '模拟未成年保护（13-15 岁）';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      '强制进入未成年保护状态，用于 QA #175/#176 保护';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle => '模拟非未成年';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      '强制不保护（明确的否定，与“不覆盖”不同）';

  @override
  String get devOptionsProtectedMinorClearTitle => '清除覆盖';

  @override
  String get devOptionsProtectedMinorClearSubtitle => '回到由 Keycast 驱动的真实账号状态';

  @override
  String get devOptionsProtectedMinorEnabledToast => '已强制开启未成年保护状态';

  @override
  String get devOptionsProtectedMinorNonMinorToast => '已强制关闭未成年保护状态';

  @override
  String get devOptionsProtectedMinorClearedToast => '未成年保护覆盖已清除';

  @override
  String get devOptionsInviteAvailabilityTitle => '注册邀请';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => '当前状态';

  @override
  String get devOptionsInviteAvailabilityServerLoading => '服务器值：加载中';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => '服务器值：已启用';

  @override
  String get devOptionsInviteAvailabilityServerDisabled => '服务器值：已禁用';

  @override
  String get devOptionsInviteAvailabilityServerUnknown => '服务器值：未知';

  @override
  String get devOptionsInviteAvailabilityOverrideNone => '覆盖：使用服务器值';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled => '覆盖：强制启用';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled => '覆盖：强制禁用';

  @override
  String get devOptionsInviteAvailabilityUseServer => '使用服务器值';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      '跟随邀请服务的 onboardingMode';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => '强制启用';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      '在本地显示注册邀请门槛和管理界面';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => '强制禁用';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      '在本地隐藏注册邀请界面，不改动服务器';

  @override
  String get devOptionsInviteAvailabilityUseServerToast => '注册邀请现在跟随服务器';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast => '注册邀请已强制启用';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast => '注册邀请已强制禁用';

  @override
  String get commentsRecordVideoButtonLabel => '录制视频评论';

  @override
  String get commentsOpenVideoLabel => '打开视频评论';

  @override
  String get commentsMuteVideoReplyLabel => '视频回复静音';

  @override
  String get commentsUnmuteVideoReplyLabel => '取消视频回复静音';

  @override
  String get commentsOpenReplyParentLabel => '打开被回复的视频';

  @override
  String get commentsReplyParentSectionTitle => '回复对象';

  @override
  String commentsReplyParentLabel(String target) {
    return '回复 $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => '回复视频';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return '已认证的 $platform 账号：$identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => '已认证账号';

  @override
  String get profileEditGetVerifiedCta => '去认证';

  @override
  String get profileEditGetVerifiedSubtitle => '关联你的社交媒体账号，让大家知道这真的是你。';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return '访问网站:$url';
  }

  @override
  String get profileCouldNotOpenWebsite => '无法打开网站';

  @override
  String get videoMetadataEditCoverTitle => '编辑封面';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => '放弃封面更改';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel => '将所选帧用作视频封面';

  @override
  String get videoMetadataEditCoverStripSemanticLabel => '拖动进度选择封面帧';

  @override
  String get videoMetadataTagsPickerSearchHint => '搜索或添加标签';

  @override
  String get videoMetadataTagsPickerEmptyHint => '添加标签，让更多人发现你的视频';

  @override
  String get videoMetadataTagsPickerNoResults => '没有匹配的标签';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '添加“#$tag”';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => '还没满 16 岁？没关系。';

  @override
  String get authUnder16ChoicesCta => '这里是你的选择。';

  @override
  String get minorAccountReviewUnder13WhyTitle => '原因在这里';

  @override
  String get generalSettingsHoldToRecord => '按住录制';

  @override
  String get generalSettingsHoldToRecordSubtitle => '按住开始录制，松开停止';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个视频已发布到你的主页',
      one: '1 个视频已发布到你的主页',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => '发送消息';

  @override
  String get emojiPickerSearchHint => '搜索';

  @override
  String get emojiCategoryRecent => '最近使用';

  @override
  String get emojiCategorySmileys => '笑脸与人物';

  @override
  String get emojiCategoryAnimals => '动物与自然';

  @override
  String get emojiCategoryFood => '美食与饮品';

  @override
  String get emojiCategoryActivities => '活动';

  @override
  String get emojiCategoryTravel => '旅行与地点';

  @override
  String get emojiCategoryObjects => '物品';

  @override
  String get emojiCategorySymbols => '符号';

  @override
  String get emojiCategoryFlags => '旗帜';

  @override
  String get videoEditorMarkerLabel => '标记';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel => '添加时间线标记';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel => '移除时间线标记';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      '移除播放头处的标记';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => '删除标记？';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle => '这会从时间线移除该标记，你的编辑不受影响。';

  @override
  String get videoEditorVolumeLongPressHint => '静音或取消静音所有轨道';

  @override
  String get videoEditorSplitFailed => '分割失败，请重试。';

  @override
  String get videoEditEditSubtitles => '编辑字幕';

  @override
  String get subtitleEditorTitle => '编辑字幕';

  @override
  String get subtitleEditorSave => '保存';

  @override
  String get subtitleEditorProcessing => '字幕还在生成中，过会儿再来看看。';

  @override
  String get subtitleEditorNoSpeech => '这个视频里没检测到人声，所以没有可以做字幕的内容。';

  @override
  String get subtitleEditorWriteOwn => '自己写字幕';

  @override
  String get subtitleEditorAddCue => '添加一行';

  @override
  String get subtitleEditorRemoveCue => '删除这一行';

  @override
  String get subtitleEditorPreviewUnavailable => '视频现在没法播放，但你仍然可以修改字幕。';

  @override
  String get subtitleEditorPlayPreview => '播放视频';

  @override
  String get subtitleEditorPausePreview => '暂停视频';

  @override
  String get subtitleEditorInvalidHint => '每一行都需要文字，而且结束时间要晚于开始时间。';

  @override
  String get subtitleEditorLoadError => '字幕加载失败，请重试。';

  @override
  String get subtitleEditorSaveSuccess => '字幕已更新';

  @override
  String get subtitleEditorSaveError => '字幕保存失败，请重试。';

  @override
  String get subtitleEditorRetry => '重试';

  @override
  String get subtitleEditorCueHint => '字幕文本';

  @override
  String get imageCropEditorRotateLabel => '旋转';

  @override
  String get imageCropEditorFlipLabel => '翻转';

  @override
  String get imageCropEditorResetLabel => '重置';

  @override
  String get imageCropEditorCloseSemanticLabel => '取消裁剪';

  @override
  String get imageCropEditorDoneSemanticLabel => '应用裁剪';

  @override
  String get imageCropEditorProcessing => '正在应用裁剪…';

  @override
  String get backgroundUploadNotificationTitle => '正在上传视频';

  @override
  String get monetizationSettingsTitle => '创作者支持';

  @override
  String get monetizationSettingsSubtitle => '添加打赏和订阅链接';

  @override
  String get monetizationSettingsIntroTitle => '仅站外链接';

  @override
  String get monetizationSettingsIntroBody =>
      '添加由创作者控制的跳转目标。Divine 不经手任何付款，也不会通过这些链接解锁应用内内容。';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    return '你的主页有 $count 个生效中的链接';
  }

  @override
  String get monetizationSettingsTipSection => '发个打赏';

  @override
  String get monetizationSettingsSubscriptionSection => '订阅 / 支持';

  @override
  String get monetizationSettingsSave => '保存支持链接';

  @override
  String get monetizationSettingsSaving => '保存中...';

  @override
  String get monetizationSettingsSaved => '支持链接已更新';

  @override
  String get monetizationSettingsSaveFailed => '无法保存支持链接。请检查网络连接后重试。';

  @override
  String get monetizationSettingsErrorEmpty => '请添加账号或 URL。';

  @override
  String get monetizationSettingsErrorInvalid => '这个链接看起来不太对。';

  @override
  String get monetizationSettingsErrorWrongProvider => '请使用该平台的链接。';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag 或 cash.app 链接';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me 账号或链接';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo 账号或链接';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon 账号或链接';

  @override
  String get monetizationSettingsHintSubstack => 'Substack 域名或链接';

  @override
  String get monetizationSettingsHintMedium => 'Medium 账号或链接';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective slug 或链接';

  @override
  String get profileSupportSheetTitle => '支持这位创作者';

  @override
  String get profileSupportSheetBody => '这些链接会在 Divine 之外打开。这里的任何内容都不会解锁应用内内容。';

  @override
  String get profileSupportTipSection => '发个打赏';

  @override
  String get profileSupportSubscriptionSection => '订阅 / 支持';

  @override
  String get profileSupportButtonLabel => '支持';

  @override
  String get monetizationTipsSettingsTitle => '打赏';

  @override
  String get monetizationTipsSettingsSubtitle => '添加可选的打赏链接';

  @override
  String get monetizationTipsSettingsIntroTitle => '仅自愿打赏';

  @override
  String get monetizationTipsSettingsIntroBody =>
      '打赏是用户之间自愿的赠予。它不会解锁 Divine 中的内容、订阅、功能、排名、曝光或访问权限。';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    return '你的主页有 $count 个生效中的打赏链接';
  }

  @override
  String get monetizationTipsSettingsSave => '保存打赏链接';

  @override
  String get monetizationTipsSettingsSaved => '打赏链接已更新';

  @override
  String get profileTipButtonLabel => '打赏';

  @override
  String get profileTipSheetTitle => '打赏这位创作者';

  @override
  String get profileTipSheetBody =>
      '打赏会在 Divine 之外完成。它完全自愿，不会解锁 Divine 中的内容、订阅、功能或访问权限。';

  @override
  String get settingsStorageTitle => '存储';

  @override
  String get settingsStorageCacheSectionTitle => '缓存的媒体';

  @override
  String get settingsStorageCacheDescription =>
      '缓存的信息流视频、缩略图和临时渲染文件。清除它们很安全——需要时会重新下载或生成。';

  @override
  String get settingsStorageMeasuring => '正在计算…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '已用 $size';
  }

  @override
  String get settingsStorageClearButton => '清除缓存';

  @override
  String get settingsStorageClearConfirmTitle => '清除缓存的媒体？';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return '这能释放 $size。你的片段库不受影响。';
  }

  @override
  String get settingsStorageClearConfirmAction => '清除';

  @override
  String get settingsStorageCleared => '缓存已清除';

  @override
  String get settingsStorageLibrarySectionTitle => '片段库';

  @override
  String get settingsStorageLibraryDescription => '检查视频文件丢失的损坏片段。';

  @override
  String get settingsStorageScanButton => '检查片段库';

  @override
  String get settingsStorageLibraryHealthy => '没有发现损坏片段';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return '发现损坏片段：$count 个';
  }

  @override
  String get settingsStorageRemoveBrokenButton => '移除损坏片段';

  @override
  String get settingsStorageBrokenClipsRemoved => '损坏片段已移除';

  @override
  String get settingsStorageError => '出了点问题';

  @override
  String get settingsStorageMaxVideoCacheLabel => '视频缓存上限';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count 个视频';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle => '移除损坏片段？';

  @override
  String get settingsStorageRepairSectionTitle => '修复安装';

  @override
  String get settingsStorageRepairDescription =>
      '如果应用总是崩溃或行为异常，重置本地数据通常能解决。你的片段和草稿会保留。';

  @override
  String get settingsStorageRepairButton => '重置应用数据';

  @override
  String get settingsStorageRepairConfirmTitle => '要重置应用数据吗？';

  @override
  String get settingsStorageRepairConfirmMessage =>
      '这会清除缓存的信息流数据和临时文件。你的片段、草稿、设置和登录状态会保留，但之后需要重启应用。';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '将删除 $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => '重置';

  @override
  String get settingsStorageRepairInProgress => '正在重置…';

  @override
  String get settingsStorageRepairSuccess => '完成 — 重启应用即可生效。';

  @override
  String get settingsStorageRepairFailure => '没能全部重置。重启后再试一次。';

  @override
  String get nostrSettingsSignatureVerification => '签名验证';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      '选择 Divine 何时检查中继事件签名。事件 ID 永远会先验证。';

  @override
  String get nostrSettingsSignatureVerificationAll => '所有中继';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      '最安全。验证每一个中继事件签名。';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => '不受信任的中继';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      '跳过已在你配置池中的中继的检查。';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => '非 Divine 中继';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      '信任 Divine 中继，验证其余中继。';

  @override
  String get settingsCrosspostingTitle => '跨平台发布';

  @override
  String get settingsCrosspostingSubtitle => '把你的视频分享到其他平台';

  @override
  String get crosspostingSignInRequired => '用 Divine 登录来管理跨平台发布';

  @override
  String get crosspostingLoadFailed => '无法加载你的跨平台发布设置';

  @override
  String get crosspostingNoPlatforms => '目前没有可用的跨平台发布平台';

  @override
  String get crosspostingRetry => '重试';

  @override
  String get crosspostingNotConnected => '未连接';

  @override
  String get crosspostingConnected => '已连接';

  @override
  String get crosspostingNeedsReconnect => '需要重新连接';

  @override
  String get crosspostingConnect => '连接';

  @override
  String get crosspostingReconnect => '重新连接';

  @override
  String get crosspostingDisconnect => '断开连接';

  @override
  String get crosspostingModeOff => '关闭';

  @override
  String get crosspostingModeManual => '手动';

  @override
  String get crosspostingModeManualSubtitle => '每个视频你自己决定';

  @override
  String get crosspostingModeAutomatic => '自动';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      '以后的视频会自动发布 —— 只包括你打开这个开关之后发布的视频';

  @override
  String get crosspostingNotConnectedError => '先连接这个平台，才能更改它的发布方式。';

  @override
  String get crosspostingGenericError => '出了点问题，再试一次。';

  @override
  String get crosspostingCallbackTimeoutError =>
      '登录页面一直没有回应。如果你已经在那边连接好了，刷新一下 —— 你的账号可能已经关联了。';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '已连接 $platform';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return '无法连接 $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return '已在 $platform 上取消连接';
  }

  @override
  String get supporterTitle => 'Divine 支持者';

  @override
  String get supporterTileSubtitle => '通过自愿的月度订阅支持 Divine。';

  @override
  String get supporterHeroTitle => '让 Divine 一直转下去';

  @override
  String get supporterHeroBody =>
      'Divine 免费，而且永远免费。如果你想帮我们让循环一直转下去，可以成为月度支持者。没有任何功能被锁定——它只是让服务器有电可用，并赢得我们的感谢。';

  @override
  String get supporterActiveBadge => '你是 Divine 支持者。谢谢你让这一切继续。';

  @override
  String get supporterPurchasePending => '你的购买正在等待批准。';

  @override
  String get supporterPurchaseConfirming => '正在确认你的支持…';

  @override
  String get supporterStoreChecking => '正在检查商店…';

  @override
  String get supporterUnavailable => '这里暂时无法使用支持者订阅。';

  @override
  String get supporterRestorePurchases => '恢复购买';

  @override
  String get supporterDismissError => '忽略错误';

  @override
  String get supporterErrorStoreUnavailable => '此设备上的商店不可用。';

  @override
  String get supporterErrorPurchaseFailed => '购买未完成。你没有被扣款。';

  @override
  String get supporterErrorPurchasePending => '你的购买正在等待批准。';

  @override
  String get supporterErrorRestoreFailed => '没有找到可恢复的支持者订阅。';

  @override
  String get supporterErrorOwnershipConflict => '该购买属于另一个 Divine 账号。';

  @override
  String get supporterErrorVerificationUnavailable => 'Divine 暂时无法确认支持者状态。';

  @override
  String get supporterErrorUnknown => '出了点问题，请重试。';

  @override
  String get supporterDisclaimer =>
      'Divine 会在商店验证你的购买后确认支持者状态。展示与否完全自愿，光环标识不代表认证。';

  @override
  String get profileNotifyBellOff => '接收新视频通知';

  @override
  String get profileNotifyBellOn => '停止新视频通知';

  @override
  String get profileNotifyUpdateFailed => '没能保存，再试一次？';

  @override
  String get savedSoundYourLabel => '你的标签';

  @override
  String get savedSoundAddHashtags => '添加话题标签';

  @override
  String get savedSoundDeviceOnly => '已保存在本设备';

  @override
  String get savedSoundDetailsRetry => '无法保存这些信息。点按重试。';

  @override
  String get savedSoundFallbackTitle => '已保存的声音';

  @override
  String get savedSoundPreviewAction => '试听声音';

  @override
  String get savedSoundEditAction => '编辑声音信息';

  @override
  String get savedSoundRemoveAction => '移除已保存的声音';

  @override
  String get savedSoundClearHashtagFilter => '清除话题标签筛选';

  @override
  String get soundAllowRemix => '允许他人混剪此声音';

  @override
  String get soundReuseUnavailable => '此声音目前无法混剪。';

  @override
  String get soundPublicCredit => '公开声音署名';

  @override
  String get soundCreditRequired => '发布前请添加公开声音署名。';

  @override
  String get soundSharedAs => '分享为';

  @override
  String get soundOwnWork => '这个声音是我做的';

  @override
  String soundCreatorBy(String creator) {
    return '作者：$creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return '由 $publisher 分享';
  }

  @override
  String get soundRemixingAllowed => '允许混剪';

  @override
  String get soundCreditOnly => '仅署名';

  @override
  String get soundCreditTitleLabel => '声音标题';

  @override
  String get soundCreditCreatorLabel => '创作者';

  @override
  String get soundCreditSourceUrlLabel => '来源 URL';

  @override
  String get soundCreditPublicHashtagsLabel => '公开话题标签';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel => '取消标签选择';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel => '应用所选标签';

  @override
  String get userPickerCancelSemanticLabel => '取消用户选择';

  @override
  String get userPickerConfirmSemanticLabel => '确认所选用户';

  @override
  String get userPickerClearSelectionSemanticLabel => '清除用户选择';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      '取消内容警告选择';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      '应用所选内容警告';

  @override
  String get videoEditorCloseEditorSemanticLabel => '关闭视频编辑器';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel => '继续前往帖子详情';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return '放弃在$tool中的更改';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return '应用在$tool中的更改';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => '移除音频';

  @override
  String rgbColorSemanticLabel(int red, int green, int blue) {
    return 'RGB $red、$green、$blue';
  }

  @override
  String videoEditorColorPickerSwatchSemanticLabel(
    String picker,
    String color,
  ) {
    return '$picker、$color';
  }

  @override
  String get verifyTitle => '已验证账号';

  @override
  String get verifySignedOutMessage => '登录后即可关联你的账号。';

  @override
  String get verifyIntro => '把你已经在用的账号关联起来，别人一眼就知道是你本人。';

  @override
  String get verifyLoadFailed => '没能加载你的关联。';

  @override
  String get verifyRetry => '再试一次';

  @override
  String get verifyLinkedSectionTitle => '已关联';

  @override
  String get verifyVerifierUnreachable => '连不上验证服务，所以这些都显示为未核查。';

  @override
  String get verifyAddSectionTitle => '添加账号';

  @override
  String get verifyAllPlatformsLinked => '我们支持的你都关联完了。';

  @override
  String get verifyStatusVerified => '已验证';

  @override
  String get verifyStatusUnverified => '未验证';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return '解除关联 $platform 账号 $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return '解除关联 $platform？';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity 将不再显示在你的资料页上。之后可以重新关联，但需要再登录一次，或者重新发一条证明帖。';
  }

  @override
  String get verifyUnlinkConfirmCta => '解除关联';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return '关联你的 $platform 账号';
  }

  @override
  String get verifyOneTapBadge => '一键';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return '登录 $platform，剩下的交给我们。不会发布任何内容。';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return '使用 $platform 继续';
  }

  @override
  String get verifyConnectProofTitle => '或者发一条证明';

  @override
  String get verifyConnectProofExplainer => '在你的账号上发布你的 npub，然后把那条帖子的链接贴进来。';

  @override
  String get verifyNpubLabel => '你的 npub';

  @override
  String get verifyCopyNpubSemanticLabel => '复制你的 npub';

  @override
  String get verifyNpubCopied => '已复制 npub';

  @override
  String get verifyIdentityLabel => '账号名称';

  @override
  String get verifyProofLabel => '帖子链接';

  @override
  String get verifyConnectProofCta => '核查并关联';

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
  String get verifyErrorVerifierUnreachable => '连不上验证服务。过一会儿再试。';

  @override
  String get verifyErrorOauthFailed => '没成功。再试一次吧。';

  @override
  String get verifyErrorHandleRequired => '先填你的 handle。';

  @override
  String get verifyErrorPublishFailed => '验证通过了，但没有中继接受这次更新。再试一次。';

  @override
  String get verifyErrorOauthUnavailable => '这个还没接一键登录。用下面的证明帖吧。';

  @override
  String get verifyConnectProofExplainerGithub =>
      '建一个公开 gist，把 npub 放在第一个文件里，然后贴上 gist 链接。';

  @override
  String get verifyConnectProofExplainerDiscord =>
      '在我们机器人能读到的 Discord 频道里发你的 npub，然后贴上那条消息的链接。服务器邀请证明不了什么。';

  @override
  String get verifyConnectProofExplainerTwitter =>
      '用那个账号发一条带 npub 的推文，然后贴上推文链接。';

  @override
  String get verifyConnectProofExplainerMastodon =>
      '用那个账号发一条带 npub 的嘟文，然后贴上链接。账号名要带实例 — mastodon.social/@alice，不是只写 alice。';

  @override
  String get verifyConnectProofExplainerTelegram =>
      '关联的是频道，不是你的 Telegram 账号。频道要先有公开链接（Telegram 新建的默认私密）。在那里发你的 npub，再贴上消息链接。';

  @override
  String get verifyConnectProofExplainerBluesky =>
      '上面登录过了？那就不用再做什么。没有的话，发一条带 npub 的帖子并贴上链接。';

  @override
  String get verifyConnectProofExplainerTiktok => '把 npub 写进视频文案，然后贴上那条视频的链接。';

  @override
  String get verifyConnectProofExplainerYoutube => '把 npub 写进视频简介，然后贴上那条视频的链接。';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform 已关联。';
  }

  @override
  String get verifyErrorTelegramNotPublic => '那是私密频道或邀请链接。先给频道设置公开链接，再贴消息链接。';

  @override
  String get verifyErrorRemoveFailed => '没能解除关联。再试一次。';

  @override
  String get verifyErrorLinksUnreadable => '读不到你现有的关联，所以什么都没改。检查网络后再试一次。';

  @override
  String get verifyChannelLabel => '频道名称';

  @override
  String get verifyHowItWorksTitle => '这是怎么运作的？';

  @override
  String get verifyHowItWorksIntro => '把它想成两个账号之间的握手：';

  @override
  String get verifyHowItWorksYourSide =>
      '你的 Divine 资料说：“我是 Twitter 上的 @alice。”';

  @override
  String get verifyHowItWorksOtherSide =>
      '你的 Twitter 账号确认：“是的，那个 Divine 资料是我的。”';

  @override
  String get verifyHowItWorksBothSides =>
      '我们两边都核对。对得上，你就通过了。这没法伪造——名字和照片可以抄，但没法从你真正的账号发帖。';

  @override
  String get verifyHowItWorksOwnership => '这些关联存在你自己的 Nostr 身份里，你随时可以在这里移除。';

  @override
  String get generalSettingsSectionIdentity => '身份';

  @override
  String get libraryFilterAll => '全部';

  @override
  String get libraryFilterArchive => '归档';

  @override
  String get libraryFilterDeleted => '已删除';

  @override
  String get libraryCategoryNewChipLabel => '新建';

  @override
  String get libraryCategoryCreateSemanticLabel => '创建分类';

  @override
  String get libraryCategoryCreateTitle => '新建分类';

  @override
  String get libraryCategoryCreateAction => '创建';

  @override
  String get libraryCategoryRenameTitle => '重命名分类';

  @override
  String get libraryCategoryRenameAction => '重命名';

  @override
  String get libraryCategoryDeleteAction => '删除分类';

  @override
  String get libraryCategoryNameLabel => '分类名称';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage => '片段还在，只是回到“全部”里。';

  @override
  String get libraryCategoryManageSemanticLabel => '重命名或删除此分类';

  @override
  String get libraryCategoryMoveTitle => '移动到';

  @override
  String get libraryCategoryMoveNone => '无分类';

  @override
  String get libraryCategoryMoveNewCategory => '新建分类';

  @override
  String get libraryArchiveAction => '归档';

  @override
  String get libraryUnarchiveAction => '取消归档';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '保留在这些分类中吗？',
      one: '保留在此分类中吗？',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return '保留在$name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => '保留在各自的分类中';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return '从$name中移除';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed => '从各自的分类中移除';

  @override
  String get libraryMoveSelectedClipsTooltip => '移动所选片段';

  @override
  String get libraryCategoryEmptyTitle => '这里还没有内容';

  @override
  String get libraryCategoryEmptySubtitle => '选几个片段，把它们移到这个分类里。';

  @override
  String get libraryArchiveEmptyTitle => '归档里还没有内容';

  @override
  String get libraryArchiveEmptySubtitle => '归档的片段在这里等着，不会挤在主素材库里。';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已将 $count 个片段移到 $name',
      one: '已将 1 个片段移到 $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已将 $count 个片段移出分类',
      one: '已将 1 个片段移出分类',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已归档 $count 个片段',
      one: '已归档 1 个片段',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个片段已回到素材库',
      one: '1 个片段已回到素材库',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => '更改邮箱';

  @override
  String get accountSettingsChangeEmailSubtitle => '把账号换到另一个邮箱地址';

  @override
  String get accountSettingsChangePassword => '更改密码';

  @override
  String get accountSettingsChangePasswordSubtitle => '设置一个新的登录密码';

  @override
  String get accountCredentialsNeedsSignIn => '登录状态已过期。请重新登录后再更改。';

  @override
  String get accountCredentialsRateLimited => '尝试次数太多，过几分钟再试。';

  @override
  String get accountCredentialsNetwork => '连不上 Divine。检查网络后再试一次。';

  @override
  String get accountCredentialsUnknown => '没成功，请再试一次。';

  @override
  String get changePasswordSubtitle => '输入当前密码，然后设置新密码。';

  @override
  String get changePasswordCurrentLabel => '当前密码';

  @override
  String get changePasswordWrongCurrent => '这不是你的当前密码。';

  @override
  String get changePasswordSuccess => '密码已更改。';

  @override
  String get changeEmailSubtitle => '我们会向新地址和账号上的地址各发一封确认邮件。两边都确认后邮箱才会更改。';

  @override
  String changeEmailCurrentAddress(String email) {
    return '账号邮箱：$email';
  }

  @override
  String get changeEmailNewLabel => '新邮箱';

  @override
  String get changeEmailPasswordLabel => '你的密码';

  @override
  String get changeEmailSameAsCurrent => '这已经是你的邮箱地址了。';

  @override
  String get changeEmailWrongPassword => '这不是你的密码。';

  @override
  String get changeEmailSubmit => '发送确认链接';

  @override
  String get changeEmailSentTitle => '两封确认邮件已在路上';

  @override
  String changeEmailSentMessage(String email) {
    return '请在 $email 和账号上的地址两边都确认。两边都完成后邮箱就会切换。';
  }

  @override
  String get changeEmailSentExpiry => '链接 24 小时后失效。';

  @override
  String get changeEmailSentDone => '知道了';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount 条视频',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => '互相关注';

  @override
  String get socialProofFollowsYou => '关注了你';

  @override
  String get socialProofYouFollow => '已关注';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount 位粉丝',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage => '视频暂时加载不出来。\n是我们的问题，正在修复。';

  @override
  String get feedOfflineMessage => '你当前处于离线状态。\n请检查网络后重试。';

  @override
  String get dbFailureTitle => '无法解锁你的本地数据库';

  @override
  String get dbFailureAdviceResettable =>
      '重启无法解决这个问题。重置下方的本地数据库可以让 Divine 全新开始 — 你的账号会保留。';

  @override
  String get dbFailureAdviceRestart => '解锁设备后重新启动 Divine。如果问题持续出现，请更新应用或联系支持。';

  @override
  String get dbFailureAdviceHotJournal =>
      '请尝试重启一次 Divine。如果问题持续出现，请更新应用或联系支持。你的本地数据仍然保留着。';

  @override
  String dbFailureDiagnostic(String code) {
    return '诊断：$code';
  }

  @override
  String get dbFailureCloseApp => '关闭 Divine';

  @override
  String get dbFailureResetAction => '重置本地数据库';

  @override
  String get dbFailureConfirmTitle => '重置你的本地数据库？';

  @override
  String get dbFailureConfirmBody =>
      '你的账号会保留。保存在此设备上的草稿和片段将被删除 — 消息和信息流会从网络重新获取。';

  @override
  String get dbFailureResetConfirm => '立即重置本地数据库';

  @override
  String get dbFailureCancel => '取消';

  @override
  String get dbFailureResetFailed => '没有成功。请关闭 Divine 后重试。';

  @override
  String get dbFailureResetDoneTitle => '本地数据库已重置';

  @override
  String get dbFailureResetDoneBody => '关闭 Divine 后重新打开 — 下次启动会建立全新的本地数据库。';

  @override
  String get authSignInOptionsInfo => '关于登录选项';

  @override
  String get authShowPassword => '显示密码';

  @override
  String get authHidePassword => '隐藏密码';

  @override
  String get followUserSemanticLabel => '关注用户';

  @override
  String get unfollowUserSemanticLabel => '取消关注用户';

  @override
  String get commentsLoadingSemanticLabel => '正在加载评论';

  @override
  String get analyticsWindowAll => '全部';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return '关注用户 $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return '取消关注用户 $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / 月';
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
  String get updateGentleBanner => '新版本刚刚上线。去看看 →';

  @override
  String get updateModerateTitle => '自上次检查后已有新版本';

  @override
  String get updateUrgentTitle => '你缺少重要修复';

  @override
  String get updateNotNow => '暂不';

  @override
  String get updateAction => '更新';

  @override
  String updateNewIn(String version) {
    return '$version 新增内容：';
  }

  @override
  String get settingsUpdateAvailable => '有可用更新';
}

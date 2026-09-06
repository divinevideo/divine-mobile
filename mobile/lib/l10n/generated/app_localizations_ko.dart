// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get devOptionsClipRecovery => '클립 복구';

  @override
  String get devOptionsClipRecoveryDescription =>
      '다른 계정에 저장된 녹화본과 어떤 항목도 참조하지 않는 동영상 파일을 찾습니다.';

  @override
  String get devOptionsClipRecoveryScan => '검사';

  @override
  String get devOptionsClipRecoveryFailure => '클립 복구에 실패했습니다';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    return '현재 표시: 클립 $clips개, 초안 $drafts개';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => '다른 계정에 숨겨짐';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    return '클립 $clips개, 초안 $drafts개';
  }

  @override
  String get devOptionsClipRecoveryClaim => '이 계정으로 옮기기';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return '참조되지 않은 파일: $count개 ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => '라이브러리에 복원';

  @override
  String get devOptionsClipRecoveryEmpty => '복구할 항목이 없습니다';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    return '클립 $count개를 복구했습니다';
  }

  @override
  String get devOptionsClipRecoveryCopied => '복구 보고서를 복사했습니다';

  @override
  String get devOptionsStorageFootprint => '저장 공간 사용량';

  @override
  String get devOptionsStorageFootprintDescription =>
      '앱이 기록하는 모든 디렉터리입니다. 캐시를 지워도 일부만 확보됩니다.';

  @override
  String get devOptionsStorageFootprintMeasure => '측정';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return '합계: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => '저장 공간 보고서를 복사했습니다';

  @override
  String get devOptionsStorageFootprintFailure => '저장 공간을 측정할 수 없습니다';

  @override
  String get feedTuningMoreLabel => '이런 영상 더 보기';

  @override
  String get feedTuningLessLabel => '이런 영상 덜 보기';

  @override
  String get feedTuningUndo => '되돌리기';

  @override
  String get dmMessageBubbleVideoReplyHint => '참조된 동영상 열기';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSecureAccount => '계정 보호하기';

  @override
  String get settingsSessionExpired => '세션이 만료됐어요';

  @override
  String get settingsSessionExpiredSubtitle => '다시 로그인해서 전체 접근 권한을 복구해보세요';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => '크리에이터 분석';

  @override
  String get settingsSupportCenter => '고객센터';

  @override
  String get settingsNotifications => '알림';

  @override
  String get settingsBlueskyPublishing => 'Bluesky 게시';

  @override
  String get settingsBlueskyPublishingSubtitle => 'Bluesky로의 크로스 포스팅을 관리해요';

  @override
  String get settingsNostrSettings => 'Nostr 설정';

  @override
  String get settingsIntegratedApps => '연동된 앱';

  @override
  String get settingsIntegratedAppsSubtitle => 'Divine 안에서 돌아가는 승인된 서드파티 앱';

  @override
  String get settingsExperimentalFeatures => '실험적 기능';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      '종종 딱굱1거리는 조정들—궁금하면 한번 써보세요.';

  @override
  String get settingsLegal => '법적 고지';

  @override
  String get settingsIntegrationPermissions => '연동 권한';

  @override
  String get settingsIntegrationPermissionsSubtitle => '저장된 연동 승인을 검토하고 취소해보세요';

  @override
  String settingsVersion(String version) {
    return '버전 $version';
  }

  @override
  String get settingsVersionEmpty => '버전';

  @override
  String get settingsDeveloperModeAlreadyEnabled => '개발자 모드가 이미 켜져 있어요';

  @override
  String get settingsDeveloperModeEnabled => '개발자 모드가 켜졌어요!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '개발자 모드를 켜려면 $count번 더 탭해주세요';
  }

  @override
  String get settingsShareDivine => '친구들과 Divine을 공유해요';

  @override
  String get settingsSwitchAccount => '계정 전환';

  @override
  String get settingsAddAnotherAccount => '다른 계정 추가';

  @override
  String get settingsAccountSwitchFailed => '계정을 전환할 수 없었어요. 다시 시도해 주세요.';

  @override
  String get settingsUnsavedDraftsTitle => '저장되지 않은 초안';

  @override
  String get settingsUploadInProgressTitle => '업로드 중';

  @override
  String settingsUploadInProgressMessage(int count) {
    return '아직 동영상 $count개를 업로드 중이에요. 계정을 바꾸면 업로드가 중단되고, 동영상은 이 계정에 초안으로 남아요.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return '저장되지 않은 초안이 $count개 있어요. 계정을 바꿔도 초안은 유지되지만, 먼저 게시하거나 검토하는 게 좋아요.';
  }

  @override
  String get settingsCancel => '취소';

  @override
  String get settingsSwitchAnyway => '그래도 전환';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      '그 계정의 세션이 만료됐어요. 다시 로그인하려면 지금 쓰고 있는 계정에서 로그아웃해야 해요.';

  @override
  String get settingsAppVersionLabel => '앱 버전';

  @override
  String get settingsAppLanguage => '앱 언어';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (기기 기본값)';
  }

  @override
  String get settingsAppLanguageTitle => '앱 언어';

  @override
  String get settingsAppLanguageDescription => '앱 인터페이스에서 사용할 언어를 고르세요';

  @override
  String get settingsAppLanguageUseDeviceLanguage => '기기 언어 사용';

  @override
  String get settingsGeneralTitle => '일반 설정';

  @override
  String get settingsContentSafetyTitle => '콘텐츠 및 안전';

  @override
  String get generalSettingsSectionIntegrations => '연동';

  @override
  String get generalSettingsSectionViewing => '시청';

  @override
  String get generalSettingsSectionCreating => '만들기';

  @override
  String get generalSettingsSectionApp => '앱';

  @override
  String get appearanceSettingsTitle => '화면 모드';

  @override
  String get appearanceSettingsSubtitle => '이 기기에서 Divine이 보이는 방식을 선택하세요';

  @override
  String get appearanceSettingsSystem => '시스템 기본값';

  @override
  String get appearanceSettingsLight => '라이트';

  @override
  String get appearanceSettingsDark => '다크';

  @override
  String get generalSettingsClosedCaptions => '자막';

  @override
  String get generalSettingsClosedCaptionsSubtitle => '영상에 자막이 있을 때 보여줘요';

  @override
  String get generalSettingsVideoShapeSquareOnly => '정사각형 영상만';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      '피드를 클래식한 정사각형으로 유지해요';

  @override
  String get contentPreferencesTitle => '콘텐츠 환경설정';

  @override
  String get contentPreferencesContentFilters => '콘텐츠 필터';

  @override
  String get contentPreferencesContentFiltersSubtitle => '콘텐츠 경고 필터를 관리해요';

  @override
  String get contentPreferencesContentLanguage => '콘텐츠 언어';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (기기 기본값)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      '시청자가 콘텐츠를 필터링할 수 있도록 영상에 언어를 태그해주세요.';

  @override
  String get contentPreferencesUseDeviceLanguage => '기기 언어 사용 (기본값)';

  @override
  String get contentPreferencesAudioSharing => '내 오디오 재사용 허용';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      '켜면 다른 사람들이 내 영상의 오디오를 쓸 수 있어요';

  @override
  String get contentPreferencesMusicMode => '음악 모드';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      '악기 소리를 뭉개는 노이즈 제거를 꺼요. 음악에는 좋고, 목소리에는 조금 거칠어요.';

  @override
  String get contentPreferencesAccountLabels => '계정 라벨';

  @override
  String get contentPreferencesAccountLabelsEmpty => '내 콘텐츠에 스스로 라벨 달기';

  @override
  String get contentPreferencesAccountContentLabels => '계정 콘텐츠 라벨';

  @override
  String get contentPreferencesClearAll => '모두 지우기';

  @override
  String get contentPreferencesSelectAllThatApply => '내 계정에 해당하는 항목을 모두 선택해주세요';

  @override
  String get contentPreferencesDoneNoLabels => '완료 (라벨 없음)';

  @override
  String contentPreferencesDoneCount(int count) {
    return '완료 ($count개 선택)';
  }

  @override
  String get contentPreferencesAudioInputDevice => '오디오 입력 장치';

  @override
  String get contentPreferencesAutoRecommended => '자동 (추천)';

  @override
  String get contentPreferencesAutoSelectsBest => '가장 좋은 마이크를 자동으로 고르주세요';

  @override
  String get contentPreferencesSelectAudioInput => '오디오 입력 선택';

  @override
  String get contentPreferencesUnknownMicrophone => '알 수 없는 마이크';

  @override
  String get contentFiltersAdultContent => '성인 콘텐츠';

  @override
  String get contentFiltersViolenceGore => '폭력 및 잔혹 묘사';

  @override
  String get contentFiltersSubstances => '약물';

  @override
  String get contentFiltersOther => '기타';

  @override
  String get contentFiltersAgeGateMessage =>
      '성인 콘텐츠 필터를 사용하려면 안전 및 개인정보 설정에서 나이를 인증해주세요';

  @override
  String get contentFiltersShow => '보이기';

  @override
  String get contentFiltersWarn => '경고';

  @override
  String get contentFiltersFilterOut => '걸러내기';

  @override
  String get profileBlockedAccountNotAvailable => '이 계정은 이용할 수 없어요';

  @override
  String get profileInvalidId => '잘못된 프로필 ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Divine에서 $displayName님을 확인해보세요!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine의 $displayName';
  }

  @override
  String get profileShareFailed => '프로필을 공유하지 못했어요. 다시 시도해보세요.';

  @override
  String get profileCopyPublicKey => '공개 키 복사 (npub)';

  @override
  String get profileGetEmbedCode => '임베드 코드 가져오기';

  @override
  String get profilePublicKeyCopied => '공개 키를 클립보드에 복사했어요';

  @override
  String get profileEmbedCodeCopied => '임베드 코드를 클립보드에 복사했어요';

  @override
  String get profileMoreTooltip => '더보기';

  @override
  String get profileMoreSemanticLabel => '더 많은 옵션';

  @override
  String get profileAvatarLightboxBarrierLabel => '아바타 닫기';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => '아바타 미리보기 닫기';

  @override
  String get profileFollowingLabel => '팔로잉';

  @override
  String get profileFollowLabel => '팔로우';

  @override
  String get profileBlockedLabel => '차단됨';

  @override
  String get profileFollowersLabel => '팔로워';

  @override
  String get profileFollowingStatLabel => '팔로잉';

  @override
  String get profileVideosLabel => '영상';

  @override
  String get profileCollabsLabel => '콜라보';

  @override
  String get profileLikedLabel => '좋아요함';

  @override
  String get profileRepostsLabel => '리포스트';

  @override
  String get profileListsLabel => '리스트';

  @override
  String get profileCommentsLabel => '댓글';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '보내야 할 콜라보 초대가 $count건 남아 있어요',
      one: '보내야 할 콜라보 초대가 1건 남아 있어요',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      '초대를 대기열에 넣어뒀어요. 여기서 다시 시도해보세요.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return '\"$title\"에 대한 초대예요. 여기서 다시 시도해보세요.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => '다시 시도';

  @override
  String get profileCollaboratorInviteRetryingAction => '다시 시도 중';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      '지금은 콜라보 초대를 다시 보낼 수 없어요.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '보내야 할 콜라보 초대가 $count건 남아 있어요.',
      one: '보내야 할 콜라보 초대가 1건 남아 있어요.',
      zero: '콜라보 초대를 보냈어요.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '콜라보 상대 $count명이 초대를 받을 수 없어요.',
      one: '콜라보 상대 1명이 초대를 받을 수 없어요.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '사용자 $count명';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName님을 차단할까요?';
  }

  @override
  String get profileBlockExplanation => '사용자를 차단하면:';

  @override
  String get profileBlockBulletHidePosts => '이 사람의 게시물이 내 피드에 나타나지 않아요.';

  @override
  String get profileBlockBulletCantView =>
      '이 사람은 내 프로필을 보거나 팔로우하거나 게시물을 볼 수 없어요.';

  @override
  String get profileBlockBulletNoNotify => '차단은 상대에게 알림으로 전달되지 않아요.';

  @override
  String get profileBlockBulletYouCanView => '당신은 여전히 상대의 프로필을 볼 수 있어요.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName님 차단';
  }

  @override
  String get profileCancelButton => '취소';

  @override
  String get profileLearnMore => '자세히 알아보기';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName님을 차단 해제할까요?';
  }

  @override
  String get profileUnblockExplanation => '이 사용자를 차단 해제하면:';

  @override
  String get profileUnblockBulletShowPosts => '이 사람의 게시물이 다시 내 피드에 나타나요.';

  @override
  String get profileUnblockBulletCanView =>
      '이 사람이 내 프로필을 보거나 팔로우하거나 게시물을 볼 수 있게 돼요.';

  @override
  String get profileUnblockBulletNoNotify => '차단 해제는 상대에게 알림으로 전달되지 않아요.';

  @override
  String get profileLearnMoreAt => '자세히 보기: ';

  @override
  String get profileUnblockButton => '차단 해제';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName님 언팔로우';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName님 차단';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName님 차단 해제';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '$displayName 신고';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayName을(를) 목록에 추가';
  }

  @override
  String get profileNoCollabsTitle => '아직 콜라보 없음';

  @override
  String get profileCollabsOwnEmpty => '콜라보한 영상이 여기에 나타나요';

  @override
  String get profileCollabsOtherEmpty => '이 사람이 콜라보한 영상이 여기에 나타나요';

  @override
  String get profileErrorLoadingCollabs => '콜라보 영상을 불러오지 못했어요';

  @override
  String get profileNoSavedVideosTitle => '아직 저장한 게 없어요';

  @override
  String get profileSavedOwnEmpty => '공유 시트에서 영상을 북마크하면 여기에 표시돼요.';

  @override
  String get profileErrorLoadingSaved => '저장한 영상을 불러오지 못했어요';

  @override
  String get profileNoCommentsOwnTitle => '아직 댓글 없음';

  @override
  String get profileNoCommentsOtherTitle => '댓글 없음';

  @override
  String get profileCommentsOwnEmpty => '내가 쓴 댓글과 답글이 여기에 나타나요';

  @override
  String get profileCommentsOtherEmpty => '이 사람의 댓글과 답글이 여기에 나타나요';

  @override
  String get profileErrorLoadingComments => '댓글을 불러오지 못했어요';

  @override
  String get profileVideoRepliesSection => '영상 답글';

  @override
  String get profileCommentsSection => '댓글';

  @override
  String get profileEditLabel => '편집';

  @override
  String get profileLibraryLabel => '라이브러리';

  @override
  String get profileNoLikedVideosTitle => '아직 좋아요한 영상 없음';

  @override
  String get profileLikedOwnEmpty => '좋아요한 영상이 여기에 나타나요';

  @override
  String get profileLikedOtherEmpty => '이 사람이 좋아요한 영상이 여기에 나타나요';

  @override
  String get profileErrorLoadingLiked => '좋아요한 영상을 불러오지 못했어요';

  @override
  String get profileNoRepostsTitle => '아직 리포스트 없음';

  @override
  String get profileRepostsOwnEmpty => '리포스트한 영상이 여기에 나타나요';

  @override
  String get profileRepostsOtherEmpty => '이 사람이 리포스트한 영상이 여기에 나타나요';

  @override
  String get profileErrorLoadingReposts => '리포스트 영상을 불러오지 못했어요';

  @override
  String get profileNoVideosTitle => '아직 영상 없음';

  @override
  String get profileNoVideosOwnSubtitle => '첫 영상을 공유하고 여기에서 확인해보세요';

  @override
  String get profileNoVideosOtherSubtitle => '이 사용자는 아직 영상을 공유하지 않았어요';

  @override
  String profileVideoThumbnailLabel(int number) {
    return '영상 썸네일 $number';
  }

  @override
  String get profileShowMore => '더보기';

  @override
  String get profileShowLess => '접기';

  @override
  String get dmMessageDisplayLimitReached => '이 메시지의 나머지 부분은 표시되지 않습니다.';

  @override
  String get profileCompleteYourProfile => '프로필 완성하기';

  @override
  String get profileCompleteSubtitle => '이름, 소개, 사진을 추가해서 시작해보세요';

  @override
  String get profilePleaseTryAgain => '다시 시도해보세요';

  @override
  String get profileSecureYourAccount => '계정 보호하기';

  @override
  String get profileSecureSubtitle => '이메일과 비밀번호를 추가해서 어느 기기에서든 계정을 복구해보세요';

  @override
  String get profileRetryButton => '다시 시도';

  @override
  String get profileSessionExpired => '세션이 만료됐어요';

  @override
  String get profileSignInToRestore => '다시 로그인해서 전체 접근 권한을 복구해보세요';

  @override
  String get profileSignInButton => '로그인';

  @override
  String get profileMaybeLaterLabel => '나중에';

  @override
  String get profileSecurePrimaryButton => '이메일과 비밀번호 추가';

  @override
  String get profileCompletePrimaryButton => '프로필 업데이트';

  @override
  String get profileLoopsLabel => '루프';

  @override
  String get profileLikesLabel => '좋아요';

  @override
  String get profileMyLibraryLabel => '내 라이브러리';

  @override
  String get profileMessageLabel => '메시지';

  @override
  String get profileShareLabel => '프로필 공유';

  @override
  String get profileDeletedAccountName => '삭제된 계정';

  @override
  String get inboxActionReportVanishedAccount => '이 계정 신고';

  @override
  String get inboxActionBlockVanishedAccount => '이 계정 차단';

  @override
  String get inboxActionUnblockVanishedAccount => '이 계정 차단 해제';

  @override
  String get inboxReportedVanishedAccount => '이 계정을 신고했어요';

  @override
  String get inboxBlockedVanishedAccount => '이 계정을 차단했어요';

  @override
  String get inboxUnblockedVanishedAccount => '이 계정의 차단을 해제했어요';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      '이 대화가 받은 편지함에서 삭제돼요. 상대방이 다시 메시지를 보내면 새 대화가 시작돼요.';

  @override
  String get inboxConversationDeletedAccountSubtitle => '이 계정은 삭제되었습니다';

  @override
  String get profileUserFallback => '사용자';

  @override
  String get profileLinkCopied => '프로필 링크를 복사했어요';

  @override
  String get profileSetupEditProfileTitle => '프로필 편집';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'NIP-05 주소를 추가하기 전에 프로필을 설정하세요.';

  @override
  String get nostrSettingsNip05CreateProfileAction => '프로필 만들기';

  @override
  String get profileSetupBackLabel => '뒤로';

  @override
  String get profileSetupAboutNostr => 'Nostr란?';

  @override
  String get profileSetupProfilePublished => '프로필을 게시했어요!';

  @override
  String get profileSetupUnsavedChangesTitle => '변경사항을 저장할까요?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      '나가기 전에 수정한 내용을 저장하거나, 버리고 계속 진행하세요.';

  @override
  String get profileSetupUnsavedChangesSaveButton => '변경사항 저장';

  @override
  String get profileSetupUnsavedChangesDiscardButton => '변경사항 버리기';

  @override
  String get profileSetupUnsavedChangesKeepButton => '계속 편집';

  @override
  String get profileSetupCreateNewProfile => '새 프로필을 만들까요?';

  @override
  String get profileSetupNoExistingProfile =>
      '릴레이에서 기존 프로필을 찾지 못했어요. 지금 게시하면 새 프로필이 만들어져요. 계속할까요?';

  @override
  String get profileSetupPublishButton => '게시';

  @override
  String get profileSetupUsernameTaken => '이 사용자명은 방금 선점됐어요. 다른 이름을 고르세요.';

  @override
  String get profileSetupClaimFailed => '사용자명을 가져오지 못했어요. 다시 시도해보세요.';

  @override
  String get profileSetupPublishFailed => '프로필을 게시하지 못했어요. 다시 시도해보세요.';

  @override
  String get profileSetupNoRelaysConnected =>
      '네트워크에 연결할 수 없어요. 연결 상태를 확인하고 다시 시도해보세요.';

  @override
  String get profileSetupDisplayNameLabel => '표시 이름';

  @override
  String get profileSetupDisplayNameRequired => '표시 이름을 입력해주세요';

  @override
  String get profileSetupBioLabel => '소개 (선택)';

  @override
  String get profileSetupWebsiteLabel => '웹사이트 (선택)';

  @override
  String get profileSetupPublicKeyLabel => '공개 키 (npub)';

  @override
  String get profileSetupUsernameLabel => '사용자명 (선택)';

  @override
  String get profileSetupUsernameHelper =>
      '영문, 숫자, 하이픈을 사용하세요. 사용자 이름은 divine.video 주소가 됩니다. 공백이나 기호는 표시 이름에 사용하세요.';

  @override
  String get profileSetupSaveButton => '저장';

  @override
  String get profileSetupSavingButton => '저장 중...';

  @override
  String get profileSetupImageUrlTitle => '이미지 URL 추가';

  @override
  String get profileSetupImageSelectionFailed =>
      '이미지 선택에 실패했어요. 아래에 이미지 URL을 붙여넣어보세요.';

  @override
  String get profileSetupImagesTypeGroup => '이미지';

  @override
  String get cameraPickErrorPermissionDenied =>
      '카메라 접근이 꺼져 있어요. 설정에서 켜면 사진을 찍을 수 있어요.';

  @override
  String get cameraPickErrorPermissionRestricted => '이 기기에서는 카메라 접근이 허용되지 않아요.';

  @override
  String get cameraPickErrorBusy => '선택기가 이미 열려 있어요. 닫고 다시 시도해보세요.';

  @override
  String get cameraPickErrorGeneric => '카메라를 열지 못했어요. 다시 시도해보세요.';

  @override
  String get profileSetupGotItButton => '알겠어요';

  @override
  String get profileSetupUploadFailedGeneric =>
      '이미지를 올리지 못했어요. 잠시 후 다시 시도해주세요.';

  @override
  String get profileSetupUploadNetworkError =>
      '네트워크 오류: 인터넷 연결을 확인하고 다시 시도해주세요.';

  @override
  String get profileSetupUploadAuthError => '인증 오류: 로그아웃 후 다시 로그인해보세요.';

  @override
  String get profileSetupUploadFileTooLarge =>
      '파일이 너무 커요: 더 작은 이미지를 고르세요 (최대 10MB).';

  @override
  String get profileSetupUploadServerError =>
      '이미지를 올리지 못했어요. 서버가 일시적으로 사용할 수 없어요. 잠시 후 다시 시도해주세요.';

  @override
  String get profileSetupBannerClearButton => '배너 지우기';

  @override
  String get profileSetupBannerChangeColor => '배너 색상';

  @override
  String get profileSetupChangeBannerTitle => '배너 변경';

  @override
  String get profileSetupBannerColorPickerTitle => '배너 색상 변경';

  @override
  String get profileSetupBannerColorCustom => '사용자 지정';

  @override
  String get profileSetupBannerColorNone => '색상 없음';

  @override
  String get profileSetupBannerColorLime => '라임';

  @override
  String get profileSetupBannerColorYellow => '노랑';

  @override
  String get profileSetupBannerColorViolet => '바이올렛';

  @override
  String get profileSetupBannerColorPink => '핑크';

  @override
  String get profileSetupBannerColorOrange => '오렌지';

  @override
  String get profileSetupBannerColorPurple => '퍼플';

  @override
  String get profileSetupAvatarClearButton => '사진 삭제';

  @override
  String get profileSetupImageTakePhoto => '사진 촬영';

  @override
  String get profileSetupImageUploadFromCameraRoll => '카메라 롤에서 업로드';

  @override
  String get profileSetupImagePasteLink => '이미지 링크 붙여넣기';

  @override
  String get profileSetupEditAvatarLabel => '프로필 사진 편집';

  @override
  String get profileSetupEditBannerLabel => '배너 편집';

  @override
  String get profileSetupUsernameChecking => '사용 가능 여부 확인 중...';

  @override
  String get profileSetupUsernameAvailable => '사용 가능한 이름이에요!';

  @override
  String get profileSetupUsernameTakenIndicator => '이미 사용 중인 이름이에요';

  @override
  String get profileSetupUsernameReserved => '예약된 이름이에요';

  @override
  String get profileSetupContactSupport => '고객센터 문의';

  @override
  String get profileSetupCheckAgain => '다시 확인';

  @override
  String get profileSetupUsernameBurned => '이 사용자명은 더 이상 사용할 수 없어요';

  @override
  String get profileSetupUsernameInvalidFormat => '문자, 숫자, 하이픈만 쓸 수 있어요';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      '사용자 이름은 하이픈으로 시작하거나 끝날 수 없어요';

  @override
  String get profileSetupUsernameInvalidLength => '사용자명은 3~63자 사이여야 해요';

  @override
  String get profileSetupUsernameNetworkError =>
      '사용 가능 여부를 확인하지 못했어요. 다시 시도해보세요.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric => '잘못된 사용자명 형식';

  @override
  String get profileSetupUsernameCheckFailed => '사용 가능 여부 확인에 실패했어요';

  @override
  String get profileSetupUsernameReservedTitle => '예약된 이름';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return '$username은(는) 예약된 이름이에요. 왜 당신의 것이어야 하는지 알려주세요.';
  }

  @override
  String get profileSetupUsernameReservedHint => '예: 내 브랜드명, 활동명 등';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      '이미 고객센터에 문의하셨나요? \"다시 확인\"을 눌러 해제되었는지 확인해보세요.';

  @override
  String get profileSetupSupportRequestSent => '요청을 보냈어요! 곷 답변드릴게요.';

  @override
  String get profileSetupCouldntOpenEmail =>
      '이메일을 열지 못했어요. names@divine.video로 보내주세요';

  @override
  String get profileSetupSendRequest => '요청 보내기';

  @override
  String get profileSetupUseOwnNip05 => '내 NIP-05 주소 쓰기';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 주소';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      '잘못된 NIP-05 형식이에요 (예: name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'divine.video는 위의 사용자명 필드를 사용해주세요';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 주소';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'divine.video 사용자 이름을 쓰거나, 직접 관리하는 도메인의 NIP-05 주소로 핸들을 연결하세요.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'NIP-05 저장';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05를 저장했어요';

  @override
  String get nostrSettingsNip05SaveFailed => 'NIP-05를 저장하지 못했어요. 다시 시도해 주세요.';

  @override
  String get profileSetupNip05ConfirmTitle => '직접 만든 NIP-05를 사용할까요?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05는 you@yourdomain.com 같은 이름을 당신의 Nostr 신원과 연결합니다. 도메인을 관리하고 올바른 경로에 인증 파일을 올려야 해요. 설정이 잘못되면 사람들이 당신을 찾을 수 없고 인증된 핸들도 사라집니다. 이미 설정을 마친 경우에만 계속하세요.';

  @override
  String get profileSetupNip05ConfirmContinue => '계속';

  @override
  String get profileSetupNip05ConfirmCancel => '취소';

  @override
  String get profileSetupProfilePicturePreview => '프로필 사진 미리보기';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine은 Nostr를 기반으로 만들어졌어요,';

  @override
  String get nostrInfoIntroDescription =>
      ' 하나의 회사나 플랫폼에 의존하지 않고 온라인으로 소통할 수 있게 해주는 검열 저항 개방형 프로토콜이에요. ';

  @override
  String get nostrInfoIntroIdentity => 'Divine에 가입하면 새 Nostr 아이덴티티를 받게 돼요.';

  @override
  String get nostrInfoOwnership =>
      'Nostr를 쓰면 내 콘텐츠, 아이덴티티, 소셜 그래프를 소유하고 여러 앱에서 쓸 수 있어요. 더 많은 선택, 적은 종속, 더 건강하고 탄력적인 소셜 인터넷을 만들 수 있죠.';

  @override
  String get nostrInfoLingo => 'Nostr 용어:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' 당신의 공개 Nostr 주소예요. 안전하게 공유할 수 있고, 다른 사람들이 Nostr 앱에서 당신을 찾거나 팔로우하거나 메시지를 보낼 수 있어요.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' 당신의 개인 키이자 소유권 증명이에요. Nostr 아이덴티티를 완전히 통제할 수 있으니까, ';

  @override
  String get nostrInfoNsecWarning => '절대 비밀로 간직하세요!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr 사용자명:';

  @override
  String get nostrInfoUsernameDescription =>
      ' npub에 연결되는 사람이 읽을 수 있는 이름(예: @name.divine.video)이에요. 이메일 주소처럼 Nostr 아이덴티티를 알아보고 인증하기 쉬워져요.';

  @override
  String get nostrInfoLearnMoreAt => '자세히 보기: ';

  @override
  String get nostrInfoGotIt => '알겠어요!';

  @override
  String get videoGridRefreshLabel => '더 많은 영상을 찾는 중';

  @override
  String get videoGridOptionsTitle => '영상 옵션';

  @override
  String get videoGridEditVideo => '영상 편집';

  @override
  String get videoGridEditVideoSubtitle => '제목, 설명, 해시태그 수정';

  @override
  String get videoGridDeleteVideo => '영상 삭제';

  @override
  String get videoGridDeleteVideoSubtitle =>
      '이 영상을 Divine에서 삭제해요. 다른 Nostr 클라이언트에는 계속 표시될 수 있어요.';

  @override
  String get videoGridDeletingContent => '콘텐츠 삭제 중...';

  @override
  String get exploreTabFeatured => '추천';

  @override
  String get exploreTabClassics => '클래식';

  @override
  String get exploreTabNew => '신규';

  @override
  String get exploreTabPopular => '인기';

  @override
  String get exploreTabCategories => '카테고리';

  @override
  String get exploreTabForYou => '추천';

  @override
  String get exploreTabLists => '리스트';

  @override
  String get exploreTabIntegratedApps => '연동된 앱';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => '아직 아무것도 없어요. 곧 다시 확인해 주세요.';

  @override
  String get featuredTabLoadFailed => '이 컬렉션을 불러오지 못했어요.';

  @override
  String get featuredTabRetry => '다시 시도';

  @override
  String get exploreNoVideosAvailable => '이용 가능한 영상이 없어요';

  @override
  String get exploreDiscoverLists => '리스트 둘러보기';

  @override
  String get exploreAboutLists => '리스트란?';

  @override
  String get exploreAboutListsDescription =>
      '리스트는 Divine 콘텐츠를 두 가지 방식으로 정리하고 큐레이션할 수 있게 해줘요:';

  @override
  String get explorePeopleLists => '사람 리스트';

  @override
  String get explorePeopleListsDescription =>
      '크리에이터 그룹을 팔로우하고 그들의 최신 영상을 확인해보세요';

  @override
  String get exploreVideoLists => '영상 리스트';

  @override
  String get exploreVideoListsDescription => '좋아하는 영상의 플레이리스트를 만들어서 나중에 다시 보세요';

  @override
  String get exploreMyLists => '내 리스트';

  @override
  String get exploreSubscribedLists => '구독 리스트';

  @override
  String get exploreErrorLoadingLists => '리스트를 불러오지 못했어요. 다시 시도해보세요.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '새 영상 $count개',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '새 영상 $count개 불러오기',
    );
    return '$_temp0';
  }

  @override
  String get videoPlayerPlayVideo => '영상 재생';

  @override
  String get videoPlayerMute => '영상 음소거';

  @override
  String get videoPlayerUnmute => '영상 음소거 해제';

  @override
  String get videoPlayerTapHint => '탭하여 재생하거나 일시정지하세요. 이중 탭으로 좋아요.';

  @override
  String get videoSettingsMenuOpen => '재생 설정 열기';

  @override
  String get videoSettingsMenuClose => '재생 설정 닫기';

  @override
  String get videoSettingsCaptionsEnable => '자막 사용';

  @override
  String get videoSettingsCaptionsDisable => '자막 사용 안 함';

  @override
  String get videoSettingsAutoAdvanceOn => '자동 넘기기 켜짐';

  @override
  String get videoSettingsAutoAdvanceOff => '자동 넘기기 꺼짐';

  @override
  String get videoSettingsCaptionsOn => '자막 켜짐';

  @override
  String get videoSettingsCaptionsOff => '자막 꺼짐';

  @override
  String get videoSettingsCaptionsOnForVideo => '이 영상의 자막을 켰어요';

  @override
  String get videoSettingsCaptionsOffForVideo => '이 영상의 자막을 껐어요';

  @override
  String get contentWarningLabel => '콘텐츠 경고';

  @override
  String get contentWarningNudity => '노출';

  @override
  String get contentWarningSexualContent => '성적 콘텐츠';

  @override
  String get contentWarningPornography => '음란물';

  @override
  String get contentWarningGraphicMedia => '자극적 매체';

  @override
  String get contentWarningViolence => '폭력';

  @override
  String get contentWarningSelfHarm => '자해';

  @override
  String get contentWarningDrugUse => '약물 사용';

  @override
  String get contentWarningAlcohol => '알코올';

  @override
  String get contentWarningTobacco => '담배';

  @override
  String get contentWarningGambling => '도박';

  @override
  String get contentWarningProfanity => '욕설';

  @override
  String get contentWarningFlashingLights => '번짝이는 불빛';

  @override
  String get contentWarningAiGenerated => 'AI 생성';

  @override
  String get contentWarningSpoiler => '스포일러';

  @override
  String get contentWarningSensitiveContent => '민감한 콘텐츠';

  @override
  String get contentWarningDescNudity => '노출 또는 부분 노출을 포함해요';

  @override
  String get contentWarningDescSexual => '성적 콘텐츠를 포함해요';

  @override
  String get contentWarningDescPorn => '노골적인 음란물을 포함해요';

  @override
  String get contentWarningDescGraphicMedia => '자극적이거나 불편한 이미지를 포함해요';

  @override
  String get contentWarningDescViolence => '폭력적인 콘텐츠를 포함해요';

  @override
  String get contentWarningDescSelfHarm => '자해 관련 내용을 포함해요';

  @override
  String get contentWarningDescDrugs => '약물 관련 콘텐츠를 포함해요';

  @override
  String get contentWarningDescAlcohol => '알코올 관련 콘텐츠를 포함해요';

  @override
  String get contentWarningDescTobacco => '담배 관련 콘텐츠를 포함해요';

  @override
  String get contentWarningDescGambling => '도박 관련 콘텐츠를 포함해요';

  @override
  String get contentWarningDescProfanity => '강한 언어를 포함해요';

  @override
  String get contentWarningDescFlashingLights => '번짝이는 불빛을 포함해요 (광과민 주의)';

  @override
  String get contentWarningDescAiGenerated => '이 콘텐츠는 AI로 생성됐어요';

  @override
  String get contentWarningDescSpoiler => '스포일러를 포함해요';

  @override
  String get contentWarningDescContentWarning => '크리에이터가 민감한 콘텐츠로 표시했어요';

  @override
  String get contentWarningDescDefault => '크리에이터가 이 콘텐츠를 표시했어요';

  @override
  String get contentWarningDetailsTitle => '콘텐츠 경고';

  @override
  String get contentWarningDetailsSubtitle => '크리에이터가 적용한 라벨:';

  @override
  String get contentWarningManageFilters => '콘텐츠 필터 관리';

  @override
  String get contentWarningViewAnyway => '그래도 보기';

  @override
  String get contentWarningReportContentTooltip => '콘텐츠 신고';

  @override
  String get contentWarningBlockUserTooltip => '사용자 차단';

  @override
  String get contentWarningBlockedTitle => '콘텐츠가 차단됐어요';

  @override
  String get contentWarningBlockedPolicy => '정책 위반으로 이 콘텐츠가 차단됐어요.';

  @override
  String get contentWarningNoticeTitle => '콘텐츠 안내';

  @override
  String get contentWarningPotentiallyHarmfulTitle => '유해할 수 있는 콘텐츠';

  @override
  String get contentWarningView => '보기';

  @override
  String get contentWarningReportAction => '신고';

  @override
  String get contentWarningHideAllLikeThis => '이런 종류의 콘텐츠 모두 숨기기';

  @override
  String get contentWarningNoFilterYet => '이 경고에 대한 저장된 필터가 아직 없어요.';

  @override
  String get contentWarningHiddenConfirmation => '앞으로 이런 게시물은 숨길게요.';

  @override
  String get communitySuggestTitle => '이 영상의 분류를 도와주세요';

  @override
  String get communitySuggestSubtitle =>
      '콘텐츠 경고가 빠져 있나요? 제안은 공개되고 서명이 붙으며, 되돌릴 수 없어요.';

  @override
  String get communitySuggestSubmit => '제안하기';

  @override
  String get communitySuggestSuccess => '고마워요. 제안을 보냈어요.';

  @override
  String get communitySuggestFailure => '제안을 보내지 못했어요. 다시 시도해주세요.';

  @override
  String get communitySuggestAlready => '이미 제안함';

  @override
  String get communitySuggestActionLabel => '분류하기';

  @override
  String get videoErrorNotFound => '영상을 찾을 수 없어요';

  @override
  String get videoErrorPlayback => '영상 재생 오류';

  @override
  String get videoErrorAgeRestricted => '연령 제한 콘텐츠';

  @override
  String get videoErrorUnavailable => '영상을 사용할 수 없어요';

  @override
  String get videoErrorUnavailableBody => '이 영상은 지금 사용할 수 없어요.';

  @override
  String get videoErrorRetry => '다시 시도';

  @override
  String get videoErrorContentRestricted => '콘텐츠 제한됨';

  @override
  String get videoErrorContentRestrictedBody => '이 영상은 콘텐츠 규칙 위반으로 삭제되었습니다.';

  @override
  String get videoErrorVerifyAgeBody => '이 영상을 보려면 나이를 인증해주세요.';

  @override
  String get videoErrorSkip => '건너뛰기';

  @override
  String get videoErrorVerifyAgeButton => '나이 인증';

  @override
  String get videoErrorVerifyAgeFailed => '나이를 확인할 수 없습니다. 다시 시도해보세요';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      '확인 시간이 초과되었습니다. 연결을 확인하거나 잠시 후 다시 시도해보세요';

  @override
  String get videoErrorAdultContentHiddenTitle => '성인 콘텐츠가 꺼져 있어요';

  @override
  String get videoErrorAdultContentHiddenBody => '이 영상을 보려면 콘텐츠 필터에서 켜 주세요.';

  @override
  String get videoErrorAdultContentHiddenAction => '콘텐츠 필터 열기';

  @override
  String get videoDetailLoadError => '영상을 불러오지 못했어요';

  @override
  String get videoDetailLoadErrorBody => '오는 길에 뭔가 어긋났어요. 다시 시도해 보세요.';

  @override
  String get videoDetailNotFoundBody =>
      '삭제됐거나, 닿을 수 없는 곳에 있거나, 설정 때문에 숨겨진 걸 수도 있어요.';

  @override
  String get databaseCorruptionTitle => '로컬 데이터가 손상됐어요';

  @override
  String get databaseCorruptionBody =>
      'Divine을 껐다가 다시 열어주세요. 자동으로 고쳐드릴게요. 초안과 클립은 최대한 살려볼게요. 나머지는 다시 불러와요.';

  @override
  String get databaseCorruptionCloseButton => 'Divine 닫기';

  @override
  String get videoDetailContextTitle => '공유된 영상';

  @override
  String get videoDetailCloseSemanticLabel => '동영상 플레이어 닫기';

  @override
  String get videoFollowButtonFollow => '팔로우';

  @override
  String get audioAttributionOriginalSound => '오리지널 사운드';

  @override
  String get audioAttributionUnavailableSound => '사운드를 사용할 수 없어요';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '@$creatorName +$additionalCreatorCount님에게 영감받아';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '@$creatorName님에게 영감받아';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '@$name님과 함께';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '@$name님 외 +$count명과 함께';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '콜라보레이터 $count명',
    );
    return '$_temp0. 탭해서 프로필을 보세요.';
  }

  @override
  String get videoCollaboratorPendingDecoration => '대기 중';

  @override
  String get videoCollaboratorPendingSemanticLabel => '대기 중인 공동 작업자';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending명 대기 중)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. 탭하면 프로필을 볼 수 있어요.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. 탭하면 이 해시태그가 달린 영상을 볼 수 있어요.';
  }

  @override
  String get listAttributionFallback => '리스트';

  @override
  String get shareVideoLabel => '영상 공유';

  @override
  String sharePostSharedWith(String recipientName) {
    return '$recipientName님과 게시물을 공유했어요';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명과 게시물을 공유했어요',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => '영상을 보내지 못했어요';

  @override
  String get shareAddedToBookmarks => '북마크에 추가했어요';

  @override
  String get shareRemovedFromBookmarks => '북마크에서 뺐어요';

  @override
  String get shareFailedToAddBookmark => '북마크 추가에 실패했어요';

  @override
  String get shareFailedToRemoveBookmark => '북마크를 지우지 못했어요';

  @override
  String get shareActionFailed => '작업에 실패했어요';

  @override
  String get shareWithTitle => '공유 대상';

  @override
  String get shareFindPeople => '사람 찾기';

  @override
  String get shareFindPeopleMultiline => '사람\n찾기';

  @override
  String get shareSent => '보냄';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name님 선택됨';
  }

  @override
  String get shareMessageHint => '메시지 추가 (선택)...';

  @override
  String get videoActionUnlike => '좋아요 취소';

  @override
  String get videoActionLike => '좋아요';

  @override
  String get videoActionAutoLabel => '자동';

  @override
  String get videoActionLikeLabel => '좋아요';

  @override
  String get videoActionReplyLabel => '답글';

  @override
  String get videoActionRepostLabel => '리포스트';

  @override
  String get videoActionShareLabel => '공유';

  @override
  String get videoActionReportLabel => '신고';

  @override
  String get videoActionReport => '동영상 신고';

  @override
  String get videoActionEditLabel => '편집';

  @override
  String get videoActionEdit => '동영상 편집';

  @override
  String get videoActionAboutLabel => '정보';

  @override
  String get videoActionEnableAutoAdvance => '자동 넘기기 활성화';

  @override
  String get videoActionDisableAutoAdvance => '자동 넘기기 비활성화';

  @override
  String get videoActionRemoveRepost => '리포스트 취소';

  @override
  String get videoActionRepost => '영상 리포스트';

  @override
  String get videoActionViewComments => '댓글 보기';

  @override
  String get videoActionMoreOptions => '더 많은 옵션';

  @override
  String get videoEngagementLikersTitle => '좋아요한 사용자';

  @override
  String get videoEngagementRepostersTitle => '리포스트한 사용자';

  @override
  String get videoEngagementLikersEmpty => '아직 좋아요가 없습니다';

  @override
  String get videoEngagementRepostersEmpty => '아직 리포스트가 없습니다';

  @override
  String get videoEngagementLoadFailed => '목록을 불러올 수 없습니다';

  @override
  String get videoOverlayOpenMetadataFromTitle => '영상 세부 정보 열기';

  @override
  String get videoOverlayOpenMetadataFromDescription => '영상 세부 정보 열기';

  @override
  String get videoOverlayCommentBarHint => '댓글 달기...';

  @override
  String get videoOverlayCommentBarSemanticLabel => '댓글 달기';

  @override
  String get videoOverlayCommentBarSendLabel => '댓글 보내기';

  @override
  String get videoOverlayCommentPostedSnackbar => '댓글을 남겼어요';

  @override
  String get videoOverlayCommentPostFailedSnackbar => '댓글을 남기지 못했어요';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '루프',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Divine 아님';

  @override
  String get metadataBadgeHumanMade => '사람 제작';

  @override
  String get metadataSoundsLabel => '사운드';

  @override
  String get metadataOriginalSound => '오리지널 사운드';

  @override
  String get metadataVerificationLabel => '인증';

  @override
  String get metadataDeviceAttestation => '기기 증명';

  @override
  String get metadataPgpSignature => 'PGP 서명';

  @override
  String get metadataC2paCredentials => 'C2PA 콘텐츠 자격 증명';

  @override
  String get metadataProofManifest => '증명 매니페스트';

  @override
  String get metadataVerificationInfoTooltip => '이 검사들은 무슨 뜻인가요?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => '이 검사들의 의미';

  @override
  String get metadataVerificationInfoIntro =>
      '이 신호들은 카메라와 영상 파일 자체에서 나옵니다. 영상이 담고 있는 신호가 많을수록 출처에 대해 더 많은 것을 증명할 수 있습니다.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      '휴대폰 운영체제가 이 영상을 녹화한 앱을 보증했습니다. 누군가 올린 파일이 아니라 카메라에서 나왔다는 강력한 근거입니다.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      '영상은 촬영되는 순간 암호학적으로 서명되었습니다. 이후 한 프레임만 바뀌어도 서명은 깨집니다.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      '파일 안에 함께 담겨 이동하는 업계 표준 출처 기록입니다. Divine이 아닌 앱에서도 확인할 수 있습니다.';

  @override
  String get metadataVerificationInfoProofManifest =>
      '전체 ProofMode 기록: 파일 지문, 타임스탬프, 촬영 정황이 영상과 함께 묶여 있습니다.';

  @override
  String get metadataVerificationInfoFootnote =>
      '검사가 없다고 해서 영상이 가짜인 것은 아닙니다. 예전 클립과 업로드에는 애초에 없었습니다. 그 부분을 증명할 수 없다는 뜻일 뿐입니다.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return '자세한 내용은 $url에서 확인하세요';
  }

  @override
  String get metadataCreatorLabel => '크리에이터';

  @override
  String get metadataCollaboratorsLabel => '콜라보레이터';

  @override
  String get metadataInspiredByLabel => '영감';

  @override
  String get metadataRepostedByLabel => '리포스트';

  @override
  String metadataMoreReposters(int count) {
    return '외 $count명';
  }

  @override
  String metadataLoopsLabel(int count) {
    return '루프';
  }

  @override
  String get metadataLikesLabel => '좋아요';

  @override
  String get metadataCommentsLabel => '댓글';

  @override
  String get metadataRepostsLabel => '리포스트';

  @override
  String get metadataVineStatsLabel => 'Vine에서';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops 루프 · $likes 좋아요 · $comments 댓글 · $reposts 리포스트';
  }

  @override
  String get metadataDivineStatsLabel => 'Divine에서';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views 조회수 · $likes 좋아요 · $comments 댓글 · $reposts 리포스트';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return '$date에 게시됨';
  }

  @override
  String get devOptionsTitle => '개발자 옵션';

  @override
  String get devOptionsDisableDeveloperMode => '개발자 모드 비활성화';

  @override
  String get devOptionsDisableDeveloperModeSubtitle => '설정에서 개발자 옵션 숨기기';

  @override
  String get devOptionsDisableDeveloperModeToast => '개발자 모드가 비활성화됨';

  @override
  String get devOptionsShorebirdTitle => 'Shorebird 패치';

  @override
  String get devOptionsShorebirdPatchLabel => '실행 중인 패치';

  @override
  String get devOptionsShorebirdNoPatch => '설치된 패치 없음';

  @override
  String get devOptionsShorebirdUnavailable => '이 빌드에서는 사용할 수 없음';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      '패치는 shorebird release로 만든 빌드에서만 작동합니다.';

  @override
  String get devOptionsShorebirdLoading => '패치 상태를 읽는 중…';

  @override
  String get devOptionsShorebirdNotChecked => '스테이징 트랙을 아직 확인하지 않았습니다.';

  @override
  String get devOptionsShorebirdCheck => '스테이징 트랙 확인';

  @override
  String get devOptionsShorebirdApply => '스테이징 패치 적용';

  @override
  String get devOptionsShorebirdUseStable => '안정 업데이트로 돌아가기';

  @override
  String get devOptionsShorebirdChecking => '스테이징 트랙 확인 중…';

  @override
  String get devOptionsShorebirdUpdateAvailable => '적용할 수 있는 스테이징 패치가 있습니다.';

  @override
  String get devOptionsShorebirdUpToDate => '이 릴리스용 스테이징 패치가 없습니다.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      '다운로드했습니다. 불러오려면 앱을 다시 시작하세요.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      '롤백이 준비되었습니다. 기본 릴리스로 돌아가려면 다시 시작하세요.';

  @override
  String get devOptionsShorebirdApplying => '다운로드 및 설치 중…';

  @override
  String get devOptionsShorebirdApplied => '설치했습니다. 불러오려면 앱을 다시 시작하세요.';

  @override
  String get devOptionsShorebirdUnchanged =>
      '설치된 항목이 없습니다. 스테이징 트랙을 확인하고 다시 시도하세요.';

  @override
  String get devOptionsShorebirdSelectingStableTrack => '안정 트랙 선택 중…';

  @override
  String get devOptionsShorebirdStableRestored =>
      '안정 트랙을 선택했습니다. 안정 패치를 확인하려면 앱을 다시 시작하세요.';

  @override
  String get devOptionsShorebirdFailure => '작동하지 않았습니다. 자세한 내용은 로그를 확인하세요.';

  @override
  String get devOptionsPageLoadTimes => '페이지 로딩 시간';

  @override
  String get devOptionsNoPageLoads =>
      '아직 기록된 페이지 로드가 없어요.\n앱을 둘러보며 타이밍 데이터를 쌓아보세요.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return '표시: ${visibleMs}ms  |  데이터: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => '가장 느린 화면';

  @override
  String get devOptionsVideoPlaybackFormat => '영상 재생 형식';

  @override
  String get devOptionsSwitchEnvironmentTitle => '환경을 전환할까요?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '$envName으로 전환할까요?\n\n캐시된 영상 데이터가 지워지고 새 릴레이에 다시 연결돼요.';
  }

  @override
  String get devOptionsCancel => '취소';

  @override
  String get devOptionsSwitch => '전환';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '$envName으로 전환했어요';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '$formatName으로 전환했어요 — 캐시 삭제됨';
  }

  @override
  String get featureFlagTitle => '기능 플래그';

  @override
  String get featureFlagResetAllTooltip => '모든 플래그를 기본값으로 재설정';

  @override
  String get featureFlagError => '오류';

  @override
  String get relaySettingsTitle => '릴레이';

  @override
  String get relaySettingsInfoTitle => 'Divine은 개방형 시스템이에요 - 연결은 당신이 조절해요';

  @override
  String get relaySettingsInfoDescription =>
      '이 릴레이들이 분산형 Nostr 네트워크 전체에 콘텐츠를 전달해요. 원하는 대로 릴레이를 추가하거나 제거할 수 있어요.';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr에 대해 자세히 보기 →';

  @override
  String get relaySettingsFindPublicRelays => 'nostr.co.uk에서 공개 릴레이 찾기 →';

  @override
  String get relaySettingsAppNotFunctional => '앱이 작동하지 않아요';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine은 영상을 불러오고 콘텐츠를 게시하고 데이터를 동기화하려면 최소 하나의 릴레이가 필요해요.';

  @override
  String get relaySettingsRestoreDefaultRelay => '기본 릴레이 복원';

  @override
  String get relaySettingsAddCustomRelay => '커스텀 릴레이 추가';

  @override
  String get relaySettingsAddRelay => '릴레이 추가';

  @override
  String get relaySettingsRetry => '다시 시도';

  @override
  String get relaySettingsNoStats => '아직 사용 가능한 통계가 없어요';

  @override
  String get relaySettingsConnection => '연결';

  @override
  String get relaySettingsConnected => '연결됨';

  @override
  String get relaySettingsDisconnected => '연결 끊김';

  @override
  String get relaySettingsSessionDuration => '세션 길이';

  @override
  String get relaySettingsLastConnected => '마지막 연결';

  @override
  String get relaySettingsDisconnectedLabel => '연결 끊김';

  @override
  String get relaySettingsReason => '이유';

  @override
  String get relaySettingsActiveSubscriptions => '활성 구독';

  @override
  String get relaySettingsTotalSubscriptions => '전체 구독';

  @override
  String get relaySettingsEventsReceived => '받은 이벤트';

  @override
  String get relaySettingsEventsSent => '보낸 이벤트';

  @override
  String get relaySettingsRequestsThisSession => '이번 세션 요청';

  @override
  String get relaySettingsFailedRequests => '실패한 요청';

  @override
  String get relaySettingsLoadingRelayInfo => '릴레이 정보 불러오는 중...';

  @override
  String get relaySettingsAboutRelay => '릴레이 정보';

  @override
  String get relaySettingsSupportedNips => '지원 NIP';

  @override
  String get relaySettingsSoftware => '소프트웨어';

  @override
  String get relaySettingsViewWebsite => '웹사이트 보기';

  @override
  String get relaySettingsRemoveRelayTitle => '릴레이를 제거할까요?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return '이 릴레이를 정말 제거할까요?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Divine 릴레이를 제거할까요?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Divine 릴레이를 제거하면 앱 사용 경험이 나빠져요. 영상, 게시, 동기화가 불안정해질 수 있어요. Nostr에 익숙한 사용자만 하는 게 좋아요.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => '릴레이 제거';

  @override
  String get relaySettingsCancel => '취소';

  @override
  String get relaySettingsRemove => '제거';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return '릴레이를 제거했어요: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => '릴레이 제거에 실패했어요';

  @override
  String get relaySettingsForcingReconnection => '릴레이 재연결 중...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '릴레이 $count개에 연결됐어요!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      '릴레이 연결에 실패했어요. 네트워크 연결을 확인해주세요.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      '이 기기에 저장됐어요. 게시가 다시 작동하면 계정에 동기화할게요.';

  @override
  String get relaySettingsAddRelayTitle => '릴레이 추가';

  @override
  String get relaySettingsAddRelayPrompt => '추가할 릴레이의 WebSocket URL을 입력해주세요:';

  @override
  String get relaySettingsBrowsePublicRelays => 'nostr.co.uk에서 공개 릴레이 둘러보기';

  @override
  String get relaySettingsAdd => '추가';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return '릴레이를 추가했어요: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      '릴레이 추가에 실패했어요. URL을 확인하고 다시 시도해보세요.';

  @override
  String get relaySettingsInvalidUrl => '릴레이 URL은 wss:// 또는 ws://로 시작해야 해요';

  @override
  String get relaySettingsInsecureUrl =>
      '릴레이 URL은 wss://를 써야 해요 (ws://는 localhost에서만 허용돼요)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return '기본 릴레이를 복원했어요: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      '기본 릴레이 복원에 실패했어요. 네트워크 연결을 확인해주세요.';

  @override
  String get relaySettingsCouldNotOpenBrowser => '브라우저를 열 수 없어요';

  @override
  String get relaySettingsFailedToOpenLink => '링크를 열 수 없어요';

  @override
  String get relaySettingsExternalRelay => '외부 릴레이';

  @override
  String get relaySettingsNotConnected => '연결되지 않음';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return '$duration 전에 연결 끊김';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '구독 $count개';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '이벤트 $count개';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration 전';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine은 분산형 게시를 위해 Nostr 프로토콜을 써요. 콘텐츠는 당신이 고른 릴레이에 저장되고, 키가 곧 당신의 신원이에요.';

  @override
  String get nostrSettingsSectionNetwork => '네트워크';

  @override
  String get nostrSettingsSectionAccount => '계정';

  @override
  String get nostrSettingsSectionDangerZone => '위험 구역';

  @override
  String get nostrSettingsRelays => '릴레이';

  @override
  String get nostrSettingsRelaysSubtitle => 'Nostr 릴레이 연결을 관리해요';

  @override
  String get nostrSettingsRelayDiagnostics => '릴레이 진단';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle => '릴레이 연결과 네트워크 문제를 디버그해요';

  @override
  String get nostrSettingsMediaServers => '미디어 서버';

  @override
  String get nostrSettingsMediaServersSubtitle => 'Blossom 업로드 서버를 설정해요';

  @override
  String get settingsDeveloperOptions => '개발자 옵션';

  @override
  String get settingsDeveloperOptionsSubtitle => '환경 전환과 디버그 설정';

  @override
  String get nostrSettingsKeyManagement => '키 관리';

  @override
  String get nostrSettingsKeyManagementSubtitle => 'Nostr 키를 내보내고, 백업하고, 복원해요';

  @override
  String get nostrSettingsClientAttribution => '클라이언트 표시';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      '게시하는 이벤트에 Divine 클라이언트 태그를 포함해 다른 Nostr 앱이 올바르게 표시할 수 있게 해요. 이게 없으면 보낸 신고는 모더레이터가 검토할 때 비중이 낮아져요.';

  @override
  String get nostrSettingsMoveAccount => '계정 옮기기';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      '아카이브를 다운로드하고 게시물과 동영상을 다른 릴레이나 미디어 서버로 옮기세요.';

  @override
  String get nostrSettingsRemoveKeys => '기기에서 키 제거';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      '이 기기에서만 개인 키를 삭제해요. 콘텐츠는 릴레이에 그대로 남지만, 다시 계정에 접근하려면 nsec 백업이 필요해요.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      '이 기기에서 이 계정을 제거하지 못했어요. 다시 시도해주세요.';

  @override
  String get nostrSettingsDeleteAccount => '계정 및 데이터 삭제';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      '콘텐츠 삭제 요청을 보내고 이 기기에서 로그아웃해요. 릴레이, 클라이언트, 검색 색인, 그리고 로그인된 다른 기기에는 사본이 남을 수 있어요.';

  @override
  String get relayDiagnosticTitle => '릴레이 진단';

  @override
  String get relayDiagnosticRefreshTooltip => '진단 새로고침';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return '마지막 새로고침: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => '릴레이 상태';

  @override
  String get relayDiagnosticInitialized => '초기화됨';

  @override
  String get relayDiagnosticReady => '준비 완료';

  @override
  String get relayDiagnosticNotInitialized => '초기화되지 않음';

  @override
  String get relayDiagnosticDatabaseEvents => '데이터베이스 이벤트';

  @override
  String get relayDiagnosticActiveSubscriptions => '활성 구독';

  @override
  String get relayDiagnosticExternalRelays => '외부 릴레이';

  @override
  String get relayDiagnosticConfigured => '구성됨';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '릴레이 $count개';
  }

  @override
  String get relayDiagnosticConnectedLabel => '연결됨';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => '영상 이벤트';

  @override
  String get relayDiagnosticHomeFeed => '홈 피드';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '영상 $count개';
  }

  @override
  String get relayDiagnosticDiscovery => '둘러보기';

  @override
  String get relayDiagnosticLoading => '불러오는 중';

  @override
  String get relayDiagnosticYes => '예';

  @override
  String get relayDiagnosticNo => '아니요';

  @override
  String get relayDiagnosticTestDirectQuery => '직접 쿼리 테스트';

  @override
  String get relayDiagnosticNetworkConnectivity => '네트워크 연결';

  @override
  String get relayDiagnosticRunNetworkTest => '네트워크 테스트 실행';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom 서버';

  @override
  String get relayDiagnosticTestAllEndpoints => '모든 엔드포인트 테스트';

  @override
  String get relayDiagnosticStatus => '상태';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => '오류';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => '기본 URL';

  @override
  String get relayDiagnosticSummary => '요약';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount 정상 (평균 ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => '모두 재테스트';

  @override
  String get relayDiagnosticRetrying => '다시 시도 중...';

  @override
  String get relayDiagnosticRetryConnection => '연결 다시 시도';

  @override
  String get relayDiagnosticTroubleshooting => '문제 해결';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• 초록 상태 = 연결되어 정상 작동 중\n• 적색 상태 = 연결 실패\n• 네트워크 테스트가 실패하면 인터넷 연결을 확인하세요\n• 릴레이가 구성되었는데 연결 안 되면 \"연결 다시 시도\"를 탭해주세요\n• 디버깅을 위해 이 화면을 캡처해두세요';

  @override
  String get relayDiagnosticAllEndpointsHealthy => '모든 REST 엔드포인트가 정상이에요!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      '일부 REST 엔드포인트가 실패했어요 - 위 세부 정보를 확인해주세요';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '데이터베이스에서 영상 이벤트 $count개를 찾았어요';
  }

  @override
  String get relayDiagnosticQueryFailed => '쿼리 실패. 다시 시도해보세요.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '릴레이 $count개에 연결됐어요!';
  }

  @override
  String get relayDiagnosticFailedToConnect => '릴레이 연결에 실패했어요';

  @override
  String get relayDiagnosticConnectionRetryFailed => '연결 재시도 실패. 다시 시도해보세요.';

  @override
  String get relayDiagnosticConnectedAuthenticated => '연결 및 인증됨';

  @override
  String get relayDiagnosticConnectedOnly => '연결됨';

  @override
  String get relayDiagnosticNotConnected => '연결되지 않음';

  @override
  String get relayDiagnosticNoRelaysConfigured => '구성된 릴레이가 없어요';

  @override
  String get relayDiagnosticFailed => '실패';

  @override
  String get notificationSettingsTitle => '알림';

  @override
  String get notificationSettingsResetTooltip => '기본값으로 재설정';

  @override
  String get notificationSettingsTypes => '알림 종류';

  @override
  String get notificationSettingsLikes => '좋아요';

  @override
  String get notificationSettingsLikesSubtitle => '누군가 내 영상을 좋아할 때';

  @override
  String get notificationSettingsComments => '댓글';

  @override
  String get notificationSettingsCommentsSubtitle => '누군가 내 영상에 댓글을 달 때';

  @override
  String get notificationSettingsFollows => '팔로우';

  @override
  String get notificationSettingsFollowsSubtitle => '누군가 나를 팔로우할 때';

  @override
  String get notificationSettingsMentions => '멘션';

  @override
  String get notificationSettingsMentionsSubtitle => '멘션될 때';

  @override
  String get notificationSettingsReposts => '리포스트';

  @override
  String get notificationSettingsRepostsSubtitle => '누군가 내 영상을 리포스트할 때';

  @override
  String get notificationSettingsNewPosts => '새 영상';

  @override
  String get notificationSettingsNewPostsSubtitle => '지켜보는 사람이 게시할 때';

  @override
  String get notificationSettingsActions => '작업';

  @override
  String get notificationSettingsMarkAllAsRead => '모두 읽음으로 표시';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle => '모든 알림을 읽음으로 표시';

  @override
  String get notificationSettingsAllMarkedAsRead => '모든 알림을 읽음으로 표시했어요';

  @override
  String get notificationSettingsMarkAllAsReadFailed => '모두 읽음으로 표시하지 못했어요';

  @override
  String get notificationSettingsResetToDefaults => '설정이 기본값으로 되돌아갔어요';

  @override
  String get notificationSettingsAbout => '알림 안내';

  @override
  String get notificationSettingsAboutDescription =>
      '알림은 Nostr 프로토콜로 구동돼요. 실시간 업데이트는 Nostr 릴레이에의 연결에 따라 달라져요. 일부 알림은 지연될 수 있어요.';

  @override
  String get safetySettingsWhatYouSee => '보이는 것';

  @override
  String get safetySettingsWhatYouPublish => '게시하는 것';

  @override
  String get safetySettingsShowDivineHostedOnly => 'Divine이 호스팅하는 영상만 보이기';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      '다른 매체 호스트에서 제공되는 영상은 숨겨요';

  @override
  String get safetySettingsModeration => '조절';

  @override
  String get safetySettingsBlockedUsers => '차단된 사용자';

  @override
  String get safetySettingsAgeVerification => '나이 인증';

  @override
  String get safetySettingsAgeConfirmation => '나는 18세 이상임을 확인해요';

  @override
  String get safetySettingsAgeRequired => '성인 콘텐츠를 보려면 필요해요';

  @override
  String get safetySettingsAgeLockedForMinor => '계정을 위해 잠겨 있어요';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle => '공식 조절 서비스 (기본 켜짐)';

  @override
  String get safetySettingsPeopleIFollow => '내가 팔로우하는 사람';

  @override
  String get safetySettingsPeopleIFollowSubtitle => '팔로우하는 사람들의 라벨을 구독해요';

  @override
  String get safetySettingsAddCustomLabeler => '커스텀 라벨러 추가';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub 입력...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => '커스텀 라벨러 추가';

  @override
  String get safetySettingsRemoveLabeler => '라벨러 제거';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub 주소를 입력해주세요';

  @override
  String get safetySettingsNoBlockedUsers => '차단한 사용자가 없어요';

  @override
  String get safetySettingsUnblock => '차단 해제';

  @override
  String get safetySettingsUserUnblocked => '사용자 차단을 해제했어요';

  @override
  String get safetySettingsCancel => '취소';

  @override
  String get safetySettingsAdd => '추가';

  @override
  String get analyticsTitle => '크리에이터 분석';

  @override
  String get analyticsDiagnosticsTooltip => '진단';

  @override
  String get analyticsDiagnosticsSemanticLabel => '진단 토글';

  @override
  String get analyticsRetry => '다시 시도';

  @override
  String get analyticsUnableToLoad => '분석을 불러올 수 없어요.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired => '크리에이터 분석을 보려면 로그인해주세요.';

  @override
  String get analyticsViewDataUnavailable =>
      '이 게시물에 대한 조회수는 현재 릴레이에서 제공되지 않아요. 좋아요/댓글/리포스트 지표는 정확해요.';

  @override
  String get analyticsViewDataTitle => '조회 데이터';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return '업데이트 $time • 점수는 Funnelcake에서 사용 가능한 경우 좋아요, 댓글, 리포스트, 조회/루프를 사용해요.';
  }

  @override
  String get analyticsVideos => '영상';

  @override
  String get analyticsViews => '조회수';

  @override
  String get analyticsInteractions => '상호작용';

  @override
  String get analyticsEngagement => '참여도';

  @override
  String get analyticsFollowers => '팔로워';

  @override
  String get analyticsAvgPerPost => '게시물당 평균';

  @override
  String get analyticsInteractionMix => '상호작용 구성';

  @override
  String get analyticsLikes => '좋아요';

  @override
  String get analyticsComments => '댓글';

  @override
  String get analyticsReposts => '리포스트';

  @override
  String get analyticsPerformanceHighlights => '주요 성과';

  @override
  String get analyticsMostViewed => '가장 많이 본 영상';

  @override
  String get analyticsMostDiscussed => '가장 많이 이야기된 영상';

  @override
  String get analyticsMostReposted => '가장 많이 리포스트된 영상';

  @override
  String get analyticsNoVideosYet => '아직 영상이 없어요';

  @override
  String get analyticsViewDataUnavailableShort => '조회 데이터 없음';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '조회수 $count';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '댓글 $count';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '리포스트 $count';
  }

  @override
  String get analyticsTopContent => '인기 콘텐츠';

  @override
  String get analyticsPublishPrompt => '순위를 보려면 영상을 몇 개 게시해보세요.';

  @override
  String get analyticsEngagementRateExplainer => '오른쪽 % = 참여율 (상호작용 ÷ 조회수).';

  @override
  String get analyticsEngagementRateNoViews =>
      '참여율은 조회 데이터가 필요해요; 조회수가 제공될 때까지 N/A로 표시돼요.';

  @override
  String get analyticsEngagementLabel => '참여도';

  @override
  String get analyticsViewsUnavailable => '조회수 없음';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '상호작용 $count';
  }

  @override
  String get analyticsPostAnalytics => '게시물 분석';

  @override
  String get analyticsOpenPost => '게시물 열기';

  @override
  String get analyticsRecentDailyInteractions => '최근 일별 상호작용';

  @override
  String get analyticsNoActivityYet => '이 기간에는 아직 활동이 없어요.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      '상호작용 = 게시일 기준 좋아요 + 댓글 + 리포스트.';

  @override
  String get analyticsDailyBarExplainer => '막대 길이는 이 기간의 최고치에 대한 상대적 값이에요.';

  @override
  String get analyticsAudienceSnapshot => '시청자 스냅샷';

  @override
  String analyticsFollowersCount(String count) {
    return '팔로워: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return '팔로잉: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Funnelcake가 시청자 분석 엔드포인트를 추가하면 시청자 소스/지역/시간 분석이 채워져요.';

  @override
  String get analyticsRetention => '재시청률';

  @override
  String get analyticsRetentionWithViews =>
      'Funnelcake에서 초/버킷별 재시청 데이터가 도착하면 재시청 곡선과 시청 시간 분석이 나타나요.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Funnelcake에서 조회+시청 시간 분석이 반환될 때까지 재시청 데이터는 이용할 수 없어요.';

  @override
  String get analyticsDiagnostics => '진단';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return '전체 영상: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return '조회 데이터 있음: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return '조회 데이터 없음: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return '체워짐 (배치): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return '체워짐 (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return '소스: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => '고정 데이터 사용';

  @override
  String get analyticsNa => '해당 없음';

  @override
  String get authCreateNewAccount => '새 Divine 계정 만들기';

  @override
  String get authCreateNewAccountShort => '새 계정 만들기';

  @override
  String get authSignInDifferentAccount => '다른 계정으로 로그인';

  @override
  String get authUseAnotherAccount => '다른 계정 사용';

  @override
  String authContinueAs(String displayName) {
    return '$displayName(으)로 계속';
  }

  @override
  String get authRecoveryDraftsOwner => '임시저장 및 클립이 이 계정에 저장되어 있어요';

  @override
  String get authRecoveryOtherAccountWarning => '여기서 로그인하면 해당 임시저장과 클립이 숨겨져요';

  @override
  String get authTermsPrefix => '아래 옵션을 선택하면 만 16세 이상임(또는 ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine 연령 인증';

  @override
  String get authTermsAfterAgeAuthorization => '을 완료했음)을 확인하고 다음에 동의하게 됩니다: ';

  @override
  String get authTermsOfService => '이용약관';

  @override
  String get authPrivacyPolicy => '개인정보 처리방침';

  @override
  String get authTermsAnd => ', 그리고 ';

  @override
  String get authSafetyStandards => '안전 기준';

  @override
  String get authAmberNotInstalled => 'Amber 앱이 설치되지 않았어요';

  @override
  String get authAmberConnectionFailed => 'Amber와 연결하지 못했어요';

  @override
  String get authPasswordResetSent => '해당 이메일로 가입된 계정이 있으면 비밀번호 재설정 링크를 보냈어요.';

  @override
  String get authSignInTitle => '로그인';

  @override
  String get authEmailLabel => '이메일';

  @override
  String get authPasswordLabel => '비밀번호';

  @override
  String get authConfirmPasswordLabel => '비밀번호 확인';

  @override
  String get authEmailRequired => '이메일을 입력해주세요';

  @override
  String get authEmailInvalid => '올바른 이메일을 입력해주세요';

  @override
  String get authPasswordRequired => '비밀번호를 입력해주세요';

  @override
  String get authConfirmPasswordRequired => '비밀번호를 다시 입력해주세요';

  @override
  String get authPasswordsDoNotMatch => '비밀번호가 일치하지 않아요';

  @override
  String get authForgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get authImportNostrKey => 'Nostr 키 가져오기';

  @override
  String get authConnectSignerApp => '서명 앱으로 연결';

  @override
  String get authSignInWithAmber => 'Amber로 로그인';

  @override
  String get authSignInWithBrowserExtension => '브라우저 확장 프로그램으로 로그인';

  @override
  String get authNip07ConnectionFailed => '브라우저 확장 프로그램에 연결할 수 없습니다.';

  @override
  String get authNip07ExtensionNotFound =>
      '브라우저 확장 프로그램을 찾을 수 없습니다. Alby, nos2x 또는 다른 NIP-07 호환 확장 프로그램을 설치하세요.';

  @override
  String get authSignInOptionsTitle => '로그인 옵션';

  @override
  String get authInfoEmailPasswordTitle => '이메일 및 비밀번호';

  @override
  String get authInfoEmailPasswordDescription =>
      'Divine 계정으로 로그인하세요. 이메일과 비밀번호로 가입했다면 여기서 쓰면 돼요.';

  @override
  String get authInfoImportNostrKeyDescription =>
      '이미 Nostr 아이덴티티가 있나요? 다른 클라이언트에서 nsec 개인 키를 가져오세요.';

  @override
  String get authInfoSignerAppTitle => '서명 앱';

  @override
  String get authInfoSignerAppDescription =>
      '키 보안 강화를 위해 nsecBunker같은 NIP-46 호환 원격 서명 앱을 쓰세요.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      '안드로이드에서 Amber 서명 앱으로 Nostr 키를 안전하게 관리해보세요.';

  @override
  String get authInfoBrowserExtensionTitle => '브라우저 확장 프로그램';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Alby 또는 nos2x와 같은 NIP-07 브라우저 확장 프로그램으로 로그인하세요. 키는 확장 프로그램에 그대로 유지되며 Divine은 절대 볼 수 없습니다.';

  @override
  String get authSignInErrorInvalidCredentials =>
      '이메일 또는 비밀번호가 잘못되었습니다. 다시 시도해 주세요.';

  @override
  String get authSignInErrorEmailNotVerified =>
      '로그인하기 전에 이메일을 인증하세요 — 받은 편지함에서 링크를 확인하세요.';

  @override
  String get authSignInErrorInvalidEmail => '유효한 이메일 주소가 아닌 것 같습니다.';

  @override
  String get authSignInErrorNetwork => '서버에 연결할 수 없습니다. 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get authSignInErrorGeneric => '문제가 발생했습니다. 다시 시도해 주세요.';

  @override
  String get authSignInOptionsHintPrefix => '지난번에 어떻게 로그인했는지 기억나지 않나요? ';

  @override
  String get authSignInOptionsHintCta => '모든 로그인 옵션 보기';

  @override
  String get authCreateAccountTitle => '계정 만들기';

  @override
  String get authBackToInviteCode => '초대 코드로 돌아가기';

  @override
  String get authUseDivineNoBackup => '백업 없이 Divine 쓰기';

  @override
  String get authSkipConfirmTitle => '마지막으로...';

  @override
  String get authSkipConfirmKeyCreated =>
      '들어오셨어요! Divine 계정을 구동할 안전한 키를 만들어드릴게요.';

  @override
  String get authSkipConfirmKeyOnly =>
      '이메일이 없으면 Divine이 이 계정을 당신의 것이라고 알 수 있는 유일한 방법은 키뿐이에요.';

  @override
  String get authSkipConfirmRecommendEmail =>
      '앱에서 키를 확인할 수는 있지만, 기술적 지식이 없다면 지금 이메일과 비밀번호를 추가하시는 걸 추천드려요. 이 기기를 잃거나 초기화해도 쉽게 로그인하고 계정을 복구할 수 있어요.';

  @override
  String get authAddEmailPassword => '이메일과 비밀번호 추가';

  @override
  String get authUseThisDeviceOnly => '이 기기에서만 쓰기';

  @override
  String get authCompleteRegistration => '가입 완료하기';

  @override
  String get authVerifying => '인증 중...';

  @override
  String get authVerificationLinkSent => '다음 주소로 인증 링크를 보냈어요:';

  @override
  String get authClickVerificationLink => '이메일의 링크를 클릭해서\n가입을 완료해주세요.';

  @override
  String get authPleaseWaitVerifying => '이메일을 인증하는 동안 기다려주세요...';

  @override
  String get authWaitingForVerification => '인증 대기 중';

  @override
  String get authOpenEmailApp => '이메일 앱 열기';

  @override
  String get authVerificationPinPrompt => '또는 이메일로 받은 6자리 코드를 입력하세요';

  @override
  String get authVerificationPinFieldLabel => '6자리 코드';

  @override
  String get authVerificationPinSubmit => '코드 확인';

  @override
  String get authVerificationResendPrompt => '못 받으셨나요?';

  @override
  String get authVerificationResend => '다시 보내기';

  @override
  String authVerificationResendCooldown(String time) {
    return '$time 후 다시 보내기';
  }

  @override
  String get authVerificationResendFailed => '이메일을 다시 보내지 못했어요. 다시 시도해주세요.';

  @override
  String get authVerificationResendExpired =>
      '해당 가입이 만료되었어요. 새 코드를 받으려면 처음부터 다시 시작하세요.';

  @override
  String get authVerificationResendUnavailable =>
      '지금은 재전송할 수 없어요. 이미 보내드린 이메일의 6자리 코드를 사용하세요.';

  @override
  String get authVerificationPollingStopped =>
      '자동 확인을 중단했어요. 로그인을 마치려면 이메일의 6자리 코드를 입력하세요.';

  @override
  String get authWelcomeToDivine => 'Divine에 오신 걸 환영해요!';

  @override
  String get authEmailVerified => '이메일이 인증됐어요.';

  @override
  String get authSigningYouIn => '로그인 중';

  @override
  String get authErrorTitle => '이런.';

  @override
  String get authVerificationFailed => '이메일 인증에 실패했어요.\n다시 시도해보세요.';

  @override
  String get authStartOver => '처음부터 다시';

  @override
  String get authEmailVerifiedLogin => '이메일 인증 완료! 계속하려면 로그인해주세요.';

  @override
  String get authVerificationLinkExpired => '이 인증 링크는 더 이상 유효하지 않아요.';

  @override
  String get authVerificationConnectionError =>
      '이메일을 인증할 수 없어요. 연결을 확인하고 다시 시도해주세요.';

  @override
  String get authWaitlistConfirmTitle => '들어오셨어요!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return '$email로 업데이트를 공유할게요.\n초대 코드가 재고가 생기면 보내드릴게요.';
  }

  @override
  String get authOk => '확인';

  @override
  String get authTryAgain => '다시 시도';

  @override
  String get authContactSupport => '고객센터 문의';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email을(를) 열 수 없어요';
  }

  @override
  String get authAddInviteCode => '초대 코드를 입력해주세요';

  @override
  String get authInviteCodeLabel => '초대 코드';

  @override
  String get authEnterYourCode => '코드 입력';

  @override
  String get authNext => '다음';

  @override
  String get authJoinWaitlist => '대기자 명단 등록';

  @override
  String get authJoinWaitlistTitle => '대기자 명단에 등록하기';

  @override
  String get authJoinWaitlistDescription => '이메일을 알려주시면 접근이 열릴 때 업데이트를 보내드릴게요.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Divine의 영감을 보내주세요';

  @override
  String get authInviteAccessHelp => '초대 접근 도움말';

  @override
  String get authGeneratingConnection => '연결 생성 중...';

  @override
  String get authConnectedAuthenticating => '연결됨! 인증 중...';

  @override
  String get authConnectionTimedOut => '연결 시간 초과';

  @override
  String get authApproveConnection => '서명 앱에서 연결을 승인했는지 확인해주세요.';

  @override
  String get authConnectionCancelled => '연결이 취소됐어요';

  @override
  String get authConnectionCancelledMessage => '연결이 취소됐어요.';

  @override
  String get authConnectionFailed => '연결 실패';

  @override
  String get authUnknownError => '알 수 없는 오류가 발생했어요.';

  @override
  String get authNostrConnectStartFailed =>
      '서명 앱에 닿지 못했어요. 연결을 확인하고 다시 시도해주세요.';

  @override
  String get authNostrConnectInvalidSession =>
      '이 연결 링크는 더 이상 유효하지 않아요. 새로 시작해주세요.';

  @override
  String get authNostrConnectSetupFailed =>
      '거의 다 왔는데 — 로그인을 마무리하지 못했어요. 다시 시도해주세요.';

  @override
  String get authUrlCopied => 'URL을 클립보드에 복사했어요';

  @override
  String get authConnectToDivine => 'Divine에 연결';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL 붙여넣기';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl => '잘못된 bunker URL이에요. bunker://로 시작해야 해요';

  @override
  String get authScanSignerApp => '서명 앱으로 스캔해서\n연결해주세요.';

  @override
  String authWaitingForConnection(int seconds) {
    return '연결 대기 중... $seconds초';
  }

  @override
  String get authCopyUrl => 'URL 복사';

  @override
  String get authShare => '공유';

  @override
  String get authAddBunker => 'Bunker 추가';

  @override
  String get authCompatibleSignerApps => '호환 서명 앱';

  @override
  String get authFailedToConnect => '연결에 실패했어요';

  @override
  String get authResetPasswordTitle => '비밀번호 재설정';

  @override
  String get authResetPasswordSubtitle => '새 비밀번호를 입력해주세요. 최소 8자 이상이어야 해요.';

  @override
  String get authNewPasswordLabel => '새 비밀번호';

  @override
  String get authConfirmNewPasswordLabel => '새 비밀번호 확인';

  @override
  String get authPasswordTooShort => '비밀번호는 최소 8자 이상이어야 해요';

  @override
  String get authPasswordResetSuccess => '비밀번호를 재설정했어요. 다시 로그인해주세요.';

  @override
  String get authPasswordResetFailed => '비밀번호 재설정에 실패했어요';

  @override
  String get authUnexpectedError => '예상치 못한 오류가 발생했어요. 다시 시도해주세요.';

  @override
  String get authUpdatePassword => '비밀번호 변경';

  @override
  String get authSecureAccountTitle => '계정 보호';

  @override
  String get authUnableToAccessKeys => '키에 접근할 수 없어요. 다시 시도해보세요.';

  @override
  String get authRegistrationFailed => '가입에 실패했어요';

  @override
  String get authRegistrationComplete => '가입이 완료됐어요. 이메일을 확인해주세요.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => '재설정 이메일을 보내지 못했어요.';

  @override
  String get authSending => '보내는 중...';

  @override
  String get authSignInButton => '로그인';

  @override
  String get authVerificationErrorTimeout => '인증 시간이 초과됐어요. 다시 가입해보세요.';

  @override
  String get authVerificationErrorMissingCode => '인증 실패 — 인증 코드가 없어요.';

  @override
  String get authVerificationErrorPollFailed => '인증에 실패했어요. 다시 시도해주세요.';

  @override
  String get authVerificationErrorNetworkExchange =>
      '로그인 중 네트워크 오류가 발생했어요. 다시 시도해주세요.';

  @override
  String get authVerificationErrorOAuthExchange => '인증에 실패했어요. 다시 가입해보세요.';

  @override
  String get authVerificationErrorSignInFailed =>
      '로그인에 실패했어요. 수동으로 로그인을 시도해보세요.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      '이 이메일은 이미 등록되어 있어요. 대신 로그인해 주세요.';

  @override
  String get authVerificationErrorPinInvalid => '코드가 일치하지 않아요. 다시 확인하고 시도해주세요.';

  @override
  String get authVerificationErrorPinExpired =>
      '코드가 만료됐어요. 다시 보내기를 탭해서 새 코드를 받으세요.';

  @override
  String get authVerificationErrorPinLocked =>
      '시도 횟수가 너무 많아요. 다시 보내기를 탭해서 새 코드를 받으세요.';

  @override
  String get authVerificationErrorPinFailed => '코드를 확인할 수 없어요. 다시 시도해주세요.';

  @override
  String get authVerificationErrorPinUnavailable =>
      '지금은 코드 입력을 사용할 수 없어요. 이메일의 링크를 탭하거나 다시 보내기로 새 코드를 받으세요.';

  @override
  String get authInviteCodeErrorMalformed => 'ABCD-EFGH 형식의 초대 코드를 입력해요.';

  @override
  String get authInviteCodeErrorNotFound => '그 초대 코드는 올바르지 않은 것 같아요.';

  @override
  String get authInviteCodeErrorAlreadyUsed => '그 초대 코드는 이미 사용했거나 취소됐어요.';

  @override
  String get authInviteGateErrorCreatorFull => '이 크리에이터의 초대장이 모두 소진됐어요';

  @override
  String get authInviteGateErrorUnavailable =>
      '그 초대 코드는 사용할 수 없어요. 대기자 명단에 등록하면 자리가 나는 대로 초대장을 보내드릴게요.';

  @override
  String get authInviteGateErrorCheckFailed => '그 코드를 확인할 수 없었어요. 다시 시도해 주세요.';

  @override
  String get authInviteGateErrorUnknown => '문제가 생겼어요. 초대 코드를 다시 시도해 주세요.';

  @override
  String get authInviteErrorAlreadyUsed =>
      '그 초대 코드는 더 이상 쓸 수 없어요. 초대 코드로 돌아가거나, 대기자 명단에 등록하거나, 고객센터에 문의해주세요.';

  @override
  String get authInviteErrorInvalid =>
      '그 초대 코드는 지금 쓸 수 없어요. 초대 코드로 돌아가거나, 대기자 명단에 등록하거나, 고객센터에 문의해주세요.';

  @override
  String get authInviteErrorTemporary =>
      '지금은 초대 코드를 확인할 수 없어요. 초대 코드로 돌아가서 다시 시도하거나 고객센터에 문의해주세요.';

  @override
  String get authInviteErrorUnknown =>
      '초대를 활성화할 수 없어요. 초대 코드로 돌아가거나, 대기자 명단에 등록하거나, 고객센터에 문의해주세요.';

  @override
  String get shareSheetSave => '저장';

  @override
  String get shareSheetRemoveFromSaved => '저장 취소';

  @override
  String get shareSheetSaveToGallery => '갤러리에 저장';

  @override
  String get shareSheetSaveWithWatermark => '워터마크와 함께 저장';

  @override
  String get shareSheetSaveVideo => '영상 저장';

  @override
  String get shareSheetAddToClips => '클립에 추가';

  @override
  String get shareSheetNameClipTitle => '이 클립 이름 정하기';

  @override
  String get shareSheetNameClipSubtitle => '라이브러리에서 알아볼 수 있는 이름을 골라주세요.';

  @override
  String get shareSheetClipTitleLabel => '클립 제목';

  @override
  String get shareSheetSaveClip => '클립 저장';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\"을(를) 클립에 저장했어요';
  }

  @override
  String get shareSheetUntitledClip => '제목 없는 클립';

  @override
  String get shareSheetAddToClipsFailed => '클립에 추가할 수 없어요';

  @override
  String get shareSheetAddToList => '리스트에 추가';

  @override
  String get shareSheetCopy => '복사';

  @override
  String get shareSheetShareVia => '다른 곳으로 공유';

  @override
  String get shareSheetEventJson => '이벤트 JSON';

  @override
  String get shareSheetEventId => '이벤트 ID';

  @override
  String get shareSheetMoreActions => '더 많은 작업';

  @override
  String get shareSheetCrosspost => '크로스 포스팅';

  @override
  String get crosspostSheetTitle => '이 영상 크로스 포스팅하기';

  @override
  String get crosspostSheetSubtitle => '연결된 플랫폼으로 보내요. 게시까지 몇 분 걸릴 수 있어요.';

  @override
  String get crosspostSubmit => '크로스 포스팅';

  @override
  String get crosspostStatusQueued => '대기 중';

  @override
  String get crosspostStatusUploading => '업로드 중';

  @override
  String get crosspostStatusProcessing => '처리 중';

  @override
  String get crosspostStatusPosted => '게시됨';

  @override
  String get crosspostStatusFailed => '실패';

  @override
  String get crosspostStatusSkipped => '건너뜀';

  @override
  String get crosspostStatusNeedsReauth => '재연결 필요';

  @override
  String get crosspostViewPost => '게시물 보기';

  @override
  String crosspostReconnectPrompt(String platform) {
    return '계속 게시하려면 크로스 포스팅 설정에서 $platform 계정을 다시 연결해주세요.';
  }

  @override
  String get crosspostReconnect => '다시 연결';

  @override
  String get crosspostErrorNotOwner => '내 영상만 크로스 포스팅할 수 있어요.';

  @override
  String get crosspostErrorNotEligible => '이 영상은 크로스 포스팅 대상이 아니에요.';

  @override
  String get crosspostErrorNotConnected => '해당 플랫폼이 연결되어 있지 않아요.';

  @override
  String get crosspostErrorUnauthorized => '계정을 다시 연결하고 다시 시도해주세요.';

  @override
  String get crosspostErrorNetwork => '크로스 포스팅 서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.';

  @override
  String get crosspostFailedGeneric => '크로스 포스팅에 실패했어요.';

  @override
  String get crosspostStillWorking =>
      '아직 작업 중이에요. 닫아도 괜찮아요 — 게시는 백그라운드에서 계속돼요.';

  @override
  String get crosspostDone => '완료';

  @override
  String get watermarkDownloadSavedToCameraRoll => '카메라 롤에 저장했어요';

  @override
  String get watermarkDownloadShare => '공유';

  @override
  String get watermarkDownloadDone => '완료';

  @override
  String get watermarkDownloadPhotosAccessNeeded => '사진 접근 권한이 필요해요';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      '영상을 저장하려면 설정에서 사진 접근을 허용해주세요.';

  @override
  String get watermarkDownloadOpenSettings => '설정 열기';

  @override
  String get watermarkDownloadNotNow => '다음에';

  @override
  String get watermarkDownloadFailed => '다운로드에 실패했어요';

  @override
  String get watermarkDownloadDismiss => '닫기';

  @override
  String get watermarkDownloadStageDownloading => '영상 다운로드 중';

  @override
  String get watermarkDownloadStageWatermarking => '워터마크 추가 중';

  @override
  String get watermarkDownloadStageSaving => '카메라 롤에 저장 중';

  @override
  String get watermarkDownloadStageDownloadingDesc => '네트워크에서 영상을 가져오는 중...';

  @override
  String get watermarkDownloadStageWatermarkingDesc => 'Divine 워터마크를 적용하는 중...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      '워터마크가 적용된 영상을 카메라 롤에 저장하는 중...';

  @override
  String get shareMenuBookmarks => '북마크';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '팔로우 세트 $count개 사용 가능';
  }

  @override
  String get peopleListsAddToList => '목록에 추가';

  @override
  String get peopleListsSheetTitle => '목록에 추가';

  @override
  String get peopleListsEmptyTitle => '목록이 없습니다';

  @override
  String get peopleListsEmptySubtitle => '목록을 만들어 사람들을 그룹화하세요.';

  @override
  String get peopleListsCreateList => '목록 만들기';

  @override
  String get peopleListsNewListTitle => '새 목록';

  @override
  String get peopleListsRouteTitle => '사람 목록';

  @override
  String get peopleListsListNameLabel => '목록 이름';

  @override
  String get peopleListsListNameHint => '친한 친구들';

  @override
  String get peopleListsCreateButton => '만들기';

  @override
  String get peopleListsAddPeopleTitle => '사람 추가';

  @override
  String get peopleListsAddPeopleTooltip => '사람 추가';

  @override
  String get peopleListsAddPeopleSemanticLabel => '목록에 사람 추가';

  @override
  String get peopleListsListNotFoundTitle => '목록을 찾을 수 없음';

  @override
  String get peopleListsListNotFoundSubtitle => '목록을 찾을 수 없습니다. 삭제되었을 수 있습니다.';

  @override
  String get peopleListsListDeletedSubtitle => '이 목록은 삭제되었을 수 있습니다.';

  @override
  String get peopleListsNoPeopleTitle => '이 목록에 사람이 없습니다';

  @override
  String get peopleListsNoPeopleSubtitle => '시작하려면 사람을 추가하세요';

  @override
  String get peopleListsNoVideosTitle => '아직 동영상 없음';

  @override
  String get peopleListsNoVideosSubtitle => '목록 구성원의 동영상이 여기에 표시됩니다';

  @override
  String get peopleListsNoVideosAvailable => '사용 가능한 동영상 없음';

  @override
  String get peopleListsFailedToLoadVideos => '동영상을 불러오지 못했습니다';

  @override
  String get peopleListsVideoNotAvailable => '동영상을 사용할 수 없습니다';

  @override
  String get peopleListsBackToGridTooltip => '그리드로 돌아가기';

  @override
  String get peopleListsErrorLoadingVideos => '동영상 불러오기 오류';

  @override
  String get peopleListsNoPeopleToAdd => '추가할 수 있는 사람이 없습니다.';

  @override
  String peopleListsAddToListName(String name) {
    return '$name에 추가';
  }

  @override
  String get peopleListsAddPeopleSearchHint => '사람 검색';

  @override
  String get peopleListsAddPeopleError => '사람을 불러올 수 없습니다. 다시 시도해 주세요.';

  @override
  String get peopleListsAddPeopleRetry => '다시 시도';

  @override
  String get peopleListsAddButton => '추가';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count명 추가';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 목록에 포함',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$name을(를) 삭제하시겠습니까?';
  }

  @override
  String get peopleListsRemoveConfirmBody => '이 목록에서 삭제됩니다.';

  @override
  String get peopleListsRemove => '삭제';

  @override
  String peopleListsRemovedFromList(String name) {
    return '목록에서 $name 삭제됨';
  }

  @override
  String get peopleListsUndo => '실행 취소';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return '$name의 프로필. 길게 눌러 삭제하세요.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return '$name의 프로필 보기';
  }

  @override
  String get shareMenuEditVideo => '영상 편집';

  @override
  String get shareMenuDeleteVideo => '영상 삭제';

  @override
  String shareMenuVideoCount(int count) {
    return '영상 $count개';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      '이 영상은 Divine에서 영구적으로 삭제됩니다. 다른 릴레이를 사용하는 타사 Nostr 클라이언트에는 계속 표시될 수 있어요.';

  @override
  String get shareMenuCancel => '취소';

  @override
  String get shareMenuDelete => '삭제';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      '삭제 준비가 아직 안 됐어요. 잠시 뒤에 다시 시도해요.';

  @override
  String get shareMenuDeleteFailedNotOwner => '내가 올린 영상만 삭제할 수 있어요.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated => '다시 로그인한 뒤 삭제를 시도해요.';

  @override
  String get shareMenuDeleteFailedCouldNotSign => '삭제 요청에 서명하지 못했어요. 다시 시도해요.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      '릴레이가 이 삭제 요청을 받아들이지 않았어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      '릴레이에 연결하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      '삭제했어요. 모든 릴레이가 확인한 건 아니라서 다른 앱에는 아직 보일 수 있어요.';

  @override
  String get shareMenuDeleteFailedGeneric => '이 영상을 삭제하지 못했어요. 다시 시도해요.';

  @override
  String get shareMenuUpdate => '업데이트';

  @override
  String get shareMenuChangeCover => '커버 변경';

  @override
  String get shareMenuVideoUpdated => '영상을 업데이트했어요';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '공동 작업자 초대 $count개가 전송되지 않았습니다.',
      one: '공동 작업자 초대 1개가 전송되지 않았습니다.',
    );
    return '동영상이 업데이트되었지만 $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated => '다시 로그인한 다음 시도해보세요.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      '이 영상에는 재생 가능한 소스가 없어서 수정할 수 없어요.';

  @override
  String get videoUpdateErrorCouldNotSign => '업데이트에 서명하지 못했어요. 다시 시도해보세요.';

  @override
  String get videoUpdateErrorPublishRejected =>
      '릴레이가 업데이트를 받지 않았어요. 잠시 후 다시 시도해보세요.';

  @override
  String get videoUpdateErrorGeneric => '이 영상을 업데이트하지 못했어요. 다시 시도해보세요.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => '영상을 삭제할까요?';

  @override
  String get shareMenuDeleteCleanupInProgress => '영상을 삭제하는 중…';

  @override
  String get shareMenuDeleteCleanupConfirmed => '영상을 삭제했어요.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      '영상을 삭제했어요. 모든 곳에서 사라질 때까지 시간이 조금 걸릴 수 있어요.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      '영상은 삭제했지만 모든 사본을 지우지는 못했어요. 지원팀에 문의해 주세요.';

  @override
  String get authSessionExpired => '세션이 만료됐어요. 다시 로그인해주세요.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => '로그인에 실패했어요. 다시 시도해주세요.';

  @override
  String get webAuthNotSupportedSecureMode =>
      '보안 모드에서는 웹 인증을 지원하지 않아요. 안전한 키 관리를 위해 모바일 앱을 이용해주세요.';

  @override
  String get webAuthEnterBunkerUri => 'Bunker URI를 입력해주세요';

  @override
  String get webAuthConnectTitle => 'Divine에 연결';

  @override
  String get webAuthChooseMethod => '원하는 Nostr 인증 방법을 고르세요';

  @override
  String get webAuthBrowserExtension => '브라우저 확장';

  @override
  String get webAuthRecommended => '추천';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => '원격 서명자에 연결';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => '클립보드에서 붙여넣기';

  @override
  String get webAuthConnectToBunker => 'Bunker에 연결';

  @override
  String get webAuthNewToNostr => 'Nostr가 처음이세요?';

  @override
  String get webAuthNostrHelp =>
      '가장 쉽게 쓰는 방법은 Alby나 nos2x 같은 브라우저 확장을 설치하거나, 안전한 원격 서명을 위해 nsec bunker를 쓰는 거예요.';

  @override
  String get soundsTitle => '사운드';

  @override
  String get soundsSearchHint => '사운드 검색...';

  @override
  String get soundsSearchResults => '검색 결과';

  @override
  String get soundsNoSoundsFound => '사운드를 찾을 수 없어요';

  @override
  String get soundsNoSoundsFoundDescription => '다른 검색어로 시도해 보세요';

  @override
  String get soundsSavedToLibrary => '사운드에 저장됨';

  @override
  String get soundsAlreadySavedToLibrary => '이미 사운드에 있음';

  @override
  String get soundsSavedLibraryTitle => '내 사운드';

  @override
  String get soundsSavedEmptyTitle => '저장된 사운드가 아직 없음';

  @override
  String get soundsSavedEmptyDescription => '동영상에서 사운드 사용을 탭하여 여기에 저장하세요.';

  @override
  String get soundsRemoveSavedSound => '사운드 제거';

  @override
  String get savedSoundSaveAction => '저장';

  @override
  String get savedSoundPausePreviewAction => '미리듣기 일시정지';

  @override
  String get savedSoundResumePreviewAction => '미리듣기 재개';

  @override
  String get savedSoundDetailsSheetTitle => '사운드 정보';

  @override
  String get savedSoundRemoveConfirmTitle => '이 사운드를 삭제할까요?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      '라이브러리에서 사라지지만, 이 사운드를 쓴 영상에서 언제든 다시 저장할 수 있어요.';

  @override
  String get soundsRemovedFromLibrary => '사운드에서 제거됨';

  @override
  String get soundsSaveFailed => '해당 사운드를 저장하지 못했어요. 다시 시도해 주세요.';

  @override
  String get soundsRemoveFailed => '해당 사운드를 삭제하지 못했어요. 다시 시도해 주세요.';

  @override
  String get soundSyncStatusSyncing => '사운드를 동기화하는 중…';

  @override
  String get soundSyncStatusSynced => '사운드가 최신 상태입니다';

  @override
  String get soundSyncStatusFailed => '사운드를 동기화하지 못했어요. 다시 시도할게요.';

  @override
  String get soundSyncStatusLocked => '이 기기에서는 동기화된 라이브러리를 열 수 없어요.';

  @override
  String get profileTitle => '프로필';

  @override
  String get profileMoreOptions => '더 보기';

  @override
  String profileBlockedUser(String name) {
    return '$name님을 차단했어요';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name님 차단을 해제했어요';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name님 팔로우를 해제했어요';
  }

  @override
  String get profileFeedError => '서버에 연결할 수 없습니다. 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get profileFeedLoadMoreError => '영상을 더 불러오지 못했어요. 당겨서 새로고침하세요.';

  @override
  String get notificationsTabAll => '전체';

  @override
  String get notificationsTabLikes => '좋아요';

  @override
  String get notificationsTabComments => '댓글';

  @override
  String get notificationsTabFollows => '팔로우';

  @override
  String get notificationsTabReposts => '리포스트';

  @override
  String get notificationsFailedToLoad => '알림을 불러오지 못했어요';

  @override
  String get notificationsRetry => '다시 시도';

  @override
  String get notificationsRefreshError => '새로고침 실패 — 보유 중인 알림을 표시합니다';

  @override
  String get notificationsUnreadPrefix => '읽지 않은 알림';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '읽지 않은 알림 $count개',
      one: '읽지 않은 알림 1개',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return '$displayName님의 프로필 보기';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => '프로필 보기';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return '$title 동영상 썸네일';
  }

  @override
  String get notificationsVideoThumbnail => '동영상 썸네일';

  @override
  String get notificationsInviteSingular => '친구와 공유할 수 있는 초대장이 1개 있어요!';

  @override
  String notificationsInvitePlural(int count) {
    return '친구들과 공유할 수 있는 초대장이 $count개 있어요!';
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
  String get notificationsVideoUnavailable => '영상을 사용할 수 없어요';

  @override
  String get feedFailedToLoadVideos => '영상을 불러오지 못했어요';

  @override
  String get feedRetry => '다시 시도';

  @override
  String get feedNoFollowedUsers => '팔로우한 사용자가 없어요.\n누군가를 팔로우하면 여기에 영상이 표시돼요.';

  @override
  String get feedModeForYou => '추천';

  @override
  String get feedModeNew => '최신';

  @override
  String get feedModeFollowing => '팔로잉';

  @override
  String get feedModeClassics => '클래식';

  @override
  String feedModeSemanticLabel(String label) {
    return '피드 모드: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return '동영상 작성자: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => '작성자 프로필 사진';

  @override
  String get feedForYouEmpty =>
      '추천 피드가 비어 있어요.\n동영상을 탐색하고 크리에이터를 팔로우해 피드를 만들어보세요.';

  @override
  String get feedFollowingEmpty =>
      '아직 팔로우한 사람들의 동영상이 없어요.\n마음에 드는 크리에이터를 찾아 팔로우해 보세요.';

  @override
  String get feedLatestEmpty => '아직 새로운 동영상이 없어요.\n잠시 후 다시 확인해 주세요.';

  @override
  String get feedClassicEmpty => '아직 클래식 동영상이 없어요.\n잠시 후 다시 확인해 주세요.';

  @override
  String get feedExploreVideos => '영상 둘러보기';

  @override
  String get feedLoadingMore => '영상을 더 불러오는 중…';

  @override
  String get feedRefreshed => '피드를 새로고침했어요';

  @override
  String get uploadUploadingVideo => '영상 업로드 중';

  @override
  String get postPublishConfirmationTitle => '프로필에 게시했어요';

  @override
  String get postPublishConfirmationView => '보기';

  @override
  String get postPublishConfirmationShare => '공유';

  @override
  String get postPublishConfirmationThumbnailLabel => '방금 게시한 영상의 썸네일';

  @override
  String get userSearchNoResults => '사용자를 찾을 수 없어요';

  @override
  String get userPickerFilterByNameHint => '이름으로 필터링...';

  @override
  String get userPickerSearchByNameHint => '이름으로 검색...';

  @override
  String get userPickerClearSearchSemantics => '검색 지우기';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name 이미 추가됨';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name 선택';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return '$name 제거';
  }

  @override
  String get userPickerEmptyFollowListTitle => '네 크루는 밖에 있어';

  @override
  String get userPickerEmptyFollowListBody =>
      '잘 맞는 사람들을 팔로우해 보세요. 서로 팔로우하면 함께 협업할 수 있어요.';

  @override
  String get userPickerGoBack => '뒤로 가기';

  @override
  String get userPickerTypeNameToSearch => '검색할 이름을 입력하세요';

  @override
  String get userPickerUnavailable => '사용자 검색을 사용할 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String get userPickerSearchFailedTryAgain => '검색에 실패했어요. 다시 시도해 주세요.';

  @override
  String get forgotPasswordTitle => '비밀번호 재설정';

  @override
  String get forgotPasswordDescription => '이메일 주소를 입력하면 비밀번호 재설정 링크를 보내드려요.';

  @override
  String get forgotPasswordEmailLabel => '이메일 주소';

  @override
  String get forgotPasswordCancel => '취소';

  @override
  String get forgotPasswordSendLink => '재설정 링크 이메일 보내기';

  @override
  String get ageVerificationContentWarning => '콘텐츠 경고';

  @override
  String get ageVerificationTitle => '연령 확인';

  @override
  String get ageVerificationAdultDescription =>
      '이 콘텐츠는 성인용 자료를 포함할 가능성이 있어 플래그가 지정됐어요. 시청하려면 만 18세 이상이어야 해요.';

  @override
  String get ageVerificationCreationDescription =>
      '카메라를 사용하고 콘텐츠를 만들려면 만 16세 이상이어야 해요.';

  @override
  String get ageVerificationAdultQuestion => '만 18세 이상이신가요?';

  @override
  String get ageVerificationCreationQuestion => '만 16세 이상이신가요?';

  @override
  String get ageVerificationNo => '아니요';

  @override
  String get ageVerificationYes => '네';

  @override
  String get navHome => '홈';

  @override
  String get navExplore => '둘러보기';

  @override
  String get navInbox => '받은편지함';

  @override
  String get navProfile => '프로필';

  @override
  String get navMyProfile => '내 프로필';

  @override
  String get navNotifications => '알림';

  @override
  String get navOpenCamera => '카메라 열기';

  @override
  String get navExploreClassics => '클래식';

  @override
  String get navExploreNewVideos => '새 영상';

  @override
  String get navExploreTrending => '인기';

  @override
  String get navExploreForYou => '추천';

  @override
  String get navExploreLists => '목록';

  @override
  String get routeErrorTitle => '오류';

  @override
  String get routeInvalidHashtag => '잘못된 해시태그예요';

  @override
  String get routeInvalidConversationId => '잘못된 대화 ID예요';

  @override
  String get routeInvalidRequestId => '잘못된 요청 ID예요';

  @override
  String get routeInvalidListId => '잘못된 목록 ID예요';

  @override
  String get routeInvalidUserId => '잘못된 사용자 ID예요';

  @override
  String get routeInvalidVideoId => '잘못된 영상 ID예요';

  @override
  String get routeInvalidSoundId => '잘못된 사운드 ID예요';

  @override
  String get routeInvalidCategory => '잘못된 카테고리예요';

  @override
  String get routeNoVideosToDisplay => '표시할 영상이 없어요';

  @override
  String get routeGoHome => '홈으로 가기';

  @override
  String get routeInvalidProfileId => '잘못된 프로필 ID예요';

  @override
  String get routeUnknownPath => '앱에 없는 화면이에요.';

  @override
  String get routeDefaultListName => '목록';

  @override
  String get supportTitle => '지원 센터';

  @override
  String get supportContactSupport => '지원팀 문의';

  @override
  String get supportContactSupportSubtitle => '대화를 시작하거나 이전 메시지를 확인해요';

  @override
  String get supportReportBug => '버그 신고';

  @override
  String get supportReportBugSubtitle => '앱의 기술적 문제';

  @override
  String get supportRequestFeature => '기능 요청';

  @override
  String get supportRequestFeatureSubtitle => '개선이나 새로운 기능을 제안해요';

  @override
  String get supportSaveLogs => '로그 저장';

  @override
  String get supportSaveLogsSubtitle => '수동 전송을 위해 로그를 파일로 내보내요';

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
  String get supportFaq => '자주 묻는 질문';

  @override
  String get supportFaqSubtitle => '일반적인 질문과 답변';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle => '부모와 청소년이 건강한 온라인 습관을 기르도록 돕기';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => '연령에 따라 계정을 다루는 방식';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => '검증과 진위 확인에 대해 알아보세요';

  @override
  String get supportLoginRequired => '지원팀에 문의하려면 로그인해 주세요';

  @override
  String get supportExportingLogs => '로그 내보내는 중...';

  @override
  String get supportExportLogsFailed => '로그 내보내기에 실패했어요';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return '$path에 로그 저장됨';
  }

  @override
  String get supportRevealLogsAction => '폴더에서 보기';

  @override
  String get supportChatNotAvailable => '지원 채팅을 사용할 수 없어요';

  @override
  String get supportCouldNotOpenMessages => '지원 메시지를 열 수 없어요';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName을(를) 열 수 없어요';
  }

  @override
  String get reportWhyReporting => '이 콘텐츠를 왜 신고하시나요?';

  @override
  String get reportPolicyNotice =>
      'Divine은 24시간 이내에 신고된 콘텐츠를 조치하여 콘텐츠를 삭제하고 문제가 된 콘텐츠를 제공한 사용자를 퇴출해요.';

  @override
  String get reportBlockUser => '이 사용자 차단';

  @override
  String get reportCancel => '취소';

  @override
  String get reportSubmit => '신고';

  @override
  String get reportSelectReason => '이 콘텐츠를 신고하는 이유를 선택해 주세요';

  @override
  String get reportOtherRequiresDetails => '‘기타’를 선택했다면 문제를 설명해 주세요';

  @override
  String get reportDetailsRequired => '문제를 설명해 주세요';

  @override
  String get reportDetailsTextOnly =>
      '텍스트만 입력할 수 있습니다. 여기에는 사진이나 GIF를 첨부할 수 없습니다.';

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
  String get reportReasonSpam => '스팸 또는 원치 않는 콘텐츠';

  @override
  String get reportReasonSpamSubtitle => '원치 않거나 반복되는 콘텐츠';

  @override
  String get reportReasonHarassment => '괴롭힘, 따돌림, 협박';

  @override
  String get reportReasonHarassmentSubtitle => '유해하고 원치 않는 답글 또는 멘션';

  @override
  String get reportReasonViolence => '폭력적이거나 극단적인 콘텐츠';

  @override
  String get reportReasonViolenceSubtitle => '폭력적, 극단적 또는 유해한 콘텐츠';

  @override
  String get reportReasonSexualContent => '성적이거나 성인용 콘텐츠';

  @override
  String get reportReasonSexualContentSubtitle => '노출, 포르노 또는 노골적인 콘텐츠';

  @override
  String get reportReasonCopyright => '저작권 침해';

  @override
  String get reportReasonCopyrightSubtitle => '지적 재산권의 무단 사용';

  @override
  String get reportReasonFalseInfo => '허위 정보';

  @override
  String get reportReasonFalseInfoSubtitle => '오해의 소지가 있거나 허위 주장';

  @override
  String get reportReasonChildSafety => '아동 안전 위반';

  @override
  String get reportReasonChildSafetySubtitle => '미성년자 안전에 대한 전반적인 우려';

  @override
  String get reportReasonCsam => '아동 성적 학대';

  @override
  String get reportReasonCsamSubtitle => '미성년자에 대한 성적 학대를 묘사한 콘텐츠';

  @override
  String get reportReasonUnderageUser => '사용자가 16세 미만으로 보임';

  @override
  String get reportReasonUnderageUserSubtitle => '계정 소유자가 미성년자로 보여요';

  @override
  String get reportReasonAiGenerated => 'AI 생성 콘텐츠';

  @override
  String get reportReasonAiGeneratedSubtitle => 'AI 생성으로 의심되는 콘텐츠';

  @override
  String get reportReasonOther => '기타 정책 위반';

  @override
  String get reportReasonOtherSubtitle => '위에 나열되지 않은 위반';

  @override
  String get reportFailed => '콘텐츠 신고에 실패했어요. 다시 시도해보세요.';

  @override
  String get reportNotSent => '신고를 보내지 못했어요. 연결 상태를 확인하고 다시 시도해보세요.';

  @override
  String get reportReceivedTitle => '신고 접수 완료';

  @override
  String get reportReceivedThankYou => 'Divine을 안전하게 지키는 데 도움을 주셔서 감사해요.';

  @override
  String get reportReceivedReviewNotice =>
      '저희 팀이 신고를 검토하고 적절한 조치를 취할 거예요. 다이렉트 메시지로 업데이트를 받을 수 있어요.';

  @override
  String get reportModerationDmDelayed =>
      '지금은 조절 팀에 바로 연결하지 못했지만, 신고는 접수됐고 검토될 거예요.';

  @override
  String get reportContactModeration => '조절 팀에 메시지 보내기';

  @override
  String get reportLearnMoreAt => '자세한 내용은';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => '닫기';

  @override
  String get listAddToList => '목록에 추가';

  @override
  String listVideoCount(int count) {
    return '영상 $count개';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
      one: '1명',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => '작성자: ';

  @override
  String get listNewList => '새 목록';

  @override
  String get listDone => '완료';

  @override
  String get listErrorLoading => '목록을 불러오는 중 오류 발생';

  @override
  String listRemovedFrom(String name) {
    return '$name에서 삭제했어요';
  }

  @override
  String listAddedTo(String name) {
    return '$name에 추가했어요';
  }

  @override
  String get listCreateNewList => '새 목록 만들기';

  @override
  String get listNewPeopleList => '새 사람 목록';

  @override
  String get listCollaboratorsNone => '없음';

  @override
  String get listAddCollaboratorTitle => '협업자 추가';

  @override
  String get listCollaboratorSearchHint => 'Divine 검색...';

  @override
  String get listNameLabel => '목록 이름';

  @override
  String get listDescriptionLabel => '설명 (선택)';

  @override
  String get listPublicList => '공개 목록';

  @override
  String get listPublicListSubtitle => '다른 사람들이 이 목록을 팔로우하고 볼 수 있어요';

  @override
  String get listPrivateListSubtitle =>
      '동영상은 비공개로 유지돼요. 이름, 설명, 태그, 커버는 계속 보여요.';

  @override
  String get listVisibilityPublic => '공개';

  @override
  String get listVisibilityPrivate => '비공개';

  @override
  String get profileListsEmpty => '아직 목록이 없어요. 함께 모아 두고 싶은 루프로 하나 만들어 보세요.';

  @override
  String get listEditTitle => '목록 편집';

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
  String get listShareAction => '목록 공유';

  @override
  String get listShareFailed => '이 목록을 공유하지 못했어요. 다시 시도해 주세요.';

  @override
  String get listSave => '저장';

  @override
  String get listContinue => '계속';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => '이 목록을 업데이트하지 못했어요. 다시 시도해 주세요.';

  @override
  String get listMakePrivateTitle => '이 목록을 비공개로 바꿀까요?';

  @override
  String get listMakePrivateWarning =>
      '동영상이 암호화돼서 나만 볼 수 있어요. 이름, 설명, 태그, 커버는 계속 보이고, 이미 공유한 사본은 남아 있을 수 있어요.';

  @override
  String get listMakePublicTitle => '이 목록을 공개로 바꿀까요?';

  @override
  String get listMakePublicWarning => '링크가 있는 사람은 누구나 이 목록과 동영상을 볼 수 있어요.';

  @override
  String listShareText(String name, String url) {
    return 'Divine에서 $name 확인해 보세요: $url';
  }

  @override
  String listShareSubject(String name) {
    return 'Divine의 $name';
  }

  @override
  String get listCancel => '취소';

  @override
  String get listCreate => '만들기';

  @override
  String get listCreateFailed => '목록 만들기에 실패했어요';

  @override
  String get keyManagementTitle => 'Nostr 키';

  @override
  String get keyManagementWhatAreKeys => 'Nostr 키란 무엇인가요?';

  @override
  String get keyManagementExplanation =>
      'Nostr 신원은 암호학적 키 쌍이에요:\n\n• 공개 키(npub)는 사용자 이름 같아요 - 자유롭게 공유하세요\n• 개인 키(nsec)는 비밀번호 같아요 - 비밀로 유지하세요!\n\nnsec으로 어떤 Nostr 앱에서든 계정에 접근할 수 있어요.';

  @override
  String get keyManagementImportTitle => '기존 키 가져오기';

  @override
  String get keyManagementImportSubtitle =>
      '이미 Nostr 계정이 있으신가요? 여기에서 접근하려면 개인 키(nsec)를 붙여넣으세요.';

  @override
  String get keyManagementImportButton => '키 가져오기';

  @override
  String get keyManagementImportWarning => '현재 키가 대체돼요!';

  @override
  String get keyManagementBackupTitle => '키 백업';

  @override
  String get keyManagementBackupSubtitle =>
      '다른 Nostr 앱에서 계정을 사용하려면 개인 키(nsec)를 저장해요.';

  @override
  String get keyManagementCopyNsec => '내 개인 키(nsec) 복사';

  @override
  String get keyManagementNeverShare => 'nsec을 절대 다른 사람과 공유하지 마세요!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      '키는 이 기기가 아니라 Divine 로그인 서비스에 보관되어 있습니다. 비밀번호를 확인하면 가져올 수 있습니다.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      '키는 Divine 로그인 서비스가 보관합니다. 계정 비밀번호를 입력하면 가져옵니다.';

  @override
  String get keyManagementKeycastCopyKey => '키 복사';

  @override
  String get keyManagementKeycastCopyBlocked =>
      '기기가 복사를 차단해서 키가 클립보드에 저장되지 않았어요.';

  @override
  String get keyManagementKeycastWrongPassword => '비밀번호가 일치하지 않습니다. 다시 시도하세요.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      '시도가 너무 많아요. 이 창을 닫고 다시 시작해 주세요.';

  @override
  String get keyManagementKeycastRateLimited =>
      '키 요청이 너무 많아요. 몇 분 기다렸다가 다시 시도해 주세요.';

  @override
  String get keyManagementKeycastSignInAgain =>
      '세션이 만료되었습니다. 키를 복사하려면 다시 로그인하세요.';

  @override
  String get keyManagementKeycastEmailUnverified => '키를 복사하기 전에 이메일 주소를 인증하세요.';

  @override
  String get keyManagementKeycastDenied =>
      '이 계정의 키는 Divine이 관리하므로 여기에서 복사할 수 없습니다.';

  @override
  String get keyManagementKeycastNoKey => '이 계정에 등록된 키가 없어요.';

  @override
  String get keyManagementKeycastGenericFailure =>
      '로그인 서비스에 연결할 수 없었어요. 다시 시도해보세요.';

  @override
  String get keyManagementRestrictedTitle => '키는 Divine이 관리합니다';

  @override
  String get keyManagementRestrictedBody =>
      '계정을 안전하게 지키기 위해 키 백업과 다른 키 가져오기는 여기서 제공하지 않아요.';

  @override
  String get keyManagementPasteKey => '개인 키를 붙여넣어 주세요';

  @override
  String get keyManagementInvalidFormat => '잘못된 키 형식이에요. \"nsec1\"로 시작해야 해요';

  @override
  String get keyManagementConfirmImportTitle => '이 키를 가져올까요?';

  @override
  String get keyManagementConfirmImportBody =>
      '현재 신원이 가져온 신원으로 대체돼요.\n\n먼저 백업하지 않으면 현재 키를 잃을 수 있어요.';

  @override
  String get keyManagementImportConfirm => '가져오기';

  @override
  String get keyManagementImportSuccess => '키를 성공적으로 가져왔어요!';

  @override
  String get keyManagementImportFailed => '키 가져오기에 실패했어요. 다시 시도해보세요.';

  @override
  String get keyManagementExportSuccess =>
      '개인 키를 클립보드에 복사했어요!\n\n안전한 곳에 보관하세요.';

  @override
  String get keyManagementExportFailed => '키 내보내기에 실패했어요. 다시 시도해보세요.';

  @override
  String get keyManagementYourPublicKeyLabel => '공개 키 (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => '공개 키 복사';

  @override
  String get keyManagementPublicKeyCopied => '공개 키를 복사했어요';

  @override
  String get saveOriginalSavedToCameraRoll => '카메라 롤에 저장했어요';

  @override
  String get saveOriginalShare => '공유';

  @override
  String get saveOriginalDone => '완료';

  @override
  String get saveOriginalPhotosAccessNeeded => '사진 접근 권한이 필요해요';

  @override
  String get saveOriginalPhotosAccessMessage =>
      '영상을 저장하려면 설정에서 사진 접근을 허용해 주세요.';

  @override
  String get saveOriginalOpenSettings => '설정 열기';

  @override
  String get saveOriginalNotNow => '나중에';

  @override
  String get saveOriginalDownloadFailed => '다운로드 실패';

  @override
  String get saveOriginalDismiss => '닫기';

  @override
  String get saveOriginalDownloadingVideo => '영상 다운로드 중';

  @override
  String get saveOriginalSavingToCameraRoll => '카메라 롤에 저장 중';

  @override
  String get saveOriginalFetchingVideo => '네트워크에서 영상을 가져오는 중...';

  @override
  String get saveOriginalSavingVideo => '원본 영상을 카메라 롤에 저장하는 중...';

  @override
  String get soundTitle => '사운드';

  @override
  String get soundOriginalSound => '원본 사운드';

  @override
  String get soundVideosUsingThisSound => '이 사운드를 사용하는 영상';

  @override
  String get soundSourceVideo => '원본 영상';

  @override
  String get soundNoVideosYet => '아직 영상이 없어요';

  @override
  String get soundBeFirstToUse => '이 사운드를 처음으로 사용해 보세요!';

  @override
  String get soundFailedToLoadVideos => '영상을 불러오지 못했어요';

  @override
  String get soundRetry => '다시 시도';

  @override
  String get soundVideosUnavailable => '영상을 사용할 수 없어요';

  @override
  String get soundCouldNotLoadDetails => '영상 세부 정보를 불러올 수 없어요';

  @override
  String get soundPreview => '미리 듣기';

  @override
  String get soundStop => '정지';

  @override
  String get soundUseSound => '사운드 사용';

  @override
  String get soundUntitled => '제목 없는 사운드';

  @override
  String get soundStopPreview => '미리 듣기 중지';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '$title 미리 듣기';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return '$title 세부 정보 보기';
  }

  @override
  String get soundNoVideoCount => '아직 영상이 없어요';

  @override
  String get soundOneVideo => '영상 1개';

  @override
  String soundVideoCount(int count) {
    return '영상 $count개';
  }

  @override
  String get soundUnableToPreview => '사운드를 미리 들을 수 없어요 - 오디오가 없어요';

  @override
  String get soundPreviewFailed => '미리 듣기를 재생하지 못했어요. 다시 시도해보세요.';

  @override
  String get soundViewSource => '원본 보기';

  @override
  String get soundCloseTooltip => '닫기';

  @override
  String get exploreNotExploreRoute => '둘러보기 경로가 아니에요';

  @override
  String get legalTitle => '법적 고지';

  @override
  String get legalTermsOfService => '서비스 약관';

  @override
  String get legalTermsOfServiceSubtitle => '사용 약관과 조건';

  @override
  String get legalPrivacyPolicy => '개인정보 처리방침';

  @override
  String get legalPrivacyPolicySubtitle => '데이터 처리 방식';

  @override
  String get legalSafetyStandards => '안전 기준';

  @override
  String get legalSafetyStandardsSubtitle => '커뮤니티 가이드라인과 안전';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => '저작권 및 삭제 정책';

  @override
  String get legalOpenSourceLicenses => '오픈 소스 라이선스';

  @override
  String get legalOpenSourceLicensesSubtitle => '서드파티 패키지 저작자 표시';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName을(를) 열 수 없어요';
  }

  @override
  String get categoryAction => '액션';

  @override
  String get categoryAdventure => '모험';

  @override
  String get categoryAnimals => '동물';

  @override
  String get categoryAnimation => '애니메이션';

  @override
  String get categoryArchitecture => '건축';

  @override
  String get categoryArt => '예술';

  @override
  String get categoryAutomotive => '자동차';

  @override
  String get categoryAwardShow => '시상식';

  @override
  String get categoryAwards => '수상';

  @override
  String get categoryBaseball => '야구';

  @override
  String get categoryBasketball => '농구';

  @override
  String get categoryBeauty => '뷰티';

  @override
  String get categoryBeverage => '음료';

  @override
  String get categoryCars => '자동차';

  @override
  String get categoryCelebration => '축하';

  @override
  String get categoryCelebrities => '연예인';

  @override
  String get categoryCelebrity => '셀럽';

  @override
  String get categoryCityscape => '도시 풍경';

  @override
  String get categoryComedy => '코미디';

  @override
  String get categoryConcert => '콘서트';

  @override
  String get categoryCooking => '요리';

  @override
  String get categoryCostume => '코스튬';

  @override
  String get categoryCrafts => '공예';

  @override
  String get categoryCrime => '범죄';

  @override
  String get categoryCulture => '문화';

  @override
  String get categoryDance => '댄스';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => '드라마';

  @override
  String get categoryEducation => '교육';

  @override
  String get categoryEmotional => '감동';

  @override
  String get categoryEmotions => '감정';

  @override
  String get categoryEntertainment => '엔터테인먼트';

  @override
  String get categoryEvent => '이벤트';

  @override
  String get categoryFamily => '가족';

  @override
  String get categoryFans => '팬';

  @override
  String get categoryFantasy => '판타지';

  @override
  String get categoryFashion => '패션';

  @override
  String get categoryFestival => '축제';

  @override
  String get categoryFilm => '영화';

  @override
  String get categoryFitness => '피트니스';

  @override
  String get categoryFood => '음식';

  @override
  String get categoryFootball => '미식축구';

  @override
  String get categoryFurniture => '가구';

  @override
  String get categoryGaming => '게임';

  @override
  String get categoryGolf => '골프';

  @override
  String get categoryGrooming => '그루밍';

  @override
  String get categoryGuitar => '기타';

  @override
  String get categoryHalloween => '할로윈';

  @override
  String get categoryHealth => '건강';

  @override
  String get categoryHockey => '하키';

  @override
  String get categoryHoliday => '휴일';

  @override
  String get categoryHome => '홈';

  @override
  String get categoryHomeImprovement => '홈 리모델링';

  @override
  String get categoryHorror => '호러';

  @override
  String get categoryHospital => '병원';

  @override
  String get categoryHumor => '유머';

  @override
  String get categoryInteriorDesign => '인테리어';

  @override
  String get categoryInterview => '인터뷰';

  @override
  String get categoryKids => '키즈';

  @override
  String get categoryLifestyle => '라이프스타일';

  @override
  String get categoryMagic => '마술';

  @override
  String get categoryMakeup => '메이크업';

  @override
  String get categoryMedical => '의료';

  @override
  String get categoryMusic => '음악';

  @override
  String get categoryMystery => '미스터리';

  @override
  String get categoryNature => '자연';

  @override
  String get categoryNews => '뉴스';

  @override
  String get categoryOutdoor => '아웃도어';

  @override
  String get categoryParty => '파티';

  @override
  String get categoryPeople => '사람';

  @override
  String get categoryPerformance => '공연';

  @override
  String get categoryPets => '반려동물';

  @override
  String get categoryPolitics => '정치';

  @override
  String get categoryPrank => '장난';

  @override
  String get categoryPranks => '몰카';

  @override
  String get categoryRealityShow => '리얼리티 쇼';

  @override
  String get categoryRelationship => '관계';

  @override
  String get categoryRelationships => '인간관계';

  @override
  String get categoryRomance => '로맨스';

  @override
  String get categorySchool => '학교';

  @override
  String get categoryScienceFiction => 'SF';

  @override
  String get categorySelfie => '셀카';

  @override
  String get categoryShopping => '쇼핑';

  @override
  String get categorySkateboarding => '스케이트보드';

  @override
  String get categorySkincare => '스킨케어';

  @override
  String get categorySoccer => '축구';

  @override
  String get categorySocialGathering => '모임';

  @override
  String get categorySocialMedia => '소셜 미디어';

  @override
  String get categorySports => '스포츠';

  @override
  String get categoryTalkShow => '토크쇼';

  @override
  String get categoryTech => '테크';

  @override
  String get categoryTechnology => '기술';

  @override
  String get categoryTelevision => 'TV';

  @override
  String get categoryToys => '장난감';

  @override
  String get categoryTransportation => '교통';

  @override
  String get categoryTravel => '여행';

  @override
  String get categoryUrban => '도시';

  @override
  String get categoryViolence => '폭력';

  @override
  String get categoryVlog => '브이로그';

  @override
  String get categoryVlogging => '브이로깅';

  @override
  String get categoryWrestling => '레슬링';

  @override
  String get profileSetupUploadStaged => '업로드됐어요 — 적용하려면 저장을 탭하세요';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName을(를) 신고했어요';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName을(를) 차단했어요';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName의 차단을 해제했어요';
  }

  @override
  String get inboxRemovedConversation => '대화를 삭제했어요';

  @override
  String get inboxRestorePausedTitle => '일부 대화를 아직 다 복구하지 못했어요';

  @override
  String get conversationRestorePausedTitle => '이 대화를 아직 다 복구하지 못했어요';

  @override
  String get inboxRestoreRetryAction => '다시 시도';

  @override
  String get inboxRestoringMessages => '메시지를 복구하는 중…';

  @override
  String get inboxEmptyTitle => '아직 메시지가 없어요';

  @override
  String get inboxEmptySubtitle => '+ 버튼, 물지 않아요.';

  @override
  String get inboxLoadErrorTitle => '메시지를 불러오지 못했어요';

  @override
  String get inboxLoadErrorSubtitle => '연결을 확인하고 다시 시도해 주세요.';

  @override
  String get inboxFilterAll => '전체';

  @override
  String get inboxFilterUnread => '안 읽음';

  @override
  String get dmBlockedThreadTitle => '이 계정을 차단했습니다';

  @override
  String get dmBlockedThreadBody =>
      '메시지는 여기에 남아 있어 읽거나 스크린샷을 찍을 수 있습니다. 답장하려면 차단을 해제하세요.';

  @override
  String get inboxFilterBlocked => '차단됨';

  @override
  String get inboxBlockedEmptyTitle => '차단된 대화가 없습니다';

  @override
  String get inboxBlockedEmptySubtitle => '차단한 계정이 여기에 표시됩니다.';

  @override
  String get inboxBlockedNoMessages => '메시지 없음';

  @override
  String get inboxUnreadEmptyTitle => '모두 확인했어요';

  @override
  String get inboxUnreadEmptySubtitle => '읽지 않은 메시지가 없어요.';

  @override
  String get inboxSearchHint => '메시지 검색';

  @override
  String get inboxSupportRowTitle => 'Divine 검수';

  @override
  String get inboxSupportRowSubtitle => '버그, 모더레이션, 계정 문제 — 듣고 있어요.';

  @override
  String get inboxSearchEmptyTitle => '일치하는 항목 없음';

  @override
  String get inboxSearchEmptySubtitle => '다른 이름이나 단어로 시도해 보세요.';

  @override
  String get inboxActionMute => '대화 알림 끄기';

  @override
  String inboxActionReport(String displayName) {
    return '$displayName 신고';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayName 차단';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayName 차단 해제';
  }

  @override
  String get inboxActionRemove => '대화 삭제';

  @override
  String get inboxRemoveConfirmTitle => '대화를 삭제할까요?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return '$displayName와의 대화가 받은 편지함에서 삭제돼요. 상대방이 다시 메시지를 보내면 새 대화가 시작돼요.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      '이 그룹 대화가 받은 편지함에서 삭제돼요. 누군가 그룹에 다시 메시지를 보내면 새 대화가 시작돼요.';

  @override
  String get inboxRemoveConfirmConfirm => '삭제';

  @override
  String get inboxConversationMuted => '대화 알림을 껐어요';

  @override
  String get inboxConversationUnmuted => '대화 알림을 다시 켰어요';

  @override
  String get inboxCollabInviteCardTitle => '콜라보 초대';

  @override
  String get inboxCollabInviteCardUntitledVideo => '제목 없는 동영상';

  @override
  String get clickableTextViewVideoLink => '동영상 보기';

  @override
  String get messageExternalLinkDialogTitle => '외부 링크를 열까요?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return '이 링크는 외부 사이트로 이동하며 안전하지 않을 수 있어요:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => '열기';

  @override
  String get inboxCollabInviteCoPostButton => '공동 게시';

  @override
  String get inboxCollabInviteNotMineButton => '내 것이 아니에요';

  @override
  String get inboxCollabInvitePreviewTitle => '공동 게시 초대';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return '$displayName님의 공동 게시 초대';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      '공동 게시하면 이 동영상이 협업으로 내 타임라인에 추가됩니다.';

  @override
  String get inboxCollabInviteAcceptedStatus => '수락됨';

  @override
  String get inboxCollabInviteIgnoredStatus => '무시됨';

  @override
  String get inboxCollabInviteAcceptError => '수락하지 못했어요. 다시 시도해 주세요.';

  @override
  String get inboxCollabInviteSentStatus => '초대를 보냈어요';

  @override
  String get inboxConversationCollabInvitePreview => '콜라보 초대';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return '$title 콜라보에 초대받았어요: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return '동영상 콜라보에 초대받았어요: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '콜라보 초대 $count건이 전송되지 않았어요.',
      one: '콜라보 초대 1건이 전송되지 않았어요.',
    );
    return '영상을 올렸지만, $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      '이 대화의 상대를 알 수 없어요. 받은 편지함에서 다시 열어 주세요.';

  @override
  String get dmSendBlockedMessage => '공식 Divine 계정에만 메시지를 보낼 수 있어요';

  @override
  String get dmSendBlockedRetiredMessage =>
      '이 대화는 아무도 읽지 않습니다. 대신 Divine Moderation에 메시지를 보내세요.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => '모두에게서 삭제하지 못했어요.';

  @override
  String get dmDeleteRefusedDetails => '일부 사람에게는 이 메시지가 아직 보일 수 있어요.';

  @override
  String get dmRetiredThreadClosedTitle => '이 대화는 종료되었습니다.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      '이 Divine Moderation 알림은 삭제할 수 없습니다.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Divine Moderation을 새 계정으로 옮겼습니다. 이 계정은 더 이상 아무도 읽지 않습니다.';

  @override
  String get dmRetiredThreadOpenSupport => 'Divine Moderation에 메시지 보내기';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => '메시지를 보내지 못했어요';

  @override
  String get dmResendFailedMessage => '여전히 보내지 못했어요';

  @override
  String get dmSendFailedSubtitle => '지금 다시 보내거나 전송을 중단하세요.';

  @override
  String get dmSendFailedRetry => '다시 시도';

  @override
  String get dmSendPartialMessage => '보냈지만 다른 기기에 동기화되지 않았어요';

  @override
  String get dmConversationLoadError => '메시지를 불러오지 못했어요';

  @override
  String get dmMessageInputHint => '한마디 남겨보세요…';

  @override
  String get dmMessageBubbleSentHint => '보낸 메시지';

  @override
  String get dmMessageBubbleReceivedHint => '받은 메시지';

  @override
  String get dmMessageBubbleLongPressHint => '메시지 작업';

  @override
  String get dmMessageBubbleFailedTapHint => '이 메시지 다시 보내기 또는 삭제';

  @override
  String get dmMessageActionCopyText => '텍스트 복사';

  @override
  String get dmMessageActionCopyVideoUrl => '영상 URL 복사';

  @override
  String get dmMessageActionDeleteForEveryone => '모두에게서 삭제';

  @override
  String get dmMessageActionReport => '신고';

  @override
  String get dmMessageActionRetrySend => '다시 보내기';

  @override
  String get dmMessageActionCancelSend => '전송 중단';

  @override
  String get dmReactionAddCustomA11yLabel => '맞춤 이모지 반응 추가';

  @override
  String dmReelReplyComposerHint(String name) {
    return '$name님에게 메시지…';
  }

  @override
  String get dmReelReplyComposerHintSelf => '나에게 답장…';

  @override
  String get dmReelReplyComposerSemanticLabel => '이 릴스에 답장';

  @override
  String get dmReelReplyViewChat => '채팅 보기';

  @override
  String get dmReelReplySentAnnouncement => '답장을 보냈습니다';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return '$emoji 반응함';
  }

  @override
  String get dmReelReplyFailed => '보내지 못했습니다';

  @override
  String get dmReelReplyUnverified => '전송을 확인하지 못했습니다';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return '내 반응: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name님이 $emoji(으)로 반응했어요';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return '반응 보내는 중: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel => '반응 실패, 두 번 탭하면 다시 시도';

  @override
  String get dmReactionChipRetryAnnouncement => '반응 다시 시도 중';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval => '다른 반응을 추가하기 전에 이전 반응 삭제를 완료하세요.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => '반응';

  @override
  String get dmReactionsViewA11yLabel => '반응한 사람 보기';

  @override
  String get dmReactionRemoveAction => '삭제';

  @override
  String get dmReactionRetryAction => '다시 시도';

  @override
  String get dmFormatBold => '굵게';

  @override
  String get dmFormatItalic => '기울임꼴';

  @override
  String get dmFormatStrikethrough => '취소선';

  @override
  String get dmFormatCode => '코드';

  @override
  String get dmStatusFailed => '보내지 못했어요';

  @override
  String get inboxConversationActionsSheetLabel => '대화 작업';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayName님과의 대화';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return '안 읽음, $displayName님과의 대화';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$name 외 $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => '대화 작업 보기';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return '제목: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return '동영상 $current/$total';
  }

  @override
  String get exploreSearchHint => '검색...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '영상 $count개';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      '구독 업데이트에 실패했어요. 다시 시도해보세요.';

  @override
  String get discoverListsTitle => '리스트 둘러보기';

  @override
  String get discoverListsFailedToLoad => '리스트를 불러오지 못했어요';

  @override
  String get discoverListsLoading => '공개 리스트를 찾는 중...';

  @override
  String get discoverListsRelayTimeout => '릴레이가 제때 리스트를 주지 않았어요. 다시 시도해 주세요.';

  @override
  String get discoverListsServiceUnavailable => '서비스를 사용할 수 없어요.';

  @override
  String get discoverListsEmptyTitle => '공개 리스트를 찾지 못했어요';

  @override
  String get discoverListsEmptySubtitle => '새 리스트가 올라오면 다시 와봐요';

  @override
  String get discoverListsByAuthorPrefix => '작성자';

  @override
  String get curatedListEmptyTitle => '이 리스트에 영상이 없어요';

  @override
  String get curatedListEmptySubtitle => '영상을 추가해서 시작해보세요';

  @override
  String get curatedListLoadingVideos => '영상 불러오는 중...';

  @override
  String get curatedListFailedToLoad => '리스트를 불러오지 못했어요';

  @override
  String get curatedListVideoNotAvailable => '영상을 사용할 수 없어요';

  @override
  String get curatedListActionsTooltip => '목록 작업';

  @override
  String get curatedListDeleteConfirmTitle => '목록을 삭제할까요?';

  @override
  String get curatedListDeleteConfirmBody =>
      '릴레이에서 목록을 지워요. 목록에 있는 영상은 삭제되지 않아요.';

  @override
  String get curatedListDeletedSnack => '목록을 삭제했어요';

  @override
  String get curatedListDeleteFailed => '목록을 삭제하지 못했어요';

  @override
  String get peopleListsActionsTooltip => '목록 작업';

  @override
  String get listDeleteAction => '목록 삭제';

  @override
  String get peopleListsDeleteConfirmTitle => '목록을 삭제할까요?';

  @override
  String get peopleListsDeleteConfirmBody =>
      '모두에게서 목록을 지워요. 목록에 있는 사람은 언팔로우되지 않아요.';

  @override
  String get peopleListsDeleteFailed => '목록을 삭제하지 못했어요';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonSomethingWentWrong => '문제가 생겼어요';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonCancel => '취소';

  @override
  String get commonBack => '뒤로';

  @override
  String get commonClose => '닫기';

  @override
  String get commonNotNow => '나중에';

  @override
  String get commonLoading => '불러오는 중';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      '커버를 업데이트하지 못했습니다. 다시 시도하세요.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => '커버 업데이트됨';

  @override
  String get videoMetadataC2paMissingTitle => '정품 인증 없이 게시할까요?';

  @override
  String get videoMetadataC2paMissingBody =>
      '콘텐츠 자격 증명을 추가할 수 없어 이 동영상은 사람이 제작한 것으로 확인되지 않습니다. 다시 시도하려면 재생성하거나 그대로 게시하세요.';

  @override
  String get videoMetadataC2paMissingNote => '콘텐츠 자격 증명에는 인터넷 연결이 필요합니다.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      '콘텐츠 자격 증명 서비스가 응답하지 않았어요. 연결 문제가 아닙니다.';

  @override
  String get videoMetadataC2paMissingRegenerate => '재생성';

  @override
  String get videoMetadataC2paMissingSkip => '건너뛰기';

  @override
  String get videoMetadataGenerationFailed => '생성 실패';

  @override
  String get videoMetadataTags => '태그';

  @override
  String get videoMetadataExpiration => '만료';

  @override
  String get videoMetadataExpirationNotExpire => '만료되지 않음';

  @override
  String get videoMetadataExpirationOneDay => '1일';

  @override
  String get videoMetadataExpirationOneWeek => '1주';

  @override
  String get videoMetadataExpirationOneMonth => '1개월';

  @override
  String get videoMetadataExpirationOneYear => '1년';

  @override
  String get videoMetadataExpirationOneDecade => '10년';

  @override
  String get videoMetadataContentWarnings => '콘텐츠 경고';

  @override
  String get videoEditorStickers => '스티커';

  @override
  String get trendingTitle => '트렌딩';

  @override
  String get libraryDeleteConfirm => '삭제';

  @override
  String get libraryWebUnavailableHeadline => '라이브러리는 모바일 앱에서 이용할 수 있어요';

  @override
  String get libraryWebUnavailableDescription =>
      '임시 저장과 클립은 기기에 저장됩니다. 관리하려면 휴대폰에서 Divine을 열어 주세요.';

  @override
  String get libraryTabDrafts => '임시 저장';

  @override
  String get libraryTabClips => '클립';

  @override
  String get libraryDeleteSelectedClipsTooltip => '선택한 클립 삭제';

  @override
  String get libraryCloseSemanticLabel => '라이브러리 닫기';

  @override
  String get libraryStopSelectingClipsSemanticLabel => '클립 선택 종료';

  @override
  String get librarySelectClipsSemanticLabel => '클립 선택';

  @override
  String get libraryGridSizeLabel => '그리드 크기';

  @override
  String get libraryDisplayOptionsLabel => '정렬 및 그리드 크기';

  @override
  String get libraryMoreActionsSemanticLabel => '라이브러리 추가 작업';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count열',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => '선택';

  @override
  String get librarySortNewestCreation => '최신 생성순';

  @override
  String get librarySortOldestCreation => '오래된 생성순';

  @override
  String get librarySortLongestClip => '긴 클립순';

  @override
  String get librarySortShortestClip => '짧은 클립순';

  @override
  String get librarySortSquareFirst => '정사각형 먼저';

  @override
  String get librarySortVerticalFirst => '세로형 먼저';

  @override
  String get libraryDeleteClipsWarning => '되돌릴 수 없어요. 동영상 파일이 기기에서 삭제됩니다.';

  @override
  String get libraryPreparingVideo => '동영상 준비 중...';

  @override
  String libraryCreateVideo(int count) {
    return '동영상 만들기 ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$destination에 클립 $count개 저장됨',
      one: '$destination에 클립 1개 저장됨',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount개 저장, $failureCount개 실패';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return '$destination에 저장할 수 없어요';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination 권한이 거부되었어요';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클립 $count개 삭제됨',
      one: '클립 1개 삭제됨',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => '실행 취소';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: '$daysLeft일 후 자동 삭제됨',
      one: '내일 자동 삭제됨',
      zero: '오늘 자동 삭제됨',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => '임시 저장 영상을 불러올 수 없어요';

  @override
  String get libraryCouldNotLoadClips => '클립을 불러올 수 없어요';

  @override
  String get libraryOpenErrorDescription => '라이브러리를 열 때 문제가 생겼어요. 다시 시도해 주세요.';

  @override
  String get libraryNoDraftsYetTitle => '아직 임시 저장이 없어요';

  @override
  String get libraryNoDraftsYetSubtitle => '임시 저장으로 저장한 동영상이 여기에 표시됩니다';

  @override
  String get libraryNoClipsYetTitle => '아직 클립이 없어요';

  @override
  String get libraryNoClipsYetSubtitle => '녹화한 클립이 여기에 표시됩니다';

  @override
  String get libraryDraftDeletedSnackbar => '임시 저장을 삭제했어요';

  @override
  String get libraryDraftDeleteFailedSnackbar => '임시 저장을 삭제하지 못했어요';

  @override
  String get libraryDraftDuplicatedSnackbar => '임시 저장을 복제했어요';

  @override
  String get libraryDraftDuplicateFailedSnackbar => '임시 저장을 복제하지 못했어요';

  @override
  String get libraryDraftInProgressBadge => '진행 중';

  @override
  String get libraryDraftActionPost => '게시';

  @override
  String get libraryDraftActionEdit => '편집';

  @override
  String get libraryDraftActionDuplicate => '복제';

  @override
  String get libraryDraftActionDelete => '임시 저장 삭제';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (사본 $number)';
  }

  @override
  String get libraryDeleteDraftTitle => '임시 저장 삭제';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '“$title”을(를) 삭제할까요?';
  }

  @override
  String get libraryDeleteClipTitle => '클립 삭제';

  @override
  String get libraryDeleteClipMessage => '이 클립을 삭제할까요?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds초';
  }

  @override
  String get libraryRecordVideo => '동영상 녹화';

  @override
  String videoClipSemanticLabel(String duration) {
    return '동영상 클립, $duration초';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return '보관됨. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return '스톱모션 클립, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return '선택됨, $position번';
  }

  @override
  String get videoClipSemanticValueSelected => '선택됨';

  @override
  String get videoClipSemanticValueNotSelected => '선택 안 됨';

  @override
  String get videoClipSemanticHintDisabled => '비활성화됨';

  @override
  String get videoClipSemanticHintSelect => '탭하여 선택, 길게 눌러 미리보기';

  @override
  String get videoClipSemanticHintDeselect => '탭하여 선택 해제, 길게 눌러 미리보기';

  @override
  String get routerInvalidCreator => '유효하지 않은 크리에이터';

  @override
  String get routerInvalidHashtagRoute => '유효하지 않은 해시태그 경로';

  @override
  String get categoryGalleryCouldNotLoadVideos => '동영상을 불러올 수 없었어요';

  @override
  String get categoryGalleryNoVideosInCategory => '이 카테고리에 영상이 없어요';

  @override
  String get categoryGallerySortOptionsLabel => '카테고리 정렬 옵션';

  @override
  String get categoryGallerySortHot => '인기';

  @override
  String get categoryGallerySortNew => '최신';

  @override
  String get categoryGallerySortClassic => '클래식';

  @override
  String get categoryGallerySortForYou => '추천';

  @override
  String get categoriesCouldNotLoadCategories => '카테고리를 불러올 수 없었어요';

  @override
  String get categoriesNoCategoriesAvailable => '사용할 수 있는 카테고리가 없어요';

  @override
  String get notificationsEmptyTitle => '아직 활동이 없어요';

  @override
  String get notificationsEmptySubtitle => '다른 사람들이 내 콘텐츠에 반응하면 여기에 표시돼요';

  @override
  String get appsPermissionsTitle => '연동 권한';

  @override
  String get appsPermissionsRevoke => '취소';

  @override
  String get appsPermissionsEmptyTitle => '저장된 연동 권한이 없어요';

  @override
  String get appsPermissionsEmptySubtitle => '접근을 승인하고 기억해두면 승인된 연동이 여기에 표시돼요.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName이(가) 승인을 요청해요';
  }

  @override
  String get nostrAppPermissionDescription =>
      '이 앱은 Divine의 검증된 샌드박스를 통해 접근을 요청하고 있어요.';

  @override
  String get nostrAppPermissionOrigin => '출처';

  @override
  String get nostrAppPermissionMethod => '메서드';

  @override
  String get nostrAppPermissionCapability => '권한';

  @override
  String get nostrAppPermissionEventKind => '이벤트 종류';

  @override
  String get nostrAppPermissionAllow => '허용';

  @override
  String get appsDetailDefaultTitle => '연동 앱';

  @override
  String get appsDetailNotFoundTitle => '연동을 찾을 수 없어요';

  @override
  String get appsDetailNotFoundSubtitle => '이 승인된 연동은 더 이상 Divine에서 이용할 수 없어요.';

  @override
  String get appsDetailHowItWorksTitle => '작동 방식';

  @override
  String get appsDetailHowItWorksBody =>
      '이건 Divine 안에서 돌아가는 승인된 서드파티 앱이에요. Divine은 이 연동에 검토된 권한만 부여하고, 승인된 출처 밖으로의 이동을 막아요.';

  @override
  String get appsDetailAboutTitle => '정보';

  @override
  String get appsDetailPrimaryOriginTitle => '기본 출처';

  @override
  String get appsDetailApprovedOriginsTitle => '승인된 출처';

  @override
  String get appsDetailCapabilitiesTitle => '이용 가능한 권한';

  @override
  String get appsDetailAskBeforeTitle => '먼저 물어보기';

  @override
  String get appsDetailOpenButton => '연동 열기';

  @override
  String get appsDetailNoneDeclared => '아직 선언된 항목 없음';

  @override
  String get appsDirectoryTitle => '연동 앱';

  @override
  String get appsDirectoryIntroTitle => '승인된 서드파티 앱';

  @override
  String get appsDirectoryIntroBody => 'Divine 안에서 돌아가는 승인된 서드파티 앱';

  @override
  String get appsDirectoryErrorTitle => '연동 앱을 불러오지 못했어요';

  @override
  String get appsDirectoryErrorSubtitle => '당겨서 승인된 연동을 다시 시도해보세요.';

  @override
  String get appsDirectoryEmptyTitle => '아직 승인된 연동이 없어요';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Divine이 추가하는 대로 승인된 서드파티 앱이 여기에 나타나요.';

  @override
  String get appsDirectoryRefresh => '새로고침';

  @override
  String get appsDirectoryUnsupportedTitle => '연동 앱은 Divine 모바일에서 실행돼요';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      '승인된 연동은 지금은 모바일에서만 이용할 수 있어요.';

  @override
  String get appsSandboxUnavailableTitle => '연동을 이용할 수 없어요';

  @override
  String get appsSandboxUnavailableBody =>
      '연동 앱 탭에서 승인된 연동을 열어야 Divine이 올바른 접근 정책을 적용할 수 있어요.';

  @override
  String get appsSandboxLoadingTitle => '연동 불러오는 중';

  @override
  String get appsSandboxLoadingSubtitle => '실행 전에 승인된 연동을 확인하고 있어요.';

  @override
  String get appsSandboxBlockedTitle => '안전을 위해 차단됨';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return '이 연동이 승인된 출처를 벗어나려고 했어요.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => '게시물 링크를 클립보드에 복사했어요';

  @override
  String get shareCopiedEventJson => 'Nostr 이벤트 JSON을 클립보드에 복사했어요';

  @override
  String get shareCopiedEventId => 'Nostr 이벤트 ID를 클립보드에 복사했어요';

  @override
  String get authHeroTaglineAuthentic => '진짜 순간들.';

  @override
  String get authHeroTaglineHuman => '사람의 창의성.';

  @override
  String get keyImportFailedToImport => '키를 가져오거나 벙커에 연결하지 못했어요';

  @override
  String get keyImportInvalidBunkerUrl => '잘못된 벙커 URL';

  @override
  String get keyImportInvalidFormat =>
      '잘못된 형식이에요. nsec..., hex, ncryptsec1..., 또는 bunker://... 를 사용해주세요';

  @override
  String get keyImportInvalidNsecFormat => '잘못된 nsec 형식이에요. 63자여야 해요';

  @override
  String get keyImportKeyFieldLabel => '개인 키 또는 벙커 URL';

  @override
  String get keyImportKeyRequired => '개인 키 또는 벙커 URL을 입력해주세요';

  @override
  String get keyImportPasswordRequired => '이 암호화된 키의 비밀번호를 입력해주세요';

  @override
  String get keyImportSecurityWarningBody =>
      '개인 키는 절대 누구와도 공유하지 마세요. 이 키는 당신의 Nostr 신원에 대한 전체 접근 권한을 줘요.';

  @override
  String get keyImportSecurityWarningTitle => '개인 키를 안전하게 보관하세요!';

  @override
  String get keyImportSubtitle => '개인 키나 벙커 URL로 기존 Nostr 신원을 가져오세요.';

  @override
  String get keyImportTitle => 'Nostr 신원\n가져오기';

  @override
  String get commentAuthorYouIndicator => '나';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return '$name님의 프로필 보기';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => '댓글 삭제';

  @override
  String get commentOptionsEditSemanticLabel => '댓글 수정';

  @override
  String get commentOptionsFlagContentLabel => '콘텐츠 신고';

  @override
  String get commentOptionsFlagContentSemanticLabel => '이 콘텐츠 신고';

  @override
  String get commentOptionsFlagReasonPrompt => '이 댓글을 신고하는 이유를 선택해주세요';

  @override
  String get commentOptionsFlagSubmit => '제출';

  @override
  String get commentOptionsTitle => '옵션';

  @override
  String get commentsEmptyClassicVineMessage =>
      '아카이브의 옛 댓글을 아직 가져오는 중이에요. 아직 준비되지 않았어요.';

  @override
  String get commentsEmptyClassicVineTitle => '클래식 Vine';

  @override
  String get commentsInputEditingLabel => '수정 중';

  @override
  String get commentsInputSemanticHint => '댓글 달기';

  @override
  String get commentsInputSemanticHintEdit => '댓글 수정';

  @override
  String get commentsInputSemanticHintReply => '답글 달기';

  @override
  String get commentsInputSemanticLabel => '댓글 입력';

  @override
  String get commentsInputSemanticLabelEdit => '수정 입력';

  @override
  String get commentsInputSemanticLabelReply => '답글 입력';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return '$displayName님의 프로필 보기';
  }

  @override
  String get classicsEmptyDescription => '클래식 아카이브를 불러오는 중이에요';

  @override
  String get classicsEmptyTitle => '클래식을 찾을 수 없어요';

  @override
  String get classicsErrorTitle => '클래식을 불러오지 못했어요';

  @override
  String get classicsUnavailableDescription =>
      '클래식은 Funnelcake 릴레이에 연결됐을 때만 이용할 수 있어요.';

  @override
  String get classicsUnavailableSettingsHint =>
      '클래식 아카이브를 이용하려면 설정에서 Funnelcake를 지원하는 릴레이로 전환하세요.';

  @override
  String get classicsUnavailableTitle => '클래식을 이용할 수 없어요';

  @override
  String get hashtagFeedEmptySubtitle => '이 해시태그로 영상을 처음 올려보세요!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return '#$hashtag에 대한 영상이 없어요';
  }

  @override
  String get hashtagFeedLoadingSubtitle => '잠시 걸릴 수 있어요';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return '#$hashtag에 대한 영상을 불러오는 중...';
  }

  @override
  String get hashtagInputHint => '해시태그 추가... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => '새 콘텐츠를 나중에 다시 확인해보세요';

  @override
  String get newVideosTabEmptyTitle => '새 영상에 영상이 없어요';

  @override
  String get popularVideosContextTitle => '인기 영상';

  @override
  String get popularVideosEmptySubtitle => '새 콘텐츠를 나중에 다시 확인해보세요';

  @override
  String get popularVideosEmptyTitle => '인기 영상에 영상이 없어요';

  @override
  String get popularVideosErrorTitle => '인기 급상승 영상을 불러오지 못했어요';

  @override
  String get popularVideosFeedSourceLabel => '인기 피드 소스';

  @override
  String get trendingHashtagsLoading => '해시태그를 불러오는 중...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return '$hashtag이(가) 태그된 영상 보기';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return '영상 작성자: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return '영상 설명: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine의 비전은 당신에게 진정한 알고리즘 선택권을 주는 거예요. 하나의 블랙박스 알고리즘에 갇히는 대신, 여러 추천 방식 중에서 고를 수 있게 될 거예요:';

  @override
  String get forYouAlgorithmChoiceChronological => '팔로우하는 크리에이터의 시간순 타임라인';

  @override
  String get forYouAlgorithmChoiceClosing =>
      '이건 당신의 관심을 플랫폼에 맡기는 대신 당신이 직접 통제하게 해줘요. 피드가 어떻게 큐레이션되는지 알아야 하고, 원할 때 언제든 바꿀 수 있는 힘이 있어야 해요.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      '음악, 코미디, 예술 같은 주제를 위한 커뮤니티가 만든 맞춤 피드';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed => '개인 맞춤 \"추천\" 피드';

  @override
  String get forYouAlgorithmChoiceTitle => '당신의 알고리즘, 당신의 선택';

  @override
  String get forYouAlgorithmChoiceTrending => '인기 급상승 및 인기 콘텐츠';

  @override
  String get forYouAlgorithmCommentsDescription => '강한 신호 — 응답할 만큼 몰입했어요';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine은 당신이 콘텐츠와 어떻게 상호작용하는지 살펴 무엇을 즐기는지 파악해요. 영상을 볼 때마다, 반응을 남길 때마다, 댓글을 달 때마다, 리포스트할 때마다 시스템이 기록해요.';

  @override
  String get forYouAlgorithmHowItWorksTitle => '작동 방식';

  @override
  String get forYouAlgorithmInteractionsIntro => '서로 다른 행동은 서로 다른 관심 수준을 나타내요:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      '아직 시청 기록이 쌓이지 않았다면, 지금 인기 있고 급상승 중인 콘텐츠와 최근 업로드를 섞어서 보여줘요. 탐색을 시작하기에 좋은 출발점이 돼요.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      '영상을 보고, 좋아요를 누르고, 콘텐츠와 어울리다 보면 추천이 점점 더 개인 맞춤형이 돼요. 시간이 지나면 추천 피드가 혼자서는 발견하지 못했을 크리에이터의 영상을 보여줘요.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Divine이 처음이세요?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      '우리는 개발자가 자신만의 알고리즘을 구현할 수 있는 열린 시스템을 만들고 있어요. 그리고 당신은 어떤 걸 쓸지 고르거나, 아예 쓰지 않을 수도 있어요.';

  @override
  String get forYouAlgorithmOpenSourceTitle => '오픈소스 & 투명함';

  @override
  String get forYouAlgorithmReactionsDescription => '중간 신호 — 감사를 표현하는 빠른 방법';

  @override
  String get forYouAlgorithmReactionsTitle => '반응';

  @override
  String get forYouAlgorithmRepostsDescription =>
      '가장 강한 신호 — 팔로워와 공유하는 건 강력한 지지예요';

  @override
  String get forYouAlgorithmSubtitle => '오픈소스 추천 엔진 Gorse로 구동돼요';

  @override
  String get forYouAlgorithmTitle => 'Divine 알고리즘';

  @override
  String get forYouAlgorithmViewsDescription => '약한 신호 — 기본적인 관심을 나타내요';

  @override
  String get forYouEmptyDescription => '영상을 보고 좋아요를 눌러 개인 맞춤 추천을 받아보세요.';

  @override
  String get forYouEmptyTitle => '아직 추천이 없어요';

  @override
  String get forYouErrorTitle => '추천을 불러오지 못했어요';

  @override
  String get forYouUnavailableDescription => '개인 맞춤 추천은 Funnelcake 연결이 필요해요.';

  @override
  String get forYouUnavailableTitle => '추천을 이용할 수 없어요';

  @override
  String get inboxConversationOptionsLabel => '옵션';

  @override
  String get inboxConversationViewProfileButton => '프로필 보기';

  @override
  String get inboxMessageRequestsEmpty => '메시지 요청 없음';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return '메시지 요청, $requestCount건 대기 중';
  }

  @override
  String get inboxMessageRequestsTitle => '메시지 요청';

  @override
  String get inboxMessagesTab => '메시지';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayName님의 메시지 요청';
  }

  @override
  String get inboxRequestTileSubtitle => '메시지 요청을 보냈어요';

  @override
  String get inboxRequestsMarkAllRead => '모든 요청을 읽음으로 표시';

  @override
  String get inboxRequestsRemoveAll => '모든 요청 삭제';

  @override
  String get messageRequestDeclineAndRemoveButton => '거절하고 삭제';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return '$displayName님의 요청을 거절했어요';
  }

  @override
  String get messageRequestLoadFailed => '이 요청을 불러오지 못했어요.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '팔로워 $count명';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '영상 $count개';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '메시지 $count개',
      one: '메시지 1개',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => '메시지 보기';

  @override
  String get messageRequestViewProfileButton => '프로필 보기';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName님이 메시지를 보내고 싶어 해요. $messageText을(를) 보냈어요.';
  }

  @override
  String get deleteAccountAccountChanged =>
      '계정이 전환돼서 아무것도 삭제되지 않았어요. 삭제할 계정에서 삭제 화면을 다시 열어주세요.';

  @override
  String get deleteAccountConfirmDeletePrompt => '확인하려면 다음을 입력해주세요:';

  @override
  String get deleteAccountConfirmUsernamePrompt => '확인하려면 사용자명을 입력해주세요:';

  @override
  String get deleteAccountConfirmationHint => 'DELETE 입력';

  @override
  String get deleteAccountConfirmationHintUsername => '사용자명 입력';

  @override
  String get deleteAccountDeleteAllContentButton => '모든 콘텐츠 삭제';

  @override
  String get accountDeletionRecoveryTitle => '계정 삭제 중';

  @override
  String get accountDeletionRecoveryBody =>
      '계정 삭제를 완료하지 못했어요. 사용자명은 그대로 예약돼 있어서 아직 되돌릴 수 있어요.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => '사용자명 되돌리기';

  @override
  String get accountDeletionFinishingBody =>
      '계정 삭제 요청이 아직 처리 중이에요. 처리가 완료될 때까지 다른 계정을 사용할 수 있어요.';

  @override
  String get accountDeletionOtherAccountPending =>
      '이 기기에서 다른 계정의 삭제가 아직 처리 중이에요. 처리가 완료된 후 이 계정을 삭제해 주세요.';

  @override
  String get accountDeletionCancellingBody =>
      '삭제를 취소하고 있어요. 이 화면을 나가기 전에 다시 확인해 주세요.';

  @override
  String get accountDeletionRecoveryFailed =>
      '사용자명을 아직 되돌리지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get accountDeletionUsernameRestored => '사용자명을 되돌렸어요. 계정은 삭제되지 않았어요.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      '삭제 상태를 확인하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';

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
      '지금은 계정을 삭제할 수 없어요. 삭제된 항목은 없어요.';

  @override
  String get deleteAccountDeletionIncomplete => '계정 삭제를 완료하지 못했어요. 다시 시도해주세요.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ 최종 확인';

  @override
  String get deleteAccountKeyDeletionWarning =>
      '삭제 요청을 보냈지만, 키가 이 기기에서 완전히 제거되지 않았을 수 있어요. 설정 → Nostr 키 → 키 제거로 가서 다시 시도하세요.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      '삭제 요청을 보내고 로그아웃됐지만, 일부 로컬 데이터는 이 기기에서 제거하지 못했어요.';

  @override
  String get deleteAccountPreparingDeletion => '삭제 준비 중...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '이벤트 $current / $total개';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      '이 기기에서 이 계정의 로컬 로그인을 제거해요. Divine 계정이나 Nostr 신원은 삭제되지 않아요.\n\n이 계정의 초안과 클립은 이 기기에 그대로 저장돼 있어요. 이게 마지막 로컬 계정이면 로그인 화면으로 돌아가요.';

  @override
  String get deleteAccountRemoveKeysConfirm => '기기에서 제거';

  @override
  String get deleteAccountRemoveKeysTitle => '이 기기에서 이 계정을 제거할까요?';

  @override
  String get deleteAccountReauthRequired =>
      '계정을 삭제하려면 다시 로그인해 주세요. 아직 삭제된 건 없어요.';

  @override
  String get deleteAccountServerDeletionFailed =>
      '게시물 삭제 요청은 보냈지만 계정 삭제를 완료하지 못했어요. 잠시 후 다시 시도해주세요.';

  @override
  String get deleteAccountSuccess =>
      'Divine 계정이 삭제됐어요. Nostr 게시물에 대한 삭제 요청도 전송했지만, 일부 릴레이, 클라이언트 또는 캐시에 사본이 남아 있을 수 있어요.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      '계정 삭제를 요청했어요. 기존 게시물 중 일부는 개별적으로 삭제를 확인하지 못했어요.';

  @override
  String get deleteAccountWarningBody =>
      '이건 계정과 콘텐츠의 삭제 요청을 보내고, 가능하면 Divine 계정을 삭제하고, 이 기기에서 로그아웃해요. 일부 릴레이, 클라이언트, 검색 색인에는 사본이 남을 수 있어요. 로그인된 다른 기기는 거기서 키를 제거할 때까지 계속 활성 상태예요.';

  @override
  String get findPeopleNoContacts => '연락처를 찾을 수 없어요.\n사람들을 팔로우하면 여기에 나타나요.';

  @override
  String get geoBlockedCityLabel => '도시';

  @override
  String get geoBlockedCountryLabel => '국가';

  @override
  String get geoBlockedDefaultReason => '현지 규정으로 인해 이 서비스는 당신의 지역에서 이용할 수 없어요.';

  @override
  String get geoBlockedLegalNotice =>
      '우리는 당신 지역의 법과 규정을 존중해요. 이 제한은 당신의 IP 주소 위치를 기반으로 해요.';

  @override
  String get geoBlockedRegionLabel => '지역';

  @override
  String get geoBlockedTitle => '서비스를 이용할 수 없어요';

  @override
  String get likedVideosEmpty => '좋아요한 영상 없음';

  @override
  String get likedVideosInvalidRoute => '잘못된 경로';

  @override
  String get likedVideosTitle => '좋아요한 영상';

  @override
  String get uploadFailureSheetRetryingSnackbar => '업로드 다시 시도 중…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => '초안에 저장';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => '초안에 저장했어요';

  @override
  String get uploadFailureSheetTitle => '업로드 실패';

  @override
  String get uploadFailureSheetTryAgainButton => '다시 시도';

  @override
  String get videoEditorAudioImportAudio => '오디오 가져오기';

  @override
  String get videoEditorAudioImportFailed => '오디오 가져오기에 실패했어요.';

  @override
  String get videoIconPlaceholderLabel => '영상';

  @override
  String get publishErrorNotSignedIn => '영상을 게시하려면 로그인해주세요.';

  @override
  String get publishErrorNoRetry => '다시 시도할 업로드가 없어요.';

  @override
  String get publishErrorNoInternet =>
      '인터넷에 연결되어 있지 않아요. 와이파이나 모바일 데이터를 확인하고 다시 시도해주세요.';

  @override
  String get publishErrorServerUnreachable => '서버에 연결할 수 없어요. 잠시 후 다시 시도해주세요.';

  @override
  String get publishErrorTimeout =>
      '업로드 시간이 초과됐어요. 더 안정적인 연결을 쓰거나 더 작은 영상으로 시도해보세요.';

  @override
  String get publishErrorTls =>
      '보안 연결에 실패했어요. 네트워크를 확인해주세요 — 공용 와이파이는 업로드를 막을 수 있어요.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return '미디어 서버($serverName)를 사용할 수 없어요. 설정에서 다른 서버를 고를 수 있어요.';
  }

  @override
  String get publishErrorFileTooLarge =>
      '영상 파일이 서버에 올리기엔 너무 커요. 영상을 자르거나 화질을 낮춰서 시도해보세요.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return '미디어 서버($serverName)에 내부 오류가 발생했어요. 설정에서 다른 서버를 고를 수 있어요.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return '미디어 서버($serverName)가 일시적으로 다운됐어요. 잠시 후 다시 시도하거나 설정에서 다른 서버를 골라보세요.';
  }

  @override
  String get publishErrorForbidden => '이 서버에 업로드할 권한이 없어요.';

  @override
  String get publishErrorFileNotFound =>
      '영상 파일을 찾을 수 없어요. 삭제됐을 수도 있어요. 다시 녹화하고 시도해주세요.';

  @override
  String get publishErrorLowStorage => '기기에 저장 공간이 부족해요. 공간을 좀 확보하고 다시 시도해주세요.';

  @override
  String get publishErrorThumbnailFailed =>
      '영상은 업로드됐지만 썸네일을 준비하지 못했어요. 다시 시도해주세요.';

  @override
  String get publishErrorNostrPublishFailed =>
      '영상은 업로드됐지만 게시물을 올리지 못했어요. 릴레이 설정을 확인하고 다시 시도해주세요.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      '영상은 업로드됐지만 이 사운드는 재사용이 허용되지 않았어요. 다른 사운드를 골라서 올려주세요.';

  @override
  String get publishErrorInterrupted => '업로드가 중단됐어요. 다시 시도할까요?';

  @override
  String get publishErrorAccountChanged =>
      '이 영상은 다른 계정 거예요. 올리려면 그 계정으로 다시 전환해 주세요.';

  @override
  String get publishErrorGeneric => '문제가 생겼어요. 다시 시도해주세요.';

  @override
  String get publishErrorRateLimited => '지금 업로드가 너무 많아요. 잠시 후 다시 시도해주세요.';

  @override
  String get publishErrorUploadSessionExpired => '업로드 세션이 만료됐어요. 다시 시도해주세요.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine에 업로드 권한이 없어요. 설정에서 앱 권한을 확인하고 다시 시도해주세요.';

  @override
  String get publishErrorOutOfMemory => '기기 메모리가 부족해요. 앱을 몇 개 닫고 다시 시도해주세요.';

  @override
  String get publishErrorOverlaysUnavailable =>
      '이 초안의 텍스트와 스티커를 준비하지 못했어요. 편집기에서 연 다음 다시 게시해주세요.';

  @override
  String get publishErrorUnknownServer => '알 수 없는 서버';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return '필터: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return '\"$query\"에 대한 결과가 없어요';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return '$tag이(가) 태그된 영상 보기';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return '사운드: $creatorName님의 $soundName. 탭하면 사운드 세부 정보를 볼 수 있어요.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return '$creatorName님의 오리지널 사운드. 탭하면 이 사운드를 쓸 수 있어요.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return '사운드: $creatorName님의 $soundName. 탭하면 세부 정보를 볼 수 있어요.';
  }

  @override
  String get soundDetailLoadError => '사운드를 불러오지 못했어요. 다시 시도해보세요.';

  @override
  String get soundDetailNotFoundMessage => '이 사운드를 찾을 수 없어요';

  @override
  String get soundDetailNotFoundTitle => '사운드를 찾을 수 없어요';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 루프 $count회';
  }

  @override
  String get originalSoundUnavailableBody => '이 영상의 오디오는 따로 이용할 수 없어요.';

  @override
  String originalSoundByCreator(String creatorName) {
    return '오리지널 사운드 - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      '이 사람은 Divine이 아카이브에서 찾은 오리지널 Vine을 올렸어요. 계정 인증 배지는 아니에요.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => '프로필 체크마크';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine는 이 체크마크를 팀 계정에 부여해요. NIP-05, 인증된 계정 링크, OG Viner 상태와는 별개예요.';

  @override
  String get unfollowConfirmButton => '언팔로우';

  @override
  String get videoClipSaveFailed => '클립을 저장하지 못했어요';

  @override
  String videoClipSaveTo(String destination) {
    return '$destination에 저장';
  }

  @override
  String get videoClipDelete => '클립 삭제';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '$creatorName +$additionalCreatorCount님에게서 영감을 받았어요. 탭하면 프로필을 볼 수 있어요.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return '$creatorName님에게서 영감을 받았어요. 탭하면 프로필을 볼 수 있어요.';
  }

  @override
  String get bugReportSendReport => '신고 보내기';

  @override
  String get supportSubjectRequiredLabel => '제목 *';

  @override
  String get supportPublicSubmissionTitle => '공개 GitHub 게시물';

  @override
  String get supportPublicSubmissionMessage =>
      '여기에 제출하는 모든 내용은 개발자가 작업을 맡을 수 있도록 GitHub의 오픈 소스 저장소에 게시됩니다. 게시물과 로그인한 계정은 누구나 공개적으로 볼 수 있습니다.';

  @override
  String get supportRequiredHelper => '필수';

  @override
  String get supportFieldLimitReached => '최대 길이예요. 이후 내용은 추가되지 않았어요.';

  @override
  String get bugReportSubjectHint => '문제를 짧게 요약해주세요';

  @override
  String get bugReportDescriptionRequiredLabel => '무슨 일이 있었나요? *';

  @override
  String get bugReportDescriptionHint => '겪은 문제를 설명해주세요';

  @override
  String get bugReportStepsLabel => '재현 단계';

  @override
  String get bugReportStepsHint => '1. ...로 이동\n2. ...을 탭\n3. 오류 발생';

  @override
  String get bugReportExpectedBehaviorLabel => '예상한 동작';

  @override
  String get bugReportExpectedBehaviorHint => '원래 어떻게 됐어야 했나요?';

  @override
  String get bugReportDiagnosticsNotice => '기기 정보와 로그가 자동으로 함께 보내져요.';

  @override
  String get bugReportSuccessMessage =>
      '고마워요! 신고를 받았어요. Divine을 더 좋게 만드는 데 쓸게요.';

  @override
  String get bugReportAttachImages => '이미지 첨부';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$max장 중 $count장 선택됨';
  }

  @override
  String get bugReportRemoveImage => '이미지 삭제';

  @override
  String get bugReportUploadFailed =>
      '선택한 이미지를 업로드하지 못했어요. 다시 시도하거나 이미지 없이 신고를 보내세요.';

  @override
  String get bugReportSendFailed => '버그 신고를 보내지 못했어요. 잠시 후 다시 시도해주세요.';

  @override
  String get featureRequestSendRequest => '요청 보내기';

  @override
  String get featureRequestSubjectHint => '아이디어를 짧게 요약해주세요';

  @override
  String get featureRequestDescriptionRequiredLabel => '어떤 기능을 원하세요? *';

  @override
  String get featureRequestDescriptionHint => '원하는 기능을 설명해주세요';

  @override
  String get featureRequestUsefulnessLabel => '어떻게 도움이 될까요?';

  @override
  String get featureRequestUsefulnessHint => '이 기능이 어떤 도움을 주는지 설명해주세요';

  @override
  String get featureRequestWhenLabel => '언제 사용하실 건가요?';

  @override
  String get featureRequestWhenHint => '이 기능이 도움 될 만한 상황을 설명해주세요';

  @override
  String get featureRequestSuccessMessage => '고마워요! 기능 요청을 받았고 검토할게요.';

  @override
  String get featureRequestSendFailed => '기능 요청을 보내지 못했어요. 잠시 후 다시 시도해주세요.';

  @override
  String get notificationFollowBack => '맞팔로우';

  @override
  String get followingTitle => '팔로잉';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName님의 팔로잉';
  }

  @override
  String get followingFailedToLoadList => '팔로잉 목록을 불러오지 못했어요';

  @override
  String get followingEmptyTitle => '아직 아무도 팔로우하지 않아요';

  @override
  String get followersTitle => '팔로워';

  @override
  String followersTitleForName(String displayName) {
    return '$displayName님의 팔로워';
  }

  @override
  String get followersFailedToLoadList => '팔로워 목록을 불러오지 못했어요';

  @override
  String get followersEmptyTitle => '아직 팔로워가 없어요';

  @override
  String get followersUpdateFollowFailed => '팔로우 상태를 업데이트하지 못했어요. 다시 시도해주세요.';

  @override
  String get followersSortSemanticLabel => '팔로워 정렬';

  @override
  String get followingSortSemanticLabel => '팔로잉 정렬';

  @override
  String get followSortTitle => '정렬 기준';

  @override
  String get followSortNewest => '최신순';

  @override
  String get followSortOldest => '오래된순';

  @override
  String get newMessageTitle => '새 메시지';

  @override
  String get newMessageFindPeople => '사람 찾기';

  @override
  String get newMessageNoContacts => '연락처가 없어요.\n사람들을 팔로우하면 여기서 볼 수 있어요.';

  @override
  String get newMessageNoUsersFound => '사용자를 찾지 못했어요';

  @override
  String get hashtagSearchTitle => '해시태그 검색';

  @override
  String get hashtagSearchSubtitle => '인기 토픽과 콘텐츠를 둘러봐요';

  @override
  String hashtagSearchNoResults(String query) {
    return '\"$query\"에 대한 해시태그를 찾지 못했어요';
  }

  @override
  String get hashtagSearchFailed => '검색에 실패했어요';

  @override
  String get userNotAvailableTitle => '계정을 사용할 수 없어요';

  @override
  String get userNotAvailableBody => '이 계정은 지금 사용할 수 없어요.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings => '설정 저장에 실패했어요. 다시 시도해보세요.';

  @override
  String get blossomValidServerUrl =>
      '올바른 서버 URL을 입력해주세요 (예: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom 설정을 저장했어요';

  @override
  String get blossomSaveTooltip => '저장';

  @override
  String get blossomAboutTitle => 'Blossom 정보';

  @override
  String get blossomAboutDescription =>
      'Blossom은 분산형 미디어 저장 프로토콜이에요. 호환되는 어떤 서버에든 영상을 올릴 수 있어요. 기본적으로 영상은 Divine의 Blossom 서버로 올라가요. 아래 옵션을 켜면 커스텀 서버를 쓸 수 있어요.';

  @override
  String get blossomUseCustomServer => '커스텀 Blossom 서버 사용';

  @override
  String get blossomCustomServerEnabledSubtitle => '커스텀 Blossom 서버로 영상이 올라가요';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      '지금은 Divine의 Blossom 서버로 영상이 올라가고 있어요';

  @override
  String get blossomCustomServerUrl => '커스텀 Blossom 서버 URL';

  @override
  String get blossomCustomServerHelper => '커스텀 Blossom 서버 URL을 입력해주세요';

  @override
  String get blossomPopularServers => '인기 Blossom 서버';

  @override
  String get blossomServerUrlMustUseHttps => 'Blossom 서버 URL은 https://를 써야 해요';

  @override
  String get blueskyFailedToUpdateCrosspost => '크로스포스트 설정 업데이트에 실패했어요';

  @override
  String get blueskySignInRequired => 'Bluesky 설정을 관리하려면 로그인해주세요';

  @override
  String get blueskyPublishVideos => 'Bluesky에 영상 게시';

  @override
  String get blueskyEnabledSubtitle => '영상이 Bluesky에 게시돼요';

  @override
  String get blueskyDisabledSubtitle => '영상이 Bluesky에 게시되지 않아요';

  @override
  String get blueskyBackfillDisclosureTitle => '이전 동영상도 게시됩니다';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      '이 기능을 켜면 Divine이 오래된 동영상부터 Bluesky로 보내기 시작하며, 일일 한도를 무리하게 채우지 않습니다.';

  @override
  String get blueskyHandle => 'Bluesky 핸들';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => '상태';

  @override
  String get blueskyStatusReady => '계정이 준비됐어요';

  @override
  String get blueskyStatusPending => '계정을 준비하는 중...';

  @override
  String get blueskyStatusFailed => '계정 준비에 실패했어요';

  @override
  String get blueskyStatusDisabled => '계정이 비활성화됐어요';

  @override
  String get blueskyStatusNotLinked => '연결된 Bluesky 계정이 없어요';

  @override
  String get blueskyUsernameRequired =>
      'Bluesky에 게시하기 전에 divine.video 핸들을 설정하세요';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Bluesky 게시에는 등록된 username.divine.video 핸들이 필요해요.';

  @override
  String get blueskyUsernameSyncPending =>
      'Divine 핸들이 등록됐어요. Bluesky와 연결 중이니 잠시 후 다시 시도해 주세요.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Divine 핸들을 확인하지 못했어요. 다시 시도해 주세요.';

  @override
  String get blueskySetUpHandle => '설정하기';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Bluesky 게시를 일시적으로 사용할 수 없어요. 다시 시도해 주세요.';

  @override
  String get invitesTitle => '친구 초대';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '생성할 수 있는 초대 $count개',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle => '공유할 준비가 되면 코드를 생성하세요.';

  @override
  String get invitesGenerateButtonLabel => '초대 생성';

  @override
  String get invitesNoneAvailable => '지금은 사용할 수 있는 초대장이 없어요';

  @override
  String get invitesShareWithPeople => 'Divine을 아는 사람들과 나눠봐요';

  @override
  String get invitesUsedInvites => '사용된 초대장';

  @override
  String invitesShareMessage(String code) {
    return 'Divine에 함께해요! 초대 코드 $code로 시작해보세요:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => '초대장 복사';

  @override
  String get invitesCopied => '초대장을 복사했어요!';

  @override
  String get invitesShareInvite => '초대장 공유';

  @override
  String get invitesShareSubject => 'Divine에 함께해요';

  @override
  String get invitesClaimed => '사용됨';

  @override
  String get invitesCouldNotLoad => '초대장을 불러오지 못했어요';

  @override
  String get invitesRetry => '다시 시도';

  @override
  String get searchSomethingWentWrong => '문제가 발생했어요';

  @override
  String get searchTryAgain => '다시 시도';

  @override
  String get searchForLists => '목록 검색';

  @override
  String get searchFindCuratedVideoLists => '큐레이션된 동영상 목록 찾기';

  @override
  String get searchEnterQuery => '검색어를 입력하세요';

  @override
  String get searchDiscoverSomethingInteresting => '흥미로운 것을 발견해보세요';

  @override
  String get searchPeopleSectionHeader => '사람';

  @override
  String get searchPeopleLoadingLabel => '사람 검색 결과 불러오는 중';

  @override
  String get searchTagsSectionHeader => '태그';

  @override
  String get searchTagsLoadingLabel => '태그 검색 결과 불러오는 중';

  @override
  String get searchVideosSectionHeader => '영상';

  @override
  String get searchVideosLoadingLabel => '영상 검색 결과 불러오는 중';

  @override
  String get searchVideosSortOptionsLabel => '영상 결과 정렬';

  @override
  String get searchVideosSortTrending => '인기';

  @override
  String get searchVideosSortLoops => '루프 많은 순';

  @override
  String get searchVideosSortEngagement => '반응 많은 순';

  @override
  String get searchVideosSortRecent => '최신순';

  @override
  String get searchListsSectionHeader => '목록';

  @override
  String get searchListsLoadingLabel => '목록 결과 불러오는 중';

  @override
  String get cameraAgeRestriction => '콘텐츠를 만들려면 16세 이상이어야 해요';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker 릴레이는 wss://를 써야 해요 (ws://는 localhost에서만 허용돼요)';

  @override
  String get timeNow => '지금';

  @override
  String timeShortMinutes(int count) {
    return '$count분';
  }

  @override
  String timeShortHours(int count) {
    return '$count시간';
  }

  @override
  String timeShortDays(int count) {
    return '$count일';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count주';
  }

  @override
  String timeShortMonths(int count) {
    return '$count개월';
  }

  @override
  String timeShortYears(int count) {
    return '$count년';
  }

  @override
  String get timeVerboseNow => '지금';

  @override
  String timeAgo(String time) {
    return '$time 전';
  }

  @override
  String get timeToday => '오늘';

  @override
  String get timeYesterday => '어제';

  @override
  String get timeJustNow => '방금';

  @override
  String timeMinutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count시간 전';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count일 전';
  }

  @override
  String get draftTimeJustNow => '방금';

  @override
  String get contentLabelNudity => '노출';

  @override
  String get contentLabelSexualContent => '성적 콘텐츠';

  @override
  String get contentLabelPornography => '포르노';

  @override
  String get contentLabelGraphicMedia => '자극적인 미디어';

  @override
  String get contentLabelViolence => '폭력';

  @override
  String get contentLabelSelfHarm => '자해/자살';

  @override
  String get contentLabelDrugUse => '약물 사용';

  @override
  String get contentLabelAlcohol => '음주';

  @override
  String get contentLabelTobacco => '담배/흡연';

  @override
  String get contentLabelGambling => '도박';

  @override
  String get contentLabelProfanity => '욕설';

  @override
  String get contentLabelHateSpeech => '혐오 발언';

  @override
  String get contentLabelHarassment => '괴롭힘';

  @override
  String get contentLabelFlashingLights => '번쩍이는 빛';

  @override
  String get contentLabelAiGenerated => 'AI 생성';

  @override
  String get contentLabelDeepfake => '딥페이크';

  @override
  String get contentLabelSpam => '스팸';

  @override
  String get contentLabelScam => '사기/사기';

  @override
  String get contentLabelSpoiler => '스포일러';

  @override
  String get contentLabelMisleading => '오해의 소지';

  @override
  String get contentLabelSensitiveContent => '민감한 콘텐츠';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName님이 회원님의 동영상을 좋아해요';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName님이 회원님의 댓글을 좋아해요';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName님이 회원님의 동영상에 댓글을 남겼어요';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName님이 회원님을 팔로우하기 시작했어요';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName님이 회원님을 언급했어요';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName님이 회원님의 동영상을 리포스트했어요';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName님이 새 영상을 게시했습니다';
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
      other: '바인 $count개',
    );
    return '$actorName님이 내 $_temp0를 $listName에 추가했어요';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName님이 회원님의 댓글에 답글을 남겼습니다';
  }

  @override
  String get notificationAndConnector => '및';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '외 $count명',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => '새로운 업데이트가 있어요';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => '키보드 숨기기';

  @override
  String get commentsErrorLoadFailed => '댓글을 불러오지 못했어요';

  @override
  String get commentsErrorNotAuthenticatedComment => '댓글을 쓰려면 로그인하세요';

  @override
  String get commentsErrorPostCommentFailed => '댓글을 올리지 못했어요';

  @override
  String get commentsErrorPostReplyFailed => '답글을 올리지 못했어요';

  @override
  String get commentsErrorEditFailed => '댓글을 수정하지 못했어요';

  @override
  String get commentsErrorNotAuthenticatedInteract => '참여하려면 로그인하세요';

  @override
  String get commentsErrorVoteFailed => '댓글 투표에 실패했어요';

  @override
  String get commentsErrorReportFailed => '댓글을 신고하지 못했어요';

  @override
  String get commentsErrorBlockFailed => '사용자를 차단하지 못했어요';

  @override
  String get commentsErrorDeleteFailed => '댓글을 삭제하지 못했어요';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '댓글 $count개',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => '게시 중…';

  @override
  String get commentsVideoReplyPendingSemanticLabel => '동영상 답글을 게시하는 중입니다';

  @override
  String get commentsSortNew => '최신순';

  @override
  String get commentsSortTop => '인기순';

  @override
  String get commentsSortOld => '오래된순';

  @override
  String get commentsSortSemanticLabel => '댓글 정렬';

  @override
  String get commentReply => '답글';

  @override
  String get commentReplySemanticLabel => '댓글에 답글 달기';

  @override
  String get commentUpvoteLabel => '댓글 추천';

  @override
  String get commentRemoveUpvoteLabel => '추천 취소';

  @override
  String get commentDownvoteLabel => '댓글 비추천';

  @override
  String get commentRemoveDownvoteLabel => '비추천 취소';

  @override
  String get commentsInputHint => '댓글 추가...';

  @override
  String get commentsInputHintEdit => '댓글 수정...';

  @override
  String get commentsEmptyTitle => '아직 댓글이 없어요';

  @override
  String get commentsEmptySubtitle => '첫 댓글을 남겨보세요!';

  @override
  String get draftUntitled => '제목 없음';

  @override
  String get contentWarningNone => '없음';

  @override
  String get textBackgroundNone => '없음';

  @override
  String get textBackgroundSolid => '불투명';

  @override
  String get textBackgroundHighlight => '하이라이트';

  @override
  String get textBackgroundTransparent => '투명';

  @override
  String get textAlignLeft => '왼쪽';

  @override
  String get textAlignRight => '오른쪽';

  @override
  String get textAlignCenter => '가운데';

  @override
  String get cameraPermissionWebUnsupportedTitle => '카메라는 아직 웹에서 지원되지 않습니다';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      '카메라 촬영 및 녹화는 웹 버전에서 아직 사용할 수 없습니다.';

  @override
  String get cameraPermissionBackToFeed => '피드로 돌아가기';

  @override
  String get cameraCouldNotStart => '카메라를 시작할 수 없어요';

  @override
  String get cameraUnsupportedPlatform =>
      '이 플랫폼에서는 아직 카메라를 사용할 수 없어요.\n영상 둘러보기와 재생은 계속할 수 있어요.';

  @override
  String get cameraPermissionErrorTitle => '권한 오류';

  @override
  String get cameraPermissionErrorDescription => '권한을 확인하는 중 문제가 발생했습니다.';

  @override
  String get cameraPermissionRetry => '다시 시도';

  @override
  String get cameraPermissionAllowAccessTitle => '카메라 및 마이크 접근 허용';

  @override
  String get cameraPermissionAllowAccessDescription =>
      '이렇게 하면 앱에서 바로 동영상을 촬영하고 편집할 수 있으며, 그 외 용도는 없습니다.';

  @override
  String get cameraPermissionGoToSettings => '설정으로 이동';

  @override
  String get videoRecorderWhySixSecondsTitle => '왜 6초인가요?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      '짧은 클립은 자발성을 위한 공간을 만듭니다. 6초 형식은 순간이 일어나는 그대로 진정성 있는 순간을 포착하는 데 도움이 됩니다.';

  @override
  String get videoRecorderWhySixSecondsButton => '알겠어요!';

  @override
  String get videoRecorderUploadTitle => '왜 업로드가 없나요?';

  @override
  String get videoRecorderUploadBody =>
      'Divine에서 보는 콘텐츠는 사람이 만든 것입니다. 가공되지 않고 그 순간에 촬영된 것이죠. 고도로 제작되거나 AI로 생성된 업로드를 허용하는 플랫폼과는 달리, 우리는 카메라 직촬 경험의 진정성을 우선시합니다.';

  @override
  String get videoRecorderUploadBodyDetail =>
      '제작을 앱 안에서 유지함으로써, 콘텐츠가 실제이며 편집되지 않았음을 더 잘 보장할 수 있습니다. 그 진정성을 보호하고 커뮤니티를 합성 콘텐츠로부터 최대한 자유롭게 유지하기 위해, 현재로서는 외부 갤러리 업로드를 열어두지 않고 있습니다.';

  @override
  String get videoRecorderUploadBodyCta => '진짜를 찍으려면 Capture나 Classic으로 전환하세요.';

  @override
  String get videoRecorderUploadLearnMore => '검증이 어떻게 작동하는지 알아보기';

  @override
  String get videoRecorderAutosaveFoundTitle => '작업 중인 항목을 찾았습니다';

  @override
  String get videoRecorderAutosaveFoundSubtitle => '중단한 부분에서 계속하시겠어요?';

  @override
  String get videoRecorderAutosaveContinueButton => '네, 계속하기';

  @override
  String get videoRecorderAutosaveDiscardButton => '아니요, 새 동영상 시작';

  @override
  String get videoRecorderAutosaveRestoreFailure => '임시저장을 복원할 수 없습니다';

  @override
  String get videoRecorderStopRecordingTooltip => '녹화 중지';

  @override
  String get videoRecorderStartRecordingTooltip => '녹화 시작';

  @override
  String get videoRecorderRecordingTapToStopLabel => '녹화 중. 아무 곳이나 탭하여 중지';

  @override
  String get videoRecorderTapToStartLabel => '아무 곳이나 탭하여 녹화 시작';

  @override
  String get videoRecorderDeleteLastClipLabel => '마지막 클립 삭제';

  @override
  String get videoRecorderSwitchCameraLabel => '카메라 전환';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return '$zoom×로 확대';
  }

  @override
  String get videoRecorderToggleGridLabel => '그리드 전환';

  @override
  String get videoRecorderToggleGhostFrameLabel => '고스트 프레임 전환';

  @override
  String get videoRecorderGhostFrameEnabled => '고스트 프레임 활성화됨';

  @override
  String get videoRecorderGhostFrameDisabled => '고스트 프레임 비활성화됨';

  @override
  String get videoRecorderClipDeletedMessage => '클립이 휴지통으로 이동되었습니다';

  @override
  String get videoRecorderClipUndoLabel => '실행 취소';

  @override
  String get libraryTrashEmptyTitle => '휴지통이 비어 있습니다';

  @override
  String get libraryTrashEmptySubtitle => '삭제된 클립은 영구 삭제되기 전 30일 동안 여기에 보관됩니다.';

  @override
  String get libraryTrashRestoreLabel => '복원';

  @override
  String get libraryTrashDeleteNowLabel => '지금 삭제';

  @override
  String get libraryTrashEmptyAllLabel => '휴지통 비우기';

  @override
  String get libraryTrashDeleteConfirmTitle => '지금 클립을 삭제할까요?';

  @override
  String get libraryTrashDeleteConfirmMessage => '이 작업은 클립을 휴지통에서 바로 삭제합니다.';

  @override
  String get libraryTrashEmptyConfirmTitle => '휴지통을 비울까요?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클립 $count개',
      one: '클립 1개',
    );
    return '이 작업은 휴지통에서 $_temp0를 바로 영구 삭제합니다.';
  }

  @override
  String get videoRecorderCloseLabel => '동영상 녹화기 닫기';

  @override
  String get videoRecorderContinueToEditorLabel => '동영상 편집기로 계속';

  @override
  String get videoRecorderCameraPreviewLabel => '카메라 미리보기';

  @override
  String get videoRecorderCameraPreviewFocusHint => '카메라 초점 맞추기';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return '$mode 모드로 전환';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => '녹화하기 전에 오디오를 추가하세요';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      '동영상을 만들지 못했습니다. 다시 시도해 주세요.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count컷 남음',
      zero: '남은 컷 없음',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => '플래시 전환';

  @override
  String get videoRecorderCycleTimerLabel => '타이머 전환';

  @override
  String get videoRecorderToggleAspectRatioLabel => '화면 비율 전환';

  @override
  String get videoRecorderStabilizationLabel => '흔들림 보정';

  @override
  String get videoRecorderStabilizationModeOff => '끔';

  @override
  String get videoRecorderStabilizationModeStandard => '표준';

  @override
  String get videoRecorderStabilizationModeCinematic => '시네마틱';

  @override
  String get videoRecorderStabilizationModeCinematicExtended => '시네마틱 확장';

  @override
  String get videoRecorderStabilizationModePreviewOptimized => '미리보기 최적화';

  @override
  String get videoRecorderStabilizationModeLowLatency => '낮은 지연 시간';

  @override
  String get videoRecorderStabilizationModeAuto => '자동';

  @override
  String get videoRecorderFlashValueOff => '끔';

  @override
  String get videoRecorderFlashValueOn => '켬';

  @override
  String get videoRecorderFlashValueAuto => '자동';

  @override
  String get videoRecorderTimerValueOff => '끔';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3초';

  @override
  String get videoRecorderTimerValueTenSeconds => '10초';

  @override
  String get videoRecorderAspectRatioValueSquare => '정사각형';

  @override
  String get videoRecorderAspectRatioValueVertical => '세로';

  @override
  String get videoRecorderCameraValueFront => '전면 카메라';

  @override
  String get videoRecorderCameraValueBack => '후면 카메라';

  @override
  String get videoRecorderLibraryEmptyLabel => '클립 보관함, 클립 없음';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: '클립 보관함 열기, $clipCount개 클립',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: '스톱모션 보관함 열기, $frameCount개 프레임',
      zero: '스톱모션 보관함 열기',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => '카메라';

  @override
  String get videoEditorOpenCameraSemanticLabel => '카메라 열기';

  @override
  String get videoEditorLibraryLabel => '라이브러리';

  @override
  String get videoEditorTextLabel => '텍스트';

  @override
  String get videoEditorDrawLabel => '그리기';

  @override
  String get videoEditorFilterLabel => '필터';

  @override
  String get videoEditorTuneLabel => '조정';

  @override
  String get videoEditorOpenTuneSemanticLabel => '조정 편집기 열기';

  @override
  String get videoEditorTuneBrightness => '밝기';

  @override
  String get videoEditorTuneContrast => '대비';

  @override
  String get videoEditorTuneSaturation => '채도';

  @override
  String get videoEditorTuneExposure => '노출';

  @override
  String get videoEditorTuneHue => '색조';

  @override
  String get videoEditorTuneTemperature => '색온도';

  @override
  String get videoEditorTuneTint => '틴트';

  @override
  String get videoEditorTuneFade => '페이드';

  @override
  String get videoEditorAudioLabel => '오디오';

  @override
  String get videoEditorAddTitle => '추가';

  @override
  String get videoEditorOpenLibrarySemanticLabel => '라이브러리 열기';

  @override
  String get videoEditorOpenAudioSemanticLabel => '오디오 편집기 열기';

  @override
  String get videoEditorCaptionsLabel => '자막';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => '자막 편집기 열기';

  @override
  String get videoEditorCaptionsBurnInLabel => '영상에 새기기';

  @override
  String get videoEditorCaptionsPresetCustom => '사용자';

  @override
  String get videoEditorCaptionsCustomStyleTitle => '사용자 스타일';

  @override
  String get videoEditorCaptionsCustomApply => '적용';

  @override
  String get videoEditorCaptionsCustomFont => '글꼴';

  @override
  String get videoEditorCaptionsCustomTextColor => '글자 색';

  @override
  String get videoEditorCaptionsCustomBackground => '배경';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => '배경색';

  @override
  String get videoEditorCaptionsCustomAnimation => '애니메이션';

  @override
  String get videoEditorCaptionsAnimationNone => '없음';

  @override
  String get videoEditorCaptionsAnimationFade => '페이드';

  @override
  String get videoEditorCaptionsAnimationPop => '팝';

  @override
  String get videoEditorCaptionsAnimationSpring => '스프링';

  @override
  String get videoEditorCaptionsEditTitle => '자막';

  @override
  String get videoEditorCaptionsGeneratingTitle => '음성을 듣고 있어요…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle => '오디오로 자막 제안을 만들고 있어요.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      '음성이 들리지 않았어요. 자막을 직접 작성할 수도 있어요.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      '이 기기에서는 음성 인식을 사용할 수 없어요. 자막을 직접 작성할 수 있어요.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      '음성 인식이 허용되지 않았어요. 설정에서 켜거나 자막을 직접 작성하세요.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      '이번에는 변환이 되지 않았어요. 자막을 직접 작성할 수 있어요.';

  @override
  String get videoEditorCaptionsStartEmptyButton => '자막 직접 쓰기';

  @override
  String get videoEditorCaptionsAddCue => '자막 추가';

  @override
  String get videoEditorCaptionsCueTextHint => '자막 텍스트';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => '자막 삭제';

  @override
  String get videoEditorCaptionsDeleteTrack => '모든 자막 제거';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => '자막을 제거할까요?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      '모든 텍스트와 타이밍이 사라져요.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => '자막 편집기 닫기';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => '자막 확정';

  @override
  String get videoEditorCaptionsPresetTitle => '자막 스타일';

  @override
  String get videoEditorCaptionsPresetClassic => '클래식';

  @override
  String get videoEditorCaptionsPresetPop => '팝';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => '스프링';

  @override
  String get videoEditorCaptionsPresetMono => '모노';

  @override
  String get videoEditorCaptionsPresetHeadline => '헤드라인';

  @override
  String get videoEditorCaptionsPresetTypewriter => '타자기';

  @override
  String get videoEditorCaptionsPresetMarker => '마커';

  @override
  String get videoEditorCaptionsPresetScript => '캘리그래피';

  @override
  String get videoEditorCaptionsPresetRetro => '레트로';

  @override
  String get videoEditorCaptionsPresetElegant => '우아함';

  @override
  String get videoEditorCaptionsPresetBubble => '버블';

  @override
  String get videoEditorCaptionsPresetNeon => '네온';

  @override
  String get videoEditorCaptionsPresetBold => '굵게';

  @override
  String get videoEditorCaptionsPresetDreamy => '몽환';

  @override
  String get videoEditorCaptionsPresetOcean => '오션';

  @override
  String get videoEditorCaptionsPresetSunny => '화창함';

  @override
  String get videoEditorCaptionsPresetHandwritten => '손글씨';

  @override
  String get videoEditorCaptionsPresetSerif => '세리프';

  @override
  String get videoEditorCaptionsPresetStamp => '스탬프';

  @override
  String get videoEditorOpenTextSemanticLabel => '텍스트 편집기 열기';

  @override
  String get videoEditorOpenDrawSemanticLabel => '그리기 편집기 열기';

  @override
  String get videoEditorOpenFilterSemanticLabel => '필터 편집기 열기';

  @override
  String get videoEditorOpenStickerSemanticLabel => '스티커 편집기 열기';

  @override
  String get videoEditorSaveDraftTitle => '임시저장 하시겠어요?';

  @override
  String get videoEditorSaveDraftSubtitle => '편집 내용을 나중에 저장하거나, 버리고 편집기를 나갑니다.';

  @override
  String get videoEditorSaveDraftButton => '임시저장';

  @override
  String get videoEditorDiscardChangesButton => '변경사항 버리기';

  @override
  String get videoEditorKeepEditingButton => '계속 편집';

  @override
  String get videoEditorDeleteLayerDropZone => '레이어 삭제 드롭 영역';

  @override
  String get videoEditorReleaseToDeleteLayer => '놓아서 레이어 삭제';

  @override
  String get videoEditorDoneLabel => '완료';

  @override
  String get videoEditorPlayPauseSemanticLabel => '동영상 재생 또는 일시 정지';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return '분할 위치가 유효하지 않습니다. 각 클립은 최소 ${minDurationMs}ms 이상이어야 합니다.';
  }

  @override
  String get videoEditorSaveSelectedClip => '선택한 클립 저장';

  @override
  String get videoEditorSaveClip => '클립 저장';

  @override
  String get videoEditorClipSavedSuccess => '클립이 보관함에 저장되었습니다';

  @override
  String get videoEditorClipSaveFailed => '클립 저장 실패';

  @override
  String get videoEditorColorPickerSemanticLabel => '색상 선택기';

  @override
  String get videoEditorUndoSemanticLabel => '실행 취소';

  @override
  String get videoEditorRedoSemanticLabel => '다시 실행';

  @override
  String get videoEditorTextColorSemanticLabel => '텍스트 색상';

  @override
  String get videoEditorTextAlignmentSemanticLabel => '텍스트 정렬';

  @override
  String get videoEditorTextBackgroundSemanticLabel => '텍스트 배경';

  @override
  String get videoEditorFontSemanticLabel => '폰트';

  @override
  String get videoEditorNoStickersFound => '스티커를 찾을 수 없음';

  @override
  String get videoEditorNoStickersAvailable => '사용 가능한 스티커 없음';

  @override
  String get videoEditorFailedLoadStickers => '스티커 로드 실패';

  @override
  String get videoEditorVoiceOverLabel => '내레이션';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return '녹음 $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => '내레이션 녹음';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => '녹음 시작';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => '녹음 중지';

  @override
  String get videoEditorVoiceOverHint => '탭하여 녹음하세요. 원하는 만큼 테이크를 추가할 수 있어요.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '녹음 $count개',
      one: '녹음 1개',
      zero: '아직 녹음이 없습니다',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => '마지막 녹음 삭제';

  @override
  String get videoEditorVoiceOverPermissionTitle => '마이크 접근 권한이 필요합니다';

  @override
  String get videoEditorVoiceOverPermissionBody => '내레이션을 녹음하려면 마이크 접근을 허용하세요.';

  @override
  String get videoEditorVoiceOverOpenSettings => '설정 열기';

  @override
  String get videoEditorVoiceOverRecordingStarted => '녹음 시작됨';

  @override
  String get videoEditorVoiceOverRecordingSaved => '녹음 저장됨';

  @override
  String get videoEditorVoiceOverTooLong => '녹음이 동영상보다 깁니다';

  @override
  String get videoEditorPlaySemanticLabel => '재생';

  @override
  String get videoEditorPauseSemanticLabel => '일시 정지';

  @override
  String get videoEditorVolumeSemanticLabel => '볼륨 조절';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return '볼륨 $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => '슬라이드하여 조절';

  @override
  String get videoEditorChromaKeyLabel => '크로마키';

  @override
  String get videoEditorChromaKeyTitle => '크로마키';

  @override
  String get videoEditorChromaKeySemanticLabel => '이 클립의 크로마키 설정';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel => '크로마키 변경 사항 취소';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => '크로마키 적용';

  @override
  String get videoEditorChromaKeyAutoDetect => '자동 감지';

  @override
  String get videoEditorChromaKeyPresetGreen => '초록';

  @override
  String get videoEditorChromaKeyPresetBlue => '파랑';

  @override
  String get videoEditorChromaKeyScreenColorLabel => '배경 색';

  @override
  String get videoEditorChromaKeyAmountLabel => '강도';

  @override
  String get videoEditorChromaKeyAmountHint => '배경 색이 얼마나 지워질지';

  @override
  String get videoEditorChromaKeyEdgeLabel => '가장자리';

  @override
  String get videoEditorChromaKeyEdgeHint => '잘린 부분을 부드럽게 해 머리카락이 거칠어지지 않게 합니다';

  @override
  String get videoEditorChromaKeySpillLabel => '색 번짐';

  @override
  String get videoEditorChromaKeySpillHint => '배경 색을 피사체에서 걷어냅니다';

  @override
  String get videoEditorChromaKeyBackgroundLabel => '이걸로 바꾸기';

  @override
  String get videoEditorChromaKeyBackgroundNone => '없음';

  @override
  String get videoEditorChromaKeyBackgroundColor => '색';

  @override
  String get videoEditorChromaKeyBackgroundImage => '이미지';

  @override
  String get videoEditorChromaKeyBackgroundVideo => '클립';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      '영상은 투명도를 담을 수 없어서 내보내면 검게 나옵니다.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      '배경을 찾지 못했습니다. 화면 가장자리까지 닿아야 해요. 아니면 색을 직접 고르세요.';

  @override
  String get videoEditorChromaKeyPickClipTitle => '클립 고르기';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      '보관함이 비어 있어요. 클립을 먼저 저장하면 배경으로 쓸 수 있습니다.';

  @override
  String get videoEditorChromaKeyImagePickFailed => '그 이미지를 불러오지 못했습니다.';

  @override
  String get videoEditorChromaKeyRemove => '크로마키 제거';

  @override
  String get videoEditorChromaKeyFailed => '크로마키를 적용하지 못했습니다. 클립은 그대로입니다.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      '크로마키를 제거하지 못했습니다. 클립은 그대로입니다.';

  @override
  String get videoEditorChromaKeyApplying => '크로마키를 적용하는 중…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      '이 기기에서는 실시간 미리보기를 표시할 수 없습니다. 설정은 내보낼 때 그대로 적용됩니다.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return '클립 $index';
  }

  @override
  String get videoEditorDeleteLabel => '삭제';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => '선택한 항목 삭제';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => '이미지당 프레임';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count프레임',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => '프레임';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '이미지당 $count프레임';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return '스톱모션 프레임 $total개 중 $position개';
  }

  @override
  String get videoEditorEditLabel => '편집';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => '선택한 항목 편집';

  @override
  String get videoEditorDuplicateLabel => '복제';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel => '선택한 항목 복제';

  @override
  String get videoEditorCombineLabel => '합치기';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      '선택한 그림을 하나의 레이어로 합치기';

  @override
  String get videoEditorSplitLabel => '분할';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => '선택한 클립 분할';

  @override
  String get videoEditorExtractAudioLabel => '오디오 추출';

  @override
  String get videoEditorClipAudioTitle => '클립 오디오';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      '클립에서 오디오를 추출하고 원본을 음소거';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      '오디오를 추출할 수 없습니다: 클립이 로컬에서 사용할 수 없습니다.';

  @override
  String get videoEditorExtractAudioFailed => '오디오를 추출할 수 없었습니다. 다시 시도해 주세요.';

  @override
  String get videoEditorSpeedLabel => '속도';

  @override
  String get videoEditorSetClipSpeedSemanticLabel => '선택한 클립의 재생 속도 설정';

  @override
  String get videoEditorReverseLabel => '역재생';

  @override
  String get videoEditorReverseClipSemanticLabel => '선택한 클립의 역방향 재생 전환';

  @override
  String get videoEditorReverseProgressLabel => '잠시만요. 클립을 역재생으로 변환하고 있어요';

  @override
  String get videoEditorTransformLabel => '변형';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      '선택한 클립 자르기, 회전 또는 뒤집기';

  @override
  String get videoEditorTransformProgressLabel => '잠시만요, 클립을 변형하고 있어요';

  @override
  String get videoEditorTransformFailed => '클립을 변형할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get videoEditorTransformNoLocalFile =>
      '변형할 수 없음: 클립을 로컬에서 사용할 수 없습니다.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      '선택한 프레임 자르기, 회전 또는 뒤집기';

  @override
  String get videoEditorTransformFrameProgressLabel => '잠시만요, 프레임을 변환하고 있어요';

  @override
  String get videoEditorTransformFrameFailed => '프레임을 변환하지 못했어요. 다시 시도해 주세요.';

  @override
  String get videoEditorTransformRotateLabel => '회전';

  @override
  String get videoEditorTransformFlipLabel => '뒤집기';

  @override
  String get videoEditorTransformResetLabel => '재설정';

  @override
  String get videoEditorTransformApplySemanticLabel => '변형 적용';

  @override
  String get videoEditorTransformCancelSemanticLabel => '변형 취소';

  @override
  String get videoEditorTransformPlayLabel => '재생';

  @override
  String get videoEditorTransformPauseLabel => '일시정지';

  @override
  String get videoEditorReverseNoLocalFile =>
      '역재생할 수 없습니다: 클립이 로컬에서 사용할 수 없습니다.';

  @override
  String get videoEditorReverseFailed => '클립을 역재생할 수 없었습니다. 다시 시도해 주세요.';

  @override
  String get videoEditorSpeedSheetTitle => '클립 속도';

  @override
  String get videoEditorTransitionSheetTitle => '전환';

  @override
  String get videoEditorTransitionNone => '없음';

  @override
  String get videoEditorTransitionDissolve => '디졸브';

  @override
  String get videoEditorTransitionFadeToBlack => '검은색으로 페이드';

  @override
  String get videoEditorTransitionFadeToWhite => '흰색으로 페이드';

  @override
  String get videoEditorTransitionSlide => '슬라이드';

  @override
  String get videoEditorTransitionPush => '밀기';

  @override
  String get videoEditorTransitionWipe => '와이프';

  @override
  String get videoEditorTransitionButtonSemanticLabel => '전환 편집';

  @override
  String get videoEditorLoopTransitionSheetTitle => '루프 전환';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel => '루프 전환 편집';

  @override
  String get videoEditorTransitionDuration => '길이';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      '인접한 전환과 겹치지 않도록 길이가 제한되었습니다.';

  @override
  String get videoEditorTransitionCurve => '커브';

  @override
  String get videoEditorTransitionDirection => '방향';

  @override
  String get videoEditorTransitionDirectionLeft => '왼쪽';

  @override
  String get videoEditorTransitionDirectionRight => '오른쪽';

  @override
  String get videoEditorTransitionDirectionUp => '위';

  @override
  String get videoEditorTransitionDirectionDown => '아래';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return '애니메이션 곡선 $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => '애니메이션';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel => '레이어 애니메이션 편집';

  @override
  String get videoEditorLayerAnimationEnter => '등장';

  @override
  String get videoEditorLayerAnimationLeave => '퇴장';

  @override
  String get videoEditorLayerAnimationFade => '페이드';

  @override
  String get videoEditorLayerAnimationScale => '크기';

  @override
  String get videoEditorLayerAnimationScaleFrom => '시작 크기';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel => '타임라인 편집 완료';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => '미리보기 재생';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => '미리보기 일시 정지';

  @override
  String get videoEditorAudioUntitledSound => '제목 없는 사운드';

  @override
  String get videoEditorAudioUntitled => '제목 없음';

  @override
  String get videoEditorAudioAddAudio => '오디오 추가';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => '사용 가능한 사운드 없음';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      '크리에이터가 오디오를 공유하면 여기에 표시됩니다';

  @override
  String get videoEditorAudioFailedToLoadTitle => '사운드 로드 실패';

  @override
  String get videoEditorAudioSegmentInstruction => '동영상에 사용할 오디오 구간을 선택하세요';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => '커뮤니티';

  @override
  String get videoEditorAudioCategoryFeatured => '추천';

  @override
  String get videoEditorAudioCategoryMySounds => '내 사운드';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => '화살표 도구';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => '지우개 도구';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => '마커 도구';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => '연필 도구';

  @override
  String get videoEditorShowTimelineSemanticLabel => '타임라인 표시';

  @override
  String get videoEditorHideTimelineSemanticLabel => '타임라인 숨기기';

  @override
  String get videoEditorFeedPreviewContent => '이 영역 뒤에 콘텐츠를 배치하지 마세요.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine 오리지널';

  @override
  String get videoEditorStickerSearchHint => '스티커 검색...';

  @override
  String get videoEditorSelectFontSemanticLabel => '폰트 선택';

  @override
  String get videoEditorFontUnknown => '알 수 없음';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      '분할하려면 재생 헤드가 선택한 클립 안에 있어야 합니다.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => '시작 트림';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => '끝 트림';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => '클립 트림';

  @override
  String get videoEditorTimelineTrimClipHint => '핸들을 드래그하여 클립 길이 조정';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return '클립 $index 드래그 중';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return '클립 $total개 중 $index번째, $duration초';
  }

  @override
  String get videoEditorTimelineClipReorderHint => '길게 눌러 순서 변경';

  @override
  String get videoEditorTimelineClipMoveLeft => '왼쪽으로 이동';

  @override
  String get videoEditorTimelineClipMoveRight => '오른쪽으로 이동';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return '클립 $index/$total, 선택됨';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return '클립 $index/$total, 선택 안 됨';
  }

  @override
  String get videoEditorMultiSelectLabel => '선택';

  @override
  String get videoEditorMultiSelectSemanticLabel => '여러 클립 선택';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => '선택 완료';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클립 $count개 선택됨',
      one: '클립 1개 선택됨',
      zero: '선택된 클립 없음',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel => '여러 그림 선택';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel => '그림 선택 완료';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel => '선택한 그림 삭제';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '그림 $count개 선택됨',
      one: '그림 1개 선택됨',
      zero: '선택된 그림 없음',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => '병합';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel => '선택한 클립 병합';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel => '선택한 클립 삭제';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel => '선택한 프레임 삭제';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel => '선택한 프레임 순서 뒤집기';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel => '선택한 프레임 복제';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return '영상은 최소 $seconds초여야 해요. 프레임을 몇 장 더 찍어 주세요.';
  }

  @override
  String get videoEditorMergeProgressLabel => '잠시만요, 클립을 병합하고 있어요';

  @override
  String get videoEditorMergeFailed => '클립을 병합할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get videoEditorTimelineLongPressToDragHint => '길게 눌러 드래그';

  @override
  String get videoEditorVideoTimelineSemanticLabel => '동영상 타임라인';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes분 $seconds초';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, 선택됨';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => '색상 선택기 닫기';

  @override
  String get videoEditorPickColorTitle => '색상 선택';

  @override
  String get videoEditorConfirmColorSemanticLabel => '색상 확인';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => '채도 및 밝기';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return '채도 $saturation%, 밝기 $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => '색조';

  @override
  String get videoEditorAddElementSemanticLabel => '요소 추가';

  @override
  String get videoEditorDoneSemanticLabel => '완료';

  @override
  String get videoEditorLevelSemanticLabel => '레벨';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel => '게시물 세부 정보 닫기';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => '도움말 대화상자 닫기';

  @override
  String get videoMetadataGotItButton => '알겠어요!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB 제한에 도달했습니다. 계속하려면 일부 콘텐츠를 삭제하세요.';

  @override
  String get videoMetadataExpirationLabel => '만료';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => '만료 시간 선택';

  @override
  String get videoMetadataTitleLabel => '제목';

  @override
  String get videoMetadataDescriptionLabel => '설명';

  @override
  String get videoMetadataTagsLabel => '태그';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return '태그 $tag 삭제';
  }

  @override
  String get videoMetadataContentWarningLabel => '콘텐츠 경고';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel => '콘텐츠 경고 선택';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      '콘텐츠에 해당하는 것을 모두 선택';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      '다른 사람들이 이 동영상의 오디오를 저장하고 재사용할 수 있도록 합니다.';

  @override
  String get publishAudioReuseDegradedWarning =>
      '영상은 올라갔지만 사운드는 게시되지 않았어요. 공유하려면 영상을 편집하세요.';

  @override
  String get videoMetadataCollaboratorsLabel => '협업자';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => '협업자 추가';

  @override
  String get videoMetadataMutualFollowersSearchText => '맞팔 팔로워';

  @override
  String get videoMetadataInspiredByLabel => '영감 출처';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => '영감 출처 설정';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      '이 크리에이터는 참조할 수 없습니다.';

  @override
  String get videoMetadataPostDetailsTitle => '게시물 세부 정보';

  @override
  String get videoMetadataSavedToLibrarySnackbar => '보관함에 저장되었습니다';

  @override
  String get videoMetadataFailedToSaveSnackbar => '저장 실패';

  @override
  String get videoMetadataGoToLibraryButton => '보관함으로 이동';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => '나중에 저장 버튼';

  @override
  String get videoMetadataSavingVideoHint => '동영상 저장 중...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return '동영상을 임시저장 및 $destination에 저장';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return '동영상을 임시보관함에 저장합니다. 아직 렌더링된 동영상이 없어 $destination에는 복사되지 않습니다.';
  }

  @override
  String get videoMetadataSaveForLaterButton => '나중에 저장';

  @override
  String get videoMetadataPostSemanticLabel => '게시 버튼';

  @override
  String get videoMetadataPublishVideoHint => '피드에 동영상 게시';

  @override
  String get videoMetadataShareReplyToFeedTitle => '내 피드에도 공유';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      '끔으로 두면 이 동영상은 댓글 스레드에만 남습니다.';

  @override
  String get videoMetadataFormNotReadyHint => '활성화하려면 양식을 작성하세요';

  @override
  String get videoMetadataPostButton => '게시';

  @override
  String get videoMetadataOpenPreviewSemanticLabel => '게시물 미리보기 화면 열기';

  @override
  String get videoMetadataShareTitle => '공유';

  @override
  String get videoMetadataVideoDetailsSubtitle => '동영상 세부 정보';

  @override
  String get videoMetadataClassicDoneButton => '완료';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => '미리보기 재생';

  @override
  String get videoMetadataPausePreviewSemanticLabel => '미리보기 일시 정지';

  @override
  String get videoMetadataClosePreviewSemanticLabel => '동영상 미리보기 닫기';

  @override
  String get videoMetadataRemoveSemanticLabel => '삭제';

  @override
  String get fullscreenFeedRemovedMessage => '동영상이 삭제됐어요';

  @override
  String get fullscreenFeedEmptyMessage => '여기에 재생할 영상이 더 없어요';

  @override
  String get settingsBadgesTitle => '배지';

  @override
  String get settingsBadgesSubtitle => '받은 배지를 수락하고 발급한 배지 상태를 확인해요.';

  @override
  String get badgesTitle => '배지';

  @override
  String get badgesLoadError => '배지를 불러오지 못했어요';

  @override
  String get badgesUpdateError => '배지를 업데이트하지 못했어요';

  @override
  String get badgesAwardedEmptyTitle => '아직 받은 배지가 없어요';

  @override
  String get badgesAwardedEmptySubtitle => '누가 Nostr 배지를 보내면 여기에 표시돼요.';

  @override
  String get badgesStatusAccepted => '수락됨';

  @override
  String get badgesStatusNotAccepted => '수락 안 함';

  @override
  String get badgesActionRemove => '제거';

  @override
  String get badgesActionAccept => '수락';

  @override
  String get badgesActionReject => '거절';

  @override
  String get badgesIssuedEmptyTitle => '아직 발급한 배지가 없어요';

  @override
  String get badgesIssuedEmptySubtitle => '발급한 배지는 여기에서 수락 상태를 보여줘요.';

  @override
  String get badgesIssuedNoRecipients => '이 배지에 대한 수령자를 찾지 못했어요.';

  @override
  String get badgesRecipientAcceptedStatus => '수령자가 수락했어요';

  @override
  String get badgesRecipientWaitingStatus => '수령자를 기다리는 중';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '숨김 ($count)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => '복원';

  @override
  String get badgesHiddenSnackbar => '배지를 숨겼어요';

  @override
  String get badgesHiddenSnackbarUndo => '실행 취소';

  @override
  String get badgesTabAwarded => '받은 배지';

  @override
  String get badgesTabCreated => '만든 배지';

  @override
  String get badgesTabIssued => '준 배지';

  @override
  String get badgesCreateAction => '새 배지';

  @override
  String get badgesCreatedEmptyTitle => '아직 만든 배지가 없어요';

  @override
  String get badgesCreatedEmptySubtitle => '하나 만들어서 받을 자격이 있는 사람에게 주세요.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명에게 줬어요',
      zero: '아직 준 사람이 없어요',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => '새 배지';

  @override
  String get badgeEditorEditTitle => '배지 수정';

  @override
  String get badgeEditorNameLabel => '이름';

  @override
  String get badgeEditorNameHint => '장면 도둑';

  @override
  String get badgeEditorIdentifierLabel => '식별자';

  @override
  String get badgeEditorIdentifierHelp => '배지 주소의 일부라서, 배지를 만든 뒤에는 바꿀 수 없어요.';

  @override
  String get badgeEditorIdentifierTaken =>
      '이 식별자를 쓰는 배지가 이미 있어요. 여기서 게시하면 덮어쓰니 그 배지를 수정해 주세요.';

  @override
  String get badgeEditorIdentifierRequired =>
      '배지에는 식별자가 필요해요. 이름으로 채워지지 않았다면 직접 입력해 주세요.';

  @override
  String get badgeEditorDescriptionLabel => '설명';

  @override
  String get badgeEditorDescriptionHint => '단 하나의 루프로 시선을 훔친 사람에게.';

  @override
  String get badgeEditorArtworkLabel => '이미지';

  @override
  String get badgeEditorArtworkAdd => '이미지 추가';

  @override
  String get badgeEditorArtworkReplace => '교체';

  @override
  String get badgeEditorArtworkError => '그 이미지를 올리지 못했어요';

  @override
  String get badgeEditorArtworkRequired => '배지에는 이미지가 꼭 필요해요.';

  @override
  String get badgeEditorArtworkRemove => '이미지 삭제';

  @override
  String get badgeEditorArtworkSheetTitle => '배지 이미지';

  @override
  String get badgeDetailDeleteAction => '배지 삭제';

  @override
  String get badgeDetailDeleteTitle => '이 배지를 삭제할까요?';

  @override
  String get badgeDetailDeleteBody =>
      '릴레이에 배지와 당신이 준 모든 수여 기록을 지워 달라고 요청해요. 릴레이는 거절할 수 있고, 프로필에 고정한 사람은 직접 뺄 때까지 계속 갖고 있어요.';

  @override
  String get badgeDetailDeleteConfirm => '삭제';

  @override
  String get badgeEditorSaveAction => '배지 게시';

  @override
  String get badgeEditorSaveError => '배지를 게시하지 못했어요';

  @override
  String get badgeEditorLoadError => '이 배지를 불러오지 못했어요';

  @override
  String get badgeDetailTitle => '배지';

  @override
  String get badgeDetailMadeBy => '만든 사람';

  @override
  String get badgeDetailRecipientsTitle => '받은 사람';

  @override
  String get badgeDetailNoRecipients => '아직 아무도 갖고 있지 않아요.';

  @override
  String get badgeDetailAwardAction => '이 배지 주기';

  @override
  String get badgeDetailEditAction => '배지 수정';

  @override
  String get badgeDetailShareAction => '공유';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Divine에서 이 배지를 확인해 보세요: $link';
  }

  @override
  String get badgeDetailRevokeAction => '배지 회수';

  @override
  String get badgeDetailRevokeTitle => '이 배지를 회수할까요?';

  @override
  String get badgeDetailRevokeBody =>
      '이 사람에게 준 수여 기록을 지워 달라고 릴레이에 요청해요. 릴레이는 거절할 수 있고, 이미 프로필에 고정했다면 직접 뺄 때까지 그대로 남아요. 어느 쪽이든 알림은 가지 않아요.';

  @override
  String get badgeDetailRevokeSelfBody =>
      '자기 자신에게 준 수여 기록을 지워 달라고 릴레이에 요청하고, 배지를 프로필에서 내려요. 릴레이가 삭제를 거절하면 아무것도 바뀌지 않아요.';

  @override
  String get badgeDetailRevokeConfirm => '회수';

  @override
  String get badgeDetailRevokeSuccess => '배지를 회수했어요';

  @override
  String get badgeDetailBlockClaimantsAction => '배지 주장 계정 차단';

  @override
  String get badgeDetailBlockClaimantsTitle => '배지 주장 계정 차단';

  @override
  String get badgeDetailBlockClaimantsLoadError => '이 배지를 주장한 계정을 불러올 수 없었습니다';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle => '지금 이 배지를 주장한 사람이 없습니다';

  @override
  String get badgeDetailBlockClaimantsEmptyBody => '차단할 현재 주장 계정을 찾지 못했습니다.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명을 차단할까요?',
      one: '1명을 차단할까요?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '지금 이 배지를 주장한 $count개 계정을 차단합니다. 해당 게시물은 내 피드에서 사라지고 알림은 가지 않습니다.',
      one: '지금 이 배지를 주장한 계정을 차단합니다. 해당 게시물은 내 피드에서 사라지고 알림은 가지 않습니다.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 계정 차단',
      one: '1개 계정 차단',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => '배지 주장 계정을 차단했습니다';

  @override
  String get badgeDetailBlockClaimantsFailure => '배지 주장 계정을 차단할 수 없었습니다';

  @override
  String get badgeDetailLoadError => '이 배지를 불러오지 못했어요';

  @override
  String get badgeDetailMissing => '어떤 릴레이에서도 이 배지를 찾을 수 없어요.';

  @override
  String get badgeDetailActionError => '처리하지 못했어요';

  @override
  String get badgeAwardTitle => '배지 주기';

  @override
  String get badgeAwardPickAction => '사람 고르기';

  @override
  String get badgeAwardManualLabel => '또는 키 붙여넣기';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => '최소 한 명은 골라 주세요.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명에게 주기',
      zero: '배지 주기',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => '준 사람';

  @override
  String get profileBadgeRecipients => '받은 사람';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '외 $count명';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name 배지';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => '배지';

  @override
  String get profileBadgeFooterBody =>
      '배지는 Nostr에서 누구나 만들 수 있는 작은 상이에요. 친구나 크리에이터, 오늘 하루를 즐겁게 해준 사람에게 하나 보내보세요.';

  @override
  String get profileBadgeFooterLink => '내 배지 만들기';

  @override
  String get minorAccountReviewWelcomePageTitle => '가족 가이드';

  @override
  String get minorAccountReviewWelcomeTitle => '아직 16세가 아닌가요? 괜찮아요.';

  @override
  String get minorAccountReviewWelcomeBody =>
      '그냥 통과되는 답을 고르는 대신 이 페이지까지 눌러서 들어온 건 의미가 있어요. 정직함과 소신, 그리고 주변 사람들을 진짜로 생각하는 마음을 보여주니까요.\n\n16세 미만에 적용되는 규칙은 사는 곳에 따라 달라요. Divine은 가족이 함께 이야기 나누고, 건강한 소셜 미디어 사용이 어떤 모습인지 같이 정하길 바라요.';

  @override
  String get minorAccountReviewModerationTitle => '한 단계가 더 필요해요';

  @override
  String get minorAccountReviewModerationBody =>
      '이 계정이 16세 미만인 분의 것일 수 있어 자세히 살펴봐 달라는 요청을 받았어요. 이 절차는 다음 단계를 비공개로 유지하고, 나이에 맞는 길을 안내합니다.';

  @override
  String get minorAccountReviewRulesTitle => '규칙은 어디서나 같지 않아요';

  @override
  String get minorAccountReviewRulesBody =>
      '나라와 지역마다 청소년의 소셜 미디어 이용을 다르게 다룹니다. 그래서 가족이 잠시 멈추고 사실을 확인한 뒤 다음 단계를 함께 정하시길 부탁드려요.';

  @override
  String get minorAccountReviewApproachTitle => 'Divine의 생각';

  @override
  String get minorAccountReviewApproachBody =>
      '건강한 기술 습관은 잠시 멈추고, 돌아보고, 더 나은 것으로 관심을 돌리는 데서 나온다고 믿어요. 아이를 감시하거나 부모를 감독관으로 만드는 데서 나오지 않습니다. 연구 결과도 이를 뒷받침해요.';

  @override
  String get minorAccountReviewLearnMoreTitle => '가족을 위한 더 많은 정보';

  @override
  String get minorAccountReviewKidsPolicyCta => 'Divine의 어린이 정책 읽기';

  @override
  String get minorAccountReviewChooseAgeBandTitle => '맞는 경로를 선택하세요';

  @override
  String get minorAccountReviewUnder13Cta => '13세 미만';

  @override
  String get minorAccountReviewTeenCta => '13~15세';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      '청소년이 소셜 미디어를 더 안전하게 쓰도록 돕는 실용적인 팁, 대화 도구, 자료는 Divine 가족 가이드에서 확인하세요.';

  @override
  String get minorAccountReviewFamilyResourcesCta => '가족 가이드와 팁 보기';

  @override
  String get minorAccountReviewFooter =>
      '16세 이상인데 실수로 여기까지 오셨다면 Divine 지원팀에 연락해 주세요. 담당자가 직접 확인합니다.';

  @override
  String get minorAccountReviewTitle => '계정 검토';

  @override
  String get minorAccountReviewCheckingStatusTitle => '계정 상태 확인 중...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      '이 계정의 현재 검토 상태를 확인하는 동안 잠시 기다려 주세요.';

  @override
  String get minorAccountReviewDefaultTitle => '계정 검토가 필요해요';

  @override
  String get minorAccountReviewDefaultBody =>
      '이 계정이 Divine을 정상적으로 이용하려면 먼저 검토가 필요합니다.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return '케이스 ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => '케이스 ID';

  @override
  String get minorAccountReviewRestrictionsTitle => '지금 제한된 것';

  @override
  String get minorAccountReviewRestrictionPosting => '게시와 공개가 중단됨';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      '댓글, 좋아요, 리포스트, 팔로우가 중단됨';

  @override
  String get minorAccountReviewRestrictionMessaging => '일반 메시지 보내기와 답장이 중단됨';

  @override
  String get minorAccountReviewRestrictionSupport => '지원과 검수 메시지는 계속 이용 가능';

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
  String get minorAccountReviewOpenSupportCenter => '지원 센터 열기';

  @override
  String get minorAccountReviewOpenModerationMessage => '검수 메시지 열기';

  @override
  String get minorAccountReviewOpenReviewPage => '검토 페이지 열기';

  @override
  String get minorAccountReviewCheckAgain => '다시 확인';

  @override
  String get minorAccountReviewLogOut => '로그아웃';

  @override
  String get minorAccountReviewNextStepTitle => '다음 단계';

  @override
  String get minorAccountReviewNextStepBody =>
      '이 검토에 도움이 필요하면 지원 센터나 검수 메시지를 열어보세요.';

  @override
  String get minorAccountReviewInProgressTitle => '검토 진행 중';

  @override
  String get minorAccountReviewInProgressBody =>
      '지금 필요한 자료는 받았어요. 계정을 정상적으로 되돌리기 전에 팀이 이 케이스를 검토하고 있습니다.';

  @override
  String get minorAccountReviewUnder13Title => '13세 미만 계정';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return '이 계정이 13세 미만인 분의 것이라면, 부모님이나 보호자가 $supportEmail로 이메일을 보내면서 케이스 ID를 함께 적어주셔야 해요.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle => '아직 계정을 드릴 수 없어요';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine은 13세 미만 어린이를 위해 만들어지지 않았고, 전 세계의 소셜 미디어 규칙도 이를 허용하지 않아요.\n\n인터넷에는 원하는 것을 얻기 위해 거짓말하도록 부추기는 것이 많은데, 우리는 그게 싫습니다. 인생에 잘못된 교훈이고, 여기서 그걸 가르치지는 않을 거예요.';

  @override
  String get minorAccountReviewUnder13FamilyTitle => '대신 가족이 할 수 있는 일';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      '부모님이나 보호자가 계정을 만들어 게시할 수 있고, 여러분도 함께 영상에 나와도 전혀 문제없어요. 가족마다 맞는 방식으로 Divine을 즐기셨으면 합니다.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => '13세가 되면';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      '사는 곳의 규칙에 따라 다시 돌아와 본인 계정을 신청할 수 있어요. 그때 13~15세라면 부모님이나 보호자의 동의가 필요합니다.';

  @override
  String get minorAccountReviewUnder13HonestyTitle => '그냥 뒤로 가라고 하지 않는 이유';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      '인터넷의 많은 곳은 관문을 통과하려고 아무 말이나 하면 보상을 주도록 설계돼 있어요. 우리는 그게 좋다고 생각하지 않아요. 물론 뒤로 가서 실제보다 나이가 많다고 말할 수도 있지만, 그건 정직하지 않고, 우리는 당신이 원하는 걸 얻으려고 거짓말하도록 부추기지 않을 거예요.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      '우리는 젊은 사람들이 자신과 주변 사람들에게 건강하고 긍정적인 방식으로 Divine을 쓰도록 돕고 있어요. 또 우리는 지역마다 다른 법을 따라야 해요. 그래서 13세 미만이라면, 오늘은 본인의 계정을 가질 수 없다는 게 답이에요.';

  @override
  String get minorAccountReviewTeenBody =>
      '이 계정이 13~15세인 분의 것이라면, 검수 메시지나 지원 경로를 통해 보호자 동의 안내를 따르세요.';

  @override
  String get minorAccountReviewParentConsentTitle => '계정이 13~15세인 분의 것이 될 경우';

  @override
  String get minorAccountReviewParentConsentBody =>
      '부모님이나 보호자가 짧은 비공개 영상을 첨부해 Divine 지원팀에 이메일을 보내주세요. 팀이 검토한 뒤 다음 단계를 도와드릴게요.\n\n부모님이나 보호자에게 연락하기 어렵거나, 연락이 누군가를 위험에 빠뜨릴 수 있다면 Divine 지원팀에 이메일로 알려주세요.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Divine 지원팀이 영상을 검토하는 동안 잠시 멈추는 거예요. 승인되면 새 계정을 설정하는 과정을 안내해 드릴게요.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      '부모님이나 보호자의 참여를 요청하는 이유';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine은 전 세계의 연령 관련 법을 따라야 해요. 또 대부분의 기술적 연령 관문이 완벽하지 않다는 것도 알아요. 규칙이 없는 척하거나 나이를 속이는 게 멋진 척하기보다는, 십 대와 가족이 Divine을 어떻게 쓰는 게 가장 좋을지 신중하게 결정하기를 바라요. 그래서 13~15세라면 계정 생성 과정에 부모님이 함께하도록 요청해요.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      '우리는 법도 따라야 하는데, 그 규칙은 사는 곳에 따라 달라요. 그래서 규칙이 없는 척하는 대신, 부모님이나 보호자가 이 과정에 함께하도록 요청해요.';

  @override
  String get minorAccountReviewParentConsentChecklist => '영상에 담겨야 할 내용';

  @override
  String get minorAccountReviewParentConsentChecklistKid => '영상 속 청소년 본인';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      '카메라 앞에서 말하는 부모님 또는 보호자';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      '청소년이 13~15세이며 Divine 이용 허락을 받았다는 명확한 진술';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      '부모님 또는 보호자가 계정을 알고 있으며 이용을 지켜보겠다는 명확한 진술';

  @override
  String get minorAccountReviewParentConsentPrivacy => '보내는 방법';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Divine 지원팀에 이메일을 보낼 때 영상을 첨부하세요';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      '영상은 비공개로 두고 앱에 올리지 마세요';

  @override
  String get minorAccountReviewParentConsentOneMove => '팀이 검토한 뒤 다음 단계를 안내드릴게요';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Divine 지원팀에 이메일 보내기';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine Greenlight 검토 문의 (13~15세)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Divine 지원팀께,\n\n13~15세 청소년과 관련해 Divine Greenlight 건으로 연락드립니다.\n\n다음 내용이 담긴 짧은 비공개 영상을 첨부했습니다:\n- 청소년 본인\n- 카메라 앞에서 말하는 부모님 또는 보호자\n- 청소년이 Divine 이용 허락을 받았다는 점\n- 부모님 또는 보호자가 계정을 알고 있으며 이용을 지켜보겠다는 점\n\n거주 국가:\n\n참고 사항:\n\n감사합니다.';

  @override
  String get minorAccountReviewParentSupportInstructions => '보호자 지원 안내';

  @override
  String get minorAccountReviewContinue => '계속';

  @override
  String get minorAccountReviewErrorTitle => '계정 검토 상태를 불러오지 못했어요.';

  @override
  String get minorAccountReviewErrorBody => '잠시 후 다시 시도해 주세요.';

  @override
  String get minorAccountReviewTryAgain => '다시 시도';

  @override
  String get minorAccountReviewParentContactTitle => '보호자 연락처';

  @override
  String get minorAccountReviewParentContactHeading => '부모님 또는 보호자 이메일 추가';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return '이 주소는 케이스 $caseId의 보호자 동의 검토에 사용됩니다.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel => '부모님 또는 보호자 이메일';

  @override
  String get minorAccountReviewSubmitting => '보내는 중...';

  @override
  String get minorAccountReviewSubmitEmail => '이메일 보내기';

  @override
  String get minorAccountReviewBackToReview => '계정 검토로 돌아가기';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => '이메일을 보냈어요';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return '$email을(를) 검토에 제출했어요. 확인을 위해 이 주소로 메일을 보낼게요. 부모님이나 보호자가 답변하면 케이스가 다음 단계로 넘어갑니다. 최신 상황은 계정 검토 화면의 ‘다시 확인’에서 볼 수 있어요.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      '이 계정의 보호자 연락처를 받았어요. 접근을 복구하기 전에 팀이 검토할 예정입니다.';

  @override
  String get minorAccountReviewMissingCase => '이 계정에 진행 중인 검토 케이스를 찾지 못했어요.';

  @override
  String get minorAccountReviewParentContactError =>
      '보호자 이메일을 보내지 못했어요. 다시 시도해 주세요.';

  @override
  String get minorAccountReviewUnder13SupportTitle => '보호자 지원';

  @override
  String get minorAccountReviewUnder13Heading => '부모님 또는 보호자가 Divine에 연락해야 해요';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      '13세 미만으로 보이는 계정은 다음 단계가 부모님 또는 보호자의 이메일 연락입니다.';

  @override
  String get minorAccountReviewSupportEmailLabel => '지원 이메일';

  @override
  String get minorAccountReviewCopySupportEmail => '지원 이메일 복사';

  @override
  String get minorAccountReviewSupportEmailCopied => '지원 이메일을 복사했어요';

  @override
  String get minorAccountReviewCopyCaseId => '케이스 ID 복사';

  @override
  String get minorAccountReviewCaseIdCopied => '케이스 ID를 복사했어요';

  @override
  String get minorAccountReviewUnavailable => '사용할 수 없음';

  @override
  String get minorAccountReviewUnder13Instructions =>
      '부모님이나 보호자에게 케이스 ID를 함께 적고, 이 계정 검토 건으로 Divine에 연락한다는 점을 밝혀 달라고 전해주세요.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return '케이스 $caseId의 13세 미만 계정 검토';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Divine 지원팀께,\n\n13세 미만 아이의 부모 또는 보호자이며, 계정 검토 케이스 $caseId 건으로 연락드립니다.\n\n감사합니다.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle => '미성년자 계정 검토 시뮬레이션';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => '현재 상태';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return '제한됨 ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => '활성';

  @override
  String get devOptionsMinorReviewStateLoading => '불러오는 중...';

  @override
  String get devOptionsMinorReviewStateError => '상태 불러오기 오류';

  @override
  String get devOptionsMinorReviewClearTitle => '시뮬레이션 재정의 해제';

  @override
  String get devOptionsMinorReviewClearSubtitle => '다시 백엔드 또는 기본 활성 상태 사용';

  @override
  String get devOptionsMinorReviewTeenTitle => '13~15세 검토 케이스 시뮬레이션';

  @override
  String get devOptionsMinorReviewTeenSubtitle => '보호자 연락 경로가 있는 제한된 계정';

  @override
  String get devOptionsMinorReviewUnder13Title => '13세 미만 지원 케이스 시뮬레이션';

  @override
  String get devOptionsMinorReviewUnder13Subtitle => '보호자 이메일 안내만 있는 제한된 계정';

  @override
  String get devOptionsMinorReviewClearedToast => '미성년자 계정 검토 시뮬레이션을 해제했어요';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      '13세 미만 지원 케이스 시뮬레이션을 켰어요';

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
  String get devOptionsProtectedMinorSimulationTitle => '보호 대상 미성년자 시뮬레이션';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => '현재 상태';

  @override
  String get devOptionsProtectedMinorStateProtected => '보호 대상 미성년자 (13~15세)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => '보호 대상 아님';

  @override
  String get devOptionsProtectedMinorStateLoading => '불러오는 중…';

  @override
  String get devOptionsProtectedMinorStateError => '상태 읽기 오류';

  @override
  String get devOptionsProtectedMinorOverrideNone => '재정의 없음 (실제 계정 상태)';

  @override
  String get devOptionsProtectedMinorOverrideProtected => '재정의: 보호 대상 강제';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected => '재정의: 보호 대상 아님 강제';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      '보호 대상 미성년자 시뮬레이션 (13~15세)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      '#175/#176 보호 기능을 검증하려고 보호 대상 미성년자 상태를 강제합니다';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle => '성인 시뮬레이션';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      '보호 대상 아님 강제 (명시적 부정으로, 재정의 없음과는 다름)';

  @override
  String get devOptionsProtectedMinorClearTitle => '재정의 해제';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Keycast가 관리하는 실제 계정 상태로 돌아가기';

  @override
  String get devOptionsProtectedMinorEnabledToast => '보호 대상 미성년자 상태를 강제로 켰어요';

  @override
  String get devOptionsProtectedMinorNonMinorToast => '보호 대상 미성년자 상태를 강제로 껐어요';

  @override
  String get devOptionsProtectedMinorClearedToast => '보호 대상 미성년자 재정의를 해제했어요';

  @override
  String get devOptionsInviteAvailabilityTitle => '가입 초대';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => '현재 상태';

  @override
  String get devOptionsInviteAvailabilityServerLoading => '서버 값: 불러오는 중';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => '서버 값: 켜짐';

  @override
  String get devOptionsInviteAvailabilityServerDisabled => '서버 값: 꺼짐';

  @override
  String get devOptionsInviteAvailabilityServerUnknown => '서버 값: 알 수 없음';

  @override
  String get devOptionsInviteAvailabilityOverrideNone => '재정의: 서버 값 사용';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled => '재정의: 켜기 강제';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled => '재정의: 끄기 강제';

  @override
  String get devOptionsInviteAvailabilityUseServer => '서버 값 사용';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      '초대 서비스의 onboardingMode 따르기';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => '켜기 강제';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      '가입 초대 게이트와 관리 화면을 로컬에서 표시';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => '끄기 강제';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      '서버를 바꾸지 않고 가입 초대 UI를 로컬에서 숨김';

  @override
  String get devOptionsInviteAvailabilityUseServerToast => '가입 초대가 이제 서버를 따릅니다';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast => '가입 초대를 강제로 켰어요';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast => '가입 초대를 강제로 껐어요';

  @override
  String get commentsRecordVideoButtonLabel => '영상 댓글 녹화';

  @override
  String get commentsOpenVideoLabel => '영상 댓글 열기';

  @override
  String get commentsMuteVideoReplyLabel => '영상 답글 음소거';

  @override
  String get commentsUnmuteVideoReplyLabel => '영상 답글 음소거 해제';

  @override
  String get commentsOpenReplyParentLabel => '답글 대상 영상 열기';

  @override
  String get commentsReplyParentSectionTitle => '답글 대상';

  @override
  String commentsReplyParentLabel(String target) {
    return '$target에 답글';
  }

  @override
  String get commentsReplyParentFallbackLabel => '영상에 답글';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return '인증된 $platform 계정: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => '인증된 계정';

  @override
  String get profileEditGetVerifiedCta => '인증 받기';

  @override
  String get profileEditGetVerifiedSubtitle => '소셜 미디어 계정을 연결해서 진짜 너인 걸 알려줘.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return '웹사이트 방문: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => '웹사이트를 열 수 없어요';

  @override
  String get videoMetadataEditCoverTitle => '커버 편집';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => '커버 변경 사항 취소';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      '선택한 프레임을 동영상 커버로 사용';

  @override
  String get videoMetadataEditCoverStripSemanticLabel => '커버 프레임 선택을 위해 동영상 탐색';

  @override
  String get videoMetadataTagsPickerSearchHint => '태그 검색 또는 추가';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      '사람들이 동영상을 발견할 수 있도록 태그를 추가하세요';

  @override
  String get videoMetadataTagsPickerNoResults => '일치하는 태그 없음';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '\"#$tag\" 추가';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => '아직 16세가 아니세요? 괜찮아요. ';

  @override
  String get authUnder16ChoicesCta => '선택지를 알려드릴게요.';

  @override
  String get minorAccountReviewUnder13WhyTitle => '그 이유는';

  @override
  String get generalSettingsHoldToRecord => '길게 눌러서 녹화';

  @override
  String get generalSettingsHoldToRecordSubtitle => '길게 누르면 녹화가 시작되고, 놓으면 멈춰요';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '프로필에 영상 $count개를 게시했어요',
      one: '프로필에 영상을 게시했어요',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => '메시지 보내기';

  @override
  String get emojiPickerSearchHint => '검색';

  @override
  String get emojiCategoryRecent => '최근 사용';

  @override
  String get emojiCategorySmileys => '스마일리 및 사람';

  @override
  String get emojiCategoryAnimals => '동물 및 자연';

  @override
  String get emojiCategoryFood => '음식 및 음료';

  @override
  String get emojiCategoryActivities => '활동';

  @override
  String get emojiCategoryTravel => '여행 및 장소';

  @override
  String get emojiCategoryObjects => '사물';

  @override
  String get emojiCategorySymbols => '기호';

  @override
  String get emojiCategoryFlags => '깃발';

  @override
  String get videoEditorMarkerLabel => '마커';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel => '타임라인 마커 추가';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel => '타임라인 마커 제거';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      '재생 헤드의 마커 제거';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => '마커를 삭제할까요?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      '타임라인에서 마커만 제거합니다. 편집 내용은 그대로 유지됩니다.';

  @override
  String get videoEditorVolumeLongPressHint => '모든 트랙 음소거 또는 해제';

  @override
  String get videoEditorSplitFailed => '분할에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get videoEditEditSubtitles => '자막 편집';

  @override
  String get subtitleEditorTitle => '자막 편집';

  @override
  String get subtitleEditorSave => '저장';

  @override
  String get subtitleEditorProcessing => '자막을 아직 생성하고 있어요. 잠시 후 다시 확인해주세요.';

  @override
  String get subtitleEditorNoSpeech =>
      '이 영상에서는 말소리가 감지되지 않았어요. 자막으로 만들 내용이 없네요.';

  @override
  String get subtitleEditorWriteOwn => '직접 쓰기';

  @override
  String get subtitleEditorAddCue => '줄 추가';

  @override
  String get subtitleEditorRemoveCue => '이 줄 삭제';

  @override
  String get subtitleEditorPreviewUnavailable =>
      '지금은 동영상을 재생할 수 없지만 자막은 계속 고칠 수 있어요.';

  @override
  String get subtitleEditorPlayPreview => '동영상 재생';

  @override
  String get subtitleEditorPausePreview => '동영상 일시정지';

  @override
  String get subtitleEditorInvalidHint => '모든 줄에는 텍스트와 시작보다 늦은 종료 시간이 필요해요.';

  @override
  String get subtitleEditorLoadError => '자막을 불러오지 못했어요. 다시 시도해주세요.';

  @override
  String get subtitleEditorSaveSuccess => '자막을 업데이트했어요';

  @override
  String get subtitleEditorSaveError => '자막을 저장하지 못했어요. 다시 시도해주세요.';

  @override
  String get subtitleEditorRetry => '다시 시도';

  @override
  String get subtitleEditorCueHint => '자막 텍스트';

  @override
  String get imageCropEditorRotateLabel => '회전';

  @override
  String get imageCropEditorFlipLabel => '뒤집기';

  @override
  String get imageCropEditorResetLabel => '초기화';

  @override
  String get imageCropEditorCloseSemanticLabel => '자르기 취소';

  @override
  String get imageCropEditorDoneSemanticLabel => '자르기 적용';

  @override
  String get imageCropEditorProcessing => '자르기 적용 중…';

  @override
  String get backgroundUploadNotificationTitle => '동영상 업로드 중';

  @override
  String get monetizationSettingsTitle => '크리에이터 후원';

  @override
  String get monetizationSettingsSubtitle => '팁과 구독 링크 추가';

  @override
  String get monetizationSettingsIntroTitle => '외부 링크만';

  @override
  String get monetizationSettingsIntroBody =>
      '직접 관리하는 링크를 추가하세요. Divine은 결제를 처리하지 않으며, 이 링크로 앱 안의 콘텐츠가 열리지도 않습니다.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '프로필에 활성 링크 $count개',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => '팁 보내기';

  @override
  String get monetizationSettingsSubscriptionSection => '구독 / 후원';

  @override
  String get monetizationSettingsSave => '후원 링크 저장';

  @override
  String get monetizationSettingsSaving => '저장 중...';

  @override
  String get monetizationSettingsSaved => '후원 링크를 업데이트했어요';

  @override
  String get monetizationSettingsSaveFailed =>
      '후원 링크를 저장하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get monetizationSettingsErrorEmpty => '핸들이나 URL을 추가하세요.';

  @override
  String get monetizationSettingsErrorInvalid => '이 링크는 올바르지 않아 보여요.';

  @override
  String get monetizationSettingsErrorWrongProvider => '이 제공업체에 맞는 링크를 사용하세요.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag 또는 cash.app 링크';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me 핸들 또는 링크';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo 핸들 또는 링크';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon 핸들 또는 링크';

  @override
  String get monetizationSettingsHintSubstack => 'Substack 도메인 또는 링크';

  @override
  String get monetizationSettingsHintMedium => 'Medium 핸들 또는 링크';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective 슬러그 또는 링크';

  @override
  String get profileSupportSheetTitle => '이 크리에이터 후원하기';

  @override
  String get profileSupportSheetBody =>
      '이 링크들은 Divine 밖에서 열립니다. 여기서 앱 안의 콘텐츠가 열리지는 않아요.';

  @override
  String get profileSupportTipSection => '팁 보내기';

  @override
  String get profileSupportSubscriptionSection => '구독 / 후원';

  @override
  String get profileSupportButtonLabel => '후원';

  @override
  String get monetizationTipsSettingsTitle => '팁';

  @override
  String get monetizationTipsSettingsSubtitle => '선택 사항인 팁 링크 추가';

  @override
  String get monetizationTipsSettingsIntroTitle => '선택 사항인 팁만';

  @override
  String get monetizationTipsSettingsIntroBody =>
      '팁은 사용자끼리 주고받는 선택 사항인 선물이에요. Divine에서 콘텐츠, 구독, 기능, 순위, 노출, 접근 권한이 열리지는 않습니다.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '프로필에 활성 팁 링크 $count개',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => '팁 링크 저장';

  @override
  String get monetizationTipsSettingsSaved => '팁 링크를 업데이트했어요';

  @override
  String get profileTipButtonLabel => '팁';

  @override
  String get profileTipSheetTitle => '이 크리에이터에게 팁 보내기';

  @override
  String get profileTipSheetBody =>
      '팁 링크는 Divine 밖에서 열립니다. 선택 사항이며 Divine에서 콘텐츠, 구독, 기능, 접근 권한이 열리지는 않아요.';

  @override
  String get settingsStorageTitle => '저장공간';

  @override
  String get settingsStorageCacheSectionTitle => '캐시된 미디어';

  @override
  String get settingsStorageCacheDescription =>
      '캐시된 피드 동영상, 썸네일, 임시 렌더입니다. 삭제해도 안전하며 필요할 때 다시 다운로드되거나 생성됩니다.';

  @override
  String get settingsStorageMeasuring => '계산 중…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size 사용 중';
  }

  @override
  String get settingsStorageClearButton => '캐시 지우기';

  @override
  String get settingsStorageClearConfirmTitle => '캐시된 미디어를 지울까요?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return '$size을(를) 확보합니다. 클립 라이브러리는 영향을 받지 않습니다.';
  }

  @override
  String get settingsStorageClearConfirmAction => '지우기';

  @override
  String get settingsStorageCleared => '캐시를 지웠습니다';

  @override
  String get settingsStorageLibrarySectionTitle => '클립 라이브러리';

  @override
  String get settingsStorageLibraryDescription => '동영상 파일이 없는 손상된 클립을 확인합니다.';

  @override
  String get settingsStorageScanButton => '라이브러리 확인';

  @override
  String get settingsStorageLibraryHealthy => '손상된 클립이 없습니다';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return '발견된 손상된 클립: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => '손상된 클립 제거';

  @override
  String get settingsStorageBrokenClipsRemoved => '손상된 클립을 제거했습니다';

  @override
  String get settingsStorageError => '문제가 발생했습니다';

  @override
  String get settingsStorageMaxVideoCacheLabel => '최대 동영상 캐시';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ 동영상 $count개';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle => '손상된 클립을 제거할까요?';

  @override
  String get settingsStorageRepairSectionTitle => '설치 복구';

  @override
  String get settingsStorageRepairDescription =>
      '앱이 자꾸 종료되거나 이상하게 작동하면 로컬 데이터를 초기화하면 대개 해결돼요. 클립과 초안은 그대로 남아요.';

  @override
  String get settingsStorageRepairButton => '앱 데이터 초기화';

  @override
  String get settingsStorageRepairConfirmTitle => '앱 데이터를 초기화할까요?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      '캐시된 피드 데이터와 임시 파일이 삭제돼요. 클립, 초안, 설정, 로그인은 남지만 그다음에 앱을 다시 시작해야 해요.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size가 삭제돼요';
  }

  @override
  String get settingsStorageRepairConfirmAction => '초기화';

  @override
  String get settingsStorageRepairInProgress => '초기화 중…';

  @override
  String get settingsStorageRepairSuccess => '완료 — 앱을 다시 시작하면 끝나요.';

  @override
  String get settingsStorageRepairFailure => '전부 초기화하지 못했어요. 다시 시작한 뒤 시도해 주세요.';

  @override
  String get nostrSettingsSignatureVerification => '서명 확인';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Divine이 릴레이 이벤트 서명을 언제 확인할지 선택하세요. 이벤트 ID는 항상 먼저 검증됩니다.';

  @override
  String get nostrSettingsSignatureVerificationAll => '모든 릴레이';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      '가장 안전합니다. 모든 릴레이 이벤트 서명을 확인합니다.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => '신뢰할 수 없는 릴레이';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      '이미 구성된 풀에 있는 릴레이는 확인을 건너뜁니다.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Divine 외 릴레이';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Divine 릴레이는 신뢰하고 나머지는 확인합니다.';

  @override
  String get settingsCrosspostingTitle => '크로스 포스팅';

  @override
  String get settingsCrosspostingSubtitle => '영상을 다른 플랫폼에 공유해요';

  @override
  String get crosspostingSignInRequired => '크로스 포스팅을 관리하려면 Divine으로 로그인해 주세요';

  @override
  String get crosspostingLoadFailed => '크로스 포스팅 설정을 불러오지 못했어요';

  @override
  String get crosspostingNoPlatforms => '지금은 사용할 수 있는 크로스 포스팅 플랫폼이 없어요';

  @override
  String get crosspostingRetry => '다시 시도';

  @override
  String get crosspostingNotConnected => '연결되지 않음';

  @override
  String get crosspostingConnected => '연결됨';

  @override
  String get crosspostingNeedsReconnect => '다시 연결해야 해요';

  @override
  String get crosspostingConnect => '연결';

  @override
  String get crosspostingReconnect => '다시 연결';

  @override
  String get crosspostingDisconnect => '연결 해제';

  @override
  String get crosspostingModeOff => '끔';

  @override
  String get crosspostingModeManual => '수동';

  @override
  String get crosspostingModeManualSubtitle => '영상마다 직접 선택해요';

  @override
  String get crosspostingModeAutomatic => '자동';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      '앞으로 올리는 영상은 자동으로 게시돼요 — 이걸 켠 뒤에 올린 영상만요';

  @override
  String get crosspostingNotConnectedError => '게시 방식을 바꾸려면 이 플랫폼을 먼저 연결해 주세요.';

  @override
  String get crosspostingGenericError => '문제가 생겼어요. 다시 시도해 주세요.';

  @override
  String get crosspostingCallbackTimeoutError =>
      '로그인 페이지에서 응답이 오지 않았어요. 거기서 연결을 마쳤다면 새로 고쳐 보세요 — 이미 계정이 연결되어 있을 수도 있어요.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform 연결됨';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return '$platform을(를) 연결하지 못했어요';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return '$platform에서 연결이 취소됐어요';
  }

  @override
  String get supporterTitle => 'Divine 서포터';

  @override
  String get supporterTileSubtitle => '선택형 월간 구독으로 Divine을 후원해요.';

  @override
  String get supporterHeroTitle => 'Divine이 계속 돌아가게 해주세요';

  @override
  String get supporterHeroBody =>
      'Divine은 무료이고 앞으로도 그럴 거예요. 루프가 계속 돌아가는 걸 돕고 싶다면 월간 서포터가 되어주세요. 잠기는 건 아무것도 없어요 — 그냥 불을 켜두는 데 보탬이 되고, 저희의 감사를 받아요.';

  @override
  String get supporterActiveBadge => 'Divine 서포터예요. 계속 이어가 주셔서 고마워요.';

  @override
  String get supporterPurchasePending => '구매가 승인 대기 중이에요.';

  @override
  String get supporterPurchaseConfirming => '후원 확인 중…';

  @override
  String get supporterStoreChecking => '스토어 확인 중…';

  @override
  String get supporterUnavailable => '지금은 여기서 서포터 구독을 사용할 수 없어요.';

  @override
  String get supporterRestorePurchases => '구매 복원';

  @override
  String get supporterDismissError => '오류 닫기';

  @override
  String get supporterErrorStoreUnavailable => '이 기기에서 스토어를 사용할 수 없어요.';

  @override
  String get supporterErrorPurchaseFailed => '구매가 완료되지 않았어요. 결제되지 않았어요.';

  @override
  String get supporterErrorPurchasePending => '구매가 승인 대기 중이에요.';

  @override
  String get supporterErrorRestoreFailed => '복원할 서포터 구독을 찾지 못했어요.';

  @override
  String get supporterErrorOwnershipConflict => '이 구매는 다른 Divine 계정에 속해 있어요.';

  @override
  String get supporterErrorVerificationUnavailable =>
      '지금은 Divine에서 서포터 상태를 확인할 수 없어요.';

  @override
  String get supporterErrorUnknown => '문제가 생겼어요. 다시 시도해주세요.';

  @override
  String get supporterDisclaimer =>
      '스토어에서 구매를 확인한 후 Divine이 서포터 상태를 확정해요. 표시는 선택 사항이고, 후광은 인증 표시가 아니에요.';

  @override
  String get profileNotifyBellOff => '새 영상 알림 받기';

  @override
  String get profileNotifyBellOn => '새 영상 알림 끄기';

  @override
  String get profileNotifyUpdateFailed => '저장하지 못했습니다. 다시 시도할까요?';

  @override
  String get savedSoundYourLabel => '내 라벨';

  @override
  String get savedSoundAddHashtags => '해시태그 추가';

  @override
  String get savedSoundDeviceOnly => '이 기기에 저장됨';

  @override
  String get savedSoundDetailsRetry => '해당 정보를 저장하지 못했어요. 탭해서 다시 시도하세요.';

  @override
  String get savedSoundFallbackTitle => '저장한 사운드';

  @override
  String get savedSoundPreviewAction => '사운드 미리 듣기';

  @override
  String get savedSoundEditAction => '사운드 정보 편집';

  @override
  String get savedSoundRemoveAction => '저장한 사운드 삭제';

  @override
  String get savedSoundClearHashtagFilter => '해시태그 필터 지우기';

  @override
  String get soundAllowRemix => '다른 사람이 이 사운드를 리믹스하도록 허용';

  @override
  String get soundReuseUnavailable => '이 사운드는 지금 리믹스할 수 없어요.';

  @override
  String get soundPublicCredit => '공개 사운드 크레딧';

  @override
  String get soundCreditRequired => '게시하기 전에 공개 사운드 크레딧을 추가하세요.';

  @override
  String get soundSharedAs => '공유 이름';

  @override
  String get soundOwnWork => '이 사운드는 내가 만들었어요';

  @override
  String soundCreatorBy(String creator) {
    return '제작: $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return '$publisher님이 공유';
  }

  @override
  String get soundRemixingAllowed => '리믹스 허용';

  @override
  String get soundCreditOnly => '크레딧만';

  @override
  String get soundCreditTitleLabel => '사운드 제목';

  @override
  String get soundCreditCreatorLabel => '제작자';

  @override
  String get soundCreditSourceUrlLabel => '출처 URL';

  @override
  String get soundCreditPublicHashtagsLabel => '공개 해시태그';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel => '태그 선택 취소';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel => '선택한 태그 적용';

  @override
  String get userPickerCancelSemanticLabel => '사용자 선택 취소';

  @override
  String get userPickerConfirmSemanticLabel => '선택한 사용자 확인';

  @override
  String get userPickerClearSelectionSemanticLabel => '사용자 선택 지우기';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      '콘텐츠 경고 선택 취소';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      '선택한 콘텐츠 경고 적용';

  @override
  String get videoEditorCloseEditorSemanticLabel => '동영상 편집기 닫기';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel => '게시물 세부 정보로 계속';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return '$tool의 변경 사항 취소';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return '$tool의 변경 사항 적용';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => '오디오 제거';

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
  String get verifyTitle => '인증된 계정';

  @override
  String get verifySignedOutMessage => '계정을 연결하려면 로그인해.';

  @override
  String get verifyIntro => '이미 쓰는 계정을 연결하면 진짜 너라는 걸 바로 알 수 있어.';

  @override
  String get verifyLoadFailed => '연결을 불러오지 못했어.';

  @override
  String get verifyRetry => '다시 시도';

  @override
  String get verifyLinkedSectionTitle => '연결됨';

  @override
  String get verifyVerifierUnreachable => '인증 서비스에 연결하지 못해서 전부 확인 안 됨으로 표시돼.';

  @override
  String get verifyAddSectionTitle => '계정 추가';

  @override
  String get verifyAllPlatformsLinked => '지원하는 건 전부 연결했어.';

  @override
  String get verifyStatusVerified => '인증됨';

  @override
  String get verifyStatusUnverified => '인증 안 됨';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return '$platform 계정 $identity 연결 해제';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return '$platform 연결을 해제할까?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity이(가) 프로필에 더 이상 표시되지 않아. 나중에 다시 연결할 수 있지만, 그때는 다시 로그인하거나 새 증명을 게시해야 해.';
  }

  @override
  String get verifyUnlinkConfirmCta => '연결 해제';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return '$platform 계정 연결';
  }

  @override
  String get verifyOneTapBadge => '한 번 탭';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return '$platform에 로그인하면 나머지는 우리가 처리해. 아무것도 게시되지 않아.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return '$platform(으)로 계속';
  }

  @override
  String get verifyConnectProofTitle => '또는 증명을 게시';

  @override
  String get verifyConnectProofExplainer => '그 계정에 npub을 게시하고, 그 게시물 링크를 붙여넣어.';

  @override
  String get verifyNpubLabel => '내 npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'npub 복사';

  @override
  String get verifyNpubCopied => 'npub 복사됨';

  @override
  String get verifyIdentityLabel => '계정 이름';

  @override
  String get verifyProofLabel => '게시물 링크';

  @override
  String get verifyConnectProofCta => '확인하고 연결';

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
  String get verifyErrorVerifierUnreachable => '인증 서비스에 연결하지 못했어. 잠시 후 다시 시도해.';

  @override
  String get verifyErrorOauthFailed => '잘 안 됐어. 한 번 더 해봐.';

  @override
  String get verifyErrorHandleRequired => '핸들부터 입력해.';

  @override
  String get verifyErrorPublishFailed => '인증은 됐는데 업데이트를 받아준 릴레이가 없어. 다시 시도해.';

  @override
  String get verifyErrorOauthUnavailable =>
      '여기는 아직 원탭 로그인이 준비 안 됐어. 아래 증명 게시물을 써.';

  @override
  String get verifyConnectProofExplainerGithub =>
      '첫 번째 파일에 npub을 넣은 공개 gist를 만들고 그 gist 링크를 붙여넣어.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      '우리 봇이 읽을 수 있는 Discord 채널에 npub을 올리고 그 메시지 링크를 붙여넣어. 서버 초대는 아무것도 증명하지 못해.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      '그 계정에서 npub을 트윗하고, 그 트윗 링크를 붙여넣어.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      '그 계정에서 npub을 올리고 링크를 붙여넣어. 계정 이름에는 인스턴스가 있어야 해 — alice가 아니라 mastodon.social/@alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      '연결되는 건 채널이야, 네 텔레그램 계정이 아니라. 먼저 공개 링크가 필요해 (텔레그램은 새 채널을 비공개로 만들어). 거기에 npub을 올리고 메시지 링크를 붙여넣어.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      '위에서 로그인했어? 그럼 더 필요 없어. 안 했으면 npub을 올리고 그 게시물 링크를 붙여넣어.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      '영상 캡션에 npub을 넣고, 그 영상 링크를 붙여넣어.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      '영상 설명에 npub을 넣고, 그 영상 링크를 붙여넣어.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform 연결됐어.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      '그건 비공개 채널이거나 초대 링크야. 채널에 공개 링크를 설정한 다음 메시지 링크를 붙여넣어.';

  @override
  String get verifyErrorRemoveFailed => '연결을 해제하지 못했어. 다시 시도해.';

  @override
  String get verifyErrorLinksUnreadable =>
      '현재 연결을 읽지 못해서 아무것도 바꾸지 않았어. 연결 상태를 확인하고 다시 시도해.';

  @override
  String get verifyChannelLabel => '채널 이름';

  @override
  String get verifyHowItWorksTitle => '어떻게 작동해?';

  @override
  String get verifyHowItWorksIntro => '두 계정이 악수한다고 생각하면 돼:';

  @override
  String get verifyHowItWorksYourSide => '네 Divine 프로필이 말해: “트위터의 @alice가 나야.”';

  @override
  String get verifyHowItWorksOtherSide =>
      '네 트위터 계정이 확인해줘: “맞아, 그 Divine 프로필은 내 거야.”';

  @override
  String get verifyHowItWorksBothSides =>
      '우리가 양쪽을 다 확인해. 맞으면 인증 완료. 위조는 못 해 — 이름과 사진은 베낄 수 있어도 네 진짜 계정에서 글을 올릴 수는 없거든.';

  @override
  String get verifyHowItWorksOwnership =>
      '연결은 네 Nostr 신원에 저장되니까 여기서 언제든 지울 수 있어.';

  @override
  String get generalSettingsSectionIdentity => '신원';

  @override
  String get libraryFilterAll => '전체';

  @override
  String get libraryFilterArchive => '보관함';

  @override
  String get libraryFilterDeleted => '삭제됨';

  @override
  String get libraryCategoryNewChipLabel => '새로 만들기';

  @override
  String get libraryCategoryCreateSemanticLabel => '카테고리 만들기';

  @override
  String get libraryCategoryCreateTitle => '새 카테고리';

  @override
  String get libraryCategoryCreateAction => '만들기';

  @override
  String get libraryCategoryRenameTitle => '카테고리 이름 변경';

  @override
  String get libraryCategoryRenameAction => '이름 변경';

  @override
  String get libraryCategoryDeleteAction => '카테고리 삭제';

  @override
  String get libraryCategoryNameLabel => '카테고리 이름';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '“$name”을(를) 삭제할까요?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      '클립은 그대로 남아요. 전체로 돌아갈 뿐이에요.';

  @override
  String get libraryCategoryManageSemanticLabel => '이 카테고리 이름 변경 또는 삭제';

  @override
  String get libraryCategoryMoveTitle => '이동할 위치';

  @override
  String get libraryCategoryMoveNone => '카테고리 없음';

  @override
  String get libraryCategoryMoveNewCategory => '새 카테고리';

  @override
  String get libraryArchiveAction => '보관';

  @override
  String get libraryUnarchiveAction => '보관 취소';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이 카테고리들에 유지할까요?',
      one: '이 카테고리에 유지할까요?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return '$name에 유지';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => '카테고리에 유지';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return '$name에서 제거';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed => '카테고리에서 제거';

  @override
  String get libraryMoveSelectedClipsTooltip => '선택한 클립 이동';

  @override
  String get libraryCategoryEmptyTitle => '아직 아무것도 없어요';

  @override
  String get libraryCategoryEmptySubtitle => '클립 몇 개를 골라 이 카테고리로 옮겨 보세요.';

  @override
  String get libraryArchiveEmptyTitle => '보관한 항목이 없어요';

  @override
  String get libraryArchiveEmptySubtitle => '보관한 클립은 기본 라이브러리와 떨어져 여기에서 기다려요.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클립 $count개를 $name(으)로 옮겼어요',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클립 $count개를 카테고리에서 뺐어요',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클립 $count개를 보관했어요',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클립 $count개가 라이브러리로 돌아왔어요',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => '이메일 변경';

  @override
  String get accountSettingsChangeEmailSubtitle => '계정을 다른 주소로 옮기기';

  @override
  String get accountSettingsChangePassword => '비밀번호 변경';

  @override
  String get accountSettingsChangePasswordSubtitle => '로그인에 쓸 새 비밀번호 정하기';

  @override
  String get accountCredentialsNeedsSignIn => '세션이 만료됐어요. 다시 로그인한 뒤 변경해 주세요.';

  @override
  String get accountCredentialsRateLimited => '시도가 너무 많아요. 몇 분 뒤에 다시 해 주세요.';

  @override
  String get accountCredentialsNetwork =>
      'Divine에 연결하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get accountCredentialsUnknown => '잘 안 됐어요. 다시 시도해 주세요.';

  @override
  String get changePasswordSubtitle => '현재 비밀번호를 입력한 뒤 새 비밀번호를 정하세요.';

  @override
  String get changePasswordCurrentLabel => '현재 비밀번호';

  @override
  String get changePasswordWrongCurrent => '현재 비밀번호가 아니에요.';

  @override
  String get changePasswordSuccess => '비밀번호를 변경했어요.';

  @override
  String get changeEmailSubtitle =>
      '새 주소와 계정에 등록된 주소로 확인 링크를 보냅니다. 둘 다 확인하면 이메일이 바뀌어요.';

  @override
  String changeEmailCurrentAddress(String email) {
    return '계정 주소: $email';
  }

  @override
  String get changeEmailNewLabel => '새 이메일';

  @override
  String get changeEmailPasswordLabel => '비밀번호';

  @override
  String get changeEmailSameAsCurrent => '이미 사용 중인 이메일 주소예요.';

  @override
  String get changeEmailWrongPassword => '비밀번호가 아니에요.';

  @override
  String get changeEmailSubmit => '확인 링크 보내기';

  @override
  String get changeEmailSentTitle => '링크 두 통을 보냈어요';

  @override
  String changeEmailSentMessage(String email) {
    return '$email과 계정에 등록된 주소에서 확인해 주세요. 둘 다 끝나면 이메일이 바뀝니다.';
  }

  @override
  String get changeEmailSentExpiry => '링크는 24시간 뒤에 만료돼요.';

  @override
  String get changeEmailSentDone => '알겠어요';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '영상 $formattedCount개',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => '맞팔로우';

  @override
  String get socialProofFollowsYou => '나를 팔로우함';

  @override
  String get socialProofYouFollow => '팔로우 중';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '팔로워 $formattedCount명',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage => '지금 영상을 불러올 수 없어요.\n저희 문제예요. 고치는 중이에요.';

  @override
  String get feedOfflineMessage => '오프라인 상태예요.\n연결을 확인하고 다시 시도해 주세요.';

  @override
  String get dbFailureTitle => '로컬 데이터베이스를 열지 못했습니다';

  @override
  String get dbFailureAdviceResettable =>
      '재시작으로는 해결되지 않습니다. 아래에서 로컬 데이터베이스를 초기화하면 Divine을 깨끗한 상태로 시작할 수 있습니다. 계정은 그대로 유지됩니다.';

  @override
  String get dbFailureAdviceRestart =>
      '기기 잠금을 해제한 뒤 Divine을 다시 실행하세요. 계속 발생하면 앱을 업데이트하거나 고객지원에 문의하세요.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Divine을 한 번 다시 시작해 보세요. 문제가 계속되면 앱을 업데이트하거나 지원팀에 문의하세요. 로컬 데이터는 그대로 보존되어 있습니다.';

  @override
  String dbFailureDiagnostic(String code) {
    return '진단: $code';
  }

  @override
  String get dbFailureCloseApp => 'Divine 닫기';

  @override
  String get dbFailureResetAction => '로컬 데이터베이스 초기화';

  @override
  String get dbFailureConfirmTitle => '로컬 데이터베이스를 초기화할까요?';

  @override
  String get dbFailureConfirmBody =>
      '계정은 그대로 유지됩니다. 이 기기에 저장된 초안과 클립은 삭제됩니다. 메시지와 피드는 네트워크에서 다시 불러옵니다.';

  @override
  String get dbFailureResetConfirm => '지금 로컬 데이터베이스 초기화';

  @override
  String get dbFailureCancel => '취소';

  @override
  String get dbFailureResetFailed => '실패했습니다. Divine을 닫고 다시 시도하세요.';

  @override
  String get dbFailureResetDoneTitle => '로컬 데이터베이스가 초기화되었습니다';

  @override
  String get dbFailureResetDoneBody =>
      'Divine을 닫았다가 다시 여세요. 다음 실행에서 새 로컬 데이터베이스가 만들어집니다.';

  @override
  String get authSignInOptionsInfo => '로그인 옵션 정보';

  @override
  String get authShowPassword => '비밀번호 표시';

  @override
  String get authHidePassword => '비밀번호 숨기기';

  @override
  String get followUserSemanticLabel => '사용자 팔로우';

  @override
  String get unfollowUserSemanticLabel => '사용자 팔로우 취소';

  @override
  String get commentsLoadingSemanticLabel => '댓글 불러오는 중';

  @override
  String get analyticsWindowAll => '전체';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return '사용자 팔로우 $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return '사용자 팔로우 취소 $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / 월';
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
  String get updateGentleBanner => '새 업데이트가 나왔어요. 확인해 보세요 →';

  @override
  String get updateModerateTitle => '마지막 확인 이후 업데이트가 나왔습니다';

  @override
  String get updateUrgentTitle => '중요한 수정 사항이 빠져 있습니다';

  @override
  String get updateNotNow => '나중에';

  @override
  String get updateAction => '업데이트';

  @override
  String updateNewIn(String version) {
    return '$version의 새로운 기능:';
  }

  @override
  String get settingsUpdateAvailable => '업데이트 가능';
}
